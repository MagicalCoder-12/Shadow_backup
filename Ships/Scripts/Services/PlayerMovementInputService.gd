extends RefCounted
class_name PlayerMovementInputService

var _owner: Node2D
var _collision_shape: CollisionShape2D
var _smoothness: float = 0.3
var _boundary_padding: float = 10.0

var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_touching: bool = false

func configure(owner: Node2D, collision_shape: CollisionShape2D, smoothness: float, boundary_padding: float) -> void:
	_owner = owner
	_collision_shape = collision_shape
	_smoothness = smoothness
	_boundary_padding = boundary_padding
	initialize_target_position()

func initialize_target_position() -> void:
	if _owner:
		target_position = _owner.position

func handle_input(event: InputEvent, input_enabled: bool) -> void:
	if not input_enabled or not _owner:
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_action_pressed("click")):
		var event_pos: Vector2 = event.position
		if _is_over_ui(event_pos):
			if event is InputEventScreenTouch and not event.pressed:
				is_touching = false
			return

		if event is InputEventScreenTouch:
			is_touching = event.pressed
			if is_touching:
				target_position = event.position
		elif event is InputEventScreenDrag:
			is_touching = true
			target_position = event.position
		elif event is InputEventMouseMotion and Input.is_action_pressed("click"):
			is_touching = true
			target_position = event.position

func handle_keyboard_movement(delta: float, speed: float) -> void:
	if not _owner:
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1

	if dir != Vector2.ZERO:
		velocity = dir.normalized() * speed
		_owner.position += velocity * delta

func handle_touch_movement() -> void:
	if not _owner:
		return
	_owner.position = _owner.position.lerp(target_position, _smoothness)

func clamp_position() -> void:
	if not _owner:
		return

	var view_rect := _owner.get_viewport_rect()
	var player_size := Vector2.ZERO
	if _collision_shape and _collision_shape.shape and _collision_shape.shape.has_method("get_rect"):
		player_size = _collision_shape.shape.get_rect().size

	var min_pos := Vector2(player_size.x / 2 + _boundary_padding, player_size.y / 2 + _boundary_padding)
	var max_pos := view_rect.size - min_pos
	_owner.position = _owner.position.clamp(min_pos, max_pos)

func _is_over_ui(event_pos: Vector2) -> bool:
	if not _owner or not _owner.get_tree():
		return false
	var controls = _owner.get_tree().get_nodes_in_group("UI")
	for control in controls:
		if control is Control and control.get_global_rect().has_point(event_pos):
			return true
	return false
