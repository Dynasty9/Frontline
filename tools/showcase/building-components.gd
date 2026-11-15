extends RefCounted
## The shared building construction on its own, one part per cell, for
## building-surfaces.tscn's --building-components sheets.

const WALL := Color(0.72, 0.66, 0.55)
const SHEET := Color(0.45, 0.47, 0.45)


static func build(holder: Node3D, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var k := BuildingKit.nodes(holder, rng)
	if kind.begins_with("fence_"):
		_fence(k, kind.trim_prefix("fence_"))
		return
	match kind:
		"wall_plaster", "wall_brick", "wall_stone", "wall_timber", "wall_corrugated", "wall_precast":
			var m := kind.trim_prefix("wall_")
			var col := BuildingMaterials.color(m) if m != "plaster" else WALL
			k.box(Vector3(3.6, 3.0, 0.3), Vector3(0, 1.5, -0.15), BuildingMaterials.surface(m), col)
			var gaps := [Rect2(-0.65, 1.0, 1.3, 1.0)]
			BuildingWalls.face(k, 3.6, 3.0, m, col, gaps, {"band": 2.85, "corners": [-1.8, 1.8], "plinth": 0.0 if m == "timber" else 0.34})
			BuildingOpenings.window(k, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), {"material": m, "wall": col, "inset": -0.03, "glazing": 1.0})
		"roof_tile":
			_walls(k, 6.0, 4.6, "plaster", WALL)
			BuildingRoofs.gable(k, 6.0, 4.6, 2.6, 28.0, 0.35, "roof_tile", Color(0.5, 0.22, 0.14), {"gable_material": "plaster", "gable_col": WALL,
				"trim": Color(0.86, 0.85, 0.8), "gable_inset": -0.07, "gutters": true, "downpipes": [[2.7, -1.0]], "wall_face": 2.5})
		"roof_sheet":
			_walls(k, 6.0, 4.6, "timber", Color(0.3, 0.34, 0.22))
			BuildingRoofs.gable(k, 6.0, 4.6, 2.6, 26.0, 0.35, "roof_sheet", SHEET, {"gable_material": "timber", "gable_col": Color(0.3, 0.34, 0.22),
				"trim": Color(0.2, 0.24, 0.15), "gable_inset": -0.07, "gutters": true, "downpipes": [[2.7, -1.0]], "wall_face": 2.5})
		"roof_flat":
			_walls(k, 6.0, 4.6, "plaster", WALL)
			BuildingRoofs.flat(k, 6.0, 4.6, 2.6, {"material": "plaster", "col": WALL, "wall_face": 2.5, "hatch": true})
			BuildingFittings.water_tank(k, Vector3(1.2, 2.8, 0.6))
		"roof_lean_to":
			k.box(Vector3(3.0, 3.0, 0.3), Vector3(0, 1.5, -0.15), "plaster", WALL)
			BuildingRoofs.canopy(k.at_point(Vector3(0, 2.5, 0)), 2.4, 1.1, "roof_tile", Color(0.5, 0.22, 0.14), Color(0.86, 0.85, 0.8))
			BuildingRoofs.mono(k.at_point(Vector3(0, 0.6, 1.8)), 1.6, 1.2, 0.12, "roof_sheet", SHEET)
		"window", "window_shutters", "window_broken":
			_wall(k, 2.4, 2.6, [Rect2(-0.65, 1.0, 1.3, 1.0)])
			var opts := {"wall": WALL, "glazing": 1.0 if kind == "window" else (0.0 if kind == "window_broken" else 0.5), "cracked": 1.0}
			if kind == "window_shutters":
				opts.shutters = Color(0.24, 0.36, 0.27)
				opts.shutter = "louvred"
				opts.open = [0.15, 0.5]
			BuildingOpenings.window(k, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), opts)
		"door_panelled", "door_ledged", "door_steel":
			_wall(k, 2.6, 2.8, [Rect2(-0.5, 0.0, 1.0, 2.15)])
			BuildingOpenings.doorway(k, Vector3.ZERO, Vector2(1.0, 2.15), {"wall": WALL, "hood": kind == "door_panelled"})
			var style := kind.trim_prefix("door_")
			BuildingOpenings.leaf(k.at_point(Vector3(-0.45, 0, -0.08), Vector3(0, -0.5, 0)), Vector2(0.9, 2.04), style,
				Color(0.3, 0.2, 0.13) if style == "panelled" else (Color(0.3, 0.34, 0.22) if style == "ledged" else Color(0.3, 0.32, 0.25)), 1.0)
		"roller_door":
			k.box(Vector3(5.0, 4.2, 0.3), Vector3(0, 2.1, -0.15), "corrugated", Color(0.45, 0.46, 0.44))
			BuildingOpenings.roller_door(k, Vector3(0, 0, 0.035), Vector2(3.6, 3.2), Color(0.55, 0.5, 0.36))
		"louvre":
			k.box(Vector3(1.6, 1.4, 0.3), Vector3(0, 0.7, -0.15), "plaster", WALL)
			BuildingOpenings.louvre(k, Vector3(0, 0.7, 0.03), Vector2(0.8, 0.8), Color(0.4, 0.42, 0.4))
		"gutter_downpipe":
			k.box(Vector3(2.4, 3.0, 0.3), Vector3(0, 1.5, -0.15), "plaster", WALL)
			BuildingFittings.gutter(k, Vector3(-1.2, 2.9, 0.25), Vector3(1.2, 2.9, 0.25), Vector3(0, 0, 1))
			BuildingFittings.downpipe(k, Vector3(0.9, 2.86, 0.25), Vector3(0.9, 0.1, 0.07))
			BuildingFittings.hopper(k, Vector3(-0.6, 2.2, 0.12))
			BuildingFittings.downpipe(k, Vector3(-0.6, 2.0, 0.07), Vector3(-0.6, 0.1, 0.07))
		"chimney":
			BuildingFittings.chimney(k, Vector3.ZERO, Vector2(0.6, 0.6), 1.6)
			BuildingFittings.flue(k, Vector3(1.0, 0, 0), 0.1, 1.2)
			BuildingFittings.stack(k, Vector3(-1.3, 0, 0), 0.35, 0.26, 2.6)
		"ac_unit":
			BuildingFittings.ac_unit(k, Vector3.ZERO, 0.3)
		"water_tank":
			BuildingFittings.water_tank(k, Vector3.ZERO)
		"dish":
			BuildingFittings.dish(k, Vector3.ZERO, 0.5, Vector3(-0.8, 0.5, 0))
		"mast":
			BuildingFittings.mast(k, Vector3.ZERO, 6.0, 3, 0.3)
			BuildingFittings.flagpole(k, Vector3(2.0, 0, 1.0), 4.0)
		"drum":
			for i in 3:
				BuildingFittings.drum(k, Vector3(i * 0.65, 0, 0), BuildingFittings.DRUMS[i], false, i * 0.9)
			BuildingFittings.drum(k, Vector3(0.65, 0.88, 0), BuildingFittings.DRUMS[3], true, 0.2)
		"crate":
			BuildingFittings.crate(k, Vector3.ZERO, Vector3(1.1, 0.55, 0.65), Color(0.5, 0.37, 0.23))
			BuildingFittings.crate(k, Vector3(0.05, 0.55, 0), Vector3(1.0, 0.45, 0.6), Color(0.3, 0.36, 0.22), 0.1, "wood_painted")
		"pallet":
			BuildingFittings.pallet(k, Vector3.ZERO)
			BuildingFittings.pallet(k, Vector3(0, 0.13, 0), Vector2(1.15, 1.0), Color(0.5, 0.42, 0.3), 0.08)
		"wire_cable":
			for z in [-0.4, 0.0, 0.4]:
				BuildingWire.insulator(k, Vector3(-3.0, 3.0, z))
				BuildingWire.insulator(k, Vector3(3.0, 3.0, z))
				BuildingWire.cable(k, Vector3(-3.0, 3.17, z), Vector3(3.0, 3.17, z), 0.35, 0.008, "metal_dark")
			for x in [-3.0, 3.0]:
				k.cyl(0.11, 0.14, 3.4, Vector3(x, 1.4, 0), "wood_dark", Color(0.3, 0.24, 0.17))
				k.box(Vector3(0.12, 0.11, 1.1), Vector3(x, 2.95, 0), "wood_dark", Color(0.3, 0.24, 0.17))
				BuildingWire.guy(k, Vector3(x, 2.9, 0), Vector3(x * 1.45, 0, 0))
		"wire_barbed":
			for x in [-1.5, 0.0, 1.5]:
				k.rod(Vector3(x, -0.1, 0), Vector3(x, 1.3, 0), 0.04, "wood_dark")
			# clean at the bottom, rusted in the middle, military at the top
			for i in 3:
				BuildingWire.barbed(k, Vector3(-1.5, 0.4 + i * 0.4, 0.04), Vector3(1.5, 0.4 + i * 0.4, 0.04), 0.03, 0.11, ["clean", "rust", "military"][i])
		"wire_close":
			# half a metre of each finish, drawn four times life size so the
			# studio's camera (which frames no less than 1.2 m) shows the barbs
			var big := k.moved(Transform3D(Basis.from_scale(Vector3.ONE * 4.0), Vector3.ZERO))
			for i in 3:
				var y := 0.1 + i * 0.06
				BuildingWire.barbed(big, Vector3(-0.25, y, 0), Vector3(0.25, y, 0), 0.002, 0.11, ["clean", "rust", "military"][i])
		"wire_topping":
			k.box(Vector3(4.0, 2.6, 0.5), Vector3(0, 1.3, 0), "concrete", Color(0.5, 0.49, 0.46))
			var top := BuildingWalls.coping(k, 4.0, 0.5, 2.6, "concrete", Color(0.5, 0.49, 0.46))
			BuildingWire.topping(k, 4.0, top, 1.0)


## A plain stretch of wall (+z its face) with holes where `gaps` are.
static func _wall(k: BuildingKit, w: float, h: float, gaps: Array) -> void:
	var gap: Rect2 = gaps[0]
	for side: float in [-1.0, 1.0]:
		var x0 := gap.position.x if side < 0.0 else gap.end.x
		var x1 := -w * 0.5 if side < 0.0 else w * 0.5
		k.box(Vector3(absf(x1 - x0), h, 0.4), Vector3((x0 + x1) * 0.5, h * 0.5, -0.2), "plaster", WALL)
	if gap.position.y > 0.0:
		k.box(Vector3(gap.size.x, gap.position.y, 0.4), Vector3(gap.get_center().x, gap.position.y * 0.5, -0.2), "plaster", WALL)
	k.box(Vector3(gap.size.x, h - gap.end.y, 0.4), Vector3(gap.get_center().x, (h + gap.end.y) * 0.5, -0.2), "plaster", WALL)
	BuildingWalls.face(k, w, h, "plaster", WALL, gaps)


## The four walls under a roof, `L` x `W`, 2.6 m to the eaves.
static func _walls(k: BuildingKit, L: float, W: float, material: String, col: Color) -> void:
	k.box(Vector3(L + 0.4, 2.6, W + 0.4), Vector3(0, 1.3, 0), BuildingMaterials.surface(material), col)
	for out: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0)]:
		var f := k.on_face(out * Vector3(L * 0.5 + 0.2, 0, W * 0.5 + 0.2), out)
		BuildingWalls.face(f, (L if out.z != 0.0 else W) + 0.4, 2.6, material, col, [], {"corners": [-(L if out.z != 0.0 else W) * 0.5 - 0.2, (L if out.z != 0.0 else W) * 0.5 + 0.2]})


## Three bays of a fence run, and its gate where it has one.
static func _fence(k: BuildingKit, style_name: String) -> void:
	var F := BuildingFences
	var spec: Array = {"picket": [F.PICKET, 0.9, true], "post_rail": [F.POST_RAIL, 1.1, true], "railings": [F.RAILINGS, 0.85, true],
		"close_board": [F.CLOSE_BOARD, 1.8, true], "paling": [F.PALING, 1.1, true], "chain_link": [F.CHAIN_LINK, 1.5, true],
		"bow_top": [F.BOW_TOP, 1.0, true], "security": [F.SECURITY, 2.4, false], "panels": [F.PANELS, 2.0, false], "improvised": [F.IMPROVISED, 1.7, false]}.get(style_name, [F.PICKET, 0.9, true])
	var bay := 2.2
	for i in 3:
		var linked := F.LINKED if i < 2 else 0
		F.bay(k.at_point(Vector3(-3.0 * bay * 0.5 + (i + 0.5) * bay, 0, 0)), bay, float(spec[1]), F.code(int(spec[0]), 1, linked))
	if spec[2]:
		F.bay(k.at_point(Vector3(1.5 * bay + 0.8, 0, 0)), 1.6, float(spec[1]), F.code(int(spec[0]), 1, F.GATE))
