extends Node

# === NODES ===
@onready var game_over_screen: Control = $"../CanvasLayer/GameOverScreen"
@onready var pause_menu: Control = $"../CanvasLayer/PauseMenu"
@onready var level_completed: Control = $"../CanvasLayer/LevelCompleted"
@onready var hud: Control = $"../CanvasLayer/HUD"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var pause_button: Button = $"../CanvasLayer/Pause"
@onready var wave_manager: WaveManager = $"../WaveManager"


# === EXPORTED ===
@export var level_num: int = 1
@export var waves: Array[WaveConfig] = []
@export var debug_mode: bool = false

# === VARIABLES ===
var has_completed_level: bool = false
var game_over: bool = false
var level_completed_shown: bool = false
var waves_initialized: bool = false
var saved_shadow_charge: float = 0.0
var player_scene: PackedScene = preload("res://Player/Player.tscn")

# === READY ===
func _ready():
	# Add to LevelManager group
	add_to_group("LevelManager")
	
	game_over_screen.hide()
	pause_menu.hide()
	level_completed.hide()
	game_over = GameManager.game_over

	# HUD check
	if not hud:
		push_warning("HUD node not found")
	else:
		var shadow_button = hud.get_node_or_null("ShadowModeButton")
		if not shadow_button:
			push_warning("ShadowModeButton not found in HUD")

	# Pause button
	if not pause_button:
		push_error("PauseButton not found")
	else:
		pause_button.grab_focus()
		if not pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.connect(_on_pause_pressed)

	# Connect signals
	GameManager.game_over_triggered.connect(_game_over_triggered)
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)
	GameManager.shadow_mode_deactivated.connect(_on_shadow_mode_deactivated)
	wave_manager.wave_started.connect(hud._on_wave_started)
	wave_manager.all_waves_cleared.connect(_on_wave_manager_all_waves_cleared)

	# Initialize waves
	_initialize_waves()

# === WAVE VALIDATION ===
func validate_wave_config(wave: WaveConfig, wave_index: int) -> bool:
	if not wave:
		push_warning("LevelManager: Wave %d is null" % (wave_index + 1))
		return false
	
	# Check enemy or boss scene
	var enemy_scene = wave.get_enemy_scene()
	if not enemy_scene or not enemy_scene.can_instantiate():
		push_warning("LevelManager: Wave %d has invalid or missing enemy/boss scene" % (wave_index + 1))
		return false
	
	# Check boss wave consistency
	if wave.is_boss_wave() and wave.get_enemy_count() != 1:
		push_warning("LevelManager: Wave %d is a boss wave but has enemy_count != 1 (%d)" % [wave_index + 1, wave.get_enemy_count()])
		return false
	
	# Check enemy density
	var valid_densities = ["Sparse", "Normal", "Dense", "Maximum"]
	if not wave.enemy_density in valid_densities:
		push_warning("LevelManager: Wave %d has invalid enemy_density '%s'" % [wave_index + 1, wave.enemy_density])
		return false
	
	# Check formation center
	if wave.formation_center.x < 0 or wave.formation_center.y < 0:
		push_warning("LevelManager: Wave %d has invalid formation_center %s" % [wave_index + 1, wave.formation_center])
		return false
	
	# Check formation type for non-boss waves
	if not wave.is_boss_wave():
		var valid_formations = formation_enums.FormationType.values()
		if not wave.get_formation_type() in valid_formations:
			push_warning("LevelManager: Wave %d has invalid formation_type %d" % [wave_index + 1, wave.get_formation_type()])
			return false
	
	# Check enemy type for non-boss waves
	if not wave.is_boss_wave():
		var valid_enemies = ["mob1", "mob2", "mob3", "mob4", "SlowShooter", "FastEnemy", "BouncerEnemy"]
		if not wave.enemy_type in valid_enemies:
			push_warning("LevelManager: Wave %d has invalid enemy_type '%s'" % [wave_index + 1, wave.enemy_type])
			return false
	
	if debug_mode:
		var debug_string = wave.as_debug_string() if wave.has_method("as_debug_string") else "WaveConfig"
		print("LevelManager: Validated Wave %d: %s" % [wave_index + 1, debug_string])
	
	return true

# === WAVE INITIALIZATION ===
func _initialize_waves() -> void:
	if not waves_initialized:
		if waves.is_empty():
			push_warning("LevelManager: No waves configured for level %d" % level_num)
		else:
			# Validate wave configurations
			for i in range(waves.size()):
				var wave: WaveConfig = waves[i]
				if not validate_wave_config(wave, i):
					push_warning("LevelManager: Wave %d failed validation" % (i + 1))
				else:
					if debug_mode:
						var debug_string = wave.as_debug_string() if wave.has_method("as_debug_string") else "WaveConfig"
						print("LevelManager: Wave %d: Validated %s (Boss: %s, Enemy Count: %d)" % [
							i + 1,
							debug_string,
							wave.is_boss_wave(),
							wave.get_enemy_count()
						])
			# Send waves to WaveManager and start spawning
			wave_manager.set_waves(waves)
			wave_manager.current_level = level_num
			wave_manager.start_waves()
			waves_initialized = true
			if debug_mode:
				print("LevelManager: Initialized %d waves for level %d" % [waves.size(), level_num])

# === INPUT HANDLER ===
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE, KEY_BACK:
				if not game_over and not level_completed_shown:
					_toggle_pause_menu()
			KEY_R:
				if game_over and not level_completed_shown:
					GameManager.is_revive_pending = true
					_on_player_revived()

# === PAUSE TOGGLE & TWEEN ===
func _toggle_pause_menu():
	if level_completed_shown:
		return
	if get_tree().paused:
		get_tree().paused = false
		GameManager.is_paused = false
		_hide_pause_menu()
	else:
		get_tree().paused = true
		GameManager.is_paused = true
		_show_pause_menu()

func _show_pause_menu():
	pause_menu.visible = true
	animation_player.play("fade_in")

func _hide_pause_menu():
	var tween = create_tween()
	tween.tween_property(pause_menu, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	pause_menu.visible = false

func _on_pause_pressed():
	if not game_over and not level_completed_shown:
		_toggle_pause_menu()

func _on_game_paused(paused: bool):
	if game_over or level_completed_shown:
		_hide_pause_menu()
		get_tree().paused = false
		GameManager.is_paused = false
	else:
		get_tree().paused = paused
		GameManager.is_paused = paused
		if paused:
			_show_pause_menu()
		else:
			_hide_pause_menu()

# === GAME OVER ===
func _game_over_triggered():
	if GameManager.is_level_just_completed:
		return
	game_over = true
	GameManager.game_over = true
	get_tree().paused = false
	pause_menu.hide()
	if hud and hud.has_method("update_charge_display"):
		saved_shadow_charge = hud.current_charge if hud.current_charge is float else 0.0
	game_over_screen._on_score_updated(GameManager.score)
	game_over_screen._on_high_score_updated(GameManager.high_score)
	game_over_screen.modulate.a = 0.0
	game_over_screen.show()
	var tween = create_tween()
	tween.tween_property(game_over_screen, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# === REVIVE ===
func _on_player_revived():
	if not GameManager.is_revive_pending:
		return
	game_over = false
	GameManager.game_over = false

	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = player_scene.instantiate()
		add_child(player)
		player.global_position = GameManager.player_spawn_position
	player.revive(2)

	if hud and hud.has_method("update_charge_display"):
		hud.current_charge = saved_shadow_charge
		hud.update_charge_display()

	AudioManager.mute_bus("Bullet", false)
	AudioManager.mute_bus("Explosion", false)
	GameManager.revive_player(2)

func revive_player():
	_on_player_revived()

# === LEVEL COMPLETE ===
func _on_level_completed(_level_num: int):
	print("level completed")
	AudioManager.mute_bus("Bullet", true)
	get_tree().paused = false
	animation_player.play("Player_sweep")

func _on_animation_player_animation_finished(anim_name: StringName):
	if anim_name == "Player_sweep" and has_completed_level and not level_completed_shown:
		_show_level_completed_ui()

func _show_level_completed_ui():
	level_completed_shown = true
	get_tree().paused = false
	pause_menu.hide()
	level_completed.modulate.a = 0.0
	level_completed.show()
	var tween = create_tween()
	tween.tween_property(level_completed, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	GameManager.save_progress()

# === WAVE CLEARED ===
func _on_wave_manager_all_waves_cleared():
	if not has_completed_level:
		has_completed_level = true
		if hud and hud.has_method("reset_charge"):
			hud.reset_charge()
		if wave_manager.all_waves_cleared.is_connected(_on_wave_manager_all_waves_cleared):
			wave_manager.all_waves_cleared.disconnect(_on_wave_manager_all_waves_cleared)
		GameManager.complete_level(level_num)

# === SHADOW MODE ===
func _on_shadow_mode_activated():
	wave_manager._on_shadow_mode_activated()

func _on_shadow_mode_deactivated():
	wave_manager._on_shadow_mode_deactivated()
