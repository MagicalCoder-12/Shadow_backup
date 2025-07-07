extends Node2D
class_name FormationManager

signal formation_complete
signal enemy_spawned(enemy: Enemy)
signal all_enemies_destroyed
signal all_enemies_spawned

@export var debug_mode: bool = false
@export var formation_completion_delay: float = 2.0

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

var entry_curve_height: float = 200.0
var entry_curve_width: float = 300.0
var spiral_turns: float = 1.5
var bounce_count: int = 2

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

func spawn_formation(config: WaveConfig) -> void:
	if is_spawning:
		push_warning("Formation is already spawning, ignoring new request")
		return
	
	if not config or not config.get_enemy_scene() or not config.get_enemy_scene().can_instantiate():
		push_error("FormationManager: Invalid WaveConfig or enemy scene")
		is_spawning = false
		formation_complete.emit()
		return
	
	is_spawning = true
	current_wave_config = config
	
	var difficulty = config.difficulty
	var multipliers = difficulty_multipliers[difficulty]
	var adjusted_enemy_count = max(1, int(config.get_enemy_count() * multipliers["enemy_count"]))
	config.count = adjusted_enemy_count
	
	if adjusted_enemy_count <= 0:
		push_error("FormationManager: Invalid enemy count %d after difficulty adjustment" % adjusted_enemy_count)
		is_spawning = false
		formation_complete.emit()
		return
	
	_clear_formation_data()
	
	_calculate_formation_positions()
	_calculate_spawn_positions()
	_calculate_entry_paths()
	
	if debug_mode:
		print("FormationManager: Starting formation spawn:")
		print("  Type: ", formation_enums.FormationType.keys()[current_wave_config.formation_type])
		print("  Pattern: ", formation_enums.EntryPattern.keys()[current_wave_config.entry_pattern])
		print("  Enemy Type: ", current_wave_config.enemy_type)
		print("  Count: ", current_wave_config.get_enemy_count())
		print("  Density: ", current_wave_config.get_density_description())
		print("  Difficulty: ", formation_enums.DifficultyLevel.keys()[difficulty])
		queue_redraw()
	
	_spawn_enemies_sequence()

func _clear_formation_data() -> void:
	formation_positions.clear()
	spawn_positions.clear()
	entry_paths.clear()
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	enemies_in_formation = 0
	enemies_spawned_count = 0
	all_enemies_have_spawned = false

func _calculate_formation_positions() -> void:
	formation_positions.clear()
	
	var formation_type = current_wave_config.get_formation_type()
	var enemy_count = current_wave_config.get_enemy_count()
	var formation_center = current_wave_config.get_formation_center()
	var formation_radius = current_wave_config.get_formation_radius()
	var formation_spacing = current_wave_config.get_formation_spacing()
	
	match formation_type:
		formation_enums.FormationType.CIRCLE:
			_calculate_circle_formation(enemy_count, formation_center, formation_radius)
		formation_enums.FormationType.SPIRAL:
			_calculate_spiral_formation(enemy_count, formation_center, formation_radius)
		formation_enums.FormationType.DIAMOND:
			_calculate_diamond_formation(enemy_count, formation_center, formation_radius, formation_spacing)
		formation_enums.FormationType.GRID:
			_calculate_grid_formation(enemy_count, formation_center, formation_spacing)
		formation_enums.FormationType.V_FORMATION:
			_calculate_v_formation(enemy_count, formation_center, formation_spacing)
		formation_enums.FormationType.DOUBLE_CIRCLE:
			_calculate_double_circle_formation(enemy_count, formation_center, formation_radius)
		formation_enums.FormationType.HEXAGON:
			_calculate_hexagon_formation(enemy_count, formation_center, formation_radius)
		formation_enums.FormationType.TRIANGLE:
			_calculate_triangle_formation(enemy_count, formation_center, formation_radius, formation_spacing)

func _calculate_circle_formation(enemy_count: int, center: Vector2, radius: float) -> void:
	var angle_step = 2.0 * PI / enemy_count
	for i in range(enemy_count):
		var angle = i * angle_step
		var pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		formation_positions.append(pos)

func _calculate_spiral_formation(enemy_count: int, center: Vector2, radius: float) -> void:
	var angle_step = (2.0 * PI * spiral_turns) / enemy_count
	var radius_step = radius / enemy_count
	for i in range(enemy_count):
		var angle = i * angle_step
		var current_radius = i * radius_step + 50.0
		var pos = center + Vector2(cos(angle) * current_radius, sin(angle) * current_radius)
		formation_positions.append(pos)

func _calculate_diamond_formation(enemy_count: int, center: Vector2, radius: float, spacing: float) -> void:
	var half_count = enemy_count / 2.0
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

func _calculate_grid_formation(enemy_count: int, center: Vector2, spacing: float) -> void:
	var cols = max(1, int(sqrt(enemy_count)))
	var rows = ceil(float(enemy_count) / cols)
	var start_x = center.x - (cols - 1) * spacing * 0.5
	var start_y = center.y - (rows - 1) * spacing * 0.5
	for i in range(enemy_count):
		var col = i % cols
		var row = i / float(cols)
		var pos = Vector2(start_x + col * spacing, start_y + row * spacing)
		formation_positions.append(pos)

func _calculate_v_formation(enemy_count: int, center: Vector2, spacing: float) -> void:
	var half_count = enemy_count / 2.0
	var v_angle = PI / 6
	for i in range(half_count):
		var distance = i * spacing
		var pos = center + Vector2(-cos(v_angle) * distance, sin(v_angle) * distance)
		formation_positions.append(pos)
	for i in range(enemy_count - half_count):
		var distance = i * spacing
		var pos = center + Vector2(cos(v_angle) * distance, sin(v_angle) * distance)
		formation_positions.append(pos)

func _calculate_double_circle_formation(enemy_count: int, center: Vector2, radius: float) -> void:
	var inner_count = enemy_count / 2.0
	var outer_count = enemy_count - inner_count
	var inner_angle_step = 2.0 * PI / inner_count
	for i in range(inner_count):
		var angle = i * inner_angle_step
		var pos = center + Vector2(cos(angle) * (radius * 0.5), sin(angle) * (radius * 0.5))
		formation_positions.append(pos)
	var outer_angle_step = 2.0 * PI / outer_count
	for i in range(outer_count):
		var angle = i * outer_angle_step
		var pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		formation_positions.append(pos)

func _calculate_hexagon_formation(enemy_count: int, center: Vector2, radius: float) -> void:
	var sides = 6
	var per_side = float(enemy_count) / sides
	var angle_step = 2.0 * PI / sides
	for side in range(sides):
		var start_angle = side * angle_step
		var side_count = int(per_side) if side < sides - 1 else enemy_count - side * int(per_side)
		for i in range(side_count):
			var t = float(i) / max(1.0, side_count - 1) if side_count > 1 else 0.5
			var angle = start_angle + t * angle_step
			var pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)
			formation_positions.append(pos)

func _calculate_triangle_formation(enemy_count: int, center: Vector2, radius: float, spacing: float) -> void:
	var rows = max(1, int(sqrt(enemy_count * 2)))
	var current_enemy = 0
	for row in range(rows):
		if current_enemy >= enemy_count:
			break
		var enemies_in_row = min(row + 1, enemy_count - current_enemy)
		var row_width = enemies_in_row * spacing
		var start_x = center.x - row_width * 0.5
		var y_pos = center.y - radius + row * spacing
		for col in range(enemies_in_row):
			if current_enemy >= enemy_count:
				break
			var pos = Vector2(start_x + col * spacing, y_pos)
			formation_positions.append(pos)
			current_enemy += 1

func _calculate_spawn_positions() -> void:
	spawn_positions.clear()
	var entry_pattern = current_wave_config.get_entry_pattern()
	var enemy_count = current_wave_config.get_enemy_count()
	match entry_pattern:
		formation_enums.EntryPattern.SIDE_CURVE:
			_calculate_side_spawn_positions(enemy_count)
		formation_enums.EntryPattern.TOP_DIVE:
			_calculate_top_spawn_positions(enemy_count)
		formation_enums.EntryPattern.SPIRAL_IN:
			_calculate_spiral_spawn_positions(enemy_count)
		formation_enums.EntryPattern.FIGURE_EIGHT:
			_calculate_figure_eight_spawn_positions(enemy_count)
		formation_enums.EntryPattern.ZIGZAG:
			_calculate_zigzag_spawn_positions(enemy_count)
		formation_enums.EntryPattern.BOUNCE:
			_calculate_bounce_spawn_positions(enemy_count)
		formation_enums.EntryPattern.LOOP:
			_calculate_loop_spawn_positions(enemy_count)
		formation_enums.EntryPattern.WAVE_ENTRY:
			_calculate_wave_spawn_positions(enemy_count)

func _calculate_side_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var side = 1 if i % 2 == 0 else -1
		var spawn_x = screen_width * 0.5 + side * (screen_width * 0.5 + SPAWN_BUFFER)
		var spawn_y = randf_range(100, 300)
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_top_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var spawn_x = randf_range(200, screen_width - 200)
		var spawn_y = -SPAWN_BUFFER
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_spiral_spawn_positions(enemy_count: int) -> void:
	var center = current_wave_config.get_formation_center()
	var radius = current_wave_config.get_formation_radius()
	var outer_radius = radius * 3
	var angle_step = 2.0 * PI / enemy_count
	for i in range(enemy_count):
		var angle = i * angle_step
		var pos = center + Vector2(cos(angle) * outer_radius, sin(angle) * outer_radius)
		spawn_positions.append(pos)

func _calculate_figure_eight_spawn_positions(enemy_count: int) -> void:
	var center = current_wave_config.get_formation_center()
	var radius = current_wave_config.get_formation_radius()
	for i in range(enemy_count):
		var side = 1 if i % 2 == 0 else -1
		var spawn_x = center.x + side * (radius * 2)
		var spawn_y = center.y - radius
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_zigzag_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var spawn_x = -SPAWN_BUFFER if i % 2 == 0 else screen_width + SPAWN_BUFFER
		var spawn_y = randf_range(100, 400)
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_bounce_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var spawn_x = randf_range(-SPAWN_BUFFER, screen_width + SPAWN_BUFFER)
		var spawn_y = -SPAWN_BUFFER
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_loop_spawn_positions(enemy_count: int) -> void:
	var center = current_wave_config.get_formation_center()
	for i in range(enemy_count):
		var side = 1 if i % 2 == 0 else -1
		var spawn_x = center.x + side * (screen_width * 0.4)
		var spawn_y = -SPAWN_BUFFER
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_wave_spawn_positions(enemy_count: int) -> void:
	for i in range(enemy_count):
		var spawn_x = -SPAWN_BUFFER
		var spawn_y = randf_range(100, 500)
		spawn_positions.append(Vector2(spawn_x, spawn_y))

func _calculate_entry_paths() -> void:
	entry_paths.clear()
	var enemy_count = current_wave_config.get_enemy_count()
	for i in range(enemy_count):
		var path = _create_entry_path(i, spawn_positions[i], formation_positions[i])
		entry_paths.append(path)

func _create_entry_path(index: int, spawn_pos: Vector2, target_pos: Vector2) -> Array:
	var path: Array[Vector2] = []
	var steps = 12
	var entry_pattern = current_wave_config.get_entry_pattern()
	match entry_pattern:
		formation_enums.EntryPattern.SIDE_CURVE:
			path = _create_side_curve_path(spawn_pos, target_pos, steps)
		formation_enums.EntryPattern.TOP_DIVE:
			path = _create_top_dive_path(spawn_pos, target_pos, steps)
		formation_enums.EntryPattern.SPIRAL_IN:
			path = _create_spiral_in_path(spawn_pos, target_pos, steps)
		formation_enums.EntryPattern.FIGURE_EIGHT:
			path = _create_figure_eight_path(spawn_pos, target_pos, steps, index)
		formation_enums.EntryPattern.ZIGZAG:
			path = _create_zigzag_path(spawn_pos, target_pos, steps)
		formation_enums.EntryPattern.BOUNCE:
			path = _create_bounce_path(spawn_pos, target_pos, steps)
		formation_enums.EntryPattern.LOOP:
			path = _create_loop_path(spawn_pos, target_pos, steps, index)
		formation_enums.EntryPattern.WAVE_ENTRY:
			path = _create_wave_path(spawn_pos, target_pos, steps)
	return path

func _create_side_curve_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	var control_height = spawn_pos.y - entry_curve_height
	for i in range(steps + 1):
		var t = float(i) / steps
		var control_point = Vector2(spawn_pos.x + (target_pos.x - spawn_pos.x) * 0.3, control_height)
		var point = _quadratic_bezier(spawn_pos, control_point, target_pos, t)
		path.append(point)
	return path

func _create_top_dive_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	for i in range(steps + 1):
		var t = float(i) / steps
		var mid_point = Vector2(spawn_pos.x + (target_pos.x - spawn_pos.x) * 0.5, spawn_pos.y + 200)
		var point = _quadratic_bezier(spawn_pos, mid_point, target_pos, t)
		path.append(point)
	return path

func _create_spiral_in_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	var center = current_wave_config.get_formation_center()
	for i in range(steps + 1):
		var t = float(i) / steps
		var angle = atan2(spawn_pos.y - center.y, spawn_pos.x - center.x) + t * PI * 2
		var radius = lerp(spawn_pos.distance_to(center), target_pos.distance_to(center), t)
		var point = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		path.append(point)
	return path

func _create_figure_eight_path(spawn_pos: Vector2, target_pos: Vector2, steps: int, _index: int) -> Array:
	var path: Array[Vector2] = []
	var center = current_wave_config.get_formation_center()
	var radius = current_wave_config.get_formation_radius()
	for i in range(steps + 1):
		var t = float(i) / steps
		var angle = t * PI * 2
		var x = center.x + radius * sin(angle)
		var y = center.y + radius * sin(angle) * cos(angle)
		var fig8_point = Vector2(x, y)
		var blend_t = smoothstep(0.0, 0.3, t) * smoothstep(1.0, 0.7, t)
		var point = spawn_pos.lerp(fig8_point, blend_t).lerp(target_pos, smoothstep(0.7, 1.0, t))
		path.append(point)
	return path

func _create_zigzag_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	var zigzag_amplitude = 150.0
	var zigzag_frequency = 3.0
	for i in range(steps + 1):
		var t = float(i) / steps
		var base_point = spawn_pos.lerp(target_pos, t)
		var zigzag_offset = sin(t * zigzag_frequency * PI * 2) * zigzag_amplitude * (1.0 - t)
		var point = base_point + Vector2(0, zigzag_offset)
		path.append(point)
	return path

func _create_bounce_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	for i in range(steps + 1):
		var t = float(i) / steps
		var base_point = spawn_pos.lerp(target_pos, t)
		var bounce_height = abs(sin(t * bounce_count * PI)) * 100.0
		var point = base_point + Vector2(0, -bounce_height)
		path.append(point)
	return path

func _create_loop_path(spawn_pos: Vector2, target_pos: Vector2, steps: int, _index: int) -> Array:
	var path: Array[Vector2] = []
	var loop_radius = 80.0
	var loop_center = Vector2(spawn_pos.x + (target_pos.x - spawn_pos.x) * 0.5, spawn_pos.y + 150)
	for i in range(steps + 1):
		var t = float(i) / steps
		if t < 0.3:
			var point = spawn_pos.lerp(loop_center + Vector2(0, -loop_radius), t / 0.3)
			path.append(point)
		elif t < 0.7:
			var loop_t = (t - 0.3) / 0.4
			var angle = loop_t * PI * 2
			var point = loop_center + Vector2(sin(angle) * loop_radius, -cos(angle) * loop_radius)
			path.append(point)
		else:
			var exit_t = (t - 0.7) / 0.3
			var loop_exit = loop_center + Vector2(0, -loop_radius)
			var point = loop_exit.lerp(target_pos, exit_t)
			path.append(point)
	return path

func _create_wave_path(spawn_pos: Vector2, target_pos: Vector2, steps: int) -> Array:
	var path: Array[Vector2] = []
	var wave_amplitude = 100.0
	var wave_frequency = 2.0
	for i in range(steps + 1):
		var t = float(i) / steps
		var base_point = spawn_pos.lerp(target_pos, t)
		var wave_offset = sin(t * wave_frequency * PI * 2) * wave_amplitude * (1.0 - t * 0.5)
		var point = base_point + Vector2(0, wave_offset)
		path.append(point)
	return path

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _spawn_enemies_sequence() -> void:
	var enemy_count = current_wave_config.get_enemy_count()
	var spawn_delay = current_wave_config.get_spawn_delay()
	var difficulty = current_wave_config.difficulty
	var multipliers = difficulty_multipliers[difficulty]
	var adjusted_spawn_delay = spawn_delay * multipliers["spawn_delay"]
	
	for i in range(enemy_count):
		_spawn_single_enemy(i)
		enemies_spawned_count += 1
		
		if debug_mode:
			print("FormationManager: Spawned %d/%d enemies" % [enemies_spawned_count, enemy_count])
		
		if adjusted_spawn_delay > 0:
			await get_tree().create_timer(adjusted_spawn_delay).timeout
	
	# Mark all enemies as spawned
	all_enemies_have_spawned = true
	all_enemies_spawned.emit()
	
	if debug_mode:
		print("FormationManager: All %d enemies spawned, waiting for formation completion" % enemy_count)

func _spawn_single_enemy(index: int) -> void:
	var enemy_scene = current_wave_config.get_enemy_scene()
	
	if not enemy_scene or not enemy_scene.can_instantiate():
		push_error("FormationManager: Invalid enemy scene at index %d" % index)
		return
	
	var enemy = enemy_scene.instantiate() as Enemy
	if not enemy:
		push_error("FormationManager: Enemy scene does not contain Enemy class at index %d" % index)
		return
	
	enemy.global_position = spawn_positions[index]
	
	get_tree().current_scene.call_deferred("add_child", enemy)
	spawned_enemies.append(enemy)
	
	if enemy.has_signal("formation_reached"):
		enemy.formation_reached.connect(_on_enemy_formation_reached.bind(enemy))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
	_setup_enemy_formation_data(enemy, index)
	_animate_enemy_entry(enemy, index)
	
	enemy_spawned.emit(enemy)
	
	if debug_mode:
		print("FormationManager: Spawned enemy %d (%s) at %s" % [index, current_wave_config.enemy_type, enemy.global_position])

func _setup_enemy_formation_data(enemy: Enemy, index: int) -> void:
	if enemy.has_method("setup_formation_entry"):
		var config = _create_enemy_config(index)
		enemy.setup_formation_entry(config, index, 0.0)

func _create_enemy_config(index: int) -> WaveConfig:
	var config = current_wave_config.duplicate()
	if config.has_method("set_spawn_pos"):
		config.set_spawn_pos(spawn_positions[index])
	return config

func _animate_enemy_entry(enemy: Enemy, index: int) -> void:
	var path = entry_paths[index]
	var tween
	if path.is_empty():
		tween = create_tween()
		var duration = 2.0 / enemy.entry_speed_multiplier
		tween.tween_property(enemy, "global_position", formation_positions[index], duration)
		tween.tween_callback(func(): _on_enemy_reached(enemy))
		return
	
	var entry_speed = current_wave_config.get_entry_speed()
	var difficulty = current_wave_config.difficulty
	var multipliers = difficulty_multipliers[difficulty]
	var adjusted_entry_speed = entry_speed * multipliers["entry_speed"] * enemy.entry_speed_multiplier
	
	tween = create_tween()
	var total_distance = 0.0
	for i in range(1, path.size()):
		total_distance += path[i-1].distance_to(path[i])
	var total_duration = total_distance / adjusted_entry_speed
	var duration_per_segment = total_duration / path.size()
	for i in range(1, path.size()):
		var target = path[i]
		tween.tween_property(enemy, "global_position", target, duration_per_segment)
	tween.tween_callback(func(): _on_enemy_reached(enemy))

func _on_enemy_reached(enemy: Enemy) -> void:
	if is_instance_valid(enemy) and enemy.has_method("on_reach_formation"):
		enemy.on_reach_formation()

func _on_enemy_formation_reached(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	enemies_in_formation += 1
	if debug_mode:
		print("FormationManager: Enemy reached formation. Total: %d/%d" % [enemies_in_formation, current_wave_config.get_enemy_count()])
	if enemies_in_formation >= current_wave_config.get_enemy_count() and is_spawning:
		_check_formation_complete()

func _check_formation_complete() -> void:
	if not is_spawning:
		return
	var enemy_count = current_wave_config.get_enemy_count()
	if enemies_in_formation >= enemy_count:
		is_spawning = false
		await get_tree().create_timer(formation_completion_delay).timeout
		formation_complete.emit()
		if debug_mode:
			print("FormationManager: Formation complete with %d enemies" % enemies_in_formation)

func _on_enemy_died(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	
	if enemy.arrived_at_formation:
		enemies_in_formation = max(0, enemies_in_formation - 1)
		if debug_mode:
			print("FormationManager: Enemy died (was in formation). Formation count: %d" % enemies_in_formation)
	else:
		if debug_mode:
			print("FormationManager: Enemy died (was not in formation yet)")
	
	spawned_enemies.erase(enemy)
	
	var alive_enemies = 0
	for spawned_enemy in spawned_enemies:
		if is_instance_valid(spawned_enemy):
			alive_enemies += 1
	
	if alive_enemies == 0 and all_enemies_have_spawned:
		all_enemies_destroyed.emit()
		is_spawning = false  # Add this line
		if debug_mode:
			print("FormationManager: All enemies destroyed, is_spawning set to false")

func get_formation_progress() -> float:
	var enemy_count = current_wave_config.get_enemy_count() if current_wave_config else 0
	if enemy_count == 0:
		return 0.0
	return float(enemies_in_formation) / float(enemy_count)

func get_spawn_progress() -> float:
	var enemy_count = current_wave_config.get_enemy_count() if current_wave_config else 0
	if enemy_count == 0:
		return 0.0
	return float(enemies_spawned_count) / float(enemy_count)

func get_enemies_in_formation() -> int:
	return enemies_in_formation

func get_total_enemies() -> int:
	return current_wave_config.get_enemy_count() if current_wave_config else 0

func get_alive_enemies() -> Array[Enemy]:
	var alive_enemies: Array[Enemy] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			alive_enemies.append(enemy)
	return alive_enemies

func get_alive_enemy_count() -> int:
	var count = 0
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			count += 1
	return count

func is_formation_complete() -> bool:
	return not is_spawning and enemies_in_formation > 0

func stop_spawning() -> void:
	if is_spawning:
		is_spawning = false
		if debug_mode:
			print("FormationManager: Spawning stopped")

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
		
		# Draw formation radius
		var radius = current_wave_config.get_formation_radius()
		draw_arc(center, radius, 0, 2 * PI, 32, DEBUG_CENTER_COLOR, 2.0)

func _on_tree_exiting() -> void:
	destroy_all_enemies()
	_clear_formation_data()

# Utility functions for advanced formations
func _create_custom_formation_positions(enemy_count: int, center: Vector2, params: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	# Example custom formation - can be extended
	var formation_name = params.get("name", "custom")
	match formation_name:
		"star":
			positions = _create_star_formation(enemy_count, center, params)
		"cross":
			positions = _create_cross_formation(enemy_count, center, params)
		"heart":
			positions = _create_heart_formation(enemy_count, center, params)
		_:
			# Default to circle if unknown
			_calculate_circle_formation(enemy_count, center, params.get("radius", 150.0))
			positions = formation_positions.duplicate()
	
	return positions

func _create_star_formation(enemy_count: int, center: Vector2, params: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var radius = params.get("radius", 150.0)
	var points = params.get("points", 5)
	var inner_radius = radius * 0.5
	
	for i in range(enemy_count):
		var angle = (float(i) / enemy_count) * 2.0 * PI
		var point_index = i % (points * 2)
		var current_radius = radius if point_index % 2 == 0 else inner_radius
		var pos = center + Vector2(cos(angle) * current_radius, sin(angle) * current_radius)
		positions.append(pos)
	
	return positions

func _create_cross_formation(enemy_count: int, center: Vector2, params: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var _arm_length = params.get("arm_length", 150.0)
	var spacing = params.get("spacing", 30.0)
	
	@warning_ignore("integer_division")
	var enemies_per_arm = enemy_count / 4
	var remaining = enemy_count % 4
	
	# Horizontal arms
	for i in range(enemies_per_arm):
		var offset = (i + 1) * spacing
		positions.append(center + Vector2(offset, 0))  # Right
		positions.append(center + Vector2(-offset, 0)) # Left
	
	# Vertical arms
	for i in range(enemies_per_arm):
		var offset = (i + 1) * spacing
		positions.append(center + Vector2(0, offset))  # Down
		positions.append(center + Vector2(0, -offset)) # Up
	
	# Place remaining enemies at center
	for i in range(remaining):
		positions.append(center)
	
	return positions

func _create_heart_formation(enemy_count: int, center: Vector2, params: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var scaled = params.get("scale", 1.0)
	
	for i in range(enemy_count):
		var t = float(i) / enemy_count * 2.0 * PI
		# Parametric heart equation
		var x = 16 * pow(sin(t), 3)
		var y = -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))
		var pos = center + Vector2(x * scaled * 3, y * scaled * 3)
		positions.append(pos)
	
	return positions

# Performance monitoring
func get_performance_stats() -> Dictionary:
	return {
		"enemies_spawned": enemies_spawned_count,
		"enemies_in_formation": enemies_in_formation,
		"alive_enemies": get_alive_enemy_count(),
		"is_spawning": is_spawning,
		"formation_complete": is_formation_complete(),
		"spawn_progress": get_spawn_progress(),
		"formation_progress": get_formation_progress()
	}
