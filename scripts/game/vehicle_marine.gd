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


static var _cloths := {}

## A sheet of cloth through a grid of `nu` by `nv` points (row by row),
## both faces drawn, since a flag or an awning is seen from either side; its
## normals run smooth across the grid, so folds shade round. Cached under
## `key` (callers keep the variants few: one per size and fold).
static func cloth(key: String, pts: PackedVector3Array, nu: int, nv: int) -> ArrayMesh:
	if _cloths.has(key):
		return _cloths[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for side: float in [1.0, -1.0]:
		var base := verts.size()
		for j in nv:
			for i in nu:
				var du := pts[j * nu + mini(i + 1, nu - 1)] - pts[j * nu + maxi(i - 1, 0)]
				var dv := pts[mini(j + 1, nv - 1) * nu + i] - pts[maxi(j - 1, 0) * nu + i]
				verts.append(pts[j * nu + i])
				norms.append(du.cross(dv).normalized() * side)
		for j in nv - 1:
			for i in nu - 1:
				var a := base + j * nu + i
				var n := (norms[a] + norms[a + nu + 1]).normalized()
				VehicleWheels._tri(idx, verts, n, a, a + 1, a + nu)
				VehicleWheels._tri(idx, verts, n, a + 1, a + nu + 1, a + nu)
	var mesh := VehicleWheels._mesh(verts, norms, idx)
	_cloths[key] = mesh
	return mesh


## An ensign on its staff or halyard: the bunting hangs from its hoist at
## `hoist` (the head of the flag, against the staff), its fly reaching aft
## along `aft`, `w` long and `h` deep. Boats and ships are built still, so it
## hangs as a flag does in a light air: the fly sagging below the hoist, the
## cloth falling into two loose folds that deepen toward the fly, its lower
## corner dropping furthest. Woven nylon in the team's colour (a muted
## field: sun and salt fade bunting), with the hoist's doubled tabling down
## the staff. Two fold patterns, picked by the kit seed, so two boats moored
## side by side don't fly identical flags; scenery takes the first. None on
## a wreck (it went up first: a ship's wreck keeps its own old flag, see
## VmShips._flag), nor for a team with no colour.
static func ensign(k: VehicleModels, parent: Node3D, hoist: Vector3, team: int, w: float, h: float, aft := Vector3.BACK) -> void:
	if team < 0 or team >= Defs.TEAM_COLORS.size() or k.wreck or k.burnt:
		return
	var tc: Color = Defs.TEAM_COLORS[team].lerp(Color(0.45, 0.45, 0.42), 0.35).darkened(0.12)
	var variant := 0 if k.kit_seed < 0 else k.kit_seed % 2
	var nu := 8
	var nv := 3
	var pts := PackedVector3Array()
	for j in nv:
		var v := float(j) / (nv - 1)
		for i in nu:
			var u := float(i) / (nu - 1)
			# the folds: none at the hoist, where the tabling holds the cloth
			# flat on the staff, deepening toward the fly; the second pattern
			# starts its first fold the other way
			var fold := w * 0.1 * pow(u, 0.8) * sin(u * PI * (2.3 if variant == 0 else 1.8) + (0.0 if variant == 0 else PI))
			# (a little twist down the hoist, so the folds don't run plumb)
			var x := fold + w * 0.03 * u * (v - 0.5)
			var y := -v * h - u * u * h * 0.32 - u * v * h * 0.12
			var z := u * w * 0.93
			pts.append(Vector3(x, y, z))
	var mesh := cloth("ensign_%.2f_%.2f_%d" % [w, h, variant], pts, nu, nv)
	var d := aft
	d.y = 0.0
	d = d.normalized() if d.length_squared() > 0.000001 else Vector3.BACK
	var mount := k._pivot(parent, hoist)
	mount.basis = Basis(Vector3.UP.cross(d).normalized(), Vector3.UP, d)
	k._add(mount, mesh, "nylon", tc, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# the tabling down the hoist, a doubled strip of heavier cloth (white
	# canvas on a real ensign: the toggle and the ring are sewn into it)
	k._add(mount, Res.box(Vector3(0.012, h, 0.03)), "webbing", Color(0.82, 0.8, 0.74), Vector3(0, -h * 0.5, 0.012), Vector3.ZERO, Vector3.ONE, false)
	k._fold(mount)


## A mooring line made off on a cleat or bitts at `made` and its tail
## coiled down on the deck beside it at `pos` (the coil's foot), as a crew
## leaves a line ready to throw: three flat turns of laid rope of radius
## `r`, each a little smaller and off-centre on the last, the lead running
## from the fitting to the outer turn. `wire` is the rope's radius. Not on
## a wreck (the line burned).
static func line_coil(k: VehicleModels, parent: Node3D, made: Vector3, pos: Vector3, r: float, wire: float, col := Color(0.78, 0.76, 0.7)) -> void:
	if k.wreck or k.burnt:
		return
	for i in 3:
		var rr := snappedf(r * (1.0 - i * 0.14), 0.005)
		k._add(parent, _ring(rr, wire, 8, 4), "rope", col, pos + Vector3(0.012 * i, wire * (1.0 + i * 1.8), -0.01 * i), Vector3.ZERO, Vector3(1, 1.25, 1), false)
	var lead := made - pos
	lead.y = 0.0
	var out := pos + lead.normalized() * r + Vector3(0, wire, 0) if lead.length_squared() > 0.0001 else pos
	VehicleCloth.rope(k, parent, [made, made.lerp(out, 0.5) + Vector3(0, -0.01, 0), out], wire, col)


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
## An inflatable fender is moulded PVC ("coated": smooth, a soft sheen, its
## colour right through, so it scuffs but never chips like the hull's paint);
## its lines are laid rope. (A wreck's keep the plain finish and the cloth
## that burns away, as they always had.)
static func fender(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, rotation := Vector3.ZERO, col := Color(0.86, 0.86, 0.83), cap = null, line := Vector3.INF, style := "cylinder", mat := "coated", line_col := Color(0.5, 0.45, 0.35)) -> void:
	assert(style in ["cylinder", "tyre"])
	var basis := Basis.from_euler(rotation)
	var up := basis.y if basis.y.dot(Vector3.UP) >= 0.0 else -basis.y
	if k.wreck and mat == "coated":
		mat = "plain"
	var cord := "canvas" if k.wreck else "rope"
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
		VehicleFrames.tube(k, parent, over - basis.y * width * 0.55, over + basis.y * width * 0.55, rope, cord, line_col, 4, false)
		if line.is_finite():
			VehicleFrames.tube(k, parent, over, line, rope, cord, line_col, 4, false)
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
		VehicleFrames.tube(k, parent, top, line, maxf(0.006, radius * 0.08), cord, line_col, 4, false)
