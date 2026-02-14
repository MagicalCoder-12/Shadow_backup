extends BulletBase
class_name PlayerBullet

## Particle effect for the bullet trail.
const BULLET_EFFECT = preload("res://Bullet/PlBullet/BulletEffect.tscn")

## Sets up the bullet for player-specific behavior.
func _setup_bullet() -> void:
	bullet_owner = "player"
	collision_groups = [GameManager.GROUP_DAMAGEABLE, GameManager.GROUP_BOSS]
	visible = true
	z_index = 10
	modulate.a = 1.0

## Plays a hit effect on collision.
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
