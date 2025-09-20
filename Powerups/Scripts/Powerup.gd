class_name Powerup
extends Area2D

enum PowerupType {
	ATTACK_BOOST,
	SUPER_MODE,
	LIFE  # New: Added LIFE powerup type
}

@export var powerup_type: PowerupType = PowerupType.ATTACK_BOOST
@export var powerupMoveSpeed: float = 500
@export var damage_increase_amount: int = 10
@export var super_mode_multiplier: float = 1.5  # Reduced from 2.0 to 1.5
@export var super_mode_duration: float = 5.0
@export var life_increase_amount: int = 1  # New: Amount to increase player life

func _physics_process(delta: float) -> void:
	position.y += powerupMoveSpeed * delta

func applyPowerup(player: Player):
	match powerup_type:
		PowerupType.ATTACK_BOOST:
			player.increase_bullet_damage(damage_increase_amount)
		PowerupType.SUPER_MODE:
			# Check if shadow mode is already active to apply combined mode
			if GameManager.player_manager.player_stats.get("is_shadow_mode_active", false):
				# Activate combined mode
				player.activate_super_mode(super_mode_multiplier, super_mode_duration)
			else:
				# Activate normal super mode
				player.activate_super_mode(super_mode_multiplier, super_mode_duration)
		PowerupType.LIFE:
			player.increase_life(life_increase_amount)
	queue_free()

func _on_VisibilityNotifier2D_screen_exited() -> void:
	queue_free()
