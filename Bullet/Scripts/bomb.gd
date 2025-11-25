extends Node2D

@export var fall_speed: float = 400.0  # Speed at which the bomb falls
var explosion_scene = preload("res://Bullet/Ebullet/Explosion.tscn")
@onready var timer: Timer = $Timer
var player_in_area: Player = null

# Add a class variable to track active bombs
static var active_bombs: int = 0
const MAX_ACTIVE_BOMBS: int = 50  # Limit the number of active bombs
const OFFSCREEN_THRESHOLD: int = 1000  # Remove bombs that fall too far

func _ready() -> void:
	# Check if we've exceeded the bomb limit
	if active_bombs >= MAX_ACTIVE_BOMBS:
		queue_free()
		return
		
	active_bombs += 1
	timer.wait_time = 3.0
	timer.start()

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	
	# Remove bombs that have fallen too far off-screen
	if position.y > OFFSCREEN_THRESHOLD:
		active_bombs = max(0, active_bombs - 1)
		queue_free()

func _on_timer_timeout() -> void:
	spawn_explosion()

func _on_area_entered(area: Area2D) -> void:
	# Disable further collisions to prevent multiple triggers
	set_deferred("monitoring", false)
	# Defer explosion spawning and cleanup
	call_deferred("spawn_explosion")
	if area is Player:
		area.damage(2)

func spawn_explosion() -> void:
	# Decrease the active bomb count when exploding
	active_bombs = max(0, active_bombs - 1)
	
	var explosion = explosion_scene.instantiate()
	explosion.position = global_position  # Use global_position for consistency
	get_parent().call_deferred("add_child", explosion)
	queue_free()

func _exit_tree() -> void:
	# Ensure we decrement the counter when the bomb is removed for any reason
	active_bombs = max(0, active_bombs - 1)
