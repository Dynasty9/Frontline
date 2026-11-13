extends Node

class ProbeGrass extends Grass:
	func _build_chunk(c: Vector2i) -> void:
		_built[c] = []

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var grass := Grass.new()
	var blades := grass._make_clump().surface_get_arrays(0)
	var vertices: PackedVector3Array = blades[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = blades[Mesh.ARRAY_TEX_UV]
	check(vertices.size() == 270, "Fine grass retains the 90-triangle clump budget")
	for i in range(0, vertices.size(), 9):
		check(vertices[i].y == 0.0 and vertices[i + 1].y == 0.0 and uv[i].y == 0.0, "Grass roots stay on the terrain with zero wind weight")
		check(vertices[i + 8].y > 0.17 and vertices[i + 8].y < 0.56 and uv[i + 8].y == 1.0, "Pointed tips retain full wind weight and varied heights")
		check(vertices[i].distance_to(vertices[i + 1]) < 0.033, "Grass blades keep a natural centimetre scale")
	var leaves: PackedVector3Array = grass._make_bush().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(leaves.size() == 480, "Shrubs use a bounded 160-triangle small-leaf canopy")
	for i in range(0, leaves.size(), 6):
		check(leaves[i].distance_to(leaves[i + 2]) <= 0.301, "Shrub branches keep their leaves at a natural scale")
	grass.HALF = 1536.0
	grass._stream(Vector3.ZERO)
	check(grass._queue.size() == 225, "Large maps must queue only nearby cosmetic chunks")
	check(grass._queue.front() == Vector2i.ZERO, "Nearest grass must build first")
	for key in grass._queue:
		grass._built[key] = []
	grass._queue.clear()
	grass._stream(Vector3(32, 0, 0))
	check(grass._queue.size() == 15, "Panning one chunk must reuse resident grass")
	grass._stream(Vector3(1400, 0, 1400))
	check(grass._built.is_empty() and grass._queue.size() <= 225, "Distant chunks must be evicted and new work bounded")
	for key: Vector2i in grass._queue:
		check(key.x < 48 and key.y < 48, "Streaming must stay inside map bounds")
	grass._clear()
	grass._stream(Vector3.ZERO)
	check(grass._queue.size() == 225, "Settings rebuilds must repopulate the current camera area")
	var world := World.new()
	world.decor = [["yard", Vector3.ZERO, 0.0, Vector3(10, 0.015, 8)]]
	var atmosphere := Atmosphere.new()
	atmosphere.world = world
	grass.atmo = atmosphere
	var blocked := grass._blocked_job()
	check(blocked.boxes.size() == 1 and blocked.boxes[0][1] == Vector2(5.2, 4.2), "Maintained yards exclude wild grass and shrubs")
	var bunker := Structure.new()
	bunker.skind = "bunker"
	bunker.position = Vector3(20, 40, 20)
	bunker.foot = Vector2(3, 3)
	bunker.yaw = 0.7
	world.structures.append(bunker)
	var earthworks := grass._blocked_job()
	earthworks.run()
	var bank_edge := bunker.position + Basis(Vector3.UP, bunker.yaw) * Vector3(4.6, 0, 0)
	var bank_x := floori(bank_edge.x) + (MapDims.N >> 1)
	var bank_z := floori(bank_edge.z) + (MapDims.N >> 1)
	check(earthworks.blocked[bank_z * MapDims.N + bank_x] == 1, "Bunker spoil excludes plants outside the walls at rotated headings")
	var meadow := bunker.position + Vector3(9, 0, 0)
	check(earthworks.blocked[(floori(meadow.z) + (MapDims.N >> 1)) * MapDims.N + floori(meadow.x) + (MapDims.N >> 1)] == 0, "The earthwork clearing preserves nearby meadow")
	world.structures.erase(bunker)
	bunker.free()
	world.atmo = atmosphere
	atmosphere.grass = grass
	world.building = false
	for authoritative in [false, true]:
		world.srv = authoritative
		var placed := Structure.new()
		placed.world = world
		placed.eid = 81 if authoritative else 80
		placed.skind = "bunker"
		placed.foot = Vector2(3,3)
		world.add_child(placed)
		grass._rebuild_t = -1.0
		world._register(placed)
		world._shash_add(placed)
		check(grass._rebuild_t > 0.0, "Placing a bunker refreshes resident plants on hosts and clients")
		grass._rebuild_t = -1.0
		world.despawn(placed)
		check(grass._rebuild_t > 0.0, "Removing a bunker refreshes its old vegetation footprint")
		await get_tree().process_frame
		world._graveyard.clear()
		placed.free()
	var street := Grass.BlockedJob.new()
	street.roads = [PackedVector3Array([Vector3(-8, 0, 0), Vector3(8, 0, 0)])]
	street.run()
	var centre := MapDims.N >> 1
	check(street.blocked[(centre + 3) * MapDims.N + centre] == 1, "Road shoulders exclude overhanging grass clumps")
	check(street.blocked[(centre + 6) * MapDims.N + centre] == 0, "Road exclusion preserves the surrounding meadow")
	world.terrain = TerrainMap.new(world)
	check_visible_stream(atmosphere)
	world.terrain.landform.peak = 40.0
	atmosphere.biome_img = Image.create(1, 1, false, Image.FORMAT_RF)
	world.terrain.landform.peak = 100.0
	world.terrain.landform.heights.resize(world.terrain.landform.n * world.terrain.landform.n)
	world.terrain.landform.heights.fill(40.0)
	world.terrain.dh.fill(40.0)
	check(atmosphere.grass_amount(Vector3.ZERO) > 0.5, "Sheltered lower slopes retain meadow cover")
	world.terrain.landform.heights.fill(54.0)
	check(atmosphere.grass_amount(Vector3.ZERO) == 0.0, "Meadow grass stops below the snow line")
	world.terrain.landform.heights.fill(40.0)
	world.terrain.landform.peak = 500.0
	var box := BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded; void vertex() { VERTEX.y += 40.0; } void fragment() { ALBEDO = vec3(1.0, 0.0, 0.0); }"
	var elevated := grass._mm(box, material, [Transform3D.IDENTITY], [Color.WHITE], 105.0)
	check(elevated.multimesh.custom_aabb.end.y >= 40.5, "Grass culling bounds include the shader's terrain displacement")
	check(absf(elevated.multimesh.custom_aabb.get_center().y - 40.0) < 1.0, "A distant mountain must not shift this meadow's visibility distance")
	if DisplayServer.get_name() != "headless":
		var view := SubViewport.new()
		view.size = Vector2i(64, 64)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		grass.remove_child(elevated)
		view.add_child(elevated)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.0
		view.add_child(camera)
		camera.position = Vector3(0, 40, 4)
		camera.look_at(Vector3(0, 40, 0))
		for frame in 4:
			await RenderingServer.frame_post_draw
		var pixel := view.get_texture().get_image().get_pixel(32, 32)
		check(pixel.r > 0.9 and pixel.g < 0.1, "Elevated grass survives native frustum culling")
		view.queue_free()
	if DisplayServer.get_name() != "headless":
		world.terrain.dh.fill(40.0)
		world.terrain.landform.peak = 100.0
		world.terrain.landform.heights.fill(54.0)
		world.settings = {"seed": 3}
		atmosphere.biome_img = Image.create(1, 1, false, Image.FORMAT_RF)
		grass.level = 2
		grass._blocked.resize(MapDims.N * MapDims.N)
		grass._blocked.fill(0)
		grass.clump = grass._make_clump()
		grass.bush = grass.clump
		grass.stone = grass._make_stone()
		grass.mat = material
		grass.bush_mat = material
		grass.stone_mat = ShaderMaterial.new()
		var stones := 0
		for cell in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]:
			grass._build_chunk(cell)
			for node: MultiMeshInstance3D in grass._built[cell]:
				check(node.material_override != grass.mat, "A zero habitat must not leak a four-percent grass population into snow")
				if node.material_override == grass.stone_mat:
					for i in node.multimesh.instance_count:
						var point := node.multimesh.get_instance_transform(i).origin
						check(point.y > 40.0 and point.y < 40.2, "Cosmetic stones rest on elevated ground instead of sea level")
						stones += 1
		check(stones > 0, "The seeded fixture includes cosmetic stones")
	world.settings = {"seed": 3}
	world.terrain.landform.heights.fill(0.0)
	world.terrain.dh.fill(0.0)
	grass._clear()
	grass.level = 2
	grass.HALF = MapDims.HALF
	grass._blocked.resize(MapDims.N * MapDims.N)
	grass._blocked.fill(0)
	grass.clump = grass._make_clump()
	grass.bush = grass._make_bush()
	grass.stone = grass._make_stone()
	grass.mat = material
	grass.bush_mat = ShaderMaterial.new()
	grass.bush_mat.shader = material.shader
	grass.stone_mat = ShaderMaterial.new()
	grass._shrub_noise.seed = 222
	grass._shrub_noise.frequency = 0.035
	var rng_before := world.rng.state
	var snapshots: Array[PackedByteArray] = []
	var sparse := 1024
	var dense := 0
	for repeat in 2:
		var placements := []
		for x in 4:
			for z in 4:
				var key := Vector2i(x, z)
				grass._build_chunk(key)
				var count := 0
				for node: MultiMeshInstance3D in grass._built[key]:
					if node.material_override == grass.bush_mat:
						count += node.multimesh.instance_count
						for i in node.multimesh.instance_count:
							placements.append(node.multimesh.get_instance_transform(i))
				sparse = mini(sparse, count)
				dense = maxi(dense, count)
		snapshots.append(var_to_bytes(placements))
		grass._clear()
	check(dense > 12 and sparse < dense / 3, "Shrub habitat produces connected patches and open ground instead of even scatter")
	check(snapshots[0] == snapshots[1] and world.rng.state == rng_before, "Cosmetic habitat rebuilds reproduce the same shrubs without advancing gameplay RNG")
	grass.free()
	atmosphere.free()
	world.free()
	print("GRASS_STREAM_TEST failures=%d" % failures)
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func check_visible_stream(atmo: Atmosphere) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1024, 768)
	add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(16, 3, 16)
	var grass := ProbeGrass.new()
	grass.atmo = atmo
	grass._stream(camera.position)
	grass._build_visible(camera)
	check(grass._built.has(Vector2i(0, -3)) and not grass._built.has(Vector2i(0, 3)), "First draw must build the visible meadow before off-screen cells")
	camera.rotation.y = PI
	grass._build_visible(camera)
	check(grass._built.has(Vector2i(0, 3)), "Turning in the same chunk must fill the new view in one pass")
	camera.position.x += 352.0
	grass._stream(camera.position)
	grass._build_visible(camera)
	check(grass._built.has(Vector2i(11, 3)) and not grass._built.has(Vector2i(0, 3)), "A camera cut must fill the destination and evict the previous meadow")
	grass.free()
	view.free()
