extends "res://tests/fixtures/squad-brain.gd"

func duty_speech(q: Squad, e: Array) -> String:
	var variant: int = e[3]
	match int(e[2]):
		14: return ["Covering fire!", "Suppress them!", "Lay it down, get him out!"][variant]
		15: return (["I'm all that's left! I'm with you!", "They got my whole squad... I'm with you guys.", "Mind if I tag along?"] if q.team == 0 else ["My brothers are dead! I fight with you!", "I'm with you now!"])[variant]
		16: return ["Get in here! Take the left.", "On me. Watch our flank.", "Good to have you."][variant]
		17: return (["Clear!", "Room clear!", "Clear! Next room!", "Building clear!"] if q.team == 0 else ["Empty!", "Nobody here!", "Clear!"])[variant]
		18: return ["Don't shoot! I surrender!", "I give up! I give up!", "Okay! Okay! Don't shoot!"][variant]
	return brain_speech(q,e)

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new(); var records := preload("res://tests/fixtures/battle-stats.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 32:
		var w := AttackWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; add_child(w)
		w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.rules = Rules.new(w); w.combat = Combat.new(w); w.combat.enable_native_collision(); w.battle = BattleStats.new(w)
		var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial / 8 % 2; q.owner = trial / 8 - 1; q.kind = "rifle_squad"; q.morale = 70.0; w.squads[7] = q
		var other := Squad.new(); other.world = w; other.sid = 8; other.team = q.team; other.owner = q.owner; other.kind = "rifle_squad"; other.morale = 70.0; w.squads[8] = other
		var cores: Array[SquadStateCore] = [ClassDB.instantiate("SquadStateCore"),ClassDB.instantiate("SquadStateCore")]
		var scenario := trial % 8
		for id in range(1,12):
			var s := make_soldier(w,id,1-q.team if id in [7,8] else q.team); w.soldiers.append(s)
			s.position = Vector3(-28.1 + id * 0.71,0,-3.7 + id * 1.37) if id <= 6 else Vector3(-10,0,3+id) if id <= 8 else Vector3(-12 if scenario == 5 else 62,0,-10+id)
			s.utype = "medic" if id == 6 else "engineer" if id == 5 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 1 if trial < 16 else 0; s.frags = 2; s.say_cd = 1.7 if trial % 3 else 0.0
			if id <= 6: q.add(s)
			elif id >= 9: other.add(s)
		q.leader = w.entities[1]; other.leader = w.entities[9]
		match scenario:
			0,1:
				w.entities[1].life = Soldier.Life.DOWNED; w.entities[1].rescue_claimed = w.entities[2]
				w.entities[2].task = "escort"; w.entities[2].task_ent = w.entities[1]; w.entities[2].task_ent2 = w.entities[4]
				w.entities[4].task = "build"
				if scenario == 0: q.known = {7:{"e":w.entities[7],"pos":w.entities[7].position,"t":100.0}}
			2: w.entities[2].hp = 30.0; w.entities[3].hp = 20.0
			5,6,7:
				for id in range(2,7): w.entities[id].life = Soldier.Life.DEAD
				if scenario == 6: w.entities[2].life = Soldier.Life.DOWNED
				if scenario == 7: w.entities[1].suppression = 60.0
		if scenario == 3:
			q.order = "build" if trial >= 16 else "hold"
			for index in 2:
				var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.team = q.team
				st.skind = "depot" if index == 0 else "hesco"; st.size = Vector3(8,2,1); st.position = Vector3(-15,0,3+index*8)
				w._register(st); w.add_child(st); st.on_spawned(); st.hp = st.max_hp * 0.5; w._shash_add(st); w.terrain.structure_changed(st)
		if scenario == 4:
			var v := Truck.new(); v.world = w; v.srv = true; v.eid = 110; v.team = q.team; v.vkind = "tank"; v.vdef = Defs.VEHICLES.tank
			v.hp = 50.0; v.max_hp = 100.0; v.track_fix = 2.0; v.position = Vector3(-15,0,7); w.add_child(v); w._register(v)
		if scenario in [2,4]: q.then_defend = [Vector3(-25,0,2),Vector3.FORWARD]; q.order = "move"
		q.clear_call = [w.entities[3],100.5]
		for sq: Squad in [q,other]:
			w.battle.squad_formed(sq); w.battle.squad_grew(sq)
			assert(ledger.register_unit("s%d" % sq.sid,sq.callsign(),sq.display_name(),sq.team,sq.owner,w.time,0))
			assert(cores[sq.sid - 7].load_state(SquadState.capture(sq))); assert(ledger.squad_grew(cores[sq.sid - 7]))
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		w.rng.seed = 8317 + trial
		if scenario == 7:
			for seed_value in 1000:
				w.rng.seed = seed_value
				if w.rng.randf() < 0.035: w.rng.seed = seed_value; break
		rng.seed = w.rng.seed
		for step in 4:
			w.time = 100.0 + step * 0.5
			var profiles := import_actors(w,actors); var roles := []
			for s: Soldier in w.soldiers: roles.append([s.eid,bool(s.udef.get("medic",false)),bool(s.udef.get("engineer",false))])
			assert(cores[0].load_state(SquadState.capture(q))); assert(cores[1].load_state(SquadState.capture(other)))
			for op in [21,22,23,17,20,18,19]:
				w.spoken.clear(); w.messages.clear(); w.stats.clear(); w.effects.clear()
				match op:
					17: q._rescue_logic()
					18: q._medic_logic()
					19: q._engineer_logic()
					20: q._surrender_logic()
					21: Tactics.straggler_tick(q)
					22: Tactics.then_defend_tick(q)
					23: Tactics.clear_call_tick(q)
				var result: Array = movement.apply(actors,geometry,units,cores,rng._backend,profiles,w.time,w.town_rect,7,op,[roles,ledger])
				assert(result.size() == 2,"duty result %d/%d/%d" % [trial,step,op])
				var said := []; var stats := {}; var messages := []; var effects := []
				for e: Array in result[0]:
					match int(e[0]):
						0: said.append([e[1],speech(q,e[2],e[3])])
						2: stats[e[1]] = stats.get(e[1],0) + 1; seen[e[1]] = true
						7: said.append([e[1],duty_speech(q,e)])
						9: messages.append([q.team,"info","The last man of %s has joined %s." % [w.squads[e[1]].display_name(),w.squads[e[2]].display_name()],e[4]])
						10:
							var s: Soldier = w.entity(e[1]); var at: Vector3 = e[3]
							effects.append([Fx.RIFLE_DROP,at + Vector3(0,1.2,0),e[4]])
							messages.append([e[2],"alert","%s has surrendered at %s." % [s.sname,Defs.grid_ref(at)],at])
							messages.append([1-e[2],"info","An enemy soldier is surrendering at %s." % Defs.grid_ref(at),at])
						_: assert(false,"unknown squad duty " + str(e))
				var label := "duties %d/%d/%d" % [trial,step,op]
				assert(said == w.spoken,label + " speech " + str([said,w.spoken])); assert(stats == w.stats,label + " stats " + str([stats,w.stats])); assert(messages == w.messages,label + " messages " + str([messages,w.messages]))
				assert(effects.size() == w.effects.size(),label + " effect count")
				for index in effects.size():
					assert(effects[index].slice(0,2) == w.effects[index].slice(0,2),label + " effect identity and position")
					# The visual rifle toss uses platform cosine in Godot, pinned libm in Rust.
					assert((effects[index][2] as Vector3).distance_to(w.effects[index][2]) <= 1e-7,label + " rifle direction")
				compare_squad(q,cores[0],{},label); compare_squad(other,cores[1],{},label + " other")
				for s: Soldier in w.soldiers:
					compare_actor(s,actors,label + "/" + str(s.eid))
					if s.task in ["heal","build"]: seen[s.task] = true
				records.compare_ledger(w.battle,ledger,label)
				assert(w.rng.state == rng.state,label + " random"); assert(geometry.inspect()[1] == helper.nav_save(w.nav),label + " queue")
				checks += 1
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,"duty route %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(ledger.restore(ledger.checkpoint())); assert(geometry.restore(geometry.checkpoint()))
			for core: SquadStateCore in cores: assert(core.restore(core.checkpoint()))
		w.free()
	for key in ["rescue","escort","heal","build","surrender","straggler_joined","house_cleared"]: assert(seen.has(key),"duty coverage " + key)
	helper.free(); records.free(); print("SQUAD_DUTIES passed states=",checks," coverage=",seen); get_tree().quit()
