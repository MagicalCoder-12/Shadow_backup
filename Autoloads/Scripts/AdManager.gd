extends Node

var gm: Node
var admob: Node
var is_initialized: bool = false
var is_reward_ad_pending: bool = false
var current_reward_type: String = ""
var selected_ad_type: String = ""
var is_ad_showing: bool = false
var max_ad_retries: int = 3
var revive_type: String = "none"
var ad_revive_pending: bool = false
var revive_timeout_timer: Timer
var is_banner_showing: bool = false
var enable_debug_logging: bool = true  # Toggle for debug messages
var _rewarded_ad_shown: bool = false  # Track if a rewarded ad has been shown
var _initialized: bool = false
var _banner_retry_count: int = 0
var _rewarded_retry_count: int = 0
var _reward_earned_for_current_ad: bool = false

# Helper function to check if game over screen is active
func is_game_over_screen_active() -> bool:
	# Allow banner ads on map screen
	if gm and gm.get_tree().current_scene:
		var scene_path = gm.get_tree().current_scene.scene_file_path
		if scene_path == "res://Map/map.tscn":
			return false
	
	# Prefer the level manager state when available
	if gm and gm.level_manager and gm.level_manager.is_game_over_screen_active:
		return true
	
	# Fallback to checking the scene tree for the GameOverScreen node
	if gm and gm.get_tree().current_scene:
		var game_over_screen = gm.get_tree().current_scene.find_child("GameOverScreen", true, false)
		if game_over_screen and game_over_screen.visible:
			return true
	
	return false

# Signals
@warning_ignore("unused_signal")
signal ad_reward_granted(ad_type: String)
@warning_ignore("unused_signal")
signal ad_failed_to_load(ad_type: String, error_data: Variant)

func _ready() -> void:
	gm = GameManager
	# Defer initialization until all autoloads are ready
	call_deferred("initialize")

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	if not gm:
		gm = GameManager
	admob = gm.get_node_or_null("Admob")
	if admob:
		# Wait a frame to ensure all autoloads are ready
		await gm.get_tree().process_frame
		# Connect all the Admob signals
		_connect_admob_signals()
		# Initialize the Admob node
		admob.initialize()
		_debug_log("Admob initialization called")
		# Add additional delay to allow plugin singleton to initialize
		await gm.get_tree().create_timer(1.0).timeout
		_check_initialization_status()
	else:
		push_error("Admob node not found in GameManager")
		_debug_log("Admob node not found in GameManager")
	
	# Initialize timeout timer
	revive_timeout_timer = Timer.new()
	revive_timeout_timer.wait_time = 30.0  # 30 second timeout
	revive_timeout_timer.one_shot = true
	revive_timeout_timer.timeout.connect(_on_revive_timeout)
	gm.add_child(revive_timeout_timer)
	
	if gm and gm.has_signal("scene_change_started"):
		if not gm.scene_change_started.is_connected(_on_scene_change_started):
			gm.scene_change_started.connect(_on_scene_change_started)
	
	# Apply banner policy for the current scene once we're initialized
	if gm and gm.get_tree().current_scene:
		var scene_path = gm.get_tree().current_scene.scene_file_path
		_apply_banner_policy_for_scene(scene_path if scene_path else "")

func _check_initialization_status() -> void:
	if not is_initialized:
		_debug_log("Warning: AdMob still not initialized after delay. Plugin singleton may not be available.")
		# Check if the plugin singleton exists
		if Engine.has_singleton("AdmobPlugin"):
			_debug_log("AdmobPlugin singleton found - initialization should proceed")
		else:
			_debug_log("AdmobPlugin singleton NOT found - plugin may not be loaded")
			push_error("AdmobPlugin singleton not found. Please ensure the AdMob plugin is properly enabled.")
	else:
		_debug_log("AdMob successfully initialized")

func _connect_admob_signals() -> void:
	if not admob:
		_debug_log("Cannot connect signals: Admob node is null")
		return
	
	_debug_log("Connecting Admob signals...")
	
	# Connect initialization signal
	if admob.has_signal("initialization_completed"):
		# Check if already connected before connecting
		if not admob.initialization_completed.is_connected(_on_admob_initialization_completed):
			admob.initialization_completed.connect(_on_admob_initialization_completed)
			_debug_log("Connected initialization_completed signal")
		else:
			_debug_log("initialization_completed signal already connected")
	else:
		_debug_log("Warning: initialization_completed signal not found")
	
	# Connect banner ad signals
	if admob.has_signal("banner_ad_loaded"):
		# Check if already connected before connecting
		if not admob.banner_ad_loaded.is_connected(_on_admob_banner_ad_loaded):
			admob.banner_ad_loaded.connect(_on_admob_banner_ad_loaded)
			_debug_log("Connected banner_ad_loaded signal")
		else:
			_debug_log("banner_ad_loaded signal already connected")
	if admob.has_signal("banner_ad_failed_to_load"):
		# Check if already connected before connecting
		if not admob.banner_ad_failed_to_load.is_connected(_on_admob_banner_ad_failed_to_load):
			admob.banner_ad_failed_to_load.connect(_on_admob_banner_ad_failed_to_load)
			_debug_log("Connected banner_ad_failed_to_load signal")
		else:
			_debug_log("banner_ad_failed_to_load signal already connected")
	
	# Connect rewarded ad signals
	if admob.has_signal("rewarded_ad_loaded"):
		# Check if already connected before connecting
		if not admob.rewarded_ad_loaded.is_connected(_on_admob_rewarded_ad_loaded):
			admob.rewarded_ad_loaded.connect(_on_admob_rewarded_ad_loaded)
			_debug_log("Connected rewarded_ad_loaded signal")
		else:
			_debug_log("rewarded_ad_loaded signal already connected")
	if admob.has_signal("rewarded_ad_failed_to_load"):
		# Check if already connected before connecting
		if not admob.rewarded_ad_failed_to_load.is_connected(_on_admob_rewarded_ad_failed_to_load):
			admob.rewarded_ad_failed_to_load.connect(_on_admob_rewarded_ad_failed_to_load)
		else:
			_debug_log("rewarded_ad_failed_to_load signal already connected")
	if admob.has_signal("rewarded_ad_showed_full_screen_content"):
		# Check if already connected before connecting
		if not admob.rewarded_ad_showed_full_screen_content.is_connected(_on_admob_rewarded_ad_showed_full_screen_content):
			admob.rewarded_ad_showed_full_screen_content.connect(_on_admob_rewarded_ad_showed_full_screen_content)
		else:
			_debug_log("rewarded_ad_showed_full_screen_content signal already connected")
	if admob.has_signal("rewarded_ad_dismissed_full_screen_content"):
		# Check if already connected before connecting
		if not admob.rewarded_ad_dismissed_full_screen_content.is_connected(_on_admob_rewarded_ad_dismissed_full_screen_content):
			admob.rewarded_ad_dismissed_full_screen_content.connect(_on_admob_rewarded_ad_dismissed_full_screen_content)
		else:
			_debug_log("rewarded_ad_dismissed_full_screen_content signal already connected")
	if admob.has_signal("rewarded_ad_user_earned_reward"):
		# Check if already connected before connecting
		if not admob.rewarded_ad_user_earned_reward.is_connected(_on_admob_rewarded_ad_user_earned_reward):
			admob.rewarded_ad_user_earned_reward.connect(_on_admob_rewarded_ad_user_earned_reward)
		else:
			_debug_log("rewarded_ad_user_earned_reward signal already connected")
	
	# Connect rewarded interstitial ad signals
	if admob.has_signal("rewarded_interstitial_ad_loaded"):
		# Check if already connected before connecting
		if not admob.rewarded_interstitial_ad_loaded.is_connected(_on_admob_rewarded_interstitial_ad_loaded):
			admob.rewarded_interstitial_ad_loaded.connect(_on_admob_rewarded_interstitial_ad_loaded)
		else:
			_debug_log("rewarded_interstitial_ad_loaded signal already connected")
	if admob.has_signal("rewarded_interstitial_ad_failed_to_load"):
		# Check if already connected before connecting
		if not admob.rewarded_interstitial_ad_failed_to_load.is_connected(_on_admob_rewarded_interstitial_ad_failed_to_load):
			admob.rewarded_interstitial_ad_failed_to_load.connect(_on_admob_rewarded_interstitial_ad_failed_to_load)
		else:
			_debug_log("rewarded_interstitial_ad_failed_to_load signal already connected")
	if admob.has_signal("rewarded_interstitial_ad_showed_full_screen_content"):
		# Check if already connected before connecting
		if not admob.rewarded_interstitial_ad_showed_full_screen_content.is_connected(_on_admob_rewarded_interstitial_ad_showed_full_screen_content):
			admob.rewarded_interstitial_ad_showed_full_screen_content.connect(_on_admob_rewarded_interstitial_ad_showed_full_screen_content)
		else:
			_debug_log("rewarded_interstitial_ad_showed_full_screen_content signal already connected")
	if admob.has_signal("rewarded_interstitial_ad_dismissed_full_screen_content"):
		# Check if already connected before connecting
		if not admob.rewarded_interstitial_ad_dismissed_full_screen_content.is_connected(_on_admob_rewarded_interstitial_ad_dismissed_full_screen_content):
			admob.rewarded_interstitial_ad_dismissed_full_screen_content.connect(_on_admob_rewarded_interstitial_ad_dismissed_full_screen_content)
		else:
			_debug_log("rewarded_interstitial_ad_dismissed_full_screen_content signal already connected")
	if admob.has_signal("rewarded_interstitial_ad_user_earned_reward"):
		# Check if already connected before connecting
		if not admob.rewarded_interstitial_ad_user_earned_reward.is_connected(_on_admob_rewarded_interstitial_ad_user_earned_reward):
			admob.rewarded_interstitial_ad_user_earned_reward.connect(_on_admob_rewarded_interstitial_ad_user_earned_reward)
		else:
			_debug_log("rewarded_interstitial_ad_user_earned_reward signal already connected")
	
	_debug_log("All available Admob signals processed")

func _debug_log(message: String) -> void:
	if enable_debug_logging:
		print("[AdManager Debug] " + message)

func _get_menu_scene_paths() -> Array[String]:
	if gm and gm.scene_manager:
		return [
			gm.scene_manager.START_SCREEN_SCENE,
			gm.scene_manager.MAP_SCENE,
			gm.scene_manager.UPGRADE_MENU
		]
	return [
		"res://MainScenes/start_menu.tscn",
		"res://Map/map.tscn",
		"res://MainScenes/upgrade_menu.tscn"
	]

func _should_show_banner_for_scene(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	for menu_scene in _get_menu_scene_paths():
		if scene_path == menu_scene:
			return true
	return false

func _apply_banner_policy_for_scene(scene_path: String) -> void:
	if _should_show_banner_for_scene(scene_path):
		show_banner_ad()
	else:
		if is_banner_showing:
			hide_banner_ad()

func _on_scene_change_started() -> void:
	if is_banner_showing:
		hide_banner_ad()

func _emit_ad_failed(ad_type: String, error_data: Variant) -> void:
	if gm:
		gm.ad_failed_to_load.emit(ad_type, error_data)
	emit_signal("ad_failed_to_load", ad_type, error_data)

func _refresh_banner_policy_for_current_scene() -> void:
	if not gm or not gm.get_tree().current_scene:
		return
	var scene_path = gm.get_tree().current_scene.scene_file_path
	_apply_banner_policy_for_scene(scene_path if scene_path else "")

func _stop_revive_timeout() -> void:
	if revive_timeout_timer and revive_timeout_timer.time_left > 0:
		revive_timeout_timer.stop()
		_debug_log("Stopped revive timeout timer")

func reset_revive_state(clear_game_manager_pending: bool = true) -> void:
	_stop_revive_timeout()
	if clear_game_manager_pending and gm:
		gm.request_revive_pending_clear("AdManager.reset_revive_state")
	ad_revive_pending = false
	revive_type = "none"
	selected_ad_type = ""
	is_ad_showing = false
	_rewarded_retry_count = 0
	_reward_earned_for_current_ad = false
	_rewarded_ad_shown = false
	_refresh_banner_policy_for_current_scene()

func _clear_reward_request_state() -> void:
	is_reward_ad_pending = false
	current_reward_type = ""
	selected_ad_type = ""
	is_ad_showing = false
	_rewarded_retry_count = 0
	_reward_earned_for_current_ad = false
	_rewarded_ad_shown = false
	_refresh_banner_policy_for_current_scene()

func _start_revive_timeout() -> void:
	if revive_timeout_timer:
		revive_timeout_timer.start()
		_debug_log("Started revive timeout timer")

func _request_selected_rewarded_ad() -> void:
	_reward_earned_for_current_ad = false
	if selected_ad_type == "video":
		if admob.is_rewarded_ad_loaded():
			is_ad_showing = true
			admob.show_rewarded_ad()
			_debug_log("Showing rewarded video ad")
		else:
			admob.load_rewarded_ad()
			_debug_log("Loading rewarded video ad")
	else:
		if admob.is_rewarded_interstitial_ad_loaded():
			is_ad_showing = true
			admob.show_rewarded_interstitial_ad()
			_debug_log("Showing rewarded interstitial ad")
		else:
			admob.load_rewarded_interstitial_ad()
			_debug_log("Loading rewarded interstitial ad")

func _begin_rewarded_request(for_revive: bool, reward_type: String = "") -> bool:
	if not admob or not is_initialized:
		var init_error := {"message": "AdMob not initialized"}
		if for_revive:
			if gm:
				gm.revive_completed.emit(false)
		else:
			_emit_ad_failed(reward_type, init_error)
		return false
	
	if is_ad_showing or ad_revive_pending or is_reward_ad_pending:
		var busy_error := {"message": "Another ad request is in progress"}
		if for_revive:
			if gm:
				gm.revive_completed.emit(false)
		else:
			_emit_ad_failed(reward_type, busy_error)
		return false
	
	if for_revive and gm and gm.is_revive_pending:
		gm.revive_completed.emit(false)
		return false
	
	_rewarded_retry_count = 0
	_rewarded_ad_shown = false
	selected_ad_type = "video" if randf() < 0.5 else "interstitial"
	
	if for_revive:
		if gm and not gm.is_revive_pending:
			gm.request_revive_pending_start("AdManager._begin_rewarded_request")
		ad_revive_pending = true
		revive_type = "ad"
		_start_revive_timeout()
		_debug_log("Requesting %s ad for revive" % selected_ad_type)
	else:
		is_reward_ad_pending = true
		current_reward_type = reward_type
		_debug_log("Requesting %s ad for reward: %s" % [selected_ad_type, reward_type])
	
	_request_selected_rewarded_ad()
	return true

func _handle_rewarded_load_failure(is_video: bool, error_data: Variant) -> void:
	var failed_type := "video" if is_video else "interstitial"
	_debug_log("Rewarded %s ad failed to load: %s" % [failed_type, error_data.get("message", "Unknown error")])
	
	if selected_ad_type != failed_type:
		return
	
	if _rewarded_retry_count < max_ad_retries:
		_rewarded_retry_count += 1
		await gm.get_tree().create_timer(5.0).timeout
		if not is_initialized:
			return
		if is_video:
			admob.load_rewarded_ad()
		else:
			admob.load_rewarded_interstitial_ad()
		_debug_log("Retrying rewarded %s ad load (attempt %d)" % [failed_type, _rewarded_retry_count])
		return
	
	if ad_revive_pending:
		_emit_ad_failed(failed_type, error_data)
		reset_revive_state()
		if gm:
			gm.revive_completed.emit(false)
	elif is_reward_ad_pending:
		var reward_type := current_reward_type
		_clear_reward_request_state()
		_emit_ad_failed(reward_type, error_data)

func _on_rewarded_ad_dismissed(is_video: bool) -> void:
	var dismissed_type := "video" if is_video else "interstitial"
	_debug_log("Rewarded %s ad dismissed" % dismissed_type)
	
	if selected_ad_type != dismissed_type:
		return
	
	is_ad_showing = false
	if is_video:
		if is_initialized:
			admob.load_rewarded_ad()
			_debug_log("Reloading rewarded video ad")
	else:
		if is_initialized:
			admob.load_rewarded_interstitial_ad()
			_debug_log("Reloading rewarded interstitial ad")
	
	if ad_revive_pending:
		# Some providers may miss the earned callback; treat close as success fallback.
		await gm.get_tree().create_timer(1.0).timeout
		if ad_revive_pending and not _reward_earned_for_current_ad:
			_debug_log("No earned callback received, completing revive on dismiss fallback")
			if gm:
				gm.ad_reward_granted.emit(dismissed_type)
			complete_ad_revive()
		return
	
	if is_reward_ad_pending:
		if _reward_earned_for_current_ad:
			_clear_reward_request_state()
		else:
			var reward_type := current_reward_type
			_clear_reward_request_state()
			_emit_ad_failed(reward_type, {"message": "Ad closed before reward was earned"})


func request_ad_revive() -> bool:
	_debug_log("Requesting ad revive")
	return _begin_rewarded_request(true)

func complete_ad_revive() -> void:
	_debug_log("complete_ad_revive called")
	if not ad_revive_pending:
		return
	_reward_earned_for_current_ad = true
	reset_revive_state()
	if is_initialized:
		admob.load_rewarded_ad()
		admob.load_rewarded_interstitial_ad()
	if gm:
		gm.revive_completed.emit(true)
	_debug_log("complete_ad_revive completed")

func reset_ad_state() -> void:
	reset_revive_state()
	_clear_reward_request_state()
	_banner_retry_count = 0
	_rewarded_ad_shown = false  # Reset rewarded ad shown flag
	if is_initialized:
		admob.load_banner_ad()
		admob.load_rewarded_ad()
		admob.load_rewarded_interstitial_ad()
		# Don't automatically show banner on reset, wait for explicit show_banner_ad() calls
		# is_banner_showing = true
	_debug_log("Ad state reset")

func show_banner_ad() -> void:
	# Check if we should show banner ads (not after rewarded ads and not during game over)
	if is_banner_showing:
		return
	if is_initialized and not is_ad_showing and not ad_revive_pending and not _rewarded_ad_shown and not is_game_over_screen_active():
		admob.show_banner_ad()
		is_banner_showing = true
		_debug_log("Banner ad shown")
	elif is_initialized:
		_debug_log("Banner ad not shown: ad showing (%s), revive pending (%s), rewarded ad shown (%s), or game over screen active" % [str(is_ad_showing), str(ad_revive_pending), str(_rewarded_ad_shown)])

func hide_banner_ad() -> void:
	if not is_banner_showing:
		return
	if is_initialized:
		admob.hide_banner_ad()
		is_banner_showing = false
		_debug_log("Banner ad hidden")

func _on_admob_initialization_completed(_status_data: InitializationStatus) -> void:
	is_initialized = true
	admob.load_banner_ad()
	admob.load_rewarded_ad()
	admob.load_rewarded_interstitial_ad()
	# Don't automatically show banner on initialization, wait for explicit show_banner_ad() calls
	# is_banner_showing = true
	_debug_log("Admob initialization completed, loading ads")
	
	if gm and gm.get_tree().current_scene:
		var scene_path = gm.get_tree().current_scene.scene_file_path
		_apply_banner_policy_for_scene(scene_path if scene_path else "")

func _on_admob_banner_ad_loaded(_ad_id: String) -> void:
	_banner_retry_count = 0
	_debug_log("Banner ad loaded")

func _on_admob_banner_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	var error_info = error_data.get("message", "Unknown error")
	var error_code = error_data.get("code", -1)
	print("Banner ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
	_debug_log("Banner ad failed to load: %s (Code: %s)" % [error_info, error_code])

	if _banner_retry_count < max_ad_retries:
		_banner_retry_count += 1
		await gm.get_tree().create_timer(5.0).timeout
		if is_initialized:
			admob.load_banner_ad()
			_debug_log("Retrying banner ad load (attempt %d)" % _banner_retry_count)
	else:
		_banner_retry_count = 0
		_debug_log("Max retries reached for banner ad")

func _on_admob_rewarded_ad_loaded(_ad_id: String) -> void:
	_rewarded_retry_count = 0
	_debug_log("Rewarded video ad loaded")
	if ad_revive_pending and selected_ad_type == "video" and not is_ad_showing:
		is_ad_showing = true
		# Don't hide banner ad before showing rewarded ad - let them coexist
		admob.show_rewarded_ad()
		_debug_log("Showing rewarded video ad over banner ad after load")
	elif is_reward_ad_pending and selected_ad_type == "video" and not is_ad_showing:
		is_ad_showing = true
		# Don't hide banner ad before showing rewarded ad - let them coexist
		admob.show_rewarded_ad()
		_debug_log("Showing rewarded video ad over banner ad for reward")

func _on_admob_rewarded_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	await _handle_rewarded_load_failure(true, error_data)

func _on_admob_rewarded_ad_showed_full_screen_content(_ad_id: String) -> void:
	is_ad_showing = true
	_rewarded_ad_shown = true
	_debug_log("Rewarded video ad shown")

func _on_admob_rewarded_ad_dismissed_full_screen_content(_ad_id: String) -> void:
	await _on_rewarded_ad_dismissed(true)

func _on_admob_rewarded_ad_user_earned_reward(_ad_id: String, _reward_data) -> void:
	_debug_log("User earned reward for video ad")
	if ad_revive_pending and selected_ad_type == "video":
		gm.ad_reward_granted.emit("video")
		complete_ad_revive()
	elif is_reward_ad_pending and selected_ad_type == "video":
		_reward_earned_for_current_ad = true
		_grant_reward(current_reward_type)
		_debug_log("Granted reward for reward ad flow")

func _on_admob_rewarded_interstitial_ad_loaded(_ad_id: String) -> void:
	_rewarded_retry_count = 0
	_debug_log("Rewarded interstitial ad loaded")
	if ad_revive_pending and selected_ad_type == "interstitial" and not is_ad_showing:
		is_ad_showing = true
		# Don't hide banner ad before showing rewarded ad - let them coexist
		admob.show_rewarded_interstitial_ad()
		_debug_log("Showing rewarded interstitial ad over banner ad after load")
	elif is_reward_ad_pending and selected_ad_type == "interstitial" and not is_ad_showing:
		is_ad_showing = true
		# Don't hide banner ad before showing rewarded ad - let them coexist
		admob.show_rewarded_interstitial_ad()
		_debug_log("Showing rewarded interstitial ad over banner ad for reward")

func _on_admob_rewarded_interstitial_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	await _handle_rewarded_load_failure(false, error_data)

func _on_admob_rewarded_interstitial_ad_showed_full_screen_content(_ad_id: String) -> void:
	is_ad_showing = true
	_rewarded_ad_shown = true
	_debug_log("Rewarded interstitial ad shown")

func _on_admob_rewarded_interstitial_ad_dismissed_full_screen_content(_ad_id: String) -> void:
	await _on_rewarded_ad_dismissed(false)

func _on_admob_rewarded_interstitial_ad_user_earned_reward(_ad_id: String, _reward_data) -> void:
	_debug_log("User earned reward for interstitial ad")
	if ad_revive_pending and selected_ad_type == "interstitial":
		gm.ad_reward_granted.emit("interstitial")
		complete_ad_revive()
	elif is_reward_ad_pending and selected_ad_type == "interstitial":
		_reward_earned_for_current_ad = true
		_grant_reward(current_reward_type)
		_debug_log("Granted reward for reward ad flow")

func _grant_reward(reward_type: String) -> void:
	var ad_crystal_reward = gm.get_upgrade_setting("ad_crystal_reward", 15) if gm else 15
	var ad_ascend_reward = gm.get_upgrade_setting("ad_ascend_reward", 10) if gm else 10
	var ad_coins_reward = gm.get_upgrade_setting("ad_coins_reward", 5000) if gm else 5000
	
	# Also emit signal for UI updates
	match reward_type:
		"crystals":
			gm.add_currency("crystals", ad_crystal_reward)
			gm.add_currency("void_shards", ad_ascend_reward)
			_debug_log("Granted %d crystals and %d void_shards" % [ad_crystal_reward, ad_ascend_reward])
		"coins":
			gm.add_currency("coins", ad_coins_reward)
			_debug_log("Granted %d coins" % ad_coins_reward)
	
	# Emit the signal to notify that reward has been granted
	emit_signal("ad_reward_granted", reward_type)
	gm.ad_reward_granted.emit(reward_type)

func handle_node_added(_node: Node) -> void:
	if not gm or not _node:
		return
	if _node != gm.get_tree().current_scene:
		return
	var scene_path = _node.scene_file_path if _node.scene_file_path else ""
	_apply_banner_policy_for_scene(scene_path)

func _on_revive_timeout() -> void:
	_debug_log("Revive timeout triggered - ad took too long to complete")
	if ad_revive_pending:
		_debug_log("Revive timeout reached; failing revive request")
		if gm:
			_emit_ad_failed("revive", {"message": "Revive ad timed out"})
		reset_revive_state()
		if gm:
			gm.revive_completed.emit(false)
	else:
		_debug_log("Timeout triggered but no revive pending")

# New function to request reward ads
func request_reward_ad(reward_type: String) -> void:
	_debug_log("Requesting reward ad for: %s" % reward_type)
	if reward_type != "crystals" and reward_type != "coins":
		_emit_ad_failed(reward_type, {"message": "Unsupported reward type"})
		return
	_begin_rewarded_request(false, reward_type)
