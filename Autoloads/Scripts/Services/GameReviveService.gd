extends RefCounted
class_name GameReviveService

# Centralized revive helpers used by GameManager.

func reset_revive_limits_for_level(game_manager) -> void:
	game_manager.request_revive_pending_clear("GameReviveService.reset_revive_limits_for_level")
	game_manager.ad_revives_used_this_level = 0
	game_manager.crystal_revives_used_this_level = 0

func get_max_ad_revives_per_level(config_service, config_loader, default_value: int) -> int:
	var configured_value: int = int(config_service.get_upgrade_setting(config_loader, "max_ad_revives_per_level", default_value))
	return maxi(0, configured_value)

func get_max_crystal_revives_per_level(config_service, config_loader, default_value: int) -> int:
	var configured_value: int = int(config_service.get_upgrade_setting(config_loader, "max_crystal_revives_per_level", default_value))
	return maxi(0, configured_value)

func get_ad_revives_remaining(max_ad_revives_per_level: int, ad_revives_used_this_level: int) -> int:
	return maxi(0, max_ad_revives_per_level - ad_revives_used_this_level)

func get_crystal_revives_remaining(max_crystal_revives_per_level: int, crystal_revives_used_this_level: int) -> int:
	return maxi(0, max_crystal_revives_per_level - crystal_revives_used_this_level)

func get_crystal_revive_cost(config_service, config_loader, crystal_revives_used_this_level: int, default_base_cost: int, default_increment: int) -> int:
	var base_cost: int = maxi(0, int(config_service.get_upgrade_setting(config_loader, "crystal_revive_base_cost", default_base_cost)))
	var increment: int = maxi(0, int(config_service.get_upgrade_setting(config_loader, "crystal_revive_cost_increment", default_increment)))
	return base_cost + (increment * crystal_revives_used_this_level)

func can_use_ad_revive(game_over: bool, is_revive_pending: bool, ad_revives_remaining: int) -> bool:
	return game_over and not is_revive_pending and ad_revives_remaining > 0

func can_use_crystal_revive(game_over: bool, is_revive_pending: bool, crystal_revives_remaining: int) -> bool:
	return game_over and not is_revive_pending and crystal_revives_remaining > 0

func mark_ad_revive_used(ad_revives_used_this_level: int, max_ad_revives_per_level: int) -> int:
	return mini(max_ad_revives_per_level, ad_revives_used_this_level + 1)

func mark_crystal_revive_used(crystal_revives_used_this_level: int, max_crystal_revives_per_level: int) -> int:
	return mini(max_crystal_revives_per_level, crystal_revives_used_this_level + 1)

func try_spend_crystal_revive(game_manager) -> Dictionary:
	if not game_manager.can_use_crystal_revive():
		return {
			"ok": false,
			"error": "Crystal revives are unavailable."
		}
	var cost: int = game_manager.get_crystal_revive_cost()
	if not game_manager.can_afford("crystals", cost):
		return {
			"ok": false,
			"error": "Not enough crystals.",
			"cost": cost
		}
	game_manager.deduct_currency("crystals", cost)
	game_manager.crystal_revives_used_this_level = mark_crystal_revive_used(
		int(game_manager.crystal_revives_used_this_level),
		int(game_manager.get_max_crystal_revives_per_level())
	)
	game_manager.request_revive_pending_start("GameReviveService.try_spend_crystal_revive")
	return {
		"ok": true,
		"cost": cost
	}

func request_ad_revive_internal(game_manager, ad_manager) -> bool:
	if not game_manager.can_use_ad_revive():
		return false
	if not ad_manager:
		return false
	game_manager.pause_for_ad_revive()
	if ad_manager.is_initialized and ad_manager.is_banner_showing:
		ad_manager.hide_banner_ad()
	var started: bool = ad_manager.request_ad_revive()
	if not started:
		game_manager.resume_after_ad_revive()
	return started

func handle_ad_revive_success(game_manager) -> void:
	game_manager.mark_ad_revive_used()
	game_manager.revive_completed.emit(true)

func handle_ad_revive_failure(game_manager, _error_data: Variant = null) -> void:
	game_manager.revive_completed.emit(false)
