extends Area2D

const MAX_ACTIVE_BOMBS: int = 8
static var active_bombs: int = 0

@export var fall_speed: float = 400.0
@export var fuse_time: float = 3.0
@export var damage: int = 2

var explosion_scene: PackedScene = preload("res://Bullet/Ebullet/Explosion.tscn")
@onready var timer: Timer = $Timer

var _has_exploded: bool = false
var _registered_as_active: bool = false

func _ready() -> void:
	_register_active_bomb()
	if timer:
		timer.wait_time = maxf(0.05, fuse_time)
		timer.start()

func _exit_tree() -> void:
	_release_active_bomb()

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return
	position.y += fall_speed * delta

func _on_timer_timeout() -> void:
	_trigger_explosion()

func _on_area_entered(_area: Area2D) -> void:
	if _has_exploded:
		return
	# Damage application is handled centrally by the player collision service.
	# Bomb only controls its explosion lifecycle.
	set_deferred("monitoring", false)
	call_deferred("_trigger_explosion")

func _trigger_explosion() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	if timer and not timer.is_stopped():
		timer.stop()
	_spawn_explosion()
	_release_active_bomb()
	queue_free()

func _spawn_explosion() -> void:
	if not explosion_scene:
		return
	var explosion: Node2D = explosion_scene.instantiate() as Node2D
	if not explosion:
		return
	explosion.global_position = global_position
	if SceneSpawnService:
		SceneSpawnService.spawn_child(explosion)
	elif get_parent():
		get_parent().call_deferred("add_child", explosion)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_release_active_bomb()
	queue_free()

func _register_active_bomb() -> void:
	if _registered_as_active:
		return
	active_bombs += 1
	_registered_as_active = true

func _release_active_bomb() -> void:
	if not _registered_as_active:
		return
	active_bombs = maxi(0, active_bombs - 1)
	_registered_as_active = false

func get_damage() -> int:
	return damage
