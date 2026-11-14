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


static var _rings := {}

## A ring of `radius` round its centre line and `wire` thick, lying in the XZ
## plane (cached by size; small fittings need few segments).
static func _ring(radius: float, wire: float, rings := 16, sides := 6) -> TorusMesh:
	var key := Vector4(radius, wire, rings, sides)
	if not _rings.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius - wire
		mesh.outer_radius = radius + wire
		mesh.rings = rings
		mesh.ring_segments = sides
		_rings[key] = mesh
	return _rings[key]


## A bow or stern eye: the stainless U-bolt a trailer winch or a towline hooks
## into, its loop standing out of the hull on a backing plate, the nuts of its
## two legs either side. `center`, `inner` and `outer` are the old ring's
## (a torus of those radii); `normal` points out of the hull where the eye
## leaves it (forward at the stem, aft on a transom) and `axis` is the hole's
## axis, across the loop (athwartships for a stem eye; zero takes the level
## direction across `normal`). The loop's centre line meets the hull at
## `center` - `normal` * (`inner` + `outer`) / 2, where the plate lies; the
## loop stands as the old ring did, the plate reaching 2.4 wires past it.
static func bow_eye(k: VehicleModels, parent: Node3D, center: Vector3, inner: float, outer: float, normal := Vector3.FORWARD, axis := Vector3.ZERO, mat := "steel", col = null) -> void:
	var z := normal.normalized()
	var x := axis - z * axis.dot(z)
	if x.length_squared() < 0.000001:
		x = z.cross(Vector3.UP) if absf(z.y) < 0.95 else Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	var radius := (inner + outer) * 0.5
	var wire := (outer - inner) * 0.5
	var mount := k._pivot(parent, center)
	mount.basis = Basis(x, y, z)
	# The loop: the ring turned so its hole runs along x.
	k._add(mount, _ring(radius, wire), mat, col, Vector3.ZERO, Vector3(0, 0, PI / 2))
	var plate := Vector3(maxf(wire * 3.2, radius * 0.7), (outer + wire * 2.4) * 2.0, maxf(wire * 0.55, 0.004))
	k._box(mount, plate, Vector3(0, 0, -radius + plate.z * 0.5), mat, col, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(0, s * (outer + wire * 1.2), -radius + plate.z), Vector3.BACK, wire * 0.9)
	k._fold(mount)


## A boat's fender (bumper) hung over the side or stowed on deck. The
## "cylinder" style is an inflatable fender: the moulded body, a boss at each
## end with the rope eye moulded through it; `center` and `rotation` are the
## old capsule's (its axis local Y), `radius` and `length` its radius and its
## overall length. The "tyre" style is an old tyre: `center` and `rotation`
## are the old torus's (the axle along local Y), `radius` its outer radius and
## `length` its tread width; it is rubber whatever `mat`, and its rope runs
## over the crown.
## `cap` colours the end bosses (null: the body's colour, a shade darker).
## `line`, when finite, hangs it from that point (a cleat or rail) by a line
## from its upper end; `line_col` colours the line.
static func fender(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, rotation := Vector3.ZERO, col := Color(0.86, 0.86, 0.83), cap = null, line := Vector3.INF, style := "cylinder", mat := "plain", line_col := Color(0.5, 0.45, 0.35)) -> void:
	assert(style in ["cylinder", "tyre"])
	var basis := Basis.from_euler(rotation)
	var up := basis.y if basis.y.dot(Vector3.UP) >= 0.0 else -basis.y
	if style == "tyre":
		var section := radius * 0.444
		var width := maxf(length, 0.01)
		k._add(parent, _ring(radius - section * 0.5, section * 0.5, 14, 6), "rubber", col, center, rotation, Vector3(1, width / section, 1))
		# The tread's crown where the line goes over it: the line passes
		# through the tyre and back over the top.
		var crown := (Vector3.UP - basis.y * Vector3.UP.dot(basis.y)).normalized()
		if crown.is_zero_approx():
			crown = basis.x
		var rope := maxf(0.008, radius * 0.04)
		var over := center + crown * (radius + rope * 0.6)
		VehicleFrames.tube(k, parent, over - basis.y * width * 0.55, over + basis.y * width * 0.55, rope, "canvas", line_col, 4, false)
		if line.is_finite():
			VehicleFrames.tube(k, parent, over, line, rope, "canvas", line_col, 4, false)
		return
	var half := length * 0.5
	k._add(parent, Res.capsule(radius, length, 12), mat, col, center, rotation)
	var boss: Color = cap if cap is Color else col.darkened(0.12)
	var eye := _ring(radius * 0.22, radius * 0.06, 8, 4)
	for e: float in [-1.0, 1.0]:
		var at := center + basis.y * e * (half - radius * 0.13)
		k._cyl(parent, radius * 0.6, radius * 0.6, radius * 0.8, at, rotation, mat, boss, 10, false)
		# The rope eye moulded through the boss, its loop standing off the end.
		k._add(parent, eye, mat, boss, at + basis.y * e * radius * 0.4, (basis * Basis(Vector3.BACK, PI / 2)).get_euler(), Vector3.ONE, false)
	if line.is_finite():
		var top := center + up * (half - radius * 0.13 + radius * 0.62)
		VehicleFrames.tube(k, parent, top, line, maxf(0.006, radius * 0.08), "canvas", line_col, 4, false)
