extends Node

func _ready() -> void:
	var grass := Grass.new()
	var meshes := [grass._make_clump(), grass._make_bush(), grass._make_stone()]
	for index in meshes.size():
		var mesh: ArrayMesh = meshes[index]
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert(not indices.is_empty() and vertices.size() < indices.size(), "Shared vertices must not duplicate every triangle corner")
		for vertex in indices:
			assert(vertex >= 0 and vertex < vertices.size())
		var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		var lods: Array = surface.get("lods", [])
		if index == 0:
			assert(indices.size() == 270, "Grass blades retain all original triangles")
			assert(lods.is_empty(), "Thin, wind-bent grass blades must not be simplified")
		else:
			assert(not lods.is_empty(), "Bushes and stones must offer smaller distant meshes")
			var previous := int(surface.index_count)
			var previous_error := 0.0
			for lod: Dictionary in lods:
				var count: int = lod.index_data.size()
				assert(count < previous * (2 if vertices.size() < 65536 else 4))
				assert(float(lod.edge_length) >= previous_error)
				previous = count / (2 if vertices.size() < 65536 else 4)
				previous_error = float(lod.edge_length)
		print("GROUND_COVER mesh=%d vertices=%d indices=%d lods=%d" % [index, vertices.size(), indices.size(), lods.size()])
	grass.free()
	print("GROUND_COVER_LOD passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
