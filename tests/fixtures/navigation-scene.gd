extends Node

var checks := 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 573923
	var core: RefCounted = ClassDB.instantiate("NavigationSceneCore")
	var ground: RefCounted = ClassDB.instantiate("TerrainCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	for trial in 8:
		MapDims.N = 64 if trial < 4 else 128
		MapDims.SIZE = float(MapDims.N); MapDims.HALF = MapDims.N * 0.5; MapDims.BIOME = MapDims.N
		Nav.N = MapDims.N; Nav.H = MapDims.HALF
		HNav.C = 16 if trial % 2 == 0 else 32
		HNav.NC = MapDims.N / HNav.C; HNav.NCC = HNav.NC * HNav.NC; HNav._corner = HNav._corners()
		TerrainMap.N = MapDims.N; TerrainMap.H = MapDims.HALF; TerrainMap.DN = MapDims.N * 2
		var w := World.new()
		w.has_view = false; w.settings = {"gdscript_terrain": true}
		w.water = WaterMap.new(w); w.water.deck.resize(MapDims.N * MapDims.N)
		w.terrain = TerrainMap.new(w)
		w.nav = Nav.new(); w.nav.terrain = w.terrain
		var t := w.terrain
		for i in t.base.size():
			t.base[i] = [0, 1, 2, 3, 7, 8][rng.randi() % 6] if i % 7 == 0 else 0
			t.trench[i] = int(i % 41 == 0); t.crater[i] = int(i % 31 == 0)
			t.woods[i] = i % 4 if i % 13 == 0 else 0; t.rubble[i] = int(i % 23 == 0)
			w.water.deck[i] = 2 if i % 17 == 0 else int(i % 5 == 0)
			w.nav.terrain_changed(i)
		assert(ground.configure(MapDims.N, layers(t), t.dh))
		assert(core.configure(ground, w.water.deck, HNav.C))
		var walls: Array[Structure] = []
		for id in range(1, 13):
			var st := Structure.new()
			st.eid = id; st.skind = "sandbags"; st.built = true
			st.position = Vector3(rng.randf_range(-Nav.H, Nav.H), 0, rng.randf_range(-Nav.H, Nav.H))
			st.yaw = rng.randf_range(-PI, PI)
			for part in 3:
				st.parts.append({"p": Vector3(part * 0.3, 0.5, part * -0.7), "s": Vector3(rng.randf_range(0.01, 7), 1, rng.randf_range(0.01, 3)), "r": rng.randf_range(-PI, PI), "nav": (id + part) % 4, "veh": (id + 3 * part) % 4, "cover": true, "col": true})
			walls.append(st)
			change_structure(core, structure, ground, w, st, true)
		w.nav.finalize(); assert(core.finalize())
		check(w.nav, core, "initial %d" % trial)
		for step in 48:
			var st: Structure = walls[(step / 4) % walls.size()]
			match step % 4:
				0: change_structure(core, structure, ground, w, st, true)
				1:
					var p := st.position + Vector3(0.5, 0, -0.5)
					var radius: float = [0.0, 0.5, 1.0, 2.7, 7.3][(step / 4) % 5]
					var delta := 1 if step % 3 else -1
					w.nav.stamp_heat(p, radius, delta)
					assert(core.stamp_heat(p, radius, delta, ground, w.water.deck))
				2:
					var indices := PackedInt32Array()
					for edit in 6:
						var index := rng.randi_range(0, t.base.size() - 1)
						t.base[index] = [0, 1, 2, 3, 7, 8][rng.randi() % 6]
						w.water.deck[index] = (w.water.deck[index] + 1) % 3
						indices.append(index)
					assert(ground.replace_ground(layers(t), t.dh))
					for index in indices:
						w.nav.terrain_changed(index)
						assert(core.terrain_changed(index, ground, w.water.deck))
				3: change_structure(core, structure, ground, w, st, false)
			w.nav.update_hier(step % 5); assert(core.update_hierarchy(step % 5))
			for query in 4:
				var a := Vector3(rng.randf_range(-Nav.H, Nav.H), 0, rng.randf_range(-Nav.H, Nav.H))
				var b := Vector3(rng.randf_range(-Nav.H, Nav.H), 0, rng.randf_range(-Nav.H, Nav.H))
				var vehicle := query % 2 == 0
				var team := query % 3 - 1
				var care := 0.0 if query == 3 else 1.0
				var expected := w.nav.find_path(a, b, vehicle, team, care)
				var actual: PackedVector3Array = core.find_path(a, b, vehicle, team, care)
				assert(expected == actual, "navigation route %d/%d/%d" % [trial, step, query])
			check(w.nav, core, "%d/%d" % [trial, step])
			if step % 8 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved)); assert(saved == core.checkpoint())
				var bad := saved.duplicate(); bad[4] = 2
				assert(not core.restore(bad)); assert(saved == core.checkpoint())
		for st in walls: st.free()
		w.free()
	print("NAVIGATION_SCENE passed states=", checks)
	get_tree().quit()

func layers(t: TerrainMap) -> Array:
	return [t.base, t.crater, t.rubble, t.woods, t.cov, t.cdir, t.solid, t.trench, t.netted]

func change_structure(core: RefCounted, structure: RefCounted, ground: RefCounted, w: World, st: Structure, add: bool) -> void:
	assert(structure.load_state(StructureState.capture(st)))
	assert(core.structure_changed(structure, ground, w.water.deck, add))
	if add: w.nav.add_structure(st)
	else: w.nav.remove_structure(st)
	assert(structure.values() == StructureState.capture(st), "navigation structure cells")

func check(nav: Nav, core: RefCounted, where: String) -> void:
	var actual: Array = core.inspect()
	var expected := [nav._planner.checkpoint(), nav.hnav_i._core.checkpoint(), nav.hnav_v._core.checkpoint(), nav.cell_objs]
	for i in 4:
		assert(actual[i] == expected[i], "navigation state %s part %d" % [where, i])
	checks += 1
