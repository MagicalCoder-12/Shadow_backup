extends Control

# Signal to notify GameManager when video ends or is skipped
signal finished

# Called when VideoStreamPlayer finishes playing
func _on_video_stream_player_finished() -> void:
	finished.emit()
	print("VideoStreamPlayer finished, emitting finished signal")

# Called when SkipButton is pressed
func _on_skip_button_pressed() -> void:
	finished.emit()
	print("SkipButton pressed, emitting finished signal")
