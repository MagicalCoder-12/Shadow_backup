extends BulletBase

@export var lifetime: float = 5.0
@onready var lifetime_timer: Timer = $LifetimeTimer

func _setup_bullet() -> void:
	bullet_owner = "satellite"
	collision_groups = [GameManager.GROUP_DAMAGEABLE, GameManager.GROUP_BOSS]
	visible = true
	z_index = 10
	modulate.a = 1.0

	if lifetime_timer:
		var timeout_callable := Callable(self, "_on_lifetime_timer_timeout")
		if not lifetime_timer.timeout.is_connected(timeout_callable):
			lifetime_timer.timeout.connect(timeout_callable)
		lifetime_timer.stop()
		lifetime_timer.wait_time = maxf(0.05, lifetime)
		lifetime_timer.start()

func _on_lifetime_timer_timeout() -> void:
	_on_screen_exited()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_on_screen_exited()
