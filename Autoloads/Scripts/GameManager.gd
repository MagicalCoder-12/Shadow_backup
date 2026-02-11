extends Node2D

# Revive state tracking
var is_revive_pending: bool = false
# Per-level revive usage counters used by ad/crystal revive limits.
var ad_revives_used_this_level: int = 0
var crystal_revives_used_this_level: int = 0

# Default revive economy settings (overridable from upgrade settings).
const DEFAULT_MAX_AD_REVIVES_PER_LEVEL: int = 1
const DEFAULT_MAX_CRYSTAL_REVIVES_PER_LEVEL: int = 2
const DEFAULT_CRYSTAL_REVIVE_BASE_COST: int = 10
const DEFAULT_CRYSTAL_REVIVE_COST_INCREMENT: int = 10
# 🔁 SIGNALS
@warning_ignore("unused_signal")
signal ad_reward_granted(ad_type: String)
signal currency_updated(currency_type: String, new_amount: int)
signal on_player_life_changed(life: int)
signal score_updated(new_score: int)
@warning_ignore("unused_signal")
signal game_over_triggered()
signal game_paused(paused: bool)
@warning_ignore("unused_signal")
signal scene_change_started()
@warning_ignore("unused_signal")
signal level_unlocked(new_level: int)
@warning_ignore("unused_signal")
signal wave_started(current_wave: int, total_waves: int)
@warning_ignore("unused_signal")
signal all_waves_cleared()
@warning_ignore("unused_signal")
signal level_completed(level_num: int)
@warning_ignore("unused_signal")
signal shadow_mode_activated
signal shadow_mode_deactivated
@warning_ignore("unused_signal")
signal level_star_earned(level_num: int)
@warning_ignore("unused_signal")
signal ad_failed_to_load(ad_type: String, error_code: Variant)
@warning_ignore("unused_signal")
signal revive_completed(success: bool)
@warning_ignore("unused_signal")
signal ship_stats_updated(ship_id: String, new_damage: int)
@warning_ignore("unused_signal")
signal satellite_stats_updated(satellite_id: String, new_damage_bonus: int)
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node)
@warning_ignore("unused_signal")
signal prepare_map_scene()
@warning_ignore("unused_signal")
signal player_manager_satellites_changed()

# 🔒 CONSTANTS
const GROUP_DAMAGEABLE: String = "damageable"
const GROUP_BOSS: String = "Boss"
const SUPER_MODE_SPAWN_COUNT: int = 25
const SAVE_VERSION: int = 1

# Ascension thresholds for ships (mirroring upgrade_settings.json)
const ASCENSION_THRESHOLDS: Dictionary = {
	"Ship1": [4, 8],
	"Ship2": [4, 8],
	"Ship3": [4, 8],
	"Ship4": [4, 8, 12, 16],
	"Ship5": [4, 8, 12, 16, 20, 24, 28, 32, 36, 40],
	"Ship6": [4, 8, 12, 16, 20, 24, 28, 32],
	"Ship7": [4, 8, 12, 16, 20, 24],
	"Ship8": [4, 8, 12, 16, 20, 24]
}

# Ascension thresholds for satellites (mirroring upgrade_settings.json)
const SATELLITE_ASCENSION_THRESHOLDS: Dictionary = {
	"Satellite1": [3, 6],
	"Satellite2": [3, 6],
	"Satellite3": [3, 6, 9],
	"Satellite4": [3, 6, 9],
	"Satellite5": [3, 6, 9, 12],
	"Satellite6": [3, 6, 9, 12, 15]
}

# Bullet constants for compatibility
const DEFAULT_BULLET_SPEED: float = 600.0
const DEFAULT_BULLET_DAMAGE: int = 10

# 🧠 MANAGERS - Now using autoload references
var save_manager: SaveManager
var ad_manager: AdManager
var scene_manager: SceneManager
var player_manager: PlayerManager
var level_manager: LevelManager

# 🔒 PERSISTENT GAME STATE
var _score: int = 0
var score: int:
	get: return _score
	set(value):
		if value != _score:
			_score = value
			score_updated.emit(_score)


var _player_lives: int = 3
var player_lives: int:
	get: return _player_lives
	set(value):
		_player_lives = max(0, value)
		on_player_life_changed.emit(_player_lives)
		# Removed saving per-level lives as it's not needed
		if _player_lives == 0 and not level_manager.is_level_just_completed:
			trigger_game_over()

var is_paused: bool = false:
	set(value):
		if value != is_paused:
			is_paused = value
			get_tree().paused = value
			game_paused.emit(value)

var game_over: bool = false
var game_ended: bool = false
var game_won: bool = false

# SHIP AND CURRENCY DATA
var ships: Array = []
var satellites: Array = []
var _crystal_count: int = 0
var crystal_count: int:
	get: return _crystal_count
	set(value):
		_crystal_count = max(0, value)
		currency_updated.emit("crystals", _crystal_count)
var _coin_count: int = 0
var coin_count: int:
	get: return _coin_count
	set(value):
		_coin_count = max(0, value)
		currency_updated.emit("coins", _coin_count)
var _void_shards_count: int = 0
var void_shards_count: int:
	get: return _void_shards_count
	set(value):
		_void_shards_count = max(0, value)
		currency_updated.emit("void_shards", _void_shards_count)

# UPGRADE MENU REFERENCE
@export var upgrade_menu_scene: PackedScene

var shadow_mode_timer: Timer = Timer.new()
var shadow_mode_state: ShadowModeState = ShadowModeState.new()

var level_currency_state: LevelCurrencyState = LevelCurrencyState.new()

func _ready() -> void:
	# Reference autoload managers instead of instantiating them
	save_manager = SaveManager
	ad_manager = AdManager
	scene_manager = SceneManager
	player_manager = PlayerManager
	level_manager = LevelManager

	# Wait for autoloads to initialize
	await get_tree().process_frame
	
	# Initialize other components
	player_manager.initialize()
	scene_manager.initialize()
	ad_manager.initialize()

	add_child(shadow_mode_timer)
	shadow_mode_timer.timeout.connect(_on_shadow_mode_timer_timeout)

	get_tree().node_added.connect(_on_node_added)

	# Connect prepare_map_scene signal
	if prepare_map_scene.is_connected(_on_prepare_map_scene):
		prepare_map_scene.disconnect(_on_prepare_map_scene)
	prepare_map_scene.connect(_on_prepare_map_scene)

# Connect revive_completed signal to resume game after ad
	if not revive_completed.is_connected(_on_revive_completed):
		revive_completed.connect(_on_revive_completed)

func _exit_tree() -> void:
	# Clean up the timer to prevent memory leaks
	if shadow_mode_timer and shadow_mode_timer.is_inside_tree():
		if shadow_mode_timer.timeout.is_connected(_on_shadow_mode_timer_timeout):
			shadow_mode_timer.timeout.disconnect(_on_shadow_mode_timer_timeout)
		shadow_mode_timer.stop()
		shadow_mode_timer.queue_free()
	
	# Disconnect node_added signal
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	
	# Disconnect prepare_map_scene signal
	if prepare_map_scene.is_connected(_on_prepare_map_scene):
		prepare_map_scene.disconnect(_on_prepare_map_scene)
	
	# Disconnect revive_completed signal
	if revive_completed.is_connected(_on_revive_completed):
		revive_completed.disconnect(_on_revive_completed)

func trigger_game_over() -> void:
	AudioManager.mute_bus("Bullet", true)
	AudioManager.mute_bus("Explosion", true)
	# Banner ad will be shown by AdManager when appropriate
	# if ad_manager.is_initialized:
	# 	ad_manager.show_banner_ad()
	game_over_triggered.emit()

func request_game_over(_source: String = "") -> void:
	game_over = true

func request_game_over_clear(_source: String = "") -> void:
	game_over = false

func request_revive_pending_start(_source: String = "") -> void:
	is_revive_pending = true

func request_revive_pending_clear(_source: String = "") -> void:
	is_revive_pending = false

# Called at run reset/new level start so revive limits do not carry across levels.
func reset_revive_limits_for_level() -> void:
	request_revive_pending_clear("GameManager.reset_revive_limits_for_level")
	ad_revives_used_this_level = 0
	crystal_revives_used_this_level = 0

# Read revive configuration through GameManager so callers use one source of truth.
func get_max_ad_revives_per_level() -> int:
	return max(0, int(get_upgrade_setting("max_ad_revives_per_level", DEFAULT_MAX_AD_REVIVES_PER_LEVEL)))

func get_max_crystal_revives_per_level() -> int:
	return max(0, int(get_upgrade_setting("max_crystal_revives_per_level", DEFAULT_MAX_CRYSTAL_REVIVES_PER_LEVEL)))

func get_ad_revives_remaining() -> int:
	return max(0, get_max_ad_revives_per_level() - ad_revives_used_this_level)

func get_crystal_revives_remaining() -> int:
	return max(0, get_max_crystal_revives_per_level() - crystal_revives_used_this_level)

func get_crystal_revive_cost() -> int:
	var base_cost: int = max(0, int(get_upgrade_setting("crystal_revive_base_cost", DEFAULT_CRYSTAL_REVIVE_BASE_COST)))
	var increment: int = max(0, int(get_upgrade_setting("crystal_revive_cost_increment", DEFAULT_CRYSTAL_REVIVE_COST_INCREMENT)))
	# Crystal revive price scales with each crystal revive used in the current level.
	return base_cost + (increment * crystal_revives_used_this_level)

# Revives are allowed only while game-over is active and no revive is already pending.
func can_use_ad_revive() -> bool:
	return game_over and not is_revive_pending and get_ad_revives_remaining() > 0

func can_use_crystal_revive() -> bool:
	return game_over and not is_revive_pending and get_crystal_revives_remaining() > 0

func mark_ad_revive_used() -> void:
	ad_revives_used_this_level = min(get_max_ad_revives_per_level(), ad_revives_used_this_level + 1)

# Deduct crystals and lock revive state atomically so UI/gameplay stay in sync.
func try_spend_crystal_revive() -> Dictionary:
	if not can_use_crystal_revive():
		return {
			"ok": false,
			"error": "Crystal revives are unavailable."
		}
	var cost: int = get_crystal_revive_cost()
	if not can_afford("crystals", cost):
		return {
			"ok": false,
			"error": "Not enough crystals.",
			"cost": cost
		}
	deduct_currency("crystals", cost)
	crystal_revives_used_this_level = min(get_max_crystal_revives_per_level(), crystal_revives_used_this_level + 1)
	request_revive_pending_start("GameManager.try_spend_crystal_revive")
	return {
		"ok": true,
		"cost": cost
	}

func set_shadow_mode_enabled(value: bool, _source: String = "") -> void:
	shadow_mode_state.shadow_mode_enabled = value

func set_shadow_mode_unlocked(value: bool, _source: String = "") -> void:
	shadow_mode_state.shadow_mode_unlocked = value

func set_shadow_mode_tutorial_shown(value: bool, _source: String = "") -> void:
	shadow_mode_state.shadow_mode_tutorial_shown = value

func request_shadow_mode_activate(duration: float = 2.0, _source: String = "") -> void:
	if level_manager and shadow_mode_state.shadow_mode_unlocked:
		shadow_mode_state.shadow_mode_enabled = true
		shadow_mode_state.shadow_mode_remaining_time = duration
		shadow_mode_activated.emit()
		shadow_mode_timer.start(duration)

func request_shadow_mode_deactivate(_source: String = "") -> void:
	if level_manager and shadow_mode_state.shadow_mode_enabled:
		shadow_mode_state.shadow_mode_enabled = false
		shadow_mode_state.shadow_mode_remaining_time = 0.0
		shadow_mode_deactivated.emit()

func request_shadow_mode_deactivate_silent(_source: String = "") -> void:
	if level_manager:
		shadow_mode_state.shadow_mode_enabled = false
		shadow_mode_state.shadow_mode_remaining_time = 0.0

func reset_game() -> void:
	score = 0
	player_lives = 3
	is_paused = false
	request_game_over_clear("reset_game")
	reset_revive_limits_for_level()
	game_ended = false
	game_won = false
	coins_collected_this_level = 0
	crystals_collected_this_level = 0
	
	# Reset all audio state to prevent BGM overlap
	AudioManager.reset_audio_state()
	
	# Reset state managers
	level_manager.reset_level_state()
	player_manager.reset_player_stats()
	player_manager.set_spawn_position()
	ad_manager.reset_ad_state()
	
	# Ensure game tree is unpaused
	get_tree().paused = false
	


# Reset score and lives for each level (per-level progression)
func reset_for_new_level() -> void:
	#var current_level = get_current_level()
	# Always reset score to 0 and lives to 3 for each level
	_score = 0
	_player_lives = 3
	reset_revive_limits_for_level()
	
	coins_collected_this_level = 0
	crystals_collected_this_level = 0
	score_updated.emit(_score)
	on_player_life_changed.emit(_player_lives)
	
	# Reset player stats to default values to ensure special modes don't carry over between levels
	if player_manager:
		player_manager.reset_player_stats()

func complete_level(current_level: int) -> void:
	level_manager.complete_level(current_level)

func complete_current_level() -> void:
	level_manager.complete_level(get_current_level())

func _on_shadow_mode_timer_timeout() -> void:
	request_shadow_mode_deactivate("_on_shadow_mode_timer_timeout")

func _on_node_added(node: Node) -> void:
	level_manager.handle_node_added(node)
	ad_manager.handle_node_added(node)
	scene_manager.handle_node_added(node)

func connect_score_signals(target_node: Node) -> void:
	if target_node.has_method("set_score"):
		score_updated.connect(target_node.set_score)

# Public API methods
func change_scene(scene_path: String) -> void:
	# Clear bullet pools before changing scenes to prevent memory leaks
	BulletFactory.clear_pools()
	scene_manager.change_scene(scene_path)

func load_level(level_num: int) -> void:
	level_manager.load_level(level_num)

func request_ad_revive() -> bool:
	# Return `false` immediately when ad revive is not currently valid.
	if not can_use_ad_revive():
		return false
	if not ad_manager:
		return false
	pause_for_ad_revive()  # Pause game before requesting ad
	# Ensure any banner ads are hidden before requesting revive
	if ad_manager.is_initialized and ad_manager.is_banner_showing:
		ad_manager.hide_banner_ad()
	return ad_manager.request_ad_revive()

func request_ad_revive_from_ui() -> bool:
	if not can_use_ad_revive():
		return false
	if not ad_manager:
		return false
	pause_for_ad_revive()
	# Matches previous UI flow: hide banner if visible, then request revive.
	if ad_manager and ad_manager.is_initialized and ad_manager.is_banner_showing:
		ad_manager.hide_banner_ad()
	return ad_manager.request_ad_revive()

# Centralized revive result handlers keep UI flows dependent on one completion signal.
func handle_ad_revive_success(_ad_type: String = "") -> void:
	mark_ad_revive_used()
	revive_completed.emit(true)

func handle_ad_revive_failure(_error_data: Variant = null) -> void:
	revive_completed.emit(false)

func notify_ad_failed_to_load(ad_type: String, error_data: Variant) -> void:
	ad_failed_to_load.emit(ad_type, error_data)

func notify_ad_reward_granted(reward_type: String) -> void:
	ad_reward_granted.emit(reward_type)

# Revive flow restores one life by default unless a caller explicitly overrides it.
func revive_player(lives: int = 1) -> void:
	player_manager.revive_player(lives)

func spawn_player(lives: int) -> void:
	player_manager.spawn_player(lives)

func activate_shadow_mode(duration: float = 5.0) -> void:
	request_shadow_mode_activate(duration, "GameManager.activate_shadow_mode")

func unlock_shadow_mode() -> void:
	level_manager.unlock_shadow_mode()

func is_level_unlocked(level: int) -> bool:
	return level_manager.is_level_unlocked(level)

func is_level_completed(level: int) -> bool:
	return level_manager.is_level_completed(level)

func get_current_level() -> int:
	if level_manager:
		return level_manager.get_current_level()
	return 0

func get_map_scene_path() -> String:
	if scene_manager:
		return scene_manager.MAP_SCENE
	return "res://Map/map.tscn"

func is_shadow_mode_enabled() -> bool:
	return shadow_mode_state.shadow_mode_enabled

func save_progress() -> void:
	if save_manager:
		save_manager.save_progress()

func save_progress_if_enabled() -> void:
	if save_manager and save_manager.autosave_progress:
		save_manager.save_progress()

func reset_player_stats() -> void:
	if player_manager:
		player_manager.reset_player_stats()

func hide_banner_ad_if_initialized() -> void:
	if ad_manager and ad_manager.is_initialized:
		ad_manager.hide_banner_ad()

func is_ad_revive_pending() -> bool:
	return ad_manager != null and ad_manager.ad_revive_pending

func reset_ad_revive_state() -> void:
	if not ad_manager:
		return
	# Prefer centralized AdManager cleanup when available.
	if ad_manager.has_method("reset_revive_state"):
		ad_manager.reset_revive_state()
	else:
		ad_manager.ad_revive_pending = false
		ad_manager.revive_type = "none"
		ad_manager.selected_ad_type = ""
		ad_manager.is_ad_showing = false

func get_start_scene_path() -> String:
	if scene_manager:
		return scene_manager.START_SCREEN_SCENE
	return "res://MainScenes/start_menu.tscn"

func set_level_game_over_screen_active(active: bool) -> void:
	if level_manager:
		level_manager.is_game_over_screen_active = active

# Save/load helper accessors keep persistence logic decoupled from manager internals.
func has_level_state() -> bool:
	return level_manager != null

func has_player_state() -> bool:
	return player_manager != null

func can_persist_progress() -> bool:
	return has_level_state() and has_player_state()

func get_unlocked_levels_for_save() -> int:
	return level_manager.unlocked_levels if level_manager else 1

func set_unlocked_levels_from_save(value: Variant) -> void:
	if level_manager:
		level_manager.unlocked_levels = value

func get_shadow_mode_unlocked_for_save() -> bool:
	return shadow_mode_state.shadow_mode_unlocked

func get_shadow_mode_tutorial_shown_for_save() -> bool:
	return shadow_mode_state.shadow_mode_tutorial_shown

func get_completed_levels_for_save() -> Array:
	return level_manager.completed_levels if level_manager else []

func set_completed_levels_from_save(value: Variant) -> void:
	if level_manager:
		level_manager.completed_levels = value

func get_selected_ship_id_for_save() -> String:
	return player_manager.selected_ship_id if player_manager else "Ship1"

func set_selected_ship_id_from_save(value: Variant) -> void:
	if player_manager:
		player_manager.selected_ship_id = value

func reset_level_progress() -> void:
	if level_manager:
		level_manager.reset_level_progress()

# Config passthrough helpers avoid direct ConfigLoader coupling in other managers.
func get_game_setting(key: String, default_value: Variant) -> Variant:
	if is_instance_valid(ConfigLoader) and ConfigLoader.game_settings:
		return ConfigLoader.game_settings.get(key, default_value)
	return default_value

func get_game_settings_section(key: String) -> Dictionary:
	var section = get_game_setting(key, {})
	return section if section is Dictionary else {}

func get_player_setting(key: String, default_value: Variant) -> Variant:
	if is_instance_valid(ConfigLoader) and ConfigLoader.player_settings:
		return ConfigLoader.player_settings.get(key, default_value)
	return default_value

func get_upgrade_setting(key: String, default_value: Variant) -> Variant:
	if is_instance_valid(ConfigLoader) and ConfigLoader.upgrade_settings:
		return ConfigLoader.upgrade_settings.get(key, default_value)
	return default_value

func get_boss_reward_for_level(level_num: int) -> Dictionary:
	var fallback := {
		"coins": int(1000 * (level_num / 5.0)),
		"crystals": int(60 * (level_num / 5.0)),
		"void_shards": int(50 * (level_num / 5.0))
	}
	var boss_rewards = get_upgrade_setting("boss_level_rewards", {})
	if boss_rewards is Dictionary and boss_rewards.has(str(level_num)):
		return boss_rewards[str(level_num)]
	return fallback

func get_config_ships_data() -> Array:
	if is_instance_valid(ConfigLoader) and ConfigLoader.ships_data and ConfigLoader.ships_data is Array:
		return ConfigLoader.ships_data.duplicate(true)
	return []

func get_config_satellites_data() -> Array:
	if is_instance_valid(ConfigLoader) and ConfigLoader.satellites_data and ConfigLoader.satellites_data is Array:
		return ConfigLoader.satellites_data.duplicate(true)
	return []

func is_boss_level_completed(level_num: int) -> bool:
	return save_manager != null and save_manager.boss_levels_completed.has(level_num)

func mark_boss_level_completed(level_num: int) -> bool:
	if not save_manager:
		return false
	if save_manager.boss_levels_completed.has(level_num):
		return false
	save_manager.boss_levels_completed.append(level_num)
	return true

func mark_level_completed_if_needed(level_num: int) -> bool:
	if not level_manager:
		return false
	if level_manager.completed_levels.has(level_num):
		return false
	level_manager.completed_levels.append(level_num)
	level_star_earned.emit(level_num)
	return true

func unlock_level_if_needed(level_num: int) -> bool:
	if not level_manager:
		return false
	if level_num > level_manager.unlocked_levels:
		level_manager.unlocked_levels = level_num
		level_unlocked.emit(level_num)
		return true
	return false

func can_afford(currency_type: String, cost: int) -> bool:
	match currency_type:
		"crystals":
			return _crystal_count >= cost
		"coins":
			return _coin_count >= cost
		"void_shards":
			return _void_shards_count >= cost
	return false

func deduct_currency(currency_type: String, amount: int) -> void:
	match currency_type:
		"crystals":
			crystal_count -= amount
		"coins":
			coin_count -= amount
		"void_shards":
			void_shards_count -= amount
	save_manager.save_progress()

var coins_collected_this_level: int:
	get: return level_currency_state.coins_collected_this_level
	set(value):
		level_currency_state.coins_collected_this_level = value

var crystals_collected_this_level: int:
	get: return level_currency_state.crystals_collected_this_level
	set(value):
		level_currency_state.crystals_collected_this_level = value

func add_currency(currency_type: String, amount: int) -> void:
	match currency_type:
		"crystals":
			crystal_count += amount
			crystals_collected_this_level += amount
		"coins":
			coin_count += amount
			coins_collected_this_level += amount
		"void_shards":
			void_shards_count += amount
			save_manager.save_progress()

# Add this function to reset the collected currencies when starting a new level
func reset_level_currencies() -> void:
	coins_collected_this_level = 0
	crystals_collected_this_level = 0

# New function to pause the game during ad revive
func pause_for_ad_revive() -> void:
	if not game_over or level_manager.is_level_just_completed:
		return
	is_paused = true  # Pauses the game tree


# New function to resume the game after ad revive
func resume_after_ad_revive() -> void:
	if is_paused and not level_manager.is_level_just_completed:
		is_paused = false  # Resumes the game tree


# Handle revive completion signal
func _on_revive_completed(success: bool) -> void:
	resume_after_ad_revive()
	if success:
		print("[GameManager]: Revive completed successfully")
	else:
		print("[GameManager]: Revive failed or was cancelled")

# Add this method to handle level selection from the map
func _on_level_selected(level_num: int) -> void:
	if is_level_unlocked(level_num):
		load_level(level_num)
	else:
		print("[GameManager]: Level %d is locked" % level_num)

# Notify when ship stats are updated
func notify_ship_stats_updated(ship_id: String, new_damage: int) -> void:
	ship_stats_updated.emit(ship_id, new_damage)
	# Update PlayerManager's base damage for the current ship
	if player_manager.selected_ship_id == ship_id:
		player_manager.update_current_ship_damage(new_damage)

# Notify when satellite stats are updated
func notify_satellite_stats_updated(satellite_id: String, damage_bonus: int) -> void:
	satellite_stats_updated.emit(satellite_id, damage_bonus)

# Notify when enemy is killed for shadow mode charging
func notify_enemy_killed(enemy: Node) -> void:
	enemy_killed.emit(enemy)

# Handle prepare_map_scene signal
func _on_prepare_map_scene() -> void:
	# This function is called before transitioning to the map scene
	# It ensures stars are updated before the scene transition
	pass
