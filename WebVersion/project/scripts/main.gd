extends Node3D

const G = preload("res://tools/geometry.gd")
const ENEMY_SPAWNS = [
	{"id":"west_patient", "position":Vector3(.3,.1,-28.5), "stage":1, "profile":"smily"},
	{"id":"east_patient", "position":Vector3(-5.0,.1,-32.0), "stage":2, "profile":"nurse"},
	{"id":"ward_patient", "position":Vector3(-6.7,.1,-22), "stage":3, "profile":"smily"},
	{"id":"the_orderly", "position":Vector3(12,-3.1,-25), "stage":4, "profile":"nurse_elite"},
]
var state := WardState.new()
var settings: Dictionary = {"sensitivity":1.0,"brightness":1.08,"volume":.75,"bob":.65,"quality":1}
var web: WardWebPlatform
var player: WardPlayer
var hud: WardHUD
var audio: WardAudio
var hospital: Node3D
var enemies: Array[WardEnemy] = []
var started := false
var finished := false
var danger := 0.0
var lightning := 0.0
var elapsed := 0.0
var stage_time := 0.0
var save_path := "user://progress.json"
var automated := false
var frame_times: Array[float] = []
var sound_stage := -1
var spooky_timer := 36.0

func _ready() -> void:
	setup_input()
	load_settings()
	automated = OS.get_cmdline_user_args().has("--test") or OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--benchmark") or OS.get_cmdline_user_args().has("--walkthrough")
	automated = automated or OS.get_cmdline_user_args().has("--enemy-test") or OS.get_cmdline_user_args().has("--enemy-showcase")
	if automated: save_path = "user://"+("capture" if OS.get_cmdline_user_args().has("--capture") else "test")+"_progress.json"
	hospital = load("res://scenes/hospital.tscn").instantiate()
	add_child(hospital)
	player = WardPlayer.new()
	player.name = "Investigator"
	player.game = self
	add_child(player)
	player.position = state.position
	audio = WardAudio.new()
	audio.game = self
	add_child(audio)
	hud = WardHUD.new()
	hud.game = self
	add_child(hud)
	web=WardWebPlatform.new()
	web.game=self
	add_child(web)
	for item in get_tree().get_nodes_in_group("interactables"):
		item.game = self
		item.sync()
	spawn_chapter_enemies()
	apply_settings()
	menu_camera()
	web.mode_changed("menu")
	if OS.get_cmdline_user_args().has("--test"):
		call_deferred("run_tests")
	elif OS.get_cmdline_user_args().has("--capture"):
		call_deferred("capture_gallery")
	elif OS.get_cmdline_user_args().has("--benchmark"):
		call_deferred("run_benchmark")
	elif OS.get_cmdline_user_args().has("--walkthrough"):
		call_deferred("run_walkthrough")
	elif OS.get_cmdline_user_args().has("--enemy-test"):
		call_deferred("run_enemy_tests")
	elif OS.get_cmdline_user_args().has("--enemy-showcase"):
		call_deferred("run_enemy_showcase")

func setup_input() -> void:
	var actions := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"crouch":KEY_CTRL,"interact":KEY_E,"flashlight":KEY_F,"reload":KEY_R,"inventory":KEY_TAB,"journal":KEY_J,"pause":KEY_ESCAPE,"fullscreen":KEY_F11}
	for action in actions:
		if action=="fullscreen" and OS.has_feature("web"):continue
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = actions[action]
		InputMap.action_add_event(action,event)
	for pair in [["fire",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(pair[0])
		var event := InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0],event)

func spawn_chapter_enemies() -> void:
	for entry in ENEMY_SPAWNS:
		spawn_enemy(entry.id, entry.position, entry.stage, entry.profile == "nurse_elite", entry.profile)

func spawn_enemy(id_: String, pos: Vector3, stage: int, is_pursuer: bool=false, profile_id: String="smily") -> void:
	var e := WardEnemy.new()
	e.name = id_
	e.game = self
	e.enemy_id = id_
	e.activation_stage = stage
	e.pursuer = is_pursuer
	e.profile = load("res://scenes/enemies/"+profile_id+".tres")
	e.position = pos
	add_child(e)
	enemies.append(e)

func menu_camera() -> void:
	player.enabled = false
	player.position = Vector3(.75,.08,11)
	player.rotation.y = .028
	player.head.rotation = Vector3(-.025,0,0)
	player.gun.visible = false
	player.torch.visible = false

func reset_world(restoring: bool=false) -> void:
	for e in enemies: e.free()
	enemies.clear()
	spawn_chapter_enemies()
	for item in get_tree().get_nodes_in_group("interactables"):
		item.visible = true
		item.collision_layer = 20 if item.kind in ["door","exit"] else 16
		item.busy = false
		item.sync()
	for e in enemies: e.sync(restoring)
	player.velocity = Vector3.ZERO
	player.position = state.position
	player.rotation.y = state.yaw
	player.pitch = 0
	player.head.rotation = Vector3.ZERO
	player.head.position.y = 1.62
	player.reload_left = 0
	player.shot_left = 0
	player.hurt_left = 0
	player.stamina = 100
	player.gun.visible = true
	player.torch.visible = true
	player.flashlight_on = true
	player.enabled = true
	stage_time = 0
	finished = false
	started = true
	hud.close()
	apply_settings()

func start_new() -> void:
	state = WardState.new()
	reset_world()
	save_game()
	hud.toast("23:58 · 圣维罗妮卡疗养院\nWASD 移动   /   E 调查   /   F 手电   /   J 日志与地图",9)

func return_to_menu() -> void:
	started = false
	finished = false
	danger = 0
	menu_camera()
	hud.show_menu()

func read_note(id_: String) -> void:
	if not WardContent.NOTES.has(id_): return
	if not state.notes.has(id_): state.notes.append(id_)
	audio.one("click",-22,.8)
	hud.show_note(id_)

func is_safe() -> bool:
	if not is_instance_valid(player): return false
	return is_safe_position(player.global_position)

func is_safe_position(p: Vector3) -> bool:
	return p.x < -3.1 and p.z>1 and p.z<9 and p.y>-.5

func advance_stage() -> void:
	stage_time = 0
	audio.one("sting",-16,.85)
	for e in enemies: e.sync()
	if state.stage==4:
		# Existing corpses remain corpses. The pursuer starts behind the escape route.
		audio.one("alarm",-22)
	if state.stage!=4: save_game()
	apply_settings()

func save_game() -> bool:
	state.position = player.position
	state.yaw = player.rotation.y
	var data := JSON.stringify(state.serialize(),"\t")
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if not file:
		if is_instance_valid(hud): hud.toast("记录失败：无法写入存档目录")
		return false
	file.store_string(data)
	file.flush()
	file.close()
	var result := DirAccess.rename_absolute(save_path+".tmp",save_path)
	if result != OK:
		hud.toast("记录失败：存档文件不可替换")
		return false
	if is_instance_valid(web):web.persist()
	return true

func has_save() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return WardState.deserialize(parsed) != null

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		hud.toast("还没有可用记录")
		return
	var loaded := WardState.deserialize(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	if loaded == null:
		hud.toast("记录文件无法读取 · 可以从主菜单开始新的调查")
		return
	state = loaded
	reset_world(true)
	hud.toast("从最近的记录醒来",4)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for key in settings:
			var value = cfg.get_value("settings",key,settings[key])
			if value is float or value is int: settings[key] = value
	settings.sensitivity = clampf(settings.sensitivity,.3,2.5)
	settings.brightness = clampf(settings.brightness,.75,1.45)
	settings.volume = clampf(settings.volume,0,1)
	settings.bob = clampf(settings.bob,0,1)
	settings.quality = clampi(int(settings.quality),0,2)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings: cfg.set_value("settings",key,settings[key])
	cfg.save("user://settings.cfg")
	if is_instance_valid(web):web.persist()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(settings.volume) if settings.volume>0 else -80)
	if is_instance_valid(web):
		web.apply_quality(int(settings.quality))
		return
	if not is_instance_valid(hospital): return
	var env: Environment = hospital.get_node("Atmosphere").environment
	var q: int = settings.quality
	env.ssao_enabled = q>=1
	env.ssil_enabled = q>=2
	env.ssr_enabled = q>=2
	env.volumetric_fog_enabled = q>=1
	get_viewport().scaling_3d_scale = [0.72,.85,1.0][q]
	get_viewport().msaa_3d = Viewport.MSAA_2X if q==2 else Viewport.MSAA_DISABLED
	get_viewport().use_taa = q>=1
	for light in get_tree().get_nodes_in_group("moonlights"): light.shadow_enabled = q>=1
	for enemy in enemies: enemy.visual.set_quality(q)

func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.RainrotWeb && window.RainrotWeb.fullscreen()",true)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func make_noise(where: Vector3, radius: float) -> void:
	for e in enemies: e.hear(where,radius)

func impact(pos: Vector3, normal: Vector3) -> void:
	var material := G.material(Color(.015,.016,.014))
	var mark := G.sphere(self,pos+normal*.004,Vector3(.028,.028,.028),material)
	get_tree().create_timer(25).timeout.connect(mark.queue_free)

func die() -> void:
	player.enabled = false
	hud.show_death()

func finish() -> void:
	if state.stage!=4: return
	finished = true
	player.enabled = false
	player.gun.visible = false
	player.position = Vector3(0,.1,21)
	player.rotation.y = PI
	danger = 0
	hud.show_ending()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and started and hud.modal=="" and not automated: hud.show_pause()

func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(hud): return
	if not started:
		player.head.rotation.y = sin(elapsed*.065)*.023
	if started and not finished and hud.modal=="" and not web.input_suspended():
		state.seconds += delta
		stage_time += delta
		spooky_timer -= delta
		if spooky_timer<0 and not is_safe():
			spooky_timer = randf_range(34,61)
			audio.one("door",-18,.55,player.global_position+Vector3(6,0,-9))
		if player.position.y < -8:
			load_game()
	var closest := 100.0
	for e in enemies:
		if e.mode in [WardEnemy.Mode.CHASE,WardEnemy.Mode.ATTACK] and not is_safe(): closest = minf(closest,e.global_position.distance_to(player.global_position))
	var target_danger := clampf(1-closest/19,0,1) if started and not finished else 0.0
	danger = lerpf(danger,target_danger,delta*1.5)
	lightning = maxf(0,lightning-delta*2.4)
	for l in get_tree().get_nodes_in_group("moonlights"):
		l.light_energy = float(l.get_meta("energy",3.8))*(1+lightning*3.8)
	for l in get_tree().get_nodes_in_group("power_lights"):
		var base: float = l.get_meta("energy",1.5)
		var flicker := 1.0
		if sin(elapsed*9+l.position.z)*sin(elapsed*13+l.position.x)>.88: flicker=.12
		if state.stage==0: flicker *= .20
		elif state.stage!=4 and (state.stage>=3 or state.collected.has("cold_event")):
			flicker *= .24 if int(abs(l.position.z))%3==0 else .63
		if state.stage==4:
			l.light_color = Color(.9,.13,.045)
			flicker *= .6+.4*sin(elapsed*4)
		else: l.light_color = Color(1,.67,.35) if base>1.8 else Color(.4,.72,.73)
		l.light_energy = base*flicker

func wait_frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func run_tests() -> void:
	await wait_frames(5)
	var test = load("res://tests/integration.gd").new()
	add_child(test)
	await test.run(self)

func run_enemy_tests() -> void:
	await wait_frames(5)
	var test = load("res://tests/enemies.gd").new()
	add_child(test)
	await test.run(self)

func run_enemy_showcase() -> void:
	await wait_frames(5)
	var show = load("res://tools/enemy_showcase.gd").new()
	add_child(show)
	await show.run(self)

func run_walkthrough() -> void:
	await wait_frames(5)
	var test = load("res://tests/walkthrough.gd").new()
	add_child(test)
	await test.run(self)

func capture_gallery() -> void:
	DisplayServer.window_set_size(Vector2i(1920,1080))
	await wait_frames(120)
	await screenshot("01_title")
	start_new()
	hud.notice_time=0
	await wait_frames(60)
	await screenshot("02_reception")
	state.stage=1
	player.position=Vector3(.3,.05,-4)
	player.rotation.y=0
	await wait_frames(70)
	await screenshot("03_corridor")
	player.position=Vector3(-5.4,.05,-18.8)
	player.rotation.y=PI*.5
	await wait_frames(60)
	await screenshot("04_ward")
	state.stage=3
	player.position=Vector3(9,-3.15,-22)
	player.rotation.y=.28
	await wait_frames(60)
	await screenshot("05_laboratory")
	player.position=Vector3(.1,.05,-9)
	player.rotation.y=0
	player.pitch=0
	enemies[0].position=Vector3(.1,.05,-12)
	enemies[0].rotation.y=PI
	enemies[0].sync()
	enemies[0].set_physics_process(false)
	await wait_frames(50)
	await screenshot("08_patient")
	enemies[0].visible=false
	hud.show_puzzle("power")
	await wait_frames(10)
	await screenshot("06_power")
	hud.show_inventory()
	await wait_frames(10)
	await screenshot("07_inventory")
	read_note("power")
	await wait_frames(10)
	await screenshot("09_archive")
	hud.show_journal()
	await wait_frames(10)
	await screenshot("10_journal")
	state.keys.append("lab_card")
	hud.show_inspect("lab_card")
	await wait_frames(20)
	await screenshot("11_inspect")
	print("CAPTURE_COMPLETE")
	get_tree().quit()

func screenshot(id_: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://captures/"+id_+".png")
	print("CAPTURE ",id_," ",image.get_size())

func run_benchmark() -> void:
	DisplayServer.window_set_size(Vector2i(1920,1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	start_new()
	await wait_frames(180)
	var results: Array = []
	settings.quality=2
	apply_settings()
	state.collected.append("cold_event")
	for shot in [["corridor_smily",Vector3(0,.05,-8),0.0,1,0,Vector3(0,.05,-12)],["morgue_nurse",Vector3(-4.5,.05,-35.2),-.3,2,1,Vector3(-5.5,.05,-31.7)],["laboratory_nurse",Vector3(9,-3.1,-20),0.0,4,3,Vector3(9,-3.1,-24)],["pursuit_nurse",Vector3(17.5,.05,-13),0.0,4,3,Vector3(17.5,.05,-17)]]:
		state.stage = shot[3]
		player.position = shot[1]
		player.rotation.y = shot[2]
		for e in enemies: e.sync()
		for e in enemies:
			e.set_physics_process(false)
			e.visible=false
		var featured: WardEnemy=enemies[shot[4]]
		featured.position=shot[5];featured.rotation.y=PI
		featured.visible=true;featured.is_active=true;featured.mode=WardEnemy.Mode.CHASE
		featured.set_physics_process(true)
		var look_direction:Vector3=(featured.get_aim_point("body")-player.camera.global_position).normalized()
		player.rotation.y=atan2(-look_direction.x,-look_direction.z);player.pitch=asin(look_direction.y)
		player.head.rotation.x=player.pitch
		await wait_frames(60)
		# Fix the camera while keeping enemy simulation and effects active.
		player.enabled=false
		var samples: Array[float] = []
		var gpu_sum := 0.0
		var cpu_sum := 0.0
		for i in 300:
			state.health=100
			var before := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			samples.append((Time.get_ticks_usec()-before)/1000.0)
			gpu_sum+=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			cpu_sum+=RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		await screenshot("benchmark_"+shot[0])
		samples.sort()
		var sum := 0.0
		for s in samples: sum+=s
		results.append({"scene":shot[0],"average_ms":sum/samples.size(),"p95_ms":samples[int(samples.size()*.95)],"fps":1000/(sum/samples.size()),"gpu_ms":gpu_sum/300,"render_cpu_ms":cpu_sum/300,"draw_calls":get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
	var file := FileAccess.open("res://captures/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"resolution":[1920,1080],"quality":settings.quality,"results":results},"\t"))
	print("BENCHMARK ",JSON.stringify(results))
	get_tree().quit()
