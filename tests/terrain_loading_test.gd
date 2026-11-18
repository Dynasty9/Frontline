extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var size := int(OS.get_environment("FL_LOAD_BENCH_SIZE")) if OS.has_environment("FL_LOAD_BENCH_SIZE") else 64
	TerrainMap.N = size
	TerrainMap.H = size * 0.5
	TerrainMap.DN = size * TerrainMap.DRES
	var samples := PackedFloat32Array()
	var width := int(size / Landform.STEP) + 1
	for z in width:
		for x in width:
			samples.append(12.0 + sin(x * 0.7) * 5.0 + cos(z * 0.4) * 3.0)
	var host := World.new()
	host.srv = true
	host.has_view = false
	host.terrain = TerrainMap.new(host)
	var client := World.new()
	client.srv = false
	client.has_view = false
	client.terrain = TerrainMap.new(client)
	for w: World in [host, client]:
		var start := Time.get_ticks_usec()
		w.terrain.install_landform(samples)
		check(is_equal_approx(w.terrain.landform_progress, 1.0), "Terrain preparation must report completion")
		print("TERRAIN_LOAD side=%s size=%d ms=%.1f" % ["host" if w.srv else "client", size, (Time.get_ticks_usec() - start) / 1000.0])
	check(host.terrain.dh == client.terrain.dh, "Client ground heights must match the host")
	check(host.terrain.slopes == client.terrain.slopes, "Client slopes must match the host")
	check(host.terrain.vehicle_slopes.size() == size * size, "Host must retain vehicle navigation slopes")
	check(client.terrain.vehicle_slopes.is_empty(), "Clients must skip the host-only vehicle navigation grid")
	for z in range(0, size, maxi(1, size / 8)):
		for x in range(0, size, maxi(1, size / 8)):
			var steep := 0.0
			for zz in range(maxi(0, z - 4), mini(size, z + 5)):
				for xx in range(maxi(0, x - 4), mini(size, x + 5)):
					steep = maxf(steep, host.terrain.slopes[zz * size + xx])
			check(host.terrain.vehicle_slopes[z * size + x] == steep, "Vehicle footprint must preserve the maximum slope")
	host.free()
	client.free()
	print("TERRAIN_LOADING_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
