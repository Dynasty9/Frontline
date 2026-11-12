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

static var _bevels := {}

## BevelMesh by size, shared by repeated identical parts (reactive bricks).
static func _bevel(size: Vector3, bevel: float) -> Mesh:
	var key := Vector4(size.x, size.y, size.z, bevel)
	if not _bevels.has(key):
		_bevels[key] = BevelMesh.make(size, bevel)
	return _bevels[key]

## Turret race ring: the old cylinder's centre, radii and height. A splash
## guard lip round the foot and the race's bolt circle on its outer face. No
## pivot is added; the ring stays on the turret that traverses with it.
static func turret_ring(k: VehicleModels, parent: Node3D, center: Vector3, top_radius: float, bottom_radius: float, height: float, mat: String, col = null, segments := 20) -> void:
	k._cyl(parent, top_radius, bottom_radius, height, center, Vector3.ZERO, mat, col, segments)
	var lip := bottom_radius + minf(0.018, height * 0.22)
	k._cyl(parent, lip, lip, height * 0.22, center + Vector3(0, -height * 0.39, 0), Vector3.ZERO, mat, col, segments, false)
	var count := clampi(roundi(TAU * top_radius / 0.32), 10, 24)
	var radius := lerpf(bottom_radius, top_radius, 0.62) + 0.002
	for i in count:
		var a := TAU * (i + 0.5) / count
		var normal := Vector3(cos(a), 0, sin(a))
		VehicleBody.fastener(k, parent, center + normal * radius + Vector3(0, height * 0.12, 0), normal, minf(0.013, height * 0.15))

## Armoured sight head (gunner's box, commander's panoramic head) with its
## window on the local -Z face. `windows` holds Rect2s: position is the window
## centre on that face (x right, y up), size its width and height; empty gives
## one centred window. `stem` = (top radius, bottom radius, drop) adds the
## panoramic head's column, reaching `drop` below the head's centre. Wrecks
## keep the frames and lose the glass.
static func sight(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, windows: Array, mat: String, col = null, stem := Vector3.ZERO, rotation := Vector3.ZERO) -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(size, minf(0.018, minf(size.x, minf(size.y, size.z)) * 0.1)), mat, col, Vector3.ZERO)
	var panes := windows
	if panes.is_empty():
		panes = [Rect2(Vector2(0, size.y * 0.06), Vector2(size.x * 0.66, size.y * 0.46))]
	var face := -size.z * 0.5
	for pane: Rect2 in panes:
		var c := Vector3(pane.position.x, pane.position.y, face)
		var w := pane.size.x
		var h := pane.size.y
		var bar := minf(0.014, minf(w, h) * 0.16)
		# Bezel bars around the pane stand proud of the glass, not over it.
		for side: float in [-1.0, 1.0]:
			k._box(mount, Vector3(w + bar * 2, bar, 0.028), c + Vector3(0, side * (h + bar) * 0.5, -0.012), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(mount, Vector3(bar, h, 0.028), c + Vector3(side * (w + bar) * 0.5, 0, -0.012), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(mount, Vector3(w + 0.004, h + 0.004, 0.012), c + Vector3(0, 0, -0.004), "rubber", null, Vector3.ZERO, false)
		if not k.burnt:
			k._box(mount, Vector3(w, h, 0.02), c + Vector3(0, 0, -0.01), "glass", null, Vector3.ZERO, false)
		# The armoured visor shades the window from above.
		var depth := minf(0.07, size.z * 0.3)
		k._box(mount, Vector3(w + bar * 3, 0.016, depth), c + Vector3(0, h * 0.5 + bar + 0.008, -depth * 0.5 + 0.004), mat, col, Vector3(0.12, 0, 0))
	# The split between cover and body runs round the head.
	var y := size.y * 0.2
	var hx := size.x * 0.505
	var hz := size.z * 0.505
	VehicleBody.seam(k, mount, [Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz), Vector3(-hx, y, -hz)], 0.003)
	if stem.z > 0.0:
		VehicleFrames.tube(k, mount, Vector3(0, -stem.z, 0), Vector3.ZERO, stem.y, "gunmetal_w", null, 12, true, stem.x)
		# Flange and rotary joint grow with thin stems but stay within a fat one's
		# head, so a stubby commander's sight keeps its outline.
		var foot := minf(stem.y * 1.45, stem.y + 0.04)
		k._cyl(mount, foot * 0.96, foot, 0.03, Vector3(0, -stem.z + 0.015, 0), Vector3.ZERO, "gunmetal_w", null, 12)
		k._cyl(mount, minf(stem.x * 1.25, stem.x + 0.025), minf(stem.x * 1.25, stem.x + 0.025), 0.03, Vector3(0, -size.y * 0.5 - 0.012, 0), Vector3.ZERO, "metal_dark", null, 12, false)
		for i in 4:
			var a := TAU * (i + 0.5) / 4.0
			var n := Vector3(cos(a), 0, sin(a))
			VehicleBody.fastener(k, mount, Vector3(0, -stem.z + 0.032, 0) + n * (stem.y + foot) * 0.5, Vector3.UP, minf(0.01, stem.y * 0.12))
	k._fold(mount)

## Commander's cupola: the old ring cylinder (centre, radii, height) with a
## bolted roof flange and `blocks` vision blocks round it, the first at
## `first_angle` radians from forward and `step` apart (0 faces -Z, positive
## toward +X). Each block has an armoured housing, a rain hood and glass.
## The hatch stays with the caller.
static func cupola(k: VehicleModels, parent: Node3D, center: Vector3, top_radius: float, bottom_radius: float, height: float, blocks: int, first_angle: float, step: float, mat: String, col = null, block := Vector3(0.11, 0.07, 0.05)) -> void:
	k._cyl(parent, top_radius, bottom_radius, height, center, Vector3.ZERO, mat, col, 18)
	var foot := bottom_radius + 0.022
	var flange := minf(0.03, height * 0.2)
	k._cyl(parent, foot, foot + 0.006, flange, center + Vector3(0, -height * 0.5 + flange * 0.5, 0), Vector3.ZERO, mat, col, 18, false)
	var bolts := clampi(roundi(TAU * foot / 0.2), 8, 16)
	for i in bolts:
		var a := TAU * (i + 0.5) / bolts
		VehicleBody.fastener(k, parent, center + Vector3(cos(a) * (foot - 0.012), -height * 0.5 + flange + 0.002, sin(a) * (foot - 0.012)), Vector3.UP, 0.009)
	var radius := (top_radius + bottom_radius) * 0.5
	for i in blocks:
		var a := first_angle + i * step
		var mount := _mount(k, parent, center + Vector3(sin(a) * radius, height * 0.12, -cos(a) * radius), Vector3(0, -a, 0))
		k._add(mount, BevelMesh.make(Vector3(block.x + 0.03, block.y + 0.024, block.z), 0.006), mat, col, Vector3.ZERO)
		k._box(mount, Vector3(block.x + 0.05, 0.012, 0.036), Vector3(0, block.y * 0.5 + 0.018, -block.z * 0.5 - 0.012), mat, col, Vector3(0.1, 0, 0))
		k._box(mount, Vector3(block.x + 0.006, block.y + 0.006, 0.008), Vector3(0, 0, -block.z * 0.5 - 0.002), "rubber", null, Vector3.ZERO, false)
		if not k.burnt:
			k._box(mount, Vector3(block.x, block.y, 0.012), Vector3(0, 0, -block.z * 0.5 - 0.005), "glass", null, Vector3.ZERO, false)
		k._fold(mount)

## One explosive reactive armour brick: the old box's centre, size and
## rotation, local +Z outward. A pressed cover plate over the insert and two
## diagonal bolts. Grids and face frames stay with the family helpers.
static func era_brick(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation: Vector3, mat: String, col = null) -> void:
	var mount := _mount(k, parent, center, rotation)
	var bevel := minf(0.012, minf(size.x, size.y) * 0.06)
	k._add(mount, _bevel(Vector3(size.x, size.y, size.z * 0.8), bevel), mat, col, Vector3(0, 0, -size.z * 0.1))
	# Bricks repeat by the hundred on a tank, so the cover is a plain plate.
	k._box(mount, Vector3(size.x * 0.9, size.y * 0.86, size.z * 0.22), Vector3(0, 0, size.z * 0.38), mat, col)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		VehicleBody.fastener(k, mount, Vector3(corner.x * size.x * 0.36, corner.y * size.y * 0.33, size.z * 0.49 + 0.002), Vector3.BACK, minf(0.012, size.x * 0.06))
	k._fold(mount)
