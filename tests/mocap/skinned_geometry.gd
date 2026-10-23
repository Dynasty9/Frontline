extends "res://scripts/main.gd"

var frames := 0

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or world.time < 0.2: return
	frames += 1
	if frames < 3: return
	var native := 0
	var procedural := 0
	for unit in world.soldiers:
		var model: SoldierModel = unit.model
		if model == null: continue
		if model.skinned == null:
			assert(not model.root.find_children("*", "MeshInstance3D", true, false).is_empty(), "Procedural soldier lost its geometry")
			procedural += 1
			continue
		native += 1
		assert(not model.root.visible)
		for mesh in model.root.find_children("*", "MeshInstance3D", true, false):
			assert(mesh.get_child_count() > 0, "Unused procedural leaf mesh survived cleanup")
		assert(not model.skinned.find_children("*", "MeshInstance3D", true, false).is_empty(), "Skinned geometry was removed")
		assert(is_instance_valid(model.skinned.weapon) and is_instance_valid(model.skinned.magazine.mesh))
		for key in MocapRetarget.MAP:
			assert(is_instance_valid(model.get(key)), "Procedural pose pivot was removed")
		for pivot in [model.gun, model.pistol, model.nade, model.stretcher]:
			assert(is_instance_valid(pivot), "Attachment pivot was removed")
	assert(procedural > 0)
	assert(native > 0 if "--skinned-units" in OS.get_cmdline_user_args() else native == 0)
	print("SKINNED GEOMETRY PASS skinned=", native, " procedural=", procedural, " pivots and attachments intact")
	get_tree().quit()
