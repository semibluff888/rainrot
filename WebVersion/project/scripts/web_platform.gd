class_name WardWebPlatform
extends Node

var game: Node
var bridge_callback: JavaScriptObject
var dust: MultiMeshInstance3D
var dust_time := 0.0
var telemetry_timer := 0.0
var diagnostic := false
var page_visible := true
var dust_timer := 0.0
var shadow_timer := 0.0
var shadow_lights: Array[Light3D] = []
var shadow_spots: Array[SpotLight3D] = []
var selected_spots: Array[SpotLight3D] = []
var pointer_locked := false

func input_suspended() -> bool:
	return OS.has_feature("web") and not game.automated and not pointer_locked

func report(kind: String, result: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.RainrotWeb && window.RainrotWeb.report("+JSON.stringify(kind)+","+JSON.stringify(result)+")",true)

func _ready() -> void:
	if OS.has_feature("web"):
		bridge_callback = JavaScriptBridge.create_callback(_browser_event)
		var shell := JavaScriptBridge.get_interface("RainrotWeb")
		if shell:
			diagnostic=bool(shell.diagnostic)
			page_visible=bool(shell.pageVisible)
			shell.connectGame(bridge_callback)
	collect_shadow_lights()
	create_dust()
	batch_static_boxes()

func _browser_event(arguments: Array) -> void:
	if arguments.is_empty(): return
	match str(arguments[0]):
		"visible":
			page_visible=true
		"lock":
			pointer_locked=true
		"unlock", "hidden":
			if str(arguments[0])=="hidden":page_visible=false
			pointer_locked=false
			if game.started and not game.finished and game.hud.modal=="" and not game.automated:
				game.hud.show_pause()
		"resume":
			if game.started and game.hud.modal=="pause": game.hud.close()
		"export_save":
			if not game.has_save():
				game.hud.toast("还没有记录 · 开始调查后会自动保存")
				return
			JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(game.save_path),"rainrot-web-save.json","application/json")
		"import_save":
			if arguments.size()<2: return
			var parsed = JSON.parse_string(str(arguments[1]))
			var imported := WardState.deserialize(parsed)
			if imported==null:
				game.hud.toast("这不是有效的第九病区记录")
				return
			var file:=FileAccess.open(game.save_path,FileAccess.WRITE)
			if not file:game.hud.toast("浏览器无法保存记录");return
			file.store_string(JSON.stringify(imported.serialize()));file.close()
			game.hud.toast("记录已导入 · 点击继续调查")
			if game.hud.modal=="menu":game.hud.show_menu()
			if game.started:game.hud.show_pause()
			persist()

func mode_changed(mode: String) -> void:
	if not OS.has_feature("web"):return
	var payload:=JSON.stringify({"mode":mode,"started":game.started,"finished":game.finished,"persistent":OS.is_userfs_persistent()})
	JavaScriptBridge.eval("window.RainrotWeb && window.RainrotWeb.update("+payload+")",true)

func persist() -> void:
	if OS.has_feature("web"):
		# Godot's IDBFS schedules filesystem synchronization. Closing each FileAccess
		# before returning is essential; no browser storage or desktop files are shared.
		mode_changed(game.hud.modal)

func apply_quality(quality: int) -> void:
	var env: Environment=game.hospital.get_node("Atmosphere").environment
	env.ssao_enabled=false;env.ssil_enabled=false;env.ssr_enabled=false
	env.volumetric_fog_enabled=false;env.glow_enabled=false
	env.ambient_light_energy=.34
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true
	env.fog_density=.008 if quality>0 else .004
	env.fog_light_color=Color(.055,.10,.12)
	game.get_viewport().scaling_3d_scale=[.65,.82,1.0][quality]
	game.get_viewport().use_taa=false
	game.get_viewport().msaa_3d=Viewport.MSAA_2X if quality==2 else Viewport.MSAA_DISABLED
	game.player.torch.shadow_enabled=quality>0
	game.player.camera.far=65
	if is_instance_valid(dust):dust.visible=quality>0
	for e in game.enemies:e.visual.set_quality(quality)
	update_shadow_lights(true)
	shadow_timer=0

func collect_shadow_lights() -> void:
	# Cache original authorship before any quality preset disables shadows.
	for node in game.hospital.find_children("*","Light3D",true,false):
		if not node.shadow_enabled:continue
		shadow_lights.append(node)
		if node is SpotLight3D:shadow_spots.append(node)

func update_shadow_lights(force: bool=false) -> void:
	var budget: int = int(game.settings.quality)
	if force:selected_spots.clear()
	var ranked := shadow_spots.duplicate()
	var where: Vector3 = game.player.global_position
	ranked.sort_custom(func(a,b):return a.global_position.distance_squared_to(where)<b.global_position.distance_squared_to(where))
	while selected_spots.size()>budget:selected_spots.pop_back()
	for candidate in ranked:
		if budget==0:break
		if candidate in selected_spots:continue
		if selected_spots.size()<budget:
			selected_spots.append(candidate)
			continue
		var farthest: SpotLight3D=selected_spots[0]
		for current in selected_spots:
			if current.global_position.distance_squared_to(where)>farthest.global_position.distance_squared_to(where):farthest=current
		if candidate.global_position.distance_to(where)+2.0<=farthest.global_position.distance_to(where):
			selected_spots.erase(farthest)
			selected_spots.append(candidate)
	for light in shadow_lights:
		var enabled: bool = budget>0 and (light is DirectionalLight3D or (light is SpotLight3D and light in selected_spots))
		if light.shadow_enabled!=enabled:light.shadow_enabled=enabled

func effects_active() -> bool:
	return page_visible and (not game.started or (not game.finished and game.hud.modal=="" and not input_suspended()))

func update_dust() -> void:
	for i in dust.multimesh.instance_count:
		var y:=fposmod(i*.137+dust_time*.018,2.5)+.18
		var x:=sin(i*2.37)*2.3+sin(dust_time*.14+i)*.035
		dust.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,y,9-fposmod(i*1.137,46))))

func create_dust() -> void:
	dust=MultiMeshInstance3D.new();dust.name="WebDust"
	var mesh:=QuadMesh.new();mesh.size=Vector2(.014,.014)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(.42,.57,.58,.16)
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test=false
	mesh.material=mat
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=80
	dust.multimesh=multi;dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.hospital.add_child(dust)
	update_dust()

func batch_static_boxes() -> void:
	# Share a unit box and instance transforms within small spatial cells. Source
	# nodes and all collision shapes remain editor-editable; moving props are excluded.
	var groups: Dictionary={}
	for node in game.hospital.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is BoxMesh or not node.visible:continue
		var ancestor: Node=node.get_parent()
		var dynamic:=false
		while ancestor!=game.hospital:
			if ancestor is WardInteractable or ancestor is WardEnemyVisual or ancestor is MeshInstance3D:dynamic=true;break
			ancestor=ancestor.get_parent()
		if dynamic:continue
		var mat: Material=node.material_override if node.material_override else node.mesh.material
		if mat==null:continue
		var cell:=Vector3i(floori(node.global_position.x/12),floori(node.global_position.y/6),floori(node.global_position.z/12))
		var key:=str(mat.get_instance_id())+str(cell)+str(node.cast_shadow)
		if not groups.has(key):groups[key]=[]
		groups[key].append(node)
	var batched:=0
	for key in groups:
		var nodes: Array=groups[key]
		if nodes.size()<3:continue
		var unit:=BoxMesh.new();unit.size=Vector3.ONE
		unit.material=nodes[0].material_override if nodes[0].material_override else nodes[0].mesh.material
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=unit;multi.instance_count=nodes.size()
		var batch:=MultiMeshInstance3D.new();batch.name="WebStaticBatch";batch.multimesh=multi;batch.cast_shadow=nodes[0].cast_shadow
		game.hospital.add_child(batch)
		for i in nodes.size():
			var source: MeshInstance3D=nodes[i]
			var xf: Transform3D=source.global_transform
			xf.basis=xf.basis*Basis.from_scale(source.mesh.size)
			multi.set_instance_transform(i,batch.global_transform.affine_inverse()*xf)
			source.visible=false
		batched+=nodes.size()
	print("WEB_STATIC_BATCH instances=",batched)

func _process(delta: float) -> void:
	if effects_active():
		if is_instance_valid(dust) and dust.visible:
			dust_time+=delta
			dust_timer+=delta
			if dust_timer>=.05:
				dust_timer=fmod(dust_timer,.05)
				update_dust()
		shadow_timer+=delta
		if shadow_timer>=.5:
			shadow_timer=fmod(shadow_timer,.5)
			update_shadow_lights()
	if not diagnostic or not OS.has_feature("web"):return
	telemetry_timer+=delta
	if telemetry_timer>1:
		telemetry_timer=0
		var shadow_count:=0
		for light in shadow_lights:
			if light.shadow_enabled:shadow_count+=1
		if game.player.torch.shadow_enabled:shadow_count+=1
		var payload:=JSON.stringify({"fps":Engine.get_frames_per_second(),"quality":game.settings.quality,"stage":game.state.stage,"modal":game.hud.modal,"health":game.state.health,"seconds":snappedf(game.state.seconds,.1),"hasSave":game.has_save(),"shadow_lights":shadow_count,"scaling_3d":game.get_viewport().scaling_3d_scale})
		JavaScriptBridge.eval("window.RainrotWeb && window.RainrotWeb.telemetry("+payload+")",true)
