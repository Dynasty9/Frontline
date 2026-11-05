extends "res://tests/fixtures/world-geometry.gd"

class SpawnWorld extends World:
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass

class Building extends Structure:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var kinds := ["low_wall", "tall_wall", "house_wall", "floor", "dock", "bridge", "roof", "rubble", "crates", "car", "wreck", "tree", "fob", "town", "barracks", "factory", "medic_tent", "research", "depot", "sandbags", "concrete_wall", "hesco", "barricade", "ammo_cache", "wire", "mines", "tank_trap", "trench", "camo_net", "watchtower", "mg_nest", "hmg_nest", "mortar_pit", "at_post", "bunker", "tunnel", "helipad"]
	for trial in 12:
		var w := SpawnWorld.new(); w.srv = true; w.has_view = false
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.nav.finalize()
		w.combat = Combat.new(w); w.combat.enable_native_collision(); add_child(w)
		var core: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
		assert(core.restore(world_save(w)))
		var walls: Array[Structure] = []
		for index in kinds.size():
			var kind: String = kinds[index]
			var st := Building.new(); st.world = w; st.srv = true; st.eid = index + 1; st.skind = kind; st.team = trial % 2
			st.size = Vector3(7.3, 2.3, 5.7); st.variant = trial % 6; st.built = trial % 3 != 0; st.door_shut = trial % 2 == 0
			st.position = Vector3((index % 7) * 5.13 - 16, 0.17, (index / 7) * 6.79 - 18); st.yaw = trial * 0.317 - 1.3; st.rotation.y = st.yaw
			if trial >= 6 and (Defs.BUILDINGS.has(kind) or kind in ["depot", "wreck", "car", "crates", "tree", "town"]): st.size = Vector3.ONE
			if trial % 4 == 1: st.hp = 41.0; st.max_hp = 937.0; st.supply = 23.0
			var profile := PackedFloat64Array()
			if Defs.BUILDINGS.has(kind):
				var definition: Dictionary = Defs.BUILDINGS[kind]; profile = PackedFloat64Array([definition.size.x, definition.size.y, definition.hp])
			assert(structure.load_state(StructureState.capture(st)))
			assert(core.spawn_structure(actors, structure, profile) == st.eid, "spawn %s/%d" % [kind, trial])
			w._register(st); w.add_child(st); st.on_spawned(); w.combat.dirty_collision(st.eid); w._shash_add(st); w.terrain.structure_changed(st)
			var expected := StructureState.capture(st)
			assert(structure.values() == expected, "structure birth %s/%d" % [kind, trial])
			assert(structure.load_state(expected)); assert(actors.actor_state(st.eid) == structure.checkpoint(), "structure birth checkpoint %s/%d" % [kind, trial])
			w.combat._sync_collision(); check_geometry(w, core, "spawn %s/%d" % [kind, trial])
			walls.append(st)
			if index % 7 == 3:
				w.terrain.tick(37); assert(core.tick_cover(37)); check_geometry(w, core, "repair %s/%d" % [kind, trial])
				var saved: PackedByteArray = core.checkpoint(); assert(core.restore(saved) and core.checkpoint() == saved)
		# Creation must remain compatible with destruction and its deferred collision removal.
		for index in range(0, walls.size(), 3):
			var st: Structure = walls[index]
			var blocks := []; var types := PackedByteArray()
			for other in w.structures:
				if other == st: continue
				assert(structure.load_state(StructureState.capture(other))); blocks.append(structure.checkpoint()); types.append(1)
			assert(actors.load_state(1000, types, blocks))
			var state := StructureState.capture(st); state[3][0] = 1
			assert(structure.load_state(state)); assert(core.retire_structure(structure, actors)); w.despawn(st)
			check_geometry(w, core, "retire %d/%d" % [trial, index])
		w.combat.finish_tick(); core.finish_tick(); check_geometry(w, core, "finish %d" % trial)
		w.free()
	print("STRUCTURE_BIRTH passed states=", checks)
	get_tree().quit()
