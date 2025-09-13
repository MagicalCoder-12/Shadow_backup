extends Node

var gm: Node
var admob: Node
var is_initialized: bool = false
var is_reward_ad_pending: bool = false
var current_reward_type: String = ""
var selected_ad_type: String = ""
var is_ad_showing: bool = false
var ad_retry_count: int = 0
var max_ad_retries: int = 3
var revive_type: String = "none"
var is_revive_pending: bool = false
var revive_timeout_timer: Timer
@export var enable_debug_logging: bool = true  # Toggle for debug messages

func _ready() -> void:
	gm = GameManager
	# Defer initialization until all autoloads are ready
	call_deferred("initialize")

func initialize() -> void:
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


func request_ad_revive() -> void:
	_debug_log("Requesting ad revive")
	if not admob or not is_initialized:
		push_error("Cannot request ad revive: AdMob not initialized or missing.")
		gm.revive_completed.emit(false)
		_debug_log("Ad revive failed: Admob not initialized")
		return

	if is_ad_showing:
		print("Ad request ignored: Another ad is already showing.")
		gm.revive_completed.emit(false)
		_debug_log("Ad revive ignored: Another ad showing")
		return

	if gm.is_revive_pending:
		print("Ad request ignored: Revive already pending (GameManager).")
		gm.revive_completed.emit(false)
		_debug_log("Ad revive ignored: GameManager revive pending")
		return

	gm.is_revive_pending = true
	revive_type = "ad"
	is_revive_pending = true
	ad_retry_count = 0
	selected_ad_type = "video" if randf() < 0.5 else "interstitial"
	
	# Start timeout timer
	if revive_timeout_timer:
		revive_timeout_timer.start()
		_debug_log("Started revive timeout timer")

	_debug_log("Requesting %s ad for revive" % selected_ad_type)

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

func complete_ad_revive() -> void:
	_debug_log("complete_ad_revive called")
	if not gm.is_revive_pending:
		print("[DEBUG] AdManager: No revive pending in GameManager")
		_debug_log("No revive pending in GameManager")
		return
	
	# Stop timeout timer
	if revive_timeout_timer and revive_timeout_timer.time_left > 0:
		revive_timeout_timer.stop()
		_debug_log("Stopped revive timeout timer")

	is_ad_showing = false
	gm.is_revive_pending = false
	revive_type = "none"
	selected_ad_type = ""

	_debug_log("Calling GameManager.revive_player")
	gm.revive_player()
	gm.revive_completed.emit(true)
	is_revive_pending = false
	_debug_log("complete_ad_revive completed")

func reset_ad_state() -> void:
	is_ad_showing = false
	is_revive_pending = false
	is_reward_ad_pending = false
	current_reward_type = ""
	revive_type = "none"
	selected_ad_type = ""
	ad_retry_count = 0
	if is_initialized:
		admob.load_banner_ad()
	_debug_log("Ad state reset")

func show_banner_ad() -> void:
	if is_initialized:
		admob.show_banner_ad()
		_debug_log("Banner ad shown")

func hide_banner_ad() -> void:
	if is_initialized:
		admob.hide_banner_ad()
		_debug_log("Banner ad hidden")

func _on_admob_initialization_completed(_status_data: InitializationStatus) -> void:
	is_initialized = true
	admob.load_banner_ad()
	admob.load_rewarded_ad()
	admob.load_rewarded_interstitial_ad()
	_debug_log("Admob initialization completed, loading ads")

func _on_admob_banner_ad_loaded(_ad_id: String) -> void:
	_debug_log("Banner ad loaded")

func _on_admob_banner_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	var error_info = error_data.get("message", "Unknown error")
	var error_code = error_data.get("code", -1)
	print("Banner ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
	_debug_log("Banner ad failed to load: %s (Code: %s)" % [error_info, error_code])

	if ad_retry_count < max_ad_retries:
		ad_retry_count += 1
		await gm.get_tree().create_timer(5.0).timeout
		if is_initialized:
			admob.load_banner_ad()
			_debug_log("Retrying banner ad load (attempt %d)" % ad_retry_count)
	else:
		ad_retry_count = 0
		_debug_log("Max retries reached for banner ad")

func _on_admob_rewarded_ad_loaded(_ad_id: String) -> void:
	_debug_log("Rewarded video ad loaded")
	if is_revive_pending and selected_ad_type == "video" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_ad()
		_debug_log("Showing rewarded video ad after load")
	elif is_reward_ad_pending and selected_ad_type == "video" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_ad()
		_debug_log("Showing rewarded video ad for reward")

func _on_admob_rewarded_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	_debug_log("Rewarded video ad failed to load: %s" % error_data.get("message", "Unknown error"))
	if is_revive_pending and selected_ad_type == "video":
		gm.ad_failed_to_load.emit("video", error_data)
		if ad_retry_count < max_ad_retries:
			ad_retry_count += 1
			await gm.get_tree().create_timer(5.0).timeout
			if is_initialized:
				admob.load_rewarded_ad()
				_debug_log("Retrying rewarded video ad load (attempt %d)" % ad_retry_count)
		else:
			_fallback_to_map()
			_debug_log("Max retries reached for video ad, falling back to map")
	elif is_reward_ad_pending and selected_ad_type == "video":
		is_reward_ad_pending = false
		current_reward_type = ""
		gm.ad_failed_to_load.emit("video", error_data)
		_debug_log("Reward ad failed, resetting reward state")

func _on_admob_rewarded_ad_showed_full_screen_content(_ad_id: String) -> void:
	is_ad_showing = true
	_debug_log("Rewarded video ad shown")

func _on_admob_rewarded_ad_dismissed_full_screen_content(_ad_id: String) -> void:
	_debug_log("Rewarded video ad dismissed")
	if is_revive_pending and selected_ad_type == "video":
		# Only reset state on dismiss, actual revive happens on earned reward
		_debug_log("Video ad dismissed during revive - waiting for earned reward signal")
		# Add a safety fallback with a 3-second delay
		await gm.get_tree().create_timer(3.0).timeout
		if is_revive_pending:  # If still pending after 3 seconds, force complete
			_debug_log("No earned reward signal received, forcing revive completion")
			complete_ad_revive()
	else:
		is_ad_showing = false
		if is_initialized:
			admob.load_rewarded_ad()
		_debug_log("Reloading rewarded video ad")

func _on_admob_rewarded_ad_user_earned_reward(_ad_id: String, _reward_data) -> void:
	_debug_log("User earned reward for video ad")
	if is_revive_pending and selected_ad_type == "video":
		gm.ad_reward_granted.emit("video")
		complete_ad_revive()
	elif is_reward_ad_pending and selected_ad_type == "video":
		_grant_reward(current_reward_type)
		gm.ad_reward_granted.emit("video")
		is_reward_ad_pending = false
		current_reward_type = ""
		_debug_log("Granted reward: %s" % current_reward_type)

func _on_admob_rewarded_interstitial_ad_loaded(_ad_id: String) -> void:
	_debug_log("Rewarded interstitial ad loaded")
	if is_revive_pending and selected_ad_type == "interstitial" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_interstitial_ad()
		_debug_log("Showing rewarded interstitial ad after load")
	elif is_reward_ad_pending and selected_ad_type == "interstitial" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_interstitial_ad()
		_debug_log("Showing rewarded interstitial ad for reward")

func _on_admob_rewarded_interstitial_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	_debug_log("Rewarded interstitial ad failed to load: %s" % error_data.get("message", "Unknown error"))
	if is_revive_pending and selected_ad_type == "interstitial":
		gm.ad_failed_to_load.emit("interstitial", error_data)
		if ad_retry_count < max_ad_retries:
			ad_retry_count += 1
			await gm.get_tree().create_timer(5.0).timeout
			if is_initialized:
				admob.load_rewarded_interstitial_ad()
				_debug_log("Retrying rewarded interstitial ad load (attempt %d)" % ad_retry_count)
		else:
			_fallback_to_map()
			_debug_log("Max retries reached for interstitial ad, falling back to map")
	elif is_reward_ad_pending and selected_ad_type == "interstitial":
		is_reward_ad_pending = false
		current_reward_type = ""
		gm.ad_failed_to_load.emit("interstitial", error_data)
		_debug_log("Reward ad failed, resetting reward state")

func _on_admob_rewarded_interstitial_ad_showed_full_screen_content(_ad_id: String) -> void:
	is_ad_showing = true
	_debug_log("Rewarded interstitial ad shown")

func _on_admob_rewarded_interstitial_ad_dismissed_full_screen_content(_ad_id: String) -> void:
	_debug_log("Rewarded interstitial ad dismissed")
	if is_revive_pending and selected_ad_type == "interstitial":
		# Only reset state on dismiss, actual revive happens on earned reward
		_debug_log("Interstitial ad dismissed during revive - waiting for earned reward signal")
		# Add a safety fallback with a 3-second delay
		await gm.get_tree().create_timer(3.0).timeout
		if is_revive_pending:  # If still pending after 3 seconds, force complete
			_debug_log("No earned reward signal received, forcing revive completion")
			complete_ad_revive()
	else:
		is_ad_showing = false
		if is_initialized:
			admob.load_rewarded_interstitial_ad()
		_debug_log("Reloading rewarded interstitial ad")

func _on_admob_rewarded_interstitial_ad_user_earned_reward(_ad_id: String, _reward_data) -> void:
	_debug_log("User earned reward for interstitial ad")
	if is_revive_pending and selected_ad_type == "interstitial":
		gm.ad_reward_granted.emit("interstitial")
		complete_ad_revive()
	elif is_reward_ad_pending and selected_ad_type == "interstitial":
		_grant_reward(current_reward_type)
		gm.ad_reward_granted.emit("interstitial")
		is_reward_ad_pending = false
		current_reward_type = ""
		_debug_log("Granted reward: %s" % current_reward_type)

func _fallback_to_map() -> void:
	is_ad_showing = false
	is_revive_pending = false
	revive_type = "none"
	selected_ad_type = ""
	ad_retry_count = 0
	gm.revive_completed.emit(false)
	gm.change_scene(gm.scene_manager.MAP_SCENE)
	_debug_log("Falling back to map scene due to ad failure")

func _grant_reward(reward_type: String) -> void:
	var ad_crystal_reward = ConfigLoader.upgrade_settings.get("ad_crystal_reward", 10)
	var ad_ascend_reward = ConfigLoader.upgrade_settings.get("ad_ascend_reward", 5)
	var ad_coins_reward = ConfigLoader.upgrade_settings.get("ad_coins_reward", 5000)
	match reward_type:
		"crystals":
			gm.add_currency("crystals", ad_crystal_reward)
			gm.add_currency("void_shards", ad_ascend_reward)
			_debug_log("Granted %d crystals and %d void_shards" % [ad_crystal_reward, ad_ascend_reward])
		"coins":
			gm.add_currency("coins", ad_coins_reward)
			_debug_log("Granted %d coins" % ad_coins_reward)

func handle_node_added(_node: Node) -> void:
	pass  # Placeholder, not needed for static ReviveAdButton

func _on_revive_timeout() -> void:
	_debug_log("Revive timeout triggered - ad took too long to complete")
	if is_revive_pending:
		_debug_log("Forcing revive completion due to timeout")
		# Force complete the revive since the ad system seems stuck
		complete_ad_revive()
	else:
		_debug_log("Timeout triggered but no revive pending")
