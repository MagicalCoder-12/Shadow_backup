extends Node2D
class_name SatelliteWeaponController

const DEFAULT_BULLET_SCENE: PackedScene = preload("res://Bullet/Sat_bullet/Sat_bullet1.tscn")
const BEHAVIOR_SHOOT_ONLY_SCRIPT := preload("res://Satellites/Scripts/Behaviors/SatelliteBehaviorShootOnly.gd")
const BEHAVIOR_LAUNCH_ATTACK_SCRIPT := preload("res://Satellites/Scripts/Behaviors/SatelliteBehaviorLaunchAttack.gd")

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

func _ready() -> void:
	original_fire_rate = maxf(0.05, fire_rate)
	_initialize_timer()
	_initialize_behavior()
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

func _physics_process(delta: float) -> void:
	if _behavior:
		_behavior.physics_process(delta)

func _initialize_timer() -> void:
	if timer == null:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)
	timer.one_shot = false
	timer.wait_time = original_fire_rate
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if is_shooting_active:
		timer.start()
	else:
		timer.stop()

func _initialize_behavior() -> void:
	_behavior = _create_behavior_instance(behavior_mode)
	if _behavior:
		_behavior.setup(self)

func _create_behavior_instance(mode: SatelliteBehaviorMode) -> SatelliteBehaviorBase:
	var behavior_script: GDScript
	match mode:
		SatelliteBehaviorMode.LAUNCH_ATTACK:
			behavior_script = BEHAVIOR_LAUNCH_ATTACK_SCRIPT
		_:
			behavior_script = BEHAVIOR_SHOOT_ONLY_SCRIPT

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

	if not bullet_scene or not bullet_scene.can_instantiate():
		push_error("Satellite %s has invalid bullet_scene; disabling shooting." % name)
		is_shooting_active = false
		if timer:
			timer.stop()

func _play_shoot_animation_if_available() -> void:
	if animation_player == null:
		return
	if animation_player.has_animation("shoot"):
		animation_player.play("shoot")
	elif animation_player.has_animation("Shoot"):
		animation_player.play("Shoot")

func _on_timer_timeout() -> void:
	if not is_shooting_active:
		return
	if not bullet_scene or not bullet_scene.can_instantiate():
		return

	var base_damage: int = _get_current_satellite_total_damage()
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
	return max(1, satellite_base_damage + satellite_damage_bonus)

func set_shooting_active(active: bool) -> void:
	is_shooting_active = active
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
	fire_rate = maxf(0.05, original_fire_rate * shadow_fire_rate_multiplier)
	if timer:
		timer.wait_time = fire_rate
		if is_shooting_active:
			timer.start()
	if _behavior:
		_behavior.on_shadow_mode_changed(true)

func _on_shadow_mode_deactivated() -> void:
	if not is_shadow_mode_active:
		return
	is_shadow_mode_active = false
	fire_rate = original_fire_rate
	if timer:
		timer.wait_time = fire_rate
		if is_shooting_active:
			timer.start()
	if _behavior:
		_behavior.on_shadow_mode_changed(false)

func set_satellite_id(id: String) -> void:
	satellite_id = id
	_load_satellite_data()

func get_satellite_id() -> String:
	return satellite_id

func apply_damage_bonus(new_damage_bonus: int) -> void:
	satellite_damage_bonus = max(0, new_damage_bonus)

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
