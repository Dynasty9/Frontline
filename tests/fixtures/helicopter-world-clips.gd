extends Node3D
## A real helicopter flight in the actual showroom battlefield: its terrain,
## grass, scenery, sky and lighting, on the High graphics preset. A Ghost
## Hawk sits on a helipad beside the base; when recording starts she is sent
## 140 m out, and eight seconds later redirected to a second pad. The world
## flies her exactly as it would in a battle (fixed 30 Hz with --fixed-fps 30),
## so the same stage on two builds gives a matched before/after pair.
##   --clip=helicopters|helicopters-chase   the whole flight from the side, or following her
##   --frames=DIR      write one PNG a frame there (tools/showcase/capture.py's contract)
##   --label=TEXT      the caption's first line (e.g. BEFORE / AFTER)
##   --seconds=S       how long to record (default 23)
##   --no-trace        leave out the traced flight path and its drop lines
##   --shot-times=A,B  also save stills at those seconds (DIR/still-00.png ...)
##   --cam=X,Y,Z --look=X,Y,Z   the side-on camera and where it looks, from the first pad
const START := Vector3(80, 0, 60)  # the first pad, on open ground east of the base
const OUT := Vector3(0, 0, -140)  # where she's sent first, from the pad
const REDIRECT := Vector3(55, 0, -65)  # the second pad, from the first
var output := ""
var mode := "helicopters"
var label := "CURRENT BUILD"
var seconds := 23.0
var trace := true
var shots: Array = []
var cam_from := Vector3(103, 10, 33)  # side on to the line between the pads, low enough that height reads against the sky
var cam_look := Vector3(27, 7, -32)
var field: World
var heli: Vehicle
var camera: Camera3D
var caption: Label
var trail := PackedVector3Array()
var drops := PackedVector3Array()
var trail_mesh: ImmediateMesh
var drop_mesh: ImmediateMesh
var next_drop := 0.0


func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=", 1))
		if arg == "--no-trace": trace = false
		if arg.begins_with("--cam="): cam_from = _v3(arg.get_slice("=", 1))
		if arg.begins_with("--look="): cam_look = _v3(arg.get_slice("=", 1))
		if arg.begins_with("--shot-times="): shots = Array(arg.get_slice("=", 1).split(",")).map(func(x): return float(x))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	seed(712)
	# A fixed, supported preset keeps the comparison reproducible and looks
	# like the game as most players see it.
	Settings.apply_preset("high", false)
	Settings.v.dof = false
	field = World.new()
	field.settings = {"scenario": "showroom", "seed": 712, "mood": "day", "map_size": 1024, "players": {}, "ai_teams": []}
	add_child(field)
	await field.build()
	while field.cam == null or field.building:
		await get_tree().process_frame
	field.cam.set_process(false)
	field.input.set_process(false)
	field.hud.visible = false
	if field.director:
		field.director.active = false
	camera = field.cam.cam
	camera.fov = 40.0 if mode == "helicopters" else 43.0
	var a := _ground(START)
	var c := _ground(START + REDIRECT)
	for p: Vector3 in [a, c]:
		field.spawn("structure", {"skind": "helipad", "pos": p, "yaw": 0.0, "team": 0, "built": true})
	heli = field.spawn("vehicle", {"vkind": "ghosthawk", "team": 0, "owner": -1, "pos": a + Vector3(0, 0.15, 0), "yaw": 0.0})
	_trace_meshes()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	_frame_camera(0.0)
	print("HELICOPTER_WORLD_WARMUP")
	# Let the terrain, grass and shaders settle (the helicopter idles on the pad).
	for i in 48:
		await RenderingServer.frame_post_draw
	print("HELICOPTER_WORLD_RECORDING")
	heli.lift_dest = _ground(START + OUT)
	var frames := int(round(seconds * 30.0))
	var shot := 0
	var redirected := false
	for frame in frames:
		var t := frame / 30.0
		if t >= 8.0 and not redirected:
			redirected = true
			heli.lift_dest = c
		_record_path(t)
		_frame_camera(1.0 / 30.0)
		_caption(t, redirected)
		await RenderingServer.frame_post_draw
		if output.is_empty():
			continue
		var image := get_viewport().get_texture().get_image()
		image.save_png(output.path_join("%04d.png" % frame))
		if shot < shots.size() and t >= float(shots[shot]):
			image.save_png(output.path_join("still-%02d.png" % shot))
			shot += 1
	print("HELICOPTER_WORLD_CLIP %s complete: %d frames, landed at %s" % [mode, frames, heli.position.snapped(Vector3.ONE * 0.1)])
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit(0)


func _v3(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, field.ground_y(p), p.z)


func _frame_camera(dt: float) -> void:
	if mode == "helicopters-chase":
		var want := heli.position + Vector3(24, 11, 28)
		camera.global_position = want if dt <= 0.0 else camera.global_position.lerp(want, 1.0 - exp(-dt * 2.0))
		camera.look_at(heli.position + Vector3(0, 1.5, 0))
		return
	# side on to the route, the base behind it
	var o := _ground(START)
	camera.global_position = o + cam_from
	camera.look_at(o + cam_look)


func _trace_meshes() -> void:
	trail_mesh = ImmediateMesh.new()
	drop_mesh = ImmediateMesh.new()
	for m: ImmediateMesh in [trail_mesh, drop_mesh]:
		var line := MeshInstance3D.new()
		line.mesh = m
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.82, 0.35) if m == trail_mesh else Color(1.0, 0.92, 0.7, 0.5)
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.visible = trace
		add_child(line)


func _record_path(t: float) -> void:
	if not trace:
		return
	var agl := heli.position.y - field.ground_y(heli.position)
	if agl > 0.25 and (trail.is_empty() or trail[-1].distance_to(heli.position) > 0.8):
		trail.append(heli.position + Vector3(0, 0.6, 0))
	if agl > 0.5 and t >= next_drop:
		drops.append(heli.position + Vector3(0, 0.6, 0))
		next_drop = t + 1.0
	trail_mesh.clear_surfaces()
	if trail.size() >= 2:
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trail:
			trail_mesh.surface_add_vertex(p)
		trail_mesh.surface_end()
	drop_mesh.clear_surfaces()
	if not drops.is_empty():
		drop_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for p in drops:
			drop_mesh.surface_add_vertex(p)
			drop_mesh.surface_add_vertex(Vector3(p.x, field.ground_y(p) + 0.05, p.z))
		drop_mesh.surface_end()


func _caption(t: float, redirected: bool) -> void:
	var agl := heli.position.y - field.ground_y(heli.position)
	var spd := Defs.flat(heli.velocity).length()
	var phase := "HOVER"
	if heli.lift_phase == 0:
		phase = "ON THE PAD" if not redirected else "DOWN"
	elif heli.lift_phase == 1:
		phase = "LIFT-OFF"
	elif heli.lift_phase == 3:
		phase = "SETTING DOWN"
	elif absf(heli.flight_roll) > 0.12:
		phase = "BANKED TURN ONTO THE NEW PAD"
	elif heli.flight_pitch > 0.05 and spd > 1.0:
		phase = "APPROACH: FLARING"
	elif heli.velocity.y > 0.5:
		phase = "CLIMBING OUT"
	elif heli.velocity.y < -0.5:
		phase = "APPROACH"
	elif spd > 3.0:
		phase = "CRUISE"
	caption.text = "%s · %s\n%04.1f s    ALT %04.1f m    SPEED %04.1f m/s    PITCH %+03.0f°    BANK %+03.0f°" % [
		label, phase, t, agl, spd, rad_to_deg(heli.flight_pitch), -rad_to_deg(heli.flight_roll)]
