extends "res://tests/fixtures/vehicle-state.gd"

func totals(r: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for field in BattleStats.FIELDS: out.append(float(r[field]))
	return out

func player_row(owner: int, p: Dictionary) -> Array:
	return [owner, p.team, p.ai, p.name, totals(p)]

func unit_row(key: String, u: Dictionary) -> Array:
	return [key, u.name, u.kind, u.team, u.owner, u.t0, u.t1, u.men, u.alive, u.kills, u.downs, u.veh_kills, u.lost]

func hero_row(id: int, h: Dictionary) -> Array:
	return [id, h.name, h.role, h.team, h.owner, h.unit, h.kills, h.veh, h.alive]

func killer_role(by: Array, w: World) -> String:
	if by.is_empty() or int(by[3]) == 0: return ""
	var s: Soldier = w.entity(int(by[3]))
	return String(Defs.UNITS.get(s.utype, {}).get("name", s.utype)) if s else ""

func ledger(b: BattleStats) -> Array:
	var players := []
	for id in b.players: players.append(player_row(id, b.players[id]))
	var units := []
	for key in b.units: units.append(unit_row(key, b.units[key]))
	var heroes := []
	for id in b.heroes: heroes.append(hero_row(id, b.heroes[id]))
	var timeline := []
	for row in b.timeline: timeline.append(PackedFloat64Array(row))
	return [players, [totals(b.sides[0]), totals(b.sides[1])], units, heroes, timeline, b.events, b.every, b._sample_t, b._blame]

func report_rows(b: BattleStats, r: Dictionary) -> Array:
	var players := []
	for p in r.players: players.append(player_row(p.id, p))
	var sides := []
	for s in r.sides: sides.append(totals(s) if not s.is_empty() else PackedFloat64Array())
	var units := []
	for u in r.units: units.append(unit_row(u.key, u))
	var heroes := []
	for h in r.heroes:
		for id in b.heroes:
			if b.heroes[id] == h:
				heroes.append(hero_row(id, h))
				break
	var timeline := []
	for row in r.tl: timeline.append(PackedFloat64Array(row))
	return [players, sides, units, heroes, timeline, r.ev]

func compare_ledger(b: BattleStats, core: RefCounted, label: String) -> void:
	var expected := ledger(b)
	var actual: Array = core.values()
	assert(actual.size() == expected.size())
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])
	checks += 1

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	checks = 0
	for trial in 32:
		var w := ActorWorld.new()
		w.srv = true
		w.has_view = false
		w.settings = {"players": {5: {"team": 0, "name": "First commander"}, 6: {"team": 1, "name": "Second commander"}}, "ai_teams": [0, 1]}
		w.rules = Rules.new(w)
		w.battle = BattleStats.new(w)
		add_child(w)
		var core: RefCounted = ClassDB.instantiate("BattleStatsCore")
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
		var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
		var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
		var qs: Array[SquadStateCore] = []
		var bearers := PackedInt64Array()
		for owner in [5, 6, -1, -2]:
			assert(core.joined(owner, 0 if owner in [5, -1] else 1, w.battle._name_of(owner, 0 if owner in [5, -1] else 1)))
		for team in 2:
			var q := Squad.new()
			q.world = w
			q.sid = 9 + team
			q.team = team
			q.owner = 5 + team
			q.kind = "rifle_squad" if team == 0 else Defs.SQUADS.keys()[trial % Defs.SQUADS.size()]
			w.squads[q.sid] = q
			w.battle.squad_formed(q)
			assert(core.register_unit("s%d" % q.sid, Squad.callsign_of(team, q.sid), q.display_name(), team, q.owner, w.time, 0))
		for id in range(1, 21):
			var s := make_soldier(w, id, (id + trial) % 2)
			s.owner_peer = [0, 5 + s.team, -1 - s.team][(id + trial) % 3]
			s.utype = "bearer" if id == 20 and trial % 3 == 0 else "rifleman"
			s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
			s.life = (id / 2 + trial) % 6
			s.hidden_reason = ["held", "interrogation", "vehicle", "tent"][(trial + id) % 4]
			s.hp = 17.7 + trial * 1.23
			s.squad = w.squads[9 + s.team]
			s.sid = s.squad.sid
			s.squad.members.append(s)
			s.position = Vector3((id % 5) * 1.1, 0, (id / 5) * 1.2)
			if s.is_bearer(): bearers.append(id)
			w.soldiers.append(s)
		for q: Squad in w.squads.values():
			w.battle.squad_grew(q)
			var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
			assert(qcore.load_state(SquadState.capture(q)))
			assert(core.squad_grew(qcore))
			qs.append(qcore)
		for id in [22, 23]:
			var v := Carrier.new()
			v.world = w
			v.eid = id
			v.team = id % 2
			v.owner_peer = 5 + v.team
			v.vkind = "tank" if id == 22 else "truck"
			v.vdef = Defs.VEHICLES[v.vkind]
			v.hp = 300.0 if trial % 3 else 0.0
			v.max_hp = v.vdef.hp
			w.entities[id] = v
			w.vehicles.append(v)
			w.add_child(v)
			w.battle.vehicle_fielded(v)
			if not v.is_auto() and v.vkind != "truck":
				assert(core.register_unit("v%d" % id, v.display_name(), "vehicle", v.team, v.owner_peer, w.time, 1))
		for id in [24, 25]:
			var st := Mount.new()
			st.world = w
			st.eid = id
			st.team = 1 if id == 24 else 0
			st.owner_peer = 5 + st.team
			st.skind = "fob" if id == 24 else "sandbags"
			st.sname = "Forward Base"
			st.built = true
			st.supply = 19.3 + trial
			w.entities[id] = st
			w.structures.append(st)
			if st.skind == "fob": w.fob_structures.append(st)
			w.add_child(st)
		var kinds := PackedByteArray()
		var blocks := []
		for e: Entity in w.entities.values():
			if e is Soldier:
				kinds.append(0)
				blocks.append(soldier_bytes(e))
			elif e is Vehicle:
				kinds.append(2)
				assert(vehicle.load_state(VehicleState.capture(e)))
				blocks.append(vehicle.checkpoint())
			else:
				kinds.append(1)
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
		assert(actors.load_state(100, kinds, blocks))
		assert(units.load_state(12.0, []) and units.rebuild_units(actors))
		w._rebuild_uhash()
		# More than eight equally successful men exercises the report's tied ranking.
		for source: Soldier in w.soldiers:
			for target: Soldier in w.soldiers:
				if target.team != source.team and target.life == Soldier.Life.ALIVE and not target.is_bearer():
					w.battle.soldier_hit(target, 1.0, source)
					assert(core.record_hit(target.eid, source.eid, 1.0, actors))
					w.battle.soldier_died(target)
					assert(core.soldier_died(target.eid, target.life, false, BattleStats.man_value(target), killer_role(target.hit_by, w), actors))
					break
		for step in 256:
			var dt: float = [0.1, 1.0, 10.0][trial % 3]
			w.time += dt
			var s: Soldier = w.entities[1 + (step / 16 + trial) % 20]
			var source: Soldier = w.entities[1 + (step / 16 + trial + 1) % 20]
			var v: Vehicle = w.entities[22 + (trial % 2)]
			var st: Structure = w.entities[24 + (trial % 2)]
			match step % 16:
				0:
					w.battle.shot(s, trial % 2 == 0)
					assert(core.shot(s.owner_peer, s.team, trial % 2 == 0))
				1:
					w.battle.soldier_hit(s, 77.7, source)
					assert(core.record_hit(s.eid, source.eid, 77.7, actors))
				2:
					w.battle.soldier_down(s)
					assert(core.soldier_down(s.eid, s.is_bearer(), actors))
				3:
					w.battle.soldier_died(s)
					assert(core.soldier_died(s.eid, s.life, s.is_bearer(), BattleStats.man_value(s), killer_role(s.hit_by, w), actors))
				4:
					w.battle.prisoner(s, source)
					assert(core.prisoner(s.eid, source.eid, BattleStats.man_value(s), actors))
				5:
					w.battle.vehicle_hit(v, 377.7, source)
					assert(core.record_hit(v.eid, source.eid, 377.7, actors))
				6:
					w.battle.vehicle_destroyed(v)
					assert(core.destroyed(v.eid, true, v.vdef.cost, w.time, "%s %s lost" % [Defs.TEAM_NAMES[v.team], v.display_name()], killer_role(v.hit_by, w), actors))
				7:
					w.battle.structure_hit(st, source)
					assert(core.record_hit(st.eid, source.eid, 0.0, actors))
				8:
					w.battle.building_destroyed(st)
					assert(core.destroyed(st.eid, false, Defs.BUILDINGS[st.skind].cost, w.time, "FOB %s wrecked" % st.sname, "", actors))
				9:
					var field := 14 + trial % 11
					w.battle.add(s.owner_peer, s.team, BattleStats.FIELDS[field], 19.71)
					assert(core.add(s.owner_peer, s.team, field, 19.71))
				10:
					var kind: String = ["sup", "fob", "town"][trial % 3]
					w.battle._event(source.team, kind, "Report")
					assert(core.event(w.time, source.team, kind, "Report"))
				11:
					assert(core.taker(Vector3.ZERO, 10.0, s.team, actors, units) == [w.battle._taker(Vector3.ZERO, 10.0, s.team)])
				12:
					var old := 5 if step == 12 else 7
					w.battle.rejoined(old, 7, 0)
					assert(core.rejoined(old, 7, 0, w.battle._name_of(7, 0)))
				13:
					w.battle.squad_gone(s.squad)
					assert(core.squad_gone(s.sid, w.time))
				14:
					var previous := w.battle.blame(5, 0)
					assert(core.blame(w.battle._blame))
					w.battle.soldier_hit(s, 91.7, null)
					assert(core.record_hit(s.eid, 0, 91.7, actors))
					w.battle.end_blame(previous)
					assert(core.blame(previous))
			var supply := PackedFloat64Array([w.rules.supply_total(0), w.rules.supply_total(1)])
			w.battle.tick(dt)
			assert(core.tick(dt, w.time, supply, bearers, actors))
			if step % 17 == 0 or step == 255:
				w.winner = trial % 2 if step == 255 else -1
				for view in [-1, 0, 1]:
					var expected := report_rows(w.battle, w.battle.report(view))
					var actual: Array = core.report(view, w.winner >= 0, w.time, supply, bearers, actors, qs)
					for group in expected.size():
						assert(expected[group] == actual[group], "report %d/%d/%d group %d: %s / %s" % [trial, step, view, group, expected[group], actual[group]])
			compare_ledger(w.battle, core, "%d/%d" % [trial, step])
			if step % 60 == 59:
				assert(core.restore(core.checkpoint()) and actors.restore(actors.checkpoint()))
		w.free()
	print("BATTLE_STATS passed states=", checks)
	get_tree().quit()
