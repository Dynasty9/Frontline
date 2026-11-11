class_name VehicleCloth
extends RefCounted

## A cloth shell with a sloping crown and gathered side folds. The displacement
## is deterministic and stays in model space; straps remain separate geometry.
static func load_cover(k: VehicleModels, base: Vector3, size: Vector3, col := Color(0.30, 0.32, 0.23), pallet := true) -> void:
	if pallet:
		k._box(k.root, Vector3(size.x - 0.06, 0.12, size.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
	var rings: Array[PackedVector3Array] = []
	for i in 25:
		var z := (float(i) / 24.0 - 0.5) * (size.z - 0.08)
		var ripple := sin(float(i) * 0.45) * 0.014 + sin(float(i) * 0.9) * 0.004
		var w := size.x * 0.5 - 0.05
		var h := size.y
		rings.append(PackedVector3Array([Vector3(-w, 0.14, z), Vector3(-w + ripple, h * 0.72, z), Vector3(-w * 0.75, h - 0.035 + ripple, z), Vector3(0, h + ripple * 0.35, z), Vector3(w * 0.75, h - 0.035 - ripple, z), Vector3(w - ripple, h * 0.72, z), Vector3(w, 0.14, z)]))
	var shell := VehicleModels.solid(rings, "shared_tarp_%s" % str(size))
	var arrays := shell.surface_get_arrays(0)
	var smooth := SurfaceTool.new()
	smooth.begin(Mesh.PRIMITIVE_TRIANGLES)
	smooth.set_smooth_group(0)
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		smooth.add_vertex(vertex)
	smooth.index()
	smooth.generate_normals()
	k._add(k.root, smooth.commit(), "canvas_white", col, base)
	for index in [0, 24]:
		var rim: PackedVector3Array = rings[index]
		for j in 6:
			VehicleFrames.tube(k, k.root, base + rim[j], base + rim[j + 1], 0.009, "canvas_white", col.darkened(0.16), 6, false)
	for side in [0, 6]:
		VehicleFrames.tube(k, k.root, base + rings[0][side], base + rings[24][side], 0.009, "canvas_white", col.darkened(0.16), 6, false)
	for index in [6, 18]:
		var cross_section: PackedVector3Array = rings[index]
		for j in 6:
			VehicleFrames.tube(k, k.root, base + cross_section[j] + Vector3(0, 0.012, 0), base + cross_section[j + 1] + Vector3(0, 0.012, 0), 0.012, "webbing", Color(0.18, 0.19, 0.13), 6, false)


## A sewn cloth panel in local XY. Edges stay on the frame while the centre
## hangs slightly between its supports; hems use the same outline as the cloth.
static func panel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, col: Color, material := "canvas_white") -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var mesh := _panel_mesh(size)
	k._add(mount, mesh, material, col, Vector3.ZERO)
	var corners := [Vector3(-size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, size.y / 2, 0), Vector3(-size.x / 2, size.y / 2, 0)]
	for i in 4:
		VehicleFrames.tube(k, mount, corners[i], corners[(i + 1) % 4], 0.009, material, col.darkened(0.16), 6, false)
	k._fold(mount)


static var _panels := {}

static func _panel_mesh(size: Vector2) -> ArrayMesh:
	if _panels.has(size):
		return _panels[size]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var nx := maxi(4, ceili(size.x / 0.12))
	var ny := maxi(4, ceili(size.y / 0.12))
	for y in ny:
		for x in nx:
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var uv := Vector2(float(x + offset.x) / nx, float(y + offset.y) / ny)
				var edge := sin(uv.x * PI) * sin(uv.y * PI)
				var depth := edge * (-0.025 + sin(uv.x * size.x * 25.0 + uv.y * 3.0) * 0.012)
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y, depth))
	surface.generate_normals()
	var mesh := surface.commit()
	_panels[size] = mesh
	return mesh


## Profile runs from the left hem over the crown to the right hem. Bows are
## support positions along Z; each bay gets fitted cloth and sewn edges.
static func canopy(k: VehicleModels, parent: Node3D, profile: Array, bows: Array, col: Color) -> void:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for point: Vector2 in profile:
		front.append(Vector3(point.x, point.y, float(bows[0])))
		back.append(Vector3(point.x, point.y, float(bows[0]) + 0.012))
	k._add(parent, VehicleModels.solid([front, back], "cloth_front_%s_%s" % [str(profile), str(bows[0])]), "canvas_white", col, Vector3.ZERO)
	for bay in bows.size() - 1:
		var z0: float = bows[bay]
		var z1: float = bows[bay + 1]
		for i in profile.size() - 1:
			var a: Vector2 = profile[i]
			var b: Vector2 = profile[i + 1]
			var across := Vector3(b.x - a.x, b.y - a.y, 0)
			var y_axis := across.normalized()
			var x_axis := Vector3.BACK
			var normal := x_axis.cross(y_axis)
			var basis := Basis(x_axis, y_axis, normal)
			panel(k, parent, Vector3((a.x + b.x) / 2, (a.y + b.y) / 2, (z0 + z1) / 2), Vector2(z1 - z0, across.length()), basis.get_euler(), col)
