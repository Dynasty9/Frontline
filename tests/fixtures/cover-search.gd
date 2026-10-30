extends "res://tests/fixtures/infantry-aim.gd"

var checks := 0


func compare_cover(w: World, anchor: Vector3, radius: float, threats: Array, prone: bool, label: String) -> void:
	var s: Soldier = w.entity(1)
	var expected := w.combat._find_cover_reference(s, anchor, radius, threats, prone)
	var actual := w.combat.find_cover(s, anchor, radius, threats, prone)
	assert(expected.is_empty() == actual.is_empty(), "Cover search empty " + label)
	if not expected.is_empty():
		for key in ["type", "prot", "fire", "lean", "pos", "n", "h", "mat", "st", "ai"]:
			assert(expected[key] == actual[key], "Cover search %s %s: %s vs %s" % [key, label, expected[key], actual[key]])
		assert(expected.tdir.distance_to(actual.tdir) < 0.000001, "Cover search threat direction " + label)
	checks += 1


func terrain(w: World, variant: int) -> void:
	var t := w.terrain
	t.crater.fill(0)
	t.rubble.fill(0)
	t.woods.fill(0)
	t.solid.fill(0)
	t.trench.fill(0)
	t.cov.fill(1)
	for z in range(20, 44):
		for x in range(20, 44):
			var i := z * TerrainMap.N + x
			if (x + z + variant) % 9 < 3:
				t.cov[i] = 2
				t.crater[i] = int(variant % 3 == 0)
				t.rubble[i] = int(variant % 3 == 1)
				t.woods[i] = int(variant % 3 == 2)
			if (x * z + variant) % 17 == 0:
				t.solid[i] = 1
			if (x * z + variant) % 19 == 0:
				t.trench[i] = 1
	assert(t._native.configure(TerrainMap.N, [t.base, t.crater, t.rubble, t.woods, t.cov, t.cdir, t.solid, t.trench, t.netted], t.dh))
	w.nav.ikind.fill(Nav.FREE)
	for i in w.nav.ikind.size():
		if (i + variant) % 37 == 0:
			w.nav.ikind[i] = Nav.SOLID
		w.nav.inf.set_point_solid(Vector2i(i % Nav.N, i / Nav.N), w.nav.ikind[i] == Nav.SOLID)
	assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
	w.fires.hot.fill(0)
	if variant % 5 == 0:
		for i in w.fires.hot.size():
			w.fires.hot[i] = int(i % 7 == 0)


func benchmark(w: World) -> void:
	var s: Soldier = w.entity(1)
	s.squad = null
	s.position = Vector3.ZERO
	var threats := [Vector3(0, 1.6, 20), Vector3(2, 1.5, 21)]
	var samples := [[], []]
	for round in 8:
		for mode in ([0, 1] if round % 2 == 0 else [1, 0]):
			var start := Time.get_ticks_usec()
			for i in 1000:
				if mode == 0:
					w.combat._find_cover_reference(s, Vector3.ZERO, 10, threats, false)
				else:
					w.combat.find_cover(s, Vector3.ZERO, 10, threats, false)
			if round > 1:
				samples[mode].append((Time.get_ticks_usec() - start) / 1000.0)
	print("COVER_SEARCH_BENCH searches=1000 gdscript_ms=", samples[0], " rust_ms=", samples[1])


func _ready() -> void:
	assert(ClassDB.class_exists("CoverSearchCore"))
	MapDims.N = 64
	MapDims.HALF = 32.0
	MapDims.SIZE = 64.0
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": true}
	w.terrain = TerrainMap.new(w)
	w.fires = Fires.new(w)
	w.water = WaterMap.new(w)
	w.nav = Nav.new()
	w.nav.finalize()
	assert(w.nav._planner != null)
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for eid in range(1, 10):
		register(w, Trooper.new(), eid)
	var s: Soldier = w.entity(1)
	var squad := Squad.new()
	squad.world = w
	squad.members = [s, w.entity(2)]
	s.wdef = {"range": 50.0}
	var walls: Array[Structure] = []
	for i in 6:
		var st := Wall.new()
		register(w, st, 20 + i)
		st.position = Vector3((i % 3 - 1) * 8, 0, (i / 3) * 8 + 1)
		st.skind = ["sandbags", "low_wall", "hedge", "hesco", "car", "house_wall"][i]
		st.built = true
		st.radius = 5
		var h: float = [0.5, 0.8, 1.6, 3.0, 1.12, 0.62][i]
		st.parts = [{"p": Vector3(0, h * 0.5, 0), "s": Vector3(7, h, 0.6), "r": 0.0, "cover": true, "col": true, "nav": Nav.SOLID}]
		st._make_body()
		st._compute_cover_pts()
		w._shash_add(st)
		walls.append(st)
	# Equal scores exercise Godot's unstable sort at and above its insertion threshold.
	var tied := walls[1]
	var saved := [tied.anc_p, tied.anc_n, tied.anc_h, tied.anc_k]
	for n in [1, 16, 17, 20, 24, 32, 64]:
		tied.anc_p.resize(n)
		tied.anc_n.resize(n)
		tied.anc_h.resize(n)
		tied.anc_k.resize(n)
		tied.anc_p.fill(Vector3.ZERO)
		tied.anc_n.fill(Vector3(0, 0, 1))
		tied.anc_h.fill(0.8)
		tied.anc_k.fill(Cover.OVER)
		for ai in n:
			s.cover_st = tied
			s.cover_ai = ai
			compare_cover(w, Vector3.ZERO, 0.0, [Vector3(0, 1.6, 20)], false, "ties n=%d ai=%d" % [n, ai])
	tied.anc_p = saved[0]
	tied.anc_n = saved[1]
	tied.anc_h = saved[2]
	tied.anc_k = saved[3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 87013
	for trial in 4096:
		if trial % 64 == 0:
			terrain(w, trial / 64)
		var anchor := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
		s.position = anchor + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		s.squad = squad if trial % 3 != 0 else null
		s.detached = trial % 5 == 0
		s.udef = {"bearer": trial % 7 == 0}
		s.wdef = {} if trial % 11 == 0 else {"range": [8.0, 50.0, 90.0][trial % 3]}
		s.cover_st = walls[trial % walls.size()] if trial % 4 == 0 else null
		s.cover_ai = trial % 5
		for st in walls:
			st.built = (trial + st.eid) % 13 != 0
			st.burn = 0.2 if (trial + st.eid) % 17 == 0 else 0.0
		w._uhash.clear()
		for eid in range(2, 10):
			var other: Soldier = w.entity(eid)
			other.position = anchor + Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
			other.cover_pos = Vector3.ZERO if eid % 3 == 0 else other.position
			other.at_cover = (trial + eid) % 3 == 0
			other.goal_kind = "cover" if (trial + eid) % 3 == 1 else "move"
			other.life = (trial + eid) % 3
			other.team = (trial + eid) % 2
			other.gone = (trial + eid) % 11 == 0
			w._hadd(other)
			if (trial + eid) % 5 == 0:
				other.position += Vector3(15, 0, 0)
		var threats := []
		for i in trial % 5:
			threats.append(Vector3(rng.randf_range(-30, 30), rng.randf_range(0.4, 2.0), rng.randf_range(-30, 30)))
		compare_cover(w, anchor, float([0, 3, 10, 16][trial % 4]), threats, trial % 2 == 0, str(trial))
	benchmark(w)
	print("COVER_SEARCH passed searches=", checks)
	w.free()
	get_tree().quit()
