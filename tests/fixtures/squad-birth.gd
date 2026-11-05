extends "res://tests/fixtures/fires-native.gd"

class RecruitingWorld extends FireWorld:
	var spoken := []
	func say(e: Entity, text: String) -> void: spoken.append([e.eid,text])

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new()
	var compare := preload("res://tests/fixtures/battle-stats.gd").new()
	var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var men := []; var buildings := []
	for kind: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
		men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
	for kind: String in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
	var count := 0; var vehicle_kinds := []
	for kind: String in Defs.VEHICLES:
		if Defs.SQUADS.has(String(Defs.VEHICLES[kind].get("carry",""))): vehicle_kinds.append(kind)
	for trial in 8:
		for entry: String in (vehicle_kinds if trial >= 6 else Defs.SQUADS.keys()):
			var w := RecruitingWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0; w.next_eid = 1000; w.next_sid = 7 + trial * 19; add_child(w)
			var team := trial % 2; var owner := trial % 3 - 2
			if trial % 3 == 0: w.rules.upgrades[team].armor = true
			if trial % 4 == 0: w.rules.upgrades[team].grenades = true
			var pos := Vector3(-13.7,0.0,1.3); var dest: Variant = Vector3(21.3,0.0,-9.7) if trial % 3 == 1 else null
			if trial % 3 == 2: dest = pos + Vector3(0.3,0,0.2)
			var transport: Vehicle; var key := entry; var vehicles := []
			if trial >= 6:
				transport = w.spawn("vehicle",{"vkind":entry,"team":team,"owner":owner,"pos":pos})
				key = String(transport.vdef.carry)
				vehicles.append([transport.eid,transport.display_name(),transport.base(),transport.is_heli(),transport.is_auto(),int(transport.vdef.get("crew",-1)),float(transport.vdef.get("cost",0)),w.rules.has_upgrade(team,"armor"),w.rules.has_upgrade(team,"grenades"),transport.weight(),transport._hull_size()])
			if trial % 2 == 1:
				w.spawn("structure",{"skind":"concrete_wall","team":team,"owner":owner,"pos":pos + Vector3(-1.4,0,0),"size":Vector3(3,2,3)})
			w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
			var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
			var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
			var visibility: RefCounted = ClassDB.instantiate("VisibilityCore"); var fires: RefCounted = ClassDB.instantiate("FiresCore")
			var qc: RefCounted = ClassDB.instantiate("SquadStateCore"); var random := SimulationRandom.new()
			var types := PackedByteArray(); var blocks := []
			for e: Entity in w.entities.values():
				var state: RefCounted = ClassDB.instantiate("VehicleStateCore" if e is Vehicle else "StructureStateCore")
				assert(state.load_state(VehicleState.capture(e) if e is Vehicle else StructureState.capture(e))); types.append(2 if e is Vehicle else 1); blocks.append(state.checkpoint())
			assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
			assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
			# The existing vehicle is already in the after-action ledger before passengers are recruited.
			if transport and not transport.is_auto() and transport.vkind != "truck": assert(ledger.register_unit("v%d" % transport.eid,transport.display_name(),"vehicle",team,owner,w.time,1))
			w.rng.seed = 3917 + count; random.seed = w.rng.seed
			var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
			var loads := []
			for kind: String in Defs.SQUADS[key].members: loads.append(birth.loadout(kind))
			var input := [key,String(Defs.SQUADS[key].name),loads,w.rules.has_upgrade(team,"armor"),w.rules.has_upgrade(team,"grenades"),team,owner,pos,dest,transport.eid if transport else 0]
			var qs: Array[SquadStateCore] = []
			var result: Array = loss.recruit(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input)
			assert(result.size() == 4,"recruit result %s/%d" % [entry,trial])
			var q: Squad
			if transport: transport.embark_new_squad(); q = w.squads.values().back()
			else: q = w.rules.spawn_squad(key,team,owner,pos,Vector3.INF if dest == null else dest)
			var label := "birth %s/%d" % [entry,trial]
			assert(w.next_sid == result[0] and q.sid == result[3][0]); assert(w.next_eid == actors.next_id())
			assert(w.rng.state == random.state,"random " + label)
			assert(qc.restore(result[1][0])); movement.compare_squad(q,qc,{},label)
			var said := []
			for event: Array in result[3][1]:
				if event[0] == 0: said.append([event[1],movement.speech(q,event[2],event[3])])
			assert(said == w.spoken,"speech " + label)
			for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + "/%d" % s.eid)
			if transport:
				var state: RefCounted = ClassDB.instantiate("VehicleStateCore"); assert(state.restore(actors.actor_state(transport.eid)))
				assert(state.values() == VehicleState.capture(transport),"passengers " + label)
			compare.compare_ledger(w.battle,ledger,label); check_geometry(w,geometry,label)
			w.nav.process_paths(50); assert(geometry.process_paths(actors,50,w.time,random._backend))
			for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + " routed/%d" % s.eid)
			assert(w.rng.state == random.state); assert(geometry.inspect()[1] == nav_save(w.nav))
			for retained in [actors,geometry,units,ledger,deferred,visibility,fires]: assert(retained.restore(retained.checkpoint()))
			w.free(); count += 1
	birth.free(); compare.free(); movement.free()
	print("SQUAD_BIRTH passed states=",count); get_tree().quit()
