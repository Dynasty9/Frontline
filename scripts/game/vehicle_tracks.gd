class_name VehicleTracks
extends RefCounted
## Individual shoes follow the vehicle's own wheel envelope. Uniform distance
## spacing continues around corners, instead of stretching one plate per edge.

static var _links := {}
## The longest unsupported return run `shoes` lets sag (see there).
const SAG_SPAN := 2.5

static func wheel_envelope(circles: Array, thickness: float, segments := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for circle: Vector3 in circles:
		for i in segments:
			var angle := TAU * (i + 0.5) / float(segments)
			points.append(Vector2(circle.x, circle.y) + Vector2(cos(angle), sin(angle)) * (circle.z + thickness * 0.5))
	return Geometry2D.convex_hull(points)


## The links round `outline`, one every `pitch` or so, each turned to the run
## it lies on. Two kinds of track, as armies fit them:
## - `pads`: a western double-pin track (Abrams, Merkava, Leopard 2,
##   Warrior): a steel body with two rubber pads on its ground face, an end
##   connector clamping the next shoe's pins at each edge (a chain of them
##   down each side of the track) and, with `guides`, a centre guide on the
##   connector between the shoes.
## - no pads: a Russian single-pin track (T-72, T-14, BMP): a cast steel link
##   with a grouser across its ground face, the hinge lugs at each end that
##   interleave with the next link's on one pin, and the guide horn standing
##   up the middle of every link (the track is steered by them between the
##   twin road wheels, so `guides` is implied).
## Each link is a few parts of cached meshes; its pad is placed on its ground
## face. The links keep the old shoe's extent: the body reaches half the
## thickness either side of the line, a pad the old pad's depth beyond it.
static func shoes(k: VehicleModels, parent: Node3D, x: float, width: float, outline: PackedVector2Array, thickness := 0.08, pitch := 0.20, pads := true, guides := false, inset := 0.0) -> void:
	var points := outline.duplicate()
	if points.size() > 1 and points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size() - 1)
	if points.size() < 3 or pitch <= 0.0:
		return
	var lengths := PackedFloat32Array([0.0])
	var center := Vector2.ZERO
	for i in points.size():
		center += points[i]
		lengths.append(lengths[-1] + points[i].distance_to(points[(i + 1) % points.size()]))
	center /= float(points.size())
	if lengths[-1] < 0.0001:
		return
	var count := maxi(3, int(ceil(lengths[-1] / pitch)))
	var spacing := lengths[-1] / float(count)
	var pad_depth := minf(0.018, thickness * 0.225)
	var link: Array = _link(width, thickness, spacing, pads, pad_depth)
	var edge := 0
	for i in count:
		var distance := (i + 0.5) * spacing
		while edge < points.size() - 1 and distance > lengths[edge + 1]:
			edge += 1
		var a := points[edge]
		var b := points[(edge + 1) % points.size()]
		var tangent := (b - a).normalized()
		var span := lengths[edge + 1] - lengths[edge]
		var along := (distance - lengths[edge]) / maxf(span, 0.0001)
		var q := a.lerp(b, along)
		var normal := Vector2(tangent.y, -tangent.x)
		if normal.dot(q - center) < 0:
			normal = -normal
		# The return run hangs between the rollers or wheels it rests on, as
		# much as 2 cm a metre. A run longer than SAG_SPAN has rollers the
		# outline leaves out, so it stays straight.
		if normal.y > 0.9 and span > 0.3 and span < SAG_SPAN:
			var bend := sin(PI * along)
			q.y -= 0.02 * span * bend * bend
			tangent = (tangent + Vector2(0, -0.02 * PI * sin(TAU * along))).normalized()
			normal = Vector2(-tangent.y, tangent.x)
			if normal.y < 0.0:
				normal = -normal
		q -= normal * inset
		# The link's +Y is its inner face (toward the wheels); a half turn
		# about the run puts it there whichever way the outline winds.
		var inner_up := Vector2(-tangent.y, tangent.x).dot(normal) < 0.0
		var rot := Vector3(atan2(-tangent.y, tangent.x), 0, 0.0 if inner_up else PI)
		var at := Vector3(x, q.y, q.x)
		k._add(parent, link[0], "track", null, at, rot)
		if pads:
			var face := q + normal * (thickness * 0.5 + pad_depth * 0.5)
			k._add(parent, link[1], "rubber", Color(0.18, 0.18, 0.17), Vector3(x, face.y, face.x), rot, Vector3.ONE, false)
		k._add(parent, link[2], "gunmetal_w" if pads else "track", null, at, rot, Vector3.ONE, false)
		if guides and pads:
			k._add(parent, link[3], "track", null, at, rot, Vector3.ONE, false)


## One link's meshes for `shoes`, centred on its line, +Z along the run to
## the next link, +Y to its inner face: [body, pads (centred on their own
## depth), hinge hardware, centre guide]. Cached by size and kind.
static func _link(width: float, thickness: float, spacing: float, pads: bool, pad_depth: float) -> Array:
	var key := "%.3f_%.3f_%.4f_%s" % [width, thickness, spacing, pads]
	if _links.has(key):
		return _links[key]
	var t := thickness
	var s := spacing
	var parts: Array = []
	if pads:
		# The body casting round both pins, narrower than the track so the
		# end connectors stand at its edges.
		parts.append(_solid([[Vector3.ZERO, Vector3(width * 0.4, t * 0.5, s * 0.43), 0]]))
		# Two pads either side of the centre, a groove between them.
		var half := Vector3(width * 0.17, pad_depth * 0.5, s * 0.35)
		parts.append(_solid([[Vector3(width * 0.205, 0, 0), half, UP], [Vector3(-width * 0.205, 0, 0), half, UP]]))
		# The end connectors over the hinge to the next shoe (their inner
		# faces against the bodies).
		parts.append(_solid([[Vector3(width * 0.455, 0, s * 0.5), Vector3(width * 0.05, t * 0.36, s * 0.3), LEFT], [Vector3(-width * 0.455, 0, s * 0.5), Vector3(width * 0.05, t * 0.36, s * 0.3), RIGHT]]))
		# The centre guide, on the centre connector between the shoes.
		parts.append(_horn(Vector3(0, t * 0.5, s * 0.5), PackedVector2Array([Vector2(width * 0.05, s * 0.2), Vector2(width * 0.03, s * 0.12)]), 0.07))
	else:
		# The cast plate with its grouser across the ground face.
		parts.append(_solid([[Vector3(0, t * 0.06, 0), Vector3(width * 0.47, t * 0.32, s * 0.31), 0], [Vector3(0, -t * 0.37, 0), Vector3(width * 0.43, t * 0.13, s * 0.085), UP]]))
		parts.append(null)
		# The hinge lugs on the pin line at each end, the middle one forward
		# and the two outer ones aft (the next link's fill between them), and
		# the guide horn up the middle of the inner face.
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Four-sided: a lug is a few centimetres across.
		var lug := VehicleBody.drum(t * 0.3, t * 0.3, width * 0.44, 4, false, false)
		var end := VehicleBody.drum(t * 0.3, t * 0.3, width * 0.22, 4, true, false)
		tool.append_from(lug, 0, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, t * 0.06, s * 0.47)))
		for side: float in [-1.0, 1.0]:
			# A drum's +Y (its capped end) turned outboard.
			tool.append_from(end, 0, Transform3D(Basis(Vector3.FORWARD, side * PI / 2), Vector3(side * width * 0.36, t * 0.06, -s * 0.47)))
		tool.append_from(_horn(Vector3(0, t * 0.38, 0), PackedVector2Array([Vector2(minf(0.036, width * 0.065), s * 0.27), Vector2(minf(0.014, width * 0.025), s * 0.11)]), t * 0.8), 0, Transform3D.IDENTITY)
		parts.append(tool.commit())
	_links[key] = parts
	return parts


## Faces a box in _solid can leave out, buried in what it stands against.
const LEFT := 1
const RIGHT := 2
const UP := 8

## Boxes as one mesh: each [centre, half size, the faces to leave out (a sum
## of LEFT, RIGHT, UP, or 0)]. Flat faces.
static func _solid(boxes: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for box: Array in boxes:
		var c: Vector3 = box[0]
		var h: Vector3 = box[1]
		var buried: int = box[2]
		for axis in 3:
			for face: float in [-1.0, 1.0]:
				if buried & (1 << (axis * 2 + (1 if face > 0.0 else 0))):
					continue
				var n := Vector3.ZERO
				n[axis] = face
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = h[(axis + 1) % 3]
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = h[(axis + 2) % 3]
				var f := c + n * h[axis]
				VehicleWheels._quad(verts, norms, idx, n, f - u - v, f + u - v, f + u + v, f - u + v)
	return VehicleWheels._mesh(verts, norms, idx)


## A guide horn or tooth standing `height` up from `base` (its foot on the
## link's inner face): a tapered block, `size` its half width and half
## length at the foot ([0]) and at the tip ([1]). No underside.
static func _horn(base: Vector3, size: PackedVector2Array, height: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var top := base + Vector3.UP * height
	var feet: Array[Vector3] = []
	var tips: Array[Vector3] = []
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		feet.append(base + Vector3(c.x * size[0].x, 0, c.y * size[0].y))
		tips.append(top + Vector3(c.x * size[1].x, 0, c.y * size[1].y))
	for i in 4:
		var j := (i + 1) % 4
		var out := (feet[i] + feet[j]) * 0.5 - base
		VehicleWheels._quad_toward(verts, norms, idx, out, feet[i], feet[j], tips[j], tips[i])
	VehicleWheels._quad(verts, norms, idx, Vector3.UP, tips[0], tips[1], tips[2], tips[3])
	return VehicleWheels._mesh(verts, norms, idx)


## Spare track links stowed in a row on a plate (a glacis, a turret side, a
## hull side), as crews carry them for repairs and for the little armour they
## add. `center` is the face point under the middle of the row, `along` the
## row's direction and `normal` the face's outward normal, in the parent's
## axes. `size` is one old link box: x its length along the row (the track's
## pitch), y its width across the track, z its thickness off the face; `count`
## links sit `pitch` apart (zero: size.x + 1.5 cm). Each is a cast shoe in the
## track's own steel: the plate (0.6 of the thickness), the grouser across its
## outer face standing to 1.35 of it, and the hinge barrels along both pitch
## edges. `retainer` crosses the row with two flat bars bolted to welded lugs
## past its end links (2 cm beyond them, 8 mm over the grousers). Static: the
## live belt and VehicleTracks.shoes are not involved.
static func spare_links(k: VehicleModels, parent: Node3D, center: Vector3, along: Vector3, normal: Vector3, count: int, size: Vector3, pitch := 0.0, retainer := true, mat := "track") -> void:
	var n := normal.normalized()
	var x := (along - n * along.dot(n)).normalized()
	if count <= 0 or n.is_zero_approx() or x.is_zero_approx():
		return
	var mount := k._pivot(parent, center)
	# Local X along the row, Y across the track, Z out of the face.
	mount.basis = Basis(x, n.cross(x), n)
	var step := pitch if pitch > 0.0 else size.x + 0.015
	var plate := size.z * 0.6
	var grouser := size.z * 1.35
	var barrel := size.z * 0.36
	for i in count:
		var cx := (i - (count - 1) * 0.5) * step
		k._add(mount, Res.box(Vector3(size.x * 0.8, size.y * 0.96, plate)), mat, null, Vector3(cx, 0, plate * 0.5))
		k._add(mount, Res.box(Vector3(size.x * 0.28, size.y * 0.9, grouser - plate)), mat, null, Vector3(cx, 0, (plate + grouser) * 0.5))
		for edge: float in [-1.0, 1.0]:
			k._add(mount, VehicleWheels.drum(barrel, barrel, size.y * 0.94, 6), mat, null, Vector3(cx + edge * (size.x * 0.5 - barrel), 0, barrel), Vector3.ZERO, Vector3.ONE, false)
	if retainer:
		var reach := (count - 1) * step * 0.5 + size.x * 0.5 + 0.02
		var lug := grouser + 0.008
		for y: float in [-size.y * 0.3, size.y * 0.3]:
			k._box(mount, Vector3(reach * 2.0 - 0.02, 0.035, 0.008), Vector3(0, y, grouser + 0.004), "gunmetal_w", null, Vector3.ZERO, false)
			for e: float in [-1.0, 1.0]:
				k._box(mount, Vector3(0.02, 0.045, lug), Vector3(e * (reach - 0.01), y, lug * 0.5), "gunmetal_w")
				VehicleBody.fastener(k, mount, Vector3(e * (reach - 0.01), y, lug + 0.002), Vector3.BACK, 0.008)
	k._fold(mount)
