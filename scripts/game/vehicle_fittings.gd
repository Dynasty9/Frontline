class_name VehicleFittings
extends RefCounted
## Repeating service fittings, folded into the parent's existing material bake.
static var _pipes := {}

## Local XY grille, +Z outward. Fins stand in front of a recessed radiator core.
static func grille(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, material: String, col = null, count := 8, vertical := false) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var rim := minf(0.035, minf(size.x, size.y) * 0.08)
	k._box(mount, Vector3(size.x, size.y, 0.018), Vector3(0, 0, -0.035), "plain_dark", Color(0.025, 0.028, 0.026), Vector3.ZERO, false)
	# Fine radiator channels behind the broad protective slats.
	var channels := clampi(ceili(size.x / 0.055), 6, 40)
	for i in channels:
		k._box(mount, Vector3(0.008, size.y - rim * 2, 0.012), Vector3(lerpf(-size.x / 2 + rim, size.x / 2 - rim, float(i) / (channels - 1)), 0, -0.018), "gunmetal", Color(0.14, 0.15, 0.14), Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x, rim, 0.06), Vector3(0, side * (size.y - rim) / 2, 0), material, col)
		k._box(mount, Vector3(rim, size.y - rim * 2, 0.06), Vector3(side * (size.x - rim) / 2, 0, 0), material, col)
		for y in [-1.0, 1.0]:
			VehicleBody.fastener(k, mount, Vector3(side * (size.x / 2 - rim / 2), y * (size.y / 2 - rim / 2), 0.035), Vector3.BACK, rim * 0.24)
	var span := (size.x if vertical else size.y) - rim * 2
	var pitch := span / maxf(count, 1)
	for i in count:
		var offset := -span / 2 + pitch * (i + 0.5)
		var fin_size := Vector3(pitch * 0.36, size.y - rim * 2, 0.035) if vertical else Vector3(size.x - rim * 2, pitch * 0.36, 0.035)
		k._box(mount, fin_size, Vector3(offset, 0, 0.008) if vertical else Vector3(0, offset, 0.008), material, col, Vector3(0, 0.22, 0) if vertical else Vector3(-0.28, 0, 0))
	k._fold(mount)


## A clamped rubber flap with a gently kicked lower edge and reinforcing ribs.
static func mudflap(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var rings: Array = []
	for i in 5:
		var t := float(i) / 4
		var y := size.y * (0.5 - t)
		var bend := t * t * 0.045
		rings.append(PackedVector3Array([Vector3(-size.x / 2, y, bend - 0.012), Vector3(size.x / 2, y, bend - 0.012), Vector3(size.x / 2, y, bend + 0.012), Vector3(-size.x / 2, y, bend + 0.012)]))
	k._add(mount, VehicleModels.solid(rings, "shared_mudflap_%s" % str(size)), "rubber", null, Vector3.ZERO)
	k._box(mount, Vector3(size.x, 0.04, 0.018), Vector3(0, size.y / 2 - 0.025, 0.026), "gunmetal", Color(0.22, 0.23, 0.21))
	for side in [-1.0, 0.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.36, size.y / 2 - 0.025, 0.038), Vector3.BACK, 0.009)
	for side in [-1.0, 1.0]:
		for i in 4:
			var t0 := float(i) / 4
			var t1 := float(i + 1) / 4
			VehicleFrames.tube(k, mount, Vector3(side * size.x * 0.36, size.y * (0.5 - t0), t0 * t0 * 0.045 + 0.016), Vector3(side * size.x * 0.36, size.y * (0.5 - t1), t1 * t1 * 0.045 + 0.016), 0.006, "rubber", Color(0.10, 0.11, 0.10), 5, false)
	k._fold(mount)


## Hollow exhaust on an authored axis. The dark sleeve sits behind the rolled
## lip; it is not a black disc pasted onto the end of a closed cylinder.
static func exhaust(k: VehicleModels, parent: Node3D, base: Vector3, direction: Vector3, length: float, radius: float) -> void:
	var mount := k._pivot(parent, base)
	mount.basis = VehicleFrames.aim(direction)
	var key := Vector2(radius, length)
	if not _pipes.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = radius
		outer.bottom_radius = radius
		outer.height = length
		outer.radial_segments = 16
		outer.cap_top = false
		var inner := CylinderMesh.new()
		inner.top_radius = radius * 0.80
		inner.bottom_radius = radius * 0.80
		inner.height = minf(length, radius * 4)
		inner.radial_segments = 16
		inner.cap_top = false
		inner.cap_bottom = false
		inner.flip_faces = true
		_pipes[key] = [outer, inner]
	var pipes: Array = _pipes[key]
	k._add(mount, pipes[0], "gunmetal", Color(0.24, 0.23, 0.21), Vector3(0, length / 2, 0))
	var depth := minf(length, radius * 4)
	k._add(mount, pipes[1], "burnt", Color(0.025, 0.025, 0.023), Vector3(0, length - depth / 2, 0))
	k._cyl(mount, radius * 0.8, radius * 0.8, 0.004, Vector3(0, length - depth, 0), Vector3.ZERO, "burnt", null, 16, false)
	k._add(mount, VehicleWheels.ring(radius * 0.8, radius * 1.03), "gunmetal", Color(0.28, 0.24, 0.19), Vector3(0, length, 0))
	# Stand-off shield and clamps sit below the hot, uncovered outlet.
	k._cyl(mount, radius * 1.4, radius * 1.4, length * 0.30, Vector3(0, length * 0.43, 0), Vector3.ZERO, "steel", Color(0.28, 0.29, 0.26), 16)
	for t in [0.28, 0.58]:
		k._add(mount, VehicleWheels.ring(radius * 1.35, radius * 1.55), "gunmetal", Color(0.18, 0.19, 0.17), Vector3(0, length * t, 0), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	k._fold(mount)
