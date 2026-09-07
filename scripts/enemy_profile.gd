class_name WardEnemyProfile
extends Resource

@export var role_id: StringName = &"smily"
@export var display_name := "笑面病患"
@export_file("*.tscn") var visual_scene_path := "res://scenes/enemies/smily_visual.tscn"
@export var max_health := 110
@export var body_radius := .32
@export var body_height := 1.85
@export var patrol_speed := .75
@export var chase_speed := 1.85
@export var visual_scale := 1.0
@export var alert_duration := 1.0
@export var attack_range := 1.3
@export var damage_range := 1.58
@export var attack_damage := 24
@export var windup := .55
@export var strike_duration := .15
@export var recovery := .65
@export var attack_cooldown := .5
@export var stagger_duration := .8
@export var burst_speed := 3.0
@export var burst_duration := .85
@export var burst_cooldown := 5.0
@export var breath_sound := "smily_breath"
@export var step_sound := "smily_step"
@export var alert_sound := "smily_alert"
@export var strike_sound := "smily_strike"
@export var voice_pitch := 1.0

func attack_duration() -> float:
	return windup + strike_duration + recovery

func is_nurse() -> bool:
	return role_id == &"nurse"
