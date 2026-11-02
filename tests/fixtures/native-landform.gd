extends Node

var queries := 0
var random := RandomNumberGenerator.new()


func compare(pair: Array[World]) -> void:
	var a := pair[0].terrain
	var b := pair[1].terrain
	assert(a.dh.size() == b.dh.size())
	for i in a.dh.size():
		assert(absf(a.dh[i] - b.dh[i]) < 0.00001, "Elevated crater sample %d" % i)
	for i in 48:
		var p := Vector3(random.randf_range(-35, 35), 0, random.randf_range(-35, 35))
		var core := b._native
		assert(absf(a.landform.height(p) - float(core.query(p, Vector3.ZERO, 11, false, false))) < 0.000001)
		assert(a.slope_at(p) == float(core.query(p, Vector3.ZERO, 12, false, false)))
		assert(a.vehicle_slopes[a.idx_of(p)] == float(core.query(p, Vector3.ZERO, 13, false, false)))
		assert(absf(pair[0].ground_y(p) - pair[1].ground_y(p)) < 0.00001)
		for vehicle in [false, true]:
			assert(a.nav_weight(a.idx_of(p), vehicle) == b.nav_weight(b.idx_of(p), vehicle))
			for tracked in [false, true]:
				assert(a.speed_mul(p, vehicle, tracked) == b.speed_mul(p, vehicle, tracked))
		var half := Vector2(random.randf_range(0.1, 5), random.randf_range(0.1, 5))
		var yaw := random.randf_range(-PI, PI)
		assert(a.landform.fits(p, half, yaw) == core.landform_fits(p, half, yaw, 0.35))
		var start := p + Vector3(0, random.randf_range(0, 40), 0)
		var finish := Vector3(random.randf_range(-35, 35), random.randf_range(-2, 40), random.randf_range(-35, 35))
		var expected := a.ray_ground(start, finish)
		var actual := b.ray_ground(start, finish)
		assert(expected.is_empty() == actual.is_empty(), "Ridge obstruction")
		if not expected.is_empty():
			assert((expected.position as Vector3).distance_to(actual.position) < 0.00001, "Ground intersection")
			assert((expected.normal as Vector3).distance_to(actual.normal) < 0.00001, "Ground normal")
		queries += 1
	var saved: PackedByteArray = b._native.checkpoint()
	assert(saved[4] == 3 and b._native.restore(saved))
	assert(b._native.checkpoint() == saved)
	assert(not b._native.set_landform(PackedFloat32Array([NAN])))
	assert(b._native.checkpoint() == saved)


func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	random.seed = 771920
	for seed_value in 4:
		var heights := PackedFloat32Array()
		for z in 17:
			for x in 17:
				heights.append(20.0 + 9.0 * sin(x * 0.3 + seed_value) + 6.0 * cos(z * 0.2))
		var pair: Array[World] = []
		for native in [false, true]:
			var w := World.new()
			w.has_view = true
			w.settings = {"seed": 314, "gdscript_terrain": not native}
			w.terrain = TerrainMap.new(w)
			w.water = WaterMap.new(w)
			w.terrain.install_landform(heights)
			pair.append(w)
		compare(pair)
		for blast in 8:
			var p := Vector3(random.randf_range(-24, 24), 0, random.randf_range(-24, 24))
			p.y = pair[0].terrain.landform.height(p)
			for w in pair:
				w.terrain.add_crater(p, 1.2 + blast * 0.2)
			compare(pair)
		# Worker imports must preserve geology as well as the carved surface.
		pair[1].terrain.begin_ground_import()
		pair[1].terrain.end_ground_import()
		compare(pair)
		var expected := pair[0].terrain.deform_img
		var actual := pair[1].terrain.deform_img
		assert(expected.get_format() == Image.FORMAT_RGH and actual.get_format() == Image.FORMAT_RGH)
		assert(expected.get_data() == actual.get_data(), "Surface and geology texture channels")
		for w in pair:
			w.free()
	print("NATIVE_LANDFORM passed queries=", queries)
	get_tree().quit()
