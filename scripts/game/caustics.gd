class_name Caustics
extends MeshInstance3D
## (view) Sunlight thrown back off the water onto whatever stands just above
## it: a boat's hull, a jetty's piles, a bridge's piers, a wall at the water's
## edge, the bank. Each ripple on a sunlit surface is a little curved mirror,
## so the light it reflects comes together in a web of bright lines that
## wriggles as the ripples run: brightest on surfaces that face the water,
## fading out a couple of metres up. (The light focused down onto the bed
## under the water is the water's own shader's: WaterView.WATER_SHADER.)
##
## One mesh of boxes over every stretch of shore, from just under the water's
## surface to a little above it, drawn after the scene: each pixel inside one
## finds what's there from the depth buffer and, if it stands just above water
## that's close by, adds a share of its own colour back, in the web's pattern.
## The boxes tile without overlapping and each pixel only counts the box its
## point lies in, so nothing is lit twice. High Water quality and up only (the
## browser's Medium has the bed's caustics alone); looks only.

const TILE := 32.0  # the boxes' size (m)
const BELOW := 0.3  # how far under the surface they start (m)
const ABOVE := 2.8  # and how far above it they reach (m)

var _mat: ShaderMaterial
var _debug_k := float(OS.get_environment("FL_DEBUG_CAUSTICS")) if OS.has_environment("FL_DEBUG_CAUSTICS") else 1.0  # brighten them, to see where they fall


## Lays the boxes over every tile with water in it or beside it, from the
## water's mask (R depth, A water), and the textures the surface uses.
func build(water: WaterView) -> void:
	name = "Caustics"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = MapDims.shader(SHADER.replace("__LEVEL__", "%.3f" % WaterMap.LEVEL).replace("// CAUSTICS_GLSL", WaterView.CAUSTICS_GLSL))
		_mat.shader = sh
		material_override = _mat
	# (with mipmaps: a lower level is "water within a few metres")
	var mask := water.water.mask.duplicate() as Image
	mask.generate_mipmaps()
	_mat.set_shader_parameter("water_mask", ImageTexture.create_from_image(mask))
	_mat.set_shader_parameter("chop_tex", water.chop_tex)
	var small := water.water.mask.duplicate() as Image
	var n := int(MapDims.SIZE / TILE)
	small.resize(n, n, Image.INTERPOLATE_BILINEAR)
	var wet := PackedByteArray()
	wet.resize(n * n)
	for z in n:
		for x in n:
			if small.get_pixel(x, z).a > 0.0:
				wet[z * n + x] = 1
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var y0 := WaterMap.LEVEL - BELOW
	var y1 := WaterMap.LEVEL + ABOVE
	for z in n:
		for x in n:
			var near := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var zz := z + dz
					if xx >= 0 and zz >= 0 and xx < n and zz < n and wet[zz * n + xx] == 1:
						near = true
			if not near:
				continue
			var a := Vector2(-MapDims.HALF + x * TILE, -MapDims.HALF + z * TILE)
			_box(verts, uv, uv2, Vector3(a.x, y0, a.y), Vector3(a.x + TILE, y1, a.y + TILE))
	if verts.is_empty():
		mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m


## How bright the web is: the sun on the water (none under cloud or at night).
func set_strength(k: float) -> void:
	if _mat:
		_mat.set_shader_parameter("strength", k * _debug_k)
	visible = k > 0.01 and mesh != null and int(Settings.get_v("water")) >= 2


## The sun's colour and strength (WaterView, every frame: the mood can change).
func set_sun(c: Color) -> void:
	if _mat and visible:
		_mat.set_shader_parameter("sun_col", c)


## A box's twelve triangles, each corner carrying the box's own footprint
## (UV the near corner, UV2 the far one).
static func _box(verts: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, lo: Vector3, hi: Vector3) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	# (each face's corners, wound so it faces out; the shader draws the inside)
	for f in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		for i in [0, 1, 2, 0, 2, 3]:
			verts.append(c[f[i]])
			uv.append(Vector2(lo.x, lo.z))
			uv2.append(Vector2(hi.x, hi.z))


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

global uniform float water_time;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D water_mask : hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D chop_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float strength = 0.0;
uniform vec3 sun_col = vec3(1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif

varying vec4 box;

void vertex() {
	box = vec4(UV, UV2);
}

// CAUSTICS_GLSL

void fragment() {
	// (both faces of the box can cover a pixel: only the one facing away does)
	if (FRONT_FACING) {
		discard;
	}
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(zd), 1.0);
	vp.xyz /= vp.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
	if (wp.x < box.x || wp.z < box.y || wp.x >= box.z || wp.z >= box.w) {
		discard;
	}
	float above = wp.y - (__LEVEL__);
	if (above < 0.02 || above > 2.6 || length(vp.xyz) > 260.0) {
		discard;
	}
	vec2 uv = (wp.xz + __MAP_HALF__) / __MAP_SIZE__;
	// water within a few metres (the mask's lower levels), and not under this point
	float near = textureLod(water_mask, uv, 2.5).a;
	if (near < 0.01) {
		discard;
	}
	// which way the surface faces, from the depth: the light comes up off the
	// water, onto walls and hulls and the undersides of decks, hardly onto tops
	vec3 n = normalize(cross(dFdy(wp), dFdx(wp)));
	if (dot(n, CAMERA_POSITION_WORLD - wp) < 0.0) {
		n = -n;
	}
	float facing = clamp(0.8 - 0.65 * n.y, 0.0, 1.0);
	// the same net the bed shows (WaterView.CAUSTICS_GLSL), from the water just
	// in front of the surface, so the two move as one; the higher up, the
	// farther the light has fanned out off the curved ripples: broader and dimmer
	vec2 out_dir = normalize(n.xz + vec2(0.0001));
	float w = caustic_light(wp.xz + out_dir * (0.4 + above * 0.8), clamp(0.25 + above / 1.6, 0.0, 1.0), 0.0);
	float fade = smoothstep(0.02, 0.12, above) * (1.0 - smoothstep(0.2, 2.2, above)) * smoothstep(0.01, 0.15, near);
	// the surface's own colour, at a set brightness: the light off the water is
	// sunlight, as bright on a hull in its own shade as in the sun (brighter to
	// the eye there), so it mustn't scale with how lit the surface already is
	vec3 col = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 hue = col / max(dot(col, vec3(0.3, 0.59, 0.11)), 0.04);
	vec3 tint = sun_col / max(max(sun_col.r, sun_col.g), max(sun_col.b, 0.001));
	ALBEDO = min(hue, vec3(3.0)) * tint * 0.14 * w * fade * facing * strength;
}
"""
