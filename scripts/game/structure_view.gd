class_name StructureView
extends Node
## Each view builds nearby scenery first. Authority, cover and fog keep the
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
var _terrain_rise := -1.0
const DRAW_CELL := 64.0
var _draw_waiting := {}
var _draw_batches := {}
var _draw_members := {}
var _draw_broken := {}
## Draw cell -> how many of its structures still wait for their models: a
## block is merged once none do (one merged late would stay out of it).
var _pending_cells := {}
## The view the pending scenery was last checked against, and whether it
## must be checked again (new scenery waiting, or last frame ran out of time)
var _vis_xf := Transform3D()
var _vis_proj := Projection()
var _vis_dirty := true
## How long a frame may spend on new models for scenery in view, and on
## merging blocks. A parked car's model alone took a fifth of a second, and a
## street of houses scrolling into view at once froze the frame for most of a
## second: now the nearest go first and the rest follow over the next frames.
const VISIBLE_BUDGET_US := 6000
const BATCH_BUDGET_US := 2000

func _ready() -> void:
	process_priority = 20


func add(st: Structure) -> void:
	# Hosts already built these models while generating the authoritative map.
	if st.view_active:
		resident[st.eid] = st
	var keys := []
	var wanted := false
	var r := st.radius
	for z in range(floori((st.position.z - r) / CELL), floori((st.position.z + r) / CELL) + 1):
		for x in range(floori((st.position.x - r) / CELL), floori((st.position.x + r) / CELL) + 1):
			var key := Vector2i(x, z)
			keys.append(key)
			if not cells.has(key):
				cells[key] = {}
			(cells[key] as Dictionary)[st.eid] = st
			if active.has(key):
				wanted = true
				request(st)
	memberships[st.eid] = keys
	if not wanted and center != Vector2i(-999, -999):
		st.set_view_active(false)
		resident.erase(st.eid)

func remove(st: Structure) -> void:
	unbatch(st, true)
	_take(st.eid)
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
		_queue_draw_batch(st)
		return
	if not pending.has(st.eid):
		order.append(st.eid)
		var cell := _draw_cell(st)
		_pending_cells[cell] = int(_pending_cells.get(cell, 0)) + 1
		_vis_dirty = true
	pending[st.eid] = st


## Takes a structure off the waiting list (null if it wasn't on it).
func _take(id: int) -> Structure:
	var st: Structure = pending.get(id)
	if st == null:
		return null
	pending.erase(id)
	var cell := _draw_cell(st)
	var left := int(_pending_cells.get(cell, 0)) - 1
	if left > 0:
		_pending_cells[cell] = left
	else:
		_pending_cells.erase(cell)
	return st

func warming() -> bool:
	return center == Vector2i(-999, -999) or not pending.is_empty() or not _draw_waiting.is_empty()

func focus_at(pos: Vector3, camera: Camera3D = null) -> void:
	var next := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var camera_id := camera.get_instance_id() if camera else 0
	var terrain_rise: float = maxf(0.0, world.terrain.landform.peak) if world.terrain else 0.0
	if next == center and terrain_rise == _terrain_rise and camera_id == _camera_id and (camera == null or (camera.global_transform == _camera_transform and camera.get_camera_projection() == _camera_projection)):
		return
	_camera_id = camera_id
	_terrain_rise = terrain_rise
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
			# Preload roofs and shadows from valley floors through the highest hillside.
			var midpoint := Vector3((x + 0.5) * CELL, 48.0 + terrain_rise * 0.5, (z + 0.5) * CELL)
			var extent := Vector3(CELL, 80.0 + terrain_rise * 0.5, CELL)
			if intersects_view(midpoint, extent, planes):
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
	_pending_cells.clear()
	order.clear()
	head = 0
	var nearby := wanted.values()
	nearby.sort_custom(func(a, b): return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	for st: Structure in nearby:
		request(st)

static func intersects_view(midpoint: Vector3, extent: Vector3, planes: Array[Plane]) -> bool:
	for plane in planes:
		if plane.distance_to(midpoint) > plane.normal.abs().dot(extent):
			return false
	return true


func _process(_dt: float) -> void:
	var started := Time.get_ticks_usec()
	if world.cam:
		var camera := world.cam.get_viewport().get_camera_3d()
		focus_at(world.cam.focus_pos, camera)
		if camera and world.loaded and not pending.is_empty() and (_vis_dirty or camera.global_transform != _vis_xf or camera.get_camera_projection() != _vis_proj):
			# (checked again only when the view or the waiting list changes:
			# a town's thousand-odd waiting pieces tested every frame cost
			# a few milliseconds of every frame)
			_vis_xf = camera.global_transform
			_vis_proj = camera.get_camera_projection()
			_vis_dirty = false
			var planes := camera.get_frustum()
			for st: Structure in pending.values():
				var half_height := maxf(32.0, st.size.y) * 0.5
				var extent := Vector3(st.radius + 4.0, half_height + 4.0, st.radius + 4.0)
				if intersects_view(st.position + Vector3.UP * half_height, extent, planes):
					if Time.get_ticks_usec() - started > VISIBLE_BUDGET_US:
						_vis_dirty = true  # the rest next frame (pending is nearest first)
						break
					_take(st.eid)
					st.set_view_active(true)
					_queue_draw_batch(st)
	var count := 0
	while head < order.size() and count < 4 and Time.get_ticks_usec() - started < 2000:
		var id := order[head]
		head += 1
		var st: Structure = _take(id)
		if is_instance_valid(st) and not st.gone and resident.has(id):
			var needs_model := st.model == null
			st.set_view_active(true)
			_queue_draw_batch(st)
			if needs_model:
				count += 1
	if head == order.size():
		order.clear()
		head = 0
	# Each block is merged as soon as all of it is built, not once the whole
	# neighbourhood is: in a town that never happened (a thousand pieces wait
	# their turn, and every pan starts the list again), so every wall drew on
	# its own, several draws a wall in each of the four shadow cascades.
	merge_ready_blocks()
	world.vp("scenery construction", started)


## Merges the waiting blocks that are wholly built, for up to BATCH_BUDGET_US.
func merge_ready_blocks() -> void:
	var started := Time.get_ticks_usec()
	for cell: Vector2i in _draw_waiting.keys():
		if Time.get_ticks_usec() - started > BATCH_BUDGET_US:
			break
		if not _pending_cells.has(cell):
			_build_draw_batch(cell)


func _draw_cell(st: Structure) -> Vector2i:
	return Vector2i(floori(st.position.x / DRAW_CELL), floori(st.position.z / DRAW_CELL))


func _batchable(st: Structure) -> bool:
	return st.view_active and st.model != null and st.team < 0 and st.built and not st.burnt and st.burn <= 0.0 and st._char <= 0.0 and st.toss == null and st.skind in ["house_wall", "floor", "crates", "low_wall", "tree"]


func _queue_draw_batch(st: Structure) -> void:
	if not _batchable(st):
		return
	var cell := _draw_cell(st)
	if _draw_broken.has(st.eid) or _draw_batches.has(cell):
		return
	if not _draw_waiting.has(cell):
		_draw_waiting[cell] = {}
	(_draw_waiting[cell] as Dictionary)[st.eid] = st


func _build_draw_batch(cell: Vector2i) -> void:
	var candidates: Array = (_draw_waiting[cell] as Dictionary).values()
	_draw_waiting.erase(cell)
	var origin := Vector3(cell.x * DRAW_CELL, 0, cell.y * DRAW_CELL)
	var groups := {}
	var meshes := []
	var members := {}
	for st in candidates:
		if not is_instance_valid(st) or st.gone or not _batchable(st) or _draw_cell(st) != cell:
			continue
		var own := {}
		var parts := []
		Mats._collect(st.model, Transform3D(Basis.IDENTITY, -origin) * st.transform * st.model.transform, own, parts, [], true, true, false)
		var suitable := not own.is_empty()
		for group: Dictionary in own.values():
			if group.mat.get_shader_parameter("local_space") == true or group.mat.shader not in [Mats.shader(), Mats.foliage().shader]:
				suitable = false
		if not suitable:
			continue
		var ranges := []
		for key in own:
			ranges.append([key, (groups[key].v as PackedVector3Array).size() if groups.has(key) else 0, (own[key].v as PackedVector3Array).size()])
			if not groups.has(key):
				groups[key] = own[key]
			else:
				for attribute in ["v", "n", "c", "uv"]:
					groups[key][attribute].append_array(own[key][attribute])
		meshes.append_array(parts)
		members[st.eid] = {"cell": cell, "meshes": parts, "ranges": ranges}
	if members.size() < 2:
		return
	var holder := Node3D.new()
	world.add_child(holder)
	holder.position = origin
	var surfaces := {}
	# the block's opaque surfaces cast one shadow together (Mats._shadow_proxy)
	var casters := Mats._shadow_casters(groups)
	var proxied := casters.size() >= 2
	for key in groups:
		var group: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.v
		arrays[Mesh.ARRAY_NORMAL] = group.n
		arrays[Mesh.ARRAY_COLOR] = group.c
		if not group.uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = group.uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = group.mat if group.mat.get_shader_parameter("use_vcolor") == true else Mats.vc_variant(group.mat)
		instance.cast_shadow = group.shadow
		if proxied and key in casters:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(instance)
		surfaces[key] = mesh
	if proxied:
		# where each caster's triangles start in the proxy, so a member leaving
		# the block can be blanked out of it as out of the meshes it draws with
		var starts := {}
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		for key in casters:
			starts[key] = v.size()
			v.append_array(groups[key].v)
			n.append_array(groups[key].n)
		var proxy := Mats.shadow_proxy_node(v, n, true)
		holder.add_child(proxy)
		for id in members:
			var extra := []
			for span: Array in members[id].ranges:
				if starts.has(span[0]):
					extra.append([proxy.mesh, int(starts[span[0]]) + int(span[1]), span[2]])
			members[id]["proxy_ranges"] = extra
	for mesh: MeshInstance3D in meshes:
		mesh.visible = false
	_draw_batches[cell] = {"node": holder, "meshes": meshes, "members": members}
	for id in members:
		var member: Dictionary = members[id]
		for span: Array in member.ranges:
			span[0] = surfaces[span[0]]
		member.ranges.append_array(member.get("proxy_ranges", []))
		member.erase("proxy_ranges")
		_draw_members[id] = member


## Remove only the changed object's triangles; the rest of the block stays batched.
func unbatch(st: Structure, leaving := false) -> void:
	if leaving:
		_draw_broken.erase(st.eid)
	if not _draw_members.has(st.eid):
		return
	var member: Dictionary = _draw_members[st.eid]
	var cell: Vector2i = member.cell
	var batch: Dictionary = _draw_batches[cell]
	for span: Array in member.ranges:
		var mesh: ArrayMesh = span[0]
		var stride := RenderingServer.mesh_surface_get_format_vertex_stride(mesh.surface_get_format(0), mesh.surface_get_array_len(0))
		var empty := PackedByteArray()
		empty.resize(int(span[2]) * stride)
		mesh.surface_update_vertex_region(0, int(span[1]) * stride, empty)
	for mesh in member.meshes:
		batch.meshes.erase(mesh)
		if is_instance_valid(mesh):
			mesh.visible = true
	(batch.members as Dictionary).erase(st.eid)
	_draw_members.erase(st.eid)
	if not leaving:
		_draw_broken[st.eid] = true
	if batch.members.is_empty():
		(batch.node as Node3D).visible = false
		(batch.node as Node3D).queue_free()
		_draw_batches.erase(cell)
