extends Node

func _ready() -> void:
	var world := World.new()
	var camera := RtsCamera.new()
	camera.world = world
	add_child(camera)
	camera.set_process(false)
	camera.edge_pan = false
	camera.focus(Vector3.ZERO)
	camera._pan_offset = Vector3(1000, 0, 0)
	camera._last_ms = Time.get_ticks_msec() - 16
	camera._view_process(0.016)
	assert(camera.focus_pos.x > 0.0 and camera.focus_pos.x <= 2.4, "Drag must respect the pan speed limit even at a long frame")
	camera.glide_to(Vector3(1000, 0, 0))
	camera._g_t = 1.0
	camera._last_ms = Time.get_ticks_msec() - 16
	var before := camera.focus_pos
	camera._view_process(0.016)
	assert(camera.focus_pos.distance_to(before) <= 2.4 and camera._gliding, "A timed glide must keep approaching its destination without a jump")
	camera.focus(Vector3(300, 0, 200))
	assert(camera.focus_pos == Vector3(300, 0, 200), "Explicit test framing remains immediate")
	world.cam = camera
	var hud := Hud.new()
	hud.world = world
	var minimap := HudMinimap.new()
	minimap.hud = hud
	minimap.size = Vector2(240, 240)
	minimap._update_xf()
	before = camera.focus_pos
	minimap._look(minimap._pt(Vector3(-300, 0, -200)))
	assert(camera.focus_pos == before and camera._gliding, "Minimap clicks must start a glide, never teleport")
	camera._last_ms = Time.get_ticks_msec() - 16
	camera._view_process(0.016)
	assert(camera.focus_pos.distance_to(before) <= 2.4, "Minimap movement must obey the speed limit")
	var destination := Vector3(100, 0, 100)
	minimap._look(minimap._pt(destination))
	assert((camera._g_pos[1] as Vector3).distance_to(destination) < 0.1, "A new click must replace the destination")
	for frame in 600:
		before = camera.focus_pos
		camera._last_ms = Time.get_ticks_msec() - 16
		camera._view_process(0.016)
		assert(camera.focus_pos.distance_to(before) <= 2.4, "The final glide frame must not teleport")
		if not camera._gliding:
			break
	assert(not camera._gliding and camera.focus_pos.distance_to(destination) < 0.1, "Minimap glide must arrive")
	minimap.free()
	hud.free()
	camera.free()
	world.free()
	print("CAMERA_STREAMING passed")
	get_tree().quit()
