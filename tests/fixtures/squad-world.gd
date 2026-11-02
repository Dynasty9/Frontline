extends "res://tests/fixtures/ambush-plan.gd"

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new(); var records := preload("res://tests/fixtures/battle-stats.gd").new(); var duties := preload("res://tests/fixtures/squad-duties.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 32:
		var w := AttackWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; add_child(w)
		w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.rules = Rules.new(w); w.combat = Combat.new(w); w.combat.enable_native_collision(); w.battle = BattleStats.new(w)
		var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var qs: Array[Squad] = []; var cores: Array[SquadStateCore] = []; var plans := {}; var attacks: Array[AttackPlan] = []; var ambushes: Array[AmbushPlan] = []
		var case_id := trial % 16
		for index in 2:
			var sq := Squad.new(); sq.world = w; sq.sid = 7+index; sq.team = trial / 16; sq.owner = 1; sq.kind = "crew" if case_id == 11 else "rifle_squad"; sq.morale = 70.0
			w.squads[sq.sid] = sq; qs.append(sq); cores.append(ClassDB.instantiate("SquadStateCore"))
		var q := qs[0]; var other := qs[1]
		for id in range(1,12):
			var s := make_soldier(w,id,1-q.team if id in [7,8] else q.team); w.soldiers.append(s)
			s.position = Vector3(-28.1+id*0.71,0,-3.7+id*1.37) if id <= 6 else Vector3(20,0,3+id) if id <= 8 else Vector3(-12 if case_id == 12 else 62,0,-10+id)
			s.utype = "medic" if id == 6 else "engineer" if id == 5 else "mg_gunner" if id == 4 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 1; s.frags = 2; s.say_cd = 1.7 if trial % 3 else 0.0
			if id <= 6: q.add(s)
			elif id >= 9: other.add(s)
		q.leader = w.entities[1]; other.leader = w.entities[9]
		match case_id:
			0: w.entities[1].life = Soldier.Life.DOWNED; q.known[7] = {"e":w.entities[7],"pos":w.entities[7].position,"t":100.0}
			1: w.entities[2].hp = 30.0; w.entities[3].hp = 20.0
			2:
				var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100; st.team = q.team; st.skind = "hesco"; st.size = Vector3(8,2,1); st.position = Vector3(-15,0,7)
				w._register(st); w.add_child(st); st.on_spawned(); st.hp = st.max_hp*0.5; w._shash_add(st); w.terrain.structure_changed(st)
			3,4:
				q.morale = 25.0 if case_id == 3 else 2.0; q.known[7] = {"e":w.entities[7],"pos":w.entities[7].position,"t":100.0}
			7: q.order = "move"; q.order_pos = Vector3(30,0,5); q.travel = true; q.morale = -1.0
			8: q.think_t = 2.0
			9:
				for s: Soldier in q.members: s.life = Soldier.Life.DOWNED
				q.known[7] = {"e":w.entities[7],"pos":w.entities[7].position,"t":70.0}
			10: q.impacts = [[q.centroid(),99.0],[q.centroid()+Vector3(1,0,2),99.5]]
			12,14:
				for id in range(2,7): w.entities[id].life = Soldier.Life.DEAD
				if case_id == 14: w.entities[1].suppression = 60.0; w.entities[7].position = Vector3(-10,0,2)
			13: q.clear_call = [w.entities[3],100.5]; q.then_defend = [q.centroid(),Vector3.FORWARD]; q.order = "move"
			15:
				for s: Soldier in q.members: s.life = Soldier.Life.DEAD
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		if case_id == 5:
			var p := AmbushPlan.make(w,q,Vector3.ZERO,Vector3.BACK,Vector3.LEFT); plans[p] = 19; ambushes.append(p)
		elif case_id == 6:
			q.order_assault(Vector3(30,0,7),Vector3.RIGHT); assert(q.plan != null); plans[q.plan] = 17; attacks.append(q.plan)
		for i in 2:
			w.battle.squad_formed(qs[i]); w.battle.squad_grew(qs[i]); assert(cores[i].load_state(SquadState.capture(qs[i],plans)))
			assert(ledger.register_unit("s%d" % qs[i].sid,qs[i].callsign(),qs[i].display_name(),qs[i].team,qs[i].owner,w.time,0)); assert(ledger.squad_grew(cores[i]))
		assert(geometry.restore(helper.world_save(w))); w.rng.seed = 12317+trial; rng.seed = w.rng.seed
		for step in 12:
			if not w.squads.has(q.sid): continue
			w.time = 100.0+step*0.25
			if step == 3 and case_id == 5:
				for s: Soldier in q.members: s.position = ambushes[0].rally
				q._centroid_t = -1.0
			w._rebuild_uhash(); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
			var profiles := import_actors(w,actors); var extra := []; var roles := []; var air := []
			for e: Entity in w.entities.values():
				if e is Soldier:
					extra.append([e.eid,int(e.wdef.get("ammo",-1)),int(e.cur_weapon().get("mag",30)),float(e.cur_weapon().get("reload",2.0)),0]); roles.append([e.eid,bool(e.udef.get("medic",false)),bool(e.udef.get("engineer",false))])
				elif e is Vehicle: extra.append([e.eid,-1,0,0.0,int(e.vdef.get("armor",0))]); air.append([e.eid,e.is_heli()])
			for i in 2: assert(cores[i].load_state(SquadState.capture(qs[i],plans)))
			var saved_attacks: Array[PackedByteArray] = []; var saved_ambushes: Array[PackedByteArray] = []
			for p: AttackPlan in attacks: saved_attacks.append(plan_bytes(p))
			for p: AmbushPlan in ambushes: saved_ambushes.append(ambush_bytes(p))
			w.spoken.clear(); w.messages.clear(); w.stats.clear(); w.effects.clear(); q.tick(0.25)
			var result: Array = movement.apply(actors,geometry,units,cores,rng._backend,profiles,w.time,w.town_rect,7,26,[[0.25,extra,saved_attacks,w.recent_impacts],roles,air,ledger,saved_ambushes])
			var label := "squad tick %d/%d" % [trial,step]; assert(result.size() == 3,label+" result")
			var said := []; var stats := {}; var messages := []; var retired := false
			for e: Array in result[0]:
				match int(e[0]):
					0: said.append([e[1],speech(q,e[2],e[3])])
					1: pass
					2: stats[e[1]] = stats.get(e[1],0)+1; seen[e[1]] = true
					5: said.append([e[1],e[2]])
					6: messages.append([e[1],"alert","%s: outnumbered at %s, gone firm. Need fires or reinforcements!" % [Squad.callsign_of(e[1],e[2]),Defs.grid_ref(e[3])],e[3]])
					7: said.append([e[1],ambush_speech(q,e) if int(e[2]) >= 19 else duties.duty_speech(q,e)])
					8: messages.append([q.team,"info",q.display_name()+" sprang its ambush.",e[3]] if int(e[2]) == 5 else brain_message(q,e))
					9: messages.append([q.team,"info","The last man of %s has joined %s." % [w.squads[e[1]].display_name(),w.squads[e[2]].display_name()],e[4]])
					11: retired = true; seen.retired = true
					_: assert(false,label+" event "+str(e))
			assert(said == w.spoken,label+" speech "+str([said,w.spoken])); assert(stats == w.stats,label+" stats "+str([stats,w.stats])); assert(messages == w.messages,label+" messages "+str([messages,w.messages])); assert(retired == not w.squads.has(q.sid),label+" retirement")
			for i in 2: compare_squad(qs[i],cores[i],plans,label+" squad "+str(i))
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+" actor "+str(s.eid))
			for i in attacks.size(): assert(result[1][i] == plan_bytes(attacks[i]),label+" attack plan")
			for i in ambushes.size(): assert(result[2][i] == ambush_bytes(ambushes[i]),label+" ambush plan")
			records.compare_ledger(w.battle,ledger,label)
			assert(w.rng.state == rng.state,label+" random"); assert(geometry.inspect()[1] == helper.nav_save(w.nav),label+" queue")
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+" routed "+str(s.eid))
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(geometry.restore(geometry.checkpoint())); assert(ledger.restore(ledger.checkpoint()))
			checks += 1
		for p: AttackPlan in attacks: p.support.clear(); p.assault.clear()
		for sq: Squad in qs: sq.plan = null; sq.ambush_plan = null
		plans.clear(); attacks.clear(); ambushes.clear(); w.free()
	for key in ["rescue","straggler_joined","squad_rout","break_contact","displace","house_cleared","retired"]: assert(seen.has(key),"squad tick coverage "+key)
	helper.free(); records.free(); duties.free(); print("SQUAD_WORLD passed states=",checks," coverage=",seen); get_tree().quit()
