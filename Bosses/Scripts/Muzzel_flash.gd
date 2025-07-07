extends Node2D

@onready var particles := $CPUParticles2D

func _ready():
	particles.restart()
	await get_tree().create_timer(5.5).timeout
	queue_free() # auto-destroy after firing
