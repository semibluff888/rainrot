extends SceneTree
## Bakes editable AnimationPlayer tracks around the original, attributed rigs.
## Run after prepare_enemy_models.py, rig_nurse_limbs.py and editor import.

var visual: WardEnemyVisual
var skeleton: Skeleton3D
var motion: Node3D
var role := ""
var elite := false
var rest_world: Array[Basis] = []

func _initialize() -> void: call_deferred("run")

func owned(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		child.scene_file_path = ""
		owned(child,owner_)

func run() -> void:
	for id in ["smily","nurse","nurse_elite"]:
		role = "smily" if id == "smily" else "nurse"
		elite = id.ends_with("elite")
		visual = WardEnemyVisual.new()
		visual.name = "Smily" if role == "smily" else ("NurseElite" if elite else "Nurse")
		# Build off-tree so the adapter's _ready runs only once everything exists.
		motion = Node3D.new(); motion.name = "Motion"; visual.add_child(motion)
		var normal := Node3D.new(); normal.name = "Normalization"; motion.add_child(normal)
		var model: Node3D = load("res://assets/models/enemies/"+role+"/model.gltf").instantiate()
		model.name = "OriginalModel"; normal.add_child(model)
		root.add_child(visual)
		await process_frame
		skeleton = model.find_children("*","Skeleton3D",true,false)[0]
		for n in model.find_children("*","AnimationPlayer",true,false): n.free()
		for n in model.find_children("*","PhysicalBoneSimulator3D",true,false): n.free()
		# Smily looks toward +Z with an author rotation; nurse's covered face is -Z.
		normal.rotation.y = PI - .19 if role == "smily" else 0.0
		var bounds := skinned_bounds(model)
		var height := 1.9 if role == "smily" else (2.25 if elite else 2.06)
		var factor := height / bounds.size.y
		normal.scale *= factor
		# Center the silhouette at its footprint; the crouched face remains forward.
		normal.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
		if role == "nurse": attach_needles(model)
		setup_materials(model)
		rest_world.clear()
		for i in skeleton.get_bone_count():
			rest_world.append((skeleton.global_basis * skeleton.get_bone_global_rest(i).basis).orthonormalized())
		var head := "head_05" if role == "smily" else "spine.006_4"
		var chest := "chest_03" if role == "smily" else "spine.003_15"
		# Target centers are offsets in game meters, converted into bone space.
		visual.head_target_path = make_hitbox(head,"Head",Vector3(0,.12,-.025),Vector3(.27,.32,.28),"head")
		visual.body_target_path = make_hitbox(chest,"Torso",Vector3(0,-.03,0),Vector3(.49,.52,.37),"body")
		if role == "smily":
			make_hitbox("spinebase_01","Abdomen",Vector3(0,0,0),Vector3(.48,.4,.38),"body")
		else:
			make_hitbox("spine.001_17","Abdomen",Vector3.ZERO,Vector3(.38,.43,.32),"body")
		var ap := AnimationPlayer.new(); ap.name = "AnimationPlayer"; visual.add_child(ap)
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
		var lib := AnimationLibrary.new()
		for state in ["idle","alert","walk","run","attack","stun","dead","raise","stab","recover"]:
			lib.add_animation(state,make_animation(state))
			visual.animation_map[state] = state
		ap.add_animation_library("",lib)
		visual.source_verified = true
		visual.movement_reference_speed = .75 if role == "smily" else .65
		visual.run_reference_speed = 1.85 if role == "smily" else (3.6 if elite else 1.75)
		visual.animation_player_path = ^"AnimationPlayer"
		ap.play("idle"); ap.advance(0)
		owned(visual,visual)
		var packed := PackedScene.new()
		var status := packed.pack(visual)
		if status == OK: status = ResourceSaver.save(packed,"res://scenes/enemies/"+id+"_visual.tscn")
		print("BUILT_ENEMY ",id," result=",status," bones=",skeleton.get_bone_count()," clips=",ap.get_animation_list()," bounds=",bounds," scale=",factor)
		if status != OK: quit(1); return
		if role=="smily":
			# Pure display scene: no gameplay areas or adapter in a containment tank.
			for area in visual.find_children("*","Area3D",true,false): area.free()
			ap.free()
			visual.set_script(null)
			var specimen := PackedScene.new()
			specimen.pack(visual)
			ResourceSaver.save(specimen,"res://scenes/enemies/smily_specimen.tscn")
		visual.free()
	quit()

func skinned_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var point := mesh.global_transform * vertices[i]
				if mesh.skin:
					point = Vector3.ZERO
					for j in 4:
						var bind: int = arrays[Mesh.ARRAY_BONES][i*4+j]
						var bone := mesh.skin.get_bind_bone(bind)
						if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
						point += skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[i] * arrays[Mesh.ARRAY_WEIGHTS][i*4+j]
				if first: bounds=AABB(point,Vector3.ZERO);first=false
				else: bounds=bounds.expand(point)
	return bounds

func attach_needles(model: Node3D) -> void:
	for side in ["L","R"]:
		var matches := model.find_children("Weapon_"+side+"*","Node3D",true,false)
		if matches.is_empty(): continue
		var weapon: Node3D = matches[0]
		var before := weapon.global_transform
		var attachment := BoneAttachment3D.new()
		attachment.name = "Needle"+side
		skeleton.add_child(attachment)
		# Source weapon labels are opposite the armature's anatomical L/R labels.
		attachment.bone_name = "hand.R_11" if side == "L" else "hand.L_7"
		attachment.transform = skeleton.get_bone_global_rest(skeleton.find_bone(attachment.bone_name))
		weapon.reparent(attachment,false)
		weapon.transform = attachment.global_transform.affine_inverse() * before

func make_hitbox(bone_name: String, label: String, offset: Vector3, size_: Vector3, zone: String) -> NodePath:
	var attachment := BoneAttachment3D.new()
	attachment.name = label+"Attachment"
	skeleton.add_child(attachment)
	attachment.bone_name = bone_name
	attachment.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))
	var area := WardEnemyHitbox.new(); area.name=label+"Hitbox"; area.zone=zone
	attachment.add_child(area)
	# Cancel rest scale/orientation so collision shape dimensions use real meters.
	area.basis = attachment.global_basis.inverse()
	area.position = attachment.global_basis.inverse() * offset
	var shape := CollisionShape3D.new();shape.name="Shape"
	var box := BoxShape3D.new(); box.size=size_; shape.shape=box
	area.add_child(shape)
	var marker := Marker3D.new();marker.name="AimPoint";area.add_child(marker)
	return visual.get_path_to(marker)

func setup_materials(model: Node3D) -> void:
	var directory := "res://materials/enemies/"+role+"/"
	DirAccess.make_dir_recursive_absolute(directory)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.extra_cull_margin = 2.5
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(surface) as StandardMaterial3D
			if not mat: continue
			var high := mat.duplicate() as StandardMaterial3D
			high.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			high.metallic = .02 if "Metal" not in mat.resource_name else .65
			high.roughness = .72 if "Hair" in mat.resource_name else .83
			high.albedo_color = Color(.82,.86,.83,1) if role == "smily" else Color(.83,.87,.85,1)
			if "Hair" in mat.resource_name or "Dress" in mat.resource_name:
				high.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				high.alpha_scissor_threshold = .4
				high.cull_mode = BaseMaterial3D.CULL_DISABLED
			var low := high.duplicate() as StandardMaterial3D
			for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_ROUGHNESS,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
				var texture := high.get_texture(slot)
				if texture:
					var path := texture.resource_path.replace("/high/","/low/")
					if ResourceLoader.exists(path): low.set_texture(slot,load(path))
			var name_ := str(mesh.name)+"_"+str(surface)
			ResourceSaver.save(high,directory+name_+"_high.tres")
			ResourceSaver.save(low,directory+name_+"_low.tres")
			mesh.set_surface_override_material(surface,high)
			visual.high_materials.append(high);visual.low_materials.append(low)
			visual.material_mesh_paths.append(visual.get_path_to(mesh));visual.material_surface_indices.append(surface)

func duration(state: String) -> float:
	match state:
		"idle": return 4.2
		"alert": return 1.35 if role=="smily" else 1.2
		"walk": return 1.65 if role=="smily" else 1.8
		"run": return .86 if role=="smily" else (.64 if elite else .95)
		"attack": return 1.35 if role=="smily" else (1.57 if elite else 1.78)
		"stun": return .9
		"dead": return 1.7
		"raise": return .75
		"stab": return .18
		"recover": return .85
	return 1

func make_animation(state: String) -> Animation:
	var clip := Animation.new(); clip.length=duration(state); clip.resource_name=state
	if state in ["idle","walk","run"]: clip.loop_mode=Animation.LOOP_LINEAR
	var path := str(visual.get_path_to(skeleton))
	var tracks: Array[int] = []
	for i in skeleton.get_bone_count():
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(path+":"+skeleton.get_bone_name(i)))
		tracks.append(track)
	var pos_track := clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(pos_track,^"Motion:position")
	var rot_track := clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(rot_track,^"Motion:rotation")
	var samples := ceili(clip.length*24)
	for frame in samples+1:
		var t := float(frame)/samples
		var time := t*clip.length
		for bone in skeleton.get_bone_count():
			var angles := pose(skeleton.get_bone_name(bone),state,t)
			var q := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			# Express animator's game-space axes in each bone's local frame.
			for axis in 3:
				if absf(angles[axis]) > .00001:
					q = q * Quaternion((rest_world[bone].inverse() * Vector3(1 if axis==0 else 0,1 if axis==1 else 0,1 if axis==2 else 0)).normalized(),angles[axis])
			clip.rotation_track_insert_key(tracks[bone],time,q.normalized())
		var p := Vector3.ZERO
		var rot := Vector3.ZERO
		var phase := t*TAU
		if state in ["walk","run"]: p.y = .018*(1-cos(phase*2)); rot.z=.017*sin(phase)
		elif state == "idle": p.y = .006*sin(phase)
		elif state in ["attack","raise","stab","recover"]:
			var a := attack_phase(state,t)
			p.y = a.x*(.12 if role=="nurse" else .03)-a.y*.04
			p.z = -a.y*.18;rot.x=-a.y*.1
		elif state == "stun": rot.x=sin(t*PI)*.14;rot.z=sin(t*PI*2)*.07
		elif state == "dead":
			var fall := smoothstep(.15,.78,t)
			rot.x = -1.44*fall;rot.z=.2*fall
			p.y=(.55 if role=="smily" else .24)*fall;p.z=-.18*fall
		if elite and state != "dead": p.y += .06
		clip.track_insert_key(pos_track,time,p)
		clip.track_insert_key(rot_track,time,rot)
	if state in ["walk","run"]:
		var method := clip.add_track(Animation.TYPE_METHOD);clip.track_set_path(method,^".")
		for point in [[.08,"left"],[.58,"right"]]:
			clip.track_insert_key(method,clip.length*point[0],{"method":&"emit_contact","args":[point[1]]})
	return clip

func attack_phase(state: String,t: float) -> Vector2:
	var f := t
	if state == "raise": f=t*.42
	elif state == "stab": f=.42+t*.10
	elif state == "recover": f=.52+t*.48
	var windup := .7/1.57 if elite else (.75/1.78 if role=="nurse" else .55/1.35)
	var raised := smoothstep(0,windup*.85,f)*(1-smoothstep(windup+.12,.92,f))
	var thrust := smoothstep(windup-.045,windup+.07,f)*(1-smoothstep(windup+.13,.93,f))
	return Vector2(raised,thrust)

func pose(bone: String,state: String,t: float) -> Vector3:
	var a := Vector3.ZERO
	var phase := t*TAU
	var left := ".L" in bone
	var sign_ := 1.0 if left else -1.0
	var moving := state in ["walk","run"]
	var stride := (1.0 if state=="run" else .62)
	if role == "smily":
		if bone=="head_05":
			a.z=.08; a.y=.04*sin(phase)
			if state=="alert": a.y=-.65*(1-smoothstep(.15,.7,t));a.z=.08+.16*sin(t*PI)
			if moving:a.x=.04*sin(phase*2);a.y=.05*sin(phase)
		if bone=="jaw_06": a.x=.025*sin(phase*2)
		if bone=="chest_03": a.x=.06;a.z=.02*sin(phase)
		if moving:
			if bone.begins_with("leg."):a.x=sin(phase+(0 if left else PI))*.27*stride
			if bone.begins_with("sheen."):a.x=maxf(0,-sin(phase+(0 if left else PI)))*.16*stride
			if bone.begins_with("Arm."):a.x=-sin(phase+(0 if left else PI))*.20*stride
			if bone.begins_with("Forearm."):a.x=.1*maxf(0,sin(phase+(0 if left else PI)))
		if state in ["attack","raise","stab","recover"]:
			var f:=attack_phase(state,t)
			if bone.begins_with("Arm."):a.x=f.x*.42+f.y*.8;a.z=-sign_*f.x*.12
			if bone.begins_with("Forearm."):a.x=-f.x*.5+f.y*.4
			if bone=="chest_03":a.x=-f.y*.18
			if bone=="jaw_06":a.x=f.x*.2
	else:
		if bone.begins_with("Tendril_"):
			var n := int(bone.get_slice("_",1));var side := -1.0 if n in [0,3,4] else 1.0
			var cycle: float = phase+(0 if n%2==0 else PI)
			var tip := bone.ends_with("tip")
			if moving:
				a.x=sin(cycle)*(.17 if tip else .1)*stride
				a.z=side*maxf(0,cos(cycle))*(.13 if tip else .055)*stride
			else: a.x=.015*sin(phase+n*.7)
			if elite: a.z += side*(.035 if tip else .045)
			if state in ["attack","raise","stab","recover"]:
				var f:=attack_phase(state,t)
				a.z+=side*f.x*(.16 if tip else .1);a.x-=f.y*.12
		if bone.begins_with("upper_arm"):
			a.x=.08;a.z=sign_*(.05 if elite else -.04)
			if moving:a.x+=sin(phase+(0 if left else PI))*.14*stride
		if bone.begins_with("spine.003"):a.z=.025*sin(phase)
		if bone.begins_with("spine.006"):
			a.z=-.09;a.x=.1
			if state=="alert":a.y=.45*(1-smoothstep(.1,.8,t));a.x=-.18*sin(t*PI)
		if state in ["attack","raise","stab","recover"]:
			var f:=attack_phase(state,t)
			if bone.begins_with("upper_arm"):a.x=f.x*.38+f.y*1.12;a.z=sign_*(f.x*.24-f.y*.26)
			if bone.begins_with("forearm"):a.x=-f.x*.6+f.y*.8
			if bone.begins_with("hand."):a.x=f.y*.55
			if bone.begins_with("spine.003"):a.x=-f.y*.13
	if state=="stun":
		if "head" in bone or "spine.006" in bone:a.x=-sin(t*PI)*.25;a.z=.2*sin(t*PI)
		if "Arm." in bone or "upper_arm" in bone:a.x=-.25*sin(t*PI)
	if state=="dead":
		if "Arm." in bone or "upper_arm" in bone:a.x=.5*smoothstep(.1,.7,t)
		if role=="smily" and bone.begins_with("leg."):a.x=1.1*smoothstep(.2,.9,t)
		if role=="smily" and bone.begins_with("sheen."):a.x=-.4*smoothstep(.3,.9,t)
		if bone.begins_with("Tendril_"):a.z=sin(float(int(bone.get_slice("_",1))))*.45*smoothstep(.1,.8,t)
	return a
