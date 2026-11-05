extends Node

func make_world(native: bool, layout: int) -> World:
	var w := World.new()
	w.has_view = false
	w.settings = {"seed": 1}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	w.water.deck.resize(4096)
	if layout in [1, 2]:
		var heights := PackedFloat32Array()
		heights.resize(289)
		for z in 17:
			for x in 17:
				heights[z * 17 + x] = x * 4.0 * 0.55 if layout == 1 else (12.0 if x >= 9 else 0.0)
		w.terrain.install_landform(heights)
	if layout == 3:
		w.terrain.begin_ground_import()
		for z in 64:
			for x in range(30, 34):
				w.terrain.base[z * 64 + x] = TerrainMap.SHALLOW
				w.water.deck[z * 64 + x] = int(z in range(30, 34))
		for z in 128:
			for x in range(60, 68): w.terrain.dh[z * 128 + x] = -2.0
		w.terrain.end_ground_import()
	w.nav = Nav.new(native)
	w.nav.terrain = w.terrain
	for i in 4096: w.nav.terrain_changed(i)
	for id in range(1, 5):
		var st := Structure.new()
		st.world = w; st.eid = id; st.skind = "house_wall"; st.built = true
		st.position = Vector3(0.6 if id == 1 else id * 7.3 - 18, 0, id * 3.7 - 8)
		st.yaw = 0.0 if id == 1 else id * 0.17
		st.parts.append({"p": Vector3.ZERO, "s": Vector3(0.6, 2, 5), "r": 0.0, "nav": 3, "veh": 3, "cover": true, "col": true})
		w.entities[id] = st
		w.add_child(st)
		w.nav.add_structure(st)
	w.nav.finalize()
	assert((w.nav._planner != null) == native)
	return w

func compare_interruptions(reference: World, actual: World, a: Vector3, b: Vector3, query: int) -> void:
	var pair: Array[Soldier] = []
	for w: World in [reference, actual]:
		w.time = 10.0
		w.settings.rust_infantry = w == actual
		var s := Soldier.new()
		s.world = w
		pair.append(s)
	for action in 4:
		for s in pair:
			s.position = Vector3(a.x, s.world.ground_y(a) + 1.2, a.z)
			s.rotation.y = 0.37
			s.dive_dir = (b - a).normalized()
			s.dive_t = 0.8
			s.base_y = 0.4
			s.dazed_t = 0.0
			s.task_t = 2.0
			var dt: float = [0.016666666666666666, 0.1, 0.8][query % 3]
			match action:
				0:
					if s.world == actual: s._alive_timers_native(dt)
					else: s._alive_timers_reference(dt)
				1:
					s.life = Soldier.Life.DEAD
					s.flinging = true
					s.fling_v = s.dive_dir * 9.0 + Vector3.DOWN * 4.0
					s._fling_tick(dt)
				2:
					s.dazed_t = 1.0
					s._dazed_tick(dt)
				3:
					var partner := Soldier.new()
					partner.position = Vector3(b.x, s.world.ground_y(b), b.z)
					partner.rotation.y = 0.73
					s._stretcher_follow(partner, dt)
					partner.free()
		assert(pair[0].position.distance_to(pair[1].position) < 0.00001, "interrupt %d query=%d ref=%s rust=%s" % [action, query, pair[0].position, pair[1].position])
		assert(pair[0].fling_v == pair[1].fling_v and pair[0].flinging == pair[1].flinging, "knockback velocity")
		assert(pair[0].act == pair[1].act and pair[0].posture == pair[1].posture, "interruption pose")
	for s in pair: s.free()

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41379
	var checks := 0
	for layout in 4:
		var reference := make_world(false, layout)
		var actual := make_world(true, layout)
		for query in 180:
			if query == 90:
				for w: World in [reference, actual]:
					w.nav.remove_structure(w.entities[2])
					w.entities[2].free(); w.entities.erase(2)
					w.nav.stamp_heat(Vector3(5, 0, 3), 4.7, 1)
			for w: World in [reference, actual]: w.nav.update_hier(query % 4)
			var a := Vector3(rng.randf_range(-29, 29), 0, rng.randf_range(-29, 29))
			var b := Vector3(rng.randf_range(-29, 29), 0, rng.randf_range(-29, 29))
			if query % 9 == 0:
				a = Vector3(-0.5, 0, -4.3)
				b = Vector3([0.1, 0.6, 1.5][(query / 9) % 3], 0, -4.3)
			var vehicle := query % 3 != 0
			compare_interruptions(reference, actual, a, b, query)
			var tracks := query % 3 == 2
			assert(reference.nav.nearest_walkable(a, vehicle, tracks) == actual.nav.nearest_walkable(a, vehicle, tracks), "recovery layout=%d query=%d" % [layout, query])
			var expected_step := reference.nav.can_step(a, b, vehicle, tracks)
			var actual_step: bool = actual.nav._planner.step_clear(a, b, vehicle, tracks, actual.terrain._native, actual.water.deck)
			assert(expected_step == actual_step, "step layout=%d query=%d" % [layout, query])
			assert(reference.nav._line_free(a, b, vehicle, tracks) == actual.nav._line_free(a, b, vehicle, tracks), "smoothing")
			var expected := reference.nav.find_path(a, b, vehicle, query % 2, 1.0, tracks)
			var got := actual.nav.find_path(a, b, vehicle, query % 2, 1.0, tracks)
			assert(expected == got, "route layout=%d query=%d from=%s to=%s expected=%s actual=%s" % [layout, query, a, b, expected, got])
			if query % 30 == 0:
				var saved: PackedByteArray = actual.nav._planner.checkpoint()
				assert(actual.nav._planner.restore(saved))
				assert(saved == actual.nav._planner.checkpoint())
			checks += 1
		reference.free(); actual.free()
	print("NATIVE_TRAVERSAL passed queries=%d interruptions=%d" % [checks, checks * 4])
	get_tree().quit()
