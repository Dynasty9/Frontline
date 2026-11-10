extends SceneTree

func _initialize() -> void:
	var archive := ZIPReader.new()
	assert(archive.open("res://assets/infantry/infantry.zip") == OK)
	var scenes := 0
	for path in archive.get_files():
		assert(not path.ends_with(".fbx") and not path.ends_with(".png") and not path.ends_with(".jpg"), "Raw source in runtime pack")
		assert(not path.contains("/FBX/"), "Legacy MoCap source in runtime pack")
		if not path.ends_with(".fbx.remap"): continue
		var resource: PackedScene = load("res://" + path.trim_suffix(".remap"))
		assert(resource != null, "Missing packed scene: " + path)
		var instance := resource.instantiate()
		assert(not instance.find_children("*", "Skeleton3D", true, false).is_empty())
		if not path.ends_with("/Swat.fbx.remap"):
			assert(instance.find_children("*", "MeshInstance3D", true, false).is_empty())
			assert(not instance.find_children("*", "AnimationPlayer", true, false).is_empty())
		instance.free()
		scenes += 1
	assert(scenes == 252)
	assert(ResourceLoader.exists("res://assets/local_mocap/runtime/m4.scn"))
	print("INFANTRY PACK CHECK PASS 252 scenes, no raw sources or animation meshes")
	quit()
