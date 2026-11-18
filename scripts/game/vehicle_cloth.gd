class_name VehicleCloth
extends RefCounted

## A cloth shell with a sloping crown and gathered side folds. The displacement
## is deterministic and stays in model space; straps remain separate geometry.
## On a vehicle with a load of its own (VehicleCargo.kit) the tarp is the
## crew's: its own shade of drab (one of four ways it was thrown over, so few
## shells are cached), its folds where it fell and its lashings a ring
## forward or back of where they were.
static func load_cover(k: VehicleModels, base: Vector3, size: Vector3, col := Color(0.30, 0.32, 0.23), pallet := true) -> void:
	var rng := VehicleCargo.kit(k, k.root, base, 3)
	var fold := 0
	var lashings: Array[int] = [6, 18]
	if rng != null:
		fold = rng.randi_range(0, 3)
		lashings = [6 + rng.randi_range(-1, 1), 18 + rng.randi_range(-1, 1)]
		col = VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_TARP, 0.5)
	if pallet:
		k._box(k.root, Vector3(size.x - 0.06, 0.12, size.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
	var rings: Array[PackedVector3Array] = []
	for i in 25:
		var z := (float(i) / 24.0 - 0.5) * (size.z - 0.08)
		var ripple := sin(float(i) * 0.45 + fold * 1.7) * 0.014 + sin(float(i) * 0.9 + fold * 2.3) * 0.004
		var w := size.x * 0.5 - 0.05
		var h := size.y
		rings.append(PackedVector3Array([Vector3(-w, 0.14, z), Vector3(-w + ripple, h * 0.72, z), Vector3(-w * 0.75, h - 0.035 + ripple, z), Vector3(0, h + ripple * 0.35, z), Vector3(w * 0.75, h - 0.035 - ripple, z), Vector3(w - ripple, h * 0.72, z), Vector3(w, 0.14, z)]))
	var shell := VehicleModels.solid(rings, "shared_tarp_%s" % str(size) + ("_%d" % fold if fold > 0 else ""))
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
	for index in lashings:
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
## On a vehicle with a load of its own (VehicleCargo.kit) the place is the
## crew's: one bag filling it, or a duffel and a rucksack side by side along
## its length (three in a long side basket), now and then one of them gone;
## each in its owner's colour, packed full or slumped part empty with its foot
## where it was, a little smaller than the place and turned no further than
## keeps it inside it, its strap where it was pulled. Nothing leaves the
## place's box but the strap and buckle, as before.
static func bag(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, material: String, col = null, rotation := Vector3.ZERO, shadow := true) -> Variant:
	var rng := VehicleCargo.kit(k, parent, center, 1)
	if rng == null:
		var mount := k._pivot(parent, center)
		mount.rotation = rotation
		return _bag(k, mount, size, Vector3.ONE, material, col, shadow)
	var basis := Basis.from_euler(rotation)
	var long_x := size.x >= size.z
	var long := maxf(size.x, size.z)
	var ratio := long / maxf(0.01, minf(size.x, size.z))
	# Cut where a bag of each length ends (few lengths, so few cached shells).
	var cuts: Array[float] = [0.0, 1.0]
	if ratio >= 1.7 and long >= 0.5:
		var pick := rng.randf()
		if ratio >= 3.2 and pick < 0.35:
			cuts = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]
		elif pick < 0.7:
			cuts = [0.0, [0.42, 0.5, 0.58][rng.randi_range(0, 2)], 1.0]
	var count := cuts.size() - 1
	var gone := rng.randi_range(0, count - 1) if count > 1 and rng.randf() < 0.25 else -1
	var first: Variant = null
	for i in count:
		var a := cuts[i] * long + (0.015 if i > 0 else 0.0)
		var b := cuts[i + 1] * long - (0.015 if i < count - 1 else 0.0)
		# (drawn for every piece, so a gone one doesn't change the next's)
		var full := 1.0 - 0.1 * rng.randi_range(0, 2)
		var fill := 1.0 - 0.05 * rng.randi_range(0, 1)
		var turn := rng.randf_range(-1.0, 1.0)
		var strap := rng.randf_range(-0.2, 0.2)
		var tint: Variant = VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_CLOTH, 0.4) if col is Color else col
		var rolled := rng.randf() < 0.22
		var pocket := (1.0 if rng.randf() < 0.5 else -1.0) if rng.randf() < 0.35 else 0.0
		if i == gone:
			continue
		var place := Vector3(b - a, size.y, size.z) if long_x else Vector3(size.x, size.y, b - a)
		var mid := (a + b) * 0.5 - long * 0.5
		var across := minf(size.y, size.z if long_x else size.x)
		if rolled and shadow and col is Color and b - a >= across * 1.6 and absf((basis * Vector3.UP).y) > 0.9:
			# A bedroll or sleeping mat rolled up in the place instead, along
			# its length on its floor, resting on its straps (3.5% proud),
			# its buckles up and a little round.
			var r := across * 0.5 / 1.035 * full
			var lie := Basis(Vector3.BACK, PI / 2) if long_x else Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.UP, PI / 2)
			var roll_mount := k._pivot(parent, center + basis * Vector3(mid if long_x else 0.0, -size.y * 0.5 + r * 1.035, 0.0 if long_x else mid))
			roll_mount.basis = basis * lie * Basis(Vector3.UP, turn * 0.7)
			_roll(k, roll_mount, r, (b - a) * fill, tint, material, Vector2(-0.3, 0.3) + Vector2(strap, strap) * 0.3)
			continue
		var scale := Vector3(fill, full, fill)
		# A pocket sewn on one of the bag's ±X faces (a kit bag's end pocket,
		# a rucksack's side one, where its strap doesn't run): the bag a
		# pocket's depth shorter along X, so the two fill only the place.
		var depth := clampf(place.x * 0.14, 0.045, 0.08) if pocket != 0.0 and place.x >= 0.3 and place.y >= 0.2 and place.z >= 0.2 else 0.0
		var body := place.x - depth
		# Smaller in plan by `fill`, a bag may turn about its middle until its
		# corners (the pocket's on its side) reach the place's sides.
		var reach := minf(body * (1.0 - fill) / (place.z * fill), place.z * (1.0 - fill) / (body * fill + depth * 2.0))
		var spin := Basis(Vector3.UP, turn * asin(clampf(reach, 0.0, 0.2)))
		var foot := Vector3(mid if long_x else 0.0, -size.y * (1.0 - full) * 0.5, 0.0 if long_x else mid)
		foot.x -= pocket * depth * 0.5
		var mount := k._pivot(parent, center + basis * foot)
		mount.basis = basis * spin
		var part: Variant = _bag(k, mount, Vector3(body, place.y, place.z), scale, material, tint, shadow, strap, Vector3(pocket * depth, 0, 0))
		if first == null:
			first = part
	return first


## One bag on its mount, centred on it: its shell cached at `place` and made
## `scale` of it (packed less full, smaller in plan), the welt and strap at
## the bag's own size, the strap `strap` of its width off centre. A nonzero
## `pocket` (along ±X, its length the pocket's depth) sews a pocket on that
## face, within the face's flat middle: half the bag's height, three fifths
## of its width.
static func _bag(k: VehicleModels, mount: Node3D, place: Vector3, scale: Vector3, material: String, col, shadow: bool, strap_at := 0.0, pocket := Vector3.ZERO) -> Variant:
	var size := place * scale
	var part: Variant = k._add(mount, _shell(place), material, col, Vector3.ZERO, Vector3.ZERO, scale, shadow)
	if pocket.x != 0.0:
		var p := Vector3(absf(pocket.x), size.y * 0.5, size.z * 0.6)
		# (into the bag's face 4 mm, so no seam of light shows round it)
		var at := Vector3(signf(pocket.x) * (size.x * 0.5 + p.x * 0.5 - 0.004), -size.y * 0.03, 0)
		k._add(mount, _shell(p.snappedf(0.005)), material, col.darkened(0.06) if col is Color else col, at, Vector3.ZERO, Vector3.ONE, shadow)
	var seam_col: Color = col.darkened(0.18) if col is Color else Color(0.23, 0.24, 0.17)
	var inset := minf(size.y, minf(size.x, size.z)) * 0.20
	var outline := [Vector3(-size.x / 2 + inset, 0, -size.z / 2), Vector3(size.x / 2 - inset, 0, -size.z / 2), Vector3(size.x / 2, 0, -size.z / 2 + inset), Vector3(size.x / 2, 0, size.z / 2 - inset), Vector3(size.x / 2 - inset, 0, size.z / 2), Vector3(-size.x / 2 + inset, 0, size.z / 2), Vector3(-size.x / 2, 0, size.z / 2 - inset), Vector3(-size.x / 2, 0, -size.z / 2 + inset)]
	# The welt runs round the bag in eight lengths, each ending in the next.
	for i in outline.size():
		VehicleEquipment._rod(k, mount, outline[i], outline[(i + 1) % outline.size()], 0.006, material, seam_col, 5, false, 0)
	# The narrow strap follows the softened corners and never registers a pivot.
	# Webbing and buckle are thin: plain bands, laid level as a level beam lies.
	var sx := strap_at * size.x
	var strap := [Vector3(sx, -size.y / 2 + inset, -size.z / 2 - 0.008), Vector3(sx, size.y / 2 - inset, -size.z / 2 - 0.008), Vector3(sx, size.y / 2 + 0.008, -size.z / 2 + inset), Vector3(sx, size.y / 2 + 0.008, size.z / 2 - inset), Vector3(sx, size.y / 2 - inset, size.z / 2 + 0.008)]
	for i in strap.size() - 1:
		var a: Vector3 = strap[i]
		var b: Vector3 = strap[i + 1]
		var y := (b - a).normalized()
		var z := (Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).cross(y).normalized()
		k._add(mount, VehicleEquipment._plate(Vector3(minf(0.045, size.x * 0.15), a.distance_to(b), 0.012)), "webbing", seam_col, (a + b) * 0.5, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)
	k._add(mount, VehicleEquipment._plate(Vector3(0.065, 0.018, 0.055)), "gunmetal", Color(0.22, 0.23, 0.21), Vector3(sx, size.y / 2 + 0.018, 0), Vector3.ZERO, Vector3.ONE, false)
	k._fold(mount)
	return part


## A bag's softened shell that size (cached by size).
static func _shell(size: Vector3) -> ArrayMesh:
	if not _bags.has(size):
		_bags[size] = VehicleBody.skin(BevelMesh.make(size, minf(size.x, minf(size.y, size.z)) * 0.20), "cloth_bag_%s" % str(size), 80.0)
	return _bags[size]


static var _bags := {}


## Rolled tarpaulin or bedroll: the old cylinder's centre, radius, length and
## rotation (the roll's axis is the cylinder's local Y). Softened rolled ends
## showing the wound layers, and two webbing straps with buckles.
## On a vehicle with a load of its own (VehicleCargo.kit) the place is the
## crew's: one roll, or a long one's place shared by two (a bedroll and a
## sleeping mat), each in its own colour, rolled tighter or looser (a thinner
## roll lies in the old one's bottom, so it still rests where the old one did
## and stays inside it), its straps where they were cinched and turned about
## its axis no further than keeps the buckles off what it lies on. A roll of
## the vehicle's own canvas (canvas_white: a tilt's back flap rolled up) or
## longer than kit comes (an awning) stays as the family made it.
static func roll(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, rotation: Vector3, col: Color, material := "canvas") -> void:
	var rng := VehicleCargo.kit(k, parent, center, 2) if material != "canvas_white" and length <= 2.6 else null
	if rng == null:
		var mount := k._pivot(parent, center)
		mount.rotation = rotation
		_roll(k, mount, radius, length, col, material, Vector2(-0.3, 0.3))
		return
	var basis := Basis.from_euler(rotation)
	var axis := basis * Vector3.UP
	# Rolled tighter, a roll lies lower in the old one's bottom: toward the
	# parent's down, across the axis (a roll standing on end keeps its size).
	var down := Vector3.DOWN - axis * axis.dot(Vector3.DOWN)
	var level := down.length() > 0.9
	down = down.normalized() if level else Vector3.ZERO
	var cuts: Array[float] = [0.0, 1.0]
	if length >= 0.9 and rng.randf() < 0.45:
		cuts = [0.0, [0.42, 0.5, 0.58][rng.randi_range(0, 2)], 1.0]
	for i in cuts.size() - 1:
		var a := cuts[i] * length + (0.02 if i > 0 else 0.0)
		var b := cuts[i + 1] * length - (0.02 if i < cuts.size() - 2 else 0.0)
		var r := radius * (1.0 - 0.07 * (rng.randi_range(0, 2) if level else 0))
		# Its buckles turn with it: kept off its underside (no lower than
		# the family set them, or than level).
		var turn := rng.randf_range(-1.0, 1.0)
		var buckle := basis * Basis(Vector3.UP, turn) * Vector3.RIGHT
		if buckle.y < minf((basis * Vector3.RIGHT).y, 0.0) - 0.001:
			turn = 0.0
		var straps := Vector2(-rng.randf_range(0.24, 0.36), rng.randf_range(0.24, 0.36))
		var tint := VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_CLOTH, 0.5)
		var at := center + axis * ((a + b) * 0.5 - length * 0.5) + down * (radius - r)
		var mount := k._pivot(parent, at)
		mount.basis = basis * Basis(Vector3.UP, turn)
		_roll(k, mount, r, b - a, tint, material, straps)


## One roll on its mount, along its Y: `straps` the two straps' places as
## fractions of its length from its middle.
static func _roll(k: VehicleModels, mount: Node3D, radius: float, length: float, col: Color, material: String, straps: Vector2) -> void:
	var end := minf(0.03, length * 0.04)
	# The body ends in its softened ends, and those show only their outer faces.
	VehicleEquipment._cyl(k, mount, radius, radius, length - end * 2, Vector3.ZERO, Vector3.ZERO, material, col, 12, true, 0)
	for side: float in [-1.0, 1.0]:
		var y := side * (length * 0.5 - end * 0.5)
		VehicleEquipment._cyl(k, mount, radius * (0.88 if side > 0 else 1.0), radius * (1.0 if side > 0 else 0.88), end, Vector3(0, y, 0), Vector3.ZERO, material, col, 12, true, 2 if side > 0 else 1)
		# The wound layers on the end face read as a darker inner spiral.
		k._add(mount, VehicleFittings._ring(radius * 0.36, radius * 0.5), material, col.darkened(0.22), Vector3(0, side * length * 0.5, 0), Vector3.ZERO, Vector3(1, 0.12, 1), false)
	var strap_col := col.darkened(0.35)
	for f: float in [straps.x, straps.y]:
		VehicleEquipment._cyl(k, mount, radius * 1.035, radius * 1.035, minf(0.04, length * 0.05), Vector3(0, f * length, 0), Vector3.ZERO, "webbing", strap_col, 12, false, 0)
		k._box(mount, Vector3(0.014, minf(0.05, length * 0.06), 0.04), Vector3(radius * 1.04, f * length, 0), "gunmetal", Color(0.22, 0.23, 0.21), Vector3.ZERO, false)
	k._fold(mount)
