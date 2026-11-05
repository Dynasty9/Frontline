extends "res://tests/fixtures/squad-movement.gd"

func order_position_equal(a: Vector3, b: Vector3) -> bool:
	for axis in 3:
		if not is_finite(a[axis]) or not is_finite(b[axis]) or absf(a[axis]-b[axis]) > 0.00000024*maxf(1.0,maxf(absf(a[axis]),absf(b[axis]))): return false
	return true

func compare_actor(s: Soldier, actors: RefCounted, label: String) -> void:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore"); assert(state.restore(actors.actor_state(s.eid)))
	var expected := InfantryState.capture(s); var actual: Array = state.values()
	# Godot's platform sinf/cosf can round a rotated work spot differently from pinned libm.
	# Only the work destination, task position and delivered path allow rounding; Rust transcripts stay exact.
	var path: PackedVector3Array = expected[1][1][1]; var route: PackedVector3Array = actual[1][1][1]
	assert(path.size() == route.size(),label+" path length")
	for i in mini(path.size(),route.size()): assert(order_position_equal(path[i],route[i]),label+" path "+str(i))
	assert(order_position_equal(expected[4][5],actual[4][5]),label+" task position")
	if expected[2][2] != actual[2][2]: assert(order_position_equal(expected[2][2],actual[2][2]),label+" destination")
	expected[1][1][1] = route; expected[4][5] = actual[4][5]; expected[2][2] = actual[2][2]
	for group in expected.size(): assert(expected[group] == actual[group],"%s group %d: %s / %s" % [label,group,expected[group],actual[group]])

func order_speech(q: Squad, call: int, variant: int) -> String:
	match call:
		10: return ["Engaging!", "Target spotted, moving in!", "Light 'em up!"][variant]
		11: return ["On it.", "Get building!", "Let's get this up."][variant]
		12: return ["Mount up!", "Everybody in!", "Load up, let's go!"][variant]
		13: return ["Into the bunker!", "Get inside!", "Man the slits!"][variant]
		14: return "Fire mission, %s. Copy!" % ("smoke" if variant == 1 else "HE")
	return speech(q,call,variant)

func _ready() -> void:
	assert(order_position_equal(Vector3(16,0,4),Vector3(16.000002,0,4)))
	assert(not order_position_equal(Vector3(16,0,4),Vector3(16.001,0,4)))
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new(); var gun := preload("res://tests/fixtures/infantry-fire.gd").new()
	var movement: RefCounted = ClassDB.instantiate("SquadMovementCore"); var count := 0; var seen := {}
	for trial in 48:
		var w := make_world(false); w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w)
		w.nav = Nav.new(); w.nav.terrain = w.terrain; w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w)
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial % 2; q.owner = -1-q.team; q.kind = "rifle_squad"; w.squads[7] = q
		for id in range(1,8):
			var s := make_soldier(w,id,q.team if id <= 6 else 1-q.team); w.soldiers.append(s)
			s.position = Vector3(-30.3+id*0.71,0,id*1.37-3.7) if id <= 6 else Vector3(40.7,0,10.1)
			s.utype = "mg_gunner" if id == 1 else "mortar_gunner" if id == 4 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 0 if id == 2 else 2; s.frags = 0 if id == 2 else 3; s.detached = true; s.say_cd = 1.7
			if id <= 6: q.add(s)
		if trial % 3 == 0: w.entities[2].life = Soldier.Life.DOWNED
		if trial % 5 == 0:
			w.entities[3].task = "rescue"; w.entities[3].task_ent = w.entities[2]; w.entities[2].dragged_by = w.entities[3]; w.entities[2].rescue_claimed = w.entities[3]
		if trial % 7 == 0: w.entities[5].task = "breach"; w.entities[5].task_phase = 2
		q.leader = w.entities[1]; q.order_n = trial; q.alert_t = 99.0 if trial % 2 else -99.0
		var st := Mount.new(); st.world = w; st.srv = true; st.eid = 100; st.team = q.team
		st.skind = ["tunnel","bunker","watchtower","mortar_pit","at_post","mg_nest","hmg_nest","sandbags"][trial % 8]
		st.position = Vector3(-12.7 if trial % 3 else 24.3,0,-7.1); st.yaw = trial*0.317-1.3; st.rotation.y = st.yaw
		w._register(st); w.add_child(st); st.on_spawned(); st.hp = st.max_hp * 0.7 if trial % 2 else st.max_hp
		w._shash_add(st); w.terrain.structure_changed(st)
		var v := Truck.new(); v.world = w; v.srv = true; v.eid = 110; v.team = q.team; v.vkind = "truck"; v.vdef = Defs.VEHICLES.truck.duplicate()
		v.vdef.seats = 2+trial%4; v.position = Vector3(-10,0,12); v.passengers = [w.entities[7]]; w.add_child(v); w._register(v)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var state: RefCounted = ClassDB.instantiate("StructureStateCore")
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var qs: Array[SquadStateCore] = [core]
		assert(core.load_state(SquadState.capture(q))); var profiles := import_actors(w,actors)
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		var rng := SimulationRandom.new(); w.rng.seed = 7317+trial; rng.seed = w.rng.seed
		for step in 16:
			w.time += 0.5; w.spoken.clear(); w.stats.clear(); var input := []; var op := 27+mini(step%8,6)
			var target: Entity = st if step == 0 else w.entities[7]; var p := Vector3(27.3,0,-7.1); var smoke := trial % 2 == 0
			match step % 8:
				0: input = [target.eid]; q.order_attack(target)
				1: q.order_stop()
				2: input = [st.eid]; q.order_work(st)
				3: input = [v.eid,v.seats()]; q.order_board(v)
				4: input = [st.eid,gun.gun_profile(st) if st.skind in ["mg_nest","hmg_nest"] else PackedFloat64Array()]; q.order_enter(st)
				5: input = [p,smoke,PackedInt64Array([4])]; q.order_fire_mission(p,"smoke" if smoke else "he")
				6,7: input = [p,step % 8 == 7]; q.order_throw(p,"smoke" if step % 8 == 7 else "frag")
			var result: Array = movement.apply(actors,geometry,units,qs,rng._backend,profiles,w.time,w.town_rect,7,op,input)
			var label := "%d/%d/%s" % [trial,step,st.skind]; assert(result.size() == 1,"result "+label)
			var said := []; var stats := {}
			for e: Array in result[0]:
				if e[0] == 0: said.append([e[1],order_speech(q,e[2],e[3])]); seen[e[2]] = true
				elif e[0] == 2: stats[e[1]] = stats.get(e[1],0)+1
				else: assert(false,"unexpected order event "+str(e))
			assert(said == w.spoken,"speech "+label+str([said,w.spoken])); assert(stats == w.stats,"stats "+label)
			compare_squad(q,core,{},label)
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+"/"+str(s.eid))
			assert(state.restore(actors.actor_state(st.eid))); assert(state.values() == StructureState.capture(st),"structure "+label)
			assert(w.rng.state == rng.state,"random "+label); assert(geometry.inspect()[1] == helper.nav_save(w.nav),"routes "+label)
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,label+" routed/"+str(s.eid))
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint())); assert(geometry.restore(geometry.checkpoint())); count += 1
		w.free()
	for call in [10,11,12,13,14]: assert(seen.has(call),"speech coverage "+str(call))
	helper.free(); gun.free(); print("SQUAD_ORDERS passed states=",count); get_tree().quit()
