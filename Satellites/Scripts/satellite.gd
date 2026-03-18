extends Node2D
class_name SatelliteWeaponController

const DEFAULT_BULLET_SCENE: PackedScene = preload("res://Bullet/Sat_bullet/Sat_bullet1.tscn")
const BEHAVIOR_SHOOT_ONLY_SCRIPT := preload("res://Satellites/Scripts/Behaviors/SatelliteBehaviorShootOnly.gd")
const DEFAULT_VISUAL_BOUNDS := Rect2(Vector2(-16, -16), Vector2(32, 32))
const SHADOW_TINT := Color(0.72, 0.45, 1.0, 1.0)
const SHADOW_BULLET_TINT := Color(0.72, 0.45, 1.0, 1.0)

enum SatelliteBehaviorMode {
	SHOOT_ONLY,
	LAUNCH_ATTACK
}

@export var bullet_scene: PackedScene = DEFAULT_BULLET_SCENE
@export var behavior_mode: SatelliteBehaviorMode = SatelliteBehaviorMode.SHOOT_ONLY
@export var fire_rate: float = 0.4
@export var bullet_speed: float = 1500.0
@export var shadow_spread_angle: float = 15.0
@export var shadow_fire_rate_multiplier: float = 0.7
@export var relative_size_multiplier: float = 1.0

@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var nozzle: Node2D = get_node_or_null("Nozel")
@onready var timer: Timer = get_node_or_null("Timer")

var is_shooting_active: bool = true
var original_fire_rate: float = 0.4
var is_shadow_mode_active: bool = false
var satellite_id: String = ""
var satellite_base_damage: int = 10
var satellite_damage_bonus: int = 0
var _behavior: SatelliteBehaviorBase = null
var _base_visual_scale: Vector2 = Vector2.ONE
var _visual_nodes: Array[CanvasItem] = []
var _normal_modulates: Dictionary = {}

func _ready() -> void:
	_base_visual_scale = scale
	_cache_visual_nodes()
	original_fire_rate = maxf(0.05, fire_rate)
	if not _uses_bullet_shooting():
		is_shooting_active = false
	_initialize_timer()
	_initialize_behavior()
	_initialize_launch_attack()
	_connect_signals()
	_validate_scene_setup()
	_play_shoot_animation_if_available()

func _exit_tree() -> void:
	if GameManager and GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.disconnect(_on_shadow_mode_activated)
	if GameManager and GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.disconnect(_on_shadow_mode_deactivated)
	if timer and timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.disconnect(_on_timer_timeout)

func _process(delta: float) -> void:
	if _behavior:
		_behavior.process(delta)
	if behavior_mode == SatelliteBehaviorMode.LAUNCH_ATTACK:
		process_launch_attack(delta)

func _physics_process(delta: float) -> void:
	if _behavior:
		_behavior.physics_process(delta)
	if behavior_mode == SatelliteBehaviorMode.LAUNCH_ATTACK:
		physics_process_launch_attack(delta)

func _initialize_timer() -> void:
	if timer == null:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)
	timer.one_shot = false
	timer.wait_time = original_fire_rate
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if is_shooting_active and _uses_bullet_shooting():
		timer.start()
	else:
		timer.stop()

func _initialize_behavior() -> void:
	if behavior_mode != SatelliteBehaviorMode.SHOOT_ONLY:
		_behavior = null
		return
	_behavior = _create_behavior_instance(behavior_mode)
	if _behavior:
		_behavior.setup(self)

func _initialize_launch_attack() -> void:
	if behavior_mode == SatelliteBehaviorMode.LAUNCH_ATTACK:
		initialize_launch_attack()

func _create_behavior_instance(mode: SatelliteBehaviorMode) -> SatelliteBehaviorBase:
	var behavior_script: GDScript
	match mode:
		SatelliteBehaviorMode.SHOOT_ONLY:
			behavior_script = BEHAVIOR_SHOOT_ONLY_SCRIPT
		_:
			return null

	var behavior_instance: Variant = behavior_script.new()
	if behavior_instance is SatelliteBehaviorBase:
		return behavior_instance as SatelliteBehaviorBase

	push_warning("Invalid satellite behavior instance; falling back to shoot-only behavior.")
	return SatelliteBehaviorShootOnly.new()

func _connect_signals() -> void:
	if GameManager and not GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	if GameManager and not GameManager.shadow_mode_deactivated.is_connected(_on_shadow_mode_deactivated):
		GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)

func _validate_scene_setup() -> void:
	if nozzle == null:
		push_warning("Satellite %s is missing Nozel node; using satellite origin as fire point." % name)

	if not _uses_bullet_shooting():
		return

	if not bullet_scene or not bullet_scene.can_instantiate():
		push_error("Satellite %s has invalid bullet_scene; disabling shooting." % name)
		is_shooting_active = false
		if timer:
			timer.stop()

func _play_shoot_animation_if_available() -> void:
	if not _uses_bullet_shooting():
		return
	if animation_player == null:
		return
	if animation_player.has_animation("shoot"):
		animation_player.play("shoot")
	elif animation_player.has_animation("Shoot"):
		animation_player.play("Shoot")

func _on_timer_timeout() -> void:
	if not _uses_bullet_shooting():
		return
	if not is_shooting_active:
		return
	if not bullet_scene or not bullet_scene.can_instantiate():
		return

	var base_damage: int = _get_current_satellite_total_damage()
	if is_shadow_mode_active and has_custom_shadow_attack():
		execute_shadow_attack(base_damage)
		return

	var shot_angles: Array[float] = []
	if _behavior:
		shot_angles = _behavior.get_shot_angles(is_shadow_mode_active, shadow_spread_angle)
	else:
		shot_angles = [0.0]
	if shot_angles.is_empty():
		shot_angles = [0.0]

	for angle_deg in shot_angles:
		_spawn_shot_at_angle(angle_deg, base_damage)

func _spawn_shot_at_angle(angle_deg: float, base_damage: int) -> void:
	var spawn_position: Vector2 = nozzle.global_position if nozzle else global_position
	var shot_damage: int = max(1, base_damage)
	var bullet: Node = BulletFactory.spawn_bullet(
		bullet_scene,
		spawn_position,
		deg_to_rad(angle_deg),
		bullet_speed,
		shot_damage
	)
	if bullet == null:
		return

	_configure_spawned_bullet(bullet, shot_damage)
	if _behavior:
		_behavior.configure_spawned_bullet(bullet, shot_damage, is_shadow_mode_active)
	_attach_bullet_to_current_scene(bullet)

func _configure_spawned_bullet(bullet: Node, shot_damage: int) -> void:
	if bullet.has_method("configure_from_satellite_weapon"):
		bullet.call("configure_from_satellite_weapon", shot_damage)
	if is_shadow_mode_active:
		if bullet.has_method("apply_shadow_tint"):
			bullet.call("apply_shadow_tint", SHADOW_BULLET_TINT)
		elif bullet is CanvasItem:
			(bullet as CanvasItem).modulate = SHADOW_BULLET_TINT

func _attach_bullet_to_current_scene(bullet: Node) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	if not bullet.get_parent():
		current_scene.add_child(bullet)
	elif bullet.get_parent() != current_scene:
		bullet.get_parent().remove_child(bullet)
		current_scene.add_child(bullet)

func _get_current_satellite_total_damage() -> int:
	var total_damage: int = max(1, satellite_base_damage + satellite_damage_bonus)
	if GameManager and GameManager.has_method("get_god_mode_damage"):
		return GameManager.get_god_mode_damage(total_damage)
	return total_damage

func set_shooting_active(active: bool) -> void:
	is_shooting_active = active and _uses_bullet_shooting()
	if timer == null:
		return
	if is_shooting_active:
		timer.start()
	else:
		timer.stop()

func _on_shadow_mode_activated() -> void:
	if is_shadow_mode_active:
		return
	is_shadow_mode_active = true
	_apply_shadow_tint()
	if _uses_bullet_shooting():
		fire_rate = maxf(0.05, original_fire_rate * shadow_fire_rate_multiplier)
		if timer:
			timer.wait_time = fire_rate
			if is_shooting_active:
				timer.start()
	if _behavior:
		_behavior.on_shadow_mode_changed(true)
	if behavior_mode == SatelliteBehaviorMode.LAUNCH_ATTACK:
		on_launch_attack_shadow_mode_changed(true)

func _on_shadow_mode_deactivated() -> void:
	if not is_shadow_mode_active:
		return
	is_shadow_mode_active = false
	_restore_normal_modulates()
	if _uses_bullet_shooting():
		fire_rate = original_fire_rate
		if timer:
			timer.wait_time = fire_rate
			if is_shooting_active:
				timer.start()
	if _behavior:
		_behavior.on_shadow_mode_changed(false)
	if behavior_mode == SatelliteBehaviorMode.LAUNCH_ATTACK:
		on_launch_attack_shadow_mode_changed(false)

func _uses_bullet_shooting() -> bool:
	return behavior_mode == SatelliteBehaviorMode.SHOOT_ONLY

func set_satellite_id(id: String) -> void:
	satellite_id = id
	_load_satellite_data()

func get_satellite_id() -> String:
	return satellite_id

func apply_damage_bonus(new_damage_bonus: int) -> void:
	satellite_damage_bonus = max(0, new_damage_bonus)

func has_custom_shadow_attack() -> bool:
	return false

func execute_shadow_attack(base_damage: int) -> void:
	_spawn_shot_pattern([0.0], base_damage)

func initialize_launch_attack() -> void:
	pass

func process_launch_attack(_delta: float) -> void:
	pass

func physics_process_launch_attack(_delta: float) -> void:
	pass

func on_launch_attack_shadow_mode_changed(_is_shadow_mode_active: bool) -> void:
	pass

func apply_ship_relative_size(ship_visual_size: Vector2, size_ratio: float = 0.8) -> void:
	var satellite_bounds := get_visual_bounds_local()
	if ship_visual_size == Vector2.ZERO or satellite_bounds.size == Vector2.ZERO:
		return

	var safe_ratio := clampf(size_ratio, 0.05, 2.0)
	var target_size := ship_visual_size * safe_ratio
	var scale_factor_x := target_size.x / satellite_bounds.size.x if satellite_bounds.size.x > 0.0 else 1.0
	var scale_factor_y := target_size.y / satellite_bounds.size.y if satellite_bounds.size.y > 0.0 else 1.0
	var scale_factor := minf(scale_factor_x, scale_factor_y)
	if not is_finite(scale_factor) or scale_factor <= 0.0:
		return

	scale = _base_visual_scale * scale_factor * maxf(0.1, relative_size_multiplier)

func get_visual_bounds_local() -> Rect2:
	var bounds_found := false
	var combined_bounds := Rect2()

	for visual_node in _collect_visual_nodes(self):
		var visual_bounds := _get_visual_node_bounds_local(visual_node)
		if visual_bounds.size == Vector2.ZERO:
			continue

		if not bounds_found:
			combined_bounds = visual_bounds
			bounds_found = true
		else:
			combined_bounds = combined_bounds.merge(visual_bounds)

	if bounds_found:
		return combined_bounds
	return DEFAULT_VISUAL_BOUNDS

func _load_satellite_data() -> void:
	if satellite_id.is_empty() and has_meta("satellite_id"):
		satellite_id = str(get_meta("satellite_id"))

	if satellite_id.is_empty():
		return

	for sat_data in GameManager.satellites:
		if not (sat_data is Dictionary):
			continue
		if str(sat_data.get("id", "")) != satellite_id:
			continue

		var texture_path: String = str(sat_data.get("texture", ""))
		satellite_base_damage = max(1, int(sat_data.get("base_damage", 10)))
		satellite_damage_bonus = max(0, int(sat_data.get("damage_bonus", 0)))
		if texture_path.is_empty():
			return
		if not ResourceLoader.exists(texture_path):
			push_warning("Invalid texture path for satellite %s: %s" % [satellite_id, texture_path])
			return

		var sprite: Sprite2D = get_node_or_null("Sprite2D")
		if sprite:
			var texture: Texture2D = load(texture_path) as Texture2D
			if texture:
				sprite.texture = texture
		return

func _cache_visual_nodes() -> void:
	_visual_nodes.clear()
	_normal_modulates.clear()
	for visual_node in _collect_visual_nodes(self):
		if visual_node is CanvasItem:
			var canvas_item := visual_node as CanvasItem
			_visual_nodes.append(canvas_item)
			_normal_modulates[canvas_item.get_path()] = canvas_item.modulate

func _apply_shadow_tint() -> void:
	for visual_node in _visual_nodes:
		if not visual_node or not is_instance_valid(visual_node):
			continue
		var normal_modulate: Variant = _normal_modulates.get(visual_node.get_path(), Color(1, 1, 1, 1))
		if normal_modulate is Color:
			visual_node.modulate = (normal_modulate as Color) * SHADOW_TINT

func _restore_normal_modulates() -> void:
	for visual_node in _visual_nodes:
		if not visual_node or not is_instance_valid(visual_node):
			continue
		var normal_modulate: Variant = _normal_modulates.get(visual_node.get_path())
		if normal_modulate is Color:
			visual_node.modulate = normal_modulate as Color

func _spawn_shot_pattern(shot_angles: Array[float], base_damage: int, angle_offset: float = 0.0) -> void:
	for angle_deg in shot_angles:
		_spawn_shot_at_angle(angle_deg + angle_offset, base_damage)

func _collect_visual_nodes(root_node: Node) -> Array[Node]:
	var visual_nodes: Array[Node] = []
	for child in root_node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			visual_nodes.append(child)
		visual_nodes.append_array(_collect_visual_nodes(child))
	return visual_nodes

func _get_visual_node_bounds_local(visual_node: Node) -> Rect2:
	var local_rect := Rect2()
	var local_transform := global_transform.affine_inverse() * (visual_node as Node2D).global_transform

	if visual_node is Sprite2D:
		local_rect = _get_sprite_rect_local(visual_node as Sprite2D)
	elif visual_node is AnimatedSprite2D:
		local_rect = _get_animated_sprite_rect_local(visual_node as AnimatedSprite2D)
	else:
		return Rect2()

	if local_rect.size == Vector2.ZERO:
		return Rect2()
	return _transform_rect(local_rect, local_transform)

func _get_sprite_rect_local(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2()

	var visible_rect := _get_texture_visible_rect(sprite.texture)
	var texture_size := sprite.texture.get_size()
	var top_left := sprite.offset
	if sprite.centered:
		top_left -= texture_size * 0.5

	return Rect2(top_left + visible_rect.position, visible_rect.size)

func _get_animated_sprite_rect_local(animated_sprite: AnimatedSprite2D) -> Rect2:
	if animated_sprite.sprite_frames == null:
		return Rect2()

	var animation_name := animated_sprite.animation
	var frame_count := animated_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return Rect2()

	var safe_frame := clampi(animated_sprite.frame, 0, frame_count - 1)
	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(animation_name, safe_frame)
	if frame_texture == null:
		return Rect2()

	var visible_rect := _get_texture_visible_rect(frame_texture)
	var texture_size := frame_texture.get_size()
	var top_left := animated_sprite.offset
	if animated_sprite.centered:
		top_left -= texture_size * 0.5

	return Rect2(top_left + visible_rect.position, visible_rect.size)

func _get_texture_visible_rect(texture: Texture2D) -> Rect2:
	var texture_size := texture.get_size()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture_size)

	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2(Vector2.ZERO, texture_size)

	return Rect2(Vector2(used_rect.position), Vector2(used_rect.size))

func _transform_rect(rect: Rect2, transform_2d: Transform2D) -> Rect2:
	var corners := PackedVector2Array([
		transform_2d * rect.position,
		transform_2d * Vector2(rect.position.x + rect.size.x, rect.position.y),
		transform_2d * Vector2(rect.position.x, rect.position.y + rect.size.y),
		transform_2d * (rect.position + rect.size)
	])

	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_y := corners[0].y
	var max_y := corners[0].y

	for point in corners:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
