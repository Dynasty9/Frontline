extends "res://tests/fixtures/squad-orders.gd"

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new(); var guns := preload("res://tests/fixtures/infantry-fire.gd").new()
	var movement: RefCounted = ClassDB.instantiate("SquadMovementCore"); var count := 0; var calls := {}
	for trial in 36:
		var w := make_world(false); w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w)
		w.nav = Nav.new(); w.nav.terrain = w.terrain; w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w)
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial % 2; q.owner = 1; q.kind = "rifle_squad"; w.squads[7] = q
		for id in range(1,8):
			var s := make_soldier(w,id,q.team if id <= 6 else 1-q.team); w.soldiers.append(s)
			s.position = Vector3(-30.3+id*0.71,0,id*1.37-3.7) if id <= 6 else Vector3(40.7,0,10.1)
			s.utype = "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 0 if id == 2 else 2; s.frags = 0 if id == 2 else 3; s.say_cd = 1.7
			if id <= 6: q.add(s)
		if trial % 3 == 0: w.entities[4].life = Soldier.Life.DOWNED
		w.entities[5].task = "breach"; w.entities[5].task_phase = 2
		w.entities[3].task = "rescue"; w.entities[3].task_ent = w.entities[4]; w.entities[4].dragged_by = w.entities[3]; w.entities[4].rescue_claimed = w.entities[3]
		q.leader = w.entities[1]; q.order_n = trial
		var st := Mount.new(); st.world = w; st.srv = true; st.eid = 100; st.team = q.team
		st.skind = ["watchtower","mortar_pit","at_post","mg_nest","hmg_nest","sandbags"][trial % 6]
		st.position = Vector3(-12.7,0,-7.1); st.yaw = trial*0.317-1.3; st.rotation.y = st.yaw
		w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
		if trial % 2 == 0:
			var fob := Mount.new(); fob.world = w; fob.srv = true; fob.eid = 101; fob.team = q.team; fob.skind = "fob"; fob.position = Vector3(-40,0,30)
			w._register(fob); w.add_child(fob); fob.on_spawned(); w._shash_add(fob); w.terrain.structure_changed(fob)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var state: RefCounted = ClassDB.instantiate("StructureStateCore")
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var qs: Array[SquadStateCore] = [core]
		assert(core.load_state(SquadState.capture(q))); var profiles := import_actors(w,actors)
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		var rng := SimulationRandom.new(); w.rng.seed = 7617+trial; rng.seed = w.rng.seed
		for step in 12:
			w.time += 0.5; w.spoken.clear(); w.stats.clear()
			var id := 2 if step == 2 else 4 if step == 9 else 5 if step == 10 else 3
			var s: Soldier = w.entities[id]; var p := st.position + Vector3(1.7,0,1.3); var face := Vector3(sin(trial*0.4),0,cos(trial*0.4)) if trial % 3 else Vector3.ZERO
			var d := {}; var order := []
			match step % 6:
				0: d = {"o":"move","pos":p,"face":face,"mode":trial%3}; order = [0,p,face,trial%3]
				1: d = {"o":"attack","target":7 if step == 1 else 2}; order = [1,d.target]
				2: d = {"o":"throw","pos":Vector3(30,0,7),"kind":"frag" if step == 2 else "smoke"}; order = [2,d.pos,step != 2]
				3: d = {"o":"stop"}; order = [3]
				4: d = {"o":"retreat"}; order = [4]
				5: d = {"o":"man","target":st.eid}; order = [5,st.eid,guns.gun_profile(st) if st.skind in ["mg_nest","hmg_nest"] else PackedFloat64Array()]
			var weapon := s.cur_weapon(); var weapon_range := float(weapon.get("range",40.0)) if not weapon.is_empty() else -1.0
			var result: Array = movement.apply(actors,geometry,units,qs,rng._backend,profiles,w.time,w.town_rect,id,35,[order,weapon_range])
			s.unit_order(d); var label := "%d/%d/%s" % [trial,step,st.skind]; assert(result.size() == 1,"result "+label)
			var said := []; var stats := {}
			for e: Array in result[0]:
				if e[0] == 0:
					calls[e[2]] = true; said.append([e[1],"I'm out!" if e[2] == 16 else ["On it.","Moving.","Copy that.","Roger.","Got it.","Going."][e[3]]])
				elif e[0] == 2: stats[e[1]] = stats.get(e[1],0)+1
				else: assert(false,"unexpected unit order event")
			assert(said == w.spoken,"speech "+label+str([said,w.spoken])); assert(stats == w.stats,"stats "+label)
			compare_squad(q,core,{},label)
			for soldier: Soldier in w.soldiers: compare_actor(soldier,actors,label+"/"+str(soldier.eid))
			for building: Structure in w.structures: assert(state.restore(actors.actor_state(building.eid))); assert(state.values() == StructureState.capture(building),"structure "+label)
			assert(w.rng.state == rng.state,"random "+label); assert(geometry.inspect()[1] == helper.nav_save(w.nav),"routes "+label)
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for soldier: Soldier in w.soldiers: compare_actor(soldier,actors,label+" routed/"+str(soldier.eid))
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint())); assert(geometry.restore(geometry.checkpoint())); count += 1
		w.free()
	assert(calls.has(15) and calls.has(16),"speech coverage")
	helper.free(); guns.free(); print("UNIT_ORDERS passed states=",count); get_tree().quit()
