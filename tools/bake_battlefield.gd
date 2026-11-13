extends Node
## Run as a scene so the ordinary autoloads and world construction stay in use.

var args := {}


func _ready() -> void:
	OS.set_environment("FL_DEBUG_LOAD", "1")
	var key := OS.get_environment("FL_BAKE_BATTLEFIELD")
	if key.is_empty():
		key = "all"
	var entry := Battlefields.find(key)
	if entry.is_empty() and key != "all":
		push_error("FL_BAKE_BATTLEFIELD must name a catalogue battlefield or all")
		get_tree().quit(1)
		return
	for selected: Dictionary in (Battlefields.MAPS if key == "all" else [entry]):
		print("BATTLEFIELD_BAKE starting key=%s" % selected.key)
		var world := World.new()
		world.name = "World"
		world.settings = {"seed": selected.seed, "map_size": selected.size, "battlefield": selected.key, "bake_battlefield": selected.key, "players": {}, "ai_teams": []}
		add_child(world)
		await world.build()
		var saved := BattlefieldMap.read(selected.key)
		print("BATTLEFIELD_BAKE key=%s valid=%s structures=%d" % [selected.key, not saved.is_empty(), world.structures.size()])
		world.free()
		if saved.is_empty():
			get_tree().quit(1)
			return
	get_tree().quit()
