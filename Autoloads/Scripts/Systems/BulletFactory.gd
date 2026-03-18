extends Node

# Object pool for bullets
var bullet_pool: Dictionary = {}
const MAX_POOL_SIZE: int = 50
const META_POOL_RETURN_PENDING: StringName = &"_pool_return_pending"

func _ready() -> void:
	# Initialize pools for different bullet types
	var bullet_scenes = [
		preload("res://Bullet/PlBullet/Bullet.tscn"),
		preload("res://Bullet/PlBullet/super_bullet.tscn"),
		preload("res://Bullet/PlBullet/plshadow_bullet.tscn"),
		preload("res://Bullet/Ebullet/Enemy_Bullet.tscn"),
		preload("res://Bullet/Ebullet/shadow_enemy_bullet.tscn")
	]
	
	for scene in bullet_scenes:
		if scene:
			bullet_pool[scene.resource_path] = []

## Spawns a bullet with the specified properties, using object pooling
func spawn_bullet(
	bullet_scene: PackedScene,
	position: Vector2,
	rotation: float = 0.0,
	speed: float = 600.0,  # Default speed from BulletBase
	damage: int = 10  # Default damage from BulletBase
) -> Node:
	if not bullet_scene or not bullet_scene.can_instantiate():
		push_warning("Invalid bullet scene passed to BulletFactory.spawn_bullet")
		return null

	# Get bullet from pool or create new one
	var bullet: Node = _get_bullet_from_pool(bullet_scene)
	if not bullet:
		# No available bullets in pool, create new one
		bullet = bullet_scene.instantiate()
		if not bullet is BulletBase:
			push_warning("Bullet scene does not inherit from BulletBase")
			bullet.queue_free()
			return null

	# Reset bullet properties
	bullet.global_position = position
	bullet.global_rotation = rotation
	bullet.speed = speed
	bullet.damage = damage
	bullet.is_active = true
	bullet.visible = true
	bullet.z_index = 10
	bullet.modulate = Color(1.0, 1.0, 1.0, 1.0)
	bullet.pool_key = bullet_scene.resource_path  # Store pool key for BulletBase return hooks.
	bullet.set_meta(META_POOL_RETURN_PENDING, false)
	
	return bullet

## Gets a bullet from the pool or creates a new one if pool is empty
func _get_bullet_from_pool(bullet_scene: PackedScene) -> Node:
	var pool_key = bullet_scene.resource_path
	if not bullet_pool.has(pool_key):
		# Initialize pool for this bullet type if not exists
		bullet_pool[pool_key] = []
	
	if bullet_pool[pool_key].size() > 0:
		var bullet = bullet_pool[pool_key].pop_back()
		# Check if the bullet is still valid (not freed)
		if is_instance_valid(bullet):
			# Ensure the bullet is not in the scene tree before returning
			if bullet.get_parent():
				bullet.get_parent().remove_child(bullet)
			# Pooled bullets need _ready to run again to refresh velocity/timers/state.
			bullet.request_ready()
			return bullet
		else:
			return null
	else:
		var new_bullet = bullet_scene.instantiate()
		if new_bullet is BulletBase:
			return new_bullet
		else:
			push_warning("Bullet scene does not inherit from BulletBase")
			new_bullet.queue_free()
			return null

## Explicitly returns a bullet to the pool (called by bullets themselves)
func return_bullet_to_pool(bullet: BulletBase, pool_key: String) -> void:
	if not is_instance_valid(bullet):
		return

	var is_pending: bool = bool(bullet.get_meta(META_POOL_RETURN_PENDING, false))
	if is_pending:
		return

	bullet.set_meta(META_POOL_RETURN_PENDING, true)
	call_deferred("_finalize_return_bullet_to_pool", bullet, pool_key)

func _finalize_return_bullet_to_pool(bullet: BulletBase, pool_key: String) -> void:
	if not is_instance_valid(bullet):
		return

	bullet.set_meta(META_POOL_RETURN_PENDING, false)

	if pool_key == "" or not bullet_pool.has(pool_key):
		bullet.queue_free()
		return

	# Check if the bullet is already in the pool to avoid double-adding.
	if bullet in bullet_pool[pool_key]:
		return

	if bullet_pool[pool_key].size() >= MAX_POOL_SIZE:
		# Pool is full, just free the bullet.
		bullet.queue_free()
		return

	# Reset bullet properties before returning to pool.
	bullet.is_active = false
	bullet.visible = false
	bullet.modulate = Color(1.0, 1.0, 1.0, 1.0)
	bullet.global_position = Vector2(-1000, -1000)
	bullet.speed = 600.0
	bullet.damage = 10
	if bullet.get_parent():
		bullet.get_parent().remove_child(bullet)
	bullet_pool[pool_key].append(bullet)

## Clears all pools (call when changing scenes)
func clear_pools() -> void:
	for pool_key in bullet_pool:
		for bullet in bullet_pool[pool_key]:
			if is_instance_valid(bullet):
				bullet.queue_free()
		bullet_pool[pool_key].clear()

## Returns the size of a specific bullet pool
func get_pool_size(bullet_scene_path: String) -> int:
	if bullet_pool.has(bullet_scene_path):
		return bullet_pool[bullet_scene_path].size()
	return 0
