class_name VehicleMounts
extends RefCounted
## Dimensioned equipment mounts. Temporary frames fold into the supplied parent;
## neither weapon sockets nor wheel/rotor animation registrations change here.

static func _mount(k: VehicleModels, parent: Node3D, center: Vector3, rotation: Vector3) -> Node3D:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	return mount

## Box mantlet or cradle, with a rounded casting and bolted trunnion covers.
## Preserve the authored barrel centre: the mount never adds or moves a muzzle.
static func mantlet(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(size, minf(size.x, minf(size.y, size.z)) * 0.12), mat, col, Vector3.ZERO)
	var radius := minf(size.y, size.z) * 0.23
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * size.x * 0.5, 0, size.z * 0.12)
		VehicleFrames.tube(k, mount, at, at + Vector3.RIGHT * side * radius * 0.15, radius, "metal_dark", null, 12, false)
		for i in 4:
			var a := TAU * i / 4.0
			VehicleBody.fastener(k, mount, at + Vector3(side * radius * 0.16, sin(a) * radius * 0.7, cos(a) * radius * 0.7), Vector3.RIGHT * side, radius * 0.13)
	k._fold(mount)

## Width is X. End caps stay within the authored envelope; front and back receive
## the same hardware so a rear bumper needs no reversed coordinate convention.
static func bumper(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO, moulded := false) -> void:
	var mount := _mount(k, parent, center, rotation)
	var bevel := minf(size.y, size.z) * 0.18
	k._add(mount, BevelMesh.make(size, bevel), mat, col, Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var x := side * (size.x * 0.5 - bevel * 1.5)
		k._add(mount, BevelMesh.make(Vector3(bevel, size.y * 0.86, size.z * 0.97), bevel * 0.25), "rubber" if moulded else mat, col, Vector3(x, 0, 0))
		if not moulded:
			for face: float in [-1.0, 1.0]:
				VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.31, 0, face * size.z * 0.505), Vector3.BACK * face, minf(0.016, size.y * 0.1))
	k._fold(mount)

## A towing jaw, not a weapon pintle. Local +Z faces away from the chassis.
static func hitch(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(Vector3(size.x, size.y, size.z * 0.28), minf(size.x, size.y) * 0.08), "gunmetal_w", null, Vector3(0, 0, -size.z * 0.35))
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x * 0.24, size.y * 0.62, size.z * 0.8), Vector3(side * size.x * 0.36, 0, size.z * 0.08), "gunmetal_w")
		VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.30, size.y * 0.34, -size.z * 0.20), Vector3.BACK, size.x * 0.07)
	VehicleFrames.tube(k, mount, Vector3(0, -size.y * 0.42, size.z * 0.32), Vector3(0, size.y * 0.42, size.z * 0.32), size.x * 0.13, "steel", null, 8, false)
	k._fold(mount)

## Open cage in local XY, with its attachment plane behind the face along Z.
static func light_guard(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, depth: float, face := -1.0, bars := 3, radius := 0.007) -> void:
	var front := center + Vector3(0, 0, face * depth)
	for side: float in [-1.0, 1.0]:
		var foot := center + Vector3(side * size.x * 0.5, -size.y * 0.5, 0)
		var top := front + Vector3(side * size.x * 0.5, size.y * 0.5, 0)
		VehicleFrames.path(k, parent, [foot, foot + Vector3(0, 0, face * depth), top], radius, "gunmetal_w", null, 6)
		VehicleBody.fastener(k, parent, foot, Vector3(0, 0, face), radius * 1.3)
	VehicleFrames.tube(k, parent, front + Vector3(-size.x * 0.5, size.y * 0.5, 0), front + Vector3(size.x * 0.5, size.y * 0.5, 0), radius, "gunmetal_w", null, 6, false)
	for i in bars:
		var x := lerpf(-size.x * 0.40, size.x * 0.40, float(i) / maxf(1, bars - 1)) if bars > 1 else 0.0
		VehicleFrames.tube(k, parent, front + Vector3(x, -size.y * 0.5, 0), front + Vector3(x, size.y * 0.5, 0), radius * 0.75, "gunmetal_w", null, 6, false)

## Open basket around a supplied floor centre. Cargo remains caller-owned.
static func basket(k: VehicleModels, parent: Node3D, floor_center: Vector3, size: Vector3, mat := "gunmetal_w", col = null, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, floor_center, rotation)
	var wire := minf(0.014, minf(size.x, size.z) * 0.035)
	var xs := maxi(2, ceili(size.x / 0.28))
	for i in xs + 1:
		var x := lerpf(-size.x * 0.5, size.x * 0.5, float(i) / xs)
		VehicleFrames.tube(k, mount, Vector3(x, 0, -size.z * 0.5), Vector3(x, 0, size.z * 0.5), wire, mat, col, 6, false)
	var feet := [Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(-size.x * 0.5, 0, size.z * 0.5), Vector3(size.x * 0.5, 0, size.z * 0.5), Vector3(size.x * 0.5, 0, -size.z * 0.5)]
	VehicleFrames.railing(k, mount, feet, size.y, wire, mat, col, true)
	for i in range(1, xs):
		var x := lerpf(-size.x * 0.5, size.x * 0.5, float(i) / xs)
		VehicleFrames.tube(k, mount, Vector3(x, 0, size.z * 0.5), Vector3(x, size.y, size.z * 0.5), wire * 0.65, mat, col, 5, false)
	k._fold(mount)

## Rectangular radar aperture or marine scanner bar; no new rotation pivot.
static func radar_array(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(size, minf(size.y, size.z) * 0.14), mat, col, Vector3.ZERO)
	var lip := minf(size.y, size.x) * 0.07
	k._box(mount, Vector3(size.x - lip * 2, size.y - lip * 2, 0.004), Vector3(0, 0, -size.z * 0.505), "rubber", Color(0.18, 0.19, 0.17), Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * (size.x * 0.5 - lip * 0.5), 0, -size.z * 0.51), Vector3.FORWARD, lip * 0.22)
		k._box(mount, Vector3(lip, size.y * 0.7, lip), Vector3(side * size.x * 0.28, 0, size.z * 0.5), mat, col)
	k._fold(mount)

## Box-section boom with end pin bosses and a wear collar. The caller owns its
## folded pose and hydraulic ram endpoints, so crane clearances stay authored.
static func boom(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float, mat: String, col = null) -> void:
	var direction := (b - a).normalized()
	var basis := VehicleFrames.aim(direction)
	var center := (a + b) * 0.5
	k._add(parent, BevelMesh.make(Vector3(width, a.distance_to(b), depth), minf(width, depth) * 0.10), mat, col, center, basis.get_euler())
	var collar := a.lerp(b, 0.90)
	k._box(parent, Vector3(width * 1.06, minf(width, depth) * 0.18, depth * 1.06), collar, "metal_dark", null, basis.get_euler())
	for end: Vector3 in [a.lerp(b, 0.04), a.lerp(b, 0.97)]:
		VehicleFrames.tube(k, parent, end - basis.x * width * 0.58, end + basis.x * width * 0.58, depth * 0.18, "steel", null, 10, false)

static func boom_box(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO) -> void:
	var axis := Basis.from_euler(rotation).z * size.z * 0.5
	boom(k, parent, center - axis, center + axis, size.x, size.y, mat, col)

## A panel of cage armour with actual open gaps. Endpoints describe its bottom
## edge; direction of the bars and spacing are explicit styles, not inferred.
static func slats(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, height: float, spacing: float, vertical := false, mat := "gunmetal_w", col = null) -> void:
	var along := (b - a).normalized()
	var normal := along.cross(Vector3.UP).normalized()
	for end: Vector3 in [a, b]:
		VehicleFrames.beam(k, parent, end, end + Vector3.UP * height, 0.045, 0.045, "gunmetal_w")
		VehicleBody.fastener(k, parent, end + Vector3.UP * height + normal * 0.026, normal, 0.010)
	for h: float in [0.0, height]:
		VehicleFrames.beam(k, parent, a + Vector3.UP * h, b + Vector3.UP * h, 0.045, 0.045, "gunmetal_w")
	var count := maxi(2, ceili((a.distance_to(b) if vertical else height) / spacing))
	for i in range(1, count):
		var t := float(i) / count
		var from := a.lerp(b, t) if vertical else a + Vector3.UP * height * t
		var to := from + Vector3.UP * height if vertical else b + Vector3.UP * height * t
		VehicleFrames.beam(k, parent, from, to, 0.018, 0.055, mat, col, false)

## Sensor stem segment; collars at both ends make telescoping stages legible.
static func mast_segment(k: VehicleModels, parent: Node3D, center: Vector3, height: float, radius: float, mat := "gunmetal_w", col = null) -> void:
	VehicleFrames.tube(k, parent, center - Vector3.UP * height * 0.5, center + Vector3.UP * height * 0.5, radius, mat, col, 10, false)
	for side: float in [-1.0, 1.0]:
		var p := center + Vector3.UP * side * (height * 0.5 - radius * 0.3)
		VehicleFrames.tube(k, parent, p - Vector3.UP * radius * 0.3, p + Vector3.UP * radius * 0.3, radius * 1.18, "metal_dark", null, 10, false)

## Receiver body with a feed-cover seam and charging handle. Barrel, feed box,
## grips and muzzle socket remain with the weapon builder.
static func receiver(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat := "gunmetal_w", col = null, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(size, minf(size.x, size.y) * 0.08), mat, col, Vector3.ZERO)
	k._box(mount, Vector3(size.x * 0.9, size.y * 0.025, size.z * 0.62), Vector3(0, size.y * 0.51, size.z * 0.08), "metal_dark", null, Vector3.ZERO, false)
	var p := Vector3(size.x * 0.50, size.y * 0.12, size.z * 0.17)
	VehicleFrames.tube(k, mount, p, p + Vector3.RIGHT * size.x * 0.3, size.x * 0.055, "steel", null, 6, false)
	for z: float in [-0.33, 0.33]:
		VehicleBody.fastener(k, mount, Vector3(size.x * 0.51, -size.y * 0.22, size.z * z), Vector3.RIGHT, size.x * 0.06)
	k._fold(mount)

## Sealed ellipsoidal radio cover. Size describes full diameters, not a radius;
## its mould seam follows the same ellipse as the shell.
static func radome(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null) -> void:
	k._add(parent, Res.sphere(0.5, 24), mat, col, center, Vector3.ZERO, size)
	var points := []
	for i in 25:
		var a := TAU * i / 24.0
		points.append(center + Vector3(cos(a) * size.x * 0.502, 0, sin(a) * size.z * 0.502))
	VehicleBody.seam(k, parent, points, minf(0.004, size.y * 0.015))
