extends "res://Satellites/Scripts/satellite.gd"

const SHADOW_TRIDENT_CORE: Array[float] = [-12.0, 0.0, 12.0]
const SHADOW_TRIDENT_WINGS: Array[float] = [-28.0, 28.0]

var _shadow_angle_bias: float = -6.0

func _ready() -> void:
	bullet_scene = preload("res://Bullet/Sat_bullet/Sat_bullet1.tscn")
	behavior_mode = SatelliteBehaviorMode.SHOOT_ONLY
	super._ready()

func has_custom_shadow_attack() -> bool:
	return true

func execute_shadow_attack(base_damage: int) -> void:
	_spawn_shot_pattern(SHADOW_TRIDENT_CORE, base_damage, _shadow_angle_bias)
	_spawn_shot_pattern(SHADOW_TRIDENT_WINGS, base_damage, -_shadow_angle_bias * 0.5)
	_shadow_angle_bias *= -1.0
