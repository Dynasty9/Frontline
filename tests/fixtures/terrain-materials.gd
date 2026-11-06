extends Node

func _ready() -> void:
	var arrays := Atmosphere.terrain_materials()
	assert(arrays.size() == 2)
	assert(arrays[0] == Atmosphere.terrain_materials()[0], "Map reloads must reuse the material allocation")
	for channel in 2:
		var array := arrays[channel]
		assert(array.get_layers() == 5 and array.get_width() == 1024 and array.get_height() == 1024)
		assert(array.has_mipmaps() and array.get_format() == Image.FORMAT_RGBA8, "All packed channels and distant filtering must survive import")
		for layer in Atmosphere.TERRAIN_MATERIALS.size():
			var name: String = Atmosphere.TERRAIN_MATERIALS[layer]
			var suffix := "color_height" if channel == 0 else "surface"
			var path := "res://assets/terrain/%s_%s.png" % [name, suffix]
			var original := Image.new()
			assert(original.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
			var texture: Texture2D = load(path)
			var imported := texture.get_image()
			for p in [Vector2i(9, 23), Vector2i(511, 800), Vector2i(901, 107)]:
				assert(original.get_pixelv(p) == imported.get_pixelv(p), "Import must not repair alpha: it contains height or roughness")
			if DisplayServer.get_name() != "headless":
				assert(array.get_layer_data(layer).get_data() == imported.get_data(), "Array layers must preserve the packed channels and mip levels")
	var asphalt: Texture2D = preload("res://assets/town/road_damaged_clean_surface.png")
	var original := Image.new()
	assert(original.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/town/road_damaged_clean_surface.png")) == OK)
	var imported := asphalt.get_image()
	assert(imported.has_mipmaps() and imported.get_size() == Vector2i(1024, 1024))
	for p in [Vector2i(9, 23), Vector2i(511, 800), Vector2i(901, 107)]:
		assert(original.get_pixelv(p) == imported.get_pixelv(p), "Asphalt roughness in alpha must survive import")
	if DisplayServer.get_name() != "headless":
		await check_road_surfaces()
	print("TERRAIN_MATERIALS passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()

func check_road_surfaces() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(64, 64)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0, 5, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded;\n" + Mats.ASPHALT_SHADER + """
varying vec3 position;
void vertex() { position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 color = normalize(ground_surface_basis(position) * vec3(0.0, 0.0, 1.0)) * 0.5 + 0.5;
	if (!OUTPUT_IS_SRGB) { color = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color)); }
	ALBEDO = color;
}
"""
	material.shader = shader
	mesh.material_override = material
	view.add_child(mesh)
	for angle in [-0.35, 0.0, 0.35]:
		mesh.rotation.x = angle
		for frame in 3:
			await RenderingServer.frame_post_draw
		var pixel := view.get_texture().get_image().get_pixel(32, 32)
		var actual := Vector3(pixel.r, pixel.g, pixel.b) * 2.0 - Vector3.ONE
		var expected := Vector3(0, cos(angle), sin(angle))
		assert(actual.distance_to(expected) < 0.025, "Road and pavement normal maps must follow the underlying slope: actual=%s expected=%s" % [actual, expected])
	mesh.rotation = Vector3.ZERO
	shader.code = "shader_type spatial; render_mode unshaded;\n" + Mats.ASPHALT_SHADER + """
uniform sampler2D scan : source_color;
uniform sampler2D noise;
void fragment() { ALBEDO = street_surface(scan, noise, vec2(0.0)); }
"""
	for pair in [["scan", 0.4], ["street_detail", 0.3], ["noise", 0.5]]:
		var flat := Image.create(4, 4, false, Image.FORMAT_RGB8)
		flat.fill(Color(pair[1], pair[1], pair[1]))
		material.set_shader_parameter(pair[0], ImageTexture.create_from_image(flat))
	for frame in 3:
		await RenderingServer.frame_post_draw
	var road := view.get_texture().get_image().get_pixel(32, 32)
	assert(absf(road.r - 0.314) < 0.008, "Street blending must use linear scan values in both renderers: %s" % road)
	for kind in ["roof_tile", "roof_concrete", "wood_dark", "bark"]:
		var photographed := Mats.get_mat(kind).duplicate() as ShaderMaterial
		assert(photographed.get_shader_parameter("pattern") == Mats.WEATHERED_PHOTO)
		var unlit := Shader.new()
		unlit.code = photographed.shader.code.replace("render_mode specular_schlick_ggx;", "render_mode unshaded;")
		photographed.shader = unlit
		photographed.set_shader_parameter("weathering", 0.0)
		photographed.set_shader_parameter("grime", 0.0)
		mesh.material_override = photographed
		for frame in 3:
			await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image()
		var mean := Vector3.ZERO
		for y in 64:
			for x in 64:
				var sample := pixels.get_pixel(x, y).srgb_to_linear()
				mean += Vector3(sample.r, sample.g, sample.b) / 4096.0
		var base: Color = photographed.get_shader_parameter("col_a")
		base = base.srgb_to_linear()
		var target := Vector3(base.r, base.g, base.b)
		assert(mean.distance_to(target) < 0.04, "Photographed %s must retain its preset colour: actual=%s expected=%s" % [kind, mean, target])
	var leaves := Texture2DArray.new()
	var leaf_images: Array[Image] = []
	for value in [0.4, 0.8]:
		var leaf := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		leaf.fill(Color(value, value, value, 1))
		leaf_images.append(leaf)
	assert(leaves.create_from_images(leaf_images) == OK)
	var forest_code := MapDims.shader(DistantForest.SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT))
	forest_code = forest_code.replace("render_mode cull_disabled;", "render_mode unshaded, cull_disabled;")
	forest_code = forest_code.substr(0, forest_code.find("void vertex()")) + "void vertex() { frames = vec3(0.0, 1.0, 0.25); shade = 0.8; lighting = vec2(1.0); }\n" + forest_code.substr(forest_code.find("void fragment()"))
	var leaf_shader := Shader.new()
	leaf_shader.code = forest_code
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = leaf_shader
	leaf_material.set_shader_parameter("atlas", leaves)
	mesh.material_override = leaf_material
	for frame in 3:
		await RenderingServer.frame_post_draw
	var leaf_pixel := view.get_texture().get_image().get_pixel(32, 32)
	var blended := Color(0.4, 0.4, 0.4).srgb_to_linear().lerp(Color(0.8, 0.8, 0.8).srgb_to_linear(), 0.25) * 0.52
	assert(absf(leaf_pixel.r - blended.linear_to_srgb().r) < 0.008, "Tree elevation frames blend and shade in linear light: %s" % leaf_pixel)
	view.queue_free()
	print("TERRAIN_MATERIALS native sloped-road normals and colour checks passed")
