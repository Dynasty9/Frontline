extends Node

var failures := 0

class TrackedWildlife extends Wildlife:
	var ticks := 0
	func _tick(_dt: float) -> void:
		ticks += 1


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	check_wildlife_threats()
	var world := World.new()
	world.srv = false
	world.has_view = false
	world.cam = RtsCamera.new()
	var wildlife := TrackedWildlife.new()
	wildlife.world = world
	wildlife.level = 1
	wildlife._process(0.016)
	check(wildlife.ticks == 0, "Wildlife must not read terrain while the loading worker replaces it")
	world.loaded = true
	wildlife._process(0.016)
	check(wildlife.ticks == 1, "Wildlife resumes on the completed battlefield")
	world.loaded = false
	world.cam.free()
	world.cam = null
	wildlife.free()
	world.terrain = TerrainMap.new(world)
	var batch := []
	for id in range(1, 19):
		batch.append([id, "soldier", {"utype": "rifleman", "team": 0, "owner": 2, "pos": Vector3.ZERO, "name": "Before"}])
	world._rpc_spawn(batch)
	world._rpc_join_end()
	world._load_step = 3
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
	check(world.entities.size() <= 17, "Loading must build only entities still present")
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


func check_wildlife_threats() -> void:
	var wildlife := Wildlife.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	for i in 500:
		wildlife._add_threat(Vector3(rng.randf_range(-180, 180), rng.randf_range(0, 60), rng.randf_range(-180, 180)), i % 3)
	check(wildlife._aircraft.size() == 166, "Only aircraft enter the soaring birds' threat list")
	for query in 300:
		var point := Vector3(rng.randf_range(-220, 220), 0, rng.randf_range(-220, 220))
		var man: float = [0.0, 4.5, 16.0, 22.0, 30.0][query % 5]
		var vehicle: float = [9.0, 12.0, 28.0, 45.0, 60.0][query % 5]
		var expected := -1
		var distance := INF
		for i in wildlife._threats.size():
			var other: Vector3 = wildlife._threats[i]
			var d := Vector2(point.x - other.x, point.z - other.z).length_squared()
			var radius := man if wildlife._big[i] == 0 else vehicle
			if d < radius * radius and d < distance:
				expected = i
				distance = d
		check(wildlife._threat(point, man, vehicle) == expected, "Indexed wildlife queries must match the nearest visible threat")
	wildlife.free()
	wildlife = Wildlife.new()
	wildlife._add_threat(Vector3(32, 0, -32), 0)
	wildlife._add_threat(Vector3(-32, 0, -32), 1)
	check(wildlife._threat(Vector3(0, 0, -32), 33, 33) == 0, "Equal-distance threats retain their scan order across cell boundaries")
	check(wildlife._threat(Vector3(0, 0, -32), 32, 32) == -1, "The fright radius stays exclusive")
	check(wildlife._threat(Vector3(0, 0, -32), 0, 33) == 1, "Fish ignore men while still noticing vehicles")
	var world := World.new()
	world.view_team = 0
	wildlife.world = world
	var soldier := Soldier.new()
	soldier.world = world
	soldier.team = 1
	soldier.vis_mask = 0
	world.soldiers.append(soldier)
	wildlife._scan()
	check(wildlife._threat(Vector3.ZERO, 10, 10) == -1 and wildlife._aircraft.is_empty(), "A fresh scan clears old threats and never reveals a hidden enemy")
	soldier.vis_mask = 1
	wildlife._scan()
	check(wildlife._threat(Vector3.ZERO, 10, 10) == 0, "Visible enemies can frighten wildlife")
	world.soldiers.clear()
	soldier.free()
	wildlife.free()
	world.free()
