extends Control

# Onready references
@onready var score_label: Label =$Panel/Score
@onready var high_score_label: Label = $Panel/HighScore
@onready var revive_button: Button = $Panel/Revive  # Make sure this node exists in the scene

# Constants
const START_SCREEN_SCENE: String = "res://Scenes/Music/StartScreen.tscn"
const MAP_SCENE: String = "res://Map/map.tscn"

# Signal
@warning_ignore("unused_signal")
signal player_revived

func _ready() -> void:
	GameManager.connect("game_over_triggered", Callable(self, "_on_game_over_triggered"))
	GameManager.connect("score_updated", Callable(self, "_on_score_updated"))
	GameManager.connect("high_score_updated", Callable(self, "_on_high_score_updated"))
	set_process_input(true)
	revive_button.disabled = false  # Ensure button is enabled initially
	_on_score_updated(GameManager.score)
	_on_high_score_updated(GameManager.high_score)

func _on_score_updated(value: int) -> void:
	score_label.text = "Score: %d" % value

func _on_high_score_updated(value: int) -> void:
	high_score_label.text = "High-Score: %d" % value

func _on_restart_button_pressed() -> void:
	GameManager.change_scene(MAP_SCENE)

func _on_back_pressed() -> void:
	GameManager.change_scene(START_SCREEN_SCENE)


func _on_game_over_triggered() -> void:
	revive_button.disabled = false
	visible = true
	print("GameOverScreen shown, revive button enabled")

func _on_revive_pressed() -> void:
	if revive_button.disabled:
		print("Revive button press ignored: Button is disabled")
		return
	revive_button.disabled = true
	GameManager.request_ad_revive()
	print("Revive button pressed, requesting ad")

func _on_ad_reward_granted(_ad_type: String) -> void:
	revive_button.disabled = true
	emit_signal("player_revived")
	visible = false
	print("GameOverScreen hidden after ad revive")

func _on_ad_failed(_ad_type: String, _error_code: Variant) -> void:
	revive_button.disabled = false
	print("Ad failed, revive button re-enabled")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			push_warning("Revive triggered via 'R' key press")
			AudioManager.mute_bus("Bullet", false)
			AudioManager.mute_bus("Explosion", false)
			GameManager.request_ad_revive()
