extends BaseShip

# Ship3: Astra Blade - Wave-pattern firing mechanism that cuts through space

# Wave-pattern configuration
@export var wave_pattern_count: int = 3  # Number of different wave patterns
@export var shots_per_wave: int = 3  # Number of shots per wave pattern
@export var wave_spread_angle: float = 30.0  # Spread angle for wave patterns (degrees)
@export var wave_fire_delay: float = 0.15  # Delay between shots in a wave
@export var pattern_cooldown: float = 0.6  # Cooldown between wave pattern changes

# Wave pattern types
enum WavePattern {
	LEFT_RIGHT_WAVE,    # Alternating diagonal shots
	CENTER_SPREAD,      # Arc spread from center
	FOCUSED_BEAM        # Concentrated straight shots
}

# Wave-pattern state tracking
var current_pattern: WavePattern = WavePattern.LEFT_RIGHT_WAVE
var current_wave_shot: int = 0
var is_wave_firing: bool = false
var wave_timer: Timer
var pattern_cooldown_timer: Timer

func _ready():
	# Configure texture scales for Ship3
	base_texture_scale = Vector2(1.5, 1.5)
	evolution_texture_scales = [Vector2(1.0, 1.0), Vector2(1.0, 1.0)]  # upgrade_1, upgrade_2
	default_evolution_scale = Vector2(1.0, 1.0)
	
	super._ready()
	plBullet = preload("res://Bullet/player_bullet_3.tscn") 
	# Setup wave-pattern timers
	wave_timer = Timer.new()
	wave_timer.wait_time = wave_fire_delay
	wave_timer.timeout.connect(_fire_wave_shot)
	add_child(wave_timer)
	
	pattern_cooldown_timer = Timer.new()
	pattern_cooldown_timer.wait_time = pattern_cooldown
	pattern_cooldown_timer.one_shot = true
	pattern_cooldown_timer.timeout.connect(_on_pattern_cooldown_finished)
	add_child(pattern_cooldown_timer)
	
	_apply_ship_specific_stats()

func _apply_ship_specific_stats() -> void:
	# Don't override damage if it was already set by the upgrade system
	if base_bullet_damage == 20:  # Default damage from Player.gd
		# Get the actual damage from the ship data
		var ship_data = null
		for ship in GameManager.ships:
			if ship.get("id", "") == ship_id:
				ship_data = ship
				break
		
		if ship_data:
			base_bullet_damage = ship_data.get("damage", 30)
		else:
			base_bullet_damage = 30  # Fallback for Ship3
	
	_debug_log("Applied Ship3 specific stats: damage=%d, speed=%.1f" % [base_bullet_damage, speed])

# Override shoot() method for wave-pattern attack
func shoot() -> void:
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

func _fire_wave_shot() -> void:
	if current_wave_shot >= shots_per_wave:
		# Wave complete, cycle to next pattern and start cooldown
		is_wave_firing = false
		wave_timer.stop()
		_cycle_wave_pattern()
		pattern_cooldown_timer.start()
		return
	
	# Get bullet configuration
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	var bullet_scene: PackedScene = plSuperBullet if is_super_mode or is_shadow_mode else plBullet
	var bullet_speed: float = super_mode_bullet_speed if is_super_mode else GameManager.player_manager.default_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	# Use shadow mode shooting if in shadow mode and not in super mode
	if is_shadow_mode and not is_super_mode:
		_shoot_shadow_bullets(bullet_scene, bullet_speed, bullet_damage)
	else:
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
	# Alternating diagonal shots (left, right, center)
	var angle_offset: float = 0.0
	if current_wave_shot == 0:
		angle_offset = -wave_spread_angle  # Left
	elif current_wave_shot == 1:
		angle_offset = wave_spread_angle   # Right
	else:
		angle_offset = 0.0  # Center
	
	for child in firing_positions.get_children():
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation + deg_to_rad(angle_offset),
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _fire_center_spread(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Arc spread from center - each shot spreads wider
	var spread_multiplier: float = (current_wave_shot + 1) * 0.5
	var angles: Array[float] = [-wave_spread_angle * spread_multiplier, 0.0, wave_spread_angle * spread_multiplier]
	
	for angle in angles:
		for child in firing_positions.get_children():
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				child.global_position,
				child.rotation + deg_to_rad(angle),
				bullet_speed,
				bullet_damage
			)
			if bullet:
				get_tree().current_scene.call_deferred("add_child", bullet)

func _fire_focused_beam(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	# Concentrated straight shots - multiple bullets per firing position
	var bullets_per_position: int = current_wave_shot + 1
	
	for child in firing_positions.get_children():
		for i in range(bullets_per_position):
			var offset: Vector2 = Vector2(randf_range(-5, 5), 0)  # Small random offset
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				child.global_position + offset,
				child.rotation,
				bullet_speed,
				bullet_damage
			)
			if bullet:
				get_tree().current_scene.call_deferred("add_child", bullet)

func _cycle_wave_pattern() -> void:
	# Cycle through wave patterns
	current_pattern = (current_pattern + 1) % wave_pattern_count as WavePattern
	_debug_log("Ship3 cycled to pattern: %s" % WavePattern.keys()[current_pattern])

func _on_pattern_cooldown_finished() -> void:
	# Pattern cooldown completed, ready for next wave
	pass
