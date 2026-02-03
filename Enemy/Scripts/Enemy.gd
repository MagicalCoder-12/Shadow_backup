extends Area2D
class_name Enemy

# Import formation_enums to access shared enums
const formations_enums = preload("res://Enemy Manager/Scripts/formation_enums.gd")

# --- Preloaded Resources ---
const EBULLET = preload("res://Bullet/Ebullet/Enemy_Bullet.tscn")
const SHADOW_EBULLET = preload("res://Bullet/Ebullet/shadow_enemy_bullet.tscn")
const BOMB = preload("res://Bullet/Ebullet/Bomb.tscn")
const BOMB_SCRIPT = preload("res://Bullet/Scripts/bomb.gd")  # Add this line to access bomb script

# --- Signals ---
signal died
signal enemy_died(payload)
signal formation_reached
signal shadow_state_changed(is_shadow: bool)

# --- Node References ---
@onready var enemy_explosion: AnimatedSprite2D = $Enemy_Explosion
@onready var firing_positions: Node = $FiringPositions
@onready var healthbar: TextureProgressBar = $HealthBar
@onready var explosion_sound: AudioStreamPlayer = $Explosion2
@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var fire_timer: Timer = $FireTimer
@onready var shadow_core_shield: AnimatedSprite2D = $ShadowCoreShield
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

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
@export var shadow_damage_multiplier: float = 1.0
@export var fire_rate: float = 1.5  # Reduced from 2.0 to 1.5
@export var entry_speed_multiplier: float = 1.0
@export var entry_shadow_shield_time: float = 2.0
@export var shadow_texture: Texture2D
@export var enemy_type: String = "standard"

# --- Bomber Enemy Properties ---
var last_bomb_drop_time: float = 0.0
const BOMB_DROP_COOLDOWN: float = 3.0  # Increased from 2.0 to 3.0 seconds (minimum time between bomb drops)
var bombs_dropped: int = 0
const MAX_BOMBS_PER_ENEMY: int = 3  # Reduced from 5 to 3 (maximum bombs a single bomber can drop)

# --- Optimized Attack Pattern System ---
enum AttackPattern { SINGLE_SHOT, SPREAD_SHOT, BURST_SHOT, AIMED_SHOT }

# Pattern weights (configurable per difficulty/mode)
var normal_pattern_weights: Dictionary = {
	AttackPattern.SINGLE_SHOT: 60,    # 60% - most common
	AttackPattern.AIMED_SHOT: 25,     # 25% - aimed at player
	AttackPattern.SPREAD_SHOT: 10,    # 10% - 2 bullet spread
	AttackPattern.BURST_SHOT: 5       # 5% - quick burst
}

var shadow_pattern_weights: Dictionary = {
	AttackPattern.SINGLE_SHOT: 40,    # 40% - still common but reduced
	AttackPattern.AIMED_SHOT: 30,     # 30% - more aimed shots
	AttackPattern.SPREAD_SHOT: 20,    # 20% - more spread
	AttackPattern.BURST_SHOT: 10      # 10% - more burst
}

# Shooting cooldown management
var can_shoot: bool = true
var shoot_cooldown: float = 0.0
var base_shoot_cooldown: float = 1.5  # Base time between shots
var min_shoot_cooldown: float = 0.8   # Minimum time between shots
var max_shoot_cooldown: float = 2.5   # Maximum time between shots

# --- Shadow Visual Properties ---
var shadow_pulse_speed: float = 2.0
var shadow_alpha_min: float = 0.4
var shadow_alpha_max: float = 0.8

# --- Difficulty System ---
var difficulty_multipliers: Dictionary = {
	formation_enums.DifficultyLevel.EASY: {
		"health": 0.8, "damage": 0.7, "fire_rate": 0.7, "speed": 0.8, "score": 0.8, "shadow_chance": 0.05
	},
	formation_enums.DifficultyLevel.NORMAL: {
		"health": 1.0, "damage": 1.0, "fire_rate": 0.8, "speed": 1.0, "score": 1.0, "shadow_chance": 0.3  # Reduced fire_rate from 1.0 to 0.8
	},
	formation_enums.DifficultyLevel.HARD: {
		"health": 1.5, "damage": 1.3, "fire_rate": 1.0, "speed": 1.2, "score": 1.5, "shadow_chance": 0.5  # Reduced fire_rate from 1.3 to 1.0
	},
	formation_enums.DifficultyLevel.NIGHTMARE: {
		"health": 2.0, "damage": 1.5, "fire_rate": 1.2, "speed": 1.5, "score": 2.0, "shadow_chance": 0.7  # Reduced fire_rate from 1.5 to 1.2
	}
}

# --- Movement Behavior ---
enum MovementPattern { 
	FORMATION_HOLD, 
	SIDE_TO_SIDE, 
	CIRCLE, 
	DIVE,
	DIVE_BOMB_PATTERN,  # New pattern
	SWARM_PATTERN,      # New pattern
	AMBUSH_PATTERN      # New pattern
}
@export var movement_pattern: MovementPattern = MovementPattern.FORMATION_HOLD

# --- New Exported Properties for Enhanced Movement Patterns ---
@export var dive_bomb_probability: float = 0.1
@export var swarm_coherence: float = 0.8
@export var ambush_probability: float = 0.15
@export var elite_spawn_probability: float = 0.05

# --- Core State Variables ---
var original_speed: float
var original_vertical_speed: float
var health: int = 0
var player_reference: Player = null
var arrived_at_formation: bool = false
var is_alive: bool = true
var spawn_position: Vector2
var formation_position: Vector2
var formation_index: int = 0
var wave_config: WaveConfig = null
var entry_path: Array[Vector2] = []
var entry_path_index: int = 0
var is_in_entry_phase: bool = true
var is_shadow_enemy: bool = false
var is_shadow_mode_active: bool = false
var shadow_mode_unlocked: bool = false
var shadow_tween: Tween
var original_modulate: Color
var original_texture: Texture2D

# --- Movement Variables ---
var current_difficulty: formation_enums.DifficultyLevel = formation_enums.DifficultyLevel.NORMAL
var side_to_side_direction: int = 1
var circle_center: Vector2
var circle_radius: float = 80.0
var circle_angle: float = 0.0
var viewport_size: Vector2
var time_since_spawn: float = 0.0
var shield_damage_reduction: float = 0.7

# --- New Variables for Enhanced Movement Patterns ---
var should_dive_bomb: bool = false
var is_diving: bool = false
var dive_target: Vector2
var swarm_center: Vector2
var ambush_position: Vector2
var is_ambushing: bool = false

# --- Initialization ---
func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	original_speed = speed
	original_vertical_speed = vertical_speed
	original_modulate = modulate
	if sprite:
		original_texture = sprite.texture
	
	# Ensure enemy scale is not smaller than 1.0
	if sprite and sprite.scale.x < 1.0:
		sprite.scale = Vector2(1.0, 1.0)
	
	tree_exiting.connect(_on_tree_exiting)
	
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	
	_setup_fire_timer()
	_connect_signals()
	_update_player_reference()
	_initialize_shadow_state()
	
	# Reset bomber counters
	bombs_dropped = 0
	last_bomb_drop_time = 0.0
	
	if shadow_core_shield:
		shadow_core_shield.visible = true
		shadow_core_shield.play("default")
	
	# Initialize new movement pattern variables
	_init_movement_patterns()
	
	if debug_mode:
		print("Enemy spawned: ", enemy_type)

func _init_movement_patterns():
	"""Initialize movement pattern variables and load config settings"""
	# Load settings from config
	_load_attack_settings_from_config()
	_load_movement_settings_from_config()
	
	# Initialize variables for movement patterns
	should_dive_bomb = randf() < dive_bomb_probability
	is_diving = false
	dive_target = Vector2.ZERO
	swarm_center = formation_position if formation_position != Vector2.ZERO else global_position
	ambush_position = Vector2.ZERO
	is_ambushing = false
	
	# Initialize shooting cooldown
	can_shoot = true
	shoot_cooldown = 0.0

func _load_attack_settings_from_config():
	"""Load attack settings from game_settings.json"""
	if not ConfigLoader or not ConfigLoader.game_settings:
		return
	
	var attack_settings = ConfigLoader.game_settings.get("enemy_attack_settings", {})
	if attack_settings.is_empty():
		return
	
	# Load cooldown settings
	base_shoot_cooldown = attack_settings.get("base_shoot_cooldown", base_shoot_cooldown)
	min_shoot_cooldown = attack_settings.get("min_shoot_cooldown", min_shoot_cooldown)
	max_shoot_cooldown = attack_settings.get("max_shoot_cooldown", max_shoot_cooldown)
	
	# Load pattern weights
	var normal_weights = attack_settings.get("normal_pattern_weights", {})
	if not normal_weights.is_empty():
		normal_pattern_weights[AttackPattern.SINGLE_SHOT] = normal_weights.get("single_shot", 60)
		normal_pattern_weights[AttackPattern.AIMED_SHOT] = normal_weights.get("aimed_shot", 25)
		normal_pattern_weights[AttackPattern.SPREAD_SHOT] = normal_weights.get("spread_shot", 10)
		normal_pattern_weights[AttackPattern.BURST_SHOT] = normal_weights.get("burst_shot", 5)
	
	var shadow_weights = attack_settings.get("shadow_pattern_weights", {})
	if not shadow_weights.is_empty():
		shadow_pattern_weights[AttackPattern.SINGLE_SHOT] = shadow_weights.get("single_shot", 40)
		shadow_pattern_weights[AttackPattern.AIMED_SHOT] = shadow_weights.get("aimed_shot", 30)
		shadow_pattern_weights[AttackPattern.SPREAD_SHOT] = shadow_weights.get("spread_shot", 20)
		shadow_pattern_weights[AttackPattern.BURST_SHOT] = shadow_weights.get("burst_shot", 10)

func _load_movement_settings_from_config():
	"""Load movement settings from game_settings.json"""
	if not ConfigLoader or not ConfigLoader.game_settings:
		return
	
	var movement_settings = ConfigLoader.game_settings.get("movement_settings", {})
	if movement_settings.is_empty():
		return
	
	swarm_coherence = movement_settings.get("swarm_coherence", swarm_coherence)
	dive_bomb_probability = movement_settings.get("dive_bomb_probability", dive_bomb_probability)
	ambush_probability = movement_settings.get("ambush_probability", ambush_probability)
	circle_radius = movement_settings.get("circle_radius", circle_radius)

func _on_tree_exiting():
	if debug_mode:
		print("Enemy: Tree exiting - cleaning up")
	_disconnect_all_signals()
	
	# Kill shadow tween if it exists
	if shadow_tween:
		shadow_tween.kill()
		shadow_tween = null

func _setup_fire_timer():
	if fire_timer:
		fire_timer.wait_time = 1.0 / fire_rate
		fire_timer.timeout.connect(_on_fire_timer_timeout)
		fire_timer.start()

func _connect_signals():
	if visible_on_screen_notifier_2d:
		# Only connect screen_entered if not already connected
		if not visible_on_screen_notifier_2d.is_connected("screen_entered", _on_visible_on_screen_notifier_2d_screen_entered):
			visible_on_screen_notifier_2d.screen_entered.connect(_on_visible_on_screen_notifier_2d_screen_entered)
			if debug_mode:
				print("Boss: Connected screen_entered signal")
		else:
			if debug_mode:
				print("Boss: Skipped connecting screen_entered signal - already connected")
		
		# Only connect screen_exited if not already connected
		if not visible_on_screen_notifier_2d.is_connected("screen_exited", _on_visible_on_screen_notifier_2d_screen_exited):
			visible_on_screen_notifier_2d.screen_exited.connect(_on_visible_on_screen_notifier_2d_screen_exited)
			if debug_mode:
				print("Boss: Connected screen_exited signal")
		else:
			if debug_mode:
				print("Boss: Skipped connecting screen_exited signal - already connected")
	

func _disconnect_all_signals():
	if shadow_tween:
		shadow_tween.kill()
		shadow_tween = null

func _physics_process(delta: float) -> void:
	if not is_alive or not is_instance_valid(self):
		return
	
	time_since_spawn += delta
	
	_update_player_reference()
	_handle_movement(delta)
	_handle_entry_shield(delta)
	_handle_shooting(delta)
	
	# Keep enemy within screen bounds with buffer
	global_position.x = clamp(global_position.x, -50, viewport_size.x + 50)

func _update_player_reference():
	if not is_instance_valid(player_reference):
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_reference = players[0]
		else:
			player_reference = null

func _handle_entry_shield(_delta: float):
	if time_since_spawn >= entry_shadow_shield_time:
		if shadow_core_shield and shadow_core_shield.visible:
			shadow_core_shield.visible = false
			if debug_mode:
				print("Entry shield deactivated")
	else:
		if shadow_core_shield:
			var alpha = (sin(time_since_spawn * 5.0) + 1.0) / 2.0
			shadow_core_shield.modulate.a = alpha

func _handle_movement(delta: float):
	if is_in_entry_phase and entry_path.size() > 0:
		_follow_entry_path(delta)
	else:
		_perform_formation_movement(delta)

func _follow_entry_path(delta: float):
	if entry_path_index >= entry_path.size():
		_reach_formation()
		return
	
	var target_pos = entry_path[entry_path_index]
	var direction = (target_pos - global_position).normalized()
	var move_speed = speed * entry_speed_multiplier
	
	global_position += direction * move_speed * delta
	
	# Check if we're close enough to the next waypoint
	if global_position.distance_to(target_pos) < 20.0:
		entry_path_index += 1

func _reach_formation():
	is_in_entry_phase = false
	arrived_at_formation = true
	global_position = formation_position
	formation_reached.emit()
	
	if debug_mode:
		print("Enemy reached formation position")

func _perform_formation_movement(delta: float):
	"""Handle movement after reaching formation position"""
	match movement_pattern:
		MovementPattern.FORMATION_HOLD:
			_handle_formation_hold(delta)
		MovementPattern.SIDE_TO_SIDE:
			_handle_side_to_side(delta)
		MovementPattern.CIRCLE:
			_handle_circle_movement(delta)
		MovementPattern.DIVE:
			_handle_dive_pattern(delta)
		MovementPattern.DIVE_BOMB_PATTERN:
			_handle_dive_bomb_pattern(delta)
		MovementPattern.SWARM_PATTERN:
			_handle_swarm_pattern(delta)
		MovementPattern.AMBUSH_PATTERN:
			_handle_ambush_pattern(delta)

func _handle_formation_hold(delta: float):
	"""Stay at formation position with slight drift"""
	var drift = Vector2(
		sin(time_since_spawn * 0.5 + formation_index) * 5.0,
		cos(time_since_spawn * 0.3) * 3.0
	)
	var target = formation_position + drift
	global_position = global_position.lerp(target, 2.0 * delta)

func _handle_side_to_side(delta: float):
	"""Move side to side around formation position with smooth easing"""
	var amplitude = 50.0
	if ConfigLoader and ConfigLoader.game_settings:
		var movement_settings = ConfigLoader.game_settings.get("movement_settings", {})
		amplitude = movement_settings.get("side_to_side_amplitude", amplitude)
	
	# Use unique offset per enemy for variety
	var phase_offset = formation_index * 0.5
	var side_offset = sin(time_since_spawn * 2.0 + phase_offset) * amplitude
	var target_pos = formation_position + Vector2(side_offset, 0)
	global_position = global_position.lerp(target_pos, 3.0 * delta)

func _handle_circle_movement(delta: float):
	"""Circle around formation position"""
	# Vary rotation speed per enemy
	var rotation_speed = 2.0 + (formation_index % 3) * 0.3
	circle_angle += delta * rotation_speed
	var circle_offset = Vector2(cos(circle_angle), sin(circle_angle)) * circle_radius
	global_position = formation_position + circle_offset

func _handle_dive_pattern(delta: float):
	"""Occasional dive towards player with smooth recovery"""
	if is_instance_valid(player_reference) and randf() < 0.002:  # Less frequent dives
		var dive_direction = (player_reference.global_position - global_position).normalized()
		global_position += dive_direction * speed * 2.0 * delta
	else:
		# Smooth return to formation
		global_position = global_position.lerp(formation_position, 3.0 * delta)

# --- New Movement Pattern Implementations ---

func _handle_dive_bomb_pattern(delta: float):
	if should_dive_bomb and not is_diving:
		is_diving = true
		# Instead of diving, just drop a bomb from current position and return to formation
		_drop_bomb()
		is_diving = false  # Reset dive state immediately
	
	# Return to formation when not diving
	global_position = global_position.lerp(formation_position, 2.0 * delta)

func _handle_swarm_pattern(delta: float):
	"""Move in coordinated swarm behavior with nearby enemies"""
	# Calculate swarm offset based on multiple factors for more organic movement
	var time_factor = time_since_spawn * swarm_coherence
	
	# Layer multiple sine waves for complex movement
	var primary_wave = Vector2(
		sin(time_factor) * 35.0,
		cos(time_factor * 0.7) * 25.0
	)
	
	# Secondary wave offset by formation index for variety
	var secondary_wave = Vector2(
		sin(time_factor * 1.5 + formation_index * 0.8) * 15.0,
		cos(time_factor * 1.2 + formation_index * 0.6) * 10.0
	)
	
	# Combine waves with formation position
	var swarm_offset = primary_wave + secondary_wave
	
	# Add slight attraction to center of formation for cohesion
	var center_attraction = (swarm_center - global_position) * 0.02
	swarm_offset += center_attraction
	
	var target_pos = formation_position + swarm_offset
	
	# Smooth lerp with slightly faster response
	global_position = global_position.lerp(target_pos, 2.5 * delta)

func _handle_ambush_pattern(delta: float):
	"""Hide at screen edges and ambush the player with improved behavior"""
	if not is_ambushing:
		# Set up initial ambush position at screen edge
		_setup_ambush_position()
		is_ambushing = true
	else:
		_execute_ambush_behavior(delta)

func _setup_ambush_position():
	"""Set up the initial ambush position"""
	# Use formation index to distribute enemies on different sides
	if formation_index % 2 == 0:
		# Left edge
		ambush_position = Vector2(-30, randf_range(100, viewport_size.y - 100))
	else:
		# Right edge
		ambush_position = Vector2(viewport_size.x + 30, randf_range(100, viewport_size.y - 100))
	
	global_position = ambush_position

func _execute_ambush_behavior(delta: float):
	"""Execute the ambush behavior - wait and attack"""
	if not is_instance_valid(player_reference):
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	# Attack when player comes close enough
	if distance_to_player < 350:
		# Rush towards player
		var direction = (player_reference.global_position - global_position).normalized()
		global_position += direction * speed * 1.8 * delta
		
		# Check if we've passed the player, then retreat
		if global_position.y > player_reference.global_position.y + 100:
			is_ambushing = false  # Reset to set up new ambush
	else:
		# Slowly creep towards center while waiting
		var creep_target = ambush_position.lerp(Vector2(viewport_size.x / 2, ambush_position.y), 0.15)
		global_position = global_position.lerp(creep_target, 0.5 * delta)

func _handle_shooting(delta: float):
	if not arrived_at_formation or not is_instance_valid(player_reference):
		return
	
	# Manage shooting cooldown
	if not can_shoot:
		shoot_cooldown -= delta
		if shoot_cooldown <= 0:
			can_shoot = true
		return
	
	# Bomber enemies drop bombs instead of shooting
	if enemy_type == "Bomber":
		_handle_bomber_shooting()
		return
	
	# Standard shooting is now handled entirely by the timer
	pass

func _handle_bomber_shooting():
	"""Handle bomber-specific shooting behavior with bombs"""
	if bombs_dropped >= MAX_BOMBS_PER_ENEMY:
		return
	
	# Use time-based cooldown instead of random chance per frame
	if time_since_spawn - last_bomb_drop_time >= BOMB_DROP_COOLDOWN:
		# 30% chance to drop a bomb when cooldown is ready
		if randf() < 0.3:
			_drop_bomb()
			bombs_dropped += 1
			last_bomb_drop_time = time_since_spawn

func _on_fire_timer_timeout():
	"""Optimized timer-based shooting with weighted pattern selection"""
	if not is_alive or not arrived_at_formation or not is_instance_valid(player_reference):
		return
	
	if not can_shoot:
		return
	
	# Select attack pattern based on weighted probability
	var pattern = _select_weighted_attack_pattern()
	
	# Execute the selected pattern
	_execute_attack_pattern(pattern)
	
	# Apply cooldown with variation for more natural shooting
	_apply_shooting_cooldown()

func _select_weighted_attack_pattern() -> AttackPattern:
	"""Select an attack pattern based on weighted probabilities"""
	var weights = shadow_pattern_weights if _is_shadow_mode_active() else normal_pattern_weights
	
	# Calculate total weight
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	# Random selection based on weights
	var roll = randi() % int(total_weight)
	var cumulative = 0
	
	for pattern in weights.keys():
		cumulative += weights[pattern]
		if roll < cumulative:
			return pattern
	
	return AttackPattern.SINGLE_SHOT  # Fallback

func _execute_attack_pattern(pattern: AttackPattern):
	"""Execute the selected attack pattern"""
	match pattern:
		AttackPattern.SINGLE_SHOT:
			_fire_single_shot()
		AttackPattern.AIMED_SHOT:
			_fire_at_player()
		AttackPattern.SPREAD_SHOT:
			_fire_spread_shot(2, PI/8)  # 2 bullets, 22.5 degree spread
		AttackPattern.BURST_SHOT:
			_fire_burst_shot(2, 0.12)  # 2 bullets, 0.12s delay
		_:
			_fire_at_player()  # Fallback

func _fire_single_shot():
	"""Fire a single bullet straight down - simple and predictable"""
	var bullet_scene = SHADOW_EBULLET if is_shadow_enemy else EBULLET
	var bullet = bullet_scene.instantiate()
	
	if not bullet:
		return
	
	bullet.global_position = global_position
	bullet.rotation = PI/2  # Straight down
	get_tree().current_scene.add_child(bullet)

func _apply_shooting_cooldown():
	"""Apply a variable cooldown between shots for natural shooting rhythm"""
	can_shoot = false
	
	# Base cooldown with difficulty scaling
	var difficulty_modifier = 1.0
	match current_difficulty:
		formation_enums.DifficultyLevel.EASY:
			difficulty_modifier = 1.3  # Slower shooting
		formation_enums.DifficultyLevel.NORMAL:
			difficulty_modifier = 1.0
		formation_enums.DifficultyLevel.HARD:
			difficulty_modifier = 0.85
		formation_enums.DifficultyLevel.NIGHTMARE:
			difficulty_modifier = 0.7  # Faster shooting
	
	# Shadow mode reduces cooldown slightly
	if _is_shadow_mode_active():
		difficulty_modifier *= 0.9
	
	# Calculate cooldown with some randomness for variety
	var cooldown_range = max_shoot_cooldown - min_shoot_cooldown
	shoot_cooldown = (min_shoot_cooldown + randf() * cooldown_range) * difficulty_modifier

func _is_shadow_mode_active() -> bool:
	"""Check if shadow mode is currently active"""
	return is_shadow_mode_active

func _fire_at_player():
	var bullet_scene = SHADOW_EBULLET if is_shadow_enemy else EBULLET
	var bullet = bullet_scene.instantiate()
	
	if not bullet:
		return
	
	# Position bullet at enemy center
	bullet.global_position = global_position
	
	# Calculate direction to player
	var direction = (player_reference.global_position - global_position).normalized()
	bullet.rotation = direction.angle() + PI/2
	
	# Add to scene
	get_tree().current_scene.add_child(bullet)
	
	if debug_mode:
		print("Enemy fired bullet")

# --- Enhanced Shooting Patterns ---

func _fire_spread_shot(bullet_count: int = 2, spread_angle: float = PI/6):  # Reduced defaults
	for i in range(bullet_count):
		var bullet_scene = SHADOW_EBULLET if is_shadow_enemy else EBULLET
		var bullet = bullet_scene.instantiate()
		
		if not bullet:
			continue
		
		# Calculate spread angle
		var angle_offset = spread_angle * (i - (bullet_count-1)/2.0) / (bullet_count-1)
		var direction = Vector2.ZERO
		if is_instance_valid(player_reference):
			direction = (player_reference.global_position - global_position).normalized()
		else:
			direction = Vector2(0, 1)  # Default downward direction
		
		direction = direction.rotated(angle_offset)
		
		bullet.global_position = global_position
		bullet.rotation = direction.angle() + PI/2
		get_tree().current_scene.add_child(bullet)

@warning_ignore("unused_parameter")
func _fire_burst_shot(burst_count: int = 2, burst_delay: float = 0.15):  # Reduced defaults
	for i in range(burst_count):
		var bullet_scene = SHADOW_EBULLET if is_shadow_enemy else EBULLET
		var bullet = bullet_scene.instantiate()
		
		if not bullet:
			continue
		
		# Calculate direction to player with slight variation for each burst
		var direction = Vector2.ZERO
		if is_instance_valid(player_reference):
			direction = (player_reference.global_position - global_position).normalized()
		else:
			direction = Vector2(0, 1)  # Default downward direction
		
		# Add slight angular variation for each burst
		var angle_variation = (i - (burst_count-1)/2.0) * 0.05  # Reduced from 0.1 to 0.05
		direction = direction.rotated(angle_variation)
		
		bullet.global_position = global_position
		bullet.rotation = direction.angle() + PI/2
		get_tree().current_scene.add_child(bullet)

# --- Bomb Dropping Functionality ---

func _drop_bomb():
	# Only bomber enemies should drop bombs
	if enemy_type != "Bomber":
		return
	
	# Check if we've exceeded the global bomb limit
	if BOMB_SCRIPT.active_bombs >= BOMB_SCRIPT.MAX_ACTIVE_BOMBS:
		return
	
	# Create a bomb instance
	var bomb_instance = BOMB.instantiate()
	if bomb_instance:
		# Position the bomb at the enemy's position
		bomb_instance.global_position = global_position
		# Add the bomb to the scene
		get_tree().current_scene.add_child(bomb_instance)

# --- Formation Setup ---
@warning_ignore("unused_parameter")
func setup_formation_entry(config: WaveConfig, index: int, formation_pos: Vector2, delay: float = 0.0):
	wave_config = config
	formation_index = index
	formation_position = formation_pos
	
	if not config:
		return
	
	current_difficulty = config.difficulty
	_apply_difficulty_multipliers(current_difficulty)
	
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	
	if fire_timer:
		fire_timer.wait_time = 1.0 / fire_rate
	
	spawn_position = global_position
	
	if debug_mode:
		print("Enemy formation setup complete")

func set_entry_path(path: Array[Vector2]):
	entry_path = path
	entry_path_index = 0
	
	if debug_mode:
		print("Entry path set with ", path.size(), " waypoints")

func assign_formation_slot(data: Dictionary) -> void:
	# TEMP SHIM - behavior must remain identical
	setup_formation_entry(
		data.wave_config,
		data.formation_index,
		data.formation_position,
		data.start_delay
	)
	set_entry_path(data.entry_path)

func _apply_difficulty_multipliers(difficulty: formation_enums.DifficultyLevel):
	var multipliers = difficulty_multipliers.get(difficulty, difficulty_multipliers[formation_enums.DifficultyLevel.NORMAL])
	
	max_health = int(max_health * multipliers["health"])
	damage_amount = int(damage_amount * multipliers["damage"])
	fire_rate = fire_rate * multipliers["fire_rate"]
	speed = speed * multipliers["speed"]
	vertical_speed = vertical_speed * multipliers["speed"]
	score = int(score * multipliers["score"])
	
	# Apply shadow probability based on difficulty
	shadow_spawn_probability = multipliers["shadow_chance"]

func _initialize_shadow_state():
	if shadow_mode_unlocked:
		if randf() < shadow_spawn_probability:
			_make_shadow_enemy()

func _make_shadow_enemy():
	is_shadow_enemy = true
	max_health = int(max_health * shadow_health_multiplier)
	damage_amount = int(damage_amount * shadow_damage_multiplier)
	score = int(score * shadow_score_multiplier)
	
	# Ensure shadow enemies maintain proper scale
	if sprite and sprite.scale.x < 1.0:
		sprite.scale = Vector2(1.0, 1.0)
	
	_apply_shadow_visuals()
	shadow_state_changed.emit(true)

func _apply_shadow_visuals():
	if not is_shadow_enemy:
		return
	
	# Ensure shadow enemies maintain proper scale
	if sprite and sprite.scale.x < 1.0:
		sprite.scale = Vector2(1.0, 1.0)
	
	if shadow_texture and sprite:
		sprite.texture = shadow_texture
	else:
		# Fallback to modulation
		modulate = Color(0.4, 0.4, 1.0, 0.8)
		_start_shadow_pulse()
	
	if healthbar:
		healthbar.modulate = Color(0.5, 0.5, 1.0, 0.8)

func _start_shadow_pulse():
	if shadow_tween:
		shadow_tween.kill()
	
	shadow_tween = create_tween()
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_max, shadow_alpha_min, shadow_pulse_speed / 2.0)
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_min, shadow_alpha_max, shadow_pulse_speed / 2.0)
	# Connect to tween finished signal to restart the pulse
	shadow_tween.finished.connect(_on_shadow_pulse_finished)

func _on_shadow_pulse_finished():
	# Restart the shadow pulse animation if the enemy is still a shadow enemy
	if is_shadow_enemy and not shadow_texture and is_inside_tree():
		_start_shadow_pulse()

func _set_shadow_alpha(alpha: float):
	if is_shadow_enemy and not shadow_texture:
		modulate.a = alpha

func _on_shadow_mode_activated():
	if debug_mode:
		print("Shadow mode activated for enemy")
	
	# Make all enemies shadow enemies when shadow mode is activated
	# This will make the game more challenging and interesting
	if not is_shadow_enemy:
		_make_shadow_enemy()
	
	# Increase fire rate in shadow mode to make enemies more threatening, but not excessively
	fire_timer.wait_time = (1.0 / fire_rate) * 0.9  # 10% faster firing (more reasonable)
	
	# Increase movement speed in shadow mode
	speed = original_speed * 1.2  # Reduced from 1.3 to 1.2
	vertical_speed = original_vertical_speed * 1.2
	
	# Change movement pattern to more aggressive patterns in shadow mode
	if movement_pattern == MovementPattern.FORMATION_HOLD:
		movement_pattern = MovementPattern.DIVE_BOMB_PATTERN
	elif movement_pattern == MovementPattern.SIDE_TO_SIDE:
		movement_pattern = MovementPattern.DIVE
	elif movement_pattern == MovementPattern.CIRCLE:
		movement_pattern = MovementPattern.SWARM_PATTERN
	
	# DO NOT increase damage in shadow mode - only speed and health should increase
	# damage_amount = int(damage_amount * 1.2)  # Removed this line
	
	# Ensure shadow enemies maintain proper scale
	if sprite and sprite.scale.x < 1.0:
		sprite.scale = Vector2(1.0, 1.0)
	
	# Add visual enhancements for shadow mode
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 1.0, 1.0)  # More intense blue tint

func _on_shadow_mode_deactivated():
	if debug_mode:
		print("Shadow mode deactivated for enemy")
	
	# Reset fire rate when shadow mode is deactivated
	fire_timer.wait_time = 1.0 / fire_rate
	
	# Reset movement speed
	speed = original_speed
	vertical_speed = original_vertical_speed
	
	# DO NOT reset damage since we didn't increase it
	# damage_amount = int(damage_amount / 1.2)  # Removed this line
	
	# Reset visual enhancements
	if sprite and is_shadow_enemy:
		sprite.modulate = Color(0.4, 0.4, 1.0, 0.8)  # Reset to shadow enemy color
		if shadow_tween:
			shadow_tween.kill()
			shadow_tween = null

# --- Damage and Health ---
func damage(amount: int):
	if not is_alive:
		return
	
	# Apply shield reduction if entry shield is active
	if shadow_core_shield and shadow_core_shield.visible:
		amount = int(amount * (1.0 - shield_damage_reduction))
		_show_shield_hit_feedback()
	
	health -= amount
	
	if healthbar:
		healthbar.value = health
	
	if health <= 0:
		die()

func _show_shield_hit_feedback():
	if shadow_core_shield:
		var tween = create_tween()
		tween.tween_property(shadow_core_shield, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.1)
		tween.tween_property(shadow_core_shield, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

# --- Death Logic ---
func die():
	if not is_alive:
		return
	
	is_alive = false
	healthbar.visible = false
	var payload = {
		"enemy_type": enemy_type,
		"is_boss": false,
		"base_score": score,
		"is_shadow_enemy": is_shadow_enemy,
		"shadow_score_multiplier": shadow_score_multiplier,
		"global_position": global_position
	}
	enemy_died.emit(payload)
	
	_disconnect_all_signals()
	_play_death_animation()
	
	died.emit()

func _play_death_animation():
	if enemy_explosion:
		enemy_explosion.visible = true
		enemy_explosion.play("explode")
		enemy_explosion.animation_finished.connect(_on_death_animation_finished)
	
	if explosion_sound:
		explosion_sound.play()
	
	if sprite:
		sprite.visible = false
	
	# Hide the shadow core shield as well
	if shadow_core_shield:
		shadow_core_shield.visible = false
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _on_death_animation_finished():
	queue_free()

# --- Screen Management ---
func _on_visible_on_screen_notifier_2d_screen_entered() -> void:
	# Enemy has entered the screen
	pass

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# Enemy has exited the screen
	if is_in_entry_phase:
		# Don't remove if still in entry phase
		return
	
	queue_free()

# --- Shadow Mode Updates ---
func on_shadow_mode_changed(active: bool) -> void:
	is_shadow_mode_active = active
	if active:
		_on_shadow_mode_activated()
	else:
		_on_shadow_mode_deactivated()

func on_shadow_mode_unlocked_changed(unlocked: bool) -> void:
	shadow_mode_unlocked = unlocked


func _on_area_entered(area: Area2D) -> void:
	# Handle collision with player bullets
	if area.is_in_group("PlayerBullet"):
		var bullet_damage = 1
		if area.has_method("get_damage"):
			bullet_damage = area.get_damage()
		elif area.has("damage"):
			bullet_damage = area.damage
		
		damage(bullet_damage)
		
		# Destroy the bullet
		if area.has_method("queue_free"):
			area.queue_free()
