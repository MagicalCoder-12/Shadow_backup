extends Area2D

signal boss_defeated
signal phase_changed
signal descent_completed

enum BossPhase { INTRO, PHASE1, PHASE2, ENRAGED }

# Boss stats for Boss 3 (Virgo)
@export var max_health: int = 30000 # Stage 1
@export var stage_2_max_health: int = 60000 # Stage 2
@export var stage_1_sprite: Texture2D = preload("res://Textures/Boss/oldBossGFX/oldVIRGO2.png")
@export var stage_2_sprite: Texture2D = preload("res://Textures/Boss/oldBossGFX/oldVIRGO12.png")
@export var projectile_scene: PackedScene = preload("res://Bullet/Boss_bullet/homing_bullet.tscn")
@export var tractor_beam_scene: PackedScene = preload("res://Bullet/Boss_bullet/TractorBeam.tscn")
@export var hell_pattern_scene: PackedScene = preload("res://Bullet/Boss_bullet/hell_pattern.tscn")
@export var move_speed: float = 250.0
@export var move_range: float = 400.0
@export var vertical_movement_range: float = 300.0
@export var attack_interval: float = 4.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.3
@export var dash_interval: float = 6.0
@export var tractor_beam_duration: float = 2.0
@export var invincibility_duration: float = 3.0
@export var bullet_lifetime: float = 3.0
@export var bullet_speed: float = 350.0 # Reduced from 400.0

# Minion system properties
@export var minion_scene: PackedScene = preload("res://Enemy/minion.tscn")
@export var max_minions: int = 6
@export var minion_spawn_interval: float = 8.0
@export var minion_spawn_distance: float = 200.0
@export var phase2_minion_boost: int = 2 # Extra minions in phase 2
@export var enraged_minion_boost: int = 3 # Extra minions in enraged phase

# Enhanced movement properties
@export var min_y_position: float = 150.0
@export var max_y_position: float = 400.0
@export var movement_pattern_change_interval: float = 8.0

# Node references
@onready var marker_2d: Marker2D = $Boss/Marker2D
@onready var left: Marker2D = $Boss/Left
@onready var right: Marker2D = $Boss/Right
@onready var center: Marker2D = $Boss/Center
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var phase_timer: Timer = $PhaseTimer
@onready var minion_spawn_timer: Timer = $MinionSpawnTimer
@onready var movement_pattern_timer: Timer
@onready var boss_death: AudioStreamPlayer = $BossDeath
@onready var phase_change: AudioStreamPlayer2D = $PhaseChange
@onready var boss_death_particles: CPUParticles2D = $BossDeathParticles
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var sprite_2d: Sprite2D = $Boss

# Add boss music player as a variable since it's created dynamically
var boss_music: AudioStreamPlayer

# State variables
var current_health: int
var current_phase: BossPhase = BossPhase.INTRO
var move_direction: float = 0.0
var last_position: Vector2
var defeated: bool = false
var is_invincible: bool = false
var dash_cooldown: float = 0.0
var effects_layer: Node
var shadow_mode_active: bool = false
var tractor_beam_active: bool = false
var tractor_beam: Node

# Movement pattern system
enum MovementPattern { HORIZONTAL_SWING, VERTICAL_SWING, CIRCULAR, RANDOM_WALK, DIAGONAL_SWING }
var current_movement_pattern: MovementPattern = MovementPattern.HORIZONTAL_SWING
var movement_pattern_timer_value: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var movement_speed_multiplier: float = 1.0

# Minion management
var active_minions: Array[Node] = []
var minion_spawn_positions: Array[Vector2] = []
var minions_spawned_this_phase: int = 0

func _ready() -> void:
	# Add boss to group
	add_to_group("Boss")
	
	# Create boss music player dynamically
	boss_music = AudioStreamPlayer.new()
	boss_music.name = "BossMusic"
	boss_music.bus = "Boss"
	add_child(boss_music)
	
	# Validate properties
	if max_health <= 0:
		print("Warning: max_health is non-positive. Setting to 30000.")
		max_health = 30000
	if stage_2_max_health <= 0:
		print("Warning: stage_2_max_health is non-positive. Setting to 60000.")
		stage_2_max_health = 60000
	if attack_interval <= 0:
		print("Warning: attack_interval is non-positive. Setting to 4.0.")
		attack_interval = 4.0
	if move_speed <= 0:
		print("Warning: move_speed is non-positive. Setting to 250.0.")
		move_speed = 250.0
	if move_range <= 0:
		print("Warning: move_range is non-positive. Setting to 400.0.")
		move_range = 400.0
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Invalid projectile_scene.")
	if not minion_scene or not minion_scene.can_instantiate():
		print("Error: Invalid minion_scene.")
	if not sprite_2d:
		print("Error: Sprite2D node not found.")
	if not health_bar:
		print("Error: HealthBar node not found.")
	if not boss_death_particles:
		print("Error: BossDeathParticles node not found.")
	if not boss_death:
		print("Error: BossDeath AudioStreamPlayer not found.")
	if not phase_change:
		print("Error: PhaseChange AudioStreamPlayer2D not found.")
	if bullet_speed <= 0:
		print("Warning: bullet_speed is non-positive. Setting to 350.0.")
		bullet_speed = 350.0

	# Ensure audio nodes continue playing during pause
	if boss_death:
		boss_death.process_mode = PROCESS_MODE_ALWAYS
	if phase_change:
		phase_change.process_mode = PROCESS_MODE_ALWAYS
	if boss_music:
		boss_music.process_mode = PROCESS_MODE_ALWAYS

	# Initialize boss stats
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = max_health
	sprite_2d.texture = stage_1_sprite

	attack_timer.wait_time = attack_interval
	attack_timer.start()
	last_position = global_position
	effects_layer = get_tree().current_scene.get_node_or_null("Effects")


	# Initialize minion system
	_setup_minion_spawn_timer()
	_initialize_minion_spawn_positions()

	# Initialize movement system
	movement_pattern_timer = Timer.new()
	movement_pattern_timer.wait_time = movement_pattern_change_interval
	movement_pattern_timer.autostart = true
	movement_pattern_timer.timeout.connect(_on_movement_pattern_timeout)
	add_child(movement_pattern_timer)

	# Connect signals
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)

	start_movement()
	# Play boss music when boss is ready
	_play_boss_music()
	
	# Tween for INTRO animation (scale from 0 to 1)
	sprite_2d.scale = Vector2(0.0, 0.0)
	var tween = create_tween()
	tween.tween_property(sprite_2d, "scale", Vector2(1.5, 1.5), 2.0).set_trans(Tween.TRANS_ELASTIC)
	phase_timer.start(2.0) # Transition to PHASE1 after intro

func fire_tractor_beam() -> void:
	if tractor_beam_active:
		return
	tractor_beam_active = true
	if not tractor_beam_scene or not tractor_beam_scene.can_instantiate():
		print("Error: TractorBeam scene invalid")
		tractor_beam_active = false
		return
	var beam = tractor_beam_scene.instantiate()
	beam.global_position = center.global_position
	beam.rotation = PI / 2
	get_tree().current_scene.add_child(beam)
	# Store reference to the beam for updating
	tractor_beam = beam
	get_tree().create_timer(tractor_beam_duration).timeout.connect(func():
		if beam and is_instance_valid(beam):
			beam.queue_free()
		tractor_beam_active = false
	)

func update_tractor_beam() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and tractor_beam:
		# Update beam position to follow player
		tractor_beam.global_position = player.global_position
		var pull_strength = 200.0 if shadow_mode_active else 100.0
		var direction = (global_position - player.global_position).normalized()
		player.global_position += direction * pull_strength * get_process_delta_time()
		
		# Add damage over time while tractor beam is active
		# Damage the player periodically while in the tractor beam
		if randf() < 0.1:
			player.call("damage", 1)

# New helper function for hell storm pattern (inspired by ShadowUnlockBoss for improved behavior)
func fire_hell_storm(bullet_count: int = 24) -> void:
	if not hell_pattern_scene or not hell_pattern_scene.can_instantiate():
		print("Error: HellPatternBullet scene invalid")
		return
	var speed_variation = 800.0
	for i in range(bullet_count):
		var bullet = hell_pattern_scene.instantiate()
		if bullet:
			bullet.global_position = center.global_position
			var angle = (i * 2.0 * PI / bullet_count) + randf_range(-0.1, 0.1)
			var direction = Vector2(cos(angle), sin(angle))
			if bullet.has_method("set_direction"):
				bullet.set_direction(direction)
			if bullet.has_method("set_speed"):
				bullet.set_speed(speed_variation + randf_range(-100, 100))
			if bullet.has_method("set_lifetime"):
				bullet.set_lifetime(6.0)
			if bullet.has_method("set_damage"):
				bullet.set_damage(2)
			get_tree().current_scene.add_child(bullet)
		await get_tree().create_timer(0.05).timeout

func _setup_minion_spawn_timer() -> void:
	if not minion_spawn_timer:
		minion_spawn_timer = Timer.new()
		add_child(minion_spawn_timer)
		minion_spawn_timer.timeout.connect(_on_minion_spawn_timer_timeout)
	minion_spawn_timer.wait_time = minion_spawn_interval
	minion_spawn_timer.start()

func _initialize_minion_spawn_positions() -> void:
	# Define spawn positions around the boss
	var spawn_angles = [0, PI/3, 2*PI/3, PI, 4*PI/3, 5*PI/3]
	for angle in spawn_angles:
		var pos = Vector2(cos(angle), sin(angle)) * minion_spawn_distance
		minion_spawn_positions.append(pos)

func start_movement() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_x: float = viewport_size.x / 2
	# Spawn above screen bounds
	global_position = Vector2(center_x, -200)
	
	# Tween to visible position
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", min_y_position + 50, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Emit signal when descent is complete
	tween.tween_callback(func(): descent_completed.emit())

func _physics_process(delta: float) -> void:
	if defeated:
		return
	var phase_speed_multiplier = 1.0
	if current_phase == BossPhase.PHASE2:
		phase_speed_multiplier = 1.3
	elif current_phase == BossPhase.ENRAGED:
		phase_speed_multiplier = 1.6
	var shadow_speed_multiplier = 1.5 if shadow_mode_active else 1.0
	movement_speed_multiplier = phase_speed_multiplier * shadow_speed_multiplier
	
	# Update timers
	dash_cooldown -= delta
	movement_pattern_timer_value += delta
	
	# Execute current movement pattern
	execute_movement_pattern(delta)

	if dash_cooldown <= 0.0 and randf() < 0.1 * delta and current_phase != BossPhase.INTRO:
		perform_dash()

	if tractor_beam_active:
		update_tractor_beam()

	# Update minion management
	_update_minion_management()

func execute_movement_pattern(delta: float) -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var center_x = viewport_rect.size.x / 2
	var center_y = (min_y_position + max_y_position) / 2
	var half_width = move_range / 2
	var half_height = vertical_movement_range / 2
	
	match current_movement_pattern:
		MovementPattern.HORIZONTAL_SWING:
			# Horizontal sine wave movement
			var t = Time.get_ticks_msec() / 1000.0
			var offset_x = sin(t * 2.0) * half_width
			var constrained_y = clamp(global_position.y, min_y_position, max_y_position)
			target_position = Vector2(center_x + offset_x, constrained_y)
			
		MovementPattern.VERTICAL_SWING:
			# Vertical sine wave movement
			var t = Time.get_ticks_msec() / 1000.0
			var offset_y = sin(t * 2.0) * half_height
			var constrained_y = clamp(center_y + offset_y, min_y_position, max_y_position)
			target_position = Vector2(center_x, constrained_y)
			
		MovementPattern.CIRCULAR:
			# Circular movement around center
			var t = Time.get_ticks_msec() / 1000.0
			var radius = min(half_width, half_height) * 0.8
			var angle = t * 1.5
			var circle_x = center_x + cos(angle) * radius
			var circle_y = center_y + sin(angle) * radius
			circle_y = clamp(circle_y, min_y_position, max_y_position)
			target_position = Vector2(circle_x, circle_y)
			
		MovementPattern.RANDOM_WALK:
			# Random walk within bounds
			if movement_pattern_timer_value > 1.0:
				var random_x = center_x + randf_range(-half_width, half_width)
				var random_y = randf_range(min_y_position, max_y_position)
				target_position = Vector2(random_x, random_y)
				movement_pattern_timer_value = 0.0
			
		MovementPattern.DIAGONAL_SWING:
			# Diagonal sweeping movement
			var t = Time.get_ticks_msec() / 1000.0
			var offset = sin(t * 1.5) * half_width
			var y_offset = cos(t * 1.5) * half_height
			var constrained_y = clamp(center_y + y_offset, min_y_position, max_y_position)
			target_position = Vector2(center_x + offset, constrained_y)
	
	# Smoothly move towards target position
	var direction = (target_position - global_position).normalized()
	var speed = move_speed * movement_speed_multiplier
	global_position += direction * speed * delta
	
	# Keep boss within screen bounds
	global_position.x = clamp(global_position.x, 100, viewport_rect.size.x - 100)
	global_position.y = clamp(global_position.y, min_y_position, max_y_position)
	
	# Update move direction for animations
	var current_position = global_position
	move_direction = 1.0 if current_position.x > last_position.x else -1.0 if current_position.x < last_position.x else 0.0
	last_position = current_position

func _update_minion_management() -> void:
	# Clean up dead minions
	active_minions = active_minions.filter(func(minion): return is_instance_valid(minion) and minion.is_alive)
	
	# Update minion references
	for minion in active_minions:
		if minion.has_method("set_boss_reference"):
			minion.set_boss_reference(self)

func perform_dash() -> void:
	if defeated:
		return
	dash_cooldown = dash_interval * (0.7 if current_phase == BossPhase.ENRAGED else 1.0)
	var dash_direction = 1.0 if randi() % 2 == 0 else -1.0
	var target_x = global_position.x + dash_direction * move_range * 0.5
	var tween = create_tween()
	tween.tween_property(self, "global_position:x", target_x, dash_duration).set_trans(Tween.TRANS_QUAD)
	await tween.finished

func take_damage(amount: int) -> void:
	if defeated or is_invincible or amount <= 0:
		return

	current_health -= amount
	health_bar.value = current_health

	# Phase transition logic (missing in original code)
	if current_phase == BossPhase.PHASE1 and current_health <= max_health * 0.3:
		is_invincible = true
		phase_change.play()
		await phase_change.finished
		enter_phase(BossPhase.PHASE2)
		await get_tree().create_timer(invincibility_duration).timeout
		is_invincible = false
	elif current_phase == BossPhase.PHASE2 and current_health <= stage_2_max_health * 0.3:
		is_invincible = true
		phase_change.play()
		await phase_change.finished
		enter_phase(BossPhase.ENRAGED)
		await get_tree().create_timer(invincibility_duration).timeout
		is_invincible = false

	if current_health <= 0 and current_phase != BossPhase.PHASE1:
		defeated = true
		attack_timer.stop()
		phase_timer.stop()
		minion_spawn_timer.stop()
		movement_pattern_timer.stop()
		boss_death_particles.emitting = true
		boss_death.play()
		
		if boss_music and boss_music.playing:
			boss_music.stop()
		
		_destroy_all_minions()
		
		var particle_lifetime = boss_death_particles.lifetime if boss_death_particles else 1.0
		await get_tree().create_timer(particle_lifetime).timeout
		if boss_death:
			await boss_death.finished
		boss_defeated.emit()
		queue_free()

func _play_boss_music() -> void:
	# Play boss music
	var boss_music_stream = preload("res://Textures/Music/Boss_music.mp3")
	if boss_music_stream:
		boss_music.stream = boss_music_stream
		boss_music.play()
		print("Boss music started")
	else:
		print("Error: Boss music file not found")

func enter_phase(phase: BossPhase) -> void:
	current_phase = phase
	phase_changed.emit(phase)
	
	var phase_multiplier = 1.0
	match phase:
		BossPhase.PHASE1:
			health_bar.max_value = max_health
			health_bar.value = current_health
			sprite_2d.texture = stage_1_sprite

			attack_timer.wait_time = attack_interval
			phase_multiplier = 1.0
		BossPhase.PHASE2:
			current_health = stage_2_max_health
			health_bar.max_value = stage_2_max_health
			health_bar.value = current_health
			sprite_2d.texture = stage_2_sprite
			attack_timer.wait_time = attack_interval * 0.7
			phase_multiplier = 1.2
			spawn_phase_transition_effect()
			# Spawn initial minions for phase 2
			_spawn_phase_minions()
		BossPhase.ENRAGED:
			attack_timer.wait_time = attack_interval * 0.5
			phase_multiplier = 1.5
			spawn_phase_transition_effect()
			# Spawn additional minions for enraged phase
			_spawn_phase_minions()
	
	# Make boss invincible for 5 seconds after phase change
	is_invincible = true
	print("Boss is now invincible for 5 seconds after phase change")
	await get_tree().create_timer(5.0).timeout
	is_invincible = false
	print("Boss invincibility ended")
	
	# Adjust minion spawn rate based on phase
	_adjust_minion_spawn_rate()
	
	# Tween for phase transition (pulse effect)
	var tween = create_tween()
	tween.tween_property(sprite_2d, "scale", sprite_2d.scale * 1.2, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite_2d, "scale", sprite_2d.scale, 0.3).set_trans(Tween.TRANS_SINE)
	attack_timer.start(attack_interval * phase_multiplier * (0.7 if shadow_mode_active else 1.0))
	print("Entered phase: %s" % BossPhase.keys()[phase])

func _adjust_minion_spawn_rate() -> void:
	var spawn_rate_multiplier = 1.0
	match current_phase:
		BossPhase.PHASE1:
			spawn_rate_multiplier = 1.0
		BossPhase.PHASE2:
			spawn_rate_multiplier = 0.8
		BossPhase.ENRAGED:
			spawn_rate_multiplier = 0.6
	
	if shadow_mode_active:
		spawn_rate_multiplier *= 0.7
	
	minion_spawn_timer.wait_time = minion_spawn_interval * spawn_rate_multiplier

func _spawn_phase_minions() -> void:
	var minions_to_spawn = 2
	if current_phase == BossPhase.PHASE2:
		minions_to_spawn += phase2_minion_boost
	elif current_phase == BossPhase.ENRAGED:
		minions_to_spawn += enraged_minion_boost
	
	for i in range(minions_to_spawn):
		if active_minions.size() < get_max_minions():
			_spawn_minion()
			await get_tree().create_timer(0.5).timeout # Stagger spawns

func get_max_minions() -> int:
	var base_max = max_minions
	if current_phase == BossPhase.PHASE2:
		base_max += phase2_minion_boost
	elif current_phase == BossPhase.ENRAGED:
		base_max += enraged_minion_boost
	return base_max

func spawn_phase_transition_effect() -> void:
	var effect_scene = preload("res://Bosses/phase_transition_effect.tscn")
	if effect_scene and effect_scene.can_instantiate():
		var effect = effect_scene.instantiate()
		effect.global_position = global_position
		if effects_layer:
			effects_layer.call_deferred("add_child", effect)
		else:
			get_tree().current_scene.call_deferred("add_child", effect)
	else:
		print("Warning: phase_transition_effect.tscn not found or invalid")

func _spawn_minion() -> void:
	if not minion_scene or not minion_scene.can_instantiate():
		print("Error: Cannot spawn minion, minion_scene invalid")
		return
	
	if active_minions.size() >= get_max_minions():
		print("Max minions reached, cannot spawn more")
		return
	
	var minion = minion_scene.instantiate()
	if not minion:
		print("Error: Failed to instantiate minion")
		return
	
	# Set spawn position
	var spawn_pos = global_position + minion_spawn_positions[randi() % minion_spawn_positions.size()]
	minion.global_position = spawn_pos
	
	# Set minion properties based on phase
	var movement_type = _get_minion_movement_type()
	if minion.has_method("set_movement_type"):
		minion.set_movement_type(movement_type)
	
	if minion.has_method("set_boss_reference"):
		minion.set_boss_reference(self)
	
	# Connect minion death signal
	if minion.has_signal("boss_minion_died"):
		minion.boss_minion_died.connect(_on_minion_died)
	
	# Add to scene
	get_tree().current_scene.call_deferred("add_child", minion)
	active_minions.append(minion)
	
	# Use MovementType enum keys for logging
	var movement_type_name = "Unknown"
	if minion.has_method("get_movement_type"):
		var type_idx = minion.get_movement_type()
		var movement_types = ["SWARM", "ORBIT", "KAMIKAZE", "GUARD"]
		if type_idx >= 0 and type_idx < movement_types.size():
			movement_type_name = movement_types[type_idx]
	print("Spawned minion at position: %s, Type: %s" % [spawn_pos, movement_type_name])

func _get_minion_movement_type() -> int:
	# Define movement types based on phase and randomness
	match current_phase:
		BossPhase.PHASE1:
			return randi() % 2 # SWARM or ORBIT
		BossPhase.PHASE2:
			return randi() % 3 # SWARM, ORBIT, or GUARD
		BossPhase.ENRAGED:
			var weights = [0.3, 0.2, 0.3, 0.2] # SWARM, ORBIT, KAMIKAZE, GUARD
			return rand_weighted(weights)
	return 0 # Default to SWARM

func _on_minion_spawn_timer_timeout() -> void:
	if defeated or current_phase == BossPhase.INTRO:
		return
	
	if active_minions.size() < get_max_minions():
		_spawn_minion()

func _on_minion_died(minion: Node = null) -> void:
	if minion and minion in active_minions:
		active_minions.erase(minion)
	print("Minion died, active count: %d" % active_minions.size())

func _destroy_all_minions() -> void:
	for minion in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()
	active_minions.clear()
	print("All minions destroyed")

func on_minion_died(minion: Node) -> void:
	_on_minion_died(minion)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_bullets"):
		var damage = 1
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		take_damage(damage)
		area.queue_free()
	if defeated:
		return
	if area.is_in_group("Player"):
		# Check if player is in grace period after revival
		if area.has_method("is_just_revived") and area.is_just_revived():
			return
		area.call("damage", 1)

func _on_attack_timer_timeout() -> void:
	if defeated:
		return
	
	# Adjust attack weights based on phase for more variety
	var attack_weights = []
	match current_phase:
		BossPhase.PHASE1:
			# In phase 1: balanced attacks
			attack_weights = [0.2, 0.2, 0.15, 0.25, 0.2]
		BossPhase.PHASE2:
			# In phase 2: more aggressive attacks
			attack_weights = [0.15, 0.2, 0.1, 0.3, 0.25]
		BossPhase.ENRAGED:
			# In enraged phase: focus on tractor beam and minions
			attack_weights = [0.1, 0.15, 0.05, 0.4, 0.3]
		_:
			attack_weights = [0.2, 0.2, 0.15, 0.25, 0.2]
	
	var attack = [0, 1, 2, 3, 4][rand_weighted(attack_weights)]
	match attack:
		0:
			fire_spread_shot()
		1:
			fire_homing_missiles()
		2:
			fire_laser_burst()
		3:
			fire_tractor_beam()
		4:
			command_minions()
	
	var phase_multiplier = 1.0
	match current_phase:
		BossPhase.PHASE2:
			phase_multiplier = 0.7
		BossPhase.ENRAGED:
			phase_multiplier = 0.5
			
	var shadow_multiplier = 1.0
	if shadow_mode_active:
		shadow_multiplier = 0.7
		
	attack_timer.start(attack_interval * phase_multiplier * shadow_multiplier)

func command_minions() -> void:
	if active_minions.size() == 0:
		return
	
	# Give commands to minions
	var command_type = randi() % 3
	match command_type:
		0: # Make some minions kamikaze
			var kamikaze_count = min(2, active_minions.size())
			for i in range(kamikaze_count):
				var minion = active_minions[randi() % active_minions.size()]
				if minion.has_method("activate_kamikaze"):
					minion.activate_kamikaze()
		1: # Change movement patterns
			for minion in active_minions:
				if minion.has_method("set_movement_type"):
					minion.set_movement_type(_get_minion_movement_type())
		2: # Boost minion aggression by dealing damage
			for minion in active_minions:
				if minion.has_method("damage"):
					minion.damage(1) # Triggers speed and fire rate boost in minion.gd
	
	print("Commanded minions - Type: %d, Count: %d" % [command_type, active_minions.size()])

func rand_weighted(weights: Array) -> int:
	var total = 0.0
	for w in weights:
		total += w
	var r = randf() * total
	var sum = 0.0
	for i in range(weights.size()):
		sum += weights[i]
		if r <= sum:
			return i
	return weights.size() - 1

func fire_spread_shot() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid")
		return
	
	# Reduced bullet count and spread
	var bullet_count = 6 if current_phase == BossPhase.ENRAGED else 5
	var angle_offset = deg_to_rad(15.0) # Reduced from 20.0
	var base_angle = PI / 2
	var speed_multiplier = 1.2 if current_phase == BossPhase.ENRAGED else 1.0 # Reduced from 1.5/1.2
	
	for marker in [left, center, right]:
		for i in range(bullet_count):
			var bullet = projectile_scene.instantiate()
			if bullet:
				bullet.global_position = marker.global_position
				var angle = base_angle + angle_offset * (i - bullet_count / 2.0 + randf_range(-0.2, 0.2))
				bullet.rotation = angle
				bullet.velocity = Vector2(cos(angle), sin(angle)) * bullet_speed * speed_multiplier
				bullet.damage = 1
				get_tree().current_scene.call_deferred("add_child", bullet)
				var bullet_ref = weakref(bullet)
				get_tree().create_timer(bullet_lifetime).timeout.connect(func():
					var b = bullet_ref.get_ref()
					if b and is_instance_valid(b):
						b.queue_free()
				)
				print("Spawned spread shot bullet from %s" % marker.name)
			else:
				print("Error: Failed to instantiate bullet for spread shot")

func fire_homing_missiles() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid")
		return
	
	# Reduced missile count
	var bullet_count = 4 if current_phase == BossPhase.ENRAGED else 3 if current_phase == BossPhase.PHASE2 else 2
	var player = get_tree().get_first_node_in_group("Player")
	# Check if player exists and is alive
	var target_pos = player.global_position if (player and "is_alive" in player and player.is_alive) else global_position + Vector2(0, 1000)
	var speed_multiplier = 1.2 if current_phase == BossPhase.ENRAGED else 1.0 # Reduced from 1.5/1.2
	
	for marker in [left, right]:
		for i in range(bullet_count):
			var bullet = projectile_scene.instantiate()
			if bullet:
				bullet.global_position = marker.global_position
				var angle = randf_range(-PI / 6, PI / 6) # Reduced spread
				bullet.rotation = angle
				bullet.velocity = Vector2(cos(angle), sin(angle)) * bullet_speed * speed_multiplier
				if bullet.has_method("set_target"):
					bullet.set_target(target_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
					bullet.turn_rate = 0.05 if current_phase == BossPhase.ENRAGED else 0.04 # Reduced turning
				bullet.damage = 1
				get_tree().current_scene.call_deferred("add_child", bullet)
				var bullet_ref = weakref(bullet)
				get_tree().create_timer(bullet_lifetime).timeout.connect(func():
					var b = bullet_ref.get_ref()
					if b and is_instance_valid(b):
						b.queue_free()
				)
				print("Spawned homing missile from %s" % marker.name)
			else:
				print("Error: Failed to instantiate bullet for homing missile")

func fire_laser_burst() -> void:
	if not projectile_scene or not projectile_scene.can_instantiate():
		print("Error: Cannot spawn bullets, projectile_scene invalid")
		return
	
	# Reduced burst count
	var burst_count = 3 if current_phase == BossPhase.ENRAGED else 2
	var speed_multiplier = 1.5 if current_phase == BossPhase.ENRAGED else 1.3 # Reduced from 2.0/1.8
	
	for burst in range(burst_count):
		for marker in [left, center, right]:
			var bullet = projectile_scene.instantiate()
			if bullet:
				bullet.global_position = marker.global_position
				var angle = PI / 2 + randf_range(-0.05, 0.05) # Reduced spread
				bullet.rotation = angle
				bullet.velocity = Vector2(cos(angle), sin(angle)) * bullet_speed * speed_multiplier
				bullet.damage = 1
				get_tree().current_scene.call_deferred("add_child", bullet)
				var bullet_ref = weakref(bullet)
				get_tree().create_timer(bullet_lifetime).timeout.connect(func():
					var b = bullet_ref.get_ref()
					if b and is_instance_valid(b):
						b.queue_free()
				)
				print("Spawned laser burst bullet from %s" % marker.name)
			else:
				print("Error: Failed to instantiate bullet for laser burst")
		await get_tree().create_timer(0.15 if current_phase == BossPhase.ENRAGED else 0.2).timeout # Increased delay

func fire_energy_ball() -> void:
	# Load the energy ball scene
	var energy_ball_scene = preload("res://Bullet/Boss_bullet/energy_ball.tscn")
	if not energy_ball_scene or not energy_ball_scene.can_instantiate():
		print("Error: Cannot spawn energy balls, energy_ball_scene invalid")
		return
	
	# Fire energy balls from all markers
	var markers = [left, center, right]
	var speed_multiplier = 1.2 if current_phase == BossPhase.ENRAGED else 1.0
	var damage_multiplier = 1
	if current_phase == BossPhase.ENRAGED:
		damage_multiplier = 2
	elif current_phase == BossPhase.PHASE2:
		damage_multiplier = 1.5
	
	for marker in markers:
		if not marker or not is_instance_valid(marker):
			continue
		var energy_ball = energy_ball_scene.instantiate()
		if energy_ball:
			energy_ball.global_position = marker.global_position
			# Set direction towards player
			var player = get_tree().get_first_node_in_group("Player")
			var target_pos = player.global_position if player else global_position + Vector2(0, 1000)
			var direction = (target_pos - marker.global_position).normalized()
			if energy_ball.has_method("set_direction"):
				energy_ball.set_direction(direction)
			if energy_ball.has_method("set_speed"):
				energy_ball.set_speed(200.0 * speed_multiplier)
			if energy_ball.has_method("set_damage"):
				energy_ball.set_damage(int(3 * damage_multiplier)) # Energy balls do more damage
			get_tree().current_scene.call_deferred("add_child", energy_ball)
			print("Spawned energy ball from %s" % marker.name)
		else:
			print("Error: Failed to instantiate energy ball")

func _on_shadow_mode_activated() -> void:
	shadow_mode_active = true
	attack_timer.wait_time = attack_timer.wait_time * 0.7
	attack_timer.start()
	
	# Boost minion spawning in shadow mode
	_adjust_minion_spawn_rate()
	
	# Make existing minions more aggressive
	for minion in active_minions:
		if minion.has_method("_make_shadow_enemy"):
			minion._make_shadow_enemy()

func _on_shadow_mode_deactivated() -> void:
	shadow_mode_active = false
	var phase_multiplier = 1.0
	if current_phase == BossPhase.PHASE2:
		phase_multiplier = 0.7
	elif current_phase == BossPhase.ENRAGED:
		phase_multiplier = 0.5
	attack_timer.wait_time = attack_interval * phase_multiplier
	attack_timer.start()
	
	# Adjust minion spawning back to normal
	_adjust_minion_spawn_rate()

func spawn_bullet_effect(spawn_position: Vector2, color: Color) -> void:
	# Create a small visual effect when bullets are fired
	var effect_scene = preload("res://Bosses/muzzle_flash.tscn")
	if effect_scene and effect_scene.can_instantiate():
		var effect = effect_scene.instantiate()
		effect.global_position = spawn_position
		if effect.has_method("set_color"):
			effect.set_color(color)
		if effects_layer:
			effects_layer.call_deferred("add_child", effect)
		else:
			get_tree().current_scene.call_deferred("add_child", effect)

func _on_movement_pattern_timeout() -> void:
	if defeated or current_phase == BossPhase.INTRO:
		return
	
	# Cycle through movement patterns
	current_movement_pattern = (current_movement_pattern + 1) as MovementPattern
	if current_movement_pattern >= MovementPattern.keys().size() as int:
		current_movement_pattern = 0 as MovementPattern
	movement_pattern_timer_value = 0.0
	print("Boss changed movement pattern to: %s" % MovementPattern.keys()[current_movement_pattern])

func _on_phase_timer_timeout() -> void:
	if current_phase == BossPhase.INTRO:
		enter_phase(BossPhase.PHASE1)
		print("Transitioned from INTRO to PHASE1")


# Public methods for minion interaction
func get_active_minion_count() -> int:
	return active_minions.size()

func get_minion_status() -> Array:
	var status = []
	for minion in active_minions:
		if minion.has_method("get_status"):
			status.append(minion.get_status())
	return status

func force_spawn_minion() -> void:
	if active_minions.size() < get_max_minions():
		_spawn_minion()

func set_invincible(invincible: bool) -> void:
	is_invincible = invincible
	print("Boss invincibility set to: %s" % invincible)
