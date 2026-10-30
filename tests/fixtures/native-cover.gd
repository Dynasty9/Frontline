extends Node3D

class Scene extends World:
	var surface := 0.0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func ground_y(_p: Vector3) -> float:
		return surface


func compare(a: Dictionary, b: Dictionary, label: String) -> void:
	assert(a.is_empty() == b.is_empty(), "Cover protection " + label)
	if a.is_empty():
		return
	for key in ["type", "prot", "fire", "lean", "pos", "n", "h", "mat", "st", "ai"]:
		assert(a[key] == b[key], "Cover %s %s: %s vs %s" % [key, label, a[key], b[key]])
	assert(a.tdir.distance_to(b.tdir) < 0.000001, "Cover threat direction " + label)


func benchmark(w: World, st: Structure) -> void:
	var p: Vector3 = st.anc_p[0]
	var n: Vector3 = st.anc_n[0]
	var threats := [p + n * 20 + Vector3.UP * 1.4, p + n * 30 + Vector3.UP * 1.4,
		p + n * 25 + Vector3.UP * 1.4, p + n * 40 + Vector3.UP * 1.4]
	var samples := [[], []]
	for round in 8:
		for mode in ([0, 1] if round % 2 == 0 else [1, 0]):
			var start := Time.get_ticks_usec()
			for i in 1000:
				if mode == 0:
					Cover._evaluate_reference(w, st, 0, threats)
				else:
					Cover.evaluate(w, st, 0, threats)
			if round > 1:
				samples[mode].append((Time.get_ticks_usec() - start) / 1000.0)
	print("COVER_BENCH evaluations=1000 gdscript_ms=", samples[0], " rust_ms=", samples[1])


func generation(rng: RandomNumberGenerator) -> void:
	var kinds := ["trench", "low_wall", "car", "house_wall", "sandbags", "hesco", "floor", "roof", "wire", "mines", "tank_trap", "tunnel", "helipad", "tree", "camo_net", "crates"]
	var generated := 0
	for trial in 400:
		var st := Structure.new()
		st.skind = kinds[trial % kinds.size()]
		st.variant = trial % 3
		var near_edge := MapDims.HALF - 5.0 if trial % 7 == 0 else 40.0
		st.position = Vector3(rng.randf_range(-near_edge, near_edge), rng.randf_range(-1.5, 0.5), rng.randf_range(-near_edge, near_edge))
		st.size = Vector3(rng.randf_range(0.1, 24.0), 1, 1)
		st.yaw = rng.randf_range(-PI, PI)
		for p in range(trial % 12 + 1):
			var size := Vector3(rng.randf_range(0.4, 14.0), rng.randf_range(0.2, 4.0), rng.randf_range(0.2, 9.0))
			st.parts.append({"p": Vector3(rng.randf_range(-8, 8), size.y * 0.5 + (1.0 if p % 7 == 1 else 0.0), rng.randf_range(-8, 8)),
				"s": size, "r": rng.randf_range(-PI, PI), "cover": p % 4 != 1, "col": p % 5 != 2, "nav": p % 4})
		Cover._build_reference(st)
		var expected := [st.anc_p, st.anc_n, st.anc_h, st.anc_k]
		Cover.build(st)
		assert(expected[3] == st.anc_k and expected[2] == st.anc_h, "Cover anchor order/height trial=" + str(trial))
		for i in st.anc_p.size():
			assert(expected[0][i].distance_to(st.anc_p[i]) < 0.00002, "Cover anchor position trial=%d i=%d ref=%s rust=%s" % [trial, i, expected[0][i], st.anc_p[i]])
			assert(expected[1][i].distance_to(st.anc_n[i]) < 0.000001, "Cover anchor normal trial=" + str(trial))
		generated += st.anc_p.size()
		st.free()
	assert(generated > 1000, "Cover fixture must generate anchors")
	print("NATIVE_COVER_GENERATION passed structures=400 anchors=", generated)


func _ready() -> void:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	assert(w.combat._collision != null)
	var reference := Combat.new(w)
	var native := w.combat
	var rng := RandomNumberGenerator.new()
	rng.seed = 71389
	assert(ClassDB.class_exists("CoverGeometry"))
	generation(rng)
	var structures: Array[Structure] = []
	for i in 40:
		var st := Structure.new()
		st.world = w
		st.srv = true
		st.eid = i + 1
		st.position = Vector3((i % 8 - 4) * 16, 0, (i / 8 - 2) * 16)
		st.yaw = rng.randf_range(-PI, PI)
		st.rotation.y = st.yaw
		st.skind = ["low_wall", "car", "house_wall", "sandbags", "hesco"][i % 5]
		st.variant = i % 3
		var h: float = [0.5, 0.62, 0.8, 1.0, 1.12, 1.55, 1.6, 3.0][i % 8]
		st.parts = [{"p": Vector3(0, h * 0.5, 0), "s": Vector3(8, h, 0.6), "r": 0.0, "cover": true, "col": true, "nav": Nav.SOLID}]
		w.entities[st.eid] = st
		w.add_child(st)
		st._make_body()
		st._compute_cover_pts()
		assert(not st.anc_p.is_empty())
		structures.append(st)
	var queries := 0
	var protected := 0
	var firing := 0
	var kinds := {}
	for round in 12:
		w.surface = [0.0, -1.05, 0.06][round % 3]
		for st in structures:
			st.position.y = w.surface
			w.combat.dirty_collision(st.eid)
		var changed := structures[round]
		var shape: CollisionShape3D = changed.body.get_child(0)
		shape.disabled = round % 3 == 0
		shape.shape.size.x += 0.2
		await get_tree().physics_frame
		await get_tree().process_frame
		for query in 250:
			var st: Structure = structures[query % structures.size()]
			var i := rng.randi_range(0, st.anc_p.size() - 1)
			var p: Vector3 = st.anc_p[i]
			var threats := []
			for k in (query % 8):
				var direction: Vector3 = st.anc_n[i].rotated(Vector3.UP, rng.randf_range(-2.0, 2.0))
				threats.append(p + direction * rng.randf_range(0.1, 60) + Vector3.UP * (w.surface + rng.randf_range(0.3, 2.0)))
			var prone := query % 3 == 0
			w.combat = reference
			var expected := Cover._evaluate_reference(w, st, i, threats, prone)
			w.combat = native
			var actual := Cover.evaluate(w, st, i, threats, prone)
			compare(expected, actual, "round=%d query=%d" % [round, query])
			if not actual.is_empty():
				protected += 1
				firing += int(actual.fire)
				kinds[int(actual.type)] = true
			queries += 1
		var saved: PackedByteArray = native._collision.checkpoint()
		assert(native._collision.restore(saved))
		assert(native._collision.checkpoint() == saved)
	assert(protected > 500 and firing > 100 and kinds.size() == 3, "Cover fixture must exercise shelter, low and leaning fire")
	if "--cover-bench" in OS.get_cmdline_user_args():
		w.surface = 0.0
		structures[1].position.y = 0.0
		w.combat.dirty_collision(structures[1].eid)
		benchmark(w, structures[1])
	w.free()
	print("NATIVE_COVER passed queries=", queries, " protected=", protected, " firing=", firing)
	get_tree().quit()
