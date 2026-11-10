extends SceneTree

func _initialize() -> void:
	call_deferred("pack")

func pack() -> void:
	var forms := Resource.new()
	forms.resource_name = "Surveyed Alpine ridge stamps"
	forms.set_meta("width", 512)
	for name in ["mont_blanc", "matterhorn", "jungfrau"]:
		var values := FileAccess.get_file_as_bytes("res://build/terrain/alpine-dem-source/" + name + ".r32").to_float32_array()
		assert(values.size() == 512 * 512)
		forms.set_meta(name, values)
	assert(ResourceSaver.save(forms, "res://assets/terrain/surveyed_alps.res", ResourceSaver.FLAG_COMPRESS) == OK)
	root.get_node("Sfx")._ensure()
	while root.get_node("Music")._task >= 0:
		await process_frame
	quit()
