extends Node2D
class_name WaveManager

# Signals for wave progression and events
signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(current_wave: int, wave_config: WaveConfig)
signal all_waves_cleared()
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D)

# Exported properties
@export var wave_delay: float = 1.5
@export var formation_manager_scene: PackedScene
@export var debug_mode: bool = false

# Core wave management variables
var waves: Array[WaveConfig] = []
var current_wave: int = 0
var current_level: int = 1
var total_waves: int = 0
var wave_in_progress: bool = false
var waiting_for_next_wave: bool = false
var has_completed_level: bool = false

# Enemy tracking
var active_enemies: Array[Node2D] = []
var _connected_enemies: Array[Node2D] = []
var enemies_alive: int = 0
var current_wave_config: WaveConfig = null

# Formation and boss management
var formation_manager: FormationManager = null
var active_formations: Array[FormationManager] = []
var current_boss: Node2D = null

# Timing
var wave_start_time: float = 0.0
var wave_completion_time: float = 0.0

# Game state references
var game_manager: Node = null

# New variables for dynamic wave progression
var player_performance: float = 0.5  # 0.0 (struggling) to 1.0 (excelling)
var elite_enemy_spawned: bool = false
var swarm_spawned: bool = false

func _ready():
	game_manager = GameManager
	if debug_mode:
		print("WaveManager: Ready for level %d" % current_level)

func set_waves(wave_configs: Array[WaveConfig]) -> void:
	waves = wave_configs
	total_waves = waves.size()
	current_wave = 0
	if debug_mode:
		print("WaveManager: Set %d waves for level %d" % [total_waves, current_level])

func start_waves() -> void:
	if waves.is_empty():
		push_error("WaveManager: No waves to start")
		return
	
	current_wave = 0
	wave_in_progress = false
	waiting_for_next_wave = false
	has_completed_level = false
	
	if debug_mode:
		print("WaveManager: Starting waves for level %d" % current_level)
	
	start_next_wave()

# --- New Methods for Dynamic Wave Progression ---

func _adjust_wave_difficulty(player_performance: float):
	# Modify enemy count, health, and shooting frequency based on player performance
	# player_performance: 0.0 (struggling) to 1.0 (excelling)
	if current_wave_config:
		if player_performance > 0.7:  # Player is doing well
			# Increase difficulty
			current_wave_config.difficulty = formation_enums.DifficultyLevel.HARD
		elif player_performance < 0.3:  # Player is struggling
			# Decrease difficulty
			current_wave_config.difficulty = formation_enums.DifficultyLevel.EASY
		else:
			# Keep normal difficulty
			current_wave_config.difficulty = formation_enums.DifficultyLevel.NORMAL

func _trigger_event_wave(event_type: String):
	# Spawn special enemy formations based on events
	# Examples: Boss rushes, swarm attacks, elite enemy appearances
	match event_type:
		"swarm":
			_spawn_enemy_swarm(10, "mob1")
		"elite":
			_spawn_elite_enemy()
		_:
			if debug_mode:
				print("WaveManager: Unknown event wave type: %s" % event_type)

func _spawn_elite_enemy():
	# Create an elite enemy with enhanced stats and rewards
	if not formation_manager_scene:
		push_error("WaveManager: No formation manager scene assigned")
		return
	
	# Create a temporary wave config for the elite enemy
	var elite_config = WaveConfig.new()
	elite_config.enemy_type = "EliteEnemy"
	elite_config.formation_type = formation_enums.FormationType.CIRCLE
	elite_config.entry_pattern = formation_enums.EntryPattern.TOP_DIVE
	elite_config.difficulty = formation_enums.DifficultyLevel.HARD
	elite_config.formation_center = Vector2(640, 300)
	elite_config.formation_radius = 100.0
	
	# Create formation manager for elite enemy
	var elite_formation_manager = formation_manager_scene.instantiate() as FormationManager
	if not elite_formation_manager:
		push_error("WaveManager: Failed to instantiate formation manager for elite enemy")
		return
	
	# Ensure we're in the scene tree before trying to access current_scene
	if not get_tree():
		push_error("WaveManager: Not in scene tree, cannot spawn elite enemy")
		elite_formation_manager.queue_free()
		return
	
	# Get the target parent - prefer current_scene, fall back to our parent
	var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not target_parent:
		push_error("WaveManager: No valid parent found for elite enemy")
		elite_formation_manager.queue_free()
		return
	
	# Add to scene and connect signals
	target_parent.call_deferred("add_child", elite_formation_manager)
	active_formations.append(elite_formation_manager)
	
	if elite_formation_manager.has_signal("enemy_spawned"):
		elite_formation_manager.enemy_spawned.connect(_on_enemy_spawned)
	if elite_formation_manager.has_signal("formation_complete"):
		elite_formation_manager.formation_complete.connect(_on_formation_complete)
	if elite_formation_manager.has_signal("all_enemies_destroyed"):
		elite_formation_manager.all_enemies_destroyed.connect(_on_all_enemies_destroyed)
	
	# Start formation spawning after FormationManager is added to scene tree
	elite_formation_manager.call_deferred("spawn_formation", elite_config)
	
	elite_enemy_spawned = true
	
	if debug_mode:
		print("WaveManager: Elite enemy spawned")

func _spawn_enemy_swarm(count: int, enemy_type: String):
	# Spawn a swarm of enemies
	if not formation_manager_scene:
		push_error("WaveManager: No formation manager scene assigned")
		return
	
	# Create a temporary wave config for the swarm
	var swarm_config = WaveConfig.new()
	swarm_config.enemy_type = enemy_type
	swarm_config.formation_type = formation_enums.FormationType.CLUSTER
	swarm_config.entry_pattern = formation_enums.EntryPattern.STAGGERED
	swarm_config.difficulty = formation_enums.DifficultyLevel.NORMAL
	swarm_config.formation_center = Vector2(640, 500)
	swarm_config.formation_radius = 150.0
	
	# Create formation manager for swarm
	var swarm_formation_manager = formation_manager_scene.instantiate() as FormationManager
	if not swarm_formation_manager:
		push_error("WaveManager: Failed to instantiate formation manager for swarm")
		return
	
	# Ensure we're in the scene tree before trying to access current_scene
	if not get_tree():
		push_error("WaveManager: Not in scene tree, cannot spawn swarm")
		swarm_formation_manager.queue_free()
		return
	
	# Get the target parent - prefer current_scene, fall back to our parent
	var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not target_parent:
		push_error("WaveManager: No valid parent found for swarm")
		swarm_formation_manager.queue_free()
		return
	
	# Add to scene and connect signals
	target_parent.call_deferred("add_child", swarm_formation_manager)
	active_formations.append(swarm_formation_manager)
	
	if swarm_formation_manager.has_signal("enemy_spawned"):
		swarm_formation_manager.enemy_spawned.connect(_on_enemy_spawned)
	if swarm_formation_manager.has_signal("formation_complete"):
		swarm_formation_manager.formation_complete.connect(_on_formation_complete)
	if swarm_formation_manager.has_signal("all_enemies_destroyed"):
		swarm_formation_manager.all_enemies_destroyed.connect(_on_all_enemies_destroyed)
	
	# Start formation spawning after FormationManager is added to scene tree
	swarm_formation_manager.call_deferred("spawn_formation", swarm_config)
	
	swarm_spawned = true
	
	if debug_mode:
		print("WaveManager: Enemy swarm spawned with %d enemies" % count)

func start_next_wave() -> void:
	if current_wave >= total_waves:
		if debug_mode:
			print("WaveManager: All waves completed for level %d" % current_level)
		print("WaveManager: Emitting all_waves_cleared signal")
		all_waves_cleared.emit()
		return
	
	if wave_in_progress or waiting_for_next_wave:
		if debug_mode:
			print("WaveManager: Cannot start wave - already in progress or waiting")
		return
	
	current_wave_config = waves[current_wave]
	wave_in_progress = true
	wave_start_time = Time.get_unix_time_from_system()
	
	# Adjust difficulty based on player performance
	_adjust_wave_difficulty(player_performance)
	
	if debug_mode:
		print("WaveManager: Starting wave %d/%d (Level: %d)" % [current_wave + 1, total_waves, current_level])
	
	wave_started.emit(current_wave + 1, total_waves)
	
	# Spawn wave based on type
	if current_wave_config.is_boss_wave():
		_spawn_boss_wave()
	else:
		_spawn_normal_wave()

func _spawn_normal_wave() -> void:
	if not formation_manager_scene:
		push_error("WaveManager: No formation manager scene assigned")
		return
	
	# Create formation manager
	formation_manager = formation_manager_scene.instantiate() as FormationManager
	if not formation_manager:
		push_error("WaveManager: Failed to instantiate formation manager")
		return
	
	# Ensure we're in the scene tree before trying to access current_scene
	if not get_tree():
		push_error("WaveManager: Not in scene tree, cannot spawn formation manager")
		formation_manager.queue_free()
		return
	
	# Get the target parent - prefer current_scene, fall back to our parent
	var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not target_parent:
		push_error("WaveManager: No valid parent found for formation manager")
		formation_manager.queue_free()
		return
	
	# Add to scene and connect signals
	target_parent.call_deferred("add_child", formation_manager)
	active_formations.append(formation_manager)
	
	if formation_manager.has_signal("enemy_spawned"):
		formation_manager.enemy_spawned.connect(_on_enemy_spawned)
	if formation_manager.has_signal("formation_complete"):
		formation_manager.formation_complete.connect(_on_formation_complete)
	if formation_manager.has_signal("all_enemies_destroyed"):
		formation_manager.all_enemies_destroyed.connect(_on_all_enemies_destroyed)
	
	# Start formation spawning after FormationManager is added to scene tree
	formation_manager.call_deferred("spawn_formation", current_wave_config)
	
	if debug_mode:
		print("WaveManager: Normal wave spawning started")

func _spawn_boss_wave() -> void:
	if not current_wave_config or not current_wave_config.boss_scene:
		push_error("WaveManager: Boss wave has no boss scene configured")
		_complete_wave()
		return
	
	# Ensure we're in the scene tree
	if not get_tree():
		push_error("WaveManager: Not in scene tree, cannot spawn boss")
		_complete_wave()
		return
	
	# Get the target parent - prefer current_scene, fall back to our parent
	var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not target_parent:
		push_error("WaveManager: No valid parent found for boss")
		_complete_wave()
		return
	
	# Instantiate and spawn the boss ABOVE the screen
	var boss_instance = current_wave_config.boss_scene.instantiate()
	if not boss_instance:
		push_error("WaveManager: Failed to instantiate boss scene")
		_complete_wave()
		return
	
	var viewport_rect = get_viewport().get_visible_rect()
	var boss_position = Vector2(current_wave_config.formation_center.x, -200)  # Spawn off-screen above
	# Clamp x to screen bounds
	boss_position.x = clamp(boss_position.x, 100, viewport_rect.size.x - 100)
	boss_instance.global_position = boss_position
	
	# Add boss to scene deferred
	target_parent.call_deferred("add_child", boss_instance)
	
	# Wait a frame for it to be in the tree, then connect
	call_deferred("_connect_boss_signals", boss_instance)
	
	# Track the boss (but don't increment enemies_alive yet—wait for descent)
	current_boss = boss_instance
	active_enemies.append(boss_instance)
	_connected_enemies.append(boss_instance)
	# enemies_alive = 1  # Defer this until descent completes
	
	enemy_spawned.emit(boss_instance)
	
	if debug_mode:
		print("WaveManager: Boss spawned off-screen at %s (will descend to y=400, Wave: %d, Level: %d)" % [boss_instance.global_position, current_wave + 1, current_level])

func _connect_boss_signals(boss: Node2D) -> void:
	if not is_instance_valid(boss):
		return
	
	# Connect death signal
	if boss.has_signal("died"):
		boss.died.connect(_on_enemy_killed.bind(boss))
	elif boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_enemy_killed.bind(boss))
	
	# New: Connect descent completed to start full tracking
	if boss.has_signal("descent_completed"):
		boss.descent_completed.connect(func(): 
			enemies_alive = 1
			if debug_mode:
				print("WaveManager: Boss descent complete - now tracking as alive enemy")
		)

func _on_enemy_spawned(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	
	active_enemies.append(enemy)
	_connected_enemies.append(enemy)
	
	# Connect enemy death signal
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_killed.bind(enemy))
	
	enemies_alive += 1
	enemy_spawned.emit(enemy)
	
	if debug_mode:
		print("WaveManager: Enemy spawned - Total alive: %d (Wave: %d, Level: %d)" % [enemies_alive, current_wave + 1, current_level])
	
	# Verify count
	_verify_enemy_count()

func _on_formation_complete() -> void:
	if debug_mode:
		print("WaveManager: Formation complete for wave %d" % (current_wave + 1))

func _on_all_enemies_destroyed() -> void:
	if debug_mode:
		print("WaveManager: All enemies destroyed for wave %d" % (current_wave + 1))
	print("WaveManager: Calling _complete_wave from _on_all_enemies_destroyed")
	_complete_wave()

func _verify_enemy_count() -> void:
	# Clean up invalid enemies first
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and e.is_alive)
	
	var valid_count = active_enemies.size()
	
	# Update enemies_alive to match valid_count if there's a discrepancy
	if enemies_alive != valid_count:
		if debug_mode:
			print("WaveManager: Count mismatch detected - enemies_alive: %d, valid_count: %d (Wave: %d, Level: %d)" % [enemies_alive, valid_count, current_wave + 1, current_level])
		
		# Only log as error if the discrepancy is significant (> 1)
		if abs(enemies_alive - valid_count) > 1:
			push_error("WaveManager: Count mismatch - enemies_alive: %d, valid_count: %d (Wave: %d, Level: %d)" % [enemies_alive, valid_count, current_wave + 1, current_level])
		else:
			push_warning("WaveManager: Minor count mismatch - enemies_alive: %d, valid_count: %d (Wave: %d, Level: %d)" % [enemies_alive, valid_count, current_wave + 1, current_level])
		
		enemies_alive = valid_count

func _on_enemy_killed(enemy: Node2D) -> void:
	if debug_mode:
		print("WaveManager: Enemy killed - enemies_alive: %d, active_enemies: %d, wave_in_progress: %s" % [enemies_alive, active_enemies.size(), wave_in_progress])
	
	# Clean up invalid enemies
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	
	if enemy and is_instance_valid(enemy) and enemy in active_enemies:
		active_enemies.erase(enemy)
		enemy_killed.emit(enemy)
		
		# Remove from connected enemies list
		if enemy in _connected_enemies:
			_connected_enemies.erase(enemy)
	else:
		if debug_mode:
			print("WaveManager: Attempted to process killed enemy that is invalid or not in active_enemies")
	
	enemies_alive = max(0, enemies_alive - 1)
	if debug_mode:
		print("WaveManager: Enemy killed, %d remaining (Wave: %d, Level: %d)" % [enemies_alive, current_wave + 1, current_level])
	
	# Verify our tracking
	_verify_enemy_count()
	
	if enemies_alive <= 0 and wave_in_progress and not waiting_for_next_wave:
		if debug_mode:
			print("WaveManager: Conditions met for wave completion - calling _complete_wave()")
		print("WaveManager: Calling _complete_wave from _on_enemy_killed")
		_complete_wave()

func _complete_wave():
	if debug_mode:
		print("WaveManager: _complete_wave() called - setting waiting_for_next_wave = true")
	
	wave_completion_time = Time.get_unix_time_from_system()
	var wave_duration = wave_completion_time - wave_start_time
	
	if debug_mode:
		print("WaveManager: Wave %d completed in %.1f seconds (Level: %d)" % [current_wave + 1, wave_duration, current_level])
	
	wave_cleared.emit(current_wave + 1, current_wave_config)
	wave_in_progress = false
	waiting_for_next_wave = true
	
	_cleanup_wave()
	
	# Move to next wave
	current_wave += 1
	
	if debug_mode:
		print("WaveManager: Starting wave delay timer for %f seconds" % wave_delay)
	
	# Create timer for next wave
	var timer = get_tree().create_timer(wave_delay, false)
	await timer.timeout
	
	if debug_mode:
		print("WaveManager: Wave delay timer finished - setting waiting_for_next_wave = false")
	
	waiting_for_next_wave = false
	start_next_wave()

func _cleanup_wave():
	# Clean up invalid enemies first
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	active_enemies.clear()
	_connected_enemies.clear()
	
	for formation in active_formations:
		if is_instance_valid(formation):
			formation.queue_free()
	active_formations.clear()
	
	if formation_manager and is_instance_valid(formation_manager) and formation_manager.has_method("reset"):
		formation_manager.reset()
		if debug_mode:
			print("WaveManager: Reset FormationManager for Wave %d" % (current_wave + 1))
	
	current_boss = null
	enemies_alive = 0

func _physics_process(_delta: float):
	if wave_in_progress and not waiting_for_next_wave:
		# Check for stuck wave due to untracked enemy deaths
		var valid_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
		if valid_enemies.size() != enemies_alive:
			if debug_mode:
				print("WaveManager: Mismatch detected - enemies_alive: %d, valid_enemies: %d (Wave: %d, Level: %d)" % [enemies_alive, valid_enemies.size(), current_wave + 1, current_level])
			
			enemies_alive = valid_enemies.size()
			active_enemies = valid_enemies
			
			if enemies_alive <= 0:
				if debug_mode:
					print("WaveManager: Forcing wave completion due to no valid enemies remaining")
				_complete_wave()

func _on_shadow_mode_activated():
	if debug_mode:
		print("WaveManager: Shadow mode activated")

func _on_shadow_mode_deactivated():
	if debug_mode:
		print("WaveManager: Shadow mode deactivated")
