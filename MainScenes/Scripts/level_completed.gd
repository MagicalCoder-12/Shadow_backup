extends Control

@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var crystalsLabel := $Panel/VBoxContainer/Crystal_texture/Crystals
@onready var coins_label: Label = $Panel/VBoxContainer/Coin_texture/Coins
// Removed count_up_timer as it's no longer needed
// @onready var count_up_timer: Timer = $CountUpTimer

const Map = "res://Map/map.tscn"
// Removed animation constants as they're no longer needed
// const COIN_COUNT_UP_SPEED: float = 0.05  # Time per coin increment in seconds
// const SCORE_COIN_CONVERSION_RATE: float = 100.0  # 100 score points = 1 coin
// const DELAY_BETWEEN_ANIMATIONS: float = 1.0  # Delay between collected and score coin animations
var current_level: int
var collected_coins: int = 0
var collected_crystals: int = 0
// Removed coins_from_score and total_coins as they're no longer needed
// var coins_from_score: int = 0
// var total_coins: int = 0
// Removed is_animating as it's no longer needed
// var is_animating: bool = false
var debug: bool = true  # Enable or disable debug logging
var signals_connected: bool = false

// Add a method to initialize the screen when it's actually shown
func initialize():
	if debug:
		print("[LevelCompleted Debug] initialize() called")
	
	if not signals_connected:
		// Connect score signals from GameManager and level completion
		if GameManager:
			if debug:
				print("[LevelCompleted Debug] GameManager found, connecting signals")
			
			// Check if signals are already connected before connecting
			if not GameManager.score_updated.is_connected(set_score):
				GameManager.score_updated.connect(set_score)
				if debug:
					print("[LevelCompleted Debug] Connected score_updated signal")
			else:
				if debug:
					print("[LevelCompleted Debug] score_updated signal already connected")
			
			if not GameManager.currency_updated.is_connected(set_crystals):
				GameManager.currency_updated.connect(set_crystals)
				if debug:
					print("[LevelCompleted Debug] Connected currency_updated signal")
			else:
				if debug:
					print("[LevelCompleted Debug] currency_updated signal already connected")
			
			if not GameManager.level_completed.is_connected(_on_level_completed):
				GameManager.level_completed.connect(_on_level_completed)
				if debug:
					print("[LevelCompleted Debug] Connected level_completed signal")
			else:
				if debug:
					print("[LevelCompleted Debug] level_completed signal already connected")
			
			current_level = GameManager.level_manager.get_current_level() if GameManager.level_manager else 1
		else:
			push_error("Error: GameManager not found! Level completed screen is adrift.")
			current_level = 1
		signals_connected = true
	
	// Show current values
	if GameManager:
		set_score(GameManager.score)
		set_crystals("crystals", GameManager.crystal_count)
	
	get_tree().get_root().connect("go_back_requested", _on_map_pressed)
	if debug:
		print("[LevelCompleted Debug] Level completed screen ready for level %d, score: %d" % [current_level, GameManager.score if GameManager else 0])
	
	// Make sure the screen is hidden by default
	hide()

func _ready():
	// Auto-initialize when the node is ready, but only if not already initialized
	print("[LevelCompleted Debug] _ready() called")
	if not signals_connected:
		print("[LevelCompleted Debug] _ready() called, auto-initializing")
		initialize()
	else:
		print("[LevelCompleted Debug] _ready() called, already initialized")
	
	// Make sure the screen is hidden by default
	hide()

func set_score(value: int) -> void:
	if debug:
		print("[LevelCompleted Debug] set_score called with value: %d" % value)
	// Update the score label
	if scoreLabel:
		scoreLabel.text = "Score: %d" % value
	else:
		if debug:
			print("[LevelCompleted Debug] scoreLabel is null!")

func set_crystals(currency_type: String, value: int) -> void:
	if debug:
		print("[LevelCompleted Debug] set_crystals called with type: %s, value: %d" % [currency_type, value])
	// Update the crystals label when crystals are updated
	if currency_type == "crystals":
		if crystalsLabel:
			crystalsLabel.text = "Crystals: %d" % value
		else:
			if debug:
				print("[LevelCompleted Debug] crystalsLabel is null!")

func _on_level_completed(_level_num: int) -> void:
	if debug:
		print("[LevelCompleted Debug] _on_level_completed called with level: %d" % _level_num)
		print("[LevelCompleted Debug] GameManager exists: %s" % (GameManager != null))
		if GameManager:
			print("[LevelCompleted Debug] GameManager.score: %d" % GameManager.score)
			print("[LevelCompleted Debug] GameManager.coins_collected_this_level: %d" % (GameManager.coins_collected_this_level if GameManager else 0))
			print("[LevelCompleted Debug] GameManager.crystals_collected_this_level: %d" % (GameManager.crystals_collected_this_level if GameManager else 0))
	
	// Get the collected coins and crystals for this level
	collected_coins = GameManager.coins_collected_this_level if GameManager else 0
	collected_crystals = GameManager.crystals_collected_this_level if GameManager else 0
	// Removed coins_from_score calculation as it's no longer needed
	// coins_from_score = _calculate_coins_from_score()
	// total_coins = collected_coins + coins_from_score
	
	// Log initial coin counts
	if debug:
		print("[LevelCompleted Debug] Starting level completed: collected_coins=%d, collected_crystals=%d" % [collected_coins, collected_crystals])
		print("[LevelCompleted Debug] Checking UI elements:")
		print("[LevelCompleted Debug] scoreLabel exists: %s" % (scoreLabel != null))
		print("[LevelCompleted Debug] coins_label exists: %s" % (coins_label != null))
		print("[LevelCompleted Debug] crystalsLabel exists: %s" % (crystalsLabel != null))
	
	// Set labels directly without animation
	if coins_label:
		coins_label.text = "Coins: %d" % collected_coins
		if debug:
			print("[LevelCompleted Debug] Set coins_label text to 'Coins: %d'" % collected_coins)
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: coins_label is null!")
			
	// Show collected crystals for this level, not the total
	if crystalsLabel:
		crystalsLabel.text = "Crystals: %d" % collected_crystals
		if debug:
			print("[LevelCompleted Debug] Set crystalsLabel text to 'Crystals: %d'" % collected_crystals)
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: crystalsLabel is null!")
	
	// Show initial score
	if scoreLabel:
		scoreLabel.text = "Score: %d" % (GameManager.score if GameManager else 0)
		if debug:
			print("[LevelCompleted Debug] Set scoreLabel text to 'Score: %d'" % (GameManager.score if GameManager else 0))
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: scoreLabel is null!")
	
	// Play sound effect when level completed screen is shown
	_play_sound_effect("level_completed")
	
	// Make sure the screen is visible
	show()
	if debug:
		print("[LevelCompleted Debug] Level completed screen shown")

// Removed animation functions as they're no longer needed
// func _on_collected_coin_count_up() -> void:
// func _on_total_coins_count_up() -> void:
// func _on_safety_timeout() -> void:

// Removed _calculate_coins_from_score as it's no longer needed
// func _calculate_coins_from_score() -> int:

// Removed _update_total_coins as it's no longer needed
// func _update_total_coins() -> void:

func _play_sound_effect(sound_type: String) -> void:
	if AudioManager:
		var sound_stream: AudioStream
		if sound_type == "level_completed":
			// Use a different sound for level completion
			sound_stream = preload("res://Textures/Music/794489__gobbe57__coin-pickup.wav")
		else:
			sound_stream = preload("res://Textures/Music/794489__gobbe57__coin-pickup.wav")
			
		if sound_stream:
			AudioManager.play_sound_effect(sound_stream, "Master")  # Use Master bus
		else:
			if debug:
				print("[LevelCompleted Debug] Warning: Sound stream for %s not found" % sound_type)
	else:
		if debug:
			print("[LevelCompleted Debug] Warning: AudioManager not found, cannot play sound effect")

func _on_next_pressed() -> void:
	if debug:
		print("[LevelCompleted Debug] _on_next_pressed called")
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[LevelCompleted Debug] Next pressed during animation, waiting for completion")
	// 	return
	if GameManager and GameManager.level_manager:
		GameManager.level_manager.unlock_next_level(current_level)
		if debug:
			print("[LevelCompleted Debug] Unlocking next level after %d, onward and upward!" % current_level)
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager or level_manager missing, can't unlock next level!")

func _on_map_pressed() -> void:
	if debug:
		print("[LevelCompleted Debug] _on_map_pressed called")
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[LevelCompleted Debug] Map pressed during animation, waiting for completion")
	// 	return
	if GameManager:
		GameManager.change_scene(Map)
		if debug:
			print("[LevelCompleted Debug] Warping to map scene, hyperspace engaged!")
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager missing, can't warp to map!")

func _on_restart_pressed() -> void:
	if debug:
		print("[LevelCompleted Debug] _on_restart_pressed called")
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[LevelCompleted Debug] Restart pressed during animation, waiting for completion")
	// 	return
	if GameManager:
		GameManager.is_paused = false
		GameManager.reset_game()
		var current_level_path = "res://Levels/level_%d.tscn" % current_level
		GameManager.change_scene(current_level_path)
		if debug:
			print("[LevelCompleted Debug] Restarting level %d, time for a fresh space battle!" % current_level)
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager missing, can't restart level!")