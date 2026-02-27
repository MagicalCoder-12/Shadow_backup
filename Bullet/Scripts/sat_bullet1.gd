extends BulletBase

const BULLET_EFFECT = preload("res://Bullet/PlBullet/BulletEffect.tscn")

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

func _on_collision(_area: Area2D) -> void:
	var hit_effect = BULLET_EFFECT.instantiate()
	if hit_effect:
		hit_effect.global_position = global_position
		var host: Node = get_parent()
		if host:
			host.call_deferred("add_child", hit_effect)
		elif get_tree() and get_tree().current_scene:
			get_tree().current_scene.call_deferred("add_child", hit_effect)
		else:
			hit_effect.queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_on_screen_exited()
