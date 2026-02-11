extends RefCounted
class_name PlayerSatelliteService

var _owner: Node2D
var _sprite: Sprite2D
var _game_manager: Node
var _debug_callback: Callable

var satellites: Array[Node2D] = []
var satellite_scenes: Dictionary = {}

const SATELLITE_IDS: Array[String] = ["Satellite1", "Satellite2", "Satellite3", "Satellite4", "Satellite5", "Satellite6"]

func configure(owner: Node2D, sprite: Sprite2D, game_manager: Node, debug_callback: Callable) -> void:
	_owner = owner
	_sprite = sprite
	_game_manager = game_manager
	_debug_callback = debug_callback

func initialize_satellites() -> void:
	load_satellite_scenes()
	add_satellites_from_selection()

func load_satellite_scenes() -> void:
	satellite_scenes.clear()
	for satellite_id in SATELLITE_IDS:
		var scene_path = "res://Satellites/%s.tscn" % satellite_id
		if ResourceLoader.exists(scene_path):
			satellite_scenes[satellite_id] = load(scene_path)
		else:
			push_warning("Satellite scene not found: " + scene_path)

func add_satellites_from_selection() -> void:
	if not _owner:
		return
	if not _owner.is_inside_tree():
		await _owner.tree_entered

	for i in range(2):
		var satellite_id := _get_selected_satellite_id(i)
		var satellite_scene: PackedScene = satellite_scenes.get(satellite_id)
		if satellite_scene:
			add_satellite(satellite_scene, i)
		else:
			push_warning("Satellite scene not loaded for: " + satellite_id)

func add_satellite(satellite_scene: PackedScene, position_index: int) -> void:
	if not _owner:
		return
	if not satellite_scene or not satellite_scene.can_instantiate():
		push_error("Invalid satellite scene")
		return

	var satellite_id := _get_selected_satellite_id(position_index)
	var satellite = satellite_scene.instantiate() as Node2D
	if not satellite:
		push_error("Failed to instantiate satellite")
		return

	satellite.name = "Satellite%d" % position_index
	satellite.position = calculate_satellite_offset(position_index)
	_owner.add_child(satellite)
	satellites.append(satellite)

	if satellite.has_method("set_satellite_id"):
		satellite.set_satellite_id(satellite_id)
	elif satellite.has_signal("satellite_id_set"):
		satellite.set("satellite_id", satellite_id)
	else:
		satellite.set_meta("satellite_id", satellite_id)

	_debug("Added satellite %s at offset %s" % [satellite.name, str(satellite.position)])

func remove_all_satellites() -> void:
	for satellite in satellites:
		if satellite and is_instance_valid(satellite):
			if satellite.has_method("set_shooting_active"):
				satellite.set_shooting_active(false)
			if _owner and satellite.get_parent() == _owner:
				_owner.remove_child(satellite)
			satellite.queue_free()
	satellites.clear()
	_debug("Removed all satellites")

func update_satellites_from_selection() -> void:
	remove_all_satellites()
	add_satellites_from_selection()

func on_satellite_stats_updated(satellite_id: String, damage_bonus: int) -> void:
	for satellite in satellites:
		if satellite and is_instance_valid(satellite) and satellite.has_method("apply_damage_bonus"):
			satellite.apply_damage_bonus(damage_bonus)
	_debug("Updated damage bonus for satellites of type %s: +%d" % [satellite_id, damage_bonus])

func calculate_satellite_offset(position_index: int) -> Vector2:
	if not _sprite:
		push_warning("Sprite2D not found, using default offset")
		return Vector2(-120, 0) if position_index == 0 else Vector2(120, 0)

	var texture_size := Vector2.ZERO
	if _sprite.texture:
		texture_size = _sprite.texture.get_size()
	else:
		push_warning("No texture found on player sprite, using default offset")
		return Vector2(-120, 0) if position_index == 0 else Vector2(120, 0)

	var scaled_size = texture_size * _sprite.scale
	var padding: float = 10.0
	var offset_x = (scaled_size.x / 2.0) + padding
	if position_index == 0:
		return Vector2(-offset_x, 0)
	return Vector2(offset_x, 0)

func _get_selected_satellite_id(index: int) -> String:
	var satellite_id := "Satellite1"
	if _game_manager and _game_manager.player_manager:
		if _game_manager.player_manager.has_method("get_selected_satellite_id"):
			satellite_id = _game_manager.player_manager.get_selected_satellite_id(index)
		elif index < _game_manager.player_manager.selected_satellite_ids.size():
			satellite_id = _game_manager.player_manager.selected_satellite_ids[index]
	return satellite_id

func _debug(message: String) -> void:
	if _debug_callback.is_valid():
		_debug_callback.call(message)
