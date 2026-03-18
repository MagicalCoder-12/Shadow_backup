extends Area2D

@export var speed: float = 1200
@export var damage: int = 1
var EBulletEffect := preload("res://Bullet/Ebullet/EnemyBulletEffect.tscn")

func _on_area_entered(area: Area2D) -> void:
	if area is Player:
		if area.has_method("is_just_revived") and area.is_just_revived():
			return
		if area.has_method("damage"):
			set_meta("direct_damage_applied", true)
			area.damage(damage)
		var bulletEffect := EBulletEffect.instantiate()
		bulletEffect.position = position
		get_parent().add_child(bulletEffect)
		queue_free()

func _physics_process(delta):
	position.y += speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
