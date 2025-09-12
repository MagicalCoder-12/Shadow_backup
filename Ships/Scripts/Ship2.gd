extends BaseShip

# Ship2: Aether Strike - Tailored implementation with burst-fire attack pattern

# Burst-fire configuration
@export var burst_count: int = 3  # Number of bullets per burst
@export var burst_delay: float = 0.1  # Delay between bullets in burst
@export var burst_cooldown: float = 0.8  # Cooldown after burst completion

# Burst-fire state tracking
var current_burst_shot: int = 0
var is_bursting: bool = false
var burst_timer: Timer
var burst_cooldown_timer: Timer

func _ready() -> void:
	# Configure texture scales for Ship2
	base_texture_scale = Vector2(1.5, 1.5)
	evolution_texture_scales = [Vector2(1.3, 1.3), Vector2(1.5, 1.5)]  # upgrade_1, upgrade_2
	default_evolution_scale = Vector2(1.0, 1.0)

	super._ready()  # Call BaseShip's _ready for evolution scaling
	plBullet = preload("res://Bullet/player_bullet_2.tscn")  # Default bullet for normal mode
	
	# Setup burst-fire timers
	burst_timer = Timer.new()
	burst_timer.wait_time = burst_delay
	burst_timer.timeout.connect(_fire_burst_shot)
	add_child(burst_timer)
	
	burst_cooldown_timer = Timer.new()
	burst_cooldown_timer.wait_time = burst_cooldown
	burst_cooldown_timer.one_shot = true
	burst_cooldown_timer.timeout.connect(_on_burst_cooldown_finished)
	add_child(burst_cooldown_timer)
	
	_apply_ship_specific_stats()

func _apply_ship_specific_stats() -> void:
	# Don't override damage if it was already set by the upgrade system
	# Only set damage if it hasn't been initialized yet (i.e., still at default value)
	if base_bullet_damage == 20:  # Default damage from Player.gd
		# Get the actual damage from the ship data instead of hardcoding
		var ship_data = null
		for ship in GameManager.ships:
			if ship.get("id", "") == ship_id:
				ship_data = ship
				break
		
		if ship_data:
			base_bullet_damage = ship_data.get("damage", 25)
		else:
			base_bullet_damage = 25  # Fallback to original value
	
	_debug_log("Applied Ship2 specific stats: damage=%d, speed=%.1f" % [base_bullet_damage, speed])

# Override shoot() method for burst-fire attack pattern
func shoot() -> void:
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

func _fire_burst_shot() -> void:
	if current_burst_shot >= burst_count:
		# Burst complete, start cooldown
		is_bursting = false
		burst_timer.stop()
		burst_cooldown_timer.start()
		return
	
	# Fire a single bullet using parent's shooting logic
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	var bullet_scene: PackedScene = plSuperBullet if is_super_mode or is_shadow_mode else plBullet
	var bullet_speed: float = super_mode_bullet_speed if is_super_mode else GameManager.player_manager.default_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	
	if is_shadow_mode and not is_super_mode:
		_shoot_shadow_bullets(bullet_scene, bullet_speed, bullet_damage)
	else:
		_shoot_normal_bullets(bullet_scene, bullet_speed, bullet_damage)
	
	# Play shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")
	
	current_burst_shot += 1

func _on_burst_cooldown_finished() -> void:
	# Burst cooldown completed, ready for next burst
	pass

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	# Override to include Ship2-specific super mode bullet setup
	super.apply_super_mode_effects(multiplier_div, duration)  # Call base implementation
	_setup_super_mode_bullets()
	_debug_log("Ship2 super mode activated with PlayerBullet2, damage boosted to %d" % GameManager.player_manager.player_stats["bullet_damage"])

func _setup_super_mode_bullets() -> void:
	# Switch to PlayerBullet2 for super mode with enhanced arch effect
	plBullet = preload("res://Bullet/player_bullet_2.tscn")  # Ensure PlayerBullet2 is used
	fire_delay_timer.wait_time = super_mode_fire_delay  # From Player.gd export
	_debug_log("Ship2 super mode bullets set to PlayerBullet2 with delay %.2f" % fire_delay_timer.wait_time)
