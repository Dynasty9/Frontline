extends SceneTree
## Scripted pointer and report exercise over the running attack scenario.
## Captures real controls at --capture-fps (match --fixed-fps); reports are deliberately cued.
func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	var fps := int(game.args.get("capture-fps", 30))
	var world = game.world
	var roster = world.hud.orbat
	root.get_node("Settings").v.perf = 0
	world.cam.edge_pan = false
	world.cam.set_process(false)
	world.cam.cam.global_position = Vector3(8, 60, 98)
	world.cam.cam.look_at(Vector3(0, 0, 34))
	var reserves := []
	for i in 8:
		reserves.append(world.rules.spawn_squad("rifle_squad", 0, 1, Vector3(-24 + (i % 4) * 16, 0, 40 + (i / 4) * 15)))
	for i in fps:
		await RenderingServer.frame_post_draw
	if world.director:
		world.director.active = false
	var folder := String(game.args.get("frames", "/tmp/hud-info"))
	DirAccess.make_dir_recursive_absolute(folder)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var caption := Label.new()
	caption.position = Vector2(380, 62)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	for frame in fps * 9:
		caption.text = String(game.args.get("label", "AFTER")) + " · SCROLL / ALERTS · NORMAL SPEED"
		if frame == fps / 2 and not roster._rows.is_empty():
			var motion := InputEventMouseMotion.new()
			motion.position = roster._rows[0][0].get_center()
			roster._gui_input(motion)
			print("HUD CAPTURE hover before ", roster.hovered())
		if frame == fps * 2:
			var pan := InputEventPanGesture.new()
			pan.delta = Vector2(0, 0.5)
			roster._gui_input(pan)
		if frame == fps * 2 + 2:
			print("HUD CAPTURE hover after scroll ", roster.hovered())
		if frame == fps * 3:
			roster._notification(Control.NOTIFICATION_MOUSE_EXIT)
			world.send_msg(0, "info", "Bravo 1 is moving out of the shellfire.")
		if frame == fps * 4:
			world.execute_cmd(1, {"t": "assault", "squads": [reserves[0].sid], "pos": Vector3(0, 0, -42)})
			world.send_msg(0, "info", "Charlie 1 is moving out of the shellfire.")
		if frame == fps * 8:
			world.send_msg(0, "info", "Bravo 1 is moving out of the shellfire.")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("frame-%04d.png" % frame))
	print("HUD CAPTURE complete")
	quit()
