extends Node


var gm: Node
var default_ship_id: String = "Ship1"
var selected_ship_id: String
var player_spawn_position: Vector2 = Vector2.ZERO
var default_bullet_speed: float = 3000.0
var default_bullet_damage: int = 20
var max_attack_level: int = 4
var player_stats: Dictionary

func _ready() -> void:
	gm = GameManager
	# Defer initialization until all autoloads are ready
	call_deferred("initialize")

func initialize() -> void:
	_load_settings_from_config()
	_initialize_player_stats()
	# Only set default ship ID if no ship ID was loaded from save data
	if selected_ship_id.is_empty():
		selected_ship_id = default_ship_id
	set_spawn_position()

func _load_settings_from_config() -> void:
	if ConfigLoader:
		default_bullet_speed = ConfigLoader.game_settings.get("default_bullet_speed", 3000.0)
		default_bullet_damage = ConfigLoader.game_settings.get("default_bullet_damage", 20)
		max_attack_level = ConfigLoader.game_settings.get("max_attack_level", 4)

	if not ConfigLoader.ships_data.is_empty():
		default_ship_id = ConfigLoader.ships_data[0].id
	else:
		push_error("Ships data is empty, cannot determine default ship ID.")
		default_ship_id = "Ship1"

func _initialize_player_stats() -> void:
	player_stats = {
		"attack_level": 0,
		"bullet_damage": default_bullet_damage,
		"base_bullet_damage": default_bullet_damage,
		"is_shadow_mode_active": false,
		"is_super_mode_active": false
	}

func save_player_stats(attack_level: int, bullet_damage: int, base_bullet_damage: int, is_shadow_mode_active: bool, is_super_mode_active: bool = false) -> void:
	player_stats["attack_level"] = attack_level
	player_stats["bullet_damage"] = bullet_damage
	player_stats["base_bullet_damage"] = base_bullet_damage
	player_stats["is_shadow_mode_active"] = is_shadow_mode_active
	player_stats["is_super_mode_active"] = is_super_mode_active

func restore_player_stats(player: Node) -> void:
	if not player or not player.has_method("set_stats"):
		push_error("Cannot restore stats: Invalid player node")
		return

	player.set_stats(
		player_stats["attack_level"],
		player_stats["bullet_damage"],
		player_stats["base_bullet_damage"],
		player_stats["is_shadow_mode_active"],
		false  # Always restore with super mode deactivated
	)
	
	# Ensure super mode is properly deactivated on revival
	player_stats["is_super_mode_active"] = false

func set_spawn_position() -> void:
	var viewport_size: Vector2 = gm.get_viewport().get_visible_rect().size
	player_spawn_position = Vector2(viewport_size.x / 2, viewport_size.y)

func spawn_player(lives: int) -> void:
	var current_scene = gm.get_tree().current_scene
	if not current_scene:
		return

	var player_scene_path = "res://Ships/Player_%s.tscn" % selected_ship_id
	if ResourceLoader.exists(player_scene_path):
		var player_scene = load(player_scene_path)
		var player_instance = player_scene.instantiate()
		player_instance.global_position = player_spawn_position
		current_scene.call_deferred("add_child", player_instance)
		player_instance.call_deferred("set_lives", lives)
	else:
		push_error("[DEBUG] Player scene not found at path: %s" % player_scene_path)

func revive_player(lives: int = 2) -> void:
	if not gm.ad_manager.is_revive_pending and gm.ad_manager.revive_type != "manual":
		gm.revive_completed.emit(false)
		return

	gm.game_over = false
	gm.is_paused = false
	gm.get_tree().paused = false

	gm.player_lives = lives
	gm.on_player_life_changed.emit(gm.player_lives)

	set_spawn_position()

	if gm.save_manager.autosave_progress:
		gm.save_manager.save_progress()

	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)

	var current_scene = gm.get_tree().current_scene
	var player_found = false

	if current_scene:
		_hide_game_over_screen(current_scene)

	for player in gm.get_tree().get_nodes_in_group("Player"):
		if player.ship_id == selected_ship_id:
			player.revive(lives)
			player_found = true
			break

	if not player_found:
		spawn_player(lives)

	gm.level_manager.is_game_over_screen_active = false

	if gm.ad_manager.is_initialized:
		gm.ad_manager.hide_banner_ad()


func _hide_game_over_screen(current_scene: Node) -> void:
	var found = false
	for child in current_scene.get_children():
		if child.name == "GameOverScreen":
			child.visible = false
			found = true
			break

	if not found:
		for child in current_scene.get_children():
			if child is CanvasLayer:
				for subchild in child.get_children():
					if subchild.name == "GameOverScreen":
						subchild.visible = false
						found = true
						break
				if found:
					break

	if not found:
		push_warning("GameOverScreen not found in current scene")

func reset_player_stats() -> void:
	player_stats = {
		"attack_level": 0,
		"bullet_damage": default_bullet_damage,
		"base_bullet_damage": default_bullet_damage,
		"is_shadow_mode_active": false,
		"is_super_mode_active": false
	}


# Update damage for the currently selected ship
func update_current_ship_damage(new_damage: int) -> void:
	player_stats["base_bullet_damage"] = new_damage
	# If not in shadow mode or super mode, also update current bullet damage
	if not player_stats.get("is_shadow_mode_active", false) and not player_stats.get("is_super_mode_active", false):
		player_stats["bullet_damage"] = new_damage
