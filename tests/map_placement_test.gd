extends Node


func _ready() -> void:
	var world := World.new()
	world.water = WaterMap.new(world)
	var generator := MapGen.new(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 67591
	for i in 1500:
		generator._place([Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500)), Vector2(rng.randf_range(0.1, 45), rng.randf_range(0.1, 3)), rng.randf() * TAU])
		generator._keep_clear([Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500)), rng.randf_range(1, 20)])
	# A floor's larger house reservation must enter any newly crossed buckets.
	generator._place([Vector2(31, 31), Vector2.ONE, 0])
	generator._unplace_last()
	generator._place([Vector2(31, 31), Vector2(18, 12), 0])
	var failures := 0
	for i in 1200:
		var center := Vector2(rng.randf_range(-520, 520), rng.randf_range(-520, 520))
		var half := Vector2(rng.randf_range(0.1, 10), rng.randf_range(0.1, 25))
		var yaw := rng.randf() * TAU
		var reference := false
		for p in generator.placed:
			if Defs.obb_overlap(center, half, yaw, p[0], p[1], p[2]):
				reference = true
				break
		if not Defs.in_map(Vector3(center.x, 0, center.y), 6.0):
			reference = true
		if generator._is_free(Vector3(center.x, 0, center.y), half, yaw, 0, false) == reference:
			failures += 1
			push_error("Placement index differs from exhaustive collision test")
		for area in generator.clear:
			if center.distance_to(area[0]) < float(area[1]) + half.length():
				reference = true
				break
		if generator._is_free(Vector3(center.x, 0, center.y), half, yaw, 0, true) == reference:
			failures += 1
			push_error("Road clearance index differs from exhaustive test")
	world.free()
	print("MAP_PLACEMENT_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
