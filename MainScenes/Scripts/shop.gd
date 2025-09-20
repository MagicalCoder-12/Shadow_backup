extends Control

const Upgrade_shop = "res://MainScenes/upgrade_menu.tscn"

func _ready() -> void:
	get_tree().get_root().connect("go_back_requested",_on_back_pressed)

func _on_back_pressed() -> void:
	GameManager.change_scene(Upgrade_shop)
