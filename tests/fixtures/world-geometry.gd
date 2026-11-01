extends Node

var checks := 0

func collision_equal(expected: PackedByteArray, actual: PackedByteArray) -> bool:
	if expected.size() != actual.size() or expected.size() < 12: return false
	var compared := expected.duplicate(); var cursor := 12
	for body in expected.decode_u32(8):
		var count := expected.decode_u32(cursor + 8); cursor += 12
		for shape in count:
			# Platform sinf/cosf differs from pinned libm; multiplying the local
			# transform propagates that rounding into box centers and child bases.
			for component in range(1,13):
				var at := cursor + component * 4
				var a := expected.decode_float(at); var b := actual.decode_float(at)
				# Centers at larger coordinates have wider float steps than unit bases.
				var scale := maxf(1.0,maxf(absf(a),absf(b))) if component < 4 else 1.0
				if not is_finite(a) or not is_finite(b) or absf(a - b) > 0.00000024 * scale: return false
				compared.encode_u32(at,actual.decode_u32(at))
			cursor += 64
	# Identity, topology and half-extents still compare byte for byte.
	return compared == actual

func collision_difference(expected: PackedByteArray, actual: PackedByteArray) -> String:
	if expected.size() != actual.size(): return "bytes %d / %d" % [expected.size(),actual.size()]
	var differences := []; var cursor := 12
	for body in expected.decode_u32(8):
		var id := expected.decode_u64(cursor); var count := expected.decode_u32(cursor + 8); cursor += 12
		for shape in count:
			for component in range(1,16):
				var at := cursor + component * 4
				if expected.decode_u32(at) != actual.decode_u32(at):
					var field := "center" if component < 4 else "basis" if component < 13 else "half"
					differences.append("body=%d shape=%d %s[%d] %.12f / %.12f bits=%d/%d" % [id,shape,field,component,expected.decode_float(at),actual.decode_float(at),expected.decode_u32(at),actual.decode_u32(at)])
					if differences.size() == 16: return "; ".join(differences)
			cursor += 64
	return "; ".join(differences) if not differences.is_empty() else "collision metadata differs"

func _ready() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 591773
	var core: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var kinds := ["house_wall", "tree", "camo_net", "trench", "bunker", "rubble", "floor", "wire", "mines", "tank_trap", "tunnel", "helipad", "roof", "low_wall", "sandbags", "barracks"]
	for trial in 6:
		MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
		Nav.N = 64; Nav.H = 32.0; HNav.C = 16 if trial % 2 == 0 else 32
		HNav.NC = 64 / HNav.C; HNav.NCC = HNav.NC * HNav.NC; HNav._corner = HNav._corners()
		TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
		var w := World.new(); w.has_view = false; w.srv = true
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w)
		w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision()
		var walls: Array[Structure] = []
		for id in range(1, 25):
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = id
			st.skind = kinds[(id + trial) % kinds.size()]; st.built = id % 9 != 0
			st.size = Vector3(rng.randf_range(2, 8), 2, rng.randf_range(1, 5))
			st.foot = Vector2(st.size.x, st.size.z) * 0.5; st.radius = st.foot.length()
			st.position = Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-28, 28))
			st.yaw = rng.randf_range(-PI, PI); st.door_shut = id % 3 == 0
			for part in 3:
				st.parts.append({"p": Vector3(part * 0.3, 0.5, -part * 0.7), "s": Vector3(st.size.x, [0.099, 1.0, 1.7, 2.0][(part + id) % 4], st.size.z), "r": part * 0.37, "nav": (id + part) % 4, "veh": (id + 3 * part) % 4, "cover": part % 3 != 2, "col": true})
			w.add_child(st); w._register(st); w._shash_add(st)
			w.nav.add_structure(st); w.terrain.structure_changed(st)
			if st.door_shut: w.add_door(st)
			var rows := PackedFloat32Array([st.position.x, 1, st.position.z, 1, 0, 0, 0, 1, 0, 0, 0, 1, st.foot.x, 1, st.foot.y, 0])
			assert(w.combat._collision.replace_body(id, rows)); w.combat._collision_bodies[id] = null
			walls.append(st)
		w.terrain.tick(137); w.nav.finalize()
		assert(core.restore(world_save(w)))
		for st in walls:
			assert(structure.load_state(StructureState.capture(st)))
			assert(core.sync_structure(structure, true)); w.terrain.sync_structure(st, true)
		check_geometry(w, core, "initial %d" % trial)
		if trial % 2: walls.reverse()
		for step in walls.size():
			var st: Structure = walls[step]
			var blocks := []; var types := PackedByteArray()
			for other in w.structures:
				if other == st: continue
				assert(structure.load_state(StructureState.capture(other)))
				blocks.append(structure.checkpoint()); types.append(1)
			assert(actors.load_state(1000, types, blocks))
			var state := StructureState.capture(st); state[3][0] = 1
			assert(structure.load_state(state)); assert(core.retire_structure(structure, actors))
			w.despawn(st)
			assert(structure.values() == StructureState.capture(st), "retired structure cells")
			check_geometry(w, core, "retired %d/%d" % [trial, step])
			var a := st.position + Vector3(0, 1, -12); var b := st.position + Vector3(0, 1, 12)
			var hit: PackedFloat64Array = w.combat._collision.ray(a, b, PackedInt64Array())
			assert(core.ray(a, b) == (0 if hit.is_empty() else int(hit[0])))
			var saved: PackedByteArray = core.checkpoint(); assert(core.restore(saved)); assert(core.checkpoint() == saved)
			w.terrain.tick(33); assert(core.tick_cover(33))
			check_geometry(w, core, "cover %d/%d" % [trial, step])
			w.combat.finish_tick(); core.finish_tick()
			check_geometry(w, core, "tick end %d/%d" % [trial, step])
		w.free()
	print("WORLD_GEOMETRY passed states=", checks)
	get_tree().quit()

func u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(4); bytes.encode_u32(0, value); return bytes

func block(data: PackedByteArray) -> PackedByteArray:
	var bytes := u32(data.size()); bytes.append_array(data); return bytes

func header(magic: String) -> PackedByteArray:
	var bytes := magic.to_utf8_buffer(); bytes.append_array(PackedByteArray([1, 0, 2, 0])); return bytes

func nav_save(nav: Nav) -> PackedByteArray:
	var bytes := header("FLNS")
	for state in [nav._planner.checkpoint(), nav.hnav_i._core.checkpoint(), nav.hnav_v._core.checkpoint()]: bytes.append_array(block(state))
	var indices := nav.cell_objs.keys(); indices.sort(); bytes.append_array(u32(indices.size()))
	for index: int in indices:
		bytes.append_array(u32(index)); bytes.append_array(u32(nav.cell_objs[index].size()))
		for item: Array in nav.cell_objs[index]:
			bytes.append_array(u32(item[0])); bytes.append(item[1]); bytes.append(item[2])
	return bytes

func spatial_save(grid: Dictionary, size: float) -> PackedByteArray:
	var index: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var cells := []
	for key: Vector2i in grid:
		if not grid[key].is_empty(): cells.append([key, InfantryState.entity_ids(grid[key])])
	assert(index.load_state(size, cells)); return index.checkpoint()

func states(w: World) -> Array:
	return [w.terrain._native.checkpoint(), nav_save(w.nav), w.combat._collision.checkpoint(), spatial_save(w._shash, 16.0), spatial_save(w.door_cells, 1.5)]

func world_save(w: World) -> PackedByteArray:
	var bytes := header("FLWG")
	for state in states(w): bytes.append_array(block(state))
	bytes.append_array(block(w.water.deck)); bytes.append_array(u32(w.combat._collision_retired.size()))
	for id: int in w.combat._collision_retired: bytes.append_array(u32(id))
	return bytes

func check_geometry(w: World, core: RefCounted, where: String) -> void:
	var expected := states(w); var actual: Array = core.inspect()
	assert(terrain_equal(expected[0], actual[0]), "geometry terrain " + where)
	assert(collision_equal(expected[2],actual[2]), "geometry collision " + where + ": " + collision_difference(expected[2],actual[2]))
	for i in [1,3,4]:
		assert(expected[i] == actual[i], "geometry state %s part %d" % [where, i])
	var expected_world := header("FLWG"); expected_world.append_array(block(actual[0]))
	expected_world.append_array(block(expected[1])); expected_world.append_array(block(actual[2]))
	expected_world.append_array(world_save(w).slice(20 + expected[0].size() + expected[1].size() + expected[2].size()))
	assert(expected_world == core.checkpoint(), "full geometry " + where)
	checks += 1

func terrain_equal(expected: PackedByteArray, actual: PackedByteArray) -> bool:
	if expected.size() != actual.size(): return false
	# Pinned libm and Godot's platform trig can differ in their last double bits.
	# Only those coefficients get a tolerance; cell data, repair order and every other byte stay exact.
	var compared := expected.duplicate()
	var at := 21
	for layer in 9: at += 4 + expected.decode_u32(at)
	at += 4 + 4 * expected.decode_u32(at)
	at += 4 + 4 * expected.decode_u32(at)
	at += 4
	var count := expected.decode_u32(at + 16); at += 20
	for item in count:
		at += 103
		var parts := expected.decode_u32(at); at += 4
		for part in parts:
			for offset in [12, 20]:
				var a := expected.decode_double(at + offset); var b := actual.decode_double(at + offset)
				if absf(a - b) > 0.000000000000001: return false
				compared.encode_double(at + offset, b)
			at += 45
		at += 4 + 8 * expected.decode_u32(at)
	return compared == actual
