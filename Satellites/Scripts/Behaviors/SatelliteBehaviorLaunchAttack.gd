extends SatelliteBehaviorBase
class_name SatelliteBehaviorLaunchAttack

const DASH_SPEED: float = 900.0
const DASH_DURATION: float = 0.35
const RETURN_SPEED: float = 650.0
const RETURN_STOP_DISTANCE: float = 2.0
const DASH_COOLDOWN: float = 1.75
const SHADOW_DASH_COOLDOWN: float = 1.15

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

func setup(satellite: Node2D) -> void:
	super.setup(satellite)
	_home_local_position = satellite.position
	_state = DashState.IDLE
	_target = null
	_dash_elapsed = 0.0
	_cooldown_remaining = DASH_COOLDOWN

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

func _process_dash(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_state = DashState.RETURNING
		return

	_satellite.global_position = _satellite.global_position.move_toward(_target.global_position, DASH_SPEED * delta)
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
		_cooldown_remaining = _get_dash_cooldown()

func _move_back_to_home(delta: float) -> void:
	_satellite.position = _satellite.position.move_toward(_home_local_position, RETURN_SPEED * delta)

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
