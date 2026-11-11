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
	VehicleBody.boundary(k, parent, surface, outline, lift + thickness - seal, seal * 0.42, false, divisions, "metal_dark")
	var mesh: Mesh = authored_mesh if authored_mesh != null else surface.patch(outline, lift + thickness * 0.6, 0.0 if clear else thickness * 0.6, divisions)
	if clear:
		VehicleCab.mesh_glass(k, parent, mesh)
		return null
	return k._add(parent, mesh, "glass", col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
