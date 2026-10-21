extends Node

var failures := 0
var delivered: Array = []


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	# Small dimensions exercise the real graph and scheduler without a world.
	MapDims.N = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var nav := Nav.new()
	nav.hnav_i.build()
	nav.hnav_v.build()
	var from := Vector3(-20, 0, -20)
	var to := Vector3(20, 0, 20)
	check(not nav.find_path(from, to).is_empty(), "Open clusters must connect")
	var nearby := to + Vector3(1, 0, 0)
	var reused := nav.find_path(from + Vector3(1, 0, 0), nearby)
	check(nav.path_cache_hits == 1 and reused[reused.size() - 1] == nearby, "Nearby orders must reuse a corridor while retaining their own destination")
	var danger := PackedFloat32Array()
	danger.resize(HNav.NC * HNav.NC)
	danger[0] = 1.0
	nav.hnav_i.set_danger(0, danger)
	nav.find_path(from, to)
	check(nav.path_cache_hits == 2, "Danger changes must not discard routes that ignore danger")
	nav.find_path(from, to, false, 0, 1.0)
	nav.hnav_i.set_danger(1, danger)
	nav.find_path(from, to, false, 0, 1.0)
	check(nav.path_cache_hits == 3, "One side's danger changes must not discard the other side's corridor")
	danger = danger.duplicate()
	danger[0] = 2.0
	nav.hnav_i.set_danger(0, danger)
	nav.find_path(from, to, false, 0, 1.0)
	check(nav.path_cache_hits == 3, "A tactical route must be recalculated when its own danger changes")
	for z in Nav.N:
		var cell := Vector2i(32, z)
		nav.inf.set_point_solid(cell, true)
		nav.ikind[cell.y * Nav.N + cell.x] = Nav.SOLID
		nav.hnav_i.mark_dirty(cell)
	var steps := 0
	while nav.hnav_i.has_work() and steps < 10000:
		nav.hnav_i.update(1)
		steps += 1
	check(steps < 10000, "Incremental rebuilding must finish")
	check(nav.find_path(from, to).is_empty(), "A sealed wall must be unreachable")
	var gate := Vector2i(32, 32)
	nav.inf.set_point_solid(gate, false)
	nav.ikind[gate.y * Nav.N + gate.x] = Nav.FREE
	nav.hnav_i.mark_dirty(gate)
	var unit := Entity.new()
	unit.eid = 1
	unit.position = from
	nav.request_path(unit, to, false, -1, 0.0, func(_p): delivered.append("old"))
	nav.request_path(unit, to, false, -1, 0.0, func(p): delivered.append(p))
	nav.process_paths()
	check(delivered.is_empty(), "Orders must wait for a rebuilding graph")
	while nav.hnav_i.has_work():
		nav.hnav_i.update(1)
	nav.process_paths(100000)
	check(delivered.size() == 1 and delivered[0] is PackedVector3Array and not delivered[0].is_empty(), "Only the latest order must run after the gate opens")
	nav.request_path(unit, to, false, -1, 0.0, func(_p): delivered.append("cancelled"))
	nav.cancel_path(unit.eid)
	nav.process_paths(100000)
	check(delivered.size() == 1, "Cancelled orders must not call back")
	unit.free()
	var world := World.new()
	world.nav = nav
	var soldier := Soldier.new()
	soldier.world = world
	soldier._path_pending = true
	check(soldier._move_tick(1.0 / 30.0, 2.0), "A queued route must not finish movement-dependent tasks")
	soldier.stop_moving()
	check(not soldier.is_moving(), "Stopping must clear pending movement")
	soldier.free()
	world.free()
	MapDims.N = 512
	HNav.NC = 32
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 512, 512)
	grid.update()
	var cached := HNav.new(grid, false)
	var changed := Vector2i(2, 2)
	grid.set_point_solid(changed, true)
	grid.set_point_weight_scale(changed, 2.5)
	cached.mark_dirty(changed)
	for ci in 513:
		cached.local_grid(ci)
	check(not cached._local.has(0) and cached._local.size() == 512, "Local grids must evict within the cell budget")
	var restored := cached.local_grid(0)
	check(restored.is_point_solid(changed) and restored.get_point_weight_scale(changed) == 2.5, "Eviction must preserve obstacle and movement costs")
	print("NAVIGATION_BUDGET_TEST failures=%d rebuild_steps=%d" % [failures, steps])
	get_tree().quit(1 if failures else 0)
