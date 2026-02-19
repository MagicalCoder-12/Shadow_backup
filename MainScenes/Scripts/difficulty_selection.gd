extends Control

# Import formation_enums to access shared enums
const FormationEnums = preload("res://Enemy Manager/Scripts/formation_enums.gd")

@onready var easy_button: TextureButton = $Panel/VBoxContainer/Difficulty_buttons/Control/Easy
@onready var medium_button: TextureButton = $Panel/VBoxContainer/Difficulty_buttons/Control/Medium
@onready var hard_button: TextureButton = $Panel/VBoxContainer/Difficulty_buttons/Control/Hard
@onready var back_button: TextureButton = $Panel/VBoxContainer/Menu_buttons/Back
@onready var start_button: TextureButton = $Panel/VBoxContainer/Menu_buttons/Start
@onready var description_label: Label = $Panel/DescriptionLabel

var selected_difficulty: FormationEnums.DifficultyLevel = FormationEnums.DifficultyLevel.NORMAL
var target_level: int = 1

func _ready():
	# Connect button signals
	if easy_button:
		easy_button.pressed.connect(_on_easy_pressed)
	if medium_button:
		medium_button.pressed.connect(_on_normal_pressed)
	if hard_button:
		hard_button.pressed.connect(_on_hard_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	
	# Set up difficulty descriptions
	_update_description(FormationEnums.DifficultyLevel.NORMAL)

func set_target_level(level_num: int) -> void:
	target_level = level_num

func _update_description(difficulty: FormationEnums.DifficultyLevel) -> void:
	selected_difficulty = difficulty
	
	var descriptions = {
		FormationEnums.DifficultyLevel.EASY: "Enemies have reduced health, damage, and speed.\nLower enemy count and slower fire rates.\nPerfect for beginners.",
		FormationEnums.DifficultyLevel.NORMAL: "Standard challenge with balanced enemy stats.\nRecommended for average players.",
		FormationEnums.DifficultyLevel.HARD: "Enemies have increased health, damage, and speed.\nHigher enemy count and faster fire rates.\nFor experienced players.",
	}
	
	# Update description label
	description_label.text = descriptions.get(difficulty, "Select a difficulty level")

func _on_easy_pressed() -> void:
	_update_description(FormationEnums.DifficultyLevel.EASY)

func _on_normal_pressed() -> void:
	_update_description(FormationEnums.DifficultyLevel.NORMAL)

func _on_hard_pressed() -> void:
	_update_description(FormationEnums.DifficultyLevel.HARD)


func _on_back_pressed() -> void:
	hide()

func _on_start_pressed() -> void:
	# Load the level with the selected difficulty
	if GameManager:
		GameManager.set_current_difficulty(selected_difficulty)
		GameManager.load_level(target_level)
		hide()
