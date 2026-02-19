extends RefCounted
class_name SatelliteBehaviorBase

var _satellite: Node2D = null

func setup(satellite: Node2D) -> void:
	_satellite = satellite

func process(_delta: float) -> void:
	pass

func physics_process(_delta: float) -> void:
	pass

func on_shadow_mode_changed(_is_shadow_mode_active: bool) -> void:
	pass

func get_shot_angles(is_shadow_mode_active: bool, shadow_spread_angle: float) -> Array[float]:
	if is_shadow_mode_active:
		return [-shadow_spread_angle, 0.0, shadow_spread_angle]
	return [0.0]

func configure_spawned_bullet(_bullet: Node, _base_damage: int, _is_shadow_mode_active: bool) -> void:
	pass
