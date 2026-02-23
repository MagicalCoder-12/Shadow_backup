class_name BomberEnemy
extends Enemy

const BOMBER_ABILITY_SERVICE_SCRIPT := preload("res://Enemy/Scripts/Services/BomberEnemyAbilityService.gd")

var _bomber_ability_service: BomberEnemyAbilityService = BOMBER_ABILITY_SERVICE_SCRIPT.new()

func reset_enemy_type_state() -> void:
	_bomber_ability_service.reset()

func is_bomber_enemy() -> bool:
	return true

func can_drop_bomb(elapsed_time: float) -> bool:
	return _bomber_ability_service.can_drop_bomb(elapsed_time)

func register_bomb_drop(elapsed_time: float) -> void:
	_bomber_ability_service.register_bomb_drop(elapsed_time)
