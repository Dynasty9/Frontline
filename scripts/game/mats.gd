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
const NATURAL_ROCK := 17
const ASPHALT := 18
const PAVEMENT := 19
const TURF := 20
const WEATHERED_PHOTO := 21
const ROAD_PAINT := 22
const PHOTO_MEAN := preload("res://assets/town/material_means.tres")

# One world-space surface keeps junction overlays continuous with street ribbons.
const ASPHALT_SHADER := """
uniform sampler2D street_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
mat3 ground_surface_basis(vec3 position) {
	vec3 up = cross(dFdx(position), dFdy(position));
	up = length(up) > 0.00000001 ? normalize(up) : vec3(0.0, 1.0, 0.0);
	if (up.y < 0.0) { up = -up; }
	vec3 across = normalize(vec3(1.0, 0.0, 0.0) - up * up.x);
	return mat3(across, -normalize(cross(across, up)), up);
}

// Thin lines where value noise crosses its middle: a meandering network like
// the cracks road crews fill with tar. Each is about 4 cm wide; with distance a
// line covers less of a pixel, so it fades out rather than crawl.
float street_crack_line(sampler2D noise, vec2 p) {
	float n = texture(noise, p * 0.028 + 0.37).r + (texture(noise, p * 0.11 + 0.71).r - 0.5) * 0.22 - 0.5;
	float w = max(fwidth(n), 0.00001);
	float half_width = 0.006;
	return (1.0 - smoothstep(half_width - w, half_width + w, abs(n))) * clamp(half_width * 2.0 / w, 0.0, 1.0);
}

// Where rain stands on a street: the dips in its surface, the same for the
// road ribbons and the paving laid over them (junctions, markings), so a
// puddle runs on across both.
float street_puddle(sampler2D noise, vec2 p) {
	return texture(noise, p * 0.012 + 0.5).r * 0.8 + (texture(noise, p * 0.05 + 0.2).r - 0.5) * 0.3;
}

// tar: how much of this point is tar (sealed cracks, the seams round patches),
// which is darker and smoother than the worn aggregate round it.
vec3 street_surface(sampler2D tex, sampler2D noise, vec2 p, out float tar) {
	vec3 aggregate = texture(street_detail, p / 2.2).rgb;
	if (OUTPUT_IS_SRGB) {
		aggregate = mix(aggregate / 12.92, pow((aggregate + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), aggregate));
	}
	float gray = dot(aggregate, vec3(0.2126, 0.7152, 0.0722));
	aggregate = mix(aggregate, vec3(gray), 0.9);
	// The aerial scan supplies cracks and weathering; fine aggregate stays at its surveyed scale.
	vec3 wear = texture(tex, p / 30.0).rgb;
	if (OUTPUT_IS_SRGB) {
		wear = mix(wear / 12.92, pow((wear + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), wear));
	}
	vec3 base = aggregate * mix(1.0, clamp(dot(wear, vec3(0.2126, 0.7152, 0.0722)) / 0.126, 0.5, 1.4), 0.35);
	float weather = texture(noise, p * 0.006 + 0.17).r;
	// Spills and soot soak in as soft, uneven stains, not round blots.
	float stains = smoothstep(0.58, 0.80, texture(noise, p * 0.035 + 0.63).r * 0.7 + texture(noise, p * 0.16 + 0.29).r * 0.3);
	base *= 0.80 + weather * 0.45;
	// Saw-cut repairs: rectangles of newer, darker binder, a few years apart
	// in age, each edged with a ribbon of sealant where it meets the old road.
	vec2 cell = floor(p / vec2(13.0, 9.0));
	vec2 f = fract(p / vec2(13.0, 9.0));
	vec2 variation = vec2(fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453), fract(sin(dot(cell, vec2(39.346,11.135))) * 23421.631));
	float chosen = step(0.62, texture(noise, cell * 0.17).r);
	vec2 center = vec2(0.3) + variation * 0.4;
	vec2 half_size = vec2(0.05, 0.07) + variation.yx * vec2(0.12, 0.14);
	vec2 off_center = abs(f - center) / half_size;
	float shape = max(off_center.x, off_center.y);
	float edge_px = max(fwidth(shape), 0.0001);
	float repair = chosen * (1.0 - smoothstep(1.0 - edge_px, 1.0 + edge_px, shape));
	// the sealant ribbon, about 6 cm, wider than a pixel or not drawn at all
	float seam_w = 0.06 / (min(half_size.x * 13.0, half_size.y * 9.0));
	float seam = chosen * (1.0 - smoothstep(seam_w * 0.5, seam_w * 0.5 + edge_px, abs(shape - 1.0))) * clamp(seam_w / edge_px, 0.0, 1.0);
	float age = fract(variation.x * 7.31);
	vec3 patched = aggregate * mix(0.74, 0.96, age) * (0.9 + 0.2 * weather);
	base = mix(base, patched, repair);
	float cracks = street_crack_line(noise, p) * smoothstep(0.52, 0.68, texture(noise, p * 0.012 + 0.83).r) * (1.0 - repair);
	tar = max(seam, cracks);
	base = mix(base, aggregate * 0.34, tar * 0.85);
	base *= 1.0 - stains * 0.16;
	// Compatibility reads sRGB samples; blend in linear light, then return its expected output.
	if (OUTPUT_IS_SRGB) {
		base = mix(base * 12.92, 1.055 * pow(max(base, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), base));
	}
	return base;
}
"""

# The rain as it falls on things, shared by the ground, the roads and every
# surface here (after Lagarde, "Water drop 2a/2b: dynamic rain and its effects",
# 2012-13): rings running out where drops land in standing water, crowns of
# spray where they strike what stands in the rain, and water running down walls
# and hulls in rivulets. Each is drawn from cells laid out in the world, one
# drop to a cell each period at a spot of its own, kept clear of the cell's
# edges, so a pixel only ever looks at its own cell. Everything fades out as it
# shrinks under a pixel: from the command camera's height none of it is fine
# enough to draw, and a pattern finer than its pixels would crawl and shimmer.
const RAIN_DROPS := """
global uniform vec4 rain_fx;  // x rings, y crowns, z rivulets and the denser rain (Effects High), w the rain's clock (s); Atmosphere._rain_fx_tick
float rain_hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }

// One layer of rings: the water's slope (dh/dx, dh/dz) at p, in metres. A drop
// lands in each 55 cm cell every period (most of them: some miss), and its ring
// runs out at a capillary wave's pace, a packet of crests 6 cm apart, dying
// away as it spreads: 10 to 21 cm and as strong as the drop was big.
vec2 rain_ring_layer(vec2 p, float t, float salt) {
	vec2 q = p / 0.55;
	vec2 cell = floor(q);
	float phase = rain_hash(cell + salt);
	float cycle = floor(t + phase);
	float age = t + phase - cycle;
	vec2 at = vec2(rain_hash(cell + cycle * 0.37 + salt), rain_hash(cell.yx + cycle * 0.61 + 7.7));
	vec2 d = (q - cell - 0.33 - 0.34 * at) * 0.55;
	float r = length(d);
	float big = mix(0.6, 1.25, rain_hash(cell.yx * 1.3 + cycle * 0.83 + salt));
	float x = r - age * 0.17 * big;
	float fade = pow(1.0 - age, 1.5) * big * step(0.3, rain_hash(cell * 1.7 + cycle + salt));
	float env = exp(-x * x * 494.0) * fade;  // (a Gaussian packet 4.5 cm wide)
	float slope = 0.0045 * env * (104.7 * cos(104.7 * x) - 988.0 * x * sin(104.7 * x));
	return d / max(r, 0.0001) * slope;
}

// The rings at p on standing water (`amount` 0..1: how much of it), faded as
// they shrink under the pixel (`footprint`, the metres it spans).
vec2 rain_rings(vec2 p, float footprint, float amount) {
	float keep = amount * rain_fx.x * (1.0 - smoothstep(0.012, 0.03, footprint));
	if (keep <= 0.0) { return vec2(0.0); }
	float t = rain_fx.w * 1.35;
	// further layers are turned against the first, so no grid lines up
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 s = rain_ring_layer(p, t, 0.0);
	s += rain_ring_layer(turn * p + 0.29, t * 1.13 + 0.5, 11.0) * turn;
	if (rain_fx.z > 0.0) {
		s += rain_ring_layer(turn * turn * p + 0.71, t * 0.91 + 0.25, 23.0) * turn * turn * rain_fx.z;
	}
	return s * keep;
}

// How much of the rings' roughening stands in for the rings themselves, where
// they're too fine to draw (0..1).
float rain_far(float footprint) { return rain_fx.x * smoothstep(0.012, 0.03, footprint); }

// Drops striking an upturned face at p: a crown of spray bursting out to two
// or three centimetres and gone in a few hundredths of a second (0..1). Below
// a pixel a crown is spread over the pixel and dimmed to match, then fades out
// altogether.
float rain_crowns(vec2 p, float footprint, float amount) {
	float keep = amount * rain_fx.y * (1.0 - smoothstep(0.025, 0.05, footprint));
	if (keep <= 0.0) { return 0.0; }
	float t = rain_fx.w * 2.0;
	vec2 q = p / 0.14;
	vec2 cell = floor(q);
	float phase = rain_hash(cell);
	float cycle = floor(t + phase);
	float age = (t + phase - cycle) / 0.15;
	float live = step(mix(0.6, 0.45, rain_fx.z), rain_hash(cell * 1.3 + cycle * 2.9)) * step(age, 1.0);
	vec2 at = vec2(rain_hash(cell + cycle * 0.37), rain_hash(cell.yx + cycle * 0.61 + 7.7));
	float r = length((q - cell - 0.25 - 0.5 * at) * 0.14);
	float size = mix(0.008, 0.03, sqrt(age)) * mix(0.7, 1.2, rain_hash(cell.yx + cycle));
	float spread = max(size, footprint * 0.7);
	// (the spray thins from the middle out as the crown opens)
	float crown = (1.0 - smoothstep(spread * 0.5, spread, r)) * mix(1.0, smoothstep(spread * 0.2, spread * 0.75, r), age);
	return crown * live * (1.0 - age * 0.5) * keep * size * size / (spread * spread);
}

// Water running down a wall or a hull's side (u across it, y up it, metres):
// rivulets 2 to 5 cm wide, about half the lanes running, each carrying beads
// of water down at its own pace. Returns how much water runs here (x) and how
// much of it is a bead's swollen head (y: its top bulges out to the sky).
vec2 rain_rivulets(float u, float y, float footprint) {
	float keep = rain_fx.z * (1.0 - smoothstep(0.02, 0.05, footprint));
	if (keep <= 0.0) { return vec2(0.0); }
	float lane = u * 9.0;
	float id = floor(lane);
	float across = abs(fract(lane) - 0.5) * 2.0;
	float width = mix(0.18, 0.42, rain_hash(vec2(id, 3.1)));
	float channel = 1.0 - smoothstep(width * 0.5, width, across);
	float bead = fract(y * 1.4 + rain_fx.w * mix(0.5, 1.2, rain_hash(vec2(id, 9.7))) + rain_hash(vec2(id, 1.3)) * 9.0);
	float flow = smoothstep(0.0, 0.05, bead) * (1.0 - smoothstep(0.05, 0.4, bead));
	float head = smoothstep(0.0, 0.04, bead) * (1.0 - smoothstep(0.06, 0.16, bead));
	float run = channel * step(0.4, rain_hash(vec2(id, 5.5))) * keep;
	return vec2(run * mix(0.35, 1.0, flow), run * head);
}
"""

static var _shader: Shader
static var _cache := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = CloudShadow.make(code(TerrainTexture.shader(SURFACE_SHADER.replace("// STREET_SURFACE", ASPHALT_SHADER).replace("// RAIN_DROPS", RAIN_DROPS))), CloudShadow.CLEARCOAT)
	return _shader


# --- per-object values ------------------------------------------------------------------

## The browser build draws with the Compatibility renderer (WebGL 2), where
## every object's own shader values ("instance uniform": a part's tint, a
## vehicle's camouflage offset, a smoke column's density) share one uniform
## buffer with room for 4096 of them. A town, its trees and two armies need
## far more, and past the limit objects draw with garbage. So there an
## instance uniform becomes a plain material uniform, and an object given its
## own values gets a copy of its material carrying them, shared by every
## object given the same values (they're rounded so near-identical tints share).
static var per_material := RenderingServer.get_current_rendering_method() == "gl_compatibility"
static var _derived := {}  # "base id|values" -> WeakRef to the copy of the base material carrying them
static var _prune_at := 1024


## Shader source for this renderer: what every shader with instance uniforms
## is compiled from (see per_material).
static func code(src: String) -> String:
	return src.replace("instance uniform ", "uniform ") if per_material else src


## Sets an object's own value of a shader parameter (an instance uniform).
## Give the object its material first: here the value may go into a copy of it.
static func set_inst(gi: GeometryInstance3D, param: StringName, value: Variant) -> void:
	if not per_material:
		gi.set_instance_shader_parameter(param, value)
		return
	var vals: Dictionary = gi.get_meta(&"inst_vals", {})
	vals[param] = _round(value)
	gi.set_meta(&"inst_vals", vals)
	_rederive(gi)


## An object's own value of a shader parameter (null if it has none).
static func get_inst(gi: GeometryInstance3D, param: StringName) -> Variant:
	if not per_material:
		return gi.get_instance_shader_parameter(param)
	return (gi.get_meta(&"inst_vals", {}) as Dictionary).get(param)


## Gives an object a new material, keeping its own values.
static func set_material(gi: GeometryInstance3D, m: Material) -> void:
	gi.material_override = m
	if per_material and gi.has_meta(&"inst_vals"):
		_rederive(gi)


## The material a copy carrying per-object values was made from (or `m` itself).
static func base_of(m: Material) -> Material:
	if m == null:
		return null
	return m.get_meta(&"inst_base", m)


static func _rederive(gi: GeometryInstance3D) -> void:
	var vals: Dictionary = gi.get_meta(&"inst_vals", {})
	if gi.material_override != null or not (gi is MeshInstance3D):
		gi.material_override = _carrying(gi.material_override, vals)
		return
	# a merged mesh: a material per surface
	var mi := gi as MeshInstance3D
	for si in mi.get_surface_override_material_count():
		var m := mi.get_active_material(si)
		if m:
			mi.set_surface_override_material(si, _carrying(m, vals))


static func _carrying(m: Material, vals: Dictionary) -> Material:
	var base := base_of(m)
	if not (base is ShaderMaterial):
		return m
	var keys := vals.keys()
	keys.sort()
	var key := str(base.get_instance_id())
	for k in keys:
		key += "|%s=%s" % [k, vals[k]]
	var w: WeakRef = _derived.get(key)
	var d: ShaderMaterial = w.get_ref() if w else null
	if d == null:
		d = base.duplicate() as ShaderMaterial
		for k in keys:
			d.set_shader_parameter(k, vals[k])
		d.set_meta(&"inst_base", base)
		_derived[key] = weakref(d)
		# a copy lives as long as something draws with it (smoke seeds and
		# splash times are new every time): forget the ones nothing uses
		if _derived.size() > _prune_at:
			for k2 in _derived.keys():
				if (_derived[k2] as WeakRef).get_ref() == null:
					_derived.erase(k2)
			_prune_at = maxi(1024, _derived.size() * 2)
	return d


## Sets a parameter of a shared material, and of every copy of it carrying
## per-object values.
static func set_shared(m: ShaderMaterial, param: StringName, value: Variant) -> void:
	m.set_shader_parameter(param, value)
	if not per_material:
		return
	for w in _derived.values():
		var d: ShaderMaterial = (w as WeakRef).get_ref()
		if d and d.get_meta(&"inst_base") == m:
			d.set_shader_parameter(param, value)


## Close enough to share a material: a 1/128 step of colour, a centimetre.
static func _round(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return snappedf(v, 0.01)
		TYPE_COLOR:
			var c: Color = v
			return Color(snappedf(c.r, 1.0 / 128.0), snappedf(c.g, 1.0 / 128.0), snappedf(c.b, 1.0 / 128.0), snappedf(c.a, 1.0 / 128.0))
		TYPE_VECTOR3:
			return (v as Vector3).snapped(Vector3.ONE * 0.01)
		TYPE_VECTOR4:
			return (v as Vector4).snapped(Vector4.ONE * 0.01)
	return v


## kind: a preset name (see _preset). Returns a shared material.
static func get_mat(kind: String) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var m := ShaderMaterial.new()
	m.resource_name = kind
	m.shader = shader()
	m.set_shader_parameter("noise_tex", noise_tex())
	var finish := kind.get_file().trim_prefix("cast_")
	if finish in ["camo_tank", "camo_tank_rebel", "abrams_olive", "abrams_sand", "abrams_scorched"]:
		m.set_shader_parameter("worn_armour", true)
		m.set_shader_parameter("wear_tex", load("res://assets/vehicles/steel-wear.jpg"))
	if finish.begins_with("abrams_"):
		m.set_shader_parameter("armour_field", load("res://assets/vehicles/abrams-weathering.png"))
	var p := _preset(kind)
	for k in p:
		m.set_shader_parameter(k, p[k])
	if _crater_tex:
		m.set_shader_parameter("crater_tex", _crater_tex)
		m.set_shader_parameter("crater_half", MapDims.HALF)
		m.set_shader_parameter("terrain_bound", true)
	_cache[kind] = m
	return m


## Paving - sidewalks, kerbs, the square, crossings, car parks: the material
## with holes where the ground under it has been cratered or dug out, so a
## shell hole in the square is a hole (and a man lying in it can be seen).
static var _paving := {}
static var _crater_tex: Texture2DArray = null
static var _trench_tex: Texture2D = null


static func paving(kind: String) -> ShaderMaterial:
	if _paving.has(kind):
		return _paving[kind]
	var m := get_mat(kind).duplicate() as ShaderMaterial
	if kind == "asphalt" or kind == "road_paint":
		# Match the road ribbons' transparent lighting pass at junctions (and
		# where paint has worn through to them); markings draw over both.
		var sh := Shader.new()
		sh.code = m.shader.code.replace("ALBEDO = col;", "ALBEDO = col; ALPHA = 1.0;")
		m.shader = sh
		m.render_priority = -1 if kind == "asphalt" else 0
	m.set_shader_parameter("crater_cut", true)
	m.set_shader_parameter("crater_half", MapDims.HALF)
	if _crater_tex:
		m.set_shader_parameter("crater_tex", _crater_tex)
	if _trench_tex:
		m.set_shader_parameter("trench_tex", _trench_tex)
	_paving[kind] = m
	return m


## Rain on the streets: the paving laid over the road ribbons (junctions,
## markings, car parks) darkens and holds puddles just as the ribbons do.
static func set_street_wet(value: float) -> void:
	for kind in ["asphalt", "road_paint"]:
		var m := paving(kind)
		set_shared(m, &"wet", value)
		set_shared(vc_variant(m), &"wet", value)


## The ground's deformation and trench masks (the atmosphere hands them over
## as they're made and remade); paving cuts holes and wall weathering follows
## the ground, including in merged meshes and Compatibility material copies.
static func set_ground_maps(crater: Texture2DArray, trench: Texture2D) -> void:
	if crater:
		_crater_tex = crater
	if trench:
		_trench_tex = trench
	var mats: Array = _cache.values() + _paving.values()
	for v in _vc_cache.values():
		if v.shader == shader() or v.get_shader_parameter("crater_cut") == true:
			mats.append(v)
	for m in mats:
		set_shared(m, &"crater_half", MapDims.HALF)
		if crater:
			set_shared(m, &"crater_tex", crater)
			set_shared(m, &"terrain_bound", true)
		if trench:
			set_shared(m, &"trench_tex", trench)


## Applies a material to a mesh instance with an optional per-instance tint.
static func apply(mi: GeometryInstance3D, kind: String, tint := Color(1, 1, 1)) -> GeometryInstance3D:
	set_material(mi, get_mat(kind))
	if tint != Color(1, 1, 1):
		set_inst(mi, &"tint", tint)
	return mi


## Tint that turns the preset's base colour into `c` (keeps per-part colours).
static func tint_for(kind: String, c: Color) -> Color:
	var b: Color = _preset(kind).get("col_a", Color(0.6, 0.6, 0.6))
	return Color(clampf(c.r / maxf(b.r, 0.02), 0.25, 2.5), clampf(c.g / maxf(b.g, 0.02), 0.25, 2.5), clampf(c.b / maxf(b.b, 0.02), 0.25, 2.5))


static var _foliage: ShaderMaterial
static var _noise: ImageTexture


## A tileable value-noise texture with mipmaps (16 features across): the
## procedural surfaces read their fine noise from it, so the GPU filters it.
static func noise_tex() -> ImageTexture:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.frequency = 1.0 / 16.0
		n.seed = 1234
		var img := n.get_seamless_image(256, 256, false, false, 0.1, true)
		img.convert(Image.FORMAT_L8)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


## Lumpy, wind-swayed leaf clusters with translucency (instance uniform tint).
static func foliage() -> ShaderMaterial:
	if _foliage == null:
		_foliage = ShaderMaterial.new()
		_foliage.shader = CloudShadow.make(code(FOLIAGE_SHADER), CloudShadow.BACKLIGHT)
		_foliage.set_shader_parameter("vertex_lit", ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"))
	return _foliage


static var _leaf_cards := {}

static func leaf_cards(conifer: bool) -> ShaderMaterial:
	if not _leaf_cards.has(conifer):
		var material := foliage().duplicate() as ShaderMaterial
		material.set_shader_parameter("leaf_cards", true)
		material.set_shader_parameter("leaf_tone", 0.65 if conifer else 0.85)
		material.set_shader_parameter("leaf_texture", preload("res://assets/foliage/fir.png") if conifer else preload("res://assets/foliage/broadleaf.png"))
		_leaf_cards[conifer] = material
	return _leaf_cards[conifer]


static var _vc_cache := {}
## Merged parts carry their tint as vertex colour, which is stored 8 bits per
## channel and clamps at 1: a tint brighter than the material's base (a sand
## paint over an olive preset) would be lost. A 2.5 sRGB tint reaches 8.35 in
## linear light, so the packed range must cover that before the shader restores it.
const VC_K := 9.0


## Same material, but reading the part colour from vertex colours (for merged meshes).
static func vc_variant(m: ShaderMaterial) -> ShaderMaterial:
	var id := m.get_instance_id()
	if _vc_cache.has(id):
		return _vc_cache[id]
	var v := m.duplicate() as ShaderMaterial
	v.set_shader_parameter("use_vcolor", true)
	if v.shader == shader():
		v.set_shader_parameter("vcolor_k", VC_K)
	_vc_cache[id] = v
	return v


## Bakes every static part under `root` that uses one of our shaders into a single
## mesh per material, carrying each part's tint as vertex colour. A ruined house
## or a tree goes from a dozen render objects to one or two.
static func merge_static(root: Node3D, keep: Array = [], deep := true, remerge := false, single := false) -> void:
	var groups := {}
	var victims: Array = []
	_collect(root, Transform3D.IDENTITY, groups, victims, keep, deep, remerge, single)
	_emit(root, groups, single)
	_free_parts(victims)


## The merged meshes, under `root`: one per material (and shadow setting), or
## with `single` one mesh with a surface per material.
static func _emit(root: Node3D, groups: Dictionary, single: bool) -> void:
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
			if not g2.uv.is_empty():
				arrays2[Mesh.ARRAY_TEX_UV] = g2.uv
			am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
			am2.surface_set_material(am2.get_surface_count() - 1, g2.mat if g2.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g2.mat))
			if int(g2.shadow) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mi2 := MeshInstance3D.new()
		mi2.mesh = am2
		mi2.cast_shadow = shadow
		root.add_child(mi2)
		# (a surface that can't go into the shadow proxy needs the whole mesh
		# casting, so then it all does, as before)
		var casters := _shadow_casters(groups)
		if casters.size() >= 2 and casters.size() == _casting(groups):
			_shadow_proxy(root, groups, casters)
			_cast_through_proxy(mi2, shadow)
		return
	var casters := _shadow_casters(groups)
	var proxied := casters.size() >= 2
	for key in groups:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_COLOR] = g.c
		if not g.uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = g.uv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat if g.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g.mat)
		mi.cast_shadow = g.shadow
		if proxied and key in casters:
			_cast_through_proxy(mi, g.shadow)
		root.add_child(mi)
	if proxied:
		_shadow_proxy(root, groups, casters)


# --- shadow proxies ---------------------------------------------------------------------

## The sun draws its shadow maps in four cascades, and every mesh in one is
## drawn again into it: a house merged into a mesh per material (plaster,
## brick, timber, glass, its paint and fittings) was a dozen draws a cascade,
## and a town in view several thousand a frame, more than the scene itself.
## A shadow needs only the shape, not the materials, so a model's opaque
## surfaces cast it together, from one mesh of all their triangles that is
## drawn into the shadow maps only (the meshes the eye sees cast none). Our
## surface shader moves no vertex, and writes depth for every pixel but the
## ground cut away under a crater, so the shape is exactly the one they cast;
## foliage (cut-out leaves, swaying) and anything else casts its own.
static func _proxy_eligible(g: Dictionary) -> bool:
	var m: ShaderMaterial = g.mat
	return int(g.shadow) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and m.shader == shader() and m.get_shader_parameter("crater_cut") != true


## The groups that would cast through a proxy, by key.
static func _shadow_casters(groups: Dictionary) -> Array:
	var out := []
	for key in groups:
		if _proxy_eligible(groups[key]):
			out.append(key)
	return out


## How many groups cast a shadow at all.
static func _casting(groups: Dictionary) -> int:
	var n := 0
	for g: Dictionary in groups.values():
		if int(g.shadow) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			n += 1
	return n


## A merged mesh that now casts its shadow through the proxy beside it. It
## remembers what it cast, so merging it again (a damaged house, a block of
## houses batched) still knows.
static func _cast_through_proxy(mi: MeshInstance3D, shadow: int) -> void:
	mi.set_meta(&"shadow", shadow)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## What a mesh casts, the proxy aside.
static func shadow_of(mi: GeometryInstance3D) -> int:
	return int(mi.get_meta(&"shadow", mi.cast_shadow))


## One shadows-only mesh of the `keys` groups' triangles, under `root`.
static func _shadow_proxy(root: Node3D, groups: Dictionary, keys: Array) -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for key in keys:
		v.append_array(groups[key].v)
		n.append_array(groups[key].n)
	var mi := shadow_proxy_node(v, n)
	root.add_child(mi)
	return mi


## A shadows-only mesh of these triangles (a plain list, with their normals,
## which the shadow's normal bias reads). `dynamic` lets parts be blanked out
## of it later (StructureView's batches).
static func shadow_proxy_node(v: PackedVector3Array, n: PackedVector3Array, dynamic := false) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE if dynamic else 0)
	var mi := MeshInstance3D.new()
	mi.name = &"ShadowProxy"
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.set_meta(&"shadow_proxy", true)
	return mi


## The parts that went into the merged meshes let go of their meshes now, and
## are deleted at the end of the frame. Laying out a battle makes and merges
## tens of thousands of them; holding their meshes, they were all deleted in
## the frame after it, and the first deletion had the renderer bring every one
## of them up to date first (each with a search through every object's shader
## values for a free place): a freeze of ten seconds and more. Deleted at once
## instead, each deletion did that for the parts of the model not merged yet.
## A part without a mesh is nothing for the renderer to bring up to date.
## (Nothing holds on to a part once it's merged: whatever a model goes on to
## use - a flag that changes colour, a door that swings - it keeps out.)
static func _free_parts(victims: Array) -> void:
	for v in victims:
		v.get_parent().remove_child(v)
		(v as MeshInstance3D).mesh = null
		v.queue_free()


static var _flat_cache := {}
static var _distant_material: ShaderMaterial


## Snapshot an articulated model without changing its joints or meshes.
static func bake_mesh(root: Node3D) -> ArrayMesh:
	var groups := {}
	var unused := []
	_collect(root, Transform3D.IDENTITY, groups, unused, [], true, true, true)
	return _bake_groups(groups)


## How far a detailed model and its distant stand-in cross-fade, dithered,
## instead of one popping into the other (Godot's visibility range fade; the
## dissolve LOD transition games use to hide the switch).
const LOD_FADE := 8.0


## Moving vehicle parts keep their pivots, but distant paint needs one surface.
static func add_distance_lod(root: Node3D, distance: float, keep: Array = []) -> void:
	var groups := {}
	var originals := []
	_collect(root, Transform3D.IDENTITY, groups, originals, keep, false, true, true)
	if groups.is_empty():
		return
	var coarse := MeshInstance3D.new()
	coarse.mesh = _bake_groups(groups)
	coarse.visibility_range_begin = distance
	coarse.visibility_range_begin_margin = LOD_FADE
	coarse.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	coarse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for original: MeshInstance3D in originals:
		original.visibility_range_end = distance
		original.visibility_range_end_margin = LOD_FADE
		original.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if shadow_of(original) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			coarse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(coarse)


## Distant meshes already made, by what went into them (see _bake_groups).
static var _baked := {}
const BAKED_KEEP := 1024


## One coarse mesh of the groups (a vehicle part, a soldier's pose, seen from
## far off), with its own levels of detail. Working those out (welding the
## vertices, simplifying them three times over) took most of the time a
## vehicle's model took to build, 150 ms for a car and more than half a second
## for a tank, and every tank of a kind is built of the same parts: so each
## mesh is made once, and a part with the same triangles, colours and paint
## shares it.
static func _bake_groups(groups: Dictionary) -> ArrayMesh:
	var key := PackedInt64Array()
	for group: Dictionary in groups.values():
		key.append((group.mat as ShaderMaterial).get_instance_id())
		key.append(hash((group.v as PackedVector3Array).to_byte_array()))
		key.append(hash((group.n as PackedVector3Array).to_byte_array()))
		key.append(hash((group.c as PackedColorArray).to_byte_array()))
		key.append((group.v as PackedVector3Array).size())
	var known: ArrayMesh = _baked.get(key)
	if known != null:
		return known
	var made := _bake_groups_now(groups)
	if _baked.size() >= BAKED_KEEP:
		_baked.clear()  # (a long battle's worth of kinds and paints: start again)
	_baked[key] = made
	return made


static func _bake_groups_now(groups: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for group: Dictionary in groups.values():
		vertices.append_array(group.v)
		normals.append_array(group.n)
		var material: ShaderMaterial = group.mat
		var base: Color = material.get_shader_parameter("col_a")
		if int(material.get_shader_parameter("pattern")) == CAMO:
			base = base.lerp(material.get_shader_parameter("col_b"), 0.35)
		if not per_material:
			base = base.srgb_to_linear()
		var scale := VC_K
		if material.get_shader_parameter("use_vcolor") == true:
			scale = float(material.get_shader_parameter("vcolor_k"))
		for tint: Color in group.c:
			colors.append(Color(base.r * tint.r * scale, base.g * tint.g * scale, base.b * tint.b * scale, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	# At this distance cloth weave and metal wear are subpixel. Keep the
	# uniform, skin, equipment and vehicle paint colours in one surface.
	if _distant_material == null:
		_distant_material = ShaderMaterial.new()
		_distant_material.shader = CloudShadow.make(DISTANT_SHADER)
	# Hundreds of instances share this mesh. Weld identical vertex attributes
	# once so the GPU can reuse transformed vertices without changing the pose.
	# (Welded from the arrays themselves: a mesh read back from the graphics
	# card waits on it.)
	var tool := SurfaceTool.new()
	tool.create_from_arrays(arrays)
	tool.index()
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, tool.commit_to_arrays(), [], {}, _distant_material)
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## A surface as an unindexed triangle list [verts, normals, colours or null].
## The shared primitives (boxes, cylinders, spheres) are flattened once and
## kept, so building a soldier or a house only appends arrays. Any other mesh
## keeps its own flattened copy for as long as it lives (every tank of a kind
## shares its hull, every sandbag one bag).
static func _flat(mesh: Mesh, si: int) -> Array:
	var cacheable := mesh is PrimitiveMesh or mesh is BevelMesh or mesh is BodyMesh
	var key := mesh.get_instance_id() * 8 + si
	if cacheable and _flat_cache.has(key):
		return _flat_cache[key]
	var own: Dictionary = {} if cacheable else mesh.get_meta(&"flat", {})
	if own.has(si):
		return own[si]
	var arr := _arrays(mesh, si)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c = arr[Mesh.ARRAY_COLOR]
	var uv = arr[Mesh.ARRAY_TEX_UV]
	var hasuv: bool = uv != null and (uv as PackedVector2Array).size() == v.size()
	var hasc: bool = c != null and (c as PackedColorArray).size() == v.size()
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx != null and not (idx as PackedInt32Array).is_empty():
		var ii: PackedInt32Array = idx
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var c2 := PackedColorArray()
		var uv2 := PackedVector2Array()
		if hasuv:
			uv2.resize(ii.size())
		v2.resize(ii.size())
		n2.resize(ii.size())
		if hasc:
			c2.resize(ii.size())
		for k in ii.size():
			var j := ii[k]
			v2[k] = v[j]
			n2[k] = n[j]
			if hasuv:
				uv2[k] = (uv as PackedVector2Array)[j]
			if hasc:
				c2[k] = (c as PackedColorArray)[j]
		v = v2
		n = n2
		c = c2
		uv = uv2
	var out := [v, n, c if hasc else null, uv if hasuv else null]
	if cacheable:
		_flat_cache[key] = out
	else:
		own[si] = out
		mesh.set_meta(&"flat", own)
	return out


## Has `mesh` (made in script from `arrays`, its one surface) remember them,
## so merging it never has to read it back from the renderer (see _arrays).
static func keep_arrays(mesh: ArrayMesh, arrays: Array) -> void:
	mesh.set_meta(&"src", arrays)


## A surface's arrays as the renderer gives them back. Reading a mesh back
## from the graphics card waits on it, a millisecond or two each time, and a
## battlefield's models merged thousands (every box of a new size, every
## vehicle hull): with a window that was most of what building them cost. A
## mesh made in script keeps the arrays it was made from (keep_arrays); the
## renderer holds normals and colours packed (normals as two 16-bit octahedral
## coordinates, colours a byte a channel), so they're packed and unpacked here
## the way it does it, to come out exactly as it would give them back.
static func _arrays(mesh: Mesh, si: int) -> Array:
	if si != 0 or not mesh.has_meta(&"src"):
		return mesh.surface_get_arrays(si)
	var src: Array = mesh.get_meta(&"src")
	mesh.remove_meta(&"src")  # (flattened once, and kept: see _flat)
	var out := src.duplicate()
	if src[Mesh.ARRAY_NORMAL] != null:
		var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var pn := PackedVector3Array()
		pn.resize(sn.size())
		for i in sn.size():
			# (scaled in single precision, as the renderer does; truncated to 16
			# bits, which makes nothing of the not-a-number a zero normal gives)
			var e := sn[i].octahedron_encode() * 65535.0
			var ex := 0 if is_nan(e.x) else int(clampf(e.x, 0.0, 65535.0))
			var ey := 0 if is_nan(e.y) else int(clampf(e.y, 0.0, 65535.0))
			pn[i] = Vector3.octahedron_decode(Vector2(ex / 65535.0, ey / 65535.0))
		out[Mesh.ARRAY_NORMAL] = pn
	if src[Mesh.ARRAY_COLOR] != null:
		var sc: PackedColorArray = src[Mesh.ARRAY_COLOR]
		var pc := PackedColorArray()
		pc.resize(sc.size())
		for i in sc.size():
			var c := sc[i]
			pc[i] = Color(_byte(c.r) / 255.0, _byte(c.g) / 255.0, _byte(c.b) / 255.0, _byte(c.a) / 255.0)
		out[Mesh.ARRAY_COLOR] = pc
	return out


## A colour channel as the renderer stores it: a byte, truncated.
static func _byte(v: float) -> int:
	return 0 if is_nan(v) else int(clampf(v * 255.0, 0.0, 255.0))


static func _collect(node: Node, xf: Transform3D, groups: Dictionary, victims: Array, keep: Array, deep := true, remerge := false, single := false) -> void:
	for c in node.get_children():
		if c in keep or not (c is Node3D):
			continue
		if not (c is MeshInstance3D) and not (c as Node3D).visible:
			continue  # a hidden attachment (the slung rifle on a corpse) stays out of the bake
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			if mi.has_meta(&"shadow_proxy"):
				# merged again, its meshes cast through the new merge's proxy
				if remerge:
					victims.append(mi)
				continue
			if mi.mesh == null or not mi.visible:
				continue
			# every surface must be one of ours (the override, or each surface's own material)
			var mats := []
			var ok := true
			for si0 in mi.mesh.get_surface_count():
				var m0 = mi.material_override if mi.material_override else mi.get_active_material(si0)
				var sm0 := base_of(m0) as ShaderMaterial
				var vc0: bool = sm0 != null and sm0.get_shader_parameter("use_vcolor") == true
				if sm0 == null or not (sm0.shader == shader() or sm0 == _foliage or (vc0 and (sm0.shader == shader() or sm0.shader == foliage().shader))) or (vc0 and not remerge):
					ok = false
					break
				mats.append(sm0)
			if ok and not mats.is_empty():
				_append(groups, mi.mesh, mats, shadow_of(mi), get_inst(mi, &"tint"), cx, single)
				victims.append(mi)
				continue
		if deep:
			_collect(c, cx, groups, victims, keep, deep, remerge, single)


## One part onto the merged meshes: each surface of `mesh` (under its material
## in `mats`) placed by `cx` in the root's space, its tint (an sRGB colour, or
## null for none) as vertex colour.
static func _append(groups: Dictionary, mesh: Mesh, mats: Array, shadow: int, tint: Variant, cx: Transform3D, single: bool) -> void:
	# Match source_color uniforms: Compatibility shades in sRGB, Forward+ in linear light.
	var col: Color = tint if tint is Color else Color(1, 1, 1)
	if not per_material:
		col = col.srgb_to_linear()
	var nb := Transform3D(cx.basis.inverse().transposed(), Vector3.ZERO)
	for si in mesh.get_surface_count():
		var sm: ShaderMaterial = mats[si]
		var vc: bool = sm.get_shader_parameter("use_vcolor") == true
		var key := str(sm.get_instance_id()) if single else "%d|%d" % [sm.get_instance_id(), shadow]
		if not groups.has(key):
			groups[key] = {"mat": sm, "shadow": shadow, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array()}
		var g: Dictionary = groups[key]
		if shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.shadow = shadow
		# plain triangle lists, so parts are appended with native array
		# ops (no index offsetting loop in script)
		var fa := _flat(mesh, si)
		var verts: PackedVector3Array = fa[0]
		g.v.append_array(cx * verts)
		g.n.append_array(nb * (fa[1] as PackedVector3Array))
		if sm.get_shader_parameter("vehicle_surface") == true:
			if fa[3] != null:
				g.uv.append_array(fa[3])
			else:
				var blank := PackedVector2Array()
				blank.resize(verts.size())
				blank.fill(Vector2(0.5, 0.5))
				g.uv.append_array(blank)
		elif sm.get_shader_parameter("leaf_cards") == true:
			assert(fa[3] != null, "Photographed foliage keeps its card coordinates through batching")
			g.uv.append_array(fa[3])
		if vc and fa[2] != null and (fa[2] as PackedColorArray).size() == verts.size():
			g.c.append_array(fa[2])
		else:
			# in the scale the merged material reads it back at (see VC_K)
			var fk := 1.0
			if vc:
				var kp = sm.get_shader_parameter("vcolor_k")
				fk = 1.0 / float(kp) if kp != null else 1.0
			elif sm.shader == shader():
				fk = 1.0 / VC_K
			var cols := PackedColorArray()
			cols.resize(verts.size())
			cols.fill(Color(col.r * fk, col.g * fk, col.b * fk, col.a))
			g.c.append_array(cols)


## Parts written straight into merged meshes, for a model that knows as it goes
## that a part will be merged (a tree is nothing else): the same meshes
## merge_static makes of the same parts built as nodes and merged, without
## making the nodes. Building a battlefield made and threw away tens of
## thousands of those, and each one had the renderer make (and later drop) an
## object for it. Parts go in the order they're added, as children would.
class Bake:
	var groups := {}
	var single := false

	func _init(one_mesh := false) -> void:
		single = one_mesh

	## A part under one of our materials (a preset from get_mat, the foliage, a
	## paving), placed by `xf` (its node's transform: see Mats.place) in a
	## holder placed by `parent` in the model (the identity for a part of the
	## model itself, else as merge_static adds up the holders' transforms), with
	## a tint (as set_inst would give it) or none, casting a shadow or not.
	func part(mesh: Mesh, mat: ShaderMaterial, xf: Transform3D, tint: Variant = null, shadow := true, parent := Transform3D.IDENTITY) -> void:
		if Mats.per_material and tint is Color:
			tint = Mats._round(tint)  # (what get_inst gives back there)
		var mats := []
		mats.resize(mesh.get_surface_count())
		mats.fill(mat)
		Mats._append(groups, mesh, mats, GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			tint, parent * xf, single)

	## The merged meshes, added under `root` (as merge_static adds them).
	func commit(root: Node3D) -> void:
		Mats._emit(root, groups, single)
		groups = {}


## A node's transform from its position, rotation and scale, worked out as
## Node3D works it out (so a baked part sits exactly where the node would).
static func place(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


static var _netting: ShaderMaterial


## Camouflage netting: ragged holes (discard) so it throws dappled shadows.
static func netting() -> ShaderMaterial:
	if _netting == null:
		_netting = ShaderMaterial.new()
		_netting.shader = CloudShadow.make(code(NETTING_SHADER), CloudShadow.BACKLIGHT)
	return _netting


static var _netting_tent: ShaderMaterial


## The same netting for a net whose mesh is already shaped (pitched over a
## pole, draped to the ground): no sag of its own.
static func netting_tent() -> ShaderMaterial:
	if _netting_tent == null:
		_netting_tent = netting().duplicate() as ShaderMaterial
		_netting_tent.set_shader_parameter("sag", 0.0)
	return _netting_tent


static func _preset(kind: String) -> Dictionary:
	if kind.begins_with("vehicle/"):
		return VehicleMaterials.preset(kind)
	match kind:
		"steel":
			return {"pattern": PAINT, "col_a": Color(0.25, 0.26, 0.27), "col_b": Color(0.4, 0.38, 0.35), "rough": 0.6, "metal": 0.6, "bump": 0.8, "grime": 0.4, "rust": 0.3}
		"floor_tiles":
			return {"pattern": TILES, "col_a": Color(0.45, 0.42, 0.38), "col_b": Color(0.3, 0.28, 0.25), "col_c": Color(0.52, 0.4, 0.32), "rough": 0.7, "bump": 0.8, "grime": 0.0}
		"car_paint":
			return {"pattern": PAINT, "col_a": Color(0.5, 0.5, 0.5), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.38, "metal": 0.3, "bump": 0.4, "grime": 0.9, "rust": 0.45}
		"wood_painted":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.34, 0.22), "col_b": Color(0.22, 0.25, 0.16), "rough": 0.8, "bump": 1.0, "grime": 0.7}
		"gunmetal_w":
			return {"pattern": PAINT, "col_a": Color(0.14, 0.14, 0.135), "col_b": Color(0.34, 0.33, 0.31), "rough": 0.52, "metal": 0.55, "bump": 0.35, "grime": 0.2}
		"plaster":
			return {"photo_color": preload("res://assets/town/plastered_wall_color.jpg"), "photo_surface": preload("res://assets/town/plastered_wall_surface.png"), "pattern": PLASTER, "col_a": Color(0.74, 0.69, 0.6), "col_b": Color(0.6, 0.57, 0.5), "col_c": Color(0.5, 0.33, 0.26), "col_d": Color(0.45, 0.42, 0.37), "rough": 0.92, "bump": 1.2, "grime": 0.7}
		"brick":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("brick_wall_001"), "col_a": Color(0.56, 0.3, 0.21), "col_b": Color(0.62, 0.58, 0.52), "col_c": Color(0.42, 0.24, 0.17), "rough": 0.9, "bump": 0.0, "grime": 0.6, "scale": 1.0, "weathering": 0.5, "photo_color": preload("res://assets/town/brick_wall_001_color.jpg"), "photo_surface": preload("res://assets/town/brick_wall_001_surface.png")}
		"concrete":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("concrete_floor_01"), "col_a": Color(0.52, 0.51, 0.48), "col_b": Color(0.36, 0.35, 0.32), "rough": 0.9, "bump": 0.0, "grime": 0.8, "scale": 0.5, "weathering": 0.5, "photo_color": preload("res://assets/town/concrete_floor_01_color.jpg"), "photo_surface": preload("res://assets/town/concrete_floor_01_surface.png")}
		"asphalt":
			return {"street_detail": preload("res://assets/town/road_damaged_clean_color.jpg"), "pattern": ASPHALT, "col_a": Color(1, 1, 1), "rough": 0.88, "bump": 0.0, "grime": 0.0, "photo_color": preload("res://assets/town/aerial_asphalt_01_color.jpg"), "photo_surface": preload("res://assets/town/road_damaged_clean_surface.png")}
		"turf":
			return {"pattern": TURF, "col_a": Color(1, 1, 1), "rough": 0.98, "bump": 0.0, "grime": 0.0, "scale": 0.5, "photo_color": preload("res://assets/town/leafy_grass_color.jpg"), "photo_surface": preload("res://assets/town/leafy_grass_surface.png")}
		"pavement":
			return {"pattern": PAVEMENT, "col_a": Color(0.52, 0.51, 0.48), "rough": 0.93, "bump": 0.0, "grime": 0.0, "scale": 0.555556, "photo_color": preload("res://assets/town/concrete_pavement_color.jpg"), "photo_surface": preload("res://assets/town/concrete_pavement_surface.png")}
		"square_paving":
			# The square: the same concrete in a larger slab, 0.9 by 0.45 m.
			return {"pattern": PAVEMENT, "col_a": Color(0.52, 0.51, 0.48), "rough": 0.93, "bump": 0.0, "grime": 0.0, "scale": 0.37037, "photo_color": preload("res://assets/town/concrete_pavement_color.jpg"), "photo_surface": preload("res://assets/town/concrete_pavement_surface.png")}
		"road_paint":
			# Markings on the road: a thin film over the asphalt, worn by traffic.
			return {"street_detail": preload("res://assets/town/road_damaged_clean_color.jpg"), "pattern": ROAD_PAINT, "col_a": Color(0.9, 0.9, 0.87), "rough": 0.6, "bump": 0.0, "grime": 0.0, "photo_color": preload("res://assets/town/aerial_asphalt_01_color.jpg"), "photo_surface": preload("res://assets/town/road_damaged_clean_surface.png")}
		"curbstone":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("concrete_floor_01"), "col_a": Color(0.47, 0.465, 0.45), "col_b": Color(0.52, 0.51, 0.48), "rough": 0.94, "bump": 0.0, "grime": 0.0, "pitting": 0.1, "seams": 0.0, "scale": 0.5, "weathering": 0.5, "photo_color": preload("res://assets/town/concrete_floor_01_color.jpg"), "photo_surface": preload("res://assets/town/concrete_floor_01_surface.png")}
		"concrete_floor":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("concrete_floor_01"), "col_a": Color(0.42, 0.41, 0.38), "col_b": Color(0.3, 0.28, 0.25), "rough": 0.9, "bump": 0.0, "grime": 0.0, "scale": 0.5, "weathering": 0.5, "photo_color": preload("res://assets/town/concrete_floor_01_color.jpg"), "photo_surface": preload("res://assets/town/concrete_floor_01_surface.png")}
		"sandbag":
			return {"pattern": SANDBAG, "col_a": Color(0.62, 0.55, 0.39), "col_b": Color(0.45, 0.39, 0.26), "rough": 0.95, "bump": 2.2, "grime": 0.6}
		"wood":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("weathered_planks"), "col_a": Color(0.5, 0.37, 0.23), "col_b": Color(0.34, 0.24, 0.14), "rough": 0.85, "bump": 0.0, "grime": 0.5, "scale": 0.5, "weathering": 0.5, "photo_color": preload("res://assets/town/weathered_planks_color.jpg"), "photo_surface": preload("res://assets/town/weathered_planks_surface.png")}
		"wood_dark":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("weathered_planks"), "col_a": Color(0.33, 0.25, 0.17), "col_b": Color(0.22, 0.16, 0.1), "rough": 0.88, "bump": 0.0, "grime": 0.5, "scale": 0.5, "weathering": 0.5, "photo_color": preload("res://assets/town/weathered_planks_color.jpg"), "photo_surface": preload("res://assets/town/weathered_planks_surface.png")}
		"bank":
			# earth thrown up and left a season: settled smooth, gone over with
			# moss and thin grass (berms, the mound over a dugout)
			return {"pattern": EARTH, "col_a": Color(0.3, 0.28, 0.18), "col_b": Color(0.2, 0.19, 0.12), "rough": 0.97, "bump": 0.45, "grime": 0.0, "scale": 0.6}
		"earth":
			return {"pattern": EARTH, "col_a": Color(0.33, 0.26, 0.17), "col_b": Color(0.22, 0.17, 0.11), "rough": 0.97, "bump": 1.6, "grime": 0.0}
		"alpine_stone":
			# Broken natural stone has grain, without the mortar joints used by masonry.
			return {"pattern": NATURAL_ROCK, "col_a": Color(0.44, 0.43, 0.39), "rough": 0.95, "bump": 2.5, "grime": 0.0, "scale": 0.75, "stone_texture": preload("res://assets/terrain/rock_face_03_color_height.png")}
		"stone":
			return {"pattern": STONE, "col_a": Color(0.58, 0.55, 0.5), "col_b": Color(0.42, 0.4, 0.36), "col_c": Color(0.5, 0.46, 0.4), "rough": 0.9, "bump": 2.0, "grime": 0.7}
		"rubble":
			return {"pattern": STONE, "col_a": Color(0.55, 0.52, 0.47), "col_b": Color(0.36, 0.34, 0.3), "col_c": Color(0.5, 0.33, 0.25), "rough": 0.95, "bump": 2.4, "grime": 0.5, "scale": 2.0}
		"roof_tile":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("roof_tiles"), "col_a": Color(0.5, 0.22, 0.14), "rough": 0.9, "bump": 0.0, "grime": 0.0, "scale": 0.5, "local_space": true, "weathering": 0.7, "photo_color": preload("res://assets/town/roof_tiles_color.jpg"), "photo_surface": preload("res://assets/town/roof_tiles_surface.png")}
		"roof_concrete":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("concrete_floor_01"), "col_a": Color(0.52, 0.5, 0.47), "rough": 0.95, "bump": 0.0, "grime": 0.0, "scale": 0.5, "local_space": true, "weathering": 1.0, "photo_color": preload("res://assets/town/concrete_floor_01_color.jpg"), "photo_surface": preload("res://assets/town/concrete_floor_01_surface.png")}
		"fence_wood", "fence_rail":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("weathered_planks"), "col_a": Color(0.5, 0.43, 0.33), "rough": 0.94, "bump": 0.0, "grime": 0.0, "scale": 0.5, "grain_horizontal": kind == "fence_rail", "weathering": 0.5, "photo_color": preload("res://assets/town/weathered_planks_color.jpg"), "photo_surface": preload("res://assets/town/weathered_planks_surface.png")}
		"fence_metal":
			return {"pattern": PAINT, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.28, 0.25, 0.21), "rough": 0.82, "metal": 0.35, "bump": 0.3, "grime": 0.65, "rust": 0.7, "scale": 1.7}
		"corrugated":
			return {"pattern": CORRUGATED, "col_a": Color(0.5, 0.51, 0.49), "col_b": Color(0.42, 0.24, 0.12), "rough": 0.55, "metal": 0.5, "bump": 1.0, "grime": 0.6}
		"canvas":
			return {"pattern": CANVAS, "col_a": Color(0.36, 0.38, 0.25), "col_b": Color(0.28, 0.3, 0.2), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"canvas_white":
			return {"pattern": CANVAS, "col_a": Color(0.85, 0.84, 0.79), "col_b": Color(0.7, 0.68, 0.62), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"bark":
			return {"pattern": WEATHERED_PHOTO, "photo_mean": PHOTO_MEAN.get_meta("tree_bark_03"), "col_a": Color(0.32, 0.25, 0.18), "col_b": Color(0.18, 0.14, 0.1), "rough": 0.95, "bump": 0.0, "grime": 0.2, "scale": 0.65, "weathering": 0.5, "photo_color": preload("res://assets/town/tree_bark_03_color.jpg"), "photo_surface": preload("res://assets/town/tree_bark_03_surface.png")}
		"paint":
			return {"pattern": PAINT, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.38, 0.37, 0.35), "rough": 0.45, "metal": 0.15, "bump": 0.6, "grime": 0.7}
		"aircraft":
			# clean matte low-visibility grey, the panel lines left to the light
			return {"pattern": PAINT, "col_a": Color(0.5, 0.52, 0.54), "col_b": Color(0.44, 0.46, 0.48), "rough": 0.62, "metal": 0.2, "bump": 0.25, "grime": 0.0, "rust": 0.0}
		"metal_dark":
			return {"pattern": PAINT, "col_a": Color(0.17, 0.17, 0.17), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.5, "metal": 0.6, "bump": 0.5, "grime": 0.3}
		"burnt":
			return {"pattern": PAINT, "col_a": Color(0.085, 0.08, 0.075), "col_b": Color(0.2, 0.17, 0.15), "rough": 0.9, "metal": 0.25, "bump": 1.2, "grime": 0.2, "rust": 0.3, "scale": 1.6}
		"abrams_scorched":
			# Ash catches on the hull plates while the steel fittings and rubber stay dark.
			return {"pattern": CAMO, "col_a": Color("383530"), "col_b": Color("51483f"), "col_c": Color("262628"), "col_d": Color("62594f"), "scale": 0.86, "rough": 0.87, "metal": 0.26, "bump": 0.72, "grime": 0.38, "local_space": true}
		"plain":
			return {"pattern": PLAIN, "col_a": Color(0.55, 0.55, 0.55), "rough": 0.85, "bump": 0.2, "grime": 0.3}
		"plain_dark":
			return {"pattern": PLAIN, "col_a": Color(0.18, 0.18, 0.18), "rough": 0.8, "bump": 0.2, "grime": 0.2}
		"rubber":
			return {"pattern": PLAIN, "col_a": Color(0.07, 0.07, 0.07), "rough": 0.85, "bump": 0.3, "grime": 0.4}
		"glass":
			return {"pattern": PLAIN, "col_a": Color(0.08, 0.1, 0.12), "rough": 0.08, "metal": 0.4, "bump": 0.0, "grime": 0.0}
		"window_lit":
			# the same glass with a lamp on in the room behind it (see `lit`)
			return {"pattern": PLAIN, "col_a": Color(0.08, 0.1, 0.12), "col_c": Color(2.4, 1.55, 0.8), "rough": 0.08, "metal": 0.4, "bump": 0.0, "grime": 0.0, "lit": 1.0}
		"track":
			return {"pattern": TRACK, "col_a": Color(0.13, 0.12, 0.11), "col_b": Color(0.3, 0.27, 0.23), "rough": 0.7, "metal": 0.5, "bump": 2.0, "grime": 0.5, "local_space": true}
		"camo_army":
			return {"pattern": CAMO, "col_a": Color(0.4, 0.4, 0.3), "col_b": Color(0.33, 0.35, 0.25), "col_c": Color(0.43, 0.38, 0.28), "col_d": Color(0.25, 0.24, 0.19), "scale": 10.0, "rough": 0.92, "bump": 0.5, "grime": 0.3, "local_space": true}
		"camo_rebel":
			return {"pattern": CAMO, "col_a": Color(0.5, 0.45, 0.34), "col_b": Color(0.42, 0.36, 0.26), "col_c": Color(0.38, 0.37, 0.3), "col_d": Color(0.3, 0.26, 0.19), "scale": 8.0, "rough": 0.92, "bump": 0.5, "grime": 0.3, "local_space": true}
		"abrams_olive", "abrams_sand":
			var sand := kind == "abrams_sand"
			return {"pattern": CAMO, "col_a": Color("a29471") if sand else Color("707447"), "col_b": Color("918060") if sand else Color("514a35"), "col_c": Color("ae9d7c") if sand else Color("393e30"), "col_d": Color("978665") if sand else Color("939068"), "scale": 0.60, "rough": 0.82, "metal": 0.12, "bump": 0.52, "grime": 0.72, "local_space": true}
		"camo_tank":
			return {"pattern": CAMO, "col_a": Color(0.3, 0.32, 0.23), "col_b": Color(0.27, 0.29, 0.21), "col_c": Color(0.31, 0.29, 0.22), "col_d": Color(0.21, 0.21, 0.17), "scale": 0.7, "rough": 0.68, "metal": 0.25, "bump": 0.6, "grime": 0.9, "local_space": true}
		"camo_tank_rebel":
			return {"pattern": CAMO, "col_a": Color(0.46, 0.42, 0.32), "col_b": Color(0.41, 0.37, 0.28), "col_c": Color(0.44, 0.39, 0.29), "col_d": Color(0.32, 0.29, 0.22), "scale": 0.6, "rough": 0.68, "metal": 0.25, "bump": 0.6, "grime": 0.9, "local_space": true}
		"fabric":
			return {"pattern": CANVAS, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.48, 0.48, 0.48), "scale": 3.0, "rough": 0.95, "bump": 0.4, "grime": 0.2, "local_space": true}
		"hesco":
			return {"pattern": HESCO, "col_a": Color(0.6, 0.55, 0.42), "col_b": Color(0.4, 0.35, 0.26), "col_c": Color(0.22, 0.21, 0.2), "rough": 0.95, "bump": 1.6, "grime": 0.8}
		"hesco_cell":
			# one filled HESCO cell (a mesh of its own): the geotextile behind the
			# welded mesh, no cell seams (the cell's own edges are the seams)
			return {"pattern": HESCO, "col_a": Color(0.6, 0.55, 0.42), "col_b": Color(0.42, 0.37, 0.27), "col_c": Color(0.24, 0.23, 0.21), "rough": 0.95, "bump": 1.4, "grime": 1.0, "cell_w": 0.0}
		"precast":
			# precast and cast-in-place defence concrete: smooth formwork faces,
			# weathered and rain-streaked, none of the pitting of old walls
			return {"pattern": CONCRETE, "col_a": Color(0.56, 0.55, 0.52), "col_b": Color(0.38, 0.37, 0.34), "rough": 0.88, "bump": 0.7, "grime": 0.85, "pitting": 0.15, "seams": 0.0}
		"rust_steel":
			return {"pattern": PAINT, "col_a": Color(0.32, 0.2, 0.12), "col_b": Color(0.22, 0.2, 0.18), "rough": 0.85, "metal": 0.35, "bump": 1.0, "grime": 0.5, "rust": 1.0}
		"wire":
			# galvanised barbed and razor wire, dulled and spotted with rust
			return {"pattern": PAINT, "col_a": Color(0.44, 0.44, 0.42), "col_b": Color(0.56, 0.55, 0.52), "rough": 0.42, "metal": 0.75, "bump": 0.0, "grime": 0.2, "rust": 0.35, "scale": 4.0}
		"bag":
			return {"pattern": CANVAS, "col_a": Color(0.5, 0.45, 0.33), "col_b": Color(0.4, 0.36, 0.26), "scale": 1.6, "rough": 0.97, "bump": 0.8, "grime": 0.7, "local_space": true, "use_vcolor": true}
		"canvas_l":
			return {"pattern": CANVAS, "col_a": Color(0.42, 0.4, 0.29), "col_b": Color(0.33, 0.31, 0.22), "scale": 4.0, "rough": 0.95, "bump": 0.6, "grime": 0.2, "local_space": true}
		"suit":
			# close-woven uniform cloth (a sneaking suit, a field jacket): a faint
			# weave and soft folds, a little sheen
			return {"pattern": CANVAS, "col_a": Color(0.5, 0.5, 0.5), "col_b": Color(0.43, 0.43, 0.43), "scale": 5.0, "rough": 0.78, "bump": 0.35, "grime": 0.3, "local_space": true}
		"armor":
			# moulded armour and helmet shells: smooth, matte, scuffed
			return {"pattern": PLAIN, "col_a": Color(0.5, 0.5, 0.5), "rough": 0.58, "bump": 0.25, "grime": 0.25, "local_space": true}
		"webbing":
			return {"pattern": CANVAS, "col_a": Color(0.2, 0.2, 0.2), "col_b": Color(0.16, 0.16, 0.16), "scale": 6.0, "rough": 0.9, "bump": 0.5, "grime": 0.2, "local_space": true}
		"wood_l":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.2, 0.12), "col_b": Color(0.2, 0.13, 0.08), "scale": 3.0, "rough": 0.6, "bump": 0.4, "grime": 0.0, "local_space": true}
		"skin":
			return {"pattern": SKIN, "col_a": Color(0.8, 0.62, 0.5), "rough": 0.6, "bump": 0.0, "grime": 0.0, "local_space": true}
		"gunmetal":
			return {"pattern": PAINT, "col_a": Color(0.15, 0.15, 0.145), "col_b": Color(0.36, 0.35, 0.33), "rough": 0.52, "metal": 0.55, "bump": 0.35, "grime": 0.0, "local_space": true, "scale": 3.0}
		"boot":
			return {"pattern": CANVAS, "col_a": Color(0.16, 0.13, 0.1), "col_b": Color(0.11, 0.09, 0.07), "scale": 6.0, "rough": 0.75, "bump": 0.4, "grime": 0.0, "local_space": true}
	return {"pattern": PLAIN, "col_a": Color(0.6, 0.6, 0.6), "rough": 0.85}


## Far off, a soldier is his colours (see _bake_groups).
const DISTANT_SHADER := """
shader_type spatial;
// CLOUD_SHADOW
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""


const SURFACE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform int pattern = 0;
uniform sampler2D photo_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D photo_surface : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 photo_mean : source_color = vec3(0.5);
uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 col_a : source_color = vec3(0.6);
uniform vec3 col_b : source_color = vec3(0.4);
uniform vec3 col_c : source_color = vec3(0.5);
uniform vec3 col_d : source_color = vec3(0.2);
uniform float scale = 1.0;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float bump = 1.0;
uniform float grime = 0.5;
uniform float wet = 0.0;  // streets in the rain (Mats.set_street_wet)
global uniform float rain_wet;  // how soaked everything out in the rain is, 0..1 (Atmosphere._rain_tick)
uniform float weathering = 0.0;
uniform bool grain_horizontal = false;
uniform bool worn_armour = false;
uniform sampler2D armour_field : filter_linear, repeat_disable;
instance uniform float armour_section = -1.0;
uniform sampler2D wear_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rust = 0.0;
uniform float pitting = 1.0;  // concrete: how much of the old pitting shows
uniform float seams = 1.0;  // concrete: the formwork joints
uniform float cell_w = 1.05;  // HESCO: the width of a cell
uniform float lit = 0.0;  // lamplight behind it (a window, a lantern): glows as the light goes
global uniform float window_glow;  // how much lamplight shows: the time of day (Atmosphere.lamplight)
uniform bool local_space = false;
// Shared vehicle maps are linear data, projected in metres without mesh UVs.
uniform bool vehicle_surface = false;
uniform bool surface_detail = false;
uniform sampler2D surface_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float surface_scale = 3.0;
uniform float surface_wear = 0.0;
uniform float surface_tone = 0.0;
uniform float surface_roughness = 0.22;
uniform float surface_corrosion = 0.0;
uniform float surface_coat = 0.0;
uniform float surface_specular = 0.4;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float surface_normal_strength = 0.0;
uniform int surface_finish = 0; // coating, rubber, cloth, metal, grip, timber, char, moulded, glass
uniform float surface_weather = 0.0;
uniform float surface_paint_wear = 0.0;
uniform float surface_grain = 0.0;
uniform float surface_coat_roughness = 0.22;
uniform bool use_vcolor = false;
uniform float vcolor_k = 1.0;  // merged parts: the vertex colour is stored scaled down (Mats.VC_K)
// paving (Mats.paving): a shell hole or a trench punches through it, as through the roads
uniform bool crater_cut = false;
uniform bool terrain_bound = false;
uniform sampler2DArray crater_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
uniform sampler2D trench_tex : hint_default_black, filter_linear, repeat_disable;
uniform float crater_half = 256.0;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec3 pofs = vec3(0.0);
// CLOUD_SHADOW

varying vec3 tp;
varying vec3 tn;
varying vec3 wpos;
varying vec3 seed;
varying float ground_y;
varying mat3 vehicle_normal_basis;

// STREET_SURFACE
// RAIN_DROPS
float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
// Value noise with one feature per unit, read from a mipmapped tileable
// texture: the GPU filters it, so fine detail averages out with distance
// instead of aliasing and crawling as the camera moves.
float tnoise(vec2 p) { return (texture(noise_tex, p * 0.0625).r - 0.467) * 1.103 + 0.5; }  // matched to the old procedural noise's spread
float tfbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * tnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }
// How much of a feature `period` units across survives at this pixel
// footprint: 1 when it spans 5+ pixels, 0 when it's under 1.5.
float keep(float period, float px) { return smoothstep(1.5, 5.0, period / max(px, 1e-5)); }

// The atlas contains the hull and the rotating turret in their own local frames.
vec3 armour_slice(vec2 xy, float z) {
	vec2 tile = vec2(mod(z,16.0),floor(z/16.0)+armour_section*16.0);
	return texture(armour_field,(tile*vec2(128.0,64.0)+xy*vec2(127.0,63.0)+0.5)/2048.0).rgb;
}

void vertex() {
	vehicle_normal_basis = transpose(inverse(mat3(MODELVIEW_MATRIX)));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_y = 0.0;
	if (terrain_bound && !local_space && grime > 0.0) {
		ground_y = terrain_height(crater_tex, (wpos.xz + crater_half) / (crater_half * 2.0));
	}
	// Moving through the world must not change camouflage or wear.
	seed = (vehicle_surface || local_space) ? vec3(0.0) : MODEL_MATRIX[3].xyz;
	if (local_space) {
		tp = VERTEX + pofs;
		tn = NORMAL;
	} else {
		tp = wpos;
		tn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (crater_cut) {
		vec2 cuv = (wpos.xz + crater_half) / (crater_half * 2.0);
		if (terrain_height(crater_tex, cuv) - terrain_geology(crater_tex, cuv) < -0.07 || texture(trench_tex, cuv).r > 0.5) {
			discard;
		}
	}
	vec3 an = abs(tn);
	vec2 uv;
	if (an.y > an.x && an.y > an.z) { uv = tp.xz; }
	else if (an.x > an.z) { uv = vec2(tp.z, tp.y); }
	else { uv = vec2(tp.x, tp.y); }
	// World-space patterns must stay fixed when scenery moves into a spatial batch.
	vec2 off = local_space ? vec2(h12(seed.xz * 0.37), h12(seed.zx * 0.71)) * 37.0 : vec2(0.0);
	uv *= scale;
	if (grain_horizontal) { uv = uv.yx; }
	// pattern units per pixel here (how fine a detail can still be drawn)
	vec2 fw = fwidth(uv);
	float px = max(fw.x, fw.y);
	// thresholds on filtered noise soften with distance rather than flicker
	float sw = clamp(px * 1.5, 0.0, 0.3);
	vec3 col = col_a;
	float h = 0.5;
	float r = rough;
	float m = metal;
	float street_tar = 0.0;
	float paint_worn = 0.0;
	if (pattern == 1 || pattern == 2) {
		// brick (pattern 2 = plaster with chipped areas showing brick)
		vec2 bs = vec2(0.25, 0.085);
		float kb = keep(bs.y, px);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float mx = smoothstep(0.0, 0.05, f.x) * smoothstep(1.0, 0.95, f.x);
		float my = smoothstep(0.0, 0.14, f.y) * smoothstep(1.0, 0.86, f.y);
		float b = mix(0.8, mx * my, kb);
		float rb = mix(0.5, h12(cell + off), kb);
		vec3 bc = (pattern == 1 ? mix(col_a, col_c, rb) : mix(col_c, col_c * 0.75, rb)) * (0.85 + 0.3 * tnoise(uv * 41.0));
		vec3 mortar = (pattern == 1 ? col_b : col_b * 0.9) * (0.9 + 0.2 * tnoise(uv * 27.0));
		vec3 brick = mix(mortar, bc, b);
		float bh = b * 0.7 + tnoise(uv * 35.0) * 0.15;
		if (pattern == 1) {
			col = brick; h = bh;
		} else {
			float n = tfbm(uv * 0.9 + off);
			float chip = smoothstep(0.69 - sw, 0.72 + sw, n + (1.0 - smoothstep(0.0, 1.2, wpos.y - ground_y)) * 0.06);
			vec3 pl = texture(photo_color, uv * 0.5).rgb * col_a * 1.8;
			float streak = tfbm(vec2(uv.x * 3.0, uv.y * 0.35) + off);
			pl = mix(pl, col_d, smoothstep(0.5, 0.8, streak) * 0.45);
			col = mix(pl, brick, chip);
			h = mix(0.9 + tnoise(uv * 18.0) * 0.1, bh * 0.6, chip);
			r = mix(rough, 0.95, chip);
		}
	} else if (pattern == 18) {
		col = street_surface(photo_color, noise_tex, wpos.xz, street_tar);
		h = 0.5;
	} else if (pattern == 22) {
		// Road paint is a thin film laid on the asphalt: it takes the stone's
		// grain, and tyres wear it through to the road beneath, most where they
		// run over it most.
		vec3 road = street_surface(photo_color, noise_tex, wpos.xz, street_tar);
		float grain = tnoise(wpos.xz * 22.0) * 0.6 + tnoise(wpos.xz * 7.0) * 0.4;
		float worn = smoothstep(0.60, 0.78, tfbm(wpos.xz * 0.7 + 3.1) + (tnoise(wpos.xz * 9.0) - 0.5) * 0.25);
		col = mix(col_a * (0.86 + 0.2 * grain) * mix(1.0, 0.82, smoothstep(0.4, 0.8, tfbm(wpos.xz * 0.35))), road / max(tint.rgb, vec3(0.05)), worn * 0.9);
		paint_worn = worn;
		street_tar *= worn;
		h = 0.5;
	} else if (pattern == 21) {
		// Keep the photographed variation while honoring the material and instance colours.
		col = texture(photo_color, uv + off * 0.03).rgb * col_a / max(photo_mean, vec3(0.01));
		float damp = smoothstep(0.38, 0.68, tfbm(wpos.xz * 0.15 + off));
		float streak = smoothstep(0.45, 0.72, tfbm(vec2(uv.x * 1.8, uv.y * 0.3) + off));
		col *= mix(1.0, 0.85 + 0.3 * tnoise(uv * 0.7 + off), weathering);
		col = mix(col, col * vec3(0.32, 0.38, 0.29), (damp * 0.5 + streak * 0.25) * weathering);
		h = 0.5;
	} else if (pattern == 19 || pattern == 20) {
		col = texture(photo_color, uv).rgb;
		if (pattern == 20) {
			float dry = smoothstep(0.35, 0.7, tfbm(wpos.xz * 0.08));
			col *= mix(vec3(0.23, 0.39, 0.16), vec3(0.36, 0.37, 0.21), dry);
		} else {
			// The photograph is laid in stretcher bond, three slabs across and six
			// courses down, every other course shifted half a slab: give each
			// slab its own shade along its real joints, not a grid across them.
			float course = floor(uv.y * 6.0);
			vec2 slab = vec2(floor(uv.x * 3.0 + 0.5 - mod(course, 2.0) * 0.5), course);
			float pick = h12(slab + 0.37);
			col *= 0.93 + 0.12 * h12(slab);
			// Desaturate the warm scan toward plain grey concrete.
			col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), 0.35);
			// now and then a slab relaid newer and paler, or one gone dark with oil or damp
			col = mix(col, col * vec3(1.10, 1.11, 1.13), step(0.93, pick));
			col *= 1.0 - 0.16 * step(pick, 0.04);
			float staining = smoothstep(0.53, 0.72, tfbm(wpos.xz * 0.21 + 13.0));
			col *= mix(vec3(1.0), vec3(0.70, 0.69, 0.65), staining * 0.55);
			// footfall polishes the middle of the way, grit gathers at the edges
			float trodden = smoothstep(0.45, 0.75, tfbm(wpos.xz * 0.6 + 41.0));
			col *= 1.0 - trodden * 0.06;
		}
		h = 0.5;
	} else if (pattern == 3) {
		col = col_a * (0.86 + 0.22 * tfbm(uv * 2.1 + off));
		float st = tfbm(uv * 0.6 + off * 0.3);
		col = mix(col, col_b, smoothstep(0.42, 0.78, st) * 0.75);
		// rain streaks running down from the top
		float rs3 = tfbm(vec2(uv.x * 4.0, uv.y * 0.3) + off * 0.5);
		col = mix(col, col_b * 0.85, smoothstep(0.55, 0.8, rs3) * 0.35);
		vec2 g = abs(fract(uv / vec2(2.0, 1.25)) - 0.5);
		float seam = smoothstep(0.485, 0.497, max(g.x, g.y)) * keep(0.1, px) * seams;
		float pits = smoothstep(0.93, 0.97, h12(floor(uv * 60.0) + off)) * keep(0.05, px) * pitting;
		col *= 1.0 - seam * 0.35 - pits * 0.1;
		h = 1.0 - seam * 0.6 - pits * 0.5 + tnoise(uv * 25.0) * 0.08;
	} else if (pattern == 4) {
		vec2 bs = vec2(0.58, 0.2);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5 + h12(vec2(row, off.x)) * 0.3;
		vec2 f = fract(q) - 0.5;
		float d = length(f * vec2(1.0, 1.7));
		float bulge = mix(0.6, clamp(1.0 - d * d * 2.4, 0.0, 1.0), keep(bs.y, px));
		float weave = ((sin(uv.x * 420.0) * sin(uv.y * 420.0)) * 0.5 + 0.5 - 0.5) * keep(0.015, px) + 0.5;
		col = mix(col_b, col_a, bulge * 0.7 + 0.3) * (0.88 + 0.18 * tnoise(uv * 13.0 + off) + weave * 0.04);
		h = bulge;
		r = 0.97;
	} else if (pattern == 5) {
		float pw = 0.19;
		float row = floor(uv.y / pw);
		float fy = fract(uv.y / pw);
		float gap = mix(0.85, smoothstep(0.0, 0.06, fy) * smoothstep(1.0, 0.94, fy), keep(pw * 0.5, px));
		float grain = tfbm(vec2(uv.x * 1.3 + row * 7.3, uv.y * 30.0));
		col = mix(col_b, col_a, grain) * (0.85 + 0.25 * mix(0.5, h12(vec2(row, off.y)), keep(pw, px)));
		col *= 0.5 + 0.5 * gap;
		h = gap * (0.8 + grain * 0.2);
	} else if (pattern == 6) {
		vec2 camo_uv = vehicle_surface ? uv * 2.4 : uv;
		float c1 = tfbm(camo_uv * 1.0 + off);
		float c2 = tfbm(camo_uv * 1.25 + off + 13.0);
		float c3 = tfbm(camo_uv * 1.6 + off + 29.0);
		col = col_a;
		col = mix(col, col_b, smoothstep(0.5 - sw, 0.53 + sw, c1));
		col = mix(col, col_c, smoothstep(0.56 - sw, 0.59 + sw, c2));
		col = mix(col, col_d, smoothstep(0.62 - sw, 0.65 + sw, c3));
		col *= 0.92 + 0.12 * tnoise(uv * 23.0);
		h = 0.5 + tnoise(uv * 30.0) * 0.2;
		if (worn_armour) {
			// Keep the patina attached to the moving panel. The same worn
			// patches interrupt the paint sheen and collect dirt below.
			float wear = smoothstep(0.19, 0.42, texture(wear_tex, uv * 0.46 + off).r);
			float runoff = smoothstep(0.26, 0.35, texture(wear_tex, uv * vec2(4.1,0.42) + off).r);
			col *= mix(1.0, mix(0.91, 1.02, runoff), 1.0-abs(tn.y));
			float recess = 1.0 - smoothstep(0.18, 0.48, wear);
			float dust = smoothstep(0.28, 0.70, wear) * (1.0 - smoothstep(0.2, 1.6, tp.y));
			col *= mix(0.85, 1.09, wear);
			col = mix(col, vec3(0.055,0.041,0.027), recess * 0.22);
			col = mix(col, vec3(0.19,0.145,0.086), dust * 0.25);
			r = mix(0.55, 0.93, wear);
			h += wear * 0.13;
			if (armour_section >= 0.0) {
				vec3 minimum = armour_section < 0.5 ? vec3(-1.92,-0.10,-4.05) : vec3(-1.92,-0.12,-3.36);
				vec3 size = armour_section < 0.5 ? vec3(3.84,1.92,8.0) : vec3(3.84,1.92,6.72);
				vec3 uvw = clamp((tp + normalize(tn)*0.022 - minimum)/size, vec3(0.0), vec3(1.0));
				float slice = uvw.z*255.0;
				vec3 field = mix(armour_slice(uvw.xy,floor(slice)),armour_slice(uvw.xy,min(255.0,floor(slice)+1.0)),fract(slice));
				// Dust catches on upward-facing plate and collects against raised fittings.
				float shelf = smoothstep(0.22, 0.85, tn.y) * smoothstep(0.22, 0.36, texture(wear_tex, uv * 0.69).r);
				col = mix(col, vec3(0.34, 0.26, 0.15), shelf * (0.21 + 0.19 * field.r));
				r = mix(r, 0.94, shelf);
				AO = 1.0 - field.r * 0.73;
				AO_LIGHT_AFFECT = 0.17;
				col *= 1.0 - field.b * 0.32;
				float chip = field.g * smoothstep(0.54,0.85,wear);
				col = mix(col,vec3(0.22,0.20,0.16),chip*0.46);
				m = mix(m,0.56,chip);
				r = mix(r,0.47,chip);
			}
		}
	} else if (pattern == 7) {
		col = col_a * (0.9 + 0.14 * tnoise(uv * 7.0 + off));
		float wear = smoothstep(0.68 - sw, 0.74 + sw, tfbm(uv * 3.5 + off));
		col = mix(col, col_b, wear);
		m = mix(metal, 0.85, wear);
		r = mix(rough, 0.35, wear);
		float rs = tfbm(vec2(uv.x * 5.0, uv.y * 0.6) + off) * (0.4 + rust);
		col = mix(col, vec3(0.32, 0.17, 0.08), smoothstep(0.55, 0.8, rs) * (0.08 + rust * 0.7));
		h = 0.6 - wear * 0.3 + tnoise(uv * 50.0) * 0.05;
	} else if (pattern == 8) {
		float n = tfbm(uv * 1.7 + off);
		col = mix(col_b, col_a, n) * (0.85 + 0.25 * tnoise(uv * 19.0));
		float peb = smoothstep(0.86, 0.93, h12(floor(uv * 14.0) + off)) * keep(0.07, px);
		col = mix(col, col * 1.45 + vec3(0.015), peb * 0.6);  // stones a shade lighter than the soil
		h = n * 0.7 + peb * 0.4;
	} else if (pattern == 9) {
		float ridge = mix(0.5, 0.5 + 0.5 * sin(uv.x * 6.2831 / 0.09), keep(0.09, px));
		col = col_a * (0.82 + 0.18 * ridge) * (0.9 + 0.15 * tnoise(uv * 4.0 + off));
		float rs = tfbm(vec2(uv.x * 2.0, uv.y * 0.4) + off);
		col = mix(col, col_b, smoothstep(0.55, 0.85, rs) * 0.8);
		h = ridge;
	} else if (pattern == 10) {
		float weave = ((sin(uv.x * 380.0) * sin(uv.y * 380.0)) * 0.5) * keep(0.0165, px) + 0.5;
		float fold = tfbm(uv * 1.3 + off);
		col = mix(col_b, col_a, fold) * (0.95 + weave * 0.08);
		h = fold * 0.8 + weave * 0.1;
	} else if (pattern == 11) {
		vec2 bs = vec2(0.5, 0.3);
		float kb = keep(bs.y, px);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += h12(vec2(row, 3.7 + off.x));
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = mix(0.82, smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.12, f.y) * smoothstep(1.0, 0.88, f.y), kb);
		float rb = mix(0.5, h12(cell + off), kb);
		vec3 sc = mix(col_a, col_c, rb) * (0.82 + 0.3 * tnoise(uv * 13.0));
		col = mix(col_b * 0.8, sc, e);
		h = e * (0.75 + 0.25 * tnoise(uv * 9.0 + rb * 10.0));
	} else if (pattern == 12) {
		float fib = tfbm(vec2(uv.x * 9.0, uv.y * 0.8) + off);
		col = mix(col_b, col_a, fib);
		h = fib;
	} else if (pattern == 13) {
		float link = fract(uv.y / 0.16);
		float ridge = mix(0.6, smoothstep(0.1, 0.2, link) * smoothstep(0.9, 0.8, link), keep(0.08, px));
		col = mix(col_a, col_b, (1.0 - ridge) * 0.4) * (0.85 + 0.25 * tnoise(uv * 20.0));
		h = ridge;
	} else if (pattern == 15) {
		float kt = keep(0.45, px);
		vec2 q = uv / 0.45;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = mix(0.9, smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x) * smoothstep(0.0, 0.04, f.y) * smoothstep(1.0, 0.96, f.y), keep(0.12, px));
		float rb = mix(0.5, h12(cell + off), kt);
		vec3 tc = mix(col_a, col_c, mix(0.3, step(0.5, mod(cell.x + cell.y, 2.0)) * 0.6, kt)) * (0.85 + 0.25 * rb);
		float dirt = tfbm(uv * 0.8 + off);
		tc = mix(tc, col_b, smoothstep(0.45, 0.75, dirt) * 0.6);
		col = mix(col_b * 0.7, tc, e);
		h = e * 0.8 + tnoise(uv * 40.0) * 0.05;
		r = mix(0.95, rough - dirt * 0.2, e);
	} else if (pattern == 16) {
		// (cell 0: a single cell modelled on its own - no seams, no bulge drawn in)
		float has_cell = step(0.01, cell_w);
		vec2 q = uv / max(cell_w, 0.01);
		vec2 hcell = floor(q) * has_cell;
		vec2 f = fract(q);
		vec2 c2 = f - 0.5;
		float bulge = mix(0.5, clamp(1.0 - dot(c2, c2) * 2.2, 0.0, 1.0), has_cell);
		float seam = (1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)))) * keep(0.1, px) * has_cell;
		vec2 wq = fract(uv / 0.075);
		float wire = (1.0 - smoothstep(0.0, 0.12, min(min(wq.x, 1.0 - wq.x), min(wq.y, 1.0 - wq.y)))) * keep(0.04, px) + 0.15 * (1.0 - keep(0.04, px));
		float stain = tfbm(uv * 1.3 + off);
		vec3 fab = mix(col_a, col_b, smoothstep(0.35, 0.8, stain) * 0.8) * (0.85 + 0.25 * mix(0.5, h12(hcell + off), keep(max(cell_w, 0.01), px) * has_cell));
		col = mix(fab, col_c, max(wire * 0.55, seam * 0.8));
		h = bulge * 0.8 - wire * 0.1 - seam * 0.5;
		m = mix(0.0, 0.6, wire * 0.6);
	} else if (pattern == 17) {
		vec3 weights = pow(abs(normalize(tn)), vec3(4.0));
		weights /= weights.x + weights.y + weights.z;
		vec4 stone = texture(stone_texture, tp.zy * scale) * weights.x
			+ texture(stone_texture, tp.xz * scale) * weights.y
			+ texture(stone_texture, tp.xy * scale) * weights.z;
		col = stone.rgb * vec3(1.02, 1.06, 1.10);
		h = stone.a;
	} else if (pattern == 14) {
		col = col_a * (0.95 + 0.08 * tnoise(uv * 30.0));
		h = 0.5;
	} else {
		col = col_a * (0.92 + 0.12 * tnoise(uv * 5.0 + off));
		h = 0.5 + tnoise(uv * 20.0) * 0.1;
	}
	float corrosion = 0.0;
	float finish_film = 0.0;
	float finish_fade = 0.0;
	float paint_edge = 0.0;
	float paint_chip = 0.0;
	float paint_stain = 0.0;
	if (vehicle_surface) {
		// Paint is a dielectric coating. Only the sparse exposed chips become
		// metallic; rubber, fabric and glass retain their own response.
		if (pattern == 0) { col = col_a; h = 0.5; }
		if (surface_detail) {
			vec3 weights = pow(abs(normalize(tn)), vec3(4.0));
			weights /= max(dot(weights, vec3(1.0)), 0.0001);
			vec3 q = tp * surface_scale;
			vec4 detail = texture(surface_map, q.yz) * weights.x
				+ texture(surface_map, q.xz) * weights.y
				+ texture(surface_map, q.xy) * weights.z;
			if (surface_normal_strength > 0.0) {
				vec3 nx = texture(surface_normal_map, q.yz).rgb * 2.0 - 1.0;
				vec3 ny = texture(surface_normal_map, q.xz).rgb * 2.0 - 1.0;
				vec3 nz = texture(surface_normal_map, q.xy).rgb * 2.0 - 1.0;
				// Project tangent slopes, then remove their normal component. A flat
				// map preserves the geometric normal on every face and at blends.
				vec3 slope = vec3(0.0, nx.x, nx.y) * weights.x
					+ vec3(ny.x, 0.0, ny.y) * weights.y + vec3(nz.x, nz.y, 0.0) * weights.z;
				vec3 base = normalize(tn);
				slope -= base * dot(slope, base);
				NORMAL = normalize(vehicle_normal_basis * normalize(base + slope * surface_normal_strength));
			}
			h = (pattern == 13 || pattern == 5) ? h + (detail.r - 0.5) * 0.15 : detail.r;
			r = clamp(rough + (detail.g - 0.5) * surface_roughness, 0.06, 1.0);
			col *= 1.0 + (detail.a - 0.5) * surface_tone;
			corrosion = detail.b * surface_corrosion;
			// Broad weathering and fine relief have separate physical scales. Local
			// coordinates keep both attached to moving and rotating assemblies.
			if (surface_paint_wear > 0.0) {
				// UV belongs to the original body piece, so a baked chassis retains
				// panel edges without drawing a repeated grid across the vehicle.
				vec2 border = min(UV, vec2(1.0) - UV);
				float edge_distance = min(border.x, border.y);
				float aa = max(fwidth(edge_distance), 0.0001);
				float broken = tnoise(tp.xz * 430.0 + tp.y * 237.0);
				paint_edge = (1.0 - smoothstep(0.004, 0.022 + aa, edge_distance)) * surface_paint_wear * min(1.0, 0.022 / aa);
				paint_chip = paint_edge * smoothstep(0.51, 0.69, broken);
				paint_edge *= 0.3 + 0.7 * tnoise(tp.xz * 85.0 + tp.y * 43.0);
				// Narrow runoff, with irregular lengths, reads down upright skins.
				float runs = tnoise(vec2((tp.x + tp.z) * 100.0, tp.y * 8.0));
				paint_stain = smoothstep(0.60, 0.78, runs) * (1.0 - abs(normalize(tn).y)) * surface_paint_wear;
				r += paint_stain * 0.18;
			}
			float broad = tnoise(tp.xz * 18.0 + tp.y * 3.7);
			float streak = tnoise(vec2((tp.x + tp.z) * 130.0, tp.y * 9.0));
			float upward = smoothstep(0.15, 0.8, normalize(tn).y);
			finish_film = surface_weather * (0.20 + 0.50 * broad) * (0.45 + 0.55 * upward);
			finish_fade = surface_weather * (broad - 0.45) * 0.35;
			r += surface_weather * (streak - 0.5) * (1.0 - upward) * 0.16;
			vec2 grain_uv = an.y > an.x && an.y > an.z ? tp.xz : (an.x > an.z ? tp.zy : tp.xy);
			float pixel = max(length(dFdx(grain_uv)), length(dFdy(grain_uv)));
			float grain = tnoise(grain_uv * 260.0);
			if (surface_finish == 3) {
				// Brushing runs along the surface, with roughness rather than
				// painted bright lines. It fades before it can crawl at distance.
				grain = tnoise(grain_uv * vec2(4.0, 520.0));
				r += (grain - 0.5) * surface_grain * keep(0.025, pixel);
			} else if (surface_finish == 2) {
				float weave = sin(grain_uv.x * 1256.637) * sin(grain_uv.y * 1256.637);
				h += weave * 0.12 * surface_grain * keep(0.005, pixel);
				col *= 1.0 + (detail.a - 0.5) * 0.32;
				// Sewn panels supply UVs; ordinary cloth meshes keep their own weave.
				vec2 hem = min(UV, vec2(1.0) - UV);
				float hem_distance = min(hem.x, hem.y);
				float stitch = (1.0 - smoothstep(0.006, 0.015, abs(hem_distance - 0.035)))
					* step(0.45, fract((UV.x + UV.y) * 65.0)) * keep(0.018, pixel);
				col *= 1.0 + stitch * 0.28;
			} else if (surface_finish == 1 || surface_finish == 7 || surface_finish == 4) {
				h += (grain - 0.5) * surface_grain * keep(0.025, pixel);
				r += (grain - 0.5) * surface_grain * 0.15;
			} else if (surface_finish == 5) {
				float fibres = tnoise(grain_uv * vec2(3.0, 180.0));
				h += (fibres - 0.5) * surface_grain * keep(0.04, pixel);
				col *= 0.88 + 0.24 * fibres;
			} else if (surface_finish == 6) {
				// Char maps have no alpha channel: height supplies their ash variation.
				col *= 0.68 + 0.70 * detail.r;
				h += (grain - 0.5) * surface_grain * 0.18;
			}
			// Sparse scuffs use a threshold, not a grey metallic wash over paint.
			float worn = smoothstep(0.74, 0.91, detail.r) * surface_wear;
			col = mix(col, vec3(0.12, 0.13, 0.14), worn);
			m = mix(metal, 0.85, worn);
			r = mix(r, 0.4, worn);
		}
	}
	col *= tint.rgb;
	if (use_vcolor) { col *= COLOR.rgb * vcolor_k; }
	// Rust is an oxide, not reflective steel tinted orange. Apply after the
	// part tint so corroded fittings retain their mineral color.
	col = mix(col, mix(vec3(0.09, 0.032, 0.012), vec3(0.28, 0.12, 0.035), corrosion), corrosion);
	m = mix(m, 0.0, corrosion);
	r = mix(r, 0.94, corrosion);
	if (vehicle_surface) {
		col *= 1.0 + finish_fade;
		col *= 1.0 - paint_stain * 0.08;
		// Rubbed paint lightens first, with small dark primer chips rather than
		// bright silver outlining every polygon. Paint stays nonmetallic.
		col = mix(col, col * 1.35 + vec3(0.025), paint_edge * 0.65);
		col = mix(col, vec3(0.075, 0.08, 0.07), paint_chip * 0.45);
		r = mix(r, 0.84, paint_chip);
		// A thin dry film softens reflections without repainting faction colours.
		col = mix(col, col * 0.72 + vec3(0.10, 0.085, 0.06), finish_film);
		r = mix(r, 0.92, finish_film);
		m *= 1.0 - finish_film;
	}
	// broad, soft variation across a surface (sun-bleached, weathered, damp
	// patches): large enough never to alias, it keeps big walls from looking flat
	vec3 weather_pos = vehicle_surface ? tp : wpos;
	float macro = tfbm(weather_pos.xz * 0.11 + weather_pos.y * 0.07 + off * 0.2);
	if (vehicle_surface) { col *= 0.96 + 0.08 * macro; }
	else if (pattern == 21) { col *= mix(1.0, 0.88 + 0.24 * macro, weathering); }
	else if (pattern != 18 && pattern != 22) { col *= 0.88 + 0.24 * macro; }
	// grime and dust toward the ground
	float low = 1.0 - smoothstep(0.0, 0.9, weather_pos.y - ground_y);
	float gn = tnoise(uv * 2.0 + off);
	float dirt = low * grime * (0.6 + 0.4 * gn);
	col = mix(col, vehicle_surface ? vec3(0.12, 0.095, 0.065) : col * 0.62 + vec3(0.05, 0.04, 0.02), dirt);
	ALBEDO = col;
	ROUGHNESS = clamp(r + (macro - 0.5) * (vehicle_surface ? 0.04 : 0.12) + (vehicle_surface ? dirt * 0.15 : 0.0), 0.05, 1.0);
	if ((pattern >= 18 && pattern <= 20 || pattern == 22) && an.y > 0.5) {
		vec2 puv = wpos.xz / 2.2;
		if (pattern == 19 || pattern == 20) { puv = uv; }
		vec4 surface = texture(photo_surface, puv);
		vec3 normal = surface.rgb * 2.0 - 1.0;
		normal.xy *= pattern == 22 ? mix(0.08, 0.18, paint_worn) : 0.18;
		NORMAL = normalize((VIEW_MATRIX * vec4(ground_surface_basis(wpos) * normal, 0.0)).xyz);
		ROUGHNESS = clamp(surface.a, 0.65, 1.0);
		// tar is smoother than the aggregate; paint smoother still where it's whole
		ROUGHNESS = mix(ROUGHNESS, 0.5, street_tar * 0.7);
		if (pattern == 22) { ROUGHNESS = mix(0.58, ROUGHNESS, paint_worn); }
	}
	if (pattern == 21 || pattern == 2) {
		vec4 photo = texture(photo_surface, pattern == 2 ? uv * 0.5 : uv + off * 0.03);
		vec3 n = photo.rgb * 2.0 - 1.0;
		n.xy *= 0.45;
		vec3 dx = dFdx(VERTEX); vec3 dy = dFdy(VERTEX);
		vec2 tx = dFdx(uv); vec2 ty = dFdy(uv);
		float handed = sign(tx.x * ty.y - tx.y * ty.x);
		vec3 tangent = (dx * ty.y - dy * tx.y) * handed;
		vec3 bitangent = (dy * tx.x - dx * ty.x) * handed;
		if (dot(tangent, tangent) > 0.000001 && dot(bitangent, bitangent) > 0.000001) {
			NORMAL = normalize(normalize(tangent) * n.x + normalize(bitangent) * n.y + NORMAL * n.z);
		}
		ROUGHNESS = clamp(photo.a, 0.7, 1.0);
	}
	METALLIC = vehicle_surface ? m * (1.0 - dirt) : m;
	SPECULAR = vehicle_surface ? surface_specular : 0.4;
	if ((pattern == 18 || pattern == 22) && wet > 0.0) {
		// as the road ribbons do it: darkened by the rain, puddles in the dips
		vec3 soaked = ALBEDO;
		if (OUTPUT_IS_SRGB) { soaked = mix(soaked / 12.92, pow((soaked + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), soaked)); }
		float pud = wet * smoothstep(0.55, 0.75, street_puddle(noise_tex, wpos.xz));
		soaked *= 1.0 - wet * 0.3;
		soaked = mix(soaked, soaked * 0.4, pud);
		if (OUTPUT_IS_SRGB) { soaked = mix(soaked * 12.92, 1.055 * pow(max(soaked, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), soaked)); }
		ALBEDO = soaked;
		ROUGHNESS = mix(ROUGHNESS - wet * 0.3, 0.06, pud);
		SPECULAR = mix(0.3, 0.55, pud);
		// the rain rings the puddles and, faintly, the wet film on the stone
		vec2 ring = rain_rings(wpos.xz, length(fwidth(wpos.xz)), max(pud, wet * 0.25));
		NORMAL = normalize(NORMAL - (VIEW_MATRIX * vec4(ring.x, 0.0, ring.y, 0.0)).xyz);
		ROUGHNESS = mix(ROUGHNESS, max(ROUGHNESS, 0.22), rain_far(length(fwidth(wpos.xz))) * pud);
	}
	CLEARCOAT = vehicle_surface ? surface_coat : 0.0;
	CLEARCOAT_ROUGHNESS = vehicle_surface ? surface_coat_roughness : 0.22;
	// lamplight in a window by dusk and night, brighter in some rooms than
	// others (a hash of where the window is, so a batch keeps each one's)
	if (lit > 0.0) {
		float room = fract(sin(dot(floor(wpos.xz * 0.6) + floor(wpos.y * 0.4), vec2(12.9898, 78.233))) * 43758.5453);
		EMISSION = col_c * lit * window_glow * (0.55 + 0.9 * room);
	}
	// bump mapping from the pattern height (surface gradient); the height is
	// band-limited above, so its screen-space slope is stable under motion
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
	if (rain_wet > 0.0) {
		// Out in the rain everything takes a film of water (after Lagarde,
		// "Water drop 2b: dynamic rain and its effects", 2013). Rough, porous
		// stuff (cloth, timber, concrete, earth on a track) soaks it up and
		// darkens, since light now scatters inside the wet pores and less comes
		// back out; smooth paint and metal barely change colour. Either way the
		// film is smooth, so it all turns glossy, upturned faces most. Faces
		// turned down stay drier, and the water runs down walls and hulls in
		// streaks rather than evenly.
		vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float exposed = mix(0.25, 1.0, smoothstep(-0.6, 0.3, wn.y));
		float streak = smoothstep(0.35, 0.8, tnoise(vec2((wpos.x + wpos.z) * 5.0, wpos.y * 0.3)));
		float soak = rain_wet * exposed * mix(0.55 + 0.6 * streak, 1.0, smoothstep(0.5, 0.9, abs(wn.y)));
		float porous = clamp((ROUGHNESS - 0.35) * 1.8, 0.0, 1.0) * (1.0 - METALLIC);
		float darken = 1.0 - soak * (0.08 + 0.47 * porous);
		ALBEDO *= OUTPUT_IS_SRGB ? pow(darken, 1.0 / 2.2) : darken;
		// (water stands as a film on paint and metal; cloth and timber drink most of it)
		ROUGHNESS = mix(ROUGHNESS, mix(0.34, 0.12, smoothstep(0.4, 0.9, wn.y)), soak * mix(0.85, 0.35, porous));
		// While it's still coming down, drops burst on every roof, deck and
		// helmet near the camera, and water runs down the walls and hull sides
		// in rivulets along the streaks. A vehicle carries its rivulets with it
		// (they're laid out in its own frame); the drops fall in the world's.
		if (rain_fx.y > 0.0) {
			float footprint = length(fwidth(wpos)) * 0.7;
			float near = rain_wet * (1.0 - smoothstep(25.0, 40.0, distance(CAMERA_POSITION_WORLD, wpos)));
			float crown = rain_crowns(wpos.xz, footprint, near * smoothstep(0.55, 0.85, wn.y));
			ALBEDO = mix(ALBEDO, OUTPUT_IS_SRGB ? vec3(0.66) : vec3(0.4), crown * 0.7);
			ROUGHNESS = mix(ROUGHNESS, 0.08, crown);
			float side = 1.0 - smoothstep(0.3, 0.6, abs(wn.y));
			if (rain_fx.z > 0.0 && side * near > 0.0) {
				vec3 lp = vehicle_surface ? (wpos - MODEL_MATRIX[3].xyz) * mat3(MODEL_MATRIX) : wpos;
				vec2 run = rain_rivulets(lp.x + lp.z, lp.y, footprint) * side * near * mix(0.4, 1.0, streak);
				ALBEDO *= 1.0 - run.x * mix(0.15, 0.3, porous);
				ROUGHNESS = mix(ROUGHNESS, 0.04, run.x * 0.9);
				// (a bead's top turns up to the sky and catches its light)
				NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz * run.y * 0.9);
			}
		}
	}
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""


const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 tint : source_color = vec4(0.2, 0.32, 0.14, 1.0);
uniform float wind = 1.0;
uniform bool leaf_cards = false;
uniform bool vertex_lit = false;
uniform float leaf_tone = 1.0;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_vcolor = false;
// on fire (a burning tree's own copy, see Structure._apply_char): the leaves
// shrivel brown, blacken and burn away, glowing at the edges while it burns
uniform float scorch = 0.0;
uniform float embers = 0.0;
// CLOUD_SHADOW

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
	if (!leaf_cards) {
		float lump = n3(wp * 1.3) * 0.55 + n3(wp * 3.1) * 0.25;
		VERTEX += NORMAL * (lump - 0.4) * 0.5;
	}
	float t = TIME * 1.3 + wp.x * 0.11 + wp.z * 0.07;
	float sway = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.3) * wind * 0.06 * clamp(VERTEX.y + 1.0, 0.0, 2.0);
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	lpos = wp;
	shade = clamp(NORMAL.y * 0.35 + 0.65, 0.0, 1.0);
	// Leaf cards keep soft canopy lighting when the browser skips fragment normals.
	if (leaf_cards && vertex_lit) {
		vec3 canopy_normal = MODEL_NORMAL_MATRIX * NORMAL;
		canopy_normal.y = abs(canopy_normal.y);
		NORMAL = normalize(inverse(MODEL_NORMAL_MATRIX) * mix(canopy_normal, vec3(0.0, 1.0, 0.0), 0.35));
	}
}

void fragment() {
	// ragged, leafy edges: holes open up where the surface turns away from
	// the eye (and from the sun, so the shadows are dappled too)
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	// detail finer than a few pixels is replaced by its average, so the holes
	// and leaf speckle don't fizz as the camera moves
	float px = max(length(fwidth(lpos)), 1e-4);
	float k6 = smoothstep(1.5, 5.0, (1.0 / 6.0) / px);
	float k15 = smoothstep(1.5, 5.0, (1.0 / 15.0) / px);
	float holes = 0.5;
	if (!leaf_cards || scorch > 0.0) { holes = mix(0.5, n3(lpos * 6.0 + 11.0), k6) * 0.6 + mix(0.5, n3(lpos * 15.0), k15) * 0.4; }
	if (!leaf_cards && rim > 0.12 && holes < (rim - 0.12) * 1.25) {
		discard;
	}
	float burnt = holes - scorch * 1.15 + 0.3;
	if (scorch > 0.0 && burnt < 0.0) {
		discard;
	}
	float leaves = 0.5;
	float gaps = 0.5;
	if (!leaf_cards || scorch > 0.0) {
		leaves = mix(0.5, n3(lpos * 9.0), smoothstep(1.5, 5.0, (1.0 / 9.0) / px));
		gaps = mix(0.5, n3(lpos * 4.2 + 7.0), smoothstep(1.5, 5.0, (1.0 / 4.2) / px));
	}
	vec3 c = use_vcolor ? COLOR.rgb : tint.rgb;
	if (OUTPUT_IS_SRGB) { c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
	c *= 0.7 + 0.5 * leaves;
	if (leaf_cards) {
		vec4 photo = texture(leaf_texture, UV);
		if (photo.a < 0.22) { discard; }
		if (OUTPUT_IS_SRGB) { photo.rgb = mix(photo.rgb / 12.92, pow((photo.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), photo.rgb)); }
		c = photo.rgb * leaf_tone * mix(vec3(0.75), vec3(1.15), clamp(c * 12.0, vec3(0.0), vec3(1.0)));
	}
	c = mix(c, c * vec3(1.15, 1.1, 0.7), smoothstep(0.55, 0.8, gaps) * 0.5);
	if (scorch > 0.0) {
		// (linear colours: a withered brown, then soot)
		vec3 dry = vec3(0.06, 0.03, 0.01) * (0.7 + 0.5 * leaves);
		c = mix(c, dry, smoothstep(0.0, 0.3, scorch + (gaps - 0.5) * 0.3));
		c = mix(c, vec3(0.006, 0.005, 0.004), smoothstep(0.25, 0.7, scorch + (leaves - 0.5) * 0.4));
		float edge = 1.0 - smoothstep(0.0, 0.05, burnt);
		EMISSION = vec3(1.0, 0.32, 0.05) * embers * edge * (0.9 + 0.6 * sin(TIME * 7.0 + lpos.x * 3.0 + lpos.y * 5.0));
	}
	ALBEDO = c * (0.55 + 0.45 * shade);
	if (OUTPUT_IS_SRGB) { ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO)); }
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35, 0.42, 0.18) * (1.0 - scorch);
	AO = 0.55 + 0.45 * shade;
	AO_LIGHT_AFFECT = 0.6;
	if (leaf_cards) {
		vec3 canopy_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		canopy_normal.y = abs(canopy_normal.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(mix(canopy_normal, vec3(0.0, 1.0, 0.0), 0.35), 0.0)).xyz);
	} else {
		float bh = leaves * 0.6 + gaps * 0.4;
		vec3 dpdx = dFdx(VERTEX); vec3 dpdy = dFdy(VERTEX);
		float dhx = dFdx(bh); float dhy = dFdy(bh);
		vec3 r1 = cross(dpdy, NORMAL); vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * 0.06);
	}
	// CLOUD_FRAGMENT cloud_sun(lpos)
}
"""


const NETTING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform vec4 tint : source_color = vec4(0.3, 0.34, 0.2, 1.0);
uniform float sag = 0.45;  // a flat net slung between poles sags in the middle
// CLOUD_SHADOW
varying vec3 wp;
float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	vec2 u = UV * 2.0 - 1.0;
	VERTEX.y -= (1.0 - u.x * u.x) * (1.0 - u.y * u.y) * sag;
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
	// the garnish: darker brown and near-black scraps knotted in, breaking it up
	c = mix(c, c * vec3(0.62, 0.5, 0.38), step(0.6, vn(p * 2.3 + 31.0)) * 0.75);
	c = mix(c, c * 0.35, step(0.7, vn(p * 4.1 + 57.0)) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.5;
	// CLOUD_FRAGMENT cloud_sun(wp)
}
"""
