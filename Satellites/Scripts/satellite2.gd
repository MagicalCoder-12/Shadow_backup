extends "res://Satellites/Scripts/satellite.gd"

const SHADOW_SWEEP_LEFT: Array[float] = [-36.0, -20.0, -6.0, 10.0, 24.0, 38.0]
const SHADOW_SWEEP_RIGHT: Array[float] = [-38.0, -24.0, -10.0, 6.0, 20.0, 36.0]

var _shadow_sweep_left_next: bool = true

func _ready() -> void:
	bullet_scene = preload("res://Bullet/Sat_bullet/Sat_bullet2.tscn")
	behavior_mode = SatelliteBehaviorMode.SHOOT_ONLY
	super._ready()

func has_custom_shadow_attack() -> bool:
	return true

func execute_shadow_attack(base_damage: int) -> void:
	var shot_pattern := SHADOW_SWEEP_LEFT if _shadow_sweep_left_next else SHADOW_SWEEP_RIGHT
	_spawn_shot_pattern(shot_pattern, base_damage)
	_shadow_sweep_left_next = not _shadow_sweep_left_next
