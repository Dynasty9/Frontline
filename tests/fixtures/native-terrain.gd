extends Node

var pair: Array[World] = []
var rng := RandomNumberGenerator.new()
var queries := 0


func import_ground(w: World) -> void:
	var cell := w.terrain.idx_of(Vector3(1, 0, 1))
	w.terrain.base[cell] = TerrainMap.SHALLOW
	w.terrain._refresh_cell(cell)
	w.terrain.dh[1] = -2.0
	w.terrain.sync_deformation()


func benchmark() -> void:
	var cells := PackedInt32Array()
	for i in TerrainMap.N * TerrainMap.N:
		cells.append(i)
	var samples := [[], []]
	for round in 8:
		for i in ([0, 1] if round % 2 == 0 else [1, 0]):
			pair[i].terrain.queue_cells(cells)
			var start := Time.get_ticks_usec()
			pair[i].terrain.tick(1 << 30)
			if round > 1:
				samples[i].append((Time.get_ticks_usec() - start) / 1000.0)
	compare("benchmark cover repairs")
	print("TERRAIN_BENCH cover_cells=", cells.size(), " gdscript_ms=", samples[0], " rust_ms=", samples[1])


func compare(label: String) -> void:
	var a := pair[0].terrain
	var b := pair[1].terrain
	for key in ["base", "crater", "rubble", "woods", "cov", "cdir", "solid", "trench", "netted"]:
		assert(a.get(key) == b.get(key), "Terrain %s differs after %s" % [key, label])
	assert(a.version == b.version, "Terrain version after " + label)
	assert(a.pending_count() == b.pending_count(), "Terrain pending after " + label)
	for i in a.dh.size():
		assert(absf(a.dh[i] - b.dh[i]) <= 0.000001, "Terrain deformation %s cell=%d ref=%.9f rust=%.9f" % [label, i, a.dh[i], b.dh[i]])
	for trial in 100:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		var source := p + Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40))
		for key in ["kind_at", "cover_at", "blast_mul", "in_trench", "concealment", "net_cover"]:
			assert(a.call(key, p) == b.call(key, p), "Terrain query %s after %s" % [key, label])
		assert(a.cover_vs(p, source) == b.cover_vs(p, source), "Directional cover after " + label)
		assert(a.hit_mul(p, source) == b.hit_mul(p, source), "Ground hit after " + label)
		assert(absf(a.deform_at(p) - b.deform_at(p)) < 0.000001, "Ground height after " + label)
		for vehicle in [false, true]:
			for tracked in [false, true]:
				assert(a.speed_mul(p, vehicle, tracked) == b.speed_mul(p, vehicle, tracked))
			assert(a.nav_weight(a.idx_of(p), vehicle) == b.nav_weight(b.idx_of(p), vehicle))
		queries += 1
	var saved: PackedByteArray = b._native.checkpoint()
	assert(b._native.restore(saved))
	assert(b._native.checkpoint() == saved)
	var invalid := saved.duplicate()
	invalid[4] = 3
	assert(not b._native.restore(invalid))
	assert(b._native.checkpoint() == saved)


func _ready() -> void:
	assert(ClassDB.class_exists("TerrainCore"))
	TerrainMap.N = 96
	TerrainMap.H = 48.0
	TerrainMap.DN = 192
	MapDims.N = 96
	MapDims.HALF = 48.0
	MapDims.SIZE = 96.0
	MapDims.BIOME = 96
	rng.seed = 77312
	for native in [false, true]:
		var world := World.new()
		world.has_view = false
		world.settings = {"seed": 923, "gdscript_terrain": not native}
		world.rng.seed = 900
		world.terrain = TerrainMap.new(world)
		pair.append(world)
	compare("initial biome")
	var kinds := ["tall_wall", "low_wall", "sandbags", "trench", "bunker", "rubble", "tree", "camo_net", "floor", "wire", "house_wall"]
	for i in 44:
		var p := Vector3(rng.randf_range(-38, 38), 0, rng.randf_range(-38, 38))
		var yaw := rng.randf_range(-PI, PI)
		for w in pair:
			var st := Structure.new()
			st.world = w
			st.eid = i + 1
			st.skind = kinds[i % kinds.size()]
			if st.skind == "house_wall":
				st.variant = 2
				st.door_shut = true
			st.position = p
			st.yaw = yaw
			st.size = Vector3(12 + i % 6, 2, 1) if st.skind.ends_with("wall") else Vector3.ONE
			st.built = i % 9 != 0
			w._register(st)
			w.add_child(st)
			st.on_spawned()
			w._shash_add(st)
			w.terrain.structure_changed(st)
	compare("queued structures")
	while pair[0].terrain.pending_count() > 0:
		for w in pair:
			w.terrain.tick(731)
		compare("partial cover rebuild")
	for round in 24:
		var p := Vector3(rng.randf_range(-52, 52), 0, rng.randf_range(-52, 52))
		var target := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		var width := rng.randf_range(0.1, 4.0)
		var yaw := rng.randf_range(-PI, PI)
		var size: float = [0.54, 0.55, 0.89, 0.9, 1.5, 6.0][round % 6]
		for w in pair:
			w.terrain.paint_box(p, Vector2(4.0, 6.0), yaw, TerrainMap.MUD)
			w.terrain.paint_roads([PackedVector3Array([p, target, target])], width)
			w.terrain.add_crater(p, size)
			w.terrain.add_crater(p, size)
			w.terrain._tree_woods(target, 1 if round % 2 == 0 else -1)
			var st: Structure = w.structures[round]
			w._shash_remove(st)
			w.terrain.structure_changed(st, false)
			st.position += Vector3(4, 0, -3)
			st.built = true
			w._shash_add(st)
			w.terrain.structure_changed(st, true)
			w.terrain.tick(217)
		compare("mutations %d" % round)
	# The replay loader imports plain arrays on a worker, with queued cover intact.
	for w in pair:
		w.terrain.begin_ground_import()
		var task := WorkerThreadPool.add_task(func(): import_ground(w))
		WorkerThreadPool.wait_for_task_completion(task)
		w.terrain.end_ground_import()
	compare("worker ground import")
	for w in pair:
		for st in w.structures:
			if st.skind == "house_wall":
				assert(st.door_shut)
				st.open_door(null, false)
				st.apply_props({"pos": st.position + Vector3(2, 0, -1), "yaw": st.yaw + 0.3})
				w.terrain.structure_changed(st)
		w.terrain.tick(613)
	compare("doors and replicated geometry")
	for w in pair:
		var st: Structure = w.structures[3]
		w._shash_remove(st)
		w.terrain.structure_changed(st, false)
		st.gone = true
		w.terrain.tick(517)
	compare("removed structure")
	# Water and replicated ground are imported after map generation.
	for w in pair:
		var cell := w.terrain.idx_of(Vector3.ZERO)
		w.terrain.base[cell] = TerrainMap.WATER
		w.terrain.refresh_cells(PackedInt32Array([cell]))
		w.terrain.dh[0] = -3.0
		w.terrain.sync_deformation()
		w.terrain.add_crater(Vector3.ZERO, 4.0)
		w.terrain.add_crater(Vector3(3, 1.6, 2), 2.0)
		w.terrain.tick(1 << 30)
	compare("water import and final cover")
	if "--terrain-bench" in OS.get_cmdline_user_args():
		benchmark()
	for w in pair:
		w.free()
	print("NATIVE_TERRAIN passed queries=", queries)
	get_tree().quit()
