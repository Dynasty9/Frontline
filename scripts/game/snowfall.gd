class_name Snowfall
extends Node3D
## Snow falling around the camera (Atmosphere's "snow" mood): soft flakes
## drifting down with the wind, slower and far more of them than the rain's
## streaks, each fluttering on a little spiral of its own as it falls.
##
## A flake takes twenty seconds to come down, so an emitter that simply
## followed the camera, as the rain's does, would leave the sky empty wherever
## the commander had just panned to. Instead the flakes fall in a box of air
## that the shader wraps round the view: each keeps its place in the world, and
## one that drifts out of one side of the box comes back in at the other, faded
## out and in again at the box's edges, so panning flies through falling snow
## rather than carrying it along. It's looks only: nothing on the battlefield
## sees or moves any differently for it.

## The wrapped box: half its width and depth, and its height (m).
const HALF := 42.0
const HEIGHT := 38.0
const FLAKES := 9000
## How fast a flake falls, and how hard the wind (Fires.WIND) carries it.
const FALL := Vector2(1.1, 1.9)
const DRIFT := 0.9

var _fall: GeometryInstance3D  # (GPU or CPU particles: see Vfx.part)


func _ready() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(HALF, HEIGHT * 0.5, HALF)
	var drift := Fires.WIND * DRIFT
	pm.direction = Vector3(drift.x, -1.5, drift.z).normalized()
	pm.spread = 12.0
	pm.initial_velocity_min = FALL.x
	pm.initial_velocity_max = FALL.y
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	var p := GPUParticles3D.new()
	p.amount = maxi(64, int(FLAKES * Settings.fx_mult()))
	if Vfx.gl:
		p.amount = int(p.amount * 0.25)  # (CPU particles in the browser)
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	p.draw_pass_1 = q
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	m.shader = sh
	m.set_shader_parameter("box", Vector3(HALF, HEIGHT, HALF))
	p.material_override = m
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the shader draws every flake inside the box round the view, wherever its
	# particle has got to: cull on the box, a little over)
	p.visibility_aabb = AABB(Vector3(-HALF - 30.0, -HEIGHT - 30.0, -HALF - 30.0), Vector3(HALF * 2.0 + 60.0, HEIGHT * 2.0 + 60.0, HALF * 2.0 + 60.0))
	_fall = Vfx.part(p)
	add_child(_fall)


## Keeps the emitter over the view (new flakes are born round it; the shader
## wraps the old ones in).
func follow(c: Camera3D) -> void:
	if c and _fall:
		_fall.global_position = _centre(c)


## The middle of the box of falling snow: ahead of the camera, between it and
## the ground it looks at, where the flakes are seen against the battlefield.
static func _centre(c: Camera3D) -> Vector3:
	return c.global_position - c.global_basis.z * HALF * 0.7


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 box = vec3(42.0, 38.0, 42.0);  // half width, height, half depth of the wrapped air
varying float fade;
varying float rnd;
void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	// (the same point Snowfall._centre puts the emitter on)
	vec3 centre = cam - INV_VIEW_MATRIX[2].xyz * box.x * 0.7;
	vec3 c = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	rnd = fract(sin(float(INSTANCE_ID) * 12.9898 + size * 78.233) * 43758.5453);
	// a flake flutters as it falls: a slow, lopsided spiral of its own
	float turn = c.y * (0.7 + rnd * 0.6) + rnd * 6.2832;
	c.x += sin(turn) * (0.25 + rnd * 0.3);
	c.z += cos(turn * 0.83) * (0.25 + rnd * 0.3);
	// wrap the flake into the box round the view
	vec3 rel = c - centre;
	rel.xz = mod(rel.xz + box.xz, box.xz * 2.0) - box.xz;
	rel.y = mod(rel.y + box.y * 0.5, box.y) - box.y * 0.5;
	c = centre + rel;
	// faded out at the box's sides, top and bottom (where it wraps), as it's
	// born and as it dies, and close to the lens
	vec3 edge = abs(rel) / vec3(box.x, box.y * 0.5, box.z);
	fade = (1.0 - smoothstep(0.7, 1.0, max(edge.x, edge.z))) * (1.0 - smoothstep(0.75, 1.0, edge.y));
	float age = INSTANCE_CUSTOM.y;
	fade *= smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.9, 1.0, age));
	float d = distance(cam, c);
	fade *= smoothstep(1.5, 5.0, d);
	// never thinner than a pixel and a half: a smaller flake would sparkle on
	// and off as it falls between pixels, so it grows and fades instead
	float pixel = 2.0 * d / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float drawn = max(size, 1.5 * pixel / 0.1);
	fade *= (size * size) / (drawn * drawn);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * drawn, INV_VIEW_MATRIX[1] * drawn, INV_VIEW_MATRIX[2] * drawn, vec4(c, 1.0));
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.25, 1.0, r);
	// (flakes catch the grey daylight: white, a touch cold)
	ALBEDO = vec3(1.0, 1.0, 1.02);
	ALPHA = a * fade * mix(0.7, 1.0, rnd);
}
"""
