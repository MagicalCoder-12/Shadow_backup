extends Control

@export var progress_bar: TextureProgressBar
@export var percentage_label: Label

var target_scene_path: String = ""
var loading_finished: bool = false
var min_loading_time: float = 1.0  # Minimum time to show loader (for smooth UX)
var loading_start_time: float

func start_load(scene_path: String):
	target_scene_path = scene_path
	loading_start_time = Time.get_ticks_msec()
	
	# Mute audio before loading starts
	if AudioManager:
		var current_scene = get_tree().current_scene
		if current_scene:
			AudioManager.stop_scene_audio_players(current_scene)
		# Mute Bullet bus for start screen or map scene
		if scene_path == "res://MainScenes/start_menu.tscn" or scene_path == "res://Map/map.tscn":
			AudioManager.mute_bus("Bullet", true)
	else:
		push_warning("AudioManager not found. Audio will not be muted during scene load.")
	
	ResourceLoader.load_threaded_request(target_scene_path)
	set_process(true)

func _process(_delta):
	var load_status = ResourceLoader.load_threaded_get_status(target_scene_path)
	var progress_array = []
	
	match load_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get_status(target_scene_path, progress_array)
			if progress_array.size() > 0:
				update_progress(progress_array[0])
				
		ResourceLoader.THREAD_LOAD_LOADED:
			# Ensure minimum loading time has passed
			var elapsed = (Time.get_ticks_msec() - loading_start_time) / 1000.0
			if elapsed >= min_loading_time:
				complete_loading()
			else:
				update_progress(1.0) # Show 100% while waiting
				
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Error loading scene: ", target_scene_path)
			queue_free()

func update_progress(value: float):
	progress_bar.value = value * 100
	percentage_label.text = "%d%%" % (value * 100)

func complete_loading():
	var scene = ResourceLoader.load_threaded_get(target_scene_path)
	if scene:
		get_tree().change_scene_to_packed(scene)
	call_deferred("queue_free")
