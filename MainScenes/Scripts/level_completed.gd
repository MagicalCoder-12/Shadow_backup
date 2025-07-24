extends Control

@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var highScoreLabel := $Panel/VBoxContainer/HighScore

const Map = "res://Map/map.tscn"
var current_level 

func _ready():
	# Connect signals from GameManager to update score and high score dynamically
	GameManager.connect_score_signals(self)
	# Initialize high score from GameManager
	set_high_score(GameManager.high_score)
	current_level = GameManager.get_current_level()
	get_tree().get_root().connect("go_back_requested",_on_map_pressed)
	
func set_score(value):
	# Update the score label
	scoreLabel.text = "Score: " + str(value)

func set_high_score(value):
	# Update the high score label
	highScoreLabel.text = "Hi-Score: " + str(value)

func _on_next_pressed() -> void:
	# Proceed to the next level or map
	GameManager.unlock_next_level(current_level)

func _on_map_pressed() -> void:
	GameManager.change_scene(Map)

func _on_restart_pressed() -> void:
	GameManager.is_paused = false
	GameManager.reset_game()
	
	var current_level_path = "res://Levels/level_%d.tscn" % current_level
	GameManager.change_scene(current_level_path)
