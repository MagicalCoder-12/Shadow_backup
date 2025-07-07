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

var level_num = 1  # Default to 1, will be updated by LevelButtons


func set_level(num: int) -> void:
	level_num = num
	if label:
		label.text = str(level_num)

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
