extends SceneTree
## Actual game, fixed camera and lighting; start near a weather-cell boundary.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	RenderingServer.render_loop_enabled = false
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 1.0:
		await process_frame
	var world = game.world
	Engine.time_scale = 0.0
	world.cam.set_process(false)
	world.cam.edge_pan = false
	world.cam.target_dist = 120.0
	world.cam.dist = 120.0
	world.cam.pitch_deg = -7.0
	world.cam.yaw = 4.5
	world.cam.set("_shake", 0.0)
	var center := Vector2(world.water.coast_x(70.0), 70.0)
	world.cam.focus(Vector3(center.x, 0.0, center.y))
	if world.director:
		world.director.active = false
	var view = world.structure_view
	view.focus_at(world.cam.focus_pos, world.cam.cam)
	for i in 20000:
		await process_frame
		if not view.warming() and view._vehicle_jobs.is_empty():
			break
	assert(not view.warming() and view._vehicle_jobs.is_empty(), "Scenery did not settle")
	print("DRIFT scenery settled: ",view.active.size())
	var air = world.atmo.air
	air._process(0.0)
	air.set_process(false)  # only the controlled grid step advances weather
	var grid = air.grid
	grid.drift = grid._wind / maxf(absf(grid._wind.x), absf(grid._wind.y)) * (grid.cell - 0.5)
	grid._row = 0
	grid._sweep_dt = 0.0
	grid._upload_all()
	RenderingServer.render_loop_enabled = true
	for i in 20:
		await process_frame
	var out := OS.get_environment("FL_DRIFT_CAPTURE")
	DirAccess.make_dir_recursive_absolute(out)
	var record := FileAccess.open(out.path_join("camera.json"), FileAccess.WRITE)
	var xf: Transform3D = world.cam.cam.global_transform
	record.store_string(JSON.stringify({"fps": 30, "origin": [xf.origin.x, xf.origin.y, xf.origin.z],
		"basis": [xf.basis.x.x, xf.basis.x.y, xf.basis.x.z, xf.basis.y.x, xf.basis.y.y, xf.basis.y.z, xf.basis.z.x, xf.basis.z.y, xf.basis.z.z],
		"initial_drift": [grid.drift.x, grid.drift.y], "effective_map_size": MapDims.SIZE, "scenery_active": view.active.size(), "grid_phase": grid._air_t}, "  "))
	record.close()
	print("DRIFT CAPTURE starting: ", grid.drift)
	for i in 60:
		assert(not view.warming() and view._vehicle_jobs.is_empty(), "Scenery changed during capture")
		grid.tick(1.0 / 30.0)
		air.mat.set_shader_parameter("drift", grid.drift)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("frame_%03d.png" % i))
	print("DRIFT CAPTURE complete")
	quit()
