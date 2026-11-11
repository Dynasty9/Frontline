extends World
## A camera car makes one lap. Vehicle swaps inherit its position, heading and lens.
const Studio := preload("res://tools/showcase/vehicle-surfaces.gd")
const RADIUS := 42.0
const FPS := 30.0
const ORIGIN := Vector3(120, WaterMap.LEVEL, 0)
const HOLD := 4
const BEACH_RUN := 20
const WARMUP := 16
var groups := [[], [], [], []]
var group_ends := PackedInt32Array()
var frames := 0
var lip := 0
var rig := Node3D.new()
var lens := Camera3D.new()
var caption := Label.new()
var scale_factor := 1.0

func _ready() -> void:
	TestRun.watch()
	settings = {"seed": 3, "mood": "day"}
	super._ready()
	set_physics_process(false)
	set_process(false)
	Music.play_cue("")
	water.coast = {"x": -24.0, "s": 3.0}
	water.paint_kinds()
	water.carve()
	_plan()
	_chart_shallows()
	_water_view()
	atmo.sun.rotation.x = deg_to_rad(-39)
	_headland()
	add_child(rig)
	add_child(lens)
	lens.current = true
	lens.fov = 37
	lens.far = 3000
	add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.offset_left = 48
	caption.offset_top = -95
	caption.add_theme_font_size_override("font_size", 37)
	caption.add_theme_constant_override("outline_size", 5)
	var cursor := 0
	for group in groups.size():
		for shot: Dictionary in groups[group]:
			var model := VehicleModels.build(shot.key, maxi(0, int(shot.get("team", 0))), 3)
			rig.add_child(model.root)
			var box := Studio._bounds(model.root, Transform3D.IDENTITY)
			var length_in_shot := 5.6 if group == 0 or shot.key == "hatchback" else 6.2
			scale_factor = length_in_shot / maxf(maxf(box.size.z, box.size.x), 0.5)
			model.root.scale *= scale_factor
			model.root.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale_factor
			if group == 3 and shot.key != "hatchback":
				model.root.position.y -= minf(0.52, box.size.y * scale_factor * 0.28)
			caption.text = shot.name
			print("CIRCUIT ", cursor, " ", shot.key)
			if cursor == 0:
				_pose(0, model, group)
				for tick in WARMUP:
					await RenderingServer.frame_post_draw
			for i in int(shot.hold):
				_pose(cursor, model, group)
				await RenderingServer.frame_post_draw
				cursor += 1
			if cursor == frames:
				# Movie Maker draws once more during quit. Carry the opening pose across that frame.
				_pose(0, model, 0)
				TestRun.quit(get_tree())
				return
			model.root.free()

func _plan() -> void:
	var models := Defs.VEHICLES.duplicate(true)
	for item in VehicleRoster.garage():
		models[item[0]] = {"name": item[1], "team": int(String(item[3]).begins_with("CSAT")), "cat": item[2]}
	for support: Dictionary in Defs.SUPPORT.values():
		var key := String(support.get("model", ""))
		if key != "" and not models.has(key):
			models[key] = {"name": String(support.name).trim_suffix(" Gun Run"), "team": support.team, "cat": "aircraft"}
	for key: String in models:
		var spec: Dictionary = models[key]
		var cat := String(spec.get("cat", ""))
		var group := 0
		if cat in ["boats", "naval"] or spec.get("base", "") == "boat":
			group = 3
		elif key in ["utility_drone", "demining_drone", "blackfish", "blackfish_armed", "xian"]:
			group = 1
		elif cat == "aircraft" or key in ["fenghuang_uav", "greyhawk_uav"]:
			group = 2
		elif spec.get("air", false):
			group = 1
		spec.key = key
		spec.hold = HOLD
		groups[group].append(spec)
	for pair in [[0, "hatchback", true, 11], [0, "prowler", false, 19], [1, "hummingbird", true, 10], [2, "blackwasp", false, 24], [3, "rhib", true, 13], [3, "water_scooter", false, 12]]:
		var shots: Array = groups[pair[0]]
		var shot: Dictionary = models[pair[1]]
		shots.erase(shot)
		shot.hold = pair[3]
		shots.insert(0 if pair[2] else shots.size(), shot)
	var landing: Dictionary = models.hatchback.duplicate()
	landing.hold = BEACH_RUN
	groups[3].append(landing)
	for shots: Array in groups:
		for shot: Dictionary in shots:
			frames += int(shot.hold)
		group_ends.append(frames)
	lip = group_ends[0] - 9
	print("CIRCUIT frames=", frames, " boundaries=", group_ends)

## The road follows the rim of a rocky headland. Its far end breaks off above the sea.
func _height(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	var f := fposmod(atan2(x, z), TAU) * frames / TAU
	var road := 0.7 + 8.7 * smoothstep(0, lip - 5, f)
	road = lerpf(road, -4.5, smoothstep(lip - 1, lip + 7, f))
	road = lerpf(road, 0.7, smoothstep(frames - BEACH_RUN - 21, frames - BEACH_RUN + 5, f))
	var inland := smoothstep(3.8, 23, RADIUS - radius)
	var offshore := smoothstep(3.6, 12, radius - RADIUS)
	var folds := 1.4 * sin(0.29 * x) * cos(0.21 * z) + 0.7 * sin(0.53 * z + 0.34 * x)
	var ridge := 7.3 + 3.5 * sin(0.11 * x + 0.08 * z) + folds
	return lerpf(lerpf(road, ridge, inland), -5.0, offshore)

## Wakes and shoal colour sample the same depth mask as the game's coastline.
func _chart_shallows() -> void:
	var center := Vector2i(int(ORIGIN.x + MapDims.HALF), int(ORIGIN.z + MapDims.HALF))
	for z in range(-59, 60):
		for x in range(-59, 60):
			var h := _height(x, z)
			var depth := clampf(-h / 3.0, 0, 1)
			water.mask.set_pixelv(center + Vector2i(x, z), Color(depth, 1 - smoothstep(0, 2, h), 1, 1 if h < 0 else 0))

func _headland() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(118, 118)
	plane.subdivide_width = 196
	plane.subdivide_depth = 196
	var arrays := plane.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var p := verts[i]
		p.y = _height(p.x, p.z)
		verts[i] = p
		normals[i] = Vector3(_height(p.x - 0.3, p.z) - _height(p.x + 0.3, p.z), 0.6, _height(p.x, p.z - 0.3) - _height(p.x, p.z + 0.3)).normalized()
		var edge := absf(Vector2(p.x, p.z).length() - RADIUS)
		colors[i] = Color(1 - smoothstep(2.2, 3.5, edge), smoothstep(0.63, 0.91, normals[i].y), 0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var surface := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.mesh = mesh
	surface.material_override = preload("res://tools/showcase/coastal-ground.tres")
	add_child(surface)
	surface.position = ORIGIN
	for i in 64:
		var a := i * 2.39996
		var r := 11 + fmod(i * 7.73, 24.7)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		p.y = _height(p.x, p.z)
		if p.y < 1.2:
			continue
		var tree := Node3D.new()
		add_child(tree)
		tree.position = ORIGIN + p
		tree.rotation.y = a
		tree.scale *= 0.63 + 0.24 * sin(a)
		Structure.tree_model(tree, i + 27, 2)

func _altitude(f: float) -> float:
	var a := TAU * f / frames
	if f <= lip:
		return _height(RADIUS * sin(a), RADIUS * cos(a))
	if f < group_ends[0]:
		return 9.4 - 0.7 * pow((f - lip) / (group_ends[0] - lip), 2)
	if f < group_ends[2] - 28:
		return 8.7 + 3.4 * smoothstep(group_ends[0], group_ends[1], f)
	if f < group_ends[2]:
		# Ease into the descent, then keep the nose down through the splash.
		var t := (f - group_ends[2] + 28) / 28.0
		var descent := t * t / 0.6 if t < 0.3 else t - 0.15
		return lerpf(12.1, -2.1, descent / 0.85)
	return maxf(0.0, _height(RADIUS * sin(a), RADIUS * cos(a)))

func _pose(f: int, model: VehicleModels, group: int) -> void:
	var a := TAU * f / frames
	var radial := Vector3(sin(a), 0, cos(a))
	var forward := Vector3(cos(a), 0, -sin(a))
	var step := TAU * RADIUS / frames
	var p := ORIGIN + radial * RADIUS
	p.y += _altitude(f)
	var afloat := group == 3 and f < frames - BEACH_RUN
	if afloat:
		p.y += atmo.water_view.height_at(p) * (1 - smoothstep(frames - BEACH_RUN - 15, frames - BEACH_RUN, f))
	var slope := (_altitude(f + 0.5) - _altitude(f - 0.5)) / step if f > 0 and f != group_ends[2] else 0.0
	rig.position = p
	rig.rotation = Vector3(0, a - PI / 2, 0)
	rig.rotate_object_local(Vector3.RIGHT, clampf(atan(slope), -0.94, 0.34))
	if group in [1, 2]:
		rig.rotate_object_local(Vector3.BACK, -0.19 * sin(PI * clampf(float(f - group_ends[0]) / (group_ends[2] - group_ends[0]), 0, 1)))
	elif afloat:
		rig.rotate_object_local(Vector3.BACK, 0.045 * sin(a * 18))
	if group == 0 or f >= frames - BEACH_RUN:
		for wheel: Node3D in model.wheels:
			wheel.rotate_x(-step / (0.42 * scale_factor))
		for belt in model.belts:
			belt.advance(step / scale_factor, _contact)
	if model.rotor:
		model.rotor.rotation.y = f * 0.97
	if model.tail_rotor:
		model.tail_rotor.rotation.x = f * 2.37
	for i in model.rotors.size():
		model.rotors[i].rotation.y = f * (0.97 if i % 2 == 0 else -0.97)
	if f == group_ends[2] - 8:
		fx.vfx.splash(Vector3(p.x, WaterMap.LEVEL, p.z) + forward * 2.1, 0.92)
	if afloat:
		atmo.water_view.wake(1, p - forward * 1.9, p + forward * 1.9, 0.7, step * FPS, 0.88, true)
	var target := p + Vector3.UP * 1.04
	# The operator eases into the dive and keeps the lens above the spray.
	target.y = maxf(target.y, WaterMap.LEVEL + 1.04)
	var pullback := smoothstep(group_ends[2] - 43, group_ends[2] - 20, f) * (1 - smoothstep(group_ends[2], group_ends[2] + 17, f))
	lens.position = target + radial * (8.2 + 0.5 * cos(a) + 3.6 * pullback) + forward * (4.5 + 1.1 * sin(a)) + Vector3.UP * (2.65 + 0.8 * sin(a) + pullback)
	lens.look_at(target + forward * 0.24)

func _contact(p: Vector3) -> float:
	return ORIGIN.y + _height(p.x - ORIGIN.x, p.z - ORIGIN.z)
