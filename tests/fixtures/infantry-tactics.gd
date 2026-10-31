extends "res://tests/fixtures/cover-search.gd"

class RecordedRoutes extends Nav:
	var jobs: Array = []
	func request_path(unit: Entity, destination: Vector3, vehicle: bool, team: int, care: float, _done: Callable) -> void:
		jobs.append([unit.eid, destination, vehicle, team, care])

class TacticalTrooper extends Soldier:
	var threats: Array = []
	var reviewing := false
	var requests := 0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _threats() -> Array:
		return threats
	func _seek_cover(anchor: Vector3, radius: float, contacts: Array) -> void:
		if reviewing:
			requests += 1
		else:
			super._seek_cover(anchor, radius, contacts)

class SectorSquad extends Squad:
	var threats: Array = []
	func sector_threats(_origin: Vector3) -> Array:
		return threats

func retained_search(w: World, s: Soldier, core: RefCounted, rng: SimulationRandom, anchor: Vector3, radius: float, threats: Array) -> Array:
	var reach := minf(radius, 3.0) if s.squad and not s.detached else radius
	var buildings := []
	for st in w.structures_near(anchor, reach + 4.0):
		if st.provides_cover() and st.burn <= 0.0:
			buildings.append([st.eid, st.built, st.burn, Cover.mat_of(st), st.anc_p, st.anc_n, st.anc_h, st.anc_k])
	var mates := []
	if s.squad:
		for o: Soldier in s.squad.members:
			mates.append([o.eid, o.life == Soldier.Life.ALIVE, o.at_cover or o.goal_kind == "cover", o.cover_pos])
	var nearby := []
	for cell in w._uhash:
		for o: Entity in w._uhash[cell]:
			if o is Soldier and o != s and o.team == s.team and o.life == Soldier.Life.ALIVE and not o.gone:
				nearby.append([o.eid, o.team, true, false, o.position, o.cover_pos, cell])
	var weapon := s.cur_weapon()
	w.combat._sync_collision()
	return core.seek_cover([w.time, anchor, radius, s.squad != null, weapon.is_empty() or s.is_bearer(), float(weapon.get("range", 50.0)), s._danger()],
		PackedVector3Array(threats), buildings, mates, nearby, w.fires.hot, w.water.deck, w.terrain._native, w.nav._planner, w.combat._collision, rng._backend)

func compare_actor(s: Soldier, core: RefCounted, label: String) -> void:
	var expected := InfantryState.capture(s)
	var actual: Array = core.values()
	for i in expected.size():
		assert(expected[i] == actual[i], "%s group %d: %s vs %s" % [label, i, expected[i], actual[i]])

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
	w.settings = {"gdscript_cover_search": true}
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
		register(w, TacticalTrooper.new(), eid)
	var s: TacticalTrooper = w.entity(1)
	var squad := SectorSquad.new()
	squad.world = w
	squad.sid = 1
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
	var samples := RandomNumberGenerator.new()
	samples.seed = 90217
	var rng := SimulationRandom.new()
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	for trial in 2048:
		if trial % 64 == 0:
			terrain(w, trial / 64)
		w.time = 100.0 + trial * 0.1
		w.rng.seed = 1729 + trial
		rng.seed = 1729 + trial
		var anchor := Vector3(samples.randf_range(-10, 10), 0, samples.randf_range(-10, 10))
		var radius: float = [0.0, 3.0, 10.0, 16.0][trial % 4]
		s.position = anchor + Vector3(samples.randf_range(-4, 4), 0, samples.randf_range(-4, 4))
		s.hold_pos = anchor
		s.hold_face = Vector3(0.3, 0, -0.9).normalized()
		s.utype = ["rifleman", "mg_gunner", "pkm"][trial % 3]
		s.udef = Defs.UNITS[s.utype]
		s.wdef = Defs.WEAPONS[s.udef.weapon]
		s.mag = 20
		s.squad = squad
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
		for eid in range(2, 10):
			var other: Soldier = w.entity(eid)
			other.position = anchor + Vector3(samples.randf_range(-10, 10), 0, samples.randf_range(-10, 10))
			other.cover_pos = other.position
			other.at_cover = (eid + trial) % 2 == 0
			other.team = (eid + trial) % 2
			w._hadd(other)
			if eid < 2 + trial % 9:
				squad.members.append(other)
		squad.members.append(s)
		if trial % 2:
			squad.members.reverse()
		s.threats = []
		for i in trial % 5:
			s.threats.append(Vector3(samples.randf_range(-30, 30), 1.6, samples.randf_range(-30, 30)))
		squad.threats = s.threats
		for st in walls:
			st.gone = (trial + st.eid) % 23 == 0
			st.burn = [0.0, 0.3, 0.31][(trial + st.eid) % 3]
		assert(core.load_state(InfantryState.capture(s)))
		assert(core.crawling(s._danger()) == s._crawling(), "crawl %d" % trial)
		assert(core.movement_speed(s._danger()) == s._speed(), "speed %d" % trial)
		var sector: Vector3 = core.sector_direction(PackedVector3Array(s.threats), squad.centroid(), squad.members.size(), squad.members.back() == s)
		assert(sector == s._sector_dir_work(), "sector %d: %s vs %s" % [trial, sector, s._sector_dir_work()])
		var shelter := [s.cover_st.gone, s.cover_st.burn, s.cover_st.anc_p] if s.cover_st else []
		var need = core.reevaluate_cover(w.time, shelter, PackedVector3Array(s.threats))
		s.reviewing = true
		s.requests = 0
		s._fight_think_work()
		assert(need is bool and need == (s.requests == 1), "review %d" % trial)
		compare_actor(s, core, "review %d" % trial)
		s.reviewing = false
		w.nav.jobs.clear()
		var result := retained_search(w, s, core, rng, anchor, radius, s.threats)
		assert(result.size() == 3, "seek %d" % trial)
		s._seek_cover(anchor, radius, s.threats)
		compare_actor(s, core, "seek %d" % trial)
		assert(w.rng.state == rng.state, "random %d" % trial)
		assert(result[2].is_empty() == w.nav.jobs.is_empty())
		if not result[2].is_empty():
			assert(result[2] == [s._path_revision, w.nav.jobs[0][4]])
		assert(core.restore(core.checkpoint()))
		compare_actor(s, core, "restore %d" % trial)
	w.free()
	print("INFANTRY_TACTICS passed cases=10240")
	get_tree().quit()
