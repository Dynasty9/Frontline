extends Node3D
## Fit the shipped character to the RHIB's wheel and throttle. Store the pose in
## the infantry pack so every live launch can share the mesh without a skeleton.

const OUTPUT := "res://build/infantry-pack/rhib-helm.scn"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Baking the seated pose needs a graphical renderer")
		get_tree().quit(1)
		return
	var driver := SoldierModel.new()
	add_child(driver)
	driver.build("crewman", 0, 1)
	driver.gun.hide()
	driver.position.y = -SoldierModel.H0  # place the saved origin at the seat
	var actor := SkinnedRifleman.new()
	actor.model_asset = InfantryAssets.SWAT
	driver.add_child(actor)
	if not actor.build():
		get_tree().quit(1)
		return
	actor.solve_contacts = false
	actor.hold_weapon = false
	actor.bind_procedural(driver)
	driver.torso.rotation.x = -0.24
	driver.thigh_l.rotation.x = 1.15
	driver.thigh_r.rotation.x = 1.24
	driver.shin_l.rotation.x = -1.15
	driver.shin_r.rotation.x = -1.33
	driver.arm_l.rotation.x = 0.92
	driver.arm_r.rotation.x = 0.95
	driver.forearm_l.rotation.x = 0.83
	driver.forearm_r.rotation.x = 0.80
	actor.pose_procedural(driver, 1.0)
	driver.root.hide()
	actor.weapon.hide()
	# The rendering server receives the skeleton after the first draw. Baking
	# during initialization returns the outstretched bind pose instead.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var seat := Node3D.new()
	seat.name = "Coxswain"
	for original: MeshInstance3D in actor.visual.find_children("*", "MeshInstance3D", true, false):
		var body := MeshInstance3D.new()
		body.mesh = original.bake_mesh_from_current_skeleton_pose()
		if body.mesh == null or body.mesh.get_aabb().size.x > 1.1:
			push_error("The helmsman's arms did not reach the controls")
			body.free()
			seat.free()
			get_tree().quit(1)
			return
		for surface in body.mesh.get_surface_count():
			body.mesh.surface_set_material(surface, original.get_active_material(surface))
		body.transform = original.global_transform
		body.visibility_range_end = 120.0
		body.visibility_range_end_margin = 10.0
		seat.add_child(body)
		body.owner = seat
	var scene := PackedScene.new()
	var error := scene.pack(seat) if seat.get_child_count() > 0 else ERR_INVALID_DATA
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if error == OK:
		error = ResourceSaver.save(scene, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	seat.free()
	if error != OK:
		push_error("Could not bake the RHIB helmsman: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
