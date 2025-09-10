# BYTEROVER MCP HANDBOOK
# Shadow Avenger - AI Agent Navigation Guide

*Generated: 2025-09-06*
*Project: Shadow Avenger (Godot 4.3)*

## Layer 1: System Overview

### Purpose
Shadow Avenger is a space-themed shoot-em-up game built with Godot Engine 4.3. The game features wave-based level progression, ship upgrades, boss battles, and monetization through AdMob integration. Players pilot the SOL Fighter Jet against the Umbravian alien threat.

### Technology Stack
- **Engine**: Godot 4.3
- **Language**: GDScript
- **Platform**: Mobile (Android/iOS) with touch controls
- **Audio**: Custom sound effects and background music
- **Monetization**: AdMob Plugin integration
- **Data Storage**: JSON configuration files + binary save system

### Architecture Pattern
**Autoloaded Manager Pattern**: The game uses Godot's autoload system for persistent managers that handle core game systems. Key managers include GameManager (central coordinator), SaveManager (persistence), PlayerManager (input/state), LevelManager (progression), and specialized managers for audio, scenes, and monetization.

## Layer 2: Module Map

### Core Autoload Managers
- **GameManager**: Central game state coordinator, currency management, score tracking
- **SaveManager**: Save/load game progress, settings persistence  
- **PlayerManager**: Player input handling, ship controls, touch/keyboard input
- **LevelManager**: Level progression, wave management, boss level detection
- **SceneManager**: Scene transitions, loading screens
- **AudioManager**: Sound effects, background music control
- **AdManager**: AdMob integration, reward videos
- **BulletFactory**: Object pooling for bullet instantiation
- **ConfigLoader**: JSON configuration loading and parsing

### Game Entities
- **Ships/**: Player ship variants (Ship1-Ship8) with evolution system
- **Enemy/**: Enemy types, AI behavior, spawn patterns
- **Bosses/**: Boss entities with unique mechanics for levels 5,10,15,20...
- **Bullet/**: Player and enemy projectile systems
- **Powerups/**: Collectible power-up items
- **Resources/**: Currency items (coins, crystals)

### UI Systems
- **MainScenes/**: Core UI screens (start menu, level completed, game over, upgrade menu)
- **HUD/**: In-game interface elements
- **UI/**: Reusable UI components

### Data Layer
- **data/**: JSON configuration files for settings, ships, upgrades
- **Levels/**: Level scene definitions and configurations
- **Textures/**: Art assets, fonts, UI graphics

## Layer 3: Integration Guide

### Currency System API
```gdscript
# Add currency (coins, crystals, void_shards)
GameManager.add_currency(currency_type: String, amount: int)

# Check affordability
GameManager.can_afford(currency_type: String, cost: int) -> bool

# Deduct currency
GameManager.deduct_currency(currency_type: String, amount: int)
```

### Scene Management
```gdscript
# Change scenes with loading
GameManager.change_scene(scene_path: String)

# Direct scene transitions
SceneManager.load_scene(scene_path: String)
```

### Level Progression
```gdscript
# Check if level is boss level (5,10,15,20...)
LevelManager.is_boss_level(level: int) -> bool

# Unlock next level
LevelManager.unlock_next_level(current_level: int)
```

### Configuration Files
- **game_settings.json**: Core game parameters, file paths
- **player_settings.json**: Player-specific settings
- **ships.json**: Ship definitions and properties
- **upgrade_settings.json**: Upgrade costs, evolution thresholds
- **hud_settings.json**: UI layout and display settings

## Layer 4: Extension Points

### Design Patterns
1. **Autoload Singleton Pattern**: All managers are autoloaded singletons
2. **Observer Pattern**: Signal-based communication between systems
3. **Factory Pattern**: BulletFactory for object pooling
4. **State Machine**: Game state management through GameManager

### Boss Level Detection
Boss levels follow pattern: level % 5 == 0 (levels 5, 10, 15, 20, etc.)
```gdscript
func is_boss_level(level: int) -> bool:
	return level % 5 == 0
```

### Currency Types
- **coins**: Basic currency from gameplay
- **crystals**: Premium currency from special actions  
- **void_shards**: Rare currency for ship ascension/evolution

### Reward System
Level completion rewards are handled through:
- Score-based coin conversion (100 score = 1 coin)
- Direct coin collection during levels
- Special boss rewards (different from normal levels)

### Scene Structure
UI scenes follow consistent pattern:
- Root Control node with script
- Background ColorRect for overlay
- Central Panel for content
- VBoxContainer for vertical layout
- HBoxContainer for button arrangements

### Extension Areas
1. **New Currency Types**: Add to GameManager currency system
2. **Boss Rewards**: Extend boss completion logic
3. **UI Screens**: Follow level_completed.tscn pattern
4. **Save System**: Extend SaveManager for new data types
5. **Audio**: Extend AudioManager for new sound categories

---
*This handbook provides AI agents with structured navigation paths through the Shadow Avenger codebase for efficient development and maintenance tasks.*
