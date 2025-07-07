extends Node2D

@export var bullet_scene: PackedScene = preload("res://Bullet/Sat_bullet.tscn")
@export var fire_rate: float = 0.1
@export var shadow_spread_angle: float = 15.0
@export var shadow_fire_rate_multiplier: float = 0.7
@export var shadow_homing_strength: float = 1.0  # Increased homing in shadow mode

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var nozzle: Node2D = $Nozel
@onready var timer: Timer = $Timer

var is_shooting_active: bool = true
var original_fire_rate: float
var is_shadow_mode_active: bool = false

func _ready() -> void:
	original_fire_rate = fire_rate
	timer.wait_time = fire_rate
	timer.one_shot = false
	timer.start()
	if animation_player:
		animation_player.play("shoot")
	
	# Connect to GameManager signals
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	
	# Validate bullet_scene
	if not bullet_scene or not bullet_scene.can_instantiate():
		push_error("SatelliteWeapon: Invalid bullet_scene. Expected SatelliteBullet.tscn.")
		is_shooting_active = false
		timer.stop()

## Shoots bullets based on shadow mode state.
func _on_timer_timeout() -> void:
	if is_shooting_active and bullet_scene:
		var player: Node = get_parent().get_parent()
		var bullet_damage: int = player.bullet_damage if player and player.has_method("bullet_damage") else GameManager.DEFAULT_BULLET_DAMAGE
		
		if is_shadow_mode_active:
			for angle in [-shadow_spread_angle, 0, shadow_spread_angle]:
				var bullet: Node = BulletFactory.spawn_bullet(
					bullet_scene,
					nozzle.global_position,
					deg_to_rad(angle),
					1500,
					int(bullet_damage * 0.8)  # SatelliteBullet uses 80% of base damage
				)
				if bullet and bullet is SatelliteBullet:
					bullet.homing_strength = shadow_homing_strength  # Enhance homing in shadow mode
					get_tree().current_scene.call_deferred("add_child", bullet)
		else:
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				nozzle.global_position,
				0,
				1500,
				int(bullet_damage * 0.8)  # Consistent with SatelliteBullet's damage scaling
			)
			if bullet and bullet is SatelliteBullet:
				get_tree().current_scene.call_deferred("add_child", bullet)

## Sets whether the satellite is actively shooting.
func set_shooting_active(active: bool) -> void:
	is_shooting_active = active
	if active and timer.is_stopped():
		timer.start()
	elif not active:
		timer.stop()

## Activates shadow mode for the satellite.
func _on_shadow_mode_activated() -> void:
	if is_shadow_mode_active:
		return
	is_shadow_mode_active = true
	fire_rate = original_fire_rate * shadow_fire_rate_multiplier
	timer.wait_time = fire_rate
	if is_shooting_active:
		timer.start()

## Deactivates shadow mode for the satellite.
func _on_shadow_mode_deactivated() -> void:
	if not is_shadow_mode_active:
		return
	is_shadow_mode_active = false
	fire_rate = original_fire_rate
	timer.wait_time = fire_rate
	if is_shooting_active:
		timer.start()
