extends Node

var gm: Node
var unlocked_levels: int = 1
var completed_levels: Array = []
var shadow_mode_unlocked: bool = false
var shadow_mode_enabled: bool = false
var shadow_mode_tutorial_shown: bool = false
var is_level_just_completed: bool = false
var is_video_playing: bool = false
var is_game_over_screen_active: bool = false

const SHADOW_MODE_TUTORIAL_SCENE: PackedScene = preload("res://MainScenes/ShadowModeTutorial.tscn")
const BACKGROUND_MUSIC: AudioStream = preload("res://Textures/Music/Start.ogg")

# Signals
signal level_loaded(level_num: int)

func _ready() -> void:
	gm = GameManager


func load_level(level_num: int) -> void:
	if not is_level_unlocked(level_num):
		return
	
	# Reset score and lives for each level (per-level progression)
	gm.reset_for_new_level()
	
	gm.player_manager.player_stats = {
		"attack_level": 0,
		"bullet_damage": gm.player_manager.default_bullet_damage,
		"base_bullet_damage": gm.player_manager.default_bullet_damage,
		"is_shadow_mode_active": false
	}
	
	# Always set player lives to 3 for each level
	gm.player_lives = 3
	
	var level_path: String = "res://Levels/level_%d.tscn" % level_num
	
	# Stop background music before loading level scenes to prevent overlap
	if level_path != gm.scene_manager.START_SCREEN_SCENE and level_path != gm.scene_manager.MAP_SCENE:
		AudioManager.stop_background_music()
	
	gm.change_scene(level_path)
	await gm.get_tree().create_timer(0.5).timeout
	
	if gm.get_tree().current_scene:
		update_hud_visibility(level_num)
		
		if gm.ad_manager.is_initialized:
			gm.ad_manager.hide_banner_ad()
		
		level_loaded.emit(level_num)
	else:
		push_error("LevelManager: Failed to load level %d, no current scene" % level_num)

func complete_level(current_level: int) -> void:
	if gm.game_over and not gm.ad_manager.is_revive_pending:
		return
	
	is_level_just_completed = true
	
	if gm.player_lives == 0:
		gm.player_lives = 2
	
	if gm.save_manager.autosave_progress:
		gm.save_manager.save_progress()
	
	# Handle special level completions
	var should_transition_to_next_level: bool = true
	var is_boss_level: bool = current_level % 5 == 0 and current_level > 0
	
	# Handle special level completions
	if current_level == 5 and not shadow_mode_tutorial_shown:
		_show_shadow_mode_tutorial()
		should_transition_to_next_level = false
		is_level_just_completed = false
	elif is_boss_level:
		# For boss levels, we don't automatically emit level_completed signal
		# The Level scene will handle showing the appropriate screen (boss clear or level completed)
		should_transition_to_next_level = false
		is_level_just_completed = false
	elif current_level == 20 and not is_video_playing:
		_play_ending_video()
		should_transition_to_next_level = false
	
	# Only add to completed levels if not already completed
	if not completed_levels.has(current_level):
		completed_levels.append(current_level)
		gm.level_star_earned.emit(current_level)
		if gm.save_manager.autosave_progress:
			gm.save_manager.save_progress()
	
	# For non-boss levels, emit the level_completed signal
	if not is_boss_level:
		if gm:
			for connection in gm.level_completed.get_connections():
				print("LevelManager: Connected to: %s" % connection.callable.get_object())
		print("LevelManager: Emitting level_completed signal for level %d" % current_level)
		gm.level_completed.emit(current_level)
	
	# Unlock next level (but only if it's the next sequential level)
	var next_level: int = current_level + 1
	if next_level == unlocked_levels + 1:  # Only unlock if it's the next sequential level
		unlocked_levels = next_level
		if gm.save_manager.autosave_progress:
			gm.save_manager.save_progress()
		gm.level_unlocked.emit(next_level)
	
	if should_transition_to_next_level:
		is_level_just_completed = false

func _show_shadow_mode_tutorial() -> void:
	var current_scene = gm.get_tree().current_scene
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
		if gm.save_manager.autosave_progress:
			gm.save_manager.save_progress()
	else:
		push_error("LevelManager: Cannot add tutorial: No current scene available")

func _play_ending_video() -> void:
	var current_scene = gm.get_tree().current_scene
	if current_scene and ResourceLoader.exists(gm.scene_manager.VIDEO_SCENE):
		is_video_playing = true
		AudioManager.lower_bus_volumes_except(["Video", "Master"], -10.0)
		
		var video_layer = CanvasLayer.new()
		video_layer.name = "VideoPlaybackLayer"
		video_layer.layer = 10
		
		var video_scene: Node = load(gm.scene_manager.VIDEO_SCENE).instantiate()
		video_layer.add_child(video_scene)
		current_scene.add_child(video_layer)
		
		if video_scene.has_signal("finished"):
			video_scene.finished.connect(_on_video_finished.bind(video_layer))
		else:
			await gm.get_tree().create_timer(10.0).timeout
			_on_video_finished(video_layer)
	else:
		push_error("LevelManager: Cannot play video: No current scene or VideoPlayback.tscn missing")

func _on_video_finished(video_layer: CanvasLayer) -> void:
	AudioManager.restore_bus_volumes()
	video_layer.queue_free()
	is_video_playing = false
	gm.change_scene(gm.scene_manager.START_SCREEN_SCENE)
	is_level_just_completed = false

func unlock_next_level(current_level: int) -> void:
	var next_level: int = current_level + 1
	var next_level_path: String = "res://Levels/level_%d.tscn" % next_level
	if ResourceLoader.exists(next_level_path):
		gm.change_scene(next_level_path)
	else:
		gm.change_scene(gm.scene_manager.MAP_SCENE)
	
	is_level_just_completed = false

func unlock_shadow_mode() -> void:
	if not shadow_mode_unlocked:
		shadow_mode_unlocked = true
		if gm.save_manager.autosave_progress:
			gm.save_manager.save_progress()
		update_hud_visibility()

func activate_shadow_mode(duration: float = 2.0) -> void:
	if shadow_mode_unlocked:
		shadow_mode_enabled = true
		gm.shadow_mode_activated.emit()
		gm.shadow_mode_timer.start(duration)

func update_hud_visibility(level_num: int = get_current_level()) -> void:
	var hud: Node = gm.get_tree().current_scene.get_node_or_null("CanvasLayer/HUD")
	if hud and hud.has_node("ShadowModeButton"):
		var shadow_button: ShadowModeButton = hud.get_node("ShadowModeButton") as ShadowModeButton
		if shadow_button:
			var should_be_visible: bool = level_num >= 5 and shadow_mode_unlocked
			shadow_button.visible = should_be_visible
			
			if not should_be_visible:
				shadow_button.set_enabled(false)
				if hud.has_method("reset_charge"):
					hud.reset_charge()

func is_level_unlocked(level: int) -> bool:
	return level <= unlocked_levels

func is_level_completed(level: int) -> bool:
	return completed_levels.has(level)

func get_current_level() -> int:
	var scene_path: String = gm.get_tree().current_scene.scene_file_path if gm.get_tree().current_scene else ""
	var regex = RegEx.new()
	regex.compile("level_(\\d+)\\.tscn")
	var result = regex.search(scene_path)
	if result:
		return int(result.get_string(1))
	return 0

func reset_level_state() -> void:
	shadow_mode_enabled = false
	is_level_just_completed = false
	is_video_playing = false
	is_game_over_screen_active = false

func reset_level_progress() -> void:
	unlocked_levels = 1
	shadow_mode_unlocked = false
	shadow_mode_tutorial_shown = false
	completed_levels = []

func handle_node_added(node: Node) -> void:
	if node is WaveManager:
		if not node.wave_started.is_connected(_on_wave_started):
			node.wave_started.connect(_on_wave_started)
			
		if not node.all_waves_cleared.is_connected(_on_all_waves_cleared):
			node.all_waves_cleared.connect(_on_all_waves_cleared)
	
	if node.is_in_group(gm.GROUP_BOSS):
		if node is Area2D and node.has_signal("boss_defeated"):
			if not node.boss_defeated.is_connected(_on_boss_defeated):
				node.boss_defeated.connect(_on_boss_defeated)

		if node.has_signal("unlock_shadow_mode"):
			if not node.unlock_shadow_mode.is_connected(_on_unlock_shadow_mode):
				node.unlock_shadow_mode.connect(_on_unlock_shadow_mode)


func _on_wave_started(current_wave: int, total_waves: int) -> void:
	gm.wave_started.emit(current_wave, total_waves)

func _on_all_waves_cleared() -> void:
	gm.all_waves_cleared.emit()

func _on_boss_defeated() -> void:
	gm.score += 1000
	var current_level: int = get_current_level()
	if current_level == 5:
		unlock_shadow_mode()
	
	# For all levels, complete the level properly through the unified flow
	complete_level(current_level)

func _on_unlock_shadow_mode() -> void:
	unlock_shadow_mode()

func _on_level_selected(level_num: int) -> void:
	if is_level_unlocked(level_num):
		load_level(level_num)
