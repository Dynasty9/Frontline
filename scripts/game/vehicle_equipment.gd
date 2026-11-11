class_name VehicleEquipment
extends RefCounted
## Mounted service equipment, parameterized by real dimensions rather than
## separate small/large copies. Hardware sizes are clamped independently.

static func storage(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var lip := minf(0.025, size.y * 0.09)
	k._add(mount, BevelMesh.make(size - Vector3(0, lip, 0), minf(lip * 0.7, minf(size.x, size.z) * 0.04)), mat, col, Vector3(0, -lip * 0.5, 0))
	k._box(mount, Vector3(size.x * 0.98, lip * 0.4, size.z * 0.98), Vector3(0, size.y * 0.5 - lip, 0), "rubber")
	k._box(mount, Vector3(size.x, lip, size.z), Vector3(0, size.y * 0.5 - lip * 0.35, 0), mat, col)
	var inset := minf(size.x, size.z) * 0.12
	k._add(mount, BevelMesh.make(Vector3(size.x - inset * 2, lip * 0.3, size.z - inset * 2), lip * 0.1), mat, col, Vector3(0, size.y * 0.5 + lip * 0.25, 0))
	var along := Vector3.FORWARD if size.z > size.x else Vector3.RIGHT
	VehicleDoors.pull(k, mount, Vector3(0, size.y * 0.5, 0), Vector3.UP, along, minf(0.18, maxf(size.x, size.z) * 0.35), minf(0.012, minf(size.x, size.z) * 0.08))
	for side: float in [-1.0, 1.0]:
		VehicleDoors.hinge(k, mount, Vector3(side * size.x * 0.3, size.y * 0.5, size.z * 0.43), Vector3.UP, Vector3.RIGHT, minf(0.012, size.x * 0.06), mat, col)
		k._box(mount, Vector3(minf(0.04, size.x * 0.18), lip * 2, 0.015), Vector3(side * size.x * 0.3, size.y * 0.5 - lip, -size.z * 0.51), "metal_dark")
	k._fold(mount)

static func skirt(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var cut := minf(0.06, minf(size.y, size.z) * 0.1)
	var profile := [-size.z * 0.5 + cut, -size.y * 0.5, size.z * 0.5 - cut, -size.y * 0.5, size.z * 0.5, -size.y * 0.5 + cut, size.z * 0.5, size.y * 0.5, -size.z * 0.5, size.y * 0.5, -size.z * 0.5, -size.y * 0.5 + cut]
	k._add(parent, VehicleModels.extrude_x("skirt_" + str(size), profile, -size.x * 0.5, size.x * 0.5), mat, col, center, rotation)
	var basis := Basis.from_euler(rotation)
	var normal := basis * Vector3(side, 0, 0)
	for end: float in [-1.0, 1.0]:
		var at := center + basis * Vector3(side * size.x * 0.55, size.y * 0.38, end * size.z * 0.36)
		VehicleBody.fastener(k, parent, at, normal, 0.012)
		VehicleFrames.tube(k, parent, at - basis.z * 0.035, at + basis.z * 0.035, minf(0.012, size.x * 0.2), "steel", null, 6, false)
		VehicleFrames.beam(k, parent, at - basis.y * size.y * 0.08, at + basis.y * size.y * 0.14, 0.032, 0.018, "metal_dark")
	# A thin lower fold distinguishes formed metal from flexible rubber skirts.
	if VehicleMaterials.profile(mat, k.surface_family) != "rubber":
		var a := center + basis * Vector3(side * size.x * 0.52, -size.y * 0.46, -size.z * 0.46)
		var b := center + basis * Vector3(side * size.x * 0.52, -size.y * 0.46, size.z * 0.46)
		VehicleFrames.tube(k, parent, a, b, 0.006, mat, col, 5, false)

static func winch(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var radius := size.y * 0.35
	var width := size.x * 0.66
	k._box(mount, Vector3(size.x, size.y * 0.16, size.z), Vector3(0, -size.y * 0.4, 0), "metal_dark")
	k._cyl(mount, radius, radius, width, Vector3.ZERO, Vector3(0, 0, PI / 2), "metal_dark", null, 16)
	for i in 9:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.88
		ring.outer_radius = radius * 1.03
		ring.rings = 12
		ring.ring_segments = 4
		k._add(mount, ring, "steel", Color(0.23, 0.24, 0.23), Vector3(lerpf(-width * 0.43, width * 0.43, i / 8.0), 0, 0), Vector3(0, 0, PI / 2))
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x * 0.1, size.y * 0.85, size.z * 0.65), Vector3(side * width * 0.57, 0, 0), "metal_dark")
		var x := side * width * 0.38
		VehicleFrames.tube(k, mount, Vector3(x, -radius * 0.5, -size.z * 0.55), Vector3(x, radius * 0.5, -size.z * 0.55), radius * 0.19, "steel", null, 8, false)
	for side: float in [-1.0, 1.0]:
		VehicleFrames.tube(k, mount, Vector3(-width * 0.38, side * radius * 0.5, -size.z * 0.55), Vector3(width * 0.38, side * radius * 0.5, -size.z * 0.55), radius * 0.15, "steel", null, 8, false)
	VehicleFrames.cable(k, mount, [Vector3(0, -radius * 0.35, 0), Vector3(0, -radius * 0.35, -size.z * 0.6)], radius * 0.08, 0.0, "steel", null, false)
	for side: float in [-1.0, 1.0]:
		k._cyl(mount, radius * 1.18, radius * 1.18, size.x * 0.025, Vector3(side * width * 0.48, 0, 0), Vector3(0, 0, PI / 2), "steel", Color(0.18, 0.19, 0.18), 16)
	k._cyl(mount, radius * 0.65, radius * 0.65, size.x * 0.12, Vector3(size.x * 0.43, 0, 0), Vector3(0, 0, PI / 2), "metal_dark", null, 12)
	k._box(mount, Vector3(size.x * 0.12, size.y * 0.65, size.z * 0.45), Vector3(-size.x * 0.43, 0, 0), "metal_dark")
	k._fold(mount)


## Sensor cases share recessed lenses and protective bezels. No turret or
## animation registration happens here; a caller may provide its own pivot.
static func sensor(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null, style := "box") -> void:
	var mount := k._pivot(parent, center)
	if style == "ball":
		k._add(mount, Res.sphere(0.5, 16), mat, col, Vector3.ZERO, Vector3.ZERO, size)
	else:
		k._box(mount, size, Vector3.ZERO, mat, col)
		k._box(mount, Vector3(size.x * 1.07, size.y * 0.08, size.z * 1.08), Vector3(0, size.y * 0.54, 0), mat, col)
	for i in 2:
		var radius := minf(size.x * (0.13 if i == 0 else 0.09), size.y * 0.22)
		var at := Vector3(size.x * (-0.19 if i == 0 else 0.19), 0, -size.z * 0.49)
		k._cyl(mount, radius * 1.25, radius * 1.25, radius * 0.35, at, Vector3(PI / 2, 0, 0), "rubber", null, 12, false)
		if not k.burnt:
			k._cyl(mount, radius, radius, radius * 0.08, at + Vector3(0, 0, -radius * 0.2), Vector3(PI / 2, 0, 0), "glass", Color(0.13, 0.20, 0.23), 12, false)
		var rim := VehicleFittings._ring(radius, radius * 1.2)
		k._add(mount, rim, "metal_dark", null, at + Vector3(0, 0, -radius * 0.28), Vector3(PI / 2, 0, 0), Vector3(1, 0.45, 1))
	for side: float in [-1.0, 1.0]:
		k._cyl(mount, size.y * 0.16, size.y * 0.16, size.x * 0.06, Vector3(side * size.x * 0.5, 0, 0), Vector3(0, 0, PI / 2), mat, col, 10, false)
	if style == "box":
		k._box(mount, Vector3(size.x * 1.08, size.y * 0.07, size.z * 0.24), Vector3(0, size.y * 0.50, -size.z * 0.48), mat, col)
	else:
		k._add(mount, VehicleFittings._ring(size.y * 0.17, size.y * 0.21), "rubber", null, Vector3(0, size.y * 0.46, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	var cover := Vector3(0, 0, size.z * 0.49)
	if style == "ball":
		k._cyl(mount, minf(size.x, size.y) * 0.22, minf(size.x, size.y) * 0.22, size.z * 0.12, Vector3(0, 0, size.z * 0.44), Vector3(PI / 2, 0, 0), mat, col, 12)
	else:
		k._add(mount, BevelMesh.make(Vector3(size.x * 0.44, size.y * 0.42, size.z * 0.035), minf(size.z * 0.012, size.y * 0.03)), mat, col, cover)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, cover + Vector3(side * size.x * 0.15, 0, size.z * 0.025), Vector3.BACK, minf(0.009, size.y * 0.035))
	k._fold(mount)


## Dished cylindrical/oval vessel along local Z, with straps and optional
## saddles. Width, height and length are independent for different tank bodies.
static func vessel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, straps: Array, mat: String, col = null, saddles := true) -> void:
	var cap := minf(size.z * 0.12, size.y * 0.18)
	var half := size.z * 0.5
	var profile := [Vector2(0, -half), Vector2(0.7, -half + cap * 0.2), Vector2(1, -half + cap), Vector2(1, half - cap), Vector2(0.7, half - cap * 0.2), Vector2(0, half)]
	var scale := Vector3(size.x * 0.5, size.y * 0.5, 1)
	k._add(parent, VehicleProfiles.revolve(profile, 24, 65), mat, col, center, Vector3.ZERO, scale)
	for end: float in [-1.0, 1.0]:
		var z := end * (half - cap)
		var weld := [Vector2(1, z - 0.008), Vector2(1.006, z), Vector2(1, z + 0.008)]
		k._add(parent, VehicleProfiles.revolve(weld, 24), mat, col, center, Vector3.ZERO, scale)
	for z: float in straps:
		var band := [Vector2(1, z - 0.024), Vector2(1.012, z - 0.02), Vector2(1.012, z + 0.02), Vector2(1, z + 0.024)]
		k._add(parent, VehicleProfiles.revolve(band, 24), "metal_dark", null, center, Vector3.ZERO, scale)
		var pad := [Vector2(1, z - 0.036), Vector2(1.004, z - 0.032), Vector2(1.004, z + 0.032), Vector2(1, z + 0.036)]
		k._add(parent, VehicleProfiles.revolve(pad, 24), "rubber", null, center, Vector3.ZERO, scale)
		if saddles:
			k._box(parent, Vector3(size.x * 0.8, size.y * 0.14, 0.12), center + Vector3(0, -size.y * 0.48, z), "metal_dark")
		for side: float in [-1.0, 1.0]:
			VehicleBody.fastener(k, parent, center + Vector3(side * size.x * 0.38, -size.y * 0.30, z), Vector3(side, 0.5, 0).normalized(), 0.014)
