extends BulletBase
class_name SatelliteBullet

@export var homing_strength: float = 1.0
@export var lifetime: float = 5.0
var target: Node

@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var lifetime_timer: Timer = $LifetimeTimer

func _setup_bullet() -> void:
	lifetime_timer.wait_time = lifetime
	lifetime_timer.start()
	bullet_owner = "satellite"
	collision_groups = [GameManager.GROUP_DAMAGEABLE, GameManager.GROUP_BOSS]

	damage = int(GameManager.player_stats["bullet_damage"] * 0.8)
	if damage <= 0:
		damage = 10
		push_warning("SatelliteBullet: Invalid damage from player stats, using default: %d" % damage)

	if glow_sprite:
		glow_sprite.modulate = Color(0, 1, 1, 0.8) # Cyan glow
		glow_sprite.scale = Vector2(0.5, 0.5)
		glow_sprite.visible = true

	visible = true
	z_index = 10
	modulate.a = 1.0

	_find_nearest_enemy()

func _update_visuals() -> void:
	if target and is_instance_valid(target):
		var direction_to_target: Vector2 = (target.global_position - global_position).normalized()
		var desired_velocity: Vector2 = direction_to_target * speed
		velocity = velocity.lerp(desired_velocity, homing_strength * get_physics_process_delta_time())
		global_rotation = velocity.angle() + PI / 2
	else:
		_find_nearest_enemy()

func _find_nearest_enemy() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group(GameManager.GROUP_DAMAGEABLE)
	var closest_distance: float = INF
	var closest_enemy: Node = null

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.is_in_group("Meteor"): # 🚫 Skip meteors
			continue

		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	target = closest_enemy

func _on_lifetime_timer_timeout() -> void:
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
