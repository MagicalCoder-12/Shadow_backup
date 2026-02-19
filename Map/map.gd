extends Control

@onready var level_buttons: Node2D = $LevelButtons
@onready var canvaslayer: CanvasLayer = $CanvasLayer
@onready var difficulty_selection: Control = $CanvasLayer/DifficultySelection

const Start_screen = "res://MainScenes/start_menu.tscn"
const Shop = "res://MainScenes/upgrade_menu.tscn"

# Configuration for world-level format
@export var levels_per_world: int = 10

# Called when the node enters the scene tree
func _ready():
	# Hide stars immediately to prevent flickering during transition
	hide_all_stars()
	
	# Hide difficulty selection panel initially
	if difficulty_selection:
		difficulty_selection.hide()
	
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
		
		# Hide all star types
		var star_bronze = button.get_node_or_null("Star_bronze")
		var star_silver = button.get_node_or_null("Star_silver")
		var star_gold = button.get_node_or_null("Star_gold")
		
		if star_bronze:
			star_bronze.hide()
		if star_silver:
			star_silver.hide()
		if star_gold:
			star_gold.hide()
		
		# Also hide fallback star for backward compatibility
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
			# Connect to GameManager
			if not button.is_connected("level_selected", Callable(GameManager, "_on_level_selected")):
				var success = button.connect(
					"level_selected",
					Callable(GameManager, "_on_level_selected"),
					CONNECT_DEFERRED | CONNECT_PERSIST
				)
				
				if success != OK:
					push_error("Failed to connect signal 'level_selected' for button: ", button.name)
			
			# Connect to local handler to hide canvas layer
			if not button.is_connected("level_selected", Callable(self, "_on_level_button_pressed")):
				button.connect(
					"level_selected",
					Callable(self, "_on_level_button_pressed"),
					CONNECT_DEFERRED
				)
		
		# 5. Force position update (fixes rendering glitches)
		button.position = button.position # Triggers transform update
	
	# Final visibility enforcement
	level_buttons.show()
	level_buttons.z_index = 1

	# Hide all stars first to ensure clean state, then update based on completion counts
	hide_all_stars()
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
		
		# Get the star sprites from the button
		if button.has_node("Star_bronze"):
			var star_bronze: Sprite2D = button.get_node("Star_bronze")
			var star_silver: Sprite2D = button.get_node("Star_silver")
			var star_gold: Sprite2D = button.get_node("Star_gold")
			
			var completion_count = GameManager.level_manager.get_level_completion_count(level_num)
			
			# Hide all stars initially
			star_bronze.hide()
			star_silver.hide()
			star_gold.hide()
			
			# Show appropriate star based on completion count
			if completion_count >= 1:
				star_bronze.show()
			if completion_count >= 2:
				star_bronze.hide()
				star_silver.show()
			if completion_count >= 3:
				star_bronze.hide()
				star_silver.hide()
				star_gold.show()
		else:
			# Fallback for backward compatibility - original logic
			var star = button.get_node_or_null("Star")
			if star:
				if GameManager.is_level_completed(i + 1):
					star.show()
				else:
					star.hide()

# Called when a level is completed and a star is earned
func _on_level_star_earned():
	update_stars()

func _on_back_pressed() -> void:
	canvaslayer.hide()
	GameManager.change_scene(Start_screen)

func _on_shop_pressed() -> void:
	canvaslayer.hide()
	GameManager.change_scene(Shop)

# Hide canvas layer when a level button is pressed
func _on_level_button_pressed(_level_num: int) -> void:
	if canvaslayer:
		canvaslayer.hide()
