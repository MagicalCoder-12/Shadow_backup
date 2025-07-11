extends Control

@onready var level_buttons: Node2D = $LevelButtons
const Start_screen = "res://MainScenes/start_menu.tscn"
const Shop = "res://MainScenes/upgrade_menu.tscn"
# Called when the node enters the scene tree
func _ready():
	# Wait until the scene is fully ready (fixes transition issues)
	call_deferred("_initialize_level_buttons")
	# Connect to level_unlocked signal to update buttons dynamically
	GameManager.level_unlocked.connect(_on_level_unlocked)
	# Connect to level_star_earned signal to update stars
	GameManager.level_star_earned.connect(_on_level_star_earned)
	# Initialize stars visibility
	update_stars()
	get_tree().get_root().connect("go_back_requested",_on_back_pressed)

# Process input for testing
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			var current_level = GameManager.unlocked_levels
			var max_levels = level_buttons.get_child_count()  # Correctly count child buttons
			if current_level < max_levels:
				GameManager.unlock_next_level(current_level)
				print("Unlocked level %d for testing" % (current_level + 1))
			else:
				print("All levels already unlocked!")

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
		
		# 2. Set level number if method exists
		if button.has_method("set_level"):
			button.call("set_level", i + 1)
			
		# 3. Set locked state based on GameManager
		var is_unlocked = GameManager.is_level_unlocked(i + 1)
		button.locked = not is_unlocked  # Set custom locked property
		
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
		button.position = button.position  # Triggers transform update

	# Final visibility enforcement
	level_buttons.show()
	level_buttons.z_index = 1

# Update button states when a new level is unlocked
func _on_level_unlocked(_new_level: int):
	update_level_buttons()

# Function to refresh button states
func update_level_buttons():
	var buttons = level_buttons.get_children()
	for i in range(buttons.size()):
		var button = buttons[i]
		var is_unlocked = GameManager.is_level_unlocked(i + 1)
		button.locked = not is_unlocked  # Update locked property

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
				if star.modulate.a < 1.0:
					var tween = create_tween()
					tween.tween_property(star, "modulate:a", 1.0, 0.5)
			else:
				# Hide the star if the level is not completed
				star.modulate.a = 0.0


# Called when a level is completed and a star is earned
func _on_level_star_earned():
	update_stars()

func _on_back_pressed() -> void:
	GameManager.change_scene(Start_screen)

func _on_texture_button_pressed() -> void:
	GameManager.change_scene(Shop)
