extends Control

@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var crystalsLabel := $Panel/VBoxContainer/Crystal_texture/Crystals
@onready var coins_label: Label = $Panel/VBoxContainer/Coin_texture/Coins
@onready var count_up_timer: Timer = $CountUpTimer

const Map = "res://Map/map.tscn"
const COIN_COUNT_UP_SPEED: float = 0.05  # Time per coin increment in seconds
const SCORE_COIN_CONVERSION_RATE: float = 100.0  # 100 score points = 1 coin
const DELAY_BETWEEN_ANIMATIONS: float = 1.0  # Delay between collected and score coin animations
var current_level: int
var collected_coins: int = 0
var collected_crystals: int = 0
var coins_from_score: int = 0
var total_coins: int = 0
var is_animating: bool = false
var debug: bool = true  # Enable or disable debug logging
var signals_connected: bool = false

# Add a method to initialize the screen when it's actually shown
func initialize():
	if not signals_connected:
		# Connect score signals from GameManager and level completion
		if GameManager:
			GameManager.score_updated.connect(set_score)
			GameManager.currency_updated.connect(set_crystals)
			GameManager.level_completed.connect(_on_level_completed)
			current_level = GameManager.level_manager.get_current_level() if GameManager.level_manager else 1
		else:
			push_error("Error: GameManager not found! Level completed screen is adrift.")
			current_level = 1
		signals_connected = true
	
	set_crystals("crystals", GameManager.crystal_count if GameManager else 0)  # Show current crystals
	get_tree().get_root().connect("go_back_requested", _on_map_pressed)
	if debug:
		print("[LevelCompleted Debug] Level completed screen ready for level %d, score: %d" % [current_level, GameManager.score if GameManager else 0])

func set_score(value: int) -> void:
	# Update the score label
	scoreLabel.text = "Score: %d" % value

func set_crystals(currency_type: String, value: int) -> void:
	# Update the crystals label when crystals are updated
	if currency_type == "crystals":
		crystalsLabel.text = "Crystals: %d" % value

func _on_level_completed(_level_num: int) -> void:
	# Get the collected coins and crystals for this level
	collected_coins = GameManager.coins_collected_this_level if GameManager else 0
	collected_crystals = GameManager.crystals_collected_this_level if GameManager else 0
	coins_from_score = _calculate_coins_from_score()
	total_coins = collected_coins + coins_from_score
	
	# Log initial coin counts
	if debug:
		print("[LevelCompleted Debug] Starting level completed: collected_coins=%d, collected_crystals=%d, coins_from_score=%d, total_coins=%d" % [collected_coins, collected_crystals, coins_from_score, total_coins])
	
	# Initialize labels with animation
	coins_label.text = "Coins: 0"
	# Show collected crystals for this level, not the total
	crystalsLabel.text = "Crystals: %d" % collected_crystals
	
	# Disconnect any existing connections to prevent errors
	if count_up_timer.timeout.is_connected(_on_collected_coin_count_up):
		count_up_timer.timeout.disconnect(_on_collected_coin_count_up)
	if count_up_timer.timeout.is_connected(_on_total_coins_count_up):
		count_up_timer.timeout.disconnect(_on_total_coins_count_up)
	
	# Start animation for collected coins
	is_animating = true
	count_up_timer.wait_time = COIN_COUNT_UP_SPEED
	count_up_timer.timeout.connect(_on_collected_coin_count_up)
	count_up_timer.start()
	
	_play_sound_effect("coin_score")

func _calculate_coins_from_score() -> int:
	# Convert score to coins based on conversion rate
	if GameManager:
		var coins = int(GameManager.score / SCORE_COIN_CONVERSION_RATE)
		if debug:
			print("[LevelCompleted Debug] Score: %d, Coins from score: %d" % [GameManager.score, coins])
		return coins
	return 0

func _on_collected_coin_count_up() -> void:
	var current_value = int(coins_label.text.split(": ")[1])
	if current_value < collected_coins:
		current_value += 1
		coins_label.text = "Coins: %d" % current_value
	else:
		count_up_timer.stop()
		if count_up_timer.timeout.is_connected(_on_collected_coin_count_up):
			count_up_timer.timeout.disconnect(_on_collected_coin_count_up)
		
		# Delay before starting total coins animation
		await get_tree().create_timer(DELAY_BETWEEN_ANIMATIONS).timeout
		
		# Disconnect any existing connections before connecting new ones
		if count_up_timer.timeout.is_connected(_on_total_coins_count_up):
			count_up_timer.timeout.disconnect(_on_total_coins_count_up)
		
		# Start animation for total coins (collected coins + coins from score)
		count_up_timer.timeout.connect(_on_total_coins_count_up)
		count_up_timer.start()

func _on_total_coins_count_up() -> void:
	var current_value = int(coins_label.text.split(": ")[1])
	if current_value < total_coins:
		current_value += 1
		coins_label.text = "Coins: %d" % current_value
	else:
		count_up_timer.stop()
		if count_up_timer.timeout.is_connected(_on_total_coins_count_up):
			count_up_timer.timeout.disconnect(_on_total_coins_count_up)
		is_animating = false
		# Update the total coins in GameManager after animation completes
		_update_total_coins()

func _update_total_coins() -> void:
	if GameManager:
		# Add the coins from score to the GameManager
		GameManager.add_currency("coins", coins_from_score)
		GameManager.coins_collected_this_level = 0  # Reset for next level
		if GameManager.save_manager.autosave_progress:
			GameManager.save_manager.save_progress()
		if debug:
			print("[LevelCompleted Debug] Added %d coins from score (collected: %d, score: %d)" % [coins_from_score, collected_coins, coins_from_score])

func _play_sound_effect(sound_type: String) -> void:
	if AudioManager:
		var sound_stream: AudioStream = preload("res://Textures/Music/794489__gobbe57__coin-pickup.wav")
		if sound_stream:
			AudioManager.play_sound_effect(sound_stream, "Master")  # Use Master bus
		else:
			if debug:
				print("[LevelCompleted Debug] Warning: Sound stream for %s not found" % sound_type)
	else:
		if debug:
			print("[LevelCompleted Debug] Warning: AudioManager not found, cannot play sound effect")

func _on_next_pressed() -> void:
	if is_animating:
		if debug:
			print("[LevelCompleted Debug] Next pressed during animation, waiting for completion")
		return
	if GameManager and GameManager.level_manager:
		GameManager.level_manager.unlock_next_level(current_level)
		if debug:
			print("[LevelCompleted Debug] Unlocking next level after %d, onward and upward!" % current_level)
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager or level_manager missing, can't unlock next level!")

func _on_map_pressed() -> void:
	if is_animating:
		if debug:
			print("[LevelCompleted Debug] Map pressed during animation, waiting for completion")
		return
	if GameManager:
		GameManager.change_scene(Map)
		if debug:
			print("[LevelCompleted Debug] Warping to map scene, hyperspace engaged!")
	else:
		if debug:
			print("[LevelCompleted Debug] Error: GameManager missing, can't warp to map!")

func _on_restart_pressed() -> void:
	if is_animating:
		if debug:
			print("[LevelCompleted Debug] Restart pressed during animation, waiting for completion")
		return
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
