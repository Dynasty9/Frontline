class_name BattlefieldMap
extends RefCounted
## Unticked scenery and ground, baked before forces are assigned to the players.

const FORMAT := 4
const MAGIC := "FLMAPGD1"
const MAX_BYTES := 256 * 1024 * 1024
const BYTES := ["base", "crater", "rubble", "woods", "cov", "cdir", "solid", "trench", "netted"]
const FLOATS := ["dh", "slopes", "vehicle_slopes"]
const GRIDS := ["inf", "veh", "tracked"]
const SOURCES := ["scripts/battlefields.gd", "scripts/autoload/defs.gd", "scripts/game/battlefield_map.gd", "scripts/game/mapgen.gd",
	"scripts/game/world.gd", "scripts/game/entity.gd", "scripts/game/rules.gd",
	"scripts/game/towngen.gd", "scripts/game/building_yards.gd", "scripts/game/terrain.gd", "scripts/game/landform.gd", "scripts/game/water.gd",
	"scripts/game/structure.gd", "scripts/game/cover.gd", "scripts/game/nav.gd", "scripts/game/nav_raster.gd", "scripts/game/hnav.gd",
	"scripts/game/trench_net.gd", "scripts/game/map_dims.gd", "assets/terrain/alpine_forms.tres"]


static func source_hashes() -> Dictionary:
	var hashes := {}
	for source: String in SOURCES:
		hashes[source] = FileAccess.get_file_as_string("res://" + source).replace("\r\n", "\n").sha256_text()
	return hashes


static func path(key: String) -> String:
	return "res://assets/battlefields/%s.flmap" % key


static func read(key: String) -> Dictionary:
	var entry := Battlefields.find(key)
	if entry.is_empty() or not FileAccess.file_exists(path(key)):
		return {}
	var file := FileAccess.open(path(key), FileAccess.READ)
	if file == null or file.get_length() < 48 or file.get_length() > MAX_BYTES:
		return {}
	if file.get_buffer(8).get_string_from_ascii() != MAGIC:
		return {}
	var length := file.get_64()
	if length < 1 or length > MAX_BYTES:
		return {}
	var digest := file.get_buffer(32)
	var packed := file.get_buffer(file.get_length() - file.get_position())
	var raw := packed.decompress(length, FileAccess.COMPRESSION_ZSTD)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	if raw.size() != length or hash.finish() != digest:
		return {}
	var data = bytes_to_var(raw)
	if not valid(data, entry):
		return {}
	# Export CI checks the source manifest before scripts become compiled resources.
	if OS.has_feature("editor") and data.sources != source_hashes():
		return {}
	return data


static func valid(data: Variant, entry: Dictionary) -> bool:
	if not data is Dictionary or data.get("format") != FORMAT or data.get("key") != entry.key or data.get("seed") != entry.seed or data.get("size") != entry.size:
		return false
	if data.get("engine") != Engine.get_version_info().string:
		return false
	if not data.get("terrain") is Dictionary or not data.get("structures") is Array or data.structures.size() > 100000:
		return false
	if not data.get("sources") is Dictionary or data.sources.size() != SOURCES.size():
		return false
	var cells: int = int(entry.size) * int(entry.size)
	for field: String in BYTES:
		if not data.terrain.get(field) is PackedByteArray or data.terrain[field].size() != cells:
			return false
	for field: String in FLOATS:
		var count := cells * TerrainMap.DRES * TerrainMap.DRES if field == "dh" else cells
		if not data.terrain.get(field) is PackedFloat32Array or data.terrain[field].size() != count:
			return false
	if not Landform.valid(data.get("heights"), int(entry.size)) or data.heights.is_empty():
		return false
	if not data.get("rocky") is PackedFloat32Array or data.rocky.size() != data.heights.size():
		return false
	if not data.get("deform") is PackedByteArray or data.deform.size() != cells * TerrainMap.DRES * TerrainMap.DRES * 8:
		return false
	if not data.get("water") is Dictionary or not data.water.get("coast") is Dictionary or not data.water.get("rivers") is Array or not data.water.get("ponds") is Array:
		return false
	var wet: bool = not data.water.coast.is_empty() or not data.water.rivers.is_empty() or not data.water.ponds.is_empty()
	if not data.get("water_mask") is PackedByteArray or data.water_mask.size() != (cells * 4 if wet else 0):
		return false
	if not data.get("deck") is PackedByteArray or data.deck.size() != (cells if wet else 0):
		return false
	if not data.get("roads") is Array or data.roads.size() != 3 or not data.get("decor") is Array or not data.get("town") is Rect2 or not data.get("key_points") is Array:
		return false
	if not data.get("rng_state") is int or not data.get("next_eid") is int or not data.get("fob_names") is Array or data.fob_names.size() != 2:
		return false
	var previous := 0
	for rec in data.structures:
		if not rec is Array or rec.size() != 4 or not rec[0] is int or rec[0] <= previous or not rec[1] is Dictionary or not rec[2] is int or not rec[3] is Array:
			return false
		if not rec[1].get("skind") is String or not rec[1].get("pos") is Vector3:
			return false
		for cell in rec[3]:
			if not cell is int or cell < 0 or cell >= cells:
				return false
		previous = rec[0]
	if not data.get("nav") is Dictionary or not data.nav.get("objects") is Dictionary:
		return false
	if not data.nav.get("costs") is Array or data.nav.costs.size() != 3:
		return false
	for graph in data.nav.costs:
		if not graph is Dictionary or not graph.get("nodes") is Dictionary or not graph.get("costs") is Array:
			return false
		for matrix in graph.costs:
			if not matrix is PackedFloat64Array:
				return false
			for cost: float in matrix:
				if not is_finite(cost) or cost < HNav.UNKNOWN:
					return false
	for cell in data.nav.objects:
		if not cell is int or cell < 0 or cell >= cells or not data.nav.objects[cell] is Array:
			return false
		for obstacle in data.nav.objects[cell]:
			if not obstacle is Array or obstacle.size() != 3 or not obstacle[0] is int or not obstacle[1] is int or not obstacle[2] is int:
				return false
			if obstacle[0] <= 0 or obstacle[0] >= data.next_eid or obstacle[1] < 0 or obstacle[1] > Nav.SOLID or obstacle[2] < 0 or obstacle[2] > Nav.SOLID:
				return false
	for field: String in ["ikind", "vkind", "tkind"]:
		if not data.nav.get(field) is PackedByteArray or data.nav[field].size() != cells:
			return false
	for grid: String in GRIDS:
		var raster: Variant = data.nav.get(grid)
		if not raster is Array or raster.size() != 2 or not raster[0] is PackedByteArray or raster[0].size() != cells or not raster[1] is PackedFloat32Array or raster[1].size() != cells:
			return false
	return data.next_eid > previous


static func save(world: World, key: String) -> Error:
	var records := []
	for st: Structure in world.structures:
		records.append([st.eid, st.get_props(), st.completed_order, st.nav_cells])
	var terrain := {}
	for field: String in BYTES + FLOATS:
		terrain[field] = world.terrain.get(field)
	var data := {"format": FORMAT, "engine": Engine.get_version_info().string, "key": key, "seed": int(world.settings.seed), "size": MapDims.N,
		"structures": records, "terrain": terrain, "heights": world.terrain.landform.heights, "rocky": world.terrain.landform.rocky,
		"water": world.water.to_dict(), "deck": world.water.deck, "roads": world.roads, "decor": world.decor, "town": world.town_rect,
		"key_points": world.key_points, "rng_state": world.rng.state, "next_eid": world.next_eid, "fob_names": world.rules.fob_names_used}
	data["deform"] = world.terrain.deform_img.get_data()
	data["water_mask"] = world.water.mask.get_data() if world.water.mask != null else PackedByteArray()
	data["sources"] = source_hashes()
	var nav := {"objects": world.nav.cell_objs, "ikind": world.nav.ikind, "vkind": world.nav.vkind, "tkind": world.nav.tkind}
	for key_grid: String in GRIDS:
		var grid: NavRaster = world.nav.get(key_grid)
		nav[key_grid] = [grid.solid, grid.weight]
	data["nav"] = nav
	nav["costs"] = []
	for hierarchy: HNav in [world.nav.hnav_i, world.nav.hnav_v, world.nav.hnav_t]:
		nav.costs.append({"nodes": hierarchy.node_cell, "costs": hierarchy.costs})
	if not valid(data, Battlefields.find(key)):
		return ERR_INVALID_DATA
	var raw := var_to_bytes(data)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	var target := ProjectSettings.globalize_path(path(key))
	var directory_error := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_64(raw.size())
	file.store_buffer(hash.finish())
	file.store_buffer(raw.compress(FileAccess.COMPRESSION_ZSTD))
	file.close()
	var error := DirAccess.rename_absolute(target + ".tmp", target)
	if error != OK:
		return error
	var manifest := FileAccess.open(target + ".json", FileAccess.WRITE)
	if manifest == null:
		return FileAccess.get_open_error()
	manifest.store_string(JSON.stringify({"format": FORMAT, "engine": data.engine, "key": key, "seed": data.seed,
		"size": data.size, "sha256": FileAccess.get_sha256(target), "sources": data.sources}, "\t") + "\n")
	manifest.close()
	return OK


static func restore_ground(world: World, data: Dictionary, water: WaterMap) -> void:
	var tm := world.terrain
	tm.landform.heights = data.heights
	tm.landform.prepare_crags(true)
	tm.landform.rocky = data.rocky
	for h: float in tm.landform.heights:
		tm.landform.peak = maxf(tm.landform.peak, h)
	for field: String in FLOATS:
		if field != "vehicle_slopes" or world.srv:
			tm.set(field, data.terrain[field])
	if tm.deform_img != null:
		# Atmosphere retains this Image; replace its pixels, not the object.
		tm.deform_img.set_data(TerrainMap.DN, TerrainMap.DN, false, Image.FORMAT_RGF, data.deform)
		tm.deform_dirty.append(Rect2i(0, 0, TerrainMap.DN, TerrainMap.DN))
	water.deck = data.deck
	water.mask = Image.create_from_data(MapDims.N, MapDims.N, false, Image.FORMAT_RGBA8, data.water_mask) if not data.water_mask.is_empty() else null
	water.version += 1
	tm.landform_progress = 1.0
	tm.version += 1


static func restore(world: World, data: Dictionary) -> Array:
	world.terrain.hold_nav()
	world.water.from_dict(data.water)
	world.water.deck = data.deck
	world.roads = data.roads
	world._painted_roads = world.roads.duplicate(true)
	world.key_points = data.key_points
	var tm := world.terrain
	for field: String in BYTES:
		tm.set(field, data.terrain[field])
	restore_ground(world, data, world.water)
	world._load_mark("cached ground restored")
	var fobs: Array = [null, null]
	world.restoring_battlefield = true
	var count := 0
	for rec: Array in data.structures:
		world.next_eid = int(rec[0])
		var st: Structure = world.spawn("structure", rec[1])
		st.completed_order = int(rec[2])
		st.nav_cells = rec[3]
		if st.skind == "depot":
			world.rules.depots[st.team] = st
		elif st.skind == "fob" and st.completed_order > 0:
			fobs[st.team] = st
			world.rules.fob_order = maxi(world.rules.fob_order, st.completed_order)
		elif st.skind == "town":
			world.rules.town_list.append(st)
		count += 1
		if world.has_view and count % 128 == 0:
			await world._breathe("Opening the battlefield", 0.18 + 0.32 * count / data.structures.size())
	world.restoring_battlefield = false
	world.next_eid = int(data.next_eid)
	world.rules.fob_names_used = data.fob_names
	world._load_mark("cached structures restored")
	tm._queue.clear()
	tm._qhead = 0
	tm._dirty.fill(0)
	tm._fresh = false
	world.nav.cell_objs = data.nav.objects
	world.nav.prepared_costs = data.nav.costs
	for field: String in ["ikind", "vkind", "tkind"]:
		world.nav.set(field, data.nav[field])
	for i in GRIDS.size():
		var grid: NavRaster = world.nav.get(GRIDS[i])
		grid.solid = data.nav[GRIDS[i]][0]
		grid.weight = data.nav[GRIDS[i]][1]
		var hierarchy: HNav = [world.nav.hnav_i, world.nav.hnav_v, world.nav.hnav_t][i]
		# Dirty detection needs yesterday's cells, separate from the live raster.
		hierarchy._solid = grid.solid.duplicate()
		hierarchy._weight = grid.weight.duplicate()
	tm.release_nav()
	world._load_mark("cached navigation cells restored")
	world.nav.build_boat_grid(world.water)
	world.set_decor(data.decor, data.town)
	world.rng.state = int(data.rng_state)
	return fobs
