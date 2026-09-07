extends Node
## Behavioral regression checks exercise the live physics world and camera hitscan.
var game: Node
var results: Array = []
var failures := 0

func check(ok: bool,label_: String) -> void:
	results.append({"name":label_,"passed":ok})
	if not ok: failures+=1;push_error("ENEMY_FAIL "+label_)
	else: print("ENEMY_PASS ",label_)

func tick(frames: int=1) -> void:
	for i in frames: await get_tree().physics_frame

func aim(e: WardEnemy,zone: String) -> void:
	var d: Vector3 = (e.get_aim_point(zone)-game.player.camera.global_position).normalized()
	game.player.rotation.y=atan2(-d.x,-d.z)
	game.player.pitch=asin(d.y)
	game.player.recoil=0
	await tick(3)

func setup_enemy(index: int,range_: float=1.1) -> WardEnemy:
	for e in game.enemies:
		e.set_physics_process(false)
		e.collision_layer=0
		e.visual.set_hittable(false)
	var e: WardEnemy=game.enemies[index]
	game.hud.close();game.state.health=100;game.player.hurt_left=0
	game.player.enabled=true;game.player.position=Vector3(17.5,.03,-12)
	game.player.velocity=Vector3.ZERO
	e.position=Vector3(17.5,.03,-12-range_);e.rotation.y=PI
	e.velocity=Vector3.ZERO;e.is_active=true;e.visible=true;e.collision_layer=2
	e.hp=e.profile.max_health;e.mode=WardEnemy.Mode.CHASE;e.alert_consumed=true
	e.timer=0;e.attack_timer=0;e._cancel_attack();e.visual.set_hittable(true)
	e.set_physics_process(true)
	return e

func run(g: Node) -> void:
	game=g;game.start_new();await tick(10)
	for e in game.enemies:
		check(e.original_asset_loaded and e.visual.has_complete_animations(),e.enemy_id+" uses original model and seven gameplay clips")
		check(e.visual.hitboxes.size()>=2,e.enemy_id+" has separate bone hitboxes")
		check(e.profile.chase_speed==3.6 if e.pursuer else e.hp>=110,e.enemy_id+" profile baseline")
	game.state.stage=2
	for e in game.enemies:e.sync()
	check(not game.enemies[1].is_active,"Nurse remains dormant until first cold-room opening")
	game.state.collected.append("cold_event")
	for e in game.enemies:e.sync()
	check(game.enemies[1].is_active and game.enemies[1].anchor.is_equal_approx(Vector3(-5,.1,-32)),"Cold-room event activates nurse inside morgue")
	var nurse := setup_enemy(1,4)
	var sk: Skeleton3D=nurse.visual.find_children("*","Skeleton3D",true,false)[0]
	var old_rotations:Array[Quaternion]=[]
	for limb in 6:old_rotations.append(sk.get_bone_pose_rotation(sk.find_bone("Tendril_"+str(limb)+"_base")))
	nurse.set_physics_process(false);nurse.visual.set_state("run",0,true)
	for frame in 16:nurse.visual.advance(1.0/60,1.75);await tick()
	var moved:=0
	for limb in 6:
		if old_rotations[limb].angle_to(sk.get_bone_pose_rotation(sk.find_bone("Tendril_"+str(limb)+"_base")))>.01:moved+=1
	check(moved==6,"All six nurse appendages have independently animated support joints")
	for needle in ["NeedleL","NeedleR"]:
		var mount:BoneAttachment3D=sk.get_node(needle)
		var weapon:Node3D=mount.get_child(0)
		var mesh:MeshInstance3D=weapon.find_children("*","MeshInstance3D",true,false)[0]
		var nearest:=INF
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			nearest=minf(nearest,(mesh.global_transform*vertex).distance_to(mount.global_position))
		check(nearest<.35,"Nurse "+needle+" blade remains near the matching animated hand")
	nurse=setup_enemy(1,4)
	nurse.mode=WardEnemy.Mode.PATROL;nurse.alert_consumed=false
	await tick(3)
	check(nurse.mode==WardEnemy.Mode.ALERT,"First sight enters visible warning without moving camera")
	var camera_rotation: Vector3=game.player.rotation
	await tick(40)
	check(game.player.rotation.is_equal_approx(camera_rotation),"First appearance never forces player view")
	nurse.sync();check(nurse.mode==WardEnemy.Mode.ALERT,"Repeated sync does not restart encounter")
	await tick(45)
	check(nurse.mode==WardEnemy.Mode.CHASE,"Alert transitions to pursuit")
	for index in [0,1]:
		var e := setup_enemy(index,3.0);e.set_physics_process(false)
		e.visual.set_state("idle",0,true);e.visual.advance(.2)
		await tick(2)
		var point:=e.get_aim_point("head")
		e.visual.set_state("attack",e.profile.attack_duration(),true)
		for frame in int((e.profile.windup+.1)*60):
			e.visual.advance(1.0/60);await tick()
		await tick(2)
		check(e.get_aim_point("head").distance_to(point)>.05,e.enemy_id+" head target follows animated skeleton")
		for zone in ["head","body"]:
			e.hp=e.profile.max_health;e.mode=WardEnemy.Mode.CHASE
			e.visual.set_state("idle",0,true);e.visual.advance(.2);await tick(2)
			game.state.magazine=8;game.player.shot_left=0
			await aim(e,zone)
			game.player.fire()
			check(e.hp==e.profile.max_health-(70 if zone=="head" else 38),e.enemy_id+" real camera ray resolves "+zone+" damage")
			e.visual.set_quality(0)
			var texture: Texture2D=e.visual.low_materials[0].albedo_texture
			check(texture.get_width()<=512,e.enemy_id+" web low tier uses 512px texture")
	nurse=setup_enemy(1)
	check(nurse.profile.windup>=.65,"Nurse warning is at least 0.65 seconds")
	nurse._begin_attack();await tick(35)
	check(game.state.health==100,"Nurse cannot damage during windup")
	await tick(16)
	check(game.state.health==72 and nurse.strikes_landed==1,"Stab lands once at the telegraphed time")
	await tick(48)
	check(game.state.health==72 and nurse.strikes_landed==1,"Recovery cannot deal a second hit")
	nurse=setup_enemy(1);nurse._begin_attack();await tick(20)
	nurse.take_hit(38,game.player.position);await tick(30)
	check(game.state.health==100 and nurse.strike_resolved,"Bullet stagger cancels pending damage")
	nurse=setup_enemy(1);nurse._begin_attack();await tick(15)
	nurse.take_hit(1000,game.player.position);await tick(70)
	check(nurse.mode==WardEnemy.Mode.DEAD and game.state.health==100,"Death cancels attack and disables body")
	check(nurse.visual.hitboxes.all(func(h):return h.collision_layer==0),"Dead nurse has no bullet hitboxes")
	nurse=setup_enemy(1);nurse._begin_attack()
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,2.6,.15);shape.shape=box
	wall.add_child(shape);game.add_child(wall);wall.position=Vector3(17.5,1.3,-12.55)
	await tick(55)
	check(game.state.health==100,"Solid obstruction prevents close-range damage through a wall")
	wall.free()
	nurse=setup_enemy(1);nurse._begin_attack();await tick(10)
	for modal in ["inventory","note","pause"]:
		game.hud.modal=modal
		var pos:=nurse.position;var clock_:float=nurse.visual.animation_clock;var timer_:float=nurse.attack_elapsed
		game.audio.one("nurse_breath",-15,1,nurse.position,true)
		await tick(40)
		check(nurse.position.is_equal_approx(pos) and nurse.visual.animation_clock==clock_ and nurse.attack_elapsed==timer_ and game.state.health==100,modal+" freezes motion, animation, damage and windup")
		check(get_tree().get_nodes_in_group("enemy_audio").all(func(p):return p.stream_paused),modal+" pauses spatial creature sound")
	game.hud.close()
	nurse=setup_enemy(1);game.player.position=Vector3(-7,.03,5);await tick(5)
	check(nurse.mode==WardEnemy.Mode.PATROL and not nurse.can_see_player(),"Safe room breaks nurse pursuit")
	var elite:=setup_enemy(3,2)
	for shot in 20:elite.take_hit(70,game.player.position)
	check(elite.hp==elite.profile.max_health and elite.mode==WardEnemy.Mode.STUN,"Twenty headshots stagger elite without killing it")
	game.state.stage=3;game.state.keys=["cold_key","lab_card"]
	game.state.dead_enemies=["west_patient","east_patient"]
	game.player.position=Vector3(-6,.03,5)
	check(game.save_game(),"Version 1 enemy checkpoint writes successfully")
	game.load_game();await tick(3)
	check(game.state.serialize().version==1,"Save schema remains version 1")
	check(game.enemies[0].mode==WardEnemy.Mode.DEAD and game.enemies[1].mode==WardEnemy.Mode.DEAD,"Old enemy IDs retain death across load")
	check(game.enemies[2].alert_consumed and game.enemies[2].profile.role_id==&"smily","Living enemy restores role and skips first appearance")
	game.state.stage=4;game.state.keys.append("evidence");game.save_game();game.load_game();await tick(2)
	check(game.enemies[3].is_active and game.enemies[3].pursuer and game.enemies[3].alert_consumed,"Final checkpoint restores elite without replaying introduction")
	var f:=FileAccess.open("user://enemy_test_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":results.size()-failures,"failed":failures,"checks":results},"\t"))
	f.close()
	game.web.report("enemies",{"passed":results.size()-failures,"failed":failures,"checks":results})
	print("ENEMY_TEST_RESULT passed=",results.size()-failures," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)
