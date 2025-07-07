extends Node2D

# The actual target scene you want to load after the loading screen
const TARGET_SCENE = "res://Map/map.tscn"  # Change to your target scene

func _on_start_pressed() -> void:
	GameManager.change_scene(TARGET_SCENE)
