extends Node3D
## Repeatable real Vehicle lift flight, without a generated battle or enemies.
## Same fixture and timed destination changes are used for before/after captures.
##   --visual-out=PREFIX   save stills at the shot times (PREFIX-00.png ...)
##   --camera=wide|chase   the whole flight from the side (default), or following her
##   --caption=TEXT        a line over the readout (e.g. which build this is)
##   --seconds=S           quit after S seconds (default 26)
##   --shot-times=A,B,...  when to take the stills (seconds)
##   --cam=X,Y,Z --look=X,Y,Z   place the wide camera
##   --label-y=PX          where the readout sits (from the top)
## Record motion with the engine's movie writer: --fixed-fps 30 --write-movie OUT.avi
## before the `--`. The flight path is traced, with a drop line to the ground every
## second, so the shape of the climb out and the approach reads at a glance.
class Field extends World:
	func _ready() -> void:
		has_view = true
		view_team = -1
		set_process(false)
		set_physics_process(false)
	func ground_y(_p: Vector3) -> float:
		return 0.0

var field: Field
var helicopter: Vehicle
var camera: Camera3D
var label: Label
var elapsed := 0.0
var redirected := false
var out := ""
var mode := "wide"
var caption := ""
var seconds := 26.0
var cam_at := Vector3(118, 27, -36)
var look_at_point := Vector3(24, 1, -58)
var label_y := 20.0
var phase_label := "ON THE PAD"
var shots := [6.0, 9.0, 12.0, 16.0, 21.0]
var shot_index := 0
var trail := PackedVector3Array()
var trail_mesh: ImmediateMesh
var drop_mesh: ImmediateMesh
var _trail_t := 0.0
var _drop_t := 0.0
var _drops := PackedVector3Array()

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--camera="):
			mode = arg.get_slice("=", 1)
		elif arg.begins_with("--caption="):
			caption = arg.get_slice("=", 1)
		elif arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cam="):
			cam_at = _v3(arg.get_slice("=", 1))
		elif arg.begins_with("--label-y="):
			label_y = float(arg.get_slice("=", 1))
		elif arg.begins_with("--look="):
			look_at_point = _v3(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-times="):
			shots = Array(arg.get_slice("=", 1).split(",")).map(func(x): return float(x))
	field = Field.new()
	field.srv = true
	add_child(field)
	# the real effects, so the downwash shows as it does in a battle
	var fx := Fx.new()
	fx.name = "Fx"
	fx.world = field
	field.add_child(fx)
	field.fx = fx
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.65, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.83, 0.88)
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 145, 0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	add_child(sun)
	_box(Vector3(0, -0.25, -40), Vector3(600, 0.5, 600), Color(0.24, 0.29, 0.20))
	for x in range(-160, 161, 20):
		for z in range(-200, 101, 20):
			_box(Vector3(x, 0.01, z), Vector3(0.25, 0.02, 2.0), Color(0.42, 0.43, 0.31))
	for p in [Vector3.ZERO, Vector3(55, 0, -65)]:
		_box(p, Vector3(17, 0.05, 17), Color(0.16, 0.18, 0.18))
		_box(p + Vector3(-2, 0.05, 0), Vector3(0.5, 0.02, 6), Color(0.85, 0.83, 0.65))
		_box(p + Vector3(2, 0.05, 0), Vector3(0.5, 0.02, 6), Color(0.85, 0.83, 0.65))
		_box(p + Vector3(0, 0.05, 0), Vector3(4, 0.02, 0.5), Color(0.85, 0.83, 0.65))
	# a few sheds and a hedge line for scale
	for b in [[Vector3(-18, 2, -8), Vector3(8, 4, 6)], [Vector3(20, 1.6, 10), Vector3(6, 3.2, 9)], [Vector3(80, 2.5, -80), Vector3(9, 5, 7)], [Vector3(30, 0.9, -110), Vector3(40, 1.8, 2)]]:
		_box(b[0], b[1], Color(0.42, 0.38, 0.33) if b[1].x < 30.0 else Color(0.2, 0.3, 0.17))
	trail_mesh = ImmediateMesh.new()
	drop_mesh = ImmediateMesh.new()
	for m: ImmediateMesh in [trail_mesh, drop_mesh]:
		var line := MeshInstance3D.new()
		line.mesh = m
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.82, 0.35) if m == trail_mesh else Color(1.0, 0.92, 0.7, 0.55)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
	helicopter = Vehicle.new()
	helicopter.world = field
	helicopter.vkind = "ghosthawk"
	helicopter.eid = 101
	helicopter.team = 0
	helicopter.srv = true
	helicopter.position = Vector3(0, 0.15, 0)
	field.add_child(helicopter)
	helicopter.on_spawned()
	helicopter.set_process(false)
	helicopter.scan_t = 10000.0
	helicopter.lift_dest = Vector3(0, 0, -140)
	camera = Camera3D.new()
	camera.fov = 40 if mode == "wide" else 43
	camera.far = 1000
	add_child(camera)
	camera.current = true
	if mode == "wide":
		camera.position = cam_at
		camera.look_at(look_at_point)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(26, label_y)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)

func _v3(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _box(p: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	mesh.position = p
	add_child(mesh)

func _draw_trail() -> void:
	trail_mesh.clear_surfaces()
	if trail.size() >= 2:
		trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trail:
			trail_mesh.surface_add_vertex(p)
		trail_mesh.surface_end()
	drop_mesh.clear_surfaces()
	if not _drops.is_empty():
		drop_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for p in _drops:
			drop_mesh.surface_add_vertex(p)
			drop_mesh.surface_add_vertex(Vector3(p.x, 0.05, p.z))
		drop_mesh.surface_end()

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= 8.0 and not redirected:
		redirected = true
		helicopter.lift_dest = Vector3(55, 0, -65)
	var agl := helicopter.position.y - 0.0
	var spd := Defs.flat(helicopter.velocity).length()
	if helicopter.lift_phase == 0:
		phase_label = "ON THE PAD" if elapsed < 8.0 else "DOWN"
	elif helicopter.lift_phase == 1:
		phase_label = "LIFT-OFF"
	elif helicopter.lift_phase == 3:
		phase_label = "SETTING DOWN"
	elif absf(helicopter.flight_roll) > 0.12:
		phase_label = "BANKED TURN ONTO THE NEW PAD"
	elif helicopter.flight_pitch > 0.05 and spd > 1.0:
		phase_label = "APPROACH: FLARING"
	elif helicopter.velocity.y > 0.5:
		phase_label = "CLIMBING OUT"
	elif helicopter.velocity.y < -0.5:
		phase_label = "APPROACH"
	elif spd > 3.0:
		phase_label = "CRUISE"
	else:
		phase_label = "HOVER"
	helicopter._lift_tick(dt)
	helicopter._view_process(dt)
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.1
		if agl > 0.25:
			trail.append(helicopter.position + Vector3(0, 0.6, 0))
	_drop_t -= dt
	if _drop_t <= 0.0:
		_drop_t = 1.0
		if agl > 0.5:
			_drops.append(helicopter.position + Vector3(0, 0.6, 0))
	_draw_trail()
	if mode == "chase":
		var want := helicopter.position + Vector3(24, 13, 28)
		camera.position = camera.position.lerp(want, 1.0 - exp(-dt * 2.0)) if elapsed > 0.1 else want
		camera.look_at(helicopter.position + Vector3(0, 1.5, 0))
	var head := "FRONTLINE  /  HELICOPTER FLIGHT" if caption.is_empty() else caption
	label.text = "%s\n%s\n%04.1f s    ALT %04.1f m    SPEED %04.1f m/s    PITCH %+03.0f°    BANK %+03.0f°" % [head, phase_label, elapsed, agl, spd, rad_to_deg(helicopter.flight_pitch), -rad_to_deg(helicopter.flight_roll)]
	if shot_index < shots.size() and elapsed >= shots[shot_index]:
		var n := shot_index
		shot_index += 1
		await RenderingServer.frame_post_draw
		if not out.is_empty():
			get_viewport().get_texture().get_image().save_png(out + "-%02d.png" % n)
	if elapsed >= seconds:
		get_tree().quit()
