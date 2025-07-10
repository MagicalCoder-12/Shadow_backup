extends Node2D

const TARGET_SCENE = "res://Map/map.tscn"

@onready var exit_panel: PanelContainer = $ExitUI/Exit_panel

func _ready() -> void:
	exit_panel.visible = false
	exit_panel.modulate.a = 0.0  # Make it transparent initially
	get_tree().get_root().connect("go_back_requested",_on_exit_pressed)
	
func _on_start_button_pressed() -> void:
	GameManager.change_scene(TARGET_SCENE)

func _on_exit_pressed() -> void:
	exit_panel.visible = true
	var tween = create_tween()
	tween.tween_property(exit_panel, "modulate:a", 1.0, 0.3).from(0.0)

func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(exit_panel, "modulate:a", 0.0, 0.3).from(1.0)
	tween.tween_callback(Callable(self, "_hide_exit_ui"))

func _hide_exit_ui() -> void:
	exit_panel.visible = false

func _on_ok_pressed() -> void:
	get_tree().quit()
