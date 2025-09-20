extends Control

# Onready references
@onready var score_label: Label = $PanelContainer/Panel/ScoreContainer/Score
@onready var message_label: Label = $PanelContainer/Panel/VBoxContainer/MessageLabel
@onready var revive_button: Button = $PanelContainer/Panel/HBoxContainer/Revive

# Constants
const MAP_SCENE: String = "res://Map/map.tscn"
var current_level

# Signals
@warning_ignore("unused_signal")
signal player_revived
@warning_ignore("unused_signal")
signal ad_revive_requested

func _ready() -> void:
	# Connect GameManager signals for game state and ads
	if GameManager:
		if not GameManager.game_over_triggered.is_connected(_on_game_over_triggered):
			GameManager.game_over_triggered.connect(_on_game_over_triggered)
			
		if not GameManager.score_updated.is_connected(_on_score_updated):
			GameManager.score_updated.connect(_on_score_updated)
			
		if not GameManager.revive_completed.is_connected(_on_revive_completed):
			GameManager.revive_completed.connect(_on_revive_completed)
			
		# Connect ad signals, with validation
		if GameManager.has_signal("ad_reward_granted"):
			if not GameManager.ad_reward_granted.is_connected(_on_ad_reward_granted):
				GameManager.ad_reward_granted.connect(_on_ad_reward_granted)
				
		if GameManager.has_signal("ad_failed_to_load"):
			if not GameManager.ad_failed_to_load.is_connected(_on_ad_failed):
				GameManager.ad_failed_to_load.connect(_on_ad_failed)
				
	else:
		_debug_log("Error: GameManager not found! Game over screen is lost in the void.")
	
	current_level = GameManager.level_manager.get_current_level() if GameManager and GameManager.level_manager else 1
	set_process_input(true)
	revive_button.disabled = false
	_on_score_updated(GameManager.score if GameManager else 0)
	message_label.visible = false
	get_tree().get_root().connect("go_back_requested", _on_map_pressed)
	_debug_log("GameOverScreen powered up for level %d, ready to revive or restart!" % current_level)
	
	# Make sure the screen is hidden by default
	hide()

func _on_score_updated(value: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % value

func _on_game_over_triggered() -> void:
	# Award half the collected coins and crystals when player dies
	_award_half_collected_currency()
	
	revive_button.disabled = false
	visible = true
	message_label.visible = false
	_debug_log("Game over triggered, showing screen of doom!")

# Award half the collected coins and crystals when player dies
func _award_half_collected_currency() -> void:
	if GameManager:
		# Calculate half of collected coins and crystals (rounded down)
		var half_coins = int(GameManager.coins_collected_this_level / 2)
		var half_crystals = int(GameManager.crystals_collected_this_level / 2)
		
		# Award the half amounts to the player's total
		if half_coins > 0:
			GameManager.add_currency("coins", half_coins)
			_debug_log("Awarded %d coins (half of %d collected)" % [half_coins, GameManager.coins_collected_this_level])
		
		if half_crystals > 0:
			GameManager.add_currency("crystals", half_crystals)
			_debug_log("Awarded %d crystals (half of %d collected)" % [half_crystals, GameManager.crystals_collected_this_level])
		
		# Reset the level currencies since we've awarded them
		GameManager.reset_level_currencies()

func _on_revive_pressed() -> void:
	if revive_button.disabled or (GameManager and GameManager.is_revive_pending):
		_debug_log("Revive button press ignored: Disabled or revive in progress")
		return
	revive_button.disabled = true
	# Request rewarded ad for revive
	if GameManager and GameManager.ad_manager:
		GameManager.ad_manager.request_ad_revive()
	else:
		emit_signal("ad_revive_requested") # fallback
		_debug_log("Revive button pressed, requesting ad revive! Beam us up, Scotty!")

func _on_ad_reward_granted(_ad_type: String) -> void:
	revive_button.disabled = true
	emit_signal("player_revived")
	visible = false
	message_label.visible = false
	if GameManager and GameManager.game_over:
		_debug_log("Warning: Game over still true after ad revive! Forcing to false.")
		GameManager.game_over = false
	_debug_log("Ad reward granted, player revived like a cosmic phoenix!")

func _on_ad_failed(_ad_type: String, _error_code: Variant) -> void:
	revive_button.disabled = false
	message_label.text = "Ad failed to load. Try again, space cowboy!"
	message_label.visible = true
	await get_tree().create_timer(3.0).timeout
	message_label.visible = false
	_debug_log("Ad failed, showing error message and re-enabling revive button")

func _on_revive_completed(success: bool) -> void:
	if success:
		if GameManager and GameManager.game_over:
			_debug_log("Warning: Game over still true after successful revive! Forcing to false.")
			GameManager.game_over = false
		visible = false
		message_label.visible = false
		_debug_log("Revive completed successfully! Player's back in the galaxy!")
	else:
		revive_button.disabled = false
		message_label.text = "Revive failed. Try again or restart, star pilot!"
		message_label.visible = true
		await get_tree().create_timer(3.0).timeout
		message_label.visible = false
		_debug_log("Revive failed, showing error message and re-enabling revive button")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if revive_button.disabled or (GameManager and GameManager.is_revive_pending):
			_debug_log("R key press ignored: Revive button disabled or revive pending")
			return
		revive_button.disabled = true
		# Use the same logic as the revive button
		if GameManager and GameManager.ad_manager:
			GameManager.ad_manager.request_ad_revive()
		else:
			emit_signal("ad_revive_requested") # fallback
		_debug_log("R key pressed for revive! Requesting ad like a mad scientist!")

func _on_map_pressed() -> void:
	if GameManager:
		GameManager.change_scene(MAP_SCENE)
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
		print("[GameOverScreen Debug] " + message)
