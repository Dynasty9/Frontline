class_name BuildingCargo
extends RefCounted

## Stores stacked in the open the way a quartermaster leaves them: framed
## shipping crates and painted ammunition boxes, each load on its pallet.
## The cover crate stacks (Structure "crates") are drawn with these, inside
## the boxes their parts give for cover.

const TIMBER := Color(0.66, 0.53, 0.36)  # new pine, a season out of doors
const OLIVE := Color(0.3, 0.3, 0.2)  # the army's olive drab
const BAND := Color(0.2, 0.21, 0.21)  # blued steel strapping, hasps and hinges
const ROPE := Color(0.55, 0.5, 0.36)
const STENCIL := Color(0.07, 0.07, 0.065)
const STENCIL_PALE := Color(0.8, 0.78, 0.68)  # (on a painted crate)
const HE_YELLOW := Color(0.72, 0.58, 0.16)  # the band round a box of high explosive

const BATTEN := 0.075  # how wide a crate's frame battens are
const PROUD := 0.022  # and how far they stand off its boards

## The lot numbers the stencils are cut for (a dump's stores come in a few
## consignments, so the same numbers turn up box after box).
const LOTS := [1043, 2417, 3388, 5160, 7092, 8815]

## The sizes the stores come in (fixed, so every crate of a kind shares its meshes).
const AMMO := Vector3(0.78, 0.3, 0.42)
const CRATE_LOW := Vector3(1.05, 0.62, 0.95)
const CRATE_TALL := Vector3(1.1, 0.95, 1.05)
const CRATE_TOP := Vector3(1.0, 0.85, 0.95)
const PALLET := Vector2(1.15, 1.1)
const DECK := 0.13  # how high a pallet's deck is


## A cover crate stack, `k` at its middle on the ground: variant 0 one pallet
## load about 1.2 m each way, variant 1 two loads side by side 2.5 m long with
## a crate hoisted onto the left one and turned a little (as the parts are).
## Which loads, and how squarely each sits, comes from `seed_from`'s seed.
static func stack(k: BuildingKit, variant: int, seed_from: RandomNumberGenerator) -> void:
	# (a stream of its own, stirred: neighbouring seeds' first draws run alike)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_from.seed ^ 0x5ca1ab1e)
	if variant == 0:
		_load(k, Vector3.ZERO, rng.randi() % 3, rng)
		return
	for i in 2:
		var x := -0.62 if i == 0 else 0.62
		# (the left load carries the crate on top, so it's always a tall crate)
		var top := _load(k, Vector3(x, 0, 0), 2 if i == 0 else rng.randi() % 3, rng)
		if i == 0:
			var col := _timber(rng)
			shipping_crate(k, Vector3(-0.6, top, 0), CRATE_TOP, col, 0.15 + rng.randf_range(-0.04, 0.04), _lot(rng), _finish(col))
		elif top < 1.05 and rng.randf() < 0.6:
			# a box someone took off the pile and left on top of it
			ammo_box(k, Vector3(0.6 + rng.randf_range(-0.08, 0.08), top, rng.randf_range(-0.15, 0.15)), AMMO, _olive(rng), rng.randf_range(0.3, 1.2), _lot(rng))


## One pallet load at `base` (see _load), for whatever stacks stores: the
## town's supply dump. Returns how high the load stands.
static func pallet_load(k: BuildingKit, base: Vector3, kind: int, rng: RandomNumberGenerator) -> float:
	return _load(k, base, kind, rng)


## A row of ammunition boxes stacked `layers` high at `base` along x, `n` of
## them, as they're stood by a command post's door.
static func ammo_row(k: BuildingKit, base: Vector3, n: int, layers: int, rng: RandomNumberGenerator) -> void:
	var lot := _lot(rng)
	for i in n:
		for layer in layers:
			if layer == layers - 1 and rng.randf() < 0.3:
				continue  # (the top one's been taken)
			ammo_box(k, base + Vector3(i * (AMMO.x + 0.04), layer * AMMO.y, rng.randf_range(-0.03, 0.03)), AMMO, _olive(rng), rng.randf_range(-0.06, 0.06), lot, layer == 0)


## A pallet at `base` with its load: 0 a low crate with two ammunition boxes
## on it, 1 three layers of ammunition boxes (the top one laid across, to tie
## the stack), 2 a tall crate. Returns how high the load stands.
static func _load(k: BuildingKit, base: Vector3, kind: int, rng: RandomNumberGenerator) -> float:
	var turn := rng.randf_range(-0.04, 0.04)
	var p := k.at_point(base, Vector3(0, turn, 0))
	BuildingFittings.pallet(p, Vector3.ZERO, PALLET, Res.vary(Color(0.55, 0.45, 0.32), 0.05, rng))
	match kind:
		0:
			var col := _timber(rng)
			shipping_crate(p, Vector3(0, DECK, 0), CRATE_LOW, col, rng.randf_range(-0.03, 0.03), _lot(rng), _finish(col))
			var lot := _lot(rng)
			for sz: float in [-1.0, 1.0]:
				ammo_box(p, Vector3(rng.randf_range(-0.04, 0.04), DECK + CRATE_LOW.y, sz * 0.225), AMMO, _olive(rng), rng.randf_range(-0.05, 0.05), lot)
			return DECK + CRATE_LOW.y + AMMO.y
		1:
			var lot := _lot(rng)
			for layer in 3:
				for s: float in [-1.0, 1.0]:
					var y := DECK + layer * AMMO.y
					if layer < 2:
						ammo_box(p, Vector3(0, y, s * 0.225), AMMO, _olive(rng), rng.randf_range(-0.02, 0.02), lot, layer == 1)
					else:
						ammo_box(p, Vector3(s * 0.225, y, 0), AMMO, _olive(rng), PI * 0.5 + rng.randf_range(-0.03, 0.03), lot)
			return DECK + AMMO.y * 3.0
	var col := _timber(rng)
	shipping_crate(p, Vector3(0, DECK, 0), CRATE_TALL, col, rng.randf_range(-0.03, 0.03), _lot(rng), _finish(col))
	return DECK + CRATE_TALL.y


## A crate's colour: bare pine, or (a third of them, the army's own) olive drab.
static func _timber(rng: RandomNumberGenerator) -> Color:
	return Res.vary(TIMBER, 0.07, rng) if rng.randf() < 0.66 else Res.vary(OLIVE.lightened(0.06), 0.05, rng)


## What a crate of that colour is finished in (painted if it's olive).
static func _finish(c: Color) -> String:
	return "wood" if c.r > c.g else "wood_painted"


static func _olive(rng: RandomNumberGenerator) -> Color:
	return Res.vary(OLIVE, 0.06, rng)


static func _lot(rng: RandomNumberGenerator) -> int:
	return LOTS[rng.randi() % LOTS.size()]


## A framed shipping crate `size` (to the outside of its battens) standing at
## `base`, turned `yaw`: boards inside a frame of battens, a brace corner to
## corner across each long face to keep it square, cleats over the lid, a
## steel band round it towards each end, and the shipper's stencil: the lot
## number and the this-way-up arrows on the ends, the number on the lid.
static func shipping_crate(k: BuildingKit, base: Vector3, size: Vector3, col: Color, yaw := 0.0, lot := 1043, kind := "wood") -> void:
	var c := k.at_point(base, Vector3(0, yaw, 0))
	var boards := size - Vector3(PROUD * 2.0, PROUD, PROUD * 2.0)
	var ink := STENCIL if kind == "wood" else STENCIL_PALE
	c.box(boards, Vector3(0, boards.y * 0.5, 0), kind, col)
	c.part(_frame(size), kind, Transform3D.IDENTITY, col.darkened(0.1))
	c.part(_bands(size), "steel", Transform3D.IDENTITY, BAND, false)
	for sx: float in [-1.0, 1.0]:
		var end := c.at_point(Vector3(sx * (size.x * 0.5 - PROUD), size.y * 0.5, 0), Vector3(0, sx * PI * 0.5, 0))
		end.part(_stencil(lot, 0.1, true), "paint", Transform3D.IDENTITY, ink, false)
	# (on the lid, between the middle cleat and a band)
	var lid := c.at_point(Vector3(size.x * 0.2, size.y - PROUD, 0), Vector3(-PI * 0.5, 0, 0))
	lid.part(_stencil(lot, 0.07, false), "paint", Transform3D.IDENTITY, ink, false)


## An ammunition box `size` at `base`, turned `yaw`: wood painted olive drab,
## the lid a shade lighter where the sun gets it, hinged along the back and
## shut by two hasps at the front, a cleat on each end that the rope handle
## goes through, and on the front its lot number and (`marked`) the yellow
## band of high explosive.
static func ammo_box(k: BuildingKit, base: Vector3, size: Vector3, col: Color, yaw := 0.0, lot := 1043, marked := true) -> void:
	var c := k.at_point(base, Vector3(0, yaw, 0))
	var lid := 0.07
	# (sharp-edged boards, not the rounded corners of a moulded case)
	c.part(BuildingKit.plain(Vector3(size.x, size.y - lid, size.z)), "wood_painted", Mats.place(Vector3(0, (size.y - lid) * 0.5, 0)), col)
	c.part(BuildingKit.plain(Vector3(size.x + 0.012, lid, size.z + 0.012)), "wood_painted", Mats.place(Vector3(0, size.y - lid * 0.5, 0)), col.lightened(0.05))
	c.part(_ammo_fittings(size, lid), "wood_painted", Transform3D.IDENTITY, col.darkened(0.12))
	c.part(_ammo_iron(size, lid), "steel", Transform3D.IDENTITY, BAND, false)
	c.part(_ammo_rope(size, lid), "canvas", Transform3D.IDENTITY, ROPE, false)
	var front := c.at_point(Vector3(0, 0, size.z * 0.5), Vector3.ZERO)
	if marked:
		front.plate(Vector3(size.x * 0.5, 0.032, 0.003), Vector3(0, (size.y - lid) * 0.72, 0.0015), "paint", HE_YELLOW)
	front.part(_stencil(lot, 0.05, false), "paint", Mats.place(Vector3(0, (size.y - lid) * 0.36, 0), Vector3.ZERO), STENCIL, false)


## A crate's battens as one mesh (cached by size): round each long face and a
## brace across it, round each end, and round the lid with a cleat across it.
static func _frame(size: Vector3) -> ArrayMesh:
	return BuildingKit.shape("crate_frame|%.3f|%.3f|%.3f" % [size.x, size.y, size.z], func() -> Array:
		var out: Array = []
		var w := BATTEN
		var t := PROUD
		for sz: float in [-1.0, 1.0]:
			var z := sz * (size.z * 0.5 - t * 0.5)
			out.append(BuildingKit.piece(Vector3(size.x, w, t), Vector3(0, w * 0.5, z)))
			out.append(BuildingKit.piece(Vector3(size.x, w, t), Vector3(0, size.y - w * 0.5, z)))
			for sx: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(w, size.y - w * 2.0, t), Vector3(sx * (size.x - w) * 0.5, size.y * 0.5, z)))
			var run := Vector2(size.x - w * 2.0, size.y - w * 2.0)
			out.append(BuildingKit.piece(Vector3(run.length(), w, t), Vector3(0, size.y * 0.5, z), Vector3(0, 0, atan2(run.y, run.x) * sz)))
		for sx: float in [-1.0, 1.0]:
			var x := sx * (size.x * 0.5 - t * 0.5)
			out.append(BuildingKit.piece(Vector3(t, w, size.z - t * 2.0), Vector3(x, w * 0.5, 0)))
			out.append(BuildingKit.piece(Vector3(t, w, size.z - t * 2.0), Vector3(x, size.y - w * 0.5, 0)))
			for sz: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(t, size.y - w * 2.0, w), Vector3(x, size.y * 0.5, sz * (size.z * 0.5 - t - w * 0.5))))
		for sz: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(size.x - t * 2.0, t, w), Vector3(0, size.y - t * 0.5, sz * (size.z * 0.5 - t - w * 0.5))))
		for sx: float in [-1.0, 0.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(w, t, size.z - (t + w) * 2.0), Vector3(sx * (size.x * 0.5 - t - w * 0.5), size.y - t * 0.5, 0)))
		return out)


## A crate's two steel bands, over the lid and down both long faces.
static func _bands(size: Vector3) -> ArrayMesh:
	return BuildingKit.shape("crate_bands|%.3f|%.3f|%.3f" % [size.x, size.y, size.z], func() -> Array:
		var out: Array = []
		for sx: float in [-1.0, 1.0]:
			var x := sx * size.x * 0.36
			out.append(BuildingKit.piece(Vector3(0.032, 0.004, size.z + 0.008), Vector3(x, size.y + 0.002, 0)))
			for sz: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(0.032, size.y, 0.004), Vector3(x, size.y * 0.5, sz * (size.z * 0.5 + 0.002))))
		return out)


## An ammunition box's wooden cleats: one across each end, under the lid.
static func _ammo_fittings(size: Vector3, lid: float) -> ArrayMesh:
	return BuildingKit.shape("ammo_cleats|%.3f|%.3f|%.3f" % [size.x, size.y, size.z], func() -> Array:
		var out: Array = []
		for sx: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.026, size.y - lid - 0.05, size.z * 0.74), Vector3(sx * (size.x * 0.5 + 0.013), (size.y - lid) * 0.5, 0)))
		return out)


## Its rope handles: a loop through each end cleat, hanging slack against it.
static func _ammo_rope(size: Vector3, lid: float) -> ArrayMesh:
	return BuildingKit.shape("ammo_rope|%.3f|%.3f|%.3f" % [size.x, size.y, size.z], func() -> Array:
		var out: Array = []
		var y := (size.y - lid) * 0.5 + 0.03
		for sx: float in [-1.0, 1.0]:
			var x := sx * (size.x * 0.5 + 0.034)
			for sz: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(0.018, 0.075, 0.018), Vector3(x, y - 0.03, sz * 0.07), Vector3(sz * 0.35, 0, 0)))
			out.append(BuildingKit.piece(Vector3(0.018, 0.018, 0.12), Vector3(x, y - 0.065, 0)))
		return out)


## Its ironwork: the two hasps over the front of the lid, the hinges behind.
static func _ammo_iron(size: Vector3, lid: float) -> ArrayMesh:
	return BuildingKit.shape("ammo_iron|%.3f|%.3f|%.3f" % [size.x, size.y, size.z], func() -> Array:
		var out: Array = []
		for sx: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.045, 0.1, 0.008), Vector3(sx * size.x * 0.3, size.y - lid - 0.015, size.z * 0.5 + 0.01)))
			out.append(BuildingKit.piece(Vector3(0.09, 0.05, 0.006), Vector3(sx * size.x * 0.28, size.y - lid, -size.z * 0.5 - 0.009)))
		return out)


## A stencil (cached), facing +z on z = 0 with its middle at the origin: the
## lot number in figures `h` high, cut with the stencil's bridges (seven
## separate strokes a figure), and (`arrows`) the this-way-up mark beside it:
## two arrows standing on a bar.
static func _stencil(lot: int, h: float, arrows: bool) -> ArrayMesh:
	return BuildingKit.shape("stencil|%d|%.3f|%s" % [lot, h, arrows], func() -> Array:
		var out: Array = []
		var digits := str(lot)
		var cw := h * 0.6
		var gap := h * 0.3
		var span := digits.length() * cw + (digits.length() - 1) * gap
		# (the arrows take 1.6 figures' height to the right of the number)
		var x0 := -(span + (h * 1.6 if arrows else 0.0)) * 0.5
		var bridge := h * 0.04
		for i in digits.length():
			var at := x0 + i * (cw + gap)
			var lit: int = BuildingFittings._FIGURES[digits.unicode_at(i) - 48]
			for s in 7:
				if (lit & (1 << s)) == 0:
					continue
				var r: Array = BuildingFittings._SEGMENTS[s]
				var lo := Vector2(at + float(r[0]) * h, float(r[1]) * h - h * 0.5)
				var hi := Vector2(at + float(r[2]) * h, float(r[3]) * h - h * 0.5)
				# (shrunk a little each way: the bridges a stencil leaves between strokes)
				var sz := Vector2(maxf(hi.x - lo.x - bridge * 2.0, bridge), maxf(hi.y - lo.y - bridge * 2.0, bridge))
				out.append(BuildingKit.piece(Vector3(sz.x, sz.y, 0.002), Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.001)))
		if arrows:
			var bx := x0 + span + h * 1.1
			for j in 2:
				var x := bx + (j - 0.5) * h * 0.6
				out.append(BuildingKit.piece(Vector3(h * 0.12, h * 0.7, 0.002), Vector3(x, -h * 0.1, 0.001)))
				for side: float in [-1.0, 1.0]:
					out.append(BuildingKit.piece(Vector3(h * 0.12, h * 0.36, 0.002), Vector3(x + side * h * 0.1, h * 0.28, 0.001), Vector3(0, 0, side * 0.75)))
			out.append(BuildingKit.piece(Vector3(h * 1.0, h * 0.12, 0.002), Vector3(bx, -h * 0.52, 0.001)))
		return out)
