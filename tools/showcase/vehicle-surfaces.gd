extends Node
## A fixed studio for the whole roster, or a named close-up. No world simulation.
## godot --path . tools/showcase/vehicle-surfaces.tscn -- --surface-out=/tmp/audit
## Add --surface-kinds=tank,heli,... for a selection; --surface-single for close-ups.

var output := "/tmp/vehicle-surfaces"
var kinds: Array[String] = []
var single := false
var team := 0
## The model seed: it picks per-vehicle details such as tactical numbers.
var model_seed := 3
var offset := Vector3.ZERO
var swatches := false
var panels := false
var fittings := false
var accessories := false
var construction := false
var antenna_motion := false
var motion_models: Array[VehicleModels] = []
var camera_size := 0.0
var grounded := false
var rotor_focus := false
## --surface-flight: rotors and propellers as they look turning at flight speed
## (each blur disc shown in place of its blades, as Vehicle does in the air),
## seen from above.
var flight := false
var body_focus := Vector3.INF
var view_direction := Vector3(1, 0.65, -1.25)
## The twenty shared parts of the component extraction (--surface-shared-parts).
const SHARED_PARTS := ["turret_ring", "sight", "panoramic_sight", "cupola", "era_bricks", "panel_hatch", "evacuator", "coax", "autocannon", "hmg", "mmg", "gmg", "rotary", "launch_tube", "dome_light", "nav_light", "rotor_mast", "turbine_exhaust", "fender", "fuel_tank", "roll"]

func _ready() -> void:
	TestRun.watch()
	if "--vehicle-roll-call" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file", "res://tools/showcase/vehicle-circuit.tscn")
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--surface-out="):
			output = arg.trim_prefix("--surface-out=")
		elif arg.begins_with("--surface-kinds="):
			kinds.assign(arg.trim_prefix("--surface-kinds=").split(","))
		elif arg == "--surface-single":
			single = true
		elif arg.begins_with("--surface-team="):
			team = int(arg.trim_prefix("--surface-team="))
		elif arg.begins_with("--surface-seed="):
			model_seed = int(arg.trim_prefix("--surface-seed="))
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
		elif arg == "--surface-flight":
			flight = true
			view_direction = Vector3(0.7, 1.5, -1.0)  # (from above, as the RTS camera sees an aircraft)
		elif arg == "--surface-rear":
			view_direction = Vector3(-1, 0.65, 1.25)
		elif arg == "--surface-antenna-motion":
			antenna_motion = true
		elif arg == "--surface-construction":
			construction = true
		elif arg == "--surface-shared-parts":
			construction = true
			kinds.assign(SHARED_PARTS)
		elif arg == "--surface-accessories":
			accessories = true
			fittings = true
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
		kinds.assign(["antenna", "mirror_front", "mirror_back", "barrel"] if accessories else ["grille", "exhaust", "mudflap", "stowage"])
	if construction and kinds.is_empty():
		kinds.assign(["jerrycan", "ammo_can", "tow_shackle", "smoke_tubes", "periscope", "hatch", "tail_lights", "lifting_eye", "rectangular_lights"])
	if antenna_motion:
		kinds.assign(["slammer", "slammer"])
		body_focus = Vector3(1.05, 3.5, 3.15)
		camera_size = 2.5
		view_direction = Vector3(-1, 0.35, 1.25)
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
	var manifest := {"team": team, "seed": model_seed, "renderer": RenderingServer.get_current_rendering_method(), "models": kinds, "camera_size": camera_size, "grounded": grounded, "panels": panels, "fittings": fittings, "accessories": accessories, "construction": construction, "rotor_focus": rotor_focus, "flight": flight, "body_focus": str(body_focus), "view_direction": str(view_direction)}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	var per_page := 1 if single else (4 if fittings else (8 if panels else (16 if swatches else 12)))
	for start in range(0, kinds.size(), per_page):
		var grid := GridContainer.new()
		grid.columns = 2 if antenna_motion else (1 if single else (2 if fittings else 4))
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		add_child(grid)
		for i in range(start, mini(start + per_page, kinds.size())):
			_cell(grid, kinds[i], Vector2i(800, 900) if antenna_motion else Vector2i(1600, 900) if single else (Vector2i(800, 450) if fittings else (Vector2i(400, 450) if panels else (Vector2i(400, 225) if swatches else Vector2i(400, 300)))))
		if antenna_motion:
			await _capture_antenna_motion()
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
	if construction:
		k = VehicleModels.new()
		k.root = Node3D.new()
		match kind:
			"jerrycan": VmCore._jerry(k, k.root, Vector3.ZERO)
			"ammo_can": VmCore._ammo_can(k, k.root, Vector3.ZERO)
			"tow_shackle": VmCore._shackle(k, k.root, Vector3.ZERO)
			"smoke_tubes": VmCore._smoke(k, k.root, Vector3.ZERO, 0.0)
			"periscope": VmCore._periscope(k, k.root, Vector3.ZERO)
			"hatch": VmCore._hatch(k, k.root, Vector3.ZERO, 0.3, "paint", Color(0.3, 0.33, 0.22))
			"tail_lights": VmCore._taillight(k, k.root, Vector3.ZERO)
			"lifting_eye": VmCore._eye(k, k.root, Vector3.ZERO)
			"rectangular_lights": VmCsat._headlight(k, k.root, Vector3.ZERO)
			"storage": VehicleEquipment.storage(k, k.root, Vector3.ZERO, Vector3(0.8, 0.36, 0.45), "paint", Color(0.3, 0.33, 0.22))
			"winch": VehicleEquipment.winch(k, k.root, Vector3.ZERO, Vector3(0.7, 0.3, 0.3))
			"sensor_ball": VehicleEquipment.sensor(k, k.root, Vector3.ZERO, Vector3.ONE * 0.4, "paint", Color(0.3, 0.33, 0.22), "ball")
			"sensor": VehicleEquipment.sensor(k, k.root, Vector3.ZERO, Vector3(0.5, 0.4, 0.4), "paint", Color(0.3, 0.33, 0.22))
			"vessel": VehicleEquipment.vessel(k, k.root, Vector3.ZERO, Vector3(1.4, 1.2, 2.5), [-0.8, 0.8], "paint", Color(0.3, 0.33, 0.22))
			"skirt": VehicleEquipment.skirt(k, k.root, Vector3.ZERO, Vector3(0.08, 0.6, 0.8), -1, "paint", Color(0.3, 0.33, 0.22))
			"door": VehicleDoors.rectangle(k, k.root, Vector3.ZERO, Vector2(0.7, 0.9), Vector3(0, PI, 0), "paint", Color(0.3, 0.33, 0.22))
			"seat": VehicleCab.seat(k, k.root, Vector3.ZERO)
			"pallet": VehicleCargo.pallet(k, k.root, Vector3.ZERO, Vector2(1, 0.8), 0.15)
			"restraints":
				k._box(k.root, Vector3(0.7, 0.6, 0.9), Vector3(0, 0.3, 0), "wood")
				VehicleCargo.restraints(k, k.root, Vector3.ZERO, Vector3(0.7, 0.6, 0.9), [-0.3, 0.3])
			"frame": VehicleRunningGear.frame(k, k.root, Vector3.ZERO, 0.45, 2.0, Vector2(0.12, 0.2), [-0.7, 0, 0.7])
			"axle": VehicleRunningGear.axle(k, k.root, Vector3.ZERO, 1.4, 0.1, 0.45)
			"gear": VehicleAircraft.gear_leg(k, k.root, Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), 0.08)
			"pylon": VehicleAircraft.hardpoint(k, k.root, Vector3.ZERO, 0.8, 0.35, Color(0.35, 0.38, 0.4))
			"rocket_pod": VehicleAircraft.rocket_pod(k, k.root, Vector3.ZERO, 0.25, 1.2)
			"mooring": VehicleMarine.mooring(k, k.root, Vector3.ZERO, Vector3(0.55, 0.2, 0.18))
			"mirror": VehicleFittings.mirror(k, k.root, Vector3.ZERO, Vector2(0.24, 0.42), PI, [Vector3(0.35, 0.14, 0), Vector3(0.35, -0.14, 0)])
			"exhaust": VehicleFittings.exhaust(k, k.root, Vector3(0, -0.6, 0), Vector3.UP, 1.2, 0.12)
			"turret_ring":
				k._box(k.root, Vector3(2.4, 0.04, 2.4), Vector3(0, -0.02, 0), "paint", Color(0.3, 0.33, 0.22))
				VehicleMounts.turret_ring(k, k.root, Vector3(0, 0.05, 0), 0.95, 1.0, 0.1, "paint", Color(0.3, 0.33, 0.22))
			"sight": VehicleMounts.sight(k, k.root, Vector3.ZERO, Vector3(0.36, 0.3, 0.42), [], "paint", Color(0.3, 0.33, 0.22))
			"panoramic_sight": VehicleMounts.sight(k, k.root, Vector3(0, 0.2, 0), Vector3(0.3, 0.24, 0.3), [Rect2(Vector2(-0.06, 0.02), Vector2(0.12, 0.12)), Rect2(Vector2(0.09, 0.02), Vector2(0.08, 0.08))], "paint", Color(0.3, 0.33, 0.22), Vector3(0.1, 0.12, 0.4))
			"cupola":
				VehicleMounts.cupola(k, k.root, Vector3(0, 0.08, 0), 0.36, 0.38, 0.16, 5, -0.9, 0.45, "paint", Color(0.3, 0.33, 0.22))
				VehicleFittings.hatch(k, k.root, Vector3(0, 0.19, 0), 0.32, "paint", Color(0.3, 0.33, 0.22), 1.0, 0.06)
			"era_bricks":
				for i in 3:
					for j in 2:
						VehicleMounts.era_brick(k, k.root, Vector3((i - 1) * 0.33, (j - 0.5) * 0.23, 0.05), Vector3(0.3, 0.2, 0.1), Vector3(0, PI, 0), "paint", Color(0.3, 0.33, 0.22))
			"panel_hatch": VehicleFittings.panel_hatch(k, k.root, Vector3(0, 0.03, 0), Vector3(0.62, 0.06, 0.6), "paint", Color(0.3, 0.33, 0.22), -1.0)
			"evacuator":
				VehicleFittings.barrel(k, k.root, Vector3(0, 0, 0.6), Vector3(0, 0, -0.9), 0.07, "paint", Color(0.36, 0.34, 0.26), false)
				VehicleFittings.evacuator(k, k.root, Vector3(0, 0, -0.2), 0.118, 0.56, "paint", Color(0.36, 0.34, 0.26))
			"coax": VehicleWeapons.coax(k, k.root, Vector3.ZERO, 0.3, 0.025)
			"autocannon": VehicleWeapons.autocannon(k, k.root, Vector3(0, 0, 1.15), Vector3(0, 0, -1.15), Vector2(0.1, 0.3), Vector2(0.045, 0.04), Vector2(0.065, 0.24), "gunmetal_w", null, 2)
			"hmg": VehicleWeapons.hmg(k, k.root, Vector3(0, 0, 0.75), Vector3(0, 0, -0.75), 1.0, -1.0, true)
			"mmg": VehicleWeapons.mmg(k, k.root, Vector3(0, 0, 0.46), Vector3(0, 0, -0.47))
			"gmg": VehicleWeapons.gmg(k, k.root, Vector3(0, 0, 0.45), Vector3(0, 0, -0.45))
			"rotary":
				k._box(k.root, Vector3(0.15, 0.17, 0.34), Vector3(0, 0, 0.42), "gunmetal_w")
				VehicleWeapons.rotary(k, k.root, Vector3(0, 0, 0.25), Vector3(0, 0, -0.55), 6, 0.042, 0.013, [0.5, 0.95])
			"launch_tube": VehicleWeapons.launch_tube(k, k.root, Vector3.ZERO, 0.085, 1.25, "paint", Color(0.33, 0.35, 0.27))
			"dome_light":
				for i in 2:
					k._box(k.root, Vector3(0.3, 0.04, 0.3), Vector3((i - 0.5) * 0.36, -0.06, 0), "paint", Color(0.3, 0.33, 0.22))
					VehicleFittings.dome_light(k, k.root, Vector3((i - 0.5) * 0.36, 0, 0), 0.07, Color(0.55, 0.08, 0.06) if i == 0 else Color(0.9, 0.9, 0.86))
			"nav_light":
				for side: float in [-1.0, 1.0]:
					k._box(k.root, Vector3(0.1, 0.16, 0.3), Vector3(side * 0.12, 0, 0), "paint", Color(0.3, 0.33, 0.22))
					VehicleFittings.nav_light(k, k.root, Vector3(side * 0.2, 0, 0), Vector3(0.06, 0.07, 0.12), side)
			"rotor_mast": VehicleRotors.mast(k, k.root, Vector3.ZERO, 0.16, 0.2, 0.55, [Vector2(-0.02, 0.34)])
			"turbine_exhaust": VehicleAircraft.turbine_exhaust(k, k.root, Vector3(0, 0, 0.3), Vector3(0, 0.05, -0.3), 0.2, 0.18)
			"fender":
				VehicleBody.fender(k, k.root, Vector3(0, 0.1, 0), Vector3(0.6, 0.04, 1.6), 1.0, "paint", Color(0.3, 0.33, 0.22))
				VehicleBody.fender(k, k.root, Vector3(0, -0.02, -0.88), Vector3(0.58, 0.04, 0.4), 1.0, "paint", Color(0.3, 0.33, 0.22), Vector3(-0.6, 0, 0))
			"fuel_tank":
				VehicleRunningGear.fuel_tank(k, k.root, Vector3(-0.35, 0, 0), Vector3(0.52, 0.52, 1.1), 1.0, "paint", Color(0.3, 0.33, 0.22))
				VehicleRunningGear.fuel_tank(k, k.root, Vector3(0.35, 0, 0), Vector3(0.5, 0.52, 1.1), 1.0, "paint", Color(0.3, 0.33, 0.22), false)
			"roll": VehicleCloth.roll(k, k.root, Vector3.ZERO, 0.17, 0.9, Vector3(0, 0, PI / 2), Color(0.42, 0.38, 0.27))
	elif fittings:
		k = VehicleModels.new()
		k.root = Node3D.new()
		match kind:
			"antenna": VehicleFittings.antenna(k, k.root, Vector3.ZERO, 0.65)
			"mirror_front": VehicleFittings.mirror(k, k.root, Vector3.ZERO, Vector2(0.24, 0.42), PI - 0.3, [Vector3(-0.3, 0.16, 0), Vector3(-0.3, -0.16, 0)])
			"mirror_back": VehicleFittings.mirror(k, k.root, Vector3.ZERO, Vector2(0.24, 0.42), -0.3, [Vector3(-0.3, 0.16, 0), Vector3(-0.3, -0.16, 0)])
			"barrel": VehicleFittings.barrel(k, k.root, Vector3(0, 0, 0.8), Vector3(0, 0, -0.8), 0.10, "paint", Color(0.3, 0.32, 0.24))
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
		k = VehicleModels.build(kind.trim_prefix("wreck_"), team, model_seed, kind.begins_with("wreck_"))
	stage.add_child(k.root)
	if flight:
		_spin_up(k.root)
		if k.blur and k.blades:
			k.blur.visible = true
			k.blades.visible = false
	if antenna_motion:
		motion_models.append(k)
	var bounds := _bounds(k.root, Transform3D.IDENTITY)
	var center := bounds.get_center()
	if rotor_focus and is_instance_valid(k.rotor):
		center = k.rotor.global_position - offset
	if body_focus.is_finite():
		center = body_focus
	var part_sizes := {"jerrycan": 0.9, "ammo_can": 0.6, "storage": 1.2, "winch": 1.0, "sensor": 0.9, "sensor_ball": 0.9, "vessel": 3.6, "skirt": 1.3, "door": 1.5, "seat": 1.0, "pallet": 1.5, "restraints": 1.5, "frame": 2.8, "axle": 2.0, "gear": 1.5, "pylon": 1.3, "rocket_pod": 1.8, "mooring": 0.9, "mirror": 0.9, "exhaust": 1.8, "hatch": 1.0, "turret_ring": 2.6, "sight": 0.7, "panoramic_sight": 0.9, "cupola": 1.1, "era_bricks": 1.2, "panel_hatch": 0.9, "evacuator": 1.6, "coax": 0.5, "autocannon": 2.4, "hmg": 1.7, "mmg": 1.1, "gmg": 1.1, "rotary": 1.1, "launch_tube": 1.4, "dome_light": 0.6, "nav_light": 0.6, "rotor_mast": 1.0, "turbine_exhaust": 0.9, "fender": 2.0, "fuel_tank": 1.6, "roll": 1.1}
	if construction and part_sizes.has(kind) and not body_focus.is_finite():
		center = Vector3.ZERO
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size if camera_size > 0.0 else maxf(bounds.size.length() * (1.55 if fittings else 0.78), 1.0)
	if construction and part_sizes.has(kind) and camera_size <= 0:
		camera.size = part_sizes[kind]
	camera.far = 1000
	camera.position = center + view_direction.normalized() * bounds.size.length() * 2.0
	camera.look_at(center + offset)
	var label := Label.new()
	label.text = ("RIGID REFERENCE" if motion_models.size() == 1 else "MOTION RESPONSE") if antenna_motion else kind.replace("_", " ").to_upper()
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 22 if single else 15)
	cell.add_child(label)

static func _bounds(node: Node3D, parent: Transform3D) -> AABB:
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


## Camera-follow test rig: both views hold the same vehicle fixed; the right
## applies the production helper to explicit world-space travel inputs.
func _capture_antenna_motion() -> void:
	var caption := Label.new()
	caption.position = Vector2(18, 845)
	caption.add_theme_font_size_override("font_size", 24)
	add_child(caption)
	for frame in 180:
		var t := frame / 15.0
		var travel := Vector3.ZERO
		var phase := "Stopped / settling"
		if t >= 1 and t < 3:
			travel = Vector3(0, 0, -16)
			phase = "Forward · 16 m/s"
		elif t >= 4 and t < 6:
			travel = Vector3(16, 0, 0)
			phase = "Lateral travel · 16 m/s"
		elif t >= 7 and t < 9:
			travel = Vector3(0, 0, 12)
			phase = "Reverse · 12 m/s"
		caption.text = "Controlled travel input: " + phase
		motion_models[1].update_antennas(travel, 1.0 / 15)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("motion-%03d.png" % frame))
	caption.free()


## Every rotor and propeller below `n` at flight speed: its "Blur" disc shown,
## its "Blades" hidden.
func _spin_up(n: Node) -> void:
	var blur := n.get_node_or_null("Blur") as Node3D
	var blades := n.get_node_or_null("Blades") as Node3D
	if blur and blades:
		blur.visible = true
		blades.visible = false
	for c in n.get_children():
		_spin_up(c)
