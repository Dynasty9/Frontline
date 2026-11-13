class_name VehicleWeapons
extends RefCounted
## Gun construction shared by every family. Callers pass the points the old
## geometry used (the receiver's centre, the breech, the muzzle), so gameplay
## muzzle markers, turret pivots and recoil parents stay exactly where they
## were; these builders own what lies between those points. Each gun lays
## itself along the line toward its muzzle, folds into the supplied parent and
## returns the muzzle it was given. `muzzle` is where the gun's own geometry
## ends (the flash hider, brake or barrel faces); a family's muzzle marker may
## stand a few centimetres ahead of it and keeps its own position.

const X90 := Vector3(PI / 2, 0, 0)

## A pivot at `from` whose local -Z runs toward `to`.
static func _aimed(k: VehicleModels, parent: Node3D, from: Vector3, to: Vector3) -> Node3D:
	var mount := k._pivot(parent, from)
	var direction := to - from
	if direction.length_squared() > 0.000001:
		var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.BACK
		mount.basis = Basis.looking_at(direction, up)
	return mount

## A round section along local Z from `rear` back to `front` (front < rear,
## both metres along the gun's axis, -Z forward), centred on `at` across it.
## `rear_cap` and `front_cap` close its ends: a section whose end is inside
## the receiver, a jacket or the next section leaves it open.
static func _z(k: VehicleModels, m: Node3D, rear: float, front: float, rear_r: float, front_r: float, mat: String, col = null, segments := 10, shadow := true, at := Vector2.ZERO, rear_cap := true, front_cap := true) -> void:
	if rear - front < 0.0005:
		return
	VehicleBody.cylinder(k, m, rear_r, front_r, rear - front, Vector3(at.x, at.y, (rear + front) * 0.5), X90, mat, col, segments, shadow, rear_cap, front_cap)

## The dark mouth of a bore, just proud of the face it sits in (its back is
## in that face). It is the near-black of the barrel builder's bore, not a
## painted dark grey: the sun lights a dark paint to a grey disc, and the
## muzzle must read as a hole.
static func _bore(k: VehicleModels, m: Node3D, z: float, radius: float, at := Vector2.ZERO) -> void:
	VehicleBody.cylinder(k, m, radius, radius, 0.004, Vector3(at.x, at.y, z - 0.0015), X90, "burnt", Color(0.018, 0.019, 0.018), 12, false, false, true)


## The barrel's crown standing in a brake's front face: the worn metal lip the
## bore is cut through, as the barrel builder draws it, so a closed brake face
## still reads as an open muzzle from the camera.
static func _crown(k: VehicleModels, m: Node3D, z: float, radius: float) -> void:
	k._add(m, VehicleFittings._ring(radius * 0.62, radius * 1.02), "gunmetal", Color(0.29, 0.30, 0.28), Vector3(0, 0, z), X90, Vector3(1, 0.3, 1))
	_bore(k, m, z, radius * 0.62)

## Coaxial machine-gun port: the old cylinder's centre, length and radius, along
## -Z. A port sleeve, the barrel, a slotted flash hider and its bore. The
## caller keeps its own muzzle marker, so the coax tracer still leaves the same
## point.
static func coax(k: VehicleModels, parent: Node3D, center: Vector3, length: float, radius := 0.022, mat := "gunmetal_w") -> void:
	var m := k._pivot(parent, center)
	var half := length * 0.5
	var hider := minf(0.06, length * 0.22)
	var sleeve := minf(0.06, length * 0.24)
	_z(k, m, half, half - sleeve, radius * 1.9, radius * 1.9, "metal_dark", null, 8, false)
	_z(k, m, half - sleeve, -half + hider, radius, radius, mat, null, 6, false, Vector2.ZERO, false, false)
	_z(k, m, -half + hider, -half, radius * 1.28, radius * 1.15, mat, null, 6, false)
	_bore(k, m, -half, radius * 0.55)
	k._fold(m)


## Automatic cannon between its breech (the back of the recoil sleeve) and its
## muzzle (the brake's front face). `root` is the sleeve's (radius, length),
## `barrel` the tube's (rear, front) radii, `brake` the muzzle brake's (radius,
## length). `bands` adds evenly spaced clamp bands along the tube.
static func autocannon(k: VehicleModels, parent: Node3D, breech: Vector3, muzzle: Vector3, root: Vector2, barrel: Vector2, brake: Vector2, mat := "gunmetal_w", col = null, bands := 0) -> Vector3:
	var m := _aimed(k, parent, breech, muzzle)
	var length := breech.distance_to(muzzle)
	var root_end := -minf(root.y, length * 0.5)
	var brake_start := -length + minf(brake.y, length * 0.3)
	# The recoil sleeve, with a collar where the barrel leaves it.
	_z(k, m, 0.0, root_end, root.x, root.x, mat, col, 12)
	_z(k, m, root_end + 0.015, root_end - 0.02, root.x * 0.82, root.x * 0.82, "metal_dark", null, 12, false, Vector2.ZERO, false)
	# (the tube's ends are in the collar and the brake)
	_z(k, m, root_end + 0.01, brake_start - 0.01, barrel.x, barrel.y, mat, col, 10, true, Vector2.ZERO, false, false)
	for i in bands:
		var z := lerpf(root_end, brake_start, (i + 1.0) / (bands + 1.0))
		var r := lerpf(barrel.x, barrel.y, (i + 1.0) / (bands + 1.0))
		_z(k, m, z + 0.015, z - 0.015, r * 1.35, r * 1.35, "metal_dark", null, 10, false)
	# Muzzle brake: a body with two rows of dark side ports and a front lip.
	_z(k, m, brake_start, -length, brake.x, brake.x * 0.94, "gunmetal_w", null, 10)
	for f: float in [0.3, 0.62]:
		var z := lerpf(brake_start, -length, f)
		# (a port band stands only 1 % proud: its ends are not worth a face)
		_z(k, m, z + brake.y * 0.07, z - brake.y * 0.07, brake.x * 1.01, brake.x * 1.01, "plain_dark", null, 10, false, Vector2.ZERO, false, false)
	_bore(k, m, -length, barrel.y * 0.75)
	k._fold(m)
	return muzzle


## Heavy machine gun (.50 / 12.7 mm pattern) from the receiver's centre to the
## muzzle. `size` scales the cross-sections; `can` puts the ammunition can on
## the left (-1) or right (+1), 0 for none; `grips` adds spade grips and the
## butterfly trigger for crew-served mounts. Returns the muzzle.
static func hmg(k: VehicleModels, parent: Node3D, receiver: Vector3, muzzle: Vector3, size := 1.0, can := -1.0, grips := false, mat := "gunmetal_w", can_col := Color(0.29, 0.31, 0.22)) -> Vector3:
	var m := _aimed(k, parent, receiver, muzzle)
	var s := size
	var length := receiver.distance_to(muzzle)
	VehicleMounts.receiver(k, m, Vector3(0.16, 0.19, 0.62) * s, Vector3.ZERO, mat)
	k._add(m, BevelMesh.make(Vector3(0.17, 0.035, 0.42) * s, 0.008 * s), mat, null, Vector3(0, 0.11, -0.02) * s)
	k._box(m, Vector3(0.02, 0.05, 0.03) * s, Vector3(0, 0.15, 0.18) * s, mat, null, Vector3.ZERO, false)
	k._box(m, Vector3(0.15, 0.16, 0.03) * s, Vector3(0, 0, 0.325) * s, mat)
	if grips:
		for side: float in [-1.0, 1.0]:
			VehicleBody.rod(k, m, Vector3(side * 0.05, 0.03, 0.335) * s, Vector3(side * 0.075, 0.03, 0.39) * s, 0.012 * s, mat, null, 6, false, -1.0, false, false)
			VehicleBody.cylinder(k, m, 0.02 * s, 0.02 * s, 0.14 * s, Vector3(side * 0.075, 0.03, 0.4) * s, Vector3.ZERO, "rubber", null, 6, false)
		k._box(m, Vector3(0.07, 0.025, 0.02) * s, Vector3(0, 0.03, 0.37) * s, mat, null, Vector3.ZERO, false)
	# The perforated barrel support, its carrying handle, the barrel and hider.
	var jacket := -0.31 * s
	var jacket_end := maxf(-0.57 * s, -length + 0.2 * s)
	_z(k, m, jacket, jacket_end, 0.046 * s, 0.046 * s, mat, null, 10, true, Vector2.ZERO, false)
	for i in 3:
		var z := lerpf(jacket, jacket_end, (i + 1) / 4.0)
		_z(k, m, z + 0.011 * s, z - 0.011 * s, 0.051 * s, 0.051 * s, "metal_dark", null, 10, false)
	VehicleDoors.pull(k, m, Vector3(0, 0.046 * s, (jacket + jacket_end) * 0.5), Vector3.UP, Vector3.FORWARD, 0.11 * s, 0.008 * s, mat)
	_z(k, m, jacket_end, -length + 0.12 * s, 0.028 * s, 0.026 * s, mat, null, 8, true, Vector2.ZERO, false, false)
	k._box(m, Vector3(0.012, 0.045, 0.02) * s, Vector3(0, 0.045 * s, -length + 0.17 * s), mat, null, Vector3.ZERO, false)
	_z(k, m, -length + 0.12 * s, -length, 0.044 * s, 0.032 * s, mat, null, 8, false)
	_bore(k, m, -length, 0.014 * s)
	if can != 0.0:
		var side := signf(can)
		VehicleFittings.ammo_can(k, m, Vector3(side * 0.18, -0.07, 0.08) * s, can_col, Vector3.ZERO, Vector3(0.12, 0.19, 0.29) * s)
		# The belt rises from the can's mouth into the feed tray.
		VehicleFrames.beam(k, m, Vector3(side * 0.15, 0.04, 0.06) * s, Vector3(side * 0.085, 0.07, 0.04) * s, 0.06 * s, 0.012 * s, "paint", Color(0.62, 0.5, 0.24), false)
	k._fold(m)
	return muzzle


## General-purpose machine gun (7.62 mm, M240 / PKT pattern). `stock` adds the
## butt and pistol grip of a pintle gun; coaxial and remote mounts omit it.
static func mmg(k: VehicleModels, parent: Node3D, receiver: Vector3, muzzle: Vector3, size := 1.0, can := -1.0, stock := true, mat := "gunmetal_w", can_col := Color(0.29, 0.31, 0.22)) -> Vector3:
	var m := _aimed(k, parent, receiver, muzzle)
	var s := size
	var length := receiver.distance_to(muzzle)
	VehicleMounts.receiver(k, m, Vector3(0.08, 0.13, 0.42) * s, Vector3.ZERO, mat)
	k._add(m, BevelMesh.make(Vector3(0.09, 0.03, 0.26) * s, 0.006 * s), mat, null, Vector3(0, 0.075, -0.02) * s)
	if stock:
		k._add(m, BevelMesh.make(Vector3(0.05, 0.1, 0.24) * s, 0.01 * s), mat, null, Vector3(0, -0.01, 0.32) * s)
		k._box(m, Vector3(0.035, 0.1, 0.045) * s, Vector3(0, -0.1, 0.12) * s, mat, null, Vector3(-0.3, 0, 0), false)
	var trunnion := maxf(-0.39 * s, -length + 0.12 * s)
	_z(k, m, -0.21 * s, trunnion, 0.03 * s, 0.03 * s, mat, null, 8, true, Vector2.ZERO, false)
	VehicleBody.rod(k, m, Vector3(0, -0.035, -0.22) * s, Vector3(0, -0.035 * s, minf(trunnion - 0.1 * s, -length * 0.55)), 0.011 * s, mat, null, 6, false, -1.0, false)
	VehicleDoors.pull(k, m, Vector3(0, 0.03, -0.3) * s, Vector3.UP, Vector3.FORWARD, 0.09 * s, 0.006 * s, mat)
	_z(k, m, trunnion, -length + 0.07 * s, 0.016 * s, 0.016 * s, mat, null, 6, false, Vector2.ZERO, false, false)
	_z(k, m, -length + 0.07 * s, -length, 0.022 * s, 0.018 * s, mat, null, 6, false)
	_bore(k, m, -length, 0.009 * s)
	if can != 0.0:
		VehicleFittings.ammo_can(k, m, Vector3(signf(can) * 0.08, -0.07, 0.02) * s, can_col, Vector3.ZERO, Vector3(0.08, 0.13, 0.15) * s)
	k._fold(m)
	return muzzle


## Automatic grenade launcher (40 mm). `feed` puts the linked-round container on
## the left (-1) or right (+1), 0 for none; `drum` chooses the round drum over
## a box, and `feed_offset` is its centre's distance from the gun's axis, so a
## box clears the mount's yoke arms. Returns the muzzle.
static func gmg(k: VehicleModels, parent: Node3D, receiver: Vector3, muzzle: Vector3, size := 1.0, feed := 1.0, drum := true, mat := "gunmetal_w", feed_col := Color(0.29, 0.31, 0.22), feed_offset := 0.24) -> Vector3:
	var m := _aimed(k, parent, receiver, muzzle)
	var s := size
	var length := receiver.distance_to(muzzle)
	VehicleMounts.receiver(k, m, Vector3(0.24, 0.24, 0.62) * s, Vector3.ZERO, mat)
	k._add(m, BevelMesh.make(Vector3(0.18, 0.08, 0.32) * s, 0.012 * s), mat, null, Vector3(0, 0.15, 0.05) * s)
	k._box(m, Vector3(0.2, 0.14, 0.03) * s, Vector3(0, 0, 0.325) * s, mat)
	for side: float in [-1.0, 1.0]:
		VehicleBody.cylinder(k, m, 0.02 * s, 0.02 * s, 0.13 * s, Vector3(side * 0.07, 0, 0.37) * s, Vector3.ZERO, "rubber", null, 6, false)
	var jacket_end := maxf(-0.66 * s, -length + 0.16 * s)
	_z(k, m, -0.3 * s, jacket_end, 0.075 * s, 0.075 * s, mat, null, 10, true, Vector2.ZERO, false)
	for i in 3:
		var z := lerpf(-0.3 * s, jacket_end, (i + 1) / 4.0)
		_z(k, m, z + 0.01 * s, z - 0.01 * s, 0.078 * s, 0.078 * s, "metal_dark", null, 10, false)
	_z(k, m, jacket_end, -length + 0.08 * s, 0.05 * s, 0.05 * s, mat, null, 8, true, Vector2.ZERO, false, false)
	_z(k, m, -length + 0.08 * s, -length, 0.062 * s, 0.06 * s, mat, null, 8, false)
	_bore(k, m, -length, 0.04 * s)
	if feed != 0.0:
		var side := signf(feed)
		if drum:
			VehicleBody.cylinder(k, m, 0.19 * s, 0.19 * s, 0.16 * s, Vector3(side * feed_offset, -0.04, 0.05) * s, Vector3(0, 0, PI / 2), "paint", feed_col, 14)
			VehicleBody.cylinder(k, m, 0.06 * s, 0.06 * s, 0.17 * s, Vector3(side * feed_offset, -0.04, 0.05) * s, Vector3(0, 0, PI / 2), "metal_dark", null, 10, false)
		else:
			VehicleFittings.ammo_can(k, m, Vector3(side * feed_offset, -0.02, 0.04) * s, feed_col, Vector3.ZERO, Vector3(0.22, 0.26, 0.36) * s)
		# The feed chute bridges the gap from the container's face to the receiver.
		var inner := 0.11
		var outer := maxf(inner, feed_offset - (0.08 if drum else 0.11))
		k._box(m, Vector3(outer - inner + 0.04, 0.08, 0.12) * s, Vector3(side * (inner + outer) * 0.5, 0.05, 0.0) * s, mat)
	k._fold(m)
	return muzzle


## Rotary barrel cluster from its rear carrier to the muzzles: `barrels` tubes
## on `cluster` radius round a spindle, with clamps at the given fractions of
## the length. Housings, motors and feed chutes stay with the aircraft or mount
## that carries them. Returns the muzzle.
static func rotary(k: VehicleModels, parent: Node3D, rear: Vector3, muzzle: Vector3, barrels: int, cluster: float, barrel_radius: float, clamps: Array = [0.55, 0.92], mat := "gunmetal_w", phase := 0.0) -> Vector3:
	var m := _aimed(k, parent, rear, muzzle)
	var length := rear.distance_to(muzzle)
	var clamp_r := cluster + barrel_radius * 1.6
	_z(k, m, 0.0, -length * 0.96, cluster * 0.42, cluster * 0.42, "metal_dark", null, 10, false, Vector2.ZERO, false)
	_z(k, m, 0.02, -minf(length * 0.06, 0.08), clamp_r, clamp_r, mat, null, 14)
	for i in barrels:
		var a := TAU * float(i) / barrels + phase
		var at := Vector2(cos(a), sin(a)) * cluster
		_z(k, m, 0.0, -length, barrel_radius, barrel_radius * 0.9, mat, null, 6, false, at, false)
		_bore(k, m, -length, barrel_radius * 0.5, at)
	for f: float in clamps:
		var z := -length * f
		var half := maxf(0.015, length * 0.025)
		_z(k, m, z + half, z - half, clamp_r, clamp_r, mat, null, 14, false)
	k._fold(m)
	return muzzle


## Box launcher (TOW, Kornet, Stinger and Igla boxes): the old box's centre,
## size and rotation, local -Z forward. `rows` x `cols` launch tubes open in
## its front face, each `mouth` in outer radius (shrunk to fit its cell);
## `spacing` is the distance between neighbouring mouths, zero spreading them
## evenly over the face. The face's bezel and mouths (see missile_face), the
## tubes' rear blast seals in a rear cover, two clamp bands, two mounting lugs
## with their pins on the face toward `mount` (a local axis: the box's arm or
## bracket side) and the firing umbilical's connector there near the back.
## The box keeps within its old size but for the lugs and connector, which
## stand at most 5 cm off the mounting face, and covers 7 mm proud of the
## front. Arms, elevation pivots and the launch marker stay with the caller.
static func missile_box(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rows: int, cols: int, mouth: float, mat := "paint", col = null, rotation := Vector3.ZERO, covers := false, mount := Vector3.DOWN, spacing := Vector2.ZERO) -> void:
	var m := k._pivot(parent, center)
	m.rotation = rotation
	var lip := minf(0.03, minf(size.x, size.y) * 0.08)
	# The face's collars stand up to the old front, the rear seals to its back.
	var front := 0.014
	var back := size.z * 0.5 - 0.014
	k._add(m, BevelMesh.make(Vector3(size.x, size.y, size.z - front - 0.014), minf(0.012, minf(size.x, size.y) * 0.05)), mat, col, Vector3(0, 0, (front - 0.014) * 0.5))
	missile_face(k, m, Vector3(0, 0, -size.z * 0.5 + front), Vector2(size.x, size.y), rows, cols, mouth, mat, col, Vector3.ZERO, covers, spacing)
	# The rear cover over the tubes' ends, a blast seal behind each.
	k._box(m, Vector3(size.x - lip * 2.0, size.y - lip * 2.0, 0.008), Vector3(0, 0, back + 0.004), mat, col, Vector3.ZERO, false)
	var pitch := _pitch(Vector2(size.x, size.y), rows, cols, spacing)
	var r := _mouth(pitch, mouth)
	for i in rows:
		for j in cols:
			var at := Vector2((j - (cols - 1) * 0.5) * pitch.x, ((rows - 1) * 0.5 - i) * pitch.y)
			VehicleBody.cylinder(k, m, r * 0.7, r * 0.7, 0.006, Vector3(at.x, at.y, back + 0.011), X90, "plain_dark", null, 8, false, true, false)
	# Clamp bands round the box, a darker shade of it.
	var band_col: Variant = (col as Color).darkened(0.12) if col is Color else null
	for f: float in [-0.22, 0.28]:
		k._add(m, BevelMesh.make(Vector3(size.x + 0.008, size.y + 0.008, minf(0.05, size.z * 0.06)), 0.003), mat, band_col, Vector3(0, 0, size.z * f))
	# Mounting lugs on the bracket face, pinned across; the umbilical behind.
	var axis := mount.abs().max_axis_index()
	var out := Vector3.ZERO
	out[axis] = 1.0 if mount[axis] >= 0.0 else -1.0
	var face := absf(size[axis]) * 0.5
	var across := out.cross(Vector3.BACK)
	var lug := Vector3(0.05, 0.05, minf(0.09, size.z * 0.12))
	lug[axis] = 0.035
	for f: float in [-0.25, 0.25]:
		var at := out * (face + 0.0175) + Vector3(0, 0, size.z * f)
		k._box(m, lug, at, "gunmetal_w")
		VehicleBody.rod(k, m, at - across * 0.035 + out * 0.004, at + across * 0.035 + out * 0.004, 0.011, "steel", null, 6, false)
	var plug := out * (face + 0.015) + across * minf(0.06, absf(across.dot(size)) * 0.3) + Vector3(0, 0, size.z * 0.5 - 0.07)
	var plug_size := Vector3(0.05, 0.05, 0.06)
	plug_size[axis] = 0.03
	k._box(m, plug_size, plug, "metal_dark", null, Vector3.ZERO, false)
	VehicleBody.rod(k, m, plug + out * 0.012, plug + out * 0.025 + Vector3(0, 0, 0.03), 0.009, "rubber", null, 6, false, -1.0, false)
	k._fold(m)


## The front of a box launcher or rocket pod: `center` is the face's centre on
## the surface the tubes open in, local -Z out of it, `size` its width and
## height. A raised bezel round its edge; in each of the `rows` x `cols` mouths
## (laid out as for missile_box) the tube's end collar standing proud round a
## dark bore, or round a frangible cover when `covers` is set. `plate` adds a
## pod end plate that thick behind the face, so a pod's face stands proud of
## the box it is mounted in.
static func missile_face(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rows: int, cols: int, mouth: float, mat := "paint", col = null, rotation := Vector3.ZERO, covers := false, spacing := Vector2.ZERO, plate := 0.0) -> void:
	var m := k._pivot(parent, center)
	m.rotation = rotation
	var lip := minf(0.03, minf(size.x, size.y) * 0.08)
	if plate > 0.0:
		k._add(m, BevelMesh.make(Vector3(size.x, size.y, plate), minf(0.008, plate * 0.25)), "gunmetal_w", null, Vector3(0, 0, plate * 0.5))
	for side: float in [-1.0, 1.0]:
		k._box(m, Vector3(size.x, lip, 0.012), Vector3(0, side * (size.y - lip) * 0.5, -0.006), mat, col, Vector3.ZERO, false)
		k._box(m, Vector3(lip, size.y - lip * 2.0, 0.012), Vector3(side * (size.x - lip) * 0.5, 0, -0.006), mat, col, Vector3.ZERO, false)
	var pitch := _pitch(size, rows, cols, spacing)
	var r := _mouth(pitch, mouth)
	for i in rows:
		for j in cols:
			var at := Vector2((j - (cols - 1) * 0.5) * pitch.x, ((rows - 1) * 0.5 - i) * pitch.y)
			_z(k, m, 0.0, -0.014, r, r, "metal_dark", null, 12, false, at, false)
			if covers:
				# A frangible cover, domed a little, scored to burst on launch.
				VehicleBody.cylinder(k, m, r * 0.62, r * 0.86, 0.012, Vector3(at.x, at.y, -0.0115), -X90, "rubber", null, 12, false, true, false)
				k._box(m, Vector3(r * 1.3, 0.004, 0.004), Vector3(at.x, at.y, -0.0185), "plain_dark", null, Vector3.ZERO, false)
			else:
				_bore(k, m, -0.0115, r * 0.8, at)
	k._fold(m)


## Distance between neighbouring mouths: `spacing`, or the face shared evenly.
static func _pitch(size: Vector2, rows: int, cols: int, spacing: Vector2) -> Vector2:
	var pitch := Vector2(size.x / maxi(1, cols), size.y / maxi(1, rows))
	if spacing.x > 0.0:
		pitch.x = spacing.x
	if spacing.y > 0.0:
		pitch.y = spacing.y
	return pitch


## A mouth's outer radius, kept inside its cell so neighbours never merge.
static func _mouth(pitch: Vector2, mouth: float) -> float:
	return minf(mouth, minf(pitch.x, pitch.y) * 0.46)


## Missile launch tube along local Z (the old cylinder's centre, radius and
## length): fitted end collars, a frangible front cover, clamp bands and the
## firing umbilical. `collar_col` defaults to a darker shade of the tube.
## `forward` is the way its mouth (the front cover) looks, -Z by default; a
## tube angled out of its mount (the Afghanit's) passes its own, and `up`
## the side its umbilical runs along (squared to the tube).
static func launch_tube(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, mat := "paint", col = null, collar_col = null, forward := Vector3.FORWARD, up := Vector3.UP) -> void:
	var aimed := not forward.normalized().is_equal_approx(Vector3.FORWARD) or not up.normalized().is_equal_approx(Vector3.UP)
	var m := _framed(k, parent, center, center + forward, up) if aimed else k._pivot(parent, center)
	var half := length * 0.5
	var cc: Variant = collar_col
	if cc == null and col is Color:
		cc = (col as Color).darkened(0.15)
	var collar := minf(0.1, length * 0.08)
	# The tube's ends are inside its collars, and each collar's end face under
	# its end ring's (they were coincident): those faces are left open.
	_z(k, m, half - collar * 0.5, -half + collar * 0.5, radius, radius, mat, col, 12, true, Vector2.ZERO, false, false)
	for end: float in [-1.0, 1.0]:
		var outer := end * half
		_z(k, m, maxf(outer, outer - end * collar), minf(outer, outer - end * collar), radius * 1.18, radius * 1.18, mat, cc, 12, true, Vector2.ZERO, end < 0.0, end > 0.0)
		_z(k, m, maxf(outer, outer - end * collar * 0.35), minf(outer, outer - end * collar * 0.35), radius * 1.24, radius * 1.24, "metal_dark", null, 12, false)
	# The domed front cover blows out on launch; the rear one is a blast seal.
	# Their inner faces are inside the tube's mouth.
	VehicleBody.cylinder(k, m, radius * 0.98, radius * 0.92, 0.014, Vector3(0, 0, -half - 0.006), X90, "rubber", null, 12, false, false, true)
	VehicleBody.cylinder(k, m, radius * 0.7, radius * 0.7, 0.008, Vector3(0, 0, half + 0.004), X90, "plain_dark", null, 10, false, true, false)
	for z: float in [-length * 0.2, length * 0.2]:
		_z(k, m, z + 0.018, z - 0.018, radius * 1.04, radius * 1.04, "metal_dark", null, 12, false)
	k._box(m, Vector3(radius * 0.45, radius * 0.28, minf(0.12, length * 0.1)), Vector3(0, radius * 1.08, half * 0.5), "metal_dark")
	k._fold(m)


## A pivot at `from` whose local -Z runs toward `to` and whose +Y leans toward
## `up` (squared up to the axis).
static func _framed(k: VehicleModels, parent: Node3D, from: Vector3, to: Vector3, up: Vector3) -> Node3D:
	var mount := k._pivot(parent, from)
	var direction := to - from
	if direction.length_squared() > 0.000001:
		var d := direction.normalized()
		var u := up - d * up.dot(d)
		if u.length_squared() < 0.000001:
			u = Vector3.BACK if absf(d.y) > 0.99 else Vector3.UP
		mount.basis = Basis.looking_at(d, u.normalized())
	return mount


## Main-gun muzzle brake, from `rear`, where its sleeve screws onto the tube,
## to `front`, its front face (where the old rings, block or tube ended), along
## any axis; `up` is the way its top wall faces. `size` is the body's width and
## height across the bore: a round brake's baffles are `size.y` across, and a
## width beyond that adds the flat side plates that frame its windows (the
## 2S19 pattern). `tube` is the barrel's radius under the sleeve (0: 0.31 of
## the height). The propellant gas leaving the bore strikes each baffle and
## turns out through the windows on either side, pulling the gun forward
## against its recoil, so the baffles' rear faces inside the windows are
## soot-black. Styles:
## - "double": the self-propelled howitzer's double-baffle brake: a threaded
##   sleeve with its lock ring and key, two round baffles held by a top and a
##   bottom wall, a window each side ahead of the sleeve and between them.
## - "single": one baffle and one pair of windows ahead of a longer sleeve.
## - "box": the light howitzer's box-section double baffle (M102): a rear
##   block clamped on with two bolts, a middle and a front baffle, the same
##   windows.
## Everything stays between `rear` and `front` within `size` (the bore's dark
## face stands 3.5 mm proud of the front). Stop the tube inside the sleeve
## (within 0.3 of the way to `front`, 0.13 for "box") so the windows stay
## open. Muzzle markers stay with the caller. Returns `front`.
static func muzzle_brake(k: VehicleModels, parent: Node3D, rear: Vector3, front: Vector3, size: Vector2, style := "double", mat := "gunmetal_w", col = null, tube := 0.0, up := Vector3.UP) -> Vector3:
	var length := rear.distance_to(front)
	if length < 0.01:
		return front
	var m := _framed(k, parent, rear, front, up)
	var r := tube if tube > 0.0 else size.y * 0.31
	# Solid sections as (start, end) fractions of the length from the rear: the
	# sleeve or rear block first, then the baffles; windows lie between them.
	var cuts: Array[Vector2] = [Vector2(0.0, 0.3), Vector2(0.52, 0.64), Vector2(0.86, 1.0)]
	if style == "single":
		cuts = [Vector2(0.0, 0.45), Vector2(0.78, 1.0)]
	elif style == "box":
		cuts = [Vector2(0.0, 0.13), Vector2(0.39, 0.61), Vector2(0.87, 1.0)]
	var first := -cuts[0].y * length
	var last := -cuts[cuts.size() - 1].x * length
	if style == "box":
		var w := size.x
		var h := size.y
		for cut: Vector2 in cuts:
			var z0 := -cut.x * length
			var z1 := -cut.y * length
			k._box(m, Vector3(w, h, z0 - z1), Vector3(0, 0, (z0 + z1) * 0.5), mat, col)
		# The top and bottom walls bridge the windows.
		var wall := h * 0.155
		for side: float in [-1.0, 1.0]:
			k._box(m, Vector3(w, wall, first - last + 0.01), Vector3(0, side * (h - wall) * 0.5, (first + last) * 0.5), mat, col)
		# The rear block's clamp bolts, on its top face.
		for x: float in [-0.25, 0.25]:
			VehicleBody.fastener(k, m, Vector3(x * w, h * 0.5 + 0.002, first * 0.5), Vector3.UP, minf(0.014, h * 0.05))
		for i in range(1, cuts.size()):
			k._box(m, Vector3(w * 0.9, h - wall * 2.0 - 0.004, 0.004), Vector3(0, 0, -cuts[i].x * length + 0.0025), "plain_dark", null, Vector3.ZERO, false)
		_crown(k, m, -length, r)
		k._fold(m)
		return front
	var big := size.y * 0.5
	var sleeve := clampf(r * 1.3, r + 0.01, big * 0.86)
	# The sleeve: a chamfer onto the tube, the lock ring, its key on top.
	var chamfer := minf(-first * 0.25, 0.04)
	_z(k, m, 0.0, -chamfer, sleeve * 0.9, sleeve, mat, col, 14)
	_z(k, m, -chamfer, first, sleeve, sleeve, mat, col, 14)
	var ring_z := first * 0.45
	_z(k, m, ring_z + length * 0.03, ring_z - length * 0.03, sleeve * 1.05, sleeve * 1.05, "metal_dark", null, 14, false)
	k._box(m, Vector3(sleeve * 0.35, sleeve * 0.16, length * 0.05), Vector3(0, sleeve * 1.05, ring_z), "metal_dark", null, Vector3.ZERO, false)
	# The baffles, the front one chamfered round its face, each sooted behind.
	for i in range(1, cuts.size()):
		var z0 := -cuts[i].x * length
		var z1 := -cuts[i].y * length
		var lip := big * 0.94 if i == cuts.size() - 1 else big
		_z(k, m, z0, z1, big, lip, mat, col, 16)
		VehicleBody.cylinder(k, m, big * 0.82, big * 0.82, 0.004, Vector3(0, 0, z0 + 0.0025), X90, "plain_dark", null, 12, false)
	# The top and bottom walls bridge the windows from sleeve to front baffle.
	for side: float in [-1.0, 1.0]:
		k._box(m, Vector3(big, big * 0.26, first - last + 0.01), Vector3(0, side * big * 0.74, (first + last) * 0.5), mat, col)
	if size.x > size.y + 0.01:
		# Side plates: posts where the sleeve and the baffles meet them, rails
		# above and below the windows.
		var outer := size.x * 0.5
		var inner := big * 0.72
		var plate_h := size.y * 0.72
		var rail := maxf(0.008, (plate_h - big * 1.22) * 0.5)
		var back := first + length * 0.14
		for side: float in [-1.0, 1.0]:
			var x := side * (outer + inner) * 0.5
			k._box(m, Vector3(outer - inner, plate_h, length * 0.14), Vector3(x, 0, first + length * 0.07), mat, col)
			for i in range(1, cuts.size()):
				var z0 := -cuts[i].x * length
				var z1 := -cuts[i].y * length
				k._box(m, Vector3(outer - inner, plate_h, z0 - z1), Vector3(x, 0, (z0 + z1) * 0.5), mat, col)
			for y: float in [-1.0, 1.0]:
				k._box(m, Vector3(outer - inner, rail, back + length), Vector3(x, y * (plate_h - rail) * 0.5, (back - length) * 0.5), mat, col, Vector3.ZERO, false)
	_crown(k, m, -length, r)
	k._fold(m)
	return front


## Muzzle reference sensor: the small collimator clamped on top of a tank gun
## near its muzzle. The gunner's sight reads its window to measure how far the
## tube has drooped as it heats, and corrects the aim. `center` and `size` are
## the old box's (local Y away from the bore, -Z toward the muzzle); `bore` is
## the point on the gun's centreline under it and `radius` the tube's radius
## there; `forward` points to the muzzle. A clamp band round the tube with its
## pinch lugs and bolts, a saddle up to the head where it stands clear of the
## tube, the bevelled head, and its rubber-framed window looking back at the
## turret under a rain lip (the glass is gone on wrecks). The band reaches
## 6 mm and its lugs 2.2 cm round the tube; the window and lip stand at most
## 1.4 cm behind the old box.
static func muzzle_sensor(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, bore: Vector3, radius: float, mat := "gunmetal_w", col = null, forward := Vector3.FORWARD) -> void:
	var m := _framed(k, parent, bore, bore + forward, center - bore)
	var at: Vector3 = m.basis.inverse() * (center - bore)
	var band := minf(size.z * 0.6, 0.08)
	_z(k, m, at.z + band * 0.5, at.z - band * 0.5, radius + 0.006, radius + 0.006, mat, col, 14, false)
	for side: float in [-1.0, 1.0]:
		var lug := Vector3(side * (radius + 0.014), 0, at.z)
		k._box(m, Vector3(0.016, 0.022, band * 0.8), lug, mat, col, Vector3.ZERO, false)
		VehicleBody.fastener(k, m, lug + Vector3(side * 0.009, 0, 0), Vector3.RIGHT * side, 0.006)
	var foot := at.y - size.y * 0.5
	if foot - radius > 0.004:
		k._box(m, Vector3(size.x * 0.55, foot - radius + 0.012, band), Vector3(0, (foot + radius) * 0.5, at.z), mat, col)
	k._add(m, BevelMesh.make(size, minf(0.008, minf(size.x, size.y) * 0.12)), mat, col, at)
	var back := at + Vector3(0, -size.y * 0.04, size.z * 0.5)
	k._box(m, Vector3(size.x * 0.66, size.y * 0.56, 0.008), back, "rubber", null, Vector3.ZERO, false)
	if not k.burnt:
		k._box(m, Vector3(size.x * 0.52, size.y * 0.42, 0.006), back + Vector3(0, 0, 0.002), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(size.x * 0.82, 0.008, 0.016), at + Vector3(0, size.y * 0.5 - 0.004, size.z * 0.5 + 0.006), mat, col, Vector3.ZERO, false)
	k._fold(m)
