class_name Grass
extends Node3D
## Instanced grass clumps, bushes and stones in 32 m chunks. Placement follows
## the ground's biome map and avoids roads and building floors. Rebuilt
## progressively (a few chunks per frame) when the map or settings change.

const CHUNK := 32.0
const HALF := 128.0

var atmo: Atmosphere
var mat: ShaderMaterial
var bush_mat: ShaderMaterial
var stone_mat: StandardMaterial3D
var clump: ArrayMesh
var scar_img: Image
var scar_tex: ImageTexture
var _scar_dirty := false
var bush: ArrayMesh
var stone: ArrayMesh
var level := -1
var _queue: Array = []
var _rebuild_t := -1.0
var _blocked := PackedByteArray()
var _built := {}  # Vector2i -> Array of nodes


func _ready() -> void:
	clump = _make_clump()
	bush = _make_bush()
	stone = _make_stone()
	scar_img = Image.create(256, 256, false, Image.FORMAT_L8)
	scar_tex = ImageTexture.create_from_image(scar_img)
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	mat.shader = sh
	mat.set_shader_parameter("scar", scar_tex)
	bush_mat = ShaderMaterial.new()
	var bs := Shader.new()
	bs.code = BUSH_SHADER
	bush_mat.shader = bs
	stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.4, 0.37)
	stone_mat.roughness = 0.9
	request_rebuild(1.2)


func set_deform(t: Texture2D) -> void:
	mat.set_shader_parameter("deform_tex", t)
	bush_mat.set_shader_parameter("deform_tex", t)


func set_trench_mask(t: Texture2D) -> void:
	mat.set_shader_parameter("trench_mask", t)
	bush_mat.set_shader_parameter("trench_mask", t)


## Marks a blast scar on the grass (craters: full, near misses: lighter).
func scar(p: Vector3, r: float, strength := 1.0) -> void:
	var ri := int(ceil(r)) + 1
	var cx := floori(p.x + 128.0)
	var cz := floori(p.z + 128.0)
	for z in range(maxi(0, cz - ri), mini(256, cz + ri + 1)):
		for x in range(maxi(0, cx - ri), mini(256, cx + ri + 1)):
			var d := Vector2(x + 0.5 - 128.0 - p.x, z + 0.5 - 128.0 - p.z).length()
			if d > r:
				continue
			var v := strength * clampf(1.2 - d / r, 0.0, 1.0)
			var cur := scar_img.get_pixel(x, z).r
			if v > cur:
				scar_img.set_pixel(x, z, Color(v, v, v))
	_scar_dirty = true


func apply_settings() -> void:
	var lvl := int(Settings.get_v("grass"))
	if lvl != level:
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
	if _rebuild_t > 0.0:
		_rebuild_t -= dt
		if _rebuild_t <= 0.0:
			_start_rebuild()
	var n := 0
	while not _queue.is_empty() and n < 12:
		_build_chunk(_queue.pop_front())
		n += 1


func _start_rebuild() -> void:
	level = int(Settings.get_v("grass"))
	for k in _built:
		for node in _built[k]:
			node.queue_free()
	_built.clear()
	_queue.clear()
	if level == 0:
		return
	_make_blocked()
	var nc := int(HALF / CHUNK)
	for cx in range(-nc, nc):
		for cz in range(-nc, nc):
			_queue.append(Vector2i(cx, cz))
	# build the chunks nearest the camera first
	var cam: Vector3 = atmo.world.cam.focus_pos if atmo.world.cam else Vector3.ZERO
	var hc := CHUNK * 0.5
	_queue.sort_custom(func(a, b): return Vector2(a.x * CHUNK + hc - cam.x, a.y * CHUNK + hc - cam.z).length() < Vector2(b.x * CHUNK + hc - cam.x, b.y * CHUNK + hc - cam.z).length())


## 1 m grid of places grass must not grow: building floors, walls, roads.
func _make_blocked() -> void:
	_blocked = PackedByteArray()
	_blocked.resize(256 * 256)
	var w := atmo.world
	for st in w.structures:
		if st.gone:
			continue
		var big: bool = st.skind in ["floor", "fob", "barracks", "factory", "medic_tent", "research", "depot", "helipad", "bunker", "mortar_pit", "hmg_nest", "mg_nest", "at_post", "tunnel", "house_wall", "tall_wall", "concrete_wall", "wreck", "car", "crates"]
		if not big:
			continue
		var h: Vector2 = st.foot + Vector2(0.4, 0.4)
		var r := h.length()
		for x in range(floori(st.position.x - r), floori(st.position.x + r) + 1):
			for z in range(floori(st.position.z - r), floori(st.position.z + r) + 1):
				if Defs.point_in_obb(Vector2(x + 0.5, z + 0.5), Vector2(st.position.x, st.position.z), h, st.yaw):
					_mark(x, z)
	# sidewalks, squares, gardens and the like
	for e in w.decor:
		if not String(e[0]) in ["walk", "pave", "junction", "soft", "lot_pave", "drive", "path", "garden"]:
			continue
		var s3: Vector3 = e[3]
		var h3 := Vector2(s3.x * 0.5 + 0.2, s3.z * 0.5 + 0.2)
		var c3: Vector3 = e[1]
		var r3 := h3.length()
		for x in range(floori(c3.x - r3), floori(c3.x + r3) + 1):
			for z in range(floori(c3.z - r3), floori(c3.z + r3) + 1):
				if Defs.point_in_obb(Vector2(x + 0.5, z + 0.5), Vector2(c3.x, c3.z), h3, float(e[2])):
					_mark(x, z)
	for t in 3:
		for poly in w.roads[t]:
			var pts: PackedVector3Array = poly
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var steps := int(a.distance_to(b) / 0.8) + 1
				for k in steps + 1:
					var p := a.lerp(b, float(k) / steps)
					for dx in range(-3, 4):
						for dz in range(-3, 4):
							if dx * dx + dz * dz <= 8:
								_mark(floori(p.x) + dx, floori(p.z) + dz)


func _mark(x: int, z: int) -> void:
	var ix := x + 128
	var iz := z + 128
	if ix >= 0 and iz >= 0 and ix < 256 and iz < 256:
		_blocked[iz * 256 + ix] = 1


func _is_blocked(p: Vector3) -> bool:
	var ix := floori(p.x) + 128
	var iz := floori(p.z) + 128
	if ix < 0 or iz < 0 or ix >= 256 or iz >= 256:
		return false
	return _blocked[iz * 256 + ix] == 1


func _build_chunk(c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c) + int(atmo.world.settings.get("seed", 1))
	var origin := Vector3(c.x * CHUNK, 0, c.y * CHUNK)
	var density := 0.45 if level == 1 else 1.0
	var count := int(CHUNK * CHUNK * density)
	var xf := []
	var cd := []
	var bushes := []
	var stones := []
	for i in count:
		var p := origin + Vector3(rng.randf() * CHUNK, 0, rng.randf() * CHUNK)
		if absf(p.x) > HALF + 14.0 or absf(p.z) > HALF + 14.0 or _is_blocked(p):
			continue
		var g := atmo.grass_amount(p)
		if rng.randf() > g * 0.92 + 0.04:
			if rng.randf() < 0.004:
				stones.append(p)
			continue
		var s := rng.randf_range(0.75, 1.3) * (0.65 + 0.5 * g)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.35), s))
		xf.append(Transform3D(basis, p))
		cd.append(Color(g, rng.randf(), 0, 0))
		if rng.randf() < 0.012 and g > 0.6:
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
			var s3 := rng.randf_range(0.25, 0.8)
			sx.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)).scaled(Vector3(s3, s3 * 0.6, s3)), p + Vector3(0, s3 * 0.15, 0)))
			sc.append(Color(0, 0, 0, 0))
		var sn := _mm(stone, stone_mat, sx, sc, 140.0)
		sn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		nodes.append(sn)
	_built[c] = nodes


func _mm(mesh: Mesh, m: Material, xf: Array, cd: Array, vis: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_custom_data(i, cd[i])
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
	for b in 15:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.32
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var yaw := rng.randf() * TAU
		var side := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.03, 0.05)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.22)
		var h := rng.randf_range(0.22, 0.55)
		var pts := []
		for k in 4:
			var t := float(k) / 3.0
			var w := 1.0 - t * 0.92
			var c := base + lean * t * t + Vector3(0, h * t, 0)
			pts.append([c - side * w, c + side * w, t])
		for k in 3:
			var p0: Array = pts[k]
			var p1: Array = pts[k + 1]
			var quad := [[p0[0], p0[2]], [p0[1], p0[2]], [p1[1], p1[2]], [p0[0], p0[2]], [p1[1], p1[2]], [p1[0], p1[2]]]
			for q in quad:
				st.set_normal(Vector3(0, 1, 0))
				st.set_uv(Vector2(0.5, q[1]))
				st.add_vertex(q[0])
	return st.commit()


func _make_bush() -> ArrayMesh:
	var st := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var sph := SphereMesh.new()
	sph.radial_segments = 10
	sph.rings = 6
	var arrays := sph.get_mesh_arrays()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var off := Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.25, 0.55), rng.randf_range(-0.45, 0.45))
		var sc := rng.randf_range(0.45, 0.75)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for j in idx:
			st.set_normal(norms[j])
			st.add_vertex(verts[j] * sc + off)
	return st.commit()


func _make_stone() -> ArrayMesh:
	var sph := SphereMesh.new()
	sph.radial_segments = 7
	sph.rings = 4
	var arrays := sph.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in verts.size():
		verts[i] *= rng.randf_range(0.8, 1.15)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 base_col : source_color = vec3(0.14, 0.19, 0.07);
uniform vec3 mid_col : source_color = vec3(0.24, 0.31, 0.1);
uniform vec3 tip_col : source_color = vec3(0.47, 0.5, 0.2);
uniform vec3 dry_col : source_color = vec3(0.5, 0.45, 0.24);
uniform float wind = 0.11;
uniform sampler2D scar : filter_linear, repeat_disable;
uniform sampler2D trench_mask : filter_linear, repeat_disable;
uniform sampler2D deform_tex : filter_linear, repeat_disable;

varying float h;
varying float g;
varying float rnd;
varying float burnt;

void vertex() {
	h = UV.y;
	g = INSTANCE_CUSTOM.r;
	rnd = INSTANCE_CUSTOM.g;
	vec3 o = MODEL_MATRIX[3].xyz;
	// shell holes and blast scars flatten and scorch the grass
	burnt = texture(scar, (o.xz + 128.0) / 256.0).r;
	// nothing grows in a trench
	if (textureLod(trench_mask, (o.xz + 128.0) / 256.0, 0.0).r > 0.3) {
		VERTEX *= 0.0;
	}
	VERTEX.y *= 1.0 - burnt * 0.85;
	VERTEX.xz *= 1.0 + burnt * 0.4;
	// stand on the ground as it is now (shell holes, rims)
	VERTEX.y += textureLod(deform_tex, (o.xz + 128.0) / 256.0, 0.0).r / max(0.05, length(MODEL_MATRIX[1].xyz));
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
	col = mix(col, dry_col, clamp((1.0 - g) * 0.8 + (rnd - 0.7) * 0.6, 0.0, 0.85) * smoothstep(0.2, 1.0, h));
	col *= 0.85 + 0.3 * rnd;
	col = mix(col, vec3(0.09, 0.075, 0.05), burnt * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.35, 0.4, 0.15) * h * (1.0 - burnt);
	AO = mix(0.78, 1.0, h);
	AO_LIGHT_AFFECT = 0.6;
}
"""

const BUSH_SHADER := """
shader_type spatial;
render_mode specular_disabled;
varying vec3 lp;
varying float rnd;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
uniform sampler2D trench_mask : filter_linear, repeat_disable;
uniform sampler2D deform_tex : filter_linear, repeat_disable;
void vertex() {
	if (textureLod(trench_mask, (MODEL_MATRIX[3].xz + 128.0) / 256.0, 0.0).r > 0.3) {
		VERTEX *= 0.0;
	}
	float gd = textureLod(deform_tex, (MODEL_MATRIX[3].xz + 128.0) / 256.0, 0.0).r;
	if (gd < -0.12) {
		VERTEX *= 0.0;  // blown away
	}
	VERTEX.y += gd / max(0.05, length(MODEL_MATRIX[1].xyz));
	rnd = INSTANCE_CUSTOM.r;
	vec3 o = MODEL_MATRIX[3].xyz;
	float n = sin(VERTEX.x * 9.0 + rnd * 7.0) * sin(VERTEX.y * 8.0) * sin(VERTEX.z * 10.0);
	VERTEX += NORMAL * n * 0.08;
	float t = TIME * 1.3 + o.x * 0.3;
	VERTEX.x += sin(t) * 0.03 * VERTEX.y;
	lp = VERTEX;
}
void fragment() {
	float leaf = 0.5 + 0.5 * sin(lp.x * 23.0 + sin(lp.y * 19.0) * 2.0) * sin(lp.z * 21.0 + sin(lp.x * 17.0) * 2.0);
	vec3 col = mix(vec3(0.045, 0.075, 0.03), vec3(0.12, 0.16, 0.055), leaf * 0.7 + rnd * 0.3);
	col = mix(col, col * vec3(1.25, 1.05, 0.7), step(0.6, rnd) * 0.6);
	float up = smoothstep(-0.2, 0.9, lp.y);
	col *= 0.55 + 0.55 * up;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	AO = 0.5 + 0.5 * up;
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = vec3(0.08, 0.1, 0.035);
	vec3 q = lp * 9.0 + rnd * 13.0;
	vec3 wob = vec3(sin(q.y * 1.7 + q.z * 2.3), sin(q.z * 1.9 + q.x * 2.1), sin(q.x * 2.2 + q.y * 1.6));
	NORMAL = normalize(NORMAL + wob * 0.35);
}
"""
