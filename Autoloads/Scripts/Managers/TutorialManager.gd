extends Node

## Central campaign tutorial director. It persists each checkpoint so a new
## profile can resume safely, while established saves are never forced into it.

const TUTORIAL_OVERLAY := preload("res://UI/TutorialOverlay.tscn")
const CORE_ONBOARDING_ID := "core_onboarding"
const SHADOW_MODE_ID := "shadow_mode"
const STAGE_COMPLETE := "complete"

var _active_id: String = ""
var _active_step: Dictionary = {}
var _tutorial_layer: CanvasLayer
var _overlay: TutorialOverlay
var _slow_motion_active: bool = false
var _previous_time_scale: float = 1.0

func get_campaign_stage() -> String:
	if SaveManager and SaveManager.has_method("get_tutorial_campaign_stage"):
		return SaveManager.get_tutorial_campaign_stage()
	return STAGE_COMPLETE

func is_new_player_campaign_active() -> bool:
	return SaveManager and bool(SaveManager.tutorial_state.get("eligible_for_automatic_tutorials", false)) and get_campaign_stage() != STAGE_COMPLETE

func should_route_to_level_zero() -> bool:
	return is_new_player_campaign_active() and get_campaign_stage() == "level0_intro"

func can_open_shop() -> bool:
	return not is_new_player_campaign_active() or get_campaign_stage() == "shop_entry"

func can_upgrade_in_shop() -> bool:
	return not is_new_player_campaign_active() or get_campaign_stage() == "shop_upgrade"

func can_exit_shop() -> bool:
	return not is_new_player_campaign_active() or get_campaign_stage() == "shop_exit"

func can_start_level(level_num: int) -> bool:
	if not is_new_player_campaign_active():
		return true
	return level_num == 1 and get_campaign_stage() == "level1_entry"

func start_level_zero() -> bool:
	if get_campaign_stage() != "level0_intro":
		return false
	return _show_step("level0_intro", {
		"text": "Pilot, this is a live training sortie. Your cannons fire automatically; focus on movement and survival.",
		"status": "Tap NEXT to deploy.", "completion": "continue", "next_stage": "level0_first_bullet",
		"allow_player_input": false, "dim_amount": 0.48, "allow_skip": false
	})

func notify_enemy_bullet_spawned(_bullet: Node) -> void:
	if get_campaign_stage() != "level0_first_bullet" or not _active_id.is_empty():
		return
	_show_step("level0_bullet", {
		"text": "Hostile fire detected. Enemy bullets can destroy your fighter—keep moving and do not fly into their path.",
		"status": "Tap NEXT to resume at reduced speed.", "completion": "continue", "next_stage": "level0_coin_pickup",
		"allow_player_input": false, "dim_amount": 0.58, "allow_skip": false, "slow_motion": true
	})

func notify_pickup_spawned(kind: String, _pickup: Node) -> void:
	var expected_stage: String = "level0_coin_pickup" if kind == "coin" else "level0_powerup_pickup"
	if get_campaign_stage() != expected_stage or not _active_id.is_empty():
		return
	var text_value: String = "Collect coins to fund permanent ship upgrades between missions." if kind == "coin" else "Collect power cores to increase your firepower during this mission."
	_show_step("level0_" + kind, {
		"text": text_value, "status": "Fly into the highlighted pickup to continue.", "completion": "external",
		"allow_player_input": true, "dim_amount": 0.28, "allow_skip": false, "slow_motion": true
	})

func notify_pickup_collected(kind: String) -> void:
	var expected_stage: String = "level0_coin_pickup" if kind == "coin" else "level0_powerup_pickup"
	if get_campaign_stage() != expected_stage:
		return
	_set_stage("level0_powerup_pickup" if kind == "coin" else "level0_combat")
	_clear_overlay(true)

func handle_tutorial_death(player: Node) -> bool:
	if get_campaign_stage() == STAGE_COMPLETE or int(GameManager.get_current_level()) != 0 or not is_instance_valid(player):
		return false
	if player.has_method("set_lives"):
		player.call("set_lives", 3)
	if player.has_method("_play_death_animation"):
		player.call("_play_death_animation")
	if player.has_method("revive"):
		player.call("revive", 3)
	if _active_id.is_empty():
		_show_step("level0_revive", {
			"text": "Emergency recovery engaged. I restored your fighter this time, pilot—but do not rely on it in combat.",
			"status": "Tap NEXT and continue the sortie.", "completion": "continue", "allow_player_input": false,
			"dim_amount": 0.48, "allow_skip": false
		})
	return true

func complete_level_zero() -> bool:
	if int(GameManager.get_current_level()) != 0 or not is_new_player_campaign_active():
		return false
	_set_stage("shop_entry")
	_clear_overlay(true)
	GameManager.save_progress_if_enabled()
	GameManager.change_scene(GameManager.get_map_scene_path())
	return true

func on_map_ready() -> void:
	match get_campaign_stage():
		"shop_entry":
			_show_step("map_shop", {"text": "Training complete. Open the Ship Bay so we can improve your fighter.", "status": "Tap SHOP.", "completion": "external", "allow_player_input": true, "dim_amount": 0.22, "allow_skip": false})
		"level1_entry":
			_show_step("map_level1", {"text": "Your fighter is stronger now. Select Level 1—the real operation starts here.", "status": "Tap Level 1.", "completion": "external", "allow_player_input": true, "dim_amount": 0.22, "allow_skip": false})
		"shadow_map_intro":
			_show_step("shadow_map", {"text": "Shadow Drive unlocked. In Level 6, destroy enemies to fill its gauge, then release it when READY.", "status": "Tap NEXT to continue.", "completion": "continue", "next_stage": "shadow_charge_explained", "allow_player_input": false, "dim_amount": 0.5, "allow_skip": false})

func notify_shop_opened() -> void:
	if get_campaign_stage() != "shop_entry":
		return
	_set_stage("shop_upgrade")

func on_shop_ready(shop: Node) -> void:
	if get_campaign_stage() != "shop_upgrade":
		return
	if not SaveManager.get_tutorial_flag("shop_investment_granted"):
		var cost: int = 0
		if shop and shop.has_method("_get_current_upgrade_costs"):
			var costs: Variant = shop.call("_get_current_upgrade_costs")
			if costs is Dictionary:
				cost = int(costs.get("coin_cost", 0))
		if cost > 0:
			GameManager.add_currency("coins", cost)
		SaveManager.set_tutorial_flag("shop_investment_granted")
	_show_step("shop_upgrade", {"text": "Command has issued an upgrade allowance. Spend it on this ship now.", "status": "Use the coin upgrade button.", "completion": "external", "allow_player_input": true, "dim_amount": 0.24, "allow_skip": false})

func notify_upgrade_completed() -> void:
	if get_campaign_stage() != "shop_upgrade":
		return
	_set_stage("shop_exit")
	_clear_overlay(true)
	_show_step("shop_exit", {"text": "Upgrade confirmed. Leave the Ship Bay and begin Level 1.", "status": "Tap BACK.", "completion": "external", "allow_player_input": true, "dim_amount": 0.22, "allow_skip": false})

func notify_shop_exited() -> void:
	if get_campaign_stage() == "shop_exit":
		_set_stage("level1_entry")
	_clear_overlay(true)

func notify_level_selected(level_num: int) -> void:
	if level_num == 1 and get_campaign_stage() == "level1_entry":
		_set_stage("level1_playing")
		_clear_overlay(true)

func start_level_one() -> void:
	if get_campaign_stage() == "level1_playing":
		_show_step("level1_start", {"text": "This is the real fight now. Use what you learned and clear the sector.", "status": "Tap NEXT to begin.", "completion": "continue", "allow_player_input": false, "dim_amount": 0.42, "allow_skip": false})

func complete_level_one() -> bool:
	if int(GameManager.get_current_level()) != 1 or get_campaign_stage() != "level1_playing":
		return false
	_set_stage("wheel_intro")
	_clear_overlay(true)
	GameManager.level_manager.complete_level(1)
	GameManager.change_scene("res://MainScenes/Intern_Menu.tscn")
	return true

func on_intern_menu_ready(menu: Node) -> void:
	if get_campaign_stage() != "wheel_intro":
		return
	_show_step("wheel_intro", {"text": "Fortune Wheel unlocked. Claim a reward, then the galaxy is yours to explore.", "status": "Tap NEXT to open it.", "completion": "continue", "next_stage": STAGE_COMPLETE, "allow_player_input": false, "dim_amount": 0.5, "allow_skip": false, "open_wheel": menu})

func begin_shadow_unlock_flow() -> bool:
	if not is_new_player_campaign_active():
		return false
	_set_stage("shadow_map_intro")
	GameManager.save_progress_if_enabled()
	GameManager.change_scene(GameManager.get_map_scene_path())
	return true

func start_shadow_level_six() -> void:
	if get_campaign_stage() == "shadow_charge_explained":
		_show_step("shadow_level6", {"text": "Destroy enemies to charge Shadow Drive. When the gauge reads READY, we will activate it together.", "status": "Tap NEXT, then fill the gauge.", "completion": "continue", "allow_player_input": false, "dim_amount": 0.46, "allow_skip": false})

func notify_shadow_ready() -> void:
	if get_campaign_stage() != "shadow_charge_explained" or not _active_id.is_empty():
		return
	_show_step("shadow_ready", {"text": "Shadow Drive is charged. Tap the READY gauge now to engage Shadow Mode.", "status": "Tap NEXT, then tap READY.", "completion": "continue", "allow_player_input": false, "dim_amount": 0.5, "allow_skip": false, "slow_motion": true})

func _ready() -> void:
	if not GameManager.shadow_mode_activated.is_connected(_on_shadow_mode_activated):
		GameManager.shadow_mode_activated.connect(_on_shadow_mode_activated)

func _on_shadow_mode_activated() -> void:
	if get_campaign_stage() == "shadow_charge_explained" and int(GameManager.get_current_level()) == 6:
		_set_stage("shadow_activated")
		SaveManager.mark_tutorial_completed(SHADOW_MODE_ID)

func notify_overclock_reached() -> void:
	if SaveManager.get_tutorial_flag("overclock_explained") or not _active_id.is_empty():
		return
	_show_step("overclock", {"text": "Overclock limit reached. Your weapon damage is now capped; extra power cores are converted into score.", "status": "Tap NEXT to continue.", "completion": "continue", "allow_player_input": false, "dim_amount": 0.45, "allow_skip": true, "mark_flag": "overclock_explained"})

func start_core_onboarding() -> bool:
	return start_level_zero()

func start_shadow_mode_tutorial() -> bool:
	return begin_shadow_unlock_flow()

func replay_tutorial(_tutorial_id: String) -> bool:
	return false

func _show_step(id: String, step: Dictionary) -> bool:
	if not _active_id.is_empty():
		return false
	var current_scene: Node = get_tree().current_scene
	if not is_instance_valid(current_scene):
		return false
	_active_id = id
	_active_step = step.duplicate(true)
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 100
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = TUTORIAL_OVERLAY.instantiate() as TutorialOverlay
	_tutorial_layer.add_child(_overlay)
	current_scene.add_child(_tutorial_layer)
	_overlay.continue_requested.connect(_advance_active_step)
	_overlay.skip_requested.connect(_skip_active_step)
	if bool(_active_step.get("slow_motion", false)):
		_set_slow_motion(true)
	_set_player_input_enabled(bool(_active_step.get("allow_player_input", true)))
	_overlay.present_step(_active_step, _get_guide_portrait())
	return true

func _advance_active_step() -> void:
	if _active_id.is_empty() or str(_active_step.get("completion", "continue")) != "continue":
		return
	var next_stage: String = str(_active_step.get("next_stage", ""))
	var mark_flag: String = str(_active_step.get("mark_flag", ""))
	var wheel_menu: Node = _active_step.get("open_wheel", null) as Node
	if not next_stage.is_empty():
		_set_stage(next_stage)
	if not mark_flag.is_empty():
		SaveManager.set_tutorial_flag(mark_flag)
	_clear_overlay(true)
	if is_instance_valid(wheel_menu) and wheel_menu.has_node("Wheel"):
		var wheel: Node = wheel_menu.get_node("Wheel")
		if wheel.has_method("popup_open"):
			wheel.call("popup_open")

func _skip_active_step() -> void:
	if bool(_active_step.get("allow_skip", true)):
		_advance_active_step()

func _set_stage(stage: String) -> void:
	if SaveManager and SaveManager.has_method("set_tutorial_campaign_stage"):
		SaveManager.set_tutorial_campaign_stage(stage)

func _set_player_input_enabled(enabled: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player and "input_enabled" in player:
		player.input_enabled = enabled

func _set_slow_motion(enabled: bool) -> void:
	if enabled and not _slow_motion_active:
		_previous_time_scale = Engine.time_scale
		Engine.time_scale = 0.18
		_slow_motion_active = true
	elif not enabled and _slow_motion_active:
		Engine.time_scale = _previous_time_scale
		_slow_motion_active = false

func _clear_overlay(enable_player_input: bool) -> void:
	_set_slow_motion(false)
	if enable_player_input:
		_set_player_input_enabled(true)
	if is_instance_valid(_tutorial_layer):
		_tutorial_layer.queue_free()
	_active_id = ""
	_active_step.clear()
	_tutorial_layer = null
	_overlay = null

func _get_guide_portrait() -> Texture2D:
	return load("res://Assets/UI/Tutorial/adrian_voss_guide.png") as Texture2D
