extends SceneTree
## Compile the locally licensed inputs into Frontline's runtime-only asset pack.
const OUTPUT := "res://assets/infantry/infantry.zip"
var pack := ZIPPacker.new()
var added := {}
var scenes := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/infantry"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/infantry-pack"))
	assert(pack.open(ProjectSettings.globalize_path(OUTPUT)) == OK)
	_collect("res://assets/local_mocap/mixamo")
	_add("res://assets/local_mocap/runtime/m4.scn")
	assert(scenes > 250, "Missing imported character/animation inputs")
	assert(pack.close() == OK)
	print("INFANTRY PACK PASS scenes=%d resources=%d bytes=%d" % [scenes, added.size(), FileAccess.get_file_as_bytes(OUTPUT).size()])
	quit()

func _collect(folder: String) -> void:
	for child in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child))
	for file in DirAccess.get_files_at(folder):
		if not file.to_lower().ends_with(".fbx"): continue
		var source := folder.path_join(file)
		_add(source)
		scenes += 1

func _add(path: String) -> void:
	if added.has(path): return
	assert(FileAccess.file_exists(path), "Missing compiled dependency: " + path)
	added[path] = true
	if FileAccess.file_exists(path + ".import"):
		var config := ConfigFile.new()
		assert(config.load(path + ".import") == OK)
		var compiled: String = config.get_value("remap", "path")
		if path.ends_with(".fbx") and not path.ends_with("/Swat.fbx"):
			var scene: Node = load(path).instantiate()
			for mesh in scene.find_children("*", "MeshInstance3D", true, false): mesh.free()
			var stripped := PackedScene.new()
			assert(stripped.pack(scene) == OK)
			var baked := "res://build/infantry-pack/%d.scn" % added.size()
			assert(ResourceSaver.save(stripped, baked, ResourceSaver.FLAG_COMPRESS) == OK)
			assert(_write(compiled, baked) == OK)
			added[compiled] = true
			scene.free()
		var remap := ConfigFile.new()
		remap.set_value("remap", "path", compiled + ".res" if compiled.ends_with(".ctex") else compiled)
		var temporary := "res://build/infantry-pack/%d.remap" % added.size()
		assert(remap.save(temporary) == OK)
		assert(_write(path + ".remap", temporary) == OK)
		_add(compiled)
		return
	assert(path.ends_with(".scn") or path.ends_with(".ctex"), "Unexpected runtime resource: " + path)
	if path.ends_with(".ctex"):
		var texture: Texture2D = load(path)
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		if maxi(image.get_width(), image.get_height()) > 2048:
			var scale := 2048.0 / maxi(image.get_width(), image.get_height())
			image.resize(roundi(image.get_width() * scale), roundi(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		var baked := "res://build/infantry-pack/%d.res" % added.size()
		assert(ResourceSaver.save(ImageTexture.create_from_image(image), baked, ResourceSaver.FLAG_COMPRESS) == OK)
		assert(_write(path + ".res", baked) == OK)
		return
	assert(_write(path, path) == OK)
	for dependency in ResourceLoader.get_dependencies(path):
		_add(dependency.get_slice("::", dependency.get_slice_count("::") - 1))


func _write(path: String, source: String) -> Error:
	var error := pack.start_file(path.trim_prefix("res://"))
	if error != OK: return error
	error = pack.write_file(FileAccess.get_file_as_bytes(source))
	if error != OK: return error
	return pack.close_file()
