class_name VmShips
extends RefCounted
## Procedural models: the patrol ship and the armed trawler, the bigger craft
## that work from a dock. Conventions as in VehicleModels and VmBoat: local -Z
## is the bow, metres, parts via k._add / k._box / k._cyl, and VmBoat's small
## helpers (_rod, _panel, _band, _skin, _strip, ...) reused. y = 0 is the KEEL.
##
## These float: DRAFT is the waterline's height above the keel, and the game
## sinks the model that far. A hull is lofted through stations whose sections
## carry points at the boot-top's edges and at the deck, so its three painted
## bands (anti-fouling, boot-top, topsides) and the bulwark above the deck all
## meet on flat faces.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["patrol_ship", "gun_trawler"]

## The waterline's height above the keel for each hull.
const DRAFT := {"patrol_ship": 1.1, "gun_trawler": 1.85}

## Hulls (see _station): z0 the transom, len to the stem's head, b the sheer
## half-beam, bc the chine's (or the bilge's) half-beam, kh the keel's
## half-width; the deck at yd0 aft and yd1 at the stem (lowest, ydm, at um;
## dp its curve forward), a bulwark bw0..bw1 high rising between bws and bwe;
## dr0/dr1 deadrise aft/forward (rad), fore where the forefoot starts to rise
## toward the stem's head and kp its curve; ent/entc where the sheer/chine
## start to narrow toward the bow, pb/pc how full the bow is in plan, cl the
## chine's lift forward; tr/tru a transom narrower than the beam; ky0 a keel
## bar's depth under the hull, sr/sru the run rising aft of it; e0/e1 a round
## bilge's squareness amidships/forward (absent: a hard chine); wl0/wl1 the
## boot-top band; us the stations (0 transom .. 1 stem).
const PB := {"z0": 12.0, "len": 24.8, "b": 3.05, "bc": 2.78, "kh": 0.1, "yd0": 2.55, "yd1": 3.3, "bw0": 0.0, "bw1": 0.8,
	"bws": 0.62, "bwe": 0.97, "dr0": 0.3, "dr1": 1.0, "fore": 0.58, "kp": 2.8, "ent": 0.42, "entc": 0.3, "pb": 2.1, "pc": 1.45,
	"cl": 0.3, "wl0": 0.85, "wl1": 1.42,
	"us": [0.0, 0.06, 0.13, 0.2, 0.28, 0.36, 0.44, 0.52, 0.58, 0.64, 0.7, 0.75, 0.8, 0.84, 0.88, 0.915, 0.945, 0.97, 0.988, 1.0]}
const TR := {"z0": 8.3, "len": 17.0, "b": 2.78, "bc": 2.62, "kh": 0.11, "yd0": 3.0, "ydm": 2.8, "um": 0.36, "yd1": 3.95, "dp": 1.8,
	"bw0": 1.0, "bw1": 1.12, "bws": 0.6, "bwe": 1.0, "dr0": 0.4, "dr1": 1.15, "fore": 0.72, "kp": 1.5, "ent": 0.5, "entc": 0.42,
	"pb": 1.9, "pc": 1.5, "cl": 0.25, "tr": 0.8, "tru": 0.36, "ky0": 0.32, "sr": 1.25, "sru": 0.3, "e0": 2.8, "e1": 1.1,
	"wl0": 1.65, "wl1": 2.1,
	"us": [0.0, 0.03, 0.07, 0.12, 0.18, 0.25, 0.33, 0.42, 0.5, 0.58, 0.65, 0.72, 0.77, 0.82, 0.86, 0.9, 0.93, 0.955, 0.975, 0.99, 1.0]}

const STAINLESS := Color(0.62, 0.63, 0.63)
const HAZE := Color(0.46, 0.49, 0.51)  # US Navy haze grey
const ORANGE := Color(0.86, 0.36, 0.08)  # life rings, floats
const RUST := Color(0.36, 0.17, 0.08)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"patrol_ship":
			_patrol_ship(k, team, seed)
		"gun_trawler":
			_gun_trawler(k, team, seed)
		_:
			return false
	return true


# --- hull geometry -------------------------------------------------------------------
## A station is [z, side, deck, top, u, chine, keel]: side the right half of
## the section as [x, y, ...] from the keel up to the bulwark's top (VmBoat's
## format, so its _band / _skin / _hw read it), deck the deck's height there.

static func _deck_y(p: Dictionary, u: float) -> float:
	var um: float = p.get("um", 0.0)
	var ydm: float = p.get("ydm", p["yd0"])
	if u < um:
		return ydm + (float(p["yd0"]) - ydm) * pow((um - u) / um, 2.0)
	return ydm + (float(p["yd1"]) - ydm) * pow((u - um) / (1.0 - um), float(p.get("dp", 2.0)))


static func _bulwark(p: Dictionary, u: float) -> float:
	return lerpf(float(p["bw0"]), float(p["bw1"]), smoothstep(float(p["bws"]), float(p["bwe"]), u))


## The keel's (the hull bottom's) height on the centreline: the forefoot
## curving up into the stem's head, the run lifting toward the transom.
static func _keel_y(p: Dictionary, u: float) -> float:
	var f := clampf((u - float(p["fore"])) / (1.0 - float(p["fore"])), 0.0, 1.0)
	var kb := _deck_y(p, 1.0) + _bulwark(p, 1.0)
	var sru: float = p.get("sru", 0.3)
	var aft := clampf((sru - u) / sru, 0.0, 1.0)
	return maxf(kb * pow(f, float(p["kp"])), float(p.get("ky0", 0.0)) + float(p.get("sr", 0.0)) * pow(aft, 1.7))


static func _station(p: Dictionary, u: float) -> Array:
	var s := clampf((u - float(p["ent"])) / (1.0 - float(p["ent"])), 0.0, 1.0)
	var sc := clampf((u - float(p["entc"])) / (1.0 - float(p["entc"])), 0.0, 1.0)
	var aft := 1.0 - clampf(u / float(p.get("tru", 0.3)), 0.0, 1.0)
	var tw := lerpf(1.0, float(p.get("tr", 1.0)), aft * aft)
	var bs: float = float(p["b"]) * (1.0 - pow(s, float(p["pb"]))) * tw
	var kh: float = float(p["kh"]) * (1.0 - s)
	var bc: float = clampf(float(p["bc"]) * (1.0 - pow(sc, float(p["pc"]))) * tw, kh, maxf(bs, kh))
	var deck := _deck_y(p, u)
	var top := deck + _bulwark(p, u)
	var ky := minf(_keel_y(p, u), top)
	var dr := lerpf(float(p["dr0"]), float(p["dr1"]), pow(u, 1.5))
	var cy := clampf(ky + (bc - kh) * tan(dr) + float(p["cl"]) * pow(u, 3.0), ky, maxf(top - 0.03, ky))
	var pts: Array = [Vector2(kh, ky)]
	if p.has("e0"):
		# a round bilge: a quarter superellipse from the keel up to the bilge's
		# top, full amidships, easing into a V toward the bow
		var e := lerpf(float(p["e0"]), float(p["e1"]), smoothstep(0.5, 0.97, u))
		for i in range(1, 5):
			var t := PI * 0.5 * i / 5.0
			pts.append(Vector2(kh + (bc - kh) * pow(sin(t), 2.0 / e), cy - (cy - ky) * pow(cos(t), 2.0 / e)))
	pts.append(Vector2(bc, cy))
	pts.append(Vector2(bs, top))
	for i in range(1, pts.size()):
		var q: Vector2 = pts[i]
		pts[i] = Vector2(q.x, maxf(q.y, (pts[i - 1] as Vector2).y))
	# points where the paint changes and at the deck's edge (always added, so
	# every station of a hull has the same count)
	for y in [float(p["wl0"]), float(p["wl1"]), deck]:
		pts = _insert(pts, y)
	var side := []
	for q in pts:
		side.append_array([(q as Vector2).x, (q as Vector2).y])
	# keep the section convex
	var n := side.size() >> 1
	for _pass in 2:
		for i in range(1, n - 1):
			var ay: float = side[i * 2 - 1]
			var by: float = side[i * 2 + 3]
			var t := (float(side[i * 2 + 1]) - ay) / maxf(by - ay, 1e-5)
			var xc := lerpf(side[i * 2 - 2], side[i * 2 + 2], t)
			if float(side[i * 2]) < xc:
				side[i * 2] = xc
	return [float(p["z0"]) - u * float(p["len"]), side, deck, top, u, Vector2(bc, cy), Vector2(kh, ky)]


## The polyline with a point added at height y (a copy of an end if y is past it).
static func _insert(pts: Array, y: float) -> Array:
	var out := []
	var done := false
	for i in pts.size():
		var q: Vector2 = pts[i]
		if not done and y <= q.y:
			if i == 0:
				out.append(q)
			else:
				var a: Vector2 = pts[i - 1]
				out.append(a.lerp(q, (y - a.y) / maxf(q.y - a.y, 1e-6)))
			done = true
		out.append(q)
	if not done:
		out.append(pts[pts.size() - 1])
	return out


static func _u(p: Dictionary, z: float) -> float:
	return clampf((float(p["z0"]) - z) / float(p["len"]), 0.0, 1.0)


static func _at(p: Dictionary, z: float) -> Array:
	return _station(p, _u(p, z))


static func _dk(p: Dictionary, z: float) -> float:
	return _deck_y(p, _u(p, z))


## Where the stem is at height y (on the forefoot's curve).
static func _stem_z(p: Dictionary, y: float) -> float:
	var kb := _deck_y(p, 1.0) + _bulwark(p, 1.0)
	var f := pow(clampf(y / kb, 0.0, 1.0), 1.0 / float(p["kp"]))
	return float(p["z0"]) - (float(p["fore"]) + f * (1.0 - float(p["fore"]))) * float(p["len"])


## The hull's half-width at z, height y.
static func _hx(p: Dictionary, z: float, y: float) -> float:
	return VmBoat._hw(_at(p, z)[1], y)


## The stations between u0 and u1 (both ends included).
static func _hull(p: Dictionary, u0 := 0.0, u1 := 1.0) -> Array:
	var out := [_station(p, u0)]
	for u in p["us"]:
		if float(u) > u0 + 0.004 and float(u) < u1 - 0.004:
			out.append(_station(p, u))
	out.append(_station(p, u1))
	return out


## The hull in its three painted bands, and the bulwark on it from the deck
## up (inn thick), from station u = bu forward.
static func _hull_bands(k: VehicleModels, m: Node3D, p: Dictionary, key: String, cols: Array, bkind: String, bcol: Color, inn: float, bu := 0.0) -> void:
	var lo := []
	var bt := []
	var hi := []
	for st in _hull(p):
		lo.append(VmBoat._band(st, -9.0, p["wl0"]))
		bt.append(VmBoat._band(st, p["wl0"], p["wl1"]))
		hi.append(VmBoat._band(st, p["wl1"], st[2]))
	k._add(m, VehicleModels.solid(lo, key + "_af"), cols[0], cols[1], Vector3.ZERO)
	k._add(m, VehicleModels.solid(bt, key + "_boot"), cols[2], cols[3], Vector3.ZERO)
	k._add(m, VehicleModels.solid(hi, key + "_top"), cols[4], cols[5], Vector3.ZERO)
	for s in [-1.0, 1.0]:
		var bw := []
		for st in _hull(p, bu, 1.0):
			bw.append(VmBoat._skin(st, st[2], st[3], 0.0, inn, s))
		k._add(m, VehicleModels.solid(bw, key + "_bw%d" % int(s)), bkind, bcol, Vector3.ZERO)


## A deck plate t thick, inset in from the hull's side at the deck.
static func _deck_mesh(key: String, sts: Array, inset: float, t: float) -> ArrayMesh:
	var rings := []
	for st in sts:
		var d: float = st[2]
		var x := maxf(VmBoat._hw(st[1], d) - inset, 0.02)
		rings.append(VmBoat._rz([x, d - 0.04, x, d + t, -x, d + t, -x, d - 0.04], st[0]))
	return VehicleModels.solid(rings, key)


## A point on the hull's side s at (z, y) and the frame there: x along the
## side the way you read it from outboard, y up the side, z out of it.
static func _surf(p: Dictionary, s: float, z: float, y: float) -> Transform3D:
	var side: Array = _at(p, z)[1]
	var x := VmBoat._hw(side, y)
	var xf := VmBoat._hw(_at(p, z - 0.1)[1], y)
	var xa := VmBoat._hw(_at(p, z + 0.1)[1], y)
	var up := Vector3(s * (VmBoat._hw(side, y + 0.06) - VmBoat._hw(side, y - 0.06)), 0.12, 0.0).normalized()
	# reading from outboard: toward the bow on the right side, aft on the left
	var along := Vector3(s * (xf - xa), 0.0, -0.2).normalized() * s
	var out := along.cross(up).normalized()
	up = out.cross(along).normalized()
	return Transform3D(Basis(along, up, out), Vector3(s * x, y, z))


## A painted patch (w along, h up, t proud) on the hull's side s, centred at (z, y).
static func _decal(k: VehicleModels, m: Node3D, p: Dictionary, s: float, z: float, y: float, w: float, h: float, kind: String, col, t := 0.006, tilt := 0.0) -> void:
	var tf := _surf(p, s, z, y)
	var b := tf.basis * Basis(Vector3(0, 0, 1), tilt)
	_bx(k, m, Vector3(w, h, t), tf.origin + tf.basis.z * (t * 0.5 + 0.002), kind, col, b.get_euler(), false)


## Seven-segment strokes per digit: a top, b top right, c bottom right, d
## bottom, e bottom left, f top left, g middle.
const SEGS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


## A number painted on the hull's side s: digits h tall, centred at (zc, yc).
static func _digits(k: VehicleModels, m: Node3D, p: Dictionary, s: float, text: String, zc: float, yc: float, h: float, col: Color) -> void:
	var w := h * 0.56
	var th := h * 0.16
	var pitch := h * 0.78
	var n := text.length()
	for i in n:
		var c := text[i]
		# where along the side this digit sits: reading from outboard
		var ox := (i - (n - 1) * 0.5) * pitch
		var strokes := []
		if c == "1":
			strokes.append([0.0, 0.0, th, h])
		else:
			for sg in String(SEGS.get(c, "")):
				match sg:
					"a":
						strokes.append([0.0, h * 0.5 - th * 0.5, w, th])
					"g":
						strokes.append([0.0, 0.0, w, th])
					"d":
						strokes.append([0.0, -h * 0.5 + th * 0.5, w, th])
					"f":
						strokes.append([-w * 0.5 + th * 0.5, h * 0.25, th, h * 0.5])
					"b":
						strokes.append([w * 0.5 - th * 0.5, h * 0.25, th, h * 0.5])
					"e":
						strokes.append([-w * 0.5 + th * 0.5, -h * 0.25, th, h * 0.5])
					"c":
						strokes.append([w * 0.5 - th * 0.5, -h * 0.25, th, h * 0.5])
		for q in strokes:
			# the side reads toward the bow on the right (-z), aft on the left
			var z: float = zc - s * (ox + float(q[0]))
			_decal(k, m, p, s, z, yc + float(q[1]), q[2], q[3], "paint", col, 0.008)


## A bar of w x d section swept along a path in the y-z plane (a keel and
## stem bar): a rectangle across the path at each point.
static func _sweep(key: String, pts: Array, w: float, ds: Array) -> ArrayMesh:
	var rings := []
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a).normalized()
		var nrm := Vector3(0, -t.z, t.y)
		var c: Vector3 = pts[i]
		var d: float = ds[i]
		rings.append(PackedVector3Array([c + Vector3(w, 0, 0) + nrm * d, c - Vector3(w, 0, 0) + nrm * d, c - Vector3(w, 0, 0) - nrm * d, c + Vector3(w, 0, 0) - nrm * d]))
	return VehicleModels.solid(rings, key)


# --- cheap parts ----------------------------------------------------------------------
## These models carry a lot of small fittings: the small ones are built from
## lighter primitives than Res gives (plain boxes, uncapped thin rods, coarse
## tori), so the detail costs a fraction of the vertices.

static var _meshes := {}


## A box: chamfered (Res.box) when it's big enough for its edges to catch the
## light, a plain one (a quarter of the vertices) for the small parts.
static func _bx(k: VehicleModels, parent: Node3D, s: Vector3, pos: Vector3, kind: String, col = null, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return k._add(parent, _box_mesh(s), kind, col, pos, rot, Vector3.ONE, shadow)


static func _box_mesh(s: Vector3) -> Mesh:
	if minf(s.x, minf(s.y, s.z)) >= 0.07 and s.x + s.y + s.z >= 1.0:
		return Res.box(s)
	var key := "pb%.3f,%.3f,%.3f" % [s.x, s.y, s.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = s
		_meshes[key] = m
	return _meshes[key]


## A rod from a to b (rails, wires, struts): thin ones four-sided and open-ended.
static func _rod(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 6, shadow := false) -> void:
	k._add(parent, _tube(r, a.distance_to(b), segs if r >= 0.03 else mini(segs, 4)), mat, col, (a + b) * 0.5, VmBoat._aim(b - a), Vector3.ONE, shadow)


static func _tube(r: float, h: float, segs: int) -> Mesh:
	if r >= 0.03:
		return Res.cyl(r, r, h, segs)
	var key := "tu%.3f,%.3f,%d" % [r, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		m.cap_top = false
		m.cap_bottom = false
		_meshes[key] = m
	return _meshes[key]


## A torus round Y (a tyre, a coil of rope, a porthole's rim, a chain link)
## with as few segments as its size needs.
static func _torus(inner: float, outer: float) -> Mesh:
	var rings := 14 if outer > 0.25 else (10 if outer > 0.1 else 7)
	var sides := 6 if outer > 0.25 else (5 if outer > 0.1 else 4)
	var key := "to%.3f,%.3f,%d,%d" % [inner, outer, rings, sides]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rr := (inner + outer) * 0.5
	var r := (outer - inner) * 0.5
	for i in rings:
		for j in sides:
			var c := []
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a: float = TAU * q[0] / rings
				var b: float = TAU * q[1] / sides
				c.append([Vector3(cos(a) * (rr + r * cos(b)), r * sin(b), sin(a) * (rr + r * cos(b))), Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))])
			for t in [0, 1, 2, 0, 2, 3]:
				st.set_normal(c[t][1])
				st.add_vertex(c[t][0])
	var m := st.commit()
	_meshes[key] = m
	return m


# --- fittings --------------------------------------------------------------------------

## A pair of mooring bitts on a base plate, across `yaw`.
static func _bitts(k: VehicleModels, m: Node3D, pos: Vector3, yaw: float, sc: float, kind: String, col) -> void:
	var bs := Basis(Vector3.UP, yaw)
	_bx(k, m, Vector3(0.62, 0.04, 0.24) * sc, pos + Vector3(0, 0.02 * sc, 0), kind, col, Vector3(0, yaw, 0))
	for dx in [-0.2, 0.2]:
		var q: Vector3 = pos + bs * Vector3(dx * sc, 0, 0)
		k._cyl(m, 0.075 * sc, 0.08 * sc, 0.3 * sc, q + Vector3(0, 0.17 * sc, 0), Vector3.ZERO, kind, col, 8)
		k._cyl(m, 0.1 * sc, 0.1 * sc, 0.035 * sc, q + Vector3(0, 0.335 * sc, 0), Vector3.ZERO, kind, col, 8, false)


## A coil of rope lying on the deck.
static func _coil(k: VehicleModels, m: Node3D, pos: Vector3, r: float, col: Color) -> void:
	for i in 3:
		var rr := r * (1.0 - i * 0.12)
		k._add(m, _torus(rr - 0.045, rr), "fabric", col, pos + Vector3(0.02 * i, 0.022 + i * 0.04, -0.015 * i), Vector3.ZERO, Vector3(1, 1.3, 1))


## A life ring on a bracket, its face out along `nrm` (horizontal).
static func _lifering(k: VehicleModels, m: Node3D, pos: Vector3, nrm: Vector3) -> void:
	var yaw := atan2(nrm.x, nrm.z)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2)
	k._add(m, _torus(0.2, 0.33), "plain", ORANGE, pos, b.get_euler())
	for i in 4:
		var a := PI / 4 + i * PI / 2
		var q := pos + Basis(Vector3.UP, yaw) * Vector3(cos(a) * 0.265, sin(a) * 0.265, 0.0)
		_bx(k, m, Vector3(0.05, 0.05, 0.135), q, "plain", Color(0.85, 0.85, 0.82), Vector3(0, yaw, a), false)
	_bx(k, m, Vector3(0.08, 0.06, 0.12), pos + Vector3(0, 0.31, 0) - nrm * 0.03, "gunmetal_w", null, Vector3(0, yaw, 0), false)


## A liferaft canister (white, banded) in its cradle, axis along z, tipped outboard.
static func _liferaft(k: VehicleModels, m: Node3D, pos: Vector3, tilt: float, cradle_col: Color) -> void:
	var pv := k._pivot(m, pos)
	pv.rotation.z = tilt
	var white := Color(0.86, 0.86, 0.82)
	k._cyl(pv, 0.29, 0.29, 0.9, Vector3(0, 0.31, 0), Vector3(PI / 2, 0, 0), "plain", white, 16)
	for e in [-1.0, 1.0]:
		k._add(pv, Res.sphere(0.29, 10), "plain", white, Vector3(0, 0.31, e * 0.45), Vector3.ZERO, Vector3(1, 1, 0.42))
	k._cyl(pv, 0.305, 0.305, 0.05, Vector3(0, 0.31, 0), Vector3(PI / 2, 0, 0), "plain", white.darkened(0.12), 16, false)
	for dz in [-0.32, 0.32]:
		k._cyl(pv, 0.298, 0.298, 0.035, Vector3(0, 0.31, dz), Vector3(PI / 2, 0, 0), "plain", Color(0.2, 0.2, 0.2), 16, false)
		# the cradle's saddle
		_bx(k, pv, Vector3(0.62, 0.12, 0.08), Vector3(0, 0.06, dz), "paint", cradle_col)
	_bx(k, pv, Vector3(0.1, 0.05, 0.9), Vector3(0.24, 0.02, 0), "paint", cradle_col)
	_bx(k, pv, Vector3(0.1, 0.05, 0.9), Vector3(-0.24, 0.02, 0), "paint", cradle_col)
	VmBoat._bake(pv)


## A mushroom ventilator on the deck.
static func _vent(k: VehicleModels, m: Node3D, pos: Vector3, kind: String, col) -> void:
	k._cyl(m, 0.09, 0.1, 0.32, pos + Vector3(0, 0.16, 0), Vector3.ZERO, kind, col, 10)
	k._cyl(m, 0.17, 0.12, 0.08, pos + Vector3(0, 0.36, 0), Vector3.ZERO, kind, col, 12)


## A flag on a staff's head at pos (its hoist), flying aft along +z.
static func _flag(k: VehicleModels, m: Node3D, pos: Vector3, team: int, w: float, h: float) -> void:
	if team < 0 or team >= Defs.TEAM_COLORS.size() or k.burnt:
		return
	var tc: Color = Defs.TEAM_COLORS[team].lerp(Color(0.45, 0.45, 0.42), 0.35).darkened(0.12)
	var n := 3
	var x := 0.0
	var z := 0.0
	for i in n:
		var a := (0.35 if i % 2 == 0 else -0.35) + 0.0
		var l := w / n
		var cz := z + cos(a) * l * 0.5
		var cx := x + sin(a) * l * 0.5
		_bx(k, m, Vector3(0.012, h - i * 0.03, l + 0.02), pos + Vector3(cx, -h * 0.5 - i * 0.03, cz), "fabric", tc, Vector3(0, a, 0), false)
		z += cos(a) * l
		x += sin(a) * l


## A whip antenna on its base, raked `rake` aft.
static func _whip(k: VehicleModels, m: Node3D, pos: Vector3, h: float, rake := 0.06) -> void:
	k._cyl(m, 0.035, 0.045, 0.16, pos + Vector3(0, 0.08, 0), Vector3.ZERO, "plain", Color(0.82, 0.82, 0.79), 8, false)
	_rod(k, m, pos + Vector3(0, 0.15, 0), pos + Vector3(0, h, h * rake), 0.012, "gunmetal_w", null, 4)


## A searchlight on a yoke: lamp drum, glass, a handle at the back.
static func _searchlight(k: VehicleModels, m: Node3D, pos: Vector3, yaw: float, col: Color, kind := "paint") -> void:
	var b := Basis(Vector3.UP, yaw)
	k._cyl(m, 0.05, 0.07, 0.14, pos + Vector3(0, 0.07, 0), Vector3.ZERO, kind, col, 10)
	_bx(k, m, Vector3(0.36, 0.03, 0.06), pos + Vector3(0, 0.15, 0), kind, col, Vector3(0, yaw, 0))
	for sx in [-0.17, 0.17]:
		_bx(k, m, Vector3(0.03, 0.2, 0.06), pos + b * Vector3(sx, 0.25, 0), kind, col, Vector3(0, yaw, 0))
	var c := pos + Vector3(0, 0.3, 0)
	k._cyl(m, 0.14, 0.12, 0.3, c, (b * Basis(Vector3.RIGHT, PI / 2)).get_euler(), kind, col, 14)
	k._cyl(m, 0.125, 0.125, 0.01, c + b * Vector3(0, 0, -0.152), (b * Basis(Vector3.RIGHT, PI / 2)).get_euler(), "glass", Color(0.75, 0.75, 0.7), 14, false)
	_rod(k, m, c + b * Vector3(0, 0.0, 0.15), c + b * Vector3(0, 0.0, 0.3), 0.015, "gunmetal_w")


# --- weapons -----------------------------------------------------------------------------

## Mk 38 Mod 2 25 mm stabilised mount: the fixed foundation ring and pedestal
## on the deck, then (on the returned training pivot, on the mount's axis) the
## carriage, the armoured cradle housing round the M242 Bushmaster with its
## barrel, the electro-optical sight on the left and the ammunition feed on the
## right. The muzzle is at (0, 0.58, -2.66) in the pivot.
static func _mk38(k: VehicleModels, m: Node3D, pos: Vector3, col: Color) -> Node3D:
	var cm := "plain"
	k._cyl(m, 0.66, 0.7, 0.06, pos + Vector3(0, 0.03, 0), Vector3.ZERO, cm, col, 22)
	for i in 12:
		var a := TAU * i / 12.0
		k._cyl(m, 0.022, 0.022, 0.05, pos + Vector3(cos(a) * 0.62, 0.07, sin(a) * 0.62), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._cyl(m, 0.5, 0.56, 0.5, pos + Vector3(0, 0.31, 0), Vector3.ZERO, cm, col, 20)
	k._cyl(m, 0.53, 0.53, 0.03, pos + Vector3(0, 0.56, 0), Vector3.ZERO, "gunmetal_w", null, 20, false)
	var tv := k._pivot(m, pos + Vector3(0, 0.57, 0))
	# the carriage: a low chamfered box on the turntable, the trunnion arms
	k._add(tv, VehicleModels.loft("ship_mk38_carr", VmBoat._rr(1.0, 1.05, 0.08, 0.22, 0.12), VmBoat._rr(0.9, 0.9, 0.1, 0.16, 0.08), 0.0, 0.2), cm, col, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		k._add(tv, VehicleModels.extrude_x("ship_mk38_arm", [-0.28, 0.18, 0.32, 0.18, 0.22, 0.66, -0.12, 0.66], -0.05, 0.05), cm, col, Vector3(sx * 0.37, 0, 0))
		k._cyl(tv, 0.09, 0.09, 0.06, Vector3(sx * 0.43, 0.58, 0.04), Vector3(0, 0, PI / 2), "gunmetal_w", null, 12, false)
	# the cradle housing: chamfered section, its nose tapering round the barrel
	var sec := func(z: float, f: float) -> PackedVector3Array:
		return VmBoat._rz([0.27 * f, 0.38, 0.27 * f, 0.7, 0.19 * f, 0.79, -0.19 * f, 0.79, -0.27 * f, 0.7, -0.27 * f, 0.38], z)
	k._add(tv, VehicleModels.solid([sec.call(-0.66, 0.55), sec.call(-0.5, 1.0), sec.call(0.62, 1.0), sec.call(0.72, 0.9)], "ship_mk38_house"), cm, col, Vector3.ZERO)
	for z in [-0.2, 0.25]:
		_bx(k, tv, Vector3(0.56, 0.012, 0.02), Vector3(0, 0.795, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the barrel: a support sleeve, the long tapering tube, a muzzle device
	k._cyl(tv, 0.075, 0.085, 0.3, Vector3(0, 0.58, -0.78), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._cyl(tv, 0.03, 0.042, 1.72, Vector3(0, 0.58, -1.78), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(tv, 0.045, 0.045, 0.16, Vector3(0, 0.58, -2.56), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	# the electro-optical sight on the left, its windows forward
	_bx(k, tv, Vector3(0.08, 0.1, 0.3), Vector3(-0.34, 0.6, -0.1), cm, col)
	k._add(tv, VehicleModels.loft("ship_mk38_eos", VmBoat._rr(0.28, 0.46, 0.0, 0.06, 0.04), VmBoat._rr(0.24, 0.4, 0.02, 0.05, 0.03), 0.0, 0.4), cm, col, Vector3(-0.53, 0.44, -0.12))
	_bx(k, tv, Vector3(0.16, 0.1, 0.012), Vector3(-0.53, 0.72, -0.35), "glass", null, Vector3.ZERO, false)
	_bx(k, tv, Vector3(0.1, 0.08, 0.012), Vector3(-0.53, 0.58, -0.35), "glass", null, Vector3.ZERO, false)
	_bx(k, tv, Vector3(0.3, 0.02, 0.2), Vector3(-0.53, 0.855, -0.3), cm, col, Vector3(-0.12, 0, 0), false)
	# the ammunition box on the right and its feed chute into the receiver
	_bx(k, tv, Vector3(0.26, 0.38, 0.66), Vector3(0.52, 0.42, 0.18), cm, col.darkened(0.06))
	_bx(k, tv, Vector3(0.2, 0.06, 0.2), Vector3(0.38, 0.66, 0.0), "gunmetal_w", null, Vector3(0, 0, -0.5))
	for z in [-0.05, 0.4]:
		_bx(k, tv, Vector3(0.28, 0.03, 0.04), Vector3(0.52, 0.62, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the spent case chute under the housing, a cable loom at the back
	_bx(k, tv, Vector3(0.12, 0.2, 0.14), Vector3(0, 0.3, -0.2), "gunmetal_w")
	_rod(k, tv, Vector3(-0.2, 0.42, 0.68), Vector3(-0.32, 0.12, 0.5), 0.03, "rubber", null, 6)
	return tv


## The M2 .50 cal on a pedestal mount: a post with a flange, the cradle,
## receiver, barrel with its carrying handle and flash hider, spade grips, the
## ammo can on the left. Trained `yaw` (0 = forward), elevated `el`.
static func _m2(k: VehicleModels, m: Node3D, pos: Vector3, yaw: float, el := 0.06) -> void:
	k._cyl(m, 0.14, 0.15, 0.03, pos + Vector3(0, 0.015, 0), Vector3.ZERO, "gunmetal_w", null, 12)
	k._cyl(m, 0.05, 0.06, 0.85, pos + Vector3(0, 0.44, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	var pv := k._pivot(m, pos + Vector3(0, 0.88, 0))
	pv.rotation = Vector3(el, yaw, 0)
	_bx(k, pv, Vector3(0.1, 0.1, 0.26), Vector3(0, 0.02, 0.0), "gunmetal_w")
	_bx(k, pv, Vector3(0.13, 0.17, 0.66), Vector3(0, 0.13, -0.05), "gunmetal_w")
	_bx(k, pv, Vector3(0.1, 0.03, 0.4), Vector3(0, 0.23, -0.08), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(pv, 0.036, 0.036, 0.3, Vector3(0, 0.13, -0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(pv, 0.022, 0.022, 1.02, Vector3(0, 0.13, -1.04), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	k._cyl(pv, 0.03, 0.026, 0.09, Vector3(0, 0.13, -1.58), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	_rod(k, pv, Vector3(0, 0.2, -0.62), Vector3(0, 0.28, -0.75), 0.012, "gunmetal_w")
	_rod(k, pv, Vector3(0, 0.28, -0.75), Vector3(0, 0.2, -0.88), 0.012, "gunmetal_w")
	for sx in [-0.07, 0.07]:
		_rod(k, pv, Vector3(sx, 0.12, 0.28), Vector3(sx, 0.2, 0.36), 0.016, "rubber", null, 6, true)
	_bx(k, pv, Vector3(0.11, 0.19, 0.29), Vector3(-0.15, 0.08, -0.08), "paint", Color(0.3, 0.33, 0.22))
	_bx(k, pv, Vector3(0.06, 0.02, 0.1), Vector3(-0.07, 0.19, -0.08), "steel", Color(0.6, 0.48, 0.22), Vector3(0, 0, 0.4), false)
	VmBoat._bake(pv)


## ZU-23-2 twin 23 mm cannon, its wheels gone and its base welded down: the
## three-legged lower carriage on a deck plate (fixed), then on the returned
## pivot (the traverse axis) the upper carriage, the two guns in their cradle
## with flash hiders, the box magazines on their outer sides, the sight and
## two seats with handwheels. Sets k.mg_tip between the two muzzles.
static func _zu23(k: VehicleModels, m: Node3D, pos: Vector3, col: Color) -> Node3D:
	var cm := "paint"
	var gm := "gunmetal_w"
	# the lower carriage: a triangle of box beams with levelling jacks
	k._cyl(m, 0.42, 0.48, 0.22, pos + Vector3(0, 0.11, 0), Vector3.ZERO, cm, col, 14)
	for i in 3:
		var a := PI / 2 + TAU * i / 3.0
		var d := Vector3(cos(a), 0, -sin(a))
		var tip := pos + d * 1.25
		_rod(k, m, pos + d * 0.3 + Vector3(0, 0.12, 0), tip + Vector3(0, 0.12, 0), 0.07, cm, col, 6, true)
		k._cyl(m, 0.05, 0.05, 0.22, tip + Vector3(0, 0.11, 0), Vector3.ZERO, gm, null, 8)
		k._cyl(m, 0.13, 0.15, 0.03, tip + Vector3(0, 0.015, 0), Vector3.ZERO, gm, null, 10)
		# crude welds: a gusset onto the deck plate
		_bx(k, m, Vector3(0.16, 0.08, 0.16), tip + Vector3(0, 0.04, 0), "steel", RUST.lerp(Color(0.25, 0.25, 0.24), 0.4))
	var tv := k._pivot(m, pos + Vector3(0, 0.24, 0))
	k._cyl(tv, 0.46, 0.46, 0.06, Vector3(0, 0.03, 0), Vector3.ZERO, cm, col, 16)
	# the upper carriage: a floor, two side frames up to the trunnions
	_bx(k, tv, Vector3(1.1, 0.06, 1.0), Vector3(0, 0.09, 0.15), cm, col)
	for sx in [-1.0, 1.0]:
		k._add(tv, VehicleModels.extrude_x("ship_zu_frame", [0.55, 0.1, -0.35, 0.1, -0.2, 0.72, 0.25, 0.72], -0.03, 0.03), cm, col, Vector3(sx * 0.3, 0, 0))
	k._cyl(tv, 0.05, 0.05, 0.72, Vector3(0, 0.66, -0.02), Vector3(0, 0, PI / 2), gm, null, 10)
	var el := k._pivot(tv, Vector3(0, 0.66, -0.02))
	el.rotation.x = 0.16
	for sx in [-0.16, 0.16]:
		# receivers, barrel jackets, barrels and flash hiders
		_bx(k, el, Vector3(0.14, 0.2, 1.05), Vector3(sx, 0.02, 0.05), gm)
		k._cyl(el, 0.06, 0.06, 0.4, Vector3(sx, 0.04, -0.66), Vector3(PI / 2, 0, 0), gm, null, 10)
		k._cyl(el, 0.032, 0.036, 1.6, Vector3(sx, 0.04, -1.65), Vector3(PI / 2, 0, 0), gm, null, 8)
		k._cyl(el, 0.05, 0.05, 0.3, Vector3(sx, 0.04, -2.55), Vector3(PI / 2, 0, 0), gm, null, 10)
		for z in [-2.48, -2.6]:
			_bx(k, el, Vector3(0.11, 0.02, 0.03), Vector3(sx, 0.04, z), gm, null, Vector3.ZERO, false)
		# the box magazine on the gun's outer side
		var ox: float = signf(sx) * 0.37
		_bx(k, el, Vector3(0.2, 0.36, 0.52), Vector3(ox, 0.08, 0.05), cm, col.darkened(0.08))
		_bx(k, el, Vector3(0.22, 0.03, 0.54), Vector3(ox, 0.27, 0.05), gm, null, Vector3.ZERO, false)
	# the cradle tying the two guns, the sight standing up on the left
	_bx(k, el, Vector3(0.5, 0.12, 0.3), Vector3(0, -0.06, -0.2), cm, col)
	_bx(k, el, Vector3(0.12, 0.34, 0.14), Vector3(-0.08, 0.3, 0.12), gm)
	_bx(k, el, Vector3(0.24, 0.16, 0.2), Vector3(-0.08, 0.5, 0.1), gm)
	_bx(k, el, Vector3(0.16, 0.1, 0.012), Vector3(-0.08, 0.5, -0.006), "glass", null, Vector3.ZERO, false)
	k.mg_tip = k._tip(el, Vector3(0, 0.04, -2.72))
	# two seats with backrests behind the guns, handwheels in front of them
	for sx in [-1.0, 1.0]:
		_bx(k, tv, Vector3(0.34, 0.06, 0.32), Vector3(sx * 0.55, 0.48, 0.55), "plain_dark", Color(0.16, 0.15, 0.13))
		_bx(k, tv, Vector3(0.32, 0.3, 0.05), Vector3(sx * 0.55, 0.66, 0.73), "plain_dark", Color(0.16, 0.15, 0.13), Vector3(-0.2, 0, 0))
		_rod(k, tv, Vector3(sx * 0.55, 0.12, 0.55), Vector3(sx * 0.55, 0.45, 0.55), 0.03, gm, null, 6, true)
		k._add(tv, _torus(0.11, 0.14), gm, null, Vector3(sx * 0.5, 0.62, 0.22), Vector3(0, 0, PI / 2))
		_rod(k, tv, Vector3(sx * 0.46, 0.62, 0.22), Vector3(sx * 0.33, 0.62, 0.22), 0.02, gm)
	# a slab of steel plate welded on in front of the cradle
	_bx(k, tv, Vector3(0.95, 0.34, 0.03), Vector3(0, 0.36, -0.64), "steel", Color(0.31, 0.3, 0.26), Vector3(-0.08, 0, 0))
	VmBoat._bake(el)  # (the muzzle marker moves with the rest)
	return tv


## DShK 12.7 mm on a pintle: the post, the cradle, the receiver, the finned
## barrel and its big muzzle brake, spade grips, a 50-round box on the left,
## a scrap-steel shield in front. Trained `yaw`.
static func _dshk(k: VehicleModels, m: Node3D, pos: Vector3, yaw: float) -> void:
	var gm := "gunmetal_w"
	k._cyl(m, 0.06, 0.07, 0.95, pos + Vector3(0, 0.47, 0), Vector3.ZERO, gm, null, 10)
	_rod(k, m, pos + Vector3(0, 0.3, 0), pos + Vector3(0.35, 0.0, 0.2), 0.025, gm, null, 6, true)
	_rod(k, m, pos + Vector3(0, 0.3, 0), pos + Vector3(-0.35, 0.0, 0.2), 0.025, gm, null, 6, true)
	_rod(k, m, pos + Vector3(0, 0.3, 0), pos + Vector3(0.0, 0.0, -0.4), 0.025, gm, null, 6, true)
	var pv := k._pivot(m, pos + Vector3(0, 0.97, 0))
	pv.rotation = Vector3(0.1, yaw, 0)
	_bx(k, pv, Vector3(0.1, 0.12, 0.3), Vector3(0, 0.0, 0.0), gm)
	_bx(k, pv, Vector3(0.14, 0.17, 0.7), Vector3(0, 0.12, 0.0), gm)
	for i in 6:
		k._cyl(pv, 0.05, 0.05, 0.035, Vector3(0, 0.13, -0.42 - i * 0.07), Vector3(PI / 2, 0, 0), gm, null, 10, false)
	k._cyl(pv, 0.026, 0.026, 1.1, Vector3(0, 0.13, -0.92), Vector3(PI / 2, 0, 0), gm, null, 6)
	_bx(k, pv, Vector3(0.11, 0.09, 0.16), Vector3(0, 0.13, -1.5), gm)
	for sx in [-0.07, 0.07]:
		_rod(k, pv, Vector3(sx, 0.1, 0.33), Vector3(sx, 0.2, 0.42), 0.017, "wood_dark", null, 6, true)
	_bx(k, pv, Vector3(0.14, 0.22, 0.3), Vector3(-0.17, 0.07, 0.0), "paint", Color(0.3, 0.33, 0.22))
	_bx(k, pv, Vector3(0.5, 0.32, 0.025), Vector3(0, 0.06, -0.4), "steel", Color(0.32, 0.31, 0.27), Vector3(-0.1, 0, 0))
	VmBoat._bake(pv)


# --- Mk VI patrol boat -------------------------------------------------------------------

## The Coalition navy's patrol boat, after the US Navy Mk VI: a 25 m deep-V
## aluminium monohull with a sharp, flared bow and a bulwark round the
## foredeck, a low faceted deckhouse whose pilothouse has a raked windscreen
## under a visor, a raked mast with the radar, a 25 mm Mk 38 forward (the
## turret) and another aft, .50 cals on pedestals along the side decks, twin
## waterjets. Haze grey, the hull number in black on the bows.
static func _patrol_ship(k: VehicleModels, team: int, seed: int) -> void:
	var m := k.root
	var p := PB
	var grey := HAZE
	var sup := HAZE.lightened(0.05)
	var dkc := Color(0.24, 0.25, 0.26)
	var blk := Color(0.07, 0.07, 0.075)
	var zt: float = p["z0"]
	var zs: float = zt - float(p["len"])
	_hull_bands(k, m, p, "ship_pb", ["plain", Color(0.3, 0.13, 0.11), "plain", blk, "plain", grey], "plain", grey, 0.07, 0.56)
	var all := _hull(p)
	k._add(m, _deck_mesh("ship_pb_deck", all, 0.09, 0.012), "plain", dkc, Vector3.ZERO)
	# spray rails and chine flats on the bottom, the rubbing strake under the
	# deck edge, a toe rail round the open decks, a capping on the bulwark
	for s in [-1.0, 1.0]:
		var sp1 := []
		var sp2 := []
		var ch := []
		for st in _hull(p, 0.0, 0.84):
			var kp: Vector2 = st[6]
			var cp: Vector2 = st[5]
			var q1 := kp.lerp(cp, 0.36)
			var q2 := kp.lerp(cp, 0.7)
			sp1.append(Vector3(s * q1.x, q1.y - 0.015, st[0]))
			sp2.append(Vector3(s * q2.x, q2.y - 0.015, st[0]))
			ch.append(Vector3(s * (cp.x + 0.02), cp.y - 0.01, st[0]))
		k._add(m, VmBoat._strip("ship_pb_sp1%d" % int(s), sp1, 0.035, 0.02), "plain", Color(0.3, 0.13, 0.11), Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_pb_sp2%d" % int(s), sp2, 0.035, 0.02), "plain", Color(0.3, 0.13, 0.11), Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_pb_ch%d" % int(s), ch, 0.04, 0.02), "plain", Color(0.3, 0.13, 0.11), Vector3.ZERO)
		var rub := []
		var toe := []
		var cap := []
		for st in _hull(p, 0.0, 0.985):
			var d: float = st[2]
			rub.append(Vector3(s * (VmBoat._hw(st[1], d - 0.14) + 0.035), d - 0.14, st[0]))
			if float(st[4]) < 0.66:
				toe.append(Vector3(s * (VmBoat._hw(st[1], d) - 0.03), d + 0.04, st[0]))
			if float(st[4]) > 0.6:
				cap.append(Vector3(s * (VmBoat._hw(st[1], st[3]) - 0.035), float(st[3]) + 0.015, st[0]))
		k._add(m, VmBoat._strip("ship_pb_rub%d" % int(s), rub, 0.045, 0.06), "rubber", Color(0.1, 0.1, 0.1), Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_pb_toe%d" % int(s), toe, 0.025, 0.045), "plain", grey, Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_pb_cap%d" % int(s), cap, 0.055, 0.02), "plain", grey.darkened(0.1), Vector3.ZERO)
		# scuppers along the deck edge, exhaust outlets low aft, the hull number
		for i in 9:
			var z := -4.6 + i * 1.8
			_decal(k, m, p, s, z, _dk(p, z) - 0.06, 0.32, 0.07, "plain_dark", Color(0.05, 0.05, 0.05))
		for z in [9.6, 10.4]:
			var tf := _surf(p, s, z, 1.75)
			k._cyl(m, 0.11, 0.11, 0.05, tf.origin, (tf.basis * Basis(Vector3.RIGHT, PI / 2)).get_euler(), "plain_dark", Color(0.05, 0.05, 0.05), 12, false)
			_decal(k, m, p, s, z + 0.32, 1.8, 0.55, 0.16, "plain", Color(0.3, 0.31, 0.31), 0.004)
		_digits(k, m, p, s, str(1 + seed % 12), -6.9, 2.25, 0.9, Color(0.06, 0.06, 0.06))
		# draft marks at the stem and stern
		for i in 4:
			var y := 0.6 + i * 0.3
			_decal(k, m, p, s, _stem_z(p, y) + 0.45, y, 0.18, 0.05, "plain", Color(0.85, 0.85, 0.82))
			_decal(k, m, p, s, zt - 0.25, y, 0.18, 0.05, "plain", Color(0.85, 0.85, 0.82))
	# --- the deckhouse: the pilothouse forward, the lower after house
	var y0 := 2.5
	var base := [-1.25, -4.85, 1.25, -4.85, 2.12, -3.6, 2.12, -0.45, -2.12, -0.45, -2.12, -3.6]
	var sill := [-1.17, -4.72, 1.17, -4.72, 2.02, -3.5, 2.02, -0.45, -2.02, -0.45, -2.02, -3.5]
	var roof := [-0.98, -3.98, 0.98, -3.98, 1.8, -3.0, 1.8, -0.45, -1.8, -0.45, -1.8, -3.0]
	var y1 := 4.0
	var y2 := 5.1
	k._add(m, VehicleModels.solid([VmBoat._ry(base, y0), VmBoat._ry(sill, y1), VmBoat._ry(roof, y2)], "ship_pb_pilot"), "plain", sup, Vector3.ZERO)
	var ab := [-2.12, -0.6, 2.12, -0.6, 2.12, 4.0, 1.85, 4.5, -1.85, 4.5, -2.12, 4.0]
	var at := [-1.98, -0.6, 1.98, -0.6, 1.98, 3.92, 1.73, 4.38, -1.73, 4.38, -1.98, 3.92]
	var ya := 4.55
	k._add(m, VehicleModels.solid([VmBoat._ry(ab, y0), VmBoat._ry(at, ya)], "ship_pb_after"), "plain", sup, Vector3.ZERO)
	# the window band: dark surrounds, then the panes, pillars between them
	var inside := Vector3(0, 4.3, -2.0)
	var wband := Color(0.13, 0.13, 0.14)
	var facets := [[5, 0, 1], [0, 1, 3], [1, 2, 1], [2, 3, 3], [4, 5, 3]]
	for f in facets:
		var a: int = f[0]
		var b: int = f[1]
		var np: int = f[2]
		var t1 := 1.0 if a != 2 and a != 4 else 0.8
		var t0 := 0.0 if a != 4 else 0.2
		var p0 := VmBoat._pt(sill, a, y1 + 0.05).lerp(VmBoat._pt(sill, b, y1 + 0.05), t0)
		var p1 := VmBoat._pt(sill, a, y1 + 0.05).lerp(VmBoat._pt(sill, b, y1 + 0.05), t1)
		var q1 := VmBoat._pt(roof, a, y2 - 0.08).lerp(VmBoat._pt(roof, b, y2 - 0.08), t1)
		var q0 := VmBoat._pt(roof, a, y2 - 0.08).lerp(VmBoat._pt(roof, b, y2 - 0.08), t0)
		VmBoat._panel(k, m, p0, p1, q1, q0, inside, 0.03, 0.02, "paint", wband, 0.0)
		for i in np:
			var ta := (i + 0.05) / np
			var tb := (i + 0.95) / np
			VmBoat._panel(k, m, p0.lerp(p1, ta), p0.lerp(p1, tb), q0.lerp(q1, tb), q0.lerp(q1, ta), inside, 0.05, 0.03, "glass", Color(0.12, 0.15, 0.18), 0.0)
	# window pillars at the facet corners, wipers on the windscreen
	for i in [0, 1, 2, 5]:
		_rod(k, m, VmBoat._pt(sill, i, y1), VmBoat._pt(roof, i, y2), 0.045, "plain", sup, 6, true)
	for i in 3:
		var bx := -0.75 + i * 0.75
		_rod(k, m, Vector3(bx, y1 + 0.12, -4.66), Vector3(bx + 0.08, y1 + 0.75, -4.24), 0.009, "plain_dark", Color(0.05, 0.05, 0.05), 4)
	# the roof, its visor over the windscreen, a coaming round its edge
	var rc := VmBoat._scale_xz(roof, 1.04, -2.2)
	k._add(m, VehicleModels.solid([VmBoat._ry(rc, y2 - 0.02), VmBoat._ry(rc, y2 + 0.1)], "ship_pb_roof"), "plain", sup, Vector3.ZERO)
	for f in [[5, 0], [0, 1], [1, 2]]:
		var a := VmBoat._pt(rc, f[0], y2 + 0.06)
		var b := VmBoat._pt(rc, f[1], y2 + 0.06)
		var o := Vector3((b - a).z, 0, -(b - a).x).normalized() * 0.42
		VmBoat._panel(k, m, a, b, b + o + Vector3(0, -0.1, 0), a + o + Vector3(0, -0.1, 0), Vector3(0, 0, -2.0), 0.0, 0.04, "plain", sup, 0.0)
	# the pilothouse's after wall above the after house: two small windows, a door to the roof
	for sx in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.6, 0.32, 0.03), Vector3(sx * 1.1, 4.82, -0.44), "glass", Color(0.12, 0.15, 0.18), Vector3.ZERO, false)
	# the after house: doors and portholes in its sides, a ladder up its back
	for s in [-1.0, 1.0]:
		var xw := func(y: float) -> float:
			return lerpf(2.12, 1.98, (y - y0) / (ya - y0))
		for dz in [[0.35, 1.2]]:
			var dy0 := _dk(p, 0.8) + 0.06
			var dy1 := 4.36
			var c0 := Vector3(s * xw.call(dy0), dy0, dz[0])
			var c1 := Vector3(s * xw.call(dy0), dy0, dz[1])
			var c2 := Vector3(s * xw.call(dy1), dy1, dz[1])
			var c3 := Vector3(s * xw.call(dy1), dy1, dz[0])
			VmBoat._panel(k, m, c0, c1, c2, c3, Vector3(0, 3.5, 1.5), -0.05, 0.02, "plain", sup.darkened(0.12), 0.0)
			VmBoat._panel(k, m, c0, c1, c2, c3, Vector3(0, 3.5, 1.5), 0.0, 0.04, "plain", sup, 0.012)
			for q in [[0.42, 3.0], [1.13, 3.0], [0.42, 3.9], [1.13, 3.9], [0.78, 4.3]]:
				_bx(k, m, Vector3(0.05, 0.05, 0.08), Vector3(s * (xw.call(q[1]) + 0.04), q[1], q[0]), "gunmetal_w", null, Vector3.ZERO, false)
			_bx(k, m, Vector3(0.05, 0.04, 0.16), Vector3(s * (xw.call(3.4) + 0.05), 3.4, 1.05), "gunmetal_w", null, Vector3.ZERO, false)
		for z in [2.1, 2.9]:
			var px: float = xw.call(3.85)
			k._add(m, _torus(0.1, 0.15), "gunmetal_w", null, Vector3(s * (px + 0.01), 3.85, z), Vector3(0, 0, PI / 2))
			k._cyl(m, 0.11, 0.11, 0.02, Vector3(s * px, 3.85, z), Vector3(0, 0, PI / 2), "glass", Color(0.12, 0.15, 0.18), 12, false)
		# a life ring, a fire-hose box, the team panel
		_lifering(k, m, Vector3(s * (xw.call(3.6) + 0.07), 3.6, 3.65), Vector3(s, 0, 0))
		_bx(k, m, Vector3(0.12, 0.5, 0.36), Vector3(s * (xw.call(3.2) + 0.05), 3.2, -0.15), "paint", Color(0.55, 0.12, 0.09))
		k._team_mark(m, team, Vector3(s * (xw.call(3.85) + 0.015), 3.85, 0.0 + 1.55), Vector3(0.012, 0.22, 0.5))
		# navigation sidelights on the pilothouse shoulders, red to port
		_bx(k, m, Vector3(0.08, 0.14, 0.3), Vector3(s * 1.93, y2 + 0.2, -2.9), "paint", Color(0.08, 0.42, 0.16) if s > 0 else Color(0.6, 0.08, 0.06), Vector3.ZERO, false)
		_bx(k, m, Vector3(0.02, 0.22, 0.42), Vector3(s * 1.87, y2 + 0.2, -2.85), "plain", sup, Vector3.ZERO, false)
	for i in 8:
		var y := 2.95 + i * 0.3
		_rod(k, m, Vector3(0.95, y, 4.64 - (y - y0) * 0.06), Vector3(1.4, y, 4.64 - (y - y0) * 0.06), 0.016, "gunmetal_w")
	for sx in [0.95, 1.4]:
		_rod(k, m, Vector3(sx, _dk(p, 4.6), 4.56), Vector3(sx, ya + 0.9, 4.38), 0.022, "gunmetal_w", null, 6, true)
	# --- the after house's roof: rails round it, four liferafts tipped
	# outboard, the satcom dome, HVAC boxes, whips at the corners
	_bx(k, m, Vector3(3.8, 0.012, 4.7), Vector3(0, ya + 0.006, 1.85), "plain", dkc, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		var rp := [Vector3(s * 1.9, ya, -0.3), Vector3(s * 1.9, ya, 3.85), Vector3(s * 1.66, ya, 4.3)]
		for q in rp:
			_rod(k, m, q, q + Vector3(0, 0.9, 0), 0.02, "gunmetal_w")
		for i in rp.size() - 1:
			for hh in [0.45, 0.9]:
				_rod(k, m, (rp[i] as Vector3) + Vector3(0, hh, 0), (rp[i + 1] as Vector3) + Vector3(0, hh, 0), 0.016, "gunmetal_w")
		for z in [0.55, 2.0]:
			_liferaft(k, m, Vector3(s * 1.3, ya + 0.02, z), -s * 0.22, grey.darkened(0.1))
		_whip(k, m, Vector3(s * 1.55, ya, 3.95), 4.6)
	for hh in [0.45, 0.9]:
		_rod(k, m, Vector3(-1.66, ya + hh, 4.3), Vector3(-0.95, ya + hh, 4.3), 0.016, "gunmetal_w")
	k._cyl(m, 0.2, 0.24, 0.35, Vector3(0, ya + 0.18, 3.2), Vector3.ZERO, "plain", sup, 12)
	k._add(m, Res.sphere(0.45, 14), "plain", Color(0.86, 0.86, 0.83), Vector3(0, ya + 0.72, 3.2))
	_bx(k, m, Vector3(0.9, 0.42, 0.7), Vector3(0, ya + 0.21, 1.3), "plain", sup.darkened(0.04))
	for i in 5:
		_bx(k, m, Vector3(0.8, 0.015, 0.03), Vector3(0, ya + 0.08 + i * 0.07, 0.94), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, m, Vector3(0.6, 0.3, 0.5), Vector3(0.3, ya + 0.15, 0.2), "plain", sup.darkened(0.04))
	# --- the pilothouse roof: the raked mast with the radar, searchlights, the
	# EO ball, the horn, whips
	k._add(m, VehicleModels.loft("ship_pb_mast", VmBoat._rr(0.62, 1.1, -1.35, 0.14, 0.22), VmBoat._rr(0.26, 0.4, -1.12, 0.05, 0.08), y2 + 0.08, 7.45), "plain", sup, Vector3.ZERO)
	_bx(k, m, Vector3(1.0, 0.06, 0.9), Vector3(0, 6.55, -1.55), "plain", sup)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.45, 6.55, -1.95), Vector3(s * 0.28, 6.05, -1.5), 0.025, "plain", sup, 6, true)
	_bx(k, m, Vector3(0.36, 0.3, 0.44), Vector3(0, 6.73, -1.65), "paint", Color(0.82, 0.82, 0.79))
	k._cyl(m, 0.06, 0.06, 0.16, Vector3(0, 6.95, -1.65), Vector3.ZERO, "gunmetal_w", null, 8)
	_bx(k, m, Vector3(2.1, 0.2, 0.14), Vector3(0, 7.1, -1.65), "plain", Color(0.84, 0.84, 0.81), Vector3(0, 0.45, 0))
	k._add(m, Res.sphere(0.28, 10), "plain", Color(0.84, 0.84, 0.81), Vector3(0, 6.3, -0.55), Vector3.ZERO, Vector3(1, 0.9, 1))
	_bx(k, m, Vector3(0.2, 0.06, 0.4), Vector3(0, 6.15, -0.75), "plain", sup)
	# the topmast, the yardarm with its lights and halyards, the masthead light
	_rod(k, m, Vector3(0, 7.4, -1.12), Vector3(0, 8.75, -1.05), 0.045, "plain", sup, 8, true)
	_rod(k, m, Vector3(-0.95, 7.95, -1.1), Vector3(0.95, 7.95, -1.1), 0.035, "plain", sup, 6, true)
	for s in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.06, 0.08, 0.06), Vector3(s * 0.9, 7.9, -1.1), "plain", Color(0.9, 0.9, 0.86), Vector3.ZERO, false)
		_rod(k, m, Vector3(s * 0.9, 7.95, -1.1), Vector3(s * 1.7, y2 + 0.1, -0.55), 0.006, "plain_dark", Color(0.1, 0.1, 0.1), 3)
	k._add(m, Res.sphere(0.06, 8), "plain", Color(0.92, 0.92, 0.88), Vector3(0, 8.8, -1.05))
	_rod(k, m, Vector3(0.08, 8.5, -1.06), Vector3(0.08, 9.6, -1.0), 0.012, "gunmetal_w", null, 4)
	_bx(k, m, Vector3(0.1, 0.08, 0.12), Vector3(0, 7.65, -1.32), "plain", Color(0.9, 0.9, 0.86), Vector3.ZERO, false)
	k._cyl(m, 0.05, 0.11, 0.24, Vector3(0.22, 7.2, -1.3), Vector3(PI / 2, 0, 0), "plain", sup, 10, false)
	for s in [-1.0, 1.0]:
		_searchlight(k, m, Vector3(s * 1.15, y2 + 0.1, -3.3), s * 0.3, sup)
		_whip(k, m, Vector3(s * 1.55, y2 + 0.1, -0.7), 4.0)
	k._cyl(m, 0.08, 0.1, 0.3, Vector3(0, y2 + 0.25, -3.45), Vector3.ZERO, "plain", sup, 10)
	k._add(m, Res.sphere(0.2, 10), "plain", sup, Vector3(0, y2 + 0.55, -3.45))
	k._cyl(m, 0.09, 0.09, 0.02, Vector3(0, y2 + 0.57, -3.64), Vector3(PI / 2, 0, 0), "glass", null, 12, false)
	# --- the foredeck: the forward Mk 38 (the turret), its ready-use lockers,
	# a hatch, the windlass, bitts, the jackstaff and the anchor on its roller
	var gz := -7.9
	k.turret = _mk38(k, m, Vector3(0, _dk(p, gz), gz), grey)
	k.mg_tip = k._tip(k.turret, Vector3(0, 0.58, -2.66))
	for s in [-1.0, 1.0]:
		var lz := -6.05
		_bx(k, m, Vector3(0.72, 0.55, 0.5), Vector3(s * 0.95, _dk(p, lz) + 0.28, lz), "plain", grey)
		_bx(k, m, Vector3(0.74, 0.03, 0.52), Vector3(s * 0.95, _dk(p, lz) + 0.56, lz), "plain", grey.darkened(0.08))
		_bx(k, m, Vector3(0.2, 0.04, 0.03), Vector3(s * 0.95, _dk(p, lz) + 0.4, lz - 0.26), "gunmetal_w", null, Vector3.ZERO, false)
		_bitts(k, m, Vector3(s * 0.95, _dk(p, -10.1), -10.1), 0.0, 1.0, "plain", grey.darkened(0.15))
		_bitts(k, m, Vector3(s * 2.45, _dk(p, -3.2), -3.2), 0.0, 1.0, "plain", grey.darkened(0.15))
		_bitts(k, m, Vector3(s * 2.35, _dk(p, 10.9), 10.9), 0.0, 1.0, "plain", grey.darkened(0.15))
		_coil(k, m, Vector3(s * 1.75, _dk(p, 10.3), 10.3), 0.3, Color(0.75, 0.73, 0.66))
		# fairleads through the bulwark by the bow bitts
		var fz := -10.5
		var fst := _at(p, fz)
		_bx(k, m, Vector3(0.16, 0.12, 0.42), Vector3(s * (VmBoat._hw(fst[1], fst[3]) - 0.03), float(fst[3]) + 0.04, fz), "gunmetal_w")
	_bx(k, m, Vector3(1.0, 0.03, 0.8), Vector3(0, _dk(p, -5.2) + 0.03, -5.2), "plain", grey.darkened(0.08))
	for q in [[-0.45, -5.55], [0.45, -5.55], [-0.45, -4.85], [0.45, -4.85]]:
		_bx(k, m, Vector3(0.06, 0.05, 0.08), Vector3(q[0], _dk(p, q[1]) + 0.06, q[1]), "gunmetal_w", null, Vector3.ZERO, false)
	_vent(k, m, Vector3(1.05, _dk(p, -5.2), -5.2), "plain", grey)
	_vent(k, m, Vector3(-1.05, _dk(p, -5.2), -5.2), "plain", grey)
	var wz := -10.9
	var wy := _dk(p, wz)
	_bx(k, m, Vector3(0.55, 0.36, 0.5), Vector3(0.25, wy + 0.18, wz), "plain", grey.darkened(0.05))
	k._cyl(m, 0.17, 0.17, 0.3, Vector3(-0.2, wy + 0.24, wz), Vector3(0, 0, PI / 2), "gunmetal_w", null, 12)
	k._cyl(m, 0.21, 0.21, 0.04, Vector3(-0.37, wy + 0.24, wz), Vector3(0, 0, PI / 2), "gunmetal_w", null, 12, false)
	for i in 7:
		k._add(m, _torus(0.025, 0.06), "gunmetal_w", null, Vector3(-0.2, wy + 0.04, wz - 0.2 - i * 0.11), Vector3(0, 0, PI / 2 * (i % 2)), Vector3.ONE, false)
	var hy := float(_at(p, zs + 0.35)[3])
	_rod(k, m, Vector3(0, hy, zs + 0.45), Vector3(0, hy + 1.5, zs + 0.5), 0.03, "plain", sup, 6, true)
	k._add(m, Res.sphere(0.05, 8), "plain", sup, Vector3(0, hy + 1.53, zs + 0.5))
	_bx(k, m, Vector3(0.24, 0.16, 0.7), Vector3(0, hy - 0.02, zs + 0.05), "gunmetal_w")
	k._cyl(m, 0.07, 0.07, 0.26, Vector3(0, hy + 0.06, zs - 0.22), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	# the anchor: shank up on the roller, its flukes against the stem
	var ay := hy - 1.0
	var az0 := _stem_z(p, ay) - 0.14
	_rod(k, m, Vector3(0, hy + 0.06, zs - 0.22), Vector3(0, ay, az0), 0.04, "gunmetal_w", null, 6, true)
	var fa := atan2(az0 - (zs - 0.22), hy + 0.06 - ay)
	for sx in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.22, 0.34, 0.04), Vector3(sx * 0.13, ay + 0.04, az0 + 0.06), "gunmetal_w", null, Vector3(fa, sx * 0.45, 0))
	# --- lifelines from the bulwark's end aft round the stern, a gate at the transom
	for s in [-1.0, 1.0]:
		var rp := []
		var z := -6.2
		while z < zt - 0.2:
			var st := _at(p, z)
			var d: float = st[2]
			var foot := maxf(d, float(st[3]))
			rp.append([Vector3(s * (VmBoat._hw(st[1], foot) - 0.06), foot, z), d + 1.0])
			z += 1.35
		var se := _at(p, zt - 0.12)
		rp.append([Vector3(s * (VmBoat._hw(se[1], se[2]) - 0.1), float(se[2]), zt - 0.12), float(se[2]) + 1.0])
		rp.append([Vector3(s * 0.55, float(se[2]), zt - 0.12), float(se[2]) + 1.0])
		for i in rp.size():
			var q: Vector3 = rp[i][0]
			var ty: float = rp[i][1]
			_rod(k, m, q, Vector3(q.x, ty, q.z), 0.022, "steel", STAINLESS, 6, true)
			if i > 0:
				var q0: Vector3 = rp[i - 1][0]
				var t0: float = rp[i - 1][1]
				_rod(k, m, Vector3(q0.x, t0, q0.z), Vector3(q.x, ty, q.z), 0.016, "steel", STAINLESS)
				_rod(k, m, Vector3(q0.x, maxf(t0 - 0.48, q0.y + 0.05), q0.z), Vector3(q.x, maxf(ty - 0.48, q.y + 0.05), q.z), 0.008, "steel", STAINLESS, 4)
	# --- side decks: .50 cals on pedestals beside the pilothouse and aft
	for s in [-1.0, 1.0]:
		for z in [-0.15, 5.7]:
			var st := _at(p, z)
			var x := VmBoat._hw(st[1], st[2]) - 0.42
			_m2(k, m, Vector3(s * x, st[2], z), -s * (PI / 2 - 0.35) if z < 0 else -s * (PI / 2 + 0.35))
	# --- the after deck: the second Mk 38 trained aft, its lockers, hatches,
	# vents, fenders, the ensign staff, the waterjets on the transom
	var az := 8.7
	var g2 := _mk38(k, m, Vector3(0, _dk(p, az), az), grey)
	g2.rotation.y = PI - 0.35
	VmBoat._bake(g2)
	for s in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.66, 0.5, 0.46), Vector3(s * 1.4, _dk(p, 7.0) + 0.25, 7.0), "plain", grey)
		_bx(k, m, Vector3(0.68, 0.03, 0.48), Vector3(s * 1.4, _dk(p, 7.0) + 0.51, 7.0), "plain", grey.darkened(0.08))
		_vent(k, m, Vector3(s * 2.1, _dk(p, 6.6), 6.6), "plain", grey)
		k._add(m, Res.capsule(0.13, 0.75, 10), "plain", Color(0.2, 0.25, 0.33), Vector3(s * 2.2, _dk(p, 8.2) + 0.13, 8.2), Vector3(PI / 2, 0, 0))
	_bx(k, m, Vector3(1.3, 0.03, 1.1), Vector3(0, _dk(p, 6.4) + 0.03, 6.4), "plain", grey.darkened(0.08))
	for q in [[-0.6, 5.9], [0.6, 5.9], [-0.6, 6.9], [0.6, 6.9]]:
		_bx(k, m, Vector3(0.06, 0.05, 0.08), Vector3(q[0], _dk(p, q[1]) + 0.06, q[1]), "gunmetal_w", null, Vector3.ZERO, false)
	var sy := _dk(p, zt)
	_rod(k, m, Vector3(0, sy, zt - 0.3), Vector3(0, sy + 3.2, zt + 0.05), 0.03, "plain", sup, 6, true)
	_flag(k, m, Vector3(0, sy + 3.12, zt + 0.06), team, 1.2, 0.72)
	k._add(m, Res.sphere(0.05, 8), "plain", Color(0.92, 0.92, 0.88), Vector3(0, sy + 1.08, zt - 0.12))
	for s in [-1.0, 1.0]:
		var x: float = s * 0.95
		k._cyl(m, 0.22, 0.26, 0.42, Vector3(x, 0.62, zt + 0.2), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 14)
		k._cyl(m, 0.16, 0.2, 0.22, Vector3(x, 0.62, zt + 0.5), Vector3(PI / 2, 0, 0), "metal_dark", null, 14)
		_bx(k, m, Vector3(0.48, 0.34, 0.05), Vector3(x, 0.84, zt + 0.7), "gunmetal_w", null, Vector3(-0.35, 0, 0))
		for dx in [-0.25, 0.25]:
			_bx(k, m, Vector3(0.04, 0.06, 0.48), Vector3(x + dx, 0.84, zt + 0.48), "gunmetal_w", null, Vector3(0.2, 0, 0), false)
		_rod(k, m, Vector3(x + s * 0.32, 1.0, zt + 0.03), Vector3(x + s * 0.24, 0.75, zt + 0.5), 0.03, "steel", null, 6)
		# the stern light and the stern's exhaust pipes
		for dy in [0.0, 0.22]:
			k._cyl(m, 0.08, 0.08, 0.12, Vector3(s * 2.0, 1.75 + dy, zt + 0.05), Vector3(PI / 2, 0, 0), "plain_dark", Color(0.08, 0.08, 0.08), 10, false)


# --- the armed trawler ---------------------------------------------------------------------

## The Rebels' gun trawler: a converted 18 m steel fishing boat with a high,
## raked bow and a round bilge, bulwarks all round, the deckhouse and its
## wheelhouse (windows leaning out) aft of amidships, a mast with a derrick,
## the trawl winch, a stern gantry with the trawl doors hanging off it, a net
## drum, nets and floats; rust streaking from every scupper and hawse. A
## ZU-23-2 welded on the foredeck (the turret), a DShK on the wheelhouse roof.
static func _gun_trawler(k: VehicleModels, team: int, seed: int) -> void:
	var m := k.root
	var p := TR
	var blue := Color(0.22, 0.34, 0.45).lerp(Color(0.45, 0.47, 0.46), 0.25)  # faded
	var white := Color(0.74, 0.73, 0.68)
	var deckc := Color(0.3, 0.35, 0.28)
	var rust := RUST
	var zt: float = p["z0"]
	var zs: float = zt - float(p["len"])
	_hull_bands(k, m, p, "ship_tr", ["paint", Color(0.42, 0.17, 0.11), "paint", Color(0.14, 0.13, 0.12), "steel", blue], "plain", white, 0.06)
	var all := _hull(p)
	k._add(m, _deck_mesh("ship_tr_deck", all, 0.07, 0.012), "steel", deckc, Vector3.ZERO)
	# the transom's bulwark across the stern
	var tst := _station(p, 0.0)
	var tw := VmBoat._hw(tst[1], tst[2])
	_bx(k, m, Vector3(tw * 2.0 - 0.06, float(tst[3]) - float(tst[2]), 0.07), Vector3(0, (float(tst[2]) + float(tst[3])) * 0.5, zt - 0.035), "plain", white)
	# the keel bar and the stem bar running up the bow
	var kp := []
	var kd := []
	var z := zt - 1.1
	while z > zt - float(p["fore"]) * float(p["len"]):
		kp.append(Vector3(0, float(p["ky0"]) * 0.5, z))
		kd.append(float(p["ky0"]) * 0.5)
		z -= 1.6
	var su := [float(p["fore"]), 0.76, 0.8, 0.84, 0.88, 0.92, 0.95, 0.975, 0.99, 1.0]
	var sl := []
	for u in su:
		sl.append(Vector3(0, _keel_y(p, u), zt - float(u) * float(p["len"])))
	for i in su.size():
		var tng := ((sl[mini(i + 1, su.size() - 1)] as Vector3) - (sl[maxi(i - 1, 0)] as Vector3)).normalized()
		var nrm := Vector3(0, tng.z, -tng.y)  # forward and down, off the stem
		if nrm.y > 0.0:
			nrm = -nrm
		var d := lerpf(float(p["ky0"]) * 0.5, 0.07, smoothstep(float(p["fore"]), 0.9, su[i]))
		kp.append((sl[i] as Vector3) + nrm * (d - 0.02))
		kd.append(d)
	k._add(m, _sweep("ship_tr_keel", kp, 0.09, kd), "steel", Color(0.28, 0.13, 0.09), Vector3.ZERO)
	# the skeg under the run, the propeller in its aperture, the rudder
	var zp := zt - 1.05
	k._add(m, VehicleModels.extrude_x("ship_tr_skeg", [3.0, 0.0, zp, 0.0, zp, _keel_y(p, _u(p, zp)) + 0.25, 3.0, 0.6], -0.09, 0.09), "paint", Color(0.42, 0.17, 0.11), Vector3.ZERO)
	_bx(k, m, Vector3(0.16, 0.12, 1.25), Vector3(0, 0.06, zp + 0.6), "steel", Color(0.28, 0.13, 0.09))
	k._cyl(m, 0.1, 0.13, 0.25, Vector3(0, 0.74, zp + 0.1), Vector3(PI / 2, 0, 0), "steel", Color(0.4, 0.3, 0.15), 10)
	VmBoat._prop(k, m, Vector3(0, 0.74, zp + 0.35), 0.5, 4, "steel", Color(0.55, 0.42, 0.22))
	_bx(k, m, Vector3(0.08, 1.45, 0.75), Vector3(0, 0.88, zp + 1.0), "paint", Color(0.42, 0.17, 0.11))
	k._cyl(m, 0.06, 0.06, 0.6, Vector3(0, 1.75, zp + 0.95), Vector3.ZERO, "steel", null, 8)
	# rubbing bands, bilge keels, the bulwark capping
	for s in [-1.0, 1.0]:
		var rub := []
		var cap := []
		var bk := []
		for st in all:
			var d: float = st[2]
			rub.append(Vector3(s * (VmBoat._hw(st[1], d - 0.05) + 0.045), d - 0.05, st[0]))
			cap.append(Vector3(s * (VmBoat._hw(st[1], st[3]) - 0.03), float(st[3]) + 0.02, st[0]))
		for st in _hull(p, 0.25, 0.68):
			var kq: Vector2 = st[6]
			var cq: Vector2 = st[5]
			var y := lerpf(kq.y, cq.y, 0.3)
			bk.append(Vector3(s * (VmBoat._hw(st[1], y) + 0.06), y, st[0]))
		k._add(m, VmBoat._strip("ship_tr_rub%d" % int(s), rub, 0.06, 0.08), "steel", Color(0.15, 0.14, 0.13), Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_tr_cap%d" % int(s), cap, 0.07, 0.025), "wood_dark", null, Vector3.ZERO)
		k._add(m, VmBoat._strip("ship_tr_bk%d" % int(s), bk, 0.09, 0.02), "paint", Color(0.42, 0.17, 0.11), Vector3.ZERO)
	# freeing ports in the bulwarks with rust running from them, rust and
	# primer patches, a replaced plate, the registration on the bows
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111 + seed
	for s in [-1.0, 1.0]:
		for i in 6:
			var fz := -3.6 + i * 1.75
			var fy := _dk(p, fz) + 0.14
			_decal(k, m, p, s, fz, fy, 0.5, 0.22, "plain_dark", Color(0.04, 0.04, 0.04))
			_decal(k, m, p, s, fz + rng.randf_range(-0.12, 0.12), fy - 0.55, 0.07 + rng.randf() * 0.06, 0.8 + rng.randf() * 0.5, "paint", rust.lerp(blue, 0.25), 0.004)
		for i in 14:
			var rz := rng.randf_range(-6.5, 7.5)
			var ry := rng.randf_range(2.2, _dk(p, rz) + 0.6)
			_decal(k, m, p, s, rz, ry, rng.randf_range(0.05, 0.12), rng.randf_range(0.4, 1.1), "paint", rust.lerp(Color(0.25, 0.2, 0.17), rng.randf() * 0.4), 0.004)
		for i in 2:
			var rz := rng.randf_range(-5.0, 6.5)
			_decal(k, m, p, s, rz, _dk(p, rz) + rng.randf_range(0.3, 0.8), rng.randf_range(0.3, 0.9), rng.randf_range(0.2, 0.45), "steel", rust, 0.005, rng.randf_range(-0.2, 0.2))
		_decal(k, m, p, s, 1.6 * s, 2.6, 1.5, 0.75, "steel", Color(0.48, 0.48, 0.46) if s > 0 else Color(0.45, 0.2, 0.13), 0.008)
		_decal(k, m, p, s, -1.4, _dk(p, -1.4) + 0.55, 1.1, 0.7, "steel", Color(0.56, 0.55, 0.52), 0.008)
		_digits(k, m, p, s, str(140 + seed % 60), -5.3, _dk(p, -5.3) - 0.42, 0.5, Color(0.85, 0.84, 0.78))
		# the hawse pipe with the anchor in it and rust bleeding down
		var hz := zs + 1.6
		var tf := _surf(p, s, hz, _dk(p, hz) - 0.45)
		k._add(m, _torus(0.12, 0.2), "steel", Color(0.25, 0.22, 0.2), tf.origin + tf.basis.z * 0.03, (tf.basis * Basis(Vector3.RIGHT, PI / 2)).get_euler())
		_bx(k, m, Vector3(0.14, 0.75, 0.08), tf.origin + tf.basis.z * 0.06 - tf.basis.y * 0.42, "steel", Color(0.2, 0.19, 0.18), tf.basis.get_euler())
		_bx(k, m, Vector3(0.6, 0.12, 0.1), tf.origin + tf.basis.z * 0.08 - tf.basis.y * 0.82, "steel", Color(0.2, 0.19, 0.18), tf.basis.get_euler())
		for sx in [-1.0, 1.0]:
			_bx(k, m, Vector3(0.12, 0.38, 0.1), tf.origin + tf.basis.z * 0.09 - tf.basis.y * 0.68 + tf.basis.x * sx * 0.27, "steel", Color(0.2, 0.19, 0.18), (tf.basis * Basis(Vector3(0, 0, 1), sx * 0.3)).get_euler())
		_decal(k, m, p, s, hz + 0.15, _dk(p, hz) - 1.6, 0.16, 1.2, "paint", rust, 0.004)
		# tyres hung over the side as fenders
		for tz in [-3.2, -0.4, 2.3, 5.0, 7.2]:
			var ty := _dk(p, tz) - 0.25
			var t2 := _surf(p, s, tz, ty)
			k._add(m, _torus(0.2, 0.36), "rubber", Color(0.08, 0.08, 0.08), t2.origin + t2.basis.z * 0.15, (t2.basis * Basis(Vector3.RIGHT, PI / 2)).get_euler(), Vector3(1, 1.3, 1))
			var bt := _at(p, tz)
			_rod(k, m, t2.origin + t2.basis.z * 0.15 + Vector3(0, 0.3, 0), Vector3(s * VmBoat._hw(bt[1], bt[3]), float(bt[3]) + 0.03, tz), 0.014, "canvas", Color(0.5, 0.45, 0.35), 4)
	# --- the deckhouse, white and streaked, and the wheelhouse on it
	var hb := 2.7
	var hr := 4.85
	var dh := [-1.7, -0.35, 1.7, -0.35, 1.92, 0.15, 1.92, 4.2, 1.78, 4.6, -1.78, 4.6, -1.92, 4.2, -1.92, 0.15]
	k._add(m, VehicleModels.solid([VmBoat._ry(dh, hb), VmBoat._ry(dh, hr)], "ship_tr_house"), "plain", white, Vector3.ZERO)
	k._add(m, VehicleModels.solid([VmBoat._ry(VmBoat._scale_xz(dh, 1.035, 2.1), hr - 0.03), VmBoat._ry(VmBoat._scale_xz(dh, 1.035, 2.1), hr + 0.08)], "ship_tr_house_roof"), "plain", white.darkened(0.08), Vector3.ZERO)
	var wb := [-1.38, 0.18, 1.38, 0.18, 1.55, 0.5, 1.55, 3.2, -1.55, 3.2, -1.55, 0.5]
	var ws := [-1.4, 0.06, 1.4, 0.06, 1.56, 0.4, 1.56, 3.2, -1.56, 3.2, -1.56, 0.4]
	var wr := [-1.46, -0.2, 1.46, -0.2, 1.6, 0.18, 1.6, 3.2, -1.6, 3.2, -1.6, 0.18]
	var wy0 := hr + 0.08
	var wy1 := wy0 + 0.95
	var wy2 := wy1 + 0.95
	k._add(m, VehicleModels.solid([VmBoat._ry(wb, wy0), VmBoat._ry(ws, wy1), VmBoat._ry(wr, wy2)], "ship_tr_wheel"), "plain", white.lightened(0.03), Vector3.ZERO)
	var wroof := VmBoat._scale_xz(wr, 1.06, 1.5)
	k._add(m, VehicleModels.solid([VmBoat._ry(wroof, wy2 - 0.02), VmBoat._ry(wroof, wy2 + 0.1)], "ship_tr_wroof"), "plain", blue.lightened(0.05), Vector3.ZERO)
	var win := Vector3(0, wy1, 1.6)
	for f in [[0, 1, 4], [1, 2, 1], [5, 0, 1], [2, 3, 3], [4, 5, 3], [3, 4, 2]]:
		var a: int = f[0]
		var b: int = f[1]
		var np: int = f[2]
		var p0 := VmBoat._pt(ws, a, wy1 + 0.04)
		var p1 := VmBoat._pt(ws, b, wy1 + 0.04)
		var q1 := VmBoat._pt(wr, b, wy2 - 0.1)
		var q0 := VmBoat._pt(wr, a, wy2 - 0.1)
		VmBoat._panel(k, m, p0, p1, q1, q0, win, 0.02, 0.02, "paint", blue.darkened(0.2), 0.0)
		for i in np:
			var ta := (i + 0.07) / np
			var tb := (i + 0.93) / np
			VmBoat._panel(k, m, p0.lerp(p1, ta), p0.lerp(p1, tb), q0.lerp(q1, tb), q0.lerp(q1, ta), win, 0.05, 0.03, "glass", Color(0.12, 0.14, 0.15), 0.0)
	# the deckhouse: a door and portholes each side, rust under them, a ladder
	# up the back to the boat deck, handrails round the roof
	for s in [-1.0, 1.0]:
		var dz := 1.0
		_bx(k, m, Vector3(0.05, 1.75, 0.78), Vector3(s * 1.935, _dk(p, dz) + 0.92, dz), "plain", white.darkened(0.15))
		_bx(k, m, Vector3(0.05, 0.05, 0.16), Vector3(s * 1.97, _dk(p, dz) + 0.95, dz + 0.28), "gunmetal_w", null, Vector3.ZERO, false)
		for z2 in [2.3, 3.2, 4.0]:
			k._add(m, _torus(0.12, 0.17), "steel", Color(0.5, 0.42, 0.25), Vector3(s * 1.93, 3.9, z2), Vector3(0, 0, PI / 2))
			k._cyl(m, 0.125, 0.125, 0.02, Vector3(s * 1.925, 3.9, z2), Vector3(0, 0, PI / 2), "glass", Color(0.1, 0.12, 0.12), 12, false)
			_bx(k, m, Vector3(0.008, 0.6 + rng.randf() * 0.4, 0.05), Vector3(s * 1.925, 3.35 - rng.randf() * 0.1, z2 + rng.randf_range(-0.05, 0.05)), "paint", rust, Vector3.ZERO, false)
		for i in 5:
			var rz := rng.randf_range(0.2, 4.4)
			_bx(k, m, Vector3(0.008, rng.randf_range(0.3, 0.9), rng.randf_range(0.04, 0.1)), Vector3(s * 1.925, hr - 0.45 - rng.randf() * 0.3, rz), "paint", rust.lerp(white, 0.3), Vector3.ZERO, false)
		# sidelights in their screens on the wheelhouse's shoulders
		_bx(k, m, Vector3(0.24, 0.3, 0.5), Vector3(s * 1.72, wy1 + 0.25, 0.75), "steel", blue.darkened(0.2))
		_bx(k, m, Vector3(0.08, 0.14, 0.18), Vector3(s * 1.86, wy1 + 0.25, 0.7), "paint", Color(0.08, 0.42, 0.16) if s > 0 else Color(0.6, 0.08, 0.06), Vector3.ZERO, false)
		_lifering(k, m, Vector3(s * 1.6, wy1 - 0.15, 2.4), Vector3(s, 0, 0))
		var rr := [Vector3(s * 1.85, hr + 0.08, 0.25), Vector3(s * 1.85, hr + 0.08, 4.15), Vector3(s * 1.0, hr + 0.08, 4.5)]
		for q in rr:
			_rod(k, m, q, q + Vector3(0, 0.85, 0), 0.02, "plain", white.darkened(0.1))
		for i in rr.size() - 1:
			_rod(k, m, (rr[i] as Vector3) + Vector3(0, 0.85, 0), (rr[i + 1] as Vector3) + Vector3(0, 0.85, 0), 0.02, "plain", white.darkened(0.1))
			_rod(k, m, (rr[i] as Vector3) + Vector3(0, 0.45, 0), (rr[i + 1] as Vector3) + Vector3(0, 0.45, 0), 0.014, "plain", white.darkened(0.1))
	for i in 7:
		var y := 3.05 + i * 0.28
		_rod(k, m, Vector3(-1.3, y, 4.68), Vector3(-0.85, y, 4.68), 0.016, "steel", null)
	for sx in [-1.3, -0.85]:
		_rod(k, m, Vector3(sx, _dk(p, 4.7), 4.7), Vector3(sx, hr + 0.95, 4.65), 0.022, "steel", null, 6, true)
	# the funnel (black-topped, sooty), a liferaft canister, a boat-deck locker
	k._cyl(m, 0.3, 0.33, 2.3, Vector3(0.95, hr + 1.2, 4.0), Vector3.ZERO, "plain", white.darkened(0.05), 14)
	k._cyl(m, 0.31, 0.31, 0.45, Vector3(0.95, hr + 2.15, 4.0), Vector3.ZERO, "plain_dark", Color(0.08, 0.08, 0.08), 14)
	k._cyl(m, 0.12, 0.12, 0.35, Vector3(0.95, hr + 2.5, 4.0), Vector3.ZERO, "plain_dark", Color(0.06, 0.06, 0.06), 10)
	_bx(k, m, Vector3(0.012, 0.9, 0.2), Vector3(0.95 + 0.3, hr + 1.6, 4.0), "plain_dark", Color(0.1, 0.09, 0.08), Vector3(0, 0, 0.0), false)
	_liferaft(k, m, Vector3(-0.85, hr + 0.08, 3.9), 0.18, rust.lerp(white, 0.4))
	_bx(k, m, Vector3(0.8, 0.5, 0.5), Vector3(0.2, hr + 0.33, 3.55), "plain", white.darkened(0.12))
	# --- the wheelhouse roof: the DShK, radar mast with its scanner, a
	# searchlight, horn, whips, a loudhailer
	_dshk(k, m, Vector3(0.45, wy2 + 0.1, 0.55), -0.25)
	k._cyl(m, 0.06, 0.08, 1.4, Vector3(-0.4, wy2 + 0.8, 2.6), Vector3.ZERO, "plain", white, 8)
	_bx(k, m, Vector3(0.26, 0.2, 0.3), Vector3(-0.4, wy2 + 1.6, 2.6), "plain", Color(0.82, 0.82, 0.79))
	_bx(k, m, Vector3(1.3, 0.13, 0.12), Vector3(-0.4, wy2 + 1.78, 2.6), "plain", Color(0.84, 0.84, 0.8), Vector3(0, -0.6, 0))
	_rod(k, m, Vector3(-0.4, wy2 + 1.5, 2.65), Vector3(-0.4, wy2 + 2.6, 2.75), 0.02, "steel", null)
	k._add(m, Res.sphere(0.05, 8), "plain", Color(0.9, 0.9, 0.86), Vector3(-0.4, wy2 + 2.64, 2.75))
	_flag(k, m, Vector3(-0.4, wy2 + 2.5, 2.76), team, 0.9, 0.55)
	_searchlight(k, m, Vector3(-1.15, wy2 + 0.1, 0.0), -0.3, Color(0.3, 0.32, 0.3))
	k._cyl(m, 0.05, 0.13, 0.3, Vector3(1.1, wy2 + 0.25, 0.1), Vector3(PI / 2, 0, 0), "plain", Color(0.8, 0.8, 0.76), 10)
	_whip(k, m, Vector3(1.3, wy2 + 0.1, 2.9), 3.2)
	_whip(k, m, Vector3(-1.3, wy2 + 0.1, 3.0), 2.6)
	# --- the mast and its derrick, the trawl winch, the fish hold hatch
	var mz := -2.05
	var my := _dk(p, mz)
	k._cyl(m, 0.08, 0.14, 8.0, Vector3(0, my + 4.0, mz), Vector3.ZERO, "plain", white, 10)
	_rod(k, m, Vector3(-0.9, my + 6.2, mz), Vector3(0.9, my + 6.2, mz), 0.04, "plain", white, 6, true)
	for s in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.1, 0.14, 0.1), Vector3(s * 0.85, my + 6.1, mz), "plain", Color(0.88, 0.86, 0.8), Vector3.ZERO, false)
		# shrouds down to the bulwark
		var bst := _at(p, mz + 0.4)
		_rod(k, m, Vector3(0, my + 6.0, mz), Vector3(s * (VmBoat._hw(bst[1], bst[3]) - 0.05), float(bst[3]), mz + 0.4), 0.01, "steel", Color(0.25, 0.24, 0.22), 4)
	k._add(m, Res.sphere(0.07, 8), "plain", Color(0.92, 0.9, 0.84), Vector3(0, my + 8.05, mz))
	_bx(k, m, Vector3(0.14, 0.18, 0.12), Vector3(0, my + 5.3, mz - 0.14), "plain", Color(0.9, 0.9, 0.84), Vector3.ZERO, false)
	_rod(k, m, Vector3(0, my + 7.6, mz), Vector3(0, wy2 + 0.1, 0.0), 0.009, "steel", Color(0.25, 0.24, 0.22), 4)
	var heel := Vector3(0, my + 1.6, mz - 0.18)
	var btip := Vector3(0, my + 5.6, mz - 4.1)
	_bx(k, m, Vector3(0.3, 0.2, 0.25), heel, "plain", white.darkened(0.1))
	_rod(k, m, heel, btip, 0.08, "plain", white.darkened(0.06), 8, true)
	_rod(k, m, btip, Vector3(0, my + 7.7, mz), 0.012, "steel", Color(0.25, 0.24, 0.22), 4)
	_rod(k, m, btip, btip + Vector3(0, -1.8, 0), 0.012, "steel", Color(0.25, 0.24, 0.22), 4)
	_bx(k, m, Vector3(0.1, 0.22, 0.14), btip + Vector3(0, -0.15, 0), "steel", Color(0.3, 0.28, 0.25))
	k._add(m, _torus(0.04, 0.09), "steel", Color(0.3, 0.28, 0.25), btip + Vector3(0, -1.9, 0), Vector3(PI / 2, 0, 0))
	var wz := -1.05
	var wy := _dk(p, wz)
	_bx(k, m, Vector3(2.0, 0.12, 0.7), Vector3(0, wy + 0.06, wz), "steel", Color(0.35, 0.33, 0.3))
	for sx in [-0.55, 0.55]:
		k._cyl(m, 0.24, 0.24, 0.6, Vector3(sx, wy + 0.45, wz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.24, 0.23), 14)
		for e in [-0.32, 0.32]:
			k._cyl(m, 0.36, 0.36, 0.04, Vector3(sx + e, wy + 0.45, wz), Vector3(0, 0, PI / 2), "steel", Color(0.4, 0.2, 0.12), 16)
	for sx in [-0.98, 0.98]:
		_bx(k, m, Vector3(0.08, 0.6, 0.5), Vector3(sx, wy + 0.4, wz), "steel", Color(0.4, 0.2, 0.12))
	_bx(k, m, Vector3(0.5, 0.42, 0.45), Vector3(0, wy + 0.33, wz + 0.15), "steel", Color(0.4, 0.2, 0.12))
	var hz2 := -3.25
	_bx(k, m, Vector3(1.4, 0.45, 1.3), Vector3(0, _dk(p, hz2) + 0.22, hz2), "plain", white.darkened(0.1))
	_bx(k, m, Vector3(1.32, 0.06, 1.22), Vector3(0, _dk(p, hz2) + 0.48, hz2), "wood_dark")
	_bx(k, m, Vector3(0.9, 0.04, 0.8), Vector3(0.1, _dk(p, hz2) + 0.52, hz2 + 0.1), "canvas", Color(0.3, 0.34, 0.3), Vector3(0, 0.15, 0))
	# --- the foredeck: the ZU-23-2 on a welded plinth (the turret), ammo
	# crates, sandbags along the bulwark, the windlass and the bow fairlead
	var gz := -5.15
	var gy := _dk(p, gz)
	_bx(k, m, Vector3(2.4, 0.05, 2.4), Vector3(0, gy + 0.025, gz), "steel", Color(0.3, 0.29, 0.26))
	var ph := 0.8
	k._add(m, VehicleModels.loft("ship_tr_plinth", VmBoat._rr(1.6, 1.6, 0.0, 0.32, 0.32), VmBoat._rr(1.3, 1.3, 0.0, 0.26, 0.26), 0.0, ph), "steel", Color(0.33, 0.31, 0.27), Vector3(0, gy + 0.05, gz))
	_bx(k, m, Vector3(1.36, 0.03, 1.36), Vector3(0, gy + 0.05 + ph + 0.015, gz), "steel", Color(0.3, 0.29, 0.26))
	for i in 2:
		_bx(k, m, Vector3(0.6, 0.05, 0.28), Vector3(0.0, gy + 0.3 + i * 0.27, gz + 0.98 - i * 0.12), "steel", Color(0.3, 0.29, 0.26))
	_bx(k, m, Vector3(0.012, 0.6, 0.5), Vector3(0.79, gy + 0.45, gz), "paint", RUST, Vector3(0, 0, -0.06), false)
	k.turret = _zu23(k, m, Vector3(0, gy + 0.08 + ph, gz), Color(0.34, 0.36, 0.28))
	for q in [[1.6, -4.1, 0.3], [1.3, -4.75, -0.2], [-1.55, -4.0, 0.1]]:
		var cz: float = q[1]
		_bx(k, m, Vector3(0.62, 0.3, 0.4), Vector3(q[0], _dk(p, cz) + 0.15, cz), "wood_painted", Color(0.3, 0.33, 0.22), Vector3(0, q[2], 0))
	_bx(k, m, Vector3(0.62, 0.3, 0.4), Vector3(1.6, _dk(p, -4.1) + 0.45, -4.12), "wood_painted", Color(0.28, 0.31, 0.21), Vector3(0, 0.1, 0))
	for s in [-1.0, 1.0]:
		for i in 5:
			var sz := gz - 1.0 + i * 0.5
			var st := _at(p, sz)
			_bx(k, m, Vector3(0.32, 0.16, 0.52), Vector3(s * (VmBoat._hw(st[1], st[3]) - 0.12), float(st[3]) + 0.1, sz), "sandbag", Color(0.6, 0.53, 0.38), Vector3(0, rng.randf_range(-0.15, 0.15), 0))
	var lz := zs + 1.55
	var ly := _dk(p, lz)
	_bx(k, m, Vector3(0.7, 0.4, 0.55), Vector3(0.0, ly + 0.2, lz), "steel", Color(0.4, 0.2, 0.12))
	for sx in [-1.0, 1.0]:
		k._cyl(m, 0.17, 0.17, 0.25, Vector3(sx * 0.5, ly + 0.3, lz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.24, 0.23), 12)
		k._cyl(m, 0.22, 0.22, 0.04, Vector3(sx * 0.65, ly + 0.3, lz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.24, 0.23), 12, false)
	_bitts(k, m, Vector3(0, _dk(p, zs + 2.6), zs + 2.6), PI / 2, 1.0, "steel", Color(0.2, 0.19, 0.18))
	var hy := float(_at(p, zs + 0.3)[3])
	_bx(k, m, Vector3(0.3, 0.2, 0.5), Vector3(0, hy + 0.05, zs + 0.3), "steel", Color(0.2, 0.19, 0.18))
	# --- the after deck: the net drum, the gantry with its blocks, the trawl
	# doors hung outboard, nets piled with floats, fish boxes, a dan buoy
	var nz := 5.85
	var ny := _dk(p, nz) + 0.95
	for sx in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.12, 0.95, 0.5), Vector3(sx * 1.25, ny - 0.47, nz), "steel", Color(0.4, 0.2, 0.12))
		k._cyl(m, 0.8, 0.8, 0.05, Vector3(sx * 1.1, ny, nz), Vector3(0, 0, PI / 2), "steel", Color(0.4, 0.2, 0.12), 20)
	k._cyl(m, 0.3, 0.3, 2.3, Vector3(0, ny, nz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.24, 0.23), 12)
	k._cyl(m, 0.66, 0.66, 2.14, Vector3(0, ny, nz), Vector3(0, 0, PI / 2), "canvas", Color(0.17, 0.25, 0.2), 18)
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		k._add(m, Res.sphere(0.09, 6), "plain", ORANGE if i % 3 != 0 else Color(0.85, 0.75, 0.2), Vector3(-0.85 + i * 0.21, ny + sin(a) * 0.67, nz + cos(a) * 0.67))
	var gy2 := _dk(p, zt - 0.45)
	var gtop := gy2 + 4.2
	for s in [-1.0, 1.0]:
		var foot := Vector3(s * 2.05, gy2 + 1.0, zt - 0.45)
		var head := Vector3(s * 1.75, gtop, zt + 0.15)
		_rod(k, m, foot, head, 0.11, "steel", Color(0.45, 0.22, 0.12), 8, true)
		_rod(k, m, foot + Vector3(0, 0.0, 0.0), Vector3(s * 2.05, gy2, zt - 0.45), 0.13, "steel", Color(0.45, 0.22, 0.12), 8, true)
		_rod(k, m, head + Vector3(0, -0.3, -0.04), Vector3(s * 1.95, gy2 + 1.0, zt - 1.8), 0.06, "steel", Color(0.45, 0.22, 0.12), 6, true)
		# a block hanging from the beam, the warp to it, the trawl door on its chains
		var blk := Vector3(s * 1.2, gtop - 0.4, zt + 0.2)
		_bx(k, m, Vector3(0.14, 0.38, 0.3), blk, "steel", Color(0.3, 0.28, 0.25))
		k._cyl(m, 0.14, 0.14, 0.08, blk, Vector3(0, 0, PI / 2), "steel", Color(0.22, 0.21, 0.2), 12, false)
		var fl := _at(p, 0.0)
		var fair := Vector3(s * (VmBoat._hw(fl[1], fl[3]) - 0.05), float(fl[3]) + 0.06, 0.0)
		_bx(k, m, Vector3(0.14, 0.14, 0.24), fair, "steel", Color(0.3, 0.28, 0.25))
		_rod(k, m, blk, fair, 0.012, "steel", Color(0.2, 0.2, 0.19), 4)
		_rod(k, m, fair, Vector3(s * 0.55, _dk(p, wz) + 0.6, wz), 0.012, "steel", Color(0.2, 0.2, 0.19), 4)
		var dst := _at(p, zt - 1.0)
		var dx := VmBoat._hw(dst[1], float(dst[2]) - 0.3) + 0.14
		var door := Vector3(s * dx, float(dst[2]) - 0.25, zt - 1.0)
		_bx(k, m, Vector3(0.1, 0.85, 1.35), door, "steel", Color(0.2, 0.19, 0.17), Vector3(0, 0, -s * 0.12))
		_bx(k, m, Vector3(0.13, 0.08, 1.38), door + Vector3(0, 0.43, 0), "steel", Color(0.32, 0.3, 0.27), Vector3(0, 0, -s * 0.12))
		_bx(k, m, Vector3(0.13, 0.1, 1.38), door + Vector3(s * 0.05, -0.43, 0), "steel", Color(0.4, 0.38, 0.35), Vector3(0, 0, -s * 0.12))
		for dz in [-0.4, 0.4]:
			_rod(k, m, door + Vector3(s * 0.1, 0.4, dz), Vector3(s * (dx - 0.2), gy2 + 1.15, zt - 1.0), 0.015, "steel", Color(0.2, 0.2, 0.19), 4)
	_bx(k, m, Vector3(3.7, 0.22, 0.22), Vector3(0, gtop + 0.06, zt + 0.15), "steel", Color(0.45, 0.22, 0.12))
	# nets heaped on the deck beside the drum, floats through them
	var heaps := [[-1.3, 7.4, 0.7], [1.2, 7.6, 0.6], [-0.2, 7.9, 0.55], [1.6, 4.9, 0.42]]
	for h in heaps:
		var hz3: float = h[1]
		var r: float = h[2]
		k._add(m, Res.sphere(1.0, 9), "canvas", Color(0.18, 0.27, 0.22), Vector3(h[0], _dk(p, hz3) + r * 0.25, hz3), Vector3(0, rng.randf() * PI, 0), Vector3(r * 1.3, r * 0.6, r))
		for i in 4:
			k._add(m, Res.sphere(0.085, 6), "plain", ORANGE if i % 2 == 0 else Color(0.85, 0.75, 0.2), Vector3(float(h[0]) + rng.randf_range(-r, r) * 0.9, _dk(p, hz3) + r * 0.45 + rng.randf() * 0.12, hz3 + rng.randf_range(-r, r) * 0.6))
	for q in [[-1.45, 4.86, 0], [-1.45, 4.86, 1], [-1.45, 4.86, 2], [-0.85, 4.88, 0], [-0.85, 4.88, 1]]:
		var cz: float = q[1]
		var lv: int = q[2]
		_bx(k, m, Vector3(0.55, 0.28, 0.4), Vector3(q[0], _dk(p, cz) + 0.14 + lv * 0.28, cz), "plain", Color(0.18, 0.32, 0.55) if lv != 1 else Color(0.55, 0.16, 0.12), Vector3(0, rng.randf_range(-0.08, 0.08), 0))
	k._add(m, Res.sphere(0.3, 12), "plain", Color(0.8, 0.22, 0.1), Vector3(1.75, _dk(p, 6.85) + 0.3, 6.85))
	_rod(k, m, Vector3(1.75, _dk(p, 6.85) + 0.5, 6.85), Vector3(1.95, _dk(p, 6.85) + 2.4, 7.15), 0.02, "wood")
	_bx(k, m, Vector3(0.012, 0.25, 0.35), Vector3(1.94, _dk(p, 6.85) + 2.25, 7.3), "fabric", Color(0.12, 0.12, 0.12), Vector3(0, 0.3, 0), false)
	_coil(k, m, Vector3(-1.6, _dk(p, 6.6), 6.6), 0.32, Color(0.55, 0.5, 0.38))
	for s in [-1.0, 1.0]:
		_bitts(k, m, Vector3(s * 2.15, _dk(p, 4.9), 4.9), 0.0, 0.9, "steel", Color(0.2, 0.19, 0.18))
