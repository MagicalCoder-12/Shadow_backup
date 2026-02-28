extends SatelliteBehaviorBase
class_name SatelliteBehaviorLaunchAttack

const DASH_SPEED: float = 900.0
const DASH_DURATION: float = 0.35
const RETURN_SPEED: float = 650.0
const RETURN_STOP_DISTANCE: float = 2.0
const DASH_COOLDOWN: float = 1.75
const SHADOW_DASH_COOLDOWN: float = 1.15
const DAMAGE_AMOUNT: int = 1  # Adjust damage as needed

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
	_satellite.global_position = _satellite.global_position.move_toward(_target.global_position, DASH_SPEED * delta)
	
	# Check for collision with target
	if not _has_hit_target and _check_collision_with_target():
		_deal_damage_to_target()
		_has_hit_target = true
		# Optionally, you can end the dash early if you want
		# _state = DashState.RETURNING
		# return
	
	_dash_elapsed += delta
	if _dash_elapsed >= DASH_DURATION:
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
	
	# Check if satellite is close enough to hit the target
	# You can adjust this threshold or use actual collision shapes
	var hit_threshold: float = 20.0  # Adjust based on your game's scale
	
	# Option 1: Simple distance check
	var distance_to_target = _satellite.global_position.distance_to(_target.global_position)
	if distance_to_target <= hit_threshold:
		return true
	
	# Option 2: If you want to use collision shapes (more accurate)
	# This requires that both satellite and target have CollisionShape2D nodes
	# if _satellite.has_node("CollisionShape2D") and _target.has_node("CollisionShape2D"):
	#     var sat_shape = _satellite.get_node("CollisionShape2D") as CollisionShape2D
	#     var target_shape = _target.get_node("CollisionShape2D") as CollisionShape2D
	#     if sat_shape and target_shape:
	#         var sat_rect = sat_shape.shape.get_rect()
	#         var target_rect = target_shape.shape.get_rect()
	#         sat_rect.position = _satellite.global_position - sat_rect.size * 0.5
	#         target_rect.position = _target.global_position - target_rect.size * 0.5
	#         return sat_rect.intersects(target_rect)
	
	return false

func _deal_damage_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	
	# Check if the target has a damage handling method
	if _target.has_method("take_damage"):
		_target.take_damage(DAMAGE_AMOUNT)
	elif _target.has_method("damage"):
		_target.damage(DAMAGE_AMOUNT)
	elif _target.has_signal("damage_taken"):
		# Emit a damage signal if that's how your game handles it
		_target.emit_signal("damage_taken", DAMAGE_AMOUNT)
	else:
		# Fallback: Try to call a common damage method
		var damage_methods = ["hit", "on_hit", "receive_damage", "apply_damage"]
		for method in damage_methods:
			if _target.has_method(method):
				_target.call(method, DAMAGE_AMOUNT)
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
		if enemy.is_in_group("Meteor"):
			continue
		var distance: float = _satellite.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _get_dash_cooldown() -> float:
	return SHADOW_DASH_COOLDOWN if _is_shadow_mode_active else DASH_COOLDOWN
