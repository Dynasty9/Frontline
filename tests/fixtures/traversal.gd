extends Node

func _ready() -> void:
	MapDims.N = 64
	MapDims.HALF = 32.0
	MapDims.SIZE = 64.0
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var w := World.new()
	w.settings = {"seed": 3}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	w.nav = Nav.new()
	w.nav.terrain = w.terrain
	# A uniform 29-degree ramp admits tracks and infantry, but not wheels.
	var heights := PackedFloat32Array()
	heights.resize(17 * 17)
	for z in 17:
		for x in 17:
			heights[z * 17 + x] = x * 4.0 * 0.55
	w.terrain.install_landform(heights)
	var c := Vector3(0.5, 0, 0.5)
	assert(w.nav.walkable(c))
	assert(w.nav.vkind_at(c) == Nav.SOLID)
	assert(w.nav.vkind_at(c, true) == Nav.FREE)
	w.nav.finalize()
	assert(w.nav.find_path(Vector3(-10, 0, 0), Vector3(10, 0, 0), true).is_empty())
	assert(not w.nav.find_path(Vector3(-10, 0, 0), Vector3(10, 0, 0), true, -1, 0, true).is_empty())
	var tank := Vehicle.new()
	tank.world = w
	tank.vkind = "tank"
	tank.vdef = Defs.VEHICLES.tank
	tank.position = c
	tank._move_by(Vector3(2, 0, 0), 0.5)
	assert(tank.position.x > c.x + 0.9, "Tracked movement uses its own grid")
	var routed := [false]
	w.nav.request_path(tank, tank.position + Vector3(2, 0, 0), true, 0, 0, func(points: PackedVector3Array): routed[0] = not points.is_empty())
	assert(routed[0], "Queued vehicle routes select the tracked graph")
	tank.free()
	var truck := Vehicle.new()
	truck.world = w
	truck.vkind = "supply"
	truck.vdef = {"base": "supply"}
	truck.position = c
	truck._move_by(Vector3(2, 0, 0), 0.5)
	assert(truck.position.x == c.x, "Supply trucks cannot bypass forbidden terrain")
	truck.free()
	# A narrow ridge beside a flat centre still blocks a hull's footprint.
	assert(w.terrain.vehicle_slopes.size() == 4096)
	for i in w.terrain.slopes.size():
		assert(w.terrain.vehicle_slopes[i] >= w.terrain.slopes[i])
	w.free()
	_footprint()
	_water()
	_regions()
	print("TRAVERSAL passed: vehicle classes, water depth, swept movement, bridges, stale routes, connectivity")
	get_tree().quit()


func _water() -> void:
	var w := World.new()
	w.settings = {"seed": 3}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	w.nav = Nav.new()
	w.nav.terrain = w.terrain
	# Deliberately label a deep bed shallow: actual depth must still win.
	for z in 64:
		for x in range(30, 34):
			w.terrain.base[z * 64 + x] = TerrainMap.SHALLOW
	for z in 128:
		for x in range(60, 68):
			w.terrain.dh[z * 128 + x] = -2.0
	for z in 64:
		for x in range(30, 34):
			w.nav.terrain_changed(z * 64 + x)
	var a := Vector3(-4.5, 0, 0.5)
	var b := Vector3(4.5, 0, 0.5)
	assert(not w.nav.walkable(Vector3(0.5, 0, 0.5)))
	assert(not w.nav.can_step(a, b), "A long tick cannot jump across deep water")
	assert(not w.nav.can_step(a, b, true), "Vehicle steps also check the whole crossing")
	w.nav.finalize()
	assert(w.nav.find_path(a, b).is_empty(), "Disconnected shores reject routes")
	var man := Soldier.new()
	man.world = w
	man.eid = 123
	man.position = a
	man.path = PackedVector3Array([b])
	man._move_tick(2.0, 8.0)
	assert(man.position == a, "An old route cannot walk through a newly deep channel")
	w.nav.cancel_path(man.eid)
	man.unhide(Vector3(0.5, 0, 0.5))
	assert(w.nav.walkable(man.position), "Disembarking finds a safe bank")
	man.free()
	# A ford and a bridge are both valid crossings, without changing the other water.
	for z in range(60, 68):
		for x in range(60, 68):
			w.terrain.dh[z * 128 + x] = -0.85
	for z in range(31, 33):
		for x in range(30, 34):
			w.nav.terrain_changed(z * 64 + x)
	while w.nav.hnav_i.has_work():
		w.nav.update_hier(100)
	assert(w.nav.can_step(a, b))
	assert(not w.nav.find_path(a, b).is_empty(), "Opening a ford updates connectivity")
	assert(w.water.depth_at(Vector3(0.5, 0, 0.5)) < WaterMap.MAX_WADE_DEPTH)
	var wader := Soldier.new()
	wader.world = w
	wader.position = Vector3(0.5, -0.85, 0.5)
	wader.posture = Soldier.Post.PRONE
	wader.suppression = 90.0
	wader._weapon_tick(0.03, false, "normal")
	assert(wader.posture == Soldier.Post.STAND, "Suppression cannot make a wading soldier lie underwater")
	wader.free()
	w.water.deck.resize(4096)
	var bridge := Vector3(0.5, 0, 5.5)
	var idx := w.terrain.idx_of(bridge)
	w.terrain.base[idx] = TerrainMap.WATER
	w.water.deck[idx] = 1
	w.nav.terrain_changed(idx)
	assert(w.nav.walkable(bridge) and is_zero_approx(w.water.depth_at(bridge)), "Bridge decks override submerged beds")
	w.water.deck[idx] = 0
	w.nav.terrain_changed(idx)
	assert(not w.nav.walkable(bridge), "Removing a bridge closes the crossing")
	w.free()


func _regions() -> void:
	var grid := NavRaster.new(8)
	for y in 8:
		grid.set_point_solid(Vector2i(4, y), true)
	grid.build_regions()
	assert(grid.disconnected(Vector2i(1, 1), Vector2i(6, 1)))
	grid.set_point_solid(Vector2i(4, 3), false)
	assert(not grid.disconnected(Vector2i(1, 1), Vector2i(6, 1)), "A new passage merges regions immediately")
	grid.set_point_solid(Vector2i(4, 3), true)
	assert(grid.reference_grid().get_id_path(Vector2i(1, 1), Vector2i(6, 1)).is_empty())


func _footprint() -> void:
	var w := World.new()
	w.settings = {"seed": 1}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	var heights := PackedFloat32Array()
	heights.resize(17 * 17)
	for z in 17:
		for x in 17:
			heights[z * 17 + x] = 10.0 if x >= 9 else 0.0
	w.terrain.install_landform(heights)
	w.nav = Nav.new()
	w.nav.terrain = w.terrain
	var p := Vector3(-1.5, 0, 0.5)
	var i := w.terrain.idx_of(p)
	w.nav.terrain_changed(i)
	assert(w.terrain.slopes[i] < Nav.WHEEL_SLOPE, "The centre of the hull is flat")
	assert(w.nav.vkind_at(p, true) == Nav.SOLID, "The adjacent cliff still blocks the hull footprint")
	w.free()
