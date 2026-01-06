extends Area2D
class_name BulletBase

## Speed of the bullet in pixels per second.
@export var speed: float = 600.0

## Damage dealt by the bullet.
@export var damage: int = 1

## Whether the bullet is active (can move and deal damage).
@export var is_active: bool = true

## Owner of the bullet (e.g., "player", "satellite", "enemy").
@export var bullet_owner: String = "player"

## Groups this bullet can collide with.
@export var collision_groups: Array[String] = [GameManager.GROUP_DAMAGEABLE, GameManager.GROUP_BOSS]

## Pool key for object pooling.
var pool_key: String = ""

## Velocity vector of the bullet.
var velocity: Vector2

func _ready() -> void:
	if speed <= 0:
		speed = 600.0
	if damage <= 0:
		damage = 10

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

			# Trigger collision effects and return bullet to pool if using object pooling
			_on_collision(area)
			is_active = false
			if pool_key != "":
				# Return to object pool instead of freeing
				if BulletFactory:
					BulletFactory.return_bullet_to_pool(self, pool_key)
				else:
					queue_free()
			else:
				# Not using object pooling, free normally
				queue_free()
			break # Stop checking other groups once a collision is handled

## Virtual method for derived classes to customize collision behavior.
func _on_collision(_area: Area2D) -> void:
	pass

## Returns the bullet to pool when it exits the screen.
func _on_screen_exited() -> void:
	if pool_key != "":
		# Return to object pool instead of freeing
		if BulletFactory:
			BulletFactory.return_bullet_to_pool(self, pool_key)
		else:
			queue_free()
	else:
		# Not using object pooling, free normally
		queue_free()
