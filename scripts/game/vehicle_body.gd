class_name VehicleBody
extends RefCounted
## Shared body skins and service fittings. Family builders still own outlines.
static var _skins := {}

## Smooth neighbouring faces of a curved skin, retaining sharp creases and caps.
## Positions are unchanged, so fitted windows and authored panels still meet it.
static func skin(mesh: ArrayMesh, key: String, crease := 55.0) -> ArrayMesh:
	if _skins.has(key):
		return _skins[key]
	var arrays := Mats._arrays(mesh, 0).duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var groups := {}
	for i in vertices.size():
		var point := Vector3i((vertices[i] * 100000.0).round())
		if not groups.has(point):
			groups[point] = []
		(groups[point] as Array).append(i)
	var softened := normals.duplicate()
	var threshold := cos(deg_to_rad(crease))
	for indices: Array in groups.values():
		for i: int in indices:
			var total := Vector3.ZERO
			for j: int in indices:
				if normals[i].dot(normals[j]) >= threshold:
					total += normals[j]
			softened[i] = total.normalized() if not total.is_zero_approx() else normals[i]
	arrays[Mesh.ARRAY_NORMAL] = softened
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(result, arrays)
	_skins[key] = result
	return result


static func seam(k: VehicleModels, parent: Node3D, points: Array, radius := 0.006) -> void:
	for i in points.size() - 1:
		VehicleFrames.tube(k, parent, points[i], points[i + 1], radius, "paint", Color(0.10, 0.11, 0.10), 5, false)


static func fastener(k: VehicleModels, parent: Node3D, position: Vector3, normal: Vector3, radius := 0.012) -> void:
	k._cyl(parent, radius, radius, 0.006, position, VehicleFrames.aim(normal).get_euler(), "steel", Color(0.28, 0.29, 0.27), 8, false)


## Local XY panel, +Z outward. Gasket, pressed sheet, flush screws and optional
## louvres share construction; callers choose the actual panel location.
static func panel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, mat: String, col = null, louvres := false) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, Vector3(size.x, size.y, 0.008), Vector3.ZERO, "rubber", null, Vector3.ZERO, false)
	k._box(mount, Vector3(size.x - 0.024, size.y - 0.024, 0.018), Vector3(0, 0, 0.009), mat, col)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			fastener(k, mount, Vector3(x * (size.x * 0.5 - 0.045), y * (size.y * 0.5 - 0.045), 0.022), Vector3.BACK)
	if louvres:
		for i in 4:
			var y := (i - 1.5) * size.y * 0.16
			k._box(mount, Vector3(size.x * 0.68, size.y * 0.055, 0.012), Vector3(0, y, 0.022), "rubber", null, Vector3.ZERO, false)
			k._box(mount, Vector3(size.x * 0.71, size.y * 0.045, 0.025), Vector3(0, y + size.y * 0.025, 0.032), mat, col, Vector3(-0.25, 0, 0))
	else:
		k._box(mount, Vector3(size.x * 0.72, size.y * 0.50, 0.012), Vector3(0, 0, 0.02), mat, col)
	k._fold(mount)
