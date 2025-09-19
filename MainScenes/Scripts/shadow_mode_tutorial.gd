extends Control


func _on_continue_button_pressed() -> void:
	# Remove the tutorial (and its CanvasLayer parent)
	get_parent().queue_free()
	
	# Properly complete the level and unlock the next level
	var current_level = GameManager.level_manager.get_current_level()
	
	# Mark level 5 as completed if it's not already
	if not GameManager.level_manager.completed_levels.has(current_level):
		GameManager.level_manager.completed_levels.append(current_level)
		GameManager.level_star_earned.emit(current_level)
	
	# Unlock next level (level 6)
	var next_level = current_level + 1
	if next_level > GameManager.level_manager.unlocked_levels:
		GameManager.level_manager.unlocked_levels = next_level
		GameManager.level_unlocked.emit(next_level)
	
	# Save progress
	if GameManager.save_manager.autosave_progress:
		GameManager.save_manager.save_progress()
	
	# Transition to the map scene to show the unlocked level
	GameManager.change_scene(GameManager.scene_manager.MAP_SCENE)
