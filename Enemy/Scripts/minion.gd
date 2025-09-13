extends Enemy
class_name BossMinion

# Boss minion specific signals
signal boss_minion_died

# Movement types for different minion behaviors
enum MovementType {
	SWARM,      # Move toward player in groups
	ORBIT,      # Orbit around boss
	KAMIKAZE,   # Direct assault on player
	GUARD       # Stay near boss and defend
}

# Boss minion properties
@export var movement_type: MovementType = MovementType.SWARM
@export var orbit_radius: float = 100.0
@export var orbit_speed: float = 2.0
@export var kamikaze_speed_multiplier: float = 2.0
@export var guard_distance: float = 150.0
@export var swarm_cohesion: float = 50.0
@export var fire_range: float = 300.0
@export var fire_cooldown: float = 2.0
@export var boss_follow_speed: float = 0.5

# Boss minion specific shadow properties
@export var shadow_minion_spawn_probability: float = 0.4
@export var shadow_minion_speed_multiplier: float = 1.3
@export var shadow_minion_aggression_multiplier: float = 1.5

# Internal variables
var boss_reference: Node2D = null
var target_player: Player = null
var orbit_angle: float = 0.0
var movement_target: Vector2 = Vector2.ZERO
var is_kamikaze_mode: bool = false
var original_movement_type: MovementType
var swarm_neighbors: Array[BossMinion] = []
var current_wave: int = 1  # Assuming set by boss or WaveManager
# fire_timer is inherited from Enemy class as a Timer node

# Constants
const MINION_SEPARATION: float = 30.0

func _ready():
	# Store original movement type
	original_movement_type = movement_type
	
	# Call parent _ready() which handles shadow initialization
	super._ready()
	
	# Set minion-specific stats (lower than regular enemies)
	score = 25
	max_health = 2
	health = max_health
	speed = 150.0
	damage_amount = 1
	vertical_speed = 50.0
	
	# Override shadow spawn probability for minions
	shadow_spawn_probability = shadow_minion_spawn_probability
	
	# Update healthbar with new max health
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.scale = Vector2(0.5, 0.5)  # Smaller healthbar for minions
	
	# Apply minion-specific shadow modifications
	_apply_minion_shadow_modifications()
	
	# Initialize orbit angle randomly
	orbit_angle = randf() * TAU
	
	# Set up fire timer
	fire_timer.wait_time = randf_range(0.5, fire_cooldown)
	fire_timer.start()
	
	# Find boss reference
	_find_boss_reference()
	
	# Find target player
	_find_target_player()
	
	# Add to minion group
	add_to_group("BossMinion")
	
	# Connect death signal
	if not died.is_connected(_on_minion_died):
		died.connect(_on_minion_died)
	
	if debug_mode:
		print("BossMinion spawned - Type: %s, Shadow: %s, Boss: %s, Wave: %d" % [
			MovementType.keys()[movement_type], is_shadow_enemy, boss_reference != null, current_wave])

# Apply shadow modifications specific to BossMinion
func _apply_minion_shadow_modifications():
	if not is_shadow_enemy:
		return
	
	# Enhance minion properties for shadow version
	speed *= shadow_minion_speed_multiplier
	fire_cooldown *= 0.7  # Fire faster
	orbit_speed *= shadow_minion_aggression_multiplier
	kamikaze_speed_multiplier *= 1.2
	
	# Shadow minions are more aggressive
	if movement_type == MovementType.GUARD:
		guard_distance *= 1.5  # Patrol wider area
	elif movement_type == MovementType.SWARM:
		swarm_cohesion *= 0.8  # Less cohesive, more chaotic
	
	# Change sprite appearance for shadow minions
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 0.9, 0.8)  # Dark blue tint
	
	if debug_mode:
		print("Shadow BossMinion modifications applied - Speed: %f, Fire Rate: %f, Orbit Speed: %f, Wave: %d" % [
			speed, fire_cooldown, orbit_speed, current_wave])

# Override shadow conversion to include minion-specific modifications
func _make_shadow_enemy():
	super._make_shadow_enemy()
	_apply_minion_shadow_modifications()

func _physics_process(delta):
	if not is_alive:
		return
	
	time_since_spawn += delta  # For entry shield
	_handle_movement(delta)    # Minion's movement
	_handle_firing()
	_handle_entry_shield(delta)
	global_position.x = clamp(global_position.x, -50, viewport_size.x + 50)

# Handle different movement patterns
func _handle_movement(delta):
	match movement_type:
		MovementType.SWARM:
			_handle_swarm_movement(delta)
		MovementType.ORBIT:
			_handle_orbit_movement(delta)
		MovementType.KAMIKAZE:
			_handle_kamikaze_movement(delta)
		MovementType.GUARD:
			_handle_guard_movement(delta)

# Swarm movement - move toward player with group cohesion
func _handle_swarm_movement(delta):
	if not target_player:
		return
	
	var desired_velocity = Vector2.ZERO
	
	# Move toward player
	var to_player = (target_player.global_position - global_position).normalized()
	desired_velocity += to_player * speed
	
	# Maintain separation from other minions
	var separation = _calculate_separation()
	desired_velocity += separation * speed * 0.5
	
	# Apply cohesion with nearby minions
	var cohesion = _calculate_cohesion()
	desired_velocity += cohesion * speed * 0.3
	
	# Shadow minions have more erratic movement
	if is_shadow_enemy:
		var noise = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		desired_velocity += noise * speed * 0.2
	
	# Apply movement
	global_position += desired_velocity.normalized() * speed * delta

# Orbit movement - circle around boss
func _handle_orbit_movement(delta):
	if not boss_reference:
		return
	
	orbit_angle += orbit_speed * delta
	
	# Calculate orbit position
	var orbit_center = boss_reference.global_position
	var orbit_pos = orbit_center + Vector2(
		cos(orbit_angle) * orbit_radius,
		sin(orbit_angle) * orbit_radius
	)
	
	# Shadow minions have unstable orbits
	if is_shadow_enemy:
		var wobble = Vector2(
			sin(orbit_angle * 3) * 20,
			cos(orbit_angle * 2) * 15
		)
		orbit_pos += wobble
	
	# Move toward orbit position
	var direction = (orbit_pos - global_position).normalized()
	global_position += direction * speed * delta

# Kamikaze movement - direct assault on player
func _handle_kamikaze_movement(delta):
	if not target_player:
		return
	
	is_kamikaze_mode = true
	
	# Move directly toward player at high speed
	var direction = (target_player.global_position - global_position).normalized()
	var kamikaze_speed = speed * kamikaze_speed_multiplier
	
	# Shadow minions are even more aggressive
	if is_shadow_enemy:
		kamikaze_speed *= 1.3
	
	global_position += direction * kamikaze_speed * delta

# Guard movement - stay near boss and defend
func _handle_guard_movement(delta):
	if not boss_reference:
		return
	
	var boss_pos = boss_reference.global_position
	var distance_to_boss = global_position.distance_to(boss_pos)
	
	# If too far from boss, move closer
	if distance_to_boss > guard_distance:
		var direction = (boss_pos - global_position).normalized()
		global_position += direction * speed * delta
	
	# If player is nearby, intercept
	if target_player:
		var player_distance = global_position.distance_to(target_player.global_position)
		if player_distance < fire_range:
			var intercept_direction = (target_player.global_position - global_position).normalized()
			global_position += intercept_direction * speed * 0.5 * delta

# Calculate separation from nearby minions
func _calculate_separation() -> Vector2:
	var separation = Vector2.ZERO
	var nearby_count = 0
	
	for minion in get_tree().get_nodes_in_group("BossMinion"):
		if minion == self or not minion.is_alive:
			continue
		
		var distance = global_position.distance_to(minion.global_position)
		if distance < MINION_SEPARATION:
			var away = (global_position - minion.global_position).normalized()
			separation += away / distance  # Closer minions have more influence
			nearby_count += 1
	
	if nearby_count > 0:
		separation = separation / nearby_count
	
	return separation

# Calculate cohesion with nearby minions
func _calculate_cohesion() -> Vector2:
	var center_of_mass = Vector2.ZERO
	var nearby_count = 0
	
	for minion in get_tree().get_nodes_in_group("BossMinion"):
		if minion == self or not minion.is_alive:
			continue
		
		var distance = global_position.distance_to(minion.global_position)
		if distance < swarm_cohesion:
			center_of_mass += minion.global_position
			nearby_count += 1
	
	if nearby_count > 0:
		center_of_mass = center_of_mass / nearby_count
		return (center_of_mass - global_position).normalized() * 0.5
	
	return Vector2.ZERO

# Handle firing at player
func _handle_firing():
	if not fire_timer.is_stopped() or not target_player or not firing_positions:
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	# Check if player is in range
	if distance_to_player <= fire_range:
		fire()
		fire_timer.wait_time = fire_cooldown
		fire_timer.start()
		
		# Shadow minions have burst fire
		if is_shadow_enemy and randf() < 0.4:
			await get_tree().create_timer(0.2).timeout
			if is_alive:
				fire()

# Override fire method for minions
func fire():
	if not (firing_positions and is_alive):
		return
	
	var bullet
	
	# Choose bullet type based on shadow status
	if is_shadow_enemy:
		bullet = SHADOW_EBULLET.instantiate()
	else:
		bullet = EBULLET.instantiate()
	
	bullet.global_position = firing_positions.global_position
	
	# Aim at player if available
	if target_player:
		var direction = (target_player.global_position - firing_positions.global_position).normalized()
		if bullet.has_method("set_direction"):
			bullet.set_direction(direction)
	
	get_tree().current_scene.call_deferred("add_child", bullet)
	
	if debug_mode:
		print("BossMinion fired - Type: %s, Shadow: %s, Wave: %d" % [
			MovementType.keys()[movement_type], is_shadow_enemy, current_wave])

# Find boss reference in scene
func _find_boss_reference():
	var bosses = get_tree().get_nodes_in_group("Boss")
	if bosses.size() > 0:
		boss_reference = bosses[0]
		if debug_mode:
			print("BossMinion found boss reference: %s, Wave: %d" % [boss_reference.name, current_wave])
	else:
		if debug_mode:
			print("BossMinion: No boss found in Boss group, Wave: %d" % current_wave)

# Find target player
func _find_target_player():
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		target_player = players[0]
		if debug_mode:
			print("BossMinion found target player: %s, Wave: %d" % [target_player.name, current_wave])

# Change movement type (can be called by boss)
func set_movement_type(new_type: MovementType):
	movement_type = new_type
	if debug_mode:
		print("BossMinion movement type changed to: %s, Wave: %d" % [MovementType.keys()[new_type], current_wave])

# Set boss reference
func set_boss_reference(boss: Node2D):
	boss_reference = boss
	if debug_mode:
		print("BossMinion boss reference set to: %s, Wave: %d" % [boss.name, current_wave])

# Activate kamikaze mode
func activate_kamikaze():
	movement_type = MovementType.KAMIKAZE
	speed *= kamikaze_speed_multiplier
	fire_cooldown *= 0.5  # Fire faster in kamikaze mode
	
	if debug_mode:
		print("BossMinion activated kamikaze mode, Wave: %d" % current_wave)

# Override damage to add minion-specific behavior
func damage(amount: int):
	super.damage(amount)
	
	# Minions become more aggressive when damaged
	if is_alive and health > 0:
		speed *= 1.1
		fire_cooldown *= 0.9
		
		# Chance to switch to kamikaze mode when critically damaged
		if health == 1 and randf() < 0.3:
			activate_kamikaze()

# Handle minion death
func _on_minion_died():
	boss_minion_died.emit()
	
	# Remove from boss reference if it exists
	if boss_reference and boss_reference.has_method("on_minion_died"):
		boss_reference.on_minion_died(self)
	
	if debug_mode:
		print("BossMinion died - Type: %s, Shadow: %s, Wave: %d" % [
			MovementType.keys()[movement_type], is_shadow_enemy, current_wave])

# Override die to add minion-specific death effects
func die():
	# Emit death signal first for manager sync
	died.emit()
	# Shadow minions explode with bullets
	if is_shadow_enemy and randf() < 0.5:
		_minion_death_burst()
	super.die()

func _exit_tree():
	# Clean up tweens if any
	for child in get_children():
		if child.get_class() == "Tween":
			child.kill()
# Shadow minions fire bullets when they die
func _minion_death_burst():
	var bullet_count = 3
	var current_scene = get_tree().current_scene
	if not current_scene:
		if debug_mode:
			print("BossMinion: No current scene for death burst, Wave: %d" % current_wave)
		return
	
	for i in range(bullet_count):
		var bullet = SHADOW_EBULLET.instantiate()
		bullet.global_position = global_position
		
		# Random direction
		var angle = randf() * TAU
		var direction = Vector2(cos(angle), sin(angle))
		
		if bullet.has_method("set_direction"):
			bullet.set_direction(direction)
		
		current_scene.call_deferred("add_child", bullet)
		
		if debug_mode:
			print("Shadow BossMinion death burst bullet %d queued, Wave: %d" % [i + 1, current_wave])

# Public methods for boss to control minions
func get_movement_type() -> MovementType:
	return movement_type

func is_in_kamikaze_mode() -> bool:
	return is_kamikaze_mode

func get_distance_to_boss() -> float:
	if boss_reference:
		return global_position.distance_to(boss_reference.global_position)
	return 0.0

func get_distance_to_player() -> float:
	if target_player:
		return global_position.distance_to(target_player.global_position)
	return 0.0

# Enhanced status reporting
func get_status() -> String:
	var status = "BossMinion - Health: %d/%d, Shadow: %s" % [health, max_health, is_shadow_enemy]
	var boss_dist = get_distance_to_boss()
	var player_dist = get_distance_to_player()
	return "%s, Type: %s, Boss: %.1f, Player: %.1f, Kamikaze: %s, Wave: %d" % [
		status, MovementType.keys()[movement_type], boss_dist, player_dist, is_kamikaze_mode, current_wave]

# Get minion-specific information
func get_minion_info() -> Dictionary:
	return {
		"is_shadow": is_shadow_enemy,
		"movement_type": MovementType.keys()[movement_type],
		"orbit_radius": orbit_radius,
		"orbit_speed": orbit_speed,
		"guard_distance": guard_distance,
		"fire_range": fire_range,
		"fire_cooldown": fire_cooldown,
		"is_kamikaze_mode": is_kamikaze_mode,
		"boss_reference": boss_reference != null,
		"target_player": target_player != null,
		"current_wave": current_wave
	}
