extends Area2D
class_name EnergyBall

## Speed of the energy ball in pixels per second.
@export var speed: float = 1200.0

## Damage dealt to the player.
@export var damage: int = 1

## Direction of movement.
var direction: Vector2 = Vector2.ZERO

## Velocity vector of the energy ball.
var velocity: Vector2 = Vector2.ZERO

## Lifetime of the energy ball in seconds.
@export var lifetime: float = 5.0

## Internal timer for tracking lifetime.
var _lifetime_timer: float = 0.0

func _ready() -> void:
	if speed <= 0:
		print("Warning: EnergyBall speed is non-positive. Setting to 1200.0.")
		speed = 1200.0
	if damage <= 0:
		print("Warning: EnergyBall damage is non-positive. Setting to 1.")
		damage = 1
	if lifetime <= 0:
		print("Warning: EnergyBall lifetime is non-positive. Setting to 5.0.")
		lifetime = 5.0

func _physics_process(delta: float) -> void:
	# Move the energy ball
	if direction != Vector2.ZERO:
		velocity = direction * speed
	global_position += velocity * delta
	
	# Handle lifetime
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		explode()
		queue_free()

## Sets the direction of the energy ball.
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

## Sets the speed of the energy ball.
func set_speed(new_speed: float) -> void:
	if new_speed <= 0:
		print("Warning: EnergyBall speed cannot be non-positive. Setting to 1200.0.")
		speed = 1200.0
	else:
		speed = new_speed

## Sets the lifetime of the energy ball.
func set_lifetime(time: float) -> void:
	if time <= 0:
		print("Warning: EnergyBall lifetime cannot be non-positive. Setting to 5.0.")
		lifetime = 5.0
	else:
		lifetime = time
		_lifetime_timer = 0.0

## Returns the damage value of the energy ball.
func get_damage() -> int:
	return damage

## Sets the damage value of the energy ball.
func set_damage(new_damage: int) -> void:
	if new_damage <= 0:
		print("Warning: EnergyBall damage is non-positive. Setting to 1.")
		damage = 1
	else:
		damage = new_damage

## Handles collision with the player.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		# Check if player is in grace period after revival
		if area.has_method("is_just_revived") and area.is_just_revived():
			return
		area.call("damage", damage)
		explode()
		queue_free()

## Frees the energy ball when it exits the screen.
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

## Creates an explosion effect when the energy ball is destroyed.
func explode() -> void:
	# Create explosion particles
	var explosion_scene = preload("res://Bosses/phase_transition_effect.tscn")
	if explosion_scene and explosion_scene.can_instantiate():
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		explosion.scale = Vector2(0.3, 0.3) # Smaller explosion
		get_tree().current_scene.call_deferred("add_child", explosion)
