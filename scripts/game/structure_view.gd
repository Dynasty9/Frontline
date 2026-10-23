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

func focus_at(pos: Vector3) -> void:
	var next := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	if next == center:
		return
	center = next
	active.clear()
	var wanted := {}
	for z in range(center.y - REACH, center.y + REACH + 1):
		for x in range(center.x - REACH, center.x + REACH + 1):
			var key := Vector2i(x, z)
			active[key] = true
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
		focus_at(world.cam.focus_pos)
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
