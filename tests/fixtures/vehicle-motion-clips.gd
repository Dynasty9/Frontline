extends Node3D
## Deterministic, rendered motion comparisons. Run this same fixture on main
## and the PR branch. -- --clip=tanks|boats|aircraft --frames=/absolute/folder
## Capture at 12 fps with 60 Hz simulation; boat footage is real time.
class Field extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
class OpenWaterBoat extends Vehicle:
	func _move_by(v: Vector3, dt: float) -> void:
		velocity = v
		position += v * dt

var field: Field
var camera: Camera3D
var caption: Label
var mode := "tanks"
var output := ""
var side := "AFTER"
var vehicles: Array[Vehicle] = []
var models: Array[VehicleModels] = []
var targets: Array[Vehicle] = []
var plane: Projectile
var beams: Array[MeshInstance3D] = []

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--label="): side = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(output)
	field = Field.new()
	field.has_view = false
	add_child(field)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.15, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for angles in [Vector3(-55, -25, 0), Vector3(25, -100, 0)]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = angles
		sun.light_energy = 1.8
		add_child(sun)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 40
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override("font_size", 24)
	canvas.add_child(caption)
	if mode == "aircraft": _aircraft()
	else: _vehicles()
	for frame in 144:
		var t := float(frame) / 12.0
		_tick(t)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
	for target in targets: target.free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("MOTION_CLIP %s %s frames=144" % [side, mode])
	get_tree().quit()

func _vehicles() -> void:
	var boats := mode == "boats"
	var kinds := ["rhib", "patrol_ship", "gun_trawler"] if boats else ["old_tank", "tank", "ifv"]
	Res.mi(self, Res.box(Vector3(180, 0.3, 240)), Res.mat(Color(0.08, 0.27, 0.34) if boats else Color(0.22, 0.27, 0.25)), Vector3(0, -0.35, -45))
	# Fixed distance marks make the relative progress visible.
	if boats:
		for z in range(0, 121, 20):
			Res.mi(self, Res.box(Vector3(130, 0.02, 0.15)), Res.mat(Color(0.35, 0.5, 0.55)), Vector3(0, -0.12, -z))
	for i in 3:
		var v: Vehicle = OpenWaterBoat.new() if boats else Vehicle.new()
		v.world = field
		v.vkind = kinds[i]
		v.vdef = Defs.VEHICLES[kinds[i]]
		v.position = Vector3((i - 1) * (38 if boats else 12), 0, 0)
		add_child(v)
		v.set_process(false)
		var model := VehicleModels.build(kinds[i], 0, 0)
		v.add_child(model.root)
		vehicles.append(v)
		models.append(model)
		if not boats:
			var target := Vehicle.new()
			target.position = v.position + Vector3(50, 0, 0)
			target.eid = 999
			v.target = target
			targets.append(target)
	if boats:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 145
		camera.position = Vector3(0, 130, 55)
		camera.look_at(Vector3(0, 0, -35))
	else:
		camera.position = Vector3(25, 24, 33)
		camera.look_at(Vector3.ZERO)

func _aircraft() -> void:
	plane = Projectile.new()
	plane.world = field
	plane.srv = true
	plane.ptype = "ac130"
	plane.mk = "ac130"
	add_child(plane)
	plane.set_process(false)
	plane.model = Node3D.new()
	plane.add_child(plane.model)
	var model := VehicleModels.build("ac130", 0, 0)
	plane.model.add_child(model.root)
	plane._vm = model
	for i in 3:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = [Color(1, 0.7, 0.2), Color(0.4, 0.9, 1), Color(1, 0.4, 0.3)][i]
		beams.append(Res.mi(self, Res.cyl(0.08, 0.08, 1, 8), material, Vector3.ZERO))

func _tick(t: float) -> void:
	if mode == "aircraft":
		plane.life_t = 5.0 + t
		plane._ac130_view(1.0 / 12.0)
		camera.position = plane.model.global_basis * Vector3(-55, 20, 32)
		camera.look_at(Vector3.ZERO)
		for i in 3:
			var weapon: String = ["ac25", "ac40", "ac105"][i]
			var from: Vector3 = plane.call("aircraft_muzzle", weapon) if plane.has_method("aircraft_muzzle") else plane.position + Vector3(0, -1.5, 0)
			var dir := (plane.model.global_basis * Vector3.LEFT).normalized()
			var length := 2.0 + fmod(t * 18.0 + i * 4.0, 12.0)
			beams[i].position = from + dir * length * 0.5
			beams[i].scale = Vector3(1, length, 1)
			beams[i].quaternion = Quaternion(Vector3.UP, dir)
		caption.text = side + " / GUNSHIP BARREL ORIGINS\n25 mm: gold   40 mm: blue   105 mm: red\nPulses mark actual authority launch points; camera follows heading."
		return
	var details := ""
	for i in 3:
		var v := vehicles[i]
		for step in 5:
			if mode == "boats":
				if t < 6.0: v._hull_tick(1.0 / 60.0, 1.0, 0.0, false)
				elif t < 10.0: v._hull_tick(1.0 / 60.0, 1.0, -1.0, false)
				else: v._lie_to(1.0 / 60.0)
			elif t >= 0.5:
				v._turret_tick(1.0 / 60.0)
		if mode == "tanks":
			models[i].turret.rotation.y = v.turret_yaw
			details += "%s: %.0f deg   " % [v.display_name(), absf(rad_to_deg(v.turret_yaw))]
		else:
			# Small course dots expose turn radius without changing the hull physics.
			Res.mi(self, Res.box(Vector3(0.4, 0.04, 0.4)), Res.mat(Color(0.75, 0.85, 0.8)), Vector3(v.position.x, -0.08, v.position.z))
			details += "%s: %.1f m/s   " % [v.display_name(), v.speed]
	if mode == "boats":
		var phase := "FULL AHEAD" if t < 6.0 else ("HARD RIGHT" if t < 10.0 else "STOP / ASTERN THRUST")
		caption.text = side + " / BOAT RESPONSE / %.1f s / %s\n" % [t, phase] + details + "\nIdentical throttle and helm inputs; distance lines every 20 metres."
	else:
		caption.text = side + " / 90 DEGREE TARGET ACQUISITION / %.1f s\n" % maxf(0.0, t - 0.5) + details + "\nIdentical targets; hulls held stationary."
