extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var world := World.new()
	world.srv = true
	world.has_view = false
	for i in 5000:
		var st := Structure.new()
		st.world = world
		st.eid = i + 1
		st.skind = "tree"
		world._register(st)
		world.add_child(st)
	check(world._dirty_static.is_empty(), "Map generation must not queue a redundant full-map snapshot")
	world.ready_peers.append(2)
	var first := world._snapshot_entities()
	check(first.size() == 112, "Scenery refresh work must be spread over 45 snapshots")
	var changed: Structure = world.entity(4000)
	changed.net_dirty = true
	var next := world._snapshot_entities()
	check(changed in next and next.size() == 113, "A changed distant building must update immediately")
	check(world._dirty_static.is_empty() and not changed.net_dirty, "Delivered dirty entries must clear")
	var seen := {}
	for i in 45:
		for e: Entity in world._snapshot_entities():
			seen[e.eid] = true
	check(seen.size() == 5000, "Periodic refresh must eventually cover every static entity")
	changed.team = 1
	changed.skind = "fob"
	changed.supply = 777
	world.known[2] = {}
	world._unrevealed[2] = {changed.eid: changed}
	check(world._take_reveals(2, 0).is_empty(), "Unseen enemy buildings must stay private")
	changed.seen_mask = 1
	check(world._take_reveals(2, 0) == [changed] and world._unrevealed[2].is_empty(), "A newly spotted building must move into the known set once")
	for view in [0, 1]:
		var record := world._initial_spawn(changed, view)
		check(view == 1 or (not record[2].has("supply") and not record[2].has("queue")), "Initial properties must not disclose enemy stocks or production")
		var state := StreamPeerBuffer.new()
		state.data_array = record[3]
		state.seek(6)
		check(state.get_u16() == (777 if view == 1 else 0), "Reliable initial state must preserve supply privacy")
	var client := World.new()
	client.time = 120.0
	var snapshot := StreamPeerBuffer.new()
	snapshot.put_float(17.5)
	client._rpc_snap(snapshot.data_array)
	check(client.time == 17.5, "The server clock must replace client loading time and drift")
	snapshot.clear()
	snapshot.put_float(18.0)
	client._rpc_snap(snapshot.data_array)
	check(client.time == 18.0, "Later snapshots must continue synchronizing battle time")
	client._rpc_snap(PackedByteArray([0, 1]))
	check(client.time == 18.0, "A truncated header must not change the clock")
	for invalid in [NAN, INF, -1.0]:
		snapshot.clear()
		snapshot.put_float(invalid)
		client._rpc_snap(snapshot.data_array)
		check(client.time == 18.0, "Invalid snapshot clocks must be rejected")
	client._physics_process(1.0)
	check(is_equal_approx(client.time, 18.1), "The view may interpolate only briefly without a fresh snapshot")
	client._physics_process(1.0)
	check(is_equal_approx(client.time, 18.1), "A paused or disconnected host must not leave the client clock running")
	client.free()
	world.free()
	print("SNAPSHOT_INDEX_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
