class_name TrenchNet
extends Node3D
## Draws every finished trench segment as one network dug into the ground.
##
## Segments are rasterised as capsules into a 4 px/m mask over the map. The
## ground, road and grass shaders cut a hole wherever the mask is set; this
## node fills the hole: revetted walls (marching squares on the mask, so
## junctions, bends and zig-zags join up by themselves), a muddy floor with
## duckboards, and the spoil heaped along the lips as a parapet.

const RES := 4  # mask texels per metre
const N := 256 * RES
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


func _init(w) -> void:
	world = w
	name = "TrenchNet"


func _ready() -> void:
	mask.resize(N * N)
	img = Image.create_from_data(N, N, false, Image.FORMAT_R8, mask)
	tex = ImageTexture.create_from_image(img)
	wall_mat = _mat(WALL_SHADER)
	berm_mat = _mat(BERM_SHADER)
	floor_mat = _mat(FLOOR_SHADER)
	board_mat = _mat(BOARD_SHADER)

	walls = _mi(wall_mat)
	berms = _mi(berm_mat)
	boards = _mi(board_mat)
	floor_mi = _mi(floor_mat)
	var pm := PlaneMesh.new()
	pm.size = Vector2(270, 270)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, FLOOR_Y, 0)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_mi.visible = false


func set_detail(t: Texture2D) -> void:
	for m in [wall_mat, berm_mat, floor_mat, board_mat]:
		m.set_shader_parameter("detail_tex", t)


func _mat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = code
	m.shader = s
	m.set_shader_parameter("trench_mask", null)
	return m


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
	return sd_seg(sg[0], sg[1], p) < -margin


## Finished trench segments as [a, b] centre lines.
func segments() -> Array:
	var out := []
	for st in world.structures:
		if st.gone or st.skind != "trench" or not st.built:
			continue
		out.append(seg_of(st))
	return out


static func seg_of(st) -> Array:
	var d := Basis(Vector3.UP, st.yaw) * Vector3(st.size.x * 0.5, 0, 0)
	return [st.position - d, st.position + d]


func rebuild() -> void:
	var segs := segments()
	var sig := str(segs.size())
	for s in segs:
		sig += "|%d,%d" % [int(s[0].x * 10 + s[0].z * 7), int(s[1].x * 10 + s[1].z * 7)]
	if sig == _sig:
		return
	_sig = sig
	mask.fill(0)
	var tiles := {}
	for s in segs:
		_raster(s[0], s[1], tiles)
	img.set_data(N, N, false, Image.FORMAT_R8, mask)
	if world and world.phys:
		world.phys.update_ground(mask)
	tex.update(img)
	floor_mi.visible = not segs.is_empty()
	_build_meshes(tiles, segs)
	if world.atmo:
		world.atmo.set_trench_mask(tex)


func _raster(a: Vector3, b: Vector3, tiles: Dictionary) -> void:
	var r := HALF_W * 2.0 + 0.5
	var x0 := clampi(floori((minf(a.x, b.x) - r + 128.0) * RES), 0, N - 1)
	var x1 := clampi(ceili((maxf(a.x, b.x) + r + 128.0) * RES), 0, N - 1)
	var z0 := clampi(floori((minf(a.z, b.z) - r + 128.0) * RES), 0, N - 1)
	var z1 := clampi(ceili((maxf(a.z, b.z) + r + 128.0) * RES), 0, N - 1)
	for z in range(z0, z1 + 1):
		var wz := (z + 0.5) / RES - 128.0
		for x in range(x0, x1 + 1):
			var wx := (x + 0.5) / RES - 128.0
			var d := sd_seg(a, b, Vector3(wx, 0, wz))
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
	return _inside(int(floor((p.x + 128.0) * RES - 0.5 + 0.5)), int(floor((p.z + 128.0) * RES - 0.5 + 0.5)))


## World position of mask corner (x, z): texel centres.
func _wp(x: float, z: float) -> Vector3:
	return Vector3((x + 0.5) / RES - 128.0, 0.0, (z + 0.5) / RES - 128.0)


func _build_meshes(tiles: Dictionary, segs: Array) -> void:
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
	walls.mesh = wst.commit() if nw > 0 else null
	berms.mesh = bst.commit() if nw > 0 else null
	# duckboards down the middle of every segment
	var dst := SurfaceTool.new()
	dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := (b - a).normalized()
		var sd := d.cross(Vector3.UP) * 0.32
		var y := Vector3(0, FLOOR_Y + 0.05, 0)
		var l := a.distance_to(b)
		var q := [a + sd + y, b + sd + y, b - sd + y, a - sd + y]
		var uv := [Vector2(0, 0), Vector2(l, 0), Vector2(l, 1), Vector2(0, 1)]
		dst.set_normal(Vector3.UP)
		for k in [0, 2, 1, 0, 3, 2]:
			dst.set_uv(uv[k])
			dst.add_vertex(q[k])
	boards.mesh = dst.commit() if not segs.is_empty() else null


## One wall quad from the lip down to the floor, facing into the trench.
func _wall(wst: SurfaceTool, p0: Vector3, p1: Vector3, inside_c: Vector3) -> void:
	var n := _inward(p0, p1, inside_c)
	var a := p0
	var b := p1
	if (b - a).cross(Vector3.UP).dot(n) > 0.0:
		a = p1
		b = p0
	var u0 := a.x * 0.7 + a.z * 0.7
	var u1 := b.x * 0.7 + b.z * 0.7
	var tl := a + Vector3(0, 0.02, 0)
	var tr := b + Vector3(0, 0.02, 0)
	var bl := a + Vector3(0, FLOOR_Y, 0)
	var br := b + Vector3(0, FLOOR_Y, 0)
	wst.set_normal(n)
	for v in [[tl, Vector2(u0, 0)], [br, Vector2(u1, 1)], [tr, Vector2(u1, 0)], [tl, Vector2(u0, 0)], [bl, Vector2(u0, 1)], [br, Vector2(u1, 1)]]:
		wst.set_uv(v[1])
		wst.add_vertex(v[0])


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
	var on := []  # outward normal per point
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
		var h := 0.3 * clampf(reach / 1.2, 0.0, 1.0)
		lip.append(p + Vector3(0, 0.02, 0))
		crest.append(p + o * minf(0.55, reach * 0.4) + Vector3(0, h, 0))
		toe.append(p + o * reach)
		on.append(o)
	for i in m - 1:
		var inward: Vector3 = ins[clampi(i, 0, ins.size() - 1)]
		var a := i
		var b := i + 1
		if ((pts[b] as Vector3) - (pts[a] as Vector3)).cross(Vector3.UP).dot(inward) > 0.0:
			a = i + 1
			b = i
		var oa: Vector3 = on[a]
		var ob: Vector3 = on[b]
		var n1a := (oa * -0.48 + Vector3.UP).normalized()
		var n1b := (ob * -0.48 + Vector3.UP).normalized()
		var n2a := (oa * 0.3 + Vector3.UP).normalized()
		var n2b := (ob * 0.3 + Vector3.UP).normalized()
		for v in [[lip[a], n1a, 0.0], [lip[b], n1b, 0.0], [crest[b], n1b, 0.5], [lip[a], n1a, 0.0], [crest[b], n1b, 0.5], [crest[a], n1a, 0.5],
				[crest[a], n2a, 0.5], [crest[b], n2b, 0.5], [toe[b], n2b, 1.0], [crest[a], n2a, 0.5], [toe[b], n2b, 1.0], [toe[a], n2a, 1.0]]:
			bst.set_normal(v[1])
			bst.set_uv(Vector2(v[2], 0))
			bst.add_vertex(v[0])


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
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float n = texture(detail_tex, vec2(u * 0.37, v * 0.6)).r;
	float n2 = texture(detail_tex, wpos.xz * 0.9 + vec2(0.0, wpos.y * 1.3)).r;
	// planks: horizontal boards held by posts, earth bulging below them
	float plank_zone = smoothstep(0.86, 0.8, v);
	float row = fract(v * 6.5);
	float seam = smoothstep(0.0, 0.08, row) * smoothstep(1.0, 0.92, row);
	float post = smoothstep(0.08, 0.0, abs(fract(u * 0.62) - 0.5) - 0.04);
	vec3 wood = mix(vec3(0.22, 0.17, 0.11), vec3(0.34, 0.27, 0.18), n) * (0.75 + 0.25 * seam);
	wood = mix(wood, vec3(0.15, 0.11, 0.075), post);
	vec3 earth = mix(vec3(0.18, 0.14, 0.1), vec3(0.26, 0.2, 0.15), n2);
	vec3 col = mix(earth, wood, plank_zone * 0.92);
	col *= mix(0.7, 1.0, smoothstep(1.0, 0.25, v));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.4, 0.5 + (seam - 0.5) * 0.4 * plank_zone, 1.0);
}
"""

const BERM_SHADER := """
shader_type spatial;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = texture(detail_tex, wpos.xz / 2.6).r;
	float n2 = texture(detail_tex, wpos.xz / 4.1 + 0.3).r;
	float clods = smoothstep(0.6, 0.72, texture(detail_tex, wpos.xz * 1.1).r) * 0.6;
	vec3 fresh = mix(vec3(0.1, 0.072, 0.05), vec3(0.155, 0.115, 0.08), n);
	vec3 grassy = mix(vec3(0.1, 0.13, 0.045), vec3(0.16, 0.19, 0.075), n2);
	float g = smoothstep(0.45, 0.95, UV.x + (n2 - 0.5) * 0.5);
	vec3 col = mix(fresh, grassy, g * 0.85);
	col = mix(col, col * 0.75, clods * (1.0 - g));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.6, 0.5 + (clods - 0.5) * 0.3, 1.0);
}
"""

const FLOOR_SHADER := """
shader_type spatial;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = texture(detail_tex, wpos.xz / 1.1).r;
	float n2 = texture(detail_tex, wpos.xz / 3.3 + 0.5).r;
	float pud = smoothstep(0.62, 0.7, n2);
	vec3 col = mix(vec3(0.11, 0.085, 0.06), vec3(0.17, 0.13, 0.09), n);
	col = mix(col, vec3(0.05, 0.045, 0.04), pud);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.15, pud);
	SPECULAR = mix(0.2, 0.5, pud);
}
"""

const BOARD_SHADER := """
shader_type spatial;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	float slat = fract(UV.x * 3.2);
	float gap = smoothstep(0.0, 0.12, slat) * smoothstep(1.0, 0.88, slat);
	float rail = smoothstep(0.1, 0.0, abs(UV.y - 0.12)) + smoothstep(0.1, 0.0, abs(UV.y - 0.88));
	float n = texture(detail_tex, vec2(UV.x * 0.4, UV.y)).r;
	vec3 wood = mix(vec3(0.16, 0.12, 0.08), vec3(0.24, 0.18, 0.12), n);
	vec3 col = mix(vec3(0.05, 0.04, 0.03), wood, max(gap, rail));
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
