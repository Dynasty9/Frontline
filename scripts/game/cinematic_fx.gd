class_name CinematicFx
extends CompositorEffect
## The camera's optics and the eye's adaptation, laid over the rendered scene
## while it is still HDR, just before it is tonemapped (Settings > Lighting &
## Look > Camera and lens). Each is a compute pass in the renderer, so only
## Forward+ runs them: the browser build's OpenGL renderer has no compositor.
##
## - Sun shafts: light scattered by the air streams past what stands against
##   the sun (Mitchell, "Volumetric Light Scattering as a Post-Process", GPU
##   Gems 3, 2007), masked by the sky in the depth buffer.
## - Lens: ghosts and a halo mirrored through the lens centre by reflections
##   between its elements (Hullin et al., "Physically-Based Real-Time Lens
##   Flare Rendering", SIGGRAPH 2011, as approximated in screen space by
##   Chapman 2013), anamorphic streaks (Kawase's streak filter, GDC 2003), and
##   dust and grease on the front glass lit by the glare round bright lights.
##   The bright pass uses Jimenez's Karis-weighted downsample (SIGGRAPH 2014,
##   "Next Generation Post Processing in Call of Duty: Advanced Warfare") so a
##   lone hot pixel can't flare the whole lens.
## - Local exposure: the scene's large-scale brightness ("base") is pulled
##   towards its average while the detail on top of it is kept, so a soldier
##   in a building's shadow and the fire beside him both read (Durand and
##   Dorsey, "Fast Bilateral Filtering for the Display of High-Dynamic-Range
##   Images", SIGGRAPH 2002). The base is blurred at a quarter of the
##   resolution and brought back up edge-aware (Kopf et al., "Joint Bilateral
##   Upsampling", SIGGRAPH 2007), so it doesn't halo round the edges.
## - Eye adaptation: the frame is metered (centre-weighted) every frame, and
##   exposure follows brightness the way an eye does: quickly towards a flash,
##   slowly back into the dark (Pattanaik et al., "Time-Dependent Visual
##   Adaptation for Fast Realistic Image Display", SIGGRAPH 2000). It works
##   against the scene's own long-term level, not an absolute one, so a night
##   battle stays night and midday stays bright: a flash dims the frame, then
##   it recovers. In the dark the eye's rods take over from its cones, and
##   colours drain towards blue (the Purkinje shift, after Thompson, Shirley
##   and Ferwerda, "A Spatial Post-Processing Algorithm for Images of Night
##   Scenes", 2002).
## - Film: halation (bright light scattering back from the film base into
##   the red layer) and contrast-adaptive sharpening (Lottes, AMD FidelityFX
##   CAS, 2019), run in a compressed space so highlights don't ring.
## - Heat haze: hot air is thinner than the air round it and bends light, and
##   it rises in turbulent cells, so what is seen through it swims. Each
##   source (HeatHaze gathers them) is a blob of hot air stretched along its
##   axis, a Gaussian whose line integral along each view ray has a closed
##   form, cut off where the ray meets the scene: so whatever stands in front
##   of a fire is never bent by it. The rising turbulence is noise carried
##   along the source's axis in the world, and the scene behind is pulled
##   sideways by it, more the nearer the hot air (in the spirit of the
##   screen-space refraction of Sousa, "Generic Refraction Simulation", GPU
##   Gems 2, 2005, with the distortion worked out per source, not drawn).
##
## - Motion blur: what moves while the shutter is open smears along its path
##   (McGuire, Hennessy, Bukowski and Osman, "A Reconstruction Filter for
##   Plausible Motion Blur", I3D 2012, with Jimenez's refinements from
##   SIGGRAPH 2014). Each pixel's movement comes from the engine's velocity
##   buffer; the share of it that is only the camera moving is worked out by
##   reprojecting the pixel's depth with last frame's camera, so a commander
##   panning across the map can keep the camera's blur low or off while a
##   rotor, a flung body or a passing jet still blurs. The longest movement in
##   each 32-pixel tile and its neighbours tells each pixel how far to look,
##   and the samples are weighed by depth and speed, so a blurred foreground
##   smears over the background and not the other way round.
##
## Atmosphere fills `params`, `heat` and the switches on the main thread every
## frame; the render thread only reads them. Everything here is looks: none of
## it reaches the simulation.

const CTX := &"frontline_cinematic"
const PARAMS := 32  # floats in the parameter block (eight vec4s, std140)
const USAGE := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
const RGBA16F := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
## The heat haze's sources: at most this many, each this many floats (three
## vec4s: centre and width; axis and stretch; strength, rise, cell, churn),
## after a header of the camera's two matrices and a vec4 (see HEAT_DECL).
const HEAT_MAX := 48
const HEAT_STRIDE := 12
const HEAT_HEAD := 36

# --- set by Atmosphere on the main thread ------------------------------------
var params := PackedFloat32Array()
var shafts := false
var lens := false
var local_exposure := false
var eye := false
var film := false
var reset_adaptation := true
var heat_haze := false
var heat := PackedFloat32Array()  # this frame's sources, HEAT_STRIDE floats each (HeatHaze.gather)
var heat_time := 0.0  # seconds the hot air has been rising (held still with Reduce motion)
var heat_bend := 0.22  # how far the hottest air bends what's behind it (m, at the hot air)
var motion_blur := false
var blur_shutter := 0.5  # the share of a frame the shutter is open (1/60 s at 30 fps: a 180 degree shutter)
var blur_camera := 0.0  # how much of the camera's own movement blurs (0 for none)

# --- render thread only ---------------------------------------------------------
var rd: RenderingDevice
var _ready_rd := false
var _shaders := {}  # pass name -> shader RID
var _pipes := {}  # pass name -> compute pipeline RID
var _sampler: RID
var _ubo: RID
var _adapt: RID  # adapted log2 luminance [quick, long-term], seconds since primed, this frame's
var _heat_buf: RID  # the camera and the heat sources (HEAT_DECL)
var _motion_buf: RID  # this frame's and last frame's camera, for the motion blur (MOTION_DECL)
var _prev_vp := Projection.IDENTITY  # last frame's projection x world-to-camera
var _prev_ok := false
var _motion_on := false  # what the motion buffer last told the composite
var _sets := {}  # pass name -> uniform set RID, for the textures below
var _set_key := []  # what those sets were built for
var _push_h := PackedByteArray()
var _push_v := PackedByteArray()
var _push_streak: Array[PackedByteArray] = []
var _push_gh := PackedByteArray()
var _push_gv := PackedByteArray()
var _said := false  # FL_DEBUG_CINE: said once that the passes run


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	# with MSAA the passes read and write the resolved image, which is what
	# the tonemapper reads next
	access_resolved_color = true
	access_resolved_depth = true
	params.resize(PARAMS)
	RenderingServer.call_on_render_thread(_setup)


## Whether this renderer can run the passes at all (Forward+ with a device).
static func supported() -> bool:
	return RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == "forward_plus"


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd != null:
		for k in _shaders:
			if (_shaders[k] as RID).is_valid():
				rd.free_rid(_shaders[k])  # (its pipeline and uniform sets go with it)
		for r: RID in [_sampler, _ubo, _adapt, _heat_buf, _motion_buf]:
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
	var zero := PackedByteArray()
	zero.resize(PARAMS * 4)
	_ubo = rd.uniform_buffer_create(PARAMS * 4, zero)
	var a := PackedByteArray()
	a.resize(16)
	_adapt = rd.storage_buffer_create(16, a)
	var hb := PackedByteArray()
	hb.resize((HEAT_HEAD + HEAT_MAX * HEAT_STRIDE) * 4)
	_heat_buf = rd.storage_buffer_create(hb.size(), hb)
	var mb := PackedByteArray()
	mb.resize(MOTION_FLOATS * 4)
	_motion_buf = rd.storage_buffer_create(mb.size(), mb)
	_push_h = PackedFloat32Array([1.0, 0.0, 1.0, 0.0]).to_byte_array()
	_push_v = PackedFloat32Array([0.0, 1.0, 0.0, 0.0]).to_byte_array()
	# the first streak pass takes only the hottest cores, so streaks stay lines
	for stride in [1.0, 4.0, 16.0]:
		_push_streak.append(PackedFloat32Array([stride, 1.0 if stride == 1.0 else 0.0, 0.0, 0.0]).to_byte_array())
	_push_gh = PackedFloat32Array([1.0, 0.0, 1.5, 0.0]).to_byte_array()
	_push_gv = PackedFloat32Array([0.0, 1.0, 1.5, 0.0]).to_byte_array()
	_ready_rd = true


func _compile(pass_name: String, body: String) -> bool:
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = HEADER + (HEAT_DECL if pass_name in ["heat", "composite"] else "") \
		+ (MOTION_DECL if pass_name in ["mvel", "composite"] else "") + body
	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("Cinematic %s pass: %s" % [pass_name, spirv.compile_error_compute])
		return false
	var sh := rd.shader_create_from_spirv(spirv, "Cinematic " + pass_name)
	if not sh.is_valid():
		push_error("Cinematic %s pass: the driver refused the shader" % pass_name)
		return false
	_shaders[pass_name] = sh
	_pipes[pass_name] = rd.compute_pipeline_create(sh)
	return true


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not _ready_rd:
		return
	var use_shafts := shafts
	var use_lens := lens
	var use_local := local_exposure
	var use_eye := eye
	var use_film := film
	var hs: PackedFloat32Array = heat
	# (no whole-number division on the render thread: see AGENTS.md, worker threads)
	var n_heat := mini(floori(hs.size() / float(HEAT_STRIDE)), HEAT_MAX) if heat_haze else 0
	var use_haze := n_heat > 0
	var use_blur := motion_blur
	if not (use_shafts or use_lens or use_local or use_eye or use_film or heat_haze or use_blur):
		_prev_ok = false
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
	var qs := Vector2i((size.x + 3) >> 2, (size.y + 3) >> 2)
	var sharpen: bool = use_film and p[22] > 0.0
	var color: RID = buffers.get_color_layer(0)
	var depth: RID = buffers.get_depth_layer(0)
	var velocity: RID = buffers.get_velocity_layer(0) if use_blur else RID()
	use_blur = use_blur and velocity.is_valid()
	# the sharpening and the haze read the scene's neighbours: from a copy of it
	# (or from the blurred scene, which the motion blur writes there instead)
	var need_src := sharpen or use_haze or use_blur
	var tex := _textures(buffers, size, qs, need_src, use_blur)
	var key := [color, depth, velocity, size, need_src, use_blur, tex["bright"]]
	if key != _set_key:
		_build_sets(color, depth, velocity, tex, need_src, use_blur)
		_set_key = key
	_motion_header(render_data, use_blur)
	if use_haze:
		_heat_header(render_data, size, hs, n_heat)
	p[0] = float(size.x)
	p[1] = float(size.y)
	p[2] = float(qs.x)
	p[3] = float(qs.y)
	p[28] = 1.0 if use_shafts else 0.0
	p[29] = 1.0 if use_lens else 0.0
	p[30] = 1.0 if use_local else 0.0
	p[31] = 1.0 if use_eye else 0.0
	if not use_film:
		p[20] = 0.0
		p[22] = 0.0
	if not use_eye:
		p[21] = 0.0
	p[27] = 1.0 if use_haze else 0.0
	rd.buffer_update(_ubo, 0, PARAMS * 4, p.to_byte_array())
	if reset_adaptation:
		reset_adaptation = false
		rd.buffer_clear(_adapt, 0, 16)
	var qg := Vector2i((qs.x + 7) >> 3, (qs.y + 7) >> 3)
	var fg := Vector2i((size.x + 7) >> 3, (size.y + 7) >> 3)
	rd.draw_command_begin_label("Cinematic lighting", Color(1.0, 0.8, 0.4))
	# (the haze and the sharpening alone need no bright pass)
	if use_shafts or use_lens or use_local or use_eye or use_film:
		_run("prep", qg)
	if use_local:
		_run("blur_h", qg, _push_h)
		_run("blur_v", qg, _push_v)
	if use_local or use_eye:
		_run("reduce", Vector2i.ONE)
	if use_shafts:
		_run("shafts", qg)
	if use_lens:
		_run("streak_0", qg, _push_streak[0])
		_run("streak_1", qg, _push_streak[1])
		_run("streak_2", qg, _push_streak[2])
		_run("gauss_h", qg, _push_gh)
		_run("gauss_v", qg, _push_gv)
		_run("flare", qg)
	if use_haze:
		_run("heat", qg)
	if use_blur:
		var tg := Vector2i((size.x + TILE - 1) >> 5, (size.y + TILE - 1) >> 5)  # (TILE is 32: shifts, not division, on the render thread)
		_run("mvel", fg)
		_run("mtile", Vector2i((tg.x + 7) >> 3, (tg.y + 7) >> 3))
		_run("mneigh", Vector2i((tg.x + 7) >> 3, (tg.y + 7) >> 3))
		_run("mblur", fg)
	elif need_src:
		_run("copy", fg)
	_run("composite", fg)
	rd.draw_command_end_label()
	if not _said and OS.has_environment("FL_DEBUG_CINE") and (use_haze or not heat_haze):
		_said = true
		print("CINEMATIC passes running at %dx%d: shafts %s, lens %s, local %s, eye %s, film %s, heat haze %s (%d sources), motion blur %s" % [size.x, size.y,
			use_shafts, use_lens, use_local, use_eye, use_film, use_haze, n_heat, use_blur])


## The camera as this frame draws it, and the heat sources, for the heat pass.
## (The projection comes as the renderer uses it: flipped to the image's rows,
## its depth reversed and remapped to 0..1, so a pixel's depth goes straight in.)
func _heat_header(render_data: RenderData, size: Vector2i, hs: PackedFloat32Array, n: int) -> void:
	var sd := render_data.get_render_scene_data()
	var pr: Projection = sd.get_cam_projection()
	var xf: Transform3D = sd.get_cam_transform()
	var inv := pr.inverse()
	var h := PackedFloat32Array()
	h.resize(HEAT_HEAD)
	for c in 4:
		var col: Vector4 = inv[c]
		h[c * 4] = col.x
		h[c * 4 + 1] = col.y
		h[c * 4 + 2] = col.z
		h[c * 4 + 3] = col.w
	for c in 3:
		var bc: Vector3 = xf.basis[c]
		h[16 + c * 4] = bc.x
		h[17 + c * 4] = bc.y
		h[18 + c * 4] = bc.z
	h[28] = xf.origin.x
	h[29] = xf.origin.y
	h[30] = xf.origin.z
	h[31] = 1.0
	h[32] = heat_time
	h[33] = float(n)
	h[34] = heat_bend
	# pixels per metre at a metre's distance: half the image's height times the focal length
	h[35] = 0.5 * float(size.y) * absf(pr.y.y)
	h.append_array(hs.slice(0, n * HEAT_STRIDE))
	rd.buffer_update(_heat_buf, 0, h.size() * 4, h.to_byte_array())


## The motion blur's camera: this frame's (to find each pixel's point in the
## world) and last frame's (to find where that point was on screen then).
const TILE := 32  # pixels to a side of a motion tile: also the longest blur, as the filter needs
const MOTION_FLOATS := 52


func _motion_header(render_data: RenderData, on: bool) -> void:
	var sd := render_data.get_render_scene_data()
	var pr: Projection = sd.get_cam_projection()
	var xf: Transform3D = sd.get_cam_transform()
	var vp: Projection = pr * Projection(xf.affine_inverse())
	if not on:
		_prev_vp = vp
		_prev_ok = true
		if _motion_on:
			# tell the composite the blurred scene is no longer there to start from
			_motion_on = false
			rd.buffer_update(_motion_buf, 48 * 4, 16, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array())
		return
	_motion_on = true
	var h := PackedFloat32Array()
	h.resize(MOTION_FLOATS)
	_put(h, 0, pr.inverse())
	_put(h, 16, Projection(xf))
	# the first frame (or the first after the blur was off) has no last frame: no camera movement
	_put(h, 32, _prev_vp if _prev_ok else vp)
	h[48] = blur_shutter
	h[49] = blur_camera
	h[50] = float(TILE)
	h[51] = 1.0
	rd.buffer_update(_motion_buf, 0, MOTION_FLOATS * 4, h.to_byte_array())
	_prev_vp = vp
	_prev_ok = true


static func _put(h: PackedFloat32Array, at: int, m: Projection) -> void:
	for c in 4:
		var col: Vector4 = m[c]
		h[at + c * 4] = col.x
		h[at + c * 4 + 1] = col.y
		h[at + c * 4 + 2] = col.z
		h[at + c * 4 + 3] = col.w


## The pass's own pipeline (the blur and streak passes share one each).
const PIPE_OF := {"blur_h": "blur", "blur_v": "blur", "streak_0": "streak", "streak_1": "streak", "streak_2": "streak",
	"gauss_h": "gauss", "gauss_v": "gauss"}


func _run(pass_name: String, groups: Vector2i, push := PackedByteArray()) -> void:
	var pipe: RID = _pipes[PIPE_OF.get(pass_name, pass_name)]
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipe)
	rd.compute_list_bind_uniform_set(cl, _sets[pass_name], 0)
	if not push.is_empty():
		rd.compute_list_set_push_constant(cl, push, push.size())
	rd.compute_list_dispatch(cl, groups.x, groups.y, 1)
	rd.compute_list_end()


## The intermediate images, kept with the view's render buffers (they go when
## the view is resized and come back at the new size).
func _textures(buffers: RenderSceneBuffersRD, size: Vector2i, qs: Vector2i, need_src: bool, blur: bool) -> Dictionary:
	if buffers.has_texture(CTX, "bright"):
		var f: RDTextureFormat = buffers.get_texture_format(CTX, "bright")
		if int(f.width) != qs.x or int(f.height) != qs.y:
			buffers.clear_context(CTX)
	var out := {}
	for n: String in ["bright", "mask", "shaft", "base_a", "base_b", "streak_a", "streak_b", "glow_a", "glow_b", "flare", "heat"]:
		if not buffers.has_texture(CTX, n):
			buffers.create_texture(CTX, n, RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, qs, 1, 1, true, false)
		out[n] = buffers.get_texture(CTX, n)
	if need_src:
		if buffers.has_texture(CTX, "src"):
			var f: RDTextureFormat = buffers.get_texture_format(CTX, "src")
			if int(f.width) != size.x or int(f.height) != size.y:
				buffers.clear_context(CTX)
				return _textures(buffers, size, qs, need_src, blur)
		else:
			buffers.create_texture(CTX, "src", RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
		out["src"] = buffers.get_texture(CTX, "src")
	if blur:
		var tg := Vector2i((size.x + TILE - 1) >> 5, (size.y + TILE - 1) >> 5)
		for n: String in ["mvel", "mtile", "mneigh"]:
			var want := size if n == "mvel" else tg
			if buffers.has_texture(CTX, n):
				var f: RDTextureFormat = buffers.get_texture_format(CTX, n)
				if int(f.width) != want.x or int(f.height) != want.y:
					buffers.clear_context(CTX)
					return _textures(buffers, size, qs, need_src, blur)
			else:
				buffers.create_texture(CTX, n, RGBA16F, USAGE, RenderingDevice.TEXTURE_SAMPLES_1, want, 1, 1, true, false)
			out[n] = buffers.get_texture(CTX, n)
	return out


func _build_sets(color: RID, depth: RID, velocity: RID, t: Dictionary, need_src: bool, blur: bool) -> void:
	var bright: RID = t["bright"]
	var src: RID = t["src"] if need_src else bright
	var base_a: RID = t["base_a"]
	var streak_a: RID = t["streak_a"]
	var streak_b: RID = t["streak_b"]
	_sets.clear()
	_sets["prep"] = _uniforms("prep", [_smp(1, color), _smp(2, depth), _img(3, bright), _img(4, t["mask"])])
	_sets["blur_h"] = _uniforms("blur", [_smp(1, bright), _img(2, base_a)])
	_sets["blur_v"] = _uniforms("blur", [_smp(1, base_a), _img(2, t["base_b"])])
	_sets["reduce"] = _uniforms("reduce", [_smp(1, bright), _buf(2, _adapt)])
	_sets["shafts"] = _uniforms("shafts", [_smp(1, t["mask"]), _img(2, t["shaft"])])
	_sets["streak_0"] = _uniforms("streak", [_smp(1, bright), _img(2, streak_a)])
	_sets["streak_1"] = _uniforms("streak", [_smp(1, streak_a), _img(2, streak_b)])
	_sets["streak_2"] = _uniforms("streak", [_smp(1, streak_b), _img(2, streak_a)])
	_sets["gauss_h"] = _uniforms("gauss", [_smp(1, bright), _img(2, t["glow_a"])])
	_sets["gauss_v"] = _uniforms("gauss", [_smp(1, t["glow_a"]), _img(2, t["glow_b"])])
	_sets["flare"] = _uniforms("flare", [_smp(1, t["glow_b"]), _smp(2, streak_a), _img(3, t["flare"])])
	_sets["heat"] = _uniforms("heat", [_smp(1, depth), _img(2, t["heat"]), _buf(10, _heat_buf)])
	if need_src:
		_sets["copy"] = _uniforms("copy", [_img(1, color), _img(2, src)])
	if blur:
		_sets["mvel"] = _uniforms("mvel", [_smp(1, velocity), _smp(2, depth), _img(3, t["mvel"]), _buf(11, _motion_buf)])
		_sets["mtile"] = _uniforms("mtile", [_smp(1, t["mvel"]), _img(2, t["mtile"])])
		_sets["mneigh"] = _uniforms("mneigh", [_smp(1, t["mtile"]), _img(2, t["mneigh"])])
		_sets["mblur"] = _uniforms("mblur", [_smp(1, color), _smp(2, t["mvel"]), _smp(3, t["mneigh"]), _img(4, src)])
	_sets["composite"] = _uniforms("composite", [_img(1, color), _smp(2, src), _smp(3, t["shaft"]), _smp(4, t["flare"]),
		_smp(5, t["base_b"]), _smp(6, bright), _buf(7, _adapt), _smp(8, depth), _smp(9, t["heat"]), _buf(10, _heat_buf),
		_buf(11, _motion_buf)])


func _uniforms(shader: String, uniforms: Array[RDUniform]) -> RID:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = 0
	u.add_id(_ubo)
	var all: Array[RDUniform] = [u]
	all.append_array(uniforms)
	return UniformSetCacheRD.get_cache(_shaders[shader], 0, all)


func _img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


func _smp(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_sampler)
	u.add_id(tex)
	return u


func _buf(binding: int, buf: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buf)
	return u


# --- the passes ---------------------------------------------------------------

const HEADER := """#version 450
layout(set = 0, binding = 0, std140) uniform Params {
	vec4 size;     // full width, height; quarter width, height
	vec4 sun;      // the sun on screen (uv), how much of it is in view, aspect (w / h)
	vec4 sun_col;  // shaft colour in scene units; strength
	vec4 lens;     // ghosts and halo, streaks, dirt, bright threshold (display units)
	vec4 tone;     // local exposure, eye adaptation, scene exposure, frame time (s)
	vec4 film;     // halation, night vision, sharpening, debug view (FL_DEBUG_CINE_VIEW)
	vec4 adapt;    // rate towards brighter, towards darker, long-term (1 / s); heat haze (0 or 1)
	vec4 flags;    // shafts, lens, local exposure, eye adaptation (0 or 1)
} P;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// a NaN or infinity anywhere in the scene would be smeared across the
// screen by the blurs: such pixels count as black
vec3 clean(vec3 c) {
	return (any(isnan(c)) || any(isinf(c))) ? vec3(0.0) : max(c, vec3(0.0));
}

// interleaved gradient noise (Jimenez 2014): dithers ray starts without patterns
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}
"""

## The camera and the heat sources (the heat pass and the composite).
const HEAT_DECL := """
layout(set = 0, binding = 10, std430) restrict readonly buffer Heat {
	mat4 inv_proj;  // the camera's projection as drawn (flipped to the image's rows, depth reversed 0..1), inverted
	mat4 cam;       // camera to world
	vec4 info;      // seconds rising, sources, bend (m), pixels per metre a metre away
	vec4 src[];     // per source: centre, width (m); axis, stretch along it; strength, rise (m/s), cell (m), churn
} H;

// a pixel's point in view space, from its depth (reversed: 1 near, 0 far)
vec3 view_at(vec2 uv, float d) {
	vec4 v = H.inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}
"""

const MOTION_DECL := """
layout(set = 0, binding = 11, std430) restrict readonly buffer Motion {
	mat4 inv_proj;  // this frame's projection as drawn, inverted
	mat4 cam;       // camera to world
	mat4 prev_vp;   // last frame's projection x world to camera
	vec4 info;      // shutter (share of a frame), camera's share, longest blur (px), on
} M;
"""

const PASSES := {
	# the quarter-resolution bright pass, metering and the sky mask for the shafts
	"prep": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D color_tex;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D bright_img;
layout(rgba16f, set = 0, binding = 4) uniform restrict writeonly image2D mask_img;

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 px = 1.0 / P.size.xy;
	vec2 uv = (vec2(q) * 4.0 + 2.0) * px;
	// four bilinear taps, each the mean of a 2 x 2 block: the 4 x 4 block under this texel
	vec3 c0 = clean(textureLod(color_tex, uv + vec2(-px.x, -px.y), 0.0).rgb);
	vec3 c1 = clean(textureLod(color_tex, uv + vec2(px.x, -px.y), 0.0).rgb);
	vec3 c2 = clean(textureLod(color_tex, uv + vec2(-px.x, px.y), 0.0).rgb);
	vec3 c3 = clean(textureLod(color_tex, uv + vec2(px.x, px.y), 0.0).rgb);
	float e = P.tone.z;
	float w0 = 1.0 / (1.0 + luma(c0) * e);
	float w1 = 1.0 / (1.0 + luma(c1) * e);
	float w2 = 1.0 / (1.0 + luma(c2) * e);
	float w3 = 1.0 / (1.0 + luma(c3) * e);
	vec3 c = (c0 * w0 + c1 * w1 + c2 * w2 + c3 * w3) / (w0 + w1 + w2 + w3);
	vec3 m = (c0 + c1 + c2 + c3) * 0.25;
	float ll = log2(clamp(luma(m) * e, 1e-4, 6e4));
	// soft-kneed threshold: only light well past white flares the lens
	float le = luma(c) * e;
	float t = P.lens.w;
	float knee = t * 0.5;
	float soft = clamp(le - t + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee + 1e-5);
	vec3 b = c * (max(soft, le - t) / max(le, 1e-5));
	b = min(b, vec3(48.0 / e));
	if (any(isnan(b))) {
		b = vec3(0.0);
	}
	imageStore(bright_img, q, vec4(b, ll));
	if (P.flags.x > 0.5) {
		// open sky (nothing drawn there: reversed depth reads 0) near the sun
		ivec2 f = q * 4;
		ivec2 fm = ivec2(P.size.xy) - 1;
		float sky = step(texelFetch(depth_tex, min(f + ivec2(1, 1), fm), 0).r, 1e-7)
			+ step(texelFetch(depth_tex, min(f + ivec2(3, 1), fm), 0).r, 1e-7)
			+ step(texelFetch(depth_tex, min(f + ivec2(1, 3), fm), 0).r, 1e-7)
			+ step(texelFetch(depth_tex, min(f + ivec2(3, 3), fm), 0).r, 1e-7);
		vec2 d = (uv - P.sun.xy) * vec2(P.sun.w, 1.0);
		float near_sun = 1.0 - smoothstep(0.0, 0.38, length(d));
		imageStore(mask_img, q, vec4(sky * 0.25 * near_sun * near_sun * min(luma(m) * e, 3.0)));
	}
}
""",
	# separable cross-bilateral blur of log luminance: the base layer for local exposure
	"blur": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D src_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D dst_img;
layout(push_constant, std430) uniform Pass {
	vec2 dir;
	float from_alpha;
	float pad;
} pc;

float pick(vec4 s) {
	return pc.from_alpha > 0.5 ? s.a : s.r;
}

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 texel = 1.0 / P.size.zw;
	vec2 uv = (vec2(q) + 0.5) * texel;
	float c = pick(textureLod(src_tex, uv, 0.0));
	float sum = 0.0;
	float wsum = 0.0;
	for (int i = -12; i <= 12; i++) {
		float v = pick(textureLod(src_tex, uv + pc.dir * texel * float(i) * 2.0, 0.0));
		float dv = v - c;
		// spatial sigma 12 texels (about a twentieth of the screen), range sigma about a stop
		float w = exp(-float(i * i) / 72.0) * exp(-dv * dv * 0.5);
		sum += v * w;
		wsum += w;
	}
	imageStore(dst_img, q, vec4(sum / wsum));
}
""",
	# meters the frame (centre-weighted) and lets the eye adapt to it
	"reduce": """
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D bright_tex;
layout(set = 0, binding = 2, std430) restrict buffer Adapt {
	vec4 state;  // adapted log2 luminance: quick, long-term; seconds since primed; this frame's
} A;

shared float s_sum[256];
shared float s_w[256];

void main() {
	uint t = gl_LocalInvocationIndex;
	ivec2 qs = ivec2(P.size.zw);
	float sum = 0.0;
	float wsum = 0.0;
	for (int y = int(gl_LocalInvocationID.y); y < qs.y; y += 16) {
		for (int x = int(gl_LocalInvocationID.x); x < qs.x; x += 16) {
			vec2 d = (vec2(x, y) + 0.5) / vec2(qs) * 2.0 - 1.0;
			float w = exp(-dot(d, d) * 1.5);
			sum += texelFetch(bright_tex, ivec2(x, y), 0).a * w;
			wsum += w;
		}
	}
	s_sum[t] = sum;
	s_w[t] = wsum;
	memoryBarrierShared();
	barrier();
	for (uint s = 128u; s > 0u; s >>= 1u) {
		if (t < s) {
			s_sum[t] += s_sum[t + s];
			s_w[t] += s_w[t + s];
		}
		memoryBarrierShared();
		barrier();
	}
	if (t == 0u) {
		vec4 st = A.state;
		float avg = s_sum[0] / max(s_w[0], 1e-6);
		bool bad = !(abs(st.x) < 64.0) || !(abs(st.y) < 64.0);
		if (!(abs(avg) < 64.0)) {
			avg = bad ? 0.0 : st.x;
		}
		if (st.z <= 0.0 || bad) {
			st = vec4(avg, avg, 1e-3, avg);
		} else {
			float dt = clamp(P.tone.w, 0.0, 0.25);
			float rate = avg > st.x ? P.adapt.x : P.adapt.y;
			st.x += (avg - st.x) * (1.0 - exp(-dt * rate));
			// while the view settles (a battle drawing its first frames, a new
			// mood) the long-term level goes with it, so nothing pumps
			st.y = st.z < 2.0 ? st.x : st.y + (avg - st.y) * (1.0 - exp(-dt * P.adapt.z));
			st.z = min(st.z + dt, 10.0);
			st.w = avg;
		}
		A.state = st;
	}
}
""",
	# radial blur of the sky mask towards the sun
	"shafts": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D mask_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D shaft_img;

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 uv = (vec2(q) + 0.5) / P.size.zw;
	const int N = 56;
	vec2 delta = (P.sun.xy - uv) * (0.94 / float(N));
	vec2 s = uv + delta * ign(vec2(q));
	float fall = 1.0;
	float acc = 0.0;
	for (int i = 0; i < N; i++) {
		acc += textureLod(mask_tex, s, 0.0).r * fall;
		fall *= 0.955;
		s += delta;
	}
	vec3 col = P.sun_col.rgb * (acc * 0.5 / float(N)) * P.sun_col.w * P.sun.z / max(P.tone.z, 1e-3);
	imageStore(shaft_img, q, vec4(col, 1.0));
}
""",
	# one pass of Kawase's streak filter: three of them stretch each light sideways
	"streak": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D src_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D dst_img;
layout(push_constant, std430) uniform Pass {
	float stride;
	float hot;
	float pad1;
	float pad2;
} pc;

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 texel = 1.0 / P.size.zw;
	vec2 uv = (vec2(q) + 0.5) * texel;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = -3; i <= 3; i++) {
		float w = pow(0.983, abs(float(i)) * pc.stride);
		vec3 c = textureLod(src_tex, uv + vec2(float(i) * pc.stride * texel.x, 0.0), 0.0).rgb;
		if (pc.hot > 0.5) {
			c *= smoothstep(P.lens.w * 2.0, P.lens.w * 6.0, luma(c) * P.tone.z);
		}
		sum += c * w;
		wsum += w;
	}
	imageStore(dst_img, q, vec4(sum / wsum, 1.0));
}
""",
	# a separable Gaussian of the bright pass: the soft light the ghosts and the dirt are made of
	"gauss": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D src_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D dst_img;
layout(push_constant, std430) uniform Pass {
	vec2 dir;
	float stride;
	float pad;
} pc;

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 texel = 1.0 / P.size.zw;
	vec2 uv = (vec2(q) + 0.5) * texel;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = -12; i <= 12; i++) {
		float w = exp(-float(i * i) / 72.0);
		sum += textureLod(src_tex, uv + pc.dir * texel * (float(i) * pc.stride), 0.0).rgb * w;
		wsum += w;
	}
	imageStore(dst_img, q, vec4(sum / wsum, 1.0));
}
""",
	# ghosts, halo, streaks and the glare on the dirty glass
	"flare": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D glow_tex;
layout(set = 0, binding = 2) uniform sampler2D streak_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D flare_img;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// grease smudges and soft dust motes on the front element, heavier towards its rim
float dirt(vec2 uv) {
	vec2 p = (uv - 0.5) * vec2(P.sun.w, 1.0);
	float d = smoothstep(0.5, 0.9, vnoise(p * 2.3 + 3.1) * 0.6 + vnoise(p * 5.1 - 1.7) * 0.4) * 0.6;
	for (int k = 0; k < 2; k++) {
		float sc = k == 0 ? 4.0 : 9.0;
		vec2 g = p * sc + float(k) * 11.3;
		vec2 cell = floor(g);
		float h = hash12(cell);
		if (h > 0.62) {
			vec2 c = vec2(0.32) + 0.36 * vec2(hash12(cell + 7.1), hash12(cell + 3.7));
			float r = 0.1 + 0.18 * hash12(cell + 1.3);
			float disc = 1.0 - smoothstep(r * 0.15, r, length(fract(g) - c));
			d += disc * disc * (0.2 + 0.5 * fract(h * 7.0));
		}
	}
	return d * (0.25 + 0.75 * smoothstep(0.1, 0.9, length(p)));
}

vec3 chroma(vec2 uv, vec2 dir, float spread) {
	return vec3(textureLod(glow_tex, uv - dir * spread, 0.0).r, textureLod(glow_tex, uv, 0.0).g,
		textureLod(glow_tex, uv + dir * spread, 0.0).b);
}

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 texel = 1.0 / P.size.zw;
	vec2 uv = (vec2(q) + 0.5) * texel;
	vec2 aspect = vec2(P.sun.w, 1.0);
	vec3 col = vec3(0.0);
	if (P.lens.x > 0.0) {
		// each light is mirrored through the centre, then repeated along the line through it
		vec2 f = vec2(1.0) - uv;
		vec2 gv = (vec2(0.5) - f) * 0.42;
		vec2 dir = normalize(gv * aspect + 1e-5) / aspect;
		vec3 ghosts = vec3(0.0);
		for (int i = 0; i < 5; i++) {
			vec2 g = f + gv * float(i);
			float r = length((vec2(0.5) - g) * aspect) / (0.5 * P.sun.w);
			float w = pow(max(1.0 - r, 0.0), 6.0);
			// each ghost takes the colour of the coating that reflected it
			vec3 tint = mix(vec3(1.0, 0.72, 0.42), vec3(0.42, 0.78, 1.0), fract(float(i) * 0.37 + r * 0.6));
			ghosts += chroma(g, dir, texel.x * 3.0 * float(i + 1)) * w * tint;
		}
		// the halo: a ring the aperture throws round the centre
		vec2 h = f + dir * 0.46;
		float hr = length((vec2(0.5) - h) * aspect) / (0.5 * P.sun.w);
		float hw = pow(max(1.0 - hr, 0.0), 5.0);
		vec3 halo = chroma(h, dir, texel.x * 6.0) * hw * vec3(1.0, 0.86, 0.7);
		col += (ghosts * 0.45 + halo * 0.35) * P.lens.x;
	}
	if (P.lens.y > 0.0) {
		col += textureLod(streak_tex, uv, 0.0).rgb * vec3(0.55, 0.72, 1.0) * P.lens.y;
	}
	if (P.lens.z > 0.0) {
		// the glare round each light, as far as the dirt on the glass catches it
		vec3 wide = textureLod(glow_tex, uv, 0.0).rgb;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 2.39996;
			float r = sqrt((float(i) + 0.5) / 8.0) * 0.08;
			wide += textureLod(glow_tex, uv + vec2(cos(a), sin(a)) * r / aspect, 0.0).rgb;
		}
		col += wide * (1.0 / 9.0) * dirt(uv) * P.lens.z;
	}
	imageStore(flare_img, q, vec4(col, 1.0));
}
""",
	# the hot air over each heat source, integrated along the view rays, and the shimmer it throws
	"heat": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D heat_img;

// erf to about 1e-4 (Winitzki 2008)
float erf_w(float x) {
	float x2 = x * x;
	float ax2 = 0.147 * x2;
	return sign(x) * sqrt(max(1.0 - exp(-x2 * (1.2732395 + ax2) / (1.0 + ax2)), 0.0));
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// two octaves of turbulence, each pulling the view two ways at once (-0.75 .. 0.75)
vec2 churn(vec3 p) {
	vec2 a = vec2(vnoise3(p), vnoise3(p + vec3(19.1, 7.3, 11.7)));
	vec3 p2 = p * 2.13 + vec3(5.2, 13.9, 3.1);
	vec2 b = vec2(vnoise3(p2), vnoise3(p2 + vec3(3.7, 17.5, 8.9)));
	return (a - 0.5) + (b - 0.5) * 0.5;
}

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (q.x >= int(P.size.z) || q.y >= int(P.size.w)) {
		return;
	}
	vec2 uv = (vec2(q) * 4.0 + 2.0) / P.size.xy;
	// the farthest point under this texel: the haze reaches round whatever stands
	// in front of it here, and the composite cuts it off that at full resolution
	ivec2 f = q * 4;
	ivec2 fm = ivec2(P.size.xy) - 1;
	float d = min(min(texelFetch(depth_tex, min(f + ivec2(1, 1), fm), 0).r, texelFetch(depth_tex, min(f + ivec2(3, 1), fm), 0).r),
		min(texelFetch(depth_tex, min(f + ivec2(1, 3), fm), 0).r, texelFetch(depth_tex, min(f + ivec2(3, 3), fm), 0).r));
	vec3 vp = view_at(uv, max(d, 1e-6));
	float far = d < 1e-7 ? 1e6 : length(vp);
	vec3 o = H.cam[3].xyz;
	vec3 rd = normalize(mat3(H.cam) * vp);
	float tt = H.info.x;
	int n = int(H.info.y + 0.5);
	vec2 off = vec2(0.0);
	float mask = 0.0;
	float front = 0.0;
	for (int i = 0; i < n; i++) {
		vec4 s0 = H.src[i * 3];
		vec4 s1 = H.src[i * 3 + 1];
		vec4 s2 = H.src[i * 3 + 2];
		// in the blob's own coordinates, where it is round: how near the ray
		// comes to its centre, and how much of it lies before the scene does
		vec3 oc = o - s0.xyz;
		float k = 1.0 / (s1.w * s1.w) - 1.0;
		float du = dot(rd, s1.xyz);
		float ou = dot(oc, s1.xyz);
		float a = 1.0 + k * du * du;
		float b = dot(oc, rd) + k * ou * du;
		float c = dot(oc, oc) + k * ou * ou;
		float m2 = (c - b * b / a) / (s0.w * s0.w);
		if (m2 > 9.0) {
			continue;
		}
		float tm = -b / a;
		float sa = sqrt(0.5 * a) / s0.w;
		float along = 0.5 * (erf_w(sa * (far - tm)) + erf_w(sa * tm));
		float w = s2.x * exp(-0.5 * m2) * along;
		float dist = clamp(tm, 0.5, far);
		float ppm = H.info.w / dist;
		// too small on screen to bend anything visibly: it would only sparkle
		w *= smoothstep(1.5, 5.0, s0.w * ppm);
		if (w < 0.004) {
			continue;
		}
		// the turbulence, carried up the axis as the air rises and churning as it
		// goes; never finer than this pass can draw (four of its texels a cell)
		float cell = max(s2.z, 16.0 / ppm);
		vec3 hp = o + rd * dist - s1.xyz * (tt * s2.y);
		off += churn(hp / cell + vec3(0.0, 0.0, tt * s2.w)) * (w * ppm * H.info.z);
		mask += w;
		// where the hot air begins along the ray (weighted: divided out in the composite)
		front += w * max(tm - 1.5 * s0.w * inversesqrt(a), 0.0);
	}
	// never more than a few pixels, however near the camera comes
	float cap = 8.0 * P.size.y / 1080.0;
	float len = length(off);
	if (len > cap) {
		off *= cap / len;
	}
	imageStore(heat_img, q, vec4(off, mask, front));
}
""",
	# each pixel's blur: half its streak in pixels, and how far away it is
	"mvel": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D vel_tex;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D mvel_img;

// the engine's velocity buffer holds where each pixel was last frame less where
// it is now, in uv: turned round, the move since last frame (measured: on still
// ground while the camera pans, -velocity matches the camera's reprojection)
const float VELOCITY_SCALE = -1.0;

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= int(P.size.x) || p.y >= int(P.size.y)) {
		return;
	}
	vec2 uv = (vec2(p) + 0.5) / P.size.xy;
	float d = texelFetch(depth_tex, p, 0).r;
	bool sky = d <= 1e-7;
	vec4 v = M.inv_proj * vec4(uv * 2.0 - 1.0, sky ? 1e-6 : d, 1.0);
	vec3 view = v.xyz / v.w;
	// where this point was on screen last frame, had only the camera moved
	vec4 was = M.prev_vp * (M.cam * vec4(view, 1.0));
	vec2 cam = uv - (was.xy / max(was.w, 1e-6) * 0.5 + 0.5);
	// the engine's movement is the camera's and the thing's own together
	vec2 moved = texelFetch(vel_tex, p, 0).xy * VELOCITY_SCALE;
	vec2 own = sky ? vec2(0.0) : moved - cam;
	vec2 b = (own + cam * M.info.y) * M.info.x * P.size.xy * 0.5;
	if (P.film.w > 6.5) {
		// debug view 7: red the engine's movement less the camera's (~0 on still ground), green plus it
		b = vec2(length(moved - cam), length(moved + cam)) * P.size.y;
	}
	float l = length(b);
	if (l > M.info.z) {
		b *= M.info.z / l;
	}
	if (any(isnan(b)) || any(isinf(b))) {
		b = vec2(0.0);
	}
	imageStore(mvel_img, p, vec4(b, -view.z, 0.0));
}
""",
	# the longest blur in each tile
	"mtile": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D mvel_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D tile_img;

void main() {
	ivec2 t = ivec2(gl_GlobalInvocationID.xy);
	ivec2 tiles = (ivec2(P.size.xy) + 31) / 32;
	if (t.x >= tiles.x || t.y >= tiles.y) {
		return;
	}
	ivec2 m = ivec2(P.size.xy) - 1;
	vec2 best = vec2(0.0);
	float bl = 0.0;
	// every other pixel: a thin fast thing is still two pixels wide in its own blur
	for (int y = 0; y < 32; y += 2) {
		for (int x = 0; x < 32; x += 2) {
			vec2 b = texelFetch(mvel_tex, min(t * 32 + ivec2(x, y), m), 0).xy;
			float l = dot(b, b);
			if (l > bl) {
				bl = l;
				best = b;
			}
		}
	}
	imageStore(tile_img, t, vec4(best, 0.0, 0.0));
}
""",
	# and the longest among each tile's neighbours, which can reach into it
	"mneigh": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D tile_tex;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D neigh_img;

void main() {
	ivec2 t = ivec2(gl_GlobalInvocationID.xy);
	ivec2 tiles = (ivec2(P.size.xy) + 31) / 32;
	if (t.x >= tiles.x || t.y >= tiles.y) {
		return;
	}
	vec2 best = vec2(0.0);
	float bl = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 b = texelFetch(tile_tex, clamp(t + ivec2(x, y), ivec2(0), tiles - 1), 0).xy;
			float l = dot(b, b);
			if (l > bl) {
				bl = l;
				best = b;
			}
		}
	}
	imageStore(neigh_img, t, vec4(best, 0.0, 0.0));
}
""",
	# the gather: samples along the neighbourhood's blur, weighed by depth and speed
	"mblur": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 1) uniform sampler2D color_tex;
layout(set = 0, binding = 2) uniform sampler2D mvel_tex;
layout(set = 0, binding = 3) uniform sampler2D neigh_tex;
layout(rgba16f, set = 0, binding = 4) uniform restrict writeonly image2D out_img;

float cone(float dist, float len) {
	return clamp(1.0 - dist / len, 0.0, 1.0);
}

float cylinder(float dist, float len) {
	return 1.0 - smoothstep(0.95 * len, 1.05 * len, dist);
}

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= int(P.size.x) || p.y >= int(P.size.y)) {
		return;
	}
	vec4 c0 = texelFetch(color_tex, p, 0);
	vec4 mc = texelFetch(mvel_tex, p, 0);
	if (P.film.w > 5.5) {
		// debug views: 6 each pixel's blur (px / 16), 7 the velocity check (see mvel)
		imageStore(out_img, p, vec4(abs(mc.xy) / (P.film.w > 6.5 ? 0.02 * P.size.y : 16.0), 0.02, c0.a));
		return;
	}
	vec2 vn = texelFetch(neigh_tex, p / 32, 0).xy;
	float ln = length(vn);
	if (ln < 0.5) {
		imageStore(out_img, p, c0);
		return;
	}
	ivec2 m = ivec2(P.size.xy) - 1;
	float lc = max(length(mc.xy), 0.5);
	float zc = mc.z;
	// what counts as the same surface: a little depth, more far off
	float extent = max(0.25, zc * 0.02);
	float wsum = 1.0 / lc;
	vec3 sum = clean(c0.rgb) * wsum;
	const int S = 14;
	float j = ign(vec2(p)) - 0.5;
	for (int i = 0; i < S; i++) {
		float t = (float(i) + 0.5 + j) / float(S) * 2.0 - 1.0;
		ivec2 sp = clamp(ivec2(vec2(p) + 0.5 + vn * t), ivec2(0), m);
		vec4 ms = texelFetch(mvel_tex, sp, 0);
		float ls = max(length(ms.xy), 0.5);
		float dist = abs(t) * ln;
		// a sample in front smears over this pixel by its own blur; this pixel, if
		// in front, smears over what's behind it by this one's; and two moving
		// together blend
		float in_front = clamp(1.0 - (ms.z - zc) / extent, 0.0, 1.0);
		float behind = clamp(1.0 - (zc - ms.z) / extent, 0.0, 1.0);
		float w = in_front * cone(dist, ls) + behind * cone(dist, lc) + cylinder(dist, ls) * cylinder(dist, lc) * 2.0;
		sum += clean(texelFetch(color_tex, sp, 0).rgb) * w;
		wsum += w;
	}
	imageStore(out_img, p, vec4(sum / wsum, c0.a));
}
""",
	# a copy of the scene for the sharpening and the haze to read its neighbours from
	"copy": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 1) uniform restrict readonly image2D src_img;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D dst_img;

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= int(P.size.x) || p.y >= int(P.size.y)) {
		return;
	}
	imageStore(dst_img, p, imageLoad(src_img, p));
}
""",
	# everything back into the full-resolution scene
	"composite": """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 1) uniform restrict image2D color_img;
layout(set = 0, binding = 2) uniform sampler2D src_tex;
layout(set = 0, binding = 3) uniform sampler2D shaft_tex;
layout(set = 0, binding = 4) uniform sampler2D flare_tex;
layout(set = 0, binding = 5) uniform sampler2D base_tex;
layout(set = 0, binding = 6) uniform sampler2D bright_tex;
layout(set = 0, binding = 7, std430) restrict readonly buffer Adapt {
	vec4 state;
} A;
layout(set = 0, binding = 8) uniform sampler2D depth_tex;
layout(set = 0, binding = 9) uniform sampler2D heat_tex;

vec3 squash(vec3 c) {
	return c / (1.0 + c);
}

vec3 unsquash(vec3 t) {
	return t / max(vec3(1.0) - t, vec3(1e-3));
}

vec3 tap(ivec2 p) {
	return squash(clean(texelFetch(src_tex, clamp(p, ivec2(0), ivec2(P.size.xy) - 1), 0).rgb));
}

// contrast-adaptive sharpening: sharpens less where the neighbourhood already has contrast
vec3 cas(ivec2 p, float sharp) {
	vec3 a = tap(p + ivec2(-1, -1));
	vec3 b = tap(p + ivec2(0, -1));
	vec3 c = tap(p + ivec2(1, -1));
	vec3 d = tap(p + ivec2(-1, 0));
	vec3 e = tap(p);
	vec3 f = tap(p + ivec2(1, 0));
	vec3 g = tap(p + ivec2(-1, 1));
	vec3 h = tap(p + ivec2(0, 1));
	vec3 i = tap(p + ivec2(1, 1));
	vec3 mn = min(min(min(d, e), min(f, b)), h);
	mn += min(mn, min(min(a, c), min(g, i)));
	vec3 mx = max(max(max(d, e), max(f, b)), h);
	mx += max(mx, max(max(a, c), max(g, i)));
	vec3 amp = sqrt(clamp(min(mn, 2.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0));
	vec3 w = amp * (-1.0 / mix(8.0, 5.0, clamp(sharp, 0.0, 1.0)));
	vec3 r = (b * w + d * w + f * w + h * w + e) / (1.0 + 4.0 * w);
	return unsquash(clamp(r, vec3(0.0), vec3(0.999)));
}

// the blurred base brought up to full resolution, weighted towards the
// quarter-resolution texels that look like this pixel
float base_at(vec2 uv, float guide) {
	vec2 st = uv * P.size.zw - 0.5;
	ivec2 i0 = ivec2(floor(st));
	vec2 fr = st - floor(st);
	ivec2 m = ivec2(P.size.zw) - 1;
	float sum = 0.0;
	float ws = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k & 1, k >> 1);
		ivec2 ic = clamp(i0 + o, ivec2(0), m);
		vec2 wb = mix(vec2(1.0) - fr, fr, vec2(o));
		float d = guide - texelFetch(bright_tex, ic, 0).a;
		float w = wb.x * wb.y * exp(-d * d * 1.4) + 1e-4;
		sum += texelFetch(base_tex, ic, 0).r * w;
		ws += w;
	}
	return sum / ws;
}

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= int(P.size.x) || p.y >= int(P.size.y)) {
		return;
	}
	vec2 uv = (vec2(p) + 0.5) / P.size.xy;
	vec4 src = imageLoad(color_img, p);
	vec3 c = src.rgb;
	if (M.info.w > 0.5) {
		c = texelFetch(src_tex, p, 0).rgb;  // the motion-blurred scene
	}
	if (P.film.z > 0.0) {
		c = cas(p, P.film.z);
	}
	if (P.adapt.w > 0.5) {
		// heat haze: what lies behind the hot air is seen through it, bent
		vec4 hz = textureLod(heat_tex, uv, 0.0);
		float d0 = texelFetch(depth_tex, p, 0).r;
		if (hz.b > 0.003 && d0 > 1e-7) {
			float front = hz.a / hz.b;
			// only what lies behind the hot air is bent (and never the sky)
			vec2 off = hz.rg * smoothstep(front - 0.5, front + 1.5, length(view_at(uv, d0)));
			float len = length(off);
			if (len > 0.03) {
				vec2 suv = uv + off / P.size.xy;
				float ds = texelFetch(depth_tex, clamp(ivec2(suv * P.size.xy), ivec2(0), ivec2(P.size.xy) - 1), 0).r;
				// and neither the sky nor anything in front of the hot air is pulled into it
				if (ds > 1e-7 && length(view_at(suv, ds)) > front - 0.5) {
					c = mix(c, clean(textureLod(src_tex, suv, 0.0).rgb), smoothstep(0.03, 0.3, len));
				}
			}
		}
	}
	float e = P.tone.z;
	float ll = log2(clamp(luma(c) * e, 1e-4, 6e4));
	float stops = 0.0;
	if (P.flags.z > 0.5) {
		float base = base_at(uv, ll);
		float key = A.state.y;
		// lift the shade more than the fire is tamed, and keep a little more local contrast
		float k = base < key ? 0.42 : 0.18;
		stops += clamp((key - base) * k * P.tone.x, -1.5, 2.0);
		stops += clamp((ll - base) * 0.18 * P.tone.x, -0.5, 0.5);
	}
	float eye = 0.0;
	if (P.flags.w > 0.5) {
		// against the scene's own long-term level: a flash dims the frame, then it recovers
		eye = clamp((A.state.y - A.state.x) * 0.5 * P.tone.y, -1.0, 0.8);
	}
	c *= exp2(stops + eye);
	vec3 add = vec3(0.0);
	if (P.flags.x > 0.5) {
		add += textureLod(shaft_tex, uv, 0.0).rgb;
	}
	if (P.flags.y > 0.5) {
		add += textureLod(flare_tex, uv, 0.0).rgb;
	}
	if (P.film.x > 0.0) {
		vec2 t = 1.5 / P.size.zw;
		vec3 h = textureLod(bright_tex, uv + vec2(t.x, t.y), 0.0).rgb + textureLod(bright_tex, uv + vec2(-t.x, t.y), 0.0).rgb
			+ textureLod(bright_tex, uv + vec2(t.x, -t.y), 0.0).rgb + textureLod(bright_tex, uv - t, 0.0).rgb;
		add += h * 0.25 * vec3(1.0, 0.3, 0.12) * P.film.x;
	}
	c += add * exp2(eye);
	if (P.film.y > 0.0) {
		// rods see no red and peak in the blue-green: in the dark, colour drains towards a cool grey
		vec3 xyz = mat3(vec3(0.4124, 0.2126, 0.0193), vec3(0.3576, 0.7152, 0.1192), vec3(0.1805, 0.0722, 0.9505)) * max(c, vec3(0.0));
		float v = max(xyz.y * (1.33 * (1.0 + (xyz.y + xyz.z) / max(xyz.x, 1e-6)) - 1.68), 0.0) / 2.573;
		// how much depends on how dark the scene is (the mood sets it: the eye is
		// still on its cones at sunset), and within it on how dark this pixel is
		// against what the eye has adapted to, so fire and flares keep their colour
		float ld = log2(max(xyz.y * e, 1e-6));
		float s = (1.0 - smoothstep(A.state.y - 2.5, A.state.y + 2.5, ld)) * P.film.y;
		c = mix(c, v * vec3(1.05, 0.97, 1.27), s);
	}
	if (P.film.w > 0.5) {
		// debug views: 1 shafts, 2 lens, 3 local exposure (red lifts, blue tames), 4 bright pass,
		// 5 heat haze (blue the hot air, red and green how far it bends, over the scene in grey)
		int view = int(P.film.w + 0.5);
		if (view == 1) {
			c = textureLod(shaft_tex, uv, 0.0).rgb * 4.0;
		} else if (view == 2) {
			c = textureLod(flare_tex, uv, 0.0).rgb * 4.0;
		} else if (view == 3) {
			c = vec3(max(stops, 0.0), 0.05, max(-stops, 0.0)) / e;
		} else if (view == 5) {
			vec4 hz = textureLod(heat_tex, uv, 0.0);
			c = (vec3(luma(src.rgb) * e * 0.25) + vec3(abs(hz.r) * 0.3, abs(hz.g) * 0.3, min(hz.b, 1.0) * 0.8)) / e;
		} else if (view == 4) {
			c = textureLod(bright_tex, uv, 0.0).rgb;
		}
		// (6 and 7, the motion blur's, are drawn by its own pass)
	}
	imageStore(color_img, p, vec4(c, src.a));
}
""",
}
