extends Node
## The shared building construction (BuildingKit and its components): every
## part builds real geometry in both its outputs, openings stay open, shared
## shapes are shared, batched scenery keeps to batchable surfaces, and every
## building's model still builds.

var _failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		TestRun.fail()
		push_error("BUILDING_COMPONENTS failed: " + what)


## Is `point` (in the root's space) inside any part built as a node under it?
## (A cached shape is several solids in one mesh, so its bounding box says
## nothing: count the faces a ray from the point crosses.)
func occupied(root: Node3D, point: Vector3) -> bool:
	return _inside(_solids(root, AABB(point, Vector3.ZERO)), point)


## The parts built as nodes under `root` that reach into `near` (in the
## root's space), for _inside(): [their inverse transforms, boxes, faces].
func _solids(root: Node3D, near: AABB) -> Array:
	var out := []
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb().grow(0.001)
		if (mi.transform * box).intersects(near) or (mi.transform * box).has_point(near.position):
			out.append([mi.transform.affine_inverse(), box, mi.mesh.get_faces()])
	return out


## Is `point` inside one of `solids` (see occupied())?
func _inside(solids: Array, point: Vector3) -> bool:
	var dir := Vector3(0.137, 0.913, 0.384).normalized()
	for s: Array in solids:
		var local: Vector3 = (s[0] as Transform3D) * point
		if not (s[1] as AABB).has_point(local):
			continue
		var faces: PackedVector3Array = s[2]
		var hits := 0
		for i in range(0, faces.size(), 3):
			if Geometry3D.ray_intersects_triangle(local, dir, faces[i], faces[i + 1], faces[i + 2]) != null:
				hits += 1
		if hits % 2 == 1:
			return true
	return false


## Every corner of the parts built as nodes under `root`, in its space, once
## each.
func _points(root: Node3D) -> PackedVector3Array:
	var seen := {}
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi != null and mi.mesh != null:
			for p in mi.transform * mi.mesh.get_faces():
				seen[p] = true
	return PackedVector3Array(seen.keys())


func valid(root: Node3D, what: String) -> void:
	var count := 0
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		count += 1
		check(mi.mesh != null and mi.mesh.get_aabb().size.is_finite(), what + ": a part without finite geometry")
		check(mi.transform.origin.is_finite() and mi.transform.basis.determinant() != 0.0, what + ": a part placed badly")
		check(Mats.base_of(mi.material_override) is ShaderMaterial, what + ": a part without one of our surfaces")
	check(count > 0, what + ": nothing built")


## The box round everything drawn under `node`, in its parent's space.
## How many of a model's meshes (or their surfaces) are lit glass.
func _lit(node: Node) -> int:
	var count := 0
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		# (lit glass, whether a part's own or merged into a bake's copy of it)
		var mats: Array = [mi.material_override]
		for i in mi.mesh.get_surface_count():
			mats.append(mi.mesh.surface_get_material(i))
		for m: Variant in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("lit") != null and float((m as ShaderMaterial).get_shader_parameter("lit")) > 0.0:
				count += 1
	for child in node.get_children():
		count += _lit(child)
	return count


func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var xf := parent * node.transform
	var box := AABB()
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		box = xf * mi.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var cb := _bounds(child, xf)
			if cb.size != Vector3.ZERO:
				box = cb if box.size == Vector3.ZERO else box.merge(cb)
	return box


## (every part's box under `node`, in `parent`'s frame)
func _part_boxes(node: Node3D, parent: Transform3D, out: Array[AABB]) -> void:
	var xf := parent * node.transform
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(xf * mi.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_part_boxes(child, xf, out)


## How high the triangles `tris` stand over (p.x, p.z), from p.y (or -1).
func _top_at(tris: PackedVector3Array, p: Vector3) -> float:
	var top := -1.0
	for i in range(0, tris.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(p, Vector3.DOWN, tris[i], tris[i + 1], tris[i + 2])
		if hit != null:
			top = maxf(top, (hit as Vector3).y)
	return top


func kit() -> BuildingKit:
	var root := Node3D.new()
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return BuildingKit.nodes(root, rng)


func _ready() -> void:
	TestRun.watch()
	# Wall gaps: dressings stop at openings and nowhere else.
	var runs := BuildingWalls.runs(-2.0, 2.0, 0.0, 0.3, [Rect2(-0.95, 0.0, 1.9, 2.2), Rect2(1.5, 1.0, 0.4, 0.5)])
	check(runs.size() == 2 and is_equal_approx(runs[0].y, -0.95) and is_equal_approx(runs[1].x, 0.95), "plinth runs split at the doorway only: %s" % [runs])
	check(BuildingWalls.runs(-1.0, 1.0, 2.5, 2.6, [Rect2(-0.5, 0.0, 1.0, 2.2)]).size() == 1, "a band above an opening runs on unbroken")

	# Every component builds, as nodes and into a bake.
	var builders := {
		"face_plaster": func(k: BuildingKit): BuildingWalls.face(k, 3.0, 3.0, "plaster", Color(0.7, 0.65, 0.55), [Rect2(-0.65, 1.0, 1.3, 1.0)], {"band": 2.9}),
		"face_brick": func(k: BuildingKit): BuildingWalls.face(k, 3.0, 3.0, "brick", Color(0.56, 0.3, 0.21)),
		"face_stone": func(k: BuildingKit): BuildingWalls.face(k, 3.0, 3.0, "stone", Color(0.6, 0.57, 0.5), [], {"corners": [-1.5, 1.5]}),
		"face_timber": func(k: BuildingKit): BuildingWalls.face(k, 3.0, 3.0, "timber", Color(0.3, 0.34, 0.22), [], {"corners": [-1.5, 1.5]}),
		"face_sheet": func(k: BuildingKit): BuildingWalls.face(k, 4.0, 4.0, "corrugated", Color(0.45, 0.46, 0.44)),
		"face_precast": func(k: BuildingKit): BuildingWalls.face(k, 6.0, 3.0, "precast", Color(0.5, 0.5, 0.5)),
		"coping": func(k: BuildingKit):
			for m in ["plaster", "brick", "stone", "concrete", "fieldstone"]:
				BuildingWalls.coping(k, 3.0, 0.4, 1.0, m, BuildingMaterials.color(m)),
		"window": func(k: BuildingKit): BuildingOpenings.window(k, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), {"shutters": Color(0.3, 0.4, 0.3), "shutter": "louvred"}),
		"doorway": func(k: BuildingKit): BuildingOpenings.doorway(k, Vector3.ZERO, Vector2(1.9, 2.2), {"hood": true}),
		"leaves": func(k: BuildingKit):
			for style in ["panelled", "ledged", "steel"]:
				BuildingOpenings.leaf(k, Vector2(0.9, 2.0), style, Color(0.3, 0.2, 0.15), 1.0),
		"roller": func(k: BuildingKit): BuildingOpenings.roller_door(k, Vector3.ZERO, Vector2(4.0, 3.5), Color(0.5, 0.5, 0.4)),
		"louvre": func(k: BuildingKit): BuildingOpenings.louvre(k, Vector3(0, 1, 0), Vector2(0.6, 0.6), Color.GRAY),
		"ribbon": func(k: BuildingKit): BuildingOpenings.ribbon(k, Vector3(0, 2, 0), Vector2(4, 0.7), 4, Color.DIM_GRAY),
		"gable": func(k: BuildingKit): BuildingRoofs.gable(k, 9.0, 7.0, 3.0, 28.0, 0.35, "roof_tile", Color(0.5, 0.22, 0.14), {"gutters": true, "downpipes": [[4.2, 1.0]]}),
		"gable_sheet": func(k: BuildingKit): BuildingRoofs.gable(k, 9.0, 6.0, 3.0, 26.0, 0.35, "roof_sheet", Color(0.45, 0.47, 0.45)),
		"hip": func(k: BuildingKit): BuildingRoofs.hip(k, 9.0, 7.0, 3.0, 32.0, 0.35, "roof_tile", Color(0.5, 0.22, 0.14), {"gutters": true, "downpipes": [[4.2, 1.0]], "wall_face": 3.7, "wall_face_x": 4.7}),
		"flat_worn": func(k: BuildingKit): BuildingRoofs.flat(k, 8.0, 7.0, 3.0, {"hatch": true, "wear": k.rng}),
		"pyramid": func(k: BuildingKit): BuildingRoofs.hip(k, 8.0, 8.0, 3.0, 26.0, 0.35, "roof_tile", Color(0.5, 0.22, 0.14), {"gutters": true}),
		"flat": func(k: BuildingKit): BuildingRoofs.flat(k, 8.0, 7.0, 3.0, {"hatch": true}),
		"canopy": func(k: BuildingKit): BuildingRoofs.canopy(k, 2.4, 1.0, "roof_sheet", Color(0.45, 0.47, 0.45)),
		"sawtooth": func(k: BuildingKit): BuildingRoofs.sawtooth(k, 9.0, 7.0, 3, 0.9, "roof_sheet", Color(0.45, 0.47, 0.45)),
		"fittings": func(k: BuildingKit):
			BuildingFittings.gutter(k, Vector3(-2, 2.8, 0), Vector3(2, 2.8, 0), Vector3(0, 0, 1))
			BuildingFittings.downpipe(k, Vector3(1.8, 2.75, 0.1), Vector3(1.8, 0.1, 0.0))
			BuildingFittings.hopper(k, Vector3(0, 3, 0))
			BuildingFittings.chimney(k, Vector3.ZERO, Vector2(0.6, 0.6), 1.5)
			BuildingFittings.stack(k, Vector3.ZERO, 0.5, 0.4, 5.0)
			BuildingFittings.steel_stack(k, Vector3.ZERO, 0.28, 4.6, [Vector3(3, 0, 0), Vector3(-1.5, 0, 2.6), Vector3(-1.5, 0, -2.6)], k.rng)
			BuildingFittings.flue(k, Vector3.ZERO, 0.1, 1.0)
			BuildingFittings.ac_unit(k, Vector3.ZERO)
			BuildingFittings.water_tank(k, Vector3.ZERO)
			BuildingFittings.dish(k, Vector3.ZERO)
			BuildingFittings.mast(k, Vector3.ZERO, 6.0)
			BuildingFittings.whip(k, Vector3.ZERO)
			BuildingFittings.flagpole(k, Vector3.ZERO, 6.0)
			BuildingFittings.lamp(k, Vector3.ZERO, Vector3.RIGHT)
			BuildingFittings.pipe(k, Vector3(0, 2, -2), Vector3(0, 2, 2), 0.15, Color.GRAY, Vector3(-0.25, 0, 0))
			BuildingFittings.drum(k, Vector3.ZERO, Color.DARK_RED)
			BuildingFittings.drum(k, Vector3(1, 0, 0), Color.DARK_RED, true, 0.5)
			BuildingFittings.crate(k, Vector3.ZERO, Vector3(1.0, 0.5, 0.6), Color.SADDLE_BROWN)
			BuildingFittings.pallet(k, Vector3.ZERO),
		"wire": func(k: BuildingKit):
			BuildingWire.cable(k, Vector3(0, 5, 0), Vector3(8, 4, 0), 0.4)
			BuildingWire.guy(k, Vector3(0, 5, 0), Vector3(2, 0, 0))
			BuildingWire.guy(k, Vector3(0, 2, 0), Vector3(1, 0, 1), true, "peg")
			BuildingWire.insulator(k, Vector3.ZERO)
			BuildingWire.barbed(k, Vector3(-2, 1, 0), Vector3(2, 1, 0))
			BuildingWire.topping(k, 4.0, 2.6),
	}
	for key: String in builders:
		var k := kit()
		builders[key].call(k)
		valid(k.sink.root, key)
		check(k.sink.parts == k.sink.root.get_child_count(), key + ": every part became a node")
		var bake := Mats.Bake.new()
		var bk := BuildingKit.baked(bake, null, Transform3D(Basis.IDENTITY, Vector3(5, 0, 5)))
		builders[key].call(bk)
		var baked := Node3D.new()
		add_child(baked)
		bake.commit(baked)
		check(baked.get_child_count() > 0, key + ": nothing baked")
		for mi in baked.get_children():
			check((mi as MeshInstance3D).mesh.get_aabb().size.is_finite(), key + ": baked geometry not finite")
		k.sink.root.free()
		baked.free()

	# Openings stay open: a doorway's passage and a window's daylight, the
	# opening between frame and frame, are clear of its dressing.
	var dk := kit()
	BuildingOpenings.doorway(dk, Vector3.ZERO, Vector2(1.9, 2.2), {"hood": true})
	for p in [Vector3(0, 1.0, 0), Vector3(0.7, 1.9, -0.05), Vector3(-0.7, 0.3, -0.05), Vector3(0, 1.0, 0.4)]:
		check(not occupied(dk.sink.root, p), "the doorway is open at %s" % p)
	check(occupied(dk.sink.root, Vector3(0.9, 1.0, -0.08)), "the doorway has its frame")
	dk.sink.root.free()
	var wk := kit()
	BuildingOpenings.window(wk, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), {"glazing": 0.0, "cracked": 0.0})
	for p in [Vector3(-0.3, 1.3, -0.1), Vector3(0.3, 1.3, -0.1), Vector3(0, 1.5, 0.05)]:
		check(not occupied(wk.sink.root, p), "the window is clear at %s" % p)
	check(occupied(wk.sink.root, Vector3(0, 1.5, -0.1)), "the window has its mullion")
	wk.sink.root.free()
	# A shop's display window: clear between its bars, its stall riser solid
	# under it; the stock behind the glass below a man's eye and inside the
	# wall's depth or behind it, none of it out on the pavement.
	var sfk := kit()
	BuildingOpenings.shopfront(sfk, Vector3(0, (Structure.SHOP_SILL + Structure.SHOP_HEAD) * 0.5, 0), Vector2(2.2, Structure.SHOP_HEAD - Structure.SHOP_SILL), {"glazing": 0.0, "cracked": 0.0})
	for p in [Vector3(-0.5, 1.4, -0.05), Vector3(0.5, 1.4, -0.05), Vector3(0, 1.5, 0.1)]:
		check(not occupied(sfk.sink.root, p), "the display window is clear at %s" % p)
	check(occupied(sfk.sink.root, Vector3(0, 0.35, 0.04)), "the display window has its stall riser")
	sfk.sink.root.free()
	for sd in 12:
		var dsk := kit()
		dsk.rng.seed = sd
		BuildingShops.display(dsk, 2.1, Structure.SHOP_SILL, BuildingShops.paint(sd), dsk.rng)
		var gb := _bounds(dsk.sink.root, Transform3D.IDENTITY)
		check(gb.position.y >= Structure.SHOP_SILL - 0.01 and gb.end.y < 1.45 and gb.end.z <= -0.1 and absf(gb.get_center().x) < 0.2, "a window display keeps behind the glass (%s)" % gb)
		dsk.sink.root.free()
	# The years' grime lies on the face, under the eaves' band and above the
	# plinth, on every part of the wall's body and none of its openings.
	for v in [0, 1, 2, 3]:
		var gw := Structure.preview_model("house_wall", -1, v, Vector3(2.8, 1.0, 0.4), v == 2, 77)
		var gwb := _bounds(gw, Transform3D.IDENTITY)
		check(gwb.end.y <= 3.05 and gwb.size.x <= 3.6, "a house wall (%d) keeps to its bay and under its eaves (%s)" % [v, gwb])
		gw.free()

	# Shared shapes: windows of one size share one frame mesh.
	check(BuildingOpenings.frame_shape(1.3, 1.0, 1, 0.7) == BuildingOpenings.frame_shape(1.3, 1.0, 1, 0.7), "window frames are cached")
	check(BuildingOpenings.leaf_shape(Vector2(0.88, 2.06), "panelled") == BuildingOpenings.leaf_shape(Vector2(0.88, 2.06), "panelled"), "door leaves are cached")

	# Materials: each house material has a surface, and house walls dress in it.
	for ci in 5:
		var m := BuildingMaterials.house(ci)
		check(Mats._preset(BuildingMaterials.surface(m)).has("pattern"), "house material %s has a surface" % m)
	check("brick" in BuildingMaterials.HOUSE and "stone" in BuildingMaterials.HOUSE, "towns have brick and stone houses")

	# Batched scenery keeps to world-space surfaces (StructureView merges
	# nothing in local space), so the new dressing doesn't break the batches.
	for spec: Array in [["house_wall", 0, Vector3(2.8, 2.0, 0.4)], ["house_wall", 1, Vector3(2.8, 4.0, 0.4)], ["house_wall", 2, Vector3(2.8, 2.0, 0.4)], ["house_wall", 3, Vector3(2.8, 1.0, 0.4)],
			["low_wall", 0, Vector3(4.0, 1.0, 0.5)], ["low_wall", 2, Vector3(4.0, 1.0, 0.5)], ["floor", 0, Vector3(8, 0.06, 7)]]:
		var m := Structure.preview_model(spec[0], -1, spec[1], spec[2])
		var stack: Array = [m]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var mi := n as MeshInstance3D
			if mi and mi.material_override is ShaderMaterial:
				var sm := Mats.base_of(mi.material_override) as ShaderMaterial
				check(sm.get_shader_parameter("local_space") != true, "%s %d stays batchable (%s)" % [spec[0], spec[1], sm.resource_name])
		m.free()

	# Lamplight: the global the windows read is registered, lit glass is lit
	# and plain glass isn't, and the time of day sets how much shows.
	check(ProjectSettings.has_setting("shader_globals/window_glow"), "window_glow is a registered shader global")
	check(Mats.get_mat("window_lit").get_shader_parameter("lit") == 1.0, "lit glass carries the lamplight")
	check(Mats.get_mat("glass").get_shader_parameter("lit") != 1.0, "plain glass stays dark by night")
	check(Atmosphere.lamplight("night") == 1.0 and Atmosphere.lamplight("day") == 0.0 and Atmosphere.lamplight("dusk") > 0.0, "lamplight follows the time of day")
	var lk := kit()
	BuildingOpenings.window(lk, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), {"lit": true, "glazing": 1.0, "curtains": "drapes"})
	var lit_panes := 0
	for child in lk.sink.root.get_children():
		if Mats.base_of((child as MeshInstance3D).material_override) == Mats.get_mat("window_lit"):
			lit_panes += 1
	check(lit_panes == 4, "a lit window's four whole panes glow (%d)" % lit_panes)
	lk.sink.root.free()

	# Furnishings build as nodes and into a bake.
	var furnishings := {
		"curtains": func(k: BuildingKit):
			for style in ["drapes", "blind", "nets"]:
				BuildingFurnishings.curtains(k, Vector3(0, 1.5, -0.1), Vector2(1.3, 1.0), style, Color(0.5, 0.2, 0.2)),
		"war": func(k: BuildingKit):
			var tone := func(_p: Vector2) -> Color: return Color(0.9, 0.85, 0.8)
			BuildingWeathering.streaks(k, 0.0, 1.0, 1.3, "plaster", tone, k.rng)
			BuildingWeathering.soot(k, 0.0, 2.0, 1.3, 2.85, "plaster", tone, k.rng, 1.4)
			BuildingWeathering.scar(k.at_point(Vector3(4, 0, 0)), Vector2(0, 1.5), 0.4, "plaster", tone, Color(0.5, 0.3, 0.2), Color(0.8, 0.78, 0.73), k.rng)
			BuildingWeathering.boards(k, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), k.rng)
			BuildingWeathering.sill_bags(k, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), k.rng)
			BuildingOpenings.window(k.at_point(Vector3(-4, 0, 0)), Vector3(0, 1.5, 0), Vector2(1.3, 1.0), {"glazing": 1.0, "tape": true}),
		"shops": func(k: BuildingKit):
			for kind in BuildingShops.KINDS.size():
				var sk := k.at_point(Vector3(kind * 8.0, 0, 0))
				BuildingShops.front(sk, 6.8, kind, k.rng)
				BuildingShops.wares(sk.at_point(Vector3(2.4, 0, 0)), kind, k.rng),
		"roof_patches": func(k: BuildingKit):
			BuildingWeathering.tarp(k, k.rng)
			BuildingWeathering.hole(k.at_point(Vector3(3, 0, 0)), k.rng)
			BuildingFurnishings.skylight(k.at_point(Vector3(-3, 0, 0)))
			BuildingFurnishings.skylight(k.at_point(Vector3(-3, 0, 3)), false),
		"outside": func(k: BuildingKit):
			BuildingFurnishings.window_box(k, 0.0, 1.0, 1.1, Color.RED)
			BuildingFurnishings.lantern(k, Vector3(1.2, 2.05, 0))
			BuildingFurnishings.aerial(k, Vector3(0, 5, 0)),
		"yards": func(k: BuildingKit):
			BuildingYards.bins(k, 2, BuildingYards.BIN_COLS[0])
			BuildingYards.woodpile(k.at_point(Vector3(3, 0, 0)), 1.8, k.rng)
			BuildingYards.garden_set(k.at_point(Vector3(0, 0, 3)), k.rng, true)
			BuildingYards.kennel(k.at_point(Vector3(-3, 0, 0)), Color.SADDLE_BROWN)
			BuildingYards.bicycle(k.at_point(Vector3(0, 0, -3)), BuildingYards.BIKE_COLS[0])
			BuildingYards.pots(k.at_point(Vector3(3, 0, 3)), 3, k.rng)
			BuildingYards.shed(k.at_point(Vector3(-4, 0, 3)), BuildingYards.SHEDS[0], k.rng)
			BuildingYards.trampoline(k.at_point(Vector3(5, 0, -4)), BuildingYards.PADS[0])
			BuildingYards.graves(k.at_point(Vector3(-6, 0, -4)), 5, k.rng),
		"storey": func(k: BuildingKit):
			BuildingStoreys.upper(k, 9.0, 7.6, 3.0, 5.8, "brick", BuildingMaterials.color("brick"), Color(0.86, 0.85, 0.8), k.rng),
		"fixtures": func(k: BuildingKit):
			BuildingFittings.meter_box(k, Vector3(-1, 0.5, 0))
			BuildingFittings.meter_box(k.at_point(Vector3(1, 0, 0)), Vector3.ZERO, true)
			BuildingFittings.tap(k.at_point(Vector3(3, 0, 0)), Vector3(0, 0.55, 0), BuildingFittings.HOSES[0])
			BuildingFittings.wall_unit(k.at_point(Vector3(5, 0, 0)), Vector3(0, 1.9, 0))
			BuildingFittings.wall_dish(k.at_point(Vector3(7, 0, 0)), Vector3(0, 2.45, 0))
			BuildingFittings.house_number(k, Vector3(-3, 1.7, 0), 47, BuildingFittings.NUMBERS[0][0], BuildingFittings.NUMBERS[0][1])
			BuildingFittings.letterbox(k, Vector3(-3, 1.15, 0), BuildingFittings.LETTERBOXES[0])
			BuildingFittings.doormat(k, Vector3(-5, 0.14, 0.3), BuildingFittings.MATS[0]),
		"furniture": func(k: BuildingKit):
			BuildingInteriors.wardrobe(k, 0.0, BuildingInteriors.WOODS[0], k.rng)
			BuildingInteriors.bookcase(k.at_point(Vector3(2, 0, 0)), 0.0, BuildingInteriors.WOODS[1], k.rng)
			BuildingInteriors.dresser(k.at_point(Vector3(4, 0, 0)), 0.0, BuildingInteriors.WOODS[2], k.rng)
			BuildingInteriors.settee(k.at_point(Vector3(6, 0, 0)), 0.0, 1.8, Color(0.5, 0.2, 0.15), k.rng)
			BuildingInteriors.kitchen(k.at_point(Vector3(9, 0, 0)), 0.0, 2.2, BuildingInteriors.UNITS[0], k.rng)
			BuildingInteriors.desk(k.at_point(Vector3(12, 0, 0)), 0.0, BuildingInteriors.WOODS[3], k.rng)
			BuildingInteriors.table(k.at_point(Vector3(0, 0, 5)), Vector3(9.0, 0.06, 7.6), BuildingInteriors.WOODS[0], k.rng)
			BuildingInteriors.shop(k.at_point(Vector3(0, 0, 16)), Vector3(9.0, 0.06, 10.0), k.rng),
		"street": func(k: BuildingKit):
			BuildingStreet.traffic_light(k, 1.0, k.rng)
			BuildingStreet.phone_box(k.at_point(Vector3(2, 0, 0)), Color(0.7, 0.1, 0.08), k.rng)
			BuildingStreet.post_box(k.at_point(Vector3(4, 0, 0)))
			BuildingStreet.ad_column(k.at_point(Vector3(6, 0, 0)), k.rng)
			BuildingStreet.hoarding(k.at_point(Vector3(10, 0, 0)), 5.6, k.rng)
			BuildingStreet.street_name(k.at_point(Vector3(14, 0, 0)), k.rng)
			BuildingStreet.belongings(k.at_point(Vector3(16, 0, 0)), k.rng),
		"farm": func(k: BuildingKit):
			BuildingFarm.barn(k, Vector3(13.0, 0.06, 10.0), 0, k.rng)
			BuildingFarm.wall_tools(k.at_point(Vector3(0, 0, 8)), 3.2, k.rng)
			BuildingFarm.bales(k.at_point(Vector3(0, 0, 12)), 3, false, k.rng)
			BuildingFarm.trough(k.at_point(Vector3(4, 0, 12)), k.rng)
			BuildingFarm.plough(k.at_point(Vector3(8, 0, 12)), k.rng)
			BuildingFarm.harrow(k.at_point(Vector3(12, 0, 12)), k.rng)
			BuildingFarm.churn_stand(k.at_point(Vector3(4, 0, 16)), k.rng)
			BuildingFarm.hen_house(k.at_point(Vector3(9, 0, 16)), k.rng)
			BuildingFarm.barrow(k.at_point(Vector3(13, 0, 16)), 1),
		"inside": func(k: BuildingKit):
			BuildingFurnishings.lining(k, 2.8, 3.0, [Rect2(-0.65, 1.0, 1.3, 1.0)], Color(0.8, 0.8, 0.7))
			BuildingFurnishings.radiator(k, 0.0, 1.0)
			BuildingFurnishings.picture(k, Vector3(0, 1.6, 0), Vector2(0.5, 0.4), Color.DARK_GREEN)
			BuildingFurnishings.shelf(k, Vector3(0, 2.0, 0), 1.2)
			BuildingFurnishings.rug(k, Vector3(0, 0.06, 0), Vector2(2.4, 1.8), Color.DARK_RED),
	}
	for key: String in furnishings:
		var fk := kit()
		furnishings[key].call(fk)
		valid(fk.sink.root, key)
		var bake := Mats.Bake.new()
		furnishings[key].call(BuildingKit.baked(bake))
		var baked := Node3D.new()
		add_child(baked)
		bake.commit(baked)
		check(baked.get_child_count() > 0, key + ": nothing baked")
		fk.sink.root.free()
		baked.free()
	var area := Rect2(-1.4, 0.0, 2.8, 3.0)
	var hole := Rect2(-0.65, 1.0, 1.3, 1.0)
	var total := 0.0
	for r in BuildingFurnishings.panels(area, [hole]):
		total += r.get_area()
		check(not r.intersects(hole), "a lining panel stays out of the opening")
	check(is_equal_approx(total, area.get_area() - hole.get_area()), "the lining covers the wall round its opening (%.2f)" % total)

	# Nothing in a room stands where a man does: Cover's fighting positions are
	# half a metre off every house wall, so whatever hangs on a wall stays
	# within a hand's breadth of it below head height.
	for s in 16:
		var rk := kit()
		rk.rng.seed = s
		BuildingFurnishings.wall_things(rk, 2.8)
		BuildingFurnishings.radiator(rk, 0.0, 1.0)
		for z in [0.2, 0.35, 0.5, 0.7]:
			for y in [0.15, 0.6, 1.0, 1.4, 1.8]:
				for x in [-1.1, -0.6, -0.2, 0.2, 0.6, 1.1]:
					if occupied(rk.sink.root, Vector3(x, y, z)):
						check(false, "a room's dressing stands at %s (seed %d)" % [Vector3(x, y, z), s])
		rk.sink.root.free()

	# A side's HQ stands its containers and command post where its parts are,
	# turned the way the battle puts it: its wall out in front (-z, towards
	# the enemy), its gate on the road's side (+x), its drive in running out
	# to the road's edge (11.6 m: TownGen.build_roads lays the road 14 m out)
	# and nothing past it, nor past the security fence along its back (8.5 m:
	# TownGen.military_fences). The masts, the long-range aerial and the flag
	# are the top of it, its guys' pickets driven in the bottom. Either side.
	for side in 2:
		var hq := Structure.preview_model("depot", side, 0)
		var hqb := _bounds(hq, Transform3D.IDENTITY)
		check(hq.get_child_count() > 0 and hqb.position.x >= -10.5 and hqb.end.x <= 11.65 and hqb.position.z >= -7.0 and hqb.end.z <= 8.5
			and hqb.position.y >= -0.2 and hqb.end.y < 12.0, "a side's HQ keeps to its compound (%d: %s)" % [side, hqb])
		check(hqb.position.z <= BuildingDepot.FRONT_Z - 0.4, "its wall stands out in front of it, towards the enemy (%d: %s)" % [side, hqb])
		hq.free()

	# The town square's war memorial stands within its steps, the soldier (or
	# the obelisk) on top of it; a market stall keeps to its pitch, its
	# canopy over a man's head.
	for obelisk in [false, true]:
		var mk := kit()
		BuildingSquare.memorial(mk, obelisk, mk.rng)
		var mb := _bounds(mk.sink.root, Transform3D.IDENTITY)
		check(mb.size.x <= 3.05 and mb.size.z <= 3.05 and mb.position.y >= -0.01 and mb.end.y > 4.0 and mb.end.y < 6.0, "the war memorial stands on its steps (%s)" % mb)
		mk.sink.root.free()
	# Its soldier is one cast figure, larger than life (a man of 1.8 m cast
	# 2.1 m tall, on his base), no wider than the top of his pedestal.
	var mwsk := kit()
	BuildingSquare.soldier(mwsk)
	var mwsb := _bounds(mwsk.sink.root, Transform3D.IDENTITY)
	check(mwsk.sink.parts == 1 and mwsb.position.y > -0.005 and mwsb.end.y > 2.0 and mwsb.end.y < 2.3 and mwsb.size.x < 0.9 and mwsb.size.z < 0.9,
		"the memorial's soldier is one figure 2.1 m tall on his base (%d parts, %s)" % [mwsk.sink.parts, mwsb])
	mwsk.sink.root.free()
	# Its wreaths are laid at its foot, in front: none in its stone, the statue
	# or another wreath, and each stands on the top step leaning back on the
	# plinth (moved 3 cm down, or back, it would be in the stone).
	for mwobelisk in [false, true]:
		for mwseed in 3:
			var mwk := kit()
			mwk.rng.seed = mwseed
			BuildingSquare.monument(mwk, mwobelisk, mwk.rng)
			var mwspots := BuildingSquare.wreath_spots(mwk.rng)
			check(mwspots.size() >= 2, "wreaths are laid at the memorial (%d)" % mwspots.size())
			var mwstone := _points(mwk.sink.root)
			var mwroots: Array[Node3D] = []
			for mwspot in mwspots:
				var mwwk := kit()
				BuildingSquare.wreath(mwwk.moved(mwspot))
				mwroots.append(mwwk.sink.root)
			for mwi in mwroots.size():
				var mwat := mwspots[mwi].origin
				var mwpts := _points(mwroots[mwi])
				var mwbox := _bounds(mwroots[mwi], Transform3D.IDENTITY)
				var mwsolids := _solids(mwk.sink.root, mwbox.grow(0.04))
				var mwin_stone := mwpts.size() == 0
				var mwon_step := false
				var mwon_plinth := false
				for mwp in mwpts:
					mwin_stone = mwin_stone or _inside(mwsolids, mwp)
					mwon_step = mwon_step or _inside(mwsolids, mwp + Vector3(0, -0.03, 0))
					mwon_plinth = mwon_plinth or _inside(mwsolids, mwp + Vector3(0, 0, 0.03))
				var mwwsolid := _solids(mwroots[mwi], mwbox)
				for mwq in mwstone:
					mwin_stone = mwin_stone or (mwbox.has_point(mwq) and _inside(mwwsolid, mwq))
				var mwin_wreath := false
				for mwj in mwroots.size():
					if mwj != mwi:
						for mwo in _points(mwroots[mwj]):
							mwin_wreath = mwin_wreath or (mwbox.has_point(mwo) and _inside(mwwsolid, mwo))
				var mwwhat := "(%s, seed %d, at %s)" % ["obelisk" if mwobelisk else "soldier", mwseed, mwat]
				check(not mwin_stone, "a wreath at the memorial is in its stone " + mwwhat)
				check(not mwin_wreath, "a wreath at the memorial is in another " + mwwhat)
				check(mwon_step and mwon_plinth, "a wreath at the memorial stands on its step leaning on the plinth " + mwwhat)
				check(mwat.z < -BuildingSquare.PLINTH * 0.5 and absf(mwat.x) < BuildingSquare.PLINTH * 0.5, "a wreath at the memorial is laid in front of it " + mwwhat)
			for mwr in mwroots:
				mwr.free()
			mwk.sink.root.free()
	for ci in 5:
		var stk := kit()
		BuildingSquare.stall(stk, ci, stk.rng)
		var stb := _bounds(stk.sink.root, Transform3D.IDENTITY)
		check(stb.size.x <= 2.7 and stb.size.z <= 1.7 and stb.end.y <= 2.5 and stb.position.y >= -0.01, "a market stall keeps to its pitch (%s)" % stb)
		stk.sink.root.free()
	# A field hospital (the medic tent) stands its tent where its part is, the
	# stretchers and stores by its door and the flag beside it, under 4.3 m.
	for side in 2:
		var mt := Structure.preview_model("medic_tent", side)
		var mtb := _bounds(mt, Transform3D.IDENTITY)
		check(mt.get_child_count() > 0 and mtb.size.x <= 12.5 and mtb.size.z <= 7.8 and mtb.position.y >= -0.15 and mtb.end.y <= 4.4, "a field hospital keeps to its pitch (%d: %s)" % [side, mtb])
		mt.free()
	# The street pieces keep to their footprints: the fountain within its
	# basin, the bus shelter over its pavement (its stop's flag the top of it),
	# a planter (its trough a square turned on its corner: its bounds are the
	# turned square's), a bin, the name board.
	var spieces := [[func(k: BuildingKit): BuildingStreet.fountain(k), Vector3(5.25, 3.2, 5.25)],
		[func(k: BuildingKit): BuildingStreet.bus_shelter(k, k.rng), Vector3(4.6, 2.85, 1.8)],
		[func(k: BuildingKit): BuildingStreet.planter(k, k.rng), Vector3(2.05, 1.25, 2.05)],
		[func(k: BuildingKit): BuildingStreet.litter_bin(k), Vector3(0.55, 0.95, 0.55)],
		[func(k: BuildingKit): BuildingStreet.town_sign(k, k.rng), Vector3(2.1, 2.35, 0.2)]]
	for sp: Array in spieces:
		var spk := kit()
		(sp[0] as Callable).call(spk)
		var spb := _bounds(spk.sink.root, Transform3D.IDENTITY)
		var lim: Vector3 = sp[1]
		check(spb.size.x <= lim.x and spb.size.z <= lim.z and spb.end.y <= lim.y and spb.position.y >= -0.01, "a street piece keeps to its footprint (%s, %s)" % [spb, lim])
		spk.sink.root.free()
	# A farm's bales keep to their footprint (two side by side, a third on
	# them), straw or wrapped.
	for i in 6:
		var bk := kit()
		bk.rng.seed = i
		BuildingFarm.bales(bk, 1 + i % 3, i >= 3, bk.rng)
		var bb := _bounds(bk.sink.root, Transform3D.IDENTITY)
		check(bb.size.x <= 2.9 and bb.size.z <= 1.5 and bb.end.y <= 3.15 and bb.position.y >= -0.01, "a farm's bales keep to their footprint (%s)" % bb)
		bk.sink.root.free()
	# A research post's dress keeps to its block and the ground beside it: the
	# parapet on its roof, the generator and blast wall by its walls.
	var rp := Structure.preview_model("research", 0)
	var rpb := _bounds(rp, Transform3D.IDENTITY)
	check(rp.get_child_count() > 0 and rpb.size.x <= 10.5 and rpb.size.z <= 9.5 and rpb.position.y >= -0.05 and rpb.end.y < 9.5, "a research post keeps to its plot (%s)" % rpb)
	rp.free()
	# What stands at the kerb keeps to its spot: a lamp's head out over the
	# road no further than its arm, a sign, a hydrant, a mailbox, a cabinet
	# (the bounds of a turned lantern or sign are a turned square's;
	# the sign now turns in its face plane, making that box wider, not deeper).
	var kerbs := [[func(k: BuildingKit): BuildingKerbside.column(k), Vector3(2.0, 6.45, 0.45)],
		[func(k: BuildingKit): BuildingKerbside.pole_lamp(k), Vector3(1.45, 6.05, 0.65)],
		[func(k: BuildingKit): BuildingKerbside.lantern_post(k), Vector3(0.75, 4.95, 0.75)],
		[func(k: BuildingKit): BuildingKerbside.hydrant(k), Vector3(0.55, 0.8, 0.36)],
		[func(k: BuildingKit): BuildingKerbside.stop_sign(k, k.rng), Vector3(1.03, 2.67, 0.12)],
		[func(k: BuildingKit): BuildingKerbside.mailbox(k, Color.BLUE, true), Vector3(0.3, 1.42, 0.5)],
		[func(k: BuildingKit): BuildingKerbside.cabinet(k), Vector3(1.25, 1.5, 0.75)]]
	for kb: Array in kerbs:
		var kbk := kit()
		(kb[0] as Callable).call(kbk)
		var kbb := _bounds(kbk.sink.root, Transform3D.IDENTITY)
		var kbl: Vector3 = kb[1]
		check(kbb.size.x <= kbl.x and kbb.size.z <= kbl.z and kbb.end.y <= kbl.y and kbb.position.y >= -0.01, "a kerbside piece keeps to its spot (%s, %s)" % [kbb, kbl])
		kbk.sink.root.free()
	# The water tower stands on its piers within its footprint, its finial at
	# 13.5 m or so.
	var towk := kit()
	BuildingLandmarks.water_tower(towk, towk.rng)
	var towb := _bounds(towk.sink.root, Transform3D.IDENTITY)
	check(towb.size.x <= 6.5 and towb.size.z <= 6.4 and towb.position.y >= -0.01 and towb.end.y > 13.0 and towb.end.y < 14.0, "the water tower keeps to its footprint (%s)" % towb)
	towk.sink.root.free()
	# A tunnel's mouth keeps to its 3 m plot, its shaft going down below it.
	var tn := Structure.preview_model("tunnel", 1)
	var tnb := _bounds(tn, Transform3D.IDENTITY)
	check(tn.get_child_count() > 0 and tnb.size.x <= 3.9 and tnb.size.z <= 4.6 and tnb.end.y < 2.2 and tnb.position.y < -1.0, "a tunnel's mouth keeps to its plot (%s)" % tnb)
	tn.free()
	# Weathering: ivy and weeds keep within a hand's breadth of the wall, and a
	# ruin's debris lies inside its floor, no higher than an ankle.
	for s in 10:
		var wk2 := kit()
		wk2.rng.seed = s
		BuildingWeathering.ivy(wk2, 0.0, 1.6, 2.8, wk2.rng)
		BuildingWeathering.weeds(wk2, 2.8, [Rect2(-0.95, 0.0, 1.9, 2.2)], wk2.rng)
		for child in wk2.sink.root.get_children():
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			check(box.end.z <= 0.2 and box.position.z >= -0.05, "ivy and weeds keep to the wall (%s)" % box)
			check(box.position.y >= -0.05 and box.end.y <= 2.9, "ivy keeps below the eaves (%s)" % box)
		wk2.sink.root.free()
		var rk2 := kit()
		rk2.rng.seed = s
		BuildingWeathering.ruin(rk2, Vector3(9.0, 0.06, 7.6), 0.06, rk2.rng)
		valid(rk2.sink.root, "ruin")
		for child in rk2.sink.root.get_children():
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			check(box.end.y <= 0.26 and absf(box.get_center().x) < 4.5 and absf(box.get_center().z) < 3.8, "a ruin's debris lies flat in its room (%s)" % box)
		rk2.sink.root.free()
	# Rain and the war on a wall keep to its face (boards and sandbags on the
	# sill no more than a hand's breadth out), strikes miss the openings, and a
	# stain comes back to exactly the wall's own colour at its rim.
	var window_hole := Rect2(-0.65, 1.0, 1.3, 1.0)
	var face_tone := func(_p: Vector2) -> Color: return Color(0.9, 0.85, 0.8)
	for s in 10:
		var wk3 := kit()
		wk3.rng.seed = s
		BuildingWeathering.streaks(wk3, 0.0, 1.0, 1.3, "plaster", face_tone, wk3.rng)
		BuildingWeathering.soot(wk3, 0.0, 2.0, 1.3, 2.85, "plaster", face_tone, wk3.rng, 1.4)
		BuildingWeathering.scar(wk3, Vector2(0.0, 1.5), 0.45, "plaster", face_tone, Color(0.5, 0.3, 0.2), Color(0.8, 0.78, 0.73), wk3.rng, [], 1.5)
		BuildingWeathering.boards(wk3, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), wk3.rng)
		BuildingWeathering.sill_bags(wk3, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), wk3.rng)
		for child in wk3.sink.root.get_children():
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			check(box.end.z <= 0.2 and box.position.z >= -0.15, "war and rain keep to the face (%s)" % box)
			check(box.position.y >= 0.0 and box.end.y <= 3.0 and absf(box.get_center().x) < 1.6, "war and rain keep on the wall (%s)" % box)
		wk3.sink.root.free()
		var pk := kit()
		pk.rng.seed = s
		BuildingWeathering.pocks(pk, Vector2(0.0, 1.5), 1.2, 30, Color(0.5, 0.3, 0.2), pk.rng, [window_hole])
		for child in pk.sink.root.get_children():
			var c3 := (child as MeshInstance3D).transform.origin
			check(not window_hole.has_point(Vector2(c3.x, c3.y)), "a bullet strike in a window at %s" % c3)
		pk.sink.root.free()
	var sk := kit()
	BuildingWeathering.stain(sk, Rect2(-1, 1, 2, 1), "plaster", face_tone, Color(0.1, 0.1, 0.1), func(_u: float, _v: float) -> float: return 1.0)
	var sm: MeshInstance3D = sk.sink.root.get_child(0)
	var cols: PackedColorArray = (sm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = (sm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rim := Color(0.9, 0.85, 0.8) if Mats.per_material else Color(0.9, 0.85, 0.8).srgb_to_linear()
	var rims := 0
	var darks := 0
	for i in verts.size():
		var edge := absf(absf(verts[i].x) - 1.0) < 0.001 or absf(verts[i].y - 1.0) < 0.001 or absf(verts[i].y - 2.0) < 0.001
		var c4: Color = cols[i] * Mats.VC_K
		if edge:
			rims += 1
			# (to the precision vertex colours are stored at, as the baked wall's are)
			var tol := 1.05 / 255.0 * Mats.VC_K
			check(absf(c4.r - rim.r) < tol and absf(c4.g - rim.g) < tol and absf(c4.b - rim.b) < tol, "a stain's rim is the wall's own colour (%s, %s)" % [c4, rim])
		elif c4.r < rim.r * 0.5:
			darks += 1
	check(rims > 0 and darks > 0, "a stain fades from dark to the wall (%d rim, %d dark)" % [rims, darks])
	sk.sink.root.free()

	# A flat roof's years of weather lie on its deck inside the parapets (only
	# a vent pipe stands up from it).
	for s in 10:
		var rk3 := kit()
		rk3.rng.seed = s
		BuildingRoofs.flat_wear(rk3, 7.7, 6.7, 3.2, rk3.rng)
		for child in rk3.sink.root.get_children():
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			check(box.position.x >= -3.86 and box.end.x <= 3.86 and box.position.z >= -3.36 and box.end.z <= 3.36, "a flat roof's wear keeps inside its parapets (%s)" % box)
			check(box.position.y >= 3.19 and (box.end.y <= 3.22 or box.size.x < 0.25), "a flat roof's wear lies on its deck (%s)" % box)
		rk3.sink.root.free()

	# A shop's front: its fascia and awning keep above a man's head out over
	# the pavement, and what it puts out stays within its 1.6 m along the
	# wall and a metre and a half out from it.
	for s in 6:
		for kind in BuildingShops.KINDS.size():
			var fk2 := kit()
			fk2.rng.seed = s
			BuildingShops.front(fk2, 6.8, kind, fk2.rng)
			for child in fk2.sink.root.get_children():
				var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
				check(box.end.z > BuildingShops.FACE - 0.35 or box.position.y >= 1.85, "a shop's awning keeps above head height (%s)" % box)
				check(box.position.z >= BuildingShops.FACE - 1.5 and box.end.y <= 3.1, "a shop's front keeps to its wall (%s)" % box)
			fk2.sink.root.free()
			var wk4 := kit()
			wk4.rng.seed = s
			BuildingShops.wares(wk4, kind, wk4.rng)
			valid(wk4.sink.root, "wares %s" % BuildingShops.KINDS[kind])
			for child in wk4.sink.root.get_children():
				var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
				check(absf(box.get_center().x) < 1.0 and box.position.z >= BuildingShops.FACE - 1.6 and box.end.z <= BuildingShops.FACE + 0.15, "%s wares keep to the shop front (%s)" % [BuildingShops.KINDS[kind], box])
			wk4.sink.root.free()

	var bake2 := Mats.Bake.new()
	var bk2 := BuildingKit.baked(bake2)
	BuildingWeathering.ivy(bk2, 0.0, 1.6, 2.8, bk2.rng)
	BuildingWeathering.ruin(bk2, Vector3(9.0, 0.06, 7.6), 0.06, bk2.rng)
	var baked2 := Node3D.new()
	add_child(baked2)
	bake2.commit(baked2)
	check(baked2.get_child_count() > 0, "weathering bakes")
	baked2.free()
	var ruined_floor := Structure.preview_model("floor", -1, 1, Vector3(9.0, 0.06, 7.6), false, 7)
	var plain_floor := Structure.preview_model("floor", -1, 0, Vector3(9.0, 0.06, 7.6), false, 7)
	check(ruined_floor.get_child_count() > plain_floor.get_child_count(), "a ruin's floor has its fallen roof on it")
	ruined_floor.free()
	plain_floor.free()
	# Utility poles: a pole (with or without its transformer) keeps to its
	# crossarm's span and under its cap, and an insulator stands at every
	# point the line's wires are strung to (Decor ties them at 7.66 m). What
	# comes down it to the ground (the earth wire, a transformer's cable) is
	# a thin wire stapled flat to it: below its plates nothing stands more
	# than a couple of centimetres off the pole.
	for with_tank in [false, true]:
		var uk := kit()
		BuildingUtility.pole(uk, with_tank, uk.rng)
		var ub := _bounds(uk.sink.root, Transform3D.IDENTITY)
		check(ub.position.y >= -0.01 and ub.end.y <= 8.5 and ub.position.z >= -1.05 and ub.end.z <= 1.05 and ub.position.x >= -0.4 and ub.end.x <= 0.8, "a utility pole keeps to its crossarm (%s)" % ub)
		for z: float in [-0.8, 0.0, 0.8]:
			check(occupied(uk.sink.root, Vector3(0, 7.62, z)), "a pole's wire at z %.1f has its insulator" % z)
		var pole_parts: Array[AABB] = []
		_part_boxes(uk.sink.root, Transform3D.IDENTITY, pole_parts)
		for ppb: AABB in pole_parts:
			if ppb.position.y < 1.7:
				var pp_off := maxf(maxf(absf(ppb.position.x), absf(ppb.end.x)), maxf(absf(ppb.position.z), absf(ppb.end.z)))
				check(pp_off <= 0.18, "what comes down a pole lies flat on it (%s)" % ppb)
		check(occupied(uk.sink.root, BuildingUtility.on_pole(BuildingUtility.EARTH, 3.0, 0.002)), "a pole's earth wire is stapled down it")
		if with_tank:
			check(occupied(uk.sink.root, BuildingUtility.on_pole(BuildingUtility.CABLE, 3.0, 0.003)), "a transformer's cable is clipped down its pole")
		uk.sink.root.free()
	# The vehicle works: its walls' dressing keeps close to the shed (the
	# bollards and drums an arm's length out), under the eaves, and the brick
	# dado stops either side of the shutter, so a vehicle drives out clear.
	var fk2 := kit()
	var shed := Vector3(11.0, 5.0, 10.0)
	BuildingFactory.walls(fk2, shed, Color(0.45, 0.46, 0.44), fk2.rng)
	var wb := _bounds(fk2.sink.root, Transform3D.IDENTITY)
	check(wb.position.x >= -6.4 and wb.end.x <= 6.4 and wb.position.z >= -5.8 and wb.end.z <= 5.8 and wb.end.y <= 5.2 and wb.position.y >= -0.01, "a factory's walls keep to the shed (%s)" % wb)
	for x: float in [-2.0, 0.0, 2.0]:
		check(not occupied(fk2.sink.root, Vector3(x, 0.6, -5.07)), "the factory's dado leaves the shutter clear at x %.1f" % x)
	check(occupied(fk2.sink.root, Vector3(4.0, 0.6, -5.07)), "the factory's dado runs along its front")
	fk2.sink.root.free()
	# Its chimney stands on the roof slab in the strip beside the north
	# lights, out of them and inside the eaves, its kerb and its guys'
	# blocks bedded on the slab, its mouth where the smoke is put.
	var fck := kit()
	var fcm := BuildingFactory.chimney(fck, shed, fck.rng)
	var fcb := _bounds(fck.sink.root, Transform3D.IDENTITY)
	check(fcb.position.y >= BuildingFactory.SLAB - 0.05 and fcb.end.y <= BuildingFactory.FLUE_TOP + 0.6 and absf(fcb.end.x) <= shed.x * 0.5 + 0.2
		and fcb.position.z >= -shed.z * 0.5 and fcb.end.z <= shed.z * 0.5 + 0.2, "the factory's chimney keeps to its roof slab (%s)" % fcb)
	check(is_equal_approx(fcm.y, BuildingFactory.FLUE_TOP) and occupied(fck.sink.root, Vector3(fcm.x, BuildingFactory.SLAB + 0.05, fcm.z)), "the chimney stands on its kerb on the slab under its mouth (%s)" % fcm)
	check(occupied(fck.sink.root, Vector3(fcm.x, BuildingFactory.FLUE_TOP - 1.0, fcm.z)), "the chimney's stack rises to its mouth")
	for x: float in [2.0, 3.0, 4.0]:
		for z: float in [1.5, 3.0, 3.8]:
			var under := BuildingFactory.SLAB + BuildingRoofs.sawtooth_rise(shed.x * 0.9, 3, 0.9, x) - 0.1
			check(not occupied(fck.sink.root, Vector3(x, under, z)), "the chimney keeps out of the north lights at (%.1f, %.1f)" % [x, z])
	fck.sink.root.free()
	# The pillbox: its walls, drawn from the bunker's parts, fill every part
	# that stops a bullet, short of them only at the corners' chamfer; its
	# embrasure stands out of the wall no further than its frame, round the
	# slit and under the eave; its roof slab covers the parts' roof and reaches
	# no further than its overhang, the cupola's periscope the highest thing on it.
	var pbst := Structure.new()
	pbst.skind = "bunker"
	pbst.team = 0
	pbst._define_parts()
	var pbwk := kit()
	BuildingPillbox.walls(pbwk, pbst.parts, BuildingPillbox.CONCRETE)
	var pbwb := _bounds(pbwk.sink.root, Transform3D.IDENTITY)
	check(pbwb.position.is_equal_approx(Vector3(-BuildingPillbox.HALF, 0, -BuildingPillbox.HALF)) and pbwb.end.is_equal_approx(Vector3(BuildingPillbox.HALF, 2.2, BuildingPillbox.HALF)), "a pillbox's walls stand on their parts (%s)" % pbwb)
	for p: Dictionary in pbst.parts:
		var pc: Vector3 = p.p
		var ps: Vector3 = p.s
		if pc.y - ps.y * 0.5 >= BuildingPillbox.EAVE - 0.1:
			continue
		for corner: Vector3 in [Vector3(-0.45, -0.45, -0.45), Vector3(0.45, 0.45, 0.45), Vector3(-0.45, 0.45, 0.45), Vector3(0.45, -0.45, -0.45), Vector3.ZERO]:
			var at := pc + ps * corner
			var chamfered := absf(at.x) + absf(at.z) > BuildingPillbox.HALF * 2.0 - BuildingPillbox.CHAMFER
			check(chamfered or occupied(pbwk.sink.root, at), "a pillbox's walls fill the part at %s (%s)" % [pc, at])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			check(not occupied(pbwk.sink.root, Vector3(sx * 2.74, 1.0, sz * 2.74)), "a pillbox's corner is chamfered (%d, %d)" % [sx, sz])
	pbwk.sink.root.free()
	pbst.free()
	var pbek := kit()
	BuildingPillbox.embrasure(pbek, 2.6, Color(0.5, 0.5, 0.48))
	var pbeb := _bounds(pbek.sink.root, Transform3D.IDENTITY)
	check(pbeb.position.z >= -0.1 and pbeb.end.z <= BuildingPillbox.EMBRASURE + 0.01 and pbeb.position.y >= 0.6 and pbeb.end.y < BuildingPillbox.EAVE and pbeb.size.x <= 2.6 + 1.0, "a pillbox's embrasure keeps round its slit (%s)" % pbeb)
	pbek.sink.root.free()
	var pbpk := kit()
	BuildingPillbox.roof(pbpk, Color(0.5, 0.5, 0.48), pbpk.rng)
	var pbpb := _bounds(pbpk.sink.root, Transform3D.IDENTITY)
	check(pbpb.position.y <= 2.2 and pbpb.position.x >= -BuildingPillbox.SLAB_HALF - 0.01 and pbpb.end.x <= BuildingPillbox.SLAB_HALF + 0.01 and pbpb.position.z >= -BuildingPillbox.SLAB_HALF - 0.01 and pbpb.end.z <= BuildingPillbox.SLAB_HALF + 0.01 and pbpb.end.y <= BuildingPillbox.SLAB_TOP + 0.8, "a pillbox's roof keeps to its slab (%s)" % pbpb)
	pbpk.sink.root.free()
	# The FOB's command post: its HESCO square keeps to the post's footprint
	# (the baffle of bags a step outside its way in) and under the net, and
	# its roof carries a burst layer of bags.
	var cp_root := Node3D.new()
	add_child(cp_root)
	var cp_rng := RandomNumberGenerator.new()
	cp_rng.seed = 11
	var cp_bags: Array = []
	WorksModels.command_post(cp_root, cp_rng, cp_bags)
	var cpb := _bounds(cp_root, Transform3D.IDENTITY)
	check(cpb.position.x >= -2.6 and cpb.end.x <= 2.6 and cpb.position.z >= -2.6 and cpb.end.z <= 2.6 and cpb.end.y <= 2.45, "a FOB's command post keeps to its footprint (%s)" % cpb)
	check(cp_bags.size() == 8, "a FOB's command post has its roof of bags and its baffle (%d rows)" % cp_bags.size())
	cp_root.free()
	# Cover crates: the stores stand on the ground inside the boxes their parts
	# give for cover, and one stack is loaded differently from the next.
	var loads := {}
	for id in 12:
		for v in 2:
			var cr := Structure.preview_model("crates", -1, v, Vector3.ZERO, false, id)
			var cb := _bounds(cr, Transform3D.IDENTITY)
			var reach := Vector3(0.65, 1.3, 0.65) if v == 0 else Vector3(1.3, 2.45, 0.72)
			check(cb.position.y >= -0.01 and cb.end.y <= reach.y and absf(cb.position.x) <= reach.x and cb.end.x <= reach.x and absf(cb.position.z) <= reach.z and cb.end.z <= reach.z, "crate stack %d (variant %d) keeps to its cover (%s)" % [id, v, cb])
			loads["%d|%s" % [v, cb.size.snapped(Vector3.ONE * 0.05)]] = true
			cr.free()
	check(loads.size() >= 4, "crate stacks are loaded differently (%d ways)" % loads.size())

	# Roofs: a hip rises as high as a gable of the same pitch over the same
	# walls; its underside comes down to the eaves on all four walls where a
	# gable's stands full height at its ends; and a house's roof, whatever its
	# form, pitch, wear or mending, stays over its walls and eaves.
	var hk := kit()
	var hip_rise := BuildingRoofs.hip(hk, 9.0, 7.0, 3.0, 30.0, 0.35, "roof_tile", Color.BROWN, {"wall_face": 3.7, "wall_face_x": 4.7})
	var gable_rise := BuildingRoofs.gable(hk, 9.0, 7.0, 3.0, 30.0, 0.35, "roof_tile", Color.BROWN, {"wall_face": 3.7})
	check(is_equal_approx(hip_rise, gable_rise), "a hip rises as high as a gable (%.3f, %.3f)" % [hip_rise, gable_rise])
	hk.sink.root.free()
	check(is_equal_approx(BuildingRoofs.underside(4.7, 3.7, 3.0, 30.0, 4.7, 0.0, true), 3.0), "a hip comes down to the eaves at its ends")
	check(BuildingRoofs.underside(4.7, 3.7, 3.0, 30.0, 4.7, 0.0, false) > 5.0, "a gable stands full height at its ends")
	check(is_equal_approx(BuildingRoofs.underside(4.7, 3.7, 3.0, 30.0, 0.0, 3.7, true), 3.0), "both come down to the eaves along their sides")
	var tops := {}
	for id in 40:
		var roof := Structure.preview_model("roof", -1, 2, Vector3(9.0, 3.0, 7.6), false, id)
		var box := _bounds(roof, Transform3D.IDENTITY)
		check(box.position.x >= -5.4 and box.end.x <= 5.4 and box.position.z >= -4.7 and box.end.z <= 4.7, "roof %d keeps over its walls (%s)" % [id, box])
		check(box.position.y >= -0.05 and box.end.y <= 8.2, "roof %d keeps its height (%s)" % [id, box])
		tops[snappedf(box.end.y, 0.05)] = true
		roof.free()
	check(tops.size() >= 8, "roofs are pitched differently (%d heights)" % tops.size())

	# A rubble heap keeps to the boxes it covers with (a joist or a rod may
	# stick out a little, lumps at its edges bed into the ground), in every
	# size a fallen wall leaves.
	for s in 10:
		for sz: Vector3 in [Vector3(3.2, 0, 1.2), Vector3(2.2, 0, 1.4), Vector3(1.4, 0, 1.0)]:
			var rb := Structure.preview_model("rubble", -1, 0, sz, false, 300 + s)
			var box := _bounds(rb, Transform3D.IDENTITY)
			check(rb.get_child_count() > 0 and box.position.y >= -0.15 and box.end.y <= 2.2, "a rubble heap builds, no higher than a joist sticking out (%s)" % box)
			check(absf(box.get_center().x) < 0.5 and box.size.x <= sz.x + 1.0 and box.size.z <= maxf(1.0, sz.z) + 1.0, "a rubble heap keeps to its footprint (%s, %s)" % [sz, box])
			rb.free()

	# A farm's barn: weatherboarded walls, a steeper sheet roof with no
	# chimney, straw on a bare floor, in each of its three colours.
	var timber := BuildingMaterials.HOUSE.find("timber")
	var n_mat := BuildingMaterials.HOUSE.size()
	check(BuildingMaterials.house(timber) == "timber" and BuildingMaterials.house(timber + n_mat) == "timber", "a barn is weatherboarded")
	for ci in [timber, timber + n_mat, timber + n_mat * 2]:
		for v in 3:
			var bw := Structure.preview_model("house_wall", -1, v, Vector3(2.8, float(ci), 0.4), v == 2, 50 + v)
			check(bw.get_child_count() > 0, "a barn's wall builds (%d/%d)" % [ci, v])
			bw.free()
		var br := Structure.preview_model("roof", -1, ci * 2, Vector3(13.0, 3.0, 10.0), false, ci)
		var bb := _bounds(br, Transform3D.IDENTITY)
		check(br.get_child_count() > 0 and bb.end.y < 3.0 + 5.2 * tan(deg_to_rad(40.5)) + 0.3, "a barn's roof builds, no chimney over it (%s)" % bb)
		br.free()
	# (and its floor is fitted out as a barn's: straw over it, the hay
	# stacked, the stalls, under its roof)
	var bf := Structure.preview_model("floor", -1, 2, Vector3(13.0, 0.06, 10.0), false, 3)
	var bfb := _bounds(bf, Transform3D.IDENTITY)
	check(bf.get_child_count() > 0 and bfb.end.y > 1.0 and bfb.end.y < 3.0, "a barn's floor is fitted out under its roof (%s)" % bfb)
	bf.free()

	# A second storey is drawn with the roof over it: the roof the same, a
	# storey higher, the storey on the ground floor's walls (sills and bands
	# no further out than theirs).
	for ci in [1, 2, 4]:
		for flat in [0, 1]:
			var one := Structure.preview_model("roof", -1, ci * 2 + flat, Vector3(9.0, 3.0, 7.6), false, 21)
			var two := Structure.preview_model("roof", -1, ci * 2 + flat, Vector3(9.0, 5.8, 7.6), false, 21)
			var b1 := _bounds(one, Transform3D.IDENTITY)
			var b2 := _bounds(two, Transform3D.IDENTITY)
			check(absf(b2.end.y - b1.end.y - 2.8) < 0.02, "a second storey lifts the roof a storey (%d: %s, %s)" % [ci, b1, b2])
			check(b2.size.x <= maxf(b1.size.x, 9.0 + 0.4) + 0.3 and b2.size.z <= maxf(b1.size.z, 7.6 + 0.4) + 0.3, "a second storey keeps to the walls' lines (%d: %s, %s)" % [ci, b1, b2])
			one.free()
			two.free()
	var stk := kit()
	BuildingStoreys.upper(stk, 9.0, 7.6, 3.0, 5.8, "plaster", Color(0.8, 0.75, 0.7), Color.WHITE, stk.rng)
	var stb := _bounds(stk.sink.root, Transform3D.IDENTITY)
	check(stb.position.y >= 2.75 and stb.end.y <= 5.85 and absf(stb.get_center().x) < 0.05 and stb.size.x <= 9.6 and stb.size.z <= 8.2, "a storey stands on the ground floor's lines (%s)" % stb)
	var panes := 0
	for child in stk.sink.root.get_children():
		var mat := Mats.base_of((child as MeshInstance3D).material_override)
		if mat == Mats.get_mat("glass") or mat == Mats.get_mat("window_lit"):
			panes += 1
	check(panes >= 12, "a storey has its windows (%d panes)" % panes)
	stk.sink.root.free()

	# What's fixed to a house wall keeps to the room Structure gives it (its
	# placing relies on these reaches), sits on the face, and stands proud of
	# it no further than a dish on its arm, below the gutter; some plain walls
	# carry one.
	var reach := {
		"meter": [func(k: BuildingKit): BuildingFittings.meter_box(k, Vector3(0, 0.5, 0)), Vector2(-0.25, 0.25), 0.3],
		"gas": [func(k: BuildingKit): BuildingFittings.meter_box(k, Vector3.ZERO, true), Vector2(-0.25, 0.25), 0.3],
		"tap": [func(k: BuildingKit): BuildingFittings.tap(k, Vector3(0, 0.55, 0), BuildingFittings.HOSES[1]), Vector2(-0.05, 0.6), 0.25],
		"unit": [func(k: BuildingKit): BuildingFittings.wall_unit(k, Vector3(0, 1.9, 0)), Vector2(-0.42, 0.56), 0.52],
		"dish": [func(k: BuildingKit): BuildingFittings.wall_dish(k, Vector3(0, 2.1, 0), Vector3(1.0, 0.6, 0)), Vector2(-0.4, 0.4), 0.72],
		"number": [func(k: BuildingKit): BuildingFittings.house_number(k, Vector3(0, 1.72, 0), 88, Color.BLUE, Color.WHITE), Vector2(-0.15, 0.15), 0.03],
		"letterbox": [func(k: BuildingKit): BuildingFittings.letterbox(k, Vector3(0, 1.15, 0), Color.RED), Vector2(-0.15, 0.15), 0.14],
	}
	for name: String in reach:
		var fk := kit()
		(reach[name][0] as Callable).call(fk)
		var fb := _bounds(fk.sink.root, Transform3D.IDENTITY)
		var span: Vector2 = reach[name][1]
		check(fk.sink.root.get_child_count() > 0 and fb.position.x >= span.x and fb.end.x <= span.y, "a %s keeps its width on the wall (%s)" % [name, fb])
		check(fb.position.z >= -0.2 and fb.end.z <= reach[name][2] and fb.position.y >= -0.05 and fb.end.y <= 2.65, "a %s keeps to the face, clear of the gutter (%s)" % [name, fb])
		fk.sink.root.free()
	var fitted := 0
	for s in 240:
		var L: float = [2.6, 2.8, 3.3][s % 3]
		var pw := Structure.preview_model("house_wall", -1, 0, Vector3(L, float(s % 5), 0.4), false, 900 + s)
		var pb := _bounds(pw, Transform3D.IDENTITY)
		check(pb.end.y <= 3.05, "a plain wall's fittings keep below its eaves (%s, %s)" % [L, pb])
		if pb.end.z > 0.6:
			fitted += 1
		pw.free()
	check(fitted >= 8 and fitted < 120, "some plain walls carry a dish or an air conditioner (%d of 240)" % fitted)

	# A house that's dark (a ruin, or hit, or burning) has no lamp lit
	# anywhere: not in a window, not by the door, not under a skylight. The
	# same walls and roofs lit are found among the first ids.
	var lit_walls := 0
	var lit_roofs := 0
	for id in 120:
		for v in [1, 2]:
			var lw := Structure.preview_model("house_wall", -1, v, Vector3(2.8, float(id % 5), 0.4), false, id)
			var dw := Structure.preview_model("house_wall", -1, v, Vector3(2.8, float(id % 5), 0.4), false, id, true)
			if _lit(lw) > 0:
				lit_walls += 1
			check(_lit(dw) == 0, "a dark house's wall has no lamp lit (%d/%d)" % [id, v])
			lw.free()
			dw.free()
		var lr := Structure.preview_model("roof", -1, (id % 5) * 2, Vector3(9.0, 3.0, 7.6), false, id)
		var dr := Structure.preview_model("roof", -1, (id % 5) * 2, Vector3(9.0, 3.0, 7.6), false, id, true)
		if _lit(lr) > 0:
			lit_roofs += 1
		check(_lit(dr) == 0, "a dark house's roof has no skylight lit (%d)" % id)
		lr.free()
		dr.free()
	check(lit_walls >= 20 and lit_roofs >= 2, "some houses have their lamps on (%d walls, %d roofs)" % [lit_walls, lit_roofs])

	# A tarp lies on its slope, its weights on it and its cords run down to
	# the eave, no further.
	for s in 12:
		var tk := kit()
		tk.rng.seed = s
		BuildingWeathering.tarp(tk, tk.rng, 2.4)
		var tb := _bounds(tk.sink.root, Transform3D.IDENTITY)
		check(tb.position.y >= -0.25 and tb.end.y <= 0.3, "a tarp lies on the slope (%s)" % tb)
		check(absf(tb.get_center().x) < 0.5 and tb.size.x <= 3.2 and tb.position.z >= -2.6 and tb.end.z <= 1.2, "a tarp keeps to its patch and the eave (%s)" % tb)
		tk.sink.root.free()
	# (and a storey's lamps go out with the rest of the house's)
	var dark_storeys := 0
	for id in 40:
		var ls := Structure.preview_model("roof", -1, (id % 5) * 2, Vector3(9.0, 5.8, 7.6), false, id)
		var ds := Structure.preview_model("roof", -1, (id % 5) * 2, Vector3(9.0, 5.8, 7.6), false, id, true)
		if _lit(ls) > 0:
			dark_storeys += 1
		check(_lit(ds) == 0, "a dark house's floor above has no lamp lit (%d)" % id)
		ls.free()
		ds.free()
	check(dark_storeys >= 5, "some floors above have a lamp on (%d of 40)" % dark_storeys)

	# The parish church: its tower, the cross on its spire the top of it, its
	# ground stage open to the west (a doorway men pass, solid above); its nave
	# and chancel house walls (the west and south doors, lancets), floors (pews,
	# the pulpit, the altar) and roofs that build, the roof's gable no higher
	# than its pitch; the south porch in front of the south door.
	var church := Structure.preview_model("church", -1, BuildingMaterials.HOUSE.find("church"), Vector3(Structure.CHURCH_TOWER, Structure.CHURCH_TOWER_H, Structure.CHURCH_TOWER), false, 1)
	var chb := _bounds(church, Transform3D.IDENTITY)
	check(church.get_child_count() > 0 and chb.end.y > 24.0 and chb.end.y < 27.5 and chb.size.x < 6.0 and chb.size.z < 6.0 and chb.position.y > -1.2, "the church tower builds, its spire the top of it (%s)" % chb)
	church.free()
	var tower_parts: Array = Structure.preview_parts("church", Vector3(Structure.CHURCH_TOWER, Structure.CHURCH_TOWER_H, Structure.CHURCH_TOWER))
	var solid_low := 0
	var doorway_free := true
	for tp: Dictionary in tower_parts:
		var lo: float = tp.p.y - tp.s.y * 0.5
		if int(tp.nav) == Nav.SOLID:
			solid_low += 1
			# nothing solid across the doorway's line through the west wall
			if absf(tp.p.x) < Structure.CHURCH_WEST_DOOR * 0.5 + tp.s.x * 0.5 - 0.01 and tp.p.z < 0.0 and lo < 2.0:
				doorway_free = false
		elif lo < 2.0:
			doorway_free = false
	check(solid_low >= 4 and doorway_free, "the tower's ground stage has walls round it and a doorway through its west wall (%d)" % solid_low)
	var cci := BuildingMaterials.HOUSE.find("church")
	check(BuildingMaterials.house(cci) == "church" and BuildingMaterials.house(cci + BuildingMaterials.HOUSE.size()) == "church", "a church is rendered in its own limewash")
	for body: Array in [[8.0, 14.0, 6.2, false], [5.6, 4.4, 5.0, true]]:
		var plan := Structure.church_walls(body[0], body[1], body[3])
		var doors := 0
		for e: Array in plan:
			var cw := Structure.preview_model("house_wall", -1, e[3], Vector3(e[2], float(cci), 0.4), int(e[3]) == 2, 60 + doors)
			check(cw.get_child_count() > 0, "a church wall builds (%s)" % [e])
			cw.free()
			if int(e[3]) == 2:
				doors += 1
		check(doors == (0 if body[3] else 2), "a church's nave has its west and south doors, its chancel none (%d)" % doors)
		var porches := 0
		for e: Array in plan:
			if not Structure.church_porch(e).is_empty():
				porches += 1
		check(porches == (0 if body[3] else 1), "the south door has its porch (%d)" % porches)
		var cr2 := Structure.preview_model("roof", -1, cci * 2, Vector3(body[0], body[2], body[1]), false, 5)
		var crb := _bounds(cr2, Transform3D.IDENTITY)
		check(cr2.get_child_count() > 0 and crb.end.y < body[2] + body[0] * 0.5 * tan(deg_to_rad(50.0)) + 1.4 and crb.position.y > -0.1, "a church roof builds over its walls (%s)" % crb)
		cr2.free()
		var cf := Structure.preview_model("floor", -1, 3, Vector3(body[0], 0.06, body[1]), false, 5)
		var cfb := _bounds(cf, Transform3D.IDENTITY)
		check(cf.get_child_count() > 0 and cfb.end.y < 3.05 and cfb.size.x <= body[0] + 0.5, "a church floor builds: its fittings, and its corners' quoins no higher than the ground floor's walls (%s)" % cfb)
		cf.free()

	# What a ruined or shelled house sheds lies flat on the ground in front of
	# the wall it came off, within its length and a metre and a half of it;
	# and a dark wall carries it while a lit one doesn't.
	for s in 10:
		var spk := kit()
		spk.rng.seed = s
		BuildingWeathering.spill(spk, 2.8, Color(0.8, 0.75, 0.7), spk.rng)
		BuildingWeathering.shards(spk, 0.0, 1.3, spk.rng)
		var spb := _bounds(spk.sink.root, Transform3D.IDENTITY)
		check(spb.position.y >= -0.04 and spb.end.y <= 0.2 and spb.position.x >= -1.55 and spb.end.x <= 1.55 and spb.position.z >= 0.0 and spb.end.z <= 1.85, "debris lies flat by its wall (%s)" % spb)
		spk.sink.root.free()
	var lit_wall := Structure.preview_model("house_wall", -1, 0, Vector3(2.8, 1.0, 0.4), false, 31)
	var dark_wall := Structure.preview_model("house_wall", -1, 0, Vector3(2.8, 1.0, 0.4), false, 31, true)
	check(_bounds(dark_wall, Transform3D.IDENTITY).end.z > _bounds(lit_wall, Transform3D.IDENTITY).end.z + 0.5, "a dark house's wall has its debris in front of it")
	lit_wall.free()
	dark_wall.free()
	# What stands against a wall keeps its reach out from it and in from its
	# ends (so two walls meeting in a corner never put things in each other's
	# way), on the floor and under the ceiling; the table and chairs keep to
	# the middle of the room.
	for s2 in 60:
		var L: float = [2.33, 2.6, 2.8, 3.1, 3.5][s2 % 5]
		var ak := kit()
		ak.rng.seed = s2
		BuildingInteriors.against_wall(ak, L, ak.rng)
		var ab := _bounds(ak.sink.root, Transform3D.IDENTITY)
		check(ak.sink.root.get_child_count() > 0, "something stands against a %.2f m wall" % L)
		check(ab.position.x >= -L * 0.5 + BuildingInteriors.REACH - 0.06 and ab.end.x <= L * 0.5 - BuildingInteriors.REACH + 0.06, "it keeps in from the wall's ends (%.2f: %s)" % [L, ab])
		check(ab.position.z >= -0.01 and ab.end.z <= BuildingInteriors.REACH + 0.02 and ab.position.y >= 0.0 and ab.end.y <= 2.6, "it keeps within reach of the wall, under the ceiling (%.2f: %s)" % [L, ab])
		ak.sink.root.free()
		# (and a shop's wall the same: its shelving, its cooler, its rack)
		var swk := kit()
		swk.rng.seed = s2
		BuildingInteriors.shop_wall(swk, L, swk.rng)
		var swb := _bounds(swk.sink.root, Transform3D.IDENTITY)
		check(swk.sink.root.get_child_count() > 0, "a shop's %.2f m wall is fitted out" % L)
		check(swb.position.x >= -L * 0.5 + BuildingInteriors.REACH - 0.06 and swb.end.x <= L * 0.5 - BuildingInteriors.REACH + 0.06, "a shop's fittings keep in from the wall's ends (%.2f: %s)" % [L, swb])
		check(swb.position.z >= -0.01 and swb.end.z <= BuildingInteriors.REACH + 0.02 and swb.position.y >= 0.0 and swb.end.y <= 2.6, "a shop's fittings keep within reach of the wall, under the ceiling (%.2f: %s)" % [L, swb])
		swk.sink.root.free()
		var tk := kit()
		tk.rng.seed = s2
		BuildingInteriors.table(tk, Vector3(9.0, 0.06, 7.6), BuildingInteriors.WOODS[0], tk.rng)
		var tb := _bounds(tk.sink.root, Transform3D.IDENTITY)
		check(tb.position.y >= 0.0 and tb.end.y <= 1.2 and absf(tb.get_center().x) < 1.0 and absf(tb.get_center().z) < 1.0 and tb.size.x < 3.6 and tb.size.z < 3.6, "a table and its chairs keep to the middle of the room (%s)" % tb)
		tk.sink.root.free()

	# Every shop size is checked with a door on each of its four walls.
	# Inspect in the entrance frame so end doors exercise the swapped axes.
	for s5 in 96:
		var size5: Vector3 = [Vector3(9.0, 0.06, 10.0), Vector3(7.4, 0.06, 9.4), Vector3(12.6, 0.06, 10.5), Vector3(6.5, 0.06, 9.0)][s5 % 4]
		var entry5 := (s5 / 4) % 4
		var shk := kit()
		shk.rng.seed = s5
		BuildingInteriors.shop(shk, size5, shk.rng, entry5)
		var turn5: float = [0.0, PI, PI * 0.5, -PI * 0.5][entry5]
		var frame5 := Transform3D(Basis(Vector3.UP, turn5), Vector3.ZERO).affine_inverse()
		var shb := _bounds(shk.sink.root, frame5)
		if entry5 >= 2:
			size5 = Vector3(size5.z, size5.y, size5.x)
		check(shb.position.y >= -0.001 and shb.end.y <= 1.7, "a shop's fittings stand on its floor (%s)" % shb)
		check(shb.position.x >= -size5.x * 0.5 + 0.2 + BuildingInteriors.REACH - 0.05 and shb.end.x <= size5.x * 0.5 - 0.2 - BuildingInteriors.REACH + 0.05, "shop fittings clear side furniture (%d, %s)" % [entry5, shb])
		check(shb.position.z >= -size5.z * 0.5 + 1.9 and shb.end.z <= size5.z * 0.5 - 0.2 - BuildingInteriors.REACH + 0.05, "shop fittings clear the actual entrance (%d, %s)" % [entry5, shb])
		shk.sink.root.free()

	# The streets' furniture stands on the pavement inside the box a vehicle
	# or a blast knocks it down as (Decor.BREAKABLE), whatever it drew.
	var street_kits := {
		"traffic_light": func(k: BuildingKit): BuildingStreet.traffic_light(k, -1.0, k.rng),
		"phone_box": func(k: BuildingKit): BuildingStreet.phone_box(k, Color(0.22, 0.3, 0.24), k.rng),
		"post_box": func(k: BuildingKit): BuildingStreet.post_box(k),
		"ad_column": func(k: BuildingKit): BuildingStreet.ad_column(k, k.rng),
		"hoarding": func(k: BuildingKit): BuildingStreet.hoarding(k, 5.0, k.rng),
		"street_name": func(k: BuildingKit): BuildingStreet.street_name(k, k.rng),
	}
	for kind: String in street_kits:
		var size: Vector3 = Decor.BREAKABLE[kind][0]
		for s3 in 12:
			var skt := kit()
			skt.rng.seed = s3
			(street_kits[kind] as Callable).call(skt)
			var sb := _bounds(skt.sink.root, Transform3D.IDENTITY)
			check(sb.position.y >= -0.02 and sb.end.y <= size.y + 0.2, "a %s stands on the pavement, no taller than it falls (%s)" % [kind, sb])
			check(maxf(absf(sb.position.x), absf(sb.end.x)) <= size.x * 0.5 + 0.9 and maxf(absf(sb.position.z), absf(sb.end.z)) <= size.z * 0.5 + 0.9, "a %s keeps near its own box (%s)" % [kind, sb])
			skt.sink.root.free()
	for s4 in 20:
		var bk := kit()
		bk.rng.seed = s4
		BuildingStreet.belongings(bk, bk.rng)
		var bb := _bounds(bk.sink.root, Transform3D.IDENTITY)
		check(bb.position.y >= -0.02 and bb.end.y <= 1.1 and bb.size.x <= 3.4 and bb.size.z <= 3.4, "what was dropped lies on the pavement in a heap (%s)" % bb)
		bk.sink.root.free()

	# A barn's fittings keep inside it and clear of the wall its door is in,
	# whichever wall that is; what stands within reach of a wall keeps under
	# the tools hung on it, and they keep above it, out from their wall's ends.
	for s6 in 32:
		var entry := s6 % 4
		var size6: Vector3 = [Vector3(13.0, 0.06, 10.0), Vector3(12.0, 0.06, 9.0)][(s6 >> 2) % 2]
		var bnk := kit()
		bnk.rng.seed = s6
		BuildingFarm.barn(bnk, size6, entry, bnk.rng)
		var bhx := size6.x * 0.5 - 0.2
		var bhz := size6.z * 0.5 - 0.2
		var whole := _bounds(bnk.sink.root, Transform3D.IDENTITY)
		check(whole.position.y >= 0.0 and whole.end.y <= 2.9 and whole.position.x >= -bhx - 0.02 and whole.end.x <= bhx + 0.02 and whole.position.z >= -bhz - 0.02 and whole.end.z <= bhz + 0.02, "a barn's fittings stand inside its walls (%s, %s)" % [size6, whole])
		var clear: float = [whole.position.z + bhz, bhz - whole.end.z, whole.position.x + bhx, bhx - whole.end.x][entry]
		check(clear >= 2.25, "they keep clear of the wall its door is in (%d, %s, %.2f)" % [entry, size6, clear])
		var boxes: Array[AABB] = []
		_part_boxes(bnk.sink.root, Transform3D.IDENTITY, boxes)
		for pb in boxes:
			var off := minf(minf(pb.position.x + bhx, bhx - pb.end.x), minf(pb.position.z + bhz, bhz - pb.end.z))
			if off < 0.65:
				check(pb.end.y <= BuildingFarm.LOW + BuildingFarm.FLOOR + 0.02, "what stands by a barn's wall keeps under its tools (%s, %.2f m out)" % [pb, off])
		bnk.sink.root.free()
	for s7 in 30:
		var L7: float = [2.6, 3.2, 2.33][s7 % 3]
		var wall_tk := kit()
		wall_tk.rng.seed = s7
		BuildingFarm.wall_tools(wall_tk, L7, wall_tk.rng)
		var wall_tb := _bounds(wall_tk.sink.root, Transform3D.IDENTITY)
		check(wall_tb.position.y >= BuildingFarm.TOOLS - 0.01 and wall_tb.end.y <= 2.6 and wall_tb.position.z >= -0.01 and wall_tb.end.z <= 0.25, "a barn's tools hang on its wall above what stands against it (%.2f: %s)" % [L7, wall_tb])
		check(wall_tb.position.x >= -L7 * 0.5 + 0.63 and wall_tb.end.x <= L7 * 0.5 - 0.63, "they keep in from the wall's ends (%.2f: %s)" % [L7, wall_tb])
		wall_tk.sink.root.free()
	# The farmyard's kit stands on the ground inside the box a vehicle or a
	# blast knocks it down as.
	var farm_kits := {
		"trough": func(k: BuildingKit): BuildingFarm.trough(k, k.rng),
		"plough": func(k: BuildingKit): BuildingFarm.plough(k, k.rng),
		"harrow": func(k: BuildingKit): BuildingFarm.harrow(k, k.rng),
		"churn_stand": func(k: BuildingKit): BuildingFarm.churn_stand(k, k.rng),
		"hen_house": func(k: BuildingKit): BuildingFarm.hen_house(k, k.rng),
		"barrow": func(k: BuildingKit): BuildingFarm.barrow(k, k.rng.randi()),
	}
	for kind: String in farm_kits:
		var fsize: Vector3 = Decor.BREAKABLE[kind][0]
		for s8 in 12:
			var fyk := kit()
			fyk.rng.seed = s8
			(farm_kits[kind] as Callable).call(fyk)
			var fb := _bounds(fyk.sink.root, Transform3D.IDENTITY)
			check(fb.position.y >= -0.02 and fb.end.y <= fsize.y + 0.2, "a %s stands on the ground, no taller than it falls (%s)" % [kind, fb])
			check(maxf(absf(fb.position.x), absf(fb.end.x)) <= fsize.x * 0.5 + 0.3 and maxf(absf(fb.position.z), absf(fb.end.z)) <= fsize.z * 0.5 + 0.3, "a %s keeps inside its own box (%s)" % [kind, fb])
			fyk.sink.root.free()

	# A field-stone wall's top is stones on edge, not a lid laid over it: one
	# cached part a wall, drawn in field stone (the face's own stone, without
	# its joints), kept to the wall's length and about its width, tall and
	# short stones in turn down to the joints between them, so its skyline is
	# ragged; and cheap, since a map has a hundred and more of these walls.
	var fsc_k := kit()
	var fsc_top := BuildingWalls.coping(fsc_k, 4.0, 0.5, 1.0, "fieldstone", BuildingMaterials.color("fieldstone"))
	check(fsc_k.sink.parts == 1 and fsc_top > 1.15 and fsc_top < 1.35, "a field-stone wall's top is one part (%d) standing up to %.2f" % [fsc_k.sink.parts, fsc_top])
	var fsc_mi := fsc_k.sink.root.get_child(0) as MeshInstance3D
	var fsc_mat := Mats.base_of(fsc_mi.material_override) as ShaderMaterial
	check(int(fsc_mat.get_shader_parameter("pattern")) == Mats.FIELDSTONE and float(fsc_mat.get_shader_parameter("seams")) == 0.0 and fsc_mat.get_shader_parameter("use_vcolor") == true,
		"its stones are field stone, each a stone of its own, shaded by its vertex colours")
	var fsc_box := fsc_mi.transform * fsc_mi.mesh.get_aabb()
	check(fsc_box.position.x >= -2.01 and fsc_box.end.x <= 2.01 and fsc_box.size.z <= 0.62 and fsc_box.position.y >= 0.95, "they keep to the wall's length and about its width (%s)" % fsc_box)
	var fsc_v: PackedVector3Array = fsc_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(fsc_v.size() <= 1500, "a 4 m top costs %d vertices" % fsc_v.size())
	# (the skyline: how high it stands every 4 cm along the wall's middle)
	var fsc_sky := PackedFloat32Array()
	for fsc_i in 100:
		fsc_sky.append(_top_at(fsc_v, Vector3(-1.98 + fsc_i * 0.04, 1.0, 0.0)))
	var fsc_turns := 0
	for fsc_i in range(1, 99):
		if (fsc_sky[fsc_i] - fsc_sky[fsc_i - 1]) * (fsc_sky[fsc_i + 1] - fsc_sky[fsc_i]) < 0.0:
			fsc_turns += 1
	var fsc_joints := 0
	for fsc_h in fsc_sky:
		if fsc_h < 0.07:
			fsc_joints += 1  # (down in a joint, on the mortar)
	var fsc_sorted := fsc_sky.duplicate()
	fsc_sorted.sort()
	var fsc_short: float = fsc_sorted[20]
	var fsc_tall: float = fsc_sorted[90]
	check(fsc_joints <= 15 and fsc_short > 0.07 and fsc_tall - fsc_short > 0.06 and fsc_tall < BuildingWalls.CROWN_H + 0.01 and fsc_turns >= 20,
		"its skyline is ragged, stones all along (%d in joints, short %.2f, tall %.2f, %d turns)" % [fsc_joints, fsc_short, fsc_tall, fsc_turns])
	# the same wall's top again is the same mesh; other walls take other layouts
	var fsc_meshes := {}
	for fsc_s in 24:
		var fsc_k2 := kit()
		fsc_k2.rng.seed = fsc_s
		BuildingWalls.coping(fsc_k2, 4.0, 0.5, 1.0, "fieldstone", BuildingMaterials.color("fieldstone"))
		fsc_meshes[(fsc_k2.sink.root.get_child(0) as MeshInstance3D).mesh] = true
		fsc_k2.sink.root.free()
	check(fsc_meshes.size() >= 3 and fsc_meshes.size() <= BuildingWalls.CROWN_LAYOUTS, "walls share a few cached tops (%d)" % fsc_meshes.size())
	fsc_k.sink.root.free()
	# a stone garden wall is built so
	var fsc_wall := Structure.preview_model("low_wall", -1, 0, Vector3(4.0, 1.0, 0.5))
	var fsc_found := false
	var fsc_stack: Array = [fsc_wall]
	while not fsc_stack.is_empty():
		var fsc_child: Node = fsc_stack.pop_back()
		fsc_stack.append_array(fsc_child.get_children())
		var fsc_wm := fsc_child as MeshInstance3D
		if fsc_wm != null and fsc_wm.mesh != null:
			for fsc_si in fsc_wm.mesh.get_surface_count():
				var fsc_sm := fsc_wm.mesh.surface_get_material(fsc_si) as ShaderMaterial
				if fsc_wm.material_override is ShaderMaterial:
					fsc_sm = fsc_wm.material_override
				if fsc_sm != null and fsc_sm.get_shader_parameter("seams") == 0.0 and fsc_sm.get_shader_parameter("pattern") == Mats.FIELDSTONE:
					fsc_found = true
	check(fsc_found, "a stone garden wall is topped with field stones on edge")
	fsc_wall.free()

	# Every building and every kind of scenery still builds a model.
	var kinds: Array = Defs.BUILDINGS.keys()
	kinds.append_array(["house_wall", "roof", "floor", "low_wall", "tall_wall", "bridge", "town", "depot", "rubble", "crates", "dock"])
	for kind: String in kinds:
		for side in [0, 1]:
			for v in [0, 1, 2]:
				var sz := Vector3.ZERO
				match kind:
					"house_wall": sz = Vector3(2.8, float(v * 2), 0.4)
					"roof": sz = Vector3(9.0, 3.0, 7.0)
					"low_wall", "tall_wall": sz = Vector3(4.0, 2.6 if kind == "tall_wall" else 1.0, 0.5)
					"bridge": sz = Vector3(8.0, 1.0, 14.0)
					"floor": sz = Vector3(8.0, 0.06, 7.0)
					"town": sz = Vector3(3.6, 2.0, 2.4)
					"depot": sz = Vector3(17, 3, 11)
				var m := Structure.preview_model(kind, side, v + (4 if kind == "roof" and v == 2 else 0), sz, v == 2)
				check(m != null and m.get_child_count() > 0, "%s/%d/%d builds" % [kind, side, v])
				m.free()
	print("BUILDING_COMPONENTS %s (%d failures)" % ["passed" if _failures == 0 else "failed", _failures])
	TestRun.quit(get_tree())
