class_name SoldierViewBatch
extends Node3D
## Distant men share baked poses of the same models used close up. Their
## simulation, selection and visibility still belong to each Soldier.

class DrawGroup:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var origin: Vector3
	var count := 0
	var last_used := 0.0

var world: World
const CELL := 64.0
var groups := {}
var poses := {}
var prototypes := {}
var _types := {}
var _next_pose := 0
var _warmup: Array = []
var _detail_frame := -1
var _detail_count := 0
var _active: Array[DrawGroup] = []
var _expires_at := 0.0


func prepare(unit: String, team: int) -> void:
	if not _types.has(unit):
		_types[unit] = {}
	var teams: Dictionary = _types[unit]
	if teams.has(team):
		return
	var base := _next_pose
	_next_pose += 15
	teams[team] = base
	for posture in 3:
		for frame in 5:
			_warmup.append([base + posture * 5 + frame, unit, team, posture, frame])


func warming() -> bool:
	return not _warmup.is_empty()


func acquire_detail_slot() -> bool:
	var frame := Engine.get_process_frames()
	if frame != _detail_frame:
		_detail_frame = frame
		_detail_count = 0
	if _detail_count >= 2:
		return false
	_detail_count += 1
	return true


func _ready() -> void:
	process_priority = 10


func _process(dt: float) -> void:
	var started := Time.get_ticks_usec()
	# Keep individual smoothing and poses, but pay frame bookkeeping once per army.
	if world.has_view and world.soldier_view == self:
		for soldier: Soldier in world.soldiers:
			if not soldier.gone:
				soldier._view_process(dt)
		world.vp("soldiers", started)
		started = Time.get_ticks_usec()
	# Bake one pose per frame while loading, rather than baking a whole new
	# stance for hundreds of men on the frame they first take cover.
	if not _warmup.is_empty():
		var pose: Array = _warmup.pop_front()
		_make_pose(pose[0], pose[1], pose[2], pose[3], pose[4])
	var previous_groups := _active
	_active = []
	for group: DrawGroup in previous_groups:
		group.count = 0
	var planes: Array[Plane] = []
	if world.cam:
		planes = world.cam.cam.get_frustum()
	var visible_cells := {}
	for s: Soldier in world.soldiers:
		if not s.view_lod or not s.visible or s.gone:
			continue
		var cell := Vector2i(floori(s.position.x / CELL), floori(s.position.z / CELL))
		if not planes.is_empty() and absf(s.position.y) < 60.0:
			if not visible_cells.has(cell):
				visible_cells[cell] = _cell_visible(cell, planes)
			if not visible_cells[cell]:
				continue
		var posture := s.posture
		if s.life in [Soldier.Life.DEAD, Soldier.Life.DOWNED]:
			posture = Soldier.Post.PRONE
		if posture > Soldier.Post.PRONE:
			posture = Soldier.Post.STAND
		var walking := s.act in [Soldier.Act.WALK, Soldier.Act.RUN, Soldier.Act.LIMP, Soldier.Act.CRAWL]
		var frame := posmod(int(world.time * 8.0) + s.eid, 4) + 1 if walking else 0
		if not _types.has(s.utype) or not (_types[s.utype] as Dictionary).has(s.team):
			prepare(s.utype, s.team)
		var base: int = _types[s.utype][s.team]
		var key := base + posture * 5 + frame
		if not poses.has(key):
			key = base
			if not poses.has(key):
				continue
		var group := _group_for(key, cell)
		var mm: MultiMesh = group.mm
		var slot: int = group.count
		if slot == 0:
			_active.append(group)
		if slot >= mm.instance_count:
			# Resizing clears transforms; copy only when this cell first grows.
			var previous := mm.buffer
			mm.instance_count = maxi(16, mm.instance_count * 2)
			var expanded := mm.buffer
			for i in previous.size():
				expanded[i] = previous[i]
			if not previous.is_empty():
				mm.buffer = expanded
		var transform := s.transform
		if s.srv:
			transform *= s.ip_offset()
		transform.origin -= group.origin
		mm.set_instance_transform(slot, transform)
		group.count = slot + 1
		group.last_used = world.time
	for group: DrawGroup in previous_groups:
		if group.count == 0:
			group.mm.visible_instance_count = 0
	for group: DrawGroup in _active:
		group.mm.visible_instance_count = group.count
	# Old walking poses stay cached briefly, but need no per-frame visits.
	if world.time >= _expires_at:
		_expires_at = world.time + 1.0
		for key in groups.keys():
			var group: DrawGroup = groups[key]
			if group.count == 0 and world.time - group.last_used > 5.0:
				group.node.queue_free()
				groups.erase(key)
	world.vp("distant soldiers", started)


static func _cell_visible(cell: Vector2i, planes: Array[Plane]) -> bool:
	# Keep a full neighbouring cell for edge shadows, but do not upload men
	# across the rest of the map merely for the renderer to discard them.
	var center := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
	var extent := Vector3(CELL * 1.5, 64, CELL * 1.5)
	for plane: Plane in planes:
		if plane.distance_to(center) > plane.normal.abs().dot(extent):
			return false
	return true


func _make_pose(key: int, unit: String, team: int, posture: int, frame: int) -> void:
	var prototype_key := key - posture * 5 - frame
	var prototype: SoldierModel = prototypes.get(prototype_key)
	if prototype == null:
		prototype = SoldierModel.new()
		add_child(prototype)
		prototype.build(unit, team, 71)
		prototype.visible = false
		prototypes[prototype_key] = prototype
	# Settle the stance, then sample a walk cycle at a repeatable phase.
	for i in 4:
		prototype.pose(0.25, Soldier.Life.ALIVE, posture, Soldier.Act.IDLE, 0.0, false, false)
	if frame > 0:
		for i in frame * 2:
			prototype.pose(0.0625, Soldier.Life.ALIVE, posture, Soldier.Act.WALK, 2.6, false, false)
	var mesh := Mats.bake_mesh(prototype)
	poses[key] = mesh


func _group_for(pose: int, cell: Vector2i) -> DrawGroup:
	var key := Vector3i(cell.x, cell.y, pose)
	if groups.has(key):
		return groups[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = poses[pose]
	mm.instance_count = 16
	mm.visible_instance_count = 0
	# Separate spatial batches let culling and mesh LOD consider nearby men,
	# rather than the bounding box of every soldier of this type on the map.
	mm.custom_aabb = AABB(Vector3(-3, -4, -3), Vector3(CELL + 6, 16, CELL + 6))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.position = Vector3(cell.x * CELL, 0, cell.y * CELL)
	add_child(node)
	var group := DrawGroup.new()
	group.mm = mm
	group.node = node
	group.origin = node.position
	group.last_used = world.time
	groups[key] = group
	return group
