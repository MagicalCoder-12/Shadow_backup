extends Enemy
class_name SlowShooter

# SlowShooter specific properties
@export var speed_multiplier: float = 0.7  # Slower movement
@export var health_multiplier: float = 1.8  # Much more health (tank)
@export var damage_multiplier: float = 1.4  # Higher damage per shot
@export var accuracy_bonus: float = 0.3  # Better aim at player
@export var charge_shot_chance: float = 0.2  # Chance for charged shot
@export var charge_shot_damage_multiplier: float = 2.5  # Charged shot damage
@export var charge_shot_duration: float = 1.5  # Time to charge
@export var defensive_mode_chance: float = 0.15  # Chance to enter defensive mode
@export var defensive_mode_duration: float = 3.0  # How long defensive mode lasts
@export var defensive_damage_reduction: float = 0.5  # Damage reduction during defense

# Shadow-specific enhancements for slow shooters
@export var shadow_charge_chance: float = 0.35  # Higher charge shot chance
@export var shadow_defensive_chance: float = 0.25  # Higher defensive mode chance
@export var shadow_health_bonus: float = 1.3  # Additional health bonus
@export var shadow_piercing_chance: float = 0.15  # Chance for piercing shots

# Internal state
var is_charging_shot: bool = false
var charge_shot_timer: float = 0.0
var is_defensive_mode: bool = false
var defensive_mode_timer: float = 0.0
var original_fire_rate: float
var player_reference: Player = null
var last_player_position: Vector2

# Charging effects
var charge_particles: Array[Node2D] = []
var charge_glow: ColorRect
var charge_tween: Tween

# Defensive mode effects
var defensive_shield: ColorRect
var defensive_tween: Tween

func _ready():
	super._ready()
	
	# Store original values
	original_fire_rate = fire_rate
	original_modulate = modulate
	
	# Enhance base enemy properties for slow shooter
	speed *= speed_multiplier
	vertical_speed *= speed_multiplier
	original_speed = speed
	original_vertical_speed = vertical_speed
	
	# Tank-like properties
	max_health = int(max_health * health_multiplier)
	health = max_health
	damage_amount = int(damage_amount * damage_multiplier)
	score = int(score * 1.3)  # 30% more score for tougher enemy
	
	# Apply shadow enhancements if this is a shadow enemy
	if is_shadow_enemy:
		_apply_shadow_slow_shooter_bonuses()
	
	# Update healthbar with new max health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	
	# Find player reference
	_find_player_reference()
	
	if debug_mode:
		print("SlowShooter spawned. Health: ", max_health, " Damage: ", damage_amount, " Shadow: ", is_shadow_enemy)

# Find player reference for targeting
func _find_player_reference():
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_reference = players[0]

# Override shadow enemy creation to add slow shooter bonuses
func _make_shadow_enemy():
	super._make_shadow_enemy()  # Call parent method
	_apply_shadow_slow_shooter_bonuses()

# Apply shadow-specific bonuses for slow shooters
func _apply_shadow_slow_shooter_bonuses():
	if not is_shadow_enemy:
		return
	
	# Enhanced health
	max_health = int(max_health * shadow_health_bonus)
	health = max_health
	
	# Enhanced special attack chances
	charge_shot_chance = shadow_charge_chance
	defensive_mode_chance = shadow_defensive_chance
	
	# Update healthbar
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	
	# Shadow slow shooters get additional visual effects
	_apply_shadow_slow_visual_effects()
	
	if debug_mode:
		print("Shadow slow shooter bonuses applied. Health: ", max_health, " Charge chance: ", charge_shot_chance)

# Apply additional visual effects for shadow slow shooters
func _apply_shadow_slow_visual_effects():
	if not is_shadow_enemy:
		return
	
	# Add a subtle aura effect
	var aura = ColorRect.new()
	aura.color = Color(0.2, 0.2, 0.6, 0.2)
	aura.size = Vector2(80, 80)
	aura.position = Vector2(-40, -40)
	aura.z_index = -1
	add_child(aura)
	
	# Pulse the aura
	var aura_tween = create_tween()
	aura_tween.set_loops()
	aura_tween.tween_property(aura, "modulate:a", 0.1, 1.0)
	aura_tween.tween_property(aura, "modulate:a", 0.3, 1.0)

func _process(delta):
	# Handle charge shot timing
	if is_charging_shot:
		charge_shot_timer -= delta
		if charge_shot_timer <= 0:
			_execute_charge_shot()
			return
	
	# Handle defensive mode timing
	if is_defensive_mode:
		defensive_mode_timer -= delta
		if defensive_mode_timer <= 0:
			_end_defensive_mode()
	
	# Original firing logic with enhancements
	if fire_timer.is_stopped() and not is_charging_shot:
		_decide_attack_type()
		fire_timer.start(randf_range(fire_rate * 0.8, fire_rate * 1.2))

# Decide what type of attack to perform
func _decide_attack_type():
	if not is_alive or not arrived_at_formation:
		return
	
	# Check for defensive mode first
	var defensive_chance = defensive_mode_chance
	if is_shadow_enemy:
		defensive_chance = shadow_defensive_chance
	
	if not is_defensive_mode and randf() < defensive_chance:
		_start_defensive_mode()
		return
	
	# Check for charge shot
	var charge_chance = charge_shot_chance
	if is_shadow_enemy:
		charge_chance = shadow_charge_chance
	
	if randf() < charge_chance:
		_start_charge_shot()
	else:
		_perform_aimed_shot()

# Start charging a powerful shot
func _start_charge_shot():
	if is_charging_shot:
		return
	
	is_charging_shot = true
	charge_shot_timer = charge_shot_duration
	
	# Create charging visual effects
	_create_charge_effects()
	
	if debug_mode:
		print("SlowShooter starting charge shot")

# Create visual effects for charging
func _create_charge_effects():
	# Create glow effect
	charge_glow = ColorRect.new()
	charge_glow.color = Color(1.0, 0.8, 0.2, 0.3)
	if is_shadow_enemy:
		charge_glow.color = Color(0.8, 0.2, 1.0, 0.4)
	
	charge_glow.size = Vector2(60, 60)
	charge_glow.position = Vector2(-30, -30)
	add_child(charge_glow)
	
	# Animate the glow
	charge_tween = create_tween()
	charge_tween.set_loops()
	charge_tween.tween_property(charge_glow, "scale", Vector2(1.2, 1.2), 0.3)
	charge_tween.tween_property(charge_glow, "scale", Vector2(0.8, 0.8), 0.3)
	
	# Create particle effects
	_create_charge_particles()

# Create particle effects for charging
func _create_charge_particles():
	for i in range(8):
		var particle = Sprite2D.new()
		# Use a small texture for the particle (create or load one)
		particle.texture =preload("res://Textures/starSmall.png") # Replace with your texture path
		particle.scale = Vector2(4, 4) / 16.0  # Adjust scale to match 4x4 size (assuming texture is 16x16)
		particle.modulate = Color(1.0, 1.0, 0.5, 0.8)
		if is_shadow_enemy:
			particle.modulate = Color(0.8, 0.5, 1.0, 0.8)
		
		var angle = i * PI * 2 / 8
		var radius = 40
		particle.position = Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)
		
		add_child(particle)
		charge_particles.append(particle)
		
		# Animate particles moving inward
		var particle_tween = create_tween()
		particle_tween.set_loops()
		particle_tween.tween_property(particle, "position", Vector2.ZERO, charge_shot_duration)
		particle_tween.tween_property(particle, "position", particle.position, 0.1)
# Execute the charged shot
func _execute_charge_shot():
	if not is_charging_shot:
		return
	
	is_charging_shot = false
	
	# Clean up charge effects
	_cleanup_charge_effects()
	
	# Fire powerful shot
	_fire_charge_shot()
	
	if debug_mode:
		print("SlowShooter executed charge shot")

# Fire the actual charged shot
func _fire_charge_shot():
	if not arrived_at_formation or not firing_positions or not is_alive:
		return
	
	for child in firing_positions.get_children():
		var bullet
		
		# Choose bullet type
		if is_shadow_enemy:
			bullet = ShadowEBullet.instantiate()
		else:
			bullet = EBullet.instantiate()
		
		bullet.global_position = child.global_position
		
		# Enhance bullet for charge shot
		if bullet.has_method("enhance_bullet"):
			bullet.enhance_bullet(charge_shot_damage_multiplier, 1.5)
		
		# Add piercing effect for shadow enemies
		if is_shadow_enemy and randf() < shadow_piercing_chance:
			if bullet.has_method("make_piercing"):
				bullet.make_piercing()
		
		get_tree().current_scene.add_child(bullet)

# Clean up charge effects
func _cleanup_charge_effects():
	if charge_glow:
		charge_glow.queue_free()
		charge_glow = null
	
	if charge_tween:
		charge_tween.kill()
		charge_tween = null
	
	for particle in charge_particles:
		if is_instance_valid(particle):
			particle.queue_free()
	charge_particles.clear()

# Perform aimed shot at player
func _perform_aimed_shot():
	if not player_reference:
		_find_player_reference()
	
	if player_reference:
		last_player_position = player_reference.global_position
		
		# Add some prediction for better aim
		if player_reference.has_method("get_velocity"):
			var player_velocity = player_reference.get_velocity()
			var prediction_time = 0.5
			last_player_position += player_velocity * prediction_time
	
	# Fire aimed shot
	fire()

# Override fire to add aiming
func fire():
	if not arrived_at_formation or not firing_positions or not is_alive:
		return
	
	for child in firing_positions.get_children():
		var bullet
		
		# Choose bullet type
		if is_shadow_enemy:
			bullet = ShadowEBullet.instantiate()
		else:
			bullet = EBullet.instantiate()
		
		bullet.global_position = child.global_position
		
		# Apply aiming if we have a target
		if last_player_position != Vector2.ZERO:
			_apply_aiming_to_bullet(bullet, child.global_position)
		
		get_tree().current_scene.add_child(bullet)

# Apply aiming to bullet
func _apply_aiming_to_bullet(bullet, start_pos: Vector2):
	if not bullet.has_method("set_direction"):
		return
	
	var direction = (last_player_position - start_pos).normalized()
	
	# Apply accuracy bonus
	var accuracy_variance = (1.0 - accuracy_bonus) * 0.3
	direction = direction.rotated(randf_range(-accuracy_variance, accuracy_variance))
	
	bullet.set_direction(direction)

# Start defensive mode
func _start_defensive_mode():
	if is_defensive_mode:
		return
	
	is_defensive_mode = true
	defensive_mode_timer = defensive_mode_duration
	
	# Create defensive visual effects
	_create_defensive_effects()
	
	if debug_mode:
		print("SlowShooter entered defensive mode")

# Create defensive mode visual effects
func _create_defensive_effects():
	# Create shield effect
	defensive_shield = ColorRect.new()
	defensive_shield.color = Color(0.2, 0.8, 1.0, 0.3)
	if is_shadow_enemy:
		defensive_shield.color = Color(0.8, 0.2, 1.0, 0.4)
	
	defensive_shield.size = Vector2(80, 80)
	defensive_shield.position = Vector2(-40, -40)
	defensive_shield.z_index = 1
	add_child(defensive_shield)
	
	# Animate the shield
	defensive_tween = create_tween()
	defensive_tween.set_loops()
	defensive_tween.tween_property(defensive_shield, "modulate:a", 0.2, 0.5)
	defensive_tween.tween_property(defensive_shield, "modulate:a", 0.5, 0.5)

# End defensive mode
func _end_defensive_mode():
	if not is_defensive_mode:
		return
	
	is_defensive_mode = false
	
	# Clean up defensive effects
	if defensive_shield:
		defensive_shield.queue_free()
		defensive_shield = null
	
	if defensive_tween:
		defensive_tween.kill()
		defensive_tween = null
	
	if debug_mode:
		print("SlowShooter exited defensive mode")

# Override damage to account for defensive mode
func damage(amount: int):
	var final_damage = amount
	
	# Apply defensive mode damage reduction
	if is_defensive_mode:
		final_damage = int(amount * defensive_damage_reduction)
		
		if debug_mode:
			print("SlowShooter defensive mode: ", amount, " -> ", final_damage)
	
	super.damage(final_damage)

# Override shadow mode activation
func _on_shadow_mode_activated():
	super._on_shadow_mode_activated()
	
	if is_shadow_enemy and debug_mode:
		print("SlowShooter shadow mode activated")

# Override shadow mode deactivation
func _on_shadow_mode_deactivated():
	super._on_shadow_mode_deactivated()
	
	if is_shadow_enemy:
		# End any active special modes
		if is_charging_shot:
			_cleanup_charge_effects()
			is_charging_shot = false
		
		if is_defensive_mode:
			_end_defensive_mode()
		
		if debug_mode:
			print("SlowShooter shadow mode deactivated")

# Public methods for special abilities
func force_charge_shot():
	if not is_charging_shot:
		_start_charge_shot()

func force_defensive_mode():
	if not is_defensive_mode:
		_start_defensive_mode()

func is_in_defensive_mode() -> bool:
	return is_defensive_mode

func is_charging() -> bool:
	return is_charging_shot

# Get slow shooter specific information
func get_slow_shooter_info() -> Dictionary:
	var info = get_shadow_info()  # Get shadow info from parent
	info.merge({
		"is_slow_shooter": true,
		"health_multiplier": health_multiplier,
		"damage_multiplier": damage_multiplier,
		"is_defensive_mode": is_defensive_mode,
		"is_charging_shot": is_charging_shot,
		"charge_shot_chance": charge_shot_chance,
		"defensive_mode_chance": defensive_mode_chance
	})
	return info

# Enhanced status for debugging
func get_status() -> String:
	var base_status = super.get_status()
	return base_status + ", Defensive: %s, Charging: %s, Health: %d/%d" % [
		is_defensive_mode, is_charging_shot, health, max_health
	]

# Cleanup
func _exit_tree():
	super._exit_tree()
	
	# Clean up effects
	_cleanup_charge_effects()
	
	if defensive_shield:
		defensive_shield.queue_free()
	
	if defensive_tween:
		defensive_tween.kill()
