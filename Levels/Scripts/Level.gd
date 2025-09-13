extends Node

# === NODES ===
@onready var game_over_screen: Control = $"../CanvasLayer/GameOverScreen"
@onready var pause_menu: Control = $"../CanvasLayer/PauseMenu"
@onready var level_completed: Control = $"../CanvasLayer/LevelCompleted"
@onready var boss_clear: Control = $"../CanvasLayer/BossClear"
@onready var hud: Control = $"../CanvasLayer/HUD"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var pause_button: Button = $"../CanvasLayer/Pause"
@onready var wave_manager: WaveManager = $"../WaveManager"

# === EXPORTED ===
@export var level_num: int = 1
@export var waves: Array[WaveConfig] = []
@export var debug_mode: bool = false

# === VARIABLES ===
var has_completed_level: bool = false
var game_over: bool = false
var waves_initialized: bool = false
var saved_shadow_charge: float = 0.0
var player_scene: PackedScene = preload("res://Ships/Player_Ship1.tscn")
var has_spawned_player: bool = false

# Signals 
@warning_ignore("unused_signal")
signal Victory_pose()

# === READY ===
func _ready():
	# Add to LevelManager group
	game_over_screen.hide()
	pause_menu.hide()
	level_completed.hide()
	if boss_clear:
		boss_clear.hide()
	game_over = GameManager.game_over

	# HUD check
	if not hud:
		push_warning("HUD node not found")
	else:
		var shadow_button = hud.get_node_or_null("ShadowModeButton")
		if not shadow_button:
			push_warning("ShadowModeButton not found in HUD")

	# Pause button
	if not pause_button:
		push_error("PauseButton not found")
	else:
		if not pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.connect(_on_pause_pressed)

	# Connect signals
	print("Level.gd: Connecting GameManager signals")
	if not GameManager.game_over_triggered.is_connected(_game_over_triggered):
		GameManager.game_over_triggered.connect(_game_over_triggered)
		print("Level.gd: Connected game_over_triggered signal")
	else:
		print("Level.gd: game_over_triggered signal already connected")
		
	if not GameManager.game_paused.is_connected(_on_game_paused):
		GameManager.game_paused.connect(_on_game_paused)
		print("Level.gd: Connected game_paused signal")
	else:
		print("Level.gd: game_paused signal already connected")
		
	if not GameManager.level_completed.is_connected(_on_level_completed):
		GameManager.level_completed.connect(_on_level_completed)
		print("Level.gd: Connected level_completed signal")
	else:
		print("Level.gd: level_completed signal already connected")
		
	if not GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
		print("Level.gd: Connected shadow_mode_activated signal")
	else:
		print("Level.gd: shadow_mode_activated signal already connected")
		
	if not GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
		print("Level.gd: Connected shadow_mode_deactivated signal")
	else:
		print("Level.gd: shadow_mode_deactivated signal already connected")
	
	print("Level.gd: Connecting wave_manager signals")
	if not wave_manager.wave_started.is_connected(hud._on_wave_started):
		wave_manager.wave_started.connect(hud._on_wave_started)
		print("Level.gd: Connected wave_manager.wave_started to hud._on_wave_started")
	else:
		print("Level.gd: wave_manager.wave_started already connected to hud._on_wave_started")
		
	if not wave_manager.all_waves_cleared.is_connected(_on_wave_manager_all_waves_cleared):
		wave_manager.all_waves_cleared.connect(_on_wave_manager_all_waves_cleared)
		print("Level.gd: Connected wave_manager.all_waves_cleared signal")
	else:
		print("Level.gd: wave_manager.all_waves_cleared signal already connected")
	
	get_tree().get_root().connect("go_back_requested",_on_pause_pressed)
	
	# Connect game_over_screen signals for revive functionality
	if game_over_screen and game_over_screen.has_signal("player_revived"):
		if not game_over_screen.player_revived.is_connected(_on_player_revived):
			game_over_screen.player_revived.connect(_on_player_revived)
			print("Level.gd: Connected to game_over_screen.player_revived signal")
		else:
			print("Level.gd: game_over_screen.player_revived signal already connected")
	else:
		push_warning("Level.gd: game_over_screen or player_revived signal not found")
		
	if not GameManager.level_manager.level_loaded.is_connected(_on_level_loaded):
		GameManager.level_manager.level_loaded.connect(_on_level_loaded)
		print("Level.gd: Connected to level_loaded signal")
	else:
		print("Level.gd: level_loaded signal already connected")
	
	# Initialize waves
	_initialize_waves()
	
	# Fallback player spawning
	_check_and_spawn_player()

# === WAVE VALIDATION ===
func validate_wave_config(wave: WaveConfig, wave_index: int) -> bool:
	if not wave:
		push_warning("LevelManager: Wave %d is null" % (wave_index + 1))
		return false
	
	# Check enemy or boss scene
	var enemy_scene = wave.get_enemy_scene()
	if not enemy_scene or not enemy_scene.can_instantiate():
		push_warning("LevelManager: Wave %d has invalid or missing enemy/boss scene" % (wave_index + 1))
		return false
	
	# Check boss wave consistency
	if wave.is_boss_wave() and wave.get_enemy_count() != 1:
		push_warning("LevelManager: Wave %d is a boss wave but has enemy_count != 1 (%d)" % [wave_index + 1, wave.get_enemy_count()])
		return false
	
	# Check enemy density
	var valid_densities = ["Sparse", "Normal", "Dense", "Maximum"]
	if not wave.enemy_density in valid_densities:
		push_warning("LevelManager: Wave %d has invalid enemy_density '%s'" % [wave_index + 1, wave.enemy_density])
		return false
	
	# Check formation center
	if wave.formation_center.x < 0 or wave.formation_center.y < 0:
		push_warning("LevelManager: Wave %d has invalid formation_center %s" % [wave_index + 1, wave.formation_center])
		return false
	
	# Check formation type for non-boss waves
	if not wave.is_boss_wave():
		var valid_formations = formation_enums.FormationType.values()
		if not wave.get_formation_type() in valid_formations:
			push_warning("LevelManager: Wave %d has invalid formation_type %d" % [wave_index + 1, wave.get_formation_type()])
			return false
	
	# Check enemy type for non-boss waves
	if not wave.is_boss_wave():
		var valid_enemies = ["mob1", "mob2", "mob3", "mob4", "SlowShooter", "FastEnemy", "BouncerEnemy","BomberBug"]
		if not wave.enemy_type in valid_enemies:
			push_warning("LevelManager: Wave %d has invalid enemy_type '%s'" % [wave_index + 1, wave.enemy_type])
			return false
	
	if debug_mode:
		var debug_string = wave.as_debug_string() if wave.has_method("as_debug_string") else "WaveConfig"
		print("LevelManager: Validated Wave %d: %s" % [wave_index + 1, debug_string])
	
	return true

# === WAVE INITIALIZATION ===
func _initialize_waves() -> void:
	if not waves:
		return
	
	for i in range(waves.size()):
		var wave = waves[i]
		if validate_wave_config(wave, i):
			if debug_mode:
				var debug_string = wave.as_debug_string() if wave.has_method("as_debug_string") else "WaveConfig"
				print("LevelManager: Wave %d: Validated %s (Boss: %s, Enemy Count: %d)" % [
					i + 1,
					debug_string,
					wave.is_boss_wave(),
					wave.get_enemy_count()
				])
	
	# Send waves to WaveManager and start spawning
	wave_manager.set_waves(waves)
	wave_manager.current_level = level_num
	wave_manager.start_waves()
	waves_initialized = true
	if debug_mode:
		print("LevelManager: Initialized %d waves for level %d" % [waves.size(), level_num])

# === PLAYER SPAWNING ===
func _spawn_player(lives: int) -> void:
	var player_scene_path = "res://Ships/Player_%s.tscn" % GameManager.player_manager.selected_ship_id
	if ResourceLoader.exists(player_scene_path):
		player_scene = load(player_scene_path)
	else:
		# Fallback to default player scene
		push_warning("Player scene not found: %s, using default Player_Ship1.tscn" % player_scene_path)
	
	var player_instance = player_scene.instantiate()
	player_instance.global_position = GameManager.player_manager.player_spawn_position
	call_deferred("add_child", player_instance)
	player_instance.call_deferred("set_lives", lives)
	has_spawned_player = true
	print("Level.gd: Spawned player with ship_id: %s with %d lives" % [GameManager.player_manager.selected_ship_id, lives])
	
func _check_and_spawn_player() -> void:
	if not has_spawned_player and not get_tree().get_nodes_in_group("Player"):
		await get_tree().create_timer(0.5).timeout
		if GameManager.level_manager.get_current_level() == level_num and not has_spawned_player:
			_spawn_player(GameManager.player_lives)

func _on_level_loaded(_level_num: int) -> void:
	print("Level.gd: Received level_loaded signal for level %d" % _level_num)
	_spawn_player(GameManager.player_lives)

# === PAUSE TOGGLE & TWEEN ===
func _toggle_pause_menu():
	if has_completed_level:
		print("level completed")
		return
	if get_tree().paused:
		get_tree().paused = false
		GameManager.is_paused = false
		_hide_pause_menu()
	else:
		get_tree().paused = true
		GameManager.is_paused = true
		_show_pause_menu()

func _show_pause_menu():
	pause_menu.visible = true
	animation_player.play("fade_in")

func _hide_pause_menu():
	if not is_inside_tree() or not pause_menu:
		return
		
	var tween = create_tween()
	if tween:
		tween.tween_property(pause_menu, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		if pause_menu:  # Check again after await
			pause_menu.visible = false

func _on_pause_pressed():
	_toggle_pause_menu()

func _on_game_paused(paused: bool):
	if game_over or has_completed_level:
		_hide_pause_menu()
		get_tree().paused = false
		GameManager.is_paused = false
	else:
		get_tree().paused = paused
		GameManager.is_paused = paused
		if paused:
			_show_pause_menu()
		else:
			_hide_pause_menu()

# === GAME OVER ===
func _game_over_triggered():
	if GameManager.level_manager.is_level_just_completed:
		return
	game_over = true
	GameManager.game_over = true
	get_tree().paused = false
	pause_menu.hide()
	if hud and hud.has_method("update_charge_display"):
		saved_shadow_charge = hud.current_charge if hud.current_charge is float else 0.0
	game_over_screen._on_score_updated(GameManager.score)
	game_over_screen.modulate.a = 0.0
	game_over_screen.show()
	if is_inside_tree() and game_over_screen:
		var tween = create_tween()
		if tween:
			tween.tween_property(game_over_screen, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# === REVIVE ===
func _on_player_revived():
	if not GameManager.is_revive_pending:
		return
	game_over = false
	GameManager.game_over = false

	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		_spawn_player(2)
	else:
		player.revive(2)

	if hud and hud.has_method("update_charge_display"):
		hud.current_charge = saved_shadow_charge
		hud.update_charge_display()

	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)
	GameManager.revive_player(2)

func revive_player():
	_on_player_revived()

# === LEVEL COMPLETE ===
func _on_level_completed(_level_num: int):
	print("[Level Debug] _on_level_completed called with level: %d" % _level_num)
	AudioManager.mute_bus("Bullet", true)
	emit_signal("Victory_pose")
	
	# Wait for player victory pose animation to complete before showing level completed UI
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_signal("victory_pose_done"):
		# Wait for the victory pose animation to finish
		await player.victory_pose_done
		
	_show_level_completed_ui()
	# Check if this is a boss level
	if _is_boss_level(_level_num):
		print("[Level Debug] Boss level detected")
		# Check if this is the first time completing this boss
		var boss_levels_completed = GameManager.save_manager.boss_levels_completed
		var is_first_time = not boss_levels_completed.has(_level_num)
		
		if is_first_time:
			print("[Level Debug] First time completing boss level %d, showing boss clear UI" % _level_num)
			_show_boss_clear_ui()
		else:
			print("[Level Debug] Boss level %d already completed before, showing level completed UI" % _level_num)
			_show_level_completed_ui()
	else:
		print("[Level Debug] Non-boss level, showing level completed UI")
		_show_level_completed_ui()

func _show_level_completed_ui():
	print("[Level Debug] _show_level_completed_ui called")
	get_tree().paused = false
	pause_menu.hide()
	level_completed.modulate.a = 0.0
	level_completed.show()
	# Initialize the level completed screen
	print("[Level Debug] Calling level_completed.initialize()")
	if level_completed.has_method("initialize"):
		level_completed.initialize()
		print("[Level Debug] level_completed.initialize() called successfully")
	else:
		print("[Level Debug] level_completed does not have initialize method!")
		
	# Call the _on_level_completed function directly
	var current_level_num = GameManager.level_manager.get_current_level()
	print("[Level Debug] Calling level_completed._on_level_completed(%d)" % current_level_num)
	if level_completed.has_method("_on_level_completed"):
		level_completed._on_level_completed(current_level_num)
		print("[Level Debug] level_completed._on_level_completed() called successfully")
	else:
		print("[Level Debug] level_completed does not have _on_level_completed method!")
		
	if is_inside_tree() and level_completed:
		var tween = create_tween()
		if tween:
			tween.tween_property(level_completed, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	GameManager.save_manager.save_progress()

func _show_boss_clear_ui():
	print("[Level Debug] _show_boss_clear_ui called")
	get_tree().paused = false
	pause_menu.hide()
	if boss_clear:
		boss_clear.modulate.a = 0.0
		boss_clear.show()
		# Initialize the boss clear screen
		print("[Level Debug] Calling boss_clear.initialize()")
		if boss_clear.has_method("initialize"):
			boss_clear.initialize()
			print("[Level Debug] boss_clear.initialize() called successfully")
		else:
			print("[Level Debug] boss_clear does not have initialize method!")
			
		# Call the _on_boss_level_completed function directly
		var current_level_num = GameManager.level_manager.get_current_level()
		print("[Level Debug] Calling boss_clear._on_boss_level_completed(%d)" % current_level_num)
		if boss_clear.has_method("_on_boss_level_completed"):
			boss_clear._on_boss_level_completed(current_level_num)
			print("[Level Debug] boss_clear._on_boss_level_completed() called successfully")
		else:
			print("[Level Debug] boss_clear does not have _on_boss_level_completed method!")
			
		if is_inside_tree():
			var tween = create_tween()
			if tween:
				tween.tween_property(boss_clear, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Fallback to normal level completed if boss_clear scene not available
		print("[Level] Boss clear scene not found, showing normal level completed")
		_show_level_completed_ui()
	GameManager.save_manager.save_progress()

# === BOSS LEVEL DETECTION ===
func _is_boss_level(level_number: int) -> bool:
	# Boss levels occur every 5 levels: 5, 10, 15, 20, etc.
	return level_number % 5 == 0 and level_number > 0

# === WAVE CLEARED ===
func _on_wave_manager_all_waves_cleared():
	print("Level.gd: _on_wave_manager_all_waves_cleared called")
	if not has_completed_level:
		has_completed_level = true
		if hud and hud.has_method("reset_charge"):
			hud.reset_charge()
		if wave_manager.all_waves_cleared.is_connected(_on_wave_manager_all_waves_cleared):
			wave_manager.all_waves_cleared.disconnect(_on_wave_manager_all_waves_cleared)
		
		# Check if the last wave was a boss wave
		var is_boss_wave = false
		if wave_manager and wave_manager.current_wave_config and wave_manager.current_wave_config.is_boss_wave():
			is_boss_wave = true
		
		# For level 5, we always want to show the boss clear screen
		var current_level_num = GameManager.level_manager.get_current_level()
		if current_level_num == 5:
			is_boss_wave = true
		
		if is_boss_wave:
			print("Level.gd: Boss wave cleared, waiting for boss defeated signal")
		else:
			print("Level.gd: Non-boss wave cleared, completing level normally")
			GameManager.level_manager.complete_level(level_num)

# === SHADOW MODE ===
func _on_shadow_mode_activated():
	wave_manager._on_shadow_mode_activated()

func _on_shadow_mode_deactivated():
	wave_manager._on_shadow_mode_deactivated()

func handle_node_added(node: Node) -> void:
	print("Level.gd: handle_node_added called for node: %s" % node.name)
	if node.is_in_group("Boss"):
		print("Level.gd: New boss node added: %s" % node.name)
		if node.has_signal("boss_defeated"):
			print("Level.gd: Boss node has boss_defeated signal")
			if not node.boss_defeated.is_connected(_on_boss_defeated):
				node.boss_defeated.connect(_on_boss_defeated)
				print("Level.gd: Connected boss_defeated signal")
			else:
				print("Level.gd: boss_defeated signal already connected")
		else:
			print("Level.gd: Boss node does not have boss_defeated signal")

func _on_boss_defeated() -> void:
	print("Level.gd: _on_boss_defeated called")
	if not GameManager.is_revive_pending:
		print("Level.gd: Revive not pending, processing boss defeat")
		GameManager.score += 1000
		var current_level: int = GameManager.level_manager.get_current_level()
		print("Level.gd: Current level is %d" % current_level)
		if current_level == 5:
			print("Level.gd: Unlocking shadow mode for level 5")
			GameManager.level_manager.unlock_shadow_mode()
		
		# For boss levels, complete the level properly
		if current_level % 5 == 0:
			print("Level.gd: Boss level detected, emitting level_completed signal")
			# Emit the level completed signal which will trigger the boss clear screen
			GameManager.level_completed.emit(current_level)
		else:
			print("Level.gd: Non-boss level, completing level normally")
			# For non-boss levels, complete normally
			GameManager.level_manager.complete_level(current_level)
	else:
		print("Level.gd: Revive pending, ignoring boss defeat")
