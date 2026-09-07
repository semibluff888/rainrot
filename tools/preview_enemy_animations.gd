extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,900))
	var world := Node3D.new();root.add_child(world)
	var env := WorldEnvironment.new();var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color(.025,.034,.045)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.6,.72,.85);e.ambient_light_energy=.6
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,145,0);light.light_energy=1.7;world.add_child(light)
	var fill:=OmniLight3D.new();fill.position=Vector3(-2,2,1);fill.light_color=Color(.2,.55,.7);fill.light_energy=3;world.add_child(fill)
	var floor_:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor_.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.08,.09,.1);mat.roughness=.65;floor_.material_override=mat;world.add_child(floor_)
	var cam:=Camera3D.new();world.add_child(cam);cam.current=true;cam.fov=43
	cam.position=Vector3(2.8,1.8,-5.3);cam.look_at(Vector3(0,1.04,0))
	for role in ["smily","nurse","nurse_elite"]:
		var model: WardEnemyVisual = load("res://scenes/enemies/"+role+"_visual.tscn").instantiate();world.add_child(model)
		for pose_ in [["idle",0.0],["run",.26],["attack",.8],["dead",1.7]]:
			model.set_state(pose_[0]);model.player.advance(.2);model.player.seek(pose_[1],true)
			for frame in 5:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://captures/pose_"+role+"_"+pose_[0]+".png")
			print("POSE ",role," ",pose_[0]," head=",model.get_aim_point()," body=",model.get_aim_point("body"))
		model.free()
	quit()
