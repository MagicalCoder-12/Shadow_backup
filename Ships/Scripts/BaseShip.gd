extends Player
class_name BaseShip

# Base ship class that handles common evolution scaling logic
# All ship scripts should extend this instead of Player directly

# Export variables for easy texture scaling configuration
@export var base_texture_scale: Vector2 = Vector2(1.0, 1.0)
@export var evolution_texture_scales: Array[Vector2] = []
@export var default_evolution_scale: Vector2 = Vector2(1.0, 1.0)

func _ready():
	super._ready() # ✅ Important: this calls the base _ready()
	_handle_evolution_scaling()

func _handle_evolution_scaling():
	"""Handle common scaling logic for evolution stages with flexible texture support"""
	if evolution_textures.size() > 0 and sprite_2d:
		var current_texture = sprite_2d.texture
		var texture_index = -1
		
		# Find which texture is currently active
		for i in range(evolution_textures.size()):
			if current_texture == evolution_textures[i]:
				texture_index = i
				break
		
		if texture_index >= 0:
			_apply_texture_scale(texture_index)

func _apply_texture_scale(texture_index: int):
	"""Apply appropriate scale based on texture index"""
	if texture_index == 0:
		# Base texture - use base_texture_scale or override method
		sprite_2d.scale = base_texture_scale
		_set_base_texture_scale()  # Allow override in child classes
	elif texture_index < evolution_texture_scales.size():
		# Use specific scale from evolution_texture_scales array
		sprite_2d.scale = evolution_texture_scales[texture_index - 1]
	else:
		# Use default evolution scale for textures beyond configured scales
		sprite_2d.scale = default_evolution_scale

func _set_base_texture_scale():
	"""Set the scale for base texture - can be overridden by child classes"""
	# This method can be overridden, but base_texture_scale export var takes precedence
	# Only override if you need complex scaling logic
	pass

func setup_texture_scales(base_scale: Vector2, evolution_scales: Array[Vector2] = [], default_scale: Vector2 = Vector2(1.0, 1.0)):
	"""Helper method to easily configure texture scales programmatically"""
	base_texture_scale = base_scale
	evolution_texture_scales = evolution_scales
	default_evolution_scale = default_scale
	# Reapply scaling if already initialized
	if sprite_2d and evolution_textures.size() > 0:
		_handle_evolution_scaling()
