extends "res://tests/fixtures/world-geometry.gd"

class RoadWorld extends World:
	var removed := PackedInt64Array()
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass
	func despawn(e: Entity) -> void:
		if e and not e.gone: removed.append(e.eid)
		super.despawn(e)

class Building extends Structure:
	func _ready() -> void:
		super(); set_process(false); set_physics_process(false)

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var cleared := 0; var no_fob := false; var routed := false
	for trial in 32:
		var w := RoadWorld.new(); w.srv = true; w.has_view = false
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w); add_child(w)
		for i in 18:
			var st := Building.new(); st.world = w; st.srv = true; st.eid = i + 1
			st.skind = "depot" if i < 2 else "fob" if i < 8 else "town" if i < 11 else "crates"
			st.team = i % 2 if i < 11 else -1; st.owner_peer = -1 - maxi(0,st.team)
			st.position = Vector3((i % 6) * 9.3 - 24,0,(i / 6) * 11.7 - 14); st.yaw = (trial % 7) * 0.137; st.rotation.y = st.yaw
			st.completed_order = (i * 5 + trial) % 6 + 1; st.sname = "Network %d" % i
			st.supply_status = "No FOB" if trial % 2 == 0 else "Truck destroyed"; st.wrecked = i == 2 and trial % 3 == 0
			st.size = Vector3(3,2,2) if i < 11 else Vector3.ONE
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st); w.combat.dirty_collision(st.eid)
			if i < 2: w.rules.depots[i] = st
			elif i >= 8 and i < 11: w.rules.town_list.append(st)
		w.roads[2] = [PackedVector3Array([Vector3(-25,0,-25),Vector3(25,0,-25)])]
		w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision(); assert(geometry.restore(world_save(w)))
		assert(network.load_state(PackedInt64Array([1,2]),PackedInt64Array([9,10,11]),w.rules.fob_order,w.roads,w._painted_roads))
		for step in 8:
			if step == 2:
				for f: Structure in w.rules.fobs(0): f.wrecked = true
			if step == 3: w.entities[9].team = 1
			if step == 4: w.entities[3].team = 1
			if step == 5:
				for f: Structure in w.rules.fobs(0): f.wrecked = false
			var team := step % 2
			var blocks := []; var types := PackedByteArray()
			for st: Structure in w.structures:
				assert(structure.load_state(StructureState.capture(st))); blocks.append(structure.checkpoint()); types.append(1)
			assert(actors.load_state(1000,types,blocks))
			w.removed.clear(); var random := w.rng.state
			w.rules.rebuild_network(team)
			var result: Array = network.rebuild(team,actors,geometry); var label := "%d/%d" % [trial,step]
			assert(result.size() == 1,"network result " + label)
			assert(result[0] == w.removed,"network removals " + label); cleared += w.removed.size()
			assert(w.rng.state == random,"network RNG " + label)
			assert(network.values() == [PackedInt64Array([1,2]),PackedInt64Array([9,10,11]),w.rules.fob_order,w.roads,w._painted_roads],"network state " + label)
			var identities := PackedInt64Array()
			for st: Structure in w.structures:
				identities.append(st.eid); identities.append(1)
				assert(structure.restore(actors.actor_state(st.eid)))
				assert(structure.values() == StructureState.capture(st),"network structure %s/%d" % [label,st.eid])
				if st.skind == "town": no_fob = no_fob or st.supply_status == "No FOB"; routed = routed or not st.road.is_empty()
				if st.skind == "fob": assert(network.route_to(st.eid,actors) == w.rules.route_to(st),"network chain " + label)
			assert(actors.identities() == identities,"network registry " + label)
			check_geometry(w,geometry,"network " + label)
			w.combat.finish_tick(); geometry.finish_tick(); w.nav.update_hier(1); assert(geometry.update_hierarchy(1))
			check_geometry(w,geometry,"network end " + label)
			for retained in [network,actors,geometry]:
				var bytes: PackedByteArray = retained.checkpoint(); assert(retained.restore(bytes) and retained.checkpoint() == bytes)
		w.free()
	assert(cleared > 0 and no_fob and routed,"network coverage")
	print("SUPPLY_NETWORK passed states=",checks," removed=",cleared)
	get_tree().quit()
