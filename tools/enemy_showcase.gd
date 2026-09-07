extends Node
## In-engine gallery and a reproducible live encounter / zero-ammo escape demo.
var game: Node
var label_: Label
var frame := 0

func frames(count: int,e: WardEnemy=null) -> void:
	for i in count:
		if e:e.visual.advance(1.0/30)
		await get_tree().process_frame

func camera_at(position_: Vector3,target: Vector3) -> void:
	game.player.position=position_;game.player.velocity=Vector3.ZERO
	var direction: Vector3=(target-game.player.camera.global_position).normalized()
	game.player.rotation.y=atan2(-direction.x,-direction.z)
	game.player.pitch=asin(direction.y);game.player.head.rotation.x=game.player.pitch

func face_camera(e: WardEnemy) -> void:
	var direction: Vector3=game.player.position-e.position
	e.rotation.y=atan2(-direction.x,-direction.z)

func title(a: String,b: String) -> void:
	label_.text=a+"\n"+b

func isolate(index: int) -> WardEnemy:
	for e in game.enemies:
		e.set_physics_process(false);e.visible=false;e.visual.set_hittable(false);e.collision_layer=0
	var e: WardEnemy=game.enemies[index]
	e.visible=true;e.is_active=true;e.mode=WardEnemy.Mode.PATROL
	e.visual.set_state("idle",0,true)
	return e

func walk(target: Vector3,look_back: bool=false) -> void:
	var count:=0
	while Vector2(game.player.position.x-target.x,game.player.position.z-target.z).length()>.25 and count<500:
		var direction: Vector3=target-game.player.position
		game.player.rotation.y=atan2(-direction.x,-direction.z)+(PI if look_back else 0)
		game.player.pitch=.05 if look_back else 0.0
		Input.action_press("back" if look_back else "forward")
		if game.player.stamina>15 and not look_back:Input.action_press("sprint")
		else:Input.action_release("sprint")
		await get_tree().process_frame
		count+=1
	Input.action_release("forward");Input.action_release("back");Input.action_release("sprint")

func run(g: Node) -> void:
	game=g
	DisplayServer.window_set_size(Vector2i(1920,1080))
	game.settings.quality=2;game.settings.bob=.3;game.start_new()
	var layer:=CanvasLayer.new();layer.layer=30;add_child(layer)
	label_=Label.new();label_.position=Vector2(80,900);label_.size=Vector2(1600,150)
	label_.add_theme_font_override("font",load("res://assets/fonts/regular.tres"))
	label_.add_theme_font_size_override("font_size",28)
	label_.add_theme_color_override("font_color",Color(.82,.88,.86))
	label_.add_theme_color_override("font_shadow_color",Color.BLACK)
	label_.add_theme_constant_override("shadow_offset_x",2);label_.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label_)
	game.hud.visible=false;game.player.enabled=false;game.player.camera.fov=54
	game.player.gun.visible=false
	game.state.stage=1
	var e:=isolate(0);e.position=Vector3(.05,.02,-12);e.rotation.y=PI
	camera_at(Vector3(.65,.02,-8.5),e.get_aim_point("head")-Vector3(0,.22,0))
	title("笑面病患 / THE SMILY","冷青走廊 · Bento 原作 / Godot 实机")
	await frames(60,e);await game.screenshot("12_smily_corridor")
	e.visual.set_state("alert",e.profile.alert_duration,true);await frames(40,e)
	game.state.stage=2;game.state.collected.append("cold_event")
	e=isolate(1);e.position=Vector3(-6.2,.02,-31.8);e.rotation.y=PI*.8
	camera_at(Vector3(-4.4,.02,-35.6),e.position+Vector3(0,1.1,0));face_camera(e)
	title("多肢护士 / THE NURSE","停尸间 · 六肢交替支撑 / 0.75 秒攻击预兆")
	await frames(60,e);await game.screenshot("13_nurse_morgue")
	e.visual.set_state("attack",e.profile.attack_duration(),true);await frames(23,e)
	await frames(3,e);await game.screenshot("14_nurse_stab");await frames(35,e)
	# Warm ward comparison uses the same materials and same standard flashlight.
	game.state.stage=3;e.position=Vector3(-6,.02,-19);e.rotation.y=PI*.25
	camera_at(Vector3(-4.2,.02,-22.5),e.position+Vector3(0,1.1,0));face_camera(e)
	title("多肢护士 / WARM LIGHT","病房暖灯 · 原模型材质与轮廓")
	e.visual.set_state("idle",0,true);await frames(50,e);await game.screenshot("15_nurse_ward")
	game.state.stage=4;e=isolate(3);e.position=Vector3(12,-3.18,-25.8);e.rotation.y=PI
	camera_at(Vector3(10.9,-3.18,-21.7),e.position+Vector3(0,1.2,0));face_camera(e)
	title("护士长 / THE MATRON","地下红色警报 · 更高站姿 / 扩张肢体")
	await frames(60,e);await game.screenshot("16_elite_laboratory")
	# Actual AI encounter: player remains free to look, attack can miss and be interrupted.
	game.state.stage=2;game.hud.visible=true;game.hud.notice_time=0
	game.player.enabled=true;game.player.gun.visible=true;game.player.camera.fov=76
	e=isolate(1);e.position=Vector3(17.5,.02,-17);e.rotation.y=PI
	camera_at(Vector3(17.5,.02,-12),e.get_aim_point("head"))
	e.alert_consumed=false;e.collision_layer=2;e.visual.set_hittable(true);e.set_physics_process(true)
	label_.position.y=765
	title("实际遭遇","警觉 → 追击 → 刺击前摇 → 枪击打断")
	await frames(96)
	Input.action_press("right");await frames(13);Input.action_release("right")
	camera_at(game.player.position,e.get_aim_point("head"));await frames(3)
	game.player.fire();await frames(18);await game.screenshot("17_nurse_encounter")
	await frames(24)
	# Begin from the actual final checkpoint; follow the real stairs and exit route.
	game.start_new();game.state.stage=4;game.state.keys=["cold_key","lab_card","evidence"]
	game.state.collected.append("cold_event");game.state.dead_enemies=["west_patient","east_patient","ward_patient"]
	for door in get_tree().get_nodes_in_group("interactables"):
		if door.kind=="door" and door.allowed() and not door.opened:door.interact()
	for enemy in game.enemies:enemy.sync(true)
	game.player.position=Vector3(6.6,-3.18,-20);game.player.stamina=100;game.state.magazine=0;game.state.inventory=[]
	game.hud.notice_time=0
	title("最终追逐 / ZERO AMMO","实际导航与碰撞 · 地下实验室 → 楼梯 → 后院")
	await walk(Vector3(8.5,-3.2,-20))
	await walk(Vector3(17.5,0,-20))
	await walk(Vector3(17.5,0,-13))
	game.player.rotation.y=0;game.player.pitch=.03
	await frames(2);await game.screenshot("18_final_pursuit")
	await walk(Vector3(17.5,0,-10),true)
	await walk(Vector3(17.5,0,8.5))
	await walk(Vector3(3,0,7.3))
	await walk(Vector3(0,0,7.3))
	await walk(Vector3(0,0,12.3))
	for item in get_tree().get_nodes_in_group("interactables"):
		if item.item_id=="end_exit":item.interact()
	title("雨蚀：第九病区","Godot 4.7.1 · 两款原作者角色完整接入")
	await frames(65)
	print("ENEMY_SHOWCASE_COMPLETE hp=",game.state.health," finished=",game.finished)
	get_tree().quit()
