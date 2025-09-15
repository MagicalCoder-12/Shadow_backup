extends Control

@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var crystalsLabel := $Panel/VBoxContainer/Crystal_texture/Crystals
@onready var coins_label: Label = $Panel/VBoxContainer/Coin_texture/Coins

const Map = "res://Map/map.tscn"
var current_level: int
var collected_coins: int = 0
var collected_crystals: int = 0
var debug: bool = true  # Enable or disable debug logging
var signals_connected: bool = false

# Add a method to initialize the screen when it's actually shown
func initialize():
	if not signals_connected:
		# Connect score signals from GameManager and level completion
		if GameManager:
			if debug:
				print("[LevelCompleted Debug] GameManager found, connecting signals")
			
			# Check if signals are already connected before connecting
			if not GameManager.score_updated.is_connected(set_score):
				GameManager.score_updated.connect(set_score)
				if debug:
					print("[LevelCompleted Debug] Connected score_updated signal")
			else:
				if debug:
					print("[LevelCompleted Debug] score_updated signal already connected")
			
			# Connect level completed signal
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
	
	# Show current values
	if GameManager:
		set_score(GameManager.score)

func _ready():
	# Auto-initialize when the node is ready, but only if not already initialized
	if debug:
		print("[LevelCompleted Debug] _ready() called")
	if not signals_connected:
		if debug:
			print("[LevelCompleted Debug] _ready() called, auto-initializing")
		initialize()
	else:
		if debug:
			print("[LevelCompleted Debug] _ready() called, already initialized")
	
	# Make sure the screen is hidden by default
	hide()

func set_score(value: int) -> void:
	if debug:
		print("[LevelCompleted Debug] set_score called with value: %d" % value)
	# Update the score label
	if scoreLabel:
		scoreLabel.text = "Score: %d" % value
	else:
		if debug:
			print("[LevelCompleted Debug] scoreLabel is null!")

func set_currency(currency_type: String, value: int) -> void:
	if debug:
		print("[LevelCompleted Debug] set_currency called with type: %s, value: %d" % [currency_type, value])
	# Update the currency labels
	if currency_type == "coins":
		if coins_label:
			coins_label.text = "Coins: %d" % value
		else:
			if debug:
				print("[LevelCompleted Debug] coins_label is null!")
	elif currency_type == "crystals":
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
	
	# Get the collected coins and crystals for this level
	collected_coins = GameManager.coins_collected_this_level if GameManager else 0
	collected_crystals = GameManager.crystals_collected_this_level if GameManager else 0
	
	# Add level completion rewards based on level difficulty
	var level_completion_rewards = _calculate_level_completion_rewards(_level_num)
	collected_coins += level_completion_rewards.coins
	collected_crystals += level_completion_rewards.crystals
	
	# Show collected coins and crystals for this level
	if coins_label:
		coins_label.text = "Coins: %d" % collected_coins
		if debug:
			print("[LevelCompleted Debug] Set coins_label text to 'Coins: %d'" % collected_coins)
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: coins_label is null!")
			
	# Show collected crystals for this level
	if crystalsLabel:
		crystalsLabel.text = "Crystals: %d" % collected_crystals
		if debug:
			print("[LevelCompleted Debug] Set crystalsLabel text to 'Crystals: %d'" % collected_crystals)
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: crystalsLabel is null!")
	
	# Show initial score
	if scoreLabel:
		scoreLabel.text = "Score: %d" % (GameManager.score if GameManager else 0)
		if debug:
			print("[LevelCompleted Debug] Set scoreLabel text to 'Score: %d'" % (GameManager.score if GameManager else 0))
	else:
		if debug:
			print("[LevelCompleted Debug] ERROR: scoreLabel is null!")
	
	# Play sound effect when level completed screen is shown
	_play_sound_effect("level_completed")
	
	# Make sure the screen is visible
	show()
	if debug:
		print("[LevelCompleted Debug] Level completed screen shown")
	
	# Reset level currencies since they've been accounted for
	if GameManager:
		GameManager.reset_level_currencies()

func _calculate_level_completion_rewards(level_num: int) -> Dictionary:
	# Get reward configuration
	var reward_config = {}
	if ConfigLoader and ConfigLoader.upgrade_settings:
		reward_config = ConfigLoader.upgrade_settings
	
	# Default values if config not found
	var base_coins = reward_config.get("level_completion_base_coins", 200)
	var base_crystals = reward_config.get("level_completion_base_crystals", 10)
	
	# Calculate rewards based on level number with diminishing returns
	# Using square root to provide growth that slows over time
	var level_multiplier = pow(float(level_num), 0.75)
	
	return {
		"coins": int(base_coins * level_multiplier),
		"crystals": int(base_crystals * level_multiplier)
	}

func _play_sound_effect(sound_type: String) -> void:
	if AudioManager:
		var sound_stream: AudioStream
		if sound_type == "level_completed":
			# Use a different sound for level completion
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
	if GameManager and GameManager.level_manager:
		GameManager.level_manager.unlock_next_level(current_level)
		GameManager.score=0
		if debug:
			print("[LevelCompleted Debug] Unlocking next level after %d, onward and upward!" % current_level)
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager or level_manager missing, can't unlock next level!")

func _on_map_pressed() -> void:
	if debug:
		print("[LevelCompleted Debug] _on_map_pressed called")
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