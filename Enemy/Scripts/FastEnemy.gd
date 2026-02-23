class_name FastEnemy
extends Enemy

const FAST_ENEMY_ABILITY_SERVICE_SCRIPT := preload("res://Enemy/Scripts/Services/FastEnemyAbilityService.gd")

var _fast_enemy_ability_service: FastEnemyAbilityService = FAST_ENEMY_ABILITY_SERVICE_SCRIPT.new()

func reset_enemy_type_state() -> void:
	_fast_enemy_ability_service.reset()

func setup_formation_entry(config: WaveConfig, index: int, formation_pos: Vector2, delay: float = 0.0):
	super.setup_formation_entry(config, index, formation_pos, delay)
	_fast_enemy_ability_service.on_setup(self)
