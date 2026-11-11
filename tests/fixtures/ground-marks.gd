extends Node3D
## Pixel regression for terrain-only decals and smoke compositing.
var failures := 0
var camera: Camera3D
var output := ""

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func capture() -> Image:
	for i in 6:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func difference(a: Image, b: Image, p: Vector3) -> float:
	var scale_to_image := Vector2(a.get_size()) / get_viewport().get_visible_rect().size
	var pixel := Vector2i(camera.unproject_position(p) * scale_to_image)
	var total := 0.0
	for y in range(pixel.y - 2, pixel.y + 3):
		for x in range(pixel.x - 2, pixel.x + 3):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
	return total / 25.0

func data_texture(c: Color) -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.get_slice("=", 1)
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.1, 0.15, 0.2)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	add_child(environment)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 4, 7)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.current = true
	var material := Res.mat(Color(0.7, 0.7, 0.7))
	var ground := Res.mi(self, Res.box(Vector3(12, 0.1, 8)), material, Vector3(0, -0.05, 0))
	ground.layers = 1 | Res.GROUND_DECAL_LAYER
	Res.mi(self, Res.box(Vector3(1.6, 0.4, 0.6)), material, Vector3(-2, 0.2, 0))
	# Use the production shader with an opaque, uniformly lit test frame.
	# The floor may darken behind it; the smoke itself must not acquire soot.
	var cloud := Res.mi(self, QuadMesh.new(), null, Vector3(2, 0.2, 0))
	cloud.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3.ONE * 4)
	var smoke := ShaderMaterial.new()
	smoke.shader = load("res://scripts/shaders/blast_flipbook.gdshader")
	smoke.set_shader_parameter("positive_map", data_texture(Color(0.8, 0.8, 0.8, 1)))
	smoke.set_shader_parameter("negative_map", data_texture(Color(0.8, 0.8, 0.8, 0)))
	smoke.set_shader_parameter("bounds_map", data_texture(Color(0, 0, 1, 1)))
	smoke.set_shader_parameter("center_height", 0.0)
	smoke.set_shader_parameter("span", 1.6)
	smoke.set_shader_parameter("tint", Color.WHITE)
	smoke.set_shader_parameter("amb_col", Color.WHITE)
	smoke.set_shader_parameter("sun_energy", 0.0)
	smoke.set_shader_parameter("amb_energy", 1.0)
	smoke.set_shader_parameter("wind", Vector3.ZERO)
	cloud.material_override = smoke
	var v: Vfx = field.fx.vfx
	v.set_process(false)
	v.scorch(Vector3.ZERO, 8.0)
	v.crater(Vector3.ZERO, 3.0)
	var marks: Array[Decal] = [v._decals[-1][0], v._craters[-1]]
	for mark in marks:
		if "--legacy-ground-masks" in OS.get_cmdline_user_args(): mark.cull_mask = 1
		mark.visible = false
	for i in 60:
		await RenderingServer.frame_post_draw
	var clear := await capture()
	var results := []
	for i in marks.size():
		marks[i].visible = true
		var marked := await capture()
		var soil := difference(clear, marked, Vector3(0, 0, 0.8))
		var wall := difference(clear, marked, Vector3(-2, 0.2, 0.3))
		var volume := difference(clear, marked, Vector3(2, 0.2, 0))
		check(soil > 0.06, "The ground still receives its damage mark")
		check(wall < 0.01, "Ground damage does not project onto cover")
		check(volume < 0.015, "Opaque smoke hides the ground mark and does not receive the decal")
		results.append({"kind": "scorch" if i == 0 else "crater", "ground_delta": soil, "wall_delta": wall, "smoke_delta": volume})
		if not output.is_empty(): marked.save_png(output.path_join("%d.png" % i))
		marks[i].visible = false
	if not output.is_empty():
		clear.save_png(output.path_join("clear.png"))
		FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("GROUND_MARKS failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
