extends Node

var rng := RandomNumberGenerator.new()
var checks := 0


func make_world(native: bool) -> World:
	var w := World.new()
	w.has_view = true
	w.settings = {"seed": 731, "gdscript_water": not native}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	return w


func compare(a: World, b: World, label: String) -> void:
	assert(a.terrain.base == b.terrain.base, "Water kinds " + label)
	assert(a.water.deck == b.water.deck, "Bridge decks " + label)
	assert(a.water.mask.get_data() == b.water.mask.get_data(), "Water mask " + label)
	for i in a.terrain.dh.size():
		assert(absf(a.terrain.dh[i] - b.terrain.dh[i]) < 0.000001, "Water height %s sample=%d ref=%.9f rust=%.9f" % [label, i, a.terrain.dh[i], b.terrain.dh[i]])
	for key in ["cov", "cdir", "version"]:
		assert(a.terrain.get(key) == b.terrain.get(key), "Water terrain " + key + label)
	checks += 1


func shapes(trial: int) -> Dictionary:
	var coast := {"x": rng.randf_range(-35, 35), "s": rng.randf_range(0, 100)} if trial % 3 != 0 else {}
	var rivers := []
	for river in range(trial % 3 + 1):
		var pts := PackedVector3Array()
		for p in 9:
			pts.append(Vector3(rng.randf_range(-38, 38), 0, -60 + p * 15))
		rivers.append({"pts": pts, "w": rng.randf_range(6, 20)})
	var ponds := []
	for p in 3:
		ponds.append({"c": Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60)), "r": rng.randf_range(1, 20), "s": rng.randf_range(0, 50)})
	var bridges := []
	for b in 4:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		bridges.append([p, p + Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)), rng.randf_range(1, 5), "quay" if b % 3 == 0 else "bridge"])
	return {"coast": coast, "rivers": rivers, "ponds": ponds, "fords": [Vector3(-12, 0, -5), Vector3(15, 0, 10)], "bridges": bridges}


func worker_load(w: World) -> void:
	w.water.paint_kinds()
	w.water.carve()


func benchmark(a: World, b: World) -> void:
	var samples := [[], []]
	for round in 8:
		for mode in ([0, 1] if round % 2 == 0 else [1, 0]):
			var w: World = a if mode == 0 else b
			w.terrain.base.fill(0)
			w.terrain.dh.fill(0)
			w.terrain.begin_ground_import()
			w.terrain.end_ground_import()
			var start := Time.get_ticks_usec()
			w.water.paint_kinds()
			w.water.carve()
			if round > 1:
				samples[mode].append((Time.get_ticks_usec() - start) / 1000.0)
	print("WATER_BENCH cells=", TerrainMap.N * TerrainMap.N, " gdscript_ms=", samples[0], " rust_ms=", samples[1])


func _ready() -> void:
	assert(ClassDB.class_exists("WaterRaster"))
	TerrainMap.N = 96
	TerrainMap.H = 48.0
	TerrainMap.DN = 192
	MapDims.N = 96
	MapDims.HALF = 48.0
	MapDims.SIZE = 96.0
	MapDims.BIOME = 96
	rng.seed = 51671
	var a := make_world(false)
	var b := make_world(true)
	var queries := 0
	for trial in 12:
		var data := shapes(trial)
		for w in [a, b]:
			w.water.from_dict(data)
			w.water.paint_kinds()
			w.water.carve()
		compare(a, b, "pass=%d" % trial)
		var native := b.water._raster_core()
		var saved: PackedByteArray = native.checkpoint()
		assert(native.restore(saved) and native.checkpoint() == saved)
		var invalid := saved.duplicate()
		invalid[4] = 2
		assert(not native.restore(invalid) and native.checkpoint() == saved)
		for q in 200:
			var p := Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80))
			if not a.water.coast.is_empty():
				assert(absf(a.water.coast_x(p.z) - float(native.coast_x(p.z))) < 0.000000001, "Coastline")
			var flow: Vector3 = native.current(p)
			assert(a.water.current_at(p).distance_to(flow) < 0.000001, "River flow")
			assert(a.water._in_bridge(p.x, p.z, 0.6) == native.in_bridge(p.x, p.z, 0.6), "Bridge geometry")
			queries += 1
	# The native worker owns numeric arrays; all Godot bindings stay on the main thread.
	a.terrain.begin_ground_import()
	var task := WorkerThreadPool.add_task(worker_load.bind(a))
	WorkerThreadPool.wait_for_task_completion(task)
	a.terrain.end_ground_import()
	b.terrain.begin_ground_import()
	var loader := b.water.begin_loading(PackedByteArray())
	assert(loader != null)
	while not loader.loading_ready():
		await get_tree().process_frame
	b.water.finish_loading(loader)
	b.terrain.end_ground_import()
	compare(a, b, "worker load")
	assert(a.terrain.deform_img.get_data() == b.terrain.deform_img.get_data(), "Worker height texture")
	if "--water-bench" in OS.get_cmdline_user_args():
		benchmark(a, b)
	a.free()
	b.free()
	print("NATIVE_WATER passed rasters=", checks, " queries=", queries)
	get_tree().quit()
