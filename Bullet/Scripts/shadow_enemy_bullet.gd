extends Area2D
class_name ShadowEnemyBullet

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 300.0
@export var damage: int = 2
@export var debug_mode: bool = false

# Shadow-specific properties
@export var shadow_damage_multiplier: float = 1.5
@export var shadow_speed_multiplier: float = 1.2
@export var shadow_pulse_speed: float = 3.0
@export var shadow_alpha_min: float = 0.3
@export var shadow_alpha_max: float = 0.9
@export var shadow_trail_length: int = 8

var is_shadow_bullet: bool = false
var shadow_tween: Tween
var original_modulate: Color
var original_speed: float
var original_damage: int
var player_in_area: Player = null
var is_alive: bool = true

# Trail effect variables
var trail_positions: Array[Vector2] = []
var trail_sprites: Array[Sprite2D] = []

const VIEWPORT_HEIGHT: float = 720.0
const SCREEN_BUFFER: float = 50.0

func _ready():
	original_speed = speed
	original_damage = damage
	original_modulate = modulate
	
	add_to_group("EnemyBullet")
	
	# Connect to shadow mode signals
	_connect_shadow_signals()
	
	if debug_mode:
		print("Shadow bullet spawned. Shadow: ", is_shadow_bullet)

# Connect to GameManager shadow signals
func _connect_shadow_signals():
	if not GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	if not GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)

# Convert this bullet to a shadow bullet
func make_shadow_bullet():
	if is_shadow_bullet:
		return
	
	is_shadow_bullet = true
	
	# Enhance bullet properties
	damage = int(original_damage * shadow_damage_multiplier)
	speed = original_speed * shadow_speed_multiplier
	
	# Apply shadow visual effects
	_apply_shadow_visuals()
	
	# Initialize trail effect
	_initialize_trail()
	
	if debug_mode:
		print("Bullet converted to shadow: Damage=", damage, " Speed=", speed)

# Apply shadow visual effects
func _apply_shadow_visuals():
	if not is_shadow_bullet:
		return
	
	# Purple/blue shadow tint with transparency
	modulate = Color(0.4, 0.2, 0.9, 0.8)
	
	# Start pulsing animation
	_start_shadow_pulse()
	
	# Add glow effect by scaling slightly
	scale = Vector2(1.2, 1.2)

# Start shadow pulsing animation
func _start_shadow_pulse():
	if shadow_tween:
		shadow_tween.kill()
	
	shadow_tween = create_tween()
	shadow_tween.set_loops()
	
	# Pulse between min and max alpha
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_max, shadow_alpha_min, shadow_pulse_speed / 2.0)
	shadow_tween.tween_method(_set_shadow_alpha, shadow_alpha_min, shadow_alpha_max, shadow_pulse_speed / 2.0)

# Set shadow alpha for pulsing effect
func _set_shadow_alpha(alpha: float):
	if is_shadow_bullet:
		modulate.a = alpha

# Initialize trail effect for shadow bullets
func _initialize_trail():
	if not is_shadow_bullet:
		return
	
	# Create trail sprites
	for i in range(shadow_trail_length):
		var trail_sprite = Sprite2D.new()
		trail_sprite.texture = sprite.texture
		trail_sprite.modulate = Color(0.2, 0.1, 0.6, 0.1 + (i * 0.05))
		trail_sprite.scale = Vector2(0.7, 0.7)
		trail_sprite.z_index = -1
		add_child(trail_sprite)
		trail_sprites.append(trail_sprite)
		trail_positions.append(global_position)

# Update trail positions
func _update_trail():
	if not is_shadow_bullet or trail_sprites.is_empty():
		return
	
	# Add current position to trail
	trail_positions.push_front(global_position)
	
	# Remove excess positions
	if trail_positions.size() > shadow_trail_length:
		trail_positions.pop_back()
	
	# Update trail sprite positions
	for i in range(min(trail_sprites.size(), trail_positions.size())):
		if i < trail_positions.size():
			trail_sprites[i].global_position = trail_positions[i]

func _physics_process(delta):
	if not is_alive:
		return
	
	# Move bullet downward
	position.y += speed * delta
	
	# Update trail effect for shadow bullets
	if is_shadow_bullet:
		_update_trail()
	
	# Remove bullet when it goes off screen
	if global_position.y > VIEWPORT_HEIGHT + SCREEN_BUFFER:
		if debug_mode:
			print("Shadow bullet destroyed: Off screen")
		destroy()

# Handle collision with player
func _on_area_entered(area):
	if area is Player and player_in_area == null:
		player_in_area = area
		
		# Apply damage to player
		player_in_area.damage(damage)
		
		if debug_mode:
			print("Shadow bullet hit player for ", damage, " damage")
		
		# Shadow bullets have special hit effects
		if is_shadow_bullet:
			_create_shadow_hit_effect()
		
		destroy()

func _on_area_exited(area):
	if area is Player:
		player_in_area = null

# Create special hit effect for shadow bullets
func _create_shadow_hit_effect():
	# Create a brief flash effect
	var flash = ColorRect.new()
	flash.color = Color(0.3, 0.1, 0.8, 0.3)
	flash.size = Vector2(100, 100)
	flash.position = global_position - Vector2(50, 50)
	get_tree().current_scene.add_child(flash)
	
	# Animate the flash
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)

# Handle shadow mode activation
func _on_shadow_mode_activated():
	if debug_mode:
		print("Shadow mode activated for bullet")
	
	# Convert to shadow bullet if not already
	if not is_shadow_bullet:
		make_shadow_bullet()

# Handle shadow mode deactivation
func _on_shadow_mode_deactivated():
	if debug_mode:
		print("Shadow mode deactivated for bullet")
	
	# Don't revert existing shadow bullets to maintain consistency
	# But stop the pulsing effect if desired
	if is_shadow_bullet and shadow_tween:
		shadow_tween.kill()
		modulate.a = 0.7  # Set to a stable alpha

# Enhanced damage for shadow bullets during shadow mode
func get_effective_damage() -> int:
	if is_shadow_bullet and GameManager.shadow_mode_enabled:
		return int(damage * 1.25)  # 25% bonus damage during active shadow mode
	return damage

# Public method to check if this is a shadow bullet
func is_shadow() -> bool:
	return is_shadow_bullet

# Get shadow bullet information
func get_shadow_info() -> Dictionary:
	return {
		"is_shadow": is_shadow_bullet,
		"shadow_damage_multiplier": shadow_damage_multiplier,
		"shadow_speed_multiplier": shadow_speed_multiplier,
		"effective_damage": get_effective_damage()
	}

# Enhanced debugging function
func get_status() -> String:
	return "Alive: %s, Shadow: %s, Damage: %d, Speed: %.1f, Pos: %s" % [
		is_alive, is_shadow_bullet, get_effective_damage(), speed, global_position
	]

# Clean destroy function
func destroy():
	if not is_alive:
		return
	
	is_alive = false
	
	if debug_mode:
		print("Shadow bullet destroyed at: ", global_position)
	
	# Clean up shadow tween
	if shadow_tween:
		shadow_tween.kill()
	
	# Clean up trail sprites
	for trail_sprite in trail_sprites:
		if is_instance_valid(trail_sprite):
			trail_sprite.queue_free()
	
	queue_free()

# Cleanup when bullet is about to be freed
func _exit_tree():
	if shadow_tween:
		shadow_tween.kill()
	
	# Disconnect signals to prevent memory leaks
	if GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.disconnect(_on_shadow_mode_activated)
	if GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.disconnect(_on_shadow_mode_deactivated)
	
	# Clean up trail sprites
	for trail_sprite in trail_sprites:
		if is_instance_valid(trail_sprite):
			trail_sprite.queue_free()

# Force conversion to shadow bullet (for special cases)
func force_shadow_conversion():
	if not is_shadow_bullet:
		make_shadow_bullet()

# Method to enhance bullet mid-flight (for power-ups or special events)
func enhance_bullet(damage_multiplier: float = 1.5, speed_multiplier: float = 1.2):
	damage = int(damage * damage_multiplier)
	speed = speed * speed_multiplier
	
	if debug_mode:
		print("Bullet enhanced: Damage=", damage, " Speed=", speed)
