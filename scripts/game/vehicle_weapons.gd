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
static func _z(k: VehicleModels, m: Node3D, rear: float, front: float, rear_r: float, front_r: float, mat: String, col = null, segments := 10, shadow := true, at := Vector2.ZERO) -> void:
	if rear - front < 0.0005:
		return
	k._cyl(m, rear_r, front_r, rear - front, Vector3(at.x, at.y, (rear + front) * 0.5), X90, mat, col, segments, shadow)

## The dark mouth of a bore, just proud of the face it sits in.
static func _bore(k: VehicleModels, m: Node3D, z: float, radius: float, at := Vector2.ZERO) -> void:
	k._cyl(m, radius, radius, 0.004, Vector3(at.x, at.y, z - 0.0015), X90, "plain_dark", null, 8, false)


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
	_z(k, m, half - sleeve, -half + hider, radius, radius, mat, null, 6, false)
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
	_z(k, m, root_end + 0.015, root_end - 0.02, root.x * 0.82, root.x * 0.82, "metal_dark", null, 12, false)
	_z(k, m, root_end + 0.01, brake_start - 0.01, barrel.x, barrel.y, mat, col, 10)
	for i in bands:
		var z := lerpf(root_end, brake_start, (i + 1.0) / (bands + 1.0))
		var r := lerpf(barrel.x, barrel.y, (i + 1.0) / (bands + 1.0))
		_z(k, m, z + 0.015, z - 0.015, r * 1.35, r * 1.35, "metal_dark", null, 10, false)
	# Muzzle brake: a body with two rows of dark side ports and a front lip.
	_z(k, m, brake_start, -length, brake.x, brake.x * 0.94, "gunmetal_w", null, 10)
	for f: float in [0.3, 0.62]:
		var z := lerpf(brake_start, -length, f)
		_z(k, m, z + brake.y * 0.07, z - brake.y * 0.07, brake.x * 1.01, brake.x * 1.01, "plain_dark", null, 10, false)
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
			VehicleFrames.tube(k, m, Vector3(side * 0.05, 0.03, 0.335) * s, Vector3(side * 0.075, 0.03, 0.39) * s, 0.012 * s, mat, null, 6, false)
			k._cyl(m, 0.02 * s, 0.02 * s, 0.14 * s, Vector3(side * 0.075, 0.03, 0.4) * s, Vector3.ZERO, "rubber", null, 6, false)
		k._box(m, Vector3(0.07, 0.025, 0.02) * s, Vector3(0, 0.03, 0.37) * s, mat, null, Vector3.ZERO, false)
	# The perforated barrel support, its carrying handle, the barrel and hider.
	var jacket := -0.31 * s
	var jacket_end := maxf(-0.57 * s, -length + 0.2 * s)
	_z(k, m, jacket, jacket_end, 0.046 * s, 0.046 * s, mat, null, 10)
	for i in 3:
		var z := lerpf(jacket, jacket_end, (i + 1) / 4.0)
		_z(k, m, z + 0.011 * s, z - 0.011 * s, 0.051 * s, 0.051 * s, "metal_dark", null, 10, false)
	VehicleDoors.pull(k, m, Vector3(0, 0.046 * s, (jacket + jacket_end) * 0.5), Vector3.UP, Vector3.FORWARD, 0.11 * s, 0.008 * s, mat)
	_z(k, m, jacket_end, -length + 0.12 * s, 0.028 * s, 0.026 * s, mat, null, 8)
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
	_z(k, m, -0.21 * s, trunnion, 0.03 * s, 0.03 * s, mat, null, 8)
	VehicleFrames.tube(k, m, Vector3(0, -0.035, -0.22) * s, Vector3(0, -0.035 * s, minf(trunnion - 0.1 * s, -length * 0.55)), 0.011 * s, mat, null, 6, false)
	VehicleDoors.pull(k, m, Vector3(0, 0.03, -0.3) * s, Vector3.UP, Vector3.FORWARD, 0.09 * s, 0.006 * s, mat)
	_z(k, m, trunnion, -length + 0.07 * s, 0.016 * s, 0.016 * s, mat, null, 6, false)
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
		k._cyl(m, 0.02 * s, 0.02 * s, 0.13 * s, Vector3(side * 0.07, 0, 0.37) * s, Vector3.ZERO, "rubber", null, 6, false)
	var jacket_end := maxf(-0.66 * s, -length + 0.16 * s)
	_z(k, m, -0.3 * s, jacket_end, 0.075 * s, 0.075 * s, mat, null, 10)
	for i in 3:
		var z := lerpf(-0.3 * s, jacket_end, (i + 1) / 4.0)
		_z(k, m, z + 0.01 * s, z - 0.01 * s, 0.078 * s, 0.078 * s, "metal_dark", null, 10, false)
	_z(k, m, jacket_end, -length + 0.08 * s, 0.05 * s, 0.05 * s, mat, null, 8)
	_z(k, m, -length + 0.08 * s, -length, 0.062 * s, 0.06 * s, mat, null, 8, false)
	_bore(k, m, -length, 0.04 * s)
	if feed != 0.0:
		var side := signf(feed)
		if drum:
			k._cyl(m, 0.19 * s, 0.19 * s, 0.16 * s, Vector3(side * feed_offset, -0.04, 0.05) * s, Vector3(0, 0, PI / 2), "paint", feed_col, 14)
			k._cyl(m, 0.06 * s, 0.06 * s, 0.17 * s, Vector3(side * feed_offset, -0.04, 0.05) * s, Vector3(0, 0, PI / 2), "metal_dark", null, 10, false)
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
	_z(k, m, 0.0, -length * 0.96, cluster * 0.42, cluster * 0.42, "metal_dark", null, 10, false)
	_z(k, m, 0.02, -minf(length * 0.06, 0.08), clamp_r, clamp_r, mat, null, 14)
	for i in barrels:
		var a := TAU * float(i) / barrels + phase
		var at := Vector2(cos(a), sin(a)) * cluster
		_z(k, m, 0.0, -length, barrel_radius, barrel_radius * 0.9, mat, null, 6, false, at)
		_bore(k, m, -length, barrel_radius * 0.5, at)
	for f: float in clamps:
		var z := -length * f
		var half := maxf(0.015, length * 0.025)
		_z(k, m, z + half, z - half, clamp_r, clamp_r, mat, null, 14, false)
	k._fold(m)
	return muzzle


## Missile launch tube along local Z (the old cylinder's centre, radius and
## length): fitted end collars, a frangible front cover, clamp bands and the
## firing umbilical. `collar_col` defaults to a darker shade of the tube.
static func launch_tube(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, mat := "paint", col = null, collar_col = null) -> void:
	var m := k._pivot(parent, center)
	var half := length * 0.5
	var cc: Variant = collar_col
	if cc == null and col is Color:
		cc = (col as Color).darkened(0.15)
	var collar := minf(0.1, length * 0.08)
	_z(k, m, half - collar * 0.5, -half + collar * 0.5, radius, radius, mat, col, 12)
	for end: float in [-1.0, 1.0]:
		var outer := end * half
		_z(k, m, maxf(outer, outer - end * collar), minf(outer, outer - end * collar), radius * 1.18, radius * 1.18, mat, cc, 12)
		_z(k, m, maxf(outer, outer - end * collar * 0.35), minf(outer, outer - end * collar * 0.35), radius * 1.24, radius * 1.24, "metal_dark", null, 12, false)
	# The domed front cover blows out on launch; the rear one is a blast seal.
	k._cyl(m, radius * 0.98, radius * 0.92, 0.014, Vector3(0, 0, -half - 0.006), X90, "rubber", null, 12, false)
	k._cyl(m, radius * 0.7, radius * 0.7, 0.008, Vector3(0, 0, half + 0.004), X90, "plain_dark", null, 10, false)
	for z: float in [-length * 0.2, length * 0.2]:
		_z(k, m, z + 0.018, z - 0.018, radius * 1.04, radius * 1.04, "metal_dark", null, 12, false)
	k._box(m, Vector3(radius * 0.45, radius * 0.28, minf(0.12, length * 0.1)), Vector3(0, radius * 1.08, half * 0.5), "metal_dark")
	k._fold(m)
