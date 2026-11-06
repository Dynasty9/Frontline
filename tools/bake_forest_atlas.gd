extends SceneTree
func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-12000, -12000))
	call_deferred("bake")
func bake() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("res://build/terrain/foliage-source/models/fir-variants.gltf", state) == OK)
	var scene := doc.generate_scene(state)
	for child in scene.get_children():
		if child is Node3D:
			child.position = Vector3.ZERO
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.5
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	viewport.add_child(camera)
	var atlas := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for i in 4:
		var kinds := [0, 1, 2, 0]
		var heights := [18.85, 13.97, 14.43]
		for k in scene.get_child_count():
			var tree: Node3D = scene.get_child(k)
			tree.visible = k == kinds[i]
			tree.scale = Vector3.ONE * (14.4 / heights[k])
		var angle := i * PI * 0.5
		camera.position = Vector3(sin(angle) * 25, 9, cos(angle) * 25)
		camera.look_at(Vector3(0, 7.2, 0))
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		atlas.blit_rect(img, Rect2i(0,0,512,512), Vector2i((i & 1) * 512, (i >> 1) * 512))
	assert(atlas.save_png("res://assets/foliage/fir_impostor.png") == OK)
	print("FIR ATLAS SAVED")
	viewport.queue_free()
	await process_frame
	quit()
