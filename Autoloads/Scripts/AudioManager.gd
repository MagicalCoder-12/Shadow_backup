extends Node

# Persistent audio player for background music
var background_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Audio bus indices
var background_bus_idx: int = AudioServer.get_bus_index("Background")
var bullet_bus_idx: int = AudioServer.get_bus_index("Bullet")
var boss_bus_idx: int = AudioServer.get_bus_index("Boss")
var explosion_bus_idx: int = AudioServer.get_bus_index("Explosion")
var video_bus_idx: int = AudioServer.get_bus_index("Video")

# Current background music stream
var current_background_music: AudioStream

# Store original bus volumes for restoration
var _original_bus_volumes: Dictionary = {}

func _ready() -> void:
	# Validate bus indices
	if background_bus_idx == -1: push_error("Background bus not found")
	if bullet_bus_idx == -1: push_error("Bullet bus not found")
	if boss_bus_idx == -1: push_error("Boss bus not found")
	if explosion_bus_idx == -1: push_error("Explosion bus not found")
	if video_bus_idx == -1: push_error("Video bus not found")
	
	# Configure background music player
	background_player.bus = "Background"
	add_child(background_player)
	print("AudioManager initialized with background player on Background bus")

func play_background_music(stream: AudioStream, force_restart: bool = false) -> void:
	if not stream:
		push_error("No audio stream provided for background music")
		return
	if not is_inside_tree() or not background_player.is_inside_tree():
		# Defer playback until in scene tree
		call_deferred("play_background_music", stream, force_restart)
		return
	if current_background_music == stream and background_player.playing and not force_restart:
		print("Background music already playing: ", stream.resource_path)
		return
	current_background_music = stream
	background_player.stream = stream
	background_player.play()
	AudioServer.set_bus_mute(background_bus_idx, false) # Ensure unmuted
	print("Playing background music: ", stream.resource_path)

func stop_background_music() -> void:
	background_player.stop()
	current_background_music = null
	print("Background music stopped")

func play_sound_effect(stream: AudioStream, bus: String) -> void:
	if not stream:
		push_error("No audio stream provided for sound effect")
		return
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.stream = stream
	player.finished.connect(player.queue_free) # Auto-free when done
	add_child(player)
	player.play()


func mute_audio_buses(mute: bool, exclude_video: bool = false) -> void:
	if background_bus_idx >= 0:
		AudioServer.set_bus_mute(background_bus_idx, mute)
		print("Background bus muted: ", mute)
	if bullet_bus_idx >= 0:
		AudioServer.set_bus_mute(bullet_bus_idx, mute)
		print("Bullet bus muted: ", mute)
	if boss_bus_idx >= 0:
		AudioServer.set_bus_mute(boss_bus_idx, mute)
		print("Boss bus muted: ", mute)
	if explosion_bus_idx >= 0:
		AudioServer.set_bus_mute(explosion_bus_idx, mute)
		print("Explosion bus muted: ", mute)
	if exclude_video and video_bus_idx >= 0:
		AudioServer.set_bus_mute(video_bus_idx, false)
		print("Video bus unmuted (excluded)")

func lower_bus_volumes_except(exclude_buses: Array[String], volume_db: float) -> void:
	_original_bus_volumes = {}
	for bus_idx in AudioServer.bus_count:
		var bus_name = AudioServer.get_bus_name(bus_idx)
		if bus_name not in exclude_buses:
			_original_bus_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_idx)
			AudioServer.set_bus_volume_db(bus_idx, volume_db)
			print("Lowered volume of bus %s to %s dB" % [bus_name, volume_db])
		else:
			print("Skipped bus %s" % bus_name)

func restore_bus_volumes() -> void:
	for bus_name in _original_bus_volumes:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			AudioServer.set_bus_volume_db(bus_idx, _original_bus_volumes[bus_name])
			print("Restored volume of bus %s to %s dB" % [bus_name, _original_bus_volumes[bus_name]])
	_original_bus_volumes.clear()

func stop_scene_audio_players(root: Node) -> void:
	if root:
		# Recursively find and stop all audio players
		var nodes = [root]
		while nodes:
			var node = nodes.pop_front()
			if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
				node.stop()
				print("Stopped audio player: ", node.name)
			nodes.append_array(node.get_children())

func mute_bus(bus_name: String, mute: bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_error("Bus %s not found!" % bus_name)
		return
	AudioServer.set_bus_mute(bus_idx, mute)
	print("Bus %s %s" % [bus_name, "muted" if mute else "unmuted"])
