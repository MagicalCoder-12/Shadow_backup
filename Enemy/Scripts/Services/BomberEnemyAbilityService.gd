extends RefCounted
class_name BomberEnemyAbilityService

const BOMB_DROP_COOLDOWN: float = 4.0
const MAX_BOMBS_PER_ENEMY: int = 1

var _last_bomb_drop_time: float = 0.0
var _bombs_dropped: int = 0

func reset() -> void:
	_last_bomb_drop_time = 0.0
	_bombs_dropped = 0

func can_drop_bomb(elapsed_time: float) -> bool:
	if _bombs_dropped >= MAX_BOMBS_PER_ENEMY:
		return false
	if elapsed_time - _last_bomb_drop_time < BOMB_DROP_COOLDOWN:
		return false
	return true

func register_bomb_drop(elapsed_time: float) -> void:
	_bombs_dropped += 1
	_last_bomb_drop_time = elapsed_time
