extends Control

const Start_screen = "res://MainScenes/start_menu.tscn"

func _ready():
	get_tree().get_root().connect("go_back_requested",_on_back_pressed)
	
func _on_back_pressed() -> void:
	GameManager.change_scene(Start_screen)
