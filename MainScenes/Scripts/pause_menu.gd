extends Control

@onready var restart_button: Button = $PanelContainer/Panel/VBoxContainer/HBoxContainer/RestartButton
@onready var back: Button = $PanelContainer/Panel/VBoxContainer/HBoxContainer/Back
@onready var resume: Button = $PanelContainer/Panel/VBoxContainer/HBoxContainer/Resume
@onready var waves: Label = $PanelContainer/Panel/VBoxContainer/Waves
@onready var total_waves: Label = $PanelContainer/Panel/VBoxContainer/Total_waves
@onready var level: Label = $PanelContainer/Panel/VBoxContainer/Level

const Map="res://Map/map.tscn"


func _ready():
	# Listen for game state changes
	GameManager.connect("game_paused", Callable(self, "_on_game_paused"))
	GameManager.connect("game_over_triggered", Callable(self, "_on_game_over"))
	GameManager.wave_started.connect(_on_wave_started)
	var current_level = GameManager.get_current_level()
	if level:
		level.text = "Level: %d"%[current_level]
		
# ✅ Disable pause menu when Game Over happens
func _on_game_over():
	hide_pause_menu()  # Hide pause menu when Game Over occurs
	
func _on_wave_started(current_wave: int, total_wave_count: int):
	if waves:
		waves.text = "Wave: %d " % [current_wave]
	if total_waves:
		total_waves.text = "Total Waves: %d" % [total_wave_count]
		
# 🔹 Resume Button Pressed
func _on_resume_pressed() -> void:
	if GameManager.game_over:
		return  # ❌ Prevent resuming if game is over
	GameManager.is_paused = false
	hide_pause_menu()

# 🔹 Restart Button Pressed
func _on_restart_button_pressed() -> void:
	GameManager.is_paused = false
	GameManager.reset_game()
	GameManager.change_scene(Map)


# 🔹 Back Button Pressed
func _on_back_pressed() -> void:
	GameManager.is_paused = false
	GameManager.change_scene(Map)

# 🔹 Hide Pause Menu
func hide_pause_menu():
	visible = false

# 🔹 Show Pause Menu (Prevent if Game Over)
func show_pause_menu():
	if GameManager.game_over:
		return  # ❌ Prevent showing pause menu if game is over
	visible = true
	GameManager.is_paused = true

# 🔹 React to GameManager’s Pause Signal
func _on_game_paused(_paused: bool):
	if GameManager.game_over:
		return  # ❌ Don't allow pause menu if the game is over
