extends Node

class PoseBounds extends SoldierViewBatch:
	func _make_atlas(base: int) -> void:
		var bounds := []
		for frame in 15:
			bounds.append((poses[base + frame] as ArrayMesh).get_aabb())
		super._make_atlas(base)
		var actual: AABB = (poses[base] as ArrayMesh).custom_aabb.grow(0.001)
		for pose: AABB in bounds:
			assert(actual.encloses(pose), "Atlas bounds must include every posture and walking frame")
		var early: DrawGroup = groups[Vector3i.ZERO]
		assert(is_equal_approx(early.model_radius, _mesh_radius(poses[base])), "An existing group must receive the full animation envelope")

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	for unit: String in Defs.UNITS:
		var world := World.new()
		var view := PoseBounds.new()
		view.world = world
		add_child(view)
		view.set_process(false)
		view.prepare(unit, int(Defs.UNITS[unit].team))
		while not view._warmup.is_empty():
			var pose: Array = view._warmup.pop_front()
			view._make_pose(pose[0], pose[1], pose[2], pose[3], pose[4])
			if pose[0] == 0:
				view._group_for(0, Vector2i.ZERO)
			await get_tree().process_frame
		assert(view._atlases.size() == 1 and view.poses.size() == 1)
		var early: SoldierViewBatch.DrawGroup = view.groups[Vector3i.ZERO]
		assert(early.mm.mesh == view.poses[0] and early.node.material_override == view._atlases[0], "Loading must replace an already displayed standing pose")
		world.simulation_client = SimulationClient.new()
		for i in 3:
			var soldier := Soldier.new()
			soldier.eid = i + 1
			soldier.utype = unit
			soldier.team = int(Defs.UNITS[unit].team)
			soldier.posture = i
			soldier.act = Soldier.Act.WALK
			soldier.life = Soldier.Life.DEAD if i == 2 else Soldier.Life.ALIVE
			soldier.view_lod = true
			world.soldiers.append(soldier)
		view._process(0.0)
		assert(view._active.size() == 1 and view._active[0].count == 3)
		var mm: MultiMesh = view._active[0].mm
		# The headless dummy renderer does not retain instance colors.
		if DisplayServer.get_name() != "headless":
			for i in 3:
				assert(roundi(mm.get_instance_color(i).a * 255.0) == i * 8 + i + 2)
		var buffer := mm.buffer
		for time in [0.125, 0.125, 2147483648.375]:
			world.time = time
			view._process(0.016)
			assert(view._active[0].last_used == 0.0 and view._age > 0.0, "Animation must leave batch construction idle")
			assert(mm.buffer == buffer, "Walking and pausing must not upload the army again")
			assert(view._atlases[0].get_shader_parameter("animation_frame") == posmod(int(time * 8.0), 4))
		world.simulation_client.free()
		for soldier: Soldier in world.soldiers:
			soldier.free()
		world.soldiers.clear()
		view.free()
		world.free()
		print("SOLDIER_POSES passed ", unit)
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
