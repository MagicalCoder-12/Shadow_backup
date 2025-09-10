extends Area2D
class_name ShadowEnemyBullet

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 1200
@export var damage: int = 1
@export var debug_mode: bool = false

# Shadow-specific properties
@export var shadow_damage_multiplier: float = 1.5
@export var shadow_speed_multiplier: float = 1.2

var is_shadow_bullet: bool = false
var original_speed: float
var original_damage: int
var player_in_area: Player = null
var is_alive: bool = true

const VIEWPORT_HEIGHT: float = 720.0

func _ready():
	original_speed = speed
	original_damage = damage
	
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
	speed = float(original_speed * shadow_speed_multiplier)
	
	if debug_mode:
		print("Bullet converted to shadow: Damage=", damage, " Speed=", speed)

func _physics_process(delta):
	if not is_alive:
		return
	
	# Move bullet downward
	position.y += speed * delta
	destroy()

# Handle collision with player
func _on_area_entered(area):
	if area is Player and player_in_area == null:
		player_in_area = area
		
		# Apply damage to player
		player_in_area.damage(damage)
		
		if debug_mode:
			print("Shadow bullet hit player for ", damage, " damage")
		
		destroy()

func _on_area_exited(area):
	if area is Player:
		player_in_area = null

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

# Enhanced damage for shadow bullets during shadow mode
func get_effective_damage() -> int:
	if is_shadow_bullet and GameManager.level_manager.shadow_mode_enabled:
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

# Clean destroy function
func destroy():
	if not is_alive:
		return
	
	is_alive = false
	
	if debug_mode:
		print("Shadow bullet destroyed at: ", global_position)
	
	queue_free()

# Cleanup when bullet is about to be freed
func _exit_tree():
	# Disconnect signals to prevent memory leaks
	if GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.disconnect(_on_shadow_mode_activated)
	if GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.disconnect(_on_shadow_mode_deactivated)

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


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
