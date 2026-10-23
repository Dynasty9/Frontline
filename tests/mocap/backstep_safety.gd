extends Node3D
var man: Soldier
func _ready() -> void:
	man = Soldier.new()
	add_child(man)
	man.set_process(false)
	_wall(Vector3(0, 1.25, -0.85))
	var rear := _wall(Vector3(0, 1.25, 0.6))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for frame in 60:
		assert(not man._prepare_prone(1.0 / 60.0))
		man._prone_check_t = 0.0
	assert(man.position == Vector3.ZERO and man._prone_back_goal == Vector3.INF, "Backstep entered an obstructed retreat path")
	rear.position.x = 8.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pending_cover := World.new()
	man.world = pending_cover
	pending_cover.time = 1.0
	man.next_cover_eval = 0.0
	assert(not man._prepare_prone(1.0 / 60.0))
	assert(man._prone_back_goal == Vector3.INF, "Backstep interrupted cover acquisition")
	man.world = null
	pending_cover.free()
	man.at_cover = true
	man.cover_n = Vector3.FORWARD
	man.cover_h = 1.0
	for frame in 30:
		man._prepare_prone(1.0 / 60.0)
		man._prone_check_t = 0.0
	assert(man.position.z > 0.0 and man._prone_back_goal != Vector3.INF, "Open retreat did not begin")
	assert(man.at_cover and man.cover_n == Vector3.FORWARD and man.cover_h == 1.0 and man.cover_pos == man._prone_back_goal, "Backstep discarded the protective barrier")
	man._clear_task()
	assert(man._prone_back_goal == Vector3.INF and man._prone_back_speed == 0.0 and man._prone_settle == 0.0, "New order retained the old maneuver")
	man._prone_retry = 0.0
	man._prepare_prone(1.0 / 60.0)
	assert(man._prone_back_goal != Vector3.INF)
	rear.position = Vector3(0, 1.25, man.position.z + 0.45)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stopped := man.position
	assert(not man._prepare_prone(1.0 / 60.0))
	assert(man.position == stopped and man._prone_back_goal == Vector3.INF, "New obstacle failed to cancel the retreat")
	print("BACKSTEP SAFETY PASS blocked path, cover acquisition/protection, order cancellation and new obstacle")
	get_tree().quit()
func _wall(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Defs.L_COVER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 2.5, 0.2)
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)
	return body
