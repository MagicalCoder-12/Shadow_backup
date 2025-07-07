extends Control

var pLifeIcon := preload("uid://ceg6sboym3t71")

@onready var lifeContainer := $LifeContainer
@onready var scoreLabel := $Score
@onready var timer_label: Label = $Timer  
@onready var shadow_mode_button: TextureButton = $ShadowModeButton
@onready var shadow_mode_charge: TextureProgressBar = $ShadowModeButton/ShadowModeCharge
@onready var shadow_mode_label: Label = $ShadowModeButton/ShadowModeCharge/ShadowModeLabel
@export var charge_per_enemy: float = 10.0
@export var max_charge: float = 100.0
var current_charge: float = 0.0
var level_start_time: float = 0.0
var timer_running: bool = false

func _ready():
	if not pLifeIcon or not pLifeIcon.can_instantiate():
		push_error("Invalid pLifeIcon preload")
	clear_lives()
	# Connect signals
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.on_player_life_changed.connect(_on_player_life_changed)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.all_waves_cleared.connect(_on_all_waves_cleared)
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	if shadow_mode_button:
		shadow_mode_button.disabled = true
		shadow_mode_button.visible = false
	# Initialize displays
	_on_score_updated(GameManager.score)
	_on_player_life_changed(GameManager.player_lives)
	update_charge_display()
	update_button_visibility()
	start_timer()

func _process(_delta):
	if timer_running:
		update_timer_display()

func start_timer():
	level_start_time = Time.get_ticks_msec()
	timer_running = true
	update_timer_display()

func stop_timer():
	timer_running = false

func reset_timer():
	level_start_time = Time.get_ticks_msec()
	timer_running = true

func update_timer_display():
	if not timer_label:
		return
	
	var current_time = Time.get_ticks_msec() - level_start_time
	var seconds = current_time / 1000.0
	var minutes = seconds / 60.0
	seconds = fmod(seconds, 60.0)
	
	# Format as MM:SS.mmm
	timer_label.text = " Time: %02d:%05.2f" % [minutes, seconds]

# Clears current life icons
func clear_lives():
	for child in lifeContainer.get_children():
		child.queue_free()

# Set the life icons based on current lives
func set_lives(lives: int):
	clear_lives()
	for i in range(lives):
		var life_icon = pLifeIcon.instantiate()
		if life_icon:
			lifeContainer.add_child(life_icon)
		else:
			push_error("Failed to instantiate pLifeIcon")

# Updates the score display
func _on_score_updated(new_score: int):
	if scoreLabel:
		scoreLabel.text = "Score: %d" % new_score

# Updates the player life count
func _on_player_life_changed(life: int):
	set_lives(life)

# Updates the display when a new wave starts
func _on_wave_started(_current_wave: int, _total_waves: int):
	pass  # We're not showing wave info anymore

# Called when all waves are cleared
func _on_all_waves_cleared():
	if timer_label:
		stop_timer()
		var current_time = Time.get_ticks_msec() - level_start_time
		var seconds = current_time / 1000.0
		var minutes = seconds / 60.0
		seconds = fmod(seconds, 60.0)
		timer_label.text = "Completed in: %02d:%05.2f" % [minutes, seconds]

# Updates the display when the game is paused or resumed
func _on_game_paused(paused: bool):
	if timer_label:
		if paused:
			timer_running = false
			timer_label.text = "⏸️ Paused"
		else:
			timer_running = true
			timer_label.text = "▶️ Resumed"

# Called when an enemy is killed to increase charge
func add_enemy_kill_charge(amount: float = charge_per_enemy):
	var current_level = GameManager.get_current_level()
	if current_level < 5 or not GameManager.shadow_mode_unlocked:
		return
	if GameManager.shadow_mode_enabled:
		return
	current_charge = clamp(current_charge + amount, 0.0, max_charge)
	update_charge_display()
	if current_charge >= max_charge and shadow_mode_button and shadow_mode_label:
		shadow_mode_button.disabled = false
		shadow_mode_label.text = "Ready!"

# Updates the charge display
func update_charge_display():
	if shadow_mode_charge:
		shadow_mode_charge.value = current_charge
	if shadow_mode_label:
		if current_charge < max_charge:
			shadow_mode_label.text = "Charge: %d%%" % (current_charge / max_charge * 100)
		else:
			shadow_mode_label.text = "Ready!"

# Called when the shadow mode button is pressed
func _on_shadow_mode_button_pressed():
	var current_level = GameManager.get_current_level()
	if current_level < 5 or not GameManager.shadow_mode_unlocked:
		return
	if current_charge >= max_charge and not GameManager.shadow_mode_enabled:
		GameManager.activate_shadow_mode(5.0)
		current_charge = 0.0
		if shadow_mode_button:
			shadow_mode_button.disabled = true
		update_charge_display()

# Updates button visibility
func update_button_visibility():
	var current_level = GameManager.get_current_level()
	var should_be_visible = current_level >= 5 and GameManager.shadow_mode_unlocked
	if shadow_mode_button:
		shadow_mode_button.visible = should_be_visible
		if not should_be_visible:
			shadow_mode_button.disabled = true
			current_charge = 0.0
			update_charge_display()

# Resets shadow mode charge
func reset_charge():
	current_charge = 0.0
	if shadow_mode_button:
		shadow_mode_button.disabled = true
	update_charge_display()

# Handle shadow mode activation
func _on_shadow_mode_activated():
	if shadow_mode_button:
		shadow_mode_button.disabled = true

# Handle shadow mode deactivation
func _on_shadow_mode_deactivated():
	var current_level = GameManager.get_current_level()
	if current_charge >= max_charge and GameManager.shadow_mode_unlocked and current_level >= 5 and shadow_mode_button:
		shadow_mode_button.disabled = false
