extends SceneTree
## Reproducible native environment fly-throughs. Launch at fixed 30 Hz.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var mode := "stones"
	var output := "build/media-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-stage="):
			mode = arg.get_slice("=", 1)
		if arg.begins_with("--motion-output="):
			output = arg.get_slice("=", 1)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	var world = game.world
	world.set_physics_process(false)
	world.cam.set_process(false)
	world.cam.edge_pan = false
	world.cam.cam.fov = 35.0
	if world.director:
		world.director.active = false
	var views := []
	match mode:
		"clouds":
			world.cam.cam.fov = 55.0
			for mood in ["day", "golden", "rain", "night"]:
				views.append([mood.capitalize(), Vector3(-1500, 120, -450), 900.0, -8.0, 0.7, mood])
		"stones":
			views = [["Fractured stone detail", Vector3(311.6891,0,433.3651), 12.0, -50.0, 0.7],
				["Stones within the alpine slope", Vector3(311.6891,0,433.3651), 42.0, -42.0, 0.7]]
		"shore":
			views = [["Gravel, wet margins and exposed sand", Vector3(330,0,0), 48.0, -45.0, 0.7],
				["Coastal town context", Vector3(330,0,0), 100.0, -45.0, 0.7]]
		"town":
			views = [["Photographed surfaces and door paths", Vector3(-30,0,-12), 35.0, -50.0, 0.7],
				["Town plots and connected streets", Vector3.ZERO, 190.0, -40.0, 0.7]]
		"environment":
			world.cam.cam.fov = 55.0
			views = [["Alpine ranges, ocean and forest coverage", Vector3.ZERO, 900.0, -22.0, 0.7],
				["Calibrated roofs, asphalt and frontages", Vector3(-30,0,-12), 55.0, -45.0, 0.7],
				["Finer meadow and clustered shrubs", Vector3(-110,0,-130), 22.0, -35.0, 0.7]]
	assert(not views.is_empty())
	var records := []
	var index := 0
	for view in views:
		if mode == "clouds":
			world.atmo.apply_mood(view[5])
			world.atmo._bolt_t = 100.0
			world.atmo._flash = 0.0
		world.cam.dist = view[2]
		world.cam.target_dist = view[2]
		world.cam.pitch_deg = view[3]
		world.cam.yaw = view[4]
		world.cam.focus_pos = view[1]
		world.cam._apply()
		for warmup in 90:
			await process_frame
		while world.structure_view != null and world.structure_view.warming():
			await process_frame
		var folder: String = output + "/view-%d" % index
		assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
		for frame in 120:
			var phase := float(frame) / 119.0
			# Gentle orbit returns to its start, leaving surfaces readable throughout.
			world.cam.yaw = float(view[4]) + sin(phase * TAU) * 0.065
			world.cam.focus_pos = view[1]
			world.cam._apply()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder + "/%04d.png" % frame) == OK)
		records.append({"label": view[0], "focus": str(view[1]), "zoom": view[2], "pitch": view[3], "yaw": view[4], "orbit_radians": 0.065, "fov": world.cam.cam.fov, "seconds": 4, "frames": 120})
		print("MOTION_VIEW ", mode, " ", index)
		index += 1
	var metadata := {"arguments": OS.get_cmdline_args(), "user_arguments": OS.get_cmdline_user_args(), "stage": mode, "seed": 3, "preset": "high", "mood": "day", "renderer": RenderingServer.get_current_rendering_method(), "resolution": str(root.size), "fps": 30, "simulation": "Held at two seconds; native camera, wind and water remain animated. Not a combat or performance benchmark.", "views": records}
	var file := FileAccess.open(output + "/capture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	quit()
