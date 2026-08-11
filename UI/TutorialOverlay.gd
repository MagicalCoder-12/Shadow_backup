extends Control
class_name TutorialOverlay

signal continue_requested
signal skip_requested

var _speaker: Label
var _dialogue: Label
var _status: Label
var _continue: Button
var _skip: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func present_step(step: Dictionary, _portrait: Texture2D) -> void:
	if not is_node_ready():
		await ready
	_speaker.text = str(step.get("speaker", "COMMANDER ADRIAN"))
	_dialogue.text = str(step.get("text", ""))
	_status.text = str(step.get("status", ""))
	_continue.visible = str(step.get("completion", "continue")) == "continue"
	_skip.visible = bool(step.get("allow_skip", true))

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.02, 0.07, 0.5)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.anchor_left = 0.05
	card.anchor_right = 0.95
	card.anchor_top = 0.64
	card.anchor_bottom = 0.95
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 30)
	box.add_child(_speaker)
	_dialogue = Label.new()
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.add_theme_font_size_override("font_size", 26)
	box.add_child(_dialogue)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	_skip = Button.new()
	_skip.text = "SKIP"
	_skip.pressed.connect(func(): skip_requested.emit())
	buttons.add_child(_skip)
	_continue = Button.new()
	_continue.text = "NEXT"
	_continue.pressed.connect(func(): continue_requested.emit())
	buttons.add_child(_continue)
