extends BaseShip

# Ship3: Astra Blade - Wave-pattern firing mechanism that cuts through space

# Wave-pattern configuration for normal mode
@export var wave_pattern_count: int = 3  # Number of different wave patterns
@export var shots_per_wave: int = 3  # Number of shots per wave pattern
@export var wave_spread_angle: float = 30.0  # Spread angle for wave patterns (degrees)
@export var wave_fire_delay: float = 0.15  # Delay between shots in a wave
@export var pattern_cooldown: float = 0.6  # Cooldown between wave pattern changes

# Shadow mode wave-pattern configuration
@export var shadow_wave_count: int = 3  # Number of different wave patterns in shadow mode
@export var shadow_bullets_per_wave: int = 3  # Number of bullets per wave in shadow mode
@export var shadow_wave_delay: float = 0.2  # Delay between waves in shadow mode
@export var shadow_wave_spread: float = 45  # Spread angle for shadow mode wave patterns (degrees)

# Super mode wave-pattern configuration
@export var super_wave_count: int = 1  # Number of different wave patterns in super mode
@export var super_wave_frequency: float = 0.1  # Increased wave frequency in super mode

# Wave pattern types
enum WavePattern {
	LEFT_RIGHT_WAVE,    # Alternating diagonal shots
	CENTER_SPREAD,      # Arc spread from center
	FOCUSED_BEAM,       # Concentrated straight shots
	SHADOW_HORIZONTAL,  # Horizontal wave (left to right)
	SHADOW_VERTICAL,    # Vertical wave (top to bottom)
	SHADOW_DIAGONAL,    # Diagonal wave (corners)
	SUPER_ENHANCED      # Enhanced patterns for super mode
}

# Wave-pattern state tracking for normal mode
var current_pattern: WavePattern = WavePattern.LEFT_RIGHT_WAVE
var current_wave_shot: int = 0
var is_wave_firing: bool = false
var wave_timer: Timer
var pattern_cooldown_timer: Timer

# Wave-pattern state tracking for shadow mode
var shadow_current_pattern: WavePattern = WavePattern.SHADOW_HORIZONTAL
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
	shadow_wave_count = 3
	shadow_bullets_per_wave = 1  # Reduced from 9 to 5
	shadow_wave_delay = 0.3  # Increased from 0.2 to 0.3 for slower firing
	shadow_wave_spread = 45.0
	
	# Super mode configurations
	super_wave_count = 3
	super_wave_frequency = 0.1
	
	# Set initial pattern
	current_pattern = WavePattern.LEFT_RIGHT_WAVE
	shadow_current_pattern = WavePattern.SHADOW_HORIZONTAL
	
	_debug_log("Applied Ship3-specific stats")

# Override shoot() method for wave-pattern attack
func shoot() -> void:
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	
	# Handle different modes with their specific attack patterns
	if is_shadow_mode and not is_super_mode:
		# Simplified shadow mode - same as Ship1
		_shoot_shadow_mode()
	elif is_super_mode and not is_shadow_mode:
		# Use default super mode pattern instead of Ship3-specific wave pattern
		_shoot_normal_bullets(plSuperBullet, super_mode_bullet_speed, GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage))
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
	# Simplified shadow mode - fire bullets like Ship1, not using wave patterns
	var bullet_scene: PackedScene = preload("res://Bullet/PlBullet/plshadow_bullet.tscn")
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * 1.2  # shadow_speed_multiplier
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage) * 2
	
	# Fire bullets in circular pattern like Ship1 (reduced count)
	var bullet_count = 8  # Reduced from Ship1's 25 to a more manageable amount
	var angle_step: float = 360.0 / float(bullet_count)
	for i in range(bullet_count):
		var angle: float = deg_to_rad(i * angle_step)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * 5.0  # spawn_point_offset
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			global_position + offset,
			angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)
	
	# Play shooting sound
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")

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
			get_tree().current_scene.call_deferred("add_child", bullet)

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
			get_tree().current_scene.call_deferred("add_child", bullet)

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
			bullet_damage * 1.5  # Increased damage for focused beam
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _fire_shadow_wave_shot() -> void:
	if current_wave_shot >= shadow_bullets_per_wave:
		# Wave complete, cycle to next pattern
		shadow_wave_timer.stop()
		
		if shadow_current_wave >= shadow_wave_count:
			# All waves complete, start cooldown
			is_shadow_wave_firing = false
			shadow_wave_cooldown_timer.start()
			return
		else:
			# Cycle to next shadow pattern
			_cycle_shadow_wave_pattern()
			current_wave_shot = 0
			shadow_wave_timer.start()
			return
	
	# Fire shadow bullets with wave pattern
	var bullet_scene: PackedScene = preload("res://Bullet/PlBullet/plshadow_bullet.tscn")  # Distinct shadow bullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * shadow_speed_multiplier
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage) * 2
	
	_fire_shadow_wave_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shadow mode shooting sound
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_wave_shot += 1

func _fire_super_wave_shot() -> void:
	# This function is no longer needed as we're using the default super pattern
	pass

func _fire_shadow_wave_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Fire bullets based on current shadow wave pattern
	match shadow_current_pattern:
		WavePattern.SHADOW_HORIZONTAL:
			_fire_shadow_horizontal_wave(bullet_scene, bullet_speed, bullet_damage)
		WavePattern.SHADOW_VERTICAL:
			_fire_shadow_vertical_wave(bullet_scene, bullet_speed, bullet_damage)
		WavePattern.SHADOW_DIAGONAL:
			_fire_shadow_diagonal_wave(bullet_scene, bullet_speed, bullet_damage)



func _fire_shadow_horizontal_wave(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Horizontal wave (left to right)
	var positions = [-0.8, -0.4, 0.0, 0.4, 0.8]
	var y_offset = positions[current_wave_shot % positions.size()] * 100
	
	for child in firing_positions.get_children():
		var offset: Vector2 = Vector2(0, y_offset)
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position + offset,
			child.rotation,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _fire_shadow_vertical_wave(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Vertical wave (top to bottom)
	var positions = [-0.8, -0.4, 0.0, 0.4, 0.8]
	var x_offset = positions[current_wave_shot % positions.size()] * 100
	
	for child in firing_positions.get_children():
		var offset: Vector2 = Vector2(x_offset, 0)
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position + offset,
			child.rotation + PI/2,  # Vertical angle
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _fire_shadow_diagonal_wave(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Diagonal wave (corners)
	var angles = [PI/4, 3*PI/4, 5*PI/4, 7*PI/4]
	var angle = angles[current_wave_shot % angles.size()]
	
	for child in firing_positions.get_children():
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _cycle_wave_pattern() -> void:
	# Cycle through normal wave patterns
	current_pattern = (current_pattern + 1) % 3 as WavePattern  # Only cycle through first 3 patterns
	_debug_log("Ship3 cycled to pattern: %s" % WavePattern.keys()[current_pattern])

func _cycle_shadow_wave_pattern() -> void:
	# Cycle through shadow wave patterns
	var shadow_patterns = [WavePattern.SHADOW_HORIZONTAL, WavePattern.SHADOW_VERTICAL, WavePattern.SHADOW_DIAGONAL]
	var current_index = shadow_patterns.find(shadow_current_pattern)
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
	
	# Apply Ship3-specific super mode visual effects
	if sprite_2d:
		sprite_2d.modulate = Color(1.8, 1.5, 0.3)  # Golden tint for Ship3 super mode
		# Could add particle effects or other visual enhancements here
