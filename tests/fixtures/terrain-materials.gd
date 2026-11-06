extends Node

func _ready() -> void:
	var arrays := Atmosphere.terrain_materials()
	assert(arrays.size() == 2)
	assert(arrays[0] == Atmosphere.terrain_materials()[0], "Map reloads must reuse the material allocation")
	for channel in 2:
		var array := arrays[channel]
		assert(array.get_layers() == 5 and array.get_width() == 1024 and array.get_height() == 1024)
		assert(array.has_mipmaps() and array.get_format() == Image.FORMAT_RGBA8, "All packed channels and distant filtering must survive import")
		for layer in Atmosphere.TERRAIN_MATERIALS.size():
			var name: String = Atmosphere.TERRAIN_MATERIALS[layer]
			var suffix := "color_height" if channel == 0 else "surface"
			var path := "res://assets/terrain/%s_%s.png" % [name, suffix]
			var original := Image.new()
			assert(original.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
			var texture: Texture2D = load(path)
			var imported := texture.get_image()
			for p in [Vector2i(9, 23), Vector2i(511, 800), Vector2i(901, 107)]:
				assert(original.get_pixelv(p) == imported.get_pixelv(p), "Import must not repair alpha: it contains height or roughness")
			if DisplayServer.get_name() != "headless":
				assert(array.get_layer_data(layer).get_data() == imported.get_data(), "Array layers must preserve the packed channels and mip levels")
	print("TERRAIN_MATERIALS passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
