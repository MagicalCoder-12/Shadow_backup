# WaveConfig Usage Guide

## Overview
WaveConfig resources are used to define enemy wave configurations in levels. Each WaveConfig defines the properties of a single wave, including enemy type, formation, entry pattern, and difficulty.

## Creating WaveConfig Resources

### Method 1: Using the Inspector (Recommended)
1. In the Godot editor, right-click in the FileSystem dock
2. Select "New Resource"
3. Choose "WaveConfig" from the list
4. Save the resource with a descriptive name (e.g., "Wave1.tres")

### Method 2: Using the Provided Template
1. Copy the ExampleWaveConfig.tres file
2. Rename it to match your wave (e.g., "BossWave.tres")
3. Modify the properties as needed

## WaveConfig Properties

### Basic Properties
- **formation_type**: The geometric formation enemies will use (CIRCLE, GRID, V_FORMATION, etc.)
- **entry_pattern**: How enemies enter the screen (SIDE_CURVE, TOP_DIVE, SPIRAL_IN, etc.)
- **difficulty**: Difficulty level (EASY, NORMAL, HARD, NIGHTMARE)
- **enemy_type**: Type of enemy to spawn (mob1, mob2, SlowShooter, etc.)
- **enemy_density**: Number of enemies (Sparse, Normal, Dense, Maximum)

### Boss Waves
- **boss_scene**: Assign a boss scene to create a boss wave (overrides enemy_type)

### Formation Parameters
- **formation_center**: Center point of the formation (Vector2)
- **formation_radius**: Radius for circular formations (float)
- **formation_spacing**: Spacing between enemies (float)
- **spawn_delay**: Delay between enemy spawns (float)
- **entry_speed**: Speed at which enemies enter (float)

## Assigning Waves to Levels

1. Open a level scene in the editor
2. Select the LevelManager node
3. In the Inspector, find the "Waves" property
4. Click the "Array[WaveConfig]" property
5. Add WaveConfig resources by:
   - Clicking "Add Element"
   - Choosing "Load" and selecting your WaveConfig resource file
   - Or creating new resources directly in the inspector

## Example Wave Configurations

### Basic Enemy Wave
```
formation_type = CIRCLE
entry_pattern = SIDE_CURVE
difficulty = NORMAL
enemy_type = "mob1"
enemy_density = "Normal"
```

### Boss Wave
```
boss_scene = preload("res://Bosses/Boss1.tscn")
entry_pattern = TOP_DIVE
difficulty = HARD
```

### Dense Enemy Wave
```
formation_type = GRID
entry_pattern = SPIRAL_IN
difficulty = HARD
enemy_type = "FastEnemy"
enemy_density = "Dense"
```

## Tips

1. **Enemy Density Mapping**:
   - Sparse: Fewer enemies
   - Normal: Standard count
   - Dense: More enemies
   - Maximum: Highest count for formation type

2. **Formation Count Optimization**:
   - Each formation type has optimal enemy counts
   - The system automatically selects the best count based on density setting

3. **Boss Waves**:
   - Set the boss_scene property to create a boss wave
   - Boss waves automatically use 1 enemy count regardless of density

4. **Testing**:
   - Use the debug_mode property in Level.gd to see wave information in the output
