extends Node

func stage() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 224)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(2.4, 1.7, -3.3)
	camera.look_at(Vector3(0, 0.95, 0))
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation_degrees = Vector3(-45, 145, 0)
	return viewport


func _ready() -> void:
	assert(DisplayServer.get_name() != "headless", "This comparison requires a renderer")
	var original := stage()
	var copied := stage()
	var units := ["rifleman", "rpg", "mortar_gunner", "engineer", "fpv_op", "bearer"]
	var sheet := Image.create(384, 224 * units.size(), false, Image.FORMAT_RGBA8)
	for i in units.size():
		var unit: String = units[i]
		var model := SoldierModel.new()
		original.add_child(model)
		model.build(unit, int(Defs.UNITS[unit].team), 71)
		var copy := model.duplicate_for_soldier(71)
		copied.add_child(copy)
		for actor: SoldierModel in [model, copy]:
			actor.pose(0.25, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.SHOOT, 0.0, false, true)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var expected := original.get_texture().get_image()
		var actual := copied.get_texture().get_image()
		var difference := 0.0
		var lit := 0
		for y in 224:
			for x in 192:
				var a := actual.get_pixel(x, y)
				var b := expected.get_pixel(x, y)
				difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				lit += int(maxf(b.r, maxf(b.g, b.b)) > 0.1)
		print("TEMPLATE_VISUAL %s difference=%.6f" % [unit, difference / (192 * 224 * 3)])
		assert(lit > 100, "The comparison must contain a visible soldier")
		assert(difference / (192 * 224 * 3) < 0.001, "Copied skin, kit, weapons and posed joints must match")
		expected.convert(Image.FORMAT_RGBA8)
		actual.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(expected, Rect2i(0, 0, 192, 224), Vector2i(0, i * 224))
		sheet.blit_rect(actual, Rect2i(0, 0, 192, 224), Vector2i(192, i * 224))
		model.free()
		copy.free()
	sheet.save_png("res://build/soldier-template-%s.png" % RenderingServer.get_current_rendering_method())
	print("SOLDIER_TEMPLATE_VISUAL passed")
	get_tree().quit()
