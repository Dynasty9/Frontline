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
			VehicleEquipment._rod(k, k.root, base + rim[j], base + rim[j + 1], 0.009, "canvas_white", col.darkened(0.16), 6, false, 3)
	for side in [0, 6]:
		VehicleEquipment._rod(k, k.root, base + rings[0][side], base + rings[24][side], 0.009, "canvas_white", col.darkened(0.16), 6, false, 3)
	for index in [6, 18]:
		var cross_section: PackedVector3Array = rings[index]
		for j in 6:
			VehicleEquipment._rod(k, k.root, base + cross_section[j] + Vector3(0, 0.012, 0), base + cross_section[j + 1] + Vector3(0, 0.012, 0), 0.012, "webbing", Color(0.18, 0.19, 0.13), 6, false, 3)


## A sewn cloth panel in local XY. Edges stay on the frame while the centre
## hangs slightly between its supports; hems use the same outline as the cloth.
## `hems` picks the hemmed edges, one bit each: 1 the -Y edge, 2 the +X, 4 the
## +Y and 8 the -X (all four by default); panels sewn edge to edge share one.
static func panel(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, col: Color, material := "canvas_white", hems := 15) -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var mesh := _panel_mesh(size)
	k._add(mount, mesh, material, col, Vector3.ZERO)
	var corners := [Vector3(-size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, size.y / 2, 0), Vector3(-size.x / 2, size.y / 2, 0)]
	for i in 4:
		if (hems & (1 << i)) != 0:
			VehicleEquipment._rod(k, mount, corners[i], corners[(i + 1) % 4], 0.009, material, col.darkened(0.16), 6, false, 3)
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
## support positions along Z; each bay gets fitted cloth and sewn edges. A seam
## between two bays or two panels of the section is one hem, sewn once.
## `closed_back` closes the rear as the front is closed (a back flap laced
## down, following the section) instead of leaving it to the caller.
static func canopy(k: VehicleModels, parent: Node3D, profile: Array, bows: Array, col: Color, closed_back := false) -> void:
	var ends: Array[float] = [float(bows[0])]
	if closed_back:
		ends.append(float(bows[bows.size() - 1]) - 0.012)
	for z: float in ends:
		var front := PackedVector3Array()
		var back := PackedVector3Array()
		for point: Vector2 in profile:
			front.append(Vector3(point.x, point.y, z))
			back.append(Vector3(point.x, point.y, z + 0.012))
		k._add(parent, VehicleModels.solid([front, back], "cloth_front_%s_%s" % [str(profile), str(z)]), "canvas_white", col, Vector3.ZERO)
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
			# Each panel hems its rear and upper edges; the first bay also its
			# front, and the first panel of the section its lower one.
			var hems := 2 | 4 | (8 if bay == 0 else 0) | (1 if i == 0 else 0)
			panel(k, parent, Vector3((a.x + b.x) / 2, (a.y + b.y) / 2, (z0 + z1) / 2), Vector2(z1 - z0, across.length()), basis.get_euler(), col, "canvas_white", hems)


## Padded stowage uses a softened shell, stitched welt and a retaining strap.
## Thin canvas panels still go through the ordinary panel/canopy builders.
static func bag(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, material: String, col = null, rotation := Vector3.ZERO, shadow := true) -> Variant:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var key := "cloth_bag_%s" % str(size)
	if not _bags.has(size):
		_bags[size] = VehicleBody.skin(BevelMesh.make(size, minf(size.x, minf(size.y, size.z)) * 0.20), key, 80.0)
	var part: Variant = k._add(mount, _bags[size], material, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, shadow)
	var seam_col: Color = col.darkened(0.18) if col is Color else Color(0.23, 0.24, 0.17)
	var inset := minf(size.y, minf(size.x, size.z)) * 0.20
	var outline := [Vector3(-size.x / 2 + inset, 0, -size.z / 2), Vector3(size.x / 2 - inset, 0, -size.z / 2), Vector3(size.x / 2, 0, -size.z / 2 + inset), Vector3(size.x / 2, 0, size.z / 2 - inset), Vector3(size.x / 2 - inset, 0, size.z / 2), Vector3(-size.x / 2 + inset, 0, size.z / 2), Vector3(-size.x / 2, 0, size.z / 2 - inset), Vector3(-size.x / 2, 0, -size.z / 2 + inset)]
	# The welt runs round the bag in eight lengths, each ending in the next.
	for i in outline.size():
		VehicleEquipment._rod(k, mount, outline[i], outline[(i + 1) % outline.size()], 0.006, material, seam_col, 5, false, 0)
	# The narrow strap follows the softened corners and never registers a pivot.
	# Webbing and buckle are thin: plain bands, laid level as a level beam lies.
	var strap := [Vector3(0, -size.y / 2 + inset, -size.z / 2 - 0.008), Vector3(0, size.y / 2 - inset, -size.z / 2 - 0.008), Vector3(0, size.y / 2 + 0.008, -size.z / 2 + inset), Vector3(0, size.y / 2 + 0.008, size.z / 2 - inset), Vector3(0, size.y / 2 - inset, size.z / 2 + 0.008)]
	for i in strap.size() - 1:
		var a: Vector3 = strap[i]
		var b: Vector3 = strap[i + 1]
		var y := (b - a).normalized()
		var z := (Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).cross(y).normalized()
		k._add(mount, VehicleEquipment._plate(Vector3(minf(0.045, size.x * 0.15), a.distance_to(b), 0.012)), "webbing", seam_col, (a + b) * 0.5, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)
	k._add(mount, VehicleEquipment._plate(Vector3(0.065, 0.018, 0.055)), "gunmetal", Color(0.22, 0.23, 0.21), Vector3(0, size.y / 2 + 0.018, 0), Vector3.ZERO, Vector3.ONE, false)
	k._fold(mount)
	return part


static var _bags := {}


## Rolled tarpaulin or bedroll: the old cylinder's centre, radius, length and
## rotation (the roll's axis is the cylinder's local Y). Softened rolled ends
## showing the wound layers, and two webbing straps with buckles.
static func roll(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, rotation: Vector3, col: Color, material := "canvas") -> void:
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var end := minf(0.03, length * 0.04)
	# The body ends in its softened ends, and those show only their outer faces.
	VehicleEquipment._cyl(k, mount, radius, radius, length - end * 2, Vector3.ZERO, Vector3.ZERO, material, col, 12, true, 0)
	for side: float in [-1.0, 1.0]:
		var y := side * (length * 0.5 - end * 0.5)
		VehicleEquipment._cyl(k, mount, radius * (0.88 if side > 0 else 1.0), radius * (1.0 if side > 0 else 0.88), end, Vector3(0, y, 0), Vector3.ZERO, material, col, 12, true, 2 if side > 0 else 1)
		# The wound layers on the end face read as a darker inner spiral.
		k._add(mount, VehicleFittings._ring(radius * 0.36, radius * 0.5), material, col.darkened(0.22), Vector3(0, side * length * 0.5, 0), Vector3.ZERO, Vector3(1, 0.12, 1), false)
	var strap_col := col.darkened(0.35)
	for f: float in [-0.3, 0.3]:
		VehicleEquipment._cyl(k, mount, radius * 1.035, radius * 1.035, minf(0.04, length * 0.05), Vector3(0, f * length, 0), Vector3.ZERO, "webbing", strap_col, 12, false, 0)
		k._box(mount, Vector3(0.014, minf(0.05, length * 0.06), 0.04), Vector3(radius * 1.04, f * length, 0), "gunmetal", Color(0.22, 0.23, 0.21), Vector3.ZERO, false)
	k._fold(mount)
