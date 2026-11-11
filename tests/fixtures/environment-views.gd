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
	var clip := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-clip="):
			clip = arg.get_slice("=", 1)
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
	if "--capture-set=town" in OS.get_cmdline_user_args():
		var town: Rect2 = world.town_rect
		var center := Vector3(town.get_center().x, 0, town.get_center().y)
		views = [
			["street", Vector3(-55,0,-4), 15.0, -55.0, 0.7],
			["transition", Vector3(town.position.x,0,center.z), 25.0, -55.0, 0.7],
			["town", center, 130.0, -50.0, 0.7],
		]
		for piece: Array in world.decor:
			if piece[0] != "drive" or not piece[3] is Vector3:
				continue
			var size: Vector3 = piece[3]
			var position: Vector3 = piece[1]
			if size.x > 2.5 and size.z > 3.0 and town.grow(20.0).has_point(Vector2(position.x, position.z)):
				views.append(["driveway", position, 18.0, -50.0, float(piece[2]) + PI + 0.4])
				break
		print("CAPTURE town bounds=", town)
	var settle_frames := 45
	if "--capture-set=shoreline" in OS.get_cmdline_user_args():
		var shore: float = world.water.coast_x(0.0)
		views = [["town", Vector3(330, 0, 0), 90.0, -45.0, 0.7],
			["grains", Vector3(shore - 8.0, 0, -35), 18.0, -50.0, 0.7],
			["waterline", Vector3(shore, 0, -35), 38.0, -25.0, 0.7]]
		settle_frames = 90
	if "--capture-set=coast" in OS.get_cmdline_user_args():
		var shore: float = world.atmo.ground_mat.get_shader_parameter("sea_x")
		assert(shore < half, "The coast stage needs a map with a sea")
		views = [["coast", Vector3(shore + 100.0, 0, 0), 280.0, -14.0, PI * 0.5]]
		settle_frames = 90
	if "--capture-set=rain" in OS.get_cmdline_user_args():
		views = [["valley", Vector3.ZERO, 900.0, -22.0, 0.7],
			["town", Vector3.ZERO, 80.0, -45.0, 0.7],
			["close", Vector3(-110, 0, -130), 18.0, -25.0, 0.7],
			["slope", Vector3(-400, 0, -450), 35.0, -25.0, -0.2]]
		settle_frames = 150
	if "--capture-set=river-boundary" in OS.get_cmdline_user_args():
		views = [["close", Vector3(-232.6883, 0, -world.terrain.landform.half), 130.0, -40.0, 0.7],
			["forest", Vector3(-400, 0, -450), 350.0, -30.0, -0.2], ["panorama", Vector3.ZERO, 900.0, -22.0, 0.7]]
	if "--capture-set=meadow" in OS.get_cmdline_user_args():
		views = [
			["close", Vector3(-110, 0, -130), 18.0, -45.0, 0.7],
			["wide", Vector3(-110, 0, -130), 45.0, -35.0, 0.7],
			["low", Vector3(-110, 0, -130), 18.0, -15.0, 0.7],
		]
		settle_frames = 225
		world.atmo.grass.mat.set_shader_parameter("wind", 0.0)
		world.atmo.grass.bush_mat.set_shader_parameter("wind", 0.0)
	if "--capture-set=foliage" in OS.get_cmdline_user_args():
		var target := Vector3(-110, 0, -130)
		var nearest := INF
		for structure in world.structures:
			if structure.skind != "tree" or structure.variant == 2 or (structure.variant != 1 and (structure.eid * 2654435761) % 100 < 34):
				continue
			var distance: float = structure.position.distance_squared_to(Vector3(-110, 0, -130))
			if distance < nearest:
				nearest = distance
				target = structure.position
		views = [["tree", target, 18.0, -15.0, 0.7], ["reverse", target, 18.0, -15.0, -2.4],
			["stand", target, 65.0, -30.0, 0.7]]
		settle_frames = 90
		var materials = load("res://scripts/game/mats.gd")
		materials.foliage().shader.code = materials.foliage().shader.code.replace("uniform float wind = 1.0;", "uniform float wind = 0.0;")
		world.atmo.grass.mat.set_shader_parameter("wind", 0.0)
		world.atmo.grass.bush_mat.set_shader_parameter("wind", 0.0)
	if "--capture-set=clouds" in OS.get_cmdline_user_args():
		views = []
		for quality in [0, 1, 2, 3, 4, 0]:
			views.append(["clouds-%d-%d" % [quality, views.size()], Vector3(0, 80, 0), 1250.0, -10.0, 0.7, quality])
	if "--capture-set=cloud-weather" in OS.get_cmdline_user_args():
		world.cam.cam.fov = 55.0
		views = [["off", Vector3(0, 80, 0), 1250.0, -10.0, 0.7, 0, "day"]]
		for mood in ["day", "golden", "night", "rain"]:
			views.append([mood, Vector3(0, 80, 0), 1250.0, -10.0, 0.7, 3, mood])
		views.append(["boundary", Vector3.ZERO, 900.0, -14.0, 0.7, 3, "day"])
	if "--capture-set=cloud-distance" in OS.get_cmdline_user_args():
		world.cam.cam.fov = 55.0
		views = [
			["close", Vector3(-110, 0, -130), 18.0, -18.0, 0.7, 3, "day"],
			["tactical", Vector3.ZERO, 180.0, -42.0, 0.7, 3, "day"],
			["panorama", Vector3(0, 80, 0), 1250.0, -10.0, 0.7, 3, "day"],
			["reverse", Vector3.ZERO, 900.0, -14.0, -2.4, 3, "day"],
			["low", Vector3(0, 80, 0), 1250.0, -10.0, 0.7, 1, "day"],
			["ultra", Vector3(0, 80, 0), 1250.0, -10.0, 0.7, 4, "day"],
		]
	if "--capture-set=cloud-benchmark" in OS.get_cmdline_user_args():
		views = []
		for quality in [0, 3, 3, 0, 0, 1, 1, 0, 0, 4, 4, 0]:
			views.append(["sample-%d-q%d" % [views.size(), quality], Vector3(0, 80, 0), 1250.0, -10.0, 0.7, quality, "day"])
	if "--capture-set=cloud-boundary" in OS.get_cmdline_user_args():
		views = [["boundary", Vector3.ZERO, 900.0, -14.0, 0.7, 3, "day"]]
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var records := []
	for view in views:
		if view.size() > 6:
			world.atmo.apply_mood(view[6])
		if view.size() > 5:
			get_root().get_node("Settings").v.mountain_clouds = view[5]
			world.atmo.mountain_clouds.apply_settings(world.atmo)
		world.cam.dist = view[2]
		world.cam.target_dist = view[2]
		world.cam.pitch_deg = view[3]
		world.cam.yaw = view[4]
		world.cam.focus_pos = view[1]
		world.cam._apply()
		if world.atmo.mood == "rain":
			world.atmo._bolt_t = 100.0
			world.atmo._flash = 0.0
		for frame in settle_frames:
			await process_frame
		while world.structure_view != null and world.structure_view.warming():
			await process_frame
		var frame_ms := 0.0
		var gpu_ms := 0.0
		if view.size() > 5:
			var started := Time.get_ticks_usec()
			for sample in 120:
				await process_frame
				gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			gpu_ms /= 120.0
			frame_ms = float(Time.get_ticks_usec() - started) / 120000.0
		await RenderingServer.frame_post_draw
		var filename: String = prefix + "-" + view[0] + ".png"
		assert(root.get_texture().get_image().save_png(filename) == OK)
		if clip == view[0]:
			# Launch with --fixed-fps 30; Godot consumes that switch before exposing arguments.
			var frames := prefix + "-" + clip + "-frames"
			assert(DirAccess.make_dir_recursive_absolute(frames) == OK)
			for frame in 180:
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(frames + "/%04d.png" % frame) == OK)
		records.append({"file": filename, "focus": str(view[1]), "zoom": view[2], "pitch": view[3], "yaw": view[4], "time": world.time, "mood": world.atmo.mood, "cloud_quality": get_root().get_node("Settings").v.mountain_clouds, "frame_ms": frame_ms, "gpu_ms": gpu_ms})
		print("CAPTURE ", filename)
	var output := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"seed": world.settings.get("seed", 1), "mood": world.atmo.mood, "renderer": RenderingServer.get_current_rendering_method(), "resolution": root.size, "views": records}, "\t"))
	quit()
