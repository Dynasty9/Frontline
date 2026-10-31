extends "res://tests/fixtures/world-geometry.gd"

class CollisionScene extends World:
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass

class PartStructure extends Structure:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

func compare_collision(w: World, core: RefCounted, st: Structure, label: String) -> void:
	w.combat._sync_collision()
	var actual: PackedByteArray = core.inspect()[2]
	var expected: PackedByteArray = w.combat._collision.checkpoint()
	assert(collision_equal(expected,actual), "structure collision geometry " + label + ": " + collision_difference(expected,actual))
	for n in 24:
		var a := st.position + Vector3(-12, float(n % 6) * 0.53, (n / 6) * 3 - 4)
		var b := st.position + Vector3(12, float(n % 6) * 0.53, -(n / 6) * 3 + 4)
		var reference: PackedFloat64Array = w.combat._collision.ray(a, b, PackedInt64Array())
		assert(core.ray(a, b) == (0 if reference.is_empty() else int(reference[0])), "structure ray " + label)
	checks += 1

func _ready() -> void:
	# Keep the platform allowance out of identities, shape sizes and meaningful transforms.
	var sample := PackedByteArray(); sample.resize(88); sample.encode_u32(8,1); sample.encode_u32(20,1)
	for at in [28,40]:
		var rounded := sample.duplicate(); rounded.encode_float(at,0.00000006); assert(collision_equal(sample,rounded))
		rounded.encode_float(at,0.000001); assert(not collision_equal(sample,rounded))
	for at in [12,24,76]:
		var changed := sample.duplicate(); changed[at] = 1; assert(not collision_equal(sample,changed))
	MapDims.N = 32; MapDims.SIZE = 32.0; MapDims.HALF = 16.0; MapDims.BIOME = 32
	Nav.N = 32; Nav.H = 16.0; HNav.C = 16; HNav.NC = 2; HNav.NCC = 4; HNav._corner = HNav._corners()
	TerrainMap.N = 32; TerrainMap.H = 16.0; TerrainMap.DN = 64
	var w := CollisionScene.new(); w.srv = true; w.has_view = false
	w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.nav.finalize()
	w.combat = Combat.new(w); w.combat.enable_native_collision(); add_child(w)
	var core: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var empty := world_save(w)
	var kinds := ["low_wall", "tall_wall", "house_wall", "floor", "dock", "bridge", "roof", "rubble", "crates", "car", "wreck", "tree", "fob", "town", "barracks", "factory", "medic_tent", "research", "depot", "sandbags", "concrete_wall", "hesco", "barricade", "wire", "mines", "tank_trap", "trench", "camo_net", "watchtower", "mg_nest", "hmg_nest", "mortar_pit", "at_post", "bunker", "tunnel", "helipad"]
	for kind: String in kinds:
		for trial in 12:
			assert(core.restore(empty))
			var st := PartStructure.new(); st.world = w; st.srv = true; st.eid = 1; st.skind = kind; st.team = trial % 2
			st.size = Vector3(7.3, 2.3, 5.7); st.variant = trial % 6; st.built = trial % 3 != 0; st.door_shut = true
			st.position = Vector3(-4.3 + trial * 0.7, 0.17, -3.1 + trial * 0.3); st.yaw = trial * 0.417 - 1.3; st.rotation.y = st.yaw
			st.foot = Vector2(st.size.x, st.size.z) * 0.5; st.radius = st.foot.length() + 0.5
			st._define_parts(); w.entities[1] = st; w.add_child(st)
			if st.built: st._make_body()
			for stage in 3:
				if stage == 1:
					st.built = true; st._make_body(); st.position += Vector3(0.71, 0.19, -0.37); st.yaw += 0.571; st.rotation.y = st.yaw
					st.tilt = Vector2(0.31, 1.57); w.combat.dirty_collision(1)
				elif stage == 2:
					st.open_door(null, false)
				assert(structure.load_state(StructureState.capture(st)))
				assert(core.refresh_structure_collision(structure))
				compare_collision(w, core, st, "%s/%d/%d" % [kind, trial, stage])
				var bytes: PackedByteArray = core.checkpoint(); assert(core.restore(bytes) and core.checkpoint() == bytes)
			w.combat.remove_collision(1); w.entities.erase(1); st.free()
	w.free()
	print("STRUCTURE_COLLISION passed states=", checks)
	get_tree().quit()
