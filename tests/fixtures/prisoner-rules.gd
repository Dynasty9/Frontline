extends "res://tests/fixtures/infantry-hidden-owned.gd"

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var records := preload("res://tests/fixtures/battle-stats.gd").new()
	var seen := {}
	checks = 0
	for team_id in 2:
		for mode in 8:
			for trial in 32:
				MapDims.configure([1024, 2048, 3072][trial % 3])
				Defs.MAP_HALF = MapDims.HALF
				var w := HiddenWorld.new()
				w.has_view = false
				w.srv = true
				w.settings = {"rust_infantry": false}
				w.nav = SpecialRoutes.new()
				w.rules = Rules.new(w)
				w.battle = BattleStats.new(w)
				w.next_sid = 100
				if trial % 3 == 0: w.mission = MissionDirector.new(w, "bridgehead", null)
				add_child(w)
				w.rng.seed = 93139 + trial
				random.seed = 93139 + trial
				var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
				var intelligence: RefCounted = ClassDB.instantiate("PrisonerIntelligenceCore")
				var bearers := PackedInt64Array()
				for id in range(1, 5):
					var s := make_soldier(w, id, team_id if id in [1, 3] else 1 - team_id)
					w.soldiers.append(s)
					s.position = Vector3.ZERO if id == 1 else Vector3(2.0 if id != 3 else (5.9 if mode == 0 else 60.0), 0, 0)
					if id == 4: s.position.x = 34.99 if trial % 2 == 0 else 35.0
					if id in [2, 3] and trial % 7 == 0:
						s.utype = "bearer"; s.udef = Defs.UNITS.bearer; s.wdef = {}; bearers.append(id)
					elif id == 2 and trial % 5 == 0: s.wdef = {}
					if id == 2 and trial % 11 == 0: s.life = Soldier.Life.DEAD
				var p: Soldier = w.entities[1]
				var c: Soldier = w.entities[2]
				p.life = [Soldier.Life.SURRENDER, Soldier.Life.SURRENDER, Soldier.Life.SURRENDER, Soldier.Life.CAPTIVE, Soldier.Life.CAPTIVE, Soldier.Life.HIDDEN, Soldier.Life.HIDDEN, Soldier.Life.ALIVE][mode]
				p.hidden_reason = "held" if mode == 5 else "interrogation" if mode == 6 else ""
				p.wdef = {} if mode < 7 else Defs.WEAPONS.rifle
				p.intel_left = 3
				p.intel_t = [9.9, 10.0, 10.1][trial % 3]
				p.captor = c if mode in [2, 3, 4] else null
				if mode in [2, 3]: c.task = "captor"; c.task_ent = p
				if mode == 4: p.go_to(Vector3(28, 0, 0), "prison", 0)
				if mode == 4 and trial % 7 == 0:
					var removed := Trooper.new()
					removed.eid = 99; p.captor = removed; removed.free()
				var cores: Array[SquadStateCore] = []
				if trial % 2 == 0:
					var q := Squad.new()
					q.world = w; q.sid = 9; q.team = team_id; q.owner = p.owner_peer
					q.kind = "rifle_squad"; q.order_pos = Vector3(12, 0, 0)
					w.squads[q.sid] = q
					w.battle.squad_formed(q)
					assert(ledger.register_unit("s9", q.callsign(), q.display_name(), q.team, q.owner, w.time, 0))
					var core: SquadStateCore = ClassDB.instantiate("SquadStateCore")
					assert(core.load_state(SquadState.capture(q))); cores.append(core)
				var names := {}
				for id in range(20, 37):
					var st := Mount.new()
					st.world = w; st.eid = id; st.team = team_id
					st.skind = ["fob", "fob", "mg_nest", "hmg_nest", "mortar_pit", "bunker", "at_post", "trench", "watchtower", "mines", "tunnel", "barracks", "factory", "medic_tent", "town", "fob", "tunnel"][id - 20]
					st.sname = "Position %d" % id
					st.position = Vector3((id - 20) * 11.37, 0, (trial - 16) * 0.73)
					st.supply = 19.75 + trial
					st.built = id in [20, 34] or trial % 5 != 0
					st.wrecked = id == 20 and trial % 2 == 0
					if id >= 35:
						st.team = 1 - team_id; st.position = Vector3([199.99, 200.0, 201.0, 600.0][trial % 4], 0, 0)
						if trial % 13 == 0: st.built = false
					if st.skind == "town": st.zone_c = Vector3(-19, 0, 38); w.rules.town_list.append(st)
					if st.skind in ["barracks", "factory"] and trial % 3 != 0:
						st.queue = [{"item": "rifle_squad", "t": 2.0, "total": 5.0, "owner": -1 - team_id, "cost": 10}]
					w.add_child(st); w.entities[id] = st; w.structures.append(st); w.owned_structures.append(st)
					if st.skind == "fob": w.fob_structures.append(st)
					names[id] = st.display_name()
				for id in [40, 41]:
					var v := Carrier.new()
					v.world = w; v.eid = id; v.team = team_id; v.vkind = "truck" if id == 40 else "tank"; v.vdef = Defs.VEHICLES[v.vkind]
					v.position = Vector3(MapDims.HALF * (1 if trial % 2 == 0 else -1), 0, -MapDims.HALF)
					w.add_child(v); w.entities[id] = v; w.vehicles.append(v)
				w.entities[20].truck = w.entities[40]
				w.entities[34].truck = w.entities[40]
				var commander := CommanderAI.new(w, team_id)
				commander.attack_target = w.entities[35]
				w.commanders.append(commander)
				var kinds := PackedByteArray()
				var blocks := []
				for e: Entity in w.entities.values():
					if e is Soldier: kinds.append(0); blocks.append(soldier_bytes(e))
					elif e is Vehicle:
						kinds.append(2); assert(vehicle.load_state(VehicleState.capture(e))); blocks.append(vehicle.checkpoint())
					else:
						kinds.append(1); assert(structure.load_state(StructureState.capture(e))); blocks.append(structure.checkpoint())
				assert(actors.load_state(100, kinds, blocks))
				assert(units.load_state(12.0, []) and units.rebuild_units(actors))
				w._rebuild_uhash()
				var next_id := 100
				for step in 3:
					w.time = 10.0 + step * 10.01
					w.props.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear(); w.messages.clear(); w.spoken.clear(); w.stats.clear()
					w.rules._prisoners()
					var messages := []; var speech := []; var props := []; var jobs := []; var stats := {}; var cancelled := []
					for s in w.soldiers:
						var weapon: String = s.udef.weapon
						var mag: int = Defs.WEAPONS[weapon].mag if Defs.WEAPONS.has(weapon) else 0
						var result: Array = actors.advance_prisoner(s.eid, w.time, [w.mission != null, 0, 0, weapon, mag, Defs.SQUADS["rifle_squad" if s.team == 0 else "fighter_cell"].name], PackedInt32Array(), cores, next_id, ledger, units, bearers)
						assert(result.size() == 3)
						next_id = result[1]
						if not result[2].is_empty():
							var added: SquadStateCore = ClassDB.instantiate("SquadStateCore")
							assert(added.restore(result[2])); cores.append(added)
						var event: Array = result[0]
						seen[event[0]] = true
						match event[0]:
							1: cancelled.append(s.eid)
							2:
								stats.captor = stats.get("captor", 0) + 1
								for route: Array in event[2]: jobs.append([event[1], route[3], false, 1 - s.team, route[4]])
							3:
								var intel: Array = intelligence.reveal(s.eid, event[1], actors, units, PackedInt64Array([34]), PackedInt64Array([team_id, 35]), MapDims.N, bearers, names, {"rifle_squad": Defs.item_name("rifle_squad")}, random._backend)
								assert(intel.size() == 5); messages.append(intel.slice(0, 4)); seen[intel[4]] = true
								stats.intel = stats.get("intel", 0) + 1
							4:
								messages.append([s.team, "info", "%s has been freed!" % s.sname, s.position])
								speech.append([s.eid, "Thanks! Get me out of here!"])
								stats.prisoner_freed = stats.get("prisoner_freed", 0) + 1
								if event[2] != null: props.append([s.eid, {"owner": event[2]}])
								for route: Array in event[3]: jobs.append([s.eid, route[3], false, s.team, route[4]])
					for s in w.soldiers:
						assert(infantry.restore(actors.actor_state(s.eid)))
						helper.check_state(s, infantry, "prisoner %d/%d/%d/%d/%d" % [team_id, mode, trial, step, s.eid]); checks += 1
						assert(intelligence.given(s.eid) == PackedStringArray(s.get_meta("given", [])), "prisoner remembers reports")
					assert(w.messages == messages, "prisoner messages %s != %s" % [w.messages, messages])
					assert(w.spoken == speech and w.props == props and w.stats == stats, "prisoner events")
					assert(w.nav.cancelled == cancelled, "prisoner cancelled paths")
					assert(w.nav.jobs.size() == jobs.size())
					for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
					assert(w.next_sid == next_id)
					var qs: Array = w.squads.values()
					assert(qs.size() == cores.size())
					for i in qs.size(): assert(cores[i].values() == SquadState.capture(qs[i]), "prisoner rejoined squad")
					records.compare_ledger(w.battle, ledger, "prisoner battle record")
					assert(w.rng.state == random.state, "prisoner random")
					assert(actors.restore(actors.checkpoint()) and intelligence.restore(intelligence.checkpoint()) and ledger.restore(ledger.checkpoint()))
					for core in cores: assert(core.restore(core.checkpoint()))
				w.free()
	helper.free(); records.free()
	for key in [0, 1, 2, 3, 4, "army", "plan35", "tr40", "tt40", "tn34", "pq31_rifle_squad"]: assert(seen.has(key), "must exercise " + str(key))
	print("PRISONER_RULES passed states=", checks)
	get_tree().quit()
