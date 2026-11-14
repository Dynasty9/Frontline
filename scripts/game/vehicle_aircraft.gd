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
	# The face plate closes the recess; its back looks into the hollow pod.
	VehicleBody.cylinder(k, parent, r * 0.9, r * 0.9, 0.012, center + Vector3(0, 0, front + 0.035), Vector3(PI / 2, 0, 0), "metal_dark", null, 20, false, false, true)
	for z in [-ln * 0.34, ln * 0.28]:
		var band := [Vector2(r, z - 0.018), Vector2(r + 0.008, z - 0.014), Vector2(r + 0.008, z + 0.014), Vector2(r, z + 0.018)]
		k._add(parent, VehicleProfiles.revolve(band, 20), "metal_dark", null, center)
		k._box(parent, Vector3(r * 0.26, r * 0.08, 0.045), center + Vector3(0, r + 0.01, z), "steel", Color(0.18, 0.19, 0.18))
	VehicleBody.cylinder(k, parent, r * 0.2, r * 0.24, ln * 0.025, center + Vector3(0, 0, ln * 0.50), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false, true, false)
	var holes: Array[Vector2] = [Vector2.ZERO]
	var rings := [[6, 0.55]] if tubes == 7 else [[6, 0.36], [12, 0.72]]
	for ring: Array in rings:
		for i in int(ring[0]):
			var angle := TAU * float(i) / float(ring[0])
			holes.append(Vector2(cos(angle), sin(angle)) * r * float(ring[1]))
	var bore := r * (0.23 if tubes == 7 else 0.135)
	var tube_profile := [Vector2(bore * 0.8, 0.035), Vector2(bore * 0.8, 0), Vector2(bore, 0), Vector2(bore, 0.035)]
	var tube := VehicleProfiles.revolve(tube_profile, 10, 35)
	# Looking into a tube the eye stops at the dark face plate 2.6 cm in, so
	# the tube needs no bore disc of its own behind it.
	for hole in holes:
		var pos := center + Vector3(hole.x, hole.y, front + 0.003)
		k._add(parent, tube, "steel", Color(0.23, 0.24, 0.22), pos)
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
## `top` is the middle of the pylon's root, where it meets the wing; the
## pylon hangs `height` below it and its root rises `rise` into the wing.
## A helicopter's stub-wing pylon (the old gunmetal box of size (w, h, l) at
## c) is hardpoint(top = c + (0, h / 2, 0), l, h, null, store radius, w,
## "gunmetal_w", the wing's depth above the box, or 0). `col` may be null for
## a material's own finish. The sway braces' hardware scales with `width`
## (unchanged at the default 0.09); `braces` off leaves them to a launcher
## that brings its own.
static func hardpoint(k: VehicleModels, parent: Node3D, top: Vector3, length: float, height: float, col, payload_radius := 0.0, width := 0.09, mat := "aircraft", rise := 0.08, braces := true) -> Vector3:
	var profile := [-length * 0.5, rise, length * 0.5, rise, length * 0.4, -height, -length * 0.3, -height]
	var key := "hardpoint_" + var_to_str([length, height, width] if rise == 0.08 else [length, height, width, rise])
	k._add(parent, VehicleModels.extrude_x(key, profile, -width * 0.5, width * 0.5), mat, col, top)
	var plate_col: Variant = null
	if col is Color:
		var c: Color = col
		plate_col = c.darkened(0.08)
	var s := clampf(width / 0.09, 0.45, 1.4)
	for side: float in [-1.0, 1.0]:
		# (a 6 mm doubler plate: a 1.5 mm chamfer on it would be under a pixel)
		k._add(parent, Res.box(Vector3(0.006, height * 0.34, length * 0.35)), mat, plate_col, top + Vector3(side * (width * 0.5 + 0.003), -height * 0.35, 0))
		if not braces:
			continue
		for z: float in [-length * 0.25, length * 0.25]:
			var foot := top + Vector3(side * (width * 0.5 + 0.035 * s), -height + 0.015 * s, z)
			# (the brace's head is in the pylon, its foot in the pad)
			VehicleBody.rod(k, parent, top + Vector3(side * width * 0.4, -height + 0.08 * s, z), foot, 0.014 * s, "steel", null, 6, false, -1.0, false, false)
			k._box(parent, Vector3(0.045, 0.018, 0.06) * s, foot, "metal_dark")
			VehicleBody.fastener(k, parent, foot + Vector3(0, 0.012 * s, 0), Vector3.UP, 0.012 * s)
	VehicleFrames.beam(k, parent, top + Vector3(0, -height - 0.006, -length * 0.3), top + Vector3(0, -height - 0.006, length * 0.35), width * 0.7, 0.02, "metal_dark")
	return top + Vector3(0, -height - payload_radius, 0)

## Oleo leg and torque link on the supplied Gear parent. Wheels and gear-door
## pivots remain caller-owned, so propeller wheel lists cannot be polluted.
static func gear_leg(k: VehicleModels, parent: Node3D, top: Vector3, axle: Vector3, radius: float, col := Color(0.72, 0.73, 0.70)) -> void:
	var mid := top.lerp(axle, 0.62)
	var direction := (axle - top).normalized()
	VehicleBody.rod(k, parent, top, mid, radius, "paint", col, 10, true, -1.0, true, false)
	VehicleBody.rod(k, parent, mid - direction * radius, axle, radius * 0.64, "steel", Color(0.50, 0.52, 0.50), 10, true, -1.0, false, true)
	VehicleBody.rod(k, parent, mid - direction * radius * 0.3, mid + direction * radius * 0.3, radius * 1.12, "metal_dark", null, 10, false)
	var across := direction.cross(Vector3.RIGHT).normalized()
	if across.is_zero_approx():
		across = Vector3.FORWARD
	var elbow := mid + direction * radius + across * radius * 2.5
	var upper := top.lerp(axle, 0.5) + across * radius
	var lower := top.lerp(axle, 0.85) + across * radius * 0.64
	VehicleFrames.beam(k, parent, upper, elbow, radius * 0.4, radius * 0.35, "paint", col)
	VehicleFrames.beam(k, parent, elbow, lower, radius * 0.4, radius * 0.35, "paint", col)
	VehicleBody.rod(k, parent, elbow - Vector3.RIGHT * radius * 0.4, elbow + Vector3.RIGHT * radius * 0.4, radius * 0.25, "steel", null, 8, false)
	var hose := [top + across * radius * 1.12, mid + across * radius * 1.35, axle + across * radius * 0.85]
	# The hose sags between its clips as VehicleFrames.cable hangs one; its
	# gentle curve is one bead, with a joint ball only where it turns sharply.
	var line: Array = [hose[0]]
	for i in hose.size() - 1:
		for j in range(1, 5):
			var t := float(j) / 4.0
			line.append((hose[i] as Vector3).lerp(hose[i + 1], t) + Vector3.DOWN * sin(PI * t) * radius * 0.35)
	VehicleBody.bead(k, parent, line, radius * 0.10, "rubber", null, 6, false, true)
	for t: float in [0.2, 0.52]:
		var at := top.lerp(axle, t)
		VehicleBody.rod(k, parent, at - direction * radius * 0.18, at + direction * radius * 0.18, radius * 1.06, "steel", null, 10, false)

## Pitot boom retains its exact endpoints, with a tapered tip and mounting sleeve.
static func pitot(k: VehicleModels, parent: Node3D, base: Vector3, tip: Vector3, radius: float, mat := "steel", col = null) -> void:
	var neck := base.lerp(tip, 0.22)
	VehicleBody.rod(k, parent, base, neck, radius * 1.2, mat, col, 8, false, -1.0, true, false)
	VehicleBody.rod(k, parent, neck, tip, radius, mat, col, 8, false, radius * 0.32, false, true)
	var direction := (tip - base).normalized()
	VehicleBody.rod(k, parent, neck - direction * radius, neck + direction * radius, radius * 1.35, "metal_dark", null, 8, false)

## Authored nacelle stations preserve the engine silhouette. The shared builder
## supplies smooth skin, section seams and service fasteners at those stations.
static func cowling(k: VehicleModels, parent: Node3D, rings: Array, center: Vector3, mat: String, col = null) -> void:
	var mount := k._pivot(parent, center)
	k._add(mount, VehicleProfiles.loft(rings, 55.0, true), mat, col, Vector3.ZERO)
	for index in range(1, rings.size() - 1):
		var ring: PackedVector3Array = rings[index]
		var centroid := VehicleModels._centroid(ring)
		var points := []
		for point in ring:
			points.append(point + (point - centroid).normalized() * 0.003)
		points.append(points[0])
		VehicleBody.seam(k, mount, points, 0.003)
		for i in range(0, ring.size(), maxi(1, ring.size() >> 2)):
			var normal := (ring[i] - centroid).normalized()
			VehicleBody.fastener(k, mount, ring[i] + normal * 0.006, normal, 0.009)
	k._fold(mount)

## A bent skid runner with replaceable wear shoes at its support stations.
static func skid_runner(k: VehicleModels, parent: Node3D, points: Array, supports: Array, radius: float, mat := "gunmetal_w", col = null) -> void:
	# VehicleFrames.path's tubes and joint balls, the tubes on one band of
	# sides and open at the joints, whose balls close them.
	for i in points.size() - 1:
		VehicleBody.rod(k, parent, points[i], points[i + 1], radius, mat, col, 8, true, -1.0, i == 0, i == points.size() - 2)
		if i > 0:
			k._add(parent, Res.sphere(radius, 8), mat, col, points[i])
	for at: Vector3 in supports:
		k._add(parent, BevelMesh.make(Vector3(radius * 1.7, radius * 0.4, radius * 7), radius * 0.15), "steel", null, at + Vector3.DOWN * radius * 0.85)
		for z: float in [-1.0, 1.0]:
			VehicleBody.fastener(k, parent, at + Vector3(0, radius, z * radius * 2.5), Vector3.UP, radius * 0.18)

## A wire-deflecting blade, expressed in the old box coordinates. The blade's
## front edge and the support gusset are separate pieces within its envelope.
static func wire_cutter(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, rotation := Vector3.ZERO) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	k._add(mount, BevelMesh.make(size, size.x * 0.18), "steel", null, Vector3.ZERO)
	k._box(mount, Vector3(size.x * 0.3, size.y * 0.94, size.z * 0.2), Vector3(0, 0, -size.z * 0.48), "gunmetal_w", null, Vector3.ZERO, false)
	for y: float in [-0.32, 0.32]:
		VehicleBody.fastener(k, mount, Vector3(size.x * 0.51, size.y * y, 0), Vector3.RIGHT, size.x * 0.17)
	k._fold(mount)

static var _nozzles := {}

## Turbine exhaust from the engine face `a` to the outlet `b`, radius tapering
## to `end_radius`: an open shell (no cap over the outlet), a soot-dark liner,
## the turbine's tail cone and a heat-tinted rolled lip, all aimed along a-b so
## the outlet disc can no longer sit crooked in the pipe.
static func turbine_exhaust(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, end_radius: float, mat := "gunmetal_w", col = null) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	k.exhaust_at(parent, b, b - a)
	var mount := k._pivot(parent, a)
	mount.basis = VehicleFrames.aim(b - a)
	var depth := minf(length * 0.9, end_radius * 2.4)
	var key := "%.3f_%.3f_%.3f" % [radius, end_radius, length]
	if not _nozzles.has(key):
		var outer := CylinderMesh.new()
		outer.top_radius = end_radius
		outer.bottom_radius = radius
		outer.height = length
		outer.radial_segments = 14
		outer.rings = 0
		outer.cap_top = false
		var liner := CylinderMesh.new()
		liner.top_radius = end_radius * 0.86
		liner.bottom_radius = lerpf(end_radius, radius, depth / length) * 0.86
		liner.height = depth
		liner.radial_segments = 14
		liner.rings = 0
		liner.cap_top = false
		liner.cap_bottom = false
		liner.flip_faces = true
		_nozzles[key] = [outer, liner]
	var meshes: Array = _nozzles[key]
	k._add(mount, meshes[0], mat, col, Vector3(0, length * 0.5, 0))
	k._add(mount, meshes[1], "burnt", Color(0.03, 0.03, 0.028), Vector3(0, length - depth * 0.5, 0), Vector3.ZERO, Vector3.ONE, false)
	var core := lerpf(end_radius, radius, depth / length) * 0.86
	# (the turbine's dark face looks out of the outlet; the tail cone stands on it)
	VehicleBody.cylinder(k, mount, core, core, 0.004, Vector3(0, length - depth, 0), Vector3.ZERO, "plain_dark", null, 14, false, true, false)
	VehicleBody.cylinder(k, mount, end_radius * 0.12, core * 0.42, depth * 0.62, Vector3(0, length - depth + depth * 0.31, 0), Vector3.ZERO, "metal_dark", null, 10, false, true, false)
	k._add(mount, VehicleFittings._ring(end_radius * 0.86, end_radius * 1.03), "gunmetal", Color(0.30, 0.25, 0.19), Vector3(0, length, 0), Vector3.ZERO, Vector3(1, 0.7, 1), false)
	k._fold(mount)


# --- stores ------------------------------------------------------------------------

const X90 := Vector3(PI / 2, 0, 0)

## Nose shapes for `missile` (the x of its `nose`, from seeker(), cone() or ogive()).
const NOSE_SEEKER := 0
const NOSE_CONE := 1
const NOSE_OGIVE := 2

## An infrared or TV seeker (Sidewinder, Maverick): a glass dome of radius
## `dome` at the tip, held in a collar that flares out to the body's radius
## `length` behind the tip.
static func seeker(length: float, dome: float) -> Vector3:
	return Vector3(NOSE_SEEKER, length, dome)

## A blunt cone reaching full radius `length` behind the tip (laser-guided
## and wire-guided anti-tank missiles).
static func cone(length: float) -> Vector3:
	return Vector3(NOSE_CONE, length, 0.0)

## A tangent-ogive radome `length` long (a radar-guided missile's nose).
static func ogive(length: float) -> Vector3:
	return Vector3(NOSE_OGIVE, length, 0.0)

## `count` identical fins round a missile or store, for `missile`'s
## `surfaces`: canards, strakes, mid-body wings and tail fins alike. Stations
## are metres along the body from the missile's centre (-Z forward). The root
## chord runs from `root_front` to `root_rear` on the skin, the tip chord from
## `tip_front` to `tip_rear` at `span` beyond the skin (an old box fin of
## height h through the axis has span h / 2 - radius). Without a tip it is a
## clipped delta: half the root chord, the trailing edge straight. `roll`
## turns the first fin from straight up: PI / 4 an X, 0 a +. `thickness` 0
## takes the body's proportion.
static func fin_set(root_front: float, root_rear: float, span: float, tip_front := INF, tip_rear := INF, count := 4, roll := PI / 4, thickness := 0.0) -> Array:
	var rear := root_rear if is_inf(tip_rear) else tip_rear
	var front := rear - (root_rear - root_front) * 0.5 if is_inf(tip_front) else tip_front
	return [root_front, root_rear, span, front, rear, count, roll, thickness]


static var _fins := {}

## One fin plate, chord along Z and span along +Y from `root` to `tip` above
## the axis: a flat slab whose leading and trailing edges are chamfered to a
## knife edge, thinning toward the tip. Cached by its shape.
static func _fin(root: float, tip: float, root_front: float, root_rear: float, tip_front: float, tip_rear: float, thickness: float) -> ArrayMesh:
	var key := "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [root, tip, root_front, root_rear, tip_front, tip_rear, thickness]
	if not _fins.has(key):
		_fins[key] = VehicleProfiles.loft([_fin_section(root, root_front, root_rear, thickness), _fin_section(tip, tip_front, tip_rear, thickness * 0.6)], 30.0)
	return _fins[key]

static func _fin_section(y: float, front: float, rear: float, thickness: float) -> PackedVector3Array:
	var bevel := minf((rear - front) * 0.2, thickness * 3.0)
	var t := thickness * 0.5
	return PackedVector3Array([Vector3(0, y, front), Vector3(t, y, front + bevel), Vector3(t, y, rear - bevel), Vector3(0, y, rear), Vector3(-t, y, rear - bevel), Vector3(-t, y, front + bevel)])


## An air-launched missile lying along -Z, centred at `center`: `length` from
## the nose's tip (center.z - length / 2) to the motor's nozzle (+ length / 2),
## body `radius`. `nose` comes from seeker, cone or ogive (ZERO: a seeker of
## the body's own proportions) and may be painted `nose_col`. `surfaces` are
## fin_sets, their stations in metres from `center`. `band` is the warhead's
## yellow band (centre z, width; zero for none). `rail` is the size of the
## launch rail on its back, centred at `rail_z` with its underside on the
## body; without one, the two suspension lugs the rail would grip stand on
## the spine. Seams mark the guidance section and the motor's joint, and the
## motor ends in a sooted nozzle. The seeker's glass is left off wrecks.
static func missile(k: VehicleModels, parent: Node3D, center: Vector3, length: float, radius: float, col = null, nose := Vector3.ZERO, surfaces: Array = [], band := Vector2.ZERO, rail := Vector3.ZERO, rail_z := 0.0, mat := "paint", nose_col = null) -> void:
	var m := k._pivot(parent, center)
	var r := radius
	var front := -length * 0.5
	var back := length * 0.5
	var shape := int(nose.x)
	var dome := minf(nose.z if nose.z > 0.0 else r * 0.45, r * 0.9)
	var nose_length := nose.y if nose.y > 0.0 else r * (1.6 if shape == NOSE_SEEKER else (2.4 if shape == NOSE_CONE else 6.0))
	if shape == NOSE_SEEKER:
		nose_length = maxf(nose_length, dome * 1.4)
	nose_length = minf(nose_length, length * 0.45)
	var neck := front + nose_length
	var segs := 12 if r >= 0.07 else 10
	var tip := []
	if shape == NOSE_SEEKER:
		var base := front + dome
		var collar := minf(dome * 1.1, r)
		tip = [Vector2(0, base), Vector2(collar, base), Vector2(lerpf(collar, r, 0.55), lerpf(base, neck, 0.35)), Vector2(lerpf(collar, r, 0.88), lerpf(base, neck, 0.7)), Vector2(r, neck)]
		if not k.burnt:
			var glass := [Vector2(0, front), Vector2(dome * 0.5, base - dome * 0.866), Vector2(dome * 0.866, base - dome * 0.5), Vector2(dome, base)]
			k._add(m, VehicleProfiles.revolve(glass, segs, 60.0), "glass", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	elif shape == NOSE_CONE:
		var blunt := r * 0.2
		tip = [Vector2(0, front), Vector2(blunt * 0.7, front + blunt * 0.3), Vector2(blunt, front + blunt * 0.8), Vector2(lerpf(blunt, r, 0.52), lerpf(front, neck, 0.45)), Vector2(lerpf(blunt, r, 0.86), lerpf(front, neck, 0.78)), Vector2(r, neck)]
	else:
		# a tangent ogive: an arc of radius rho meeting the body without a kink
		var rho := (r * r + nose_length * nose_length) / (2.0 * r)
		tip = [Vector2(0, front)]
		for f: float in [0.04, 0.12, 0.25, 0.42, 0.62, 0.82, 1.0]:
			var x := nose_length * f
			tip.append(Vector2(sqrt(maxf(rho * rho - pow(nose_length - x, 2.0), 0.0)) + r - rho, front + x))
	k._add(m, VehicleProfiles.revolve(tip, segs, 50.0), mat, nose_col if nose_col is Color else col, Vector3.ZERO)
	# the body to the motor's boat-tail, the nozzle recessed in its end
	var mouth := minf(r * 0.45, 0.04)
	k._add(m, VehicleProfiles.revolve([Vector2(r, neck), Vector2(r, back - r * 0.18), Vector2(r * 0.93, back), Vector2(r * 0.6, back)], segs, 50.0), mat, col, Vector3.ZERO)
	k._add(m, VehicleProfiles.revolve([Vector2(r * 0.6, back), Vector2(r * 0.6, back - mouth), Vector2(0, back - mouth)], segs, 50.0), "metal_dark", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# the warhead's band, the section joints either side of it
	var joint := lerpf(neck, back, 0.4)
	if band.y > 0.0:
		k._add(m, _band(r * 1.012, band.x, band.y, segs), "paint", Color(0.6, 0.55, 0.25), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		joint = band.x + band.y * 0.5 + minf(0.03, r * 0.4)
	for z: float in [neck + 0.004, clampf(joint, neck + 0.02, back - 0.05)]:
		k._add(m, _band(r * 1.006, z, 0.005, segs), "paint", Color(0.1, 0.11, 0.1), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	if rail.is_zero_approx():
		for f: float in [0.3, 0.72]:
			k._box(m, Vector3(r * 0.32, r * 0.26, r * 0.7), Vector3(0, r * 1.08, lerpf(neck, back, f)), "gunmetal_w", null, Vector3.ZERO, false)
	else:
		_rail(k, m, Vector3(0, r + rail.y * 0.5, rail_z), rail)
	var thickness := clampf(r * 0.15, 0.006, 0.016)
	for fins: Array in surfaces:
		var t: float = float(fins[7]) if float(fins[7]) > 0.0 else thickness
		var plate := _fin(r * 0.93, r + float(fins[2]), float(fins[0]), float(fins[1]), float(fins[3]), float(fins[4]), t)
		var count: int = fins[5]
		for i in count:
			k._add(m, plate, mat, col, Vector3.ZERO, Vector3(0, 0, float(fins[6]) + TAU * float(i) / float(count)), Vector3.ONE, false)
	k._fold(m)


## A missile's launch rail (LAU-7 / LAU-105 pattern) in the old rail box's
## centre and size, the missile hanging under it: a raked nose fairing on
## the rail and its side bolts.
static func _rail(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3) -> void:
	var h := size.y * 0.5
	var l := size.z * 0.5
	var profile := [-l, -h, -l + size.z * 0.12, h, l, h, l, -h]
	k._add(parent, VehicleModels.extrude_x("vac_rail_%.3f_%.3f_%.3f" % [size.x, size.y, size.z], profile, -size.x * 0.5, size.x * 0.5), "gunmetal_w", null, center)
	for side: float in [-1.0, 1.0]:
		for z: float in [-l * 0.55, l * 0.6]:
			VehicleBody.fastener(k, parent, center + Vector3(side * (size.x * 0.5 + 0.002), 0, z), Vector3(side, 0, 0), minf(0.01, size.y * 0.16))


## Store pods for `pod`: a plain store (gun or dispenser pod), a fuel tank
## (filler cap on its back), a targeting pod (its front section the turning
## sensor head) and a jamming pod (radomes at both ends).
const POD_STORE := 0
const POD_TANK := 1
const POD_TARGETING := 2
const POD_ECM := 3

## A store hung under a pylon, lofted as VmPlane.body lofts it: `stations`
## are VmPlane.sec stations [z, y, w, ht, hb, (et, eb, x)] in metres from
## `center`, nose first, -Z forward (the old loft's own list, so the
## silhouette stays put; tank_stations makes a round-ended tank's). `joints`
## (z) split the body into its sections, each joint a seam band. Two NATO
## suspension lugs (14 inches apart, 30 on a store over 3.2 m) stand on the
## crown about z = 0 with sway-brace pads beside them, unless an `adapter`
## carries the store (the old adapter box's size, centred on z = 0: its
## underside sinks 1 cm into the crown, so its top stands size.y - 0.01
## above it). `kind` adds what each store has:
## POD_TANK a filler cap; POD_TARGETING the section ahead of the first joint
## as a faceted sensor head, darker, the joint a bearing ring, and a window
## on the facet that looks most nearly forward and down (glass left off
## wrecks); POD_ECM the end sections as darker radomes and antenna fairings
## under the body at the z values in `fairings`. `fins` adds that many tail
## fins (a drop tank's three: one under, two above the sides). `n` is the
## old loft's segment count. Registers nothing.
static func pod(k: VehicleModels, parent: Node3D, center: Vector3, stations: Array, mat: String, col, joints: Array = [], kind := POD_STORE, fins := 0, fairings: Array = [], adapter := Vector3.ZERO, n := 16) -> void:
	var m := k._pivot(parent, center)
	var z0 := float((stations[0] as Array)[0])
	var z1 := float((stations[stations.size() - 1] as Array)[0])
	var span := z1 - z0
	var cuts: Array[float] = [z0]
	var sorted := joints.duplicate()
	sorted.sort()
	for z in sorted:
		if float(z) > z0 + 0.02 and float(z) < z1 - 0.02:
			cuts.append(float(z))
	cuts.append(z1)
	var shade: Variant = _shade(col, 0.12)
	for i in cuts.size() - 1:
		var piece := _piece(stations, cuts[i], cuts[i + 1])
		if kind == POD_TARGETING and i == 0 and cuts.size() > 2:
			_sensor_head(k, m, piece, mat, shade)
			continue
		var radome := kind == POD_ECM and cuts.size() > 2 and (i == 0 or i == cuts.size() - 2)
		VmPlane.body(k, m, "vac_pod" + var_to_str([piece, n]), piece, mat, shade if radome else col, n, 50.0)
	for j in range(1, cuts.size() - 1):
		var bearing := kind == POD_TARGETING and j == 1
		var key := "vac_band" + var_to_str([stations, cuts[j], n, bearing])
		if bearing:
			VmPlane.band(k, m, key, stations, cuts[j], 0.03, 0.006, "gunmetal_w", null, n)
		else:
			VmPlane.band(k, m, key, stations, cuts[j], 0.018, 0.003, mat, _shade(col, 0.35), n)
	# the suspension lugs on the crown or the adapter, and the pads the
	# pylon's sway braces bear on
	var crown := VmPlane.st_at(stations, 0.0)
	var axis := Vector2(float(crown[7]), float(crown[1]))
	var top := axis.y + float(crown[3])
	if adapter.is_zero_approx():
		var spacing := minf(0.762 if span >= 3.2 else 0.356, span * 0.4)
		for z: float in [-spacing * 0.5, spacing * 0.5]:
			k._box(m, Vector3(0.05, 0.012, 0.07), Vector3(axis.x, top + 0.004, z), "steel", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.016, 0.03, 0.045), Vector3(axis.x, top + 0.022, z), "steel", null, Vector3.ZERO, false)
			var q := VmPlane.st_at(stations, z)
			for side: float in [-1.0, 1.0]:
				var a := side * 0.6
				var at := Vector3(axis.x + sin(a) * float(q[2]), axis.y + cos(a) * float(q[3]), z)
				k._box(m, Vector3(0.05, 0.005, 0.08), at, mat, _shade(col, 0.18), Vector3(0, 0, -a), false)
	else:
		# the adapter carries the store's lugs up inside the pylon
		var ac := Vector3(axis.x, top + adapter.y * 0.5 - 0.01, 0)
		k._add(m, BevelMesh.make(adapter, minf(adapter.x, adapter.y) * 0.12), "gunmetal_w", null, ac)
		for side: float in [-1.0, 1.0]:
			for z: float in [-adapter.z * 0.32, adapter.z * 0.32]:
				VehicleBody.fastener(k, m, ac + Vector3(side * (adapter.x * 0.5 + 0.002), -adapter.y * 0.15, z), Vector3(side, 0, 0), minf(0.01, adapter.y * 0.12))
	var rmax := 0.0
	for s: Array in stations:
		var q := VmPlane._sp(s)
		rmax = maxf(rmax, maxf(float(q[2]), maxf(float(q[3]), float(q[4]))))
	if kind == POD_TANK:
		var zf := lerpf(z0, z1, 0.32)
		var qf := VmPlane.st_at(stations, zf)
		VehicleFittings.filler(k, m, Vector3(axis.x, float(qf[1]) + float(qf[3]) + 0.002, zf), clampf(rmax * 0.12, 0.025, 0.05), Vector3.UP, "gunmetal_w")
	if kind == POD_ECM:
		for z in fairings:
			var q := VmPlane.st_at(stations, float(z))
			k._add(m, Res.sphere(float(q[2]) * 0.53, 10), mat, _shade(col, -0.1), Vector3(float(q[7]), float(q[1]) - float(q[4]), float(z)), Vector3.ZERO, Vector3(1, 0.6, 1.6), false)
	if fins > 0:
		# tail fins on the tail cone, a tenth of the store's length in chord
		var rf := z1 - span * 0.15
		var rr := z1 - span * 0.05
		var root := minf(float(VmPlane.st_at(stations, rf)[2]), float(VmPlane.st_at(stations, rr)[2])) * 0.9
		var plate := _fin(root, rmax * 1.45, rf, rr, rr - (rr - rf) * 0.6, rr, clampf(rmax * 0.04, 0.008, 0.016))
		for i in fins:
			var a := TAU * float(i) / float(fins) + (0.0 if (fins & 1) == 1 else PI / float(fins))
			k._add(m, plate, mat, col, Vector3(axis.x, axis.y, 0), Vector3(0, 0, PI + a), Vector3.ONE, false)
	k._fold(m)


## Stations for a round tank: the barrel from `barrel_front` to `barrel_back`
## (z) at `radius`, with rounded ends `nose` and `tail` long beyond them
## (half-ellipsoids, as a fuel tank's pressed ends are).
static func tank_stations(barrel_front: float, barrel_back: float, radius: float, nose: float, tail: float) -> Array:
	var st := []
	for u: float in [0.0, 0.08, 0.3, 0.6]:
		var w := radius * sqrt(1.0 - (1.0 - u) * (1.0 - u))
		st.append([barrel_front - nose * (1.0 - u), 0, w, w, w])
	st.append([barrel_front, 0, radius, radius, radius])
	st.append([barrel_back, 0, radius, radius, radius])
	for u: float in [0.6, 0.3, 0.08, 0.0]:
		var w := radius * sqrt(1.0 - (1.0 - u) * (1.0 - u))
		st.append([barrel_back + tail * (1.0 - u), 0, w, w, w])
	return st


## `col` darkened by `amount` (lightened when negative); null stays null.
static func _shade(col, amount: float) -> Variant:
	if not col is Color:
		return null
	var c: Color = col
	return c.darkened(amount) if amount >= 0.0 else c.lightened(-amount)


## The stations of `stations` between z = a and b, the ends interpolated.
static func _piece(stations: Array, a: float, b: float) -> Array:
	var out := [VmPlane.st_at(stations, a)]
	for s: Array in stations:
		if float(s[0]) > a + 0.005 and float(s[0]) < b - 0.005:
			out.append(s)
	out.append(VmPlane.st_at(stations, b))
	return out


## A targeting pod's sensor head: its stations as an eight-sided faceted
## loft (a flat under it) and a window framed on the facet that looks most
## nearly forward and down, where the sensor looks out.
static func _sensor_head(k: VehicleModels, parent: Node3D, piece: Array, mat: String, col) -> void:
	var rings := []
	for s: Array in piece:
		var q := VmPlane._sp(s)
		var ring := PackedVector3Array()
		for i in 8:
			var a := TAU * float(i) / 8.0 + PI / 8.0
			var half := float(q[3]) if sin(a) >= 0.0 else float(q[4])
			ring.append(Vector3(float(q[7]) + cos(a) * float(q[2]), float(q[1]) + sin(a) * half, float(q[0])))
		rings.append(ring)
	k._add(parent, VehicleProfiles.loft(rings, 20.0), mat, col, Vector3.ZERO)
	var look := Vector3(0, -0.5, -0.866)
	var best := -2.0
	var face := []
	for j in rings.size() - 1:
		var a: PackedVector3Array = rings[j]
		var b: PackedVector3Array = rings[j + 1]
		# the bottom facet lies between corners 5 and 6 (247.5 and 292.5 degrees)
		var normal := (a[6] - a[5]).cross(b[5] - a[5])
		if normal.length_squared() < 1e-10:
			normal = (b[6] - b[5]).cross(b[5] - a[5])
		normal = normal.normalized()
		if normal.y > 0.0:
			normal = -normal
		if normal.dot(look) > best:
			best = normal.dot(look)
			face = [a[5], a[6], b[6], b[5], normal]
	if face.is_empty():
		return
	var c0: Vector3 = face[0]
	var c1: Vector3 = face[1]
	var c2: Vector3 = face[2]
	var c3: Vector3 = face[3]
	var n: Vector3 = face[4]
	var front := (c0 + c1) * 0.5
	var rear := (c2 + c3) * 0.5
	var across := (c1 - c0).normalized() if c0.distance_to(c1) > 0.001 else (c2 - c3).normalized()
	var along := n.cross(across).normalized()
	var size := Vector2(lerpf(c0.distance_to(c1), c3.distance_to(c2), 0.3) * 0.9, front.distance_to(rear) * 0.72)
	var euler := Basis(across, along, n).get_euler()
	var mid := (front + rear) * 0.5
	k._box(parent, Vector3(size.x * 1.12, size.y * 1.12, 0.004), mid + n * 0.002, "metal_dark", null, euler, false)
	if not k.burnt:
		k._box(parent, Vector3(size.x, size.y, 0.003), mid + n * 0.004, "glass", null, euler, false)


static var _fans := {}

## The engine face seen down an intake: a dark annulus of `radius` round a
## hub of `hub` radius, on the face's plane at `center` (the old dark disc's
## centre), the intake opening toward `facing` (Vector3.FORWARD in a
## nacelle's front). A rolled bellmouth lip rings it. The hub is a short
## rounded cap, or with `spinner` > 0 a spinner standing that far ahead of
## the face (hub 0: none). `blades` twisted fan blades fill the annulus (a
## turbofan's fan); `vanes` straight inlet guide vanes stand ahead of them (a
## turboshaft's front frame). `dust` (length, base radius) puts a dust
## protector's cone ahead of the face in mat / col, its base on the face, so
## the annulus round it is the intake. Registers nothing; no glass.
static func intake_face(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, facing: Vector3, hub: float, spinner := 0.0, blades := 0, vanes := 0, dust := Vector2.ZERO, mat := "gunmetal_w", col = null) -> void:
	var m := k._pivot(parent, center)
	var dir := facing.normalized()
	if not dir.is_zero_approx():
		m.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)
	# local -Z now runs out through the intake's mouth
	var segs := 24 if radius > 0.3 else 16
	# (its back stays closed: a face wider than the nacelle's mouth shows it)
	VehicleBody.cylinder(k, m, radius, radius, 0.02, Vector3.ZERO, X90, "plain_dark", Color(0.05, 0.05, 0.05), segs, false)
	if dust.x <= 0.0:
		k._add(m, VehicleFittings._ring(radius * 0.92, radius), "gunmetal_w", null, Vector3(0, 0, -0.012), X90, Vector3(1, 0.6, 1), false)
	var ahead := 0.008
	if blades > 0:
		var r0 := maxf(hub * 0.98, radius * 0.2)
		var r1 := radius * 0.96
		var chord := clampf(TAU * (r0 + r1) * 0.5 / float(blades) * 0.92, 0.02, (r1 - r0) * 0.8)
		k._add(m, _fan(blades, r0, r1, chord, maxf(0.006, chord * 0.1), Vector2(0.45, 0.8)), "metal_dark", null, Vector3(0, 0, -(chord * 0.45 + ahead)), Vector3.ZERO, Vector3.ONE, false)
		ahead += chord * 0.9
	if vanes > 0:
		var chord := radius * 0.18
		k._add(m, _fan(vanes, maxf(hub * 0.5, radius * 0.1), radius * 0.97, chord, maxf(0.006, radius * 0.03), Vector2.ZERO), "gunmetal_w", null, Vector3(0, 0, -(chord * 0.5 + ahead)), Vector3.ZERO, Vector3.ONE, false)
	if hub > 0.0:
		var prof := []
		if spinner > 0.0:
			for q: Vector2 in [Vector2(0.0, 0.0), Vector2(0.08, 0.22), Vector2(0.25, 0.5), Vector2(0.5, 0.78), Vector2(0.78, 0.95), Vector2(1.0, 1.0)]:
				prof.append(Vector2(hub * q.y, -spinner * (1.0 - q.x)))
		else:
			var cap := hub * 0.38
			prof = [Vector2(0, -cap), Vector2(hub * 0.55, -cap * 0.85), Vector2(hub * 0.88, -cap * 0.45), Vector2(hub, -cap * 0.1)]
		prof.append(Vector2(hub, 0.01))
		k._add(m, VehicleProfiles.revolve(prof, 16 if spinner > 0.0 else 12, 50.0), "metal_dark" if spinner > 0.0 else "gunmetal_w", null, Vector3.ZERO)
	if dust.x > 0.0:
		var cr := dust.y
		var blunt := cr * 0.22
		var shell := [Vector2(0, -dust.x), Vector2(blunt * 0.8, -dust.x + blunt * 0.35), Vector2(blunt, -dust.x + blunt * 0.9), Vector2(cr * 0.97, -0.012), Vector2(cr, 0.0)]
		k._add(m, VehicleProfiles.revolve(shell, 12, 40.0), mat, col, Vector3.ZERO)
		k._add(m, VehicleFittings._ring(cr * 0.93, cr), "gunmetal_w", null, Vector3(0, 0, -0.01), X90, Vector3(1, 0.5, 1), false)
	k._fold(m)


## A ring of `count` thin blades round local Z from radius r0 to r1, `chord`
## wide (a little narrower at the root, wider at the tip), their leading edges
## toward -Z: each section a thin diamond, its chord turned from the axis by
## `angle` (root, tip) radians toward the direction of rotation, so a fan's
## blades twist flatter outward; ZERO makes straight vanes. One cached mesh.
static func _fan(count: int, r0: float, r1: float, chord: float, thickness: float, angle: Vector2) -> ArrayMesh:
	var key := "%d,%.4f,%.4f,%.4f,%.4f,%.3f,%.3f" % [count, r0, r1, chord, thickness, angle.x, angle.y]
	if _fans.has(key):
		return _fans[key]
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		var d := Vector3(cos(a), sin(a), 0)
		var t := Vector3(-sin(a), cos(a), 0)
		var rings: Array[PackedVector3Array] = []
		for f: float in [0.0, 0.5, 1.0]:
			var beta := lerpf(angle.x, angle.y, f)
			var cdir := Vector3(0, 0, cos(beta)) + t * sin(beta)
			var side := d.cross(cdir).normalized()
			var c := d * lerpf(r0, r1, f)
			var half := chord * lerpf(0.85, 1.1, f) * 0.5
			var th := thickness * lerpf(1.0, 0.5, f) * 0.5
			rings.append(PackedVector3Array([c - cdir * half, c + side * th, c + cdir * half, c - side * th]))
		for j in 2:
			var p: PackedVector3Array = rings[j]
			var q: PackedVector3Array = rings[j + 1]
			var mid := (VehicleModels._centroid(p) + VehicleModels._centroid(q)) * 0.5
			for e in 4:
				var e1 := (e + 1) & 3
				var out := (p[e] + p[e1] + q[e] + q[e1]) * 0.25 - mid
				var nrm := (q[e] - p[e]).cross(p[e1] - p[e]).normalized()
				if nrm.dot(out) < 0.0:
					nrm = -nrm
				VehicleProfiles._tri(vs, ns, p[e], p[e1], q[e1], nrm, nrm, nrm, nrm)
				VehicleProfiles._tri(vs, ns, p[e], q[e1], q[e], nrm, nrm, nrm, nrm)
		var tip: PackedVector3Array = rings[2]
		VehicleProfiles._tri(vs, ns, tip[0], tip[1], tip[2], d, d, d, d)
		VehicleProfiles._tri(vs, ns, tip[0], tip[2], tip[3], d, d, d, d)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(mesh, arr)
	_fans[key] = mesh
	return mesh


# --- helicopter landing gear ------------------------------------------------------------

## A helicopter's trailing-arm main gear (Black Hawk, Apache, Ka-50/52,
## Comanche): a forged drag beam pivots on a bolted airframe fitting at
## `pivot` and trails out and back to the stub axle, and an oleo shock strut,
## pinned in its clevis at `strut_top`, lands on a lug on top of the beam just
## inboard of the wheel, so the wheel rides up on the strut as the beam
## swings. `axle` is the wheel's centre and `wheel` its (radius, width): the
## old k._wheel's, which stays with the caller (its pivot, spin and
## registration), its axle along X and outboard of the pivot. The beam's end
## and the strut's foot follow from the axle, so a call takes the old tubes'
## airframe ends (pivot: the old drag tube's, strut_top: the old strut's) and
## radii. The stub axle carries a brake disc and caliper inside the tyre's
## inner wall, and a brake line runs down the strut to it. `fairing` (width
## across, length down the strut, chord fore and aft: the old fairing box's
## size, zero for none) is a faceted fairing over the strut's top in
## fairing_mat / fairing_col. `hub`, the caller's wheel pivot, with
## `hub_radius` puts a faceted hub cover of that radius and `hub_segments`
## sides on the wheel's outer face, in the same paint, on the pivot so it
## turns with the wheel. `hull` is how far out the fuselage's skin is at the
## pivot and at the strut's top (|x|; zero: none): the pivot lugs and the
## strut's clevis then sit on forged fittings that run from a few centimetres
## inside the skin out to them, so the gear hangs from the airframe. Registers
## nothing.
static func trailing_gear(k: VehicleModels, parent: Node3D, pivot: Vector3, strut_top: Vector3, axle: Vector3, wheel: Vector2, beam_radius: float, strut_radius: float, mat := "gunmetal_w", col = null, fairing := Vector3.ZERO, fairing_mat := "paint", fairing_col = null, hub: Node3D = null, hub_radius := 0.0, hub_segments := 8, hull := Vector2.ZERO) -> void:
	var side := signf(axle.x - pivot.x)
	if side == 0.0:
		side = 1.0 if axle.x >= 0.0 else -1.0
	var out := Vector3(side, 0, 0)
	var half := wheel.y * 0.5
	var br := beam_radius
	var sr := strut_radius
	# the beam's forged end, clear of the brake disc inside the tyre's wall
	var knuckle := axle - out * (half + br * 1.2 + 0.02)
	var along := (knuckle - pivot).normalized()
	var pin := along.cross(Vector3.UP).normalized()
	if pin.is_zero_approx():
		pin = Vector3.RIGHT
	# the pivot: two lugs of the airframe fitting either side of the beam's
	# root, reaching along it, the bolt through them and its nuts
	var lug_euler := Basis(pin, Vector3.UP, pin.cross(Vector3.UP)).get_euler()
	var reach := Vector3.UP.cross(pin) * br * 0.6
	for s: float in [-1.0, 1.0]:
		k._add(parent, BevelMesh.make(Vector3(br * 0.4, br * 2.2, br * 2.0), br * 0.1), "gunmetal_w", null, pivot + pin * s * br * 1.0 + Vector3.UP * br * 0.35 + reach, lug_euler)
		VehicleBody.fastener(k, parent, pivot + pin * s * br * 1.33, pin * s, br * 0.45)
	VehicleBody.rod(k, parent, pivot - pin * br * 1.3, pivot + pin * br * 1.3, br * 0.4, "steel", null, 8, false)
	if hull.x > 0.0:
		# the pivot's fitting: a forged block from inside the skin out to the
		# lugs' inner ends, as wide as the pair and as tall
		var wall := side * (hull.x - 0.03)
		var inner := pivot.x - side * br * 0.3
		if (inner - wall) * side > 0.0:
			k._box(parent, Vector3(absf(inner - wall), br * 2.2, br * 2.6), Vector3((inner + wall) * 0.5, pivot.y + br * 0.35, pivot.z), "gunmetal_w")
	# the beam tapering to the boss round the stub axle
	VehicleBody.rod(k, parent, pivot, knuckle, br, mat, col, 8, true, br * 0.8, true, false)
	VehicleBody.cylinder(k, parent, br * 1.15, br * 1.15, br * 1.5, knuckle, Vector3(0, 0, PI / 2), mat, col, 10)
	VehicleBody.rod(k, parent, knuckle, axle, br * 0.5, "steel", null, 8, false, -1.0, false, true)
	# the brake disc against the tyre's inner wall, its caliper over the top
	VehicleBody.cylinder(k, parent, wheel.x * 0.4, wheel.x * 0.4, 0.014, axle - out * (half + 0.011), Vector3(0, 0, PI / 2), "metal_dark", null, 12, false)
	var caliper := axle - out * (half + 0.016) + Vector3(0, wheel.x * 0.3, wheel.x * 0.1)
	k._box(parent, Vector3(0.03, wheel.x * 0.2, wheel.x * 0.26), caliper, "gunmetal_w", null, Vector3.ZERO, false)
	# the strut: its clevis under the airframe, the barrel, the gland nut and
	# the chrome piston down to the eye on the beam's lug
	var foot := knuckle - along * br * 2.0 + Vector3.UP * br * 0.95
	k._box(parent, Vector3(sr * 1.6, br * 0.9, sr * 1.8), knuckle - along * br * 2.0 + Vector3.UP * br * 0.5, mat, col)
	var down := foot - strut_top
	var length := down.length()
	var dn := down / maxf(length, 0.001)
	k._box(parent, Vector3(sr * 2.6, sr * 1.3, sr * 2.4), strut_top + Vector3.UP * sr * 0.45, "gunmetal_w")
	if hull.y > 0.0:
		# the clevis's fitting, out from inside the skin to the clevis block
		var wall := side * (hull.y - 0.03)
		var inner := strut_top.x - side * sr * 1.2
		if (inner - wall) * side > 0.0:
			k._box(parent, Vector3(absf(inner - wall), sr * 1.6, sr * 2.4), Vector3((inner + wall) * 0.5, strut_top.y + sr * 0.45, strut_top.z), "gunmetal_w")
	VehicleBody.rod(k, parent, strut_top - pin * sr * 1.4, strut_top + pin * sr * 1.4, sr * 0.36, "steel", null, 8, false)
	VehicleBody.rod(k, parent, strut_top, strut_top + dn * length * 0.58, sr, mat, col, 10, true, -1.0, false, false)
	VehicleBody.rod(k, parent, strut_top + dn * (length * 0.58 - sr * 0.3), strut_top + dn * (length * 0.58 + sr * 0.3), sr * 1.12, "metal_dark", null, 10, false)
	VehicleBody.rod(k, parent, strut_top + dn * length * 0.5, foot - dn * sr * 0.5, sr * 0.62, "steel", Color(0.62, 0.63, 0.6), 10, false, -1.0, false, false)
	VehicleBody.rod(k, parent, foot - pin * sr * 0.65, foot + pin * sr * 0.65, sr * 0.72, mat, col, 8, false)
	# the brake line down the strut's back to the caliper
	var aft := dn.cross(pin).normalized()
	if aft.z < 0.0:
		aft = -aft
	VehicleBody.bead(k, parent, [strut_top + dn * sr * 1.5 + aft * sr * 1.25, strut_top + dn * length * 0.62 + aft * sr * 1.4, caliper + Vector3.UP * wheel.x * 0.1], clampf(sr * 0.13, 0.005, 0.012), "rubber", null, 6, false, true)
	if fairing.x > 0.0 and fairing.y > 0.0:
		# a faceted fairing over the strut's upper part, from just inside the
		# airframe down `fairing.y`, its six facets meeting in sharp edges
		var ya := -dn
		var xa := (out - ya * out.dot(ya)).normalized()
		var za := xa.cross(ya)
		if za.z < 0.0:
			za = -za
		var w := fairing.x * 0.5
		var c := fairing.z * 0.5
		var hex := [Vector2(0, -c), Vector2(w, -c * 0.38), Vector2(w * 0.8, c * 0.55), Vector2(0, c), Vector2(-w * 0.8, c * 0.55), Vector2(-w, -c * 0.38)]
		var rings := []
		for e: Array in [[strut_top + ya * 0.04, 1.0], [strut_top - ya * (fairing.y - 0.04), 0.86]]:
			var at: Vector3 = e[0]
			var ring := PackedVector3Array()
			for q: Vector2 in hex:
				ring.append(at + (xa * q.x + za * q.y) * float(e[1]))
			rings.append(ring)
		k._add(parent, VehicleProfiles.loft(rings, 30.0), fairing_mat, fairing_col, Vector3.ZERO)
		for e: Array in [[strut_top - ya * 0.08, 1.0], [strut_top - ya * (fairing.y - 0.1), 0.88]]:
			var at: Vector3 = e[0]
			VehicleBody.fastener(k, parent, at + xa * w * float(e[1]) * 0.94 + xa * 0.003, xa, minf(0.01, w * 0.08))
	if hub != null and hub_radius > 0.0:
		# a dished, faceted cover over the hub, in the wheel pivot's own axes
		var t := hub_radius * 0.135
		var face := Vector3(side * (half + t * 0.25), 0, 0)
		var prof := [Vector2(hub_radius * 0.97, -t * 0.5), Vector2(hub_radius, -t * 0.2), Vector2(hub_radius * 0.96, t * 0.2), Vector2(hub_radius * 0.78, t * 0.5), Vector2(hub_radius * 0.3, t * 0.6), Vector2(0, t * 0.6)]
		k._add(hub, VehicleProfiles.revolve(prof, maxi(hub_segments, 4), 25.0), fairing_mat, fairing_col, face, Vector3(0, side * PI / 2, 0))
		VehicleBody.cylinder(k, hub, hub_radius * 0.13, hub_radius * 0.15, t * 0.5, face + Vector3(side * t * 0.8, 0, 0), Vector3(0, 0, PI / 2), "metal_dark", null, 6, false)
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI / 4.0
			VehicleBody.fastener(k, hub, face + Vector3(side * t * 0.56, sin(a) * hub_radius * 0.55, cos(a) * hub_radius * 0.55), Vector3(side, 0, 0), hub_radius * 0.05)


## A helicopter's tail wheel (Black Hawk, Apache, Ka-50/52, Comanche): a shock
## strut leg from its bracket under the tail boom at `top` down to the swivel
## housing, the castoring fork's crown on the swivel just over the tyre, and
## two fork arms down either side of the tyre to the axle bolt at `axle`, the
## wheel's centre; the wheel trails aft (+Z) of the swivel by a quarter of its
## radius. `wheel` is the wheel's (radius, width): the old k._wheel's, which
## stays with the caller with its pivot and registration, its axle along X.
## `top` is the old leg tube's upper end and `leg_radius` its radius; the old
## crown box (which the tyre ran through) and the leg's lower end follow from
## the axle. `brace_top` (ZERO for none) is the old brace tube's upper end: a
## drag brace of `brace_radius` from there to the leg below its middle, in
## collars at both ends. Registers nothing.
static func tailwheel(k: VehicleModels, parent: Node3D, top: Vector3, axle: Vector3, wheel: Vector2, leg_radius: float, brace_top := Vector3.ZERO, brace_radius := 0.0, mat := "gunmetal_w", col = null) -> void:
	var r := wheel.x
	var lr := leg_radius
	var arm := clampf(r * 0.09, 0.012, 0.03)
	var gap := wheel.y * 0.5 + 0.012 + arm * 0.5
	var crown_size := Vector3(gap * 2.0 + arm, r * 0.22, r * 0.62)
	var crown := axle + Vector3(0, r + 0.012 + crown_size.y * 0.5, -r * 0.24)
	# the swivel housing standing on the crown, along the leg
	var dn := (crown - top).normalized()
	var swivel_foot := crown + Vector3(0, crown_size.y * 0.4, 0)
	var swivel_head := swivel_foot - dn * lr * 2.4
	# the bracket under the boom
	k._box(parent, Vector3(lr * 2.8, lr * 0.7, lr * 3.2), top + Vector3.UP * lr * 0.25, "gunmetal_w")
	# the leg: the barrel, the gland nut, the chrome piston into the swivel
	var length := top.distance_to(swivel_head)
	VehicleBody.rod(k, parent, top, top + dn * length * 0.56, lr, mat, col, 10, true, -1.0, false, false)
	VehicleBody.rod(k, parent, top + dn * (length * 0.56 - lr * 0.3), top + dn * (length * 0.56 + lr * 0.3), lr * 1.14, "metal_dark", null, 10, false)
	VehicleBody.rod(k, parent, top + dn * length * 0.5, swivel_head, lr * 0.62, "steel", Color(0.62, 0.63, 0.6), 10, false, -1.0, false, false)
	VehicleBody.rod(k, parent, swivel_head, swivel_foot, lr * 1.3, mat, col, 10)
	# the fork: its crown, an arm down each side, the axle bolt and its nuts
	k._add(parent, BevelMesh.make(crown_size, minf(crown_size.y * 0.2, 0.01)), mat, col, crown)
	for s: float in [-1.0, 1.0]:
		VehicleFrames.beam(k, parent, axle + Vector3(s * gap, 0, 0), crown + Vector3(s * gap, -crown_size.y * 0.3, 0), arm, r * 0.26, mat, col)
		VehicleBody.fastener(k, parent, axle + Vector3(s * (gap + arm * 0.5 + 0.003), 0, 0), Vector3(s, 0, 0), r * 0.13)
	VehicleBody.cylinder(k, parent, r * 0.1, r * 0.1, gap * 2.0 + arm + 0.006, axle, Vector3(0, 0, PI / 2), "steel", null, 8, false)
	if brace_top != Vector3.ZERO and brace_radius > 0.0:
		var foot := top.lerp(swivel_head, 0.62)
		var bd := (foot - brace_top).normalized()
		k._box(parent, Vector3(brace_radius * 2.6, brace_radius * 0.8, brace_radius * 3.0), brace_top + Vector3.UP * brace_radius * 0.3, "gunmetal_w")
		VehicleBody.rod(k, parent, brace_top, foot, brace_radius, "steel", null, 8, true, -1.0, false, false)
		for at: Vector3 in [brace_top + bd * brace_radius * 1.6, foot - bd * brace_radius * 1.6]:
			VehicleBody.rod(k, parent, at - bd * brace_radius * 1.2, at + bd * brace_radius * 1.2, brace_radius * 1.35, "gunmetal_w", null, 8, false)


# --- countermeasures, lights and refuelling -----------------------------------------------

static var _cells := {}

## A chaff and flare dispenser (AN/ALE-40 and -47, UV-26): a magazine let into
## a pod, sponson or wing tip, its face a grid of round cartridge cells, each
## cartridge's end cap set back in its cell inside a dark ring. `center`,
## `size` and `rotation` are the old box's; `face` is the box's local axis the
## cells open toward (Vector3.DOWN under a wing tip, +-X on a flank). `cols`
## cells run along the box's local Z (along X on a face toward +-Z) and `rows`
## across the face's other axis; `field` (cols extent, rows extent) is the
## cell field's size, centred on the face, zero for the whole face inside a
## 12 % rim. The housing keeps the old box; the field and the cells' lips
## stand under 5 mm proud of its face. Every lip is one cached mesh and every
## cap another, so a dispenser costs four parts whatever its count.
## Registers nothing.
static func dispenser(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation: Vector3, face: Vector3, rows: int, cols: int, mat := "gunmetal_w", col = null, field := Vector2.ZERO) -> void:
	var m := k._pivot(parent, center)
	m.rotation = rotation
	var f := face.normalized()
	var u := Vector3.BACK if absf(f.z) < 0.5 else Vector3.RIGHT
	var v := f.cross(u)
	var depth := absf(size.dot(f)) * 0.5
	var span := Vector2(absf(size.dot(u)), absf(size.dot(v)))
	var area := field if field.x > 0.0 and field.y > 0.0 else span * 0.76
	var nr := maxi(1, rows)
	var nc := maxi(1, cols)
	var pitch := Vector2(area.x / float(nc), area.y / float(nr))
	var radius := minf(pitch.x, pitch.y) * 0.42
	k._add(m, BevelMesh.make(size, minf(0.006, minf(size.x, minf(size.y, size.z)) * 0.2)), mat, col, Vector3.ZERO)
	var euler := Basis(u, v, f).get_euler()
	k._add(m, Res.box(Vector3(area.x + radius * 0.5, area.y + radius * 0.5, 0.002)), "plain_dark", null, f * (depth + 0.001), euler, Vector3.ONE, false)
	var cells := _cell_meshes(nr, nc, pitch, radius)
	k._add(m, cells[0], mat, col, f * depth, euler, Vector3.ONE, false)
	k._add(m, cells[1], "paint", Color(0.36, 0.35, 0.29), f * depth, euler, Vector3.ONE, false)
	k._fold(m)


## A dispenser face's cells in its own frame (+Z out of the face, cols along
## X, rows along Y): each cell's lip ring 4.8 mm up with its wall down to the
## dark field, and the cartridge's cap 2.6 mm up inside it. Cached by layout.
static func _cell_meshes(rows: int, cols: int, pitch: Vector2, radius: float) -> Array:
	var key := "%d,%d,%.4f,%.4f,%.4f" % [rows, cols, pitch.x, pitch.y, radius]
	if _cells.has(key):
		return _cells[key]
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var cv := PackedVector3Array()
	var cn := PackedVector3Array()
	var inner := radius * 0.78
	var cap := radius * 0.66
	var lip := Vector3(0, 0, 0.0048)
	var base := Vector3(0, 0, 0.002)
	var z := Vector3.BACK
	for j in rows:
		for i in cols:
			var c := Vector3((float(i) - float(cols - 1) * 0.5) * pitch.x, (float(j) - float(rows - 1) * 0.5) * pitch.y, 0)
			var cc := c + Vector3(0, 0, 0.0026)
			for s in 8:
				var d0 := Vector3(cos(TAU * float(s) / 8.0), sin(TAU * float(s) / 8.0), 0)
				var d1 := Vector3(cos(TAU * float(s + 1) / 8.0), sin(TAU * float(s + 1) / 8.0), 0)
				var o0 := c + d0 * radius + lip
				var o1 := c + d1 * radius + lip
				var i0 := c + d0 * inner + lip
				var i1 := c + d1 * inner + lip
				VehicleProfiles._tri(lv, ln, o0, o1, i1, z, z, z, z)
				VehicleProfiles._tri(lv, ln, o0, i1, i0, z, z, z, z)
				var wn := -(d0 + d1).normalized()
				VehicleProfiles._tri(lv, ln, i0, i1, c + d1 * inner + base, wn, wn, wn, wn)
				VehicleProfiles._tri(lv, ln, i0, c + d1 * inner + base, c + d0 * inner + base, wn, wn, wn, wn)
				VehicleProfiles._tri(cv, cn, cc, cc + d0 * cap, cc + d1 * cap, z, z, z, z)
	_cells[key] = [_flat_mesh(lv, ln), _flat_mesh(cv, cn)]
	return _cells[key]


static func _flat_mesh(vs: PackedVector3Array, ns: PackedVector3Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(mesh, arr)
	return mesh


## A surface for fittings laid on the skin: metres along `along` (x) and
## across it (y) about `center`, facing `normal`. A valid `skin` takes each
## point of that plane onto a curved skin (a Callable from a point to the
## skin's point, as VmFighter._project or a hull's half-width finds it).
static func _face(center: Vector3, normal: Vector3, along: Vector3, skin := Callable()) -> VehicleSurface:
	var n := normal.normalized()
	var x := along - n * along.dot(n)
	if x.length_squared() < 1e-8:
		x = Vector3.BACK - n * n.z
	x = x.normalized()
	var y := n.cross(x)
	if skin.is_valid():
		return VehicleSurface.new(func(q: Vector2) -> Vector3:
			var p: Vector3 = skin.call(center + x * q.x + y * q.y)
			return p, n)
	return VehicleSurface.new(func(q: Vector2) -> Vector3: return center + x * q.x + y * q.y, n)


## A raised plate on `surface` over `rect` (its metres; the x side cut into
## `steps` so it follows a curved skin): the top `lift` off the skin, its
## sides down to lift - depth. Appended to `data` for VehicleSurface._mesh.
static func _plate(data: Array, surface: VehicleSurface, rect: Rect2, lift: float, depth: float, steps := 1) -> void:
	var n := maxi(1, steps)
	var y0 := rect.position.y
	var y1 := rect.end.y
	var mid := surface.point(rect.get_center(), lift)
	var xs: Array[float] = []
	for i in n + 1:
		xs.append(lerpf(rect.position.x, rect.end.x, float(i) / float(n)))
	for i in n:
		var q0 := Vector2(xs[i], y0)
		var q1 := Vector2(xs[i + 1], y0)
		var q2 := Vector2(xs[i + 1], y1)
		var q3 := Vector2(xs[i], y1)
		var up := surface.normal(Vector2((xs[i] + xs[i + 1]) * 0.5, (y0 + y1) * 0.5))
		VehicleSurface._quad(data, surface.point(q0, lift), surface.point(q1, lift), surface.point(q2, lift), surface.point(q3, lift), up)
		_wall(data, surface, q0, q1, lift, depth, mid)
		_wall(data, surface, q3, q2, lift, depth, mid)
	_wall(data, surface, Vector2(xs[0], y0), Vector2(xs[0], y1), lift, depth, mid)
	_wall(data, surface, Vector2(xs[n], y0), Vector2(xs[n], y1), lift, depth, mid)


static func _wall(data: Array, surface: VehicleSurface, a: Vector2, b: Vector2, lift: float, depth: float, mid: Vector3) -> void:
	var p0 := surface.point(a, lift)
	var p1 := surface.point(b, lift)
	var p2 := surface.point(b, lift - depth)
	var p3 := surface.point(a, lift - depth)
	var n := (p1 - p0).cross(p3 - p0)
	if n.length_squared() < 1e-12:
		return
	if n.dot((p0 + p1) * 0.5 - mid) < 0.0:
		n = -n
	VehicleSurface._quad(data, p0, p1, p2, p3, n.normalized())


## A flat stripe from a to b (the surface's metres), `width` wide, `lift` off
## the skin, in `steps` pieces. Appended to `data`.
static func _stripe(data: Array, surface: VehicleSurface, a: Vector2, b: Vector2, width: float, lift: float, steps := 1) -> void:
	var across := (b - a).orthogonal().normalized() * width * 0.5
	var n := maxi(1, steps)
	for i in n:
		var p := a.lerp(b, float(i) / float(n))
		var q := a.lerp(b, float(i + 1) / float(n))
		VehicleSurface._quad(data, surface.point(p - across, lift), surface.point(q - across, lift), surface.point(q + across, lift), surface.point(p + across, lift), surface.normal((p + q) * 0.5))


## The pale yellow-green of a formation light by day.
const FORMATION := Color(0.55, 0.62, 0.45)

## A formation ("slime") light: an electroluminescent strip a wingman holds
## station on at night, pale yellow-green by day. `center` is the strip's
## middle on the skin, `size` its (length along `along`, width) and `normal`
## the skin's outward normal there. An old box strip passes its inner face (its
## centre less half its thickness along the normal) and its long and thin
## axes turned by its rotation; a hull stripe or a decal passes its middle,
## and `skin` (see _face) lays the strip on the curved skin as the stripe or
## decal was laid. A dark frame 4 mm off the skin fills that footprint; the
## panel stands 2.5 mm above it inside its rim, in sections about every 0.6 m
## of a long strip. Wrecks keep both, burnt. Registers nothing.
static func formation_light(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, normal: Vector3, along: Vector3, col := FORMATION, skin := Callable()) -> void:
	var surface := _face(center, normal, along, skin)
	var steps := clampi(ceili(size.x / 0.12), 1, 20) if skin.is_valid() else 1
	var rim := clampf(size.y * 0.14, 0.003, 0.01)
	var hl := size.x * 0.5
	var hw := size.y * 0.5
	var frame := [[], [], []]
	_plate(frame, surface, Rect2(-hl, -hw, size.x, size.y), 0.004, 0.006, steps)
	k._add(parent, VehicleSurface._mesh(frame), "metal_dark", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# the panel inside the frame's rim, in sections
	var inner := size - Vector2(rim, rim) * 2.0
	var count := clampi(roundi(inner.x / 0.6), 1, 6)
	var gap := minf(0.01, inner.x * 0.02)
	var each := maxi(1, ceili(float(steps) / float(count)))
	var panel := [[], [], []]
	for i in count:
		var a := -hl + rim + inner.x * float(i) / float(count) + (gap * 0.5 if i > 0 else 0.0)
		var b := -hl + rim + inner.x * float(i + 1) / float(count) - (gap * 0.5 if i < count - 1 else 0.0)
		_plate(panel, surface, Rect2(a, -hw + rim, b - a, inner.y), 0.0065, 0.003, each)
	k._add(parent, VehicleSurface._mesh(panel), "paint", col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## An air-refuelling receptacle (UARRSI) where a tanker's flying boom plugs in,
## on a spine, a roof or a nose. `center` is the slipway's centre on the skin,
## `size` its (length along `forward`, width), `normal` the skin's outward
## normal and `forward` the way along the skin its mouth faces (the boom's
## nozzle slides in from that end). Closed, it is the slipway door: a panel a
## shade darker than `col` standing 4 mm proud in its dark seam (clear of a
## hull's coarser mesh, as the old 6 mm decals were), two hinge knuckles at
## its back edge. `open` shows the slipway: a dark funnel narrowing back from the
## mouth between raised rails, and the receptacle's nozzle socket at the
## narrow end facing the mouth, its latch ring and dark bore. `height` raises
## it on a fairing that tall in mat / col (the A-10's nose housing; 0 flush):
## `size` is then the fairing's footprint (the old fairing box's), the
## slipway inset in it at 0.86 of its length and 0.8 of its width.
## `lead` paints the boom operator's two white guide lines that far beyond
## the mouth, 8 mm off the skin as the old slip-line decals were, converging
## away from it (negative: behind the slipway's back end, as on the A-10's
## nose; 0 none), in `lead_col` (white; the F-16's low-visibility lines are
## dark); like other markings they are left off wrecks. `skin` lays it all on a curved skin (see _face). Registers nothing.
static func refuel_receptacle(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, normal: Vector3, forward: Vector3, open := false, height := 0.0, lead := 0.0, mat := "aircraft", col = null, skin := Callable(), lead_col := Color(0.85, 0.85, 0.8)) -> void:
	var surface := _face(center, normal, forward, skin)
	var curved := skin.is_valid()
	var hl := size.x * 0.5
	var hw := size.y * 0.5
	var steps := clampi(ceili(size.x / 0.15), 1, 8) if curved else 1
	var div := 1 if curved else 0
	var base := 0.0
	var reach := hl
	if height > 0.0:
		var fair := [[], [], []]
		_plate(fair, surface, Rect2(-hl, -hw, size.x, size.y), height, height + 0.01, steps)
		k._add(parent, VehicleSurface._mesh(fair), mat, col, Vector3.ZERO)
		base = height
		hl *= 0.86
		hw *= 0.8
	if open:
		# the slipway: wide at the mouth (+x), narrowing back to the socket
		var outline := PackedVector2Array([Vector2(hl, -hw * 0.9), Vector2(hl, hw * 0.9), Vector2(-hl * 0.2, hw * 0.34), Vector2(-hl, hw * 0.34), Vector2(-hl, -hw * 0.34), Vector2(-hl * 0.2, -hw * 0.34)])
		k._add(parent, surface.patch(outline, base + 0.0025, 0.0025, div), "plain_dark", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		VehicleBody.boundary(k, parent, surface, outline, base + 0.003, minf(0.006, size.y * 0.025), false, div, "gunmetal_w")
		# the socket lies half sunk in the slipway's floor
		var rn := hw * 0.18
		var back := surface.point(Vector2(-hl * 0.86, 0), base + rn * 0.1)
		var front := surface.point(Vector2(-hl * 0.42, 0), base + rn * 0.1)
		var dx := (front - back).normalized()
		VehicleBody.rod(k, parent, back, front, rn, "gunmetal_w", null, 12)
		VehicleBody.rod(k, parent, front - dx * 0.014, front, rn * 1.14, "metal_dark", null, 12, false)
		VehicleBody.rod(k, parent, front, front + dx * 0.003, rn * 0.6, "plain_dark", null, 10, false)
	else:
		var door := PackedVector2Array([Vector2(-hl, -hw), Vector2(hl, -hw), Vector2(hl, hw), Vector2(-hl, hw)])
		k._add(parent, surface.patch(door, base + 0.004, 0.004, div), mat, _shade(col, 0.15), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		VehicleBody.boundary(k, parent, surface, door, base + 0.0035, minf(0.004, size.y * 0.02), false, div, "plain_dark")
		var axis := (surface.point(Vector2(-hl, 0.01)) - surface.point(Vector2(-hl, -0.01))).normalized()
		for y: float in [-hw * 0.55, hw * 0.55]:
			var at := surface.point(Vector2(-hl + 0.008, y), base + 0.006)
			VehicleBody.rod(k, parent, at - axis * hw * 0.12, at + axis * hw * 0.12, minf(0.006, hw * 0.05), "metal_dark", null, 6, false)
	if lead != 0.0 and not k.burnt:
		var start := (reach + 0.02) * signf(lead)
		var lines := [[], [], []]
		for s: float in [-1.0, 1.0]:
			_stripe(lines, surface, Vector2(start, s * hw * 0.8), Vector2(start + lead, s * hw * 0.32), clampf(size.y * 0.09, 0.02, 0.05), 0.008, clampi(ceili(absf(lead) / 0.15), 1, 10) if curved else 1)
		k._add(parent, VehicleSurface._mesh(lines), "paint", lead_col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


# --- bombs ------------------------------------------------------------------------------

## Kits for `bomb`: a Mk 80 general-purpose bomb, a Paveway II laser-guided
## bomb, a JDAM.
const BOMB_GP := 0
const BOMB_LGB := 1
const BOMB_JDAM := 2
## Bomb bodies are olive drab; guidance kits store grey.
const BOMB_OLIVE := Color(0.33, 0.35, 0.27)
const GUIDANCE_GREY := Color(0.55, 0.56, 0.55)
## Case stations (z / length, radius / radius): VmPlane.bomb's Mk 80 low-drag
## case, and VmFighter._gbu31's Mk 84 with the JDAM tail kit from 0.245.
const _MK80 := [Vector2(-0.5, 0.08), Vector2(-0.44, 0.55), Vector2(-0.3, 0.92), Vector2(-0.12, 1.0), Vector2(0.18, 1.0), Vector2(0.34, 0.72), Vector2(0.46, 0.5)]
const _MK84 := [Vector2(-0.5, 0.087), Vector2(-0.459, 0.42), Vector2(-0.387, 0.76), Vector2(-0.271, 0.96), Vector2(-0.18, 1.0), Vector2(0.116, 1.0), Vector2(0.237, 0.84), Vector2(0.245, 0.88), Vector2(0.464, 0.8), Vector2(0.5, 0.6)]

## A bomb lying along -Z, centred at `center`, revolved as `missile` is and in
## the proportions of the helper it replaces. `length` and `radius` are
## VmPlane.bomb's (the case from its nose at -length / 2 to the tail cone at
## +0.46 length, the fins to +0.49) or VmFighter._gbu31's (3.88, 0.229: the
## Mk 84 from -1.94 to 1.94). `kit` adds what each store carries:
## BOMB_GP a Mk 80 low-drag bomb: the nose fuze in its well, the conical fin
##   assembly's joint and four fins (an X);
## BOMB_LGB a Paveway II: the guidance group in place of the fuze, its seeker
##   dome in a gimbal ring 0.64 length plus 0.4 radius ahead of the centre,
##   the computer section with four canards, and the airfoil group's big tail
##   wings reaching to +0.51 length;
## BOMB_JDAM the Mk 84 case with a nose fuze, the strake kit (a strake each
##   side and one under, on two bands) and the tail kit's joint and four fins.
## A yellow nose band marks it live, and two suspension lugs stand on its back
## at NATO spacing (14 inches, 30 for a 2,000 lb bomb of radius 0.2 and over),
## 3.7 cm proud of the case. `col` paints the case and fins (olive when null);
## the guidance group is store grey. The seeker's glass is left off wrecks.
## Registers nothing.
static func bomb(k: VehicleModels, parent: Node3D, center: Vector3, length: float, radius: float, kit := BOMB_GP, col = null, mat := "paint") -> void:
	var m := k._pivot(parent, center)
	var L := length
	var r := radius
	var c: Color = col if col is Color else BOMB_OLIVE
	var segs := 16 if r >= 0.2 else 14
	var jdam := kit == BOMB_JDAM
	var st: Array = _MK84 if jdam else _MK80
	# the case from the fuze well's face to its tail
	var nose := -L * 0.5 + r * 0.2
	var prof := [Vector2(0, nose), Vector2(r * _case_radius(st, nose / L), nose)]
	for q: Vector2 in st:
		if q.x * L > nose + 0.003:
			prof.append(Vector2(r * q.y, q.x * L))
	if jdam:
		prof.append(Vector2(0, L * 0.5))
	else:
		prof.append_array([Vector2(r * 0.44, L * 0.462), Vector2(0, L * 0.462)])
	k._add(m, VehicleProfiles.revolve(prof, segs, 50.0), mat, c, Vector3.ZERO)
	var t := clampf(r * 0.08, 0.006, 0.016)
	if kit == BOMB_LGB:
		# the guidance group: the seeker in its gimbal ring, the computer
		# section narrowing back over the case's nose, four canards
		var front := -L * 0.64
		var dome := r * 0.5
		var group := [Vector2(dome * 0.98, front), Vector2(r * 0.72, front + r * 0.04), Vector2(r * 0.75, front + L * 0.03), Vector2(r * 0.7, -L * 0.55), Vector2(r * 0.6, -L * 0.49), Vector2(r * 0.56, -L * 0.47), Vector2(r * 0.3, -L * 0.47)]
		k._add(m, VehicleProfiles.revolve(group, segs, 40.0), mat, GUIDANCE_GREY, Vector3.ZERO)
		VehicleBody.cylinder(k, m, dome * 1.04, dome * 1.04, 0.012, Vector3(0, 0, front + 0.004), X90, "gunmetal_w", null, segs, false)
		if not k.burnt:
			var glass := [Vector2(0, front - dome * 0.8), Vector2(dome * 0.5, front - dome * 0.69), Vector2(dome * 0.87, front - dome * 0.4), Vector2(dome, front)]
			k._add(m, VehicleProfiles.revolve(glass, segs, 60.0), "glass", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		var canard := _fin(r * 0.66, r * 1.2, -L * 0.59, -L * 0.515, -L * 0.555, -L * 0.515, t * 0.8)
		for i in 4:
			k._add(m, canard, mat, GUIDANCE_GREY, Vector3.ZERO, Vector3(0, 0, PI / 4 + PI / 2 * float(i)), Vector3.ONE, false)
	else:
		# the nose fuze standing in its well
		var fuze := [Vector2(0, -L * 0.5), Vector2(r * 0.05, -L * 0.5 + r * 0.04), Vector2(r * 0.09, -L * 0.5 + r * 0.11), Vector2(r * 0.12, nose - 0.002), Vector2(r * 0.12, nose + 0.004)]
		k._add(m, VehicleProfiles.revolve(fuze, 8, 50.0), "steel", Color(0.5, 0.47, 0.38), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# the yellow band of a live bomb behind the nose
	var bz := -L * (0.322 if jdam else 0.2)
	var bw := 0.06 if jdam else 0.05
	var band_r := r * maxf(_case_radius(st, (bz - bw * 0.5) / L), _case_radius(st, (bz + bw * 0.5) / L)) * 1.012
	k._add(m, _band(band_r, bz, bw, segs), "paint", Color(0.62, 0.55, 0.22), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# the suspension lugs on the back
	var spacing := minf(0.762 if r >= 0.2 else 0.356, L * 0.4)
	for z: float in [-spacing * 0.5, spacing * 0.5]:
		var top := r * _case_radius(st, z / L)
		k._box(m, Vector3(0.05, 0.011, 0.07), Vector3(0, top + 0.004, z), "steel", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.011, 0.03, 0.045), Vector3(0, top + 0.022, z), "steel", null, Vector3.ZERO, false)
	var dark := c.darkened(0.08)
	if jdam:
		# the strake kit on its two bands, the tail kit's joint and fins
		for z: float in [-L * 0.18, L * 0.05]:
			k._add(m, _band(r * _case_radius(st, z / L) * 1.008, z, 0.035, segs), mat, c.darkened(0.15), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		var strake := _fin(r * 0.96, r * 1.37, -L * 0.167, L * 0.039, -L * 0.13, L * 0.03, 0.012)
		for roll: float in [PI / 2, -PI / 2, PI]:
			k._add(m, strake, mat, c.darkened(0.1), Vector3.ZERO, Vector3(0, 0, roll), Vector3.ONE, false)
		k._add(m, _band(r * 0.9, L * 0.242, 0.03, segs), "gunmetal_w", null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		var tail := _fin(r * 0.7, r * 1.87, L * 0.374, L * 0.497, L * 0.433, L * 0.497, clampf(r * 0.07, 0.008, 0.016))
		for i in 4:
			k._add(m, tail, mat, dark, Vector3.ZERO, Vector3(0, 0, PI / 4 + PI / 2 * float(i)), Vector3.ONE, false)
	else:
		# the fin assembly's joint ring on the tail cone, its four fins
		k._add(m, _band(r * _case_radius(st, 0.26) * 1.006, L * 0.26, 0.006, segs), "paint", c.darkened(0.35), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		var lgb := kit == BOMB_LGB
		var fin := _fin(r * 0.48, r * (1.6 if lgb else 1.35), L * (0.31 if lgb else 0.33), L * 0.49, L * (0.42 if lgb else 0.42), L * (0.51 if lgb else 0.49), t)
		for i in 4:
			k._add(m, fin, mat, dark, Vector3.ZERO, Vector3(0, 0, PI / 4 + PI / 2 * float(i)), Vector3.ONE, false)
	k._fold(m)


## A thin band round a body revolved about local Z, at z, `width` wide:
## revolved with the body's own facets, so it stands evenly proud of them
## where a cylinder's facets would cross theirs.
static func _band(radius: float, z: float, width: float, segs: int) -> ArrayMesh:
	return VehicleProfiles.revolve([Vector2(radius, z - width * 0.5), Vector2(radius, z + width * 0.5)], segs, 30.0)


## A bomb case's radius (a fraction of its radius) at z / length `f`.
static func _case_radius(st: Array, f: float) -> float:
	var a: Vector2 = st[0]
	if f <= a.x:
		return a.y
	for i in range(1, st.size()):
		var b: Vector2 = st[i]
		if f <= b.x:
			return lerpf(a.y, b.y, (f - a.x) / maxf(b.x - a.x, 1e-5))
		a = b
	return a.y


# --- chin turrets -----------------------------------------------------------------------

## The housing of a helicopter's chin gun turret (the Apache's M230, the
## Comanche's XM301, the Mi-28's 2A42, a twin 23 mm ball): the turning drum,
## the yoke hanging from its bolted mounting plate with the gun's elevation
## trunnions, the gun's cradle, the elevation jack and the ammunition feed. It
## is built on the caller's turret pivot `turret`, in its coordinates, so it
## turns with it; the gun itself (VehicleWeapons.rotary or autocannon), the
## pivot and the muzzle marker stay with the caller. `drum` is the old drum
## cylinder's centre, `drum_radius` its (top, bottom) radii and `drum_height`
## its height; with `ball` the drum is a ball housing of radius drum_radius.x
## that tall (an old sphere's radius, its height twice the radius times its y
## scale) with a rubber boot where the cradle leaves it, and no yoke arms.
## `cradle` and `cradle_size` are the old gunmetal box the gun lay in (its
## receiver housing): a bevelled cradle with a feed cover and the receiver's
## split line, held by yoke arms from the drum's underside to trunnions on
## either side of it under the drum's centre. `chute` (+1 right, -1 left, 0
## none) adds the feeder on that side of the cradle (the Apache's old feed
## box) and the linked ammunition chute from it up past the drum into the
## airframe. `magazines` (an old magazine box's size, zero none) hangs a
## magazine either side of the cradle under the drum's centre, clear of the
## trunnions, its lid seam, latches and a feed chute across to the cradle
## (the 2A42's dual feed). `segments` facets the drum (8 for a faceted stealth
## nose). Registers nothing.
static func chin_turret(k: VehicleModels, turret: Node3D, drum: Vector3, drum_radius: Vector2, drum_height: float, cradle: Vector3, cradle_size: Vector3, mat := "aircraft", col = null, chute := 0.0, magazines := Vector3.ZERO, ball := false, segments := 12) -> void:
	var h := drum_height
	var rt := drum_radius.x
	var rb := drum_radius.y
	var cs := cradle_size
	var upright := Vector3(-PI / 2, 0, 0)
	var bottom := drum.y - h * 0.5
	var segs := maxi(segments, 4)
	if ball:
		var prof := []
		for i in 9:
			var a := PI * float(i) / 8.0
			prof.append(Vector2(rt * sin(a), -h * 0.5 * cos(a)))
		k._add(turret, VehicleProfiles.revolve(prof, segs, 50.0), mat, col, drum, upright)
		k._add(turret, _band(rt * 1.006, 0.0, 0.012, segs), "paint", Color(0.1, 0.11, 0.1), drum, upright, Vector3.ONE, false)
		# the rubber boot where the cradle comes out of the ball
		var dx := (cradle.x - drum.x) / rt
		var dy := (cradle.y - drum.y) / (h * 0.5)
		var inside := 1.0 - dx * dx - dy * dy
		if inside > 0.0:
			k._box(turret, Vector3(cs.x + 0.03, cs.y + 0.03, 0.03), Vector3(cradle.x, cradle.y, drum.z - rt * sqrt(inside) + 0.004), "rubber")
	else:
		var prof := [Vector2(0, -h * 0.5), Vector2(rb * 0.9, -h * 0.5), Vector2(rb, -h * 0.5 + h * 0.16), Vector2(lerpf(rb, rt, 0.82), h * 0.3), Vector2(rt, h * 0.5)]
		k._add(turret, VehicleProfiles.revolve(prof, segs, 30.0 if segs < 10 else 50.0), mat, col, drum, upright)
		# the seam where the drum's lower ring turns, the yoke's mounting
		# plate under it and the plate's bolts
		k._add(turret, _band(lerpf(rb, rt, 0.25) * 1.008, -h * 0.12, 0.006, segs), "paint", Color(0.1, 0.11, 0.1), drum, upright, Vector3.ONE, false)
		VehicleBody.cylinder(k, turret, rb * 0.8, rb * 0.8, 0.012, Vector3(drum.x, bottom - 0.006, drum.z), Vector3.ZERO, "gunmetal_w", null, segs, false, false, true)
		for i in 6:
			var a := TAU * float(i) / 6.0 + PI / 6.0
			VehicleBody.fastener(k, turret, Vector3(drum.x + sin(a) * rb * 0.66, bottom - 0.013, drum.z + cos(a) * rb * 0.66), Vector3.DOWN, minf(0.012, rb * 0.05))
	# the cradle, its feed cover and the receiver's split line
	k._add(turret, BevelMesh.make(cs, minf(cs.x, cs.y) * 0.1), "gunmetal_w", null, cradle)
	k._box(turret, Vector3(cs.x * 0.78, 0.01, cs.z * 0.42), cradle + Vector3(0, cs.y * 0.5 + 0.005, cs.z * 0.08), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(turret, Vector3(cs.x + 0.004, cs.y + 0.004, 0.006), cradle + Vector3(0, 0, -cs.z * 0.22), "plain_dark", null, Vector3.ZERO, false)
	var arm := clampf(cs.x * 0.1, 0.012, 0.03)
	var tz := clampf(drum.z, cradle.z - cs.z * 0.4, cradle.z + cs.z * 0.4)
	var tr := clampf(cs.y * 0.3, 0.025, 0.08)
	var arm_d := clampf(tr * 2.6, 0.06, cs.z * 0.6)
	if not ball:
		# the yoke: an arm down each side of the cradle to its trunnion, the
		# trunnion's boss and cap
		var arm_top := bottom - 0.006
		var arm_bot := cradle.y - tr * 0.9
		if arm_top - arm_bot > 0.02:
			for s: float in [-1.0, 1.0]:
				var ax := s * (cs.x * 0.5 + arm * 0.5 + 0.004)
				k._add(turret, BevelMesh.make(Vector3(arm, arm_top - arm_bot, arm_d), arm * 0.3), "gunmetal_w", null, Vector3(cradle.x + ax, (arm_top + arm_bot) * 0.5, tz))
				VehicleBody.cylinder(k, turret, tr, tr, arm * 1.2, Vector3(cradle.x + ax + s * arm * 0.4, cradle.y, tz), Vector3(0, 0, PI / 2), "metal_dark", null, 10, false)
				VehicleBody.fastener(k, turret, Vector3(cradle.x + ax + s * (arm + 0.003), cradle.y, tz), Vector3(s, 0, 0), tr * 0.45)
		# the elevation jack from the drum's underside to the cradle's back,
		# where the cradle hangs clear below the drum
		if bottom - (cradle.y + cs.y * 0.5) > 0.04:
			var jr := clampf(cs.x * 0.12, 0.012, 0.03)
			var j0 := Vector3(cradle.x, bottom - 0.004, drum.z + rb * 0.55)
			var j1 := Vector3(cradle.x, cradle.y + cs.y * 0.5 - 0.004, cradle.z + cs.z * 0.38)
			VehicleBody.rod(k, turret, j0, j0.lerp(j1, 0.55), jr, "gunmetal_w", null, 8, false, -1.0, false, true)
			VehicleBody.rod(k, turret, j0.lerp(j1, 0.45), j1, jr * 0.6, "steel", Color(0.62, 0.63, 0.6), 8, false, -1.0, false, false)
	if chute != 0.0:
		# the feeder on the cradle's side, the linked chute from it up past the
		# drum into the airframe, with its link ribs
		var sd := signf(chute)
		var fw := clampf(cs.x * 0.6, 0.06, 0.16)
		var fs := Vector3(fw, cs.y * 0.55, cs.z * 0.6)
		var feeder := cradle + Vector3(sd * (cs.x * 0.5 + fw * 0.5), cs.y * 0.15, cs.z * 0.3)
		k._add(turret, BevelMesh.make(fs, fw * 0.1), "gunmetal_w", null, feeder)
		var reach := maxf(rt, rb)
		var a := feeder + Vector3(0, fs.y * 0.5, fs.z * 0.15)
		var b := Vector3(drum.x + sd * (reach + fw * 0.35), drum.y + h * 0.5, drum.z + reach * 0.5)
		var mid := a.lerp(b, 0.5) + Vector3(sd * fw * 0.35, 0, fw * 0.4)
		var cw := fw * 0.8
		var ct := fw * 0.32
		VehicleFrames.beam(k, turret, a, mid, cw, ct, "metal_dark")
		VehicleFrames.beam(k, turret, mid, b, cw, ct, "metal_dark")
		for f: float in [0.25, 0.75]:
			for seg: Array in [[a, mid], [mid, b]]:
				var p0: Vector3 = seg[0]
				var p1: Vector3 = seg[1]
				var p := p0.lerp(p1, f)
				var d := (p1 - p0).normalized()
				VehicleFrames.beam(k, turret, p - d * 0.004, p + d * 0.004, cw * 1.12, ct * 1.25, "gunmetal_w", null, false)
	if magazines.x > 0.0 and magazines.y > 0.0 and magazines.z > 0.0:
		var gap := arm + 0.028
		var feed_z := tz - arm_d * 0.5 - magazines.z * 0.15 - 0.01
		for s: float in [-1.0, 1.0]:
			var mc := Vector3(cradle.x + s * (cs.x * 0.5 + gap + magazines.x * 0.5), cradle.y + (magazines.y - cs.y) * 0.33, drum.z)
			k._add(turret, BevelMesh.make(magazines, minf(0.012, minf(magazines.x, magazines.y) * 0.08)), mat, col, mc)
			k._box(turret, Vector3(magazines.x + 0.004, 0.006, magazines.z + 0.004), mc + Vector3(0, magazines.y * 0.32, 0), "plain_dark", null, Vector3.ZERO, false)
			# the lid's two latches on the front face
			for x: float in [-0.25, 0.25]:
				k._box(turret, Vector3(0.03, 0.05, 0.012), mc + Vector3(x * magazines.x, magazines.y * 0.25, -magazines.z * 0.5 - 0.006), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(turret, Vector3(gap + 0.01, magazines.y * 0.35, magazines.z * 0.3), Vector3(cradle.x + s * (cs.x * 0.5 + gap * 0.5), cradle.y + cs.y * 0.2, feed_z), "metal_dark")
