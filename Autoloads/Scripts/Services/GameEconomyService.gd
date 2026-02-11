extends RefCounted
class_name GameEconomyService

# Centralized currency/save helpers used by GameManager to reduce direct coupling.

func save_progress(save_manager) -> void:
	if save_manager:
		save_manager.save_progress()

func save_progress_if_enabled(save_manager) -> void:
	if save_manager and save_manager.autosave_progress:
		save_manager.save_progress()

func can_afford(game_manager, currency_type: String, cost: int) -> bool:
	var normalized_cost: int = maxi(0, cost)
	match currency_type:
		"crystals":
			return int(game_manager.crystal_count) >= normalized_cost
		"coins":
			return int(game_manager.coin_count) >= normalized_cost
		"void_shards":
			return int(game_manager.void_shards_count) >= normalized_cost
	return false

func deduct_currency(game_manager, save_manager, currency_type: String, amount: int) -> void:
	var normalized_amount: int = maxi(0, amount)
	match currency_type:
		"crystals":
			game_manager.crystal_count -= normalized_amount
		"coins":
			game_manager.coin_count -= normalized_amount
		"void_shards":
			game_manager.void_shards_count -= normalized_amount
	save_progress(save_manager)

func add_currency(game_manager, save_manager, currency_type: String, amount: int) -> void:
	var normalized_amount: int = maxi(0, amount)
	match currency_type:
		"crystals":
			game_manager.crystal_count += normalized_amount
			game_manager.crystals_collected_this_level += normalized_amount
		"coins":
			game_manager.coin_count += normalized_amount
			game_manager.coins_collected_this_level += normalized_amount
		"void_shards":
			game_manager.void_shards_count += normalized_amount
			# Preserve current behavior: shard gains are persisted immediately.
			save_progress(save_manager)
