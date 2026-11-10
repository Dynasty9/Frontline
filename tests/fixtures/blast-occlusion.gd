extends Node3D
## Renderer-backed regression: move an opaque surface through a cloud and
## inspect actual pixels. Run with both Forward+ and Compatibility, not headless.
var failures := 0
var output := ""
var shader_path := "res://scripts/shaders/blast_flipbook.gdshader"

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func texture(color: Color) -> ImageTexture:
	var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func sample() -> float:
	# A changed material/depth pass must reach the rendered image first.
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	return image.get_pixel(image.get_width() / 2, image.get_height() / 2).r

func _ready() -> void:
	TestRun.watch()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-msaa": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		if arg.begins_with("--results="): output = arg.get_slice("=", 1)
		if arg.begins_with("--shader="): shader_path = arg.get_slice("=", 1)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 0, 10)
	camera.current = true
	camera.size = 6.0
	var cover := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 20, 0.2)
	cover.mesh = box
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	cover.material_override = black
	add_child(cover)
	var cloud := MeshInstance3D.new()
	cloud.mesh = QuadMesh.new()
	cloud.custom_aabb = AABB(Vector3(-4, -4, -4), Vector3.ONE * 8)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string(shader_path)
	material.shader = shader
	material.set_shader_parameter("bounds_map", texture(Color(0, 0, 1, 1)))
	material.set_shader_parameter("negative_map", texture(Color(0.8, 0.8, 0.8, 0)))
	material.set_shader_parameter("center_height", 0.0)
	material.set_shader_parameter("span", 4.0)
	material.set_shader_parameter("tint", Color.WHITE)
	material.set_shader_parameter("sun_energy", 0.0)
	material.set_shader_parameter("amb_col", Color.WHITE)
	material.set_shader_parameter("amb_energy", 1.0)
	material.set_shader_parameter("wind", Vector3.ZERO)
	cloud.material_override = material
	add_child(cloud)
	# Give asynchronous renderer pipelines time to finish before reading depth.
	# This mirrors the world's effect prewarming, including the MSAA resolve.
	material.set_shader_parameter("positive_map", texture(Color(0.8, 0.8, 0.8, 0.8)))
	for i in 60:
		await RenderingServer.frame_post_draw
	var results := []
	for projection in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		for alpha in [0.8, 1.0]:
			material.set_shader_parameter("positive_map", texture(Color(0.8, 0.8, 0.8, alpha)))
			var pixels := []
			for separation in [-2.2, -0.3, -0.01, 0.01, 0.3, 2.2]:
				cover.position.z = -separation - 0.1
				pixels.append(await sample())
			check(pixels[0] < 0.005, "Foreground cover completely hides the cloud")
			check(pixels[1] > 0.1, "The visible front of the cloud survives when its middle is behind cover")
			check(absf(pixels[3] - pixels[2]) < 0.03, "Crossing the billboard plane has no opaque cut")
			check(pixels[5] > 0.5, "A cloud ahead of cover stays visible")
			for i in range(1, pixels.size()):
				check(pixels[i] >= pixels[i - 1] - 0.005, "Visible density increases as cover moves behind the cloud")
			results.append({"projection": projection, "alpha": alpha, "pixels": pixels})
	# A fully opaque atlas texel must still respond to lower dust density;
	# otherwise reducing the setting leaves a solid wall at the cloud's core.
	cover.position.z = -3.1
	material.set_shader_parameter("ground_dust", 1.0)
	material.set_shader_parameter("opacity", 0.4)
	material.set_shader_parameter("duration", 3.8)
	material.set_shader_parameter("age", 0.02)
	var opening := await sample()
	material.set_shader_parameter("age", 0.3)
	var peak := await sample()
	material.set_shader_parameter("age", 3.4)
	var clearing := await sample()
	material.set_shader_parameter("ground_dust", 0.0)
	material.set_shader_parameter("opacity", 1.0)
	material.set_shader_parameter("age", 0.3)
	var dense := await sample()
	check(peak > opening + 0.05, "Dust develops after the opening impulse")
	check(peak < dense - 0.04, "Lower dust density opens even saturated atlas texels")
	check(clearing < peak - 0.1, "Dust clears while the impact aftermath remains visible")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "msaa": get_viewport().msaa_3d, "samples": results, "failures": failures}, "\t"))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("BLAST_OCCLUSION failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
