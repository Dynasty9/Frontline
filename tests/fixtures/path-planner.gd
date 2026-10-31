extends Node


func _ready() -> void:
	assert(ClassDB.class_exists("PathPlannerCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 881405
	var queries := 0
	var reference_usec := 0
	var native_usec := 0
	for trial in 6:
		MapDims.N = 128 if trial > 2 else 64
		Nav.N = MapDims.N
		Nav.H = MapDims.N * 0.5
		HNav.C = 32 if trial > 2 else 16
		HNav.NC = MapDims.N / HNav.C
		var reference := Nav.new(false)
		var actual := Nav.new()
		for z in Nav.N:
			for x in Nav.N:
				var cell := Vector2i(x, z)
				var kind: int = [0, 0, 0, 0, 0, 0, 1, 2, 3][rng.randi() % 9] if trial % 3 else 0
				var weight: float = [0.3, 0.95, 1.0, 2.5, 9.0][rng.randi() % 5] if trial % 3 else 1.0
				var fire := 1 if rng.randf() < 0.01 else 0
				for nav: Nav in [reference, actual]:
					set_cell(nav, cell, kind, weight, fire)
		reference.finalize()
		actual.finalize()
		assert(actual._planner != null and reference._planner == null)
		var danger := PackedFloat32Array()
		danger.resize(HNav.NC * HNav.NC)
		for edit in 20:
			if edit % 4 == 0:
				var saved: PackedByteArray = actual._planner.checkpoint()
				var hits: int = actual._planner.cache_hits()
				assert(actual._planner.restore(saved))
				assert(actual._planner.checkpoint() == saved)
				# Performance counters are excluded from authoritative state.
				reference.path_cache_hits -= hits
				var bad := saved.duplicate()
				bad[4] = 2
				assert(not actual._planner.restore(bad))
				assert(actual._planner.checkpoint() == saved)
			for query in 24:
				var from := Vector3(rng.randf_range(-Nav.H, Nav.H), 0, rng.randf_range(-Nav.H, Nav.H))
				var to := Vector3(rng.randf_range(-Nav.H, Nav.H), 0, rng.randf_range(-Nav.H, Nav.H))
				var team := query % 3 - 1
				var care := 1.0 if query % 4 else 0.0
				var vehicle := query % 2 == 0
				for nearby in 2:
					var expected := PackedVector3Array()
					var got := PackedVector3Array()
					for mode in [0, 1] if query % 2 == 0 else [1, 0]:
						var start := Time.get_ticks_usec()
						if mode == 0:
							expected = reference.find_path(from, to, vehicle, team, care)
							reference_usec += Time.get_ticks_usec() - start
						else:
							got = actual.find_path(from, to, vehicle, team, care)
							native_usec += Time.get_ticks_usec() - start
					assert(expected == got, "Paths trial=%d edit=%d query=%d nearby=%d from=%s to=%s expected=%s got=%s" % [trial, edit, query, nearby, from, to, expected, got])
					assert(reference.path_cache_hits == actual.path_cache_hits, "Corridor reuse must match")
					assert(reference._line_free(from, to, vehicle) == actual._line_free(from, to, vehicle), "Smoothing probes must match")
					queries += 1
					from += Vector3(0.25, 0, 0.25)
					to += Vector3(0.25, 0, 0.25)
			for change in 12:
				var cell := Vector2i(rng.randi_range(0, Nav.N - 1), rng.randi_range(0, Nav.N - 1))
				var kind := rng.randi_range(0, 3)
				var weight := rng.randf_range(0.3, 9.0)
				var fire := int(change % 3 == 0)
				for nav: Nav in [reference, actual]:
					set_cell(nav, cell, kind, weight, fire)
			danger[edit % danger.size()] = rng.randf_range(0.0, 5.0)
			for nav: Nav in [reference, actual]:
				nav.hnav_i.set_danger(edit % 2, danger.duplicate())
				nav.hnav_v.set_danger(edit % 2, danger.duplicate())
				nav.update_hier(3)
	check_queue()
	print("PATH_PLANNER passed queries=", queries)
	print("PATH_PLANNER_TIMING reference_ms=%.3f native_ms=%.3f" % [reference_usec / 1000.0, native_usec / 1000.0])
	get_tree().quit()


func set_cell(nav: Nav, cell: Vector2i, kind: int, weight: float, fire: int) -> void:
	var index := cell.y * Nav.N + cell.x
	nav.ikind[index] = kind
	nav.vkind[index] = kind
	nav.heat[index] = fire
	for pair: Array in [[nav.inf, nav.hnav_i], [nav.veh, nav.hnav_v]]:
		pair[0].set_point_solid(cell, kind == Nav.SOLID)
		pair[0].set_point_weight_scale(cell, weight)
		pair[1].mark_dirty(cell)
	nav._sync_path_cell(index)


func check_queue() -> void:
	MapDims.N = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var expected: Array = []
	var got: Array = []
	var navs := [Nav.new(false), Nav.new()]
	var units: Array[Entity] = []
	for id in range(1, 9):
		var unit := Entity.new()
		unit.eid = id
		unit.position = Vector3(-25, 0, -25 + id)
		units.append(unit)
	for mode in 2:
		var nav: Nav = navs[mode]
		var output: Array = expected if mode == 0 else got
		for unit in units:
			var id := unit.eid
			nav.request_path(unit, Vector3(24, 0, 24), false, 0, 1.0, func(points): output.append([id, points]))
		nav.cancel_path(1)
		nav.request_path(units[0], Vector3(22, 0, 22), false, 0, 1.0, func(points): output.append([1, points]))
		nav.request_path(units[1], Vector3(25, 0, 25), false, 0, 1.0, func(points): output.append([2, points]))
		nav.finalize()
	for tick in 8:
		for nav: Nav in navs:
			# The route begins at the unit's position when its job runs.
			units[4].position.x = -22.0 + tick
			nav.process_paths(2)
		assert(expected == got, "Path completion order tick=%d expected=%s got=%s" % [tick, expected, got])
	assert(got.size() == units.size())
	for unit in units:
		unit.free()
