extends Control


func _on_continue_button_pressed() -> void:
	# Remove the tutorial (and its CanvasLayer parent)
	get_parent().queue_free()
	# Transition to the next level
	var current_level: int = GameManager.get_current_level()
	LevelManager.unlock_next_level(current_level)
