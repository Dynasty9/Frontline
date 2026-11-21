extends "res://tools/showcase/building-surfaces.gd"
## Native procedural-model review, with fixed studio light and matched framing.
func _ready() -> void:
	TestRun.watch()
	var take_label := "BEFORE"
	var frame_count := 60
	var command_only := false
	var intact := false
	var geometry_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-out="): output = arg.get_slice("=", 1)
		if arg.begins_with("--review-label="): take_label = arg.get_slice("=", 1)
		if arg == "--review-intact": intact = true
		if arg == "--review-geometry-only": geometry_only = true
		if arg == "--review-sample": frame_count = 2
		if arg == "--review-command-only":
			command_only = true
			frame_count = 15
	DirAccess.make_dir_recursive_absolute(output)
	if geometry_only:
		var fingerprints := {}
		for kind in ["house_ruin_plaster", "house_pitched"]:
			var model := _subject(kind)
			var triangles: Array[String] = []
			_geometry_rows(model, Transform3D.IDENTITY, triangles)
			triangles.sort()
			fingerprints[kind] = {"triangles": triangles.size(), "sha256": "\n".join(triangles).sha256_text()}
			model.free()
		FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE).store_string(JSON.stringify(fingerprints, "  "))
		TestRun.quit(get_tree())
		return
	view_direction = Vector3(0.5, 1.0, -1.35)
	var grid := GridContainer.new()
	add_child(grid)
	_cell(grid, "house_pitched" if intact else "house_ruin_plaster", Vector2i(1600, 900))
	var camera := grid.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var caption := grid.find_children("*", "Label", true, false)[0] as Label
	for warm in 6: await RenderingServer.frame_post_draw
	var records: Array = []
	for frame in frame_count:
		var close := not command_only and (frame > 0 if frame_count == 2 else frame >= 15)
		if close:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			var u := 0.5 if frame_count == 2 else float(frame - 15) / 44.0
			var focus := Vector3(0, 1.5, 3.4)
			camera.size = 5.3
			camera.position = focus + view_direction.rotated(Vector3.UP, lerpf(-0.1, 0.1, u)).normalized() * 43.6671
			camera.look_at(focus)
		else:
			# Use the game's default command zoom, FOV and zoom-dependent pitch.
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 48.0
			var elevation := -deg_to_rad(RtsCamera.pitch_for(55.0, 0.0))
			var yaw := atan2(view_direction.x, view_direction.z)
			camera.position = Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)) * 55.0
			camera.look_at(Vector3.ZERO)
		records.append({"frame": frame, "camera": str(camera.transform), "projection": camera.projection, "fov": camera.fov, "size": camera.size})
		caption.text = take_label + " · NATIVE MODEL · " + ("ROOM-SIDE OBLIQUE" if close else "COMMAND SCALE · 55 M · FOV 48°")
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(output.path_join("frame-%04d.png" % frame)) == OK)
	FileAccess.open(output.path_join("motion.json"), FileAccess.WRITE).store_string(JSON.stringify({"source_ref": OS.get_environment("FL_CAPTURE_REF"), "renderer": RenderingServer.get_current_rendering_method(), "frames": records}, "  "))
	print("ROOM_MOTION frames=", frame_count, " renderer=", RenderingServer.get_current_rendering_method())
	grid.free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	TestRun.quit(get_tree())


## Sorted transformed triangles, rounded to five decimals; independent of materials.
func _geometry_rows(node: Node, parent: Transform3D, rows: Array[String]) -> void:
	var xf: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0, count, 3):
				var points: Array[String] = []
				for j in 3:
					var v: Vector3 = xf * vertices[indices[i+j] if not indices.is_empty() else i+j]
					points.append("%.5f,%.5f,%.5f" % [v.x, v.y, v.z])
				points.sort()
				rows.append(";".join(points))
	for child in node.get_children(): _geometry_rows(child, xf, rows)
