class_name VehicleGlazing
extends RefCounted
## Pane outlines and seals are shared. Clear glazing is opt-in: a solid hull
## still needs opaque glazing until its builder provides an actual opening.

static var _frames := {}
static var _panes := {}

## The rubber seal round the pane is one moulded frame, chamfered front and
## back along its edges as its four separate strips were. The pane's own
## edges sit inside it, so an opaque pane is just its two faces.
static func rectangle(k: VehicleModels, parent: Node3D, size: Vector2, pos: Vector3, rot: Vector3, clear := false, col = null, thickness := 0.02) -> Variant:
	var border := minf(0.025, minf(size.x, size.y) * 0.08)
	k._add(parent, _frame(size, border, thickness + 0.015), "rubber", null, pos, rot, Vector3.ONE, false)
	if clear:
		VehicleCab.mesh_glass(k, parent, _pane(size, 0.0), pos, rot)
		return null
	return k._add(parent, _pane(size, thickness), "glass", col, pos, rot, Vector3.ONE, false)


## How far a pane's shading normals lean out toward its edges (the tangent of
## the lean at its farthest corner): glass is pressed to a gentle curve, so
## from above the sky slides down a window from a bright edge to a dark one
## instead of lying on it as one flat tone, which read as a painted panel.
const CROWN := 0.3


## A rectangular seal frame in local XY, `depth` through along Z: outside
## size + border, its opening size - border. Each face's outer and inner edges
## are chamfered as Res.box chamfers a strip that size. Cached by size.
static func _frame(size: Vector2, border: float, depth: float) -> ArrayMesh:
	var key := "%.4f,%.4f,%.4f,%.4f" % [size.x, size.y, border, depth]
	if _frames.has(key):
		return _frames[key]
	var outer := (size + Vector2(border, border)) * 0.5
	var inner := (size - Vector2(border, border)) * 0.5
	var chamfer := 0.0 if minf(border, depth) < 0.012 else clampf(minf(border, depth) * 0.16, 0.0025, 0.035)
	chamfer = minf(chamfer, border * 0.3)
	var hz := depth * 0.5
	var c := Vector2(chamfer, chamfer)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var q0: Vector2 = corners[i]
		var q1: Vector2 = corners[(i + 1) % 4]
		# this side's outward direction in the frame's plane
		var out3 := Vector3((q0 + q1).x * 0.5, (q0 + q1).y * 0.5, 0)
		for z: float in [-1.0, 1.0]:
			var face := Vector3(0, 0, z)
			var o0 := _at(q0 * (outer - c), hz * z)
			var o1 := _at(q1 * (outer - c), hz * z)
			var i0 := _at(q0 * (inner + c), hz * z)
			var i1 := _at(q1 * (inner + c), hz * z)
			_quad(vs, ns, o0, o1, i1, i0, face)
			if chamfer > 0.0:
				var oe0 := _at(q0 * outer, (hz - chamfer) * z)
				var oe1 := _at(q1 * outer, (hz - chamfer) * z)
				var ie0 := _at(q0 * inner, (hz - chamfer) * z)
				var ie1 := _at(q1 * inner, (hz - chamfer) * z)
				_quad(vs, ns, oe0, oe1, o1, o0, (out3 + face).normalized())
				_quad(vs, ns, i0, i1, ie1, ie0, (face - out3).normalized())
		var hz0 := hz - chamfer
		_quad(vs, ns, _at(q0 * outer, -hz0), _at(q1 * outer, -hz0), _at(q1 * outer, hz0), _at(q0 * outer, hz0), out3)
		_quad(vs, ns, _at(q0 * inner, -hz0), _at(q1 * inner, -hz0), _at(q1 * inner, hz0), _at(q0 * inner, hz0), -out3)
	var mesh := _flat(vs, ns)
	_frames[key] = mesh
	return mesh


## An opaque pane's front and back faces (its edges are inside the frame),
## crowned (CROWN); zero thickness is a clear pane's single sheet, facing +Z
## as a QuadMesh does.
static func _pane(size: Vector2, thickness: float) -> ArrayMesh:
	var key := "%.4f,%.4f,%.4f" % [size.x, size.y, thickness]
	if _panes.has(key):
		return _panes[key]
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var h := size * 0.5
	for z: float in ([1.0] if thickness <= 0.0 else [-1.0, 1.0]):
		var t := thickness * 0.5 * z
		var c := [Vector3(-h.x, -h.y, t), Vector3(h.x, -h.y, t), Vector3(h.x, h.y, t), Vector3(-h.x, h.y, t)]
		var n := []
		for q: Vector3 in c:
			n.append((Vector3(0, 0, z) + Vector3(q.x, q.y, 0) / h.length() * CROWN).normalized())
		var face := Vector3(0, 0, z)
		VehicleProfiles._tri(vs, ns, c[0], c[1], c[2], n[0], n[1], n[2], face)
		VehicleProfiles._tri(vs, ns, c[0], c[2], c[3], n[0], n[2], n[3], face)
	var mesh := _flat(vs, ns)
	_panes[key] = mesh
	return mesh


## The fitted pane `mesh` (a VehicleSurface patch) with its faces crowned as
## _pane's are: each face vertex's normal leans out from the pane's middle in
## proportion to its distance from it. The edge strips keep theirs.
static func _crowned(mesh: ArrayMesh) -> ArrayMesh:
	var src: Array = mesh.get_meta(&"src") if mesh.has_meta(&"src") else mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = (src[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	if vs.is_empty():
		return mesh
	var facing := ns[0]
	var middle := Vector3.ZERO
	var count := 0
	for i in vs.size():
		if absf(ns[i].dot(facing)) > 0.9:
			middle += vs[i]
			count += 1
	middle /= maxf(1.0, count)
	var reach := 0.0
	for i in vs.size():
		if absf(ns[i].dot(facing)) > 0.9:
			var d := vs[i] - middle
			reach = maxf(reach, (d - ns[i] * d.dot(ns[i])).length())
	if reach < 0.001:
		return mesh
	for i in vs.size():
		if absf(ns[i].dot(facing)) > 0.9:
			var d := vs[i] - middle
			ns[i] = (ns[i] + (d - ns[i] * d.dot(ns[i])) / reach * CROWN).normalized()
	var arrays := src.duplicate()
	arrays[Mesh.ARRAY_NORMAL] = ns
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(result, arrays)
	return result


static func _at(q: Vector2, z: float) -> Vector3:
	return Vector3(q.x, q.y, z)


static func _quad(vs: PackedVector3Array, ns: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	VehicleProfiles._tri(vs, ns, a, b, c, normal, normal, normal, normal)
	VehicleProfiles._tri(vs, ns, a, c, d, normal, normal, normal, normal)


static func _flat(vs: PackedVector3Array, ns: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	return mesh


static func quad(k: VehicleModels, parent: Node3D, _key: String, corners: Array, inside: Vector3, region: Rect2, lift: float, thickness: float, mat: String, col = null, clear := false) -> Variant:
	var surface := VehicleSurface.quad(corners, inside)
	var outline := PackedVector2Array([region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)])
	if mat == "glass":
		return polygon(k, parent, surface, outline, clear, col, thickness, 0, lift)
	return k._add(parent, surface.patch(outline, lift + thickness, thickness), mat, col, Vector3.ZERO)


## Arbitrary fitted pane: the seal and retaining lip follow its actual outline.
## Clear is still opt-in, and uses the existing wreck/near/far glass contract.
static func polygon(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, clear := false, col = null, thickness := 0.02, divisions := 0, lift := 0.0, authored_mesh: Mesh = null) -> Variant:
	var shortest := INF
	for i in outline.size():
		shortest = minf(shortest, surface.point(outline[i]).distance_to(surface.point(outline[(i + 1) % outline.size()])))
	var seal := minf(0.014, shortest * 0.045)
	VehicleBody.boundary(k, parent, surface, outline, lift + thickness, seal, false, divisions)
	# The thin painted retaining bead gives the rubber a distinct attachment.
	# Where its inner half lies inside an opaque pane's edge (as it does at the
	# usual 2 cm thickness and full 14 mm seal), only its outer faces are built.
	var bead := seal * 0.42
	var faces := VehicleBody.SEAL_ALL
	var middle := lift + thickness - seal
	if not clear and middle + bead <= lift + thickness * 0.6 + 0.0002 and middle - bead >= lift - 0.0002:
		faces = VehicleBody.SEAL_UPPER_OUT | VehicleBody.SEAL_LOWER_OUT
	VehicleBody._seal(k, parent, surface, outline, middle, bead, divisions, "metal_dark", null, faces)
	var mesh: Mesh = authored_mesh if authored_mesh != null else _crowned(surface.patch(outline, lift + thickness * 0.6, 0.0 if clear else thickness * 0.6, divisions))
	if clear:
		VehicleCab.mesh_glass(k, parent, mesh)
		return null
	return k._add(parent, mesh, "glass", col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
