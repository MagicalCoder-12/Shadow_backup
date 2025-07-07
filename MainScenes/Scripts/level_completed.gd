extends Control

@onready var scoreLabel := $Panel/Score
@onready var highScoreLabel := $Panel/HighScore

const Map = "res://Map/map.tscn"

func _ready():
	# Connect signals from GameManager to update score and high score dynamically
	GameManager.connect_score_signals(self)
	# Initialize high score from GameManager
	set_high_score(GameManager.high_score)

func set_score(value):
	# Update the score label
	scoreLabel.text = "Score: " + str(value)

func set_high_score(value):
	# Update the high score label
	highScoreLabel.text = "Hi-Score: " + str(value)

func _on_back_pressed() -> void:
	# Go back to the start screen
	GameManager.change_scene(Map)

func _on_next_pressed() -> void:
	# Proceed to the next level or map
	var current_level = GameManager.get_current_level()
	GameManager.unlock_next_level(current_level)
