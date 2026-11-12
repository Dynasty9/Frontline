extends SceneTree

func _initialize() -> void:
	check_model_selection()
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
	assert(scenes == 263)
	assert(ResourceLoader.exists("res://assets/local_mocap/runtime/m4.scn"))
	print("INFANTRY PACK CHECK PASS 263 scenes, no raw sources or animation meshes")
	quit()


func check_model_selection() -> void:
	const Assets := preload("res://scripts/autoload/infantry_assets.gd")
	var installed := {}
	var exists := func(path: String) -> bool: return installed.has(path)
	for file: String in Assets.MIXAMO_CLIPS.values():
		installed[Assets.MIXAMO_BASE + file] = true
	installed[Assets.SWAT] = true
	assert(Assets.select_model([], exists) == "", "A partial installation must keep procedural geometry")
	installed[Assets.Rifle.SCENE] = true
	assert(Assets.select_model([], exists) == Assets.SWAT, "Complete SWAT installations require no flags")
	for file: String in Assets.CLIPS.values():
		installed[Assets.BASE + file] = true
	installed[Assets.MANNEQUIN] = true
	installed[Assets.SOLDIER] = true
	assert(Assets.select_model([], exists) == Assets.SWAT)
	assert(Assets.select_model(["--skinned-units"], exists) == Assets.SOLDIER)
	for flag in ["--swat", "--swat-units"]:
		assert(Assets.select_model(["--skinned-units", flag], exists) == Assets.SWAT)
	installed.erase(Assets.SWAT)
	assert(Assets.select_model([], exists) == Assets.SOLDIER)
	assert(Assets.select_model([], ResourceLoader.exists) == Assets.SWAT, "The mounted pack must supply the default model")
	var native_gl := OS.has_feature("macos") and RenderingServer.get_current_rendering_driver_name() == "opengl3"
	assert(root.get_node("InfantryAssets").gameplay_model == ("" if native_gl else Assets.SWAT))
