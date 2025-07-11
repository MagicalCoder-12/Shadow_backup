extends Control

const MAP = "res://Map/map.tscn"

# Ship data structure with upgrade textures for Ship1
var ships = [
	{
		"name": "Star Blaster",
		"base_texture": preload("res://Textures/player/Spaceships-13/spaceships/h-03.png"),
		"upgrade_texture_1": preload("res://Textures/player/Spaceships-13/spaceships/b-02.png"),
		"upgrade_texture_2": preload("res://Textures/player/Spaceships-13/spaceships/b-01.png"),
		"speed": 2000,
		"damage": 20,
		"health": 100,
		"upgrade_count": 0
	},
	{
		"name": "Cosmo Cruiser",
		"base_texture": preload("res://Textures/UI/Main_Menu/Ship_Main_Icon.png"),
		"speed": 1800,
		"damage": 30,
		"health": 150
	},
	{
		"name": "Nebula Fighter",
		"base_texture": preload("res://Textures/player/Fighter/Idle.png"),
		"speed": 1600,
		"damage": 40,
		"health": 200
	}
]

# Crystal cost per upgrade
const UPGRADE_COST: int = 50
# Crystal reward for watching interstitial ad
const AD_CRYSTAL_REWARD: int = 1000

# Node references
@onready var ship_name: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/ShipName
@onready var speed: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Speed
@onready var damage: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Damage
@onready var health: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Health
@onready var ship_1: Panel = $GridContainer/Ship1
@onready var ship_2: Panel = $GridContainer/Ship2
@onready var ship_3: Panel = $GridContainer/Ship3
@onready var s_01: TextureRect = $GridContainer/Ship1/S01
@onready var s_02: TextureRect = $GridContainer/Ship2/S02
@onready var s_03: TextureRect = $GridContainer/Ship3/S03
@onready var selected_ship: TextureRect = $SelectedShipDisplay/SelectedShip
@onready var crstal: TextureRect = $HeaderPanel/HBoxContainer/Crstal
@onready var crystals: Label = $HeaderPanel/HBoxContainer/Crystals


# Track current ship and crystal count
var current_ship_index: int = 0
var crystal_count: int = 1000  # Starting crystals (dummy value)
var is_ad_loading: bool = false

func _ready() -> void:
	# Connect the go_back_requested signal
	get_tree().get_root().connect("go_back_requested", Callable(self, "_on_back_pressed"))
	
	# Connect AdMob signals from GameManager
	if GameManager.admob:
		GameManager.admob.interstitial_ad_loaded.connect(_on_admob_interstitial_ad_loaded)
		GameManager.admob.interstitial_ad_failed_to_load.connect(_on_admob_interstitial_ad_failed_to_load)
		GameManager.admob.interstitial_ad_dismissed_full_screen_content.connect(_on_admob_interstitial_ad_dismissed)
	
	# Initialize crystal display
	crystals.text = "Crystals: %d" % crystal_count
	
	# Initialize with the first ship selected
	update_ship_display(0)


func _on_back_pressed() -> void:
	GameManager.change_scene(MAP)

func _on_upgrade_pressed() -> void:
	# Only allow upgrades for Ship1 (index 0)
	if current_ship_index == 0 and crystal_count >= UPGRADE_COST:
		# Deduct crystals
		crystal_count -= UPGRADE_COST
		crystals.text = "Crystals: %d" % crystal_count
		
		# Increment upgrade count and boost stats
		ships[0]["upgrade_count"] += 1
		ships[0]["speed"] += 100
		ships[0]["damage"] += 5
		ships[0]["health"] += 20
		
		# Update Ship1 texture based on upgrade count
		if ships[0]["upgrade_count"] == 3:
			ships[0]["base_texture"] = ships[0]["upgrade_texture_1"]
			s_01.texture = ships[0]["upgrade_texture_1"]
		elif ships[0]["upgrade_count"] == 6:
			ships[0]["base_texture"] = ships[0]["upgrade_texture_2"]
			s_01.texture = ships[0]["upgrade_texture_2"]
		
		# Update display if Ship1 is selected
		if current_ship_index == 0:
			update_ship_display(0)
	else:
		# Feedback for insufficient crystals
		print("Not enough crystals or wrong ship selected!")

func _on_ship1_selected(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		current_ship_index = 0
		update_ship_display(0)

func _on_ship2_selected(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		current_ship_index = 1
		update_ship_display(1)

func _on_ship3_selected(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		current_ship_index = 2
		update_ship_display(2)

func update_ship_display(ship_index: int) -> void:
	# Update the selected ship display and details
	current_ship_index = ship_index
	selected_ship.texture = ships[ship_index]["base_texture"]
	ship_name.text = ships[ship_index]["name"]
	speed.text = "Speed: %d" % ships[ship_index]["speed"]
	damage.text = "Damage: %d" % ships[ship_index]["damage"]
	health.text = "Health: %d" % ships[ship_index]["health"]

func _on_ads_pressed() -> void:
	if not GameManager.admob or not GameManager.is_initialized:
		print("Cannot show interstitial ad: AdMob not initialized!")
		return
	if is_ad_loading:
		print("Ad request ignored: Interstitial ad already loading!")
		return
	
	is_ad_loading = true
	if GameManager.admob.is_interstitial_ad_loaded():
		GameManager.admob.show_interstitial_ad()
		print("Showing interstitial ad for crystals right away! 💎")
	else:
		print("Loading interstitial ad for crystals...")
		GameManager.admob.load_interstitial_ad()

func _on_admob_interstitial_ad_loaded(_ad_id: String) -> void:
	if is_ad_loading and GameManager.is_initialized:
		GameManager.admob.show_interstitial_ad()
		print("Interstitial ad loaded and ready to shine!")

func _on_admob_interstitial_ad_failed_to_load(_ad_id: String, error_data: Variant) -> void:
	if is_ad_loading:
		var error_info = error_data.message if error_data and error_data.has("message") else str(error_data)
		var error_code = error_data.code if error_data and error_data.has("code") else "Unknown"
		print("Interstitial ad failed to load. Error: %s, Code: %s" % [error_info, error_code])
		is_ad_loading = false
		if GameManager.ad_retry_count < GameManager.max_ad_retries:
			GameManager.ad_retry_count += 1
			print("Retrying interstitial ad load, attempt %d/%d" % [GameManager.ad_retry_count, GameManager.max_ad_retries])
			await get_tree().create_timer(5.0).timeout
			if GameManager.is_initialized:
				GameManager.admob.load_interstitial_ad()
		else:
			print("Max retries reached for interstitial ad. No crystals this time! 😞")
			GameManager.ad_retry_count = 0
			is_ad_loading = false

func _on_admob_interstitial_ad_dismissed(_ad_id: String) -> void:
	if is_ad_loading:
		# Grant 1000 crystals when ad is fully watched
		crystal_count += AD_CRYSTAL_REWARD
		crystals.text = "Crystals: %d" % crystal_count
		print("Interstitial ad watched! Awarded %d crystals! 💎" % AD_CRYSTAL_REWARD)
		is_ad_loading = false
		# Preload next interstitial ad
		if GameManager.admob and GameManager.is_initialized:
			GameManager.admob.load_interstitial_ad()
			print("Preloading next interstitial ad for more crystal goodness.")


func _on_ships_pressed() -> void:
	pass # Replace with function body.


func _on_drones_pressed() -> void:
	pass # Replace with function body.


func _on_shop_pressed() -> void:
	pass # Replace with function body.


func _on_upgrade_money_pressed() -> void:
	pass # Replace with function body.


func _on_upgrade_crystals_pressed() -> void:
	pass # Replace with function body.
