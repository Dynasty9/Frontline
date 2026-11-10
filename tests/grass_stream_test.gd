extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var grass := Grass.new()
	grass.HALF = 1536.0
	grass._stream(Vector3.ZERO)
	check(grass._queue.size() == 361, "Large maps must queue only nearby cosmetic chunks")
	check(grass._queue.front() == Vector2i.ZERO, "Nearest grass must build first")
	for key in grass._queue:
		grass._built[key] = []
	grass._queue.clear()
	grass._stream(Vector3(32, 0, 0))
	check(grass._queue.size() == 19, "Panning one chunk must reuse resident grass")
	grass._stream(Vector3.ZERO)
	check(grass._queue.is_empty(), "Panning back must reuse resident chunks")
	grass._stream(Vector3(1400, 0, 1400))
	check(grass._built.is_empty() and grass._queue.size() <= 361, "Distant chunks must be evicted and new work bounded")
	for key: Vector2i in grass._queue:
		check(key.x < 48 and key.y < 48, "Streaming must stay inside map bounds")
	grass._clear()
	grass._stream(Vector3.ZERO)
	check(grass._queue.size() == 361, "Settings rebuilds must repopulate the current camera area")
	# Conservatively complete one chunk per frame (the production cap is two).
	for key in grass._queue:
		grass._built[key] = []
	grass._queue.clear()
	for frame in 500:
		var pos := Vector3(frame * 1.92, 0, frame * 1.92) / sqrt(2.0)
		grass._stream(pos)
		if not grass._queue.is_empty():
			grass._built[grass._queue.pop_front()] = []
		for key: Vector2i in grass._queue:
			var corner := Vector2(key) * Grass.CHUNK
			var nearest := Vector2(clampf(pos.x, corner.x, corner.x + Grass.CHUNK), clampf(pos.z, corner.y, corner.y + Grass.CHUNK))
			check(nearest.distance_to(Vector2(pos.x, pos.z)) >= 170.0, "Vegetation inside the largest fade distance must be ready during a capped diagonal pan")
	grass.free()
	print("GRASS_STREAM_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
