extends Area2D
class_name ShadowUnlockBoss

## Enum for different attack types.
enum AttackType { SPREAD_SHOT, HOMING_SHOT, LASER_BURST, CIRCLE_SHOT }

## Maximum health of the boss.
@export var max_health: int = 10000

## Base interval between attacks (seconds).
@export var attack_interval: float = 5.0

## Scene for boss projectiles (must use HomingBullet.gd).
@export var projectile_scene: PackedScene

## Movement speed (pixels per second).
@export var move_speed: float = 200.0

## Horizontal movement range from center (pixels).
@export var move_range: float = 300.0

## Shadow-themed sprite for phase 2.
var shadow_boss_sprite: Texture2D = preload("res://Textures/Boss/B1.png")

## Node references.
@onready var attack_timer: Timer = $AttackTimer
@onready var nozzel: Node2D = $Sprite2D/Nozzel
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var boss_death_particles: CPUParticles2D = $BossDeathParticles
@onready var boss_death: AudioStreamPlayer = $BossDeath
@onready var phase_change: AudioStreamPlayer2D = $PhaseChange

## Signals emitted by the boss.
signal boss_defeated
signal unlock_shadow_mode

## Current health of the boss.
var current_health: int

## Current movement direction (1.0 right, -1.0 left, 0.0 stationary).
var move_direction: float = 0.0

## Last recorded position for movement direction calculation.
var last_position: Vector2

## Whether the boss is in phase 2 (health <= 50%).
var is_phase_two: bool = false

## Whether the boss is defeated.
var defeated: bool = false

## Whether the boss is invincible.
var is_invincible: bool = false

## Cached effects layer node.
var effects_layer: Node

## Time since last dash.
var dash_cooldown: float = 0.0

## Constants for attack variations.
const MUZZLE_FLASH_DURATION: float = 1.0
const PHASE_TWO_ATTACK_INTERVAL_MULTIPLIER: float = 0.7
const PHASE_TWO_MOVE_SPEED_MULTIPLIER: float = 1.5
const DASH_INTERVAL: float = 5.0
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.3
const INVINCIBILITY_DURATION: float = 5.0
const BULLET_LIFETIME: float = 3.0  # Lifetime for bullets in seconds

func _ready() -> void:
	if max_health <= 0:
		push_error("Warning: max_health is non-positive. Setting to 10000.")
		max_health = 10000
	if attack_interval <= 0:
		push_error("Warning: attack_interval is non-positive. Setting to 2.0.")
		attack_interval = 2.0
	if move_speed <= 0:
		push_error("Warning: move_speed is non-positive. Setting to 200.0.")
		move_speed = 200.0
	if move_range <= 0:
		push_error("Warning: move_range is non-positive. Setting to 300.0.")
		move_range = 300.0
	if not projectile_scene or not projectile_scene.can_instantiate():
		push_error("Error: Invalid projectile_scene. Set res://Bullets/HomingBullet.tscn in editor.")
	if not nozzel:
		push_error("Error: Nozzel node not found.")
	if not sprite_2d:
		push_error("Error: Sprite2D node not found.")
	if not health_bar:
		push_error("Error: HealthBar node not found.")
	if not shadow_boss_sprite:
		push_error("Warning: shadow_boss_sprite not set. Phase 2 will use default sprite.")
	if not animation_player:
		push_error("Error: AnimationPlayer node not found.")
	if not boss_death_particles:
		push_error("Error: BossDeathParticles node not found.")
	if not boss_death:
		push_error("Error: BossDeath AudioStreamPlayer not found.")
	if not phase_change:
		push_error("Error: PhaseChange AudioStreamPlayer2D not found.")
	
	current_health = max_health
	attack_timer.wait_time = attack_interval
	attack_timer.start()
	last_position = global_position
	effects_layer = get_tree().current_scene.get_node_or_null("Effects")
	
	health_bar.max_value = max_health
	health_bar.value = max_health
	
	if animation_player:
		animation_player.play("Shrink")
	else:
		push_error("Warning: AnimationPlayer missing, cannot play 'Shrink'.")
	
	add_to_group(GameManager.GROUP_BOSS)
	
	if not boss_defeated.is_connected(GameManager._on_boss_defeated):
		boss_defeated.connect(GameManager._on_boss_defeated)
	if not unlock_shadow_mode.is_connected(GameManager._on_unlock_shadow_mode):
		unlock_shadow_mode.connect(GameManager._on_unlock_shadow_mode)
	
	start_movement()

func start_movement() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_x: float = viewport_size.x / 2
	global_position = Vector2(center_x, 500)

func _physics_process(delta: float) -> void:
	if defeated:
		return
	var current_speed: float = move_speed * (PHASE_TWO_MOVE_SPEED_MULTIPLIER if is_phase_two else 1.0)
	var center_x: float = get_viewport().get_visible_rect().size.x / 2
	var t: float = Time.get_ticks_msec() / 1000.0
	var offset_x: float = sin(t * current_speed / 200.0) * move_range * (0.5 if is_phase_two else 1.0)
	global_position.x = center_x + offset_x
	
	if randf() < 0.02 * delta and not is_phase_two:
		current_speed = 0.0
		await get_tree().create_timer(0.5).timeout
	
	var current_position: Vector2 = global_position
	move_direction = 1.0 if current_position.x > last_position.x else -1.0 if current_position.x < last_position.x else 0.0
	last_position = current_position
	
	dash_cooldown -= delta
	if dash_cooldown <= 0.0 and randf() < 0.15 * delta:
		perform_dash()

func perform_dash() -> void:
	if defeated:
		return
	dash_cooldown = DASH_INTERVAL * (0.7 if is_phase_two else 1.0)
	var dash_direction: float = 1.0 if randi() % 2 == 0 else -1.0
	var target_x: float = global_position.x + dash_direction * move_range * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position:x", target_x, DASH_DURATION).set_trans(Tween.TRANS_QUAD)
	await tween.finished

func take_damage(amount: int) -> void:
	if defeated or is_invincible or amount <= 0:
		if defeated:
			print("Boss already defeated, ignoring damage")
			return
		elif is_invincible:
			print("Boss is invincible, ignoring damage: %d" % amount)
			return
		else:
			push_warning("Warning: take_damage received non-positive amount: %d" % amount)
		return
		
	# New: Cap health at 50% to ensure phase 2 transition
	var new_health = max(0, current_health - amount)
	@warning_ignore("integer_division")
	if new_health <= max_health / 2 and not is_phase_two:
		@warning_ignore("integer_division")
		new_health = max_health / 2
		is_invincible = true
		print("Boss reached 50% health, setting invincible")
	
	current_health = new_health
	health_bar.value = current_health
	print("Boss health: %d/%d" % [current_health, max_health])
	
	# Modified: Play phase_change audio before phase 2
	@warning_ignore("integer_division")
	if current_health == max_health / 2 and not is_phase_two:
		if phase_change :
			phase_change.play()
			print("Playing phase_change audio for phase 2")
			await phase_change.finished # Wait for audio to complete
		else:
			push_warning("Warning: phase_change not set or has no stream")
		enter_phase_two()
		await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
		is_invincible = false
		print("Boss invincibility ended, can take damage again")
	
	if current_health <= 0:
		defeated = true
		attack_timer.stop()
		# New: Play death particles and audio
		if boss_death_particles:
			boss_death_particles.emitting = true
			boss_death.play()
			print("Playing boss_death audio")
			print("Playing boss_death_particles")
		else:
			print("Warning: boss_death_particles not set")

		# New: Wait for particles and audio to finish
		var particle_lifetime = boss_death_particles.lifetime if boss_death_particles else 1.0
		await get_tree().create_timer(particle_lifetime).timeout
		if boss_death:
			await boss_death.finished
		print("Boss defeated, emitting boss_defeated signal.")
		emit_signal("boss_defeated")
		if not GameManager.shadow_mode_unlocked:
			print("Unlocking shadow mode.")
			emit_signal("unlock_shadow_mode")
		queue_free()

func enter_phase_two() -> void:
	is_phase_two = true
	
	if animation_player:
		# Stop the "Shrink" animation before proceeding
		animation_player.stop()
		print("Stopped 'Shrink' animation for phase 2 transition")
	else:
		push_warning("Warning: AnimationPlayer not found, cannot stop 'Shrink' animation")

	if sprite_2d:
		# Change the sprite texture for phase 2
		if shadow_boss_sprite:
			sprite_2d.texture = shadow_boss_sprite
			print("Changed sprite to shadow_boss_sprite for phase 2")
		else:
			push_warning("Warning: No shadow_boss_sprite set for phase 2.")

		# Play scale animation for visual effect
		var tween: Tween = create_tween()
		tween.tween_property(sprite_2d, "scale", Vector2(1.2, 1.2), 0.4)
		tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), 0.4)
	else:
		push_warning("Error: Sprite2D node not found.")

	attack_timer.wait_time = attack_interval * PHASE_TWO_ATTACK_INTERVAL_MULTIPLIER
	spawn_phase_transition_effect()
	print("Entered phase 2")

func spawn_phase_transition_effect() -> void:
	var effect_scene: PackedScene = preload("res://Bosses/phase_transition_effect.tscn")
	if effect_scene and effect_scene.can_instantiate():
		var effect: Node = effect_scene.instantiate()
		effect.global_position = global_position
		if effects_layer:
			effects_layer.call_deferred("add_child", effect)
		else:
			get_tree().current_scene.call_deferred("add_child", effect)
	else:
		push_warning("Warning: phase_transition_effect.tscn not found or invalid.")

func _on_area_entered(area: Area2D) -> void:
	if defeated:
		return
	if area.is_in_group("Player"):
		area.call("damage", 1)
		take_damage(500)

func _on_attack_timer_timeout() -> void:
	if defeated:
		return
	spawn_muzzle_flash()
	var attack_weights: Array = [0.3, 0.2, 0.5] if is_phase_two else [0.5, 0.3, 0.2]
	var attack: AttackType
	if is_phase_two:
		attack = [AttackType.CIRCLE_SHOT, AttackType.HOMING_SHOT, AttackType.LASER_BURST][rand_weighted(attack_weights)]
	else:
		attack = AttackType.values()[rand_weighted(attack_weights)]
	print("Selected attack: %s" % AttackType.keys()[attack])
	match attack:
		AttackType.SPREAD_SHOT:
			fire_spread_shot()
		AttackType.HOMING_SHOT:
			fire_homing_shot()
		AttackType.LASER_BURST:
			fire_laser_burst()
		AttackType.CIRCLE_SHOT:
			fire_circle_shot()
	attack_timer.start(attack_interval * (PHASE_TWO_ATTACK_INTERVAL_MULTIPLIER if is_phase_two else 1.0) * randf_range(0.7, 1.3))

func rand_weighted(weights: Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var r: float = randf() * total
	var sum: float = 0.0
	for i in range(weights.size()):
		sum += weights[i]
		if r <= sum:
			return i
	return weights.size() - 1

func spawn_muzzle_flash() -> void:
	var muzzle_flash_scene: PackedScene = preload("res://Bosses/muzzle_flash.tscn")
	if muzzle_flash_scene and muzzle_flash_scene.can_instantiate():
		var muzzle_flash: Node = muzzle_flash_scene.instantiate()
		muzzle_flash.global_position = nozzel.global_position
		if effects_layer:
			effects_layer.call_deferred("add_child", muzzle_flash)
		else:
			get_tree().current_scene.call_deferred("add_child", muzzle_flash)
		await get_tree().create_timer(MUZZLE_FLASH_DURATION).timeout
		muzzle_flash.call_deferred("queue_free")
	else:
		print("Warning: muzzle_flash.tscn not found or invalid.")

func fire_spread_shot() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid.")
		return
	var bullet_count: int = 12
	var angle_offset: float = deg_to_rad(15.0)
	var base_angle: float = PI / 2
	if move_direction > 0:
		base_angle = PI
	elif move_direction < 0:
		base_angle = 0.0
	
	for i in range(bullet_count):
		var bullet: Node = projectile_scene.instantiate()
		if bullet:
			bullet.global_position = nozzel.global_position
			bullet.global_rotation = base_angle + angle_offset * (i - bullet_count / 2.0 + randf_range(-0.3, 0.3))
			bullet.speed = GameManager.DEFAULT_BULLET_SPEED * randf_range(0.8, 1.2)
			bullet.damage = 1
			get_tree().current_scene.call_deferred("add_child", bullet)
			# Add lifetime to bullet
			get_tree().create_timer(BULLET_LIFETIME).timeout.connect(func():
				if is_instance_valid(bullet):
					bullet.queue_free()
					print("Spread shot bullet freed after %s seconds" % BULLET_LIFETIME)
			)
			print("Spawned spread shot bullet at %s, rotation %s" % [bullet.global_position, bullet.global_rotation])
		else:
			print("Error: Failed to instantiate bullet for spread shot.")

func fire_homing_shot() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid.")
		return
	var bullet_count: int = 6 if is_phase_two else 4
	var player: Node = get_tree().get_first_node_in_group("Player")
	var target_pos: Vector2 = player.global_position if player else global_position + Vector2(0, 1000)
	
	for i in range(bullet_count):
		var bullet: Node = projectile_scene.instantiate()
		if bullet:
			bullet.global_position = nozzel.global_position
			bullet.global_rotation = randf_range(-PI / 4, PI / 4)
			bullet.speed = 300.0 * (2.0 if is_phase_two else 1.0)
			bullet.damage = 1
			if bullet.has_method("set_target"):
				bullet.set_target(target_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100)))
				bullet.turn_rate = randf_range(0.05, 0.09) if is_phase_two else randf_range(0.03, 0.07)
			get_tree().current_scene.call_deferred("add_child", bullet)
			# Add lifetime to bullet
			get_tree().create_timer(BULLET_LIFETIME).timeout.connect(func():
				if is_instance_valid(bullet):
					bullet.queue_free()
					print("Homing shot bullet freed after %s seconds" % BULLET_LIFETIME)
			)
			print("Spawned homing shot bullet at %s, targeting %s" % [bullet.global_position, target_pos])
		else:
			print("Error: Failed to instantiate bullet for homing shot.")

func fire_laser_burst() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid.")
		return
	var burst_count: int = 4 if is_phase_two else 3
	for burst in range(burst_count):
		for i in range(2):
			var bullet: Node = projectile_scene.instantiate()
			if bullet:
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = PI / 2 + deg_to_rad((5 if is_phase_two else 10) * (i - 0.5)) + randf_range(-0.1, 0.1)
				bullet.speed = GameManager.DEFAULT_BULLET_SPEED * (2.0 if is_phase_two else 1.8)
				bullet.damage = 1
				get_tree().current_scene.call_deferred("add_child", bullet)
				# Add lifetime to bullet
				get_tree().create_timer(BULLET_LIFETIME).timeout.connect(func():
					if is_instance_valid(bullet):
						bullet.queue_free()
						print("Laser burst bullet freed after %s seconds" % BULLET_LIFETIME)
				)
				print("Spawned laser burst bullet at %s, rotation %s" % [bullet.global_position, bullet.global_rotation])
			else:
				print("Error: Failed to instantiate bullet for laser burst.")
		await get_tree().create_timer(0.1 if is_phase_two else 0.15).timeout

func fire_circle_shot() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid.")
		return
	var bullet_count: int = 16
	var angle_increment: float = 2 * PI / bullet_count
	
	for i in range(bullet_count):
		var bullet: Node = projectile_scene.instantiate()
		if bullet:
			bullet.global_position = nozzel.global_position
			bullet.global_rotation = i * angle_increment + randf_range(-0.1, 0.1)
			bullet.speed = GameManager.DEFAULT_BULLET_SPEED * 1.5
			bullet.damage = 1
			get_tree().current_scene.call_deferred("add_child", bullet)
			# Add lifetime to bullet
			get_tree().create_timer(BULLET_LIFETIME).timeout.connect(func():
				if is_instance_valid(bullet):
					bullet.queue_free()
					print("Circle shot bullet freed after %s seconds" % BULLET_LIFETIME)
			)
			print("Spawned circle shot bullet at %s, rotation %s" % [bullet.global_position, bullet.global_rotation])
		else:
			print("Error: Failed to instantiate bullet for circle shot.")
