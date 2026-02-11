extends RefCounted
class_name GameProgressService

# Centralized progression/save-state helpers used by GameManager.

func has_level_state(level_manager) -> bool:
	return level_manager != null

func has_player_state(player_manager) -> bool:
	return player_manager != null

func can_persist_progress(level_manager, player_manager) -> bool:
	return has_level_state(level_manager) and has_player_state(player_manager)

func get_unlocked_levels_for_save(level_manager) -> int:
	if level_manager:
		return int(level_manager.unlocked_levels)
	return 1

func set_unlocked_levels_from_save(level_manager, value: Variant) -> void:
	if level_manager:
		level_manager.unlocked_levels = value

func get_shadow_mode_unlocked_for_save(shadow_mode_state) -> bool:
	if shadow_mode_state:
		return bool(shadow_mode_state.shadow_mode_unlocked)
	return false

func get_shadow_mode_tutorial_shown_for_save(shadow_mode_state) -> bool:
	if shadow_mode_state:
		return bool(shadow_mode_state.shadow_mode_tutorial_shown)
	return false

func get_completed_levels_for_save(level_manager) -> Array:
	if level_manager:
		return level_manager.completed_levels
	return []

func set_completed_levels_from_save(level_manager, value: Variant) -> void:
	if level_manager:
		level_manager.completed_levels = value

func get_selected_ship_id_for_save(player_manager) -> String:
	if player_manager:
		var selected_ship_id: String = str(player_manager.selected_ship_id)
		if not selected_ship_id.is_empty():
			return selected_ship_id
	return "Ship1"

func set_selected_ship_id_from_save(player_manager, value: Variant) -> void:
	if player_manager:
		player_manager.selected_ship_id = value

func reset_level_progress(level_manager) -> void:
	if level_manager:
		level_manager.reset_level_progress()

func is_boss_level_completed(save_manager, level_num: int) -> bool:
	return save_manager != null and save_manager.boss_levels_completed.has(level_num)

func mark_boss_level_completed(save_manager, level_num: int) -> bool:
	if not save_manager:
		return false
	if save_manager.boss_levels_completed.has(level_num):
		return false
	save_manager.boss_levels_completed.append(level_num)
	return true

func mark_level_completed_if_needed(level_manager, level_num: int) -> bool:
	if not level_manager:
		return false
	if level_manager.completed_levels.has(level_num):
		return false
	level_manager.completed_levels.append(level_num)
	return true

func unlock_level_if_needed(level_manager, level_num: int) -> bool:
	if not level_manager:
		return false
	if level_num > level_manager.unlocked_levels:
		level_manager.unlocked_levels = level_num
		return true
	return false
