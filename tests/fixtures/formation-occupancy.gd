extends Node

class ReferenceGround extends TerrainMap:
	func slots(c: Vector3, face: Vector3, n: int, wide := false) -> Array:
		if face.length() < 0.1:
			face = Vector3.FORWARD
		var side := face.cross(Vector3.UP).normalized()
		var threat := c + face * 40.0
		var taken := []
		var out := []
		var spacing := 4.0 if wide else 3.2
		for i in n:
			var col := float(i) - (n - 1) * 0.5
			var depth := -absf(col) * 0.7 if wide else (-1.2 if i % 2 == 0 else 1.0)
			var p := c + side * col * spacing + face * depth
			var sp := best_spot_near(p, 3.4 if wide else 2.6, threat, taken)
			var q: Vector3 = sp[0]
			if wide and trench[idx_of(q)] == 0:
				# a defensive line mans the trench if there's one in reach
				var tq := nearest_trench(p, 7.0, taken)
				if tq != Vector3.INF:
					var ts := best_spot_near(tq, 1.6, threat, taken)
					sp = ts if trench[idx_of(ts[0])] > 0 else [tq, cover_vs(tq, threat), {}]
					q = sp[0]
			taken.append(q)
			out.append(sp)
		return out

func _ready() -> void:
	var w := World.new()
	w.has_view = false
	var fast := TerrainMap.new(w)
	var reference := ReferenceGround.new(w)
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
	reference.cov = fast.cov
	reference.cdir = fast.cdir
	reference.solid = fast.solid
	reference.trench = fast.trench
	var cases := 0
	for wide in [false, true]:
		for count in [1, 8, 32, 96]:
			for center in [Vector3.ZERO, Vector3(490, 0, 490)]:
				var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				var expected := reference.slots(center, face, count, wide)
				assert(fast.slots(center, face, count, wide) == expected, "Nearby occupancy must retain every formation position and cover choice")
				cases += 1
	for ground in [reference, fast]:
		var start := Time.get_ticks_usec()
		ground.slots(Vector3.ZERO, Vector3.FORWARD, 200, true)
		print("FORMATION_TIME reference=%s ms=%.3f" % [ground == reference, (Time.get_ticks_usec() - start) / 1000.0])
	w.free()
	print("FORMATION_OCCUPANCY passed cases=%d" % cases)
	get_tree().quit()
