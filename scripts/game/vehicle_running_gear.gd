class_name VehicleRunningGear
extends RefCounted
## Underbody assemblies never register wheels. The family retains wheel pivots,
## track envelopes and vehicle-specific suspension layouts.

static func frame(k: VehicleModels, parent: Node3D, center: Vector3, half_width: float, length: float, rail: Vector2, crossmembers: Array) -> void:
	for side: float in [-1.0, 1.0]:
		var at := center + Vector3(side * half_width, 0, 0)
		k._box(parent, Vector3(rail.x * 0.22, rail.y, length), at + Vector3(side * rail.x * 0.39, 0, 0), "metal_dark")
		for edge: float in [-1.0, 1.0]:
			k._box(parent, Vector3(rail.x, rail.y * 0.16, length), at + Vector3(0, edge * rail.y * 0.42, 0), "metal_dark")
	for z: float in crossmembers:
		k._box(parent, Vector3(half_width * 2, rail.y * 0.55, rail.x), Vector3(center.x, center.y, z), "metal_dark")
		for side: float in [-1.0, 1.0]:
			# The gusset is a plate a few centimetres thick under the body: plain.
			k._add(parent, VehicleEquipment._plate(Vector3(rail.x * 1.6, rail.y * 0.16, rail.x * 1.8)), "metal_dark", null, Vector3(center.x + side * (half_width - rail.x * 0.3), center.y, z))
			VehicleBody.fastener(k, parent, Vector3(center.x + side * half_width, center.y + rail.y * 0.52, z), Vector3.UP, 0.012)

static func axle(k: VehicleModels, parent: Node3D, center: Vector3, width: float, radius: float, spring_span := 0.0, spring_length := 0.85) -> void:
	VehicleEquipment._rod(k, parent, center - Vector3.RIGHT * width * 0.5, center + Vector3.RIGHT * width * 0.5, radius, "metal_dark", null, 10, true, 3)
	k._add(parent, Res.sphere(radius * 2.3, 12), "metal_dark", null, center, Vector3.ZERO, Vector3(1, 0.9, 0.85))
	VehicleEquipment._cyl(k, parent, radius * 1.7, radius * 1.7, radius * 0.3, center + Vector3(0, 0, -radius * 1.8), Vector3(PI / 2, 0, 0), "steel", Color(0.18, 0.19, 0.18), 10, false)
	# Six bolts round the differential cover read as its bolt ring under the
	# chassis as well as eight did.
	for i in 6:
		var angle := TAU * (i + 0.5) / 6.0
		VehicleBody.fastener(k, parent, center + Vector3(cos(angle) * radius * 1.35, sin(angle) * radius * 1.35, -radius * 1.97), Vector3.FORWARD, radius * 0.13)
	# The pinion nose's ends are in the housing and the flange.
	VehicleEquipment._cyl(k, parent, radius * 0.8, radius * 0.7, radius * 0.8, center + Vector3(0, 0, radius * 2.0), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, true, 0)
	VehicleEquipment._cyl(k, parent, radius, radius, radius * 0.2, center + Vector3(0, 0, radius * 2.4), Vector3(PI / 2, 0, 0), "steel", null, 10, false)
	if spring_span > 0:
		for side: float in [-1.0, 1.0]:
			for leaf in 3:
				var length := spring_length * (1.0 - leaf * 0.15)
				var c := center + Vector3(side * spring_span, radius + 0.025 + leaf * 0.012, 0)
				VehicleFrames.beam(k, parent, c + Vector3(0, 0.035, -length * 0.5), c, 0.07, 0.01, "metal_dark")
				VehicleFrames.beam(k, parent, c, c + Vector3(0, 0.035, length * 0.5), 0.07, 0.01, "metal_dark")
			# The spring's clamp blocks, under the chassis: plain blocks.
			for z in [-spring_length * 0.4, spring_length * 0.4]:
				k._add(parent, VehicleEquipment._plate(Vector3(0.1, 0.045, 0.035)), "steel", Color(0.20, 0.21, 0.19), center + Vector3(side * spring_span, radius + 0.07, z))

## Saddle fuel tank hung from the frame rail: the old tank's centre and size
## (a round tank is 2r x 2r x length along Z). `side` is the vehicle side it
## hangs on. Dished ends and straps (round) or a bevelled box with straps,
## the filler cap on the outer shoulder, hanger brackets inboard and a drain.
## `rotation` turns the whole tank about its centre (one sitting askew, or on a
## sloped fender), its axes then the tank's own; zero builds it straight in the
## parent's axes as before.
static func fuel_tank(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, round := true, rotation := Vector3.ZERO) -> void:
	var p := parent
	var c := center
	if rotation != Vector3.ZERO:
		p = k._pivot(parent, center)
		p.rotation = rotation
		c = Vector3.ZERO
	var s := 1.0 if side >= 0.0 else -1.0
	var straps := [-size.z * 0.28, size.z * 0.28]
	if round:
		VehicleEquipment.vessel(k, p, c, size, straps, mat, col, false)
	else:
		k._add(p, BevelMesh.make(size, minf(0.03, minf(size.x, size.y) * 0.1)), mat, col, c)
		for z: float in straps:
			k._box(p, Vector3(size.x + 0.012, size.y + 0.012, 0.04), c + Vector3(0, 0, z), "metal_dark")
	var shoulder := Vector3(s * 0.45, 0.89, 0).normalized()
	var cap_at := c + Vector3(shoulder.x * size.x * 0.5, shoulder.y * size.y * 0.5, -size.z * 0.3) if round else c + Vector3(s * size.x * 0.25, size.y * 0.5, -size.z * 0.3)
	VehicleFittings.filler(k, p, cap_at, minf(0.05, size.x * 0.12), shoulder if round else Vector3.UP)
	for z: float in straps:
		k._box(p, Vector3(0.03, size.y * 0.8, 0.08), c + Vector3(-s * (size.x * 0.5 + 0.015), 0, z), "metal_dark")
	VehicleBody.fastener(k, p, c + Vector3(0, -size.y * 0.5 - 0.002, size.z * 0.3), Vector3.DOWN, 0.014)
	if p != parent:
		k._fold(p)


## Double-wishbone independent suspension at one wheel, static: the lower and
## upper A-arms, the upright (steering knuckle) between their outer ball
## joints and an optional coil-over. The arms' ends are the old arms' own, in
## the parent's axes: `*_in` the middle of the arm's two chassis bushings,
## `*_out` its outer ball joint. `lower` / `upper` = (spread, tube): the two
## legs leave rubber-bushed eyes `spread` apart along Z (the old arm box's
## depth) and converge on the joint, round tubes `tube` thick (the box's
## height), braced between them. An old arm box at c, length L, turned θ about
## Z converts as c ∓ (cos θ, sin θ, 0) · L/2, the end nearer the centre line
## in. `damper_top` / `damper_bottom` (both non-zero) stand a coil-over between
## them: damper body, rod, eyes, spring seats and a coil spring `damper_radius`
## round (the old damper cylinder's radius); `spring_col` paints the spring
## (null: the arms' finish). `upright` false leaves the knuckle to the caller
## (a portal hub housing). It stays within the old arm boxes and damper
## cylinder but for the joints (1.3 tube radii), the knuckle's spindle boss
## (1.3 tubes toward the wheel) and the damper eyes. Wheels, pivots and
## steering stay with the family.
static func wishbone(k: VehicleModels, parent: Node3D, lower_in: Vector3, lower_out: Vector3, upper_in: Vector3, upper_out: Vector3, lower := Vector2(0.16, 0.07), upper := Vector2(0.14, 0.07), damper_top := Vector3.ZERO, damper_bottom := Vector3.ZERO, damper_radius := 0.06, upright := true, mat := "gunmetal_w", col = null, spring_col = null) -> void:
	_a_arm(k, parent, lower_in, lower_out, lower, mat, col)
	_a_arm(k, parent, upper_in, upper_out, upper, mat, col)
	if upright:
		var t := maxf(lower.y, upper.y)
		VehicleFrames.beam(k, parent, lower_out, upper_out, t * 1.2, t * 1.4, mat, col, true, true)
		var out := Vector3(lower_out.x - lower_in.x, 0, lower_out.z - lower_in.z).normalized()
		if not out.is_zero_approx():
			var mid := (lower_out + upper_out) * 0.5
			VehicleEquipment._rod(k, parent, mid, mid + out * t * 1.3, t * 0.8, "steel", Color(0.28, 0.29, 0.27), 10, false, 2)
	if damper_top != Vector3.ZERO and damper_bottom != Vector3.ZERO and damper_top.distance_to(damper_bottom) > damper_radius:
		_coil_over(k, parent, damper_bottom, damper_top, damper_radius, mat, col, spring_col)


## One A-arm: two tube legs from bushed eyes to a ball joint, a cross brace.
static func _a_arm(k: VehicleModels, parent: Node3D, inner: Vector3, outer: Vector3, dims: Vector2, mat: String, col) -> void:
	var r := dims.y * 0.5
	var eye := minf(dims.x * 0.3, r * 2.0)
	# The legs and eyes keep inside the old arm's depth.
	var half := Vector3(0, 0, maxf(dims.x * 0.5 - maxf(r, eye * 0.5 + 0.004), 0.0))
	# Each leg ends in the ball joint (its other end shows past a short eye),
	# and the brace in the legs.
	for e: float in [-1.0, 1.0]:
		var bush := inner + half * e
		VehicleEquipment._rod(k, parent, bush, outer, r, mat, col, 6, true, 1)
		VehicleEquipment._cyl(k, parent, r * 1.3, r * 1.3, eye, bush, Vector3(PI / 2, 0, 0), mat, col, 8, false)
		VehicleEquipment._cyl(k, parent, r * 0.7, r * 0.7, eye + 0.008, bush, Vector3(PI / 2, 0, 0), "rubber", null, 6, false)
	VehicleEquipment._rod(k, parent, (inner - half).lerp(outer, 0.4), (inner + half).lerp(outer, 0.4), r * 0.7, mat, col, 6, false, 0)
	k._add(parent, Res.sphere(r * 1.3, 8), "steel", Color(0.28, 0.29, 0.27), outer)


## A coil-over damper from its lower eye at `bottom` to its upper at `top`:
## the damper body, the bright rod, the spring between its seats.
static func _coil_over(k: VehicleModels, parent: Node3D, bottom: Vector3, top: Vector3, radius: float, mat: String, col, spring_col) -> void:
	var length := bottom.distance_to(top)
	var d := (top - bottom) / length
	var across := Vector3.BACK - d * d.dot(Vector3.BACK)
	if across.length_squared() < 0.01:
		across = Vector3.RIGHT - d * d.dot(Vector3.RIGHT)
	across = across.normalized()
	var eye := radius * 0.32
	for at: Vector3 in [bottom + d * eye, top - d * eye]:
		VehicleEquipment._rod(k, parent, at - across * radius * 0.4, at + across * radius * 0.4, eye, "metal_dark", null, 8, false, 3)
	VehicleEquipment._rod(k, parent, bottom + d * eye * 1.6, bottom + d * length * 0.58, radius * 0.42, "metal_dark", null, 10, true, 3)
	# The rod's ends are in the damper body and the upper eye.
	VehicleEquipment._rod(k, parent, bottom + d * length * 0.58, top - d * eye * 1.6, radius * 0.16, "steel", Color(0.55, 0.56, 0.55), 8, false, 0)
	var s0 := bottom + d * length * 0.22
	var s1 := top - d * length * 0.1
	for at: Vector3 in [s0, s1]:
		VehicleEquipment._rod(k, parent, at - d * 0.006, at + d * 0.006, radius * 0.95, "metal_dark", null, 12, false, 3)
	var turns := clampi(roundi(s0.distance_to(s1) / maxf(radius * 0.95, 0.01)), 3, 6)
	var coil := _coil(radius * 0.82, s0.distance_to(s1), radius * 0.18, turns)
	var paint := spring_col is Color
	k._add(parent, coil, "paint" if paint else mat, spring_col if paint else col, s0, VehicleFrames.aim(d).get_euler(), Vector3.ONE, false)


## A helical spring along +Y from 0 to `length`, `radius` to its wire's centre,
## the wire a square section `wire` across (cached by size).
static func _coil(radius: float, length: float, wire: float, turns: int) -> ArrayMesh:
	var key := "gear_coil_%.3f_%.3f_%.3f_%d" % [radius, length, wire, turns]
	if VehicleModels._cache.has(key):
		return VehicleModels._cache[key]
	var steps := turns * 8
	var rings: Array = []
	for i in steps + 1:
		var angle := TAU * turns * i / float(steps)
		var c := Vector3(cos(angle) * radius, length * i / float(steps), sin(angle) * radius)
		var tangent := Vector3(-sin(angle) * radius * TAU * turns, length, cos(angle) * radius * TAU * turns).normalized()
		var radial := Vector3(cos(angle), 0, sin(angle))
		var side := tangent.cross(radial).normalized()
		var ring := PackedVector3Array()
		for corner: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
			ring.append(c + (radial * corner.x + side * corner.y) * wire * 0.5)
		rings.append(ring)
	return VehicleModels.solid(rings, key)
