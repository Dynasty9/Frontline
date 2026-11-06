extends Node

func stage() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 384)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var camera := Camera3D.new()
	camera.fov = 48
	camera.far = 1600
	vp.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 800
	sun.directional_shadow_fade_start = 0.85
	sun.rotation_degrees = Vector3(-18, -65, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.04, 0.05, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.2
	vp.add_child(env)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.7, 0.55)
	material.roughness = 1
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	ground.mesh = plane
	ground.material_override = material
	vp.add_child(ground)
	for x in range(-3, 4):
		for z in range(-4, 3):
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(14, 8 + posmod(x * 7 + z, 4) * 9, 18)
			box.mesh = mesh
			box.material_override = material
			box.position = Vector3(x * 60, mesh.size.y * 0.5, z * 60)
			vp.add_child(box)
	# A tall caster beyond the camera footprint still casts onto visible receivers.
	var tower := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18, 160, 25)
	tower.mesh = mesh
	tower.material_override = material
	tower.position = Vector3(140, 80, -160)
	vp.add_child(tower)
	return {"viewport": vp, "camera": camera, "sun": sun}

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var before := stage()
	var after := stage()
	var positions := [Vector3(0, 100, 80), Vector3(100, 100, 80), Vector3(0, 250, 100), Vector3(0, 30, 120), Vector3(0, 400, 200)]
	var results := []
	for i in positions.size():
		for side in [before, after]:
			side.camera.position = positions[i]
			side.camera.look_at(Vector3.ZERO)
			side.sun.rotation_degrees.x = -5 if i == 1 else -18
		after.sun.directional_shadow_max_distance = Atmosphere.fitted_shadow_distance(after.camera, 800, 0.85)
		for frame in 12:
			await RenderingServer.frame_post_draw
		var a: Image = before.viewport.get_texture().get_image()
		var b: Image = after.viewport.get_texture().get_image()
		a.convert(Image.FORMAT_RGB8)
		b.convert(Image.FORMAT_RGB8)
		var dark := 0
		var missing := 0
		for y in range(2, 382, 2):
			for x in range(2, 510, 2):
				var covered := true
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var c := a.get_pixel(x + dx, y + dy)
						covered = covered and c.r < 0.35 and c.g < 0.4
				if covered:
					dark += 1
					missing += int(b.get_pixel(x, y).g > a.get_pixel(x, y).g + 0.2)
		var pair := Image.create(1024, 384, false, Image.FORMAT_RGB8)
		pair.blit_rect(a, Rect2i(0, 0, 512, 384), Vector2i.ZERO)
		pair.blit_rect(b, Rect2i(0, 0, 512, 384), Vector2i(512, 0))
		pair.save_png("res://build/shadow-range-%s-%d.png" % [RenderingServer.get_current_rendering_method(), i])
		var row := {"case": i, "distance": after.sun.directional_shadow_max_distance, "dark_interior": dark, "missing": missing}
		results.append(row)
		print("SHADOW_RENDER ", JSON.stringify(row))
		assert(dark > 100 and missing < maxi(4, int(dark * 0.02)), "Fitted cascades must retain interior shadows, including tall remote casters")
	FileAccess.open("res://build/shadow-range-%s.json" % RenderingServer.get_current_rendering_method(), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("SHADOW_RENDER passed")
	get_tree().quit()
