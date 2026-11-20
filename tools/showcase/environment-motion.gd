extends SceneTree
## Reproducible native environment fly-throughs. Launch at fixed 30 Hz.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var mode := "stones"
	var output := "build/media-review"
	var frames := 120
	var fps := 30
	var warmup_frames := 90
	var defer_draw := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-stage="):
			mode = arg.get_slice("=", 1)
		if arg.begins_with("--motion-output="):
			output = arg.get_slice("=", 1)
		if arg.begins_with("--motion-frames="): frames = maxi(2, int(arg.get_slice("=", 1)))
		if arg.begins_with("--motion-fps="): fps = maxi(1, int(arg.get_slice("=", 1)))
		if arg.begins_with("--motion-warmup="): warmup_frames = maxi(2, int(arg.get_slice("=", 1)))
		if arg == "--motion-defer-draw": defer_draw = true
	if defer_draw: RenderingServer.set_render_loop_enabled(false)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	print("MOTION_WORLD_READY time=", game.world.time)
	var world = game.world
	world.set_physics_process(false)
	world.cam.set_process(false)
	world.cam.edge_pan = false
	world.cam.cam.fov = 35.0
	if world.director:
		world.director.active = false
	var views := []
	match mode:
		"parking":
			views = [["Seed 3: occupied and empty bays", Vector3(-6.8,0,20.3), 19.0, -36.0, -1.0],
				["Street clearance at command height", Vector3(-6.8,0,20.3), 38.0, -50.0, -1.0]]
		"clouds":
			world.cam.cam.fov = 55.0
			for mood in ["day", "golden", "rain", "night"]:
				views.append([mood.capitalize(), Vector3(0, 80, 0), 1250.0, -10.0, 0.7, mood])
		"stones":
			views = [["Fractured stone detail", Vector3(311.6891,0,433.3651), 12.0, -50.0, 0.7],
				["Stones within the alpine slope", Vector3(311.6891,0,433.3651), 42.0, -42.0, 0.7]]
		"shore":
			views = [["Gravel, wet margins and exposed sand", Vector3(330,0,0), 48.0, -45.0, 0.7],
				["Coastal town context", Vector3(330,0,0), 100.0, -45.0, 0.7]]
		"town":
			views = [["Photographed surfaces and door paths", Vector3(-30,0,-12), 35.0, -50.0, 0.7],
				["Town plots and connected streets", Vector3.ZERO, 190.0, -40.0, 0.7]]
		"church":
			for st in world.structures:
				if st.skind == "church":
					views = [["Church entrances from the road", st.position, 48.0, -30.0, st.yaw + PI + 0.6],
						["Churchyard at command height", st.position, 75.0, -55.0, st.yaw + PI + 0.6]]
		"square":
			views = [["Bench and fence support clearance", Vector3(-1, 0, 12), 10.0, -26.0, 2.6]]
			for piece: Array in world.decor:
				if piece[0] in ["fountain", "statue"]:
					views.append(["Square at command height", piece[1], 42.0, -55.0, 0.7])
					break
		"environment":
			world.cam.cam.fov = 55.0
			views = [["Alpine ranges, ocean and forest coverage", Vector3.ZERO, 900.0, -22.0, 0.7],
				["Calibrated roofs, asphalt and frontages", Vector3(-30,0,-12), 55.0, -45.0, 0.7],
				["Finer meadow and clustered shrubs", Vector3(-110,0,-130), 22.0, -35.0, 0.7]]
	assert(not views.is_empty())
	var orbit := 0.0 if mode == "clouds" else 0.065
	var records := []
	var index := 0
	for view in views:
		if mode == "clouds":
			world.atmo.apply_mood(view[5])
			world.atmo._bolt_t = 100.0
			world.atmo._flash = 0.0
		if defer_draw: RenderingServer.set_render_loop_enabled(false)
		world.cam.dist = view[2]
		world.cam.target_dist = view[2]
		world.cam.pitch_deg = view[3]
		world.cam.yaw = view[4]
		world.cam.focus_pos = view[1]
		world.cam._apply()
		print("MOTION_PREPARE view=", index)
		if defer_draw:
			for prepare in 2: await process_frame
			while world.structure_view != null and world.structure_view.warming(): await process_frame
			RenderingServer.set_render_loop_enabled(true)
		print("MOTION_RENDER_WARMUP view=", index)
		for warmup in warmup_frames:
			await process_frame
		while world.structure_view != null and world.structure_view.warming():
			await process_frame
		var folder: String = output + "/view-%d" % index
		assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder + "/checkpoint.png") == OK)
		var camera_frames := []
		for frame in frames:
			var phase := float(frame) / float(frames - 1)
			# Gentle orbit returns to its start, leaving surfaces readable throughout.
			world.cam.yaw = float(view[4]) + sin(phase * TAU) * orbit
			world.cam.focus_pos = view[1]
			world.cam._apply()
			camera_frames.append(str(world.cam.cam.global_transform))
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder + "/%04d.png" % frame) == OK)
		records.append({"label": view[0], "focus": str(view[1]), "zoom": view[2], "pitch": view[3], "yaw": view[4], "orbit_radians": orbit, "fov": world.cam.cam.fov, "seconds": float(frames) / fps, "frames": frames, "camera": str(world.cam.cam.global_transform), "simulation_time": world.time, "camera_frames": camera_frames})
		print("MOTION_VIEW ", mode, " ", index)
		FileAccess.open(output + "/views.json", FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
		index += 1
	var metadata := {"arguments": OS.get_cmdline_args(), "user_arguments": OS.get_cmdline_user_args(), "stage": mode, "source_ref": OS.get_environment("FL_CAPTURE_REF"), "exposure": world.atmo.env.tonemap_exposure, "tonemap": world.atmo.env.tonemap_mode, "sun": str(world.atmo.sun.global_transform), "seed": 3, "preset": str(root.get_node("Settings").preset), "mood": "day", "renderer": RenderingServer.get_current_rendering_method(), "resolution": str(root.size), "fps": fps, "simulation": "Held at two seconds; native wind and water remain animated. Not a combat or performance benchmark.", "views": records}
	var file := FileAccess.open(output + "/capture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	quit()
