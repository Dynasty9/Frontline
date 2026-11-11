extends Node


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	var world := World.new()
	world.settings = {"seed": 3}
	var simulation_state := world.rng.state
	var atmo := Atmosphere.new()
	atmo.world = world
	atmo.detail_tex = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var clouds = load("res://scripts/game/mountain_clouds.gd").new()
	add_child(clouds)
	clouds.setup(atmo)
	assert(world.rng.state == simulation_state)
	assert(clouds.get_child_count() == 8)
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
	clouds.free()
	atmo.free()
	world.free()
	print("MOUNTAIN CLOUDS passed: bounds, tiers, night, reduced motion")
	get_tree().quit()
