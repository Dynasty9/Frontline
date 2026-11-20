extends SceneTree
## Two-process ENet check: a trench dug and then shelled on the host changes
## depth on a client, which has no nav of its own (only the host paths soldiers).
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.world == null or game.world.building:
		await process_frame
	var world = game.world
	if game.args.has("trench-host"):
		print("TRENCH HOST ready")
		while world.ready_peers.is_empty():
			await process_frame
		var pos := Vector3(60, 0, 60)
		pos.y = world.ground_y(pos)
		var st = world.spawn("structure", {"skind": "trench", "pos": pos, "yaw": 0.0, "team": 0, "built": false, "progress": 0.0})
		# dig it in stages, each one sent, then shell it: every step reshapes the hole
		for i in 40:
			if st.built:
				break
			st.add_work(4.0)
			await _wait(world, 0.5)
		st.take_damage(st.max_hp * 0.5, null)
		await _wait(world, 0.5)
		print("TRENCH HOST depth %.3f built=%s" % [st.trench_depth(), st.built])
		await _wait(world, 6.0)
	else:
		var end: float = Time.get_ticks_msec() + 120000.0
		var st = null
		while Time.get_ticks_msec() < end and game.world == world:
			st = _trench(world)
			if st != null and st.built and st.hp < st.max_hp:
				break
			await process_frame
		if game.world == world:
			await _wait(world, 1.0)
		if st != null and game.world == world:
			print("TRENCH CLIENT depth %.3f built=%s nav=%s parts=%d" % [st.trench_depth(), st.built, world.nav != null, st.parts.size()])
	quit()

func _wait(world, seconds: float) -> void:
	var end: float = world.time + seconds
	while is_instance_valid(world) and world.time < end:
		await process_frame

func _trench(world):
	for st in world.structures:
		if st.skind == "trench" and not st.gone:
			return st
	return null
