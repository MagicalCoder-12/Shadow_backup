extends Area2D
class_name Enemy

var EBullet := preload("res://Bullet/Enemy_Bullet.tscn")
var ShadowEBullet := preload("res://Bullet/shadow_enemy_bullet.tscn")
var Bomb := preload("res://Bullet/shadow_enemy_bullet.tscn")

signal died
signal formation_reached

@onready var enemy_explosion: AnimatedSprite2D = $Enemy_Explosion
@onready var firing_positions: Node = $FiringPositions
@onready var healthbar: TextureProgressBar = $HealthBar
@onready var explosion_sound: AudioStreamPlayer = $Explosion2
@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var fire_timer: Timer = $FireTimer

@export var score: int = 100
@export var vertical_speed: float = 100.0
@export var max_health: int = 150
@export var damage_amount: int = 1
@export var speed: float = 200.0
@export var debug_mode: bool = false
@export var shadow_spawn_probability: float = 0.3
@export var shadow_health_multiplier: float = 1.5
@export var shadow_score_multiplier: float = 2.0
@export var shadow_damage_multiplier: float = 1.5
@export var fire_rate: float = 2.0
@export var entry_speed_multiplier: float = 1.0

# Dynamic difficulty multipliers with creative scaling (adjusted for 4 difficulty levels)
var difficulty_multipliers: Dictionary = {
	formation_enums.DifficultyLevel.EASY: {
		"health": 0.7, "damage": 0.8, "fire_rate": 0.6, "speed": 0.8, "score": 0.5, "shadow_chance": 0.1
	},
	formation_enums.DifficultyLevel.NORMAL: {
		"health": 1.0, "damage": 1.0, "fire_rate": 1.0, "speed": 1.0, "score": 1.0, "shadow_chance": 0.3
	},
	formation_enums.DifficultyLevel.HARD: {
		"health": 1.6, "damage": 1.5, "fire_rate": 1.6, "speed": 1.4, "score": 2.0, "shadow_chance": 0.6
	},
	formation_enums.DifficultyLevel.NIGHTMARE: {
		"health": 2.5, "damage": 2.2, "fire_rate": 2.2, "speed": 1.8, "score": 3.5, "shadow_chance": 0.8
	}
}

# Enhanced enemy behavior patterns
enum BehaviorPattern {
	STANDARD,
	AGGRESSIVE,
	DEFENSIVE,
	BERSERKER,
	PHANTOM
}

# New movement behaviors
enum MovementBehavior {
	SIDE_TO_SIDE,
	DIVING,
	BOMB_AND_RETREAT
}

@export var behavior_pattern: BehaviorPattern = BehaviorPattern.STANDARD
@export var movement_behavior: MovementBehavior = MovementBehavior.SIDE_TO_SIDE
@export var adaptive_difficulty: bool = false

var original_speed: float
var original_vertical_speed: float
var health: int = 0
var player_in_area: Player = null
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

# Enhanced combat variables
var rage_mode: bool = false
var rage_multiplier: float = 1.5
var current_difficulty: formation_enums.DifficultyLevel = formation_enums.DifficultyLevel.NORMAL
var behavior_timer: Timer
var evasion_chance: float = 0.0

var viewport_size: Vector2
const SCREEN_BUFFER: float = 100.0

# Movement behavior variables
var dive_target_position: Vector2
var is_diving: bool = false
var side_to_side_direction: int = 1

func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	original_speed = speed
	original_vertical_speed = vertical_speed
	original_modulate = modulate

	# Setup behavior timer for advanced patterns
	_setup_behavior_timer()

	_initialize_shadow_state()
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health

	if visible_on_screen_notifier_2d:
		# Adjust notifier to new dynamic viewport size
		var notifier_rect = Rect2(
			-SCREEN_BUFFER, -SCREEN_BUFFER,
			viewport_size.x + (SCREEN_BUFFER * 2),
			viewport_size.y + (SCREEN_BUFFER * 2)
		)
		visible_on_screen_notifier_2d.rect = notifier_rect

	add_to_group("Enemy")
	_connect_shadow_signals()

	if debug_mode:
		print("Enemy spawned at: ", global_position, " Shadow: ", is_shadow_enemy, " Difficulty: ", _get_difficulty_name(current_difficulty))

# Enhanced behavior timer setup
func _setup_behavior_timer():
	behavior_timer = Timer.new()
	behavior_timer.wait_time = randf_range(2.0, 5.0)
	behavior_timer.one_shot = false
	behavior_timer.timeout.connect(_on_behavior_timer_timeout)
	add_child(behavior_timer)
	behavior_timer.start()

# Dynamic behavior changes
func _on_behavior_timer_timeout():
	match behavior_pattern:
		BehaviorPattern.AGGRESSIVE:
			_trigger_aggressive_behavior()
		BehaviorPattern.DEFENSIVE:
			_trigger_defensive_behavior()
		BehaviorPattern.BERSERKER:
			_trigger_berserker_behavior()
		BehaviorPattern.PHANTOM:
			_trigger_phantom_behavior()
	
	# Potentially switch movement behavior mid-flight for dynamic gameplay
	if randf() < 0.1: # 10% chance to change movement
		movement_behavior = MovementBehavior.values().pick_random()


func _trigger_aggressive_behavior():
	if not rage_mode and health < max_health * 0.5:
		rage_mode = true
		fire_rate *= rage_multiplier
		speed *= 1.2
		modulate = Color.RED if not is_shadow_enemy else Color(0.8, 0.2, 0.8)

		if debug_mode:
			print("Enemy entered RAGE MODE!")

func _trigger_defensive_behavior():
	evasion_chance = min(0.3, evasion_chance + 0.05)
	if healthbar:
		healthbar.modulate = Color.GREEN

func _trigger_berserker_behavior():
	if health < max_health * 0.3:
		speed *= 1.5
		fire_rate *= 2.0
		damage_amount = int(damage_amount * 1.3)
		modulate = Color.ORANGE_RED if not is_shadow_enemy else Color(1.0, 0.5, 0.0)

func _trigger_phantom_behavior():
	if randf() < 0.3:
		var ghost_tween = create_tween()
		ghost_tween.tween_property(self, "modulate:a", 0.3, 0.5)
		ghost_tween.tween_property(self, "modulate:a", 1.0, 0.5)

func setup_formation_entry(config: WaveConfig, index: int, delay: float = 0.0):
	wave_config = config
	formation_index = index
	formation_delay = delay

	if not config or config.get_enemy_count() <= 0:
		if debug_mode:
			print("Enemy: Invalid WaveConfig or enemy_count, skipping setup")
		formation_position = Vector2(viewport_size.x / 2, 250) # Use dynamic viewport
		return

	current_difficulty = config.difficulty
	_apply_difficulty_multipliers(current_difficulty)
	_apply_behavior_pattern_modifiers()
	
	# Randomly assign a movement behavior
	movement_behavior = MovementBehavior.values().pick_random()


	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health

	if fire_timer:
		fire_timer.wait_time = 1.0 / fire_rate

	spawn_position = config.spawn_pos
	formation_position = config.center
	global_position = spawn_position

	if debug_mode:
		print("Enemy setup - Spawn: ", spawn_position,
			" Formation: ", formation_position,
			" Difficulty: ", _get_difficulty_name(current_difficulty),
			" Behavior: ", _get_behavior_name(behavior_pattern),
			" Movement: ", movement_behavior,
			" Health: ", max_health, " Damage: ", damage_amount,
			" Fire Rate: ", fire_rate, " Speed: ", speed)

func _get_adaptive_difficulty() -> formation_enums.DifficultyLevel:
	return wave_config.difficulty if wave_config else formation_enums.DifficultyLevel.NORMAL

func _apply_difficulty_multipliers(difficulty: formation_enums.DifficultyLevel):
	var multipliers = difficulty_multipliers[difficulty]
	max_health = int(max_health * multipliers["health"])
	damage_amount = int(damage_amount * multipliers["damage"])
	fire_rate = fire_rate * multipliers["fire_rate"]
	speed = speed * multipliers["speed"]
	score = int(score * multipliers["score"])
	shadow_spawn_probability = multipliers["shadow_chance"]

func _apply_behavior_pattern_modifiers():
	match behavior_pattern:
		BehaviorPattern.AGGRESSIVE:
			fire_rate *= 1.3
			speed *= 1.1
			damage_amount = int(damage_amount * 1.2)
		BehaviorPattern.DEFENSIVE:
			max_health = int(max_health * 1.4)
			evasion_chance = 0.15
		BehaviorPattern.BERSERKER:
			damage_amount = int(damage_amount * 1.5)
			max_health = int(max_health * 0.8)
			speed *= 1.2
		BehaviorPattern.PHANTOM:
			evasion_chance = 0.25
			shadow_spawn_probability *= 1.5

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

	if debug_mode:
		print("Enemy converted to shadow: Health=", max_health, " Damage=", damage_amount, " Score=", score)

func _apply_shadow_visuals():
	if not is_shadow_enemy:
		return
	modulate = Color(0.2, 0.2, 0.8, 0.7)
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
	if is_shadow_enemy:
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

func _physics_process(delta):
	if not is_alive:
		return
	
	# Handle movement logic based on current state and behavior
	_handle_movement(delta)

	# Boundary checks using dynamic viewport size
	global_position.x = clamp(global_position.x, -50, viewport_size.x + 50)
	

func _handle_movement(delta: float):
	# Entry phase movement
	if is_in_entry_phase:
		# Simple move towards formation position, can be customized later
		var direction = (formation_position - global_position).normalized()
		global_position += direction * speed * entry_speed_multiplier * delta
		if global_position.distance_to(formation_position) < 5.0:
			on_reach_formation()
		return
		
	# Post-formation movement behaviors
	if arrived_at_formation:
		match movement_behavior:
			MovementBehavior.SIDE_TO_SIDE:
				position.x += speed * side_to_side_direction * delta
				# Reverse direction at screen edges
				if (position.x > viewport_size.x - 50 and side_to_side_direction > 0) or \
				   (position.x < 50 and side_to_side_direction < 0):
					side_to_side_direction *= -1
			
			MovementBehavior.DIVING:
				if not is_diving:
					is_diving = true
					var target_y = global_position.y + randf_range(200, 400)
					var target_x = global_position.x + randf_range(-150, 150)
					dive_target_position = Vector2(clamp(target_x, 50, viewport_size.x - 50), target_y)
				
				global_position = global_position.move_toward(dive_target_position, vertical_speed * delta)
				if global_position.distance_to(dive_target_position) < 10.0:
					is_diving = false # will pick a new dive target on next frame

			MovementBehavior.BOMB_AND_RETREAT:
				if not is_diving: # Use diving state to manage the 'bombing' run
					is_diving = true
					dive_target_position = Vector2(global_position.x, viewport_size.y + 100) # Target below screen
				
				global_position = global_position.move_toward(dive_target_position, vertical_speed * 1.5 * delta)
				# Once it moves off-screen, it will be cleaned up by the notifier
	
	# Handle other advanced movements like AGGRESSIVE player tracking
	_handle_advanced_movement(delta)


func _handle_advanced_movement(delta: float):
	match behavior_pattern:
		BehaviorPattern.PHANTOM:
			var time = Time.get_time_dict_from_system()
			var wave_offset = sin(time.second * 2.0 + formation_index) * 30.0
			position.x += wave_offset * delta
		BehaviorPattern.AGGRESSIVE:
			if player_in_area:
				var direction = (player_in_area.global_position - global_position).normalized()
				position += direction * speed * 0.3 * delta


func fire():
	if arrived_at_formation and firing_positions and is_alive:
		for child in firing_positions.get_children():
			var bullet = ShadowEBullet.instantiate() if is_shadow_enemy else EBullet.instantiate()
			bullet.global_position = child.global_position

			if bullet.has_method("set_damage"):
				bullet.set_damage(damage_amount)
			if bullet.has_method("set_speed_multiplier"):
				var speed_mult = 1.0
				if current_difficulty >= formation_enums.DifficultyLevel.HARD:
					speed_mult = 1.3
				if behavior_pattern == BehaviorPattern.AGGRESSIVE:
					speed_mult *= 1.2
				bullet.set_speed_multiplier(speed_mult)

			get_tree().current_scene.call_deferred("add_child", bullet)

			if debug_mode:
				print("Enemy fired bullet. Shadow: ", is_shadow_enemy, " Difficulty: ", _get_difficulty_name(current_difficulty))

func damage(amount: int):
	if not is_alive or health <= 0 or is_in_entry_phase:
		if is_in_entry_phase and debug_mode: print("Enemy immune during entry phase")
		return

	if randf() < evasion_chance:
		if debug_mode: print("Enemy evaded attack!")
		return

	var final_damage = amount
	if is_shadow_enemy and GameManager.shadow_mode_enabled:
		final_damage = max(1, int(amount * 0.75))
	if behavior_pattern == BehaviorPattern.DEFENSIVE:
		final_damage = max(1, int(final_damage * 0.8))

	health -= final_damage

	if debug_mode:
		print("Enemy took damage: ", amount, " -> ", final_damage, " Health remaining: ", health)

	if healthbar:
		healthbar.value = health
		if health < max_health * 0.3:
			healthbar.modulate = Color.RED
		elif health < max_health * 0.6:
			healthbar.modulate = Color.YELLOW

	if health <= 0:
		death_reason = "health_depleted"
		die()

func die():
	if not is_alive: return
	is_alive = false

	if debug_mode:
		print("Enemy died. Reason: ", death_reason, " Position: ", global_position)

	var final_score = score
	if is_shadow_enemy:
		final_score = int(score * shadow_score_multiplier)
	match current_difficulty:
		formation_enums.DifficultyLevel.HARD: final_score = int(final_score * 1.3)
		formation_enums.DifficultyLevel.NIGHTMARE: final_score = int(final_score * 1.8)

	if debug_mode:
		print("Final score awarded: ", final_score, " (Base: ", score, ")")

	GameManager.score += final_score

	if shadow_tween: shadow_tween.kill()
	if explosion_sound: explosion_sound.play()

	if enemy_explosion:
		enemy_explosion.visible = true
		if is_shadow_enemy:
			enemy_explosion.modulate = Color(0.5, 0.5, 1.0, 1.0)
		elif rage_mode:
			enemy_explosion.modulate = Color(1.5, 0.5, 0.5, 1.0)
		enemy_explosion.play("default")

	died.emit()
	if enemy_explosion:
		await enemy_explosion.animation_finished
	queue_free()

func on_reach_formation():
	is_in_entry_phase = false
	arrived_at_formation = true
	if debug_mode:
		print("Enemy reached formation at: ", global_position)
	formation_reached.emit()

func _on_area_entered(area):
	if area is Player and player_in_area == null:
		player_in_area = area
		var final_damage = damage_amount
		if is_shadow_enemy:
			final_damage = int(damage_amount * shadow_damage_multiplier)
		player_in_area.damage(final_damage)
		if healthbar: healthbar.hide()
		death_reason = "player_collision"
		die()

func _on_area_exited(area):
	if area is Player:
		player_in_area = null

func _on_visible_on_screen_notifier_2d_screen_exited():
	# Only destroy the enemy if it has already been on screen.
	# This prevents it from being deleted if it spawns off-screen.
	if is_alive and has_entered_screen:
		if debug_mode:
			print("Enemy died: Exited screen after entering.")
		death_reason = "screen_exit"
		# Use queue_free directly instead of die() to avoid explosion/score for off-screen enemies
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	if not has_entered_screen:
		has_entered_screen = true
		if debug_mode:
			print("Enemy entered screen at: ", global_position)

func force_shadow_conversion():
	if not is_shadow_enemy:
		_make_shadow_enemy()

func is_shadow() -> bool:
	return is_shadow_enemy

func get_shadow_info() -> Dictionary:
	return {
		"is_shadow": is_shadow_enemy, "shadow_health_multiplier": shadow_health_multiplier,
		"shadow_score_multiplier": shadow_score_multiplier, "shadow_damage_multiplier": shadow_damage_multiplier,
		"shadow_spawn_probability": shadow_spawn_probability
	}

func get_difficulty_info() -> Dictionary:
	return {
		"current_difficulty": current_difficulty, "difficulty_name": _get_difficulty_name(current_difficulty),
		"behavior_pattern": behavior_pattern, "behavior_name": _get_behavior_name(behavior_pattern),
		"rage_mode": rage_mode, "evasion_chance": evasion_chance
	}

func get_status() -> String:
	return "Alive: %s, Formation: %s, Health: %d/%d, Pos: %s, Shadow: %s, Entry: %s, Difficulty: %s, Behavior: %s" % [
		is_alive, arrived_at_formation, health, max_health, global_position, is_shadow_enemy, is_in_entry_phase,
		_get_difficulty_name(current_difficulty), _get_behavior_name(behavior_pattern)
	]

func get_formation_info() -> Dictionary:
	return {
		"spawn_pos": spawn_position, "formation_pos": formation_position,
		"formation_index": formation_index, "is_in_entry": is_in_entry_phase,
		"arrived_at_formation": arrived_at_formation
	}

func set_difficulty(difficulty: formation_enums.DifficultyLevel):
	current_difficulty = difficulty
	_apply_difficulty_multipliers(difficulty)

func set_behavior_pattern(pattern: BehaviorPattern):
	behavior_pattern = pattern
	_apply_behavior_pattern_modifiers()

func get_combat_effectiveness() -> float:
	var effectiveness = 1.0
	effectiveness *= (float(health) / float(max_health))
	effectiveness *= (1.0 + (fire_rate - 1.0) * 0.5)
	effectiveness *= (1.0 + (damage_amount - 1.0) * 0.3)
	if is_shadow_enemy: effectiveness *= 1.5
	if rage_mode: effectiveness *= rage_multiplier
	return effectiveness

func _get_difficulty_name(difficulty: formation_enums.DifficultyLevel) -> String:
	match difficulty:
		formation_enums.DifficultyLevel.EASY: return "EASY"
		formation_enums.DifficultyLevel.NORMAL: return "NORMAL"
		formation_enums.DifficultyLevel.HARD: return "HARD"
		formation_enums.DifficultyLevel.NIGHTMARE: return "NIGHTMARE"
		_: return "UNKNOWN"

func _get_behavior_name(pattern: BehaviorPattern) -> String:
	match pattern:
		BehaviorPattern.STANDARD: return "STANDARD"
		BehaviorPattern.AGGRESSIVE: return "AGGRESSIVE"
		BehaviorPattern.DEFENSIVE: return "DEFENSIVE"
		BehaviorPattern.BERSERKER: return "BERSERKER"
		BehaviorPattern.PHANTOM: return "PHANTOM"
		_: return "UNKNOWN"

func _exit_tree():
	if shadow_tween: shadow_tween.kill()
	if behavior_timer: behavior_timer.queue_free()
	if GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.disconnect(_on_shadow_mode_activated)
	if GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.disconnect(_on_shadow_mode_deactivated)
