extends "res://tests/fixtures/vehicle-state.gd"

func profile(v: Vehicle) -> Array:
	var p := v.motion_profile()
	return [v._hull_size(), PackedByteArray([int(v.is_tracked()), int(v.base() == "supply"), int(v.base() == "tank"), int(v.vdef.cannon)]), v.weight(),
		PackedFloat64Array([v.vdef.speed, p.hull_turn, p.hull_accel, p.handling[0], p.handling[1], p.handling[2], p.handling[3]])]

func traffic(w: World) -> Array:
	var out := []
	for v in w.vehicles:
		if not v.gone:
			out.append([v.eid, v.position, v.rotation.y, v.speed, v._hull_size(), v.is_air()])
	return out

func compare_motion(v: Vehicle, core: RefCounted, label: String) -> void:
	var expected := VehicleState.capture(v)
	var actual: Array = core.values()
	for group in expected.size():
		if group == 2:
			for i in expected[group].size():
				assert(absf(float(expected[group][i]) - float(actual[group][i])) < 0.0001, "%s scalar %d: %s / %s" % [label, i, expected[group][i], actual[group][i]])
		elif group == 4:
			for i in expected[group].size():
				assert((expected[group][i] as Vector3).distance_to(actual[group][i]) < 0.0002, "%s point %d: %s / %s" % [label, i, expected[group][i], actual[group][i]])
		else:
			assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])
	checks += 1

func ground_world() -> World:
	var w := ActorWorld.new()
	w.has_view = false
	w.srv = true
	w.settings = {"seed": 137}
	w.nav = RecordedRoutes.new()
	w.nav._planner = ClassDB.instantiate("PathPlannerCore")
	assert(w.nav._planner.configure(Nav.N))
	w.terrain = TerrainMap.new(w)
	add_child(w)
	return w

func _ready() -> void:
	MapDims.N = 128
	MapDims.SIZE = 128.0
	MapDims.HALF = 64.0
	MapDims.BIOME = 128
	Nav.N = 128
	Nav.H = 64.0
	HNav.C = 16
	HNav.NC = 8
	TerrainMap.N = 128
	TerrainMap.H = 64.0
	TerrainMap.DN = 256
	var w := ground_world()
	var foe := make_soldier(w, 9, 1)
	foe.position = Vector3(0, 0, -40)
	var kinds := []
	for kind in Defs.VEHICLES:
		var d: Dictionary = Defs.VEHICLES[kind]
		if not d.get("air", false) and String(d.get("base", kind)) != "boat":
			kinds.append(kind)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	checks = 0
	var outcomes := {}
	for trial in kinds.size() + 40:
		var mode := trial % 10
		w.nav.jobs.clear()
		w.stats.clear()
		w.rng.seed = trial + 137
		random.set_seed(trial + 137)
		for z in Nav.N:
			for x in Nav.N:
				var i := z * Nav.N + x
				w.nav.vkind[i] = Nav.SOLID if mode == 5 or (mode == 7 and x in range(67, 69)) else Nav.FREE
				w.terrain.base[i] = [TerrainMap.GROUND, TerrainMap.MUD, TerrainMap.ROAD, TerrainMap.SHALLOW][(z / 8) % 4]
				w.terrain.trench[i] = int(mode == 8 and trial % 3 == 0)
		assert(w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
		assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.vkind = "truck" if mode == 9 else kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(0.3, 0, 1.7)
		v.rotation.y = 0.0 if mode in [5, 6, 7, 8] else (trial % 7) * 0.37
		v.path = PackedVector3Array([Vector3(1.2, 0, -10.3), Vector3(9.7, 0, -39.1)])
		if mode == 1:
			v.path = PackedVector3Array([Vector3(1.7, 0, 15.3)])
		elif mode == 2:
			v.path.clear()
			v.face_yaw = 1.3
		v.route = PackedVector3Array([Vector3(1.2, 0, -10.3), Vector3(9.7, 0, -39.1)])
		v.speed = 5.3 if mode in [2, 3, 4, 6, 7] else 0.0
		v.assault = mode == 8
		v.target = foe if mode == 8 else null
		w.add_child(v)
		w.vehicles.append(v)
		var others := []
		if mode in [6, 7]:
			for j in 3:
				var other := Carrier.new()
				other.world = w
				other.eid = 20 + j
				other.vkind = "tank"
				other.vdef = Defs.VEHICLES.tank
				other.position = Vector3((j - 1) * 1.7, 0, -9.3 - j * 9.0)
				other.rotation.y = PI if j == 2 else 0.0
				other.speed = 1.7 if mode == 6 else 0.0
				w.add_child(other)
				w.vehicles.append(other)
				others.append(other)
		assert(core.load_state(VehicleState.capture(v)))
		var p := profile(v)
		for step in 240:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			if step == 50 and mode in [3, 4]:
				v.track_broken = mode == 3
				v.brain_hold = mode == 4
				var state: Array = core.values()
				state[3][1] = int(v.track_broken)
				state[3][5] = int(v.brain_hold)
				assert(core.load_state(state))
			var before := int(w.stats.get("veh_unstick", 0))
			var target := PackedVector3Array([foe.position]) if mode == 8 else PackedVector3Array()
			var result: Array = core.ground_tick(dt, p, target, w.terrain.in_trench(foe.position), w.nav._planner, w.terrain._native, traffic(w), random, mode == 9)
			assert(result.size() == 3, "Ground step %d/%d" % [trial, step])
			if mode == 9:
				v.route_i = v._follow(v.route, v.route_i, dt, float(v.vdef.speed), false, 1.6)
			else:
				v._drive(dt)
			apply_route(v, core, result[0])
			assert(bool(result[1]) == (int(w.stats.get("veh_unstick", 0)) > before))
			assert(random.get_state() == w.rng.state, "Driving random cursor")
			compare_motion(v, core, "%s mode=%d step=%d" % [v.vkind, mode, step])
			if step % 23 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
			if result[1]:
				outcomes["unstuck"] = true
			if result[0][0] == 1:
				outcomes["replanned"] = true
			if v._rev:
				outcomes["reverse"] = true
			if v._avoid_cap == 3.0:
				outcomes["avoid"] = true
			for other in others:
				other.position += Defs.dir_of(other.rotation.y) * other.speed * dt
		var saved: PackedByteArray = core.checkpoint()
		var cursor: int = random.get_state()
		assert(core.ground_tick(NAN, p, PackedVector3Array(), false, w.nav._planner, w.terrain._native, [], random, false).is_empty())
		p[1][0] = 2
		assert(core.ground_tick(0.1, p, PackedVector3Array(), false, w.nav._planner, w.terrain._native, [], random, false).is_empty())
		assert(core.checkpoint() == saved and random.get_state() == cursor, "Rejected driving input must be atomic")
		w.vehicles.clear()
		for other in others:
			other.free()
		v.free()
	for key in ["unstuck", "replanned", "reverse", "avoid"]:
		assert(outcomes.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_MOTION passed steps=%d outcomes=%s" % [checks, outcomes])
	get_tree().quit()
