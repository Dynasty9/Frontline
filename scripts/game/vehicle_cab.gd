class_name VehicleCab
extends RefCounted
## Open truck cabs share glazing and furniture, with family-specific proportions.

static var glass_near: StandardMaterial3D
static var glass_far: StandardMaterial3D

## Separate transparent panes are intentionally outside the opaque material bake.
## A cheap opaque pane takes over at the same distance as the chassis LOD.
static func glass(k: VehicleModels, size: Vector2, pos: Vector3, rot: Vector3) -> void:
	if k.burnt:
		return
	_materials()
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh_glass(k, k.root, mesh, pos, rot)


static func mesh_glass(k: VehicleModels, parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	if k.burnt:
		return
	_materials()
	var pane := Res.mi(parent, mesh, glass_near, pos, rot, false)
	pane.name = "CabGlass"
	pane.visibility_range_end = 100.0
	var distant := Res.mi(parent, mesh, glass_far, pos, rot, false)
	distant.name = "CabGlassDistant"
	distant.visibility_range_begin = 100.0

static func interior(k: VehicleModels, origin := Vector3.ZERO, scale := Vector3.ONE) -> void:
	var m := k._pivot(k.root, origin)
	m.scale = scale
	k._box(m, Vector3(2.10, 0.17, 0.34), Vector3(0, 2.03, -4.17), "plain_dark", Color(0.10, 0.12, 0.10))
	for side in [-1.0, 1.0]:
		k._box(m, Vector3(0.57, 0.13, 0.54), Vector3(side * 0.60, 1.99, -3.49), "canvas", Color(0.18, 0.20, 0.13))
		k._box(m, Vector3(0.55, 0.58, 0.12), Vector3(side * 0.60, 2.24, -3.19), "canvas", Color(0.16, 0.18, 0.12), Vector3(-0.10, 0, 0))
		k._box(m, Vector3(0.32, 0.20, 0.13), Vector3(side * 0.60, 2.61, -3.19), "canvas", Color(0.16, 0.18, 0.12))
	# Steering wheel, spokes, column and an instrument binnacle.
	var rim := TorusMesh.new()
	rim.inner_radius = 0.16
	rim.outer_radius = 0.18
	rim.rings = 32
	rim.ring_segments = 8
	k._add(m, rim, "rubber", null, Vector3(-0.60, 2.26, -3.97), Vector3(0.65, 0, 0))
	VehicleFrames.tube(k, m, Vector3(-0.60, 1.97, -4.14), Vector3(-0.60, 2.26, -3.97), 0.035, "gunmetal_w")
	k._box(m, Vector3(0.45, 0.13, 0.10), Vector3(-0.60, 2.17, -4.15), "rubber")
	for x in [-0.73, -0.59, -0.47]:
		k._cyl(m, 0.04, 0.04, 0.012, Vector3(x, 2.18, -4.09), Vector3(PI / 2, 0, 0), "glass", Color(0.30, 0.32, 0.24), 12, false)
	k._fold(m)


## A hollow glasshouse on a separately modelled lower cab. Frame members follow
## the windshield rake and inward lean; no solid panel sits behind a window.
static func upper(k: VehicleModels, widths: Vector2, heights: Vector2, front: Vector2, rear: float, mat: String, col = null) -> void:
	var m := k.root
	var h := heights.y - heights.x
	var y := (heights.x + heights.y) * 0.5
	var z := (front.x + front.y) * 0.5
	var width := (widths.x + widths.y) * 0.5
	var rake := atan2(front.y - front.x, h)
	var lean := atan2(widths.x - widths.y, h)
	k._box(m, Vector3(widths.y * 2.0, 0.09, rear - front.y), Vector3(0, heights.y, (rear + front.y) * 0.5), mat, col)
	k._box(m, Vector3(width * 2.0, h, 0.10), Vector3(0, y, rear), mat, col)
	for t in [0.04, 0.96]:
		k._box(m, Vector3(width * 2.0, 0.10, 0.10), Vector3(0, lerpf(heights.x, heights.y, t), lerpf(front.x, front.y, t)), mat, col, Vector3(rake, 0, 0))
	for side in [-1.0, 1.0]:
		for x in [0.0, side * (width - 0.06)]:
			if side > 0 and x == 0.0:
				continue
			k._box(m, Vector3(0.10, h, 0.10), Vector3(x, y, z), mat, col, Vector3(rake, 0, 0))
		window(k, Vector2(width - 0.16, h * 0.78), Vector3(side * width * 0.5, y, z - 0.025), Vector3(rake, PI, 0))
		var length := rear - z
		for t in [0.0, 0.62, 1.0]:
			k._box(m, Vector3(0.10, h, 0.10), Vector3(side * width, y, z + length * t), mat, col, Vector3(0, 0, side * lean))
		for yy in [heights.x + 0.04, heights.y - 0.05]:
			var xx := lerpf(widths.x, widths.y, (yy - heights.x) / h)
			k._box(m, Vector3(0.10, 0.10, length), Vector3(side * xx, yy, z + length * 0.5), mat, col)
		window(k, Vector2(length * 0.62 - 0.12, h * 0.76), Vector3(side * (width + 0.015), y, z + length * 0.31), Vector3(0, side * PI / 2, side * lean))
		window(k, Vector2(length * 0.38 - 0.12, h * 0.76), Vector3(side * (width + 0.015), y, z + length * 0.81), Vector3(0, side * PI / 2, side * lean))
	# Furniture is fitted into each cab's available space, then baked with it.
	var sc := Vector3(width / 1.17, h / 0.91, (rear - z) / 1.51)
	interior(k, Vector3(0, heights.x - 1.95 * sc.y, rear + 2.91 * sc.z), sc)


static func window(k: VehicleModels, size: Vector2, pos: Vector3, rot: Vector3) -> void:
	VehicleGlazing.rectangle(k, k.root, size, pos, rot, true)



static func _materials() -> void:
	if glass_near == null:
		glass_near = StandardMaterial3D.new()
		glass_near.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_near.albedo_color = Color(0.18, 0.24, 0.23, 0.36)
		glass_near.roughness = 0.08
		glass_near.metallic_specular = 0.5
		glass_near.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass_far = StandardMaterial3D.new()
		glass_far.albedo_color = Color(0.09, 0.14, 0.15)
		glass_far.roughness = 0.14
		glass_far.cull_mode = BaseMaterial3D.CULL_DISABLED
