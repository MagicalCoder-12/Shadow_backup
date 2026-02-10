extends Control


func _on_continue_button_pressed() -> void:
	# Remove the tutorial (and its CanvasLayer parent)
	get_parent().queue_free()
	
	# Properly complete the level and unlock the next level
	var current_level = GameManager.get_current_level()
	
	# Mark level 5 as completed if it's not already
	GameManager.mark_level_completed_if_needed(current_level)
	
	# Unlock next level (level 6)
	var next_level = current_level + 1
	GameManager.unlock_level_if_needed(next_level)
	
	# Save progress
	GameManager.save_progress_if_enabled()
	
	# Transition to the map scene to show the unlocked level
	GameManager.change_scene(GameManager.get_map_scene_path())
