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
##   throws onto the street is a bounce it never counted. Last frame's
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
##   it gets: exact in shade, where bounce light shows, and capped in the sun,
##   where it hardly does.
##
## Only Forward+ can run it: the browser build's OpenGL renderer has no
## compositor, so there the setting does nothing. Atmosphere fills `params`
## on the main thread each frame; the render thread only reads them. It is
## looks only: nothing here reaches the simulation.

const CTX := &"frontline_ssgi"
const PARAMS := 16  # floats in the parameter block (four vec4s, std140)
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


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	# like the cinematic passes: with MSAA, the resolved image is what the
	# tonemapper reads next
	access_resolved_color = true
	access_resolved_depth = true
	needs_normal_roughness = true
	params.resize(PARAMS)
	RenderingServer.call_on_render_thread(_setup)


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
	var tex := _textures(buffers, hs)
	# this view's history: which of the two buffers holds last frame's
	var id := buffers.get_instance_id()
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


func _textures(buffers: RenderSceneBuffersRD, hs: Vector2i) -> Dictionary:
	if buffers.has_texture(CTX, "rad"):
		var f: RDTextureFormat = buffers.get_texture_format(CTX, "rad")
		if int(f.width) != hs.x or int(f.height) != hs.y:
			buffers.clear_context(CTX)
	var out := {}
	for n: String in IMAGES:
		if not buffers.has_texture(CTX, n):
			buffers.create_texture(CTX, n, RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, hs, 1, 1, true, false)
		out[n] = buffers.get_texture(CTX, n)
	return out


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
			_img(4, gb), _img(5, t["rad"]), _smp(6, t["filt"], false)])
		_sets["gather_" + cur] = _uniforms("gather", [_smp(1, gb, true), _smp(2, t["rad"], true), _img(3, t["raw"])])
		_sets["temporal_" + cur] = _uniforms("temporal", [_smp(1, gb, true), _smp(2, t["raw"], true), _smp(3, gb_prev, true),
			_smp(4, hist_prev, false), _img(5, hist)])
		_sets["denoise_" + cur] = _uniforms("denoise", [_smp(1, gb, true), _smp(2, hist, true), _img(3, t["filt"])])
		_sets["composite_" + cur] = _uniforms("composite", [_img(1, color), _smp(2, depth, true), _smp(3, normal, true),
			_smp(4, gb, true), _smp(5, t["filt"], true), _smp(6, t["rad"], true), _smp(7, t["raw"], true), _smp(8, hist, true)])


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
vec3 albedo_of(vec3 c) {
	vec3 a = c / max(P.amb.rgb, vec3(1e-4));
	float m = max(a.r, max(a.g, a.b));
	return m > P.amb.a ? a * (P.amb.a / m) : a;
}

// the same, for a surface the bounce light lands on. Where ambient occlusion
// or a cast shadow has darkened a pixel, its colour against the sky light
// comes out far too dark, and the bounce light would be darkened a second
// time: there the colour is held to what a dull real surface reflects
// (a quarter of the light; asphalt and bark are darker, but little that
// stands in a street is), keeping the pixel's own hue
vec3 receiver_albedo(vec3 c) {
	vec3 a = albedo_of(c);
	float l = dot(a, vec3(0.2126, 0.7152, 0.0722));
	if (l >= 0.25) {
		return a;
	}
	vec3 hue = l > 1e-3 ? a / l : vec3(1.0);
	// (a near-black pixel has no hue to keep: it takes grey)
	hue = mix(vec3(1.0), hue, smoothstep(0.0, 0.05, l));
	return min(hue * 0.25, vec3(P.amb.a));
}

// a little noise that differs from pixel to pixel and frame to frame, but is
// even across the screen (Jimenez, interleaved gradient noise, 2014)
float ign(vec2 p, float frame) {
	p += frame * 5.588238;
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}
"""

const PASSES := {
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
		sum += clean(texelFetch(color_tex, f, 0).rgb);
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
			vec3 again = clean(textureLod(prev_filt_tex, puv, 0.0).rgb);
			// (at most physical strength, and a little under: a closed room
			// would otherwise feed its own light back without end)
			c += receiver_albedo(c) * again * min(P.gi.y, 1.0) * 0.8;
		}
	}
	// (fires and muzzle flashes are far brighter than any wall: kept in
	// bounds so a single hot pixel can't light the street)
	vec3 r = min(c, vec3(8.0));
	imageStore(rad_img, h, vec4(r, 1.0));
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
	float len = P.gi.x;
	// start a little off the surface, more far away (where a depth step is coarser)
	vec3 start = pos + n * (0.05 + g.w * 0.002);
	vec3 sum = vec3(0.0);
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
				break;  // behind the camera
			}
			vec4 c = C.proj * vec4(q, 1.0);
			vec2 quv = c.xy / c.w * 0.5 + 0.5;
			if (quv.x < 0.0 || quv.y < 0.0 || quv.x > 1.0 || quv.y > 1.0) {
				break;  // left the screen: what's there, the frame doesn't know
			}
			ivec2 qp = clamp(ivec2(quv * P.size.zw), ivec2(0), hs - 1);
			vec4 sg = texelFetch(gbuf_tex, qp, 0);
			if (sg.w <= 0.0) {
				continue;  // the sky in front of it
			}
			float behind = -q.z - sg.w;
			// the ray has gone behind a surface, and not so far that it passed
			// behind it unseen: it hit that surface
			if (behind > 0.02 && behind < max(0.4, dist * P.misc.w)) {
				// a surface lights the ray's start only with its front
				vec3 sn = normalize(to_view * sg.xyz);
				float facing = clamp(-dot(sn, d) * 4.0, 0.0, 1.0);
				sum += texelFetch(rad_tex, qp, 0).rgb * facing;
				break;
			}
		}
	}
	vec3 e = clean(sum / float(rays));
	imageStore(raw_img, h, vec4(e, 1.0));
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
	vec3 wn = normalize(mat3(C.cam) * normalize(texelFetch(normal_tex, p, 0).xyz * 2.0 - 1.0));
	// the four half-resolution pixels round this one, weighed by distance on
	// screen and by how alike their surface is
	vec2 hp = uv * P.size.zw - 0.5;
	ivec2 base = ivec2(floor(hp));
	vec2 fr = hp - vec2(base);
	ivec2 hm = ivec2(P.size.zw) - 1;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 4; i++) {
		ivec2 o = ivec2(i & 1, i >> 1);
		ivec2 q = clamp(base + o, ivec2(0), hm);
		vec4 g = texelFetch(gbuf_tex, q, 0);
		if (g.w <= 0.0) {
			continue;
		}
		vec2 bw = mix(1.0 - fr, fr, vec2(o));
		float w = bw.x * bw.y + 1e-3;
		w *= exp(-abs(g.w - z) / (z * 0.02 + 0.02));
		w *= pow(clamp(dot(g.xyz, wn), 0.0, 1.0), 8.0) + 1e-4;
		sum += texelFetch(filt_tex, q, 0).rgb * w;
		wsum += w;
	}
	vec3 e = wsum > 1e-5 ? sum / wsum : vec3(0.0);
	vec3 c = clean(col.rgb);
	vec3 alb = receiver_albedo(c);
	vec3 outc = c + alb * e * P.gi.y;
	if (view_mode == 1) {
		outc = e;  // the bounce light alone
	} else if (view_mode == 2) {
		outc = alb;  // the colour estimated for each surface
	} else if (view_mode == 3) {
		outc = alb * e * P.gi.y * 4.0;  // what is added, four times over
	} else if (view_mode == 4) {
		outc = textureLod(rad_tex, uv, 0.0).rgb;  // the light each surface sends out
	} else if (view_mode == 5) {
		outc = texelFetch(gbuf_tex, ivec2(hp), 0).xyz * 0.5 + 0.5;  // facing (world)
	} else if (view_mode == 6) {
		outc = textureLod(raw_tex, uv, 0.0).rgb * 4.0;  // this frame's rays alone, four times over
	} else if (view_mode == 7) {
		outc = vec3(textureLod(hist_tex, uv, 0.0).a / P.misc.y, texelFetch(gbuf_tex, ivec2(hp), 0).w / 200.0, 0.0);  // history length; distance
	}
	imageStore(color_img, p, vec4(clean(outc), col.a));
}
""",
}
