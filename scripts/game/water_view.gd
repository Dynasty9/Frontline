class_name WaterView
extends Node3D
## (view) The water as the player sees it: the sea, the rivers and the ponds
## WaterMap lays out. A swell rolls in off the open sea and breaks on the
## beach, the surf running up the sand and draining back; the sky and the sun
## shine off the surface, the bed shows through the shallows and the deep goes
## dark; foam gathers wherever the water meets something. Boats leave wakes
## (a wash of white water astern, the bow wave spreading in a V), shells and
## bullets throw up foam, and a sunk boat leaves a boil and a slick of oil.
##
## The swell is one set of waves (SWELL) that the shaders draw and height_at
## samples, so a boat rides the same waves the player sees. Everything on the
## water keeps time by the `water_time` global shader uniform (project.godot).

const TILE := 64.0  # the surface is drawn in tiles this big, only where there's water
const TILE_SUB := 31  # (2 m quads: fine enough for the swell)

## The sea's swell: trains of waves rolling in from the open sea to the east,
## each [heading, wavelength (m), height (m)]. Waves in deep water run at
## sqrt(g L / 2 pi), the long ones fastest. The first SWELL_MOVES lift the
## surface (and the boats on it); the short ones only ruffle the light.
const SWELL := [
	[Vector2(-0.97, 0.24), 44.0, 0.2],
	[Vector2(-0.86, -0.51), 27.0, 0.13],
	[Vector2(-0.74, 0.67), 17.5, 0.08],
	[Vector2(-0.99, -0.12), 9.5, 0.045],
	[Vector2(-0.6, 0.8), 6.1, 0.028],
	[Vector2(-0.83, -0.56), 4.3, 0.018],
]
const SWELL_MOVES := 3
## The surf: a breaker comes ashore every SURF_L metres at SURF_C m/s, and
## the water it throws up the beach stands up to SURGE above the sea.
const SURF_L := 15.0
const SURF_C := 2.1
const SURGE := 0.32

## Patches of foam on the water (see foam()).
const RING := 0  # a shell's splash: a ring running outward, foam where the column fell back
const BOIL := 1  # water boiling up white (a boat going down, a big splash's heart)
const OIL := 2  # fuel and oil from a wreck, spreading in a dark, rainbowed film
const PATCHES := 64

var world
var water: WaterMap
var t := 0.0  # water_time: what the shaders run the waves by
var mat: ShaderMaterial
var wake_mat: ShaderMaterial
var patch_mat: ShaderMaterial
var mask_tex: ImageTexture
var chop_tex: NoiseTexture2D
var foam_tex: NoiseTexture2D
var _tiles: Array = []
var _mask: Image
var _sea_x := 1e9
var _wk := PackedFloat32Array()  # per moving wave: kx, kz, omega, height, phase
var _wakes := {}  # eid -> Wake
var _patches: Array = []  # [mi, ends at]
var _patch_i := 0


func _init(w) -> void:
	world = w
	name = "Water"
	for i in SWELL_MOVES:
		var sw: Array = SWELL[i]
		var d: Vector2 = (sw[0] as Vector2).normalized()
		var k := TAU / float(sw[1])
		_wk.append_array([k * d.x, k * d.y, sqrt(9.81 * k), float(sw[2]), i * 1.7])


## Lays the surface over the water (and again whenever the water changes).
func build(w: WaterMap, detail: Texture2D) -> void:
	water = w
	_mask = w.mask
	_sea_x = (float(w.coast.x) + 30.0) if not w.coast.is_empty() else 1e9
	if mask_tex == null:
		mask_tex = ImageTexture.create_from_image(w.mask)
	else:
		mask_tex.set_image(w.mask)
	if mat == null:
		_make_textures()
		mat = _material(WATER_SHADER, detail)
		mat.render_priority = -10  # under everything else see-through: smoke, splashes, wakes
		wake_mat = _material(WAKE_SHADER, detail)
		wake_mat.render_priority = -5
		patch_mat = _material(PATCH_SHADER, detail)
		patch_mat.render_priority = -5
		_make_patches()
	for m in [mat, wake_mat, patch_mat]:
		m.set_shader_parameter("water_mask", mask_tex)
		m.set_shader_parameter("sea_x", _sea_x)
	var c := Vector3.ZERO
	if not w.coast.is_empty():
		c = Vector3(float(w.coast.x), float(w.coast.s), 1.0)
	mat.set_shader_parameter("coast", c)
	_lay_tiles()


func _material(code: String, detail: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Mats.code(MapDims.shader(code.replace("__WAVES__", waves_glsl()).replace("__LEVEL__", "%.3f" % WaterMap.LEVEL)))
	m.shader = sh
	m.set_shader_parameter("detail_tex", detail)
	m.set_shader_parameter("chop_tex", chop_tex)
	m.set_shader_parameter("foam_tex", foam_tex)
	return m


## The wind's chop (a tiling normal map) and foam: a web of bubbles, bright
## along the cells' edges, that thins into lace as it breaks up.
func _make_textures() -> void:
	var cn := FastNoiseLite.new()
	cn.seed = 7
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.03
	cn.fractal_type = FastNoiseLite.FRACTAL_FBM
	cn.fractal_octaves = 4
	chop_tex = NoiseTexture2D.new()
	chop_tex.width = 256
	chop_tex.height = 256
	chop_tex.seamless = true
	chop_tex.as_normal_map = true
	chop_tex.bump_strength = 6.0
	chop_tex.noise = cn
	var fn := FastNoiseLite.new()
	fn.seed = 3
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = 0.07
	fn.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 2
	fn.fractal_gain = 0.4
	foam_tex = NoiseTexture2D.new()
	foam_tex.width = 256
	foam_tex.height = 256
	foam_tex.seamless = true
	foam_tex.noise = fn


## Tiles of surface wherever there's water (or the sea's beach, where the
## surf runs up): the map's water mask boxed down to 16 m cells, four to a tile.
func _lay_tiles() -> void:
	for ti in _tiles:
		ti.queue_free()
	_tiles.clear()
	var small := _mask.duplicate() as Image
	while small.get_width() > int(MapDims.SIZE / 16.0):
		small.shrink_x2()  # (box-filtered: a trickle of water still shows)
	var sn := small.get_width()
	var cell := MapDims.SIZE / sn
	var ext := MapDims.HALF + 132.0
	var n := ceili(ext * 2.0 / TILE)
	var x0 := -n * TILE * 0.5
	var pm := PlaneMesh.new()
	pm.size = Vector2(TILE, TILE)
	pm.subdivide_width = TILE_SUB
	pm.subdivide_depth = TILE_SUB
	for tz in n:
		for tx in n:
			var r := Rect2(x0 + tx * TILE, x0 + tz * TILE, TILE, TILE)
			var wet := r.end.x > _sea_x
			if not wet:
				var cx0 := floori((r.position.x + MapDims.HALF) / cell)
				var cz0 := floori((r.position.y + MapDims.HALF) / cell)
				var per := int(TILE / cell)
				for cz in range(maxi(0, cz0 - 1), mini(sn, cz0 + per + 1)):
					for cx in range(maxi(0, cx0 - 1), mini(sn, cx0 + per + 1)):
						var c := small.get_pixel(cx, cz)
						if c.a > 0.0 or c.g > 0.0:
							wet = true
							break
					if wet:
						break
			if not wet:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 1.0  # (the swell lifts it)
			mi.position = Vector3(r.get_center().x, WaterMap.LEVEL, r.get_center().y)
			add_child(mi)
			_tiles.append(mi)


## Lighting follows the time of day (Atmosphere's moods).
func apply_mood(d: Dictionary, mood: String) -> void:
	if mat == null:
		return
	var cloudy := 1.0 if mood in ["overcast", "rain"] else 0.55
	for m in [mat, wake_mat]:
		m.set_shader_parameter("zenith", d.zenith)
		m.set_shader_parameter("horizon", d.horizon)
		m.set_shader_parameter("ambient", float(d.ambient))
	mat.set_shader_parameter("clouds", cloudy)
	# (under cloud there's no glitter, only a sheen)
	mat.set_shader_parameter("sun_k", {"overcast": 0.1, "rain": 0.06, "hazy": 0.55}.get(mood, 1.0))
	mat.set_shader_parameter("rain", 1.0 if mood == "rain" else 0.0)
	# rain and a grey sky: a darker, duller sea
	var dull := 1.0 if mood in ["overcast", "rain", "night"] else 0.0
	mat.set_shader_parameter("sea_tint", Color(0.025, 0.14, 0.21).lerp(Color(0.08, 0.15, 0.17), dull))
	mat.set_shader_parameter("shoal_tint", Color(0.12, 0.46, 0.46).lerp(Color(0.16, 0.28, 0.27), dull))


func _process(dt: float) -> void:
	t += dt
	RenderingServer.global_shader_parameter_set("water_time", t)
	for k in _wakes.keys():
		var wk: Wake = _wakes[k]
		if t - wk.seen > Wake.LIFE:
			wk.mi.queue_free()
			_wakes.erase(k)
	for p in _patches:
		if p[0].visible and t > float(p[1]):
			p[0].visible = false


# --- the swell ---------------------------------------------------------------------

## GLSL for the swell (see SWELL): swell_v(p, t) = (height, d/dx, d/dz) of the
## waves that lift the surface, swell_f(p, t) = the slope of the short ones.
static func waves_glsl() -> String:
	var v := "vec3 swell_v(vec2 p, float t) { vec3 r = vec3(0.0); float a;"
	var f := "vec2 swell_f(vec2 p, float t) { vec2 r = vec2(0.0); float a;"
	for i in SWELL.size():
		var sw: Array = SWELL[i]
		var d: Vector2 = (sw[0] as Vector2).normalized()
		var k := TAU / float(sw[1])
		var amp := float(sw[2])
		var ph := " a = %.6f * p.x + %.6f * p.y - %.6f * t + %.3f;" % [k * d.x, k * d.y, sqrt(9.81 * k), i * 1.7]
		if i < SWELL_MOVES:
			v += ph + " r += vec3(%.5f * sin(a), %.6f * cos(a), %.6f * cos(a));" % [amp, amp * k * d.x, amp * k * d.y]
		else:
			f += ph + " r += vec2(%.6f, %.6f) * cos(a);" % [amp * k * d.x, amp * k * d.y]
	var c := "const float SURF_L = %.2f; const float SURF_C = %.2f; const float SURGE = %.3f;" % [SURF_L, SURF_C, SURGE]
	var e := "float swell_env(vec2 p) { return 0.62 + 0.38 * sin(p.x * 0.0113 + p.y * 0.0171) * sin(p.x * 0.0067 - p.y * 0.0131 + 1.3); }"
	return c + " " + e + " " + v + " return r * swell_env(p); } " + f + " return r * swell_env(p); }"


## How far the swell has lifted (or dropped) the water at p just now: 0 off
## the sea, and dying away in the shallows.
func height_at(p: Vector3) -> float:
	if _mask == null:
		return 0.0
	var k := 0.0
	if absf(p.x) >= MapDims.HALF or absf(p.z) >= MapDims.HALF:
		k = 1.0 if p.x > _sea_x else 0.0
	else:
		var c := _mask.get_pixel(int(p.x + MapDims.HALF), int(p.z + MapDims.HALF))
		k = c.b * smoothstep(0.06, 0.55, c.r)
	if k <= 0.0:
		return 0.0
	var h := 0.0
	for i in SWELL_MOVES:
		var j := i * 5
		h += _wk[j + 3] * sin(_wk[j] * p.x + _wk[j + 1] * p.z - _wk[j + 2] * t + _wk[j + 4])
	# (the waves come in groups: see swell_env in waves_glsl)
	var env := 0.62 + 0.38 * sin(p.x * 0.0113 + p.z * 0.0171) * sin(p.x * 0.0067 - p.z * 0.0131 + 1.3)
	return h * k * env


# --- wakes -----------------------------------------------------------------------------

## The wake a boat leaves: samples of where she was, every few metres - her
## stern (the wash spreads from there) and her bow (the bow wave's two arms
## run out from there in a V) - drawn as three strips whose spreading and
## fading the shader works out from each sample's age. A ring of slots: the
## newest overwrites the oldest, with a collapsed "break" between them.
class Wake:
	const CAP := 72
	const LIFE := 16.0
	const PER := 7  # vertices a slot: the wash (port, middle, starboard), each arm (inner, outer)
	var mi: MeshInstance3D
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var head := 0
	var last := Vector3.INF  # where the last sample was laid
	var seen := 0.0
	var hidden := false

	func _init() -> void:
		var n := CAP * PER
		verts.resize(n)
		norms.resize(n)
		cols.resize(n)
		uvs.resize(n)
		uv2s.resize(n)
		# each slot to the next: the wash two quads across, each arm one
		for s in CAP:
			var a := s * PER
			var b := ((s + 1) % CAP) * PER
			for q in [[0, 1], [1, 2], [3, 4], [5, 6]]:
				var i0: int = q[0]
				var i1: int = q[1]
				for j in [a + i0, b + i0, a + i1, a + i1, b + i0, b + i1]:
					idx.append(j)

	## Every slot collapsed onto her first sample, none of it laid yet.
	func start(at: Vector3, bow: Vector3, side: Vector3) -> void:
		for s in CAP:
			put(s, at, bow, side, 1e7, 0.0, 0.0, 0.0)

	## Writes slot s: the samples at the stern and the bow, `side` to starboard.
	func put(s: int, stern: Vector3, bow: Vector3, side: Vector3, born: float, hb: float, v: float, k: float) -> void:
		var a := s * PER
		var c := Color(clampf(v / 25.0, 0.0, 1.0), k, 0.0, 1.0)
		for i in PER:
			var at := stern if i < 3 else bow
			verts[a + i] = Vector3(at.x, 0.0, at.z)
			norms[a + i] = side
			cols[a + i] = c
		uvs[a] = Vector2(-1, born)
		uvs[a + 1] = Vector2(0, born)
		uvs[a + 2] = Vector2(1, born)
		uvs[a + 3] = Vector2(-1, born)
		uvs[a + 4] = Vector2(1, born)
		uvs[a + 5] = Vector2(-1, born)
		uvs[a + 6] = Vector2(1, born)
		for i in 3:
			uv2s[a + i] = Vector2(0, hb)
		uv2s[a + 3] = Vector2(-1, hb)
		uv2s[a + 4] = Vector2(-1, hb)
		uv2s[a + 5] = Vector2(1, hb)
		uv2s[a + 6] = Vector2(1, hb)

	func commit() -> void:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## A boat under way, each frame: `key` her entity, her stern and bow on the
## water, her half-beam, speed (m/s) and how hard she's going (0-1).
## `shown`: false while she's hidden from us (her wake hides with her).
func wake(key: int, stern: Vector3, bow: Vector3, half_beam: float, speed: float, k: float, shown: bool) -> void:
	var wk: Wake = _wakes.get(key)
	if wk == null:
		if speed < 0.8 or not shown:
			return
		wk = Wake.new()
		wk.mi = MeshInstance3D.new()
		wk.mi.mesh = wk.mesh
		wk.mi.material_override = wake_mat
		wk.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wk.mi.extra_cull_margin = 50.0  # (the arms spread far from where they were laid)
		add_child(wk.mi)
		_wakes[key] = wk
		wk.start(stern, bow, (bow - stern).cross(Vector3.UP).normalized())
	if not shown:
		# hidden from us: her wake goes with her, and starts afresh where she's
		# seen again (it mustn't give away where she went)
		wk.mi.visible = false
		wk.hidden = true
		return
	if wk.hidden:
		wk.hidden = false
		wk.mi.visible = true
		wk.last = Vector3.INF
		wk.start(stern, bow, (bow - stern).cross(Vector3.UP).normalized())
		wk.commit()
	if speed < 0.8:
		return  # (stopped: what's there fades)
	wk.seen = t
	var side := (bow - stern).cross(Vector3.UP).normalized()
	if side == Vector3.ZERO:
		return
	if wk.last == Vector3.INF or Defs.flat(stern - wk.last).length() > clampf(speed * 0.22, 1.2, 4.0):
		# lay this sample down; the next slot (the oldest) becomes the break
		wk.last = stern
		wk.put(wk.head, stern, bow, side, t, half_beam, speed, k)
		wk.head = (wk.head + 1) % Wake.CAP
	# the head slot follows her every frame, the break collapsed onto it
	wk.put(wk.head, stern, bow, side, t, half_beam, speed, k)
	var nb := (wk.head + 1) % Wake.CAP
	wk.put(nb, stern, bow, side, 1e7, half_beam, speed, k)
	wk.commit()


# --- foam and oil ------------------------------------------------------------------------

func _make_patches() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	pm.subdivide_width = 6
	pm.subdivide_depth = 6
	for i in PATCHES:
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = patch_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_patches.append([mi, 0.0])


## A patch of foam (RING, BOIL) or oil (OIL) on the water at p, `r` metres
## across at its widest, lasting `secs`.
func foam(p: Vector3, r: float, secs: float, kind: int) -> void:
	if _patches.is_empty():
		return
	var e: Array = _patches[_patch_i]
	_patch_i = (_patch_i + 1) % _patches.size()
	var mi: MeshInstance3D = e[0]
	mi.position = Vector3(p.x, WaterMap.LEVEL, p.z)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	Mats.set_inst(mi, &"fp", Vector4(t, secs, float(kind), randf() * 10.0))
	mi.visible = true
	e[1] = t + secs


# --- shaders -----------------------------------------------------------------------------

## The surface. ALBEDO is the light the water scatters back up (lit by the sun,
## so a ship's shadow falls on it) and foam; EMISSION is the bed seen through
## the water - the screen behind it, bent by the ripples and dimmed by how
## much water the eye looks through, red going first - and the sky reflected,
## more the flatter you look across it. The sun's glitter is in light().
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, ambient_light_disabled;

global uniform float water_time;
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D chop_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// a depth read back to clip space: OpenGL's (the browser build's) runs -1..1, Vulkan's 0..1
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sea_x = 1e9;
uniform vec3 coast = vec3(0.0);  // the shoreline's mean x, its seed, 1 if there's a sea
uniform vec3 zenith : source_color = vec3(0.22, 0.42, 0.74);
uniform vec3 horizon : source_color = vec3(0.68, 0.76, 0.84);
uniform float clouds = 0.55;
uniform float ambient = 0.55;
uniform float sun_k = 1.0;  // how sharp the sun is on the water (a blur under cloud)
uniform float rain = 0.0;
// (linear colours) what the water scatters back: peaty green-brown fresh
// water, blue-green sea, the breakers clouded with sand
uniform vec3 fresh_tint : source_color = vec3(0.2, 0.22, 0.12);
uniform vec3 sea_tint : source_color = vec3(0.025, 0.14, 0.21);
uniform vec3 shoal_tint : source_color = vec3(0.12, 0.46, 0.46);  // (the sea over sand: turquoise)
uniform vec3 surf_tint : source_color = vec3(0.34, 0.4, 0.3);
// how fast each colour dies away through a metre of water
uniform vec3 fresh_absorb = vec3(1.25, 1.05, 1.3);
uniform vec3 sea_absorb = vec3(0.6, 0.2, 0.15);
uniform vec3 foam_col : source_color = vec3(0.92, 0.94, 0.94);

varying vec3 wpos;
varying float swell_k;
varying float glint;

__WAVES__

vec4 wmask(vec2 p) {
	if (abs(p.x) >= __MAP_HALF__ || abs(p.y) >= __MAP_HALF__) {
		return p.x > sea_x ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(0.0);
	}
	return textureLod(water_mask, (p + __MAP_HALF__) / __MAP_SIZE__, 0.0);
}

// metres out to sea from the shoreline (WaterMap.coast_x); negative up the beach
float coast_into(vec2 p) {
	float s = coast.y;
	return p.x - (coast.x + 22.0 * sin(p.y * 0.0105 + s) + 9.0 * sin(p.y * 0.031 + s * 2.3) + 4.0 * sin(p.y * 0.077 + s * 0.7));
}

// how far the breakers have come: its fraction is 0 on a breaker's front,
// rising to 1 just ahead of the next (the fronts bend along the shore)
float surf_run(vec2 p, float into) {
	return (into + 1.8 * sin(p.y * 0.043 + coast.y * 3.0) + 0.7 * sin(p.y * 0.13 + coast.y) + water_time * SURF_C) / SURF_L;
}

float surf_phase(vec2 p, float into) {
	return fract(surf_run(p, into));
}

// the run-up behind a breaker: the water surges up the sand and drains away
float surge_at(vec2 p, float into) {
	float s = surf_phase(p, into);
	return smoothstep(0.0, 0.05, s) * exp(-s * 4.0) * smoothstep(-11.0, -2.0, into) * (1.0 - smoothstep(2.0, 9.0, into));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 m = wmask(wpos.xz);
	// the swell out at sea, dying away as the water shoals (still on rivers and ponds)
	swell_k = m.b * smoothstep(0.06, 0.55, m.r);
	float dy = swell_v(wpos.xz, water_time).x * swell_k;
	if (coast.z > 0.5 && m.b > 0.5) {
		dy += surge_at(wpos.xz, coast_into(wpos.xz)) * SURGE;
	}
	VERTEX.y += dy;
	wpos.y += dy;
}

float lace(vec2 p) {
	float a = texture(foam_tex, p / 3.3 + vec2(water_time * 0.011, water_time * 0.006)).r;
	float b = texture(foam_tex, p / 1.35 - vec2(water_time * 0.017, -water_time * 0.01)).r;
	return a * 0.62 + b * 0.38;
}

// the slope of the rings spreading from raindrops, one to a cell
vec2 drops(vec2 p, float seed) {
	vec2 cell = floor(p / 1.3);
	vec2 f = fract(p / 1.3) - 0.5;
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233)) + seed) * 43758.5453);
	float ph = fract(water_time * 1.1 + h);
	vec2 d = f - (vec2(fract(h * 7.1), fract(h * 13.7)) - 0.5) * 0.5;
	float r = length(d);
	float wave = sin((r - ph * 0.42) * 45.0) * smoothstep(0.08, 0.0, abs(r - ph * 0.42)) * (1.0 - ph);
	return d / max(r, 0.001) * wave * 0.5;
}

// `amt` of foam: solid white at 1, opening into a lace of bubbles as it thins
float foam_of(float amt, float l) {
	return smoothstep(1.0 - amt, 1.0 - amt + 0.22, l) * smoothstep(0.0, 0.08, amt);
}

void fragment() {
	vec2 p = wpos.xz;
	vec4 m = wmask(p);
	float sea = m.b;
	float into = coast.z > 0.5 ? coast_into(p) : 1e4;
	// (on the sea's beach the surf may run up over the sand)
	if (m.a < 0.5 && !(sea > 0.5 && into > -12.0)) {
		discard;
	}
	float dist = length(VERTEX);
	float far = smoothstep(80.0, 360.0, dist);
	// the surface: the swell, the shorter waves on it, the wind's chop on those -
	// rougher in the gusts that darken patches of the water
	vec3 sw = swell_v(p, water_time);
	vec2 g = (sw.yz + swell_f(p, water_time)) * swell_k;
	vec2 flow = mix(vec2(0.0, 0.55), vec2(-0.3, 0.1), sea);  // the rivers run south; the wind blows ashore
	float gust = texture(detail_tex, p / 260.0 + vec2(water_time * 0.0035, water_time * 0.001)).r;
	vec2 c1 = texture(chop_tex, p / 12.0 + flow * water_time * 0.045).xy * 2.0 - 1.0;
	vec2 c2 = texture(chop_tex, p / 4.7 + vec2(0.31, 0.17) - flow.yx * water_time * 0.08).xy * 2.0 - 1.0;
	// (the fine ripples fade out with distance, before they shimmer)
	float chop = mix(0.2, 0.34, sea) * mix(0.55, 1.45, smoothstep(0.3, 0.75, gust));
	vec2 gs = g;
	g += (c1 * 0.6 * (1.0 - far * 0.7) + c2 * 0.4 * (1.0 - smoothstep(25.0, 150.0, dist))) * chop;
	if (rain > 0.0) {
		// rain: every drop a ring spreading out and dying away
		g += (drops(p, 0.0) + drops(p * 1.37 + 0.5, 0.5)) * rain * (1.0 - smoothstep(20.0, 90.0, dist));
	}
	vec3 n = normalize(vec3(-g.x * 1.35, 1.0, -g.y * 1.35));
	vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// how much sky it reflects, by the broader slopes (by every ripple it sparkles)
	vec3 ns = normalize(vec3(-(gs.x + c1.x * chop * 0.4) * 1.5, 1.0, -(gs.y + c1.y * chop * 0.4) * 1.5));
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(ns, eye), 0.0, 1.0), 5.0);
	// what lies under the water, bent by the ripples (but never something in front of it)
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(zd), 1.0);
	vp.xyz /= vp.w;
	float thick = max(0.0, length(vp.xyz) - dist);
	vec2 roff = (VIEW_MATRIX * vec4(n.x, 0.0, n.z, 0.0)).xy * 1.1 * clamp(thick, 0.0, 2.0) / max(dist, 4.0);
	vec2 ruv = clamp(SCREEN_UV + roff, vec2(0.001), vec2(0.999));
	float zr = texture(depth_tex, ruv).r;
	vec4 rp = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, NDC_Z(zr), 1.0);
	rp.xyz /= rp.w;
	if (length(rp.xyz) < dist + 0.05) {
		ruv = SCREEN_UV;
		rp = vp;
	}
	float rthick = max(0.0, length(rp.xyz) - dist);
	vec3 bed = textureLod(screen_tex, ruv, 0.0).rgb;
	// (the open sea runs deeper than the few metres carved into the map:
	// darker the farther out)
	float depth = rthick + sea * clamp(into - 20.0, 0.0, 90.0) * 0.2;
	vec3 tr = exp(-mix(fresh_absorb, sea_absorb, sea) * depth);
	// the breakers: a white front with foam trailing behind it, sand stirred up
	float surf = 0.0;
	float zone = 0.0;
	if (coast.z > 0.5 && sea > 0.5) {
		float run = surf_run(p, into);
		float s = fract(run);
		zone = smoothstep(17.0, 9.0, into) * smoothstep(-10.0, -1.0, into);
		// each breaker spills unevenly along its length, here white, there hardly at all
		float wob = texture(detail_tex, vec2(p.y / 45.0, floor(run) * 0.31)).r;
		float strength = mix(0.6, 1.0, smoothstep(0.2, 0.8, wob));
		surf = (smoothstep(0.0, 0.03, s) * exp(-s * 4.5) * 0.62 + exp(-s * 2.6) * 0.14) * strength * zone;
		surf *= mix(0.65, 1.0, smoothstep(-4.0, 1.0, into));  // (thinning as it runs up the sand)
	}
	vec3 tint = mix(fresh_tint, mix(shoal_tint, sea_tint, smoothstep(1.0, 7.0, depth)), sea);
	tint = mix(tint, surf_tint, zone * 0.4);
	// foam: a line wherever the water meets something (the bank, a hull, a
	// pile), the breakers, whitecaps on the swell's crests in the gusts
	float l = lace(p);
	// (on the beach the surf's film is thin all over: only its very edge froths)
	float cw = mix(0.14, mix(0.05, 0.3, smoothstep(2.0, 8.0, into)), sea);
	float contact = (1.0 - smoothstep(0.0, cw, thick)) * mix(0.55, mix(0.5, 0.85, smoothstep(2.0, 8.0, into)), sea);
	// (whitecaps: flecks on the tops of the biggest waves, where the wind gusts)
	float fleck = smoothstep(0.5, 0.75, texture(foam_tex, p / 9.0 + vec2(water_time * 0.02, 0.0)).r);
	float caps = swell_k * smoothstep(0.22, 0.34, sw.x) * smoothstep(0.6, 0.85, gust) * fleck * 0.8;
	float amt = clamp(contact + surf + caps, 0.0, 1.0);
	// (seen from afar the lace blurs to grey: thresholding that would break the
	// foam into blocks, so it gives way to a soft wash of white)
	float blur = smoothstep(0.04, 0.2, length(fwidth(p)));
	float foam = mix(foam_of(amt, l), amt * amt * 0.7, blur);
	// the sky in it, and its clouds
	vec3 r = reflect(-eye, n);
	r.y = abs(r.y);
	vec3 sky = mix(horizon, zenith, pow(r.y, 0.5));
	vec2 cuv = r.xz / (r.y + 0.18) * 0.09 + vec2(water_time * 0.0015, water_time * 0.0007);
	float cl = smoothstep(1.0 - clouds - 0.15, 1.0 - clouds + 0.35, texture(detail_tex, cuv).r) * smoothstep(0.0, 0.2, r.y);
	sky = mix(sky, mix(horizon * 0.95, vec3(1.0), 0.55), cl * 0.8);
	vec3 scatter = tint * (1.0 - tr);
	vec3 amb = mix(horizon, zenith, 0.5) * ambient;
	ALBEDO = mix(scatter * (1.0 - fres), foam_col, foam);
	EMISSION = ((bed * tr + scatter * amb) * (1.0 - fres) + sky * fres) * (1.0 - foam) + foam_col * amb * foam * 0.6;
	// (soft where it laps the bank)
	ALPHA = clamp(smoothstep(0.0, 0.05, thick) + foam, 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.6, foam);
	NORMAL = normalize(mix((VIEW_MATRIX * vec4(n, 0.0)).xyz, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, foam * 0.7));
	glint = (1.0 - foam) * mix(0.3, 1.0, fres) * sun_k;
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	// the sun on the water: a hard glitter off every ripple facing it, a broad sheen round it
	float nh = clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0);
	float sp = pow(nh, 1600.0) * 9.0 + pow(nh, 220.0) * 0.25 + pow(nh, 30.0) * 0.025;
	SPECULAR_LIGHT += sp * glint * ATTENUATION * LIGHT_COLOR;
}
"""

## A boat's wake (see Wake): each vertex is a sample of where she was, with
## which way was starboard (NORMAL), its side of the strip (UV.x), when it was
## laid (UV.y), which strip (UV2.x: 0 the wash, -1 / 1 the arms) and her
## half-beam (UV2.y), her speed and how hard she was going (COLOR.rg).
const WAKE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

global uniform float water_time;
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform float sea_x = 1e9;
uniform vec3 zenith : source_color = vec3(0.22, 0.42, 0.74);
uniform vec3 horizon : source_color = vec3(0.68, 0.76, 0.84);
uniform float ambient = 0.55;
uniform vec3 foam_col : source_color = vec3(0.92, 0.94, 0.94);
uniform vec3 slick_col : source_color = vec3(0.55, 0.66, 0.68);

varying vec3 wp;
varying float age;
varying float kind;
varying float across;
varying float spd;

__WAVES__

vec4 wmask(vec2 p) {
	if (abs(p.x) >= __MAP_HALF__ || abs(p.y) >= __MAP_HALF__) {
		return p.x > sea_x ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(0.0);
	}
	return textureLod(water_mask, (p + __MAP_HALF__) / __MAP_SIZE__, 0.0);
}

void vertex() {
	age = water_time - UV.y;
	kind = UV2.x;
	across = UV.x;
	spd = COLOR.g;
	float hb = UV2.y;
	float v = COLOR.r * 25.0;
	float a = max(age, 0.0);
	float off;
	if (abs(kind) < 0.5) {
		// the wash spreads only slowly from the stern's width
		off = across * hb * (0.7 + 0.22 * sqrt(a));
	} else {
		// the bow wave runs out at the Kelvin angle (19.5 degrees) and broadens
		off = kind * (hb * 0.95 + a * v * 0.34) + across * (0.25 + 0.14 * a + hb * 0.1);
	}
	wp = VERTEX + NORMAL * off;
	vec4 m = wmask(wp.xz);
	wp.y = __LEVEL__ + swell_v(wp.xz, water_time).x * m.b * smoothstep(0.06, 0.55, m.r) + 0.02;
	// (drawn a touch toward the eye, so it stays on the water it lies on)
	vec3 w = wp + normalize(CAMERA_POSITION_WORLD - wp) * 0.2;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	if (age < -0.5 || age > 16.0 || wmask(wp.xz).a < 0.5) {
		discard;
	}
	float x = abs(across);
	float l = texture(foam_tex, wp.xz / 2.6 + vec2(0.0, water_time * 0.01)).r * 0.6 + texture(foam_tex, wp.xz / 1.05).r * 0.4;
	float amt;
	float sheen;
	if (abs(kind) < 0.5) {
		// the wash: white water churned up astern in streaks, breaking up as
		// it spreads, then a long faint streak of smoothed water
		float core = 1.0 - x * x;
		float streak = texture(foam_tex, vec2(across * 0.45 + UV2.y * 0.1, age * 0.05)).r;
		amt = spd * (0.85 * exp(-age / 1.1) + 0.4 * exp(-age / 4.0) * smoothstep(0.25, 0.65, streak)) * core;
		sheen = core * spd * 0.05 * (1.0 - smoothstep(2.0, 12.0, age));
	} else {
		// the bow wave's crest: white close aboard if she's going hard, smoothing out
		float ridge = 1.0 - x;
		amt = (0.2 + 0.6 * spd) * exp(-age / 2.2) * ridge * ridge;
		sheen = ridge * ridge * (0.07 + 0.1 * spd) * (1.0 - smoothstep(1.5, 8.0, age));
	}
	float blur = smoothstep(0.04, 0.2, length(fwidth(wp.xz)));
	float foam = mix(smoothstep(1.0 - amt, 1.0 - amt + 0.25, l) * smoothstep(0.0, 0.06, amt), clamp(amt * amt, 0.0, 1.0) * 0.7, blur);
	vec3 amb = mix(horizon, zenith, 0.5) * ambient;
	ALBEDO = mix(slick_col, foam_col, foam);
	EMISSION = mix(slick_col * amb * 0.3, foam_col * amb * 0.6, foam);
	ALPHA = clamp(max(foam, sheen), 0.0, 1.0);
	ROUGHNESS = mix(0.08, 0.7, foam);
}
"""

## Foam and oil on the water (see foam()): fp = (laid at, seconds, kind, seed).
const PATCH_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

global uniform float water_time;
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float sea_x = 1e9;
uniform vec3 foam_col : source_color = vec3(0.92, 0.94, 0.94);
instance uniform vec4 fp = vec4(0.0, 1.0, 0.0, 0.0);

varying vec3 wp;

__WAVES__

vec4 wmask(vec2 p) {
	if (abs(p.x) >= __MAP_HALF__ || abs(p.y) >= __MAP_HALF__) {
		return p.x > sea_x ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(0.0);
	}
	return textureLod(water_mask, (p + __MAP_HALF__) / __MAP_SIZE__, 0.0);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 m = wmask(wp.xz);
	wp.y = __LEVEL__ + swell_v(wp.xz, water_time).x * m.b * smoothstep(0.06, 0.55, m.r) + 0.02;
	vec3 w = wp + normalize(CAMERA_POSITION_WORLD - wp) * 0.2;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	if (wmask(wp.xz).a < 0.5) {
		discard;
	}
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float u = clamp((water_time - fp.x) / fp.y, 0.0, 1.0);
	float wob = texture(detail_tex, q * 0.3 + fp.w).r - 0.5;
	float l = texture(foam_tex, wp.xz / 2.4 + fp.w).r * 0.6 + texture(foam_tex, wp.xz / 0.95 + fp.w * 1.7).r * 0.4;
	if (fp.z < 1.5) {
		float amt;
		if (fp.z < 0.5) {
			// a ring running outward and breaking up; foam where the column fell back
			float rr = 0.25 + 0.68 * (1.0 - pow(1.0 - u, 2.2));
			float band = (1.0 - smoothstep(0.0, 0.1 + 0.22 * u, abs(r + wob * 0.45 - rr))) * mix(0.5, 1.0, l);
			float mid = (1.0 - smoothstep(0.0, 0.22 + 0.35 * u, r + wob * 0.3)) * (1.0 - u);
			amt = min(band * 0.95 + mid * 0.8, 0.85) * pow(1.0 - u, 1.3);
		} else {
			// boiling up white and spreading, breaking into islands as it goes
			float edge = 1.0 - smoothstep(0.35 + 0.3 * u, 0.95, r + wob * 0.5);
			amt = edge * (1.0 - u) * (1.0 - u * 0.5) * 0.78 * smoothstep(0.0, 0.04, u);
		}
		float blur = smoothstep(0.04, 0.2, length(fwidth(wp.xz)));
		float foam = mix(smoothstep(1.0 - amt, 1.0 - amt + 0.3, l) * smoothstep(0.0, 0.06, amt), amt * 0.6, blur) * smoothstep(1.0, 0.75, r);
		ALBEDO = foam_col;
		ALPHA = foam * 0.9;
		ROUGHNESS = 0.7;
	} else {
		// oil: a dark film spreading over the water, smoothing it, rainbowed where it's thin
		float rs = r / mix(0.3, 1.0, sqrt(u));
		float edge = 1.0 - smoothstep(0.45, 1.0, rs + wob * 0.6);
		float thin = texture(detail_tex, wp.xz / 16.0 + fp.w).r;
		vec3 film = mix(vec3(0.5), 0.5 + 0.5 * cos(6.2832 * (thin * 1.3 + rs * 0.4 + vec3(0.0, 0.33, 0.67))), 0.55);
		ALBEDO = vec3(0.018, 0.014, 0.01);
		EMISSION = film * 0.05 * smoothstep(0.3, 0.85, rs + wob * 0.4) + vec3(0.006, 0.005, 0.004);
		ALPHA = edge * 0.82 * (1.0 - u * u * u) * smoothstep(0.0, 0.02, u);
		ROUGHNESS = 0.05;
		SPECULAR = 0.6;
	}
}
"""
