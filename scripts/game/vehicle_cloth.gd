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
		var t := float(i) / 24.0
		var z := (t - 0.5) * (size.z - 0.08)
		var ripple := sin(float(i) * 0.45 + fold * 1.7) * 0.014 + sin(float(i) * 0.9 + fold * 2.3) * 0.004
		# A lashing cinched over the load pulls the tarp down into a waist
		# under it, so the cover bellies up between its straps; and the tarp
		# folds down over the load's ends instead of stopping square.
		var pinch := 0.0
		for lashing in lashings:
			pinch = maxf(pinch, exp(-pow((float(i) - float(lashing)) / 1.7, 2.0)))
		# (the hem stays where it's tied down along the bed)
		var end := pow(absf(t - 0.5) * 2.0, 6.0)
		var hem := size.x * 0.5 - 0.05
		var w := hem * (1.0 - 0.03 * pinch - 0.025 * end)
		var h := size.y * (1.0 - 0.065 * pinch - 0.07 * end)
		rings.append(PackedVector3Array([Vector3(-hem, 0.14, z), Vector3(-w + ripple, h * 0.72, z), Vector3(-w * 0.75, h - 0.035 + ripple, z), Vector3(0, h + ripple * 0.35, z), Vector3(w * 0.75, h - 0.035 - ripple, z), Vector3(w - ripple, h * 0.72, z), Vector3(hem, 0.14, z)]))
	var shell := VehicleModels.solid(rings, "shared_tarp_%s_%d_%d" % [str(size), lashings[0], lashings[1]] + ("_%d" % fold if fold > 0 else ""))
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
				# The cloth slacks between its supports, most in the middle of a
				# long bay and flat along the rails it's laced to, and pulls
				# into folds running out diagonally from the corners.
				var slack := -minf(0.07, maxf(size.x, size.y) * 0.05) * sin(uv.x * PI) * pow(sin(uv.y * PI), 0.6)
				var folds := sin((uv.x * size.x + uv.y * size.y * 0.7) * 16.0) * 0.013 + sin(uv.x * size.x * 25.0 + uv.y * 3.0) * 0.006
				var depth := slack + edge * folds
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
## place's box but the strap and buckle, as before. A crew that camouflages
## its vehicle (camouflage) may have stuffed its net in one of the places
## instead, heaped up to a third over the place's top, and laid a cut branch
## along the load's top (see branch).
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
	# A crew that camouflages its vehicle (camouflage) stuffs its net in a
	# basket in place of a bag and lays cut branches over the load, where the
	# place is out in the open and level.
	var camo := camouflage(k) if shadow and (basis * Vector3.UP).y > 0.9 else 0.0
	var dress := VehicleCargo.kit(k, parent, center, 12) if camo > 0.0 else null
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
		if dress != null and dress.randf() < 0.35 * camo and minf(place.x, place.z) >= 0.2 and size.y >= 0.15:
			# The net stuffed into the place, heaped up to its top or bulging a
			# third over it (a place in a basket or on a deck is open above).
			var foot := center + basis * Vector3(mid if long_x else 0.0, -size.y * 0.5, 0.0 if long_x else mid)
			net(k, parent, foot, Vector3(place.x, size.y * dress.randf_range(0.9, 1.3), place.z), rotation, dress)
			continue
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
	if dress != null and dress.randf() < 0.8 * camo and long >= 0.4:
		# A branch laid along the load's top, off its middle, its tip either way,
		# cut longer than the load so its leaves hang past both ends and break
		# the load's square outline (what a branch is cut for).
		var lay := basis * (Vector3.RIGHT if long_x else Vector3.BACK) * (1.0 if dress.randf() < 0.5 else -1.0)
		var off := basis * (Vector3.BACK if long_x else Vector3.RIGHT) * dress.randf_range(-0.25, 0.25) * minf(size.x, size.z)
		# (its stem pressed a little into the bags' tops)
		var top := center + basis * Vector3(0, size.y * 0.42, 0) + off
		var reach := long * dress.randf_range(0.55, 0.7)
		branch(k, parent, top - lay * reach, top + lay * reach, dress, clampf(minf(size.x, size.z) * 0.75, 0.2, 0.32))
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


## How heavily a crew has camouflaged its vehicle, from 0 to 1. A military
## vehicle (the armour family's: tanks, carriers, trucks) with a load of its
## own (VehicleCargo.kit) is netted and dressed with cut branches as its crew
## sees fit: some heavily, some a little, a third not at all, as a column in
## the field looks. Never a wreck's (the net and the leaves went up with it),
## nor scenery's or a burnt hulk's, which share one look per kind.
static func camouflage(k: VehicleModels) -> float:
	if k.kit_seed < 0 or k.wreck or k.surface_family != "armor":
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([k.kit_seed, 21])
	var r := rng.randf()
	return 0.0 if r < 0.3 else (0.6 if r < 0.7 else 1.0)


## Camouflage nets as armies issue them, each [the net, its pale scrim, its
## dark scrim]: woodland green over khaki and black-brown, and a desert net of
## sand over pale stone and brown for a vehicle painted sand.
const NET_WOODLAND: Array[Color] = [Color(0.2, 0.24, 0.14), Color(0.4, 0.39, 0.25), Color(0.13, 0.11, 0.07)]
const NET_DESERT: Array[Color] = [Color(0.50, 0.44, 0.31), Color(0.66, 0.60, 0.46), Color(0.30, 0.24, 0.16)]
## Cut leaves: fresh, in shade, and a day or two on, drying out. Living leaves
## are a yellower, more saturated green than any olive or green paint, and
## a branch is cut to be seen as bush from above, so these keep that: a fresh
## spray stands off the paint under it at 50 m, a drying one goes olive-gold.
const LEAVES: Array[Color] = [Color(0.25, 0.38, 0.10), Color(0.18, 0.29, 0.08), Color(0.36, 0.38, 0.13), Color(0.47, 0.40, 0.16)]
## A cut branch's bark.
const STEM := Color(0.27, 0.21, 0.15)


## The net a crew carries goes with its paint: a sand net on a vehicle painted
## sand, a woodland one on anything greener. The paint is the hull's, the
## first part the family put on the model in its own finish.
static func _net_colours(k: VehicleModels) -> Array[Color]:
	for pt: Array in k._parts.get(k.root, []):
		var mat := pt[1] as ShaderMaterial
		if mat == null or VehicleMaterials.profile(mat.resource_name.get_file(), k.surface_family) != k.surface_family:
			continue
		var a: Variant = mat.get_shader_parameter("col_a")
		if a is Color:
			var c: Color = (a as Color) * (pt[2] as Color)
			return NET_DESERT if c.r > c.g * 0.98 and c.get_luminance() > 0.36 else NET_WOODLAND
		break
	return NET_WOODLAND


## A camouflage net bundled up where the crew threw it: an uneven mound over
## `size` (x by z its footprint, y its crown), the middle of its foot at `foot`
## and turned by `rotation`, in the net's shade, and its garnish (the scrim cut
## into leaves that hides the net's square shape) standing out of it in a pale
## shade and a dark one. `rng` picks which of a few ways it lies and the
## shades. Stays within its footprint and 5 cm over its crown.
static func net(k: VehicleModels, parent: Node3D, foot: Vector3, size: Vector3, rotation: Vector3, rng: RandomNumberGenerator) -> void:
	var cols := _net_colours(k)
	var q := Vector3(maxf(0.15, snappedf(size.x, 0.05)), maxf(0.04, snappedf(size.y, 0.02)), maxf(0.15, snappedf(size.z, 0.05)))
	var meshes := _net_meshes(q, rng.randi_range(0, 2))
	var mount := k._pivot(parent, foot)
	mount.basis = Basis.from_euler(rotation) * Basis(Vector3.UP, PI if rng.randf() < 0.5 else 0.0)
	var scale := size / q
	for i in 3:
		var shade := rng.randf_range(-0.07, 0.07)
		var c: Color = cols[i].lightened(shade) if shade > 0.0 else cols[i].darkened(-shade)
		k._add(mount, meshes[i], "canvas", c, Vector3.ZERO, Vector3.ZERO, scale, i == 0)
	k._fold(mount)


static var _nets := {}

## The net's meshes `size` big as `variant` lies: [the heap, the pale scrim,
## the dark scrim]. Cached by both.
static func _net_meshes(size: Vector3, variant: int) -> Array:
	var key := "%s_%d" % [str(size), variant]
	if _nets.has(key):
		return _nets[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["net", key])
	# A bundled net heaps up in a few folds: bumps of their own size here and
	# there over a low dome, the whole scaled to the crown.
	var folds: Array[Vector4] = []
	for i in 4:
		folds.append(Vector4(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.5, 0.5), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 1.0)))
	var ragged := rng.randf_range(0.0, TAU)
	var nx := clampi(ceili(size.x / 0.07), 4, 18)
	var nz := clampi(ceili(size.z / 0.07), 4, 18)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var top := 0.0
	for j in nz + 1:
		for i in nx + 1:
			var p := _net_point(float(i) / nx * 2.0 - 1.0, float(j) / nz * 2.0 - 1.0, size, folds, ragged)
			top = maxf(top, p.y)
			verts.append(p)
	var lift := size.y / maxf(top, 0.001)
	for i in verts.size():
		verts[i].y *= lift
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	var heap := _smooth(verts, idx)
	var parts: Array = [heap]
	# The garnish: the scrim's leaves lying on the heap, most flat to it and some
	# turned up out of it, so many that little plain net shows between them,
	# kept in from the edge far enough that none hangs past it. Each is shaded
	# as the heap under it, so the heap reads as one soft lumpy mass.
	var count := clampi(roundi(size.x * size.z * 130.0), 8, 64)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var ru := maxf(0.2, 1.0 - 0.09 / hx)
	var rv := maxf(0.2, 1.0 - 0.09 / hz)
	for tint in 2:
		var lv := PackedVector3Array()
		var ln := PackedVector3Array()
		var li := PackedInt32Array()
		for n in count:
			var u := rng.randf_range(-ru, ru)
			var v := rng.randf_range(-rv, rv)
			var e := 0.03
			var p := _net_point(u, v, size, folds, ragged) * Vector3(1, lift, 1)
			var du := (_net_point(u + e, v, size, folds, ragged) - _net_point(u - e, v, size, folds, ragged)) * Vector3(1, lift, 1)
			var dv := (_net_point(u, v + e, size, folds, ragged) - _net_point(u, v - e, size, folds, ragged)) * Vector3(1, lift, 1)
			var up := dv.cross(du).normalized()
			if up.y < 0.0:
				up = -up
			var a := rng.randf_range(0.0, TAU)
			var t := (du.normalized() * cos(a) + dv.normalized() * sin(a)).normalized()
			var tilt := rng.randf_range(0.05, 0.75)
			var b := (up.cross(t).normalized() * cos(tilt) + up * sin(tilt)).normalized()
			# (cut a hand long: from a few tens of metres the scrim's tufts, not
			# the net, are what break up the bundle's shape)
			var w := rng.randf_range(0.06, 0.09)
			_leaf(lv, ln, li, p + up * 0.006 + b * w * 0.5 * sin(tilt), t, b, rng.randf_range(0.11, 0.17), w, up)
		parts.append(VehicleWheels._mesh(lv, ln, li))
	_nets[key] = parts
	return parts


## A point on the net's heap over (u, v), each -1..1 across its footprint,
## before it is scaled to its crown: a low dome and the folds (u, v, reach,
## height) heaped on it, falling to nothing at its foot, and its edge ragged
## where the scrim hangs.
static func _net_point(u: float, v: float, size: Vector3, folds: Array[Vector4], ragged: float) -> Vector3:
	var cu := clampf(u, -1.0, 1.0)
	var cv := clampf(v, -1.0, 1.0)
	var h := 0.35 * (1.0 - cu * cu) * (1.0 - cv * cv)
	for f: Vector4 in folds:
		h += f.w * exp(-((cu - f.x) * (cu - f.x) + (cv - f.y) * (cv - f.y)) / (f.z * f.z))
	h *= maxf(0.0, (1.0 - pow(absf(cu), 4.0)) * (1.0 - pow(absf(cv), 4.0)))
	var edge := pow(maxf(absf(cu), absf(cv)), 4.0)
	var pull := 1.0 - 0.1 * (0.5 + 0.5 * sin(cu * 9.0 + cv * 7.0 + ragged)) * edge
	return Vector3(cu * size.x * 0.5 * pull, size.y * h, cv * size.z * 0.5 * pull)


## A mesh from shared vertices, its normals smoothed over the faces round
## each and every face turned up (a heap seen from above).
static func _smooth(verts: PackedVector3Array, idx: PackedInt32Array) -> ArrayMesh:
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	var out := PackedInt32Array()
	for f in range(0, idx.size(), 3):
		var a := idx[f]
		var b := idx[f + 1]
		var c := idx[f + 2]
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if n.y < 0.0:
			n = -n
		for i: int in [a, b, c]:
			norms[i] += n
		VehicleWheels._tri(out, verts, n, a, b, c)
	for i in norms.size():
		norms[i] = norms[i].normalized() if norms[i].length_squared() > 0.0 else Vector3.UP
	return VehicleWheels._mesh(verts, norms, out)


## One leaf, of scrim or off a branch: a diamond `length` along `t` and
## `width` along `b`, centred on `c`, its widest a little toward its tip, seen
## from both sides (a leaf has no back face to hide). Both faces are shaded
## as `shade` faces (the heap's or the spray's outside where the leaf is), so
## a mass of leaves lights as one soft shape instead of a glitter of facets.
static func _leaf(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, c: Vector3, t: Vector3, b: Vector3, length: float, width: float, shade: Vector3) -> void:
	var corners := [c - t * length * 0.5, c + b * width * 0.5 + t * length * 0.08, c + t * length * 0.5, c - b * width * 0.5 + t * length * 0.08]
	var face := t.cross(b)
	var n := (shade + face * (0.35 if face.dot(shade) >= 0.0 else -0.35)).normalized()
	for side: float in [1.0, -1.0]:
		var base := verts.size()
		verts.append_array(corners)
		norms.append_array([n, n, n, n])
		VehicleWheels._tri(idx, verts, face * side, base, base + 1, base + 2)
		VehicleWheels._tri(idx, verts, face * side, base, base + 2, base + 3)


static var _sprays := {}

## A spray of leaves at the end of a twig, about a unit across (scaled to its
## branch), longer along x than across and flatter still: leaves crowding out
## from its middle at all angles. Cached by `variant`.
static func _spray(variant: int) -> ArrayMesh:
	if _sprays.has(variant):
		return _sprays[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["spray", variant])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for n in 42:
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var r := pow(rng.randf(), 0.5) * 0.9
		var c := Vector3(d.x * r * 1.25, d.y * r * 0.55 + 0.12, d.z * r)
		var out := Vector3(c.x / 1.25, (c.y - 0.12) / 0.55, c.z).normalized()
		var t := (out + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6))).normalized()
		var b := t.cross(Vector3(rng.randf_range(-0.7, 0.7), 1.0, rng.randf_range(-0.7, 0.7)).normalized()).normalized()
		_leaf(verts, norms, idx, c, t, b, rng.randf_range(0.46, 0.62), rng.randf_range(0.22, 0.3), (out + Vector3.UP * 0.3).normalized())
	_sprays[variant] = VehicleWheels._mesh(verts, norms, idx)
	return _sprays[variant]


## A branch cut for camouflage and laid on the vehicle, from its cut end `a` to
## its tip `b` in the parent's space: a stem, and sprays of leaves crowding its
## outer two thirds, each about three times `spread` long and twice it across,
## leaning up off what it lies on, all the one cutting's shade (fresh, or
## drying out a day or two on).
static func branch(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, rng: RandomNumberGenerator, spread := 0.2) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.2:
		return
	var dir := along / length
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
	var up := side.cross(dir).normalized()
	VehicleEquipment._rod(k, parent, a, b, 0.013, "canvas", STEM, 5, false, 3, 0.005)
	var age := rng.randi_range(0, LEAVES.size() - 1) if rng.randf() < 0.35 else rng.randi_range(0, 1)
	var sprays := clampi(roundi(length / 0.26), 3, 6)
	for i in sprays:
		var f := lerpf(0.3, 1.0, float(i) / (sprays - 1))
		var s := spread * rng.randf_range(0.9, 1.1) * (0.8 + 0.2 * f)
		var lean := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(0.15, 0.4)
		var at := a + along * f + side * lean * s + up * s * 0.3
		var basis := Basis(dir, up, dir.cross(up)).rotated(dir, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
		var shade := rng.randf_range(-0.05, 0.05)
		var c := LEAVES[age].lightened(shade) if shade > 0.0 else LEAVES[age].darkened(-shade)
		# (spread wider than tall, along and across what it lies on: a spray
		# pressed down by its own weight covers ground, it doesn't stand up)
		k._add(parent, _spray(rng.randi_range(0, 3)), "canvas", c, at, basis.get_euler(), Vector3(1.2, 0.75, 1.2) * s)


## Whether `node` stands upright on the model (its +Y within 25 degrees of
## the model's up): a net or a branch rests only on what's level.
static func _upright(k: VehicleModels, node: Node3D) -> bool:
	var basis := Basis.IDENTITY
	var n := node
	while n != null and n != k.root:
		basis = n.basis * basis
		n = n.get_parent() as Node3D
	return (basis * Vector3.UP).normalized().y > 0.9


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
## its axis no further than keeps the buckles off what it lies on, and now and
## then a cut branch tucked along its top (camouflage). A roll of the
## vehicle's own canvas (canvas_white: a tilt's back flap rolled up) or
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
	# A crew that camouflages its vehicle (camouflage) tucks a cut branch under
	# a lying roll's straps, along its top.
	var camo := camouflage(k) if level and length >= 0.5 else 0.0
	if camo > 0.0 and _upright(k, parent):
		var dress := VehicleCargo.kit(k, parent, center, 14)
		if dress.randf() < 0.75 * camo:
			var lay := axis * (1.0 if dress.randf() < 0.5 else -1.0)
			var top := center - down * radius * 0.85
			var reach := length * dress.randf_range(0.5, 0.62)
			branch(k, parent, top - lay * reach, top + lay * reach, dress, clampf(radius * 1.9, 0.18, 0.3))


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
