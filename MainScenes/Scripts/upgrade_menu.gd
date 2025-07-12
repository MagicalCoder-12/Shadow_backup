extends Control

# ================================
# CONSTANTS & CONFIGURATION
# ================================

const MAP = "res://Map/map.tscn"

# Upgrade costs
const UPGRADE_CRYSTAL_COST: int = 50
const UPGRADE_COIN_COST: int = 5000
const UPGRADE_ASCEND_COST: int = 100

# Ad rewards
const AD_CRYSTAL_REWARD: int = 10
const AD_ASCEND_REWARD: int = 5
const AD_COINS_REWARD: int = 2000

# Dynamic ascension thresholds for each ship
var ascension_thresholds = {
	"Ship1": [4, 8],                           # 2 ascensions (NoctiSol -> Solstice)
	"Ship2": [4, 8],                           # 2 ascensions (Aether Strike evolution)
	"Ship3": [4, 8],                           # 2 ascensions (new)
	"Ship4": [4,8,12,16],                       # 4 ascensions (Phantom Drake evolution)
	"Ship5": [4, 8, 12, 16, 20, 24, 28, 32, 36], # 9 ascensions (Umbra Wraith evolution)
	"Ship6": [4, 8, 12, 16, 20, 24, 28, 32],     # 8 ascensions (Void Howler evolution)
	"Ship7": [4, 8, 12, 16, 20, 24, 28, 32, 36], # 9 ascensions (Tenebris Fang evolution)
	"Ship8": [4, 8, 12, 16, 20, 24]             # 6 ascensions (Oblivion Viper evolution)
}

# Ship evolution names for each ascension stage
var ship_evolution_names = {
	"Ship1": ["NoctiSol", "Solstice", "Eclipse Sovereign"],
	"Ship2": ["Aether Strike", "Void Piercer", "Quantum Saber"],
	"Ship3": ["Astra Blade", "Astra Striker", "Astra Prime"],
	"Ship4": ["Phantom Drake", "Spectral Wyrm", "Ethereal Leviathan", "Void Dragon", "Cosmic Serpent"],
	"Ship5": [
		"Umbra Wraith", "Shadow Reaper", "Darkness Incarnate", 
		"Void Phantom", "Abyssal Terror", "Nightmare Sovereign",
		"Obsidian Specter", "Eclipse Revenant", "Nether Shade", "Celestial Wraith"
	],
	"Ship6": [
		"Void Howler", "Cosmic Screamer", "Stellar Devourer", 
		"Galactic Destroyer", "Nova Reaver", "Quantum Predator",
		"Singularity Hunter", "Infinity Ravager", "Omniverse Annihilator"
	],
	"Ship7": [
		"Tenebris Fang", "Shadow Blade", "Darkness Cutter", 
		"Void Ripper", "Abyssal Slicer", "Nightmare Edge", 
		"Phantom Cleaver", "Spectral Razor", "Ethereal Scythe", 
		"Cosmic Reaper"
	],
	"Ship8": [
		"Oblivion Viper", "Void Serpent", "Cosmic Cobra", 
		"Stellar Python", "Galactic Anaconda", "Universal Leviathan", 
		"Infinity Wyrm", "Multiversal Basilisk", "Omnipotent Ouroboros"
	]
}

# ================================
# SHIP DATA CONFIGURATION
# ================================

var ships = [
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
		"can_evolve": true,
		"can_ascend": false,
		"description": "A mysterious vessel that harnesses both shadow and light"
	},
	{
		"id": "Ship2",
		"display_name": "Aether Strike",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 2,
		"final_rank": "SR",
		"speed": 1800,
		"damage": 25,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Swift striker that cuts through the void"
	},
	{
		"id": "Ship3",
		"display_name": "Astra Blade",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 2,
		"final_rank": "SR",
		"speed": 1800,
		"damage": 25,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Swift striker that cuts through the void"
	},
	{
		"id": "Ship4",
		"display_name": "Phantom Drake",
		"rank": "R",
		"current_evolution_stage": 0,
		"max_evolution_stage": 4,
		"final_rank": "SR",
		"speed": 1900,
		"damage": 30,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Elusive predator with spectral capabilities"
	},
	{
		"id": "Ship5",
		"display_name": "Umbra Wraith",
		"rank": "SR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 9,
		"final_rank": "LR",
		"speed": 2100,
		"damage": 40,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Shadow-born destroyer with ethereal powers"
	},
	{
		"id": "Ship6",
		"display_name": "Void Howler",
		"rank": "SR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 8,
		"final_rank": "LR",
		"speed": 2200,
		"damage": 45,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Unleashes the fury of the cosmic void"
	},
	{
		"id": "Ship7",
		"display_name": "Tenebris Fang",
		"rank": "SSR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 9,
		"final_rank": "LR",
		"speed": 2300,
		"damage": 50,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Pierces through darkness with deadly precision"
	},
	{
		"id": "Ship8",
		"display_name": "Oblivion Viper",
		"rank": "SSR",
		"current_evolution_stage": 0,
		"max_evolution_stage": 6,
		"final_rank": "LR",
		"speed": 2400,
		"damage": 55,
		"upgrade_count": 0,
		"can_evolve": true,
		"can_ascend": false,
		"description": "Apex predator of the cosmic battlefield"
	}
]

# ================================
# TEXTURE RESOURCES
# ================================

var ship_textures = {
	"Ship1": {
		"base": preload("res://Textures/player/Spaceships-13/spaceships/h-03.png"),
		"upgrade_1": preload("res://Textures/player/Spaceships-13/spaceships/b-02.png"),
		"upgrade_2": preload("res://Textures/player/Spaceships-13/spaceships/b-01.png")
	},
	"Ship2": {
		"base": preload("res://Textures/player/Example_ships/Spaceships-12/Spaceships/Spaceship12-black-01.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/Spaceships-12/Spaceships/Spaceship12-black-02.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/Spaceships-12/Spaceships/Spaceship12-black-03.png")
	},
	"Ship3": {
		"base": preload("res://Textures/player/Example_ships/ships-03/Spaceships-03-Blue-01.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/ships-03/Spaceships-03-Blue-02.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/ships-03/Spaceships-03-Blue-03.png"),
	},
	"Ship4": {
		"base": preload("res://Textures/player/Example_ships/13B.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/10B.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/rect1.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/rect2.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/rect3.png"),
	},
	"Ship5": {
		"base": preload("res://Textures/player/Example_ships/1.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/2.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/3.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/4.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/5.png"),
		"upgrade_5": preload("res://Textures/player/Example_ships/8.png"),
		"upgrade_6": preload("res://Textures/player/Example_ships/Spaceship14.png"),
		"upgrade_7": preload("res://Textures/player/Example_ships/Spaceship14C.png"),
		"upgrade_8": preload("res://Textures/player/Example_ships/Spaceship15.png"),
		"upgrade_9": preload("res://Textures/player/Example_ships/Spaceship16.png")
	},
	"Ship6": {
		"base": preload("res://Textures/player/Example_ships/12B.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/2B.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/3B.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/5B.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/7B.png"),
		"upgrade_5": preload("res://Textures/player/Example_ships/9B.png"),
		"upgrade_6": preload("res://Textures/player/Example_ships/Spaceship14B.png"),
		"upgrade_7": preload("res://Textures/player/Example_ships/Spaceship15B.png"),
		"upgrade_8": preload("res://Textures/player/Example_ships/Spaceship16B.png")
	},
	"Ship7": {
		"base": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-01.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-02.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-03.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-04.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-05.png"),
		"upgrade_5": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-06.png"),
		"upgrade_6": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-07.png"),
		"upgrade_7": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-08.png"),
		"upgrade_8": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-09.png"),
		"upgrade_9": preload("res://Textures/player/Example_ships/AntuZ/SpaceShips/G-10.png")
	},
	"Ship8": {
		"base": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir1.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir2.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir3.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir4.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir5.png"),
		"upgrade_5": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir6.png"),
		"upgrade_6": preload("res://Textures/player/Example_ships/Drakir/Spaceship-Drakir7.png")
	}
}

# ================================
# SHIP MAPPING & INDEXING
# ================================

var name_to_index = {
	"Ship1": 0,
	"Ship2": 1,
	"Ship3": 2,
	"Ship4": 3,
	"Ship5": 4,
	"Ship6": 5,
	"Ship7": 6,
	"Ship8": 7
}

# ================================
# UI NODE REFERENCES
# ================================

@onready var crystals: Label = $Resources/HBoxContainer/Crystals
@onready var coins: Label = $Resources/Money/Coins
@onready var acend_amt: Label = $UI/Ascend/Acend_amt
@onready var ascend_crystals: Label = $HBoxContainer/Ascend_crystals
@onready var warning: Label = $UI/WarningPanel/Warning_Label
@onready var warning_panel: Panel = $UI/WarningPanel
@onready var selected_ship: TextureRect = $SelectedShipDisplay/SelectedShip
@onready var ship_name: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipName
@onready var speed: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Speed
@onready var damage: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Damage
@onready var status_label: Label = $SelectedShipDisplay/StatusLabel
@onready var ascend: Button = $UI/Ascend
@onready var upgrade_crystals_button: TextureButton = $UI/HBoxContainer/Upgrade_Crystals
@onready var upgrade_coins_button: TextureButton = $UI/HBoxContainer/Upgrade_coins

@onready var ship_textures_ui = [
	$ScrollContainer/GridContainer/Ship1/S01,
	$ScrollContainer/GridContainer/Ship2/S02,
	$ScrollContainer/GridContainer/Ship3/S03,
	$ScrollContainer/GridContainer/Ship4/S04,
	$ScrollContainer/GridContainer/Ship5/S05,
	$ScrollContainer/GridContainer/Ship6/S06,
	$ScrollContainer/GridContainer/Ship7/S07,
	$ScrollContainer/GridContainer/Ship8/S08
]

@onready var power_up: AudioStreamPlayer = $"Power-up"

# ================================
# GAME STATE VARIABLES
# ================================

var selected_ship_index: int = 0
var crystal_count: int = 10000
var coin_count: int = 5000
var ascend_crystals_count: int = 5000
var is_ad_loading: bool = false

# ================================
# INITIALIZATION
# ================================

func _ready() -> void:
	get_tree().get_root().connect("go_back_requested", Callable(self, "_on_back_pressed"))
	_setup_admob_connections()
	_initialize_ui()
	_load_ship_progress()

func _setup_admob_connections() -> void:
	if GameManager.admob:
		GameManager.admob.interstitial_ad_loaded.connect(_on_admob_interstitial_ad_loaded)
		GameManager.admob.interstitial_ad_failed_to_load.connect(_on_admob_interstitial_ad_failed_to_load)
		GameManager.admob.interstitial_ad_dismissed_full_screen_content.connect(_on_admob_interstitial_ad_dismissed)

func _initialize_ui() -> void:
	_update_currency_display()
	_update_all_ship_textures()
	update_ship_ui()

func _load_ship_progress() -> void:
	pass

# ================================
# CURRENCY MANAGEMENT
# ================================

func _update_currency_display() -> void:
	crystals.text = "Crystals: %d" % crystal_count
	coins.text = "Coins: %d" % coin_count
	ascend_crystals.text = "Ascend: %d" % ascend_crystals_count

func _can_afford_upgrade(cost: int, currency_type: String) -> bool:
	match currency_type:
		"crystals":
			return crystal_count >= cost
		"coins":
			return coin_count >= cost
		"ascend_crystals":
			return ascend_crystals_count >= cost
		_:
			return false

func _deduct_currency(amount: int, currency_type: String) -> void:
	match currency_type:
		"crystals":
			crystal_count -= amount
		"coins":
			coin_count -= amount
		"ascend_crystals":
			ascend_crystals_count -= amount
	_update_currency_display()

# ================================
# SHIP SELECTION SYSTEM
# ================================

func update_ship_ui() -> void:
	var ship = ships[selected_ship_index]
	var ship_id = ship["id"]
	var current_texture = _get_ship_texture_dynamic(ship_id, ship["upgrade_count"])
	selected_ship.texture = current_texture

	var current_evolution_name = _get_current_evolution_name(ship_id, ship["current_evolution_stage"])
	ship_name.text = current_evolution_name
	speed.text = "Speed: %d" % ship["speed"]

	var rank_color = _get_rank_color(ship["rank"])
	ship_name.modulate = rank_color

	# Update status display
	var status_text = ""
	if ship["can_ascend"]:
		status_text = "Ready to Ascend!"
	elif ship["current_evolution_stage"] == ship["max_evolution_stage"]:
		var last_threshold = ascension_thresholds[ship_id][-1]
		var additional_upgrades = ship["upgrade_count"] - last_threshold
		if additional_upgrades >= 5:
			status_text = "Max Level"
		else:
			status_text = "Max Ascension Reached! (+%d/5)" % additional_upgrades
	else:
		var next_requirements = _get_next_evolution_requirements(selected_ship_index)
		if next_requirements["can_evolve"]:
			status_text = "Upgrades to next ascension: %d" % next_requirements["upgrades_needed"]
	status_label.text = status_text  # Assumes a StatusLabel node exists

	_update_ascend_button_visibility()
	_update_upgrade_buttons_state()

func _update_ascend_button_visibility() -> void:
	var ship = ships[selected_ship_index]
	if ship["can_ascend"]:
		ascend.visible = true
		ascend.disabled = false
		var ship_id = ship["id"]
		var next_stage = ship["current_evolution_stage"] + 1
		var next_evolution_name = _get_current_evolution_name(ship_id, next_stage)
		ascend.text = "Ascend to %s" % next_evolution_name
		acend_amt.text = str(UPGRADE_ASCEND_COST)
	else:
		ascend.visible = false

func _update_upgrade_buttons_state() -> void:
	var ship = ships[selected_ship_index]
	var is_max_level = ship["current_evolution_stage"] == ship["max_evolution_stage"] and ship["upgrade_count"] >= ascension_thresholds[ship["id"]][-1] + 5
	if ship["can_ascend"] or is_max_level:
		upgrade_crystals_button.disabled = true
		upgrade_crystals_button.modulate = Color.GRAY
		upgrade_coins_button.disabled = true
		upgrade_coins_button.modulate = Color.GRAY
	else:
		upgrade_crystals_button.disabled = false
		upgrade_crystals_button.modulate = Color.WHITE
		upgrade_coins_button.disabled = false
		upgrade_coins_button.modulate = Color.WHITE

func _show_next_evolution_info(ship: Dictionary) -> void:
	var ship_id = ship["id"]
	var current_stage = ship["current_evolution_stage"]
	var thresholds = ascension_thresholds[ship_id]
	if current_stage < thresholds.size():
		var next_threshold = thresholds[current_stage]
		var upgrades_needed = next_threshold - ship["upgrade_count"]
		if upgrades_needed > 0 and not ship["can_ascend"]:
			var next_evolution_name = _get_current_evolution_name(ship_id, current_stage + 1)
			print("Next Evolution: %s (in %d upgrades)" % [next_evolution_name, upgrades_needed])

func _get_current_evolution_name(ship_id: String, evolution_stage: int) -> String:
	var evolution_names = ship_evolution_names[ship_id]
	if evolution_stage < evolution_names.size():
		return evolution_names[evolution_stage]
	return evolution_names[evolution_names.size() - 1]

func select_ship_by_name(ship_node_name: String) -> void:
	if name_to_index.has(ship_node_name):
		selected_ship_index = name_to_index[ship_node_name]
		update_ship_ui()
		_play_selection_sound()
	else:
		push_warning("Unknown ship node name: %s" % ship_node_name)

func _play_selection_sound() -> void:
	pass

# ================================
# ENHANCED TEXTURE MANAGEMENT
# ================================

func _get_ship_texture_dynamic(ship_id: String, upgrade_count: int) -> Texture2D:
	var textures = ship_textures[ship_id]
	var thresholds = ascension_thresholds[ship_id]
	var texture_stage = 0
	for i in range(thresholds.size()):
		if upgrade_count >= thresholds[i]:
			texture_stage = i + 1
		else:
			break
	var texture_key = "base" if texture_stage == 0 else "upgrade_%d" % texture_stage
	return textures.get(texture_key, textures["base"])

func _update_all_ship_textures() -> void:
	for i in range(ships.size()):
		var ship = ships[i]
		var ship_id = ship["id"]
		var texture_node = ship_textures_ui[i]
		if texture_node:
			var current_texture = _get_ship_texture_dynamic(ship_id, ship["upgrade_count"])
			texture_node.texture = current_texture

func _get_rank_color(rank: String) -> Color:
	match rank:
		"R": return Color.GRAY
		"SR": return Color.YELLOW
		"SSR": return Color.GOLD
		"LR": return Color.CYAN
		_: return Color.WHITE

# ================================
# ENHANCED UPGRADE SYSTEM
# ================================

func _upgrade_ship(ship_index: int, currency_type: String) -> bool:
	var ship = ships[ship_index]
	if ship["can_ascend"]:
		print("Cannot upgrade %s - ship is ready for ascension!" % ship["display_name"])
		return false

	if ship["current_evolution_stage"] == ship["max_evolution_stage"]:
		var last_threshold = ascension_thresholds[ship["id"]][-1]
		if ship["upgrade_count"] >= last_threshold + 5:
			print("Ship %s is at maximum level!" % ship["display_name"])
			return false

	var cost = UPGRADE_CRYSTAL_COST if currency_type == "crystals" else UPGRADE_COIN_COST
	if not _can_afford_upgrade(cost, currency_type):
		_show_insufficient_funds_message(ship["display_name"], currency_type)
		return false

	_deduct_currency(cost, currency_type)
	ship["upgrade_count"] += 1
	_apply_stat_boost(ship)
	_update_all_ship_textures()
	_check_ascension_eligibility(ship_index)
	power_up.play()
	if ship_index == selected_ship_index:
		update_ship_ui()
	return true

func _apply_stat_boost(ship: Dictionary) -> void:
	var base_speed_boost = 100
	var base_damage_boost = 5
	var stage_multiplier = 1.0 + (ship["current_evolution_stage"] * 0.2)
	ship["speed"] += int(base_speed_boost * stage_multiplier)
	ship["damage"] += int(base_damage_boost * stage_multiplier)

func _check_ascension_eligibility(ship_index: int) -> void:
	var ship = ships[ship_index]
	var ship_id = ship["id"]
	var thresholds = ascension_thresholds[ship_id]
	var current_stage = ship["current_evolution_stage"]
	if current_stage < thresholds.size() and ship["upgrade_count"] >= thresholds[current_stage]:
		ship["can_ascend"] = true
		print("ð %s is ready for ascension! ð" % ship["display_name"])
		if ship_index == selected_ship_index:
			update_ship_ui()

func _manual_ascend_ship(ship_index: int) -> bool:
	var ship = ships[ship_index]
	if not ship["can_ascend"]:
		print("Ship %s is not ready for ascension!" % ship["display_name"])
		return false
	if not _can_afford_upgrade(UPGRADE_ASCEND_COST, "ascend_crystals"):
		_show_insufficient_funds_message(ship["display_name"], "ascend_crystals")
		return false
	_deduct_currency(UPGRADE_ASCEND_COST, "ascend_crystals")
	var ship_id = ship["id"]
	var new_stage = ship["current_evolution_stage"] + 1
	ship["current_evolution_stage"] = new_stage
	ship["display_name"] = _get_current_evolution_name(ship_id, new_stage)
	var evolution_bonus = _get_evolution_bonus(ship_id, new_stage)
	ship["speed"] += evolution_bonus["speed"]
	ship["damage"] += evolution_bonus["damage"]
	if new_stage >= ship["max_evolution_stage"]:
		ship["rank"] = ship["final_rank"]
	ship["can_ascend"] = false
	_update_all_ship_textures()
	power_up.play()
	update_ship_ui()
	_show_evolution_message(ship)
	print("ð %s has evolved to %s! ð" % [ship["display_name"], _get_current_evolution_name(ship_id, new_stage)])
	return true

func _get_evolution_bonus(ship_id: String, evolution_stage: int) -> Dictionary:
	var base_bonuses = {
		"speed": 500,
		"damage": 15,
	}
	var rarity_multiplier = _get_rarity_multiplier(ship_id)
	var stage_multiplier = 1.0 + (evolution_stage * 0.5)
	return {
		"speed": int(base_bonuses["speed"] * rarity_multiplier * stage_multiplier),
		"damage": int(base_bonuses["damage"] * rarity_multiplier * stage_multiplier),
	}

func _get_rarity_multiplier(ship_id: String) -> float:
	var ship = _get_ship_by_id(ship_id)
	if not ship:
		return 1.0
	match ship["rank"]:
		"R": return 1.0
		"SR": return 1.3
		"SSR": return 1.6
		"LR": return 2.0
		_: return 1.0

func _get_ship_by_id(ship_id: String) -> Dictionary:
	var index = name_to_index.get(ship_id, -1)
	return ships[index] if index >= 0 else {}

func _show_evolution_message(ship: Dictionary) -> void:
	var message = "ð %s has evolved! ð" % ship["display_name"]
	print(message)

func _show_insufficient_funds_message(shipname: String, currency_type: String) -> void:
	var currency_name = "Crystals" if currency_type == "crystals" else "Coins" if currency_type == "coins" else "Ascend Crystals"
	var message = "Not enough %s to upgrade %s!" % [currency_name, shipname]
	warning.text = message
	warning_panel.show()
	await get_tree().create_timer(2.0).timeout
	warning_panel.hide()

# ================================
# OPTIMIZED SIGNAL HANDLERS
# ================================

func _on_ship1_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship1")

func _on_ship2_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship2")

func _on_ship3_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship3")

func _on_ship4_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship4")

func _on_ship5_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship5")

func _on_ship6_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship6")

func _on_ship7_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship7")

func _on_ship8_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship8")

func _handle_ship_selection(event: InputEvent, shipname: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_ship_by_name(shipname)

func _on_upgrade_crystals_pressed() -> void:
	if not _upgrade_ship(selected_ship_index, "crystals"):
		_show_upgrade_failed_feedback()

func _on_upgrade_coins_pressed() -> void:
	if not _upgrade_ship(selected_ship_index, "coins"):
		_show_upgrade_failed_feedback()

func _on_ascend_pressed() -> void:
	if not _manual_ascend_ship(selected_ship_index):
		_show_ascend_failed_feedback()

func _show_upgrade_failed_feedback() -> void:
	warning.text = "Upgrade failed"
	warning_panel.show()
	await get_tree().create_timer(2.0).timeout
	warning_panel.hide()

func _show_ascend_failed_feedback() -> void:
	pass

func _on_back_pressed() -> void:
	_save_ship_progress()
	_change_scene_optimized()

func _change_scene_optimized() -> void:
	if power_up and power_up.playing:
		power_up.stop()
	get_tree().change_scene_to_file(MAP)

# ================================
# AD MANAGEMENT SYSTEM
# ================================

func _on_ad_crystals_pressed() -> void:
	if not is_ad_loading:
		_show_rewarded_ad("crystals")

func _on_ad_coins_pressed() -> void:
	if not is_ad_loading:
		_show_rewarded_ad("coins")

func _show_rewarded_ad(reward_type: String) -> void:
	if not GameManager.admob:
		_grant_ad_reward(reward_type)
		return
	is_ad_loading = true
	await get_tree().create_timer(1.0).timeout
	_grant_ad_reward(reward_type)
	is_ad_loading = false

func _grant_ad_reward(reward_type: String) -> void:
	match reward_type:
		"crystals":
			crystal_count += AD_CRYSTAL_REWARD
			ascend_crystals_count += AD_ASCEND_REWARD
		"coins":
			coin_count += AD_COINS_REWARD
	_update_currency_display()
	_show_ad_reward_message(reward_type)

func _show_ad_reward_message(reward_type: String) -> void:
	var amount = AD_CRYSTAL_REWARD if reward_type == "crystals" else AD_COINS_REWARD
	var currency_name = "Crystals" if reward_type == "crystals" else "Coins"
	print("Received %d %s from ad!" % [amount, currency_name])

func _on_admob_interstitial_ad_loaded() -> void:
	is_ad_loading = false

func _on_admob_interstitial_ad_failed_to_load(error_code: int) -> void:
	is_ad_loading = false
	print("Ad failed to load with error code: %d" % error_code)

func _on_admob_interstitial_ad_dismissed() -> void:
	is_ad_loading = false

# ================================
# SAVE/LOAD SYSTEM
# ================================

func _save_ship_progress() -> void:
	var save_data = {
		"ships": ships,
		"crystal_count": crystal_count,
		"coin_count": coin_count,
		"ascend_crystals_count": ascend_crystals_count,
		"selected_ship_index": selected_ship_index
	}

func _load_saved_progress() -> void:
	pass

func _apply_saved_data(save_data: Dictionary) -> void:
	if save_data.has("ships"):
		ships = save_data["ships"]
	if save_data.has("crystal_count"):
		crystal_count = save_data["crystal_count"]
	if save_data.has("coin_count"):
		coin_count = save_data["coin_count"]
	if save_data.has("ascend_crystals_count"):
		ascend_crystals_count = save_data["ascend_crystals_count"]
	if save_data.has("selected_ship_index"):
		selected_ship_index = save_data["selected_ship_index"]

# ================================
# UTILITY FUNCTIONS
# ================================

func _is_ship_at_max_evolution(ship_index: int) -> bool:
	var ship = ships[ship_index]
	return ship["current_evolution_stage"] >= ship["max_evolution_stage"]

func _get_total_upgrade_cost(upgrades_needed: int, currency_type: String) -> int:
	var cost_per_upgrade = UPGRADE_CRYSTAL_COST if currency_type == "crystals" else UPGRADE_COIN_COST
	return cost_per_upgrade * upgrades_needed

func _get_ship_power_rating(ship_index: int) -> int:
	var ship = ships[ship_index]
	var base_power = ship["speed"] + (ship["damage"] * 10)
	var evolution_bonus = ship["current_evolution_stage"] * 1000
	return base_power + evolution_bonus

func _get_next_evolution_requirements(ship_index: int) -> Dictionary:
	var ship = ships[ship_index]
	var ship_id = ship["id"]
	var current_stage = ship["current_evolution_stage"]
	var thresholds = ascension_thresholds[ship_id]
	if current_stage >= thresholds.size():
		return {"can_evolve": false, "upgrades_needed": 0}
	var next_threshold = thresholds[current_stage]
	var upgrades_needed = max(0, next_threshold - ship["upgrade_count"])
	return {
		"can_evolve": true,
		"upgrades_needed": upgrades_needed,
		"threshold": next_threshold,
		"next_evolution_name": _get_current_evolution_name(ship_id, current_stage + 1)
	}

# ================================
# PERFORMANCE OPTIMIZATIONS
# ================================

func _optimize_texture_loading() -> void:
	var visible_ships = [selected_ship_index]
	for i in range(max(0, selected_ship_index - 2), min(ships.size(), selected_ship_index + 3)):
		if i != selected_ship_index:
			visible_ships.append(i)
	for ship_index in visible_ships:
		var ship = ships[ship_index]
		var ship_id = ship["id"]
		var texture_node = ship_textures_ui[ship_index]
		if texture_node:
			var current_texture = _get_ship_texture_dynamic(ship_id, ship["upgrade_count"])
			texture_node.texture = current_texture

func _batch_update_ui() -> void:
	_update_currency_display()
	update_ship_ui()
	_update_ascend_button_visibility()
	_update_upgrade_buttons_state()

# ================================
# DEBUG FUNCTIONS
# ================================

func _debug_print_ship_info(ship_index: int) -> void:
	if ship_index < 0 or ship_index >= ships.size():
		return
	var ship = ships[ship_index]
	print("=== SHIP DEBUG INFO ===")
	print("Name: %s" % ship["display_name"])
	print("ID: %s" % ship["id"])
	print("Rank: %s" % ship["rank"])
	print("Evolution Stage: %d/%d" % [ship["current_evolution_stage"], ship["max_evolution_stage"]])
	print("Upgrade Count: %d" % ship["upgrade_count"])
	print("Can Ascend: %s" % ship["can_ascend"])
	print("Stats - Speed: %d, Damage: %d" % [ship["speed"], ship["damage"]])
	print("Power Rating: %d" % _get_ship_power_rating(ship_index))
	print("=====================")

func _debug_grant_resources(crystal: int = 1000, coin: int = 50000, ascend_crystal: int = 500) -> void:
	crystal_count += crystal
	coin_count += coin
	ascend_crystals_count += ascend_crystal
	_update_currency_display()
	print("Granted %d crystals and %d coins and %d ascend crystals" % [crystal, coin, ascend_crystal])

# ================================
# INPUT HANDLING
# ================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				var ship_index = event.keycode - KEY_1
				if ship_index < ships.size():
					selected_ship_index = ship_index
					update_ship_ui()
			KEY_U:
				_upgrade_ship(selected_ship_index, "crystals")
			KEY_A:
				if ships[selected_ship_index]["can_ascend"]:
					_manual_ascend_ship(selected_ship_index)
			KEY_D:
				_debug_print_ship_info(selected_ship_index)
			KEY_R:
				_debug_grant_resources()

# ================================
# CLEANUP
# ================================

func _exit_tree() -> void:
	_save_ship_progress()
	if GameManager.admob:
		GameManager.admob.interstitial_ad_loaded.disconnect(_on_admob_interstitial_ad_loaded)
		GameManager.admob.interstitial_ad_failed_to_load.disconnect(_on_admob_interstitial_ad_failed_to_load)
		GameManager.admob.interstitial_ad_dismissed_full_screen_content.disconnect(_on_admob_interstitial_ad_dismissed)
