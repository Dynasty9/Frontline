extends "res://tests/fixtures/structure-production.gd"

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/squad-movement.gd").new(); var birth := preload("res://tests/fixtures/vehicle-loss.gd").new()
	var boat_helper := preload("res://tests/fixtures/boat-navigation.gd").new(); var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var kinds := {}; var count := 0
	for key: String in Defs.VEHICLES:
		var d: Dictionary = Defs.VEHICLES[key]; var signature := [String(d.get("base","tank")),bool(d.get("auto",false))]
		if not kinds.has(signature): kinds[signature] = key
	for trial in 4:
		for key: String in kinds.values():
			var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}; w.time = 100.0; w.next_eid = 100
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w); w.battle = BattleStats.new(w); add_child(w)
			w.water.coast = {"x":16.0,"s":0.0}; w.water.paint_kinds(); w.nav.build_boat_grid(w.water); boat_helper.reference_grid(w)
			w.spawn("structure",{"skind":"hesco","pos":Vector3(-10,0,4),"size":Vector3(14,2,1),"yaw":0.0})
			var v := Truck.new(); v.world = w; v.srv = true; v.eid = 20; v.team = trial % 2; v.owner_peer = -1-v.team if trial == 0 else 7
			v.vkind = key; v.vdef = Defs.VEHICLES[key]; v.hp = v.vdef.hp; v.max_hp = v.hp
			v.position = Vector3(35 if v.is_boat() else -30,5 if v.is_heli() else 0,-20); v.brain_state = "withdraw" if trial < 2 else ""; v.lift_phase = [3,4,7,0][trial]
			w.add_child(v); w._register(v)
			var target := Trooper.new(); target.world = w; target.srv = true; target.eid = 1; target.team = 1-v.team
			target.utype = "rifleman"; target.udef = Defs.UNITS.rifleman; target.wdef = Defs.WEAPONS[target.udef.weapon]; target.position = Vector3(-35 if v.is_boat() else 35,0,20)
			w.add_child(target); w._register(target); w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); helper.import_actors(w,actors)
			var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore"); var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
			var boats: RefCounted = ClassDB.instantiate("BoatNavigationCore"); var state: RefCounted = ClassDB.instantiate("VehicleStateCore")
			var fires: RefCounted = ClassDB.instantiate("FiresCore"); var battle: RefCounted = ClassDB.instantiate("BattleStatsCore")
			var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore"); var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
			assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0))); assert(boats.configure(w.terrain._native,w.water.deck)); assert(fires.configure(128,false))
			var random := SimulationRandom.new(); random.seed = 1437+count; w.rng.seed = random.seed; var qs: Array[SquadStateCore] = []
			var vehicles := [[v.eid,v.display_name(),v.base(),v.is_heli(),v.is_auto(),int(v.vdef.get("crew",-1)),float(v.vdef.get("cost",0)),false,false,v.weight(),v._hull_size()]]
			var men := []
			for unit: String in ["rifleman","crewman","r_crewman"]:
				var ud: Dictionary = Defs.UNITS[unit]; var wd: Dictionary = Defs.WEAPONS[ud.weapon]
				men.append([unit,false,int(wd.ammo),BattleStats.MAN_VALUE,float(wd.range),String(ud.name)])
			var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,[]]
			for step in 8:
				var op := step % 4; var p := Vector3(45 if v.is_boat() else -18,0,24 if step < 4 else -8)
				if v.is_heli() and step < 2: p = Vector3(-10,0,4)
				var input := [20,op,null if op == 3 else 1 if op == 2 else p]
				var result: Array = loss.command_vehicle(actors,geometry,units,qs,fires,battle,deferred,visibility,random._backend,config,input,boats)
				match op:
					0: v.order_move(p)
					1: v.order_assault(p)
					2: v.order_attack(target)
					3: v.order_stop()
				var label := "%s/%d/%d" % [key,trial,step]; assert(result.size() == 3,"result "+label)
				assert(state.restore(actors.actor_state(20))); assert(state.values() == VehicleState.capture(v),"vehicle "+label)
				assert(geometry.inspect()[1] == nav_save(w.nav),"routes "+label); assert(w.rng.state == random.state,"random "+label)
				w.nav.process_paths(2); assert(geometry.process_paths(actors,2,w.time,random._backend))
				assert(state.restore(actors.actor_state(20))); assert(state.values() == VehicleState.capture(v),"routed vehicle "+label)
				assert(geometry.inspect()[1] == nav_save(w.nav),"completed routes "+label)
				assert(actors.restore(actors.checkpoint())); assert(geometry.restore(geometry.checkpoint())); assert(boats.restore(boats.checkpoint())); count += 1
			w.free()
	helper.free(); birth.free(); boat_helper.free(); print("VEHICLE_ORDERS_WORLD passed states=",count," profiles=",kinds.size()); get_tree().quit()
