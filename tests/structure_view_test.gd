extends Node

class ViewStub extends Structure:
	var builds := 0
	func set_view_active(value: bool) -> void:
		view_active = value
		if value:
			builds += 1

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var world := World.new()
	var view := StructureView.new()
	view.world = world
	view.focus_at(Vector3.ZERO)
	var near := ViewStub.new()
	near.eid = 1
	near.view_active = false
	var far := ViewStub.new()
	far.eid = 2
	far.position = Vector3(1400, 0, 0)
	far.view_active = false
	view.add(near)
	view.add(far)
	check(view.warming() and view.pending.size() == 1, "Only nearby scenery should delay initial loading")
	view._process(0.016)
	check(near.builds == 1 and far.builds == 0 and not view.warming(), "Distant scenery must remain unbuilt")
	view.focus_at(far.position)
	view._process(0.016)
	check(not near.view_active and far.view_active, "Moving across the map must switch active scenery")
	view.focus_at(Vector3.ZERO)
	view.remove(near)
	near.free()
	view._process(0.016)
	check(view.pending.is_empty() and not view.resident.has(1), "Despawn during queued construction must leave no stale reference")
	far.position = Vector3.ZERO
	view.remove(far)
	check(view.cells.is_empty() and view.memberships.is_empty(), "Removing a moved structure must clear its original spatial membership")
	far.free()
	var cached: Array[ViewStub] = []
	for i in 6:
		var st := ViewStub.new()
		st.eid = i + 10
		st.view_active = false
		st.model = Node3D.new()
		st.add_child(st.model)
		cached.append(st)
		view.add(st)
	view._process(0.016)
	for st in cached:
		check(st.view_active, "Showing cached scenery must not consume the new-model construction limit")
		view.remove(st)
		st.free()
	view.free()
	world.has_view = true
	var actual := Structure.new()
	actual.world = world
	actual.skind = "tall_wall"
	actual.built = false
	actual.defer_view = true
	world.add_child(actual)
	actual.on_spawned()
	check(actual.model == null and actual.body == null, "Deferred scenery must not allocate models or cosmetic bodies")
	actual.set_view_active(true)
	check(actual.model != null and actual.body == null, "An unfinished visible wall must draw without completed collision")
	actual.set_view_active(false)
	actual.built = true
	actual.set_view_active(true)
	check(actual.body != null and actual.body.collision_layer == Defs.L_COVER, "Construction completed off-screen must gain collision when revisited")
	actual.team = 0
	actual._recolor()
	check(actual.is_processing(), "Capturing neutral scenery must resume ownership and fog updates")
	actual.set_view_active(false)
	check(not actual.model.visible and actual.body.collision_layer == 0, "Inactive scenery must leave rendering and cosmetic collision")
	actual.srv = true
	actual.body.collision_layer = Defs.L_COVER
	actual.set_view_active(true)
	actual.set_view_active(false)
	check(actual.body.collision_layer == Defs.L_COVER, "Hiding host scenery must retain authoritative projectile collision")
	var host_view := StructureView.new()
	host_view.world = world
	actual.eid = 3
	actual.position = Vector3(1400, 0, 0)
	actual.set_view_active(true)
	host_view.add(actual)
	host_view.focus_at(Vector3.ZERO)
	check(not actual.view_active and actual.body.collision_layer == Defs.L_COVER, "Initial host residency hides distant models without changing combat")
	actual.position = Vector3(1500, 0, 0)
	actual.set_view_active(true)
	host_view.remove(actual)
	host_view.add(actual)
	check(not actual.view_active, "A moved off-screen host structure must not bypass residency")
	host_view.free()
	world.free()
	check_camera_residency()
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	print("STRUCTURE_VIEW_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func check_camera_residency() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var camera := Camera3D.new()
	camera.far = 700.0
	camera.fov = 40.0
	viewport.add_child(camera)
	var world := World.new()
	var view := StructureView.new()
	view.world = world
	camera.position = Vector3(0, 100, 100)
	camera.look_at(Vector3.ZERO)
	view.focus_at(Vector3.ZERO, camera)
	check(view.active.size() < 81, "A close view should not retain the old kilometre-wide square")
	view.focus_at(Vector3.ZERO)
	check(view.active.size() == 81, "Removing the camera must restore fallback residency at the same position")
	view.focus_at(Vector3.ZERO, camera)
	check(view.active.size() < 81, "Restoring the camera must invalidate fallback residency")
	for screen in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		viewport.size = screen
		for fov in [40.0, 75.0]:
			camera.fov = fov
			for distance in [30.0, 210.0]:
				for pitch in [20.0, 80.0]:
					for yaw in [0.0, 1.3]:
						camera.position = Vector3(0, distance * sin(deg_to_rad(pitch)), distance * cos(deg_to_rad(pitch))).rotated(Vector3.UP, yaw)
						camera.look_at(Vector3.ZERO)
						view.focus_at(Vector3.ZERO, camera)
						for x in range(-900, 901, 60):
							for z in range(-900, 901, 60):
								for height in [0.0, 32.0, 96.0]:
									var point := Vector3(x, height, z)
									if camera.is_position_in_frustum(point):
										var cell := Vector2i(floori(x / StructureView.CELL), floori(z / StructureView.CELL))
										check(view.active.has(cell), "Visible scenery must remain resident through tilt, rotation, zoom and resize")
	world.has_view = false
	world.terrain = TerrainMap.new(world)
	var elevated := ViewStub.new()
	elevated.eid = 3
	elevated.position = Vector3(0, 220, 0)
	elevated.view_active = false
	view.add(elevated)
	viewport.size = Vector2i(1280, 720)
	camera.fov = 20.0
	camera.position = Vector3(0, 220, 30)
	camera.look_at(elevated.position)
	view.focus_at(elevated.position, camera)
	world.terrain.landform.peak = 240.0
	view.focus_at(elevated.position, camera)
	check(camera.is_position_in_frustum(elevated.position) and view.resident.has(3), "Visible trees on high terrain must survive cell frustum culling")
	# Eight cold models exceed the four-per-frame prefetch budget.
	world.cam = RtsCamera.new()
	world.cam.world = world
	viewport.add_child(world.cam)
	camera.current = true
	world.loaded = true
	var crowd: Array[ViewStub] = []
	for i in 8:
		var st := ViewStub.new()
		st.eid = 500 + i
		st.position = elevated.position + Vector3(i * 0.2, 0, 0)
		st.view_active = false
		view.add(st)
		crowd.append(st)
	view._process(0.016)
	for st in crowd:
		check(st.view_active, "Every visible structure must be ready on the first frame of a camera cut")
		view.remove(st)
		st.free()
	view.remove(elevated)
	elevated.free()
	view.free()
	world.free()
	viewport.free()
