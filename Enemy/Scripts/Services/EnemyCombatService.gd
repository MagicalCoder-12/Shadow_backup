extends RefCounted
class_name EnemyCombatService

const PATTERN_SINGLE_SHOT: int = 0
const PATTERN_SPREAD_SHOT: int = 1
const PATTERN_BURST_SHOT: int = 2
const PATTERN_AIMED_SHOT: int = 3

const DIFF_EASY: int = 0
const DIFF_NORMAL: int = 1
const DIFF_HARD: int = 2
const DIFF_NIGHTMARE: int = 3
const EBULLET: PackedScene = preload("res://Bullet/Ebullet/Enemy_Bullet.tscn")
const SHADOW_EBULLET: PackedScene = preload("res://Bullet/Ebullet/shadow_enemy_bullet.tscn")
const BOMB: PackedScene = preload("res://Bullet/Ebullet/Bomb.tscn")
const BOMB_SCRIPT = preload("res://Bullet/Scripts/bomb.gd")

var _enemy: Node = null

func configure(enemy: Node) -> void:
	_enemy = enemy

func reset_enemy_type_state() -> void:
	if _enemy and _enemy.has_method("reset_enemy_type_state"):
		_enemy.call("reset_enemy_type_state")

func setup_fire_timer() -> void:
	if not _enemy or not _enemy.fire_timer:
		return
	_enemy.fire_timer.one_shot = false
	_enemy.fire_timer.wait_time = 1.0 / maxf(0.01, float(_enemy.fire_rate))
	var timeout_callable := Callable(_enemy, "_on_fire_timer_timeout")
	if not _enemy.fire_timer.timeout.is_connected(timeout_callable):
		_enemy.fire_timer.timeout.connect(timeout_callable)
	_enemy.fire_timer.start()

func handle_shooting(delta: float) -> void:
	if not _enemy:
		return
	if not _enemy.arrived_at_formation or not is_instance_valid(_enemy.player_reference):
		return
	if not _enemy.can_shoot:
		_enemy.shoot_cooldown -= delta
		if _enemy.shoot_cooldown <= 0.0:
			_enemy.can_shoot = true
		return
	if _is_bomber_enemy():
		handle_bomber_shooting()

func handle_bomber_shooting() -> void:
	if not _enemy:
		return
	if not _enemy.has_method("can_drop_bomb"):
		return
	if not bool(_enemy.call("can_drop_bomb", _enemy.time_since_spawn)):
		return
	drop_bomb()
	if _enemy.has_method("register_bomb_drop"):
		_enemy.call("register_bomb_drop", _enemy.time_since_spawn)

func on_fire_timer_timeout() -> void:
	if not _enemy:
		return
	if not _enemy.is_alive or not _enemy.arrived_at_formation or not is_instance_valid(_enemy.player_reference):
		return
	if not _enemy.can_shoot:
		return
	var pattern: int = select_weighted_attack_pattern()
	execute_attack_pattern(pattern)
	apply_shooting_cooldown()

func select_weighted_attack_pattern() -> int:
	if not _enemy:
		return PATTERN_SINGLE_SHOT
	var weights: Dictionary = _enemy.shadow_pattern_weights if bool(_enemy.is_shadow_mode_active) else _enemy.normal_pattern_weights
	var total_weight: int = 0
	for weight in weights.values():
		total_weight += int(weight)
	if total_weight <= 0:
		return PATTERN_SINGLE_SHOT
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for pattern in weights.keys():
		cumulative += int(weights[pattern])
		if roll < cumulative:
			return int(pattern)
	return PATTERN_SINGLE_SHOT

func execute_attack_pattern(pattern: int) -> void:
	match pattern:
		PATTERN_SINGLE_SHOT:
			fire_single_shot()
		PATTERN_AIMED_SHOT:
			fire_at_player()
		PATTERN_SPREAD_SHOT:
			fire_spread_shot(2, PI / 8.0)
		PATTERN_BURST_SHOT:
			fire_burst_shot(2, 0.12)
		_:
			fire_at_player()

func fire_single_shot() -> void:
	if not _enemy:
		return
	var bullet_scene: PackedScene = SHADOW_EBULLET if _enemy.is_shadow_enemy else EBULLET
	var bullet: Node = bullet_scene.instantiate()
	if not bullet:
		return
	bullet.global_position = _enemy.global_position
	bullet.rotation = PI / 2.0
	SceneSpawnService.spawn_child(bullet)

func apply_shooting_cooldown() -> void:
	if not _enemy:
		return
	_enemy.can_shoot = false
	var difficulty_modifier: float = 1.0
	match int(_enemy.current_difficulty):
		DIFF_EASY:
			difficulty_modifier = 1.3
		DIFF_NORMAL:
			difficulty_modifier = 1.0
		DIFF_HARD:
			difficulty_modifier = 0.85
		DIFF_NIGHTMARE:
			difficulty_modifier = 0.7
	if bool(_enemy.is_shadow_mode_active):
		difficulty_modifier *= 0.9
	var cooldown_range: float = _enemy.max_shoot_cooldown - _enemy.min_shoot_cooldown
	_enemy.shoot_cooldown = (_enemy.min_shoot_cooldown + randf() * cooldown_range) * difficulty_modifier

func fire_at_player() -> void:
	if not _enemy:
		return
	var bullet_scene: PackedScene = SHADOW_EBULLET if _enemy.is_shadow_enemy else EBULLET
	var bullet: Node = bullet_scene.instantiate()
	if not bullet:
		return
	bullet.global_position = _enemy.global_position
	_enemy._update_player_reference()
	var direction: Vector2 = Vector2(0, 1)
	if is_instance_valid(_enemy.player_reference):
		direction = (_enemy.player_reference.global_position - _enemy.global_position).normalized()
	bullet.rotation = direction.angle() + PI / 2.0
	SceneSpawnService.spawn_child(bullet)
	if _enemy.debug_mode:
		print("Enemy fired bullet")

func fire_spread_shot(bullet_count: int = 2, spread_angle: float = PI / 6.0) -> void:
	if not _enemy:
		return
	for i in range(bullet_count):
		var bullet_scene: PackedScene = SHADOW_EBULLET if _enemy.is_shadow_enemy else EBULLET
		var bullet: Node = bullet_scene.instantiate()
		if not bullet:
			continue
		var angle_offset: float = spread_angle * (i - (bullet_count - 1) / 2.0) / maxf(1.0, float(bullet_count - 1))
		var direction: Vector2 = Vector2(0, 1)
		if is_instance_valid(_enemy.player_reference):
			direction = (_enemy.player_reference.global_position - _enemy.global_position).normalized()
		direction = direction.rotated(angle_offset)
		bullet.global_position = _enemy.global_position
		bullet.rotation = direction.angle() + PI / 2.0
		SceneSpawnService.spawn_child(bullet)

func fire_burst_shot(burst_count: int = 2, _burst_delay: float = 0.15) -> void:
	if not _enemy:
		return
	for i in range(burst_count):
		var bullet_scene: PackedScene = SHADOW_EBULLET if _enemy.is_shadow_enemy else EBULLET
		var bullet: Node = bullet_scene.instantiate()
		if not bullet:
			continue
		var direction: Vector2 = Vector2(0, 1)
		if is_instance_valid(_enemy.player_reference):
			direction = (_enemy.player_reference.global_position - _enemy.global_position).normalized()
		var angle_variation: float = (i - (burst_count - 1) / 2.0) * 0.05
		direction = direction.rotated(angle_variation)
		bullet.global_position = _enemy.global_position
		bullet.rotation = direction.angle() + PI / 2.0
		SceneSpawnService.spawn_child(bullet)

func drop_bomb() -> void:
	if not _enemy:
		return
	if not _is_bomber_enemy():
		return
	if BOMB_SCRIPT.active_bombs >= BOMB_SCRIPT.MAX_ACTIVE_BOMBS:
		return
	var bomb_instance: Node = BOMB.instantiate()
	if bomb_instance:
		bomb_instance.global_position = _enemy.global_position
		SceneSpawnService.spawn_child(bomb_instance)

func _is_bomber_enemy() -> bool:
	if not _enemy:
		return false
	if _enemy.has_method("is_bomber_enemy"):
		return bool(_enemy.call("is_bomber_enemy"))
	return false
