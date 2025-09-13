extends Control


func _on_continue_button_pressed() -> void:
	# Remove the tutorial (and its CanvasLayer parent)
	get_parent().queue_free()
	# Transition to the next level
	hide()
