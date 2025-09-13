extends Resource
class_name WaveConfig

# Import shared enums (from your shared enum script, e.g., formation_enums.gd)
@export var formation_type: formation_enums.FormationType = formation_enums.FormationType.CIRCLE:
	set(value):
		formation_type = value
		_update_count_options()

@export var entry_pattern: formation_enums.EntryPattern = formation_enums.EntryPattern.SIDE_CURVE

# CORRECTED: Difficulty enum now matches the Enemy script
@export var difficulty: formation_enums.DifficultyLevel = formation_enums.DifficultyLevel.NORMAL

@export_enum("mob1", "mob2", "mob3", "mob4", "SlowShooter", "FastEnemy", "BouncerEnemy","BomberBug", "OblivionTank", "PhasePhantom","ShadowSentinel")
var enemy_type: String = "mob1"

# NEW: Dedicated boss scene for boss waves
@export var boss_scene: PackedScene

# Dynamic enemy count based on formation type
@export_enum("Sparse", "Normal", "Dense", "Maximum")
var enemy_density: String = "Normal"

# Formation parameters
@export var formation_center: Vector2 = Vector2(640, 600)
@export var formation_radius: float = 150.0
@export var formation_spacing: float = 100.0
@export var spawn_delay: float = 0.3
@export var entry_speed: float = 300.0

# Internal properties used by FormationManager (don't export these)
var spawn_pos: Vector2
var entry_pos: Vector2
var center: Vector2
var count: int
var padding: float

# Optimal enemy counts for each formation type
var formation_counts := {
	formation_enums.FormationType.CIRCLE: [6, 8, 12, 16],          # Even divisions for circle
	formation_enums.FormationType.SPIRAL: [8, 12, 16, 20],         # Good for spiral progression
	formation_enums.FormationType.DIAMOND: [6, 8, 12, 16],         # Symmetric diamond shapes
	formation_enums.FormationType.GRID: [9, 16, 25, 36],           # Perfect squares (3x3, 4x4, 5x5, 6x6)
	formation_enums.FormationType.V_FORMATION: [6, 8, 10, 12],     # Even numbers for balanced V
	formation_enums.FormationType.DOUBLE_CIRCLE: [8, 12, 16, 20],  # Even for inner/outer circles
	formation_enums.FormationType.HEXAGON: [6, 12, 18, 24],        # Multiples of 6 for hexagon sides
	formation_enums.FormationType.TRIANGLE: [6, 10, 15, 21],       # Triangular numbers (3+2+1, 4+3+2+1, etc.),
	formation_enums.FormationType.V_WAVE: [8, 12, 16, 20],         # New V-wave formation
	formation_enums.FormationType.CLUSTER: [6, 9, 12, 15],         # New cluster formation
	formation_enums.FormationType.DYNAMIC: [8, 12, 16, 20]        # New dynamic formation
}

# Paths to enemy scenes
var enemy_paths := {
	"mob1": preload("res://Enemy/mob1.tscn"),
	"mob2": preload("res://Enemy/mob2.tscn"),
	"mob3": preload("res://Enemy/mob3.tscn"),
	"mob4": preload("res://Enemy/mob4.tscn"),
	"SlowShooter": preload("res://Enemy/SlowShooter.tscn"),
	"FastEnemy": preload("res://Enemy/FastEnemy.tscn"),
	"BouncerEnemy": preload("res://Enemy/BouncerEnemy.tscn"),
	"BomberBug" : preload("res://Enemy/BomberBug.tscn"),
	"OblivionTank": preload("res://Enemy/OblivionTank.tscn"),            
	"PhasePhantom": preload("res://Enemy/PhasePhantom.tscn"),
	"ShadowSentinel":preload("res://Enemy/ShadowSentinel.tscn")
}

# Returns the configured enemy or boss scene
func get_enemy_scene() -> PackedScene:
	if boss_scene:
		return boss_scene
	if enemy_paths.has(enemy_type):
		return enemy_paths[enemy_type]
	else:
		push_warning("Invalid enemy_type '%s' in WaveConfig. Falling back to 'mob1'." % enemy_type)
		return enemy_paths["mob1"]

# Get enemy count based on formation type and density
func get_enemy_count() -> int:
	# For boss waves, return 1 if boss_scene is set
	if boss_scene:
		return 1
	var counts = formation_counts.get(formation_type, [6, 8, 12, 16])
	
	match enemy_density:
		"Sparse":
			return counts[0]
		"Normal":
			return counts[1]
		"Dense":
			return counts[2]
		"Maximum":
			return counts[3]
		_:
			return counts[1]  # Default to Normal

# Helper function to update count options when formation type changes
func _update_count_options():
	# This is called when formation_type changes
	# The counts will be automatically updated when get_enemy_count() is called
	pass

# Getter methods that FormationManager expects
func get_formation_type() -> formation_enums.FormationType:
	return formation_type

func get_entry_pattern() -> formation_enums.EntryPattern:
	return entry_pattern

func get_formation_center() -> Vector2:
	return formation_center

func get_formation_radius() -> float:
	return formation_radius

func get_formation_spacing() -> float:
	return formation_spacing

func get_spawn_delay() -> float:
	return spawn_delay

func get_entry_speed() -> float:
	return entry_speed

# Debug helper to show what counts are available for current formation
func get_available_counts() -> Array:
	return formation_counts.get(formation_type, [6, 8, 12, 16])

# Get description of current density setting
func get_density_description() -> String:
	var counts = get_available_counts()
	var _current_count = get_enemy_count()
	
	if boss_scene:
		return "Boss (1 enemy)"
	
	match enemy_density:
		"Sparse":
			return "Sparse (%d enemies)" % counts[0]
		"Normal":
			return "Normal (%d enemies)" % counts[1]
		"Dense":
			return "Dense (%d enemies)" % counts[2]
		"Maximum":
			return "Maximum (%d enemies)" % counts[3]
		_:
			return "Normal (%d enemies)" % counts[1]

# NEW: Check if this is a boss wave
func is_boss_wave() -> bool:
	return boss_scene != null
