class_name Mats
extends RefCounted
## Procedural surface materials: one uber-shader with a pattern switch
## (brick, plaster, concrete, sandbags, wood, camouflage, worn paint, ...).
## Patterns are evaluated in world space (or object space for things that
## move) and get bump-mapped relief, grime near the ground and per-object
## variation. Per-instance tint comes from an instance uniform.

const PLAIN := 0
const BRICK := 1
const PLASTER := 2
const CONCRETE := 3
const SANDBAG := 4
const WOOD := 5
const CAMO := 6
const PAINT := 7
const EARTH := 8
const CORRUGATED := 9
const CANVAS := 10
const STONE := 11
const BARK := 12
const TRACK := 13
const SKIN := 14
const TILES := 15
const HESCO := 16

static var _shader: Shader
static var _cache := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SURFACE_SHADER
	return _shader


## kind: a preset name (see _preset). Returns a shared material.
static func get_mat(kind: String) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var m := ShaderMaterial.new()
	m.shader = shader()
	var p := _preset(kind)
	for k in p:
		m.set_shader_parameter(k, p[k])
	_cache[kind] = m
	return m


## Applies a material to a mesh instance with an optional per-instance tint.
static func apply(mi: GeometryInstance3D, kind: String, tint := Color(1, 1, 1)) -> GeometryInstance3D:
	mi.material_override = get_mat(kind)
	if tint != Color(1, 1, 1):
		mi.set_instance_shader_parameter("tint", tint)
	return mi


## Tint that turns the preset's base colour into `c` (keeps per-part colours).
static func tint_for(kind: String, c: Color) -> Color:
	var b: Color = _preset(kind).get("col_a", Color(0.6, 0.6, 0.6))
	return Color(clampf(c.r / maxf(b.r, 0.02), 0.25, 2.5), clampf(c.g / maxf(b.g, 0.02), 0.25, 2.5), clampf(c.b / maxf(b.b, 0.02), 0.25, 2.5))


static var _foliage: ShaderMaterial


## Lumpy, wind-swayed leaf clusters with translucency (instance uniform tint).
static func foliage() -> ShaderMaterial:
	if _foliage == null:
		var sh := Shader.new()
		sh.code = FOLIAGE_SHADER
		_foliage = ShaderMaterial.new()
		_foliage.shader = sh
	return _foliage


static var _vc_cache := {}


## Same material, but reading the part colour from vertex colours (for merged meshes).
static func vc_variant(m: ShaderMaterial) -> ShaderMaterial:
	var id := m.get_instance_id()
	if _vc_cache.has(id):
		return _vc_cache[id]
	var v := m.duplicate() as ShaderMaterial
	v.set_shader_parameter("use_vcolor", true)
	_vc_cache[id] = v
	return v


## Bakes every static part under `root` that uses one of our shaders into a single
## mesh per material, carrying each part's tint as vertex colour. A ruined house
## or a tree goes from a dozen render objects to one or two.
static func merge_static(root: Node3D, keep: Array = [], deep := true, remerge := false, single := false) -> void:
	var groups := {}
	var victims: Array = []
	_collect(root, Transform3D.IDENTITY, groups, victims, keep, deep, remerge, single)
	if single and not groups.is_empty():
		# one mesh, a surface per material: one render instance to move, not a dozen
		var am2 := ArrayMesh.new()
		var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for key in groups:
			var g2: Dictionary = groups[key]
			var arrays2 := []
			arrays2.resize(Mesh.ARRAY_MAX)
			arrays2[Mesh.ARRAY_VERTEX] = g2.v
			arrays2[Mesh.ARRAY_NORMAL] = g2.n
			arrays2[Mesh.ARRAY_COLOR] = g2.c
			arrays2[Mesh.ARRAY_INDEX] = g2.i
			am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
			am2.surface_set_material(am2.get_surface_count() - 1, g2.mat if g2.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g2.mat))
			if int(g2.shadow) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mi2 := MeshInstance3D.new()
		mi2.mesh = am2
		mi2.cast_shadow = shadow
		root.add_child(mi2)
		for v in victims:
			v.get_parent().remove_child(v)
			v.queue_free()
		return
	for key in groups:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_INDEX] = g.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat if g.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g.mat)
		mi.cast_shadow = g.shadow
		root.add_child(mi)
	for v in victims:
		v.get_parent().remove_child(v)
		v.queue_free()


static func _collect(node: Node, xf: Transform3D, groups: Dictionary, victims: Array, keep: Array, deep := true, remerge := false, single := false) -> void:
	for c in node.get_children():
		if c in keep or not (c is Node3D):
			continue
		if not (c is MeshInstance3D) and not (c as Node3D).visible:
			continue  # a hidden attachment (the slung rifle on a corpse) stays out of the bake
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			# every surface must be one of ours (the override, or each surface's own material)
			var mats := []
			var ok := true
			for si0 in mi.mesh.get_surface_count():
				var m0 = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si0)
				var sm0 := m0 as ShaderMaterial
				var vc0: bool = sm0 != null and sm0.get_shader_parameter("use_vcolor") == true
				if sm0 == null or not (sm0.shader == shader() or sm0 == _foliage or (vc0 and sm0.shader == shader())) or (vc0 and not remerge):
					ok = false
					break
				mats.append(sm0)
			if ok and not mats.is_empty():
				var tint = mi.get_instance_shader_parameter("tint")
				# the tint uniform is sRGB (source_color); vertex colours are read as linear
				var col: Color = (tint as Color).srgb_to_linear() if tint is Color else Color(1, 1, 1)
				var nb := Transform3D(cx.basis.inverse().transposed(), Vector3.ZERO)
				for si in mi.mesh.get_surface_count():
					var sm: ShaderMaterial = mats[si]
					var vc: bool = sm.get_shader_parameter("use_vcolor") == true
					var key := str(sm.get_instance_id()) if single else "%d|%d" % [sm.get_instance_id(), mi.cast_shadow]
					if not groups.has(key):
						groups[key] = {"mat": sm, "shadow": mi.cast_shadow, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
					var g: Dictionary = groups[key]
					if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						g.shadow = mi.cast_shadow
					var arr := mi.mesh.surface_get_arrays(si)
					var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					var base: int = g.v.size()
					g.v.append_array(cx * verts)
					g.n.append_array(nb * norms)
					var cols := PackedColorArray()
					if vc and arr[Mesh.ARRAY_COLOR] != null and (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size() == verts.size():
						cols = arr[Mesh.ARRAY_COLOR]
					else:
						cols.resize(verts.size())
						cols.fill(col)
					g.c.append_array(cols)
					var idx = arr[Mesh.ARRAY_INDEX]
					if idx == null or (idx as PackedInt32Array).is_empty():
						idx = PackedInt32Array(range(verts.size()))
					var ii := (idx as PackedInt32Array).duplicate()
					for k in ii.size():
						ii[k] += base
					g.i.append_array(ii)
				victims.append(mi)
				continue
		if deep:
			_collect(c, cx, groups, victims, keep, deep, remerge, single)


static var _netting: ShaderMaterial


## Camouflage netting: ragged holes (discard) so it throws dappled shadows.
static func netting() -> ShaderMaterial:
	if _netting == null:
		var sh := Shader.new()
		sh.code = NETTING_SHADER
		_netting = ShaderMaterial.new()
		_netting.shader = sh
	return _netting


static func _preset(kind: String) -> Dictionary:
	match kind:
		"steel":
			return {"pattern": PAINT, "col_a": Color(0.25, 0.26, 0.27), "col_b": Color(0.4, 0.38, 0.35), "rough": 0.6, "metal": 0.6, "bump": 0.8, "grime": 0.4, "rust": 0.3}
		"floor_tiles":
			return {"pattern": TILES, "col_a": Color(0.45, 0.42, 0.38), "col_b": Color(0.3, 0.28, 0.25), "col_c": Color(0.52, 0.4, 0.32), "rough": 0.7, "bump": 0.8, "grime": 0.0}
		"car_paint":
			return {"pattern": PAINT, "col_a": Color(0.5, 0.5, 0.5), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.3, "metal": 0.35, "bump": 0.4, "grime": 0.8, "rust": 0.4}
		"wood_painted":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.34, 0.22), "col_b": Color(0.22, 0.25, 0.16), "rough": 0.8, "bump": 1.0, "grime": 0.7}
		"gunmetal_w":
			return {"pattern": PAINT, "col_a": Color(0.1, 0.1, 0.1), "col_b": Color(0.3, 0.29, 0.28), "rough": 0.45, "metal": 0.7, "bump": 0.2, "grime": 0.0}
		"plaster":
			return {"pattern": PLASTER, "col_a": Color(0.74, 0.69, 0.6), "col_b": Color(0.6, 0.57, 0.5), "col_c": Color(0.5, 0.33, 0.26), "col_d": Color(0.45, 0.42, 0.37), "rough": 0.92, "bump": 1.2, "grime": 0.7}
		"brick":
			return {"pattern": BRICK, "col_a": Color(0.56, 0.3, 0.21), "col_b": Color(0.62, 0.58, 0.52), "col_c": Color(0.42, 0.24, 0.17), "rough": 0.9, "bump": 1.4, "grime": 0.6}
		"concrete":
			return {"pattern": CONCRETE, "col_a": Color(0.6, 0.6, 0.57), "col_b": Color(0.42, 0.41, 0.38), "rough": 0.88, "bump": 0.8, "grime": 0.7}
		"concrete_floor":
			return {"pattern": CONCRETE, "col_a": Color(0.42, 0.41, 0.38), "col_b": Color(0.3, 0.28, 0.25), "rough": 0.9, "bump": 0.6, "grime": 0.0}
		"sandbag":
			return {"pattern": SANDBAG, "col_a": Color(0.62, 0.55, 0.39), "col_b": Color(0.45, 0.39, 0.26), "rough": 0.95, "bump": 2.2, "grime": 0.6}
		"wood":
			return {"pattern": WOOD, "col_a": Color(0.5, 0.37, 0.23), "col_b": Color(0.34, 0.24, 0.14), "rough": 0.85, "bump": 1.2, "grime": 0.5}
		"wood_dark":
			return {"pattern": WOOD, "col_a": Color(0.33, 0.25, 0.17), "col_b": Color(0.22, 0.16, 0.1), "rough": 0.88, "bump": 1.2, "grime": 0.5}
		"earth":
			return {"pattern": EARTH, "col_a": Color(0.33, 0.26, 0.17), "col_b": Color(0.22, 0.17, 0.11), "rough": 0.97, "bump": 1.6, "grime": 0.0}
		"stone":
			return {"pattern": STONE, "col_a": Color(0.58, 0.55, 0.5), "col_b": Color(0.42, 0.4, 0.36), "col_c": Color(0.5, 0.46, 0.4), "rough": 0.9, "bump": 2.0, "grime": 0.7}
		"rubble":
			return {"pattern": STONE, "col_a": Color(0.55, 0.52, 0.47), "col_b": Color(0.36, 0.34, 0.3), "col_c": Color(0.5, 0.33, 0.25), "rough": 0.95, "bump": 2.4, "grime": 0.5, "scale": 2.0}
		"roof_tile":
			return {"pattern": BRICK, "col_a": Color(0.5, 0.22, 0.14), "col_b": Color(0.36, 0.17, 0.11), "col_c": Color(0.44, 0.2, 0.13), "rough": 0.82, "bump": 1.8, "grime": 0.55, "scale": 0.7}
		"corrugated":
			return {"pattern": CORRUGATED, "col_a": Color(0.5, 0.51, 0.49), "col_b": Color(0.42, 0.24, 0.12), "rough": 0.55, "metal": 0.5, "bump": 1.0, "grime": 0.6}
		"canvas":
			return {"pattern": CANVAS, "col_a": Color(0.36, 0.38, 0.25), "col_b": Color(0.28, 0.3, 0.2), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"canvas_white":
			return {"pattern": CANVAS, "col_a": Color(0.85, 0.84, 0.79), "col_b": Color(0.7, 0.68, 0.62), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"bark":
			return {"pattern": BARK, "col_a": Color(0.32, 0.25, 0.18), "col_b": Color(0.18, 0.14, 0.1), "rough": 0.95, "bump": 2.0, "grime": 0.2}
		"paint":
			return {"pattern": PAINT, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.38, 0.37, 0.35), "rough": 0.45, "metal": 0.15, "bump": 0.6, "grime": 0.7}
		"metal_dark":
			return {"pattern": PAINT, "col_a": Color(0.17, 0.17, 0.17), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.5, "metal": 0.6, "bump": 0.5, "grime": 0.3}
		"burnt":
			return {"pattern": PAINT, "col_a": Color(0.085, 0.08, 0.075), "col_b": Color(0.2, 0.17, 0.15), "rough": 0.9, "metal": 0.25, "bump": 1.2, "grime": 0.2, "rust": 0.3, "scale": 1.6}
		"plain":
			return {"pattern": PLAIN, "col_a": Color(0.55, 0.55, 0.55), "rough": 0.85, "bump": 0.2, "grime": 0.3}
		"plain_dark":
			return {"pattern": PLAIN, "col_a": Color(0.18, 0.18, 0.18), "rough": 0.8, "bump": 0.2, "grime": 0.2}
		"rubber":
			return {"pattern": PLAIN, "col_a": Color(0.07, 0.07, 0.07), "rough": 0.85, "bump": 0.3, "grime": 0.4}
		"glass":
			return {"pattern": PLAIN, "col_a": Color(0.08, 0.1, 0.12), "rough": 0.08, "metal": 0.4, "bump": 0.0, "grime": 0.0}
		"track":
			return {"pattern": TRACK, "col_a": Color(0.13, 0.12, 0.11), "col_b": Color(0.3, 0.27, 0.23), "rough": 0.7, "metal": 0.5, "bump": 2.0, "grime": 0.5, "local_space": true}
		"camo_army":
			return {"pattern": CAMO, "col_a": Color(0.36, 0.39, 0.25), "col_b": Color(0.24, 0.29, 0.17), "col_c": Color(0.38, 0.32, 0.21), "col_d": Color(0.12, 0.12, 0.1), "scale": 6.0, "rough": 0.9, "bump": 0.5, "grime": 0.3, "local_space": true}
		"camo_rebel":
			return {"pattern": CAMO, "col_a": Color(0.52, 0.46, 0.34), "col_b": Color(0.4, 0.33, 0.22), "col_c": Color(0.33, 0.33, 0.27), "col_d": Color(0.2, 0.17, 0.12), "scale": 5.0, "rough": 0.9, "bump": 0.5, "grime": 0.3, "local_space": true}
		"camo_tank":
			return {"pattern": CAMO, "col_a": Color(0.31, 0.34, 0.22), "col_b": Color(0.22, 0.26, 0.16), "col_c": Color(0.33, 0.29, 0.2), "col_d": Color(0.13, 0.13, 0.11), "scale": 0.9, "rough": 0.6, "metal": 0.3, "bump": 0.6, "grime": 0.8, "local_space": true}
		"camo_tank_rebel":
			return {"pattern": CAMO, "col_a": Color(0.5, 0.45, 0.32), "col_b": Color(0.38, 0.33, 0.23), "col_c": Color(0.44, 0.38, 0.27), "col_d": Color(0.24, 0.21, 0.16), "scale": 0.6, "rough": 0.6, "metal": 0.3, "bump": 0.6, "grime": 0.8, "local_space": true}
		"fabric":
			return {"pattern": CANVAS, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.48, 0.48, 0.48), "scale": 3.0, "rough": 0.95, "bump": 0.4, "grime": 0.2, "local_space": true}
		"hesco":
			return {"pattern": HESCO, "col_a": Color(0.6, 0.55, 0.42), "col_b": Color(0.4, 0.35, 0.26), "col_c": Color(0.22, 0.21, 0.2), "rough": 0.95, "bump": 1.6, "grime": 0.8}
		"bag":
			return {"pattern": CANVAS, "col_a": Color(0.5, 0.45, 0.33), "col_b": Color(0.4, 0.36, 0.26), "scale": 1.6, "rough": 0.97, "bump": 0.8, "grime": 0.7, "local_space": true, "use_vcolor": true}
		"canvas_l":
			return {"pattern": CANVAS, "col_a": Color(0.42, 0.4, 0.29), "col_b": Color(0.33, 0.31, 0.22), "scale": 4.0, "rough": 0.95, "bump": 0.6, "grime": 0.2, "local_space": true}
		"wood_l":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.2, 0.12), "col_b": Color(0.2, 0.13, 0.08), "scale": 3.0, "rough": 0.6, "bump": 0.4, "grime": 0.0, "local_space": true}
		"skin":
			return {"pattern": SKIN, "col_a": Color(0.8, 0.62, 0.5), "rough": 0.6, "bump": 0.0, "grime": 0.0, "local_space": true}
		"gunmetal":
			return {"pattern": PAINT, "col_a": Color(0.1, 0.1, 0.1), "col_b": Color(0.32, 0.31, 0.3), "rough": 0.4, "metal": 0.7, "bump": 0.2, "grime": 0.0, "local_space": true}
		"boot":
			return {"pattern": PLAIN, "col_a": Color(0.1, 0.08, 0.06), "rough": 0.7, "bump": 0.0, "grime": 0.0}
	return {"pattern": PLAIN, "col_a": Color(0.6, 0.6, 0.6), "rough": 0.85}


const SURFACE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform int pattern = 0;
uniform vec3 col_a : source_color = vec3(0.6);
uniform vec3 col_b : source_color = vec3(0.4);
uniform vec3 col_c : source_color = vec3(0.5);
uniform vec3 col_d : source_color = vec3(0.2);
uniform float scale = 1.0;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float bump = 1.0;
uniform float grime = 0.5;
uniform float rust = 0.0;
uniform bool local_space = false;
uniform bool use_vcolor = false;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec3 pofs = vec3(0.0);

varying vec3 tp;
varying vec3 tn;
varying vec3 wpos;
varying vec3 seed;

float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = MODEL_MATRIX[3].xyz;
	if (local_space) {
		tp = VERTEX + pofs;
		tn = NORMAL;
	} else {
		tp = wpos;
		tn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	vec3 an = abs(tn);
	vec2 uv;
	if (an.y > an.x && an.y > an.z) { uv = tp.xz; }
	else if (an.x > an.z) { uv = vec2(tp.z, tp.y); }
	else { uv = vec2(tp.x, tp.y); }
	vec2 off = vec2(h12(seed.xz * 0.37), h12(seed.zx * 0.71)) * 37.0;
	uv *= scale;
	vec3 col = col_a;
	float h = 0.5;
	float r = rough;
	float m = metal;
	float n1 = vnoise(uv * 3.1 + off);
	if (pattern == 1 || pattern == 2) {
		// brick (pattern 2 = plaster with chipped areas showing brick)
		vec2 bs = vec2(0.25, 0.085);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float mx = smoothstep(0.0, 0.05, f.x) * smoothstep(1.0, 0.95, f.x);
		float my = smoothstep(0.0, 0.14, f.y) * smoothstep(1.0, 0.86, f.y);
		float b = mx * my;
		float rb = h12(cell + off);
		vec3 bc = (pattern == 1 ? mix(col_a, col_c, rb) : mix(col_c, col_c * 0.75, rb)) * (0.85 + 0.3 * vnoise(uv * 41.0));
		vec3 mortar = (pattern == 1 ? col_b : col_b * 0.9) * (0.9 + 0.2 * vnoise(uv * 27.0));
		vec3 brick = mix(mortar, bc, b);
		float bh = b * 0.7 + vnoise(uv * 35.0) * 0.15;
		if (pattern == 1) {
			col = brick; h = bh;
		} else {
			float n = fbm(uv * 0.9 + off);
			float chip = smoothstep(0.69, 0.72, n + (1.0 - smoothstep(0.0, 1.2, wpos.y)) * 0.06);
			vec3 pl = col_a * (0.88 + 0.18 * fbm(uv * 2.3 + off));
			float streak = fbm(vec2(uv.x * 3.0, uv.y * 0.35) + off);
			pl = mix(pl, col_d, smoothstep(0.5, 0.8, streak) * 0.45);
			col = mix(pl, brick, chip);
			h = mix(0.9 + vnoise(uv * 18.0) * 0.1, bh * 0.6, chip);
			r = mix(rough, 0.95, chip);
		}
	} else if (pattern == 3) {
		col = col_a * (0.86 + 0.22 * fbm(uv * 2.1 + off));
		float st = fbm(uv * 0.6 + off * 0.3);
		col = mix(col, col_b, smoothstep(0.45, 0.8, st) * 0.6);
		vec2 g = abs(fract(uv / vec2(2.0, 1.25)) - 0.5);
		float seam = smoothstep(0.485, 0.497, max(g.x, g.y));
		float pits = smoothstep(0.93, 0.97, h12(floor(uv * 60.0) + off));
		col *= 1.0 - seam * 0.35 - pits * 0.25;
		h = 1.0 - seam * 0.6 - pits * 0.5 + vnoise(uv * 25.0) * 0.08;
	} else if (pattern == 4) {
		vec2 bs = vec2(0.58, 0.2);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5 + h12(vec2(row, off.x)) * 0.3;
		vec2 f = fract(q) - 0.5;
		float d = length(f * vec2(1.0, 1.7));
		float bulge = clamp(1.0 - d * d * 2.4, 0.0, 1.0);
		float weave = (sin(uv.x * 420.0) * sin(uv.y * 420.0)) * 0.5 + 0.5;
		col = mix(col_b, col_a, bulge * 0.7 + 0.3) * (0.88 + 0.18 * vnoise(uv * 13.0 + off) + weave * 0.04);
		h = bulge;
		r = 0.97;
	} else if (pattern == 5) {
		float pw = 0.19;
		float row = floor(uv.y / pw);
		float fy = fract(uv.y / pw);
		float gap = smoothstep(0.0, 0.06, fy) * smoothstep(1.0, 0.94, fy);
		float grain = fbm(vec2(uv.x * 1.3 + row * 7.3, uv.y * 30.0));
		col = mix(col_b, col_a, grain) * (0.85 + 0.25 * h12(vec2(row, off.y)));
		col *= 0.5 + 0.5 * gap;
		h = gap * (0.8 + grain * 0.2);
	} else if (pattern == 6) {
		float c1 = fbm(uv * 1.0 + off);
		float c2 = fbm(uv * 1.25 + off + 13.0);
		float c3 = fbm(uv * 1.6 + off + 29.0);
		col = col_a;
		col = mix(col, col_b, smoothstep(0.5, 0.53, c1));
		col = mix(col, col_c, smoothstep(0.56, 0.59, c2));
		col = mix(col, col_d, smoothstep(0.62, 0.65, c3));
		col *= 0.92 + 0.12 * vnoise(uv * 23.0);
		h = 0.5 + vnoise(uv * 30.0) * 0.2;
	} else if (pattern == 7) {
		col = col_a * (0.9 + 0.14 * vnoise(uv * 7.0 + off));
		float wear = smoothstep(0.68, 0.74, fbm(uv * 3.5 + off));
		col = mix(col, col_b, wear);
		m = mix(metal, 0.85, wear);
		r = mix(rough, 0.35, wear);
		float rs = fbm(vec2(uv.x * 5.0, uv.y * 0.6) + off) * (0.4 + rust);
		col = mix(col, vec3(0.32, 0.17, 0.08), smoothstep(0.55, 0.8, rs) * (0.08 + rust * 0.7));
		h = 0.6 - wear * 0.3 + vnoise(uv * 50.0) * 0.05;
	} else if (pattern == 8) {
		float n = fbm(uv * 1.7 + off);
		col = mix(col_b, col_a, n) * (0.85 + 0.25 * vnoise(uv * 19.0));
		float peb = smoothstep(0.86, 0.93, h12(floor(uv * 14.0) + off));
		col = mix(col, vec3(0.45, 0.42, 0.38), peb * 0.7);
		h = n * 0.7 + peb * 0.4;
	} else if (pattern == 9) {
		float ridge = 0.5 + 0.5 * sin(uv.x * 6.2831 / 0.09);
		col = col_a * (0.82 + 0.18 * ridge) * (0.9 + 0.15 * vnoise(uv * 4.0 + off));
		float rs = fbm(vec2(uv.x * 2.0, uv.y * 0.4) + off);
		col = mix(col, col_b, smoothstep(0.55, 0.85, rs) * 0.8);
		h = ridge;
	} else if (pattern == 10) {
		float weave = (sin(uv.x * 380.0) * sin(uv.y * 380.0)) * 0.5 + 0.5;
		float fold = fbm(uv * 1.3 + off);
		col = mix(col_b, col_a, fold) * (0.95 + weave * 0.08);
		h = fold * 0.8 + weave * 0.1;
	} else if (pattern == 11) {
		vec2 bs = vec2(0.5, 0.3);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += h12(vec2(row, 3.7 + off.x));
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.12, f.y) * smoothstep(1.0, 0.88, f.y);
		float rb = h12(cell + off);
		vec3 sc = mix(col_a, col_c, rb) * (0.82 + 0.3 * vnoise(uv * 13.0));
		col = mix(col_b * 0.8, sc, e);
		h = e * (0.75 + 0.25 * vnoise(uv * 9.0 + rb * 10.0));
	} else if (pattern == 12) {
		float fib = fbm(vec2(uv.x * 9.0, uv.y * 0.8) + off);
		col = mix(col_b, col_a, fib);
		h = fib;
	} else if (pattern == 13) {
		float link = fract(uv.y / 0.16);
		float ridge = smoothstep(0.1, 0.2, link) * smoothstep(0.9, 0.8, link);
		col = mix(col_a, col_b, (1.0 - ridge) * 0.4) * (0.85 + 0.25 * vnoise(uv * 20.0));
		h = ridge;
	} else if (pattern == 15) {
		vec2 q = uv / 0.45;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x) * smoothstep(0.0, 0.04, f.y) * smoothstep(1.0, 0.96, f.y);
		float rb = h12(cell + off);
		vec3 tc = mix(col_a, col_c, step(0.5, mod(cell.x + cell.y, 2.0)) * 0.6) * (0.85 + 0.25 * rb);
		float dirt = fbm(uv * 0.8 + off);
		tc = mix(tc, col_b, smoothstep(0.45, 0.75, dirt) * 0.6);
		col = mix(col_b * 0.7, tc, e);
		h = e * 0.8 + vnoise(uv * 40.0) * 0.05;
		r = mix(0.95, rough - dirt * 0.2, e);
	} else if (pattern == 16) {
		vec2 q = uv / 1.05;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		vec2 c2 = f - 0.5;
		float bulge = clamp(1.0 - dot(c2, c2) * 2.2, 0.0, 1.0);
		float seam = 1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		vec2 wq = fract(uv / 0.075);
		float wire = 1.0 - smoothstep(0.0, 0.12, min(min(wq.x, 1.0 - wq.x), min(wq.y, 1.0 - wq.y)));
		float stain = fbm(uv * 1.3 + off);
		vec3 fab = mix(col_a, col_b, smoothstep(0.35, 0.8, stain) * 0.8) * (0.85 + 0.25 * h12(cell + off));
		col = mix(fab, col_c, max(wire * 0.55, seam * 0.8));
		h = bulge * 0.8 - wire * 0.1 - seam * 0.5;
		m = mix(0.0, 0.6, wire * 0.6);
	} else if (pattern == 14) {
		col = col_a * (0.95 + 0.08 * vnoise(uv * 30.0));
		h = 0.5;
	} else {
		col = col_a * (0.92 + 0.12 * vnoise(uv * 5.0 + off));
		h = 0.5 + vnoise(uv * 20.0) * 0.1;
	}
	col *= tint.rgb;
	if (use_vcolor) { col *= COLOR.rgb; }
	// grime and dust toward the ground
	float low = 1.0 - smoothstep(0.0, 0.9, wpos.y);
	float gn = vnoise(uv * 2.0 + off);
	col = mix(col, col * 0.62 + vec3(0.05, 0.04, 0.02), low * grime * (0.6 + 0.4 * gn));
	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = m;
	SPECULAR = 0.4;
	// bump mapping from the pattern height (surface gradient)
	if (bump > 0.0) {
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhx = dFdx(h);
		float dhy = dFdy(h);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * bump * 0.02);
	}
}
"""


const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 tint : source_color = vec4(0.2, 0.32, 0.14, 1.0);
uniform float wind = 1.0;
uniform bool use_vcolor = false;

varying vec3 lpos;
varying float shade;

float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lump = n3(wp * 1.3) * 0.55 + n3(wp * 3.1) * 0.25;
	VERTEX += NORMAL * (lump - 0.4) * 0.5;
	float t = TIME * 1.3 + wp.x * 0.11 + wp.z * 0.07;
	float sway = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.3) * wind * 0.06 * clamp(VERTEX.y + 1.0, 0.0, 2.0);
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	lpos = wp;
	shade = clamp(NORMAL.y * 0.35 + 0.65, 0.0, 1.0);
}

void fragment() {
	// ragged, leafy edges: holes open up where the surface turns away from
	// the eye (and from the sun, so the shadows are dappled too)
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float holes = n3(lpos * 6.0 + 11.0) * 0.6 + n3(lpos * 15.0) * 0.4;
	if (rim > 0.12 && holes < (rim - 0.12) * 1.25) {
		discard;
	}
	float leaves = n3(lpos * 9.0);
	float gaps = n3(lpos * 4.2 + 7.0);
	vec3 c = (use_vcolor ? COLOR.rgb : tint.rgb) * (0.7 + 0.5 * leaves);
	c = mix(c, c * vec3(1.15, 1.1, 0.7), smoothstep(0.55, 0.8, gaps) * 0.5);
	ALBEDO = c * (0.55 + 0.45 * shade);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35, 0.42, 0.18);
	AO = 0.55 + 0.45 * shade;
	AO_LIGHT_AFFECT = 0.6;
	float bh = leaves * 0.6 + gaps * 0.4;
	vec3 dpdx = dFdx(VERTEX); vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(bh); float dhy = dFdy(bh);
	vec3 r1 = cross(dpdy, NORMAL); vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.06);
}
"""


const NETTING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform vec4 tint : source_color = vec4(0.3, 0.34, 0.2, 1.0);
varying vec3 wp;
float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	vec2 u = UV * 2.0 - 1.0;
	VERTEX.y -= (1.0 - u.x * u.x) * (1.0 - u.y * u.y) * 0.45;
	VERTEX.y += sin(VERTEX.x * 0.9 + TIME * 0.7) * 0.03;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz;
	float n = vn(p * 1.9) * 0.55 + vn(p * 5.3) * 0.45;
	float g = vn(p * 13.0);
	vec2 u = UV * 2.0 - 1.0;
	float edge = max(abs(u.x), abs(u.y));
	if (n + g * 0.3 < 0.47 + smoothstep(0.8, 1.0, edge) * 0.3) { discard; }
	vec3 c = tint.rgb * (0.65 + 0.55 * g);
	c = mix(c, c * vec3(1.25, 1.05, 0.7), step(0.62, vn(p * 3.1 + 9.0)) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.5;
}
"""
