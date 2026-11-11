class_name VehicleAircraft
extends RefCounted
## Shared aircraft equipment keeps each family's mount and flight animation.

## Rocket pod with a rolled lip, recessed tube bores and separate mounting bands.
## Radius and length are independent; seven- and nineteen-tube patterns differ.
static func rocket_pod(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, material := "paint", col = null, tubes := 7) -> void:
	assert(tubes == 7 or tubes == 19)
	var r := radius
	var ln := length
	var front := -ln * 0.48
	var profile := [Vector2(r * 0.91, front + 0.04), Vector2(r * 0.91, front), Vector2(r * 0.96, front - 0.008), Vector2(r, front + 0.025), Vector2(r, ln * 0.34), Vector2(r * 0.62, ln * 0.5), Vector2(0, ln * 0.5)]
	k._add(parent, VehicleProfiles.revolve(profile, 20), material, col, center)
	k._cyl(parent, r * 0.9, r * 0.9, 0.012, center + Vector3(0, 0, front + 0.035), Vector3(PI / 2, 0, 0), "metal_dark", null, 20, false)
	for z in [-ln * 0.34, ln * 0.28]:
		var band := [Vector2(r, z - 0.018), Vector2(r + 0.008, z - 0.014), Vector2(r + 0.008, z + 0.014), Vector2(r, z + 0.018)]
		k._add(parent, VehicleProfiles.revolve(band, 20), "metal_dark", null, center)
	var holes: Array[Vector2] = [Vector2.ZERO]
	var rings := [[6, 0.55]] if tubes == 7 else [[6, 0.36], [12, 0.72]]
	for ring: Array in rings:
		for i in int(ring[0]):
			var angle := TAU * float(i) / float(ring[0])
			holes.append(Vector2(cos(angle), sin(angle)) * r * float(ring[1]))
	var bore := r * (0.23 if tubes == 7 else 0.135)
	var tube_profile := [Vector2(bore * 0.8, 0.035), Vector2(bore * 0.8, 0), Vector2(bore, 0), Vector2(bore, 0.035)]
	var tube := VehicleProfiles.revolve(tube_profile, 10, 35)
	for hole in holes:
		var pos := center + Vector3(hole.x, hole.y, front + 0.003)
		k._add(parent, tube, "steel", Color(0.23, 0.24, 0.22), pos)
		k._cyl(parent, bore * 0.8, bore * 0.8, 0.003, pos + Vector3(0, 0, 0.035), Vector3(PI / 2, 0, 0), "plain_dark", null, 10, false)
	k._box(parent, Vector3(r * 0.5, 0.055, ln * 0.4), center + Vector3(0, r + 0.015, 0), "metal_dark")


## Double-wall duct between authored loops. The rim is open; a dark engine face
## sits at the back, rather than painting a disc over the mouth.
static func duct(k: VehicleModels, parent: Node3D, lip: PackedVector3Array, back: PackedVector3Array, thickness: float, material: String, col, inner_col, facing := -1.0, crease := 40.0, outer := true) -> void:
	assert(lip.size() == back.size() and lip.size() >= 3)
	if outer:
		k._add(parent, VehicleProfiles.loft([lip, back], crease, false), material, col, Vector3.ZERO)
	var li := inset(lip, thickness)
	var bi := inset(back, thickness * 0.8)
	k._add(parent, VehicleProfiles.loft([li, bi], crease, false, true), material, inner_col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var data := [[], [], []]
	for i in lip.size():
		var j := (i + 1) % lip.size()
		var normal := (li[i] - lip[i]).cross(lip[j] - lip[i]).normalized()
		if normal.z * facing < 0.0:
			normal = -normal
		VehicleSurface._quad(data, lip[i], lip[j], li[j], li[i], normal)
	k._add(parent, VehicleSurface._mesh(data), material, col, Vector3.ZERO)
	var center := VehicleModels._centroid(bi)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var normal := Vector3(0, 0, facing)
	for i in bi.size():
		VehicleProfiles._tri(vs, ns, center, bi[i], bi[(i + 1) % bi.size()], normal, normal, normal, normal)
	k._add(parent, VehicleSurface._mesh([Array(vs), Array(ns), Array(PackedVector2Array())]), "plain_dark", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

static func inset(ring: PackedVector3Array, distance: float) -> PackedVector3Array:
	var center := VehicleModels._centroid(ring)
	var result := PackedVector3Array()
	for v in ring:
		var direction := center - v
		direction.z = 0.0
		result.append(v + direction.normalized() * minf(distance, direction.length() * 0.5))
	return result


## Pylon and sway braces. The returned payload axis retains the old socket
## location; improving this mount must never move gameplay muzzle positions.
static func hardpoint(k: VehicleModels, parent: Node3D, top: Vector3, length: float, height: float, col: Color, payload_radius := 0.0, width := 0.09) -> Vector3:
	var profile := [-length * 0.5, 0.08, length * 0.5, 0.08, length * 0.4, -height, -length * 0.3, -height]
	k._add(parent, VehicleModels.extrude_x("hardpoint_" + var_to_str([length, height, width]), profile, -width * 0.5, width * 0.5), "aircraft", col, top)
	for side: float in [-1.0, 1.0]:
		for z: float in [-length * 0.25, length * 0.25]:
			var foot := top + Vector3(side * (width * 0.5 + 0.035), -height + 0.015, z)
			VehicleFrames.tube(k, parent, top + Vector3(side * width * 0.4, -height + 0.08, z), foot, 0.014, "steel", null, 6, false)
			k._box(parent, Vector3(0.045, 0.018, 0.06), foot, "metal_dark")
	VehicleFrames.beam(k, parent, top + Vector3(0, -height - 0.006, -length * 0.3), top + Vector3(0, -height - 0.006, length * 0.35), width * 0.7, 0.02, "metal_dark")
	return top + Vector3(0, -height - payload_radius, 0)

## Oleo leg and torque link on the supplied Gear parent. Wheels and gear-door
## pivots remain caller-owned, so propeller wheel lists cannot be polluted.
static func gear_leg(k: VehicleModels, parent: Node3D, top: Vector3, axle: Vector3, radius: float, col := Color(0.72, 0.73, 0.70)) -> void:
	var mid := top.lerp(axle, 0.62)
	var direction := (axle - top).normalized()
	VehicleFrames.tube(k, parent, top, mid, radius, "paint", col, 10)
	VehicleFrames.tube(k, parent, mid - direction * radius, axle, radius * 0.64, "steel", Color(0.50, 0.52, 0.50), 10)
	VehicleFrames.tube(k, parent, mid - direction * radius * 0.3, mid + direction * radius * 0.3, radius * 1.12, "metal_dark", null, 10, false)
	var across := direction.cross(Vector3.RIGHT).normalized()
	if across.is_zero_approx():
		across = Vector3.FORWARD
	var elbow := mid + direction * radius + across * radius * 2.5
	var upper := top.lerp(axle, 0.5) + across * radius
	var lower := top.lerp(axle, 0.85) + across * radius * 0.64
	VehicleFrames.beam(k, parent, upper, elbow, radius * 0.4, radius * 0.35, "paint", col)
	VehicleFrames.beam(k, parent, elbow, lower, radius * 0.4, radius * 0.35, "paint", col)
	VehicleFrames.tube(k, parent, elbow - Vector3.RIGHT * radius * 0.4, elbow + Vector3.RIGHT * radius * 0.4, radius * 0.25, "steel", null, 8, false)
