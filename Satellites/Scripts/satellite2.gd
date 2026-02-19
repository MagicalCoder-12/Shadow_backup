extends "res://Satellites/Scripts/satellite.gd"

func _ready() -> void:
	bullet_scene = preload("res://Bullet/Sat_bullet/Sat_bullet2.tscn")
	behavior_mode = SatelliteBehaviorMode.SHOOT_ONLY
	super._ready()
