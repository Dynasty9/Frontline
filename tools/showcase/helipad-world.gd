extends SceneTree
## Matched, inert in-world pad views. No generated units or flight simulation.
## Run at --fixed-fps 15; encode the saved frames at 15 fps.
## --view=normal,mat-detail,concrete-detail,windsocks selects views.
## --smoke saves one frame per view; --output=DIR chooses the capture directory.
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var output := OS.get_user_data_dir().path_join("helipad-review")
	var frames := 30
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.get_slice("=",1)
		if arg == "--smoke": frames=1
		if arg.begins_with("--view="): selected=arg.get_slice("=",1)
	DirAccess.make_dir_recursive_absolute(output)
	var settings = root.get_node("Settings")
	settings.apply_preset("high",false)
	settings.v["mood"]="day"
	settings.v["perf"]=0
	root.size=Vector2i(960,540)
	DisplayServer.window_set_size(Vector2i(960,540))
	RenderingServer.render_loop_enabled=false
	Engine.time_scale=0.0
	var world = load("res://scripts/game/world.gd").new()
	world.settings={"seed":4,"mood":"day","scenario":"inert-pad-review","map_size":1024}
	root.add_child(world)
	current_scene=world
	world.set_physics_process(false)
	world.set_process(false)
	world.nav=load("res://scripts/game/nav.gd").new()
	world.nav.terrain=world.terrain
	world.time=8.0
	world.cam=load("res://scripts/game/rts_camera.gd").new()
	world.cam.world=world
	world.add_child(world.cam)
	world.cam.set_process(false)
	world.cam.edge_pan=false
	var pads := []
	for i in 2:
		world.next_eid=100+i
		var pad=world.spawn("structure",{"skind":"helipad","team":i,"owner":-1,"pos":Vector3(-9 if i==0 else 9,0,0),"yaw":0.0 if i==0 else PI*0.5})
		pads.append(pad)
	world.terrain.tick(1<<30)
	print("PAD_SCENE_READY")
	assert(world.soldiers.is_empty() and world.vehicles.is_empty() and world.projectiles.is_empty())
	var views := [["normal",Vector3.ZERO,55.0,-48.0,0.45],["mat-detail",Vector3(-9,0,0),19.0,-48.0,0.45],["concrete-detail",Vector3(9,0,0),19.0,-48.0,0.45]]
	views.append(["windsocks",Vector3(0,3,-5.2),18.0,-28.0,0.45])
	if selected != "": views=views.filter(func(v): return v[0] in selected.split(","))
	var records := []
	var first_view := true
	for view in views:
		var camera=world.cam
		camera.focus_pos=view[1]
		camera.dist=view[2]
		camera.target_dist=view[2]
		camera.pitch_deg=view[3]
		camera.yaw=view[4]
		camera._apply()
		for i in (24 if first_view else 4): await process_frame
		RenderingServer.render_loop_enabled=true
		var probes=world.atmo.light_probes
		if first_view and probes != null and probes.quality>0:
			probes._base_drawn=false
			probes._requeue_all_bricks()
			print("PAD_PROBE_WARMUP")
			for bake_frame in 512:
				await process_frame
				await RenderingServer.frame_post_draw
				if bake_frame % 32 == 0: print("PAD_PROBE_FRAME ",bake_frame)
				if probes._tile_queue.is_empty() and probes._brick_queue.is_empty() and probes._light_queue.is_empty() and probes._local_queue.is_empty(): break
			assert(probes._brick_queue.is_empty())
		first_view=false
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		print("PAD_VIEW_READY ",view[0])
		var dest: String=output+"/"+view[0]
		DirAccess.make_dir_recursive_absolute(dest)
		for frame in frames:
			camera.yaw=float(view[4])+0.12*sin(TAU*frame/maxf(frames-1,1))
			camera._apply()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dest+"/%04d.png"%frame)
			records.append({"view":view[0],"frame":frame,"focus":str(camera.focus_pos),"distance":camera.dist,"pitch":camera.pitch_deg,"yaw":camera.yaw,"world_time":world.time})
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"seed":4,"mood":"day","preset":"high","pads":[{"eid":100,"team":0,"yaw":0},{"eid":101,"team":1,"yaw":PI*0.5}],"records":records,"fps":15,"fixture":"In-world idle pad fixture using actual World terrain, Atmosphere, Structure and RTS camera. Flat terrain, two pads, no units, simulation or flight. Frozen weather phase; camera orbit only."},"\t"))
	print("PAD_CAPTURE_COMPLETE")
	quit()
