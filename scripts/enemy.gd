class_name WardEnemy
extends CharacterBody3D

enum Mode { DORMANT, PATROL, INVESTIGATE, CHASE, ATTACK, STUN, DEAD, ALERT }
var game: Node
var enemy_id := "patient"
var activation_stage := 1
var pursuer := false
var profile: WardEnemyProfile
var hp := 110
var mode := Mode.DORMANT
var agent: NavigationAgent3D
var visual: WardEnemyVisual
var anchor := Vector3.ZERO
var interest := Vector3.ZERO
var timer := 0.0
var attack_timer := 0.0
var breath_timer := 4.0
var route_timer := 0.0
var seen_timer := 0.0
var anim_clock := 0.0
var is_active := false
var alert_consumed := false
var strike_resolved := true
var attack_elapsed := 0.0
var burst_wait := 2.0
var burst_warning := 0.0
var burst_left := 0.0
var strikes_landed := 0
var original_asset_loaded := false

func _ready() -> void:
	if profile == null: profile = load("res://scenes/enemies/smily.tres")
	hp = profile.max_health
	collision_layer = 0
	collision_mask = 1 | 4 | 8
	floor_snap_length = .4
	floor_max_angle = deg_to_rad(49)
	var shape := CapsuleShape3D.new()
	shape.radius = profile.body_radius
	shape.height = profile.body_height
	var c := CollisionShape3D.new()
	c.name = "MovementCollider"
	c.shape = shape
	c.position.y = profile.body_height * .5
	add_child(c)
	visual = load(profile.visual_scene_path).instantiate() as WardEnemyVisual
	visual.name = "Visual"
	visual.scale *= profile.visual_scale
	add_child(visual)
	visual.configure(self)
	visual.foot_contact.connect(_foot_contact)
	original_asset_loaded = visual.source_verified
	agent = NavigationAgent3D.new()
	agent.name = "NavigationAgent"
	agent.path_desired_distance = .35
	agent.target_desired_distance = .5
	agent.radius = profile.body_radius
	agent.height = profile.body_height
	agent.path_max_distance = 2
	add_child(agent)
	anchor = global_position
	visible = false
	add_to_group("enemies")

func sync(restoring: bool = false) -> void:
	if game.state.dead_enemies.has(enemy_id):
		mode = Mode.DEAD
		is_active = false
		visible = false
		collision_layer = 0
		visual.set_hittable(false)
		return
	if game.state.stage < activation_stage: return
	if activation_stage == 2 and not game.state.collected.has("cold_event") and game.state.stage < 3: return
	if is_active: return
	is_active = true
	visible = true
	collision_layer = 2
	visual.set_hittable(true)
	interest = anchor
	alert_consumed = restoring or pursuer
	mode = Mode.CHASE if pursuer else Mode.PATROL
	seen_timer = 100 if pursuer else 0
	_update_animation()

func hear(where: Vector3, radius: float) -> void:
	if not is_active or mode in [Mode.DEAD, Mode.DORMANT] or game.is_safe(): return
	if global_position.distance_to(where) < radius and mode not in [Mode.CHASE, Mode.STUN, Mode.ATTACK, Mode.ALERT]:
		interest = where
		mode = Mode.INVESTIGATE
		timer = 7

func get_aim_point(zone: String = "head") -> Vector3:
	return visual.get_aim_point(zone)

func _clear_ray(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == game.player

func can_see_player() -> bool:
	if not is_active or mode == Mode.DEAD or game.is_safe(): return false
	var from := get_aim_point("head")
	var to: Vector3 = game.player.global_position + Vector3(0, 1.0, 0)
	var distance := from.distance_to(to)
	if distance > 18 or (game.player.crouched and distance > 7): return false
	if distance > 3 and (-global_basis.z).dot((to - from).normalized()) < .1: return false
	return _clear_ray(from, to)

func can_strike_player() -> bool:
	if game.is_safe() or not is_active or mode != Mode.ATTACK: return false
	var offset: Vector3 = game.player.global_position - global_position
	if Vector2(offset.x, offset.z).length() > profile.damage_range or absf(offset.y) > 1.1: return false
	var flat := Vector3(offset.x, 0, offset.z).normalized()
	if (-global_basis.z).dot(flat) < .35: return false
	return _clear_ray(get_aim_point("body"), game.player.global_position + Vector3(0, .9, 0))

func _physics_process(delta: float) -> void:
	if not game.started or game.finished or game.hud.modal != "" or not is_active: return
	if mode == Mode.DEAD:
		visual.advance(delta)
		return
	if mode == Mode.DORMANT: return
	anim_clock += delta
	timer -= delta
	attack_timer -= delta
	breath_timer -= delta
	route_timer -= delta
	burst_wait -= delta
	burst_left = maxf(0, burst_left - delta)
	if breath_timer <= 0:
		breath_timer = 5.5 + fmod(float(enemy_id.hash() % 17), 3.0)
		_voice(profile.breath_sound, -14)
	var distance := global_position.distance_to(game.player.global_position)
	var sees := can_see_player()
	if game.is_safe():
		_cancel_attack()
		mode = Mode.PATROL
		interest = anchor
		seen_timer = 0
	elif sees or (pursuer and game.state.stage == 4):
		seen_timer = 7
		interest = game.player.global_position
		if mode not in [Mode.STUN, Mode.ATTACK, Mode.ALERT]:
			if not alert_consumed:
				alert_consumed = true
				mode = Mode.ALERT
				timer = profile.alert_duration
				_voice(profile.alert_sound, -10)
			else:
				mode = Mode.CHASE
	else:
		seen_timer -= delta
		if mode == Mode.CHASE and seen_timer < 0:
			mode = Mode.INVESTIGATE
			timer = 7
	match mode:
		Mode.STUN:
			velocity.x = move_toward(velocity.x, 0, delta * 5)
			velocity.z = move_toward(velocity.z, 0, delta * 5)
			if timer <= 0: mode = Mode.CHASE
		Mode.ALERT:
			velocity.x = 0
			velocity.z = 0
			_face(interest, delta * 1.6)
			if timer <= 0: mode = Mode.CHASE
		Mode.ATTACK:
			velocity.x = 0
			velocity.z = 0
			attack_elapsed += delta
			# Commit facing before the damage window, allowing a real sidestep.
			if attack_elapsed < profile.windup * .55: _face(interest, delta * 2)
			if attack_elapsed >= profile.windup and not strike_resolved:
				strike_resolved = true
				_voice(profile.strike_sound, -7)
				if can_strike_player():
					strikes_landed += 1
					game.player.damage(profile.attack_damage)
			if attack_elapsed >= profile.attack_duration():
				mode = Mode.CHASE
				attack_timer = profile.attack_cooldown
		_:
			if distance < profile.attack_range and sees and not game.is_safe() and attack_timer <= 0:
				_begin_attack()
			else:
				if mode == Mode.INVESTIGATE and timer <= 0:
					mode = Mode.PATROL
					interest = anchor
				if mode == Mode.PATROL and global_position.distance_to(interest) < .8:
					interest = anchor + Vector3(0, 0, sin(anim_clock * .12) * 2.0)
				_update_burst(delta, distance, sees)
				_move_to_interest(delta)
				_push_unlocked_doors()
	if not is_on_floor(): velocity.y -= 18 * delta
	else: velocity.y = -.5
	move_and_slide()
	_update_animation()
	visual.advance(delta, Vector2(velocity.x, velocity.z).length())

func _face(where: Vector3, weight: float) -> void:
	var direction := where - global_position
	if Vector2(direction.x, direction.z).length() > .05:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(weight, 1.0))

func _update_burst(delta: float, distance: float, sees: bool) -> void:
	if mode != Mode.CHASE or profile.burst_speed <= 0:
		burst_warning = 0
		burst_left = 0
		return
	if burst_warning > 0:
		burst_warning -= delta
		if burst_warning <= 0: burst_left = profile.burst_duration
	elif burst_wait <= 0 and burst_left <= 0 and distance > 2.6 and distance < 6 and sees:
		burst_warning = .45
		burst_wait = profile.burst_cooldown
		_voice(profile.alert_sound, -10)

func _move_to_interest(delta: float) -> void:
	if route_timer <= 0:
		route_timer = .25
		agent.target_position = interest
	velocity.x = 0
	velocity.z = 0
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0: return
	var next := agent.get_next_path_position()
	if game.is_safe_position(next):
		interest = anchor
		route_timer = 0
		return
	var direction := next - global_position
	direction.y = 0
	if direction.length() <= .12 or agent.is_navigation_finished(): return
	direction = direction.normalized()
	var speed := profile.chase_speed if mode == Mode.CHASE else profile.patrol_speed
	if burst_warning > 0: speed = profile.patrol_speed
	elif burst_left > 0: speed = profile.burst_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 5, 1.0))

func _push_unlocked_doors() -> void:
	for d in get_tree().get_nodes_in_group("interactables"):
		if d.kind == "door" and d.item_id != "safe_door" and not d.opened and d.allowed() and d.global_position.distance_to(global_position) < 1.6:
			d.interact()

func _begin_attack() -> void:
	mode = Mode.ATTACK
	attack_elapsed = 0
	strike_resolved = false
	burst_left = 0
	burst_warning = 0
	velocity.x = 0
	velocity.z = 0
	_voice(profile.alert_sound, -11)
	_update_animation()

func _cancel_attack() -> void:
	strike_resolved = true
	attack_elapsed = 0
	burst_left = 0
	burst_warning = 0

func _update_animation() -> void:
	match mode:
		Mode.ALERT: visual.set_state("alert", profile.alert_duration)
		Mode.ATTACK: visual.set_state("attack", profile.attack_duration())
		Mode.STUN: visual.set_state("stun", profile.stagger_duration)
		Mode.DEAD: visual.set_state("dead")
		_:
			var moving := Vector2(velocity.x, velocity.z).length() > .1
			visual.set_state(("run" if mode == Mode.CHASE else "walk") if moving else "idle")

func _voice(sound: String, volume: float) -> void:
	game.audio.one(sound, volume, profile.voice_pitch, get_aim_point("body"), true)

func _foot_contact(side: String) -> void:
	if not game.started or game.finished or game.hud.modal != "" or mode not in [Mode.PATROL, Mode.INVESTIGATE, Mode.CHASE]: return
	if Vector2(velocity.x, velocity.z).length() < .15 or not is_on_floor(): return
	var offset := global_basis.x * (-.18 if side == "left" else .18)
	game.audio.one(profile.step_sound, -15 if mode == Mode.CHASE else -20, profile.voice_pitch, global_position + offset, true)

func take_hit(amount: int, from: Vector3) -> void:
	if mode in [Mode.DEAD, Mode.DORMANT] or not is_active or game.hud.modal != "": return
	if not pursuer: hp -= amount
	_cancel_attack()
	alert_consumed = true
	_voice("hit", -9)
	var away := global_position - from
	away.y = 0
	velocity = away.normalized() * 1.2
	mode = Mode.STUN
	timer = profile.stagger_duration
	attack_timer = maxf(attack_timer, .35)
	interest = game.player.global_position
	seen_timer = 8
	burst_wait = profile.burst_cooldown
	if hp <= 0:
		mode = Mode.DEAD
		velocity = Vector3.ZERO
		collision_layer = 0
		visual.set_hittable(false)
		if not game.state.dead_enemies.has(enemy_id): game.state.dead_enemies.append(enemy_id)
	_update_animation()
	if mode == Mode.STUN: visual.set_state("stun",profile.stagger_duration,true)

