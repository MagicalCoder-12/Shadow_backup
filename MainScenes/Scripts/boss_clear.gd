extends Control

# Onready references
@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var void_shard_label: Label = $Panel/VBoxContainer/RewardsContainer/VoidShardsReward/VoidShardLabel
@onready var coin_label: Label = $Panel/VBoxContainer/RewardsContainer/CoinsReward/CoinLabel
@onready var crystal_label: Label = $Panel/VBoxContainer/RewardsContainer/CrystalsReward/CrystalLabel
@onready var total_rewards_label: Label = $Panel/VBoxContainer/TotalRewards

# Constants
const Map = "res://Map/map.tscn"

# Boss clear rewards - these will be calculated based on level
var current_level: int
var debug: bool = false  # Enable or disable debug logging
var signals_connected: bool = false
var screen_shown: bool = false  # Track if the screen has been shown

# Add a method to initialize the screen when it's actually shown
func initialize():
	print("[BossClear Debug] initialize() called")
	if not signals_connected:
		# Connect signals from GameManager 
		if GameManager:
			print("[BossClear Debug] GameManager found, connecting signals")
			if not GameManager.score_updated.is_connected(set_score):
				GameManager.score_updated.connect(set_score)
				print("[BossClear Debug] Connected score_updated signal")
			else:
				print("[BossClear Debug] score_updated signal already connected")
				
			current_level = GameManager.level_manager.get_current_level() if GameManager.level_manager else 1
		else:
			push_error("Error: GameManager not found! Boss clear screen is adrift.")
			current_level = 1
		signals_connected = true
	
	# Initialize display
	print("[BossClear Debug] Setting initial score display")
	set_score(GameManager.score if GameManager else 0)
	
	# Show boss rewards immediately
	_show_boss_rewards()
	
	if debug:
		print("[BossClear Debug] Boss clear screen ready for level %d, score: %d" % [current_level, GameManager.score if GameManager else 0])
	
	# Make sure the screen is hidden by default
	hide()

func _ready():
	# Auto-initialize when the node is ready, but only if not already initialized
	print("[BossClear Debug] _ready() called")
	if not signals_connected:
		print("[BossClear Debug] _ready() called, auto-initializing")
		initialize()
	else:
		print("[BossClear Debug] _ready() called, already initialized")

func set_score(value: int) -> void:
	# Update the score label
	if debug:
		print("[BossClear Debug] set_score called with value: %d" % value)
	if scoreLabel:
		scoreLabel.text = "Level Score: %d" % value
		if debug:
			print("[BossClear Debug] scoreLabel.text set to: %s" % scoreLabel.text)
	else:
		if debug:
			print("[BossClear Debug] ERROR: scoreLabel is null!")

func _show_boss_rewards() -> void:
	# Calculate rewards based on level
	var rewards = _calculate_boss_rewards()
	
	# Display the rewards that will be given
	if void_shard_label:
		void_shard_label.text = "Void Shards: +%d" % rewards.void_shards
	if coin_label:
		coin_label.text = "Coins: +%d" % rewards.coins
	if crystal_label:
		crystal_label.text = "Crystals: +%d" % rewards.crystals
	
	if debug:
		print("[BossClear Debug] Displaying boss rewards: %d void shards, %d coins, %d crystals" % [rewards.void_shards, rewards.coins, rewards.crystals])

func _calculate_boss_rewards() -> Dictionary:
	# Get reward configuration
	var boss_rewards_config = {}
	if ConfigLoader and ConfigLoader.upgrade_settings:
		boss_rewards_config = ConfigLoader.upgrade_settings.get("boss_level_rewards", {})
	
	# Default rewards if config not found
	var _default_rewards = {
		"coins": 1000,
		"crystals": 50,
		"void_shards": 10
	}
	
	# Check if we have specific rewards for this level
	if boss_rewards_config.has(str(current_level)):
		return boss_rewards_config[str(current_level)]
	
	# Calculate rewards based on level number (boss levels are 5, 10, 15, 20, etc.)
	@warning_ignore("integer_division")
	var level_multiplier = current_level / 5  # 1 for level 5, 2 for level 10, etc.
	
	return {
		"coins": int(1000 * level_multiplier),
		"crystals": int(50 * level_multiplier),
		"void_shards": int(10 * level_multiplier)
	}

func _apply_boss_rewards() -> void:
	if GameManager:
		# Calculate rewards
		var rewards = _calculate_boss_rewards()
		
		# Check if this is the first time completing this boss level
		var boss_levels_completed = GameManager.save_manager.boss_levels_completed
		var is_first_time = not boss_levels_completed.has(current_level)
		
		if is_first_time:
			print("[BossClear Debug] First time completing boss level %d, applying rewards" % current_level)
			# Add the special boss rewards only for first time
			GameManager.add_currency("void_shards", rewards.void_shards)
			GameManager.add_currency("coins", rewards.coins)
			GameManager.add_currency("crystals", rewards.crystals)
			
			# Mark this boss level as completed
			boss_levels_completed.append(current_level)
			# SaveManager will handle saving the updated boss_levels_completed array
		else:
			print("[BossClear Debug] Boss level %d already completed before" % current_level)
		
		# Also add any collected coins from the level (if any)
		var collected_coins = GameManager.coins_collected_this_level if GameManager else 0
		if collected_coins > 0:
			GameManager.add_currency("coins", collected_coins)
			if debug:
				print("[BossClear Debug] Added %d collected coins from level" % collected_coins)
		
		# Reset level collected coins
		GameManager.coins_collected_this_level = 0
		
		# Save progress
		if GameManager.save_manager and GameManager.save_manager.autosave_progress:
			GameManager.save_manager.save_progress()
		
		# Play reward sound effect
		_play_sound_effect("boss_victory")
		
		if debug:
			if is_first_time:
				print("[BossClear Debug] Applied boss rewards: %d void shards, %d coins, %d crystals" % [rewards.void_shards, rewards.coins, rewards.crystals])
			else:
				print("[BossClear Debug] No additional boss rewards for previously completed boss level")
			
		# Show total rewards applied message
		if total_rewards_label:
			if is_first_time:
				total_rewards_label.text = "Total Rewards Applied!"
			else:
				total_rewards_label.text = "Level Completed!"
			total_rewards_label.show()
			if debug:
				print("[BossClear Debug] Showing total rewards applied message")
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager not found, cannot apply boss rewards")

func _play_sound_effect(sound_type: String) -> void:
	if AudioManager:
		var sound_stream: AudioStream = preload("res://Textures/Music/794489__gobbe57__coin-pickup.wav")
		if sound_stream:
			AudioManager.play_sound_effect(sound_stream, "Master")  # Use Master bus
		else:
			if debug:
				print("[BossClear Debug] Warning: Sound stream for %s not found" % sound_type)
	else:
		if debug:
			print("[BossClear Debug] Warning: AudioManager not found, cannot play sound effect")

func _on_next_pressed() -> void:
	
	if GameManager and GameManager.level_manager:
		GameManager.level_manager.unlock_next_level(current_level)
		if debug:
			print("[BossClear Debug] Unlocking next level after boss level %d" % current_level)
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager or level_manager missing, can't unlock next level!")

func _on_map_pressed() -> void:
	if GameManager:
		GameManager.change_scene(Map)
		if debug:
			print("[BossClear Debug] Warping to map scene after boss victory!")
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager missing, can't warp to map!")

func _on_restart_pressed() -> void:
	if GameManager:
		GameManager.is_paused = false
		GameManager.reset_game()
		var current_level_path = "res://Levels/level_%d.tscn" % current_level
		GameManager.change_scene(current_level_path)
		if debug:
			print("[BossClear Debug] Restarting boss level %d" % current_level)
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager missing, can't restart level!")
