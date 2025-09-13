extends Area2D
class_name ShadowUnlockBoss

## Simplified AI Boss with two-phase system + initial descent
## Phase 1: Simple spiral pattern
## Phase 2: Converging storm pattern

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
		_pattern_p1_spiral_wave()
	else:
		_pattern_p2_converging_storm()

func _show_muzzle_flash() -> void:
	var flash = MUZZLE_FLASH.instantiate()
	if flash:
		flash.global_position = nozzel.global_position
		get_tree().current_scene.add_child(flash)

func _pattern_p1_spiral_wave() -> void:
	var bullet_count = 8
	var spiral_arms = 2
	
	for arm in range(spiral_arms):
		@warning_ignore("integer_division")
		for i in range(bullet_count / spiral_arms):
			var bullet = _create_bullet()
			if bullet:
				var angle = (Time.get_ticks_msec() * 0.001 * 1.5) + (arm * PI) + (i * 0.4)
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = angle
				bullet.speed = 600 + (i * 8)
				_add_bullet_to_scene(bullet)

func _pattern_p2_converging_storm() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return  # Added null check for safety
	
	var beam_count = 16
	var target_pos = player.global_position
	
	for i in range(beam_count):
		var bullet = _create_bullet()
		if bullet:
			var start_angle = (i * 2.0 * PI / beam_count) + Time.get_ticks_msec() * 0.001 * 0.5
			var start_pos = nozzel.global_position + Vector2(cos(start_angle), sin(start_angle)) * 120
			var direction = (target_pos - start_pos).normalized()
			
			bullet.global_position = start_pos
			bullet.global_rotation = direction.angle()
			bullet.speed = 1200
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
	if current_health <= 0:
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
