extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	RenderingServer.render_loop_enabled = false
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 8.0:
		await process_frame
	var world = game.world
	Engine.time_scale = 0.0
	var cam = world.cam
	cam.set_process(false)
	cam.edge_pan = false
	if world.director:
		world.director.active = false
	var center := Vector3(1.0,0.0,-34.25)
	cam.target_dist = 9.0
	cam.dist = 9.0
	cam.pitch_deg = -32.0
	cam.yaw = 1.57
	cam.set("_shake",0.0)
	cam.focus(center)
	var view = world.structure_view
	view.focus_at(cam.focus_pos,cam.cam)
	for i in 20000:
		await process_frame
		if not view.warming() and view._vehicle_jobs.is_empty():
			break
	assert(not view.warming() and view._vehicle_jobs.is_empty())
	RenderingServer.render_loop_enabled = true
	# Drawing was disabled while scenery built; replay GPU atlas work that
	# the probe scheduler may have consumed without rendering it.
	var probes = world.atmo.light_probes
	if probes != null and probes.quality > 0:
		probes._base_drawn = false
		probes._requeue_all_bricks()
		for bake_frame in 512:
			await process_frame
			await RenderingServer.frame_post_draw
			if bake_frame % 10 == 0:
				print("PROBE pending ",probes._brick_queue.size()," local ",probes._local_queue.size()," light ",probes._light_queue.size())
			if probes._tile_queue.is_empty() and probes._brick_queue.is_empty() and probes._light_queue.is_empty() and probes._local_queue.is_empty():
				break
		assert(probes._brick_queue.is_empty(), "Probe GPU bake did not settle")
		print("PROBE GPU bake complete: ",probes.traced)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("FL_FOLLOW_CAPTURE")
	DirAccess.make_dir_recursive_absolute(out)
	var records: Array = []
	# A normal squad move from the open mouth into the alley, identical in both builds.
	for squad in world.squads.values():
		var c: Vector3 = squad.centroid()
		if c.x < -8.0 and absf(c.z + 34.25) < 5.0:
			squad.order_move(Vector3(-2.5,0.0,-34.25),Vector3(1,0,0),1,false)
	Engine.time_scale = 1.0
	for i in 90:
		var t := float(i)/89.0
		cam.target_dist = 9.0
		cam.dist = cam.target_dist
		cam.pitch_deg = -32.0
		cam.yaw = 1.57
		cam.set("_shake",0.0)
		cam.focus(center + Vector3(-t*8.0,0.0,0.0))
		await process_frame
		await RenderingServer.frame_post_draw
		var xf: Transform3D = cam.cam.global_transform
		records.append({"frame":i,"time":world.time,"origin":[xf.origin.x,xf.origin.y,xf.origin.z],
			"basis":[xf.basis.x.x,xf.basis.x.y,xf.basis.x.z,xf.basis.y.x,xf.basis.y.y,xf.basis.y.z,xf.basis.z.x,xf.basis.z.y,xf.basis.z.z],"scenery":view.active.size(),"warming":view.warming()})
		var men: Array = []
		for squad in world.squads.values():
			for man in squad.members:
				men.append_array([man.position.x,man.position.y,man.position.z])
		records[-1]["men"] = men
		root.get_texture().get_image().save_png(out.path_join("frame_%03d.png" % i))
		if i%30 == 0:
			print("ALLEY frame ",i," time ",world.time," scenery ",view.active.size()," warming ",view.warming())
	var record := FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE)
	record.store_string(JSON.stringify({"fps":30,"frames":records},"  "))
	record.close()
	print("ALLEY complete")
	if OS.get_environment("FL_WALL_SMOKE") == "1":
		await wall_smoke(world,out)
	quit()

func wall_smoke(world, out: String) -> void:
	Engine.time_scale = 0.0
	world.cam.target_dist = 11.0
	world.cam.dist = 11.0
	world.cam.pitch_deg = -48.0
	world.cam.yaw = 1.57
	world.cam.focus(Vector3(0,0,-30))
	for i in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	var wall = null
	var best_d := INF
	for st in world.structures_near(Vector3(4,0,-30),30.0):
		var d: float = Vector2(st.position.x-4.0,st.position.z+30.0).length()
		if not st.gone and st.skind == "house_wall" and d < best_d:
			wall = st
			best_d = d
	assert(wall != null)
	var folder := out.path_join("wall")
	DirAccess.make_dir_recursive_absolute(folder)
	var probes = world.atmo.light_probes
	var traced_before: int = probes.traced
	var record: Array = []
	print("WALL selected ",wall.position," traced ",traced_before)
	Engine.time_scale = 1.0
	for i in 60:
		if i == 30:
			wall.take_damage(wall.hp+1.0)
			print("WALL damaged; pending tiles ",probes._tile_queue.size())
		await process_frame
		await RenderingServer.frame_post_draw
		record.append({"frame":i,"time":world.time,"tiles":probes._tile_queue.size(),"bricks":probes._brick_queue.size(),"traced":probes.traced})
		root.get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % i))
	var f := FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(record,"  "))
	f.close()
	print("WALL complete; traced before ",traced_before," after ",probes.traced)
