class_name TrenchNet
extends Node3D
## Draws every excavated trench segment as one network dug into the ground.
##
## Segments are rasterised as capsules into a 4 px/m mask over the map. The
## ground, road and grass shaders cut a hole wherever the mask is set; this
## node fills the hole: revetted walls (marching squares on the mask, so
## junctions, bends and zig-zags join up by themselves), a muddy floor with
## duckboards, and the spoil heaped along the lips as a parapet.

const RES := 4  # mask texels per metre
static var N := MapDims.SIZE * RES
const HALF_W := 0.72  # half the trench width (m)
const FLOOR_Y := -1.2
const TILE := 16

var world
var mask := PackedByteArray()
var img: Image
var tex: ImageTexture
var wall_mat: ShaderMaterial
var berm_mat: ShaderMaterial
var floor_mat: ShaderMaterial
var board_mat: ShaderMaterial
var walls: MeshInstance3D
var berms: MeshInstance3D
var boards: MeshInstance3D
var floor_mi: MeshInstance3D
var _dirty := true
var _cool := 0.0
var _sig := ""
var _depth_shapes := {}
var _depth_cache := {}  # shared mesh corners sample excavation once per rebuild
var _seg_keys := {}  # what was cut last time, so only the changed ground is redone


func _init(w) -> void:
	world = w
	name = "TrenchNet"


func _ready() -> void:
	mask.resize(N * N)
	img = Image.create_from_data(N, N, false, Image.FORMAT_R8, mask)
	tex = ImageTexture.create_from_image(img)
	bank_material(true).set_shader_parameter("trench_mask", tex)
	bank_material(true).set_shader_parameter("map_half", MapDims.HALF)
	wall_mat = _mat(WALL_SHADER)
	berm_mat = _mat(BERM_SHADER)
	floor_mat = _mat(FLOOR_SHADER)
	board_mat = _mat(BOARD_SHADER)
	board_mat.set_shader_parameter("wood_color", load("res://assets/town/weathered_planks_color.jpg"))
	board_mat.set_shader_parameter("wood_surface", load("res://assets/town/weathered_planks_surface.png"))
	for material in [wall_mat, berm_mat, floor_mat]:
		_bind_earth(material)

	walls = _mi(wall_mat)
	berms = _mi(berm_mat)
	boards = _mi(board_mat)
	floor_mi = _mi(floor_mat)
	var pm := PlaneMesh.new()
	pm.size = Vector2(MapDims.SIZE + 14.0, MapDims.SIZE + 14.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3.ZERO
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_mi.visible = false


func _mat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CloudShadow.make(code)
	m.set_shader_parameter("trench_mask", null)
	return m


static var _bank_material: ShaderMaterial
static var _cut_bank_material: ShaderMaterial


static func _bind_earth(material: ShaderMaterial) -> void:
	var layers := Atmosphere.terrain_materials()
	material.set_shader_parameter("earth_colors", layers[0])
	material.set_shader_parameter("earth_surfaces", layers[1])


static func bank_material(cut_trenches := false) -> ShaderMaterial:
	if _bank_material == null:
		_bank_material = ShaderMaterial.new()
		_bank_material.shader = CloudShadow.make(BERM_SHADER)
		_bank_material.set_shader_parameter("bank_surface", 1.0)
		_bind_earth(_bank_material)
	if cut_trenches:
		if _cut_bank_material == null:
			_cut_bank_material = _bank_material.duplicate()
			_cut_bank_material.set_shader_parameter("cut_trench", true)
		return _cut_bank_material
	return _bank_material


func _mi(m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = m
	add_child(mi)
	return mi


func mark_dirty() -> void:
	_dirty = true


func _process(dt: float) -> void:
	_cool -= dt
	if _dirty and _cool <= 0.0:
		_dirty = false
		_cool = 0.4
		rebuild()


const JOG := 2.8  # how far each traverse steps the line sideways
const CORNER := 0.18
const BUILD_GRID := 1.0  # everything you build snaps to whole metres...
const BUILD_ANGLE := PI * 0.25  # ...and to 45 degree headings


static func snap_dir(v: Vector3) -> Vector3:
	var ang := atan2(v.z, v.x)
	ang = round(ang / BUILD_ANGLE) * BUILD_ANGLE
	return Vector3(cos(ang), 0, sin(ang))


static func snap_pos(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, BUILD_GRID), 0.0, snappedf(p.z, BUILD_GRID))


static func snap_yaw(y: float) -> float:
	return round(y / BUILD_ANGLE) * BUILD_ANGLE


## Where a building of this kind goes near p: square to the grid, its walls on
## whole-metre lines (linear works like trenches and wire keep their centre line
## on the grid instead, so lines of them meet up).
static func snap_foot(p: Vector3, kind: String, yaw: float) -> Vector3:
	p = snap_pos(p)
	if not Defs.BUILDINGS.has(kind):
		return p
	var s: Vector2 = Defs.BUILDINGS[kind].size
	if minf(s.x, s.y) < 2.0 or kind == "trench":
		return p
	var q := fposmod(yaw, PI)
	var r := fposmod(q, PI * 0.5)
	if r > 0.01 and r < PI * 0.5 - 0.01:
		return p  # on a diagonal: the centre on the grid is the best we can do
	var ex := s.x
	var ez := s.y
	if absf(q - PI * 0.5) < 0.01:
		ex = s.y
		ez = s.x
	p.x = round(p.x - ex * 0.5) + ex * 0.5
	p.z = round(p.z - ez * 0.5) + ez * 0.5
	return p


## Segment placements [pos, yaw, length] for a trench dug from a to b, on the
## build grid. Fire trenches are crenellated: bays along the line, joined by
## short traverses that step it back and forth, so neither a shell nor a gunner
## at one end can sweep more than one bay. `zig` false: one straight trench.
static func layout(a: Vector3, b: Vector3, zig := true, seg_len := 6.0, max_n := 24) -> Array:
	var out := []
	var to := Defs.flat(b - a)
	if to.length() < 1.0:
		return out
	var dir := snap_dir(to)
	a = snap_pos(a)
	var nb := clampi(int(round(to.dot(dir) / seg_len)), 1, max_n)
	var side := dir.cross(Vector3.UP)
	var yaw_b := atan2(-dir.z, dir.x)
	var yaw_j := atan2(-side.z, side.x)
	for i in nb:
		if out.size() >= max_n:
			break
		var off := JOG if zig and i % 2 == 1 else 0.0
		out.append([a + dir * seg_len * (i + 0.5) + side * off, yaw_b, seg_len])
		if zig and i < nb - 1 and out.size() < max_n:
			var off2 := JOG if (i + 1) % 2 == 1 else 0.0
			out.append([a + dir * seg_len * (i + 1) + side * (off + off2) * 0.5, yaw_j, JOG])
	return out


## Signed distance from p to the dug footprint of the segment a-b: a box the
## trench's width, square-ended (run on a little so corners and junctions fill).
static func sd_seg(a: Vector3, b: Vector3, p: Vector3) -> float:
	var d := Defs.flat(b - a)
	var l := d.length()
	if l < 0.001:
		return Defs.flat(p - a).length() - HALF_W
	d /= l
	var c := (a + b) * 0.5
	var rel := Defs.flat(p - c)
	var u := absf(rel.dot(d)) - (l * 0.5 + HALF_W - CORNER)
	var v := absf(rel.dot(Vector3(-d.z, 0, d.x))) - (HALF_W - CORNER)
	return Vector2(maxf(u, 0.0), maxf(v, 0.0)).length() + minf(maxf(u, v), 0.0) - CORNER


static func inside(st, p: Vector3, margin := 0.0) -> bool:
	var sg := seg_of(st)
	var recess := recess_of(st)
	return minf(sd_seg(sg[0], sg[1], p), sd_seg(recess[0], recess[1], p) if not recess.is_empty() else INF) < -margin


## Exposed ends slope up to the surface; a connected end stays level through the junction.
static func depth_at(st, p: Vector3, world, margin := 0.05) -> float:
	if not inside(st, p, margin):
		return 0.0
	var depth: float = st.trench_depth()
	var axis := Basis(Vector3.UP, st.yaw) * Vector3.RIGHT
	var along: float = Defs.flat(p - st.position).dot(axis)
	var half: float = st.size.x * 0.5
	if absf(along) > half - 0.6:
		var end: Vector3 = st.position + axis * half * signf(along)
		var joined_depth := -1.0
		for other in world._trenches_at(end):
			if other != st and not other.gone and other.trench_depth() > 0.0 and inside(other, end, -0.1):
				joined_depth = maxf(joined_depth, other.trench_depth())
		if joined_depth >= 0.0:
			return lerpf(joined_depth, depth, clampf((half + 0.6 - absf(along)) / 1.2, 0.0, 1.0))
		depth *= clampf((half + 0.5 - absf(along)) / 1.1, 0.0, 1.0)
	return depth


## Excavated trench segments as [a, b, depth] centre lines.
func segments() -> Array:
	var out := []
	for st in world.structures:
		if st.gone or st.skind != "trench" or st.trench_depth() <= 0.0:
			continue
		var seg := seg_of(st)
		seg.append(st.trench_depth())
		out.append(seg)
		var recess := recess_of(st)
		if not recess.is_empty():
			recess.append(st.trench_depth())
			out.append(recess)
	return out


## Long bays have a rear recess, leaving the through route clear for passing.
static func has_recess(st) -> bool:
	return st.size.x >= 5.0 and st.eid % 3 == 0


static func recess_of(st) -> Array:
	if not has_recess(st):
		return []
	var rear: Vector3 = Basis(Vector3.UP, st.yaw) * Vector3(0, 0, -st._enemy_side())
	return [st.position + rear * 0.35, st.position + rear * 1.25]


static func seg_of(st) -> Array:
	var d := Basis(Vector3.UP, st.yaw) * Vector3(st.size.x * 0.5, 0, 0)
	return [st.position - d, st.position + d]


## The ground (in metres) touched by trench segments added or filled in
## since the last rebuild; empty the first time (everything is redone).
func _changed_area(segs: Array) -> Rect2:
	var keys := {}
	for s in segs:
		keys[str(s)] = s
	var first := _seg_keys.is_empty()
	var area := Rect2()
	var any := false
	for pair in [[keys, _seg_keys], [_seg_keys, keys]]:
		for k in pair[0]:
			if pair[1].has(k):
				continue
			var s: Array = pair[0][k]
			var r := Rect2(Vector2(s[0].x, s[0].z), Vector2.ZERO).expand(Vector2(s[1].x, s[1].z)).grow(3.0)
			area = r if not any else area.merge(r)
			any = true
	_seg_keys = keys
	return Rect2() if first else area


# shortcut: edits rebuild the full network; split meshes into chunks if large construction sites hitch.
func rebuild() -> void:
	var segs := segments()
	var sig := str(segs.size())
	for s in segs:
		sig += "|" + str(s)
	if sig == _sig:
		return
	_sig = sig
	mask.fill(0)
	var tiles := {}
	for s in segs:
		_raster(s[0], s[1], tiles)
	img.set_data(N, N, false, Image.FORMAT_R8, mask)
	if world and world.phys:
		world.phys.update_ground(mask, _changed_area(segs))
	tex.update(img)
	floor_mi.visible = not segs.is_empty()
	_build_meshes(tiles, segs)
	if world.atmo:
		world.atmo.set_trench_mask(tex)


static func edge_erosion(p: Vector3) -> float:
	return 0.07 * sin(p.x * 1.17 + sin(p.z * 0.83)) + 0.04 * sin(p.z * 4.1 + p.x * 2.3)


func _raster(a: Vector3, b: Vector3, tiles: Dictionary) -> void:
	var r := HALF_W * 2.0 + 0.5
	var x0 := clampi(floori((minf(a.x, b.x) - r + MapDims.HALF) * RES), 0, N - 1)
	var x1 := clampi(ceili((maxf(a.x, b.x) + r + MapDims.HALF) * RES), 0, N - 1)
	var z0 := clampi(floori((minf(a.z, b.z) - r + MapDims.HALF) * RES), 0, N - 1)
	var z1 := clampi(ceili((maxf(a.z, b.z) + r + MapDims.HALF) * RES), 0, N - 1)
	for z in range(z0, z1 + 1):
		var wz := (z + 0.5) / RES - MapDims.HALF
		for x in range(x0, x1 + 1):
			var wx := (x + 0.5) / RES - MapDims.HALF
			var d := sd_seg(a, b, Vector3(wx, 0, wz)) - edge_erosion(Vector3(wx, 0, wz))
			# soft edge so the filtered mask gives a clean rim
			var v := clampi(int(-d * RES * 0.5 * 255.0 + 127.5), 0, 255)
			var i := z * N + x
			if v > mask[i]:
				mask[i] = v
	for tz in range(z0 / TILE, z1 / TILE + 1):
		for tx in range(x0 / TILE, x1 / TILE + 1):
			tiles[Vector2i(tx, tz)] = true


func _inside(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= N or z >= N:
		return false
	return mask[z * N + x] > 127


func _val(x: int, z: int) -> float:
	if x < 0 or z < 0 or x >= N or z >= N:
		return 0.0
	return float(mask[z * N + x])


static func _cross(a: float, b: float) -> float:
	if absf(b - a) < 0.001:
		return 0.5
	return clampf((127.5 - a) / (b - a), 0.0, 1.0)


func _inside_w(p: Vector3) -> bool:
	return _inside(int(floor((p.x + MapDims.HALF) * RES)), int(floor((p.z + MapDims.HALF) * RES)))


## World position of mask corner (x, z): texel centres.
func _wp(x: float, z: float) -> Vector3:
	var p := Vector3((x + 0.5) / RES - MapDims.HALF, 0.0, (z + 0.5) / RES - MapDims.HALF)
	p.y = world.terrain.landform.height(p)
	return p


## Cache immutable section geometry while rebuilding; per-vertex queries must not
## rediscover connections or allocate segment arrays thousands of times.
func _prepare_depths() -> void:
	_depth_cache.clear()
	_depth_shapes.clear()
	for st in world.structures:
		if st.gone or st.skind != "trench" or st.trench_depth() <= 0.0:
			continue
		if world.has_view and st.model != null:
			st.refresh_trench_furnishings()
		var ends := seg_of(st)
		var joins := [-1.0, -1.0]
		for i in 2:
			for other in world._trenches_at(ends[i]):
				if other != st and not other.gone and other.trench_depth() > 0.0 and inside(other, ends[i], -0.1):
					joins[i] = maxf(joins[i], other.trench_depth())
		var recess := recess_of(st)
		var bounds := Rect2(Vector2(ends[0].x, ends[0].z), Vector2.ZERO).expand(Vector2(ends[1].x, ends[1].z))
		for point in recess:
			bounds = bounds.expand(Vector2(point.x, point.z))
		_depth_shapes[st.eid] = {"a": ends[0], "b": ends[1], "recess": recess, "bounds": bounds.grow(HALF_W + 0.31), "depth": st.trench_depth(),
			"axis": Basis(Vector3.UP, st.yaw) * Vector3.RIGHT, "half": st.size.x * 0.5, "joins": joins}


func _draw_depth(p: Vector3, margin: float) -> float:
	var key := Vector3(p.x, margin, p.z)
	if _depth_cache.has(key):
		return _depth_cache[key]
	var result := 0.0
	for st in world._trenches_at(p):
		if not _depth_shapes.has(st.eid):
			continue
		var shape: Dictionary = _depth_shapes[st.eid]
		if not (shape.bounds as Rect2).has_point(Vector2(p.x, p.z)):
			continue
		var distance := sd_seg(shape.a, shape.b, p)
		if not shape.recess.is_empty():
			distance = minf(distance, sd_seg(shape.recess[0], shape.recess[1], p))
		if distance >= -margin:
			continue
		var depth: float = shape.depth
		var along: float = Defs.flat(p - st.position).dot(shape.axis)
		var half: float = shape.half
		if absf(along) > half - 0.6:
			var joined: float = shape.joins[0 if along < 0.0 else 1]
			if joined >= 0.0:
				depth = lerpf(joined, depth, clampf((half + 0.6 - absf(along)) / 1.2, 0.0, 1.0))
			else:
				depth *= clampf((half + 0.5 - absf(along)) / 1.1, 0.0, 1.0)
		result = maxf(result, depth)
	_depth_cache[key] = result
	return result


func _build_meshes(tiles: Dictionary, segs: Array) -> void:
	_prepare_depths()
	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floors := 0
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bst := SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nw := 0
	var contour := []
	for t in tiles:
		var tx: int = t.x * TILE
		var tz: int = t.y * TILE
		for z in range(tz - 1, tz + TILE):
			for x in range(tx - 1, tx + TILE):
				var v0 := _val(x, z)
				var v1 := _val(x + 1, z)
				var v2 := _val(x + 1, z + 1)
				var v3 := _val(x, z + 1)
				var idx := int(v0 > 127.5) | (int(v1 > 127.5) << 1) | (int(v2 > 127.5) << 2) | (int(v3 > 127.5) << 3)
				if idx != 0:
					var floor_corners := [_wp(x, z), _wp(x + 1, z), _wp(x + 1, z + 1), _wp(x, z + 1)]
					fst.set_normal(Vector3.UP)
					for k in [0, 1, 2, 0, 2, 3]:
						var p: Vector3 = floor_corners[k]
						p.y -= _draw_depth(p, -0.3)
						fst.add_vertex(p)
					floors += 1
				if idx == 0 or idx == 15:
					continue
				# crossings interpolated on each edge: smooth contours, not a staircase
				var em := [_wp(x + _cross(v0, v1), z), _wp(x + 1, z + _cross(v1, v2)), _wp(x + _cross(v3, v2), z + 1), _wp(x, z + _cross(v0, v3))]
				var corners := [_wp(x, z), _wp(x + 1, z), _wp(x + 1, z + 1), _wp(x, z + 1)]
				var inside_c := Vector3.ZERO
				var ni := 0
				for k in 4:
					if (idx >> k) & 1:
						inside_c += corners[k]
						ni += 1
				inside_c /= maxf(1, ni)
				for e in _EDGES[idx]:
					var q0: Vector3 = em[e[0]]
					var q1: Vector3 = em[e[1]]
					if q0.distance_to(q1) < 0.0005:
						continue
					_wall(wst, q0, q1, inside_c)
					contour.append([q0, q1, inside_c])
					nw += 1
	_berms(bst, contour)
	# Shared corners retain the same shape and normals without duplicate vertex storage.
	if floors > 0:
		fst.index()
	if nw > 0:
		wst.index()
		bst.index()
	floor_mi.mesh = fst.commit() if floors > 0 else null
	walls.mesh = wst.commit() if nw > 0 else null
	berms.mesh = bst.commit() if nw > 0 else null
	# Short slats follow the slope instead of bridging between segment endpoints.
	var dst := SurfaceTool.new()
	dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var board_count := 0
	for s in segs:
		if s[2] < 1.0:
			continue
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := Defs.flat(b - a).normalized()
		var sd := d.cross(Vector3.UP) * 0.32
		var l := Defs.flat(b - a).length()
		for i in ceili(l / 0.32):
			var p := a + d * (i * 0.32)
			var wear := sin(p.x * 19.7 + p.z * 8.3)
			var width := sd * (0.94 + 0.1 * wear)
			p += sd * (wear * 0.08)
			var q := [p + width + d * wear * 0.025, p + d * 0.28 + width, p + d * (0.28 - wear * 0.025) - width, p - width]
			for j in 4:
				q[j].y = world.terrain.landform.height(q[j]) - _draw_depth(q[j], -0.1) + minf(0.15, _draw_depth(q[j], -0.1) * 0.125)
			var uv := [Vector2(i * 0.32, 0), Vector2(i * 0.32 + 0.28, 0), Vector2(i * 0.32 + 0.28, 1), Vector2(i * 0.32, 1)]
			dst.set_color(Color((wear + 1.0) * 0.5, 1, 1))
			_board(dst, q, uv, 0.045)
			board_count += 1
		# Bearers carry the slats above drainage mud, rather than leaving them suspended.
		for side in [-1.0, 1.0]:
			for i in ceili(l):
				var p: Vector3 = a + d * float(i) + sd.normalized() * side * 0.2
				var span := minf(1.0, l - float(i))
				var width := sd.normalized() * 0.035
				var q := [p + width, p + d * span + width, p + d * span - width, p - width]
				for j in 4:
					q[j].y = world.terrain.landform.height(q[j]) - _draw_depth(q[j], -0.1) + minf(0.105, _draw_depth(q[j], -0.1) * 0.0875)
				dst.set_color(Color(0.2, 1, 1))
				_board(dst, q, [Vector2(0.02, 0), Vector2(0.02, span), Vector2(0.29, span), Vector2(0.29, 0)], 0.09)
	if board_count > 0:
		dst.index()
	boards.mesh = dst.commit() if board_count > 0 else null


func _board(dst: SurfaceTool, q: Array, uv: Array, thickness: float) -> void:
	dst.set_normal(Vector3.UP)
	for k in [0, 2, 1, 0, 3, 2]:
		dst.set_uv(uv[k])
		dst.add_vertex(q[k])
	for edge in 4:
		var next := (edge + 1) % 4
		var a: Vector3 = q[edge]
		var b: Vector3 = q[next]
		dst.set_normal((b - a).cross(Vector3.UP).normalized())
		for vertex in [[a, uv[edge]], [b, uv[next]], [b - Vector3.UP * thickness, uv[next]], [a, uv[edge]], [b - Vector3.UP * thickness, uv[next]], [a - Vector3.UP * thickness, uv[edge]]]:
			dst.set_uv(vertex[1])
			dst.add_vertex(vertex[0])


## A battered cut; shared rim directions keep the layered mesh closed around corners.
func _cut_inward(p: Vector3) -> Vector3:
	var x := roundi((p.x + MapDims.HALF) * RES - 0.5)
	var z := roundi((p.z + MapDims.HALF) * RES - 0.5)
	return Vector3(_val(x + 1, z) - _val(x - 1, z), 0, _val(x, z + 1) - _val(x, z - 1)).normalized()


## Loose clods break the level cut edge, sharing the same height with the spoil.
static func rim_height(p: Vector3, depth: float) -> float:
	var clods := 0.5 + 0.32 * sin(p.x * 2.7 + p.z * 1.9) + 0.18 * sin(p.z * 7.1 - p.x * 4.3)
	return 0.02 + 0.08 * clods * clampf(depth / 1.2, 0.0, 1.0)


static func cut_relief(p: Vector3, fraction: float) -> float:
	return sin(fraction * PI) * (0.045 + 0.035 * sin(p.x * 8.3 + p.z * 6.7 + fraction * 12.0))


static func cut_normal(p: Vector3, inward: Vector3, depth: float, fraction: float) -> Vector3:
	var phase := p.x * 8.3 + p.z * 6.7 + fraction * 12.0
	var wave := sin(fraction * PI)
	var across := Vector3(-inward.z, 0, inward.x)
	var along_slope := wave * 0.035 * cos(phase) * (across.x * 8.3 + across.z * 6.7)
	var down_slope := PI * cos(fraction * PI) * (0.045 + 0.035 * sin(phase)) + wave * 0.42 * cos(phase)
	return (inward - across * along_slope + Vector3.UP * down_slope / maxf(depth, 0.15)).normalized()


func _wall(wst: SurfaceTool, p0: Vector3, p1: Vector3, inside_c: Vector3) -> void:
	var n := _inward(p0, p1, inside_c)
	var a := p0
	var b := p1
	if (b - a).cross(Vector3.UP).dot(n) > 0.0:
		a = p1
		b = p0
	var da: float = _draw_depth(a, -0.3)
	var db: float = _draw_depth(b, -0.3)
	var na := _cut_inward(a)
	var nb := _cut_inward(b)
	var bl := a + Vector3(0, -da, 0)
	var br := b + Vector3(0, -db, 0)
	wst.set_color(Color(1, n.x * 0.5 + 0.5, n.z * 0.5 + 0.5, minf(da, db) / 1.2))
	var ha := rim_height(a, da)
	var hb := rim_height(b, db)
	var left := a + Vector3.UP * ha
	var right := b + Vector3.UP * hb
	for row in 5:
		var t0 := row * 0.2
		var t1 := (row + 1) * 0.2
		var lower_left := a + Vector3(0, lerpf(ha, -da, t1), 0) + na * cut_relief(a, t1)
		var lower_right := b + Vector3(0, lerpf(hb, -db, t1), 0) + nb * cut_relief(b, t1)
		var normals := [cut_normal(a, na, da, t0), cut_normal(b, nb, db, t0), cut_normal(a, na, da, t1), cut_normal(b, nb, db, t1)]
		for v in [[left, Vector2(0, da * t0), normals[0]], [lower_right, Vector2(1, db * t1), normals[3]], [right, Vector2(1, db * t0), normals[1]],
				[left, Vector2(0, da * t0), normals[0]], [lower_left, Vector2(0, da * t1), normals[2]], [lower_right, Vector2(1, db * t1), normals[3]]]:
			wst.set_uv(v[1])
			wst.set_normal(v[2])
			wst.add_vertex(v[0])
		left = lower_left
		right = lower_right
	if minf(da, db) >= 1.0:
		# The standing surface stays level; boots wear a rounded, irregular edge into it.
		var sa := bl + Vector3.UP * 0.3
		var sb := br + Vector3.UP * 0.3
		var ea := na * (0.4 + 0.035 * sin(a.x * 3.7 + a.z * 2.1))
		var eb := nb * (0.4 + 0.035 * sin(b.x * 3.7 + b.z * 2.1))
		var ta := sa + ea - na * 0.045
		var tb := sb + eb - nb * 0.045
		var fa := sa + ea - Vector3.UP * 0.055
		var fb := sb + eb - Vector3.UP * 0.055
		wst.set_color(Color(0, 0.5, 0.5, minf(da, db) / 1.2))
		wst.set_normal(Vector3.UP)
		for p in [sa, tb, sb, sa, ta, tb]:
			wst.set_uv(Vector2(p.x + p.z, minf(da, db) - 0.3))
			wst.add_vertex(p)
		for strip in [[ta, tb, fa, fb, (n + Vector3.UP).normalized()], [fa, fb, bl + ea, br + eb, n]]:
			wst.set_normal(strip[4])
			wst.set_color(Color(0, n.x * 0.5 + 0.5, n.z * 0.5 + 0.5, minf(da, db) / 1.2))
			for p in [strip[0], strip[2], strip[3], strip[0], strip[3], strip[1]]:
				wst.set_uv(Vector2(p.x + p.z, (a.y + b.y) * 0.5 - p.y))
				wst.add_vertex(p)



static func _inward(p0: Vector3, p1: Vector3, inside_c: Vector3) -> Vector3:
	var d := p1 - p0
	var n := Vector3(-d.z, 0, d.x).normalized()
	if n.dot(inside_c - (p0 + p1) * 0.5) < 0.0:
		n = -n
	return n


static func _key(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x * 200.0)), int(round(p.z * 200.0)))


## The spoil heaped outside the lips: contour pieces are chained into outlines
## so the heap is one continuous strip (smooth normals, no gaps at bends), and
## it stops short of any neighbouring trench.
func _berms(bst: SurfaceTool, contour: Array) -> void:
	var at := {}  # endpoint key -> [segment indices]
	for i in contour.size():
		for k in 2:
			var key := _key(contour[i][k])
			if not at.has(key):
				at[key] = []
			at[key].append(i)
	var used := PackedByteArray()
	used.resize(contour.size())
	for start in contour.size():
		if used[start]:
			continue
		used[start] = 1
		var pts: Array = [contour[start][0], contour[start][1]]
		var ins: Array = [_inward(contour[start][0], contour[start][1], contour[start][2])]
		for dirn in 2:
			while true:
				var end: Vector3 = pts.back() if dirn == 0 else pts.front()
				var nxt := -1
				for j in at.get(_key(end), []):
					if not used[j]:
						nxt = j
						break
				if nxt < 0:
					break
				used[nxt] = 1
				var c: Array = contour[nxt]
				var other: Vector3 = c[1] if _key(c[0]) == _key(end) else c[0]
				var n := _inward(c[0], c[1], c[2])
				if dirn == 0:
					pts.append(other)
					ins.append(n)
				else:
					pts.push_front(other)
					ins.push_front(n)
		_berm_strip(bst, pts, ins)


func _berm_strip(bst: SurfaceTool, pts: Array, ins: Array) -> void:
	var m := pts.size()
	if m < 2:
		return
	var closed := _key(pts[0]) == _key(pts[m - 1])
	var lip := []
	var crest := []
	var toe := []
	for i in m:
		var a: Vector3 = ins[clampi(i - 1, 0, ins.size() - 1)]
		var b: Vector3 = ins[clampi(i, 0, ins.size() - 1)]
		if closed and (i == 0 or i == m - 1):
			a = ins[ins.size() - 1]
			b = ins[0]
		var o: Vector3 = -(a + b).normalized() if (a + b).length() > 0.01 else -b
		var p: Vector3 = pts[i]
		var reach := 1.55
		for k in [0.6, 1.0, 1.55]:
			if _inside_w(p + o * k):
				reach = maxf(0.0, k - 0.45)
				break
		var depth: float = _draw_depth(p, -0.3)
		var variation := 0.76 + 0.24 * sin(p.x * 1.3 + sin(p.z * 0.9))
		reach *= (0.4 + 0.6 * depth / 1.2) * variation
		var h := (0.31 + 0.16 * sin(p.x * 1.7 + p.z * 0.71) + 0.07 * sin(p.z * 5.3)) * clampf(reach / 1.2, 0.0, 1.0) * depth / 1.2
		lip.append(p + Vector3.UP * rim_height(p, depth))
		crest.append(p + o * minf(0.65, reach * (0.36 + 0.12 * variation)) + Vector3(0, maxf(0.1 * depth / 1.2, h), 0))
		var outer := p + o * reach
		outer.y = world.terrain.landform.height(outer) - 0.025
		toe.append(outer)
	var lip_normals: Array[Vector3] = []
	var crest_normals: Array[Vector3] = []
	var toe_normals: Array[Vector3] = []
	for i in m:
		lip_normals.append(_berm_normal(lip, i, crest[i] - lip[i], closed))
		crest_normals.append(_berm_normal(crest, i, toe[i] - lip[i], closed))
		toe_normals.append(_berm_normal(toe, i, toe[i] - crest[i], closed))
	for i in m - 1:
		var inward: Vector3 = ins[clampi(i, 0, ins.size() - 1)]
		var a := i
		var b := i + 1
		if ((pts[b] as Vector3) - (pts[a] as Vector3)).cross(Vector3.UP).dot(inward) > 0.0:
			a = i + 1
			b = i
		for v in [[lip[a], lip_normals[a], 0.0], [lip[b], lip_normals[b], 0.0], [crest[b], crest_normals[b], 0.5], [lip[a], lip_normals[a], 0.0], [crest[b], crest_normals[b], 0.5], [crest[a], crest_normals[a], 0.5],
				[crest[a], crest_normals[a], 0.5], [crest[b], crest_normals[b], 0.5], [toe[b], toe_normals[b], 1.0], [crest[a], crest_normals[a], 0.5], [toe[b], toe_normals[b], 1.0], [toe[a], toe_normals[a], 1.0]]:
			bst.set_normal(v[1])
			bst.set_uv(Vector2(v[2], 0))
			bst.add_vertex(v[0])


## Light follows the actual mound and hillside, with one smooth crest at each join.
static func _berm_normal(ring: Array, i: int, across: Vector3, closed: bool) -> Vector3:
	var previous := maxi(0, i - 1)
	var next := mini(ring.size() - 1, i + 1)
	if closed and (i == 0 or i == ring.size() - 1):
		previous = ring.size() - 2
		next = 1
	var along: Vector3 = ring[next] - ring[previous]
	var normal := along.cross(across).normalized()
	if normal.length_squared() < 0.5:
		return Vector3.UP
	return normal if normal.y >= 0.0 else -normal


## Marching squares: which edge pairs to join per corner case (corners 0..3 =
## (x,z) (x+1,z) (x+1,z+1) (x,z+1); edges 0..3 = bottom, right, top, left).
const _EDGES := [
	[], [[3, 0]], [[0, 1]], [[3, 1]],
	[[1, 2]], [[3, 0], [1, 2]], [[0, 2]], [[3, 2]],
	[[2, 3]], [[2, 0]], [[0, 1], [2, 3]], [[2, 1]],
	[[1, 3]], [[1, 0]], [[0, 3]], [],
]


const WALL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/game/trench_earth.gdshaderinc"
// CLOUD_SHADOW
varying vec3 wpos;
varying vec3 cut_normal;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; cut_normal = vec3(COLOR.g * 2.0 - 1.0, 0.0, COLOR.b * 2.0 - 1.0); }
void fragment() {
	vec2 cut_uv = dot(cut_normal, cut_normal) < 0.1 ? wpos.xz : (abs(cut_normal.x) > abs(cut_normal.z) ? wpos.zy : wpos.xy);
	float depth = UV.y;
	float patches = earth_noise(wpos.xz * 0.42);
	float wet = clamp(smoothstep(0.6, 1.2, depth) * (0.12 + patches * 0.25) + rain_wet * 0.45, 0.0, 1.0);
	vec3 soil; vec4 grain;
	earth_material(cut_uv / 1.3, wpos, depth, wet, soil, grain);
	float root_path = sin(cut_uv.x * 42.0 + sin(depth * 14.0 + patches * 6.0) * 1.7);
	float roots = smoothstep(0.985, 0.998, root_path) * smoothstep(0.48, 0.7, patches) * (1.0 - smoothstep(0.05, 0.25 + patches * 0.15, depth));
	soil = mix(soil, soil * 0.3, roots * 0.65);
	ALBEDO = earth_output(soil);
	ROUGHNESS = mix(clamp(grain.a, 0.72, 0.98), 0.59, wet);
	NORMAL = earth_detail_normal(NORMAL, VERTEX, cut_uv / 1.3, grain.xy, 0.7);
	AO = mix(0.7, 1.0, grain.b) * mix(1.0, 0.76, depth);
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""

const BERM_SHADER := """
shader_type spatial;
#include "res://scripts/game/trench_earth.gdshaderinc"
uniform float bank_surface = 0.0;
uniform bool cut_trench = false;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform float map_half = 1.0;
global uniform float snow_cover;  // (Atmosphere._snow_tick)
// CLOUD_SHADOW
varying vec3 wpos;
varying float upness;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; upness = abs((MODEL_NORMAL_MATRIX * NORMAL).y); }
void fragment() {
	// Excavating beside an existing bunker also cuts its ground-level spoil.
	if (cut_trench && texture(trench_mask, (wpos.xz + vec2(map_half)) / (map_half * 2.0)).r > 0.5) discard;
	float patches = earth_noise(wpos.xz * 1.7);
	float torn = earth_noise(wpos.xz * 5.1);
	float wet = clamp(rain_wet * 0.7 + earth_noise(wpos.xz * 0.38) * 0.12, 0.0, 1.0);
	vec3 soil; vec4 soil_surface;
	earth_material(wpos.xz / 1.3, wpos, 0.65, wet, soil, soil_surface);
	vec3 turf = earth_color(wpos.xz * 0.4, 6.0) * vec3(0.43, 0.53, 0.30);
	float edge = mix(UV.x, upness * 0.7, bank_surface);
	float grass = smoothstep(0.58, 0.96, edge + (patches - 0.5) * 0.8 + (torn - 0.5) * 0.3);
	vec4 surface = mix(soil_surface, texture(earth_surfaces, vec3(wpos.xz * 0.4, 6.0)), grass);
	vec3 col = mix(soil, turf * (1.0 - wet * 0.45), grass);
	// in snow the old, grassed-over spoil and the tops of the banks lie white;
	// the fresh-dug earth, turned over since it fell, stays dark mud
	float snowed = 0.0;
	if (snow_cover > 0.0) {
		snowed = smoothstep(0.0, 0.3, grass * 0.8 + upness * 0.45 + (patches - 0.5) * 0.5 - 0.6 - (1.0 - snow_cover) * 1.4);
		col = mix(col, vec3(0.78, 0.8, 0.85) * (0.92 + 0.08 * torn), snowed);
	}
	ALBEDO = earth_output(col);
	ROUGHNESS = mix(mix(clamp(surface.a, 0.72, 0.98), 0.64, wet), 0.85, snowed);
	NORMAL = earth_detail_normal(NORMAL, VERTEX, wpos.xz, surface.xy, 0.75);
	AO = surface.b;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""

const FLOOR_SHADER := """
shader_type spatial;
#include "res://scripts/game/trench_earth.gdshaderinc"
// CLOUD_SHADOW
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float drainage = earth_noise(wpos.xz * 0.58 + vec2(4.2, 0.7));
	float grain = earth_noise(wpos.xz * 7.0);
	float puddle = smoothstep(0.7 - rain_wet * 0.16, 0.79 - rain_wet * 0.16, drainage + (grain - 0.5) * 0.08);
	float wet = clamp(0.28 + drainage * 0.45 + rain_wet * 0.3, 0.0, 1.0);
	vec3 soil; vec4 surface;
	earth_material(wpos.xz / 1.3, wpos, 0.85, wet, soil, surface);
	vec3 litter = earth_color(wpos.xz * 0.8, 4.0) * vec3(0.38,0.34,0.29);
	float debris = smoothstep(0.66, 0.81, earth_noise(wpos.xz * 1.35));
	vec3 col = mix(soil, litter, debris * 0.25);
	col = mix(col, vec3(0.018,0.015,0.01), puddle * 0.76);
	ALBEDO = earth_output(col);
	ROUGHNESS = mix(mix(clamp(surface.a, 0.72, 0.98), 0.59, wet), 0.19, puddle);
	SPECULAR = mix(0.22, 0.48, puddle);
	NORMAL = earth_detail_normal(NORMAL, VERTEX, wpos.xz, surface.xy, mix(0.6, 0.03, puddle));
	AO = mix(surface.b, 1.0, puddle);
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""

const BOARD_SHADER := """
shader_type spatial;
#include "res://scripts/game/trench_earth.gdshaderinc"
uniform sampler2D wood_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_surface : filter_linear_mipmap_anisotropic, repeat_enable;
// CLOUD_SHADOW
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float age = COLOR.r;
	// Sample one plank across each slat, with the photographed grain along its length.
	vec2 wood_uv = vec2(fract(UV.x / 0.32) * 0.08 + 0.01 + floor(age * 9.0) * 0.11, UV.y * 0.34 + age * 0.4);
	vec3 col = texture(wood_color, wood_uv).rgb;
	if (OUTPUT_IS_SRGB) col = mix(col / 12.92, pow((col + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), col));
	vec4 surface = texture(wood_surface, wood_uv);
	float wet = clamp(0.1 + rain_wet * 0.7, 0.0, 1.0);
	col *= (0.65 + age * 0.45) * (1.0 - wet * 0.4);
	ALBEDO = earth_output(col);
	ROUGHNESS = mix(max(surface.a, 0.78), 0.57, wet);
	NORMAL = earth_detail_normal(NORMAL, VERTEX, wood_uv, surface.xy, 0.4);
	AO = 1.0;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""
