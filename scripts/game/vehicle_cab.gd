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
	for side: float in [-1.0, 1.0]:
		seat(k, m, Vector3(side * 0.60, 1.99, -3.49), Vector3(0.57, 0.58, 0.54), Vector3.ZERO, Color(0.18, 0.20, 0.13), "canvas", true)
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
	k._box(m, Vector3(widths.y * 2.0, 0.09, rear - front.y), Vector3(0, heights.y, (rear + front.y) * 0.5), mat, col)
	k._box(m, Vector3(width * 2.0, h, 0.10), Vector3(0, y, rear), mat, col)
	# The same surface defines the shell and its glass: the raked panes cannot
	# drift away from a separately positioned frame as cab proportions change.
	var front_corners := [Vector3(-widths.x, heights.x, front.x), Vector3(widths.x, heights.x, front.x), Vector3(widths.y, heights.y, front.y), Vector3(-widths.y, heights.y, front.y)]
	framed_face(k, m, front_corners, Vector3(0, y, rear), [Rect2(0.055, 0.10, 0.415, 0.79), Rect2(0.53, 0.10, 0.415, 0.79)], mat, col)
	for side: float in [-1.0, 1.0]:
		var corners := [Vector3(side * widths.x, heights.x, front.x), Vector3(side * widths.x, heights.x, rear), Vector3(side * widths.y, heights.y, rear), Vector3(side * widths.y, heights.y, front.y)]
		framed_face(k, m, corners, Vector3(0, y, z), [Rect2(0.055, 0.12, 0.53, 0.75), Rect2(0.65, 0.12, 0.29, 0.75)], mat, col)
	# Furniture is fitted into each cab's available space, then baked with it.
	var sc := Vector3(width / 1.17, h / 0.91, (rear - z) / 1.51)
	interior(k, Vector3(0, heights.x - 1.95 * sc.y, rear + 2.91 * sc.z), sc)


static func window(k: VehicleModels, size: Vector2, pos: Vector3, rot: Vector3) -> void:
	VehicleGlazing.rectangle(k, k.root, size, pos, rot, true)



static func _materials() -> void:
	if glass_near == null:
		glass_near = StandardMaterial3D.new()
		glass_near.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_near.albedo_color = Color(0.16, 0.20, 0.21, 0.27)
		glass_near.roughness = 0.045
		glass_near.metallic_specular = 0.5
		glass_near.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass_far = StandardMaterial3D.new()
		glass_far.albedo_color = Color(0.10, 0.14, 0.16)
		glass_far.roughness = 0.09
		glass_far.cull_mode = BaseMaterial3D.CULL_DISABLED


## Reusable hollow cabin face; openings are normalized rectangles on the quad.
static func framed_face(k: VehicleModels, parent: Node3D, corners: Array, inside: Vector3, openings: Array[Rect2], mat: String, col = null, depth := 0.065) -> void:
	var surface := VehicleSurface.quad(corners, inside)
	k._add(parent, surface.shell(Rect2(0, 0, 1, 1), openings, depth), mat, col, Vector3.ZERO)
	for hole in openings:
		var outline := PackedVector2Array([hole.position, Vector2(hole.end.x, hole.position.y), hole.end, Vector2(hole.position.x, hole.end.y)])
		VehicleGlazing.polygon(k, parent, surface, outline, true, null, 0.012)


## Seat origin is the cushion centre; dimensions are width, back height, depth.
## The local front is -Z. Padding, seams and support share construction, while
## low marine jockey backs and full-height crew seats retain their proportions.
static func seat(k: VehicleModels, parent: Node3D, center: Vector3, size := Vector3(0.46, 0.5, 0.46), rotation := Vector3.ZERO, col := Color(0.20, 0.21, 0.17), material := "canvas", headrest := false) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var pad := minf(0.12, size.z * 0.24)
	k._add(mount, BevelMesh.make(Vector3(size.x, pad, size.z), minf(0.035, pad * 0.3)), material, col, Vector3.ZERO)
	var back := Vector3(0, size.y * 0.5, size.z * 0.46)
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.94, size.y, pad * 0.8), pad * 0.22), material, col.darkened(0.06), back, Vector3(-0.12, 0, 0))
	# Rolled cushion piping and the two stitched back panels catch side light.
	var seam_col := col.darkened(0.26)
	for side: float in [-1.0, 1.0]:
		VehicleFrames.tube(k, mount, Vector3(side * size.x * 0.43, pad * 0.48, -size.z * 0.4), Vector3(side * size.x * 0.43, pad * 0.48, size.z * 0.34), 0.004, material, seam_col, 5, false)
		VehicleFrames.tube(k, mount, Vector3(side * size.x * 0.30, size.y * 0.13, size.z * 0.46 - pad * 0.42), Vector3(side * size.x * 0.30, size.y * 0.85, size.z * 0.46 - pad * 0.42 - size.y * 0.086), 0.0035, material, seam_col, 5, false)
		VehicleFrames.beam(k, mount, Vector3(side * size.x * 0.32, -pad * 0.7, -size.z * 0.3), Vector3(side * size.x * 0.32, -pad * 0.7, size.z * 0.38), 0.025, 0.035, "metal_dark")
	if headrest:
		for side: float in [-1.0, 1.0]:
			VehicleFrames.tube(k, mount, back + Vector3(side * size.x * 0.2, size.y * 0.46, -0.04), back + Vector3(side * size.x * 0.2, size.y * 0.63, -0.04), 0.012, "steel", null, 6, false)
		k._box(mount, Vector3(size.x * 0.58, size.y * 0.25, pad), back + Vector3(0, size.y * 0.66, -0.04), material, col)
	for side: float in [-1.0, 1.0]:
		k._add(mount, BevelMesh.make(Vector3(size.x * 0.11, pad * 0.62, size.z * 0.75), pad * 0.15), material, col, Vector3(side * size.x * 0.43, pad * 0.35, 0))
	k._add(mount, BevelMesh.make(Vector3(size.x * 0.78, size.y * 0.82, pad * 0.22), pad * 0.07), "plain_dark", Color(0.12, 0.13, 0.12), back + Vector3(0, 0, pad * 0.5), Vector3(-0.12, 0, 0))
	k._fold(mount)
