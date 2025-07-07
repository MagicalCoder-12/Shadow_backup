extends Area2D
class_name BulletBase

## Speed of the bullet in pixels per second.
@export var speed: float = 600.0 # Assuming a default value if GameManager is not available here

## Damage dealt by the bullet.
@export var damage: int = 1 # Assuming a default value

## Whether the bullet is active (can move and deal damage).
@export var is_active: bool = true

## Owner of the bullet (e.g., "player", "satellite", "enemy").
@export var bullet_owner: String = "player"

## Groups this bullet can collide with.
@export var collision_groups: Array[String] = ["damageable", "boss"] # Using string literals for example

## Velocity vector of the bullet.
var velocity: Vector2

func _ready() -> void:

	if speed <= 0:
		# Using a generic default if GameManager isn't accessible in this context
		speed = 600.0
		print("Warning: Bullet speed is non-positive. Setting to default: %s" % speed)
	if damage <= 0:
		# Using a generic default
		damage = 1
		print("Warning: Bullet damage is non-positive. Setting to default: %s" % damage)

	velocity = Vector2.UP.rotated(global_rotation) * speed

	# Connect to screen exit signal if a VisibleOnScreenNotifier2D is present
	var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)

	# Allow derived classes to customize setup
	_setup_bullet()

## Virtual method for derived classes to customize bullet initialization.
func _setup_bullet() -> void:
	visible = true
	z_index = 10
	modulate.a = 1.0

## Updates the bullet's position and visuals each frame.
func _physics_process(delta: float) -> void:
	if is_active:
		global_position += velocity * delta
		_update_visuals()

## Virtual method for derived classes to customize visual updates (e.g., particles, animations).
func _update_visuals() -> void:
	pass

## Handles collision when entering another Area2D.
func _on_area_entered(area: Area2D) -> void:
	# Ignore self-collision or collisions after being deactivated
	if area == self or not is_active:
		return

	for group in collision_groups:
		if area.is_in_group(group):
			# Attempt to call a damage function on the collided object
			if area.has_method("damage"):
				area.damage(damage)
			elif area.has_method("take_damage"):
				area.take_damage(damage)

			# Trigger collision effects and clean up the bullet
			_on_collision(area)
			is_active = false
			call_deferred("queue_free")
			break # Stop checking other groups once a collision is handled

## Virtual method for derived classes to customize collision behavior.
func _on_collision(_area: Area2D) -> void:
	# Example: Play an impact animation or sound
	pass

## Frees the bullet when it exits the screen.
func _on_screen_exited() -> void:
	call_deferred("queue_free")
