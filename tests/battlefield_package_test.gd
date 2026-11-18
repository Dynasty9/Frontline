extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	for entry: Dictionary in Battlefields.MAPS:
		var data := BattlefieldMap.read(entry.key)
		check(not data.is_empty(), "Missing, damaged or stale battlefield: " + String(entry.key))
		if data.is_empty():
			continue
		var bad := data.duplicate()
		bad["engine"] = "different engine"
		check(not BattlefieldMap.valid(bad, entry), "Engine-incompatible map data must be rejected")
		bad = data.duplicate()
		bad["seed"] = -1
		check(not BattlefieldMap.valid(bad, entry), "The selected map must match its baked seed")
		bad = data.duplicate()
		bad["terrain"] = {}
		check(not BattlefieldMap.valid(bad, entry), "Incomplete terrain must be rejected before restoration")
		match entry.water:
			"dry":
				check(data.water.coast.is_empty() and data.water.rivers.is_empty() and data.water.ponds.is_empty(), "Highland Junction must retain its dry routes")
			"river":
				check(data.water.coast.is_empty() and not data.water.rivers.is_empty(), "Stonebridge must be an inland river map")
			"coast":
				check(not data.water.coast.is_empty() and not data.water.rivers.is_empty(), "Alder Valley must retain both coastal and river approaches")
		var starts := [0, 0]
		for record: Array in data.structures:
			if record[1].skind == "fob":
				starts[int(record[1].team)] += 1
		check(starts == [1, 1], "Every map must provide a starting FOB for both sides")
		print("BATTLEFIELD_PACKAGE key=%s structures=%d" % [entry.key, data.structures.size()])
	print("BATTLEFIELD_PACKAGE_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
