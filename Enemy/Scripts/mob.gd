extends Enemy
class_name Mob

func _ready():
	super._ready()
	fire_rate = 3.0	
	fire_timer.wait_time = fire_rate
	fire_timer.start()
