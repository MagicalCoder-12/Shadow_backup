extends Control

const MAP = "res://Map/map.tscn"
const Credits = "res://MainScenes/credits.tscn"
@onready var exit_panel: Panel = $Exit_panel
var _exit_tween: Tween

func _ready() -> void:
	exit_panel.visible = false
	exit_panel.modulate.a = 0.0
	var root: Window = get_tree().get_root()
	if root and not root.is_connected("go_back_requested", _on_exit_pressed):
		root.connect("go_back_requested", _on_exit_pressed)

	
func _on_start_button_pressed() -> void:
	GameManager.change_scene(MAP)


func _on_exit_pressed() -> void:
	if _exit_tween:
		_exit_tween.kill()
	exit_panel.visible = true
	_exit_tween = create_tween()
	_exit_tween.tween_property(exit_panel, "modulate:a", 1.0, 0.3).from(0.0)
	

func _on_close_pressed() -> void:
	if _exit_tween:
		_exit_tween.kill()
	_exit_tween = create_tween()
	_exit_tween.tween_property(exit_panel, "modulate:a", 0.0, 0.3).from(1.0)
	_exit_tween.tween_callback(Callable(self, "_hide_exit_ui"))

func _hide_exit_ui() -> void:
	exit_panel.visible = false
	exit_panel.modulate.a = 0.0

func _on_ok_pressed() -> void:
	get_tree().quit()


func _on_info_pressed() -> void:
	GameManager.change_scene(Credits)
