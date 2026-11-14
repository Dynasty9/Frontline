class_name VehicleBody
extends RefCounted
## Shared body skins and service fittings. Family builders still own outlines.
static var _skins := {}

## Smooth neighbouring faces of a curved skin, retaining sharp creases and caps.
## Positions are unchanged, so fitted windows and authored panels still meet it.
static func skin(mesh: ArrayMesh, key: String, crease := 55.0) -> ArrayMesh:
	if _skins.has(key):
		return _skins[key]
	var arrays := Mats._arrays(mesh, 0).duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var groups := {}
	for i in vertices.size():
		var point := Vector3i((vertices[i] * 100000.0).round())
		if not groups.has(point):
			groups[point] = []
		(groups[point] as Array).append(i)
	var softened := normals.duplicate()
	var threshold := cos(deg_to_rad(crease))
	for indices: Array in groups.values():
		for i: int in indices:
			var total := Vector3.ZERO
			for j: int in indices:
				if normals[i].dot(normals[j]) >= threshold:
					total += normals[j]
			softened[i] = total.normalized() if not total.is_zero_approx() else normals[i]
	arrays[Mesh.ARRAY_NORMAL] = softened
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(result, arrays)
	_skins[key] = result
	return result


## A dark seam bead along `points` (see bead).
static func seam(k: VehicleModels, parent: Node3D, points: Array, radius := 0.006) -> void:
	bead(k, parent, points, radius, "paint", Color(0.10, 0.11, 0.10), 5, false)


## A round bead, hose or bar along `points` (a closed loop repeats its first
## point last), a rod of `segments` sides a span. Each span runs on into the
## next by as much as a gentle bend opens on its outside, so its joints need
## no caps; free ends are capped, and a corner sharper than 30 degrees is
## capped (each span as it ends) or, with `balls`, filled with a ball as
## VehicleFrames.path fills every joint. A seam's or a hose's curve, then,
## costs its rods and nothing at its joints.
static func bead(k: VehicleModels, parent: Node3D, points: Array, radius: float, mat: String, col = null, segments := 6, shadow := true, balls := false) -> void:
	var n := points.size()
	if n < 2:
		return
	var closed := n > 2 and (points[0] as Vector3).is_equal_approx(points[n - 1])
	var runs: Array[Vector3] = []
	for i in n - 1:
		var d: Vector3 = points[i + 1] - points[i]
		runs.append(d.normalized() if d.length_squared() > 1e-12 else Vector3.ZERO)
	for i in n - 1:
		var d := runs[i]
		if d.is_zero_approx():
			continue
		# the runs before and after this span (-1: a free end) and its bends
		var before := i - 1 if i > 0 else (n - 2 if closed else -1)
		var after := i + 1 if i < n - 2 else (0 if closed else -1)
		var a_bend := _bend(runs, before, i)
		var b_bend := _bend(runs, i, after)
		if balls and a_bend > -1.5 and a_bend < 0.866:
			k._add(parent, Res.sphere(radius, segments), mat, col, points[i])
		var a_run := radius * sqrt((1.0 - a_bend) / (1.0 + a_bend)) if a_bend >= 0.866 else 0.0
		var b_run := radius * sqrt((1.0 - b_bend) / (1.0 + b_bend)) if b_bend >= 0.866 else 0.0
		var a_cap := a_bend < -1.5 or (a_bend < 0.866 and not balls)
		var b_cap := b_bend < -1.5 or (b_bend < 0.866 and not balls)
		rod(k, parent, points[i] - d * a_run, points[i + 1] + d * b_run, radius, mat, col, segments, shadow, -1.0, a_cap, b_cap)


## The cosine of the bend from run `from` into run `to`, or -2 where there is
## no joint (a free end, or a span of no length).
static func _bend(runs: Array[Vector3], from: int, to: int) -> float:
	if from < 0 or to < 0 or runs[from].is_zero_approx() or runs[to].is_zero_approx():
		return -2.0
	return clampf(runs[from].dot(runs[to]), -1.0, 1.0)


static var _drums := {}
static var _heads := {}

## A round section on local Y, centred, as Res.cyl lays one, but with a single
## band of sides (a CylinderMesh's ring only splits a straight side in two)
## and only the ends that show: an end inside a boss, a hull or the next
## section needs no cap. The same shape and shading for half the sides.
## Cached by size.
static func drum(top: float, bottom: float, height: float, segments := 8, top_cap := true, bottom_cap := true) -> CylinderMesh:
	var key := "%.4f,%.4f,%.4f,%d,%d,%d" % [top, bottom, height, segments, int(top_cap), int(bottom_cap)]
	if _drums.has(key):
		return _drums[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	m.cap_top = top_cap
	m.cap_bottom = bottom_cap
	_drums[key] = m
	return m


## A drum placed as k._cyl places a cylinder (top radius first).
static func cylinder(k: VehicleModels, parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, rot: Vector3, mat: String, col = null, segments := 8, shadow := true, top_cap := true, bottom_cap := true) -> Variant:
	return k._add(parent, drum(top, bottom, height, segments, top_cap, bottom_cap), mat, col, pos, rot, Vector3.ONE, shadow)


## A drum from a to b, as VehicleFrames.tube runs one (`end_radius` at b);
## `a_cap` and `b_cap` close its two ends.
static func rod(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: String, col = null, segments := 8, shadow := true, end_radius := -1.0, a_cap := true, b_cap := true) -> Variant:
	if a.distance_squared_to(b) < 0.00000001:
		return null
	return cylinder(k, parent, end_radius if end_radius >= 0 else radius, radius, a.distance_to(b), (a + b) * 0.5, VehicleFrames.aim(b - a).get_euler(), mat, col, segments, shadow, b_cap, a_cap)


## A bolt head: half of its 6 mm driven into the face, half standing proud.
static func fastener(k: VehicleModels, parent: Node3D, position: Vector3, normal: Vector3, radius := 0.012) -> void:
	k._add(parent, _head(radius), "steel", Color(0.28, 0.29, 0.27), position, VehicleFrames.aim(normal).get_euler(), Vector3.ONE, false)


## A bolt head's mesh. The roster carries thousands of them, so it has no
## underside (that half is in the face) and its top is a flat fan without a
## centre point; six smooth sides still read round at bolt sizes, eight on
## the few heads over 3 cm across. Cached by radius.
static func _head(radius: float) -> ArrayMesh:
	var r := snappedf(radius, 0.0001)
	if _heads.has(r):
		return _heads[r]
	var sides := 6 if r < 0.015 else 8
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var top := Vector3(0, 0.003, 0)
	var foot := Vector3(0, -0.003, 0)
	var rim: Array[Vector3] = []
	for i in sides:
		var a := TAU * float(i) / float(sides)
		rim.append(Vector3(sin(a), 0, cos(a)))
	for i in sides:
		var d0 := rim[i]
		var d1 := rim[(i + 1) % sides]
		var f := (d0 + d1).normalized()
		VehicleProfiles._tri(vs, ns, d0 * r + top, d1 * r + top, d1 * r + foot, d0, d1, d1, f)
		VehicleProfiles._tri(vs, ns, d0 * r + top, d1 * r + foot, d0 * r + foot, d0, d1, d0, f)
	for i in range(1, sides - 1):
		VehicleProfiles._tri(vs, ns, rim[0] * r + top, rim[i] * r + top, rim[i + 1] * r + top, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	_heads[r] = mesh
	return mesh


## Local XY panel, +Z outward. Gasket, pressed sheet, flush screws and optional
## louvres share construction; callers choose the actual panel location.
static func panel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, mat: String, col = null, louvres := false) -> void:
	var finish := VehicleMaterials.profile(mat, k.surface_family)
	if finish == "canvas":
		VehicleCloth.panel(k, parent, center, size, rotation, col if col is Color else Color(0.40, 0.42, 0.30), mat)
		return
	if finish == "glass":
		VehicleGlazing.rectangle(k, parent, size, center, rotation, false, col)
		return
	var mount := k._pivot(parent, center)
	if finish in ["rubber", "plastic", "wood"]:
		mount.rotation = rotation
		k._add(mount, BevelMesh.make(Vector3(size.x, size.y, 0.025), 0.008), mat, col, Vector3.ZERO)
		k._fold(mount)
		return
	mount.rotation = rotation
	var surface := VehicleSurface.plane(Vector3.ZERO, Vector3.RIGHT, Vector3.UP)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var corner := minf(0.035, minf(hx, hy) * 0.15)
	var outline := PackedVector2Array([Vector2(-hx + corner, -hy), Vector2(hx - corner, -hy), Vector2(hx, -hy + corner), Vector2(hx, hy - corner), Vector2(hx - corner, hy), Vector2(-hx + corner, hy), Vector2(-hx, hy - corner), Vector2(-hx, -hy + corner)])
	fitted(k, mount, surface, outline, mat, col)
	if louvres:
		for i in 4:
			var y := (i - 1.5) * size.y * 0.16
			k._box(mount, Vector3(size.x * 0.68, size.y * 0.055, 0.012), Vector3(0, y, 0.022), "rubber", null, Vector3.ZERO, false)
			k._box(mount, Vector3(size.x * 0.71, size.y * 0.045, 0.025), Vector3(0, y + size.y * 0.025, 0.032), mat, col, Vector3(-0.25, 0, 0))
	else:
		k._box(mount, Vector3(size.x * 0.72, size.y * 0.50, 0.012), Vector3(0, 0, 0.02), mat, col)
	k._fold(mount)


## Coordinates of each flat body piece, retained through the material bake.
## Curved faces have no artificial bounding-box edge; their authored seams remain.
static func paint_mesh(mesh: Mesh) -> Mesh:
	if mesh.has_meta(&"paint_mesh"):
		return mesh.get_meta(&"paint_mesh")
	if mesh.get_surface_count() != 1:
		return mesh
	var flat := Mats._flat(mesh, 0)
	var vertices: PackedVector3Array = flat[0]
	var normals: PackedVector3Array = flat[1]
	var uv := PackedVector2Array()
	uv.resize(vertices.size())
	uv.fill(Vector2(0.5, 0.5))
	var bounds := mesh.get_aabb()
	for start in range(0, vertices.size(), 3):
		var normal := normals[start].normalized()
		if normal.dot(normals[start + 1].normalized()) < 0.999 or normal.dot(normals[start + 2].normalized()) < 0.999:
			continue
		var axis := normal.abs().max_axis_index()
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		if minf(bounds.size[a], bounds.size[b]) < 0.08:
			continue
		for i in range(start, start + 3):
			var q := vertices[i] - bounds.position
			uv[i] = Vector2(q[a] / bounds.size[a], q[b] / bounds.size[b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	if flat[2] != null:
		arrays[Mesh.ARRAY_COLOR] = flat[2]
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(result, arrays)
	mesh.set_meta(&"paint_mesh", result)
	return result


## Polygon panels share one outline for skin, edge fold, gasket and fasteners.
## Domain coordinates may be metres (flat sheet) or a family's surface domain.
static func fitted(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, mat: String, col = null, thickness := 0.018, divisions := 0, screws := true) -> Variant:
	var finish := VehicleMaterials.profile(mat, k.surface_family)
	if finish == "glass":
		return VehicleGlazing.polygon(k, parent, surface, outline, false, col, thickness, divisions)
	var part: Variant = k._add(parent, surface.patch(outline, thickness, thickness, divisions), mat, col, Vector3.ZERO)
	# The gasket is half sunk in the sheet's edge: only its outer faces show.
	# The folded edge sits on the sheet's top corner, so only its lower inner
	# face is buried.
	_seal(k, parent, surface, outline, thickness * 0.35, minf(thickness * 0.3, 0.006), divisions, "rubber", null, SEAL_UPPER_OUT | SEAL_LOWER_OUT)
	if finish not in ["rubber", "plastic", "wood", "canvas"]:
		_seal(k, parent, surface, outline, thickness, minf(thickness * 0.22, 0.004), divisions, mat, col, SEAL_ALL & ~SEAL_LOWER_IN)
		if screws:
			_screws(k, parent, surface, outline, thickness)
	return part


## A seal's four faces (its cross-section is a diamond on the outline): the
## upper and lower faces on the outline's outer side, the lower and upper on
## its inner side.
const SEAL_UPPER_OUT := 1
const SEAL_LOWER_OUT := 2
const SEAL_LOWER_IN := 4
const SEAL_UPPER_IN := 8
const SEAL_ALL := 15

## Place seams and corner fasteners from the same boundary as the panel.
## Subdivision is explicit so tiny straight panels never inherit hull costs.
static func boundary(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, lift := 0.01, radius := 0.005, screws := false, divisions := 0, mat := "rubber", col = null) -> void:
	_seal(k, parent, surface, outline, lift, radius, divisions, mat, col, SEAL_ALL)
	if screws:
		_screws(k, parent, surface, outline, lift)


## The seal of `boundary` with only the faces in `faces` (SEAL_*): a seal
## half buried in the panel it edges needs none of the faces inside it.
static func _seal(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, lift: float, radius: float, divisions: int, mat: String, col, faces: int) -> void:
	var center := Vector2.ZERO
	for q in outline:
		center += q
	center /= outline.size()
	# Each side of the section by the face it is: `across` (the tangent crossed
	# with the normal) points out of the outline when the outline runs the same
	# way round as the surface's own axes.
	var sides: Array[int] = [SEAL_UPPER_OUT, SEAL_LOWER_OUT, SEAL_LOWER_IN, SEAL_UPPER_IN]
	if faces != SEAL_ALL:
		var area := 0.0
		for i in outline.size():
			var p := outline[i]
			var q := outline[(i + 1) % outline.size()]
			area += p.x * q.y - q.x * p.y
		var du: Vector3 = surface.sample.call(center + Vector2(0.0001, 0)) - surface.sample.call(center - Vector2(0.0001, 0))
		var dv: Vector3 = surface.sample.call(center + Vector2(0, 0.0001)) - surface.sample.call(center - Vector2(0, 0.0001))
		var hand := du.cross(dv).dot(surface.normal(center))
		if absf(area) < 1e-12 or absf(hand) < 1e-16:
			faces = SEAL_ALL
		elif (area > 0.0) != (hand > 0.0):
			sides = [SEAL_UPPER_IN, SEAL_LOWER_IN, SEAL_LOWER_OUT, SEAL_UPPER_OUT]
	var data := [[], [], []]
	var count := 1 << clampi(divisions, 0, 3)
	# Four-sided seal sections need no cylinder caps or hidden axial rings.
	# Join them in one baked mesh, sampling each surface point just once.
	# Subdivision follows a curved skin. Along an edge that runs straight
	# across it with the skin's normal unchanged (a flat pane's edges, a
	# cylinder's along its axis) every section between the two next to the
	# corners is the same prism, so it is built as one.
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in outline.size():
		var q0 := outline[i]
		var q1 := outline[(i + 1) % outline.size()]
		var stations: Array[float] = []
		for j in count:
			stations.append(float(j) / count)
		if count > 2:
			var p0 := surface.point(q0)
			var chord := surface.point(q1) - p0
			var n0 := surface.normal(q0)
			var straight := chord.length_squared() > 1e-10 and surface.normal(q1).dot(n0) > 0.99999
			for j in range(1, count):
				if not straight:
					break
				var q := q0.lerp(q1, float(j) / count)
				var off := surface.point(q) - p0
				straight = (off - chord * clampf(off.dot(chord) / chord.length_squared(), 0.0, 1.0)).length() < 0.0001 and surface.normal(q).dot(n0) > 0.99999
			if straight:
				stations = [0.0, 1.0 / count, float(count - 1) / count]
		for f in stations:
			var uv := q0.lerp(q1, f)
			points.append(surface.point(uv, lift))
			normals.append(surface.normal(uv))
	var rings: Array = []
	for i in points.size():
		var tangent := (points[(i + 1) % points.size()] - points[(i - 1 + points.size()) % points.size()]).normalized()
		var across := tangent.cross(normals[i]).normalized() * radius
		var up := normals[i] * radius
		rings.append([points[i] + up, points[i] + across, points[i] - up, points[i] - across])
	for i in points.size():
		var next := (i + 1) % points.size()
		for side in 4:
			if faces & sides[side] == 0:
				continue
			var a: Vector3 = rings[i][side]
			var b: Vector3 = rings[next][side]
			var c: Vector3 = rings[next][(side + 1) % 4]
			var d: Vector3 = rings[i][(side + 1) % 4]
			var normal := (a + b + c + d - (points[i] + points[next]) * 2.0).normalized()
			VehicleSurface._quad(data, a, b, c, d, normal)
	k._add(parent, VehicleSurface._mesh(data), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## A screw in from each corner of the outline, `lift` off the surface.
static func _screws(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, lift: float) -> void:
	var center := Vector2.ZERO
	for q in outline:
		center += q
	center /= outline.size()
	for a in outline:
		var distance := surface.point(a).distance_to(surface.point(center))
		var uv := a.lerp(center, minf(0.2, 0.035 / maxf(distance, 0.001)))
		fastener(k, parent, surface.point(uv, lift + 0.002), surface.normal(uv), minf(0.009, distance * 0.06))


## Flat fender sheet over a wheel: the old plate's centre, size and rotation,
## `side` the vehicle side its outer edge faces (+X or -X). A rolled bead
## stiffens the outer edge, bolts hold the inner edge and two stays brace it
## from below. A raked lip is another call with its own rotation; `valance`
## drops a skirt of that height from the outer edge.
static func fender(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, rotation := Vector3.ZERO, valance := 0.0) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var s := 1.0 if side >= 0.0 else -1.0
	k._add(mount, BevelMesh.make(size, minf(size.y * 0.35, 0.012)), mat, col, Vector3.ZERO)
	var edge := Vector3(s * size.x * 0.5, 0, 0)
	VehicleBody.rod(k, mount, edge + Vector3(0, 0, -size.z * 0.5), edge + Vector3(0, 0, size.z * 0.5), size.y * 0.55, mat, col, 6, false)
	if valance > 0.0:
		k._box(mount, Vector3(size.y * 0.8, valance, size.z), edge + Vector3(0, -valance * 0.5, 0), mat, col)
	var rubber := VehicleMaterials.profile(mat, k.surface_family) == "rubber"
	var bolts := clampi(roundi(size.z / 0.3), 2, 8)
	for i in bolts:
		var z := lerpf(-size.z * 0.4, size.z * 0.4, (i + 0.5) / bolts if bolts > 1 else 0.5)
		VehicleBody.fastener(k, mount, Vector3(-s * size.x * 0.4, size.y * 0.5 + 0.002, z), Vector3.UP, 0.011)
	# Stays run inboard from the inner edge to the hull, never down over the
	# tyre crown, so a guard sitting close above its wheel stays clear of it.
	if not rubber and size.z > 0.5:
		for z: float in [-size.z * 0.42, size.z * 0.42]:
			var top := Vector3(-s * size.x * 0.46, -size.y * 0.5, z)
			VehicleFrames.beam(k, mount, top, top + Vector3(-s * 0.1, -0.05, 0), 0.03, 0.012, "metal_dark")
	k._fold(mount)


## Track guard: the long sheet-steel shelf over a tank's track, the old
## shelf's centre and size (x across, y its thickness, z its length along the
## hull), `side` the vehicle side its outer edge faces (+X or -X). A real one
## is several pressed sections butt-strapped together, bolted along its inner
## edge to an angle flange on the hull side and held up by gussets welded under
## it; its outer edge is rolled into a bead, and `valance` > 0 drops a lip that
## tall from it. `brackets` gussets are spread along the inner edge, reaching
## 0.6 of the width out and at most 12 cm down. `front` and `rear` are the
## raked mudguards hinged on its ends: (run along Z, drop below the shelf's
## centre) of the guard's far edge from the shelf's end edge, so the old end
## plate converts as its far edge minus the shelf's end (zero: none; `front`
## is the -Z end). `flange` false leaves the inner edge flush, as a lip lying
## on a sponson needs. Everything stays inside the sheet's own box but for the
## bead (0.55 of the thickness out), the flange (4 cm up at the inner edge) and
## what valance, brackets and mudguards add below and beyond the ends.
static func track_guard(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side: float, mat: String, col = null, brackets := 0, valance := 0.0, front := Vector2.ZERO, rear := Vector2.ZERO, flange := true) -> void:
	var mount := k._pivot(parent, center)
	var s := 1.0 if side >= 0.0 else -1.0
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var bevel := minf(size.y * 0.35, 0.012)
	k._add(mount, BevelMesh.make(size, bevel), mat, col, Vector3.ZERO)
	var bead := size.y * 0.55
	VehicleBody.rod(k, mount, Vector3(s * hx, 0, -hz), Vector3(s * hx, 0, hz), bead, mat, col, 6, false)
	if valance > 0.0:
		k._box(mount, Vector3(size.y * 0.8, valance, size.z), Vector3(s * hx, -valance * 0.5, 0), mat, col)
	# Butt straps across the top where the pressed sections meet.
	var sections := clampi(roundi(size.z / 1.5), 1, 6)
	for i in range(1, sections):
		var z := -hz + size.z * i / float(sections)
		k._box(mount, Vector3(size.x * 0.9, 0.006, minf(0.06, size.z * 0.1)), Vector3(0, hy + 0.003, z), mat, col, Vector3.ZERO, false)
		for x: float in [-hx * 0.6, hx * 0.55]:
			fastener(k, mount, Vector3(x, hy + 0.006, z), Vector3.UP, 0.009)
	# The angle flange up the hull side, its bolts on the outer face.
	if flange:
		var rise := minf(0.04, size.x * 0.25)
		var t := 0.008
		k._box(mount, Vector3(t, rise, size.z), Vector3(-s * (hx - t * 0.5), hy + rise * 0.5, 0), mat, col, Vector3.ZERO, false)
		var bolts := clampi(roundi(size.z / 0.6), 2, 10)
		for i in bolts:
			var z := lerpf(-hz, hz, (i + 0.5) / bolts)
			fastener(k, mount, Vector3(-s * (hx - t - 0.003), hy + rise * 0.5, z), Vector3(s, 0, 0), minf(0.009, rise * 0.25))
	# Gussets under the inner edge, welded to the hull side, one bolt over each.
	# They stay shallow: the track's top run passes only a few centimetres
	# under the guard when the road wheels ride up to their stops.
	if brackets > 0:
		var reach := size.x * 0.6
		var drop := minf(reach * 0.5, 0.05)
		var fin := _gusset(reach, drop, minf(0.012, size.y * 0.4))
		for i in brackets:
			var z := lerpf(-hz * 0.9, hz * 0.9, (i + 0.5) / brackets)
			k._add(mount, fin, mat, col, Vector3(-s * hx, -hy, z), Vector3(0, 0.0 if s > 0.0 else PI, 0), Vector3.ONE, false)
			fastener(k, mount, Vector3(-s * (hx - minf(0.04, size.x * 0.2)), hy + 0.002, z), Vector3.UP, 0.009)
	# The raked mudguards on their hinges over the idler and the sprocket.
	for end: float in [-1.0, 1.0]:
		var guard: Vector2 = front if end < 0.0 else rear
		if guard.x <= 0.0:
			continue
		var near := Vector3(0, 0, end * hz)
		var far := Vector3(0, -guard.y, end * (hz + guard.x))
		var length := near.distance_to(far)
		var pitch := atan2(guard.y, guard.x) * end
		k._add(mount, BevelMesh.make(Vector3(size.x, size.y, length), bevel), mat, col, (near + far) * 0.5, Vector3(pitch, 0, 0))
		VehicleBody.rod(k, mount, near + Vector3(s * hx, 0, 0), far + Vector3(s * hx, 0, 0), bead, mat, col, 6, false)
		VehicleBody.rod(k, mount, near + Vector3(-hx * 0.8, -hy - bead * 0.6, 0), near + Vector3(hx * 0.8, -hy - bead * 0.6, 0), bead * 1.1, "metal_dark", null, 6, false)
	k._fold(mount)


## A right-angled gusset plate: legs `reach` along +X and `drop` down -Y from
## its corner, `t` thick (cached by size).
static func _gusset(reach: float, drop: float, t: float) -> ArrayMesh:
	var rings := []
	for z: float in [-t * 0.5, t * 0.5]:
		rings.append(PackedVector3Array([Vector3(0, 0, z), Vector3(reach, 0, z), Vector3(0, -drop, z)]))
	return VehicleModels.solid(rings, "body_gusset_%.4f_%.4f_%.4f" % [reach, drop, t])
