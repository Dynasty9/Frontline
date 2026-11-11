class_name VehicleMarine
extends RefCounted
## Deck hardware uses the same mounting construction at boat and ship scales.

static func mooring(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, yaw := 0.0, style := "cleat", material := "steel", col = null) -> void:
	assert(style in ["cleat", "bitts"])
	var mount := k._pivot(parent, base)
	mount.rotation.y = yaw
	var foot := minf(size.y * 0.15, 0.04)
	k._box(mount, Vector3(size.x, foot, size.z), Vector3(0, foot * 0.5, 0), material, col)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			VehicleBody.fastener(k, mount, Vector3(x * size.x * 0.38, foot, z * size.z * 0.32), Vector3.UP, minf(0.015, size.z * 0.09))
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
