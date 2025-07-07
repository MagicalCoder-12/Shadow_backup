extends Area2D
class_name Player

# Preloaded scenes
var plBullet: PackedScene = preload("res://Bullet/Bullet.tscn")
var plSuperBullet: PackedScene = preload("res://Bullet/super_bullet.tscn")
var shadow_texture: Texture2D = preload("res://Textures/player/Spaceships-13/spaceships/g-02.png")

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

# Exported variables
@export var speed: float = 500.0
@export var touch_speed: float = 200.0
@export var smoothness: float = 0.2
@export var normal_fire_delay: float = 0.3
@export var boundary_padding: float = 10.0
@export var max_life: int = 5
@export var shadow_speed_multiplier: float = 1.2
@export var shadow_fire_delay_multiplier: float = 0.7
@export var spread_angle_increment: float = 15.0
@export var spawn_point_offset: float = 5.0
@export var super_mode_damage_boost: int = 10
@export var super_mode_speed_multiplier: float = 2.0
@export var super_mode_fire_delay: float = 0.15
@export var super_mode_bullet_speed: float = 5000.0
@export var shadow_bullet_count: int = 12

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
var input_enabled := true

func _ready() -> void:
	# Sync lives with GameManager
	lives = GameManager.player_lives
	print("Player lives synced to: %d in _ready" % lives)
	if GameManager.autosave_progress:
		GameManager.save_progress()
	sprite_2d.show()
	# Cache original texture and speed
	if sprite_2d:
		original_texture = sprite_2d.texture
	else:
		push_error("Sprite2D node is missing in Player.tscn")
	original_speed = speed

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

	# Connect signals
	area_entered.connect(_on_area_entered)
	GameManager.on_player_life_changed.connect(_on_player_life_changed)
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	GameManager.level_completed.connect(_on_level_completed)
	# Apply shadow mode if enabled
	if GameManager.shadow_mode_enabled:
		_on_shadow_mode_activated()

	target_position = position

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


func _on_area_entered(area: Area2D) -> void:
	if area is Powerup:
		area.applyPowerup(self)

func _on_shadow_mode_activated() -> void:
	if GameManager.player_stats.get("is_shadow_mode_active", false):
		return
	GameManager.player_stats["is_shadow_mode_active"] = true
	if sprite_2d:
		sprite_2d.texture = shadow_texture
		sprite_2d.modulate = Color(1.2, 1.2, 1.2)
	speed = original_speed * shadow_speed_multiplier
	fire_delay_timer.wait_time = shadow_fire_delay_multiplier
	GameManager.player_stats["bullet_damage"] = GameManager.player_stats.get("base_bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE) * 2

func _on_shadow_mode_deactivated() -> void:
	if not GameManager.player_stats.get("is_shadow_mode_active", false):
		return
	GameManager.player_stats["is_shadow_mode_active"] = false
	if sprite_2d and original_texture:
		sprite_2d.texture = original_texture
		sprite_2d.modulate = Color(1.0, 1.0, 1.0)
	speed = original_speed
	fire_delay_timer.wait_time = normal_fire_delay
	GameManager.player_stats["bullet_damage"] = GameManager.player_stats.get("base_bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE)

func shoot() -> void:
	fire_delay_timer.start(fire_delay_timer.wait_time)
	var is_super_mode = GameManager.player_stats.get("is_super_mode_active", false)
	var is_shadow_mode = GameManager.player_stats.get("is_shadow_mode_active", false)
	var bullet_scene: PackedScene = plSuperBullet if is_super_mode or is_shadow_mode else plBullet
	var bullet_speed: float = super_mode_bullet_speed if is_super_mode else GameManager.DEFAULT_BULLET_SPEED
	var bullet_damage: int = GameManager.player_stats.get("bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE)

	if is_shadow_mode and not is_super_mode:
		var angle_step: float = 360.0 / shadow_bullet_count
		for i in shadow_bullet_count:
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
	else:
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

	# Play shooting sound via AudioManager
	if AudioManager:
		AudioManager.play_sound_effect(preload("res://Textures/Music/Laser_Shoot16.wav"), "Bullet")

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
	if just_revived or !invincibility_timer.is_stopped() or GameManager.player_stats.get("is_shadow_mode_active", false):
		return

	# Save current stats
	GameManager.save_player_stats(
		GameManager.player_stats.get("attack_level", 0),
		GameManager.player_stats.get("bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE),
		GameManager.player_stats.get("base_bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE),
		GameManager.player_stats.get("is_shadow_mode_active", false)
	)

	# Update lives without triggering signal loop
	lives = max(0, lives - amount)
	GameManager.player_lives = lives
	print("Player damaged, lives: %d" % lives)
	if GameManager.autosave_progress:
		GameManager.save_progress()

	satellite.set_shooting_active(false)
	satellite_2.set_shooting_active(false)

	# Set collision mask to layer 2 (power-ups only)
	if collision_shape:
		set_collision_layer_value(1, false)
		set_collision_layer_value(2, true)
	else:
		push_error("CollisionShape2D is null, cannot update collision mask")

	# Start invincibility
	invincibility_timer.start(2)
	blinking(true)

	if lives > 0:
		sprite_2d.visible = true
		is_alive = true
		set_collision_layer_value(1, true)
		set_collision_layer_value(2, false)
		satellite.set_shooting_active(true)
		satellite_2.set_shooting_active(true)
		var cam := get_tree().current_scene.get_node_or_null("Cam")
		if cam and cam.has_method("shake"):
			cam.shake(20)
	else:
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
	print("Player revived with %d lives" % Player_lives)
	set_physics_process(true)
	set_process(true)

	# Restore player stats
	GameManager.restore_player_stats(self)

	# Set spawn position
	if GameManager.player_spawn_position == Vector2.ZERO:
		GameManager.set_spawn_position()

	var target_pos = GameManager.player_spawn_position - Vector2(0, 500)
	var start_pos = target_pos + Vector2(0, 3500)
	global_position = start_pos

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	print("Player lives set to: %d in set_lives" % lives)
	if lives <= 0:
		is_alive = false
		queue_free()
		GameManager.game_over_triggered.emit()

func blinking(state: bool) -> void:
	if not sprite_2d:
		push_error("Cannot toggle blinking: sprite_2d is null")
		return
	if state:
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
	else:
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
	# Reset firing positions
	for child in firing_positions.get_children():
		if child.name not in ["LeftGun", "RightGun"]:
			child.queue_free()
	super_mode_spawn_points.clear()

	# Update GameManager stats
	GameManager.player_stats["attack_level"] = clamp(attack_level_value, 0, GameManager.MAX_ATTACK_LEVEL)
	GameManager.player_stats["bullet_damage"] = bullet_damage_value
	GameManager.player_stats["base_bullet_damage"] = base_bullet_damage_value
	GameManager.player_stats["is_shadow_mode_active"] = shadow_mode_active

	# Add firing positions based on attack level
	for i in range(1, GameManager.player_stats["attack_level"] + 1):
		add_firing_position(i)

	# Apply shadow mode
	if shadow_mode_active:
		_on_shadow_mode_activated()
	else:
		_on_shadow_mode_deactivated()

func increase_bullet_damage(amount: int) -> void:
	if GameManager.player_stats.get("attack_level", 0) >= GameManager.MAX_ATTACK_LEVEL:
		if power_up_notification:
			power_up_notification.text = "OVERCLOCKED"
			power_up_notification.visible = true
			get_tree().create_timer(2.0).timeout.connect(func(): power_up_notification.visible = false)
		return
	GameManager.player_stats["bullet_damage"] += amount
	GameManager.player_stats["base_bullet_damage"] += amount
	GameManager.player_stats["attack_level"] += 1
	add_firing_position(GameManager.player_stats["attack_level"])
	if GameManager.player_stats.get("is_shadow_mode_active", false) and not GameManager.player_stats.get("is_super_mode_active", false):
		GameManager.player_stats["bullet_damage"] = GameManager.player_stats["base_bullet_damage"] * 2

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
	GameManager.player_stats["is_super_mode_active"] = true
	GameManager.player_stats["bullet_damage"] = int(GameManager.player_stats.get("bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE) * multiplier_div) + super_mode_damage_boost
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
	GameManager.player_stats["is_super_mode_active"] = false
	GameManager.player_stats["bullet_damage"] = GameManager.player_stats.get("base_bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE) * 2 if GameManager.player_stats.get("is_shadow_mode_active", false) else GameManager.player_stats.get("base_bullet_damage", GameManager.DEFAULT_BULLET_DAMAGE)
	fire_delay_timer.wait_time = normal_fire_delay if not GameManager.player_stats.get("is_shadow_mode_active", false) else normal_fire_delay * shadow_fire_delay_multiplier
	for marker in super_mode_spawn_points:
		marker.queue_free()
	super_mode_spawn_points.clear()

func _on_player_life_changed(new_lives: int) -> void:
	lives = clamp(new_lives, 0, max_life)
	print("Player lives updated via signal: %d" % lives)
	if lives <= 0:
		is_alive = false
		queue_free()
		GameManager.game_over_triggered.emit()

func increase_life(amount: int) -> void:
	if amount <= 0:
		return
	lives = min(max_life, lives + amount)
	GameManager.player_lives = lives
	print("Player lives increased to: %d" % lives)
	if GameManager.autosave_progress:
		GameManager.save_progress()

func _on_game_over_triggered() -> void:
	is_alive = false
	queue_free()
	
func _on_level_completed(_level_num):
	input_enabled = false
	GameManager.player_stats["attack_level"] = 0
	GameManager.player_stats["bullet_damage"] = GameManager.DEFAULT_BULLET_DAMAGE
	if GameManager.autosave_progress:
		GameManager.save_progress()
	
