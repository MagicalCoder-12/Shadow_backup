extends Area2D
class_name Player

@warning_ignore("unused_signal")
signal victory_pose_done()

# Preloaded scenes
var plBullet: PackedScene = preload("res://Bullet/Bullet.tscn")
var plSuperBullet: PackedScene = preload("res://Bullet/super_bullet.tscn")

# Node references
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var firing_positions: Node2D = $Sprite2D/FiringPositions
@onready var fire_delay_timer: Timer = $FireDelayTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_animation: CPUParticles2D = $DeathAnimation
@onready var satellite: Node2D = $Sprite2D/Satellite
@onready var satellite_2: Node2D = $Sprite2D/Satellite2
@onready var power_up_notification: Label = $PowerUpNotification
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Exported variables
@export var ship_id: String = ""  # Unique identifier for the ship
@export var speed: float = 2000.0
@export var touch_speed: float = 500.0
@export var smoothness: float = 0.3
@export var normal_fire_delay: float = 0.3
@export var boundary_padding: float = 10.0
@export var max_life: int = 4
@export var shadow_speed_multiplier: float = 1.2
@export var shadow_fire_delay_multiplier: float = 0.1
@export var spread_angle_increment: float = 10.0
@export var spawn_point_offset: float = 5.0
@export var super_mode_damage_boost: int = 2
@export var super_mode_speed_multiplier: float = 2.0
@export var super_mode_fire_delay: float = 0.15
@export var super_mode_bullet_speed: float = 5000.0
@export var shadow_bullet_count: int = 25
@export var base_bullet_damage: int = 20
@export var shadow_texture: Texture2D = preload("res://Textures/player/g-02.png")
@export var enable_debug_logging: bool = false  # Toggle for debug messages
@export var evolution_textures: Array[Texture2D] = []  # Textures for each evolution stage

# Local variables
var velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_touching: bool = false
var is_alive: bool = true
var lives: int = 2  # Synced with GameManager
var original_texture: Texture2D
var original_speed: float
var is_blinking: bool = false
var just_revived: bool = false
var super_mode_timer: Timer
var super_mode_spawn_points: Array[Marker2D] = []
var input_enabled: bool = true

func _ready() -> void:
	_initialize_player()
	_setup_references()
	_connect_signals()
	_apply_initial_state()

func _initialize_player() -> void:
	# Sync lives with GameManager
	lives = GameManager.player_lives
	if GameManager.save_manager.autosave_progress:
		GameManager.save_manager.save_progress()
	
	sprite_2d.show()
	# Cache original speed
	original_speed = speed
	
	# Set ship_id and apply stats and texture from PlayerManager
	ship_id = GameManager.player_manager.selected_ship_id
	_apply_ship_stats()
	_debug_log("Player initialized with ship_id: " + ship_id)
	
	# Add to Player group
	add_to_group("Player")
	
	target_position = position
	
	# Initialize ship-specific base stats
	GameManager.player_manager.player_stats["base_bullet_damage"] = base_bullet_damage
	GameManager.player_manager.player_stats["bullet_damage"] = base_bullet_damage
	
	# Ensure we have the latest upgraded damage if available
	var current_ship_damage = GameManager.player_manager.player_stats.get("base_bullet_damage", base_bullet_damage)
	if current_ship_damage != base_bullet_damage:
		base_bullet_damage = current_ship_damage
		_debug_log("Synchronized damage to upgraded value: %d" % base_bullet_damage)

func _apply_ship_stats() -> void:
	# Find the ship configuration in GameManager.ships and apply stats and texture
	for ship in GameManager.ships:
		if ship.get("id", "") == ship_id:  # Compare with id instead of display_name
			base_bullet_damage = ship.get("damage", base_bullet_damage)
			var stage = ship.get("current_evolution_stage", 0)
			if stage < evolution_textures.size() and evolution_textures[stage]:
				sprite_2d.texture = evolution_textures[stage]
				original_texture = evolution_textures[stage]
			else:
				push_warning("No texture for stage %d of %s" % [stage, ship_id])
			_debug_log("Applied ship stats and texture for %s: speed=%s, damage=%s, stage=%d" % [ship_id, speed, base_bullet_damage, stage])
			return
	_debug_log("Warning: No ship configuration found for ship_id: " + ship_id + ". Using default stats and texture.")

func _setup_references() -> void:
	# Validate node references
	if not death_animation:
		push_warning("DeathAnimation node is missing or not properly set up")
	if not invincibility_timer:
		push_error("InvincibilityTimer node is missing in Player.tscn")
	if not plBullet or not plBullet.can_instantiate():
		push_error("Invalid plBullet scene")
	if not plSuperBullet or not plSuperBullet.can_instantiate():
		push_error("Invalid plSuperBullet scene")
	
	# Set up super mode timer
	super_mode_timer = Timer.new()
	super_mode_timer.name = "SuperModeTimer"
	super_mode_timer.one_shot = true
	add_child(super_mode_timer)
	super_mode_timer.timeout.connect(_on_super_mode_timeout)

func _connect_signals() -> void:
	# Connect to LevelManager
	var level_manager = get_tree().get_first_node_in_group("LevelManager")
	if level_manager:
		if level_manager.has_signal("Victory_pose"):
			level_manager.Victory_pose.connect(_on_victory_pose)
		else:
			_debug_log("LevelManager does not have Victory_pose signal")
	
	# Connect to Level node
	var level_node = get_tree().get_first_node_in_group("Level")
	if level_node and level_node.has_signal("Victory_pose"):
		level_node.Victory_pose.connect(_on_victory_pose)
	else:
		# Try to find the Level node by name if not in group
		level_node = get_parent()
		while level_node and not (level_node is Node and level_node.has_signal("Victory_pose")):
			level_node = level_node.get_parent()
			if level_node == null:
				break
		
		if level_node and level_node.has_signal("Victory_pose"):
			level_node.Victory_pose.connect(_on_victory_pose)
			_debug_log("Connected to Level node by hierarchy traversal")
		else:
			_debug_log("Could not find Level node with Victory_pose signal")
	
	# Connect GameManager signals
	GameManager.on_player_life_changed.connect(_on_player_life_changed)
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.ship_stats_updated.connect(_on_ship_stats_updated)

func _apply_initial_state() -> void:
	# Apply shadow mode if enabled
	if GameManager.level_manager.shadow_mode_enabled:
		_on_shadow_mode_activated()

func _debug_log(message: String) -> void:
	if enable_debug_logging:
		print("[Player Debug] " + message)

func _process(_delta: float) -> void:
	if is_alive and fire_delay_timer.is_stopped():
		shoot()

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	handle_keyboard_movement(delta)
	if is_touching:
		handle_touch_movement()

func _input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_action_pressed("click")):
		var event_pos = event.position
		var controls = get_tree().get_nodes_in_group("UI")
		var is_over_ui = false
		
		for control in controls:
			if control is Control and control.get_global_rect().has_point(event_pos):
				is_over_ui = true
				break

		if is_over_ui:
			if event is InputEventScreenTouch and not event.pressed:
				is_touching = false
			return

		if event is InputEventScreenTouch:
			is_touching = event.pressed
			if is_touching:
				target_position = event.position
		elif event is InputEventScreenDrag:
			is_touching = true
			target_position = event.position
		elif event is InputEventMouseMotion and Input.is_action_pressed("click"):
			is_touching = true
			target_position = event.position


func get_health_percent() -> float:
	return float(lives) / float(max_life)

func _on_shadow_mode_activated() -> void:
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
		return
	GameManager.player_manager.player_stats["is_shadow_mode_active"] = true
	apply_shadow_mode_effects()

func _on_shadow_mode_deactivated() -> void:
	if not GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
		return
	GameManager.player_manager.player_stats["is_shadow_mode_active"] = false
	revert_shadow_mode_effects()

func apply_shadow_mode_effects() -> void:
	if sprite_2d:
		sprite_2d.texture = shadow_texture
		sprite_2d.modulate = Color(1.2, 1.2, 1.2)
	speed = original_speed * shadow_speed_multiplier
	fire_delay_timer.wait_time = shadow_fire_delay_multiplier
	GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.player_stats.get("base_bullet_damage", GameManager.player_manager.default_bullet_damage) * 2

func revert_shadow_mode_effects() -> void:
	if sprite_2d and original_texture:
		sprite_2d.texture = original_texture
		sprite_2d.modulate = Color(1.0, 1.0, 1.0)
	speed = original_speed
	fire_delay_timer.wait_time = normal_fire_delay
	GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.player_stats.get("base_bullet_damage", GameManager.player_manager.default_bullet_damage)

func shoot() -> void:
	fire_delay_timer.start(fire_delay_timer.wait_time)
	var is_super_mode = GameManager.player_manager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	var bullet_scene: PackedScene = plSuperBullet if is_super_mode or is_shadow_mode else plBullet
	var bullet_speed: float = super_mode_bullet_speed if is_super_mode else GameManager.player_manager.default_bullet_speed
	var bullet_damage: int = GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage)

	if is_shadow_mode and not is_super_mode:
		_shoot_shadow_bullets(bullet_scene, bullet_speed, bullet_damage)
	else:
		_shoot_normal_bullets(bullet_scene, bullet_speed, bullet_damage)

	# Play shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")

func _shoot_shadow_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	var angle_step: float = 360.0 / float(shadow_bullet_count)
	for i in range(shadow_bullet_count):
		var angle: float = deg_to_rad(i * angle_step)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * spawn_point_offset
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			global_position + offset,
			angle,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func _shoot_normal_bullets(bullet_scene: PackedScene, bullet_speed: float, bullet_damage: int) -> void:
	for child in firing_positions.get_children():
		var bullet: Node = BulletFactory.spawn_bullet(
			bullet_scene,
			child.global_position,
			child.rotation,
			bullet_speed,
			bullet_damage
		)
		if bullet:
			get_tree().current_scene.call_deferred("add_child", bullet)

func handle_keyboard_movement(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	
	if dir != Vector2.ZERO:
		velocity = dir.normalized() * speed
		position += velocity * delta
		
	clamp_position()

func handle_touch_movement() -> void:
	position = position.lerp(target_position, smoothness)
	clamp_position()

func clamp_position() -> void:
	var view_rect := get_viewport_rect()
	var player_size: Vector2 = collision_shape.shape.get_rect().size if collision_shape else Vector2.ZERO
	var min_pos := Vector2(player_size.x / 2 + boundary_padding, player_size.y / 2 + boundary_padding)
	var max_pos := view_rect.size - min_pos
	position = position.clamp(min_pos, max_pos)

func damage(amount: int) -> void:
	if just_revived or !invincibility_timer.is_stopped() or GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
		return

	_save_current_stats()
	_update_lives_after_damage(amount)
	_disable_satellites()
	_setup_damage_collision()
	_start_invincibility()
	
	if lives > 0:
		_handle_survival()
	else:
		_handle_death()

func _save_current_stats() -> void:
	GameManager.player_manager.save_player_stats(
		GameManager.player_manager.player_stats.get("attack_level", 0),
		GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage),
		GameManager.player_manager.player_stats.get("base_bullet_damage", GameManager.player_manager.default_bullet_damage),
		GameManager.player_manager.player_stats.get("is_shadow_mode_active", false)
	)

func _update_lives_after_damage(amount: int) -> void:
	lives = max(0, lives - amount)
	GameManager.player_lives = lives
	_debug_log("Player damaged, lives: " + str(lives))
	if GameManager.save_manager.autosave_progress:
		GameManager.save_manager.save_progress()

func _disable_satellites() -> void:
	satellite.set_shooting_active(false)
	satellite_2.set_shooting_active(false)

func _setup_damage_collision() -> void:
	# Set collision mask to layer 2 (power-ups only)
	if collision_shape:
		set_collision_layer_value(1, false)
		set_collision_layer_value(2, true)
	else:
		push_error("CollisionShape2D is null, cannot update collision mask")

func _start_invincibility() -> void:
	invincibility_timer.start(2.5)
	blinking(true)

func _handle_survival() -> void:
	sprite_2d.visible = true
	is_alive = true
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, false)
	satellite.set_shooting_active(true)
	satellite_2.set_shooting_active(true)
	
	var cam := get_tree().current_scene.get_node_or_null("Cam")
	if cam and cam.has_method("shake"):
		cam.shake(20)

func _handle_death() -> void:
	sprite_2d.visible = false
	if death_animation:
		death_animation.emitting = true
	else:
		push_error("Cannot emit death animation: DeathAnimation is null")
	
	is_alive = false
	await get_tree().create_timer(death_animation.lifetime if death_animation else 1.0).timeout
	GameManager.game_over_triggered.emit()
	queue_free()

func revive(Player_lives: int) -> void:
	just_revived = true
	self.lives = Player_lives
	GameManager.player_lives = Player_lives
	_debug_log("Player revived with " + str(Player_lives) + " lives")
	
	set_physics_process(true)
	set_process(true)

	# Restore player stats
	GameManager.player_manager.restore_player_stats(self)

	# Set spawn position
	if GameManager.player_manager.player_spawn_position == Vector2.ZERO:
		GameManager.player_manager.set_spawn_position()

	_animate_revival()
	_setup_revival_state()

func _animate_revival() -> void:
	var target_pos = GameManager.player_manager.player_spawn_position - Vector2(0, 500)
	var start_pos = target_pos + Vector2(0, 3500)
	global_position = start_pos

	if is_inside_tree():
		var tween := create_tween()
		if tween:
			tween.tween_property(self, "global_position", target_pos, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _setup_revival_state() -> void:
	if death_animation:
		death_animation.emitting = false
	
	invincibility_timer.start(5.0)
	if collision_shape:
		set_collision_layer_value(1, false)
	
	blinking(true)
	is_alive = true
	GameManager.game_over = false
	satellite.set_shooting_active(true)
	satellite_2.set_shooting_active(true)

func set_lives(new_lives: int) -> void:
	lives = clamp(new_lives, 0, max_life)
	GameManager.player_lives = lives
	_debug_log("Player lives set to: " + str(lives))
	
	if lives <= 0:
		is_alive = false
		queue_free()
		GameManager.game_over_triggered.emit()

func blinking(state: bool) -> void:
	if not sprite_2d:
		push_error("Cannot toggle blinking: sprite_2d is null")
		return
		
	if state:
		_start_blinking()
	else:
		_stop_blinking()

func _start_blinking() -> void:
	if is_blinking:
		return
		
	is_blinking = true
	var blink_timer := Timer.new()
	blink_timer.wait_time = 0.2
	blink_timer.one_shot = false
	blink_timer.name = "BlinkTimer"
	add_child(blink_timer)
	
	if blink_timer.timeout.connect(_on_blink_timer_timeout) != OK:
		push_error("Failed to connect BlinkTimer timeout signal")
		
	sprite_2d.modulate.a = 0.7
	blink_timer.start()

func _stop_blinking() -> void:
	if not is_blinking:
		return
		
	is_blinking = false
	sprite_2d.modulate.a = 1.0
	sprite_2d.visible = true
	
	var blink_timer := get_node_or_null("BlinkTimer")
	if blink_timer:
		blink_timer.stop()
		blink_timer.queue_free()

func _on_blink_timer_timeout() -> void:
	if is_blinking and sprite_2d:
		sprite_2d.visible = !sprite_2d.visible

func _on_invincibility_timer_timeout() -> void:
	just_revived = false
	blinking(false)
	if sprite_2d:
		sprite_2d.visible = true
		sprite_2d.modulate.a = 1.0
	if collision_shape:
		set_collision_layer_value(1, true)  # Re-enable layer 1
	else:
		push_error("CollisionShape2D is null, cannot re-enable collision")

func set_stats(attack_level_value: int, bullet_damage_value: int, base_bullet_damage_value: int, shadow_mode_active: bool) -> void:
	_reset_firing_positions()
	_update_game_manager_stats(attack_level_value, bullet_damage_value, base_bullet_damage_value, shadow_mode_active)
	_setup_firing_positions()
	_apply_mode_effects(shadow_mode_active)

func _reset_firing_positions() -> void:
	for child in firing_positions.get_children():
		if child.name not in ["LeftGun", "RightGun"]:
			child.queue_free()
	super_mode_spawn_points.clear()

func _update_game_manager_stats(attack_level_value: int, bullet_damage_value: int, base_bullet_damage_value: int, shadow_mode_active: bool) -> void:
	GameManager.player_manager.player_stats["attack_level"] = clamp(attack_level_value, 0, GameManager.player_manager.max_attack_level)
	GameManager.player_manager.player_stats["bullet_damage"] = bullet_damage_value
	GameManager.player_manager.player_stats["base_bullet_damage"] = base_bullet_damage_value
	GameManager.player_manager.player_stats["is_shadow_mode_active"] = shadow_mode_active

func _setup_firing_positions() -> void:
	for i in range(1, GameManager.player_manager.player_stats["attack_level"] + 1):
		add_firing_position(i)

func _apply_mode_effects(shadow_mode_active: bool) -> void:
	if shadow_mode_active:
		_on_shadow_mode_activated()
	else:
		_on_shadow_mode_deactivated()

func increase_bullet_damage(amount: int) -> void:
	if GameManager.player_manager.player_stats.get("attack_level", 0) >= GameManager.player_manager.max_attack_level:
		_show_overclocked_notification()
		return
	apply_bullet_damage_increase(amount)

func _show_overclocked_notification() -> void:
	if power_up_notification:
		power_up_notification.text = "OVERCLOCKED"
		power_up_notification.visible = true
		get_tree().create_timer(2.0).timeout.connect(func(): power_up_notification.visible = false)

func apply_bullet_damage_increase(amount: int) -> void:
	GameManager.player_manager.player_stats["bullet_damage"] += amount
	GameManager.player_manager.player_stats["base_bullet_damage"] += amount
	GameManager.player_manager.player_stats["attack_level"] += 1
	add_firing_position(GameManager.player_manager.player_stats["attack_level"])
	
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false) and not GameManager.player_manager.player_stats.get("is_super_mode_active", false):
		GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.player_stats["base_bullet_damage"] * 2

func add_firing_position(level: int) -> void:
	var new_marker := Marker2D.new()
	new_marker.name = "FiringPosition%d" % level
	var angle := deg_to_rad(spread_angle_increment * level)
	var offset := Vector2(spawn_point_offset, 0).rotated(angle)
	new_marker.position = offset
	new_marker.rotation = angle
	firing_positions.add_child(new_marker)

	var mirror_marker := Marker2D.new()
	mirror_marker.name = "FiringPosition%d_Mirror" % level
	mirror_marker.position = Vector2(-offset.x, offset.y)
	mirror_marker.rotation = -angle
	firing_positions.add_child(mirror_marker)

func activate_super_mode(multiplier_div: float, duration: float) -> void:
	GameManager.player_manager.player_stats["is_super_mode_active"] = true
	apply_super_mode_effects(multiplier_div, duration)

func apply_super_mode_effects(multiplier_div: float, duration: float) -> void:
	GameManager.player_manager.player_stats["bullet_damage"] = int(GameManager.player_manager.player_stats.get("bullet_damage", GameManager.player_manager.default_bullet_damage) * multiplier_div) + super_mode_damage_boost
	fire_delay_timer.wait_time = super_mode_fire_delay
	add_super_mode_spawn_points()
	super_mode_timer.start(duration)

func add_super_mode_spawn_points() -> void:
	super_mode_spawn_points.clear()
	var total_angle: float = 100.0
	var start_angle := -5.0 - (total_angle / 2)
	var angle_step: float = total_angle / (GameManager.SUPER_MODE_SPAWN_COUNT - 1)
	
	for i in GameManager.SUPER_MODE_SPAWN_COUNT:
		var marker := Marker2D.new()
		marker.name = "SuperMode%d" % i
		var angle := deg_to_rad(start_angle + angle_step * i)
		var offset := Vector2(spawn_point_offset, 0).rotated(angle)
		marker.position = offset
		marker.rotation = angle
		firing_positions.add_child(marker)
		super_mode_spawn_points.append(marker)

func _on_super_mode_timeout() -> void:
	GameManager.player_manager.player_stats["is_super_mode_active"] = false
	_restore_normal_damage()
	_restore_normal_fire_delay()
	_cleanup_super_mode_spawn_points()

func _restore_normal_damage() -> void:
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
		GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.player_stats.get("base_bullet_damage", GameManager.player_manager.default_bullet_damage) * 2
	else:
		GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.player_stats.get("base_bullet_damage", GameManager.player_manager.default_bullet_damage)

func _restore_normal_fire_delay() -> void:
	if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
		fire_delay_timer.wait_time = normal_fire_delay * shadow_fire_delay_multiplier
	else:
		fire_delay_timer.wait_time = normal_fire_delay

func _cleanup_super_mode_spawn_points() -> void:
	for marker in super_mode_spawn_points:
		marker.queue_free()
	super_mode_spawn_points.clear()

func _on_player_life_changed(new_lives: int) -> void:
	lives = clamp(new_lives, 0, max_life)
	_debug_log("Player lives updated via signal: " + str(lives))
	
	if lives <= 0:
		is_alive = false
		queue_free()
		GameManager.game_over_triggered.emit()

func increase_life(amount: int) -> void:
	if amount <= 0:
		return
		
	lives = min(max_life, lives + amount)
	GameManager.player_lives = lives
	_debug_log("Player lives increased to: " + str(lives))
	
	if GameManager.save_manager.autosave_progress:
		GameManager.save_manager.save_progress()

func _on_game_over_triggered() -> void:
	is_alive = false
	queue_free()
	
func _on_victory_pose():
	_debug_log("Playing victory pose animation")
	if animation_player:
		animation_player.play("Player_sweep")
	else:
		_debug_log("AnimationPlayer not found, cannot play victory pose")
		
func _on_level_completed(_level_num):
	input_enabled = false
	GameManager.player_manager.player_stats["attack_level"] = 0
	GameManager.player_manager.player_stats["bullet_damage"] = GameManager.player_manager.default_bullet_damage
	if GameManager.save_manager.autosave_progress:
		GameManager.save_manager.save_progress()

func _on_ship_stats_updated(updated_ship_id: String, new_damage: int) -> void:
	"""Handle ship stat updates from upgrade system"""
	if updated_ship_id == ship_id:
		# Update this player's base damage if it matches the updated ship
		base_bullet_damage = new_damage
		# Update PlayerManager's player stats
		GameManager.player_manager.player_stats["base_bullet_damage"] = new_damage
		# If not in shadow mode or super mode, also update current bullet damage
		if not GameManager.player_manager.player_stats.get("is_shadow_mode_active", false) and not GameManager.player_manager.player_stats.get("is_super_mode_active", false):
			GameManager.player_manager.player_stats["bullet_damage"] = new_damage
		_debug_log("Ship stats updated: damage is now %d for ship %s" % [new_damage, ship_id])

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Player_sweep":
		_debug_log("Victory pose animation finished")
		emit_signal("victory_pose_done", anim_name)

# Handle collisions with enemies and enemy bullets
func _on_area_entered(area: Area2D) -> void:
	if not is_alive or just_revived:
		return
	
	# Handle enemy collision (direct contact damage)
	if area.is_in_group("Enemy") or area.is_in_group("Enemies"):
		_handle_enemy_collision(area)
		
	if area is Powerup:
		area.applyPowerup(self)

	# Handle enemy bullet collision
	elif area.is_in_group("EnemyBullet"):
		_handle_enemy_bullet_collision(area)
	
	# Handle boss collision
	elif area.is_in_group("Boss"):
		_handle_enemy_collision(area)

func _handle_enemy_collision(enemy: Area2D) -> void:
	"""Handle direct collision with enemy ships"""
	if not is_alive or just_revived:
		return
	
	# Deal damage to player
	damage(1)  # Direct enemy contact deals 1 damage
	
	# Damage or destroy the enemy
	if enemy.has_method("damage"):
		enemy.damage(50)  # Deal significant damage to enemy on collision
	
	_debug_log("Player collided with enemy: %s" % enemy.name)

func _handle_enemy_bullet_collision(bullet: Area2D) -> void:
	"""Handle collision with enemy bullets"""
	if not is_alive or just_revived:
		return
	
	# Deal damage to player
	var bullet_damage = 1
	if bullet.has_method("get_damage"):
		bullet_damage = bullet.get_damage()
	elif bullet.has_variable("damage"):
		bullet_damage = bullet.damage
	
	damage(bullet_damage)
	
	# Destroy the bullet
	if bullet.has_method("queue_free"):
		bullet.queue_free()
	
	_debug_log("Player hit by bullet: %s (damage: %d)" % [bullet.name, bullet_damage])
