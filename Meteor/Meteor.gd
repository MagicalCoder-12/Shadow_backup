extends Area2D

var pMeteorEffect := preload("uid://fh5nwi0jt7vx")
@onready var health_bar: TextureProgressBar = get_parent().get_node("HealthBar")
@onready var asteroid_explosion: AudioStreamPlayer = $"../AsteroidExplosion"

@export var minSpeed: float = 400
@export var maxSpeed: float = 600
@export var minRotationRate: float = -10
@export var maxRotationRate: float = 30
@export var score: float = 5000
@export var life: int = 1000
@export var invincible: bool = false  # Optional toggle for debugging or specific obstacles
@export var i_frame_duration: float = 0.1  # How long asteroid is invincible after taking damage

var i_frame_timer := 0.0

var speed: float = 0
var rotationRate: float = 0
var playerInArea: Player = null

# New: Invincibility frame system
var last_hit_time := -1.0
@export var hit_cooldown := 0.25  # seconds of invincibility after hit

func _ready():
	add_to_group(GameManager.GROUP_DAMAGEABLE)
	GameManager.connect("score_updated", Callable(self, "_on_score_updated"))
	
	speed = randf_range(minSpeed, maxSpeed)
	rotationRate = randf_range(minRotationRate, maxRotationRate)
	health_bar.max_value = float(life)
	health_bar.value = float(life)

func _physics_process(delta):
	rotation_degrees += rotationRate * delta
	position.y += speed * delta
	
	# 🔥 Tick down invincibility timer every frame
	if i_frame_timer > 0:
		i_frame_timer -= delta

	if playerInArea != null:
		if GameManager.shadow_mode_enabled:
			damage(life) 
			playerInArea.damage(1)
		else:
			invincible = false
			i_frame_timer = 0.0
			damage(life)
			playerInArea.damage(1)

	update_healthbar(delta)
	health_bar.position = position + Vector2(-200, -300)


func damage(amount: int):
	if life <= 0 or invincible or i_frame_timer > 0:
		return
	
	life -= amount
	i_frame_timer = i_frame_duration  # Reset i-frame cooldown

	
	if life <= 0:
		asteroid_explosion.play()
		health_bar.hide()
		var effect := pMeteorEffect.instantiate()
		effect.position = position
		get_parent().add_child(effect)
		
		var cam := get_tree().current_scene.find_child("Cam", true, false)
		cam.shake(100)
		
		@warning_ignore("narrowing_conversion")
		GameManager.score += score
		GameManager.score_updated.emit(GameManager.score)
		queue_free()


func _on_VisibilityNotifier2D_screen_exited():
	queue_free()

func _on_area_entered(area: Node):
	if area is Player:
		playerInArea = area

func _on_area_exited(area: Node):
	if area is Player:
		playerInArea = null

func update_healthbar(delta):
	if health_bar:
		health_bar.value = lerp(health_bar.value, float(life), delta * 10)
