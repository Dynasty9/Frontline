extends "res://tools/showcase/building-surfaces.gd"
## Native procedural-model review, with fixed studio light and matched framing.
func _ready() -> void:
	TestRun.watch()
	var take_label := "BEFORE"
	var frame_count := 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-out="): output = arg.get_slice("=", 1)
		if arg.begins_with("--review-label="): take_label = arg.get_slice("=", 1)
		if arg == "--review-sample": frame_count = 2
	DirAccess.make_dir_recursive_absolute(output)
	view_direction = Vector3(0.5, 1.0, -1.35)
	var grid := GridContainer.new()
	add_child(grid)
	_cell(grid, "house_ruin_plaster", Vector2i(1600, 900))
	var camera := grid.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var caption := grid.find_children("*", "Label", true, false)[0] as Label
	var initial := camera.transform
	var initial_size := camera.size
	for warm in 6: await RenderingServer.frame_post_draw
	for frame in frame_count:
		var close := frame > 0 if frame_count == 2 else frame >= 15
		if close:
			var u := 0.5 if frame_count == 2 else float(frame - 15) / 44.0
			var focus := Vector3(0, 1.5, 3.4)
			camera.size = 5.3
			camera.position = focus + view_direction.rotated(Vector3.UP, lerpf(-0.1, 0.1, u)).normalized() * 43.6671
			camera.look_at(focus)
		else:
			camera.transform = initial
			camera.size = initial_size
		caption.text = take_label + " · NATIVE MODEL · " + ("ROOM-SIDE OBLIQUE" if close else "COMMAND HEIGHT")
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(output.path_join("frame-%04d.png" % frame)) == OK)
	print("ROOM_MOTION frames=", frame_count, " renderer=", RenderingServer.get_current_rendering_method())
	grid.free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	TestRun.quit(get_tree())
