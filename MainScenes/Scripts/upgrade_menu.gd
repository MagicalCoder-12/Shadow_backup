extends Control

# ================================
# CONSTANTS & CONFIGURATION
# ================================

const MAP = "res://Map/map.tscn"

# Upgrade costs
const UPGRADE_CRYSTAL_COST: int = 50
const UPGRADE_COIN_COST: int = 500

# Ad rewards
const AD_CRYSTAL_REWARD: int = 1000
const AD_COINS_REWARD: int = 1000

# Upgrade thresholds for texture changes
const FIRST_UPGRADE_THRESHOLD: int = 3
const SECOND_UPGRADE_THRESHOLD: int = 6

# ================================
# SHIP DATA CONFIGURATION
# ================================

# Complete ship database with all stats and evolution data
var ships = [
	{
		"id": "Ship1",
		"display_name": "NoctiSol",
		"rank": "C",
		"evolves_to": "Solstice",
		"final_rank": "SSR+",
		"speed": 2000,
		"damage": 20,
		"health": 100,
		"upgrade_count": 0,
		"can_evolve": true,
		"description": "A mysterious vessel that harnesses both shadow and light"
	},
	{
		"id": "Ship2",
		"display_name": "Aether Strike",
		"rank": "C",
		"speed": 1800,
		"damage": 25,
		"health": 120,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Swift striker that cuts through the void"
	},
	{
		"id": "Ship3",
		"display_name": "Phantom Drake",
		"rank": "R",
		"speed": 1900,
		"damage": 30,
		"health": 150,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Elusive predator with spectral capabilities"
	},
	{
		"id": "Ship4",
		"display_name": "Umbra Wraith",
		"rank": "UR",
		"speed": 2100,
		"damage": 40,
		"health": 180,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Shadow-born destroyer with ethereal powers"
	},
	{
		"id": "Ship5",
		"display_name": "Void Howler",
		"rank": "UR",
		"speed": 2200,
		"damage": 45,
		"health": 200,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Unleashes the fury of the cosmic void"
	},
	{
		"id": "Ship6",
		"display_name": "Tenebris Fang",
		"rank": "SR",
		"speed": 2300,
		"damage": 50,
		"health": 220,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Pierces through darkness with deadly precision"
	},
	{
		"id": "Ship7",
		"display_name": "Oblivion Viper",
		"rank": "SSR",
		"speed": 2400,
		"damage": 55,
		"health": 240,
		"upgrade_count": 0,
		"can_evolve": false,
		"description": "Apex predator of the cosmic battlefield"
	}
]

# ================================
# TEXTURE RESOURCES
# ================================

# Comprehensive texture dictionary for all ships and their upgrade states
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
		"base": preload("res://Textures/player/Example_ships/10B.png"),
		"upgrade_1": preload("res://Textures/player/Example_ships/13B.png"),
		"upgrade_2": preload("res://Textures/player/Example_ships/rect1.png"),
		"upgrade_3": preload("res://Textures/player/Example_ships/rect3.png"),
		"upgrade_4": preload("res://Textures/player/Example_ships/rect2.png")
	},
	"Ship4": {
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
	"Ship5": {
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
	"Ship6": {
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
	"Ship7": {
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

# Maps ship node names to their array indices for quick lookup
var name_to_index = {
	"Ship1": 0,
	"Ship2": 1,
	"Ship3": 2,
	"Ship4": 3,
	"Ship5": 4,
	"Ship6": 5,
	"Ship7": 6
}

# ================================
# UI NODE REFERENCES
# ================================

# Header UI elements
@onready var crystals: Label = $Header_panel/VBoxContainer/HBoxContainer/Crystals
@onready var coins: Label = $Header_panel/VBoxContainer/Money/Coins

# Selected ship display elements
@onready var selected_ship: TextureRect = $SelectedShipDisplay/SelectedShip
@onready var ship_name: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/ShipName
@onready var speed: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Speed
@onready var damage: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Damage
@onready var health: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Health

# Ship grid texture references
@onready var ship_textures_ui = [
	$ScrollContainer/GridContainer/Ship1/S01,
	$ScrollContainer/GridContainer/Ship2/S02,
	$ScrollContainer/GridContainer/Ship3/S03,
	$ScrollContainer/GridContainer/Ship4/S04,
	$ScrollContainer/GridContainer/Ship5/S05,
	$ScrollContainer/GridContainer/Ship6/S06,
	$ScrollContainer/GridContainer/Ship7/S07
]

# Audio
@onready var power_up: AudioStreamPlayer = $"Power-up"

# ================================
# GAME STATE VARIABLES
# ================================

var selected_ship_index: int = 0      # Currently selected ship
var crystal_count: int = 1000         # Player's crystal currency
var coin_count: int = 5000            # Player's coin currency
var is_ad_loading: bool = false       # Ad loading state tracker

# ================================
# INITIALIZATION
# ================================

func _ready() -> void:
	# Connect back button signal
	get_tree().get_root().connect("go_back_requested", Callable(self, "_on_back_pressed"))
	
	# Setup AdMob connections if available
	_setup_admob_connections()
	
	# Initialize UI displays
	_initialize_ui()
	
	# Load saved ship data if available
	_load_ship_progress()

func _setup_admob_connections() -> void:
	"""Connect AdMob signals for ad management"""
	if GameManager.admob:
		GameManager.admob.interstitial_ad_loaded.connect(_on_admob_interstitial_ad_loaded)
		GameManager.admob.interstitial_ad_failed_to_load.connect(_on_admob_interstitial_ad_failed_to_load)
		GameManager.admob.interstitial_ad_dismissed_full_screen_content.connect(_on_admob_interstitial_ad_dismissed)

func _initialize_ui() -> void:
	"""Initialize all UI elements with current game state"""
	_update_currency_display()
	_update_all_ship_textures()
	update_ship_ui()

func _load_ship_progress() -> void:
	"""Load ship upgrade progress from save data (placeholder for future implementation)"""
	# TODO: Implement save/load system
	pass

# ================================
# CURRENCY MANAGEMENT
# ================================

func _update_currency_display() -> void:
	"""Update the currency display in the header"""
	crystals.text = "Crystals: %d" % crystal_count
	coins.text = "Coins: %d" % coin_count

func _can_afford_upgrade(cost: int, currency_type: String) -> bool:
	"""Check if player can afford an upgrade"""
	match currency_type:
		"crystals":
			return crystal_count >= cost
		"coins":
			return coin_count >= cost
		_:
			return false

func _deduct_currency(amount: int, currency_type: String) -> void:
	"""Deduct currency and update display"""
	match currency_type:
		"crystals":
			crystal_count -= amount
		"coins":
			coin_count -= amount
	_update_currency_display()

# ================================
# SHIP SELECTION SYSTEM
# ================================

func update_ship_ui() -> void:
	"""Update the selected ship display with current ship data"""
	var ship = ships[selected_ship_index]
	var ship_id = ship["id"]
	
	# Update ship texture based on upgrade level
	var current_texture = _get_ship_texture(ship_id, ship["upgrade_count"])
	selected_ship.texture = current_texture
	
	# Update ship information
	ship_name.text = ship["display_name"]
	speed.text = "Speed: %d" % ship["speed"]
	damage.text = "Damage: %d" % ship["damage"]
	health.text = "Health: %d" % ship["health"]
	
	# Add rank indicator
	var rank_color = _get_rank_color(ship["rank"])
	ship_name.modulate = rank_color

func select_ship_by_name(ship_node_name: String) -> void:
	"""Select a ship by its node name"""
	if name_to_index.has(ship_node_name):
		selected_ship_index = name_to_index[ship_node_name]
		update_ship_ui()
		_play_selection_sound()
	else:
		push_warning("Unknown ship node name: %s" % ship_node_name)

func _play_selection_sound() -> void:
	"""Play selection sound effect"""
	# TODO: Add selection sound effect
	pass

# ================================
# TEXTURE MANAGEMENT
# ================================

func _get_ship_texture(ship_id: String, upgrade_count: int) -> Texture2D:
	"""Get the appropriate texture for a ship based on upgrade count"""
	var textures = ship_textures[ship_id]
	
	# Determine which texture to use based on upgrade count
	if upgrade_count >= SECOND_UPGRADE_THRESHOLD:
		return textures.get("upgrade_2", textures["base"])
	elif upgrade_count >= FIRST_UPGRADE_THRESHOLD:
		return textures.get("upgrade_1", textures["base"])
	else:
		return textures["base"]

func _update_all_ship_textures() -> void:
	"""Update all ship textures in the grid based on their upgrade levels"""
	for i in range(ships.size()):
		var ship = ships[i]
		var ship_id = ship["id"]
		var texture_node = ship_textures_ui[i]
		
		if texture_node:
			var current_texture = _get_ship_texture(ship_id, ship["upgrade_count"])
			texture_node.texture = current_texture

func _get_rank_color(rank: String) -> Color:
	"""Get color associated with ship rank"""
	match rank:
		"C":
			return Color.GRAY
		"R":
			return Color.BLUE
		"SR":
			return Color.PURPLE
		"UR":
			return Color.ORANGE
		"SSR":
			return Color.GOLD
		"SSR+":
			return Color.CYAN
		_:
			return Color.WHITE

# ================================
# UPGRADE SYSTEM
# ================================

func _upgrade_ship(ship_index: int, currency_type: String) -> bool:
	"""Upgrade a ship with specified currency type"""
	var ship = ships[ship_index]
	var cost = UPGRADE_CRYSTAL_COST if currency_type == "crystals" else UPGRADE_COIN_COST
	
	if not _can_afford_upgrade(cost, currency_type):
		_show_insufficient_funds_message(ship["display_name"], currency_type)
		return false
	
	# Deduct currency
	_deduct_currency(cost, currency_type)
	
	# Apply upgrade
	ship["upgrade_count"] += 1
	_apply_stat_boost(ship)
	
	# Update textures
	_update_all_ship_textures()
	
	# Handle special evolutions
	_check_evolution(ship_index)
	
	# Play upgrade sound
	power_up.play()
	
	# Update UI if this is the selected ship
	if ship_index == selected_ship_index:
		update_ship_ui()
	
	return true

func _apply_stat_boost(ship: Dictionary) -> void:
	"""Apply stat increases to a ship"""
	ship["speed"] += 100
	ship["damage"] += 5
	ship["health"] += 20

func _check_evolution(ship_index: int) -> void:
	"""Check if ship should evolve based on upgrade count"""
	var ship = ships[ship_index]
	
	# Special evolution for NoctiSol at upgrade 6
	if ship["id"] == "Ship1" and ship["upgrade_count"] == SECOND_UPGRADE_THRESHOLD:
		evolve_noctisol()

func _show_insufficient_funds_message(ships_name: String, currency_type: String) -> void:
	"""Show message when player cannot afford upgrade"""
	var currency_name = currency_type.capitalize()
	print("Not enough %s to upgrade %s!" % [currency_name, ships_name])
	# TODO: Add UI notification system

# ================================
# SHIP EVOLUTION SYSTEM
# ================================

func evolve_noctisol() -> void:
	"""Handle NoctiSol evolution to Solstice"""
	var ship = ships[0]  # NoctiSol is always the first ship
	
	if ship.has("evolves_to"):
		ship["display_name"] = ship["evolves_to"]
		ship["rank"] = ship["final_rank"]
		
		# Apply evolution bonus stats
		ship["speed"] += 500
		ship["damage"] += 25
		ship["health"] += 100
		
		update_ship_ui()
		_show_evolution_message(ship["evolves_to"])

func _show_evolution_message(evolved_name: String) -> void:
	"""Show evolution celebration message"""
	print("%s evolved! 🌟" % evolved_name)
	# TODO: Add evolution animation and UI celebration

# ================================
# SHIP SELECTION INPUT HANDLERS
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

func _handle_ship_selection(event: InputEvent, Ship_name: String) -> void:
	"""Generic handler for ship selection input"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_ship_by_name(Ship_name)

# ================================
# UPGRADE BUTTON HANDLERS
# ================================

func _on_upgrade_crystals_pressed() -> void:
	"""Handle crystal upgrade button press"""
	_upgrade_ship(selected_ship_index, "crystals")

func _on_upgrade_money_pressed() -> void:
	"""Handle coin upgrade button press"""
	_upgrade_ship(selected_ship_index, "coins")

# ================================
# AD SYSTEM INTEGRATION
# ================================

func _on_ads_pressed() -> void:
	"""Handle ad button press for free currency"""
	if not _is_admob_ready():
		return
	
	if is_ad_loading:
		print("Ad request ignored: Already loading!")
		return
	
	is_ad_loading = true
	
	if GameManager.admob.is_interstitial_ad_loaded():
		GameManager.admob.show_interstitial_ad()
		print("Showing interstitial ad immediately! 💎")
	else:
		print("Loading interstitial ad...")
		GameManager.admob.load_interstitial_ad()

func _is_admob_ready() -> bool:
	"""Check if AdMob is properly initialized"""
	if not GameManager.admob or not GameManager.is_initialized:
		print("Cannot show ad: AdMob not initialized!")
		return false
	return true

# ================================
# ADMOB EVENT HANDLERS
# ================================

func _on_admob_interstitial_ad_loaded(_ad_id: String) -> void:
	"""Handle successful ad loading"""
	if is_ad_loading and GameManager.is_initialized:
		GameManager.admob.show_interstitial_ad()
		print("Ad loaded and showing!")

func _on_admob_interstitial_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	"""Handle ad loading failure with retry logic"""
	if not is_ad_loading:
		return
	
	var error_info = error_data.message if error_data and error_data.has("message") else str(error_data)
	var error_code = error_data.code if error_data and error_data.has("code") else "Unknown"
	print("Ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
	
	_handle_ad_retry()

func _handle_ad_retry() -> void:
	"""Handle ad retry logic"""
	is_ad_loading = false
	
	if GameManager.ad_retry_count < GameManager.max_ad_retries:
		GameManager.ad_retry_count += 1
		print("Retrying ad load, attempt %d/%d" % [GameManager.ad_retry_count, GameManager.max_ad_retries])
		
		await get_tree().create_timer(5.0).timeout
		
		if GameManager.is_initialized:
			GameManager.admob.load_interstitial_ad()
			is_ad_loading = true
	else:
		print("Max retries reached. No rewards this time! 😞")
		GameManager.ad_retry_count = 0

func _on_admob_interstitial_ad_dismissed(_ad_id: String) -> void:
	"""Handle successful ad completion and reward distribution"""
	if not is_ad_loading:
		return
	
	# Grant rewards
	crystal_count += AD_CRYSTAL_REWARD
	coin_count += AD_COINS_REWARD
	
	# Update UI
	_update_currency_display()
	
	# Play reward sound
	power_up.play()
	
	# Show reward message
	print("Ad completed! Awarded %d crystals and %d coins! 💎💰" % [AD_CRYSTAL_REWARD, AD_COINS_REWARD])
	
	# Reset ad state
	is_ad_loading = false
	
	# Preload next ad
	_preload_next_ad()

func _preload_next_ad() -> void:
	"""Preload the next interstitial ad"""
	if GameManager.admob and GameManager.is_initialized:
		GameManager.admob.load_interstitial_ad()
		print("Preloading next ad...")

# ================================
# NAVIGATION HANDLERS
# ================================

func _on_back_pressed() -> void:
	"""Handle back button press"""
	GameManager.change_scene(MAP)

func _on_ships_pressed() -> void:
	"""Handle ships tab press"""
	# Already on ships tab - no action needed
	pass

func _on_drones_pressed() -> void:
	"""Handle drones tab press"""
	# TODO: Implement drones functionality
	print("Drones feature coming soon!")

func _on_shop_pressed() -> void:
	"""Handle shop tab press"""
	# TODO: Implement shop functionality
	print("Shop feature coming soon!")
