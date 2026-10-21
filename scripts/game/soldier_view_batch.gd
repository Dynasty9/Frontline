class_name SoldierViewBatch
extends Node3D
## Distant men share baked poses of the same models used close up. Their
## simulation, selection and visibility still belong to each Soldier.

var world: World
const CELL := 64.0
var groups := {}
var poses := {}
var prototypes := {}
var _types := {}
var _warmup: Array = []
var _detail_frame := -1
var _detail_count := 0


func prepare(unit: String, team: int) -> void:
	var key := "%s:%d" % [unit, team]
	if _types.has(key):
		return
	_types[key] = true
	for posture in 3:
		for frame in 5:
			_warmup.append(["%s:%d:%d" % [key, posture, frame], unit, team, posture, frame])


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


func _process(_dt: float) -> void:
	var started := Time.get_ticks_usec()
	# Bake one pose per frame while loading, rather than baking a whole new
	# stance for hundreds of men on the frame they first take cover.
	if not _warmup.is_empty():
		var pose: Array = _warmup.pop_front()
		_make_pose(pose[0], pose[1], pose[2], pose[3], pose[4])
	for group: Dictionary in groups.values():
		group.count = 0
	for s: Soldier in world.soldiers:
		if not s.view_lod or not s.visible or s.gone:
			continue
		var posture := s.posture
		if s.life in [Soldier.Life.DEAD, Soldier.Life.DOWNED]:
			posture = Soldier.Post.PRONE
		if posture > Soldier.Post.PRONE:
			posture = Soldier.Post.STAND
		var walking := s.act in [Soldier.Act.WALK, Soldier.Act.RUN, Soldier.Act.LIMP, Soldier.Act.CRAWL]
		var frame := posmod(int(world.time * 8.0) + s.eid, 4) + 1 if walking else 0
		var key := "%s:%d:%d:%d" % [s.utype, s.team, posture, frame]
		if not poses.has(key):
			prepare(s.utype, s.team)
			key = "%s:%d:0:0" % [s.utype, s.team]
			if not poses.has(key):
				continue
		var cell := Vector2i(floori(s.position.x / CELL), floori(s.position.z / CELL))
		var group := _group_for(key, cell)
		var mm: MultiMesh = group.mm
		var slot: int = group.count
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
	for key in groups.keys():
		var group: Dictionary = groups[key]
		(group.mm as MultiMesh).visible_instance_count = group.count
		if group.count == 0 and world.time - float(group.last_used) > 5.0:
			(group.node as MultiMeshInstance3D).queue_free()
			groups.erase(key)
	world.vp("distant soldiers", started)


func _make_pose(key: String, unit: String, team: int, posture: int, frame: int) -> void:
	var prototype_key := "%s:%d" % [unit, team]
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


func _group_for(pose: String, cell: Vector2i) -> Dictionary:
	var key := "%s:%d:%d" % [pose, cell.x, cell.y]
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
	var group := {"mm": mm, "node": node, "origin": node.position, "count": 0, "last_used": world.time}
	groups[key] = group
	return group
