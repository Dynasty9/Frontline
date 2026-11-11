extends Node
## A fixed studio for the whole roster, or a named close-up. No world simulation.
## godot --path . tools/showcase/vehicle-surfaces.tscn -- --surface-out=/tmp/audit
## Add --surface-kinds=tank,heli,... for a selection; --surface-single for close-ups.

var output := "/tmp/vehicle-surfaces"
var kinds: Array[String] = []
var single := false
var team := 0
var offset := Vector3.ZERO
var swatches := false
var panels := false
var fittings := false
var camera_size := 0.0
var grounded := false
var rotor_focus := false
var body_focus := Vector3.INF
var view_direction := Vector3(1, 0.65, -1.25)

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--surface-out="):
			output = arg.trim_prefix("--surface-out=")
		elif arg.begins_with("--surface-kinds="):
			kinds.assign(arg.trim_prefix("--surface-kinds=").split(","))
		elif arg == "--surface-single":
			single = true
		elif arg.begins_with("--surface-team="):
			team = int(arg.trim_prefix("--surface-team="))
		elif arg == "--surface-offset":
			offset = Vector3(117, 35, -81)
		elif arg == "--surface-ground":
			grounded = true
		elif arg.begins_with("--surface-size="):
			camera_size = float(arg.trim_prefix("--surface-size="))
		elif arg.begins_with("--surface-focus="):
			var xyz := arg.trim_prefix("--surface-focus=").split(",")
			body_focus = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		elif arg == "--surface-rotor":
			rotor_focus = true
		elif arg == "--surface-rear":
			view_direction = Vector3(-1, 0.65, 1.25)
		elif arg == "--surface-fittings":
			fittings = true
		elif arg == "--surface-panels":
			panels = true
			swatches = true
		elif arg == "--surface-swatches":
			swatches = true
	if swatches:
		kinds.assign(["armor", "aircraft", "canvas", "rubber", "plastic", "wood", "glass", "steel"] if panels else VehicleMaterials.PROFILES.keys())
	if fittings:
		kinds.assign(["grille", "exhaust", "mudflap", "stowage"])
	if kinds.is_empty():
		for list in [Defs.VEHICLES.keys(), VehicleModels.family_keys(), VmCore.KEYS, VmGunship.KEYS, VmAttack.KEYS, VmFighter.KEYS]:
			for kind: String in list:
				if kind not in kinds:
					kinds.append(kind)
		for i in 5:
			kinds.append("civilian_%d" % i)
		kinds.append_array(["wreck_tank", "wreck_heli", "wreck_patrol_ship"])
		kinds.sort()
	DirAccess.make_dir_recursive_absolute(output)
	var manifest := {"team": team, "seed": 3, "renderer": RenderingServer.get_current_rendering_method(), "models": kinds, "camera_size": camera_size, "grounded": grounded, "panels": panels, "fittings": fittings, "rotor_focus": rotor_focus, "body_focus": str(body_focus), "view_direction": str(view_direction)}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	var per_page := 1 if single else (4 if fittings else (8 if panels else (16 if swatches else 12)))
	for start in range(0, kinds.size(), per_page):
		var grid := GridContainer.new()
		grid.columns = 1 if single else (2 if fittings else 4)
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		add_child(grid)
		for i in range(start, mini(start + per_page, kinds.size())):
			_cell(grid, kinds[i], Vector2i(1600, 900) if single else (Vector2i(800, 450) if fittings else (Vector2i(400, 450) if panels else (Vector2i(400, 225) if swatches else Vector2i(400, 300)))))
		for frame in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := kinds[start] if single else "roster-%02d" % (start / per_page)
		get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))
		print("SURFACE_CAPTURE " + name)
		grid.free()
	print("SURFACE_AUDIT rendered=%d team=%d" % [kinds.size(), team])
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	TestRun.quit(get_tree())

func _cell(grid: GridContainer, kind: String, size: Vector2i) -> void:
	var cell := Control.new()
	cell.custom_minimum_size = size
	grid.add_child(cell)
	var container := SubViewportContainer.new()
	container.size = size
	cell.add_child(container)
	var view := SubViewport.new()
	view.size = size
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	container.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	stage.position = offset
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.19, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.49, 0.63)
	sky_mat.sky_horizon_color = Color(0.82, 0.85, 0.88)
	sky_mat.ground_bottom_color = Color(0.17, 0.19, 0.21)
	sky_mat.ground_horizon_color = Color(0.66, 0.68, 0.7)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 145, 0) if panels or fittings else Vector3(-48, -35, 0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	if grounded:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 80.0
		env.ssao_enabled = true
		env.ssao_radius = 0.7
		env.ssao_intensity = 1.4
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.32, 0.30, 0.27)
		floor_mat.roughness = 0.95
		var floor_mesh := PlaneMesh.new()
		floor_mesh.size = Vector2(200, 200)
		Res.mi(stage, floor_mesh, floor_mat, Vector3(0, -0.015, 0))
	var k: VehicleModels
	if fittings:
		k = VehicleModels.new()
		k.root = Node3D.new()
		match kind:
			"grille": VehicleFittings.grille(k, k.root, Vector3.ZERO, Vector2(2, 1.1), Vector3(0, PI, 0), "paint", Color(0.30, 0.32, 0.23))
			"exhaust": VehicleFittings.exhaust(k, k.root, Vector3(0, -0.8, 0), Vector3.UP, 1.6, 0.18)
			"mudflap": VehicleFittings.mudflap(k, k.root, Vector3.ZERO, Vector2(1.0, 1.1), Vector3(0, PI, 0))
			"stowage": k._bag(k.root, Vector3(1.3, 0.65, 0.85), Vector3.ZERO, "canvas", Color(0.38, 0.37, 0.27))
	elif swatches:
		k = VehicleModels.new()
		k.root = Node3D.new()
		var source := kind if kind not in ["armor", "automotive", "marine"] else "paint"
		var family_name := kind if kind in ["armor", "automotive", "marine", "aircraft"] else "armor"
		if kind == "oxidized":
			source = "rust_steel"
		if kind == "plastic":
			source = "plain_dark"
		if panels:
			k.surface_family = family_name
			VehicleBody.panel(k, k.root, Vector3.ZERO, Vector2(2.0, 1.4), Vector3(0, PI, 0), source)
		else:
			Res.mi(k.root, Res.sphere(1.0, 48), Mats.get_mat(VehicleMaterials.key(source, family_name)), Vector3.ZERO)
	elif kind.begins_with("civilian_"):
		k = VehicleModels.build_car(int(kind.trim_prefix("civilian_")), Color(0.36, 0.16, 0.12))
	else:
		k = VehicleModels.build(kind.trim_prefix("wreck_"), team, 3, kind.begins_with("wreck_"))
	stage.add_child(k.root)
	var bounds := _bounds(k.root, Transform3D.IDENTITY)
	var center := bounds.get_center()
	if rotor_focus and is_instance_valid(k.rotor):
		center = k.rotor.global_position - offset
	if body_focus.is_finite():
		center = body_focus
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size if camera_size > 0.0 else maxf(bounds.size.length() * (1.55 if fittings else 0.78), 1.0)
	camera.far = 1000
	camera.position = center + view_direction.normalized() * bounds.size.length() * 2.0
	camera.look_at(center + offset)
	var label := Label.new()
	label.text = kind.replace("_", " ").to_upper()
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 22 if single else 15)
	cell.add_child(label)

func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var xf := parent * node.transform
	var box := AABB()
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh and mi.visibility_range_begin == 0:
			box = xf * mi.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var cb := _bounds(child, xf)
			if cb.size != Vector3.ZERO:
				box = cb if box.size == Vector3.ZERO else box.merge(cb)
	return box
