class_name BuildingFurnishings
extends RefCounted
## What makes a house somebody's home: curtains, blinds and nets at its
## windows, a lamp by the front door, flowers in a box under a window, a TV
## aerial on the roof; and inside, painted walls with a skirting, pictures, a
## mirror, a clock, shelves of books, a radiator under each window, a rug.
## Work in a face kit (see BuildingWalls: x along the face, y up, z out of
## it); for the inside of a wall, a kit turned to face into the room.
##
## Nothing in a room may stand where a man does: Cover puts fighting positions
## half a metre off both faces of every house wall, and men walk through the
## middle of the room. So the room's things hang on the walls (above head
## height when they stand out from them) or lie flat on the floor.

const FABRICS := [Color(0.55, 0.2, 0.16), Color(0.3, 0.42, 0.3), Color(0.75, 0.68, 0.5), Color(0.28, 0.33, 0.5),
	Color(0.62, 0.45, 0.22), Color(0.48, 0.3, 0.42), Color(0.8, 0.78, 0.72)]
const NETS := Color(0.86, 0.85, 0.8)
## Inside walls: distemper and paint in the colours people chose.
const INTERIORS := [Color(0.85, 0.8, 0.66), Color(0.72, 0.78, 0.68), Color(0.7, 0.76, 0.82), Color(0.84, 0.72, 0.66),
	Color(0.88, 0.86, 0.8), Color(0.8, 0.74, 0.56)]
const BOOKS := [Color(0.5, 0.16, 0.12), Color(0.18, 0.28, 0.45), Color(0.2, 0.36, 0.24), Color(0.72, 0.6, 0.3),
	Color(0.35, 0.22, 0.14), Color(0.6, 0.58, 0.52)]


# --- windows ---------------------------------------------------------------------------

## What hangs in a window `size` with its pane plane at `fp` (the frame's
## middle): "drapes" (a pair drawn to the sides, folded), "blind" (a roller
## blind half down), "nets" (a net across the lower panes) or "" for none.
## They hang just in front of the glass (the glass is opaque, so this is how
## they show through it), behind the glazing bars.
static func curtains(k: BuildingKit, fp: Vector3, size: Vector2, style: String, col: Color) -> void:
	var w := size.x - 0.14
	var h := size.y - 0.14
	var z := fp.z + 0.01
	match style:
		"drapes":
			var cw := w * 0.24
			for sx: float in [-1.0, 1.0]:
				k.part(drape_shape(Vector2(cw, h)), "canvas", Transform3D(Basis.IDENTITY, Vector3(fp.x + sx * (w - cw) * 0.5, fp.y, z)), col)
			k.plate(Vector3(w + 0.06, 0.035, 0.03), Vector3(fp.x, fp.y + h * 0.5 - 0.02, z + 0.006), "wood_dark", Color(0.3, 0.22, 0.15))
		"blind":
			var bh := h * 0.45
			k.plate(Vector3(w, bh, 0.006), Vector3(fp.x, fp.y + (h - bh) * 0.5, z), "canvas_white", col.lightened(0.35))
			k.plate(Vector3(w, 0.03, 0.016), Vector3(fp.x, fp.y + h * 0.5 - bh, z + 0.004), "wood", Color(0.5, 0.4, 0.28))
		"nets":
			var nh := h * 0.55
			k.plate(Vector3(w, nh, 0.005), Vector3(fp.x, fp.y - (h - nh) * 0.5, z), "canvas_white", NETS)


## A curtain gathered in folds: alternate pleats stand forward and back.
static func drape_shape(size: Vector2) -> ArrayMesh:
	return BuildingKit.shape("drape|%.2f|%.2f" % [size.x, size.y], func() -> Array:
		var out: Array = []
		var folds := maxi(3, int(size.x / 0.09))
		var fw := size.x / folds
		for i in folds:
			out.append(BuildingKit.piece(Vector3(fw * 1.08, size.y, 0.008), Vector3(-size.x * 0.5 + (i + 0.5) * fw, 0, 0.007 if i % 2 == 0 else -0.003), Vector3(0, 0.35 if i % 2 == 0 else -0.35, 0)))
		return out)


## Flowers in a box on a window's sill, `w` wide, whose top is at `y`: the
## box on two brackets, greenery and blooms in it.
static func window_box(k: BuildingKit, x: float, y: float, w: float, bloom: Color, box_col := Color(0.42, 0.3, 0.2)) -> void:
	var z := 0.17
	k.box(Vector3(w, 0.16, 0.18), Vector3(x, y + 0.08, z), "wood", box_col)
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.03, 0.12, 0.16), Vector3(x + sx * w * 0.36, y - 0.04, z - 0.03), "metal_dark", Color(0.18, 0.18, 0.17))
	k.part_with(Res.foliage_cards(false), Mats.leaf_cards(false), Transform3D(Basis.from_scale(Vector3(w * 0.5, 0.17, 0.12)), Vector3(x, y + 0.24, z)), Color(0.25, 0.4, 0.18), false)
	k.part_with(Res.foliage_cards(false), Mats.leaf_cards(false), Transform3D(Basis.from_scale(Vector3(w * 0.42, 0.11, 0.1)), Vector3(x, y + 0.3, z + 0.02)), bloom, false)


# --- outside ---------------------------------------------------------------------------

## A lantern on a bracket beside a door at `p` on the face: its glass lit at
## night like the windows.
static func lantern(k: BuildingKit, p: Vector3, col := Color(0.12, 0.12, 0.11)) -> void:
	k.plate(Vector3(0.1, 0.16, 0.02), p + Vector3(0, 0, 0.01), "metal_dark", col)
	k.bar(p + Vector3(0, 0.03, 0.01), p + Vector3(0, 0.08, 0.2), 0.025, 0.025, "metal_dark", col, false)
	var c := p + Vector3(0, -0.04, 0.22)
	k.plate(Vector3(0.16, 0.03, 0.16), c + Vector3(0, 0.14, 0), "metal_dark", col)
	k.plate(Vector3(0.12, 0.2, 0.12), c, "window_lit", BuildingOpenings.GLASS)
	k.plate(Vector3(0.14, 0.025, 0.14), c + Vector3(0, -0.11, 0), "metal_dark", col)


## A skylight let into a roof, in a kit lying on the slope: its frame and
## the glass (lit by night when there's a lamp on under it).
static func skylight(k: BuildingKit, lit := true) -> void:
	k.part(BuildingKit.shape("skylight", func() -> Array:
		var out: Array = []
		for sx: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.06, 0.07, 0.9), Vector3(sx * 0.33, 0.035, 0)))
		for sz: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.72, 0.07, 0.06), Vector3(0, 0.035, sz * 0.42)))
		return out), "metal_dark", Transform3D.IDENTITY, Color(0.22, 0.23, 0.22))
	k.plate(Vector3(0.6, 0.012, 0.78), Vector3(0, 0.06, 0), "window_lit" if lit else "glass", BuildingOpenings.GLASS)


## A TV aerial at `base` (on a chimney's side or the ridge): its pole and a
## Yagi aimed along `yaw` to the transmitter.
static func aerial(k: BuildingKit, base: Vector3, h := 1.6, yaw := 0.0) -> void:
	k.cyl(0.018, 0.022, h, base + Vector3(0, h * 0.5, 0), "steel", Color(0.55, 0.56, 0.55), Vector3.ZERO, 6, false)
	k.part(BuildingKit.shape("yagi", func() -> Array:
		var out: Array = [BuildingKit.piece(Vector3(1.1, 0.02, 0.02), Vector3(0.25, 0, 0))]
		for i in 7:
			var span := 0.5 - i * 0.04
			out.append(BuildingKit.piece(Vector3(0.012, 0.012, span), Vector3(-0.2 + i * 0.15, 0, 0)))
		out.append(BuildingKit.piece(Vector3(0.04, 0.05, 0.05), Vector3(-0.18, -0.02, 0)))
		return out), "steel", Mats.place(base + Vector3(0, h - 0.05, 0), Vector3(0, yaw, 0)), Color(0.6, 0.61, 0.6), false)


# --- inside ----------------------------------------------------------------------------

## The inside of a wall `length` wide and `height` tall: its paint, round the
## openings in `gaps`, and a skirting board along its foot.
static func lining(k: BuildingKit, length: float, height: float, gaps: Array, paint: Color) -> void:
	for r: Rect2 in panels(Rect2(-length * 0.5, 0.0, length, height), gaps):
		k.plate(Vector3(r.size.x, r.size.y, 0.006), Vector3(r.get_center().x, r.get_center().y, 0.003), "plaster", paint)
	for run: Vector2 in BuildingWalls.runs(-length * 0.5, length * 0.5, 0.0, 0.1, gaps):
		if run.y - run.x > 0.05:
			k.plate(Vector3(run.y - run.x, 0.1, 0.018), Vector3((run.x + run.y) * 0.5, 0.05, 0.012), "paint", Color(0.86, 0.84, 0.78))


## A rectangle less the openings in it, as the rectangles left (each opening
## takes out a column: what's left of the column above and below it, and the
## strips either side).
static func panels(area: Rect2, gaps: Array) -> Array[Rect2]:
	var out: Array[Rect2] = [area]
	for g: Rect2 in gaps:
		var next: Array[Rect2] = []
		for r in out:
			var cut := r.intersection(g)
			if cut.size.x <= 0.0 or cut.size.y <= 0.0:
				next.append(r)
				continue
			if cut.position.x > r.position.x:
				next.append(Rect2(r.position.x, r.position.y, cut.position.x - r.position.x, r.size.y))
			if cut.end.x < r.end.x:
				next.append(Rect2(cut.end.x, r.position.y, r.end.x - cut.end.x, r.size.y))
			if cut.position.y > r.position.y:
				next.append(Rect2(cut.position.x, r.position.y, cut.size.x, cut.position.y - r.position.y))
			if cut.end.y < r.end.y:
				next.append(Rect2(cut.position.x, cut.end.y, cut.size.x, r.end.y - cut.end.y))
		out = next
	return out


## A radiator under a window, `w` wide, standing just off the wall.
static func radiator(k: BuildingKit, x: float, w: float) -> void:
	k.part(BuildingKit.shape("radiator|%.2f" % w, func() -> Array:
		var out: Array = []
		var n := maxi(4, int(w / 0.16))
		for i in n:
			out.append(BuildingKit.piece(Vector3(w / n * 0.7, 0.52, 0.07), Vector3(-w * 0.5 + (i + 0.5) * w / n, 0.44, 0.06)))
		out.append(BuildingKit.piece(Vector3(w, 0.03, 0.03), Vector3(0, 0.69, 0.06)))
		out.append(BuildingKit.piece(Vector3(w, 0.03, 0.03), Vector3(0, 0.19, 0.06)))
		return out), "paint", Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)), Color(0.88, 0.87, 0.83))


## Something on a plain stretch of wall: a picture or two, a mirror, a clock,
## or a shelf of books above head height; now and then nothing.
static func wall_things(k: BuildingKit, length: float) -> void:
	var r := k.rng.randf()
	if r < 0.3:
		var n := 1 if length < 2.4 or k.rng.randf() < 0.5 else 2
		for i in n:
			var x := (float(i) - (n - 1) * 0.5) * 0.9 + k.rng.randf_range(-0.15, 0.15)
			var s := Vector2(k.rng.randf_range(0.35, 0.7), k.rng.randf_range(0.3, 0.55))
			picture(k, Vector3(x, k.rng.randf_range(1.5, 1.75), 0), s, FABRICS[k.rng.randi() % FABRICS.size()])
	elif r < 0.45:
		# a mirror in a frame
		k.plate(Vector3(0.5, 0.75, 0.025), Vector3(0, 1.55, 0.012), "wood_dark", Color(0.35, 0.25, 0.15))
		k.plate(Vector3(0.42, 0.67, 0.006), Vector3(0, 1.55, 0.027), "glass", Color(0.2, 0.24, 0.28))
	elif r < 0.55:
		# a clock
		k.cyl(0.17, 0.17, 0.05, Vector3(0, 2.1, 0.025), "wood_dark", Color(0.35, 0.25, 0.15), Vector3(PI * 0.5, 0, 0), 10, false)
		k.cyl(0.14, 0.14, 0.01, Vector3(0, 2.1, 0.052), "paint", Color(0.9, 0.88, 0.82), Vector3(PI * 0.5, 0, 0), 10, false)
		k.plate(Vector3(0.012, 0.1, 0.004), Vector3(0, 2.13, 0.06), "metal_dark", Color(0.1, 0.1, 0.1))
	elif r < 0.85:
		shelf(k, Vector3(k.rng.randf_range(-0.2, 0.2), 2.0, 0), minf(length - 0.6, 1.4))


## A picture `size` hung at `c`: its frame, the canvas, the paint on it.
static func picture(k: BuildingKit, c: Vector3, size: Vector2, col: Color) -> void:
	k.plate(Vector3(size.x, size.y, 0.025), c + Vector3(0, 0, 0.0125), "wood_dark", Color(0.42, 0.3, 0.16))
	k.plate(Vector3(size.x - 0.07, size.y - 0.07, 0.004), c + Vector3(0, 0, 0.026), "canvas_white", Color(0.84, 0.82, 0.74))
	k.plate(Vector3(size.x * 0.6, size.y * 0.45, 0.004), c + Vector3(0, -size.y * 0.06, 0.03), "paint", col)


## A shelf `w` long on brackets with its books along it, its top at `c.y`
## (kept above a standing man's head).
static func shelf(k: BuildingKit, c: Vector3, w: float) -> void:
	k.plate(Vector3(w, 0.03, 0.24), c + Vector3(0, -0.015, 0.12), "wood", Color(0.46, 0.34, 0.2), Vector3.ZERO, true)
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.025, 0.16, 0.18), c + Vector3(sx * w * 0.38, -0.11, 0.09), "metal_dark", Color(0.2, 0.2, 0.19))
	# the books in runs of a binding each (a set, a shelf of paperbacks), with
	# gaps where some were taken down
	var x := -w * 0.5 + 0.04
	while x < w * 0.5 - 0.1:
		var bw := minf(k.rng.randf_range(0.08, 0.22), w * 0.5 - 0.04 - x)
		var bh := k.rng.randf_range(0.17, 0.26)
		if k.rng.randf() < 0.2:
			x += 0.12
			continue
		k.plate(Vector3(bw, bh, k.rng.randf_range(0.14, 0.2)), c + Vector3(x + bw * 0.5, bh * 0.5, 0.1), "paint", BOOKS[k.rng.randi() % BOOKS.size()])
		x += bw + 0.012


## A rug on a floor, `size` across, lying flat (nothing to trip a man).
static func rug(k: BuildingKit, c: Vector3, size: Vector2, col: Color, yaw := 0.0) -> void:
	k.plate(Vector3(size.x, 0.008, size.y), c + Vector3(0, 0.004, 0), "canvas", col.darkened(0.35), Vector3(0, yaw, 0))
	k.plate(Vector3(size.x - 0.2, 0.008, size.y - 0.2), c + Vector3(0, 0.009, 0), "canvas", col, Vector3(0, yaw, 0))
