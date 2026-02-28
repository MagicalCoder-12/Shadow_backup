extends Node

var gm: Node
var unlocked_levels: int = 1
var completed_levels: Array = []
var shadow_mode_unlocked: bool:
	get:
		return gm.shadow_mode_state.shadow_mode_unlocked if gm else false
	set(value):
		if gm:
			gm.set_shadow_mode_unlocked(value, "LevelManager.shadow_mode_unlocked")

var shadow_mode_enabled: bool:
	get:
		return gm.shadow_mode_state.shadow_mode_enabled if gm else false
	set(value):
		if gm:
			gm.set_shadow_mode_enabled(value, "LevelManager.shadow_mode_enabled")

var shadow_mode_tutorial_shown: bool:
	get:
		return gm.shadow_mode_state.shadow_mode_tutorial_shown if gm else false
	set(value):
		if gm:
			gm.set_shadow_mode_tutorial_shown(value, "LevelManager.shadow_mode_tutorial_shown")
var is_level_just_completed: bool = false
var is_video_playing: bool = false
var is_game_over_screen_active: bool = false

# Signals
signal level_loaded(level_num: int)
signal boss_defeated

const SHADOW_MODE_TUTORIAL_SCENE: PackedScene = preload("res://MainScenes/ShadowModeTutorial.tscn")
const BACKGROUND_MUSIC: AudioStream = preload("res://Textures/Music/Start.ogg")

func _ready() -> void:
	gm = GameManager


func load_level(level_num: int) -> void:
	if not is_level_unlocked(level_num):
		return
	
	# Reset score and lives for each level (per-level progression)
	gm.reset_for_new_level()
	
	# Reset player stats to default values
	gm.reset_player_stats()
	
	# Always set player lives to 3 for each level
	gm.player_lives = 3
	
	var level_path: String = "res://Levels/level_%d.tscn" % level_num
	
	# Stop background music before loading level scenes to prevent overlap
	if level_path != gm.get_start_scene_path() and level_path != gm.get_map_scene_path():
		AudioManager.stop_background_music()
	
	# Hide banner ad when loading a level
	gm.hide_banner_ad_if_initialized()
	
	gm.change_scene(level_path)
	await gm.get_tree().create_timer(0.5).timeout
	
	if gm.get_tree().current_scene:
		update_hud_visibility(level_num)
		
		gm.hide_banner_ad_if_initialized()
		
		level_loaded.emit(level_num)
	else:
		push_error("LevelManager: Failed to load level %d, no current scene" % level_num)

func complete_level(current_level: int) -> void:
	if gm.game_over and not gm.is_ad_revive_pending():
		return
	
	is_level_just_completed = true
	
	if gm.player_lives == 0:
		gm.player_lives = 2
	
	gm.save_progress_if_enabled()
	
	# Handle special level completions
	var should_transition_to_next_level: bool = true
	@warning_ignore("unused_variable")
	var is_boss_level: bool = current_level % 5 == 0 and current_level > 0
	
	# Handle special level completions
	if current_level == 5 and not shadow_mode_tutorial_shown:
		_show_shadow_mode_tutorial()
		should_transition_to_next_level = false
		#Don't set is_level_just_completed = false here, it interferes with level unlocking
	#elif current_level == 20 and not is_video_playing:
	#	_play_ending_video()
	#	should_transition_to_next_level = false
	
	# Increment completion count regardless of whether it's first time
	increment_level_completion_count(current_level)

	# Only add to completed levels if not already completed
	if not completed_levels.has(current_level):
		completed_levels.append(current_level)
		gm.level_star_earned.emit(current_level)
		gm.save_progress_if_enabled()
		
		# Check if level 10 is completed for the first time to unlock difficulty selection
		if current_level == 10:
			_unlock_difficulty_selection()
	
	# For boss levels, emit the level_completed signal to show boss clear screen
	# For non-boss levels, also emit the level_completed signal
	gm.level_completed.emit(current_level)
	
	# Unlock next level (but only if it's the next sequential level)
	var next_level: int = current_level + 1
	if next_level == unlocked_levels + 1:  # Only unlock if it's the next sequential level
		unlocked_levels = next_level
		gm.save_progress_if_enabled()
		gm.level_unlocked.emit(next_level)
	
	if should_transition_to_next_level:
		is_level_just_completed = false

func _unlock_difficulty_selection() -> void:
	# Trigger difficulty unlock notification when level 10 is completed
	# This will show the difficulty_unlocked UI on the next map visit
	if gm.save_manager:
		gm.save_manager.difficulty_unlocked_showed = false
		gm.save_progress_if_enabled()
	print("LevelManager: Difficulty selection unlocked after completing level 10")

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
		
		gm.set_shadow_mode_tutorial_shown(true, "LevelManager._show_shadow_mode_tutorial")
		gm.save_progress_if_enabled()
		
		# Properly reset the level completion flag after showing tutorial
		is_level_just_completed = false
	else:
		push_error("LevelManager: Cannot add tutorial: No current scene available")

#func _play_ending_video() -> void:
#	var current_scene = gm.get_tree().current_scene
#	if current_scene and ResourceLoader.exists(gm.scene_manager.VIDEO_SCENE):
#		is_video_playing = true
#		AudioManager.lower_bus_volumes_except(["Video", "Master"], -10.0)
#		
#		var video_layer = CanvasLayer.new()
#		video_layer.name = "VideoPlaybackLayer"
#		video_layer.layer = 10
#		
#		var video_scene: Node = load(gm.scene_manager.VIDEO_SCENE).instantiate()
#		video_layer.add_child(video_scene)
#		current_scene.add_child(video_layer)
#		
#		if video_scene.has_signal("finished"):
#			video_scene.finished.connect(_on_video_finished.bind(video_layer))
#		else:
#			await gm.get_tree().create_timer(10.0).timeout
#			_on_video_finished(video_layer)
#	else:
#		push_error("LevelManager: Cannot play video: No current scene or VideoPlayback.tscn missing")

#func _on_video_finished(video_layer: CanvasLayer) -> void:
#	AudioManager.restore_bus_volumes()
#	video_layer.queue_free()
#	is_video_playing = false
#	gm.change_scene(gm.scene_manager.START_SCREEN_SCENE)
#	is_level_just_completed = false

func unlock_next_level(current_level: int) -> void:
	var next_level: int = current_level + 1
	var next_level_path: String = "res://Levels/level_%d.tscn" % next_level
	if ResourceLoader.exists(next_level_path):
		# Reset player stats before loading next level
		gm.reset_player_stats()
		# Unlock the next level in the save data
		if next_level > unlocked_levels:
			unlocked_levels = next_level
			gm.save_progress_if_enabled()
		gm.change_scene(next_level_path)
	else:
		gm.change_scene(gm.get_map_scene_path())
	
	is_level_just_completed = false

func unlock_shadow_mode() -> void:
	if not shadow_mode_unlocked:
		gm.set_shadow_mode_unlocked(true, "LevelManager.unlock_shadow_mode")
		gm.save_progress_if_enabled()
		update_hud_visibility()

func activate_shadow_mode(duration: float = 2.0) -> void:
	if shadow_mode_unlocked:
		gm.request_shadow_mode_activate(duration, "LevelManager.activate_shadow_mode")

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
	# Progressive level unlock system
	# Level 1: Always unlocked (starting level)
	# Levels 2-10: Unlocked after completing the previous level
	# Levels 11-20: Unlocked after completing level 10
	# Levels 21-30: Unlocked after completing level 20
	
	if level == 1:
		# Starting level - always unlocked
		return true
	elif level <= 10:
		# Easy levels 2-10 - unlocked after completing previous level
		return is_level_completed(level - 1)
	elif level <= 20:
		# Medium levels 11-20 - unlocked after completing level 10
		return is_level_completed(10)
	elif level <= 30:
		# Hard levels 21-30 - unlocked after completing level 20
		return is_level_completed(20)
	else:
		# Beyond level 30 - use default unlock system
		return level <= unlocked_levels

func is_level_completed(level: int) -> bool:
	return completed_levels.has(level)

# Add functions for level completion count tracking
func get_level_completion_count(level: int) -> int:
	if gm.save_manager:
		return gm.save_manager.get_level_completion_count(level)
	return 0

func increment_level_completion_count(level: int) -> void:
	if gm.save_manager:
		gm.save_manager.increment_level_completion_count(level)
		gm.save_progress_if_enabled()

func get_current_level() -> int:
	var scene_path: String = gm.get_tree().current_scene.scene_file_path if gm.get_tree().current_scene else ""
	var regex = RegEx.new()
	regex.compile("level_(\\d+)\\.tscn")
	var result = regex.search(scene_path)
	if result:
		return int(result.get_string(1))
	return 0

func reset_level_state() -> void:
	gm.request_shadow_mode_deactivate_silent("LevelManager.reset_level_state")
	is_level_just_completed = false
	is_video_playing = false
	is_game_over_screen_active = false

func reset_level_progress() -> void:
	unlocked_levels = 1
	gm.set_shadow_mode_unlocked(false, "LevelManager.reset_level_progress")
	gm.set_shadow_mode_tutorial_shown(false, "LevelManager.reset_level_progress")
	completed_levels = []

func handle_node_added(node: Node) -> void:
	if node is WaveManager:
		# Safely connect to WaveManager signals
		if node.has_signal("wave_started") and not node.wave_started.is_connected(_on_wave_started):
			node.wave_started.connect(_on_wave_started)
			
		if node.has_signal("all_waves_cleared") and not node.all_waves_cleared.is_connected(_on_all_waves_cleared):
			node.all_waves_cleared.connect(_on_all_waves_cleared)
	
	if node.is_in_group(gm.GROUP_BOSS):
		if node is Area2D and node.has_signal("boss_defeated"):
			if not node.boss_defeated.is_connected(_on_boss_defeated):
				node.boss_defeated.connect(_on_boss_defeated)

		if node.has_signal("unlock_shadow_mode"):
			if not node.unlock_shadow_mode.is_connected(_on_unlock_shadow_mode):
				node.unlock_shadow_mode.connect(_on_unlock_shadow_mode)

	# Additional safety check for other node types
	if node.has_signal("level_completed"):
		if not node.level_completed.is_connected(_on_level_completed):
			node.level_completed.connect(_on_level_completed)

func _on_level_completed(_level_num: int) -> void:
	# Default implementation - can be overridden
	pass


func _on_wave_started(current_wave: int, total_waves: int) -> void:
	gm.wave_started.emit(current_wave, total_waves)

func _on_all_waves_cleared() -> void:
	gm.all_waves_cleared.emit()

func _on_boss_defeated() -> void:
	gm.score += 1000
	var current_level: int = get_current_level()
	if current_level == 5:
		unlock_shadow_mode()
	
	# Emit boss_defeated signal for the Level scene to handle
	boss_defeated.emit()
	
	# For all levels, complete the level properly through the unified flow
	# But let the Level scene decide which screen to show based on first time completion
	# complete_level(current_level)  # This will be handled by the Level scene

func _on_unlock_shadow_mode() -> void:
	unlock_shadow_mode()

func _exit_tree() -> void:
	# Disconnect any connected signals to prevent memory leaks
	# Note: In autoloads, this is rarely called, but good practice
	pass

func _on_level_selected(level_num: int) -> void:
	if is_level_unlocked(level_num):
		load_level(level_num)
