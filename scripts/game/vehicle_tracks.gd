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
		k._cyl(parent, pin_radius, pin_radius, width + pin_radius * 1.4, Vector3(x, hinge.y, hinge.x), VehicleWheels.AXLE, "gunmetal_w", null, 6, false)

		if guides:
			var tooth := q - normal * (thickness * 0.5 + 0.035)
			k._add(parent, _shoe, "track", null, Vector3(x, tooth.y, tooth.x), rot, Vector3(width * 0.10, 0.07, spacing * 0.35), false)
