extends RefCounted
class_name UpgradeSelectionService

const DEFAULT_SATELLITE_ID := "Satellite1"

func _ensure_satellite_slots(player_manager) -> void:
	if not player_manager:
		return
	if player_manager.selected_satellite_ids.size() < 2:
		player_manager.selected_satellite_ids.resize(2)
		player_manager.selected_satellite_ids[0] = DEFAULT_SATELLITE_ID
		player_manager.selected_satellite_ids[1] = DEFAULT_SATELLITE_ID

func _save_progress(game_manager) -> void:
	if game_manager and game_manager.save_manager:
		game_manager.save_manager.save_progress()

func equip_satellite_both(game_manager, player_manager, satellite: Dictionary) -> Dictionary:
	if satellite.is_empty() or not bool(satellite.get("unlocked", false)):
		return {"ok": false}
	var satellite_id := str(satellite.get("id", ""))
	if satellite_id.is_empty():
		return {"ok": false}
	_ensure_satellite_slots(player_manager)
	player_manager.selected_satellite_ids[0] = satellite_id
	player_manager.selected_satellite_ids[1] = satellite_id
	_save_progress(game_manager)
	return {
		"ok": true,
		"message": "%s equipped to both left and right slots" % satellite.get("display_name", "Satellite")
	}

func equip_satellite_left(game_manager, player_manager, satellite: Dictionary) -> Dictionary:
	if satellite.is_empty() or not bool(satellite.get("unlocked", false)):
		return {"ok": false}
	var satellite_id := str(satellite.get("id", ""))
	if satellite_id.is_empty():
		return {"ok": false}
	_ensure_satellite_slots(player_manager)
	player_manager.selected_satellite_ids[0] = satellite_id
	_save_progress(game_manager)
	return {
		"ok": true,
		"message": "%s equipped to left slot" % satellite.get("display_name", "Satellite")
	}

func equip_satellite_right(game_manager, player_manager, satellite: Dictionary) -> Dictionary:
	if satellite.is_empty() or not bool(satellite.get("unlocked", false)):
		return {"ok": false}
	var satellite_id := str(satellite.get("id", ""))
	if satellite_id.is_empty():
		return {"ok": false}
	_ensure_satellite_slots(player_manager)
	player_manager.selected_satellite_ids[1] = satellite_id
	_save_progress(game_manager)
	return {
		"ok": true,
		"message": "%s equipped to right slot" % satellite.get("display_name", "Satellite")
	}

func select_ship(game_manager, ship: Dictionary) -> Dictionary:
	if ship.is_empty() or not bool(ship.get("unlocked", false)):
		return {"ok": false}
	var ship_id := str(ship.get("id", ""))
	if ship_id.is_empty():
		return {"ok": false}
	if game_manager and game_manager.player_manager:
		game_manager.player_manager.selected_ship_id = ship_id
	_save_progress(game_manager)
	return {
		"ok": true,
		"message": "%s selected" % ship.get("display_name", "Ship")
	}
