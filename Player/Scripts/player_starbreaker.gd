extends Player

func _ready() -> void:
	speed = 1800.0
	base_bullet_damage = 25
	super._ready()

# Optional: Override shoot for a unique attack pattern
func shoot() -> void:
	# Custom shooting logic here, e.g., triple shot
	pass
