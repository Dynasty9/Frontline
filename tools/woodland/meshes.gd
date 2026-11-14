extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var repo := ProjectSettings.globalize_path(get_script().resource_path).get_base_dir().get_base_dir().get_base_dir()
	var files: Array = JSON.parse_string(FileAccess.get_file_as_string(repo.path_join("build/woodland/meshes/manifest.json")))
	var meshes := {}
	for file: String in files:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(repo.path_join("build/woodland/meshes/" + file), state) == OK)
		var scene := doc.generate_scene(state)
		root.add_child(scene)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in scene.find_children("*", "MeshInstance3D"):
			var instance := child as MeshInstance3D
			for index in instance.mesh.get_surface_count():
				surface.append_from(instance.mesh, index, instance.global_transform)
		surface.generate_tangents()
		surface.index()
		var mesh := surface.commit()
		assert(mesh != null and mesh.get_aabb().size.y > 0.01)
		meshes[file.get_basename()] = mesh
		scene.free()
	for name: String in meshes:
		var mesh: ArrayMesh = meshes[name]
		if name == "shrub_02-0":
			# The established meadow shrub shader raises its mesh origin by 65 cm.
			var shifted := SurfaceTool.new()
			shifted.begin(Mesh.PRIMITIVE_TRIANGLES)
			shifted.append_from(mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.65, 0)))
			shifted.index()
			mesh = shifted.commit()
		if name.begins_with("tree_small_02-") or name.begins_with("pine_sapling_small-") or name.begins_with("fir_tree_01-"):
			var family := name.get_slice("-", 0) + "-" + name.get_slice("-", 1)
			var trunk: ArrayMesh = meshes[family + "-trunk"]
			var vertices: PackedVector3Array = trunk.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var bottom := trunk.get_aabb().position.y
			var anchor := Vector3.ZERO
			var count := 0
			for vertex in vertices:
				if vertex.y < bottom + 0.15:
					anchor += vertex
					count += 1
			assert(count > 0)
			anchor /= float(count)
			anchor.y = bottom
			# Every part shares the trunk's foot, regardless of asymmetric canopy bounds.
			var centered := SurfaceTool.new()
			centered.begin(Mesh.PRIMITIVE_TRIANGLES)
			centered.append_from(mesh, 0, Transform3D(Basis.IDENTITY, -anchor))
			centered.index()
			mesh = centered.commit()
		var imported := ImporterMesh.new()
		imported.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
		imported.generate_lods(60.0, 0.0, [])
		mesh = imported.get_mesh()
		assert(ResourceSaver.save(mesh, repo.path_join("assets/foliage/woodland/" + name + ".res"), ResourceSaver.FLAG_COMPRESS) == OK)
		print("WOODLAND_BAKE ", name, " bounds=", mesh.get_aabb(), " lods=", imported.get_surface_lod_count(0))
	quit()
