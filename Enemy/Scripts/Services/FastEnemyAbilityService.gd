extends RefCounted
class_name FastEnemyAbilityService

const ENEMY_MOVEMENT_SERVICE_SCRIPT := preload("res://Enemy/Scripts/Services/EnemyMovementService.gd")

const PATTERN_SINGLE_SHOT: int = 0
const PATTERN_SPREAD_SHOT: int = 1
const PATTERN_BURST_SHOT: int = 2
const PATTERN_AIMED_SHOT: int = 3

func reset() -> void:
	pass

func on_setup(enemy: Enemy) -> void:
	enemy.movement_pattern = ENEMY_MOVEMENT_SERVICE_SCRIPT.MOVE_DIVE
	enemy.normal_pattern_weights[PATTERN_SINGLE_SHOT] = 45
	enemy.normal_pattern_weights[PATTERN_AIMED_SHOT] = 35
	enemy.normal_pattern_weights[PATTERN_SPREAD_SHOT] = 10
	enemy.normal_pattern_weights[PATTERN_BURST_SHOT] = 10
