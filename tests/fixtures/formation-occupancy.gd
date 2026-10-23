extends Node

func _ready() -> void:
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
	var cases := 0
	for wide in [false, true]:
		for count in [1, 8, 32, 96]:
			for center in [Vector3.ZERO, Vector3(MapDims.HALF - 2, 0, MapDims.HALF - 2)]:
				var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				var slots := fast.slots(center, face, count, wide)
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
