extends TextureButton

@onready var label: Label = $Label

const Level_1 = "res://Levels/level_1.tscn"

signal level_selected

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
		# Emit the signal and let the GameManager handle the rest
		level_selected.emit(level_num)
		GameManager.load_level(level_num)
