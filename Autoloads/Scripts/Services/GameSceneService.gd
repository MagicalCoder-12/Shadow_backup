extends RefCounted
class_name GameSceneService

# Centralized scene helpers used by GameManager.

func change_scene(scene_manager, scene_path: String) -> void:
	# Clear bullet pools before changing scenes to prevent memory leaks.
	BulletFactory.clear_pools()
	if scene_manager:
		scene_manager.change_scene(scene_path)

func load_level(level_manager, level_num: int) -> void:
	if level_manager:
		level_manager.load_level(level_num)

func get_current_level(level_manager) -> int:
	if level_manager:
		return int(level_manager.get_current_level())
	return 0

func get_map_scene_path(scene_manager) -> String:
	if scene_manager:
		return str(scene_manager.MAP_SCENE)
	return "res://Map/map.tscn"

func get_start_scene_path(scene_manager) -> String:
	if scene_manager:
		return str(scene_manager.START_SCREEN_SCENE)
	return "res://MainScenes/start_menu.tscn"

func set_level_game_over_screen_active(level_manager, active: bool) -> void:
	if level_manager:
		level_manager.is_game_over_screen_active = active
