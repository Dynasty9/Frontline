extends Node


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	var world := World.new()
	world.settings = {"seed": 3}
	var simulation_state := world.rng.state
	var atmo := Atmosphere.new()
	atmo.world = world
	var clouds = load("res://scripts/game/mountain_clouds.gd").new()
	add_child(clouds)
	clouds.setup(atmo)
	assert(world.rng.state == simulation_state)
	assert(clouds.get_child_count() == 8)
	var noise: Texture3D = clouds.material.get_shader_parameter("noise_tex")
	assert(noise.get_width() == 64 and noise.get_height() == 64 and noise.get_depth() == 64)
	for bank: MeshInstance3D in clouds.get_children():
		var half_extent: Vector3 = (bank.basis.x.abs() + bank.basis.y.abs() + bank.basis.z.abs()) * 0.5
		assert(absf(bank.position.x) - half_extent.x > MapDims.HALF or absf(bank.position.z) - half_extent.z > MapDims.HALF)
	for quality in 5:
		Settings.v.mountain_clouds = quality
		clouds.apply_settings(atmo)
		assert(clouds.visible == (quality > 0))
		assert(clouds.material.get_shader_parameter("steps") == [8, 8, 12, 20, 32][quality])
	atmo.mood = "night"
	Settings.v.reduce_motion = true
	clouds.apply_settings(atmo)
	assert(clouds.material.get_shader_parameter("still"))
	assert(clouds.material.get_shader_parameter("lit_color").r < 0.1)
	atmo.mood = "day"
	clouds.apply_settings(atmo)
	var clear_coverage: float = clouds.material.get_shader_parameter("coverage")
	atmo.mood = "rain"
	clouds.apply_settings(atmo)
	assert(float(clouds.material.get_shader_parameter("coverage")) < clear_coverage)
	if DisplayServer.get_name() != "headless":
		get_viewport().transparent_bg = true
		var camera := Camera3D.new()
		add_child(camera)
		var bank: MeshInstance3D = clouds.get_child(0)
		camera.position = bank.position + Vector3(0, 0, 1200)
		camera.far = 5000.0
		camera.look_at(bank.position)
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered := get_viewport().get_texture().get_image()
		var center := rendered.get_pixel(rendered.get_width() / 2, rendered.get_height() / 2)
		assert(center.a > 0.05 and center.get_luminance() > 0.02)
		camera.free()
	clouds.free()
	atmo.free()
	world.free()
	print("MOUNTAIN CLOUDS passed: bounds, tiers, night, reduced motion")
	get_tree().quit()
