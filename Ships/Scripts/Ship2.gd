extends BaseShip

# Ship2: Aether Strike - Tailored implementation with burst-fire attack pattern
const SHADOW_BULLET_TINT: Color = Color(0.72, 0.45, 1.0, 1.0)

# Burst-fire configuration for normal mode
@export var burst_count: int = 3  # Number of bullets per burst
@export var burst_delay: float = 0.1  # Delay between bullets in burst
@export var burst_cooldown: float = 0.8  # Cooldown after burst completion

# Shadow mode burst-fire configuration
@export var shadow_burst_count: int = 4  # Number of sweep volleys per shadow sequence
@export var shadow_burst_delay: float = 0.08  # Delay between shadow sweep volleys
@export var shadow_burst_sequence_count: int = 3  # Number of chained sweep sequences in shadow mode
@export var shadow_burst_sequence_delay: float = 0.18  # Delay between shadow sweep sequences
@export var shadow_sweep_angle_degrees: float = 54.0
@export var shadow_inner_spread_degrees: float = 8.0
@export var shadow_outer_spread_degrees: float = 18.0
@export var shadow_bullet_speed_multiplier: float = 1.15

# Super mode burst-fire configuration
@export var super_burst_count: int = 4  # Number of bullets per burst in super mode
@export var super_burst_spread: float = 45  # Spread angle for super mode bursts (degrees)

# Burst-fire state tracking
var current_burst_shot: int = 0
var is_bursting: bool = false
var burst_timer: Timer
var burst_cooldown_timer: Timer

# Shadow mode burst sequence tracking
var current_burst_sequence: int = 0
var is_shadow_bursting: bool = false
var shadow_burst_timer: Timer
var shadow_sequence_timer: Timer

# Super mode burst state tracking
var is_super_bursting: bool = false
var super_burst_timer: Timer

func _ready() -> void:
	# Configure texture scales for Ship2
	base_texture_scale = Vector2(1.5, 1.5)
	evolution_texture_scales = [Vector2(1.3, 1.3), Vector2(1.5, 1.5)]  # upgrade_1, upgrade_2
	default_evolution_scale = Vector2(1.0, 1.0)

	super._ready()  # Call BaseShip's _ready for evolution scaling
	plBullet = preload("res://Bullet/PlBullet/player_bullet_2.tscn")  # Default bullet for normal mode
	plNormalBullet = preload("res://Bullet/PlBullet/player_bullet_2.tscn")  # Store reference to ship's normal bullet
	
	# Setup burst-fire timers for normal mode
	burst_timer = Timer.new()
	burst_timer.wait_time = burst_delay
	burst_timer.timeout.connect(_fire_burst_shot)
	add_child(burst_timer)
	
	burst_cooldown_timer = Timer.new()
	burst_cooldown_timer.wait_time = burst_cooldown
	burst_cooldown_timer.one_shot = true
	burst_cooldown_timer.timeout.connect(_on_burst_cooldown_finished)
	add_child(burst_cooldown_timer)
	
	# Setup timers for shadow mode burst sequences
	shadow_burst_timer = Timer.new()
	shadow_burst_timer.wait_time = shadow_burst_delay
	shadow_burst_timer.timeout.connect(_fire_shadow_burst_shot)
	add_child(shadow_burst_timer)
	
	shadow_sequence_timer = Timer.new()
	shadow_sequence_timer.wait_time = shadow_burst_sequence_delay
	shadow_sequence_timer.one_shot = true
	shadow_sequence_timer.timeout.connect(_start_next_shadow_burst_sequence)
	add_child(shadow_sequence_timer)
	
	# Setup timer for super mode bursts
	super_burst_timer = Timer.new()
	super_burst_timer.wait_time = burst_delay
	super_burst_timer.timeout.connect(_fire_super_burst_shot)
	add_child(super_burst_timer)
	
	_apply_ship_specific_stats()

# Override shoot() method for burst-fire attack pattern
func shoot() -> void:
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	
	# Handle different modes with their specific attack patterns
	if is_super_mode and not is_shadow_mode:
		# Super mode active: use super bullets with super pattern
		_shoot_super_mode()
	elif is_shadow_mode and not is_super_mode:
		# Shadow mode active: use shadow bullets with shadow pattern
		_shoot_shadow_mode()
	else:
		# Normal burst-fire for regular mode
		_shoot_normal_burst()

func _shoot_normal_burst() -> void:
	# Don't start a new burst if one is already in progress or cooling down
	if is_bursting or not burst_cooldown_timer.is_stopped():
		return
	
	# Start burst-fire sequence
	is_bursting = true
	current_burst_shot = 0
	_fire_burst_shot()  # Fire first shot immediately
	
	# Start timer for subsequent shots if burst_count > 1
	if burst_count > 1:
		burst_timer.start()

func _shoot_shadow_mode() -> void:
	# Don't start a new burst sequence if one is already in progress
	if is_shadow_bursting or not shadow_sequence_timer.is_stopped():
		return
	
	# Start shadow burst sequence (using shadow bullets with shadow pattern)
	is_shadow_bursting = true
	current_burst_sequence = 0
	current_burst_shot = 0
	_fire_shadow_burst_shot()  # Fire first shot immediately
	
	# Start timer for subsequent shots if shadow_burst_count > 1
	if shadow_burst_count > 1:
		shadow_burst_timer.start()

func _shoot_super_mode() -> void:
	# Don't start a new super burst if one is already in progress
	if is_super_bursting:
		return
	
	# Start super burst-fire sequence (using super bullets with super pattern)
	is_super_bursting = true
	current_burst_shot = 0
	_fire_super_burst_shot()  # Fire first shot immediately
	
	# Start timer for subsequent shots if super_burst_count > 1
	if super_burst_count > 1:
		super_burst_timer.start()

func _fire_burst_shot() -> void:
	if current_burst_shot >= burst_count:
		# Burst complete, start cooldown
		is_bursting = false
		burst_timer.stop()
		burst_cooldown_timer.start()
		return
	
	# Fire a single bullet using parent's shooting logic
	var bullet_scene: PackedScene = plBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	_shoot_normal_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Assets/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_burst_shot += 1

func _fire_shadow_burst_shot() -> void:
	if current_burst_shot >= shadow_burst_count:
		# Burst complete, check if we need more sequences
		shadow_burst_timer.stop()
		current_burst_sequence += 1
		
		if current_burst_sequence >= shadow_burst_sequence_count:
			# All sequences complete, start cooldown
			is_shadow_bursting = false
			shadow_sequence_timer.start()
		else:
			# Start next sequence after delay
			shadow_sequence_timer.start()
		return
	
	# Fire Ship2's own bullet in a forward sweeping lance pattern.
	var bullet_scene: PackedScene = plNormalBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * shadow_bullet_speed_multiplier
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	# Use Ship2-specific shadow sweep pattern.
	_shoot_shadow_burst_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shadow mode shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Assets/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_burst_shot += 1

func _fire_super_burst_shot() -> void:
	if current_burst_shot >= super_burst_count:
		# Super burst complete
		is_super_bursting = false
		if super_burst_timer:
			super_burst_timer.stop()
		return
	
	# Fire super bullets with spread pattern
	var bullet_scene: PackedScene = preload("res://Bullet/PlBullet/super2.tscn")
	var bullet_speed: float = super_mode_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	# Use super burst bullets pattern
	_shoot_super_burst_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play super mode shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Assets/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_burst_shot += 1

func _shoot_shadow_burst_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	var firing_points: Array[Node2D] = []
	for child in firing_positions.get_children():
		if child is Node2D:
			firing_points.append(child as Node2D)
	if firing_points.is_empty():
		firing_points.append(self)

	var sweep_half_angle: float = deg_to_rad(shadow_sweep_angle_degrees * 0.5)
	var shot_ratio: float = 0.0
	if shadow_burst_count > 1:
		shot_ratio = float(current_burst_shot) / float(shadow_burst_count - 1)

	var sequence_bias: float = float(current_burst_sequence - 1) * deg_to_rad(6.0)
	var sweep_center: float = lerpf(-sweep_half_angle, sweep_half_angle, shot_ratio)
	var sweep_direction: float = 1.0 if (current_burst_sequence % 2) == 0 else -1.0
	var base_rotation: float = sweep_center * sweep_direction
	var spread_angles: Array[float] = [
		-deg_to_rad(shadow_inner_spread_degrees),
		0.0,
		deg_to_rad(shadow_inner_spread_degrees)
	]

	for firing_point in firing_points:
		for spread_angle in spread_angles:
			var final_rotation: float = firing_point.rotation + base_rotation + sequence_bias + spread_angle
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				firing_point.global_position,
				final_rotation,
				bullet_speed,
				bullet_damage
			)
			if bullet:
				SceneSpawnService.spawn_child(bullet)
				if bullet.has_method("apply_shadow_tint"):
					bullet.call("apply_shadow_tint", SHADOW_BULLET_TINT)
				elif bullet is CanvasItem:
					(bullet as CanvasItem).modulate = SHADOW_BULLET_TINT

func _shoot_super_burst_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Fire bullets with spread pattern for super mode
	var spread_angle: float = deg_to_rad(super_burst_spread)
	var angle_step: float = spread_angle / float(super_burst_count - 1)
	var start_angle: float = -spread_angle / 2.0
	
	# Only use the first firing position to reduce bullet intensity
	var firing_point = firing_positions.get_child(0) if firing_positions.get_child_count() > 0 else self
	
	for i in range(super_burst_count):
		var angle: float = start_angle + i * angle_step
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			firing_point.global_position,
			firing_point.rotation + angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			SceneSpawnService.spawn_child(bullet)

func _start_next_shadow_burst_sequence() -> void:
	# Reset for next burst sequence
	current_burst_shot = 0
	_fire_shadow_burst_shot()  # Fire first shot immediately
	
	# Start timer for subsequent shots if shadow_burst_count > 1
	if shadow_burst_count > 1:
		shadow_burst_timer.start()

func _on_burst_cooldown_finished() -> void:
	# Burst cooldown completed, ready for next burst
	pass

func apply_shadow_mode_effects() -> void:
	# Call base implementation
	super.apply_shadow_mode_effects()
	
	# Apply Ship2-specific shadow mode visual effects
	if sprite_2d:
		sprite_2d.modulate = Color(0.7, 0.3, 1.0)  # Purple tint for Ship2 shadow mode
		# Could add particle effects or other visual enhancements here

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	# Call base implementation
	super.apply_super_mode_effects(multiplier_div, duration)
	
	# Apply Ship2-specific super mode visual effects
	if sprite_2d:
		sprite_2d.modulate = Color(1, 0.706, 0.385)  # Gold tint for Ship2 super mode
		# Could add particle effects or other visual enhancements here
	_setup_super_mode_bullets()
	_debug_log("Ship2 super mode activated with PlayerBullet2, damage boosted to %d" % GameManager.player_manager.player_stats["bullet_damage"])

func _setup_super_mode_bullets() -> void:
	# Switch to PlayerBullet2 for super mode with enhanced arch effect
	plBullet = preload("res://Bullet/PlBullet/super2.tscn")  # Ensure PlayerBullet2 is used
	fire_delay_timer.wait_time = super_mode_fire_delay  # From Player.gd export
	_debug_log("Ship2 super mode bullets set to PlayerBullet2 with delay %.2f" % fire_delay_timer.wait_time)

func _apply_ship_specific_stats() -> void:
	"""Apply Ship2-specific stats and configurations"""
	# Ship2 has burst-fire capabilities
	burst_count = 2
	burst_delay = 0.1
	burst_cooldown = 0.8
	
	# Shadow mode configurations: Ship2 uses chained sweeping lances instead of radial spam.
	shadow_burst_count = 4
	shadow_burst_delay = 0.08
	shadow_burst_sequence_count = 3
	shadow_burst_sequence_delay = 0.18
	shadow_sweep_angle_degrees = 54.0
	shadow_inner_spread_degrees = 8.0
	shadow_outer_spread_degrees = 18.0
	shadow_bullet_speed_multiplier = 1.15
	
	# Super mode configurations - reduced bullet intensity
	super_burst_count = 3  # Reduced from 5 to 3
	super_burst_spread = 45  # Reduced from 45 to 30 degrees for tighter spread
	
	_debug_log("Applied Ship2-specific stats")

func _on_super_mode_timeout() -> void:
	# Call parent implementation
	super._on_super_mode_timeout()
	
	# Ship2-specific cleanup
	is_super_bursting = false
	if super_burst_timer:
		super_burst_timer.stop()
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false) and sprite_2d:
		sprite_2d.modulate = Color(0.7, 0.3, 1.0)

func revert_shadow_mode_effects() -> void:
	# Call parent implementation
	super.revert_shadow_mode_effects()
	
	# Ship2-specific shadow mode cleanup
	is_shadow_bursting = false
	current_burst_sequence = 0
	current_burst_shot = 0
	if shadow_burst_timer:
		shadow_burst_timer.stop()
	if shadow_sequence_timer:
		shadow_sequence_timer.stop()
