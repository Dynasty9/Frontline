extends "res://tests/fixtures/attack-plan.gd"

func brain_speech(q: Squad, e: Array) -> String:
	var variant: int = e[3]
	match int(e[2]):
		0: return "Fall back! Fall back!"
		1: return ["Run! Get out of here!", "We can't hold! Go, go!", "Leave it! Run!", "Fall back! Fall back!"][variant]
		2: return ["Alright... alright. On me, form up!", "Get a grip! Form on me!", "Enough running. We hold here."][variant]
		3: return ["Incoming! Out of the impact area, move!", "They've got us zeroed! Move, move!", "Arty! Get out of here, go!", "Shells! Move it, move it!"][variant]
		4: return ["It's lifted. Back to the line!", "Back to your positions!"][variant]
		5: return ["Break contact! Smoke out, fall back by teams!", "Pull back! Bounding back, go!", "Too many of them! Fall back, covering fire!"][variant]
		6: return ["We're clear! Count off, check your ammo!", "Hold here! Reload, watch your front!", "Alright, we're out. Get your breath."][variant]
		7: return (["Near ambush! Assault through! Go, go, go!", "Ambush! Into them, move!", "Get out of the kill zone - assault!"] if q.team == 0 else ["Ambush! At them!", "Charge them! Go!"])[variant]
		8:
			var s: Soldier = q.world.entity(int(e[1])); var target: Vector3 = e[4]
			var distance := maxi(25,int(round(Defs.flat(target - s.position).length() / 25.0) * 25.0)); var dirn := Defs.compass(s.position,target)
			return ["Contact! %s, %d metres!" % [dirn.capitalize(),distance], "Contact %s! %d metres, return fire!" % [dirn,distance], "Enemy %s, %d metres! Get down!" % [dirn,distance]][variant]
		9: return (["FIRE!", "Now! Open fire!", "Hit them!", "Light them up!"] if q.team == 0 else ["NOW! Fire!", "Kill them!", "Fire, fire!"])[variant]
		10: return ["Ammo! Throw me a mag!", "I'm low! Mags!", "Anyone got a mag?"][variant]
		11: return ["Here, catch!", "Mag! Make it count!", "Take these."][variant]
		12: return ["Reloading!", "Changing mag!", "Cover me, reloading!"][variant]
		13: return ["Clearing that house!", "I'll take the door - on me!", "Stack up, we clear it!", "Checking the building!"][variant]
	assert(false); return ""

func brain_message(q: Squad, e: Array) -> Array:
	var suffix: String = [" is routing!", " has rallied.", " is moving out of the shellfire.", " is breaking contact.", " ambushed - assaulting through!"][int(e[2])]
	return [q.team,"alert" if int(e[2]) in [0,4] else "info",q.display_name() + suffix,e[3]]

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 64:
		var w := AttackWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; add_child(w)
		w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.rules = Rules.new(w); w.combat = Combat.new(w); w.combat.enable_native_collision()
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial / 16 % 2; q.owner = trial / 16 - 1; q.kind = "rifle_squad"; q.order_n = trial
		q.morale = 70.0; q.order_pos = Vector3(30.0,0,5.0); w.squads[7] = q
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var cores: Array[SquadStateCore] = [core]
		var plans := {}; var saved: Array[PackedByteArray] = []
		for id in range(1,9):
			var s := make_soldier(w,id,q.team if id <= 6 else 1-q.team); w.soldiers.append(s)
			s.position = Vector3(-28.1 + id * 0.71,0,-3.7 + id * 1.37) if id <= 6 else Vector3(30.1,0,4.7+id)
			s.utype = "mg_gunner" if id == 4 else "medic" if id == 6 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.smokes = 1; s.frags = 2; s.mag = 30; s.reserve = int(s.wdef.ammo) - 30; s.say_cd = 1.7 if trial % 3 else 0.0
			if id <= 6: q.add(s)
		q.leader = w.entities[1]; q.leader.mag = 0; q.leader.reserve = 0; q.leader.out_said = true
		q.known = {7:{"e":w.entities[7],"pos":w.entities[7].position,"t":100.0}}
		q.ambush = trial % 5 == 0
		for m: Soldier in q.members: m.target = w.entities[7]
		var scenario := trial % 16
		match scenario:
			0,1: q.morale = 5.0
			2: q.drill = "rout"; q.morale = 46.0
			3:
				q.impacts = [[Vector3(-28,0,0),99.0],[Vector3(-27,0,0),98.0],[Vector3.ZERO,60.0]]
				if trial >= 32:
					for s: Soldier in q.members: s._gy = -0.7
			4:
				q.drill = "displace"; q.drill_t = 50.0; q.drill_pos = Vector3(-10,0,30)
				q.pre_order = ["defend",Vector3(-20,0,20),Vector3.RIGHT,1]; q.known.clear()
			5:
				q.morale = 25.0
			6,7:
				q.drill = "withdraw"; q.drill_t = 99.0 if scenario == 6 else -50.0; q.order = "withdraw"
			8,9:
				q.order = "move"
				if scenario == 9:
					w.entities[7].position = Vector3(-10,0,0); q.known[7].pos = w.entities[7].position
			10,11:
				q.drill = "contact"; q.drill_t = 50.0; q.halt_dest = Vector3(30,0,-10); q.halt_face = Vector3.RIGHT
				q.halt_then = [Vector3(30,0,-10),Vector3.RIGHT]
				if scenario == 10: q.known.clear()
			12,13,14,15:
				q.order = "defend"; q.order_pos = Vector3.ZERO; q.alert_t = 100.0; q.known.clear()
				if scenario == 14:
					for s: Soldier in q.members: s.detached = true
				if scenario == 15:
					var plan := AttackPlan.new(); plan.world = w; plan.team = q.team; plan.support_set = true; plan.phase = "assault"
					plan.support = [{"sq":q,"team":0}]; plan.assault = [{"sq":q,"team":1}]
					q.plan = plan; plans[plan] = 17; saved.append(plan_bytes(plan))
				for index in 2:
					var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.team = -1
					st.skind = "floor" if index == 0 else "house_wall"; st.variant = 0 if index == 0 else 2
					st.size = Vector3(10,0.1,10) if index == 0 else Vector3(2,3,0.2); st.position = Vector3.ZERO if index == 0 else Vector3(0,0,-5)
					w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
				if scenario == 13: w.entities[3].position = Vector3.ZERO
		if scenario in [1,2] or trial >= 48:
			var f := Structure.new(); f.world = w; f.srv = true; f.eid = 102; f.team = q.team; f.skind = "fob"; f.position = Vector3(-45,0,-20)
			w._register(f); w.add_child(f); f.on_spawned(); w._shash_add(f); w.terrain.structure_changed(f)
		if trial >= 32:
			var v := Truck.new(); v.world = w; v.srv = true; v.eid = 110; v.team = q.team if trial % 2 else 1-q.team
			v.vkind = "tank"; v.vdef = Defs.VEHICLES.tank; v.vis_mask = 1 << q.team; v.position = Vector3(-5,0,-10); w.add_child(v); w._register(v)
		if trial >= 48:
			for s: Soldier in q.members: s.suppression = 40.0; s.at_cover = s.eid % 2 == 0; s.cover_mat = Cover.HARD
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		w.rng.seed = 5317 + trial; rng.seed = w.rng.seed
		for step in 6:
			w.time = 100.0 + step * 8.1
			var profiles := import_actors(w,actors); assert(core.load_state(SquadState.capture(q,plans)))
			var extra := []
			for e: Entity in w.entities.values():
				if e is Soldier: extra.append([e.eid,int(e.wdef.get("ammo",-1)),int(e.cur_weapon().get("mag",30)),float(e.cur_weapon().get("reload",2.0)),0])
				elif e is Vehicle: extra.append([e.eid,-1,0,0.0,int(e.vdef.get("armor",0))])
			for op in range(12,16):
				w.spoken.clear(); w.messages.clear(); w.stats.clear()
				match op:
					12: SquadBrain.morale_tick(q,0.5)
					13: SquadBrain.think(q)
					14: SquadBrain.ambush_tick(q)
					15: SquadBrain.share_ammo(q)
				var result: Array = movement.apply(actors,geometry,units,cores,rng._backend,profiles,w.time,w.town_rect,7,op,[0.5,extra,saved,w.recent_impacts])
				assert(result.size() == 2,"brain result %d/%d/%d" % [trial,step,op])
				var said := []; var stats := {}; var messages := []
				for e: Array in result[0]:
					match int(e[0]):
						0: said.append([e[1],speech(q,e[2],e[3])])
						2: stats[e[1]] = stats.get(e[1],0) + 1; seen[e[1]] = true
						7: said.append([e[1],brain_speech(q,e)])
						8: messages.append(brain_message(q,e))
						_: assert(false,"unknown squad event " + str(e))
				var label := "brain %d/%d/%d" % [trial,step,op]
				assert(said == w.spoken,label + " speech: " + str([said,w.spoken])); assert(stats == w.stats,label + " stats: " + str([stats,w.stats])); assert(messages == w.messages,label + " messages: " + str([messages,w.messages]))
				compare_squad(q,core,plans,label)
				for s: Soldier in w.soldiers: compare_actor(s,actors,label + "/" + str(s.eid))
				assert(w.rng.state == rng.state,label + " random")
				assert(geometry.inspect()[1] == helper.nav_save(w.nav),label + " queue")
				checks += 1
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,"brain route %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint())); assert(geometry.restore(geometry.checkpoint()))
		for p: AttackPlan in plans:
			p.support.clear(); p.assault.clear()
		q.plan = null; plans.clear(); w.free()
	for key in ["squad_rout","squad_rally","displace","break_contact","withdraw_done","react_to_contact","near_ambush_assault","contact_resume","ambush","ammo_shared","clear_house"]: assert(seen.has(key),"brain coverage " + key)
	helper.free(); print("SQUAD_BRAIN passed states=",checks," coverage=",seen); get_tree().quit()
