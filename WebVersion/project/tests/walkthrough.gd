extends Node

# A continuous physical route: no teleportation after start, no health override,
# no disabled enemies, no direct puzzle-state changes. Uses real interact rays/UI callbacks.
# Exploration uses the normal starting weapon. Final pursuit is forced to zero ammunition.
var game: Node
var steps: Array = []
var failed := false
var sprinting := false
var pacifist := false

func physics(frames: int=1) -> void:
	for i in frames: await get_tree().physics_frame

func fail(message: String) -> void:
	failed=true
	push_error("WALKTHROUGH_FAIL "+message+" position="+str(game.player.position))
	finish_report()
	get_tree().quit(1)

func record(message: String) -> void:
	steps.append({"event":message,"seconds":game.state.seconds,"health":game.state.health,"position":[game.player.position.x,game.player.position.y,game.player.position.z]})
	print("ROUTE ",message," HP=",game.state.health," time=",snappedf(game.state.seconds,.1))

func walk(x: float, z: float, y: float=0, run_: bool=false) -> void:
	if failed:return
	if pacifist and game.state.stage<4:run_=true
	game.player.pitch=0
	var target := Vector3(x,y,z)
	var frames := 0
	while Vector2(game.player.position.x-x,game.player.position.z-z).length()>.25 and frames<1800:
		if game.state.health<=0:
			fail("Player died en route to "+str(target));return
		if game.state.health<38:
			for i in game.state.inventory.size():
				if game.state.inventory[i].kind=="med": game.state.heal(i);break
		if game.state.stage<4 and not pacifist:
			for enemy in game.enemies:
				if not enemy.is_active or enemy.mode==WardEnemy.Mode.DEAD or enemy.pursuer:continue
				if enemy.global_position.distance_to(game.player.global_position)>5 or not enemy.can_see_player():continue
				Input.action_release("forward")
				var shot_direction: Vector3 = (enemy.get_aim_point("head")-game.player.camera.global_position).normalized()
				game.player.rotation.y=atan2(-shot_direction.x,-shot_direction.z)
				game.player.pitch=asin(shot_direction.y)
				await physics(2)
				if game.state.magazine==0:
					game.player.reload_weapon()
					await physics(100)
				game.player.fire()
				await physics(20)
				game.player.pitch=0
		var dir: Vector3 = target-game.player.position
		game.player.rotation.y=atan2(-dir.x,-dir.z)
		Input.action_press("forward")
		if run_:
			if game.player.stamina>80:sprinting=true
			if game.player.stamina<15:sprinting=false
		if run_ and sprinting: Input.action_press("sprint")
		else: Input.action_release("sprint")
		await physics()
		frames+=1
	Input.action_release("forward")
	Input.action_release("sprint")
	await physics(10)
	if frames>=1800: fail("Blocked walking to "+str(target));return
	if absf(game.player.position.y-y)>.65: fail("Wrong floor at "+str(target));return

func interact(id_: String) -> void:
	if failed:return
	var target: WardInteractable
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.item_id==id_:target=n;break
	if target==null:fail("Missing interaction "+id_);return
	var pos := target.global_position
	if target.kind=="door":pos=target.to_global(Vector3(.93,1.31,0))
	var dir: Vector3 = (pos-game.player.camera.global_position).normalized()
	game.player.rotation.y=atan2(-dir.x,-dir.z)
	game.player.pitch=asin(dir.y)
	await physics(3)
	game.player.find_target()
	if game.player.target!=target:
		fail("Interaction ray cannot reach "+id_+"; hits "+(game.player.target.item_id if game.player.target else "wall"));return
	target.interact()
	await physics(50 if target.kind=="door" else 2)
	record(id_)
	if target.kind=="note":game.hud.close()

func click(x: float,y: float) -> void:
	if failed:return
	for n in game.hud.menus.find_children("*","Button",true,false):
		if Rect2(n.position,n.size).has_point(Vector2(x,y)):
			n.pressed.emit()
			await physics(2)
			return
	fail("Missing UI button at "+str(Vector2(x,y)))

func finish_report() -> void:
	var f:=FileAccess.open("user://"+("walkthrough_zero_ammo" if pacifist else "walkthrough")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":not failed,"no_teleports":true,"enemies_enabled":true,"shots":game.state.shots,"health":game.state.health,"active_play_seconds":game.state.seconds,"events":steps},"\t"))
	f.close()
	game.web.report("walkthrough",{"passed":not failed,"no_teleports":true,"enemies_enabled":true,"shots":game.state.shots,"health":game.state.health,"active_play_seconds":game.state.seconds,"events":steps})

func run(g: Node) -> void:
	game=g
	game.start_new()
	pacifist=OS.get_cmdline_user_args().has("--pacifist")
	if pacifist:
		game.state.magazine=0
		game.state.inventory=game.state.inventory.filter(func(i):return i.kind!="ammo")
	await physics(10)
	await interact("note_arrival")
	await walk(0,5)
	await interact("safe_door")
	await walk(-5.6,5)
	await walk(-8.3,4.4)
	await interact("note_rounds")
	await walk(-7.1,4.4)
	await interact("save_recorder")
	await walk(-7,6.4)
	await interact("note_last_shift")
	await walk(-4.4,5)
	await walk(0,5)
	await walk(0,-6)
	await interact("power_door")
	await walk(-5,-6)
	await walk(-6.2,-7.2)
	await interact("note_power")
	await walk(-8.2,-5)
	await interact("power_panel")
	await click(450,580)
	await click(1120,580)
	await click(1450,580)
	await click(900,800)
	if game.state.stage!=1:fail("Power UI failed");return
	await walk(-5,-6)
	await walk(0,-6)
	await walk(0,-20)
	await interact("ward_door")
	await walk(-4.2,-20)
	await walk(-5.2,-16)
	await interact("note_ward")
	await walk(-5.4,-20)
	await walk(-4.2,-20)
	await walk(0,-20)
	await walk(0,-1)
	await interact("pharmacy_west")
	await walk(5,-1)
	await walk(5,-4)
	await walk(8,-4.5)
	await interact("medicine_lock")
	await click(760,565) # 4
	await click(760,465) # 1
	await click(760,665) # 7
	await click(1140,755)
	if game.state.stage!=2:fail("Cabinet UI failed");return
	await walk(12,-4.5)
	await walk(13,-1)
	await interact("pharmacy_east")
	await walk(17.5,-1)
	await walk(17.5,-31.5)
	await walk(0,-31.5)
	await walk(0,-34)
	await interact("cold_door")
	await walk(-4.5,-34)
	await walk(-5,-32.3)
	await walk(-8.7,-32.5)
	await interact("note_autopsy")
	await walk(-10,-32.7)
	await interact("specimen_terminal")
	await click(530,652)
	await click(1340,652)
	await click(1340,652)
	await click(900,810)
	if game.state.stage!=3:fail("Specimen UI failed");return
	if pacifist:
		# Circle the south side of the examination table rather than running
		# straight back into the nurse approaching from the north aisle.
		await walk(-10,-36)
		await walk(-5,-36)
	else:
		await walk(-5,-32.3)
	await walk(-4,-34)
	await walk(0,-34)
	await walk(0,-31.5)
	await walk(17.5,-31.5)
	await walk(17.5,-20)
	await interact("lab_door")
	await walk(16.2,-20)
	await walk(8.5,-20,-3.2)
	await walk(6.6,-21.4,-3.2)
	await interact("note_lab")
	await walk(6.6,-20,-3.2)
	await interact("lab_terminal")
	game.state.magazine=0
	game.state.inventory=game.state.inventory.filter(func(i):return i.kind!="ammo")
	await click(1180,770)
	if game.state.stage!=4:fail("Termination UI failed");return
	record("escape_started")
	await walk(8.5,-20,-3.2,true)
	await walk(17.5,-20,0,true)
	await walk(17.5,8.5,0,true)
	await walk(3,7.3,0,true)
	await walk(0,7.3,0,true)
	await walk(0,12.3,0,true)
	var pursuer: WardEnemy=game.enemies[3]
	if pursuer.position.y < -.5 or pursuer.position.distance_to(game.player.position)>7:
		fail("Final pursuer did not traverse stairs and reach the escape route");return
	await interact("end_exit")
	if not game.finished:fail("Exit did not end chapter");return
	record("chapter_complete")
	print("PURSUER_END position=",game.enemies[3].position," mode=",game.enemies[3].mode," target=",game.enemies[3].interest)
	finish_report()
	print("WALKTHROUGH_COMPLETE seconds=",game.state.seconds," health=",game.state.health," shots=",game.state.shots)
	get_tree().quit()
