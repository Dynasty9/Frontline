extends Node

class UncachedTerrain extends TerrainMap:
	func best_spot_near(p: Vector3, r: float, from: Vector3, taken: Array, group_center := Vector3.INF, group_radius := 0.0, search: Dictionary = {}) -> Array:
		search.erase("ground")
		search.erase("native_ground")
		return super.best_spot_near(p, r, from, taken, group_center, group_radius, search)

	func group_spot_cached(p: Vector3, c: Vector3, radius: float, normal: Vector3, _search: Dictionary) -> bool:
		return group_spot(p, c, radius, normal)

	func occupied_count(p: Vector3, radius: float, taken: Array, _search: Dictionary) -> int:
		var count := 0
		for t in taken:
			if Defs.flat((t as Vector3) - p).length() < radius:
				count += 1
		return count

class FallbackTerrain extends TerrainMap:
	func _formation_ground(c: Vector3, radius: float, from: Vector3, search: Dictionary) -> Array:
		var candidates := super._formation_ground(c, radius, from, search)
		search.erase("native_ground")
		return candidates

func _check_native() -> void:
	if not ClassDB.class_exists("FormationGround"):
		return
	var scorer: Object = ClassDB.instantiate("FormationGround")
	assert(scorer.prepare(PackedVector3Array(), PackedFloat64Array()))
	assert(scorer.best(Vector3.ZERO)[0] == -1.0, "empty ground has no winner")
	var points := PackedVector3Array([Vector3.LEFT, Vector3.RIGHT])
	assert(scorer.prepare(points, PackedFloat64Array([3.0, 0.0, 3.0, 0.0])))
	assert(scorer.best(Vector3.ZERO)[0] == 0.0, "equal scores keep the first candidate")
	scorer.add_taken(Vector3.LEFT)
	assert(scorer.best(Vector3.ZERO)[0] == 1.0, "occupied ground loses priority")
	assert(not scorer.prepare(points, PackedFloat64Array([3.0])))
	assert(scorer.best(Vector3.ZERO)[0] == -1.0, "invalid preparation clears old candidates")
	assert(not scorer.prepare(points, PackedFloat64Array([NAN, 0.0, 3.0, 0.0])))
	print("FORMATION_NATIVE passed")

func _ready() -> void:
	_check_native()
	var w := World.new()
	w.has_view = false
	var fast := TerrainMap.new(w)
	w.nav = Nav.new()
	w.terrain = fast
	var rng := RandomNumberGenerator.new()
	rng.seed = 701
	for i in 12000:
		var cell := rng.randi_range(0, fast.base.size() - 1)
		fast.cov[cell] = rng.randi_range(0, 4)
		fast.cdir[cell] = rng.randi_range(0, 8)
		fast.solid[cell] = 1 if i % 7 == 0 else 0
	for x in range(-70, 71):
		for z in range(-24, 25, 8):
			var cell := fast.idx_of(Vector3(x, 0, z))
			fast.trench[cell] = 1
			fast.cov[cell] = 4
	for i in 35:
		var st := Structure.new()
		st.world = w
		st.eid = i + 1
		st.skind = "low_wall"
		st.built = true
		st.position = Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(-30, 30))
		st.radius = 3.0
		st.anc_p = PackedVector3Array([st.position + Vector3(0, 0, 0.5), st.position - Vector3(0, 0, 0.5)])
		st.cover_pts = st.anc_p
		st.anc_n = PackedVector3Array([Vector3.FORWARD, Vector3.BACK])
		st.anc_h = PackedFloat32Array([1.1, 1.1])
		st.anc_k = PackedByteArray([Cover.OVER, Cover.OVER])
		w._register(st)
		w._shash_add(st)
		w.add_child(st)
	var reference := UncachedTerrain.new(w)
	reference.cov = fast.cov
	reference.cdir = fast.cdir
	reference.solid = fast.solid
	reference.trench = fast.trench
	var fallback := FallbackTerrain.new(w)
	fallback.cov = fast.cov
	fallback.cdir = fast.cdir
	fallback.solid = fast.solid
	fallback.trench = fast.trench
	var cases := 0
	for wide in [false, true]:
		for count in [1, 8, 32, 96, 200]:
			for center in [Vector3.ZERO, Vector3(MapDims.HALF - 2, 0, MapDims.HALF - 2)]:
				var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				var slots := fast.slots(center, face, count, wide)
				w.terrain = reference
				var expected := reference.slots(center, face, count, wide)
				w.terrain = fallback
				var fallback_slots := fallback.slots(center, face, count, wide)
				w.terrain = fast
				assert(fallback_slots == expected, "prepared GDScript ground matches exhaustive selection")
				assert(slots == expected, "cached formation matches exhaustive cover selection")
				assert(slots.size() == count, "each man receives a position")
				assert(slots == fast.slots(center, face, count, wide), "cover selection is deterministic")
				for sl in slots:
					var p: Vector3 = sl[0]
					assert(absf(p.x) < MapDims.HALF and absf(p.z) < MapDims.HALF, "positions stay inside the map")
					var normal: Vector3 = sl[2].get("n", Vector3.ZERO)
					assert(fast.group_spot(p, center, 6.5 if wide else 5.5, normal), "positions remain in the squad's pocket")
				cases += 1
	assert(fast.trench[fast.idx_of(fast.slots(Vector3.ZERO, Vector3.FORWARD, 1, true)[0][0])] > 0, "defence still favors nearby trench cover")
	w.free()
	print("FORMATION_OCCUPANCY passed cases=%d" % cases)
	get_tree().quit()
