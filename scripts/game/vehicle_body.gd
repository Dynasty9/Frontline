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


static func seam(k: VehicleModels, parent: Node3D, points: Array, radius := 0.006) -> void:
	for i in points.size() - 1:
		VehicleFrames.tube(k, parent, points[i], points[i + 1], radius, "paint", Color(0.10, 0.11, 0.10), 5, false)


static func fastener(k: VehicleModels, parent: Node3D, position: Vector3, normal: Vector3, radius := 0.012) -> void:
	k._cyl(parent, radius, radius, 0.006, position, VehicleFrames.aim(normal).get_euler(), "steel", Color(0.28, 0.29, 0.27), 8, false)


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
	boundary(k, parent, surface, outline, thickness * 0.35, minf(thickness * 0.3, 0.006), false, divisions, "rubber")
	if finish not in ["rubber", "plastic", "wood", "canvas"]:
		boundary(k, parent, surface, outline, thickness, minf(thickness * 0.22, 0.004), screws, divisions, mat, col)
	return part


## Place seams and corner fasteners from the same boundary as the panel.
## Subdivision is explicit so tiny straight panels never inherit hull costs.
static func boundary(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, lift := 0.01, radius := 0.005, screws := false, divisions := 0, mat := "rubber", col = null) -> void:
	var center := Vector2.ZERO
	for q in outline:
		center += q
	center /= outline.size()
	var data := [[], [], []]
	var count := 1 << clampi(divisions, 0, 3)
	# Four-sided seal sections need no cylinder caps or hidden axial rings.
	# Join them in one baked mesh, sampling each surface point just once.
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in outline.size():
		for j in count:
			var uv := outline[i].lerp(outline[(i + 1) % outline.size()], float(j) / count)
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
			var a: Vector3 = rings[i][side]
			var b: Vector3 = rings[next][side]
			var c: Vector3 = rings[next][(side + 1) % 4]
			var d: Vector3 = rings[i][(side + 1) % 4]
			var normal := (a + b + c + d - (points[i] + points[next]) * 2.0).normalized()
			VehicleSurface._quad(data, a, b, c, d, normal)
	k._add(parent, VehicleSurface._mesh(data), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	if screws:
		for a in outline:
			var distance := surface.point(a).distance_to(surface.point(center))
			var uv := a.lerp(center, minf(0.2, 0.035 / maxf(distance, 0.001)))
			fastener(k, parent, surface.point(uv, lift + 0.002), surface.normal(uv), minf(0.009, distance * 0.06))
