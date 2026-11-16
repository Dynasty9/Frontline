class_name BuildingFences
extends RefCounted
## Fences, put up the way they really are: posts set in the ground at each
## bay, rails or wires strained between them, the infill fixed to the rails.
## A piece of fence is one bay (Decor gets the town's runs cut into bays of
## at most 2.2 m); it climbs with the ground between its two posts, its
## uprights kept plumb, as a fence on a slope is built.
##
## Garden and field fences:
##   PICKET      - painted pickets with pointed tops nailed to two back rails,
##                 square posts under pyramid caps
##   POST_RAIL   - a farm's post and rail: weathered posts, three rails nailed
##                 to their faces, the odd rail split and hanging
##   RAILINGS    - painted steel railings with spear tops; a front garden's
##                 stand on a dwarf brick wall
##   CLOSE_BOARD - a garden's privacy fence: featheredge boards lapped on arris
##                 rails over a concrete gravel board, capped
##   PALING      - cleft chestnut paling: rough split stakes woven into twisted
##                 wire, on round posts
##   CHAIN_LINK  - galvanised (or green-coated) chain-link on tube posts, a top
##                 rail and a tension wire along the foot
##   BOW_TOP     - a playground's bow-top railings, overlapping hoops along the top
## Military:
##   SECURITY    - a 2.4 m perimeter: chain-link on posts set in concrete, a
##                 Y-arm outrigger with barbed strands each side and a razor coil
##                 in the V, warning signs wired on
##   PANELS      - temporary welded-mesh panels standing in concrete feet,
##                 coupled at the joints, some hung with olive drab scrim, stayed
##                 and weighted with sandbags
##   IMPROVISED  - the Rebels' perimeter: crooked stakes and the odd steel
##                 picket, slack rusted barbed wire (a strand snapped here and
##                 there), roofing sheets and pallets wired into the gaps, a
##                 rusty coil dragged along the outside
##
## The code Decor stores packs the style (low four bits) with LINKED (the next
## bay's first post is this one's last), GATE (a gate leaf in the opening, not
## a bay) and a variant (bits 6-8: the paint, which posts) the whole run shares.

const PICKET := 0
const POST_RAIL := 1
const RAILINGS := 2
const CLOSE_BOARD := 3
const PALING := 4
const CHAIN_LINK := 5
const BOW_TOP := 6
const SECURITY := 7
const PANELS := 8
const IMPROVISED := 9

const LINKED := 16
const GATE := 32
const VARIANT := 64  # (variant * VARIANT)

## Picket paint: white, cream, sage, a faded blue-grey, and a brown stain.
const PICKET_PAINT := [Color(0.8, 0.79, 0.74), Color(0.78, 0.73, 0.6), Color(0.52, 0.6, 0.52), Color(0.5, 0.57, 0.62), Color(0.42, 0.31, 0.21)]
## Railing paint: black, Brunswick green, a dark blue, and oxide red.
const RAIL_PAINT := [Color(0.09, 0.09, 0.09), Color(0.1, 0.2, 0.13), Color(0.11, 0.14, 0.22), Color(0.3, 0.13, 0.09)]
## Board and post timber: weathered silver-brown, a brown stain, fresh green
## pressure-treated, dark creosote.
const TIMBER := [Color(0.5, 0.45, 0.37), Color(0.4, 0.29, 0.19), Color(0.47, 0.45, 0.33), Color(0.27, 0.2, 0.14)]
## Chain-link: galvanised, green plastic-coated, black.
const LINK_COLOURS := [Color(0.58, 0.59, 0.58), Color(0.16, 0.27, 0.17), Color(0.1, 0.1, 0.1)]
const GALV := Color(0.66, 0.67, 0.66)
const OD := Color(0.3, 0.33, 0.22)

static var _meshes := {}


## Packs a run's style, its variant and the flags into the code Decor stores.
static func code(style: int, variant := 0, flags := 0) -> int:
	return style | flags | (variant << 6)


static func style_of(c: int) -> int:
	return c & 15


static func variant_of(c: int) -> int:
	return (c >> 6) & 7


## One bay `length` long and `height` tall along x, centred on x = 0, the
## ground `y0` under its first post and `y1` under its last (in k's frame).
static func bay(k: BuildingKit, length: float, height: float, c: int, y0 := 0.0, y1 := 0.0) -> void:
	var style := style_of(c)
	var v := variant_of(c)
	# a frame sheared to climb with the ground: x runs along the line at the
	# ground's height, y stays plumb, so every upright stands straight
	var slope := clampf((y1 - y0) / maxf(length, 0.05), -0.6, 0.6)
	var sk := k.moved(Transform3D(Basis(Vector3(1, slope, 0), Vector3.UP, Vector3.BACK), Vector3(0, (y0 + y1) * 0.5, 0)))
	# every part casts (a bake makes a mesh per surface and shadow setting,
	# so a few shadowless trims would cost a chunk a draw call each)
	var was := k.sink.cast_all
	k.sink.cast_all = true
	if c & GATE:
		_gate(sk, style, v, length, height)
		k.sink.cast_all = was
		return
	var posts: Array[float] = [-length * 0.5]
	if not (c & LINKED):
		posts.append(length * 0.5)
	match style:
		PICKET:
			_picket(sk, length, height, v, posts)
		POST_RAIL:
			_post_rail(sk, length, height, v, posts)
		RAILINGS:
			_railings(sk, length, height, v, posts)
		CLOSE_BOARD:
			_close_board(sk, length, height, v, posts)
		PALING:
			_paling(sk, length, height, v, posts)
		CHAIN_LINK:
			_chain_link(sk, length, height, v, posts)
		BOW_TOP:
			_bow_top(sk, length, height, v, posts)
		SECURITY:
			_security(sk, length, height, v, posts)
		PANELS:
			_panels(sk, length, height, v, posts)
		IMPROVISED:
			_improvised(sk, length, height, v, posts)
		_:
			_picket(sk, length, height, v, posts)
	k.sink.cast_all = was


## (a cached panel `length` long is built once at the nearest 5 cm and
## stretched the last few millimetres: the eye can't tell, the town shares it)
static func _panel(k: BuildingKit, key: String, length: float, build: Callable, kind: String, col: Variant, shadow := true) -> void:
	k.part(_cached(key, length, build), kind, _stretch(length), col, shadow)


static func _join(pieces: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for piece: Array in pieces:
		var fa := Mats._flat(piece[0], 0)
		var xf: Transform3D = piece[1]
		v.append_array(xf * (fa[0] as PackedVector3Array))
		n.append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (fa[1] as PackedVector3Array))
	return BuildingKit._commit(v, n)


## Grass and weeds come up along the foot of a fence nobody strims.
static func _weeds(k: BuildingKit, length: float, chance: float) -> void:
	if k.rng.randf() < chance:
		BuildingWeathering.weeds(k, length, [], k.rng, 0.0)


# --- wood -------------------------------------------------------------------------------

static func _picket(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var paint: Color = PICKET_PAINT[v % PICKET_PAINT.size()]
	var col := Res.vary(paint, 0.04, k.rng)
	for x in posts:
		_square_post(k, x, 0.09, height + 0.06, "fence_painted", col, true)
	# a picket gone (kicked in, burned for the stove) or hanging off its nail
	var damage := 0 if k.rng.randf() < 0.7 else k.rng.randi_range(1, 3)
	var h := height
	var build := func(lk: float) -> ArrayMesh:
		var pieces := []
		for y in [h * 0.2, h * 0.7]:
			pieces.append(BuildingKit.piece(Vector3(lk, 0.07, 0.03), Vector3(0, y, 0.035)))
		var n := maxi(2, int(lk / 0.13))
		var drop := -1 if damage == 0 else (damage * 5) % n
		for i in n:
			if damage >= 2 and (i == drop or (damage == 3 and i == (drop + 3) % n)):
				continue
			var x := -lk * 0.5 + (i + 0.5) * lk / n
			var lean := 0.0 if i != drop else 0.32
			var pk := Transform3D(Basis(Vector3.BACK, lean), Vector3(x, 0.04, 0)) if lean != 0.0 else Transform3D(Basis.IDENTITY, Vector3(x, 0.04, 0))
			var ph := h - 0.1
			pieces.append([BuildingKit.plain(Vector3(0.075, ph, 0.02)), pk * Transform3D(Basis.IDENTITY, Vector3(0, ph * 0.5, 0))])
			pieces.append([Res.prism(Vector3(0.075, 0.07, 0.02)), pk * Transform3D(Basis.IDENTITY, Vector3(0, ph + 0.035, 0))])
		return _join(pieces)
	_panel(k, "picket%d|%.2f" % [damage, h], length, build, "fence_painted", col)
	_weeds(k, length, 0.5)


static func _post_rail(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(TIMBER[v % 2 * 3], 0.12, k.rng)  # weathered or creosoted
	for x in posts:
		var lean := Vector3(k.rng.randf_range(-0.035, 0.035), 0, k.rng.randf_range(-0.04, 0.04))
		var ht := height + k.rng.randf_range(0.0, 0.12)
		k.part(Res.box(Vector3(0.13, ht + 0.2, 0.12)), "fence_wood", Transform3D(Basis.from_euler(lean), Vector3(x, (ht - 0.2) * 0.5, 0)), col.darkened(k.rng.randf_range(0.0, 0.15)))
	# rails nailed to the posts' faces, each a little bowed and not quite level
	for i in 3:
		var y: float = height * [0.24, 0.55, 0.86][i]
		var a := Vector3(-length * 0.5 - 0.05, y + k.rng.randf_range(-0.03, 0.03), -0.085)
		var b := Vector3(length * 0.5 + 0.05, y + k.rng.randf_range(-0.03, 0.03), -0.085)
		var rc := col.darkened(k.rng.randf_range(0.0, 0.18))
		if k.rng.randf() < 0.06:
			# split at a knot: one half still nailed, the other end down in the grass
			var m := a.lerp(b, k.rng.randf_range(0.35, 0.6))
			k.beam(a, m, 0.11, 0.04, "fence_rail", rc)
			k.beam(m + Vector3(0.05, 0, 0), Vector3(b.x, 0.06, -0.2), 0.11, 0.04, "fence_rail", rc)
			continue
		k.beam(a, (a + b) * 0.5 - Vector3(0, 0.015, 0), 0.11, 0.04, "fence_rail", rc)
		k.beam((a + b) * 0.5 - Vector3(0, 0.015, 0), b, 0.11, 0.04, "fence_rail", rc)
	if v % 2 == 1:
		# a strand of barbed wire stapled along the post tops to keep the stock
		# off the rails, gone rusty and slack
		BuildingWire.barbed(k, Vector3(-length * 0.5, height + 0.08, -0.07), Vector3(length * 0.5, height + 0.08, -0.07), 0.03, 0.12, "rust")
	_weeds(k, length, 0.8)


static func _close_board(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(TIMBER[v % TIMBER.size()], 0.06, k.rng)
	var concrete_posts := v >= 4
	for x in posts:
		if concrete_posts:
			_square_post(k, x, 0.1, height + 0.02, "concrete", Color(0.55, 0.54, 0.5), false)
		else:
			_square_post(k, x, 0.1, height + 0.04, "fence_wood", col.darkened(0.08), false)
	# the concrete gravel board along the foot, the boards over it, the capping
	k.box(Vector3(length, 0.15, 0.04), Vector3(0, 0.075, 0.0), "concrete", Color(0.52, 0.51, 0.47))
	var h := height - 0.18
	# a bay stove in (a vehicle backed into it, someone kicked a way through):
	# boards gone, one snapped off, the pieces lying at its foot
	var broken := 1 if k.rng.randf() < 0.12 else 0
	_panel(k, "featheredge%d|%.2f" % [broken, h], length, func(lk: float) -> ArrayMesh: return _featheredge(lk, h, broken), "fence_wood", col)
	if broken:
		for i in 2:
			k.plate(Vector3(0.1, h * k.rng.randf_range(0.4, 0.8), 0.015), Vector3(k.rng.randf_range(-0.3, 0.4), 0.02, -0.25 - i * 0.12), "fence_wood",
				col.darkened(0.1), Vector3(-PI * 0.5 + 0.06, k.rng.randf_range(-0.6, 0.6), 0), true)
	k.plate(Vector3(length, 0.022, 0.13), Vector3(0, height - 0.01, 0.01), "fence_rail", col.darkened(0.12), Vector3.ZERO, true)
	k.plate(Vector3(length, 0.05, 0.02), Vector3(0, height - 0.05, -0.03), "fence_rail", col.darkened(0.06))
	# arris rails behind, the boards nailed to them
	for y in [0.4, height - 0.35] + ([height * 0.5] if height > 1.5 else []):
		k.part(BuildingKit.plain(Vector3(length, 0.07, 0.07)), "fence_rail", Transform3D(Basis(Vector3.RIGHT, PI * 0.25), Vector3(0, y, 0.035)), col.darkened(0.15), false)
	_weeds(k, length, 0.45)


## Featheredge boards 100 mm wide lapped 20 mm, wedge-thick: a sawtooth face
## towards -z, flat behind, from y = 0.17 for `h`.
static func _featheredge(lk: float, h: float, broken := 0) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var y0 := 0.17
	var n_b := maxi(1, int(lk / 0.08))
	var pitch := lk / n_b
	var gone := n_b / 2 - 1 if broken else -9
	for i in n_b:
		if i == gone or i == gone + 1:
			continue
		var x0 := -lk * 0.5 + i * pitch
		var x1 := x0 + pitch
		var y1 := y0 + h * (0.45 if i == gone + 2 else 1.0)
		BuildingKit._tri(v, n, Vector3(x0, y0, 0), Vector3(x1, y0, 0), Vector3(x1, y1, 0), Vector3.BACK)
		BuildingKit._tri(v, n, Vector3(x0, y0, 0), Vector3(x1, y1, 0), Vector3(x0, y1, 0), Vector3.BACK)
		var a := Vector3(x0, 0, -0.004)
		var b := Vector3(x1, 0, -0.018)
		var face := (b - a).cross(Vector3.UP).normalized()
		if face.z > 0.0:
			face = -face
		BuildingKit._tri(v, n, Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), face)
		BuildingKit._tri(v, n, Vector3(a.x, y0, a.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z), face)
		# the thick edge of each board, stepping back to the next
		BuildingKit._tri(v, n, Vector3(x1, y0, -0.018), Vector3(x1, y0, -0.004), Vector3(x1, y1, -0.004), Vector3.RIGHT)
		BuildingKit._tri(v, n, Vector3(x1, y0, -0.018), Vector3(x1, y1, -0.004), Vector3(x1, y1, -0.018), Vector3.RIGHT)
		if y1 < y0 + h:
			# the snapped top, splintered across
			BuildingKit._tri(v, n, Vector3(x0, y1, -0.004), Vector3(x1, y1, -0.018), Vector3(x1, y1, 0), Vector3.UP)
			BuildingKit._tri(v, n, Vector3(x0, y1, -0.004), Vector3(x1, y1, 0), Vector3(x0, y1, 0), Vector3.UP)
	return BuildingKit._commit(v, n)


static func _paling(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(Color(0.47, 0.37, 0.27), 0.1, k.rng)
	for x in posts:
		k.cyl(0.04, 0.045, height + 0.25, Vector3(x, (height - 0.25) * 0.5 + 0.02, 0.04), "fence_wood", col.darkened(0.15), Vector3.ZERO, 7)
	var h := height
	var shape := v % 4
	var build := func(lk: float) -> ArrayMesh:
		var r := RandomNumberGenerator.new()
		r.seed = 7721 + shape * 131 + int(lk * 100.0)
		var pieces := []
		var x := -lk * 0.5 + 0.03
		while x < lk * 0.5 - 0.03:
			var w := r.randf_range(0.04, 0.065)
			var ph := h + r.randf_range(-0.06, 0.03)
			var tilt := Basis.from_euler(Vector3(r.randf_range(-0.03, 0.03), r.randf_range(-0.3, 0.3), r.randf_range(-0.035, 0.035)))
			pieces.append([BuildingKit.plain(Vector3(w, ph - 0.06, 0.022)), Transform3D(tilt, Vector3(x + w * 0.5, (ph - 0.06) * 0.5, 0))])
			pieces.append([Res.prism(Vector3(w, 0.08, 0.022)), Transform3D(tilt, Vector3(x + w * 0.5, ph - 0.02, 0))])
			x += w + r.randf_range(0.045, 0.075)
		return _join(pieces)
	_panel(k, "paling%d|%.2f" % [shape, h], length, build, "fence_wood", col)
	# the paling's held in pairs of wire twisted round each stake
	for y in [0.15, h - 0.15] + ([h * 0.5] if h > 1.1 else []):
		k.rod(Vector3(-length * 0.5, y, 0.012), Vector3(length * 0.5, y - 0.01, 0.012), 0.0035, "galvanised", Color(0.36, 0.35, 0.33), 3, false)
	_weeds(k, length, 0.75)


# --- metal ------------------------------------------------------------------------------

static func _railings(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(RAIL_PAINT[v % RAIL_PAINT.size()], 0.05, k.rng)
	var base := 0.0
	if height < 0.95:
		# a front garden's railings stand on a dwarf wall of brick
		var brick := Res.vary(Color(0.52, 0.29, 0.21), 0.06, k.rng)
		base = 0.38
		k.box(Vector3(length + 0.01, base - 0.06, 0.23), Vector3(0, (base - 0.06) * 0.5, 0), "brick", brick)
		k.plate(Vector3(length + 0.01, 0.06, 0.27), Vector3(0, base - 0.03, 0), "concrete", Color(0.6, 0.59, 0.55), Vector3.ZERO, true)
	var h := height - (0.1 if base > 0.0 else 0.0)
	for x in posts:
		k.box(Vector3(0.05, h + 0.06, 0.05), Vector3(x, base + (h + 0.06) * 0.5, 0), "fence_metal", col)
		k.cyl(0.0, 0.035, 0.07, Vector3(x, base + h + 0.095, 0), "fence_metal", col, Vector3(0, PI * 0.25, 0), 4)
	var build := func(lk: float) -> ArrayMesh:
		var pieces := []
		for y in [0.07, h - 0.13]:
			pieces.append(BuildingKit.piece(Vector3(lk, 0.04, 0.014), Vector3(0, y, 0)))
		var n := maxi(2, int(lk / 0.115))
		for i in n:
			var x := -lk * 0.5 + (i + 0.5) * lk / n
			pieces.append(BuildingKit.piece(Vector3(0.015, h - 0.03, 0.015), Vector3(x, (h - 0.03) * 0.5, 0)))
			pieces.append([Res.cyl(0.0, 0.017, 0.07, 4), Mats.place(Vector3(x, h + 0.005, 0), Vector3(0, PI * 0.25, 0))])
		return _join(pieces)
	k.moved(Transform3D(Basis.IDENTITY, Vector3(0, base, 0))).part(_cached("rail|%.2f" % h, length, build), "fence_metal", _stretch(length), col)


static func _bow_top(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(Color(0.12, 0.26, 0.15) if v % 2 == 0 else Color(0.08, 0.08, 0.08), 0.05, k.rng)
	for x in posts:
		k.box(Vector3(0.06, height + 0.04, 0.06), Vector3(x, (height + 0.04) * 0.5, 0), "fence_metal", col)
		k.cyl(0.02, 0.04, 0.03, Vector3(x, height + 0.055, 0), "fence_metal", col, Vector3.ZERO, 8)
	var h := height
	var build := func(lk: float) -> ArrayMesh:
		var pieces := []
		var top := h - 0.2
		for y in [0.07, top]:
			pieces.append(BuildingKit.piece(Vector3(lk, 0.03, 0.012), Vector3(0, y, 0)))
		var n := maxi(2, int(lk / 0.13))
		var s := lk / n
		for i in n:
			var x := -lk * 0.5 + (i + 0.5) * s
			pieces.append(BuildingKit.piece(Vector3(0.013, top - 0.07, 0.013), Vector3(x, (top + 0.07) * 0.5, 0)))
		# the hoops, each over two bars, every one overlapping the next
		var mesh := ArrayMesh.new()
		var vv := PackedVector3Array()
		var nn := PackedVector3Array()
		for i in n - 1:
			var cx := -lk * 0.5 + (i + 1.0) * s
			var pts := PackedVector3Array()
			for j in 9:
				var a := PI * float(j) / 8.0
				pts.append(Vector3(cx + cos(a) * s, top + sin(a) * 0.18, 0))
			BuildingWire.strand(vv, nn, pts, 0.008)
		mesh = BuildingKit._commit(vv, nn)
		pieces.append([mesh, Transform3D.IDENTITY])
		return _join(pieces)
	k.part(_cached("bow|%.2f" % h, length, build), "fence_metal", _stretch(length), col)


static func _chain_link(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col: Color = LINK_COLOURS[v % LINK_COLOURS.size()]
	var kind := "galvanised" if v % LINK_COLOURS.size() == 0 else "fence_metal"
	for x in posts:
		k.cyl(0.024, 0.024, height + 0.1, Vector3(x, (height - 0.1) * 0.5 + 0.05, 0.03), kind, col, Vector3.ZERO, 8)
		k.cyl(0.012, 0.03, 0.04, Vector3(x, height + 0.04, 0.03), kind, col, Vector3.ZERO, 8)
	k.rod(Vector3(-length * 0.5, height - 0.02, 0.03), Vector3(length * 0.5, height - 0.02, 0.03), 0.017, kind, col, 6)
	k.rod(Vector3(-length * 0.5, 0.06, 0.008), Vector3(length * 0.5, 0.06, 0.008), 0.003, kind, col, 3, false)
	mesh_panel(k, length, 0.03, height - 0.03, Vector3(0, 0, 0.008), col, false)
	_weeds(k, length, 0.6)


## A sheet of wire mesh `length` across from `y0` to `y1` at `at` in the
## kit's frame: chain-link diamonds or a welded grid, drawn by Mats.wire_mesh.
static func mesh_panel(k: BuildingKit, length: float, y0: float, y1: float, at: Vector3, col: Color, welded: bool) -> void:
	var xf := Transform3D(Basis.from_scale(Vector3(length, y1 - y0, 1)), at + Vector3(0, (y0 + y1) * 0.5, 0))
	# (it casts none: a shadow can't be see-through, and a solid one is wrong)
	var was := k.sink.cast_all
	k.sink.cast_all = false
	k.part_with(Res.quad(Vector2.ONE), Mats.wire_mesh(welded), xf, col, false)
	k.sink.cast_all = was


# --- military ---------------------------------------------------------------------------

static func _security(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := GALV
	for x in posts:
		k.cyl(0.038, 0.038, height + 0.1, Vector3(x, (height - 0.1) * 0.5, 0.04), "galvanised", col, Vector3.ZERO, 8)
		k.cyl(0.16, 0.19, 0.12, Vector3(x, 0.03, 0.04), "concrete", Color(0.55, 0.54, 0.5), Vector3.ZERO, 10)
		# the Y-arm, an angle-iron V clamped to the post's head
		for sd: float in [-1.0, 1.0]:
			k.beam(Vector3(x, height - 0.02, 0.04), Vector3(x, height + 0.42, 0.04 + sd * 0.42), 0.04, 0.006, "galvanised", col.darkened(0.1))
	# the line, tension and stretcher wires, and the mesh between them
	for y in [0.06, height * 0.5, height - 0.04]:
		k.rod(Vector3(-length * 0.5, y, 0.012), Vector3(length * 0.5, y, 0.012), 0.0035, "wire", null, 3, false)
	mesh_panel(k, length, 0.02, height, Vector3(0, 0, 0.01), col, false)
	# three barbed strands up each arm
	var x0 := -length * 0.5
	var x1 := length * 0.5
	for sd: float in [-1.0, 1.0]:
		for i in 3:
			var f := (i + 1) / 3.0
			var p := Vector3(0, height - 0.02 + 0.44 * f, 0.04 + sd * 0.42 * f)
			BuildingWire.barbed(k, Vector3(x0, p.y, p.z), Vector3(x1, p.y, p.z), 0.015, 0.11, "military")
	# razor coil laid in the V
	k.part(_cached("razor|%.2f" % height, length, func(lk: float) -> ArrayMesh: return _razor_coil(lk, height)), "wire_military", _stretch(length), null, false)
	if k.rng.randf() < 0.3:
		_warning_sign(k, k.rng.randf_range(-length * 0.25, length * 0.25), 1.55, -0.005)
	if k.rng.randf() < 0.3:
		# a floodlight on a bracket, turned out over the wire, its cable down the post
		var px: float = posts[0]
		var lamp := k.at_point(Vector3(px, height - 0.25, 0.04))
		lamp.beam(Vector3.ZERO, Vector3(0, 0.05, -0.32), 0.03, 0.03, "galvanised", GALV.darkened(0.1))
		lamp.box(Vector3(0.24, 0.16, 0.1), Vector3(0, 0.0, -0.38), "metal_dark", null, Vector3(-0.5, 0, 0))
		lamp.plate(Vector3(0.2, 0.12, 0.01), Vector3(0, -0.03, -0.44), "glass", null, Vector3(-0.5, 0, 0))
		lamp.rod(Vector3(0.0, 0.0, 0.0), Vector3(0.0, -height + 0.35, 0.045), 0.006, "rubber", null, 3, false)


## A coil of razor wire along x, 0.45 m across, lying in the outrigger's V.
static func _razor_coil(lk: float, height: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var r := RandomNumberGenerator.new()
	r.seed = 9911 + int(lk * 100.0)
	var loops := int(lk / 0.2)
	var steps := loops * 14
	var pts := PackedVector3Array()
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * loops * TAU
		var rr := 0.22 * (1.0 + 0.07 * sin(a * 3.0 + 1.3))
		# loops clipped to their neighbours lean alternately and cross (see WorksModels._concertina)
		var lean := 0.07 * sin(a) * (1.0 if int(floor(a / TAU)) % 2 == 0 else -1.0)
		pts.append(Vector3(-lk * 0.5 + t * lk + lean, height + 0.25 + rr * sin(a) * 0.9, 0.04 + rr * cos(a)))
	BuildingWire.strand(v, n, pts, 0.0068)
	BuildingWire.barbs(v, n, pts, 0.045, 0.024, r)
	return BuildingKit._commit(v, n)


## A warning plate wired to the mesh: a red band over white, lines of black
## lettering (no one reads it at this range; everyone knows what it says).
static func _warning_sign(k: BuildingKit, x: float, y: float, z: float) -> void:
	var s := k.at_point(Vector3(x, y, z), Vector3(k.rng.randf_range(-0.04, 0.04), 0, k.rng.randf_range(-0.03, 0.03)))
	s.plate(Vector3(0.5, 0.34, 0.006), Vector3.ZERO, "paint", Color(0.85, 0.84, 0.8), Vector3.ZERO, true)
	s.plate(Vector3(0.5, 0.09, 0.008), Vector3(0, 0.125, 0), "paint", Color(0.7, 0.1, 0.08))
	for i in 3:
		s.plate(Vector3([0.36, 0.42, 0.3][i], 0.022, 0.008), Vector3(0, 0.03 - i * 0.055, 0), "paint", Color(0.08, 0.08, 0.08))


static func _panels(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var col := Res.vary(GALV, 0.04, k.rng)
	var lean := k.rng.randf_range(-0.025, 0.025)
	var pk := k.moved(Transform3D(Basis(Vector3.RIGHT, lean), Vector3(0, 0.13, 0)))
	var w := length - 0.06
	var h := height - 0.15
	# the frame of round tube, the welded mesh inside it
	for y in [0.0, h]:
		pk.rod(Vector3(-w * 0.5, y, 0), Vector3(w * 0.5, y, 0), 0.021, "galvanised", col, 6)
	for x in [-w * 0.5, w * 0.5]:
		pk.rod(Vector3(x, -0.13, 0), Vector3(x, h, 0), 0.021, "galvanised", col, 6)
	mesh_panel(pk, w, 0.0, h, Vector3.ZERO, col, true)
	# the feet the panel legs stand in, a coupler clamping each joint
	for x in posts:
		k.box(Vector3(0.7, 0.14, 0.2), Vector3(x, 0.07, 0), "concrete", Color(0.5, 0.49, 0.46), Vector3(0, k.rng.randf_range(-0.08, 0.08), 0))
		for y in [0.45, h - 0.2]:
			k.box(Vector3(0.1, 0.06, 0.06), Vector3(x, y + 0.13, 0), "steel", Color(0.4, 0.4, 0.38))
	# olive drab scrim lashed on to screen the compound
	if v % 2 == 0 and k.rng.randf() < 0.8:
		pk.plate(Vector3(w - 0.04, h - 0.08, 0.004), Vector3(0, h * 0.5 + 0.02, -0.03), "canvas", Res.vary(OD, 0.06, k.rng), Vector3(0, 0, k.rng.randf_range(-0.01, 0.01)), true)
		for x in [-w * 0.45, 0.0, w * 0.45]:
			for y in [0.06, h - 0.06]:
				pk.plate(Vector3(0.012, 0.05, 0.03), Vector3(x, y, -0.02), "canvas", Color(0.22, 0.22, 0.17))
	if k.rng.randf() < 0.3:
		# a stay out the back to a foot of its own, a sandbag on it
		var fx := k.rng.randf_range(-w * 0.3, w * 0.3)
		k.rod(Vector3(fx, h + 0.05, 0.02), Vector3(fx, 0.1, 1.1), 0.018, "galvanised", col, 6)
		k.box(Vector3(0.55, 0.14, 0.2), Vector3(fx, 0.07, 1.15), "concrete", Color(0.5, 0.49, 0.46), Vector3(0, PI * 0.5, 0))
	for x in posts:
		if k.rng.randf() < 0.35:
			k.box(Vector3(0.5, 0.14, 0.3), Vector3(x + k.rng.randf_range(-0.1, 0.1), 0.2, k.rng.randf_range(-0.15, 0.15)), "sandbag", null, Vector3(0, k.rng.randf_range(-0.4, 0.4), 0))
	if k.rng.randf() < 0.15:
		_warning_sign(k, 0.0, 1.4, -0.04)


static func _improvised(k: BuildingKit, length: float, height: float, v: int, posts: Array[float]) -> void:
	var r := k.rng
	var tops: Array[Vector3] = []
	for x in posts:
		var lean := Vector3(r.randf_range(-0.07, 0.07), 0, r.randf_range(-0.09, 0.09))
		var ht := height + r.randf_range(-0.15, 0.1)
		var top := Vector3(x, ht, 0) + Vector3(lean.z, 0, -lean.x) * ht
		if r.randf() < 0.25:
			# a steel picket pulled from someone else's wire
			k.beam(Vector3(x, -0.3, 0), top, 0.05, 0.012, "rust_steel")
		else:
			k.rod(Vector3(x, -0.3, 0), top, r.randf_range(0.035, 0.05), "wood_dark", Res.vary(Color(0.3, 0.23, 0.16), 0.15, r), 6)
		tops.append(top)
	# strands from post to post at whatever height they were tied, slack and rusty;
	# one snapped, its ends hanging
	var strands := 5
	for i in strands:
		var y := 0.22 + i * (height - 0.3) / (strands - 1) + r.randf_range(-0.06, 0.06)
		var a := Vector3(-length * 0.5, y, -0.04)
		var b := Vector3(length * 0.5, y + r.randf_range(-0.08, 0.08), -0.04)
		if r.randf() < 0.08:
			BuildingWire.barbed(k, a, a.lerp(b, 0.4) + Vector3(0.05, -y * 0.6, -0.1), 0.05, 0.12, "rust")
			BuildingWire.barbed(k, b, b.lerp(a, 0.35) + Vector3(-0.05, -y * 0.7, -0.08), 0.05, 0.12, "rust")
			continue
		BuildingWire.barbed(k, a, b, r.randf_range(0.02, 0.05), 0.12, "rust")
	# whatever was to hand, wired into the gaps
	var fill := r.randf()
	if fill < 0.3:
		var h := r.randf_range(0.9, 1.5)
		k.plate(Vector3(length * r.randf_range(0.6, 0.9), h, 0.012), Vector3(r.randf_range(-0.2, 0.2), h * 0.5 + 0.02, 0.03), "corrugated",
			Res.vary(Color(0.42, 0.26, 0.15), 0.12, r), Vector3(r.randf_range(-0.05, 0.05), 0, r.randf_range(-0.04, 0.04)), true)
	elif fill < 0.45:
		BuildingFittings.pallet(k.at_point(Vector3(r.randf_range(-0.4, 0.4), 0.0, 0.12), Vector3(PI * 0.5 - 0.08, 0, 0)), Vector3.ZERO, Vector2(1.15, 1.0), Color(0.5, 0.41, 0.29))
	if r.randf() < 0.4:
		# a rusty coil dragged along the outside
		k.at_point(Vector3(0, 0, -0.45)).part(_cached("razor|%.2f" % -0.02, length, func(lk: float) -> ArrayMesh: return _razor_coil(lk, -0.02)), "wire_rust", _stretch(length), null, false)
	_weeds(k, length, 0.9)


# --- gates ------------------------------------------------------------------------------

## A gate leaf filling the opening, hung on the first post: shut, or left
## swinging when whoever lived here went.
static func _gate(k: BuildingKit, style: int, v: int, length: float, height: float) -> void:
	var w := length - 0.06
	var swing := 0.0 if k.rng.randf() < 0.45 else k.rng.randf_range(0.5, 1.7) * (1.0 if k.rng.randf() < 0.5 else -1.0)
	var g := k.moved(Transform3D(Basis(Vector3.UP, swing), Vector3(-length * 0.5 + 0.03, 0.06, 0)))
	var h := height - 0.1
	match style:
		RAILINGS, BOW_TOP, CHAIN_LINK:
			var col: Color = RAIL_PAINT[v % RAIL_PAINT.size()] if style == RAILINGS else (Color(0.12, 0.26, 0.15) if style == BOW_TOP else LINK_COLOURS[v % LINK_COLOURS.size()])
			if style == RAILINGS and height < 0.95:
				h = height + 0.15
			for y in [0.02, h]:
				g.box(Vector3(w, 0.035, 0.02), Vector3(w * 0.5, y, 0), "fence_metal", col)
			for x in [0.02, w - 0.02]:
				g.box(Vector3(0.035, h, 0.02), Vector3(x, h * 0.5, 0), "fence_metal", col)
			if style == CHAIN_LINK:
				mesh_panel(g, w - 0.04, 0.02, h, Vector3(w * 0.5, 0, 0), col, false)
			else:
				var n := int(w / 0.115)
				for i in n:
					g.plate(Vector3(0.014, h, 0.014), Vector3(0.06 + i * (w - 0.12) / maxf(1.0, n - 1), h * 0.5 + 0.02, 0), "fence_metal", col, Vector3.ZERO, true)
			g.box(Vector3(0.08, 0.03, 0.04), Vector3(w - 0.02, h * 0.6, -0.02), "steel", Color(0.3, 0.3, 0.28))
		_:
			# ledged and braced: two ledges, a brace rising from the hinge
			# side's foot, the boards or pickets of the fence nailed over them
			var col: Color = PICKET_PAINT[v % PICKET_PAINT.size()] if style == PICKET else TIMBER[v % TIMBER.size()]
			var kind := "fence_painted" if style == PICKET else "fence_wood"
			if style == POST_RAIL:
				# a field gate: five bars, a brace, the heel and head stiles
				for i in 5:
					g.box(Vector3(w, 0.09, 0.04), Vector3(w * 0.5, 0.15 + i * (h - 0.2) / 4.0, 0), "fence_rail", col)
				for x in [0.04, w - 0.04]:
					g.box(Vector3(0.08, h + 0.05, 0.06), Vector3(x, h * 0.5 + 0.05, 0), "fence_wood", col)
				g.beam(Vector3(0.06, 0.15, 0.04), Vector3(w - 0.06, h, 0.04), 0.09, 0.035, "fence_rail", col.darkened(0.08))
				return
			for y in [h * 0.18, h * 0.78]:
				g.box(Vector3(w - 0.02, 0.08, 0.025), Vector3(w * 0.5, y, 0.03), kind, col.darkened(0.06))
			g.beam(Vector3(0.05, h * 0.18, 0.03), Vector3(w - 0.05, h * 0.78, 0.03), 0.07, 0.022, kind, col.darkened(0.06))
			if style == CLOSE_BOARD:
				g.box(Vector3(w, h, 0.02), Vector3(w * 0.5, h * 0.5, 0.0), kind, col)
			else:
				var n := maxi(2, int(w / 0.13))
				for i in n:
					var x := (i + 0.5) * w / n
					g.plate(Vector3(0.075, h - 0.08, 0.02), Vector3(x, (h - 0.08) * 0.5, 0), kind, col, Vector3.ZERO, true)
					g.prism(Vector3(0.075, 0.07, 0.02), Vector3(x, h - 0.045, 0), kind, col)
			g.box(Vector3(0.05, 0.05, 0.05), Vector3(w - 0.04, h * 0.6, -0.03), "metal_dark")


# --- shared -----------------------------------------------------------------------------

static func _square_post(k: BuildingKit, x: float, w: float, ht: float, kind: String, col: Color, cap: bool) -> void:
	# set 0.2 m into the ground (the ground under the bay is only a line
	# between its posts, so a foot of post hides wherever it dips)
	k.box(Vector3(w, ht + 0.2, w), Vector3(x, (ht - 0.2) * 0.5, 0), kind, col)
	if cap:
		k.cyl(0.0, w * 0.78, 0.05, Vector3(x, ht + 0.025, 0), kind, col.darkened(0.05), Vector3(0, PI * 0.25, 0), 4)


## A cached panel at the nearest 5 cm (see _panel), and the stretch onto the
## real length.
static func _cached(key: String, length: float, build: Callable) -> ArrayMesh:
	var lk := maxf(0.2, snappedf(length, 0.05))
	var full := "%s|%.2f" % [key, lk]
	var m: ArrayMesh = _meshes.get(full)
	if m == null:
		m = build.call(lk)
		_meshes[full] = m
	return m


static func _stretch(length: float) -> Transform3D:
	var lk := maxf(0.2, snappedf(length, 0.05))
	return Transform3D(Basis.from_scale(Vector3(length / lk, 1, 1)), Vector3.ZERO)
