extends Enemy
class_name BouncerEnemy

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
	fire_rate = fire_delay  # Sync with base class	
	# NEW: Override fire timer setup from base class
	fire_timer.wait_time = fire_rate
	fire_timer.start()

func _physics_process(delta):
	if not is_alive:
		return
	super._physics_process(delta)
	if arrived_at_formation:
		var bounce = sin(Time.get_ticks_msec() / 1000.0 * bounce_frequency) * bounce_amplitude * delta
		global_position.x = clamp(global_position.x + bounce, 50.0, VIEWPORT_WIDTH - 50.0)
		# Shooting is handled by base class _physics_process
