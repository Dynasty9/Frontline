class_name StructureView
extends Node
## The client builds nearby scenery first. Authority, cover and fog keep the
## complete world; distant cosmetic bodies and models need not exist yet.

const CELL := 128.0
const REACH := 4
var world: World
var cells := {}
var memberships := {}
var resident := {}
var active := {}
var pending := {}
var order: Array[int] = []
var head := 0
var center := Vector2i(-999, -999)
var _camera_transform := Transform3D()
var _camera_projection := Projection()
var _camera_id := 0

func add(st: Structure) -> void:
	var keys := []
	var r := st.radius
	for z in range(floori((st.position.z - r) / CELL), floori((st.position.z + r) / CELL) + 1):
		for x in range(floori((st.position.x - r) / CELL), floori((st.position.x + r) / CELL) + 1):
			var key := Vector2i(x, z)
			keys.append(key)
			if not cells.has(key):
				cells[key] = {}
			(cells[key] as Dictionary)[st.eid] = st
			if active.has(key):
				request(st)
	memberships[st.eid] = keys

func remove(st: Structure) -> void:
	pending.erase(st.eid)
	resident.erase(st.eid)
	for key: Vector2i in memberships.get(st.eid, []):
		if cells.has(key):
			(cells[key] as Dictionary).erase(st.eid)
			if (cells[key] as Dictionary).is_empty():
				cells.erase(key)
	memberships.erase(st.eid)

func request(st: Structure) -> void:
	resident[st.eid] = st
	if st.view_active:
		return
	if not pending.has(st.eid):
		order.append(st.eid)
	pending[st.eid] = st

func warming() -> bool:
	return center == Vector2i(-999, -999) or not pending.is_empty()

func focus_at(pos: Vector3, camera: Camera3D = null) -> void:
	var next := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var camera_id := camera.get_instance_id() if camera else 0
	if next == center and camera_id == _camera_id and (camera == null or (camera.global_transform == _camera_transform and camera.get_camera_projection() == _camera_projection)):
		return
	_camera_id = camera_id
	center = next
	var visible_cells := {}
	var low := next - Vector2i(REACH, REACH)
	var high := next + Vector2i(REACH, REACH)
	var planes: Array[Plane] = []
	if camera:
		_camera_transform = camera.global_transform
		_camera_projection = camera.get_camera_projection()
		planes = camera.get_frustum()
		var p := camera.global_position
		var bounds := Rect2(Vector2(p.x, p.z), Vector2.ZERO)
		var screen := camera.get_viewport().get_visible_rect().size
		for corner in [Vector2.ZERO, Vector2(screen.x, 0), screen, Vector2(0, screen.y)]:
			var point := camera.project_position(corner, camera.far)
			bounds = bounds.expand(Vector2(point.x, point.z))
		bounds = bounds.grow(CELL)
		low = Vector2i(floori(bounds.position.x / CELL), floori(bounds.position.y / CELL))
		high = Vector2i(floori(bounds.end.x / CELL), floori(bounds.end.y / CELL))
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var key := Vector2i(x, z)
			# Preload beyond the screen edges, including roofs and shadows.
			var midpoint := Vector3((x + 0.5) * CELL, 48.0, (z + 0.5) * CELL)
			var extent := Vector3(CELL, 80.0, CELL)
			var visible_cell := true
			for plane: Plane in planes:
				if plane.distance_to(midpoint) > plane.normal.abs().dot(extent):
					visible_cell = false
					break
			if visible_cell:
				visible_cells[key] = true
	if visible_cells == active and not resident.is_empty():
		return
	active = visible_cells
	var wanted := {}
	for key: Vector2i in active:
		for st: Structure in (cells.get(key, {}) as Dictionary).values():
			wanted[st.eid] = st
	for st: Structure in resident.values():
		if not wanted.has(st.eid) and is_instance_valid(st) and not st.gone:
			st.set_view_active(false)
	resident = wanted
	pending.clear()
	order.clear()
	head = 0
	var nearby := wanted.values()
	nearby.sort_custom(func(a, b): return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	for st: Structure in nearby:
		request(st)

func _process(_dt: float) -> void:
	if world.cam:
		focus_at(world.cam.focus_pos, world.cam.cam)
	var started := Time.get_ticks_usec()
	var count := 0
	while head < order.size() and count < 4 and Time.get_ticks_usec() - started < 2000:
		var id := order[head]
		head += 1
		var st: Structure = pending.get(id)
		pending.erase(id)
		if is_instance_valid(st) and not st.gone and resident.has(id):
			st.set_view_active(true)
			count += 1
	if head == order.size():
		order.clear()
		head = 0
	world.vp("scenery construction", started)
