class_name VehicleGlazing
extends RefCounted
## Pane outlines and seals are shared. Clear glazing is opt-in: a solid hull
## still needs opaque glazing until its builder provides an actual opening.

static func rectangle(k: VehicleModels, parent: Node3D, size: Vector2, pos: Vector3, rot: Vector3, clear := false, col = null, thickness := 0.02) -> Variant:
	var basis := Basis.from_euler(rot)
	var border := minf(0.025, minf(size.x, size.y) * 0.08)
	for side in [-1.0, 1.0]:
		k._box(parent, Vector3(border, size.y + border, thickness + 0.015), pos + basis * Vector3(side * size.x * 0.5, 0, 0), "rubber", null, rot, false)
		k._box(parent, Vector3(size.x, border, thickness + 0.015), pos + basis * Vector3(0, side * size.y * 0.5, 0), "rubber", null, rot, false)
	if clear:
		var mesh := QuadMesh.new()
		mesh.size = size
		VehicleCab.mesh_glass(k, parent, mesh, pos, rot)
		return null
	return k._box(parent, Vector3(size.x, size.y, thickness), pos, "glass", col, rot, false)


static func quad(k: VehicleModels, parent: Node3D, key: String, corners: Array, inside: Vector3, region: Rect2, lift: float, thickness: float, mat: String, col = null, clear := false) -> Variant:
	var c0: Vector3 = corners[0]
	var c1: Vector3 = corners[1]
	var c2: Vector3 = corners[2]
	var c3: Vector3 = corners[3]
	var normal := (c1 - c0).cross(c3 - c0).normalized()
	if normal.dot(c0 - inside) < 0:
		normal = -normal
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	for uv in [region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)]:
		var q := c0.lerp(c1, uv.x).lerp(c3.lerp(c2, uv.x), uv.y)
		inner.append(q + normal * lift)
		outer.append(q + normal * (lift + thickness))
	if mat == "glass":
		var seal := minf(0.013, minf(outer[0].distance_to(outer[1]), outer[0].distance_to(outer[3])) * 0.06)
		for i in 4:
			VehicleFrames.tube(k, parent, outer[i], outer[(i + 1) % 4], seal, "rubber", null, 6, false)
	var mesh := VehicleModels.solid([inner, outer], key)
	if clear:
		VehicleCab.mesh_glass(k, parent, mesh)
		return null
	return k._add(parent, mesh, mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, mat != "glass")
