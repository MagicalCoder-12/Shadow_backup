extends Node

# Configuration data
var game_settings: Dictionary = {}
var ships_data: Array = []
var upgrade_settings: Dictionary = {}
var hud_settings: Dictionary = {}
var level_waves: Dictionary = {} # Key: level number (int), Value: Array of wave configs

# File paths
const GAME_SETTINGS_PATH = "res://data/game_settings.json"
const SHIPS_PATH = "res://data/ships.json"
const UPGRADE_SETTINGS_PATH = "res://data/upgrade_settings.json"
const PLAYER_SETTINGS_PATH = "res://data/player_settings.json"
const HUD_SETTINGS_PATH = "res://data/hud_settings.json"
const LEVEL_WAVES_PATH_TEMPLATE = "res://data/level_%d_waves.json"

func _ready() -> void:
	"""
	Loads all JSON configuration files at game startup.
	Provides fallback defaults if files are missing or corrupted.
	"""

	# Load game settings
	game_settings = _load_json_file(GAME_SETTINGS_PATH, _get_default_game_settings())
	if game_settings.is_empty():
		push_error("Failed to load game settings. Using fallback defaults.")
		game_settings = _get_default_game_settings()

	# Load ships data
	ships_data = _load_json_file(SHIPS_PATH, _get_default_ships_data())
	if ships_data.is_empty():
		push_error("Failed to load ships data. Using fallback default ships.")
		ships_data = _get_default_ships_data()

	# Load upgrade settings
	upgrade_settings = _load_json_file(UPGRADE_SETTINGS_PATH, _get_default_upgrade_settings())
	if upgrade_settings.is_empty():
		push_error("Failed to load upgrade settings. Using fallback defaults.")
		upgrade_settings = _get_default_upgrade_settings()

	# Load HUD settings
	hud_settings = _load_json_file(HUD_SETTINGS_PATH, _get_default_hud_settings())
	if hud_settings.is_empty():
		push_error("Failed to load HUD settings. Using fallback defaults.")
		hud_settings = _get_default_hud_settings()

func _get_default_game_settings() -> Dictionary:
	var defaults = {
		"progress_file_path": "user://game_progress.dat",
		"default_bullet_speed": 3000.0,
		"default_bullet_damage": 20,
		"max_attack_level": 4,
	}
	# Add version information to defaults
	defaults["version"] = GameManager.SAVE_VERSION
	return defaults

func _get_default_ships_data() -> Array:
	var defaults = [
	{
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
		"unlocked": true,
		"description": "A mysterious vessel that harnesses both shadow and light",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_01_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_01_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_01_lvl2.png"
			}
		},
	{
		"id": "Ship2",
		"display_name": "Aether Strike",
		"rank": "SR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 2,
		"final_rank": "LR",
		"damage": 25,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A swift striker with ethereal capabilities",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_02_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_02_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_02_lvl2.png"
			}
		},
	{
		"id": "Ship3",
		"display_name": "Astra Blade",
		"rank": "SSR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 2,
		"final_rank": "LR",
		"damage": 30,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A blade that cuts through the fabric of space",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_03_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_03_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_03_lvl2.png"
		 }
		},
	{
		"id": "Ship4",
		"display_name": "Phantom Drake",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 4,
		"final_rank": "LR",
		"damage": 35,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A ghostly dragon that phases through dimensions",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_04_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_04_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_04_lvl2.png",
			"upgrade_3": "res://Textures/player/ship_textures/ship_04_lvl3.png",
			"upgrade_4": "res://Textures/player/ship_textures/ship_04_lvl4.png"
			}
		},
	{
		"id": "Ship5",
		"display_name": "Umbra Wraith",
		"rank": "SR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 10,
		"final_rank": "LR",
		"damage": 40,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A shadow wraith that haunts the void",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_05_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_05_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_05_lvl2.png",
			"upgrade_3": "res://Textures/player/ship_textures/ship_05_lvl3.png",
			"upgrade_4": "res://Textures/player/ship_textures/ship_05_lvl4.png",
			"upgrade_5": "res://Textures/player/ship_textures/ship_05_lvl5.png",
			"upgrade_6": "res://Textures/player/ship_textures/ship_05_lvl6.png",
			"upgrade_7": "res://Textures/player/ship_textures/ship_05_lvl7.png",
			"upgrade_8": "res://Textures/player/ship_textures/ship_05_lvl8.png",
			"upgrade_9": "res://Textures/player/ship_textures/ship_05_lvl9.png",
			"upgrade_10": "res://Textures/player/ship_textures/ship_05_lvl10.png"
			}
		},
	{
		"id": "Ship6",
		"display_name": "Void Howler",
		"rank": "SSR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 8,
		"final_rank": "LR",
		"damage": 45,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A cosmic predator that howls through the void",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_06_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_06_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_06_lvl2.png",
			"upgrade_3": "res://Textures/player/ship_textures/ship_06_lvl3.png",
			"upgrade_4": "res://Textures/player/ship_textures/ship_06_lvl4.png",
			"upgrade_5": "res://Textures/player/ship_textures/ship_06_lvl5.png",
			"upgrade_6": "res://Textures/player/ship_textures/ship_06_lvl6.png",
			"upgrade_7": "res://Textures/player/ship_textures/ship_06_lvl7.png",
			"upgrade_8": "res://Textures/player/ship_textures/ship_06_lvl8.png"
			}
		},
	{
		"id": "Ship7",
		"display_name": "Tenebris Fang",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 6,
		"final_rank": "LR",
		"damage": 50,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A razor-sharp fang that cuts through darkness",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_07_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_07_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_07_lvl2.png",
			"upgrade_3": "res://Textures/player/ship_textures/ship_07_lvl3.png",
			"upgrade_4": "res://Textures/player/ship_textures/ship_07_lvl4.png",
			"upgrade_5": "res://Textures/player/ship_textures/ship_07_lvl5.png",
			"upgrade_6": "res://Textures/player/ship_textures/ship_07_lvl6.png"
			}
		},
	{
		"id": "Ship8",
		"display_name": "Oblivion Viper",
		"rank": "SR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 6,
		"final_rank": "LR",
		"damage": 55,
		"upgrade_count": 0,
		"ascend_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"unlocked": false,
		"description": "A serpentine vessel that strikes from the void",
		"textures": {
			"base": "res://Textures/player/ship_textures/ship_08_lvl0.png",
			"upgrade_1": "res://Textures/player/ship_textures/ship_08_lvl1.png",
			"upgrade_2": "res://Textures/player/ship_textures/ship_08_lvl2.png",
			"upgrade_3": "res://Textures/player/ship_textures/ship_08_lvl3.png",
			"upgrade_4": "res://Textures/player/ship_textures/ship_08_lvl4.png",
			"upgrade_5": "res://Textures/player/ship_textures/ship_08_lvl5.png",
			"upgrade_6": "res://Textures/player/ship_textures/ship_08_lvl6.png"
			}
		}
	]
	return defaults

func _get_default_upgrade_settings() -> Dictionary:
	var defaults = {
	"upgrade_crystal_cost": 50,
	"upgrade_coin_cost": 500,
	"upgrade_ascend_cost": 100,
	"ad_crystal_reward": 10,
	"ad_ascend_reward": 5,
	"ad_coins_reward": 1000,
	"ascension_thresholds": {
		"Ship1": [4, 8],
		"Ship2": [4, 8],
		"Ship3": [4, 8],
		"Ship4": [4, 8, 12, 16],
		"Ship5": [4, 8, 12, 16, 20, 24, 28, 32, 36, 40],
		"Ship6": [4, 8, 12, 16, 20, 24, 28, 32],
		"Ship7": [4, 8, 12, 16, 20, 24],
		"Ship8": [4, 8, 12, 16, 20]
	},
	"ship_evolution_names": {
		"Ship1": ["NoctiSol", "Solstice", "Eclipse Sovereign"],
		"Ship2": ["Aether Strike", "Void Piercer", "Quantum Saber"],
		"Ship3": ["Astra Blade", "Astra Striker", "Astra Prime"],
		"Ship4": ["Phantom Drake", "Spectral Wyrm", "Ethereal Leviathan", "Void Dragon", "Cosmic Serpent"],
		"Ship5": ["Umbra Wraith", "Shadow Reaper", "Darkness Incarnate", "Void Phantom", "Abyssal Terror", "Nightmare Sovereign", "Obsidian Specter", "Eclipse Revenant", "Nether Shade", "Celestial Wraith","Ethereal Scythe"],
		"Ship6": ["Void Howler", "Cosmic Screamer", "Stellar Devourer", "Galactic Destroyer", "Nova Reaver", "Quantum Predator","Singularity Hunter", "Infinity Ravager", "Omniverse Annihilator"],
		"Ship7": ["Tenebris Fang", "Shadow Blade", "Darkness Cutter", "Void Ripper", "Abyssal Slicer", "Nightmare Edge", "Phantom Cleaver", "Spectral Razor"],
		"Ship8": ["Void Serpent", "Cosmic Cobra", "Stellar Python", "Galactic Anaconda", "Universal Leviathan", "Infinity Wyrm"]
			}
		}
	# Add version information to defaults
	defaults["version"] = GameManager.SAVE_VERSION
	return defaults

func _get_default_hud_settings() -> Dictionary:
	var defaults = {
		"charge_per_enemy": 10.0,
		"max_charge": 100.0
	}
	# Add version information to defaults
	defaults["version"] = GameManager.SAVE_VERSION
	return defaults

func _load_json_file(path: String, default: Variant) -> Variant:
	"""
	Loads and parses a JSON file, returning the parsed data or the default value on failure.
	"""
	if not FileAccess.file_exists(path):
		return default
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open JSON file at path: %s" % path)
		return default
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var data = json.get_data()
		# Check if the data is a dictionary and has a version field
		if data is Dictionary and data.has("version"):
			if data["version"] != GameManager.SAVE_VERSION:
				push_error("JSON file version mismatch in %s. Expected version %d, got %d. Using defaults." % [path, GameManager.SAVE_VERSION, data["version"]])
				return default
			# Return the data without the version field
			data.erase("version")
			return data
		else:
			# For arrays or data without version field, return as is
			# In a real implementation, you might want to handle version checking differently for arrays
			return data
	else:
		push_error("Error parsing JSON file at %s: %s" % [path, json.get_error_message()])
		return default

func _save_json_file(path: String, data: Variant) -> void:
	"""
	Saves data to a JSON file with version information.
	"""
	var data_to_save = data
	
	# Add version information to the data if it's a dictionary
	if data is Dictionary:
		data_to_save = data.duplicate()
		data_to_save["version"] = GameManager.SAVE_VERSION
	elif data is Array:
		# For arrays, save the data as is
		# In a more complex implementation, you might want to save version information separately
		data_to_save = data
	else:
		# For other types, wrap in a dictionary with version
		data_to_save = {"data": data, "version": GameManager.SAVE_VERSION}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data_to_save, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("Could not write to JSON file at path: %s" % path)
