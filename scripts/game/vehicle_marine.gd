class_name VehicleMarine
extends RefCounted
## Deck hardware uses the same mounting construction at boat and ship scales.

static func mooring(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, yaw := 0.0, style := "cleat", material := "steel", col = null) -> void:
	assert(style in ["cleat", "bitts"])
	var mount := k._pivot(parent, base)
	mount.rotation.y = yaw
	k._box(mount, Vector3(size.x * 1.02, size.y * 0.03, size.z * 1.02), Vector3(0, size.y * 0.015, 0), "rubber")
	var foot := minf(size.y * 0.15, 0.04)
	k._box(mount, Vector3(size.x, foot, size.z), Vector3(0, foot * 0.5, 0), material, col)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			VehicleBody.fastener(k, mount, Vector3(x * size.x * 0.38, foot, z * size.z * 0.32), Vector3.UP, minf(0.015, size.z * 0.09))
	for side: float in [-1.0, 1.0]:
		k._cyl(mount, size.z * (0.31 if style == "bitts" else 0.18), size.z * (0.40 if style == "bitts" else 0.27), foot * 1.8, Vector3(side * size.x * (0.32 if style == "bitts" else 0.18), foot * 1.3, 0), Vector3.ZERO, material, col, 10, false)
	if style == "bitts":
		for side: float in [-1.0, 1.0]:
			var center := Vector3(side * size.x * 0.32, size.y * 0.5, 0)
			k._cyl(mount, size.z * 0.31, size.z * 0.34, size.y - foot, center, Vector3.ZERO, material, col, 12)
			k._cyl(mount, size.z * 0.42, size.z * 0.42, foot, center + Vector3(0, size.y * 0.5 - foot, 0), Vector3.ZERO, material, col, 12)
	else:
		var radius := size.z * 0.18
		for side: float in [-1.0, 1.0]:
			VehicleFrames.tube(k, mount, Vector3(side * size.x * 0.18, foot, 0), Vector3(side * size.x * 0.18, size.y * 0.72, 0), radius, material, col, 8, false)
		var points := [Vector3(-size.x * 0.5, size.y * 0.92, 0), Vector3(-size.x * 0.3, size.y * 0.76, 0), Vector3(size.x * 0.3, size.y * 0.76, 0), Vector3(size.x * 0.5, size.y * 0.92, 0)]
		for i in points.size() - 1:
			VehicleFrames.tube(k, mount, points[i], points[i + 1], radius, material, col, 8, false)
	k._fold(mount)

## Marine screw on local Z. Blade pitch is geometric and independent of aircraft
## propeller animation; callers retain any existing motor or rudder pivots.
static func propeller(k: VehicleModels, parent: Node3D, pos: Vector3, radius: float, blades: int, mat: String, col = null) -> void:
	k._cyl(parent, radius * 0.26, radius * 0.3, radius * 0.5, pos, Vector3(PI / 2, 0, 0), mat, col, 12, false)
	k._cyl(parent, radius * 0.06, radius * 0.26, radius * 0.4, pos + Vector3(0, 0, radius * 0.45), Vector3(PI / 2, 0, 0), mat, col, 12, false)
	var profile := [Vector2(0.12, -0.10), Vector2(0.42, -0.32), Vector2(0.86, -0.28), Vector2(1.0, -0.08), Vector2(0.88, 0.26), Vector2(0.42, 0.22)]
	for i in blades:
		var basis := Basis(Vector3.BACK, TAU * i / float(blades)) * Basis(Vector3.RIGHT, 0.58)
		var front := PackedVector3Array()
		var back := PackedVector3Array()
		for p in profile:
			front.append(basis * Vector3(p.y * radius, p.x * radius, radius * 0.025))
			back.append(basis * Vector3(p.y * radius, p.x * radius, -radius * 0.025))
		k._add(parent, VehicleProfiles.loft([back, front], 45.0, true), mat, col, pos)
