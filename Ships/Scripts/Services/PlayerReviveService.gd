extends RefCounted
class_name PlayerReviveService

const DEFAULT_BLINK_INTERVAL: float = 0.2

var just_revived: bool = false
var is_blinking: bool = false
var is_revive_shield_active: bool = false
var _pending_post_revive_invincibility: bool = false

var _owner: Node
var _invincibility_timer: Timer
var _animation_player: AnimationPlayer
var _revive_shield: CanvasItem
var _sprite: CanvasItem
var _collision_owner: Node
var _blink_timer: Timer

func configure(owner: Node, invincibility_timer: Timer, animation_player: AnimationPlayer, revive_shield: CanvasItem, sprite: CanvasItem, collision_owner: Node) -> void:
	_owner = owner
	_invincibility_timer = invincibility_timer
	_animation_player = animation_player
	_revive_shield = revive_shield
	_sprite = sprite
	_collision_owner = collision_owner

	if _invincibility_timer and not _invincibility_timer.is_connected("timeout", _on_invincibility_timer_timeout):
		_invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)

func is_invincible() -> bool:
	if just_revived:
		return true
	if _invincibility_timer and not _invincibility_timer.is_stopped():
		return true
	return false

func prepare_revival_state() -> void:
	if _invincibility_timer:
		_invincibility_timer.stop()
	just_revived = true
	_pending_post_revive_invincibility = false
	set_revive_shield_active(false)
	stop_blinking()
	if _sprite:
		_sprite.visible = true
		_sprite.modulate.a = 1.0
	if _collision_owner and _collision_owner.has_method("set_collision_layer_value"):
		_collision_owner.set_collision_layer_value(1, false)
		_collision_owner.set_collision_layer_value(2, false)

func play_revive_animation_then_start_invincibility(duration: float) -> void:
	_pending_post_revive_invincibility = true
	if _animation_player and _animation_player.has_animation("Player_revive"):
		_animation_player.play("Player_revive")
		return
	start_post_revive_invincibility(duration)

func on_animation_finished(anim_name: StringName, duration: float) -> void:
	if anim_name == "Player_revive" and _pending_post_revive_invincibility:
		start_post_revive_invincibility(duration)

func start_damage_invincibility(duration: float) -> void:
	if _invincibility_timer:
		_invincibility_timer.start(duration)
	start_blinking()

func start_post_revive_invincibility(duration: float) -> void:
	_pending_post_revive_invincibility = false
	if _invincibility_timer:
		_invincibility_timer.start(duration)
	set_revive_shield_active(true)
	start_blinking()

func set_revive_shield_active(active: bool) -> void:
	is_revive_shield_active = active
	if _revive_shield:
		_revive_shield.visible = active
		_revive_shield.modulate.a = 1.0

func start_blinking() -> void:
	if is_blinking:
		return
	is_blinking = true
	if not _blink_timer:
		_blink_timer = Timer.new()
		_blink_timer.wait_time = DEFAULT_BLINK_INTERVAL
		_blink_timer.one_shot = false
		_blink_timer.name = "BlinkTimer"
		if _owner:
			_owner.add_child(_blink_timer)
		_blink_timer.timeout.connect(_on_blink_timer_timeout)
	if _sprite:
		_sprite.visible = true
		_sprite.modulate.a = 0.7
	_blink_timer.start()

func stop_blinking() -> void:
	if not is_blinking:
		return
	is_blinking = false
	if _sprite:
		_sprite.modulate.a = 1.0
		_sprite.visible = true
	if _blink_timer:
		_blink_timer.stop()
		_blink_timer.queue_free()
		_blink_timer = null

func _on_blink_timer_timeout() -> void:
	if is_blinking and _sprite:
		_sprite.visible = !_sprite.visible
	if is_blinking and is_revive_shield_active and _revive_shield:
		_revive_shield.visible = !_revive_shield.visible

func _on_invincibility_timer_timeout() -> void:
	just_revived = false
	stop_blinking()
	set_revive_shield_active(false)
	if _sprite:
		_sprite.visible = true
		_sprite.modulate.a = 1.0
	if _collision_owner and _collision_owner.has_method("set_collision_layer_value"):
		_collision_owner.set_collision_layer_value(1, true)
	if _owner and _owner.has_method("_debug_log"):
		_owner._debug_log("Invincibility timer finished, just_revived set to false")
