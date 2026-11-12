extends Node3D
## Real helicopter flights in the actual showroom battlefield: its terrain,
## grass, scenery, sky and lighting, on the High graphics preset. The world
## flies them exactly as it would in a battle (fixed 30 Hz with --fixed-fps
## 30), so the same stage on two builds gives a matched before/after pair.
##   --clip=helicopters        a Ghost Hawk lifts off a helipad beside the base and is sent 140 m
##                             out; eight seconds later she's redirected to a second pad
##   --clip=helicopters-chase  the same flight from a camera following her
##   --clip=helicopters-crash  two Ghost Hawks cross the view at 16 m and are both shot down
##                             2.5 s in: the near one's tail rotor goes, the far one's engines
##   --frames=DIR      write one PNG a frame there (tools/showcase/capture.py's contract)
##   --label=TEXT      the caption's first line (e.g. BEFORE / AFTER)
##   --seconds=S       how long to record (default 23; 10 for the crash)
##   --no-trace        leave out the traced flight paths and their drop lines
##   --shot-times=A,B  also save stills at those seconds (DIR/still-00.png ...)
##   --cam=X,Y,Z --look=X,Y,Z   the side-on camera and where it looks, from the first pad
const START := Vector3(80, 0, 60)  # the first pad, on open ground east of the base
const OUT := Vector3(0, 0, -140)  # where she's sent first, from the pad
const REDIRECT := Vector3(55, 0, -65)  # the second pad, from the first
const SHOT_DOWN_AT := 2.5


## One helicopter and the path it has flown, traced in the air.
class Track:
	var heli: Vehicle
	var points: Array = []  # (plain arrays: packed ones would be copied, not added to)
	var drops: Array = []
	var next_drop := 0.0
	var trail_mesh := ImmediateMesh.new()
	var drop_mesh := ImmediateMesh.new()


var output := ""
var mode := "helicopters"
var label := "CURRENT BUILD"
var seconds := -1.0
var trace := true
var shots: Array = []
var cam_from := Vector3(103, 10, 33)  # side on to the line between the pads, low enough that height reads against the sky
var cam_look := Vector3(27, 7, -32)
var field: World
var tracks: Array[Track] = []
var camera: Camera3D
var caption: Label


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
	if seconds < 0.0:
		seconds = 10.0 if mode == "helicopters-crash" else 23.0
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
	camera.fov = 43.0 if mode == "helicopters-chase" else 40.0
	var a := _ground(START)
	var c := _ground(START + REDIRECT)
	for p: Vector3 in [a, c]:
		field.spawn("structure", {"skind": "helipad", "pos": p, "yaw": 0.0, "team": 0, "built": true})
	if mode == "helicopters-crash":
		# both crossing the view at cruise height, one nearer the camera
		var across := Defs.flat(REDIRECT).normalized()
		var toward := Defs.flat(cam_from - cam_look).normalized()
		for i in 2:
			# (staggered along the line too, so they don't overlap on screen)
			var p := a + toward * (12.0 if i == 0 else -14.0) + across * (-28.0 if i == 0 else 0.0)
			var h := _helicopter(p + Vector3(0, 16.0, 0), Defs.yaw_of(across))
			h.velocity = across * 15.0
			h.lift_phase = 2
			h.lift_dest = _ground(p + across * 400.0)
			# (the shoot-down is the same on both builds; how she comes down
			# is chosen only where the build knows the difference)
			if "crash_mode_next" in h:
				h.crash_mode_next = 1 if i == 0 else 2
	else:
		_helicopter(a + Vector3(0, 0.15, 0), 0.0)
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
	# Let the terrain, grass and shaders settle (in the air the helicopters
	# are held where they start).
	var held: Array = []
	for tr in tracks:
		held.append([tr.heli.position, tr.heli.velocity])
	for i in 48:
		await RenderingServer.frame_post_draw
		if mode == "helicopters-crash":
			for k in tracks.size():
				tracks[k].heli.position = held[k][0]
				tracks[k].heli.velocity = held[k][1]
	print("HELICOPTER_WORLD_RECORDING")
	if mode != "helicopters-crash":
		tracks[0].heli.lift_dest = _ground(START + OUT)
	var frames := int(round(seconds * 30.0))
	var shot := 0
	var redirected := false
	var downed := false
	for frame in frames:
		var t := frame / 30.0
		if mode == "helicopters-crash":
			if t >= SHOT_DOWN_AT and not downed:
				downed = true
				for tr in tracks:
					# the hit itself: a missile bursting against her
					field.fx_event([Fx.EXPLODE, tr.heli.position + Vector3(0, 1.4, 0), 0.8, "he"])
					tr.heli.take_damage(tr.heli.max_hp * 3.0, null)
		elif t >= 8.0 and not redirected:
			redirected = true
			tracks[0].heli.lift_dest = c
		for tr in tracks:
			_record_path(tr, t)
		_frame_camera(1.0 / 30.0)
		_caption(t, redirected, downed)
		await RenderingServer.frame_post_draw
		if output.is_empty():
			continue
		var image := get_viewport().get_texture().get_image()
		image.save_png(output.path_join("%04d.png" % frame))
		if shot < shots.size() and t >= float(shots[shot]):
			image.save_png(output.path_join("still-%02d.png" % shot))
			shot += 1
	var where := "down" if not is_instance_valid(tracks[0].heli) or tracks[0].heli.gone else str(tracks[0].heli.position.snapped(Vector3.ONE * 0.1))
	print("HELICOPTER_WORLD_CLIP %s complete: %d frames, first helicopter %s" % [mode, frames, where])
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit(0)


func _helicopter(p: Vector3, yaw: float) -> Vehicle:
	var tr := Track.new()
	tr.heli = field.spawn("vehicle", {"vkind": "ghosthawk", "team": 0, "owner": -1, "pos": p, "yaw": yaw})
	for m: ImmediateMesh in [tr.trail_mesh, tr.drop_mesh]:
		var line := MeshInstance3D.new()
		line.mesh = m
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.82, 0.35) if m == tr.trail_mesh else Color(1.0, 0.92, 0.7, 0.5)
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.visible = trace
		add_child(line)
	tracks.append(tr)
	return tr.heli


func _v3(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, field.ground_y(p), p.z)


func _frame_camera(dt: float) -> void:
	var heli := tracks[0].heli
	if mode == "helicopters-chase" and is_instance_valid(heli) and not heli.gone:
		var want := heli.position + Vector3(24, 11, 28)
		camera.global_position = want if dt <= 0.0 else camera.global_position.lerp(want, 1.0 - exp(-dt * 2.0))
		camera.look_at(heli.position + Vector3(0, 1.5, 0))
		return
	if mode == "helicopters-chase":
		return
	var o := _ground(START)
	camera.global_position = o + cam_from
	camera.look_at(o + cam_look)


func _record_path(tr: Track, t: float) -> void:
	if not trace:
		return
	var heli := tr.heli
	if is_instance_valid(heli) and not heli.gone:
		var agl := heli.position.y - field.ground_y(heli.position)
		if agl > 0.25 and (tr.points.is_empty() or (tr.points[-1] as Vector3).distance_to(heli.position) > 0.8):
			tr.points.append(heli.position + Vector3(0, 0.6, 0))
		if agl > 0.5 and t >= tr.next_drop:
			tr.drops.append(heli.position + Vector3(0, 0.6, 0))
			tr.next_drop = t + 1.0
	tr.trail_mesh.clear_surfaces()
	if tr.points.size() >= 2:
		tr.trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p: Vector3 in tr.points:
			tr.trail_mesh.surface_add_vertex(p)
		tr.trail_mesh.surface_end()
	tr.drop_mesh.clear_surfaces()
	if not tr.drops.is_empty():
		tr.drop_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for p: Vector3 in tr.drops:
			tr.drop_mesh.surface_add_vertex(p)
			tr.drop_mesh.surface_add_vertex(Vector3(p.x, field.ground_y(p) + 0.05, p.z))
		tr.drop_mesh.surface_end()


func _caption(t: float, redirected: bool, downed: bool) -> void:
	var heli := tracks[0].heli
	if mode == "helicopters-crash":
		var state := "BOTH SHOT DOWN AT %.1f s" % SHOT_DOWN_AT if downed else "TWO GHOST HAWKS AT 16 m, 15 m/s"
		caption.text = "%s · %s\n%04.1f s" % [label, state, t]
		return
	if not is_instance_valid(heli) or heli.gone:
		caption.text = "%s · DOWN\n%04.1f s" % [label, t]
		return
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
