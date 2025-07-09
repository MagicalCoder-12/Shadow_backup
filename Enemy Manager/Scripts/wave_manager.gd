extends Node2D
class_name WaveManager

# Signals for wave progression and events
signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(current_wave: int, wave_config: WaveConfig)
signal all_waves_cleared()
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D)

# Configuration
@export var wave_delay: float = 3.0
@export var spawn_indicator_texture: Texture2D = preload("res://Textures/UI/Indicator.png")
@export var formation_manager_scene: PackedScene # Reference to FormationManager scene
@export var debug_mode: bool = true # Enabled for better logging
@export var current_level: int = 1

# Wave management
var waves: Array[WaveConfig] = []
var current_wave: int = 0
var enemies_alive: int = 0
var wave_in_progress: bool = false
var waiting_for_next_wave: bool = false
var total_waves: int = 0
var current_wave_config: WaveConfig
var current_boss: Node2D
var level_manager: Node # Reference to LevelManager for validation
var game_manager: Node # Reference to GameManager for pause and ad states

# Formation and enemy tracking
var active_formations: Array[Node2D] = []
var active_enemies: Array[Node2D] = []
var formation_manager: Node2D

# Boss and special effects
@onready var boss_music: AudioStreamPlayer = $BossMusic
var _boss_scene: PackedScene
var _boss_spawn_pos: Vector2

# Wave timing
var wave_start_time: float = 0.0
var wave_completion_time: float = 0.0

func _ready():
	# Find LevelManager using node group
	var level_managers = get_tree().get_nodes_in_group("LevelManager")
	if level_managers.is_empty():
		push_warning("WaveManager: No LevelManager found in 'LevelManager' group")
	else:
		level_manager = level_managers[0]
		if not level_manager.has_method("validate_wave_config"):
			push_warning("WaveManager: LevelManager found but missing validate_wave_config method")
	
	# Find GameManager using node group
	var game_managers = get_tree().get_nodes_in_group("GameManager")
	if game_managers.is_empty():
		push_warning("WaveManager: No GameManager found in 'GameManager' group")
	else:
		game_manager = game_managers[0]
		if not game_manager.has_signal("game_paused"):
			push_warning("WaveManager: GameManager found but missing game_paused signal")
		else:
			# Connect to game_paused signal
			game_manager.game_paused.connect(_on_game_paused)
			if debug_mode:
				print("WaveManager: Connected to GameManager.game_paused signal")
	
	# Validate formation manager scene
	if not formation_manager_scene:
		push_warning("WaveManager: No formation_manager_scene assigned. Boss waves will work, but formations require a valid FormationManager scene.")
	else:
		if not ResourceLoader.exists(formation_manager_scene.resource_path):
			push_error("WaveManager: Invalid formation_manager_scene path: %s" % formation_manager_scene.resource_path)
			formation_manager_scene = null
	
	if debug_mode:
		print("WaveManager: Initialized with formation_manager_scene: %s (Level: %d)" % [formation_manager_scene.resource_path if formation_manager_scene else "None", current_level])

func _on_game_paused(paused: bool) -> void:
	if debug_mode:
		print("WaveManager: Game pause state changed to %s (Level: %d)" % [paused, current_level])
	if paused or (game_manager and game_manager.is_ad_showing):
		if debug_mode:
			print("WaveManager: Pausing wave timer due to game pause or ad showing")
	else:
		if debug_mode:
			print("WaveManager: Resuming wave timer")

func set_waves(waves_: Array[WaveConfig]):
	waves = waves_
	total_waves = waves.size()
	current_wave = 0
	
	# Validate all wave configurations
	for i in range(waves.size()):
		var wave = waves[i]
		if level_manager and level_manager.has_method("validate_wave_config"):
			if not level_manager.validate_wave_config(wave, i):
				push_error("WaveManager: Wave %d failed validation, skipping" % (i + 1))
				waves[i] = null
		else:
			# Perform robust fallback validation
			if not wave or not wave.get_enemy_scene() or not wave.get_enemy_scene().can_instantiate():
				push_error("WaveManager: Wave %d has invalid or missing enemy/boss scene" % (i + 1))
				waves[i] = null
			else:
				if wave.is_boss_wave():
					if wave.get_enemy_count() != 1:
						push_warning("WaveManager: Wave %d is boss wave but enemy_count != 1 (%d)" % [i + 1, wave.get_enemy_count()])
				else:
					var valid_formations = formation_enums.FormationType.values()
					if not wave.get_formation_type() in valid_formations:
						push_warning("WaveManager: Wave %d has invalid formation_type %d" % [i + 1, wave.get_formation_type()])
						waves[i] = null
					var valid_enemies = ["mob1", "mob2", "mob3", "mob4", "SlowShooter", "FastEnemy", "BouncerEnemy", "BomberBug"]
					if not wave.enemy_type in valid_enemies:
						push_warning("WaveManager: Wave %d has invalid enemy_type '%s'" % [i + 1, wave.enemy_type])
						waves[i] = null
				# Validate difficulty
				if wave.difficulty < 0 or wave.difficulty >= formation_enums.DifficultyLevel.keys().size():
					push_warning("WaveManager: Wave %d has invalid difficulty %d" % [i + 1, wave.difficulty])
					waves[i] = null
	
	# Remove invalid waves
	waves = waves.filter(func(w): return w != null)
	total_waves = waves.size()
	
	if debug_mode:
		print("WaveManager: Loaded %d valid waves for level %d" % [total_waves, current_level])
		for i in range(waves.size()):
			var debug_string = waves[i].as_debug_string() if waves[i].has_method("as_debug_string") else "WaveConfig"
			print("  Wave %d: %s" % [i + 1, debug_string])

func start_waves():
	if waves.is_empty():
		push_warning("WaveManager: No valid waves configured for level %d" % current_level)
		return
	
	current_wave = 0
	start_next_wave()

func start_next_wave():
	if debug_mode:
		print("DEBUG: start_next_wave() called - wave_in_progress: %s, waiting_for_next_wave: %s, current_wave: %d/%d, is_paused: %s, is_ad_showing: %s" % [
			wave_in_progress, waiting_for_next_wave, current_wave, total_waves,
			game_manager.is_paused if game_manager else false,
			game_manager.is_ad_showing if game_manager else false
		])
	
	if wave_in_progress or waiting_for_next_wave:
		return
	
	if current_wave >= total_waves:
		if debug_mode:
			print("DEBUG: All waves completed - emitting all_waves_cleared")
		all_waves_cleared.emit()
		return
	
	current_wave += 1
	
	if current_wave - 1 >= waves.size():
		push_error("WaveManager: Wave index out of bounds: %d >= %d" % [current_wave - 1, waves.size()])
		return
		
	current_wave_config = waves[current_wave - 1]
	
	# Validate wave before starting
	if level_manager and level_manager.has_method("validate_wave_config") and not level_manager.validate_wave_config(current_wave_config, current_wave - 1):
		push_warning("WaveManager: Skipping invalid Wave %d" % current_wave)
		_complete_wave()
		return
	
	wave_in_progress = true
	wave_start_time = Time.get_unix_time_from_system()
	
	wave_started.emit(current_wave, total_waves)
	
	if debug_mode:
		var difficulty_str = "Unknown"
		if current_wave_config and current_wave_config.difficulty >= 0 and current_wave_config.difficulty < formation_enums.DifficultyLevel.keys().size():
			difficulty_str = formation_enums.DifficultyLevel.keys()[current_wave_config.difficulty]
		print("WaveManager: Starting Wave %d (Difficulty: %s, Boss: %s, Level: %d)" % [
			current_wave, 
			difficulty_str,
			current_wave_config.is_boss_wave() if current_wave_config else false,
			current_level
		])
	
	start_wave()

func start_wave():
	if not current_wave_config:
		push_error("WaveManager: No current wave config for Wave %d (Level: %d)" % [current_wave, current_level])
		return
	
	if not current_wave_config.get_enemy_scene():
		push_warning("WaveManager: Wave %d missing enemy or boss scene" % current_wave)
		wave_in_progress = false
		_complete_wave()
		return
	
	# Show spawn indicator
	_show_spawn_indicator(current_wave_config.formation_center)
	
	# Determine if this is a boss wave or formation wave
	if current_wave_config.is_boss_wave():
		spawn_boss()
	else:
		spawn_formation()

func spawn_formation():
	# Create formation manager if we don't have one
	if not formation_manager and formation_manager_scene:
		formation_manager = formation_manager_scene.instantiate()
		if not formation_manager is FormationManager:
			push_error("WaveManager: formation_manager_scene is not a FormationManager for Wave %d (Level: %d)" % [current_wave, current_level])
			formation_manager.queue_free()
			formation_manager = null
			return
		add_child(formation_manager)
		# Connect signals
		if not formation_manager.enemy_died.is_connected(_on_enemy_killed):
			formation_manager.enemy_died.connect(_on_enemy_killed)
			if debug_mode:
				print("WaveManager: Connected FormationManager.enemy_died to _on_enemy_killed for Wave %d" % current_wave)
	
	if not formation_manager:
		push_error("WaveManager: No FormationManager available for Wave %d (Level: %d)" % [current_wave, current_level])
		wave_in_progress = false
		_complete_wave()
		return
	
	# Use formation manager to spawn the formation
	formation_manager.spawn_formation(current_wave_config)
	enemies_alive = current_wave_config.get_enemy_count()
	
	# Connect to enemy_spawned signal to track enemies
	if not formation_manager.enemy_spawned.is_connected(_on_enemy_spawned):
		formation_manager.enemy_spawned.connect(_on_enemy_spawned)
	
	if debug_mode:
		var difficulty_str = "Unknown"
		if current_wave_config.difficulty >= 0 and current_wave_config.difficulty < formation_enums.DifficultyLevel.keys().size():
			difficulty_str = formation_enums.DifficultyLevel.keys()[current_wave_config.difficulty]
		print("WaveManager: Formation spawned with %d enemies (Type: %s, Difficulty: %s, Level: %d)" % [
			enemies_alive,
			formation_enums.FormationType.keys()[current_wave_config.get_formation_type()],
			difficulty_str,
			current_level
		])

func spawn_boss():
	_boss_scene = current_wave_config.get_enemy_scene()
	_boss_spawn_pos = current_wave_config.formation_center
	
	if debug_mode:
		print("WaveManager: Attempting to spawn boss for Wave %d at %s (Level: %d)" % [current_wave, _boss_spawn_pos, current_level])
	
	# Validate boss scene
	if not _boss_scene or not _boss_scene.can_instantiate():
		push_error("WaveManager: Invalid or missing boss scene for Wave %d (Level: %d)" % [current_wave, current_level])
		wave_in_progress = false
		_complete_wave()
		return
	
	if boss_music and boss_music.stream and not boss_music.playing:
		if debug_mode:
			print("WaveManager: Playing boss music for Wave %d (Level: %d)" % [current_wave, current_level])
		AudioManager.lower_bus_volumes_except(["Boss", "Master"], -25.0)
		_start_red_blink_effect()
		boss_music.play()
	else:
		if debug_mode:
			print("WaveManager: No boss music or already playing, spawning boss immediately for Wave %d (Level: %d)" % [current_wave, current_level])
		_spawn_boss_immediately()

func _spawn_boss_immediately():
	_stop_red_blink_effect()
	AudioManager.restore_bus_volumes()
	
	if not _boss_scene:
		push_error("WaveManager: No boss scene to instantiate for Wave %d (Level: %d)" % [current_wave, current_level])
		wave_in_progress = false
		_complete_wave()
		return
	
	if debug_mode:
		print("WaveManager: Instantiating boss for Wave %d (Level: %d)" % [current_wave, current_level])
	
	var boss = _boss_scene.instantiate()
	if not boss is Area2D:
		push_error("WaveManager: Boss scene is not an Area2D for Wave %d (Level: %d)" % [current_wave, current_level])
		boss.queue_free()
		wave_in_progress = false
		_complete_wave()
		return
	
	boss.global_position = _boss_spawn_pos
	get_tree().current_scene.call_deferred("add_child", boss)
	current_boss = boss
	active_enemies.append(boss)
	
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_killed)
		if debug_mode:
			print("WaveManager: Connected boss_defeated signal for Wave %d (Level: %d)" % [current_wave, current_level])
	else:
		push_warning("WaveManager: Boss does not have 'boss_defeated' signal for Wave %d (Level: %d)" % [current_wave, current_level])
	
	# Connect minion death signals for boss
	if boss.has_signal("boss_minion_died"):
		boss.boss_minion_died.connect(_on_minion_died)
		if debug_mode:
			print("WaveManager: Connected boss_minion_died signal for boss in Wave %d (Level: %d)" % [current_wave, current_level])
	
	enemy_spawned.emit(boss)
	
	if debug_mode:
		print("WaveManager: Boss spawned successfully at %s for Wave %d (Level: %d)" % [boss.global_position, current_wave, current_level])
	
	_boss_scene = null
	_boss_spawn_pos = Vector2.ZERO
	enemies_alive = 1

func _on_formation_complete():
	if debug_mode:
		print("WaveManager: Formation completed for Wave %d (Level: %d)" % [current_wave, current_level])

func _on_enemy_spawned(enemy: Node2D):
	if not is_instance_valid(enemy):
		if debug_mode:
			print("WaveManager: Attempted to spawn invalid enemy for Wave %d (Level: %d)" % [current_wave, current_level])
		return
	
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	if enemy.has_signal("died"):
		if not enemy.died.is_connected(_on_enemy_killed):
			enemy.died.connect(_on_enemy_killed.bind(enemy))
	else:
		if debug_mode:
			print("WaveManager: Enemy at %s does not have 'died' signal (Wave: %d, Level: %d)" % [enemy.global_position, current_wave, current_level])
	
	if debug_mode:
		print("WaveManager: Enemy spawned at %s, active_enemies: %d (Wave: %d, Level: %d)" % [enemy.global_position, active_enemies.size(), current_wave, current_level])

func _on_enemy_killed(enemy: Node2D) -> void:
	if debug_mode:
		print("DEBUG: Enemy killed - enemies_alive: %d, active_enemies: %d, wave_in_progress: %s" % [enemies_alive, active_enemies.size(), wave_in_progress])
	
	# Clean up invalid enemies
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	
	if enemy and is_instance_valid(enemy) and enemy in active_enemies:
		active_enemies.erase(enemy)
		enemy_killed.emit(enemy)
	else:
		if debug_mode:
			print("WaveManager: Attempted to process killed enemy that is invalid or not in active_enemies")
	
	# Increment shadow mode charge
	var hud_nodes = get_tree().get_nodes_in_group("HUD")
	if hud_nodes.is_empty():
		if debug_mode:
			print("WaveManager: No HUD found for charge update")
	else:
		var hud = hud_nodes[0]
		if hud.has_method("add_enemy_kill_charge"):
			var charge_amount = 20
			hud.add_enemy_kill_charge(charge_amount)
			if debug_mode:
				print("WaveManager: Added %.1f charge for %s kill" % [charge_amount, "Boss_Minion" if enemy.is_in_group("Boss_Minion") else "Enemy"])
		else:
			if debug_mode:
				print("WaveManager: HUD missing add_enemy_kill_charge method")
	
	enemies_alive = max(0, enemies_alive - 1)
	
	if debug_mode:
		print("WaveManager: Enemy killed, %d remaining (Wave: %d, Level: %d)" % [enemies_alive, current_wave, current_level])
	
	if enemies_alive <= 0 and wave_in_progress and not waiting_for_next_wave:
		if debug_mode:
			print("DEBUG: Conditions met for wave completion - calling _complete_wave()")
		_complete_wave()

func _on_minion_died(minion: Node2D) -> void:
	if minion and is_instance_valid(minion) and minion in active_enemies:
		active_enemies.erase(minion)
		enemy_killed.emit(minion)
	else:
		if debug_mode:
			print("WaveManager: Attempted to process killed minion that is invalid or not in active_enemies")
	
	var hud_nodes = get_tree().get_nodes_in_group("HUD")
	if hud_nodes.is_empty():
		if debug_mode:
			print("WaveManager: No HUD found for charge update")
	else:
		var hud = hud_nodes[0]
		if hud.has_method("add_enemy_kill_charge"):
			var charge_amount = 25.0 if minion.is_in_group("Boss_Minion") else 20.0
			hud.add_enemy_kill_charge(charge_amount)
			if debug_mode:
				print("WaveManager: Added %.1f charge for %s kill" % [charge_amount, "Boss_Minion" if minion.is_in_group("Boss_Minion") else "Minion"])
		else:
			if debug_mode:
				print("WaveManager: HUD missing add_enemy_kill_charge method")
	
	enemies_alive = max(0, enemies_alive - 1)
	if debug_mode:
		print("WaveManager: Minion killed, %d remaining (Wave: %d, Level: %d)" % [enemies_alive, current_wave, current_level])
	
	if enemies_alive <= 0 and wave_in_progress and not waiting_for_next_wave:
		_complete_wave()

func _on_boss_killed():
	if debug_mode:
		print("WaveManager: Boss defeated for Wave %d (Level: %d)" % [current_wave, current_level])
	_on_enemy_killed(current_boss)
	current_boss = null

func _complete_wave():
	if debug_mode:
		print("DEBUG: _complete_wave() called - setting waiting_for_next_wave = true")
	
	wave_completion_time = Time.get_unix_time_from_system()
	var wave_duration = wave_completion_time - wave_start_time
	
	if wave_duration > 60.0:
		push_warning("WaveManager: Wave %d timed out after %.1f seconds, forcing completion" % [current_wave, wave_duration])
		_cleanup_wave()
	
	if debug_mode:
		print("WaveManager: Wave %d completed in %.1f seconds (Level: %d)" % [current_wave, wave_duration, current_level])
	
	wave_cleared.emit(current_wave, current_wave_config)
	wave_in_progress = false
	waiting_for_next_wave = true
	
	_cleanup_wave()
	
	if debug_mode:
		print("DEBUG: Starting wave delay timer for %f seconds, is_paused: %s, is_ad_showing: %s" % [
			wave_delay,
			game_manager.is_paused if game_manager else false,
			game_manager.is_ad_showing if game_manager else false
		])
	
	# Create timer that respects pause state
	var timer = get_tree().create_timer(wave_delay, false) # false ensures timer pauses with get_tree().paused
	if game_manager and game_manager.is_ad_showing:
		timer.paused = true
		if debug_mode:
			print("WaveManager: Wave timer paused due to ad showing")
	
	# Wait for timer to complete
	await timer.timeout
	
	if debug_mode:
		print("DEBUG: Wave delay timer finished - setting waiting_for_next_wave = false")
	
	waiting_for_next_wave = false
	start_next_wave()

func _cleanup_wave():
	# Clean up invalid enemies first
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
	for formation in active_formations:
		if is_instance_valid(formation):
			formation.queue_free()
	active_formations.clear()
	
	if current_boss and is_instance_valid(current_boss) and current_boss.has_method("_destroy_all_minions"):
		current_boss._destroy_all_minions()
		if debug_mode:
			print("WaveManager: Destroyed all minions for boss in Wave %d" % current_wave)
	
	if formation_manager and is_instance_valid(formation_manager) and formation_manager.has_method("reset"):
		formation_manager.reset()
		if debug_mode:
			print("WaveManager: Reset FormationManager for Wave %d" % current_wave)
	
	current_boss = null
	enemies_alive = 0 # Ensure enemies_alive is reset

func _physics_process(_delta: float):
	if wave_in_progress and not waiting_for_next_wave and not (game_manager and (game_manager.is_paused or game_manager.is_ad_showing)):
		# Check for stuck wave due to untracked enemy deaths
		var valid_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
		if valid_enemies.size() != enemies_alive:
			if debug_mode:
				print("WaveManager: Mismatch detected - enemies_alive: %d, valid_enemies: %d (Wave: %d, Level: %d)" % [enemies_alive, valid_enemies.size(), current_wave, current_level])
			enemies_alive = valid_enemies.size()
			active_enemies = valid_enemies
			if enemies_alive <= 0:
				if debug_mode:
					print("DEBUG: Forcing wave completion due to no valid enemies remaining")
				_complete_wave()

func _on_boss_music_finished():
	if debug_mode:
		print("WaveManager: Boss music finished, spawning boss for Wave %d (Level: %d)" % [current_wave, current_level])
	_spawn_boss_immediately()

func _show_spawn_indicator(spawn_pos: Vector2):
	if not spawn_indicator_texture:
		return
	
	var indicator = Sprite2D.new()
	indicator.texture = spawn_indicator_texture
	indicator.global_position = spawn_pos
	get_tree().current_scene.call_deferred("add_child", indicator)
	
	var tween = create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(indicator.queue_free)

func _start_red_blink_effect():
	var rect = ColorRect.new()
	rect.name = "RedBlink"
	rect.color = Color(1, 0, 0, 0)
	rect.size = get_viewport().get_visible_rect().size
	get_tree().current_scene.call_deferred("add_child", rect)
	
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.3, 0.5)
	tween.tween_property(rect, "color:a", 0.0, 0.5)

func _stop_red_blink_effect():
	var rect = get_tree().current_scene.get_node_or_null("RedBlink")
	if rect:
		rect.queue_free()

func _on_shadow_mode_activated():
	if debug_mode:
		print("WaveManager: Shadow mode activated (Level: %d)" % current_level)

func _on_shadow_mode_deactivated():
	if debug_mode:
		print("WaveManager: Shadow mode deactivated (Level: %d)" % current_level)

func get_current_wave_config() -> WaveConfig:
	return current_wave_config

func get_wave_progress() -> float:
	if not wave_in_progress or total_waves == 0:
		return 0.0
	return float(current_wave) / float(total_waves)

func get_enemies_remaining() -> int:
	return enemies_alive

func is_wave_active() -> bool:
	return wave_in_progress

func skip_current_wave():
	if wave_in_progress:
		_complete_wave()

func get_debug_info() -> Dictionary:
	return {
		"current_wave": current_wave,
		"total_waves": total_waves,
		"enemies_alive": enemies_alive,
		"wave_in_progress": wave_in_progress,
		"wave_config": current_wave_config.as_debug_string() if current_wave_config and current_wave_config.has_method("as_debug_string") else "None",
		"active_enemies": active_enemies.size(),
		"active_formations": active_formations.size(),
		"is_boss_wave": current_wave_config.is_boss_wave() if current_wave_config else false,
		"current_boss": current_boss != null,
		"current_level": current_level,
		"is_paused": game_manager.is_paused if game_manager else false,
		"is_ad_showing": game_manager.is_ad_showing if game_manager else false
	}

func debug_wave_state():
	print("=== WAVE DEBUG STATE ===")
	print("Current wave: %d / %d" % [current_wave, total_waves])
	print("Enemies alive: %d" % enemies_alive)
	print("Wave in progress: %s" % wave_in_progress)
	print("Waiting for next wave: %s" % waiting_for_next_wave)
	print("Active enemies count: %d" % active_enemies.size())
	print("Active formations count: %d" % active_formations.size())
	if current_wave_config:
		print("Current wave config exists: %s" % current_wave_config.is_boss_wave())
	else:
		print("Current wave config: NULL")
	print("Active enemies: %s" % active_enemies)
	print("Game paused: %s" % (game_manager.is_paused if game_manager else false))
	print("Ad showing: %s" % (game_manager.is_ad_showing if game_manager else false))
	print("========================")
