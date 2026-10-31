extends "res://tests/fixtures/cover-search.gd"

class RecordedRoutes extends Nav:
	var jobs: Array = []
	func request_path(unit: Entity, destination: Vector3, vehicle: bool, team: int, care: float, _done: Callable) -> void:
		jobs.append([unit.eid, destination, vehicle, team, care])

func soldier_bytes(s: Soldier) -> PackedByteArray:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	assert(state.load_state(InfantryState.capture(s)))
	return state.checkpoint()

func compare_actor(s: Soldier, actors: RefCounted, label: String) -> void:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	assert(state.restore(actors.actor_state(s.eid)))
	var expected := InfantryState.capture(s)
	var actual: Array = state.values()
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])

func _ready() -> void:
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
	w.settings = {"gdscript_cover_search": true, "rust_infantry": false}
	w.time = 100.0
	w.terrain = TerrainMap.new(w)
	w.fires = Fires.new(w)
	w.water = WaterMap.new(w)
	w.nav = RecordedRoutes.new()
	w.nav.finalize()
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for eid in range(1, 10):
		var s := Trooper.new()
		register(w, s, eid)
		s.utype = "rifleman"
		s.udef = Defs.UNITS[s.utype]
		s.wdef = Defs.WEAPONS[s.udef.weapon]
		w.soldiers.append(s)
	var s: Soldier = w.entity(1)
	var squad := Squad.new()
	squad.world = w
	squad.sid = 1
	var walls: Array[Structure] = []
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	assert(structures.load_state(16.0, []))
	for i in 6:
		var st := Wall.new()
		register(w, st, 20 + i)
		st.position = Vector3((i % 3 - 1) * 8, 0, (i / 3) * 8 + 1)
		st.skind = ["sandbags", "low_wall", "hedge", "hesco", "car", "house_wall"][i]
		st.built = true
		st.radius = 5
		var h: float = [0.5, 0.8, 1.6, 3.0, 1.12, 0.62][i]
		st.parts = [{"p": Vector3(0, h * 0.5, 0), "s": Vector3(7, h, 0.6), "r": 0.0, "cover": true, "col": true, "nav": Nav.SOLID, "veh": Nav.SOLID}]
		st._make_body()
		st._compute_cover_pts()
		w._shash_add(st)
		w.structures.append(st)
		assert(structures.insert(st.eid, st.position, st.radius))
		walls.append(st)
	var samples := RandomNumberGenerator.new()
	samples.seed = 90217
	var rng := SimulationRandom.new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var qcore: RefCounted = ClassDB.instantiate("SquadStateCore")
	var seen := {}
	checks = 0
	for trial in 512:
		if trial % 32 == 0:
			terrain(w, trial / 32)
		w.time = 100.0 + trial * 0.1
		w.rng.seed = 1729 + trial
		rng.seed = 1729 + trial
		var anchor := Vector3(samples.randf_range(-10, 10), 0, samples.randf_range(-10, 10))
		var radius: float = [0.0, 3.0, 10.0, 16.0][trial % 4]
		s.position = anchor + Vector3(samples.randf_range(-4, 4), 0, samples.randf_range(-4, 4))
		s.hold_pos = anchor
		s.hold_face = Vector3(0.3, 0, -0.9).normalized()
		s.leash = radius
		s.utype = ["rifleman", "mg_gunner", "pkm"][trial % 3]
		s.udef = Defs.UNITS[s.utype]
		s.wdef = Defs.WEAPONS[s.udef.weapon]
		s.mag = 20
		s.squad = squad if trial % 7 else null
		s.sid = squad.sid if s.squad else 0
		s.detached = trial % 5 == 0
		s.cover_st = walls[trial % walls.size()] if trial % 4 != 0 else null
		s.cover_ai = [0, 1, -1, 1000][trial % 4]
		s.cover_pos = s.position if trial % 3 else (s.cover_st.anc_p[0] if s.cover_st else Vector3.ZERO)
		s.cover_type = trial % 4
		s.cover_n = Vector3.FORWARD
		s.cover_h = [0.0, 0.6, 1.12, 2.1][trial % 4]
		s.cover_mat = 2
		s.cover_threat = Vector3.BACK
		s.at_cover = trial % 2 == 0
		s.next_cover_eval = w.time + [-0.1, 0.0, 0.1][trial % 3]
		s.suppression = [0.0, 35.0, 45.0, 70.0, 90.0][trial % 5]
		s.stamina = [0.0, 0.349, 0.35, 1.0][trial % 4]
		s.posture = trial % 5
		s._shifting = trial % 3 == 0
		s.peek_up = true
		s.blind = true
		s.goal_kind = ["", "cover", "slot", "task"][trial % 4]
		s.goal = s.position + Vector3(2.59, 0, 0)
		s.path = PackedVector3Array([s.goal])
		s.path_i = trial % 2
		s._path_pending = trial % 7 == 0
		s.move_mode = trial % 3
		s.vis_targets = [w.entity(2)] if trial % 3 == 0 else []
		w._uhash.clear()
		squad.members = []
		squad.known = {}
		squad.heard = []
		squad._combat_cache_t = w.time if trial % 11 == 0 else -1.0
		squad._combat_cache = trial % 2 == 0
		for eid in range(2, 10):
			var other: Soldier = w.entity(eid)
			other.position = anchor + Vector3(samples.randf_range(-10, 10), 0, samples.randf_range(-10, 10))
			other.cover_pos = other.position
			other.at_cover = (eid + trial) % 2 == 0
			other.team = (eid + trial) % 2
			other.life = Soldier.Life.DEAD if (eid + trial) % 13 == 0 else Soldier.Life.ALIVE
			if eid < 2 + trial % 9:
				squad.members.append(other)
			if eid < 2 + trial % 5:
				squad.known[eid] = {"e": other, "pos": other.position, "t": w.time - [0.0, 7.99, 8.0, 15.0, 15.01][(trial + eid) % 5]}
		for i in trial % 4:
			squad.heard.append([Vector3(samples.randf_range(-30, 30), 0, samples.randf_range(-30, 30)), w.time - [0.0, 6.0, 8.0][i]])
		squad.members.append(s)
		if trial % 2:
			squad.members.reverse()
		for st in walls:
			st.gone = (trial + st.eid) % 23 == 0
			st.burn = [0.0, 0.3, 0.31][(trial + st.eid) % 3]
		var blocks := []
		var types := PackedByteArray()
		for e: Entity in w.entities.values():
			if e.gone: continue
			if e is Soldier:
				blocks.append(soldier_bytes(e))
				types.append(0)
			else:
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
				types.append(1)
		assert(actors.load_state(100, types, blocks))
		assert(qcore.load_state(SquadState.capture(squad)))
		var original_position: Vector3 = w.entities[2].position
		if trial % 2 == 0:
			var other: Soldier = w.entities[2]
			other.position -= Vector3(24, 0, 0)
		w._rebuild_uhash()
		var cells := []
		for cell in w._uhash:
			var ids := PackedInt64Array()
			for other: Entity in w._uhash[cell]: ids.append(other.eid)
			cells.append([cell, ids])
		assert(units.load_state(12.0, cells))
		if trial % 2 == 0:
			w.entities[2].position = original_position
		w.combat._sync_collision()
		for step in 6:
			w.time += [0.0, 0.1, 2.5, 6.1][step % 4]
			var review := step % 2 == 0
			w.nav.jobs.clear()
			var weapon := s.cur_weapon()
			var result: Array = actors.decide_infantry_cover(1, anchor,
				PackedFloat64Array([w.time, radius, weapon.get("range", 50.0), s.is_bearer(), review]),
				qcore if s.squad else null, w.fires.hot, w.water.deck, w.terrain._native, w.nav._planner,
				units, structures, w.combat._collision, rng._backend)
			assert(result.size() == 4, "result %d/%d" % [trial, step])
			if review: s._fight_think_work()
			else: s._seek_cover(anchor, radius, s._threats())
			seen["search" if result[0] else "wait"] = true
			seen["cover" if s.cover_type != Soldier.Cov.NONE else "open"] = true
			for other: Soldier in w.soldiers:
				compare_actor(other, actors, "%d/%d/%d" % [trial, step, other.eid])
				checks += 1
			assert(SquadState.capture(squad) == qcore.values(), "squad %d/%d" % [trial, step])
			assert(w.rng.state == rng.state, "random %d/%d" % [trial, step])
			var route: Array = result[3]
			assert(route.is_empty() == w.nav.jobs.is_empty(), "route %d/%d" % [trial, step])
			if not route.is_empty():
				assert(route == [s._path_revision, w.nav.jobs[0][0], w.nav.jobs[0][1], w.nav.jobs[0][4]])
			if step == 2:
				assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
	for key in ["search", "wait", "cover", "open"]:
		assert(seen.has(key), "missing outcome " + key)
	w.free()
	print("INFANTRY_COVER passed states=", checks)
	get_tree().quit()
