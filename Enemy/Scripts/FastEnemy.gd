extends Enemy
class_name FastEnemy

# Fast enemy specific properties
@export var speed_multiplier: float = 1.5  # How much faster than base enemy
@export var agility_multiplier: float = 2.0  # How much more agile in formation
@export var dive_speed_multiplier: float = 1.8  # Faster diving
@export var rapid_fire_chance: float = 0.15  # Chance to enter rapid fire mode
@export var rapid_fire_duration: float = 2.0  # How long rapid fire lasts
@export var rapid_fire_rate: float = 0.3  # Fire rate during rapid fire

# Shadow-specific enhancements for fast enemies
@export var shadow_fire_rate_multiplier: float = 0.7  # Faster firing when shadow
@export var shadow_agility_multiplier: float = 1.3  # Even more agile when shadow
@export var shadow_rapid_fire_chance: float = 0.25  # Higher chance of rapid fire

# Internal state
var is_rapid_firing: bool = false
var rapid_fire_timer: float = 0.0
var original_fire_rate: float
var formation_sway_timer: float = 0.0
var sway_amplitude: float = 30.0
var sway_frequency: float = 2.0
var original_formation_pos: Vector2

func _ready():
	super._ready()
	
	# Set entry speed multiplier for FormationManager
	entry_speed_multiplier = speed_multiplier
	
	# Store original values
	original_fire_rate = fire_rate
	
	# Enhance base enemy properties for fast enemy
	speed *= speed_multiplier
	vertical_speed *= speed_multiplier
	original_speed = speed
	original_vertical_speed = vertical_speed
	
	# Configure fire timer
	if fire_timer:
		fire_timer.wait_time = fire_rate
		fire_timer.timeout.connect(_on_fire_timer_timeout)
		fire_timer.start()
	
	# Fast enemies have slightly different stats
	if not is_shadow_enemy:
		score = int(score * 1.2)  # 20% more score for fast enemies
		max_health = max(1, max_health - 1)  # Slightly less health (glass cannon)
		damage_amount = int(damage_amount * 1.1)  # 10% more damage
	
	# Apply shadow enhancements if this is a shadow enemy
	if is_shadow_enemy:
		_apply_shadow_fast_enemy_bonuses()
	
	if debug_mode:
		print("FastEnemy spawned. Speed: ", speed, " Fire rate: ", fire_rate, " Shadow: ", is_shadow_enemy)

# Override shadow enemy creation to add fast enemy bonuses
func _make_shadow_enemy():
	super._make_shadow_enemy()
	_apply_shadow_fast_enemy_bonuses()

# Apply shadow-specific bonuses for fast enemies
func _apply_shadow_fast_enemy_bonuses():
	if not is_shadow_enemy:
		return
	
	# Enhanced fire rate
	fire_rate *= shadow_fire_rate_multiplier
	
	# Enhanced agility
	agility_multiplier *= shadow_agility_multiplier
	
	# Enhanced rapid fire chance
	rapid_fire_chance = shadow_rapid_fire_chance
	
	# Update fire timer if it exists
	if fire_timer:
		fire_timer.wait_time = fire_rate
	
	# Shadow fast enemies get additional visual effects
	_apply_shadow_fast_visual_effects()
	
	if debug_mode:
		print("Shadow fast enemy bonuses applied. Fire rate: ", fire_rate, " Agility: ", agility_multiplier)

# Apply additional visual effects for shadow fast enemies
func _apply_shadow_fast_visual_effects():
	if not is_shadow_enemy:
		return
	
	# Add speed lines or motion blur effect
	var speed_lines = Line2D.new()
	speed_lines.width = 2.0
	speed_lines.default_color = Color(0.3, 0.3, 1.0, 0.5)
	speed_lines.z_index = -1
	add_child(speed_lines)
	
	# Create a pulsing outline effect
	if sprite:
		var outline = sprite.duplicate()
		outline.modulate = Color(0.5, 0.5, 1.0, 0.3)
		outline.scale = Vector2(1.1, 1.1)
		outline.z_index = -1
		add_child(outline)

func _physics_process(delta):
	super._physics_process(delta)
	
	# Handle rapid fire mode
	if is_rapid_firing:
		rapid_fire_timer -= delta
		if rapid_fire_timer <= 0:
			is_rapid_firing = false
			fire_timer.wait_time = fire_rate
			if debug_mode:
				print("FastEnemy rapid fire mode ended")
	
	# Handle swaying when in formation
	if arrived_at_formation:
		_handle_formation_sway(delta)

# Handle swaying movement in formation
func _handle_formation_sway(delta):
	formation_sway_timer += delta * sway_frequency
	
	# Calculate sway offset
	var sway_offset = sin(formation_sway_timer) * sway_amplitude * agility_multiplier
	
	# Apply sway to x position only
	if original_formation_pos != Vector2.ZERO:
		position.x = original_formation_pos.x + sway_offset
	
	# Clamp to screen bounds
	position.x = clamp(position.x, 50, VIEWPORT_WIDTH - 50)

# Called by FormationManager when enemy reaches formation
func on_reach_formation():
	super.on_reach_formation()
	original_formation_pos = global_position
	
	if debug_mode:
		print("FastEnemy reached formation and started swaying")

# Override diving to make it faster and more aggressive
func start_dive():
	if not arrived_at_formation or not is_alive:
		return
	
	if debug_mode:
		print("FastEnemy starting aggressive dive")
	
	# Fast enemies dive more aggressively
	var dive_target_x = global_position.x + randf_range(-200, 200)
	dive_target_x = clamp(dive_target_x, 100, VIEWPORT_WIDTH - 100)
	var end_pos = Vector2(dive_target_x, VIEWPORT_HEIGHT + 50)
	
	# Faster dive duration
	var dive_duration = 2.0 / dive_speed_multiplier
	var tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, dive_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): death_reason = "dive_complete"; die())

# Fire timer timeout handler
func _on_fire_timer_timeout():
	if not is_alive or not arrived_at_formation:
		return
	
	# Check for rapid fire mode activation
	if not is_rapid_firing:
		var rapid_chance = rapid_fire_chance if not is_shadow_enemy else shadow_rapid_fire_chance
		if randf() < rapid_chance:
			_start_rapid_fire()
			return
	
	# Regular firing
	fire()

# Start rapid fire mode
func _start_rapid_fire():
	if is_rapid_firing:
		return
	
	is_rapid_firing = true
	rapid_fire_timer = rapid_fire_duration
	fire_timer.wait_time = rapid_fire_rate
	
	if debug_mode:
		print("FastEnemy entered rapid fire mode")
	
	# Fire immediately when entering rapid fire
	fire()

# Override fire to add rapid fire effects
func fire():
	super.fire()
	
	if is_rapid_firing and debug_mode:
		print("FastEnemy rapid fire shot")

# Override damage to account for glass cannon nature
func damage(amount: int):
	# Fast enemies take slightly more damage (glass cannon)
	var enhanced_damage = amount
	if not is_shadow_enemy:
		enhanced_damage = int(amount * 1.1)
	
	super.damage(enhanced_damage)

# Override shadow mode activation
func _on_shadow_mode_activated():
	super._on_shadow_mode_activated()
	
	if is_shadow_enemy:
		fire_timer.wait_time = fire_rate * shadow_fire_rate_multiplier
		if debug_mode:
			print("FastEnemy shadow mode activated, fire rate: ", fire_timer.wait_time)

# Override shadow mode deactivation
func _on_shadow_mode_deactivated():
	super._on_shadow_mode_deactivated()
	
	if is_shadow_enemy and is_rapid_firing:
		is_rapid_firing = false
		fire_timer.wait_time = fire_rate
		if debug_mode:
			print("FastEnemy shadow mode deactivated")

# Public method to force rapid fire (for special events)
func force_rapid_fire(duration: float = -1):
	if duration > 0:
		rapid_fire_duration = duration
	_start_rapid_fire()

# Check if in rapid fire mode
func is_in_rapid_fire() -> bool:
	return is_rapid_firing

# Get fast enemy specific information
func get_fast_enemy_info() -> Dictionary:
	var info = get_shadow_info()
	info.merge({
		"is_fast_enemy": true,
		"fire_rate": fire_rate,
		"speed_multiplier": speed_multiplier,
		"agility_multiplier": agility_multiplier,
		"is_rapid_firing": is_rapid_firing,
		"rapid_fire_chance": rapid_fire_chance
	})
	return info

# Enhanced status for debugging
func get_status() -> String:
	var base_status = super.get_status()
	return base_status + ", RapidFire: %s, FireRate: %.1f, Agility: %.1f" % [
		is_rapid_firing, fire_rate, agility_multiplier
	]

# Cleanup
func _exit_tree():
	super._exit_tree()
	
	if fire_timer and fire_timer.timeout.is_connected(_on_fire_timer_timeout):
		fire_timer.timeout.disconnect(_on_fire_timer_timeout)
