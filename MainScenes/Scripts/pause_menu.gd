extends Control

@onready var waves: Label = $PanelContainer/Panel/VBoxContainer/Waves
@onready var total_waves: Label = $PanelContainer/Panel/VBoxContainer/Total_waves
@onready var level: Label = $PanelContainer/Panel/VBoxContainer/Level

const Map = "res://Map/map.tscn"
var current_level

func _ready():
	# Listen for game state changes from the cosmic overlord
	if GameManager:
		GameManager.game_paused.connect(_on_game_paused)
		GameManager.game_over_triggered.connect(_on_game_over)
	else:
		_debug_log("Error: GameManager not found! Pause menu is lost in space.")
	
	# Connect to GameManager's wave_started signal
	if GameManager:
		GameManager.wave_started.connect(_on_wave_started)
	else:
		_debug_log("Warning: GameManager not found, cannot connect to wave_started!")
	
	current_level = GameManager.level_manager.get_current_level() if GameManager and GameManager.level_manager else 1
	if level:
		level.text = "Level: %d" % current_level
	else:
		_debug_log("Warning: Level label not found!")
	
	get_tree().get_root().connect("go_back_requested", _on_resume_pressed)
	_debug_log("Pause menu ready, locked and loaded for level %d" % current_level)

# ✅ Disable pause menu when Game Over happens
func _on_game_over():
	hide_pause_menu()
	_debug_log("Game over! Pause menu hiding faster than a cloaked ship.")

func _on_wave_started(current_wave: int, total_wave_count: int):
	if waves:
		waves.text = "Wave: %d" % current_wave
	if total_waves:
		total_waves.text = "Total Waves: %d" % total_wave_count
	_debug_log("Wave %d of %d started, updating HUD like a pro!" % [current_wave, total_wave_count])

# 🔹 Resume Button Pressed
func _on_resume_pressed() -> void:
	if GameManager and GameManager.game_over:
		_debug_log("Resume attempt blocked: Game over, no sneaking back in!")
		return
	GameManager.is_paused = false
	hide_pause_menu()
	_debug_log("Resuming game, pause menu blasting off!")

# 🔹 Hide Pause Menu
func hide_pause_menu():
	visible = false
	_debug_log("Pause menu hidden, back to the action!")

# 🔹 Show Pause Menu (Prevent if Game Over)
func show_pause_menu():
	if GameManager and GameManager.game_over:
		_debug_log("Can't show pause menu: Game over, captain!")
		return
	visible = true
	if GameManager:
		GameManager.is_paused = true
	_debug_log("Pause menu shown, time for a cosmic coffee break!")

# 🔹 React to GameManager’s Pause Signal
func _on_game_paused(_paused: bool):
	if GameManager and GameManager.game_over:
		_debug_log("Pause signal ignored: Game over, no pausing allowed!")
		return
	if _paused:
		show_pause_menu()
	else:
		hide_pause_menu()

func _on_map_pressed() -> void:
	if GameManager:
		GameManager.is_paused = false
		GameManager.change_scene(Map)
		_debug_log("Warping to map scene, hyperspace engaged!")
	else:
		_debug_log("Error: GameManager missing, can't warp to map!")

func _on_restart_pressed() -> void:
	if GameManager:
		GameManager.is_paused = false
		GameManager.reset_game()
		var current_level_path = "res://Levels/level_%d.tscn" % current_level
		GameManager.change_scene(current_level_path)
		_debug_log("Restarting level %d, time for a fresh space battle!" % current_level)
	else:
		_debug_log("Error: GameManager missing, can't restart level!")

# Logs debug messages if enabled in Player.gd
func _debug_log(message: String) -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player and player is Player and player.enable_debug_logging:
		print("[PauseMenu Debug] " + message)
