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
	TRIANGLE
}

enum EntryPattern {
	SIDE_CURVE,
	TOP_DIVE,
	SPIRAL_IN,
	FIGURE_EIGHT,
	ZIGZAG,
	BOUNCE,
	LOOP,
	WAVE_ENTRY
}

# Difficulty levels for enemy behavior
enum DifficultyLevel {
	EASY,
	NORMAL,
	HARD,
	NIGHTMARE
}
