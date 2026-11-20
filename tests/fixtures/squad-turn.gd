extends "res://scripts/main.gd"

func _process(dt: float) -> void:
	super._process(dt)
	if not world or not world.rules or world.time < 0.05:
		return
	set_process(false)
	var start := Vector3(-310, 0, 47)
	var squad = world.rules.spawn_squad("rifle_squad", 0, 1, start)
	var leader = squad.get_leader()
	var followers: Array = squad.members.duplicate()
	followers.erase(leader)
	leader.position = start
	leader._last_dir = Vector3.FORWARD
	for i in followers.size():
		followers[i].position = start + Vector3((1.5 - i) * 2.0, 0.0, 0.0)
	squad.order_move(start + Vector3.BACK * 45.0, Vector3.BACK, 1, false)
	assert(squad.travel and leader._path_pending)
	# On a reversal the new path is still queued when the followers receive their first order.
	var available := []
	for m in followers:
		assert(m.hold_pos.z < start.z, "followers must line up behind the new heading")
		available.append(m.hold_pos)
	for m in followers:
		for place: Vector3 in available:
			assert(m.position.distance_to(m.hold_pos) <= m.position.distance_to(place) + 0.001, "each follower takes the closest available place")
		available.erase(m.hold_pos)
	# Once a waypoint is available, the group takes its direction from that segment.
	leader.path = PackedVector3Array([start + Vector3.RIGHT * 12.0])
	leader.path_i = 0
	leader._path_pending = false
	squad._follow_tick()
	for m in followers:
		assert(m.hold_pos.x < start.x, "followers must turn with the planned corner")
	print("SQUAD_TURN passed")
	get_tree().quit()
