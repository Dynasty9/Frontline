extends "res://tests/fixtures/structure-birth.gd"

class BornVehicle extends Vehicle:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var count := 0
	for trial in 4:
		var w := SpawnWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.nav.finalize()
		w.combat = Combat.new(w); w.combat.enable_native_collision(); add_child(w)
		var core: RefCounted = ClassDB.instantiate("WorldGeometryCore"); var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var state: RefCounted = ClassDB.instantiate("VehicleStateCore")
		assert(core.restore(world_save(w)))
		var index := 0
		for kind: String in Defs.VEHICLES:
			var def: Dictionary = Defs.VEHICLES[kind]; var v := BornVehicle.new(); v.world = w; v.srv = true; v.eid = index+1
			var yaw_value := trial*0.317-1.3
			v.apply_props({"vkind":kind,"team":trial % 3-1,"owner":trial-2,"pos":Vector3(index % 8*7.13-27,trial*0.2,index / 8*2.19-17),"yaw":yaw_value,"max_hp":41.0})
			var spawn := [v.team,v.owner_peer,v.position,yaw_value]
			var profile := [kind,String(def.get("base","tank")),float(def.hp),def.get("size",Vector3(2.3,2.6,6.0)),int(def.get("atgm",[0,0.0])[0]),int(def.get("sam",[0,0.0])[0]),bool(def.get("tracked",false))]
			assert(core.spawn_vehicle(actors,spawn,profile) == v.eid,"vehicle birth "+kind)
			w._register(v); w.add_child(v); v.on_spawned(); w.combat.dirty_collision(v.eid); w.combat._sync_collision()
			assert(state.restore(actors.actor_state(v.eid)))
			var expected := VehicleState.capture(v); var actual: Array = state.values()
			for group in expected.size(): assert(expected[group] == actual[group],"vehicle birth %s/%d group %d: %s / %s" % [kind,trial,group,expected[group],actual[group]])
			if index % 13 == 0: check_geometry(w,core,"vehicle birth %s/%d" % [kind,trial]); assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint()))
			index += 1; count += 1
		check_geometry(w,core,"vehicle birth end %d" % trial); w.free()
	print("VEHICLE_BIRTH passed states=",count); get_tree().quit()
