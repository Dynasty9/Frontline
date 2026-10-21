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
	check(grass._queue.size() == 225, "Large maps must queue only nearby cosmetic chunks")
	check(grass._queue.front() == Vector2i.ZERO, "Nearest grass must build first")
	for key in grass._queue:
		grass._built[key] = []
	grass._queue.clear()
	grass._stream(Vector3(32, 0, 0))
	check(grass._queue.size() == 15, "Panning one chunk must reuse resident grass")
	grass._stream(Vector3(1400, 0, 1400))
	check(grass._built.is_empty() and grass._queue.size() <= 225, "Distant chunks must be evicted and new work bounded")
	for key: Vector2i in grass._queue:
		check(key.x < 48 and key.y < 48, "Streaming must stay inside map bounds")
	grass._clear()
	grass._stream(Vector3.ZERO)
	check(grass._queue.size() == 225, "Settings rebuilds must repopulate the current camera area")
	grass.free()
	print("GRASS_STREAM_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
