extends Node

class ClearCombat extends Combat:
	func ray(_from: Vector3, _to: Vector3, _ex: Array = []) -> Dictionary:
		return {}


func _ready() -> void:
	var river_shapes := [{"pts": PackedVector3Array([Vector3(-80, 0, -80), Vector3.ZERO, Vector3(80, 0, 80)]), "w": 20.0}]
	var river_bytes := var_to_bytes(river_shapes)
	var tips := WaterView.scenery_river_tips(river_shapes, 32.0)
	assert(tips.size() == 8 and tips[0].z == 10.0 and tips[1].z == 10.0 and tips[2] == Vector4.ZERO, "Corner crossings are deduplicated and unused shader slots are empty")
	assert(Vector2(tips[0].x, tips[0].y) == Vector2(-32, -32) and Vector2(cos(tips[0].w), sin(tips[0].w)).dot(Vector2(-1, -1).normalized()) > 0.999)
	assert(Vector2(tips[1].x, tips[1].y) == Vector2(32, 32) and Vector2(cos(tips[1].w), sin(tips[1].w)).dot(Vector2(1, 1).normalized()) > 0.999)
	assert(var_to_bytes(river_shapes) == river_bytes, "Scenery continuations never alter replicated water shapes")
	var inland := [{"pts": PackedVector3Array([Vector3(-10, 0, 0), Vector3(10, 0, 0)]), "w": 20.0}]
	assert(WaterView.scenery_river_tips(inland, 32.0) == WaterView.scenery_river_tips([], 32.0), "Inland rivers need no boundary extension")
	assert(MapGen.habitat(0.4, 6.0, 0.2) > MapGen.habitat(0.4, -6.0, 0.2), "Sheltered bowls support more growth than exposed ribs")
	assert(MapGen.habitat(0.3, 0.0, 0.8) > MapGen.habitat(0.3, 0.0, -0.8), "Aspect affects habitat")
	assert(MapGen.habitat(0.2, 0.0, 0.0) > MapGen.habitat(0.9, 0.0, 0.0), "Gentler ledges retain more vegetation")
	assert(MapGen.alpine_dressing(0.15, 0.1, 0.8) == "alpine_scrub")
	assert(MapGen.alpine_dressing(0.55, 0.1, 0.8) == "alpine_stones")
	assert(MapGen.alpine_dressing(0.2, 0.6, 0.8) == "alpine_stones")
	assert(MapGen.alpine_dressing(0.8, 0.1, 0.8) == "")
	assert(MapGen.alpine_dressing(0.2, 1.2, 0.8) == "")
	var boughs := Res.foliage_cards(true)
	assert(boughs == Res.foliage_cards(true), "Trees share their bough mesh")
	assert(boughs.surface_get_array_len(0) == 108 and boughs.get_aabb().size.y > 0.8, "Boughs retain a bounded tree silhouette and triangle budget")
	assert(Res.alpine_stone(0) == Res.alpine_stone(4), "Scree variants reuse four cached meshes")
	assert(Res.alpine_stone(0).surface_get_array_len(0) == 60)
	for variant in 4:
		var arrays := Res.alpine_stone(variant).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for j in vertices.size():
			assert(normals[j].dot(vertices[j]) > 0.0, "Stone faces point outward")
	assert(Res.alpine_stone(0).get_aabb() != Res.alpine_stone(1).get_aabb(), "Stone variants have distinct fractured profiles")
	assert(Mats.get_mat("alpine_stone").get_shader_parameter("stone_texture") is Texture2D, "Natural stones bind their photographic surface in merged batches")
	var surveyed: Resource = preload("res://assets/terrain/surveyed_alps.res")
	assert(int(surveyed.get_meta("width")) == 512)
	for name in ["mont_blanc", "matterhorn", "jungfrau"]:
		var heights: PackedFloat32Array = surveyed.get_meta(name)
		assert(heights.size() == 512 * 512)
		for value in heights:
			assert(is_finite(value) and value >= 0.0 and value <= 1.0)
		for edge in 512:
			assert(heights[edge] == 0.0 and heights[511 * 512 + edge] == 0.0)
			assert(heights[edge * 512] == 0.0 and heights[edge * 512 + 511] == 0.0, "Surveyed stamps must join without a vertical cut")
	var horizon := Atmosphere.backdrop_image(3)
	assert(horizon.get_size() == Vector2i(512, 512) and horizon.has_mipmaps() and horizon.get_format() == Image.FORMAT_RGF)
	assert(horizon.get_data() == Atmosphere.backdrop_image(3).get_data(), "Scenery is deterministic for every peer")
	assert(horizon.get_data() != Atmosphere.backdrop_image(4).get_data(), "Different maps have different mountain silhouettes")
	var runoff := PackedFloat32Array()
	runoff.resize(33 * 33)
	for z in 33:
		for x in 33:
			runoff[z * 33 + x] = absf(x - 16.0) + (32 - z) * 0.5
	var catchment := Landform.bake_drainage(runoff, 33)
	assert(catchment == Landform.bake_drainage(runoff, 33), "Catchment weathering is deterministic")
	assert(catchment[30 * 33 + 16] > catchment[4 * 33 + 16] + 0.2, "Gully weathering grows downstream")
	assert(catchment[24 * 33 + 16] > catchment[24 * 33 + 4] + 0.2, "Flow converges in the valley instead of crossing its walls")
	assert(runoff[0] == 32.0 and runoff[32 * 33 + 16] == 0.0, "Drainage baking preserves gameplay heights")
	runoff.fill(0.0)
	for value in Landform.bake_drainage(runoff, 33):
		assert(value == 0.0, "Flat ground has no arbitrary downhill streaks or wrapped edges")
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var world := World.new()
	world.srv = true
	world.settings = {"seed": 3}
	world.terrain = TerrainMap.new(world)
	world.water = WaterMap.new(world)
	var precise := TerrainMap.new(world)
	var slope := PackedFloat32Array()
	slope.resize(17 * 17)
	for z in 17:
		for x in 17:
			slope[z * 17 + x] = 100.001 + x * 0.011 + z * 0.017
	precise.install_landform(slope)
	for z in range(30, 36):
		for x in range(30, 36):
			var height := precise.dh[z * TerrainMap.DN + x]
			var drawn := precise.deform_img.get_pixel(x, z)
			assert(absf(drawn.r - height) < 0.00002 and absf(drawn.g - height) < 0.00002, "Elevated height textures must not quantize slopes into visible terraces")
	var dressing := Decor.new()
	dressing.build(world, [["alpine_stones", Vector3.ZERO, 0.0, 1.0]])
	var chunk: Node3D = dressing._chunks[Vector2i.ZERO]
	var fragments := chunk.get_node("FineStones")
	assert(fragments.get_child_count() > 0, "Small fragments are batched separately")
	for mesh: MeshInstance3D in fragments.get_children():
		assert(mesh.visibility_range_end == 180.0 and mesh.visibility_range_end_margin == 20.0)
	for child in chunk.get_children():
		if child is MeshInstance3D:
			assert(child.visibility_range_end == 0.0, "Large stones remain visible at distance")
	dressing.free()
	var previous_half := MapDims.HALF
	MapDims.HALF = 32.0
	world.terrain.landform.heights.resize(world.terrain.landform.n * world.terrain.landform.n)
	world.terrain.landform.heights.fill(8.0)
	world.terrain.landform.peak = 30.0
	var scatter_a: Array = []
	var scatter_b: Array = []
	var gen := MapGen.new(world)
	gen._alpine_scatter(scatter_a, 1.0)
	gen._alpine_scatter(scatter_b, 1.0)
	assert(not scatter_a.is_empty() and scatter_a.size() <= 65, "Dressing is bounded and populated")
	assert(scatter_a == scatter_b, "Dressing placement is seeded independently of simulation RNG")
	for entry in scatter_a:
		assert(is_equal_approx(entry[1].y, 7.92), "Dressing follows the authoritative ground")
	for z in world.terrain.landform.n:
		for x in world.terrain.landform.n:
			world.terrain.landform.heights[z * world.terrain.landform.n + x] = 8.0 + x * 2.4
	assert(not gen._is_free(Vector3.ZERO, Vector2(0.6, 0.6), 0.0), "Building foundations still require level ground")
	assert(gen._is_free(Vector3.ZERO, Vector2(0.6, 0.6), 0.0, 0.6, true, 0.7), "Tree roots can occupy a moderate slope")
	assert(absf(gen._contour(Vector3.ZERO).x) < 0.01, "Woodland follows the contour rather than running straight uphill")
	var town := TownGen.new(gen)
	check_driveway_crossings(world, gen)
	town._d("lamp", Vector3(0, 2, 0))
	assert(is_equal_approx(town.decor[0][1].y, world.terrain.landform.height(Vector3.ZERO) + 2.0))
	var wire := [Vector3(4, 0, 0), 0.0]
	town._d("wire", Vector3.ZERO, 0.0, wire)
	assert(wire[0].y == 0.0, "Grounding must not mutate the generator's endpoint array")
	assert(is_equal_approx(town.decor[1][3][0].y, world.terrain.landform.height(Vector3(4, 0, 0))))
	town._d("drop", Vector3(0, 7, 0), 0.0, Vector3(4, 2.85, 0))
	assert(is_equal_approx(town.decor[2][3].y, world.terrain.landform.height(Vector3(4, 0, 0)) + 2.85))
	assert(World._unpack(World._pack(town.decor)) == town.decor, "Town elevations survive map transfer and replay serialization")
	town.decor.clear()
	town._front_fence(Vector3.ZERO, Vector3.BACK, Vector3.RIGHT, 14.0, 1.0, -4.0, 0)
	for entry in town.decor:
		var center: Vector3 = entry[1]
		var size: Vector3 = entry[3]
		assert(size.x <= 2.2, "Fences have bounded breakable sections")
		for opening in [Vector2(0.2, 1.8), Vector2(-5.4, -2.6)]:
			assert(center.x + size.x * 0.5 <= opening.x + 0.001 or center.x - size.x * 0.5 >= opening.y - 0.001, "Fences leave paths and drives open")
	town.decor.clear()
	var gate := town._approach(Vector3.ZERO, Vector3.BACK, Vector3.RIGHT, Vector3(4, 0, 5), 0.0, 2.0, 12.0)
	assert(gate > 4.5 and town.decor.size() == 2, "Side-door paths go around the house before turning toward its door")
	var paving := Decor.new()
	paving.world = world
	paving._at.origin.y = world.terrain.landform.height(Vector3.ZERO)
	var paved := paving._paving_mesh(Res.box(Vector3(12, 0.1, 3)), Transform3D.IDENTITY)
	var paved_vertices: PackedVector3Array = paved.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(paved_vertices.size() > 24, "Long paving is subdivided to follow grades")
	for vertex in paved_vertices:
		var point := paving._at * vertex
		assert(absf(absf(point.y - world.terrain.landform.height(point)) - 0.05) < 0.001, "Paving follows the local geology without a floating centre")
	world.terrain.landform.heights.fill(12.0)
	paving._at.origin.y = 12.0
	var flat_paving := paving._paving_mesh(Res.box(Vector3(2, 0.1, 2)), Transform3D.IDENTITY)
	var flat_normals: PackedVector3Array = flat_paving.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in flat_normals:
		assert(is_equal_approx(normal.length(), 1.0) and (absf(normal.x) > 0.999 or absf(normal.y) > 0.999 or absf(normal.z) > 0.999), "Flat paving keeps face normals distinct at slab corners")
	paving.free()
	MapDims.HALF = previous_half
	world.terrain.landform.heights = PackedFloat32Array()
	world.terrain.landform.peak = 0.0
	var atmosphere := Atmosphere.new()
	var old_lod: int = Settings.get_v("lod")
	Settings.v.lod = 0
	var low_ring := atmosphere._ground_ring(32.0, 64.0)
	Settings.v.lod = 2
	var high_ring := atmosphere._ground_ring(32.0, 64.0)
	Settings.v.lod = old_lod
	var ring_data: Array = high_ring.surface_get_arrays(0)
	assert(high_ring.get_aabb() == low_ring.get_aabb(), "Detail settings preserve scenery boundaries")
	assert(high_ring.surface_get_array_len(0) > low_ring.surface_get_array_len(0), "Low detail retains the cheaper scenery mesh")
	assert(ring_data[Mesh.ARRAY_INDEX].size() > ring_data[Mesh.ARRAY_VERTEX].size(), "Scenery shares vertices rather than duplicating triangle corners")
	atmosphere.world = world
	atmosphere._surface_baked = true
	var reflections_before: bool = Settings.get_v("terrain_reflections")
	Settings.v.terrain_reflections = true
	atmosphere._update_terrain_probe()
	var capture := atmosphere._terrain_probe
	assert(capture != null and capture.cull_mask == 4 and capture.update_mode == ReflectionProbe.UPDATE_ONCE, "Reflections capture static terrain once")
	atmosphere._update_terrain_probe()
	assert(atmosphere._terrain_probe == capture, "Steady settings reuse the capture")
	atmosphere._update_terrain_probe(true)
	assert(atmosphere._terrain_probe != capture, "Lighting changes refresh the capture")
	Settings.v.terrain_reflections = false
	atmosphere._update_terrain_probe()
	assert(atmosphere._terrain_probe == null, "Disabling reflections releases the probe")
	Settings.v.terrain_reflections = reflections_before
	var haze_before: bool = Settings.get_v("alpine_haze")
	atmosphere.env = Environment.new()
	atmosphere.ground_mat = ShaderMaterial.new()
	var ground_shader := Shader.new()
	ground_shader.code = CloudShadow.shader(MapDims.shader(Atmosphere.GROUND_SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT)), CloudShadow.OWN_LIGHT)
	atmosphere.ground_mat.shader = ground_shader
	atmosphere._d = {"fog_d": 0.002}
	world.terrain.landform.peak = 80.0
	Settings.v.alpine_haze = true
	atmosphere._apply_haze(600.0)
	assert(atmosphere.env.fog_aerial_perspective > 0.0 and atmosphere.env.fog_height_density > 0.0, "Alpine haze adds sky tint and a valley veil")
	assert(float(atmosphere.ground_mat.get_shader_parameter("terrain_air")) > 0.0)
	Settings.v.alpine_haze = false
	atmosphere._apply_haze(600.0)
	assert(float(atmosphere.ground_mat.get_shader_parameter("terrain_air")) == 0.0)
	assert(atmosphere.env.fog_aerial_perspective == 0.0 and atmosphere.env.fog_height_density == 0.0, "Disabling alpine haze clears both additions")
	Settings.v.alpine_haze = true
	world.terrain.landform.peak = 0.0
	atmosphere._apply_haze(600.0)
	assert(atmosphere.env.fog_height_density == 0.0, "Flat scenarios retain their existing atmosphere")
	Settings.v.alpine_haze = haze_before
	atmosphere.free()
	var geology := Landform.new(64)
	geology.generate(3, [[], [], []], world.water, [])
	var repeat := Landform.new(64)
	repeat.generate(3, [[], [], []], world.water, [])
	assert(geology.heights == repeat.heights, "Seeded terrain must reproduce exactly")
	repeat.drainage = PackedFloat32Array([1.0])
	repeat.generate(9, [[], [], []], world.water, [])
	assert(repeat.drainage.is_empty(), "Regenerating a map invalidates its drainage")
	assert(geology.heights != repeat.heights, "Seeds must produce different terrain")
	assert(Landform.valid(geology.heights, 64))
	var campaign := Landform.new(64)
	campaign.generate(3, [[], [], []], world.water, [], false)
	assert(campaign.heights != geology.heights and Landform.valid(campaign.heights, 64), "Campaigns retain their authored relief recipe")
	var foothills := Landform.new(1024)
	foothills.generate(3, [[], [], []], world.water, [])
	assert(foothills.peak > 25.0 and foothills.peak < 140.0, "Playable skirmish terrain retains relief without towering foreground peaks")
	assert(not Landform.valid(PackedFloat32Array([NAN]), 64))
	var invalid := geology.heights.duplicate()
	invalid[0] = INF
	assert(not Landform.valid(invalid, 64))
	var forms_a := Landform.new(256)
	forms_a.heights.resize(forms_a.n * forms_a.n)
	forms_a.heights.fill(80.0)
	var forms_b := Landform.new(256)
	forms_b.heights = forms_a.heights.duplicate()
	forms_a._place_forms(3)
	forms_b._place_forms(3)
	assert(forms_a.heights == forms_b.heights, "Baked rock forms place deterministically")
	assert(Array(forms_a.heights).min() < 75.0 and Array(forms_a.heights).max() > 85.0, "Forms carve valleys and build rock masses, not just recolour ground")
	assert(Landform.valid(forms_a.heights, 256))
	for name in ["buttress", "cirque", "saddle"]:
		var form: PackedFloat32Array = Landform.FORMS.get_meta(name)
		assert(form.size() == 33 * 33 and Array(form).min() >= 0.0 and Array(form).max() <= 1.0)
	for name in ["rock_face_03", "aerial_rocks_02", "aerial_grass_rock"]:
		for suffix in ["color_height", "surface"]:
			var tex: Texture2D = load("res://assets/terrain/%s_%s.png" % [name, suffix])
			var img := tex.get_image()
			assert(img.get_size() == Vector2i(1024, 1024) and img.has_mipmaps(), "Packed relief textures keep distance filtering")
			assert(img.get_format() == Image.FORMAT_RGBA8, "Height and roughness alpha must survive import")
	var corridor := Landform.new(256)
	corridor.generate(3, [[PackedVector3Array([Vector3(-100, 0, 0), Vector3(100, 0, 0)])]], world.water, [[Vector3(0, 0, 60), 12.0]])
	assert(corridor.peak > 5.0, "Reserved maps still contain hills")
	for x in range(-100, 97, 4):
		var here := corridor.height(Vector3(x, 0, 0))
		assert(absf(corridor.height(Vector3(x + 4, 0, 0)) - here) < 0.5, "Roads have a continuous graded corridor: %.2f m to %.2f m at x=%d" % [here, corridor.height(Vector3(x + 4, 0, 0)), x])
		assert(absf(corridor.height(Vector3(x, 0, 3)) - here) < 0.3 and absf(corridor.height(Vector3(x, 0, -3)) - here) < 0.3, "Roads lie level across their carriageway")
	assert(corridor.fits(Vector3(0, 0, 60), Vector2(10, 10), 0.0), "Settlements retain level building ground")
	var coastal_water := WaterMap.new(world)
	coastal_water.coast = {"x": 40.0, "s": 3.0}
	var coast := Landform.new(256)
	coast.generate(3, [], coastal_water, [], false)
	for z in range(-100, 101, 4):
		var shore := coastal_water.coast_x(z)
		for x in range(ceili(shore / 4.0) * 4 + 4, 124, 4):
			assert(is_zero_approx(coast.height(Vector3(x, 0, z))), "Sediment must not lift the landing boats' seabed")
	assert(is_zero_approx(corridor.height(Vector3(0, 0, 60))), "Settlements sit on the valley's level floor")
	var floor_low := INF
	var floor_high := -INF
	for z in range(-100, 101, 25):
		var h := corridor.height(Vector3(-100, 0, z))
		floor_low = minf(floor_low, h)
		floor_high = maxf(floor_high, h)
	assert(floor_high - floor_low > 0.8, "Skirmish valley floors roll rather than lie planed: %.2f m" % (floor_high - floor_low))
	# A known ridge separates two level firing positions, with a gentle west ramp.
	var heights := PackedFloat32Array()
	heights.resize(17 * 17)
	for z in 17:
		for x in 17:
			var wx := x * 4.0 - 32.0
			heights[z * 17 + x] = 12.0 * maxf(0.0, 1.0 - absf(wx) / 12.0)
	var flat := Landform.new(64).bake_surface()
	assert(flat.get_pixel(3, 3).r > 0.99 and absf(flat.get_pixel(3, 3).g - 0.5) < 0.01, "Flat terrain has open sky and no concavity")
	assert(flat.get_format() == Image.FORMAT_RGBA8 and flat.get_pixel(3, 3).a == 0.0, "Flat terrain has no drainage weathering")
	# Skirmish rock carries crag relief finer than the 4 m grid: the same on every
	# peer, absent from campaign ground, and invisible to slopes and routes.
	var crag_heights := PackedFloat32Array()
	crag_heights.resize(17 * 17)
	for z in 17:
		for x in 17:
			crag_heights[z * 17 + x] = 40.0 * maxf(0.0, 1.0 - absf(x * 4.0 - 32.0) / 24.0)
	var crag_a := Landform.new(64)
	crag_a.heights = crag_heights.duplicate()
	crag_a.prepare_crags(true)
	var crag_b := Landform.new(64)
	crag_b.heights = crag_heights.duplicate()
	crag_b.prepare_crags(true)
	var rough := 0.0
	for k in 16:
		var q := Vector3(-14.0 + k * 0.25, 0, 3.0)
		assert(crag_a.height(q) == crag_b.height(q), "Crag relief is deterministic")
		rough = maxf(rough, absf(crag_a.height(q) - crag_a.smooth_height(q)))
	assert(rough > 0.15, "Bare rock carries relief finer than the grid: %.3f m" % rough)
	assert(is_equal_approx(crag_a.slope(Vector3(-12, 0, 3)), 40.0 / 24.0), "Crags do not change slopes for movement")
	var authored := Landform.new(64)
	authored.heights = crag_heights.duplicate()
	authored.prepare_crags(false)
	assert(authored.height(Vector3(-12, 0, 3)) == authored.smooth_height(Vector3(-12, 0, 3)), "Campaign ground stays as authored")
	assert(crag_a.height(Vector3(-30, 0, 3)) == crag_a.smooth_height(Vector3(-30, 0, 3)), "Level ground takes no crags")
	world.terrain.landform.drainage = PackedFloat32Array([1.0])
	world.terrain.install_landform(heights, false)  # (a smooth ridge: exact sight and sampling checks)
	assert(world.terrain.landform.drainage.is_empty(), "Installing a map invalidates the old catchment cache")
	var baked := world.terrain.landform.bake_surface()
	assert(baked.get_data() == world.terrain.landform.bake_surface().get_data(), "Surface baking is deterministic")
	assert(world.terrain.landform.heights == heights, "Baking must not change gameplay geography")
	assert(baked.get_pixel(2, 4).r < 0.97, "A nearby ridge reduces valley sky light")
	var low_sun := world.terrain.landform.bake_surface(Vector3(1, 0.3, 0).normalized())
	for z in baked.get_height():
		for x in baked.get_width():
			assert(baked.get_pixel(x, z).a == low_sun.get_pixel(x, z).a, "Changing sunlight preserves drainage")
	assert(low_sun.get_pixel(2, 4).b < 0.1 and low_sun.get_pixel(6, 4).b > 0.9, "Baked sunlight casts a ridge shadow on its sheltered side")
	assert(is_equal_approx(world.ground_y(Vector3.ZERO), 11.75))
	var hit := world.terrain.ray_ground(Vector3(-20, 1.5, 0), Vector3(20, 1.5, 0))
	assert(not hit.is_empty() and hit.position.x < 0.0, "A ridge must block sight and bullets")
	assert(world.terrain.ray_ground(Vector3(-20, 15, 0), Vector3(20, 15, 0)).is_empty())
	world.rules = Rules.new(world)
	var enemy := Soldier.new()
	enemy.world = world
	enemy.team = 1
	enemy.position = Vector3(20, 0, 0)
	var observers := [{}, {}]
	world.rules._add_obs(observers[0], Vector3(-20, 1.5, 0), 60.0)
	world.rules._vis_ent(enemy, observers)
	assert((enemy.vis_mask & 1) == 0, "Fog of war must not reveal enemies through ridges")
	enemy.free()
	assert(not world.terrain.landform.fits(Vector3(-8, 0, 0), Vector2(3, 3), 0.0))
	assert(world.terrain.landform.fits(Vector3(-24, 0, 0), Vector2(2, 2), 0.0))
	world.nav = Nav.new()
	world.nav.terrain = world.terrain
	var steep := world.terrain.idx_of(Vector3(-8, 0, 0))
	world.nav.terrain_changed(steep)
	assert(not world.nav.walkable(Vector3(-8, 0, 0)))
	assert(world.nav.vkind_at(Vector3(-8, 0, 0)) == Nav.SOLID)
	var soldier := Soldier.new()
	soldier.world = world
	soldier.position = Vector3(0, 0, 0)
	for i in 90:
		soldier._settle_y(1.0 / 30.0)
	assert(absf(soldier.position.y - world.ground_y(soldier.position)) < 0.01, "Infantry settle onto a ridge")
	soldier.position.x = -5.0
	for i in 90:
		soldier._settle_y(1.0 / 30.0)
	assert(absf(soldier.position.y - world.ground_y(soldier.position)) < 0.01, "Infantry update height after moving downhill")
	soldier.dive_t = 0.5
	soldier.dive_dir = Vector3.ZERO
	soldier._alive(1.0 / 30.0)
	assert(soldier.position.y >= world.ground_y(soldier.position), "Diving infantry cannot sink into elevated ground")
	soldier.free()
	var truck := Vehicle.new()
	truck.world = world
	truck.vkind = "supply"
	truck.position = Vector3(-13, 0, 0)
	world.nav.terrain_changed(world.terrain.idx_of(Vector3(-11, 0, 0)))
	truck._move_by(Vector3(2, 0, 0), 1.0)
	assert(truck.position.x <= -12.0, "Supply trucks cannot bypass an impassable mountain slope")
	# Give the hull a real elevated plateau, rather than a knife-edge ridge.
	var plateau := World.new()
	plateau.srv = true
	plateau.settings = {"seed": 3}
	plateau.terrain = TerrainMap.new(plateau)
	plateau.water = WaterMap.new(plateau)
	var level := heights.duplicate()
	level.fill(12.0)
	plateau.terrain.install_landform(level)
	plateau.nav = Nav.new()
	plateau.nav.terrain = plateau.terrain
	truck.world = plateau
	truck.position = Vector3(0, 12, 0)
	plateau.nav.terrain_changed(plateau.terrain.idx_of(Vector3(0, 0, 2)))
	truck._move_by(Vector3(0, 0, 2), 1.0)
	assert(truck.position.z > 1.9 and is_equal_approx(truck.position.y, 12.0), "Vehicles traverse level elevated ground")
	truck.free()
	plateau.free()
	var heli := Vehicle.new()
	heli.world = world
	heli.vkind = "hummingbird"
	heli.vdef = {"speed": 22.0, "turn": 1.8}
	heli.flight = HelicopterFlight.new()
	heli.position = Vector3(-24, 16, 0)
	var crossed := false
	for i in 30 * 45:
		heli._fly_to(Vector3(24, 16, 0), 1.0 / 30.0)
		assert(heli.position.y >= world.ground_y(heli.position) + 0.14, "Rotorcraft must stay above a crossed ridge")
		crossed = crossed or heli.position.x > 20.0
	assert(crossed, "Terrain clearance must not strand a helicopter in its climb")
	heli.position = Vector3(0, 25, 0)
	heli.velocity = Vector3.ZERO
	for i in 30 * 12:
		heli._fly_to(Vector3(0, world.ground_y(Vector3.ZERO) + 0.15, 0), 1.0 / 30.0)
	assert(absf(heli.position.y - world.ground_y(heli.position) - 0.15) < 0.02, "Touchdown is relative to elevated terrain")
	heli.free()
	var trench := Structure.new()
	trench.eid = 101
	trench.skind = "trench"
	trench.built = true
	trench.position = Vector3(0, 12, 0)
	trench.size = Vector3(6, 3, 3.2)
	trench.foot = Vector2(3, 1.6)
	world._shash_add(trench)
	assert(is_equal_approx(world.ground_y(Vector3.ZERO), 12.0 + TrenchNet.FLOOR_Y + 0.15), "Trenches are dug below local ground")
	world.combat = ClearCombat.new(world)
	var frag := Projectile.new()
	frag.world = world
	frag.ptype = "frag"
	frag.fuse = 100.0
	frag.flying = true
	frag.position = Vector3(0, 13, 0)
	for i in 120:
		frag._ballistic(1.0 / 30.0)
	assert(absf(frag.position.y - world.ground_y(frag.position) - 0.06) < 0.01, "Grenades settle on the elevated trench floor")
	frag.free()
	world._shash_remove(trench)
	trench.free()
	var shell := Projectile.new()
	shell.world = world
	shell.srv = true
	shell.ptype = "mortar"
	shell.target = Vector3.ZERO
	shell.on_spawned()
	assert(is_equal_approx(shell.get_props().target.y, world.ground_y(Vector3.ZERO)), "Shell elevation is set before its trajectory is replicated")
	shell.free()
	var before := world.ground_y(Vector3.ZERO)
	world.terrain.add_crater(Vector3(0, before, 0), 2.0)
	var after := world.ground_y(Vector3.ZERO)
	assert(after < before and after > before - 1.5, "Shells dig relative to the ridge, not down to sea level")
	assert(is_equal_approx(world.terrain.landform.height(Vector3.ZERO), 12.0))
	# The network representation must preserve the exact geology, not regenerate a new seed.
	var restored: PackedFloat32Array = World._unpack(World._pack(heights))
	assert(restored == heights)
	world.free()
	for kind in ["asphalt", "pavement", "turf", "roof_tile", "roof_concrete", "fence_wood", "fence_rail", "brick", "plaster", "bark", "concrete", "concrete_floor", "wood", "wood_dark", "curbstone"]:
		var photo: Texture2D = Mats.get_mat(kind).get_shader_parameter("photo_color")
		var surface: Texture2D = Mats.get_mat(kind).get_shader_parameter("photo_surface")
		assert(photo != null and surface != null, "Town scans ship with colour and normal/roughness maps")
		assert(photo.get_image().has_mipmaps() and surface.get_image().has_mipmaps(), "Town scans filter with distance")
	assert(Mats.paving("asphalt").get_shader_parameter("pattern") == Mats.ASPHALT, "Junction shader preserves its asphalt pattern")
	assert(Mats.paving("asphalt").get_shader_parameter("crater_cut") == true, "Asphalt junctions retain crater cutouts")
	assert(Mats.paving("pavement").get_shader_parameter("grime") == 0.0, "Horizontal paving must not inherit ground-height wall grime")
	print("LANDFORM passed: generation, determinism, validation, grounding, sight, slope navigation, craters, replication")
	get_tree().quit()


func check_driveway_crossings(world, gen: MapGen) -> void:
	for yaw: float in [0.0, 0.7, PI]:
		var along := Basis(Vector3.UP, yaw).x
		var away := Basis(Vector3.UP, yaw).z
		var town := TownGen.new(gen)
		town._d("walk", away * ((TownGen.CURB + TownGen.WALK) * 0.5), yaw, Vector3(16, 0.12, 1.8))
		town._d("curb", away * (TownGen.CURB + 0.09), yaw, Vector3(16, 0.17, 0.18))
		town._d("walk", -away * ((TownGen.CURB + TownGen.WALK) * 0.5), yaw, Vector3(16, 0.12, 1.8))
		town._d("walk", away * ((TownGen.CURB + TownGen.WALK) * 0.5), yaw + PI * 0.5, Vector3(16, 0.12, 1.8))
		var untouched := town.decor.slice(2).duplicate(true)
		var rng_before := gen.rng.state
		assert(town._curb_crossing(away * TownGen.FRONT + along, away, along, 2.6))
		assert(town.decor[2] == untouched[0] and town.decor[3] == untouched[1], "Crossings preserve the opposite and perpendicular sidewalks")
		assert(gen.rng.state == rng_before, "Driveway presentation must not change the generated battle")
		for kind in ["walk", "curb"]:
			var length := 0.0
			var spans: Array[Vector2] = []
			for entry: Array in town.decor:
				if entry == town.decor[2] or entry == town.decor[3]:
					continue
				if entry[0] != kind and entry[0] != kind + "_crossing":
					continue
				var size: Vector3 = entry[3] if entry[3] is Vector3 else entry[3][0]
				var center: float = entry[1].dot(along)
				length += size.x
				spans.append(Vector2(center - size.x * 0.5, center + size.x * 0.5))
				assert(is_equal_approx(entry[1].y, world.terrain.landform.height(entry[1])), "Split paving is grounded exactly once")
			spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			assert(is_equal_approx(length, 16.0) and spans.size() == 3)
			for i in 2:
				assert(is_equal_approx(spans[i].y, spans[i + 1].x), "A driveway must leave no gap or overlap in the sidewalk")
		assert(town._curb_crossing(away * TownGen.FRONT + along * 7.4, away, along, 2.6), "Crossings can end at a sidewalk boundary")
		assert(World._unpack(World._pack(town.decor)) == town.decor, "Lowered crossings survive map transfer")
		world.decor = town.decor
		var atmosphere := Atmosphere.new()
		atmosphere.world = world
		var grass := Grass.new()
		grass.atmo = atmosphere
		var blocked := grass._blocked_job()
		for entry: Array in town.decor:
			if entry[0] == "walk_crossing":
				var point: Vector3 = entry[1]
				assert(blocked.boxes.any(func(box: Array) -> bool: return box[0] == Vector2(point.x, point.z)), "Grass must not grow through a lowered sidewalk")
		grass.free()
		atmosphere.free()
		var paving := Decor.new()
		paving.world = world
		for entry: Array in town.decor:
			if entry[0] != "walk_crossing" and entry[0] != "curb_crossing":
				continue
			var size: Vector3 = entry[3][0]
			var lowered: Vector2 = entry[3][1]
			paving._at = Transform3D(Basis(Vector3.UP, yaw), entry[1])
			var local := Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0))
			var mesh := paving._paving_mesh(Res.box(size), local, lowered)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				assert(vertices[i].is_finite() and is_equal_approx(normals[i].length(), 1.0))
				if normals[i].y < 0.5:
					continue
				var point := paving._at * local * vertices[i]
				var shoulder := maxf(lowered.x - vertices[i].x, vertices[i].x - lowered.y)
				var expected := lerpf(0.03, size.y, clampf(shoulder / 0.6, 0.0, 1.0))
				assert(absf(point.y - world.terrain.landform.height(point) - expected) < 0.001, "Lowered paving joins the driveway with sloping shoulders")
		paving.free()
	var country := TownGen.new(gen)
	assert(not country._curb_crossing(Vector3.ZERO, Vector3.BACK, Vector3.RIGHT, 2.6), "Country drives do not invent urban sidewalks")
