extends RefCounted
class_name PlayerModeService

var _owner: Node
var _game_manager: Node
var _sprite: Sprite2D
var _fire_delay_timer: Timer
var _firing_positions: Node2D
var _super_mode_timer: Timer

var _ship_id: String = ""
var _shadow_texture: Texture2D
var _original_texture: Texture2D
var _original_speed: float = 0.0
var _normal_fire_delay: float = 0.3
var _shadow_speed_multiplier: float = 1.2
var _shadow_fire_delay_multiplier: float = 0.1
var _super_mode_speed_multiplier: float = 2.0
var _super_mode_damage_boost: int = 2
var _super_mode_fire_delay: float = 0.15
var _spawn_point_offset: float = 5.0
var _player_balance: Dictionary = {
	"shadow_damage_multiplier": 1.75,
	"super_damage_multiplier": 1.55,
	"super_flat_bonus": 3,
	"combined_damage_multiplier": 2.1,
	"min_fire_delay": 0.08,
	"max_fire_delay": 0.32,
	"max_damage_cap": 2500,
	"ship2_mode_swap_enabled": true,
	"upgrade_diminish_per_level": 0.12,
	"min_upgrade_factor": 0.55
}

var _normal_bullet_scene: PackedScene
var _super_bullet_scene: PackedScene
var _shadow_bullet_scene: PackedScene

var _super_mode_spawn_points: Array[Marker2D] = []

func configure(
	owner: Node,
	game_manager: Node,
	sprite: Sprite2D,
	fire_delay_timer: Timer,
	firing_positions: Node2D,
	super_mode_timer: Timer,
	ship_id: String,
	shadow_texture: Texture2D,
	original_texture: Texture2D,
	original_speed: float,
	normal_fire_delay: float,
	shadow_speed_multiplier: float,
	shadow_fire_delay_multiplier: float,
	super_mode_speed_multiplier: float,
	super_mode_damage_boost: int,
	super_mode_fire_delay: float,
	spawn_point_offset: float,
	normal_bullet_scene: PackedScene,
	super_bullet_scene: PackedScene,
	shadow_bullet_scene: PackedScene,
	player_balance_settings: Dictionary = {}
) -> void:
	_owner = owner
	_game_manager = game_manager
	_sprite = sprite
	_fire_delay_timer = fire_delay_timer
	_firing_positions = firing_positions
	_super_mode_timer = super_mode_timer
	_ship_id = ship_id
	_shadow_texture = shadow_texture
	_original_texture = original_texture
	_original_speed = original_speed
	_normal_fire_delay = normal_fire_delay
	_shadow_speed_multiplier = shadow_speed_multiplier
	_shadow_fire_delay_multiplier = shadow_fire_delay_multiplier
	_super_mode_speed_multiplier = super_mode_speed_multiplier
	_super_mode_damage_boost = super_mode_damage_boost
	_super_mode_fire_delay = super_mode_fire_delay
	_spawn_point_offset = spawn_point_offset
	_normal_bullet_scene = normal_bullet_scene
	_super_bullet_scene = super_bullet_scene
	_shadow_bullet_scene = shadow_bullet_scene
	_apply_player_balance_settings(player_balance_settings)

func update_ship_context(ship_id: String, original_texture: Texture2D, original_speed: float) -> void:
	_ship_id = ship_id
	_original_texture = original_texture
	_original_speed = original_speed

func on_shadow_mode_activated() -> void:
	if _is_shadow_mode_active():
		return
	_set_shadow_mode_active(true)
	apply_shadow_mode_effects()

func on_shadow_mode_deactivated() -> void:
	# Always revert shadow mode effects regardless of current state
	# This ensures the ship properly resets even if the state is inconsistent
	_set_shadow_mode_active(false)
	revert_shadow_mode_effects()

func apply_shadow_mode_effects() -> void:
	var stats := _get_stats()
	if _sprite:
		_sprite.texture = _shadow_texture
		if _ship_id == "Ship2":
			_sprite.modulate = Color(0.7, 0.3, 1.0)
		else:
			_sprite.modulate = Color(1.2, 1.2, 1.2)

	_set_player_speed(_original_speed * _shadow_speed_multiplier)
	if _fire_delay_timer:
		_fire_delay_timer.wait_time = get_balanced_fire_delay(_normal_fire_delay * _shadow_fire_delay_multiplier)
	if stats:
		var base_damage: int = int(stats.get("base_bullet_damage", _get_default_bullet_damage()))
		var shadow_multiplier: float = float(_player_balance.get("shadow_damage_multiplier", 1.75))
		stats["bullet_damage"] = get_balanced_bullet_damage(int(base_damage * shadow_multiplier))

func revert_shadow_mode_effects() -> void:
	var stats := _get_stats()
	if _sprite and _original_texture:
		_sprite.texture = _original_texture
		if _is_super_mode_active():
			if _ship_id == "Ship2":
				_sprite.modulate = Color(1, 0.706, 0.385)
			else:
				_sprite.modulate = Color(0.5, 0.5, 1.5)
		else:
			_sprite.modulate = Color(1.0, 1.0, 1.0)

	if _is_super_mode_active():
		if _ship_id == "Ship2" and _is_shadow_mode_active():
			_set_player_speed(_original_speed * _shadow_speed_multiplier * _super_mode_speed_multiplier)
		else:
			_set_player_speed(_original_speed * _super_mode_speed_multiplier)
	else:
		_set_player_speed(_original_speed)

	if _fire_delay_timer:
		if _is_super_mode_active():
			_fire_delay_timer.wait_time = get_balanced_fire_delay(_super_mode_fire_delay)
		else:
			_fire_delay_timer.wait_time = get_balanced_fire_delay(_normal_fire_delay)

	if stats and not _is_super_mode_active():
		stats["bullet_damage"] = get_balanced_bullet_damage(int(stats.get("base_bullet_damage", _get_default_bullet_damage())))

	_set_active_bullet_scene(_get_normal_bullet_scene())

func apply_mode_effects(shadow_mode_active: bool, super_mode_active: bool) -> void:
	var was_shadow_active: bool = _is_shadow_mode_active()
	var was_super_active: bool = _is_super_mode_active()

	if was_super_active and not super_mode_active:
		_set_super_mode_active(false)
		on_super_mode_timeout()

	if was_shadow_active and not shadow_mode_active:
		_set_shadow_mode_active(false)
		revert_shadow_mode_effects()

	if shadow_mode_active and not was_shadow_active:
		_set_shadow_mode_active(true)
		apply_shadow_mode_effects()

	if super_mode_active and not was_super_active:
		_set_super_mode_active(true)
		var super_mode_duration: float = 2.0
		if _game_manager and _game_manager.has_method("get_super_mode_duration"):
			super_mode_duration = float(_game_manager.get_super_mode_duration())
		apply_super_mode_effects(2.0, super_mode_duration)

func activate_super_mode(multiplier_div: float, duration: float) -> void:
	_set_super_mode_active(true)
	apply_super_mode_effects(multiplier_div, duration)

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	var stats := _get_stats()
	if stats.is_empty():
		return

	var base_damage: int = int(stats.get("base_bullet_damage", _get_default_bullet_damage()))
	var current_damage: int = int(stats.get("bullet_damage", base_damage))
	var super_damage_multiplier: float = float(_player_balance.get("super_damage_multiplier", 1.55))
	var combined_damage_multiplier: float = float(_player_balance.get("combined_damage_multiplier", 2.1))
	var super_flat_bonus: int = int(_player_balance.get("super_flat_bonus", 3))

	if _is_shadow_mode_active():
		stats["bullet_damage"] = get_balanced_bullet_damage(int(base_damage * combined_damage_multiplier) + super_flat_bonus + _super_mode_damage_boost)
		_set_active_bullet_scene(_shadow_bullet_scene)
	else:
		var normalized_multiplier := clampf(multiplier_div, 1.0, 2.2)
		var final_multiplier: float = minf(super_damage_multiplier, normalized_multiplier)
		var scaled_damage := int(current_damage * final_multiplier) + super_flat_bonus + _super_mode_damage_boost
		stats["bullet_damage"] = get_balanced_bullet_damage(scaled_damage)
		_set_active_bullet_scene(_super_bullet_scene)

	if _fire_delay_timer:
		_fire_delay_timer.wait_time = get_balanced_fire_delay(_super_mode_fire_delay)

	add_super_mode_spawn_points()
	if _super_mode_timer:
		_super_mode_timer.start(duration)

	if _sprite:
		if _is_shadow_mode_active():
			_sprite.modulate = Color(0.7, 0.7, 1.5)
		else:
			if _ship_id == "Ship2":
				_sprite.modulate = Color(1, 0.706, 0.385)
			else:
				_sprite.modulate = Color(0.5, 0.5, 1.5)

	if _is_shadow_mode_active():
		_set_player_speed(_original_speed * _shadow_speed_multiplier * _super_mode_speed_multiplier)
	else:
		_set_player_speed(_original_speed * _super_mode_speed_multiplier)

func add_super_mode_spawn_points() -> void:
	_cleanup_super_mode_spawn_points()
	if not _firing_positions or not _game_manager:
		return

	var total_angle: float = 100.0
	var start_angle := -5.0 - (total_angle / 2)
	var spawn_count: int = int(_game_manager.SUPER_MODE_SPAWN_COUNT)
	if spawn_count <= 1:
		return
	var angle_step: float = total_angle / float(spawn_count - 1)

	for i in spawn_count:
		var marker := Marker2D.new()
		marker.name = "SuperMode%d" % i
		var angle := deg_to_rad(start_angle + angle_step * i)
		var offset := Vector2(_spawn_point_offset, 0).rotated(angle)
		marker.position = offset
		marker.rotation = angle
		_firing_positions.add_child(marker)
		_super_mode_spawn_points.append(marker)

func on_super_mode_timeout() -> void:
	_set_super_mode_active(false)
	_restore_normal_damage()
	_restore_normal_fire_delay()
	_cleanup_super_mode_spawn_points()
	_set_active_bullet_scene(_get_normal_bullet_scene())

	if _sprite:
		if _is_shadow_mode_active():
			_sprite.modulate = Color(1.2, 1.2, 1.2)
			_set_player_speed(_original_speed * _shadow_speed_multiplier)
		else:
			_sprite.modulate = Color(1.0, 1.0, 1.0)
			_set_player_speed(_original_speed)

	if not _is_shadow_mode_active():
		var stats := _get_stats()
		if stats:
			stats["bullet_damage"] = get_balanced_bullet_damage(int(stats.get("base_bullet_damage", _get_default_bullet_damage())))

func clear_super_mode_spawn_cache() -> void:
	_super_mode_spawn_points.clear()

func _restore_normal_damage() -> void:
	var stats := _get_stats()
	if stats.is_empty():
		return

	if _is_shadow_mode_active():
		var shadow_multiplier: float = float(_player_balance.get("shadow_damage_multiplier", 1.75))
		stats["bullet_damage"] = get_balanced_bullet_damage(int(stats.get("base_bullet_damage", _get_default_bullet_damage()) * shadow_multiplier))
	else:
		stats["bullet_damage"] = get_balanced_bullet_damage(int(stats.get("base_bullet_damage", _get_default_bullet_damage())))

	if _game_manager:
		_game_manager.notify_ship_stats_updated(_ship_id, int(stats.get("base_bullet_damage", _get_default_bullet_damage())))

func _restore_normal_fire_delay() -> void:
	if not _fire_delay_timer:
		return
	if _is_shadow_mode_active():
		_fire_delay_timer.wait_time = get_balanced_fire_delay(_normal_fire_delay * _shadow_fire_delay_multiplier)
	else:
		_fire_delay_timer.wait_time = get_balanced_fire_delay(_normal_fire_delay)

func _cleanup_super_mode_spawn_points() -> void:
	for marker in _super_mode_spawn_points:
		if marker and is_instance_valid(marker):
			marker.queue_free()
	_super_mode_spawn_points.clear()

func _set_player_speed(new_speed: float) -> void:
	if _owner:
		_owner.set("speed", new_speed)

func _set_active_bullet_scene(scene: PackedScene) -> void:
	if _owner:
		_owner.set("plBullet", scene)

func _get_normal_bullet_scene() -> PackedScene:
	# Prefer the owner's current normal bullet to avoid stale cached scene references.
	if _owner:
		var owner_normal_scene: Variant = _owner.get("plNormalBullet")
		if owner_normal_scene is PackedScene:
			var scene := owner_normal_scene as PackedScene
			if scene.can_instantiate():
				return scene
	return _normal_bullet_scene

func _get_stats() -> Dictionary:
	if _game_manager and _game_manager.player_manager:
		return _game_manager.player_manager.player_stats
	return {}

func _get_default_bullet_damage() -> int:
	if _game_manager and _game_manager.player_manager:
		return int(_game_manager.player_manager.default_bullet_damage)
	return 20

func _is_shadow_mode_active() -> bool:
	return bool(_get_stats().get("is_shadow_mode_active", false))

func _is_super_mode_active() -> bool:
	return bool(_get_stats().get("is_super_mode_active", false))

func _set_shadow_mode_active(active: bool) -> void:
	var stats := _get_stats()
	if stats:
		stats["is_shadow_mode_active"] = active

func _set_super_mode_active(active: bool) -> void:
	var stats := _get_stats()
	if stats:
		stats["is_super_mode_active"] = active

func get_balanced_fire_delay(raw_delay: float) -> float:
	var min_delay: float = float(_player_balance.get("min_fire_delay", 0.08))
	var max_delay: float = float(_player_balance.get("max_fire_delay", 0.32))
	if max_delay < min_delay:
		max_delay = min_delay
	return clampf(raw_delay, min_delay, max_delay)

func get_balanced_bullet_damage(raw_damage: int) -> int:
	var cap: int = int(_player_balance.get("max_damage_cap", 2500))
	return clampi(raw_damage, 1, maxi(1, cap))

func get_balanced_upgrade_gain(base_gain: int, attack_level: int, max_attack_level: int) -> int:
	var diminish_per_level: float = float(_player_balance.get("upgrade_diminish_per_level", 0.12))
	var min_factor: float = float(_player_balance.get("min_upgrade_factor", 0.55))
	var level_ratio: float = 0.0
	if max_attack_level > 0:
		level_ratio = float(attack_level) / float(max_attack_level)
	var factor: float = maxf(min_factor, 1.0 - (diminish_per_level * level_ratio))
	return maxi(1, int(round(base_gain * factor)))

func use_ship2_mode_swap() -> bool:
	return bool(_player_balance.get("ship2_mode_swap_enabled", true))

func is_shadow_mode_active() -> bool:
	return _is_shadow_mode_active()

func is_super_mode_active() -> bool:
	return _is_super_mode_active()

func set_shadow_mode_active(active: bool) -> void:
	_set_shadow_mode_active(active)

func set_super_mode_active(active: bool) -> void:
	_set_super_mode_active(active)

func _apply_player_balance_settings(balance_settings: Dictionary) -> void:
	if balance_settings.is_empty():
		return
	for key in _player_balance.keys():
		if balance_settings.has(key):
			_player_balance[key] = balance_settings[key]
