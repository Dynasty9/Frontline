extends Node3D
## Repeatable real Vehicle lift flight, without a generated battle or enemies.
## Same fixture and timed destination changes are used for before/after captures.
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
var phase_label := "VERTICAL DEPARTURE"
var shots := [6.0, 9.0, 12.0, 16.0, 21.0]
var shot_index := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="):
			out = arg.get_slice("=", 1)
	field = Field.new()
	field.srv = true
	add_child(field)
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
	camera.fov = 43
	camera.far = 1000
	add_child(camera)
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(26, 20)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)

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

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= 8.0 and not redirected:
		redirected = true
		helicopter.lift_dest = Vector3(55, 0, -65)
		phase_label = "MID-FLIGHT RETARGET"
	if not redirected and helicopter.lift_phase == 2:
		phase_label = "FORWARD FLIGHT"
	if elapsed > 12.0:
		phase_label = "BRAKING APPROACH / LANDING"
	helicopter._lift_tick(dt)
	helicopter._view_process(dt)
	camera.position = helicopter.position + Vector3(24, 13, 28)
	camera.look_at(helicopter.position + Vector3(0, 1.5, 0))
	label.text = "FRONTLINE  /  HELICOPTER FLIGHT\n%s\n%04.1f s    ALT %04.1f m    SPEED %04.1f m/s" % [phase_label, elapsed, helicopter.position.y, helicopter.velocity.length()]
	if shot_index < shots.size() and elapsed >= shots[shot_index]:
		var n := shot_index
		shot_index += 1
		await RenderingServer.frame_post_draw
		if not out.is_empty():
			get_viewport().get_texture().get_image().save_png(out + "-%02d.png" % n)
	if elapsed >= 24.0:
		get_tree().quit()
