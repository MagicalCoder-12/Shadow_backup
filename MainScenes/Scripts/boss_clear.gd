extends Control

@onready var scoreLabel := $Panel/VBoxContainer/Score
@onready var void_shard_label: Label = $Panel/VBoxContainer/RewardsContainer/VoidShardsReward/VoidShardLabel
@onready var coin_label: Label = $Panel/VBoxContainer/RewardsContainer/CoinsReward/CoinLabel
@onready var crystal_label: Label = $Panel/VBoxContainer/RewardsContainer/CrystalsReward/CrystalLabel
@onready var total_rewards_label: Label = $Panel/VBoxContainer/TotalRewards
// Removed count_up_timer as it's no longer needed
// @onready var count_up_timer: Timer = $CountUpTimer

const Map = "res://Map/map.tscn"

// Boss clear rewards - these are the special rewards for defeating bosses
const BOSS_VOID_SHARDS_REWARD: int = 10
const BOSS_COINS_REWARD: int = 1000
const BOSS_CRYSTALS_REWARD: int = 50

var current_level: int
// Removed is_animating as it's no longer needed
// var is_animating: bool = false
var debug: bool = true  # Enable or disable debug logging
var signals_connected: bool = false

// Add a method to initialize the screen when it's actually shown
func initialize():
	print("[BossClear Debug] initialize() called")
	if not signals_connected:
		// Connect signals from GameManager 
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
	
	// Initialize display
	print("[BossClear Debug] Setting initial score display")
	set_score(GameManager.score if GameManager else 0)
	get_tree().get_root().connect("go_back_requested", _on_map_pressed)
	
	// Show boss rewards immediately
	_show_boss_rewards()
	// Apply boss rewards when the screen is shown
	_apply_boss_rewards()
	
	if debug:
		print("[BossClear Debug] Boss clear screen ready for level %d, score: %d" % [current_level, GameManager.score if GameManager else 0])
	
	// Make sure the screen is visible
	show()
	print("[BossClear Debug] Boss clear screen shown")

func _ready():
	// Auto-initialize when the node is ready, but only if not already initialized
	print("[BossClear Debug] _ready() called")
	if not signals_connected:
		print("[BossClear Debug] _ready() called, auto-initializing")
		initialize()
	else:
		print("[BossClear Debug] _ready() called, already initialized")

func set_score(value: int) -> void:
	// Update the score label
	print("[BossClear Debug] set_score called with value: %d" % value)
	if scoreLabel:
		scoreLabel.text = "Level Score: %d" % value
		print("[BossClear Debug] scoreLabel.text set to: %s" % scoreLabel.text)
	else:
		print("[BossClear Debug] ERROR: scoreLabel is null!")

func _show_boss_rewards() -> void:
	// Display the rewards that will be given
	void_shard_label.text = "Void Shards: +%d" % BOSS_VOID_SHARDS_REWARD
	coin_label.text = "Coins: +%d" % BOSS_COINS_REWARD
	crystal_label.text = "Crystals: +%d" % BOSS_CRYSTALS_REWARD
	
	if debug:
		print("[BossClear Debug] Displaying boss rewards: %d void shards, %d coins, %d crystals" % [BOSS_VOID_SHARDS_REWARD, BOSS_COINS_REWARD, BOSS_CRYSTALS_REWARD])

func _apply_boss_rewards() -> void:
	if GameManager:
		// Check if this is the first time completing this boss level
		var boss_levels_completed = GameManager.save_manager.boss_levels_completed
		var is_first_time = not boss_levels_completed.has(current_level)
		
		if is_first_time:
			print("[BossClear Debug] First time completing boss level %d, applying rewards" % current_level)
			// Add the special boss rewards only for first time
			GameManager.add_currency("void_shards", BOSS_VOID_SHARDS_REWARD)
			GameManager.add_currency("coins", BOSS_COINS_REWARD)
			GameManager.add_currency("crystals", BOSS_CRYSTALS_REWARD)
			
			// Mark this boss level as completed
			boss_levels_completed.append(current_level)
			// SaveManager will handle saving the updated boss_levels_completed array
		else:
			print("[BossClear Debug] Boss level %d already completed before, no bonus rewards" % current_level)
			// Update the UI to show no rewards
			void_shard_label.text = "Void Shards: +0"
			coin_label.text = "Coins: +0"
			crystal_label.text = "Crystals: +0"
		
		// Also add any collected coins from the level (if any)
		var collected_coins = GameManager.coins_collected_this_level if GameManager else 0
		if collected_coins > 0:
			GameManager.add_currency("coins", collected_coins)
			if debug:
				print("[BossClear Debug] Added %d collected coins from level" % collected_coins)
		
		// Reset level collected coins
		GameManager.coins_collected_this_level = 0
		
		// Save progress
		if GameManager.save_manager and GameManager.save_manager.autosave_progress:
			GameManager.save_manager.save_progress()
		
		// Play reward sound effect
		_play_sound_effect("boss_victory")
		
		if debug:
			if is_first_time:
				print("[BossClear Debug] Applied boss rewards: %d void shards, %d coins, %d crystals" % [BOSS_VOID_SHARDS_REWARD, BOSS_COINS_REWARD, BOSS_CRYSTALS_REWARD])
			else:
				print("[BossClear Debug] No boss rewards applied for previously completed boss level")
			
		// Show total rewards applied message
		if total_rewards_label:
			if is_first_time:
				total_rewards_label.text = "Total Rewards Applied!"
			else:
				total_rewards_label.text = "Level Completed! (No bonus rewards)"
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
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[BossClear Debug] Next pressed during animation, waiting for completion")
	// 	return
	
	if GameManager and GameManager.level_manager:
		GameManager.level_manager.unlock_next_level(current_level)
		if debug:
			print("[BossClear Debug] Unlocking next level after boss level %d" % current_level)
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager or level_manager missing, can't unlock next level!")

func _on_map_pressed() -> void:
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[BossClear Debug] Map pressed during animation, waiting for completion")
	// 	return
	
	if GameManager:
		GameManager.change_scene(Map)
		if debug:
			print("[BossClear Debug] Warping to map scene after boss victory!")
	else:
		if debug:
			print("[BossClear Debug] Error: GameManager missing, can't warp to map!")

func _on_restart_pressed() -> void:
	// Removed is_animating check as it's no longer needed
	// if is_animating:
	// 	if debug:
	// 		print("[BossClear Debug] Restart pressed during animation, waiting for completion")
	// 	return
	
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