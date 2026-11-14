class_name VehicleTracks
extends RefCounted
## Individual shoes follow the vehicle's own wheel envelope. Uniform distance
## spacing continues around corners, instead of stretching one plate per edge.

static var _shoe: BoxMesh

static func wheel_envelope(circles: Array, thickness: float, segments := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for circle: Vector3 in circles:
		for i in segments:
			var angle := TAU * (i + 0.5) / float(segments)
			points.append(Vector2(circle.x, circle.y) + Vector2(cos(angle), sin(angle)) * (circle.z + thickness * 0.5))
	return Geometry2D.convex_hull(points)


static func shoes(k: VehicleModels, parent: Node3D, x: float, width: float, outline: PackedVector2Array, thickness := 0.08, pitch := 0.20, pads := true, guides := false, inset := 0.0) -> void:
	if _shoe == null:
		_shoe = BoxMesh.new()
		_shoe.size = Vector3.ONE
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
	var edge := 0
	for i in count:
		var distance := (i + 0.5) * spacing
		while edge < points.size() - 1 and distance > lengths[edge + 1]:
			edge += 1
		var a := points[edge]
		var b := points[(edge + 1) % points.size()]
		var tangent := (b - a).normalized()
		var q := a.lerp(b, (distance - lengths[edge]) / maxf(lengths[edge + 1] - lengths[edge], 0.0001))
		var normal := Vector2(tangent.y, -tangent.x)
		if normal.dot(q - center) < 0:
			normal = -normal
		q -= normal * inset
		var rot := Vector3(atan2(-tangent.y, tangent.x), 0, 0)
		k._add(parent, _shoe, "track", null, Vector3(x, q.y, q.x), rot, Vector3(width, thickness, spacing * 0.92))
		if pads:
			var pad_depth := minf(0.018, thickness * 0.225)
			var face := q + normal * (thickness * 0.5 + pad_depth * 0.5)
			k._add(parent, _shoe, "rubber", Color(0.18, 0.18, 0.17), Vector3(x, face.y, face.x), rot, Vector3(width * 0.65, pad_depth, spacing * 0.66), false)
		# Hinge ends show at the edges without filling the guide-tooth gap.
		var hinge := q + tangent * spacing * 0.44
		var pin_radius := minf(0.018, thickness * 0.225)
		k._add(parent, VehicleWheels.drum(pin_radius, pin_radius, width + pin_radius * 1.4, 6), "gunmetal_w", null, Vector3(x, hinge.y, hinge.x), VehicleWheels.AXLE, Vector3.ONE, false)

		if guides:
			var tooth := q - normal * (thickness * 0.5 + 0.035)
			k._add(parent, _shoe, "track", null, Vector3(x, tooth.y, tooth.x), rot, Vector3(width * 0.10, 0.07, spacing * 0.35), false)


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
