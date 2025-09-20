extends Resource
class_name formation_enums

enum FormationType {
	CIRCLE,
	SPIRAL,
	DIAMOND,
	GRID,
	V_FORMATION,
	DOUBLE_CIRCLE,
	HEXAGON,
	TRIANGLE,
	V_WAVE,         # New formation type
	CLUSTER,        # New formation type
	DYNAMIC         # New formation type
}

enum EntryPattern {
	SIDE_CURVE,
	TOP_DIVE,
	SPIRAL_IN,
	FIGURE_EIGHT,
	ZIGZAG,
	BOUNCE,
	LOOP,
	WAVE_ENTRY,
	STAGGERED,      # New entry pattern
	AMBUSH,         # New entry pattern
	MULTI_SIDE,     # New entry pattern
	RANDOM_EDGE,    # New entry pattern
	CORNER_AMBUSH   # New entry pattern
}

# Difficulty levels for enemy behavior
enum DifficultyLevel {
	EASY,
	NORMAL,
	HARD,
	NIGHTMARE
}

# New enemy types
enum EnemyType {
	MOB1,
	MOB2,
	MOB3,
	MOB4,
	SLOW_SHOOTER,
	FAST_ENEMY,
	BOUNCER_ENEMY,
	BOMBER_BUG,
	OblivionTank,      
	PhasePhantom,     
	ShadowSentinel
}
