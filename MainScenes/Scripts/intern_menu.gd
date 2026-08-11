extends Control

const MAP = "res://Map/map.tscn"
const START = "res://MainScenes/start_menu.tscn"

@onready var wheel: Control = $Wheel

func _ready() -> void:
	get_tree().get_root().connect("go_back_requested", _on_back_button_down)
	call_deferred("_configure_campaign_entry")

func _configure_campaign_entry() -> void:
	TutorialManager.on_intern_menu_ready(self)
	if not TutorialManager.is_new_player_campaign_active():
		_show_wheel_popup()

func _show_wheel_popup() -> void:
	if not wheel:
		return
	if wheel.has_method("popup_open"):
		wheel.popup_open()
	else:
		wheel.show()

func _on_wheelbutton_pressed() -> void:
	_show_wheel_popup()


func _on_play_pressed() -> void:
	if TutorialManager.should_route_to_level_zero():
		GameManager.load_level(0)
	else:
		GameManager.change_scene(MAP)

func _on_back_button_down() -> void:
	GameManager.change_scene(START)
