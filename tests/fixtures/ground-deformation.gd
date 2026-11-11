extends Node3D
## Read back the production terrain vertex displacement with normal LOD enabled.
var args := {}
var field: World
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	TestRun.watch()
	Settings.v.grass = 0
	Settings.v.post = false
	Settings.v.lod = 2
	field = World.new()
	field.settings = {"scenario": "showroom", "seed": 712, "mood": "day", "map_size": 1024, "players": {}, "ai_teams": []}
	add_child(field)
	await field.build()
	field.set_process(false)
	field.set_physics_process(false)
	field.cam.set_process(false)
	field.input.set_process(false)
	field.hud.visible = false
	var p := Vector3(4, 0, 6)
	var camera := field.cam.cam
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.global_position = p + Vector3.UP * 5.0
	camera.look_at(p, Vector3.FORWARD)
	camera.attributes = null
	field.atmo.post_layer.visible = false
	field.atmo.env.adjustment_enabled = false
	field.atmo.env.fog_enabled = false
	field.atmo.env.glow_enabled = false
	field.atmo.env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	field.atmo.env.tonemap_exposure = 1.0
	# Expose the interpolated world height from the unchanged production vertex
	# program. Mesh density, culling, LOD and tile uploads all remain live.
	var shader := Shader.new()
	var code: String = field.atmo.ground_mat.shader.code
	code = code.substr(0, code.find("void fragment() {"))
	code = code.replace("render_mode specular_schlick_ggx;", "render_mode unshaded, fog_disabled;")
	shader.code = code + "void fragment() { ALBEDO = vec3(clamp(wpos.y + 1.0, 0.0, 1.0)); }"
	field.atmo.ground_mat.shader = shader
	field.atmo.ground_mat.set_shader_parameter("deform_tex", field.atmo.deform_tex)
	for i in 20: await RenderingServer.frame_post_draw
	var before := await height_pixel()
	field.terrain.add_crater(p + Vector3.UP * 0.1, 1.4)
	for i in 20: await RenderingServer.frame_post_draw
	var after := await height_pixel()
	var cpu_height := field.terrain.deform_at(p)
	check(absf(before) < 0.02, "Ground must start level")
	check(after < -0.3, "Nearby terrain must render the crater, not a flat coarse grid")
	check(absf(after - cpu_height) < 0.07, "Rendered crater must agree with terrain data")
	print("GROUND_DEFORMATION failures=", failures, " before=", before, " after=", after, " cpu=", cpu_height)
	if Music._task >= 0: WorkerThreadPool.wait_for_task_completion(Music._task)
	get_tree().quit(1 if failures else 0)

func height_pixel() -> float:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var pixel := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	# Compatibility writes unshaded ALBEDO directly into its sRGB framebuffer.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		pixel = pixel.srgb_to_linear()
	return pixel.r - 1.0
