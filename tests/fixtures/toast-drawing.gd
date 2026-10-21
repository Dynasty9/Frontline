extends Node

class Log extends HudToasts:
	var draws := 0
	func _draw_content() -> void:
		draws += 1

func flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	var log := Log.new()
	add_child(log)
	await flush()
	log.push("alert", "Contact")
	await flush()
	var count := log.draws
	assert(count > 0)
	log.tick(0.07)
	await flush()
	assert(log.draws > count)
	log.tick(0.3)
	await flush()
	count = log.draws
	log.tick(1.0)
	await flush()
	assert(log.draws == count)
	log.push("alert", "Contact")
	await flush()
	assert(log.draws > count and log.items.size() == 1 and log.items[0][2] == 0.0)
	log.tick(9.9)
	await flush()
	count = log.draws
	log.tick(0.05)
	await flush()
	assert(log.draws > count)
	count = log.draws
	log.tick(0.2)
	await flush()
	assert(log.items.is_empty() and log.draws > count)
	count = log.draws
	log.tick(1.0)
	await flush()
	assert(log.draws == count)
	print("TOAST_DRAWING passed")
	get_tree().quit()
