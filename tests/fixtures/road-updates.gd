extends Node

class Ground extends TerrainMap:
	var calls := []
	func paint_roads(polys: Array, half_w := 2.2) -> void:
		calls.append([polys.duplicate(), half_w])
		super.paint_roads(polys, half_w)

class RoadView extends Atmosphere:
	var calls := []
	func make_road_mesh(polys: Array, team: int) -> MeshInstance3D:
		calls.append([polys.duplicate(), team])
		return MeshInstance3D.new()

class ReferenceGround extends TerrainMap:
	func paint_roads(polys: Array, half_w := 2.2) -> void:
		# (a cell that's road already is passed over while the ground is fresh: see _fresh)
		var keep: bool = _fresh and not (world.nav and world.nav.hnav_i and world.nav.hnav_i.built)
		for poly in polys:
			var pts: PackedVector3Array = poly
			for k in range(pts.size() - 1):
				var a := pts[k]
				var b := pts[k + 1]
				var x0 := floori(minf(a.x, b.x) - half_w - 1.0 + H)
				var x1 := floori(maxf(a.x, b.x) + half_w + 1.0 + H)
				var z0 := floori(minf(a.z, b.z) - half_w - 1.0 + H)
				var z1 := floori(maxf(a.z, b.z) + half_w + 1.0 + H)
				# (Defs.dist_point_segment, worked through here for every cell)
				var sa := Vector3(a.x, 0, a.z)
				var ab := Vector3(b.x, 0, b.z) - sa
				var l2 := ab.length_squared()
				var dot := l2 >= 0.0001
				for z in range(maxi(0, z0), mini(N - 1, z1) + 1):
					var row := z * N
					for x in range(maxi(0, x0), mini(N - 1, x1) + 1):
						var was: int = base[row + x]
						if was >= WATER or (keep and was == ROAD):
							continue
						var c := Vector3(x - H + 0.5, 0, z - H + 0.5)
						var d := c.distance_to(sa + ab * clampf((c - sa).dot(ab) / l2, 0.0, 1.0)) if dot else c.distance_to(sa)
						if d <= half_w:
							base[row + x] = ROAD
							_refresh_cell(row + x)
		version += 1

func _ready() -> void:
	var w := World.new()
	w.has_view = false
	var ground := Ground.new(w)
	w.terrain = ground
	var first := PackedVector3Array([Vector3(-20, 0, 0), Vector3(20, 0, 0)])
	var town := PackedVector3Array([Vector3(-20, 0, 10), Vector3(20, 0, 10)])
	w.roads = [[first], [], [town]]
	w._rebuild_roads()
	assert(ground.calls.size() == 2 and ground.calls[0][1] == 1.8 and ground.calls[1][1] == 2.4)
	ground.calls.clear()
	w._rebuild_roads()
	assert(ground.calls.is_empty(), "An unchanged network must not repaint roads")
	var added := PackedVector3Array([Vector3(0, 0, 30), Vector3(20, 0, 30)])
	w.roads[0].append(added)
	w._rebuild_roads()
	assert(ground.calls.size() == 1 and ground.calls[0][0] == [added], "A new supply route must not repaint existing town streets")
	assert(ground.base[ground.idx_of(Vector3(10, 0, 30))] == TerrainMap.ROAD)
	ground.calls.clear()
	var moved := PackedVector3Array([Vector3(0, 0, 40), Vector3(20, 0, 40)])
	w.roads[0][1] = moved
	w._rebuild_roads()
	assert(ground.calls.size() == 1 and ground.calls[0][0] == [moved], "Same-length route geometry changes must be painted")
	assert(ground.base[ground.idx_of(Vector3(10, 0, 40))] == TerrainMap.ROAD)
	ground.calls.clear()
	w.roads[0].erase(first)
	w._rebuild_roads()
	assert(ground.calls.is_empty(), "Removing a route retains existing terrain roads without repainting")
	assert(ground.base[ground.idx_of(Vector3.ZERO)] == TerrainMap.ROAD)
	check_raster(w)
	check_verges(w)
	w.has_view = true
	var view := RoadView.new()
	w.atmo = view
	w.add_child(view)
	w._rebuild_roads()
	assert(view.calls.size() == 2, "The view must build even if terrain was painted before it existed")
	var town_mesh: MeshInstance3D = w._road_meshes[2]
	w._rebuild_roads()
	assert(view.calls.size() == 2, "Unchanged roads must retain their mesh")
	w.roads[0].append(first)
	w._rebuild_roads()
	assert(view.calls.size() == 3 and w._road_meshes[2] == town_mesh, "Only the changed team's road mesh is rebuilt")
	w.roads[0].clear()
	w._rebuild_roads()
	assert(w._road_meshes[0] == null and w._road_meshes[2] == town_mesh)
	w.free()
	print("ROAD_UPDATES passed")
	get_tree().quit()


func check_verges(w: World) -> void:
	w.water = WaterMap.new(w)
	var view := Atmosphere.new()
	view.world = w
	w.water.bridges = [[Vector3(-10, 0, 0), Vector3(10, 0, 0), 3.9, "bridge"]]
	assert(view._road_deck_distance(Vector3.ZERO) < 0.0, "Gravel must not cover bridge paving")
	assert(is_zero_approx(view._road_deck_distance(Vector3(10, 0, 0))), "The road meets the exact end of the deck")
	assert(view._road_deck_distance(Vector3(11, 0, 0)) > 0.0 and view._road_deck_distance(Vector3(0, 0, 4)) > 0.0, "Roads outside the deck remain visible")
	view.road_mat = ShaderMaterial.new()
	for team in [0, 2]:
		var mesh := view.make_road_mesh([PackedVector3Array([Vector3.ZERO, Vector3(40, 0, 0)])], team)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var deck_distances: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		assert(deck_distances.size() == vertices.size(), "Every road vertex carries the bridge clipping boundary")
		assert(deck_distances[18].x < 0.0 and deck_distances[deck_distances.size() - 1].x > 0.0, "The mesh distinguishes the deck from its approach")
		assert(vertices.size() == 960, "Road panels follow terrain along and across the carriageway")
		assert(uvs[0].x < 0.0 and uvs[uvs.size() - 2].x > 1.0, "Shoulders extend beyond the original driving surface")
		assert(is_equal_approx(mesh.mesh.get_aabb().size.z, 8.8 if team == 2 else 7.8))
		mesh.free()
	view.free()
	w.water.bridges.clear()
	w.roads[2] = [PackedVector3Array([Vector3(-100, 0, 0), Vector3(100, 0, 0)]),
		PackedVector3Array([Vector3(0, 0, -100), Vector3(0, 0, 100)])]
	var mg := MapGen.new(w)
	var town := TownGen.new(mg)
	town.rect = Rect2(-10, -10, 20, 20)
	var state := mg.rng.state
	town._road_verges()
	assert(town.decor.size() > 0)
	var first := town.decor.duplicate(true)
	for item in first:
		assert(town._road_dist(item[1]) >= 3.4, "Markers stay off intersecting roads")
		assert(not town.rect.grow(8).has_point(Vector2(item[1].x, item[1].z)), "No country markers on town pavements")
	town.decor.clear()
	town._road_verges()
	assert(town.decor == first and mg.rng.state == state, "Dressing repeats without changing gameplay randomness")
	var blocked: Vector3 = first[0][1]
	mg._place([Vector2(blocked.x, blocked.z), Vector2(3, 3), 0.0])
	town.decor.clear()
	town._road_verges()
	for item in town.decor:
		assert(item[1].distance_to(blocked) > 3.0, "Dressing avoids occupied building lots")
	w.water.rivers = [{"pts": PackedVector3Array([Vector3(-110, 0, 0), Vector3(110, 0, 0)]), "w": 14.0}]
	town.decor.clear()
	town._road_verges()
	for item in town.decor:
		assert(not w.water.wet_at(item[1]), "No roadside furniture in water")
	w.water.rivers.clear()

func check_raster(w: World) -> void:
	var fast := TerrainMap.new(w)
	var reference := ReferenceGround.new(w)
	for i in range(0, fast.base.size(), 13):
		fast.base[i] = TerrainMap.WATER
		reference.base[i] = TerrainMap.WATER
	var rng := RandomNumberGenerator.new()
	rng.seed = 917
	var segments := [
		PackedVector3Array([Vector3(-600, 0, -600), Vector3(600, 0, 600)]),
		PackedVector3Array([Vector3(500, 0, -500), Vector3(-500, 0, 500)]),
		PackedVector3Array([Vector3(-60, 0, 0.5), Vector3(60, 0, 0.5)]),
		PackedVector3Array([Vector3(0.5, 0, -60), Vector3(0.5, 0, 60)]),
		PackedVector3Array([Vector3.ZERO, Vector3.ZERO]),
	]
	for i in 40:
		segments.append(PackedVector3Array([
			Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80)),
			Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80)),
		]))
	for fresh in [true, false]:
		fast._fresh = fresh
		reference._fresh = fresh
		for segment in segments:
			var width := rng.randf_range(0.1, 4.0)
			fast.paint_roads([segment], width)
			reference.paint_roads([segment], width)
			assert(fast.base == reference.base, "Road strip must match exhaustive cell-distance rasterization")
			assert(fast.cov == reference.cov and fast.cdir == reference.cdir, "Cover semantics must stay identical")
