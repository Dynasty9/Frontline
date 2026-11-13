class_name LightProbes
extends Node
## A grid of light probes over the battlefield: how much sky each point can
## see, from which way, and how much sunlight the walls, roofs and ground
## round it throw back. A street between two rows of houses sees a strip of
## sky, so its walls and cobbles take less of the skylight than a meadow does,
## and the sunlit side throws a warm glow across onto the shaded one. Inside a
## house the roof hides the sky altogether: what light there is comes in
## through the windows and doors, off the sunlit ground outside.
##
## Screen-space occlusion (SSAO) sees only what's on screen and a metre or so
## round each pixel; this sees whole streets and rooms, whether or not they're
## in view, and costs a handful of texture reads a pixel rather than a pass
## over the screen.
##
## The probes are few and the pixels many, so the probes are kept small and
## the pixels rebuild the light from them:
##
##  - The scene, as the probes see it, is a coarse block model: every
##    structure's boxes (walls, roofs, floors, sandbags, wrecks; tree crowns
##    and nets half see-through) laid into 1 m cubes up to 16 m above the
##    ground (`voxels`, a texture array of 64 m tiles). The ground itself is
##    the terrain's own height texture, craters and all.
##  - A probe every 2 m across the map, at eight heights 2 m apart following
##    the lie of the land, traces 32 rays (16 on Low) through that model on
##    the GPU (BAKE_SHADER). It keeps 8 bytes: the share of rays that reach
##    the sky and their mean direction (the first two spherical-harmonic
##    bands of what it can see, which is also its bent normal), and the mean
##    light off whatever stopped the others. The open ground under the open
##    sky counts as seen: the sky's own lower half already stands for it, so
##    an open field comes out exactly as it did without the probes.
##  - A pixel reads the probes round it (hardware-filtered, five reads; two on
##    Low), offset along its normal so it reads the air in front of a wall
##    rather than the wall, and turns the bands into the cosine-weighted share
##    of sky its own normal sees: on Low by the exact formula for the two
##    bands kept, on High through a tiny network with baked weights that
##    learned to read more out of them (PIXEL). That multiplies the skylight
##    (AO), and the rest of its view, lit by the bounce, comes back as a
##    little emission.
##
## The probes change only where the scene does. A structure built, blown down
## or burnt away marks its 64 m tile; the tile's cubes are laid again on the
## CPU (a few milliseconds) and the probes within reach of it traced again,
## two tiles' worth a frame, nearest the camera first. A crater does the same
## a moment later, once its heights are up on the GPU, and a new time of day
## traces the lot again (the bounce follows the sun). Tiles with nothing in
## reach aren't traced at all: they're written as open sky.
##
## It's light and nothing else: no gameplay reads it, it never touches the
## world's random numbers, and the server never builds it. The Light probes
## setting turns it off (and the browser, which draws per vertex, gets the
## two-read Low version).

## Voxels across the map (MapDims.N metres): 1 m cubes on the standard map,
## 2 m and 3 m on the larger ones, so the grid keeps its size and cost.
const NV := 1024
const TILE := 64  # voxels a side in a tile
const TILES := NV / TILE  # tiles across
const VH := 16  # voxel layers above the ground
const P := NV / 2  # probe columns across (one every two voxels)
const LAYERS := 8  # probe heights, two voxels apart
const BRICK := TILE / 2  # probe columns across a tile
## The probe atlas: the eight heights side by side, the visibility above the
## bounce, and below them the height the columns stand on (for the pixels).
const ATLAS := Vector2i(P * LAYERS, P * 3)

## How far rays reach (in voxels, BAKE_SHADER's 18 steps of 0.9): a tile's
## probes see into the next tile but no further.
const REACH := 16.0

## How much light the bounce gives back, and how far the sky occlusion
## darkens, at full strength: the bounce errs low, since SSIL adds its own
## near the camera on High and above.
const AO_STRENGTH := 1.0
const BOUNCE_STRENGTH := 0.8

## Time budget for laying tiles each frame, and how many tiles of probes are
## traced a frame (each is 32x32 columns at 8 heights, visibility and bounce).
const LAY_BUDGET_US := 3000
const BAKES_PER_FRAME := 2
const BAKES_PER_FRAME_WEB := 1
## A crater's heights take a few frames to reach the GPU (Atmosphere._update_deform).
const DEFORM_DELAY := 0.6

var atmo  # Atmosphere
var world: World
var quality := 0  # 0 off, 1 low (AO only, nearest height), 2 high

var _vsz := 1.0  # voxel size, metres
var _ready_size := -1  # the landform's sample count when the grid was laid out (clients get theirs late)
var _voxels: Texture2DArray
var _tile_full := PackedByteArray()  # 1: the tile has something in it
var _tile_dirty := PackedByteArray()  # 1: queued for laying
var _tile_queue: Array[int] = []
var _brick_dirty := PackedByteArray()
var _brick_queue: Array[int] = []
var _late: Array = []  # [seconds left, tile] waiting for a crater's heights
var _vp: SubViewport
var _bake: Node2D
var _fill: Node2D
var _bake_mat: ShaderMaterial
var _fill_mat: ShaderMaterial
var _base_drawn := false
var traced := 0  # bricks traced so far (tests, diagnostics)
var laid := 0  # tiles laid so far
var _ab := false
var _trench_tex: Texture2D
var _cycle := 0

static var _globals := false


## Wanted at all here: a view, and the setting on.
static func level() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	return clampi(int(Settings.get_v("light_probes")), 0, 2)


func setup(a) -> void:
	atmo = a
	world = a.world
	name = "LightProbes"
	_vsz = MapDims.SIZE / NV
	_ensure_globals()
	apply_settings()


func apply_settings() -> void:
	var q := level()
	if q == quality and _vp != null:
		return
	var was := quality
	quality = q
	_publish()
	if quality == 0:
		return
	if _vp == null:
		_build()
	elif (was == 1) != (quality == 1):
		# Low traces fewer rays and no bounce: trace it all again
		_requeue_all_bricks()
	if _bake_mat:
		_bake_mat.set_shader_parameter("rays", 16.0 if quality == 1 else 32.0)
		_bake_mat.set_shader_parameter("bounce", quality >= 2)


## The sun moved or the weather changed: the bounce follows the light.
func relight() -> void:
	if _bake_mat == null:
		return
	_set_light()
	_requeue_all_bricks()


## A structure appeared, went or moved: its tiles are laid again.
func structure_changed(st: Structure) -> void:
	if _ready_size < 0 or st == null:
		return
	var r := st.radius + 4.0  # (a tree's crown spreads well past its trunk)
	_mark_area(Rect2(st.position.x - r, st.position.z - r, r * 2.0, r * 2.0))


## The trench network changed (TrenchNet.rebuild): its mask goes to the
## tracer, and the probes round what changed (area, in metres; empty for the
## first network or a whole new one) are traced again.
func trench_changed(tex: Texture2D, area: Rect2) -> void:
	_trench_tex = tex
	for m: ShaderMaterial in [_bake_mat, _fill_mat]:
		if m:
			m.set_shader_parameter("trench_mask", tex)
	if _ready_size < 0:
		return
	if area.size == Vector2.ZERO:
		_requeue_all_bricks()
		return
	for t in _tiles_in(area.grow(REACH * _vsz)):
		_queue_brick(t)


## The ground changed (a crater, in metres of the deformation grid): the
## probes in reach of it are traced again once the heights are on the GPU.
func terrain_changed(cells: Rect2i) -> void:
	if _ready_size < 0:
		return
	var m := MapDims.N / float(NV)  # deformation cells (1 m) per voxel
	var t0 := Vector2i(floori(cells.position.x / m / TILE), floori(cells.position.y / m / TILE))
	var t1 := Vector2i(floori(cells.end.x / m / TILE), floori(cells.end.y / m / TILE))
	for tz in range(maxi(t0.y, 0), mini(t1.y, TILES - 1) + 1):
		for tx in range(maxi(t0.x, 0), mini(t1.x, TILES - 1) + 1):
			_late.append([DEFORM_DELAY, tz * TILES + tx])


func _process(dt: float) -> void:
	if quality == 0 or world == null or world.terrain == null or atmo.deform_tex == null:
		return
	var lf: Landform = world.terrain.landform
	var size := lf.heights.size() if lf else 0
	if size != _ready_size:
		_start(size)
	for i in range(_late.size() - 1, -1, -1):
		_late[i][0] = float(_late[i][0]) - dt
		if float(_late[i][0]) <= 0.0:
			_touch_bricks_round(int(_late[i][1]), false)
			_late.remove_at(i)
	if OS.has_environment("FL_DEBUG_PROBES_BENCH") and _vp:
		_bench()
	if OS.get_environment("FL_DEBUG_PROBES_AB") == "cycle" and _vp:
		# FL_DEBUG_PROBES_AB=cycle: off, on, the probes' term, the bent normal, three
		# frames each, round and round: four panels of one moment from frames in a row
		var phase := (_cycle / 3) % 4
		_cycle += 1
		RenderingServer.global_shader_parameter_set("probe_grid", Vector4(MapDims.HALF, _vsz * 2.0, 0.0 if phase == 0 else float(quality), 0.0))
		RenderingServer.global_shader_parameter_set("probe_mix", Vector4(AO_STRENGTH, BOUNCE_STRENGTH, [0.0, 0.0, 1.0, 3.0][phase], 0.0))
	elif OS.has_environment("FL_DEBUG_PROBES_AB") and _vp:
		# FL_DEBUG_PROBES_AB=1: the probes on and off on alternate frames, for a
		# before-and-after of one moment from two frames in a row (two runs of a
		# seed don't build the same town, and the clouds move on between shots)
		_ab = not _ab
		if OS.get_environment("FL_DEBUG_PROBES_AB") != "ssil":
			RenderingServer.global_shader_parameter_set("probe_grid", Vector4(MapDims.HALF, _vsz * 2.0, float(quality) if _ab else 0.0, 0.0))
	var t0 := Time.get_ticks_usec()
	while not _tile_queue.is_empty() and Time.get_ticks_usec() - t0 < LAY_BUDGET_US:
		_lay(_tile_queue.pop_front())
	_bake_some()


## FL_DEBUG_PROBES_BENCH=<frames> (with FL_DEBUG_PROBES_AB=1, or =ssil to
## flip screen-space indirect light instead): the GPU time of frames with the
## thing on and off, interleaved so a busy machine weighs on both alike; and
## the atlas pass's own GPU time on frames that traced probes.
func _bench() -> void:
	var main_vp := get_viewport().get_viewport_rid()
	if not has_meta("bench"):
		set_meta("bench", [[], [], []])
		RenderingServer.viewport_set_measure_render_time(main_vp, true)
		RenderingServer.viewport_set_measure_render_time(_vp.get_viewport_rid(), true)
	var b: Array = get_meta("bench")
	if OS.get_environment("FL_DEBUG_PROBES_AB") == "ssil":
		atmo.env.ssil_enabled = not atmo.env.ssil_enabled
	var bake_ms := RenderingServer.viewport_get_measured_render_time_gpu(_vp.get_viewport_rid())
	if _vp.render_target_update_mode == SubViewport.UPDATE_ONCE or bake_ms > 0.0:
		(b[2] as Array).append([bake_ms, traced])
	if _brick_queue.is_empty() and _tile_queue.is_empty():
		(b[1 if _ab else 0] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(main_vp))
	var n := int(OS.get_environment("FL_DEBUG_PROBES_BENCH"))
	if (b[0] as Array).size() >= n and (b[1] as Array).size() >= n and not has_meta("benched"):
		set_meta("benched", true)
		for i in 2:
			var a: Array = b[i]
			a.sort()
			print("PROBES BENCH parity %d: median %.3f ms, mean %.3f ms over %d frames" % [i, a[a.size() / 2], a.reduce(func(x, y): return x + y, 0.0) / a.size(), a.size()])
		print("PROBES BENCH atlas pass (ms, tiles traced so far): ", b[2])
		get_tree().quit()


# --- the grid -------------------------------------------------------------------------

func _build() -> void:
	_voxels = Texture2DArray.new()
	var blank := Image.create(TILE, TILE * VH, false, Image.FORMAT_R8)
	var layers: Array[Image] = []
	for i in TILES * TILES:
		layers.append(blank)
	_voxels.create_from_images(layers)
	_tile_full.resize(TILES * TILES)
	_tile_dirty.resize(TILES * TILES)
	_brick_dirty.resize(TILES * TILES)
	_vp = SubViewport.new()
	_vp.name = "ProbeAtlas"
	_vp.size = ATLAS
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.use_hdr_2d = false
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var sh := Shader.new()
	sh.code = BAKE_SHADER.replace("__TILE__", "%d.0" % TerrainTexture.TILE)
	_bake_mat = ShaderMaterial.new()
	_bake_mat.shader = sh
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = sh
	for m: ShaderMaterial in [_bake_mat, _fill_mat]:
		m.set_shader_parameter("voxels", _voxels)
		m.set_shader_parameter("map_half", MapDims.HALF)
		m.set_shader_parameter("vsz", _vsz)
	_fill_mat.set_shader_parameter("mode", 0.0)
	for m: ShaderMaterial in [_bake_mat, _fill_mat]:
		m.set_shader_parameter("trench_floor", TrenchNet.FLOOR_Y)
		if _trench_tex:
			m.set_shader_parameter("trench_mask", _trench_tex)
	_bake_mat.set_shader_parameter("mode", 1.0)
	_fill = _Rects.new()
	_fill.material = _fill_mat
	_vp.add_child(_fill)
	_bake = _Rects.new()
	_bake.material = _bake_mat
	_vp.add_child(_bake)
	_set_light()
	_publish()


## Starts over: every tile with something in it laid, every column written.
func _start(size: int) -> void:
	_ready_size = size
	_tile_full.fill(0)
	_tile_dirty.fill(0)
	_tile_queue.clear()
	_brick_dirty.fill(0)
	_brick_queue.clear()
	_base_drawn = false
	# (a network dug before the probes existed never told them)
	if _trench_tex == null and atmo.trench_net:
		_trench_tex = atmo.trench_net.tex
	for m: ShaderMaterial in [_bake_mat, _fill_mat]:
		m.set_shader_parameter("heights", atmo.deform_tex)
		if _trench_tex:
			m.set_shader_parameter("trench_mask", _trench_tex)
	var seen := PackedByteArray()
	seen.resize(TILES * TILES)
	for st: Structure in world.structures:
		if is_instance_valid(st) and not st.gone:
			var r := st.radius + 4.0
			for t in _tiles_in(Rect2(st.position.x - r, st.position.z - r, r * 2.0, r * 2.0)):
				seen[t] = 1
	for t in TILES * TILES:
		if seen[t]:
			_queue_tile(t)
		_queue_brick(t)


func _requeue_all_bricks() -> void:
	if _ready_size < 0:
		return
	for t in TILES * TILES:
		_queue_brick(t)


func _publish() -> void:
	RenderingServer.global_shader_parameter_set("probe_grid", Vector4(MapDims.HALF, _vsz * 2.0, float(quality) if _vp else 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("probe_mix", Vector4(AO_STRENGTH, BOUNCE_STRENGTH, float(OS.get_environment("FL_DEBUG_PROBES_VIEW")) if OS.has_environment("FL_DEBUG_PROBES_VIEW") else 0.0, 0.0))
	if _vp:
		RenderingServer.global_shader_parameter_set("probe_atlas", _vp.get_texture())


func _set_light() -> void:
	var sun: DirectionalLight3D = atmo.sun
	var to_sun := sun.global_transform.basis.z.normalized() if sun.is_inside_tree() else sun.basis.z.normalized()
	var d: Dictionary = atmo._d
	var sun_c: Color = (d.sun as Color).srgb_to_linear() * float(d.energy)
	var sky_c: Color = ((d.zenith as Color).lerp(d.horizon as Color, 0.6)).srgb_to_linear() * float(d.ambient)
	_bake_mat.set_shader_parameter("sun_dir", to_sun)
	_bake_mat.set_shader_parameter("sun_col", Vector3(sun_c.r, sun_c.g, sun_c.b))
	_bake_mat.set_shader_parameter("sky_col", Vector3(sky_c.r, sky_c.g, sky_c.b))


func _tiles_in(r: Rect2) -> Array[int]:
	var out: Array[int] = []
	var tw := TILE * _vsz
	var x0 := clampi(floori((r.position.x + MapDims.HALF) / tw), 0, TILES - 1)
	var x1 := clampi(floori((r.end.x + MapDims.HALF) / tw), 0, TILES - 1)
	var z0 := clampi(floori((r.position.y + MapDims.HALF) / tw), 0, TILES - 1)
	var z1 := clampi(floori((r.end.y + MapDims.HALF) / tw), 0, TILES - 1)
	for tz in range(z0, z1 + 1):
		for tx in range(x0, x1 + 1):
			out.append(tz * TILES + tx)
	return out


func _mark_area(r: Rect2) -> void:
	for t in _tiles_in(r):
		_queue_tile(t)


func _queue_tile(t: int) -> void:
	if _tile_dirty[t] == 0:
		_tile_dirty[t] = 1
		_tile_queue.append(t)


func _queue_brick(b: int) -> void:
	if _brick_dirty[b] == 0:
		_brick_dirty[b] = 1
		_brick_queue.append(b)


## The tile and its neighbours (whose probes reach into it) are traced again.
## Bricks with nothing in reach are only written as open sky, so a crater out
## in the fields costs nothing.
func _touch_bricks_round(t: int, always := true) -> void:
	var tx := t % TILES
	var tz := t / TILES
	for z in range(maxi(tz - 1, 0), mini(tz + 1, TILES - 1) + 1):
		for x in range(maxi(tx - 1, 0), mini(tx + 1, TILES - 1) + 1):
			var b := z * TILES + x
			if always or _in_reach(b):
				_queue_brick(b)


func _in_reach(b: int) -> bool:
	var bx := b % TILES
	var bz := b / TILES
	for z in range(maxi(bz - 1, 0), mini(bz + 1, TILES - 1) + 1):
		for x in range(maxi(bx - 1, 0), mini(bx + 1, TILES - 1) + 1):
			if _tile_full[z * TILES + x]:
				return true
	return false


# --- laying the cubes -----------------------------------------------------------------

## Lays tile t's cubes from the structures standing in it. Each byte is a
## cube: how much light it stops (high four bits) and how much it throws back
## (low four, its albedo).
func _lay(t: int) -> void:
	_tile_dirty[t] = 0
	laid += 1
	var tx := t % TILES
	var tz := t / TILES
	var tw := TILE * _vsz
	var ox := tx * tw - MapDims.HALF
	var oz := tz * tw - MapDims.HALF
	var bytes := PackedByteArray()
	bytes.resize(TILE * TILE * VH)
	var lf: Landform = world.terrain.landform
	var geo := PackedFloat32Array()
	geo.resize(TILE * TILE)
	for z in TILE:
		for x in TILE:
			geo[z * TILE + x] = lf.height(Vector3(ox + (x + 0.5) * _vsz, 0, oz + (z + 0.5) * _vsz))
	var any := false
	var c := Vector3(ox + tw * 0.5, 0, oz + tw * 0.5)
	for st in world.structures_near(c, tw * 0.75 + 6.0):
		var s: Structure = st
		for box in _boxes(s):
			var took := _rasterize(box, ox, oz, geo, bytes)
			if took:
				any = true
			if OS.has_environment("FL_DEBUG_PROBES_TRACE"):
				print("LAY t=%d %s %s %s took=%s" % [t, s.skind, s.position, (box[0] as Transform3D).origin, took])
	if any and OS.has_environment("FL_DEBUG_PROBES_TILES"):
		# FL_DEBUG_PROBES_TILES=<dir>: each laid tile's cubes and ground, for offline study
		var dir := OS.get_environment("FL_DEBUG_PROBES_TILES")
		FileAccess.open(dir.path_join("tile_%d.bin" % t), FileAccess.WRITE).store_buffer(bytes)
		FileAccess.open(dir.path_join("geo_%d.bin" % t), FileAccess.WRITE).store_buffer(geo.to_byte_array())
	var was := _tile_full[t] == 1
	_tile_full[t] = 1 if any else 0
	if any or was:
		_voxels.update_layer(Image.create_from_data(TILE, TILE * VH, false, Image.FORMAT_R8, bytes), t)
	_touch_bricks_round(t, any or was)


## The boxes a structure blocks light with: [world transform of its centre,
## half extents, how much it stops 0..1, albedo]. Its parts, as bullets see
## them, plus what only looks solid: roofs, tree crowns, nets.
func _boxes(st: Structure) -> Array:
	var out := []
	if st.gone:
		return out
	var xf := Transform3D(Basis(Vector3.UP, st.yaw), st.position)
	match st.skind:
		"roof":
			var h := st.size.y
			out.append([xf * Transform3D(Basis(), Vector3(0, h + 0.15, 0)), Vector3(st.size.x * 0.5 + 0.3, 0.2, st.size.z * 0.5 + 0.3), 1.0, 0.18])
			if st.variant % 2 == 0:
				# pitched: the attic's wedge, as a box two thirds as wide and a third as high
				var long_x := st.size.x >= st.size.z
				var w := minf(st.size.x, st.size.z)
				var rise := w * 0.5 * tan(deg_to_rad(28.0))
				var half := Vector3(st.size.x * 0.5, rise / 3.0, w / 3.0) if long_x else Vector3(w / 3.0, rise / 3.0, st.size.z * 0.5)
				out.append([xf * Transform3D(Basis(), Vector3(0, h + 0.35 + rise / 3.0, 0)), half, 1.0, 0.18])
			return out
		"tree":
			if not st.burnt:
				out.append([xf * Transform3D(Basis(), Vector3(0, 4.6, 0)), Vector3(2.3, 2.1, 2.3), 0.35, 0.1])
		"camo_net":
			out.append([xf * Transform3D(Basis(), Vector3(0, 2.0, 0)), Vector3(maxf(st.size.x, 4.0) * 0.5, 0.15, maxf(st.size.z, 4.0) * 0.5), 0.55, 0.14])
			return out
		"wire", "mines":
			return out
	for p: Dictionary in st.parts:
		var s: Vector3 = p.s
		var top: float = (p.p as Vector3).y + s.y * 0.5
		if s.y < 0.05 or top < 0.35:
			# a floor slab, a kerb, a doorstep: the ground, as far as the sky is
			# concerned (laid as cubes, it would shut out the lower half of every
			# room and leave the sky's own ground half counted twice)
			continue
		var col: Color = p.get("color", Color(0.5, 0.5, 0.5))
		out.append([xf * Transform3D(Basis(Vector3.UP, float(p.get("r", 0.0))), p.p), s * 0.5, 1.0, col.srgb_to_linear().get_luminance()])
	return out


## Lays one box into the tile's bytes; true if any cube took it.
func _rasterize(box: Array, ox: float, oz: float, geo: PackedFloat32Array, bytes: PackedByteArray) -> bool:
	var bxf: Transform3D = box[0]
	var half: Vector3 = box[1]
	# a thin wall still fills the cubes it passes through, but a window in it
	# stays open: only the thin way is fattened to a cube
	var e := Vector3(maxf(half.x, _vsz * 0.51), maxf(half.y, _vsz * 0.51), maxf(half.z, _vsz * 0.51))
	var b := bxf.basis.orthonormalized()
	var inv := b.transposed()
	var reach := absf(b.x.x) * e.x + absf(b.y.x) * e.y + absf(b.z.x) * e.z
	var reach_z := absf(b.x.z) * e.x + absf(b.y.z) * e.y + absf(b.z.z) * e.z
	var reach_y := absf(b.x.y) * e.x + absf(b.y.y) * e.y + absf(b.z.y) * e.z
	var c := bxf.origin
	var x0 := maxi(floori((c.x - reach - ox) / _vsz), 0)
	var x1 := mini(floori((c.x + reach - ox) / _vsz), TILE - 1)
	var z0 := maxi(floori((c.z - reach_z - oz) / _vsz), 0)
	var z1 := mini(floori((c.z + reach_z - oz) / _vsz), TILE - 1)
	if x0 > x1 or z0 > z1:
		return false
	var dens := clampi(roundi(float(box[2]) * 15.0), 1, 15)
	var alb := clampi(roundi(float(box[3]) / 0.8 * 15.0), 1, 15)
	var code := dens * 16 + alb
	var hit := false
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var g: float = geo[z * TILE + x]
			var y0 := maxi(floori((c.y - reach_y - g) / _vsz), 0)
			var y1 := mini(floori((c.y + reach_y - g) / _vsz), VH - 1)
			if y0 > y1:
				continue
			var px := ox + (x + 0.5) * _vsz
			var pz := oz + (z + 0.5) * _vsz
			for y in range(y0, y1 + 1):
				var l := inv * (Vector3(px, g + (y + 0.5) * _vsz, pz) - c)
				if absf(l.x) > e.x or absf(l.y) > e.y or absf(l.z) > e.z:
					continue
				var i := (y * TILE + z) * TILE + x
				if (bytes[i] >> 4) < dens:
					bytes[i] = code
				hit = true
	return hit


# --- tracing the probes ---------------------------------------------------------------

## Traces the next few tiles of probes, nearest the camera first, once every
## tile is laid (a probe traced through half-laid cubes would only need doing
## again).
func _bake_some() -> void:
	if not _tile_queue.is_empty() and _base_drawn:
		return
	var fill_rects: Array[Rect2] = []
	var bake_rects: Array[Rect2] = []
	if not _base_drawn:
		# the heights the columns stand on, once, and every column open sky
		_base_drawn = true
		fill_rects.append(Rect2(Vector2.ZERO, Vector2(ATLAS)))
	if _tile_queue.is_empty() and not _brick_queue.is_empty():
		_sort_bricks()
		var n := BAKES_PER_FRAME_WEB if OS.has_feature("web") else BAKES_PER_FRAME
		while not _brick_queue.is_empty():
			var b: int = _brick_queue.pop_front()
			_brick_dirty[b] = 0
			var traced_now := _in_reach(b)
			var bx := (b % TILES) * BRICK
			var bz := (b / TILES) * BRICK
			for block in 2:
				for layer in LAYERS:
					var r := Rect2(layer * P + bx, block * P + bz, BRICK, BRICK)
					if traced_now:
						bake_rects.append(r)
					else:
						fill_rects.append(r)
			# and the heights its columns stand on (a crater or trench may have moved them)
			(bake_rects if traced_now else fill_rects).append(Rect2(bx, 2 * P + bz, BRICK, BRICK))
			if traced_now:
				traced += 1
				n -= 1
				if n <= 0:
					break
	if fill_rects.is_empty() and bake_rects.is_empty():
		if OS.has_environment("FL_DEBUG_PROBES") and _brick_queue.is_empty() and not has_meta("dumped"):
			# FL_DEBUG_PROBES=<png>: the atlas, once everything is traced
			set_meta("dumped", true)
			_vp.get_texture().get_image().save_png(OS.get_environment("FL_DEBUG_PROBES"))
			print("PROBES traced=%d laid=%d atlas saved" % [traced, laid])
		return
	(_fill as _Rects).rects = fill_rects
	(_bake as _Rects).rects = bake_rects
	_fill.queue_redraw()
	_bake.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## The camera's own tiles first: what the player is looking at fills in first.
func _sort_bricks() -> void:
	if world.cam == null or _brick_queue.size() < 2:
		return
	var f: Vector3 = world.cam.focus_pos
	var tw := TILE * _vsz
	var fc := Vector2((f.x + MapDims.HALF) / tw - 0.5, (f.z + MapDims.HALF) / tw - 0.5)
	_brick_queue.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(a % TILES, a / TILES).distance_squared_to(fc) < Vector2(b % TILES, b / TILES).distance_squared_to(fc))


## Draws the rectangles it's given, nothing else: the shader works out which
## probe each pixel is from where it is.
class _Rects extends Node2D:
	var rects: Array[Rect2] = []

	func _draw() -> void:
		for r in rects:
			draw_rect(r, Color.WHITE)


# --- the shaders ------------------------------------------------------------------------

static func _ensure_globals() -> void:
	if _globals:
		return
	_globals = true
	# (added here rather than in project.godot: they're this file's alone, and
	# the static flag keeps a second battle from adding them again)
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.5, 0.5, 0.5, 1.0))
	RenderingServer.global_shader_parameter_add(&"probe_atlas", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, ImageTexture.create_from_image(img))
	RenderingServer.global_shader_parameter_add(&"probe_grid", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(512, 2, 0, 0))
	RenderingServer.global_shader_parameter_add(&"probe_mix", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1, 1, 0, 0))


## A surface shader (one CloudShadow makes with its PROBES flag) taking its
## skylight and bounce from the probes: the reads go in among its uniforms,
## the use at the end of its fragment(), with the albedo and normal final.
static func inject(src: String) -> String:
	_ensure_globals()
	var out := src.replace("// CLOUD_SHADOW", PIXEL + "\n// CLOUD_SHADOW")
	return out.replace("// CLOUD_FRAGMENT ", PIXEL_USE + "\t// CLOUD_FRAGMENT ")


## What a pixel does with the probes round it. A probe keeps the share of sky
## it sees (m0) and the mean direction it sees it in, weighted by how much it
## sees (m1): the first two spherical-harmonic bands of its view. With only
## those two bands, the share a surface facing n sees, weighted by the cosine
## as light falls, comes out as m0 + 2 m1.n (half the sky over flat ground: 1
## facing up, 1/2 facing sideways, 0 facing down, as it should). That's what
## Low does. High hands the same eight numbers, its normal and where it stands
## between the probes to a tiny network (10 inputs, 16 hidden, 1 out: 176
## multiply-adds and 16 tanh a pixel) trained offline against sky occlusion
## traced from every pixel itself: on two towns it hadn't seen it came within
## 0.08 of the traced answer where the formula came within 0.13, closer than
## the formula does from probes twice as dense (see the pull request). Its
## weights are below, fitted with numpy on dumps of the
## cubes (FL_DEBUG_PROBES_TILES). What a pixel doesn't see is lit by the
## bounce, the mean light off whatever is in the way. Reads are offset 0.6 of a
## probe out along the normal (the air in front of a wall, not the wall), and
## fade out above the top probes and at the map's edge.
const PIXEL := """
global uniform sampler2D probe_atlas : filter_linear, repeat_disable;
global uniform vec4 probe_grid;  // map half-size, probe spacing, quality (0 off, 1 low, 2 high)
global uniform vec4 probe_mix;  // how far the sky is shut out, how much bounce comes back, debug view

const float PROBE_W1[160] = float[160](-0.34115, 0.59463, 7.41159, -7.57962, -1.65540, -4.43343, 2.42593, 0.43647, -0.51720, 0.16805, 1.98253, 0.30646, 33.85116, 5.60881, 0.94415, -0.58237, 0.39510, -0.07296, -0.67169, -0.10212, 1.81543, -0.73037, 0.26733, 5.53789, 0.30678, -1.82469, 0.51796, 0.39529, -0.79183, -0.08490, 0.05339, 23.79072, 37.14708, 10.58335, -4.26974, 1.59772, 10.87560, -2.44424, -5.50589, 0.21478, -2.23437, -8.07771, -0.69088, -4.02103, 0.65147, 0.70595, 1.24203, 2.32539, -0.32077, -0.11191, 4.75058, 2.75394, -33.70576, -1.64853, 0.80046, 3.45982, 3.50304, -0.28085, 3.53338, -0.39625, -0.45626, 2.77583, -4.05925, -3.52512, 1.03019, -0.43330, 0.48198, 0.25550, -0.45801, -0.04977, 0.44428, 6.81782, 65.43001, 11.81844, 2.66430, -0.65926, 2.48422, 0.41144, -0.52693, -0.38543, 0.01191, -3.05404, 21.96171, 3.96039, -2.42013, -2.99996, 1.22487, 0.00461, -1.03447, 0.51088, 1.70249, -1.15754, -11.31601, 2.97831, 0.22574, 2.05025, 1.49544, -0.27370, -1.31674, 0.45732, -5.65615, -16.39887, -46.52639, -7.89839, 6.70929, 5.07787, 1.00519, -1.21541, 0.74920, -0.57723, 1.86588, -3.02073, -7.23745, 5.77726, 0.02432, -0.27721, 1.16917, -0.10342, -0.53743, 0.74436, -2.37073, -3.97871, -3.45995, -5.60392, 1.00018, -0.00244, 1.42845, -1.45780, 0.79167, -0.07837, 0.11456, -0.33218, 68.86202, 13.83017, 0.71601, -0.26657, 0.22765, -0.17386, -1.56872, -0.27696, 1.63907, -2.89064, -3.52652, -5.36765, 0.95201, -1.03973, 1.10329, -0.17026, -0.10640, 0.43318, 1.52519, 18.48795, 9.22931, 5.00968, -0.54710, 0.20953, -1.35280, -4.38298, 0.57061, 0.70628);
const float PROBE_B1[16] = float[16](1.75814, -1.36098, -0.83073, -1.48206, 0.31049, -5.64665, 0.08652, -1.33732, 1.10659, -1.63574, 0.76282, -1.70935, 1.80304, -0.28505, -0.53898, 0.71955);
const float PROBE_W2[16] = float[16](1.19216, 1.85324, 1.15446, -0.48165, -0.90306, 0.58065, -1.50234, -0.66945, -1.11564, 1.19264, -0.45014, -1.00855, -0.81659, -0.78570, 1.49789, -0.35214);
const float PROBE_B2 = -0.10534;

vec4 probe_read(vec2 col, float layer, float block) {
	vec2 c = clamp(col, vec2(0.5), vec2(511.5));
	return textureLod(probe_atlas, vec2(layer * 512.0 + c.x, block * 512.0 + c.y) / vec2(4096.0, 1536.0), 0.0);
}

// the share of sky a surface facing n sees, from the probes round it (High)
float probe_decode(float m0, vec3 m1, vec3 n, vec3 fr) {
	float x[10] = float[10](m0, m1.x, m1.y, m1.z, n.x, n.y, n.z, fr.x, fr.y, fr.z);
	float o = PROBE_B2;
	for (int j = 0; j < 16; j++) {
		float s = PROBE_B1[j];
		for (int i = 0; i < 10; i++) {
			s += PROBE_W1[j * 10 + i] * x[i];
		}
		o += PROBE_W2[j] * tanh(s);
	}
	return 1.0 / (1.0 + exp(-o));
}

vec4 probe_light(vec3 wp, vec3 wn) {
	float ps = probe_grid.y;
	vec3 p = wp + wn * ps * 0.6;
	vec2 col = (p.xz + probe_grid.x) / ps;
	vec4 bh = probe_read(col, 0.0, 2.0);
	float base = (bh.r * 65280.0 + bh.g * 255.0) * 0.05 - 200.0;
	float lf = (p.y - base) / ps - 0.5;
	vec2 edge = abs(p.xz) / probe_grid.x;
	float fade = (1.0 - smoothstep(6.5, 8.0, lf)) * (1.0 - smoothstep(0.97, 1.0, max(edge.x, edge.y)));
	float seen;
	vec3 lb = vec3(0.0);
	if (probe_grid.z > 1.5) {
		float l0 = clamp(floor(lf), 0.0, 6.0);
		float t = clamp(lf - l0, 0.0, 1.0);
		vec4 a = mix(probe_read(col, l0, 0.0), probe_read(col, l0 + 1.0, 0.0), t);
		vec3 b = mix(probe_read(col, l0, 1.0).rgb, probe_read(col, l0 + 1.0, 1.0).rgb, t);
		lb = b * b * 4.0;
		seen = probe_decode(a.a, a.rgb * 2.0 - 1.0, wn, vec3(fract(col.x - 0.5), t, fract(col.y - 0.5)));
	} else {
		vec4 a = probe_read(col, clamp(floor(lf + 0.5), 0.0, 7.0), 0.0);
		seen = clamp(a.a + 2.0 * dot(a.rgb * 2.0 - 1.0, wn), 0.0, 1.0);
	}
	float k = fade * probe_mix.x;
	return vec4(mix(1.0, seen, k), lb * (1.0 - seen) * fade * probe_mix.y);
}
"""

const PIXEL_USE := """if (probe_grid.z > 0.5) {
		vec4 probe_k = probe_light((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));
		AO *= probe_k.x;
		EMISSION += ALBEDO * probe_k.yzw;
		if (probe_mix.z > 0.5) {
			// FL_DEBUG_PROBES_VIEW=1: the probes' own term on grey, the share of sky each
			// surface sees (grey) and the bounce it gets (colour, amplified); =2: the raw
			// heights block (one flat colour on flat ground); =3: the bent normal, the way
			// the sky it sees lies (x red, y green, z blue; open sky reads mid-grey)
			vec3 probe_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
			ALBEDO = vec3(0.0);
			EMISSION = vec3(probe_k.x) * 0.18 + probe_k.yzw * 0.8;
			if (probe_mix.z > 2.5) {
				vec3 probe_p = probe_w + normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz) * probe_grid.y * 0.6;
				vec2 probe_c = (probe_p.xz + probe_grid.x) / probe_grid.y;
				vec4 probe_b = probe_read(probe_c, 0.0, 2.0);
				float probe_l = (probe_p.y - ((probe_b.r * 65280.0 + probe_b.g * 255.0) * 0.05 - 200.0)) / probe_grid.y - 0.5;
				vec4 probe_a = probe_read(probe_c, clamp(floor(probe_l + 0.5), 0.0, 7.0), 0.0);
				vec3 probe_bent = clamp((probe_a.rgb * 2.0 - 1.0) / max(probe_a.a, 0.05), -1.0, 1.0);
				EMISSION = clamp(probe_bent * 0.8 + 0.5, 0.0, 1.0) * 0.3;
			} else if (probe_mix.z > 1.5) {
				EMISSION = probe_read((probe_w.xz + probe_grid.x) / probe_grid.y, 0.0, 2.0).rgb * 0.3;
			}
		}
	}
"""

## Traces the probes: one pixel of the atlas is one probe's visibility (top
## block), bounce (middle) or the height its column stands on (bottom), and
## the pixel works out which from where it is. mode 0 writes open sky (and the
## heights) without tracing anything.
##
## A ray steps 0.9 of a cube at a time out to 16 cubes. Through a cube it loses
## the share the cube stops; under the ground it ends, and the ground counts
## as in the way only if the ray was climbing (a bank, a crater's rim, the
## hillside above: ground standing above the probe's horizon) or has something
## over it (a floor under a roof). Ground below the horizon is the sky's own
## lower half, which already lights everything: counted again, every slope
## would glow with a bounce off the ground beside it.
## What stops a ray is lit by the sun, if it can see the sun (a second trace),
## and by half the sky, or a tenth of it under a roof.
const BAKE_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2DArray heights : filter_linear, repeat_disable;
uniform sampler2DArray voxels : filter_nearest, repeat_disable;
// the trench network's mask (TrenchNet): trenches are cut into the ground by the
// ground's own shader, not the height texture, so the probes cut them here too
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform float trench_floor = -1.2;
uniform float mode = 0.0;
uniform float map_half = 512.0;
uniform float vsz = 1.0;
uniform float rays = 32.0;
uniform bool bounce = true;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col = vec3(1.0);
uniform vec3 sky_col = vec3(0.4);
uniform vec3 ground_albedo = vec3(0.15, 0.14, 0.1);

varying vec2 px;

void vertex() {
	px = VERTEX;
}

// the ground's height (with craters) and the undisturbed geology under it
vec2 ground_at(vec2 xz) {
	vec2 uv = (xz + map_half) / (map_half * 2.0);
	float tiles = sqrt(float(textureSize(heights, 0).z));
	vec2 margin = vec2(0.5 / (tiles * __TILE__));
	vec2 grid = clamp(uv, margin, vec2(1.0) - margin) * tiles;
	vec2 cell = floor(grid);
	vec2 local_uv = (fract(grid) * __TILE__ + 1.0) / (__TILE__ + 2.0);
	vec2 h = textureLod(heights, vec3(local_uv, cell.y * tiles + cell.x), 0.0).rg;
	float cut = smoothstep(0.3, 0.7, textureLod(trench_mask, uv, 0.0).r);
	return vec2(min(h.x, h.y + trench_floor * cut), h.y);
}

// how much the cube at q stops, and its albedo
float cube(vec3 q, float geo, out float alb) {
	alb = 0.0;
	float rel = (q.y - geo) / vsz;
	vec2 v = (q.xz + map_half) / vsz;
	if (rel < 0.0 || rel >= 16.0 || v.x < 0.0 || v.y < 0.0 || v.x >= 1024.0 || v.y >= 1024.0) {
		return 0.0;
	}
	ivec2 iv = ivec2(v);
	ivec2 t = iv / ivec2(64);
	ivec2 l = iv - t * 64;
	int b = int(texelFetch(voxels, ivec3(l.x, (int(rel) << 6) + l.y, t.y * 16 + t.x), 0).r * 255.0 + 0.5);
	alb = float(b & 15) * (0.8 / 15.0);
	return float(b >> 4) / 15.0;
}

// is there a floor, roof or crown over this bit of ground?
bool covered(vec2 xz, float geo) {
	float a;
	for (int k = 0; k < 16; k++) {
		if (cube(vec3(xz.x, geo + (float(k) + 0.5) * vsz, xz.y), geo, a) > 0.5) {
			return true;
		}
	}
	return false;
}

// how much sunlight reaches o
float sunlit(vec3 o) {
	float T = 1.0;
	for (int i = 0; i < 18; i++) {
		vec3 q = o + sun_dir * (float(i) * 0.9 + 0.5) * vsz;
		vec2 h = ground_at(q.xz);
		if (q.y < h.x) {
			return 0.0;
		}
		if (q.y - h.y >= 16.0 * vsz) {
			break;
		}
		float a;
		T *= 1.0 - cube(q, h.y, a);
		if (T < 0.03) {
			return 0.0;
		}
	}
	return T;
}

void fragment() {
	ivec2 p = ivec2(floor(px));
	int block = p.y / 512;
	int iz = p.y - block * 512;
	int layer = p.x / 512;
	int ix = p.x - layer * 512;
	float ps = vsz * 2.0;
	vec2 xz = (vec2(float(ix), float(iz)) + 0.5) * ps - map_half;
	vec2 h0 = ground_at(xz);
	// the probes stand on the geology, or down in a trench or crater cut below it
	float base = min(h0.y, h0.x);
	if (block >= 2) {
		// the geology, to 5 cm, in two bytes (they filter apart and add back exactly)
		float g = clamp(floor((base + 200.0) / 0.05 + 0.5), 0.0, 65535.0);
		float hi = floor(g / 256.0);
		COLOR = vec4(hi / 255.0, (g - hi * 256.0) / 255.0, 0.0, 1.0);
	} else if (mode < 0.5 || (block == 1 && !bounce)) {
		COLOR = block == 0 ? vec4(0.5, 0.5, 0.5, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 o = vec3(xz.x, base + (float(layer) + 0.5) * ps, xz.y);
		o.y = max(o.y, h0.x + 0.3);
		float a;
		// a probe that fell inside a wall or a roof steps out of it: down first
		// (out of a roof, into the room it covers), then to either side (out of
		// a wall), then up
		if (cube(o, h0.y, a) >= 0.5) {
			vec3 steps[6] = vec3[](vec3(0.0, -1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0),
				vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0), vec3(0.0, 1.0, 0.0));
			for (int k = 0; k < 6; k++) {
				vec3 q = o + steps[k] * vsz;
				if (q.y > h0.x + 0.2 && cube(q, h0.y, a) < 0.5) {
					o = q;
					break;
				}
			}
		}
		float seen = 0.0;
		vec3 m1 = vec3(0.0);
		vec3 lsum = vec3(0.0);
		float wsum = 0.0;
		int n = int(rays);
		for (int i = 0; i < n; i++) {
			// an even spread of directions over the sphere (a Fibonacci spiral)
			float y = 1.0 - 2.0 * (float(i) + 0.5) / rays;
			float r = sqrt(max(0.0, 1.0 - y * y));
			float ph = float(i) * 2.39996323;
			vec3 d = vec3(cos(ph) * r, y, sin(ph) * r);
			float T = 1.0;
			int kind = 0;  // 0: out to the sky (or the open ground), 1: a solid cube, 2: the ground, in the way
			vec3 hit = o;
			float halb = 0.0;
			float palb = 0.0;
			for (int s = 0; s < 18; s++) {
				vec3 q = o + d * (float(s) * 0.9 + 0.5) * vsz;
				if (abs(q.x) >= map_half || abs(q.z) >= map_half) {
					break;
				}
				vec2 h = ground_at(q.xz);
				if (q.y < h.x) {
					if (d.y > 0.05 || covered(q.xz, h.y)) {
						kind = 2;
						hit = vec3(q.x, h.x, q.z);
					}
					break;
				}
				if (q.y - h.y >= 16.0 * vsz && d.y >= 0.0) {
					break;
				}
				float va;
				float dn = cube(q, h.y, va);
				if (dn > 0.0) {
					T *= 1.0 - dn;
					palb = va;
					if (T < 0.03) {
						kind = 1;
						hit = q;
						halb = va;
						break;
					}
				}
			}
			float vis = kind == 0 ? T : 0.0;
			seen += vis;
			m1 += d * vis;
			if (block == 1 && vis < 0.999) {
				vec3 lh;
				if (kind == 0) {
					// through leaves or netting: lit from all round, a little sun through it
					lh = vec3(palb) * vec3(0.9, 1.0, 0.8) * (sky_col * 0.5 + sun_col * 0.2);
				} else {
					vec3 nh = vec3(0.0, 1.0, 0.0);
					vec3 alb3 = ground_albedo;
					if (kind == 1) {
						// the face of the cube the ray went in by
						vec3 ad = abs(d);
						nh = ad.x > ad.y && ad.x > ad.z ? vec3(-sign(d.x), 0.0, 0.0) : (ad.y > ad.z ? vec3(0.0, -sign(d.y), 0.0) : vec3(0.0, 0.0, -sign(d.z)));
						alb3 = vec3(halb) * vec3(1.04, 1.0, 0.94);
					}
					float ndl = max(dot(nh, sun_dir), 0.0);
					float lit = ndl > 0.0 ? sunlit(hit + nh * 0.6 * vsz) : 0.0;
					// a surface under a roof sees little sky itself: only what comes in round it
					float sky_seen = covered(hit.xz, ground_at(hit.xz).y) ? 0.1 : 0.5;
					lh = alb3 * (sun_col * ndl * lit + sky_col * sky_seen);
				}
				lsum += lh * (1.0 - vis);
				wsum += 1.0 - vis;
			}
		}
		seen /= rays;
		m1 /= rays;
		if (block == 0) {
			COLOR = vec4(clamp(m1 * 0.5 + 0.5, 0.0, 1.0), seen);
		} else {
			vec3 lb = lsum / max(wsum, 0.001);
			COLOR = vec4(sqrt(clamp(lb / 4.0, 0.0, 1.0)), 1.0);
		}
	}
}
"""
