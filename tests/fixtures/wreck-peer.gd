extends SceneTree
## Two-process ENet check after actual vehicle destruction.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.building:
		await process_frame
	var world = game.world
	if game.args.has("wreck-host"):
		print("WRECK HOST ready")
		while world.ready_peers.is_empty():
			await process_frame
		for kind in ["tank", "slammer", "technical"]:
			var vehicle = world.spawn("vehicle", {"vkind": kind, "team": 0, "pos": Vector3(70 + ["tank", "slammer", "technical"].find(kind) * 30, 0, 70)})
			vehicle.brew_up_next = 1
			vehicle.take_damage(vehicle.max_hp * 3.0, null)
		print("WRECK HOST properties ", JSON.stringify(wrecks(world)))
		var end: float = world.time + 8.0
		while world.time < end:
			await process_frame
	else:
		while wrecks(world).size() < 3:
			await process_frame
		print("WRECK CLIENT properties ", JSON.stringify(wrecks(world)))
	quit()

func wrecks(world) -> Dictionary:
	var result := {}
	for st in world.structures:
		if st.skind == "wreck" and st.vk in ["tank", "slammer", "technical"] and not st.wreck_finish.is_empty():
			var props: Dictionary = st.get_props()
			result[st.vk] = {"wreck_finish": props.get("wreck_finish"), "turret_off": props.get("turret_off", false),
				"wreck_turret_yaw": props.get("wreck_turret_yaw"), "bent_skirts": props.get("bent_skirts")}
	return result
