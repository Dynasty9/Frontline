extends Node3D
## Fixed, renderer-backed barrage benchmark. Results describe this device and
## scene only; they are not a hardware-independent frame-rate claim.
var field: World
var samples: Array[float] = []
var peak_draws := 0
var peak_objects := 0
var peak_memory := 0

func _ready() -> void:
	TestRun.watch()
	seed(712)
	Settings.v["effects"] = 2
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = false
	get_viewport().scaling_3d_scale = 1.0
	# Effect internals consume cosmetic randomness differently across versions;
	# keep barrage positions identical with their own seeded generator.
	var locations := RandomNumberGenerator.new()
	locations.seed = 712
	field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 24, 42)
	add_child(camera)
	camera.look_at(Vector3(0, 3, 0))
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.2, 0.25, 0.3)
	add_child(environment)
	Res.mi(self, Res.box(Vector3(120, 0.2, 120)), Res.mat(Color(0.3, 0.26, 0.2)), Vector3(0, -0.11, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	field.fx.vfx.prewarm(Vector3.ZERO)
	field.fx.gunfx.prewarm(Vector3.ZERO)
	for i in 60:
		await RenderingServer.frame_post_draw
	for frame in 240:
		var start := Time.get_ticks_usec()
		if frame % 8 == 0 and frame < 180:
			for j in 3:
				var p := Vector3(locations.randf_range(-15, 15), 0.1, locations.randf_range(-8, 8))
				field.fx.vfx.explode(p, 1.4)
		await RenderingServer.frame_post_draw
		if frame >= 60:
			samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		peak_memory = maxi(peak_memory, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	samples.sort()
	var total := 0.0
	for ms in samples: total += ms
	print("BLAST_BENCH " + JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string, "width": get_viewport().size.x, "height": get_viewport().size.y, "msaa_samples": 2, "render_scale": get_viewport().scaling_3d_scale, "frames": samples.size(), "mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)], "peak_draw_calls": peak_draws, "peak_objects": peak_objects, "effect_nodes": count_nodes(field.fx), "texture_mib": peak_memory / 1048576.0, "seed": 712, "burst_count": 69, "effects_quality": Settings.get_v("effects")}))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit()

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total
