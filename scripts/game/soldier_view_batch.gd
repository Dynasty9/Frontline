class_name SoldierViewBatch
extends Node3D
## Distant men share baked poses of the same models used close up. Their
## simulation, selection and visibility still belong to each Soldier.

class DrawGroup:
	var mm: MultiMesh
	var buffer := SoldierBatchBuffer.new()
	var node: MultiMeshInstance3D
	var origin: Vector3
	var count := 0
	var last_used := 0.0
	var bounds := AABB()
	var model_radius := 0.0

var motion := SoldierViewMotion.new()
var world: World
const CELL := 64.0
const MAX_DETAILED := 16
const COMMAND_DETAILED := 4
var detail_ids := {}
var _detail_left := 0.0
var _detail_view := Transform3D.IDENTITY
var groups := {}
var poses := {}
var prototypes := {}
var detail_templates := {}
var _types := {}
var _next_pose := 0
var _warmup: Array = []
var _detail_frame := -1
var _detail_count := 0
var _active: Array[DrawGroup] = []
var _expires_at := 0.0
var _dirty := true
var _motion_frame := -1
var _sample_view := Transform3D.IDENTITY
var _sample_projection := Projection()
var _batch_deferred := 0
var _age := 0.0
var _material: ShaderMaterial
var _atlases := {}
var _presentations := {}
var _presentation_team := -2
var _presentation_camera := false
var _batch_radii := PackedFloat32Array()
var _native_batches := false


func request_view(soldier: Soldier) -> void:
	if soldier.gone:
		return
	if not _presentations.has(soldier.eid):
		# Resume detail from this frame's movement, not all motion since it went dormant.
		soldier._last_view_pos = soldier.position
	_presentations[soldier.eid] = soldier


func remove(soldier: Soldier) -> void:
	_presentations.erase(soldier.eid)
	motion.remove(soldier)
	invalidate()


func invalidate() -> void:
	_dirty = true


func motion_changed() -> void:
	# Spread routine uploads away from packet decoding; visibility is still immediate.
	if _motion_frame < 0:
		_motion_frame = Engine.get_process_frames() + 1


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
	if _detail_count >= 1:
		return false
	_detail_count += 1
	return true


func make_detail(unit: String, team: int, seed: int) -> SoldierModel:
	var teams: Dictionary = _types.get(unit, {})
	var template: SoldierModel = detail_templates.get(int(teams.get(team, -1)))
	return template.duplicate_for_soldier(seed) if template else null


func _choose_detail(dt: float) -> void:
	if not world.cam:
		return
	var camera := world.cam.cam
	_detail_left -= dt
	if _detail_left > 0.0 and camera.global_transform == _detail_view:
		return
	_detail_left = 0.2
	_detail_view = camera.global_transform
	var candidates := []
	for soldier: Soldier in world.soldiers:
		if soldier.gone or not soldier.visible or soldier.life == Soldier.Life.HIDDEN:
			continue
		var distance := camera.global_position.distance_squared_to(soldier.position)
		if distance > 8100.0 or not camera.is_position_in_frustum(soldier.position + Vector3(0, 1, 0)):
			continue
		# Favour selected men and retain nearby detail to avoid switching models at a tie.
		var priority := distance * (0.85 if detail_ids.has(soldier.eid) else 1.0)
		if not soldier.selected:
			priority += 10000.0
		candidates.append([priority, soldier.eid])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var previous := detail_ids
	detail_ids = {}
	# At command zoom shared poses retain the army; close inspection keeps more articulated men.
	var budget := MAX_DETAILED if world.cam.dist < 22.0 else COMMAND_DETAILED
	for i in mini(budget, candidates.size()):
		detail_ids[candidates[i][1]] = true
	for ids in [previous, detail_ids]:
		for id in ids:
			var soldier: Soldier = world.entity(id) as Soldier
			if soldier:
				request_view(soldier)


func _ready() -> void:
	process_priority = 10
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/shaders/soldier_batch.gdshader")


func _process(dt: float) -> void:
	var started := Time.get_ticks_usec()
	# Keep individual smoothing and poses, but pay frame bookkeeping once per army.
	if world.has_view and world.soldier_view == self:
		if _presentation_team != world.view_team or _presentation_camera != (world.cam != null):
			_presentation_team = world.view_team
			_presentation_camera = world.cam != null
			for soldier: Soldier in world.soldiers:
				request_view(soldier)
		_choose_detail(dt)
		var blend := 1.0 - exp(-dt * 14.0)
		if motion.advance(blend):
			_dirty = true
		var presentations: Array = _presentations.values() if world.simulation_client else world.soldiers
		for soldier: Soldier in presentations:
			if not is_instance_valid(soldier):
				continue
			if not soldier.gone:
				if not soldier._native_view_motion and _motion_frame >= 0 and soldier.position.distance_squared_to(soldier.net_pos) > 64.0:
					_dirty = true
				var was_lod := soldier.view_lod
				var was_visible := soldier.visible
				soldier._view_process(dt, blend, soldier._native_view_motion)
				if soldier.view_lod != was_lod or soldier.visible != was_visible:
					_dirty = true
				_update_batch(soldier)
				if soldier.retains_view():
					_presentations.erase(soldier.eid)
		world.vp("soldiers", started)
		started = Time.get_ticks_usec()
	# Bake one pose per frame while loading, rather than baking a whole new
	# stance for hundreds of men on the frame they first take cover.
	if not _warmup.is_empty():
		var pose: Array = _warmup.pop_front()
		_make_pose(pose[0], pose[1], pose[2], pose[3], pose[4])
		_dirty = true
	var interpolate := world.simulation_client != null
	var motion_due := _motion_frame >= 0 and Engine.get_process_frames() >= _motion_frame
	var view := world.cam.cam.global_transform if world.cam else Transform3D.IDENTITY
	var projection := world.cam.cam.get_camera_projection() if world.cam else Projection()
	_age += dt
	if interpolate and not _dirty and view == _sample_view and projection == _sample_projection:
		var unchanged := not motion_due
		var overview_busy := world.hud and world.hud.overview_frame == Engine.get_process_frames()
		if unchanged or (overview_busy and _batch_deferred < 2):
			# Two frames let the summary and roster finish separately while GPU motion continues.
			if not unchanged:
				_batch_deferred += 1
			_set_animation(_age)
			world.vp("distant soldiers", started)
			return
	_batch_deferred = 0
	_dirty = false
	_motion_frame = -1
	_sample_view = view
	_sample_projection = projection
	_age = 0.0
	_set_animation(0.0)
	var previous_groups := _active
	_active = []
	for group: DrawGroup in previous_groups:
		group.count = 0
		group.buffer.clear()
	var planes: Array[Plane] = []
	if world.cam:
		planes = world.cam.cam.get_frustum()
	var native_ready := interpolate and _warmup.is_empty() and _atlases.size() * 15 == _next_pose
	if native_ready and not _native_batches:
		for soldier: Soldier in world.soldiers:
			_update_batch(soldier)
	_native_batches = native_ready
	if _native_batches:
		for batch: Dictionary in motion.batches(planes, _batch_radii):
			var key: Vector3i = batch.key
			var group := _group_for(key.z, Vector2i(key.x, key.y))
			group.count = batch.count
			group.last_used = world.time
			if group.count > group.mm.instance_count:
				group.mm.instance_count = maxi(group.count, group.mm.instance_count * 2)
			var data: PackedFloat32Array = batch.data
			data.resize(group.mm.instance_count * 20)
			group.mm.buffer = data
			group.bounds = batch.bounds
			_active.append(group)
	else:
		_fill_batches(planes, interpolate)
	_dirty = false
	for group: DrawGroup in previous_groups:
		if group.count == 0:
			group.mm.visible_instance_count = 0
	for group: DrawGroup in _active:
		if not _native_batches:
			if group.count > group.mm.instance_count:
				group.mm.instance_count = maxi(group.count, group.mm.instance_count * 2)
			group.mm.buffer = group.buffer.encode(group.mm.instance_count)
			group.bounds = group.buffer.bounds()
		if group.mm.custom_aabb != group.bounds:
			group.mm.custom_aabb = group.bounds
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


func _update_batch(s: Soldier) -> void:
	if not s._native_view_motion:
		return
	if not s.view_lod or not s.visible or s.gone:
		if motion.set_batch(s, -1, 0):
			_dirty = true
		return
	prepare(s.utype, s.team)
	var base: int = _types[s.utype][s.team]
	var posture := s.posture
	if s.life in [Soldier.Life.DEAD, Soldier.Life.DOWNED]:
		posture = Soldier.Post.PRONE
	if posture > Soldier.Post.PRONE:
		posture = Soldier.Post.STAND
	var walking := s.act in [Soldier.Act.WALK, Soldier.Act.RUN, Soldier.Act.LIMP, Soldier.Act.CRAWL]
	if motion.set_batch(s, base, posture * 8 + (posmod(s.eid, 4) + 1 if walking else 0)):
		_dirty = true


func _fill_batches(planes: Array[Plane], interpolate: bool) -> void:
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
		var key := base if _atlases.has(base) else base + posture * 5 + frame
		if not poses.has(key):
			key = base
			if not poses.has(key):
				continue
		var group := _group_for(key, cell)
		var slot: int = group.count
		var transform := s.transform
		if s.srv:
			transform *= s.ip_offset()
		transform.origin -= group.origin
		var offset := s.net_pos - s.position if interpolate else Vector3.ZERO
		var turn := angle_difference(s.rotation.y, s.net_yaw) if interpolate else 0.0
		# Pose selection rides in the unused tint alpha; motion retains all four custom values.
		var pose_code := posture * 8 + (posmod(s.eid, 4) + 1 if walking else 0)
		if not group.buffer.append(transform, offset, turn, pose_code if _atlases.has(base) else 255, group.model_radius):
			continue
		if slot == 0:
			_active.append(group)
		group.count = slot + 1
		group.last_used = world.time


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
		# Keep an untouched rig while the other copy is posed for distant batches.
		var template := prototype.duplicate_for_soldier(71)
		add_child(template)
		template.visible = false
		detail_templates[prototype_key] = template
	# Settle the stance, then sample a walk cycle at a repeatable phase.
	for i in 4:
		prototype.pose(0.25, Soldier.Life.ALIVE, posture, Soldier.Act.IDLE, 0.0, false, false)
	if frame > 0:
		for i in frame * 2:
			prototype.pose(0.0625, Soldier.Life.ALIVE, posture, Soldier.Act.WALK, 2.6, false, false)
	var mesh := Mats.bake_mesh(prototype)
	poses[key] = mesh
	if posture == Soldier.Post.PRONE and frame == 4:
		_make_atlas(prototype_key)


func _group_for(pose: int, cell: Vector2i) -> DrawGroup:
	var key := Vector3i(cell.x, cell.y, pose)
	if groups.has(key):
		return groups[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = poses[pose]
	mm.instance_count = 16
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	# Shared models are small on screen; keep fine geometry for the articulated rigs.
	node.lod_bias = 0.25
	node.material_override = _atlases.get(pose, _material)
	node.position = Vector3(cell.x * CELL, 0, cell.y * CELL)
	add_child(node)
	var group := DrawGroup.new()
	group.mm = mm
	group.model_radius = _mesh_radius(mm.mesh)
	group.node = node
	group.origin = node.position
	group.last_used = world.time
	groups[key] = group
	return group


static func _mesh_radius(mesh: Mesh) -> float:
	var bounds := mesh.get_aabb()
	return bounds.position.abs().max(bounds.end.abs()).length()


func _set_animation(age: float) -> void:
	_material.set_shader_parameter("age", age)
	for material: ShaderMaterial in _atlases.values():
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("animation_frame", posmod(int(world.time * 8.0), 4))


func _make_atlas(base: int) -> void:
	# Keep the same sampled poses while letting every stance share one spatial batch.
	var samples := []
	var bounds := AABB()
	for frame in 15:
		var mesh: ArrayMesh = poses[base + frame]
		bounds = bounds.merge(mesh.get_aabb())
		samples.append(mesh.surface_get_arrays(0))
	var arrays: Array = samples[0].duplicate()
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for sample: Array in samples:
		assert(sample[Mesh.ARRAY_INDEX] == arrays[Mesh.ARRAY_INDEX], "Pose index correspondence")
		assert(sample[Mesh.ARRAY_COLOR] == arrays[Mesh.ARRAY_COLOR], "Pose color correspondence")
		assert(sample[Mesh.ARRAY_VERTEX].size() == count, "Pose vertex correspondence")
	var rows := ceili(float(count) / 1024.0)
	var image := Image.create(1024, rows * 30, false, Image.FORMAT_RGBAF)
	var uv := PackedVector2Array()
	uv.resize(count)
	for i in count:
		uv[i] = Vector2(i % 1024, i / 1024)
	for frame in 15:
		var vertices: PackedVector3Array = samples[frame][Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = samples[frame][Mesh.ARRAY_NORMAL]
		for i in count:
			var v := vertices[i]
			var n := normals[i]
			image.set_pixel(i % 1024, i / 1024 + frame * rows * 2, Color(v.x, v.y, v.z, 1))
			image.set_pixel(i % 1024, i / 1024 + (frame * 2 + 1) * rows, Color(n.x, n.y, n.z, 1))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	poses[base] = importer.get_mesh()
	(poses[base] as ArrayMesh).custom_aabb = bounds
	for frame in range(1, 15):
		poses.erase(base + frame)
	var material := ShaderMaterial.new()
	material.shader = _material.shader
	material.set_shader_parameter("animated_poses", true)
	material.set_shader_parameter("poses", ImageTexture.create_from_image(image))
	material.set_shader_parameter("rows", rows)
	_atlases[base] = material
	_batch_radii.resize(_next_pose)
	_batch_radii[base] = _mesh_radius(poses[base])
	# Loading can already have displayed the first standing pose.
	for key: Vector3i in groups:
		if key.z == base:
			var group: DrawGroup = groups[key]
			group.mm.mesh = poses[base]
			group.model_radius = _mesh_radius(poses[base])
			group.node.material_override = material
