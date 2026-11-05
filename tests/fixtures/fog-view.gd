extends Node

var _visibility_cache := {}
var _terrain_version := -1
var _mask: RefCounted = ClassDB.instantiate("FogSightMask")
var checks := 0
var reference_usec := 0
var native_usec := 0
var rendered_mask := PackedByteArray()


func check(terrain: TerrainMap, eyes: PackedVector4Array) -> void:
	var start := Time.get_ticks_usec()
	var expected := reference(terrain, eyes)
	reference_usec += Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var actual: PackedByteArray = _mask.raster(terrain._native, eyes, terrain.version)
	native_usec += Time.get_ticks_usec() - start
	assert(actual == expected, "Fog pixels differ for map %d mask %d" % [MapDims.N, checks])
	checks += 1


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 713198
	for size: int in [64, 256, 1024, 3072]:
		MapDims.N = size; MapDims.SIZE = size; MapDims.HALF = size * 0.5; MapDims.BIOME = size
		TerrainMap.N = size; TerrainMap.H = size * 0.5; TerrainMap.DN = size * TerrainMap.DRES
		var w := World.new()
		w.has_view = false
		w.terrain = TerrainMap.new(w)
		var fog := FogView.new()
		fog.world = w
		w.terrain.begin_ground_import()
		fog._process(0.1)
		fog._draw_visibility()
		check_loading(fog)
		w.terrain.end_ground_import()
		fog.free()
		var heights := PackedFloat32Array()
		var width := size / 4 + 1
		heights.resize(width * width)
		heights.fill(35.0)
		var row := PackedFloat32Array()
		for x in TerrainMap.DN:
			row.append(25.0 + 9.0 * sin(x * 0.05))
		w.terrain.dh.clear()
		for z in TerrainMap.DN:
			w.terrain.dh.append_array(row)
		assert(w.terrain._native.configure(size, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
		w.terrain.install_landform(heights, true)
		_visibility_cache.clear()
		_terrain_version = -1
		var eyes := PackedVector4Array()
		for i in (500 if size == 3072 else 32):
			var p := Vector3(random.randf_range(-size * 0.5, size * 0.5), 0, random.randf_range(-size * 0.5, size * 0.5))
			eyes.append(Vector4(p.x, w.terrain.deform_at(p) + (100.0 if i % 7 == 0 else 1.5), p.z, random.randf_range(1, minf(120, size * 0.2))))
		# Negative rounding boundaries, a zero radius and eyes beyond the texture edges.
		var pixel := FogView.span() / FogView.N
		eyes.append_array(PackedVector4Array([Vector4(-0.5 * pixel, 25.5, 0.5 * pixel, 1.5 * pixel), Vector4(0, 30, 0, 0), Vector4(-size, 40, size, 56)]))
		check(w.terrain, eyes)
		check(w.terrain, eyes)
		for i in eyes.size():
			eyes[i] += Vector4(0.04, 0.04, -0.04, 0)
		check(w.terrain, eyes)
		for i in eyes.size():
			eyes[i] += Vector4(pixel * 2, 0.75, pixel * 2, 0)
		check(w.terrain, eyes)
		w.terrain.add_crater(Vector3.ZERO, 5)
		check(w.terrain, eyes)
		rendered_mask = _mask.raster(w.terrain._native, eyes, w.terrain.version)
		check(w.terrain, PackedVector4Array())
		check(w.terrain, eyes)
		# A different terrain instance can have the same version and observer keys.
		w.terrain = TerrainMap.new(w)
		_visibility_cache.clear()
		check(w.terrain, eyes)
		assert(_mask.raster(w.terrain._native, PackedVector4Array([Vector4(NAN, 0, 0, 1)]), 0).is_empty())
		w.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fog-output="):
			await render_comparison(arg.trim_prefix("--fog-output="))
	print("FOG_VIEW passed masks=", checks, " reference_usec=", reference_usec, " native_usec=", native_usec)
	get_tree().quit()


func check_loading(fog: FogView) -> void:
	assert(not fog.active and fog._observers.is_empty(), "Fog must wait for the imported terrain before gathering or drawing")


func render_comparison(path: String) -> void:
	assert(rendered_mask.count(255) > 0 and rendered_mask.count(0) > 0)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 256)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(512, 256)
	viewport.add_child(bg)
	var eyes := Node2D.new()
	var texture := ImageTexture.create_from_image(Image.create_from_data(256, 256, false, Image.FORMAT_L8, rendered_mask))
	eyes.draw.connect(func():
		for i in rendered_mask.size():
			if rendered_mask[i]:
				eyes.draw_rect(Rect2(i % 256, i / 256, 1, 1), Color.WHITE)
		eyes.draw_texture(texture, Vector2(256, 0)))
	viewport.add_child(eyes)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var drawn := image.get_region(Rect2i(0, 0, 256, 256))
	drawn.convert(Image.FORMAT_L8)
	assert(drawn.get_data() == rendered_mask, "The viewport must actually render the visible cells")
	assert(image.get_region(Rect2i(0, 0, 256, 256)).get_data() == image.get_region(Rect2i(256, 0, 256, 256)).get_data(), "One texture must draw the same pixels as the cell rectangles")
	assert(image.save_png(path) == OK)


# The former GDScript raster is the pixel oracle, including its observer cache.
func reference(terrain: TerrainMap, observers: PackedVector4Array) -> PackedByteArray:
	var k := FogView.N / FogView.span()
	var o := MapDims.HALF + FogView.MARGIN
	if _terrain_version != terrain.version:
		_terrain_version = terrain.version
		_visibility_cache.clear()
	var used := {}
	var visible_cells := {}
	for eye in observers:
		var key := Vector4i(roundi(eye.x * k), roundi(eye.z * k), roundi(eye.y), roundi(eye.w * k))
		used[key] = true
		if not _visibility_cache.has(key):
			var pixels := {}
			var center := Vector2((eye.x + o) * k, (eye.z + o) * k)
			var radius := ceili(eye.w * k)
			pixels[Vector2i(center)] = true
			# Sweep the horizon once per bearing; testing every pixel with a
			# full ray would repeat the same terrain thousands of times.
			var bearings := maxi(32, ceili(TAU * radius))
			for bearing in bearings:
				var direction := Vector2.from_angle(bearing * TAU / bearings)
				var horizon := -INF
				for step in range(1, radius + 1):
					var pixel := Vector2i(center + direction * step)
					if pixel.x < 0 or pixel.y < 0 or pixel.x >= FogView.N or pixel.y >= FogView.N:
						break
					var target := Vector3((pixel.x + 0.5) / k - o, 0, (pixel.y + 0.5) / k - o)
					var distance := Vector2(target.x - eye.x, target.z - eye.z).length()
					if distance > eye.w or distance < 0.1:
						continue
					var height := terrain.deform_at(target) - eye.y
					if (height + 1.5) / distance >= horizon:
						pixels[pixel] = true
					horizon = maxf(horizon, height / distance)
			_visibility_cache[key] = pixels.keys()
		for pixel in _visibility_cache[key]:
			visible_cells[pixel] = true
	for key in _visibility_cache.keys():
		if not used.has(key):
			_visibility_cache.erase(key)
	var data := PackedByteArray()
	data.resize(FogView.N * FogView.N)
	for pixel: Vector2i in visible_cells:
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < FogView.N and pixel.y < FogView.N:
			data[pixel.y * FogView.N + pixel.x] = 255
	return data
