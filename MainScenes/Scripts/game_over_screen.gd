extends Control

# Onready references
@onready var score_label: Label = $Panel/Score
@onready var high_score_label: Label = $Panel/HighScore
@onready var revive_button: Button = $Panel/Revive
@onready var message_label: Label = $Panel/MessageLabel  # Add a Label node in the scene for feedback

# Constants
const START_SCREEN_SCENE: String = "res://Scenes/Music/StartScreen.tscn"
const MAP_SCENE: String = "res://Map/map.tscn"

# Signals
signal player_revived
signal ad_revive_requested

func _ready() -> void:
	# Connect GameManager signals
	GameManager.connect("game_over_triggered", Callable(self, "_on_game_over_triggered"))
	GameManager.connect("score_updated", Callable(self, "_on_score_updated"))
	GameManager.connect("high_score_updated", Callable(self, "_on_high_score_updated"))
	GameManager.connect("ad_reward_granted", Callable(self, "_on_ad_reward_granted"))
	GameManager.connect("ad_failed_to_load", Callable(self, "_on_ad_failed"))
	GameManager.connect("revive_completed", Callable(self, "_on_revive_completed"))
	
	set_process_input(true)
	revive_button.disabled = false
	_on_score_updated(GameManager.score)
	_on_high_score_updated(GameManager.high_score)
	message_label.visible = false
	print("GameOverScreen powered up, signals locked in like a starship! 🌟")

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
	message_label.visible = false

func _on_revive_pressed() -> void:
	if revive_button.disabled or GameManager.is_revive_pending:
		print("Revive button press ignored: Button disabled or revive in progress")
		return
	revive_button.disabled = true
	emit_signal("ad_revive_requested")
	print("Revive button pressed, requesting ad revive! Beam us up! 🖖")

func _on_ad_reward_granted(_ad_type: String) -> void:
	revive_button.disabled = true
	emit_signal("player_revived")
	visible = false
	message_label.visible = false
	if GameManager.game_over:
		push_warning("Game over still true after ad revive! Forcing to false.")
		GameManager.game_over = false
	print("Ad reward granted, GameOverScreen hidden, player revived like a cosmic phoenix!")

func _on_ad_failed(_ad_type: String, _error_code: Variant) -> void:
	revive_button.disabled = false
	message_label.text = "Ad failed to load. Try again, space cowboy!"
	message_label.visible = true
	await get_tree().create_timer(3.0).timeout
	message_label.visible = false
	print("Ad failed, revive button re-enabled, showing error message")

func _on_revive_completed(success: bool) -> void:
	if success:
		if GameManager.game_over:
			push_warning("Game over still true after successful revive! Forcing to false.")
			GameManager.game_over = false
		visible = false
		message_label.visible = false
		print("Revive completed successfully! Player’s back in the galaxy, game_over: %s" % GameManager.game_over)
	else:
		revive_button.disabled = false
		message_label.text = "Revive failed. Try again or restart, star pilot!"
		message_label.visible = true
		await get_tree().create_timer(3.0).timeout
		message_label.visible = false
		print("Revive failed, showing error message and re-enabling revive button")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if revive_button.disabled or GameManager.is_revive_pending:
			print("R key press ignored: Revive button disabled or revive pending")
			return
		revive_button.disabled = true
		emit_signal("ad_revive_requested")
		print("R key pressed for debug revive! Requesting ad like a mad scientist! 🧪")
