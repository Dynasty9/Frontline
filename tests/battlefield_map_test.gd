extends Node

var args := {}
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var key := OS.get_environment("FL_TEST_BATTLEFIELD")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--battlefield="):
			key = arg.trim_prefix("--battlefield=")
	if key.is_empty():
		key = "alder-valley"
	if key == "all":
		for entry: Dictionary in Battlefields.MAPS:
			await _compare(entry.key)
	else:
		await _compare(key)
	print("BATTLEFIELD_MAP_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func _compare(key: String) -> void:
	var entry := Battlefields.find(key)
	var data := BattlefieldMap.read(key)
	check(not data.is_empty(), "A baked map must load before comparing it with generation")
	if data.is_empty():
		return
	check(not BattlefieldMap.valid({}, entry), "Empty packages must be rejected")
	var invalid := data.duplicate()
	invalid["seed"] = -1
	check(not BattlefieldMap.valid(invalid, entry), "Packages must match the selected seed")
	invalid = data.duplicate()
	invalid["terrain"] = {}
	check(not BattlefieldMap.valid(invalid, entry), "Missing terrain arrays must be rejected")
	var reference := {}
	var reference_props := {}
	var changed_reference := {}
	var simulation_reference := {}
	for generated in [true, false]:
		var w := World.new()
		w.name = "World"
		w.settings = {"seed": entry.seed, "map_size": entry.size, "battlefield": key, "no_baked_map": generated,
			"players": {1: {"team": 0, "name": "Test"}, 7: {"team": 0, "name": "Partner"}, 9: {"team": -1, "name": "Observer"}}, "ai_teams": [1]}
		add_child(w)
		var started := Time.get_ticks_msec()
		await w.build()
		if not generated:
			check(w.loading_ms.has("cached structures restored"), "The prepared comparison must exercise restoration, not silently regenerate")
		w.set_physics_process(false)
		w.set_process(false)
		var state := _fingerprint(w)
		print("BATTLEFIELD_LOAD key=%s generated=%s ms=%d structures=%d" % [key, generated, Time.get_ticks_msec() - started, w.structures.size()])
		if generated:
			reference = state
			for e: Entity in w.entities.values():
				reference_props[e.eid] = e.get_props().duplicate(true)
		else:
			for e: Entity in w.entities.values():
				var expected: Dictionary = reference_props.get(e.eid, {})
				var actual := e.get_props()
				for property: String in expected:
					if expected[property] != actual.get(property):
						print("PROPERTY_DIFFERENCE eid=%d field=%s generated=%s baked=%s" % [e.eid, property, expected[property], actual.get(property)])
			for field: String in reference:
				check(reference[field] == state[field], "Baked battlefield differs from generation: " + field)
		var owners := {}
		for squad: Squad in w.squads.values():
			owners[squad.owner] = true
		check(owners.has(1) and owners.has(7) and owners.has(-2) and not owners.has(9), "Fresh forces must belong to current co-commanders and AI, never observers")
		_check_routes(w, key)
		_remove_scenery(w)
		var changed := _fingerprint(w)
		if generated:
			changed_reference = changed
		else:
			for field: String in changed_reference:
				check(changed_reference[field] == changed[field], "Destruction after a cached load differs: " + field)
		for tick in 180:
			w._physics_process(1.0 / 30.0)
		var simulated := _fingerprint(w)
		if generated:
			simulation_reference = simulated
		else:
			for field: String in simulation_reference:
				check(simulation_reference[field] == simulated[field], "Simulation after a cached load differs: " + field)
		print("BATTLEFIELD_SIMULATION key=%s generated=%s ticks=180" % [key, generated])
		w.free()
	_compare_client_ground(entry, data)


func _check_routes(w: World, key: String) -> void:
	var center := w.town_rect.get_center()
	var town := Vector3(center.x, 0, center.y)
	var destination := town
	var nearest := INF
	for road: PackedVector3Array in w.roads[2]:
		for point: Vector3 in road:
			var distance := Defs.flat(point - town).length_squared()
			if distance < nearest:
				nearest = distance
				destination = point
	for st: Structure in w.structures:
		if st.skind != "fob":
			continue
		var start := st.position + (Vector3.FORWARD if st.team == 0 else Vector3.BACK) * 20.0
		for mode in 3:
			var vehicle := mode > 0
			var tracks := mode == 2
			var goal := w.nav.nearest_walkable(destination, vehicle, tracks)
			var route := w.nav.find_path(start, goal, vehicle, -1, 0.0, tracks)
			check(not route.is_empty() and Defs.flat(route[-1] - goal).length() < 2.0,
				"%s team %d movement class %d must reach the central town" % [key, st.team, mode])
	print("BATTLEFIELD_ROUTES key=%s checked both sides and three movement classes" % key)


func _remove_scenery(w: World) -> void:
	for kind: String in ["tree", "house_wall"]:
		for st: Structure in w.structures:
			if st.skind == kind:
				w.despawn(st)
				break
	w.terrain.tick(1 << 30)
	for i in 100:
		if not w.nav.hnav_i.has_work() and not w.nav.hnav_v.has_work() and not w.nav.hnav_t.has_work():
			return
		w.nav.update_hier(256)
	check(false, "Navigation must settle after removing cached scenery")


func _compare_client_ground(entry: Dictionary, data: Dictionary) -> void:
	var reference := {}
	for generated in [true, false]:
		var w := World.new()
		w.srv = false
		w.has_view = true
		w.settings = {"seed": entry.seed, "battlefield": entry.key, "no_baked_map": generated}
		w.terrain = TerrainMap.new(w)
		w._ground_water = WaterMap.new(w)
		w._ground_water.from_dict(data.water)
		w._join_landform = data.heights
		w._join_kinds = data.terrain.base
		var original_image := w.terrain.deform_img
		var started := Time.get_ticks_msec()
		w._ground_job()
		print("BATTLEFIELD_CLIENT_GROUND generated=%s ms=%d" % [generated, Time.get_ticks_msec() - started])
		check(w.terrain.deform_img == original_image, "Ground loading must preserve Atmosphere's Image reference")
		check(w.terrain.deform_dirty.has(Rect2i(0, 0, TerrainMap.DN, TerrainMap.DN)), "Prepared ground must upload all changed height-texture tiles")
		var state := {"height": _hash(w.terrain.dh), "slopes": _hash(w.terrain.slopes),
			"kinds": _hash(w.terrain.base), "texture": _hash(w.terrain.deform_img.get_data()),
			"decks": _hash(w._ground_water.deck), "water mask": _hash(w._ground_water.mask.get_data() if w._ground_water.mask != null else PackedByteArray())}
		if generated:
			reference = state
		else:
			for field: String in reference:
				check(reference[field] == state[field], "Cached client ground differs: " + field)
		w.free()


func _fingerprint(w: World) -> Dictionary:
	var state := {}
	for field: String in BattlefieldMap.BYTES + BattlefieldMap.FLOATS:
		state["terrain/" + field] = _hash(w.terrain.get(field))
	for key: String in ["inf", "veh", "tracked"]:
		var raster: NavRaster = w.nav.get(key)
		state["nav/" + key] = _hash([raster.solid, raster.weight])
	for key: String in ["hnav_i", "hnav_v", "hnav_t"]:
		var graph: HNav = w.nav.get(key)
		for field: String in ["node_cell", "node_cl", "node_base", "mids", "costs", "basis"]:
			state["graph/" + key + "/" + field] = _hash(graph.get(field))
	state["entities"] = _hash(w._build_snapshot(w.entities.values(), -1))
	var props := []
	for e: Entity in w.entities.values():
		props.append([e.eid, e.get_props()])
	state["props"] = _hash(props)
	var cover := []
	for st: Structure in w.structures:
		cover.append([st.eid, st.parts, st.anc_p, st.anc_n, st.anc_h, st.anc_k, st.completed_order])
	state["cover geometry"] = _hash(cover)
	state["rng"] = w.rng.state
	state["roads"] = _hash(w.roads)
	state["decor"] = _hash([w.decor, w.town_rect, w.key_points])
	state["water"] = _hash([w.water.to_dict(), w.water.deck])
	state["ids"] = [w.next_eid, w.next_sid]
	return state


func _hash(value: Variant) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()

