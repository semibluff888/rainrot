extends Node

var failures: Array[String] = []
var passed := 0
var report: Array = []

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ",message)
	else:
		failures.append(message)
		push_error("FAIL "+message)
	report.append({"name":message,"passed":condition})

func step(frames: int) -> void:
	for i in frames: await get_tree().physics_frame

func item(game: Node, id_: String) -> WardInteractable:
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.item_id==id_: return n
	return null

func run(game: Node) -> void:
	var s := WardState.new()
	check(not s.solve_cabinet("417"),"Cabinet rejects out-of-sequence completion")
	check(not s.solve_specimens(),"Archive rejects premature submission")
	check(not s.terminate(),"Termination requires underground access")
	s.breakers=[true,true,true,true]
	check(not s.solve_power(),"Overloaded power circuit rejected")
	s.breakers=[true,false,true,true]
	check(s.solve_power() and s.stage==1,"Correct circuit restores power")
	check(not s.solve_power(),"Power reward cannot repeat")
	check(not s.solve_cabinet("714"),"Wrong cabinet code rejected")
	s.inventory=[]
	for i in 6: s.add_supply("med",1)
	check(s.inventory.size()==6 and not s.add_supply("ammo",1),"Full six-slot inventory rejects supplies atomically")
	check(s.solve_cabinet("417") and s.keys.has("cold_key"),"Critical key obtained with full supply inventory")
	check(not s.solve_cabinet("417") and s.keys.count("cold_key")==1,"Cabinet reward cannot repeat")
	s.specimens=["14","09","23"]
	check(s.solve_specimens() and s.keys.has("lab_card"),"Correct tissue association grants access card")
	s.magazine=0
	s.inventory=[]
	check(s.terminate() and s.stage==4 and s.keys.has("evidence"),"Zero-ammo player can unlock escape")
	check(not s.terminate(),"Termination cannot repeat")
	var roundtrip := WardState.deserialize(JSON.parse_string(JSON.stringify(s.serialize())))
	check(roundtrip!=null and roundtrip.stage==4 and roundtrip.keys.has("evidence"),"Versioned JSON roundtrip preserves progression")
	check(WardState.deserialize({"version":999})==null,"Unsupported save versions rejected")
	check(WardState.deserialize(null)==null,"Corrupted save rejected")
	var bad := s.serialize()
	bad.inventory=[{"kind":"ammo","amount":-5}]
	check(WardState.deserialize(bad)==null,"Malformed inventory rejected")
	s = WardState.new()
	s.magazine=2
	check(s.reload()==6 and s.magazine==8 and s.reserve()==0 and s.inventory.size()==1,"Reload consumes reserve and releases slot")
	s.health=30
	check(s.heal(0) and s.health==85 and s.inventory.size()==0,"Treatment heals and releases inventory slot")
	s.add_supply("ammo",12)
	s.add_supply("ammo",7)
	check(s.reserve()==19 and s.inventory.size()==2,"Ammo stack limit respected")
	# Real scene validation.
	game.start_new()
	await step(20)
	check(game.player.is_on_floor(),"Player starts on a solid floor")
	check(get_tree().get_nodes_in_group("interactables").size()>=25,"World interactions installed")
	check(not item(game,"pharmacy_west").allowed(),"Pharmacy gate locked before restoration")
	check(not item(game,"cold_door").allowed(),"Cold room requires key")
	check(not item(game,"lab_door").allowed(),"Stairwell requires card")
	# Pickup idempotence by actual interaction node and persisted collection state.
	var ammo := item(game,"safe_ammo")
	ammo.interact()
	var reserve: int = game.state.reserve()
	ammo.interact()
	check(game.state.reserve()==reserve,"Repeated pickup interaction cannot duplicate ammunition")
	check(not ammo.visible and game.state.collected.has("safe_ammo"),"Pickup hides and records the collection")
	game.read_note("power")
	game.hud.close()
	game.read_note("power")
	game.hud.close()
	check(game.state.notes.count("power")==1,"Reading files twice does not duplicate journal")
	game.state.breakers=[true,false,true,true]
	game.state.solve_power()
	game.advance_stage()
	check(item(game,"pharmacy_west").allowed(),"Both power and gate state are connected")
	check(game.enemies[0].is_active,"First infection event activates enemy")
	game.state.solve_cabinet("417")
	game.advance_stage()
	game.state.specimens=["14","09","23"]
	game.state.solve_specimens()
	game.advance_stage()
	check(item(game,"lab_door").allowed(),"Archive unlocks physical stairwell door")
	# Open all unlocked doors then test physics locomotion through actual thresholds.
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.kind=="door" and not n.opened and n.allowed(): n.interact()
	for e in game.enemies: e.mode=WardEnemy.Mode.DEAD; e.collision_layer=0
	await step(60)
	game.player.position=Vector3(.0,.04,1)
	game.player.rotation.y=0
	Input.action_press("forward")
	await step(120)
	Input.action_release("forward")
	check(game.player.position.z < -3.4,"Walk traverses the corridor without collision traps")
	game.player.position=Vector3(0,.05,5)
	game.player.rotation.y=PI*.5
	Input.action_press("forward")
	await step(120)
	Input.action_release("forward")
	check(game.player.position.x < -4,"Open doorway passes full player capsule")
	game.player.position=Vector3(16.4,.05,-20)
	game.player.rotation.y=PI*.5
	Input.action_press("forward")
	await step(180)
	Input.action_release("forward")
	await step(15)
	print("STAIR_DOWN_POSITION ",game.player.position)
	check(game.player.position.x<10 and game.player.position.y < -2.1,"Staircase descends smoothly into laboratory")
	game.player.rotation.y=-PI*.5
	Input.action_press("forward")
	await step(260)
	Input.action_release("forward")
	await step(15)
	print("STAIR_UP_POSITION ",game.player.position)
	check(game.player.position.x>15.5 and game.player.position.y>-.3,"Staircase ascends with standing clearance")
	# Navigation connectivity uses baked mesh rather than teleporting enemies.
	var nav: NavigationRegion3D = game.hospital.get_node("Navigation")
	var map := nav.get_navigation_map()
	for endpoints in [[Vector3(0,0,5),Vector3(17.5,0,-25)],[Vector3(17.5,0,-20),Vector3(8,-3.2,-20)],[Vector3(0,0,-20),Vector3(-8,0,-20)]]:
		var path := NavigationServer3D.map_get_path(map,endpoints[0],endpoints[1],true)
		check(path.size()>1 and path[path.size()-1].distance_to(endpoints[1])<1.0,"Navigation connected: "+str(endpoints))
	# Physical save and restore, including collected objects and doors.
	game.state.magazine=0
	game.state.inventory=[]
	game.state.health=42
	game.player.position=Vector3(-6,.03,5)
	check(game.save_game(),"Atomic checkpoint write succeeds")
	game.state.health=1
	game.state.keys=[]
	game.load_game()
	await step(5)
	check(game.state.health==42 and game.state.keys.has("lab_card"),"Reload restores health and progression")
	check(not item(game,"safe_ammo").visible,"Reload does not respawn collected supplies")
	check(item(game,"safe_door").opened,"Reload restores door position")
	check(game.is_safe(),"Safe-room region correctly identified")
	game.player.damage(99)
	check(game.state.health==42,"Safe room prevents damage")
	game.player.position=Vector3(0,.02,8)
	game.player.hurt_left=0
	game.player.damage(99)
	check(game.hud.modal=="death","Lethal damage opens retry screen")
	game.load_game()
	check(game.hud.modal=="" and game.player.enabled,"Retry restores playable input")
	# Exercise hitscan through the camera ray, not direct health edits.
	game.player.position=Vector3(0,.03,-6)
	game.player.rotation.y=0
	game.player.pitch=0
	game.player.head.rotation=Vector3.ZERO
	game.state.magazine=6
	var victim: WardEnemy = game.enemies[0]
	victim.position=Vector3(0,.03,-9)
	victim.rotation.y=PI
	victim.set_physics_process(false)
	await step(3)
	var shot_direction: Vector3 = (victim.get_aim_point("head")-game.player.camera.global_position).normalized()
	game.player.rotation.y=atan2(-shot_direction.x,-shot_direction.z)
	game.player.pitch=asin(shot_direction.y)
	await step(3)
	game.player.fire()
	check(victim.hp<110 and game.state.magazine==5,"Camera hitscan damages visible enemy and consumes one round")
	await step(24)
	game.player.fire()
	check(victim.mode==WardEnemy.Mode.DEAD and game.state.dead_enemies.has(victim.enemy_id),"Headshots stop the infected and persist its death")
	game.hud.show_pause()
	var paused_position: Vector3 = game.player.position
	Input.action_press("forward")
	await step(30)
	Input.action_release("forward")
	check(game.player.position.is_equal_approx(paused_position),"Pause suppresses player movement")
	game.hud.close()
	# Threat senses use line-of-sight and a baked route through the environment.
	var hunter: WardEnemy = game.enemies[1]
	hunter.mode=WardEnemy.Mode.PATROL
	hunter.is_active=true
	hunter.visible=true
	hunter.collision_layer=2
	hunter.position=Vector3(17.5,.03,-9)
	hunter.rotation.y=0
	game.player.position=Vector3(17.5,.03,-15)
	await step(5)
	check(hunter.can_see_player(),"Enemy sees an unobstructed player")
	var before: float = hunter.position.distance_to(game.player.position)
	await step(90)
	check(hunter.mode==WardEnemy.Mode.CHASE and hunter.position.distance_to(game.player.position)<before-1,"Enemy follows navigation toward a seen target")
	game.player.position=Vector3(-7,.03,5)
	await step(10)
	check(not hunter.can_see_player() and hunter.mode==WardEnemy.Mode.PATROL,"Safe room breaks pursuit")
	game.state.terminate()
	game.advance_stage()
	check(game.enemies[3].is_active,"Final pursuer spawns on termination")
	var pursuer: WardEnemy = game.enemies[3]
	pursuer.take_hit(70,game.player.position)
	check(pursuer.mode==WardEnemy.Mode.STUN and pursuer.hp>0,"Final pursuer can be staggered but survives")
	game.state.magazine=0
	game.state.inventory=[]
	game.finish()
	check(game.finished and game.hud.modal=="ending","Zero-ammunition exit completes the chapter")
	var file := FileAccess.open("res://captures/test_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failures.size(),"checks":report},"\t"))
	print("TEST_RESULT passed=",passed," failed=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
