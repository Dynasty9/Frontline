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
	for child in root.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.transform.affine_inverse() * point
		if not mi.mesh.get_aabb().grow(0.001).has_point(local):
			continue
		var faces := mi.mesh.get_faces()
		var dir := Vector3(0.137, 0.913, 0.384).normalized()
		var hits := 0
		for i in range(0, faces.size(), 3):
			if Geometry3D.ray_intersects_triangle(local, dir, faces[i], faces[i + 1], faces[i + 2]) != null:
				hits += 1
		if hits % 2 == 1:
			return true
	return false


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
			for m in ["plaster", "brick", "stone", "concrete"]:
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
	for spec: Array in [["house_wall", 0, Vector3(2.8, 2.0, 0.4)], ["house_wall", 1, Vector3(2.8, 4.0, 0.4)], ["house_wall", 2, Vector3(2.8, 2.0, 0.4)],
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
			BuildingWeathering.scar(k.at_point(Vector3(4, 0, 0)), Vector2(0, 1.5), 0.4, "plaster", tone, k.rng)
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
			BuildingYards.pots(k.at_point(Vector3(3, 0, 3)), 3, k.rng),
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
		BuildingWeathering.scar(wk3, Vector2(0.0, 1.5), 0.45, "plaster", face_tone, wk3.rng, [], 1.5)
		BuildingWeathering.boards(wk3, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), wk3.rng)
		BuildingWeathering.sill_bags(wk3, Vector3(0, 1.5, 0), Vector2(1.3, 1.0), wk3.rng)
		for child in wk3.sink.root.get_children():
			var box: AABB = (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			check(box.end.z <= 0.2 and box.position.z >= -0.15, "war and rain keep to the face (%s)" % box)
			check(box.position.y >= 0.0 and box.end.y <= 3.0 and absf(box.get_center().x) < 1.6, "war and rain keep on the wall (%s)" % box)
		wk3.sink.root.free()
		var pk := kit()
		pk.rng.seed = s
		BuildingWeathering.pocks(pk, Vector2(0.0, 1.5), 1.2, 30, "plaster", face_tone, pk.rng, [window_hole])
		for child in pk.sink.root.get_children():
			var pm := child as MeshInstance3D
			var pb: AABB = pm.transform * pm.mesh.get_aabb()
			check(not Rect2(pb.position.x, pb.position.y, pb.size.x, pb.size.y).intersects(window_hole), "a bullet strike in a window at %s" % pb)
			check(pb.end.z < 0.01 and pb.position.z > 0.0, "a bullet strike lies flat on the face (%s)" % pb)
		pk.sink.root.free()
	# A strike is a hollow in the face's own material: its facets above its
	# middle face down into it and those below face up, and nowhere is it
	# lighter than the wall round it (no flake of another colour).
	var strike_kit := kit()
	BuildingWeathering.pocks(strike_kit, Vector2(0, 1.5), 0.01, 1, "plaster", face_tone, strike_kit.rng)
	check(strike_kit.sink.root.get_child_count() == 1, "one strike, one hollow")
	var hm := (strike_kit.sink.root.get_child(0) as MeshInstance3D).mesh as ArrayMesh
	var ha := hm.surface_get_arrays(0)
	var hv: PackedVector3Array = ha[Mesh.ARRAY_VERTEX]
	var hn: PackedVector3Array = ha[Mesh.ARRAY_NORMAL]
	var hc: PackedColorArray = ha[Mesh.ARRAY_COLOR]
	var mid := hm.get_aabb().get_center()
	var sloped := 0
	var inward := 0
	for t in range(0, hv.size(), 3):
		var fc := (hv[t] + hv[t + 1] + hv[t + 2]) / 3.0
		if absf(fc.y - mid.y) > 0.006:
			sloped += 1
			if signf(hn[t].y) == -signf(fc.y - mid.y):
				inward += 1
	check(sloped > 4 and inward >= sloped * 0.8, "a strike's facets face into it (%d of %d)" % [inward, sloped])
	var lightest := 0.0
	for hcol in hc:
		var u := Color(hcol.r * Mats.VC_K, hcol.g * Mats.VC_K, hcol.b * Mats.VC_K)
		if not Mats.per_material:
			u = u.linear_to_srgb()
		lightest = maxf(lightest, maxf(u.r - 0.9, maxf(u.g - 0.85, u.b - 0.8)))
	check(lightest <= 1.05 / 255.0 * Mats.VC_K, "a strike is no lighter than the wall (%.3f over)" % lightest)
	strike_kit.sink.root.free()
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
