extends Area2D

# Add a class variable to track active explosions
static var active_explosions: int = 0
const MAX_ACTIVE_EXPLOSIONS: int = 30  # Limit the number of active explosions

@onready var explosion_anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Check if we've exceeded the explosion limit
	if active_explosions >= MAX_ACTIVE_EXPLOSIONS:
		queue_free()
		return
		
	active_explosions += 1
	
	# Connect the finished signal to call _on_explosion_finished
	explosion_anim.animation_finished.connect(_on_explosion_finished)
	
	# Start the animation if not auto-playing
	explosion_anim.play()

func _on_explosion_finished() -> void:
	active_explosions = max(0, active_explosions - 1)
	queue_free()