extends "res://tests/fixtures/infantry-hidden-owned.gd"

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Defs.MAP_HALF = 32.0
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
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var records := preload("res://tests/fixtures/battle-stats.gd").new()
	var seen := {}
	checks = 0
	for team_id in 2:
		for mode in 5:
			for trial in 64:
				var w := HiddenWorld.new()
				w.has_view = false
				w.srv = true
				w.settings = {"rust_infantry": false, "ai_teams": [0, 1]}
				w.nav = SpecialRoutes.new()
				w.nav._planner = ClassDB.instantiate("PathPlannerCore")
				assert(w.nav._planner.configure(Nav.N))
				w.terrain = TerrainMap.new(w)
				w.water = WaterMap.new(w)
				w.combat = ScanCombat.new(w)
				w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
				w.rules = Rules.new(w)
				w.battle = BattleStats.new(w)
				add_child(w)
				w.rng.seed = 37531 + trial
				random.seed = 37531 + trial
				var ledger_core: RefCounted = ClassDB.instantiate("BattleStatsCore")
				for t in 2: assert(ledger_core.joined(-1 - t, t, w.battle._name_of(-1 - t, t)))
				var c := make_soldier(w, 1, team_id)
				var p := make_soldier(w, 2, 1 - team_id)
				w.soldiers = [c, p]
				var q := Squad.new()
				q.world = w
				q.sid = 9
				q.team = p.team
				q.owner = p.owner_peer
				q.kind = "rifle_squad"
				q.members = [p]
				p.squad = q
				p.sid = q.sid
				w.squads[q.sid] = q
				w.battle.squad_formed(q)
				assert(ledger_core.register_unit("s9", Squad.callsign_of(q.team, q.sid), q.display_name(), q.team, q.owner, w.time, 0))
				var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
				var cores: Array[SquadStateCore] = [qcore]
				c.position = Vector3.ZERO
				c.rotation.y = [0.0, 1.3, -2.5][trial % 3]
				c.posture = trial % 5
				c.task = "captor"
				c.task_ent = p
				c.task_phase = 1 if mode in [2, 3] else 0
				c.hold_pos = Vector3(-20, 0, 0)
				c.at_cover = true
				c.path = PackedVector3Array([Vector3(8, 0, 0)]) if trial % 3 == 0 else PackedVector3Array()
				c._path_pending = trial % 7 == 0
				c._stuck_t = 3.1 if trial % 13 == 0 else 0.0
				p.life = Soldier.Life.CAPTIVE if mode == 3 else Soldier.Life.SURRENDER
				p.captor = c if mode != 4 or trial % 3 == 0 else null
				if mode == 4 and trial % 3 == 0: p.life = Soldier.Life.ALIVE
				p.position = Vector3([0.0, 1.0, 2.29, 2.3, 2.599, 2.6, 4.0, 12.0][trial % 8], 0, 0)
				if mode == 0: p.position.x += 12.0
				p.intel_left = trial % 5
				p.intel_t = 9.0
				p.goal_kind = "prison" if mode == 3 else ""
				p.goal = p.position
				p.path = PackedVector3Array([p.position]) if mode == 3 else PackedVector3Array()
				for id in range(10, 14):
					var st := Mount.new()
					st.world = w
					st.eid = id
					st.team = team_id if id != 13 or trial % 3 else 1 - team_id
					st.skind = ["hq", "fob", "tunnel", "fob"][id - 10]
					st.sname = "Prison %d" % id
					st.position = Vector3([28.0, 6.0, 30.0, -6.0][id - 10], 0, 0)
					st.built = id == 10 or trial % 5 != 0
					w.add_child(st)
					w.entities[id] = st
					w.structures.append(st)
					w.owned_structures.append(st)
					if id == 10: w.rules.depots[team_id] = st
				p.prison_dest = w.entities[11 if trial % 2 == 0 else 12]
				if mode == 3 and trial % 7 == 0:
					p.prison_dest.gone = true
					w.owned_structures.erase(p.prison_dest)
				if mode == 3 and trial % 11 == 0:
					var freed: Structure = p.prison_dest
					w.owned_structures.erase(freed)
					w.entities.erase(freed.eid)
					w.structures.erase(freed)
					freed.free()
				if mode == 3 and trial % 5 == 0: c.task = "heal"
				var blocks := []
				var kinds := PackedByteArray()
				for e: Entity in w.entities.values():
					if e.gone: continue
					if e is Soldier: kinds.append(0); blocks.append(soldier_bytes(e))
					else:
						kinds.append(1)
						assert(structure.load_state(StructureState.capture(e)))
						blocks.append(structure.checkpoint())
				assert(actors.load_state(100, kinds, blocks) and qcore.load_state(SquadState.capture(q)))
				assert(units.load_state(12.0, []) and units.rebuild_units(actors) and structures.load_state(16.0, []) and doors.load_state(1.5, []))
				for step in 4:
					w.time = 10.0 + step * 0.1
					w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.props.clear(); w.messages.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear()
					var result := [[]]
					if mode == 3:
						if p.life == Soldier.Life.CAPTIVE:
							p._captive(0.1)
							var inactive: Array = actors.advance_infantry_inactive(2, 0.1, w.time, PackedFloat64Array(), cores, w.water.deck, w.terrain._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
							assert(inactive.size() == 3 and inactive[0].is_empty() and inactive[1].is_empty())
							result = [inactive[2]]
					elif c.task == "captor":
						c._captor_tick(0.1)
						result = actors.advance_infantry_captor(1, PackedFloat64Array([0.1, w.time, BattleStats.man_value(p), 10]), PackedFloat64Array(), ledger_core, cores, w.water.deck, w.terrain._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
					assert(result.size() == 1)
					for s in [c, p]:
						assert(infantry.restore(actors.actor_state(s.eid)))
						helper.check_state(s, infantry, "prison %d/%d/%d/%d/%d" % [team_id, mode, trial, step, s.eid]); checks += 1
					records.compare_ledger(w.battle, ledger_core, "capture credit")
					assert(qcore.values() == SquadState.capture(q))
					var jobs := []
					var cancelled := []
					var speech := []
					var stats := {}
					var messages := []
					for event: Array in result[0]:
						match int(event[0]):
							0:
								var move: Array = event[2]
								match int(move[0]):
									0: jobs.append([event[1], move[3], false, w.entities[event[1]].team, move[4]])
									1: cancelled.append(event[1])
									7: stats[move[1]] = stats.get(move[1], 0) + 1
									_: assert(false, "unexpected prisoner movement event")
							1:
								stats.prisoner_taken = 1
								messages.append([c.team, "info", "%s took a prisoner. Escorting him to %s." % [c.sname, w.entities[event[3]].display_name()], p.position])
							2: speech.append([event[1], ["Move! Hands where I can see them!", "On your feet! Walk!", "Easy... keep those hands up."][event[2]]])
							3:
								messages.append([w.entities[event[2]].team, "intel", "Prisoner %s has been taken into the tunnels for interrogation." % p.sname, null])
							4: messages.append([p.team, "alert", "%s has been taken prisoner by the enemy." % p.sname, null])
					assert(w.rng.state == random.state, "prison random")
					assert(w.stats == stats and w.spoken == speech and w.messages == messages, "prison events")
					assert(w.nav.cancelled == cancelled and w.nav.jobs.size() == jobs.size(), "prison routes")
					for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i], "prison route %d/%d/%d/%d: %s / %s" % [team_id, mode, trial, step, w.nav.jobs[i], jobs[i]])
					for key in stats: seen[key] = true
					if p.life == Soldier.Life.HIDDEN: seen[p.hidden_reason] = true
					if step == 1: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()) and ledger_core.restore(ledger_core.checkpoint()))
				w.free()
	helper.free()
	records.free()
	for key in ["prisoner_taken", "held", "interrogation", "repath"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_PRISON_OWNED passed states=", checks)
	get_tree().quit()
