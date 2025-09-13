extends Node2D

# Revive state tracking
var is_revive_pending: bool = false
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
signal enemy_killed(enemy: Node)

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
		if game_over: return
		if value != is_paused:
			is_paused = value
			get_tree().paused = value
			game_paused.emit(value)

var game_over: bool = false
var game_ended: bool = false
var game_won: bool = false

# SHIP AND CURRENCY DATA
var ships: Array = []
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
var upgrade_menu_ref: Node = null

var shadow_mode_timer: Timer = Timer.new()

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

# Connect revive_completed signal to resume game after ad
	if not revive_completed.is_connected(_on_revive_completed):
		revive_completed.connect(_on_revive_completed)

func trigger_game_over() -> void:
	AudioManager.mute_bus("Bullet", true)
	AudioManager.mute_bus("Explosion", true)
	if ad_manager.is_initialized:
		ad_manager.show_banner_ad()
	game_over_triggered.emit()

func reset_game() -> void:
	score = 0
	player_lives = 3
	is_paused = false
	game_over = false
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
	
	print("[GameManager] Game state fully reset for restart")

# Reset score and lives for each level (per-level progression)
func reset_for_new_level() -> void:
	#var current_level = get_current_level()
	# Always reset score to 0 and lives to 3 for each level
	_score = 0
	_player_lives = 3
	
	coins_collected_this_level = 0
	crystals_collected_this_level = 0
	print("[GameManager] Score and lives reset for new level: score=%d, lives=%d" % [_score, _player_lives])
	score_updated.emit(_score)
	on_player_life_changed.emit(_player_lives)

func complete_level(current_level: int) -> void:
	print("[GameManager] complete_level called for level: %d" % current_level)
	level_manager.complete_level(current_level)

func _on_shadow_mode_timer_timeout() -> void:
	if level_manager.shadow_mode_enabled:
		level_manager.shadow_mode_enabled = false
		shadow_mode_deactivated.emit()

func _on_node_added(node: Node) -> void:
	level_manager.handle_node_added(node)
	ad_manager.handle_node_added(node)
	scene_manager.handle_node_added(node)

func connect_score_signals(target_node: Node) -> void:
	if target_node.has_method("set_score"):
		score_updated.connect(target_node.set_score)

# Public API methods
func change_scene(scene_path: String) -> void:
	scene_manager.change_scene(scene_path)

func load_level(level_num: int) -> void:
	level_manager.load_level(level_num)

func request_ad_revive() -> void:
	pause_for_ad_revive()  # Pause game before requesting ad
	ad_manager.request_ad_revive()

func revive_player(lives: int = 2) -> void:
	print("[DEBUG] GameManager: revive_player called with lives: %d" % lives)
	player_manager.revive_player(lives)
	print("[DEBUG] GameManager: revive_player completed")

func spawn_player(lives: int) -> void:
	player_manager.spawn_player(lives)

func activate_shadow_mode(duration: float = 5.0) -> void:
	level_manager.activate_shadow_mode(duration)

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

func set_upgrade_menu_ref(menu: Node) -> void:
	upgrade_menu_ref = menu

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

var coins_collected_this_level: int = 0
var crystals_collected_this_level: int = 0

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
	print("Game paused for ad revive")

# New function to resume the game after ad revive
func resume_after_ad_revive() -> void:
	if is_paused and not game_over and not level_manager.is_level_just_completed:
		is_paused = false  # Resumes the game tree
		print("Game resumed after ad revive")

# Handle revive completion signal
func _on_revive_completed(success: bool) -> void:
	resume_after_ad_revive()
	if success:
		print("Revive completed successfully")
	else:
		print("Revive failed or was cancelled")

# Notify when ship stats are updated
func notify_ship_stats_updated(ship_id: String, new_damage: int) -> void:
	ship_stats_updated.emit(ship_id, new_damage)
	# Update PlayerManager's base damage for the current ship
	if player_manager.selected_ship_id == ship_id:
		player_manager.update_current_ship_damage(new_damage)

# Notify when enemy is killed for shadow mode charging
func notify_enemy_killed(enemy: Node) -> void:
	enemy_killed.emit(enemy)
