extends Node

class TransformProbe extends Node3D:
	var updates := 0
	func _ready() -> void:
		set_notify_transform(true)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			updates += 1

class TrackedSoldier extends Soldier:
	var frames := {}
	var elapsed := 0.0
	func _view_process(dt: float, _blend := -1.0) -> void:
		var frame := Engine.get_process_frames()
		assert(not frames.has(frame), "A registered soldier must update only once per frame")
		frames[frame] = true
		elapsed += dt

func _ready() -> void:
	check_detail_budget()
	check_detail_templates()
	await check_hidden_rigs()
	var world := World.new()
	var view := SoldierViewBatch.new()
	view.world = world
	add_child(view)
	view.set_process(false)
	view.prepare("rifleman", 0)
	view.prepare("rifleman", 0)
	assert(view._warmup.size() == 15)
	view.prepare("rifleman", 1)
	view.prepare("medic", 0)
	assert(view._warmup.size() == 45 and view._next_pose == 45)
	var first: int = view._types.rifleman[0]
	var enemy: int = view._types.rifleman[1]
	assert(first != enemy and enemy != int(view._types.medic[0]))
	view._warmup.clear()
	view.poses[first] = BoxMesh.new()
	view.poses[first + 5] = BoxMesh.new()
	view.poses[enemy] = BoxMesh.new()
	var a := Soldier.new()
	var b := Soldier.new()
	for s in [a, b]:
		s.utype = "rifleman"
		s.team = 0
		s.view_lod = true
		s.posture = Soldier.Post.STAND
		s.act = Soldier.Act.IDLE
		world.soldiers.append(s)
	a.position = Vector3(1, 0, 2)
	b.position = Vector3(2, 0, 3)
	view._process(0.0)
	var original := Vector3i(0, 0, first)
	assert(view.groups.size() == 1 and view.groups[original].count == 2)
	assert(view.groups[original].mm.visible_instance_count == 2)
	b.position.x = SoldierViewBatch.CELL + 1
	view._process(0.0)
	assert(view.groups[original].count == 1 and view.groups[Vector3i(1, 0, first)].count == 1)
	a.posture = Soldier.Post.CROUCH
	view._process(0.0)
	assert(view.groups[original].count == 0 and view.groups[Vector3i(0, 0, first + 5)].count == 1)
	assert(view.groups[original].mm.visible_instance_count == 0, "Previous poses must disappear before cache expiry")
	assert(view._active.size() == 2, "Only populated poses need per-frame updates")
	b.team = 1
	view._process(0.0)
	assert(view.groups[Vector3i(1, 0, enemy)].count == 1)
	a.visible = false
	b.gone = true
	world.time = 6.0
	view._process(0.0)
	assert(view.groups.is_empty(), "Hidden/dead batches must expire")
	world.soldiers.clear()
	a.free()
	b.free()
	view.free()
	world.free()
	world = World.new()
	view = SoldierViewBatch.new()
	view.world = world
	world.soldier_view = view
	add_child(view)
	var tracked := TrackedSoldier.new()
	tracked.world = world
	tracked.eid = 1
	world._register(tracked)
	add_child(tracked)
	view._warmup.clear()
	assert(not tracked.is_processing(), "The shared view loop replaces individual frame callbacks")
	for i in 4:
		await get_tree().process_frame
		assert(view.acquire_detail_slot(), "A new frame can construct one detailed soldier")
		assert(not view.acquire_detail_slot(), "Cold detailed models must be spread across frames")
	assert(tracked.frames.size() >= 2 and tracked.elapsed > 0.0)
	var updates := tracked.frames.size()
	tracked.gone = true
	for i in 2:
		await get_tree().process_frame
	assert(tracked.frames.size() == updates, "Despawned soldiers must stop receiving view updates")
	tracked.free()
	view.free()
	world.free()
	print("SOLDIER_BATCHES passed")
	get_tree().quit()


func check_detail_budget() -> void:
	var world := World.new()
	world.cam = RtsCamera.new()
	world.cam.dist = 18.0
	world.cam.cam = Camera3D.new()
	add_child(world.cam.cam)
	var view := SoldierViewBatch.new()
	view.world = world
	for i in SoldierViewBatch.MAX_DETAILED * 2:
		var soldier := Soldier.new()
		soldier.eid = i + 1
		soldier.position = Vector3(0, 0, -20 - i)
		world.soldiers.append(soldier)
	view._choose_detail(1.0)
	assert(view.detail_ids.size() == SoldierViewBatch.MAX_DETAILED)
	assert(view.detail_ids.has(1) and not view.detail_ids.has(world.soldiers.size()))
	world.soldiers.back().selected = true
	world.soldiers[0].visible = false
	world.soldiers[1].gone = true
	view._choose_detail(1.0)
	assert(view.detail_ids.size() == SoldierViewBatch.MAX_DETAILED)
	assert(view.detail_ids.has(world.soldiers.size()) and not view.detail_ids.has(1) and not view.detail_ids.has(2))
	world.cam.dist = 35.0
	view._choose_detail(1.0)
	assert(view.detail_ids.size() == SoldierViewBatch.COMMAND_DETAILED and view.detail_ids.has(world.soldiers.size()), "Command zoom keeps every troop but limits articulated models, with selection first")
	world.cam.dist = 18.0
	view._choose_detail(1.0)
	assert(view.detail_ids.size() == SoldierViewBatch.MAX_DETAILED, "Close inspection restores the larger detail budget")
	world.cam.cam.rotation.y = PI
	view._choose_detail(0.0)
	assert(view.detail_ids.is_empty(), "Camera turns must refresh the detailed-model budget immediately")
	for soldier: Soldier in world.soldiers:
		soldier.free()
	world.cam.cam.free()
	world.cam.free()
	view.free()
	world.free()


func check_detail_templates() -> void:
	var view := SoldierViewBatch.new()
	add_child(view)
	view.set_process(false)
	assert(view.make_detail("rifleman", 0, 71) == null, "Unprepared models retain the normal construction fallback")
	for unit: String in Defs.UNITS:
		for team in [0, 1]:
			view.prepare(unit, team)
			var base: int = view._types[unit][team]
			view._make_pose(base, unit, team, 0, 0)
			var template: SoldierModel = view.detail_templates[base]
			var a := view.make_detail(unit, team, 71)
			var b := view.make_detail(unit, team, 238)
			add_child(a)
			add_child(b)
			assert(a.visible and b.visible and not template.visible)
			assert(a.seedf != b.seedf and b.dvar == int(238 / 7) % 3)
			for property: Dictionary in template.get_property_list():
				if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
					continue
				var original: Variant = template.get(property.name)
				if original is Node3D:
					var joint: Node3D = a.get(property.name)
					assert(joint != original and a.is_ancestor_of(joint), "Copied joints must never drive the template or another soldier")
					assert(joint.transform == original.transform and joint.visible == original.visible)
			var rest := template.hips.transform
			a.pose(0.25, Soldier.Life.ALIVE, Soldier.Post.PRONE, Soldier.Act.CRAWL, 1.0, false, false)
			a.pose(0.25, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.LAUNCH, 0.0, false, true)
			assert(template.hips.transform == rest and b.hips.transform == rest)
			a.free()
			b.free()
	view.free()


func check_hidden_rigs() -> void:
	var world := World.new()
	world.view_team = 0
	world.cam = RtsCamera.new()
	world.cam.cam = Camera3D.new()
	add_child(world.cam.cam)
	world.soldier_view = SoldierViewBatch.new()
	var s := Soldier.new()
	s.world = world
	s.eid = 1
	s.team = 1
	s.vis_mask = 1
	s.position = Vector3(0, 0, -20)
	add_child(s)
	s.set_process(false)
	s.on_spawned()
	world.soldier_view.detail_ids[1] = true
	s._view_process(0.016)
	assert(s.model != null and s.model.visible and not s.model.top_level)
	var local := Transform3D(Basis(Vector3.UP, 0.2), Vector3(0.4, 0.2, -0.3))
	s.model.transform = local
	var probe := TransformProbe.new()
	s.model.hips.add_child(probe)
	await get_tree().process_frame
	world.soldier_view.detail_ids.clear()
	s._view_process(0.016)
	assert(s.view_lod and not s.model.visible and s.model.top_level)
	await get_tree().process_frame
	var updates := probe.updates
	s.net_pos = Vector3(3, 2, -24)
	s.net_yaw = 0.7
	for i in 3:
		s._view_process(0.016)
		await get_tree().process_frame
	assert(probe.updates == updates, "Moving a batched soldier must not update his hidden rig")
	assert(s.muzzle_world() == Vector3.INF, "A hidden cached weapon must not place visible shot effects")
	world.soldier_view.detail_ids[1] = true
	s._view_process(0.016)
	assert(not s.view_lod and s.model.visible and not s.model.top_level)
	assert(s.model.transform.is_equal_approx(local), "Restoring a cached rig preserves its local crew/interpolation offset")
	assert(s.model.global_transform.is_equal_approx(s.global_transform * local), "Restored detail must follow current position, elevation and facing")
	s.vis_mask = 0
	s._view_process(0.016)
	assert(not s.visible and not s.model.visible and s.model.top_level)
	s.vis_mask = 1
	s._view_process(0.016)
	assert(s.visible and s.model.visible and not s.model.top_level, "Fog reveal restores detail immediately")
	world.soldier_view.detail_ids.clear()
	s._view_process(0.016)
	s.position += Vector3(2, 0, 0)
	var phys := PhysicsFx.new(world)
	add_child(phys)
	phys.set_process(false)
	phys.set_physics_process(false)
	var ragdolls: bool = Settings.v.ragdolls
	Settings.v.ragdolls = true
	phys.ragdoll(s, Vector3.ZERO, 0)
	Settings.v.ragdolls = ragdolls
	assert(s.model.ragdoll != null and not s.model.top_level)
	assert(s.model.global_transform.is_equal_approx(s.global_transform * local), "Ragdolls start at the current soldier, not the cached rig location")
	s._view_process(0.016)
	assert(not s.model.top_level, "Live ragdoll joints retain their world transforms while hidden")
	s.model.ragdoll.finish()
	phys.free()
	s.free()
	world.soldier_view.free()
	world.cam.cam.free()
	world.cam.free()
	world.free()
