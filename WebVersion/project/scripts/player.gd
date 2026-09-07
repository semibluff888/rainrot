class_name WardPlayer
extends CharacterBody3D

const G = preload("res://tools/geometry.gd")
var game: Node
var camera: Camera3D
var head: Node3D
var gun: Node3D
var slide: Node3D
var torch: SpotLight3D
var muzzle: OmniLight3D
var body_shape: CollisionShape3D
var pitch := 0.0
var stamina := 100.0
var reload_left := 0.0
var shot_left := 0.0
var hurt_left := 0.0
var recoil := 0.0
var foot_distance := 0.0
var bob_clock := 0.0
var input_sway := Vector2.ZERO
var target: WardInteractable
var enabled := false
var flashlight_on := true
var aim := false
var crouched := false
var step_counter := 0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1|2|4
	floor_snap_length = .45
	floor_max_angle = deg_to_rad(49)
	wall_min_slide_angle = deg_to_rad(12)
	body_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 1.72
	body_shape.shape = shape
	body_shape.position.y = .86
	add_child(body_shape)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 76
	camera.near = .045
	camera.far = 80
	head.add_child(camera)
	camera.current = true
	var listener := AudioListener3D.new()
	head.add_child(listener)
	listener.make_current()
	torch = SpotLight3D.new()
	torch.position = Vector3(.2,-.14,-.18)
	torch.light_color = Color(.91,.88,.71)
	torch.light_energy = 6.5
	torch.spot_range = 23
	torch.spot_angle = 29
	torch.spot_angle_attenuation = .55
	torch.spot_attenuation = .65
	torch.shadow_enabled = true
	torch.shadow_bias = .04
	torch.light_size = .04
	torch.light_specular = .12
	torch.light_volumetric_fog_energy = .65
	camera.add_child(torch)
	var fill := OmniLight3D.new()
	fill.light_color = Color(.45,.58,.62)
	fill.light_energy = .12
	fill.omni_range = 2
	camera.add_child(fill)
	build_weapon()

func build_weapon() -> void:
	gun = Node3D.new()
	gun.name = "Pistol"
	camera.add_child(gun)
	var metal := G.material(Color(.09,.11,.12),.38,.78)
	var dark := G.material(Color(.028,.035,.034),.66,.1)
	var skin := G.material(Color(.19,.16,.12),.9)
	var brass := G.material(Color(.5,.4,.22),.3,.65)
	gun.position = Vector3(.21,-.27,-.52)
	# Handcrafted slide, frame, barrel, sights, extractor and stippled grip.
	slide = Node3D.new()
	gun.add_child(slide)
	G.bevel_box(slide,Vector3(0,.065,-.12),Vector3(.055,.056,.25),.009,metal)
	G.box(slide,Vector3(.029,.067,-.08),Vector3(.002,.027,.067),dark)
	for i in 9:
		for side in [-1,1]: G.box(slide,Vector3(side*.028,.069,-.012-i*.006),Vector3(.002,.046,.002),dark)
	var barrel := G.cylinder(gun,Vector3(0,.064,-.25),.017,.026,metal)
	barrel.rotation.x = PI*.5
	var hole := G.cylinder(gun,Vector3(0,.064,-.264),.011,.002,dark)
	hole.rotation.x = PI*.5
	G.bevel_box(gun,Vector3(0,.028,-.07),Vector3(.047,.026,.18),.004,dark)
	var grip := G.bevel_box(gun,Vector3(0,-.046,.007),Vector3(.05,.14,.068),.008,dark)
	grip.rotation.x = -.24
	for i in 8: G.box(grip,Vector3(0,-.053+i*.014,.035),Vector3(.047,.002,.003),metal)
	G.box(gun,Vector3(0,-.043,-.071),Vector3(.041,.009,.092),dark)
	G.box(gun,Vector3(0,-.012,-.115),Vector3(.042,.065,.009),dark)
	G.rod(gun,Vector3(0,.017,-.063),Vector3(0,-.022,-.075),.006,metal)
	G.box(slide,Vector3(0,.101,-.226),Vector3(.012,.014,.013),dark)
	G.box(slide,Vector3(0,.101,-.015),Vector3(.04,.016,.018),dark)
	for side in [-1,1]: G.sphere(slide,Vector3(side*.013,.102,-.004),Vector3(.004,.004,.002),brass)
	G.sphere(slide,Vector3(0,.101,-.217),Vector3(.004,.004,.002),brass)
	G.label(slide,"09 / 9mm",Vector3(.029,.071,-.15),22,.00027,Color(.49,.52,.47),PI*.5)
	# Sleeves and articulated-looking glove silhouettes.
	for side in [-1,1]:
		var hand := G.sphere(gun,Vector3(side*.036,-.062,.04),Vector3(.067,.1,.13),skin)
		hand.rotation.x = -.3
		for i in 4:
			G.rod(gun,Vector3(side*.033,-.022-i*.018,.018),Vector3(side*.024,-.029-i*.018,-.047),.011,skin)
		var sleeve := G.cylinder(gun,Vector3(side*.081,-.11,.20),.056,.24,dark,.044)
		sleeve.rotation_degrees = Vector3(70,side*18,0)
	muzzle = OmniLight3D.new()
	muzzle.position = Vector3(0,.07,-.29)
	muzzle.light_color = Color(1,.56,.16)
	muzzle.omni_range = 5
	muzzle.light_energy = 0
	gun.add_child(muzzle)
	for child in gun.find_children("*","MeshInstance3D",true,false): child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _unhandled_input(event: InputEvent) -> void:
	if game.automated: return
	if not enabled or game.hud.modal != "" or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		var sensitivity: float = game.settings.sensitivity*.0015
		rotation.y -= event.relative.x*sensitivity
		pitch = clampf(pitch-event.relative.y*sensitivity,-1.35,1.35)
		input_sway += event.relative*.0001
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		torch.visible = flashlight_on
		game.audio.one("click",-19)
	if event.is_action_pressed("reload"): reload_weapon()
	if event.is_action_pressed("interact") and is_instance_valid(target): target.interact()
	if event.is_action_pressed("fire"): fire()

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(game): return
	if game.hud.modal != "" or game.web.input_suspended():
		velocity = Vector3.ZERO
		return
	shot_left = maxf(0,shot_left-delta)
	hurt_left = maxf(0,hurt_left-delta)
	if reload_left > 0:
		reload_left -= delta
		if reload_left <= 0:
			game.state.reload()
			game.audio.one("click",-13,.8)
	var input := Input.get_vector("left","right","forward","back")
	crouched = Input.is_action_pressed("crouch")
	aim = Input.is_action_pressed("aim") and reload_left<=0
	var sprint := Input.is_action_pressed("sprint") and input.y<-.1 and stamina>1 and not crouched and not aim
	var speed := 4.65 if sprint else (1.3 if crouched else 2.5)
	if aim: speed *= .64
	stamina = clampf(stamina+(-15.5 if sprint else 19)*delta,0,100)
	var direction := transform.basis*Vector3(input.x,0,input.y)
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*18)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*18)
	if not is_on_floor(): velocity.y -= 18*delta
	else: velocity.y = -.4
	move_and_slide()
	# Standing clearance: do not expand the capsule through furniture.
	var target_height := 1.05 if crouched else 1.72
	if not crouched and body_shape.shape.height < 1.6:
		var query := PhysicsRayQueryParameters3D.create(global_position+Vector3(0,.8,0),global_position+Vector3(0,1.76,0),1|4,[get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			target_height = 1.05
			crouched = true
	body_shape.shape.height = target_height
	body_shape.position.y = target_height*.5
	var horizontal := Vector2(velocity.x,velocity.z).length()
	bob_clock += horizontal*delta*2.0
	var bob: float = sin(bob_clock*2)*.019*game.settings.bob if horizontal>.3 else 0.0
	head.position.y = lerpf(head.position.y,(.98 if crouched else 1.62)+bob,delta*12)
	head.rotation.x = pitch+recoil*.04
	head.rotation.z = lerpf(head.rotation.z,-input.x*.007*game.settings.bob,delta*6)
	foot_distance += horizontal*delta
	if foot_distance > (2.4 if crouched else 1.68) and is_on_floor():
		foot_distance = 0
		game.audio.one("step"+str(step_counter%4),-28 if crouched else (-10 if sprint else -17),randf_range(.86,1.06))
		step_counter += 1
		game.make_noise(global_position,11 if sprint else (2 if crouched else 5))
	recoil = move_toward(recoil,0,delta*7)
	muzzle.light_energy = maxf(0,muzzle.light_energy-delta*140)
	input_sway = input_sway.lerp(Vector2.ZERO,delta*9)
	var base := Vector3(.016,-.155,-.39) if aim else Vector3(.21,-.27,-.52)
	base += Vector3(clampf(-input_sway.x,-.018,.018),bob*.5+clampf(input_sway.y,-.016,.016),recoil*.06)
	if reload_left>0: base.y -= .19*sin(clampf(reload_left/1.55,0,1)*PI)
	gun.position = gun.position.lerp(base,delta*11)
	gun.rotation.x = recoil*.1 + (.65*sin(reload_left/1.55*PI) if reload_left>0 else 0.0)
	gun.rotation.z = .05 if reload_left>0 else 0
	slide.position.z = recoil*.023
	camera.fov = lerpf(camera.fov,59.0 if aim else (80.0 if sprint else 76.0),delta*8)
	find_target()

func find_target() -> void:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*2.7,1|4|16,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.collider as WardInteractable if hit and hit.collider is WardInteractable else null

func fire() -> void:
	if shot_left>0 or reload_left>0 or game.state.health<=0: return
	if game.state.magazine<=0:
		game.audio.one("click",-10,.75)
		game.hud.toast("弹匣已空 · R 换弹" if game.state.reserve()>0 else "没有弹药 · 保持距离，寻找绕行路线")
		shot_left = .35
		return
	game.state.magazine -= 1
	game.state.shots += 1
	shot_left = .3
	recoil = 1
	muzzle.light_energy = 9
	game.audio.one("shot",-6,randf_range(.94,1.04))
	game.make_noise(global_position,32)
	var from := camera.global_position
	var end := from-camera.global_basis.z*44
	# Shooting tests the animated hit regions, not the movement capsule.
	var query := PhysicsRayQueryParameters3D.create(from,end,1|4|32,[get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		if hit.collider is WardEnemyHitbox:
			hit.collider.receive_shot(from)
			game.hud.hit_confirm = .2
		else: game.impact(hit.position,hit.normal)

func reload_weapon() -> void:
	if reload_left>0 or game.state.magazine==8: return
	if game.state.reserve()==0:
		game.hud.toast("没有备用弹药")
		return
	reload_left = 1.55
	game.audio.one("click",-11,.85)

func damage(amount: float) -> void:
	if hurt_left>0 or game.state.health<=0 or game.is_safe(): return
	game.state.health = maxf(0,game.state.health-amount)
	hurt_left = .95
	game.audio.one("hit",-8)
	pitch = clampf(pitch+.055,-1.35,1.35)
	if game.state.health<=0: game.die()
