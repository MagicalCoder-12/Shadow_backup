extends BaseShip

# Ship5: Umbra Wraith - 11 textures total (base + 10 upgrades)

func _ready():
	# Configure texture scales for Ship5
	base_texture_scale = Vector2(1.0, 1.0)
	# You can specify scales for each upgrade, or let default_evolution_scale handle the rest
	evolution_texture_scales = [
		Vector2(1.0, 1.0),  # upgrade_1
		Vector2(1.0, 1.0),  # upgrade_2
		Vector2(1.0, 1.0),  # upgrade_3
		Vector2(1.0, 1.0),  # upgrade_4
		Vector2(1.0, 1.0),  # upgrade_5
		# upgrades 6-10 will use default_evolution_scale
	]
	default_evolution_scale = Vector2(1.0, 1.0)  # Applied to upgrades beyond the array
	
	super._ready()
