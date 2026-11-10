extends Node
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var grass := Grass.new()
	var mesh := grass._make_bush()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.38, 0.1)
	material.roughness = 1.0
	var transforms := []
	var colors := []
	for i in 1024:
		transforms.append(Transform3D(Basis.from_euler(Vector3(0.2, i * 0.01, 0.4)).scaled(Vector3(1, 2, 3)), Vector3((i % 32) * 3 - 48, 0, (i / 32) * 3 - 48)))
		colors.append(Color(0.2, 0.4, 0.6, 0.8))
	var totals := [0, 0]
	var reference_colors := PackedColorArray()
	for run in 40:
		var mode := run % 4 in [1, 2]
		var start := Time.get_ticks_usec()
		var node: MultiMeshInstance3D
		if mode:
			node = grass._mm(mesh, material, transforms, colors, 170.0)
		else:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i, transforms[i])
				mm.set_instance_custom_data(i, colors[i])
			node = MultiMeshInstance3D.new()
			node.multimesh = mm
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = 170.0
			node.visibility_range_end_margin = 12.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			grass.add_child(node)
		totals[int(mode)] += Time.get_ticks_usec() - start
		if run == 0:
			for i in transforms.size():
				reference_colors.append(node.multimesh.get_instance_custom_data(i))
		if mode:
			for i in transforms.size():
				assert(node.multimesh.get_instance_transform(i).is_equal_approx(transforms[i]))
				assert(node.multimesh.get_instance_custom_data(i).is_equal_approx(reference_colors[i]), "Bulk upload must preserve the renderer's custom-data precision")
		if run in [0, 1] and OS.has_environment("FL_BUFFER_CAPTURE"):
			grass.remove_child(node)
			add_child(node)
			var camera := Camera3D.new()
			add_child(camera)
			camera.position = Vector3(0, 55, 65)
			camera.look_at(Vector3.ZERO)
			var light := DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-50, -30, 0)
			add_child(light)
			for frame in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/vegetation-" + ("after" if mode else "before") + ".png")
			camera.free()
			light.free()
		node.free()
		await get_tree().process_frame
	print("BUFFER_CHECK old_us=", totals[0] / 20.0, " bulk_us=", totals[1] / 20.0)
	grass.free()
	get_tree().quit()
