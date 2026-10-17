class_name WorksModels
extends RefCounted
## The field defences, modelled on the real things and built where the
## structure's parts (its cover and collision) already are. Local -z faces the
## enemy, y = 0 is the ground.
##
##   wire        - triple-strand concertina: two coils of razor wire side by
##                 side on the ground, a third in the groove on top, wired to
##                 steel pickets (wooden stakes for the Rebels), a barbed strand
##                 strained along each row of pickets
##   tank_trap   - a Czech hedgehog: three steel angles (Rebels: old rails) at
##                 right angles through one point, gusseted and bolted, standing
##                 on three ends
##   mines       - the mines dug in under rings of loosened earth, a cordon of
##                 pickets and tape round the field, red triangles hung on it
##                 (only its own side ever sees any of this)
##   concrete_wall - precast T-walls: slabs on a wide foot, haunched, with
##                 lifting loops, set side by side
##   hesco       - a line of HESCO cells: welded mesh lined with geotextile,
##                 filled with earth, coil joints at the corners
##   barricade   - the Rebels' improvised wall: oil drums, tyres, a sheet of
##                 roofing, rubble, pallets and sacks, whatever was to hand
##   ammo_cache  - stores on pallets under a tarp: cans and crates of rounds,
##                 rockets and grenades, a red flag on a stake
##   camo_net    - a camouflage net pitched over a centre pole and draped to the
##                 ground on four corner poles, guyed out
## and the weapons in the mortar pit and the anti-tank post.

const OD := Color(0.36, 0.38, 0.26)  # olive drab
const OD_DARK := Color(0.25, 0.27, 0.19)
const RUST := Color(0.36, 0.2, 0.11)
const ROUND_OD := Color(0.3, 0.33, 0.22)
const ROUND_BAND := Color(0.75, 0.62, 0.2)  # the yellow band on HE

## Kinds whose parts aren't drawn as plain boxes (the model is all their own).
const OWN_KINDS := ["wire", "tank_trap", "mines", "concrete_wall", "hesco", "barricade", "ammo_cache", "camo_net"]


## Builds the model of a work into `model`. Returns the nodes to leave out of
## the static merge (meshes shared between every copy). Sandbags go into
## `bags` (see Structure._bag_walls).
static func build(st, model: Node3D, rng: RandomNumberGenerator, bags: Array) -> Array:
	var rebel: bool = st.team == 1
	var L: float = st.size.x
	match String(st.skind):
		"wire":
			return _wire(model, L, rebel, rng)
		"tank_trap":
			_hedgehog(model, rebel, rng)
		"mines":
			_minefield(model, rebel, rng)
		"concrete_wall":
			_twalls(model, L, rng)
		"hesco":
			_hesco(model, L, rng)
		"barricade":
			_barricade(model, L, rng, bags)
		"ammo_cache":
			_ammo_cache(model, rebel, rng, bags)
		"camo_net":
			return _camo_net(model, rebel, rng)
		"mortar_pit":
			_mortar(model, rebel, rng)
		"at_post":
			_at_weapon(model, rebel, rng)
	return []


# --- helpers ---------------------------------------------------------------------------

static func _mk(root: Node3D, mesh: Mesh, kind: String, p: Vector3, rot := Vector3.ZERO, col = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	Mats.apply(mi, kind, Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1))
	return mi


static func _xf(root: Node3D, mesh: Mesh, kind: String, xf: Transform3D, col = null, shadow := true) -> MeshInstance3D:
	var mi := _mk(root, mesh, kind, Vector3.ZERO, Vector3.ZERO, col, shadow)
	mi.transform = xf
	return mi


## A rod (a pole, a picket, a leg, a rope) from a to b.
static func _rod(root: Node3D, a: Vector3, b: Vector3, r: float, kind: String, col = null, segs := 6, shadow := true) -> MeshInstance3D:
	var y := b - a
	var ln := y.length()
	y /= ln
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return _xf(root, Res.cyl(r, r, 1.0, segs), kind, Transform3D(Basis(x, y * ln, z), (a + b) * 0.5), col, shadow)


## A box along `ax` (its length), turned so its local x lies along `side`.
static func _beam(root: Node3D, c: Vector3, ax: Vector3, side: Vector3, s: Vector3, kind: String, col = null) -> MeshInstance3D:
	var up := ax.cross(side).normalized()
	return _xf(root, Res.box(s), kind, Transform3D(Basis(side, up, ax), c), col)


## A triangle (a, b, c) with per-corner normals, wound the way Godot draws
## front faces whichever way it was given.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		v.append_array([a, c, b])
		n.append_array([na, nc, nb])
	else:
		v.append_array([a, b, c])
		n.append_array([na, nb, nc])


static func _commit(v: PackedVector3Array, n: PackedVector3Array, uv := PackedVector2Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static var _meshes := {}


## A wire along `pts`: a thin three-sided tube, its frame carried along so it
## doesn't twist.
static func _wire_tube(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, r: float) -> void:
	var up := Vector3.UP
	var last: Array = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := t.cross(up)
		if side.length_squared() < 1e-6:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		up = side.cross(t).normalized()
		var ring: Array = []
		for k in 3:
			var a := TAU * k / 3.0
			var d := side * cos(a) + up * sin(a)
			ring.append([pts[i] + d * r, d])
		if not last.is_empty():
			for k in 3:
				var k2 := (k + 1) % 3
				var a0: Array = last[k]
				var a1: Array = last[k2]
				var b0: Array = ring[k]
				var b1: Array = ring[k2]
				_tri(v, n, a0[0], b0[0], b1[0], a0[1], b0[1], b1[1])
				_tri(v, n, a0[0], b1[0], a1[0], a0[1], b1[1], a1[1])
		last = ring


## Barbs every `every` metres along the wire: little four-pointed stars of
## sharpened wire (razor tape's blades read the same from any distance).
static func _barbs(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, every: float, size: float, rng: RandomNumberGenerator) -> void:
	var run := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		run += seg.length()
		if run < every:
			continue
		run = 0.0
		var t := seg.normalized()
		var s := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		var u := s.cross(t)
		var a := rng.randf() * TAU
		var d1 := (s * cos(a) + u * sin(a)) * size
		var d2 := (s * -sin(a) + u * cos(a)) * size
		var p := pts[i]
		for d in [d1, d2]:
			var tip0: Vector3 = p + d
			var tip1: Vector3 = p - d
			var w: Vector3 = t * size * 0.35
			var nn: Vector3 = (d as Vector3).cross(t).normalized()
			_tri(v, n, tip0, p + w, tip1, nn, nn, nn)
			_tri(v, n, tip0, tip1, p + w, -nn, -nn, -nn)
			_tri(v, n, tip0, p - w, tip1, -nn, -nn, -nn)
			_tri(v, n, tip0, tip1, p - w, nn, nn, nn)


# --- the ground round a work -----------------------------------------------------------

## The earth trodden bare and spilled round the foot of a work, `hx` by `hz`
## (half extents), a low lens of it so the work sits in the ground, not on it.
static func apron(model: Node3D, hx: float, hz: float) -> void:
	var a := _mk(model, Res.dome(1.0, 14), "earth", Vector3(0, -0.03, 0), Vector3.ZERO, Color(0.29, 0.23, 0.16), false)
	a.scale = Vector3(hx, 0.1, hz)


## A floor dug out and trodden flat, `r` across from the middle.
static func pit_floor(model: Node3D, r: float) -> void:
	_mk(model, Res.cyl(r, r + 0.1, 0.03, 16), "earth", Vector3(0, 0.0, 0), Vector3.ZERO, Color(0.2, 0.16, 0.11), false)


## Earth banked against the outside of the walls of a square position
## `half` from its middle, `h` high (up to the slits) and running out `depth`
## from the wall, rounded over and dying away at the corners. `all_sides`:
## round the back too, either side of the door.
static func berms(model: Node3D, half: float, h: float, depth: float, all_sides: bool) -> void:
	var full := _bank_mesh(h, depth, half * 2.0 + depth * 1.2)
	var part := _bank_mesh(h, depth, half + 0.2)
	var col := Color(0.29, 0.27, 0.17)
	for a in 4:
		var n := Basis(Vector3.UP, PI + a * PI * 0.5) * Vector3(0, 0, 1)
		var rot := Vector3(0, PI + a * PI * 0.5, 0)
		if a == 2:
			if not all_sides:
				continue
			for sx in [-1.0, 1.0]:
				_mk(model, part, "bank", n * half + Vector3(sx * (half * 0.5 + 0.85), 0, 0), rot, col)
			continue
		_mk(model, full, "bank", n * half, rot, col)


## A bank of earth `length` long (along local x), `h` high against a wall at
## z = 0, rounding over and down to the ground `depth` out along +z, falling
## away to nothing at both ends. Smooth normals, a few lumps.
static func _bank_mesh(h: float, depth: float, length: float) -> ArrayMesh:
	var key := "bank%.2f,%.2f,%.2f" % [h, depth, length]
	if _meshes.has(key):
		return _meshes[key]
	var nu := maxi(6, int(length / 0.35))
	var ns := 8
	var hl := length * 0.5
	var pos: Array = []
	for j in ns + 1:
		var row: Array = []
		for i in nu + 1:
			var u := -hl + length * float(i) / nu
			var t := float(j) / ns
			var taper := smoothstep(hl, hl - depth * 1.1, absf(u))
			var y := h * pow(cos(t * PI * 0.5), 1.25) * taper
			y += 0.035 * sin(u * 3.1 + t * 2.0) * sin(t * PI) * taper
			# the toe runs out a little further where the bank is highest
			row.append(Vector3(u, maxf(y, 0.0) - 0.02, t * depth * (0.75 + 0.25 * taper)))
		pos.append(row)
	var nrm: Array = []
	for j in ns + 1:
		var row2: Array = []
		for i in nu + 1:
			var du: Vector3 = pos[j][mini(i + 1, nu)] - pos[j][maxi(i - 1, 0)]
			var dt: Vector3 = pos[mini(j + 1, ns)][i] - pos[maxi(j - 1, 0)][i]
			var nn := dt.cross(du).normalized()
			if nn.y < 0.0:
				nn = -nn
			row2.append(nn)
		nrm.append(row2)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for j in ns:
		for i in nu:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Array = q[tri[0]]
				var b: Array = q[tri[1]]
				var c: Array = q[tri[2]]
				_tri(v, n, pos[a[1]][a[0]], pos[b[1]][b[0]], pos[c[1]][c[0]], nrm[a[1]][a[0]], nrm[b[1]][b[0]], nrm[c[1]][c[0]])
	var m := _commit(v, n)
	_meshes[key] = m
	return m


# --- the watchtower --------------------------------------------------------------------

## The watchtower's timberwork round its legs and platform: X braces on every
## face and a girt halfway up, a ladder up the back, a single-pitch tin roof on
## four posts, a row of sandbags along the front rail and a searchlight on the
## corner.
static func tower(model: Node3D, rng: RandomNumberGenerator, bags: Array) -> void:
	var wc := Color(0.46, 0.34, 0.21)
	var l := 1.2
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		var a0 := b * Vector3(-l, 0.35, l)
		var a1 := b * Vector3(l, 3.85, l)
		var c0 := b * Vector3(l, 0.35, l)
		var c1 := b * Vector3(-l, 3.85, l)
		_rod(model, a0, a1, 0.045, "wood", wc, 6)
		_rod(model, c0, c1, 0.045, "wood", wc, 6)
		_rod(model, b * Vector3(-l, 2.1, l + 0.06), b * Vector3(l, 2.1, l + 0.06), 0.05, "wood", wc.darkened(0.08), 6)
	# the ladder up the back
	for sx in [-0.24, 0.24]:
		_rod(model, Vector3(sx, 0.0, 1.95), Vector3(sx, 4.2, 1.42), 0.035, "wood", wc, 5)
	for i in 13:
		var t := (i + 0.6) / 13.6
		var p := Vector3(0, t * 4.2, lerpf(1.95, 1.42, t))
		_rod(model, p + Vector3(-0.24, 0, 0), p + Vector3(0.24, 0, 0), 0.02, "wood", wc.lightened(0.05), 4, false)
	# the roof: corrugated tin on four posts, falling to the back
	for x in [-1.3, 1.3]:
		for z in [-1.3, 1.3]:
			_rod(model, Vector3(x, 5.0, z), Vector3(x, 6.72 - z * 0.09, z), 0.05, "wood", wc, 5)
	_mk(model, Res.box(Vector3(3.7, 0.03, 3.75)), "corrugated", Vector3(0, 6.76, 0), Vector3(0.09, 0, 0), Color(0.46, 0.45, 0.42))
	bags.append({"p": Vector3(0, 5.27, -1.45), "s": Vector3(3.0, 0.19, 0.38), "r": 0.0})
	# a searchlight on the front corner, on its yoke
	var sl := Vector3(1.2, 5.52, -1.38)
	_mk(model, Res.cyl(0.04, 0.05, 0.18, 6), "metal_dark", sl + Vector3(0, -0.1, 0))
	_mk(model, Res.cyl(0.15, 0.13, 0.32, 12), "paint", sl + Vector3(0, 0.08, 0), Vector3(PI * 0.5 - 0.15, rng.randf_range(-0.4, 0.4), 0), OD_DARK)
	_mk(model, Res.cyl(0.13, 0.13, 0.01, 12), "glass", sl + Vector3(0, 0.1, -0.17), Vector3(PI * 0.5 - 0.15, 0, 0), null, false)


# --- barbed wire -----------------------------------------------------------------------

## Triple-strand concertina, `L` metres of it: two coils on the ground side by
## side and one on top in the groove between them, each a stretched-out coil of
## barbed tape, every loop a little kinked and squashed where it was clipped to
## its neighbour; a barbed strand strained along the top of each row of
## pickets. One mesh per length and pattern, shared by every stretch of wire.
static func _concertina(L: float, v: int) -> ArrayMesh:
	var key := "concertina%.2f/%d" % [L, v]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421 + v * 977
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var r := 0.31
	var coils := [Vector3(0, r * 0.95, -0.29), Vector3(0, r * 0.95, 0.29), Vector3(0, r * 0.95 + 0.5, 0.0)]
	for ci in coils.size():
		var c: Vector3 = coils[ci]
		var loops := int(L / 0.24) + (ci % 2)
		var steps := loops * 18
		var ph := rng.randf() * TAU
		var pts := PackedVector3Array()
		var kink := rng.randf() * TAU
		for i in steps + 1:
			var t := float(i) / steps
			var a := ph + t * loops * TAU
			var x := -L * 0.5 + 0.06 + t * (L - 0.12)
			var rr := r * (1.0 + 0.08 * sin(a * 3.0 + kink) + 0.04 * sin(t * 37.0 + ci))
			# the loops lean along the run as it's pulled out, and the coil sags
			# a little between the points where it's pegged down
			var sag := 0.035 * sin(t * PI * 2.0 * maxf(1.0, L / 2.5)) if ci == 2 else 0.0
			pts.append(Vector3(x + 0.05 * sin(a), c.y + rr * sin(a) * 0.92 - sag, c.z + rr * cos(a)))
		_wire_tube(vv, nn, pts, 0.0105)
		_barbs(vv, nn, pts, 0.085, 0.028, rng)
	# the strained strands along the picket rows
	for sz in [-0.62, 0.62]:
		var pts2 := PackedVector3Array()
		for i in 33:
			var t := float(i) / 32.0
			pts2.append(Vector3(-L * 0.5 + 0.1 + t * (L - 0.2), 1.02 - 0.03 * sin(t * PI * 2.0), sz))
		_wire_tube(vv, nn, pts2, 0.006)
		_barbs(vv, nn, pts2, 0.12, 0.02, rng)
	var m := _commit(vv, nn)
	_meshes[key] = m
	return m


static func _wire(model: Node3D, L: float, rebel: bool, rng: RandomNumberGenerator) -> Array:
	var coil := MeshInstance3D.new()
	coil.mesh = _concertina(L, rng.randi() % 3)
	model.add_child(coil)
	# new galvanised wire for the Coalition; the Rebels' has been out in the rain
	Mats.apply(coil, "wire", Color(0.82, 0.74, 0.62) if rebel else Color(1, 1, 1))
	coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# pickets along both rows, staggered: steel U-pickets (or cut stakes),
	# driven in at a slight lean, the strand wired to their tops
	for row in 2:
		var sz := -0.62 if row == 0 else 0.62
		var n := maxi(2, int(round(L / 2.4)) + 1)
		for i in n:
			var x := -L * 0.5 + 0.15 + (L - 0.3) * float(i) / (n - 1) + (0.35 if row == 1 and i < n - 1 else 0.0)
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.06, 0.06) + (-0.05 if row == 0 else 0.05))
			var top := Vector3(x, 1.08, sz) + lean
			if rebel:
				_rod(model, Vector3(x, -0.1, sz), top, 0.035, "wood_dark", null, 6)
			else:
				var ax := (top - Vector3(x, -0.1, sz)).normalized()
				var c := (top + Vector3(x, -0.1, sz)) * 0.5
				_beam(model, c, ax, Vector3(1, 0, 0), Vector3(0.05, 0.012, 1.2), "paint", OD_DARK)
				_beam(model, c + Vector3(0, 0, 0.02), ax, Vector3(0, 0, 1), Vector3(0.04, 0.012, 1.2), "paint", OD_DARK)
	# the ground trampled bare along the line
	var scuff := _mk(model, Res.dome(1.0, 12), "earth", Vector3(0, -0.01, 0), Vector3.ZERO, Color(0.27, 0.22, 0.15), false)
	scuff.scale = Vector3(L * 0.5 + 0.3, 0.05, 0.8)
	return [coil]


# --- tank traps ------------------------------------------------------------------------

## A Czech hedgehog: three 2.2 m beams at right angles to each other through
## one point, standing on three of their ends (each beam 54.7 degrees off the
## vertical), so a tank that climbs it is lifted onto its belly. Steel angle
## gusseted and bolted at the crossing for the Coalition; lengths of old rail
## welded together, rusted brown, for the Rebels.
static func _hedgehog(model: Node3D, rebel: bool, rng: RandomNumberGenerator) -> void:
	var L := 2.2
	var th := acos(1.0 / sqrt(3.0))
	var c := Vector3(0, L * 0.5 * cos(th) - 0.04, 0)
	var phi0 := rng.randf() * TAU
	var col: Color = Color(0.36, 0.23, 0.14) if rebel else Color(0.3, 0.29, 0.26)
	var kind := "rust_steel" if rebel else "steel"
	var axes: Array[Vector3] = []
	for k in 3:
		var phi := phi0 + k * TAU / 3.0
		axes.append(Vector3(sin(th) * cos(phi), cos(th), sin(th) * sin(phi)))
	for k in 3:
		var ax: Vector3 = axes[k]
		# the beam's own frame: one flange (or the rail's foot) square to the
		# next beam round, so the three nest together at the crossing
		var side: Vector3 = axes[(k + 1) % 3]
		var up: Vector3 = ax.cross(side)
		if rebel:
			# a rail: head, web and foot
			_beam(model, c + up * 0.065, ax, side, Vector3(0.07, 0.045, L), kind, col)
			_beam(model, c, ax, side, Vector3(0.018, 0.1, L), kind, col)
			_beam(model, c - up * 0.065, ax, side, Vector3(0.14, 0.014, L), kind, col)
		else:
			# an angle: two flanges at right angles, the corner on the axis
			_beam(model, c + side * 0.06, ax, side, Vector3(0.12, 0.014, L), kind, col)
			_beam(model, c + up * 0.06, ax, side, Vector3(0.014, 0.12, L), kind, col)
		# the end that bears on the ground has bitten into it
		var foot := c - ax * L * 0.5
		var mound := _mk(model, Res.dome(0.2, 8), "earth", Vector3(foot.x, -0.02, foot.z), Vector3.ZERO, Color(0.24, 0.19, 0.13), false)
		mound.scale = Vector3(1.0, 0.35, 1.0)
	# gussets where the beams cross, bolted through
	for k in 3:
		var nrm: Vector3 = axes[k]
		var a: Vector3 = axes[(k + 1) % 3]
		var pc := c - nrm * 0.075 + (a + axes[(k + 2) % 3]) * 0.07
		if rebel:
			# (welded: a fat bead of weld and spatter, no plates)
			_xf(model, Res.box(Vector3(0.09, 0.09, 0.03)), kind, Transform3D(Basis(a, nrm.cross(a), nrm), pc), col.darkened(0.2))
			continue
		_xf(model, Res.box(Vector3(0.26, 0.26, 0.012)), kind, Transform3D(Basis(a, nrm.cross(a), nrm), pc), col)
		for bx in [-0.08, 0.08]:
			for by in [-0.08, 0.08]:
				var bp: Vector3 = pc + a * bx + nrm.cross(a) * by - nrm * 0.012
				_xf(model, Res.cyl(0.017, 0.017, 0.025, 6), kind, Transform3D(Basis(a, nrm, a.cross(nrm)), bp), col.darkened(0.25))


# --- minefields ------------------------------------------------------------------------

## The mines, dug in: each under a ring of loosened earth, its top flush with
## the ground or just proud of it - anti-tank mines (an M15 or a TM-62) and
## the small anti-personnel ones (an M14 or a PMN). Round the field a cordon:
## pickets (the Rebels' are cut stakes), tape or rope between them, and the red
## triangles hung point-down on it.
static func _minefield(model: Node3D, rebel: bool, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector3] = []
	for tries in 60:
		if spots.size() >= 7:
			break
		var p := Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-1.1, 1.1))
		var ok := true
		for q in spots:
			if p.distance_to(q) < 0.75:
				ok = false
				break
		if ok:
			spots.append(p)
	for i in spots.size():
		var p: Vector3 = spots[i]
		var at := i % 2 == 0
		var r := 0.17 if at else 0.065
		var dirt := _mk(model, Res.dome(r * 2.2, 10), "earth", p + Vector3(0, -0.015, 0), Vector3(0, rng.randf() * TAU, 0), Color(0.22, 0.17, 0.11), false)
		dirt.scale = Vector3(1.0 + rng.randf_range(0.0, 0.25), 0.12, 1.0)
		if at:
			var body := OD if not rebel else Color(0.38, 0.4, 0.27)
			_mk(model, Res.cyl(r, r, 0.07, 14), "paint", p + Vector3(0, 0.01, 0), Vector3.ZERO, body, false)
			_mk(model, Res.cyl(r * 0.92, r, 0.012, 14), "paint", p + Vector3(0, 0.05, 0), Vector3.ZERO, body.darkened(0.12), false)
			# the fuze in the middle (a pressure ring on the M15)
			_mk(model, Res.cyl(0.045, 0.05, 0.035, 10), "paint", p + Vector3(0, 0.068, 0), Vector3.ZERO, Color(0.42, 0.42, 0.4) if rebel else OD_DARK, false)
		else:
			_mk(model, Res.cyl(r, r * 1.05, 0.05, 10), "paint", p + Vector3(0, 0.005, 0), Vector3.ZERO, Color(0.16, 0.17, 0.13) if rebel else OD, false)
			_mk(model, Res.cyl(r * 0.7, r * 0.8, 0.012, 10), "rubber", p + Vector3(0, 0.034, 0), Vector3.ZERO, null, false)
	# the cordon round the field
	var h := 1.42
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var tops: Array[Vector3] = []
	for c in corners:
		var top: Vector3 = c + Vector3(rng.randf_range(-0.04, 0.04), 0.82, rng.randf_range(-0.04, 0.04))
		tops.append(top)
		if rebel:
			_rod(model, c + Vector3(0, -0.1, 0), top + Vector3(0, 0.05, 0), 0.028, "wood_dark", null, 5)
		else:
			_beam(model, (c + top) * 0.5, (top - c).normalized(), Vector3(1, 0, 0), Vector3(0.045, 0.012, 0.95), "paint", OD_DARK)
	var tape := Color(0.62, 0.58, 0.46) if rebel else Color(0.85, 0.84, 0.8)
	for i in 4:
		var a: Vector3 = tops[i] + Vector3(0, -0.04, 0)
		var b: Vector3 = tops[(i + 1) % 4] + Vector3(0, -0.04, 0)
		var mid := (a + b) * 0.5 + Vector3(0, -0.06, 0)
		_rod(model, a, mid, 0.008, "paint", tape, 4, false)
		_rod(model, mid, b, 0.008, "paint", tape, 4, false)
		# a triangle on every side, hung point down from the tape
		var sm := mid + (b - a).normalized() * rng.randf_range(-0.3, 0.3)
		var out := (sm - Vector3(0, sm.y, 0)).normalized()
		_xf(model, _sign_mesh(), "paint", Transform3D(Basis.looking_at(out, Vector3.UP), sm + Vector3(0, -0.13, 0)), Color(0.72, 0.1, 0.07))


## A red triangle sign, point down, 28 cm across: a thin plate.
static func _sign_mesh() -> ArrayMesh:
	if _meshes.has("sign"):
		return _meshes.sign
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var s := 0.14
	var t := 0.006
	var pts := [Vector3(-s, s * 0.6, 0), Vector3(s, s * 0.6, 0), Vector3(0, -s * 1.1, 0)]
	for side in [-1.0, 1.0]:
		var nz := Vector3(0, 0, side)
		_tri(v, n, pts[0] + nz * t, pts[1] + nz * t, pts[2] + nz * t, nz, nz, nz)
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 3]
		var e := (b - a).cross(Vector3(0, 0, 1)).normalized()
		if e.dot(a + b) < 0.0:
			e = -e
		_tri(v, n, a + Vector3(0, 0, -t), b + Vector3(0, 0, -t), b + Vector3(0, 0, t), e, e, e)
		_tri(v, n, a + Vector3(0, 0, -t), b + Vector3(0, 0, t), a + Vector3(0, 0, t), e, e, e)
	var m := _commit(v, n)
	_meshes["sign"] = m
	return m


# --- T-walls ---------------------------------------------------------------------------

## Precast T-walls (a "Bremer" wall, cut down): each slab a tall stem on a wide
## foot with a haunch either side where they meet, lifting loops cast into the
## top, set side by side with a hand's-width of daylight between them and
## never quite square.
static func _twalls(model: Node3D, L: float, rng: RandomNumberGenerator) -> void:
	var n := maxi(1, int(round(L / 1.35)))
	var w := L / n
	for i in n:
		var holder := Node3D.new()
		holder.position = Vector3(-L * 0.5 + (i + 0.5) * w, 0, rng.randf_range(-0.015, 0.015))
		holder.rotation = Vector3(rng.randf_range(-0.006, 0.006), rng.randf_range(-0.012, 0.012), 0)
		model.add_child(holder)
		var ww := w - 0.04
		var tone := Color(0.46, 0.45, 0.42) * rng.randf_range(0.92, 1.04)
		tone.a = 1.0
		_mk(holder, Res.box(Vector3(ww, 0.3, 0.86)), "precast", Vector3(0, 0.15, 0), Vector3.ZERO, tone)
		_mk(holder, Res.box(Vector3(ww, 2.32, 0.26)), "precast", Vector3(0, 1.45, 0), Vector3.ZERO, tone)
		# the top of the stem, a shade narrower: the slab tapers as it rises
		_mk(holder, Res.box(Vector3(ww, 0.05, 0.22)), "precast", Vector3(0, 2.625, 0), Vector3.ZERO, tone.darkened(0.04))
		for sd in [-1.0, 1.0]:
			_mk(holder, _haunch(ww), "precast", Vector3(0, 0.3, sd * 0.13), Vector3(0, -sd * PI * 0.5, 0), tone)
		for lx in [-ww * 0.28, ww * 0.28]:
			_mk(holder, Res.torus(0.022, 0.06), "steel", Vector3(lx, 2.64, 0), Vector3(PI * 0.5, 0, 0), RUST, false)
		# a painted serial on a few of them
		if rng.randf() < 0.45:
			_mk(holder, Res.box(Vector3(0.34, 0.12, 0.004)), "paint", Vector3(rng.randf_range(-0.2, 0.2), 1.95, 0.132), Vector3.ZERO, Color(0.12, 0.12, 0.12), false)


## The fillet between a T-wall's foot and its stem: a right-angled wedge,
## upright face against the stem (turned to the slab's side by the caller).
static func _haunch(w: float) -> Mesh:
	var key := "haunch%.3f" % w
	if _meshes.has(key):
		return _meshes[key]
	var m := PrismMesh.new()
	m.left_to_right = 0.0
	m.size = Vector3(0.2, 0.2, w)
	# PrismMesh is centred: lift it so its base sits on the foot
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var arr := m.get_mesh_arrays()
	var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for k in idx:
		v.append(pv[k] + Vector3(0.1, 0.1, 0))
		nrm.append(pn[k])
	var out := _commit(v, nrm)
	_meshes[key] = out
	return out


# --- HESCO ------------------------------------------------------------------------------

## A run of HESCO cells, `L` metres: each a cage of welded mesh lined with
## geotextile, filled with earth till its sides bulge between the corners;
## spiral coil joints pin each cell to the next. Earth heaped along the foot,
## the odd weed growing out of the fill.
static func _hesco(model: Node3D, L: float, rng: RandomNumberGenerator) -> void:
	var cw := 1.1
	var n := maxi(1, int(round(L / cw)))
	var h := 1.37
	var d := 1.06
	var cell := _bulge_box(Vector3(cw - 0.03, h, d), 0.055, false)
	for i in n:
		var x := -L * 0.5 + (i + 0.5) * cw
		var tint := Color(0.53, 0.48, 0.36) * rng.randf_range(0.9, 1.06)
		tint.a = 1.0
		_mk(model, cell, "hesco_cell", Vector3(x, 0, rng.randf_range(-0.012, 0.012)), Vector3(0, rng.randf_range(-0.01, 0.01), 0), tint)
		# the earth it's filled with, settled a little below the rim
		_mk(model, Res.box(Vector3(cw - 0.035, 0.06, d - 0.005)), "earth", Vector3(x, h - 0.06, 0), Vector3.ZERO, Color(0.3, 0.24, 0.16), false)
		if rng.randf() < 0.35:
			var wd := Res.mi(model, Res.sphere(0.12, 6), Mats.foliage(), Vector3(x + rng.randf_range(-0.3, 0.3), h + 0.02, rng.randf_range(-0.3, 0.3)))
			wd.scale = Vector3(1.0, 0.7, 1.0)
			Mats.set_inst(wd, &"tint", Color(0.3, 0.33, 0.16))
		# the top edges of the cage
		for sz in [-d * 0.5, d * 0.5]:
			_rod(model, Vector3(x - cw * 0.5 + 0.02, h + 0.005, sz), Vector3(x + cw * 0.5 - 0.02, h + 0.005, sz), 0.009, "wire", null, 4, false)
	# coil joints at every corner where the cells meet, and at the ends
	for i in n + 1:
		var x := -L * 0.5 + i * cw
		for sz in [-d * 0.5, d * 0.5]:
			_rod(model, Vector3(x, 0.0, sz), Vector3(x, h + 0.02, sz), 0.016, "wire", Color(0.34, 0.34, 0.32), 5, false)
	var apron := _mk(model, Res.dome(1.0, 14), "earth", Vector3(0, -0.02, 0), Vector3.ZERO, Color(0.3, 0.24, 0.16), false)
	apron.scale = Vector3(L * 0.5 + 0.25, 0.12, d * 0.5 + 0.3)


## A box `s` (base on y = 0) whose four sides bulge out by `b` in the middle,
## like a sack or a mesh cage filled with earth. Smooth normals.
static func _bulge_box(s: Vector3, b: float, lid := true) -> ArrayMesh:
	var key := "bulge%.3f,%.3f,%.3f,%.3f,%s" % [s.x, s.y, s.z, b, str(lid)]
	if _meshes.has(key):
		return _meshes[key]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var h := Vector3(s.x * 0.5, s.y * 0.5, s.z * 0.5)
	var seg := 8
	# the four sides: (normal axis, sign); u runs along the side, w up it
	for face in 4:
		var nx := Vector3(1, 0, 0) if face < 2 else Vector3(0, 0, 1)
		var sg := 1.0 if face % 2 == 0 else -1.0
		var nrm := nx * sg
		var ta := Vector3(0, 0, 1) if face < 2 else Vector3(1, 0, 0)
		var half_u: float = h.z if face < 2 else h.x
		var half_n: float = h.x if face < 2 else h.z
		var grid: Array = []
		for j in seg + 1:
			var row: Array = []
			var w := -1.0 + 2.0 * j / seg
			for i in seg + 1:
				var u := -1.0 + 2.0 * i / seg
				var bul := b * (1.0 - u * u) * (1.0 - w * w * 0.6)
				var p := nrm * (half_n + bul) + ta * u * half_u + Vector3(0, h.y + w * h.y, 0)
				var du := -2.0 * b * u * (1.0 - w * w * 0.6) / half_u
				var dw := -2.0 * b * (1.0 - u * u) * w * 0.6 / h.y
				var pn := (nrm - ta * du - Vector3(0, dw, 0)).normalized()
				row.append([p, pn])
			grid.append(row)
		for j in seg:
			for i in seg:
				var a: Array = grid[j][i]
				var bb: Array = grid[j][i + 1]
				var c: Array = grid[j + 1][i + 1]
				var dd: Array = grid[j + 1][i]
				_tri(v, n, a[0], bb[0], c[0], a[1], bb[1], c[1])
				_tri(v, n, a[0], c[0], dd[0], a[1], c[1], dd[1])
	# the top (the bulged sides' rim, a flat lid inside it) and the bottom
	for top in [true, false]:
		if top and not lid:
			continue
		var y: float = s.y if top else 0.0
		var nn := Vector3.UP if top else Vector3.DOWN
		var q := [Vector3(-h.x, y, -h.z), Vector3(h.x, y, -h.z), Vector3(h.x, y, h.z), Vector3(-h.x, y, h.z)]
		_tri(v, n, q[0], q[1], q[2], nn, nn, nn)
		_tri(v, n, q[0], q[2], q[3], nn, nn, nn)
	var m := _commit(v, n)
	_meshes[key] = m
	return m


# --- barricades ------------------------------------------------------------------------

## A barricade thrown up from whatever was to hand, chest high: oil drums filled
## with earth, stacks of tyres, a sheet of roofing propped against a heap of
## rubble, broken concrete, pallets, and sacks along the back and over the top.
static func _barricade(model: Node3D, L: float, rng: RandomNumberGenerator, bags: Array) -> void:
	var x := -L * 0.5 + 0.05
	var last := -1
	while x < L * 0.5 - 0.35:
		# drums most often, then tyres; never the same thing twice running
		var r := rng.randf()
		var k := 0 if r < 0.32 else (1 if r < 0.57 else (2 if r < 0.72 else (3 if r < 0.86 else 4)))
		if k == last:
			k = (k + 1 + rng.randi() % 4) % 5
		last = k
		var room := L * 0.5 - x
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, rng.randf_range(-0.12, 0.1))
		model.add_child(holder)
		var x0 := x
		var nb := bags.size()
		match k:
			0:
				x = _bar_drums(holder, x, room, rng, bags)
			1:
				x = _bar_tyres(holder, x, room, rng, bags)
			2:
				x = _bar_sheet(holder, x, room, rng)
			3:
				x = _bar_block(holder, x, room, rng)
			_:
				x = _bar_pallets(holder, x, room, rng, bags)
		# each piece dragged in a little askew
		var mx := (x0 + x) * 0.5
		holder.position += Vector3(mx, 0, 0)
		holder.rotation.y = rng.randf_range(-0.16, 0.16)
		for c in holder.get_children():
			(c as Node3D).position.x -= mx
		var hxf := Transform3D(Basis(Vector3.UP, holder.rotation.y), holder.position)
		for bi in range(nb, bags.size()):
			var e: Dictionary = bags[bi]
			e.p = hxf * ((e.p as Vector3) - Vector3(mx, 0, 0))
			e.r = float(e.r) + holder.rotation.y
	# sacks along the back, holding it all up
	bags.append({"p": Vector3(0, 0.3, 0.3), "s": Vector3(L - 0.2, 0.6, 0.4), "r": 0.0})
	# rubble kicked about at its foot
	for i in 7:
		var p := Vector3(rng.randf_range(-L * 0.5, L * 0.5), 0.05, rng.randf_range(-0.75, -0.45))
		_mk(model, Res.box(Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.06, 0.14), rng.randf_range(0.1, 0.25))), "rubble" if i % 2 == 0 else "brick", p,
			Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)), null, false)
	var apron := _mk(model, Res.dome(1.0, 12), "earth", Vector3(0, -0.02, 0), Vector3.ZERO, Color(0.3, 0.25, 0.18), false)
	apron.scale = Vector3(L * 0.5 + 0.2, 0.1, 0.75)


## Two oil drums side by side, a sandbag on each, sometimes a third lying across them.
static func _bar_drums(model: Node3D, x: float, room: float, rng: RandomNumberGenerator, bags: Array) -> float:
	var cols := [Color(0.24, 0.32, 0.42), Color(0.5, 0.17, 0.12), Color(0.3, 0.33, 0.2), Color(0.58, 0.45, 0.14), Color(0.42, 0.42, 0.4)]
	var n := 2 if room > 1.3 else 1
	for i in n:
		var p := Vector3(x + 0.31 + i * 0.6, 0, rng.randf_range(-0.22, -0.08))
		_drum(model, p, cols[rng.randi() % cols.size()], rng, false)
	if n == 2 and rng.randf() < 0.45:
		# a third laid across the two
		_drum(model, Vector3(x + 0.61, 0.88, -0.15), cols[rng.randi() % cols.size()], rng, true)
	else:
		for i in n:
			bags.append({"p": Vector3(x + 0.31 + i * 0.6, 0.98, -0.12), "s": Vector3(0.5, 0.19, 0.4), "r": rng.randf_range(-0.3, 0.3)})
	return x + n * 0.6 + 0.05


static func _drum(model: Node3D, p: Vector3, col: Color, rng: RandomNumberGenerator, lying: bool) -> void:
	var rot := Vector3(0, rng.randf() * TAU, 0) if not lying else Vector3(rng.randf() * TAU, rng.randf_range(-0.2, 0.2), PI * 0.5)
	var c := p + (Vector3(0, 0.44, 0) if not lying else Vector3(0, 0.29, 0))
	var holder := Node3D.new()
	holder.position = c
	holder.rotation = rot
	model.add_child(holder)
	var dc := Res.vary(col, 0.1, rng)
	_mk(holder, Res.cyl(0.29, 0.29, 0.88, 14), "car_paint", Vector3.ZERO, Vector3.ZERO, dc)
	# the rolling hoops and the rims
	for y in [-0.43, -0.15, 0.15, 0.43]:
		_mk(holder, Res.torus(0.285, 0.305), "car_paint", Vector3(0, y, 0), Vector3.ZERO, dc.darkened(0.15), false)
	_mk(holder, Res.cyl(0.03, 0.03, 0.02, 6), "steel", Vector3(0.17, 0.44, 0.05), Vector3.ZERO, null, false)


static func _bar_tyres(model: Node3D, x: float, room: float, rng: RandomNumberGenerator, bags: Array) -> float:
	var n := 2 if room > 1.6 else 1
	for i in n:
		var p := Vector3(x + 0.4 + i * 0.76, 0, rng.randf_range(-0.2, 0.0))
		var k := rng.randi_range(3, 5)
		for j in k:
			var q := p + Vector3(rng.randf_range(-0.06, 0.06), 0.105 + j * 0.205, rng.randf_range(-0.06, 0.06))
			_mk(model, Res.torus(0.18, 0.39), "rubber", q, Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)), null)
		# filled with earth, a sack or two on the short stacks
		_mk(model, Res.cyl(0.2, 0.2, k * 0.2, 8), "earth", p + Vector3(0, k * 0.1, 0), Vector3.ZERO, Color(0.28, 0.22, 0.15), false)
		if k < 5:
			bags.append({"p": p + Vector3(0, k * 0.205 + 0.1 + (0.19 if k == 3 else 0.0) * 0.5, 0), "s": Vector3(0.55, 0.19 * (2 if k == 3 else 1), 0.42), "r": rng.randf_range(-0.4, 0.4)})
	return x + n * 0.76 + 0.06


## A sheet of rusty roofing propped against a heap of rubble.
static func _bar_sheet(model: Node3D, x: float, room: float, rng: RandomNumberGenerator) -> float:
	var w := minf(1.5, room - 0.1)
	if w < 0.7:
		return x + 0.4
	var heap := _mk(model, Res.dome(1.0, 10), "rubble", Vector3(x + w * 0.5, 0, 0.05), Vector3.ZERO, null)
	heap.scale = Vector3(w * 0.5, 1.0, 0.45)
	_mk(model, Res.box(Vector3(w, 1.2, 0.025)), "corrugated", Vector3(x + w * 0.5, 0.58, -0.3), Vector3(0.2, rng.randf_range(-0.05, 0.05), rng.randf_range(-0.04, 0.04)), RUST.lightened(0.15))
	return x + w + 0.05


## A lump of broken concrete (a slab off a building), bricks on it.
static func _bar_block(model: Node3D, x: float, room: float, rng: RandomNumberGenerator) -> float:
	var w := minf(1.0, room - 0.05)
	var rot := Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.1))
	var c := Vector3(x + w * 0.5, 0.36, -0.05)
	_mk(model, Res.box(Vector3(w, 0.75, 0.75)), "precast", c, rot, Color(0.46, 0.45, 0.42))
	# the reinforcing bars it was torn off, bent and rusted
	var b := Basis.from_euler(rot)
	for i in 3:
		var a := c + b * Vector3(-w * 0.5 + 0.15 + i * 0.22, 0.3, rng.randf_range(-0.25, 0.25))
		_rod(model, a, a + b * Vector3(rng.randf_range(-0.15, 0.15), 0.35, rng.randf_range(-0.2, 0.2)), 0.01, "rust_steel", null, 4, false)
	for i in 3:
		_mk(model, Res.box(Vector3(0.24, 0.07, 0.12)), "brick", Vector3(x + w * 0.5 + rng.randf_range(-0.3, 0.3), 0.78 + i * 0.07, rng.randf_range(-0.2, 0.15)), Vector3(0, rng.randf() * TAU, 0))
	return x + w + 0.05


static func _bar_pallets(model: Node3D, x: float, room: float, rng: RandomNumberGenerator, bags: Array) -> float:
	var w := minf(1.2, room - 0.05)
	var n := rng.randi_range(4, 6)
	if n < 6:
		bags.append({"p": Vector3(x + w * 0.5, n * 0.15 + 0.085, -0.1), "s": Vector3(w * 0.9, 0.19, 0.42), "r": rng.randf_range(-0.15, 0.15)})
	for i in n:
		var y := 0.07 + i * 0.15
		var p := Vector3(x + w * 0.5 + rng.randf_range(-0.05, 0.05), y, -0.1)
		var r := Vector3(0, rng.randf_range(-0.08, 0.08), 0)
		for s in 5:
			_mk(model, Res.box(Vector3(w, 0.022, 0.13)), "wood", p + Basis.from_euler(r) * Vector3(0, 0.06, -0.38 + s * 0.19), r, Color(0.52, 0.42, 0.3))
		for s in 3:
			_mk(model, Res.box(Vector3(0.09, 0.09, 0.9)), "wood", p + Basis.from_euler(r) * Vector3(-w * 0.5 + 0.06 + s * (w - 0.12) * 0.5, 0.0, 0), r, Color(0.48, 0.38, 0.26))
	return x + w + 0.05


# --- ammunition cache --------------------------------------------------------------------

## Stores stacked on pallets, half under a tarp: for the Coalition, olive cans
## of small-arms rounds strapped in blocks and long crates of rockets and
## mortar bombs; for the Rebels, wooden crates painted green with rope
## handles, zinc cases, an open crate of RPG rounds, a blue plastic sheet. Low
## sandbags in front and a red flag on a stake (an ammunition point).
static func _ammo_cache(model: Node3D, rebel: bool, rng: RandomNumberGenerator, bags: Array) -> void:
	for px in [-0.68, 0.68]:
		_pallet(model, Vector3(px, 0, 0.15), rng)
	if rebel:
		var crate := Color(0.3, 0.36, 0.22)
		for i in 3:
			for j in 2:
				var cp := Vector3(-0.68 + rng.randf_range(-0.03, 0.03), 0.13 + 0.17 + i * 0.34, -0.1 + j * 0.5)
				_crate(model, cp, Vector3(1.0, 0.32, 0.45), crate, rng)
		for i in 2:
			_crate(model, Vector3(0.68, 0.13 + 0.17 + i * 0.34, -0.1), Vector3(1.05, 0.32, 0.45), crate.darkened(0.08), rng)
		# zinc cases of rounds, and an open crate of RPG rounds
		for i in 4:
			_mk(model, Res.box(Vector3(0.36, 0.14, 0.22)), "steel", Vector3(0.45 + (i % 2) * 0.4, 0.2, 0.42 + (i / 2) * 0.25), Vector3(0, rng.randf_range(-0.1, 0.1), 0), Color(0.6, 0.6, 0.58))
		_mk(model, Res.box(Vector3(1.0, 0.04, 0.45)), "wood_dark", Vector3(0.68, 0.8, -0.1), Vector3(0, 0.05, 0), crate.darkened(0.2))
		for i in 3:
			_rpg_round(model, Vector3(0.38 + i * 0.25, 0.86, -0.1), rng)
		# a blue tarp over the back of it
		_tarp(model, Vector3(-0.4, 0, 0.15), Color(0.18, 0.3, 0.5))
	else:
		# cans of 5.56 and 7.62, strapped in a block on the pallet
		for ix in 3:
			for iz in 5:
				for iy in 4:
					var cp := Vector3(-0.68 + (ix - 1) * 0.33, 0.13 + 0.095 + iy * 0.19, 0.15 + (iz - 2) * 0.165)
					_mk(model, Res.box(Vector3(0.3, 0.18, 0.15)), "paint", cp, Vector3.ZERO, OD.darkened(rng.randf_range(0.0, 0.14)))
		for sx in [-0.3, 0.3]:
			_mk(model, Res.box(Vector3(0.035, 0.012, 0.86)), "canvas", Vector3(-0.68 + sx, 0.9, 0.15), Vector3.ZERO, Color(0.66, 0.6, 0.42), false)
			for sz in [-0.43, 0.43]:
				_mk(model, Res.box(Vector3(0.035, 0.77, 0.012)), "canvas", Vector3(-0.68 + sx, 0.51, 0.15 + sz), Vector3.ZERO, Color(0.66, 0.6, 0.42), false)
		# long crates: rockets and mortar bombs, stencilled
		for i in 3:
			for j in 2:
				var cp := Vector3(0.68, 0.13 + 0.12 + i * 0.25, -0.12 + j * 0.42)
				_mk(model, Res.box(Vector3(1.1, 0.23, 0.38)), "paint", cp, Vector3(0, rng.randf_range(-0.04, 0.04), 0), OD_DARK.lightened(rng.randf_range(0.0, 0.1)))
				_mk(model, Res.box(Vector3(0.12, 0.234, 0.384)), "paint", cp + Vector3(0.3, 0, 0), Vector3.ZERO, ROUND_BAND.darkened(0.25), false)
		_tarp(model, Vector3(0.5, 0, 0.15), Color(0.35, 0.37, 0.25))
	# low sacks along the front, and the red flag
	bags.append({"p": Vector3(0, 0.2, -0.95), "s": Vector3(2.6, 0.4, 0.42), "r": 0.0})
	_rod(model, Vector3(1.45, -0.1, -0.9), Vector3(1.45, 1.55, -0.9), 0.016, "wood", null, 5)
	_mk(model, Res.box(Vector3(0.36, 0.26, 0.01)), "paint", Vector3(1.64, 1.38, -0.9), Vector3(0, 0, -0.08), Color(0.7, 0.1, 0.07))


static func _pallet(model: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var col := Res.vary(Color(0.55, 0.45, 0.32), 0.08, rng)
	for s in 6:
		_mk(model, Res.box(Vector3(1.15, 0.022, 0.13)), "wood", p + Vector3(0, 0.119, -0.45 + s * 0.18), Vector3.ZERO, col)
	for s in 3:
		_mk(model, Res.box(Vector3(0.1, 0.1, 1.0)), "wood", p + Vector3(-0.5 + s * 0.5, 0.05, 0), Vector3.ZERO, col.darkened(0.08))


static func _crate(model: Node3D, c: Vector3, s: Vector3, col: Color, rng: RandomNumberGenerator) -> void:
	var r := Vector3(0, rng.randf_range(-0.05, 0.05), 0)
	_mk(model, Res.box(s), "wood_painted", c, r, Res.vary(col, 0.06, rng))
	# battens at the ends, rope handles
	for sx in [-1.0, 1.0]:
		_mk(model, Res.box(Vector3(0.05, s.y + 0.01, s.z + 0.01)), "wood_painted", c + Basis.from_euler(r) * Vector3(sx * (s.x * 0.5 - 0.06), 0, 0), r, col.darkened(0.15))
		_mk(model, Res.torus(0.03, 0.05), "canvas", c + Basis.from_euler(r) * Vector3(sx * (s.x * 0.5 + 0.01), 0.02, 0), r + Vector3(0, 0, PI * 0.5), Color(0.55, 0.5, 0.36), false)


## A PG-7 round lying in its crate: the cone of the warhead, the motor, the fins.
static func _rpg_round(model: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var r := Vector3(PI * 0.5, rng.randf_range(-0.1, 0.1), 0)
	var b := Basis.from_euler(r)
	_mk(model, Res.cyl(0.02, 0.042, 0.2, 10), "paint", p + b * Vector3(0, 0.22, 0), r, Color(0.3, 0.35, 0.22), false)
	_mk(model, Res.cyl(0.042, 0.042, 0.1, 10), "paint", p + b * Vector3(0, 0.07, 0), r, Color(0.3, 0.35, 0.22), false)
	_mk(model, Res.cyl(0.022, 0.022, 0.28, 8), "paint", p + b * Vector3(0, -0.12, 0), r, Color(0.2, 0.22, 0.2), false)


## A fly sheet pitched over the stacks at `p`: a ridge on two poles, the
## sides pegged out low front and back, the stores in its shade.
static func _tarp(model: Node3D, p: Vector3, col: Color) -> void:
	var ridge := 1.62
	var eave := 1.0
	var half := 0.78
	for sx in [-0.72, 0.72]:
		_rod(model, p + Vector3(sx, -0.1, 0), p + Vector3(sx, ridge + 0.1, 0), 0.022, "wood", null, 5)
		for sz in [-1.0, 1.0]:
			_rod(model, p + Vector3(sx, eave, sz * half), p + Vector3(sx * 1.2, 0.02, sz * (half + 0.55)), 0.005, "canvas", Color(0.55, 0.5, 0.38), 3, false)
	var ang := atan2(ridge - eave, half)
	var ln := Vector2(half, ridge - eave).length() + 0.04
	for sz in [-1.0, 1.0]:
		_mk(model, Res.box(Vector3(1.5, 0.02, ln)), "canvas", p + Vector3(0, (ridge + eave) * 0.5, sz * half * 0.5), Vector3(sz * ang, 0, 0), col.darkened(0.06 if sz > 0.0 else 0.0))


# --- camouflage net --------------------------------------------------------------------

## A camouflage net pitched over a centre pole and four corner poles and draped
## down the sides nearly to the ground, so what's under it has no shape and
## throws no shadow of its own; guy ropes out to pegs. Woodland green and brown
## for the Coalition, the Rebels' a faded desert pattern on cut poles.
static func _camo_net(model: Node3D, rebel: bool, rng: RandomNumberGenerator) -> Array:
	var net := MeshInstance3D.new()
	net.mesh = _net_mesh(rng.randi() % 2)
	net.material_override = Mats.netting_tent()
	Mats.set_inst(net, &"tint", Color(0.42, 0.37, 0.26) if rebel else Color(0.23, 0.27, 0.15))
	model.add_child(net)
	var pk := "wood_dark" if rebel else "steel"
	var pc = null if rebel else Color(0.45, 0.46, 0.42)
	_rod(model, Vector3(0, 0, 0), Vector3(0, 2.55, 0), 0.03, pk, pc, 6)
	# a spreader at the top so the pole doesn't punch through
	_mk(model, Res.cyl(0.16, 0.16, 0.02, 8), "metal_dark", Vector3(0, 2.56, 0), Vector3.ZERO, null, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * 2.5, 0, sz * 2.5)
			_rod(model, base, base + Vector3(0, 1.78, 0), 0.025, pk, pc, 5)
			# guyed out to a peg
			var peg := Vector3(sx * 3.5, 0.05, sz * 3.5)
			_rod(model, base + Vector3(0, 1.85, 0), peg, 0.006, "canvas", Color(0.5, 0.47, 0.36), 3, false)
			_rod(model, peg + Vector3(0, -0.1, 0), peg + Vector3(0, 0.12, 0), 0.015, "steel", null, 4, false)
	return [net]


## The net's shape: a square 7.2 m across, high in the middle over the centre
## pole, sagging between the corner poles and draped down to knee height at
## its edges. UV runs 0..1 corner to corner (the netting shader frays its edge).
static func _net_mesh(v: int) -> ArrayMesh:
	var key := "net%d" % v
	if _meshes.has(key):
		return _meshes[key]
	var N := 20
	var S := 3.6
	var pole := 2.5
	var pos: Array = []
	for j in N + 1:
		var row: Array = []
		for i in N + 1:
			var x := (float(i) / N * 2.0 - 1.0) * S
			var z := (float(j) / N * 2.0 - 1.0) * S
			var d := maxf(absf(x), absf(z))
			# how far along a side from its corner pole (0 at a corner, 1 mid-side)
			var mid := 1.0 - minf(absf(x), absf(z)) / maxf(d, 0.01)
			var y := 0.0
			if d < pole:
				var f := d / pole
				y = lerpf(2.6, 1.8, pow(f, 0.8)) - 0.32 * f * mid
			else:
				var g := (d - pole) / (S - pole)
				y = lerpf(1.8 - 0.32 * mid, 0.35 + 0.25 * mid, pow(g, 0.7))
			y += 0.08 * sin(x * 2.1 + v * 1.7) * sin(z * 1.7 - v) + 0.04 * sin(x * 5.3 + z * 4.1 + v)
			row.append(Vector3(x, y, z))
		pos.append(row)
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var uu := PackedVector2Array()
	var nrm: Array = []
	for j in N + 1:
		var row2: Array = []
		for i in N + 1:
			var du: Vector3 = pos[j][mini(i + 1, N)] - pos[j][maxi(i - 1, 0)]
			var dv: Vector3 = pos[mini(j + 1, N)][i] - pos[maxi(j - 1, 0)][i]
			var q := dv.cross(du).normalized()
			row2.append(q if q.y >= 0.0 else -q)
		nrm.append(row2)
	for j in N:
		for i in N:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var k0: Array = q[tri[0]]
				var k1: Array = q[tri[1]]
				var k2: Array = q[tri[2]]
				var a: Vector3 = pos[k0[1]][k0[0]]
				var b: Vector3 = pos[k1[1]][k1[0]]
				var c: Vector3 = pos[k2[1]][k2[0]]
				var na: Vector3 = nrm[k0[1]][k0[0]]
				var order: Array = [k0, k2, k1] if (b - a).cross(c - a).dot(na) > 0.0 else [k0, k1, k2]
				for k in order:
					vv.append(pos[k[1]][k[0]])
					nn.append(nrm[k[1]][k[0]])
					uu.append(Vector2(float(k[0]) / N, float(k[1]) / N))
	var m := _commit(vv, nn, uu)
	_meshes[key] = m
	return m


# --- crew weapons ----------------------------------------------------------------------

## The mortar in its pit: an 81 mm M252 for the Coalition, an 82 mm 2B14 for
## the Rebels - the round baseplate dug in, the tube laid at about sixty
## degrees, the bipod with its elevating and traversing gear and the sight on
## the left, and bombs laid out ready on their crates beside the gunner.
static func _mortar(model: Node3D, rebel: bool, rng: RandomNumberGenerator) -> void:
	var tube_col := OD_DARK if not rebel else Color(0.24, 0.27, 0.2)
	var base := Vector3(0, 0.05, 0.25)
	_mk(model, Res.cyl(0.27, 0.31, 0.06, 16), "paint", base, Vector3.ZERO, tube_col.darkened(0.1))
	for i in 6:
		var a := TAU * i / 6.0
		_mk(model, Res.box(Vector3(0.03, 0.05, 0.25)), "paint", base + Vector3(sin(a) * 0.13, 0.04, cos(a) * 0.13), Vector3(0, a, 0), tube_col.darkened(0.15))
	# the tube, from the ball at its base up and out over the front of the pit
	var el := deg_to_rad(62.0)
	var dir := Vector3(0, sin(el), -cos(el))
	var b0 := base + Vector3(0, 0.07, 0)
	var b1 := b0 + dir * 1.27
	_mk(model, Res.sphere(0.065, 8), "gunmetal_w", b0)
	_rod(model, b0, b1, 0.05, "paint", tube_col, 12)
	_rod(model, b1 - dir * 0.05, b1 + dir * 0.03, 0.062, "paint", tube_col.darkened(0.1), 12)
	# the bipod: a collar on the tube, two legs splayed to the ground, the
	# elevating screw between them and the traversing gear across the top
	var collar := b0 + dir * 0.82
	_rod(model, collar - dir * 0.05, collar + dir * 0.05, 0.068, "gunmetal_w", null, 10)
	var yoke := collar + Vector3(0, -0.1, -0.12)
	_rod(model, collar, yoke, 0.03, "gunmetal_w", null, 6)
	_rod(model, yoke + Vector3(-0.17, 0, 0), yoke + Vector3(0.17, 0, 0), 0.025, "gunmetal_w", null, 6)
	var feet := [Vector3(-0.36, 0.0, -0.62), Vector3(0.36, 0.0, -0.62)]
	for f in feet:
		_rod(model, yoke + Vector3(signf(f.x) * 0.15, 0, 0), f, 0.022, "paint", tube_col, 6)
		_mk(model, Res.cyl(0.04, 0.05, 0.03, 8), "gunmetal_w", f + Vector3(0, 0.015, 0))
	var mid: Vector3 = (feet[0] + feet[1]) * 0.5 + Vector3(0, 0.32, 0.02)
	_rod(model, feet[0] + Vector3(0, 0.3, 0), feet[1] + Vector3(0, 0.3, 0), 0.012, "gunmetal_w", null, 5)
	_rod(model, yoke, mid, 0.026, "gunmetal_w", null, 6)
	# the handwheels and the sight on the left
	_mk(model, Res.torus(0.04, 0.06), "gunmetal_w", yoke + Vector3(0.24, 0, 0), Vector3(0, 0, PI * 0.5), null, false)
	_mk(model, Res.torus(0.035, 0.05), "gunmetal_w", mid + Vector3(0, -0.12, 0.05), Vector3(PI * 0.5, 0, 0), null, false)
	var sight := yoke + Vector3(-0.24, 0.1, 0.04)
	_mk(model, Res.box(Vector3(0.08, 0.1, 0.12)), "paint", sight, Vector3.ZERO, Color(0.2, 0.22, 0.18))
	_mk(model, Res.cyl(0.022, 0.022, 0.12, 8), "gunmetal_w", sight + Vector3(0, 0.1, 0.02), Vector3(-0.4, 0, 0))
	# bombs laid out on their crates beside him, and more in the open crate
	var crate_c := Color(0.4, 0.31, 0.2) if rebel else OD
	for i in 2:
		var cp := Vector3(0.95, 0.15 + i * 0.28, 0.75 + rng.randf_range(-0.03, 0.03))
		_mk(model, Res.box(Vector3(0.75, 0.27, 0.35)), "wood_painted" if rebel else "paint", cp, Vector3(0, 0.15 + rng.randf_range(-0.05, 0.05), 0), crate_c.darkened(i * 0.08))
	for i in 4:
		_bomb(model, Vector3(0.68 + i * 0.13, 0.62, 0.7 + (i % 2) * 0.04), Vector3(PI * 0.5, 0.15, 0) + Vector3(0, 0, 0), rebel)
	for i in 3:
		_bomb(model, Vector3(-0.85 + i * 0.12, 0.07, 0.95), Vector3(0, 0, rng.randf_range(-0.05, 0.05)), rebel)
	# the gunner's floor dug down a little, his kit in the corner
	_mk(model, Res.box(Vector3(0.5, 0.3, 0.3)), "canvas", Vector3(-1.0, 0.15, 0.4), Vector3(0, 0.4, 0), Color(0.32, 0.33, 0.24))


## A mortar bomb standing on its tail fins (rot turns it).
static func _bomb(model: Node3D, p: Vector3, rot: Vector3, rebel: bool) -> void:
	var holder := Node3D.new()
	holder.position = p
	holder.rotation = rot
	model.add_child(holder)
	var body := ROUND_OD if not rebel else Color(0.36, 0.38, 0.3)
	var s := _mk(holder, Res.sphere(0.045, 10), "paint", Vector3(0, 0.17, 0), Vector3.ZERO, body)
	s.scale = Vector3(1.0, 2.4, 1.0)
	_mk(holder, Res.cyl(0.046, 0.046, 0.02, 10), "paint", Vector3(0, 0.21, 0), Vector3.ZERO, ROUND_BAND, false)
	_mk(holder, Res.cyl(0.012, 0.016, 0.06, 6), "gunmetal_w", Vector3(0, 0.3, 0), Vector3.ZERO, null, false)
	_mk(holder, Res.cyl(0.016, 0.016, 0.12, 6), "paint", Vector3(0, 0.0, 0), Vector3.ZERO, body.darkened(0.2), false)
	for a in 4:
		_mk(holder, Res.box(Vector3(0.003, 0.06, 0.07)), "paint", Vector3(0, -0.04, 0), Vector3(0, a * PI * 0.25, 0), body.darkened(0.25), false)


## The anti-tank weapon: a Javelin (the launch tube on the parapet, the command
## launch unit clamped to it, spare rounds in their tubes behind) for the
## Coalition; an SPG-9 recoilless rifle on its tripod, the venturi flaring at
## the back, rounds in an open crate, for the Rebels.
static func _at_weapon(model: Node3D, rebel: bool, rng: RandomNumberGenerator) -> void:
	if rebel:
		var g := Node3D.new()
		g.position = Vector3(0, 0.82, -0.55)
		g.rotation.y = rng.randf_range(-0.12, 0.12)
		model.add_child(g)
		var tc := Color(0.27, 0.3, 0.21)
		# the barrel: 2.1 m, the muzzle, the breech and its venturi
		_mk(g, Res.cyl(0.055, 0.055, 1.6, 12), "paint", Vector3(0, 0.12, -0.35), Vector3(PI * 0.5, 0, 0), tc)
		_mk(g, Res.cyl(0.062, 0.062, 0.1, 12), "paint", Vector3(0, 0.12, -1.15), Vector3(PI * 0.5, 0, 0), tc.darkened(0.1))
		_mk(g, Res.cyl(0.09, 0.09, 0.3, 12), "paint", Vector3(0, 0.12, 0.55), Vector3(PI * 0.5, 0, 0), tc.darkened(0.05))
		_mk(g, Res.cyl(0.07, 0.12, 0.2, 12), "gunmetal_w", Vector3(0, 0.12, 0.8), Vector3(PI * 0.5, 0, 0))
		# the sight and the firing grip
		_mk(g, Res.box(Vector3(0.07, 0.12, 0.16)), "paint", Vector3(-0.12, 0.2, 0.2), Vector3.ZERO, Color(0.18, 0.2, 0.16))
		_mk(g, Res.cyl(0.025, 0.025, 0.14, 8), "gunmetal_w", Vector3(-0.12, 0.27, 0.3), Vector3(PI * 0.5, 0, 0))
		_mk(g, Res.box(Vector3(0.04, 0.12, 0.05)), "gunmetal_w", Vector3(0.03, 0.03, 0.3), Vector3(0.3, 0, 0))
		# the tripod (its little wheels folded up)
		_rod(g, Vector3(0, 0.05, 0.1), Vector3(0, -0.82, -0.75), 0.022, "paint", tc.darkened(0.1))
		for sx in [-1.0, 1.0]:
			_rod(g, Vector3(sx * 0.03, 0.05, 0.12), Vector3(sx * 0.5, -0.82, 0.55), 0.022, "paint", tc.darkened(0.1))
			_mk(g, Res.cyl(0.08, 0.08, 0.04, 10), "rubber", Vector3(sx * 0.33, -0.48, 0.38), Vector3(0, 0, PI * 0.5), null, false)
		# PG-9 rounds in their crate
		_mk(model, Res.box(Vector3(1.05, 0.25, 0.4)), "wood_painted", Vector3(0.9, 0.13, 0.6), Vector3(0, 0.3, 0), Color(0.33, 0.37, 0.24))
		for i in 2:
			_rpg_round(model, Vector3(0.75 + i * 0.22, 0.29, 0.6) + Vector3(0, 0, 0.05 * i), rng)
		return
	# the Javelin on the parapet, pointing out
	var lg := Node3D.new()
	lg.position = Vector3(0, 0.97, -1.1)
	lg.rotation = Vector3(0.03, rng.randf_range(-0.1, 0.1), 0)
	model.add_child(lg)
	var tube := Color(0.3, 0.32, 0.23)
	_mk(lg, Res.cyl(0.07, 0.07, 1.2, 12), "paint", Vector3(0, 0.0, 0), Vector3(PI * 0.5, 0, 0), tube)
	for z in [-0.58, 0.58]:
		_mk(lg, Res.cyl(0.088, 0.088, 0.09, 12), "rubber", Vector3(0, 0, z), Vector3(PI * 0.5, 0, 0), null)
	_mk(lg, Res.box(Vector3(0.02, 0.06, 0.32)), "paint", Vector3(0, -0.075, 0.1), Vector3.ZERO, tube.darkened(0.2))
	# the CLU: a box of electronics with its sight and handles, clamped on the left
	_mk(lg, Res.box(Vector3(0.26, 0.24, 0.3)), "paint", Vector3(-0.16, 0.05, 0.2), Vector3.ZERO, Color(0.36, 0.36, 0.3))
	_mk(lg, Res.cyl(0.05, 0.05, 0.12, 10), "gunmetal_w", Vector3(-0.16, 0.08, 0.4), Vector3(PI * 0.5, 0, 0))
	_mk(lg, Res.box(Vector3(0.18, 0.1, 0.05)), "gunmetal_w", Vector3(-0.16, 0.2, 0.04))
	for sx in [-0.28, -0.04]:
		_mk(lg, Res.box(Vector3(0.03, 0.12, 0.04)), "gunmetal_w", Vector3(sx, -0.02, 0.28), Vector3(0.3, 0, 0))
	# spare rounds in their tubes, laid on the floor behind the parapet
	for i in 2:
		_mk(model, Res.cyl(0.07, 0.07, 1.2, 12), "paint", Vector3(1.0 + i * 0.17, 0.08, 0.35), Vector3(PI * 0.5, 0.2, 0), tube.darkened(0.05))
	_mk(model, Res.box(Vector3(0.5, 0.25, 0.3)), "paint", Vector3(-1.0, 0.13, 0.5), Vector3(0, 0.3, 0), OD)
