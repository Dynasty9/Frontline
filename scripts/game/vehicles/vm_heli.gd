class_name VmHeli
extends RefCounted
## Procedural models: helicopters and rotary drones.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## Fuselages are Hulls: convex sections lofted along Z, with windows, doors,
## seams and livery laid on them as patches that follow the facets. Rotors,
## tail rotors, fantails, skids and the weapons are shared helpers below.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["pawnee", "hummingbird", "m900", "ghosthawk", "ghosthawk_stub", "huron", "blackfoot",
	"mohawk", "hellcat", "kajman", "orca", "orca_armed", "taru", "falcon", "darter", "utility_drone", "demining_drone"]

const NATO_BLACK := Color(0.2, 0.21, 0.22)
const NATO_GREY := Color(0.42, 0.45, 0.48)
const CSAT_SAND := Color(0.47, 0.44, 0.38)
const AAF_GREEN := Color(0.36, 0.39, 0.28)
## The sheen of a helicopter's clear cockpit glass (VmPlane.clear_glass):
## a dark grey, so the cockpit behind it reads near black with the crew's
## helmets the light shapes in it, as real glazing over a dark cockpit does
## (the jets' grey-blue laid a pale haze over everything seen through the
## flat panes from the side).
const PIT_GLASS := Color(0.17, 0.19, 0.21)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"pawnee":
			_little_bird(k, team, seed, 1)
		"hummingbird":
			_little_bird(k, team, seed, 0)
		"m900":
			_little_bird(k, team, seed, 2)
		"ghosthawk":
			_ghost_hawk(k, team, false)
		"ghosthawk_stub":
			_ghost_hawk(k, team, true)
		"huron":
			_huron(k, team)
		"blackfoot":
			_blackfoot(k, team)
		"mohawk":
			_mohawk(k, team)
		"hellcat":
			_hellcat(k, team)
		"kajman":
			_kajman(k, team)
		"orca":
			_orca(k, team, false)
		"orca_armed":
			_orca(k, team, true)
		"taru":
			_taru(k, team)
		"falcon":
			_falcon(k, team)
		"darter":
			_darter(k, team)
		"utility_drone":
			_hexa(k, team, false)
		"demining_drone":
			_hexa(k, team, true)
		_:
			return false
	return true


# --- hulls -----------------------------------------------------------------------

## A lofted fuselage. Stations [z, cy, rx, ry_top, ry_bottom, top_scale,
## bottom_scale] run front to back; each is a convex superellipse section of n
## points round (0, cy): p = 2 an ellipse, larger boxier; top/bottom_scale
## narrow the roof or the belly. n = 6 with phase 0 gives the chined, faceted
## section of a stealth airframe. Vertex t = 0 is the right flank at cy,
## t = n / 4 the roof, n / 2 the left flank, 3n / 4 the belly; fractional t
## lies on the facet between two vertices.
class Hull:
	extends RefCounted
	var st: Array
	var n := 12
	var p := 2.0
	var ph := 0.0

	func _init(stations: Array, pts := 12, power := 2.0, phase := 0.0) -> void:
		st = stations
		n = pts
		p = power
		ph = phase

	static func _full(s: Array) -> Array:
		var o := s.duplicate()
		while o.size() < 7:
			o.append(1.0)
		return o

	## The section's parameters at z (linear between stations).
	func at(z: float) -> Array:
		if z <= float(st[0][0]):
			return _full(st[0])
		for i in st.size() - 1:
			var b: Array = st[i + 1]
			if z <= float(b[0]):
				var fa := _full(st[i])
				var fb := _full(b)
				var f := (z - float(fa[0])) / maxf(float(fb[0]) - float(fa[0]), 1e-5)
				var o := []
				for j in 7:
					o.append(lerpf(float(fa[j]), float(fb[j]), f))
				return o
		return _full(st[st.size() - 1])

	func vert(prm: Array, i: int) -> Vector2:
		var a := ph + TAU * float(posmod(i, n)) / float(n)
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 2.0 / p) * float(prm[2])
		var y := signf(s) * pow(absf(s), 2.0 / p)
		x *= 1.0 + (float(prm[5]) - 1.0) * maxf(s, 0.0) + (float(prm[6]) - 1.0) * maxf(-s, 0.0)
		return Vector2(x, float(prm[1]) + y * (float(prm[3]) if s > 0.0 else float(prm[4])))

	func _enorm(prm: Array, i: int) -> Vector2:
		var a := vert(prm, i)
		var b := vert(prm, i + 1)
		var d := b - a
		var nn := Vector2(d.y, -d.x).normalized()
		if nn.dot((a + b) * 0.5 - Vector2(0, float(prm[1]))) < 0.0:
			nn = -nn
		return nn

	## The surface point at (z, t), pushed out along the facet normal by grow.
	func pt(z: float, t: float, grow := 0.0) -> Vector3:
		var prm := at(z)
		var i := floori(t)
		var f := t - i
		var v := vert(prm, i).lerp(vert(prm, i + 1), f)
		var nn: Vector2
		if f < 0.002:
			nn = (_enorm(prm, i - 1) + _enorm(prm, i)).normalized()
		elif f > 0.998:
			nn = (_enorm(prm, i) + _enorm(prm, i + 1)).normalized()
		else:
			nn = _enorm(prm, i)
		v += nn * grow
		return Vector3(v.x, v.y, z)

	func ring(z: float, grow := 0.0) -> PackedVector3Array:
		var r := PackedVector3Array()
		for i in n:
			r.append(pt(z, float(i), grow))
		return r

	func mesh(key: String, grow := 0.0) -> ArrayMesh:
		var rings := []
		for s in st:
			rings.append(ring(float(s[0]), grow))
		return VehicleModels.solid(rings, key)

	## A panel laid on the hull between z0..z1 and t0..t1, standing grow
	## proud and depth deep (sx = -1 mirrors it to the left).
	func patch(key: String, z0: float, z1: float, t0: float, t1: float, grow := 0.012, depth := 0.03, sx := 1.0) -> ArrayMesh:
		var zs := [z0]
		for s in st:
			if float(s[0]) > z0 + 0.01 and float(s[0]) < z1 - 0.01:
				zs.append(float(s[0]))
		zs.append(z1)
		var ts := [t0]
		for i in range(ceili(t0 + 0.01), floori(t1 - 0.01) + 1):
			ts.append(float(i))
		ts.append(t1)
		var rings := []
		for z in zs:
			var r := PackedVector3Array()
			for t in ts:
				var q := pt(z, t, grow)
				r.append(Vector3(q.x * sx, q.y, q.z))
			for j in range(ts.size() - 1, -1, -1):
				var q2 := pt(z, ts[j], -depth)
				r.append(Vector3(q2.x * sx, q2.y, q2.z))
			rings.append(r)
		return VehicleModels.solid(rings, key)


## The hull as a solid.
## `joins`: the panel joints' stations (z), where the hull's own every other
## station would fall wrongly (a nose given extra stations to round it).
static func _hull(k: VehicleModels, p: Node3D, h: Hull, key: String, mat: String, col = null, grow := 0.0, joins: Array = []) -> Variant:
	var mesh := h.mesh(key, grow)
	if h.n >= 10:
		mesh = VehicleBody.skin(mesh, key)
	var part: Variant = k._add(p, mesh, mat, col, Vector3.ZERO)
	if key.ends_with("_body") and h.n >= 10:
		# Panel joins follow the authored skin; glazing sits above them, so
		# seams cannot cut across a cockpit pane or change the hull outline.
		var zs: Array = joins.duplicate()
		if zs.is_empty():
			for station in range(2, h.st.size() - 2, 2):
				zs.append(float(h.st[station][0]))
		for z: float in zs:
			if float(h.at(z)[2]) < 0.35:
				continue
			var points: Array = []
			for t in h.n + 1:
				points.append(h.pt(z, float(t), grow + 0.006))
			VehicleBody.seam(k, p, points)
			for t: float in [0.15, 0.85, 1.15, 1.85]:
				var slot := t * h.n * 0.5
				var point := h.pt(z + 0.045, slot, grow + 0.012)
				var normal := (h.pt(z + 0.045, slot, grow + 0.022) - point).normalized()
				VehicleBody.fastener(k, p, point, normal)
	return part


## A patch on the hull, on the right (sx 1), the left (-1) or both (0).
static func _patch(k: VehicleModels, p: Node3D, h: Hull, key: String, z0: float, z1: float, t0: float, t1: float, mat: String, col = null, grow := 0.012, depth := 0.03, sx := 0.0) -> void:
	for s in ([1.0, -1.0] if sx == 0.0 else [sx]):
		if mat == "glass":
			_pane(k, p, h, key, z0, z1, t0, t1, col, grow, depth, s)
			continue
		var pkey := "%s%s" % [key, "r" if s > 0.0 else "l"]
		var mesh := h.patch(pkey, z0, z1, t0, t1, grow, depth, s)
		# (on a round hull a panel follows the skin's curve, shaded as smoothly
		# as the skin under it: flat-shaded, a livery top or a door panel showed
		# every facet as a stripe of sunlight from above, and the boom read as
		# an octagonal pipe; its cut edges keep their crease; wrecks are drawn
		# as they were)
		if h.n >= 10 and not k.wreck:
			mesh = VehicleBody.skin(mesh, pkey)
		var mi: Variant = k._add(p, mesh, mat, col, Vector3.ZERO)
		k._unshadow(mi)


## One pane of glass laid on the hull between z0..z1 and t0..t1 on one side
## (sx 1 or -1), in its rubber seal: the glass part (VmPlane.cockpit clears
## it over a crew).
static func _pane(k: VehicleModels, p: Node3D, h: Hull, key: String, z0: float, z1: float, t0: float, t1: float, col = null, grow := 0.012, depth := 0.03, sx := 1.0) -> Variant:
	var pkey := "%s%s" % [key, "r" if sx > 0.0 else "l"]
	var mesh := h.patch(pkey, z0, z1, t0, t1, grow, depth, sx)
	# (on a round hull the pane is curved glass, its reflection sliding
	# smoothly over it as the skin's light does, not broken at every facet)
	if h.n >= 10 and not k.wreck:
		mesh = VehicleBody.skin(mesh, pkey)
	return VehicleGlazing.polygon(k, p, _skin(h, z0, z1, t0, t1, sx), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), false, col, 0.012, 2, grow, mesh)


## The six-sided hull `h` with its roof sunk between z0 and z1 to make room
## for a cockpit under a glass canopy laid on h: the upper flanks stop a
## fraction `keep` of the way up their facet (along it, so they stay where
## the glass's sills sit on them) and a flat floor joins them, with a step
## down at either end (the cockpit's bulkheads). For a hexagonal (n 6,
## phase 0) round section (p 2) with an unscaled top, as the Comanche's.
## `round`: a section of eight or more points (the Little Bird's egg, the
## Ghost Hawk's faceted nose), whose roof only comes down: its widest points
## stay where they are, so the sills under the glass keep the hull's line.
static func _sunk(h: Hull, z0: float, z1: float, keep: float, round := false) -> Hull:
	var lowered := func(z: float) -> Array:
		var q := h.at(z)
		q[0] = z
		q[3] = float(q[3]) * keep
		if round:
			return q
		# (the facet's top corner, at 60 degrees, pulled along the facet
		# toward its foot: its x is widened back by the top scale)
		q[5] = 1.0 + (1.0 - keep) / sin(PI / 3.0)
		return q
	# [z, sunk] for each station: the hull's own, and a pair either side of
	# each step
	var marks: Array = [[z0 - 0.01, false], [z0 + 0.01, true], [z1 - 0.01, true], [z1 + 0.01, false]]
	for s: Array in h.st:
		var z: float = s[0]
		if z < z0 - 0.011 or z > z1 + 0.011:
			marks.append([z, false])
		elif z > z0 + 0.011 and z < z1 - 0.011:
			marks.append([z, true])
	marks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var st: Array = []
	for mk: Array in marks:
		st.append(lowered.call(float(mk[0])) if mk[1] else h.at(float(mk[0])))
	return Hull.new(st, h.n, h.p, h.ph)


## A two-pilot flight deck under the clear windscreen `ws`, the pilots side
## by side as a utility helicopter's sit: VmPlane.cockpit for the right seat
## through the stations `cst` (their x the right seat's) and for the left
## through their mirror, each pilot's seat at z `seat`. The hull under the
## windscreen must be sunk (`_sunk`) for them to show.
static func _pilots(k: VehicleModels, p: Node3D, key: String, ws: Variant, cst: Array, seat: float) -> void:
	for s: float in [1.0, -1.0]:
		var st: Array = []
		for q: Array in cst:
			var o := q.duplicate()
			o[7] = float(o[7]) * s
			st.append(o)
		VmPlane.cockpit(k, p, key + ("r" if s > 0.0 else "l"), st, ws, [seat], PIT_GLASS, 0.4, Color(0.3, 0.31, 0.28), Color(0.4, 0.42, 0.33), false, false)
	_pedestal(k, p, cst, seat)


## The middle of a flight deck whose two pilots VmPlane.cockpit seats side
## by side (the right seat's stations `cst`, his seat at z `seat`, the tub's
## `floor` as cockpit's): the instrument panel's centre under the
## glareshield, which runs on across from one pilot's coaming to the
## other's, and the centre console (radios, navigation, engine controls)
## standing between their knees back to their seats, as every two-pilot
## helicopter's is; without them the two sat at two separate desks. Both are
## dark mouldings seen only through the glass, so they cast no shadow, and
## their sizes are snapped so few new meshes are cut. Wrecks have neither.
static func _pedestal(k: VehicleModels, p: Node3D, cst: Array, seat: float, floor := 0.4) -> void:
	if k.wreck or k.burnt:
		return
	var zc := maxf(seat - 0.62, float(cst[0][0]) + 0.22)
	var qc: Array = VmPlane.st_at(cst, zc)
	var hh := float(qc[3])
	var yt := float(qc[1]) + clampf(hh * 0.55, hh * floor + 0.04, hh - 0.1)
	var gap := maxf(float(qc[7]) - float(qc[2]) * 0.55, 0.05)
	k._add(p, VehicleCab._rolled(Vector3(snappedf(gap * 2.0 + 0.04, 0.05), 0.09, 0.28), 0.03), "plain_dark", Color(0.06, 0.065, 0.07), Vector3(0, yt - 0.045, zc), Vector3.ZERO, Vector3.ONE, false)
	var qs: Array = VmPlane.st_at(cst, seat - 0.2)
	var y_t := float(qs[1]) + float(qs[3]) * floor
	var z0 := zc + 0.1
	var z1 := seat + 0.05
	k._add(p, VehicleEquipment._plate(Vector3(0.24, 0.16, snappedf(z1 - z0, 0.05))), "plain_dark", Color(0.13, 0.135, 0.14), Vector3(0, y_t - 0.02, (z0 + z1) * 0.5), Vector3.ZERO, Vector3.ONE, false)


## The hull's skin between z0..z1 and t0..t1 as a surface (q.x along z, q.y
## across t), mirrored to the left for sx -1, facing out of its middle.
static func _skin(h: Hull, z0: float, z1: float, t0: float, t1: float, sx: float) -> VehicleSurface:
	var mid := h.pt((z0 + z1) * 0.5, (t0 + t1) * 0.5)
	var out := h.pt((z0 + z1) * 0.5, (t0 + t1) * 0.5, 0.01) - mid
	return VehicleSurface.new(func(q: Vector2) -> Vector3:
		var v := h.pt(lerpf(z0, z1, q.x), lerpf(t0, t1, q.y))
		return Vector3(v.x * sx, v.y, v.z), Vector3(out.x * sx, out.y, out.z))


## A sliding door's rail laid along the hull between z0..z1 and t0..t1, on the
## right (sx 1), the left (-1) or both (0): its flanges stand grow proud of
## the skin and it is seated depth into it.
static func _door_rail(k: VehicleModels, p: Node3D, h: Hull, z0: float, z1: float, t0: float, t1: float, grow := 0.012, depth := 0.03, sx := 0.0) -> void:
	for s: float in ([1.0, -1.0] if sx == 0.0 else [sx]):
		VehicleDoors.slide_rail(k, p, _skin(h, z0, z1, t0, t1, s), z1 - z0, grow, depth)


## An open cabin doorway on the hull between z0..z1 and t0..t1, on the right
## (sx 1), the left (-1) or both (0): the cabin dark beyond it, the floor's
## worn edge at the sill (t0..floor_t) catching the light, and `seats` troop
## seats facing out of it, as a Black Hawk's or a Chinook's are: each an
## aluminium tube frame standing from the floor to the cabin roof with a
## webbing pan (pan.x..pan.y) and back (pan.y..pan.z) slung between its rails.
## The fuselage is a solid, so the cabin is laid on its skin a few millimetres
## apart, back to front, which from the battle camera reads as a room behind
## the door. The seats' webbing is kit-seeded: a crew re-slings a torn seat in
## whatever webbing the depot has. Wrecks keep their doors shut. `dark` is
## the cabin's lining as it shows in the doorway's shade.
static func _cabin(k: VehicleModels, p: Node3D, h: Hull, key: String, z0: float, z1: float, t0: float, t1: float, floor_t: float, pan: Vector3, seats: int, web: Color, sx := 0.0, dark := Color(0.05, 0.05, 0.055)) -> void:
	_patch(k, p, h, key + "_dark", z0, z1, t0, t1, "plain_dark", dark, 0.006, 0.02, sx)
	if floor_t > t0:
		_patch(k, p, h, key + "_floor", z0, z1, t0, floor_t, "nonslip", Color(0.2, 0.205, 0.2), 0.009, 0.02, sx)
	var pitch := (z1 - z0) / float(seats)
	var half := minf(0.22, pitch * 0.5 - 0.03)
	var alloy := Color(0.5, 0.52, 0.53)
	for s: float in ([1.0, -1.0] if sx == 0.0 else [sx]):
		for i in seats:
			var zc := z0 + pitch * (float(i) + 0.5)
			var tag := "%s_s%d%s" % [key, i, "r" if s > 0.0 else "l"]
			var c := web
			var rng := VehicleCargo.kit(k, p, h.pt(zc, pan.y), 61 + i)
			if rng != null:
				c = VehicleCargo.kit_colour(rng, web, VehicleCargo.KIT_STRAP, 0.7)
			_patch(k, p, h, tag + "b", zc - half, zc + half, pan.y, pan.z, "webbing", c, 0.012, 0.02, s)
			_patch(k, p, h, tag + "p", zc - half, zc + half, pan.x, pan.y - 0.03, "webbing", c.lightened(0.12), 0.013, 0.02, s)
			for e: float in [-1.0, 1.0]:
				var ze := zc + e * (half + 0.012)
				_patch(k, p, h, tag + ("u" if e > 0.0 else "v"), ze - 0.016, ze + 0.016, floor_t, t1 - 0.02, "steel", alloy, 0.016, 0.02, s)
			_patch(k, p, h, tag + "t", zc - half - 0.03, zc + half + 0.03, pan.z, pan.z + 0.05, "steel", alloy, 0.016, 0.02, s)


## The windscreen wipers on a nose windscreen (the patch over the hull's
## z0..z1 and t0..t1, one pane across the nose, its foot at z0): at each
## fraction `at` across it a dark arm parked up the glass from its pivot cap
## at the foot, leaning in a little toward the middle, the rubber blade along
## its outer part, all standing just proud of the pane. Every helicopter's
## windscreen has them, and they give the glass its scale. Wrecks are left as
## they were.
static func _wipers(k: VehicleModels, p: Node3D, h: Hull, z0: float, z1: float, t0: float, t1: float, at := [0.36, 0.64], reach := 0.72) -> void:
	if k.wreck or k.burnt:
		return
	var pane := _skin(h, z0, z1, t0, t1, 1.0)
	for u: float in at:
		var lean := 0.05 * signf(0.5 - u)
		var a := pane.point(Vector2(0.07, u), 0.032)
		var b := pane.point(Vector2(reach, u + lean), 0.032)
		VehicleFrames.beam(k, p, a, b, 0.016, 0.01, "metal_dark", null, false)
		VehicleFrames.beam(k, p, pane.point(Vector2(lerpf(0.07, reach, 0.3), u + lean * 0.3), 0.02), pane.point(Vector2(reach - 0.02, u + lean), 0.02), 0.012, 0.014, "rubber", null, false)
		k._add(p, Res.sphere(0.022, 6), "metal_dark", null, a, Vector3.ZERO, Vector3.ONE, false)


## A tailplane (or a small wing) spanning the centreline, mirrored: airfoil
## sections from the root's leading edge `le` (chord `chord`, `depth` thick)
## out `span` to a tip `tip_chord` long, its leading edge swept back `sweep`
## there. A real stabiliser is a rounded-nosed aerofoil that tapers to its
## tips, not a plank: from above its nose rolls the light and its planform
## narrows. `free` rounds off a tip with nothing on it (no endplate fin);
## `both` false builds only the right half (a tailplane on one side of a
## pylon, its root at le.x).
static func _tailplane(k: VehicleModels, p: Node3D, le: Vector3, chord: float, tip_chord: float, span: float, depth: float, mat: String, col = null, sweep := 0.0, free := false, both := true) -> void:
	var tip_depth := depth * tip_chord / chord
	var stations: Array = [[le, chord, depth], [le + Vector3(span, 0, sweep), tip_chord, tip_depth]]
	if free:
		# the tip cap: the chord pulled in from both edges over a few centimetres
		stations.append([le + Vector3(span + tip_chord * 0.12, 0, sweep + tip_chord * 0.12), tip_chord * 0.72, tip_depth * 0.6])
	VehicleAirfoils.surface(k, p, stations, mat, col, [], both)


## The flat top of a fairing (the loft's top ring `outline`, x, z pairs, at
## height y, its edge chamfered `inset` back) as a real cowling's looks from
## above: the panels a mechanic lifts off to reach the gearbox and engines,
## split by dark joints at each z in `splits` and round the edge, and the
## panels numbered in `odd` (front to back) a shade darker - a cowling
## refitted from another airframe or touched up on its own, the patchwork
## every service helicopter wears. Paint (no silhouette, a few triangles),
## in the skin's own finish so camouflage carries on under it. `x` moves the
## outline across (an engine's cowling beside the centreline).
static func _cowl_top(k: VehicleModels, p: Node3D, outline: Array, y: float, inset: float, splits: Array, odd: Array, mat: String, col = null, x := 0.0) -> void:
	var placed := VehicleModels._v2(outline)
	for i in placed.size():
		placed[i] = placed[i] + Vector2(x, 0)
	var shrunk := Geometry2D.offset_polygon(placed, -(inset + 0.025))
	if shrunk.is_empty():
		return
	var top: PackedVector2Array = shrunk[0]
	var z0 := INF
	var z1 := -INF
	for q in top:
		z0 = minf(z0, q.y)
		z1 = maxf(z1, q.y)
	# (the paint face's metres: q.x runs aft along z, q.y out along x)
	var joints: Array = []
	var ring: Array = []
	for q in top:
		ring.append(Vector2(q.y, q.x))
	ring.append(ring[0])
	joints.append(ring)
	var bounds: Array = [z0]
	for z: float in splits:
		bounds.append(z)
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(-9, z), Vector2(9, z)]), top):
			var cut: PackedVector2Array = seg
			joints.append([Vector2(cut[0].y, cut[0].x), Vector2(cut[cut.size() - 1].y, cut[cut.size() - 1].x)])
	bounds.append(z1)
	var shade := PackedVector2Array()
	for i: int in odd:
		var slab := PackedVector2Array([Vector2(-9, bounds[i]), Vector2(9, bounds[i]), Vector2(9, bounds[i + 1]), Vector2(-9, bounds[i + 1])])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(top, slab):
			var swapped := PackedVector2Array()
			for q in piece:
				swapped.append(Vector2(q.y, q.x))
			shade.append_array(VehicleAircraft._fill(swapped))
	var base: Color = col if col is Color else Mats._preset(mat).get("col_a", Color(0.5, 0.5, 0.5))
	var layers: Array = []
	if shade.size() >= 3:
		layers.append([shade, Color(base.r * 0.8, base.g * 0.8, base.b * 0.8), mat])
	layers.append([VehicleAircraft.lines(joints, 0.022), Color(base.r * 0.5, base.g * 0.5, base.b * 0.5), mat])
	VehicleAircraft.paint(k, p, VehicleAircraft.face(Vector3(0, y, 0), Vector3.UP, Vector3.BACK), layers, mat)


## The skirt under a roof fairing: its bottom outline (x, z pairs at y0, moved
## `x` across) carried down `drop` onto the hull's curved roof. A real
## fairing's flanks are fastened down to the skin round its whole edge; a
## loft standing on the roof's crown leaves daylight under its overhanging
## sides, 10-40 cm of it, that the battle camera sees as a dark slot. Where
## the outline overhangs the hull's narrowing flank, the skirt's foot is
## pulled in onto the flank, so it slopes down into the side like a cowling's
## lower panel instead of hanging in the air.
static func _skirt(k: VehicleModels, p: Node3D, h: Hull, key: String, outline: Array, y0: float, drop: float, mat: String, col = null, x := 0.0) -> void:
	var flank := _flank_skin(h, 1.0)
	var foot := PackedVector3Array()
	var head := PackedVector3Array()
	for i in range(0, outline.size(), 2):
		var px: float = float(outline[i]) + x
		var pz: float = outline[i + 1]
		var yb := y0 - drop
		var w: float = (flank.call(Vector3(0, yb, pz)) as Vector3).x - 0.03
		foot.append(Vector3(signf(px) * minf(absf(px), w), yb, pz))
		head.append(Vector3(px, y0, pz))
	k._add(p, VehicleModels.solid([foot, head], key), mat, col, Vector3.ZERO)


## Which of `count` cowling panels (front to back) are off-shade on this
## airframe: drawn from its seed, so two of a kind side by side wear
## different patchworks; scenery and wrecks (seed -1) share one.
static func _patchwork(k: VehicleModels, count: int, salt: int) -> Array:
	var bits: int = 0b0101 if k.kit_seed < 0 else hash([k.kit_seed, salt])
	var out: Array = []
	for i in count:
		if (bits >> i) & 1:
			out.append(i)
	if out.size() == count:
		out.pop_back()  # (all of them refitted is one paint again)
	return out


## A ring of points (x, y pairs) in the XY plane at z.
static func _rz(pts: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pts.size(), 2):
		r.append(Vector3(pts[i], pts[i + 1], z))
	return r


## A cylinder from a to b (radius ra at a, rb at b).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, ra: float, mat: String, col = null, segs := 8, rb := -1.0, shadow := true) -> Variant:
	return VehicleFrames.tube(k, p, a, b, ra, mat, col, segs, shadow, rb)


## A tube along a polyline.
static func _path(k: VehicleModels, p: Node3D, pts: Array, r: float, mat: String, col = null, segs := 8) -> void:
	VehicleFrames.path(k, p, pts, r, mat, col, segs)


## A box in a rotated frame (base, about origin) without a pivot node of its
## own, so it merges with the rest of its parent: blades round a hub.
static func _rbox(k: VehicleModels, p: Node3D, base: Basis, s: Vector3, lpos: Vector3, mat: String, col = null, lrot := Vector3.ZERO, shadow := true, origin := Vector3.ZERO) -> Variant:
	return k._box(p, s, origin + base * lpos, mat, col, (base * Basis.from_euler(lrot)).get_euler(), shadow)


## [material, colour] for an airframe: CSAT (team 1) gets sand (or its hex
## camouflage), everyone else the given paint.
static func _air(team: int, col: Color, hex := false) -> Array:
	if team == 1:
		return ["camo_tank_rebel", null] if hex else ["aircraft", CSAT_SAND]
	return ["aircraft", col]


# --- paint: insignia, numbers, soot ------------------------------------------------

## The national insignia a helicopter flies under: CSAT's red star for team 1,
## the AAF's roundel on its own types, otherwise the US low-visibility star.
static func _insignia_style(team: int, aaf := false) -> int:
	if team == 1:
		return VehicleAircraft.INSIGNIA_STAR
	return VehicleAircraft.INSIGNIA_ROUNDEL if aaf else VehicleAircraft.INSIGNIA_US


## A hull's flank on the right (side 1) or left (-1): a point moved across
## onto the facets at its station and height, found by halving the section
## between the belly and the roof (its height climbs steadily between them).
static func _flank_skin(h: Hull, side: float) -> Callable:
	var lo0 := (-PI / 2 - h.ph) * float(h.n) / TAU + 0.01
	var hi0 := (PI / 2 - h.ph) * float(h.n) / TAU - 0.01
	return func(q: Vector3) -> Vector3:
		var lo := lo0
		var hi := hi0
		for i in 18:
			var mid := (lo + hi) * 0.5
			if h.pt(q.z, mid).y < q.y:
				lo = mid
			else:
				hi = mid
		var v := h.pt(q.z, (lo + hi) * 0.5)
		return Vector3(v.x * side, v.y, q.z)


## A hull's roof: a point moved down onto the facets at its station and x,
## found by halving the section between its two flanks.
static func _roof_skin(h: Hull) -> Callable:
	var a0 := -h.ph * float(h.n) / TAU
	var a1 := (PI - h.ph) * float(h.n) / TAU
	return func(q: Vector3) -> Vector3:
		var lo := a0
		var hi := a1
		for i in 18:
			var mid := (lo + hi) * 0.5
			if h.pt(q.z, mid).x > q.x:
				lo = mid
			else:
				hi = mid
		return h.pt(q.z, (lo + hi) * 0.5)


## A tapered tube's skin (a tail boom from a, radius ra, to b, rb): a point
## moved straight out from the axis onto it.
static func _tube_skin(a: Vector3, b: Vector3, ra: float, rb: float) -> Callable:
	return func(q: Vector3) -> Vector3:
		var ax := b - a
		var f := clampf((q - a).dot(ax) / ax.length_squared(), 0.0, 1.0)
		var c := a + ax * f
		var out := q - c - ax.normalized() * (q - c).dot(ax.normalized())
		return c + out.normalized() * lerpf(ra, rb, f)


## Paint (VehicleAircraft layers) on both flanks of a hull, or one (sx 1
## right, -1 left), centred at station z, height y, reading toward the nose;
## `divisions` splits big triangles to follow the hull's curve (lettering
## comes in pieces already).
static func _flank_paint(k: VehicleModels, p: Node3D, h: Hull, z: float, y: float, layers: Array, sx := 0.0, divisions := 2) -> void:
	for sd: float in ([1.0, -1.0] if sx == 0.0 else [sx]):
		VehicleAircraft.paint(k, p, VehicleAircraft.face(Vector3(sd, y, z), Vector3(sd, 0, 0), Vector3(0, 0, -sd), _flank_skin(h, sd)), layers, "aircraft", divisions, 0.006)


## Paint on both faces of a flat fin or pylon (extruded across x, its faces
## at x = ±half) centred at station z, height y.
static func _fin_paint(k: VehicleModels, p: Node3D, half: float, z: float, y: float, layers: Array, x := 0.0) -> void:
	for sd: float in [-1.0, 1.0]:
		VehicleAircraft.paint(k, p, VehicleAircraft.face(Vector3(x + sd * half, y, z), Vector3(sd, 0, 0), Vector3(0, 0, -sd)), layers)


## Exhaust soot streaking aft along both flanks of a hull from station z at
## height y, `length` long and `width` wide at its broadest, darkening the
## hull's paint (mat, col) under it, `lift` off the skin (more where a
## painted patch already stands on it).
static func _flank_soot(k: VehicleModels, p: Node3D, h: Hull, z: float, y: float, length: float, width: float, mat: String, col, lift := 0.004) -> void:
	for sd: float in [1.0, -1.0]:
		VehicleAircraft.paint(k, p, VehicleAircraft.face(Vector3(sd, y, z), Vector3(sd, 0, 0), Vector3.BACK, _flank_skin(h, sd)), VehicleAircraft.soot(length, width, mat, col), mat, 0, lift)


## An airframe's own number: `fixed` for scenery and wrecks (one look per
## kind), else drawn from the vehicle's seed, each figure from its string in
## `places`, so two of a kind side by side carry different serials and bort
## numbers, as a unit's aircraft do (peers build the same: the seed is the
## entity's).
static func _number(k: VehicleModels, fixed: String, places: Array, salt := 0) -> String:
	return fixed if k.kit_seed < 0 else VehicleMarkings.tactical_number(k.kit_seed, places, salt)


## Oil weeping down both flanks of a hull from its shoulder at height y,
## `count` streaks a side between stations z0 and z1: gearbox and engine-deck
## seepage that runs down the skin and is dragged aft by the airflow, a dull
## stain in the paint's own finish (not soot-black), up to `length` long.
## Where each runs, its length and width come from the airframe's seed, so
## no two of a kind weep alike (scenery and wrecks share one set).
static func _weep(k: VehicleModels, p: Node3D, h: Hull, z0: float, z1: float, y: float, count: int, length: float, mat: String, col = null, lift := 0.004) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([k.kit_seed, 29, roundi(z0 * 10.0)])
	var base: Color = col if col is Color else Mats._preset(mat).get("col_a", Color(0.5, 0.5, 0.5))
	for sd: float in [1.0, -1.0]:
		for i in count:
			var z := lerpf(z0, z1, (float(i) + rng.randf_range(0.15, 0.85)) / float(count))
			var run := Vector3(0, -1, rng.randf_range(0.2, 0.45)).normalized()
			var layers: Array = VehicleAircraft.soot(length * rng.randf_range(0.55, 1.0), rng.randf_range(0.13, 0.22), mat, base).slice(0, 2)
			for j in layers.size():
				var f: float = [0.9, 0.82][j]
				layers[j][1] = Color(base.r * f, base.g * f, base.b * f)
			VehicleAircraft.paint(k, p, VehicleAircraft.face(Vector3(sd, y, z), Vector3(sd, 0, 0), run, _flank_skin(h, sd)), layers, mat, 0, lift)


## A bort number red edged white, as Russian helicopters wear theirs.
static func _bort(text: String, height: float) -> Array:
	return [[VehicleAircraft.lettering(text, height, "tail", height * 0.07), VehicleAircraft.STAR_WHITE], [VehicleAircraft.lettering(text, height, "tail"), VehicleAircraft.STAR_RED]]


# --- rotors ----------------------------------------------------------------------

## A rotor: n blades of radius r and chord c round a hub at pos. The hub and
## blade grips stay; the blades sit in a node shown when slow, a blur disc
## when fast. The main rotor fills k.rotor / k.blades / k.blur, any other is
## appended to k.rotors with "Blades" and "Blur" children. tip: 0 square,
## 1 swept, 2 a BERP paddle.
static func _rotor(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, main := true, phase := 0.0, droop := 0.02, hub := 0.28, tip := 0, bcol = null) -> Node3D:
	return VehicleRotors.main(k, p, pos, nb, r, c, main, phase, droop, hub, tip, bcol)


static func _tail_rotor(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, side := 1.0, phase := 0.4) -> Node3D:
	return VehicleRotors.tail(k, p, pos, nb, r, c, side, phase)


## A fin (side profile pairs z, y, convex, extruded x0..x1) with a round duct
## through it at centre c, radius rd: the fin is built as convex slices round
## the hole, so the duct is open.
static func _ducted_fin(k: VehicleModels, p: Node3D, key: String, prof: Array, c: Vector2, rd: float, x0: float, x1: float, mat: String, col = null, segs := 16) -> void:
	var poly := VehicleModels._v2(prof)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var h0 := c + Vector2(cos(a0), sin(a0)) * rd
		var h1 := c + Vector2(cos(a1), sin(a1)) * rd
		var q0 := _ray_hit(c, Vector2(cos(a0), sin(a0)), poly)
		var q1 := _ray_hit(c, Vector2(cos(a1), sin(a1)), poly)
		var pts := [h0.x, h0.y, q0.x, q0.y]
		# the outline's corners inside this wedge, in angular order
		var mids := []
		for v in poly:
			var av := fposmod((v - c).angle() - a0, TAU)
			if av > 0.0001 and av < a1 - a0 - 0.0001:
				mids.append([av, v])
		mids.sort_custom(func(m1, m2): return m1[0] < m2[0])
		for m in mids:
			pts.append((m[1] as Vector2).x)
			pts.append((m[1] as Vector2).y)
		pts.append_array([q1.x, q1.y, h1.x, h1.y])
		k._add(p, VehicleModels.extrude_x("%s%d" % [key, i], pts, x0, x1), mat, col, Vector3.ZERO)


static func _ray_hit(c: Vector2, d: Vector2, poly: PackedVector2Array) -> Vector2:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var den := d.cross(e)
		if absf(den) < 1e-8:
			continue
		var t := (a - c).cross(e) / den
		var u := (a - c).cross(d) / den
		if t > 0.0 and u >= -1e-4 and u <= 1.0001:
			best = minf(best, t)
	return c + d * (best if best < INF else 0.0)


## A fan in a duct (spinning about X): the tail rotor of a fenestron.
static func _fan(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float) -> Node3D:
	var tr := k._pivot(p, pos)
	k._cyl(tr, r * 0.3, r * 0.3, 0.22, Vector3.ZERO, Vector3(0, 0, PI / 2), "gunmetal_w", null, 12)
	# The blades go in a "Blades" node that the blur disc replaces at flight
	# speed, as on an open tail rotor: a fan in its duct turns faster still,
	# and its blades would strobe. The hub stays: it barely turns to the eye.
	var bl := k._pivot(tr, Vector3.ZERO)
	bl.name = "Blades"
	for i in nb:
		# unevenly spaced, as on the real fans (it spreads the noise)
		var bs := Basis.from_euler(Vector3(TAU * float(i) / float(nb) + sin(float(i) * 2.3) * 0.08, 0, 0))
		_rbox(k, bl, bs, Vector3(0.02, r * 0.68, c), Vector3(0, r * 0.62, 0), "aircraft", Color(0.17, 0.17, 0.18), Vector3(0, 0.35, 0))
	if not k.wreck:
		var blur := MeshInstance3D.new()
		blur.name = "Blur"
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 1.92  # (inside the duct's lip)
		disc.orientation = PlaneMesh.FACE_X
		blur.mesh = disc
		blur.material_override = VehicleModels._blur_mat()
		Mats.set_inst(blur, &"blade_count", float(nb))
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.visible = false
		tr.add_child(blur)
	k.tail_rotor = tr
	return tr


# --- landing gear ----------------------------------------------------------------

## Skids: tubes at ±x from z0 to z1 (upturned at the front), on cross tubes at
## the zs that rise to the belly (half width bx at height by).
static func _skids(k: VehicleModels, p: Node3D, x: float, z0: float, z1: float, cz: Array, bx: float, by: float, r := 0.045, mat := "gunmetal_w", col = null) -> void:
	for s in [-1.0, 1.0]:
		var y := r + 0.01
		var shoes := []
		for z in cz:
			shoes.append(Vector3(s * x, y, z))
		VehicleAircraft.skid_runner(k, p, [Vector3(s * x, y + 0.24, z0 - 0.26), Vector3(s * x, y, z0), Vector3(s * x, y, z1)], shoes, r, mat, col)
	for z in cz:
		var pts := [Vector3(-x, r + 0.01, z), Vector3(-x * 0.9, by * 0.55, z), Vector3(-bx, by, z),
			Vector3(bx, by, z), Vector3(x * 0.9, by * 0.55, z), Vector3(x, r + 0.01, z)]
		_path(k, p, pts, r * 1.1, mat, col, 8)


## A wheel on an oleo leg from the airframe (top) down to the axle.
static func _gear(k: VehicleModels, p: Node3D, top: Vector3, axle: Vector3, r: float, w: float, twin := false) -> void:
	VehicleAircraft.gear_leg(k, p, top, axle + Vector3(0, r * 0.3, 0), 0.075, Color(0.25, 0.27, 0.24))
	if twin:
		for s in [-1.0, 1.0]:
			k._wheel(p, axle + Vector3(s * (w * 0.5 + 0.03), 0, 0), r, w)
		_tube(k, p, axle - Vector3(w + 0.06, 0, 0), axle + Vector3(w + 0.06, 0, 0), 0.04, "gunmetal_w", null, 6)
	else:
		var sx := signf(axle.x - top.x) if absf(axle.x - top.x) > 0.02 else 0.0
		k._wheel(p, axle, r, w)
		if sx != 0.0:
			_tube(k, p, axle, axle - Vector3(sx * (w * 0.5 + 0.08), 0, 0), 0.045, "gunmetal_w", null, 6)


# --- weapons ---------------------------------------------------------------------

## An M134 minigun pointing -Z with its breech at pos; returns the muzzle.
## `feed` is the side its feeder (and so its chute) is on: -1 the left, as
## the gun comes, +1 the right (the feeder turned round, the motor with it),
## so a door gun on either side of the cabin feeds from inboard. `chute`
## replaces the door gun's chute with a path of the caller's (in the gun's
## space, from the feeder), where its ammunition box stands elsewhere; a
## fixed gun given one feeds through it from its box in the airframe.
static func _minigun(k: VehicleModels, p: Node3D, pos: Vector3, ln := 0.75, door := false, feed := -1.0, chute: Array[Vector3] = []) -> Vector3:
	# (on a pivot of its own at the housing: whoever lays it swings it whole)
	var g := k._pivot(p, pos)
	var fs := -feed
	# the housing, a drum round the rotor with the bearing collar at its
	# face; the feeder-delinker on its feed side, which strips the rounds
	# from the belt; the drive motor along the other; the control box under it
	var x90 := Vector3(PI / 2, 0, 0)
	k._cyl(g, 0.07, 0.07, 0.32, Vector3(0, 0, 0.1), x90, VehicleWeapons.STEEL, null, 14)
	k._cyl(g, 0.078, 0.078, 0.035, Vector3(0, 0, -0.065), x90, "metal_dark", null, 14)
	k._cyl(g, 0.074, 0.074, 0.02, Vector3(0, 0, 0.26), x90, "metal_dark", null, 14, false)
	k._add(g, BevelMesh.make(Vector3(0.085, 0.12, 0.18), 0.008), VehicleWeapons.STEEL, null, Vector3(-0.1 * fs, -0.01, 0.1))
	k._box(g, Vector3(0.012, 0.07, 0.11), Vector3(-0.146 * fs, -0.01, 0.1), "metal_dark", null, Vector3.ZERO, false)
	k._cyl(g, 0.036, 0.036, 0.19, Vector3(0.09 * fs, 0.05, 0.12), x90, "metal_dark", null, 10)
	k._cyl(g, 0.03, 0.03, 0.02, Vector3(0.09 * fs, 0.05, 0.225), x90, VehicleWeapons.STEEL, null, 10, false)
	k._add(g, BevelMesh.make(Vector3(0.1, 0.05, 0.12), 0.006), VehicleWeapons.STEEL, null, Vector3(0.0, -0.085, 0.16))
	# the six barrels from the rotor at the housing's face, clamped past
	# mid-length and just behind the muzzles
	VehicleWeapons.rotary(k, g, Vector3(0, 0, -0.1), Vector3(0, 0, -0.1 - ln), 6, 0.042, 0.013, [0.62, 1.0 - 0.03 / ln])
	var hands: Array = []
	var path: Array[Vector3] = chute.duplicate()
	if door:
		# a door gunner's spade grips behind the housing, the trigger
		# between them, and the flexible chute dropping away to the
		# ammunition box on the cabin floor
		for side: float in [-1.0, 1.0]:
			_tube(k, g, Vector3(side * 0.05, 0.0, 0.27), Vector3(side * 0.1, 0.0, 0.34), 0.012, VehicleWeapons.STEEL, null, 6)
			k._cyl(g, 0.02, 0.02, 0.15, Vector3(side * 0.1, 0.0, 0.35), Vector3.ZERO, "rubber", null, 6, false)
		k._box(g, Vector3(0.08, 0.03, 0.025), Vector3(0, 0.02, 0.33), "metal_dark", null, Vector3.ZERO, false)
		# the cradle the gun is clamped in, a cheek either side of the drum,
		# and its pintle stub standing down under the gun's axis into the
		# mount's socket (the gun traverses about it)
		k._box(g, Vector3(0.13, 0.022, 0.15), Vector3(0, -0.081, 0.0), VehicleWeapons.STEEL)
		for side: float in [-1.0, 1.0]:
			k._box(g, Vector3(0.012, 0.075, 0.12), Vector3(side * 0.077, -0.045, 0.0), VehicleWeapons.STEEL, null, Vector3.ZERO, false)
			k._cyl(g, 0.016, 0.016, 0.008, Vector3(side * 0.085, -0.03, 0.0), Vector3(0, 0, PI / 2), "metal_dark", null, 8, false)
		k._cyl(g, 0.018, 0.018, 0.09, Vector3(0, -0.135, 0.0), Vector3.ZERO, VehicleWeapons.STEEL, null, 8, false)
		# the chute out of the feeder's foot dropping away to the ammunition
		# box on the cabin floor
		if path.is_empty():
			for c: Vector3 in [Vector3(-0.1, -0.07, 0.1), Vector3(-0.13, -0.18, 0.14), Vector3(-0.12, -0.36, 0.22), Vector3(-0.06, -0.52, 0.3)]:
				path.append(Vector3(c.x * fs, c.y, c.z))
		hands = [Vector3(0.1, 0.0, 0.35), Vector3(-0.1, 0.0, 0.35)]
	else:
		# a fixed gun throws its cases and links down and back out of the
		# chute under the housing, clear of the airframe
		k._box(g, Vector3(0.05, 0.11, 0.045), Vector3(0, -0.12, 0.05), VehicleWeapons.STEEL, null, Vector3(-0.35, 0, 0), false)
	if not path.is_empty():
		# the feed chute (ribbed where its links hinge)
		_path(k, g, path, 0.034, "metal_dark", null, 8)
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			for f: float in [0.3, 0.75]:
				k._add(g, Res.torus(0.03, 0.041), "metal_dark", null, a.lerp(b, f), VehicleFrames.aim(b - a).get_euler(), Vector3.ONE, false)
	k.gun_assembly(g, Vector3(0, 0, -0.12 - ln), hands)
	return pos + Vector3(0, 0, -0.12 - ln)


## A rocket pod along Z centred at pos: tubes in its face (7 or 19).
static func _rocket_pod(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, mat := "paint", col = null, tubes := 7) -> void:
	VehicleAircraft.rocket_pod(k, p, pos, r, ln, mat, col, tubes)


## A missile along Z (nose at -Z) centred at pos: a Hellfire's blunt seeker
## cone in a lighter shade, and (with fins) its X of tail fins.
static func _missile(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, col := Color(0.32, 0.34, 0.29), fins := true) -> void:
	var surfaces: Array = [VehicleAircraft.fin_set(ln * 0.34, ln * 0.46, r * 0.7)] if fins else []
	VehicleAircraft.missile(k, p, pos, ln * 0.94, r, col, VehicleAircraft.cone(ln * 0.14), surfaces, Vector2.ZERO, Vector3.ZERO, 0.0, "paint", col.lightened(0.15))


## A four-round Hellfire launcher hanging from pos (2 x 2 missiles on rails).
static func _hellfires(k: VehicleModels, p: Node3D, pos: Vector3, rounds := 4) -> void:
	# the spine under the pylon (the launcher's own rails hold the rounds, so
	# no sway braces), the cross beam the rails hang from
	VehicleAircraft.hardpoint(k, p, pos, 1.3, 0.2, null, 0.0, 0.12, "gunmetal_w", 0.0, false)
	k._box(p, Vector3(0.62, 0.06, 1.2), pos + Vector3(0, -0.22, 0.05), "gunmetal_w")
	for i in rounds:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var row := 0.0 if i < 2 else 1.0
		_missile(k, p, pos + Vector3(sx * 0.21, -0.36 - row * 0.3, 0.0), 0.085, 1.62, Color(0.3, 0.33, 0.26))


# --- MD 500 / Little Bird -----------------------------------------------------------

## MD 500 "Little Bird": the glazed egg of a cabin on tall skids, the thin
## boom with its T-tail and endplates, a five-blade rotor on a short mast, the
## two-blade tail rotor on the left. v 0: MH-6 (benches outside for four),
## 1: AH-6 (two miniguns and two rocket pods on a cross-bar), 2: a civilian
## MD 500 with its doors on.
static func _little_bird(k: VehicleModels, team: int, seed: int, v: int) -> void:
	var m := k.root
	var pc := _air(team, NATO_BLACK)
	var mat: String = pc[0]
	var col = pc[1]
	if v == 2:
		mat = "car_paint"
		col = [Color(0.2, 0.3, 0.42), Color(0.75, 0.72, 0.65), Color(0.34, 0.17, 0.14), Color(0.55, 0.52, 0.45)][seed % 4]
	var dark := Color(0.07, 0.07, 0.07)
	var h := Hull.new([
		[-2.2, 1.1, 0.04, 0.04, 0.04],
		[-2.08, 1.12, 0.36, 0.36, 0.33],
		[-1.85, 1.17, 0.56, 0.58, 0.52],
		[-1.45, 1.22, 0.67, 0.7, 0.64],
		[-0.95, 1.26, 0.7, 0.74, 0.7],
		[-0.25, 1.27, 0.69, 0.73, 0.7],
		[0.35, 1.32, 0.63, 0.67, 0.64],
		[0.8, 1.42, 0.47, 0.56, 0.46],
		[1.15, 1.55, 0.28, 0.36, 0.27],
		[1.38, 1.62, 0.17, 0.22, 0.16],
	], 16, 2.2)
	# The bubble: an MD 500's two crew sit side by side right up in it, the
	# pilot on the right, and from above a player looks down through its
	# upper panes onto their helmets and shoulders over the instrument
	# console (an opaque sheet read as a black egg, the aircraft unmanned).
	# The hull's roof comes down under the upper panes to the crew's sills;
	# the chin windows below the flanks stay tinted, under the upper panes'
	# seal as the real bubble's are framed. Wrecks keep the solid hull and
	# the old single sheet.
	var crew := not (k.wreck or k.burnt)
	if crew:
		var pit: Hull = _sunk(h, -1.98, -0.97, 0.22, true)
		_hull(k, m, pit, "heli_lb_pit_body", mat, col, 0.0, [-0.95, 0.35])
		# (the cockpit's floor under the bubble in the dark of the cockpit,
		# not the hull's paint lit as if outside)
		_patch(k, m, pit, "heli_lb_floor", -1.97, -0.98, 0.0, 8.0, "plain_dark", Color(0.12, 0.125, 0.13), 0.004, 0.02, 1.0)
		var upper: Variant = _pane(k, m, h, "heli_lb_wtop", -2.2, -0.97, 0.0, 8.0, null, 0.012, 0.05, 1.0)
		for t: Array in [[-1.55, 0.0, "heli_lb_wchr"], [8.0, 9.55, "heli_lb_wchl"]]:
			# (plain tinted glass on the skin: the upper panes' seal frames
			# them, and a seal of their own cost as much as a crewman)
			var chin := VehicleBody.skin(h.patch(String(t[2]), -2.2, -0.97, float(t[0]), float(t[1]), 0.012, 0.05, 1.0), String(t[2]))
			k._unshadow(k._add(m, chin, "glass", null, Vector3.ZERO))
		# (an Army crew in olive flight suits and grey helmets; a civil pilot
		# in a dark shirt under a black headset)
		var suit := Color(0.22, 0.25, 0.31) if v == 2 else Color(0.4, 0.42, 0.33)
		var helmet := Color(0.13, 0.135, 0.14) if v == 2 else Color(0.3, 0.31, 0.28)
		# (the pilot's station runs in toward the nose as the bubble narrows,
		# so the tub stays inside it; the left seat's is its mirror, so the
		# second crewman sits as the pilot does, in his harness, his own
		# consoles by his elbows and the glareshield ahead of him, where a bare
		# crewman read as a dummy propped beside a fitted-out seat)
		for s: float in [1.0, -1.0]:
			VmPlane.cockpit(k, m, "heli_lb_pit" + ("" if s > 0.0 else "l"), [[-1.95, 1.19, 0.16, 0.36, 0.24, 2.0, 2.0, s * 0.14],
				[-1.5, 1.23, 0.24, 0.56, 0.36, 2.0, 2.0, s * 0.27], [-0.98, 1.26, 0.26, 0.64, 0.4, 2.0, 2.0, s * 0.31]],
				upper, [-1.12], PIT_GLASS, 0.4, helmet, suit, false, false)
		_pedestal(k, m, [[-1.95, 1.19, 0.16, 0.36, 0.24, 2.0, 2.0, 0.14], [-1.5, 1.23, 0.24, 0.56, 0.36, 2.0, 2.0, 0.27],
			[-0.98, 1.26, 0.26, 0.64, 0.4, 2.0, 2.0, 0.31]], -1.12)
	else:
		_hull(k, m, h, "heli_lb_body", mat, col)
		# the bubble: windscreen and chin windows, one framed sheet
		_patch(k, m, h, "heli_lb_wind", -2.2, -0.97, -1.55, 9.55, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_lb_mull", -2.15, -0.97, 3.82, 4.18, mat, col, 0.024, 0.02, 1.0)
	_patch(k, m, h, "heli_lb_sill", -2.12, -0.97, -0.62, -0.3, mat, col, 0.024, 0.02)
	_patch(k, m, h, "heli_lb_chin", -2.16, -1.5, 11.8, 12.2, mat, col, 0.024, 0.02, 1.0)
	_patch(k, m, h, "heli_lb_hoop", -1.06, -0.93, -2.6, 10.6, mat, col, 0.026, 0.03, 1.0)
	# doors: the pilots' (off on the military birds), the cabin's behind
	if v == 2:
		_patch(k, m, h, "heli_lb_dwin", -0.88, -0.25, -0.1, 2.55, "glass", null, 0.012)
		_patch(k, m, h, "heli_lb_rwin", -0.06, 0.48, 0.2, 2.3, "glass", null, 0.012)
		for z in [-0.2, 0.55]:
			_patch(k, m, h, "heli_lb_seam%d" % int(z * 100), z - 0.012, z + 0.012, -2.6, 2.75, "gunmetal_w", null, 0.008)
		# a cheat line down the flank
		var stripe: Color = Color(0.82, 0.8, 0.74) if (col as Color).v < 0.6 else Color(0.18, 0.24, 0.36)
		_patch(k, m, h, "heli_lb_stripe", -1.9, 1.3, -1.25, -0.95, "car_paint", stripe, 0.01)
	else:
		# (the doorways are the cabin's dark, as the open cabins' are, not a
		# grey panel: "plain" lifts so dark a tint to a mid grey; the seat
		# backs seen through them are nylon-covered. Wrecks are as they were.)
		var hole := "plain" if k.wreck or k.burnt else "plain_dark"
		var hole_col := dark if k.wreck or k.burnt else Color(0.05, 0.05, 0.055)
		_patch(k, m, h, "heli_lb_door", -0.92, -0.2, -2.55, 2.7, hole, hole_col, 0.006)
		if v == 0:
			_patch(k, m, h, "heli_lb_cabin", -0.12, 0.56, -2.4, 2.55, hole, hole_col, 0.006)
		else:
			_patch(k, m, h, "heli_lb_rwin", -0.06, 0.48, 0.2, 2.3, "glass", null, 0.012)
			_patch(k, m, h, "heli_lb_seam", 0.54, 0.57, -2.4, 2.6, "gunmetal_w", null, 0.008)
		# seat backs, seen through the openings
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.4, 0.62, 0.08), Vector3(s * 0.33, 1.22, -0.3), "plain" if k.wreck or k.burnt else "fabric", Color(0.2, 0.2, 0.18) if k.wreck or k.burnt else Color(0.24, 0.25, 0.21))
	# roof fairing over the mast and the engine intake behind it (a pressed
	# cowling's top edge is rolled, so it catches the light from above)
	k._add(m, VehicleModels.loft("heli_lb_fair", [-0.3, -0.85, 0.3, -0.85, 0.36, 0.2, 0.2, 0.78, -0.2, 0.78, -0.36, 0.2],
		[-0.17, -0.55, 0.17, -0.55, 0.24, 0.1, 0.12, 0.6, -0.12, 0.6, -0.24, 0.1], 1.9, 2.2, 0.05), mat, col, Vector3.ZERO)
	# its top: the mast fairing's panel and the intake cover behind it
	_cowl_top(k, m, [-0.17, -0.55, 0.17, -0.55, 0.24, 0.1, 0.12, 0.6, -0.12, 0.6, -0.24, 0.1], 2.2, 0.05, [0.12], _patchwork(k, 2, 3), mat, col)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.14, 0.32), Vector3(s * 0.27, 2.08, 0.2), "plain", dark, Vector3(0, 0, s * 0.35), false)
	VehicleRotors.mast(k, m, Vector3(0, 2.36, -0.25), 0.1, 0.12, 0.38, [Vector2(2.38, 0.2)])
	# exhaust under the boom root, the boom, the tail
	VehicleAircraft.turbine_exhaust(k, m, Vector3(0, 1.4, 0.95), Vector3(0, 1.33, 1.36), 0.1, 0.085)
	# the exhaust's soot streaking back along the boom's underside and lower
	# flanks, as every MD 500's boom wears it
	VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(0, 1.5, 1.42), Vector3.DOWN, Vector3.BACK, _tube_skin(Vector3(0, 1.64, 1.2), Vector3(0, 1.76, 4.8), 0.2, 0.1)), VehicleAircraft.soot(1.7, 0.34, mat, col), mat)
	_tube(k, m, Vector3(0, 1.64, 1.2), Vector3(0, 1.76, 4.8), 0.2, mat, col, 12, 0.1)
	k._add(m, Res.sphere(0.1, 10), mat, col, Vector3(0, 1.76, 4.8))
	var boom := _tube_skin(Vector3(0, 1.64, 1.2), Vector3(0, 1.76, 4.8), 0.2, 0.1)
	if v == 2:
		# a civil MD 500's registration down both sides of the boom, picked by
		# the seed from the letters the stencil can cut
		var letters := "ACEFHJLPSTU"
		var reg := "C-G"
		for i in 3:
			reg += letters[(absi(seed) / int(pow(11.0, float(i))) + i * 4) % letters.length()]
		var ink: Color = Color(0.12, 0.13, 0.15) if (col as Color).v > 0.5 else Color(0.85, 0.84, 0.8)
		for sd: float in [-1.0, 1.0]:
			VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(sd * 0.2, 1.7, 2.75), Vector3(sd, 0, 0), Vector3(0, 0, -sd), boom), [[VehicleAircraft.lettering(reg, 0.16, "tail"), ink]])
	else:
		# the Army's serial small on the boom, a shade off the black
		for sd: float in [-1.0, 1.0]:
			VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(sd * 0.2, 1.7, 3.3), Vector3(sd, 0, 0), Vector3(0, 0, -sd), boom), [[VehicleAircraft.lettering(_number(k, "23157", ["12", "0123456789", "0123456789", "0123456789", "0123456789"], 11), 0.1, "tail"), Color(0.36, 0.37, 0.37)]])
	k._add(m, VehicleModels.extrude_x("heli_lb_fin", [4.28, 1.78, 4.82, 1.78, 4.98, 2.56, 4.66, 2.57], -0.035, 0.035), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_lb_vent", [4.42, 1.74, 4.88, 1.74, 5.0, 1.24, 4.84, 1.22], -0.03, 0.03), mat, col, Vector3.ZERO)
	_tube(k, m, Vector3(0, 1.26, 4.92), Vector3(0, 1.12, 5.12), 0.018, "gunmetal_w", null, 6)
	_tailplane(k, m, Vector3(0, 2.57, 4.65), 0.36, 0.34, 0.8, 0.045, mat, col, 0.01)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_lb_endp", [4.68, 2.4, 4.98, 2.4, 5.04, 2.8, 4.84, 2.8], -0.018, 0.018), mat, col, Vector3(s * 0.8, 0, 0))
		VmPlane.nav_light(k, m, Vector3(s * 0.8, 2.56, 5.06), Vector3(0.03, 0.05, 0.05), s)
	_tail_rotor(k, m, Vector3(-0.1, 1.76, 4.88), 2, 0.7, 0.11, -1.0)
	# beacon, antennas, pitot, the landing light
	VehicleFittings.dome_light(k, m, Vector3(0, 1.93, 3.2), 0.04, _beacon(k))
	VehicleFittings.antenna(k, m, Vector3(0, 1.9, 2.3), 0, Vector3(0, 0.28, 0.18), 0.012, "gunmetal_w", null, "whip")
	VehicleFittings.antenna(k, m, Vector3(0, 0.58, 0.1), 0, Vector3(0, -0.28, 0.32), 0.01, "gunmetal_w", null, "whip")
	VehicleAircraft.pitot(k, m, Vector3(0.12, 0.9, -2.05), Vector3(0.12, 0.86, -2.42), 0.012, "steel", null)
	VehicleFittings.searchlight(k, m, Vector3(0, 0.6, -1.55), Vector3(0, -0.955, -0.296), 0.07, 0.04)
	_skids(k, m, 0.98, -1.5, 1.05, [-0.85, 0.5], 0.5, 0.62, 0.042, "gunmetal_w")
	# a step on a stub post off each skid
	for s in [-1.0, 1.0]:
		VehicleFrames.step(k, m, Vector3(s * 0.98, 0.15, -0.55), Vector2(0.16, 0.3), Vector3.ZERO, "steel")
		_tube(k, m, Vector3(s * 0.98, 0.1, -0.55), Vector3(s * 0.98, 0.14, -0.55), 0.03, "steel", null, 6)
	if v == 0:
		# the external personnel benches, two a side, facing out: the padded
		# seat on its tray with a lip along the outer edge (its pad covered in
		# nylon, like the crew seats, not the cotton duck of a truck's tilt)
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.46, 0.05, 1.85), Vector3(s * 1.05, 0.78, -0.12), "gunmetal_w")
			VehicleCab.bench(k, m, Vector3(s * 1.05, 0.82, -0.12), Vector3(0.42, 0.04, 1.75), Vector3(s, 0, 0), Vector3.ZERO, "fabric", Color(0.18, 0.19, 0.16))
			k._box(m, Vector3(0.04, 0.08, 1.85), Vector3(s * 1.28, 0.8, -0.12), "gunmetal_w", null, Vector3.ZERO, false)
			for z in [-0.85, 0.5]:
				_tube(k, m, Vector3(s * 0.95, 0.38, z), Vector3(s * 1.1, 0.76, z), 0.025, "gunmetal_w", null, 6)
				_tube(k, m, Vector3(s * 0.66, 0.92, z), Vector3(s * 0.85, 0.77, z), 0.025, "gunmetal_w", null, 6)
			# a grab rail over the doorway
			VehicleDoors.pull(k, m, Vector3(s * 0.59, 1.87, -0.175), Vector3(s, 0, 0), Vector3.BACK, 1.25, 0.012)
	elif v == 1:
		# the weapons cross-bar under the cabin floor: minigun inboard, pod out
		_tube(k, m, Vector3(-1.62, 0.92, 0.0), Vector3(1.62, 0.92, 0.0), 0.05, "gunmetal_w", null, 10)
		k._box(m, Vector3(3.0, 0.09, 0.16), Vector3(0, 0.88, 0.0), "gunmetal_w")
		for s in [-1.0, 1.0]:
			# the pylons hung under the bar, sway braces down onto the gun's
			# housing and the pod
			VehicleAircraft.hardpoint(k, m, Vector3(s * 1.0, 0.835, -0.1), 0.42, 0.09, null, 0.075, 0.08, "gunmetal_w", 0.0)
			VehicleAircraft.hardpoint(k, m, Vector3(s * 1.52, 0.835, -0.05), 0.6, 0.105, null, 0.13, 0.08, "gunmetal_w", 0.0)
			_rocket_pod(k, m, Vector3(s * 1.52, 0.6, -0.12), 0.13, 1.6, "paint", Color(0.3, 0.32, 0.27), 7)
			# each gun feeds from inboard, its chute up out of the feeder,
			# under the cross-bar and in through the cabin floor to the
			# ammunition box behind the pilots' seats
			var feed: Array[Vector3] = [Vector3(-s * 0.1, 0.05, 0.1), Vector3(-s * 0.2, 0.1, 0.25), Vector3(-s * 0.32, 0.2, 0.42), Vector3(-s * 0.42, 0.28, 0.5)]
			if s > 0.0:
				k.turret = k._pivot(m, Vector3(1.0, 0.66, -0.25))
				k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3.ZERO, 0.72, false, -s, feed))
			else:
				_minigun(k, m, Vector3(-1.0, 0.66, -0.25), 0.72, false, -s, feed)
	if v != 2:
		# the FLIR ball hanging on its neck under the nose
		VehicleEquipment.sensor(k, m, Vector3(0, 0.5, -1.8), Vector3.ONE * 0.13 * 2.0, "paint", Color(0.3, 0.31, 0.3), "ball", Vector3(0.05, 0.05, 0.18))
		# the side's chevron on top of the boom, between the whip antenna and
		# the beacon: painted round the boom's curve (a flat card stood 10 cm
		# over the round boom with its arms in the air), 5 mm proud of it
		k._team_mark(m, team, Vector3(0, 1.84, 2.82), Vector3(0.16, 0.02, 0.5), _tube_skin(Vector3(0, 1.64, 1.2), Vector3(0, 1.76, 4.8), 0.205, 0.105))
	_rotor(k, m, Vector3(0, 2.58, -0.25), 5, 4.03, 0.17, true, 0.3, 0.012, 0.2)


# --- UH-80 Ghost Hawk ----------------------------------------------------------------

## UH-80 Ghost Hawk, the stealth Black Hawk: faceted panels over a UH-60's
## lines - the angular nose and windscreens, a tumblehome cabin with its
## sliding doors, engines under a faceted top fairing, a hub cap on the
## four-blade rotor, the canted tail rotor high on the pylon over a
## stabilator, fixed main gear and a tailwheel, miniguns in the gunners'
## windows. stub: the ESSS stub wings with four rocket pods.
static func _ghost_hawk(k: VehicleModels, team: int, stub: bool) -> void:
	var m := k.root
	var pc := _air(team, NATO_BLACK)
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-7.0, 1.22, 0.1, 0.1, 0.12],
		[-6.6, 1.27, 0.62, 0.42, 0.52],
		[-5.9, 1.4, 0.95, 0.66, 0.76],
		[-5.2, 1.52, 1.07, 0.98, 0.92],
		[-4.4, 1.56, 1.13, 1.0, 1.0],
		[-2.0, 1.56, 1.18, 1.0, 1.0],
		[0.6, 1.6, 1.14, 0.95, 0.98],
		[1.9, 1.78, 0.84, 0.74, 0.6],
		[3.3, 1.98, 0.46, 0.44, 0.36],
		[6.6, 2.08, 0.3, 0.32, 0.27],
		[7.7, 2.18, 0.2, 0.26, 0.2],
	], 8, 2.6, PI / 8)
	# Windscreens: the front panes over the nose, the cockpit door windows,
	# the eyebrow windows in the roof. A Black Hawk's two pilots sit side by
	# side under the eyebrows, and from above a player sees their helmets
	# through the windscreen and the roof panes over the glareshield (opaque
	# panes read as a navy box, nobody flying): the hull's roof comes down
	# under those panes and they are clear; the door windows stay tinted.
	# Wrecks keep the solid hull and the old glass.
	var crew := not (k.wreck or k.burnt)
	var pit: Hull = _sunk(h, -6.45, -4.5, 0.3, true) if crew else h
	_hull(k, m, pit, "heli_gh_body" + ("_pit" if crew else ""), mat, col)
	if crew:
		# (the sunk sill under the windscreen in the cockpit's dark, not a
		# pale ledge of hull paint)
		_patch(k, m, pit, "heli_gh_floor", -6.44, -4.51, 0.06, 2.94, "plain_dark", Color(0.12, 0.125, 0.13), 0.004, 0.02, 1.0)
		var ws: Variant = _pane(k, m, h, "heli_gh_wind", -6.5, -5.28, 0.06, 2.94, null, 0.012, 0.05, 1.0)
		var brow: Variant = _pane(k, m, h, "heli_gh_eyeb", -5.25, -4.55, 1.08, 1.92, null, 0.012, 0.05, 1.0)
		k._restyle(brow, VmPlane.clear_glass(PIT_GLASS))
		k._unshadow(brow)
		for s: float in [1.0, -1.0]:
			VmPlane.cockpit(k, m, "heli_gh_pit%s" % ("r" if s > 0.0 else "l"), [[-6.4, 1.3, 0.18, 0.5, 0.3, 2.0, 2.0, s * 0.22],
				[-5.6, 1.48, 0.3, 0.75, 0.4, 2.0, 2.0, s * 0.4], [-4.55, 1.55, 0.32, 0.76, 0.4, 2.0, 2.0, s * 0.45]],
				ws, [-4.85], PIT_GLASS, 0.4, Color(0.3, 0.31, 0.28), Color(0.4, 0.42, 0.33), false, false)
		_pedestal(k, m, [[-6.4, 1.3, 0.18, 0.5, 0.3, 2.0, 2.0, 0.22], [-5.6, 1.48, 0.3, 0.75, 0.4, 2.0, 2.0, 0.4],
			[-4.55, 1.55, 0.32, 0.76, 0.4, 2.0, 2.0, 0.45]], -4.85)
	else:
		_patch(k, m, h, "heli_gh_wind", -6.5, -5.28, 0.06, 2.94, "glass", null, 0.012, 0.05, 1.0)
	_wipers(k, m, h, -6.5, -5.28, 0.06, 2.94)
	_patch(k, m, h, "heli_gh_post", -6.5, -5.28, 1.45, 1.55, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_gh_side", -5.1, -3.82, -0.55, 0.84, "glass", null, 0.012, 0.05)
	if not crew:
		_patch(k, m, h, "heli_gh_eyeb", -5.25, -4.55, 1.08, 1.92, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_gh_eyep", -5.25, -4.55, 1.47, 1.53, mat, col, 0.02, 0.02, 1.0)
	# door seams, the gunners' windows (open), the sliding cabin doors
	for z in [-5.2, -3.7, -2.8, -0.8]:
		_patch(k, m, h, "heli_gh_seam%d" % int(z * 10), z - 0.014, z + 0.014, -1.7, 0.96, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_gh_seamb", -2.8, -0.8, -1.72, -1.66, "gunmetal_w", null, 0.008)
	# (the gunners' open windows dark like the cabin behind the doors; a
	# wreck's as it was)
	_patch(k, m, h, "heli_gh_gunwin", -3.5, -2.92, -0.3, 0.8, "plain" if k.wreck or k.burnt else "plain_dark", dark if k.wreck or k.burnt else Color(0.05, 0.05, 0.055), 0.006)
	# the Ghost Hawk flies with its cabin doors slid back, the troops sat in
	# the doorways on outward-facing seats: the dark cabin, its floor and two
	# seats a side show where the door was; the door rides outboard on its
	# rail over the cabin's rear, its window with it, the rail run on to it.
	# A crew shuts a door for the transit leg, about one side in four (from
	# the kit seed), so a flight of them isn't one mould. Wrecks stay shut.
	var slid: Array[float] = [0.0, 0.0]
	for si in 2:
		var s := 1.0 if si == 0 else -1.0
		if k.wreck or k.burnt:
			continue
		var rng := VehicleCargo.kit(k, m, Vector3(s, 1.5, -2.0), 71)
		slid[si] = 0.0 if rng != null and rng.randf() < 0.25 else 1.35
		if slid[si] > 0.0:
			_cabin(k, m, h, "heli_gh_cab", -2.78, -1.47, -1.64, 0.92, -1.3, Vector3(-0.8, -0.62, 0.02), 2, Color(0.36, 0.34, 0.26), s)
			_patch(k, m, h, "heli_gh_door", -2.8 + slid[si], -0.8 + slid[si], -1.66, 0.93, mat, col, 0.03, 0.01, s)
			_patch(k, m, h, "heli_gh_dwino", -2.45 + slid[si], -1.2 + slid[si], -0.05, 0.76, "glass", null, 0.042, 0.03, s)
			_door_rail(k, m, h, -2.85, 0.6, 0.9, 0.98, 0.02, 0.03, s)
	for si in 2:
		if slid[si] == 0.0:
			_patch(k, m, h, "heli_gh_dwin", -2.45, -1.2, -0.05, 0.76, "glass", null, 0.012, 0.03, 1.0 if si == 0 else -1.0)
			_door_rail(k, m, h, -2.85, 0.3, 0.9, 0.98, 0.02, 0.03, 1.0 if si == 0 else -1.0)
	# the top fairing over the gearbox, the engines either side of it; their
	# top edges are broken, as the cowlings' formed panels are, not knife-sharp
	k._add(m, VehicleModels.loft("heli_gh_top", [-0.75, -3.7, 0.75, -3.7, 0.98, -2.9, 0.98, 0.9, 0.6, 1.8, -0.6, 1.8, -0.98, 0.9, -0.98, -2.9],
		[-0.42, -3.15, 0.42, -3.15, 0.6, -2.55, 0.6, 0.55, 0.32, 1.25, -0.32, 1.25, -0.6, 0.55, -0.6, -2.55], 2.45, 3.12, 0.2, 0.0, true), mat, col, Vector3.ZERO)
	_skirt(k, m, h, "heli_gh_tskirt", [-0.75, -3.7, 0.75, -3.7, 0.98, -2.9, 0.98, 0.9, 0.6, 1.8, -0.6, 1.8, -0.98, 0.9, -0.98, -2.9], 2.45, 0.4, mat, col)
	_cowl_top(k, m, [-0.42, -3.15, 0.42, -3.15, 0.6, -2.55, 0.6, 0.55, 0.32, 1.25, -0.32, 1.25, -0.6, 0.55, -0.6, -2.55], 3.12, 0.2, [-2.55, -1.45, 0.0], _patchwork(k, 4, 1), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_gh_eng", [-0.36, -2.3, 0.36, -2.3, 0.4, 0.75, -0.4, 0.75], [-0.24, -2.1, 0.24, -2.1, 0.26, 0.6, -0.26, 0.6], 2.48, 3.08, 0.15, 0.0, true), mat, col, Vector3(s * 0.78, 0, 0))
		_skirt(k, m, h, "heli_gh_eskirt%s" % ("r" if s > 0.0 else "l"), [-0.36, -2.3, 0.36, -2.3, 0.4, 0.75, -0.4, 0.75], 2.48, 0.45, mat, col, s * 0.78)
		_cowl_top(k, m, [-0.24, -2.1, 0.24, -2.1, 0.26, 0.6, -0.26, 0.6], 3.08, 0.15, [-0.85], _patchwork(k, 2, 4 + int(s)), mat, col, s * 0.78)
		# the engine inlet in the cowling's raked face, behind a louvred screen
		# (the stealth airframe's inlets are screened against radar and grit),
		# not a black plate standing off it
		VehicleFittings.grille(k, m, Vector3(s * 0.78, 2.77, -2.235), Vector2(0.36, 0.34), Vector3(-2.82, 0, 0), mat, col, 6)
		# the shrouded exhausts, turned out and up
		k._add(m, VehicleModels.loft("heli_gh_exh", [-0.24, 0.0, 0.24, 0.0, 0.2, 0.8, -0.2, 0.8], [-0.18, 0.05, 0.18, 0.05, 0.14, 0.7, -0.14, 0.7], 0.0, 0.34), "gunmetal_w", null, Vector3(s * 0.82, 2.66, 0.7), Vector3(0, s * 0.35, 0))
		k._box(m, Vector3(0.24, 0.03, 0.5), Vector3(s * 0.95, 3.01, 1.12), "plain", dark, Vector3(0, s * 0.35, 0), false)
	# mast, swashplate, the IR jammer behind, wire cutters, pitots
	VehicleRotors.mast(k, m, Vector3(0, 3.3, -2.0), 0.16, 0.2, 0.55, [Vector2(3.28, 0.34)])
	k._cyl(m, 0.13, 0.15, 0.3, Vector3(0, 3.24, 1.05), Vector3.ZERO, "gunmetal_w", null, 8)
	VehicleAircraft.wire_cutter(k, m, Vector3(0.04, 0.42, 0.08), Vector3(0, 2.75, -4.62), Vector3(0.5, 0, 0))
	VehicleAircraft.wire_cutter(k, m, Vector3(0.04, 0.3, 0.08), Vector3(0, 0.9, -6.2), Vector3(-0.6, 0, 0))
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.32, 1.72, -6.2), Vector3(s * 0.32, 1.7, -6.95), 0.018, "steel", null)
		# steps, the cabin door's grab handle, the navigation lights
		VehicleFrames.step(k, m, Vector3(s * 1.2, 0.7, -4.6), Vector2(0.12, 0.3))
		VmPlane.nav_light(k, m, Vector3(s * 1.12, 2.3, -4.2), Vector3(0.05, 0.05, 0.06), s)
		var ds: float = slid[0 if s > 0.0 else 1]
		VehicleDoors.pull(k, m, Vector3(s * (1.1 + ds * 0.022), 1.4, -2.65 + ds), Vector3(s, 0, 0), Vector3.BACK, 0.3)
	# the tail pylon, the canted tail rotor high on its right, the stabilator
	k._add(m, VehicleModels.extrude_x("heli_gh_pylon", [6.3, 2.25, 7.85, 2.2, 8.32, 4.3, 7.62, 4.42], -0.14, 0.14, 0.04), mat, col, Vector3.ZERO)
	# the Army serial on the pylon, low-visibility grey on the black; the
	# engines' soot streaking back over the boom from the turned-out exhausts
	var ink: Color = (col as Color).lightened(0.22) if col is Color else Color(0.36, 0.34, 0.28)
	_fin_paint(k, m, 0.14, 7.2, 3.1, [[VehicleAircraft.lettering(_number(k, "20316", ["12", "0123456789", "0123456789", "0123456789", "0123456789"], 12), 0.2, "tail"), ink]])
	_flank_soot(k, m, h, 1.3, 2.22, 2.6, 0.42, mat, col)
	_weep(k, m, h, -3.4, 0.4, 2.2, 3, 1.0, mat, col)
	k._add(m, VehicleModels.loft("heli_gh_tgb", [-0.12, -0.35, 0.12, -0.35, 0.12, 0.35, -0.12, 0.35], [-0.06, -0.25, 0.06, -0.25, 0.06, 0.25, -0.06, 0.25], 0.0, 0.18), mat, col, Vector3(0.12, 3.48, 7.95), Vector3(0, 0, -PI / 2))
	var cant := k._pivot(m, Vector3(0.36, 3.48, 7.95))
	cant.rotation.z = 0.35
	_tail_rotor(k, cant, Vector3.ZERO, 4, 1.68, 0.25, 1.0, 0.3)
	k._cyl(k.tail_rotor, 0.16, 0.24, 0.12, Vector3(0.14, 0, 0), Vector3(0, 0, -PI / 2), mat, col, 8)
	_tailplane(k, m, Vector3(0, 2.265, 7.3), 1.02, 0.6, 2.1, 0.09, mat, col, 0.4)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_gh_endp", [7.68, 0.0, 8.32, 0.0, 8.5, 0.62, 8.08, 0.62], -0.03, 0.03), mat, col, Vector3(s * 2.1, 2.27, 0), Vector3(0, 0, -s * 0.38))
		k._team_mark(m, team, Vector3(s * 0.4, 2.06, 4.6), Vector3(0.02, 0.24, 0.8))
	VehicleFittings.antenna(k, m, Vector3(0, 2.4, 3.6), 0, Vector3(0, 0.32, 0.3), 0.014, "gunmetal_w", null, "whip")
	k._box(m, Vector3(0.03, 0.2, 0.3), Vector3(0, 2.48, 5.6), "gunmetal_w", null, Vector3(0, 0, 0))
	VehicleFittings.dome_light(k, m, Vector3(0, 4.45, 7.65), 0.06, _beacon(k))
	# the tailwheel on its leg and drag brace
	VehicleAircraft.tailwheel(k, m, Vector3(0, 1.88, 6.05), Vector3(0, 0.24, 6.48), Vector2(0.24, 0.16), 0.06, Vector3(0, 1.84, 5.55), 0.04)
	k._wheel(m, Vector3(0, 0.24, 6.48), 0.24, 0.16)
	# main gear: drag beams and shock struts under faceted fairings, faceted
	# hub covers
	for s in [-1.0, 1.0]:
		var wp := k._wheel(m, Vector3(s * 1.48, 0.38, -3.95), 0.38, 0.26)
		VehicleAircraft.trailing_gear(k, m, Vector3(s * 0.78, 0.68, -4.35), Vector3(s * 1.08, 1.3, -3.8), Vector3(s * 1.48, 0.38, -3.95), Vector2(0.38, 0.26), 0.07, 0.08, "gunmetal_w", null, Vector3(0.22, 0.62, 0.3), mat, col, wp, 0.3, 8, Vector2(0.61, 0.977))
	# door guns: miniguns on swing-out mounts in the gunners' windows. The
	# mount's arm is hinged on the window's forward frame and swung out, its
	# pintle socket at the end under the gun, a strut down to the skin taking
	# the recoil; each gun feeds from inboard (the feeder turned to the
	# cabin's side), its chute running back in through the window to the
	# ammunition box on the floor
	for s in [-1.0, 1.0]:
		var gp := Vector3(s * 1.34, 1.62, -3.05)
		var hinge := Vector3(s * 1.1, 1.36, -3.42)
		var socket := gp + Vector3(0, -0.215, 0)
		k._cyl(m, 0.026, 0.026, 0.16, hinge, Vector3.ZERO, "gunmetal_w", null, 8)
		_tube(k, m, hinge, socket + Vector3(0, -0.05, 0), 0.024, "gunmetal_w", null, 8)
		_tube(k, m, socket + Vector3(0, -0.07, 0), Vector3(s * 1.17, 1.08, -3.0), 0.016, "gunmetal_w", null, 6)
		k._cyl(m, 0.03, 0.028, 0.12, socket + Vector3(0, -0.04, 0), Vector3.ZERO, "gunmetal_w", null, 10)
		k._cyl(m, 0.034, 0.034, 0.016, socket + Vector3(0, 0.028, 0), Vector3.ZERO, "metal_dark", null, 10, false)
		var chute: Array[Vector3] = [Vector3(-s * 0.1, -0.07, 0.1), Vector3(-s * 0.17, -0.14, 0.06), Vector3(-s * 0.27, -0.2, 0.0)]
		var tip := _minigun(k, m, gp, 0.7, true, -s, chute)
		if s > 0.0:
			k.mg_tip = k._tip(m, tip)
	if stub:
		# the External Stores Support System: anhedral stub wings over the
		# cabin's rear, braced to the floor, two pylons and two pods a side;
		# each wing a thick aerofoil drooping 6 degrees, its tip rounded off
		VehicleAirfoils.surface(k, m, [[Vector3(0.93, 2.275, -0.54), 0.88, 0.18], [Vector3(3.07, 2.06, -0.54), 0.88, 0.18], [Vector3(3.11, 2.056, -0.48), 0.76, 0.11]], mat, col)
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.3, 0.24, 1.0), Vector3(s * 1.05, 2.3, -0.1), mat, col)
			_tube(k, m, Vector3(s * 2.3, 2.08, -0.1), Vector3(s * 1.1, 0.95, -0.1), 0.045, "gunmetal_w", null, 6)
			for j in 2:
				var px: float = s * (1.7 + j * 0.95)
				var py: float = 2.16 - (absf(px) - 2.0) * 0.1
				VehicleAircraft.hardpoint(k, m, Vector3(px, py - 0.06, -0.1), 0.62, 0.24, null, 0.2, 0.1, "gunmetal_w", 0.04)
				_rocket_pod(k, m, Vector3(px, py - 0.5, -0.2), 0.2, 1.7, "paint", Color(0.3, 0.32, 0.27), 7 if j == 0 else 19)
	# the rotor: four blades with swept tips under a faceted hub cap
	_rotor(k, m, Vector3(0, 3.62, -2.0), 4, 8.18, 0.53, true, PI / 4, 0.02, 0.42, 1)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.22, 0), 0.5, 0.84, 0.2, 8, mat, col, false, Vector3(0.2, 0.5, 0.1))


# --- CH-67 Huron ----------------------------------------------------------------------

## CH-67 Huron, the stealth Chinook: a long faceted box of a fuselage on four
## fixed wheels, fuel sponsons down its flanks, the forward rotor on a low
## pylon over the cockpit and the aft one on the tall rear pylon with an
## engine either side, the shaft tunnel along the roof between them, two
## three-blade rotors turning against each other, the loading ramp under the
## tail. No tail rotor.
static func _huron(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, Color(0.24, 0.25, 0.26))
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-7.95, 1.72, 0.32, 0.3, 0.42],
		[-7.6, 1.78, 0.95, 0.74, 0.98],
		[-7.0, 1.87, 1.2, 1.15, 1.15],
		[-6.2, 1.95, 1.28, 1.25, 1.25],
		[3.9, 1.95, 1.28, 1.25, 1.25],
		[4.6, 2.0, 1.28, 1.2, 1.25],
		[7.95, 2.35, 1.2, 0.85, 0.82],
	], 8, 5.0, PI / 8)
	# Cockpit glazing: windscreen, chin windows, side windows; the crew door.
	# A Chinook's two pilots sit side by side right behind the windscreen,
	# their helmets up under its top edge: the hull's roof comes down under
	# it and it is clear (an opaque one read as a navy box, nobody flying);
	# the side and chin windows stay tinted. Wrecks keep the solid hull and
	# the old glass.
	var crew := not (k.wreck or k.burnt)
	_hull(k, m, _sunk(h, -7.7, -6.98, 0.35, true) if crew else h, "heli_hu_body" + ("_pit" if crew else ""), mat, col)
	if crew:
		var ws: Variant = _pane(k, m, h, "heli_hu_wind", -7.72, -6.98, 0.12, 2.88, null, 0.012, 0.05, 1.0)
		_pilots(k, m, "heli_hu_pit", ws, [[-7.65, 1.85, 0.2, 0.6, 0.4, 2.0, 2.0, 0.3], [-7.3, 1.85, 0.3, 0.75, 0.45, 2.0, 2.0, 0.5],
			[-6.98, 1.9, 0.32, 0.75, 0.45, 2.0, 2.0, 0.55]], -7.0)
	else:
		_patch(k, m, h, "heli_hu_wind", -7.72, -6.98, 0.12, 2.88, "glass", null, 0.012, 0.05, 1.0)
	_wipers(k, m, h, -7.72, -6.98, 0.12, 2.88)
	for t in [1.0, 1.5, 2.0]:
		_patch(k, m, h, "heli_hu_post%d" % int(t * 10), -7.72, -6.98, t - 0.04, t + 0.04, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_hu_chin", -7.76, -7.08, -1.86, -1.14, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hu_side", -6.88, -5.86, -0.55, 0.86, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hu_sidep", -6.4, -6.33, -0.55, 0.86, mat, col, 0.022, 0.02)
	for z in [-5.58, -4.72]:
		_patch(k, m, h, "heli_hu_dseam%d" % int(-z * 10), z - 0.014, z + 0.014, -1.85, 0.92, "gunmetal_w", null, 0.008, 0.03, 1.0)
	var hrng := VehicleCargo.kit(k, m, Vector3(1.3, 2.0, -5.15), 73)
	if k.wreck or k.burnt or (hrng != null and hrng.randf() < 0.25):
		_patch(k, m, h, "heli_hu_dwin", -5.42, -4.88, -0.15, 0.6, "glass", null, 0.012, 0.05, 1.0)
	else:
		# the crew door's upper half slid away, as a Chinook's flies open (a
		# crew shuts it about one sortie in four): the dark cabin and the red
		# webbing troop bench along its far wall
		_cabin(k, m, h, "heli_hu_cab", -5.54, -4.76, -0.7, 0.86, -0.7, Vector3(-0.68, -0.48, 0.32), 2, Color(0.44, 0.19, 0.15), 1.0)
	_patch(k, m, h, "heli_hu_hatch", -5.42, -4.88, -0.15, 0.6, "glass", null, 0.012, 0.05, -1.0)
	# the row of small cabin windows
	for i in 6:
		var zc := -3.6 + i * 1.4
		_patch(k, m, h, "heli_hu_cw%d" % i, zc - 0.2, zc + 0.2, -0.38, -0.12, "glass", null, 0.012)
	# oil weeping from both transmissions down the slab sides
	_weep(k, m, h, -7.0, -4.4, 3.05, 2, 1.2, mat, col)
	_weep(k, m, h, 3.3, 7.6, 3.05, 2, 1.2, mat, col)
	# the ramp: hinge line, its edges under the tail, the door in the back
	_patch(k, m, h, "heli_hu_hinge", 4.56, 4.66, 4.8, 7.2, "gunmetal_w", null, 0.012, 0.03, 1.0)
	for t in [4.85, 6.15]:
		_patch(k, m, h, "heli_hu_redge%d" % int(t * 10), 4.6, 7.95, t - 0.04, t + 0.04, "gunmetal_w", null, 0.01, 0.03, 1.0)
	k._box(m, Vector3(1.9, 0.05, 0.05), Vector3(0, 2.3, 7.96), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.75, 0.05), Vector3(s * 0.95, 1.93, 7.96), "gunmetal_w", null, Vector3.ZERO, false)
	# fuel sponsons down the flanks
	for s in [-1.0, 1.0]:
		var base := [1.02, 0.78, 1.72, 0.82, 1.92, 1.05, 1.92, 1.42, 1.74, 1.66, 1.02, 1.7]
		var rings := []
		for zf in [[-4.75, 0.3], [-4.25, 0.86], [-3.8, 1.0], [3.0, 1.0], [3.75, 0.86], [4.3, 0.35]]:
			var pts := []
			for i in range(0, base.size(), 2):
				pts.append(s * (1.02 + (float(base[i]) - 1.02) * float(zf[1])))
				pts.append(1.24 + (float(base[i + 1]) - 1.24) * float(zf[1]))
			rings.append(_rz(pts, float(zf[0])))
		k._add(m, VehicleModels.solid(rings, "heli_hu_spon%s" % ("r" if s > 0.0 else "l")), mat, col, Vector3.ZERO)
		for z in [-2.0, 0.6]:
			k._box(m, Vector3(0.03, 0.42, 0.03), Vector3(s * 1.935, 1.24, z), "gunmetal_w", null, Vector3.ZERO, false)
		k._cyl(m, 0.07, 0.07, 0.04, Vector3(s * 1.84, 1.6, -1.0), Vector3.ZERO, "gunmetal_w", null, 8, false)
		# the gear: two wheels forward of the sponsons, two under their tails
		_gear(k, m, Vector3(s * 1.3, 0.95, -4.45), Vector3(s * 1.42, 0.45, -4.62), 0.45, 0.3)
		_tube(k, m, Vector3(s * 0.8, 0.75, -4.75), Vector3(s * 1.36, 0.6, -4.62), 0.06, "gunmetal_w", null, 8)
		_gear(k, m, Vector3(s * 1.55, 0.85, 3.55), Vector3(s * 1.6, 0.45, 3.72), 0.45, 0.3)
		# steps, lights, the rescue hoist over the door
		VehicleFrames.step(k, m, Vector3(s * 1.32, 0.62, -5.15), Vector2(0.14, 0.32))
		VmPlane.nav_light(k, m, Vector3(s * 1.95, 1.66, -3.0), Vector3(0.05, 0.06, 0.06), s)
	k._box(m, Vector3(0.5, 0.18, 0.3), Vector3(1.3, 3.02, -5.15), "gunmetal_w", null, Vector3(0, 0, -0.5))
	_tube(k, m, Vector3(1.55, 3.0, -5.15), Vector3(1.55, 2.6, -5.15), 0.015, "steel", null, 4)
	# cargo hooks, the FLIR ball, pitots
	for z in [-1.5, 0.0, 1.5]:
		k._box(m, Vector3(0.2, 0.12, 0.3), Vector3(0, 0.66, z), "gunmetal_w")
	VehicleEquipment.sensor(k, m, Vector3(0, 0.7, -7.32), Vector3.ONE * 0.4, "paint", Color(0.28, 0.29, 0.28), "ball", Vector3(0.07, 0.07, 0.22))
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.45, 2.3, -7.75), Vector3(s * 0.45, 2.28, -8.25), 0.02, "steel", null)
	# forward pylon, the shaft tunnel, the tall aft pylon with its engines
	# (their roof edges broken, as the fairings' formed panels are)
	k._add(m, VehicleModels.loft("heli_hu_fpyl", [-0.95, -7.35, 0.95, -7.35, 1.1, -6.6, 1.1, -4.55, -1.1, -4.55, -1.1, -6.6],
		[-0.42, -6.85, 0.42, -6.85, 0.58, -6.4, 0.58, -5.25, -0.58, -5.25, -0.58, -6.4], 3.1, 3.92, 0.08), mat, col, Vector3.ZERO)
	_cowl_top(k, m, [-0.42, -6.85, 0.42, -6.85, 0.58, -6.4, 0.58, -5.25, -0.58, -5.25, -0.58, -6.4], 3.92, 0.08, [-6.4, -5.55], _patchwork(k, 3, 1), mat, col)
	k._add(m, VehicleModels.loft("heli_hu_tun", [-0.6, -4.8, 0.6, -4.8, 0.6, 3.6, -0.6, 3.6], [-0.4, -4.75, 0.4, -4.75, 0.4, 3.6, -0.4, 3.6], 3.1, 3.5, 0.06), mat, col, Vector3.ZERO)
	# the tunnel's top is the crew's walkway between the pylons, as on a
	# Chinook: non-skid mats in three lengths, the gritty dark coating
	# reading apart from the paint from above
	for i in 3:
		k._box(m, Vector3(0.5, 0.01, 2.6), Vector3(0, 3.505, -3.25 + float(i) * 2.72), "nonslip", Color(0.15, 0.155, 0.15), Vector3.ZERO, false)
	k._add(m, VehicleModels.loft("heli_hu_apyl", [-0.9, 3.2, 0.9, 3.2, 1.02, 4.0, 1.02, 7.98, -1.02, 7.98, -1.02, 4.0],
		[-0.5, 5.0, 0.5, 5.0, 0.58, 5.4, 0.58, 6.9, -0.58, 6.9, -0.58, 5.4], 3.1, 5.02, 0.08), mat, col, Vector3.ZERO)
	_cowl_top(k, m, [-0.5, 5.0, 0.5, 5.0, 0.58, 5.4, 0.58, 6.9, -0.58, 6.9, -0.58, 5.4], 5.02, 0.08, [5.55, 6.45], _patchwork(k, 3, 2), mat, col)
	var eng := Hull.new([[3.3, 3.55, 0.32, 0.32, 0.32], [3.6, 3.55, 0.47, 0.47, 0.47], [6.25, 3.55, 0.47, 0.47, 0.47], [6.95, 3.55, 0.33, 0.33, 0.33]], 8, 2.2, PI / 8)
	for s in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, m, cowling_rings, Vector3(s * 1.56, 0, 0), mat, col)
		VehicleAircraft.intake_face(k, m, Vector3(s * 1.56, 3.55, 3.29), 0.3, Vector3.FORWARD, 0.13)
		k._box(m, Vector3(0.32, 0.3, 0.12), Vector3(s * 1.56, 3.55, 6.98), "plain", dark, Vector3.ZERO, false)
		k._box(m, Vector3(0.5, 0.18, 1.6), Vector3(s * 1.12, 3.5, 4.9), mat, col)
		k._team_mark(m, team, Vector3(s * 0.97, 4.0, 6.6), Vector3(0.02, 0.4, 0.8))
	# masts, antennas, beacons
	VehicleRotors.mast(k, m, Vector3(0, 4.05, -5.95), 0.2, 0.24, 0.45)
	VehicleRotors.mast(k, m, Vector3(0, 5.2, 6.0), 0.2, 0.24, 0.45)
	VehicleFittings.antenna(k, m, Vector3(0, 3.5, -1.0), 0, Vector3(0, 0.4, 0.2), 0.014, "gunmetal_w", null, "whip")
	k._box(m, Vector3(0.03, 0.22, 0.32), Vector3(0, 3.6, 1.6), "gunmetal_w")
	VehicleFittings.dome_light(k, m, Vector3(0, 3.53, 2.6), 0.07, _beacon(k))
	VehicleFittings.antenna(k, m, Vector3(0, 0.66, 2.8), 0, Vector3(0, -0.3, 0.3), 0.012, "gunmetal_w", null, "whip")
	# the rotors: three-blade, contra-rotating, the aft one higher, each under
	# a six-sided hub cap
	_rotor(k, m, Vector3(0, 4.32, -5.95), 3, 9.15, 0.81, true, 0.0, 0.028, 0.5, 1)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.24, 0), 0.4, 0.78, 0.22, 6, mat, col, false)
	var rr := _rotor(k, m, Vector3(0, 5.48, 6.0), 3, 9.15, 0.81, false, PI / 3, 0.028, 0.5, 1)
	VehicleRotors.hub_cap(k, rr, Vector3(0, 0.24, 0), 0.4, 0.78, 0.22, 6, mat, col, false)


# --- AH-99 Blackfoot ------------------------------------------------------------------

## AH-99 Blackfoot, the RAH-66 Comanche: a chined, faceted stealth fuselage
## with the stepped tandem canopy, the 20 mm three-barrel gun in a chin
## turret, weapon bay doors opened out like stub wings with three Hellfires
## on each, short gear legs out of their stubs and a tailwheel, a five-blade
## rotor with swept tips, the fantail in its shroud under a T-tail.
static func _blackfoot(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, Color(0.33, 0.35, 0.33))
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-6.55, 1.02, 0.05, 0.05, 0.05],
		[-6.1, 1.05, 0.42, 0.36, 0.34],
		[-5.3, 1.1, 0.66, 0.62, 0.46],
		[-4.3, 1.15, 0.78, 0.98, 0.52],
		[-3.5, 1.18, 0.83, 1.08, 0.55],
		[-3.25, 1.19, 0.85, 1.3, 0.56],
		[-2.3, 1.2, 0.9, 1.34, 0.57],
		[-1.4, 1.22, 0.95, 1.28, 0.6],
		[0.6, 1.28, 0.92, 1.12, 0.6],
		[1.8, 1.38, 0.62, 0.8, 0.42],
		[3.8, 1.52, 0.36, 0.46, 0.28],
		[5.3, 1.58, 0.3, 0.38, 0.24],
	], 6, 2.0, 0.0)
	# The stepped tandem canopy, framed, and the night-pilotage window. The
	# Comanche's two crew sit in a cockpit sunk under its faceted glass: the
	# hull's roof drops to their sills under the panes, and the panes are
	# clear over the pilot and gunner in their seats (opaque tiles read as a
	# blue box). Wrecks keep the solid hull and the old glass.
	var crew := not (k.wreck or k.burnt)
	_hull(k, m, _sunk(h, -5.25, -2.05, 0.3) if crew else h, "heli_bf_body" + ("_pit" if crew else ""), mat, col)
	var can1: Variant = _pane(k, m, h, "heli_bf_can1", -5.25, -3.55, 0.22, 2.78, null, 0.012, 0.05)
	var can2: Variant = _pane(k, m, h, "heli_bf_can2", -3.2, -2.05, 0.22, 2.78, null, 0.012, 0.05)
	# (the gunner in front, the pilot behind and higher; olive suits, grey
	# helmets, as the Kajman's)
	VmPlane.cockpit(k, m, "heli_bf1", [[-5.2, 1.3, 0.5, 0.36, 0.02], [-4.6, 1.37, 0.58, 0.5, 0.02], [-3.6, 1.45, 0.64, 0.56, 0.02]], can1, [-4.3], PIT_GLASS, 0.4, Color(0.48, 0.49, 0.47), Color(0.4, 0.42, 0.33), false, false)
	VmPlane.cockpit(k, m, "heli_bf2", [[-3.15, 1.52, 0.66, 0.62, 0.02], [-2.6, 1.54, 0.68, 0.74, 0.02], [-2.1, 1.55, 0.68, 0.72, 0.02]], can2, [-2.62], PIT_GLASS, 0.4, Color(0.48, 0.49, 0.47), Color(0.4, 0.42, 0.33), false, false)
	_patch(k, m, h, "heli_bf_bow", -3.56, -3.2, 0.1, 2.9, mat, col, 0.026, 0.03, 1.0)
	for t in [1.0, 2.0]:
		_patch(k, m, h, "heli_bf_rail%d" % int(t), -5.25, -2.05, t - 0.05, t + 0.05, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_bf_nvps", -6.5, -6.0, 0.2, 2.8, "glass", null, 0.01, 0.04, 1.0)
	# the bays, open; engine inlets; exhaust slots down the tail
	_patch(k, m, h, "heli_bf_bay", -1.85, 0.55, -0.88, -0.1, "plain", dark, 0.006)
	_patch(k, m, h, "heli_bf_inlet", -1.95, -1.05, 0.25, 0.72, "plain", dark, 0.008)
	_patch(k, m, h, "heli_bf_exh", 1.9, 3.4, -0.72, -0.25, "plain", dark, 0.008)
	# the cooled exhaust still stains the boom aft of its slots
	_flank_soot(k, m, h, 3.35, 1.38, 2.2, 0.3, mat, col, 0.006)
	_patch(k, m, h, "heli_bf_seam", -4.35, -4.3, -0.95, 0.2, "gunmetal_w", null, 0.008)
	# The composite skin is laid up in bays, and its joints show: frame
	# joints round the airframe aft of the weapon bays and down the tail
	# cone, and an access panel over each engine bay a shade darker (one
	# flat grey read as a CG box). Wrecks as they were.
	if not k.wreck:
		for z: float in [0.62, 1.86, 3.7]:
			_patch(k, m, h, "heli_bf_joint%d" % int(z * 100), z - 0.012, z + 0.012, -3.0, 3.0, "gunmetal_w", Color(0.2, 0.21, 0.2), 0.005, 0.02, 1.0)
		_patch(k, m, h, "heli_bf_panel", -0.85, 0.4, 0.3, 0.9, mat, (col as Color).darkened(0.07) if col is Color else null, 0.004, 0.02)
	# the mast fairing and mast
	k._add(m, VehicleModels.loft("heli_bf_mast", [-0.5, -2.1, 0.5, -2.1, 0.62, -1.2, 0.55, 1.2, -0.55, 1.2, -0.62, -1.2],
		[-0.24, -1.62, 0.24, -1.62, 0.34, -1.05, 0.28, 0.35, -0.28, 0.35, -0.34, -1.05], 2.2, 2.78, 0.06), mat, col, Vector3.ZERO)
	_cowl_top(k, m, [-0.24, -1.62, 0.24, -1.62, 0.34, -1.05, 0.28, 0.35, -0.28, 0.35, -0.34, -1.05], 2.78, 0.06, [-0.65, -0.1], _patchwork(k, 3, 3), mat, col)
	VehicleRotors.mast(k, m, Vector3(0, 2.92, -1.1), 0.12, 0.16, 0.35)
	# the fantail: a shroud with an open duct, a fin over it, the T-tail
	_ducted_fin(k, m, "heli_bf_duct", [5.05, 1.25, 5.45, 0.95, 6.6, 0.95, 6.98, 1.4, 6.98, 2.15, 6.6, 2.52, 5.45, 2.52, 5.05, 2.15],
		Vector2(6.0, 1.72), 0.62, -0.19, 0.19, mat, col, 16)
	_fan(k, m, Vector3(0, 1.72, 6.0), 8, 0.6, 0.13)
	for a in [0.4, 2.2, 4.0]:
		k._box(m, Vector3(0.03, 0.56, 0.08), Vector3(-0.1, 1.72 + sin(a) * 0.32, 6.0 + cos(a) * 0.32), "gunmetal_w", null, Vector3(-a + PI / 2, 0, 0), false)
	k._add(m, VehicleModels.extrude_x("heli_bf_fin", [5.95, 2.45, 6.95, 2.45, 7.22, 3.35, 6.78, 3.38], -0.07, 0.07, 0.025), mat, col, Vector3.ZERO)
	_tailplane(k, m, Vector3(0, 3.375, 6.6), 0.7, 0.45, 1.08, 0.07, mat, col, 0.25)
	VehicleFittings.dome_light(k, m, Vector3(0, 3.44, 7.1), 0.05, _beacon(k))
	# tailwheel under the boom
	VehicleAircraft.tailwheel(k, m, Vector3(0, 1.34, 4.5), Vector3(0, 0.2, 4.88), Vector2(0.2, 0.12), 0.045)
	k._wheel(m, Vector3(0, 0.2, 4.88), 0.2, 0.12)
	for s in [-1.0, 1.0]:
		# main gear legs out of their stubs: trailing beams and struts,
		# six-sided hub covers
		k._box(m, Vector3(0.24, 0.24, 0.62), Vector3(s * 0.78, 0.8, -2.95), mat, col, Vector3(0, 0, s * 0.5))
		var wp := k._wheel(m, Vector3(s * 1.04, 0.3, -2.85), 0.3, 0.16)
		VehicleAircraft.trailing_gear(k, m, Vector3(s * 0.82, 0.8, -3.1), Vector3(s * 0.8, 0.86, -2.7), Vector3(s * 1.04, 0.3, -2.85), Vector2(0.3, 0.16), 0.06, 0.04, "gunmetal_w", null, Vector3.ZERO, mat, col, wp, 0.22, 6)
		# the bay doors opened out: three Hellfires on rails under each
		VehicleDoors.leaf(k, m, Vector3(0.82, 0.05, 2.3), Vector3(s * 1.33, 1.2, -0.65), mat, col, Vector3(0, 0, -s * 0.06), 1)
		k._box(m, Vector3(0.06, 0.12, 2.2), Vector3(s * 0.94, 1.22, -0.65), "gunmetal_w")
		for j in 3:
			var mx: float = s * (1.08 + j * 0.25)
			k._box(m, Vector3(0.06, 0.1, 1.2), Vector3(mx, 1.12, -0.6), "gunmetal_w", null, Vector3.ZERO, false)
			_missile(k, m, Vector3(mx, 0.97, -0.6), 0.085, 1.62, Color(0.3, 0.33, 0.26))
		k._team_mark(m, team, Vector3(s * 0.43, 1.58, 3.0), Vector3(0.02, 0.18, 0.7))
		VmPlane.nav_light(k, m, Vector3(s * 1.74, 1.18, -0.2), Vector3(0.05, 0.05, 0.06), s)
	# the chin turret: XM301 three-barrel 20 mm, its faceted drum and the
	# gun's cradle tucked under it
	k.turret = k._pivot(m, Vector3(0, 0.68, -4.75))
	VehicleAircraft.chin_turret(k, k.turret, Vector3(0, -0.02, 0), Vector2(0.2, 0.24), 0.2, Vector3(0, -0.18, -0.18), Vector3(0.22, 0.2, 0.55), mat, col, 0.0, Vector3.ZERO, false, 8)
	# the barrels out of the receiver, one on top, clamped near the breech and
	# at the muzzles
	VehicleWeapons.rotary(k, k.turret, Vector3(0, -0.18, -0.4), Vector3(0, -0.18, -1.7), 3, 0.045, 0.022, [0.154, 0.938], "gunmetal_w", PI / 2)
	k.mg_tip = k._tip(k.turret, Vector3(0, -0.18, -1.72))
	# pitots and an antenna
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.25, 1.35, -5.8), Vector3(s * 0.25, 1.33, -6.35), 0.012, "steel", null)
	k._box(m, Vector3(0.03, 0.16, 0.25), Vector3(0, 2.0, 1.5), "gunmetal_w")
	# the rotor: five blades with swept tips, a faceted hub shroud
	_rotor(k, m, Vector3(0, 3.12, -1.1), 5, 5.95, 0.36, true, 0.0, 0.015, 0.3, 1)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.18, 0), 0.3, 0.6, 0.2, 5, mat, col, false)


# --- CH-49 Mohawk ---------------------------------------------------------------------

## CH-49 Mohawk, the AW101 Merlin: a long, slab-sided cabin with the rear
## ramp under its upswept tail, three engines on the roof (two either side of
## the gearbox, one behind it), sponsons holding the twin-wheel main gear, a
## twin nosewheel, the five-blade rotor with BERP paddle tips, the four-blade
## tail rotor on the left of the pylon and the tailplane on its right. AAF
## two-tone: olive over grey-green.
static func _mohawk(k: VehicleModels, team: int) -> void:
	var m := k.root
	var lo := ["aircraft", Color(0.42, 0.44, 0.39)]
	var hi := ["aircraft", Color(0.3, 0.33, 0.24)]
	if team == 1:
		lo = ["aircraft", CSAT_SAND]
		hi = ["aircraft", CSAT_SAND.darkened(0.12)]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-9.8, 1.65, 0.3, 0.3, 0.4],
		[-9.4, 1.68, 0.95, 0.78, 0.92],
		[-8.8, 1.72, 1.25, 1.02, 1.08],
		[-7.9, 1.75, 1.38, 1.15, 1.13],
		[1.6, 1.75, 1.38, 1.15, 1.13],
		[2.6, 1.95, 1.36, 0.95, 0.95],
		[4.6, 2.35, 1.0, 0.62, 0.48],
		[8.4, 2.6, 0.42, 0.36, 0.3],
		[9.73, 2.7, 0.3, 0.3, 0.25],
	], 12, 3.0)
	# A Merlin's two pilots sit side by side right behind the windscreen,
	# their helmets up under its top edge: the hull's roof comes down under
	# it and it is clear (an opaque one read as a navy box, nobody flying);
	# the side and chin windows stay tinted. Wrecks keep the solid hull and
	# the old glass. (The sunk hull's panel joints are the solid hull's, less
	# the one under the windscreen.)
	var crew := not (k.wreck or k.burnt)
	if crew:
		_hull(k, m, _sunk(h, -9.5, -8.55, 0.35, true), "heli_mo_pit_body", lo[0], lo[1], 0.0, [1.6, 4.6])
	else:
		_hull(k, m, h, "heli_mo_body", lo[0], lo[1])
	# the olive upper half of the scheme
	_patch(k, m, h, "heli_mo_top", -8.6, 9.73, 0.55, 5.45, hi[0], hi[1], 0.005, 0.03, 1.0)
	# the cockpit: windscreen, chin windows, side windows
	if crew:
		var ws: Variant = _pane(k, m, h, "heli_mo_wind", -9.6, -8.55, 0.65, 5.35, null, 0.012, 0.05, 1.0)
		_pilots(k, m, "heli_mo_pit", ws, [[-9.4, 1.75, 0.22, 0.55, 0.4, 2.0, 2.0, 0.3], [-9.0, 1.78, 0.32, 0.72, 0.45, 2.0, 2.0, 0.5],
			[-8.55, 1.78, 0.34, 0.8, 0.45, 2.0, 2.0, 0.55]], -8.65)
	else:
		_patch(k, m, h, "heli_mo_wind", -9.6, -8.55, 0.65, 5.35, "glass", null, 0.012, 0.05, 1.0)
	_wipers(k, m, h, -9.6, -8.55, 0.65, 5.35)
	for t in [1.6, 3.0, 4.4]:
		_patch(k, m, h, "heli_mo_post%d" % int(t * 10), -9.6, -8.55, t - 0.05, t + 0.05, hi[0], hi[1], 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_mo_chin", -9.55, -8.75, -2.2, -1.25, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_mo_side", -8.45, -7.45, -0.35, 1.5, "glass", null, 0.012, 0.05)
	# the cabin door (right, forward), windows down both sides
	for z in [-6.85, -5.25]:
		_patch(k, m, h, "heli_mo_dseam%d" % int(-z * 10), z - 0.015, z + 0.015, -2.0, 1.7, "gunmetal_w", null, 0.01, 0.03, 1.0)
	var slid := 0.0 if k.wreck or k.burnt else 1.6
	var mrng := VehicleCargo.kit(k, m, Vector3(1.3, 1.6, -6.0), 72)
	if mrng != null and mrng.randf() < 0.25:
		slid = 0.0
	if slid > 0.0:
		# the cabin door slid back along its sill rail, as the Merlin flies
		# with it open: the dark cabin, its floor and three troop seats facing
		# out of it, the door outboard over the cabin's next window
		_cabin(k, m, h, "heli_mo_cab", -6.82, -5.28, -1.98, 1.68, -1.35, Vector3(-0.75, -0.45, 0.7), 3, Color(0.43, 0.41, 0.32), 1.0)
		_patch(k, m, h, "heli_mo_door", -6.85 + slid, -5.25 + slid, -2.0, 0.55, lo[0], lo[1], 0.03, 0.01, 1.0)
		_patch(k, m, h, "heli_mo_doorhi", -6.85 + slid, -5.25 + slid, 0.55, 1.7, hi[0], hi[1], 0.03, 0.01, 1.0)
		_patch(k, m, h, "heli_mo_dwin", -6.35 + slid, -5.75 + slid, 0.15, 0.9, "glass", null, 0.042, 0.05, 1.0)
	_door_rail(k, m, h, -6.9, -3.8 + slid * 0.14, -2.05, -1.95, 0.014, 0.03, 1.0)
	for i in 6:
		var zc := -6.05 + i * 1.32
		_patch(k, m, h, "heli_mo_cw%d" % i, zc - 0.3, zc + 0.3, 0.15, 0.9, "glass", null, 0.012, 0.03, -1.0 if slid > 0.0 and i == 0 else 0.0)
	# the ramp: hinge line, its edges
	_patch(k, m, h, "heli_mo_hinge", 1.55, 1.65, 7.6, 10.4, "gunmetal_w", null, 0.012, 0.03, 1.0)
	for t in [7.7, 10.3]:
		_patch(k, m, h, "heli_mo_redge%d" % int(t * 10), 1.6, 4.6, t - 0.05, t + 0.05, "gunmetal_w", null, 0.01, 0.03, 1.0)
	# sponsons with the twin-wheel main gear, the twin nosewheel. Each is a
	# moulded fairing, its section rounded over the bilge and the shoulder
	# and shaded round: in six flat facets it read from above as a pale
	# hexagonal drop tank hung on the flank.
	for s in [-1.0, 1.0]:
		var base := [1.25, 0.66, 1.62, 0.665, 1.88, 0.7, 2.04, 0.8, 2.13, 0.96, 2.15, 1.14, 2.13, 1.3, 2.05, 1.42, 1.9, 1.52, 1.6, 1.57, 1.25, 1.58]
		if k.wreck:
			# (a wreck's keep their old facets)
			base = [1.25, 0.66, 1.9, 0.7, 2.14, 0.95, 2.14, 1.3, 1.92, 1.52, 1.25, 1.58]
		var rings := []
		for zf in [[-1.95, 0.25], [-1.25, 0.88], [-0.8, 1.0], [1.0, 1.0], [1.6, 0.82], [2.35, 0.28]]:
			var pts := []
			for i in range(0, base.size(), 2):
				pts.append(s * (1.25 + (float(base[i]) - 1.25) * float(zf[1])))
				pts.append(1.12 + (float(base[i + 1]) - 1.12) * float(zf[1]))
			rings.append(_rz(pts, float(zf[0])))
		if k.wreck:
			k._add(m, VehicleModels.solid(rings, "heli_mo_spon%s" % ("r" if s > 0.0 else "l")), lo[0], lo[1], Vector3.ZERO)
		else:
			# (in the scheme's upper colour, as the Merlin's green runs down
			# over its sponsons: in the pale belly colour they stood out from
			# above as a pair of drop tanks)
			k._add(m, VehicleModels.solid(rings, "heli_mo_sponson%s" % ("r" if s > 0.0 else "l"), true), hi[0], hi[1], Vector3.ZERO)
		_gear(k, m, Vector3(s * 1.78, 0.72, 0.0), Vector3(s * 1.8, 0.38, 0.12), 0.38, 0.22, true)
		VmPlane.nav_light(k, m, Vector3(s * 2.15, 1.3, -0.5), Vector3(0.05, 0.06, 0.06), s)
		VehicleFrames.step(k, m, Vector3(s * 1.4, 0.66, -6.0), Vector2(0.14, 0.32))
		k._team_mark(m, team, Vector3(s * 0.4, 2.6, 7.4), Vector3(0.02, 0.26, 0.9))
	_gear(k, m, Vector3(0, 0.72, -8.3), Vector3(0, 0.32, -8.45), 0.32, 0.18, true)
	# the hoist over the door, the radome, pitots
	k._box(m, Vector3(0.55, 0.2, 0.32), Vector3(1.35, 3.0, -6.1), "gunmetal_w", null, Vector3(0, 0, -0.45))
	# the cable hanging from the hoist's arm, its hook block at the bottom
	VehicleFrames.tube(k, m, Vector3(1.62, 2.95, -6.1), Vector3(1.62, 2.61, -6.1), 0.008, "metal_dark", null, 6, false)
	k._box(m, Vector3(0.06, 0.08, 0.045), Vector3(1.62, 2.58, -6.1), "gunmetal_w", null, Vector3.ZERO, false)
	VehicleMounts.radome(k, m, Vector3(0, 0.88, -8.95), Vector3(1.3, 0.55, 1.3) * 0.9, lo[0], (lo[1] as Color).darkened(0.1))
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.55, 2.35, -9.45), Vector3(s * 0.55, 2.32, -10.0), 0.02, "steel", null)
	# the roof: gearbox fairing, three engines, their intakes and exhausts
	# (the AW101's gearbox and engine cowlings are moulded, rounded over
	# their shoulders, and come down to the cabin roof all round)
	k._add(m, VehicleModels.loft("heli_mo_roof", [-0.95, -5.5, 0.95, -5.5, 1.15, -4.7, 1.15, 1.2, 0.8, 2.3, -0.8, 2.3, -1.15, 1.2, -1.15, -4.7],
		[-0.6, -5.05, 0.6, -5.05, 0.82, -4.35, 0.82, 0.9, 0.5, 1.8, -0.5, 1.8, -0.82, 0.9, -0.82, -4.35], 2.8, 3.6, 0.22, 0.0, true), hi[0], hi[1], Vector3.ZERO)
	_skirt(k, m, h, "heli_mo_rskirt", [-0.95, -5.5, 0.95, -5.5, 1.15, -4.7, 1.15, 1.2, 0.8, 2.3, -0.8, 2.3, -1.15, 1.2, -1.15, -4.7], 2.8, 0.3, hi[0], hi[1])
	_cowl_top(k, m, [-0.6, -5.05, 0.6, -5.05, 0.82, -4.35, 0.82, 0.9, 0.5, 1.8, -0.5, 1.8, -0.82, 0.9, -0.82, -4.35], 3.6, 0.22, [-4.0, -3.1, -1.9, -0.9], _patchwork(k, 5, 1), hi[0], hi[1])
	var eng := Hull.new([[-4.75, 3.25, 0.3, 0.3, 0.3], [-4.55, 3.25, 0.38, 0.4, 0.36], [-1.9, 3.25, 0.38, 0.4, 0.36], [-1.3, 3.25, 0.3, 0.32, 0.28]], 10, 2.4)
	for s in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, m, cowling_rings, Vector3(s * 0.98, 0, 0), hi[0], hi[1])
		VehicleAircraft.intake_face(k, m, Vector3(s * 0.98, 3.25, -4.76), 0.27, Vector3.FORWARD, 0.1)
		VehicleAircraft.turbine_exhaust(k, m, Vector3(s * 1.0, 3.25, -1.45), Vector3(s * 1.42, 3.3, -1.0), 0.2, 0.18)
	k._add(m, VehicleModels.loft("heli_mo_eng2", [-0.45, -0.9, 0.45, -0.9, 0.5, 1.9, -0.5, 1.9], [-0.3, -0.75, 0.3, -0.75, 0.34, 1.6, -0.34, 1.6], 3.5, 4.0, 0.14, 0.0, true), hi[0], hi[1], Vector3.ZERO)
	_cowl_top(k, m, [-0.3, -0.75, 0.3, -0.75, 0.34, 1.6, -0.34, 1.6], 4.0, 0.14, [0.4], _patchwork(k, 2, 2), hi[0], hi[1])
	k._box(m, Vector3(0.5, 0.3, 0.04), Vector3(0, 3.78, -0.92), "plain", dark, Vector3(-0.3, 0, 0), false)
	VehicleAircraft.turbine_exhaust(k, m, Vector3(-0.3, 3.7, 1.7), Vector3(-0.6, 3.75, 2.3), 0.18, 0.16)
	# mast, the IR jammer, antennas
	VehicleRotors.mast(k, m, Vector3(0, 4.1, -2.5), 0.2, 0.26, 0.6, [Vector2(3.95, 0.42)])
	VehicleFittings.antenna(k, m, Vector3(0, 2.95, 4.0), 0, Vector3(0, 0.4, 0.3), 0.014, "gunmetal_w", null, "whip")
	k._box(m, Vector3(0.03, 0.22, 0.32), Vector3(0, 3.05, 6.0), "gunmetal_w")
	VehicleFittings.antenna(k, m, Vector3(0, 0.64, -3.0), 0, Vector3(0, -0.32, 0.3), 0.012, "gunmetal_w", null, "whip")
	# the tail pylon, the tail rotor on its left, the tailplane on its right
	k._add(m, VehicleModels.extrude_x("heli_mo_pylon", [7.95, 2.6, 9.75, 2.5, 10.15, 5.3, 9.3, 5.45], -0.16, 0.16, 0.05), hi[0], hi[1], Vector3.ZERO)
	# the national insignia on the cabin's flanks aft, the serial on the
	# pylon, the side engines' soot streaking back down the roof's flanks
	var style := _insignia_style(team, true)
	_flank_paint(k, m, h, 2.1, 1.95, VehicleAircraft.insignia(style, 0.4, Color(0.17, 0.22, 0.15), Color(0.62, 0.63, 0.55)), 0.0, 0 if style == VehicleAircraft.INSIGNIA_ROUNDEL else 2)
	_fin_paint(k, m, 0.16, 9.25, 3.55, [[VehicleAircraft.lettering(_number(k, "1042", ["1", "0", "0123456789", "0123456789"], 13), 0.3, "tail"), Color(0.14, 0.16, 0.12)]])
	_flank_soot(k, m, h, -0.85, 2.5, 3.4, 0.5, hi[0], hi[1], 0.008)
	# (from under the olive top, in the grey-green they run down over)
	_weep(k, m, h, -5.0, 0.8, 2.2, 4, 1.1, lo[0], lo[1])
	_tailplane(k, m, Vector3(0.1, 4.97, 9.15), 0.9, 0.6, 2.25, 0.1, hi[0], hi[1], 0.2, false, false)
	k._add(m, VehicleModels.extrude_x("heli_mo_tendp", [9.3, 4.75, 9.95, 4.75, 10.05, 5.25, 9.55, 5.25], -0.025, 0.025), hi[0], hi[1], Vector3(2.35, 0, 0))
	VehicleFittings.dome_light(k, m, Vector3(0, 5.5, 9.45), 0.07, _beacon(k))
	_tail_rotor(k, m, Vector3(-0.22, 4.68, 9.55), 4, 2.0, 0.3, -1.0, 0.2)
	k._cyl(k.tail_rotor, 0.14, 0.22, 0.14, Vector3(-0.12, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	# the rotor: five BERP blades under a domed hub cap
	_rotor(k, m, Vector3(0, 4.45, -2.5), 5, 9.3, 0.62, true, 0.25, 0.026, 0.5, 2)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.2, 0), 0.36, 0.5, 0.18, 10)


# --- WY-55 Hellcat --------------------------------------------------------------------

## WY-55 Hellcat, the AW159 Wildcat (on skids): the compact Lynx cabin with
## the Wildcat's angular nose and its sensor turret on top, sliding doors,
## twin engines under the roof fairing exhausting out the sides, the slim
## boom up to the swept pylon with the four-blade tail rotor on the left and
## the tailplane on the right, four BERP blades, weapon pylons either side
## with a minigun and a rocket pod.
static func _hellcat(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank"
	var col = AAF_GREEN
	if team == 1:
		mat = "camo_tank_rebel"
		col = null
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-5.5, 1.35, 0.18, 0.18, 0.24],
		[-5.15, 1.38, 0.62, 0.5, 0.58],
		[-4.5, 1.48, 0.92, 0.76, 0.72],
		[-3.6, 1.6, 1.0, 0.86, 0.85],
		[0.4, 1.62, 1.02, 0.85, 0.85],
		[1.3, 1.8, 0.78, 0.66, 0.6],
		[2.4, 2.0, 0.42, 0.38, 0.32],
		[6.0, 2.18, 0.26, 0.26, 0.22],
		[6.6, 2.22, 0.22, 0.24, 0.2],
	], 12, 2.6)
	# Glazing: windscreen, chin windows, cockpit doors; the sliding doors.
	# A Wildcat's two pilots sit side by side up under the windscreen, and
	# from above a player sees their helmets through it: the hull's roof
	# comes down under the windscreen and it is clear (an opaque one read as
	# a navy box, nobody flying); the door and chin windows stay tinted.
	# Wrecks keep the solid hull and the old glass.
	var crew := not (k.wreck or k.burnt)
	# (the sunk hull's panel joints at the solid hull's, less the one under
	# the windscreen)
	if crew:
		_hull(k, m, _sunk(h, -4.7, -3.62, 0.3, true), "heli_hc_pit_body", mat, col, 0.0, [0.4, 2.4])
	else:
		_hull(k, m, h, "heli_hc_body", mat, col)
	if crew:
		var ws: Variant = _pane(k, m, h, "heli_hc_wind", -4.75, -3.62, 0.55, 5.45, null, 0.012, 0.05, 1.0)
		_pilots(k, m, "heli_hc_pit", ws, [[-4.6, 1.5, 0.2, 0.6, 0.35, 2.0, 2.0, 0.25], [-4.1, 1.5, 0.3, 0.75, 0.38, 2.0, 2.0, 0.42],
			[-3.66, 1.55, 0.32, 0.77, 0.4, 2.0, 2.0, 0.45]], -3.8)
	else:
		_patch(k, m, h, "heli_hc_wind", -4.75, -3.62, 0.55, 5.45, "glass", null, 0.012, 0.05, 1.0)
	_wipers(k, m, h, -4.75, -3.62, 0.55, 5.45)
	_patch(k, m, h, "heli_hc_post", -4.75, -3.62, 2.95, 3.05, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_hc_chin", -5.1, -4.3, -2.1, -1.2, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hc_side", -3.5, -2.45, -0.35, 1.6, "glass", null, 0.012, 0.05)
	for z in [-3.58, -2.35, -0.55]:
		_patch(k, m, h, "heli_hc_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.2, 1.75, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_hc_dwin", -2.05, -0.95, 0.15, 1.35, "glass", null, 0.012)
	_door_rail(k, m, h, -2.4, 0.5, 1.75, 1.85, 0.016)
	# the roof fairing, engines with side exhausts, mast
	k._add(m, VehicleModels.loft("heli_hc_roof", [-0.72, -3.3, 0.72, -3.3, 0.9, -2.5, 0.9, 1.2, 0.5, 2.3, -0.5, 2.3, -0.9, 1.2, -0.9, -2.5],
		[-0.42, -2.9, 0.42, -2.9, 0.6, -2.2, 0.6, 0.9, 0.3, 1.8, -0.3, 1.8, -0.6, 0.9, -0.6, -2.2], 2.3, 2.95, 0.08), mat, col, Vector3.ZERO)
	_skirt(k, m, h, "heli_hc_rskirt", [-0.72, -3.3, 0.72, -3.3, 0.9, -2.5, 0.9, 1.2, 0.5, 2.3, -0.5, 2.3, -0.9, 1.2, -0.9, -2.5], 2.3, 0.26, mat, col)
	_cowl_top(k, m, [-0.42, -2.9, 0.42, -2.9, 0.6, -2.2, 0.6, 0.9, 0.3, 1.8, -0.3, 1.8, -0.6, 0.9, -0.6, -2.2], 2.95, 0.08, [-2.1, -1.25, -0.15, 0.9], _patchwork(k, 5, 1), mat, col)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.3, 0.5), Vector3(s * 0.8, 2.62, -1.9), "plain", dark, Vector3(0, 0, s * 0.3), false)
		VehicleAircraft.turbine_exhaust(k, m, Vector3(s * 0.6, 2.62, 0.75), Vector3(s * 0.98, 2.62, 1.1), 0.17, 0.15)
	VehicleRotors.mast(k, m, Vector3(0, 3.12, -0.7), 0.14, 0.18, 0.45, [Vector2(3.02, 0.3)])
	# the sensor turret standing on its neck on the nose, pitots, wire cutters
	VehicleEquipment.sensor(k, m, Vector3(0, 2.28, -4.85), Vector3.ONE * 0.21 * 2.0, "paint", Color(0.3, 0.31, 0.3), "ball", Vector3(0.12, 0.15, -0.3))
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.35, 1.6, -5.1), Vector3(s * 0.35, 1.58, -5.65), 0.015, "steel", null)
	VehicleAircraft.wire_cutter(k, m, Vector3(0.04, 0.34, 0.08), Vector3(0, 2.62, -3.7), Vector3(0.5, 0, 0))
	# the tail: pylon, tail rotor on its left, tailplane on its right
	k._add(m, VehicleModels.extrude_x("heli_hc_pylon", [5.55, 2.1, 6.95, 2.05, 7.32, 3.75, 6.75, 3.85], -0.12, 0.12, 0.04), mat, col, Vector3.ZERO)
	# the national insignia on the flanks behind the doors, the serial on
	# the pylon, the engines' soot streaking back along the boom
	_flank_paint(k, m, h, 0.95, 1.74, VehicleAircraft.insignia(_insignia_style(team, true), 0.3, Color(0.17, 0.22, 0.15), Color(0.62, 0.63, 0.55)), 0.0, 0 if team != 1 else 2)
	_fin_paint(k, m, 0.12, 6.45, 2.75, [[VehicleAircraft.lettering(_number(k, "502", ["5", "0123", "0123456789"], 14), 0.24, "tail"), Color(0.12, 0.13, 0.1)]])
	_flank_soot(k, m, h, 1.25, 2.12, 2.4, 0.36, mat, col)
	_weep(k, m, h, -3.0, 0.6, 2.15, 3, 0.9, mat, col)
	_tailplane(k, m, Vector3(0.08, 2.74, 5.95), 0.75, 0.45, 1.47, 0.08, mat, col, 0.2, false, false)
	k._add(m, VehicleModels.extrude_x("heli_hc_tendp", [6.05, 2.5, 6.62, 2.5, 6.72, 3.0, 6.28, 3.0], -0.02, 0.02), mat, col, Vector3(1.55, 0, 0))
	k._add(m, VehicleModels.extrude_x("heli_hc_vent", [5.9, 2.0, 6.5, 2.0, 6.75, 1.55, 6.5, 1.5], -0.04, 0.04), mat, col, Vector3.ZERO)
	_tail_rotor(k, m, Vector3(-0.18, 3.28, 6.95), 4, 1.1, 0.18, -1.0, 0.2)
	VehicleFittings.dome_light(k, m, Vector3(0, 3.88, 6.8), 0.05, _beacon(k))
	VehicleFittings.antenna(k, m, Vector3(0, 2.36, 3.0), 0, Vector3(0, 0.3, 0.25), 0.012, "gunmetal_w", null, "whip")
	# skids and their steps
	_skids(k, m, 1.15, -3.3, 0.95, [-2.55, 0.25], 0.7, 0.8, 0.05, "gunmetal_w")
	for s in [-1.0, 1.0]:
		VehicleFrames.step(k, m, Vector3(s * 1.15, 0.18, -3.0), Vector2(0.16, 0.34), Vector3.ZERO, "steel")
		VmPlane.nav_light(k, m, Vector3(s * 1.0, 1.2, -4.0), Vector3(0.05, 0.06, 0.06), s)
		k._team_mark(m, team, Vector3(s * 0.29, 2.14, 4.4), Vector3(0.02, 0.18, 0.7))
	# weapon pylons: a minigun inboard, a rocket pod out
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_hc_pyl%d" % int(s), _mx([0.0, -0.45, 1.0, -0.3, 1.0, 0.15, 0.0, 0.3], s), _mx([0.0, -0.4, 1.0, -0.27, 1.0, 0.12, 0.0, 0.25], s), 0.0, 0.1),
			mat, col, Vector3(s * 0.85, 1.05, -1.25))
		VehicleAircraft.hardpoint(k, m, Vector3(s * 1.3, 1.05, -1.3), 0.5, 0.16, null, 0.09, 0.08, "gunmetal_w", 0.04)
		# The outer pylon runs past the wing's trailing edge, so it hangs flush
		# under the skin rather than standing on a fairing.
		VehicleAircraft.hardpoint(k, m, Vector3(s * 1.78, 1.05, -1.25), 0.7, 0.16, null, 0.17, 0.08, "gunmetal_w", 0.0)
		_rocket_pod(k, m, Vector3(s * 1.78, 0.72, -1.3), 0.17, 1.6, "paint", Color(0.3, 0.32, 0.27), 7)
		# the minigun feeds from inboard, its chute rising from the feeder
		# into the stub wing, where its ammunition rides
		var feed: Array[Vector3] = [Vector3(-s * 0.1, 0.05, 0.1), Vector3(-s * 0.15, 0.13, 0.2), Vector3(-s * 0.2, 0.26, 0.3)]
		if s > 0.0:
			k.turret = k._pivot(m, Vector3(1.3, 0.8, -1.4))
			k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3.ZERO, 0.72, false, -s, feed))
		else:
			_minigun(k, m, Vector3(-1.3, 0.8, -1.4), 0.72, false, -s, feed)
	# the rotor: four BERP blades on the compact hub, under its domed cap
	_rotor(k, m, Vector3(0, 3.4, -0.7), 4, 6.4, 0.39, true, PI / 4, 0.018, 0.32, 2)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.18, 0), 0.22, 0.32, 0.14, 10)


## Flat [x, z, ...] pairs with x scaled by s (mirrors an outline to the left).
static func _mx(a: Array, s: float) -> Array:
	var o := a.duplicate()
	for i in range(0, o.size(), 2):
		o[i] = float(o[i]) * s
	return o


## The anti-collision beacon's lens: aviation red, bright enough to pick out
## on the cabin roof or the fin from the battle camera (the old deep red read
## as a dark speck); a wreck keeps the old one.
static func _beacon(k: VehicleModels) -> Color:
	return Color(0.55, 0.08, 0.06) if k.wreck else Color(0.82, 0.1, 0.07)


## A faceted canopy of flat panes: a glass loft between two XZ outlines (at
## y0 and y1), framed with bars along its edges in the airframe's paint.
## Returns the glass part (VmPlane.cockpit clears it over a crew).
static func _canopy(k: VehicleModels, p: Node3D, key: String, bottom: Array, top: Array, y0: float, y1: float, mat: String, col = null, r := 0.03) -> Variant:
	var glass: Variant = k._add(p, VehicleModels.loft(key, bottom, top, y0, y1), "glass", null, Vector3.ZERO)
	var nb := bottom.size() >> 1
	for i in nb:
		var j := (i + 1) % nb
		var b := Vector3(bottom[2 * i], y0, bottom[2 * i + 1])
		var t := Vector3(top[2 * i], y1, top[2 * i + 1])
		var t2 := Vector3(top[2 * j], y1, top[2 * j + 1])
		_tube(k, p, b, t, r, mat, col, 6)
		_tube(k, p, t, t2, r, mat, col, 6)
		k._add(p, Res.sphere(r, 6), mat, col, t)
	return glass


## A launcher of four anti-tank missile tubes (2 x 2) hanging from pos.
static func _atgm_tubes(k: VehicleModels, p: Node3D, pos: Vector3, ln := 1.9, r := 0.11) -> void:
	# the spine under the pylon (the tubes' frames hold them, so no sway
	# braces), the plate the tubes hang from
	VehicleAircraft.hardpoint(k, p, pos, ln * 0.6, 0.16, null, 0.0, 0.1, "gunmetal_w", 0.0, false)
	k._box(p, Vector3(r * 4.6, 0.05, ln * 0.7), pos + Vector3(0, -0.18, 0), "gunmetal_w")
	for i in 4:
		var x := (r * 1.08) * (-1.0 if i % 2 == 0 else 1.0)
		var y := -0.18 - r * 1.1 - (0.0 if i < 2 else r * 2.15)
		VehicleWeapons.launch_tube(k, p, pos + Vector3(x, y, 0), r, ln, "paint", Color(0.33, 0.35, 0.28))
	for z in [-ln * 0.38, ln * 0.38]:
		k._box(p, Vector3(r * 4.7, r * 4.6, 0.05), pos + Vector3(0, -0.18 - r * 2.15, z), "gunmetal_w", null, Vector3.ZERO, false)


# --- Mi-48 Kajman ---------------------------------------------------------------------

## Mi-48 Kajman: the Mi-28's stepped tandem cockpit of flat armoured panes
## on a Mi-24-style fuselage with its troop cabin and split doors, the
## Ka-50/52's coaxial rotors (three blades each, turning against each other,
## no tail rotor), twin engines with exhaust deflectors, stub wings with six
## pylons (rocket pods and Ataka tubes) and countermeasure pods at the tips,
## the 30 mm cannon in a chin turret, fixed tailwheel gear.
static func _kajman(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank_rebel"
	var col = null
	if team != 1:
		mat = "aircraft"
		col = NATO_GREY
	var h := Hull.new([
		[-8.35, 1.35, 0.12, 0.12, 0.12],
		[-8.0, 1.38, 0.5, 0.45, 0.48],
		[-7.2, 1.42, 0.62, 0.6, 0.6],
		[-6.2, 1.45, 0.68, 0.68, 0.62],
		[-5.3, 1.5, 0.74, 0.82, 0.66],
		[-4.4, 1.55, 0.84, 0.95, 0.72],
		[-3.6, 1.6, 0.96, 1.0, 0.8],
		[0.6, 1.65, 0.98, 1.0, 0.82],
		[1.6, 1.85, 0.7, 0.78, 0.6],
		[3.0, 2.05, 0.4, 0.42, 0.34],
		[7.6, 2.25, 0.24, 0.26, 0.2],
		[8.4, 2.3, 0.16, 0.2, 0.16],
	], 12, 2.6)
	_hull(k, m, h, "heli_kj_body", mat, col)
	# the stepped cockpits: the gunner low in front, the pilot high behind
	var can1: Variant = _canopy(k, m, "heli_kj_can1", [-0.6, -7.25, 0.6, -7.25, 0.7, -5.45, -0.7, -5.45], [-0.34, -6.75, 0.34, -6.75, 0.42, -5.5, -0.42, -5.5], 1.95, 2.55, mat, col, 0.035)
	var can2: Variant = _canopy(k, m, "heli_kj_can2", [-0.72, -5.55, 0.72, -5.55, 0.84, -3.75, -0.84, -3.75], [-0.4, -5.1, 0.4, -5.1, 0.5, -3.8, -0.5, -3.8], 2.3, 3.05, mat, col, 0.035)
	# the crew under the flat panes, as a Mi-28's are seen from above: the
	# gunner (sight on his coaming) low in front, the pilot high behind (the
	# rows are the panes' outlines as ellipses inside them, for the tubs)
	# (armoured seats, not ejection seats; the gunner's sight is the one
	# combiner glass aboard, the pilot reading his off the helmet)
	VmPlane.cockpit(k, m, "heli_kj1", [[-7.15, 1.95, 0.6, 0.12, 0.02], [-6.75, 1.95, 0.62, 0.6, 0.02], [-5.55, 1.95, 0.69, 0.6, 0.02]], can1, [-6.3], PIT_GLASS, 0.4, Color(0.52, 0.53, 0.5), Color(0.4, 0.42, 0.33), true, false)
	VmPlane.cockpit(k, m, "heli_kj2", [[-5.45, 2.3, 0.72, 0.15, 0.02], [-5.1, 2.3, 0.75, 0.75, 0.02], [-3.85, 2.3, 0.83, 0.75, 0.02]], can2, [-4.4], PIT_GLASS, 0.4, Color(0.52, 0.53, 0.5), Color(0.4, 0.42, 0.33), false, false)
	k._add(m, VehicleModels.loft("heli_kj_spine", [-0.84, -3.8, 0.84, -3.8, 0.75, -2.9, -0.75, -2.9], [-0.5, -3.8, 0.5, -3.8, 0.45, -3.0, -0.45, -3.0], 2.5, 3.05, 0.06), mat, col, Vector3.ZERO)
	# the cabin: split doors with a window in the upper half, side windows
	for z in [-3.25, -1.95]:
		_patch(k, m, h, "heli_kj_dseam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.4, 1.85, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_kj_dsplit", -3.25, -1.95, -0.32, -0.26, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_kj_dwin", -2.95, -2.25, 0.15, 1.0, "glass", null, 0.012)
	for i in 3:
		var zc := -1.35 + i * 0.75
		_patch(k, m, h, "heli_kj_cw%d" % i, zc - 0.2, zc + 0.2, 0.35, 0.95, "glass", null, 0.012)
	# the nose sensors
	VehicleEquipment.sensor(k, m, Vector3(0, 1.05, -7.85), Vector3.ONE * 0.6, "paint", Color(0.3, 0.31, 0.29), "ball")
	k._add(m, Res.sphere(0.17, 10), "paint", Color(0.3, 0.31, 0.29), Vector3(0, 1.75, -8.05))
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.3, 1.6, -7.9), Vector3(s * 0.3, 1.58, -8.55), 0.018, "steel", null)
	# top fairing, the engines with their dust filters and exhaust deflectors
	k._add(m, VehicleModels.loft("heli_kj_top", [-0.6, -3.0, 0.6, -3.0, 0.75, -2.3, 0.75, 0.8, 0.45, 1.4, -0.45, 1.4, -0.75, 0.8, -0.75, -2.3],
		[-0.35, -2.6, 0.35, -2.6, 0.48, -2.0, 0.48, 0.4, 0.25, 1.0, -0.25, 1.0, -0.48, 0.4, -0.48, -2.0], 2.5, 3.32, 0.08), mat, col, Vector3.ZERO)
	_cowl_top(k, m, [-0.35, -2.6, 0.35, -2.6, 0.48, -2.0, 0.48, 0.4, 0.25, 1.0, -0.25, 1.0, -0.48, 0.4, -0.48, -2.0], 3.32, 0.08, [-1.95, -0.85, 0.3], _patchwork(k, 4, 1), mat, col)
	var eng := Hull.new([[-3.1, 2.95, 0.3, 0.3, 0.3], [-2.85, 2.95, 0.42, 0.42, 0.42], [0.3, 2.95, 0.42, 0.42, 0.4], [0.75, 2.95, 0.34, 0.34, 0.32]], 10, 2.2)
	for s in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, m, cowling_rings, Vector3(s * 1.0, 0, 0), mat, col)
		# the dust protector: a cone ahead of a dark annular intake
		VehicleAircraft.intake_face(k, m, Vector3(s * 1.0, 2.95, -3.08), 0.4, Vector3.FORWARD, 0.0, 0.0, 0, 0, Vector2(0.42, 0.36), mat, col)
		VehicleAircraft.turbine_exhaust(k, m, Vector3(s * 1.0, 2.95, 0.7), Vector3(s * 1.3, 2.75, 1.5), 0.3, 0.26, mat, col)
		_tube(k, m, Vector3(s * 0.62, 2.6, -1.0), Vector3(s * 0.7, 2.55, 0.2), 0.04, "gunmetal_w", null, 6)
	# the coaxial mast: the swashplate guide at its foot, the separator
	# between the two rotors
	VehicleRotors.mast(k, m, Vector3(0, 4.13, -1.4), 0.17, 0.2, 1.65, [Vector2(3.5, 0.36), Vector2(4.45, 0.3)])
	# stub wings: anhedral, three pylons a side, flare pods at the tips
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_kj_wing%d" % int(s), _mx([0.0, -2.45, 2.6, -2.15, 2.6, -1.25, 0.0, -0.95], s), _mx([0.0, -2.42, 2.6, -2.12, 2.6, -1.28, 0.0, -0.98], s), -0.07, 0.07, 0.03, 0.03),
			mat, col, Vector3(s * 0.85, 2.12, 0), Vector3(0, 0, -s * 0.1))
		VehicleAircraft.dispenser(k, m, Vector3(s * 3.5, 1.86, -1.7), Vector3(0.22, 0.26, 1.1), Vector3.ZERO, Vector3(s, 0, 0), 2, 7, "gunmetal_w", null, Vector2(0.5, 0.16))
		for j in 3:
			var px: float = s * (1.6 + j * 0.72)
			var py: float = 2.12 - (absf(px) - 0.85) * 0.1
			VehicleAircraft.hardpoint(k, m, Vector3(px, py - 0.04, -1.7), 0.7, 0.2, null, 0.26 if j < 2 else 0.0, 0.09, "gunmetal_w", 0.04)
			if j < 2:
				_rocket_pod(k, m, Vector3(px, py - 0.5, -1.85), 0.26, 2.0, "paint", Color(0.3, 0.32, 0.27), 19 if j == 0 else 7)
			else:
				_atgm_tubes(k, m, Vector3(px, py - 0.22, -1.75))
		# main gear on trailing legs
		VehicleAircraft.trailing_gear(k, m, Vector3(s * 0.8, 1.0, -3.65), Vector3(s * 0.85, 1.55, -3.4), Vector3(s * 1.38, 0.42, -3.2), Vector2(0.42, 0.28), 0.07, 0.06, "gunmetal_w", null, Vector3.ZERO, "paint", null, null, 0.0, 8, Vector2(0.697, 0.772))
		k._wheel(m, Vector3(s * 1.38, 0.42, -3.2), 0.42, 0.28)
		VmPlane.nav_light(k, m, Vector3(s * 3.62, 2.02, -1.3), Vector3(0.05, 0.06, 0.06), s)
		k._team_mark(m, team, Vector3(s * 0.33, 2.15, 4.6), Vector3(0.02, 0.2, 0.8))
	# the tail: a swept fin, the stabiliser with endplate fins, the tailwheel
	k._add(m, VehicleModels.extrude_x("heli_kj_fin", [6.6, 2.3, 8.3, 2.25, 8.75, 4.0, 8.15, 4.05], -0.08, 0.08, 0.03), mat, col, Vector3.ZERO)
	# a Mi-28's paint: stars on the boom and the fin, the bort number under
	# the gunner, soot streaking back from the exhaust deflectors
	var style := _insignia_style(team)
	_flank_paint(k, m, h, 6.25, 2.21, VehicleAircraft.insignia(style, 0.2, (col as Color).darkened(0.45) if col is Color else Color(0.2, 0.2, 0.18), col if col is Color else CSAT_SAND))
	_fin_paint(k, m, 0.08, 7.75, 3.15, VehicleAircraft.insignia(style, 0.34, (col as Color).darkened(0.45) if col is Color else Color(0.2, 0.2, 0.18), col if col is Color else CSAT_SAND))
	if team == 1:
		_flank_paint(k, m, h, -6.35, 1.36, _bort(_number(k, "35", ["123456789", "0123456789"], 15), 0.4), 0.0, 0)
	_flank_soot(k, m, h, 1.55, 2.3, 3.0, 0.42, mat, col)
	_weep(k, m, h, -2.8, 0.5, 2.4, 3, 1.0, mat, col)
	_tailplane(k, m, Vector3(0, 2.42, 7.13), 0.84, 0.7, 1.65, 0.08, mat, col, 0.09)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_kj_endp", [7.05, 1.95, 7.95, 1.95, 8.2, 2.95, 7.5, 2.95], -0.03, 0.03), mat, col, Vector3(s * 1.65, 0, 0))
	VehicleFittings.dome_light(k, m, Vector3(0, 4.07, 8.4), 0.05, _beacon(k))
	VehicleAircraft.tailwheel(k, m, Vector3(0, 1.95, 6.8), Vector3(0, 0.25, 7.16), Vector2(0.25, 0.16), 0.05)
	k._wheel(m, Vector3(0, 0.25, 7.16), 0.25, 0.16)
	VehicleFittings.antenna(k, m, Vector3(0, 2.5, 2.4), 0, Vector3(0, 0.35, 0.3), 0.014, "gunmetal_w", null, "whip")
	# the chin turret: 2A42 30 mm with its ammunition boxes either side
	k.turret = k._pivot(m, Vector3(0, 0.9, -6.75))
	VehicleAircraft.chin_turret(k, k.turret, Vector3.ZERO, Vector2(0.26, 0.3), 0.16, Vector3(0, -0.36, -0.2), Vector3(0.24, 0.24, 0.9), mat, col, 0.0, Vector3(0.2, 0.3, 0.7))
	# the cannon: its recoil sleeve out of the gun box, the barrel, the brake
	VehicleWeapons.autocannon(k, k.turret, Vector3(0, -0.36, -0.62), Vector3(0, -0.36, -2.41), Vector2(0.07, 0.4), Vector2(0.05, 0.05), Vector2(0.075, 0.18))
	k.mg_tip = k._tip(k.turret, Vector3(0, -0.36, -2.45))
	# the coaxial rotors: three blades each, the upper one turning the other way
	_rotor(k, m, Vector3(0, 3.92, -1.4), 3, 7.25, 0.5, true, 0.0, 0.016, 0.36, 1)
	var up := _rotor(k, m, Vector3(0, 4.95, -1.4), 3, 7.25, 0.5, false, PI / 3, 0.01, 0.36, 1)
	VehicleRotors.hub_cap(k, up, Vector3(0, 0.22, 0), 0.18, 0.34, 0.24, 10, mat, col)


# --- PO-30 Orca -----------------------------------------------------------------------

## PO-30 Orca, the Ka-60 Kasatka: a sleek, rounded fuselage with a pointed
## nose under a big windscreen, sliding doors both sides, the twin engines
## under a smooth roof fairing, the slim boom running into a fenestron with
## a fin over it and the tailplane ahead of it, a four-blade rotor, tricycle
## wheels. armed: a minigun on the left pylon, a rocket pod on the right.
static func _orca(k: VehicleModels, team: int, armed: bool) -> void:
	var m := k.root
	var mat := "aircraft"
	var col = CSAT_SAND
	if team == 1 and armed:
		mat = "camo_tank_rebel"
		col = null
	elif team != 1:
		col = NATO_GREY
	var h := Hull.new([
		[-5.6, 1.25, 0.06, 0.06, 0.08],
		[-5.3, 1.27, 0.45, 0.4, 0.45],
		[-4.7, 1.32, 0.8, 0.7, 0.7],
		[-3.9, 1.4, 0.95, 0.85, 0.8],
		[0.2, 1.45, 0.98, 0.85, 0.82],
		[1.3, 1.65, 0.72, 0.66, 0.55],
		[2.6, 1.85, 0.36, 0.36, 0.3],
		[6.2, 1.92, 0.22, 0.24, 0.2],
	], 14, 2.3)
	# The windscreen, chin windows, cockpit door windows. A Kasatka's two
	# pilots sit side by side under the windscreen, and from above a player
	# sees their helmets through it: the hull's roof comes down under it and
	# it is clear (an opaque one read as a navy box, nobody flying); the
	# door and chin windows stay tinted. Wrecks keep the solid hull and the
	# old glass.
	var crew := not (k.wreck or k.burnt)
	# (the sunk hull's panel joints at the solid hull's, less the one under
	# the windscreen)
	if crew:
		_hull(k, m, _sunk(h, -5.05, -3.85, 0.3, true), "heli_or_pit_body", mat, col, 0.0, [0.2])
	else:
		_hull(k, m, h, "heli_or_body", mat, col)
	if crew:
		var ws: Variant = _pane(k, m, h, "heli_or_wind", -5.12, -3.85, 0.8, 6.2, null, 0.012, 0.05, 1.0)
		_pilots(k, m, "heli_or_pit", ws, [[-4.95, 1.33, 0.18, 0.45, 0.3, 2.0, 2.0, 0.18], [-4.45, 1.36, 0.28, 0.62, 0.38, 2.0, 2.0, 0.36],
			[-3.88, 1.4, 0.3, 0.77, 0.4, 2.0, 2.0, 0.42]], -4.0)
	else:
		_patch(k, m, h, "heli_or_wind", -5.12, -3.85, 0.8, 6.2, "glass", null, 0.012, 0.05, 1.0)
	_wipers(k, m, h, -5.12, -3.85, 0.8, 6.2)
	_patch(k, m, h, "heli_or_post", -5.12, -3.85, 3.45, 3.55, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_or_chin", -5.05, -4.2, -2.5, -1.45, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_or_side", -3.75, -2.75, -0.3, 2.2, "glass", null, 0.012, 0.05)
	# the sliding doors and a window behind them
	for z in [-3.8, -2.6, -0.65]:
		_patch(k, m, h, "heli_or_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.6, 2.4, "gunmetal_w", null, 0.008)
	# the transport flies with its doors slid back over the rear windows (a
	# crew shuts one about one side in four), the dark cabin and two troop
	# seats in each doorway; the armed one keeps them shut, its pylons
	# standing where an open door would ride
	for s: float in [1.0, -1.0]:
		var rng := VehicleCargo.kit(k, m, Vector3(s, 1.4, -2.0), 74)
		if not armed and not k.wreck and not k.burnt and not (rng != null and rng.randf() < 0.25):
			# (the Ka-60's cabin is lined in a grey that shows as a shaded room
			# through the door, not a black hole; its troop seats' backs reach
			# shoulder height, in a dark grey-green webbing: tall khaki seat
			# backs read as two panels stuck on the blue-grey airframe)
			_cabin(k, m, h, "heli_or_cab", -2.58, -1.47, -2.55, 2.32, -1.7, Vector3(-0.6, -0.25, 0.8), 2, Color(0.25, 0.26, 0.23), s, Color(0.1, 0.11, 0.12))
			_patch(k, m, h, "heli_or_door", -1.45, 0.5, -2.6, 2.33, mat, col, 0.03, 0.01, s)
			_patch(k, m, h, "heli_or_dwino", -1.15, 0.15, 0.3, 1.85, "glass", null, 0.042, 0.03, s)
		else:
			_patch(k, m, h, "heli_or_dwin", -2.3, -1.0, 0.3, 1.85, "glass", null, 0.012, 0.03, s)
			_patch(k, m, h, "heli_or_rwin", -0.42, 0.15, 0.45, 1.7, "glass", null, 0.012, 0.03, s)
		_door_rail(k, m, h, -2.65, 0.6, 2.35, 2.45, 0.014, 0.03, s)
	# the roof fairing with the engine intakes and exhausts
	k._add(m, VehicleModels.loft("heli_or_roof", [-0.62, -3.6, 0.62, -3.6, 0.85, -2.6, 0.85, 1.0, 0.5, 2.1, -0.5, 2.1, -0.85, 1.0, -0.85, -2.6],
		[-0.3, -3.0, 0.3, -3.0, 0.56, -2.2, 0.56, 0.7, 0.28, 1.6, -0.28, 1.6, -0.56, 0.7, -0.56, -2.2], 2.08, 2.86, 0.08), mat, col, Vector3.ZERO)
	_skirt(k, m, h, "heli_or_rskirt", [-0.62, -3.6, 0.62, -3.6, 0.85, -2.6, 0.85, 1.0, 0.5, 2.1, -0.5, 2.1, -0.85, 1.0, -0.85, -2.6], 2.08, 0.28, mat, col)
	_cowl_top(k, m, [-0.3, -3.0, 0.3, -3.0, 0.56, -2.2, 0.56, 0.7, 0.28, 1.6, -0.28, 1.6, -0.56, 0.7, -0.56, -2.2], 2.86, 0.08, [-2.1, -1.5, -0.45, 0.6], _patchwork(k, 5, 1), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_or_intk", [-0.17, 0.0, 0.17, 0.0, 0.17, 0.7, -0.17, 0.7], [-0.13, 0.08, 0.13, 0.08, 0.13, 0.7, -0.13, 0.7], 0.0, 0.32), mat, col, Vector3(s * 0.72, 2.4, -2.5))
		# the engine's intake: a dark mouth with a rolled lip in the housing's
		# raked face, where a black plate stood off it
		VehicleAircraft.intake_face(k, m, Vector3(s * 0.72, 2.56, -2.468), 0.115, Vector3(0, 0.24, -0.97), 0.04)
		VehicleAircraft.turbine_exhaust(k, m, Vector3(s * 0.5, 2.48, 1.2), Vector3(s * 0.85, 2.45, 1.6), 0.15, 0.13)
		VmPlane.nav_light(k, m, Vector3(s * 0.96, 1.3, -3.6), Vector3(0.05, 0.06, 0.06), s)
		k._team_mark(m, team, Vector3(s * 0.27, 1.9, 4.6), Vector3(0.02, 0.18, 0.7))
	VehicleRotors.mast(k, m, Vector3(0, 3.06, -1.0), 0.13, 0.17, 0.48, [Vector2(2.95, 0.3)])
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.28, 1.45, -5.2), Vector3(s * 0.28, 1.43, -5.75), 0.015, "steel", null)
	VehicleFittings.dome_light(k, m, Vector3(0, 2.88, 0.9), 0.06, _beacon(k))
	VehicleFittings.antenna(k, m, Vector3(0, 2.15, 2.6), 0, Vector3(0, 0.3, 0.25), 0.012, "gunmetal_w", null, "whip")
	# the fenestron: shroud with its open duct, the fin, the tailplane
	_ducted_fin(k, m, "heli_or_duct", [6.05, 1.45, 6.4, 1.15, 7.55, 1.15, 7.9, 1.5, 7.9, 2.3, 7.55, 2.65, 6.4, 2.65, 6.05, 2.35],
		Vector2(6.98, 1.9), 0.58, -0.17, 0.17, mat, col, 16)
	_fan(k, m, Vector3(0, 1.9, 6.98), 11, 0.56, 0.11)
	for a in [0.6, 2.4, 4.2]:
		k._box(m, Vector3(0.03, 0.52, 0.07), Vector3(-0.09, 1.9 + sin(a) * 0.3, 6.98 + cos(a) * 0.3), "gunmetal_w", null, Vector3(-a + PI / 2, 0, 0), false)
	k._add(m, VehicleModels.extrude_x("heli_or_fin", [6.7, 2.6, 7.85, 2.6, 8.05, 3.6, 7.45, 3.62], -0.07, 0.07, 0.025), mat, col, Vector3.ZERO)
	# a Ka-60's paint: stars on the fin, the bort number under the cockpit,
	# the engines' soot streaking back along the boom
	var style := _insignia_style(team)
	_fin_paint(k, m, 0.07, 7.48, 3.1, VehicleAircraft.insignia(style, 0.26, (col as Color).darkened(0.45) if col is Color else Color(0.2, 0.2, 0.18), col if col is Color else CSAT_SAND))
	if team == 1:
		_flank_paint(k, m, h, -3.3, 1.02, _bort(_number(k, "07", ["0123456789", "0123456789"], 16), 0.3), 0.0, 0)
	_flank_soot(k, m, h, 1.7, 2.0, 2.2, 0.32, mat, col)
	_weep(k, m, h, -3.2, 0.5, 1.98, 3, 0.9, mat, col)
	_tailplane(k, m, Vector3(0, 1.98, 5.16), 0.58, 0.5, 1.25, 0.065, mat, col, 0.06)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_or_endp", [5.15, 1.75, 5.72, 1.75, 5.85, 2.3, 5.42, 2.3], -0.02, 0.02), mat, col, Vector3(s * 1.25, 0, 0))
	# tricycle wheels: the nosewheel, mains in their fairings
	_gear(k, m, Vector3(0, 0.7, -4.15), Vector3(0, 0.26, -4.3), 0.26, 0.16)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_or_spon%d" % int(s), _mx([0.75, -0.3, 1.15, -0.1, 1.15, 1.0, 0.75, 1.2], s), _mx([0.75, -0.1, 1.05, 0.0, 1.05, 0.85, 0.75, 1.0], s), 0.62, 1.08, 0.04), mat, col, Vector3.ZERO)
		_gear(k, m, Vector3(s * 1.0, 0.7, 0.4), Vector3(s * 1.15, 0.3, 0.45), 0.3, 0.18)
		VehicleFrames.step(k, m, Vector3(s * 1.0, 0.55, -2.0), Vector2(0.14, 0.3))
	if armed:
		# side pylons: a minigun on the left, a rocket pod on the right
		for s in [-1.0, 1.0]:
			k._add(m, VehicleModels.loft("heli_or_pyl%d" % int(s), _mx([0.0, -0.45, 0.85, -0.3, 0.85, 0.2, 0.0, 0.35], s), _mx([0.0, -0.4, 0.85, -0.27, 0.85, 0.17, 0.0, 0.3], s), 0.0, 0.1),
				mat, col, Vector3(s * 0.8, 1.08, 0.0))
			VehicleAircraft.hardpoint(k, m, Vector3(s * 1.5, 1.08, -0.05), 0.62, 0.16, null, 0.2 if s > 0.0 else 0.16, 0.08, "gunmetal_w", 0.04)
		_rocket_pod(k, m, Vector3(1.5, 0.74, -0.15), 0.2, 1.6, "paint", Color(0.3, 0.32, 0.27), 19)
		k.turret = k._pivot(m, Vector3(-1.5, 0.82, -0.1))
		# the minigun pod: its body (the gun's drive and 1,500 rounds inside),
		# the nose fairing tapering round the barrels, which stand out of it;
		# the band where the nose comes off for loading, the ejection port
		# underneath that throws the cases and links clear, the tail cone
		var pod := Color(0.3, 0.32, 0.27)
		k._cyl(k.turret, 0.16, 0.16, 0.9, Vector3(0, 0, 0.25), Vector3(PI / 2, 0, 0), "paint", pod, 12)
		_tube(k, k.turret, Vector3(0, 0, -0.2), Vector3(0, 0, -0.42), 0.16, "paint", pod, 12, 0.075)
		k._cyl(k.turret, 0.072, 0.072, 0.012, Vector3(0, 0, -0.426), Vector3(PI / 2, 0, 0), "metal_dark", null, 12, false)
		k._cyl(k.turret, 0.163, 0.163, 0.02, Vector3(0, 0, -0.16), Vector3(PI / 2, 0, 0), "metal_dark", null, 12, false)
		k._box(k.turret, Vector3(0.06, 0.012, 0.2), Vector3(0, -0.156, 0.08), "plain_dark", Color(0.04, 0.04, 0.04), Vector3.ZERO, false)
		k._add(k.turret, Res.sphere(0.16, 12), "paint", pod, Vector3(0, 0, 0.7), Vector3.ZERO, Vector3(1, 1, 0.8))
		k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3(0, 0, -0.2), 0.6))
	# the rotor: four blades with swept tips under a domed hub cap
	_rotor(k, m, Vector3(0, 3.36, -1.0), 4, 6.75, 0.4, true, PI / 4, 0.018, 0.32, 1)
	VehicleRotors.hub_cap(k, k.rotor, Vector3(0, 0.2, 0), 0.2, 0.36, 0.2, 10, mat, col)


# --- Mi-290 Taru ----------------------------------------------------------------------

## Mi-290 Taru: a CH-54 Tarhe's skeletal sky-crane - a glazed cab hung off
## the front of a narrow spine, four long legs splayed out to the wheels -
## under a Ka-226's coaxial rotors (no tail rotor; a twin-finned tailplane),
## two engines on the spine, the transport pod slung underneath on its
## hooks.
static func _taru(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank_rebel"
	var col = null
	if team != 1:
		mat = "aircraft"
		col = NATO_GREY
	# the spine
	var sp := Hull.new([
		[-5.7, 3.45, 0.6, 0.55, 0.58],
		[-4.2, 3.45, 0.66, 0.62, 0.6],
		[1.6, 3.45, 0.66, 0.62, 0.6],
		[4.0, 3.5, 0.5, 0.48, 0.42],
		[7.7, 3.6, 0.28, 0.3, 0.25],
		[8.5, 3.62, 0.2, 0.22, 0.18],
	], 8, 3.0, PI / 8)
	_hull(k, m, sp, "heli_ta_spine", mat, col)
	_patch(k, m, sp, "heli_ta_keel", -4.0, 4.5, 5.35, 5.65, "gunmetal_w", null, 0.012, 0.03, 1.0)
	# the cab, glazed all round its nose
	var cab := Hull.new([
		[-8.3, 3.0, 0.1, 0.1, 0.1],
		[-8.05, 3.0, 0.68, 0.6, 0.6],
		[-7.45, 3.05, 0.98, 0.86, 0.84],
		[-6.2, 3.12, 1.04, 0.9, 0.88],
		[-5.3, 3.2, 0.95, 0.82, 0.76],
		[-4.7, 3.3, 0.7, 0.68, 0.5],
	], 14, 2.2)
	# (its two pilots sit side by side up in the glazed nose, their helmets
	# under its top: the cab's roof comes down under the glazing and it is
	# clear, where an opaque sheet read as a navy box with nobody flying; the
	# side and chin windows stay tinted; wrecks as they were)
	var crew := not (k.wreck or k.burnt)
	_hull(k, m, _sunk(cab, -8.1, -6.55, 0.3, true) if crew else cab, "heli_ta_cab" + ("_pit" if crew else ""), mat, col)
	if crew:
		var ws: Variant = _pane(k, m, cab, "heli_ta_wind", -8.3, -6.55, -0.7, 7.7, null, 0.012, 0.05, 1.0)
		_pilots(k, m, "heli_ta_pit", ws, [[-7.95, 3.05, 0.22, 0.5, 0.4, 2.0, 2.0, 0.25], [-7.4, 3.08, 0.32, 0.7, 0.45, 2.0, 2.0, 0.45],
			[-6.6, 3.12, 0.34, 0.78, 0.45, 2.0, 2.0, 0.5]], -6.9)
	else:
		_patch(k, m, cab, "heli_ta_wind", -8.3, -6.55, -0.7, 7.7, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, cab, "heli_ta_chin", -8.2, -6.6, -2.9, -1.3, "glass", null, 0.012, 0.05)
	for t in [1.7, 3.5, 5.3]:
		_patch(k, m, cab, "heli_ta_post%d" % int(t * 10), -8.25, -6.55, t - 0.07, t + 0.07, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, cab, "heli_ta_cpost", -8.2, -6.6, -2.15, -2.05, mat, col, 0.022, 0.02)
	_patch(k, m, cab, "heli_ta_bow", -6.65, -6.5, -3.2, 10.2, mat, col, 0.026, 0.03, 1.0)
	_patch(k, m, cab, "heli_ta_side", -6.3, -5.35, -0.6, 2.4, "glass", null, 0.012, 0.05)
	_patch(k, m, cab, "heli_ta_dseam", -6.42, -6.38, -2.4, 2.6, "gunmetal_w", null, 0.01)
	k._box(m, Vector3(0.9, 0.5, 0.04), Vector3(0, 2.75, -4.85), "glass", null, Vector3(0.5, 0, 0), false)
	for s in [-1.0, 1.0]:
		VehicleAircraft.pitot(k, m, Vector3(s * 0.35, 3.0, -8.1), Vector3(s * 0.35, 2.98, -8.7), 0.018, "steel", null)
		VehicleFrames.step(k, m, Vector3(s * 0.95, 2.28, -5.8), Vector2(0.14, 0.3))
	# the engines and the gearbox fairing on the spine
	k._add(m, VehicleModels.loft("heli_ta_top", [-0.55, -4.4, 0.55, -4.4, 0.62, -3.6, 0.62, 0.8, 0.4, 1.4, -0.4, 1.4, -0.62, 0.8, -0.62, -3.6],
		[-0.3, -3.9, 0.3, -3.9, 0.4, -3.2, 0.4, 0.4, 0.22, 0.95, -0.22, 0.95, -0.4, 0.4, -0.4, -3.2], 3.95, 4.62, 0.07), mat, col, Vector3.ZERO)
	_skirt(k, m, sp, "heli_ta_rskirt", [-0.55, -4.4, 0.55, -4.4, 0.62, -3.6, 0.62, 0.8, 0.4, 1.4, -0.4, 1.4, -0.62, 0.8, -0.62, -3.6], 3.95, 0.22, mat, col)
	_cowl_top(k, m, [-0.3, -3.9, 0.3, -3.9, 0.4, -3.2, 0.4, 0.4, 0.22, 0.95, -0.22, 0.95, -0.4, 0.4, -0.4, -3.2], 4.62, 0.07, [-3.0, -1.6, -0.4], _patchwork(k, 4, 1), mat, col)
	var eng := Hull.new([[-3.7, 4.36, 0.26, 0.26, 0.26], [-3.45, 4.36, 0.36, 0.36, 0.36], [-0.7, 4.36, 0.36, 0.36, 0.36], [-0.2, 4.36, 0.27, 0.27, 0.27]], 10, 2.2)
	for s in [-1.0, 1.0]:
		var cowling_rings := []
		for station: Array in eng.st:
			cowling_rings.append(eng.ring(float(station[0])))
		VehicleAircraft.cowling(k, m, cowling_rings, Vector3(s * 0.66, 0, 0), mat, col)
		VehicleAircraft.intake_face(k, m, Vector3(s * 0.66, 4.36, -3.71), 0.24, Vector3.FORWARD, 0.1)
		VehicleAircraft.turbine_exhaust(k, m, Vector3(s * 0.66, 4.36, -0.25), Vector3(s * 0.95, 4.42, 0.25), 0.2, 0.17)
		k._team_mark(m, team, Vector3(s * 0.4, 3.62, 5.6), Vector3(0.02, 0.24, 0.9))
		# the engines' soot streaking back along the spine's roof
		VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(s * 0.42, 4.1, 1.45), Vector3.UP, Vector3.BACK, _roof_skin(sp)), VehicleAircraft.soot(2.6, 0.34, mat, col), mat)
	# stars on the spine's flanks, the bort number on the cab's
	var style := _insignia_style(team)
	_flank_paint(k, m, sp, 3.2, 3.47, VehicleAircraft.insignia(style, 0.3, (col as Color).darkened(0.45) if col is Color else Color(0.2, 0.2, 0.18), col if col is Color else CSAT_SAND))
	if team == 1:
		_flank_paint(k, m, cab, -5.8, 2.66, _bort(_number(k, "21", ["123456789", "0123456789"], 17), 0.34), 0.0, 0)
	VehicleRotors.mast(k, m, Vector3(0, 5.3, -1.0), 0.17, 0.2, 1.5, [Vector2(4.66, 0.34)])
	VehicleFittings.dome_light(k, m, Vector3(0, 4.08, 2.6), 0.07, _beacon(k))
	VehicleFittings.antenna(k, m, Vector3(0, 4.0, 3.4), 0, Vector3(0, 0.35, 0.3), 0.012, "gunmetal_w", null, "whip")
	# the tailplane with its twin fins, a ventral fin
	_tailplane(k, m, Vector3(0, 3.62, 7.58), 0.84, 0.74, 1.55, 0.075, mat, col, 0.06)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_ta_fin", [7.5, 3.15, 8.4, 3.15, 8.62, 4.35, 7.95, 4.35], -0.035, 0.035), mat, col, Vector3(s * 1.55, 0, 0))
	k._add(m, VehicleModels.extrude_x("heli_ta_vent", [7.6, 3.45, 8.45, 3.45, 8.6, 2.95, 8.1, 2.9], -0.04, 0.04), mat, col, Vector3.ZERO)
	# the legs: long oleo struts splayed out from the spine, braced
	for s in [-1.0, 1.0]:
		for lz in [[-4.25, -4.55, 2.45], [3.7, 4.3, 2.6]]:
			var top := Vector3(s * 0.55, 3.05, float(lz[0]))
			var axle := Vector3(s * float(lz[2]), 0.42, float(lz[1]))
			# the strut runs down to the axle's fitting over the wheel; one
			# brace meets its barrel, the other its gland nut
			var foot := axle + Vector3(0, 0.25, 0)
			VehicleAircraft.gear_leg(k, m, top, foot, 0.085, Color(0.25, 0.27, 0.24))
			_tube(k, m, Vector3(s * 0.3, 2.9, float(lz[0]) + (0.9 if float(lz[0]) < 0.0 else -0.9)), top.lerp(foot, 0.45), 0.05, "gunmetal_w", null, 6)
			_tube(k, m, Vector3(s * 0.45, 2.88, float(lz[0])), top.lerp(foot, 0.62), 0.04, "gunmetal_w", null, 6)
			k._box(m, Vector3(0.1, 0.12, 0.38), axle + Vector3(-s * 0.05, 0.28, 0), "gunmetal_w")
			k._wheel(m, axle, 0.42, 0.3)
	# the transport pod on its four hooks
	var pod := Hull.new([
		[-3.45, 1.6, 1.0, 0.8, 0.8],
		[-3.2, 1.6, 1.25, 1.0, 1.0],
		[2.95, 1.6, 1.25, 1.0, 1.0],
		[3.2, 1.6, 1.05, 0.85, 0.85],
	], 8, 6.0, PI / 8)
	_hull(k, m, pod, "heli_ta_pod", mat, col)
	# the pod's roof, the face the battle camera sees: riveted sheet panels on
	# the frames under it (a joint over every frame, seams down either side
	# of the lifting beam), a refitted panel or two in another shade, and
	# the ventilation louvres a cabin carrying people needs
	var roof_y := 2.575
	var roof: Array = []
	var bounds: Array = [-3.1]
	for z: float in [-2.0, -0.8, 0.4, 1.6]:
		roof.append([Vector2(z, -0.86), Vector2(z, 0.86)])
		bounds.append(z)
	bounds.append(2.85)
	for x: float in [-0.86, -0.56, 0.56, 0.86]:
		roof.append([Vector2(-3.1, x), Vector2(2.85, x)])
	roof.append([Vector2(-3.1, -0.86), Vector2(-3.1, 0.86)])
	roof.append([Vector2(2.85, -0.86), Vector2(2.85, 0.86)])
	var refit := PackedVector2Array()
	for i: int in _patchwork(k, 5, 23):
		var lane: float = [0.56, -0.86][i % 2]
		refit.append_array(VehicleAircraft._fill(PackedVector2Array([Vector2(bounds[i], lane), Vector2(bounds[i + 1], lane), Vector2(bounds[i + 1], lane + 0.3), Vector2(bounds[i], lane + 0.3)])))
	var pbase: Color = col if col is Color else Mats._preset(mat).get("col_a", Color(0.5, 0.5, 0.5))
	var pod_layers: Array = []
	if refit.size() >= 3:
		pod_layers.append([refit, pbase.darkened(0.16), mat])
	pod_layers.append([VehicleAircraft.lines(roof, 0.02), pbase.darkened(0.5), mat])
	VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(0, roof_y, 0), Vector3.UP, Vector3.BACK), pod_layers, mat)
	for g: Vector2 in [Vector2(0.7, -1.4), Vector2(-0.7, 1.0)]:
		VehicleFittings.grille(k, m, Vector3(g.x, roof_y + 0.03, g.y), Vector2(0.22, 0.42), Vector3(-PI / 2, 0, 0), mat, col, 5)
	for i in 4:
		var zc := -2.4 + i * 1.6
		_patch(k, m, pod, "heli_ta_pw%d" % i, zc - 0.25, zc + 0.25, -0.33, -0.05, "glass", null, 0.012)
	for z in [-0.6, 0.45]:
		_patch(k, m, pod, "heli_ta_pdoor%d" % int(z * 10 + 10), z - 0.014, z + 0.014, -0.95, 0.75, "gunmetal_w", null, 0.008, 0.03, -1.0)
	_patch(k, m, pod, "heli_ta_pdwin", -0.4, 0.25, -0.35, -0.08, "glass", null, 0.012, 0.03, -1.0)
	# the rear doors: their frame, the leaf, the split between the two halves
	k._box(m, Vector3(2.2, 1.7, 0.03), Vector3(0, 1.6, 3.21), "gunmetal_w", null, Vector3.ZERO, false)
	VehicleDoors.leaf(k, m, Vector3(2.1, 1.6, 0.04), Vector3(0, 1.6, 3.22), mat, col)
	k._box(m, Vector3(0.03, 1.6, 0.05), Vector3(0, 1.6, 3.25), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.05, 0.4), Vector3(s * 1.27, 0.95, -0.1), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.24, 0.04, 0.5), Vector3(s * 1.3, 0.62, -0.1), "gunmetal_w")
		for z in [-2.6, 2.4]:
			_tube(k, m, Vector3(s * 0.4, 2.6, z), Vector3(s * 0.3, 2.95, z), 0.05, "gunmetal_w", null, 6)
			k._box(m, Vector3(0.3, 0.08, 0.3), Vector3(s * 0.4, 2.62, z), "gunmetal_w")
	k.sling_eye = Vector3(0, 2.62, -0.1)
	k._box(m, Vector3(0.9, 0.05, 6.0), k.sling_eye, "gunmetal_w")
	# the coaxial rotors: three blades each, turning against each other
	_rotor(k, m, Vector3(0, 4.98, -1.0), 3, 7.5, 0.48, true, 0.0, 0.02, 0.36, 0)
	var up := _rotor(k, m, Vector3(0, 6.08, -1.0), 3, 7.5, 0.48, false, PI / 3, 0.012, 0.36, 0)
	VehicleRotors.hub_cap(k, up, Vector3(0, 0.2, 0), 0.16, 0.32, 0.22, 10, mat, col)


# --- MQ-12 Falcon ---------------------------------------------------------------------

## MQ-12 Falcon, the MQ-8 Fire Scout: an unmanned Schweizer - a windowless
## teardrop of a pod on skids, the sensor ball under its nose, the engine
## fairing and exhaust on its back, a thin boom with fins, a two-blade tail
## rotor, the four-blade rotor, stub wings with four small missiles.
static func _falcon(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, NATO_GREY)
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	# (the Fire Scout's nose is a smooth blunt dome over its avionics bay: a
	# quarter ellipse in six stations, where three made a faceted golf ball)
	var h := Hull.new([
		[-2.9, 1.26, 0.068, 0.065, 0.062],
		[-2.875, 1.262, 0.164, 0.155, 0.149],
		[-2.83, 1.265, 0.267, 0.252, 0.243],
		[-2.75, 1.275, 0.377, 0.356, 0.343],
		[-2.63, 1.29, 0.476, 0.45, 0.433],
		[-2.45, 1.31, 0.55, 0.52, 0.5],
		[-1.6, 1.36, 0.64, 0.62, 0.6],
		[-0.6, 1.38, 0.65, 0.64, 0.6],
		[0.3, 1.42, 0.58, 0.6, 0.52],
		[1.0, 1.5, 0.38, 0.42, 0.32],
		[1.5, 1.58, 0.18, 0.2, 0.16],
	], 14, 2.1)
	if k.wreck:
		# (a wreck keeps the old nose: wrecks are drawn as they were)
		h = Hull.new([[-2.9, 1.26, 0.16, 0.15, 0.15], [-2.78, 1.27, 0.4, 0.37, 0.36]] + h.st.slice(5), 14, 2.1)
	_hull(k, m, h, "heli_fa_body" if k.wreck else "heli_fa_round_body", mat, col, 0.0, [-2.45, -0.6])
	# panel seams and access hatches (no windows: nobody aboard)
	for z in [-2.2, -1.05, 0.25]:
		_patch(k, m, h, "heli_fa_seam%d" % int(z * 100 + 300), z - 0.012, z + 0.012, -3.4, 10.4, "gunmetal_w", null, 0.006, 0.03, 1.0)
	_patch(k, m, h, "heli_fa_hatch", -0.9, -0.2, -0.6, 1.4, mat, (col as Color).darkened(0.08) if col is Color else null, 0.008)
	_patch(k, m, h, "heli_fa_nose" if k.wreck else "heli_fa_rnose", -2.9, -2.45, -3.4, 10.4, mat, (col as Color).darkened(0.12) if col is Color else null, 0.006, 0.03, 1.0)
	# the engine fairing on the back, its intake and exhaust; the mast
	k._add(m, VehicleModels.loft("heli_fa_eng", [-0.32, -1.2, 0.32, -1.2, 0.36, 0.7, 0.2, 1.15, -0.2, 1.15, -0.36, 0.7],
		[-0.18, -0.9, 0.18, -0.9, 0.22, 0.5, 0.1, 0.9, -0.1, 0.9, -0.22, 0.5], 1.9, 2.3, 0.04), mat, col, Vector3.ZERO)
	# the engine bay's access panels on top of the fairing
	_cowl_top(k, m, [-0.18, -0.9, 0.18, -0.9, 0.22, 0.5, 0.1, 0.9, -0.1, 0.9, -0.22, 0.5], 2.3, 0.04, [-0.2, 0.45], _patchwork(k, 3, 3), mat, col)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.12, 0.3), Vector3(s * 0.27, 2.1, -0.15), "plain", dark, Vector3(0, 0, s * 0.3), false)
	VehicleAircraft.turbine_exhaust(k, m, Vector3(0, 2.12, 0.85), Vector3(0, 2.2, 1.25), 0.09, 0.08)
	# its soot laid back along the top of the boom behind the outlet
	VehicleAircraft.paint(k, m, VehicleAircraft.face(Vector3(0, 1.8, 1.38), Vector3.UP, Vector3.BACK, _tube_skin(Vector3(0, 1.58, 1.3), Vector3(0, 1.7, 4.35), 0.13, 0.07)), VehicleAircraft.soot(1.9, 0.2, mat, col), mat)
	VehicleRotors.mast(k, m, Vector3(0, 2.42, -0.5), 0.08, 0.1, 0.36, [Vector2(2.35, 0.17)])
	# the boom, fins, stabiliser, the tail rotor on the left
	_tube(k, m, Vector3(0, 1.58, 1.3), Vector3(0, 1.7, 4.35), 0.13, mat, col, 10, 0.07)
	k._add(m, Res.sphere(0.07, 8), mat, col, Vector3(0, 1.7, 4.35))
	k._add(m, VehicleModels.extrude_x("heli_fa_fin", [3.8, 1.72, 4.3, 1.72, 4.48, 2.35, 4.2, 2.36], -0.025, 0.025), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_fa_vent", [3.9, 1.66, 4.3, 1.66, 4.45, 1.2, 4.28, 1.18], -0.025, 0.025), mat, col, Vector3.ZERO)
	_tailplane(k, m, Vector3(0, 1.7, 3.39), 0.32, 0.22, 0.56, 0.04, mat, col, 0.07, true)
	_tail_rotor(k, m, Vector3(-0.08, 1.72, 4.3), 2, 0.62, 0.09, -1.0)
	# the sensor ball hanging on its neck under the nose, antennas, the
	# datalink dome
	VehicleEquipment.sensor(k, m, Vector3(0, 0.66, -2.15), Vector3.ONE * 0.18 * 2.0, "paint", Color(0.28, 0.29, 0.3), "ball", Vector3(0.06, 0.06, 0.23))
	k._add(m, Res.dome(0.16, 10), mat, col, Vector3(0, 1.98, -1.6))
	k._box(m, Vector3(0.025, 0.18, 0.18), Vector3(0, 0.66, 0.0), "gunmetal_w")
	VehicleFittings.antenna(k, m, Vector3(0, 1.82, 2.4), 0, Vector3(0, 0.23, 0.15), 0.01, "gunmetal_w", null, "whip")
	VehicleFittings.dome_light(k, m, Vector3(0, 2.38, 4.22), 0.035, _beacon(k))
	# skids
	_skids(k, m, 0.82, -1.55, 0.85, [-1.1, 0.4], 0.42, 0.8, 0.035, "gunmetal_w")
	# stub wings with two pylons a side, a small missile on each
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.75, 0.05, 0.42), Vector3(s * 0.95, 1.12, -0.7), mat, col, Vector3(0, 0, -s * 0.05))
		for j in 2:
			var px: float = s * (0.82 + j * 0.36)
			VehicleAircraft.hardpoint(k, m, Vector3(px, 1.1, -0.7), 0.3, 0.1, null, 0.055, 0.04, "gunmetal_w", 0.0)
			_missile(k, m, Vector3(px, 0.94, -0.75), 0.055, 1.1, Color(0.32, 0.34, 0.29))
		k._team_mark(m, team, Vector3(s * 0.11, 1.62, 2.5), Vector3(0.02, 0.1, 0.5))
	# the national insignia on the flanks aft of the hatch, low-visibility
	_flank_paint(k, m, h, 0.15, 1.5, VehicleAircraft.insignia(_insignia_style(team), 0.16, (col as Color).darkened(0.45) if col is Color else Color(0.2, 0.2, 0.18), col if col is Color else CSAT_SAND), 0.0, 0)
	# the rotor: four blades
	_rotor(k, m, Vector3(0, 2.64, -0.5), 4, 4.2, 0.2, true, PI / 4, 0.012, 0.18, 0)


# --- rotary drones --------------------------------------------------------------------

## A drone's propeller at pos (radius r, nb blades) on k.rotors: the spinner
## stays, the blades sit in "Blades" (shown slow), a "Blur" disc (fast).
static func _prop(k: VehicleModels, p: Node3D, pos: Vector3, r: float, nb := 2, phase := 0.0, col := Color(0.11, 0.11, 0.11)) -> Node3D:
	var rp := k._pivot(p, pos)
	var bl := k._pivot(rp, Vector3.ZERO)
	bl.name = "Blades"
	k._cyl(rp, r * 0.1, r * 0.14, r * 0.14, Vector3(0, r * 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	# Moulded composite blades, as a small multirotor's are: steep and narrow
	# at the hub, widest a third of the way out, twisting flatter to a slim
	# rounded-off tip (flat boards read as planks). One cached aerofoil per
	# prop size, a coarse section at this scale, turned round the hub for
	# each blade; it pulls up the rotor's y. (Wrecks keep the old blades.)
	var prof := [0.0, r * 0.13, 0.35, r * 0.21, 0.75, r * 0.16, 1.0, r * 0.07]
	var foil := [0.0, 0.0, 0.3, 1.0, 1.0, 0.12]
	var blade := VehiclePropellers.blade("", Vector3(0, -1, 0), r * 0.1, r, prof, 0.62, 0.2, 0.12, 1.0, foil)
	for i in nb:
		if k.wreck:
			var bs := Basis.from_euler(Vector3(0, phase + TAU * float(i) / float(nb), 0))
			_rbox(k, bl, bs, Vector3(r * 0.17, r * 0.045, r * 0.55), Vector3(0, r * 0.07, r * 0.36), "plain", col, Vector3(0, 0, 0.3))
			_rbox(k, bl, bs, Vector3(r * 0.13, r * 0.04, r * 0.36), Vector3(r * 0.015, r * 0.07, r * 0.8), "plain", col, Vector3(0, 0.08, 0.22))
			continue
		k._add(bl, blade, "plain", col, Vector3(0, r * 0.07, 0), Vector3(-PI / 2, phase + TAU * float(i) / float(nb), 0))
	if not k.burnt:
		var blur := MeshInstance3D.new()
		blur.name = "Blur"
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 2.0
		blur.mesh = disc
		# (a propeller's disc, in the blades' own plastic: broad blades on a
		# small circle fill more of it than a rotor's, and one shared material
		# per count and colour needs no per-object values)
		blur.material_override = VehiclePropellers.disc_material(nb, 0.12, col)
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, r * 0.08, 0)
		blur.visible = false
		rp.add_child(blur)
	k.rotors.append(rp)
	return rp


## AR-2 Darter: a palm-sized quadcopter, 0.9 m across - a small fuselage on
## an X of arms, each rotor inside its guard ring, a camera on a gimbal under
## the nose, two little skids.
static func _darter(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "aircraft"
	var col: Color = Color(0.36, 0.37, 0.32) if team != 1 else CSAT_SAND
	var dark := Color(0.08, 0.08, 0.08)
	var h := Hull.new([
		[-0.19, 0.2, 0.05, 0.025, 0.03],
		[-0.13, 0.2, 0.1, 0.055, 0.05],
		[0.1, 0.205, 0.11, 0.06, 0.05],
		[0.18, 0.21, 0.07, 0.04, 0.035],
	], 10, 2.4)
	_hull(k, m, h, "heli_da_body", mat, col)
	_patch(k, m, h, "heli_da_stripe", -0.19, -0.13, 1.2, 3.8, "plain", dark, 0.003, 0.01, 1.0)
	k._box(m, Vector3(0.1, 0.028, 0.15), Vector3(0, 0.27, 0.03), "plain", Color(0.15, 0.15, 0.15))
	_tube(k, m, Vector3(0.03, 0.28, 0.12), Vector3(0.03, 0.36, 0.15), 0.004, "gunmetal_w", null, 4)
	# the X of arms, a motor and guard ring at each end
	var order := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var d: Vector2 = order[i]
		var mp := Vector3(d.x * 0.29, 0.22, d.y * 0.29)
		var ab := Vector3(d.x * 0.06, 0.215, d.y * 0.06)
		_tube(k, m, ab, mp, 0.016, mat, col, 6)
		k._box(m, Vector3(0.05, 0.02, 0.24), (ab + mp) * 0.5 + Vector3(0, -0.012, 0), mat, col, Vector3(0, atan2(d.x, d.y), 0))
		k._cyl(m, 0.03, 0.03, 0.05, mp + Vector3(0, 0.015, 0), Vector3.ZERO, "gunmetal_w", null, 10)
		k._add(m, Res.torus(0.17, 0.19), mat, col, mp + Vector3(0, 0.05, 0))
		for j in 3:
			var a := atan2(d.y, d.x) + PI + (float(j) - 1.0) * 0.9
			var e := mp + Vector3(cos(a) * 0.17, 0.045, sin(a) * 0.17)
			_tube(k, m, mp + Vector3(0, 0.02, 0), e, 0.006, mat, col, 4)
		# lights under the motors: red on the left and green on the right up
		# front, white aft
		if d.y > 0.0:
			VehicleFittings.marker(k, m, mp + Vector3(0, -0.018, 0), Vector3(0.02, 0.012, 0.02), 0.0, Color(0.8, 0.8, 0.75))
		else:
			VehicleFittings.nav_light(k, m, mp + Vector3(0, -0.018, 0), Vector3(0.02, 0.012, 0.02), d.x)
		_prop(k, m, mp + Vector3(0, 0.05, 0), 0.155, 2, float(i) * 0.7)
	# the camera on its gimbal under the nose
	k._box(m, Vector3(0.05, 0.03, 0.04), Vector3(0, 0.15, -0.12), "gunmetal_w")
	k._add(m, Res.sphere(0.036, 10), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.12, -0.13))
	k._cyl(m, 0.018, 0.018, 0.01, Vector3(0, 0.12, -0.165), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	# skids
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.06, 0.16, -0.06), Vector3(s * 0.12, 0.012, -0.08), 0.006, "gunmetal_w", null, 4)
		_tube(k, m, Vector3(s * 0.06, 0.16, 0.08), Vector3(s * 0.12, 0.012, 0.1), 0.006, "gunmetal_w", null, 4)
		VehicleAircraft.skid_runner(k, m, [Vector3(s * 0.12, 0.012, -0.16), Vector3(s * 0.12, 0.012, 0.16)], [], 0.008, "rubber")


## A hexacopter, about 1.5 m across: a round hub with a dome over the
## electronics, six carbon arms with a motor and two-blade prop at each end,
## two skids. demining: white, with a rack of demolition charges and a
## ground-scanning sensor under it; else (utility) a cargo box slung under.
static func _hexa(k: VehicleModels, team: int, demining: bool) -> void:
	var m := k.root
	var mat := "aircraft"
	var col: Color = Color(0.26, 0.27, 0.27) if team != 1 else CSAT_SAND
	if demining:
		col = Color(0.8, 0.8, 0.76)
	var dark := Color(0.08, 0.08, 0.08)
	var carbon := Color(0.12, 0.12, 0.12)
	# the hub: a hexagonal frame, the dome, the battery under it
	k._cyl(m, 0.2, 0.2, 0.025, Vector3(0, 0.3, 0), Vector3.ZERO, "plain", carbon, 6)
	k._cyl(m, 0.2, 0.2, 0.025, Vector3(0, 0.38, 0), Vector3.ZERO, "plain", carbon, 6)
	k._cyl(m, 0.15, 0.17, 0.06, Vector3(0, 0.34, 0), Vector3.ZERO, mat, col, 12)
	k._add(m, Res.dome(0.16, 14), mat, col, Vector3(0, 0.39, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	k._box(m, Vector3(0.14, 0.06, 0.24), Vector3(0, 0.26, 0), "plain", Color(0.18, 0.18, 0.18))
	_tube(k, m, Vector3(0, 0.49, 0.03), Vector3(0, 0.58, 0.03), 0.006, "gunmetal_w", null, 4)
	k._cyl(m, 0.04, 0.04, 0.015, Vector3(0, 0.585, 0.03), Vector3.ZERO, "plain", Color(0.2, 0.2, 0.2), 10)
	# six arms, alternately turning props, orientation colours on the front pair
	for i in 6:
		var a := PI / 6 + float(i) * PI / 3
		var d := Vector3(sin(a), 0, -cos(a))
		var mp := d * 0.56 + Vector3(0, 0.34, 0)
		_tube(k, m, d * 0.15 + Vector3(0, 0.34, 0), mp, 0.016, "plain", carbon, 8)
		k._box(m, Vector3(0.05, 0.035, 0.06), d * 0.17 + Vector3(0, 0.34, 0), "plain", carbon, Vector3(0, atan2(d.x, d.z), 0))
		var front := i == 0 or i == 5
		k._cyl(m, 0.04, 0.042, 0.06, mp + Vector3(0, 0.03, 0), Vector3.ZERO, "plain", Color(0.62, 0.2, 0.1) if front else Color(0.16, 0.16, 0.16), 12)
		k._box(m, Vector3(0.06, 0.02, 0.06), mp + Vector3(0, -0.005, 0), mat, col)
		_prop(k, m, mp + Vector3(0, 0.065, 0), 0.21, 2, float(i) * 0.9)
	# skids on two legs each
	for s in [-1.0, 1.0]:
		for z in [-0.1, 0.1]:
			_tube(k, m, Vector3(s * 0.09, 0.29, z), Vector3(s * 0.22, 0.015, z * 1.6), 0.008, "plain", carbon, 6)
		VehicleAircraft.skid_runner(k, m, [Vector3(s * 0.22, 0.015, -0.24), Vector3(s * 0.22, 0.015, 0.24)], [], 0.011, "plain", carbon)
	if demining:
		# a rack of four demolition charges and the ground-scanning sensor
		k._box(m, Vector3(0.3, 0.02, 0.3), Vector3(0, 0.215, 0), "gunmetal_w")
		for i in 4:
			var cx := -0.08 if i % 2 == 0 else 0.08
			var cz := -0.08 if i < 2 else 0.08
			k._cyl(m, 0.045, 0.045, 0.13, Vector3(cx, 0.14, cz), Vector3.ZERO, "paint", Color(0.72, 0.38, 0.1), 10)
			k._cyl(m, 0.025, 0.025, 0.03, Vector3(cx, 0.06, cz), Vector3.ZERO, "plain", dark, 8)
		k._box(m, Vector3(0.05, 0.05, 0.2), Vector3(0, 0.27, -0.19), "gunmetal_w")
		k._box(m, Vector3(0.12, 0.03, 0.12), Vector3(0, 0.235, -0.33), mat, col)
		k._add(m, Res.sphere(0.035, 10), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.2, -0.33))
		k._cyl(m, 0.016, 0.016, 0.01, Vector3(0, 0.2, -0.366), Vector3(PI / 2, 0, 0), "glass", null, 8, false)
		k._box(m, Vector3(0.05, 0.022, 0.08), Vector3(0.1, 0.4, 0.1), "plain", Color(0.15, 0.3, 0.55))
	else:
		# the cargo box on its release hook
		k._box(m, Vector3(0.05, 0.06, 0.05), Vector3(0, 0.205, 0), "gunmetal_w")
		k._box(m, Vector3(0.3, 0.17, 0.34), Vector3(0, 0.1, 0), "canvas", Color(0.36, 0.36, 0.26))
		for x in [-0.08, 0.08]:
			k._box(m, Vector3(0.03, 0.175, 0.345), Vector3(x, 0.1, 0), "plain", Color(0.15, 0.15, 0.13))
		k._box(m, Vector3(0.1, 0.06, 0.005), Vector3(0, 0.12, -0.172), "plain", Color(0.8, 0.78, 0.7), Vector3.ZERO, false)
		k._add(m, Res.sphere(0.03, 8), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.29, -0.15))
