extends RefCounted
class_name FastEnemyAbilityService

const ENEMY_MOVEMENT_SERVICE_SCRIPT := preload("res://Enemy/Scripts/Services/EnemyMovementService.gd")

const PATTERN_SINGLE_SHOT: int = 0
const PATTERN_SPREAD_SHOT: int = 1
const PATTERN_BURST_SHOT: int = 2
const PATTERN_AIMED_SHOT: int = 3
const SWOOP_SPEED_MULTIPLIER: float = 2.2
const SWOOP_MIN_SPEED: float = 500.0
const REENTRY_DELAY_MIN: float = 0.15
const REENTRY_DELAY_MAX: float = 0.45
const REENTRY_SPAWN_BUFFER: float = 130.0
const REENTRY_EXIT_BUFFER: float = 160.0
const REENTRY_TOP_MARGIN: float = 60.0
const REENTRY_DIAGONAL_MIN: float = 120.0
const REENTRY_DIAGONAL_MAX: float = 320.0

var _swoop_initialized: bool = false
var _waiting_for_reentry: bool = false
var _reentry_cooldown: float = 0.0
var _next_spawn_side: int = 0
var _swoop_velocity: Vector2 = Vector2.ZERO

func on_setup(enemy: Enemy) -> void:
	reset()
	enemy.movement_pattern = ENEMY_MOVEMENT_SERVICE_SCRIPT.MOVE_DIVE
	_next_spawn_side = -1 if enemy.formation_index % 2 == 0 else 1
	_disable_shooting(enemy)

func reset() -> void:
	_swoop_initialized = false
	_waiting_for_reentry = false
	_reentry_cooldown = 0.0
	_next_spawn_side = 0
	_swoop_velocity = Vector2.ZERO

func handle_movement(enemy: Enemy, delta: float) -> void:
	if not is_instance_valid(enemy):
		return

	if enemy.is_in_entry_phase and enemy.entry_path.size() > 0:
		enemy.movement_service.handle_movement(delta)
		if not enemy.is_in_entry_phase:
			_start_first_swoop(enemy)
		return

	if not _swoop_initialized:
		_start_first_swoop(enemy)

	if _waiting_for_reentry:
		_reentry_cooldown -= delta
		if _reentry_cooldown <= 0.0:
			_spawn_for_next_pass(enemy)
		return

	enemy.position += _swoop_velocity * delta

	if _is_outside_reentry_bounds(enemy):
		_enter_reentry_window()

func should_ignore_screen_exit(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	return enemy.is_alive and not enemy.is_in_entry_phase

func _disable_shooting(enemy: Enemy) -> void:
	enemy.can_shoot = false
	enemy.shoot_cooldown = INF

	enemy.normal_pattern_weights[PATTERN_SINGLE_SHOT] = 0
	enemy.normal_pattern_weights[PATTERN_AIMED_SHOT] = 0
	enemy.normal_pattern_weights[PATTERN_SPREAD_SHOT] = 0
	enemy.normal_pattern_weights[PATTERN_BURST_SHOT] = 0

	enemy.shadow_pattern_weights[PATTERN_SINGLE_SHOT] = 0
	enemy.shadow_pattern_weights[PATTERN_AIMED_SHOT] = 0
	enemy.shadow_pattern_weights[PATTERN_SPREAD_SHOT] = 0
	enemy.shadow_pattern_weights[PATTERN_BURST_SHOT] = 0

	if enemy.fire_timer:
		enemy.fire_timer.stop()

func _start_first_swoop(enemy: Enemy) -> void:
	_swoop_initialized = true
	_waiting_for_reentry = false
	_reentry_cooldown = 0.0

	var viewport_size: Vector2 = enemy.viewport_size
	if viewport_size == Vector2.ZERO and enemy.get_viewport():
		viewport_size = enemy.get_viewport().get_visible_rect().size

	var horizontal_sign: float = 1.0 if enemy.global_position.x <= viewport_size.x * 0.5 else -1.0
	var vertical_component: float = randf_range(0.35, 0.85)
	if enemy.global_position.y > viewport_size.y * 0.65:
		vertical_component = -randf_range(0.2, 0.55)

	var direction: Vector2 = Vector2(horizontal_sign, vertical_component).normalized()
	_swoop_velocity = direction * _get_swoop_speed(enemy)
	_next_spawn_side = -int(horizontal_sign)

func _spawn_for_next_pass(enemy: Enemy) -> void:
	var viewport_size: Vector2 = enemy.viewport_size
	if viewport_size == Vector2.ZERO and enemy.get_viewport():
		viewport_size = enemy.get_viewport().get_visible_rect().size

	var side: int = _next_spawn_side
	if side == 0:
		side = -1 if randf() < 0.5 else 1

	var spawn_x: float = -REENTRY_SPAWN_BUFFER if side < 0 else viewport_size.x + REENTRY_SPAWN_BUFFER
	var spawn_y: float = randf_range(REENTRY_TOP_MARGIN, viewport_size.y * 0.7)
	enemy.global_position = Vector2(spawn_x, spawn_y)

	var target_x: float = viewport_size.x + REENTRY_EXIT_BUFFER if side < 0 else -REENTRY_EXIT_BUFFER
	var y_shift: float = randf_range(REENTRY_DIAGONAL_MIN, REENTRY_DIAGONAL_MAX)
	if randf() < 0.35:
		y_shift *= -1.0
	var target_y: float = clamp(spawn_y + y_shift, -REENTRY_EXIT_BUFFER, viewport_size.y + REENTRY_EXIT_BUFFER)
	var target_pos: Vector2 = Vector2(target_x, target_y)

	var direction: Vector2 = (target_pos - enemy.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(1.0 if side < 0 else -1.0, 0.5).normalized()

	_swoop_velocity = direction * _get_swoop_speed(enemy)
	_next_spawn_side = -side
	_waiting_for_reentry = false
	_reentry_cooldown = 0.0

func _enter_reentry_window() -> void:
	_waiting_for_reentry = true
	_reentry_cooldown = randf_range(REENTRY_DELAY_MIN, REENTRY_DELAY_MAX)

func _is_outside_reentry_bounds(enemy: Enemy) -> bool:
	var viewport_size: Vector2 = enemy.viewport_size
	var pos: Vector2 = enemy.global_position
	return (
		pos.x < -REENTRY_EXIT_BUFFER
		or pos.x > viewport_size.x + REENTRY_EXIT_BUFFER
		or pos.y < -REENTRY_EXIT_BUFFER
		or pos.y > viewport_size.y + REENTRY_EXIT_BUFFER
	)

func _get_swoop_speed(enemy: Enemy) -> float:
	return maxf(SWOOP_MIN_SPEED, enemy.speed * SWOOP_SPEED_MULTIPLIER)
