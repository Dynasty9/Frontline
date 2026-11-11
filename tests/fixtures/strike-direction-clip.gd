extends SceneTree
## Record the real input preview and resulting sortie at fixed 30 Hz.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
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
	world.cam.dist = 100.0
	world.cam.target_dist = 100.0
	world.cam.pitch_deg = -55.0
	world.cam.yaw = 0.0
	world.cam.focus(Vector3(0, 0, -10))
	var caption := Label.new()
	caption.position = Vector2(470, 100)
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_constant_override("outline_size", 8)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(caption)
	var inp = world.input
	var start: Vector2 = world.cam.cam.unproject_position(Vector3(0, 0, -10))
	inp.debug_mouse = start
	inp.ability = "demo:airstrike"
	for frame in 30:
		await process_frame
	var directory := "build/strike-direction-final"
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var expected := Vector3.ZERO
	for frame in 360:
		if frame < 30:
			caption.text = "1  PRESS ON THE TARGET"
		elif frame < 150:
			caption.text = "2  HOLD + DRAG TO CHOOSE THE RUN-IN ANGLE"
			var angle := lerpf(-0.6, 0.65, clampf(float(frame - 45) / 85.0, 0.0, 1.0))
			inp.debug_mouse = start + Vector2(cos(angle), sin(angle)) * 130.0
		else:
			caption.text = "3  RELEASE — THE AIRCRAFT FOLLOWS YOUR LINE"
		if frame == 30 or frame == 150:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = frame == 30
			event.position = inp.debug_mouse
			if frame == 150:
				expected = inp.support_dir()
			inp._unhandled_input(event)
			if frame == 150:
				var found := false
				for projectile in world.projectiles:
					if projectile.ptype == "jet":
						assert(projectile.vel.normalized().is_equal_approx(expected))
						found = true
				assert(found, "Releasing the drag must launch a jet along the preview")
				world.set_physics_process(true)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(directory + "/%04d.png" % frame) == OK)
	print("STRIKE_DIRECTION_CLIP frames=360 direction=", expected)
	quit()
