extends BaseShip

# Ship8: Void Serpent - A serpentine vessel that strikes from the void
# SSR rank ship with 5 evolution stages (max_evolution_stage corrected)

func _ready():
	# Configure texture scales for Ship8 (SSR ship with standard 1.0x scaling)
	base_texture_scale = Vector2(1.0, 1.0)
	evolution_texture_scales = [
		Vector2(1.0, 1.0),  # upgrade_1
		Vector2(1.0, 1.0),  # upgrade_2
		Vector2(1.0, 1.0),  # upgrade_3
		Vector2(1.0, 1.0),  # upgrade_4
		Vector2(1.0, 1.0)   # upgrade_5
	]
	default_evolution_scale = Vector2(1.0, 1.0)
	
	super._ready()
	_apply_ship_specific_stats()

func _apply_ship_specific_stats() -> void:
	# Don't override damage if it was already set by the upgrade system
	# Only set damage if it hasn't been initialized yet (i.e., still at default value)
	if base_bullet_damage == 20:  # Default damage from Player.gd
		# Get the actual damage from the ship data instead of hardcoding
		var ship_data = null
		for ship in GameManager.ships:
			if ship.get("id", "") == ship_id:
				ship_data = ship
				break
		
		if ship_data:
			base_bullet_damage = ship_data.get("damage", 55)
		else:
			base_bullet_damage = 55  # Fallback to SSR ship damage
	
	_debug_log("Applied Ship8 specific stats: damage=%d, speed=%.1f" % [base_bullet_damage, speed])