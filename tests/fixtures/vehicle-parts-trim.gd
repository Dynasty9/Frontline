extends Node
## Trim and fittings of the third construction pass: number plates, medical
## crosses and stencil lettering (VehicleMarkings), lever handles, piano
## hinges and sliding-door rails (VehicleDoors), bow eyes and fenders
## (VehicleMarine). Each folds into its parent, registers no wheels, stays
## inside an envelope close to the geometry it replaces and takes the burnt
## material (or, for paint, is gone) on a wreck. The shared lettering lays out
## every family's numbers exactly as the four copies it replaces did.

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

## Every noted part, in root coordinates, whichever pivot it is noted on.
func parts(k: VehicleModels) -> Array:
	var out := []
	for node: Node3D in k._parts:
		var xf := Transform3D.IDENTITY
		var n := node
		while n and n != k.root:
			xf = n.transform * xf
			n = n.get_parent() as Node3D
		for part: Array in k._parts[node]:
			var local: Transform3D = Transform3D(part[7], part[4]) if part[7] is Basis else Mats.place(part[4], part[5], part[6])
			out.append([part, xf * local])
	return out

func bounds(k: VehicleModels) -> AABB:
	var box := AABB()
	var first := true
	for entry: Array in parts(k):
		var xf: Transform3D = entry[1]
		var aabb := xf * ((entry[0] as Array)[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func vertices(k: VehicleModels) -> int:
	var count := 0
	for entry: Array in parts(k):
		var mesh: Mesh = (entry[0] as Array)[0]
		for i in mesh.get_surface_count():
			count += (Mats._flat(mesh, i)[0] as PackedVector3Array).size()
	return count

func count_material(k: VehicleModels, kind: String) -> int:
	var m := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for entry: Array in parts(k):
		if (entry[0] as Array)[1] == m:
			n += 1
	return n

## The box of `size` round `center` turned by `basis`, as an AABB.
func turned(center: Vector3, size: Vector3, basis: Basis) -> AABB:
	var box := AABB(center, Vector3.ZERO)
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				box = box.expand(center + basis * Vector3(size.x * x, size.y * y, size.z * z))
	return box

func check(k: VehicleModels, envelope: AABB, label: String) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.antennas.is_empty(), label + ": static parts must not register animation")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s verts=%d parts=%d" % [label, box, vertices(k), parts(k).size()])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for entry: Array in parts(k):
			assert((entry[0] as Array)[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

## Paint that is gone on a wreck: nothing built, nothing left behind.
func gone(k: VehicleModels, label: String) -> void:
	assert(parts(k).is_empty() and k.root.get_child_count() == 0, label + ": a wreck's paint is gone")
	k.root.free()

# --- the four families' lettering as it was -------------------------------------

const ATTACK_SEGS := {"a": [0.0, 1.0, 1.0, 1.0], "b": [1.0, 1.0, 1.0, 0.5], "c": [1.0, 0.5, 1.0, 0.0], "d": [0.0, 0.0, 1.0, 0.0],
	"e": [0.0, 0.0, 0.0, 0.5], "f": [0.0, 0.5, 0.0, 1.0], "g": [0.0, 0.5, 0.85, 0.5], "i": [0.5, 0.0, 0.5, 1.0]}
const ATTACK_GLYPHS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc",
	"8": "abcdefg", "9": "abcdfg", "A": "abcefg", "F": "afeg", "T": "ai", "-": "g", "C": "afed", "E": "afedg", "U": "bcdef", "S": "afgcd"}

func attack_strokes(strokes: Array, lw: float, piece := 0.12) -> Array:
	var out: Array = []
	for s in strokes:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var nn := Vector2(-d.y, d.x) * lw * 0.5
		a -= d * lw * 0.5
		b += d * lw * 0.5
		var n := maxi(1, ceili(a.distance_to(b) / piece))
		for i in n:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			out.append([p0 - nn, p1 - nn, p1 + nn, p0 + nn])
	return out

func attack_text(text: String, h: float, cx: float, cy: float) -> Array:
	var cw := h * 0.58
	var adv := cw + h * 0.28
	var total := adv * text.length() - h * 0.28
	var st: Array = []
	for i in text.length():
		var ch := text[i]
		if not ATTACK_GLYPHS.has(ch):
			continue
		var x0 := cx - total * 0.5 + adv * i
		for sname in String(ATTACK_GLYPHS[ch]):
			var s: Array = ATTACK_SEGS[sname]
			st.append([Vector2(x0 + float(s[0]) * cw, cy - h * 0.5 + float(s[1]) * h), Vector2(x0 + float(s[2]) * cw, cy - h * 0.5 + float(s[3]) * h)])
	return attack_strokes(st, h * 0.13, h * 0.2)

const GUNSHIP_SEGS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg",
	"9": "abcdfg", "A": "abcefg", "F": "aefg"}

func gunship_ribbon(out: PackedVector2Array, pts: PackedVector2Array, w: float, closed: bool) -> void:
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

func gunship_text(txt: String, h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cw := h * 0.55
	var adv := h * 0.82
	var x0 := -float(txt.length()) * adv * 0.5 + (adv - cw) * 0.5
	var pts := {"a": [Vector2(0, 1), Vector2(1, 1)], "b": [Vector2(1, 1), Vector2(1, 0.5)], "c": [Vector2(1, 0.5), Vector2(1, 0)], "d": [Vector2(1, 0), Vector2(0, 0)],
		"e": [Vector2(0, 0), Vector2(0, 0.5)], "f": [Vector2(0, 0.5), Vector2(0, 1)], "g": [Vector2(0, 0.5), Vector2(1, 0.5)]}
	for i in txt.length():
		var ch := txt[i]
		if not GUNSHIP_SEGS.has(ch):
			continue
		for sg in String(GUNSHIP_SEGS[ch]):
			var e: Array = pts[sg]
			var o := Vector2(x0 + float(i) * adv - (cw * 0.4 if ch == "1" else 0.0), -h * 0.5)
			var pa: Vector2 = o + Vector2(e[0].x * cw, e[0].y * h)
			var pb: Vector2 = o + Vector2(e[1].x * cw, e[1].y * h)
			var d := (pb - pa).normalized()
			gunship_ribbon(out, PackedVector2Array([pa - d * h * 0.06, pb + d * h * 0.06]), h * 0.13, false)
	return out

const SHIP_SEGS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}

## VmShips._digits' painted bars: [centre along the line, centre height, width, height].
func ship_digits(text: String, h: float) -> Array:
	var w := h * 0.56
	var th := h * 0.16
	var pitch := h * 0.78
	var n := text.length()
	var out := []
	for i in n:
		var c := text[i]
		var ox := (i - (n - 1) * 0.5) * pitch
		var strokes := []
		if c == "1":
			strokes.append([0.0, 0.0, th, h])
		else:
			for sg in String(SHIP_SEGS.get(c, "")):
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
			out.append([ox + float(q[0]), float(q[1]), float(q[2]), float(q[3])])
	return out

const FIGHTER_FONT := {
	"W": [[0, 1, 0.15, 0], [0.15, 0, 0.3, 0.62], [0.3, 0.62, 0.45, 0], [0.45, 0, 0.6, 1]],
	"N": [[0, 0, 0, 1], [0, 1, 0.55, 0], [0.55, 0, 0.55, 1]],
	"H": [[0, 0, 0, 1], [0.55, 0, 0.55, 1], [0, 0.5, 0.55, 0.5]],
	"1": [[0.3, 0, 0.3, 1], [0.3, 1, 0.1, 0.8]],
	"0": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0]],
	"6": [[0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0, 0.5, 0], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0, 0.5]],
	"8": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0.5, 0.5, 0.5]],
	"9": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0.5], [0, 0.5, 0.5, 0.5]],
}

## VmFighter._text's strokes in the text's plane (x along it, y up from its
## baseline), before it lays them on the skin.
func fighter_strokes(txt: String, h: float) -> Array:
	var out := []
	var wide := 0.0
	for ch in txt:
		wide += 0.62 if ch != "1" else 0.42
	var cx := -(wide - 0.06) * 0.5
	for ch in txt:
		for sg in FIGHTER_FONT.get(ch, []):
			out.append([Vector2((cx + float(sg[0])) * h, float(sg[1]) * h), Vector2((cx + float(sg[2])) * h, float(sg[3]) * h)])
		cx += 0.62 if ch != "1" else 0.42
	return out

func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.00001

## Each polygon of `a` has one in `b` with the same corners (in any order).
func same_polygons(a: Array, b: Array, label: String) -> void:
	assert(a.size() == b.size(), "%s: %d polygons, expected %d" % [label, a.size(), b.size()])
	var used := {}
	for pa: Array in a:
		var found := -1
		for j in b.size():
			if used.has(j) or (b[j] as Array).size() != pa.size():
				continue
			var all := true
			for p: Vector2 in pa:
				var hit := false
				for q: Vector2 in b[j]:
					hit = hit or near(p, q)
				all = all and hit
			if all:
				found = j
				break
		assert(found >= 0, "%s: a stroke moved: %s" % [label, pa])
		used[found] = true

func triangles(flat: PackedVector2Array) -> Array:
	var out := []
	for i in range(0, flat.size(), 3):
		out.append([flat[i], flat[i + 1], flat[i + 2]])
	return out

## The shared lettering reproduces each family's numbers: the same strokes,
## triangles or bars as the copies it replaces.
func lettering() -> void:
	for t: Array in [["FT", 0.62, 0.0, 2.72], ["AF 1234", 0.13, 0.05, 2.2], ["USAF", 0.72, 0.0, 0.0], ["AT", 0.42, 0.0, 0.85], ["0123456789", 0.11, 0.0, 0.45], ["CE-SU T", 0.3, 0.2, -0.1]]:
		var text: String = t[0]
		same_polygons(VehicleMarkings.digit_quads(text, t[1], Vector2(t[2], t[3]), "stencil"), attack_text(text, t[1], t[2], t[3]), "stencil " + text)
	for t: Array in [["AF 90", 0.3], ["0163", 0.52], ["1A 8F", 0.4]]:
		var text: String = t[0]
		var h: float = t[1]
		var ours := VehicleMarkings.stroke_triangles(VehicleMarkings.digit_strokes(text, h, Vector2.ZERO, "tail"), h * 0.13, h * 0.06)
		same_polygons(triangles(ours), triangles(gunship_text(text, h)), "tail " + text)
	for t: Array in [["147", 0.5], ["1908", 0.8], ["2356", 0.42]]:
		var text: String = t[0]
		var h: float = t[1]
		var bars := VehicleMarkings.stroke_rects(VehicleMarkings.digit_strokes(text, h, Vector2.ZERO, "hull"), h * 0.16)
		var old := ship_digits(text, h)
		assert(bars.size() == old.size(), "hull %s: %d bars, expected %d" % [text, bars.size(), old.size()])
		for q: Array in old:
			var found := false
			for r: Rect2 in bars:
				found = found or (near(r.get_center(), Vector2(q[0], q[1])) and near(r.size, Vector2(q[2], q[3])))
			assert(found, "hull %s: a bar moved: %s" % [text, q])
	for t: Array in [["WN 1068", 0.9], ["H 9", 0.35]]:
		var text: String = t[0]
		var h: float = t[1]
		var ours := VehicleMarkings.digit_strokes(text, h, Vector2(0, h * 0.5), "stroke")
		var old := fighter_strokes(text, h)
		assert(ours.size() == old.size(), "stroke %s: %d strokes, expected %d" % [text, ours.size(), old.size()])
		for i in old.size():
			assert(near(ours[i][0], old[i][0]) and near(ours[i][1], old[i][1]), "stroke %s: stroke %d moved" % [text, i])
	# The builder lays the stencil on a skin, and the paint is gone on a wreck.
	for burnt in [false, true]:
		var k := kit(burnt)
		VehicleMarkings.digits(k, k.root, "AF 90", 0.3, func(q: Vector2) -> Vector3: return Vector3(1.5, 2.0 + q.y, -q.x), Vector3.RIGHT, Color(0.2, 0.2, 0.2))
		if burnt:
			gone(k, "digits")
		else:
			check(k, AABB(Vector3(1.5, 1.83, -0.623), Vector3(0.0, 0.34, 1.246)), "digits")

## A plate's raised characters: which side of the plate (in its parent's
## coordinates, along `across`) the fewer vertices sit on.
func sparse_side(k: VehicleModels, center: Vector3, across: Vector3) -> float:
	var left := 0
	var right := 0
	var ink := Mats.get_mat(VehicleMaterials.key("paint", k.surface_family))
	for entry: Array in parts(k):
		var part: Array = entry[0]
		if not (part[0] is ArrayMesh) or part[1] != ink:
			continue
		for v: Vector3 in Mats._flat(part[0], 0)[0]:
			if ((entry[1] as Transform3D) * v - center).dot(across) < 0.0:
				left += 1
			else:
				right += 1
	k.root.free()
	return -1.0 if left < right else 1.0

func _ready() -> void:
	TestRun.watch()
	lettering()
	var olive := Color(0.3, 0.33, 0.22)
	assert(VehicleMarkings._registration(Vector3(0, 0.62, -2.5), Vector2(0.52, 0.12)) == VehicleMarkings._registration(Vector3(0, 0.62, -2.5), Vector2(0.52, 0.12)), "a plate's registration is fixed by where it is")
	# A rear plate reads left to right from behind: its "1" on the left (-x),
	# a front plate's on its left seen from ahead (+x).
	var k := kit()
	VehicleMarkings.plate(k, k.root, Vector3(0, 0.79, 2.515), Vector2(0.52, 0.12), Vector3.BACK, 0.0, "1  8")
	assert(sparse_side(k, Vector3(0, 0.79, 2.515), Vector3.RIGHT) < 0.0, "a rear plate reads from behind")
	k = kit()
	VehicleMarkings.plate(k, k.root, Vector3(0, 0.6, -2.075), Vector2(0.52, 0.12), Vector3.FORWARD, 0.0, "1  8")
	assert(sparse_side(k, Vector3(0, 0.6, -2.075), Vector3.RIGHT) > 0.0, "a front plate reads from ahead")
	for burnt in [false, true]:
		# Number plates: a civilian front plate raked with its bumper, a rear
		# one, the small one on a quad, a bare military plate on a bumper; each
		# within its old box but for its screw heads and embossing.
		k = kit(burnt)
		k.surface_family = "automotive"
		VehicleMarkings.plate(k, k.root, Vector3(0, 0.62, -2.5), Vector2(0.52, 0.12), Vector3.FORWARD, 0.2)
		check(k, turned(Vector3(0, 0.62, -2.5), Vector3(0.52, 0.12, 0.016 + 0.008), Basis(Vector3.RIGHT, 0.2)), "front plate")
		k = kit(burnt)
		k.surface_family = "automotive"
		VehicleMarkings.plate(k, k.root, Vector3(0, 0.79, 2.515), Vector2(0.52, 0.12), Vector3.BACK, 0.0, "CE 4821")
		check(k, AABB(Vector3(-0.26, 0.73, 2.503), Vector3(0.52, 0.12, 0.024)), "rear plate")
		k = kit(burnt)
		k.surface_family = "automotive"
		VehicleMarkings.plate(k, k.root, Vector3(-0.22, 0.66, 1.005), Vector2(0.2, 0.12), Vector3.BACK)
		check(k, AABB(Vector3(-0.32, 0.6, 0.993), Vector3(0.2, 0.12, 0.024)), "small plate")
		k = kit(burnt)
		VehicleMarkings.plate(k, k.root, Vector3(0, 0.98, -2.8), Vector2(0.44, 0.12), Vector3.FORWARD, 0.0, "", 0.02, Color(0.82, 0.8, 0.72), VehicleMarkings.PLATE_INK, false)
		check(k, AABB(Vector3(-0.22, 0.92, -2.814), Vector3(0.44, 0.12, 0.028)), "military plate")
		# Medical crosses: the HEMTT's removable board on its side, bolted; the
		# CSAT panel laid on the box's back; the van's red cross straight on
		# its white side. Each is gone with the paint on a wreck, or burnt
		# whole when asked to stay.
		k = kit(burnt)
		VehicleMarkings.cross(k, k.root, Vector3(1.23, 2.2, 3.6), Vector2(1.0, 1.0), Vector3(0, PI / 2, 0), VehicleMarkings.CROSS_GROUND, VehicleMarkings.CROSS_RED, 0.7, 0.22, 0.02, "plain", true)
		if burnt:
			gone(k, "board cross")
		else:
			assert(count_material(k, "paint") == 1, "one painted cross, not overlapping bars")
			check(k, AABB(Vector3(1.22, 1.7, 3.1), Vector3(0.024, 1.0, 1.0)), "board cross")
		k = kit(burnt)
		VehicleMarkings.cross(k, k.root, Vector3(0.75, 2.6, 4.456), Vector2(0.62, 0.62), Vector3.ZERO, Color(0.72, 0.7, 0.64), Color(0.48, 0.09, 0.07), 0.742, 0.226, 0.012)
		if burnt:
			gone(k, "panel cross")
		else:
			check(k, AABB(Vector3(0.44, 2.29, 4.45), Vector3(0.62, 0.62, 0.0135)), "panel cross")
		k = kit(burnt)
		VehicleMarkings.cross(k, k.root, Vector3(0.994, 1.78, 1.05), Vector2(0.42, 0.42), Vector3(0, PI / 2, 0), null, Color(0.62, 0.1, 0.08), 1.0, 0.31, 0.012, "paint", false, false)
		check(k, AABB(Vector3(0.988, 1.57, 0.84), Vector3(0.012, 0.42, 0.42)), "painted cross")
		# Lever handles: the Marshall's stub (4 x 8 cm, standing 10 cm off its
		# door) becomes a lever as far out, hanging down toward its keeper; the
		# Ifrit's bar lying along its door keeps the bar's length and depth.
		k = kit(burnt)
		VehicleDoors.lever(k, k.root, Vector3(0.18, 1.45, 3.93), Vector3.BACK, Vector3.DOWN, 0.12, 0.1, 0.02)
		check(k, AABB(Vector3(0.145, 1.33, 3.93), Vector3(0.07, 0.155, 0.1)), "rear lever")
		k = kit(burnt)
		VehicleDoors.lever(k, k.root, Vector3(1.16, 1.38, 0.505), Vector3.RIGHT, Vector3.BACK, 0.125, 0.04, 0.02, "paint", olive)
		check(k, AABB(Vector3(1.16, 1.345, 0.47), Vector3(0.04, 0.07, 0.16)), "side lever")
		# Piano hinges: the BTR's fold-down step along its foot, the trim vane's
		# across a glacis.
		k = kit(burnt)
		VehicleDoors.piano_hinge(k, k.root, Vector3(1.27, 0.72, -0.49), Vector3(1.27, 0.72, 0.01), 0.02, Vector3.RIGHT)
		check(k, AABB(Vector3(1.25, 0.672, -0.497), Vector3(0.044, 0.096, 0.514)), "piano hinge")
		var glacis := Vector3(0, 0.65, -0.66).normalized()
		k = kit(burnt)
		VehicleDoors.piano_hinge(k, k.root, Vector3(-1.0, 1.3, -3.72), Vector3(1.0, 1.3, -3.72), 0.035, glacis, "paint", olive)
		check(k, AABB(Vector3(-1.013, 1.21, -3.81), Vector3(2.026, 0.18, 0.18)), "trim vane hinge")
		# A helicopter's sliding-door rail on a curved side (a cylinder 1.2 m
		# round), within the old strip's lift and seat.
		k = kit(burnt)
		k.surface_family = "aircraft"
		var side := VehicleSurface.new(func(q: Vector2) -> Vector3:
			var a := lerpf(0.9, 0.98, q.y)
			return Vector3(cos(a) * 1.2, 1.0 + sin(a) * 1.2, lerpf(-2.85, 0.3, q.x)), Vector3.RIGHT)
		VehicleDoors.slide_rail(k, k.root, side, 3.15, 0.02, 0.03)
		check(k, AABB(Vector3(0.65, 1.915, -2.851), Vector3(0.115, 0.105, 3.152)), "slide rail")
		# Bow eyes: a motorboat's on its stem, a jet ski's stern eye stood up
		# off the transom.
		k = kit(burnt)
		k.surface_family = "marine"
		VehicleMarine.bow_eye(k, k.root, Vector3(0, 0.56, -2.4), 0.022, 0.045, Vector3.FORWARD, Vector3.RIGHT, "steel", Color(0.75, 0.76, 0.76))
		check(k, AABB(Vector3(-0.0184, 0.4874, -2.445), Vector3(0.0368, 0.1452, 0.09)), "bow eye")
		k = kit(burnt)
		k.surface_family = "marine"
		VehicleMarine.bow_eye(k, k.root, Vector3(0, 0.36, 1.493), 0.016, 0.03, Vector3.BACK)
		check(k, AABB(Vector3(-0.0112, 0.3132, 1.463), Vector3(0.0224, 0.0936, 0.06)), "stern eye")
		# Fenders: two stowed on a motorboat's sole with coloured ends, one hung
		# over a patrol boat's side on its line, a trawler's tyre on its rope.
		k = kit(burnt)
		k.surface_family = "marine"
		var rot := Vector3(PI / 2, 0.25, 0)
		VehicleMarine.fender(k, k.root, Vector3(-0.62, 0.6, 1.45), 0.075, 0.46, rot, Color(0.86, 0.86, 0.83), Color(0.2, 0.3, 0.55))
		check(k, turned(Vector3(-0.62, 0.6, 1.45), Vector3(0.15, 0.46 + 0.075 * 1.1, 0.15), Basis.from_euler(rot)), "stowed fender")
		k = kit(burnt)
		k.surface_family = "marine"
		VehicleMarine.fender(k, k.root, Vector3(2.3, 1.2, 8.2), 0.13, 0.75, Vector3.ZERO, Color(0.2, 0.25, 0.33), null, Vector3(2.2, 2.0, 8.2))
		check(k, AABB(Vector3(2.17, 0.75, 8.07), Vector3(0.26, 1.26, 0.26)), "hung fender")
		k = kit(burnt)
		k.surface_family = "marine"
		var hang := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2)
		VehicleMarine.fender(k, k.root, Vector3(2.6, 1.6, -3.2), 0.36, 0.208, hang.get_euler(), Color(0.08, 0.08, 0.08), null, Vector3(2.45, 2.4, -3.2), "tyre")
		check(k, AABB(Vector3(2.435, 1.24, -3.56), Vector3(0.285, 1.175, 0.72)), "tyre fender")
	print("VEHICLE_PARTS_TRIM passed")
	TestRun.quit(get_tree())
