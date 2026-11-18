extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var host := HostSetup.new()
	add_child(host)
	var picker: BattlefieldPicker = host._rows.battlefield.find_children("*", "OptionButton", true, false)[0]
	var requests := []
	host.host_requested.connect(func(options: Dictionary): requests.append(options))
	for i in Battlefields.MAPS.size():
		var entry: Dictionary = Battlefields.MAPS[i]
		picker.select(i)
		picker.item_selected.emit(i)
		host._go()
		check(requests[-1].battlefield == entry.key, "Hosting must carry the selected battlefield")
		var options := Battlefields.options(entry.key)
		check(options.fixed_seed == entry.seed and options.map_size == entry.size, "Map choices must carry their authored seed and size")
	host._pick_mode("mission")
	check(not host._rows.battlefield.visible, "Campaign missions must hide the battlefield choice")
	host._go()
	check(requests[-1].battlefield == "" and requests[-1].mission != "", "Campaign missions must retain their own map")
	host._pick_mode("coop")
	check(host._rows.battlefield.visible and host._battlefield == Battlefields.MAPS[-1].key, "Returning to skirmish must preserve the map selection")
	check(Battlefields.options("../missing").is_empty(), "Unknown map keys must not become file paths")
	picker.select_key("missing")
	check(picker.selected == -1, "Unknown map selections must not claim a different map")
	check(not ResourceLoader.has_cached(GameScripts.WORLD), "The map picker must not compile the game before the title")
	host.free()
	print("BATTLEFIELD_PICKER_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
