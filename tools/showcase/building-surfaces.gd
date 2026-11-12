extends Node
## A fixed studio for buildings, built from the same preview models as the
## Field Manual. No world simulation, so the same subject renders identically
## on two revisions.
## godot --path . tools/showcase/building-surfaces.tscn -- --building-out=/tmp/buildings
## Add --building-kinds=house_pitched,barracks,... for a selection, --building-single
## for one large close-up per image, --building-rear for the back quarter, and
## --building-components for the shared construction parts on their own,
## --building-night for the lamps lit and the sun down. Any
## structure kind can be named with its side (and variant): barricade:1:0.

const SUBJECTS := ["house_pitched", "house_flat", "house_window", "house_door", "barracks", "factory",
	"research", "medic_tent", "bunker", "bunker_rebel", "fob", "town", "watchtower", "low_wall_stone",
	"low_wall_brick", "tall_wall", "bridge", "dock"]
const COMPONENTS := ["wall_plaster", "wall_brick", "wall_stone", "wall_timber", "wall_corrugated", "wall_precast",
	"roof_tile", "roof_sheet", "roof_flat", "roof_lean_to", "window", "window_shutters", "window_broken", "door_panelled",
	"door_ledged", "door_steel", "roller_door", "louvre", "gutter_downpipe", "chimney", "ac_unit", "water_tank",
	"dish", "mast", "drum", "crate", "pallet", "wire_cable", "wire_barbed", "wire_topping"]

var output := "/tmp/building-surfaces"
var kinds: Array[String] = []
var single := false
var components := false
var view_direction := Vector3(1.0, 0.7, -1.35)
var night := false  # --building-night: the lamps on, the sun down
var cameras := {}  # subject -> [centre x, y, z, size, distance] as framed (in capture.json)
var framing := {}  # the same, read from an earlier run's capture.json (--building-match)


func _ready() -> void:
	TestRun.watch()
	if "--offscreen" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		# As main.gd does for render copies: restore the minimized window far off-screen.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-12000, -12000))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(Vector2i(-12000, -12000))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--building-out="):
			output = arg.trim_prefix("--building-out=")
		elif arg.begins_with("--building-kinds="):
			kinds.assign(arg.trim_prefix("--building-kinds=").split(","))
		elif arg == "--building-single":
			single = true
		elif arg == "--building-rear":
			view_direction = Vector3(-1.0, 0.7, 1.35)
		elif arg == "--building-components":
			components = true
		elif arg == "--building-night":
			night = true
		elif arg.begins_with("--building-match="):
			# frame every subject as an earlier run did: a matched before and after
			var earlier = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--building-match=")))
			if earlier is Dictionary:
				framing = earlier.get("cameras", {})
	if kinds.is_empty():
		kinds.assign(COMPONENTS if components else SUBJECTS)
	RenderingServer.global_shader_parameter_set("window_glow", 1.0 if night else 0.0)
	DirAccess.make_dir_recursive_absolute(output)
	var manifest := {"renderer": RenderingServer.get_current_rendering_method(), "subjects": kinds, "single": single,
		"components": components, "view_direction": str(view_direction)}
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	var per_page := 1 if single else (6 if components else 6)
	for start in range(0, kinds.size(), per_page):
		var grid := GridContainer.new()
		grid.columns = 1 if single else 3
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		add_child(grid)
		for i in range(start, mini(start + per_page, kinds.size())):
			_cell(grid, kinds[i], Vector2i(1600, 900) if single else Vector2i(533, 450))
		for frame in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := kinds[start] if single else "%s-%02d" % ["components" if components else "buildings", start / per_page]
		get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))
		print("BUILDING_CAPTURE " + name)
		grid.free()
	manifest["cameras"] = cameras
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
	print("BUILDING_AUDIT rendered=%d" % kinds.size())
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
	if night:
		sky_mat.sky_top_color = Color(0.02, 0.03, 0.06)
		sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.12)
		sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
		sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.08)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_energy = 0.12 if night else 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0) if view_direction.z < 0 else Vector3(-42, 142, 0)
	sun.light_energy = 0.18 if night else 1.25
	if night:
		sun.light_color = Color(0.55, 0.66, 0.98)
		env.background_color = Color(0.03, 0.035, 0.05)
		env.glow_enabled = true
		env.glow_intensity = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	stage.add_child(sun)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.33, 0.31, 0.27) if not night else Color(0.12, 0.12, 0.11)
	floor_mat.roughness = 0.95
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(300, 300)
	Res.mi(stage, floor_mesh, floor_mat, Vector3(0, -0.012, 0))
	var subject := _subject(kind)
	stage.add_child(subject)
	var bounds := _bounds(subject, Transform3D.IDENTITY)
	var center := bounds.get_center()
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var fit := bounds.size.length()
	camera.far = 2000
	camera.position = center + view_direction.normalized() * maxf(fit, 4.0) * 3.0
	camera.look_at(center)
	# Fit the subject's projected box, whichever way it is longer.
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var half := Vector2.ZERO
	for corner in 8:
		var p := bounds.get_endpoint(corner) - center
		half = Vector2(maxf(half.x, absf(p.dot(right))), maxf(half.y, absf(p.dot(up))))
	camera.size = maxf(maxf(half.y, half.x * float(size.y) / size.x) * 2.25, 1.2)
	if framing.has(kind):
		var m: Array = framing[kind]
		center = Vector3(float(m[0]), float(m[1]), float(m[2]))
		camera.size = float(m[3])
		camera.position = center + view_direction.normalized() * float(m[4])
		camera.look_at(center)
	cameras[kind] = [center.x, center.y, center.z, camera.size, camera.position.distance_to(center)]
	var label := Label.new()
	label.text = kind.replace("_", " ").to_upper()
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 24 if single else 16)
	cell.add_child(label)


## A building as the map lays it out: a house is a floor, a ring of wall
## sections (each its own structure, its dressed face outwards) and a roof.
func _subject(kind: String) -> Node3D:
	match kind:
		"house_pitched":
			return _house(9.0, 7.6, 1, false)
		"house_flat":
			return _house(8.4, 7.4, 3, true)
		"house_open":
			# the roof hidden, as when men are inside: the room as they see it
			return _house(9.0, 7.6, 1, false, false)
		"house_brick":
			return _house(9.0, 7.6, 2, false)
		"house_ruin":
			# a house that burned and fell in: no roof, the odd wall down
			return _house(9.0, 7.6, 4, false, false, true)
		"house_stone":
			return _house(8.6, 7.4, 4, true)
		"house_window":
			return _rotated(Structure.preview_model("house_wall", -1, 1, Vector3(3.0, 0.0, 0.4)))
		"house_door":
			return _rotated(Structure.preview_model("house_wall", -1, 2, Vector3(3.0, 2.0, 0.4), true))
		"barracks":
			return Structure.preview_model("barracks", 0)
		"factory":
			return Structure.preview_model("factory", 0)
		"research":
			return Structure.preview_model("research", 0)
		"medic_tent":
			return Structure.preview_model("medic_tent", 0)
		"bunker":
			return Structure.preview_model("bunker", 0)
		"bunker_rebel":
			return Structure.preview_model("bunker", 1)
		"fob":
			return Structure.preview_model("fob", 0, 0, Vector3(13.0, 3.0, 13.0))
		"town":
			return Structure.preview_model("town", -1, 0, Vector3(3.6, 2.0, 2.4))
		"watchtower":
			return Structure.preview_model("watchtower", 0)
		"low_wall_stone":
			return Structure.preview_model("low_wall", -1, 0, Vector3(4.0, 1.0, 0.5))
		"low_wall_brick":
			return Structure.preview_model("low_wall", -1, 2, Vector3(4.0, 1.0, 0.5))
		"tall_wall":
			return Structure.preview_model("tall_wall", -1, 0, Vector3(4.0, 2.6, 0.5))
		"bridge":
			return Structure.preview_model("bridge", -1, 0, Vector3(8.0, 1.0, 14.0))
		"dock":
			return Structure.preview_model("dock", 0, 0, Vector3(16.0, 3.0, 12.0))
	if ":" in kind:
		# any structure kind, for a side: "barricade:1", "ammo_cache:0"
		var spec := kind.split(":")
		return Structure.preview_model(spec[0], int(spec[1]), int(spec[2]) if spec.size() > 2 else 0)
	var holder := Node3D.new()
	var builder := "res://tools/showcase/building-components.gd"
	if components and ResourceLoader.exists(builder):
		load(builder).call("build", holder, kind)
	return _rotated(holder)


## House walls dress their local +z face; turn it towards the camera.
func _rotated(n: Node3D) -> Node3D:
	var holder := Node3D.new()
	n.rotation.y = PI
	holder.add_child(n)
	return holder


## The same layout as MapGen._house: the front (street) wall at -z with the
## door in it, windows in most other sections.
func _house(w: float, d: float, color: int, flat: bool, roofed := true, ruined := false) -> Node3D:
	var root := Node3D.new()
	var floor := Structure.preview_model("floor", -1, 1 if ruined else 0, Vector3(w, 0.06, d), false, 7)
	root.add_child(floor)
	var sides := [[Vector3(0, 0, -d * 0.5), w, 0.0], [Vector3(0, 0, d * 0.5), w, 0.0],
		[Vector3(-w * 0.5, 0, 0), d - 0.4, PI * 0.5], [Vector3(w * 0.5, 0, 0), d - 0.4, PI * 0.5]]
	for si in 4:
		var s: Array = sides[si]
		var L: float = s[1]
		var segs := maxi(1, int(round(L / 2.8)))
		var seg_len := L / segs
		for k in segs:
			var off := (k + 0.5) * seg_len - L * 0.5
			var lp: Vector3 = s[0] + (Vector3(off, 0, 0) if s[2] == 0.0 else Vector3(0, 0, off))
			var yaw: float = s[2] + (PI if si == 0 or si == 2 else 0.0)
			var variant := 0
			if si == 0 and k == segs / 2:
				variant = 2
			elif seg_len > 2.0 and (k + si) % 3 != 2:
				variant = 1
			if ruined and (si * 3 + k) % 4 == 1:
				var heap := Structure.preview_model("rubble", -1, 0, Vector3(seg_len * 0.9, 0, 1.2), false, 300 + si * 10 + k)
				heap.position = lp
				heap.rotation.y = yaw
				root.add_child(heap)
				continue
			var wall := Structure.preview_model("house_wall", -1, variant, Vector3(seg_len, float(color), 0.4), variant == 2, 100 + si * 10 + k)
			wall.position = lp
			wall.rotation.y = yaw
			root.add_child(wall)
	if roofed:
		var roof := Structure.preview_model("roof", -1, color * 2 + (1 if flat else 0), Vector3(w, 3.0, d))
		root.add_child(roof)
	return root


func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var xf := parent * node.transform
	var box := AABB()
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh and mi.visibility_range_begin == 0 and mi.visible:
			box = xf * mi.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var cb := _bounds(child, xf)
			if cb.size != Vector3.ZERO:
				box = cb if box.size == Vector3.ZERO else box.merge(cb)
	return box
