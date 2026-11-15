extends SceneTree
## Native generated-world review: matched views, one map build, simulation held at two seconds.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var source_hashes := _source_hashes()
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
	var capture_views := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-views="):
			capture_views = arg.get_slice("=", 1).split(",")
		if arg.begins_with("--capture-clip="):
			clip = arg.get_slice("=", 1)
		if arg.begins_with("--capture-prefix="):
			prefix = arg.get_slice("=", 1)
	assert(DirAccess.make_dir_recursive_absolute(prefix.get_base_dir()) == OK)
	if "--capture-set=trench-build" in OS.get_cmdline_user_args():
		await _trench_build(world, prefix)
		quit()
		return
	var heights: PackedFloat32Array = world.terrain.landform.heights
	assert(not heights.is_empty() or "--capture-set=trenches" in OS.get_cmdline_user_args() or "--capture-set=fortifications" in OS.get_cmdline_user_args() or "--capture-set=woodland" in OS.get_cmdline_user_args(), "The environment stage needs a generated alpine map")
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
		# a shop's front, from across the pavement
		for piece: Array in world.decor:
			if piece[0] == "awning" and town.has_point(Vector2(piece[1].x, piece[1].z)):
				views.append(["shopfront", piece[1], 16.0, -32.0, float(piece[2]) + PI + 0.5])
				break
		# the central crossroads close up, the square, a car park from the street
		views.append(["crossroads", center, 24.0, -48.0, 0.7])
		for piece: Array in world.decor:
			if piece[0] in ["fountain", "statue"]:
				views.append(["square", piece[1], 26.0, -45.0, 0.7])
				break
		for piece: Array in world.decor:
			if piece[0] == "lot_pave":
				views.append(["carpark", piece[1], 22.0, -38.0, float(piece[2]) + PI * 0.5 + 0.4])
				break
		# a farmstead off the country road (its hay stacked by the barn)
		for piece: Array in world.decor:
			if piece[0] == "hay":
				views.append(["farm", piece[1], 34.0, -42.0, 0.7])
				break
		print("CAPTURE town bounds=", town)
	if "--capture-set=trenches" in OS.get_cmdline_user_args():
		views = [["trenches", Vector3(0, 0, -28), 24.0, -48.0, 0.5]]
	if "--capture-set=fortifications" in OS.get_cmdline_user_args():
		views = [["earthwork", Vector3(0, 0, -28), 13.0, -38.0, 0.5],
			["cut", Vector3(3, -0.6, -28), 5.5, -23.0, 0.5],
			["inside", Vector3(3, -0.6, -28), 5.5, -23.0, 0.5],
			["bunker", Vector3(0, 0, -58), 14.0, -32.0, -0.65],
			["position", Vector3(0, 0, -40), 55.0, -50.0, 0.35]]
	if "--slope-review" in OS.get_cmdline_user_args():
		assert(not heights.is_empty(), "Slope review requires generated geology")
		var target := Vector3(-110, 0, -130)
		var best := INF
		for x in range(-180, -70, 10):
			for z in range(-180, -70, 10):
				var point := Vector3(x, 0, z)
				var grade: float = absf(world.terrain.landform.height(point + Vector3.RIGHT * 6.0) - world.terrain.landform.height(point - Vector3.RIGHT * 6.0)) / 12.0
				if grade > 0.08 and grade < 0.18 and point.distance_squared_to(Vector3(-110, 0, -130)) < best:
					target = point
					best = point.distance_squared_to(Vector3(-110, 0, -130))
		assert(best < INF, "Review seed must provide a useful moderate slope")
		# Clear only this review footprint so foliage cannot hide foundation gaps.
		for obstacle in world.structures.duplicate():
			var offset: Vector3 = obstacle.position - target - Vector3(0,0,4)
			if obstacle.skind == "tree" and Vector2(offset.x, offset.z).length() < 17.0:
				world.despawn(obstacle)
		target.y = world.terrain.landform.height(target)
		world.spawn("structure", {"skind": "trench", "team": 1, "pos": target, "yaw": 0.0, "built": true, "progress": 1.0})
		var bunker_pos := target + Vector3(0, 0, 9)
		bunker_pos.y = world.terrain.landform.height(bunker_pos)
		world.spawn("structure", {"skind": "bunker", "team": 1, "pos": bunker_pos, "yaw": 0.0, "built": true, "progress": 1.0})
		world.terrain.tick(1 << 30)
		world.atmo.trench_net.mark_dirty()
		world.atmo.trench_net.rebuild()
		views = [["earthwork", target, 18.0, -38.0, 0.5], ["cut", target + Vector3(0,-0.6,0), 6.0, -23.0, 0.5],
			["bunker", bunker_pos, 16.0, -32.0, -0.65], ["position", target, 45.0, -50.0, 0.35]]
		print("SLOPE_REVIEW ", target, " bunker=", bunker_pos)
	var settle_frames := 90
	if "--capture-set=woodland" in OS.get_cmdline_user_args():
		if "--woodland-before" in OS.get_cmdline_user_args():
			world.atmo.grass.woodland = null
			world.atmo.grass.request_rebuild(0.01)
		var stand := Vector3(-28, 0, -20)
		if "--woodland-generated" in OS.get_cmdline_user_args():
			var density := 0
			for tree in world.structures:
				if tree.skind != "tree" or tree.gone or world.town_rect.grow(30.0).has_point(Vector2(tree.position.x, tree.position.z)):
					continue
				var count := 0
				for neighbor in world.structures_near(tree.position, 15.0):
					if neighbor.skind == "tree":
						count += 1
				if count > density:
					density = count
					stand = tree.position
			print("WOODLAND stand=", stand, " trees=", density)
		views = [["floor", stand, 12.0, -32.0, 0.6], ["stand", stand, 30.0, -42.0, 0.6], ["eye", stand, 12.0, -8.0, 0.6]]
		settle_frames = 180
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
		views.append(["shore-join", Vector3(world.water.coast_x(MapDims.HALF), 0, MapDims.HALF), 180.0, -30.0, 0.7, 3, "day"])
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
	if "--capture-set=coast-join" in OS.get_cmdline_user_args():
		views = [["shore-join", Vector3(world.water.coast_x(MapDims.HALF), 0, MapDims.HALF), 180.0, -30.0, 0.7, 3, "day"]]
	if "--weather-review" in OS.get_cmdline_user_args() and "--capture-set=fortifications" in OS.get_cmdline_user_args():
		var base_views := views.duplicate(true)
		views = []
		for mood in ["day", "overcast", "rain", "night"]:
			for index in [0, 1, 3]:
				var view: Array = base_views[index].duplicate()
				view[0] = String(view[0]) + "-" + mood
				view.append(3)
				view.append(mood)
				views.append(view)
		settle_frames = 120
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var records := []
	for view in views:
		if not capture_views.is_empty() and view[0] not in capture_views:
			continue
		if view.size() > 6:
			world.atmo.apply_mood(view[6])
			if "--weather-review" in OS.get_cmdline_user_args():
				world.atmo.rain_wet = -1.0
				world.atmo._wet_tick(0.0)
		if view.size() > 5:
			get_root().get_node("Settings").v.mountain_clouds = view[5]
			world.atmo.mountain_clouds.apply_settings(world.atmo)
		world.cam.cam.rotation = Vector3.ZERO
		world.cam.dist = view[2]
		world.cam.target_dist = view[2]
		world.cam.pitch_deg = view[3]
		world.cam.yaw = view[4]
		world.cam.focus_pos = view[1]
		world.cam._apply()
		if String(view[0]).begins_with("cut"):
			world.cam.position = view[1]
		if view[0] == "inside":
			world.cam.cam.global_position = Vector3(0.8, 0.02, -28.0)
			world.cam.cam.look_at(Vector3(4.8, -0.5, -28.3))
		if view[0] == "eye":
			var target: Vector3 = view[1] + Vector3(1.5, 0, 1.0)
			target.y = world.ground_y(target) + 2.0
			for angle in [0.6, 1.2, -0.6, -1.2]:
				var eye: Vector3 = view[1] + Vector3(sin(angle), 0, cos(angle)) * 12.0
				var clear := true
				for tree in world.structures_near(eye, 2.0):
					if tree.skind == "tree":
						clear = false
				if clear:
					eye.y = world.ground_y(eye) + 1.75
					world.cam.cam.global_position = eye
					world.cam.cam.look_at(target)
					break
		if String(view[0]).begins_with("detail-"):
			var subject: Vector3 = view[1]
			subject.y = world.ground_y(subject) + (0.8 if view[0] == "detail-4" else 0.18)
			# Photo close-ups bypass the RTS camera's minimum ground clearance.
			var offset := Vector3(1.4, 1.0, 1.6)
			if view[0] == "detail-13":
				subject.y += 1.0
				offset = Vector3(2.7, 1.1, 3.0)
			elif view[0] == "detail-1":
				offset = Vector3(2.7, 2.4, -2.7)
			elif view[0] == "detail-4":
				offset = Vector3(1.0, 0.6, 1.0)
			world.cam.cam.global_position = subject + offset
			world.cam.cam.look_at(subject)
		if world.atmo.mood == "rain":
			world.atmo._bolt_t = 100.0
			world.atmo._flash = 0.0
		for frame in (60 if String(view[0]).begins_with("detail-") else settle_frames):
			await process_frame
		while world.structure_view != null and world.structure_view.warming():
			await process_frame
		if "--capture-set=woodland" in OS.get_cmdline_user_args() and world.atmo.grass.woodland:
			var details := []
			details.resize(world.atmo.grass.woodland.meshes.size())
			details.fill(0)
			var subjects := {}
			for chunk: Array in world.atmo.grass._built.values():
				for node: MultiMeshInstance3D in chunk:
					var kind: int = world.atmo.grass.woodland.materials.find(node.material_override)
					if kind >= 0:
						details[kind] += node.multimesh.instance_count
						for i in node.multimesh.instance_count:
							var candidate := node.multimesh.get_instance_transform(i).origin
							if not subjects.has(kind) or candidate.distance_squared_to(view[1]) < (subjects[kind] as Vector3).distance_squared_to(view[1]):
								subjects[kind] = candidate
			print("WOODLAND instance counts by mesh: ", details)
			if view[0] == "floor":
				for kind in [0, 1, 3, 4, 6, 7, 9, 11, 13, 17]:
					if subjects.has(kind):
						views.append(["detail-%d" % kind, subjects[kind], 3.0, -28.0, 0.6])
		var frame_ms := 0.0
		var gpu_ms := 0.0
		if view.size() > 5 or "--capture-benchmark" in OS.get_cmdline_user_args():
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
				if "--capture-set=fortifications" in OS.get_cmdline_user_args():
					world.cam.yaw = float(view[4]) + 0.18 * sin(float(frame) * TAU / 180.0)
					world.cam._apply()
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(frames + "/%04d.png" % frame) == OK)
		records.append({"file": filename, "focus": str(view[1]), "zoom": view[2], "pitch": view[3], "yaw": view[4], "camera": str(world.cam.cam.global_transform), "camera_position": str(world.cam.cam.global_position), "camera_rotation": str(world.cam.cam.global_rotation), "time": world.time, "wetness": world.atmo.rain_wet, "mood": world.atmo.mood, "cloud_quality": get_root().get_node("Settings").v.mountain_clouds, "frame_ms": frame_ms, "gpu_ms": gpu_ms, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("CAPTURE ", filename)
	assert(source_hashes == _source_hashes(), "Capture source changed during rendering; discard this take")
	var output := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"seed": world.settings.get("seed", 1), "mood": world.atmo.mood, "renderer": RenderingServer.get_current_rendering_method(), "resolution": root.size, "source_sha256": source_hashes, "views": records}, "\t"))
	quit()


## Real builder orders at 30 Hz, sampled at 10 fps; no accelerated construction.
func _trench_build(world, prefix: String) -> void:
	var pos := Vector3(-90, 0, 80)
	var st = world.spawn("structure", {"skind": "trench", "team": 0, "pos": pos, "built": false, "progress": 0.0})
	var squad = world.rules.spawn_squad("engineer_team", 0, 1, pos + Vector3(0, 0, 3))
	squad.order_work(st)
	world.cam.dist = 13.0
	world.cam.target_dist = 13.0
	world.cam.pitch_deg = -38.0
	world.cam.yaw = 0.35
	world.cam.focus(pos)
	for frame in 90:
		await process_frame
	var frames := prefix + "-frames"
	assert(DirAccess.make_dir_recursive_absolute(frames) == OK)
	var records := []
	for frame in 300:
		if frame == 180:
			st.take_damage(st.max_hp * 0.9)
			squad.order_work(st)
		for tick in 3:
			world._simulate(1.0 / 30.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		assert(shot.save_png(frames + "/%04d.png" % frame) == OK)
		if frame in [10, 60, 150, 190, 299]:
			shot.save_png(prefix + "-%03d.png" % frame)
			records.append({"frame": frame, "progress": st.progress, "hp": st.hp, "built": st.built})
	print("TRENCH_CAPTURE ", JSON.stringify(records))
	var output := FileAccess.open(prefix + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"fps": 10, "simulation_hz": 30, "damage_at": 18, "records": records}, "\t"))


func _source_hashes() -> Dictionary:
	var hashes := {}
	if "--capture-set=fortifications" in OS.get_cmdline_user_args():
		for path in ["scripts/game/trench_net.gd", "scripts/game/trench_earth.gdshaderinc", "scripts/game/works_models.gd", "scripts/game/structure.gd", "scripts/game/grass.gd", "scripts/game/trench_vegetation.gdshaderinc", "scripts/game/atmosphere.gd", "scripts/game/mapgen.gd", "scripts/game/mats.gd", "tests/fixtures/environment-views.gd"]:
			hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes
