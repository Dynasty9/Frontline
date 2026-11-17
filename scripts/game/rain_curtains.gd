class_name RainCurtains
extends Node3D
## (view) Under rain, the showers further off: grey curtains hanging from the
## cloud base to the ground, streaked and drawn out in folds, some trailing
## off before they reach it, drifting over with the clouds. Close round the
## camera the rain is Atmosphere's falling streaks; the curtains stand only
## beyond NEAR, so from the command view the far valley and the mountains are
## seen through passing showers rather than one even murk.
##
## A few big quads (COUNT) turned to face the camera, scattered over a tile of
## TILE metres that drifts with the clouds and wraps round the camera, so there
## are always some in view and they come and go as the wind carries them. Each
## is faded by its distance (none close, none past FAR) and by how much it
## rains (blended as the weather turns). Works under both renderers. Looks only:
## positions come from a fixed hash and the clock, never world.rng.

const COUNT := 24
const TILE := 3600.0
## None closer than this (m), fading in over the next FADE_IN; gone by FAR.
const NEAR := 360.0
const FADE_IN := 300.0
const FAR := 2600.0
## How fast the showers drift over (m/s): with the clouds (CloudShadow.SPEED).
const SPEED := 6.5
## The cloud base above the ground (m), where the curtains hang from.
const BASE := 380.0

var world
var atmo
## How much it's raining (0..1).
var level := 0.0
var enabled := true  # (AirLayers' off/on flips)
var _mat: ShaderMaterial
var _q: Array[MeshInstance3D] = []
var _seed: Array[Vector4] = []  # per curtain: where in the tile (x, z: 0..1), how wide (0..1), how heavy (0..1)
var _t := 0.0


func setup(w, a) -> void:
	world = w
	atmo = a
	name = "RainCurtains"
	var n := FastNoiseLite.new()
	n.seed = 41
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("noise_tex", tex)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)  # (hung from its top, standing on its foot)
	for i in COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		Mats.set_inst(mi, &"seed", float(i) * 0.137)
		_q.append(mi)
		# (a fixed scatter: the plastic-number sequence spreads them evenly over
		# the tile, with no rows or clumps)
		_seed.append(Vector4(fposmod(0.5 + i * 0.7548777, 1.0), fposmod(0.5 + i * 0.5698403, 1.0), fposmod(i * 0.618034 + 0.1, 1.0), fposmod(i * 0.381966 + 0.4, 1.0)))


func tick(dt: float) -> void:
	_t += dt
	var on := enabled and level > 0.02 and world.cam != null and world.cam.cam != null
	if not on:
		for mi in _q:
			mi.visible = false
		return
	var cam: Camera3D = world.cam.cam
	var eye := cam.global_position
	var wind := Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	var drift := wind * SPEED * _t
	var right := cam.global_basis.x
	# (the rain slants with the wind: as seen from here, sideways by how much the
	# wind blows across the view)
	_mat.set_shader_parameter("slant", clampf(Vector2(right.x, right.z).dot(wind), -1.0, 1.0) * 0.12)
	var fog: Color = atmo._d.fog
	_mat.set_shader_parameter("col", fog.darkened(0.3))
	for i in COUNT:
		var s := _seed[i]
		var mi := _q[i]
		var p := Vector2(s.x, s.y) * TILE + drift
		# (wrapped to the tile round the camera)
		p.x = eye.x + wrapf(p.x - eye.x, -TILE * 0.5, TILE * 0.5)
		p.y = eye.z + wrapf(p.y - eye.z, -TILE * 0.5, TILE * 0.5)
		var d := Vector2(eye.x, eye.z).distance_to(p)
		var fade := smoothstep(NEAR, NEAR + FADE_IN, d) * (1.0 - smoothstep(FAR * 0.75, FAR, d))
		var k := level * fade * (0.55 + 0.45 * s.w)
		if k < 0.01:
			mi.visible = false
			continue
		var gy: float = world.ground_y(Vector3(p.x, 0.0, p.y))
		var width := 180.0 + 260.0 * s.z
		var foot := gy - 30.0
		var height := gy + BASE - foot
		var at := Vector3(p.x, foot, p.y)
		# turned to face the camera (about the upright only)
		var to_eye := Vector2(eye.x - p.x, eye.z - p.y).normalized()
		var basis := Basis(Vector3.UP, atan2(to_eye.x, to_eye.y)) * Basis.from_scale(Vector3(width, height, 1.0))
		mi.global_transform = Transform3D(basis, at)
		# (in steps: the browser's renderer makes a material for each value)
		Mats.set_inst(mi, &"k", snappedf(k, 0.04))
		Mats.set_inst(mi, &"dims", Vector2(width, height).snapped(Vector2(10.0, 10.0)))
		mi.visible = true


## A curtain: folds across it, thick along the cloud base and thinning toward
## the ground, a ragged foot (some showers trail off before they reach it), fine
## streaks falling through it, its edges soft so it's never a card.
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 col : source_color = vec3(0.55, 0.58, 0.62);
uniform float slant = 0.0;
instance uniform float k = 0.0;
instance uniform float seed = 0.0;
instance uniform vec2 dims = vec2(300.0, 400.0);

void fragment() {
	float x = UV.x * dims.x;
	float yn = 1.0 - UV.y;  // 0 at its foot, 1 at the cloud base
	float y = yn * dims.y;
	float xs = x + y * slant;
	// the folds: heavier and lighter columns across it, slowly changing
	float folds = texture(noise_tex, vec2(xs * 0.0025 + seed, TIME * 0.002 + seed * 0.3)).r;
	float body = smoothstep(0.3, 0.7, folds);
	// soft sides
	body *= smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	// a ragged foot: in places the rain stops short of the ground (virga)
	float foot = texture(noise_tex, vec2(xs * 0.006 + seed * 2.0, 0.37)).r;
	float stop = smoothstep(0.45, 0.85, foot) * 0.45;
	body *= smoothstep(stop, stop + 0.18, yn) * smoothstep(0.0, 0.1, yn);
	// thickest under the cloud base, merging up into it
	body *= mix(0.55, 1.0, smoothstep(0.1, 0.8, yn)) * smoothstep(1.0, 0.86, yn);
	// streaks: fine noise drawn out downward, falling
	float streak = texture(noise_tex, vec2(xs * 0.22 + seed * 5.0, y * 0.002 + TIME * 0.12)).r;
	streak = smoothstep(0.3, 0.8, streak);
	ALBEDO = col * (0.94 + 0.12 * streak);
	ALPHA = clamp(k * body * (0.7 + 0.45 * streak) * 0.85, 0.0, 0.72);
}
"""
