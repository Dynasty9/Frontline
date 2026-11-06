extends SceneTree
## Native generated-world review: four matched views, one map build, simulation held at two seconds.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	var world = game.world
	world.set_physics_process(false)
	world.cam.set_process(false)
	world.cam.edge_pan = false
	if world.director:
		world.director.active = false
	var prefix := "build/terrain/environment-views"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-prefix="):
			prefix = arg.get_slice("=", 1)
	assert(DirAccess.make_dir_recursive_absolute(prefix.get_base_dir()) == OK)
	var heights: PackedFloat32Array = world.terrain.landform.heights
	assert(not heights.is_empty(), "The environment stage needs a generated alpine map")
	var peak_index := 0
	for i in heights.size():
		if heights[i] > heights[peak_index]:
			peak_index = i
	var n: int = world.terrain.landform.n
	var half: float = world.terrain.landform.half
	var peak := Vector3((peak_index % n) * 4.0 - half, 0, floori(float(peak_index) / float(n)) * 4.0 - half)
	var views := [
		["snow-close", peak, 45.0, -42.0, -0.2],
		["snow-ridge", peak, 120.0, -30.0, -0.7],
		["forest", Vector3(-400,0,-450), 350.0, -30.0, -0.2],
		["panorama", Vector3.ZERO, 900.0, -22.0, 0.7],
	]
	var records := []
	for view in views:
		world.cam.dist = view[2]
		world.cam.target_dist = view[2]
		world.cam.pitch_deg = view[3]
		world.cam.yaw = view[4]
		world.cam.focus(view[1])
		for frame in 45:
			await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = prefix + "-" + view[0] + ".png"
		assert(root.get_texture().get_image().save_png(filename) == OK)
		records.append({"file": filename, "focus": str(view[1]), "zoom": view[2], "pitch": view[3], "yaw": view[4], "time": world.time})
		print("CAPTURE ", filename)
	var output := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"seed": world.settings.get("seed", 1), "mood": world.atmo.mood, "renderer": RenderingServer.get_current_rendering_method(), "resolution": root.size, "views": records}, "\t"))
	quit()
