extends "res://tests/fixtures/vehicle-loss-world.gd"

class CombatBuilding extends Structure:
	func _ready() -> void:
		super(); set_process(false); set_physics_process(false)

class CombatDrone extends Drone:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

class ShotWorld extends FireWorld:
	var bullet_fx: Array = []
	func fx_event(event: Array) -> void:
		if event[0] == Fx.SHOT: bullet_fx.append(["shot",event[1],event[2],event[3],event[4],event[5]])
		elif event[0] == Fx.RICOCHET: bullet_fx.append(["ricochet",event[1],event[2]])

func _ready() -> void:
	run(false)

func blast_ledger_equal(expected: Array, actual: Array) -> bool:
	if expected.size() != actual.size(): return false
	var normalized := expected.duplicate(true)
	# Godot's power function can round blast damage one ulp from the pinned Rust math.
	for group in [0,1]:
		if expected[group].size() != actual[group].size(): return false
		for row in expected[group].size():
			var a: PackedFloat64Array = expected[group][row][4] if group == 0 else expected[group][row]
			var b: PackedFloat64Array = actual[group][row][4] if group == 0 else actual[group][row]
			if a.size() != b.size() or not is_finite(a[11]) or not is_finite(b[11]) or absf(a[11] - b[11]) > 1e-10: return false
			a[11] = b[11]
			if group == 0: normalized[group][row][4] = a
			else: normalized[group][row] = a
	return normalized == actual

func run(shoot: bool) -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var combat: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var soldier: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
	var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
	var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
	var fires: RefCounted = ClassDB.instantiate("FiresCore")
	var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
	var random := SimulationRandom.new()
	var compare := preload("res://tests/fixtures/battle-stats.gd").new()
	var infantry := preload("res://tests/fixtures/infantry-blast.gd").new()
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new()
	var actor_compare := preload("res://tests/fixtures/actors.gd").new()
	var seen := {}
	for trial in 64:
		var w := ShotWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
		w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
		if shoot and trial % 3 == 0: w.rules.upgrades = [{"optics":true},{"optics":true}]
		w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
		for pair in [[ledger,"BattleStatsCore"],[deferred,"DeferredEffectsCore"]]:
			var empty: RefCounted = ClassDB.instantiate(pair[1]); assert(pair[0].restore(empty.checkpoint()))
		for side in 2:
			var q := Squad.new(); q.world = w; q.sid = side + 1; q.team = side; q.owner = 7 + side; q.kind = "rifle_squad"; w.squads[q.sid] = q
		for id in range(1,13):
			var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = id % 2; s.owner_peer = 7 + s.team
			s.utype = "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]; s.sname = "Combat %d" % id
			s.position = Vector3((id % 4) * 3.1 - 4.2,0,(id / 4) * 2.3 - 3.7); s.posture = id % 3
			s.hp = 20.0 if trial % 5 == 0 else 100.0; s.times_downed = trial % 4; s.mag = 7; s.reserve = 23
			s.squad = w.squads[s.team + 1]; s.sid = s.squad.sid; s.squad.members.append(s)
			w.add_child(s); w._register(s)
		for index in 2:
			var v := Destructible.new(); v.world = w; v.srv = true; v.eid = 40 + index; v.team = index; v.owner_peer = 7 + index
			v.vkind = ["truck","tank","rhib","heli"][(trial + index) % 4]
			v.vdef = Defs.VEHICLES[v.vkind]; v.max_hp = v.vdef.hp; v.hp = v.max_hp
			v.position = Vector3(-3 + index * 7,0,-3); v.rotation.y = trial * 0.137
			w.add_child(v); w._register(v); v.on_spawned(); w.combat.dirty_collision(v.eid)
			if shoot: v.hp = 2.0 if trial % 3 == 0 else 40.0
			var passenger: Soldier = w.entities[index + 1]; passenger.riding = v; passenger.life = Soldier.Life.HIDDEN; v.passengers.append(passenger)
		var kinds := ["depot","fob","fob","town","house_wall","ammo_cache","tree","car","crates","wire","camo_net","tunnel","mg_nest","barracks"]
		for index in kinds.size():
			var st := CombatBuilding.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.skind = kinds[index]
			st.team = 0 if index < 4 or index > 10 else -1; st.owner_peer = 7 if st.team == 0 else 0
			st.position = [Vector3(-24,0,-20),Vector3(-10,0,0),Vector3(9,0,0),Vector3(24,0,20)][index] if index < 4 else Vector3((index % 4) * 2.9 - 3.7,0,(index / 4) * 2.1 - 3)
			st.yaw = (trial % 7) * 0.137; st.rotation.y = st.yaw; st.sname = "Combat base %d" % index
			st.completed_order = index; st.supply = 120.0; st.door_shut = index == 4; st.variant = 2 if index == 4 else trial % 2
			if index == 4: st.size = Vector3(7.3,2.3,1.0)
			w.add_child(st); w._register(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st); w.combat.dirty_collision(st.eid)
			if index > 0: st.hp = minf(st.hp,90.0 if trial % 2 else 500.0)
			if index == 0: w.rules.depots[0] = st
			if index == 3: w.rules.town_list.append(st)
		var dr := CombatDrone.new(); dr.world = w; dr.srv = true; dr.eid = 60; dr.team = 1; dr.position = Vector3(1,1,0); dr.operator = w.entities[5]
		w.add_child(dr); w._register(dr); dr.on_spawned()
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var types := PackedByteArray(); var blocks := []; var vehicles := []; var men := []; var buildings := []
		for e: Entity in w.entities.values():
			if e is Soldier:
				assert(soldier.load_state(InfantryState.capture(e))); types.append(0); blocks.append(soldier.checkpoint())
			elif e is Vehicle:
				assert(vehicle.load_state(VehicleState.capture(e))); types.append(2); blocks.append(vehicle.checkpoint())
				vehicles.append([e.eid,e.display_name(),e.base(),e.is_heli(),e.is_auto(),int(e.vdef.get("crew",-1)),float(e.vdef.get("cost",0)),false,false,e.weight(),e._hull_size(),int(e.vdef.armor),float(e._toss_class()[0]),e.hit_factor()])
			elif e is Drone:
				types.append(4); blocks.append(actor_compare.drone_bytes(e,actors))
			else:
				assert(structure.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure.checkpoint())
		for kind in ["rifleman","crewman","r_crewman"]:
			var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
			men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.man_value(w.entities[1]) if kind == "rifleman" else BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
		for kind in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
		assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
		assert(network.load_state(PackedInt64Array([100,0]),PackedInt64Array([103]),w.rules.fob_order,w.roads,w._painted_roads))
		w.rng.seed = 7317 + trial; random.seed = w.rng.seed
		var qs: Array[SquadStateCore] = []
		for q: Squad in w.squads.values():
			var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(qc.load_state(SquadState.capture(q))); qs.append(qc)
		var impacts := []
		var next: int = w.next_sid
		var initial: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
		assert(combat.gunfire_restore(initial.gunfire_checkpoint()))
		for step in (12 if shoot else 3):
			if shoot: w.time += 0.17
			elif step == 2: w.time += 1.6
			var config := [next,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
			var p: Vector3 = [Vector3.ZERO,Vector3(-10,0,0),Vector3(9,0,0),Vector3(3,2,0)][trial % 4]
			var source: Entity = w.entities[5] if step == 0 else null
			var data := {"radius":12.0,"fling":8.0,"size":[0.55,1.0,2.7,6.0][trial % 4],"at":120.0 if trial % 3 == 0 else 0.0,"top":trial % 2 == 0,"src":source,"by":8,"team":1}
			if trial % 5: data.dmg = 180.0 if step == 0 else 1200.0
			var input := [p,data.get("dmg"),data.radius,data.fling,data.size,data.at,0.3,data.top,null,1.0,1.0,InfantryState.entity_id(source),8,1]
			var result: Array
			if shoot:
				var shooter: Entity = w.entity([5,40,104][step % 3]); shooter = shooter if shooter else w.entity(5)
				var target: Entity = w.entity([6,3,40,41,60,104,105,0][(step + trial) % 8])
				var weapon: Dictionary = Defs.WEAPONS[["rifle","m2","chaingun","zu23","bushmaster","gmg"][(trial + step) % 6]]
				var muzzle := shooter.center_point() if step % 2 else Vector3(-15,1.3,-4)
				var aim := target.center_point() if target else Vector3(5,0,5)
				var accuracy := 8.0 if step % 3 == 0 else 0.7
				var values := PackedFloat64Array([weapon.acc,weapon.range,weapon.dmg,int(weapon.get("aa",false)),Cover.pen_class(weapon),0.08 if weapon.snd == "hmg" else 0.045 if weapon.snd == "mg" else 0.03,weapon.get("he",-1.0),int(weapon.get("airburst",false)),accuracy,int(w.rules.has_upgrade(shooter.team,"optics")),int(weapon.get("ap",false)),weapon.supp])
				result = combat.fire_bullet(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,[shooter.eid,InfantryState.entity_id(target),muzzle,aim,values,String(weapon.snd)],network,impacts)
				assert(result.size() == 5,"bullet result %d/%d" % [trial,step])
				w.bullet_fx.clear(); w.combat._fire_bullet_reference(shooter,muzzle,aim,target,weapon,accuracy)
				assert(result[4] == w.bullet_fx,"bullet effects %d/%d" % [trial,step])
				assert(combat.gunfire_reveals() == w.combat._reveal,"bullet reveal %d/%d" % [trial,step])
				assert(combat.gunfire_restore(combat.gunfire_checkpoint()))
			else:
				result = combat.explode(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input,network,impacts) if step < 2 else combat.flush_deferred(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,network,impacts)
			var label := "blast %d/%d" % [trial,step]
			assert(result.size() == (5 if shoot else 4),"combat result " + label)
			if not shoot:
				if step < 2: w.combat.explode(p,data)
				else: w._run_deferred_effects()
			w.combat._sync_collision()
			assert(w.rng.state == random.state,"explosion RNG " + label + ": %d / %d" % [w.rng.state,random.state])
			var identities := PackedInt64Array()
			for e: Entity in w.entities.values(): identities.append(e.eid); identities.append(0 if e is Soldier else 1 if e is Structure else 2 if e is Vehicle else 4)
			assert(actors.identities() == identities and actors.next_id() == w.next_eid,"explosion registry " + label)
			next = result[0]; impacts = result[3]; qs.clear()
			assert(w.next_sid == next and w.squads.size() == result[1].size(),"explosion squad births " + label)
			assert(impacts == w.recent_impacts,"explosion impacts " + label)
			for bytes: PackedByteArray in result[1]:
				var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(qc.restore(bytes)); qs.append(qc)
				assert(qc.values() == SquadState.capture(w.squads[qc.values()[0][0]]),"explosion squad " + label)
			for e: Entity in w.entities.values():
				if e is Soldier:
					infantry.check_blast_actor(e,actors,label + "/%d" % e.eid)
				elif e is Vehicle:
					assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"explosion vehicle " + label)
				elif e is Drone: actor_compare.compare_drone(e,actors,label)
				else:
					assert(structure.restore(actors.actor_state(e.eid))); assert(structure.values() == StructureState.capture(e),"explosion structure %s/%d" % [label,e.eid])
			assert(blast_ledger_equal(compare.ledger(w.battle),ledger.values()),"combat ledger " + label)
			if trial == 0 and step == 0:
				var wrong: Array = ledger.values(); var counters: PackedFloat64Array = wrong[1][0]
				counters[11] += 1e-8; wrong[1][0] = counters
				assert(not blast_ledger_equal(compare.ledger(w.battle),wrong),"ledger must reject changed damage")
				wrong = ledger.values(); counters = wrong[1][0]; counters[9] += 1; wrong[1][0] = counters
				assert(not blast_ledger_equal(compare.ledger(w.battle),wrong),"ledger must reject changed shot counts")
			assert(fires.values() == fire_values(w.fires),"explosion fires " + label)
			assert(network.values() == [PackedInt64Array([100,0]),PackedInt64Array([103]),w.rules.fob_order,w.roads,w._painted_roads],"explosion network " + label)
			if not shoot and step == 2: assert(deferred.take_rubble() == w._deferred_effects.take_rubble(),"explosion rubble " + label)
			var pending: Array = deferred.pending(); assert(pending.size() == w._deferred_effects._pending.size(),"explosion deferred " + label)
			for i in pending.size():
				var e: Array = w._deferred_effects._pending[i]; var d: Dictionary = e[3]
				assert(e[0] == pending[i][0] and e[1] == pending[i][1] and e[2] == pending[i][2][0][1],"explosion deadline " + label)
				assert(pending[i][2][0][2] == PackedFloat64Array([d.dmg,d.radius,d.fling,d.get("at",0.0),0.3,d.size,1.0]),"explosion delayed blast " + label)
			check_geometry(w,geometry,label)
			for key: String in result[2]: seen[key] = true
			for retained in [actors,geometry,units,ledger,deferred,visibility,fires,network]: assert(retained.restore(retained.checkpoint()))
			w.combat.finish_tick(); geometry.finish_tick(); check_geometry(w,geometry,label + " end")
		w.free()
	for key in (["penetration","through_hit","ricochet","vehicle_destroyed","drone_shot_down"] if shoot else ["vehicle_destroyed","drone_shot_down","door_kicked","cache_cook_off","at_hit"]): assert(seen.has(key),"unexercised combat " + key)
	compare.free(); infantry.free(); birth.free(); actor_compare.free()
	print("BULLET_WORLD passed states=" if shoot else "WORLD_COMBAT passed states=",checks)
	get_tree().quit()
