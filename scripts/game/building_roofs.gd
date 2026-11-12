class_name BuildingRoofs
extends RefCounted
## Roofs, in a kit whose origin is the building's middle at the ground (or,
## for a canopy, the wall face at its top edge). The ridge of a gable runs
## along x; the eaves along x either side of it at ±z.
##
## The covering is a material (BuildingMaterials: roof_tile, roof_sheet,
## roof_concrete, canvas) and decides how the roof is finished: tiles get a
## round ridge, fascia and barge boards; sheet a ridge capping, lapped sheets
## and drip edges; a flat slab a parapet under a coping, scuppers through it.
## Gutters and downpipes come from BuildingFittings.


## A pitched roof over walls whose tops are at `eave`, pitched at `pitch`
## degrees: `L` along the ridge (the gable walls' line; the slopes overhang it
## by `overhang` at each end), `W` across. The roof bears on the walls' outer
## faces (`wall_face` either side of the ridge, W/2 by default): its underside
## meets the wall tops there, so no wall shows through the covering, and runs
## on `overhang` beyond them to the eaves. Returns the rise of the top of the
## covering at the ridge above the eaves. opts:
##   gable_material, gable_col  the infill in each gable end (the walls')
##   trim                       fascia and barge-board colour
##   gutters                    gutters along both eaves
##   downpipes                  [x, side] pairs: a downpipe from that end of that eave
##   wall_face                  half-depth to the walls' outer faces
##   gable_inset                how far in from x = ±L/2 the gables stand (0.12)
static func gable(k: BuildingKit, L: float, W: float, eave: float, pitch: float, overhang: float, covering: String, col: Color, opts := {}) -> float:
	var t := deg_to_rad(pitch)
	var tn := tan(t)
	var face: float = opts.get("wall_face", W * 0.5)
	var ov := overhang
	var kind := BuildingMaterials.surface(covering)
	var th: float = BuildingMaterials.value(covering, "thickness", 0.09)
	var trim_col: Color = opts.get("trim", Color(0.3, 0.24, 0.18))
	var trim_kind: String = BuildingMaterials.trim(covering)
	var run := L + ov * 2.0
	var reach := face + ov  # ridge to the eave's edge, level
	var lift := th * 0.5 / cos(t)  # the covering's middle above its underside, straight up
	var edge := eave - ov * tn  # the underside at the eave's edge
	var ridge := eave + face * tn  # the underside at the ridge
	var rise := face * tn + th / cos(t)
	# the two slopes: underside y = eave + (face - |z|) * tan
	for s: float in [-1.0, 1.0]:
		var mz := reach * 0.5
		var my := eave + (face - mz) * tn + lift
		k.box(Vector3(run, th, reach / cos(t)), Vector3(0, my, s * mz), kind, col, Vector3(s * t, 0, 0))
		var laps: float = BuildingMaterials.value(covering, "laps", 0.0)
		if laps > 0.0:
			_laps(k, run, reach / cos(t), Vector3(0, my, s * mz) + Vector3(0, cos(t), s * sin(t)) * (th * 0.5 + 0.004), s * t, laps, col)
	# the gable ends, in the walls' own material, filling up under the slopes
	var gi: float = opts.get("gable_inset", 0.12)
	var gm: String = opts.get("gable_material", "plaster")
	var gc: Color = opts.get("gable_col", BuildingMaterials.color(gm))
	for e: float in [-1.0, 1.0]:
		k.prism(Vector3(face * 2.0, face * tn, 0.25), Vector3(e * (L * 0.5 - gi), eave + face * tn * 0.5 - 0.005, 0), BuildingMaterials.surface(gm), gc, Vector3(0, PI * 0.5, 0))
	# the ridge
	match BuildingMaterials.value(covering, "ridge", "round"):
		"round":
			k.cyl(0.11, 0.11, run, Vector3(0, eave + rise - 0.03, 0), kind, col.darkened(0.22), Vector3(0, 0, PI * 0.5), 8)
		"capping":
			for s: float in [-1.0, 1.0]:
				k.plate(Vector3(run + 0.02, 0.014, 0.34), Vector3(0, eave + rise + 0.008 - 0.17 * sin(t), s * 0.17 * cos(t)), "steel", col.darkened(0.15), Vector3(s * t, 0, 0), true)
	# along the eaves a fascia board (or a drip edge on sheet); up the gables
	# the barge boards, their tops flush with the covering
	var eaves: String = BuildingMaterials.value(covering, "eaves", "fascia")
	for s: float in [-1.0, 1.0]:
		if eaves == "fascia":
			k.plate(Vector3(run, 0.17, 0.028), Vector3(0, edge - 0.03, s * (reach + 0.015)), trim_kind, trim_col, Vector3.ZERO, true)
		elif eaves == "drip":
			k.plate(Vector3(run, 0.06, 0.012), Vector3(0, edge + 0.01, s * (reach + 0.008)), "steel", col.darkened(0.2))
		for e: float in [-1.0, 1.0]:
			var x := e * (run * 0.5 + 0.014)
			k.beam(Vector3(x, edge - 0.012, s * reach), Vector3(x, ridge - 0.012, 0), 0.028, 0.2, trim_kind, trim_col)
	if opts.get("gutters", false):
		var gy := edge - 0.1
		var gz := reach + 0.07
		for s: float in [-1.0, 1.0]:
			BuildingFittings.gutter(k, Vector3(-run * 0.5, gy, s * gz), Vector3(run * 0.5, gy, s * gz), Vector3(0, 0, s))
		for dp: Array in opts.get("downpipes", []):
			var x: float = dp[0]
			var s: float = dp[1]
			BuildingFittings.downpipe(k, Vector3(x, gy - 0.02, s * gz), Vector3(x, 0.12, s * (face + 0.06)))
	return rise


## Sheet laps down a slope: the edges of the sheets, one every `pitch` along
## the ridge, a shadow line from eave to ridge.
static func _laps(k: BuildingKit, run: float, slope: float, c: Vector3, ang: float, pitch: float, col: Color) -> void:
	var n := int(run / pitch)
	for i in n:
		var x := -run * 0.5 + (i + 1) * run / (n + 1)
		k.plate(Vector3(0.03, 0.012, slope), Vector3(x, c.y, c.z), "plain_dark", col.darkened(0.3), Vector3(ang, 0, 0))


## A flat roof: a slab over walls `L` x `W` whose tops are at `y`, and round it
## a parapet in the walls' material under a coping, scuppers through the
## parapet at the back with a hopper and downpipe under one. opts:
##   material, col  the parapet's (the walls')        parapet  its height (0.55; 0 for none)
##   scuppers       how many (2)                        wall_face  half-depth to the walls' faces (W/2 + 0.2)
##   hatch          a roof hatch
static func flat(k: BuildingKit, L: float, W: float, y: float, opts := {}) -> void:
	var material: String = opts.get("material", "plaster")
	var col: Color = opts.get("col", BuildingMaterials.color(material))
	k.box(Vector3(L + 0.1, 0.2, W + 0.1), Vector3(0, y + 0.1, 0), "roof_concrete")
	var ph: float = opts.get("parapet", 0.55)
	if ph <= 0.0:
		k.plate(Vector3(L + 0.16, 0.07, W + 0.16), Vector3(0, y + 0.22, 0), "concrete", Color(0.5, 0.49, 0.46), Vector3.ZERO, true)
		return
	var pt := 0.18
	var wk := BuildingMaterials.surface(material)
	for e: float in [-1.0, 1.0]:
		k.box(Vector3(L + 0.1, ph, pt), Vector3(0, y + 0.2 + ph * 0.5 - 0.005, e * (W * 0.5 - 0.04)), wk, col)
		k.box(Vector3(pt, ph, W + 0.1), Vector3(e * (L * 0.5 - 0.04), y + 0.2 + ph * 0.5 - 0.005, 0), wk, col)
	var top := y + 0.2 + ph - 0.005
	for e: float in [-1.0, 1.0]:
		BuildingWalls.coping(k.at_point(Vector3(0, 0, e * (W * 0.5 - 0.04))), L + 0.1, pt, top, material, col)
		BuildingWalls.coping(k.at_point(Vector3(e * (L * 0.5 - 0.04), 0, 0), Vector3(0, PI * 0.5, 0)), W - 0.26, pt, top, material, col)
	var n: int = opts.get("scuppers", 2)
	var face: float = opts.get("wall_face", W * 0.5 + 0.2)
	for i in n:
		var x := (-0.5 + (i + 0.5) / n) * L * 0.8
		var sz := W * 0.5 + 0.08
		k.plate(Vector3(0.16, 0.09, 0.42), Vector3(x, y + 0.26, sz), "paint", BuildingFittings.IRON, Vector3(-0.08, 0, 0), true)
		if i == 0:
			BuildingFittings.hopper(k, Vector3(x, y + 0.02, face + 0.17))
			BuildingFittings.downpipe(k, Vector3(x, y - 0.18, face + 0.12), Vector3(x, 0.12, face + 0.06))
	if opts.get("hatch", false):
		var hp := Vector3(L * 0.3, y + 0.2, -W * 0.25)
		k.box(Vector3(0.8, 0.28, 0.8), hp + Vector3(0, 0.14, 0), wk, col)
		k.plate(Vector3(0.88, 0.04, 0.88), hp + Vector3(0, 0.3, 0), "metal_dark", Color(0.3, 0.32, 0.3), Vector3.ZERO, true)


## A single-pitch roof centred on the kit's origin, `width` along x and
## `depth` down its fall along z, falling `fall` radians towards +z: the
## covering, edges trimmed as the covering is (drip, fascia), purlins under
## it so it reads as built from below too.
static func mono(k: BuildingKit, width: float, depth: float, fall: float, covering: String, col: Color, trim_col := Color(0.3, 0.24, 0.18), purlins := 2) -> void:
	var kind := BuildingMaterials.surface(covering)
	var th: float = BuildingMaterials.value(covering, "thickness", 0.04)
	var rot := Vector3(fall, 0, 0)
	var b := Basis.from_euler(rot)
	k.box(Vector3(width, th, depth), Vector3.ZERO, kind, col, rot)
	if BuildingMaterials.value(covering, "laps", 0.0) > 0.0:
		_laps(k, width, depth, b * Vector3(0, th * 0.5 + 0.004, 0), fall, float(BuildingMaterials.value(covering, "laps", 0.95)), col)
	var tk := BuildingMaterials.trim(covering)
	k.plate(Vector3(width + 0.02, 0.12 if kind == "roof_tile" else 0.05, 0.025), b * Vector3(0, -0.03, depth * 0.5 + 0.012), tk, trim_col if kind == "roof_tile" else col.darkened(0.2), Vector3.ZERO, true)
	for i in purlins:
		var z := lerpf(-depth * 0.38, depth * 0.38, float(i) / maxi(1, purlins - 1)) if purlins > 1 else 0.0
		k.box(Vector3(width - 0.1, 0.07, 0.07), b * Vector3(0, -th * 0.5 - 0.035, z), "wood_dark", Color(0.33, 0.26, 0.18), rot)


## A canopy on brackets over a door or a porch, in a kit at the wall face at
## its top edge (+z out from the wall): it falls a little to its front edge.
static func canopy(k: BuildingKit, width: float, depth: float, covering: String, col: Color, trim_col := Color(0.3, 0.24, 0.18)) -> void:
	var fall := atan2(0.22, depth)
	mono(k.at_point(Vector3(0, -0.11, depth * 0.5)), width, Vector2(depth, 0.22).length(), fall, covering, col, trim_col, 1)
	# a flashing where it meets the wall, a knee brace under each end
	k.plate(Vector3(width, 0.08, 0.04), Vector3(0, 0.02, 0.02), "steel", Color(0.4, 0.4, 0.38))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (width * 0.5 - 0.12)
		k.beam(Vector3(x, -0.6, 0.02), Vector3(x, -0.2, depth * 0.8), 0.06, 0.06, "wood_dark", trim_col)


## A run of north lights over a roof whose top is at the kit's origin, `L`
## along x and `W` across: each tooth a sheeted slope up to a glazed upright
## face, triangular ends, a valley gutter between teeth.
static func sawtooth(k: BuildingKit, L: float, W: float, teeth: int, rise: float, covering: String, col: Color, frame_col := Color(0.3, 0.32, 0.3)) -> void:
	var p := L / teeth
	var sl := p * 0.78
	var kind := BuildingMaterials.surface(covering)
	var ang := atan2(rise, sl)
	for i in teeth:
		var x0 := -L * 0.5 + i * p
		var ln := Vector2(sl, rise).length()
		k.box(Vector3(ln, 0.04, W), Vector3(x0 + sl * 0.5, rise * 0.5 + 0.02, 0), kind, col, Vector3(0, 0, ang))
		if BuildingMaterials.value(covering, "laps", 0.0) > 0.0:
			for j in int(W / 0.95):
				var z := -W * 0.5 + (j + 1) * W / (int(W / 0.95) + 1)
				k.plate(Vector3(ln, 0.012, 0.03), Vector3(x0 + sl * 0.5 - sin(ang) * 0.025, rise * 0.5 + 0.02 + cos(ang) * 0.025, z), "plain_dark", col.darkened(0.3), Vector3(0, 0, ang))
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(sl, 0), Vector2(sl, rise)])
		for e: float in [-1.0, 1.0]:
			k.part(BuildingKit.extrusion("tooth|%.2f|%.2f" % [sl, rise], tri, 0.06), kind, Transform3D(Basis.IDENTITY, Vector3(x0, 0, e * (W * 0.5 - 0.03))), col.darkened(0.08))
		# the glazed face, its bars and rails
		var gx := x0 + sl
		k.plate(Vector3(0.012, rise - 0.08, W - 0.1), Vector3(gx + 0.01, rise * 0.5, 0), "glass", BuildingOpenings.GLASS)
		k.part(BuildingKit.shape("northlight|%.2f|%.2f" % [rise, W], func() -> Array:
			var out: Array = []
			for sy: float in [0.03, rise - 0.03]:
				out.append(BuildingKit.piece(Vector3(0.07, 0.06, W), Vector3(0, sy, 0)))
			var bars := maxi(2, int(W / 1.1))
			for j in bars + 1:
				out.append(BuildingKit.piece(Vector3(0.05, rise - 0.08, 0.04), Vector3(0, rise * 0.5, -W * 0.5 + 0.05 + j * (W - 0.1) / bars)))
			return out), "metal_dark", Transform3D(Basis.IDENTITY, Vector3(gx + 0.02, 0, 0)), frame_col)
		if i < teeth - 1:
			k.plate(Vector3(p - sl, 0.06, W), Vector3(gx + (p - sl) * 0.5, 0.03, 0), "steel", col.darkened(0.25))
