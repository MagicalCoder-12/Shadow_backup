extends Area2D

@export var speed: float = 500
var EBulletEffect := preload("res://Bullet/EnemyBulletEffect.tscn")

func _on_area_entered(area: Area2D) -> void:
	if area is Player:
		var bulletEffect := EBulletEffect.instantiate()
		bulletEffect.position = position
		get_parent().add_child(bulletEffect)
		
		area.damage(1)
		queue_free()

func _physics_process(delta):
	position.y += speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
