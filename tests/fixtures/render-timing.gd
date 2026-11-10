extends Node

class TrackedProbe extends PerfProbe:
	var samples := 0
	var sampled_on_main := true
	func _sample_render_time() -> void:
		samples += 1
		sampled_on_main = sampled_on_main and OS.get_thread_caller_id() == OS.get_main_thread_id()
		super._sample_render_time()

func _ready() -> void:
	var probe := TrackedProbe.new()
	add_child(probe)
	probe.set_process(false)
	if not probe.measuring:
		probe.measuring = true
		RenderingServer.frame_pre_draw.connect(probe._sample_render_time)
	probe.render_cpu_ms = 3.5
	probe.render_gpu_ms = 7.25
	probe.render_setup_ms = 1.0
	var before := probe.samples
	for i in 5:
		var slot := probe._fi
		probe._process(1.0 / 60.0)
		assert(probe.f_rcpu[slot] == 3.5 and probe.f_gpu[slot] == 7.25, "Updates reuse cached renderer timings")
	assert(probe.samples == before, "Game updates must not query the render thread")
	RenderingServer.frame_pre_draw.emit()
	assert(probe.samples == before + 1 and probe.sampled_on_main)
	assert(is_finite(probe.render_cpu_ms) and probe.render_cpu_ms >= 0.0)
	assert(is_finite(probe.render_gpu_ms) and probe.render_gpu_ms >= 0.0)
	if DisplayServer.get_name() != "headless":
		var cube := MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		add_child(cube)
		var camera := Camera3D.new()
		camera.position.z = 4
		add_child(camera)
		for i in 24:
			await RenderingServer.frame_post_draw
		assert(probe.samples > before + 12 and probe.sampled_on_main, "Real draws publish timings on the main thread")
		assert(probe.render_cpu_ms > 0.0)
	probe.free()
	await get_tree().process_frame
	print("RENDER_TIMING passed")
	get_tree().quit()
