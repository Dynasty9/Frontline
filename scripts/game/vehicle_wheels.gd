class_name VehicleWheels
extends RefCounted
## Wheel assemblies share their construction, never their moving pivots.

static var _rings := {}
static var _meshes := {}  # carcasses, tread bands, rim lips and drums, shared by size
const AXLE := Vector3(0, 0, PI / 2)

static func pneumatic(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, hub_kind := "gunmetal_w", hub_col = null, profile := "offroad", register := true) -> Node3D:
	# A car's road wheel is a car wheel, not a truck's: see _car_wheel. Trucks
	# and tractors pass painted rims, quad bikes' tyres are fatter than a
	# car's, and military vehicles keep their steel and beadlock rims.
	if profile == "road" and k.surface_family == "automotive" and hub_kind in ["steel", "gunmetal_w"] and r >= 0.3 and r < 0.42 and w <= r * 0.75:
		return _car_wheel(k, parent, pos, r, w, hub_kind, hub_col, register)
	var pv := k._pivot(parent, pos)
	# Rounded shoulders and recessed rims share meshes at every wheel size.
	# Tiny trolley wheels and broad tracked road wheels retain their solid discs.
	var fine := r >= 0.18
	if r < 0.18 or w > r * 1.2:
		k._add(pv, drum(r, r, w, 24), "rubber", null, Vector3.ZERO, AXLE)
	elif k.burnt:
		# Burnt out: the rubber is gone, leaving the steel belt (see _belt).
		k._add(pv, _belt(r, w), "steel", null, Vector3(0, -r * 0.05, 0))
	else:
		k._add(pv, _carcass(), "rubber", Color(0.17, 0.18, 0.17), Vector3.ZERO, AXLE, Vector3(r, w / 0.50, r))
		if profile != "aircraft":
			k._add(pv, _tread(r, w, profile == "offroad"), "rubber", Color(0.20, 0.21, 0.19), Vector3.ZERO)
	# The rim: its disc (the drum's edge runs on inside the tyre), the rolled
	# lip at each face, eight wheel nuts a face and the hub. Small wheels need
	# half the segments to look as round.
	k._add(pv, drum(r * 0.54, r * 0.54, w * 0.67, 32 if fine else 16), hub_kind, hub_col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	for side: float in [-1.0, 1.0]:
		k._add(pv, _lip(fine), hub_kind, hub_col, Vector3(side * w * 0.37, 0, 0), AXLE, Vector3.ONE * r, false)
		# A nut's foot sits on the disc, so it has no base; its top faces out.
		var nut := drum(r * 0.03, r * 0.03, w * 0.08, 6, false)
		for i in 8:
			var a := TAU * i / 8.0
			k._add(pv, nut, "steel", Color(0.35, 0.36, 0.33), Vector3(side * w * 0.38, sin(a) * r * 0.31, cos(a) * r * 0.31), Vector3(0, 0, -side * PI / 2), Vector3.ONE, false)
	k._add(pv, drum(r * 0.23, r * 0.26, w * 0.89, 16 if fine else 8), hub_kind, hub_col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	if register:
		k.wheels.append(pv)
	else:
		k._fold(pv)
		return parent
	return pv


## A car's wheel: a low-profile tyre with two grooves round its crown, on a
## rim two thirds of its radius (a truck's is half), the polished flange
## standing just inside the sidewall's bulge. What fills the rim is what a
## car of that kind wears, chosen by the caller's rim:
## - a dark rim (`gunmetal_w`): a painted alloy, five twin spokes on a small
##   car (the sport hatchback), five broad ones on a big one (the 4WD);
## - a bright steel rim of 36 cm or more (the SUV, the pickups): a six-spoke
##   alloy on six studs;
## - a smaller bright steel rim (the plain hatchback, the van, parked cars):
##   a pressed steel wheel under a domed plastic trim with its vent slots.
## Alloys show the dark wheel well and the brake disc between their spokes,
## and five or six wheel nuts round a centre cap. A running wheel details its
## outer face only (the inner one faces the chassis); a spare details both,
## and a carrier's stud runs through its centre to either face of the old hub.
## About half the vertices of the truck wheel it replaces.
static func _car_wheel(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, hub_kind: String, hub_col, register: bool) -> Node3D:
	var pv := k._pivot(parent, pos)
	var dark := hub_kind != "steel"
	var trim := not dark and r < 0.36
	var rr := r * (0.70 if dark and r < 0.36 else 0.63)
	if k.burnt:
		k._add(pv, _belt(r, w), "steel", null, Vector3(0, -r * 0.05, 0))
	else:
		k._add(pv, _car_tyre(r, w, rr), "rubber", Color(0.17, 0.18, 0.17), Vector3.ZERO)
	var faces: Array = [signf(pos.x) if pos.x != 0.0 else 1.0] if register else [-1.0, 1.0]
	for side: float in faces:
		var turn := Vector3(0, PI, 0) if side < 0.0 else Vector3.ZERO
		var out := Vector3(0, 0, -side * PI / 2)  # a drum's +Y (its cap) facing out
		k._add(pv, _car_rim(w, rr), hub_kind, hub_col, Vector3.ZERO, turn, Vector3.ONE, false)
		if trim:
			k._add(pv, _car_trim(w, rr), hub_kind, hub_col, Vector3.ZERO, turn, Vector3.ONE, false)
			# The trim's vent slots, dark against the silver, and its badge.
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				k._box(pv, Vector3(0.006, rr * 0.24, rr * 0.12), Vector3(side * w * 0.416, sin(a) * rr * 0.62, cos(a) * rr * 0.62), "rubber", Color(0.03, 0.03, 0.03), Vector3(PI / 2 - a, 0, 0), false)
			k._add(pv, drum(rr * 0.11, rr * 0.11, 0.008, 12, false), hub_kind, Color(0.2, 0.2, 0.21), Vector3(side * w * 0.447, 0, 0), out, Vector3.ONE, false)
			continue
		# The dark wheel well and the brake disc, seen between the spokes.
		k._add(pv, drum(rr * 0.93, rr * 0.93, 0.01, 16, false), "rubber", Color(0.04, 0.04, 0.04), Vector3(side * w * 0.12, 0, 0), out, Vector3.ONE, false)
		k._add(pv, drum(rr * 0.74, rr * 0.74, w * 0.05, 20, false), "steel", Color(0.36, 0.35, 0.33), Vector3(side * w * 0.2, 0, 0), out, Vector3.ONE, false)
		var spokes := 5 if dark else 6
		k._add(pv, _car_spokes(w, rr, spokes, dark and r < 0.36), hub_kind, hub_col, Vector3.ZERO, turn, Vector3.ONE, false)
		# The hub boss, its centre cap and the wheel nuts round it.
		k._add(pv, drum(rr * 0.34, rr * 0.34, w * 0.12, 16, false), hub_kind, hub_col, Vector3(side * w * 0.305, 0, 0), out, Vector3.ONE, false)
		k._add(pv, drum(rr * 0.15, rr * 0.16, w * 0.03, 12, false), hub_kind, Color(0.55, 0.56, 0.56) if dark else Color(0.12, 0.12, 0.13), Vector3(side * w * 0.375, 0, 0), out, Vector3.ONE, false)
		var nut := drum(maxf(0.008, r * 0.026), maxf(0.008, r * 0.026), 0.016, 6, false)
		for i in spokes:
			var a := TAU * (i + 0.5) / float(spokes)
			k._add(pv, nut, "steel", Color(0.52, 0.53, 0.52), Vector3(side * w * 0.37, cos(a) * rr * 0.23, sin(a) * rr * 0.23), out, Vector3.ONE, false)
	if register:
		# The tyre's inner opening closed in the dark of the wheel arch.
		var back: float = -float(faces[0])
		k._add(pv, drum(rr * 1.04, rr * 1.04, 0.01, 16, false), "rubber", Color(0.04, 0.04, 0.04), Vector3(back * w * 0.3, 0, 0), Vector3(0, 0, -back * PI / 2), Vector3.ONE, false)
	else:
		# A spare's carrier stud, through the centre to either face of the old hub.
		k._add(pv, drum(rr * 0.12, rr * 0.12, w * 0.89, 8), hub_kind, hub_col, Vector3.ZERO, AXLE, Vector3.ONE, false)
		k._fold(pv)
		return parent
	k.wheels.append(pv)
	return pv


## A car tyre's section, round the outside from the outer bead to the inner:
## the bead tucked under the rim's flange, the sidewall bulging past it, a
## rounded shoulder and a flat crown with two grooves. Cached by size.
static func _car_tyre(r: float, w: float, rr: float) -> ArrayMesh:
	var key := "car_tyre_%.3f_%.3f_%.3f" % [r, w, rr]
	if _meshes.has(key):
		return _meshes[key]
	var wall := r - rr
	var half: Array[Vector2] = [Vector2(0.39 * w, rr * 1.03), Vector2(0.462 * w, rr + wall * 0.32), Vector2(0.475 * w, rr + wall * 0.64),
		Vector2(0.44 * w, r - wall * 0.07), Vector2(0.37 * w, r)]
	var section := PackedVector2Array()
	for p in half:
		section.append(p)
	# Grooves steep enough that their edges stay crisp (see _lathe).
	for c: float in [0.17, -0.17]:
		section.append(Vector2((c + 0.025) * w, r))
		section.append(Vector2(c * w, r - minf(0.012, wall * 0.1)))
		section.append(Vector2((c - 0.025) * w, r))
	for i in range(half.size() - 1, -1, -1):
		section.append(Vector2(-half[i].x, half[i].y))
	_meshes[key] = _lathe(section, 32)
	return _meshes[key]


## What a tyre leaves when it burns: the rubber of its sidewalls and tread goes
## up, and the steel belt that ran under the crown is left as a ragged band of
## wire round where the crown was, so the rim shows inside it and the dark of
## the arch between. Placed 5% of the radius low on the axle, the band sags
## onto the ground under the rim it no longer holds up. A few millimetres of
## wire, wavering a little round the wheel (the surface shader draws it as
## rusted wire and ash: see the char finish). Cached by size.
static func _belt(r: float, w: float) -> ArrayMesh:
	var key := "belt_%.3f_%.3f" % [r, w]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var around := 24
	var hw := w * 0.36
	var th := maxf(0.006, r * 0.025)
	var mid: Array[Vector3] = []
	for i in around:
		var t := TAU * i / float(around)
		var out := Vector3(0, cos(t), sin(t))
		mid.append(out * r * (0.935 + 0.02 * sin(t * 3.0 + 1.3) + 0.012 * sin(t * 7.0 + 0.4)))
	for i in around:
		var a: Vector3 = mid[i]
		var b: Vector3 = mid[(i + 1) % around]
		var na := a.normalized() * th * 0.5
		var nb := b.normalized() * th * 0.5
		var x := Vector3(hw, 0, 0)
		var out := (a + b).normalized()
		_quad(verts, norms, idx, out, a + na - x, a + na + x, b + nb + x, b + nb - x)
		_quad(verts, norms, idx, -out, a - na - x, b - nb - x, b - nb + x, a - na + x)
		_quad(verts, norms, idx, Vector3.RIGHT, a - na + x, b - nb + x, b + nb + x, a + na + x)
		_quad(verts, norms, idx, Vector3.LEFT, a - na - x, a + na - x, b + nb - x, b - nb - x)
	_meshes[key] = _mesh(verts, norms, idx)
	return _meshes[key]


## The rim's visible steel: the barrel inside the spokes rising to the
## polished flange, whose rolled lip runs into the tyre's bead.
static func _car_rim(w: float, rr: float) -> ArrayMesh:
	var key := "car_rim_%.3f_%.3f" % [w, rr]
	if not _meshes.has(key):
		_meshes[key] = _lathe(PackedVector2Array([Vector2(0.12 * w, rr * 0.93), Vector2(0.3 * w, rr * 0.93), Vector2(0.38 * w, rr * 0.95),
			Vector2(0.42 * w, rr * 0.975), Vector2(0.43 * w, rr * 1.02), Vector2(0.4 * w, rr * 1.06)]), 32)
	return _meshes[key]


## A plain car's wheel trim: a domed disc from the badge to the flange, a
## dished ring where the vent slots are and a raised rim round its edge.
static func _car_trim(w: float, rr: float) -> ArrayMesh:
	var key := "car_trim_%.3f_%.3f" % [w, rr]
	if not _meshes.has(key):
		_meshes[key] = _lathe(PackedVector2Array([Vector2(0.445 * w, 0.0), Vector2(0.44 * w, rr * 0.2), Vector2(0.405 * w, rr * 0.42),
			Vector2(0.42 * w, rr * 0.8), Vector2(0.437 * w, rr * 0.9), Vector2(0.415 * w, rr * 0.985)]), 32)
	return _meshes[key]


## An alloy's spokes as one mesh: each runs from the hub boss out to the
## barrel, its face sloping back into the dish and ridged down its middle so
## one half catches the light; `twin` splits each into a pair that part
## toward the rim. Only what shows is drawn: the faces and the sides.
static func _car_spokes(w: float, rr: float, count: int, twin: bool) -> ArrayMesh:
	var key := "car_spokes_%.3f_%.3f_%d_%s" % [w, rr, count, twin]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var inner := rr * 0.3
	var outer := rr * 0.96
	var half_in := rr * (0.05 if twin else (0.11 if count == 5 else 0.09))
	var half_out := rr * (0.055 if twin else (0.16 if count == 5 else 0.13))
	var depth := w * 0.08
	for i in count:
		var a := TAU * i / float(count)
		for split: float in ([-0.14, 0.14] if twin else [0.0]):
			var ai := Vector3(0, cos(a), sin(a))
			var ao := Vector3(0, cos(a + split), sin(a + split))
			var ti := Vector3(0, -sin(a), cos(a))
			var to := Vector3(0, -sin(a + split), cos(a + split))
			var ci := ai * inner + Vector3.RIGHT * w * 0.36
			var co := ao * outer + Vector3.RIGHT * w * 0.31
			var ridge := Vector3.RIGHT * depth * 0.18
			for s: float in [-1.0, 1.0]:
				var ei := ci + ti * half_in * s
				var eo := co + to * half_out * s
				_quad_toward(verts, norms, idx, Vector3.RIGHT, ei, eo, co + ridge, ci + ridge)
				_quad_toward(verts, norms, idx, ti * s, ei, eo, eo - Vector3.RIGHT * depth, ei - Vector3.RIGHT * depth)
	_meshes[key] = _mesh(verts, norms, idx)
	return _meshes[key]


## A flat face of four corners, its normal from their cross product turned
## to the side `hint` points to.
static func _quad_toward(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, hint: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	if n.dot(hint) < 0.0:
		n = -n
	_quad(verts, norms, idx, n, p0, p1, p2, p3)


## A solid of revolution about the X axis (the axle): `section` runs (x,
## radius) round the outside of the part, its outward side on the right of
## the direction it runs in, and is turned through `around` steps. Normals
## are smooth across gentle bends and break at corners sharper than 50
## degrees, so a sidewall shades round while a groove's edge stays crisp.
static func _lathe(section: PackedVector2Array, around: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var bends: Array[Vector2] = []
	for i in section.size() - 1:
		var d := (section[i + 1] - section[i]).normalized()
		bends.append(Vector2(d.y, -d.x))
	for i in bends.size():
		var na := bends[i]
		var nb := bends[i]
		if i > 0 and bends[i - 1].dot(bends[i]) > 0.64:
			na = (bends[i - 1] + bends[i]).normalized()
		if i < bends.size() - 1 and bends[i + 1].dot(bends[i]) > 0.64:
			nb = (bends[i + 1] + bends[i]).normalized()
		var a := section[i]
		var b := section[i + 1]
		var base := verts.size()
		for j in around:
			var t := TAU * j / float(around)
			var c := cos(t)
			var s := sin(t)
			verts.append(Vector3(a.x, a.y * c, a.y * s))
			norms.append(Vector3(na.x, na.y * c, na.y * s))
			verts.append(Vector3(b.x, b.y * c, b.y * s))
			norms.append(Vector3(nb.x, nb.y * c, nb.y * s))
		for j in around:
			var p := base + j * 2
			var q := base + ((j + 1) % around) * 2
			var face := (norms[p] + norms[p + 1]).normalized()
			if b.y > 0.0001:
				_tri(idx, verts, face, p, p + 1, q + 1)
			if a.y > 0.0001:
				_tri(idx, verts, face, p, q + 1, q)
	return _mesh(verts, norms, idx)


## Cached unit rings keep rounded tyres and rim lips affordable across the roster.
static func ring(inner: float, outer: float) -> TorusMesh:
	var key := "tyre_ring_%s_%s" % [inner, outer]
	if not _rings.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 40
		mesh.ring_segments = 12
		_rings[key] = mesh
	return _rings[key]


## A cylinder as Res.cyl makes it (axis +Y, `top` radius at +Y) but without
## the ring of vertices half way up its side, which nothing on a wheel bends:
## a third fewer triangles. `base = false` leaves off the bottom cap, for a nut
## whose foot sits on the face it is screwed to.
static func drum(top: float, bottom: float, h: float, segs: int, base := true) -> CylinderMesh:
	return VehicleBody.drum(top, bottom, h, segs, true, base)


## The rim's rolled lip (ring(0.49, 0.55) as it was, scaled by the radius).
## Six sides round a tube a few centimetres thick, and the hub disc's 32
## round the wheel, read as round; a small wheel's lip is a few millimetres
## and needs four and sixteen.
static func _lip(fine: bool) -> TorusMesh:
	var key := "lip_%s" % fine
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.49
		mesh.outer_radius = 0.55
		mesh.rings = 32 if fine else 16
		mesh.ring_segments = 6 if fine else 4
		_meshes[key] = mesh
	return _meshes[key]


## The tyre's carcass: ring(0.5, 1.0)'s torus, laid out and scaled as it was
## (axis Y, a 0.25 tube round a 0.75 circle, forty slices) but without the
## innermost sixth of its section, the bead that runs inside the rim drum and
## never shows. The rest keeps the old vertices, so the tread, shoulders and
## sidewall are unchanged.
static func _carcass() -> ArrayMesh:
	if _meshes.has("carcass"):
		return _meshes["carcass"]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var around := 40
	# Twelve 30-degree steps round the section from its innermost point;
	# the two either side of that point are left out.
	var section := 12
	var row := section - 1
	for i in around:
		var u := TAU * i / float(around)
		var slice := Vector2(-sin(u), -cos(u))
		for j in range(1, section):
			var v := TAU * j / float(section)
			var n := Vector2(-cos(v), sin(v))
			var p := n * 0.25 + Vector2(0.75, 0)
			verts.append(Vector3(slice.x * p.x, p.y, slice.y * p.x))
			norms.append(Vector3(slice.x * n.x, n.y, slice.y * n.x))
	for i in around:
		var next := (i + 1) % around
		for j in row - 1:
			var a := i * row + j
			var b := next * row + j
			_tri(idx, verts, norms[a], a, b, b + 1)
			_tri(idx, verts, norms[a], a, b + 1, a + 1)
	_meshes["carcass"] = _mesh(verts, norms, idx)
	return _meshes["carcass"]


## The tread for an `r` by `w` tyre, as one mesh: two staggered rows of
## blocks round the crown, each placed and turned exactly as the separate
## blocks were. They were bevelled boxes; a bevel of a few millimetres on a
## matt rubber block is lost from any distance, so these are plain boxes,
## a quarter of the triangles.
static func _tread(r: float, w: float, offroad: bool) -> ArrayMesh:
	var key := "tread_%s_%.3f_%.3f" % [offroad, r, w]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var count := 36 if offroad else 48
	var half := Vector3(w * 0.43, r * (0.055 if offroad else 0.018), r * (0.13 if offroad else 0.095)) * 0.5
	for i in count:
		for row: float in [-1.0, 1.0]:
			var a := TAU * (float(i) + (0.45 if row > 0 else 0.0)) / float(count)
			var b := Basis.from_euler(Vector3(a, row * 0.20, 0))
			var c := Vector3(row * w * 0.24, cos(a) * r * 0.975, sin(a) * r * 0.975)
			for axis in 3:
				var n: Vector3 = b[axis]
				var u: Vector3 = b[(axis + 1) % 3] * half[(axis + 1) % 3]
				var v: Vector3 = b[(axis + 2) % 3] * half[(axis + 2) % 3]
				for s: float in [-1.0, 1.0]:
					var f := c + n * half[axis] * s
					_quad(verts, norms, idx, n * s, f - u - v, f + u - v, f + u + v, f - u + v)
	_meshes[key] = _mesh(verts, norms, idx)
	return _meshes[key]


## A flat face of four corners in order round it, facing `n`.
static func _quad(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, n: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var base := verts.size()
	for p: Vector3 in [p0, p1, p2, p3]:
		verts.append(p)
		norms.append(n)
	_tri(idx, verts, n, base, base + 1, base + 2)
	_tri(idx, verts, n, base, base + 2, base + 3)


## A triangle wound the way Godot draws front faces, seen from `n`'s side.
static func _tri(idx: PackedInt32Array, verts: PackedVector3Array, n: Vector3, a: int, b: int, c: int) -> void:
	idx.append(a)
	if (verts[b] - verts[a]).cross(verts[c] - verts[a]).dot(n) > 0.0:
		idx.append(c)
		idx.append(b)
	else:
		idx.append(b)
		idx.append(c)


## A mesh made here, keeping its arrays so the bake never reads it back.
static func _mesh(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	return mesh


## Twin road wheels leave space for the track guide teeth. Spoked wheels retain
## their characteristic pressed ribs; rubber tyres never receive road tread.
static func road(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, mat := "gunmetal_w", col = null, spokes := 0, rubber := true) -> Node3D:
	var pv := k._pivot(parent, pos)
	var outer := signf(pos.x) if pos.x != 0 else 1.0
	for side: float in [-1.0, 1.0]:
		var x: float = side * w * 0.30
		k._add(pv, drum(r, r, w * 0.38, 28), "rubber" if rubber else "gunmetal_w", null, Vector3(x, 0, 0), AXLE)
		k._add(pv, drum(r * 0.82, r * 0.77, w * 0.40, 28), mat, col, Vector3(x, 0, 0), AXLE)
		k._add(pv, drum(r * 0.66, r * 0.66, w * 0.41, 24), mat, col, Vector3(x, 0, 0), AXLE, Vector3.ONE, false)
		# The inboard twin's bolts face the hull side, behind the track; a
		# wheel on its parent's centre line keeps both faces' bolts.
		if pos.x != 0.0 and side != outer:
			continue
		var nut := drum(r * 0.03, r * 0.03, 0.025, 6, false)
		for i in 8:
			var a := TAU * i / 8.0
			k._add(pv, nut, "gunmetal_w", null, Vector3(side * w * 0.52, sin(a) * r * 0.47, cos(a) * r * 0.47), Vector3(0, 0, -side * PI / 2), Vector3.ONE, false)
	k._add(pv, drum(r * 0.24, r * 0.28, w + 0.06, 16), mat, col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	for i in spokes:
		var a := TAU * i / float(spokes)
		k._box(pv, Vector3(0.025, r * 0.44, r * 0.18), Vector3(outer * w * 0.52, sin(a) * r * 0.53, cos(a) * r * 0.53), mat, col, Vector3(-a + PI / 2, 0, 0), false)
	k.wheels.append(pv)
	return pv


## Track return roller (support roller): one of the small wheels above the road
## wheels that carry the top run of the track. `pos`, `r` and `w` are the old
## disc's centre, radius and width, the axle along X as on road wheels. Twin
## rubber tyres leave the gap the guide horns run through; the pressed disc
## face, a hub that runs on through the inboard side as its stub axle, and the
## hub bolts on the outer face (the side pos.x points to). Rollers are static:
## nothing is registered, so the wheel animation is unchanged.
static func roller(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, mat := "gunmetal_w", col = null) -> void:
	var pv := k._pivot(parent, pos)
	# Up to eight a vehicle, mostly behind the skirts: a few cheap cylinders.
	for side: float in [-1.0, 1.0]:
		k._add(pv, drum(r, r, w * 0.28, 10), "rubber", null, Vector3(side * w * 0.36, 0, 0), AXLE, Vector3.ONE, false)
	k._add(pv, drum(r * 0.76, r * 0.76, w * 1.02, 10), mat, col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	k._add(pv, drum(r * 0.28, r * 0.32, w + 0.04, 8), mat, col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	var outer := signf(pos.x) if pos.x != 0 else 1.0
	var nut := drum(r * 0.05, r * 0.05, 0.014, 6, false)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		k._add(pv, nut, "gunmetal_w", null, Vector3(outer * (w * 0.51 + 0.004), sin(a) * r * 0.48, cos(a) * r * 0.48), Vector3(0, 0, -outer * PI / 2), Vector3.ONE, false)
	k._fold(pv)


## A spare shares the running tyre's construction but never a rotating pivot.
## Rotation follows CylinderMesh convention: its unrotated axle points up.
static func spare(k: VehicleModels, parent: Node3D, pos: Vector3, radius: float, width: float, rot := Vector3.ZERO, mat := "gunmetal_w", col = null, profile := "offroad") -> void:
	var mount := k._pivot(parent, pos)
	mount.basis = Basis.from_euler(rot) * Basis.from_euler(AXLE).inverse()
	pneumatic(k, mount, Vector3.ZERO, radius, width, mat, col, profile, false)
	k._fold(mount)


## The hardware that holds a spare: call it beside `spare` with the spare's own
## `pos`, `radius`, `width` and `rot` (the wheel stays spare's job). `mount` is
## where the carrier meets the vehicle, and `style` how it holds the wheel:
## - "hub": bolted through its centre to a carrier on a door, tailgate, cab or
##   panel behind it. `mount` is a point on that panel: the backing plate is
##   bolted there, and a strut runs from it to the hub plate, rising from a
##   lower edge if the wheel stands above the panel's top.
## - "swing": on a swing-out carrier. `mount` is the hinge, on the body's face
##   at the arm's height; the arm runs level behind the wheel from it to a
##   latch just past the wheel, and an upright on the arm carries the hub plate.
## - "cradle": standing on a floor, deck or the chassis rails, whose top is
##   `mount`'s height (up to 12 cm under the tread): a cradle bar and chocks
##   under the tread, a U-bolt up both faces and through the centre.
## - "strap": lying on a bed floor, a ratchet strap from a tie-down ring on
##   the floor at `mount` (a free spot beside the wheel) up over the tread and
##   across the top face to a clamp bar on the hub, whose hook bolt runs down
##   through the centre hole to the floor.
## The upright styles clamp the wheel with a nut and tommy bar on its outer
## face: the face away from `mount`, or, with `mount` in the wheel's own
## plane, the face `rot` turns +Y toward (the rear for a spare turned by X90).
## Builds nothing that turns and registers nothing. Stays within the wheel but
## for the bracket between it and `mount`, the clamp nut up to 2.5 cm proud of
## the tyre, the swing arm's latch and hinge leaves, and the strap's ring plate
## 4 cm round `mount`.
static func carrier(k: VehicleModels, parent: Node3D, pos: Vector3, radius: float, width: float, rot: Vector3, style: String, mount: Vector3, mat := "gunmetal_w", col = null) -> void:
	var r := radius
	var hw := width * 0.5
	var hub := width * 0.445  # the ends of pneumatic's hub
	var axle := (Basis.from_euler(rot) * Vector3.UP).normalized()
	var pv := k._pivot(parent, pos)
	if style == "strap":
		# The pivot's +Z is the upper face, +X the run toward the ring.
		var top := axle if axle.y >= 0.0 else -axle
		var run := mount - pos
		run -= top * top.dot(run)
		if run.length() < 0.01:
			run = Vector3.RIGHT - top * top.dot(Vector3.RIGHT)
		run = run.normalized()
		pv.basis = Basis(run, top.cross(run), top)
		_strap(k, parent, pv, pos, mount, r, hw, hub)
		k._fold(pv)
		return
	# The pivot's +Z is the outer face, +Y up the wheel, +X across it.
	var off := (mount - pos).dot(axle)
	var out := axle if absf(off) < 0.01 else -signf(off) * axle
	var up := (Vector3.UP - out * out.dot(Vector3.UP)).normalized()
	pv.basis = Basis(up.cross(out), up, out)
	var at := pv.basis.inverse() * (mount - pos)
	var face := hub
	match style:
		"hub":
			# The backing plate bolted to the panel, a strut out to the hub plate.
			var d := maxf(-at.z, hub + 0.012)
			var plate := clampf(r * 0.55, 0.12, 0.34)
			var back := Vector3(at.x, at.y, -d)
			k._add(pv, BevelMesh.make(Vector3(plate, plate, 0.012), 0.004), mat, col, back + Vector3(0, 0, 0.006))
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					VehicleBody.fastener(k, pv, back + Vector3(sx * plate * 0.36, sy * plate * 0.36, 0.015), Vector3.BACK)
			# The strut: square on the axle, or a web up to the hub from a plate
			# set lower on the panel.
			var strut := clampf(r * 0.22, 0.06, 0.14)
			var z0 := -d + 0.012
			var depth := maxf(-hub - 0.012 - z0, 0.012)
			if depth > 0.012 or Vector2(at.x, at.y).length() > 0.01:
				k._box(pv, Vector3(absf(at.x) + strut, absf(at.y) + strut, depth), Vector3(at.x * 0.5, at.y * 0.5, z0 + depth * 0.5), mat, col)
			_hub_plate(k, pv, -hub - 0.012, hub, r, mat, col)
		"swing":
			# The arm and upright fill the gap between the body and the tyre.
			var sec := clampf(r * 0.15, 0.05, 0.1)
			var side := signf(at.x) if at.x != 0.0 else -1.0
			var t := clampf(-hw - at.z - 0.004, 0.02, sec)
			var z := at.z + 0.002 + t * 0.5
			var latch := -side * r * 0.55
			k._box(pv, Vector3(absf(latch - at.x), sec, t), Vector3((latch + at.x) * 0.5, at.y, z), mat, col)
			var foot := at.y - sec * 0.5
			var head := r * 0.35
			k._box(pv, Vector3(sec * 1.2, head - foot, t), Vector3(0, (head + foot) * 0.5, z), mat, col)
			VehicleDoors.hinge(k, pv, at, Vector3.BACK, Vector3.UP, 0.022, mat, col)
			# The latch: a keeper on the body past the arm's end, the pin
			# dropped through both.
			k._box(pv, Vector3(0.03, sec * 1.3, 0.016), Vector3(latch - side * 0.015, at.y, at.z + 0.008), mat, col)
			VehicleFrames.tube(k, pv, Vector3(latch + side * 0.012, at.y - sec * 0.75, z), Vector3(latch + side * 0.012, at.y + sec * 0.75, z), 0.008, "steel", null, 6, false)
			_hub_plate(k, pv, z + t * 0.5, hub, r, mat, col)
		"cradle":
			# The cradle bar pressed a centimetre into the tread, on its support.
			var low := -r + 0.01
			var bh := clampf(low - at.y, 0.03, 0.12)
			k._box(pv, Vector3(r * 1.6, bh, width * 0.5), Vector3(0, low - bh * 0.5, 0), mat, col)
			for s: float in [-1.0, 1.0]:
				var x := s * r * 0.55
				var ch := -sqrt(r * r - x * x) + 0.01 - low
				k._box(pv, Vector3(r * 0.16, ch, width * 0.8), Vector3(x, low + ch * 0.5, 0), mat, col)
			# The U-bolt: a flat bar up each face, over the tyre's lower wall
			# and in to a clamp plate on the hub.
			for f: float in [-1.0, 1.0]:
				var a := Vector3(0, low, f * (hw + 0.012))
				var b := Vector3(0, -r * 0.55, f * (hw + 0.012))
				VehicleFrames.beam(k, pv, a, b, 0.035, 0.012, mat, col)
				VehicleFrames.beam(k, pv, b, Vector3(0, 0, f * (hub + 0.012)), 0.035, 0.012, mat, col)
				k._add(pv, drum(r * 0.14, r * 0.14, 0.012, 10), mat, col, Vector3(0, 0, f * (hub + 0.006)), Vector3(PI / 2, 0, 0), Vector3.ONE, false)
			face = hub + 0.012
	# The clamp nut on the outer face (its foot against it), a tommy bar
	# through it.
	var nut := maxf(0.025, r * 0.075)
	k._add(pv, drum(nut, nut, 0.025, 6, false), "gunmetal_w", null, Vector3(0, 0, face + 0.0125), Vector3(PI / 2, 0, 0), Vector3.ONE, false)
	k._box(pv, Vector3(r * 0.4, 0.014, 0.014), Vector3(0, 0, face + 0.016), "steel", null, Vector3.ZERO, false)
	k._fold(pv)


## The hub plate a spare is bolted to, from `back` (the carrier's face) to the
## inner end of the wheel's hub.
static func _hub_plate(k: VehicleModels, pv: Node3D, back: float, hub: float, r: float, mat: String, col) -> void:
	var thick := maxf(0.012, -hub - back)
	k._add(pv, drum(r * 0.3, r * 0.3, thick, 12), mat, col, Vector3(0, 0, -hub - thick * 0.5), Vector3(PI / 2, 0, 0), Vector3.ONE, false)


## A ratchet strap holding down a spare that lies on a bed floor (see
## carrier): in the pivot's frame the wheel's upper face is +Z and the ring at
## `mount` lies along +X. The strap climbs the tread's shoulder, crosses the
## top face and drops into the rim to the clamp bar on the hub.
static func _strap(k: VehicleModels, parent: Node3D, pv: Node3D, pos: Vector3, mount: Vector3, r: float, hw: float, hub: float) -> void:
	var flat := Vector3(pv.basis.x.x, 0, pv.basis.x.z).normalized()
	k._box(parent, Vector3(0.07, 0.008, 0.05), mount + Vector3(0, 0.004, 0), "steel", null, Vector3(0, atan2(flat.x, flat.z), 0))
	k._add(parent, VehicleCargo._ring(0.022, 0.005), "steel", null, mount + Vector3(0, 0.013, 0))
	var ring := pv.basis.inverse() * (mount + Vector3(0, 0.013, 0) - pos)
	var web := Color(0.2, 0.2, 0.16)
	var points: Array[Vector3] = [ring, Vector3(r + 0.008, 0, hw * 0.92), Vector3(r * 0.7, 0, hw + 0.006), Vector3(r * 0.28, 0, hub + 0.008), Vector3(0, 0, hub + 0.008)]
	for i in points.size() - 1:
		_band(k, pv, points[i], points[i + 1], 0.04, 0.004, "webbing", web)
	# The ratchet on the run down to the ring; the clamp bar across the hub.
	_band(k, pv, points[1].lerp(ring, 0.3), points[1].lerp(ring, 0.6), 0.055, 0.03, "steel", null)
	k._box(pv, Vector3(0.014, r * 0.4, 0.014), Vector3(0, 0, hub + 0.017), "steel", null, Vector3.ZERO, false)


## A flat strip from `a` to `b`, `width` across in the pivot's Y and `thick`.
static func _band(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, width: float, thick: float, mat: String, col) -> void:
	var along := (b - a).normalized()
	var x := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	k._box(parent, Vector3(width, a.distance_to(b), thick), (a + b) * 0.5, mat, col, Basis(x, along, x.cross(along)).get_euler(), false)


## Shared drive wheel: teeth remain separate from the smooth road-wheel rim.
## The hub uses the existing X-axis animation contract, exactly one registration.
static func sprocket(k: VehicleModels, parent: Node3D, pos: Vector3, radius: float, width: float, mat: String, col = null, teeth := 8, twin := false) -> Node3D:
	var pv := k._pivot(parent, pos)
	var rows: Array = [-0.3, 0.3] if twin else [0.0]
	for row: float in rows:
		var w := width * (0.2 if twin else 0.7)
		k._add(pv, drum(radius * 0.86, radius * 0.86, w, 20), "gunmetal_w", null, Vector3(row * width, 0, 0), AXLE)
		# One tooth shape serves the ring.
		var tooth := BevelMesh.make(Vector3(w, radius * 0.20, radius * 0.16), radius * 0.025)
		for i in teeth:
			var a := TAU * i / float(teeth)
			k._add(pv, tooth, "gunmetal_w", null, Vector3(row * width, sin(a) * radius * 0.9, cos(a) * radius * 0.9), Vector3(-a, 0, 0))
	k._add(pv, drum(radius * 0.66, radius * 0.70, width * 0.76, 20), mat, col, Vector3.ZERO, AXLE)
	k._add(pv, drum(radius * 0.25, radius * 0.30, width + 0.06, 12), mat, col, Vector3.ZERO, AXLE, Vector3.ONE, false)
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var a := TAU * i / 6.0
			VehicleBody.fastener(k, pv, Vector3(side * width * 0.39, sin(a) * radius * 0.47, cos(a) * radius * 0.47), Vector3.RIGHT * side, radius * 0.045)
	k.wheels.append(pv)
	return pv
