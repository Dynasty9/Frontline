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
	log.tick(HudToasts.LIFE_LOUD - 0.1)
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
	# only a few lines at once, and the same news again counts on one line
	for i in 5:
		log.push("info", "Squad %s ready." % "ABCDE"[i])
	assert(log.items.size() == HudToasts.MAX_LINES)
	log.items.clear()
	log.push("alert", "The supply truck from Ruvel was destroyed at E6 with 120 supply aboard!")
	log.push("alert", "The supply truck from Ilmen was destroyed at D4 with 80 supply aboard!")
	assert(log.items.size() == 2)
	log.push("alert", "The supply truck from Ilmen was destroyed at D5 with 90 supply aboard!")
	assert(log.items.size() == 2 and int(log.items[0][6]) == 2)
	# a warning outlasts newer routine news when the lines run out
	log.items.clear()
	log.push("alert", "FOB Bravo is under attack at E5!")
	for i in 4:
		log.push("info", "Squad %s ready." % "ABCD"[i])
	var kept := false
	for it in log.items:
		kept = kept or it[0] == "alert"
	assert(kept)
	print("TOAST_DRAWING passed")
	get_tree().quit()
