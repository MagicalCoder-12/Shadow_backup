extends Area2D
class_name ShadowUnlockBoss

## Enhanced AI Boss with two-phase system and intelligent behavior
## Phase 1: Normal attacks with standard patterns
## Phase 2: Shadow mode at 50% health with intense bullet hell and sprite change

# Boss Phases
enum BossPhase {
	PHASE_1,    # Normal phase (100% - 50% health)
	PHASE_2,    # Shadow phase (50% - 0% health)
	TRANSITION  # Brief transition between phases
}

# Phase 1 Bullet Patterns - Normal difficulty
enum Phase1Pattern { 
	SPIRAL_WAVE,      # Classic spiral pattern
	PETAL_BURST,      # Flower-like burst pattern
	WAVE_FORMATION,   # Sine wave bullets
	SCATTER_BASIC     # Basic scattered shots
}

# Phase 2 Bullet Patterns - Intense difficulty
enum Phase2Pattern {
	CONVERGING_STORM,  # Multiple converging beams
	SHADOW_ORBIT,      # Complex orbital attacks
	CHAOS_BARRAGE,     # Rapid-fire chaos
	WALL_PRISON,       # Moving bullet walls
	SHADOW_CHASE,      # Advanced homing attacks
	SPIRAL_HELL        # Intense multi-spiral
}

# AI States for intelligent behavior
enum AIState {
	OBSERVING,        # Watching player, minimal attacks
	AGGRESSIVE,       # Heavy attack phase
	BERSERKER,        # Final desperate phase
	PATTERN_SHIFT     # Transitioning between patterns
}

## Core Stats
@export var max_health: int = 8000
@export var phase_transition_health: int = 4000  # 50% health threshold
@export var base_attack_interval_p1: float = 2.5  # Phase 1 attack speed
@export var base_attack_interval_p2: float = 1.2  # Phase 2 attack speed (faster)
@export var projectile_scene: PackedScene
@export var move_speed: float = 150.0
@export var ai_reaction_time: float = 0.3

## AI Behavior Settings
@export var aggression_threshold: float = 0.7
@export var pattern_switch_cooldown_p1: float = 8.0  # Phase 1 pattern switching
@export var pattern_switch_cooldown_p2: float = 5.0  # Phase 2 pattern switching (faster)

## Visual Components - Different sprites for each phase
var normal_boss_sprite: Texture2D = preload("res://Textures/Boss/Boss_1_A_Large_NoLight.png")
var shadow_boss_sprite: Texture2D = preload("res://Textures/Boss/B1.png")
const MUZZLE_FLASH = preload("res://Bosses/muzzle_flash.tscn")
const PHASE_TRANSITION_EFFECT = preload("res://Bosses/phase_transition_effect.tscn")

## Node References
@onready var attack_timer: Timer = $AttackTimer
@onready var ai_timer: Timer = $AITimer
@onready var pattern_timer: Timer = $PatternTimer
@onready var nozzel: Node2D = $Sprite2D/Nozzel
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var boss_death_particles: CPUParticles2D = $BossDeathParticles
@onready var boss_death: AudioStreamPlayer = $BossDeath
@onready var phase_change: AudioStreamPlayer2D = $PhaseChange

## Signals
signal boss_defeated
signal unlock_shadow_mode
@warning_ignore("unused_signal")
signal pattern_changed(new_pattern)
@warning_ignore("unused_signal")
signal phase_changed(new_phase: BossPhase)

## Phase System
var current_phase: BossPhase = BossPhase.PHASE_1
var phase_transition_complete: bool = false

## AI State Variables
var current_health: int
var ai_state: AIState = AIState.OBSERVING
var current_p1_pattern: Phase1Pattern = Phase1Pattern.SPIRAL_WAVE
var current_p2_pattern: Phase2Pattern = Phase2Pattern.CONVERGING_STORM
var player_reference: Node = null
var last_player_position: Vector2
var player_velocity: Vector2
var predicted_player_position: Vector2

## Movement AI
var target_position: Vector2
var movement_style: int = 0
var movement_timer: float = 0.0

## Pattern State
var pattern_time: float = 0.0
var bullet_wave_count: int = 0
var is_pattern_active: bool = false
var pattern_intensity: float = 1.0

## Combat Intelligence
var player_threat_level: float = 0.0
var damage_taken_recently: float = 0.0
var last_damage_time: float = 0.0

## Constants
const BULLET_LIFETIME: float = 6.0
const AI_UPDATE_INTERVAL: float = 0.1
const THREAT_DECAY_RATE: float = 0.5
const PHASE_TRANSITION_DURATION: float = 2.0

func _ready() -> void:
	_validate_setup()
	_initialize_boss()
	_setup_ai_system()
	_connect_signals()

func _validate_setup() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		push_error("Invalid projectile_scene! Please assign a valid bullet scene.")
	if not nozzel:
		push_error("Nozzel node missing! Required for bullet spawning.")
	if not normal_boss_sprite:
		push_error("Normal boss sprite missing!")
	if not shadow_boss_sprite:
		push_error("Shadow boss sprite missing!")

func _initialize_boss() -> void:
	current_health = max_health
	target_position = global_position
	current_phase = BossPhase.PHASE_1
	
	sprite_2d.texture = normal_boss_sprite
	
	health_bar.max_value = max_health
	health_bar.value = max_health
	
	add_to_group(GameManager.GROUP_BOSS)
	
	ai_state = AIState.OBSERVING
	pattern_intensity = 0.6

func _setup_ai_system() -> void:
	ai_timer.wait_time = AI_UPDATE_INTERVAL
	ai_timer.timeout.connect(_update_ai_state)
	ai_timer.start()
	
	pattern_timer.wait_time = pattern_switch_cooldown_p1
	pattern_timer.timeout.connect(_consider_pattern_change)
	pattern_timer.start()
	
	attack_timer.wait_time = base_attack_interval_p1
	attack_timer.timeout.connect(_execute_attack_pattern)
	attack_timer.start()

func _connect_signals() -> void:
	if not boss_defeated.is_connected(GameManager._on_boss_defeated):
		boss_defeated.connect(GameManager._on_boss_defeated)
	if not unlock_shadow_mode.is_connected(GameManager._on_unlock_shadow_mode):
		unlock_shadow_mode.connect(GameManager._on_unlock_shadow_mode)

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	
	_check_phase_transition()
	_track_player(delta)
	_update_movement_ai(delta)
	_update_threat_assessment(delta)
	_update_timers(delta)
	
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
	target_position = global_position
	
	attack_timer.stop()
	pattern_timer.stop()
	
	if phase_change:
		phase_change.play()
	
	_execute_phase_transition()

func _execute_phase_transition() -> void:
	animation_player.stop()
	var effect = PHASE_TRANSITION_EFFECT.instantiate()
	add_child(effect)
	effect.global_position = global_position
	sprite_2d.texture = shadow_boss_sprite
	sprite_2d.scale = Vector2(2.0, 2.0)
	
	await get_tree().create_timer(PHASE_TRANSITION_DURATION).timeout
	
	current_phase = BossPhase.PHASE_2
	phase_transition_complete = true
	
	attack_timer.wait_time = base_attack_interval_p2
	pattern_timer.wait_time = pattern_switch_cooldown_p2
	
	attack_timer.start()
	pattern_timer.start()
	
	pattern_intensity = 1.5
	
	print("Shadow Phase activated! Prepare for chaos!")
	emit_signal("phase_changed", BossPhase.PHASE_2)

func _track_player(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player_reference = player
		var new_position = player.global_position
		
		if last_player_position != Vector2.ZERO:
			player_velocity = (new_position - last_player_position) / delta
		
		var prediction_time = ai_reaction_time
		if current_phase == BossPhase.PHASE_2:
			prediction_time *= 1.5
		
		predicted_player_position = new_position + player_velocity * prediction_time
		last_player_position = new_position

func _update_movement_ai(delta: float) -> void:
	if current_phase == BossPhase.TRANSITION:
		return
	
	movement_timer += delta
	
	var speed_multiplier = 1.0
	if current_phase == BossPhase.PHASE_2:
		speed_multiplier = 1.3
	
	match ai_state:
		AIState.OBSERVING:
			_movement_observing(delta)
		AIState.AGGRESSIVE:
			_movement_aggressive(delta)
		AIState.BERSERKER:
			_movement_berserker(delta)
		AIState.PATTERN_SHIFT:
			_movement_pattern_shift(delta)
	
	var direction = (target_position - global_position).normalized()
	var current_speed = move_speed * _get_speed_multiplier() * speed_multiplier
	global_position += direction * current_speed * delta

func _movement_observing(_delta: float) -> void:
	var center = Vector2(get_viewport().size.x / 2, 200)
	var radius = 200
	
	if current_phase == BossPhase.PHASE_1:
		target_position = center + Vector2(
			cos(movement_timer * 0.5) * radius,
			sin(movement_timer * 0.8) * radius * 0.3
		)
	else:
		target_position = center + Vector2(
			cos(movement_timer * 1.2) * radius,
			sin(movement_timer * 1.5) * radius * 0.6
		)

func _movement_aggressive(_delta: float) -> void:
	if player_reference:
		var player_pos = player_reference.global_position
		var distance_to_player = global_position.distance_to(player_pos)
		
		var optimal_distance = 400
		if current_phase == BossPhase.PHASE_2:
			optimal_distance = 300
		
		if distance_to_player > optimal_distance:
			target_position = player_pos + (global_position - player_pos).normalized() * optimal_distance
		else:
			var strafe_speed = 2.0 if current_phase == BossPhase.PHASE_2 else 1.5
			var strafe_angle = movement_timer * strafe_speed
			target_position = player_pos + Vector2(cos(strafe_angle), sin(strafe_angle)) * optimal_distance

func _movement_berserker(_delta: float) -> void:
	var chaos_chance = 0.1 if current_phase == BossPhase.PHASE_1 else 0.2
	var chaos_range = 300 if current_phase == BossPhase.PHASE_1 else 400
	
	if randf() < chaos_chance:
		target_position = global_position + Vector2(
			randf_range(-chaos_range, chaos_range),
			randf_range(-100, 100)
		)

func _movement_pattern_shift(_delta: float) -> void:
	target_position = global_position

func _update_threat_assessment(delta: float) -> void:
	player_threat_level = max(0.0, player_threat_level - THREAT_DECAY_RATE * delta)
	damage_taken_recently = max(0.0, damage_taken_recently - 100.0 * delta)

func _update_timers(delta: float) -> void:
	pattern_time += delta

func _update_ai_state() -> void:
	if current_phase == BossPhase.TRANSITION:
		return
	
	var health_ratio = float(current_health) / float(max_health)
	var old_state = ai_state
	
	var aggression_thresh = aggression_threshold
	if current_phase == BossPhase.PHASE_2:
		aggression_thresh = 0.8
	
	if health_ratio <= 0.15:
		ai_state = AIState.BERSERKER
	elif health_ratio <= aggression_thresh or player_threat_level > 0.7:
		ai_state = AIState.AGGRESSIVE
	else:
		ai_state = AIState.OBSERVING
	
	var base_intensity = 0.8 if current_phase == BossPhase.PHASE_1 else 1.5
	match ai_state:
		AIState.OBSERVING:
			pattern_intensity = base_intensity * 0.7
		AIState.AGGRESSIVE:
			pattern_intensity = base_intensity * 1.0
		AIState.BERSERKER:
			pattern_intensity = base_intensity * 1.8
	
	var base_interval = base_attack_interval_p1 if current_phase == BossPhase.PHASE_1 else base_attack_interval_p2
	var new_interval = base_interval
	
	match ai_state:
		AIState.OBSERVING:
			new_interval = base_interval * 1.5
		AIState.AGGRESSIVE:
			new_interval = base_interval * 0.7
		AIState.BERSERKER:
			new_interval = base_interval * 0.4
	
	attack_timer.wait_time = new_interval
	
	if old_state != ai_state:
		print("AI State changed: %s -> %s (Phase %d)" % [AIState.keys()[old_state], AIState.keys()[ai_state], current_phase + 1])

func _consider_pattern_change() -> void:
	if current_phase == BossPhase.TRANSITION:
		return
	
	if ai_state == AIState.BERSERKER and randf() < 0.7:
		return
	
	if current_phase == BossPhase.PHASE_1:
		var available_patterns = _get_available_phase1_patterns()
		var new_pattern = available_patterns[randi() % available_patterns.size()]
		if new_pattern != current_p1_pattern:
			_change_phase1_pattern(new_pattern)
	else:
		var available_patterns = _get_available_phase2_patterns()
		var new_pattern = available_patterns[randi() % available_patterns.size()]
		if new_pattern != current_p2_pattern:
			_change_phase2_pattern(new_pattern)

func _get_available_phase1_patterns() -> Array:
	var patterns = []
	
	match ai_state:
		AIState.OBSERVING:
			patterns = [Phase1Pattern.SPIRAL_WAVE, Phase1Pattern.PETAL_BURST]
		AIState.AGGRESSIVE:
			patterns = [Phase1Pattern.WAVE_FORMATION, Phase1Pattern.SCATTER_BASIC]
		AIState.BERSERKER:
			patterns = Phase1Pattern.values()
	
	return patterns

func _get_available_phase2_patterns() -> Array:
	var patterns = []
	
	match ai_state:
		AIState.OBSERVING:
			patterns = [Phase2Pattern.CONVERGING_STORM, Phase2Pattern.SHADOW_ORBIT]
		AIState.AGGRESSIVE:
			patterns = [Phase2Pattern.CHAOS_BARRAGE, Phase2Pattern.WALL_PRISON, Phase2Pattern.SHADOW_CHASE]
		AIState.BERSERKER:
			patterns = Phase2Pattern.values()
	
	return patterns

func _change_phase1_pattern(new_pattern: Phase1Pattern) -> void:
	ai_state = AIState.PATTERN_SHIFT
	current_p1_pattern = new_pattern
	pattern_time = 0.0
	bullet_wave_count = 0
	
	print("Phase 1 pattern changed to: %s" % Phase1Pattern.keys()[new_pattern])
	emit_signal("pattern_changed", new_pattern)
	
	await get_tree().create_timer(0.5).timeout
	if ai_state == AIState.PATTERN_SHIFT:
		_update_ai_state()

func _change_phase2_pattern(new_pattern: Phase2Pattern) -> void:
	ai_state = AIState.PATTERN_SHIFT
	current_p2_pattern = new_pattern
	pattern_time = 0.0
	bullet_wave_count = 0
	
	print("Phase 2 pattern changed to: %s" % Phase2Pattern.keys()[new_pattern])
	emit_signal("pattern_changed", new_pattern)
	
	await get_tree().create_timer(0.3).timeout
	if ai_state == AIState.PATTERN_SHIFT:
		_update_ai_state()

func _execute_attack_pattern() -> void:
	if current_health <= 0 or current_phase == BossPhase.TRANSITION:
		return
	
	_show_muzzle_flash()
	
	if current_phase == BossPhase.PHASE_1:
		_execute_phase1_pattern()
	else:
		_execute_phase2_pattern()
	
	bullet_wave_count += 1

func _show_muzzle_flash() -> void:
	var flash = MUZZLE_FLASH.instantiate()
	if flash:
		flash.global_position = nozzel.global_position
		get_tree().current_scene.add_child(flash)

func _execute_phase1_pattern() -> void:
	match current_p1_pattern:
		Phase1Pattern.SPIRAL_WAVE:
			_pattern_p1_spiral_wave()
		Phase1Pattern.PETAL_BURST:
			_pattern_p1_petal_burst()
		Phase1Pattern.WAVE_FORMATION:
			_pattern_p1_wave_formation()
		Phase1Pattern.SCATTER_BASIC:
			_pattern_p1_scatter_basic()

func _execute_phase2_pattern() -> void:
	match current_p2_pattern:
		Phase2Pattern.CONVERGING_STORM:
			_pattern_p2_converging_storm()
		Phase2Pattern.SHADOW_ORBIT:
			_pattern_p2_shadow_orbit()
		Phase2Pattern.CHAOS_BARRAGE:
			_pattern_p2_chaos_barrage()
		Phase2Pattern.WALL_PRISON:
			_pattern_p2_wall_prison()
		Phase2Pattern.SHADOW_CHASE:
			_pattern_p2_shadow_chase()
		Phase2Pattern.SPIRAL_HELL:
			_pattern_p2_spiral_hell()

func _pattern_p1_spiral_wave() -> void:
	var bullet_count = int(8 * pattern_intensity)
	var spiral_arms = 2
	
	for arm in range(spiral_arms):
		@warning_ignore("integer_division")
		for i in range(bullet_count / spiral_arms):
			var bullet = _create_bullet()
			if bullet:
				var angle = (pattern_time * 1.5) + (arm * PI) + (i * 0.4)
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = angle
				bullet.speed = 600 + (i * 8)
				_add_bullet_to_scene(bullet)

func _pattern_p1_petal_burst() -> void:
	var petal_count = int(6 * pattern_intensity)
	var bullets_per_petal = 4
	
	for petal in range(petal_count):
		var base_angle = (petal * 2.0 * PI / petal_count) + (pattern_time * 0.3)
		for i in range(bullets_per_petal):
			var bullet = _create_bullet()
			if bullet:
				var angle_variation = sin(pattern_time * 2.0 + petal) * 0.2
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = base_angle + angle_variation
				bullet.speed = 700 + (i * 25)
				_add_bullet_to_scene(bullet)

func _pattern_p1_wave_formation() -> void:
	var bullet_count = int(8 * pattern_intensity)
	
	for i in range(bullet_count):
		var bullet = _create_bullet()
		if bullet:
			var base_angle = PI / 2
			var wave_offset = sin(pattern_time * 1.5 + i * 0.3) * 0.5
			bullet.global_position = nozzel.global_position + Vector2(i * 25 - bullet_count * 12, 0)
			bullet.global_rotation = base_angle + wave_offset
			bullet.speed = 900
			_add_bullet_to_scene(bullet)

func _pattern_p1_scatter_basic() -> void:
	var bullet_count = int(12 * pattern_intensity)
	
	for i in range(bullet_count):
		var bullet = _create_bullet()
		if bullet:
			var angle = (i * 2.0 * PI / bullet_count) + (pattern_time * 0.5)
			bullet.global_position = nozzel.global_position
			bullet.global_rotation = angle
			bullet.speed = randf_range(900, 1200)
			_add_bullet_to_scene(bullet)

func _pattern_p2_converging_storm() -> void:
	if not player_reference:
		return
	
	var beam_count = int(16 * pattern_intensity)
	var target_pos = predicted_player_position
	
	for i in range(beam_count):
		var bullet = _create_bullet()
		if bullet:
			var start_angle = (i * 2.0 * PI / beam_count) + pattern_time * 0.5
			var start_pos = nozzel.global_position + Vector2(cos(start_angle), sin(start_angle)) * 120
			var direction = (target_pos - start_pos).normalized()
			
			bullet.global_position = start_pos
			bullet.global_rotation = direction.angle()
			bullet.speed = 1200
			_add_bullet_to_scene(bullet)

func _pattern_p2_shadow_orbit() -> void:
	var orbit_layers = 3
	var bullets_per_layer = int(12 * pattern_intensity)
	
	for layer in range(orbit_layers):
		var orbit_radius = 100 + (layer * 80)
		var layer_speed = 2.0 + (layer * 0.5)
		
		for i in range(bullets_per_layer):
			var bullet = _create_bullet()
			if bullet:
				var angle = (i * 2.0 * PI / bullets_per_layer) + (pattern_time * layer_speed)
				var orbit_pos = nozzel.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
				
				bullet.global_position = orbit_pos
				bullet.global_rotation = angle + PI / 2
				bullet.speed = 850 + (layer * 20)
				_add_bullet_to_scene(bullet)

func _pattern_p2_chaos_barrage() -> void:
	var barrage_count = int(25 * pattern_intensity)
	
	for i in range(barrage_count):
		var bullet = _create_bullet()
		if bullet:
			var random_angle = randf() * 2.0 * PI
			var speed_variation = randf_range(150, 350)
			
			bullet.global_position = nozzel.global_position
			bullet.global_rotation = random_angle
			bullet.speed = speed_variation
			_add_bullet_to_scene(bullet)

func _pattern_p2_wall_prison() -> void:
	var wall_segments = 4
	var bullets_per_segment = int(8 * pattern_intensity)
	
	for segment in range(wall_segments):
		var wall_angle = (segment * PI / 2) + (pattern_time * 0.3)
		
		for i in range(bullets_per_segment):
			var bullet = _create_bullet()
			if bullet:
				@warning_ignore("integer_division")
				var offset = (i - bullets_per_segment / 2) * 40
				var start_pos = nozzel.global_position + Vector2(cos(wall_angle + PI/2), sin(wall_angle + PI/2)) * offset
				
				bullet.global_position = start_pos
				bullet.global_rotation = wall_angle
				bullet.speed = 980
				_add_bullet_to_scene(bullet)

func _pattern_p2_shadow_chase() -> void:
	if not player_reference:
		return
	
	var chase_count = int(12 * pattern_intensity)
	
	for i in range(chase_count):
		var bullet = _create_bullet()
		if bullet:
			var spawn_angle = (i * 2.0 * PI / chase_count) + pattern_time
			var spawn_pos = nozzel.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * 60
			
			bullet.global_position = spawn_pos
			bullet.speed = 920
			if bullet.has_method("set_target"):
				bullet.set_target(player_reference.global_position)
				bullet.turn_rate = 0.12
			_add_bullet_to_scene(bullet)

func _pattern_p2_spiral_hell() -> void:
	var spiral_count = 4
	var bullets_per_spiral = int(10 * pattern_intensity)
	
	for spiral in range(spiral_count):
		var spiral_direction = 1 if spiral % 2 == 0 else -1
		var spiral_offset = spiral * PI / 2
		
		for i in range(bullets_per_spiral):
			var bullet = _create_bullet()
			if bullet:
				var angle = (pattern_time * 3.0 * spiral_direction) + spiral_offset + (i * 0.2)
				bullet.global_position = nozzel.global_position
				bullet.global_rotation = angle
				bullet.speed = 700 + (i * 15)
				_add_bullet_to_scene(bullet)

func _get_speed_multiplier() -> float:
	var base_multiplier = 1.0
	
	if current_phase == BossPhase.PHASE_2:
		base_multiplier = 1.2
	
	match ai_state:
		AIState.OBSERVING:
			return base_multiplier * 0.7
		AIState.AGGRESSIVE:
			return base_multiplier * 1.0
		AIState.BERSERKER:
			return base_multiplier * 1.5
		AIState.PATTERN_SHIFT:
			return base_multiplier * 0.5
	
	return base_multiplier

func _add_bullet_to_scene(bullet: Node) -> void:
	if not bullet:
		return
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(bullet)
	else:
		get_parent().add_child(bullet)
	
	if bullet.has_method("set_lifetime"):
		bullet.set_lifetime(BULLET_LIFETIME)
	
	bullet.add_to_group("bullets")

func take_damage(damage_amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
	
	damage_taken_recently += damage_amount
	last_damage_time = Time.get_unix_time_from_system()
	
	player_threat_level = min(1.0, player_threat_level + 0.2)
	
	if current_health <= 0:
		_die()

func _die() -> void:
	print("Boss defeated!")
	
	attack_timer.stop()
	ai_timer.stop()
	pattern_timer.stop()
	
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
