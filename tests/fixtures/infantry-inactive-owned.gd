extends "res://tests/fixtures/infantry-hidden-owned.gd"

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for life: int in [Soldier.Life.DEAD, Soldier.Life.SURRENDER, Soldier.Life.CAPTIVE]:
		for trial in 128:
			var w := HiddenWorld.new()
			w.has_view = false
			w.srv = true
			w.settings = {"rust_infantry": false}
			w.nav = SpecialRoutes.new()
			w.nav._planner = ClassDB.instantiate("PathPlannerCore")
			assert(w.nav._planner.configure(Nav.N))
			w.terrain = TerrainMap.new(w)
			w.water = WaterMap.new(w)
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.rules = Rules.new(w)
			add_child(w)
			w.rng.seed = 27191 + trial
			random.seed = 27191 + trial
			var q := Squad.new()
			q.world = w
			q.sid = 9
			q._centroid_t = 3.0
			w.squads[q.sid] = q
			var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
			var cores: Array[SquadStateCore] = [qcore]
			var s := make_soldier(w, 1, 0)
			var bearer := make_soldier(w, 2, 0)
			var missing := make_soldier(w, 3, 0)
			missing.gone = true
			bearer.life = Soldier.Life.DEAD if trial % 5 == 0 else Soldier.Life.ALIVE
			s.squad = q
			s.sid = q.sid
			q.members = [s]
			w.soldiers = [s, bearer]
			s.life = life
			s.dead_t = [0.0, 10.0, 10.0001][trial % 3]
			s.position = Vector3(0, [-0.55, 0.0, 0.5, 1.3][trial % 4], 0)
			s.rotation.y = [0.0, 1.3, -2.5][trial % 3]
			s.posture = trial % 5
			s.path = PackedVector3Array([Vector3(8, 0, 0)]) if trial % 3 == 0 else PackedVector3Array()
			s._path_pending = trial % 7 == 0
			s._stuck_t = 3.1 if trial % 13 == 0 else 0.0
			s._gy = -0.4
			s._gy_t = [309.9, 310.0, 310.2][trial % 3]
			s.carried_by = [[], [bearer], [missing], [missing, bearer]][trial % 4]
			s.stretcher_claimed = trial % 11 == 0
			w.water.deck.fill(1 if trial % 5 == 0 else 0)
			var tm: TerrainMap = w.terrain
			tm.dh.fill(-0.2 if trial % 2 else 0.0)
			assert(tm._native.configure(TerrainMap.N, [tm.base, tm.crater, tm.rubble, tm.woods, tm.cov, tm.cdir, tm.solid, tm.trench, tm.netted], tm.dh))
			assert(actors.load_state(100, PackedByteArray([0, 0]), [soldier_bytes(s), soldier_bytes(bearer)]))
			assert(qcore.load_state(SquadState.capture(q)))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors) and structures.load_state(16.0, []) and doors.load_state(1.5, []))
			var retired := PackedByteArray()
			for step in 4:
				w.time = 310.0 + step * 0.1
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.props.clear(); w.nav.jobs.clear()
				var result := [[], PackedByteArray(), []]
				if not s.gone:
					if life == Soldier.Life.DEAD: s._dead(0.1)
					else: s._captive(0.1)
					result = actors.advance_infantry_inactive(1, 0.1, w.time, PackedFloat64Array(), cores, w.water.deck, tm._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
				assert(result.size() == 3 and result[2].is_empty(), "inactive %d/%d/%d" % [life, trial, step])
				if not result[1].is_empty(): retired = result[1]
				assert(infantry.restore(retired if s.gone else actors.actor_state(1)))
				helper.check_state(s, infantry, "inactive %d/%d/%d" % [life, trial, step]); checks += 1
				assert(qcore.values() == SquadState.capture(q), "inactive squad")
				assert(actors.actor_state(1).is_empty() == s.gone, "inactive removal")
				var stats := {}
				var jobs := []
				for event: Array in result[0]:
					match int(event[0]):
						0: jobs.append([1, event[3], false, 0, event[4]])
						7: stats[event[1]] = stats.get(event[1], 0) + 1
						_: assert(false, "unexpected inactive movement event")
				assert(w.rng.state == random.state, "inactive random")
				assert(w.stats == stats and w.spoken.is_empty() and w.props.is_empty() and w.effects.is_empty(), "inactive events")
				assert(w.nav.jobs.size() == jobs.size(), "inactive routes")
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				if s.gone: seen.removed = true
				if s.act == Soldier.Act.CARRIED: seen.carried = true
				if s.position.x > 0.0: seen.moved = true
				if step == 1: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	helper.free()
	for key in ["removed", "carried", "moved"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_INACTIVE_OWNED passed states=", checks)
	get_tree().quit()
