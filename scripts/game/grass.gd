class_name Grass
extends Node3D
## Instanced grass clumps, bushes and stones in 32 m chunks. Placement follows
## the ground's biome map and avoids roads and building floors. Rebuilt
## for the active camera first, with nearby off-screen chunks prepared between frames.

const CHUNK := 32.0
var HALF := MapDims.HALF

var atmo: Atmosphere
var mat: ShaderMaterial
var bush_mat: ShaderMaterial
var stone_mat: ShaderMaterial
var clump: ArrayMesh
var scar_img: Image
var scar_tex: ImageTexture
var _scar_dirty := false
var bush: ArrayMesh
var stone: ArrayMesh
var woodland: Woodland
var canopy_img: Image
var _shrub_noise := FastNoiseLite.new()
var level := -1
var _wildlife_level := -1
var _queue: Array = []
var _rebuild_t := -1.0
var _blocked := PackedByteArray()
var _bounds := {}  # local terrain heights for chunks still waiting to be built
var _built := {}  # Vector2i -> Array of nodes
var _center := Vector2i(999999, 999999)
const REACH := 7  # beyond the bushes' 170 m fade, including a chunk and pan margin


func _ready() -> void:
	process_priority = 20  # The camera and director have chosen this frame's view.
	clump = _make_clump()
	bush = _make_bush()
	stone = _make_stone()
	woodland = Woodland.new()
	woodland.setup()
	scar_img = Image.create(MapDims.N, MapDims.N, false, Image.FORMAT_L8)
	scar_tex = ImageTexture.create_from_image(scar_img)
	mat = ShaderMaterial.new()
	# (the clouds' shade, CloudShadow.FOLD: in the albedo with Cloud shadows off)
	mat.shader = CloudShadow.make(MapDims.shader(GRASS_SHADER), CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD)
	mat.set_shader_parameter("scar", scar_tex)
	bush_mat = ShaderMaterial.new()
	bush_mat.shader = CloudShadow.make(MapDims.shader(BUSH_SHADER), CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD)
	bush_mat.set_shader_parameter("leaf_texture", preload("res://assets/foliage/woodland/shrub_02-color.png"))
	bush_mat.set_shader_parameter("leaf_surface", preload("res://assets/foliage/woodland/shrub_02-surface.png"))
	# (a shader, not a StandardMaterial3D, so that the stones go into cloud shade too)
	stone_mat = ShaderMaterial.new()
	stone_mat.shader = CloudShadow.make(STONE_SHADER)
	stone_mat.set_shader_parameter("stone_color", preload("res://assets/foliage/woodland/rock_moss_set_01-color.png"))
	stone_mat.set_shader_parameter("stone_surface", preload("res://assets/foliage/woodland/rock_moss_set_01-surface.png"))
	request_rebuild(1.2)


func set_deform(t: Texture2DArray) -> void:
	mat.set_shader_parameter("deform_tex", t)
	bush_mat.set_shader_parameter("deform_tex", t)
	if woodland:
		for material in woodland.materials:
			material.set_shader_parameter("deform_tex", t)


func set_trench_mask(t: Texture2D) -> void:
	mat.set_shader_parameter("trench_mask", t)
	bush_mat.set_shader_parameter("trench_mask", t)
	if woodland:
		for material in woodland.materials:
			material.set_shader_parameter("trench_mask", t)


## Marks a blast scar on the grass (craters: full, near misses: lighter).
func scar(p: Vector3, r: float, strength := 1.0) -> void:
	var ri := int(ceil(r)) + 1
	var cx := floori(p.x + HALF)
	var cz := floori(p.z + HALF)
	for z in range(maxi(0, cz - ri), mini(MapDims.N, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(MapDims.N, cx + ri + 1)):
			var d := Vector2(x + 0.5 - HALF - p.x, z + 0.5 - HALF - p.z).length()
			if d > r:
				continue
			var v := strength * clampf(1.2 - d / r, 0.0, 1.0)
			var cur := scar_img.get_pixel(x, z).r
			if v > cur:
				scar_img.set_pixel(x, z, Color(v, v, v))
	_scar_dirty = true


func apply_settings() -> void:
	var lvl := int(Settings.get_v("grass"))
	if lvl != level or int(Settings.get_v("wildlife")) != _wildlife_level:
		request_rebuild(0.1)


func request_rebuild(delay := 1.0) -> void:
	_rebuild_t = delay


func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if atmo.world:
		atmo.world.vp("grass", _t0)


func _view_process(dt: float) -> void:
	if _scar_dirty:
		_scar_dirty = false
		scar_tex.update(scar_img)
	if atmo.world.building or not atmo.world.loaded or not atmo.world.cam:
		return
	if level < 0:
		_rebuild_t = -1.0
		_start_rebuild(true)
	elif _rebuild_t > 0.0:
		_rebuild_t -= dt
		if _rebuild_t <= 0.0:
			_start_rebuild()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_lay_out()
	if level == 0 or _blocked.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	_stream(camera.global_position)
	_build_visible(camera)
	var started := Time.get_ticks_usec()
	var n := 0
	while not _queue.is_empty() and n < 2 and Time.get_ticks_usec() - started < 1000:
		_build_chunk(_queue.pop_front())
		n += 1


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)  # nothing may be left running on a worker
		_task = -1


func _start_rebuild(first_view := false) -> void:
	level = int(Settings.get_v("grass"))
	_wildlife_level = int(Settings.get_v("wildlife"))
	_shrub_noise.seed = int(atmo.world.settings.get("seed", 1)) + 219
	_shrub_noise.frequency = 0.035
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)  # (a rebuild already on its way: redone from now)
		_task = -1
	# The forest floor remains visible with grass disabled.
	_job = _blocked_job()
	if first_view or OS.has_feature("nothreads"):
		_job.run()
		_lay_out()
	else:
		_task = WorkerThreadPool.add_task(_job.run, false, "Grass: bare ground")


## Where grass can't grow is worked out: the old chunks go and the new ones
## queue up, the nearest the camera first.
func _lay_out() -> void:
	_blocked = _job.blocked
	canopy_img = Image.create_from_data(MapDims.N >> 1, MapDims.N >> 1, false, Image.FORMAT_R8, _job.canopy)
	if is_instance_valid(_job.biome):
		atmo.biome_tex.set_image(_job.biome)
	atmo.ground_mat.set_shader_parameter("woodland_ready", woodland != null)
	_job = null
	_clear()


func _stream(pos: Vector3) -> void:
	var center := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if center == _center:
		return
	_center = center
	_queue.clear()
	_bounds.clear()
	for key: Vector2i in _built.keys():
		if absi(key.x - center.x) > REACH + 2 or absi(key.y - center.y) > REACH + 2:
			for node in _built[key]:
				node.queue_free()
			_built.erase(key)
	var nc := int(HALF / CHUNK)
	for x in range(maxi(-nc, center.x - REACH), mini(nc, center.x + REACH + 1)):
		for z in range(maxi(-nc, center.y - REACH), mini(nc, center.y + REACH + 1)):
			var key := Vector2i(x, z)
			if not _built.has(key):
				_queue.append(key)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i): return (a - center).length_squared() < (b - center).length_squared())


## The visible ground first, nearest first. The remaining queue preloads
## around it. A camera cut used to build all of the view at once (a hundred
## chunks, the better part of half a second in one frame); now a frame builds
## what it can in VISIBLE_BUDGET_US and the rest of the view fills in from the
## camera outwards over the next frames.
const VISIBLE_BUDGET_US := 4000


func _build_visible(camera: Camera3D) -> void:
	if _queue.is_empty():
		return
	var started := Time.get_ticks_usec()
	var planes := camera.get_frustum()
	var pos := camera.global_position
	var built: Array[int] = []
	for i in _queue.size():
		if Time.get_ticks_usec() - started > VISIBLE_BUDGET_US:
			break
		var cell: Vector2i = _queue[i]
		var center := Vector3((cell.x + 0.5) * CHUNK, 0, (cell.y + 0.5) * CHUNK)
		if not _bounds.has(cell):
			var box := atmo._ground_chunk_bounds(center, CHUNK).grow(2.0)
			box.position += center
			_bounds[cell] = box
		var bounds: AABB = _bounds[cell]
		# Bushes have the longest draw distance (170 m plus their 12 m fade).
		if pos.distance_squared_to(pos.clamp(bounds.position, bounds.end)) > 182.0 * 182.0:
			continue
		if StructureView.intersects_view(bounds.get_center(), bounds.size * 0.5, planes):
			_build_chunk(cell)
			built.append(i)
	for k in range(built.size() - 1, -1, -1):
		_queue.remove_at(built[k])


func _clear() -> void:
	_bounds.clear()
	for k in _built:
		for node in _built[k]:
			node.hide()
			node.queue_free()
	_built.clear()
	_queue.clear()
	_center = Vector2i(999999, 999999)


var _job: BlockedJob = null  # where grass can't grow, being worked out on a worker thread
var _task := -1


## Where grass can't grow, worked out from what's on the map now: the
## buildings, pavements and roads are copied out here (a few thousand), the
## grid is filled in on a worker thread (a million cells, a quarter of a
## second and more of script that held up a frame).
func _blocked_job() -> BlockedJob:
	var j := BlockedJob.new()
	if is_instance_valid(atmo.biome_img):
		j.biome = atmo.biome_img.duplicate()
	var w := atmo.world
	for st in w.structures:
		if st.gone:
			continue
		if st.skind == "tree":
			j.trees.append(Vector3(st.position.x, 4.0 if st.variant == 1 else 7.0, st.position.z))
		var big: bool = st.skind in ["floor", "fob", "barracks", "factory", "medic_tent", "research", "depot", "helipad", "bunker", "mortar_pit", "hmg_nest", "mg_nest", "at_post", "tunnel", "house_wall", "tall_wall", "concrete_wall", "hesco", "barricade", "ammo_cache", "wreck", "car", "crates", "bridge", "town"]
		if big:
			var cleared: Vector2 = st.foot + Vector2(0.4, 0.4)
			if st.skind == "bunker":
				# The two-metre earth bank buries plants beyond the building walls.
				cleared = cleared.max(Vector2(5.2, 5.2))
			j.boxes.append([Vector2(st.position.x, st.position.z), cleared, float(st.yaw)])
	# sidewalks, squares, gardens and the like
	for e in w.decor:
		if not String(e[0]) in ["walk", "walk_corner", "walk_crossing", "pave", "junction", "soft", "lot_pave", "drive", "path", "garden", "yard"]:
			continue
		var s3: Vector3 = e[3][0] if e[0] == "walk_crossing" else e[3]
		if e[0] == "walk_corner":
			s3 = Vector3(absf(s3.x), 0.12, absf(s3.z))  # (the signs say which corner)
		var c3: Vector3 = e[1]
		j.boxes.append([Vector2(c3.x, c3.z), Vector2(s3.x * 0.5 + 0.2, s3.z * 0.5 + 0.2), float(e[2])])
	# the water, and the sand and mud along its shores
	if w.water and w.water.mask:
		j.water = w.water.mask.get_data()
	for t in 3:
		j.roads.append_array(w.roads[t])
	return j


## 1 m grid of places grass must not grow: building floors, walls, roads.
class BlockedJob:
	var biome: Image
	var trees: Array[Vector3] = []  # x, litter radius, z
	var canopy := PackedByteArray()
	var boxes: Array = []  # [centre, half size, yaw] (x, z)
	var water := PackedByteArray()  # the water mask's pixels (RGBA8)
	var roads: Array = []  # PackedVector3Array polylines
	var blocked := PackedByteArray()

	func run() -> void:
		blocked.resize(MapDims.N * MapDims.N)
		for b in boxes:
			var c: Vector2 = b[0]
			var h: Vector2 = b[1]
			var yaw: float = b[2]
			var r := h.length()
			# (Defs.point_in_obb)
			var a0 := Vector2(cos(yaw), -sin(yaw))
			var a1 := Vector2(sin(yaw), cos(yaw))
			for x in range(floori(c.x - r), floori(c.x + r) + 1):
				for z in range(floori(c.y - r), floori(c.y + r) + 1):
					var d := Vector2(x + 0.5, z + 0.5) - c
					if absf(d.dot(a0)) <= h.x and absf(d.dot(a1)) <= h.y:
						_mark(x, z)
		if water.size() == MapDims.N * MapDims.N * 4:
			for i in MapDims.N * MapDims.N:
				if water[i * 4 + 3] > 0 or water[i * 4 + 1] > 110:
					blocked[i] = 1
		for poly in roads:
			var pts: PackedVector3Array = poly
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var steps := int(a.distance_to(b) / 0.8) + 1
				for k in steps + 1:
					var p := a.lerp(b, float(k) / steps)
					for dx in range(-4, 5):
						for dz in range(-4, 5):
							# Keep clumps from overhanging the 2.9 m carriageway; past
							# it they grow into a track's soil shoulder.
							if dx * dx + dz * dz <= 10:
								_mark(floori(p.x) + dx, floori(p.z) + dz)
		var n := MapDims.N >> 1
		var half := float(MapDims.N) * 0.5
		canopy.resize(n * n)
		for tree: Vector3 in trees:
			for z in range(maxi(0, floori((tree.z - tree.y + half) * 0.5)), mini(n, ceili((tree.z + tree.y + half) * 0.5))):
				for x in range(maxi(0, floori((tree.x - tree.y + half) * 0.5)), mini(n, ceili((tree.x + tree.y + half) * 0.5))):
					if blocked[((z << 1) + 1) * MapDims.N + (x << 1) + 1] != 0:
						continue
					var distance := Vector2(float(x * 2 + 1) - half - tree.x, float(z * 2 + 1) - half - tree.z).length()
					var weight := 1.0 - smoothstep(tree.y * 0.2, tree.y, distance)
					var index := z * n + x
					canopy[index] = mini(255, canopy[index] + int(weight * 215.0))
		if is_instance_valid(biome):
			biome = Grass.pack_biome(biome, Image.create_from_data(n, n, false, Image.FORMAT_R8, canopy))

	func _mark(x: int, z: int) -> void:
		var ix := x + MapDims.N / 2
		var iz := z + MapDims.N / 2
		if ix >= 0 and iz >= 0 and ix < MapDims.N and iz < MapDims.N:
			blocked[iz * MapDims.N + ix] = 1


## Bare ground, where no grass grows (or the grass is off): roads, pavements,
## floors, the water's edge. Before the grass is laid out, nowhere is.
func bare(p: Vector3) -> bool:
	return level == 0 or (not _blocked.is_empty() and _is_blocked(p))


func _near_bare(p: Vector3, r: float) -> bool:
	for d: Vector3 in [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		if _is_blocked(p + d):
			return true
	return false


func _is_blocked(p: Vector3) -> bool:
	var ix := floori(p.x) + MapDims.N / 2
	var iz := floori(p.z) + MapDims.N / 2
	if ix < 0 or iz < 0 or ix >= MapDims.N or iz >= MapDims.N:
		return false
	return _blocked[iz * MapDims.N + ix] == 1


## Share a sampler with biome noise without changing its red channel or CPU image.
static func pack_biome(source: Image, canopy: Image) -> Image:
	var noise: Image = source.duplicate()
	noise.convert(Image.FORMAT_R8)
	var mask: Image = canopy.duplicate()
	mask.resize(noise.get_width(), noise.get_height(), Image.INTERPOLATE_BILINEAR)
	var red := noise.get_data()
	var green := mask.get_data()
	var packed := PackedByteArray()
	packed.resize(red.size() * 2)
	for i in red.size():
		packed[i << 1] = red[i]
		packed[(i << 1) + 1] = green[i]
	return Image.create_from_data(noise.get_width(), noise.get_height(), false, Image.FORMAT_RG8, packed)


func canopy_at(p: Vector3) -> float:
	if canopy_img == null or woodland == null:
		return 0.0
	var x := floori((p.x + HALF) * 0.5)
	var z := floori((p.z + HALF) * 0.5)
	if x < 0 or z < 0 or x >= canopy_img.get_width() or z >= canopy_img.get_height():
		return 0.0
	return canopy_img.get_pixel(x, z).r


func _build_chunk(c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + int(atmo.world.settings.get("seed", 1))
	var origin := Vector3(c.x * CHUNK, 0, c.y * CHUNK)
	var density := 0.45 if level == 1 else 1.0
	var count := int(CHUNK * CHUNK * density)
	var town := atmo.world.town_rect.grow(12.0)
	var xf := []
	var cd := []
	var bushes := []
	var stones := []
	# The ground's moisture on an 8 m lattice over the chunk, read between its
	# corners for each clump (one lookup per clump would cost a frame).
	var wet := PackedFloat32Array()
	wet.resize(WET_CELLS * WET_CELLS)
	for z in WET_CELLS:
		for x in WET_CELLS:
			wet[z * WET_CELLS + x] = atmo.meadow_moisture(origin + Vector3(x, 0, z) * (CHUNK / (WET_CELLS - 1)))
	for i in count:
		var p := origin + Vector3(rng.randf() * CHUNK, 0, rng.randf() * CHUNK)
		if absf(p.x) > HALF + 14.0 or absf(p.z) > HALF + 14.0 or _is_blocked(p):
			continue
		if p.x > HALF - 1.0 and atmo.world.water and not atmo.world.water.coast.is_empty():
			continue  # the sea, past the edge
		var g := atmo.grass_amount(p)
		var m := _wet_at(wet, (p.x - origin.x) / CHUNK, (p.z - origin.z) / CHUNK)
		# Damp ground grows thick, tall grass; a dry crest keeps thin short tufts.
		var shade := canopy_at(p)
		var lush := g * lerpf(0.55, 1.15, m) * lerpf(1.0, 0.16, shade)
		if lush <= 0.001 or rng.randf() > lush * 0.92 + 0.04:
			if rng.randf() < 0.004:
				stones.append(p)
			continue
		var s := rng.randf_range(0.75, 1.3) * (0.65 + 0.5 * g) * lerpf(0.82, 1.15, m)
		# Shorter urban grass exposes the soil and blade texture between clumps.
		var height := 0.45 if atmo.world.town_rect.has_area() and town.has_point(Vector2(p.x, p.z)) else 1.0
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.35) * height, s))
		xf.append(Transform3D(basis, p))
		cd.append(Color(g, rng.randf(), m, 0))
		if rng.randf() < 0.035 and g > 0.6 and _shrub_noise.get_noise_2d(p.x, p.z) > 0.08:
			# grass grows up to a track's edge; a shrub would be cut back from it
			if not _near_bare(p, 1.5):
				bushes.append(p)
		elif rng.randf() < 0.003:
			stones.append(p)
	var nodes := []
	if not xf.is_empty():
		nodes.append(_mm(clump, mat, xf, cd, 105.0 if level == 2 else 75.0))
	if not bushes.is_empty():
		var bx := []
		var bc := []
		for p in bushes:
			var s2 := rng.randf_range(0.7, 1.6)
			bx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2 * rng.randf_range(0.7, 1.0), s2)), p))
			bc.append(Color(rng.randf(), rng.randf(), 0, 0))
		var bn := _mm(bush, bush_mat, bx, bc, 170.0)
		bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		nodes.append(bn)
	if not stones.is_empty():
		var sx := []
		var sc := []
		for p in stones:
			var s3 := rng.randf_range(0.15, 0.4)
			sx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s3, s3 * 0.6, s3)), Vector3(p.x, atmo.world.ground_y(p) + s3 * 0.15, p.z)))
			sc.append(Color(0, 0, 0, 0))
		var sn := _mm(stone, stone_mat, sx, sc, 140.0)
		sn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		nodes.append(sn)
	if woodland:
		woodland.build(self, c, nodes)
	_built[c] = nodes


const WET_CELLS := 5  # moisture lattice points across a chunk (8 m apart)


static func _wet_at(wet: PackedFloat32Array, u: float, v: float) -> float:
	var x := clampf(u, 0.0, 1.0) * (WET_CELLS - 1)
	var z := clampf(v, 0.0, 1.0) * (WET_CELLS - 1)
	var x0 := mini(int(x), WET_CELLS - 2)
	var z0 := mini(int(z), WET_CELLS - 2)
	var i := z0 * WET_CELLS + x0
	return lerpf(lerpf(wet[i], wet[i + 1], x - x0), lerpf(wet[i + WET_CELLS], wet[i + WET_CELLS + 1], x - x0), z - z0)


func _mm(mesh: Mesh, m: Material, xf: Array, cd: Array, vis: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	var deform_bounds := m is ShaderMaterial and is_instance_valid(atmo) and is_instance_valid(atmo.world.terrain)
	var low := INF
	var high := -INF
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_custom_data(i, cd[i])
		if deform_bounds:
			var height: float = atmo.world.terrain.deform_at(xf[i].origin)
			low = minf(low, height)
			high = maxf(high, height)
	if deform_bounds:
		# Local height bounds preserve distance fading even beside much taller mountains.
		var bounds := mm.get_aabb()
		bounds.position.y += low - 5.0
		bounds.size.y += high - low + 10.0
		mm.custom_aabb = bounds
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = vis
	mi.visibility_range_end_margin = 12.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


func _make_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# More narrow, pointed blades keep the previous clump's 90-triangle budget.
	for blade in 30:
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * 0.32
		var base := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var yaw := rng.randf() * TAU
		var side := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.003, 0.008)
		var lean := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.1, 0.3)
		var height := rng.randf_range(0.12, 0.42)
		var middle := base + lean * 0.25 + Vector3(0, height * 0.5, 0)
		var points := [base - side, base + side, middle - side * 0.65, middle + side * 0.65, base + lean + Vector3(0, height, 0)]
		var heights := [0.0, 0.0, 0.5, 0.5, 1.0]
		for index in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, heights[index]))
			st.add_vertex(points[index])
	return st.commit()


func _make_bush() -> ArrayMesh:
	return preload("res://assets/foliage/woodland/shrub_02-0.res")


func _make_stone() -> ArrayMesh:
	# Retain the baked distance LODs; rebuilding surface arrays discards them.
	return preload("res://assets/foliage/woodland/rock_moss_set_01-2.res")


const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 base_col : source_color = vec3(0.14, 0.19, 0.07);
uniform vec3 mid_col : source_color = vec3(0.24, 0.32, 0.14);
uniform vec3 tip_col : source_color = vec3(0.38, 0.45, 0.23);
uniform vec3 dry_col : source_color = vec3(0.55, 0.49, 0.3);
uniform float wind = 0.11;
uniform sampler2D scar : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
#include "res://scripts/game/trench_vegetation.gdshaderinc"
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
// CLOUD_SHADOW

varying float h;
varying float g;
varying float rnd;
varying float wet;
varying float burnt;
#ifdef CLOUD_PATTERN
varying float cloud_v;  // the sunlight the clouds let through at the blade
#endif

void vertex() {
	h = UV.y;
	g = INSTANCE_CUSTOM.r;
	rnd = INSTANCE_CUSTOM.g;
	wet = INSTANCE_CUSTOM.b;
	vec3 o = MODEL_MATRIX[3].xyz;
#ifdef CLOUD_PATTERN
	cloud_v = cloud_sun(o);
#endif
	// shell holes and blast scars flatten and scorch the grass
	burnt = texture(scar, (o.xz + __MAP_HALF__) / __MAP_SIZE__).r;
	// nothing grows in a trench
	if (trench_disturbed(trench_mask, (o.xz + __MAP_HALF__) / __MAP_SIZE__, 0.85 / __MAP_SIZE__) > 0.1) {
		VERTEX *= 0.0;
	}
	VERTEX.y *= 1.0 - burnt * 0.85;
	VERTEX.xz *= 1.0 + burnt * 0.4;
	// stand on the ground as it is now (shell holes, rims)
	VERTEX.y += terrain_height(deform_tex, (o.xz + __MAP_HALF__) / __MAP_SIZE__) / max(0.05, length(MODEL_MATRIX[1].xyz));
	float t = TIME * 1.7 + o.x * 0.21 + o.z * 0.13;
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + o.x * 0.02 + o.z * 0.015);
	float sway = (sin(t) + 0.45 * sin(t * 2.7 + 1.3)) * wind * gust * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
}

void fragment() {
	// blades are lit as if they faced the sky from both sides: the engine flips
	// back faces' normals, which turned half of every blade black
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col = mix(base_col, mid_col, smoothstep(0.0, 0.5, h));
	col = mix(col, tip_col, smoothstep(0.45, 1.0, h));
	// Tips cure to straw where the ground dries out, as the turf beneath them does.
	float cured = clamp((1.0 - wet) * 0.8 + (1.0 - g) * 0.4 + (rnd - 0.7) * 0.6 - 0.08, 0.0, 0.9);
	col = mix(col, dry_col, cured * smoothstep(0.2, 1.0, h));
	col *= mix(1.0, 0.86, wet) * (0.85 + 0.3 * rnd);
	col = mix(col, vec3(0.09, 0.075, 0.05), burnt * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.35, 0.4, 0.15) * h * (1.0 - burnt);
	AO = mix(0.78, 1.0, h);
	AO_LIGHT_AFFECT = 0.6;
	// CLOUD_FRAGMENT cloud_v
}
"""

const BUSH_SHADER := """
shader_type spatial;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_surface : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float wind = 0.03;
render_mode specular_disabled, cull_disabled;
varying float plant_height;
varying float rnd;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
#include "res://scripts/game/trench_vegetation.gdshaderinc"
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
// CLOUD_SHADOW
#ifdef CLOUD_PATTERN
varying float cloud_v;
#endif
void vertex() {
	VERTEX.y += 0.65;
#ifdef CLOUD_PATTERN
	cloud_v = cloud_sun(MODEL_MATRIX[3].xyz);
#endif
	if (trench_disturbed(trench_mask, (MODEL_MATRIX[3].xz + __MAP_HALF__) / __MAP_SIZE__, 0.85 / __MAP_SIZE__) > 0.1) {
		VERTEX *= 0.0;
	}
	float gd = terrain_height(deform_tex, (MODEL_MATRIX[3].xz + __MAP_HALF__) / __MAP_SIZE__);
	if (gd - terrain_geology(deform_tex, (MODEL_MATRIX[3].xz + __MAP_HALF__) / __MAP_SIZE__) < -0.12) {
		VERTEX *= 0.0;  // blown away
	}
	float plant_y = VERTEX.y;
	VERTEX.y += gd / max(0.05, length(MODEL_MATRIX[1].xyz));
	rnd = INSTANCE_CUSTOM.r;
	vec3 o = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.3 + o.x * 0.3;
	VERTEX.x += sin(t) * wind * plant_y;
	plant_height = plant_y;
}
void fragment() {
	vec4 photograph = texture(leaf_texture, UV);
	ALPHA = photograph.a;
	ALPHA_SCISSOR_THRESHOLD = 0.25;
	if (OUTPUT_IS_SRGB) {
		photograph.rgb = mix(photograph.rgb / 12.92, pow((photograph.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), photograph.rgb));
	}
	float up = smoothstep(0.0, 1.1, plant_height);
	vec3 col = photograph.rgb * mix(vec3(0.7, 0.85, 0.7), vec3(1.0, 0.9, 0.65), rnd) * mix(0.65, 1.0, up);
	if (OUTPUT_IS_SRGB) {
		col = mix(col * 12.92, 1.055 * pow(max(col, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), col));
	}
	ALBEDO = col;
	vec4 detail = texture(leaf_surface, UV);
	NORMAL_MAP = vec3(detail.rg, 1.0);
	NORMAL_MAP_DEPTH = 0.4;
	ROUGHNESS = clamp(detail.a, 0.65, 1.0);
	AO = detail.b * (0.6 + 0.4 * up);
	AO_LIGHT_AFFECT = 0.5;
	// Keep the engine's two-sided normal, with both leaf faces receiving skylight.
	vec3 leaf_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	leaf_normal.y = abs(leaf_normal.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(leaf_normal, vec3(0.0, 1.0, 0.0), 0.45), 0.0)).xyz);
	BACKLIGHT = vec3(0.08, 0.1, 0.035);
	// CLOUD_FRAGMENT cloud_v
}
"""

## Scanned stones share the woodland geology and cloud lighting.
const STONE_SHADER := """
shader_type spatial;
uniform sampler2D stone_color : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_surface : hint_normal, filter_linear_mipmap_anisotropic;
// CLOUD_SHADOW
varying vec3 wpos;
void vertex() {
	VERTEX.y -= 0.25; // The established scatter origin sits slightly above the soil.
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 photograph = texture(stone_color, UV);
	ALBEDO = photograph.rgb;
	vec4 detail = texture(stone_surface, UV);
	NORMAL_MAP = vec3(detail.rg, 1.0);
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = clamp(detail.a, 0.65, 1.0);
	AO = detail.b;
	AO_LIGHT_AFFECT = 0.5;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""
