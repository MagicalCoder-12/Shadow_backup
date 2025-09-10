extends Sprite2D
class_name EffectBase

# Base class for all effect animations
# Consolidates common functionality between BulletEffect and Enemy_Bullet_Effect

func _on_timer_timeout():
	"""Standard cleanup function for effects"""
	queue_free()