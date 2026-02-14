extends Node
## Provides safe scene tree manipulation with null guards.
## Replaces raw get_tree().current_scene.add_child() calls to prevent
## null reference errors during scene transitions.

## Spawns a node as a child of the current scene safely.
## Returns the spawned node if successful, null otherwise.
func spawn_child(node: Node, add_to_front: bool = false) -> Node:
	if not node:
		push_warning("SceneSpawnService: Cannot spawn null node")
		return null
	
	var current_scene = _get_safe_current_scene()
	if not current_scene:
		push_warning("SceneSpawnService: Cannot spawn - no valid current scene")
		node.queue_free()
		return null
	
	current_scene.add_child(node, add_to_front)
	return node

## Spawns a node at a specific global position.
func spawn_child_at(node: Node, global_pos: Vector2, add_to_front: bool = false) -> Node:
	if not node:
		push_warning("SceneSpawnService: Cannot spawn null node at position")
		return null
	
	node.global_position = global_pos
	return spawn_child(node, add_to_front)

## Safely gets the current scene with null checks.
func _get_safe_current_scene() -> Node:
	var tree = Engine.get_main_loop()
	if not tree:
		push_warning("SceneSpawnService: No main loop available")
		return null
	
	var current_scene = tree.current_scene
	if not current_scene:
		push_warning("SceneSpawnService: current_scene is null")
		return null
	
	return current_scene

## Checks if a safe spawn is possible.
func can_spawn() -> bool:
	return _get_safe_current_scene() != null
