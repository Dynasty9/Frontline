extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var world := World.new()
	world.has_view = false
	world.terrain = TerrainMap.new(world)
	var terrain := world.terrain
	for kind in ["tall_wall", "low_wall", "house_wall", "sandbags", "trench", "bunker", "rubble", "floor", "wire", "helipad"]:
		for yaw in [0.0, 0.37, PI * 0.5]:
			var st := Structure.new()
			st.world = world
			st.eid = 1
			st.skind = kind
			st.yaw = yaw
			st.size = Vector3(64, 2, 1) if kind.ends_with("wall") else Vector3.ONE
			world._register(st)
			world.add_child(st)
			st.on_spawned()
			world._shash_add(st)
			terrain.structure_changed(st, true)
			if kind == "tall_wall" and yaw == 0.0:
				check(terrain._queue.size() < 600, "A long wall must queue a strip, not its circumscribed square")
			terrain.tick(1 << 30)
			verify_reference(terrain, st)
			world._shash_remove(st)
			terrain.structure_changed(st, false)
			terrain.tick(1 << 30)
			verify_reference(terrain, st)
			world.structures.clear()
			world.sim_structures.clear()
			world.fob_structures.clear()
			world.entities.clear()
			st.free()
	world.free()
	print("TERRAIN_COVER_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func verify_reference(terrain: TerrainMap, st: Structure) -> void:
	var r := ceili(st.radius + 2.0)
	var mismatches := 0
	for z in range(-r, r + 1):
		for x in range(-r, r + 1):
			var i := terrain.idx_of(Vector3(x, 0, z))
			var before := [terrain.cov[i], terrain.cdir[i], terrain.solid[i], terrain.rubble[i], terrain.trench[i]]
			terrain._recompute_cell(i)
			if before != [terrain.cov[i], terrain.cdir[i], terrain.solid[i], terrain.rubble[i], terrain.trench[i]]:
				mismatches += 1
	check(mismatches == 0, "Bounded cover update differs from exhaustive region for %s at %.2f: %d cells" % [st.skind, st.yaw, mismatches])
