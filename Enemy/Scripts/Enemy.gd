extends Area2D
class_name Enemy

# --- Preloaded Resources ---
const EBULLET = preload("res://Bullet/Enemy_Bullet.tscn")
const SHADOW_EBULLET = preload("res://Bullet/shadow_enemy_bullet.tscn")
const BOMB = preload("res://Bullet/Bomb.tscn")
const COINS = preload("res://Resources/Coins.tscn")
const CRYSTAL = preload("res://Resources/Crystal.tscn")

# --- Signals ---
signal died
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
@export var shadow_damage_multiplier: float = 1.5
@export var fire_rate: float = 2.0
@export var entry_speed_multiplier: float = 1.0
@export var entry_shadow_shield_time: float = 2.0
@export var shadow_texture: Texture2D
@export var enemy_type: String = "standard"

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
		"health": 1.0, "damage": 1.0, "fire_rate": 1.0, "speed": 1.0, "score": 1.0, "shadow_chance": 0.3
	},
	formation_enums.DifficultyLevel.HARD: {
		"health": 1.5, "damage": 1.3, "fire_rate": 1.3, "speed": 1.2, "score": 1.5, "shadow_chance": 0.5
	},
	formation_enums.DifficultyLevel.NIGHTMARE: {
		"health": 2.0, "damage": 1.5, "fire_rate": 1.5, "speed": 1.5, "score": 2.0, "shadow_chance": 0.7
	}
}

# --- Movement Behavior ---
enum MovementPattern { FORMATION_HOLD, SIDE_TO_SIDE, CIRCLE, DIVE }
@export var movement_pattern: MovementPattern = MovementPattern.FORMATION_HOLD

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
var shield_damage_reduction: float = 0.5

# --- Initialization ---
func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	original_speed = speed
	original_vertical_speed = vertical_speed
	original_modulate = modulate
	if sprite:
		original_texture = sprite.texture
	
	tree_exiting.connect(_on_tree_exiting)
	
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	
	_setup_fire_timer()
	_connect_signals()
	_update_player_reference()
	_initialize_shadow_state()
	
	if shadow_core_shield:
		shadow_core_shield.visible = true
		shadow_core_shield.play("default")
	
	if debug_mode:
		print("Enemy spawned: ", enemy_type)

func _on_tree_exiting():
	if debug_mode:
		print("Enemy: Tree exiting - cleaning up")
	_disconnect_all_signals()

func _setup_fire_timer():
	if fire_timer:
		fire_timer.wait_time = 1.0 / fire_rate
		fire_timer.timeout.connect(_on_fire_timer_timeout)
		fire_timer.start()

func _connect_signals():
	if visible_on_screen_notifier_2d:
		visible_on_screen_notifier_2d.screen_exited.connect(_on_screen_exited)

func _disconnect_all_signals():
	if GameManager and GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.disconnect(_on_shadow_mode_activated)
	if GameManager and GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.disconnect(_on_shadow_mode_deactivated)

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
	match movement_pattern:
		MovementPattern.FORMATION_HOLD:
			# Stay at formation position
			global_position = global_position.lerp(formation_position, 2.0 * delta)
			
		MovementPattern.SIDE_TO_SIDE:
			# Move side to side around formation position
			var side_offset = sin(time_since_spawn * 2.0) * 50.0
			var target_pos = formation_position + Vector2(side_offset, 0)
			global_position = global_position.lerp(target_pos, 3.0 * delta)
			
		MovementPattern.CIRCLE:
			# Circle around formation position
			circle_angle += delta * 2.0
			var circle_offset = Vector2(cos(circle_angle), sin(circle_angle)) * circle_radius
			global_position = formation_position + circle_offset
			
		MovementPattern.DIVE:
			# Occasional dive towards player
			if is_instance_valid(player_reference) and randf() < 0.001:
				var dive_direction = (player_reference.global_position - global_position).normalized()
				global_position += dive_direction * speed * 2.0 * delta
			else:
				# Return to formation
				global_position = global_position.lerp(formation_position, 2.0 * delta)

func _handle_shooting(_delta: float):
	if not arrived_at_formation or not is_instance_valid(player_reference):
		return
	
	# Fire timer handles the shooting interval
	pass

func _on_fire_timer_timeout():
	if not is_alive or not arrived_at_formation or not is_instance_valid(player_reference):
		return
	
	_fire_at_player()

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
	if GameManager and GameManager.level_manager and GameManager.level_manager.shadow_mode_unlocked:
		if randf() < shadow_spawn_probability:
			_make_shadow_enemy()

func _make_shadow_enemy():
	is_shadow_enemy = true
	max_health = int(max_health * shadow_health_multiplier)
	damage_amount = int(damage_amount * shadow_damage_multiplier)
	score = int(score * shadow_score_multiplier)
	_apply_shadow_visuals()
	shadow_state_changed.emit(true)

func _apply_shadow_visuals():
	if not is_shadow_enemy:
		return
	
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
	shadow_tween.set_loops()
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_max, shadow_alpha_min, shadow_pulse_speed / 2.0)
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_min, shadow_alpha_max, shadow_pulse_speed / 2.0)

func _set_shadow_alpha(alpha: float):
	if is_shadow_enemy and not shadow_texture:
		modulate.a = alpha

func _on_shadow_mode_activated():
	if debug_mode:
		print("Shadow mode activated for enemy")
	
	if not is_shadow_enemy and randf() < shadow_spawn_probability:
		_make_shadow_enemy()

func _on_shadow_mode_deactivated():
	if debug_mode:
		print("Shadow mode deactivated for enemy")

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
	
	var final_score = score
	if is_shadow_enemy:
		final_score = int(score * shadow_score_multiplier)
	
	GameManager.score += final_score
	_drop_resources()
	_disconnect_all_signals()
	_play_death_animation()
	
	# Notify GameManager for shadow mode charging
	GameManager.notify_enemy_killed(self)
	
	died.emit()

func _drop_resources():
	# Drop coins - reduced from 1-3 to 1-2 coins
	var coin_count = randi_range(1, 2)
	for i in range(coin_count):
		var coin = COINS.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.call_deferred("add_child", coin)
	
	# Drop crystal occasionally
	if randf() < 0.15: # 15% chance (changed from 30%)
		var crystal = CRYSTAL.instantiate()
		crystal.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", crystal)

func _play_death_animation():
	if enemy_explosion:
		enemy_explosion.visible = true
		enemy_explosion.play("explode")
		enemy_explosion.animation_finished.connect(_on_death_animation_finished)
	
	if explosion_sound:
		explosion_sound.play()
	
	if sprite:
		sprite.visible = false
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _on_death_animation_finished():
	queue_free()

# --- Screen Management ---
func _on_screen_exited():
	if is_in_entry_phase:
		# Don't remove if still in entry phase
		return
	
	queue_free()

# --- Signal Connections ---
func _connect_shadow_signals():
	if GameManager:
		if not GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
			GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
		if not GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
			GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
