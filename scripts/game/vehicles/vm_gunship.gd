class_name VmGunship
extends RefCounted
## Procedural models: gunships - the AC-130 and the V-44X Blackfish.
## Conventions as in VmPlane (read its header): local -Z is forward, y = 0 is
## the ground, metres; built in flight with the gear up, round the fuselage.
## Landing gear goes under a child Node3D named "Gear", hidden by default (the
## Field Manual and the model sheets show it, standing the aircraft on it).
##
## Propellers and proprotors are pivots in k.wheels spinning about their local
## z (projectile.gd turns them in the orbit), each holding a spinner, a
## "Blades" node and a soft "Blur" disc. The guns all fire out of the port
## (left, -x) side: the orbit is flown port wing down round the target.

## Every model key this file builds.
const KEYS: Array[String] = ["ac130", "blackfish", "blackfish_armed"]

## Gunship Gray (FS 36118): the AC-130's overall finish.
const GUNSHIP_GREY := Color(0.3, 0.32, 0.34)
## Low-visibility markings: black outlines on the grey.
const MARK := Color(0.08, 0.08, 0.085)
## The airframes' paint (a clean matte finish, see Mats).
const AIR := "aircraft"
## The Blackfish in Pacific NATO's two-tone (gunship grey over a medium blue
## underside) and in the olive scheme it wears for the other side.
const BF_GREY := Color(0.27, 0.3, 0.33)
const BF_BLUE := Color(0.31, 0.38, 0.47)
const BF_OLIVE := Color(0.33, 0.35, 0.27)

static var _discs := {}
static var _dc := {}


## A tiltrotor's nacelle pivot. It is built in aeroplane mode (the nacelle
## along -z, as the gunship flies its orbit); entering the tree with its
## landing gear showing - the Field Manual stands the aircraft on its wheels -
## it tilts the nacelle up by `parked` (a tiltrotor sits with its proprotors
## turned up: in aeroplane mode their tips would be in the ground).
class Tilt extends Node3D:
	var gear: Node3D
	var parked := PI / 2

	func _ready() -> void:
		if gear != null and gear.visible:
			rotation.x = parked


## Builds the model for `key` into k; false if this file doesn't (yet) know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"ac130":
			_ac130(k, team)
		"blackfish":
			_blackfish(k, team, false)
		"blackfish_armed":
			_blackfish(k, team, true)
		_:
			return false
	return true


# --- shared helpers ---------------------------------------------------------------

## The "Gear" node the landing gear hangs in: hidden in flight, shown by the
## Field Manual. (FL_GEAR_UP leaves it out, for renders of the clean airframe.)
static func _gear_node(k: VehicleModels) -> Node3D:
	if OS.has_environment("FL_GEAR_UP"):
		return null
	var g := k._pivot(k.root, Vector3.ZERO)
	g.name = "Gear"
	g.visible = false
	return g


## The section angle (as VmPlane.stripe takes it: 0 the right side's widest
## point, PI/2 the top, PI the left) of the point at height y on station s.
static func _ang(s: Array, y: float, left := false) -> float:
	var q := VmPlane._sp(s)
	var dy := y - float(q[1])
	var h: float = float(q[3]) if dy >= 0.0 else float(q[4])
	var e: float = float(q[5]) if dy >= 0.0 else float(q[6])
	var u := clampf(absf(dy) / maxf(h, 1e-4), 0.0, 1.0)
	var a := asin(pow(u, e / 2.0) * signf(dy))
	return PI - a if left else a


## How far out from its axis the body's side is at height y on station s.
static func _half_w(s: Array, y: float) -> float:
	var q := VmPlane._sp(s)
	var a := _ang(s, y)
	var e: float = float(q[5]) if y >= float(q[1]) else float(q[6])
	return float(q[2]) * pow(absf(cos(a)), 2.0 / e)


## A flush patch on a body's side between heights y0 and y1, z0 to z1 (a door,
## a gun port, a window): a stripe `grow` proud of the skin.
static func _patch(k: VehicleModels, p: Node3D, key: String, st: Array, z0: float, z1: float, y0: float, y1: float, left: bool, mat: String, col, grow := 0.008) -> void:
	var zm := (z0 + z1) * 0.5
	var s := VmPlane.st_at(st, zm)
	VmPlane.stripe(k, p, key, st, z0, z1, _ang(s, y0, left), _ang(s, y1, left), mat, col, grow, 4)


## The outline of a door or hatch on a body's side: four thin seams.
static func _door(k: VehicleModels, p: Node3D, key: String, st: Array, z0: float, z1: float, y0: float, y1: float, left: bool, col: Color) -> void:
	var w := 0.035
	_patch(k, p, key + "f", st, z0 - w, z0 + w, y0, y1, left, AIR, col, 0.006)
	_patch(k, p, key + "a", st, z1 - w, z1 + w, y0, y1, left, AIR, col, 0.006)
	_patch(k, p, key + "t", st, z0, z1, y1 - w, y1 + w, left, AIR, col, 0.006)
	_patch(k, p, key + "b", st, z0, z1, y0 - w, y0 + w, left, AIR, col, 0.006)


## A landing-gear tyre and hub (not in k.wheels: those are the propellers).
static func _tyre(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float) -> void:
	k._cyl(p, r * 0.94, r * 0.94, w, pos, Vector3(0, 0, PI / 2), "rubber", null, 22)
	k._cyl(p, r, r, w * 0.78, pos, Vector3(0, 0, PI / 2), "rubber", null, 22)
	k._cyl(p, r * 0.56, r * 0.56, w + 0.02, pos, Vector3(0, 0, PI / 2), "paint", Color(0.5, 0.51, 0.5), 16, false)
	k._cyl(p, r * 0.22, r * 0.26, w + 0.08, pos, Vector3(0, 0, PI / 2), "gunmetal_w", null, 10, false)


## The soft disc a turning propeller sweeps: dark, densest inboard where the
## blades are broad, fading out to the tips without a hard rim, with faint
## ghost blades drifting round. One material per blade count and hub size.
static func _disc_mat(nb: int, hub: float) -> ShaderMaterial:
	var key := "%d_%.2f" % [nb, hub]
	if _discs.has(key):
		return _discs[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float nb = 4.0;
uniform float hub = 0.2;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float disc = smoothstep(1.0, 0.86, r) * smoothstep(hub * 0.8, hub + 0.1, r);
	float dens = mix(1.0, 0.45, smoothstep(0.3, 1.0, r));
	float ghost = pow(0.5 + 0.5 * cos(a * nb - TIME * 9.0 + r * 1.5), 8.0);
	ALBEDO = vec3(0.075, 0.075, 0.08);
	ALPHA = disc * dens * (0.065 + 0.07 * ghost);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("nb", float(nb))
	m.set_shader_parameter("hub", hub)
	_discs[key] = m
	return m


## One propeller blade along d (unit, in the disc plane of a shaft along local
## z), from radius r0 to r1: `prof` is [span fraction, chord] pairs, root to
## tip; twisted from blade angle p0 at the root to p1 at the tip, `th` its
## thickness as a fraction of chord. It pulls toward local z = fw and its
## leading edge leads as the pivot turns about +z.
static func _pblade(key: String, d: Vector3, r0: float, r1: float, prof: Array, p0: float, p1: float, th: float, fw := -1.0) -> ArrayMesh:
	var f := Vector3(0, 0, fw)
	var t := Vector3(0, 0, 1).cross(d).normalized()
	var rings := []
	for i in range(0, prof.size(), 2):
		var u: float = prof[i]
		var c: float = prof[i + 1]
		var pa := lerpf(p0, p1, u)
		var cdir := (-t * cos(pa) - f * sin(pa)).normalized()
		var up := d.cross(cdir).normalized()
		if up.dot(f) < 0.0:
			up = -up
		var le := d * lerpf(r0, r1, u) - cdir * c * 0.4
		rings.append(VmPlane.foil(le, c, th * c * lerpf(1.5, 0.7, u), up, 0.0, 1.0, cdir))
	return VmPlane.skin(rings, "gs_" + key, 40.0)


## A spinner: an ogive from its back plate forward (toward z = fw * len) to a
## blunt point, a short skirt behind the plate.
static func _spinner(key: String, r: float, len: float, fw := -1.0, bluntness := 0.0) -> ArrayMesh:
	var prof := [[0.0, 1.0], [0.2, 0.98], [0.42, 0.9], [0.62, 0.74], [0.8, 0.5], [0.92, 0.27 + bluntness * 0.2], [0.985, 0.08 + bluntness * 0.2], [1.0, 0.0]]
	var rings := [VmPlane.sec([-fw * r * 0.25, 0, r * 0.98, r * 0.98, r * 0.98], 20)]
	for q in prof:
		var rr: float = r * float(q[1])
		rings.append(VmPlane.sec([fw * len * float(q[0]), 0, rr, rr, rr], 20))
	return VmPlane.skin(rings, "gs_" + key, 50.0)


## A propeller at pos (its pivot turned by rot): a spinner, `nb` blades of
## profile `prof` out to radius r in a "Blades" node (turned a0 round the
## shaft), a "Blur" disc; the pivot goes in k.wheels and spins about its z.
## fw = 1 builds it pulling toward its own +z (a mirror-image, counter-rotating
## proprotor on a pivot turned round).
static func _propeller(k: VehicleModels, p: Node3D, key: String, pos: Vector3, rot: Vector3, r: float, nb: int, prof: Array, p0: float, p1: float, th: float,
		spin_r: float, spin_len: float, bcol: Color, scol: Color, a0 := 0.0, fw := -1.0, bluntness := 0.0) -> Node3D:
	var pv := k._pivot(p, pos)
	pv.rotation = rot
	k._add(pv, _spinner(key + "_sp", spin_r, spin_len, fw, bluntness), "paint", scol, Vector3.ZERO)
	var bl := k._pivot(pv, Vector3.ZERO)
	bl.name = "Blades"
	bl.rotation.z = a0
	for i in nb:
		var a := TAU * float(i) / float(nb)
		var d := Vector3(sin(a), cos(a), 0)
		k._add(bl, _pblade("%s_b%d" % [key, i], d, spin_r * 0.7, r, prof, p0, p1, th, fw), "paint", bcol, Vector3.ZERO)
	if not k.burnt:
		var disc := MeshInstance3D.new()
		disc.name = "Blur"
		var pm := PlaneMesh.new()
		pm.size = Vector2(r, r) * 2.0
		pm.orientation = PlaneMesh.FACE_Z
		disc.mesh = pm
		disc.material_override = _disc_mat(nb, spin_r / r)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pv.add_child(disc)
	k.wheels.append(pv)
	return pv


# --- markings ---------------------------------------------------------------------

## Triangles (2D, unit radius) of the low-visibility national insignia: the
## outlines of the star, the circle round it and the bars either side.
static func _insignia_tris(lw: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	# the star, its points just inside the circle
	var star := PackedVector2Array()
	for i in 10:
		var a := PI / 2 + PI * float(i) / 5.0
		var rr: float = 0.93 if i % 2 == 0 else 0.93 * 0.382
		star.append(Vector2(cos(a), sin(a)) * rr)
	_ribbon(out, star, lw, true)
	# the circle, broken where the bars join it
	var yt := 0.309
	var yb := -0.191
	var at := asin(yt)
	var ab := asin(yb)
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		var a1 := lerpf(at, PI - at, u)
		up.append(Vector2(cos(a1), sin(a1)))
		var a2 := lerpf(PI - ab, TAU + ab, u)
		lo.append(Vector2(cos(a2), sin(a2)))
	_ribbon(out, up, lw, false)
	_ribbon(out, lo, lw, false)
	for sd: float in [-1.0, 1.0]:
		var bar := PackedVector2Array([Vector2(sd * cos(at), yt), Vector2(sd * 2.0, yt), Vector2(sd * 2.0, yb), Vector2(sd * cos(ab), yb)])
		_ribbon(out, bar, lw, false)
	return out


## A line `w` wide along the points (mitred), as triangles appended to out.
static func _ribbon(out: PackedVector2Array, pts: PackedVector2Array, w: float, closed: bool) -> void:
	var n := pts.size()
	var offs := PackedVector2Array()
	for i in n:
		var prv: Vector2 = pts[(i - 1 + n) % n] if (closed or i > 0) else pts[i] - (pts[i + 1] - pts[i])
		var nxt: Vector2 = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i] + (pts[i] - pts[i - 1])
		var d0 := (pts[i] - prv).normalized()
		var d1 := (nxt - pts[i]).normalized()
		var n0 := Vector2(-d0.y, d0.x)
		var nm := (n0 + Vector2(-d1.y, d1.x)).normalized()
		var ml := clampf(1.0 / maxf(nm.dot(n0), 0.3), 1.0, 2.2)
		offs.append(nm * w * 0.5 * ml)
	for i in (n if closed else n - 1):
		var j := (i + 1) % n
		var a := pts[i] + offs[i]
		var b := pts[i] - offs[i]
		var c := pts[j] - offs[j]
		var d := pts[j] + offs[j]
		out.append_array([a, b, c, a, c, d])


## Lays 2D triangles (u right, v up, scaled by s) over a surface as a thin
## double-sided decal, cached by key: mode 0 on a body's side (prm: [stations,
## z, y, side sign]: u runs along -z on the right side, so a marking reads
## the same from both sides), mode 1 on a wing's upper or lower surface (prm:
## [wing sections, x, z, sign of y]: u along the span, v forward), mode 2 on
## a fin's side (prm: [fin sections, z, y, side sign]).
static func _decal(k: VehicleModels, p: Node3D, key: String, tris: PackedVector2Array, s: float, mode: int, prm: Array, mat: String, col: Color) -> void:
	if not _dc.has(key):
		var vs := PackedVector3Array()
		for t in tris:
			var q := t * s
			var v := Vector3.ZERO
			if mode == 0:
				var sd: float = prm[3]
				var z: float = float(prm[1]) - q.x * sd
				var y: float = float(prm[2]) + q.y
				var ss := VmPlane.st_at(prm[0], z)
				v = Vector3(sd * (_half_w(ss, y) + 0.014) + float(ss[7]), y, z)
			elif mode == 1:
				var x: float = float(prm[1]) + q.x
				var z: float = float(prm[2]) - q.y
				var w := VmPlane.surf_at(prm[0], absf(x))
				var le: Vector3 = w[0]
				var fc := clampf((z - le.z) / float(w[1]), 0.0, 1.0)
				var sg: float = prm[3]
				v = Vector3(x, le.y + sg * (VmPlane._foil_t(fc) * float(w[2]) * 0.5 + 0.014), z)
			else:
				var sd: float = prm[3]
				var z: float = float(prm[1]) - q.x * sd
				var y: float = float(prm[2]) + q.y
				var w := _fin_at(prm[0], y)
				var le: Vector3 = w[0]
				var fc := clampf((z - le.z) / float(w[1]), 0.0, 1.0)
				v = Vector3(le.x + sd * (VmPlane._foil_t(fc) * float(w[2]) * 0.5 + 0.012), y, z)
			vs.append(v)
		_dc[key] = _dmesh(vs)
	k._add(p, _dc[key], mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## Panel lines over a wing's upper surface, both sides: chordwise joints at
## the spans in xs (from the leading edge to chord fraction f1) and the spar
## lines along it at the chord fractions in fs, from span x0 to x1.
static func _wing_lines(k: VehicleModels, p: Node3D, key: String, secs: Array, xs: Array, fs: Array, x0: float, x1: float, f1: float, col: Color) -> void:
	var tris := PackedVector2Array()
	for sd: float in [-1.0, 1.0]:
		for x: float in xs:
			var line := PackedVector2Array()
			for i in 11:
				var w := VmPlane.surf_at(secs, x)
				var le: Vector3 = w[0]
				line.append(Vector2(sd * x, -(le.z + lerpf(0.02, f1, float(i) / 10.0) * float(w[1]))))
			_ribbon(tris, line, 0.035, false)
		for f: float in fs:
			var line := PackedVector2Array()
			for i in 25:
				var x := lerpf(x0, x1, float(i) / 24.0)
				var w := VmPlane.surf_at(secs, x)
				var le: Vector3 = w[0]
				line.append(Vector2(sd * x, -(le.z + f * float(w[1]))))
			_ribbon(tris, line, 0.035, false)
	_decal(k, p, key, tris, 1.0, 1, [secs, 0.0, 0.0, 1.0], AIR, col)


## A seam running along a body's side at height y from z0 to z1, both sides.
static func _seam(k: VehicleModels, p: Node3D, key: String, st: Array, z0: float, z1: float, y: float, col: Color) -> void:
	for sd: float in [-1.0, 1.0]:
		var a := _ang(VmPlane.st_at(st, (z0 + z1) * 0.5), y, sd < 0.0)
		VmPlane.stripe(k, p, key + ("L" if sd < 0.0 else ""), st, z0, z1, a - 0.007, a + 0.007, AIR, col, 0.006, 3)


## A thin double-sided mesh from a triangle list (each face lit from the side
## it is seen from).
static func _dmesh(vs: PackedVector3Array) -> ArrayMesh:
	var v2 := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in range(0, vs.size(), 3):
		var nn := (vs[i + 1] - vs[i]).cross(vs[i + 2] - vs[i]).normalized()
		# (Godot's front faces wind clockwise, seen from their normal's side)
		v2.append_array([vs[i], vs[i + 2], vs[i + 1], vs[i], vs[i + 1], vs[i + 2]])
		ns.append_array([nn, nn, nn, -nn, -nn, -nn])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v2
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(am, arr)
	return am


## Where a vertical fin (sections stacked up y) is at height y: [leading
## edge, chord, thickness].
static func _fin_at(secs: Array, y: float) -> Array:
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var la: Vector3 = a[0]
		var lb: Vector3 = b[0]
		if y <= lb.y or i == secs.size() - 2:
			var t := clampf((y - la.y) / maxf(1e-4, lb.y - la.y), 0.0, 1.0)
			return [la.lerp(lb, t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]
	return secs[0]


## The segments (a to g, clockwise from the top, then the middle bar) each
## character lights, stencil style: digits, A and F.
const SEGS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg",
	"9": "abcdfg", "A": "abcefg", "F": "aefg"}


## Triangles of a line of stencil lettering h tall, centred on the origin
## (its baseline at -h/2): the tail number.
static func _text_tris(txt: String, h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cw := h * 0.55
	var adv := h * 0.82
	var x0 := -float(txt.length()) * adv * 0.5 + (adv - cw) * 0.5
	var pts := {"a": [Vector2(0, 1), Vector2(1, 1)], "b": [Vector2(1, 1), Vector2(1, 0.5)], "c": [Vector2(1, 0.5), Vector2(1, 0)], "d": [Vector2(1, 0), Vector2(0, 0)],
		"e": [Vector2(0, 0), Vector2(0, 0.5)], "f": [Vector2(0, 0.5), Vector2(0, 1)], "g": [Vector2(0, 0.5), Vector2(1, 0.5)]}
	for i in txt.length():
		var ch := txt[i]
		if not SEGS.has(ch):
			continue
		for sg in String(SEGS[ch]):
			var e: Array = pts[sg]
			var o := Vector2(x0 + float(i) * adv - (cw * 0.4 if ch == "1" else 0.0), -h * 0.5)
			var pa: Vector2 = o + Vector2(e[0].x * cw, e[0].y * h)
			var pb: Vector2 = o + Vector2(e[1].x * cw, e[1].y * h)
			var d := (pb - pa).normalized()
			# (each stroke runs a little past its ends to close the corners)
			_ribbon(out, PackedVector2Array([pa - d * h * 0.06, pb + d * h * 0.06]), h * 0.13, false)
	return out


# --- AC-130U Spooky II --------------------------------------------------------------

## Lockheed AC-130U Spooky II (29.8 m long, 40.4 m span, 11.7 m tall): the
## C-130H airframe - the flat-bottomed fuselage with its main gear in long
## sponsons, the high wing with four Allison T56s in long underslung nacelles
## and four-blade Hamilton Standard propellers, the upswept tail over the
## cargo ramp and door, a tall fin with a dorsal fillet - and the gunship's
## kit: the bulbous AN/APQ-180 radome, the IR and all-light-level TV turrets,
## the refuelling receptacle, chaff and flare dispensers, and down the port
## side the 25 mm GAU-12 behind the crew door and, aft of the sponson, the
## 40 mm Bofors and the 105 mm M102 howitzer in the paratroop door. Gunship
## Gray with black low-visibility insignia and formation lights.
static func _ac130(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := GUNSHIP_GREY
	var cj := c.darkened(0.3)  # panel joints and seams
	# the fuselage: the radome, the flight deck, the long constant section of
	# the cargo hold (belly 0.65 m up, roof 4.75 m), the upswept tail
	var st := [
		[-14.95, 2.3, 0.0, 0.0, 0.0],
		[-14.86, 2.3, 0.42, 0.4, 0.38, 2.0, 2.0],
		[-14.6, 2.32, 0.86, 0.8, 0.76, 2.0, 2.05],
		[-14.15, 2.38, 1.26, 1.15, 1.1, 2.0, 2.15],
		[-13.6, 2.44, 1.56, 1.32, 1.36, 2.0, 2.3],
		[-13.05, 2.5, 1.8, 1.32, 1.56, 2.0, 2.45],
		[-12.45, 2.55, 1.97, 1.85, 1.72, 2.0, 2.65],
		[-11.8, 2.58, 2.08, 2.12, 1.84, 2.02, 2.8],
		[-10.9, 2.6, 2.14, 2.15, 1.92, 2.04, 2.95],
		[-9.6, 2.6, 2.15, 2.15, 1.95, 2.05, 3.0],
		[3.75, 2.6, 2.15, 2.15, 1.95, 2.05, 3.0],
		[5.65, 2.83, 2.08, 1.92, 1.6, 2.05, 2.85],
		[7.9, 3.2, 1.86, 1.53, 1.12, 2.05, 2.6],
		[10.3, 3.52, 1.5, 1.18, 0.78, 2.05, 2.4],
		[12.6, 3.8, 1.02, 0.86, 0.52, 2.0, 2.2],
		[14.2, 4.0, 0.52, 0.58, 0.32],
		[14.95, 4.1, 0.1, 0.2, 0.1],
	]
	VmPlane.body(k, m, "gs_ac_fus", st, AIR, c, 28)
	# the radome's joint, frame joints down the fuselage
	for z: float in [-13.75, -9.6, -6.6, 3.75, 10.4]:
		VmPlane.band(k, m, "gs_ac_j%.1f" % z, st, z, 0.03, 0.005, AIR, cj, 28)
	_ac130_cockpit(k, m, st, c)
	_seam(k, m, "gs_ac_seam0", st, -9.6, 3.75, 3.7, cj)
	_seam(k, m, "gs_ac_seam1", st, -9.6, 3.75, 2.35, cj)
	_ac130_doors(k, m, st, cj)
	# the main gear sponsons along the lower sides
	var sp := [[-6.4, 1.5, 0.05, 0.3, 0.3, 2, 2, 1.95], [-5.8, 1.42, 0.4, 0.66, 0.6, 2.2, 2.4, 2.0], [-4.8, 1.39, 0.6, 0.86, 0.72, 2.4, 2.8, 2.03],
		[-3.0, 1.38, 0.66, 0.9, 0.74, 2.5, 3.0, 2.05], [0.0, 1.38, 0.66, 0.9, 0.74, 2.5, 3.0, 2.05], [0.9, 1.42, 0.55, 0.8, 0.66, 2.4, 2.6, 2.02],
		[1.5, 1.5, 0.25, 0.5, 0.4, 2.2, 2.2, 1.98], [1.85, 1.55, 0.05, 0.12, 0.1, 2, 2, 1.95]]
	VmPlane.body2(k, m, "gs_ac_spon", sp, AIR, c, 20)
	for s: float in [-1.0, 1.0]:
		# the closed wheel-well doors under each sponson, the joint at its nose
		for z: float in [-3.0, 0.5]:
			k._box(m, Vector3(0.5, 0.012, 0.02), Vector3(s * 2.06, 0.637, z), AIR, cj, Vector3.ZERO, false)
		for x: float in [1.8, 2.32]:
			k._box(m, Vector3(0.02, 0.012, 3.5), Vector3(s * x, 0.637, -1.25), AIR, cj, Vector3.ZERO, false)
		# the chaff and flare dispensers in the sponson's tail
		k._box(m, Vector3(0.06, 0.32, 0.55), Vector3(s * 2.5, 1.15, 0.85), "gunmetal_w", null, Vector3(0, s * 0.35, 0), false)
		for i in 3:
			k._box(m, Vector3(0.02, 0.06, 0.4), Vector3(s * 2.53, 1.06 + i * 0.09, 0.85), "plain_dark", null, Vector3(0, s * 0.35, 0), false)
	# the wing on top: a constant-chord centre section out past the inboard
	# engines, tapered outer panels with 2.5 degrees of dihedral; Fowler flaps
	# inboard, ailerons outboard
	var ws := [[Vector3(0.0, 4.95, -3.1), 4.9, 0.86], [Vector3(2.15, 4.95, -3.1), 4.9, 0.85], [Vector3(5.6, 4.95, -3.1), 4.88, 0.8],
		[Vector3(13.6, 5.3, -2.33), 3.62, 0.56], [Vector3(19.95, 5.58, -1.72), 2.6, 0.32]]
	VmPlane.surf(k, m, "gs_ac_wing", ws, AIR, c, [0.0, 0.72, 0.72, 0.74])
	VmPlane.surf(k, m, "gs_ac_wtip", [[Vector3(19.94, 5.58, -1.72), 2.6, 0.32], [Vector3(20.2, 5.59, -1.45), 2.1, 0.12]], AIR, c, [])
	VmPlane.nav_lights(k, m, Vector3(20.22, 5.59, -0.9), 0.12)
	_wing_lines(k, m, "gs_ac_wl", ws, [2.4, 6.4, 8.7, 13.6, 17.2], [0.14, 0.64], 2.2, 19.6, 0.71, cj)
	# the fairing over the wing root on top of the fuselage
	VmPlane.body(k, m, "gs_ac_wfair", [[-5.2, 4.6, 0.0, 0.0, 0.0], [-4.3, 4.68, 0.7, 0.24, 0.2, 2.2, 2.0], [-3.0, 4.75, 1.05, 0.52, 0.3, 2.4, 2.0],
		[-0.5, 4.78, 1.15, 0.6, 0.3, 2.5, 2.0], [1.9, 4.75, 1.05, 0.5, 0.3, 2.4, 2.0], [3.4, 4.65, 0.55, 0.22, 0.2, 2.2, 2.0], [4.4, 4.6, 0.0, 0.0, 0.0]], AIR, c, 20)
	# the engines: long T56 nacelles slung under the wing, four-blade props
	var engines := [[5.0, 0.4], [10.0, 1.7]]
	for e in engines:
		var nx: float = e[0]
		var w := VmPlane.surf_at(ws, nx)
		var le: Vector3 = w[0]
		var cw: float = w[1]
		_t56(k, m, "gs_ac_nac%d" % int(nx), nx, le, cw, c, cj)
		for s: float in [-1.0, 1.0]:
			var yt := le.y - 0.62
			_propeller(k, m, "gs_ac_prop", Vector3(s * nx, yt, le.z - 3.66), Vector3.ZERO, 2.06, 4,
				[0.0, 0.32, 0.1, 0.46, 0.3, 0.52, 0.6, 0.51, 0.85, 0.44, 0.96, 0.32, 1.0, 0.16], 0.95, 0.32, 0.1,
				0.52, 1.15, Color(0.14, 0.14, 0.15), c.lightened(0.06), float(e[1]) + (0.6 if s < 0.0 else 0.0), -1.0, 0.25)
	# the tail: the stabiliser with its elevators, the fin and rudder, the
	# dorsal fillet running forward along the top
	VmPlane.surf(k, m, "gs_ac_stab", [[Vector3(0.0, 4.4, 10.1), 4.3, 0.46], [Vector3(1.2, 4.4, 10.25), 4.15, 0.44], [Vector3(7.75, 4.4, 12.15), 2.2, 0.22],
		[Vector3(8.02, 4.4, 12.5), 1.75, 0.1]], AIR, c, [0.0, 0.68, 0.0])
	var fin := [[Vector3(0, 4.35, 8.6), 6.1, 0.56], [Vector3(0, 5.0, 8.95), 5.75, 0.54], [Vector3(0, 11.5, 11.85), 2.85, 0.26], [Vector3(0, 11.66, 12.05), 2.55, 0.1]]
	VmPlane.surf(k, m, "gs_ac_fin", fin, AIR, c, [0.0, 0.6, 0.0], false)
	VmPlane.surf(k, m, "gs_ac_fillet", [[Vector3(0, 4.6, 4.3), 6.0, 0.34], [Vector3(0, 5.75, 9.35), 1.2, 0.3]], AIR, c, [], false)
	# the tail cone: the white tail light, the warning sensors either side
	k._add(m, Res.sphere(0.07, 8), "paint", Color(0.9, 0.9, 0.85), Vector3(0, 4.12, 14.98), Vector3.ZERO, Vector3.ONE, false)
	for s: float in [-1.0, 1.0]:
		k._add(m, Res.sphere(0.11, 10), "glass", null, Vector3(s * 0.62, 4.05, 13.3), Vector3.ZERO, Vector3(0.6, 1, 1), false)
		k._add(m, Res.sphere(0.1, 10), "glass", null, Vector3(s * 1.6, 3.05, -13.2), Vector3.ZERO, Vector3(0.6, 1, 1), false)
	# the anti-collision beacons, the antennas, the SATCOM dome
	k._add(m, Res.sphere(0.13, 10), "plain_dark", Color(0.5, 0.06, 0.05), Vector3(0, 4.78, -8.4), Vector3.ZERO, Vector3(1, 0.7, 1.3), false)
	k._add(m, Res.sphere(0.13, 10), "plain_dark", Color(0.5, 0.06, 0.05), Vector3(0, 0.63, -3.6), Vector3.ZERO, Vector3(1, 0.7, 1.3), false)
	k._add(m, Res.sphere(0.42, 16), AIR, c.lightened(0.05), Vector3(0, 4.62, 5.2), Vector3.ZERO, Vector3(1, 0.42, 1.25))
	for z: float in [-7.5, -6.6, 6.5]:
		VmPlane.antenna(k, m, Vector3(0, 4.75, z), 0.38)
	for z: float in [-8.6, -7.0]:
		VmPlane.antenna(k, m, Vector3(0, 0.66, z), 0.32, true)
	# the formation lights: pale green strips on the nose, the tail and the fin
	var fl := Color(0.52, 0.62, 0.44)
	for s: float in [-1.0, 1.0]:
		_patch(k, m, "gs_ac_fl0" + ("L" if s < 0.0 else ""), st, -10.45, -10.35, 1.6, 2.7, s < 0.0, "paint", fl, 0.01)
		_patch(k, m, "gs_ac_fl1" + ("L" if s < 0.0 else ""), st, 8.75, 8.85, 3.2, 4.25, s < 0.0, "paint", fl, 0.01)
		k._box(m, Vector3(0.012, 2.4, 0.08), Vector3(s * 0.205, 7.6, 11.0), "paint", fl, Vector3(0.42, 0, 0), false)
	_ac130_guns(k, m, st, c)
	# markings: the black outline insignia aft and on the wings, team panels
	var ins := _insignia_tris(0.075)
	for s: float in [-1.0, 1.0]:
		_decal(k, m, "gs_ac_ins" + ("L" if s < 0.0 else ""), ins, 0.62, 0, [st, 6.0, 3.0, s], "plain_dark", MARK)
	_decal(k, m, "gs_ac_insw", ins, 0.95, 1, [ws, -15.2, -1.0, 1.0], "plain_dark", MARK)
	_decal(k, m, "gs_ac_insw2", ins, 0.95, 1, [ws, 15.2, -1.0, -1.0], "plain_dark", MARK)
	VmPlane.wing_marks(k, m, team, ws, 7.6, 1.3)
	for s: float in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 0.235, 7.6, 12.0), Vector3(0.02, 1.1, 1.3))
		# the tail number: the fiscal year small, the serial under it
		var sfx := "L" if s < 0.0 else ""
		_decal(k, m, "gs_ac_tn0" + sfx, _text_tris("AF 90", 0.3), 1.0, 2, [fin, 12.1, 9.75, s], "plain_dark", MARK)
		_decal(k, m, "gs_ac_tn1" + sfx, _text_tris("0163", 0.52), 1.0, 2, [fin, 12.1, 9.05, s], "plain_dark", MARK)
	_ac130_gear(k)


## The flight deck: the multi-pane windscreen and its frames, the eyebrow
## windows over it, side windows, the chin windows low in the nose; pitot
## tubes either side, the refuelling receptacle on the roof behind.
static func _ac130_cockpit(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var cf := c.darkened(0.15)
	# the windscreen: five panes across the steep front of the flight deck,
	# framed; its top and bottom rails
	VmPlane.stripe(k, m, "gs_ac_ws", st, -13.0, -12.42, 0.42, PI - 0.42, "glass", null, 0.012, 18)
	for a: float in [PI / 2, PI / 2 - 0.42, PI / 2 + 0.42, 0.72, PI - 0.72]:
		VmPlane.stripe(k, m, "gs_ac_wsp%.2f" % a, st, -13.03, -12.4, a - 0.035, a + 0.035, AIR, cf, 0.022, 3)
	for z: float in [-13.02, -12.42]:
		VmPlane.stripe(k, m, "gs_ac_wsb%.2f" % z, st, z - 0.035, z + 0.035, 0.4, PI - 0.4, AIR, cf, 0.022, 18)
	for s: float in [-1.0, 1.0]:
		var left := s < 0.0
		var sfx := "L" if left else ""
		# two side windows each side, the eyebrow windows over them
		for zz in [[-12.36, -11.84], [-11.74, -11.2]]:
			var z0: float = zz[0]
			var z1: float = zz[1]
			var sa := VmPlane.st_at(st, (z0 + z1) * 0.5)
			VmPlane.stripe(k, m, "gs_ac_sw%.1f%s" % [z0, sfx], st, z0, z1, _ang(sa, 3.32, left), _ang(sa, 4.12, left), "glass", null, 0.012, 5)
			VmPlane.stripe(k, m, "gs_ac_ew%.1f%s" % [z0, sfx], st, z0 + 0.06, z1 - 0.06, _ang(sa, 4.26, left), _ang(sa, 4.5, left), "glass", null, 0.012, 4)
		# the chin window low in the nose beside the nose gear
		var sc := VmPlane.st_at(st, -12.9)
		VmPlane.stripe(k, m, "gs_ac_chin" + sfx, st, -13.3, -12.55, _ang(sc, 1.3, left), _ang(sc, 2.0, left), "glass", null, 0.012, 5)
		# the pitot tubes
		var sp := VmPlane.st_at(st, -13.2)
		var px := _half_w(sp, 2.8) + 0.12
		VmPlane.rod(k, m, Vector3(s * (px - 0.14), 2.8, -13.2), Vector3(s * px, 2.8, -13.2), 0.03, "gunmetal_w", null, 6, -1.0, false)
		VmPlane.rod(k, m, Vector3(s * px, 2.8, -13.2), Vector3(s * px, 2.8, -13.65), 0.022, "gunmetal_w", null, 6, -1.0, false)
	# the air-refuelling receptacle (UARRSI) on the roof and its slipway
	k._box(m, Vector3(0.62, 0.05, 0.9), Vector3(0, 4.74, -9.4), "plain_dark", null, Vector3(-0.02, 0, 0), false)
	k._box(m, Vector3(0.36, 0.06, 0.4), Vector3(0, 4.76, -9.4), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.02, 1.4), Vector3(s * 0.45, 4.755, -10.3), "paint", Color(0.85, 0.85, 0.8), Vector3(0, s * 0.3, 0), false)


## Doors and windows on the fuselage: the crew entrance door forward on the
## left, the paratroop door aft on the right (the 105 fills the left one), the
## cargo ramp and the upper cargo door under the tail, the cabin windows.
static func _ac130_doors(k: VehicleModels, m: Node3D, st: Array, cj: Color) -> void:
	_door(k, m, "gs_ac_crew", st, -9.45, -8.55, 0.95, 2.85, true, cj)
	_patch(k, m, "gs_ac_crewwin", st, -9.15, -8.85, 2.25, 2.55, true, "glass", null, 0.01)
	_door(k, m, "gs_ac_para", st, 2.45, 3.5, 1.05, 3.05, false, cj)
	_patch(k, m, "gs_ac_parawin", st, 2.8, 3.15, 2.35, 2.7, false, "glass", null, 0.01)
	for s: float in [-1.0, 1.0]:
		for z: float in [-7.4, -4.5, -0.9]:
			if s < 0.0 and z < -7.0:
				continue
			_patch(k, m, "gs_ac_win%.1f%s" % [z, "L" if s < 0.0 else ""], st, z - 0.14, z + 0.14, 3.0, 3.28, s < 0.0, "glass", null, 0.01)
	# the ramp and cargo door: seams along the lower sides of the upsweep and
	# across it at the hinge, the ramp's end and the door's top
	for a: float in [-PI / 2 - 0.82, -PI / 2 + 0.82]:
		VmPlane.stripe(k, m, "gs_ac_ramp%.2f" % a, st, 3.75, 10.0, a - 0.018, a + 0.018, AIR, cj, 0.008, 3)
	for z: float in [3.75, 7.1, 10.0]:
		VmPlane.stripe(k, m, "gs_ac_rampx%.1f" % z, st, z - 0.03, z + 0.03, -PI / 2 - 0.82, -PI / 2 + 0.82, AIR, cj, 0.008, 10)


## An Allison T56 nacelle under the wing at span nx (both sides): the cowl
## behind the spinner with the big chin intake, the body deep under the wing,
## the long tail fairing past the trailing edge and the exhaust low on its
## outboard side.
static func _t56(k: VehicleModels, m: Node3D, key: String, nx: float, le: Vector3, cw: float, c: Color, cj: Color) -> void:
	var z0 := le.z
	var yt := le.y - 0.62
	# a tall oval behind the spinner (the intake under it), the top running
	# back into the wing's leading edge, the deep belly, the tail fairing
	var nst := [
		[z0 - 3.62, yt - 0.2, 0.56, 0.78, 0.86, 2.0, 2.2, nx],
		[z0 - 3.0, yt - 0.2, 0.6, 0.84, 0.92, 2.1, 2.4, nx],
		[z0 - 1.8, yt - 0.16, 0.62, 0.86, 0.96, 2.2, 2.6, nx],
		[z0 - 0.4, yt - 0.1, 0.62, 0.8, 0.98, 2.2, 2.6, nx],
		[z0 + 1.4, yt - 0.02, 0.6, 0.7, 0.98, 2.2, 2.6, nx],
		[z0 + cw * 0.92, yt + 0.15, 0.5, 0.5, 0.8, 2.2, 2.4, nx],
		[z0 + cw + 0.9, yt + 0.3, 0.3, 0.3, 0.45, 2.1, 2.2, nx],
		[z0 + cw + 2.0, yt + 0.4, 0.05, 0.06, 0.06, 2.0, 2.0, nx],
	]
	VmPlane.body2(k, m, key, nst, AIR, c, 22)
	for s: float in [-1.0, 1.0]:
		var x: float = s * nx
		var sfx := "L" if s < 0.0 else ""
		# the cowl's panel joints
		for z: float in [z0 - 3.1, z0 - 1.3]:
			k._add(m, VmPlane.skin([VmPlane.sec(_shift(VmPlane.st_at(nst, z - 0.02), x), 22, 0.006), VmPlane.sec(_shift(VmPlane.st_at(nst, z + 0.02), x), 22, 0.006)],
				"gs_%s_j%.2f%s" % [key, z, sfx], 50.0), AIR, cj, Vector3.ZERO)
		# the engine and oil-cooler intake under the spinner: a lip standing
		# proud of the cowl's face, dark inside
		var ist := [[z0 - 3.78, yt - 0.72, 0.42, 0.26, 0.24, 2.4, 2.4, x], [z0 - 3.55, yt - 0.74, 0.47, 0.31, 0.3, 2.4, 2.4, x], [z0 - 3.0, yt - 0.74, 0.47, 0.3, 0.3, 2.4, 2.4, x]]
		VmPlane.body(k, m, key + "_in" + sfx, ist, AIR, c, 18)
		VmPlane.mouth(k, m, key + "_inm" + sfx, ist[0], 0.82, -1.0, "plain_dark")
		# the exhaust: a short pipe out of the outboard side of the nacelle under
		# the trailing edge, soot streaked aft of it
		var ez := z0 + cw - 0.3
		var ex := x + s * 0.5
		k._cyl(m, 0.22, 0.25, 0.5, Vector3(ex, yt - 0.5, ez), Vector3(PI / 2, s * 0.25, 0), "gunmetal_w", c.darkened(0.5), 14)
		k._cyl(m, 0.17, 0.17, 0.03, Vector3(ex + s * 0.07, yt - 0.5, ez + 0.25), Vector3(PI / 2, s * 0.25, 0), "plain_dark", null, 12, false)
		k._box(m, Vector3(0.02, 0.26, 1.7), Vector3(x + s * 0.4, yt - 0.4, z0 + cw + 0.85), "paint", Color(0.16, 0.16, 0.16), Vector3(0, s * 0.18, 0), false)


## Station s moved out to x.
static func _shift(s: Array, x: float) -> Array:
	var q := VmPlane._sp(s)
	q[7] = x
	return q


## The guns down the left side, through ports in the skin: the GAU-12's five
## barrels behind the crew door; aft of the sponson, side by side, the 40 mm
## Bofors with its long flash hider and the M102 105 mm in the paratroop door
## with its recoil sleeve and double-baffle muzzle brake. All train out to
## port, depressed a little; the IR and TV sensor turrets forward.
static func _ac130_guns(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var dep := 0.1
	var dn := Vector3(-cos(dep), -sin(dep), 0)
	# the 25 mm GAU-12 Equalizer
	_patch(k, m, "gs_ac_p25", st, -8.25, -7.45, 1.3, 2.15, true, "plain_dark", null, 0.008)
	var g25 := Vector3(-_half_w(VmPlane.st_at(st, -7.85), 1.72), 1.72, -7.85)
	k._add(m, Res.sphere(0.32, 14), AIR, c.darkened(0.08), g25 + Vector3(0.02, 0, 0), Vector3.ZERO, Vector3(0.6, 1.0, 1.15))
	for i in 5:
		var a := TAU * float(i) / 5.0
		var o := Vector3(0, cos(a) * 0.075, sin(a) * 0.075)
		VmPlane.rod(k, m, g25 + o, g25 + o + dn * 1.15, 0.019, "gunmetal_w", null, 6, -1.0, false)
	for f: float in [0.35, 0.95]:
		k._add(m, Res.cyl(0.11, 0.11, 0.07, 12), "gunmetal_w", null, g25 + dn * float(f), Vector3(0, 0, PI / 2 + dep))
	k.mg_tip = k._tip(m, g25 + dn * 1.2)
	# the 40 mm L/60 Bofors
	_patch(k, m, "gs_ac_p40", st, 1.45, 2.3, 1.15, 2.2, true, "plain_dark", null, 0.008)
	var g40 := Vector3(-_half_w(VmPlane.st_at(st, 1.88), 1.66), 1.66, 1.88)
	# (the mount's shield in the port, the cooling jacket, the barrel, the
	# conical flash hider)
	k._box(m, Vector3(0.3, 0.6, 0.62), g40 + Vector3(-0.06, 0, 0), "gunmetal_w", c.darkened(0.3))
	VmPlane.rod(k, m, g40, g40 + dn * 0.8, 0.12, "gunmetal_w", null, 12)
	VmPlane.rod(k, m, g40, g40 + dn * 1.9, 0.065, "gunmetal_w", null, 10)
	VmPlane.rod(k, m, g40 + dn * 1.75, g40 + dn * 2.45, 0.08, "gunmetal_w", null, 12, 0.15)
	k._add(m, Res.cyl(0.13, 0.13, 0.02, 12), "plain_dark", null, g40 + dn * 2.455, Vector3(0, 0, PI / 2 + dep), Vector3.ONE, false)
	# the 105 mm M102 howitzer
	_patch(k, m, "gs_ac_p105", st, 2.4, 3.6, 0.95, 2.85, true, "plain_dark", null, 0.008)
	var g105 := Vector3(-_half_w(VmPlane.st_at(st, 3.0), 1.92), 1.92, 3.0)
	# (the cradle in the port, the recoil sleeve, the barrel, the double-baffle
	# muzzle brake with its side ports)
	k._box(m, Vector3(0.5, 0.8, 0.9), g105 + Vector3(-0.1, 0, 0), "gunmetal_w", c.darkened(0.35))
	VmPlane.rod(k, m, g105, g105 + dn * 1.2, 0.2, "gunmetal_w", null, 14)
	VmPlane.rod(k, m, g105 + dn * 1.15, g105 + dn * 1.3, 0.22, "gunmetal_w", null, 14)
	VmPlane.rod(k, m, g105, g105 + dn * 2.8, 0.1, "gunmetal_w", null, 12)
	var mb := g105 + dn * 3.02
	k._box(m, Vector3(0.5, 0.32, 0.4), mb, "gunmetal_w", null, Vector3(0, 0, dep))
	for f: float in [-0.12, 0.12]:
		k._box(m, Vector3(0.13, 0.22, 0.412), mb + dn * f, "plain_dark", null, Vector3(0, 0, dep), false)
	k.gun_tip = k._tip(m, mb + dn * 0.25)
	# the AN/AAQ-117 infrared turret under the nose, the ALLTV turret in the
	# front of the left sponson
	for tp in [[Vector3(-0.95, 0.66, -9.15), 0.36], [Vector3(-2.18, 0.86, -5.25), 0.3]]:
		var tc: Vector3 = tp[0]
		var tr: float = tp[1]
		k._cyl(m, tr * 0.8, tr * 0.85, 0.16, tc + Vector3(0, tr * 0.55, 0), Vector3.ZERO, AIR, c)
		k._add(m, Res.sphere(tr, 16), "paint", Color(0.42, 0.43, 0.44), tc)
		k._add(m, Res.sphere(tr * 0.42, 12), "glass", null, tc + Vector3(-tr * 0.7, -tr * 0.45, 0), Vector3.ZERO, Vector3(0.45, 1, 1), false)
		k._add(m, Res.sphere(tr * 0.24, 10), "glass", null, tc + Vector3(-tr * 0.82, -tr * 0.05, tr * 0.42), Vector3.ZERO, Vector3(0.45, 1, 1), false)


## The landing gear, down (the "Gear" node): twin nose wheels under the
## flight deck with their doors open, two main wheels in tandem out of each
## sponson's open well.
static func _ac130_gear(k: VehicleModels) -> void:
	var g := _gear_node(k)
	if g == null:
		return
	# the nose gear: the strut, its torque links, the twin wheels, the doors
	VmPlane.rod(k, g, Vector3(0, 1.0, -10.6), Vector3(0, 0.5, -10.6), 0.09, "steel", Color(0.6, 0.6, 0.58), 10)
	VmPlane.rod(k, g, Vector3(0, 0.85, -10.7), Vector3(0, 0.6, -10.72), 0.04, "gunmetal_w", null, 6)
	k._cyl(g, 0.05, 0.05, 0.62, Vector3(0, 0.5, -10.6), Vector3(0, 0, PI / 2), "steel", null, 8)
	for s: float in [-1.0, 1.0]:
		_tyre(k, g, Vector3(s * 0.25, 0.5, -10.6), 0.5, 0.3)
		k._box(g, Vector3(0.025, 0.55, 1.5), Vector3(s * 0.62, 0.55, -10.6), AIR, GUNSHIP_GREY, Vector3(0, 0, s * 0.12))
	k._box(g, Vector3(1.0, 0.02, 1.4), Vector3(0, 0.665, -10.6), "plain_dark", null, Vector3.ZERO, false)
	# the main gear: the open wells, a strut and wheel at each station
	for s: float in [-1.0, 1.0]:
		k._box(g, Vector3(0.6, 0.02, 3.45), Vector3(s * 2.06, 0.632, -1.25), "plain_dark", null, Vector3.ZERO, false)
		for z: float in [-2.05, -0.45]:
			VmPlane.rod(k, g, Vector3(s * 1.78, 1.9, z), Vector3(s * 1.78, 0.71, z), 0.08, "steel", Color(0.6, 0.6, 0.58), 10)
			_tyre(k, g, Vector3(s * 2.12, 0.71, z), 0.71, 0.5)


# --- V-44X Blackfish ----------------------------------------------------------------

## V-44X Blackfish (Arma 3): a V-22 Osprey grown half as big again into a
## C-130 replacement. The bulbous glazed nose with its targeting turret, a
## deep slab-sided cabin with big gear sponsons along its lower sides, the
## high straight wing on a fairing over the cabin, a whole nacelle tilting at
## each wingtip with a three-blade proprotor (aeroplane mode in flight, turned
## up on the ground: see Tilt), the upswept tail over the rear ramp, an H tail
## with canted fins. The gunship (`armed`) fires out of the port side: a 40 mm
## cannon in a blister forward and aft, in one big mount, the 105 mm howitzer
## with the 20 mm Gatling under it. Gunship grey over a medium blue belly
## (olive for the other side).
static func _blackfish(k: VehicleModels, team: int, armed: bool) -> void:
	var m := k.root
	var olive := team == 1
	var c := BF_OLIVE if olive else BF_GREY
	var cu := BF_OLIVE if olive else BF_BLUE
	var cj := c.darkened(0.3)
	var st := [
		[-12.4, 2.22, 0.0, 0.0, 0.0],
		[-12.3, 2.22, 0.34, 0.3, 0.3, 2.0, 2.0],
		[-12.0, 2.24, 0.7, 0.62, 0.64, 2.0, 2.1],
		[-11.5, 2.28, 1.02, 0.92, 0.98, 2.1, 2.3],
		[-10.8, 2.34, 1.28, 1.14, 1.3, 2.2, 2.5],
		[-10.0, 2.4, 1.47, 1.5, 1.6, 2.3, 2.75],
		[-9.0, 2.43, 1.58, 1.76, 1.78, 2.45, 2.95],
		[-7.8, 2.45, 1.62, 1.85, 1.85, 2.6, 3.2],
		[4.6, 2.45, 1.62, 1.85, 1.85, 2.6, 3.2],
		[6.2, 2.68, 1.55, 1.64, 1.5, 2.6, 3.0],
		[8.0, 3.04, 1.3, 1.28, 1.02, 2.5, 2.7],
		[9.8, 3.42, 0.94, 0.9, 0.6, 2.4, 2.4],
		[11.3, 3.72, 0.52, 0.56, 0.32],
		[12.1, 3.84, 0.16, 0.24, 0.12],
		[12.35, 3.86, 0.03, 0.05, 0.03],
	]
	VmPlane.body(k, m, "gs_bf_fus", st, AIR, c, 28)
	if not olive:
		# the blue underside, up to a line along the lower flanks
		VmPlane.stripe(k, m, "gs_bf_belly", st, -11.9, 12.2, -PI + 0.12, -0.12, AIR, cu, 0.004, 16)
	for z: float in [-11.55, -7.6, -2.6, 4.6, 9.4]:
		VmPlane.band(k, m, "gs_bf_j%.1f" % z, st, z, 0.03, 0.005, AIR, cj, 28)
	_bf_cockpit(k, m, st, c)
	_seam(k, m, "gs_bf_seam0", st, -7.8, 4.6, 3.65, cj)
	_bf_doors(k, m, st, armed, cj)
	# the sponsons: the main gear, fuel, the chaff and flare dispensers
	var sp := [[-6.6, 1.32, 0.05, 0.25, 0.25, 2, 2, 1.55], [-5.9, 1.3, 0.42, 0.7, 0.6, 2.2, 2.5, 1.75], [-4.6, 1.3, 0.62, 0.9, 0.7, 2.5, 3.0, 1.9],
		[1.0, 1.3, 0.66, 0.92, 0.7, 2.6, 3.0, 1.92], [2.4, 1.36, 0.5, 0.75, 0.6, 2.4, 2.6, 1.85], [3.3, 1.45, 0.08, 0.18, 0.15, 2, 2, 1.65]]
	VmPlane.body2(k, m, "gs_bf_spon", sp, AIR, cu, 20)
	for s: float in [-1.0, 1.0]:
		for z: float in [-1.8, 0.7]:
			k._box(m, Vector3(0.62, 0.012, 0.02), Vector3(s * 1.95, 0.605, z), AIR, cj, Vector3.ZERO, false)
		for x: float in [1.66, 2.24]:
			k._box(m, Vector3(0.02, 0.012, 2.5), Vector3(s * x, 0.605, -0.55), AIR, cj, Vector3.ZERO, false)
		k._box(m, Vector3(0.06, 0.34, 0.6), Vector3(s * 2.36, 1.2, 2.2), "gunmetal_w", null, Vector3(0, s * 0.3, 0), false)
		for i in 3:
			k._box(m, Vector3(0.02, 0.06, 0.45), Vector3(s * 2.39, 1.1 + i * 0.09, 2.2), "plain_dark", null, Vector3(0, s * 0.3, 0), false)
	# the wing: straight, a touch of forward sweep, thick; flaperons along it
	var ws := [[Vector3(0.0, 4.9, -2.25), 3.65, 0.82], [Vector3(1.6, 4.9, -2.3), 3.62, 0.8], [Vector3(8.95, 5.05, -3.05), 3.4, 0.72]]
	VmPlane.surf(k, m, "gs_bf_wing", ws, AIR, c, [0.0, 0.7])
	_wing_lines(k, m, "gs_bf_wl", ws, [2.2, 5.4, 7.6], [0.15, 0.62], 1.8, 8.8, 0.69, cj)
	if not olive:
		_under(k, m, "gs_bf_wingu", ws, 1.6, 8.95, cu)
	# the fairing over the wing's centre section
	VmPlane.body(k, m, "gs_bf_wfair", [[-4.2, 4.2, 0.0, 0.0, 0.0], [-3.3, 4.32, 0.75, 0.42, 0.2, 2.2, 2.0], [-2.0, 4.42, 1.15, 0.86, 0.2, 2.6, 2.0],
		[0.5, 4.45, 1.2, 0.92, 0.2, 2.7, 2.0], [2.0, 4.42, 1.1, 0.78, 0.2, 2.6, 2.0], [3.4, 4.32, 0.6, 0.36, 0.2, 2.3, 2.0], [4.4, 4.25, 0.0, 0.0, 0.0]], AIR, c, 22)
	# the nacelles on their tilt pivots at the tips, the proprotors (the
	# right one a mirror image, turning the other way)
	var g := _gear_node(k)
	for s: float in [-1.0, 1.0]:
		var tl := Tilt.new()
		tl.position = Vector3(s * 9.9, 5.1, -2.15)
		tl.gear = g
		m.add_child(tl)
		_bf_nacelle(k, tl, s, c, cj)
		_propeller(k, tl, "gs_bf_rotor" + ("R" if s > 0.0 else ""), Vector3(0, 0, -4.0), Vector3(0, PI, 0) if s > 0.0 else Vector3.ZERO, 8.1, 3,
			[0.0, 0.8, 0.07, 1.1, 0.3, 1.04, 0.6, 0.9, 0.85, 0.74, 0.96, 0.56, 1.0, 0.3], 0.78, 0.02, 0.12,
			0.96, 1.35, Color(0.19, 0.2, 0.21), c, 0.4 if s > 0.0 else 1.3, 1.0 if s > 0.0 else -1.0, 0.55)
	_bf_tail(k, m, c, cu, olive)
	# the dorsal spine from the wing back to the tail, the formation lights
	VmPlane.body(k, m, "gs_bf_spine", [[2.6, 4.22, 0.1, 0.05, 0.1], [3.6, 4.25, 0.5, 0.22, 0.1, 2.4, 2.0], [8.4, 4.25, 0.42, 0.2, 0.1, 2.4, 2.0],
		[9.9, 4.25, 0.05, 0.04, 0.1]], AIR, c, 16)
	var fl := Color(0.52, 0.62, 0.44)
	for s: float in [-1.0, 1.0]:
		var sfx := "L" if s < 0.0 else ""
		_patch(k, m, "gs_bf_fl0" + sfx, st, -8.15, -8.05, 2.0, 3.1, s < 0.0, "paint", fl, 0.01)
		_patch(k, m, "gs_bf_fl1" + sfx, st, 8.35, 8.45, 3.45, 4.1, s < 0.0, "paint", fl, 0.01)
		k._box(m, Vector3(0.012, 1.9, 0.08), Vector3(s * 4.23, 5.65, 11.25), "paint", fl, Vector3(0.48, 0, -s * 0.145), false)
	# the targeting turret under the nose, antennas, the beacons
	k._cyl(m, 0.22, 0.26, 0.3, Vector3(0, 0.82, -10.35), Vector3.ZERO, AIR, c)
	k._add(m, Res.sphere(0.4, 18), "paint", Color(0.46, 0.47, 0.48), Vector3(0, 0.58, -10.35))
	k._add(m, Res.sphere(0.17, 12), "glass", null, Vector3(0, 0.52, -10.7), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	k._add(m, Res.sphere(0.1, 10), "glass", null, Vector3(0.2, 0.62, -10.66), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	for z: float in [-6.4, -5.0, 6.0]:
		VmPlane.antenna(k, m, Vector3(0, 4.3, z), 0.36)
	for z: float in [-7.4, -3.4]:
		VmPlane.antenna(k, m, Vector3(0, 0.61, z), 0.3, true)
	k._add(m, Res.sphere(0.12, 10), "plain_dark", Color(0.5, 0.06, 0.05), Vector3(0, 4.29, -7.0), Vector3.ZERO, Vector3(1, 0.7, 1.3), false)
	k._add(m, Res.sphere(0.12, 10), "plain_dark", Color(0.5, 0.06, 0.05), Vector3(0, 0.59, -4.6), Vector3.ZERO, Vector3(1, 0.7, 1.3), false)
	k.gun_tip = k._tip(m, Vector3(0, 0.5, -10.8))
	if armed:
		_bf_guns(k, m, st, c)
	# team panels on the wings and the tail
	VmPlane.wing_marks(k, m, team, ws, 6.6, 1.15)
	for s: float in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * (_half_w(VmPlane.st_at(st, 7.0), 3.4) + 0.01), 3.4, 7.0), Vector3(0.02, 0.8, 0.9))
	_bf_gear(k, g, c)


## The Blackfish's flight deck: four big windscreen panes and their frames,
## the side windows, the chin windows low either side of the nose.
static func _bf_cockpit(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var cf := c.darkened(0.18)
	VmPlane.stripe(k, m, "gs_bf_ws", st, -10.85, -9.85, 0.42, PI - 0.42, "glass", null, 0.012, 18)
	for a: float in [PI / 2, 0.98, PI - 0.98]:
		VmPlane.stripe(k, m, "gs_bf_wsp%.2f" % a, st, -10.88, -9.82, a - 0.04, a + 0.04, AIR, cf, 0.024, 3)
	for z: float in [-10.86, -9.84]:
		VmPlane.stripe(k, m, "gs_bf_wsb%.2f" % z, st, z - 0.04, z + 0.04, 0.4, PI - 0.4, AIR, cf, 0.024, 18)
	for s: float in [-1.0, 1.0]:
		var left := s < 0.0
		var sfx := "L" if left else ""
		var sa := VmPlane.st_at(st, -9.25)
		VmPlane.stripe(k, m, "gs_bf_sw" + sfx, st, -9.78, -8.72, _ang(sa, 2.75, left), _ang(sa, 3.85, left), "glass", null, 0.012, 6)
		VmPlane.stripe(k, m, "gs_bf_swp" + sfx, st, -9.29, -9.21, _ang(sa, 2.7, left), _ang(sa, 3.9, left), AIR, cf, 0.024, 3)
		var sc := VmPlane.st_at(st, -10.45)
		VmPlane.stripe(k, m, "gs_bf_chin" + sfx, st, -10.8, -10.12, _ang(sc, 1.5, left), _ang(sc, 2.12, left), "glass", null, 0.012, 5)


## The Blackfish's doors and windows: the crew door forward on the right, a
## row of small cabin windows (only on the right of the gunship), the ramp
## and the upper ramp door under the tail.
static func _bf_doors(k: VehicleModels, m: Node3D, st: Array, armed: bool, cj: Color) -> void:
	_door(k, m, "gs_bf_crew", st, -7.55, -6.6, 0.85, 3.55, false, cj)
	_patch(k, m, "gs_bf_crewwin", st, -7.3, -6.85, 2.75, 3.25, false, "glass", null, 0.01)
	for s: float in [-1.0, 1.0]:
		for z: float in ([-4.6, -2.0, 0.6, 3.0] if s > 0.0 else ([-2.8, -0.2] if armed else [-5.4, -2.8, -0.2, 2.4])):
			_patch(k, m, "gs_bf_win%.1f%s" % [z, "L" if s < 0.0 else ""], st, z - 0.2, z + 0.2, 3.05, 3.45, s < 0.0, "glass", null, 0.01)
	for a: float in [-PI / 2 - 0.85, -PI / 2 + 0.85]:
		VmPlane.stripe(k, m, "gs_bf_ramp%.2f" % a, st, 4.6, 9.2, a - 0.018, a + 0.018, AIR, cj, 0.008, 3)
	for z: float in [4.6, 7.5, 9.2]:
		VmPlane.stripe(k, m, "gs_bf_rampx%.1f" % z, st, z - 0.03, z + 0.03, -PI / 2 - 0.85, -PI / 2 + 0.85, AIR, cj, 0.008, 10)


## A Blackfish nacelle in its tilt pivot's space (the nacelle along -z, the
## pivot at the wingtip): the proprotor gearbox behind the spinner, the
## engine body with its intake scoop on top and cooling grilles, the exhaust
## at the back, the navigation light on the outboard side (side s).
static func _bf_nacelle(k: VehicleModels, tl: Node3D, s: float, c: Color, cj: Color) -> void:
	var nst := [
		[-3.98, 0.0, 0.92, 0.92, 0.92, 2.0, 2.0],
		[-3.72, 0.0, 1.1, 1.1, 1.1, 2.0, 2.0],
		[-3.05, 0.0, 1.17, 1.19, 1.13, 2.1, 2.1],
		[-2.45, 0.0, 1.03, 1.06, 0.99, 2.1, 2.1],
		[-1.9, 0.02, 1.0, 1.12, 0.98, 2.2, 2.3],
		[0.4, 0.02, 0.98, 1.08, 0.96, 2.3, 2.3],
		[1.6, 0.0, 0.86, 0.9, 0.86, 2.2, 2.2],
		[2.3, 0.0, 0.6, 0.6, 0.6, 2.0, 2.0],
		[2.6, 0.0, 0.48, 0.48, 0.48, 2.0, 2.0],
	]
	VmPlane.body(k, tl, "gs_bf_nac", nst, AIR, c, 24)
	VmPlane.band(k, tl, "gs_bf_nacj0", nst, -2.42, 0.04, 0.006, AIR, cj, 24)
	VmPlane.band(k, tl, "gs_bf_nacj1", nst, 1.0, 0.04, 0.006, AIR, cj, 24)
	# the engine's intake scoop on top, dark inside
	var ist := [[-2.3, 0.9, 0.5, 0.28, 0.2, 2.4, 2.4], [-1.85, 0.95, 0.56, 0.34, 0.26, 2.4, 2.4], [-0.4, 0.92, 0.5, 0.3, 0.3, 2.4, 2.4], [0.5, 0.85, 0.2, 0.1, 0.2, 2.2, 2.2]]
	VmPlane.body(k, tl, "gs_bf_nacin", ist, AIR, c, 18)
	VmPlane.mouth(k, tl, "gs_bf_nacinm", ist[0], 0.8, -1.0, "plain_dark")
	# cooling grilles either side, the exhaust
	for sd: float in [-1.0, 1.0]:
		for i in 4:
			k._box(tl, Vector3(0.03, 0.42, 0.07), Vector3(sd * 0.98, 0.1, -1.1 + i * 0.16), "plain_dark", null, Vector3.ZERO, false)
	k._cyl(tl, 0.4, 0.46, 0.4, Vector3(0, 0, 2.75), Vector3(PI / 2, 0, 0), "gunmetal_w", c.darkened(0.5), 18)
	k._cyl(tl, 0.34, 0.34, 0.03, Vector3(0, 0, 2.95), Vector3(PI / 2, 0, 0), "plain_dark", null, 16, false)
	# the navigation light, green on the right, red on the left
	if not k.burnt:
		k._box(tl, Vector3(0.06, 0.12, 0.22), Vector3(s * 1.0, 0.0, -0.4), "paint", Color(0.15, 0.5, 0.2) if s > 0.0 else Color(0.6, 0.12, 0.1), Vector3.ZERO, false)


## The Blackfish's H tail: the stabiliser on top of the tail boom with its
## elevators, a canted fin with its rudder at each tip, the tail light.
static func _bf_tail(k: VehicleModels, m: Node3D, c: Color, cu: Color, olive: bool) -> void:
	var hs := [[Vector3(0.0, 4.35, 9.7), 2.3, 0.3], [Vector3(1.0, 4.4, 9.75), 2.25, 0.28], [Vector3(3.95, 4.45, 10.15), 1.9, 0.22]]
	VmPlane.surf(k, m, "gs_bf_stab", hs, AIR, c, [0.0, 0.68])
	if not olive:
		_under(k, m, "gs_bf_stabu", hs, 1.0, 3.95, cu)
	VmPlane.surf(k, m, "gs_bf_fin", [[Vector3(3.76, 3.0, 9.55), 2.05, 0.2], [Vector3(3.95, 4.45, 10.1), 2.15, 0.22], [Vector3(4.3, 6.85, 11.35), 1.4, 0.14],
		[Vector3(4.32, 6.98, 11.6), 1.1, 0.06]], AIR, c, [0.0, 0.64, 0.0])
	k._add(m, Res.sphere(0.07, 8), "paint", Color(0.9, 0.9, 0.85), Vector3(0, 3.86, 12.38), Vector3.ZERO, Vector3.ONE, false)


## The gunship's port side: the 40 mm cannon in its blister forward of the
## wing, and aft of the sponson the big mount with the 105 mm howitzer (recoil
## sleeve, double-baffle muzzle brake) and the 20 mm Gatling under it; a
## second sensor turret low on the port side of the nose.
static func _bf_guns(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var dep := 0.12
	var dn := Vector3(-cos(dep), -sin(dep), 0)
	var cb := c.darkened(0.08)
	# the 40 mm
	var z40 := -5.3
	var y40 := 3.0
	var x40 := _half_w(VmPlane.st_at(st, z40), y40)
	k._add(m, Res.sphere(0.62, 18), AIR, cb, Vector3(-x40 + 0.1, y40, z40), Vector3.ZERO, Vector3(0.62, 0.95, 1.1))
	var g40 := Vector3(-x40 - 0.36, y40, z40)
	k._box(m, Vector3(0.32, 0.34, 0.4), g40, "gunmetal_w", c.darkened(0.4), Vector3(0, 0, dep))
	VmPlane.rod(k, m, g40, g40 + dn * 0.95, 0.11, "gunmetal_w", null, 12)
	VmPlane.rod(k, m, g40, g40 + dn * 2.35, 0.065, "gunmetal_w", null, 10)
	VmPlane.rod(k, m, g40 + dn * 2.2, g40 + dn * 2.65, 0.09, "gunmetal_w", null, 12, 0.1)
	# the 105 mm and the 20 mm in the aft mount
	var zg := 3.75
	var yg := 2.6
	var xg := _half_w(VmPlane.st_at(st, zg), yg)
	k._add(m, Res.sphere(0.95, 20), AIR, cb, Vector3(-xg + 0.12, yg, zg), Vector3.ZERO, Vector3(0.6, 1.0, 1.12))
	k._box(m, Vector3(0.1, 1.2, 0.9), Vector3(-xg - 0.42, yg, zg), "plain_dark", null, Vector3(0, 0, dep), false)
	var g105 := Vector3(-xg - 0.45, yg + 0.22, zg)
	k._box(m, Vector3(0.5, 0.56, 0.62), g105, "gunmetal_w", c.darkened(0.4), Vector3(0, 0, dep))
	VmPlane.rod(k, m, g105, g105 + dn * 1.35, 0.21, "gunmetal_w", null, 14)
	VmPlane.rod(k, m, g105 + dn * 1.3, g105 + dn * 1.45, 0.23, "gunmetal_w", null, 14)
	VmPlane.rod(k, m, g105, g105 + dn * 3.3, 0.11, "gunmetal_w", null, 12)
	var mb := g105 + dn * 3.52
	k._box(m, Vector3(0.52, 0.34, 0.42), mb, "gunmetal_w", null, Vector3(0, 0, dep))
	for f: float in [-0.12, 0.12]:
		k._box(m, Vector3(0.13, 0.24, 0.432), mb + dn * f, "plain_dark", null, Vector3(0, 0, dep), false)
	k.gun_tip = k._tip(m, mb + dn * 0.28)
	var g20 := Vector3(-xg - 0.42, yg - 0.38, zg)
	k._box(m, Vector3(0.46, 0.3, 0.32), g20, "gunmetal_w", c.darkened(0.4), Vector3(0, 0, dep))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var o := Vector3(0, cos(a) * 0.075, sin(a) * 0.075)
		VmPlane.rod(k, m, g20 + o, g20 + o + dn * 1.55, 0.02, "gunmetal_w", null, 6, -1.0, false)
	for f: float in [0.6, 1.4]:
		k._add(m, Res.cyl(0.11, 0.11, 0.06, 12), "gunmetal_w", null, g20 + dn * f, Vector3(0, 0, PI / 2 + dep))
	k.mg_tip = k._tip(m, g20 + dn * 1.6)
	# the gunners' second sensor turret
	k._add(m, Res.sphere(0.3, 14), "paint", Color(0.46, 0.47, 0.48), Vector3(-1.45, 1.05, -8.3))
	k._add(m, Res.sphere(0.13, 10), "glass", null, Vector3(-1.7, 0.98, -8.3), Vector3.ZERO, Vector3(0.5, 1, 1), false)


## The Blackfish's landing gear (the "Gear" node, hidden in flight): twin nose
## wheels under the flight deck, a pair of wheels on a strut out of each
## sponson.
static func _bf_gear(k: VehicleModels, g: Node3D, c: Color) -> void:
	if g == null:
		return
	VmPlane.rod(k, g, Vector3(0, 1.2, -9.4), Vector3(0, 0.45, -9.4), 0.09, "steel", Color(0.6, 0.6, 0.58), 10)
	k._cyl(g, 0.05, 0.05, 0.6, Vector3(0, 0.45, -9.4), Vector3(0, 0, PI / 2), "steel", null, 8)
	for s: float in [-1.0, 1.0]:
		_tyre(k, g, Vector3(s * 0.24, 0.45, -9.4), 0.45, 0.28)
		k._box(g, Vector3(0.025, 0.5, 1.3), Vector3(s * 0.55, 0.55, -9.4), AIR, c, Vector3(0, 0, s * 0.12))
	k._box(g, Vector3(0.9, 0.02, 1.3), Vector3(0, 0.67, -9.4), "plain_dark", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		k._box(g, Vector3(0.62, 0.02, 2.55), Vector3(s * 1.95, 0.598, -0.55), "plain_dark", null, Vector3.ZERO, false)
		VmPlane.rod(k, g, Vector3(s * 1.95, 1.9, -0.55), Vector3(s * 1.95, 0.6, -0.55), 0.1, "steel", Color(0.6, 0.6, 0.58), 10)
		k._cyl(g, 0.06, 0.06, 0.9, Vector3(s * 1.95, 0.6, -0.55), Vector3(0, 0, PI / 2), "steel", null, 8)
		for o: float in [-0.25, 0.25]:
			_tyre(k, g, Vector3(s * 1.95 + o, 0.6, -0.55), 0.6, 0.34)


## A lower-surface overlay on a wing from span x0 to x1 (both sides): the
## underside in another colour, following the airfoil.
static func _under(k: VehicleModels, p: Node3D, key: String, secs: Array, x0: float, x1: float, col: Color) -> void:
	var fs := [0.0, 0.03, 0.1, 0.25, 0.45, 0.7, 0.98]
	for sd: float in [-1.0, 1.0]:
		var kk := key + ("L" if sd < 0.0 else "")
		if not _dc.has(kk):
			var vs := PackedVector3Array()
			for i in 4:
				for j in fs.size() - 1:
					var q := []
					for e in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
						var x := lerpf(x0, x1, float(e[0]) / 4.0)
						var f: float = fs[e[1]]
						var w := VmPlane.surf_at(secs, x)
						var le: Vector3 = w[0]
						q.append(Vector3(sd * x, le.y - VmPlane._foil_t(f) * float(w[2]) * 0.5 - 0.008, le.z + f * float(w[1])))
					vs.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
			_dc[kk] = _dmesh(vs)
		k._add(p, _dc[kk], AIR, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
