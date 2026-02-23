extends TextureButton

@onready var label: Label = $Label

const Level_1 = "res://Levels/level_1.tscn"
@onready var star_bronze: Sprite2D = $Stars/Star_bronze
@onready var star_silver: Sprite2D = $Stars/Star_silver
@onready var star_gold: Sprite2D = $Stars/Star_gold

signal level_selected(level_num: int)

@export var locked: bool = true:
	set(value):
		locked = value
		if locked:
			level_locked()
		else:
			level_unlocked()

var level_num = 1 # Default to 1, will be updated by LevelButtons
var world_num = 1 # Track which world this level belongs to
var level_in_world = 1 # Track level number within the world

func set_level(num: int, levels_per_world: int = 10) -> void:
	level_num = num
	
	# Calculate world and level within world
	@warning_ignore("integer_division")
	world_num = ((num - 1) / levels_per_world) + 1
	level_in_world = ((num - 1) % levels_per_world) + 1
	
	if label:
		label.text = str(world_num) + "-" + str(level_in_world)

func level_locked() -> void:
	level_state(true)

func level_unlocked() -> void:
	level_state(false)

func level_state(value: bool) -> void:
	disabled = value
	if label:
		label.visible = true

func _on_pressed():
	if not locked:
		# Stop the map sound before changing scenes
		var map_scene = get_tree().current_scene
		if map_scene.has_node("map"):
			var map_audio = map_scene.get_node("map")
			if map_audio and map_audio.is_playing():
				map_audio.stop()
		
		# Emit signal to notify listeners (like map scene) that level was selected
		level_selected.emit(level_num)
		
		# Show difficulty selection before loading level
		_show_difficulty_selection()
		
		# OLD CODE: GameManager.load_level(level_num)

func _show_difficulty_selection() -> void:
	# Show the existing difficulty selection panel by traversing up the scene tree
	var current_node = self
	
	# Traverse up to find the map node
	while current_node and current_node.name != "Map":
		current_node = current_node.get_parent()
		if not current_node:
			print("Level button: Could not find Map node in parent hierarchy")
			return
	
	print("Level button: Found Map node through parent traversal")
	
	# Find the difficulty selection panel
	if current_node.has_node("CanvasLayer/DifficultySelection"):
		var difficulty_panel = current_node.get_node("CanvasLayer/DifficultySelection")
		print("Level button: Found difficulty selection panel")
		
		# Set the target level
		if difficulty_panel.has_method("set_target_level"):
			difficulty_panel.set_target_level(level_num)
			print("Level button: Set target level to ", level_num)
		
		# Show the canvas layer and difficulty selection panel
		if current_node.has_node("CanvasLayer"):
			var canvas_layer = current_node.get_node("CanvasLayer")
			canvas_layer.show()
		
			difficulty_panel.show()
			print("Level button: Showed difficulty selection panel")
			
			# Focus a valid interactive control to avoid focus warnings on non-focusable roots.
			if difficulty_panel.has_method("focus_default_control"):
				difficulty_panel.focus_default_control()
			elif difficulty_panel is Control:
				var panel_control := difficulty_panel as Control
				if panel_control.focus_mode == Control.FOCUS_NONE:
					panel_control.focus_mode = Control.FOCUS_ALL
				panel_control.grab_focus()
		else:
			print("Level button: Difficulty selection panel not found at CanvasLayer/DifficultySelection")
