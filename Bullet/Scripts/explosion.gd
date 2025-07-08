extends Area2D

@onready var explosion_anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Connect the finished signal to call _on_explosion_finished
	explosion_anim.animation_finished.connect(_on_explosion_finished)
	
	# Start the animation if not auto-playing
	explosion_anim.play()

func _on_explosion_finished() -> void:
	queue_free()
