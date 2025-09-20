extends Enemy
class_name BouncerEnemy

func _exit_tree():
	# Clean up tweens if any
	for child in get_children():
		if child.get_class() == "Tween":
			child.kill()

@export var bounce_amplitude: float = 50.0
@export var bounce_frequency: float = 2.0
@export var fire_delay: float = 1.0
@export var shadow_extra_bullets: int = 2  # NEW: Extra bullets in shadow mode

func _ready():
	super._ready()
	score = 150
	max_health = 200
	health = max_health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
	speed = 180.0
	fire_rate = 1.0 / fire_delay  # Set fire_rate as shots per second

func _physics_process(delta):
	if not is_alive:
		return
	super._physics_process(delta)
	if arrived_at_formation:
		var bounce = sin(Time.get_ticks_msec() / 1000.0 * bounce_frequency) * bounce_amplitude * delta
		global_position.x = clamp(global_position.x + bounce, 50.0, viewport_size.x - 50.0)
		# Shooting is handled by base class _physics_process
