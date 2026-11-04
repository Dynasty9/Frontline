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

func finish(view: StructureView, cell: Vector2i) -> void:
	for step in range(1000):
		if view._build_draw_batch(cell):
			return
	assert(false, "Progressive scenery batching must finish")

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
	view.center = Vector2i.ZERO
	assert(not view._build_draw_batch(Vector2i.ZERO))
	assert(a.model.get_child(0).visible and b.model.get_child(0).visible, "Original geometry stays visible while a block is collected")
	assert(view.warming(), "Loading must wait for an unfinished batch")
	finish(view, Vector2i.ZERO)
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
				assert(vertices[i] == Mats.HIDDEN_VERTEX, "Removed triangles and their shadows must leave the visible world")
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
	finish(view, Vector2i(1, 0))
	assert(view._draw_batches.is_empty(), "A queued structure may despawn before its batch is built")
	assert(not view.warming())
	var d := wall(w, 4, Vector3(132, 0, 3))
	var e := wall(w, 5, Vector3(135, 0, 3))
	var f := wall(w, 6, Vector3(138, 0, 3))
	var cell := Vector2i(2, 0)
	for st in [d, e]:
		view._queue_draw_batch(st)
	view._build_draw_batch(cell)
	d.apply_props({"pos": Vector3(133, 0, 3)})
	assert(view._draw_build == null and d.model.get_child(0).visible, "Changes during collection must discard stale geometry")
	view._build_draw_batch(cell)
	view._queue_draw_batch(f)
	finish(view, cell)
	assert(not view._draw_members.has(d.eid) and view._draw_members.has(e.eid) and view._draw_members.has(f.eid), "A new member must join without reusing a changed model")
	view.remove(e)
	view.remove(f)
	for st in [e, f]:
		view._queue_draw_batch(st)
	view._build_draw_batch(cell)
	view._build_draw_batch(cell)
	view._build_draw_batch(cell)
	assert(view._draw_build.holder != null and not view._draw_build.holder.visible)
	assert(e.model.get_child(0).visible and f.model.get_child(0).visible, "Partially uploaded geometry must not replace complete models")
	view.remove(e)
	e.free()
	finish(view, cell)
	assert(not view._draw_batches.has(cell) and f.model.get_child(0).visible, "Despawn during upload must cancel without hiding the surviving model")
	var trees: Array[Structure] = []
	for id in [10, 11]:
		var tree := wall(w, id, Vector3(id * 2, 12, 20))
		tree.skind = "tree"
		tree.model.get_child(0).free()
		Structure.tree_model(tree.model, id, 0)
		trees.append(tree)
		view._queue_draw_batch(tree)
	finish(view, Vector2i.ZERO)
	assert(view._draw_members.has(10) and view._draw_members.has(11), "Tree bark and foliage must share spatial batches")
	for tree in trees:
		for part in tree.model.get_children():
			assert(not part.visible, "Batched foliage must not draw twice")
	view.unbatch(trees[0])
	assert(view._draw_members.has(11) and not view._draw_members.has(10), "Felling or burning one tree preserves its neighbour")
	for part in trees[0].model.get_children():
		assert(part.visible, "Changed trees regain individual foliage and bark")
	w.free()
	print("STRUCTURE_BATCHES passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
