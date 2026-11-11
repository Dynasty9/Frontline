class_name VehicleFrames
extends RefCounted
## Structural members in the supplied parent's coordinates, baked like other
## opaque parts. Family builders own their layout; these helpers own the joins.

static func aim(direction: Vector3) -> Basis:
	var y := direction.normalized()
	if y.is_zero_approx():
		return Basis.IDENTITY
	return Basis(Quaternion(Vector3.RIGHT, PI)) if y.dot(Vector3.UP) < -0.9999 else Basis(Quaternion(Vector3.UP, y))


static func tube(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: String, col = null, segments := 8, shadow := true, end_radius := -1.0) -> Variant:
	if a.distance_squared_to(b) < 0.00000001:
		return null
	return k._cyl(parent, end_radius if end_radius >= 0 else radius, radius, a.distance_to(b), (a + b) * 0.5, aim(b - a).get_euler(), mat, col, segments, shadow)


static func beam(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float, mat: String, col = null, shadow := true, level := false) -> Variant:
	if a.distance_squared_to(b) < 0.00000001:
		return null
	var basis := aim(b - a)
	if level:
		var y := (b - a).normalized()
		var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var z := ref.cross(y).normalized()
		basis = Basis(y.cross(z), y, z)
	return k._box(parent, Vector3(width, a.distance_to(b), depth), (a + b) * 0.5, mat, col, basis.get_euler(), shadow)


static func path(k: VehicleModels, parent: Node3D, points: Array, radius: float, mat: String, col = null, segments := 8) -> void:
	for i in points.size() - 1:
		tube(k, parent, points[i], points[i + 1], radius, mat, col, segments)
		if i > 0:
			k._add(parent, Res.sphere(radius, segments), mat, col, points[i])
