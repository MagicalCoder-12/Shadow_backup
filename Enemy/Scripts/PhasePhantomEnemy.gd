class_name PhasePhantomEnemy
extends Enemy

const PHASE_PHANTOM_ABILITY_SERVICE_SCRIPT := preload("res://Enemy/Scripts/Services/PhasePhantomAbilityService.gd")

var _phase_phantom_ability_service: PhasePhantomAbilityService = PHASE_PHANTOM_ABILITY_SERVICE_SCRIPT.new()

func reset_enemy_type_state() -> void:
	_phase_phantom_ability_service.reset()

func setup_formation_entry(config: WaveConfig, index: int, formation_pos: Vector2, delay: float = 0.0):
	super.setup_formation_entry(config, index, formation_pos, delay)
	_phase_phantom_ability_service.on_setup(self)
