class_name Camo
extends RefCounted
## Camouflage: printed patterns for uniforms, and disruptive paint for the
## buildings of a base.
##
## A uniform's pattern is printed on the cloth, so it has hard edges and
## motifs of a fixed size in centimetres, and it runs on round a sleeve
## without a seam. Each pattern is one of a few printing styles (woodland
## blotches with black branches, fleck dots, square pixels, tiger stripes,
## soft multi-terrain shapes, rain lines) in its own colours, after the real
## patterns armies issue. The procedural soldiers wear it through the shared
## surface shader (Mats, pattern CAMO with camo_style > 0); the imported
## character wears it through swat_material, which reprints the cloth of its
## texture and keeps the folds.
##
## Buildings put up for a base are painted over in big blotches of a few
## earth colours that run on across walls, corners and roof, so the box
## breaks up at a distance (Mats "paint0:" / "paint1:" kinds, see painted()).

# --- the patterns --------------------------------------------------------------------

const WOODLAND := 1
const FLECK := 2
const DIGITAL := 3
const TIGER := 4
const MULTI := 5
const RAIN := 6

## Each pattern: its printing style, five colours (ground, then the shapes
## printed over it in order), how much of the cloth each covers (for the
## colour it averages to at a distance), its size (motifs per metre) and how
## much wider than tall its shapes are drawn.
const PATTERNS := {
	# US woodland: broad interlocking sand-green, green and brown with black
	# branches over them
	"woodland": {"style": WOODLAND, "cols": ["7b7b55", "485235", "5c4733", "211f1b", "211f1b"], "cover": [0.2, 0.32, 0.33, 0.15, 0.0], "scale": 4.6, "stretch": Vector3(0.85, 1.2, 0.85)},
	# Vietnam-era leaf pattern: smaller, leafier shapes, more green
	"leaf": {"style": WOODLAND, "cols": ["8a9264", "3d5135", "6a5134", "1d1e19", "1d1e19"], "cover": [0.26, 0.36, 0.24, 0.14, 0.0], "scale": 7.0, "stretch": Vector3(1.0, 1.35, 1.0)},
	# three-colour desert: wide pale strokes on sand, no black
	"desert": {"style": WOODLAND, "cols": ["a99977", "8d8664", "76604c", "76604c", "76604c"], "cover": [0.45, 0.3, 0.25, 0.0, 0.0], "scale": 3.4, "stretch": Vector3(0.75, 1.4, 0.75)},
	# five-colour fleck: clusters of dots that merge into blotches
	"fleck": {"style": FLECK, "cols": ["7e7f5f", "38432e", "626f45", "5a4130", "1d1e19"], "cover": [0.3, 0.25, 0.2, 0.15, 0.1], "scale": 5.2, "stretch": Vector3(1.0, 1.0, 1.0)},
	# woodland printed in square pixels
	"digital": {"style": DIGITAL, "cols": ["77725a", "4f563d", "5b4a37", "28282a", "28282a"], "cover": [0.34, 0.3, 0.24, 0.12, 0.0], "scale": 5.5, "stretch": Vector3(1.0, 1.0, 1.0)},
	"digital_desert": {"style": DIGITAL, "cols": ["8f8064", "766650", "5a4a39", "9c9276", "9c9276"], "cover": [0.36, 0.3, 0.2, 0.14, 0.0], "scale": 5.5, "stretch": Vector3(1.0, 1.0, 1.0)},
	# tiger stripe: narrow green and black brush strokes across khaki
	"tiger": {"style": TIGER, "cols": ["7a7550", "45502f", "1c1d18", "5a4c33", "1c1d18"], "cover": [0.36, 0.34, 0.22, 0.08, 0.0], "scale": 3.8, "stretch": Vector3(0.5, 2.6, 0.5)},
	# rain: fine short vertical dashes over a grey-khaki ground
	"rain": {"style": RAIN, "cols": ["868669", "6e715a", "3b4636", "3b4636", "3b4636"], "cover": [0.55, 0.3, 0.15, 0.0, 0.0], "scale": 3.0, "stretch": Vector3(1.0, 1.0, 1.0)},
	# multi-terrain: a soft tan-to-green ground, brown shapes, thin dark
	# branches and cream highlights
	"multi": {"style": MULTI, "cols": ["9c8d68", "707350", "6a553e", "3a3127", "c0b18c"], "cover": [0.35, 0.3, 0.2, 0.08, 0.07], "scale": 3.6, "stretch": Vector3(1.0, 1.0, 1.0)},
	# the Coalition's tonal slate: their sneaking suits' grey, broken up in
	# shades of itself
	"slate": {"style": MULTI, "cols": ["4f5659", "41474b", "33393c", "212527", "5f6669"], "cover": [0.36, 0.3, 0.2, 0.08, 0.06], "scale": 3.6, "stretch": Vector3(1.0, 1.0, 1.0)},
	"slate_digital": {"style": DIGITAL, "cols": ["434a4d", "393f42", "2e3336", "232729", "232729"], "cover": [0.36, 0.3, 0.22, 0.12, 0.0], "scale": 5.5, "stretch": Vector3(1.0, 1.0, 1.0)},
}

## What the Rebels have on: surplus from everywhere, so each man's jacket
## and trousers may be a different pattern or plain. Weights out of 100.
const REBEL_TOPS := [["woodland", 18], ["leaf", 9], ["tiger", 10], ["fleck", 9], ["rain", 8], ["digital", 8], ["digital_desert", 4], ["desert", 6], ["multi", 8], ["", 20]]

## The colour a pattern averages to (what it reads as from far off).
static func mean(name: String) -> Color:
	var p: Dictionary = PATTERNS[name]
	var c := Color(0, 0, 0)
	var cols: Array = p.cols
	var cover: Array = p.cover
	for i in 5:
		var k := Color(String(cols[i]))
		c += Color(k.r, k.g, k.b) * float(cover[i])
	return Color(c.r, c.g, c.b)


## The Mats preset for cloth printed in a pattern (kind "camo/NAME").
static func cloth_preset(name: String) -> Dictionary:
	var p: Dictionary = PATTERNS.get(name, PATTERNS["woodland"])
	var cols: Array = p.cols
	return {"pattern": Mats.CAMO, "camo_style": p.style, "col_a": Color(String(cols[0])), "col_b": Color(String(cols[1])),
		"col_c": Color(String(cols[2])), "col_d": Color(String(cols[3])), "camo_e": Color(String(cols[4])), "camo_mean": mean(name),
		"camo_stretch": p.stretch, "scale": p.scale, "rough": 0.9, "bump": 0.4, "grime": 0.35, "local_space": true}


## One pattern from a weighted list, or "" for plain cloth.
static func pick(table: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in table:
		total += int(e[1])
	var r := rng.randi() % total
	for e in table:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return ""


# --- the shader ----------------------------------------------------------------------

## The printing styles, for any shader that declares col_a..col_d, noise_tex,
## tnoise(), h12() and keep() first (the shared surface shader, swat_shader).
const GLSL := """
uniform int camo_style = 0;  // Camo: 0 the old soft blotches, else the printing style
uniform vec3 camo_e : source_color = vec3(0.1);
uniform vec3 camo_mean : source_color = vec3(0.4);  // what the print averages to
uniform vec3 camo_stretch = vec3(1.0);  // how much finer the shapes are along local x, y, z

// Two octaves of the filtered noise: the shapes' outline, with a ragged edge.
float camo_n(vec2 p) { return tnoise(p) * 0.64 + tnoise(p * 2.13 + 5.3) * 0.36; }

// One field over a curved surface: noise from the three projections, blended
// by the way the surface faces before it's cut into shapes, so a blotch runs
// on unbroken round a sleeve. Where projections blend the sum has less
// contrast; dividing by the weights' length gives it back.
float camo_f(vec3 p, vec3 w) {
	float f = (camo_n(p.zy + 3.7) - 0.5) * w.x + (camo_n(p.xz + 7.3) - 0.5) * w.y + (camo_n(p.xy + 1.1) - 0.5) * w.z;
	return 0.5 + f / max(length(w), 0.35);
}

// A printed edge: hard, antialiased to the pixel.
float camo_cut(float f, float t) {
	float s = max(fwidth(f) * 0.75, 0.003);
	return smoothstep(t - s, t + s, f);
}

// One dot in each cell, jittered, of varying size: the dots of a fleck pattern.
float camo_dot(vec2 p) {
	vec2 c = floor(p);
	vec2 j = vec2(h12(c), h12(c + 19.7)) - 0.5;
	float d = length(fract(p) - 0.5 - j * 0.34);
	float r = 0.24 + 0.2 * h12(c + 7.3);
	float aa = max(fwidth(d), 0.001);
	return 1.0 - smoothstep(r - aa, r + aa, d);
}

// The projection the surface mostly faces (for the dot and pixel grids, which
// can't be blended).
vec2 camo_face(vec3 p, vec3 w) {
	return (w.x > w.y && w.x > w.z) ? p.zy : ((w.y > w.z) ? p.xz : p.xy);
}

// The print at p (in motifs: about one blotch per unit), facing by weights w,
// px motifs per pixel. Detail too small to see fades to the colour it
// averages to rather than crawl.
vec3 camo_print(vec3 p, vec3 w, float px) {
	vec3 c = col_a;
	vec3 q = p * camo_stretch;
	if (camo_style == 1) {
		// woodland: blotches of three colours interlocking over the ground
		// colour (their outlines pushed about by a second field, so they
		// meander), black branches over the top
		vec2 wv = vec2(camo_f(q * 0.55 + 41.0, w), camo_f(q * 0.55 + 83.0, w)) - 0.5;
		vec3 wq = q + vec3(wv.x, wv.y, wv.x) * 1.2;
		c = mix(c, col_b, camo_cut(camo_f(wq, w), 0.47));
		c = mix(c, col_c, camo_cut(camo_f(wq * 1.13 + 13.0, w), 0.535));
		c = mix(c, col_d, camo_cut(camo_f(wq * vec3(1.5, 2.2, 1.5) + 29.0, w), 0.6));
	} else if (camo_style == 2) {
		// fleck: each colour a cluster of dots, dense in the middle (where they
		// merge into a blotch) and thinning out at its edge
		vec2 d = camo_face(q, w) * 6.5;
		float dk = keep(1.0 / 6.5, px);
		c = mix(c, col_c, camo_cut(camo_f(q * 0.9 + 5.0, w) + (camo_dot(d) - 0.5) * 0.24 * dk, 0.52));
		c = mix(c, col_b, camo_cut(camo_f(q * 1.05 + 23.0, w) + (camo_dot(d + vec2(0.5, 0.31)) - 0.5) * 0.24 * dk, 0.535));
		c = mix(c, col_d, camo_cut(camo_f(q * 1.2 + 47.0, w) + (camo_dot(d * 1.1 + vec2(0.23, 0.67)) - 0.5) * 0.26 * dk, 0.565));
		c = mix(c, camo_e, camo_cut(camo_f(q * 1.4 + 71.0, w) + (camo_dot(d * 1.2 + vec2(0.71, 0.13)) - 0.5) * 0.28 * dk, 0.6));
	} else if (camo_style == 3) {
		// digital: the blotches printed in square pixels (with distance, the
		// pixels go and the blotches stay)
		vec2 d = camo_face(q, w);
		float pix = 9.0;
		vec2 g = mix(d, (floor(d * pix) + 0.5) / pix, keep(2.0 / pix, px));
		float f1 = camo_n(g + 3.0);
		float f2 = camo_n(g * 1.17 + 31.0);
		float f3 = camo_n(g * 1.6 + 57.0);
		float s = keep(2.0 / pix, px) > 0.5 ? 0.0001 : 0.03;
		c = mix(c, col_b, smoothstep(0.47 - s, 0.47 + s, f1));
		c = mix(c, col_c, smoothstep(0.535 - s, 0.535 + s, f2));
		c = mix(c, col_d, smoothstep(0.6 - s, 0.6 + s, f3));
	} else if (camo_style == 4) {
		// tiger stripe: long narrow brush strokes across the body, wavering,
		// with a dry-brush fringe
		vec3 wq = q;
		wq.y += (camo_f(q * vec3(0.9, 0.12, 0.9) + 11.0, w) - 0.5) * 3.0;
		float fringe = (camo_f(q * vec3(5.0, 1.4, 5.0) + 61.0, w) - 0.5) * 0.12 * keep(0.08, px);
		c = mix(c, col_d, camo_cut(camo_f(wq * 0.8 + 37.0, w), 0.58));
		c = mix(c, col_b, camo_cut(camo_f(wq, w) + fringe, 0.5));
		c = mix(c, col_c, camo_cut(camo_f(wq * vec3(1.0, 1.4, 1.0) + 19.0, w) + fringe * 1.4, 0.58));
	} else if (camo_style == 5) {
		// multi-terrain: a ground that shades softly from one colour to the
		// next, soft-edged shapes over it, then thin dark branches and pale
		// highlights, which are the only hard edges
		c = mix(col_a, col_b, smoothstep(0.4, 0.6, camo_f(q * 0.45 + 3.0, w)));
		float f2 = camo_f(q * 1.1 + 13.0, w);
		c = mix(c, col_c, smoothstep(0.53, 0.58, f2));
		float f3 = camo_f(q * 1.9 + 29.0, w);
		float line = 1.0 - smoothstep(0.012, 0.012 + max(fwidth(f3), 0.002), abs(f3 - 0.5));
		c = mix(c, col_d, line * camo_cut(camo_f(q * 0.7 + 51.0, w), 0.52) * keep(0.05, px));
		c = mix(c, col_d, camo_cut(f3, 0.64));
		c = mix(c, camo_e, camo_cut(camo_f(q * 2.3 + 77.0, w), 0.64));
	} else if (camo_style == 6) {
		// rain: faint blotches, and short fine vertical dashes all over
		c = mix(c, col_b, camo_cut(camo_f(q * 0.6 + 7.0, w), 0.55));
		float dash = camo_f(q * vec3(9.0, 0.9, 9.0) + 21.0, w) + (camo_f(q * vec3(2.0, 2.4, 2.0) + 43.0, w) - 0.5) * 0.4;
		c = mix(c, col_c, camo_cut(dash, 0.63) * keep(0.11, px));
	}
	return mix(camo_mean, c, keep(0.18, px));
}

// --- disruptive paint over a building ----------------------------------------------
uniform bool paint_on = false;
uniform vec3 paint_a : source_color = vec3(0.3, 0.32, 0.22);
uniform vec3 paint_b : source_color = vec3(0.33, 0.27, 0.2);
uniform vec3 paint_c : source_color = vec3(0.13, 0.13, 0.12);

// The colour a painted surface is, given what it was (col, as tinted: its
// relief and grime show through the paint) and the colour it was meant to
// be (base), `above` metres above the ground. Big blotches several metres across, laid out in the world so
// they run on round corners and up onto the roof; flaked off here and there.
vec3 camo_paint(vec3 col, vec3 base, vec3 wp, vec3 wn, float above) {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 q = wp * vec3(0.24, 0.32, 0.24);
	vec2 wv = vec2(camo_f(q * 0.5 + 41.0, w), camo_f(q * 0.5 + 83.0, w)) - 0.5;
	vec3 wq = q + vec3(wv.x, wv.y, wv.x);
	vec3 p = paint_a;
	p = mix(p, paint_b, camo_cut(camo_f(wq, w), 0.5));
	p = mix(p, paint_c, camo_cut(camo_f(wq * 1.2 + 31.0, w), 0.585));
	float lb = max(dot(base, vec3(0.2126, 0.7152, 0.0722)), 0.01);
	float shade = clamp(dot(col, vec3(0.2126, 0.7152, 0.0722)) / lb, 0.35, 1.5);
	// what faces the sky has faded chalky in the sun
	float up = smoothstep(0.3, 0.9, wn.y);
	float pl = dot(p, vec3(0.2126, 0.7152, 0.0722));
	p = mix(p, mix(p, vec3(pl), 0.6) * 1.12, up * 0.4);
	// brushed or sprayed on in the field: uneven, thinner here and there
	p *= 0.9 + 0.2 * camo_n(wp.xz * 0.9 + wp.y * 1.7 + 3.0);
	// and worn through in small flakes, most of all low down where boots and
	// barrows knock it
	float low = 1.0 - smoothstep(0.2, 1.6, above);
	float flake = camo_cut(camo_n(wp.xz * 4.3 + wp.y * 3.1 + 9.0) * 0.55 + camo_n(wp.zy * 9.0 + wp.x * 4.0) * 0.45, 0.735 - low * 0.05);
	return mix(p * shade, col, flake * 0.6);
}
"""


# --- buildings -----------------------------------------------------------------------

## Surfaces a base's buildings are painted over on (not glass, concrete
## footings, rubber, the red cross...).
const PAINTABLE := ["timber", "corrugated", "roof_sheet", "precast", "steel", "metal_dark", "paint", "wood_painted"]

## Paint schemes by side: the Coalition's green, brown and black; the Rebels'
## sand, earth and olive.
const SCHEMES := [
	[Color("4c5440"), Color("5a4e3e"), Color("2a2a25")],
	[Color("9c8e70"), Color("6c5b47"), Color("5c5d48")],
]


## The kind of a surface painted over in a side's scheme (or the surface
## itself, if it's not one that gets painted).
static func painted(kind: String, side: int) -> String:
	if side < 0 or side > 1 or not kind in PAINTABLE:
		return kind
	return "paint%d:%s" % [side, kind]


## The Mats preset for "paintN:KIND".
static func paint_preset(kind: String, base: Dictionary) -> Dictionary:
	var side := int(kind.substr(5, 1))
	var p := base.duplicate()
	var s: Array = SCHEMES[side]
	p["paint_on"] = true
	p["paint_a"] = s[0]
	p["paint_b"] = s[1]
	p["paint_c"] = s[2]
	return p


## Camouflage nets' garnish, by side: the Coalition's woodland (green, dark
## green, brown, near-black), the Rebels' desert (sand, earth, khaki, pale).
const NETS := [
	[Color("4a5432"), Color("333b25"), Color("54452f"), Color("1d1e18")],
	[Color("5c513d"), Color("4a3e2e"), Color("464432"), Color("6d634d")],
]


## A net's colours, for the netting shader (Mats.netting).
static func dress_net(net: GeometryInstance3D, side: int) -> void:
	var c: Array = NETS[clampi(side, 0, 1)]
	Mats.set_inst(net, &"tint", c[0])
	Mats.set_inst(net, &"net_b", c[1])
	Mats.set_inst(net, &"net_c", c[2])
	Mats.set_inst(net, &"net_d", c[3])


# --- the imported character ----------------------------------------------------------

## The imported character's cloth reprinted in a pattern: its texture's print
## is a grey digital one, so the shader takes the folds and seams from it
## (blurred, so the old print goes) and prints the pattern in its UV space;
## the dark kit (vest, webbing, pouches) is recoloured to `gear` with its own
## detail kept. "digital" patterns reuse the texture's own pixels.
const SWAT_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 col_a : source_color = vec3(0.6);
uniform vec3 col_b : source_color = vec3(0.4);
uniform vec3 col_c : source_color = vec3(0.5);
uniform vec3 col_d : source_color = vec3(0.2);
uniform float scale = 9.0;  // motifs per unit of UV
uniform vec3 gear : source_color = vec3(0.1);  // what the black kit becomes
uniform bool recolour_gear = false;
uniform bool body = true;  // the body surface (cloth and vest), or the kit
uniform bool print_digital = false;  // reuse the texture's own pixels
uniform bool reprint = true;  // or leave the cloth's own print
instance uniform vec2 camo_seed = vec2(0.0);

float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float tnoise(vec2 p) { return (texture(noise_tex, p * 0.0625).r - 0.467) * 1.103 + 0.5; }
float keep(float period, float px) { return smoothstep(1.5, 5.0, period / max(px, 1e-5)); }
// CAMO
vec3 lin(vec3 c) { return OUTPUT_IS_SRGB ? mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)) : c; }
float lum(vec3 c) { return dot(lin(c), vec3(0.2126, 0.7152, 0.0722)); }

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float l = lum(t);
	vec3 col = t;
	if (body) {
		// cloth is the lighter part of this texture, the vest and helmet the
		// near-black; decided on the blurred texture so the print's dark
		// pixels stay cloth
		float lb = lum(textureLod(albedo_tex, UV, 4.0).rgb);
		float cloth = smoothstep(0.024, 0.045, lb);
		// folds and seams: the texture's shading, without its print
		float shade = clamp(lb / 0.13, 0.25, 1.35) * mix(1.0, clamp(l / max(lb, 0.001), 0.7, 1.25), 0.25);
		vec3 print;
		if (print_digital) {
			// the texture's own pixels, sorted by brightness into the colours
			print = col_a;
			print = mix(print, col_b, 1.0 - smoothstep(0.17, 0.2, l));
			print = mix(print, col_c, 1.0 - smoothstep(0.095, 0.115, l));
			print = mix(print, col_d, 1.0 - smoothstep(0.045, 0.06, l));
			shade = clamp(lb / 0.13, 0.4, 1.25);
		} else {
			vec2 fw = fwidth(UV * scale);
			print = camo_print(vec3((UV + camo_seed) * scale, 0.0), vec3(0.0, 0.0, 1.0), max(fw.x, fw.y));
		}
		if (reprint) {
			col = mix(col, print * shade, cloth);
		}
		if (recolour_gear) {
			col = mix(gear * clamp(l / 0.012, 0.3, 2.6), col, cloth);
		}
	} else if (recolour_gear) {
		// the kit: black webbing and pouches take the gear colour; the pale
		// parts (gloves, pads) stay as they are
		col = mix(col, gear * clamp(l / 0.012, 0.3, 2.6), 1.0 - smoothstep(0.025, 0.06, l));
	}
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""

static var _swat_shader: Shader
static var _swat_mats := {}


## The material for one surface of the imported character (0 the body, 1
## its kit), printed in `pattern` ("" for its own grey print) with the black
## kit in `gear` (or left black).
static func swat_material(original: StandardMaterial3D, surface: int, pattern: String, gear: Variant) -> ShaderMaterial:
	var key := "%d|%s|%s|%s" % [original.get_instance_id(), surface, pattern, str(gear)]
	if _swat_mats.has(key):
		return _swat_mats[key]
	if _swat_shader == null:
		_swat_shader = Shader.new()
		_swat_shader.code = Mats.code(SWAT_SHADER.replace("// CAMO", GLSL))
	var m := ShaderMaterial.new()
	m.shader = _swat_shader
	m.set_shader_parameter("albedo_tex", original.albedo_texture)
	m.set_shader_parameter("normal_tex", original.normal_texture)
	m.set_shader_parameter("noise_tex", Mats.noise_tex())
	m.set_shader_parameter("body", surface == 0)
	if gear is Color:
		m.set_shader_parameter("recolour_gear", true)
		m.set_shader_parameter("gear", gear)
	if pattern != "" and surface == 0:
		var p := cloth_preset(pattern)
		for k in ["camo_style", "col_a", "col_b", "col_c", "col_d", "camo_e", "camo_mean", "camo_stretch"]:
			m.set_shader_parameter(k, p[k])
		# (UV runs about 2 m to the unit over this character)
		m.set_shader_parameter("scale", float(p.scale) * 2.0)
		m.set_shader_parameter("print_digital", int(p.camo_style) == DIGITAL)
	elif surface == 0:
		m.set_shader_parameter("reprint", false)
	_swat_mats[key] = m
	return m
