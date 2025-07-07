extends Enemy
class_name Mob

func _ready():
	super._ready()
	if not arrived_at_formation or not firing_positions or not is_alive:
		return
	
	for child in firing_positions.get_children():
		var bullet
		
		# Choose bullet type
		if is_shadow_enemy:
			bullet = ShadowEBullet.instantiate()
		else:
			bullet = EBullet.instantiate()
		
		bullet.global_position = child.global_position
