extends BulletBase

# Tailored bullet for Ship2 with blue arch effect, adjusted for visibility against blue background

@onready var sprite_2d: Sprite2D = $Sprite2D

var arch_amplitude: float = 50.0  # Height of the arch curve
var arch_frequency: float = 2.0  # Speed of the arch oscillation
var time: float = 0.0  # Time for sinusoidal arching
var _active_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	time = 0.0
	_active_tint = Color(1.0, 1.0, 1.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	super._ready()  # Call base ready if BulletBase has one
	_apply_tint()

func _process(delta: float) -> void:
	# Tailor arching motion effect
	time += delta
	var offset = sin(time * arch_frequency) * arch_amplitude
	position.x += offset * delta  # Apply horizontal offset for arch curve


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_on_screen_exited()

func apply_shadow_tint(tint: Color) -> void:
	_active_tint = tint
	_apply_tint()

func _apply_tint() -> void:
	modulate = _active_tint
