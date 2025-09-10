extends BaseShip

# Ship4: Phantom Drake - 5 textures total (base + 4 upgrades)

func _ready():
	# Configure texture scales for Ship4
	base_texture_scale = Vector2(1.0, 1.0)  # Different scale for Ship4
	evolution_texture_scales = [
		Vector2(1.0, 1.0),  # upgrade_1
		Vector2(2.5, 2.5),  # upgrade_2
		Vector2(1.0, 1.0),  # upgrade_3
		Vector2(1.0, 1.0)   # upgrade_4
	]
	default_evolution_scale = Vector2(1.0, 1.0)
	
	super._ready()
