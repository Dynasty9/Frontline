extends "res://tests/fixtures/squad-state.gd"

class Plan extends RefCounted:
	var done := false

class Truck extends Vehicle:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

func import_actors(w: World, actors: RefCounted) -> Array:
	var kinds := PackedByteArray(); var blocks := []; var profiles := []
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	for e: Entity in w.entities.values():
		if e is Soldier:
			kinds.append(0); blocks.append(soldier_bytes(e))
			profiles.append([e.eid,e.is_bearer(),float(e.wdef.get("range",60.0)) if not e.wdef.is_empty() else -1.0,false,false])
		elif e is Vehicle:
			kinds.append(2); assert(vehicle.load_state(VehicleState.capture(e))); blocks.append(vehicle.checkpoint())
			profiles.append([e.eid,false,-1.0,e.is_auto(),false])
		else:
			kinds.append(1); assert(structure.load_state(StructureState.capture(e))); blocks.append(structure.checkpoint())
			profiles.append([e.eid,false,-1.0,false,e.is_player_building()])
	assert(actors.load_state(1000,kinds,blocks)); return profiles

func speech(q: Squad, call: int, variant: int) -> String:
	match call:
		0: return (["Sarge is down, I've got command!", "On me! I'm taking the squad!", "I've got it, form on me!"] if q.team == 0 else ["I lead now! Follow me!", "Brothers, on me!", "I'm in command!"])[variant]
		1: return (["Moving!", "Move up!", "On me!", "Let's go!", "Copy, moving."] if q.owner >= 0 else ["Copy, moving to %s." % Defs.grid_ref(q.order_pos), "Roger, %s. On me!" % Defs.grid_ref(q.order_pos), "Moving to %s." % Defs.grid_ref(q.order_pos)])[variant]
		2: return (["Bounding overwatch! Alpha moving, Bravo cover!", "By teams - bound! Watch your sectors!", "Alpha go, Bravo cover!", "Leapfrog it up, one team covering!"] if q.team == 0 else ["Half of you cover, half move! Go!", "Move in pairs, cover each other!", "You go, we cover! Then us!"])[variant]
		3: return ["Moving!", "Going!", "On the move!", "Bounding!"][variant]
		4: return ["Set!", "Set! Move up!", "In position, go!", "Covering!"][variant]
		5: return (["Recon by fire!", "Putting rounds in that treeline!", "Spraying it - see if they bite!", "Rounds into that house!"] if q.team == 0 else ["Shoot it up, see who's there!", "Fire into it!"])[variant]
	assert(false); return ""

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}
	checks = 0
	for trial in 96:
		var w := make_world(false); w.time = 100.0
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision()
		w.town_rect = Rect2(-50,-20,100,40) if trial % 2 else Rect2()
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial % 2; q.owner = trial % 3 - 1
		q.kind = "crew" if trial % 7 == 0 else "rifle_squad"; q.order_n = trial
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var qs: Array[SquadStateCore] = [core]
		var plan := Plan.new(); var ambush := Plan.new(); var plans := {plan:17,ambush:19}
		for id in range(1,11):
			var s := make_soldier(w,id,q.team if id <= 8 else 1 - q.team); w.soldiers.append(s)
			s.position = Vector3(-30.3 + id * 0.71,0.0,id * 1.37 - 3.7) if id <= 8 else Vector3(30.1,0,4.7 + id)
			s.utype = "mg_gunner" if id % 4 == 0 else "medic" if id == 6 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.say_cd = 1.7 if trial % 3 == 0 else 0.0; s.vis_mask = 1 << q.team if trial % 4 == 0 else 0
			if id <= 6: q.add(s)
		q.leader = w.entities[1]; q.alert_t = 99.0 if trial % 3 == 0 else -99.0
		q.known = {9:{"e":w.entities[9],"pos":Vector3(25.0,0,8.0),"t":90.0}}
		q.heard = [[Vector3(25.0,0,20.0),95.0]] if trial % 5 else []
		if trial % 6 == 0: q.members.reverse()
		if trial % 8 == 0: w.entities[1].life = Soldier.Life.DOWNED
		if trial % 5 == 0:
			w.entities[3].task = "rescue"; w.entities[3].task_ent = w.entities[7]; w.entities[7].dragged_by = w.entities[3]; w.entities[7].rescue_claimed = w.entities[3]
			w.entities[4].task = "breach"; w.entities[4].task_phase = 0; q.breach_by = w.entities[4]
			w.entities[5].task = "breach"; w.entities[5].task_phase = 2
		for index in 3:
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.team = 1 - q.team
			st.skind = ["hesco","house_wall","fob"][index]; st.size = Vector3(10,2,1); st.position = Vector3(6.7 + index * 10.13,0,-4.1)
			st.vis_mask = 1 << q.team if trial % 5 == 0 else 0; st.yaw = trial % 4 * 0.317; st.rotation.y = st.yaw
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
		if trial % 11 == 0:
			w.entities[6].task = "man"; w.entities[6].mounted = w.entities[100]; w.entities[6].base_y = 3.0
		var v := Truck.new(); v.world = w; v.srv = true; v.eid = 110; v.team = 1 - q.team; v.vkind = "truck"; v.vdef = Defs.VEHICLES.truck.duplicate()
		v.vdef.auto = trial % 2 == 0; v.vis_mask = 1 << q.team; v.position = Vector3(30,0,35); w.add_child(v); w._register(v)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		w.rng.seed = 1937 + trial; rng.seed = w.rng.seed
		for step in 24:
			w.time = 100.0 + step * 3.7
			if step % 4 == 3:
				for s: Soldier in q.members:
					s.position.x += 2.7; s._last_dir = Vector3(0.7,0,0.3)
			if step == 13 and trial % 4 == 0 and q.leader: q.leader.life = Soldier.Life.DOWNED
			if step == 19 and trial % 4 == 1 and q.leader:
				q.leader.position = q.final_slots.get(q.leader.eid,q.order_pos)
			if step % 8 == 0:
				q.plan = plan; q.ambush_plan = ambush; ambush.done = false; q.then_defend = [Vector3.ONE,Vector3.RIGHT]
				q.shown_order = "contact"; q.ambush = true
				for s: Soldier in q.members: s.detached = true
			var profiles := import_actors(w,actors)
			assert(core.load_state(SquadState.capture(q,plans)))
			w.spoken.clear(); w.stats.clear()
			var op := 0 if step % 8 == 0 else 1 if q.travel else 2
			var args := []
			if op == 0:
				var dest := Vector3([30.7,4.3,-15.7,62.5][(trial + step / 8) % 4],0,step - 8.3)
				var face := Vector3.ZERO if trial % 3 else Vector3(0.7,0,-0.3)
				var mode: int = trial / 3 % 3; var tactical := trial % 9 != 0
				args = [dest,face,mode,tactical]; q.order_move(dest,face,mode,tactical)
			elif op == 1: q._follow_tick()
			else: Tactics.overwatch_tick(q)
			var result: Array = movement.apply(actors,geometry,units,qs,rng._backend,profiles,w.time,w.town_rect,7,op,args)
			assert(result.size() == 1,"movement result %d/%d" % [trial,step])
			var said := []; var stats := {}
			for e: Array in result[0]:
				match int(e[0]):
					0: said.append([e[1],speech(q,e[2],e[3])])
					1: assert(e[1] == 19 and ambush.done)
					2: stats[e[1]] = stats.get(e[1],0) + 1; seen[e[1]] = true
			assert(said == w.spoken,"movement speech %d/%d: %s / %s" % [trial,step,said,w.spoken])
			assert(stats == w.stats,"movement stats %d/%d: %s / %s" % [trial,step,stats,w.stats])
			compare_squad(q,core,plans,"movement %d/%d" % [trial,step])
			for s: Soldier in w.soldiers: compare_actor(s,actors,"movement actor %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state,"movement random %d/%d" % [trial,step])
			assert(geometry.inspect()[1] == helper.nav_save(w.nav),"movement queue %d/%d" % [trial,step])
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,"movement routed %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state)
			assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			if q.travel: seen.travel = true
			if q.technique == "bound": seen.bound = true
			if step % 7 == 6:
				assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint())); assert(geometry.restore(geometry.checkpoint()))
			checks += 1
		w.free()
	for key in ["travel","bound","bounding","recon_by_fire","leader_succession"]: assert(seen.has(key),"movement coverage " + key)
	helper.free()
	print("SQUAD_MOVEMENT passed states=",checks," coverage=",seen)
	get_tree().quit()
