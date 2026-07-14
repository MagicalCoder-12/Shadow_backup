extends PlayerBullet

# Piercing rail bullet for Ship4 (Phantom Drake)

var _active_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	super._ready()
	_apply_tint()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_on_screen_exited()

func apply_shadow_tint(tint: Color) -> void:
	_active_tint = tint
	_apply_tint()

func _apply_tint() -> void:
	modulate = _active_tint
