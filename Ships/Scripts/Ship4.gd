extends BaseShip

# Ship4: Phantom Drake - Piercing Rail attack pattern
# Fires high-damage railgun shots that pierce through multiple enemies.

const SHADOW_BULLET_TINT: Color = Color(0.3, 0.7, 1.0, 1.0)

# Piercing rail configuration for normal mode
@export var pierce_count: int = 3
@export var rail_fire_delay: float = 0.5
@export var rail_speed_multiplier: float = 1.5

# Shadow mode configuration
@export var shadow_rail_count: int = 5
@export var shadow_spread_degrees: float = 20.0
@export var shadow_damage_multiplier: float = 1.5
@export var shadow_pierce_bonus: int = 1

# Super mode configuration
@export var super_speed_multiplier: float = 2.5
@export var super_damage_multiplier: float = 3.0
@export var super_pierce_bonus: int = 3

func _ready():
	base_texture_scale = Vector2(1.0, 1.0)
	evolution_texture_scales = [
		Vector2(1.0, 1.0),
		Vector2(2.5, 2.5),
		Vector2(1.0, 1.0),
		Vector2(1.0, 1.0)
	]
	default_evolution_scale = Vector2(1.0, 1.0)

	super._ready()
	plBullet = preload("res://Bullet/PlBullet/player_bullet_4.tscn")
	plNormalBullet = preload("res://Bullet/PlBullet/player_bullet_4.tscn")

	_apply_ship_specific_stats()

func _apply_ship_specific_stats() -> void:
	fire_delay_timer.wait_time = rail_fire_delay
	_debug_log("Applied Ship4-specific stats")

func shoot() -> void:
	fire_delay_timer.start(mode_service.get_balanced_fire_delay(fire_delay_timer.wait_time))
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	var bullet_damage: int = mode_service.get_balanced_bullet_damage(
		GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)
	)
	bullet_damage = GameManager.get_god_mode_damage(bullet_damage)

	if is_super_mode and not is_shadow_mode:
		_shoot_super_rail(bullet_damage)
	elif is_shadow_mode and not is_super_mode:
		_shoot_shadow_rails(bullet_damage)
	else:
		_shoot_normal_rail(bullet_damage)

	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")

func _shoot_normal_rail(bullet_damage: int) -> void:
	var bullet_scene: PackedScene = plBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * rail_speed_multiplier

	for child in firing_positions.get_children():
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation,
			bullet_speed,
			bullet_damage
		)
		if bullet and bullet is BulletBase:
			bullet.pierce_count = pierce_count
			if not bullet.is_inside_tree():
				SceneSpawnService.spawn_child(bullet)

func _shoot_shadow_rails(bullet_damage: int) -> void:
	var bullet_scene: PackedScene = plBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * rail_speed_multiplier
	var spread: float = deg_to_rad(shadow_spread_degrees)
	var angle_step: float = spread / float(max(1, shadow_rail_count - 1))
	var start_angle: float = -spread / 2.0

	for i in range(shadow_rail_count):
		var angle: float = start_angle + i * angle_step
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			global_position,
			angle,
			bullet_speed,
			int(bullet_damage * shadow_damage_multiplier)
		)
		if bullet and bullet is BulletBase:
			bullet.pierce_count = pierce_count + shadow_pierce_bonus
			if bullet is CanvasItem:
				bullet.modulate = SHADOW_BULLET_TINT
			if not bullet.is_inside_tree():
				SceneSpawnService.spawn_child(bullet)

func _shoot_super_rail(bullet_damage: int) -> void:
	var bullet_scene: PackedScene = plBullet
	var bullet_speed: float = GameManager.player_manager.default_bullet_speed * super_speed_multiplier

	for child in firing_positions.get_children():
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation,
			bullet_speed,
			int(bullet_damage * super_damage_multiplier)
		)
		if bullet and bullet is BulletBase:
			bullet.pierce_count = pierce_count + super_pierce_bonus
			if bullet is CanvasItem:
				bullet.modulate = Color(1.0, 0.7, 0.0)
			if not bullet.is_inside_tree():
				SceneSpawnService.spawn_child(bullet)

func apply_shadow_mode_effects() -> void:
	super.apply_shadow_mode_effects()
	if sprite_2d:
		sprite_2d.modulate = Color(0.3, 0.7, 1.0)

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	super.apply_super_mode_effects(multiplier_div, duration)
	if sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.7, 0.0)

func revert_shadow_mode_effects() -> void:
	super.revert_shadow_mode_effects()
	if GameManager.player_manager.player_stats.get("is_super_mode_active", false) and sprite_2d:
		sprite_2d.modulate = Color(1.0, 0.7, 0.0)
