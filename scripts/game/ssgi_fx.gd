class_name SsgiFx
extends CompositorEffect
## Bounce light (Settings > Graphics > Bounce light): sunlight that lands on a
## wall, a roof or a road doesn't stop there. Part of it scatters back out,
## coloured by what it hit, and lights whatever faces it: a sunlit brick wall
## warms the pavement in front of it, a white house brightens the shaded
## alley beside it, and the floor inside a breached room picks up the light
## pouring through the hole. The engine's sky light already fills shadows
## with the sky's blue; this adds the nearby world's own colours.
##
## It is worked out in screen space from what the frame has already drawn
## (in the spirit of Ritschel, Grosch and Seidel, "Approximating Dynamic
## Global Illumination in Image Space", I3D 2009, with rays marched through
## the depth buffer as in Mara, McGuire, Nowrouzezahrai and Luebke, "Deep
## G-Buffers for Stable Global Illumination Approximation", HPG 2016):
##
## - prep: at half resolution, each pixel's place in the world, its facing,
##   and the light it sends out. All of it bounces, the sky's share too: the
##   engine's sky light comes from the open sky, so the sky light a wall
##   throws onto the street is a bounce it never counted. So does what
##   burns or shines: a burning car, a street lamp, a shell's flash light the
##   walls and ground round them in their colour. Last frame's
##   bounce light is added too, so light goes one bounce further each frame.
## - gather: a few rays per pixel leave the surface in cosine-weighted
##   directions and are marched a few metres through the depth buffer. A ray
##   that runs into a surface facing it brings back that surface's light; one
##   that escapes brings back nothing (the sky's share is the engine's).
## - temporal: last frame's answer is found again by putting each pixel back
##   through last frame's camera, so it holds wherever the camera goes. It is
##   kept only where the same surface was there (its depth and facing agree),
##   and it is clipped to what this frame's rays say round the pixel
##   (Salvi's variance clipping, "An Excursion in Temporal Supersampling",
##   GDC 2016), so nothing moving or newly uncovered trails a ghost.
## - denoise: an edge-aware blur that stops at depth and facing changes, so
##   light doesn't bleed from a wall onto the ground in front of it.
## - composite: brought up to full resolution along the same edges (Kopf et
##   al., "Joint Bilateral Upsampling", SIGGRAPH 2007) and laid onto the
##   scene, tinted by each surface's own colour. Forward+ keeps no albedo
##   buffer, so the colour is estimated from the pixel against the sky light
##   it gets (exact in shade, where bounce light shows), or against the sky
##   and the sun together where the sky alone couldn't make it that bright.
##   Further off, where a wall is a few pixels tall, the rays reach further
##   and the light is laid on stronger, so it still shows from the command
##   height. Smoke and dust drawn in front of a hull or a wall hide its
##   bounce light as they hide it (see Snap).
##
## Only Forward+ can run it: the browser build's OpenGL renderer has no
## compositor, so there the setting does nothing. Atmosphere fills `params`
## on the main thread each frame; the render thread only reads them. It is
## looks only: nothing here reaches the simulation.

const CTX := &"frontline_ssgi"
const PARAMS := 40  # floats in the parameter block (ten vec4s, std140)
const CAM_FLOATS := 84  # five matrices and a vec4 (CAM_DECL)
const USAGE := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
const RGBA16F := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
## Rays per pixel and steps along each, by quality (Medium, High).
const RAYS := [4, 6]
const STEPS := [6, 8]
## How many frames of history a pixel blends at most: more is smoother, but a
## change in the light (a flare, a burning house) takes longer to show.
const HISTORY := 16.0

# --- set by Atmosphere on the main thread ------------------------------------
var params := PackedFloat32Array()  # ambient (rgb, albedo cap), radius, strength, debug view
var quality := 1  # 1 Medium, 2 High
var reset := false  # forget every view's history (to watch it build up again)
var snap: Snap  # goes into the compositor beside this, and on and off with it

# --- render thread only ---------------------------------------------------------
var rd: RenderingDevice
var _ready_rd := false
var _shaders := {}
var _pipes := {}
var _sampler: RID
var _nearest: RID
var _ubo: RID
var _cam_buf: RID
var _views := {}  # render buffers' instance id -> [last frame's view-projection, world-to-camera, frame]
var _sets := {}
var _set_key := []
var _said := false
var _snapped := false  # whether this frame's opaque picture was taken


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	# like the cinematic passes: with MSAA, the resolved image is what the
	# tonemapper reads next
	access_resolved_color = true
	access_resolved_depth = true
	needs_normal_roughness = true
	params.resize(PARAMS)
	snap = Snap.new()
	snap.of = weakref(self)
	RenderingServer.call_on_render_thread(_setup)


## The world as drawn just before smoke, dust, flames and water are laid over
## it. The bounce light belongs under them: laid on after them (the pass needs
## them drawn, a flame being a light it throws), it showed through a dust
## cloud in front of a sunlit tank. With MSAA, nothing written before they
## are drawn survives (the image is resolved again after them), so the pass
## runs after them, and this picture tells it where they are.
class Snap extends CompositorEffect:
	var of: WeakRef

	func _init() -> void:
		effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
		access_resolved_color = true

	func _render_callback(callback_type: int, render_data: RenderData) -> void:
		var fx: SsgiFx = of.get_ref() if of != null else null
		if fx != null and callback_type == EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT:
			fx._snap(render_data)


## Whether this renderer can run the passes at all (Forward+ with a device).
static func supported() -> bool:
	return RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == "forward_plus"


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd != null:
		for k in _shaders:
			if (_shaders[k] as RID).is_valid():
				rd.free_rid(_shaders[k])
		for r: RID in [_sampler, _nearest, _ubo, _cam_buf]:
			if r.is_valid():
				rd.free_rid(r)


func _setup() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	for k in PASSES:
		if not _compile(k, String(PASSES[k])):
			return
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = rd.sampler_create(ss)
	var sn := RDSamplerState.new()
	sn.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sn.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest = rd.sampler_create(sn)
	var zero := PackedByteArray()
	zero.resize(PARAMS * 4)
	_ubo = rd.uniform_buffer_create(PARAMS * 4, zero)
	var cb := PackedByteArray()
	cb.resize(CAM_FLOATS * 4)
	_cam_buf = rd.storage_buffer_create(cb.size(), cb)
	_ready_rd = true


func _compile(pass_name: String, body: String) -> bool:
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = HEADER + body
	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("Bounce light %s pass: %s" % [pass_name, spirv.compile_error_compute])
		return false
	var sh := rd.shader_create_from_spirv(spirv, "Bounce light " + pass_name)
	if not sh.is_valid():
		push_error("Bounce light %s pass: the driver refused the shader" % pass_name)
		return false
	_shaders[pass_name] = sh
	_pipes[pass_name] = rd.compute_pipeline_create(sh)
	return true


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not _ready_rd:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x < 16 or size.y < 16:
		return
	var p: PackedFloat32Array = params
	if p.size() != PARAMS:
		return
	var normal: RID = buffers.get_texture(&"forward_clustered", &"normal_roughness") if buffers.has_texture(&"forward_clustered", &"normal_roughness") else RID()
	if not normal.is_valid():
		return
	var hs := Vector2i((size.x + 1) >> 1, (size.y + 1) >> 1)
	var color: RID = buffers.get_color_layer(0)
	var depth: RID = buffers.get_depth_layer(0)
	var tex := _textures(buffers, hs, size)
	# this view's history: which of the two buffers holds last frame's
	var id := buffers.get_instance_id()
	if reset:
		reset = false
		_views.clear()
	if not _views.has(id) and _views.size() >= 8:
		_views.clear()  # (views come and go with resizes: forget the old ones)
	var view: Array = _views.get(id, [])
	var fresh := view.is_empty()
	var frame: int = 0 if fresh else int(view[2]) + 1
	var odd := frame & 1
	var key := [color, depth, normal, size, tex["gbuf_0"]]
	if key != _set_key:
		_build_sets(color, depth, normal, tex)
		_set_key = key
		fresh = true  # (new buffers hold no history)
	_cam_header(render_data, view, fresh, frame)
	_views[id] = view
	var q := clampi(quality, 1, 2) - 1
	p[0] = float(size.x)
	p[1] = float(size.y)
	p[2] = float(hs.x)
	p[3] = float(hs.y)
	p[10] = float(RAYS[q])
	p[11] = float(STEPS[q])
	p[12] = float(frame & 1023)
	p[13] = HISTORY
	p[31] = 1.0 if _snapped else 0.0
	_snapped = false
	rd.buffer_update(_ubo, 0, PARAMS * 4, p.to_byte_array())
	var hg := Vector2i((hs.x + 7) >> 3, (hs.y + 7) >> 3)
	var fg := Vector2i((size.x + 7) >> 3, (size.y + 7) >> 3)
	var cur := str(odd)
	rd.draw_command_begin_label("Bounce light", Color(0.9, 0.6, 0.3))
	_run("prep_" + cur, hg)
	_run("gather_" + cur, hg)
	_run("temporal_" + cur, hg)
	_run("denoise_" + cur, hg)
	_run("composite_" + cur, fg)
	rd.draw_command_end_label()
	if not _said and OS.has_environment("FL_DEBUG_SSGI"):
		_said = true
		print("SSGI passes running at %dx%d (half %dx%d), %d rays x %d steps" % [size.x, size.y, hs.x, hs.y, RAYS[q], STEPS[q]])


## This frame's camera and last frame's, for marching rays and finding each
## pixel again in last frame's history. (The projection comes as the renderer
## uses it: flipped to the image's rows, depth reversed and remapped to 0..1.)
func _cam_header(render_data: RenderData, view: Array, fresh: bool, frame: int) -> void:
	var sd := render_data.get_render_scene_data()
	var pr: Projection = sd.get_cam_projection()
	var xf: Transform3D = sd.get_cam_transform()
	var w2c := Projection(xf.affine_inverse())
	var vp: Projection = pr * w2c
	var h := PackedFloat32Array()
	h.resize(CAM_FLOATS)
	_put(h, 0, pr.inverse())
	_put(h, 16, pr)
	_put(h, 32, Projection(xf))
	_put(h, 48, vp if fresh else view[0] as Projection)
	_put(h, 64, w2c if fresh else view[1] as Projection)
	h[80] = 0.0 if fresh else 1.0
	rd.buffer_update(_cam_buf, 0, CAM_FLOATS * 4, h.to_byte_array())
	view.resize(3)
	view[0] = vp
	view[1] = w2c
	view[2] = frame


static func _put(h: PackedFloat32Array, at: int, m: Projection) -> void:
	for c in 4:
		var col: Vector4 = m[c]
		h[at + c * 4] = col.x
		h[at + c * 4 + 1] = col.y
		h[at + c * 4 + 2] = col.z
		h[at + c * 4 + 3] = col.w


func _run(pass_name: String, groups: Vector2i) -> void:
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipes[pass_name.get_slice("_", 0)])
	rd.compute_list_bind_uniform_set(cl, _sets[pass_name], 0)
	rd.compute_list_dispatch(cl, groups.x, groups.y, 1)
	rd.compute_list_end()


## The half-resolution images, kept with the view's render buffers (they go
## when the view is resized and come back at the new size). Two of the
## surface and history images, so last frame's can be read while this
## frame's is written.
const IMAGES := ["gbuf_0", "gbuf_1", "rad", "raw", "hist_0", "hist_1", "filt"]


func _textures(buffers: RenderSceneBuffersRD, hs: Vector2i, size: Vector2i) -> Dictionary:
	if buffers.has_texture(CTX, "opaque"):
		var f: RDTextureFormat = buffers.get_texture_format(CTX, "opaque")
		if int(f.width) != size.x or int(f.height) != size.y:
			buffers.clear_context(CTX)
	var out := {}
	for n: String in IMAGES:
		if not buffers.has_texture(CTX, n):
			buffers.create_texture(CTX, n, RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, hs, 1, 1, true, false)
		out[n] = buffers.get_texture(CTX, n)
	if not buffers.has_texture(CTX, "opaque"):
		buffers.create_texture(CTX, "opaque", RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
	out["opaque"] = buffers.get_texture(CTX, "opaque")
	return out


## (render thread, before the transparent things are drawn: see Snap)
func _snap(render_data: RenderData) -> void:
	if not _ready_rd or not enabled:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x < 16 or size.y < 16:
		return
	var tex := _textures(buffers, Vector2i((size.x + 1) >> 1, (size.y + 1) >> 1), size)
	var us := _uniforms("snap", [_smp(1, buffers.get_color_layer(0), true), _img(2, tex["opaque"])])
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipes["snap"])
	rd.compute_list_bind_uniform_set(cl, us, 0)
	rd.compute_list_dispatch(cl, (size.x + 7) >> 3, (size.y + 7) >> 3, 1)
	rd.compute_list_end()
	_snapped = true


func _build_sets(color: RID, depth: RID, normal: RID, t: Dictionary) -> void:
	_sets.clear()
	for odd in 2:
		var cur := str(odd)
		var prev := str(1 - odd)
		var gb: RID = t["gbuf_" + cur]
		var gb_prev: RID = t["gbuf_" + prev]
		var hist: RID = t["hist_" + cur]
		var hist_prev: RID = t["hist_" + prev]
		_sets["prep_" + cur] = _uniforms("prep", [_smp(1, color, true), _smp(2, depth, true), _smp(3, normal, true),
			_img(4, gb), _img(5, t["rad"]), _smp(6, t["filt"], false), _smp(7, t["opaque"], true), _smp(8, gb_prev, true)])
		_sets["gather_" + cur] = _uniforms("gather", [_smp(1, gb, true), _smp(2, t["rad"], true), _img(3, t["raw"])])
		_sets["temporal_" + cur] = _uniforms("temporal", [_smp(1, gb, true), _smp(2, t["raw"], true), _smp(3, gb_prev, true),
			_smp(4, hist_prev, false), _img(5, hist)])
		_sets["denoise_" + cur] = _uniforms("denoise", [_smp(1, gb, true), _smp(2, hist, true), _img(3, t["filt"])])
		_sets["composite_" + cur] = _uniforms("composite", [_img(1, color), _smp(2, depth, true), _smp(3, normal, true),
			_smp(4, gb, true), _smp(5, t["filt"], true), _smp(6, t["rad"], true), _smp(7, t["raw"], true), _smp(8, hist, true),
			_smp(9, t["opaque"], true)])


func _uniforms(shader: String, uniforms: Array[RDUniform]) -> RID:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = 0
	u.add_id(_ubo)
	var c := RDUniform.new()
	c.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	c.binding = 10
	c.add_id(_cam_buf)
	var all: Array[RDUniform] = [u, c]
	all.append_array(uniforms)
	return UniformSetCacheRD.get_cache(_shaders[shader], 0, all)


func _img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


func _smp(binding: int, tex: RID, nearest: bool) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_nearest if nearest else _sampler)
	u.add_id(tex)
	return u


# --- the passes ---------------------------------------------------------------

const HEADER := """#version 450
layout(set = 0, binding = 0, std140) uniform Params {
	vec4 size;  // full width, height; half width, height
	vec4 amb;   // the sky light a surface gets (rgb, scene units); the brightest a surface's colour can be
	vec4 gi;    // ray length (m), strength, rays, steps
	vec4 misc;  // frame, history (frames), debug view (FL_DEBUG_SSGI_VIEW), ray thickness (share of its length)
	vec4 far;   // distance (m) the far view starts and is full at; reach and strength there (multipliers)
	vec4 sun;   // towards the sun (world); how much more saturated the gathered light is laid on
	vec4 sun_col;  // the sun's light on a surface square to it (rgb, scene units)
	vec4 opt;   // share of last frame's bounce fed back; upsample search (0/1); saturation from afar; opaque picture taken (0/1)
	vec4 rim;   // towards the fill light (world)
	vec4 rim_col;  // the fill light on a surface square to it (rgb, scene units)
} P;
layout(set = 0, binding = 10, std430) restrict readonly buffer Cam {
	mat4 inv_proj;   // this frame's projection as drawn, inverted
	mat4 proj;       // and as drawn
	mat4 cam;        // camera to world
	mat4 prev_vp;    // last frame's projection x world to camera
	mat4 prev_view;  // last frame's world to camera
	vec4 info;       // last frame's history usable (0 or 1)
} C;

vec3 clean(vec3 c) {
	return (any(isnan(c)) || any(isinf(c))) ? vec3(0.0) : max(c, vec3(0.0));
}

// a point on screen (uv) at a depth from the depth buffer, in view space
vec3 view_at(vec2 uv, float d) {
	vec4 v = C.inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

// a surface's own colour, estimated from how it looks against the sky light
// on it: exact in shade; in the sun it would come out too bright, so it is
// capped (keeping its hue)
// the light a surface out of the sun gets: the sky's, and the cool fill
// light from the side away from the sun (Atmosphere's rim light), which
// lights shade as strongly as the sky does on what faces it. (Left out, a
// shaded face turned to it read twice as pale as it is.)
vec3 shade_light(vec3 wn) {
	return P.amb.rgb + P.rim_col.rgb * max(dot(wn, P.rim.xyz), 0.0);
}

vec3 albedo_of(vec3 c, vec3 wn) {
	vec3 a = c / max(shade_light(wn), vec3(1e-4));
	float m = max(a.r, max(a.g, a.b));
	return m > P.amb.a ? a * (P.amb.a / m) : a;
}

// the same, for a surface the bounce light lands on. Where ambient occlusion
// or a cast shadow has darkened a pixel, its colour against the sky light
// comes out far too dark, and the bounce light would be darkened a second
// time: there the colour is held to what a dull real surface reflects
// (a quarter of the light; asphalt and bark are darker, but little that
// stands in a street is), keeping the pixel's own hue
vec3 receiver_albedo(vec3 c, vec3 wn, float sunvis, float dull, out float sunny) {
	vec3 a = albedo_of(c, wn);
	vec3 shade = shade_light(wn);
	sunny = 0.0;
	// a pixel in the sun (nothing stands between it and the sun on screen,
	// see prep; or brighter than the shade's light alone could make it) is
	// lit by the sky and the sun together, and its colour is read against
	// both (or a dark, sunlit road or lawn would be taken for a white wall in
	// the shade, and the bounce light would lay a veil over everything in the
	// sun: brightness alone can't tell them apart).
	// How much sun it gets is read from its facing, but no less than level
	// ground of that facing gets: a grass blade's own facing often turns from
	// the sun, and against too little sun a sunlit lawn read as a yellow
	// near-white, which tinted the light laid on it orange
	vec3 raw = c / max(shade, vec3(1e-4));
	float lit = max(max(dot(wn, P.sun.xyz), 0.0), max(P.sun.y, 0.0) * clamp(wn.y, 0.0, 1.0));
	// How surely it is in the sun runs smoothly, not as a switch: across a
	// shadow's soft edge the brightness climbs, and the half-resolution sun
	// test is smeared, so either taken as yes-or-no turned the shadow map's
	// own fine steps into a sawtooth in the light laid on
	float in_sun = max(smoothstep(P.amb.a, P.amb.a * 1.6, max(raw.r, max(raw.g, raw.b))), smoothstep(0.6, 0.95, sunvis));
	if (in_sun > 0.0 && lit > 0.0) {
		vec3 b = c / max(shade + P.sun_col.rgb * lit, vec3(1e-4));
		float mb = max(b.r, max(b.g, b.b));
		a = mix(a, mb > P.amb.a ? b * (P.amb.a / mb) : b, in_sun);
		// and the share of its light that is the sun's
		vec3 lum = vec3(0.2126, 0.7152, 0.0722);
		float ls = dot(P.sun_col.rgb, lum) * lit;
		sunny = in_sun * ls / max(ls + dot(shade, lum), 1e-5);
	}
	float l = dot(a, vec3(0.2126, 0.7152, 0.0722));
	if (l >= dull) {
		return a;
	}
	vec3 hue = l > 1e-3 ? a / l : vec3(1.0);
	// (a near-black pixel has no hue to keep: it takes grey)
	hue = mix(vec3(1.0), hue, smoothstep(0.0, 0.01, l));
	return min(hue * dull, vec3(P.amb.a));
}

// how dull a surface may be taken for, at the darkest (see receiver_albedo).
// A wall or a room darkened by ambient occlusion is held to a quarter. Not
// level ground: a cast shadow there is lit by the shade's light alone, so its
// colour read against that is right, and held up to a quarter the dark grass
// under a squad's feet took twice its own share and lifted grey. Nor a man or
// a vehicle: dark gear is dark, and lifted as much as the ground round it
// read as light painted on, not reflected
float dull_floor(vec3 wn, bool mover) {
	return mover ? 0.0 : mix(0.25, 0.0, smoothstep(0.6, 0.85, wn.y));
}

// how much of the bounce light is laid on where all of a pixel's light is the sun's
#define SUNLIT 0.15
// how far the bounce light may raise a pixel above what it shows without it:
// anywhere (a doorway-lit room, a wall's foot), and on level ground in the open
#define LIFT_MAX 6.0
#define LEVEL_LIFT 0.15

// a little noise that differs from pixel to pixel and frame to frame, but is
// even across the screen (Jimenez, interleaved gradient noise, 2014)
float ign(vec2 p, float frame) {
	p += frame * 5.588238;
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}
"""

const PASSES := {
	# the world before the transparent things are drawn over it
	"snap": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D color_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D opaque_img;

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x < int(P.size.x) && p.y < int(P.size.y)) {
		imageStore(opaque_img, p, vec4(clean(texelFetch(color_tex, p, 0).rgb), 1.0));
	}
}
""",
	# each half-resolution pixel's surface (world facing, distance) and the
	# light it sends out
	"prep": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D color_tex;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(set = 0, binding = 3) uniform sampler2D normal_tex;
layout(rgba16f, set = 0, binding = 4) uniform restrict writeonly image2D gbuf_img;
layout(rgba16f, set = 0, binding = 5) uniform restrict writeonly image2D rad_img;
layout(set = 0, binding = 6) uniform sampler2D prev_filt_tex;
layout(set = 0, binding = 7) uniform sampler2D opaque_tex;
layout(set = 0, binding = 8) uniform sampler2D prev_gbuf_tex;

// Reprojection can land on a surface uncovered by a moving hull or camera.
// Validate each bilinear tap: checking only the nearest depth still lets a
// bright neighbour bleed across a silhouette and feed the next bounce.
vec3 previous_bounce(vec2 uv, float depth, vec3 normal) {
	vec2 pixel = uv * P.size.zw - 0.5;
	ivec2 base = ivec2(floor(pixel));
	vec2 f = fract(pixel);
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	for (int i = 0; i < 4; i++) {
		ivec2 offset = ivec2(i & 1, i >> 1);
		ivec2 tap = clamp(base + offset, ivec2(0), ivec2(P.size.zw) - 1);
		vec4 surface = texelFetch(prev_gbuf_tex, tap, 0);
		if (surface.w <= 0.0 || abs(surface.w - depth) >= depth * 0.04 + 0.05 || dot(surface.xyz, normal) <= 0.85) {
			continue;
		}
		vec2 weights = mix(1.0 - f, f, vec2(offset));
		float w = weights.x * weights.y;
		sum += clean(texelFetch(prev_filt_tex, tap, 0).rgb) * w;
		weight += w;
	}
	return weight > 1e-5 ? sum / weight : vec3(0.0);
}

void main() {
	ivec2 h = ivec2(gl_GlobalInvocationID.xy);
	if (h.x >= int(P.size.z) || h.y >= int(P.size.w)) {
		return;
	}
	ivec2 m = ivec2(P.size.xy) - 1;
	// the nearest of the four full pixels stands for them: an edge keeps its
	// foreground, so light can't leak round it
	ivec2 best = min(h * 2, m);
	float bd = texelFetch(depth_tex, best, 0).r;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		ivec2 f = min(h * 2 + ivec2(i & 1, i >> 1), m);
		float d = texelFetch(depth_tex, f, 0).r;
		if (d > bd) {  // (reversed depth: nearer is larger)
			bd = d;
			best = f;
		}
		// (the world before smoke, dust and flames, where it was taken: a
		// muzzle flash's or a flame's sprite isn't a surface, and read as one
		// it lit the gun barrel it hung in front of. Fires and flashes still
		// throw their light, through the lights they bring, off the walls and
		// ground those light)
		sum += clean(P.opt.w > 0.5 ? texelFetch(opaque_tex, f, 0).rgb : texelFetch(color_tex, f, 0).rgb);
	}
	if (bd <= 1e-7) {
		imageStore(gbuf_img, h, vec4(0.0, 0.0, 0.0, 0.0));  // the sky: nothing to light, nothing to bounce
		imageStore(rad_img, h, vec4(0.0));
		return;
	}
	vec3 v = view_at((vec2(best) + 0.5) / P.size.xy, bd);
	vec3 n = normalize(texelFetch(normal_tex, best, 0).xyz * 2.0 - 1.0);
	vec3 wn = normalize(mat3(C.cam) * n);
	if (any(isnan(wn))) {
		wn = vec3(0.0, 1.0, 0.0);
	}
	imageStore(gbuf_img, h, vec4(wn, -v.z));
	vec3 c = sum * 0.25;
	// whether the sun reaches it: steps towards the sun through the
	// depth buffer, as far as a house's shadow falls. (The engine's shadow
	// maps aren't open to this pass. Only what is on screen can cast here,
	// and a grass blade's own shadow is too fine to see at half resolution,
	// which is as wanted: the lawn reads as in the sun.)
	float sunvis = 0.0;
	vec3 lv = normalize(transpose(mat3(C.cam)) * P.sun.xyz);
	if (dot(n, lv) > 0.0 && P.sun.y > 0.0) {
		sunvis = 1.0;
		vec3 from = v + n * (0.05 - v.z * 0.002);
		float jit = ign(vec2(h) + vec2(31.0, 7.0), P.misc.x);
		// (steps close enough not to step over a wall's thickness near the
		// pixel, where the shadows that matter here are cast)
		for (int s = 1; s <= 16; s++) {
			float f = (float(s) - 0.5 + jit * 0.5) / 16.0;
			float dist = 10.0 * f * sqrt(f);
			vec3 q = from + lv * dist;
			if (q.z > -0.05) {
				break;
			}
			vec4 cq = C.proj * vec4(q, 1.0);
			vec2 quv = cq.xy / cq.w * 0.5 + 0.5;
			if (quv.x < 0.0 || quv.y < 0.0 || quv.x > 1.0 || quv.y > 1.0) {
				break;
			}
			float dq = texelFetch(depth_tex, clamp(ivec2(quv * P.size.xy), ivec2(0), m), 0).r;
			if (dq <= 1e-7) {
				continue;  // the sky
			}
			float behind = -q.z + view_at(quv, dq).z;
			// (deeper than a ray of bounce light may pass: under a table the
			// step is most of a metre behind the table top the camera sees)
			if (behind > 0.05 && behind < max(1.5, dist * 0.7)) {
				sunvis = 0.0;
				break;
			}
		}
	}
	// light bounces more than once: a wall lit by the sunlit street lights
	// the floor beside it in turn. Last frame's bounce light, found again
	// through last frame's camera, is added to what each surface sends out,
	// so every frame carries the light one bounce further (it converges in a
	// few frames, each bounce weaker by the surface's colour)
	if (C.info.x > 0.5) {
		vec4 world = C.cam * vec4(v, 1.0);
		vec4 was = C.prev_vp * world;
		vec2 puv = was.xy / max(was.w, 1e-6) * 0.5 + 0.5;
		if (was.w > 0.0 && puv.x >= 0.0 && puv.y >= 0.0 && puv.x <= 1.0 && puv.y <= 1.0) {
			float previous_depth = -(C.prev_view * world).z;
			vec3 again = previous_bounce(puv, previous_depth, wn);
			// (as bright as it is laid on, so a surface throws on the light it
			// shows, and a little under that: each round is weaker by the
			// surface's colour and this share, and gather holds what comes back
			// to the light of what the rays hit, so a closed room settles
			// instead of feeding its own light back without end)
			float sunny;
			vec3 ra = receiver_albedo(c, wn, sunvis, dull_floor(wn, texelFetch(normal_tex, best, 0).a > 0.5), sunny);
			c += ra * again * P.opt.x * mix(1.0, SUNLIT, sunny);
		}
	}
	// (fires and muzzle flashes are far brighter than any wall: kept in
	// bounds so a single hot pixel can't light the street)
	vec3 r = min(c, vec3(8.0));
	// (alpha: whether the sun reaches it, and 2 more for something that moves,
	// a man or a vehicle: the renderer marks them in the top bit of the
	// roughness. See gather and composite)
	float mover = texelFetch(normal_tex, best, 0).a > 0.5 ? 2.0 : 0.0;
	imageStore(rad_img, h, vec4(r, sunvis + mover));
}
""",
	# a few rays from each pixel through the depth buffer
	"gather": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D gbuf_tex;
layout(set = 0, binding = 2) uniform sampler2D rad_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D raw_img;

void main() {
	ivec2 h = ivec2(gl_GlobalInvocationID.xy);
	ivec2 hs = ivec2(P.size.zw);
	if (h.x >= hs.x || h.y >= hs.y) {
		return;
	}
	vec4 g = texelFetch(gbuf_tex, h, 0);
	// a man's or a vehicle's own rays run into himself first, and would bring
	// his own colour back onto him, a muddy cast that greys his camouflage:
	// what moves takes nothing from what moves
	bool mover = texelFetch(rad_tex, h, 0).a > 1.5;
	if (g.w <= 0.0) {
		imageStore(raw_img, h, vec4(0.0));
		return;
	}
	vec2 uv = (vec2(h) + 0.5) / P.size.zw;
	mat3 to_view = transpose(mat3(C.cam));
	vec3 n = normalize(to_view * g.xyz);
	// this pixel in view space, from its distance along its own ray
	vec3 dir_px = view_at(uv, 0.5);
	vec3 pos = dir_px * (g.w / max(-dir_px.z, 1e-6));
	// a frame round the facing, to turn the rays out of the surface
	vec3 t = normalize(abs(n.y) < 0.99 ? cross(n, vec3(0.0, 1.0, 0.0)) : cross(n, vec3(1.0, 0.0, 0.0)));
	vec3 b = cross(n, t);
	int rays = int(P.gi.z);
	int steps = int(P.gi.w);
	float jit = ign(vec2(h), P.misc.x);
	float spin = ign(vec2(h) + vec2(17.0, 59.0), P.misc.x) * 6.2831853;
	// seen from afar a pixel stands for more of the world, and the walls a
	// player sees from the usual command height are a few pixels tall: the
	// rays reach further there, so a street still gathers its walls' light
	float far_k = smoothstep(P.far.x, P.far.y, g.w);
	float len = P.gi.x * mix(1.0, P.far.z, far_k);
	// start a little off the surface, more far away (where a depth step is coarser)
	vec3 start = pos + n * (0.05 + g.w * 0.002);
	vec3 sum = vec3(0.0);
	float hit = 0.0;
	// rays that leave the screen (or pass behind the camera): what lies there,
	// the frame doesn't know. Most are rays that rose into the open sky (from
	// up close, nearly every one that climbs), so they count as misses, left
	// to the engine's sky light like any other, never darker than that. (They
	// are counted for the debug view: taking them as unknown instead, and
	// letting the rest stand for them, lit open ground three times over.)
	float lost = 0.0;
	for (int i = 0; i < rays; i++) {
		// cosine-weighted directions (Malley's method on a spun, stratified disc):
		// each ray stands for an equal share of the light the surface can see
		float u = (float(i) + jit) / float(rays);
		float a = spin + float(i) * 2.3999632;
		float r = sqrt(u);
		vec3 d = normalize(t * (r * cos(a)) + b * (r * sin(a)) + n * sqrt(max(1.0 - u, 0.0)));
		for (int s = 1; s <= steps; s++) {
			// steps closer together near the surface, where most light comes from
			float f = (float(s) - 0.5 + jit * 0.5) / float(steps);
			float dist = len * f * f;
			vec3 q = start + d * dist;
			if (q.z > -0.05) {
				lost += 1.0;  // behind the camera
				break;
			}
			vec4 c = C.proj * vec4(q, 1.0);
			vec2 quv = c.xy / c.w * 0.5 + 0.5;
			if (quv.x < 0.0 || quv.y < 0.0 || quv.x > 1.0 || quv.y > 1.0) {
				lost += 1.0;  // left the screen
				break;
			}
			ivec2 qp = clamp(ivec2(quv * P.size.zw), ivec2(0), hs - 1);
			vec4 sg = texelFetch(gbuf_tex, qp, 0);
			if (sg.w <= 0.0) {
				continue;  // the sky in front of it
			}
			float behind = -q.z - sg.w;
			// the ray has gone behind a surface, and not so far that it passed
			// behind it unseen: it hit that surface. (How deep counts grows with
			// how far the ray has gone, for steps that lengthen and walls seen
			// at a slant from afar. It would let a post or a man catch rays
			// that pass behind him, but that has been looked for and doesn't
			// show: what such a thin thing catches is little, and only its own
			// colour, the same as it throws anyway. Holding it to each step's
			// own depth instead lost a third of the light off real walls.)
			if (behind > 0.02 && behind < max(0.4, dist * P.misc.w)) {
				// a surface lights the ray's start only with its front
				vec4 hr = texelFetch(rad_tex, qp, 0);
				if (mover && hr.a > 1.5) {
					break;  // (as if it went on into the open sky)
				}
				vec3 sn = normalize(to_view * sg.xyz);
				float facing = clamp(-dot(sn, d) * 4.0, 0.0, 1.0);
				sum += hr.rgb * facing;
				hit += facing;
				break;
			}
		}
	}
	// laid on stronger than physical (the rays miss what is off screen, and
	// from afar a wall is a few pixels tall), but never brighter than what the
	// rays hit: a surface walled in by its source on every side gets that
	// source's own light, no more, so a yard can't outshine the wall lighting it
	float seen = float(rays) - lost;
	vec3 e = sum / float(rays) * P.gi.y * mix(1.0, P.far.w, far_k);
	vec3 src = sum / max(hit, 1e-4);
	float el = dot(e, vec3(0.2126, 0.7152, 0.0722));
	float sl = dot(src, vec3(0.2126, 0.7152, 0.0722));
	if (el > sl && el > 1e-6) {
		e *= sl / el;
	}
	// (alpha: how much of it the rays could see)
	imageStore(raw_img, h, vec4(clean(e), seen / float(rays)));
}
""",
	# last frame's answer, found again through last frame's camera
	"temporal": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D gbuf_tex;
layout(set = 0, binding = 2) uniform sampler2D raw_tex;
layout(set = 0, binding = 3) uniform sampler2D prev_gbuf_tex;
layout(set = 0, binding = 4) uniform sampler2D prev_hist_tex;
layout(rgba16f, set = 0, binding = 5) uniform restrict writeonly image2D hist_img;

void main() {
	ivec2 h = ivec2(gl_GlobalInvocationID.xy);
	ivec2 hs = ivec2(P.size.zw);
	if (h.x >= hs.x || h.y >= hs.y) {
		return;
	}
	vec4 g = texelFetch(gbuf_tex, h, 0);
	vec3 cur = texelFetch(raw_tex, h, 0).rgb;
	if (g.w <= 0.0) {
		imageStore(hist_img, h, vec4(0.0));
		return;
	}
	// what this frame's rays say round the pixel: their mean and spread
	vec3 m1 = vec3(0.0);
	vec3 m2 = vec3(0.0);
	float wn = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 o = clamp(h + ivec2(x, y), ivec2(0), hs - 1);
			vec4 og = texelFetch(gbuf_tex, o, 0);
			if (og.w <= 0.0 || abs(og.w - g.w) > g.w * 0.1) {
				continue;  // another surface
			}
			vec3 c = texelFetch(raw_tex, o, 0).rgb;
			m1 += c;
			m2 += c * c;
			wn += 1.0;
		}
	}
	m1 /= max(wn, 1.0);
	vec3 sigma = sqrt(max(m2 / max(wn, 1.0) - m1 * m1, vec3(0.0)));
	vec3 lo = m1 - sigma * 1.5;
	vec3 hi = m1 + sigma * 1.5;
	vec3 outc = cur;
	float n = 1.0;
	if (C.info.x > 0.5) {
		vec2 uv = (vec2(h) + 0.5) / P.size.zw;
		vec3 dir_px = view_at(uv, 0.5);
		vec3 pos = dir_px * (g.w / max(-dir_px.z, 1e-6));
		vec4 world = C.cam * vec4(pos, 1.0);
		vec4 was = C.prev_vp * world;
		vec2 puv = was.xy / max(was.w, 1e-6) * 0.5 + 0.5;
		float pz = -(C.prev_view * world).z;
		if (was.w > 0.0 && puv.x >= 0.0 && puv.y >= 0.0 && puv.x <= 1.0 && puv.y <= 1.0) {
			ivec2 pp = clamp(ivec2(puv * P.size.zw), ivec2(0), hs - 1);
			vec4 pg = texelFetch(prev_gbuf_tex, pp, 0);
			// the same surface was there: as far off, facing the same way
			if (pg.w > 0.0 && abs(pg.w - pz) < pz * 0.04 + 0.05 && dot(pg.xyz, g.xyz) > 0.85) {
				vec4 ph = textureLod(prev_hist_tex, puv, 0.0);
				n = min(ph.a + 1.0, P.misc.y);
				// (the clipping is also what lets a flash show: a gun or a shell
				// bursting lights the walls round it the frame it goes off, as
				// this frame's rays lift the window the memory is held to, and
				// it goes out as fast. Cutting the memory short where the rays
				// jumped was tried: it added nothing to that, only shimmer)
				outc = mix(clamp(ph.rgb, lo, hi), cur, 1.0 / n);
			}
		}
	}
	imageStore(hist_img, h, vec4(clean(outc), n));
}
""",
	# an edge-aware blur: it stops where the surface changes
	"denoise": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D gbuf_tex;
layout(set = 0, binding = 2) uniform sampler2D hist_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D filt_img;

void main() {
	ivec2 h = ivec2(gl_GlobalInvocationID.xy);
	ivec2 hs = ivec2(P.size.zw);
	if (h.x >= hs.x || h.y >= hs.y) {
		return;
	}
	vec4 g = texelFetch(gbuf_tex, h, 0);
	if (g.w <= 0.0) {
		imageStore(filt_img, h, vec4(0.0));
		return;
	}
	vec4 c0 = texelFetch(hist_tex, h, 0);
	// a pixel with little history yet is noisier: blur it wider
	float reach = c0.a < 4.0 ? 2.0 : 1.0;
	vec3 sum = c0.rgb;
	float wsum = 1.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			ivec2 o = clamp(h + ivec2(vec2(x, y) * reach), ivec2(0), hs - 1);
			vec4 og = texelFetch(gbuf_tex, o, 0);
			if (og.w <= 0.0) {
				continue;
			}
			float wz = exp(-abs(og.w - g.w) / (g.w * 0.02 + 0.02));
			float wnorm = pow(clamp(dot(og.xyz, g.xyz), 0.0, 1.0), 16.0);
			float ws = exp(-float(x * x + y * y) / 4.5);
			float w = wz * wnorm * ws;
			sum += texelFetch(hist_tex, o, 0).rgb * w;
			wsum += w;
		}
	}
	imageStore(filt_img, h, vec4(clean(sum / wsum), c0.a));
}
""",
	# up to full resolution along the edges, and onto the scene
	"composite": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 1) uniform restrict image2D color_img;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(set = 0, binding = 3) uniform sampler2D normal_tex;
layout(set = 0, binding = 4) uniform sampler2D gbuf_tex;
layout(set = 0, binding = 5) uniform sampler2D filt_tex;
layout(set = 0, binding = 6) uniform sampler2D rad_tex;
layout(set = 0, binding = 7) uniform sampler2D raw_tex;
layout(set = 0, binding = 8) uniform sampler2D hist_tex;
layout(set = 0, binding = 9) uniform sampler2D opaque_tex;

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= int(P.size.x) || p.y >= int(P.size.y)) {
		return;
	}
	float d = texelFetch(depth_tex, p, 0).r;
	vec4 col = imageLoad(color_img, p);
	int view_mode = int(P.misc.z + 0.5);
	if (d <= 1e-7) {
		if (view_mode > 0) {
			imageStore(color_img, p, vec4(0.0, 0.0, 0.0, col.a));
		}
		return;
	}
	vec2 uv = (vec2(p) + 0.5) / P.size.xy;
	float z = -view_at(uv, d).z;
	vec4 nr = texelFetch(normal_tex, p, 0);
	vec3 vn = normalize(nr.xyz * 2.0 - 1.0);
	vec3 wn = normalize(mat3(C.cam) * vn);
	// (the renderer keeps the roughness in alpha's low seven bits; the top
	// one marks things that move)
	float rough = nr.a > 0.5 ? 1.0 - nr.a : nr.a;
	rough = clamp(rough / (127.0 / 255.0), 0.0, 1.0);
	// the four half-resolution pixels round this one, weighed by distance on
	// screen and by how alike their surface is
	vec2 hp = uv * P.size.zw - 0.5;
	ivec2 base = ivec2(floor(hp));
	vec2 fr = hp - vec2(base);
	ivec2 hm = ivec2(P.size.zw) - 1;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	float best = 0.0;  // how alike the likest of them is
	float vis = 0.0;  // and whether the sun reaches them
	float vsum = 0.0;
	// (which of them the sun reaches is told at half resolution, and a shadow's
	// edge runs through the full one: weighed also by how near each one's
	// brightness is to this pixel's, the edge follows the shadow, not the
	// half-resolution pixels' steps)
	vec3 lumw = vec3(0.2126, 0.7152, 0.0722);
	float pl = dot(clean(P.opt.w > 0.5 ? texelFetch(opaque_tex, p, 0).rgb : col.rgb), lumw);
	for (int i = 0; i < 4; i++) {
		ivec2 o = ivec2(i & 1, i >> 1);
		ivec2 q = clamp(base + o, ivec2(0), hm);
		vec4 g = texelFetch(gbuf_tex, q, 0);
		if (g.w <= 0.0) {
			continue;
		}
		vec2 bw = mix(1.0 - fr, fr, vec2(o));
		float like = exp(-abs(g.w - z) / (z * 0.02 + 0.02)) * (pow(clamp(dot(g.xyz, wn), 0.0, 1.0), 8.0) + 1e-4);
		float w = (bw.x * bw.y + 1e-3) * like;
		best = max(best, like);
		sum += texelFetch(filt_tex, q, 0).rgb * w;
		vec4 rq = texelFetch(rad_tex, q, 0);
		float wb = w * exp(-4.0 * abs(log((dot(rq.rgb, lumw) + 1e-3) / (pl + 1e-3))));
		vis += (rq.a > 1.5 ? rq.a - 2.0 : rq.a) * wb;
		vsum += wb;
		wsum += w;
	}
	float sunvis = vsum > 1e-6 ? vis / vsum : 0.0;
	// where the half-resolution answer is mixed (only near a shadow's edge),
	// the same steps towards the sun again from this very pixel: the edge of
	// the light laid on then follows the shadow, not the half-resolution
	// pixels' steps (they showed as a sawtooth along a room's sunlit floor)
	if (sunvis > 0.02 && sunvis < 0.98) {
		vec3 v = view_at(uv, d);
		vec3 lv = normalize(transpose(mat3(C.cam)) * P.sun.xyz);
		float reach = 0.0;
		if (dot(vn, lv) > 0.0 && P.sun.y > 0.0) {
			reach = 1.0;
			vec3 from = v + vn * (0.05 - v.z * 0.002);
			ivec2 fm = ivec2(P.size.xy) - 1;
			for (int s = 1; s <= 16; s++) {
				float f = (float(s) - 0.5) / 16.0;
				float dist = 10.0 * f * sqrt(f);
				vec3 q = from + lv * dist;
				if (q.z > -0.05) {
					break;
				}
				vec4 cq = C.proj * vec4(q, 1.0);
				vec2 quv = cq.xy / cq.w * 0.5 + 0.5;
				if (quv.x < 0.0 || quv.y < 0.0 || quv.x > 1.0 || quv.y > 1.0) {
					break;
				}
				float dq = texelFetch(depth_tex, clamp(ivec2(quv * P.size.xy), ivec2(0), fm), 0).r;
				if (dq <= 1e-7) {
					continue;
				}
				float behind = -q.z + view_at(quv, dq).z;
				if (behind > 0.05 && behind < max(1.5, dist * 0.7)) {
					reach = 0.0;
					break;
				}
			}
		}
		sunvis = reach;
	}
	// none of the four is this surface: a pixel at the edge of something thin
	// (a man, a post, a barrel's rim) whose half-resolution pixels all went to
	// whatever stands in front. Weighed as they are, it would take that
	// thing's light, a halo round it; it takes its own surface's from a pixel
	// further out instead
	if (best < 0.2 && P.opt.y > 0.5) {
		vec3 s2 = vec3(0.0);
		float w2 = 0.0;
		float b2 = 0.0;
		for (int y = -1; y <= 2; y++) {
			for (int x = -1; x <= 2; x++) {
				ivec2 q = clamp(base + ivec2(x, y), ivec2(0), hm);
				vec4 g = texelFetch(gbuf_tex, q, 0);
				if (g.w <= 0.0) {
					continue;
				}
				float like = exp(-abs(g.w - z) / (z * 0.02 + 0.02)) * pow(clamp(dot(g.xyz, wn), 0.0, 1.0), 8.0);
				float w = like * like;
				b2 = max(b2, like);
				s2 += texelFetch(filt_tex, q, 0).rgb * w;
				w2 += w;
			}
		}
		if (b2 > best && w2 > 1e-5) {
			sum = s2;
			wsum = w2;
		}
	}
	vec3 e = wsum > 1e-5 ? sum / wsum : vec3(0.0);
	// what a wall throws carries its own colour, but mixed over many rays and
	// a surface's own tint, it greys: brought back a little, so the green of
	// a wall reads in the tiles beside it
	// (from afar a little less: a wall's colour laid over a whole yard read
	// as a tint painted on, when sunlit yards took it too; now that only the
	// shade does, a red brick wall reddening its foot still reads from the
	// command height, a little over gathered)
	float far_k = smoothstep(P.far.x, P.far.y, z);
	float el = dot(e, vec3(0.2126, 0.7152, 0.0722));
	// (brought back against the sun's own colour, not white: the sun's warmth
	// is in everything it lights, and made richer with the rest it turned the
	// light off a pale wall or lawn orange, which browned a soldier's camouflage)
	vec3 sunhue = P.sun_col.rgb / max(dot(P.sun_col.rgb, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
	sunhue = P.sun_col.r > 1e-4 ? sunhue : vec3(1.0);
	vec3 en = e / max(sunhue, vec3(0.05));
	float enl = dot(en, vec3(0.2126, 0.7152, 0.0722));
	e = max(vec3(enl) + (en - vec3(enl)) * mix(P.sun.w, P.opt.z, far_k), vec3(0.0)) * sunhue;
	// on a man or a vehicle the light off the ground round him is a fill, not
	// a recolouring: at most a sixth again the shade's own light on him (so
	// his shaded side keeps its depth against his sunlit one, as a cast
	// shadow does: see LEVEL_LIFT), and at half the colour, so camouflage
	// keeps its colours. (At half again, dark gear and the shade between the
	// men filled in, and the squad read washed out)
	if (nr.a > 0.5) {
		float ml = dot(e, vec3(0.2126, 0.7152, 0.0722));
		e = mix(vec3(ml), e, 0.5);
		float cap = LEVEL_LIFT * dot(shade_light(wn), vec3(0.2126, 0.7152, 0.0722));
		e *= ml > cap ? cap / ml : 1.0;
	}
	vec3 c = clean(col.rgb);
	// smoke, dust or a flame drawn over this pixel: the bounce light lands on
	// the world behind them, and shows only as much as they let through. How
	// much that is isn't kept, but how far they moved the pixel from the
	// world behind says it near enough: a thin haze leaves most, a thick
	// cloud over a dark hull next to none, and the fog of war's shade (a
	// multiply) exactly its own share. Level ground is left alone: roads,
	// paving and floors are drawn among the see-through things too (their
	// edges fade into the verges), so a road over grass would read as a
	// cloud, and a lift laid flat on the ground doesn't give away what is
	// behind the smoke the way a hull's or a wall's outline does
	float through = 1.0;
	if (P.opt.w > 0.5) {
		vec3 o = clean(texelFetch(opaque_tex, p, 0).rgb);
		float lc = dot(c, vec3(0.2126, 0.7152, 0.0722));
		float lo = dot(o, vec3(0.2126, 0.7152, 0.0722));
		// (the roads drawn among them are asphalt, darker than the ground
		// under them: level ground made brighter is under dust or smoke)
		float level = smoothstep(0.6, 0.85, wn.y) * (lc <= lo * 1.05 ? 1.0 : 0.0);
		through = mix(min(lc, lo) / max(max(lc, lo), 1e-5), 1.0, level);
	}
	float sunny;
	vec3 alb = receiver_albedo(c, wn, sunvis, dull_floor(wn, nr.a > 0.5), sunny);
	// (the gathered light already carries its strength: see gather.) In the
	// shade it is much of what lights a surface; in the sun, a few percent at
	// most. There the short rays overstate it: from a lawn they run into the
	// next sunlit blades of grass, whose faces turn every way, and a sunlit
	// lawn and a tank's deck came out a fifth brighter, tinted, while the
	// shade beside them is what should lift. So it is laid on only in part as
	// far as the pixel's light is the sun's
	e *= mix(1.0, SUNLIT, sunny);
	// A cast shadow on open level ground faces the sky, not the ground round
	// it, and takes little of the light off it: its rays run into the next
	// blades of grass, which overstates it, and the shadows under a squad
	// filled in, a washed-out grey. There it may raise the shadow by a sixth
	// at most, so the shadow keeps its depth against the sunlit ground
	// beside it (the shadow-to-sun ratio within about 15%). Walls, and what
	// stands in the shade of them, keep the full light
	vec3 add = alb * e * through;
	float level_k = smoothstep(0.6, 0.85, wn.y);
	float la = dot(add, vec3(0.2126, 0.7152, 0.0722));
	float lmax = dot(c, vec3(0.2126, 0.7152, 0.0722)) * mix(LIFT_MAX, LEVEL_LIFT, level_k);
	float k = la > lmax ? lmax / la : 1.0;
	add *= k;
	e *= k;
	vec3 outc = c + add;
	// and a surface gives some back as a sheen, more at a glancing look: a
	// wet road or a polished hull in shade picks up the colour of the walls
	// round it as well as the sky's. A rough sheen spreads wide, much as the
	// bounce light comes in, so the gathered light stands for what it
	// reflects; a mirror-smooth one shows a sharp picture of the world,
	// which is the screen-space reflections' work, so it fades out there
	// (Karis's fit of the split sum for a dielectric's 4%, "Physically Based
	// Shading on Mobile", 2014)
	float nv = clamp(dot(vn, -normalize(view_at(uv, d))), 0.0, 1.0);
	vec4 rr = rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
	float a004 = min(rr.x * rr.x, exp2(-9.28 * nv)) * rr.x + rr.y;
	vec2 ab = vec2(-1.04, 1.04) * a004 + rr.zw;
	vec3 sheen = e * (0.04 * ab.x + ab.y) * smoothstep(0.1, 0.3, rough) * through;
	outc += sheen;
	if (view_mode == 1) {
		outc = e;  // the bounce light alone
	} else if (view_mode == 2) {
		outc = alb;  // the colour estimated for each surface
	} else if (view_mode == 3) {
		outc = (add + sheen) * 4.0;  // what is added, four times over
	} else if (view_mode == 4) {
		outc = textureLod(rad_tex, uv, 0.0).rgb;  // the light each surface sends out
	} else if (view_mode == 5) {
		outc = texelFetch(gbuf_tex, ivec2(hp), 0).xyz * 0.5 + 0.5;  // facing (world)
	} else if (view_mode == 6) {
		outc = textureLod(raw_tex, uv, 0.0).rgb;  // this frame's rays alone
	} else if (view_mode == 7) {
		outc = vec3(textureLod(hist_tex, uv, 0.0).a / P.misc.y, texelFetch(gbuf_tex, ivec2(hp), 0).w / 200.0, 0.0);  // history length; distance
	} else if (view_mode == 8) {
		outc = sheen * 16.0;  // the sheen alone, sixteen times over
	} else if (view_mode == 9) {
		outc = vec3(1.0 - textureLod(raw_tex, uv, 0.0).a, rough, 0.0);  // share of rays lost off screen; roughness
	} else if (view_mode == 10) {
		outc = vec3(best < 0.2 ? 1.0 : 0.0, e.g * 4.0, 0.0);  // where the upsample looked further out; the light
	} else if (view_mode == 11) {
		outc = vec3(1.0 - through, e.g * 4.0, 0.0);  // where smoke or a flame hides it; the light
	} else if (view_mode == 14) {
		outc = vec3(nr.a > 0.5 ? 1.0 : 0.0, rough, 0.0);  // things that move (the renderer's flag); roughness
	} else if (view_mode == 13) {
		vec3 rw = c / max(shade_light(wn), vec3(1e-4));
		outc = vec3(sunny, max(rw.r, max(rw.g, rw.b)) * 0.1, sunvis);  // the sun's share of its light; brightness against the shade's light / 10; whether the sun reaches it
	} else if (view_mode == 12) {
		outc = texelFetch(opaque_tex, p, 0).rgb;  // the world before the see-through things
	}
	imageStore(color_img, p, vec4(clean(outc), col.a));
}
""",
}
