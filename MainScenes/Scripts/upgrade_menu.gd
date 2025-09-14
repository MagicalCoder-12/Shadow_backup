extends Control

# ================================
# CONSTANTS & CONFIGURATION
# ================================
const MAP = "res://Map/map.tscn"
const AD_LIMIT_PER_HOUR = 10
const AD_COOLDOWN_SECONDS = 3600  # 1 hour in seconds

# ================================
# UI NODE REFERENCES
# ================================
@onready var crystals_display: Label = $Resources/HBoxContainer/Crystals_display
@onready var coins_display: Label = $Resources/Money/Coins_display
@onready var coins_amt: Label = $UI/HBoxContainer/Upgrade_coins/HBoxContainer/Coins_amt
@onready var crystal_amt: Label = $UI/HBoxContainer/Upgrade_Crystals/HBoxContainer/Crystal_amt
@onready var acend_amt: Label = $UI/Buy_Ascend/Ascend/Void_Shard
@onready var void_shards_display: Label = $HBoxContainer/Void_Shards_display
@onready var warning: Label = $UI/WarningPanel/Warning_Label
@onready var warning_panel: Panel = $UI/WarningPanel
@onready var selected_ship: TextureRect = $SelectedShipDisplay/SelectedShip
@onready var ship_name: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipName
@onready var damage: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/Damage
@onready var status_label: Label = $SelectedShipDisplay/MarginContainer/Panel/ShipDetails/Stats/StatusLabel
@onready var ascend: Button = $UI/Buy_Ascend/Ascend
@onready var upgrade_crystals_button: TextureButton = $UI/HBoxContainer/Upgrade_Crystals
@onready var upgrade_coins_button: TextureButton = $UI/HBoxContainer/Upgrade_coins
@onready var buy_button: Button = $UI/Buy_Ascend/Buy
@onready var selected: Button = $UI/Buy_Ascend/Selected
@onready var power_up: AudioStreamPlayer = $"Power-up"

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

# ================================
# GAME STATE VARIABLES
# ================================
var selected_ship_index: int = 0
var is_ad_loading: bool = false
var ad_usage_count: int = 0
var ad_last_used_time: int = 0
var ad_usage_timer: Timer

# Ship mapping & indexing
var name_to_index = {
	"Ship1/cache": 0,
	"Ship2/cache": 1,
	"Ship3/cache": 2,
	"Ship4/cache": 3,
	"Ship5/cache": 4,
	"Ship6/cache": 5,
	"Ship7/cache": 6,
	"Ship8/cache": 7
}

# ================================
# INITIALIZATION
# ================================
func _ready() -> void:
	# Connect to GameManager signals first
	_connect_gamemanager_signals()

	get_tree().get_root().connect("go_back_requested", Callable(self, "_on_back_pressed"))

	# Initialize ad usage tracking
	_initialize_ad_tracking()

	# Check if ships data is available
	if GameManager.ships.is_empty():
		push_warning("No ships data available in GameManager.ships. UI may not initialize correctly.")

	_initialize_ui()

	# Use the proper method to set reference
	if GameManager.has_method("set_upgrade_menu_ref"):
		GameManager.set_upgrade_menu_ref(self)

func _connect_gamemanager_signals() -> void:
	"""Connect to relevant GameManager signals"""
	if GameManager.has_signal("ad_reward_granted"):
		if not GameManager.ad_reward_granted.is_connected(_on_ad_reward_granted):
			GameManager.ad_reward_granted.connect(_on_ad_reward_granted)
	if GameManager.has_signal("currency_updated"):
		if not GameManager.currency_updated.is_connected(_on_currency_updated):
			GameManager.currency_updated.connect(_on_currency_updated)
	
	# Also connect to AdManager signals
	_connect_ad_signals()

func _connect_ad_signals() -> void:
	if GameManager.ad_manager:
		if GameManager.ad_manager.has_signal("ad_reward_granted"):
			if not GameManager.ad_manager.ad_reward_granted.is_connected(_on_ad_reward_granted):
				GameManager.ad_manager.ad_reward_granted.connect(_on_ad_reward_granted)
		if GameManager.ad_manager.has_signal("ad_failed_to_load"):
			if not GameManager.ad_manager.ad_failed_to_load.is_connected(_on_ad_failed_to_load):
				GameManager.ad_manager.ad_failed_to_load.connect(_on_ad_failed_to_load)

func _on_currency_updated(_currency_type: String, _new_amount: int) -> void:
	_update_currency_display()

func _initialize_ui() -> void:
	_update_currency_display()
	_update_all_ship_textures()

	# Find selected ship index using GameManager's player manager
	if GameManager.player_manager and GameManager.ships.size() > 0:
		for i in range(GameManager.ships.size()):
			if GameManager.ships[i]["id"] == GameManager.player_manager.selected_ship_id:
				selected_ship_index = i
				break

	update_ship_ui()

func _initialize_ad_tracking() -> void:
	ad_usage_timer = Timer.new()
	add_child(ad_usage_timer)
	ad_usage_timer.wait_time = 1.0  # Check every second
	ad_usage_timer.timeout.connect(_on_ad_timer_timeout)
	ad_usage_timer.start()
	
	# Load ad usage data from save if available
	_load_ad_usage_data()

func _load_ad_usage_data() -> void:
	if GameManager.save_manager:
		# Fixed: Access SaveManager properties directly instead of trying to use return value of load_progress()
		ad_usage_count = GameManager.save_manager.ad_usage_count
		ad_last_used_time = GameManager.save_manager.ad_last_used_time

func _save_ad_usage_data() -> void:
	# Save ad usage data to SaveManager and call save_progress()
	if GameManager.save_manager:
		GameManager.save_manager.ad_usage_count = ad_usage_count
		GameManager.save_manager.ad_last_used_time = ad_last_used_time
		GameManager.save_manager.save_progress()
	
func _on_ad_timer_timeout() -> void:
	var current_time = Time.get_unix_time_from_system() as int
	# Reset ad usage count if more than an hour has passed
	if current_time - ad_last_used_time >= AD_COOLDOWN_SECONDS:
		ad_usage_count = 0

func _can_show_rewarded_ad() -> bool:
	var current_time = Time.get_unix_time_from_system() as int
	# Reset count if cooldown period has passed
	if current_time - ad_last_used_time >= AD_COOLDOWN_SECONDS:
		ad_usage_count = 0
		return true
	
	# Check if we're within the limit
	return ad_usage_count < AD_LIMIT_PER_HOUR

func _record_ad_usage() -> void:
	ad_usage_count += 1
	ad_last_used_time = Time.get_unix_time_from_system() as int
	_save_ad_usage_data()

func _show_ad_limit_message() -> void:
	var message = "Ad limit reached! You can watch ads again in %d minutes." % _get_remaining_cooldown_minutes()
	warning.text = message
	warning_panel.show()
	
	# Update the currency display
	_update_currency_display()
	
	# Hide the message after a delay
	await get_tree().create_timer(3.0).timeout
	warning_panel.hide()

func _get_remaining_cooldown_minutes() -> int:
	var current_time = Time.get_unix_time_from_system() as int
	var elapsed_time = current_time - ad_last_used_time
	var remaining_time = max(0, AD_COOLDOWN_SECONDS - elapsed_time)
	return ceil(remaining_time / 60.0)

# ================================
# CURRENCY MANAGEMENT
# ================================
func _get_current_upgrade_costs() -> Dictionary:
	if GameManager.ships.is_empty() or selected_ship_index >= GameManager.ships.size():
		return {"crystal_cost": 50, "coin_cost": 250, "void_shard_cost": 100}

	var ship = GameManager.ships[selected_ship_index]
	if not ship is Dictionary:
		return {"crystal_cost": 50, "coin_cost": 250, "void_shard_cost": 100}

	var upgrade_count = ship.get("upgrade_count", 0)
	
	# Get base costs and scaling factors from config
	var base_crystal_cost = 50
	var base_coin_cost = 250
	var ascend_cost = 100
	
	# Changed: Use different scaling factors for each currency type
	var crystal_scaling_factor = 1.10
	var coin_scaling_factor = 1.25
	var ascend_scaling_factor = 1.05

	# Use ConfigLoader if available
	if is_instance_valid(ConfigLoader) and ConfigLoader.upgrade_settings:
		base_crystal_cost = ConfigLoader.upgrade_settings.get("upgrade_crystal_cost", 50)
		base_coin_cost = ConfigLoader.upgrade_settings.get("upgrade_coin_cost", 250)
		ascend_cost = ConfigLoader.upgrade_settings.get("upgrade_ascend_cost", 100)
		
		# Changed: Load different scaling factors if available in config
		crystal_scaling_factor = ConfigLoader.upgrade_settings.get("crystal_scaling_factor", 1.10)
		coin_scaling_factor = ConfigLoader.upgrade_settings.get("coin_scaling_factor", 1.25)
		ascend_scaling_factor = ConfigLoader.upgrade_settings.get("ascend_scaling_factor", 1.05)
	else:
		push_warning("ConfigLoader not available or upgrade_settings missing. Using default upgrade costs.")

	# Changed: Use different scaling factors for each currency type
	var crystal_cost = base_crystal_cost * pow(crystal_scaling_factor, float(upgrade_count))
	var coin_cost = base_coin_cost * pow(coin_scaling_factor, float(upgrade_count))
	var void_shard_cost = ascend_cost * pow(ascend_scaling_factor, float(upgrade_count))

	return {
		"crystal_cost": int(crystal_cost),
		"coin_cost": int(coin_cost),
		"void_shard_cost": int(void_shard_cost)
	}

func _format_number(num: int) -> String:
	if num >= 1000000000:
		return "%.1fB" % (num / 1000000000.0)
	elif num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _update_currency_display() -> void:
	if not crystals_display or not coins_display or not void_shards_display:
		push_error("One or more currency labels are null!")
		return

	var crystals_text := _format_number(GameManager.crystal_count)
	var coins_text := _format_number(GameManager.coin_count)
	var void_shards_text := _format_number(GameManager.void_shards_count)

	crystals_display.text = "Crystals: %s" % crystals_text
	coins_display.text = "Coins: %s" % coins_text
	void_shards_display.text = "Void Shards: %s" % void_shards_text

func _can_afford_upgrade(cost: int, currency_type: String) -> bool:
	return GameManager.can_afford(currency_type, cost)

func _deduct_currency(amount: int, currency_type: String) -> void:
	GameManager.deduct_currency(currency_type, amount)
	_update_currency_display()

# ================================
# SHIP SELECTION SYSTEM
# ================================
func update_ship_ui() -> void:
	if GameManager.ships.is_empty():
		push_warning("Ships array is empty. Cannot update UI yet.")
		return

	if not selected_ship or not ship_name or not damage:
		push_error("One or more UI elements are null!")
		return

	var ship = GameManager.ships[selected_ship_index]
	var current_texture = _get_ship_texture_dynamic(ship, ship["current_evolution_stage"])
	selected_ship.texture = current_texture

	var current_evolution_name = _get_current_evolution_name(ship["id"], ship["current_evolution_stage"])
	ship_name.text = current_evolution_name
	damage.text = "Damage: %d" % ship["damage"]

	var rank_color = _get_rank_color(ship["rank"])
	ship_name.modulate = rank_color

	if ship["unlocked"]:
		buy_button.hide()
		selected.show()
		var costs = _get_current_upgrade_costs()
		coins_amt.text = _format_number(costs["coin_cost"])
		crystal_amt.text = _format_number(costs["crystal_cost"])
		upgrade_coins_button.show()
		upgrade_crystals_button.show()
		selected_ship.modulate = Color.WHITE

		var status_text = ""
		if ship["can_ascend"]:
			status_text = "Ready to Ascend!"
		elif ship["current_evolution_stage"] == ship["max_evolution_stage"]:
			var last_threshold = GameManager.ASCENSION_THRESHOLDS[ship["id"]][-1]
			var additional_upgrades = ship["upgrade_count"] - last_threshold
			if additional_upgrades >= 5:
				status_text = "Max Level"
			else:
				status_text = "Max Ascension Reached! (+%d/5)" % additional_upgrades
		else:
			var next_requirements = _get_next_evolution_requirements(selected_ship_index)
			if next_requirements["can_evolve"]:
				status_text = "Upgrades to next ascension: %d" % next_requirements["upgrades_needed"]

		status_label.text = status_text
		_update_ascend_button_visibility()
		_update_upgrade_buttons_state()
	else:
		var cost = ship.get("purchase_cost", 0)
		buy_button.show()
		selected.hide()
		upgrade_coins_button.hide()
		upgrade_crystals_button.hide()
		if cost <= 0:
			buy_button.text = "Get Free Ship"
			status_label.text = "Free Ship - Unlock Now!"
		else:
			buy_button.text = "Buy for %d crystals" % cost
			status_label.text = "Locked - Cost: %d crystals" % cost
		selected_ship.modulate = Color.BLACK
		
		# Ensure ascend button is hidden for locked ships
		ascend.visible = false

func _update_ascend_button_visibility() -> void:
	var ship = GameManager.ships[selected_ship_index]
	var costs = _get_current_upgrade_costs()

	# Only show ascend button if ship is unlocked AND can ascend
	if ship["unlocked"] and ship["can_ascend"]:
		ascend.visible = true
		ascend.disabled = false
		var ship_id = ship["id"]
		var next_stage = ship["current_evolution_stage"] + 1
		var next_evolution_name = _get_current_evolution_name(ship_id, next_stage)
		ascend.text = "Ascend to %s" % next_evolution_name
		acend_amt.text = _format_number(costs["void_shard_cost"])
	else:
		ascend.visible = false

func _update_upgrade_buttons_state() -> void:
	var ship = GameManager.ships[selected_ship_index]
	var is_max_level = ship["current_evolution_stage"] == ship["max_evolution_stage"] and ship["upgrade_count"] >= GameManager.ASCENSION_THRESHOLDS[ship["id"]][-1] + 5

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

func select_ship_by_name(ship_node_name: String) -> void:
	if name_to_index.has(ship_node_name):
		selected_ship_index = name_to_index[ship_node_name]
		print("[DEBUG] Ship selected for viewing in upgrade menu: %s (index: %d)" % [ship_node_name, selected_ship_index])
		# Only update UI for preview - don't change the actual selected ship yet
		update_ship_ui()
	else:
		push_warning("Unknown ship node name: %s" % ship_node_name)

# ================================
# ENHANCED TEXTURE MANAGEMENT
# ================================
func _get_ship_texture_dynamic(ship: Dictionary, evolution_stage: int) -> Texture2D:
	if not ship.has("textures"):
		push_error("No textures found for ship: %s" % ship.get("display_name", "Unknown"))
		return null

	var textures = ship["textures"]
	if textures.is_empty():
		push_error("Textures dictionary is empty for ship: %s" % ship.get("display_name", "Unknown"))
		return null

	var texture_key = "base" if evolution_stage == 0 else "upgrade_%d" % evolution_stage
	var texture_path = textures.get(texture_key, textures.get("base", ""))

	if not texture_path:
		push_warning("Texture key %s not found for %s, using fallback" % [texture_key, ship.get("display_name", "Unknown")])
		return null

	return load(texture_path)

func _update_all_ship_textures() -> void:
	if ship_textures_ui.size() != GameManager.ships.size():
		push_warning("Mismatch: ship_textures_ui has %d elements, but ships has %d" %
			[ship_textures_ui.size(), GameManager.ships.size()])

	for i in range(min(GameManager.ships.size(), ship_textures_ui.size())):
		var ship = GameManager.ships[i]
		var texture_node = ship_textures_ui[i]

		if not texture_node:
			push_warning("Texture node at index %d is null!" % i)
			continue

		var current_texture = _get_ship_texture_dynamic(ship, ship["current_evolution_stage"])
		if current_texture:
			texture_node.texture = current_texture
			texture_node.modulate = Color.WHITE if ship["unlocked"] else Color.GRAY

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
	var ship = GameManager.ships[ship_index]
	var costs = _get_current_upgrade_costs()

	if not ship["unlocked"] or ship["can_ascend"]:
		return false

	if ship["current_evolution_stage"] == ship["max_evolution_stage"]:
		var last_threshold = GameManager.ASCENSION_THRESHOLDS[ship["id"]][-1]
		if ship["upgrade_count"] >= last_threshold + 5:
			return false

	var cost = costs["crystal_cost"] if currency_type == "crystals" else costs["coin_cost"]
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

	# Save progress after upgrade
	GameManager.save_manager.save_progress()
	return true

func _apply_stat_boost(ship: Dictionary) -> void:
	var base_damage_boost = 5
	var stage_multiplier = 1.0 + (ship["current_evolution_stage"] * 0.2)
	ship["damage"] += int(base_damage_boost * stage_multiplier)
	
	# Notify GameManager that ship stats have been updated
	GameManager.notify_ship_stats_updated(ship["id"], ship["damage"])

func _check_ascension_eligibility(ship_index: int) -> void:
	var ship = GameManager.ships[ship_index]
	var ship_id = ship["id"]
	var thresholds = GameManager.ASCENSION_THRESHOLDS[ship_id]
	var current_stage = ship["current_evolution_stage"]

	if current_stage < thresholds.size() and ship["upgrade_count"] >= thresholds[current_stage]:
		ship["can_ascend"] = true
		if ship_index == selected_ship_index:
			update_ship_ui()

func _manual_ascend_ship(ship_index: int) -> bool:
	var ship = GameManager.ships[ship_index]
	var costs = _get_current_upgrade_costs()

	if not ship["unlocked"] or not ship["can_ascend"]:
		return false

	if not _can_afford_upgrade(costs["void_shard_cost"], "void_shards"):
		_show_insufficient_funds_message(ship["display_name"], "void_shards")
		return false

	_deduct_currency(costs["void_shard_cost"], "void_shards")

	var ship_id = ship["id"]
	var new_stage = ship["current_evolution_stage"] + 1
	ship["current_evolution_stage"] = new_stage
	ship["display_name"] = _get_current_evolution_name(ship_id, new_stage)

	var evolution_bonus = _get_evolution_bonus(ship_id, new_stage)
	ship["damage"] += evolution_bonus["damage"]
	
	# Notify GameManager that ship stats have been updated
	GameManager.notify_ship_stats_updated(ship["id"], ship["damage"])

	if new_stage >= ship["max_evolution_stage"]:
		ship["rank"] = ship["final_rank"]

	ship["can_ascend"] = false
	_update_all_ship_textures()
	power_up.play()
	update_ship_ui()
	_show_evolution_message(ship)

	# Save progress after ascension
	GameManager.save_manager.save_progress()
	return true

func _get_evolution_bonus(ship_id: String, evolution_stage: int) -> Dictionary:
	var base_bonuses = {"damage": 15}
	var rarity_multiplier = _get_rarity_multiplier(ship_id)
	var stage_multiplier = 1.0 + (evolution_stage * 0.5)

	return {
		"damage": int(base_bonuses["damage"] * rarity_multiplier * stage_multiplier)
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
	for ship in GameManager.ships:
		if ship["id"] == ship_id:
			return ship
	return {}

func _show_evolution_message(ship: Dictionary) -> void:
	print("Ship %s has evolved!" % ship["display_name"])

func _show_insufficient_funds_message(shipname: String, currency_type: String) -> void:
	var currency_name = {"crystals": "Crystals", "coins": "Coins", "void_shards": "Void Shards"}.get(currency_type, "Unknown")
	var message = "Not enough %s to upgrade %s!" % [currency_name, shipname]
	warning.text = message
	warning_panel.show()
	await get_tree().create_timer(2.0).timeout
	warning_panel.hide()

# ================================
# OPTIMIZED SIGNAL HANDLERS
# ================================
func _on_ship1_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship1/cache")

func _on_ship2_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship2/cache")

func _on_ship3_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship3/cache")

func _on_ship4_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship4/cache")

func _on_ship5_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship5/cache")

func _on_ship6_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship6/cache")

func _on_ship7_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship7/cache")

func _on_ship8_selected(event: InputEvent) -> void:
	_handle_ship_selection(event, "Ship8/cache")

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

func _on_ad_reward_granted(ad_type: String) -> void:
	# Update UI when reward is granted through ads
	_update_currency_display()
	_show_ad_reward_message(ad_type)
	is_ad_loading = false
	
	# Record ad usage for crystals and coins
	if ad_type == "crystals" or ad_type == "coins":
		_record_ad_usage()

func _on_ad_failed_to_load(_ad_type: String, _error_data: Variant) -> void:
	# Handle ad failure
	is_ad_loading = false
	# UI can show an error message if needed

func _on_back_pressed() -> void:
	_save_ship_progress()
	_change_scene_optimized()

func _change_scene_optimized() -> void:
	if power_up and power_up.playing:
		power_up.stop()

	# Use GameManager's scene system
	GameManager.change_scene(MAP)

func _on_selected_pressed() -> void:
	var ship = GameManager.ships[selected_ship_index]
	if ship["unlocked"]:
	# Use GameManager's player manager to set selected ship
		GameManager.player_manager.selected_ship_id = ship["id"]
		print("[DEBUG] Confirmed ship selection: %s" % GameManager.player_manager.selected_ship_id)
		GameManager.save_manager.save_progress()
		print("Selected ship set to: %s" % GameManager.player_manager.selected_ship_id)
	else:
		print("Cannot select %s - ship is locked!" % ship["display_name"])

func _on_buy_pressed() -> void:
	var ship = GameManager.ships[selected_ship_index]
	if ship["unlocked"]:
		return

	# Handle free ships vs paid ships
	var cost = ship.get("purchase_cost", 0)
	
	# If cost is 0 or not defined, unlock the ship immediately without deducting currency
	if cost <= 0:
		ship["unlocked"] = true
		GameManager.save_manager.save_progress()
		_update_all_ship_textures()
		update_ship_ui()
		_update_currency_display()
		return
	
	# For paid ships, check if player can afford and deduct currency
	if GameManager.can_afford("crystals", cost):
		GameManager.deduct_currency("crystals", cost)
		ship["unlocked"] = true
		GameManager.save_manager.save_progress()
		_update_all_ship_textures()
		update_ship_ui()
		_update_currency_display()
	else:
		_show_insufficient_funds_message(ship["display_name"], "crystals")

# ================================
# AD MANAGEMENT SYSTEM
# ================================
func _on_ad_crystals_pressed() -> void:
	if not is_ad_loading:
		# Check ad limit before showing ad
		if _can_show_rewarded_ad():
			_show_rewarded_ad("crystals")
		else:
			_show_ad_limit_message()

func _on_ad_coins_pressed() -> void:
	if not is_ad_loading:
		# Check ad limit before showing ad
		if _can_show_rewarded_ad():
			_show_rewarded_ad("coins")
		else:
			_show_ad_limit_message()

func _show_rewarded_ad(reward_type: String) -> void:
	# Use GameManager's ad system
	if GameManager.ad_manager and GameManager.ad_manager.is_initialized:
		is_ad_loading = true
		GameManager.ad_manager.request_reward_ad(reward_type)
	else:
		# If ads aren't available, grant reward directly and update UI
		_grant_ad_reward(reward_type)
		_update_currency_display()
		_show_ad_reward_message(reward_type)

func _grant_ad_reward(reward_type: String) -> void:
	var ad_rewards = {}
	if is_instance_valid(ConfigLoader) and ConfigLoader.upgrade_settings:
		ad_rewards = ConfigLoader.upgrade_settings
	else:
		push_warning("ConfigLoader not available. Using default ad rewards.")
		# Default values if config not found
		ad_rewards = {
			"ad_crystal_reward": 10,
			"ad_ascend_reward": 10,
			"ad_coins_reward": 1000
		}
	
	match reward_type:
		"crystals":
			var crystal_reward = ad_rewards.get("ad_crystal_reward", 20)
			var void_shard_reward = ad_rewards.get("ad_ascend_reward", 15)
			GameManager.add_currency("crystals", crystal_reward)
			GameManager.add_currency("void_shards", void_shard_reward)
			_show_ad_reward_message("crystals")
		"coins":
			var coins_reward = ad_rewards.get("ad_coins_reward", 1000)
			GameManager.add_currency("coins", coins_reward)
			_show_ad_reward_message("coins")
		_:
			push_warning("Unknown reward type: %s" % reward_type)
			_show_ad_reward_message(reward_type)

func _show_ad_reward_message(reward_type: String) -> void:
	var ad_rewards = {}
	if is_instance_valid(ConfigLoader) and ConfigLoader.upgrade_settings:
		ad_rewards = ConfigLoader.upgrade_settings
	else:
		# Default values if config not found
		ad_rewards = {
			"ad_crystal_reward": 20,
			"ad_ascend_reward": 15,
			"ad_coins_reward": 1000
		}
	
	var message = ""
	match reward_type:
		"crystals":
			var crystal_reward = ad_rewards.get("ad_crystal_reward", 20)
			var void_shard_reward = ad_rewards.get("ad_ascend_reward", 15)
			message = "Rewarded: %d Crystals and %d Void Shards!" % [crystal_reward, void_shard_reward]
		"coins":
			var coins_reward = ad_rewards.get("ad_coins_reward", 1000)
			message = "Rewarded: %d Coins!" % coins_reward
		_:
			message = "Reward granted!"
	
	# Display the message to the user
	warning.text = message
	warning_panel.show()
	
	# Update the currency display
	_update_currency_display()
	
	# Hide the message after a delay
	await get_tree().create_timer(2.0).timeout
	warning_panel.hide()

# ================================
# SAVE/LOAD SYSTEM
# ================================
func _save_ship_progress() -> void:
	GameManager.save_manager.save_progress()

# ================================
# UTILITY FUNCTIONS
# ================================
func _get_current_evolution_name(ship_id: String, stage: int) -> String:
	var evolution_names = {}
	if is_instance_valid(ConfigLoader):
		evolution_names = ConfigLoader.upgrade_settings.get("ship_evolution_names", {}).get(ship_id, null)
	else:
		push_warning("ConfigLoader not available. Using default evolution names.")

	# Fallback evolution names
	var fallback_names = {
		"Ship1": ["NoctiSol", "Solstice", "Eclipse Sovereign"],
		"Ship2": ["Aether Strike", "Void Piercer", "Quantum Saber"],
		"Ship3": ["Astra Blade", "Astra Striker", "Astra Prime"],
		"Ship4": ["Phantom Drake", "Spectral Wyrm", "Ethereal Leviathan", "Void Dragon", "Cosmic Serpent"],
		"Ship5": ["Umbra Wraith", "Shadow Reaper", "Darkness Incarnate", "Void Phantom", "Abyssal Terror", "Nightmare Sovereign", "Obsidian Specter", "Eclipse Revenant", "Nether Shade", "Celestial Wraith"],
		"Ship6": ["Void Howler", "Cosmic Screamer", "Stellar Devourer", "Galactic Destroyer", "Nova Reaver", "Quantum Predator", "Singularity Hunter", "Infinity Ravager"],
		"Ship7": ["Tenebris Fang", "Shadow Blade", "Darkness Cutter", "Void Ripper", "Abyssal Slicer", "Nightmare Edge", "Phantom Cleaver", "Spectral Razor", "Ethereal Scythe"],
		"Ship8": ["Oblivion Viper", "Void Serpent", "Cosmic Cobra", "Stellar Python", "Galactic Anaconda", "Universal Leviathan", "Infinity Wyrm"]
	}
	evolution_names = fallback_names.get(ship_id, null)

	if evolution_names == null:
		return "Unknown"
	return evolution_names[min(stage, evolution_names.size() - 1)]

func _get_next_evolution_requirements(ship_index: int) -> Dictionary:
	var ship = GameManager.ships[ship_index]
	var ship_id = ship["id"]
	var thresholds = GameManager.ASCENSION_THRESHOLDS.get(ship_id, [])
	var current_stage = ship["current_evolution_stage"]

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
	for i in range(max(0, selected_ship_index - 2), min(GameManager.ships.size(), selected_ship_index + 3)):
		if i != selected_ship_index:
			visible_ships.append(i)

	for ship_index in visible_ships:
		var ship = GameManager.ships[ship_index]
		var texture_node = ship_textures_ui[ship_index]
		if texture_node:
			var current_texture = _get_ship_texture_dynamic(ship, ship["current_evolution_stage"])
			if current_texture:
				texture_node.texture = current_texture

func _debug_grant_resources(crystal: int = 1000000, coin: int = 500000, void_shard: int = 500000) -> void:
	GameManager.add_currency("crystals", crystal)
	GameManager.add_currency("coins", coin)
	GameManager.add_currency("void_shards", void_shard)
	_update_currency_display()

# ================================
# INPUT HANDLING
# ================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				var ship_index = event.keycode - KEY_1
				if ship_index < GameManager.ships.size():
					selected_ship_index = ship_index
					update_ship_ui()
			KEY_U:
				_upgrade_ship(selected_ship_index, "crystals")
			KEY_A:
				if GameManager.ships[selected_ship_index]["can_ascend"]:
					_manual_ascend_ship(selected_ship_index)
			KEY_R:
				_debug_grant_resources()

# ================================
# CLEANUP
# ================================
func _exit_tree() -> void:
	_save_ship_progress()
