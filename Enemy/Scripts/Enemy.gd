extends Area2D
class_name Enemy

# --- Preloaded Resources ---
var EBullet := preload("res://Bullet/Enemy_Bullet.tscn")
var ShadowEBullet := preload("res://Bullet/shadow_enemy_bullet.tscn")
var Bomb := preload("res://Bullet/Bomb.tscn")

# --- Signals ---
signal died
signal formation_reached
signal behavior_changed(new_behavior: BehaviorPattern)
signal movement_changed(new_movement: MovementBehavior)

# --- Node References ---
@onready var enemy_explosion: AnimatedSprite2D = $Enemy_Explosion
@onready var firing_positions: Node = $FiringPositions
@onready var healthbar: TextureProgressBar = $HealthBar
@onready var explosion_sound: AudioStreamPlayer = $Explosion2
@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var fire_timer: Timer = $FireTimer
@onready var shadow_core_shield: AnimatedSprite2D = $ShadowCoreShield

# --- Exported Properties ---
@export var score: int = 100
@export var vertical_speed: float = 400.0
@export var max_health: int = 200
@export var damage_amount: int = 1
@export var speed: float = 200.0
@export var debug_mode: bool = false
@export var shadow_spawn_probability: float = 0.3
@export var shadow_health_multiplier: float = 1.5
@export var shadow_score_multiplier: float = 2.0
@export var shadow_damage_multiplier: float = 1.5
@export var fire_rate: float = 2.0
@export var entry_speed_multiplier: float = 1.0
@export var entry_shadow_shield_time: float = 2.0
@export var shadow_texture: Texture2D  # New export for custom shadow texture

# --- Difficulty System ---
var difficulty_multipliers: Dictionary = {
	formation_enums.DifficultyLevel.EASY: {
		"health": 0.7, "damage": 0.8, "fire_rate": 0.6, "speed": 0.8, "score": 0.5, "shadow_chance": 0.1
	},
	formation_enums.DifficultyLevel.NORMAL: {
		"health": 1.0, "damage": 1.0, "fire_rate": 1.0, "speed": 1.0, "score": 1.0, "shadow_chance": 0.3
	},
	formation_enums.DifficultyLevel.HARD: {
		"health": 2.6, "damage": 1.0, "fire_rate": 1.6, "speed": 1.4, "score": 2.0, "shadow_chance": 0.8
	},
	formation_enums.DifficultyLevel.NIGHTMARE: {
		"health": 3.5, "damage": 1.0, "fire_rate": 2.2, "speed": 2.8, "score": 3.5, "shadow_chance": 0.9
	}
}

# --- Enums ---
enum BombAndRetreatPhase { IDLE, DIVING, RETREATING }

enum BehaviorPattern {
	STANDARD, AGGRESSIVE, DEFENSIVE, BERSERKER, PHANTOM, TACTICAL, KAMIKAZE, ADAPTIVE
}

enum MovementBehavior {
	SIDE_TO_SIDE, DIVING, BOMB_AND_RETREAT, CIRCLING, ZIGZAG, FORMATION_HOLD, FLANKING, SWARM
}

# --- Behavior-Movement Synergies ---
var behavior_movement_synergies: Dictionary = {
	BehaviorPattern.AGGRESSIVE: [MovementBehavior.DIVING, MovementBehavior.FLANKING, MovementBehavior.CIRCLING],
	BehaviorPattern.DEFENSIVE: [MovementBehavior.FORMATION_HOLD, MovementBehavior.SIDE_TO_SIDE],
	BehaviorPattern.BERSERKER: [MovementBehavior.BOMB_AND_RETREAT, MovementBehavior.DIVING],
	BehaviorPattern.PHANTOM: [MovementBehavior.ZIGZAG, MovementBehavior.CIRCLING],
	BehaviorPattern.TACTICAL: [MovementBehavior.FORMATION_HOLD, MovementBehavior.SWARM],
	BehaviorPattern.KAMIKAZE: [MovementBehavior.SIDE_TO_SIDE, MovementBehavior.BOMB_AND_RETREAT],
	BehaviorPattern.ADAPTIVE: [MovementBehavior.SIDE_TO_SIDE, MovementBehavior.ZIGZAG]
}

# --- Exported Behavior Config ---
@export var behavior_pattern: BehaviorPattern = BehaviorPattern.STANDARD
@export var movement_behavior: MovementBehavior = MovementBehavior.SIDE_TO_SIDE
@export var adaptive_difficulty: bool = false
@export var enable_behavior_evolution: bool = false

# --- State Variables ---
var original_speed: float
var original_vertical_speed: float
var health: int = 0
var player_in_area: Player = null
var target_player: Player = null
var arrived_at_formation: bool = false
var is_alive: bool = true
var death_reason: String = ""
var spawn_position: Vector2
var formation_position: Vector2
var formation_index: int = 0
var wave_config: WaveConfig = null
var formation_delay: float = 0.0
var has_entered_screen: bool = false
var is_in_entry_phase: bool = true
var is_shadow_enemy: bool = false
var shadow_tween: Tween
var original_modulate: Color
var shadow_pulse_speed: float = 2.0
var shadow_alpha_min: float = 0.4
var shadow_alpha_max: float = 0.8
var bomb_and_retreat_phase: BombAndRetreatPhase = BombAndRetreatPhase.IDLE
var bomb_and_retreat_cooldown: float = 0.0
var rage_mode: bool = false
var rage_multiplier: float = 1.5
var current_difficulty: formation_enums.DifficultyLevel = formation_enums.DifficultyLevel.NORMAL
var behavior_timer: Timer
var movement_timer: Timer
var evasion_chance: float = 0.0
var behavior_change_cooldown: float = 0.0
var time_since_last_behavior_change: float = 0.0
var player_distance_history: Array[float] = []
var shots_fired: int = 0
var hits_taken: int = 0
var survival_time: float = 0.0
var side_to_side_direction: int = 1
var dive_target_position: Vector2
var is_diving: bool = false
var circle_center: Vector2
var circle_radius: float = 150.0
var circle_angle: float = 0.0
var zigzag_direction: Vector2
var zigzag_change_timer: float = 0.0
var formation_allies: Array[Enemy] = []
var viewport_size: Vector2
const SCREEN_BUFFER: float = 200.0
var time_since_spawn: float = 0.0
var shield_damage_reduction: float = 0.5
var original_texture: Texture2D  # To store the original texture

# --- Initialization ---
func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	original_speed = speed
	original_vertical_speed = vertical_speed
	original_modulate = modulate
	original_texture = sprite.texture  # Store the original texture

	_setup_timers()
	_initialize_behavior_synergy()
	_initialize_shadow_state()

	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health

	if visible_on_screen_notifier_2d:
		var notifier_rect = Rect2(
			-SCREEN_BUFFER, -SCREEN_BUFFER,
			viewport_size.x + (SCREEN_BUFFER * 2),
			viewport_size.y + (SCREEN_BUFFER * 2)
		)
		visible_on_screen_notifier_2d.rect = notifier_rect

	_connect_shadow_signals()
	_connect_signals()

	_update_player_reference()
	if debug_mode and target_player:
		print("Enemy found target player: ", target_player.name)
	if shadow_core_shield:
		shadow_core_shield.visible = true
		shadow_core_shield.play("default")

	if debug_mode:
		print("Enhanced Enemy spawned - Behavior: ", _get_behavior_name(behavior_pattern), 
			  " Movement: ", _get_movement_name(movement_behavior))

func _setup_timers():
	behavior_timer = Timer.new()
	behavior_timer.wait_time = randf_range(3.0, 8.0)
	behavior_timer.one_shot = false
	behavior_timer.timeout.connect(_on_behavior_timer_timeout)
	add_child(behavior_timer)
	behavior_timer.start()
	
	movement_timer = Timer.new()
	movement_timer.wait_time = randf_range(2.0, 5.0)
	movement_timer.one_shot = false
	movement_timer.timeout.connect(_on_movement_timer_timeout)
	add_child(movement_timer)
	movement_timer.start()

func _initialize_behavior_synergy():
	if behavior_pattern in behavior_movement_synergies:
		var synergistic_movements = behavior_movement_synergies[behavior_pattern]
		if movement_behavior not in synergistic_movements and enable_behavior_evolution:
			if randf() < 0.3:
				movement_behavior = synergistic_movements.pick_random()
				if debug_mode:
					print("Adjusted movement to synergize with behavior: ", _get_movement_name(movement_behavior))

# --- Process Logic ---
func _physics_process(delta: float) -> void:
	if not is_alive or not is_instance_valid(self):
		return
	
	survival_time += delta
	time_since_spawn += delta
	time_since_last_behavior_change += delta
	
	_update_player_reference()
	
	if is_instance_valid(player_in_area):
		player_distance_history.append(global_position.distance_to(player_in_area.global_position))
		if player_distance_history.size() > 10:
			player_distance_history.pop_front()
	
	_handle_movement(delta)
	_update_behavioral_state(delta)
	_handle_entry_shield(delta)
	
	global_position.x = clamp(global_position.x, -50, viewport_size.x + 50)

func _update_player_reference():
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			target_player = players[0]
			if debug_mode:
				print("Updated target player reference to: ", target_player.name)
		else:
			target_player = null
			if debug_mode:
				print("No valid player found for enemy at ", global_position)

func _handle_entry_shield(_delta: float):
	if time_since_spawn >= entry_shadow_shield_time:
		if shadow_core_shield and shadow_core_shield.visible:
			shadow_core_shield.visible = false
			if debug_mode:
				print("Entry shield deactivated for enemy at ", global_position)
	else:
		if shadow_core_shield:
			var alpha = (sin(time_since_spawn * 5.0) + 1.0) / 2.0
			shadow_core_shield.modulate.a = alpha

func _update_behavioral_state(delta: float):
	if behavior_change_cooldown > 0:
		behavior_change_cooldown -= delta
	
	if behavior_pattern == BehaviorPattern.ADAPTIVE:
		_handle_adaptive_behavior()

func _handle_adaptive_behavior():
	if player_distance_history.size() < 5:
		return
		
	var avg_distance = 0.0
	for dist in player_distance_history:
		avg_distance += dist
	avg_distance /= player_distance_history.size()
	
	if avg_distance < 200 and movement_behavior != MovementBehavior.ZIGZAG:
		_change_movement_behavior(MovementBehavior.ZIGZAG)
	elif avg_distance > 400 and movement_behavior != MovementBehavior.DIVING:
		_change_movement_behavior(MovementBehavior.DIVING)

# --- Behavior Evolution ---
func _on_behavior_timer_timeout():
	if not enable_behavior_evolution or behavior_change_cooldown > 0:
		return
	
	var health_percent = float(health) / float(max_health)
	
	match behavior_pattern:
		BehaviorPattern.STANDARD:
			if health_percent < 0.5:
				_evolve_behavior(BehaviorPattern.AGGRESSIVE)
		BehaviorPattern.AGGRESSIVE:
			if health_percent < 0.3:
				_evolve_behavior(BehaviorPattern.BERSERKER)
		BehaviorPattern.DEFENSIVE:
			if hits_taken > 3:
				_evolve_behavior(BehaviorPattern.PHANTOM)
		BehaviorPattern.BERSERKER:
			if health_percent < 0.15:
				_evolve_behavior(BehaviorPattern.KAMIKAZE)
		BehaviorPattern.TACTICAL:
			if survival_time > 20.0:
				_evolve_behavior(BehaviorPattern.ADAPTIVE)

func _on_movement_timer_timeout():
	if randf() < 0.15 and enable_behavior_evolution:
		var possible_movements = behavior_movement_synergies.get(behavior_pattern, MovementBehavior.values())
		var new_movement = possible_movements.pick_random()
		if new_movement != movement_behavior:
			_change_movement_behavior(new_movement)

func _evolve_behavior(new_behavior: BehaviorPattern):
	if behavior_change_cooldown > 0:
		return
		
	var old_behavior = behavior_pattern
	behavior_pattern = new_behavior
	behavior_change_cooldown = 5.0
	time_since_last_behavior_change = 0.0
	
	_apply_behavior_pattern_modifiers()
	
	if behavior_pattern in behavior_movement_synergies:
		var synergistic_movements = behavior_movement_synergies[behavior_pattern]
		if movement_behavior not in synergistic_movements:
			_change_movement_behavior(synergistic_movements.pick_random())
	
	behavior_changed.emit(new_behavior)
	
	if debug_mode:
		print("Enemy evolved from ", _get_behavior_name(old_behavior), " to ", _get_behavior_name(new_behavior))

func _change_movement_behavior(new_movement: MovementBehavior):
	movement_behavior = new_movement
	movement_changed.emit(new_movement)
	
	is_diving = false
	circle_angle = 0.0
	zigzag_change_timer = 0.0
	
	if debug_mode:
		print("Movement changed to: ", _get_movement_name(new_movement))

# --- Movement Logic ---
func _handle_movement(delta: float):
	if is_in_entry_phase:
		var direction = (formation_position - global_position).normalized()
		global_position += direction * speed * entry_speed_multiplier * delta
		if global_position.distance_to(formation_position) < 5.0:
			on_reach_formation()
		return
	
	if not arrived_at_formation:
		return
		
	match movement_behavior:
		MovementBehavior.SIDE_TO_SIDE:
			_handle_side_to_side_movement(delta)
		MovementBehavior.DIVING:
			_handle_diving_movement(delta)
		MovementBehavior.BOMB_AND_RETREAT:
			_handle_bomb_and_retreat_movement(delta)
		MovementBehavior.CIRCLING:
			_handle_circling_movement(delta)
		MovementBehavior.ZIGZAG:
			_handle_zigzag_movement(delta)
		MovementBehavior.FORMATION_HOLD:
			_handle_formation_hold_movement(delta)
		MovementBehavior.FLANKING:
			_handle_flanking_movement(delta)
		MovementBehavior.SWARM:
			_handle_swarm_movement(delta)
	
	_handle_behavior_specific_movement(delta)

func _handle_side_to_side_movement(delta: float):
	position.x += speed * side_to_side_direction * delta
	if (position.x > viewport_size.x - 50 and side_to_side_direction > 0) or \
	   (position.x < 50 and side_to_side_direction < 0):
		side_to_side_direction *= -1

func _handle_diving_movement(delta: float):
	if not is_diving:
		is_diving = true
		var target_y = global_position.y + randf_range(200, 400)
		var target_x = global_position.x + randf_range(-150, 150)
		dive_target_position = Vector2(clamp(target_x, 50, viewport_size.x - 50), target_y)
	
	global_position = global_position.move_toward(dive_target_position, vertical_speed * delta)
	if global_position.distance_to(dive_target_position) < 10.0:
		is_diving = false

func _handle_bomb_and_retreat_movement(delta: float):
	if bomb_and_retreat_cooldown > 0:
		bomb_and_retreat_cooldown -= delta
		return

	if bomb_and_retreat_phase == BombAndRetreatPhase.IDLE and bomb_and_retreat_cooldown <= 0:
		bomb_and_retreat_phase = BombAndRetreatPhase.DIVING
		if is_instance_valid(target_player):
			dive_target_position = target_player.global_position + Vector2(randf_range(-100, 100), randf_range(-50, 50))
			dive_target_position.y = clamp(dive_target_position.y, 0, viewport_size.y * 0.75)
		else:
			dive_target_position = Vector2(global_position.x + randf_range(-150, 150), viewport_size.y * 0.5)
		bomb_and_retreat_cooldown = 3.0
		if debug_mode:
			print("Enemy starting dive towards: ", dive_target_position)

	elif bomb_and_retreat_phase == BombAndRetreatPhase.DIVING:
		global_position = global_position.move_toward(dive_target_position, vertical_speed * 1.5 * delta)
		if global_position.distance_to(dive_target_position) < 10.0:
			_drop_bomb()
			bomb_and_retreat_phase = BombAndRetreatPhase.RETREATING
			if debug_mode:
				print("Enemy reached dive target, bomb dropped at ", global_position)

	elif bomb_and_retreat_phase == BombAndRetreatPhase.RETREATING:
		global_position = global_position.move_toward(formation_position, speed * delta)
		if global_position.distance_to(formation_position) < 5.0:
			bomb_and_retreat_phase = BombAndRetreatPhase.IDLE
			if debug_mode:
				print("Enemy returned to formation")

func _drop_bomb():
	var bomb = Bomb.instantiate()
	bomb.global_position = global_position
	get_tree().current_scene.add_child(bomb)

func _handle_circling_movement(delta: float):
	if player_in_area:
		circle_center = player_in_area.global_position
	else:
		circle_center = formation_position
	
	circle_angle += speed * delta * 0.01
	var offset = Vector2(cos(circle_angle), sin(circle_angle)) * circle_radius
	var target_pos = circle_center + offset
	global_position = global_position.move_toward(target_pos, speed * delta)

func _handle_zigzag_movement(delta: float):
	zigzag_change_timer += delta
	if zigzag_change_timer >= 1.0:
		zigzag_direction = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)).normalized()
		zigzag_change_timer = 0.0
	
	global_position += zigzag_direction * speed * delta

func _handle_formation_hold_movement(delta: float):
	if global_position.distance_to(formation_position) > 20.0:
		var direction = (formation_position - global_position).normalized()
		global_position += direction * speed * 0.3 * delta

func _handle_flanking_movement(delta: float):
	if player_in_area:
		var player_pos = player_in_area.global_position
		var flank_offset = Vector2(100, -50) if global_position.x < player_pos.x else Vector2(-100, -50)
		var target_pos = player_pos + flank_offset
		global_position = global_position.move_toward(target_pos, speed * delta)

func _handle_swarm_movement(delta: float):
	_update_formation_allies()
	if formation_allies.size() > 0:
		var center = Vector2.ZERO
		for ally in formation_allies:
			center += ally.global_position
		center /= formation_allies.size()
		
		var direction = (center - global_position).normalized()
		global_position += direction * speed * 0.5 * delta

func _handle_behavior_specific_movement(delta: float):
	if not is_alive:
		return
	
	match behavior_pattern:
		BehaviorPattern.PHANTOM:
			var time_offset = Time.get_time_dict_from_system().second
			var wave_offset = sin(time_offset * 2.0 + formation_index) * 30.0
			position.x += wave_offset * delta
		BehaviorPattern.AGGRESSIVE:
			if player_in_area:
				var direction = (player_in_area.global_position - global_position).normalized()
				position += direction * speed * 0.3 * delta
		BehaviorPattern.KAMIKAZE:
			if bomb_and_retreat_cooldown > 0:
				bomb_and_retreat_cooldown -= delta
			elif is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) < 1000:
				_drop_bomb()
				bomb_and_retreat_cooldown = 3.0
				side_to_side_direction = 1 if randf() > 0.5 else -1
			else:
				position.x += speed * side_to_side_direction * delta
				if (position.x > viewport_size.x - 50 and side_to_side_direction > 0) or \
				   (position.x < 50 and side_to_side_direction < 0):
					side_to_side_direction *= -1

func _update_formation_allies():
	formation_allies.clear()
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if enemy != self and enemy.global_position.distance_to(global_position) < 200:
			formation_allies.append(enemy)

# --- Firing System ---
func fire():
	if not (arrived_at_formation and firing_positions and is_alive):
		return
		
	shots_fired += 1
	
	match behavior_pattern:
		BehaviorPattern.AGGRESSIVE:
			_fire_aggressive_pattern()
		BehaviorPattern.BERSERKER:
			_fire_berserker_pattern()
		BehaviorPattern.TACTICAL:
			_fire_tactical_pattern()
		_:
			_fire_standard_pattern()

func _fire_standard_pattern():
	for child in firing_positions.get_children():
		_create_and_fire_bullet(child.global_position)

func _fire_aggressive_pattern():
	for child in firing_positions.get_children():
		_create_and_fire_bullet(child.global_position)
		var spread_angle = randf_range(-0.3, 0.3)
		var spread_pos = child.global_position + Vector2(sin(spread_angle) * 20, 0)
		_create_and_fire_bullet(spread_pos)

func _fire_berserker_pattern():
	for i in range(3):
		for child in firing_positions.get_children():
			_create_and_fire_bullet(child.global_position)

func _fire_tactical_pattern():
	for child in firing_positions.get_children():
		_create_and_fire_bullet(child.global_position)

func _create_and_fire_bullet(pos: Vector2):
	var bullet = ShadowEBullet.instantiate() if is_shadow_enemy else EBullet.instantiate()
	bullet.global_position = pos

	if bullet.has_method("set_damage"):
		var bullet_damage = int(damage_amount * (shadow_damage_multiplier if is_shadow_enemy and GameManager.shadow_mode_enabled else 1.0))
		bullet.set_damage(bullet_damage)
		if debug_mode:
			print("Bullet fired with damage: ", bullet_damage)
	if bullet.has_method("set_speed_multiplier"):
		var speed_mult = 1.0
		if current_difficulty >= formation_enums.DifficultyLevel.HARD:
			speed_mult = 1.3
		if behavior_pattern == BehaviorPattern.AGGRESSIVE:
			speed_mult *= 1.2
		bullet.set_speed_multiplier(speed_mult)

	get_tree().current_scene.call_deferred("add_child", bullet)

# --- Damage System ---
func damage(amount: int):
	if not is_alive or health <= 0:
		return

	hits_taken += 1
	
	var final_damage = amount
	match behavior_pattern:
		BehaviorPattern.DEFENSIVE:
			final_damage = max(1, int(final_damage * 0.8))
		BehaviorPattern.PHANTOM:
			if randf() < 0.3:
				if debug_mode: print("Phantom enemy evaded attack!")
				return

	if is_shadow_enemy and GameManager.shadow_mode_enabled:
		final_damage = max(1, int(final_damage * 0.75))

	if time_since_spawn < entry_shadow_shield_time:
		final_damage = int(final_damage * shield_damage_reduction)
		_show_shield_hit_feedback()

	health -= final_damage

	if debug_mode:
		print("Enemy took damage: ", amount, " -> ", final_damage, " Health: ", health)

	if healthbar:
		healthbar.value = health
		if health < max_health * 0.3:
			healthbar.modulate = Color.RED
		elif health < max_health * 0.6:
			healthbar.modulate = Color.YELLOW

	if health < max_health * 0.3 and behavior_pattern == BehaviorPattern.STANDARD:
		_evolve_behavior(BehaviorPattern.AGGRESSIVE)

	if health <= 0:
		death_reason = "health_depleted"
		die()

func _show_shield_hit_feedback():
	if shadow_core_shield:
		var tween = create_tween()
		tween.tween_property(shadow_core_shield, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.1)
		tween.tween_property(shadow_core_shield, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

# --- Formation Setup ---
func setup_formation_entry(config: WaveConfig, index: int, formation_pos: Vector2, delay: float = 0.0):
	wave_config = config
	formation_index = index
	formation_delay = delay
	
	if not config or config.get_enemy_count() <= 0:
		formation_position = Vector2(viewport_size.x / 2, 250)
		return
	
	current_difficulty = config.difficulty
	_apply_difficulty_multipliers(current_difficulty)
	_apply_behavior_pattern_modifiers()
	
	if randf() < 0.3:
		behavior_pattern = BehaviorPattern.values().pick_random()
		movement_behavior = MovementBehavior.values().pick_random()
		_initialize_behavior_synergy()
	
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	if fire_timer:
		fire_timer.wait_time = 1.0 / fire_rate
	
	spawn_position = config.spawn_pos if config.spawn_pos != Vector2.ZERO else global_position
	formation_position = formation_pos
	global_position = spawn_position

# --- Shadow Mode ---
func _initialize_shadow_state():
	if GameManager.shadow_mode_unlocked and GameManager.shadow_mode_enabled:
		if randf() < shadow_spawn_probability:
			_make_shadow_enemy()

func _make_shadow_enemy():
	is_shadow_enemy = true
	max_health = int(max_health * shadow_health_multiplier)
	damage_amount = int(damage_amount * shadow_damage_multiplier)
	score = int(score * shadow_score_multiplier)
	_apply_shadow_visuals()

func _apply_shadow_visuals():
	if not is_shadow_enemy:
		return
	if shadow_texture:
		sprite.texture = shadow_texture
	else:
		# Fallback to modulation with a lighter color for visibility
		modulate = Color(0.4, 0.4, 1.0, 0.7)  # Lighter blue shade
		_start_shadow_pulse()
	if healthbar:
		healthbar.modulate = Color(0.5, 0.5, 1.0, 0.8)

func _start_shadow_pulse():
	if shadow_tween:
		shadow_tween.kill()
	shadow_tween = create_tween().set_loops()
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_max, shadow_alpha_min, shadow_pulse_speed / 2.0)
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_min, shadow_alpha_max, shadow_pulse_speed / 2.0)

func _set_shadow_alpha(alpha: float):
	if is_shadow_enemy and not shadow_texture:  # Only pulse if using modulation
		modulate.a = alpha

func _connect_shadow_signals():
	if GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		return
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)

func _on_shadow_mode_activated():
	if debug_mode: print("Shadow mode activated for enemy")
	if not is_shadow_enemy and randf() < shadow_spawn_probability:
		_make_shadow_enemy()

func _on_shadow_mode_deactivated():
	if debug_mode: print("Shadow mode deactivated for enemy")

func toggle_shadow_mode(enabled: bool):
	if enabled and not is_shadow_enemy:
		if randf() < shadow_spawn_probability:
			_make_shadow_enemy()
	elif not enabled and is_shadow_enemy:
		_revert_from_shadow()

func _revert_from_shadow():
	is_shadow_enemy = false
	if shadow_texture:
		sprite.texture = original_texture
	else:
		modulate = original_modulate
	if shadow_tween:
		shadow_tween.kill()
	
	max_health = int(max_health / shadow_health_multiplier)
	damage_amount = 1
	score = int(score / shadow_score_multiplier)
	
	var health_percent = float(health) / float(max_health * shadow_health_multiplier)
	health = int(max_health * health_percent)
	
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.modulate = Color.WHITE

# --- Death Logic ---
func die():
	if not is_alive or not is_instance_valid(self):
		return
	is_alive = false

	if debug_mode:
		print("Enemy died. Reason: ", death_reason, " Survival time: ", survival_time)

	var final_score = score
	if is_shadow_enemy:
		final_score = int(score * shadow_score_multiplier)
	
	if behavior_pattern == BehaviorPattern.ADAPTIVE and survival_time > 15.0:
		final_score = int(final_score * 1.5)
	elif behavior_pattern == BehaviorPattern.PHANTOM and hits_taken < 2:
		final_score = int(final_score * 1.3)
	elif behavior_pattern == BehaviorPattern.TACTICAL and shots_fired > 10:
		final_score = int(final_score * 1.2)
	
	if behavior_pattern == BehaviorPattern.BERSERKER:
		_perform_berserker_death()
	elif behavior_pattern == BehaviorPattern.TACTICAL:
		_perform_tactical_death()
	
	GameManager.score += final_score
	
	# Disconnect signals to prevent further processing
	if behavior_timer:
		if behavior_timer.timeout.is_connected(_on_behavior_timer_timeout):
			behavior_timer.timeout.disconnect(_on_behavior_timer_timeout)
		behavior_timer.queue_free()
	if movement_timer:
		if movement_timer.timeout.is_connected(_on_movement_timer_timeout):
			movement_timer.timeout.disconnect(_on_movement_timer_timeout)
		movement_timer.queue_free()
	if shadow_tween:
		shadow_tween.kill()
	if fire_timer:
		if fire_timer.timeout.is_connected(_on_fire_timer_timeout):
			fire_timer.timeout.disconnect(_on_fire_timer_timeout)
	
	_play_death_animation()
	
	died.emit()

func _perform_berserker_death():
	for i in range(8):
		var angle = (PI * 2 / 8) * i
		var bullet_pos = global_position + Vector2(cos(angle), sin(angle)) * 30
		_create_and_fire_bullet(bullet_pos)

func _perform_tactical_death():
	var nearby_enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in nearby_enemies:
		if enemy != self and enemy.global_position.distance_to(global_position) < 300:
			if enemy.has_method("receive_tactical_alert"):
				enemy.receive_tactical_alert(global_position)

func _play_death_animation():
	if enemy_explosion:
		enemy_explosion.visible = true
		enemy_explosion.play("explode")
		if enemy_explosion.animation_finished.is_connected(_on_death_animation_finished):
			enemy_explosion.animation_finished.disconnect(_on_death_animation_finished)
		enemy_explosion.animation_finished.connect(_on_death_animation_finished)
	
	if explosion_sound:
		explosion_sound.play()
	
	if sprite:
		sprite.visible = false
	if healthbar:
		healthbar.visible = false

func _on_death_animation_finished():
	queue_free()

# --- AI Communication ---
func receive_tactical_alert(alert_position: Vector2):
	if not is_alive:
		return
	
	if behavior_pattern == BehaviorPattern.TACTICAL:
		var temp_behavior = behavior_pattern
		behavior_pattern = BehaviorPattern.AGGRESSIVE
		
		await get_tree().create_timer(5.0).timeout
		if is_alive:
			behavior_pattern = temp_behavior
	
	if movement_behavior == MovementBehavior.FORMATION_HOLD:
		var danger_distance = global_position.distance_to(alert_position)
		if danger_distance < 200:
			_change_movement_behavior(MovementBehavior.ZIGZAG)

# --- Formation Coordination ---
func get_formation_neighbors(radius: float = 150.0) -> Array[Enemy]:
	var neighbors: Array[Enemy] = []
	var enemies = get_tree().get_nodes_in_group("Enemy")
	
	for enemy in enemies:
		if enemy != self and enemy.global_position.distance_to(global_position) < radius:
			neighbors.append(enemy as Enemy)
	
	return neighbors

func coordinate_formation_attack():
	if behavior_pattern != BehaviorPattern.TACTICAL:
		return
	
	var neighbors = get_formation_neighbors()
	if neighbors.size() >= 2:
		fire()
		for neighbor in neighbors:
			if neighbor.has_method("fire"):
				neighbor.fire()

# --- Difficulty Scaling ---
func adapt_to_player_performance():
	if not player_in_area:
		return
	
	var player_health_percent = 1.0
	if player_in_area.has_method("get_health_percent"):
		player_health_percent = player_in_area.get_health_percent()
	
	if player_health_percent < 0.3:
		fire_rate *= 0.9
		speed *= 0.95
	elif player_health_percent > 0.8:
		fire_rate *= 1.1
		speed *= 1.05

# --- Utility Methods ---
func _get_behavior_name(behavior: BehaviorPattern) -> String:
	match behavior:
		BehaviorPattern.STANDARD: return "STANDARD"
		BehaviorPattern.AGGRESSIVE: return "AGGRESSIVE"
		BehaviorPattern.DEFENSIVE: return "DEFENSIVE"
		BehaviorPattern.BERSERKER: return "BERSERKER"
		BehaviorPattern.PHANTOM: return "PHANTOM"
		BehaviorPattern.TACTICAL: return "TACTICAL"
		BehaviorPattern.KAMIKAZE: return "KAMIKAZE"
		BehaviorPattern.ADAPTIVE: return "ADAPTIVE"
		_: return "UNKNOWN"

func _get_movement_name(movement: MovementBehavior) -> String:
	match movement:
		MovementBehavior.SIDE_TO_SIDE: return "SIDE_TO_SIDE"
		MovementBehavior.DIVING: return "DIVING"
		MovementBehavior.BOMB_AND_RETREAT: return "BOMB_AND_RETREAT"
		MovementBehavior.CIRCLING: return "CIRCLING"
		MovementBehavior.ZIGZAG: return "ZIGZAG"
		MovementBehavior.FORMATION_HOLD: return "FORMATION_HOLD"
		MovementBehavior.FLANKING: return "FLANKING"
		MovementBehavior.SWARM: return "SWARM"
		_: return "UNKNOWN"

func _apply_difficulty_multipliers(difficulty: formation_enums.DifficultyLevel):
	var multipliers = difficulty_multipliers[difficulty]
	max_health = int(max_health * multipliers["health"])
	fire_rate = fire_rate * multipliers["fire_rate"]
	speed = speed * multipliers["speed"]
	score = int(score * multipliers["score"])
	shadow_spawn_probability = multipliers["shadow_chance"]

func _apply_behavior_pattern_modifiers():
	match behavior_pattern:
		BehaviorPattern.AGGRESSIVE:
			fire_rate *= 1.3
			speed *= 1.1
		BehaviorPattern.DEFENSIVE:
			max_health = int(max_health * 1.4)
			evasion_chance = 0.15
		BehaviorPattern.BERSERKER:
			max_health = int(max_health * 0.8)
			speed *= 1.2
		BehaviorPattern.PHANTOM:
			evasion_chance = 0.25
			shadow_spawn_probability *= 1.5
		BehaviorPattern.TACTICAL:
			fire_rate *= 1.1
			max_health = int(max_health * 1.2)
		BehaviorPattern.KAMIKAZE:
			max_health = int(max_health * 0.6)
			speed *= 1.5
		BehaviorPattern.ADAPTIVE:
			pass

func on_reach_formation():
	is_in_entry_phase = false
	arrived_at_formation = true
	circle_center = formation_position
	if debug_mode:
		print("Enemy reached formation at: ", global_position)
	formation_reached.emit()

# --- Performance Optimization ---
func _on_visible_on_screen_notifier_2d_screen_exited():
	if not arrived_at_formation:
		return
	
	set_physics_process(false)
	
	var reactivate_timer = Timer.new()
	reactivate_timer.wait_time = 0.5
	reactivate_timer.one_shot = true
	reactivate_timer.timeout.connect(_reactivate_processing)
	add_child(reactivate_timer)
	reactivate_timer.start()

func _on_visible_on_screen_notifier_2d_screen_entered():
	set_physics_process(true)

func _reactivate_processing():
	set_physics_process(true)

# --- Debug and Analytics ---
func get_performance_stats() -> Dictionary:
	return {
		"survival_time": survival_time,
		"shots_fired": shots_fired,
		"hits_taken": hits_taken,
		"behavior_changes": time_since_last_behavior_change,
		"current_behavior": _get_behavior_name(behavior_pattern),
		"current_movement": _get_movement_name(movement_behavior),
		"is_shadow": is_shadow_enemy,
		"health_percent": float(health) / float(max_health)
	}

# --- Signal Handlers ---
func _on_fire_timer_timeout():
	if not is_alive or not is_instance_valid(self) or not arrived_at_formation:
		return

	if movement_behavior == MovementBehavior.BOMB_AND_RETREAT and bomb_and_retreat_phase != BombAndRetreatPhase.IDLE:
		return

	var should_fire = true
	match behavior_pattern:
		BehaviorPattern.DEFENSIVE:
			should_fire = is_instance_valid(player_in_area) and global_position.distance_to(player_in_area.global_position) < 300
		BehaviorPattern.PHANTOM:
			should_fire = randf() < 0.7
		BehaviorPattern.TACTICAL:
			if randf() < 0.3:
				coordinate_formation_attack()
				return

	if should_fire:
		fire()
		
func _on_area_entered(area):
	if not is_instance_valid(area) or not is_alive:
		return
	if area is Player and player_in_area == null:
		player_in_area = area
		var collision_damage = int(damage_amount * (shadow_damage_multiplier if is_shadow_enemy and GameManager.shadow_mode_enabled else 1.0))
		if is_instance_valid(player_in_area):
			player_in_area.damage(collision_damage)
		if debug_mode:
			print("Enemy collided with player, dealing damage: ", collision_damage)
		if healthbar:
			healthbar.hide()
		die()
		
func _on_area_exited(area):
	if area.get_parent() is Player:
		player_in_area = null

func _connect_signals():
	if fire_timer:
		fire_timer.timeout.connect(_on_fire_timer_timeout)
