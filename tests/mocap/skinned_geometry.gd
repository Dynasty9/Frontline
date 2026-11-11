extends "res://scripts/main.gd"

var frames := 0
var fixtures: Array[Node3D] = []

func _ready() -> void:
	super._ready()

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or world.time < 0.2: return
	frames += 1
	if frames == 1:
		var soldier: GDScript = load("res://scripts/game/soldier.gd")
		for kind in ["crewman", "mortar_gunner", "medic"]:
			var unit := world.spawn("soldier", {"utype": kind, "team": 0, "pos": world.cam.focus_pos}) as Node3D
			unit.debug_pose = [soldier.Post.STAND, soldier.Act.IDLE, soldier.Life.ALIVE, 0.0]
			if kind == "medic":
				unit.debug_pose = [soldier.Post.CROUCH, soldier.Act.HEAL, soldier.Life.ALIVE, 0.0]
			fixtures.append(unit)
	if frames < 3: return
	for unit in fixtures:
		if unit.model == null:
			if frames >= 90:
				push_error("The character fixture never obtained a detailed model")
				get_tree().quit(1)
			return
	var native := 0
	var procedural := 0
	for unit in world.soldiers:
		var model: Node3D = unit.model
		if model == null: continue
		if unit.utype == "mortar_gunner" and InfantryAssets.gameplay_model == InfantryAssets.SWAT:
			assert(model.skinned != null and model.tube.get_parent() is BoneAttachment3D, "The specialist carries his kit on the animated spine")
			unit.debug_pose = []
			var pit = world.spawn("structure", {"skind": "mortar_pit", "team": 0, "pos": unit.position, "built": true})
			unit.mounted = pit
			unit.position = pit.mount_pos()
			unit.act = Soldier.Act.LAUNCH
			for i in 6:
				unit._view_process(1.0 / 30.0)
			assert(model.crew and not model.tube.visible and not model.skinned.weapon.visible, "Only the fixed mortar shows while the gunner works")
			unit.mounted = null
			unit.position += Vector3.RIGHT * 2.0
			for i in 6:
				unit._view_process(1.0 / 30.0)
			assert(model.tube.visible and not model.crew, "Leaving the pit restores the personal kit")
			world.despawn(pit)
		if unit.utype == "medic" and unit.team == 0 and InfantryAssets.gameplay_model == InfantryAssets.SWAT:
			assert(model.skinned != null)
			for kit in [model.medical_band, model.medical_pack]:
				assert(kit.get_parent() is BoneAttachment3D and kit.is_visible_in_tree())
				assert(not kit.find_children("*", "MeshInstance3D", true, false).is_empty())
			assert(model.medical_band.get_parent().bone_idx == model.skinned.bones["LeftArm"])
			assert(model.medical_pack.get_parent().bone_idx == model.skinned.bones["Spine2"])
			var shoulder: Vector3 = model.skinned.joint("LeftArm").origin
			var elbow: Vector3 = model.skinned.joint("LeftForeArm").origin
			var centre: Vector3 = model.medical_band.to_global(Vector3.DOWN * 0.145)
			assert(centre.distance_to(shoulder + shoulder.direction_to(elbow) * 0.145) < 0.002, "The cuff must stay centred on the posed upper arm")
		if model.skinned == null:
			assert(not model.root.find_children("*", "MeshInstance3D", true, false).is_empty(), "Procedural soldier lost its geometry")
			procedural += 1
			continue
		native += 1
		if InfantryAssets.gameplay_model == InfantryAssets.SWAT:
			assert(model.skinned.model_asset == InfantryAssets.SWAT and model.rifle_driver != null, "Bundled riflemen use the SWAT animation driver without flags")
		assert(not model.root.visible)
		for mesh in model.root.find_children("*", "MeshInstance3D", true, false):
			assert(mesh.get_child_count() > 0, "Unused procedural leaf mesh survived cleanup")
		assert(not model.skinned.find_children("*", "MeshInstance3D", true, false).is_empty(), "Skinned geometry was removed")
		assert(is_instance_valid(model.skinned.weapon))
		if unit.utype == "medic":
			var visible_parts := 0
			for mesh in model.skinned.weapon.find_children("*", "MeshInstance3D", true, false):
				if mesh.visible and mesh.get_parent().visible:
					visible_parts += 1
			assert(model.skinned.magazine.mesh == null and visible_parts > 0)
		else:
			assert(is_instance_valid(model.skinned.magazine.mesh))
		for key in load("res://scripts/game/mocap_retarget.gd").MAP:
			assert(is_instance_valid(model.get(key)), "Procedural pose pivot was removed")
		for pivot in [model.gun, model.pistol, model.nade, model.stretcher]:
			assert(is_instance_valid(pivot), "Attachment pivot was removed")
	assert(procedural > 0)
	assert(native > 0 if not InfantryAssets.gameplay_model.is_empty() else native == 0)
	print("SKINNED GEOMETRY PASS skinned=", native, " procedural=", procedural, " pivots and attachments intact")
	get_tree().quit()
