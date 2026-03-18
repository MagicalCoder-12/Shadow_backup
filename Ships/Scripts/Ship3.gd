extends BaseShip

# Ship3: Astra Blade - Wave-pattern firing mechanism that cuts through space

# Wave-pattern configuration for normal mode
@export var wave_pattern_count: int = 3  # Number of different wave patterns
@export var shots_per_wave: int = 3  # Number of shots per wave pattern
@export var wave_spread_angle: float = 30.0  # Spread angle for wave patterns (degrees)
@export var wave_fire_delay: float = 0.15  # Delay between shots in a wave
@export var pattern_cooldown: float = 0.6  # Cooldown between wave pattern changes

# Shadow mode wave-pattern configuration
@export var shadow_wave_count: int = 4  # Number of diagonal volleys in the shadow X-sequence
@export var shadow_bullets_per_wave: int = 3  # Number of bullets per gun in each shadow volley
@export var shadow_wave_delay: float = 0.14  # Delay between shadow volleys
@export var shadow_wave_spread: float = 10.0  # Tight spread inside each diagonal volley
@export var shadow_diagonal_angle_degrees: float = 42.0
@export var shadow_bullet_speed_multiplier: float = 1.25

# Super mode wave-pattern configuration
@export var super_wave_count: int = 1  # Number of different wave patterns in super mode
@export var super_wave_frequency: float = 0.15  # Reduced frequency for better balance

# Wave pattern types
enum WavePattern {
	LEFT_RIGHT_WAVE,    # Alternating diagonal shots
	CENTER_SPREAD,      # Arc spread from center
	FOCUSED_BEAM,       # Concentrated straight shots
	SHADOW_UP_RIGHT,    # Top-right diagonal volley
	SHADOW_DOWN_RIGHT,  # Bottom-right diagonal volley
	SHADOW_DOWN_LEFT,   # Bottom-left diagonal volley
	SHADOW_UP_LEFT,     # Top-left diagonal volley
	SUPER_ENHANCED      # Enhanced patterns for super mode
}

# Wave-pattern state tracking for normal mode
var current_pattern: WavePattern = WavePattern.LEFT_RIGHT_WAVE
var current_wave_shot: int = 0
var is_wave_firing: bool = false
var wave_timer: Timer
var pattern_cooldown_timer: Timer

# Wave-pattern state tracking for shadow mode
var shadow_current_pattern: WavePattern = WavePattern.SHADOW_UP_RIGHT
var shadow_current_wave: int = 0
var is_shadow_wave_firing: bool = false
var shadow_wave_timer: Timer
var shadow_wave_cooldown_timer: Timer

func _ready():
	# Configure texture scales for Ship3
	base_texture_scale = Vector2(1.5, 1.5)
	evolution_texture_scales = [Vector2(1.0, 1.0), Vector2(1.0, 1.0)]  # upgrade_1, upgrade_2
	default_evolution_scale = Vector2(1.0, 1.0)
	
	super._ready()
	plBullet = preload("res://Bullet/PlBullet/player_bullet_3.tscn")
	plNormalBullet = preload("res://Bullet/PlBullet/player_bullet_3.tscn")  # Store reference to ship's normal bullet
	# Setup wave-pattern timers for normal mode
	wave_timer = Timer.new()
	wave_timer.wait_time = wave_fire_delay
	wave_timer.timeout.connect(_fire_wave_shot)
	add_child(wave_timer)
	
	pattern_cooldown_timer = Timer.new()
	pattern_cooldown_timer.wait_time = pattern_cooldown
	pattern_cooldown_timer.one_shot = true
	pattern_cooldown_timer.timeout.connect(_on_pattern_cooldown_finished)
	add_child(pattern_cooldown_timer)
	
	# Setup timers for shadow mode wave patterns
	shadow_wave_timer = Timer.new()
	shadow_wave_timer.wait_time = shadow_wave_delay
	shadow_wave_timer.timeout.connect(_fire_shadow_wave_shot)
	add_child(shadow_wave_timer)
	
	shadow_wave_cooldown_timer = Timer.new()
	shadow_wave_cooldown_timer.wait_time = 0.5  # Cooldown between shadow wave sequences
	shadow_wave_cooldown_timer.one_shot = true
	shadow_wave_cooldown_timer.timeout.connect(_on_shadow_wave_cooldown_finished)
	add_child(shadow_wave_cooldown_timer)
	
	_apply_ship_specific_stats()

func _apply_ship_specific_stats() -> void:
	"""Apply Ship3-specific stats and configurations"""
	# Ship3 has enhanced wave pattern capabilities
	wave_pattern_count = 3
	shots_per_wave = 3
	wave_spread_angle = 30.0
	wave_fire_delay = 0.15
	pattern_cooldown = 0.6
	
	# Shadow mode configurations - reduced bullet count
	shadow_wave_count = 4
	shadow_bullets_per_wave = 3
	shadow_wave_delay = 0.14
	shadow_wave_spread = 10.0
	shadow_diagonal_angle_degrees = 42.0
	shadow_bullet_speed_multiplier = 1.25
	
	# Super mode configurations - Balanced power
	super_wave_count = 1
	super_wave_frequency = 0.15  # Balanced frequency for fair comparison
	
	# Set initial pattern
	current_pattern = WavePattern.LEFT_RIGHT_WAVE
	shadow_current_pattern = WavePattern.SHADOW_UP_RIGHT
	if wave_timer:
		wave_timer.wait_time = wave_fire_delay
	if pattern_cooldown_timer:
		pattern_cooldown_timer.wait_time = pattern_cooldown
	if shadow_wave_timer:
		shadow_wave_timer.wait_time = shadow_wave_delay
	
	_debug_log("Applied Ship3-specific stats")

# Override shoot() method for wave-pattern attack
func shoot() -> void:
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	
	# Handle different modes with their specific attack patterns
	if is_shadow_mode and not is_super_mode:
		# Shadow mode fires a fixed X-sequence of diagonal volleys.
		_shoot_shadow_mode()
	elif is_super_mode and not is_shadow_mode:
		# Ship3-specific balanced super mode pattern
		_shoot_super_mode()
	else:
		# Normal wave-pattern for regular mode
		_shoot_normal_wave()

func _shoot_normal_wave() -> void:
	# Don't start a new wave if one is already in progress or cooling down
	if is_wave_firing or not pattern_cooldown_timer.is_stopped():
		return
	
	# Start wave-firing sequence
	is_wave_firing = true
	current_wave_shot = 0
	_fire_wave_shot()  # Fire first shot immediately
	
	# Start timer for subsequent shots if shots_per_wave > 1
	if shots_per_wave > 1:
		wave_timer.start()

func _shoot_shadow_mode() -> void:
	if is_shadow_wave_firing or not shadow_wave_cooldown_timer.is_stopped():
		return

	is_shadow_wave_firing = true
	shadow_current_wave = 0
	shadow_current_pattern = WavePattern.SHADOW_UP_RIGHT
	_fire_shadow_wave_shot()
	if is_shadow_wave_firing and shadow_wave_timer:
		shadow_wave_timer.start()

func _fire_wave_shot() -> void:
	if current_wave_shot >= shots_per_wave:
		# Wave complete, cycle to next pattern and start cooldown
		is_wave_firing = false
		wave_timer.stop()
		_cycle_wave_pattern()
		pattern_cooldown_timer.start()
		return
	
	# Get bullet configuration
	var bullet_scene: PackedScene = plBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	# Fire bullets based on current wave pattern
	match current_pattern:
		WavePattern.LEFT_RIGHT_WAVE:
			_fire_left_right_wave(bullet_scene, bullet_speed, bullet_damage)
		WavePattern.CENTER_SPREAD:
			_fire_center_spread(bullet_scene, bullet_speed, bullet_damage)
		WavePattern.FOCUSED_BEAM:
			_fire_focused_beam(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shooting sound
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_wave_shot += 1

func _fire_left_right_wave(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	"""Fire bullets in a left-right wave pattern"""
	# Alternate between left and right firing positions with offset angles
	var positions = firing_positions.get_children()
	if positions.size() == 0:
		return
	
	# Calculate wave offset based on current_wave_shot
	var wave_offset = sin(current_wave_shot * 0.5) * (wave_spread_angle / 2)
	
	for i in range(positions.size()):
		var child = positions[i]
		# Alternate left/right pattern with wave effect
		var angle_offset = 0.0
		if i % 2 == 0:
			# Left side positions get negative offset
			angle_offset = deg_to_rad(-wave_spread_angle/2 - wave_offset)
		else:
			# Right side positions get positive offset
			angle_offset = deg_to_rad(wave_spread_angle/2 + wave_offset)
		
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation + angle_offset,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			SceneSpawnService.spawn_child(bullet)

func _fire_center_spread(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	"""Fire bullets in a center spread pattern"""
	var positions = firing_positions.get_children()
	if positions.size() == 0:
		return
	
	# Create an arc spread from center
	var spread_count = min(5, positions.size() * 2)  # Up to 5 bullets in spread
	var spread_angle = deg_to_rad(wave_spread_angle)
	var angle_step = spread_angle / max(1, spread_count - 1)
	var start_angle = -spread_angle / 2
	
	for i in range(spread_count):
		# Use center position for spread pattern
		var center_pos = global_position
		var angle = start_angle + i * angle_step
		
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			center_pos,
			angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			SceneSpawnService.spawn_child(bullet)

func _fire_focused_beam(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	"""Fire bullets in a focused beam pattern"""
	var positions = firing_positions.get_children()
	if positions.size() == 0:
		return
	
	# Fire concentrated straight shots with minimal spread
	var focus_factor = 0.1  # Reduced spread for focused beam
	
	for child in positions:
		# Very tight spread for focused beam
		var angle_variation = (randf() - 0.5) * focus_factor
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation + angle_variation,
			bullet_speed * 1.2,  # Slightly faster for focused beam
			int(bullet_damage * 1.5)
		)
		if bullet:
			SceneSpawnService.spawn_child(bullet)

func _fire_shadow_wave_shot() -> void:
	if not is_shadow_wave_firing:
		return

	if shadow_current_wave >= shadow_wave_count:
		_reset_shadow_wave_state()
		if shadow_wave_cooldown_timer:
			shadow_wave_cooldown_timer.start()
		return

	shadow_current_pattern = _get_shadow_pattern_for_wave(shadow_current_wave)

	# Fire a diagonal X-volley in the current quadrant.
	var bullet_scene: PackedScene = preload("res://Bullet/PlBullet/plshadow_bullet.tscn")
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * shadow_bullet_speed_multiplier
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage) * 2
	
	_fire_shadow_wave_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shadow mode shooting sound
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")
	
	shadow_current_wave += 1

func _shoot_super_mode() -> void:
	# Ship3-specific balanced super mode with reduced bullet count
	var bullet_scene: PackedScene = preload("res://Bullet/PlBullet/super2.tscn")
	var bullet_speed: float = super_mode_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	# Reduced bullet count for balance - fire 3 bullets in a spread pattern
	var super_bullet_count = 3
	var spread_angle: float = deg_to_rad(30.0)  # 30 degree spread
	var angle_step: float = spread_angle / float(super_bullet_count - 1)
	var start_angle: float = -spread_angle / 2.0
	
	# Use center position for balanced spread
	var center_pos = global_position
	
	for i in range(super_bullet_count):
		var angle: float = start_angle + i * angle_step
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			center_pos,
			angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			SceneSpawnService.spawn_child(bullet)
	
	# Play shooting sound
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")

func _fire_shadow_wave_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	var base_rotation: float = _get_shadow_base_rotation()
	var spread_step: float = deg_to_rad(shadow_wave_spread)
	var start_offset: float = -spread_step * float(max(0, shadow_bullets_per_wave - 1)) * 0.5
	var firing_points = firing_positions.get_children()
	if firing_points.is_empty():
		firing_points = [self]

	for firing_point_variant in firing_points:
		var firing_point: Node2D = firing_point_variant as Node2D
		if not firing_point:
			continue

		for volley_index in range(shadow_bullets_per_wave):
			var spread_offset: float = start_offset + (spread_step * float(volley_index))
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				firing_point.global_position,
				base_rotation + spread_offset,
				bullet_speed,
				bullet_damage
			)
			if bullet:
				SceneSpawnService.spawn_child(bullet)

func _get_shadow_pattern_for_wave(wave_index: int) -> WavePattern:
	var shadow_patterns: Array[int] = [
		WavePattern.SHADOW_UP_RIGHT,
		WavePattern.SHADOW_DOWN_RIGHT,
		WavePattern.SHADOW_DOWN_LEFT,
		WavePattern.SHADOW_UP_LEFT
	]
	return shadow_patterns[wave_index % shadow_patterns.size()]

func _get_shadow_base_rotation() -> float:
	var diagonal_angle: float = deg_to_rad(shadow_diagonal_angle_degrees)
	match shadow_current_pattern:
		WavePattern.SHADOW_UP_RIGHT:
			return diagonal_angle
		WavePattern.SHADOW_DOWN_RIGHT:
			return PI - diagonal_angle
		WavePattern.SHADOW_DOWN_LEFT:
			return -PI + diagonal_angle
		WavePattern.SHADOW_UP_LEFT:
			return -diagonal_angle
		_:
			return 0.0

func _cycle_wave_pattern() -> void:
	# Cycle through normal wave patterns
	current_pattern = (current_pattern + 1) % 3 as WavePattern  # Only cycle through first 3 patterns
	_debug_log("Ship3 cycled to pattern: %s" % WavePattern.keys()[current_pattern])

func _cycle_shadow_wave_pattern() -> void:
	# Cycle through the X-volley quadrants.
	var shadow_patterns: Array[int] = [
		WavePattern.SHADOW_UP_RIGHT,
		WavePattern.SHADOW_DOWN_RIGHT,
		WavePattern.SHADOW_DOWN_LEFT,
		WavePattern.SHADOW_UP_LEFT
	]
	var current_index: int = shadow_patterns.find(shadow_current_pattern)
	shadow_current_pattern = shadow_patterns[(current_index + 1) % shadow_patterns.size()]
	_debug_log("Ship3 cycled to shadow pattern: %s" % WavePattern.keys()[shadow_current_pattern])

func _cycle_super_wave_pattern() -> void:
	# This function is no longer needed as we're using the default super pattern
	pass

func _on_pattern_cooldown_finished() -> void:
	# Pattern cooldown completed, ready for next wave
	pass

func _on_shadow_wave_cooldown_finished() -> void:
	# Shadow wave cooldown completed, ready for next sequence
	pass

func apply_shadow_mode_effects() -> void:
	# Call base implementation
	super.apply_shadow_mode_effects()
	
	# Apply Ship3-specific shadow mode visual effects
	if sprite_2d:
		sprite_2d.modulate = Color(0.3, 1.0, 0.3)  # Green tint for Ship3 shadow mode
		# Could add particle effects or other visual enhancements here

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	# Call base implementation
	super.apply_super_mode_effects(multiplier_div, duration)
	
	# Apply Ship3-specific super mode visual effects with balanced intensity
	if sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.8, 0.0)  # Balanced golden tint for fair power
		# Could add particle effects or other visual enhancements here

func revert_shadow_mode_effects() -> void:
	super.revert_shadow_mode_effects()
	_reset_shadow_wave_state()
	if GameManager.player_manager.player_stats.get("is_super_mode_active", false) and sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.8, 0.0)

func _on_super_mode_timeout() -> void:
	super._on_super_mode_timeout()
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false) and sprite_2d:
		sprite_2d.modulate = Color(0.3, 1.0, 0.3)

func _reset_shadow_wave_state() -> void:
	is_shadow_wave_firing = false
	shadow_current_wave = 0
	shadow_current_pattern = WavePattern.SHADOW_UP_RIGHT
	if shadow_wave_timer:
		shadow_wave_timer.stop()
	if shadow_wave_cooldown_timer:
		shadow_wave_cooldown_timer.stop()
