extends "res://tests/battlefield_map_test.gd"
## Headless attach/build comparison only; no images, gameplay ticks or FPS claims.
func _ready() -> void:
	Online.record_battles = false
	var key := "highland-junction"
	var entry := Battlefields.find(key)
	check(not BattlefieldMap.read(key).is_empty(), "Validated package required")
	if failures:
		get_tree().quit(1)
		return
	var reference := {}
	var results := []
	# Warm both paths, then counterbalance two measured runs per arm.
	var arms := [true, false, false, true, true, false]
	for i in arms.size():
		var generated: bool = arms[i]
		var w := World.new()
		w.name = "World"
		w.settings = {"seed": entry.seed, "map_size": entry.size, "battlefield": key, "no_baked_map": generated,
			"players": {1: {"team": 0, "name": "Fixture"}}, "ai_teams": [1]}
		var started := Time.get_ticks_usec()
		add_child(w)
		await w.build()
		var elapsed := Time.get_ticks_usec() - started
		w.set_physics_process(false)
		w.set_process(false)
		var restored: bool = w.loading_ms.has("cached structures restored")
		check(restored != generated, "Requested path must match observed restoration marker")
		var state := _fingerprint(w)
		if i == 0:
			reference = state
		else:
			for field: String in reference:
				check(reference[field] == state[field], "Arm state differs: " + field)
		var row := {"index": i, "warmup": i < 2, "requested": "generated" if generated else "prepared",
			"observed_cached_structures_restored": restored, "no_baked_map": generated,
			"attach_and_build_us": elapsed, "structures": w.structures.size(), "seed": entry.seed}
		results.append(row)
		print("PAIR_PATH ", JSON.stringify(row))
		w.free()
		await get_tree().process_frame
	var output := OS.get_environment("FL_PAIR_OUTPUT")
	var file := FileAccess.open(output, FileAccess.WRITE)
	check(file != null, "Fresh result output must be writable")
	if file:
		file.store_string(JSON.stringify({"failures": failures, "scope": "headless world attach and build; no rendered loading or FPS measurement", "runs": results}, "  "))
	print("PREPARED_PAIR failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
