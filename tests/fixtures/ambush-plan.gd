extends "res://tests/fixtures/squad-brain.gd"

func ambush_bytes(p: AmbushPlan) -> PackedByteArray:
	var b := StreamPeerBuffer.new(); b.put_data("FLAM01".to_utf8_buffer()); b.put_u16(SimulationInitial.NUMERIC_VERSION)
	b.put_u32(19); b.put_u32(p.sq.sid)
	for at: Vector3 in [p.kz,p.road,p.side,p.rally]: point_bytes(b,at)
	b.put_double(p.mg_end); b.put_u8(["move","wait","spring"].find(p.phase))
	for t: float in [p.t0,p.fire_t,p.quiet_t]: b.put_double(t)
	b.put_u8(int(p.done)); b.put_u32(p.caught); return b.data_array

func ambush_speech(q: Squad, e: Array) -> String:
	var variant: int = e[3]
	match int(e[2]):
		19: return (["We hit them on the road. Move quiet.","Ambush on the road - nobody fires till I do.","Into the ambush position. Silence from here."] if q.team == 0 else ["We wait for them by the road. Quiet now.","We'll hit them on the road. Follow me."])[variant]
		20: return (["FIRE!","Now! Open fire!","Hit them!","Light them up!"] if q.team == 0 else ["NOW! Kill them!","Allahu akbar! Fire!","Fire, fire!"])[variant]
		21: return (["Cease fire! Pull back to the rally point!","That's it - break contact, go!","Done! Smoke, back by teams!"] if q.team == 0 else ["Enough! Go, go - scatter!","Back! Back to the rally point!","Melt away! Go!"])[variant]
	return brain_speech(q,e)

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 32:
		var w := AttackWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; add_child(w)
		w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.rules = Rules.new(w); w.combat = Combat.new(w); w.combat.enable_native_collision()
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial / 8 % 2; q.owner = trial / 8 - 1; q.kind = "rifle_squad"; w.squads[7] = q
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var cores: Array[SquadStateCore] = [core]; var plans := {}
		for id in range(1,9):
			var s := make_soldier(w,id,q.team if id <= 6 else 1-q.team); w.soldiers.append(s)
			s.position = Vector3(-28.1+id*0.71,0,-3.7+id*1.37) if id <= 6 else Vector3(62,0,55+id)
			s.utype = "mg_gunner" if id == 4 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 1; s.frags = 2; s.say_cd = 1.7 if trial % 3 else 0.0
			if id <= 6: q.add(s)
		q.leader = w.entities[1]
		if trial >= 16: w.entities[3].task = "breach"; w.entities[3].task_phase = 2
		var v := Truck.new(); v.world = w; v.srv = true; v.eid = 110; v.team = 1-q.team
		v.vkind = "falcon" if trial % 8 == 5 else "tank"; v.vdef = Defs.VEHICLES[v.vkind]; v.position = Vector3(62,0,62); w.add_child(v); w._register(v)
		for index in 2:
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100+index; st.team = -1; st.skind = "hesco"
			st.size = Vector3(1,2,10); st.position = Vector3(-20.3,0,-25+index*50); st.yaw = trial % 4*0.317; st.rotation.y = st.yaw
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); w.rng.seed = 9717+trial; rng.seed = w.rng.seed
		var p: AmbushPlan = null; var case_id := trial % 8
		for step in 12:
			w.time = 100.0+step*7.1
			if step == 1:
				if case_id == 1: q.known[7] = {"e":w.entities[7],"pos":q.centroid()+Vector3.RIGHT*20,"t":w.time}
				elif case_id == 7: q.drill = "rout"
				else:
					for s: Soldier in q.members: s.position = p.rally
			if step == 2:
				for s: Soldier in q.members: s.position = Vector3(-24,0,s.eid*1.3)
				if case_id in [0,3,4]: w.entities[7].position = Vector3.ZERO
				if case_id == 0: w.entities[8].position = Vector3(1,0,3)
				if case_id == 4: w.entities[7].life = Soldier.Life.DOWNED
				if case_id in [5,6]: v.position = Vector3(0,20 if case_id == 5 else 0,0)
			if step >= 3 and case_id == 2: w.time += 300.0
			if step == 3 and case_id == 4: w.entities[2].suppression = 60.0
			if step == 3 and case_id == 5: w.entities[7].position = Vector3(-23,0,2)
			if step == 5 and case_id == 3: w.entities[7].position = Vector3(62,0,62)
			q._centroid_t = -1.0
			w._rebuild_uhash(); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
			var profiles := import_actors(w,actors); assert(core.load_state(SquadState.capture(q,plans)))
			w.spoken.clear(); w.messages.clear(); w.stats.clear()
			var op := 25; var args := []
			if step == 0:
				op = 24; args = [19,Vector3.ZERO,Vector3(0,0,1),Vector3(-1,0,0)]
				p = AmbushPlan.make(w,q,args[1],args[2],args[3]); plans[p] = 19
			else: args = [ambush_bytes(p),[[110,v.is_heli()]]]; p.tick()
			var result: Array = movement.apply(actors,geometry,units,cores,rng._backend,profiles,w.time,w.town_rect,7,op,args)
			var label := "ambush %d/%d" % [trial,step]; assert(result.size() == 2,label+" result")
			var said := []; var stats := {}; var messages := []
			for e: Array in result[0]:
				match int(e[0]):
					0: said.append([e[1],speech(q,e[2],e[3])])
					2: stats[e[1]] = stats.get(e[1],0)+1; seen[e[1]] = true
					7: said.append([e[1],ambush_speech(q,e)])
					8: messages.append([q.team,"info",q.display_name()+" sprang its ambush.",e[3]] if int(e[2]) == 5 else brain_message(q,e))
					_: assert(false,label+" event "+str(e))
			assert(said == w.spoken,label+" speech "+str([said,w.spoken])); assert(stats == w.stats,label+" stats "+str([stats,w.stats])); assert(messages == w.messages,label+" messages")
			assert(result[1] == ambush_bytes(p),label+" plan")
			compare_squad(q,core,plans,label)
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+" actor "+str(s.eid))
			assert(w.rng.state == rng.state,label+" random"); assert(geometry.inspect()[1] == helper.nav_save(w.nav),label+" queue")
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+" routed "+str(s.eid))
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(geometry.restore(geometry.checkpoint())); assert(core.restore(core.checkpoint()))
			checks += 1
		q.ambush_plan = null; plans.clear(); p = null; w.free()
	for key in ["ambush_set_out","ambush_laid","ambush_sprung","ambush_caught","ambush_withdraw","ambush_abandoned"]: assert(seen.has(key),"ambush coverage "+key)
	helper.free(); print("AMBUSH_PLAN passed states=",checks," coverage=",seen); get_tree().quit()
