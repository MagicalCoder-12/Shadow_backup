extends "res://Satellites/Scripts/satellite.gd"

const DASH_SPEED: float = 1200.0
const DASH_MAX_DURATION: float = 3.0
const RETURN_SPEED: float = 700.0
const RETURN_STOP_DISTANCE: float = 2.0
const DASH_COOLDOWN: float = 1.5
const SHADOW_DASH_COOLDOWN: float = 1.0
const SHADOW_DASH_SPEED_MULTIPLIER: float = 1.22
const DASH_SPEED_PER_UPGRADE: float = 0.05
const DASH_SPEED_PER_ASCEND: float = 0.18
const DASH_SPEED_MAX_MULTIPLIER: float = 2.4
const DAMAGE_AMOUNT: int = 1
const MIN_HIT_THRESHOLD: float = 42.0
const SHADOW_DASH_TOTAL_COUNT: int = 3
const SHADOW_REENTRY_BACKSTEP: float = 190.0
const SHADOW_REENTRY_SIDE_OFFSET: float = 128.0
const SHADOW_CHAIN_SPEED_STEP: float = 0.18
const DASH_REACQUIRE_DISTANCE: float = 620.0
const OVERSHOOT_HIT_FACTOR: float = 1.35
const SHADOW_IMPACT_RADIUS: float = 160.0
const SHADOW_SPLASH_DAMAGE_FACTOR: float = 0.65

enum DashState {
	IDLE,
	DASHING,
	RETURNING
}

var _dash_state: DashState = DashState.IDLE
var _home_local_position: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _cooldown_remaining: float = DASH_COOLDOWN
var _dash_elapsed: float = 0.0
var _has_hit_target: bool = false
var _shadow_dashes_remaining: int = 0
var _shadow_dash_index: int = 0
var _hit_targets: Array[Node2D] = []

func _ready() -> void:
	behavior_mode = SatelliteBehaviorMode.LAUNCH_ATTACK
	super._ready()

func initialize_launch_attack() -> void:
	_home_local_position = position
	_dash_state = DashState.IDLE
	_target = null
	_dash_elapsed = 0.0
	_cooldown_remaining = _get_dash_cooldown()
	_has_hit_target = false
	_shadow_dashes_remaining = 0
	_shadow_dash_index = 0
	_hit_targets.clear()

func process_launch_attack(delta: float) -> void:
	_home_local_position = calculate_satellite_home_position()
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	match _dash_state:
		DashState.IDLE:
			_move_back_to_home(delta)
			if _cooldown_remaining <= 0.0:
				_try_begin_dash()
		DashState.DASHING:
			_process_dash(delta)
		DashState.RETURNING:
			_process_return(delta)

func on_launch_attack_shadow_mode_changed(_is_shadow_mode_active: bool) -> void:
	_cooldown_remaining = minf(_cooldown_remaining, _get_dash_cooldown())

func calculate_satellite_home_position() -> Vector2:
	if not get_parent():
		return position

	var parent_node := get_parent()
	if parent_node.has_method("_calculate_satellite_offset"):
		var satellite_name := name.to_lower()
		var index := 0 if satellite_name.ends_with("0") else 1
		var home_position: Variant = parent_node.call("_calculate_satellite_offset", index)
		if home_position is Vector2:
			return home_position

	return position

func _try_begin_dash() -> void:
	_target = _find_nearest_enemy([], global_position)
	if _target == null:
		_cooldown_remaining = _get_dash_cooldown()
		return

	_dash_state = DashState.DASHING
	_dash_elapsed = 0.0
	_has_hit_target = false
	_shadow_dash_index = 0
	_shadow_dashes_remaining = SHADOW_DASH_TOTAL_COUNT - 1 if is_shadow_mode_active else 0
	_hit_targets.clear()

func _process_dash(delta: float) -> void:
	if not _ensure_dash_target():
		_dash_state = DashState.RETURNING
		return

	var target_position: Vector2 = _target.global_position
	var previous_distance: float = global_position.distance_to(target_position)
	global_position = global_position.move_toward(target_position, _get_current_dash_speed() * delta)
	var current_distance: float = global_position.distance_to(target_position)
	var hit_threshold: float = _get_hit_threshold(_target)

	if not _has_hit_target:
		var overshot_target: bool = current_distance > previous_distance and previous_distance <= hit_threshold * OVERSHOOT_HIT_FACTOR
		if current_distance <= hit_threshold or overshot_target:
			_handle_dash_impact()
			return

	_dash_elapsed += delta
	if _dash_elapsed >= DASH_MAX_DURATION:
		if _ensure_dash_target(true):
			_dash_elapsed = DASH_MAX_DURATION * 0.35
			return
		_dash_state = DashState.RETURNING

func _process_return(delta: float) -> void:
	_move_back_to_home(delta)
	if position.distance_to(_home_local_position) <= RETURN_STOP_DISTANCE:
		position = _home_local_position
		_dash_state = DashState.IDLE
		_target = null
		_dash_elapsed = 0.0
		_has_hit_target = false
		_cooldown_remaining = _get_dash_cooldown()
		_shadow_dashes_remaining = 0
		_shadow_dash_index = 0
		_hit_targets.clear()

func _move_back_to_home(delta: float) -> void:
	position = position.move_toward(_home_local_position, RETURN_SPEED * delta)

func _check_collision_with_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false

	return global_position.distance_to(_target.global_position) <= _get_hit_threshold(_target)

func _get_hit_threshold(target: Node2D) -> float:
	var sat_radius: float = _get_collision_radius(self)
	var target_radius: float = _get_collision_radius(target)
	return maxf(MIN_HIT_THRESHOLD, sat_radius + target_radius)

func _handle_dash_impact() -> void:
	_deal_damage_to_target()
	if is_shadow_mode_active:
		_deal_shadow_splash_damage()
	if _target != null and is_instance_valid(_target) and not _hit_targets.has(_target):
		_hit_targets.append(_target)
	_has_hit_target = true
	if _prepare_next_shadow_dash():
		return
	_dash_state = DashState.RETURNING

func _deal_damage_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var damage_amount: int = _resolve_dash_damage()
	if _target.has_method("take_damage"):
		_target.take_damage(damage_amount)
	elif _target.has_method("damage"):
		_target.damage(damage_amount)
	elif _target.has_signal("damage_taken"):
		_target.emit_signal("damage_taken", damage_amount)
	else:
		var damage_methods: Array[String] = ["hit", "on_hit", "receive_damage", "apply_damage"]
		for method in damage_methods:
			if _target.has_method(method):
				_target.call(method, damage_amount)
				break

func _deal_shadow_splash_damage() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var splash_damage: int = max(1, int(round(float(_resolve_dash_damage()) * SHADOW_SPLASH_DAMAGE_FACTOR)))
	var enemies: Array[Node] = get_tree().get_nodes_in_group(GameManager.GROUP_DAMAGEABLE)
	for enemy_node in enemies:
		if not (enemy_node is Node2D):
			continue
		var enemy: Node2D = enemy_node as Node2D
		if not _can_dash_target(enemy):
			continue
		if enemy == _target:
			continue
		if enemy.global_position.distance_to(_target.global_position) > SHADOW_IMPACT_RADIUS:
			continue
		_apply_damage_to_enemy(enemy, splash_damage)

func _prepare_next_shadow_dash() -> bool:
	if not is_shadow_mode_active:
		return false
	if _shadow_dashes_remaining <= 0:
		return false
	if _target == null or not is_instance_valid(_target):
		return false

	var previous_target: Node2D = _target
	var next_target: Node2D = _find_nearest_enemy(_hit_targets, previous_target.global_position)
	if next_target == null:
		next_target = _find_nearest_enemy([], previous_target.global_position)
	if next_target == null:
		next_target = previous_target

	var dash_direction: Vector2 = (next_target.global_position - global_position).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.UP
	var side_sign: float = 1.0 if (_shadow_dash_index % 2) == 0 else -1.0
	var reentry_offset: Vector2 = (-dash_direction * SHADOW_REENTRY_BACKSTEP) + (dash_direction.orthogonal() * SHADOW_REENTRY_SIDE_OFFSET * side_sign)

	global_position = next_target.global_position + reentry_offset
	_target = next_target
	_dash_elapsed = 0.0
	_has_hit_target = false
	_shadow_dash_index += 1
	_shadow_dashes_remaining -= 1
	return true

func _find_nearest_enemy(excluded_enemies: Array, from_global_position: Vector2) -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(GameManager.GROUP_DAMAGEABLE)
	var closest_enemy: Node2D = null
	var closest_distance: float = INF

	for enemy_node in enemies:
		if not (enemy_node is Node2D):
			continue

		var enemy := enemy_node as Node2D
		if not _can_dash_target(enemy):
			continue
		if excluded_enemies.has(enemy):
			continue

		var distance: float = from_global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _ensure_dash_target(allow_any_target: bool = false) -> bool:
	if _target != null and is_instance_valid(_target) and _can_dash_target(_target):
		return true

	var excluded_targets: Array = []
	if not allow_any_target:
		excluded_targets = _hit_targets.duplicate()
	var reacquired_target: Node2D = _find_nearest_enemy(excluded_targets, global_position)
	if reacquired_target == null and not allow_any_target:
		reacquired_target = _find_nearest_enemy([], global_position)
	if reacquired_target == null:
		return false
	if global_position.distance_to(reacquired_target.global_position) > DASH_REACQUIRE_DISTANCE and not allow_any_target:
		return false

	_target = reacquired_target
	_dash_elapsed = minf(_dash_elapsed, DASH_MAX_DURATION * 0.45)
	return true

func _can_dash_target(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy == self:
		return false
	if enemy.is_in_group("Meteor"):
		return false
	return enemy.has_method("take_damage") \
		or enemy.has_method("damage") \
		or enemy.has_method("hit") \
		or enemy.has_method("on_hit") \
		or enemy.has_method("receive_damage") \
		or enemy.has_method("apply_damage") \
		or enemy.has_signal("damage_taken")

func _apply_damage_to_enemy(enemy: Node2D, damage_amount: int) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_amount)
	elif enemy.has_method("damage"):
		enemy.damage(damage_amount)
	elif enemy.has_signal("damage_taken"):
		enemy.emit_signal("damage_taken", damage_amount)
	else:
		var damage_methods: Array[String] = ["hit", "on_hit", "receive_damage", "apply_damage"]
		for method in damage_methods:
			if enemy.has_method(method):
				enemy.call(method, damage_amount)
				break

func _get_dash_cooldown() -> float:
	return SHADOW_DASH_COOLDOWN if is_shadow_mode_active else DASH_COOLDOWN

func _resolve_dash_damage() -> int:
	var total_damage := _get_current_satellite_total_damage()
	return max(DAMAGE_AMOUNT, total_damage)

func _get_current_dash_speed() -> float:
	var speed_multiplier: float = 1.0
	var upgrade_data := _get_satellite_upgrade_data()
	if not upgrade_data.is_empty():
		var upgrade_count: int = max(0, int(upgrade_data.get("upgrade_count", 0)))
		var ascend_count: int = max(0, int(upgrade_data.get("ascend_count", 0)))
		speed_multiplier += float(upgrade_count) * DASH_SPEED_PER_UPGRADE
		speed_multiplier += float(ascend_count) * DASH_SPEED_PER_ASCEND

	speed_multiplier = clampf(speed_multiplier, 1.0, DASH_SPEED_MAX_MULTIPLIER)
	if is_shadow_mode_active:
		speed_multiplier *= SHADOW_DASH_SPEED_MULTIPLIER
		speed_multiplier *= 1.0 + (float(_shadow_dash_index) * SHADOW_CHAIN_SPEED_STEP)

	return DASH_SPEED * speed_multiplier

func _get_satellite_upgrade_data() -> Dictionary:
	if satellite_id.is_empty():
		return {}
	if GameManager == null:
		return {}
	if not (GameManager.satellites is Array):
		return {}

	for satellite_data in GameManager.satellites:
		if not (satellite_data is Dictionary):
			continue
		if str(satellite_data.get("id", "")) == satellite_id:
			return satellite_data

	return {}

func _get_collision_radius(node: Node2D) -> float:
	if node == null:
		return 0.0

	var collision_shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 24.0

	var shape := collision_shape.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		return maxf(size.x, size.y) * 0.5
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5)

	return 24.0
