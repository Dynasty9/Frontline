class_name Headlights
extends Node3D
## (view) After dark the vehicles driving about near the camera have their
## headlights on: a pair of cones down the road ahead, lighting the ground and
## showing in the night's low mist and haze (AirLayers), the way a car's beams
## do on a damp night. A few lights (SLOTS) are shared out among the nearest
## vehicles on the move (a pair each) a few times a second, so however big the column the
## cost stays the same. None by day, and none in the browser (its renderer
## compiles shaders again for every new light, a hitch mid-battle). Looks only.
##
## The fog's grid is far too coarse to hold a beam's edge, so each lamp also
## draws its beam itself (BEAM_SHADER): a cone mesh whose shader follows the
## view ray through the cone and adds up the light the air throws back along
## it, brightest by the lamp and falling away down the beam, with a defined
## edge and stopped where the ray meets the ground or a wall. And a glare spot
## on the lamp.

const SLOTS := 6
## Only vehicles this close to the camera (m) get a light.
const REACH := 240.0
## A vehicle keeps its lights on this long (s) after it last moved: a halt in a
## column doesn't switch the beams off and on.
const LINGER := 5.0
## The beam: how far it carries (m) and its half-angle (degrees).
const RANGE := 26.0
const HALF := 14.0
const COLOR := Color(1.0, 0.93, 0.82)  # (a halogen lamp's warm white, about 3200 K)

var world
## How dark it is (Atmosphere's LAMPLIGHT for the mood): the lights burn above 0.4.
var level := 0.0
var _lights: Array[SpotLight3D] = []
var _beams: Array[MeshInstance3D] = []  # each light's beam, then its glare
var _on: Array = []  # the vehicle each light is on, or null
var _pick_t := 0.0
var _t := 0.0
## (a peer isn't sent the vehicles' speeds, so whether each is on the move
## comes from where it was at the last look)
var _last := {}  # eid -> where it was at the last pick
var _moved := {}  # eid -> _t it last moved


func setup(w) -> void:
	world = w
	name = "Headlights"
	var beam_mesh := _beam_mesh()
	var beam_mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	beam_mat.shader = sh
	beam_mat.set_shader_parameter("range_m", RANGE)
	beam_mat.set_shader_parameter("tan_half", tan(deg_to_rad(HALF)))
	beam_mat.set_shader_parameter("col", COLOR)
	var glare_mat := ShaderMaterial.new()
	var gsh := Shader.new()
	gsh.code = GLARE_SHADER
	glare_mat.shader = gsh
	glare_mat.set_shader_parameter("col", COLOR)
	var glare_mesh := QuadMesh.new()
	glare_mesh.size = Vector2(1.6, 1.6)
	# (a pair a vehicle: two narrow cones, bright at the lamp and gone in 20-odd m)
	for i in SLOTS * 2:
		var l := SpotLight3D.new()
		l.light_color = COLOR
		l.spot_range = RANGE
		l.spot_angle = HALF
		l.spot_angle_attenuation = 0.9  # (a firm edge to the pool on the road)
		l.spot_attenuation = 1.2
		l.light_specular = 0.4
		l.shadow_enabled = false
		# (a little in the fog too, for the mist and dust round about)
		l.light_volumetric_fog_energy = 10.0
		l.visible = false
		add_child(l)
		_lights.append(l)
		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.add_child(beam)
		var glare := MeshInstance3D.new()
		glare.mesh = glare_mesh
		glare.material_override = glare_mat
		glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.add_child(glare)
		_beams.append(beam)
		_beams.append(glare)
	for i in SLOTS:
		_on.append(null)


func _process(dt: float) -> void:
	_t += dt
	var on := level > 0.4
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 0.25
		_pick(on)
	var dark := clampf((level - 0.4) / 0.4, 0.0, 1.0)
	var energy := 6.0 * dark
	for i in SLOTS:
		var v = _on[i]
		if v == null or not is_instance_valid(v):
			_on[i] = null
			_lights[i * 2].visible = false
			_lights[i * 2 + 1].visible = false
			continue
		var size: Vector3 = v.vdef.get("size", Vector3(2.3, 2.6, 6.0))
		var xf: Transform3D = (v as Node3D).global_transform
		for side in 2:
			var l := _lights[i * 2 + side]
			# (low on the front of the hull either side, dipped a little toward the road)
			var at: Transform3D = xf * Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(size.x * (0.32 if side == 0 else -0.32), size.y * 0.36, -size.z * 0.5 - 0.15))
			l.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
			l.light_energy = energy
			l.visible = true
			_beams[(i * 2 + side) * 2].set_instance_shader_parameter(&"k", dark)
			_beams[(i * 2 + side) * 2 + 1].set_instance_shader_parameter(&"k", dark)


## The nearest vehicles on the move get the lights.
func _pick(on: bool) -> void:
	var near: Array = []
	var cam := Vector3.INF
	if on and world.cam and world.cam.cam:
		cam = world.cam.cam.global_position
	var seen := {}
	for v in world.vehicles:
		if not is_instance_valid(v) or v.is_air() or v.is_boat():
			continue
		var p: Vector3 = v.position
		seen[v.eid] = true
		var was: Vector3 = _last.get(v.eid, p)
		_last[v.eid] = p
		if Defs.flat(p - was).length() > 0.3:  # (over a quarter of a second: over 1 m/s)
			_moved[v.eid] = _t
		if cam == Vector3.INF or v.health_frac() <= 0.0 or _t - float(_moved.get(v.eid, -99.0)) > LINGER:
			continue
		var d := cam.distance_to(p)
		if d < REACH:
			near.append([d, v])
	for eid in _last.keys():
		if not seen.has(eid):
			_last.erase(eid)
			_moved.erase(eid)
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in SLOTS:
		_on[i] = near[i][1] if i < near.size() else null


## The cone the beam is drawn on, in the light's own space: its point at the
## lamp, opening down -Z to RANGE (a little wider than the beam, so the edge
## falls inside it).
func _beam_mesh() -> ArrayMesh:
	var c := CylinderMesh.new()
	c.top_radius = RANGE * tan(deg_to_rad(HALF)) * 1.15
	c.bottom_radius = 0.12
	c.height = RANGE
	c.radial_segments = 16
	c.rings = 1
	var arrays := c.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var to_light := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.0, -RANGE * 0.5))
	for i in verts.size():
		verts[i] = to_light * verts[i]
	var out := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return out


## The beam in the air: drawn on the cone's far side (so it's drawn once even
## from inside it), the view ray is followed through the cone from where it
## enters to where it leaves or meets something solid, and the light thrown
## back along it added up: within the cone (a firm, slightly softened edge),
## bright by the lamp, falling away with distance down the beam.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float range_m = 26.0;
uniform float tan_half = 0.25;
uniform vec3 col : source_color = vec3(1.0, 0.93, 0.82);
instance uniform float k = 0.0;

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(wp - cam);
	float t_back = distance(wp, cam);
	// where the ray meets the scene
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	float t_scene = length(sv.xyz / sv.w);
	float t1 = min(t_back, t_scene);
	// into the light's own space
	mat3 rt = transpose(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz));
	vec3 o = rt * (cam - MODEL_MATRIX[3].xyz);
	vec3 rd = rt * dir;
	// start where the ray enters the sphere round the cone
	vec3 c = vec3(0.0, 0.0, -range_m * 0.5);
	float R = length(vec2(range_m * 0.5, range_m * tan_half * 1.15));
	float b = dot(o - c, rd);
	float h = b * b - (dot(o - c, o - c) - R * R);
	float t0 = max(0.0, -b - sqrt(max(h, 0.0)));
	float dt = max(t1 - t0, 0.0) / 24.0;
	float sum = 0.0;
	for (int i = 0; i < 24; i++) {
		vec3 p = o + rd * (t0 + (float(i) + 0.5) * dt);
		float along = -p.z;
		if (along > 0.0 && along < range_m) {
			float cr = along * tan_half + 0.06;
			float inside = 1.0 - smoothstep(cr * 0.72, cr, length(p.xy));
			float fall = 1.0 - along / range_m;
			sum += inside * fall * fall / (1.0 + along * 0.12) * dt;
		}
	}
	ALBEDO = col * sum * k * 0.075;
}
"""

## The lamp itself, a glare spot turned to the camera.
const GLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 col : source_color = vec3(1.0, 0.93, 0.82);
instance uniform float k = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = col * k * (exp(-r * r * 30.0) * 3.0 + exp(-r * r * 5.0) * 0.25);
}
"""
