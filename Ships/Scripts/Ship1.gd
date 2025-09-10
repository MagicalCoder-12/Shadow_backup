extends BaseShip

# Ship1: NoctiSol - Uses export variables for easy scaling configuration

func _ready():
	# Configure texture scales for Ship1
	# base_texture_scale can be set in the editor or here
	base_texture_scale = Vector2(1.5, 1.5)
	evolution_texture_scales = [Vector2(1.0, 1.0), Vector2(1.0, 1.0)]  # upgrade_1, upgrade_2
	default_evolution_scale = Vector2(1.0, 1.0)
	
	super._ready()
