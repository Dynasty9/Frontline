class_name VehicleCloth
extends RefCounted

## A tarpaulin lashed over a load, taking the load's shape (_box_tarp); a
## wreck's is the old cloth shell with a sloping crown and gathered side
## folds. The displacement is deterministic and stays in model space; straps
## remain separate geometry. On a vehicle with a load of its own
## (VehicleCargo.kit) the tarp is the crew's: its own shade of drab, the way
## it was thrown over and its lashings a hand forward or back of where they
## were.
static func load_cover(k: VehicleModels, base: Vector3, size: Vector3, col := Color(0.30, 0.32, 0.23), pallet := true, mat := "canvas_white", boxes := Vector3i.ZERO, straps: Array = []) -> void:
	# (`mat` the cloth: cotton duck by default, "coated" for a polythene or PVC
	# tarp, smooth and a little glossy, that sheds the rain; a wreck's stays
	# the duck it always was)
	if k.wreck:
		mat = "canvas_white"
	var rng := VehicleCargo.kit(k, k.root, base, 3)
	# A load under a tarp is boxes and bales, and the tarp takes their shape
	# (_box_tarp): `boxes`, the boxes across, the layers and the boxes along,
	# where the caller knows them (VehicleCargo.crate_stack's stack, the tarp
	# exactly its size and colour, `straps` the z offsets of its lashings),
	# else a load of boxes of about 60 by 45 cm under the cloth, its two
	# lashings a quarter of the way in from either end, give or take a
	# hand's width. Its hem comes down to the bed (or the pallet) it's tied
	# to, where the old shell's stopped 14 cm short of it. (A wreck's stays
	# the cover it always was.)
	if not k.wreck:
		var lift := 0.12 if pallet else 0.0
		if pallet:
			k._box(k.root, Vector3(size.x - 0.06, 0.12, size.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
		var cover := size
		var grid := boxes
		var lashed := straps
		if boxes == Vector3i.ZERO:
			cover = Vector3(size.x - 0.1, size.y - lift, size.z - 0.08)
			grid = Vector3i(maxi(1, roundi(cover.x / 0.6)), maxi(1, roundi(cover.y / 0.45)), maxi(1, roundi(cover.z / 0.6)))
			lashed = [-cover.z * 0.25, cover.z * 0.25]
			if rng != null:
				col = VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_TARP, 0.5)
				lashed = [-cover.z * (0.25 + rng.randf_range(-0.04, 0.04)), cover.z * (0.25 + rng.randf_range(-0.04, 0.04))]
		# A depot's tarpaulin over a stack of cases is heavy vinyl-coated
		# duck a few seasons old, gone as dull as the canvas: in the coated
		# finish's satin sheen a sheet over boxes read as a plastic case.
		# (A loose load's plastic sheet, the offroad's, keeps its sheen.)
		var cloth := "canvas_white" if mat == "coated" and boxes != Vector3i.ZERO else mat
		if cloth != mat:
			# (its shades were picked a little warm for the sheen that greyed
			# them; matte, they'd come out mustard and grass)
			col = Color.from_hsv(col.h, col.s * 0.75, col.v)
		# (a load the caller doesn't know is piled by hand: its sides lean in)
		_box_tarp(k, base + Vector3(0, lift, 0), cover, grid, lashed, col, cloth, rng, 0.04 if boxes == Vector3i.ZERO else 0.0)
		return
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
	k._add(k.root, smooth.commit(), mat, col, base)
	for index in [0, 24]:
		var rim: PackedVector3Array = rings[index]
		for j in rim.size() - 1:
			VehicleEquipment._rod(k, k.root, base + rim[j], base + rim[j + 1], 0.009, mat, col.darkened(0.16), 6, false, 3)
	var last := rings[0].size() - 1
	for side in [0, last]:
		VehicleEquipment._rod(k, k.root, base + rings[0][side], base + rings[24][side], 0.009, mat, col.darkened(0.16), 6, false, 3)
	# (a wreck's lashings stay the round cords they always were)
	for index in lashings:
		var cross_section: PackedVector3Array = rings[index]
		for j in last:
			VehicleEquipment._rod(k, k.root, base + cross_section[j] + Vector3(0, 0.012, 0), base + cross_section[j + 1] + Vector3(0, 0.012, 0), 0.012, "webbing", Color(0.18, 0.19, 0.13), 6, false, 3)


static var _box_tarps := {}


## A tarpaulin lashed over a stack of boxes (load_cover's `boxes`: the boxes
## across, the layers and the boxes along; `size` the stack's, from its foot
## at `base`). Pulled over boxes a tarp takes their shape, not a pillow's: it
## lies flat on the lids and dips 3.5 cm into the gaps between them, so from
## above the load still reads as boxes under a sheet; it turns over the lids'
## edges in a tight 2.5 cm roll and hangs down the sides, bellied a little
## between the joints and creased in at each, to its hem hanging loose just
## above the bed. The spare cloth at each corner is folded round the end, so
## the skirt flares out a few centimetres at the foot of every corner, the
## fold's edge running up to the lid's corner (more at one end than the
## other: the way it was thrown over). Its faces are planes between the rolls
## and creases, so they read as a box's and only those shade round. Its
## lashings (`straps`, z offsets) are webbing from hem to hem, cinched flat
## over the lids and the rolls. `lean` draws the sides in by that much at the
## top, as a tarp falls over a load piled by hand rather than one stacked
## square. One cached sheet per size, stack, lean and lie.
static func _box_tarp(k: VehicleModels, base: Vector3, size: Vector3, boxes: Vector3i, straps: Array, col: Color, mat: String, rng: RandomNumberGenerator, lean := 0.0) -> void:
	var lie := rng.randi_range(0, 1) if rng != null else 0
	var key := "%s|%s|%d|%.3f" % [str(size), str(boxes), lie, lean]
	if not _box_tarps.has(key):
		_box_tarps[key] = _box_tarp_mesh(size, boxes, lie, lean)
	k._add(k.root, _box_tarps[key], mat, col, base)
	var hx := size.x * 0.5
	var hi := hx - lean
	var top := size.y
	var t := 0.005
	var shape := _tarp_shape(size, boxes, lean)
	var roll: float = shape[0]
	var crown: float = shape[2]
	var belly: float = shape[3]
	var middles: Array[float] = shape[4]
	# (the webbing a shade darker than the cloth it's cinched over, as wet
	# and oily straps go: at the tarp's own value it vanished into the sheet)
	var webbing := VehicleCargo.kit_colour(rng, Color(0.18, 0.19, 0.13), VehicleCargo.KIT_STRAP, 0.6) if rng != null else Color(0.18, 0.19, 0.13)
	webbing = webbing.darkened(0.35)
	var nz := maxi(1, boxes.z)
	for s: float in straps:
		var at := base + Vector3(0, 0, s)
		# (the sides belly out only clear of the joints between the boxes
		# along, where the sheet is pulled in: a strap there lies on the
		# crease)
		var clear := 1.0
		for j in range(1, nz):
			clear = minf(clear, absf(s - (-size.z * 0.5 + size.z * float(j) / float(nz))) / 0.05)
		clear = minf(clear, 1.0)
		# hem, over the bellies of the sides, the shoulder, the lid's crown
		var left := [at + Vector3(-hx - t - 0.01, 0.035, 0)]
		for y: float in middles:
			left.append(at + Vector3(-(hx - lean * y / top) - belly * clear - t, y, 0))
		# (over a crowned lid it rides the crown, laid on at the shoulder, half
		# way in and the middle, bridging the dips between)
		var u := (hx - roll) / hx
		left.append_array([at + Vector3(-hi - t, top - roll, 0), at + Vector3(-hi + roll, top + crown * (1.0 - u * u) + t, 0)])
		if crown > 0.0:
			left.append(at + Vector3(-hi * 0.5, top + crown * 0.75 + t, 0))
		var path := left.duplicate()
		if crown > 0.0:
			path.append(at + Vector3(0, top + crown + t, 0))
		left.reverse()
		for p: Vector3 in left:
			path.append(Vector3(2.0 * at.x - p.x, p.y, p.z))
		strap(k, k.root, path, 0.05, webbing, Vector3.BACK, t)


## The shape a tarp takes over its load, shared by its sheet and its straps:
## [the shoulder's roll radius, the shoulder's depth, the lid's crown, the
## sides' belly, the heights of the bellies (each layer's middle)]. Over
## boxes stacked square (no `lean`) it turns the lids' edges in a tight 2.5
## cm roll and lies flat on them; over a load piled by hand it falls over
## soft 9 cm shoulders onto a lid crowned 4 cm in the middle, as cloth drapes
## over bales and bags, not over cases.
static func _tarp_shape(size: Vector3, boxes: Vector3i, lean: float) -> Array:
	var soft := lean > 0.0
	var roll := 0.09 if soft else 0.025
	var shoulder := roll + 0.035
	var top := size.y
	var ny := maxi(1, boxes.y)
	var middles: Array[float] = []
	for l in ny:
		var y := top * (float(l) + 0.5) / float(ny)
		var below := 0.07 if l == 0 else top * float(l) / float(ny) + 0.025
		var above := top - shoulder if l == ny - 1 else top * float(l + 1) / float(ny) - 0.025
		if y - below > 0.03 and above - y > 0.03:
			middles.append(y)
	return [roll, shoulder, 0.04 if soft else 0.0, 0.02 if soft else 0.012, middles]


static func _box_tarp_mesh(size: Vector3, boxes: Vector3i, lie: int, lean := 0.0) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var top := size.y
	var nx := maxi(1, boxes.x)
	var ny := maxi(1, boxes.y)
	var nz := maxi(1, boxes.z)
	# Canvas pulled over boxes, not a box itself: it sinks 3.5 cm into the
	# gaps between them (at a centimetre and a half it read as one hard
	# case), its sides belly out between the layers' joints and hang loose a
	# finger's width at the hem, and the spare cloth folded round each end
	# flares 6 cm at the foot of the corners.
	var shape := _tarp_shape(size, boxes, lean)
	var roll: float = shape[0]
	var shoulder: float = shape[1]
	var crown: float = shape[2]
	var belly: float = shape[3]
	var middles: Array[float] = shape[4]
	var dip := 0.035 if crown == 0.0 else 0.02
	var ear := 0.06
	var nib := roll * 0.32
	# Stations up a side (y, and 1 where a layer's joint creases it, -1 at a
	# layer's middle, where the side bellies) and across the lid (x, and 1
	# at a joint between boxes).
	var ys: Array[Vector2] = [Vector2(0.025, 0.0), Vector2(0.07, 0.0)]
	for l in ny:
		if l > 0:
			var y := top * float(l) / float(ny)
			ys.append_array([Vector2(y - 0.025, 0.0), Vector2(y, 1.0), Vector2(y + 0.025, 0.0)])
		var y_mid := top * (float(l) + 0.5) / float(ny)
		if y_mid in middles:
			ys.append(Vector2(y_mid, -1.0))
	ys.append_array([Vector2(top - shoulder, 0.0), Vector2(top - roll, 0.0)])
	var xs: Array[Vector2] = [Vector2(-hx + roll, 0.0), Vector2(-hx + shoulder, 0.0)]
	var odd := (nx & 1) == 1
	var mid := nx >> 1
	if odd and mid == 0:
		xs.append(Vector2(0.0, 0.0))
	for i in range(1, nx):
		var x := -hx + size.x * float(i) / float(nx)
		xs.append_array([Vector2(x - 0.05, 0.0), Vector2(x, 1.0), Vector2(x + 0.05, 0.0)])
		if odd and i == mid:
			xs.append(Vector2(0.0, 0.0))
	xs.append_array([Vector2(hx - shoulder, 0.0), Vector2(hx - roll, 0.0)])
	# Stations along it: [z, dip at a joint, the end's roll, the corners'
	# flare], from the front end to the back.
	var fade := minf(0.16, hz * 0.45)
	var front := 1.0 if lie == 0 else 0.6
	var back := 0.6 if lie == 0 else 1.0
	var zs: Array[Vector4] = [Vector4(-hz, 0.0, roll, front), Vector4(-hz + nib, 0.0, nib, front * (1.0 - nib / fade)), Vector4(-hz + roll, 0.0, 0.0, front * (1.0 - roll / fade)), Vector4(-hz + shoulder, 0.0, 0.0, front * maxf(0.0, 1.0 - shoulder / fade)), Vector4(-hz + fade, 0.0, 0.0, 0.0)]
	for j in range(1, nz):
		var z := -hz + size.z * float(j) / float(nz)
		zs.append_array([Vector4(z - 0.05, 0.0, 0.0, 0.0), Vector4(z, 1.0, 0.0, 0.0), Vector4(z + 0.05, 0.0, 0.0, 0.0)])
	zs.append_array([Vector4(hz - fade, 0.0, 0.0, 0.0), Vector4(hz - shoulder, 0.0, 0.0, back * maxf(0.0, 1.0 - shoulder / fade)), Vector4(hz - roll, 0.0, 0.0, back * (1.0 - roll / fade)), Vector4(hz - nib, 0.0, nib, back * (1.0 - nib / fade)), Vector4(hz, 0.0, roll, back)])
	var rings: Array[PackedVector3Array] = []
	for st: Vector4 in zs:
		var z := st.x
		var d := st.y
		var e := st.z
		var f := st.w
		# (no dips in the end rings, which close flat: the end's own face)
		var keep := 1.0 - e / roll
		var ring := PackedVector3Array()
		for side: float in [-1.0, 1.0]:
			var run: Array[Vector2] = ys.duplicate()
			if side > 0.0:
				run.reverse()
			var lid := PackedVector3Array()
			for yv: Vector2 in run:
				var y := yv.x
				var flare := ear * f * (1.0 - y / top)
				var lip := 0.016 if y < 0.03 else 0.0
				# (pulled in at a layer's joint and where the boxes along it
				# meet, bellied out between)
				var crease := (0.01 * maxf(yv.y, 0.0) + 0.012 * d - belly * maxf(-yv.y, 0.0) * (1.0 - d)) * keep
				var roll_in := clampf((y - (top - shoulder - 0.02)) / (shoulder + 0.02), 0.0, 1.0)
				lid.append(Vector3(side * (hx + flare + lip - crease - lean * y / top), y - e * roll_in, z))
			if side < 0.0:
				ring.append_array(lid)
				ring.append(Vector3(-hx + lean + nib, top - nib - e, z))
				for xv: Vector2 in xs:
					var u := xv.x / hx
					ring.append(Vector3(xv.x * (1.0 - lean / hx), top - e - dip * maxf(xv.y, d) * keep + crown * (1.0 - u * u) * keep, z))
				ring.append(Vector3(hx - lean - nib, top - nib - e, z))
			else:
				ring.append_array(lid)
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for r in rings.size() - 1:
		var r0 := rings[r]
		var r1 := rings[r + 1]
		var cen := Vector3(0, top * 0.5, (r0[0].z + r1[0].z) * 0.5)
		var n := r0.size()
		for i in n:
			var j := i + 1 if i + 1 < n else 0
			# (the underside, hem to hem, apart: its normals would darken the
			# hem's whole band)
			surface.set_smooth_group(2 if j == 0 else 0)
			VehicleModels._tri(surface, r0[i], r0[j], r1[j], cen)
			VehicleModels._tri(surface, r0[i], r1[j], r1[i], cen)
	surface.set_smooth_group(1)
	for e: int in [0, rings.size() - 1]:
		var r := rings[e]
		var inside := Vector3(0, top * 0.5, 0)
		for i in range(1, r.size() - 1):
			VehicleModels._tri(surface, r[0], r[i], r[i + 1], inside)
	surface.generate_normals()
	surface.index()
	return surface.commit()


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
		if closed_back and z != ends[0] and not k.wreck:
			# The back flap let down and laced shut is cloth, not a board: it
			# hangs from the rear bow in two soft folds, pulled flat again at
			# its foot where it's laced to the tailboard (a wreck's stays the
			# sheet it was).
			var low: float = (profile[0] as Vector2).y
			for p: Vector2 in profile:
				low = minf(low, p.y)
			var key := "%s|%.3f|laced" % [str(profile), low]
			if not _flaps.has(key):
				_flaps[key] = _flap_mesh(profile, low, true)
			k._add(parent, _flaps[key], "canvas_white", col, Vector3(0, 0, z + 0.012))
			continue
		var front := PackedVector3Array()
		var back := PackedVector3Array()
		for point: Vector2 in profile:
			front.append(Vector3(point.x, point.y, z))
			back.append(Vector3(point.x, point.y, z + 0.012))
		k._add(parent, VehicleModels.solid([front, back], "cloth_front_%s_%s" % [str(profile), str(z)]), "canvas_white", col, Vector3.ZERO)
	# (a wreck's tilt keeps its old fitted panels)
	if not k.wreck:
		_tilt(k, parent, profile, bows, col)
		return
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


## The faded issue shade a tilt's roof goes after a few summers in the sun:
## paler and greyer than the sides, which the roof shades. (A wreck's.)
const SUN_FADED := Color(0.60, 0.58, 0.50)
## The same on a running truck: olive duck bleaches toward a warm khaki, the
## dye's green going first. (Toward the greyer shade, on a tilt as dark as the
## hull a bleached width read slate blue in the sky's light, a different cloth.)
const SUN_FADED_LIVE := Color(0.6, 0.55, 0.42)
## How much more or less than the rest each roof width has faded, bay by bay.
const ROOF_FADES: Array[float] = [0.0, 0.06, -0.04, 0.035, -0.055, 0.05]
static var _tilts := {}


## A canvas tilt as it lies on its bows: one cover pulled over them, sagging
## between them (most on the roof, a little on the sides) so each bow shows as
## a ridge, creased where it was folded and its hem laced with a cord to the
## bed through eyes a little under half a metre apart, scalloping up between
## them. It's sewn from widths: the roof (faded paler by the sun) and each
## side curtain, a seam at every bow; on a vehicle with a load of its own
## (VehicleCargo.kit) it lies one of three ways, and one width in two has been
## patched or replaced in another shade.
static func _tilt(k: VehicleModels, parent: Node3D, profile: Array, bows: Array, col: Color) -> void:
	var variant := 0
	var patch := Vector2i(-1, -1)
	var patch_col := col
	var rng := VehicleCargo.kit(k, parent, Vector3(0, 0, float(bows[0])), 17)
	if rng != null:
		variant = rng.randi_range(0, 2)
		var wide: Array[int] = []
		for bay in bows.size() - 1:
			if float(bows[bay + 1]) - float(bows[bay]) > 0.5:
				wide.append(bay)
		if not wide.is_empty() and rng.randf() < 0.5:
			patch = Vector2i(wide[rng.randi_range(0, wide.size() - 1)], rng.randi_range(0, 2))
			var other := VehicleCargo.kit_colour(rng, col, VehicleCargo.KIT_TARP, 0.0)
			patch_col = col.lerp(other, 0.5).darkened(0.07) if rng.randf() < 0.6 else col.lerp(SUN_FADED if k.wreck else SUN_FADED_LIVE, 0.3)
	# In the heat a crew rolls a side curtain up to the eaves (or both) and
	# straps it there, so the bows, benches and bed show.
	var rolled := 0
	if rng != null:
		var pick := rng.randf()
		rolled = 3 if pick < 0.16 else (1 if pick < 0.26 else (2 if pick < 0.36 else 0))
	var built := _tilt_meshes(profile, bows, variant)
	# (the roof bleached by the sun on every tilt, the curtains under the
	# eaves a shade darker, where road dirt and the rain's run-off stain them)
	var faded := SUN_FADED if k.wreck else SUN_FADED_LIVE
	var roof := col.lerp(faded, 0.26)
	var side := col.darkened(0.06)
	for part: Array in built[0]:
		var width := int(part[2])
		if width != 1 and (rolled & (1 if width == 0 else 2)) != 0:
			continue
		# (each roof width sewn from its own bolt and bleached its own amount,
		# so from above the bays don't read as one lid)
		# (posmod, not %: models are built on worker threads)
		var c := col.lerp(faded, 0.26 + ROOF_FADES[posmod(int(part[1]) + variant * 2, ROOF_FADES.size())]) if width == 1 else side
		if Vector2i(int(part[1]), width) == patch:
			c = patch_col
		k._add(parent, part[0], "canvas_white", c, Vector3.ZERO)
	# the bound hems along the bed, and the lacing cord
	for s in 2:
		if (rolled & (1 << s)) == 0:
			k._add(parent, built[1][s], "canvas_white", col.darkened(0.16), Vector3.ZERO)
			k._add(parent, built[2][s], "canvas_white", col.darkened(0.42).lerp(Color(0.25, 0.23, 0.17), 0.4), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	# The cover's dim inside, the cloth seen from under it: past an open back
	# or a rolled side the shade under the tilt shows, and the benches and
	# troops in it, as on a real truck (no board across the opening). (Under
	# a cover the sky's light is gone, which the renderer doesn't know: lit
	# by the sun through the opening, a liner at 40% of the cloth read as
	# bright as the outside, so it's taken down to 28%.)
	for width in 3:
		if width == 1 or (rolled & (1 if width == 0 else 2)) == 0:
			k._add(parent, built[4][width], "canvas_white", col.darkened(0.72), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	if rolled != 0:
		var z0: float = bows[0]
		var z1: float = bows[bows.size() - 1]
		for s in 2:
			if (rolled & (1 << s)) == 0:
				continue
			var eave: Vector3 = built[3][s]
			var out := -1.0 if s == 0 else 1.0
			# the bows' painted uprights from the bed to the eaves (the cover's
			# end hems wrap the end bows)
			for j in bows.size():
				var z: float = bows[j]
				if j > 0 and j < bows.size() - 1 and (z - float(bows[j - 1]) < 0.2 or float(bows[j + 1]) - z < 0.2):
					continue
				for i in profile.size() - 1:
					var a: Vector2 = profile[i]
					var b: Vector2 = profile[i + 1]
					var d := b - a
					if absf(Vector2(-d.y, d.x).normalized().y) < 0.5 and (a.x + b.x) * out > 0.0:
						VehicleEquipment._rod(k, parent, Vector3(a.x, a.y, z) - Vector3(out * 0.02, 0, 0), Vector3(b.x, b.y, z) - Vector3(out * 0.02, 0, 0), 0.018, "gunmetal_w", col.darkened(0.3), 6, false, 0)
			# the curtain rolled up under the eaves, strapped round
			var r := 0.085
			var at := Vector3(eave.x + out * r * 0.7, eave.y - r * 0.5, (z0 + z1) * 0.5)
			roll(k, parent, at, r, z1 - z0 - 0.04, Vector3(PI / 2, 0, 0), side.darkened(0.04), "canvas_white")
			# Two more webbing straps nearer its middle (the roll's own are
			# near its ends), cinched onto the roll's flattened section: its
			# top settled to ROLL_TOP of its radius, its underside where it
			# rests, so a band's middle sits a little below the roll's axis.
			for f: float in [-0.12, 0.12]:
				k._add(parent, VehicleEquipment._cylinder(1.0, 1.0, 0.04, 10, false, false), "webbing", col.darkened(0.35), at + Vector3(0, -r * (1.0 - ROLL_TOP) * 0.5, f * (z1 - z0)), Vector3(PI / 2, 0, 0), Vector3(r * 1.02, 1.0, r * (1.0 + ROLL_TOP) * 0.5 * 1.02), false)
	# the doubled hems bound round the cover's front and back edges, over the
	# end bows, and the chafing strips over the bows between them
	k._add(parent, built[5], "canvas_white", roof.darkened(0.25), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## A tilt's back flap let half down from its rear bow at `z`: the cloth hangs
## from the bow's own section (so it meets the cover at the roof and the
## shoulders, with no gaps), falls in two soft vertical folds and is rolled up
## at its foot, `foot` high, and strapped there, so the dim inside shows under
## it. One cached sheet per section and foot.
static func back_flap(k: VehicleModels, parent: Node3D, profile: Array, z: float, foot: float, col: Color) -> void:
	var key := "%s|%.3f" % [str(profile), foot]
	if not _flaps.has(key):
		_flaps[key] = _flap_mesh(profile, foot)
	k._add(parent, _flaps[key], "canvas_white", col, Vector3(0, 0, z + 0.004))
	var r := 0.085
	var width := _flap_half(profile, foot) * 2.0 - 0.08
	roll(k, parent, Vector3(0, foot + r * 0.35, z + r * 0.85), r, width, Vector3(0, 0, PI / 2), col.darkened(0.05), "canvas_white")


static var _flaps := {}


## The section's half width at height y (its widest point there).
static func _flap_half(profile: Array, y: float) -> float:
	var best := 0.0
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if (y - a.y) * (y - b.y) <= 0.0 and absf(b.y - a.y) > 0.0001:
			best = maxf(best, absf(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))))
		elif absf(b.y - a.y) <= 0.0001 and absf(y - a.y) < 0.0001:
			best = maxf(best, maxf(absf(a.x), absf(b.x)))
	return best


## The flap's sheet in the section's plane (z 0, its face toward +Z): rows
## from the foot to the crown, through every corner of the section, each as
## wide as the section there; the folds deepen toward the foot, where the
## cloth hangs free of the bow. `laced`: the flap let all the way down and
## laced to the tailboard, its folds fullest half way down and pulled flat at
## both ends, set in from the lacing straps families run down its face.
static func _flap_mesh(profile: Array, foot: float, laced := false) -> ArrayMesh:
	var top := foot
	for p: Vector2 in profile:
		top = maxf(top, p.y)
	var ys: Array[float] = []
	for i in 5:
		ys.append(lerpf(foot, top, i / 4.0))
	for p: Vector2 in profile:
		if p.y > foot + 0.02 and p.y < top - 0.02:
			ys.append(p.y)
	ys.sort()
	var cols := 21
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var grid: Array[PackedVector3Array] = []
	for y: float in ys:
		var hw := _flap_half(profile, y)
		var hang := 1.0 - (y - foot) / maxf(top - foot, 0.01)
		var row := PackedVector3Array()
		for c in cols:
			var u := float(c) / (cols - 1)
			var fold := 0.0
			for at: float in ([0.38, 0.62] if laced else [0.3, 0.68]):
				fold += exp(-pow((u - at) / (0.05 if laced else 0.07), 2.0))
			var depth := (0.03 * fold + 0.012 * sin(PI * u)) * hang * sin(PI * u)
			if laced:
				depth = 0.035 * fold * sin(PI * hang) * sin(PI * u)
			row.append(Vector3((u - 0.5) * 2.0 * hw, y, depth))
		grid.append(row)
	for r in grid.size() - 1:
		for c in cols - 1:
			# (wound clockwise seen from behind, the face Godot draws)
			var quad: Array[Vector3] = [grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]]
			for tri: Array in [[0, 3, 2], [0, 2, 1]]:
				for i: int in tri:
					surface.set_uv(Vector2(quad[i].x, quad[i].y))
					surface.add_vertex(quad[i])
	surface.index()
	surface.generate_normals()
	return surface.commit()


## The section sampled from the left hem over the crown to the right about
## every 12 cm, the corners kept: [points, outward normals (averaged at the
## corners), arc length from the left hem, the segment each starts].
static func _tilt_section(profile: Array) -> Array:
	var face: Array[Vector2] = []
	for i in profile.size() - 1:
		var d: Vector2 = (profile[i + 1] as Vector2) - (profile[i] as Vector2)
		face.append(Vector2(-d.y, d.x).normalized())
	var points: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var arc := PackedFloat32Array()
	var seg := PackedInt32Array()
	var run := 0.0
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		var na: Vector2 = face[i] if i == 0 else (face[i - 1] + face[i]).normalized()
		var nb: Vector2 = face[i] if i == face.size() - 1 else (face[i] + face[i + 1]).normalized()
		var n := maxi(1, ceili(a.distance_to(b) / 0.12))
		for j in n:
			var t := float(j) / n
			points.append(a.lerp(b, t))
			normals.append(na.lerp(nb, t).normalized())
			arc.append(run + a.distance_to(b) * t)
			seg.append(i)
		run += a.distance_to(b)
	points.append(profile[profile.size() - 1])
	normals.append(face[face.size() - 1])
	arc.append(run)
	seg.append(face.size() - 1)
	return [points, normals, arc, seg, face]


## The tilt's meshes, cached by section, bows and lie: [[mesh, bay, width]...]
## (width 0 the left curtain, 1 the roof, 2 the right), the bound hems, the
## lacing cord.
static func _tilt_meshes(profile: Array, bows: Array, variant: int) -> Array:
	var key := "%s|%s|%d" % [str(profile), str(bows), variant]
	if _tilts.has(key):
		return _tilts[key]
	var section := _tilt_section(profile)
	var points: Array[Vector2] = section[0]
	var normals: Array[Vector2] = section[1]
	var arc: PackedFloat32Array = section[2]
	var seg: PackedInt32Array = section[3]
	var face: Array[Vector2] = section[4]
	var total: float = arc[arc.size() - 1]
	var phase := float(variant) * 2.1
	# Lengthwise: each bay's ends at its bows, a row 5 cm in from each so the
	# bow's ridge reads sharp, and rows about every 14 cm between.
	var zs := PackedFloat32Array()
	var bay_of := PackedInt32Array()
	var us := PackedFloat32Array()
	for bay in bows.size() - 1:
		var z0: float = bows[bay]
		var z1: float = bows[bay + 1]
		var length := z1 - z0
		var cuts: Array[float] = [0.0]
		if length > 0.3:
			var inner := maxi(1, ceili((length - 0.1) / 0.14))
			cuts.append(0.05 / length)
			for j in range(1, inner):
				cuts.append(lerpf(0.05 / length, 1.0 - 0.05 / length, float(j) / inner))
			cuts.append(1.0 - 0.05 / length)
		for u: float in cuts:
			zs.append(z0 + u * length)
			bay_of.append(bay)
			us.append(u)
	# (the last bow's row closes the last bay)
	zs.append(float(bows[bows.size() - 1]))
	bay_of.append(bows.size() - 1)
	us.append(1.0)
	# The cloth's place at every sample.
	var rows := zs.size()
	var cols := points.size()
	var grid := PackedVector3Array()
	grid.resize(rows * cols)
	for r in rows:
		var bay := mini(bay_of[r], bows.size() - 2)
		var length: float = float(bows[bay + 1]) - float(bows[bay])
		var u := us[r]
		var z := zs[r]
		var bell := pow(sin(PI * u), 0.55)
		# lacing eyes at the bows and evenly between them
		var eyes := maxi(1, roundi(length / 0.45))
		var v := fposmod(u * eyes, 1.0)
		for q in cols:
			var p := points[q]
			var n := normals[q]
			var h := minf(arc[q], total - arc[q])
			var up := clampf(n.y, 0.0, 1.0)
			var hold := smoothstep(0.0, 0.3, h)
			# The cover sags between its bows: most across the middle of the
			# roof, a little on the sides, nothing at the laced hem; deep
			# enough on the roof that each bow throws a shadow line seen from
			# above.
			var sag := minf(0.075, 0.048 * length) * bell * (0.4 + 0.6 * up) * (0.7 + 0.3 * sin(PI * arc[q] / total)) * hold
			# Pulled in at each eye and bellied out between them, the hem
			# lifting a little between its eyes.
			var belly := 0.013 * sin(PI * v) * (1.0 - smoothstep(0.05, 0.5, h)) * smoothstep(0.0, 0.06, h)
			var lift := 0.012 * sin(PI * v) * (1.0 - smoothstep(0.0, 0.14, h))
			# where it was folded in its bundle, faint creases that pull
			# out over the bows, and the side curtains hanging in soft
			# upright folds
			var crease := sin(z * 6.1 + arc[q] * 3.7 + phase) * sin(z * 2.3 - arc[q] * 7.9 + phase * 1.7) * 0.009 * bell * hold
			crease += sin(z * 8.3 + phase * 2.9 + arc[q] * 1.1) * 0.007 * (1.0 - up) * bell * hold
			var out := belly + crease - sag
			grid[r * cols + q] = Vector3(p.x + n.x * out, p.y + n.y * out + lift, z)
	# Normals from the cloth's own shape, so the widths shade as one cover.
	var shade := PackedVector3Array()
	shade.resize(rows * cols)
	for r in rows:
		for q in cols:
			var ts := grid[r * cols + mini(q + 1, cols - 1)] - grid[r * cols + maxi(q - 1, 0)]
			var tz := grid[mini(r + 1, rows - 1) * cols + q] - grid[maxi(r - 1, 0) * cols + q]
			var n := ts.cross(tz).normalized()
			if n.dot(Vector3(normals[q].x, normals[q].y, 0)) < 0.0:
				n = -n
			shade[r * cols + q] = n
	# One mesh per width of each bay, its UVs spanning the width so the
	# stitching runs round it.
	var parts: Array = []
	for bay in bows.size() - 1:
		var r0 := bay_of.find(bay)
		var r1 := r0
		while r1 + 1 < rows and bay_of[r1 + 1] == bay:
			r1 += 1
		r1 += 1  # (the next bay's first row is this one's last)
		for width in 3:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var uvs := PackedVector2Array()
			var qs: Array[int] = []
			for q in cols - 1:
				var f: Vector2 = face[seg[q]]
				var w := 1 if absf(f.y) >= 0.5 else (0 if points[q].x < 0.0 else 2)
				if w == width:
					qs.append(q)
			if qs.is_empty():
				continue
			var a0: float = arc[qs[0]]
			var a1: float = arc[qs[qs.size() - 1] + 1]
			var z0: float = zs[r0]
			var z1: float = zs[r1]
			for r in range(r0, r1):
				for q: int in qs:
					# (corners as the section sample each lies on, then the grid
					# index: no integer division where a worker builds this)
					var along: Array[int] = [q, q + 1, q + 1, q]
					var quad: Array[int] = [r * cols + q, r * cols + q + 1, (r + 1) * cols + q + 1, (r + 1) * cols + q]
					for tri: Array in [[0, 1, 2], [0, 2, 3]]:
						var order: Array[int] = [tri[0], tri[1], tri[2]]
						var a: int = quad[order[0]]
						var b: int = quad[order[1]]
						var c: int = quad[order[2]]
						if (grid[a] - grid[c]).cross(grid[a] - grid[b]).dot(shade[a] + shade[b] + shade[c]) < 0.0:
							order = [order[0], order[2], order[1]]
						for corner: int in order:
							var i := quad[corner]
							verts.append(grid[i])
							norms.append(shade[i])
							uvs.append(Vector2((grid[i].z - z0) / maxf(z1 - z0, 0.001), (arc[along[corner]] - a0) / maxf(a1 - a0, 0.001)))
			parts.append([_arrays_mesh(verts, norms, uvs), bay, width])
	# Where each side curtain meets the roof (a rolled curtain is strapped
	# up there).
	var first_roof := -1
	var last_roof := -1
	for q in cols - 1:
		if absf(face[seg[q]].y) >= 0.5:
			if first_roof < 0:
				first_roof = q
			last_roof = q + 1
	# The bound hem along each side's foot and the cord laced from eye to
	# hook: down to a hook on the bed 7 cm under the hem halfway between two
	# eyes, and up to the next.
	var hems: Array[ArrayMesh] = []
	var cords: Array[ArrayMesh] = []
	for q: int in [0, cols - 1]:
		var hem_v := PackedVector3Array()
		var hem_n := PackedVector3Array()
		var cord_v := PackedVector3Array()
		var cord_n := PackedVector3Array()
		var out := Vector3(normals[q].x, normals[q].y, 0)
		var line := PackedVector3Array()
		for r in rows:
			line.append(grid[r * cols + q] + out * 0.004 + Vector3(0, 0.012, 0))
		_cord(line, 0.011, 4, hem_v, hem_n)
		# The seam where the curtain is sewn to the roof, bound over the eave
		# in a doubled band 6 cm wide that road grime and the rain's run-off
		# darken, so from above the roof's edge reads as a line (it goes with
		# its curtain: a rolled curtain's eave is under its roll).
		var eq := first_roof if q == 0 else last_roof
		if eq > 0 and eq < cols - 1:
			var lo := PackedVector3Array()
			var mid := PackedVector3Array()
			var hi := PackedVector3Array()
			var ns := PackedVector3Array()
			for r in rows:
				var c := grid[r * cols + eq]
				var a := grid[r * cols + eq - 1]
				var b := grid[r * cols + eq + 1]
				var n := shade[r * cols + eq]
				lo.append(c.lerp(a, minf(0.5, 0.03 / maxf(c.distance_to(a), 0.001))) + n * 0.004)
				mid.append(c + n * 0.005)
				hi.append(c.lerp(b, minf(0.5, 0.03 / maxf(c.distance_to(b), 0.001))) + n * 0.004)
				ns.append(n)
			_strip(lo, mid, ns, hem_v, hem_n)
			_strip(mid, hi, ns, hem_v, hem_n)
		var lace := PackedVector3Array()
		for bay in bows.size() - 1:
			var z0: float = bows[bay]
			var length: float = float(bows[bay + 1]) - z0
			var eyes := maxi(1, roundi(length / 0.45))
			for e in eyes:
				var at := z0 + length * float(e) / eyes
				lace.append(Vector3(points[q].x, points[q].y + 0.022, at) + out * 0.012)
				# (a hem's end round the end bow runs straight on to the first eye)
				if length > 0.3:
					lace.append(Vector3(points[q].x, points[q].y - 0.07, at + length * 0.5 / eyes) + out * 0.014)
		lace.append(Vector3(points[q].x, points[q].y + 0.022, float(bows[bows.size() - 1])) + out * 0.012)
		_cord(lace, 0.006, 3, cord_v, cord_n)
		hems.append(_arrays_mesh(hem_v, hem_n, PackedVector2Array()))
		cords.append(_arrays_mesh(cord_v, cord_n, PackedVector2Array()))
	# The eaves, and the cover's inside: the section 8 cm in (deeper than the
	# cloth sags between its bows, so no edge of it shows past the eaves from
	# outside), facing in, one mesh for each width.
	var eaves: Array[Vector3] = []
	var liners: Array[ArrayMesh] = []
	for q: int in [maxi(first_roof, 0), maxi(last_roof, 0)]:
		eaves.append(Vector3(points[q].x, points[q].y, normals[q].x))
	for width in 3:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		for i in profile.size() - 1:
			var f := face[i]
			var mid: float = (profile[i] as Vector2).x + (profile[i + 1] as Vector2).x
			var w := 1 if absf(f.y) >= 0.5 else (0 if mid < 0.0 else 2)
			if w != width:
				continue
			var a: Vector2 = (profile[i] as Vector2) - f * 0.08
			var b: Vector2 = (profile[i + 1] as Vector2) - f * 0.08
			var z0: float = float(bows[0]) + 0.02
			var z1: float = float(bows[bows.size() - 1]) - 0.02
			var corners: Array[Vector3] = [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)]
			var inward := Vector3(-f.x, -f.y, 0)
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var p0 := corners[tri[0]]
				var p1 := corners[tri[1]]
				var p2 := corners[tri[2]]
				if (p0 - p2).cross(p0 - p1).dot(inward) < 0.0:
					var swap := p1
					p1 = p2
					p2 = swap
				for p: Vector3 in [p0, p1, p2]:
					verts.append(p)
					norms.append(inward)
		if width == 1:
			# The front panel's inside too, with the roof's (always built):
			# looking in past the open back, the far end of a covered bed is
			# the dimmest thing in it, the cloth seen from the shade under the
			# cover, not the cover's sunlit drab. The section 3 cm in, just
			# behind the panel, fanned from the middle of its foot.
			var z := float(bows[0]) + 0.02
			var outline: Array[Vector3] = []
			for i in profile.size():
				var n: Vector2 = face[0] if i == 0 else (face[face.size() - 1] if i == face.size() else (face[i - 1] + face[i]).normalized())
				var p: Vector2 = (profile[i] as Vector2) - n * 0.03
				outline.append(Vector3(p.x, p.y, z))
			var foot := (outline[0] + outline[outline.size() - 1]) * 0.5
			for i in outline.size() - 1:
				var p0 := foot
				var p1 := outline[i]
				var p2 := outline[i + 1]
				if (p0 - p2).cross(p0 - p1).dot(Vector3.BACK) < 0.0:
					var swap := p1
					p1 = p2
					p2 = swap
				for p: Vector3 in [p0, p1, p2]:
					verts.append(p)
					norms.append(Vector3.BACK)
		liners.append(_arrays_mesh(verts, norms, PackedVector2Array()))
	# The cover's two ends bound in a doubled hem 3 cm deep over the end bows
	# (seen from behind it's the edge of a cover, not of a sheet of paper),
	# and a chafing strip 5 cm wide sewn over every bow between them across
	# the roof, where the cloth wears on the bow: grime works into the doubled
	# cloth, so from the battle camera the strips rule the roof off bay by bay.
	var trim_v := PackedVector3Array()
	var trim_n := PackedVector3Array()
	for r: int in [0, rows - 1]:
		var line := PackedVector3Array()
		var inward := 0.008 if r == 0 else -0.008
		for q in cols:
			line.append(grid[r * cols + q] + Vector3(0, 0, inward))
		_cord(line, 0.018, 4, trim_v, trim_n)
	if first_roof >= 0:
		for r in range(1, rows - 1):
			if us[r] != 0.0:
				continue
			var ta := minf(0.5, 0.025 / maxf(zs[r] - zs[r - 1], 0.001))
			var tb := minf(0.5, 0.025 / maxf(zs[r + 1] - zs[r], 0.001))
			var la := PackedVector3Array()
			var lm := PackedVector3Array()
			var lb := PackedVector3Array()
			var ns := PackedVector3Array()
			for q in range(first_roof, last_roof + 1):
				var c := grid[r * cols + q]
				var n := shade[r * cols + q]
				la.append(c.lerp(grid[(r - 1) * cols + q], ta) + n * 0.004)
				lm.append(c + n * 0.005)
				lb.append(c.lerp(grid[(r + 1) * cols + q], tb) + n * 0.004)
				ns.append(n)
			_strip(la, lm, ns, trim_v, trim_n)
			_strip(lm, lb, ns, trim_v, trim_n)
	var result := [parts, hems, cords, eaves, liners, _arrays_mesh(trim_v, trim_n, PackedVector2Array())]
	_tilts[key] = result
	return result


## A cord through `points`: a thin prism of `sides` faces along each leg.
static func _cord(points: PackedVector3Array, radius: float, sides: int, verts: PackedVector3Array, norms: PackedVector3Array) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var lift := side.cross(axis)
		for j in sides:
			var t0 := TAU * float(j) / sides
			var t1 := TAU * float(j + 1) / sides
			var d0 := side * cos(t0) + lift * sin(t0)
			var d1 := side * cos(t1) + lift * sin(t1)
			for tri: Array in [[a + d0 * radius, b + d0 * radius, b + d1 * radius, d0, d0, d1], [a + d0 * radius, b + d1 * radius, a + d1 * radius, d0, d1, d1]]:
				var order: Array[int] = [0, 1, 2]
				if ((tri[0] as Vector3) - (tri[2] as Vector3)).cross((tri[0] as Vector3) - (tri[1] as Vector3)).dot(d0 + d1) < 0.0:
					order = [0, 2, 1]
				for c: int in order:
					verts.append(tri[c])
					norms.append(tri[c + 3])


## A band laid on the cloth between two lines of as many points, `normals`
## (one a point of `a`, shared by `b`'s) its outward face.
static func _strip(a: PackedVector3Array, b: PackedVector3Array, normals: PackedVector3Array, verts: PackedVector3Array, norms: PackedVector3Array) -> void:
	for i in a.size() - 1:
		var quad: Array[Vector3] = [a[i], a[i + 1], b[i + 1], b[i]]
		var qn: Array[Vector3] = [normals[i], normals[i + 1], normals[i + 1], normals[i]]
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			var order: Array[int] = [tri[0], tri[1], tri[2]]
			if (quad[order[0]] - quad[order[2]]).cross(quad[order[0]] - quad[order[1]]).dot(qn[order[0]]) < 0.0:
				order = [order[0], order[2], order[1]]
			for c: int in order:
				verts.append(quad[c])
				norms.append(qn[c])


static func _arrays_mesh(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	if uvs.size() == verts.size() and not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(mesh, arrays)
	return mesh


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
		# Kit comes in whatever its owner was issued or bought: old cotton
		# duck, newer nylon (Cordura) and, black, a rubberised dry bag. (A
		# wreck's straps lie as they did: its cloth burnt away.)
		var lidded := false
		var weave := 1.0
		if not k.wreck:
			lidded = rng.randf() < 0.5
			weave = rng.randf()
		var cloth := material
		if material == "canvas" and tint is Color:
			var c: Color = tint
			if c.s < 0.2 and c.v < 0.2 and weave < 0.5:
				cloth = "boot"
			elif weave < 0.5:
				cloth = "fabric"
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
			# its length on its floor, resting on its cloth (its straps bite
			# into it), its buckles up and a little round.
			var r := across * 0.5 / 1.035 * full
			var lie := Basis(Vector3.BACK, PI / 2) if long_x else Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.UP, PI / 2)
			var roll_mount := k._pivot(parent, center + basis * Vector3(mid if long_x else 0.0, -size.y * 0.5 + r * (1.035 if k.wreck else 1.0), 0.0 if long_x else mid))
			roll_mount.basis = basis * lie * Basis(Vector3.UP, turn * 0.7)
			_roll(k, roll_mount, r, (b - a) * fill, tint, "fabric" if cloth == "fabric" else material, Vector2(-0.3, 0.3) + Vector2(strap, strap) * 0.3)
			continue
		var scale := Vector3(fill, full, fill)
		# Each bag lies along its place's length (its X), so its strap is
		# cinched across it and a duffel's ends are the place's ends.
		var yaw := Basis.IDENTITY if long_x or k.wreck else Basis(Vector3.UP, PI / 2)
		if not long_x and not k.wreck:
			place = Vector3(place.z, place.y, place.x)
		# (its front, where a rucksack's straps buckle, faces out from the
		# vehicle, not into the wall it's stowed against)
		var front := basis * yaw * Vector3.BACK
		if not k.wreck and front.x * center.x + front.z * center.z < 0.0:
			yaw = yaw * Basis(Vector3.UP, PI)
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
		foot -= yaw * Vector3(pocket * depth * 0.5, 0, 0)
		var mount := k._pivot(parent, center + basis * foot)
		mount.basis = basis * yaw * spin
		# (a rucksack: a bag standing about as wide as deep, tall enough
		# for its lid)
		var shape := Vector3(body, place.y, place.z)
		var lid := lidded and not _duffel(shape) and place.y >= 0.22 and maxf(body, place.z) <= 1.5 * minf(body, place.z)
		var part: Variant = _bag(k, mount, shape, scale, cloth, tint, shadow, strap, Vector3(pocket * depth, 0, 0), lid)
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
static func _bag(k: VehicleModels, mount: Node3D, place: Vector3, scale: Vector3, material: String, col, shadow: bool, strap_at := 0.0, pocket := Vector3.ZERO, lid := false) -> Variant:
	var size := place * scale
	var part: Variant = k._add(mount, _shell(place), material, col, Vector3.ZERO, Vector3.ZERO, scale, shadow)
	if pocket.x != 0.0:
		var p := Vector3(absf(pocket.x), size.y * 0.5, size.z * 0.6)
		# (into the bag's face 4 mm, so no seam of light shows round it)
		var at := Vector3(signf(pocket.x) * (size.x * 0.5 + p.x * 0.5 - 0.004), -size.y * 0.03, 0)
		k._add(mount, _shell(p.snappedf(0.005)), material, col.darkened(0.06) if col is Color else col, at, Vector3.ZERO, Vector3.ONE, shadow)
	var seam_col: Color = col.darkened(0.18) if col is Color else Color(0.23, 0.24, 0.17)
	var h := place * 0.5
	if k.wreck:
		# A wreck's cloth burnt away, its webbing strap and buckle left lying
		# where they were cinched, as they always lay.
		var inset := minf(size.y, minf(size.x, size.z)) * 0.20
		var sx0 := strap_at * size.x
		var old := [Vector3(sx0, -size.y / 2 + inset, -size.z / 2 - 0.008), Vector3(sx0, size.y / 2 - inset, -size.z / 2 - 0.008), Vector3(sx0, size.y / 2 + 0.008, -size.z / 2 + inset), Vector3(sx0, size.y / 2 + 0.008, size.z / 2 - inset), Vector3(sx0, size.y / 2 - inset, size.z / 2 + 0.008)]
		for i in old.size() - 1:
			var a: Vector3 = old[i]
			var b: Vector3 = old[i + 1]
			var y := (b - a).normalized()
			var z := (Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).cross(y).normalized()
			k._add(mount, VehicleEquipment._plate(Vector3(minf(0.045, size.x * 0.15), a.distance_to(b), 0.012)), "webbing", seam_col, (a + b) * 0.5, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)
		k._add(mount, VehicleEquipment._plate(Vector3(0.065, 0.018, 0.055)), "gunmetal", Color(0.22, 0.23, 0.21), Vector3(sx0, size.y / 2 + 0.018, 0), Vector3.ZERO, Vector3.ONE, false)
		k._fold(mount)
		return part
	if lid:
		_lid(k, mount, place, scale, material, col, seam_col, shadow)
		k._fold(mount)
		return part
	if _duffel(place):
		# A duffel is a tube of cloth with a round panel sewn in each end
		# (seamed by its UVs, as every edge is) and no welt round its
		# middle; its mouth at one end is gathered shut on a drawstring,
		# the cord's knot and tail hanging from the gather.
		var end := _soft(Vector3(h.x, (_round(place).y - _round(place).z) * 0.5, 0), place) * scale
		var gather := minf(place.y, place.z) * 0.16
		k._add(mount, VehicleFittings._ring(gather * 0.45, gather), material, seam_col, end - Vector3(0.006, 0, 0), Vector3(0, 0, PI / 2), Vector3.ONE, false)
		VehicleEquipment._rod(k, mount, end + Vector3(0.004, -gather * 0.8, 0), end + Vector3(0.012, -gather * 0.8 - 0.07, 0.02), 0.005, material, seam_col.darkened(0.1), 4, false, 2)
	else:
		# The welt runs round the bag's middle in the seam, following its
		# rounded corners and bellied faces (scaled with the shell, so it
		# stays on it).
		k._add(mount, _welt(place), material, seam_col, Vector3.ZERO, Vector3.ZERO, scale, false)
	# The narrow strap is cinched round the bag, so it lies on the cloth and
	# bites into it (half its thickness sunk), over the rounded top edges
	# and down both faces, never registering a pivot. Webbing and buckle are
	# thin: plain bands, laid level as a level beam lies.
	var round := _round(place)
	var r := round.x
	var sx := strap_at * place.x
	var top := h.y - round.z
	var raw := [Vector3(sx, -h.y + round.y * 2.0, -h.z), Vector3(sx, top, -h.z), Vector3(sx, top + round.z, r - h.z - r), Vector3(sx, h.y, r - h.z), Vector3(sx, h.y, h.z - r), Vector3(sx, top + round.z, h.z), Vector3(sx, top, h.z)]
	var strap: Array[Vector3] = []
	for p: Vector3 in raw:
		strap.append(_soft(p, place) * scale)
	for i in strap.size() - 1:
		var a: Vector3 = strap[i]
		var b: Vector3 = strap[i + 1]
		var y := (b - a).normalized()
		var z := (Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).cross(y).normalized()
		var mid := (a + b) * 0.5
		if z.dot(Vector3(0, mid.y + h.y * 0.3, mid.z)) < 0.0:
			z = -z
		k._add(mount, VehicleEquipment._plate(Vector3(minf(0.045, size.x * 0.15), a.distance_to(b) + 0.004, 0.012)), "webbing", seam_col, mid + z * 0.002, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)
	# The buckle on the bag's top is a black acetal side-release buckle, as
	# on all issue and bought kit since the seventies, moulded with a dull
	# satin face like the webbing's: a steel plate there mirrored the sky,
	# a pale label on every bag's lid from above.
	k._add(mount, VehicleEquipment._plate(Vector3(0.065, 0.018, 0.055)), "webbing", BUCKLE, _soft(Vector3(sx, h.y, 0), place) * scale + Vector3(0, 0.009, 0), Vector3.ZERO, Vector3.ONE, false)
	k._fold(mount)
	return part


## A rucksack's lid on the bag shell `place` (made `scale` of it, as the
## shell is): a flatter shell of its own buckled down over the bag's settled
## top, wider than it and hanging over its front (+Z) a little, and two
## compression straps from under the lid's front edge down the front face to
## their buckles, where a rucksack is cinched shut. Its welt is the lid's own
## edge, so it has none round its middle.
static func _lid(k: VehicleModels, mount: Node3D, place: Vector3, scale: Vector3, material: String, col, seam_col: Color, shadow: bool) -> void:
	var h := place * 0.5
	var size := place * scale
	var cover := Vector3(place.x * 0.97, maxf(0.05, place.y * 0.3), place.z * 0.98).snappedf(0.01)
	var top := _soft(Vector3(0, h.y, 0), place).y
	k._add(mount, _shell(cover), material, col.darkened(0.05) if col is Color else col, Vector3(0, top - cover.y * 0.5 + 0.006, place.z * 0.01) * scale, Vector3.ZERO, scale, shadow)
	for side: float in [-1.0, 1.0]:
		var x := side * place.x * 0.26
		var a := _soft(Vector3(x, top - cover.y * 0.85, h.z), place) * scale
		var b := _soft(Vector3(x, -h.y * 0.25, h.z), place) * scale
		var y := (b - a).normalized()
		var z := Vector3.RIGHT.cross(y).normalized()
		if z.z < 0.0:
			z = -z
		k._add(mount, VehicleEquipment._plate(Vector3(minf(0.035, size.x * 0.12), a.distance_to(b), 0.01)), "webbing", seam_col, (a + b) * 0.5 + z * 0.002, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)
		k._add(mount, VehicleEquipment._plate(Vector3(minf(0.045, size.x * 0.15), 0.03, 0.012)), "webbing", BUCKLE, b + z * 0.005, Basis(y.cross(z), y, z).get_euler(), Vector3.ONE, false)


## Woven webbing laid along `points` (in `parent`'s coordinates): one flat
## band per leg, `width` across (along `across`, which a strap wrapped round a
## load keeps all the way round) and `thick` through, each running on into the
## next by its own thickness, so the strap folds over an edge instead of
## standing off it with daylight under the turn. Load, cam and ratchet straps,
## slings and the bands round a roll are 25 to 50 mm webbing a few millimetres
## thick: thinner than a shadow resolves, so none casts one. Sizes are rounded
## to the millimetre, so a roster of loads shares few cached bands.
static func strap(k: VehicleModels, parent: Node3D, points: Array, width: float, col: Color, across := Vector3.BACK, thick := 0.004, material := "webbing") -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.002:
			continue
		var y := (b - a) / length
		var x := across - y * across.dot(y)
		if x.length_squared() < 0.000001:
			x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT)
		x = x.normalized()
		var size := Vector3(width, length + thick, thick).snappedf(0.001)
		k._add(parent, VehicleEquipment._plate(size), material, col, (a + b) * 0.5, Basis(x, y, x.cross(y)).get_euler(), Vector3.ONE, false)


## A light vehicle's harness webbing: black, as the issue four-point belts are.
const HARNESS := Color(0.07, 0.07, 0.065)
## A kit bag's moulded plastic buckles: black acetal.
const BUCKLE := Color(0.075, 0.075, 0.07)

## The four-point harness of an open light vehicle's crew seat (a Prowler's,
## a Qilin's), left lying in the empty seat as the crew climbed out of it:
## two shoulder belts out of their slots in the seat back, down its face and
## across the cushion, and the two halves of the lap belt in from the
## cushion's sides, all four meeting in the buckle's pressed steel plate at
## the cushion's front. From above, an open buggy's seats are the most visible
## thing in it, and the belts and their buckle read them as seats a crew
## is strapped into over rough ground, not as padded boards. `center`, `size`
## and `rotation` are the seat's own, as VehicleCab.seat takes them (its
## cushion centre, width, back height and depth; its front is local -Z).
## Wrecks and burnt hulks keep their bare seats.
static func harness(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, rotation: Vector3, col := HARNESS) -> void:
	if k.wreck or k.burnt:
		return
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	# (the seat's cushion and leaning back as VehicleCab.seat builds them,
	# each belt laid 3 mm proud of the cloth it lies on)
	var pad := minf(0.12, size.z * 0.24)
	var back := Vector3(0, size.y * 0.5, size.z * 0.46)
	var lean := Basis(Vector3.RIGHT, 0.12)
	var face := -(pad * 0.4 + 0.003)
	var top := pad * 0.5 + 0.003
	var buckle := Vector3(0, top + 0.002, -size.z * 0.12)
	for side: float in [-1.0, 1.0]:
		var shoulder := [back + lean * Vector3(side * 0.075, size.y * 0.36, face), back + lean * Vector3(side * 0.065, -size.y * 0.3, face), Vector3(side * 0.055, top, size.z * 0.2), buckle + Vector3(side * 0.02, 0, 0.03)]
		strap(k, mount, shoulder, 0.045, col, Vector3.RIGHT)
		strap(k, mount, [Vector3(side * size.x * 0.34, top, size.z * 0.24), buckle + Vector3(side * 0.03, 0, 0)], 0.045, col, Vector3.BACK)
	# (the buckle a rotary cam-lock in a black anodised housing: bright
	# steel glared from above as a lamp, and even blackened steel, flat and
	# level in a seat, gave the sky back as a pale square on every cushion,
	# where the anodised face is as dull as the belts round it)
	k._box(mount, Vector3(0.05, 0.008, 0.06), buckle + Vector3(0, 0.003, 0), "webbing", BUCKLE, Vector3.ZERO, false)
	k._fold(mount)


## A ratchet tensioner on a load strap: `at` its middle on the strap's face,
## `out` the way it faces (off the load), `up` along the strap toward the
## load's top. Its pressed steel frame straddles the webbing, the handle folded
## down flat over it with its grip end lifted a finger off, the spool across
## the frame's cheeks fat with the strap wound onto it, and the loose tail
## hanging out below, as a crew leaves it once the load is cinched down.
## `metal` its plating: bright zinc on a civilian's, black or olive on issue
## straps. Stands 3.5 cm off the strap and 0.07 m above and below `at` (and
## the tail `tail` below that).
static func ratchet(k: VehicleModels, parent: Node3D, at: Vector3, out: Vector3, up: Vector3, width: float, col: Color, metal: Color, tail := 0.16) -> void:
	var u := up.normalized()
	var o := (out - u * out.dot(u)).normalized()
	var basis := Basis(u.cross(o), u, o)
	var rot := basis.get_euler()
	var w := snappedf(width, 0.005)
	for e: float in [-1.0, 1.0]:
		k._add(parent, VehicleEquipment._plate(Vector3(0.005, 0.11, 0.026)), "steel", metal, at + basis * Vector3(e * (w * 0.5 + 0.004), 0.0, 0.013), rot, Vector3.ONE, false)
	k._add(parent, VehicleEquipment._plate(Vector3(w + 0.014, 0.13, 0.004)), "steel", metal, at + basis * Vector3(0, -0.012, 0.03), (basis * Basis(Vector3.RIGHT, -0.1)).get_euler(), Vector3.ONE, false)
	VehicleEquipment._rod(k, parent, at + basis * Vector3(-w * 0.5, 0.035, 0.013), at + basis * Vector3(w * 0.5, 0.035, 0.013), 0.013, "webbing", col.darkened(0.12), 8, false, 3)
	strap(k, parent, [at + basis * Vector3(0, -0.045, 0.02), at + basis * Vector3(0, -0.045 - tail * 0.55, 0.03), at + basis * Vector3(0, -0.045 - tail, 0.022)], w * 0.95, col, basis.x)


## A rope lashing laid along `points`, a length of it per leg, `radius` thick
## (a lashing's 12 mm line is 0.006), each leg capped so a turn closes. Rope
## takes the "rope" finish: hairy laid fibre, coarser than any cloth. `knots`
## are indices into `points` where a knot sits (the trucker's hitch a lashing
## is drawn tight with, the half hitches at a ring): a lump of the rope's own
## fibre, a shade darker where it is handled.
static func rope(k: VehicleModels, parent: Node3D, points: Array, radius: float, col: Color, knots: Array = []) -> void:
	var r := snappedf(radius, 0.001)
	for i in points.size() - 1:
		VehicleEquipment._rod(k, parent, points[i], points[i + 1], r, "rope", col, 5, false, 3)
	for i: int in knots:
		k._add(parent, Res.sphere(r * 2.2, 6), "rope", col.darkened(0.1), points[i], Vector3.ZERO, Vector3(1.0, 1.5, 1.0), false)


## A filled sandbag's size once it has settled: the standard 14 by 26 inch
## sack holds about 15 kg of earth and lies some 0.5 m long, 0.28 wide and
## 0.14 high, its faces bellied out and its top pressed flat.
const SACK := Vector3(0.5, 0.14, 0.28)
## Sacks as irregulars find them: hessian (jute, the old issue: brown, hairy,
## dead matte) and woven polypropylene (the builders' merchant's plastic sack:
## off-white, olive or sand, finer). Both are woven and read matt at any
## distance. (Jute is a greyish brown: any more chroma and the game's warm sun
## turns a wall of them into orange loaves, the warmest thing on the vehicle.
## A white sack is grey with the earth it was filled with and the hands that
## carried it: at the clean white of a new one, a wall of them was the
## brightest thing on a truck's cab.)
const SACK_HESSIAN: Array[Color] = [Color(0.44, 0.38, 0.28), Color(0.39, 0.34, 0.25), Color(0.50, 0.44, 0.33)]
const SACK_POLY: Array[Color] = [Color(0.52, 0.5, 0.45), Color(0.36, 0.37, 0.27), Color(0.5, 0.47, 0.38), Color(0.31, 0.33, 0.25)]
## Earth rubbed into a sack that has been filled, carried and sat on.
const SACK_EARTH := Color(0.34, 0.29, 0.21)


## The sacks one crew filled its sandbags from: [poly, colour], hessian or
## plastic and the lot's colour, the same for every sandbag on the vehicle
## (drawn from the kit seed). Empty for a wreck or for scenery, which carry
## none: a wreck's sacks have split and spilt, and scenery keeps one look.
static func sack_lot(k: VehicleModels) -> Array:
	var rng := VehicleCargo.kit(k, k.root, Vector3.ZERO, 41)
	if rng == null or k.wreck:
		return []
	var poly := rng.randf() < 0.55
	var palette := SACK_POLY if poly else SACK_HESSIAN
	return [poly, palette[rng.randi_range(0, palette.size() - 1)]]


## One sandbag (see SACK), its base's middle at `foot` on what carries it,
## lying along `along` with its mouth that way, from the crew's `lot`
## (sack_lot; empty: none). Each is turned, filled and settled its own way,
## a few from another lot (a crew fills what sacks it finds), the earth rubbed
## into it; `drape` where it lies over a rail narrower than itself, its sides
## hanging down either side of it. Four cached sacks (the mouth tied off or
## folded under, slumped toward either end) and their draped twins, scaled
## in a few steps, so a roster of sandbags bakes eight small meshes.
static func sandbag(k: VehicleModels, parent: Node3D, foot: Vector3, along: Vector3, rng: RandomNumberGenerator, lot: Array, drape := false, length := 1.0) -> void:
	if lot.is_empty() or k.wreck or k.kit_seed < 0:
		return
	var poly: bool = lot[0]
	var col: Color = lot[1]
	if rng.randf() < 0.18:
		poly = not poly
		var palette := SACK_POLY if poly else SACK_HESSIAN
		col = palette[rng.randi_range(0, palette.size() - 1)]
	var shade := rng.randf_range(-0.06, 0.06)
	col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
	col = col.lerp(SACK_EARTH, rng.randf_range(0.05, 0.3) if not poly else rng.randf_range(0.08, 0.25))
	var variant := rng.randi_range(0, 3) + (4 if drape else 0)
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	var yaw := atan2(-flat.z, flat.x) + rng.randf_range(-0.12, 0.12)
	var fill := snappedf(rng.randf_range(0.88, 1.06), 0.06)
	var scale := Vector3(snappedf(length, 0.05), fill, snappedf(rng.randf_range(0.92, 1.04), 0.06))
	var tilt := Vector3(rng.randf_range(-0.05, 0.05), yaw, rng.randf_range(-0.03, 0.03))
	k._add(parent, _sack(variant), "canvas", col, foot, tilt, scale)


## A wall of sandbags along a line of support from `a` to `b` (each a point
## on what carries them, under the wall's middle): sacks laid end to end
## along it and pressed together, `courses` high, each course set half a sack
## along on the one under it and nested into its grooves, as a sandbag wall
## is laid so no joint runs straight through it; an upper course one sack
## shorter, its ends stepped in. Mouths are turned in or out at random, as
## the sacks were thrown up. `drape` the bottom course over a rail.
static func sandbags(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, rng: RandomNumberGenerator, lot: Array, courses := 1, drape := false) -> void:
	if lot.is_empty() or rng == null:
		return
	var run := b - a
	var count := maxi(1, roundi(run.length() / (SACK.x * 0.88)))
	var step := run / count
	var length := clampf(step.length() / (SACK.x * 0.88), 0.8, 1.15)
	for course in courses:
		var n := count - course
		if n < 1:
			break
		for i in n:
			var at := a + step * (float(i) + 0.5 + 0.5 * float(course)) + Vector3(0, course * SACK.y * 0.78, 0)
			var mouth := 1.0 if rng.randf() < 0.5 else -1.0
			sandbag(k, parent, at, run * mouth, rng, lot, drape and course == 0, length)


static var _sacks := {}

## A filled sack lying along X on its base (y 0), SACK its size, `variant`'s
## bits: 1 its mouth (+X) tied off with an ear of cloth past the tie (else
## folded flat under it), 2 slumped toward the mouth (else toward the closed
## end), 4 draped over a rail (its sides hanging 5 cm either side of the
## middle). Rings along its length are rounded rectangles, fullest at mid
## length and closing to a rounded end, the base flatter than the top; small
## lumps of the fill push the cloth about. The cloth's UVs end along the
## base's edges, where the canvas finish sews the sack's seams. About 80
## triangles a sack.
static func _sack(variant: int) -> ArrayMesh:
	if _sacks.has(variant):
		return _sacks[variant]
	var tied := variant & 1 != 0
	var slump := 1.0 if variant & 2 != 0 else -1.0
	var draped := variant & 4 != 0
	var h := SACK * 0.5
	var base := SACK.y * 0.3
	var top := SACK.y - base
	# (t along the length from the closed end, its width and height shares,
	# its middle's height as a share of the sack's)
	var rings: Array[Vector4] = []
	for t: float in [-1.0, -0.88, -0.55, 0.45]:
		var p := pow(1.0 - pow(absf(t), 4.0), 0.25)
		rings.append(Vector4(t, p, p, lerpf(0.45, 0.3, p)))
	if tied:
		# gathered to the tie, the ear of cloth past it flattened
		rings.append_array([Vector4(0.7, 0.8, 0.78, 0.36), Vector4(0.79, 0.26, 0.26, 0.45), Vector4(0.88, 0.4, 0.16, 0.42), Vector4(0.95, 0.0, 0.0, 0.4)])
	else:
		# the spare cloth folded flat under: the end squarer, lower, spread
		for e: Vector3 in [Vector3(0.78, 1.03, 0.72), Vector3(0.95, 0.92, 0.28), Vector3(1.0, 0.0, 0.0)]:
			rings.append(Vector4(e.x, e.y, e.z, 0.3 * e.z))
	# Round each ring from the base's one edge, over the top, to its other:
	# the base itself rests on what carries the sack, never seen, so it has
	# no faces (the sides belly out lowest, where the fill settles).
	var arc: Array[float] = [-0.4, -0.08, 0.25, 0.5, 0.75, 1.08, 1.4]
	var sides := arc.size() - 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var mids := PackedVector3Array()
	for r in rings.size():
		var ring := rings[r]
		var mid := Vector3(ring.x * h.x, SACK.y * ring.w, 0.0)
		mids.append(mid)
		for j in sides + 1:
			var w := PI * arc[j]
			var s := sin(w)
			var c := cos(w)
			# (the top pressed flat under the course above or the fill's own
			# weight: square shoulders, not a loaf's dome)
			var y := signf(s) * pow(absf(s), 0.3 if s < 0.0 else 0.4)
			var z := signf(c) * pow(absf(c), 0.6)
			var p := Vector3(ring.x * h.x, 0.0, z * h.z * ring.y)
			if y >= 0.0:
				# the top domed by the fill, slumped toward one end, lumpy
				var lump := 0.05 * sin(ring.x * 7.3 + z * 4.1 + float(variant)) * sin(z * 3.0 + float(variant) * 1.7)
				p.y = mid.y + y * top * ring.z * (1.0 - 0.07 * slump * ring.x + lump)
			else:
				p.y = mid.y + y * base * ring.z
			if draped:
				p.y -= 0.05 * pow(absf(p.z) / h.z, 2.0)
			verts.append(p)
			uvs.append(Vector2(float(r) / float(rings.size() - 1), float(j) / float(sides)))
	for r in rings.size() - 1:
		for j in sides:
			var a := r * (sides + 1) + j
			var out := (verts[a] - mids[r]).normalized() + Vector3(signf(rings[r].x) * 0.2 if r == 0 or r == rings.size() - 2 else 0.0, 0, 0)
			VehicleWheels._tri(idx, verts, out, a, a + sides + 1, a + 1)
			VehicleWheels._tri(idx, verts, out, a + 1, a + sides + 1, a + sides + 2)
	# one smooth skin, its seam and its ends' poles included
	var sums := {}
	for f in range(0, idx.size(), 3):
		var n := (verts[idx[f + 2]] - verts[idx[f]]).cross(verts[idx[f + 1]] - verts[idx[f]])
		for c in 3:
			var point := Vector3i((verts[idx[f + c]] * 10000.0).round())
			sums[point] = (sums.get(point, Vector3.ZERO) as Vector3) + n
	var norms := PackedVector3Array()
	for q in verts:
		var total: Vector3 = sums[Vector3i((q * 10000.0).round())]
		norms.append(total.normalized() if total.length_squared() > 0.0 else Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	_sacks[variant] = mesh
	return mesh


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
## (The desert one's garnish is no paler than the sand paint it hides: a
## paler scrim catches the noon sun white and the bundle reads as litter on
## the roof, where a darker mound with mid-brown in it reads as a net.)
const NET_DESERT: Array[Color] = [Color(0.45, 0.39, 0.27), Color(0.54, 0.48, 0.35), Color(0.34, 0.27, 0.17)]
## Cut leaves: fresh, in shade, a day or two on drying out, and wilted. Living
## leaves are a yellower green than any olive or green paint, and a branch is
## cut to be seen as bush from above, so these keep that, but a cut branch
## starts to wilt within hours, its leaves going greyer and duller as they
## curl (a saturated green read as plastic ivy): a fresh spray still stands
## off the paint under it at 50 m, a drying one goes olive-gold, a wilted one
## brown-olive.
const LEAVES: Array[Color] = [Color(0.24, 0.34, 0.11), Color(0.19, 0.27, 0.10), Color(0.32, 0.34, 0.14), Color(0.40, 0.35, 0.16), Color(0.33, 0.29, 0.16)]
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


## A camouflage net stowed on a cab roof as a crew carries it between halts:
## folded and rolled into a bundle along the longer side of `size`'s
## footprint (x by z), its middle on the roof at `foot` and turned by
## `rotation`, strapped twice, the garnish tufting out of both ends in the
## net's pale and dark scrim; or, one time in three, `net`'s heap where it was
## thrown down. A roll reads as kit from the battle camera, where a heap the
## size of a door mat reads as litter. Stays within the footprint and 26 cm
## over the roof.
static func roof_net(k: VehicleModels, parent: Node3D, foot: Vector3, size: Vector3, rotation: Vector3, rng: RandomNumberGenerator) -> void:
	if k.wreck or rng.randf() < 0.34:
		net(k, parent, foot, size, rotation, rng)
		return
	var cols := _net_colours(k)
	var long := maxf(size.x, size.z)
	var r := clampf(minf(size.x, size.z) * 0.18, 0.09, 0.13)
	var length := long - 0.18
	var mount := k._pivot(parent, foot)
	mount.basis = Basis.from_euler(rotation) * (Basis.IDENTITY if size.x >= size.z else Basis(Vector3.UP, PI / 2))
	var shade := rng.randf_range(-0.06, 0.06)
	var body: Color = cols[0].lightened(shade) if shade > 0.0 else cols[0].darkened(-shade)
	var lie := k._pivot(mount, Vector3(0, r, 0))
	lie.rotation = Vector3(0, 0, PI / 2)
	_roll(k, lie, r, length, body, "canvas", Vector2(-0.3, 0.3))
	# The scrim's leaves spill out of the roll's ends, as they would out of a
	# rolled garnished net, tucked in only half way.
	var tuft := Vector3(0.15, maxf(0.04, snappedf(r * 1.4, 0.02)), maxf(0.15, snappedf(r * 2.0, 0.05)))
	var variant := rng.randi_range(0, 2)
	var meshes := _net_meshes(tuft, variant)
	for e: float in [-1.0, 1.0]:
		for i: int in [1, 2]:
			k._add(mount, meshes[i], "canvas", cols[i], Vector3(e * (length * 0.5 + 0.02), 0, 0), Vector3(0, PI if e < 0.0 else 0.0, 0), Vector3.ONE, false)
	# and the garnish caught in the outer lap stands out of it all along, so
	# from above it's a net, not a bedroll: the scrim of a heap the roll's
	# size, its leaves round the roll's top
	var along := Vector3(maxf(0.15, snappedf(length, 0.05)), maxf(0.04, snappedf(r * 2.0 + 0.04, 0.02)), maxf(0.15, snappedf(r * 2.3, 0.05)))
	var lap := _net_meshes(along, variant)
	for i: int in [1, 2]:
		k._add(mount, lap[i], "canvas", cols[i], Vector3.ZERO, Vector3.ZERO, Vector3(length / along.x, 1.0, 1.0), false)
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
	# (six more, smaller leaves than the old forty-two, so the spray stays as
	# full while each leaf shrinks to a hand's length)
	for n in 48:
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var r := pow(rng.randf(), 0.5) * 0.9
		var c := Vector3(d.x * r * 1.25, d.y * r * 0.55 + 0.12, d.z * r)
		var out := Vector3(c.x / 1.25, (c.y - 0.12) / 0.55, c.z).normalized()
		# (each leaf drooping off its stalk as a cut branch's do once they wilt,
		# and a hand's length at most: big flat leaves read as a houseplant)
		var t := (out + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6)) + Vector3.DOWN * 0.45).normalized()
		var b := t.cross(Vector3(rng.randf_range(-0.7, 0.7), 1.0, rng.randf_range(-0.7, 0.7)).normalized()).normalized()
		_leaf(verts, norms, idx, c, t, b, rng.randf_range(0.36, 0.48), rng.randf_range(0.17, 0.23), (out + Vector3.UP * 0.3).normalized())
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


## A bag's softened shell that size (cached by size): stuffed cloth, not a
## rounded box. A kit bag packed with clothing settles: its base sits flat on
## what carries it with tight edges (the load's weight squares them), its
## upper sides pull in and its top edges droop over the softer top, and its
## faces belly out between corners that pull in. No two lie quite square: one
## end of the top slumps lower and the top leans, drawn from the size, so a
## cached shell is one shape. Each face carries its own UVs, so the canvas
## finish sews a seam along every edge, where a bag's panels are stitched.
## Nothing leaves the box `size` spans.
static func _shell(size: Vector3) -> ArrayMesh:
	if _bags.has(size):
		return _bags[size]
	var h := size * 0.5
	var r := _round(size)
	var lo := Vector3(h.x - r.x, h.y - r.y, h.z - r.x)
	var hi := Vector3(h.x - r.x, h.y - r.z, h.z - r.x)
	# Each axis: the edges' crests, a point partway round each rounded edge
	# and the face's middle, where it bellies out: the face curves all the
	# way across, as stuffed cloth does.
	var grid: Array[PackedFloat32Array] = []
	for axis in 3:
		grid.append(PackedFloat32Array([-h[axis], -h[axis] + (h[axis] - lo[axis]) * 0.45, (hi[axis] - lo[axis]) * 0.5, h[axis] - (h[axis] - hi[axis]) * 0.45, h[axis]]))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for a in 3:
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		for s: float in [-1.0, 1.0]:
			# (its base rests on what carries it, never seen)
			if a == 1 and s < 0.0:
				continue
			var base := verts.size()
			for i in 5:
				for j in 5:
					var p := Vector3.ZERO
					p[a] = s * h[a]
					p[u] = grid[u][i]
					p[v] = grid[v][j]
					verts.append(_soft(p, size))
					uvs.append(Vector2(float(i) / 4.0, float(j) / 4.0))
			var outward := Vector3.ZERO
			outward[a] = s
			for i in 4:
				for j in 4:
					var c := base + i * 5 + j
					VehicleWheels._tri(idx, verts, outward, c, c + 5, c + 1)
					VehicleWheels._tri(idx, verts, outward, c + 1, c + 5, c + 6)
	# One smooth skin across the faces' seams: each normal the sum of its
	# faces' at that point, whichever face's vertex it is.
	var sums := {}
	for f in range(0, idx.size(), 3):
		var n := (verts[idx[f + 2]] - verts[idx[f]]).cross(verts[idx[f + 1]] - verts[idx[f]])
		for c in 3:
			var point := Vector3i((verts[idx[f + c]] * 10000.0).round())
			sums[point] = (sums.get(point, Vector3.ZERO) as Vector3) + n
	var norms := PackedVector3Array()
	for q in verts:
		var total: Vector3 = sums[Vector3i((q * 10000.0).round())]
		norms.append(total.normalized() if total.length_squared() > 0.0 else Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	_bags[size] = mesh
	return mesh


## Where a point `p` on the box `size` spans (centred) lies on that size's
## bag shell (_shell): pushed onto its rounded edges (tighter at the base) and
## settled as the shell is, so a strap or welt laid by it lies on the cloth.
static func _soft(p: Vector3, size: Vector3) -> Vector3:
	var h := size * 0.5
	var r := _round(size)
	var lo := Vector3(h.x - r.x, h.y - r.y, h.z - r.x)
	var hi := Vector3(h.x - r.x, h.y - r.z, h.z - r.x)
	var core := Vector3(clampf(p.x, -lo.x, hi.x), clampf(p.y, -lo.y, hi.y), clampf(p.z, -lo.z, hi.z))
	var radii := Vector3(r.x, r.y if p.y < core.y else r.z, r.x)
	var e := (p - core) / radii
	var q := core + (e.normalized() * radii if e.length_squared() > 0.0 else Vector3.ZERO)
	var key := hash(str(size))
	var slump := float(key & 255) / 255.0
	var lean := float((key >> 8) & 255) / 255.0 - 0.5
	var n := q / h
	var up := maxf(n.y, 0.0)
	var low := maxf(-n.y, 0.0)
	# (faces belly out across their whole width and height, so no face is
	# flat: the corners pull in, the upper sides most and the base a little;
	# the top leans a little one way)
	var waist := 0.07 * up * up + 0.025 * low * low
	q.x *= 1.0 - 0.09 * n.z * n.z - waist
	q.z *= 1.0 - 0.09 * n.x * n.x - waist
	q.x += h.x * 0.03 * lean * up
	# (the top domes, its edges drooping, and one end of it slumps)
	q.y -= h.y * up * (0.07 * (n.x * n.x + n.z * n.z) + 0.06 * slump * (0.5 + 0.5 * n.x))
	return q


## A bag shell's rounding that size: its edges' radius, its base's (tighter)
## and its top's (softer). A bag long in plan is a duffel, a tube of cloth
## round across its length (_duffel).
static func _round(size: Vector3) -> Vector3:
	var r := minf(size.x, minf(size.y, size.z)) * (0.42 if _duffel(size) else 0.24)
	return Vector3(r, r * 0.5, r * 1.25)


## Whether a bag that size is a duffel: long in plan, its length nearly twice
## its height and width.
static func _duffel(size: Vector3) -> bool:
	return maxf(size.x, size.z) >= 1.8 * maxf(size.y, minf(size.x, size.z))


static var _welts := {}

## The sewn welt round a bag's shell that size at its middle: a cord in the
## seam, a little sunk in the cloth, following the shell's rounded corners
## (cached by size).
static func _welt(size: Vector3) -> ArrayMesh:
	if _welts.has(size):
		return _welts[size]
	var h := size * 0.5
	var round := _round(size)
	var r := round.x
	var y := (round.y - round.z) * 0.5
	var raw: Array[Vector3] = []
	for corner in 4:
		var c := Vector3(h.x - r if corner == 0 or corner == 3 else r - h.x, y, h.z - r if corner < 2 else r - h.z)
		for step in 3:
			var angle := (float(corner) + float(step) / 2.0) * PI * 0.5
			raw.append(c + Vector3(cos(angle), 0, sin(angle)) * r * 1.5)
	# (round each corner, and at each side's middle, where the face bellies)
	var ring: Array[Vector3] = []
	for i in raw.size():
		ring.append(_soft(raw[i], size))
		if i % 3 == 2:
			ring.append(_soft((raw[i] + raw[(i + 1) % raw.size()]) * 0.5, size))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var count := ring.size()
	for i in count:
		var out := Vector3(ring[i].x / h.x, 0, ring[i].z / h.z).normalized()
		for k in 4:
			var d := out * cos(k * PI * 0.5) + Vector3.UP * sin(k * PI * 0.5)
			verts.append(ring[i] + d * 0.006 - out * 0.002)
			norms.append(d)
	for i in count:
		for k in 4:
			var a := i * 4 + k
			var b := i * 4 + (k + 1) % 4
			var c := ((i + 1) % count) * 4 + k
			var d := ((i + 1) % count) * 4 + (k + 1) % 4
			VehicleWheels._tri(idx, verts, norms[a] + norms[b], a, c, b)
			VehicleWheels._tri(idx, verts, norms[a] + norms[b], b, c, d)
	_welts[size] = VehicleWheels._mesh(verts, norms, idx)
	return _welts[size]


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


## A tarpaulin rolled up tight on a roof, as a crew carries the vehicle's own
## cover across a turret's rear plate: roll's shape at a roof kit's price.
## Its two ties are knotted webbing, not buckled straps (a tarp is lashed down
## where it lies and seldom undone), and its wound ends show a turn and a half
## of the cloth's edge, not two and a half: a roll a hand across is a few
## pixels from the battle camera, where it reads by its round top, its dark
## ends and the two ties pinching it. Eight sides instead of twelve, for the
## same reason. Built once per size (cached as roll's are); wrecks carry none.
static func tarp_roll(k: VehicleModels, parent: Node3D, center: Vector3, radius: float, length: float, rotation: Vector3, col: Color, material := "canvas") -> void:
	if k.wreck:
		return
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	_roll(k, mount, radius, length, col, material, Vector2(-0.3, 0.3), true)


## One roll on its mount, along its Y: `straps` the two straps' places as
## fractions of its length from its middle. `cheap` builds tarp_roll's: no
## buckles, fewer sides and wound turns.
static func _roll(k: VehicleModels, mount: Node3D, radius: float, length: float, col: Color, material: String, straps: Vector2, cheap := false) -> void:
	if k.wreck:
		# (a wreck's rolls, and the webbing left of them, as they always were)
		var end := minf(0.03, length * 0.04)
		VehicleEquipment._cyl(k, mount, radius, radius, length - end * 2, Vector3.ZERO, Vector3.ZERO, material, col, 12, true, 0)
		for side: float in [-1.0, 1.0]:
			var y := side * (length * 0.5 - end * 0.5)
			VehicleEquipment._cyl(k, mount, radius * (0.88 if side > 0 else 1.0), radius * (1.0 if side > 0 else 0.88), end, Vector3(0, y, 0), Vector3.ZERO, material, col, 12, true, 2 if side > 0 else 1)
			k._add(mount, VehicleFittings._ring(radius * 0.36, radius * 0.5), material, col.darkened(0.22), Vector3(0, side * length * 0.5, 0), Vector3.ZERO, Vector3(1, 0.12, 1), false)
		for f: float in [straps.x, straps.y]:
			VehicleEquipment._cyl(k, mount, radius * 1.035, radius * 1.035, minf(0.04, length * 0.05), Vector3(0, f * length, 0), Vector3.ZERO, "webbing", col.darkened(0.35), 12, false, 0)
			k._box(mount, Vector3(0.014, minf(0.05, length * 0.06), 0.04), Vector3(radius * 1.04, f * length, 0), "gunmetal", Color(0.22, 0.23, 0.21), Vector3.ZERO, false)
		k._fold(mount)
		return
	# A roll settles under its own weight and under the straps cinched round
	# it: its top flattens (its underside stays where it rests), so the cloth
	# is turned about the axis until that flat side faces the model's up.
	var basis := Basis.IDENTITY
	var n: Node3D = mount
	while n != null and n != k.root:
		basis = n.basis.orthonormalized() * basis
		n = n.get_parent() as Node3D
	var up := basis.inverse() * Vector3.UP
	var flat := Vector2(up.x, up.z)
	var yaw := atan2(up.x, up.z) if flat.length() > 0.3 else 0.0
	# Cached by its length in radii and its straps' places, to a few
	# centimetres, and scaled to the exact size.
	var ratio := maxf(1.5, snappedf(length / radius, 0.25))
	var at := Vector2(snappedf(straps.x, 0.04), snappedf(straps.y, 0.04))
	var meshes := _roll_meshes(ratio, at, cheap)
	var scale := Vector3(radius, length / ratio, radius)
	var rot := Vector3(0, yaw, 0)
	k._add(mount, meshes[0], material, col, Vector3.ZERO, rot, scale)
	# The wound layers on the end faces read as a darker spiral.
	k._add(mount, meshes[1], material, col.darkened(0.25), Vector3.ZERO, rot, scale, false)
	k._add(mount, meshes[2], "webbing", col.darkened(0.35), Vector3.ZERO, rot, scale, false)
	if cheap:
		k._fold(mount)
		return
	# Each buckle on its strap at the mount's +X, where the family put it, on
	# the strap's flattened section there. A tilt's own curtain is strapped
	# with the steel roller buckles sewn to it; a bedroll's or a mat's
	# compression straps close in the black plastic buckles of the kit bags
	# beside it (steel there caught the sky as a grey glint on every roll).
	var c := up.x / flat.length() if flat.length() > 0.3 else 0.0
	var reach := ROLL_BAND * sqrt(1.0 - c * c * (1.0 - ROLL_TOP * ROLL_TOP)) if c > 0.0 else ROLL_BAND
	var steel := material == "canvas_white"
	for f: float in [at.x, at.y]:
		k._box(mount, Vector3(0.014, minf(0.05, length * 0.06), 0.04), Vector3(radius * reach + 0.005, f * length, 0), "gunmetal" if steel else "webbing", Color(0.22, 0.23, 0.21) if steel else BUCKLE, Vector3.ZERO, false)
	k._fold(mount)


## A roll's flattened top (its section's upper half against its radius), and
## a strap's radius over the cloth it bites into.
const ROLL_TOP := 0.88
const ROLL_BAND := 0.975

static var _rolls := {}

## A rolled bedroll, mat or tarp along +Y at radius 1 (local +Z up), `ratio`
## radii long, `straps` its straps' places as fractions of its length from
## its middle: [the cloth, the spiral on its ends, the straps]. The cloth is
## wound, so its outer lap ends in a step along its length, and lumpy with
## the folds rolled in; it pinches in under each strap; its ends turn in and
## dish a little where the layers are wound tighter at the core. `cheap` is
## tarp_roll's: eight sides, one ring fewer at each end, a turn and a half of
## spiral in ten steps.
static func _roll_meshes(ratio: float, straps: Vector2, cheap := false) -> Array:
	var key := Vector4(ratio, straps.x, straps.y, 1.0 if cheap else 0.0)
	if _rolls.has(key):
		return _rolls[key]
	var half := ratio * 0.5
	var sides := 8 if cheap else 12
	var lap := 0.6
	var stations: Array[float] = [-half, -half + 0.16]
	if not cheap:
		stations = [-half, -half + 0.1, -half + 0.28]
	for s: float in [straps.x * ratio, straps.y * ratio]:
		for d: float in [-0.24, 0.0, 0.24]:
			stations.append(s + d)
	stations.append(0.0)
	var ends: Array[float] = [half - 0.16, half]
	if not cheap:
		ends = [half - 0.28, half - 0.1, half]
	stations.append_array(ends)
	stations.sort()
	var ys: Array[float] = []
	for y in stations:
		if (ys.is_empty() or y > ys[ys.size() - 1] + 0.05) and absf(y) <= half:
			ys.append(y)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for y in ys:
		var pinch := 0.0
		for s: float in [straps.x * ratio, straps.y * ratio]:
			pinch = maxf(pinch, exp(-pow((y - s) / 0.16, 2.0)))
		var end := clampf((absf(y) - (half - 0.3)) / 0.3, 0.0, 1.0)
		var rr := 1.0 - 0.06 * pinch - 0.13 * end * end
		for j in sides + 1:
			var a := lap + TAU * float(j) / sides
			# (the outer lap steps out as it winds round, ending in its edge)
			var wound := rr * (0.97 + 0.03 * float(j) / sides) + 0.015 * sin(a * 3.0 + y * 1.7) * (1.0 - pinch)
			verts.append(_roll_point(a, wound, y))
	var ring := sides + 1
	for i in ys.size() - 1:
		for j in sides:
			var c := i * ring + j
			var out := verts[c] - Vector3(0, verts[c].y, 0)
			VehicleWheels._tri(idx, verts, out, c, c + 1, c + ring)
			VehicleWheels._tri(idx, verts, out, c + 1, c + ring + 1, c + ring)
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for f in range(0, idx.size(), 3):
		var nf := (verts[idx[f + 2]] - verts[idx[f]]).cross(verts[idx[f + 1]] - verts[idx[f]])
		for c in 3:
			norms[idx[f + c]] += nf
	# (the lap's edge, a strip from the outer layer down to the one under it)
	for i in ys.size() - 1:
		var c := i * ring
		VehicleWheels._tri(idx, verts, Vector3(cos(lap), 0, -sin(lap)), c, c + sides, c + ring)
		VehicleWheels._tri(idx, verts, Vector3(cos(lap), 0, -sin(lap)), c + sides, c + ring + sides, c + ring)
	# Each end dished in to its core, on vertices of its own so the face
	# shades flat against the rounded side.
	var spiral := PackedVector3Array()
	var spiral_norms := PackedVector3Array()
	var spiral_idx := PackedInt32Array()
	for side: float in [-1.0, 1.0]:
		var rim := (0 if side < 0.0 else ys.size() - 1) * ring
		var centre := verts.size()
		verts.append(Vector3(0, side * (half - 0.07), 0))
		norms.append(Vector3(0, side, 0))
		for j in sides + 1:
			verts.append(verts[rim + j])
			norms.append(Vector3(0, side, 0))
		for j in sides:
			VehicleWheels._tri(idx, verts, Vector3(0, side, 0), centre, centre + 1 + j, centre + 2 + j)
		# Two and a half turns of the wound cloth's edge, a couple of
		# millimetres proud of the dished face so it never fights it.
		var rim_r := 0.87
		var turns := 10 if cheap else 26
		var winds := 1.5 if cheap else 2.5
		for t in turns + 1:
			var f := float(t) / turns
			var a := lap + f * TAU * winds * side
			var rad := lerpf(0.12, 0.78, f)
			for w: float in [-0.035, 0.035]:
				var p := _roll_point(a, rad + w, 0.0)
				p.y = side * (half - 0.07 * (1.0 - (rad + w) / rim_r) + 0.012)
				spiral.append(p)
				spiral_norms.append(Vector3(0, side, 0))
			if t > 0:
				var b := spiral.size() - 4
				VehicleWheels._tri(spiral_idx, spiral, Vector3(0, side, 0), b, b + 1, b + 2)
				VehicleWheels._tri(spiral_idx, spiral, Vector3(0, side, 0), b + 1, b + 3, b + 2)
	for i in norms.size():
		norms[i] = norms[i].normalized() if norms[i].length_squared() > 0.0 else Vector3.UP
	# The straps: a band round the pinched cloth, its outer face and its
	# two edges down into the cloth.
	var band := PackedVector3Array()
	var band_norms := PackedVector3Array()
	var band_idx := PackedInt32Array()
	for s: float in [straps.x * ratio, straps.y * ratio]:
		var base := band.size()
		var rows: Array[Vector2] = [Vector2(s - 0.13, 0.9), Vector2(s - 0.13, ROLL_BAND), Vector2(s + 0.13, ROLL_BAND), Vector2(s + 0.13, 0.9)]
		for row: Vector2 in rows:
			for j in sides + 1:
				var a := lap + TAU * float(j) / sides
				var p := _roll_point(a, row.y, row.x)
				band.append(p)
				band_norms.append(Vector3(p.x, 0, p.z).normalized())
		for i in 3:
			for j in sides:
				var c := base + i * ring + j
				var out := band[c] - Vector3(0, band[c].y, 0)
				if i != 1:
					out = Vector3(0, -1.0 if i == 0 else 1.0, 0)
				VehicleWheels._tri(band_idx, band, out, c, c + 1, c + ring)
				VehicleWheels._tri(band_idx, band, out, c + 1, c + ring + 1, c + ring)
	var result := [VehicleWheels._mesh(verts, norms, idx), VehicleWheels._mesh(spiral, spiral_norms, spiral_idx), VehicleWheels._mesh(band, band_norms, band_idx)]
	_rolls[key] = result
	return result


## A point on a roll's section at angle `a` from its up (+Z) toward +X,
## `r` radii out, `y` along it: its upper half flattened.
static func _roll_point(a: float, r: float, y: float) -> Vector3:
	var z := cos(a)
	return Vector3(sin(a) * r, y, z * r * (ROLL_TOP if z > 0.0 else 1.0))
