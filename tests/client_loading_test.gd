extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var world := World.new()
	world.srv = false
	world.has_view = false
	world.terrain = TerrainMap.new(world)
	var batch := []
	for id in range(1, 19):
		batch.append([id, "soldier", {"utype": "rifleman", "team": 0, "owner": 2, "pos": Vector3.ZERO, "name": "Before"}])
	world._rpc_spawn(batch)
	world._rpc_initial_received()
	check(world.entities.is_empty() and world.client_loading(), "Receiving spawn batches must not build every object immediately")
	world._rpc_props({1: {"name": "After", "owner": 3}})
	world._rpc_despawn([18])
	var source := Soldier.new()
	source.world = world
	source.position = Vector3(10, 0, 20)
	source.life = Soldier.Life.DEAD
	var state := StreamPeerBuffer.new()
	source.write_state(state)
	var packet := StreamPeerBuffer.new()
	packet.put_float(1.0)
	packet.put_u32(1)
	packet.put_u8(state.data_array.size())
	packet.put_data(state.data_array)
	world._rpc_snap(packet.data_array)
	world._process(0.016)
	check(world.entities.size() <= 16 and world.client_loading(), "One frame must respect the spawn work limit")
	for i in 20:
		world._process(0.016)
	check(world.entities.size() == 17 and not world.entities.has(18), "An entity despawned during loading must never appear")
	var soldier: Soldier = world.entity(1)
	check(soldier.sname == "After" and soldier.owner_peer == 3, "Property updates must survive delayed construction")
	check(soldier.life == Soldier.Life.DEAD and soldier.net_pos == source.position, "The latest snapshot must survive delayed construction")
	check(not world.client_loading(), "Loading must finish after the final batch is constructed")
	world._rpc_spawn([[19, "soldier", {"utype": "rifleman", "team": 0}, state.data_array]])
	check(not world.client_loading(), "Reinforcements must not restart the initial loading screen")
	world._process(0.016)
	check(world.entity(19).life == Soldier.Life.DEAD and world.entity(19).net_pos == source.position, "Reliable initial state must load without waiting for an unreliable snapshot")
	source.free()
	world.free()
	print("CLIENT_LOADING_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
