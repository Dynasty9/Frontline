extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(44100)
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	var player := AudioStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	for frame in 30: await process_frame
	assert(player.playing, "Audio cleanup probe never started playback")
	if "--drain-audio" in OS.get_cmdline_user_args():
		assert(not Engine.get_write_movie_path().is_empty(), "Drain probe requires Movie Maker mode")
		paused = true
		player.stop()
		player.stream = null
		for frame in 2: await process_frame
	quit()
