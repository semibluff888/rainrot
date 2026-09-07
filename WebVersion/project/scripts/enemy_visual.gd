class_name WardEnemyVisual
extends Node3D

# Original assets are packaged as editor scenes with this adapter at their root.
# Animation clocks advance only from WardEnemy's unpaused physics update.
signal foot_contact(side: String)

@export var source_verified := false
@export var head_target_path: NodePath
@export var body_target_path: NodePath
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var animation_map: Dictionary = {}
@export var movement_reference_speed := 1.0
@export var run_reference_speed := 1.85
@export var low_materials: Array[Material] = []
@export var high_materials: Array[Material] = []
@export var material_mesh_paths: Array[NodePath] = []
@export var material_surface_indices: Array[int] = []
var player: AnimationPlayer
var head_target: Node3D
var body_target: Node3D
var hitboxes: Array[WardEnemyHitbox] = []
var current_state := ""
var animation_clock := 0.0

func _ready() -> void:
	player = get_node_or_null(animation_player_path) as AnimationPlayer
	head_target = get_node_or_null(head_target_path) as Node3D
	body_target = get_node_or_null(body_target_path) as Node3D
	if player:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	for n in find_children("*", "Area3D", true, false):
		if n is WardEnemyHitbox: hitboxes.append(n)

func configure(enemy: Node) -> void:
	for hitbox in hitboxes: hitbox.enemy = enemy

func set_hittable(enabled: bool) -> void:
	for hitbox in hitboxes: hitbox.set_enabled(enabled)

func get_aim_point(zone: String = "head") -> Vector3:
	var target := head_target if zone == "head" else body_target
	return target.global_position if is_instance_valid(target) else global_position

func set_state(state: String, duration: float = 0.0, restart: bool = false) -> void:
	if not player or (state == current_state and not restart): return
	current_state = state
	var clip: StringName = animation_map.get(state, state)
	if not player.has_animation(clip): return
	var rate := player.get_animation(clip).length / duration if duration > 0 else 1.0
	player.play(clip, .12 if state != "dead" else .08, rate)
	player.advance(0)

func advance(delta: float, movement_speed: float = 0.0) -> void:
	if not player: return
	animation_clock += delta
	var rate := 1.0
	if current_state in ["walk", "run"]:
		var reference := run_reference_speed if current_state == "run" else movement_reference_speed
		rate = clampf(movement_speed / maxf(reference, .01), .0, 2.5)
	player.advance(delta * rate)

func emit_contact(side: String) -> void:
	foot_contact.emit(side)

func set_quality(quality: int) -> void:
	var materials := low_materials if quality == 0 else high_materials
	for i in mini(materials.size(), material_mesh_paths.size()):
		var mesh := get_node_or_null(material_mesh_paths[i]) as MeshInstance3D
		if mesh and i < material_surface_indices.size():
			mesh.set_surface_override_material(material_surface_indices[i], materials[i])

func has_complete_animations() -> bool:
	if not player: return false
	for state in ["idle", "alert", "walk", "run", "attack", "stun", "dead"]:
		if not player.has_animation(animation_map.get(state, state)): return false
	return true
