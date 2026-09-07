extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for role in ["smily", "nurse"]:
		var scene: PackedScene = load("res://assets/models/enemies/"+role+"/model.gltf")
		if not scene: quit(1); return
		var model := scene.instantiate()
		root.add_child(model)
		await process_frame
		var result := {"role":role,"nodes":[],"skeletons":[],"meshes":[],"animations":[]}
		for n in model.find_children("*", "Node", true, false):
			if n is Node3D:
				result.nodes.append({"path":str(model.get_path_to(n)),"type":n.get_class(),"position":str(n.position),"scale":str(n.scale)})
			if n is Skeleton3D:
				var bones: Array = []
				for i in n.get_bone_count():
					bones.append({"index":i,"name":n.get_bone_name(i),"parent":n.get_bone_parent(i),"rest_position":str(n.get_bone_rest(i).origin),"world_position":str(n.global_transform*n.get_bone_global_rest(i).origin),"rest_rotation":str(n.get_bone_rest(i).basis.get_rotation_quaternion())})
				result.skeletons.append({"path":str(model.get_path_to(n)),"bones":bones})
			if n is MeshInstance3D:
				var mats: Array = []
				for i in n.mesh.get_surface_count():
					var mat: Material = n.get_active_material(i)
					mats.append({"index":i,"name":mat.resource_name if mat else "none"})
				result.meshes.append({"path":str(model.get_path_to(n)),"aabb":str(n.global_transform*n.get_aabb()),"skeleton":str(n.skeleton),"materials":mats})
			if n is AnimationPlayer:
				for name_ in n.get_animation_list():
					var clip: Animation = n.get_animation(name_)
					result.animations.append({"name":name_,"length":clip.length,"tracks":clip.get_track_count()})
		var file := FileAccess.open("res://.runtime/monster_sources/"+role+"_godot_report.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
		print("MODEL_REPORT ",role," ",JSON.stringify(result.skeletons)," ANIM ",result.animations)
		model.free()
	quit()
