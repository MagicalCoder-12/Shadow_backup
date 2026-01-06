extends Node

var gm: Node
var progress_file_path: String = "user://game_progress.dat"
var backup_progress_file_path: String = "user://game_progress_backup.dat"
var autosave_progress: bool = true

# Default resource values for new or reset progress
const DEFAULT_RESOURCES: Dictionary = {
	"crystal_count": 350,
	"coin_count": 1500,
	"void_shards_count": 100
}

# Per-level data storage
var level_scores: Dictionary = {}  # level_num -> score
var level_lives: Dictionary = {}   # level_num -> lives
# Added boss_levels_completed to track which boss levels have been completed
var boss_levels_completed: Array = []  # Array of boss level numbers that have been completed

# Added: Ad usage tracking variables
var ad_usage_count: int = 0
var ad_last_used_time: int = 0

func _ready() -> void:
	gm = GameManager
	# Defer initialization until all autoloads are ready
	call_deferred("initialize")

func initialize() -> void:
	_load_settings_from_config()
	load_progress()

func _load_settings_from_config() -> void:
	if is_instance_valid(ConfigLoader):
		progress_file_path = ConfigLoader.game_settings.get("progress_file_path", "user://game_progress.dat")
	else:
		push_warning("ConfigLoader not available. Using default file paths.")

func save_progress() -> void:
	if not autosave_progress:
		return
	
	#Check if managers are ready before saving
	if not gm or not gm.level_manager or not gm.player_manager:
		push_warning("SaveManager: Cannot save progress, managers not ready yet")
		return
		
	var file: FileAccess = FileAccess.open(progress_file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save progress: Unable to open file at %s, error: %s" % [progress_file_path, FileAccess.get_open_error()])
		return
	
	# Safely store all data
	file.store_var(gm.SAVE_VERSION)
	file.store_var(gm.level_manager.unlocked_levels if gm.level_manager else 1)
	file.store_var(gm.level_manager.shadow_mode_unlocked if gm.level_manager else false)
	file.store_var(gm.level_manager.shadow_mode_tutorial_shown if gm.level_manager else false)
	file.store_var(gm.level_manager.completed_levels if gm.level_manager else [])
	file.store_var(gm.player_lives)
	file.store_var(gm.player_manager.selected_ship_id if gm.player_manager else "Ship1")
	file.store_var(gm.ships)
	file.store_var(gm.satellites)
	file.store_var(gm.crystal_count)
	file.store_var(gm.coin_count)
	file.store_var(gm.void_shards_count)

	file.store_var(level_scores)
	file.store_var(level_lives)
	# Save boss_levels_completed data
	file.store_var(boss_levels_completed)
	
	# Added: Save ad usage data
	file.store_var(ad_usage_count)
	file.store_var(ad_last_used_time)
	
	file.close()
	
	# Create backup of the save file
	if FileAccess.file_exists(progress_file_path):
		var dir := DirAccess.open("user://")
		if dir:
			dir.copy(progress_file_path, backup_progress_file_path)
		else:
			push_warning("Failed to access directory for backup")
	else:
		push_error("Save file was not created successfully at %s" % progress_file_path)

func load_progress() -> void:
	if FileAccess.file_exists(progress_file_path):
		var file: FileAccess = FileAccess.open(progress_file_path, FileAccess.READ)
		if file:
			if file.get_length() == 0:
				push_warning("Save file is empty, resetting to defaults.")
				reset_progress()
				file.close()
				return
			
			var version: int = file.get_var()
			if version != gm.SAVE_VERSION:
				push_error("Save file version mismatch. Resetting to defaults.")
				reset_progress()
				file.close()
				return
			
			# Load data with null checks for managers
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.unlocked_levels = file.get_var()
			else:
				file.get_var()  # Skip this value if manager not ready
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.shadow_mode_unlocked = file.get_var()
			else:
				file.get_var()  # Skip this value if manager not ready
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.shadow_mode_tutorial_shown = file.get_var()
			else:
				file.get_var()  # Skip this value if manager not ready
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.completed_levels = file.get_var()
			else:
				file.get_var()  # Skip this value if manager not ready
				
			if !file.eof_reached():
				gm.player_lives = file.get_var()
			if !file.eof_reached() and gm.player_manager:
				gm.player_manager.selected_ship_id = file.get_var()
			else:
				file.get_var()  # Skip this value if manager not ready
				
			if !file.eof_reached():
				gm.ships = file.get_var()
			if !file.eof_reached():
				gm.satellites = file.get_var()
			else:
				gm.satellites = _get_default_satellites()
			if !file.eof_reached():
				gm.crystal_count = file.get_var()
			if !file.eof_reached():
				gm.coin_count = file.get_var()
			if !file.eof_reached():
				gm.void_shards_count = file.get_var()
			

			if !file.eof_reached():
				level_scores = file.get_var()
			else:
				level_scores = {}
				
			if !file.eof_reached():
				level_lives = file.get_var()
			else:
				level_lives = {}
			
			# Load boss_levels_completed data
			if !file.eof_reached():
				boss_levels_completed = file.get_var()
			else:
				boss_levels_completed = []
			
			# Added: Load ad usage data
			if !file.eof_reached():
				ad_usage_count = file.get_var()
			else:
				ad_usage_count = 0
				
			if !file.eof_reached():
				ad_last_used_time = file.get_var()
			else:
				ad_last_used_time = 0
			
			# Validate ships data
			if gm.ships.is_empty() or not gm.ships is Array:
				gm.ships = _get_default_ships()
				push_warning("Loaded ships data was invalid. Using default data.")
			
			# Validate satellites data
			if gm.satellites.is_empty() or not gm.satellites is Array:
				gm.satellites = _get_default_satellites()
				push_warning("Loaded satellites data was invalid. Using default data.")
			
			# Ensure all ships have required fields and valid textures
			for ship in gm.ships:
				if not ship.has("unlocked"):
					ship["unlocked"] = false
				if not ship.has("ascend_count"):
					ship["ascend_count"] = 0
				if not ship.has("can_ascend"):
					ship["can_ascend"] = false
				if ship.has("textures"):
					for key in ship["textures"]:
						var path = ship["textures"][key]
						if not ResourceLoader.exists(path, "Texture2D"):
							push_warning("Invalid texture path %s for ship %s, using fallback" % [path, ship.get("display_name", "Unknown")])
							ship["textures"][key] = "res://Textures/player/ship_textures/ship_01_lvl0.png"
			
			# Ensure all satellites have required fields and valid texture
			for satellite in gm.satellites:
				if not satellite.has("unlocked"):
					satellite["unlocked"] = false
				if not satellite.has("ascend_count"):
					satellite["ascend_count"] = 0
				if not satellite.has("can_ascend"):
					satellite["can_ascend"] = false
				if satellite.has("texture"):
					var path = satellite["texture"]
					if not ResourceLoader.exists(path, "Texture2D"):
						push_warning("Invalid satellite texture path %s for %s, using fallback" % [path, satellite.get("display_name", "Unknown")])
						satellite["texture"] = "res://Textures/Satellite/Sat_textures/Sat1.png"
			
			file.close()
		else:
			push_error("Failed to load progress: Unable to open file at %s, error: %s" % [progress_file_path, FileAccess.get_open_error()])
			# Try to load from backup if main file fails
			if FileAccess.file_exists(backup_progress_file_path):
				push_warning("Attempting to load from backup file")
				_load_from_backup()
			else:
				reset_progress()
	else:
		# Try to load from backup if main file doesn't exist
		if FileAccess.file_exists(backup_progress_file_path):
			push_warning("Main save file not found, attempting to load from backup")
			_load_from_backup()
		else:
			reset_progress()

# Helper function to load from backup file
func _load_from_backup() -> void:
	var file: FileAccess = FileAccess.open(backup_progress_file_path, FileAccess.READ)
	if file:
		var version: int = file.get_var()
		if version != gm.SAVE_VERSION:
			push_error("Backup save file version mismatch. Resetting to defaults.")
			reset_progress()
			file.close()
			return
		else:
			# Load data from backup with null checks
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.unlocked_levels = file.get_var()
			else:
				file.get_var()
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.shadow_mode_unlocked = file.get_var()
			else:
				file.get_var()
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.shadow_mode_tutorial_shown = file.get_var()
			else:
				file.get_var()
				
			if !file.eof_reached() and gm.level_manager:
				gm.level_manager.completed_levels = file.get_var()
			else:
				file.get_var()
				
			if !file.eof_reached():
				gm.player_lives = file.get_var()
			if !file.eof_reached() and gm.player_manager:
				gm.player_manager.selected_ship_id = file.get_var()
			else:
				file.get_var()
				
			if !file.eof_reached():
				gm.ships = file.get_var()
			if !file.eof_reached():
				gm.satellites = file.get_var()
			else:
				gm.satellites = _get_default_satellites()
			if !file.eof_reached():
				gm.crystal_count = file.get_var()
			if !file.eof_reached():
				gm.coin_count = file.get_var()
			if !file.eof_reached():
				gm.void_shards_count = file.get_var()
			
			if !file.eof_reached():
				level_scores = file.get_var()
			else:
				level_scores = {}
				
			if !file.eof_reached():
				level_lives = file.get_var()
			else:
				level_lives = {}
			
			# Load boss_levels_completed data
			if !file.eof_reached():
				boss_levels_completed = file.get_var()
			else:
				boss_levels_completed = []
			
			# Added: Load ad usage data
			if !file.eof_reached():
				ad_usage_count = file.get_var()
			else:
				ad_usage_count = 0
				
			if !file.eof_reached():
				ad_last_used_time = file.get_var()
			else:
				ad_last_used_time = 0
			
			# Validate ships and satellites data
			if gm.ships.is_empty() or not gm.ships is Array:
				gm.ships = _get_default_ships()
			
			if gm.satellites.is_empty() or not gm.satellites is Array:
				gm.satellites = _get_default_satellites()
			
			# Apply validation
			_apply_data_validation()
			
			file.close()
			# Save the loaded backup data to main file to restore it
			save_progress()
	else:
		push_error("Failed to load from backup file, resetting to defaults")
		reset_progress()

# Helper function to apply validation to loaded data
func _apply_data_validation() -> void:
	# Validate ships data
	for ship in gm.ships:
		if not ship.has("unlocked"):
			ship["unlocked"] = false
		if not ship.has("ascend_count"):
			ship["ascend_count"] = 0
		if not ship.has("can_ascend"):
			ship["can_ascend"] = false
		if ship.has("textures"):
			for key in ship["textures"]:
				var path = ship["textures"][key]
				if not ResourceLoader.exists(path, "Texture2D"):
					push_warning("Invalid texture path %s for ship %s, using fallback" % [path, ship.get("display_name", "Unknown")])
					ship["textures"][key] = "res://Textures/player/ship_textures/ship_01_lvl0.png"
	
	# Validate satellites data
	for satellite in gm.satellites:
		if not satellite.has("unlocked"):
			satellite["unlocked"] = false
		if not satellite.has("ascend_count"):
			satellite["ascend_count"] = 0
		if not satellite.has("can_ascend"):
			satellite["can_ascend"] = false
		if satellite.has("texture"):
			var path = satellite["texture"]
			if not ResourceLoader.exists(path, "Texture2D"):
				push_warning("Invalid satellite texture path %s for %s, using fallback" % [path, satellite.get("display_name", "Unknown")])
				satellite["texture"] = "res://Textures/Satellite/Sat_textures/Sat1.png"

func reset_progress() -> void:
	gm.player_lives = 3
	if gm.player_manager:
		gm.player_manager.reset_player_stats()
	if gm.level_manager:
		gm.level_manager.reset_level_progress()
	gm.ships = _get_default_ships()
	gm.satellites = _get_default_satellites()
	gm.crystal_count = DEFAULT_RESOURCES["crystal_count"]
	gm.coin_count = DEFAULT_RESOURCES["coin_count"]
	gm.void_shards_count = DEFAULT_RESOURCES["void_shards_count"]
	level_scores = {}
	level_lives = {}
	# Reset boss_levels_completed data
	boss_levels_completed = []
	if autosave_progress:
		save_progress()

# Add functions to save and get per-level data

func get_level_score(_level_num: int) -> int:
	# Always return 0 as scores start from 0 for each level
	return 0

func get_level_lives(_level_num: int) -> int:
	# Always return 3 as lives start from 3 for each level
	return 3

func _get_default_ships() -> Array:
	if is_instance_valid(ConfigLoader) and ConfigLoader.ships_data and ConfigLoader.ships_data is Array:
		return ConfigLoader.ships_data.duplicate(true)
	return [{
		"id": "Ship1",
		"display_name": "NoctiSol",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 2,
		"final_rank": "LR",
		"speed": 2000,
		"damage": 20,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A mysterious vessel that harnesses both shadow and light",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_01_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_01_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_01_lvl2.png"
		}
	}]

func _get_default_satellites() -> Array:
	if is_instance_valid(ConfigLoader) and ConfigLoader.satellites_data and ConfigLoader.satellites_data is Array:
		return ConfigLoader.satellites_data.duplicate(true)
	return [{
		"id": "Satellite1",
		"display_name": "Guardian Drone",
		"rank": "R",
		"max_evolution_stage": 2,
		"final_rank": "LR",
		"damage_bonus": 5,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_ascend": false,
		"unlocked": true,
		"description": "A basic but reliable orbital companion",
		"texture": "res://Textures/player/Sat_textures/Sat1.png",
		"purchase_cost": 0
	}]
