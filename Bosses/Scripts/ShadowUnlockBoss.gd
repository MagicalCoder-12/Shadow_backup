extends Area2D
class_name ShadowUnlockBoss

## Simplified AI Boss with two-phase system + initial descent
## Phase 1: Simple spiral pattern
## Phase 2: Converging storm pattern with HellPatternBullet

# Boss Phases (added DESCENT)
enum BossPhase {
	DESCENT,   # Initial drop from off-screen
	PHASE_1,   # Normal phase (100% - 50% health)
	PHASE_2,   # Shadow phase (50% - 0% health)
	TRANSITION # Brief transition between phases
}

## Core Stats
@export var max_health: int = 8000
@export var phase_transition_health: int = 4000  # 50% health threshold
@export var base_attack_interval_p1: float = 2.5  # Phase 1 attack speed
@export var base_attack_interval_p2: float = 1.2  # Phase 2 attack speed (faster)
@export var projectile_scene: PackedScene
@export var move_speed: float = 150.0
@export var descent_target_y: float = 400.0  # Pixels below top of screen

## Visual Components - Different sprites for each phase
var normal_boss_sprite: Texture2D = preload("res://Textures/Boss/oldBossGFX/oldSERPENTARIUS2.png")
var shadow_boss_sprite: Texture2D = preload("res://Textures/Boss/oldBossGFX/oldSERPENTARIUS3.png")
const MUZZLE_FLASH = preload("res://Bosses/muzzle_flash.tscn")
const PHASE_TRANSITION_EFFECT = preload("res://Bosses/phase_transition_effect.tscn")

## Node References
@onready var attack_timer: Timer = $AttackTimer
@onready var nozzel: Node2D = $Sprite2D/Nozzel
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var boss_death_particles: CPUParticles2D = $BossDeathParticles
@onready var boss_death: AudioStreamPlayer = $BossDeath
@onready var phase_change: AudioStreamPlayer2D = $PhaseChange

## Signals (added descent_completed)
@warning_ignore("unused_signal")
signal phase_changed(new_phase: BossPhase)
@warning_ignore("unused_signal")
signal boss_defeated
@warning_ignore("unused_signal")
signal unlock_shadow_mode
@warning_ignore("unused_signal")
signal descent_completed  # New: Fired when boss reaches descent_target_y

## Phase System
var current_phase: BossPhase = BossPhase.DESCENT  # Start in descent
var current_health: int
var has_completed_descent: bool = false
var is_invincible: bool = false

func _ready() -> void:
	_initialize_boss()
	_setup_attack_timer()  # Won't fire until after descent

func _initialize_boss() -> void:
	current_health = max_health
	
	sprite_2d.texture = normal_boss_sprite
	
	health_bar.max_value = max_health
	health_bar.value = max_health
	
	add_to_group(GameManager.GROUP_BOSS)

func _setup_attack_timer() -> void:
	attack_timer.wait_time = base_attack_interval_p1
	attack_timer.timeout.connect(_execute_attack_pattern)
	# Don't start yet—wait for descent

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	
	_handle_descent(delta)
	
	if has_completed_descent:
		_handle_normal_movement(delta)
		_check_phase_transition()

func _handle_descent(delta: float) -> void:
	if current_phase != BossPhase.DESCENT:
		return
	
	# Move straight down until target y
	var target_y = get_viewport().get_visible_rect().position.y + descent_target_y
	global_position.y += move_speed * delta  # Simple downward speed
	
	if global_position.y >= target_y:
		global_position.y = target_y  # Snap to exact position
		_complete_descent()

func _complete_descent() -> void:
	current_phase = BossPhase.PHASE_1
	has_completed_descent = true
	attack_timer.start()  # Now start attacks
	emit_signal("descent_completed")
	phase_changed.emit(current_phase)  # Emit the phase changed signal
	

func _handle_normal_movement(delta: float) -> void:
	# Updated center to match descent target
	var center = Vector2(get_viewport().size.x / 2, descent_target_y)
	var radius = 200
	var target_position = center + Vector2(
		cos(Time.get_ticks_msec() * 0.001) * radius,
		sin(Time.get_ticks_msec() * 0.001 * 0.8) * radius * 0.3
	)
	
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta
	global_position = _clamp_to_screen(global_position)

func _clamp_to_screen(pos: Vector2) -> Vector2:
	var viewport = get_viewport().get_visible_rect()
	var margin = 100
	pos.x = clamp(pos.x, viewport.position.x + margin, viewport.position.x + viewport.size.x - margin)
	pos.y = clamp(pos.y, viewport.position.y + margin, viewport.position.y + viewport.size.y - margin)
	return pos

func _check_phase_transition() -> void:
	if current_phase == BossPhase.PHASE_1 and current_health <= phase_transition_health:
		_trigger_phase_transition()

func _trigger_phase_transition() -> void:
	print("PHASE TRANSITION: Entering Shadow Phase!")
	current_phase = BossPhase.TRANSITION
	phase_changed.emit(current_phase)  # Emit the phase changed signal
	
	attack_timer.stop()
	
	if phase_change:
		phase_change.play()
	
	_execute_phase_transition()

func _execute_phase_transition() -> void:
	animation_player.stop()
	var effect = PHASE_TRANSITION_EFFECT.instantiate()
	add_child(effect)
	effect.global_position = global_position
	sprite_2d.texture = shadow_boss_sprite
	
	await get_tree().create_timer(2.5).timeout  # Slightly longer for drama
	
	current_phase = BossPhase.PHASE_2
	attack_timer.wait_time = base_attack_interval_p2
	attack_timer.start()
	
	print("Shadow Phase activated!")
	emit_signal("phase_changed", BossPhase.PHASE_2)

func _execute_attack_pattern() -> void:
	if current_health <= 0 or current_phase == BossPhase.TRANSITION or current_phase == BossPhase.DESCENT:
		return
	
	_show_muzzle_flash()
	
	if current_phase == BossPhase.PHASE_1:
		_pattern_p2_converging_storm()
	else:
		_pattern_p1_spiral_wave()

func _show_muzzle_flash() -> void:
	var flash = MUZZLE_FLASH.instantiate()
	if flash:
		flash.global_position = nozzel.global_position
		get_tree().current_scene.add_child(flash)

func _pattern_p1_spiral_wave() -> void:
	var bullet_count = 3
	var spiral_arms = 2
	
	for arm in range(spiral_arms):
		@warning_ignore("integer_division")
		for i in range(bullet_count / spiral_arms):
			var bullet = _create_bullet()
			if bullet:
				var angle = (Time.get_ticks_msec() * 0.001 * 1.5) + (arm * PI) + (i * 0.4)
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = angle
				# Use HomingBullet methods instead of direct property access
				if bullet.has_method("set_speed"):
					bullet.set_speed(600 + (i * 8))
				else:
					# Fallback for other bullet types
					bullet.speed = 600 + (i * 8)
				# Add check for player being alive, if not go straight down
				var player = get_tree().get_first_node_in_group("Player")
				# Check if player exists and is alive
				if player and player.is_alive:
					# Player is alive, set target for homing
					if bullet.has_method("set_target"):
						bullet.set_target(player.global_position)
				else:
					# Player is dead or doesn't exist, set direction straight down
					if bullet.has_method("set_direction"):
						bullet.set_direction(Vector2.DOWN)
				_add_bullet_to_scene(bullet)

func _pattern_p2_converging_storm() -> void:
	# Load the hell pattern scene directly for Phase 2
	var hell_pattern_scene = preload("res://Bullet/Boss_bullet/hell_pattern.tscn")
	if not hell_pattern_scene or not hell_pattern_scene.can_instantiate():
		# Fallback to regular bullet pattern if hell pattern not available
		_fallback_p2_pattern()
		print("falling abck to p2")
		return
	
	# Use HellPatternBullet for Phase 2 (360-degree pattern, no homing)
	var bullet_count = 16  # Number of bullets in the 360-degree pattern
	var speed_variation = 600.0  # Base speed for HellPatternBullet
	
	for i in range(bullet_count):
		var bullet = hell_pattern_scene.instantiate()
		if bullet:
			# Spawn all bullets from the nozzle position
			var start_pos = nozzel.global_position
			
			# Set direction to go outward in 360 degrees (no homing)
			var angle = (i * 2.0 * PI / bullet_count)
			var direction = Vector2(cos(angle), sin(angle))
			
			# Configure HellPatternBullet
			bullet.global_position = start_pos
			bullet.global_rotation = direction.angle()
			if bullet.has_method("set_direction"):
				bullet.set_direction(direction)
			if bullet.has_method("set_speed"):
				bullet.set_speed(speed_variation + randf_range(-50, 50))  # Slight speed variation
			if bullet.has_method("set_lifetime"):
				bullet.set_lifetime(5.0)
			if bullet.has_method("set_damage"):
				bullet.set_damage(2)  # Set damage for phase 2
			_add_bullet_to_scene(bullet)

# Fallback pattern for Phase 2 when HellPatternBullet is not available
func _fallback_p2_pattern() -> void:
	var bullet_count = 16
	var speed_variation = 600.0
	
	for i in range(bullet_count):
		var bullet = _create_bullet()
		if bullet:
			# Spawn all bullets from the nozzle position
			var start_pos = nozzel.global_position
			
			# Set direction to go outward in 360 degrees (no homing)
			var angle = (i * 2.0 * PI / bullet_count)
			var direction = Vector2(cos(angle), sin(angle))
			
			# Configure bullet
			bullet.global_position = start_pos
			bullet.global_rotation = direction.angle()
			if bullet.has_method("set_direction"):
				bullet.set_direction(direction)
			else:
				# Fallback for other bullet types
				bullet.direction = direction
			if bullet.has_method("set_speed"):
				bullet.set_speed(speed_variation + randf_range(-50, 50))
			_add_bullet_to_scene(bullet)

func _add_bullet_to_scene(bullet: Node) -> void:
	if not bullet:
		return
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(bullet)
	else:
		get_parent().add_child(bullet)
	
	if bullet.has_method("set_lifetime"):
		bullet.set_lifetime(6.0)
	
	bullet.add_to_group("bullets")

func take_damage(damage_amount: int) -> void:
	if current_health <= 0 or is_invincible:
		if is_invincible:
			print("Boss is invincible, ignoring damage: %d" % damage_amount)
		return
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0:
		_die()

func _die() -> void:
	print("Boss defeated!")
	
	attack_timer.stop()
	
	if boss_death_particles:
		boss_death_particles.emitting = true
	
	if boss_death:
		boss_death.play()
	
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
	
	emit_signal("boss_defeated")
	if current_phase == BossPhase.PHASE_2:
		emit_signal("unlock_shadow_mode")
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _create_bullet() -> Node:
	if not projectile_scene or not projectile_scene.can_instantiate():
		return null
	
	var bullet = projectile_scene.instantiate()
	
	if bullet.has_method("set_damage"):
		var damage = 1
		if current_phase == BossPhase.PHASE_2:
			damage = 2
		bullet.set_damage(damage)
	
	return bullet

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_bullets"):
		var damage = 1
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		take_damage(damage)
		area.queue_free()

func set_invincible(invincible: bool) -> void:
	is_invincible = invincible
	print("Boss invincibility set to: %s" % invincible)
