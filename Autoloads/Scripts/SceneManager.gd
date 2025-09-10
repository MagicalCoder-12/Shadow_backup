extends Node


var gm: Node
const LOADER_SCENE: PackedScene = preload("res://Autoloads/screen_loader.tscn")
const MAP_SCENE: String = "res://Map/map.tscn"
const START_SCREEN_SCENE: String = "res://MainScenes/start_menu.tscn"
const UPGRADE_MENU: String = "res://MainScenes/upgrade_menu.tscn"
const VIDEO_SCENE: String = "res://UI/VideoPlayback.tscn"
const BACKGROUND_MUSIC: AudioStream = preload("res://Textures/Music/Start.ogg")

func _ready() -> void:
	gm = GameManager
	# Defer initialization until all autoloads are ready
	call_deferred("initialize")

func initialize() -> void:
	AudioManager.play_background_music(BACKGROUND_MUSIC, false)

func change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Scene not found: %s" % scene_path)
		return
	
	gm.scene_change_started.emit()
	var root: Node = gm.get_tree().current_scene
	
	if root:
		for child in root.get_children():
			if child.name == "LoaderCanvasLayer" or child.name == "VideoPlaybackLayer":
				continue
		
		var loader: Node = LOADER_SCENE.instantiate()
		loader.name = "LoaderCanvasLayer"
		root.add_child(loader)
		
		# Mute all buses except Background and Master
		for bus in AudioServer.bus_count:
			var bus_name = AudioServer.get_bus_name(bus)
			if bus_name != "Background" and bus_name != "Master":
				AudioServer.set_bus_mute(bus, true)
		
		if gm.ad_manager.is_initialized:
			gm.ad_manager.hide_banner_ad()
		
		loader.start_load(scene_path)

func handle_node_added(node: Node) -> void:
	if node is Control and node.name == "LoaderCanvasLayer":
		node.z_index = 100
	
	if node == gm.get_tree().current_scene:
		var scene_path = node.scene_file_path if node.scene_file_path else ""
		
		if scene_path == START_SCREEN_SCENE or scene_path == MAP_SCENE:
			AudioManager.play_background_music(BACKGROUND_MUSIC, false)
			if AudioManager.background_player:
				AudioManager.background_player.stream.loop = true
				AudioManager.background_player.stream_paused = false
			
			AudioManager.mute_bus("Bullet", true)
			AudioManager.mute_bus("Explosion", true)
			
			if gm.ad_manager.is_initialized:
				gm.ad_manager.show_banner_ad()
		else:
			if AudioManager.background_player:
				AudioManager.background_player.stream.loop = false
			
			AudioManager.mute_bus("Bullet", false)
			AudioManager.mute_bus("Explosion", false)
			
			if gm.ad_manager.is_initialized:
				gm.ad_manager.hide_banner_ad()
