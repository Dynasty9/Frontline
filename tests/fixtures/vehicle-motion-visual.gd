extends Node3D
## Render identical timed acquisitions and gunship launch geometry on either
## side of the change. -- --motion-shot=tanks|aircraft --visual-out=/path.png
class Field extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

var out := ""
var mode := "tanks"
var field: Field

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):
			out = arg.get_slice("=", 1)
		if arg.begins_with("--motion-shot="):
			mode = arg.get_slice("=", 1)
	field = Field.new()
	field.has_view = false
	add_child(field)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.16, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 40
	if mode == "aircraft":
		_aircraft(camera)
	else:
		_tanks(camera)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("MOTION_VISUAL " + out)
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit()

func _tanks(camera: Camera3D) -> void:
	_box(Vector3(0, -0.2, 0), Vector3(70, 0.3, 50), Color(0.22, 0.27, 0.25))
	var text := "90 DEGREE ACQUISITION / TWO SECONDS AFTER TARGET APPEARS\n\n"
	var index := 0
	for kind in ["old_tank", "tank", "ifv"]:
		var vehicle := Vehicle.new()
		vehicle.world = field
		vehicle.vkind = kind
		vehicle.vdef = Defs.VEHICLES[kind]
		vehicle.position = Vector3((index - 1) * 12, 0, 0)
		add_child(vehicle)
		vehicle.set_process(false)
		var target := Vehicle.new()
		target.position = vehicle.position + Vector3(50, 0, 0)
		target.eid = 999
		vehicle.target = target
		var k := VehicleModels.build(kind, 0, 0)
		vehicle.add_child(k.root)
		for step in 60:
			vehicle._turret_tick(1.0 / 30.0)
		k.turret.rotation.y = vehicle.turret_yaw
		text += "%s: %.1f degrees    " % [vehicle.display_name(), absf(rad_to_deg(vehicle.turret_yaw))]
		index += 1
		target.free()
	camera.position = Vector3(25, 24, 33)
	camera.look_at(Vector3(0, 0, 0))
	_label(text + "\n\nHull headings held constant; all three targets are 90 degrees to the right.")

func _aircraft(camera: Camera3D) -> void:
	var plane := Projectile.new()
	plane.world = field
	plane.srv = true
	plane.ptype = "ac130"
	plane.mk = "ac130"
	plane.life_t = 5.0
	add_child(plane)
	plane.set_process(false)
	plane.model = Node3D.new()
	plane.add_child(plane.model)
	var k := VehicleModels.build("ac130", 0, 0)
	plane.model.add_child(k.root)
	plane._vm = k
	plane._ac130_view(0.0)
	var from: Vector3
	if plane.has_method("aircraft_muzzle"):
		from = plane.call("aircraft_muzzle", "ac105")
	else:
		from = plane.position + Vector3(0, -1.5, 0)
	# A short visible segment at the actual authority's 105 mm launch point.
	var to := from + (plane.model.global_basis * Vector3.LEFT).normalized() * 12.0
	var tracer := Res.mi(self, Res.cyl(0.07, 0.07, from.distance_to(to), 8), Res.mat(Color(1, 0.65, 0.18), 0.1, 5.0), (from + to) * 0.5)
	tracer.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25, -100, 0)
	fill.light_energy = 2.0
	add_child(fill)
	camera.position = plane.model.global_basis * Vector3(-55, 20, 32)
	camera.look_at(Vector3(0, 0, 0))
	_label("ORBITING GUNSHIP / 105 MM LAUNCH POSITION\n\nOrange segment begins at the server's launch point.\nThe aircraft uses its actual model, heading, and bank.")

func _label(text: String) -> void:
	var label := Label.new()
	label.position = Vector2(30, 25)
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(label)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	Res.mi(self, Res.box(size), Res.mat(color), pos)
