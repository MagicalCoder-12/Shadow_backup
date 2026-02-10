extends Node2D

@export var bullet_scene: PackedScene = preload("res://Bullet/Sat_bullet/Sat_bullet.tscn")
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
	
	# Connect to GameManager signals for shadow mode shenanigans
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	
	# Validate bullet_scene to avoid shooting blanks
	if not bullet_scene or not bullet_scene.can_instantiate():
		push_error("SatelliteWeapon: Invalid bullet_scene. Expected SatelliteBullet.tscn.")
		is_shooting_active = false
		timer.stop()

## Shoots bullets like a space cowboy, shadow mode or not.
func _on_timer_timeout() -> void:
	if not is_shooting_active or not bullet_scene:
		return
	
	# Get the player node to snag that sweet bullet damage
	var player: Node = get_parent().get_parent()
	var bullet_damage: int = GameManager.player_manager.default_bullet_damage
	
	if player:
		bullet_damage = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)

	
	if is_shadow_mode_active:
		# Shadow mode: unleash a spread of homing bullets like a cosmic sprinkler
		for angle in [-shadow_spread_angle, 0, shadow_spread_angle]:
			var bullet: Node = BulletFactory.spawn_bullet(
				bullet_scene,
				nozzle.global_position,
				deg_to_rad(angle),
				1500,
				int(bullet_damage * 0.8)  # Satellite bullets pack 80% of the punch
			)
			if bullet:
				# Set homing strength if the bullet has this property
				if "homing_strength" in bullet:
					bullet.homing_strength = shadow_homing_strength  # Crank up the homing juice
				# Only add the bullet to the scene if it doesn't already have a parent
				if not bullet.get_parent():
					get_tree().current_scene.add_child(bullet)
				elif bullet.get_parent() != get_tree().current_scene:
					# If bullet is in a different scene, remove it from there first
					bullet.get_parent().remove_child(bullet)
					get_tree().current_scene.add_child(bullet)
	else:
		# Normal mode: just a single, no-nonsense bullet
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			nozzle.global_position,
			0,
			1500,
			int(bullet_damage * 0.8)  # Keepin' it consistent
		)
		if bullet:
			# Set homing strength if the bullet has this property
			if "homing_strength" in bullet:
				bullet.homing_strength = shadow_homing_strength  # Crank up the homing juice
			# Only add the bullet to the scene if it doesn't already have a parent
			if not bullet.get_parent():
				get_tree().current_scene.add_child(bullet)
			elif bullet.get_parent() != get_tree().current_scene:
				# If bullet is in a different scene, remove it from there first
				bullet.get_parent().remove_child(bullet)
				get_tree().current_scene.add_child(bullet)

## Toggles shooting on or off, like flipping a laser switch.
func set_shooting_active(active: bool) -> void:
	is_shooting_active = active
	if active and timer.is_stopped():
		timer.start()
	elif not active:
		timer.stop()
		
## Activates shadow mode, making this satellite a lean, mean, bullet-spraying machine.
func _on_shadow_mode_activated() -> void:
	if is_shadow_mode_active:
		return
	is_shadow_mode_active = true
	fire_rate = original_fire_rate * shadow_fire_rate_multiplier
	timer.wait_time = fire_rate
	if is_shooting_active:
		timer.start()

## Deactivates shadow mode, back to regular pew-pew duty.
func _on_shadow_mode_deactivated() -> void:
	if not is_shadow_mode_active:
		return
	is_shadow_mode_active = false
	fire_rate = original_fire_rate
	timer.wait_time = fire_rate
	if is_shooting_active:
		timer.start()

var satellite_id: String = ""

func set_satellite_id(id: String) -> void:
	satellite_id = id

func _load_satellite_data() -> void:
	# This function is called by the Player when satellite data needs to be updated
	# For example, when the satellite texture or stats change in the upgrade menu
	
	# If satellite_id is not set via the setter method, try to get it from metadata
	if satellite_id.is_empty():
		if has_meta("satellite_id"):
			satellite_id = get_meta("satellite_id")
	
	# Look up satellite data in GameManager
	for sat_data in GameManager.satellites:
		if sat_data.get("id", "") == satellite_id:
			# Update any visual properties based on satellite data
			if sat_data.has("texture") and sat_data["texture"]:
				var texture_path = sat_data["texture"]
				if ResourceLoader.exists(texture_path):
					var texture = load(texture_path)
					# Find the sprite node and update its texture
					var sprite = get_node_or_null("Sprite2D")
					if sprite:
						sprite.texture = texture
						print("Updated satellite texture for: ", satellite_id)
						break
				else:
					push_warning("Invalid texture path for satellite: " + texture_path)
					break
