class_name BuildingOpenings
extends RefCounted
## Windows, doorways and the things that close them, in a face kit (see
## BuildingWalls: x along the face, y up, z out of it, the face at z = 0).
## The opening itself is the builder's (its wall parts leave the hole); these
## dress it as a builder would: a frame set back in the reveal, glazing bars,
## panes (whole, cracked to shards or gone), a sill that throws the rain off
## and a head that carries the wall over the hole, both in the wall's
## material (BuildingMaterials), shutters on their hinges, a step at a door.
##
## Frames, leaves, louvres and shutters are cached shapes (BuildingKit.shape):
## a town's few hundred windows share a handful of meshes, each one part.

const GLASS := Color(0.08, 0.1, 0.12)
const IRON := Color(0.17, 0.16, 0.15)


## A window: `c` is the middle of the opening on the face, `size` its width
## and height. opts:
##   frame        frame paint colour (white-ish)          frame_kind  surface (paint)
##   inset        how far the frame sits back in the reveal (0.1)
##   material     the wall's material (sill and head follow it; plaster)
##   wall         the wall's colour (render dressings take its paint)
##   mullions     upright glazing bars (1)                transom    height of the transom bar, 0..1 (0.7; <0 none)
##   glazing      chance each pane is whole (0.4); of the rest, `cracked` (0.5) hold shards
##   shutters     a colour, for a pair of shutters folded back on their hinges
##   shutter      "boarded" or "louvred"                  open       how far each swings off the wall (rad)
##   curtains     "drapes", "blind" or "nets" (BuildingFurnishings.curtains), in `curtain` colour
##   lit          a lamp on in the room: the whole panes glow by night (the `window_lit` glass)
##   sill, head   false for none
static func window(k: BuildingKit, c: Vector3, size: Vector2, opts := {}) -> void:
	var material: String = opts.get("material", "plaster")
	var wall: Color = opts.get("wall", BuildingMaterials.color(material))
	var inset: float = opts.get("inset", 0.1)
	var w := size.x
	var h := size.y
	var fk: String = opts.get("frame_kind", "paint")
	var fc: Color = opts.get("frame", Color(0.86, 0.85, 0.8))
	var mullions: int = opts.get("mullions", 1)
	var transom: float = opts.get("transom", 0.7)
	if opts.get("sill", true):
		sill(k, c.x, c.y - h * 0.5, w, inset, material, wall)
	if opts.get("head", true):
		head(k, c.x, c.y + h * 0.5, w, material, wall)
	var fp := Vector3(c.x, c.y, -inset)
	k.part(frame_shape(w, h, mullions, transom), fk, Transform3D(Basis.IDENTITY, fp), fc)
	panes(k, fp, size, mullions, transom, opts.get("glazing", 0.4), opts.get("cracked", 0.5), "window_lit" if opts.get("lit", false) else "glass")
	if opts.get("curtains", "") != "":
		BuildingFurnishings.curtains(k, fp, size, opts.curtains, opts.get("curtain", BuildingFurnishings.FABRICS[0]))
	if opts.get("shutters") is Color:
		var open: Array = opts.get("open", [0.1, 0.1])
		var style: String = opts.get("shutter", "boarded")
		for i in 2:
			var sx := -1.0 if i == 0 else 1.0
			if open.size() > i and open[i] == null:
				continue  # (that one's been torn off)
			var a: float = open[i] if open.size() > i else 0.1
			shutter(k, Vector3(c.x + sx * w * 0.5, c.y, 0.02), Vector2(w * 0.5 + 0.03, h + 0.04), sx, a, style, opts.shutters)


## The sill under an opening whose bottom is at `y`: from the frame out past
## the face, its top falling outwards, a drip under its front edge.
static func sill(k: BuildingKit, x: float, y: float, w: float, inset: float, material: String, wall: Color) -> void:
	var kind := BuildingMaterials.trim(material, "sill")
	var col := BuildingMaterials.trim_color(material, wall, 0.25 if kind == "plaster" else 0.04)
	var depth := inset + 0.09
	var z := (0.09 - inset) * 0.5
	k.box(Vector3(w + 0.22, 0.07, depth), Vector3(x, y - 0.035, z), kind, col, Vector3(0.08, 0, 0))


## What carries the wall over an opening whose top is at `y`: a render band, a
## cast lintel, or a dressed stone lintel with a keystone.
static func head(k: BuildingKit, x: float, y: float, w: float, material: String, wall: Color) -> void:
	var kind := BuildingMaterials.trim(material, "head")
	match BuildingMaterials.value(material, "finish", "render"):
		"stone":
			var sc := wall.lightened(0.08)
			k.box(Vector3(w + 0.3, 0.22, 0.035), Vector3(x, y + 0.11, 0.0175), "stone", sc)
			k.box(Vector3(0.16, 0.28, 0.06), Vector3(x, y + 0.13, 0.03), "stone", sc.lightened(0.05))
		"brick", "cast", "panels":
			k.box(Vector3(w + 0.3, 0.18, 0.03), Vector3(x, y + 0.09, 0.015), kind, BuildingMaterials.trim_color(material, wall, 0.02))
		_:
			k.box(Vector3(w + 0.16, 0.13, 0.03), Vector3(x, y + 0.07, 0.015), kind, BuildingMaterials.trim_color(material, wall, -0.1))


## A window frame `w` x `h` round its opening (centred), with `mullions`
## upright bars and a transom at `transom` of its height (none below 0).
static func frame_shape(w: float, h: float, mullions: int, transom: float) -> ArrayMesh:
	return BuildingKit.shape("window|%.2f|%.2f|%d|%.2f" % [w, h, mullions, transom], func() -> Array:
		var fw := 0.07
		var out: Array = [
			BuildingKit.piece(Vector3(fw, h, fw), Vector3(-w * 0.5 + fw * 0.5, 0, 0)),
			BuildingKit.piece(Vector3(fw, h, fw), Vector3(w * 0.5 - fw * 0.5, 0, 0)),
			BuildingKit.piece(Vector3(w - fw * 2.0, fw, fw), Vector3(0, h * 0.5 - fw * 0.5, 0)),
			BuildingKit.piece(Vector3(w - fw * 2.0, fw * 1.2, fw * 1.1), Vector3(0, -h * 0.5 + fw * 0.6, 0.004)),
		]
		for i in mullions:
			out.append(BuildingKit.piece(Vector3(0.05, h - fw * 2.0, 0.05), Vector3(-w * 0.5 + (i + 1) * w / (mullions + 1), 0, 0)))
		if transom >= 0.0:
			out.append(BuildingKit.piece(Vector3(w - fw * 2.0, 0.05, 0.05), Vector3(0, -h * 0.5 + h * transom, 0)))
		return out)


## The panes between the bars of a frame at `fp`: each one whole, cracked to
## the shards still in its putty, or gone.
static func panes(k: BuildingKit, fp: Vector3, size: Vector2, mullions: int, transom: float, whole: float, cracked: float, glass := "glass") -> void:
	var fw := 0.07
	var cols := mullions + 1
	var inner := Vector2(size.x - fw * 2.0, size.y - fw * 2.0)
	var rows: Array = [[-size.y * 0.5 + fw, size.y * 0.5 - fw]]
	if transom >= 0.0:
		var ty := -size.y * 0.5 + size.y * transom
		rows = [[-size.y * 0.5 + fw, ty - 0.025], [ty + 0.025, size.y * 0.5 - fw]]
	for ci in cols:
		var x0 := -size.x * 0.5 + fw + ci * inner.x / cols + (0.025 if ci > 0 else 0.0)
		var x1 := -size.x * 0.5 + fw + (ci + 1) * inner.x / cols - (0.025 if ci < cols - 1 else 0.0)
		for r: Array in rows:
			var cell := Vector2(x1 - x0, float(r[1]) - float(r[0]))
			var mid := fp + Vector3((x0 + x1) * 0.5, (float(r[0]) + float(r[1])) * 0.5, 0)
			var roll := k.rng.randf()
			if roll < whole:
				k.plate(Vector3(cell.x, cell.y, 0.012), mid, glass, GLASS)
			elif k.rng.randf() < cracked:
				var shard := shard_mesh(k.rng.randi() % 4)
				k.part(shard, "glass", Transform3D(Basis.from_scale(Vector3(cell.x, cell.y, 1.0)), mid), GLASS, false)


## Broken glass left in a frame: a few jagged triangles along the edges of a
## unit pane (scaled to the pane), four ways it can break.
static func shard_mesh(i: int) -> ArrayMesh:
	# (corners of a unit pane: the glass that's left clings to the putty)
	var sets := [
		[[Vector2(-0.5, -0.5), Vector2(-0.05, -0.5), Vector2(-0.5, 0.1)], [Vector2(0.5, 0.5), Vector2(0.5, 0.12), Vector2(0.26, 0.5)]],
		[[Vector2(-0.5, 0.5), Vector2(0.12, 0.5), Vector2(-0.5, 0.18)], [Vector2(0.5, -0.5), Vector2(0.5, -0.12), Vector2(0.2, -0.5)]],
		[[Vector2(-0.5, -0.5), Vector2(0.3, -0.5), Vector2(-0.18, -0.3)], [Vector2(-0.5, 0.5), Vector2(-0.5, 0.25), Vector2(-0.3, 0.5)]],
		[[Vector2(0.5, 0.5), Vector2(-0.15, 0.5), Vector2(0.5, 0.0)], [Vector2(-0.5, -0.5), Vector2(-0.5, -0.28), Vector2(-0.32, -0.5)]],
	]
	return BuildingKit.shape("shards|%d" % i, func() -> Array:
		var out: Array = []
		var j := 0
		for tri: Array in sets[i]:
			out.append([BuildingKit.extrusion("shard|%d|%d" % [i, j], PackedVector2Array(tri), 0.008), Transform3D.IDENTITY])
			j += 1
		return out)


## A shutter hung on the jamb at `hinge`, `size` its leaf, swinging out along
## `side` (-1 left, +1 right) folded back against the wall and `open` off it.
static func shutter(k: BuildingKit, hinge: Vector3, size: Vector2, side: float, open: float, style: String, col: Color) -> void:
	var xf := Transform3D(Basis(Vector3.UP, -side * open), hinge) * Transform3D(Basis.IDENTITY, Vector3(side * size.x * 0.5, 0, 0.02))
	k.part(shutter_shape(size, style), "paint", xf, col)


static func shutter_shape(size: Vector2, style: String) -> ArrayMesh:
	return BuildingKit.shape("shutter|%s|%.2f|%.2f" % [style, size.x, size.y], func() -> Array:
		var out: Array = []
		if style == "louvred":
			for sx: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(0.06, size.y, 0.035), Vector3(sx * (size.x * 0.5 - 0.03), 0, 0)))
			for sy: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(size.x - 0.12, 0.07, 0.035), Vector3(0, sy * (size.y * 0.5 - 0.035), 0)))
			var n := int((size.y - 0.14) / 0.1)
			for i in n:
				var y := -size.y * 0.5 + 0.07 + (i + 0.5) * (size.y - 0.14) / n
				out.append(BuildingKit.piece(Vector3(size.x - 0.12, 0.085, 0.01), Vector3(0, y, 0), Vector3(-0.75, 0, 0)))
		else:
			var boards := maxi(2, int(round(size.x / 0.2)))
			for i in boards:
				var bw := size.x / boards
				out.append(BuildingKit.piece(Vector3(bw - 0.012, size.y, 0.025), Vector3(-size.x * 0.5 + (i + 0.5) * bw, 0, 0)))
			for sy: float in [-0.3, 0.3]:
				out.append(BuildingKit.piece(Vector3(size.x - 0.08, 0.09, 0.022), Vector3(0, sy * size.y, 0.022)))
			var a := Vector3(-size.x * 0.4, -0.3 * size.y + 0.05, 0.022)
			var b := Vector3(size.x * 0.4, 0.3 * size.y - 0.05, 0.022)
			out.append([BuildingKit.plain(Vector3(0.07, a.distance_to(b), 0.02)), Transform3D(BuildingKit.aim(b - a), (a + b) * 0.5)])
		return out)


## A doorway whose opening is `size` (width, height) with its foot at `c`:
## the frame in the reveal, a head over it, a step with a nosing, and with
## opts "hood" a small canopy on brackets. opts as for window() (material,
## wall, inset, frame, frame_kind), "step" (false for none).
static func doorway(k: BuildingKit, c: Vector3, size: Vector2, opts := {}) -> void:
	var material: String = opts.get("material", "plaster")
	var wall: Color = opts.get("wall", BuildingMaterials.color(material))
	var inset: float = opts.get("inset", 0.08)
	var w := size.x
	var h := size.y
	k.part(door_frame_shape(w, h), opts.get("frame_kind", "paint"), Transform3D(Basis.IDENTITY, c + Vector3(0, 0, -inset)), opts.get("frame", Color(0.86, 0.85, 0.8)))
	if opts.get("head", true):
		head(k, c.x, c.y + h, w, material, wall)
	if opts.get("step", true):
		var sk: String = "stone" if BuildingMaterials.value(material, "finish", "") == "stone" else "concrete"
		var scol := Color(0.6, 0.58, 0.54)
		k.box(Vector3(w + 0.4, 0.14, 0.6), c + Vector3(0, 0.07, 0.3), sk, scol)
	if opts.get("hood", false):
		BuildingRoofs.canopy(k.at_point(c + Vector3(0, h + 0.3, 0)), w + 0.6, 0.7, opts.get("hood_covering", "roof_tile"), opts.get("hood_col", BuildingMaterials.color("roof_tile")), opts.get("frame", Color(0.86, 0.85, 0.8)))


static func door_frame_shape(w: float, h: float) -> ArrayMesh:
	return BuildingKit.shape("doorframe|%.2f|%.2f" % [w, h], func() -> Array:
		return [
			BuildingKit.piece(Vector3(0.08, h, 0.1), Vector3(-w * 0.5 + 0.04, h * 0.5, 0)),
			BuildingKit.piece(Vector3(0.08, h, 0.1), Vector3(w * 0.5 - 0.04, h * 0.5, 0)),
			BuildingKit.piece(Vector3(w, 0.09, 0.1), Vector3(0, h - 0.045, 0)),
			# the stop the leaves close against
			BuildingKit.piece(Vector3(0.02, h - 0.1, 0.03), Vector3(-w * 0.5 + 0.09, (h - 0.1) * 0.5, -0.035)),
			BuildingKit.piece(Vector3(0.02, h - 0.1, 0.03), Vector3(w * 0.5 - 0.09, (h - 0.1) * 0.5, -0.035)),
		])


## A door leaf in a hinge kit (its origin on the hinge line at the foot, the
## leaf running out along `toward` = -1 or +1 on x), `size` its width and
## height. style: "panelled" (rails, stiles, fielded panels both faces),
## "ledged" (boards on ledges and braces, a thumb latch), "steel" (a plate on
## a stiffened frame, lever handle, heavy hinges).
static func leaf(k: BuildingKit, size: Vector2, style: String, col: Color, toward := 1.0) -> void:
	var mid := Transform3D(Basis.IDENTITY, Vector3(toward * size.x * 0.5, 0, 0))
	var free := toward * (size.x - 0.09)
	match style:
		"ledged":
			k.part(leaf_shape(size, "ledged"), "wood_painted", mid, col)
			k.part(leaf_shape(size, "ledged_strap"), "metal_dark", mid, IRON)
			k.cyl(0.012, 0.012, 0.09, Vector3(free, 1.0, 0.03), "metal_dark", IRON, Vector3(PI * 0.5, 0, 0), 6, false)
			k.part(BuildingKit.ring(0.025, 0.04), "metal_dark", Mats.place(Vector3(free, 0.92, 0.04), Vector3(PI * 0.5, 0, 0)), IRON, false)
		"steel":
			k.part(leaf_shape(size, "steel"), "metal_dark", mid, col)
			for y: float in [0.25, size.y * 0.5, size.y - 0.25]:
				k.cyl(0.022, 0.022, 0.16, Vector3(0, y, 0.0), "steel", IRON, Vector3.ZERO, 8, false)
			k.plate(Vector3(0.14, 0.03, 0.03), Vector3(free + toward * 0.03, 1.0, 0.045), "steel", Color(0.5, 0.5, 0.48))
			k.plate(Vector3(0.14, 0.03, 0.03), Vector3(free + toward * 0.03, 1.0, -0.045), "steel", Color(0.5, 0.5, 0.48))
		_:
			k.part(leaf_shape(size, "panelled"), "paint", mid, col)
			k.part(leaf_shape(size, "panels"), "paint", mid, col.darkened(0.18))
			# lever handles through both faces and two butt hinges, one piece
			var hw := Transform3D(Basis.from_scale(Vector3(toward, 1, 1)), Vector3.ZERO)
			k.part(BuildingKit.shape("leaf|hardware|%.2f|%.2f" % [size.x, size.y], func() -> Array:
				return [
					BuildingKit.piece(Vector3(0.05, 0.05, 0.16), Vector3(size.x - 0.09, 1.0, 0)),
					BuildingKit.piece(Vector3(0.12, 0.022, 0.024), Vector3(size.x - 0.04, 1.0, 0.07)),
					BuildingKit.piece(Vector3(0.12, 0.022, 0.024), Vector3(size.x - 0.04, 1.0, -0.07)),
					BuildingKit.piece(Vector3(0.024, 0.1, 0.03), Vector3(0, 0.3, 0)),
					BuildingKit.piece(Vector3(0.024, 0.1, 0.03), Vector3(0, size.y - 0.3, 0)),
				]), "metal_dark", hw, Color(0.18, 0.17, 0.15), false)


static func leaf_shape(size: Vector2, style: String) -> ArrayMesh:
	return BuildingKit.shape("leaf|%s|%.2f|%.2f" % [style, size.x, size.y], func() -> Array:
		var w := size.x
		var h := size.y
		var out: Array = []
		match style:
			"panelled":
				out.append(BuildingKit.piece(Vector3(w, h, 0.05), Vector3(0, h * 0.5 + 0.02, 0), Vector3.ZERO, true))
			"panels":
				for face: float in [-1.0, 1.0]:
					out.append(BuildingKit.piece(Vector3(w * 0.7, h * 0.38, 0.016), Vector3(0, h * 0.72, face * 0.031)))
					out.append(BuildingKit.piece(Vector3(w * 0.7, h * 0.3, 0.016), Vector3(0, h * 0.24, face * 0.031)))
			"ledged":
				var boards := maxi(3, int(round(w / 0.15)))
				for i in boards:
					out.append(BuildingKit.piece(Vector3(w / boards - 0.01, h, 0.03), Vector3(-w * 0.5 + (i + 0.5) * w / boards, h * 0.5 + 0.02, 0.008)))
				for y: float in [0.25, 0.5, 0.78]:
					out.append(BuildingKit.piece(Vector3(w - 0.1, 0.12, 0.028), Vector3(0, h * y, -0.022)))
				for pair: Array in [[0.25, 0.5], [0.5, 0.78]]:
					var a := Vector3(-w * 0.38, h * float(pair[0]) + 0.06, -0.022)
					var b := Vector3(w * 0.38, h * float(pair[1]) - 0.06, -0.022)
					out.append([BuildingKit.plain(Vector3(0.1, a.distance_to(b), 0.026)), Transform3D(BuildingKit.aim(b - a), (a + b) * 0.5)])
			"ledged_strap":
				for y: float in [0.25, 0.78]:
					out.append(BuildingKit.piece(Vector3(w * 0.62, 0.045, 0.008), Vector3(-w * 0.19, h * y, 0.027)))
			"steel":
				out.append(BuildingKit.piece(Vector3(w, h, 0.045), Vector3(0, h * 0.5 + 0.01, 0), Vector3.ZERO, true))
				for sy: float in [-1.0, 1.0]:
					out.append(BuildingKit.piece(Vector3(w - 0.04, 0.07, 0.03), Vector3(0, h * 0.5 + sy * (h * 0.5 - 0.06), -0.035)))
				for sx: float in [-1.0, 1.0]:
					out.append(BuildingKit.piece(Vector3(0.07, h - 0.12, 0.03), Vector3(sx * (w * 0.5 - 0.055), h * 0.5, -0.035)))
				for y: float in [0.36, 0.66]:
					out.append(BuildingKit.piece(Vector3(w - 0.12, 0.06, 0.03), Vector3(0, h * y, -0.035)))
		return out)


## A roller shutter in an opening `size` with its foot at `c`: the slatted
## curtain down, guide channels either side, the drum's box over the head, a
## bottom rail with a lifting handle.
static func roller_door(k: BuildingKit, c: Vector3, size: Vector2, col: Color) -> void:
	var w := size.x
	var h := size.y
	# (the curtain's slats run across it: plain painted steel, the joints drawn)
	k.box(Vector3(w, h, 0.06), c + Vector3(0, h * 0.5, 0), "paint", col)
	k.part(BuildingKit.shape("roller|%.2f|%.2f" % [w, h], func() -> Array:
		var out: Array = []
		var n := int(h / 0.09)
		for i in range(1, n):
			out.append(BuildingKit.piece(Vector3(w, 0.012, 0.008), Vector3(0, i * h / n, 0.033)))
		return out), "paint", Transform3D(Basis.IDENTITY, c), col.darkened(0.3), false)
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.1, h + 0.05, 0.12), c + Vector3(sx * (w * 0.5 + 0.05), (h + 0.05) * 0.5, 0.0), "steel", Color(0.36, 0.37, 0.35), Vector3.ZERO, true)
	k.box(Vector3(w + 0.34, 0.46, 0.44), c + Vector3(0, h + 0.23, 0.16), "steel", col.darkened(0.12))
	k.plate(Vector3(w, 0.08, 0.1), c + Vector3(0, 0.04, 0.01), "steel", Color(0.3, 0.3, 0.29), Vector3.ZERO, true)
	k.plate(Vector3(0.22, 0.04, 0.06), c + Vector3(0, 0.3, 0.06), "metal_dark", IRON)


## A louvred vent `size` centred on `c`: a frame and blades set to shed rain.
static func louvre(k: BuildingKit, c: Vector3, size: Vector2, col: Color, kind := "paint") -> void:
	k.part(BuildingKit.shape("louvre|%.2f|%.2f" % [size.x, size.y], func() -> Array:
		var out: Array = []
		for sx: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.05, size.y, 0.06), Vector3(sx * (size.x * 0.5 - 0.025), 0, 0)))
		for sy: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(size.x - 0.1, 0.05, 0.06), Vector3(0, sy * (size.y * 0.5 - 0.025), 0)))
		var n := maxi(2, int((size.y - 0.1) / 0.075))
		for i in n:
			out.append(BuildingKit.piece(Vector3(size.x - 0.1, 0.07, 0.008), Vector3(0, -size.y * 0.5 + 0.05 + (i + 0.5) * (size.y - 0.1) / n, 0), Vector3(-0.8, 0, 0)))
		return out), kind, Transform3D(Basis.IDENTITY, c), col)
	k.plate(Vector3(size.x - 0.1, size.y - 0.1, 0.01), c + Vector3(0, 0, -0.03), "plain_dark", Color(0.05, 0.05, 0.05))


## A band of glazing `size` centred on `c`, `panes` wide: head and sill
## rails, mullions, the glass behind them, a flashing over the sill.
static func ribbon(k: BuildingKit, c: Vector3, size: Vector2, panes: int, col: Color, kind := "metal_dark", lit := false) -> void:
	k.plate(Vector3(size.x - 0.04, size.y - 0.04, 0.012), c + Vector3(0, 0, -0.02), "window_lit" if lit else "glass", GLASS)
	k.part(BuildingKit.shape("ribbon|%.2f|%.2f|%d" % [size.x, size.y, panes], func() -> Array:
		var out: Array = []
		for sy: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(size.x, 0.06, 0.07), Vector3(0, sy * (size.y * 0.5 - 0.03), 0)))
		for i in panes + 1:
			out.append(BuildingKit.piece(Vector3(0.05, size.y - 0.08, 0.06), Vector3(-size.x * 0.5 + 0.025 + i * (size.x - 0.05) / panes, 0, 0)))
		return out), kind, Transform3D(Basis.IDENTITY, c), col)
	k.plate(Vector3(size.x + 0.06, 0.03, 0.1), c + Vector3(0, -size.y * 0.5 - 0.015, 0.04), "steel", Color(0.5, 0.5, 0.48), Vector3(0.15, 0, 0))
