extends Control

# Onready references
@onready var score_label: Label = $PanelContainer/Panel/ScoreContainer/Score
@onready var message_label: Label = $PanelContainer/Panel/VBoxContainer/MessageLabel
@onready var revive_button: Button = $PanelContainer/Panel/HBoxContainer/Revive

# Constants
const MAP_SCENE: String = "res://Map/map.tscn"
var current_level

# Signals
signal player_revived
@warning_ignore("unused_signal")
signal ad_revive_requested

func _ready() -> void:
	print("[GameOverScreen Debug] _ready() called")
	print("[GameOverScreen Debug] Checking UI elements:")
	print("[GameOverScreen Debug] score_label exists: %s" % (score_label != null))
	print("[GameOverScreen Debug] message_label exists: %s" % (message_label != null))
	print("[GameOverScreen Debug] revive_button exists: %s" % (revive_button != null))
	
	# Connect GameManager signals for game state and ads
	if GameManager:
		print("[GameOverScreen Debug] GameManager found, connecting signals")
		if not GameManager.game_over_triggered.is_connected(_on_game_over_triggered):
			GameManager.game_over_triggered.connect(_on_game_over_triggered)
			print("[GameOverScreen Debug] Connected game_over_triggered signal")
		else:
			print("[GameOverScreen Debug] game_over_triggered signal already connected")
			
		if not GameManager.score_updated.is_connected(_on_score_updated):
			GameManager.score_updated.connect(_on_score_updated)
			print("[GameOverScreen Debug] Connected score_updated signal")
		else:
			print("[GameOverScreen Debug] score_updated signal already connected")
			
		if not GameManager.revive_completed.is_connected(_on_revive_completed):
			GameManager.revive_completed.connect(_on_revive_completed)
			print("[GameOverScreen Debug] Connected revive_completed signal")
		else:
			print("[GameOverScreen Debug] revive_completed signal already connected")
			
		# Connect ad signals, with validation
		if GameManager.has_signal("ad_reward_granted"):
			if not GameManager.ad_reward_granted.is_connected(_on_ad_reward_granted):
				GameManager.ad_reward_granted.connect(_on_ad_reward_granted)
				print("[GameOverScreen Debug] Connected ad_reward_granted signal")
			else:
				print("[GameOverScreen Debug] ad_reward_granted signal already connected")
		else:
			_debug_log("Error: GameManager missing ad_reward_granted signal! Revive may not work.")
		if GameManager.has_signal("ad_failed_to_load"):
			if not GameManager.ad_failed_to_load.is_connected(_on_ad_failed):
				GameManager.ad_failed_to_load.connect(_on_ad_failed)
				print("[GameOverScreen Debug] Connected ad_failed_to_load signal")
			else:
				print("[GameOverScreen Debug] ad_failed_to_load signal already connected")
		else:
			_debug_log("Error: GameManager missing ad_failed_to_load signal! Revive may fail silently.")
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
	print("[GameOverScreen Debug] GameOverScreen hidden by default")

func _on_score_updated(value: int) -> void:
	print("[GameOverScreen Debug] _on_score_updated called with value: %d" % value)
	if score_label:
		score_label.text = "Score: %d" % value
		print("[GameOverScreen Debug] score_label.text set to: %s" % score_label.text)
	else:
		print("[GameOverScreen Debug] ERROR: score_label is null!")

func _on_game_over_triggered() -> void:
	print("[GameOverScreen Debug] _on_game_over_triggered called")
	revive_button.disabled = false
	visible = true
	message_label.visible = false
	_debug_log("Game over triggered, showing screen of doom!")
	print("[GameOverScreen Debug] GameOverScreen visibility set to: %s" % visible)

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
		_debug_log("Revive completed successfully! Player’s back in the galaxy!")
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
