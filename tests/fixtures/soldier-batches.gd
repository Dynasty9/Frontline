extends Node

class TrackedSoldier extends Soldier:
	var frames := {}
	var elapsed := 0.0
	func _view_process(dt: float, _blend := -1.0) -> void:
		var frame := Engine.get_process_frames()
		assert(not frames.has(frame), "A registered soldier must update only once per frame")
		frames[frame] = true
		elapsed += dt

func _ready() -> void:
	for hz in [30, 60, 120]:
		check_body_motion(hz)
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

## A reversal should start under the old stride and turn across several frames.
func check_body_motion(hz: int) -> void:
	var s := Soldier.new()
	s.srv = true
	var dt := 1.0 / hz
	s._update_body(dt)
	for i in hz:
		s.position.x += 4.0 * dt
		s._update_body(dt)
	var before := (s.transform * s.body_offset).origin.x
	s.position.x -= 4.0 * dt
	s.rotation.y = PI
	s._update_body(dt)
	var drawn := s.transform * s.body_offset
	assert(drawn.origin.x > before, "the body finishes its outgoing step on a reversal")
	assert(absf(drawn.basis.get_euler().y) <= TAU * dt + 0.00001, "the model cannot snap through a half-turn")
	for i in hz:
		s._update_body(dt)
	assert((s.transform * s.body_offset).is_equal_approx(s.transform), "settles onto the exact resting pose")
	s.position += Vector3(8.0, -1.0, 4.0)
	s._update_body(dt)
	assert(s.body_offset.is_equal_approx(Transform3D.IDENTITY), "a spawn or teleport must not glide across the map")
	s.srv = false
	s.position.x += 0.2
	s._update_body(dt)
	assert(s.body_offset.origin.is_zero_approx(), "network interpolation already eases client positions")
	s.free()
