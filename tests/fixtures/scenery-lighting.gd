extends Node

func _ready() -> void:
	for metres in [1024, 2048, 3072]:
		MapDims.configure(metres)
		var shader := Shader.new()
		shader.code = MapDims.shader(Atmosphere.SCENERY_BAKE_SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT))
		assert(not shader.code.contains("__MAP_"))
		if DisplayServer.get_name() != "headless":
			await check_bake(shader)
	MapDims.configure(1024)
	if DisplayServer.get_name() != "headless":
		await check_river_continuation()
	print("SCENERY_LIGHTING passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()

func check_river_continuation() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(16, 16)
	view.disable_3d = true
	add_child(view)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = MapDims.shader("shader_type canvas_item; render_mode unshaded, blend_disabled; uniform vec2 sample_position;\n" + WaterView.SCENERY_RIVERS + "\nvoid fragment() { vec4 mask = scenery_river_mask(sample_position); COLOR = vec4(mask.r, mask.a, 0.0, 1.0); }")
	var tips := WaterView.scenery_river_tips([{"pts": PackedVector3Array([Vector3(0, 0, -600), Vector3(0, 0, 600)]), "w": 24.0}], MapDims.HALF)
	material.set_shader_parameter("river_tips", tips)
	var rect := ColorRect.new()
	rect.size = Vector2(16, 16)
	rect.material = material
	view.add_child(rect)
	for sample in [[Vector2(0, -MapDims.HALF + 1), false], [Vector2(8, -MapDims.HALF - 20), true],
			[Vector2(70, -MapDims.HALF - 20), false], [Vector2(0, -MapDims.HALF - 160), false]]:
		material.set_shader_parameter("sample_position", sample[0])
		var output := await bake(view)
		var pixel := output.get_pixel(8, 8)
		if sample[1]:
			assert(pixel.r > 0.35 and pixel.g > 0.99, "The scenery river has a visible submerged bed: " + str(pixel))
		else:
			assert(pixel.r < 0.01 and pixel.g < 0.01, "Scenery water stays outside the battlefield and within its bounded continuation")
	view.queue_free()


func check_bake(shader: Shader) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(512, 512)
	view.disable_3d = true
	add_child(view)
	var rect := ColorRect.new()
	rect.size = Vector2(512, 512)
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	view.add_child(rect)
	var blank := Image.create(512, 512, false, Image.FORMAT_RF)
	var mountain := ImageTexture.create_from_image(blank)
	var ground := TerrainTexture.new(Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_RH))
	material.set_shader_parameter("backdrop_tex", mountain)
	material.set_shader_parameter("deform_tex", ground.texture)
	material.set_shader_parameter("sun_direction", Vector3(1, 0.15, 0).normalized())
	var flat := await bake(view)
	var open := flat.get_pixel(130, 130)
	assert(absf(open.r - 1.0) < 0.01 and absf(open.g - 0.5) < 0.01 and absf(open.b - 1.0) < 0.01, "Baked visibility is linear data, not gamma-encoded colour")
	var ridge_x := -MapDims.HALF - 600.0
	for z in 512:
		for x in 512:
			var world_x := (float(x) + 0.5) / 512.0 * (MapDims.SIZE + 3600.0) - (MapDims.HALF + 1800.0)
			var ridge := exp(-pow((world_x - ridge_x) / 85.0, 2.0)) * 0.86
			blank.set_pixel(x, z, Color(ridge, 0, 0))
	mountain.update(blank)
	var east := await bake(view)
	material.set_shader_parameter("sun_direction", Vector3(-1, 0.15, 0).normalized())
	var west := await bake(view)
	var left := Vector2i(Vector2(ridge_x - 150.0, -MapDims.HALF - 400.0) / (MapDims.SIZE + 3600.0) * 512.0 + Vector2.ONE * 256.0)
	var right := Vector2i(Vector2(ridge_x + 150.0, -MapDims.HALF - 400.0) / (MapDims.SIZE + 3600.0) * 512.0 + Vector2.ONE * 256.0)
	assert(east.get_pixelv(left).b < 0.1 and east.get_pixelv(right).b > 0.9, "A ridge must shade its west valley when the sun is east")
	assert(west.get_pixelv(right).b < 0.1 and west.get_pixelv(left).b > 0.9, "Changing the sun must move the cached shadow")
	assert(east.get_pixelv(left).r < 0.99, "Cliffs also reduce ambient sky visibility")
	material.set_shader_parameter("sun_direction", Vector3.UP)
	for frame in 3:
		await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().get_data() == west.get_data(), "Lighting must remain cached until explicitly rebaked")
	print("SCENERY_LIGHTING native ridge and colour checks passed map=", MapDims.N)
	view.queue_free()

func bake(view: SubViewport) -> Image:
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
