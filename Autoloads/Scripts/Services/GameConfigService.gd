extends RefCounted
class_name GameConfigService

# Centralized config access helpers used by GameManager.

func get_game_setting(config_loader, key: String, default_value: Variant) -> Variant:
	if is_instance_valid(config_loader) and config_loader.game_settings:
		return config_loader.game_settings.get(key, default_value)
	return default_value

func get_game_settings_section(config_loader, key: String) -> Dictionary:
	var section: Variant = get_game_setting(config_loader, key, {})
	if section is Dictionary:
		return section as Dictionary
	return {}

func get_player_setting(config_loader, key: String, default_value: Variant) -> Variant:
	if is_instance_valid(config_loader) and config_loader.player_settings:
		return config_loader.player_settings.get(key, default_value)
	return default_value

func get_upgrade_setting(config_loader, key: String, default_value: Variant) -> Variant:
	if is_instance_valid(config_loader) and config_loader.upgrade_settings:
		return config_loader.upgrade_settings.get(key, default_value)
	return default_value

func get_boss_reward_for_level(config_loader, level_num: int) -> Dictionary:
	var fallback: Dictionary = {
		"coins": int(1000 * (level_num / 5.0)),
		"crystals": int(60 * (level_num / 5.0)),
		"void_shards": int(50 * (level_num / 5.0))
	}
	var boss_rewards: Variant = get_upgrade_setting(config_loader, "boss_level_rewards", {})
	if boss_rewards is Dictionary and boss_rewards.has(str(level_num)):
		var level_reward: Variant = boss_rewards[str(level_num)]
		if level_reward is Dictionary:
			return level_reward as Dictionary
	return fallback

func get_config_ships_data(config_loader) -> Array:
	if is_instance_valid(config_loader):
		var ships_data: Variant = config_loader.ships_data
		if ships_data is Array:
			return (ships_data as Array).duplicate(true)
	return []

func get_config_satellites_data(config_loader) -> Array:
	if is_instance_valid(config_loader):
		var satellites_data: Variant = config_loader.satellites_data
		if satellites_data is Array:
			return (satellites_data as Array).duplicate(true)
	return []
