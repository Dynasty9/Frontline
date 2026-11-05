extends Node

func _ready() -> void:
	var audio: Node = load("res://scripts/autoload/sfx.gd").new()
	add_child(audio)
	var finished := [false, false, false, false]
	var lock := Mutex.new()
	audio._synth = WorkerThreadPool.add_group_task(func(index: int):
		OS.delay_msec(5)
		lock.lock()
		finished[index] = true
		lock.unlock(), finished.size())
	remove_child(audio)
	assert(finished.all(func(done): return done), "Leaving the scene must join every audio synthesis worker before freeing its owner")
	assert(audio._synth == -1)
	audio.free()
	print("AUDIO_SHUTDOWN passed")
	get_tree().quit()
