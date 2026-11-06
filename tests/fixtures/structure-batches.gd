extends Node

func wall(w: World, id: int, at: Vector3) -> Structure:
	var st := Structure.new()
	st.world = w
	st.eid = id
	st.skind = "house_wall"
	st.built = true
	st.position = at
	w.add_child(st)
	st.model = Node3D.new()
	st.add_child(st.model)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = Mats.get_mat("concrete")
	st.model.add_child(mesh)
	return st

func _ready() -> void:
	var w := World.new()
	var view := StructureView.new()
	view.world = w
	w.structure_view = view
	w.add_child(view)
	var a := wall(w, 1, Vector3(2, 0, 3))
	var b := wall(w, 2, Vector3(5, 0, 3))
	var c := wall(w, 3, Vector3(70, 0, 3))
	for st in [a, b, c]:
		view._queue_draw_batch(st)
	view._build_draw_batch(Vector2i.ZERO)
	assert(view._draw_batches.size() == 1 and view._draw_members.size() == 2)
	assert(not a.model.get_child(0).visible and not b.model.get_child(0).visible)
	assert(c.model.get_child(0).visible, "Other cells retain their own models")
	var merged: MeshInstance3D = view._draw_batches[Vector2i.ZERO].node.get_child(0)
	var bounds := merged.mesh.get_aabb()
	assert(bounds.has_point(Vector3(2, 0, 3)) and bounds.has_point(Vector3(5, 0, 3)), "Merged geometry retains each structure's placement")
	var spans: Array = view._draw_members[a.eid].ranges.duplicate()
	a.apply_props({"pos": Vector3(3, 0, 3)})
	if DisplayServer.get_name() != "headless":
		for span: Array in spans:
			var vertices: PackedVector3Array = (span[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i in range(span[1], span[1] + span[2]):
				assert(vertices[i] == Vector3.ZERO, "Removed triangles must collapse, including their shadows")
			assert(vertices[vertices.size() - 1] != Vector3.ZERO, "Neighbouring geometry must remain intact")
	assert(view._draw_batches.size() == 1 and view._draw_members.size() == 1)
	assert(a.model.get_child(0).visible and not b.model.get_child(0).visible, "Changing one structure restores only its original meshes")
	view._queue_draw_batch(a)
	assert(not view._draw_waiting.has(Vector2i.ZERO), "Changed objects must not rebuild repeatedly during combat")
	view.remove(b)
	assert(a.model.get_child(0).visible and view._draw_members.is_empty(), "Despawn must not leave duplicate or dangling batch members")
	view._draw_broken.clear()
	a.burn = 0.5
	view._queue_draw_batch(a)
	assert(not view._draw_waiting.has(Vector2i.ZERO), "Burning structures keep their individual effects")
	view.remove(c)
	c.free()
	view._build_draw_batch(Vector2i(1, 0))
	assert(view._draw_batches.is_empty(), "A queued structure may despawn before its batch is built")
	var trees: Array[Structure] = []
	for id in [10, 11]:
		var tree := wall(w, id, Vector3(id * 2, 12, 20))
		tree.skind = "tree"
		tree.model.get_child(0).free()
		Structure.tree_model(tree.model, id, 0)
		trees.append(tree)
		view._queue_draw_batch(tree)
	view._build_draw_batch(Vector2i.ZERO)
	assert(view._draw_members.has(10) and view._draw_members.has(11), "Tree bark and foliage must share spatial batches")
	for tree in trees:
		for part in tree.model.get_children():
			assert(not part.visible, "Batched foliage must not draw twice")
	for part: MeshInstance3D in view._draw_batches[Vector2i.ZERO].node.get_children():
		if part.material_override.get_shader_parameter("leaf_cards") == true:
			var arrays: Array = part.mesh.surface_get_arrays(0)
			assert(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Leaf atlas coordinates survive spatial batching")
			assert((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).has(Vector2.ONE), "Merged cards retain the complete texture extent")
	view.unbatch(trees[0])
	assert(view._draw_members.has(11) and not view._draw_members.has(10), "Felling or burning one tree preserves its neighbour")
	for part in trees[0].model.get_children():
		assert(part.visible, "Changed trees regain individual foliage and bark")
	# Background forests cannot masquerade as cover inside the combat map.
	var atmosphere := Atmosphere.new()
	atmosphere.world = w
	w.terrain = TerrainMap.new(w)
	w.terrain.landform.peak = 100.0
	atmosphere.ground_mat = ShaderMaterial.new()
	atmosphere.ground_mat.shader = Shader.new()
	atmosphere.ground_mat.shader.code = "shader_type spatial; uniform float sea_x = 1000000000.0; uniform sampler2D forest_cover;"
	atmosphere.backdrop_tex = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RF))
	var forest := DistantForest.new()
	forest.setup(atmosphere)
	var repeat_cover := DistantForest.coverage_image(7919, MapDims.HALF + 1400.0)
	assert(forest.coverage.get_data() == repeat_cover.get_data(), "Forest floors and placement reproduce the map seed")
	assert(forest.coverage.get_pixel(128, 128).r == 0.0, "Scenery understory must not paint the playable map")
	assert(forest.coverage.get_data() != DistantForest.coverage_image(7919 * 2, MapDims.HALF + 1400.0).get_data(), "Different seeds grow different stands")
	assert(forest.tree_count > 10000 and forest.get_child_count() < 300, "Dense forests share bounded spatial draw batches")
	if DisplayServer.get_name() != "headless":
		for chunk: MultiMeshInstance3D in forest.get_children():
			for i in chunk.multimesh.instance_count:
				var position := chunk.position + chunk.multimesh.get_instance_transform(i).origin
				assert(maxf(absf(position.x), absf(position.z)) >= MapDims.HALF + 48.0)
	forest.free()
	atmosphere.free()
	w.free()
	print("STRUCTURE_BATCHES passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
