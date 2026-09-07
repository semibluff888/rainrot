class_name WardEnemyHitbox
extends Area3D

@export_enum("body", "head") var zone := "body"
var enemy: Node

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

func set_enabled(enabled: bool) -> void:
	collision_layer = 32 if enabled else 0

func receive_shot(from: Vector3) -> void:
	if is_instance_valid(enemy) and collision_layer != 0:
		enemy.take_hit(70 if zone == "head" else 38, from)
