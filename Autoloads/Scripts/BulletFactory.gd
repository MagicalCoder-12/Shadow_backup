extends Node

## Spawns a bullet with the specified properties
func spawn_bullet(
	bullet_scene: PackedScene,
	position: Vector2,
	rotation: float = 0.0,
	speed: float = GameManager.DEFAULT_BULLET_SPEED,
	damage: int = GameManager.DEFAULT_BULLET_DAMAGE
) -> Node:
	if not bullet_scene or not bullet_scene.can_instantiate():
		print("Invalid bullet scene passed to BulletFactory.spawn_bullet")
		return null

	var bullet: Node = bullet_scene.instantiate()
	if not bullet is BulletBase:
		print("Bullet scene does not inherit from BulletBase")
		bullet.queue_free()
		return null

	bullet.global_position = position
	bullet.global_rotation = rotation
	bullet.speed = speed
	bullet.damage = damage
	bullet.visible = true
	bullet.z_index = 10
	bullet.modulate.a = 1.0
	return bullet
