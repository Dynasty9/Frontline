extends "res://tests/fixtures/fires-native.gd"

class Destructible extends Vehicle:
	func _ready() -> void:
		super(); set_process(false); set_physics_process(false)

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
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
	var random := SimulationRandom.new()
	var compare := preload("res://tests/fixtures/battle-stats.gd").new()
	var infantry := preload("res://tests/fixtures/infantry-update.gd").new()
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new()
	var kinds := Defs.VEHICLES.keys(); var seen := {}
	for trial in 192:
		var w := FireWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
		w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
		w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
		var empty: RefCounted = ClassDB.instantiate("BattleStatsCore"); assert(ledger.restore(empty.checkpoint()))
		for team in 2:
			if trial % 3 == 0: w.rules.upgrades[team].armor = true
			if trial % 4 == 0: w.rules.upgrades[team].grenades = true
		var v := Destructible.new(); v.world = w; v.srv = true; v.eid = 20; v.team = trial % 2; v.owner_peer = 7
		v.vkind = kinds[trial % kinds.size()]; v.vdef = Defs.VEHICLES[v.vkind]; v.max_hp = v.vdef.hp; v.hp = v.max_hp
		v.position = Vector3(1.3,0,-2.7); v.rotation.y = trial * 0.137
		v._last_blast = [v.position + Vector3(-1.3,0,0.7),2.7,w.time - [0.0,0.599,0.601][trial % 3]] if trial % 4 else []
		w.add_child(v); w._register(v); v.on_spawned(); w.combat.dirty_collision(v.eid)
		var q := Squad.new(); q.world = w; q.sid = 1; q.team = v.team; q.owner = 7; q.kind = "rifle_squad"; w.squads[1] = q
		for id in range(1,6):
			var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = v.team if id < 5 else 1 - v.team; s.owner_peer = 7 if id < 5 else 8
			s.utype = "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]; s.sname = "Passenger %d" % id
			s.position = v.position + Vector3(id,0,0); s.life = Soldier.Life.HIDDEN if id < 4 else Soldier.Life.ALIVE
			s.hp = 20.0 if trial % 5 == 0 else 100.0; s.times_downed = trial % 4; s.mag = 7; s.reserve = 23
			if id < 5: s.squad = q; s.sid = q.sid; q.members.append(s)
			if id < 4: s.riding = v; v.passengers.append(s)
			w.add_child(s); w._register(s)
		if trial % 3 != 1:
			var f := Wall.new(); f.world = w; f.srv = true; f.eid = 30; f.skind = "fob"; f.team = v.team; f.owner_peer = 7
			f.position = Vector3(-12,0,2) if trial % 3 == 0 else Vector3(25,0,20); f.sname = "Home"; f.supply = 100.0
			w.add_child(f); w._register(f); f.on_spawned(); w._shash_add(f); w.terrain.structure_changed(f)
			if v.base() == "supply": v.dest_fob = f; f.truck = v; v.cargo = 71
		if v.is_heli() and trial % 2 == 0:
			var cargo := Destructible.new(); cargo.world = w; cargo.srv = true; cargo.eid = 21; cargo.team = v.team; cargo.owner_peer = 7
			cargo.vkind = "truck"; cargo.vdef = Defs.VEHICLES.truck; cargo.max_hp = cargo.vdef.hp; cargo.hp = 20.0
			cargo.position = Vector3(1,27,-2); cargo.slung_by = v; v.sling_cargo = cargo; v.position.y = 30.0
			w.add_child(cargo); w._register(cargo); cargo.on_spawned(); cargo.hp = 20.0; w.combat.dirty_collision(cargo.eid)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var types := PackedByteArray(); var blocks := []; var vehicles := []; var men := []; var buildings := []
		for e: Entity in w.entities.values():
			if e is Soldier:
				assert(soldier.load_state(InfantryState.capture(e))); types.append(0); blocks.append(soldier.checkpoint())
			elif e is Vehicle:
				assert(vehicle.load_state(VehicleState.capture(e))); types.append(2); blocks.append(vehicle.checkpoint())
				vehicles.append([e.eid,e.display_name(),e.base(),e.is_heli(),e.is_auto(),int(e.vdef.get("crew",-1)),float(e.vdef.get("cost",0)),w.rules.has_upgrade(e.team,"armor"),w.rules.has_upgrade(e.team,"grenades"),e.weight(),e._hull_size()])
			else:
				assert(structure.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure.checkpoint())
		for kind in ["rifleman","crewman","r_crewman"]:
			var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
			men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.man_value(w.entities[1]) if kind == "rifleman" else BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
		for kind in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
		var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(qc.load_state(SquadState.capture(q))); var qs: Array[SquadStateCore] = [qc]
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
		assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
		w.rng.seed = 3917 + trial; random.seed = w.rng.seed
		var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
		var amount: float = v.max_hp * [1.1,1.35,1.350001,1.8][trial % 4]
		var result: Array = loss.damage(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,20,amount,5)
		assert(result.size() == 3,"destruction result %d" % trial)
		v.take_damage(amount,w.entities[5]); w.combat._sync_collision()
		var label := "loss %d/%s" % [trial,v.vkind]
		assert(w.rng.state == random.state,"RNG " + label)
		var identities := PackedInt64Array()
		for e: Entity in w.entities.values(): identities.append(e.eid); identities.append(0 if e is Soldier else 1 if e is Structure else 2)
		assert(actors.identities() == identities and actors.next_id() == w.next_eid,"entity registry " + label)
		assert(w.next_sid == result[0] and w.squads.size() == result[1].size(),"squad births " + label)
		for bytes: PackedByteArray in result[1]:
			var core: RefCounted = ClassDB.instantiate("SquadStateCore"); assert(core.restore(bytes))
			assert(core.values() == SquadState.capture(w.squads[core.values()[0][0]]),"squad " + label)
		for e: Entity in w.entities.values():
			if e is Soldier:
				assert(soldier.restore(actors.actor_state(e.eid))); infantry.check_state(e,soldier,label + "/%d" % e.eid)
			elif e is Vehicle:
				assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"vehicle " + label)
			else:
				assert(structure.restore(actors.actor_state(e.eid))); assert(structure.values() == StructureState.capture(e),"structure " + label)
		compare.compare_ledger(w.battle,ledger,label)
		assert(fires.values() == fire_values(w.fires),"fires " + label)
		check_geometry(w,geometry,label)
		var counted := {}
		for key: String in result[2]: counted[key] = int(counted.get(key,0)) + 1; seen[key] = true
		for key: String in counted: assert(w.stats.get(key,0) == counted[key],"stat " + key)
		for retained in [actors,geometry,units,ledger,deferred,visibility,fires]: assert(retained.restore(retained.checkpoint()))
		w.combat.finish_tick(); geometry.finish_tick(); check_geometry(w,geometry,label + " end")
		w.free()
	for key in ["vehicle_destroyed","boat_sunk","crew_bailout","crew_lost","crew_home","truck_lost","sling_dropped"]: assert(seen.has(key),"unexercised " + key)
	compare.free(); infantry.free(); birth.free()
	print("VEHICLE_LOSS_WORLD passed states=",checks)
	get_tree().quit()
