class_name SmokeShadow
extends Node
## (view) The shade smoke and dust throw. A smoke screen thick enough to hide a
## platoon takes most of the sunlight going through it as well, so a long grey
## shadow lies on the ground on its sunward side: across the grass, the men in
## it and the vehicles behind it, and through the sunlit haze, where the shafts
## stop at the smoke. A shell's dust cloud throws a brief one round its crater,
## a burning house a long dark band downwind, a column's dust a pale strip along
## the road.
##
## Everything that smokes is laid down as a soft blob of optical depth on a
## small map seen from the sun (MAP texels square, over the ground the camera
## is looking at): each blob is the smoke's own shape, a squashed ellipsoid,
## projected along the sun's rays onto a level plane, so under a low sun it
## stretches out into a long shadow away from the sun. The map is drawn on the
## graphics card as a 2D scene of additive sprites (a few hundred at most), so
## it costs next to nothing; every lit surface then looks up the sun's ray
## through its own position in it (CloudShadow.cloud_sun, which every surface
## and the air's fog already call for the clouds' shade). Alongside the depth,
## the map keeps how high the smoke hangs, so something standing above it (a
## hilltop, the air over the pall) stays in the sun.
##
## Looks only, like the smoke it follows: who can see whom is the host's
## business (Combat.smoke_blocks). Not in the browser (its renderer lights per
## vertex and has no HDR 2D): there the globals stay at nothing and the shaders
## skip it.

## Texels across the map.
const MAP := 256
## The ground the map covers (m), by how far the camera is pulled back: close
## in a texel is a metre, zoomed right out four.
const SPANS := [256.0, 512.0, 1024.0]
## The level plane the shadows are laid on is snapped to steps this high (m),
## so it doesn't creep as the camera moves over a slope.
const REF_STEP := 2.0
## Scales of the map's channels (G: the smoke's height above the plane, B: its
## depth), so they keep their precision in half floats.
const H_SCALE := 64.0
const S_SCALE := 16.0
## Most blobs drawn at once.
const MAX_PUFFS := 384

var world
var air  # AirLayers
var viewport: SubViewport
var _mm: MultiMesh
## The blobs as the multimesh takes them, all in one go: for each, its 2D
## transform (two rows of four) and its custom data (depth, height, spread, seed).
var buf := PackedFloat32Array()
var _n := 0
## How much of the shadow the shaders were last told to show (0..1).
var shown := 0.0
var _origin := Vector2.ZERO  # the map's corner (x, z)
var _span := 256.0
var _ref := 0.0
var _s := Vector2.ZERO  # the sun's ray: how far it goes sideways for each metre up
var _sin_elev := 1.0
var _strength := 1.0
var _wind := Vector2.ONE
var _wind_theta := 0.0
## The share of the shadow shown (1; AirLayers' FL_DEBUG_AIR_FLIP_SHADOW turns it off and on).
var enabled_k := 1.0
## FL_DEBUG_SMOKE_SHADOW_PART=map|sample: what that flip turns off and on, for
## timing each half: the map's drawing alone, or the surfaces reading it alone.
var _part := OS.get_environment("FL_DEBUG_SMOKE_SHADOW_PART")
## FL_DEBUG_SMOKE_SHADOW=PATH: save the map to PATH (an EXR) once a second.
var _dump := OS.get_environment("FL_DEBUG_SMOKE_SHADOW") if OS.has_environment("FL_DEBUG_SMOKE_SHADOW") else ""
var _dump_t := 0.0
## (the map's own GPU time, added up while the air's flip runs: AirLayers._flip)
var gpu_sum := 0.0
var gpu_n := 0
## (the noise each blob's edges are broken up with)
var _noise: NoiseTexture2D


func setup(w, a) -> void:
	world = w
	air = a
	name = "SmokeShadow"
	_wind = Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	_wind_theta = atan2(_wind.y, _wind.x)
	viewport = SubViewport.new()
	viewport.size = Vector2i(MAP, MAP)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_mm.mesh = q
	_mm.instance_count = MAX_PUFFS
	_mm.visible_instance_count = 0
	buf.resize(MAX_PUFFS * 12)
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _mm
	var fn := FastNoiseLite.new()
	fn.seed = 7
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.05
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	_noise.noise = fn
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SPLAT_SHADER
	m.shader = sh
	m.set_shader_parameter("noise", _noise)
	mmi.material = m
	viewport.add_child(mmi)
	RenderingServer.global_shader_parameter_set(&"smoke_shadow", viewport.get_texture())


## Wanted: the desktop's renderer only.
static func supported() -> bool:
	return not Vfx.gl


func tick(_dt: float) -> void:
	if world.cam == null or air.atmo == null or air.atmo.sun == null:
		return
	var to_sun: Vector3 = air.atmo.sun.global_transform.basis.z.normalized()
	# (a sun on the horizon throws no shadow worth the name, and below it none)
	_strength = smoothstep(0.03, 0.12, to_sun.y) * (enabled_k if _part == "" else 1.0)
	_sin_elev = maxf(to_sun.y, 0.1)
	_s = Vector2(to_sun.x, to_sun.z) / _sin_elev
	var d: float = world.cam.dist
	_span = SPANS[0] if d < 70.0 else (SPANS[1] if d < 180.0 else SPANS[2])
	var texel := _span / MAP
	var focus: Vector3 = world.cam.focus_pos
	_ref = snappedf(world.ground_y(focus), REF_STEP)
	# (the corner snapped to whole texels, so a blob lands on the same texels
	# as the camera pans and its shadow doesn't shimmer)
	_origin = Vector2(floorf(focus.x / texel - MAP * 0.5) * texel, floorf(focus.z / texel - MAP * 0.5) * texel)
	_n = 0
	if _strength > 0.0:
		_gather()
	# (nothing to draw: the map isn't redrawn, and the shaders skip it)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _n > 0 and (_part != "map" or enabled_k > 0.0) else SubViewport.UPDATE_DISABLED
	if _n > 0:
		_mm.buffer = buf
	_mm.visible_instance_count = _n
	shown = _strength if _n > 0 else 0.0
	if _part == "map":
		shown = 0.0
	elif _part == "sample":
		shown *= enabled_k
	RenderingServer.global_shader_parameter_set(&"smoke_shadow_map", Vector4(_origin.x, _origin.y, 1.0 / _span, shown))
	RenderingServer.global_shader_parameter_set(&"smoke_shadow_sun", Vector4(_s.x, _s.y, _ref, 0.0))
	if air._flip_frame >= 0 and _n > 0:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
		gpu_n += 1
	if _dump != "":
		_dump_t += _dt
		if _dump_t >= 1.0:
			_dump_t = 0.0
			var img := viewport.get_texture().get_image()
			if img:
				img.save_exr(_dump)
				var lo := 1e9
				var hi := 0.0
				var sum := 0.0
				for y in range(0, MAP, 4):
					for x in range(0, MAP, 4):
						var v := img.get_pixel(x, y).r
						lo = minf(lo, v)
						hi = maxf(hi, v)
						sum += v
				print("SMOKE SHADOW map: %d blobs, depth min %.4f mean %.4f max %.3f, corner %s" % [_n, lo, sum / float((MAP / 4) * (MAP / 4)), hi, img.get_pixel(0, 0)])


## A blob of smoke: centred at c, sa metres along `theta` (the angle of its
## long axis on the ground, from +x toward +z), sb across, sc up (standard
## deviations), tau the optical depth straight down through its middle.
## Projected along the sun's ray onto the plane: its outline is the ground
## shape widened by its height along the sun's direction, and its depth
## spread over that (the slanting ray goes through more of it, by 1/sin).
func puff(c: Vector3, sa: float, sb: float, sc: float, theta: float, tau: float, seed_v: float) -> void:
	if _n >= MAX_PUFFS or tau < 0.01:
		return
	var texel := _span / MAP
	var at := Vector2(c.x, c.z) - _s * (c.y - _ref)
	var reach := 3.0 * maxf(maxf(sa, sb), sc * _s.length())
	var lo := at - _origin
	if lo.x < -reach or lo.y < -reach or lo.x > _span + reach or lo.y > _span + reach:
		return
	var u := Vector2(cos(theta), sin(theta))
	var a2 := sa * sa
	var b2 := sb * sb
	var c2 := sc * sc
	# horizontal spread, plus the height thrown along the sun's direction
	var sxx := a2 * u.x * u.x + b2 * u.y * u.y + c2 * _s.x * _s.x
	var sxz := (a2 - b2) * u.x * u.y + c2 * _s.x * _s.y
	var szz := a2 * u.y * u.y + b2 * u.x * u.x + c2 * _s.y * _s.y
	var det := sxx * szz - sxz * sxz
	# (never finer than the map can draw: widened to most of a texel, its
	# depth thinned to keep the smoke's total)
	var m2 := 0.64 * texel * texel
	var wxx := sxx + m2
	var wzz := szz + m2
	var wdet := wxx * wzz - sxz * sxz
	var peak := tau * sa * sb / (_sin_elev * sqrt(maxf(det, 1e-6)))
	peak *= sqrt(maxf(det, 1e-6) / wdet)
	# in texels: the Cholesky factor of the spread, three deviations to the quad's edge
	var l11 := sqrt(wxx) / texel
	var l21 := sxz / (sqrt(wxx) * texel)
	var l22 := sqrt(maxf(wdet / wxx, 1e-6)) / texel
	# (rows of the 2D transform: x of each axis then the origin, y the same)
	var o := _n * 12
	buf[o] = l11 * 6.0
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = lo.x / texel
	buf[o + 4] = l21 * 6.0
	buf[o + 5] = l22 * 6.0
	buf[o + 6] = 0.0
	buf[o + 7] = lo.y / texel
	buf[o + 8] = minf(peak, 8.0)
	buf[o + 9] = (c.y - _ref) / H_SCALE
	buf[o + 10] = sc / S_SCALE
	buf[o + 11] = seed_v
	_n += 1


## Everything smoking or dusty near enough to matter, as blobs.
func _gather() -> void:
	var w3 := Vector3(_wind.x, 0.0, _wind.y)
	# smoke screens: a dense roll laid downwind of the canister, opening out
	# and thinning along its length (the shape smoke_screen.gdshader traces)
	for p in world.smoke_projectiles:
		if not is_instance_valid(p) or p.smoke_r <= 0.3:
			continue
		var r: float = p.smoke_r
		var seed_v := float(p.eid % 97) * 0.37
		var base: Vector3 = p.position + Vector3(0.0, 0.6, 0.0) + (Fires.WIND * 0.58 + Vector3.UP * 0.44) * r
		var k := clampf(r / 6.5, 0.0, 1.2)
		puff(base + w3 * (0.2 * r) - Vector3.UP * (0.12 * r), 0.6 * r, 0.42 * r, 0.18 * r, _wind_theta, 2.2 * k, seed_v)
		puff(base + w3 * (0.9 * r) - Vector3.UP * (0.02 * r), 0.7 * r, 0.55 * r, 0.24 * r, _wind_theta, 1.1 * k, seed_v + 3.1)
	var vfx = world.fx.vfx if world.fx else null
	if vfx:
		# a shell's cloud: thrown up at once, hanging a few seconds as it settles
		if vfx.blasts:
			for b in vfx.blasts.clouds():
				var age: float = b[2]
				var life: float = b[3]
				var sk: float = b[1]
				var env := smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(life * 0.35, life, age))
				var fuel: bool = b[5]
				var span := (21.0 if fuel else 18.0) * sk
				var hh := (7.0 if fuel else 2.7) * sk
				var grow := 0.6 + 0.4 * smoothstep(0.0, life * 0.5, age)
				puff(b[0] + Vector3.UP * hh * grow, span * 0.17 * grow, span * 0.17 * grow, hh * 0.55, 0.0, (1.6 if fuel else 1.1) * float(b[4]) * env, float(b[6]))
		# what's burning: the column of smoke rising off it, leaning downwind
		for f in vfx.fire_sources():
			var at: Vector3 = f[0]
			var heat: float = f[1]
			var big: float = minf(float(f[2]), 2.6)
			var tall := 4.0 + 3.0 * big
			puff(at + Vector3.UP * tall + w3 * tall * 0.7, 1.5 + 1.3 * big, 1.2 + 0.9 * big, 1.5 + 1.0 * big, _wind_theta, 0.35 + 0.5 * heat, at.x * 0.13 + at.z * 0.07)
		# a strike's pillar of black smoke
		for c in vfx.plume_columns():
			var at: Vector3 = c[0]
			var t: float = c[1]
			var amount: float = c[2]
			var big: float = c[3]
			var tall := minf(4.0 + t * 1.6, 22.0) * big
			puff(at + Vector3.UP * tall * 0.6 + w3 * tall * 0.4, (2.5 + t * 0.2) * big, (2.0 + t * 0.12) * big, tall * 0.3, _wind_theta, 0.9 * amount, at.x * 0.11 + at.z * 0.05)
	# the pall left hanging (volumetric fog's plumes) and dust down the roads
	if air.plumes and air.plumes.visible:
		air.plumes.shadow_casters(self)
	if air.trails and air.trails.visible:
		air.trails.shadow_casters(self)
	# (not the weather grid's coarse smoke: close up it's the same smoke as
	# the screens and plumes above, counted again, and spread over its 32 m
	# cells it only greyed the whole view a little)


## The splat: a blob's optical depth, its height and its spread, added up.
## The gaussian is let down to nothing at the quad's edge (three deviations
## out), and its depth broken up a little, as smoke is.
const SPLAT_SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D noise : repeat_enable, filter_linear;
varying vec4 puff;

void vertex() {
	puff = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 r = (UV - 0.5) * 6.0;
	float g = max(exp(-0.5 * dot(r, r)) - 0.0111, 0.0) / 0.9889;
	float n = texture(noise, r * 0.09 + vec2(puff.w, puff.w * 0.61)).r;
	float tau = puff.x * g * (0.45 + 1.1 * n);
	COLOR = vec4(tau, tau * puff.y, tau * puff.z, 1.0);
}
"""

## For a shader taking part (CloudShadow.PATTERN): smoke_sun(p), the share of
## the sunlight the smoke lets through to a point. The point's own sun ray,
## followed down to the map's plane, finds the smoke on it; only the part of
## that smoke hanging above the point shades it. The map fades out toward its
## edges, so its end is never a line on the ground.
const PATTERN := """
global uniform sampler2D smoke_shadow : filter_linear, repeat_disable;
global uniform vec4 smoke_shadow_map;  // the map's corner (x, z), 1 / its span, how much it shows
global uniform vec4 smoke_shadow_sun;  // the sun's ray sideways a metre up (x, z), the plane's height

float smoke_sun(vec3 p) {
	if (smoke_shadow_map.w <= 0.0) {
		return 1.0;
	}
	vec2 smoke_uv = (p.xz - smoke_shadow_sun.xy * (p.y - smoke_shadow_sun.z) - smoke_shadow_map.xy) * smoke_shadow_map.z;
	vec2 smoke_e = min(smoke_uv, 1.0 - smoke_uv);
	float smoke_edge = smoothstep(0.0, 0.12, min(smoke_e.x, smoke_e.y));
	if (smoke_edge <= 0.0) {
		return 1.0;
	}
	vec3 smoke_v = textureLod(smoke_shadow, smoke_uv, 0.0).rgb;
	if (smoke_v.r < 0.003) {
		return 1.0;
	}
	float smoke_y = smoke_shadow_sun.z + smoke_v.g / smoke_v.r * 64.0;
	float smoke_s = max(smoke_v.b / smoke_v.r * 16.0, 0.5);
	float smoke_above = 1.0 - smoothstep(smoke_y - 1.8 * smoke_s, smoke_y + 1.8 * smoke_s, p.y);
	return exp(-smoke_v.r * smoke_above * smoke_edge * smoke_shadow_map.w);
}"""
