extends Camera2D

# Hardcoded limits
const START_LIMIT: float = 1000 # Bottom limit (can't go below this)
const END_LIMIT: float = -5700.0    # Top limit (can't go above this)

@export var scroll_speed: float = 1.0    # Sensitivity
@export var inertia: float = 0.95        # Smooth stop
@export var friction: float = 0.05       # Friction

var drag_start_position: Vector2
var is_dragging: bool = false
var vertical_velocity: float = 0.0
var cam_half_height: float  # Half of camera height for bounds checking

func _ready():
	make_current()
	# Get half the screen height to check top/bottom edges
	cam_half_height = get_viewport_rect().size.y * 0.5 
	
func _input(event):
	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		drag_start_position = event.position
		is_dragging = true
		vertical_velocity = 0.0

	elif (event is InputEventScreenDrag or (event is InputEventMouseMotion and is_dragging)):
		var delta_y = (drag_start_position.y - event.position.y) * scroll_speed
		var new_y = clamp(position.y + delta_y, END_LIMIT + cam_half_height, START_LIMIT - cam_half_height)
		
		position.y = new_y
		drag_start_position = event.position
		vertical_velocity = delta_y * 0.2
		position.x = 0  # Lock X position

	elif (event is InputEventScreenTouch and not event.pressed) or \
		 (event is InputEventMouseButton and not event.pressed):
		is_dragging = false

func _process(_delta):
	if not is_dragging:
		var new_y = clamp(position.y + vertical_velocity,
						 END_LIMIT + cam_half_height,
						 START_LIMIT - cam_half_height)
		
		position.y = new_y
		vertical_velocity *= inertia
		if abs(vertical_velocity) < friction:
			vertical_velocity = 0.0
		position.x = 0  # Lock X position
