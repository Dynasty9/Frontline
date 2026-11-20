extends SceneTree
## Generated shops, real entry orders and the normal roof reveal. Capture is optional.

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shop-review-output="):
			output = arg.get_slice("=", 1)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.time < 2.0:
		await process_frame
	var world = game.world
	var shop = null
	var barn_count := 0
	for floor in world.structures:
		if floor.skind != "floor" or floor.variant not in [2, 3]:
			continue
		var restored = load("res://scripts/game/structure.gd").new()
		restored.apply_props(floor.get_props())
		assert(restored.entry == floor.entry, "Furnished floor entrance survives the serialized props used by replay")
		restored.free()
		if floor.variant == 2:
			barn_count += 1
		for other in world.structures:
			assert(other.skind != "crates" or not floor._covers(other.position, 0.0), "Solid crates must not intersect fitted stock")
		# (an end-door shop when there is one; shops on a street have their
		# door in the shopfront, so most are entered from the front)
		if floor.variant == 3 and (shop == null or (floor.entry >= 2 and shop.entry < 2)):
			shop = floor
	if shop == null:
		print("SHOP_GAMEPLAY no shop in this seed")
		quit(1)
		return
	assert(barn_count > 0, "Seed must include the existing farm work")
	var door = null
	var roof = null
	for st in world.structures:
		if st.skind == "house_wall" and st.variant == 2 and shop._covers(st.position, 0.5):
			door = st
		if st.skind == "roof" and st.position.distance_to(shop.position) < 0.5:
			roof = st
	assert(door != null and roof != null)
	var outward: Vector3 = Basis(Vector3.UP, door.yaw) * Vector3.BACK
	var squad = world.rules.spawn_squad("rifle_squad", 0, 0, door.position + outward * 5.0)
	if world.has_view:
		world.cam.set_process(false)
		world.cam.edge_pan = false
		if world.director:
			world.director.active = false
		world.cam.dist = 27.0
		world.cam.target_dist = 27.0
		world.cam.pitch_deg = -55.0
		world.cam.yaw = door.yaw + 0.5
		world.cam.focus_pos = shop.position
		world.cam._apply()
		world.set_physics_process(false)
		for i in 30:
			await process_frame
		while world.structure_view != null and world.structure_view.warming():
			await process_frame
	if output != "":
		assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	world.set_physics_process(true)
	var revealed := false
	for frame in 450:
		if frame == 60:
			squad.order_move(door.position - outward * 2.0, -outward, 0)
		await process_frame
		if roof.model != null and not roof.model.visible:
			revealed = true
		if output != "" and frame % 3 == 0:
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output + "/%04d.png" % (frame / 3)) == OK)
	if world.has_view:
		assert(revealed, "The normal roof logic must reveal the squad entering the shop")
	var entered := false
	for man in squad.members:
		entered = entered or shop._covers(man.position, 0.0)
	assert(entered, "A squad member must enter through the generated shop door")
	print("SHOP_GAMEPLAY passed entry=", shop.entry, " floor=", shop.position, " barns=", barn_count, " roof_revealed=", revealed)
	if output != "":
		var file := FileAccess.open(output + "/capture.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"arguments": OS.get_cmdline_args(), "user_arguments": OS.get_cmdline_user_args(), "focus": str(shop.position), "entry": shop.entry, "roof_revealed": revealed, "barns": barn_count, "fps": 10, "simulation_hz": 30, "frames": 150, "renderer": RenderingServer.get_current_rendering_method()}, "\t"))
	quit()
