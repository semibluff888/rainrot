extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.035,.045,.055)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.7,.8,1)
	e.ambient_light_energy = .7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 2
	world.add_child(light)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for role in ["smily","nurse"]:
		var model: Node3D = load("res://assets/models/enemies/"+role+"/model.gltf").instantiate()
		world.add_child(model)
		await process_frame
		var sk: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
		var bb := AABB()
		var first := true
		for m: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for s in m.mesh.get_surface_count():
				var a: Array = m.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				for i in vs.size():
					var p: Vector3 = m.global_transform * vs[i]
					if m.skin:
						p = Vector3.ZERO
						for j in 4:
							var bi: int = a[Mesh.ARRAY_BONES][i*4+j]
							var bone: int = m.skin.get_bind_bone(bi)
							if bone < 0: bone = sk.find_bone(m.skin.get_bind_name(bi))
							p += sk.global_transform * sk.get_bone_global_pose(bone) * m.skin.get_bind_pose(bi) * vs[i] * a[Mesh.ARRAY_WEIGHTS][i*4+j]
					if first: bb = AABB(p,Vector3.ZERO);first=false
					else: bb = bb.expand(p)
		print("SKIN_BOUNDS ",role," ",bb," SKELETON ",sk.global_transform)
		var s := 2.0 / bb.size.y
		model.scale *= s
		model.position = -Vector3(bb.get_center().x,bb.position.y,bb.get_center().z)*s
		cam.position = Vector3(3,1.7,4)
		cam.look_at(Vector3(0,1,0))
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/raw_"+role+".png")
		model.free()
	quit()
