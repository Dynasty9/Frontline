extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var grass := Grass.new()
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
	var street := Grass.BlockedJob.new()
	street.roads = [PackedVector3Array([Vector3(-8, 0, 0), Vector3(8, 0, 0)])]
	street.run()
	var centre := MapDims.N >> 1
	check(street.blocked[(centre + 3) * MapDims.N + centre] == 1, "Road shoulders exclude overhanging grass clumps")
	check(street.blocked[(centre + 6) * MapDims.N + centre] == 0, "Road exclusion preserves the surrounding meadow")
	world.terrain = TerrainMap.new(world)
	world.terrain.landform.peak = 40.0
	atmosphere.biome_img = Image.create(1, 1, false, Image.FORMAT_RF)
	world.terrain.landform.peak = 100.0
	world.terrain.landform.heights.resize(world.terrain.landform.n * world.terrain.landform.n)
	world.terrain.landform.heights.fill(40.0)
	world.terrain.dh.fill(40.0)
	check(atmosphere.grass_amount(Vector3.ZERO) > 0.5, "Sheltered lower slopes retain meadow cover")
	world.terrain.landform.heights.fill(54.0)
	check(atmosphere.grass_amount(Vector3.ZERO) == 0.0, "Meadow grass stops below the snow line")
	var box := BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded; void vertex() { VERTEX.y += 40.0; } void fragment() { ALBEDO = vec3(1.0, 0.0, 0.0); }"
	var elevated := grass._mm(box, material, [Transform3D.IDENTITY], [Color.WHITE], 105.0)
	check(elevated.multimesh.custom_aabb.end.y >= 40.5, "Grass culling bounds include the shader's terrain displacement")
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
		grass.stone_mat = StandardMaterial3D.new()
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
	grass.free()
	atmosphere.free()
	world.free()
	print("GRASS_STREAM_TEST failures=%d" % failures)
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
