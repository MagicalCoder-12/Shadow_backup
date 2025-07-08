extends Node

### 🔁 SIGNALS ###
signal on_player_life_changed(life: int)
signal score_updated(new_score: int)
signal high_score_updated(new_high_score: int)
signal game_over_triggered()
signal game_paused(paused: bool)
signal scene_change_started()
signal level_unlocked(new_level: int)
signal wave_started(current_wave: int, total_waves: int)
signal all_waves_cleared()
signal level_completed(level_num: int)
signal shadow_mode_activated
signal shadow_mode_deactivated
signal level_star_earned(level_num: int)
signal ad_reward_granted(ad_type: String)
signal ad_failed_to_load(ad_type: String, error_code: Variant)
signal revive_completed(success: bool)

### 🔒 CONSTANTS ###
const HIGH_SCORE_FILE_PATH: String = "user://high_score.dat"
const PROGRESS_FILE_PATH: String = "user://game_progress.dat"
const LOADER_SCENE: PackedScene = preload("res://Autoloads/screen_loader.tscn")
const MAP_SCENE: String = "res://Map/map.tscn"
const SHADOW_MODE_TUTORIAL_SCENE: PackedScene = preload("res://MainScenes/ShadowModeTutorial.tscn")
const SAVE_VERSION: int = 2
const GROUP_DAMAGEABLE: String = "damageable"
const GROUP_BOSS: String = "Boss"
const DEFAULT_BULLET_SPEED: float = 3000.0
const DEFAULT_BULLET_DAMAGE: int = 20
const MAX_ATTACK_LEVEL: int = 4
const SUPER_MODE_SPAWN_COUNT: int = 25
const VIDEO_SCENE: String = "res://UI/VideoPlayback.tscn"
const START_SCREEN_SCENE: String = "res://MainScenes/start_menu.tscn"
const BACKGROUND_MUSIC: AudioStream = preload("res://Textures/Music/Start.ogg")

### 🧠 SETTINGS ###
var autosave_high_score: bool = true
var autosave_progress: bool = true
var shadow_mode_unlocked: bool = false
var shadow_mode_enabled: bool = false
var shadow_mode_tutorial_shown: bool = false
var player_spawn_position: Vector2 = Vector2.ZERO
var is_level_just_completed: bool = false
var is_video_playing: bool = false
var is_game_over_screen_active: bool = false
var is_revive_pending: bool = false
var selected_ad_type: String = ""
var is_initialized: bool = false

### 🔗 PERSISTENT GAME STATE ###
var _score: int = 0
var score: int:
	get: return _score
	set(value):
		if value != _score:
			_score = value
			score_updated.emit(_score)
			if _score > high_score:
				high_score = _score

var _high_score: int = 0
var high_score: int:
	get: return _high_score
	set(value):
		if value != _high_score:
			_high_score = value
			high_score_updated.emit(_high_score)
			if autosave_high_score:
				save_high_score()

var _player_lives: int = 3
var player_lives: int:
	get: return _player_lives
	set(value):
		_player_lives = max(0, value)
		print("Player lives set to: %d (caller: %s)" % [_player_lives, get_stack()[1]["function"]])
		on_player_life_changed.emit(_player_lives)
		if _player_lives == 0 and not is_level_just_completed:
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
var unlocked_levels: int = 1:
	set(value):
		if value > unlocked_levels:
			unlocked_levels = value
			if autosave_progress:
				save_progress()
			level_unlocked.emit(value)

var completed_levels: Array = []:
	set(value):
		completed_levels = value
		if autosave_progress:
			save_progress()

### 🕒 SHADOW MODE TIMER ###
@onready var shadow_mode_timer: Timer = $ShadowModeTimer
@onready var admob: Admob = $Admob

### 📱 ADMOB REVIVE STATE ###
var revive_type: String = "none"  # "ad", "manual", "none"
var is_ad_showing: bool = false
var ad_retry_count: int = 0
var max_ad_retries: int = 3

### 📊 PLAYER STATS ###
var player_stats: Dictionary = {
	"attack_level": 0,
	"bullet_damage": DEFAULT_BULLET_DAMAGE,
	"base_bullet_damage": DEFAULT_BULLET_DAMAGE,
	"is_shadow_mode_active": false
}

func set_spawn_position() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	player_spawn_position = Vector2(viewport_size.x / 2, viewport_size.y)

func _ready() -> void:
	load_high_score()
	load_progress()
	get_tree().node_added.connect(_on_node_added)
	AudioManager.play_background_music(BACKGROUND_MUSIC, false)
	
	if not shadow_mode_timer:
		push_error("ShadowModeTimer node not found in GameManager.")
	else:
		shadow_mode_timer.one_shot = true
		if not shadow_mode_timer.timeout.is_connected(_on_shadow_mode_timer_timeout):
			shadow_mode_timer.timeout.connect(_on_shadow_mode_timer_timeout)
	
	set_spawn_position()
	
	if admob:
		admob.initialize()

func save_player_stats(attack_level: int, bullet_damage: int, base_bullet_damage: int, is_shadow_mode_active: bool) -> void:
	player_stats["attack_level"] = attack_level
	player_stats["bullet_damage"] = bullet_damage
	player_stats["base_bullet_damage"] = base_bullet_damage
	player_stats["is_shadow_mode_active"] = is_shadow_mode_active
	print("Saved player stats for current level: %s" % player_stats)

func restore_player_stats(player: Node) -> void:
	if not player or not player.has_method("set_stats"):
		push_error("Cannot restore stats: Invalid player node")
		return
	player.set_stats(
		player_stats["attack_level"],
		player_stats["bullet_damage"],
		player_stats["base_bullet_damage"],
		player_stats["is_shadow_mode_active"]
	)
	print("Restored player stats for current level: %s" % player_stats)

### 📊 SAVE / LOAD ###
func save_high_score() -> void:
	var file: FileAccess = FileAccess.open(HIGH_SCORE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.close()
	else:
		push_error("Failed to save high score: Unable to open file at %s" % HIGH_SCORE_FILE_PATH)

func load_high_score() -> void:
	if FileAccess.file_exists(HIGH_SCORE_FILE_PATH):
		var file: FileAccess = FileAccess.open(HIGH_SCORE_FILE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_var()
			file.close()
		else:
			push_error("Failed to load high score: Unable to open file at %s" % HIGH_SCORE_FILE_PATH)

func save_progress() -> void:
	var file: FileAccess = FileAccess.open(PROGRESS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(SAVE_VERSION)
		file.store_var(unlocked_levels)
		file.store_var(shadow_mode_unlocked)
		file.store_var(shadow_mode_tutorial_shown)
		file.store_var(completed_levels)
		file.store_var(player_lives)
		file.close()
	else:
		push_error("Failed to save progress: Unable to open file at %s" % PROGRESS_FILE_PATH)

func load_progress() -> void:
	if FileAccess.file_exists(PROGRESS_FILE_PATH):
		var file: FileAccess = FileAccess.open(PROGRESS_FILE_PATH, FileAccess.READ)
		if file:
			var version: int = file.get_var()
			if version != SAVE_VERSION:
				push_error("Save file version mismatch. Resetting to defaults.")
				reset_progress()
				file.close()
				return
			if !file.eof_reached():
				unlocked_levels = file.get_var()
			else:
				push_error("Save file corrupted: Missing 'unlocked_levels'.")
				unlocked_levels = 1
			if !file.eof_reached():
				shadow_mode_unlocked = file.get_var()
			else:
				push_error("Save file corrupted: Missing 'shadow_mode_unlocked'.")
				shadow_mode_unlocked = false
			if !file.eof_reached():
				shadow_mode_tutorial_shown = file.get_var()
			else:
				push_error("Save file corrupted: Missing 'shadow_mode_tutorial_shown'.")
				shadow_mode_tutorial_shown = false
			if !file.eof_reached():
				completed_levels = file.get_var()
			else:
				push_error("Save file corrupted: Missing 'completed_levels'.")
				completed_levels = []
			if !file.eof_reached():
				player_lives = file.get_var()
			else:
				push_error("Save file corrupted: Missing 'player_lives'.")
				player_lives = 3
			file.close()
			if unlocked_levels >= 6 and not shadow_mode_unlocked:
				shadow_mode_unlocked = true
				save_progress()
		else:
			push_error("Failed to load progress: Unable to open file at %s" % PROGRESS_FILE_PATH)
	else:
		reset_progress()

func reset_progress() -> void:
	player_lives = 3
	player_stats = {
		"attack_level": 0,
		"bullet_damage": DEFAULT_BULLET_DAMAGE,
		"base_bullet_damage": DEFAULT_BULLET_DAMAGE,
		"is_shadow_mode_active": false
	}
	unlocked_levels = 1
	shadow_mode_unlocked = false
	shadow_mode_tutorial_shown = false
	completed_levels = []
	if autosave_progress:
		save_progress()

### 🎮 GAME CONTROL ###
func reset_game() -> void:
	score = 0
	player_lives = 3
	is_paused = false
	game_over = false
	game_ended = false
	game_won = false
	set_spawn_position()
	shadow_mode_enabled = false
	shadow_mode_timer.stop()
	is_level_just_completed = false
	is_video_playing = false
	is_game_over_screen_active = false
	is_revive_pending = false
	selected_ad_type = ""
	is_ad_showing = false
	ad_retry_count = 0
	revive_type = "none"
	player_stats = {
		"attack_level": 0,
		"bullet_damage": DEFAULT_BULLET_DAMAGE,
		"base_bullet_damage": DEFAULT_BULLET_DAMAGE,
		"is_shadow_mode_active": false
	}
	AudioManager.play_background_music(BACKGROUND_MUSIC, true)
	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)

func trigger_game_over() -> void:
	if game_over or is_level_just_completed:
		return
	game_over = true
	is_paused = false
	get_tree().paused = false
	shadow_mode_enabled = false
	shadow_mode_timer.stop()
	shadow_mode_deactivated.emit()
	is_video_playing = false
	is_game_over_screen_active = true
	AudioManager.mute_bus("Bullet", true)
	AudioManager.mute_bus("Explosion", true)
	if admob and is_initialized:
		admob.show_banner_ad()
	game_over_triggered.emit()

func revive_player(lives: int = 2) -> void:
	if not is_revive_pending:
		print("Revive attempted but no revive pending")
		revive_completed.emit(false)
		return
	
	print("Reviving player with %d lives (type: %s)" % [lives, revive_type])
	
	game_over = false
	is_paused = false
	get_tree().paused = false
	player_lives = lives
	on_player_life_changed.emit(player_lives)
	set_spawn_position()
	
	if autosave_progress:
		save_progress()
	
	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		_hide_game_over_screen(current_scene)
		var player = current_scene.get_node_or_null("Player")
		if player and player.has_method("set_lives"):
			player.set_lives(player_lives)
			print("Synced player lives to %d" % player_lives)
	
	is_game_over_screen_active = false
	if admob and is_initialized:
		admob.hide_banner_ad()
	
	is_revive_pending = false
	is_ad_showing = false
	ad_retry_count = 0
	selected_ad_type = ""
	revive_type = "none"
	
	print("Player revived successfully, game_over set to: %s" % game_over)
	revive_completed.emit(true)

func _hide_game_over_screen(current_scene: Node) -> void:
	var found = false
	for child in current_scene.get_children():
		if child.name == "GameOverScreen":
			child.visible = false
			print("Hid GameOverScreen")
			found = true
			break
	if not found:
		for child in current_scene.get_children():
			if child is CanvasLayer:
				for subchild in child.get_children():
					if subchild.name == "GameOverScreen":
						subchild.visible = false
						print("Hid GameOverScreen from CanvasLayer")
						found = true
						break
				if found:
					break
	if not found:
		push_warning("GameOverScreen not found in current scene")

### 🕒 SHADOW MODE MANAGEMENT ###
func unlock_shadow_mode() -> void:
	if not shadow_mode_unlocked:
		shadow_mode_unlocked = true
		if autosave_progress:
			save_progress()
		update_hud_visibility()

func activate_shadow_mode(duration: float = 2.0) -> void:
	if shadow_mode_unlocked:
		shadow_mode_enabled = true
		shadow_mode_activated.emit()
		shadow_mode_timer.start(duration)

func _on_shadow_mode_timer_timeout() -> void:
	if shadow_mode_enabled:
		shadow_mode_enabled = false
		shadow_mode_deactivated.emit()

### 🗺️ SCENE MANAGEMENT ###
func change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Scene not found: %s" % scene_path)
		return
	scene_change_started.emit()
	var root: Node = get_tree().current_scene
	if root:
		for child in root.get_children():
			if child.name == "LoaderCanvasLayer" or child.name == "VideoPlaybackLayer":
				continue
	var loader: Node = LOADER_SCENE.instantiate()
	loader.name = "LoaderCanvasLayer"
	root.add_child(loader)
	for bus in AudioServer.bus_count:
		var bus_name = AudioServer.get_bus_name(bus)
		if bus_name != "Background" and bus_name != "Master":
			AudioServer.set_bus_mute(bus, true)
	if admob and is_initialized:
		admob.hide_banner_ad()
	loader.start_load(scene_path)

### 🧩 LEVEL MANAGEMENT ###
func load_level(level_num: int) -> void:
	if is_level_unlocked(level_num):
		player_stats = {
			"attack_level": 0,
			"bullet_damage": DEFAULT_BULLET_DAMAGE,
			"base_bullet_damage": DEFAULT_BULLET_DAMAGE,
			"is_shadow_mode_active": false
		}
		player_lives = max(2, player_lives)
		print("Set player_lives to %d for level %d" % [player_lives, level_num])
		var level_path: String = "res://Levels/level_%d.tscn" % level_num
		if level_path != START_SCREEN_SCENE and level_path != MAP_SCENE:
			AudioManager.stop_background_music()
		change_scene(level_path)
		await get_tree().create_timer(0.3).timeout
		update_hud_visibility(level_num)
		if admob and is_initialized:
			admob.hide_banner_ad()
		var current_scene = get_tree().current_scene
		if current_scene:
			var player = current_scene.get_node_or_null("Player")
			if player and player.has_method("set_lives"):
				player.set_lives(player_lives)
				print("Synced player lives to %d after level load" % player_lives)

func update_hud_visibility(level_num: int = get_current_level()) -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("CanvasLayer/HUD")
	if hud and hud.has_node("ShadowModeButton"):
		var shadow_button: TextureButton = hud.get_node("ShadowModeButton")
		var should_be_visible: bool = level_num >= 5 and shadow_mode_unlocked
		shadow_button.visible = should_be_visible
		if not should_be_visible:
			shadow_button.disabled = true
			if hud.has_method("reset_charge"):
				hud.reset_charge()

func complete_level(current_level: int) -> void:
	if game_over and not is_revive_pending:
		print("Cannot complete level %d, game over" % current_level)
		return
	print("Completing level %d" % current_level)
	
	is_level_just_completed = true
	
	if player_lives == 0:
		player_lives = 2
		if autosave_progress:
			save_progress()
	
	if not completed_levels.has(current_level):
		completed_levels.append(current_level)
		level_star_earned.emit(current_level)
		if autosave_progress:
			save_progress()
	
	level_completed.emit(current_level)

	var should_transition_to_next_level: bool = true
	if current_level == 5 and not shadow_mode_tutorial_shown:
		var current_scene = get_tree().current_scene
		if current_scene:
			AudioManager.mute_bus("Bullet", true)
			AudioManager.mute_bus("Explosion", true)
			var tutorial_layer = CanvasLayer.new()
			tutorial_layer.name = "ShadowModeTutorialLayer"
			tutorial_layer.layer = 10
			var tutorial: Node = SHADOW_MODE_TUTORIAL_SCENE.instantiate()
			tutorial_layer.add_child(tutorial)
			current_scene.add_child(tutorial_layer)
			shadow_mode_tutorial_shown = true
			if autosave_progress:
				save_progress()
			should_transition_to_next_level = false
			is_level_just_completed = false
		else:
			push_error("Cannot add tutorial: No current scene available")

	if current_level == 10 and not is_video_playing:
		var current_scene = get_tree().current_scene
		if current_scene and ResourceLoader.exists(VIDEO_SCENE):
			is_video_playing = true
			AudioManager.lower_bus_volumes_except(["Boss", "Master"], -60.0)
			var video_layer = CanvasLayer.new()
			video_layer.name = "VideoPlaybackLayer"
			video_layer.layer = 10
			var video_scene: Node = load(VIDEO_SCENE).instantiate()
			video_layer.add_child(video_scene)
			current_scene.add_child(video_layer)
			should_transition_to_next_level = false
			if video_scene.has_signal("finished"):
				AudioManager.mute_audio_buses(false)
				video_scene.finished.connect(_on_video_finished.bind(video_layer))
			else:
				await get_tree().create_timer(10.0).timeout
				_on_video_finished(video_layer)
		else:
			push_error("Cannot play video: No current scene or VideoPlayback.tscn missing")
	
	var next_level: int = current_level + 1
	if next_level > unlocked_levels:
		unlocked_levels = next_level
		if autosave_progress:
			save_progress()
		level_unlocked.emit(next_level)
	
	if should_transition_to_next_level:
		print("Next level unlocked: %d" % next_level)
		is_level_just_completed = false

func _on_video_finished(video_layer: CanvasLayer) -> void:
	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)
	video_layer.queue_free()
	is_video_playing = false
	change_scene(START_SCREEN_SCENE)
	is_level_just_completed = false

func unlock_next_level(current_level: int) -> void:
	var next_level: int = current_level + 1
	var next_level_path: String = "res://Levels/level_%d.tscn" % next_level
	if ResourceLoader.exists(next_level_path):
		change_scene(next_level_path)
	else:
		change_scene(MAP_SCENE)
	is_level_just_completed = false

func is_level_unlocked(level: int) -> bool:
	return level <= unlocked_levels

func is_level_completed(level: int) -> bool:
	return completed_levels.has(level)

### 📡 SIGNAL FORWARDERS ###
func _on_wave_started(current_wave: int, total_waves: int) -> void:
	wave_started.emit(current_wave, total_waves)

func _on_all_waves_cleared() -> void:
	all_waves_cleared.emit()

func _on_level_selected(level_num: int) -> void:
	if is_level_unlocked(level_num):
		load_level(level_num)

func _on_boss_defeated() -> void:
	print("Boss defeated signal received in GameManager")
	score += 1000
	var current_level: int = get_current_level()
	if current_level == 5:
		unlock_shadow_mode()
	complete_level(current_level)

func _on_unlock_shadow_mode() -> void:
	unlock_shadow_mode()

func _on_shadow_unlock_boss_boss_defeated():
	if game_ended:
		return
	game_ended = true
	game_won = true
	var victory_screen = preload("res://MainScenes/ShadowModeTutorial.tscn").instantiate()
	get_tree().current_scene.add_child(victory_screen)
	is_level_just_completed = false

func _on_game_over_triggered() -> void:
	if game_ended:
		return
	game_ended = true
	game_won = false
	print("Game over! Player died.")
	if not is_revive_pending:
		AudioManager.mute_bus("Bullet", true)
		AudioManager.mute_bus("Explosion", true)
		print("Muted Bullet and Explosion buses during game over")
	var current_scene = get_tree().current_scene
	if current_scene:
		var game_over_screen = preload("res://MainScenes/game_over_screen.tscn").instantiate()
		current_scene.add_child(game_over_screen)
		if game_over_screen.name == "GameOverScreen":
			game_over_screen.visible = true
			print("Added and showed GameOverScreen")
	is_level_just_completed = false

### 🔌 SIGNAL AUTO-CONNECT ###
func _on_node_added(node: Node) -> void:
	if node is WaveManager:
		node.wave_started.connect(_on_wave_started)
		node.all_waves_cleared.connect(_on_all_waves_cleared)
	if node is Control and node.name == "LoaderCanvasLayer":
		node.z_index = 100
	if node.is_in_group(GROUP_BOSS):
		if node is Area2D and node.has_signal("boss_defeated"):
			node.boss_defeated.connect(_on_boss_defeated)
			if node.has_signal("unlock_shadow_mode"):
				node.unlock_shadow_mode.connect(_on_unlock_shadow_mode)
		else:
			push_error("Skipping Boss group node: %s (type: %s, has boss_defeated: %s)" % [
				node.name, node.get_class(), node.has_signal("boss_defeated")
			])
	if node.name == "GameOverScreen":
		if node.has_signal("player_revived"):
			node.player_revived.connect(_on_player_revived)
		if node.has_signal("ad_revive_requested"):
			node.ad_revive_requested.connect(_on_ad_revive_requested)
	if node == get_tree().current_scene:
		var scene_path = node.scene_file_path if node.scene_file_path else ""
		if scene_path == START_SCREEN_SCENE or scene_path == MAP_SCENE:
			AudioManager.play_background_music(BACKGROUND_MUSIC, false)
			if AudioManager.background_player:
				AudioManager.background_player.stream.loop = true
				AudioManager.background_player.stream_paused = false
				print("Background music set to loop in %s" % scene_path)
			AudioManager.mute_bus("Bullet", true)
			AudioManager.mute_bus("Explosion", true)
			if admob and is_initialized:
				admob.show_banner_ad()
		else:
			if AudioManager.background_player:
				AudioManager.background_player.stream.loop = false
			AudioManager.mute_bus("Bullet", false)
			AudioManager.mute_bus("Explosion", false)
			if admob and is_initialized:
				admob.hide_banner_ad()

### 📈 UI Sync Helper ###
func connect_score_signals(target_node: Node) -> void:
	if target_node.has_method("set_score"):
		score_updated.connect(target_node.set_score)
	if target_node.has_method("set_high_score"):
		high_score_updated.connect(target_node.set_high_score)

### 🛠️ Helper Functions ###
func get_current_level() -> int:
	var scene_path: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var regex = RegEx.new()
	regex.compile("level_(\\d+)\\.tscn")
	var result = regex.search(scene_path)
	if result:
		return int(result.get_string(1))
	return 0

### 📱 ADMOB INITIALIZATION ###
func _on_admob_initialization_completed(status_data: InitializationStatus) -> void:
	is_initialized = true
	var app_id = "ca-app-pub-3940256099942544~3347511713" if admob.is_real == false else "ca-app-pub-4574794641011089~7012103621"
	var rewarded_ad_id = "ca-app-pub-3940256099942544/5224354917" 
	var interstitial_ad_id = "ca-app-pub-3940256099942544/1033173712" 
	print("AdMob initialized like a boss! 🚀 Status: %s, App ID: %s, Rewarded Ad ID: %s, Interstitial Ad ID: %s" % [
		status_data, app_id, rewarded_ad_id, interstitial_ad_id
	])
	admob.load_banner_ad()
	admob.load_rewarded_ad()
	admob.load_rewarded_interstitial_ad()
	var scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if scene_path == MAP_SCENE or scene_path == START_SCREEN_SCENE:
		await admob.banner_ad_loaded
		if is_initialized:
			admob.show_banner_ad()
			print("Banner ad waving at players from %s!" % scene_path)
	else:
		admob.hide_banner_ad()
		print("Banner ad tucked away for gameplay focus.")

### 📱 ADMOB EVENT HANDLERS ###
func _on_admob_banner_ad_loaded(ad_id: String) -> void:
	print("Banner ad loaded with ID: %s. Ready to dazzle!" % ad_id)
	if is_initialized and (get_tree().current_scene.scene_file_path == MAP_SCENE or get_tree().current_scene.scene_file_path == START_SCREEN_SCENE):
		admob.show_banner_ad()
		print("Banner ad displayed because we're on the cool screens!")

func _on_admob_banner_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	var error_info = error_data.message if error_data and error_data.has("message") else str(error_data)
	var error_code = error_data.code if error_data and error_data.has("code") else "Unknown"
	push_warning("Banner ad failed to load. Error: %s, Code: %s. Retrying in 5 seconds..." % [error_info, error_code])
	if ad_retry_count < max_ad_retries:
		ad_retry_count += 1
		await get_tree().create_timer(5.0).timeout
		if is_initialized:
			admob.load_banner_ad()
			print("Retrying banner ad load, attempt %d/%d" % [ad_retry_count, max_ad_retries])
	else:
		push_error("Max retries reached for banner ad. Giving up! 😢")
		ad_retry_count = 0

func _on_admob_rewarded_ad_loaded(ad_id: String) -> void:
	print("Rewarded video ad loaded! ID: %s. Ready for some shiny rewards!" % ad_id)
	if is_revive_pending and selected_ad_type == "video" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_ad()
		print("Showing rewarded video ad for revive. Let's bring that player back!")

func _on_admob_rewarded_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	if is_revive_pending and selected_ad_type == "video":
		var error_info = error_data.message if error_data and error_data.has("message") else str(error_data)
		var error_code = error_data.code if error_data and error_data.has("code") else "Unknown"
		print("Rewarded video ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
		ad_failed_to_load.emit("video", error_data)
		if ad_retry_count < max_ad_retries:
			ad_retry_count += 1
			print("Retrying video ad load, attempt %d/%d" % [ad_retry_count, max_ad_retries])
			await get_tree().create_timer(5.0).timeout
			if is_initialized:
				admob.load_rewarded_ad()
		else:
			print("Max retries reached for video ad. Falling back to map! 😞")
			is_ad_showing = false
			is_revive_pending = false
			revive_type = "none"
			selected_ad_type = ""
			ad_retry_count = 0
			revive_completed.emit(false)
			change_scene(MAP_SCENE)

func _on_admob_rewarded_ad_showed_full_screen_content(ad_id: String) -> void:
	print("Rewarded video ad is showing! ID: %s. Popcorn ready!" % ad_id)
	is_ad_showing = true

func _on_admob_rewarded_ad_dismissed_full_screen_content(ad_id: String) -> void:
	print("Rewarded video ad dismissed. ID: %s" % ad_id)
	if is_revive_pending and selected_ad_type == "video":
		complete_ad_revive()
	else:
		is_ad_showing = false
		revive_type = "none"
		selected_ad_type = ""
		ad_retry_count = 0
		if is_initialized:
			admob.load_rewarded_ad()
			print("Preloading next rewarded video ad for future revives.")

func _on_admob_rewarded_ad_user_earned_reward(ad_id: String, reward_data: RewardItem) -> void:
	if is_revive_pending and selected_ad_type == "video":
		print("Player earned reward from video ad! ID: %s, Reward: %s" % [ad_id, reward_data])
		ad_reward_granted.emit("video")
		complete_ad_revive()
	else:
		print("Reward earned but no revive pending. Saving it for later! ID: %s" % ad_id)

func _on_admob_rewarded_interstitial_ad_loaded(ad_id: String) -> void:
	print("Rewarded interstitial ad loaded! ID: %s. Ready to surprise!" % ad_id)
	if is_revive_pending and selected_ad_type == "interstitial" and not is_ad_showing:
		is_ad_showing = true
		admob.show_rewarded_interstitial_ad()
		print("Showing rewarded interstitial ad for revive. Back to action!")

func _on_admob_rewarded_interstitial_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	if is_revive_pending and selected_ad_type == "interstitial":
		var error_info = error_data.message if error_data and error_data.has("message") else str(error_data)
		var error_code = error_data.code if error_data and error_data.has("code") else "Unknown"
		print("Rewarded interstitial ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
		ad_failed_to_load.emit("interstitial", error_data)
		if ad_retry_count < max_ad_retries:
			ad_retry_count += 1
			print("Retrying interstitial ad load, attempt %d/%d" % [ad_retry_count, max_ad_retries])
			await get_tree().create_timer(5.0).timeout
			if is_initialized:
				admob.load_rewarded_interstitial_ad()
		else:
			print("Max retries reached for interstitial ad. Falling back to map! 😞")
			is_ad_showing = false
			is_revive_pending = false
			revive_type = "none"
			selected_ad_type = ""
			ad_retry_count = 0
			revive_completed.emit(false)
			change_scene(MAP_SCENE)

func _on_admob_rewarded_interstitial_ad_showed_full_screen_content(ad_id: String) -> void:
	print("Rewarded interstitial ad is showing! ID: %s. Get ready for epicness!" % ad_id)
	is_ad_showing = true

func _on_admob_rewarded_interstitial_ad_dismissed_full_screen_content(ad_id: String) -> void:
	print("Rewarded interstitial ad dismissed. ID: %s" % ad_id)
	if is_revive_pending and selected_ad_type == "interstitial":
		complete_ad_revive()
	else:
		is_ad_showing = false
		revive_type = "none"
		selected_ad_type = ""
		ad_retry_count = 0
		if is_initialized:
			admob.load_rewarded_interstitial_ad()
			print("Preloading next rewarded interstitial ad for future revives.")

func _on_admob_rewarded_interstitial_ad_user_earned_reward(ad_id: String, reward_data: RewardItem) -> void:
	if is_revive_pending and selected_ad_type == "interstitial":
		print("Player earned reward from interstitial ad! ID: %s, Reward: %s" % [ad_id, reward_data])
		ad_reward_granted.emit("interstitial")
		complete_ad_revive()
	else:
		print("Reward earned but no revive pending. Stashing it for later! ID: %s" % ad_id)

### 📱 ADMOB REVIVE LOGIC ###
func _on_ad_revive_requested() -> void:
	if not admob or not is_initialized:
		push_error("Cannot request ad revive: AdMob not initialized or missing.")
		revive_completed.emit(false)
		return
	if is_ad_showing:
		print("Ad request ignored: Another ad is already showing. Chill out!")
		revive_completed.emit(false)
		return
	if is_revive_pending:
		print("Ad request ignored: Revive already pending. Patience, young padawan!")
		revive_completed.emit(false)
		return
	
	is_revive_pending = true
	revive_type = "ad"
	ad_retry_count = 0
	selected_ad_type = "video" if randf() < 0.5 else "interstitial"
	print("Requesting %s ad for revive. Fingers crossed! 🤞" % selected_ad_type)
	
	if selected_ad_type == "video":
		if admob.is_rewarded_ad_loaded():
			is_ad_showing = true
			admob.show_rewarded_ad()
			print("Showing rewarded video ad right away!")
		else:
			print("Loading rewarded video ad...")
			admob.load_rewarded_ad()
	else:
		if admob.is_rewarded_interstitial_ad_loaded():
			is_ad_showing = true
			admob.show_rewarded_interstitial_ad()
			print("Showing rewarded interstitial ad right away!")
		else:
			print("Loading rewarded interstitial ad...")
			admob.load_rewarded_interstitial_ad()

func _on_player_revived() -> void:
	if revive_type != "ad":
		revive_type = "manual"
		print("Player revived manually like a sci-fi phoenix! 🔥")
		revive_player(2)
	else:
		print("Player revive triggered, but waiting for ad reward. Hold tight!")
		# Ad-based revive will be handled by complete_ad_revive

func complete_ad_revive() -> void:
	if not is_revive_pending:
		print("Ad revive attempted: No revive pending. Back to the drawing board!")
		is_ad_showing = false
		revive_completed.emit(false)
		return
	
	print("Completing ad revive like a galactic hero! 🌌")
	var current_scene = get_tree().current_scene
	var player = current_scene.get_node_or_null("Player") if current_scene else null
	if player and player.is_inside_tree():
		print("Reviving existing player (ad)")
		player.revive(2)
		game_over = false
	else:
		print("Instantiating new player for revive (ad)")
		var new_player = preload("res://Player/Player.tscn").instantiate()
		new_player.global_position = player_spawn_position
		if current_scene:
			current_scene.call_deferred("add_child", new_player)
			new_player.call_deferred("revive", 2)
			game_over = false
	
	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)
	print("Unmuted Bullet and Explosion buses in complete_ad_revive")
	
	call_deferred("revive_player", 2)
	
	if admob and is_initialized:
		if selected_ad_type == "video":
			admob.load_rewarded_ad()
			print("Preloading video ad for next revive")
		else:
			admob.load_rewarded_interstitial_ad()
			print("Preloading interstitial ad for next revive")
	
	is_ad_showing = false
	revive_completed.emit(true)
	print("Ad revive completed, game_over set to: %s" % game_over)
