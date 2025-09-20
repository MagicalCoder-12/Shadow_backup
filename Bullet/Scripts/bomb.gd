extends Node2D

@export var fall_speed: float = 400.0  # Speed at which the bomb falls
var explosion_scene = preload("res://Bullet/Ebullet/Explosion.tscn")
@onready var timer: Timer = $Timer
var player_in_area: Player = null

func _ready() -> void:
	timer.wait_time = 3.0
	timer.start()

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta

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
	var explosion = explosion_scene.instantiate()
	explosion.position = global_position  # Use global_position for consistency
	get_parent().call_deferred("add_child", explosion)
	queue_free()
