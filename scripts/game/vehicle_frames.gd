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


## A boarding tread with a rolled front lip and sparse grip ribs.
static func step(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO, mat := "metal_dark", col = null) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, Vector3(size.x, 0.035, size.y), Vector3.ZERO, mat, col)
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x, 0.035, 0.018), Vector3(0, -0.008, side * (size.y * 0.5 - 0.009)), mat, col)
	var ribs := clampi(ceili(size.y / 0.06), 2, 8)
	for i in ribs:
		k._box(mount, Vector3(size.x * 0.9, 0.006, 0.009), Vector3(0, 0.020, lerpf(-size.y * 0.38, size.y * 0.38, float(i) / (ribs - 1))), "steel", Color(0.22, 0.23, 0.21), Vector3.ZERO, false)
	k._fold(mount)

static func ladder(k: VehicleModels, parent: Node3D, bottom: Vector3, width: float, pitch: float, count: int, depth := 0.24, rotation := Vector3.ZERO, mat := "metal_dark", col = null) -> void:
	var mount := k._pivot(parent, bottom)
	mount.rotation = rotation
	for i in count:
		step(k, mount, Vector3(0, i * pitch, 0), Vector2(width, depth), Vector3.ZERO, mat, col)
	for side: float in [-1.0, 1.0]:
		var lo := Vector3(side * width * 0.45, -0.06, depth * 0.32)
		var hi := lo + Vector3(0, (count - 1) * pitch + 0.24, 0)
		beam(k, mount, lo, hi, 0.025, 0.035, mat, col)
		for at in [lo, hi]:
			tube(k, mount, at, at + Vector3(0, 0, depth * 0.3), 0.018, mat, col, 6, false)
	k._fold(mount)

## Handrail along deck points, with stanchions and feet. Explicit points allow
## callers to leave access gaps instead of joining every segment indiscriminately.
static func railing(k: VehicleModels, parent: Node3D, feet: Array, height: float, radius := 0.018, mat := "metal_dark", col = null, middle := false) -> void:
	for foot: Vector3 in feet:
		tube(k, parent, foot, foot + Vector3.UP * height, radius, mat, col, 6, false)
		k._box(parent, Vector3(radius * 4, radius, radius * 4), foot, mat, col, Vector3.ZERO, false)
	for i in feet.size() - 1:
		for fraction: float in ([0.5, 1.0] if middle else [1.0]):
			tube(k, parent, feet[i] + Vector3.UP * height * fraction, feet[i + 1] + Vector3.UP * height * fraction, radius, mat, col, 6, false)

## Static routed hose/cable: authored supports, sag between them, and optional
## end collars. Sampling happens only during model construction.
static func cable(k: VehicleModels, parent: Node3D, supports: Array, radius: float, slack := 0.0, mat := "rubber", col = null, collars := true) -> void:
	for i in supports.size() - 1:
		var a: Vector3 = supports[i]
		var b: Vector3 = supports[i + 1]
		var count := 4 if slack > 0 else 1
		var last := a
		for j in range(1, count + 1):
			var t := float(j) / count
			var point := a.lerp(b, t) + Vector3.DOWN * sin(PI * t) * slack
			tube(k, parent, last, point, radius, mat, col, 6, false)
			last = point
		if collars:
			var direction := (b - a).normalized()
			for tip: Vector3 in [a, b]:
				tube(k, parent, tip - direction * radius * 1.5, tip + direction * radius * 1.5, radius * 1.35, "steel", null, 8, false)


## A wound service hose on a drum, with end flanges. Static, baked geometry;
## dimensions describe the hose pack, with the axle along local X.
static func hose_reel(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, width: float, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._cyl(mount, radius * 0.91, radius * 0.91, width, Vector3.ZERO, Vector3(0, 0, PI / 2), "rubber", null, 16)
	var count := clampi(ceili(width / (radius * 0.18)), 4, 14)
	for i in count:
		var ring := Res.torus(radius * 0.88, radius)
		k._add(mount, ring, "rubber", null, Vector3(lerpf(-width * 0.46, width * 0.46, float(i) / (count - 1)), 0, 0), Vector3(0, 0, PI / 2), Vector3(1, width / count / (radius * 0.12), 1), false)
	for side: float in [-1.0, 1.0]:
		k._cyl(mount, radius * 1.1, radius * 1.1, width * 0.05, Vector3(side * width * 0.52, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 16)
		k._cyl(mount, radius * 0.2, radius * 0.2, width * 0.08, Vector3(side * width * 0.54, 0, 0), Vector3(0, 0, PI / 2), "steel", null, 10, false)
	k._fold(mount)
