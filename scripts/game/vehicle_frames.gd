class_name VehicleFrames
extends RefCounted
## Structural members in the supplied parent's coordinates, baked like other
## opaque parts. Family builders own their layout; these helpers own the joins.

static func aim(direction: Vector3) -> Basis:
	var y := direction.normalized()
	if y.is_zero_approx():
		return Basis.IDENTITY
	return Basis(Quaternion(Vector3.RIGHT, PI)) if y.dot(Vector3.UP) < -0.9999 else Basis(Quaternion(Vector3.UP, y))


## A round bar from `a` to `b`, `radius` at a and `end_radius` at b (-1: the
## same). `caps` closes its ends: 1 the end at b, 2 the end at a, 3 both, 0
## neither (a bar whose ends are buried in what it joins).
static func tube(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: String, col = null, segments := 8, shadow := true, end_radius := -1.0, caps := 3) -> Variant:
	if a.distance_squared_to(b) < 0.00000001:
		return null
	return k._add(parent, rod_mesh(end_radius if end_radius >= 0 else radius, radius, a.distance_to(b), segments, caps), mat, col, (a + b) * 0.5, aim(b - a).get_euler(), Vector3.ONE, shadow)


## A straight-sided cylinder along local Y, `top` its radius at +Y. A straight
## side needs no rings between its ends (CylinderMesh's default ring only adds
## vertices), and `caps` keeps just the ends that can show: 1 the top, 2 the
## bottom, 3 both. Sized as Res.cyl sizes the same values, so a part made from
## it keeps the old part's extent exactly.
static func rod_mesh(top: float, bottom: float, height: float, segments := 8, caps := 3) -> CylinderMesh:
	var base := Res.cyl(top, bottom, height, segments)
	return VehicleBody.drum(base.top_radius, base.bottom_radius, base.height, segments, (caps & 1) != 0, (caps & 2) != 0)


## k._cyl on a rod_mesh: the same part, without the hidden middle ring and with
## only the caps (as rod_mesh takes them) that can show.
static func cyl(k: VehicleModels, parent: Node3D, top: float, bottom: float, height: float, position: Vector3, rotation: Vector3, mat: String, col = null, segments := 12, shadow := true, caps := 3) -> Variant:
	return k._add(parent, rod_mesh(top, bottom, height, segments, caps), mat, col, position, rotation, Vector3.ONE, shadow)


static func beam(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float, mat: String, col = null, shadow := true, level := false) -> Variant:
	if a.distance_squared_to(b) < 0.00000001:
		return null
	var basis := aim(b - a)
	if level:
		var y := (b - a).normalized()
		var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var z := ref.cross(y).normalized()
		basis = Basis(y.cross(z), y, z)
	return k._box(parent, Vector3(width, a.distance_to(b), depth), (a + b) * 0.5, mat, col, basis.get_euler(), shadow)


## A tube bent through `points`. Where it bends gently its straight pieces run
## on into each other just far enough to close the outside of the bend, as one
## bent bar would. A thin tube's corner (45 to 95 degrees, under 2.4 cm across)
## is bent round as a handle or a pressed bead is, through two gentle bends a
## radius and a half from the corner, where its legs are long enough; any other
## corner too sharp to close that way (over 95 degrees, or over 45 on a thicker
## tube, which reads as a jointed knuckle) gets a ball, as every joint once had.
## An end run on into the next piece round a gentle bend is left open, buried
## in it. `caps` closes the path's own ends as tube's does: 1 the last point's,
## 2 the first's, 3 both, 0 neither (ends sunk in what they join). A path whose
## last point is its first closes on itself. `shadow` false casts none.
static func path(k: VehicleModels, parent: Node3D, route: Array, radius: float, mat: String, col = null, segments := 8, shadow := true, caps := 3) -> void:
	if route.size() < 2:
		return
	var closed := route.size() > 3 and (route[0] as Vector3).distance_to(route[route.size() - 1]) < radius * 0.05
	var points := _bent(route, radius, closed) if radius < 0.012 else route
	var n := points.size()
	var lengths := PackedFloat32Array()
	lengths.resize(n - 1)
	for i in n - 1:
		lengths[i] = (points[i] as Vector3).distance_to(points[i + 1])
	# At each joint: how far the two pieces run past it, whether it gets a
	# ball, and whether each piece hides the other's open end.
	var laps := PackedFloat32Array()
	laps.resize(n)
	var balls := PackedByteArray()
	balls.resize(n)
	var open_in := PackedByteArray()
	open_in.resize(n)
	var open_out := PackedByteArray()
	open_out.resize(n)
	for i in n:
		var before := i - 1
		var after := i
		if closed and (i == 0 or i == n - 1):
			before = n - 2
			after = 0
		if before < 0 or after > n - 2:
			continue
		if lengths[before] < 0.0001 or lengths[after] < 0.0001:
			balls[i] = 1
			continue
		var p: Vector3 = points[i]
		var din: Vector3 = (p - (points[before] as Vector3)) / lengths[before]
		var dout: Vector3 = ((points[after + 1] as Vector3) - p) / lengths[after]
		var bend := acos(clampf(din.dot(dout), -1.0, 1.0))
		if bend > deg_to_rad(95.0) or (bend > deg_to_rad(45.0) and radius >= 0.012):
			balls[i] = 1
			continue
		laps[i] = minf(radius * tan(bend * 0.5), minf(lengths[before], lengths[after]))
		open_in[i] = 1 if _buries(lengths[after], radius, bend) else 0
		open_out[i] = 1 if _buries(lengths[before], radius, bend) else 0
	for i in n - 1:
		if lengths[i] < 0.0001:
			continue
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := (b - a) / lengths[i]
		var ends := 0
		var at_end := i + 1 == n - 1 and not closed
		var at_start := i == 0 and not closed
		if (at_end and (caps & 1) != 0) or (not at_end and open_in[i + 1] == 0):
			ends |= 1
		if (at_start and (caps & 2) != 0) or (not at_start and open_out[i] == 0):
			ends |= 2
		tube(k, parent, a - d * laps[i], b + d * laps[i + 1], radius, mat, col, segments, shadow, -1.0, ends)
	for i in n:
		if balls[i] == 1 and not (closed and i == n - 1):
			k._add(parent, Res.sphere(radius, segments), mat, col, points[i], Vector3.ZERO, Vector3.ONE, shadow)


## Whether a piece `length` long, leaving a joint that bends by `bend`, hides
## the open end of the piece coming in (run on into it by radius * tan(bend / 2)).
## Past about 45 degrees the end's sides stand out of the other piece's wall
## (by 4% of the radius at 45, 40% at 90), so it keeps its cap; and the piece
## must reach past that end's far rim.
static func _buries(length: float, radius: float, bend: float) -> bool:
	return bend <= deg_to_rad(46.0) and length >= radius * (0.1 + 2.0 * sin(bend))


## `points` with each corner of 45 to 95 degrees bent round: the corner point
## replaced by two, cut back along its legs (1.5 radii times tan(bend / 2),
## less on short legs) so the tube turns through two half bends. A corner whose
## legs are too short for the middle piece to bury its neighbours' ends stays.
static func _bent(points: Array, radius: float, closed: bool) -> Array:
	var n := points.size()
	var out: Array = []
	for i in (n - 1 if closed else n):
		var p: Vector3 = points[i]
		if not closed and (i == 0 or i == n - 1):
			out.append(p)
			continue
		var before: Vector3 = points[i - 1] if i > 0 else points[n - 2]
		var after: Vector3 = points[i + 1]
		var lin := p.distance_to(before)
		var lout := p.distance_to(after)
		if lin < 0.0001 or lout < 0.0001:
			out.append(p)
			continue
		var din := (p - before) / lin
		var dout := (after - p) / lout
		var bend := acos(clampf(din.dot(dout), -1.0, 1.0))
		var cut := minf(radius * 1.5 * tan(bend * 0.5), 0.45 * minf(lin, lout))
		if bend <= deg_to_rad(45.0) or bend > deg_to_rad(95.0) or 2.0 * cut * cos(bend * 0.5) < radius * (0.1 + 2.0 * sin(bend * 0.5)):
			out.append(p)
			continue
		out.append(p - din * cut)
		out.append(p + dout * cut)
	if closed:
		out.append(out[0])
	return out


## A boarding tread with a rolled front lip and sparse grip ribs.
static func step(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO, mat := "metal_dark", col = null) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._box(mount, Vector3(size.x, 0.035, size.y), Vector3.ZERO, mat, col)
	for side: float in [-1.0, 1.0]:
		k._box(mount, Vector3(size.x, 0.035, 0.018), Vector3(0, -0.008, side * (size.y * 0.5 - 0.009)), mat, col)
	var ribs := clampi(ceili(size.y / 0.06), 2, 8)
	for i in ribs:
		k._box(mount, Vector3(size.x * 0.9, 0.006, 0.009), Vector3(0, 0.020, lerpf(-size.y * 0.38, size.y * 0.38, float(i) / (ribs - 1))), "steel", Color(0.22, 0.23, 0.21), Vector3.ZERO, false)
	k._fold(mount)

static func ladder(k: VehicleModels, parent: Node3D, bottom: Vector3, width: float, pitch: float, count: int, depth := 0.24, rotation := Vector3.ZERO, mat := "metal_dark", col = null) -> void:
	var mount := k._pivot(parent, bottom)
	mount.rotation = rotation
	for i in count:
		step(k, mount, Vector3(0, i * pitch, 0), Vector2(width, depth), Vector3.ZERO, mat, col)
	for side: float in [-1.0, 1.0]:
		var lo := Vector3(side * width * 0.45, -0.06, depth * 0.32)
		var hi := lo + Vector3(0, (count - 1) * pitch + 0.24, 0)
		beam(k, mount, lo, hi, 0.025, 0.035, mat, col)
		for at in [lo, hi]:
			tube(k, mount, at, at + Vector3(0, 0, depth * 0.3), 0.018, mat, col, 6, false)
	k._fold(mount)

## Handrail along deck points, with stanchions and feet. Explicit points allow
## callers to leave access gaps instead of joining every segment indiscriminately.
## `lean` rakes the stanchions, as on a boat's bow rail or a helm seat's
## backrest: each post's top stands `lean` off the point `height` above its
## foot (one Vector3 for every post, or an Array of one per foot), and the rails
## run through the tops (the middle one halfway up the posts).
static func railing(k: VehicleModels, parent: Node3D, feet: Array, height: float, radius := 0.018, mat := "metal_dark", col = null, middle := false, lean: Variant = Vector3.ZERO) -> void:
	var tops: Array[Vector3] = []
	for i in feet.size():
		var off: Vector3 = Vector3.ZERO
		if lean is Vector3:
			off = lean
		elif lean is Array and i < (lean as Array).size():
			off = (lean as Array)[i]
		tops.append((feet[i] as Vector3) + Vector3.UP * height + off)
	for i in feet.size():
		var foot: Vector3 = feet[i]
		# A post's foot stands in its plate and its top inside the rail, but
		# for the end posts', whose top half shows past the rail's end.
		tube(k, parent, foot, tops[i], radius, mat, col, 6, false, -1.0, 1 if i == 0 or i == feet.size() - 1 else 0)
		k._box(parent, Vector3(radius * 4, radius, radius * 4), foot, mat, col, Vector3.ZERO, false)
	if feet.size() < 2:
		return
	for fraction: float in ([0.5, 1.0] if middle else [1.0]):
		var line := []
		for i in feet.size():
			line.append((feet[i] as Vector3).lerp(tops[i], fraction))
		path(k, parent, line, radius, mat, col, 6, false)

## Static routed hose/cable: authored supports, sag between them, and optional
## end collars. Sampling happens only during model construction. The run is
## one bent hose (path), so its sagging pieces need no caps between them.
static func cable(k: VehicleModels, parent: Node3D, supports: Array, radius: float, slack := 0.0, mat := "rubber", col = null, collars := true) -> void:
	if supports.size() < 2:
		return
	var line: Array = [supports[0]]
	for i in supports.size() - 1:
		var a: Vector3 = supports[i]
		var b: Vector3 = supports[i + 1]
		var count := 4 if slack > 0 else 1
		for j in range(1, count + 1):
			var t := float(j) / count
			line.append(a.lerp(b, t) + Vector3.DOWN * sin(PI * t) * slack)
	path(k, parent, line, radius, mat, col, 6, false)
	for i in supports.size() - 1:
		var a: Vector3 = supports[i]
		var b: Vector3 = supports[i + 1]
		if collars:
			var direction := (b - a).normalized()
			for tip: Vector3 in [a, b]:
				tube(k, parent, tip - direction * radius * 1.5, tip + direction * radius * 1.5, radius * 1.35, "steel", null, 8, false)


## Sport bar or roll cage: welded tube members in the parent's coordinates
## (the old tubes' endpoints). Each member is an Array of Vector3 points that
## one tube is bent through, its corners rolled into mandrel bends, optionally
## followed by a float: that member's tube radius in place of `radius`. An end
## that meets another member is welded to it (a node and a bead where tubes
## corner, a bolted saddle clamp partway along a tube, as a hoop's stays are);
## every other end is a foot, welded to a bolted base plate with gusset fins
## (tubes that come down together onto one point share its plate). A plate
## lies flat under a foot that comes down onto it and stands upright across a
## tube that ends against a wall; it reaches 2.2 radii round the foot. Pads,
## seats and lamps stay with the caller.
static func roll_bar(k: VehicleModels, parent: Node3D, members: Array, radius: float, mat := "gunmetal_w", col = null, segments := 8) -> void:
	_tubework(k, parent, members, radius, mat, col, segments, 3.0)


## Bull bar, brush guard or tube bumper across a nose: the same members as
## roll_bar (the old hoop's points first, then its cross bars and uprights as
## further members, any of them with its own radius), bent at a tighter
## radius, its feet bolted to the bumper or chassis on base plates. `tabs`
## lamp tabs stand on the hoop's highest level run (a spotlight's bracket).
static func bull_bar(k: VehicleModels, parent: Node3D, members: Array, radius: float, mat := "gunmetal_w", col = null, tabs := 0, segments := 8) -> void:
	var runs := _tubework(k, parent, members, radius, mat, col, segments, 2.5)
	if tabs <= 0 or runs.is_empty():
		return
	# The tabs go on the first member's highest run that lies nearly level.
	var points: Array[Vector3] = runs[0][0]
	var r: float = runs[0][1]
	var best := -1
	for i in points.size() - 1:
		var d := points[i + 1] - points[i]
		if d.length() < r * 6.0 or absf(d.normalized().y) > 0.3:
			continue
		if best < 0 or points[i].y + points[i + 1].y > points[best].y + points[best + 1].y:
			best = i
	if best < 0:
		return
	var a := points[best]
	var b := points[best + 1]
	var along := (b - a).normalized()
	var face := along.cross(Vector3.UP).normalized()
	for i in tabs:
		var at := a.lerp(b, (i + 1.0) / (tabs + 1.0)) + Vector3.UP * r * 0.8
		beam(k, parent, at, at + Vector3.UP * r * 2.2, r * 1.7, r * 0.35, mat, col, false)
		VehicleBody.fastener(k, parent, at + Vector3.UP * r * 1.4 + face * r * 0.2, face, r * 0.32)


## The members of a tubework call as [points, radius] pairs; members of fewer
## than two points are skipped.
static func _runs(members: Array, radius: float) -> Array:
	var runs := []
	for member: Array in members:
		var points: Array[Vector3] = []
		var r := radius
		for item: Variant in member:
			if item is Vector3:
				points.append(item)
			elif item is float or item is int:
				r = float(item)
		if points.size() >= 2:
			runs.append([points, r])
	return runs


## A polyline with each corner rolled into a short arc of `bend` radius (a
## tube bender's die), the straight runs trimmed to meet it.
static func _rolled(points: Array[Vector3], bend: float) -> Array:
	var out: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var p := points[i]
		var da := (points[i - 1] - p).normalized()
		var db := (points[i + 1] - p).normalized()
		if da.dot(db) < -0.995:
			out.append(p)
			continue
		var pa := p + da * minf(bend, p.distance_to(points[i - 1]) * 0.45)
		var pb := p + db * minf(bend, p.distance_to(points[i + 1]) * 0.45)
		for j in 4:
			var t := j / 3.0
			out.append(pa.lerp(p, t).lerp(p.lerp(pb, t), t))
	out.append(points[points.size() - 1])
	return out


## Closest point to `p` on a polyline: [point, segment index, distance].
static func _nearest(points: Array[Vector3], p: Vector3) -> Array:
	var best := [points[0], 0, INF]
	for i in points.size() - 1:
		var q := Geometry3D.get_closest_point_to_segment(p, points[i], points[i + 1])
		var d := q.distance_to(p)
		if d < float(best[2]):
			best = [q, i, d]
	return best


## A thin right-angled fin, its legs `size` long along local X and Y, `t` thick.
static func _fin(size: float, t: float) -> ArrayMesh:
	var rings := []
	for z: float in [-t * 0.5, t * 0.5]:
		rings.append(PackedVector3Array([Vector3(0, 0, z), Vector3(size, 0, z), Vector3(0, size, z)]))
	return VehicleModels.solid(rings, "frames_fin_%.4f_%.4f" % [size, t])


## The kernel of roll_bar and bull_bar: bent members, their welded joints,
## clamps and footings. Returns the parsed [points, radius] members.
static func _tubework(k: VehicleModels, parent: Node3D, members: Array, radius: float, mat: String, col, segments: int, bend: float) -> Array:
	var runs := _runs(members, radius)
	var nodes: Array[Vector3] = []
	var feet: Array[Vector3] = []
	for run: Array in runs:
		var points: Array[Vector3] = run[0]
		var r: float = run[1]
		# A bend's short pieces overlap by just enough to close its outside,
		# so no joint spheres are needed.
		var line := _rolled(points, r * bend)
		var laps := PackedFloat32Array()
		laps.resize(line.size())
		var turns := PackedFloat32Array()
		turns.resize(line.size())
		for j in range(1, line.size() - 1):
			var da: Vector3 = (line[j] - line[j - 1]).normalized()
			var db: Vector3 = (line[j + 1] - line[j]).normalized()
			turns[j] = acos(clampf(da.dot(db), -1.0, 1.0))
			laps[j] = r * minf(1.0, tan(turns[j] * 0.5))
		for j in line.size() - 1:
			var a: Vector3 = line[j]
			var b: Vector3 = line[j + 1]
			var d := (b - a).normalized()
			# The member's own ends are capped; an end run on into the next
			# piece round a rolled bend is buried in it (see _buries).
			var ends := 3
			if j + 1 < line.size() - 1 and _buries((line[j + 2] as Vector3).distance_to(b), r, turns[j + 1]):
				ends &= ~1
			if j > 0 and _buries((line[j - 1] as Vector3).distance_to(a), r, turns[j]):
				ends &= ~2
			tube(k, parent, a - d * laps[j], b + d * laps[j + 1], r, mat, col, segments, true, -1.0, ends)
	for i in runs.size():
		var points: Array[Vector3] = runs[i][0]
		var r: float = runs[i][1]
		for end in 2:
			var tip: Vector3 = points[0] if end == 0 else points[points.size() - 1]
			var inner: Vector3 = points[1] if end == 0 else points[points.size() - 2]
			var into := (tip - inner).normalized()
			# The member this end is welded or clamped to, if any.
			var host := -1
			var hit := []
			for j in runs.size():
				if j == i:
					continue
				var cand: Array[Vector3] = runs[j][0]
				var found := _nearest(cand, tip)
				if float(found[2]) <= float(runs[j][1]) + r * 0.6 + 0.01 and (host < 0 or float(found[2]) < float(hit[2])):
					host = j
					hit = found
			var other: Array[Vector3] = runs[host][0] if host >= 0 else points
			var hr: float = runs[host][1] if host >= 0 else r
			var at: Vector3 = hit[0] if host >= 0 else tip
			# Tubes that come down together onto one point share its base plate.
			var shared := false
			if host >= 0 and into.y < -0.3:
				for e in 2:
					var end_at: Vector3 = other[0] if e == 0 else other[other.size() - 1]
					var end_in: Vector3 = other[1] if e == 0 else other[other.size() - 2]
					if end_at.distance_to(tip) <= r + hr and (end_at - end_in).normalized().y < -0.3:
						shared = true
			if host < 0 or shared:
				var seen := false
				for f in feet:
					if f.distance_to(tip) < r + hr:
						seen = true
				if not seen:
					feet.append(tip)
					_foot(k, parent, tip, into, r, mat, col)
				continue
			var corner := false
			for q in other:
				if q.distance_to(at) <= hr * 2.5 + r:
					corner = true
			if corner:
				# Tubes cornering together are notched, welded and ground round.
				var seen := false
				for n in nodes:
					if n.distance_to(tip) < r:
						seen = true
				if not seen:
					nodes.append(tip)
					k._add(parent, Res.sphere(maxf(r, hr), 6), mat, col, tip)
				tube(k, parent, tip - into * r * 1.5, tip - into * r * 0.9, r * 1.13, mat, col, segments, false)
			else:
				# A stay meeting a tube partway along is held by a split saddle
				# clamp, bolted on the side away from it.
				var seg := int(hit[1])
				var along := (other[seg + 1] - other[seg]).normalized()
				tube(k, parent, at - along * r * 1.5, at + along * r * 1.5, hr * 1.32, "metal_dark", null, segments, false)
				var away := -(into - along * into.dot(along)).normalized()
				if away.is_zero_approx():
					away = Vector3.UP
				VehicleBody.fastener(k, parent, at + away * hr * 1.34, away, r * 0.4)
	return runs


## A base plate under a tube's free end, bolted down, with two gusset fins
## welded between it and the tube.
static func _foot(k: VehicleModels, parent: Node3D, tip: Vector3, into: Vector3, r: float, mat: String, col) -> void:
	var n := Vector3.UP if into.y < 0.0 else Vector3.DOWN
	if absf(into.y) < 0.5:
		n = Vector3(-into.x, 0, -into.z).normalized()
	var basis := aim(n)
	var w := r * 4.4
	var t := maxf(0.008, r * 0.3)
	k._box(parent, Vector3(w, t, w), tip, mat, col, basis.get_euler())
	for corner: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, parent, tip + n * t * 0.5 + (basis.x + basis.z * corner) * w * 0.33, n, r * 0.32)
	if absf(into.dot(n)) < 0.8:
		return
	# Fins run fore and aft on a floor plate, up and down on a wall plate, and
	# stop at its edge.
	var s := basis.x if absf(basis.x.y) > absf(basis.z.y) or (absf(basis.x.y) == absf(basis.z.y) and absf(basis.x.z) > absf(basis.z.z)) else basis.z
	var fin := _fin(r * 1.25, t * 0.8)
	for side: float in [-1.0, 1.0]:
		var x := s * side
		k._add(parent, fin, mat, col, tip + n * t * 0.5 + x * r * 0.92, Basis(x, n, x.cross(n)).get_euler(), Vector3.ONE, false)


## A wound service hose on a drum, with end flanges. Static, baked geometry;
## dimensions describe the hose pack, with the axle along local X.
static func hose_reel(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, width: float, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	# The drum's ends lie in its flanges.
	cyl(k, mount, radius * 0.91, radius * 0.91, width, Vector3.ZERO, Vector3(0, 0, PI / 2), "rubber", null, 16, true, 0)
	var count := clampi(ceili(width / (radius * 0.18)), 4, 14)
	for i in count:
		var ring := Res.torus(radius * 0.88, radius)
		k._add(mount, ring, "rubber", null, Vector3(lerpf(-width * 0.46, width * 0.46, float(i) / (count - 1)), 0, 0), Vector3(0, 0, PI / 2), Vector3(1, width / count / (radius * 0.12), 1), false)
	for side: float in [-1.0, 1.0]:
		cyl(k, mount, radius * 1.1, radius * 1.1, width * 0.05, Vector3(side * width * 0.52, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 16)
		cyl(k, mount, radius * 0.2, radius * 0.2, width * 0.08, Vector3(side * width * 0.54, 0, 0), Vector3(0, 0, PI / 2), "steel", null, 10, false)
	k._fold(mount)


## Hydraulic ram between its two pins: a crane's luffing ram, a dozer blade's
## lifting ram, a launcher's elevation ram, a gun's recoil cylinder. `foot` is
## where the cylinder is pinned and `end` where its rod is (the old tube's
## endpoints), `radius` the old tube's, the cylinder's, radius. The cylinder
## runs from its welded base cap to the gland, and the bright rod shows for
## `stroke` of the length. Each eye is a boss across `pin` (the axis the ram
## pivots about, squared up to the ram: RIGHT for a ram working in a fore and
## aft plane) between the clevis lugs of its bracket, which reach 1.7 eye
## radii back past the pin into the part the ram hangs from, and the pin
## through them (the cylinder's eye is 1.05 radii, the rod's 0.94). `hose` adds
## the two oil ports, the steel pipe between them along the cylinder and the
## hose leaving the base end. `eyes` false makes a cylinder held in a cradle
## (recoil and buffer cylinders): a bolted flange at the foot and a nut on the
## rod's end, no pins, all between the two endpoints.
static func ram(k: VehicleModels, parent: Node3D, foot: Vector3, end: Vector3, radius: float, mat := "gunmetal_w", col = null, stroke := 0.4, pin := Vector3.RIGHT, hose := true, eyes := true) -> void:
	var length := foot.distance_to(end)
	if length < radius * 4.0:
		return
	var y := (end - foot) / length
	var x := pin - y * pin.dot(y)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.FORWARD)
	x = x.normalized()
	var m := k._pivot(parent, foot)
	m.basis = Basis(x, y, x.cross(y))
	var rod := radius * 0.55
	var eye := radius * 1.05 if eyes else 0.0
	var rod_eye := rod * 1.7 if eyes else 0.0
	var low := eye * 0.55
	var top := length - (rod_eye * 0.55 if eyes else rod * 1.1)
	var gland := clampf(length * (1.0 - stroke), low + radius * 2.0, top - radius * 0.5)
	var z90 := Vector3(0, 0, PI / 2)
	if not eyes:
		# The mounting flange, bolted to the cradle.
		cyl(k, m, radius * 1.35, radius * 1.35, 0.02, Vector3(0, 0.01, 0), Vector3.ZERO, mat, col, 10)
		for i in 4:
			var a := TAU * (i + 0.5) / 4.0
			VehicleBody.fastener(k, m, Vector3(cos(a) * radius * 1.2, 0.0215, sin(a) * radius * 1.2), Vector3.UP, radius * 0.1)
		low = 0.02
	# The base cap, the cylinder, the gland and its wiper, the rod.
	cyl(k, m, radius * 1.06, radius * 1.06, radius * 0.6, Vector3(0, low + radius * 0.3, 0), Vector3.ZERO, mat, col, 10)
	var barrel := gland - radius * 0.6 - (low + radius * 0.6)
	cyl(k, m, radius, radius, barrel, Vector3(0, low + radius * 0.6 + barrel * 0.5, 0), Vector3.ZERO, mat, col, 10, true, 0)
	cyl(k, m, radius * 1.1, radius * 1.1, radius * 0.6, Vector3(0, gland - radius * 0.3, 0), Vector3.ZERO, mat, col, 10)
	cyl(k, m, rod * 1.3, rod * 1.3, 0.01, Vector3(0, gland + 0.005, 0), Vector3.ZERO, "rubber", null, 8, false)
	# The rod runs from inside the gland into its eye (or under its nut).
	cyl(k, m, rod, rod, top - gland, Vector3(0, (top + gland) * 0.5, 0), Vector3.ZERO, "steel", Color(0.8, 0.81, 0.8), 8, true, 0)
	if eyes:
		for e: Vector2 in [Vector2(0.0, eye), Vector2(length, rod_eye)]:
			var at := Vector3(0, e.x, 0)
			var away := -1.0 if e.x == 0.0 else 1.0
			var w := e.y * 1.35
			cyl(k, m, e.y, e.y, w, at, z90, mat, col, 10)
			var lug_t := maxf(0.008, e.y * 0.3)
			var reach := w * 0.5 + lug_t + 0.012
			VehicleFrames.tube(k, m, at - Vector3.RIGHT * reach, at + Vector3.RIGHT * reach, e.y * 0.4, "steel", null, 6, false)
			for side: float in [-1.0, 1.0]:
				k._box(m, Vector3(lug_t, e.y * 2.5, e.y * 1.9), at + Vector3(side * (w * 0.5 + lug_t * 0.5 + 0.002), away * e.y * 0.45, 0), mat, col)
	else:
		cyl(k, m, rod * 1.5, rod * 1.5, rod * 1.1, Vector3(0, length - rod * 0.55, 0), Vector3.ZERO, "metal_dark", null, 6)
	if hose:
		# Oil ports at both ends of the cylinder on its +Z side, the gland's
		# line piped back along it to the base, the hose leaving there.
		var base_port := low + radius * 1.0
		var gland_port := gland - radius * 1.0
		for py: float in [base_port, gland_port]:
			k._box(m, Vector3(radius * 0.7, radius * 0.7, radius * 0.5), Vector3(0, py, radius * 1.1), mat, col, Vector3.ZERO, false)
		VehicleFrames.tube(k, m, Vector3(0, gland_port, radius * 1.38), Vector3(0, base_port, radius * 1.38), radius * 0.13, "steel", null, 6, false)
		var bend := Vector3(0, base_port - radius * 0.9, radius * 1.85)
		path(k, m, [Vector3(0, base_port, radius * 1.38), bend, Vector3(0, maxf(base_port - radius * 2.4, -eye), radius * 1.7)], radius * 0.2, "rubber", null, 6)
	k._fold(m)
