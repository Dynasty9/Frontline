extends Node

func _ready() -> void:
	check_release_forest_atlas()
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
		await check_cloud_continuity()
		await check_vertex_ground_normals()
		await check_rain_splashes()
		await check_road_surfaces()
		await check_ground_grime()
		await check_shrub_leaves()
		await check_tree_leaves()
		await check_batched_tints()
	print("TERRAIN_MATERIALS passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()

func check_batched_tints() -> void:
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
	var shader := Mats.shader()
	var original_code := shader.code
	shader.code = original_code.replace("render_mode specular_schlick_ggx;", "render_mode unshaded;")
	for sample in [["roof_tile", Color(0.65, 1.2, 1.4), Vector3.ZERO],
		["roof_tile", Mats.tint_for("roof_tile", Color(0.36, 0.34, 0.32)), Vector3.ZERO],
		["wood_dark", Color.WHITE, Vector3(17, 0, 23)]]:
		var tint: Color = sample[1]
		var offset: Vector3 = sample[2]
		camera.position = offset + Vector3(0, 5, 0)
		camera.look_at(offset, Vector3.FORWARD)
		var holder := Node3D.new()
		view.add_child(holder)
		holder.position = offset
		var mesh := MeshInstance3D.new()
		mesh.mesh = PlaneMesh.new()
		holder.add_child(mesh)
		Mats.apply(mesh, sample[0], tint)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var before := view.get_texture().get_image()
		var groups := {}
		var parts := []
		Mats._collect(holder, holder.transform, groups, parts, [], true, true)
		holder.free()
		holder = Node3D.new()
		view.add_child(holder)
		Mats._emit(holder, groups, false)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var after := view.get_texture().get_image()
		var error := 0.0
		for y in 64:
			for x in 64:
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				error += Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / 4096.0
		assert(error < 0.018, "Batching must preserve colours and world-space texture placement in both renderers: error=%f material=%s tint=%s" % [error, sample[0], tint])
		holder.free()
	shader.code = original_code
	view.free()

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
	var track_shader := Shader.new()
	track_shader.code = Mats.code(MapDims.shader(Atmosphere.ROAD_SHADER.replace("// STREET_SURFACE", Mats.ASPHALT_SHADER))).replace("render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;", "render_mode unshaded;")
	var track_material := ShaderMaterial.new()
	track_material.shader = track_shader
	var flat_noise := Image.create(4, 4, false, Image.FORMAT_RF)
	flat_noise.fill(Color(0.5, 0, 0))
	var noise_texture := ImageTexture.create_from_image(flat_noise)
	track_material.set_shader_parameter("detail_tex", noise_texture)
	track_material.set_shader_parameter("street_noise", noise_texture)
	var flat_ground := TerrainTexture.new(Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_RGF))
	track_material.set_shader_parameter("deform_tex", flat_ground.texture)
	mesh.material_override = track_material
	for frame in 3:
		await RenderingServer.frame_post_draw
	var track := view.get_texture().get_image().get_pixel(32, 32).srgb_to_linear()
	var track_expected := Color(0.115, 0.09, 0.0615) * lerpf(0.65, 1.2, smoothstep(0.25, 0.70, 0.5))
	assert(Vector3(track.r, track.g, track.b).distance_to(Vector3(track_expected.r, track_expected.g, track_expected.b)) < 0.008, "Country tracks must blend dirt and wear in linear light in both renderers: %s" % track)
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
	var meadow_code := MapDims.shader(Atmosphere.GROUND_SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT))
	meadow_code = meadow_code.replace("render_mode specular_schlick_ggx;", "render_mode unshaded;")
	meadow_code = meadow_code.substr(0, meadow_code.find("void fragment()")) + """
void fragment() {
	ALBEDO = meadow_color(vec2(0.5), 0.5);
	if (OUTPUT_IS_SRGB) { ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(ALBEDO, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO)); }
}
"""
	var meadow_image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	meadow_image.fill(Color(0.5, 0.6, 0.3))
	var meadow_material := ShaderMaterial.new()
	var meadow_shader := Shader.new()
	meadow_shader.code = meadow_code
	meadow_material.shader = meadow_shader
	meadow_material.set_shader_parameter("meadow_grass", ImageTexture.create_from_image(meadow_image))
	mesh.material_override = meadow_material
	for frame in 3:
		await RenderingServer.frame_post_draw
	var meadow_pixel := view.get_texture().get_image().get_pixel(32, 32).srgb_to_linear()
	var meadow_expected := meadow_image.get_pixel(0, 0).srgb_to_linear() * Color(0.27, 0.415, 0.375)
	assert(Vector3(meadow_pixel.r, meadow_pixel.g, meadow_pixel.b).distance_to(Vector3(meadow_expected.r, meadow_expected.g, meadow_expected.b)) < 0.008, "Meadow photographs shade in linear light in both renderers: %s" % meadow_pixel)
	view.queue_free()
	print("TERRAIN_MATERIALS native sloped-road normals and colour checks passed")


func check_ground_grime() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	view.add_child(camera)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	view.add_child(mesh)
	var material := Mats.get_mat("wood_dark")
	var merged := Mats.vc_variant(material)
	Mats.set_material(mesh, material)
	Mats.set_inst(mesh, &"tint", Color(0.8, 0.7, 0.6))
	var carried := mesh.material_override as ShaderMaterial
	for elevation in [0.0, 40.0, 80.0]:
		var field := Image.create(514, 514, false, Image.FORMAT_RGBAF)
		field.fill(Color(elevation, elevation, 0.0, 1.0))
		var heights := Texture2DArray.new()
		assert(heights.create_from_images([field]) == OK)
		Mats.set_ground_maps(heights, null)
		for shared in [material, merged, carried, Mats.get_mat("plaster")]:
			assert(shared.get_shader_parameter("crater_tex") == heights, "Ground weathering must follow new maps in shared, batched and Compatibility materials")
		var debug := material.duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code = material.shader.code.replace("render_mode specular_schlick_ggx;", "render_mode unshaded;").replace("ALBEDO = col;", "ALBEDO = vec3(low); if (OUTPUT_IS_SRGB) { ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(ALBEDO, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO)); }")
		debug.shader = shader
		mesh.material_override = debug
		for above in [0.1, 0.45, 1.2]:
			mesh.position.y = elevation + above
			camera.position = mesh.position + Vector3(0, 4, 0)
			camera.look_at(mesh.position, Vector3.FORWARD)
			for frame in 3:
				await RenderingServer.frame_post_draw
			var pixel := view.get_texture().get_image().get_pixel(16, 16).srgb_to_linear()
			var expected := 1.0 - smoothstep(0.0, 0.9, above)
			assert(absf(pixel.r - expected) < 0.025, "Grime follows height above terrain, not sea level: elevation=%s above=%s actual=%s" % [elevation, above, pixel.r])
	view.queue_free()
	print("TERRAIN_MATERIALS elevated-ground weathering passed")


func check_shrub_leaves() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	view.add_child(camera)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.center_offset.y = -0.1
	mesh.mesh = plane
	mesh.scale = Vector3.ONE * 2.0
	view.add_child(mesh)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MapDims.shader(Grass.BUSH_SHADER.replace("render_mode specular_disabled, cull_disabled;", "render_mode unshaded, cull_disabled;"))
	material.shader = shader
	mesh.material_override = material
	var leaf := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	leaf.fill(Color(0.5, 0.6, 0.3, 1.0))
	material.set_shader_parameter("leaf_texture", ImageTexture.create_from_image(leaf))
	var expected := leaf.get_pixel(0, 0).srgb_to_linear() * Color(0.7, 0.85, 0.7) * 0.825
	for height in [0.0, 40.0, 80.0]:
		var ground := Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_RGF)
		ground.fill(Color(height, height, 0.0))
		var tiled := TerrainTexture.new(ground)
		material.set_shader_parameter("deform_tex", tiled.texture)
		camera.position = Vector3(0, height + 5.0, 0)
		camera.look_at(Vector3(0, height, 0), Vector3.FORWARD)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var pixel := view.get_texture().get_image().get_pixel(16, 16).srgb_to_linear()
		assert(Vector3(pixel.r, pixel.g, pixel.b).distance_to(Vector3(expected.r, expected.g, expected.b)) < 0.008, "Leaf photographs and root shade stay consistent on elevated terrain: %s" % pixel)
	leaf.fill(Color(0.5, 0.6, 0.3, 0.1))
	material.set_shader_parameter("leaf_texture", ImageTexture.create_from_image(leaf))
	for frame in 3:
		await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().get_pixel(16, 16).a < 0.01, "Transparent photographed leaf edges must not turn into opaque cards")
	leaf.fill(Color.WHITE)
	material.set_shader_parameter("leaf_texture", ImageTexture.create_from_image(leaf))
	mesh.mesh = QuadMesh.new()
	mesh.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 100, 4))
	# Read the actual leaf normal from each side, independently of scene lighting.
	shader.code = shader.code.replace("BACKLIGHT = vec3(0.08, 0.1, 0.035);", """
	vec3 encoded = NORMAL * 0.5 + 0.5;
	if (!OUTPUT_IS_SRGB) { encoded = mix(encoded / 12.92, pow((encoded + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), encoded)); }
	ALBEDO = encoded;
""")
	for side in [-1.0, 1.0]:
		camera.position = Vector3(0, 81.3, side * 5.0)
		camera.look_at(Vector3(0, 81.3, 0))
		for frame in 3:
			await RenderingServer.frame_post_draw
		var normal := view.get_texture().get_image().get_pixel(16, 16)
		assert(normal.b > 0.8 and normal.g > 0.65, "Both sides of a leaf must face the camera-facing hemisphere and bend toward the sky: %s" % normal)
	view.queue_free()
	print("TERRAIN_MATERIALS native shrub colour and elevated roots passed")


func check_tree_leaves() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0, 0, 5)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	var material := Mats.leaf_cards(false)
	var shader := material.shader
	var original_code := shader.code
	var original_texture: Texture2D = material.get_shader_parameter("leaf_texture")
	shader.code = original_code.replace("render_mode cull_disabled;", "render_mode unshaded, cull_disabled;")
	var photo := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	photo.fill(Color(0.5, 0.6, 0.3, 1.0))
	var texture := ImageTexture.create_from_image(photo)
	material.set_shader_parameter("leaf_texture", texture)
	material.set_shader_parameter("wind", 0.0)
	var holder := Node3D.new()
	view.add_child(holder)
	var tint := Color(0.2, 0.32, 0.14)
	var bake := Mats.Bake.new()
	bake.part(QuadMesh.new(), material, Transform3D.IDENTITY, tint)
	bake.commit(holder)
	for frame in 3:
		await RenderingServer.frame_post_draw
	var pixel := view.get_texture().get_image().get_pixel(16, 16).srgb_to_linear()
	var expected := photo.get_pixel(0, 0).srgb_to_linear()
	var linear_tint := tint.srgb_to_linear() * 0.95
	for channel in 3:
		expected[channel] *= 0.85 * 0.8425 * lerpf(0.75, 1.15, clampf(linear_tint[channel] * 12.0, 0.0, 1.0))
	assert(Vector3(pixel.r, pixel.g, pixel.b).distance_to(Vector3(expected.r, expected.g, expected.b)) < 0.012, "Baked tree cards must blend photographed leaves and tint in linear light: %s expected=%s" % [pixel, expected])
	photo.fill(Color(0.5, 0.6, 0.3, 0.1))
	texture.update(photo)
	for frame in 3:
		await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().get_pixel(16, 16).a < 0.01, "Tree photographs must keep transparent edges after batching")
	photo.fill(Color.WHITE)
	texture.update(photo)
	var baked_material: ShaderMaterial = holder.get_child(0).material_override
	baked_material.set_shader_parameter("vertex_lit", true)
	var normal_source := original_code.substr(0, original_code.find("void fragment()"))
	shader.code = normal_source.replace("render_mode cull_disabled;", "render_mode unshaded, cull_disabled;") + """
void fragment() {
	vec3 color = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz * 0.5 + 0.5;
	if (!OUTPUT_IS_SRGB) { color = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color)); }
	ALBEDO = color;
}
"""
	for angle in [-0.6, 0.6]:
		holder.rotation.x = angle
		holder.scale = Vector3(1.3, 0.8, 1.7)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var normal_pixel := view.get_texture().get_image().get_pixel(16, 16)
		assert(normal_pixel.g > 0.68 and normal_pixel.b > 0.7, "Vertex-lit leaves must retain soft sky-facing canopy normals: %s" % normal_pixel)
	baked_material.set_shader_parameter("vertex_lit", false)
	material.set_shader_parameter("leaf_texture", original_texture)
	material.set_shader_parameter("wind", 1.0)
	shader.code = original_code
	view.free()
	print("TERRAIN_MATERIALS photographed tree colour and alpha passed")


func check_release_forest_atlas() -> void:
	# Release builds omit assertion expressions, including any allocation inside them.
	var lines := PackedStringArray()
	var forest_source: GDScript = load("res://scripts/game/distant_forest.gd")
	for line in forest_source.source_code.split("\n"):
		if not line.strip_edges().begins_with("assert(") and not line.begins_with("class_name "):
			lines.append(line)
	var release_script := GDScript.new()
	release_script.source_code = "\n".join(lines)
	var error := release_script.reload()
	assert(error == OK)
	var atlas: Texture2DArray = release_script.atlas_texture()
	assert(atlas.get_layers() == 20 and atlas.get_width() == 256 and atlas.has_mipmaps(), "Release tree cards must allocate their complete atlas without assertions")


func check_vertex_ground_normals() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0, 20, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	mesh.mesh = plane
	view.add_child(mesh)
	var shader := Shader.new()
	var source := Atmosphere.GROUND_SHADER
	# Read the production vertex normal before fragment bump mapping can hide it.
	source = source.substr(0, source.find("float hgt(")) + """
void fragment() {
	vec3 color = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz * 0.5 + 0.5;
	if (!OUTPUT_IS_SRGB) { color = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color)); }
	ALBEDO = color;
}
"""
	source = source.replace("render_mode specular_schlick_ggx;", "render_mode unshaded;")
	source = source.replace("// BACKDROP_HEIGHT", "float backdrop(vec2 p) { return 0.0; }")
	shader.code = MapDims.shader(source)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vertex_lit", true)
	mesh.material_override = material
	for slope in [Vector2.ZERO, Vector2(0.4, 0.2), Vector2(-0.3, -0.5)]:
		var heights := Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_RF)
		for y in MapDims.N:
			for x in MapDims.N:
				heights.set_pixel(x, y, Color((float(x) - MapDims.HALF) * slope.x + (float(y) - MapDims.HALF) * slope.y, 0, 0))
		var tiled := TerrainTexture.new(heights)
		material.set_shader_parameter("deform_tex", tiled.texture)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var pixel := view.get_texture().get_image().get_pixel(16, 16)
		var actual := Vector3(pixel.r, pixel.g, pixel.b) * 2.0 - Vector3.ONE
		var expected := Vector3(-slope.x, 1.0, -slope.y).normalized()
		assert(actual.distance_to(expected) < 0.025, "Vertex lighting must follow displaced terrain across tile seams: actual=%s expected=%s" % [actual, expected])
	view.free()
	print("TERRAIN_MATERIALS native displaced vertex normals passed")


func check_rain_splashes() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	view.add_child(camera)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 100, 2))
	view.add_child(mesh)
	var shader := Shader.new()
	shader.code = MapDims.shader(Atmosphere.SPLASH_SHADER)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("water_level", WaterMap.LEVEL)
	mesh.material_override = material
	for height in [-2.0, 0.0, 80.0]:
		var ground := Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_RF)
		ground.fill(Color(height, 0, 0))
		var tiled := TerrainTexture.new(ground)
		material.set_shader_parameter("deform_tex", tiled.texture)
		var target := Vector3(0, maxf(height, WaterMap.LEVEL) + 0.05, 0)
		camera.position = target + Vector3(0, 0, 5)
		camera.look_at(target)
		for frame in 3:
			await RenderingServer.frame_post_draw
		var pixels := view.get_texture().get_image()
		assert(pixels.get_pixel(16, 16).a > 0.2, "Rain splashes must land on elevated ground or the water surface")
		assert(pixels.get_pixel(0, 0).a < 0.01, "Splash edges must fade rather than draw white squares")
	camera.position.z = 150.0
	for frame in 3:
		await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().get_pixel(16, 16).a < 0.01, "Distant splashes must fade before they form a bright patch")
	view.free()
	print("TERRAIN_MATERIALS native rain splash height, shape and distance passed")


func check_cloud_continuity() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(64, 64)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var rect := ColorRect.new()
	rect.size = Vector2(64, 64)
	view.add_child(rect)
	var source := Atmosphere.SKY_SHADER
	var start := source.find("float hash(")
	var helpers := source.substr(start, source.find("void sky()") - start)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" + helpers + """
void fragment() {
	vec2 p = floor(UV * 64.0) - 32.0;
	float x = abs(noise(p + vec2(-0.001, 0.37)) - noise(p + vec2(0.001, 0.37)));
	float y = abs(noise(p + vec2(0.37, -0.001)) - noise(p + vec2(0.37, 0.001)));
	COLOR = vec4(x, y, 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	for frame in 4:
		await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	for y in 64:
		for x in 64:
			var pixel := pixels.get_pixel(x, y)
			assert(maxf(pixel.r, pixel.g) < 0.01, "Cloud noise must remain continuous across neighboring grid cells: %s" % pixel)
	view.free()
	print("TERRAIN_MATERIALS native cloud continuity passed")
