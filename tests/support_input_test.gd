extends Node

class CommandWorld extends World:
	var commands: Array[Dictionary] = []
	func _ready() -> void:
		pass
	func ground_y(_p: Vector3) -> float:
		return 2.5
	func send_cmd(command: Dictionary) -> void:
		commands.append(command)

class MapCamera extends RtsCamera:
	func _ready() -> void:
		pass
	func ground_point(screen: Vector2) -> Vector3:
		return Vector3(screen.x, 0, screen.y)

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func button(inp: PlayerInput, at: Vector2, pressed: bool, which := MOUSE_BUTTON_LEFT) -> void:
	inp.debug_mouse = at
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.position = at
	event.pressed = pressed
	inp._unhandled_input(event)

func _ready() -> void:
	TestRun.watch()
	var world := CommandWorld.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.local_team = 0
	add_child(world)
	world.cam = MapCamera.new()
	world.cam.target_dist = 200.0
	world.add_child(world.cam)
	var inp := PlayerInput.new()
	inp.world = world
	world.add_child(inp)
	var start := Vector2(100, 100)
	for prefix in ["support:", "demo:"]:
		# Demo fallback uses the camera's right vector.
		world.cam.cam = Camera3D.new()
		world.cam.add_child(world.cam.cam)
		for kind in Defs.SUPPORT:
			for offset in [Vector2(60, 30), Vector2(-30, 60), Vector2.ZERO]:
				inp.ability = prefix + kind
				button(inp, start, true)
				inp.debug_mouse = start + offset
				var expected := inp.support_dir()
				button(inp, start + offset, false)
				var command: Dictionary = world.commands.back()
				check(command.dir.is_equal_approx(expected), kind + " must send the preview direction on release")
				check(command.pos == Vector3(100, 0, 100), kind + " must keep the initial target")
				check(not inp.ab_drag and inp.ability == "", kind + " must finish targeting")
				if offset != Vector2.ZERO and Defs.SUPPORT[kind].shape in ["line", "strafe", "sweep"]:
					check(command.dir.is_equal_approx(Vector3(offset.x, 0, offset.y).normalized()), kind + " must follow the drag")
				else:
					check(command.dir == (Vector3.RIGHT if prefix == "demo:" else Vector3.FORWARD), kind + " must keep its default direction")
		world.cam.cam.free()
	inp.ability = "support:airstrike"
	button(inp, start, true)
	var count := world.commands.size()
	button(inp, start, true, MOUSE_BUTTON_RIGHT)
	button(inp, start, false)
	check(world.commands.size() == count and not inp.ab_drag, "Cancel must not call support")
	# Confirmation rings use the terrain height even when the clicked object is above it.
	inp._marker(Vector3(7, 12, 4), Color.WHITE, 2.4)
	var marker: MeshInstance3D = inp._markers.back()[0]
	check(marker.position.is_equal_approx(Vector3(7, 2.6, 4)), "The order ring must sit on the raised ground")
	check(is_equal_approx(marker.mesh.outer_radius, 2.4), "The ring must accommodate the cargo footprint")
	world.free()
	print("SUPPORT_INPUT_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
