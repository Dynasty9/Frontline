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
		# The cover's inner face is on the casting.
		VehicleEquipment._rod(k, mount, at, at + Vector3.RIGHT * side * radius * 0.15, radius, "metal_dark", null, 12, false, 2)
		# A small cradle's cover bolts would be under a centimetre across.
		if radius * 0.13 < 0.005:
			continue
		for i in 4:
			var a := TAU * i / 4.0
			VehicleBody.fastener(k, mount, at + Vector3(side * radius * 0.16, sin(a) * radius * 0.7, cos(a) * radius * 0.7), Vector3.RIGHT * side, radius * 0.13)
	k._fold(mount)

## Width is X. End caps stay within the authored envelope; front and back receive
## the same hardware so a rear bumper needs no reversed coordinate convention,
## except that a bumper clearly fore or aft of the parent's middle leaves out
## the bolts on its face toward the vehicle, which stand behind it unseen.
static func bumper(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO, moulded := false) -> void:
	var mount := _mount(k, parent, center, rotation)
	var bevel := minf(size.y, size.z) * 0.18
	k._add(mount, BevelMesh.make(size, bevel), mat, col, Vector3.ZERO)
	var faces: Array[float] = [-1.0, 1.0]
	if absf(center.z) > size.z * 2.0:
		var out := Basis.from_euler(rotation).z.z * signf(center.z)
		if absf(out) > 0.7:
			faces = [signf(out)]
	for side: float in [-1.0, 1.0]:
		var x := side * (size.x * 0.5 - bevel * 1.5)
		k._add(mount, BevelMesh.make(Vector3(bevel, size.y * 0.86, size.z * 0.97), bevel * 0.25), "rubber" if moulded else mat, col, Vector3(x, 0, 0))
		if not moulded:
			for face: float in faces:
				VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.31, 0, face * size.z * 0.505), Vector3.BACK * face, minf(0.016, size.y * 0.1))
	k._fold(mount)

## A towing jaw, not a weapon pintle. Local +Z faces away from the chassis.
## `style` "ball" builds a tow ball on the same bolted mounting plate in place
## of the jaws and pin: a flat ball mount reaching out from the plate's face,
## the neck standing on it with its nut under the mount, and the ball on top,
## all within the same box, the nut at its foot and the ball's crown at its
## top; "jaw" (the default) is the open jaws with their vertical pin.
static func hitch(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation := Vector3.ZERO, style := "jaw") -> void:
	var mount := _mount(k, parent, center, rotation)
	k._add(mount, BevelMesh.make(Vector3(size.x, size.y, size.z * 0.28), minf(size.x, size.y) * 0.08), "gunmetal_w", null, Vector3(0, 0, -size.z * 0.35))
	for side: float in [-1.0, 1.0]:
		if style != "ball":
			k._box(mount, Vector3(size.x * 0.24, size.y * 0.62, size.z * 0.8), Vector3(side * size.x * 0.36, 0, size.z * 0.08), "gunmetal_w")
		VehicleBody.fastener(k, mount, Vector3(side * size.x * 0.30, size.y * 0.34, -size.z * 0.20), Vector3.BACK, size.x * 0.07)
	if style != "ball":
		VehicleFrames.tube(k, mount, Vector3(0, -size.y * 0.42, size.z * 0.32), Vector3(0, size.y * 0.42, size.z * 0.32), size.x * 0.13, "steel", null, 8, false)
		k._fold(mount)
		return
	# The ball mount: a flat bar from the plate's face out under the ball, its
	# nut under it at the foot of the box.
	var ball := minf(size.x * 0.3, minf(size.y * 0.24, size.z * 0.2))
	var z := size.z * 0.5 - ball * 1.15
	var nut := size.y * 0.1
	var bar := Vector3(minf(size.x * 0.6, ball * 2.6), size.y * 0.16, z + ball + size.z * 0.21)
	var floor_y := -size.y * 0.5 + nut + bar.y
	k._box(mount, bar, Vector3(0, floor_y - bar.y * 0.5, -size.z * 0.21 + bar.z * 0.5), "gunmetal_w")
	k._cyl(mount, ball * 0.75, ball * 0.75, nut, Vector3(0, -size.y * 0.5 + nut * 0.5, z), Vector3.ZERO, "steel", null, 6, false)
	# The neck narrows from its collar on the mount up into the ball.
	var top := size.y * 0.5 - ball
	k._cyl(mount, ball * 0.55, ball * 0.8, top - floor_y, Vector3(0, (floor_y + top) * 0.5, z), Vector3.ZERO, "gunmetal_w", null, 10)
	k._add(mount, Res.sphere(ball, 10), "steel", null, Vector3(0, top, z))
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
## `rake` leans it: the top end stands that far (horizontally) from straight
## over the bottom, the segment still centred on `center` and rising `height`
## (a mast raked forward over a nose); zero stands it upright.
static func mast_segment(k: VehicleModels, parent: Node3D, center: Vector3, height: float, radius: float, mat := "gunmetal_w", col = null, rake := Vector3.ZERO) -> void:
	var half := (Vector3.UP * height + Vector3(rake.x, 0, rake.z)) * 0.5
	var axis := half.normalized()
	# The tube's ends are flush with its collars' outer faces.
	VehicleEquipment._rod(k, parent, center - half, center + half, radius, mat, col, 10, false, 0)
	for side: float in [-1.0, 1.0]:
		var p := center + half * side - axis * side * radius * 0.3
		VehicleEquipment._rod(k, parent, p - axis * radius * 0.3, p + axis * radius * 0.3, radius * 1.18, "metal_dark", null, 10, false, 3)

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
	# The race and its lip stand on the roof: their undersides never show.
	k._add(parent, VehicleEquipment._cylinder(top_radius, bottom_radius, height, segments, true, false), mat, col, center)
	var lip := bottom_radius + minf(0.018, height * 0.22)
	k._add(parent, VehicleEquipment._cylinder(lip, lip, height * 0.22, segments, true, false), mat, col, center + Vector3(0, -height * 0.39, 0), Vector3.ZERO, Vector3.ONE, false)
	# A bolt about every 42 cm still reads as the race's bolt circle under the
	# turret's overhang, at three quarters of the bolts.
	var count := clampi(roundi(TAU * top_radius / 0.42), 8, 20)
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
		# Bezel bars around the pane stand proud of the glass, not over it. Bars,
		# seal, glass and visor are all under 2 cm thick: plain plates, as a
		# chamfer of a few millimetres on them is lost even in a close-up.
		for side: float in [-1.0, 1.0]:
			k._add(mount, VehicleEquipment._plate(Vector3(w + bar * 2, bar, 0.028)), "gunmetal_w", null, c + Vector3(0, side * (h + bar) * 0.5, -0.012), Vector3.ZERO, Vector3.ONE, false)
			k._add(mount, VehicleEquipment._plate(Vector3(bar, h, 0.028)), "gunmetal_w", null, c + Vector3(side * (w + bar) * 0.5, 0, -0.012), Vector3.ZERO, Vector3.ONE, false)
		k._add(mount, VehicleEquipment._plate(Vector3(w + 0.004, h + 0.004, 0.012)), "rubber", null, c + Vector3(0, 0, -0.004), Vector3.ZERO, Vector3.ONE, false)
		if not k.burnt:
			k._add(mount, VehicleEquipment._plate(Vector3(w, h, 0.02)), "glass", null, c + Vector3(0, 0, -0.01), Vector3.ZERO, Vector3.ONE, false)
		# The armoured visor shades the window from above.
		var depth := minf(0.07, size.z * 0.3)
		k._add(mount, VehicleEquipment._plate(Vector3(w + bar * 3, 0.016, depth)), mat, col, c + Vector3(0, h * 0.5 + bar + 0.008, -depth * 0.5 + 0.004), Vector3(0.12, 0, 0))
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
	# The ring and its flange stand on the roof: their undersides never show.
	VehicleEquipment._cyl(k, parent, top_radius, bottom_radius, height, center, Vector3.ZERO, mat, col, 18, true, 2)
	var foot := bottom_radius + 0.022
	var flange := minf(0.03, height * 0.2)
	VehicleEquipment._cyl(k, parent, foot, foot + 0.006, flange, center + Vector3(0, -height * 0.5 + flange * 0.5, 0), Vector3.ZERO, mat, col, 18, false, 2)
	var bolts := clampi(roundi(TAU * foot / 0.2), 8, 16)
	for i in bolts:
		var a := TAU * (i + 0.5) / bolts
		VehicleBody.fastener(k, parent, center + Vector3(cos(a) * (foot - 0.012), -height * 0.5 + flange + 0.002, sin(a) * (foot - 0.012)), Vector3.UP, 0.009)
	var radius := (top_radius + bottom_radius) * 0.5
	for i in blocks:
		var a := first_angle + i * step
		var mount := _mount(k, parent, center + Vector3(sin(a) * radius, height * 0.12, -cos(a) * radius), Vector3(0, -a, 0))
		k._add(mount, BevelMesh.make(Vector3(block.x + 0.03, block.y + 0.024, block.z), 0.006), mat, col, Vector3.ZERO)
		# The hood and the glass are 1.2 cm sheets: plain plates.
		k._add(mount, VehicleEquipment._plate(Vector3(block.x + 0.05, 0.012, 0.036)), mat, col, Vector3(0, block.y * 0.5 + 0.018, -block.z * 0.5 - 0.012), Vector3(0.1, 0, 0))
		k._box(mount, Vector3(block.x + 0.006, block.y + 0.006, 0.008), Vector3(0, 0, -block.z * 0.5 - 0.002), "rubber", null, Vector3.ZERO, false)
		if not k.burnt:
			k._add(mount, VehicleEquipment._plate(Vector3(block.x, block.y, 0.012)), "glass", null, Vector3(0, 0, -block.z * 0.5 - 0.005), Vector3.ZERO, Vector3.ONE, false)
		k._fold(mount)

## Crew-served weapon pedestal (a pickup technical's pintle post). The static
## part goes on `parent`, in its coordinates: from `base`, the floor point under
## the post, a `plate`-square base plate bolted down at its corners, or with
## `plate` 0 and `clamp` > 0 a split clamp round a bar of that radius running
## along X through `base` (the bar stays with the caller); a tapered `post`
## (top, bottom radius) with a welded collar, `braces` 4 (or 2, fore and aft)
## struts from the plate to the post, rising to the bearing under `pivot`.
## The traversing part goes on `head`, the caller's turret node whose origin
## is `pivot` (null for none): the swivel housing with its traverse lock, and
## `yoke` = (cheek half-spacing, cheek height, cheek depth) cradle cheeks with
## the elevation pin across their tops and an elevation lock. The gun, its
## muzzle marker, any shield (gun_shield) and ammunition stay with the caller.
static func pedestal(k: VehicleModels, parent: Node3D, base: Vector3, pivot: Vector3, head: Node3D = null, mat := "gunmetal_w", col = null, plate := 0.5, post := Vector2(0.07, 0.08), braces := 4, yoke := Vector3(0.1, 0.3, 0.16), clamp := 0.0) -> void:
	var foot := base.y
	if plate > 0.0:
		k._box(parent, Vector3(plate, 0.03, plate), base + Vector3(0, 0.015, 0), mat, col)
		for x: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				VehicleBody.fastener(k, parent, base + Vector3(x * plate * 0.4, 0.031, z * plate * 0.4), Vector3.UP, minf(0.014, plate * 0.03))
		foot += 0.03
	elif clamp > 0.0:
		# Two clamp halves round the bar, drawn together by four bolts.
		var block := Vector3(0.18, clamp * 2.0 + 0.04, clamp * 2.0 + 0.05)
		k._box(parent, block, base, mat, col)
		k._box(parent, Vector3(0.19, 0.01, block.z + 0.012), base, "metal_dark", null, Vector3.ZERO, false)
		for x: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				VehicleBody.fastener(k, parent, base + Vector3(x * 0.065, block.y * 0.5 + 0.001, z * block.z * 0.3), Vector3.UP, 0.01)
		foot += block.y * 0.5
	var bearing := pivot.y - 0.045
	if bearing - foot < 0.02:
		return
	var axis := Vector3(base.x, 0, base.z)
	# The post's ends are in its collar and its bearing, the collar's foot on
	# the plate.
	VehicleEquipment._cyl(k, parent, post.x, post.y, bearing - foot, axis + Vector3(0, (foot + bearing) * 0.5, 0), Vector3.ZERO, mat, col, 12, true, 0)
	VehicleEquipment._cyl(k, parent, post.y * 1.28, post.y * 1.36, 0.03, axis + Vector3(0, foot + 0.015, 0), Vector3.ZERO, mat, col, 12, false, 2)
	k._cyl(parent, post.x * 1.22, post.x * 1.22, 0.04, axis + Vector3(0, bearing - 0.02, 0), Vector3.ZERO, "metal_dark", null, 12, false)
	if plate > 0.0 and braces > 0:
		var rise := minf(0.45, (bearing - foot) * 0.65)
		var corners: Array = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)] if braces >= 4 else [Vector2(0, 1), Vector2(0, -1)]
		for c: Vector2 in corners:
			var low := axis + Vector3(c.x * plate * 0.44, foot, c.y * plate * 0.4)
			var high := axis + Vector3(0, foot + rise, 0)
			VehicleFrames.tube(k, parent, low, low.lerp(high, 0.94), 0.02, mat, col, 6)
			k._box(parent, Vector3(0.05, 0.012, 0.05), low + Vector3(0, 0.006, 0), mat, col, Vector3.ZERO, false)
	if head == null:
		return
	# The traversing head, in the turret node's own frame.
	var swivel := post.x * 1.3
	k._cyl(head, swivel, swivel, 0.08, Vector3.ZERO, Vector3.ZERO, mat, col, 12)
	k._cyl(head, swivel * 1.06, swivel * 1.06, 0.012, Vector3(0, -0.034, 0), Vector3.ZERO, "metal_dark", null, 12, false)
	VehicleFrames.tube(k, head, Vector3(swivel, 0, 0), Vector3(swivel + 0.05, 0.01, 0), 0.008, "steel", null, 6, false)
	k._add(head, Res.sphere(0.014, 8), "rubber", null, Vector3(swivel + 0.055, 0.012, 0))
	var cheek := Vector3(maxf(0.02, yoke.z * 0.28), yoke.y, yoke.z)
	k._box(head, Vector3(yoke.x * 2.0 + cheek.x, 0.03, yoke.z), Vector3(0, 0.045, 0), mat, col)
	for side: float in [-1.0, 1.0]:
		k._box(head, cheek, Vector3(side * yoke.x, 0.01 + yoke.y * 0.5, 0), mat, col)
	var pin := 0.01 + yoke.y * 0.82
	VehicleFrames.tube(k, head, Vector3(-yoke.x - cheek.x * 0.5 - 0.012, pin, 0), Vector3(yoke.x + cheek.x * 0.5 + 0.012, pin, 0), 0.02, "steel", null, 8, false)
	for side: float in [-1.0, 1.0]:
		k._cyl(head, 0.03, 0.03, 0.01, Vector3(side * (yoke.x + cheek.x * 0.5 + 0.005), pin, 0), Vector3(0, 0, PI / 2), "metal_dark", null, 10, false)
	VehicleFrames.tube(k, head, Vector3(-yoke.x - cheek.x * 0.5, pin - yoke.y * 0.35, 0), Vector3(-yoke.x - cheek.x * 0.5 - 0.04, pin - yoke.y * 0.3, 0.0), 0.007, "steel", null, 6, false)


## Gunner's shield on a traversing head, in the head's coordinates, local -Z
## toward the target: `center` the old main plate's centre, `size` its width
## and height, its face leaning back by `tilt` radians. `wing` = (depth, angle)
## hangs a side plate on each edge, swept back by the angle (positive flares
## out, negative wraps in round the gunner; zero depth for none). A sight slot
## (`slot` wide and high) over the barrel and a vision slit cut in the plate,
## a rolled top edge, hinge knuckles at the wings and two bolted arms back to
## the yoke at the head's axis.
static func gun_shield(k: VehicleModels, head: Node3D, center: Vector3, size: Vector2, mat: String, col = null, tilt := 0.08, wing := Vector2(0.32, 0.55), slot := Vector2(0.12, 0.06), thickness := 0.025) -> void:
	var m := _mount(k, head, center, Vector3(tilt, 0, 0))
	k._add(m, BevelMesh.make(Vector3(size.x, size.y, thickness), minf(0.006, thickness * 0.3)), mat, col, Vector3.ZERO)
	var face := -thickness * 0.5 - 0.003
	k._box(m, Vector3(slot.x, slot.y, 0.006), Vector3(0, -size.y * 0.06, face), "plain_dark", null, Vector3.ZERO, false)
	k._box(m, Vector3(size.x * 0.3, 0.025, 0.006), Vector3(size.x * 0.22, size.y * 0.32, face), "plain_dark", null, Vector3.ZERO, false)
	VehicleFrames.tube(k, m, Vector3(-size.x * 0.5 + 0.01, size.y * 0.5, 0), Vector3(size.x * 0.5 - 0.01, size.y * 0.5, 0), thickness * 0.55, mat, col, 6, false)
	if wing.x > 0.0:
		for side: float in [-1.0, 1.0]:
			var edge := Vector3(side * size.x * 0.5, 0, 0)
			var d := Vector3(side * sin(wing.y), 0, cos(wing.y))
			k._add(m, BevelMesh.make(Vector3(thickness, size.y * 0.92, wing.x), minf(0.006, thickness * 0.3)), mat, col, edge + d * wing.x * 0.5, Vector3(0, side * wing.y, 0))
			for y: float in [-0.3, 0.3]:
				VehicleFrames.tube(k, m, edge + Vector3(0, size.y * y - 0.035, 0), edge + Vector3(0, size.y * y + 0.035, 0), thickness * 0.6, "steel", null, 6, false)
	# The arms run from the plate's back down to the yoke at the head's axis.
	var back := Basis.from_euler(Vector3(tilt, 0, 0)).inverse()
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * size.x * 0.28, -size.y * 0.38, thickness * 0.5)
		var b: Vector3 = back * (Vector3(side * minf(0.09, size.x * 0.15), center.y - size.y * 0.36, 0) - center)
		VehicleFrames.beam(k, m, a, b, 0.025, 0.025, mat, col)
		VehicleBody.fastener(k, m, a + Vector3(side * 0.02, 0, 0.003), Vector3.BACK, 0.009)
	k._fold(m)


## Tubular weapon ring on a roll cage's roof (Dagor, Qilin): `center` the
## ring's centre and `radius` its radius in the parent's coordinates, `tube`
## the ring's tube radius. `spokes` are points on the cage the ring is braced
## out to, each stay clamped at the cage end. The traversing carriage goes on
## `carriage` (the caller's turret node, its origin at the ring's centre, or
## the parent itself when the whole ring turns with the gun; null for none):
## a bar across the ring along local X, `bar` off its centre along Z, roller
## blocks riding the ring at its ends and a seat for the gun's post in its
## middle. The post (pedestal) and gun stay with the caller.
static func ring_mount(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, tube := 0.03, mat := "gunmetal_w", col = null, spokes: Array = [], carriage: Node3D = null, bar := 0.0) -> void:
	k._add(parent, Res.torus(radius - tube, radius + tube), mat, col, center)
	for spoke: Vector3 in spokes:
		var out := Vector3(spoke.x - center.x, 0, spoke.z - center.z).normalized()
		var from := center + out * radius
		VehicleFrames.tube(k, parent, from, spoke, tube * 0.9, mat, col, 6)
		VehicleFrames.tube(k, parent, from - out * tube * 1.6, from + out * tube * 0.4, tube * 1.25, mat, col, 8, false)
		var along := (spoke - from).normalized()
		VehicleFrames.tube(k, parent, spoke - along * tube * 2.2, spoke - along * tube * 0.6, tube * 1.3, "metal_dark", null, 8, false)
	if carriage == null:
		return
	var at := center
	if carriage != parent and carriage.get_parent() == parent:
		at = carriage.transform.affine_inverse() * center
	elif carriage != parent:
		at = Vector3.ZERO
	var half := sqrt(maxf(0.0, radius * radius - bar * bar))
	var y := at.y
	VehicleFrames.tube(k, carriage, at + Vector3(-half, 0, bar), at + Vector3(half, 0, bar), tube * 0.85, mat, col, 6)
	for side: float in [-1.0, 1.0]:
		var end := at + Vector3(side * half, 0, bar)
		k._box(carriage, Vector3(tube * 2.6, tube * 3.4, tube * 4.0), end + Vector3(0, tube * 0.4, 0), mat, col)
		for e: float in [-1.0, 1.0]:
			k._cyl(carriage, tube * 0.7, tube * 0.7, tube * 2.8, end + Vector3(0, e * tube * 1.6, 0), Vector3(0, 0, PI / 2), "steel", null, 8, false)
	k._cyl(carriage, tube * 1.9, tube * 1.9, tube * 2.4, Vector3(at.x, y + tube * 0.3, at.z + bar), Vector3.ZERO, mat, col, 12)


## One explosive reactive armour brick: the old box's centre, size and
## rotation, local +Z outward. A pressed cover plate over the insert and two
## diagonal bolts. Grids and face frames stay with the family helpers.
static func era_brick(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation: Vector3, mat: String, col = null) -> void:
	var mount := _mount(k, parent, center, rotation)
	var bevel := minf(0.012, minf(size.x, size.y) * 0.06)
	k._add(mount, _bevel(Vector3(size.x, size.y, size.z * 0.8), bevel), mat, col, Vector3(0, 0, -size.z * 0.1))
	# Bricks repeat by the hundred on a tank, so the cover is a plain plate,
	# without even a chamfer: the brick's own bevel draws its outline.
	k._add(mount, VehicleEquipment._plate(Vector3(size.x * 0.9, size.y * 0.86, size.z * 0.22)), mat, col, Vector3(0, 0, size.z * 0.38))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		VehicleBody.fastener(k, mount, Vector3(corner.x * size.x * 0.36, corner.y * size.y * 0.33, size.z * 0.49 + 0.002), Vector3.BACK, minf(0.012, size.x * 0.06))
	k._fold(mount)


## Vehicle crane (a loader's knuckle-boom crane, a recovery crane, a pickup's
## davit) in the parent's coordinates, posed by the caller. Stacked up from
## `base`, its foot on the deck: the slewing ring, `ring` = (top radius,
## bottom radius, height), bolted down (zero height: none); a round king post,
## `post` the same, with its bolted foot flange and its slewing collar (zero
## height: none); the box housing that carries the boom's heel, `column` its
## size, standing on the ring or on the post (sunk 6 cm into its collar; zero:
## none), with the operator's valve bank and three levers on its outboard face
## (the side away from the centreline), standing 6 cm proud. The boom runs
## from its heel pin at `heel` to `tip`, `boom` its (width, depth) (boom). The
## luffing ram (VehicleFrames.ram) runs from `ram`[0] to `ram`[1] with radius
## `ram`[2] (empty: none), pivoting across the boom. With `hook` at the hook
## block's centre (INF: none) and `hook_size` the old block's box: the sheave
## at `sheave` (INF: the tip) across the boom, the wire rope down from it when
## the block hangs below, the block's cheek plates, pulley and pin, and the
## hook in safety yellow. A knuckle or telescoping second boom, stabiliser
## legs and boom rests stay with the caller (further boom calls).
static func crane(k: VehicleModels, parent: Node3D, base: Vector3, heel: Vector3, tip: Vector3, boom_size: Vector2, mat: String, col = null, ring := Vector3.ZERO, post := Vector3.ZERO, column := Vector3.ZERO, ram: Array = [], hook := Vector3.INF, sheave := Vector3.INF, hook_size := Vector3(0.1, 0.22, 0.12), hook_col := Color(0.62, 0.5, 0.12)) -> void:
	var axis := Vector3(base.x, 0, base.z)
	var y := base.y
	if ring.z > 0.0:
		turret_ring(k, parent, base + Vector3(0, ring.z * 0.5, 0), ring.x, ring.y, ring.z, "gunmetal_w", null, 16)
		y += ring.z
	if post.z > 0.0:
		k._cyl(parent, post.x, post.y, post.z, axis + Vector3(0, y + post.z * 0.5, 0), Vector3.ZERO, mat, col, 12)
		var flange := post.y * 1.25
		k._cyl(parent, flange, flange, 0.03, axis + Vector3(0, y + 0.015, 0), Vector3.ZERO, mat, col, 12, false)
		for i in 6:
			var a := TAU * (i + 0.5) / 6.0
			VehicleBody.fastener(k, parent, axis + Vector3(cos(a) * flange * 0.84, y + 0.031, sin(a) * flange * 0.84), Vector3.UP, minf(0.012, flange * 0.07))
		k._cyl(parent, post.x * 1.12, post.x * 1.12, 0.05, axis + Vector3(0, y + post.z - 0.04, 0), Vector3.ZERO, "metal_dark", null, 12, false)
		y += post.z - (minf(0.06, column.y * 0.25) if column.y > 0.0 else 0.0)
	if column.y > 0.0:
		var c := axis + Vector3(0, y + column.y * 0.5, 0)
		k._add(parent, BevelMesh.make(column, minf(0.02, minf(column.x, column.z) * 0.08)), mat, col, c)
		# The valve bank where the operator works the crane from beside it.
		var side := 1.0 if base.x >= 0.0 else -1.0
		var bank := Vector3(0.04, minf(0.12, column.y * 0.4), minf(0.24, column.z * 0.7))
		var at := c + Vector3(side * (column.x * 0.5 + bank.x * 0.5), -column.y * 0.2 if column.y > bank.y * 2.5 else 0.0, 0)
		k._box(parent, bank, at, "gunmetal_w")
		for i in 3:
			var lever := at + Vector3(side * 0.008, bank.y * 0.5, (i - 1) * bank.z * 0.3)
			VehicleFrames.tube(k, parent, lever, lever + Vector3(side * 0.01, 0.08, 0), 0.005, "steel", null, 6, false)
			k._add(parent, Res.sphere(0.011, 8), "rubber", null, lever + Vector3(side * 0.01, 0.085, 0))
	boom(k, parent, heel, tip, boom_size.x, boom_size.y, mat, col)
	var across := (tip - heel).cross(Vector3.UP)
	across = across.normalized() if across.length_squared() > 0.0001 else Vector3.RIGHT
	if ram.size() >= 3:
		var foot: Vector3 = ram[0]
		var end: Vector3 = ram[1]
		var radius: float = ram[2]
		VehicleFrames.ram(k, parent, foot, end, radius, "gunmetal_w", null, 0.4, across)
	if not hook.is_finite():
		return
	var s := sheave if sheave.is_finite() else tip
	var sr := clampf(boom_size.y * 0.38, 0.03, 0.1)
	var sw := boom_size.x * 0.5
	VehicleFrames.tube(k, parent, s - across * sw * 0.5, s + across * sw * 0.5, sr, "steel", null, 12, false)
	var block_top := hook.y + hook_size.y * 0.5
	if s.y - sr - block_top > 0.02:
		VehicleFrames.tube(k, parent, Vector3(hook.x, s.y - sr, hook.z), Vector3(hook.x, block_top, hook.z), 0.008, "steel", Color(0.35, 0.35, 0.33), 6, false)
	# The block: cheek plates round its pulley on a pin, the hook under it.
	var cheek := Vector3(0.012, hook_size.y * 0.55, hook_size.z)
	var mid := hook + Vector3(0, hook_size.y * 0.225, 0)
	for x: float in [-1.0, 1.0]:
		k._box(parent, cheek, mid + Vector3(x * (hook_size.x - cheek.x) * 0.5, 0, 0), "gunmetal_w")
	var pulley := minf(hook_size.z, cheek.y) * 0.38
	k._cyl(parent, pulley, pulley, hook_size.x - cheek.x * 2.0, mid, Vector3(0, 0, PI / 2), "steel", null, 10, false)
	VehicleFrames.tube(k, parent, mid - Vector3(hook_size.x * 0.5 + 0.004, 0, 0), mid + Vector3(hook_size.x * 0.5 + 0.004, 0, 0), minf(0.01, pulley * 0.3), "metal_dark", null, 6, false)
	var hr := clampf(hook_size.x * 0.12, 0.005, 0.016)
	var drop := hook_size.y * 0.45
	var bowl := minf(hook_size.z * 0.5 - hr, drop * 0.35)
	var bottom := hook.y - hook_size.y * 0.5 + hr
	var c0 := bottom + bowl
	var j := [Vector3(0, hook.y - hook_size.y * 0.04, -bowl), Vector3(0, c0, -bowl), Vector3(0, bottom, 0), Vector3(0, c0, bowl), Vector3(0, c0 + bowl * 0.7, bowl * 0.7)]
	for i in j.size():
		j[i] = Vector3(hook.x, 0, hook.z) + (j[i] as Vector3)
	VehicleFrames.path(k, parent, j, hr, "paint", hook_col, 6)


## Gun travel lock (barrel crutch) folded down on a hull's deck or glacis, in
## the parent's coordinates. On the march it stands up and clamps the barrel
## so it can't whip about; folded, its arms lie along the face from their
## hinge brackets at `foot` to the cradle at `cradle`, on the face whose
## outward normal is `normal`; both points are on the arms' centreline, and
## `cradle` is the saddle's centre (the old cradle box's), the arms ending
## under its middle. `spread` = (half the gap between the arms at the foot, at
## the cradle): two arms with a cross brace, or one arm for (0, 0). `arm` is a
## round arm's radius (`arm.y` 0) or a box arm's (width, depth). Each foot has
## a base plate bolted to the face (2 cm thick, on the face half an arm under
## the centreline), clevis lugs and its pin across; the saddle
## is `saddle` in size (width across, height out of the face, length along
## it): its base, two cheeks, a rubber pad for the barrel and the clamp strap
## shut over it with its hinge and locking pin (zero width: none). The plates
## reach an arm width and 3 cm round each foot.
## A fixed launcher rest is the same construction standing up: its posts rise
## along `normal` from the deck at `foot` to the bar's centre at `cradle`, the
## bar as the saddle, and their plates lie on the deck.
static func travel_lock(k: VehicleModels, parent: Node3D, foot: Vector3, cradle: Vector3, normal: Vector3, mat := "gunmetal_w", col = null, spread := Vector2(0.3, 0.08), arm := Vector2(0.04, 0.0), saddle := Vector3(0.36, 0.1, 0.16)) -> void:
	var n := normal.normalized()
	var run := cradle - foot
	var along := run - n * run.dot(n)
	if along.length_squared() < 0.0001:
		along = Vector3.BACK - n * n.z
	along = along.normalized()
	var m := _mount(k, parent, foot, Vector3.ZERO)
	m.basis = Basis(n.cross(along), n, along)
	var c: Vector3 = m.basis.inverse() * run
	var tubular := arm.y <= 0.0
	var w := arm.x * 2.0 if tubular else arm.x
	var half := arm.x if tubular else arm.y * 0.5
	var sides: Array[float] = [0.0]
	if spread.x > 0.0 or spread.y > 0.0:
		sides = [-1.0, 1.0]
	var ends: Array[Vector3] = []
	for s: float in sides:
		var a := Vector3(s * spread.x, 0, 0)
		var b := Vector3(c.x + s * spread.y, c.y, c.z)
		ends.append(a)
		ends.append(b)
		var d := (b - a).normalized()
		if tubular:
			VehicleFrames.tube(k, m, a, b, arm.x, mat, col, 8)
		else:
			var dx := Vector3.UP.cross(d).normalized() if absf(d.y) < 0.99 else Vector3.RIGHT
			k._box(m, Vector3(arm.x, arm.y, a.distance_to(b)), (a + b) * 0.5, mat, col, Basis(dx, d.cross(dx), d).get_euler())
		# The hinge bracket: a plate bolted to the face, lugs either side of
		# the arm's end, the pin through them. An arm lying along the face has
		# the face `half` under its centreline; a post standing off it (a
		# fixed launcher rest) stands on its plate.
		var face := -half * sqrt(maxf(0.0, 1.0 - d.y * d.y))
		var plate := w * 2.0 + 0.06
		k._box(m, Vector3(plate, 0.02, plate), a + Vector3(0, face + 0.01, 0), mat, col)
		for f: float in [-1.0, 1.0]:
			VehicleBody.fastener(k, m, a + Vector3(f * plate * 0.36, face + 0.021, f * plate * 0.36), Vector3.UP, minf(0.012, plate * 0.08))
		var lug_t := maxf(0.01, w * 0.25)
		for f: float in [-1.0, 1.0]:
			k._box(m, Vector3(lug_t, half * 2.2, w * 2.0), a + Vector3(f * (w * 0.5 + lug_t * 0.5 + 0.002), face + half * 1.1, 0), mat, col)
		var reach := w * 0.5 + lug_t + 0.012
		var pin := a + Vector3(0, face + half, 0)
		VehicleFrames.tube(k, m, pin - Vector3(reach, 0, 0), pin + Vector3(reach, 0, 0), half * 0.45, "steel", null, 8, false)
	if sides.size() == 2:
		var p := ends[0].lerp(ends[1], 0.4)
		var q := ends[2].lerp(ends[3], 0.4)
		if tubular:
			VehicleFrames.tube(k, m, p, q, arm.x * 0.8, mat, col, 8, false)
		else:
			k._box(m, Vector3(p.distance_to(q), arm.y * 0.8, arm.x * 0.8), (p + q) * 0.5, mat, col)
	if saddle.x > 0.0:
		var sx := saddle.x
		var sy := saddle.y
		var sz := saddle.z
		k._box(m, Vector3(sx, sy * 0.3, sz), c + Vector3(0, -sy * 0.35, 0), mat, col)
		for f: float in [-1.0, 1.0]:
			k._box(m, Vector3(sx * 0.16, sy, sz), c + Vector3(f * sx * 0.42, 0, 0), mat, col)
		k._box(m, Vector3(sx * 0.66, 0.012, sz * 0.9), c + Vector3(0, -sy * 0.2 + 0.006, 0), "rubber", null, Vector3.ZERO, false)
		# The clamp strap, shut, hinged on one cheek and pinned to the other.
		k._box(m, Vector3(sx * 0.86, 0.012, sz * 0.5), c + Vector3(0, sy * 0.5 - 0.006, 0), mat, col, Vector3.ZERO, false)
		VehicleFrames.tube(k, m, c + Vector3(-sx * 0.42, sy * 0.5, -sz * 0.27), c + Vector3(-sx * 0.42, sy * 0.5, sz * 0.27), 0.012, mat, col, 8, false)
		VehicleFrames.tube(k, m, c + Vector3(sx * 0.42, sy * 0.5, -sz * 0.36), c + Vector3(sx * 0.42, sy * 0.5, sz * 0.36), 0.008, "steel", null, 6, false)
	k._fold(m)


## Pintle mount for a commander's or loader's machine gun on a cupola, hatch
## ring or roof, in the parent's coordinates: the socket welded at `base` (on
## the face the post stands on) with its bolted flange, the tapered post
## (`post` = top, bottom radius) up to the swivel, and on it the cradle under
## `receiver`, the gun's receiver centre as the family passes it to
## VehicleWeapons.hmg / mmg: the tray under the receiver and the cheeks either
## side of it (`gun` = the receiver's width and height; the hmg's is 0.16 x
## 0.19 and the mmg's 0.08 x 0.13 at size 1), the trunnion pin across them, and
## the elevation lock's T-handle under the tray's back. The cradle sits over
## the post, squared to `forward` (the gun's direction); the gun, its muzzle
## marker and its ammunition stay with the family.
static func pintle(k: VehicleModels, parent: Node3D, base: Vector3, receiver: Vector3, mat := "gunmetal_w", col = null, post := Vector2(0.03, 0.04), gun := Vector2(0.16, 0.19), forward := Vector3.FORWARD) -> void:
	var f := Vector3(forward.x, 0, forward.z)
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	var m := _mount(k, parent, base, Vector3.ZERO)
	m.basis = Basis.looking_at(f, Vector3.UP)
	var r: Vector3 = m.basis.inverse() * (receiver - base)
	var tray := 0.018
	var swivel := 0.035
	var tray_top := r.y - gun.y * 0.5
	var top := tray_top - tray - swivel
	var flange := post.y * 1.6
	# The flange lies on the face; the post's ends are in the flange and the
	# swivel.
	VehicleEquipment._cyl(k, m, flange, flange, 0.015, Vector3(0, 0.0075, 0), Vector3.ZERO, mat, col, 10, false, 2)
	for i in 3:
		var a := TAU * (i + 0.25) / 3.0
		VehicleBody.fastener(k, m, Vector3(cos(a) * flange * 0.78, 0.0155, sin(a) * flange * 0.78), Vector3.UP, minf(0.009, flange * 0.12))
	if top > 0.03:
		VehicleEquipment._cyl(k, m, post.x, post.y, top - 0.015, Vector3(0, (top + 0.015) * 0.5, 0), Vector3.ZERO, mat, col, 10, true, 0)
	VehicleEquipment._cyl(k, m, post.x * 1.4, post.x * 1.4, swivel, Vector3(0, top + swivel * 0.5, 0), Vector3.ZERO, "metal_dark", null, 10)
	# The cradle: the tray, a cheek either side of the receiver, the trunnion.
	var ct := maxf(0.008, gun.x * 0.08)
	var span := gun.x + ct * 2.0
	var length := clampf(gun.y * 0.9, 0.08, 0.18)
	k._box(m, Vector3(span, tray, length), Vector3(r.x, tray_top - tray * 0.5, 0), mat, col)
	for side: float in [-1.0, 1.0]:
		k._box(m, Vector3(ct, gun.y * 0.45, length * 0.8), Vector3(r.x + side * (gun.x + ct) * 0.5, tray_top + gun.y * 0.225 - 0.002, 0), mat, col)
	var pin := Vector3(r.x, tray_top + gun.y * 0.3, 0)
	VehicleFrames.tube(k, m, pin - Vector3(span * 0.5 + 0.008, 0, 0), pin + Vector3(span * 0.5 + 0.008, 0, 0), ct * 0.7, "steel", null, 8, false)
	for side: float in [-1.0, 1.0]:
		k._cyl(m, ct * 1.3, ct * 1.3, 0.006, pin + Vector3(side * (span * 0.5 + 0.005), 0, 0), Vector3(0, 0, PI / 2), "metal_dark", null, 8, false)
	# The elevation lock: a screw clamp under the tray's back, its T-handle.
	var lock := Vector3(r.x, tray_top - tray, length * 0.4)
	VehicleFrames.tube(k, m, lock, lock + Vector3(0, -0.03, 0.012), ct * 0.45, "steel", null, 6, false)
	VehicleFrames.tube(k, m, lock + Vector3(-0.025, -0.03, 0.012), lock + Vector3(0.025, -0.03, 0.012), ct * 0.4, "steel", null, 6, false)
	k._fold(m)


## Amphibious trim vane folded flat on a bow plate or glacis, in the parent's
## coordinates. Raised before the vehicle swims, it stops the bow wave coming
## over the nose. `hinge` is the middle of its hinged lower edge and `top` the
## middle of its free edge, both on the face under it (the old plate's inner
## face); `width` runs across it, square to hinge and top, and `thickness`
## stands out of the face along `normal`, the face's outward normal. The thin
## sheet, its flanged rim and `ribs` stiffeners spaced evenly across it,
## running up from the hinge (they carry the water's push on the raised vane),
## all within the old plate's thickness; `hinges` knuckle hinges along its
## lower edge, their straps reaching 1.1 thicknesses either side of it; and
## the two latches on the face above its top corners that hold it folded,
## reaching 6 cm past `top` and standing half a thickness proud of the vane.
static func trim_vane(k: VehicleModels, parent: Node3D, hinge: Vector3, top: Vector3, width: float, thickness: float, normal: Vector3, mat: String, col = null, ribs := 2, hinges := 2) -> void:
	var length := hinge.distance_to(top)
	if length < 0.05:
		return
	var y := (top - hinge) / length
	var z := normal - y * normal.dot(y)
	if z.length_squared() < 0.0001:
		return
	z = z.normalized()
	var m := _mount(k, parent, hinge, Vector3.ZERO)
	m.basis = Basis(y.cross(z), y, z)
	var t := thickness
	var sheet := t * 0.45
	k._add(m, BevelMesh.make(Vector3(width, length, sheet), minf(0.006, sheet * 0.3)), mat, col, Vector3(0, length * 0.5, sheet * 0.5))
	var rim := clampf(width * 0.03, 0.025, 0.05)
	for e: float in [rim * 0.5, length - rim * 0.5]:
		k._box(m, Vector3(width, rim, t), Vector3(0, e, t * 0.5), mat, col)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(rim, length - rim * 2.0, t), Vector3(s * (width - rim) * 0.5, length * 0.5, t * 0.5), mat, col)
	for i in ribs:
		var rx := width * ((i + 1.0) / (ribs + 1.0) - 0.5)
		k._box(m, Vector3(minf(0.05, width * 0.04), length - rim * 2.0, t * 0.85), Vector3(rx, length * 0.5, t * 0.425), mat, col, Vector3.ZERO, false)
	for i in hinges:
		var hx := 0.0 if hinges == 1 else lerpf(-width * 0.4, width * 0.4, float(i) / (hinges - 1))
		VehicleDoors.hinge(k, m, Vector3(hx, 0, 0), Vector3.BACK, Vector3.RIGHT, t * 0.5, mat, col)
	for s: float in [-1.0, 1.0]:
		var at := Vector3(s * (width * 0.5 - 0.08), length + 0.02, t * 0.75)
		k._box(m, Vector3(0.06, 0.08, t * 1.5), at, "gunmetal_w")
		VehicleFrames.tube(k, m, at + Vector3(-0.04, 0.01, t * 0.75 + 0.008), at + Vector3(0.04, 0.01, t * 0.75 + 0.008), 0.008, "steel", null, 6, false)
	k._fold(m)
