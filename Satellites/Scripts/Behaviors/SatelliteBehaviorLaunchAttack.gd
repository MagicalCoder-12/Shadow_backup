extends SatelliteBehaviorBase
class_name SatelliteBehaviorLaunchAttack

const DASH_SPEED: float = 1200.0
const DASH_MAX_DURATION: float = 2.0
const RETURN_SPEED: float = 650.0
const RETURN_STOP_DISTANCE: float = 2.0
const DASH_COOLDOWN: float = 1.75
const SHADOW_DASH_COOLDOWN: float = 1.15
const SHADOW_DASH_SPEED_MULTIPLIER: float = 1.1
const DASH_SPEED_PER_UPGRADE: float = 0.05
const DASH_SPEED_PER_ASCEND: float = 0.18
const DASH_SPEED_MAX_MULTIPLIER: float = 2.4
const DAMAGE_AMOUNT: int = 1
const MIN_HIT_THRESHOLD: float = 42.0

enum DashState {
	IDLE,
	DASHING,
	RETURNING
}

var _state: DashState = DashState.IDLE
var _home_local_position: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _cooldown_remaining: float = DASH_COOLDOWN
var _dash_elapsed: float = 0.0
var _is_shadow_mode_active: bool = false
var _has_hit_target: bool = false  # Track if we've already hit the target during this dash

func setup(satellite: Node2D) -> void:
	super.setup(satellite)
	_home_local_position = satellite.position
	_state = DashState.IDLE
	_target = null
	_dash_elapsed = 0.0
	_cooldown_remaining = DASH_COOLDOWN
	_has_hit_target = false

func on_shadow_mode_changed(is_shadow_mode_active: bool) -> void:
	_is_shadow_mode_active = is_shadow_mode_active
	var max_cooldown: float = SHADOW_DASH_COOLDOWN if _is_shadow_mode_active else DASH_COOLDOWN
	_cooldown_remaining = minf(_cooldown_remaining, max_cooldown)

func process(delta: float) -> void:
	if _satellite == null or not is_instance_valid(_satellite):
		return

	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	match _state:
		DashState.IDLE:
			_move_back_to_home(delta)
			if _cooldown_remaining <= 0.0:
				_try_begin_dash()
		DashState.DASHING:
			_process_dash(delta)
		DashState.RETURNING:
			_process_return(delta)

func _try_begin_dash() -> void:
	_target = _find_nearest_enemy()
	if _target == null:
		_cooldown_remaining = _get_dash_cooldown()
		return

	_state = DashState.DASHING
	_dash_elapsed = 0.0
	_has_hit_target = false  # Reset hit flag for new dash

func _process_dash(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_state = DashState.RETURNING
		return

	# Move toward target
	_satellite.global_position = _satellite.global_position.move_toward(_target.global_position, _get_current_dash_speed() * delta)
	
	# Check for collision with target
	if not _has_hit_target and _check_collision_with_target():
		_deal_damage_to_target()
		_has_hit_target = true
		_state = DashState.RETURNING
		return
	
	_dash_elapsed += delta
	if _dash_elapsed >= DASH_MAX_DURATION:
		_state = DashState.RETURNING

func _process_return(delta: float) -> void:
	_move_back_to_home(delta)
	if _satellite.position.distance_to(_home_local_position) <= RETURN_STOP_DISTANCE:
		_satellite.position = _home_local_position
		_state = DashState.IDLE
		_target = null
		_dash_elapsed = 0.0
		_has_hit_target = false
		_cooldown_remaining = _get_dash_cooldown()

func _move_back_to_home(delta: float) -> void:
	_satellite.position = _satellite.position.move_toward(_home_local_position, RETURN_SPEED * delta)

func _check_collision_with_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	
	var sat_radius: float = _get_collision_radius(_satellite)
	var target_radius: float = _get_collision_radius(_target)
	var hit_threshold: float = maxf(MIN_HIT_THRESHOLD, sat_radius + target_radius)
	var distance_to_target = _satellite.global_position.distance_to(_target.global_position)
	if distance_to_target <= hit_threshold:
		return true
	return false

func _deal_damage_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var damage_amount: int = _resolve_dash_damage()
	
	# Check if the target has a damage handling method
	if _target.has_method("take_damage"):
		_target.take_damage(damage_amount)
	elif _target.has_method("damage"):
		_target.damage(damage_amount)
	elif _target.has_signal("damage_taken"):
		# Emit a damage signal if that's how your game handles it
		_target.emit_signal("damage_taken", damage_amount)
	else:
		# Fallback: Try to call a common damage method
		var damage_methods = ["hit", "on_hit", "receive_damage", "apply_damage"]
		for method in damage_methods:
			if _target.has_method(method):
				_target.call(method, damage_amount)
				break

func _find_nearest_enemy() -> Node2D:
	var enemies: Array[Node] = _satellite.get_tree().get_nodes_in_group(GameManager.GROUP_DAMAGEABLE)
	var closest_enemy: Node2D = null
	var closest_distance: float = INF

	for enemy_node in enemies:
		if not (enemy_node is Node2D):
			continue
		var enemy: Node2D = enemy_node as Node2D
		if not is_instance_valid(enemy):
			continue
		if enemy == _satellite:
			continue
		if enemy.is_in_group("Meteor"):
			continue
		if not enemy.has_method("damage") and not enemy.has_method("take_damage"):
			continue
		var distance: float = _satellite.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _get_dash_cooldown() -> float:
	return SHADOW_DASH_COOLDOWN if _is_shadow_mode_active else DASH_COOLDOWN

func _resolve_dash_damage() -> int:
	if _satellite and _satellite.has_method("_get_current_satellite_total_damage"):
		var value: Variant = _satellite.call("_get_current_satellite_total_damage")
		if value is int:
			return max(DAMAGE_AMOUNT, int(value))
		if value is float:
			return max(DAMAGE_AMOUNT, int(round(value)))
	return DAMAGE_AMOUNT

func _get_current_dash_speed() -> float:
	var speed_multiplier: float = 1.0
	var upgrade_data: Dictionary = _get_satellite_upgrade_data()
	if not upgrade_data.is_empty():
		var upgrade_count: int = max(0, int(upgrade_data.get("upgrade_count", 0)))
		var ascend_count: int = max(0, int(upgrade_data.get("ascend_count", 0)))
		speed_multiplier += (float(upgrade_count) * DASH_SPEED_PER_UPGRADE)
		speed_multiplier += (float(ascend_count) * DASH_SPEED_PER_ASCEND)

	speed_multiplier = clampf(speed_multiplier, 1.0, DASH_SPEED_MAX_MULTIPLIER)
	if _is_shadow_mode_active:
		speed_multiplier *= SHADOW_DASH_SPEED_MULTIPLIER

	return DASH_SPEED * speed_multiplier

func _get_satellite_upgrade_data() -> Dictionary:
	var satellite_id: String = _get_satellite_id()
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

func _get_satellite_id() -> String:
	if _satellite and _satellite.has_method("get_satellite_id"):
		return str(_satellite.call("get_satellite_id"))
	if _satellite and _satellite.has_meta("satellite_id"):
		return str(_satellite.get_meta("satellite_id"))
	return ""

func _get_collision_radius(node: Node2D) -> float:
	if node == null:
		return 0.0

	var collision_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 24.0

	var shape: Shape2D = collision_shape.shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.x, size.y) * 0.5
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5)

	return 24.0
