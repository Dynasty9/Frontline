class_name BuildingKerbside
extends RefCounted
## What stands at the kerb: street lamps (a town's steel columns, a village's
## lamp on a wooden pole, the square's lanterns), hydrants, stop signs, a
## farm's mailbox on its post, the electricity board's cabinet. Each in a kit
## at its foot; a lamp's arm reaches along +x, a sign or a cabinet faces -z.
## Their lenses glow from Decor (its _lens), where the lamp heads hang.

const COLUMN := Color(0.3, 0.32, 0.32)
const HERITAGE := Color(0.12, 0.16, 0.13)


## A town's street lamp: a steel column (a base with its service door, tapered
## up 6 m), an outreach arm sweeping up and out, the lantern at its end, its
## underside (the glow, 6.05 m up and 1.44 m out) a flat lens.
static func column(k: BuildingKit) -> void:
	k.cyl(0.17, 0.2, 0.9, Vector3(0, 0.45, 0), "metal_dark", COLUMN.darkened(0.1), Vector3.ZERO, 12)
	k.box(Vector3(0.14, 0.34, 0.02), Vector3(0, 0.5, -0.18), "metal_dark", COLUMN.darkened(0.2), Vector3.ZERO, false)
	k.cyl(0.19, 0.19, 0.04, Vector3(0, 0.92, 0), "metal_dark", COLUMN, Vector3.ZERO, 12, false)
	k.cyl(0.055, 0.1, 5.3, Vector3(0, 0.9 + 2.65, 0), "metal_dark", COLUMN, Vector3.ZERO, 10)
	# the arm: up out of the column's top, curving out to the lantern
	var prev := Vector3(0, 6.15, 0)
	for i in 6:
		var t := (i + 1) / 6.0
		var p := Vector3(1.2 * t, 6.15 + 0.2 * sin(t * PI * 0.5), 0)
		k.rod(prev, p, 0.04, "metal_dark", COLUMN, 8)
		prev = p
	# The socket drops into the cast head; the lens stays at its lighting anchor.
	k.rod(prev, Vector3(1.2, 6.21, 0), 0.04, "metal_dark", COLUMN, 8)
	# the lantern: a cast head, its lens under it
	k.part(Res.sphere(0.5, 10), "metal_dark", Transform3D(Basis.from_scale(Vector3(0.7, 0.18, 0.32)), Vector3(1.44, 6.17, 0)), COLUMN.lightened(0.05))
	k.box(Vector3(0.56, 0.05, 0.27), Vector3(1.44, 6.09, 0), "metal_dark", COLUMN.darkened(0.15), Vector3.ZERO, false)


## A village's lamp on its wooden pole: the pole, a steel bracket out from it,
## an enamelled shade over the bulb (its underside 5.33 m up, 1.0 m out).
static func pole_lamp(k: BuildingKit) -> void:
	k.cyl(0.085, 0.12, 6.0, Vector3(0, 3.0, 0), "wood_dark", Color(0.3, 0.24, 0.17), Vector3.ZERO, 8)
	k.rod(Vector3(0, 5.75, 0), Vector3(0.95, 5.75, 0), 0.025, "metal_dark", Color(0.2, 0.22, 0.21), 6)
	k.rod(Vector3(0, 5.3, 0), Vector3(0.6, 5.73, 0), 0.02, "metal_dark", Color(0.2, 0.22, 0.21), 6, false)
	k.cyl(0.03, 0.03, 0.18, Vector3(0.98, 5.65, 0), "metal_dark", Color(0.2, 0.22, 0.21), Vector3.ZERO, 6, false)
	k.cyl(0.06, 0.3, 0.16, Vector3(1.0, 5.47, 0), "paint", Color(0.22, 0.32, 0.25), Vector3.ZERO, 14)
	k.cyl(0.31, 0.31, 0.02, Vector3(1.0, 5.38, 0), "paint", Color(0.9, 0.9, 0.86), Vector3.ZERO, 14, false)


## A heritage lantern on the square: a cast base with its mouldings, a fluted
## column, the ladder bar under the lantern, the lantern (its glass, the
## glow, about 4.4 m up), its roof and finial.
static func lantern_post(k: BuildingKit) -> void:
	var c := HERITAGE
	k.cyl(0.2, 0.24, 0.12, Vector3(0, 0.06, 0), "metal_dark", c, Vector3.ZERO, 12)
	k.cyl(0.14, 0.2, 0.55, Vector3(0, 0.395, 0), "metal_dark", c, Vector3.ZERO, 12)
	k.cyl(0.17, 0.17, 0.06, Vector3(0, 0.7, 0), "metal_dark", c.lightened(0.05), Vector3.ZERO, 12, false)
	k.cyl(0.055, 0.075, 3.0, Vector3(0, 0.7 + 1.5, 0), "metal_dark", c, Vector3.ZERO, 10)
	for i in 8:
		var a := TAU * i / 8.0
		k.box(Vector3(0.012, 2.6, 0.012), Vector3(cos(a) * 0.07, 1.95, sin(a) * 0.07), "metal_dark", c.lightened(0.08), Vector3.ZERO, false)
	k.cyl(0.11, 0.08, 0.14, Vector3(0, 3.77, 0), "metal_dark", c, Vector3.ZERO, 10)
	k.rod(Vector3(-0.32, 3.9, 0), Vector3(0.32, 3.9, 0), 0.018, "metal_dark", c, 6, false)
	# the lantern: four glazed sides between its frame, its roof and finial
	k.cyl(0.16, 0.12, 0.08, Vector3(0, 4.0, 0), "metal_dark", c, Vector3(0, PI * 0.25, 0), 4)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.025, 0.5, 0.025), Vector3(sx * 0.15, 4.3, sz * 0.15), "metal_dark", c, Vector3.ZERO, false)
	k.cyl(0.0, 0.24, 0.22, Vector3(0, 4.66, 0), "metal_dark", c, Vector3(0, PI * 0.25, 0), 4)
	k.cyl(0.25, 0.25, 0.03, Vector3(0, 4.56, 0), "metal_dark", c.lightened(0.05), Vector3(0, PI * 0.25, 0), 4, false)
	k.part(Res.sphere(0.05, 6), "metal_dark", Transform3D(Basis.IDENTITY, Vector3(0, 4.83, 0)), c)


## A pillar hydrant: its flange on the pavement, the barrel, the bonnet
## with its operating nut, two hose outlets with their caps on chains.
static func hydrant(k: BuildingKit, col := Color(0.7, 0.12, 0.08)) -> void:
	k.cyl(0.17, 0.17, 0.05, Vector3(0, 0.025, 0), "paint", col.darkened(0.2), Vector3.ZERO, 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.cyl(0.02, 0.02, 0.03, Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14), "metal_dark", Color(0.2, 0.2, 0.2), Vector3.ZERO, 6, false)
	k.cyl(0.11, 0.12, 0.55, Vector3(0, 0.33, 0), "paint", col, Vector3.ZERO, 12)
	k.cyl(0.14, 0.14, 0.05, Vector3(0, 0.6, 0), "paint", col.darkened(0.08), Vector3.ZERO, 12, false)
	k.part(Res.sphere(0.12, 10), "paint", Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0, 0.64, 0)), col)
	k.cyl(0.03, 0.03, 0.06, Vector3(0, 0.74, 0), "metal_dark", Color(0.3, 0.3, 0.3), Vector3(0, PI * 0.2, 0), 5, false)
	for sx: float in [-1.0, 1.0]:
		k.cyl(0.045, 0.045, 0.1, Vector3(sx * 0.15, 0.42, 0), "paint", col, Vector3(0, 0, PI * 0.5), 10, false)
		k.cyl(0.055, 0.055, 0.04, Vector3(sx * 0.21, 0.42, 0), "metal_dark", Color(0.62, 0.55, 0.32), Vector3(0, 0, PI * 0.5), 6, false)
		k.rod(Vector3(sx * 0.21, 0.4, 0.03), Vector3(sx * 0.1, 0.5, 0.06), 0.005, "steel", Color(0.55, 0.55, 0.55), 3, false)


## Where the sign's face is: its middle's height, the red's radius to its
## corners (the white border runs out from it to 0.38), and where the red
## sheeting's face lies (z: the sign stands off the post towards -z).
const STOP_Y := 2.15
const STOP_RED := 0.355
const STOP_FACE := -0.069
## The legend's cap height: a third of the sign across its flats, as on a
## real one (10 inch letters on a 30 inch sign).
const STOP_CAP := 0.24


## A stop sign on its post: the red octagon in its white border, a bare
## galvanised back, its two brackets on the post. The face is reflective
## sheeting, not paint: flat colour that doesn't chip through or rust.
static func stop_sign(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.cyl(0.035, 0.035, 2.4, Vector3(0, 1.2, 0), "steel", Color(0.55, 0.56, 0.55), Vector3.ZERO, 8)
	# Turn the octagon within its own plane before tipping it upright, so
	# the face stays parallel to the lettering.
	var face := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI / 8.0)
	k.part(Res.cyl(0.39, 0.39, 0.02, 8), "steel", Transform3D(face, Vector3(0, STOP_Y, -0.05)), Color(0.6, 0.61, 0.6))
	k.part(Res.cyl(0.38, 0.38, 0.005, 8), "sheeting", Transform3D(face, Vector3(0, STOP_Y, -0.062)), Color(0.92, 0.92, 0.9), false)
	k.part(Res.cyl(STOP_RED, STOP_RED, 0.006, 8), "sheeting", Transform3D(face, Vector3(0, STOP_Y, STOP_FACE + 0.003)), Color(0.72, 0.07, 0.06), false)
	# The legend lies 3 mm proud of the red: flat, as printed, and far enough
	# off it that the depth buffer keeps the two apart at the battle camera's
	# distance (no shadow of its own: one 3 mm off the face would be acne).
	k.part(stop_letters(), "sheeting", Transform3D(Basis.IDENTITY, Vector3(0, STOP_Y, STOP_FACE - 0.003)), Color(0.95, 0.95, 0.92), false)
	for y: float in [1.98, 2.32]:
		k.box(Vector3(0.1, 0.03, 0.05), Vector3(0, y, -0.025), "steel", Color(0.5, 0.5, 0.5), Vector3.ZERO, false)


## STOP as road signs letter it, one cached mesh every sign shares: the
## highway sans (tall, upright, round-ended O, curved S, a P with a round
## bowl), its strokes about a sixth of the cap height, centred on the origin and
## facing -z. Seen from -z the word reads along -x.
static func stop_letters() -> ArrayMesh:
	return BuildingKit.shape("stop_word", func() -> Array:
		var stroke := 0.16
		var gap := 0.12
		var strokes: Array = []  # [closed, centre line], in cap heights, x as read
		var x := 0.0
		for ch in "STOP":
			var w := _stop_glyph(ch, stroke, x, strokes)
			x += w + gap
		# (centred on the word's middle, seen from -z: what reads left to
		# right runs along -x)
		var place := Transform2D(Vector2(-STOP_CAP, 0.0), Vector2(0.0, STOP_CAP), Vector2((x - gap) * 0.5 * STOP_CAP, -0.5 * STOP_CAP))
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		for st: Array in strokes:
			_ribbon(place * (st[1] as PackedVector2Array), stroke * STOP_CAP, st[0], v, n)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(m, arrays)
		return [[m, Transform3D.IDENTITY]])


## A letter's centre lines (cubic Bezier runs: a point, two controls, the
## next point...) into `out`, set at `x0`, over a cap height of 1; returns
## its width. The proportions follow the condensed highway alphabet a stop
## sign is lettered in, each letter about half as wide as it's tall.
static func _stop_glyph(ch: String, stroke: float, x0: float, out: Array) -> float:
	var h := stroke * 0.5  # (the centre lines run half a stroke in from the edges)
	var arm := 0.5523  # (a quarter ellipse's control arm, as a fraction of its radius)
	var o := Vector2(x0, 0.0)
	match ch:
		"S":
			# one run: the upper terminal, over the top, the spine across, round
			# the bottom to the lower terminal; the upper bowl a little the smaller
			out.append([false, _sample(o, [Vector2(0.415, 0.775), Vector2(0.405, 0.87), Vector2(0.345, 1.0 - h), Vector2(0.25, 1.0 - h),
				Vector2(0.15, 1.0 - h), Vector2(h, 0.865), Vector2(h, 0.735),
				Vector2(h, 0.6), Vector2(0.16, 0.555), Vector2(0.255, 0.515),
				Vector2(0.355, 0.475), Vector2(0.5 - h, 0.43), Vector2(0.5 - h, 0.28),
				Vector2(0.5 - h, 0.14), Vector2(0.355, h), Vector2(0.25, h),
				Vector2(0.145, h), Vector2(0.09, 0.125), Vector2(0.075, 0.235)])])
			return 0.5
		"T":
			out.append([false, _sample(o, _line(Vector2(0.0, 1.0 - h), Vector2(0.48, 1.0 - h)))])
			out.append([false, _sample(o, _line(Vector2(0.24, 0.0), Vector2(0.24, 1.0 - h)))])
			return 0.48
		"O":
			# straight sides, the ends half circles: a running track
			var w := 0.52
			var r := w * 0.5 - h
			var top := 1.0 - h - r
			var bot := h + r
			var c := w * 0.5
			var pts: Array = _line(Vector2(w - h, bot), Vector2(w - h, top))
			pts.append_array([Vector2(w - h, top + arm * r), Vector2(c + arm * r, 1.0 - h), Vector2(c, 1.0 - h),
				Vector2(c - arm * r, 1.0 - h), Vector2(h, top + arm * r), Vector2(h, top)])
			pts.append_array(_line(Vector2(h, top), Vector2(h, bot)).slice(1))
			pts.append_array([Vector2(h, bot - arm * r), Vector2(c - arm * r, h), Vector2(c, h),
				Vector2(c + arm * r, h), Vector2(w - h, bot - arm * r), Vector2(w - h, bot)])
			out.append([true, _sample(o, pts)])
			return w
		_:
			# P: the stem, and the bowl from its top round to its foot just under
			# the middle (its ends hidden in the stem, so its corners are square)
			var w := 0.48
			var foot := 0.44
			var ry := (1.0 - h - foot) * 0.5
			var rx := 0.16
			var bx := w - h - rx
			var cy := foot + ry
			out.append([false, _sample(o, _line(Vector2(h, 0.0), Vector2(h, 1.0)))])
			var pts: Array = _line(Vector2(h, 1.0 - h), Vector2(bx, 1.0 - h))
			pts.append_array([Vector2(bx + arm * rx, 1.0 - h), Vector2(w - h, cy + arm * ry), Vector2(w - h, cy),
				Vector2(w - h, cy - arm * ry), Vector2(bx + arm * rx, foot), Vector2(bx, foot)])
			pts.append_array(_line(Vector2(bx, foot), Vector2(h, foot)).slice(1))
			out.append([false, _sample(o, pts)])
			return w


## (a straight run as a Bezier piece: its controls on the line)
static func _line(a: Vector2, b: Vector2) -> Array:
	return [a, a.lerp(b, 1.0 / 3.0), a.lerp(b, 2.0 / 3.0), b]


## (Bezier pieces into points along the centre line, moved `by`; a straight
## piece one step, a curve eight)
static func _sample(by: Vector2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array([(pts[0] as Vector2) + by])
	for i in range(0, pts.size() - 1, 3):
		var p0: Vector2 = pts[i]
		var c0: Vector2 = pts[i + 1]
		var c1: Vector2 = pts[i + 2]
		var p1: Vector2 = pts[i + 3]
		var chord := (p1 - p0).normalized()
		var bend := maxf(absf(chord.cross(c0 - p0)), absf(chord.cross(c1 - p0)))
		var steps := 1 if bend < 0.0001 else 8
		for s in range(1, steps + 1):
			out.append(p0.bezier_interpolate(c0, c1, p1, float(s) / steps) + by)
	return out


## A flat stroke `width` wide along `line` in the z = 0 plane, facing -z:
## mitred where it bends, so it keeps its width round a curve, and cut
## square at its ends unless it's `closed`.
static func _ribbon(line: PackedVector2Array, width: float, closed: bool, v: PackedVector3Array, n: PackedVector3Array) -> void:
	var count := line.size()
	if closed and line[0].is_equal_approx(line[count - 1]):
		count -= 1
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in count:
		var prev: Vector2 = line[(i - 1 + count) % count] if closed or i > 0 else line[0]
		var next: Vector2 = line[(i + 1) % count] if closed or i < count - 1 else line[count - 1]
		var a: Vector2 = (line[i] - prev).normalized() if i > 0 or closed else (next - line[i]).normalized()
		var b: Vector2 = (next - line[i]).normalized() if i < count - 1 or closed else a
		var across := (a.orthogonal() + b.orthogonal()).normalized()
		var reach := width * 0.5 / maxf(across.dot(a.orthogonal()), 0.3)
		var p := line[i]
		left.append(Vector3(p.x + across.x * reach, p.y + across.y * reach, 0.0))
		right.append(Vector3(p.x - across.x * reach, p.y - across.y * reach, 0.0))
	for i in (count if closed else count - 1):
		var j := (i + 1) % count
		for tri: Array in [[left[i], left[j], right[j]], [left[i], right[j], right[i]]]:
			# (wound so the front faces -z, whichever way the line runs)
			var a3: Vector3 = tri[0]
			var b3: Vector3 = tri[1]
			var c3: Vector3 = tri[2]
			v.append_array([a3, c3, b3] if (b3 - a3).cross(c3 - a3).z < 0.0 else [a3, b3, c3])
			n.append_array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])


## A farm's mailbox on its post: the round-topped box, its door, the red
## flag at its side (up or down), the post with a brace.
static func mailbox(k: BuildingKit, col: Color, up: bool) -> void:
	k.box(Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), "wood_dark", Color(0.32, 0.25, 0.17))
	k.box(Vector3(0.06, 0.04, 0.4), Vector3(0, 0.97, 0), "wood_dark", Color(0.32, 0.25, 0.17))
	k.box(Vector3(0.22, 0.16, 0.44), Vector3(0, 1.07, 0), "car_paint", col)
	k.cyl(0.11, 0.11, 0.44, Vector3(0, 1.15, 0), "car_paint", col, Vector3(PI * 0.5, 0, 0), 12)
	k.box(Vector3(0.21, 0.24, 0.02), Vector3(0, 1.09, -0.22), "car_paint", col.darkened(0.1), Vector3.ZERO, false)
	var flag := Basis(Vector3.RIGHT, 0.0 if up else PI * 0.5)
	k.part(Res.box(Vector3(0.012, 0.22, 0.03)), "paint", Transform3D(flag, Vector3(0.125, 1.1, 0.1)) * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Color(0.82, 0.12, 0.08), false)
	k.part(Res.box(Vector3(0.012, 0.08, 0.1)), "paint", Transform3D(flag, Vector3(0.125, 1.1, 0.1)) * Transform3D(Basis.IDENTITY, Vector3(0, 0.19, 0.03)), Color(0.82, 0.12, 0.08), false)


## The electricity board's cabinet: green steel on a concrete plinth, double
## doors with their handle and lock, louvres low and high for its cooling, a
## danger plate, its roof overhanging.
static func cabinet(k: BuildingKit) -> void:
	var g := Color(0.3, 0.4, 0.3)
	k.box(Vector3(1.2, 0.12, 0.7), Vector3(0, 0.06, 0), "concrete", Color(0.5, 0.5, 0.48))
	k.box(Vector3(1.1, 1.3, 0.6), Vector3(0, 0.77, 0), "paint", g)
	k.box(Vector3(1.18, 0.05, 0.68), Vector3(0, 1.445, 0), "paint", g.darkened(0.12))
	k.plate(Vector3(0.012, 1.18, 0.008), Vector3(0, 0.77, -0.302), "paint", g.darkened(0.3))
	for sx: float in [-1.0, 1.0]:
		BuildingOpenings.louvre(k.at_point(Vector3(sx * 0.27, 0, -0.302), Vector3(0, PI, 0)), Vector3(0, 0.35, 0), Vector2(0.36, 0.2), g.darkened(0.2), "paint")
		BuildingOpenings.louvre(k.at_point(Vector3(sx * 0.27, 0, -0.302), Vector3(0, PI, 0)), Vector3(0, 1.22, 0), Vector2(0.36, 0.14), g.darkened(0.2), "paint")
		k.box(Vector3(0.03, 0.14, 0.03), Vector3(sx * 0.05, 0.85, -0.31), "metal_dark", Color(0.18, 0.18, 0.18), Vector3.ZERO, false)
	k.plate(Vector3(0.2, 0.15, 0.006), Vector3(0.27, 0.9, -0.305), "paint", Color(0.95, 0.8, 0.1))
	k.prism(Vector3(0.1, 0.07, 0.004), Vector3(0.27, 0.91, -0.309), "plain_dark", Color(0.05, 0.05, 0.05), Vector3(PI, 0, 0), false)
