extends RefCounted
class_name UpgradeAdService

var ad_limit_per_hour: int = 15
var ad_cooldown_seconds: int = 3600
var ad_usage_count: int = 0
var ad_last_used_time: int = 0

func configure(limit_per_hour: int, cooldown_seconds: int) -> void:
	ad_limit_per_hour = maxi(0, limit_per_hour)
	ad_cooldown_seconds = maxi(0, cooldown_seconds)

func load_usage(save_manager) -> void:
	if save_manager:
		ad_usage_count = int(save_manager.ad_usage_count)
		ad_last_used_time = int(save_manager.ad_last_used_time)

func save_usage(save_manager) -> void:
	if save_manager:
		save_manager.ad_usage_count = ad_usage_count
		save_manager.ad_last_used_time = ad_last_used_time
		save_manager.save_progress()

func reset_if_cooldown_elapsed() -> void:
	var current_time: int = int(Time.get_unix_time_from_system())
	if current_time - ad_last_used_time >= ad_cooldown_seconds:
		ad_usage_count = 0

func can_show_rewarded_ad() -> bool:
	reset_if_cooldown_elapsed()
	return ad_usage_count < ad_limit_per_hour

func record_ad_usage(save_manager) -> void:
	ad_usage_count += 1
	ad_last_used_time = int(Time.get_unix_time_from_system())
	save_usage(save_manager)

func get_remaining_cooldown_minutes() -> int:
	var current_time: int = int(Time.get_unix_time_from_system())
	var elapsed_time: int = current_time - ad_last_used_time
	var remaining_time: int = maxi(0, ad_cooldown_seconds - elapsed_time)
	return int(ceil(remaining_time / 60.0))

func get_ad_limit_message() -> String:
	return "Ad limit reached! You can watch ads again in %d minutes." % get_remaining_cooldown_minutes()

func _get_reward_amounts(game_manager) -> Dictionary:
	if game_manager and game_manager.has_method("get_upgrade_setting"):
		return {
			"ad_crystal_reward": int(game_manager.get_upgrade_setting("ad_crystal_reward", 15)),
			"ad_ascend_reward": int(game_manager.get_upgrade_setting("ad_ascend_reward", 10)),
			"ad_coins_reward": int(game_manager.get_upgrade_setting("ad_coins_reward", 5000))
		}
	return {
		"ad_crystal_reward": 15,
		"ad_ascend_reward": 10,
		"ad_coins_reward": 5000
	}

func build_reward_message(game_manager, reward_type: String) -> String:
	var rewards := _get_reward_amounts(game_manager)
	match reward_type:
		"crystals":
			return "Rewarded: %d Crystals and %d Void Shards!" % [
				int(rewards.get("ad_crystal_reward", 15)),
				int(rewards.get("ad_ascend_reward", 10))
			]
		"coins":
			return "Rewarded: %d Coins!" % int(rewards.get("ad_coins_reward", 5000))
	return "Reward granted!"

func grant_reward(game_manager, reward_type: String) -> String:
	if not game_manager:
		return "Reward granted!"
	var rewards := _get_reward_amounts(game_manager)
	match reward_type:
		"crystals":
			game_manager.add_currency("crystals", int(rewards.get("ad_crystal_reward", 15)))
			game_manager.add_currency("void_shards", int(rewards.get("ad_ascend_reward", 10)))
		"coins":
			game_manager.add_currency("coins", int(rewards.get("ad_coins_reward", 5000)))
	return build_reward_message(game_manager, reward_type)

func request_reward_ad(game_manager, reward_type: String) -> Dictionary:
	if reward_type != "crystals" and reward_type != "coins":
		return {
			"ok": false,
			"error": "unsupported_reward",
			"message": "Unsupported reward type."
		}
	if not can_show_rewarded_ad():
		return {
			"ok": false,
			"error": "limit",
			"message": get_ad_limit_message()
		}
	if not game_manager or not game_manager.ad_manager or not game_manager.ad_manager.is_initialized:
		return {
			"ok": false,
			"error": "unavailable",
			"message": "Ads not available. Please try again later."
		}
	game_manager.ad_manager.request_reward_ad(reward_type)
	return {"ok": true}
