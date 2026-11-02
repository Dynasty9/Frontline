extends SceneTree
## Bake mesh and textures into one binary scene, then package for game builds.
const SOURCE := "res://assets/local_mocap/FBX/Animation/Rifle/M4/"
const OUTPUT := "res://assets/local_mocap/runtime/m4.scn"

func _initialize() -> void:
	var rifle := (load(SOURCE + "M4_Rifle_01.fbx") as PackedScene).instantiate()
	var baked := Node3D.new()
	baked.name = "M4"
	var material := StandardMaterial3D.new()
	material.roughness = 0.68
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.albedo_texture = _texture("M4DF2048.jpg")
	material.normal_enabled = true
	material.normal_texture = _texture("M4NM2048.jpg")
	material.ao_enabled = true
	material.ao_texture = _texture("M4AO2048.jpg")
	for original in rifle.find_children("*", "MeshInstance3D", true, false):
		var mesh := MeshInstance3D.new()
		mesh.name = original.name
		mesh.mesh = original.mesh.duplicate(true)
		mesh.mesh.resource_path = ""
		for surface in mesh.mesh.get_surface_count():
			mesh.mesh.surface_set_material(surface, null)
		mesh.material_override = material
		var transform: Transform3D = original.transform
		var parent: Node = original.get_parent()
		while parent != null:
			if parent is Node3D: transform = parent.transform * transform
			parent = parent.get_parent()
		mesh.transform = transform
		baked.add_child(mesh)
		mesh.owner = baked
	assert(baked.get_child_count() > 0, "Rifle has no geometry")
	var packed := PackedScene.new()
	assert(packed.pack(baked) == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	assert(ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(OUTPUT).is_empty(), "Baked rifle still references source assets")
	var restored := (load(OUTPUT) as PackedScene).instantiate()
	assert(restored.get_child_count() == baked.get_child_count())
	print("RIFLE PACK PASS: ", OUTPUT, " self-contained meshes=", restored.get_child_count())
	restored.free()
	baked.free()
	rifle.free()
	quit()

func _texture(filename: String) -> ImageTexture:
	var source := load(SOURCE + "M4_Rifle_01.fbm/" + filename) as Texture2D
	var image := source.get_image()
	if image.is_compressed(): assert(image.decompress() == OK)
	if not image.has_mipmaps(): assert(image.generate_mipmaps() == OK)
	return ImageTexture.create_from_image(image)
