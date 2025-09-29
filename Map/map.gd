extends Control

@onready var level_buttons: Node2D = $LevelButtons

const Start_screen = "res://MainScenes/start_menu.tscn"
const Shop = "res://MainScenes/upgrade_menu.tscn"

# Configuration for world-level format
@export var levels_per_world: int = 10

# Called when the node enters the scene tree
func _ready():
	# Hide stars immediately to prevent flickering during transition
	hide_all_stars()
	
	# Connect to prepare_map_scene signal to update stars before scene transition
	if GameManager.has_signal("prepare_map_scene"):
		GameManager.prepare_map_scene.connect(_on_prepare_map_scene)
	
	# Wait until the scene is fully ready (fixes transition issues)
	call_deferred("_initialize_level_buttons")

	# Show banner ad only on map scene
	if GameManager and GameManager.ad_manager:
		# Add a small delay before showing banner to prevent conflicts
		await get_tree().create_timer(1.0).timeout
		# Check if we're still in the map scene and no ad is showing
		if is_inside_tree() and GameManager.ad_manager.is_initialized and not GameManager.ad_manager.is_ad_showing:
			GameManager.ad_manager.show_banner_ad()

	# Connect to level_unlocked signal to update buttons dynamically
	GameManager.level_unlocked.connect(_on_level_unlocked)

	# Connect to level_star_earned signal to update stars
	GameManager.level_star_earned.connect(_on_level_star_earned)

	get_tree().get_root().connect("go_back_requested", _on_back_pressed)

# Hide banner ad when leaving the map scene
func _exit_tree() -> void:
	if GameManager and GameManager.ad_manager:
		GameManager.ad_manager.hide_banner_ad()

# Hide all stars immediately to prevent flickering during transition
func hide_all_stars():
	var buttons = level_buttons.get_children()
	for i in range(buttons.size()):
		var button = buttons[i]
		var star = button.get_node_or_null("Star")
		if star:
			star.hide()

# Update stars before scene transition
func _on_prepare_map_scene():
	update_stars()

# Handles all button initialization
func _initialize_level_buttons():
	# Debug check with fallback
	if level_buttons == null:
		level_buttons = get_node_or_null("LevelButtons")
		if level_buttons == null:
			return
	
	# Get all buttons with null check
	var buttons = level_buttons.get_children()
	if buttons.is_empty():
		return
	
	# Initialize each button with full safety checks
	for i in range(buttons.size()):
		var button = buttons[i]
		
		# 1. Ensure button is visible and interactive
		button.show()
		button.set_process(true)
		
		# 2. Set level number with world-level format
		if button.has_method("set_level"):
			button.call("set_level", i + 1, levels_per_world)
		
		# 3. Set locked state based on GameManager
		var is_unlocked = GameManager.is_level_unlocked(i + 1)
		button.locked = not is_unlocked # Set custom locked property
		
		# 4. Connect signals safely
		if button.has_signal("level_selected"):
			if not button.is_connected("level_selected", Callable(GameManager, "_on_level_selected")):
				var success = button.connect(
					"level_selected",
					Callable(GameManager, "_on_level_selected"),
					CONNECT_DEFERRED | CONNECT_PERSIST
				)
				
				if success != OK:
					push_error("Failed to connect signal 'level_selected' for button: ", button.name)
		
		# 5. Force position update (fixes rendering glitches)
		button.position = button.position # Triggers transform update
	
	# Final visibility enforcement
	level_buttons.show()
	level_buttons.z_index = 1

	# Update stars after buttons are initialized to ensure they reflect the correct state
	update_stars()

# Update button states when a new level is unlocked
func _on_level_unlocked(_new_level: int):
	update_level_buttons()

# Function to refresh button states
func update_level_buttons():
	var buttons = level_buttons.get_children()
	for i in range(buttons.size()):
		var button = buttons[i]
		var is_unlocked = GameManager.is_level_unlocked(i + 1)
		button.locked = not is_unlocked # Update locked property

# Update stars visibility on level buttons
func update_stars():
	var buttons = level_buttons.get_children()
	for i in range(buttons.size()):
		var button = buttons[i]
		var level_num = i + 1
		var star = button.get_node_or_null("Star")
		
		if star:
			if GameManager.is_level_completed(level_num):
				# Show the star if the level is completed
				star.show()
			else:
				# Hide the star if the level is not completed
				star.hide()

# Called when a level is completed and a star is earned
func _on_level_star_earned():
	update_stars()

func _on_back_pressed() -> void:
	GameManager.change_scene(Start_screen)

func _on_shop_pressed() -> void:
	GameManager.change_scene(Shop)
