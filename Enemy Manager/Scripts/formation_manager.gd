extends Node2D
class_name FormationManager

signal formation_complete
signal enemy_spawned(enemy: Enemy)
signal all_enemies_destroyed
signal all_enemies_spawned
signal enemy_died(enemy: Enemy)

@export var debug_mode: bool = false
@export var formation_completion_delay: float = 0.5

# New export for spawn point indicator
@export var show_spawn_indicators: bool = true
@export var spawn_indicator_duration: float = 1.0
@export var spawn_indicator_blink_count: int = 3

var viewport_size: Vector2
var screen_width: float
var screen_height: float
const SPAWN_BUFFER: float = 100.0

var formation_positions: Array[Vector2] = []
var spawn_positions: Array[Vector2] = []
var entry_paths: Array[Array] = []
var spawned_enemies: Array[Enemy] = []
var enemies_in_formation: int = 0
var enemies_spawned_count: int = 0
var all_enemies_have_spawned: bool = false
var is_spawning: bool = false
var current_wave_config: WaveConfig = null

var difficulty_multipliers := {
	formation_enums.DifficultyLevel.EASY: {
		"spawn_delay": 1.2,
		"entry_speed": 0.8,
		"enemy_count": 0.8
	},
	formation_enums.DifficultyLevel.NORMAL: {
		"spawn_delay": 1.0,
		"entry_speed": 1.0,
		"enemy_count": 1.0
	},
	formation_enums.DifficultyLevel.HARD: {
		"spawn_delay": 0.8,
		"entry_speed": 1.2,
		"enemy_count": 1.2
	},
	formation_enums.DifficultyLevel.NIGHTMARE: {
		"spawn_delay": 0.6,
		"entry_speed": 1.5,
		"enemy_count": 1.5
	}
}

const DEBUG_FORMATION_COLOR = Color.GREEN
const DEBUG_SPAWN_COLOR = Color.YELLOW
const DEBUG_PATH_COLOR = Color.CYAN
const DEBUG_CENTER_COLOR = Color.RED

func _ready():
	viewport_size = get_viewport().get_visible_rect().size
	screen_width = viewport_size.x
	screen_height = viewport_size.y
	tree_exiting.connect(_on_tree_exiting)

func reset() -> void:
	_clear_formation_data()
	is_spawning = false
	if debug_mode:
		print("FormationManager: Reset state")

func spawn_formation(config: WaveConfig) -> void:
	if is_spawning:
		push_warning("Formation is already spawning, ignoring new request")
		return
	
	if not config:
		push_error("FormationManager: Invalid WaveConfig")
		is_spawning = false
		formation_complete.emit()
		return
	
	is_spawning = true
	current_wave_config = config
	
	var difficulty = config.difficulty
	var multipliers = difficulty_multipliers[difficulty]
	var adjusted_enemy_count = max(1, int(config.get_enemy_count() * multipliers["enemy_count"]))
	
	if adjusted_enemy_count <= 0:
		push_error("FormationManager: Invalid enemy count after difficulty adjustment")
		is_spawning = false
		formation_complete.emit()
		return
	
	_clear_formation_data()
	
	# Always generate enough positions
	_calculate_formation_positions(adjusted_enemy_count)
	_calculate_spawn_positions(adjusted_enemy_count)
	_calculate_entry_paths(adjusted_enemy_count)
	
	# Validate position generation
	if formation_positions.size() != adjusted_enemy_count:
		push_error("FormationManager: Formation position generation failed. Expected: %d, Got: %d" % [adjusted_enemy_count, formation_positions.size()])
		is_spawning = false
		formation_complete.emit()
		return
	
	if spawn_positions.size() != adjusted_enemy_count:
		push_error("FormationManager: Spawn position generation failed. Expected: %d, Got: %d" % [adjusted_enemy_count, spawn_positions.size()])
		is_spawning = false
		formation_complete.emit()
		return
	
	if debug_mode:
		print("FormationManager: Starting formation spawn:")
		print("  Type: ", formation_enums.FormationType.keys()[current_wave_config.formation_type])
		print("  Pattern: ", formation_enums.EntryPattern.keys()[current_wave_config.entry_pattern])
		print("  Enemy Type: ", current_wave_config.enemy_type)
		print("  Count: ", adjusted_enemy_count)
		print("  Difficulty: ", formation_enums.DifficultyLevel.keys()[difficulty])
		queue_redraw()
	
	_spawn_enemies_sequence(adjusted_enemy_count)

func _clear_formation_data() -> void:
	formation_positions.clear()
	spawn_positions.clear()
	entry_paths.clear()
	
	# Properly clean up enemies
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	
	enemies_in_formation = 0
	enemies_spawned_count = 0
	all_enemies_have_spawned = false

func _calculate_formation_positions(enemy_count: int) -> void:
	formation_positions.clear()
	
	var formation_type = current_wave_config.get_formation_type()
	var formation_center = current_wave_config.get_formation_center()
	var formation_radius = current_wave_config.get_formation_radius()
	var formation_spacing = current_wave_config.get_formation_spacing()
	
	match formation_type:
		formation_enums.FormationType.CIRCLE:
			_calculate_circle_formation(enemy_count, formation_center, formation_radius)
		formation_enums.FormationType.GRID:
			_calculate_grid_formation(enemy_count, formation_center, formation_spacing)
		formation_enums.FormationType.V_FORMATION:
			_calculate_v_formation(enemy_count, formation_center, formation_spacing)
		formation_enums.FormationType.DIAMOND:
			_calculate_diamond_formation(enemy_count, formation_center, formation_radius, formation_spacing)
		# New formation types
		formation_enums.FormationType.V_WAVE:
			_calculate_v_wave_formation(enemy_count, formation_center, formation_spacing)
		formation_enums.FormationType.CLUSTER:
			_calculate_cluster_formation(enemy_count, formation_center, 5)  # Default cluster size of 5
		formation_enums.FormationType.DYNAMIC:
			_calculate_dynamic_formation(enemy_count, formation_center, Time.get_ticks_msec() / 1000.0)
		_:
			# Default to circle formation
			_calculate_circle_formation(enemy_count, formation_center, formation_radius)
	
	# Ensure we have enough positions
	while formation_positions.size() < enemy_count:
		var fallback_pos = formation_center + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		formation_positions.append(fallback_pos)
	
	if debug_mode:
		print("FormationManager: Generated ", formation_positions.size(), " formation positions")

# --- New Formation Calculation Methods ---

func _calculate_v_wave_formation(enemy_count: int, center: Vector2, spacing: float):
	var rows = ceil(sqrt(enemy_count))
	var cols = ceil(float(enemy_count) / rows)
	
	for i in range(enemy_count):
		var row = i / cols
		var col = i % int(cols)
		
		# Create wave pattern
		var wave_offset = sin(row * 0.5) * spacing
		var pos = center + Vector2(col * spacing - (cols * spacing / 2), row * spacing + wave_offset)
		formation_positions.append(pos)

func _calculate_cluster_formation(enemy_count: int, center: Vector2, cluster_size: int = 5):
	var clusters = ceil(float(enemy_count) / cluster_size)
	
	for c in range(clusters):
		var cluster_center = Vector2(
			center.x + (c % 3 - 1) * 200,
			center.y + (c / 3) * 150
		)
		
		var cluster_count = min(cluster_size, enemy_count - c * cluster_size)
		for i in range(cluster_count):
			var angle = i * (2 * PI / cluster_count)
			var pos = cluster_center + Vector2(cos(angle) * 50, sin(angle) * 50)
			formation_positions.append(pos)

func _calculate_dynamic_formation(enemy_count: int, center: Vector2, time: float):
	# Formation positions change over time
	for i in range(enemy_count):
		var angle = i * (2 * PI / enemy_count) + time * 0.5
		var radius = 100 + sin(time + i) * 50
		var pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		formation_positions.append(pos)

func _calculate_circle_formation(enemy_count: int, center: Vector2, radius: float) -> void:
	var angle_step = 2.0 * PI / enemy_count
	for i in range(enemy_count):
		var angle = i * angle_step
		var pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		formation_positions.append(pos)

func _calculate_grid_formation(enemy_count: int, center: Vector2, spacing: float) -> void:
	var cols = max(1, int(sqrt(enemy_count)))
	var rows = ceil(float(enemy_count) / cols)
	var start_x = center.x - (cols - 1) * spacing * 0.5
	var start_y = center.y - (rows - 1) * spacing * 0.5
	
	for i in range(enemy_count):
		var col = i % cols
		var row = i / cols
		var pos = Vector2(start_x + col * spacing, start_y + row * spacing)
		formation_positions.append(pos)

func _calculate_v_formation(enemy_count: int, center: Vector2, spacing: float) -> void:
	@warning_ignore("integer_division")
	var half_count = enemy_count / 2
	var v_angle = PI / 6
	
	for i in range(half_count):
		var distance = i * spacing
		var pos = center + Vector2(-cos(v_angle) * distance, sin(v_angle) * distance)
		formation_positions.append(pos)
	
	for i in range(enemy_count - half_count):
		var distance = i * spacing
		var pos = center + Vector2(cos(v_angle) * distance, sin(v_angle) * distance)
		formation_positions.append(pos)

func _calculate_diamond_formation(enemy_count: int, center: Vector2, radius: float, spacing: float) -> void:
	@warning_ignore("integer_division")
	var half_count = enemy_count / 2
	var enemies_per_side = ceil(float(half_count) / 2.0)
	
	for i in range(enemies_per_side):
		var progress = float(i) / max(1.0, enemies_per_side - 1)
		var offset = (progress - 0.5) * spacing * enemies_per_side
		var y_offset = -radius + (progress * radius)
		var pos = center + Vector2(offset, y_offset)
		formation_positions.append(pos)
	
	var remaining = enemy_count - enemies_per_side
	for i in range(remaining):
		var progress = float(i) / max(1.0, remaining - 1)
		var offset = (progress - 0.5) * spacing * remaining
		var y_offset = (progress * radius)
		var pos = center + Vector2(offset, y_offset)
		formation_positions.append(pos)

func _calculate_spawn_positions(enemy_count: int) -> void:
	spawn_positions.clear()
	
	if not current_wave_config:
		push_error("FormationManager: No wave config for spawn position calculation")
		return
	
	var entry_pattern = current_wave_config.get_entry_pattern()
	
	if debug_mode:
		print("FormationManager: Calculating spawn positions for pattern: ", formation_enums.EntryPattern.keys()[entry_pattern])
	
	match entry_pattern:
		formation_enums.EntryPattern.SIDE_CURVE:
			_calculate_side_spawn_positions(enemy_count)
		formation_enums.EntryPattern.TOP_DIVE:
			_calculate_top_spawn_positions(enemy_count)
		# New entry patterns
		formation_enums.EntryPattern.STAGGERED:
			_calculate_staggered_entry_positions(enemy_count, 5)  # Default group size of 5
		formation_enums.EntryPattern.AMBUSH:
			_calculate_ambush_entry_positions(enemy_count, 3)  # Default ambush count of 3
		_:
			# Default to top dive
			_calculate_top_spawn_positions(enemy_count)
	
	# Ensure we have enough positions
	while spawn_positions.size() < enemy_count:
		var fallback_pos = Vector2(screen_width/2 + randf_range(-200, 200), -SPAWN_BUFFER)
		spawn_positions.append(fallback_pos)
		if debug_mode:
			print("FormationManager: Added fallback spawn position %d" % spawn_positions.size())
	
	if debug_mode:
		print("FormationManager: Generated ", spawn_positions.size(), " spawn positions")

# --- New Entry Position Calculation Methods ---

func _calculate_staggered_entry_positions(enemy_count: int, group_size: int = 5):
	# Calculate entry positions for staggered group entry
	var groups = ceil(float(enemy_count) / group_size)
	
	for g in range(groups):
		var group_start = g * group_size
		var group_end = min((g + 1) * group_size, enemy_count)
		
		# Position group members together but with slight variations
		var group_center_x = randf_range(100, screen_width - 100)
		
		for i in range(group_start, group_end):
			var offset_x = randf_range(-30, 30)
			var spawn_x = clamp(group_center_x + offset_x, 50, screen_width - 50)
			var spawn_y = -SPAWN_BUFFER - (g * 50)  # Stagger groups vertically
			spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_ambush_entry_positions(enemy_count: int, ambush_count: int = 3):
	# Calculate standard entry positions for most enemies
	_calculate_top_spawn_positions(enemy_count - ambush_count)
	
	# Calculate edge entry positions for ambush enemies
	for i in range(ambush_count):
		var side = 1 if i % 2 == 0 else -1
		#Keep enemies within screen bounds - spawn just outside but not too far
		var spawn_x = screen_width * 0.5 + side * (screen_width * 0.4)  # Changed from 0.5 + SPAWN_BUFFER to 0.4
		# Clamp to ensure they don't go beyond reasonable boundaries
		spawn_x = clamp(spawn_x, -50, screen_width + 50)  # Small buffer for entry effect
		var spawn_y = randf_range(100, 300)
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_side_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var side = 1 if i % 2 == 0 else -1
		# Keep enemies within screen bounds - spawn just outside but not too far
		var spawn_x = screen_width * 0.5 + side * (screen_width * 0.4)  # Changed from 0.5 + SPAWN_BUFFER to 0.4
		# Clamp to ensure they don't go beyond reasonable boundaries
		spawn_x = clamp(spawn_x, -50, screen_width + 50)  # Small buffer for entry effect
		var spawn_y = randf_range(100, 300)
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_top_spawn_positions(enemy_count: int) -> void:
	var spacing = screen_width / (enemy_count + 1)
	for i in range(enemy_count):
		var spawn_x = spacing * (i + 1)
		var spawn_y = -SPAWN_BUFFER
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_entry_paths(enemy_count: int) -> void:
	entry_paths.clear()
	
	for i in range(enemy_count):
		if i < spawn_positions.size() and i < formation_positions.size():
			var path = _create_entry_path(spawn_positions[i], formation_positions[i])
			entry_paths.append(path)
		else:
			# Fallback path
			var simple_path = [Vector2(screen_width/2, -SPAWN_BUFFER), Vector2(screen_width/2, 200)]
			entry_paths.append(simple_path)
	
	# Ensure we have enough paths
	while entry_paths.size() < enemy_count:
		var simple_path = [Vector2(screen_width/2, -SPAWN_BUFFER), Vector2(screen_width/2, 200)]
		entry_paths.append(simple_path)
	
	if debug_mode:
		print("FormationManager: Generated ", entry_paths.size(), " entry paths")

func _create_entry_path(spawn_pos: Vector2, target_pos: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var steps = 8
	
	# Simple linear interpolation path
	for i in range(steps + 1):
		var t = float(i) / steps
		var point = spawn_pos.lerp(target_pos, t)
		path.append(point)
	
	return path

func _spawn_enemies_sequence(enemy_count: int) -> void:
	var spawn_delay = current_wave_config.get_spawn_delay()
	var difficulty = current_wave_config.difficulty
	var multipliers = difficulty_multipliers[difficulty]
	var adjusted_spawn_delay = spawn_delay * multipliers["spawn_delay"]
	
	if debug_mode:
		print("FormationManager: Starting to spawn ", enemy_count, " enemies")
	
	# Show spawn indicators before spawning enemies
	if show_spawn_indicators and enemy_count > 0:
		await _show_spawn_indicators(enemy_count)
	
	# Spawn enemies one by one
	for i in range(enemy_count):
		_spawn_single_enemy(i)
		enemies_spawned_count += 1
		
		if debug_mode:
			print("FormationManager: Spawned enemy ", i+1, "/", enemy_count)
		
		if adjusted_spawn_delay > 0 and i < enemy_count - 1:
			if get_tree():
				await get_tree().create_timer(adjusted_spawn_delay).timeout
			else:
				push_warning("FormationManager: Cannot create spawn delay timer, not in scene tree")
	
	# Mark all enemies as spawned
	all_enemies_have_spawned = true
	all_enemies_spawned.emit()
	
	if debug_mode:
		print("FormationManager: All enemies spawned")

func _spawn_single_enemy(index: int) -> void:
	var enemy_scene = current_wave_config.get_enemy_scene()
	
	if not enemy_scene or not enemy_scene.can_instantiate():
		push_error("FormationManager: Invalid enemy scene at index %d" % index)
		return
	
	var enemy = enemy_scene.instantiate() as Enemy
	if not enemy:
		push_error("FormationManager: Enemy scene does not contain Enemy class at index %d" % index)
		return
	
	# Ensure we have valid positions
	if index >= spawn_positions.size():
		push_error("FormationManager: No spawn position for enemy index %d (only have %d positions)" % [index, spawn_positions.size()])
		enemy.queue_free()
		return
	
	if index >= formation_positions.size():
		push_error("FormationManager: No formation position for enemy index %d (only have %d positions)" % [index, formation_positions.size()])
		enemy.queue_free()
		return
	
	# Set enemy position
	enemy.global_position = spawn_positions[index]
	
	# Add to scene tree
	# Ensure we're in the scene tree before trying to access current_scene
	if not get_tree():
		push_error("FormationManager: Not in scene tree, cannot spawn enemy")
		enemy.queue_free()
		return
	
	# Get the target parent - prefer current_scene, fall back to our parent
	var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not target_parent:
		push_error("FormationManager: No valid parent found for enemy")
		enemy.queue_free()
		return
	
	target_parent.call_deferred("add_child", enemy)
	spawned_enemies.append(enemy)
	
	# Connect signals safely
	if enemy.has_signal("formation_reached"):
		enemy.formation_reached.connect(_on_enemy_formation_reached.bind(enemy))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
	# Setup enemy formation data
	_setup_enemy_formation_data(enemy, index)
	
	enemy_spawned.emit(enemy)
	
	if debug_mode:
		print("FormationManager: Spawned enemy %d at %s" % [index, enemy.global_position])

func _setup_enemy_formation_data(enemy: Enemy, index: int) -> void:
	if enemy.has_method("setup_formation_entry"):
		var config = _create_enemy_config(index)
		var formation_pos = formation_positions[index]
		enemy.setup_formation_entry(config, index, formation_pos, 0.0)
		
		if enemy.has_method("set_entry_path") and index < entry_paths.size():
			var entry_path = entry_paths[index]
			enemy.set_entry_path(entry_path)

func _create_enemy_config(index: int) -> WaveConfig:
	var config = current_wave_config.duplicate()
	
	if index < spawn_positions.size():
		config.spawn_pos = spawn_positions[index]
	
	config.center = current_wave_config.get_formation_center()
	
	return config

func _on_tree_exiting() -> void:
	destroy_all_enemies()
	_clear_formation_data()

func _on_enemy_formation_reached(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		if debug_mode:
			print("FormationManager: Formation reached signal for invalid enemy")
		return
	
	enemies_in_formation += 1
	if debug_mode:
		print("FormationManager: Enemy reached formation. Total: %d" % enemies_in_formation)
	
	if enemies_in_formation >= spawned_enemies.size() and is_spawning:
		_check_formation_complete()

func _check_formation_complete() -> void:
	if not is_spawning:
		return
	
	# Validate alive enemies
	var alive_enemies = get_alive_enemy_count()
	if enemies_in_formation >= alive_enemies:
		is_spawning = false
		if get_tree():
			await get_tree().create_timer(formation_completion_delay).timeout
		else:
			push_warning("FormationManager: Cannot create completion delay timer, not in scene tree")
		formation_complete.emit()
		if debug_mode:
			print("FormationManager: Formation complete")

func _on_enemy_died(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		if debug_mode:
			print("FormationManager: Died signal received for invalid enemy")
		return
	
	if enemy.arrived_at_formation:
		enemies_in_formation = max(0, enemies_in_formation - 1)
		if debug_mode:
			print("FormationManager: Enemy died (was in formation). Formation count: %d" % enemies_in_formation)
	
	# Remove from spawned_enemies
	spawned_enemies.erase(enemy)
	enemy_died.emit(enemy)
	
	# Check if all enemies are destroyed
	var alive_enemies = get_alive_enemy_count()
	if alive_enemies == 0 and all_enemies_have_spawned:
		all_enemies_destroyed.emit()
		is_spawning = false
		if debug_mode:
			print("FormationManager: All enemies destroyed")

func get_alive_enemy_count() -> int:
	#var count = 0
	spawned_enemies = spawned_enemies.filter(func(e): return is_instance_valid(e))
	return spawned_enemies.size()

func destroy_all_enemies() -> void:
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_clear_formation_data()
	if debug_mode:
		print("FormationManager: All enemies destroyed")

func _draw() -> void:
	if not debug_mode:
		return
	
	# Draw formation positions
	for pos in formation_positions:
		draw_circle(pos, 8, DEBUG_FORMATION_COLOR)
	
	# Draw spawn positions
	for pos in spawn_positions:
		draw_circle(pos, 6, DEBUG_SPAWN_COLOR)
	
	# Draw entry paths
	for path in entry_paths:
		if path.size() > 1:
			for i in range(path.size() - 1):
				draw_line(path[i], path[i + 1], DEBUG_PATH_COLOR, 2.0)
	
	# Draw formation center
	if current_wave_config:
		var center = current_wave_config.get_formation_center()
		draw_circle(center, 12, DEBUG_CENTER_COLOR)
		
		var radius = current_wave_config.get_formation_radius()
		draw_arc(center, radius, 0, 2 * PI, 32, DEBUG_CENTER_COLOR, 2.0)

# New method to show spawn point indicators
func _show_spawn_indicators(enemy_count: int) -> void:
	if not show_spawn_indicators:
		return
	
	var indicator_nodes: Array[Node2D] = []
	
	# Create visual indicators at each spawn position
	for i in range(min(enemy_count, spawn_positions.size())):
		var spawn_pos = spawn_positions[i]
		
		# Create a visual indicator using a simple colored circle
		var indicator = Node2D.new()
		indicator.name = "SpawnIndicator_%d" % i
		indicator.position = spawn_pos
		
		# Create a colored circle
		var circle = ColorRect.new()
		circle.name = "IndicatorCircle"
		circle.size = Vector2(32, 32)
		circle.position = Vector2(-16, -16)  # Center the circle
		circle.color = Color(1.0, 0.2, 0.2, 0.8)  # Red color with transparency
		
		indicator.add_child(circle)
		add_child(indicator)
		indicator_nodes.append(indicator)
		
		# Create tween for blinking effect
		if is_instance_valid(indicator) and indicator.has_method("create_tween"):
			var tween = indicator.create_tween()
			tween.set_loops(spawn_indicator_blink_count)
			
			# Blink animation: scale and fade
			tween.tween_property(circle, "scale", Vector2(2.0, 2.0), spawn_indicator_duration / (spawn_indicator_blink_count * 2))
			tween.tween_property(indicator, "modulate:a", 0.2, spawn_indicator_duration / (spawn_indicator_blink_count * 2))
			tween.tween_property(circle, "scale", Vector2(1.0, 1.0), spawn_indicator_duration / (spawn_indicator_blink_count * 2))
			tween.tween_property(indicator, "modulate:a", 0.8, spawn_indicator_duration / (spawn_indicator_blink_count * 2))
	
	# Wait for the indicator duration
	if get_tree():
		await get_tree().create_timer(spawn_indicator_duration).timeout
	
	# Clean up indicator nodes
	for indicator in indicator_nodes:
		if is_instance_valid(indicator):
			indicator.queue_free()
