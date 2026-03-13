extends RefCounted
class_name PlayerCombatService

func should_ignore_damage(revive_service, is_shadow_mode_active: bool) -> bool:
	if is_shadow_mode_active:
		return true
	if revive_service and revive_service.is_invincible():
		return true
	return false

func can_process_collision(is_alive: bool, revive_service) -> bool:
	return is_alive and not (revive_service and revive_service.just_revived)

func save_current_stats(game_manager) -> void:
	if not game_manager or not game_manager.player_manager:
		return
	game_manager.player_manager.save_player_stats(
		game_manager.player_manager.player_stats.get("attack_level", 0),
		game_manager.player_manager.player_stats.get("bullet_damage", game_manager.player_manager.default_bullet_damage),
		game_manager.player_manager.player_stats.get("base_bullet_damage", game_manager.player_manager.default_bullet_damage),
		game_manager.player_manager.player_stats.get("is_shadow_mode_active", false),
		game_manager.player_manager.player_stats.get("is_super_mode_active", false)
	)
	game_manager.player_manager.player_stats["is_super_mode_active"] = game_manager.player_manager.player_stats.get("is_super_mode_active", false)

func update_lives_after_damage(game_manager, current_lives: int, amount: int) -> int:
	var new_lives := maxi(0, current_lives - amount)
	if game_manager:
		game_manager.player_lives = new_lives
		game_manager.save_progress_if_enabled()
	return new_lives

func setup_damage_collision(collision_owner: Node) -> void:
	if collision_owner and collision_owner.has_method("set_collision_layer_value"):
		collision_owner.set_collision_layer_value(1, false)
		collision_owner.set_collision_layer_value(2, true)

func handle_survival(owner: Node, sprite: CanvasItem, collision_owner: Node) -> void:
	if sprite:
		sprite.visible = true
	if collision_owner and collision_owner.has_method("set_collision_layer_value"):
		collision_owner.set_collision_layer_value(1, true)
		collision_owner.set_collision_layer_value(2, false)
	if owner and owner.get_tree():
		var cam := owner.get_tree().current_scene.get_node_or_null("Cam") if owner.get_tree().current_scene else null
		if cam and cam.has_method("shake"):
			cam.shake(20)

func get_bullet_damage(bullet: Area2D) -> int:
	if not bullet:
		return 1
	if bullet.has_method("get_damage"):
		return int(bullet.get_damage())
	for property in bullet.get_property_list():
		if property.get("name", "") == "damage":
			return int(bullet.get("damage"))
	return 1

func apply_enemy_contact(enemy: Area2D, damage_callback: Callable) -> void:
	if damage_callback.is_valid():
		damage_callback.call(1)
	if enemy and enemy.has_method("damage"):
		enemy.damage(500)

func apply_bullet_hit(bullet: Area2D, damage_callback: Callable) -> int:
	var bullet_damage := get_bullet_damage(bullet)
	if damage_callback.is_valid():
		damage_callback.call(bullet_damage)
	if bullet and bullet.has_method("queue_free"):
		bullet.queue_free()
	return bullet_damage
