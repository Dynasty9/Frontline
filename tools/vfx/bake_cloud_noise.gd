extends SceneTree
## godot --rendering-method gl_compatibility --position -10000,-10000 --path . --script tools/vfx/bake_cloud_noise.gd


func _initialize() -> void:
	call_deferred("bake")


func bake() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Cloud texture baking needs a renderer; use the off-screen command above.")
		quit(1)
		return
	var noise := FastNoiseLite.new()
	noise.seed = 1907
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var slices := noise.get_seamless_image_3d(64, 64, 64)
	assert(slices.size() == 64)
	for slice in slices:
		slice.convert(Image.FORMAT_R8)
	var texture := ImageTexture3D.new()
	assert(texture.create(Image.FORMAT_R8, 64, 64, 64, false, slices) == OK)
	assert(texture.get_data().size() == 64)
	assert(ResourceSaver.save(texture, "res://assets/sky/cloud_noise.res", ResourceSaver.FLAG_COMPRESS) == OK)
	print("CLOUD NOISE baked: 64 cubed, R8")
	quit()
