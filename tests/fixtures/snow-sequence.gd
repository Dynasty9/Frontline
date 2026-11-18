extends SceneTree
## Actual gameplay updates at 24 Hz; only rendering is skipped for time lapse.
## No thaw spots, track marks or surface colours are painted by this fixture.
var world
var tank
var prefix := "build/snow-sequence"
var records := []

func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	call_deferred("capture")

func capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-prefix="):
			prefix = arg.get_slice("=", 1)
	assert(DirAccess.make_dir_recursive_absolute(prefix) == OK)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	world = game.world
	# Do not consume atlas bake batches while their viewport is not drawn.
	world.atmo.light_probes.set_process(false)
	if world.director:
		world.director.active = false
	world.cam.set_process(false)
	world.cam.edge_pan = false
	_camera(Vector3(400, 0, 399), 26.0, -38.0)
	for x in [396.0, 400.1, 404.2]:
		world.spawn("structure", {"skind": "low_wall", "team": -1, "pos": Vector3(x, 0, 394), "yaw": 0.0, "size": Vector3(4, 1, 0.9), "variant": 1})
	tank = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": 1, "pos": Vector3(387, 0, 400), "yaw": -PI * 0.5})
	tank.order_stop()
	tank.always_animate_tracks = true
	await _advance(48)
	await _prepare_probes()
	await _shot("control", 0)
	if "--snow-diagnostic" in OS.get_cmdline_user_args():
		await _diagnostic()
		_write_records()
		quit()
		return
	if "--sequence-smoke" in OS.get_cmdline_user_args():
		_write_records()
		quit()
		return
	tank.order_move(Vector3(405, 0, 400))
	for i in 48:
		await _advance(3)
		await _shot("rolling", i)
	tank.order_stop()
	await _advance(24)
	await _shot("parked-start", 0)
	for i in 32:
		await _advance(71)
		await _shot("idle", i)
	await _shot("parked-end", 0)
	tank.order_move(Vector3(416, 0, 400))
	for i in 24:
		await _advance(3)
		await _shot("reveal", i)
	_write_records()
	quit()

func _camera(focus: Vector3, zoom: float, pitch: float) -> void:
	world.cam.focus_pos = focus
	world.cam.dist = zoom
	world.cam.target_dist = zoom
	world.cam.pitch_deg = pitch
	world.cam.yaw = 0.0
	world.cam._apply()

func _advance(ticks: int) -> void:
	for tick in ticks:
		await process_frame

func _shot(phase: String, frame: int) -> void:
	# Resume after node _process updates, then draw exactly this state.
	await process_frame
	world.atmo.light_probes._process(1.0 / 24.0)
	RenderingServer.force_draw(false, 1.0 / 24.0)
	assert(root.get_texture().get_image().save_png(prefix + "/%s-%04d.png" % [phase, frame]) == OK)
	var spots := []
	if world.atmo.snow_melt:
		for s in world.atmo.snow_melt.spots:
			if int(s[5]) == -1 - tank.eid or Vector2(s[0] - 400, s[1] - 400).length() < 25.0:
				spots.append([s[0], s[1], s[2], s[3], s[5]])
	if phase == "control":
		assert(spots.is_empty(), "Undisturbed powder must not inherit a shader warm-up thaw")
	if phase == "parked-end":
		var engine_thaw := 0.0
		for spot in spots:
			if int(spot[4]) == -1 - tank.eid:
				engine_thaw = float(spot[3])
		assert(engine_thaw >= 0.45, "A long real idle must produce visible slush")
	var prints: int = world.fx.vfx._tread_prints.visible_instance_count if world.fx.vfx._tread_prints else 0
	records.append({"phase": phase, "frame": frame, "time": world.time, "tank": [tank.position.x, tank.position.y, tank.position.z], "engine_run": tank._engine_run, "spots": spots, "tread_instances": prints})
	print("SNOW_SEQUENCE ", JSON.stringify(records[-1]))

func _write_records() -> void:
	var output := FileAccess.open(prefix + "/records.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "camera": str(world.cam.cam.global_transform), "fixed_fps": 24, "playback_fps": 12, "rates": {"rolling": 2, "idle": 36, "reveal": 2}, "source_hashes": {"vfx": FileAccess.get_sha256("res://scripts/game/vfx.gd"), "snow_melt": FileAccess.get_sha256("res://scripts/game/snow_melt.gd"), "fixture": FileAccess.get_sha256("res://tests/fixtures/snow-sequence.gd")}, "records": records}, "\t"))


## Diagnostic images only: never splice these material overrides into gameplay footage.
func _diagnostic() -> void:
	_camera(Vector3(400, 0, 394), 18.0, -20.0)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var ground: ShaderMaterial = world.atmo.ground_mat
	var bank: ShaderMaterial = world.atmo.snow_drift._mat
	var ground_original: Shader = ground.shader
	var bank_original: Shader = bank.shader
	for lighting in ["snow", "day"]:
		world.atmo.apply_mood(lighting)
		# Frozen snow after the weather clears, to compare sunny and overcast light.
		RenderingServer.global_shader_parameter_set("snow_cover", 1.0)
		var probes = world.atmo.light_probes
		probes.relight()
		for warm in 48:
			probes._process(1.0 / 24.0)
			RenderingServer.force_draw(false, 1.0 / 24.0)
			await process_frame
			if probes._tile_queue.is_empty() and probes._brick_queue.is_empty() and probes._light_queue.is_empty():
				break
		print("SNOW_PROBE_STATE ", lighting, " quality=", probes.quality, " tiles=", probes._tile_queue.size(), " bricks=", probes._brick_queue.size(), " relight=", probes._light_queue.size())
		for treatment in ["baseline", "probes-off", "flat-normals", "equal-albedo", "flat-equal"]:
			var g: String = ground_original.code
			var b: String = bank_original.code
			if treatment in ["flat-normals", "flat-equal"]:
				g = g.replace("NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);", "NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);")
				b = b.replace("NORMAL = normalize(vec3(-(xp - xn) * 1.4, 2.0, -(zp - zn) * 1.4));", "NORMAL = vec3(0.0, 1.0, 0.0);")
			if treatment in ["equal-albedo", "flat-equal"]:
				g = g.replace("ALBEDO = col * (1.0 - aerial);", "ALBEDO = vec3(0.5);")
				b = b.replace("if (OUTPUT_IS_SRGB) {\n\t\tcol =", "col = vec3(0.5);\n\tif (OUTPUT_IS_SRGB) {\n\t\tcol =")
			ground.shader = Shader.new()
			ground.shader.code = g
			bank.shader = Shader.new()
			bank.shader.code = b
			RenderingServer.global_shader_parameter_set("probe_mix", Vector4(0, 0, 0, 1) if treatment == "probes-off" else Vector4(1, 0.8, 0, 1))
			await _shot("diagnostic-" + lighting + "-" + treatment, 0)
		ground.shader = ground_original
		bank.shader = bank_original


func _prepare_probes() -> void:
	# Rebuild any atlas batches queued during startup before rendering was enabled.
	# Hold simulation for these preparation draws; they are not footage.
	var mode: int = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var probes = world.atmo.light_probes
	probes._base_drawn = false
	probes._requeue_all_bricks()
	for warm in 48:
		probes._process(1.0 / 24.0)
		RenderingServer.force_draw(false, 1.0 / 24.0)
		await process_frame
		if probes._tile_queue.is_empty() and probes._brick_queue.is_empty() and probes._light_queue.is_empty() and probes._local_queue.is_empty():
			break
	print("SNOW_PROBE_PREPARED quality=", probes.quality, " tiles=", probes._tile_queue.size(), " bricks=", probes._brick_queue.size(), " relight=", probes._light_queue.size())
	assert(probes._tile_queue.is_empty() and probes._brick_queue.is_empty() and probes._light_queue.is_empty(), "Capture requires a completed probe atlas")
	world.process_mode = mode
