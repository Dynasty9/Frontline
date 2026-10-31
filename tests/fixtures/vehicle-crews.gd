extends "res://tests/fixtures/vehicle-driving.gd"

func crew_profile(v: Vehicle) -> Array:
	return [v.base(), PackedByteArray([int(v.is_heli()), int(v.is_auto()), int(v.vdef.has("art")), int(v.is_tracked())]), int(v.vdef.get("armor", 0))]

func contacts(units: Array, team: int) -> Array:
	var out := []
	for e in units:
		var fields := PackedInt64Array()
		if e is Soldier:
			fields = PackedInt64Array([int(e.life == Soldier.Life.ALIVE), e.rockets, int(e.utype in ["at_soldier", "rpg"]), int(e.riding != null)])
		else:
			fields = PackedInt64Array([int(e.is_air()), int(e.vdef.get("cannon", false)), e.atgm_left])
		out.append([e.eid, e.position, e.team, e.visible_to_team(team), e.gone, int(e is Vehicle), fields])
	return out

func perception(v: Vehicle) -> Array:
	var w := v.world
	return [contacts(w.units_near(v.position, 120.0), v.team),
		contacts(w.soldiers_near(v.position + Defs.dir_of(v.rotation.y) * 30.0, 45.0), v.team),
		contacts(w.soldiers_near(v.position, 35.0), v.team)]

func record_result(v: Vehicle, core: RefCounted, result: Array, stats: Dictionary, observed: Dictionary) -> void:
	assert(result.size() == 4)
	apply_route(v, core, result[0])
	var names := ["", "veh_withdraw", "veh_patched_up", "veh_wait_infantry", "veh_evade"]
	var event: int = result[1]
	if event > 0:
		stats[names[event]] = int(stats.get(names[event], 0)) + 1
		observed[names[event]] = true

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
	w.rules = Rules.new(w)
	var fob := Mount.new()
	fob.team = 0
	fob.world = w
	fob.eid = 2
	fob.skind = "fob"
	fob.sname = "Test FOB"
	fob.built = true
	w.add_child(fob)
	w.fob_structures.append(fob)
	for z in Nav.N:
		for x in Nav.N:
			var solid := x < 3 or z < 3 or x >= Nav.N - 3 or z >= Nav.N - 3 or (x in range(51, 54) and z in range(61, 69))
			w.nav.vkind[z * Nav.N + x] = Nav.SOLID if solid else Nav.FREE
			w.nav.veh.set_point_solid(Vector2i(x, z), solid)
	assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var observed := {}
	checks = 0
	for trial in 96:
		var mode := trial % 8
		w.rng.seed = trial + 177
		random.set_seed(trial + 177)
		w.stats.clear()
		w.nav.jobs.clear()
		var expected_stats := {}
		w.mission = MissionDirector.new(w, "bridgehead", null) if trial % 3 == 0 else null
		fob.position = Vector3([80.0, 10.0, 200.0, 240.0][trial % 4], 0, 0)
		fob.team = 1 if trial % 13 == 0 else 0
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.owner_peer = 1 if trial % 11 == 0 else -1
		v.vkind = ["tank", "old_tank", "technical", "ifv", "truck", "aa_tech"][trial % 6]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.max_hp = v.vdef.hp
		v.hp = v.max_hp * ([0.3, 0.79, 0.9, 1.0][trial % 4])
		v.position = Vector3(0.3, 0, 0.7)
		v.rotation.y = 0.0
		v.path = PackedVector3Array([Vector3(0, 0, -50)])
		v.path_pending = trial % 5 == 0
		v.path_destination = Vector3(0, 0, -50)
		v.assault = true
		v.assault_dest = Vector3(0, 0, -50)
		v.brain_state = ["", "withdraw", "", "wait", "evade", "", "", ""][mode]
		v.brain_resume = {"dest": Vector3(30, 0, 0), "assault": true, "assault_dest": Vector3(0, 0, -50)} if mode == 4 else {}
		v.brain_overruled = mode == 5
		v.track_broken = mode == 6
		v.track_fix = 5.8 if mode == 6 else 0.0
		v._tries_t = -INF
		w.add_child(v)
		w.vehicles.append(v)
		var men := []
		for i in 6:
			var s := make_soldier(w, 20 + i, 0 if i >= 4 else 1)
			s.position = Vector3((i % 2) * 20.0, 0, -15.0 - i * 7.0)
			s.vis_mask = 3 if trial % 3 else 0
			s.rockets = 1 if i % 2 else 0
			s.utype = "at_soldier" if i % 3 == 0 else "rifleman"
			s.riding = v if i >= 4 and trial % 2 == 0 else null
			w.soldiers.append(s)
			men.append(s)
		var other := Carrier.new()
		other.world = w
		other.eid = 50
		other.team = 1
		other.vis_mask = 3
		other.vkind = "tank"
		other.vdef = Defs.VEHICLES.tank
		other.position = Vector3(35, 0, -20)
		w.add_child(other)
		w.vehicles.append(other)
		assert(core.load_state(VehicleState.capture(v)))
		var p := crew_profile(v)
		for step in 128:
			w.time = step * 0.5
			for s in men:
				if step == 32:
					s.vis_mask = 3
				if step == 64 and s.team == 0:
					s.life = Soldier.Life.DEAD
			w._rebuild_uhash()
			if mode == 2 and step == 2:
				var from := Vector3(19.3, 0, -27.1)
				var result: Array = core.crew_step(w.time, p, perception(v), [], w.mission != null, w.nav._planner, random, PackedVector3Array([from]))
				VehicleBrain.on_threat(v, from)
				record_result(v, core, result, expected_stats, observed)
			var near: Structure = w.rules.nearest_fob(v.team, v.position)
			var fob_state := [near.eid, near.position] if near else []
			var result: Array = core.crew_step(w.time, p, perception(v), fob_state, w.mission != null, w.nav._planner, random, PackedVector3Array())
			if VehicleBrain.applies(v):
				VehicleBrain.think(v)
			record_result(v, core, result, expected_stats, observed)
			compare_vehicle(v, core, "crew %s trial=%d step=%d" % [v.vkind, trial, step])
			assert(w.stats == expected_stats, "Crew event order %s / %s" % [w.stats, expected_stats])
			assert(w.rng.state == random.get_state(), "Crew random cursor")
		var saved: PackedByteArray = core.checkpoint()
		assert(core.crew_step(NAN, p, [[], [], []], [], false, w.nav._planner, random, PackedVector3Array()).is_empty())
		assert(core.checkpoint() == saved)
		w.vehicles.clear()
		w.soldiers.clear()
		w.entities.clear()
		for s in men:
			s.free()
		other.free()
		v.free()
	for event in ["veh_withdraw", "veh_patched_up", "veh_wait_infantry", "veh_evade"]:
		assert(observed.has(event), "Fixture must exercise " + event)
	w.free()
	print("VEHICLE_CREWS passed steps=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
