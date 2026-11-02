extends "res://tests/fixtures/fires-native.gd"

class CameraDrone extends Drone:
	func _ready() -> void: set_process(false); set_physics_process(false)

func fog_values(w: World) -> Array:
	var marks := []; var seen := []; var drones := PackedInt64Array()
	for t in 2:
		var m := PackedFloat32Array(); var sightings := []
		for p: Vector4 in w.rules.marks[t]: m.append_array(PackedFloat32Array([p.x,p.y,p.z,p.w]))
		for id: int in w.rules.sighted[t]:
			var s: Array = w.rules.sighted[t][id]; sightings.append([id,s[1],s[2]])
		marks.append(m); seen.append(sightings)
	for d: Drone in w.drones: drones.append(d.eid); drones.append(d.vis_mask)
	return [marks,seen,drones]

func _ready() -> void:
	MapDims.N = 256; MapDims.SIZE = 256.0; MapDims.HALF = 128.0; MapDims.BIOME = 256; Defs.MAP_HALF = 128.0
	Nav.N = 256; Nav.H = 128.0; HNav.C = 16; HNav.NC = 16; HNav.NCC = 256; HNav._corner = HNav._corners()
	TerrainMap.N = 256; TerrainMap.H = 128.0; TerrainMap.DN = 512
	var movement := preload("res://tests/fixtures/squad-movement.gd").new(); var actor_helper := preload("res://tests/fixtures/actors.gd").new()
	var projectile_helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var count := 0; var saw_hidden := false; var saw_contact := false; var saw_danger := false
	for trial in 12:
		var w := FireWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w); w.time = 100.0; w.next_eid = 1000; add_child(w)
		var kinds := ["watchtower","fob","town","mg_nest","mines","camo_net","concrete_wall","barracks","depot","roof"]
		for i in kinds.size():
			var st: Structure = w.spawn("structure",{"skind":kinds[i],"team":-1 if i == 9 else i % 2,"pos":Vector3((i % 5)*38.7-77,0,(i / 5)*71.3-37),"name":"Outpost %d" % i})
			st.manned = trial % 2 == 0; st.built = (i+trial) % 7 != 0; st.zone_c = st.position+Vector3(3.2,0,7.1); st.zone_r = 37.3; st.seen_mask = trial % 4
		for id in range(1,49):
			var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = (id+trial) % 3-1; s.owner_peer = -1-maxi(0,s.team)
			s.utype = "mg_gunner" if id % 9 == 0 else "rifleman"; s.position = Vector3((id % 8)*27.7-98.1,0,(id / 8)*31.3-87.7)
			w._register(s); w.add_child(s); s.on_spawned(); s.life = (id+trial) % 6
			if id == 1: s.mounted = w.entities[1000]; s.task_phase = 2; s.position = s.mounted.position; s.life = Soldier.Life.ALIVE
		for i in 8:
			var key: String = Defs.VEHICLES.keys()[(i*13+trial*7) % Defs.VEHICLES.size()]
			var v: Vehicle = w.spawn("vehicle",{"vkind":key,"team":i % 3-1,"pos":Vector3(i*24.7-89,0,(i % 3)*54.1-61.7)})
			if v.is_heli(): v.position.y = 3.01 if trial % 2 else 3.0; w.combat.dirty_collision(v.eid)
		for i in 4:
			var d := CameraDrone.new(); d.world = w; d.srv = true; d.eid = 70+i; d.team = i % 3-1; d.position = Vector3(i*52.1-78,12,81)
			w._register(d); w.add_child(d); d.on_spawned()
		for i in 4:
			var p := Projectile.new(); p.world = w; p.srv = true; p.eid = 80+i; p.team = i % 2; p.ptype = ["jet","a10","ac130","ac130"][i]
			p.position = Vector3(167.99 if trial % 3 == 0 else 168.0 if trial % 3 == 1 else -67,50,i*29.3-63); p.target = Vector3(-81,0,83)
			p.life_t = [1.99,2.0,2.001,26.0][trial % 4]; p.sight = 110.7 if trial % 2 else 0.0; p.stay = 40.0 if trial % 3 == 0 else 0.0
			w._register(p); w.add_child(p); p.set_process(false); p.set_physics_process(false)
		for t in 2: w.rules.marks[t] = [Vector4(83,-76,32.7,100.0),Vector4(-83,79,41.1,100.5),Vector4(31.7,21.3,17.1,99.9)]
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		for e: Entity in w.soldiers+w.vehicles:
			if e.eid % 3 == 0: w.terrain.netted[w.terrain.idx_of(e.position)] = 1
		assert(w.terrain._native.configure(256,[w.terrain.base,w.terrain.crater,w.terrain.rubble,w.terrain.woods,w.terrain.cov,w.terrain.cdir,w.terrain.solid,w.terrain.trench,w.terrain.netted],w.terrain.dh))
		var core: RefCounted = ClassDB.instantiate("FogCore"); var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore"); var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore"); var projectile: RefCounted = ClassDB.instantiate("ProjectileActorCore")
		var types := PackedByteArray(); var blocks := []; var profiles := []
		for e: Entity in w.entities.values():
			if e is Soldier: types.append(0); blocks.append(movement.soldier_bytes(e))
			elif e is Vehicle:
				assert(vehicle.load_state(VehicleState.capture(e))); types.append(2); blocks.append(vehicle.checkpoint()); profiles.append([e.eid,float(e.vdef.get("sight",50.0)),e.is_heli(),e.is_auto(),bool(e.vdef.get("cannon",false))])
			elif e is Structure: assert(structure.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure.checkpoint())
			elif e is Drone: types.append(4); blocks.append(actor_helper.drone_bytes(e,actors))
			elif e is Projectile: projectile_helper.start(e,projectile); types.append(3); blocks.append(projectile.checkpoint())
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(core.load_state(fog_values(w)))
		for now: float in [100.0,100.2,100.5,104.0]:
			w.time = now
			for e: Entity in w.entities.values(): e.net_dirty = false
			var label := "%d/%.4f" % [trial,now]; var result: Array = core.update(actors,geometry,now,profiles); assert(result.size() == 1,"fog result " + label)
			w.rules._visibility(); var changed := PackedInt64Array()
			for e: Entity in w.soldiers+w.vehicles+w.drones+w.owned_structures:
				if e.net_dirty: changed.append(e.eid)
			assert(result[0] == changed,"dirty visibility " + label); assert(core.values() == fog_values(w),"fog state " + label)
			for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label)
			for v: Vehicle in w.vehicles: assert(vehicle.restore(actors.actor_state(v.eid))); assert(vehicle.values() == VehicleState.capture(v),"vehicle " + label)
			for st: Structure in w.structures: assert(structure.restore(actors.actor_state(st.eid))); assert(structure.values() == StructureState.capture(st),"structure " + label)
			w.rules._danger_maps(); var danger: Array = core.update_danger(actors,geometry,profiles); assert(danger.size() == 2)
			for t in 2:
				assert(danger[t] == w.nav.hnav_i.danger[t],"danger " + label); assert(danger[t] == w.nav.hnav_v.danger[t]); saw_danger = saw_danger or danger[t].count(0.0) < danger[t].size()
			assert(geometry.inspect()[1] == nav_save(w.nav),"danger routes " + label)
			for s: Soldier in w.soldiers: saw_hidden = saw_hidden or s.vis_mask == 0; saw_contact = saw_contact or s.vis_mask == 3
			for retained in [core,actors,geometry]: assert(retained.restore(retained.checkpoint()))
			count += 1
		w.free()
	assert(saw_hidden and saw_contact and saw_danger,"fog coverage")
	movement.free(); actor_helper.free(); projectile_helper.free()
	print("FOG passed states=",count); get_tree().quit()
