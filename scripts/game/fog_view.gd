class_name FogView
extends Node3D
## The fog of war as you see it: ground your side can't see right now is drawn
## darker and cooler, on the battlefield and on the minimap, so it's plain at a
## glance what's in sight and what isn't. (What is hidden is the host's
## business - Rules - and enemies out of sight are never sent; this only shows
## where the line runs.)
##
## Every eye your side has (Vision.eyes, the same circles the host uses) is
## drawn as a soft white disc into a small off-screen map of the battlefield
## (and a margin round it, so sight near the edge runs on past it), about 5 m
## to the pixel, fifteen times a second. A full-screen pass over the 3D
## view finds where each pixel lies on the ground (from the depth buffer) and
## darkens it if that ground is out of sight; aircraft high overhead are left
## alone. The minimap lays a dark copy of the same picture over its map.

const N := 256  # the sight map's pixels across
const MARGIN := 128.0  # how far past the map's edge it reaches (m)
const EVERY := 1.0 / 15.0
const EDGE := 1.1  # the soft edge runs from 0.9 to 1.1 of each eye's reach

var world: World
var sight_tex: Texture2D  # white where your side sees, black where it doesn't
var dark_tex: Texture2D  # the same, as darkness: black, alpha 1 out of sight (the minimap)
var active := false

var _vp: SubViewport
var _vp_dark: SubViewport
var _eyes: Node2D
var _disc: Texture2D
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _list := PackedVector3Array()
var _t := 0.0
var _own: Array = []  # your side's buildings (re-gathered every second, not every update)
var _own_t := 0.0


func _ready() -> void:
	# the sight map: black, with a white disc for every eye
	_vp = SubViewport.new()
	_vp.size = Vector2i(N, N)
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(N, N)
	_vp.add_child(bg)
	_eyes = Node2D.new()
	_eyes.draw.connect(_draw_eyes)
	_vp.add_child(_eyes)
	sight_tex = _vp.get_texture()
	# and turned into darkness for the minimap
	_vp_dark = SubViewport.new()
	_vp_dark.size = Vector2i(N, N)
	_vp_dark.disable_3d = true
	_vp_dark.transparent_bg = true
	_vp_dark.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp_dark)
	var tr := TextureRect.new()
	tr.texture = sight_tex
	tr.size = Vector2(N, N)
	var im := ShaderMaterial.new()
	var ish := Shader.new()
	ish.code = INVERT_SHADER
	im.shader = ish
	tr.material = im
	_vp_dark.add_child(tr)
	dark_tex = _vp_dark.get_texture()
	_disc = _make_disc()
	# the pass over the 3D view
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FOG_SHADER
	_mat.shader = sh
	_mat.render_priority = Material.RENDER_PRIORITY_MAX  # after the smoke, water and particles: it darkens them too
	_mat.set_shader_parameter("sight_tex", sight_tex)
	_mat.set_shader_parameter("origin", -MapDims.HALF - MARGIN)
	_mat.set_shader_parameter("span", span())
	_mi = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	_mi.mesh = qm
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 16384.0  # it covers the screen wherever the camera looks
	_mi.visible = false
	add_child(_mi)


## How much ground the sight map covers, across (m).
static func span() -> float:
	return MapDims.SIZE + MARGIN * 2.0


## The part of the sight map that is the battlefield itself (the minimap's).
func map_region() -> Rect2:
	var m := MARGIN / span() * N
	return Rect2(m, m, N - m * 2.0, N - m * 2.0)


## A soft white disc, transparent at the rim and beyond.
func _make_disc() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.9 / EDGE, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt


func _process(dt: float) -> void:
	var team := world.view_team
	var on := team >= 0 and team <= 1 and bool(Settings.get_v("lyr_vision"))
	if on != active:
		active = on
		_mi.visible = on
		_t = 0.0
		if on and world.atmo:
			# at night the whole field is dark already: out of sight is only a little darker
			_mat.set_shader_parameter("shade", Color(0.74, 0.76, 0.82) if world.atmo.mood == "night" else Color(0.6, 0.62, 0.68))
	if not on:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = EVERY
	_own_t -= EVERY
	if _own_t <= 0.0:
		_own_t = 1.0
		_own.clear()
		for st in world.structures:
			if st.team == team:
				_own.append(st)
	var marks: Array = (world.team_info[team] as Dictionary).get("marks", []) if team < world.team_info.size() else []
	_list = Vision.eyes(world, team, marks, _own)
	_eyes.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp_dark.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_eyes() -> void:
	var k := N / span()
	var o := MapDims.HALF + MARGIN
	for e in _list:
		var c := Vector2((e.x + o) * k, (e.y + o) * k)
		var rr := e.z * k * EDGE
		_eyes.draw_texture_rect(_disc, Rect2(c.x - rr, c.y - rr, rr * 2.0, rr * 2.0), false)


const INVERT_SHADER := """
shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - texture(TEXTURE, UV).r);
}
"""

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D sight_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec3 shade : source_color = vec3(0.6, 0.62, 0.68);
uniform float origin = -500.0;  // the sight map's corner (m)
uniform float span = 1000.0;  // and how much ground it covers

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);  // the whole screen, in front of everything
}

void fragment() {
	vec3 k = vec3(1.0);
	float d = texture(depth_tex, SCREEN_UV).r;
	if (d > 1e-7) {  // (0: the sky)
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		vp.xyz /= vp.w;
		vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
		vec2 uv = (wp.xz - origin) / span;
		float seen = 0.0;
		if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
			seen = texture(sight_tex, uv).r;
		}
		// out of sight is darker; anything high in the air (aircraft) is left alone
		float dark = (1.0 - smoothstep(0.1, 0.9, seen)) * (1.0 - smoothstep(16.0, 34.0, wp.y));
		k = mix(vec3(1.0), shade, dark);
	}
	ALBEDO = k;
}
"""
