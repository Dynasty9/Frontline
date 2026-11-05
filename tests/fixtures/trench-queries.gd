extends Node

func reference(w: World, p: Vector3) -> bool:
	for st in w.structures_near(p, 4.0):
		if st.skind == "trench" and st.built and TrenchNet.inside(st, p, 0.05):
			return true
	return false

func _ready() -> void:
	var w := World.new()
	w.has_view = false
	w.terrain = TerrainMap.new(w)
	var objects: Array[Structure] = []
	for i in 500:
		var st := Structure.new()
		st.eid = i + 1
		st.skind = "trench" if i % 20 == 0 else "crates"
		st.built = i % 40 != 0
		st.position = Vector3((i % 25) * 3 - 36, 0, (i / 25) * 3 - 30)
		st.size = Vector3(20, 1, 1.5)
		st.yaw = i * 0.271
		st.radius = Vector2(10 + TrenchNet.HALF_W, 0.75).length() + 0.5
		w._shash_add(st)
		objects.append(st)
	var points := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 182
	for i in 2000:
		points.append(Vector3(rng.randf_range(-55, 55), 0, rng.randf_range(-45, 45)))
	for stage in 3:
		for p: Vector3 in points:
			var expected := reference(w, p)
			assert(w.in_trench(p) == expected, "index preserves exact trench containment")
			assert(w.ground_y(p) == (TrenchNet.FLOOR_Y + 0.15 if expected else 0.0))
		for st: Structure in objects:
			if st.skind == "trench":
				w._shash_remove(st)
				st.position += Vector3(17, 0, -16)
				st.built = true
				st.gone = stage == 1
				w._shash_add(st)
	for st: Structure in objects:
		w._shash_remove(st)
		st.free()
	assert(w._trench_hash.is_empty(), "removed trenches leave no stale entries")
	w.water = WaterMap.new(w)
	w.water.deck.resize(TerrainMap.N * TerrainMap.N)
	w.water.deck[w.terrain.idx_of(Vector3.ZERO)] = 1
	assert(w.ground_y(Vector3.ZERO) == 0.06, "Bridge deck wins over ground geometry")
	w.free()
	print("TRENCH_QUERIES passed")
	get_tree().quit()
