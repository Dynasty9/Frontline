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
## The waves are one set (WAVES) that the shaders draw and height_at samples,
## so a boat rides the same waves the player sees. Everything on the water
## keeps time by the `water_time` global shader uniform (project.godot). How
## much of it is drawn is the Water quality setting (Settings "water").

const TILE := 64.0  # the surface is drawn in tiles this big, only where there's water
const TILE_SUB := [15, 31, 31, 47]  # quads a tile side, by quality (4 m, 2 m, 2 m, 1.4 m)

## The sea's waves, each [group, heading off the group's way (degrees),
## wavelength (m), height (m)]. Group 0 is the swell, rolling in off the open
## sea from weather far away: long and regular, its two longest trains close
## enough in length to come in sets. Group 1 is the wind's own sea, short and
## steep, running the way the wind blows (Fires.WIND, the wind that carries
## the smoke): offshore on this coast, so it crosses the swell. The weather
## sets how big each group runs (SEA_STATE). Deep-water waves run at
## sqrt(g L / 2 pi), the long ones fastest. They're Gerstner waves: the water
## moves round in a circle as one passes, so the crests come up sharp and the
## troughs broad. The first MOVING move the surface (and the boats); the rest
## only ruffle the light.
const WAVES := [
	[0, 0.0, 58.0, 0.3],
	[0, 9.0, 47.0, 0.24],
	[0, -17.0, 33.0, 0.14],
	[1, 0.0, 21.0, 0.12],
	[1, 28.0, 14.5, 0.08],
	[1, -33.0, 10.0, 0.05],
	[1, 12.0, 6.5, 0.022],
	[1, -48.0, 4.4, 0.014],
	[0, -30.0, 3.1, 0.009],
]
const MOVING := 6
const MOVING_LOW := 4  # (Low's coarse grid can't carry the shortest of them)
const STEEP := 0.75  # how far the crests bunch up in the roughest sea (at 1 they'd fold over)
## The sea in each weather: how big the (swell, wind sea) run.
const SEA_STATE := {"day": Vector2(0.85, 0.6), "hazy": Vector2(0.7, 0.4), "golden": Vector2(0.55, 0.3), "dawn": Vector2(0.45, 0.2),
	"dusk": Vector2(0.5, 0.25), "night": Vector2(0.75, 0.5), "overcast": Vector2(1.0, 0.85), "rain": Vector2(1.15, 1.1)}
const SEA_MAX := 1.25
## The waves build over the first OFFSHORE metres out from the beach (in
## nearer, the surf takes over), which also keeps a dock's jetty dry.
const OFFSHORE := Vector2(4.0, 35.0)
## The surf: a breaker comes ashore every SURF_L metres at SURF_C m/s, rising
## up to SURF_H as it shoals before it spills, and the water it throws up the
## beach stands up to SURGE above the sea.
const SURF_L := 15.0
const SURF_C := 2.1
const SURF_H := 0.3
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
var _terrain_reflections := false
var quality := -1  # the Water quality the surface is built for
var sea := Vector2(0.85, 0.6)  # how big the swell and the wind sea run (SEA_STATE)
var _waves: Array = []  # [direction, k, omega, height, phase, group] per wave
var _q := 0.0  # how far a wave's crest bunches for its height (see STEEP)
var _wf := PackedFloat32Array()  # (height_at) per moving wave: kx, kz, heading x, z, omega, phase, height, bunching, for this sea
var _detail: Texture2D
var caustic_tex: NoiseTexture2D
var _wakes := {}  # eid -> Wake
var _patches: Array = []  # [mi, ends at]
var _patch_i := 0


func _init(w) -> void:
	world = w
	name = "Water"
	_set_waves(0.0)
	Settings.changed.connect(_settings_changed)


## The waves for this coast: the swell comes in square to the shore give or
## take `rot` (radians: each map's own), the wind sea runs with the wind.
func _set_waves(rot: float) -> void:
	_waves.clear()
	var onshore := Vector2(-1, 0).rotated(rot)
	var wind := Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	var ka := 0.0
	for i in WAVES.size():
		var wv: Array = WAVES[i]
		var d: Vector2 = (onshore if int(wv[0]) == 0 else wind).rotated(deg_to_rad(float(wv[1])))
		var k := TAU / float(wv[2])
		_waves.append([d, k, sqrt(9.81 * k), float(wv[3]), i * 1.7, int(wv[0])])
		if i < MOVING:
			ka += k * float(wv[3])
	_q = STEEP / (SEA_MAX * ka)
	_pack()


## The moving waves for height_at, flat and scaled for the sea running now.
func _pack() -> void:
	_wf.clear()
	for i in MOVING:
		var w: Array = _waves[i]
		var d: Vector2 = w[0]
		var k: float = w[1]
		var g: float = sea.x if int(w[5]) == 0 else sea.y
		_wf.append_array([k * d.x, k * d.y, d.x, d.y, float(w[2]), float(w[4]), float(w[3]) * g, _q * float(w[3]) * g])


## Lays the surface over the water (and again whenever the water changes).
func build(w: WaterMap, detail: Texture2D) -> void:
	water = w
	_mask = w.mask
	_detail = detail
	_sea_x = (float(w.coast.x) + 30.0) if not w.coast.is_empty() else 1e9
	if not w.coast.is_empty():
		_set_waves((fposmod(float(w.coast.s) * 0.618, 1.0) - 0.5) * 0.7)
	if mask_tex == null:
		mask_tex = ImageTexture.create_from_image(w.mask)
	else:
		mask_tex.set_image(w.mask)
	if mat == null:
		_make_textures()
		mat = _material("", detail)
		mat.render_priority = -10  # under everything else see-through: smoke, splashes, wakes
		wake_mat = _material("", detail)
		wake_mat.render_priority = -5
		patch_mat = _material("", detail)
		patch_mat.render_priority = -5
	# (the swell's heading is baked into the shaders: they're compiled for this coast)
	wake_mat.shader.code = _code(WAKE_SHADER, MOVING)
	patch_mat.shader.code = _code(PATCH_SHADER, MOVING)
	if _patches.is_empty():
		# (only now: an object given a material whose shader has no code yet
		# draws with the engine's plain white one, and still does once it has)
		_make_patches()
	for m in [mat, wake_mat, patch_mat]:
		Mats.set_shared(m, "water_mask", mask_tex)
		Mats.set_shared(m, "sea_x", _sea_x)
	var c := Vector3.ZERO
	if not w.coast.is_empty():
		c = Vector3(float(w.coast.x), float(w.coast.s), 1.0)
	for m in [mat, wake_mat, patch_mat]:
		Mats.set_shared(m, "coast", c)
	quality = -1
	_settings_changed()


## The Water quality setting: the surface's shader and its grid are built for
## it (Low draws no see-through water and fewer waves; High and Ultra add the
## light dancing on the bed and the wind's streaks; Ultra a finer grid).
func _settings_changed() -> void:
	if mat == null or _mask == null:
		return
	var reflect_terrain := bool(Settings.get_v("terrain_reflections"))
	mat.set_shader_parameter("terrain_reflections", reflect_terrain)
	var wq := clampi(int(Settings.get_v("water")), 0, 3)
	if wq == quality and reflect_terrain == _terrain_reflections:
		return
	quality = wq
	_terrain_reflections = reflect_terrain
	var surface := WATER_SHADER.replace("__WQ__", str(wq))
	if reflect_terrain:
		surface = surface.replace(", ambient_light_disabled", "")
	mat.shader.code = _code(surface, MOVING_LOW if wq == 0 else MOVING)
	_lay_tiles()


func _code(src: String, moving: int) -> String:
	return Mats.code(MapDims.shader(src.replace("__WAVES__", waves_glsl(moving)).replace("__LEVEL__", "%.3f" % WaterMap.LEVEL)))


func _material(src: String, detail: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	if src != "":
		m.shader.code = _code(src, MOVING)
	m.set_shader_parameter("detail_tex", detail)
	m.set_shader_parameter("chop_tex", chop_tex)
	m.set_shader_parameter("foam_tex", foam_tex)
	m.set_shader_parameter("caustic_tex", caustic_tex)
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
	# light focused by the ripples onto the bed: a web of bright lines along
	# the cells' edges
	var kn := FastNoiseLite.new()
	kn.seed = 11
	kn.noise_type = FastNoiseLite.TYPE_CELLULAR
	kn.frequency = 0.035
	kn.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	kn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	caustic_tex = NoiseTexture2D.new()
	caustic_tex.width = 256
	caustic_tex.height = 256
	caustic_tex.seamless = true
	caustic_tex.noise = kn


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
	pm.subdivide_width = int(TILE_SUB[maxi(quality, 0)])
	pm.subdivide_depth = int(TILE_SUB[maxi(quality, 0)])
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
			mi.extra_cull_margin = 2.0  # (the waves lift it and carry it about)
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
	# the sea the weather brings: glassy at dawn, a storm sea in the rain
	sea = SEA_STATE.get(mood, SEA_STATE.day)
	_pack()
	for m in [mat, wake_mat, patch_mat]:
		Mats.set_shared(m, "sea", sea)
	mat.set_shader_parameter("shoal_tint", Color(0.12, 0.46, 0.46).lerp(Color(0.16, 0.28, 0.27), dull))


func _process(dt: float) -> void:
	t += dt
	RenderingServer.global_shader_parameter_set("water_time", t)
	if Vfx.gl and mat and world.atmo and world.atmo.sun:
		# (the browser lights per vertex: the water works the sun's glitter out itself)
		var sun: DirectionalLight3D = world.atmo.sun
		mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z.normalized())
		mat.set_shader_parameter("sun_col", sun.light_color * sun.light_energy)
	for k in _wakes.keys():
		var wk: Wake = _wakes[k]
		if t - wk.seen > Wake.LIFE:
			wk.mi.queue_free()
			_wakes.erase(k)
	for p in _patches:
		if p[0].visible and t > float(p[1]):
			p[0].visible = false


# --- the swell ---------------------------------------------------------------------

## GLSL for the waves (see WAVES). gerst(p, t, n): where the water laid at p
## has gone (x, height, z) under the first `moving` waves, with n the sums its
## normal is made of (n.xz its slope, n.y how far the crests have bunched it);
## ripples(p, t): the slope of the rest; gerst_h(x, t): the height of the
## water at x (one step back to where it was laid). `sea` scales each group.
func waves_glsl(moving: int) -> String:
	var g := "vec3 gerst(vec2 p, float t, out vec3 n) { vec3 d = vec3(0.0); n = vec3(0.0); float a; float c; float s;"
	var f := "vec2 ripples(vec2 p, float t) { vec2 r = vec2(0.0); float a;"
	for i in _waves.size():
		var w: Array = _waves[i]
		var d: Vector2 = w[0]
		var k: float = w[1]
		var amp: float = w[3]
		var grp := "sea.x" if int(w[5]) == 0 else "sea.y"
		var ph := " a = %.6f * p.x + %.6f * p.y - %.6f * t + %.3f;" % [k * d.x, k * d.y, float(w[2]), float(w[4])]
		if i < moving:
			var b := _q * amp
			g += ph + " c = cos(a) * %s; s = sin(a) * %s;" % [grp, grp]
			g += " d += vec3(%.5f * c, %.5f * s, %.5f * c);" % [b * d.x, amp, b * d.y]
			g += " n += vec3(%.6f * c, %.6f * s, %.6f * c);" % [k * amp * d.x, k * b, k * amp * d.y]
		else:
			f += ph + " r += vec2(%.6f, %.6f) * cos(a) * %s;" % [k * amp * d.x, k * amp * d.y, grp]
	var h := "float gerst_h(vec2 x, float t) { vec3 n; vec3 d = gerst(x, t, n); return gerst(x - d.xz, t, n).y; }"
	# (how far the waves have built up at p, out from the beach: see OFFSHORE)
	h += " float offshore(vec2 p) { if (coast.z < 0.5) { return 1.0; } float s = coast.y;"
	h += " float into = p.x - (coast.x + 22.0 * sin(p.y * 0.0105 + s) + 9.0 * sin(p.y * 0.031 + s * 2.3) + 4.0 * sin(p.y * 0.077 + s * 0.7));"
	h += " return smoothstep(OFFSHORE.x, OFFSHORE.y, into); }"
	var wind := Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	var c := "const float SURF_L = %.2f; const float SURF_C = %.2f; const float SURF_H = %.3f; const float SURGE = %.3f; const vec2 WIND = vec2(%.4f, %.4f); const vec2 OFFSHORE = vec2(%.1f, %.1f);" % [SURF_L, SURF_C, SURF_H, SURGE, wind.x, wind.y, OFFSHORE.x, OFFSHORE.y]
	return c + " " + g + " return d; } " + f + " return r; } " + h


## How far the waves have lifted (or dropped) the water at p just now: 0 off
## the sea, and dying away in the shallows. (A couple of steps back to the
## water that has come to be at p, as gerst_h in the shaders.)
func height_at(p: Vector3) -> float:
	if _mask == null:
		return 0.0
	var k := 0.0
	if absf(p.x) >= MapDims.HALF or absf(p.z) >= MapDims.HALF:
		k = 1.0 if p.x > _sea_x else 0.0
	else:
		var c := _mask.get_pixel(int(p.x + MapDims.HALF), int(p.z + MapDims.HALF))
		k = c.b * smoothstep(0.06, 0.55, c.r)
	if k > 0.0 and water and not water.coast.is_empty():
		k *= smoothstep(OFFSHORE.x, OFFSHORE.y, p.x - water.coast_x(p.z))
	if k <= 0.0:
		return 0.0
	var x0 := p.x
	var z0 := p.z
	for it in 2:
		var ox := 0.0
		var oz := 0.0
		for j in range(0, _wf.size(), 8):
			var c := cos(_wf[j] * x0 + _wf[j + 1] * z0 - _wf[j + 4] * t + _wf[j + 5]) * _wf[j + 7]
			ox += _wf[j + 2] * c
			oz += _wf[j + 3] * c
		x0 = p.x - ox
		z0 = p.z - oz
	var h := 0.0
	for j in range(0, _wf.size(), 8):
		h += _wf[j + 6] * sin(_wf[j] * x0 + _wf[j + 1] * z0 - _wf[j + 4] * t + _wf[j + 5])
	return h * k


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
## more the flatter you look across it. The sun's glitter is in light() (in
## fragment() where the lighting is per vertex: the browser build). WQ is the
## Water quality: Low (0) draws no see-through water, which saves copying the
## screen every frame; High (2) and Ultra (3) add the light the ripples focus
## on the bed and the wind's streaks of foam in a blow.
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, ambient_light_disabled;

#define WQ __WQ__

global uniform float water_time;
uniform bool terrain_reflections = false;
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D chop_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
#if WQ >= 1
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// (only ever read at full size: no mipmaps of the screen to make each frame)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
#endif
#if WQ >= 2
uniform sampler2D caustic_tex : filter_linear_mipmap, repeat_enable;
#endif
// a depth read back to clip space: OpenGL's (the browser build's) runs -1..1, Vulkan's 0..1
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif
uniform float sea_x = 1e9;
uniform vec3 coast = vec3(0.0);  // the shoreline's mean x, its seed, 1 if there's a sea
uniform vec2 sea = vec2(0.85, 0.6);  // how big the swell and the wind sea run (WaterView.SEA_STATE)
uniform vec3 zenith : source_color = vec3(0.22, 0.42, 0.74);
uniform vec3 horizon : source_color = vec3(0.68, 0.76, 0.84);
uniform float clouds = 0.55;
uniform float ambient = 0.55;
uniform float sun_k = 1.0;  // how sharp the sun is on the water (a blur under cloud)
uniform float rain = 0.0;
// the sun, for the glitter where the lighting is per vertex
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col = vec3(1.0);
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
varying vec2 gp;  // where this water lies at rest (the waves are worked out from there)
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

// a breaker rising as the water shoals under it, steepest just before it spills
float surf_hump(vec2 p, float into) {
	float s = surf_phase(p, into);
	return pow(smoothstep(0.55, 1.0, s), 2.5) * smoothstep(20.0, 7.0, into) * smoothstep(-1.0, 3.0, into);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	gp = wpos.xz;
	vec4 m = wmask(gp);
	// the waves out at sea, building up away from the beach (in nearer the surf
	// takes over; still on rivers and ponds)
	float into = coast.z > 0.5 ? coast_into(gp) : 1e4;
	swell_k = m.b * smoothstep(0.06, 0.55, m.r) * smoothstep(OFFSHORE.x, OFFSHORE.y, into);
	vec3 n;
	vec3 d = gerst(gp, water_time, n) * swell_k;
	if (coast.z > 0.5 && m.b > 0.5) {
		d.y += surge_at(gp, into) * SURGE + surf_hump(gp, into) * SURF_H * sea.x;
	}
	VERTEX += d;
	wpos += d;
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
	float salt = m.b;
	float into = coast.z > 0.5 ? coast_into(p) : 1e4;
#if WQ >= 1
	// (on the sea's beach the surf may run up over the sand)
	if (m.a < 0.5 && !(salt > 0.5 && into > -12.0)) {
		discard;
	}
#else
	if (m.a < 0.5) {
		discard;
	}
#endif
	float dist = length(VERTEX);
	float far = smoothstep(80.0, 360.0, dist);
	// the surface: the waves, the short ones on them, the wind's chop on those
	// (rougher in the gusts that darken patches of the water)
	vec3 gn;
	gerst(gp, water_time, gn);
	gn *= swell_k;
	float bunch = gn.y;  // how far the crests have bunched the water: where it breaks
	// (the slopes drawn steeper than they are, so the waves read from above)
	vec2 g = gn.xz * 2.6 + ripples(gp, water_time) * swell_k * 1.5;
	if (coast.z > 0.5 && salt > 0.5) {
		// the faces of the breakers coming in
		g.x += (surf_hump(p + vec2(0.4, 0.0), into + 0.4) - surf_hump(p - vec2(0.4, 0.0), into - 0.4)) * 1.25 * SURF_H * sea.x * 1.5;
	}
	vec2 flow = mix(vec2(0.0, 0.55), WIND * 0.3, salt);  // the rivers run south; the chop runs with the wind
	float gust = texture(detail_tex, p / 260.0 + vec2(water_time * 0.0035, water_time * 0.001)).r;
	vec2 c1 = texture(chop_tex, p / 12.0 + flow * water_time * 0.045).xy * 2.0 - 1.0;
#if WQ >= 1
	vec2 c2 = texture(chop_tex, p / 4.7 + vec2(0.31, 0.17) - flow.yx * water_time * 0.08).xy * 2.0 - 1.0;
#else
	vec2 c2 = vec2(0.0);
#endif
	// (the chop is the wind sea's own: it gets up with it in a blow; the fine
	// ripples fade out with distance, before they shimmer)
	float chop = mix(0.2, 0.34, salt) * mix(0.55, 1.45, smoothstep(0.3, 0.75, gust)) * mix(1.0, 0.45 + 0.75 * sea.y, salt);
	vec2 gs = g;
	g += (c1 * 0.6 * (1.0 - far * 0.7) + c2 * 0.4 * (1.0 - smoothstep(25.0, 150.0, dist))) * chop * 1.5;
#if WQ >= 1
	if (rain > 0.0) {
		// rain: every drop a ring spreading out and dying away
		g += (drops(p, 0.0) + drops(p * 1.37 + 0.5, 0.5)) * rain * 1.5 * (1.0 - smoothstep(20.0, 90.0, dist));
	}
#endif
	// (bunched up on the crests, spread out in the troughs)
	float up = max(1.0 - bunch, 0.25);
	vec3 n = normalize(vec3(-g.x, up, -g.y));
	vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// how much sky it reflects, by the broader slopes (by every ripple it sparkles)
	vec3 ns = normalize(vec3(-(gs.x + c1.x * chop * 0.6), up, -(gs.y + c1.y * chop * 0.6)));
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(ns, eye), 0.0, 1.0), 5.0);
#if WQ >= 1
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
#else
	// (Low: the depth from the map, the bed showing through as the water's laid over it)
	float rthick = m.r * 3.0 / max(eye.y, 0.35);
	float thick = rthick;
#endif
	// (the open sea runs deeper than the few metres carved into the map:
	// darker the farther out)
	float depth = rthick + salt * clamp(into - 20.0, 0.0, 90.0) * 0.2;
	vec3 tr = exp(-mix(fresh_absorb, sea_absorb, salt) * depth);
#if WQ >= 2
	// the light the ripples focus onto the bed, dancing in the shallows
	float ca = texture(caustic_tex, p / 6.5 + vec2(water_time * 0.023, water_time * 0.011)).r;
	float cb = texture(caustic_tex, p / 4.9 - vec2(water_time * 0.017, -water_time * 0.02)).r;
	float caus = pow(1.0 - smoothstep(0.0, 0.2, ca), 3.0) + pow(1.0 - smoothstep(0.0, 0.2, cb), 3.0);
	bed *= 1.0 + caus * 1.1 * sun_k * (1.0 - smoothstep(0.4, 4.0, rthick)) * (1.0 - far);
#endif
	// the breakers: a white front with foam trailing behind it, sand stirred up
	float surf = 0.0;
	float zone = 0.0;
	if (coast.z > 0.5 && salt > 0.5) {
		float run = surf_run(p, into);
		float s = fract(run);
		zone = smoothstep(17.0, 9.0, into) * smoothstep(-10.0, -1.0, into);
		// each breaker spills unevenly along its length, here white, there hardly at all
		float wob = texture(detail_tex, vec2(p.y / 45.0, floor(run) * 0.31)).r;
		float strength = mix(0.6, 1.0, smoothstep(0.2, 0.8, wob)) * mix(0.7, 1.15, smoothstep(0.4, 1.2, sea.x));
		surf = (smoothstep(0.0, 0.03, s) * exp(-s * 4.5) * 0.62 + exp(-s * 2.6) * 0.14) * strength * zone;
		surf *= mix(0.65, 1.0, smoothstep(-4.0, 1.0, into));  // (thinning as it runs up the sand)
	}
	vec3 tint = mix(fresh_tint, mix(shoal_tint, sea_tint, smoothstep(1.0, 7.0, depth)), salt);
	tint = mix(tint, surf_tint, zone * 0.4);
	// foam: a line wherever the water meets something (the bank, a hull, a
	// pile), the breakers, whitecaps where the crests bunch up enough to break
	float l = lace(p);
#if WQ >= 1
	// (on the beach the surf's film is thin all over: only its very edge froths)
	float cw = mix(0.14, mix(0.05, 0.3, smoothstep(2.0, 8.0, into)), salt);
	float contact = (1.0 - smoothstep(0.0, cw, thick)) * mix(0.55, mix(0.5, 0.85, smoothstep(2.0, 8.0, into)), salt);
#else
	float contact = (1.0 - smoothstep(0.0, 0.05, m.r)) * 0.7;
#endif
	// (whitecaps: flecks the wind tears off the tops of the waves, more in the gusts)
	float fleck = smoothstep(0.5, 0.75, texture(foam_tex, p / 9.0 + WIND * water_time * 0.08).r);
	float caps = smoothstep(0.3, 0.58, bunch) * mix(0.45, 1.0, smoothstep(0.4, 0.8, gust)) * fleck;
#if WQ >= 2
	// in a blow, streaks of foam laid out down the wind
	vec2 wf = vec2(dot(p, WIND), dot(p, vec2(-WIND.y, WIND.x)));
	float streak = smoothstep(0.6, 0.85, texture(foam_tex, vec2(wf.x * 0.012 - water_time * 0.01, wf.y * 0.35)).r);
	caps += streak * smoothstep(0.75, 1.15, sea.y) * swell_k * 0.55;
#endif
	float amt = clamp(contact + surf + caps, 0.0, 1.0);
	// (seen from afar the lace blurs to grey: thresholding that would break the
	// foam into blocks, so it gives way to a soft wash of white)
	float blur = smoothstep(0.04, 0.2, length(fwidth(p)));
	float foam = mix(foam_of(amt, l), amt * amt * 0.7, blur);
	// the sky in it, and its clouds (mostly as the broad slopes of the waves
	// turn it, so a swell shows as long bands of light; the ripples sparkle)
	vec3 rr = reflect(-eye, n);
	vec3 rb = reflect(-eye, normalize(mix(n, ns, 0.6)));
	vec3 r = vec3(rb.x, abs(rb.y), rb.z);
	vec3 sky = mix(horizon, zenith, pow(r.y, 0.5));
	vec2 cuv = r.xz / (r.y + 0.18) * 0.09 + vec2(water_time * 0.0015, water_time * 0.0007);
	float cl = smoothstep(1.0 - clouds - 0.15, 1.0 - clouds + 0.35, texture(detail_tex, cuv).r) * smoothstep(0.0, 0.2, r.y);
	sky = mix(sky, mix(horizon * 0.95, vec3(1.0), 0.55), cl * 0.8);
	if (terrain_reflections) { sky = vec3(0.0); }
	SPECULAR = terrain_reflections ? 0.25 : 0.0;
	vec3 amb = terrain_reflections ? vec3(0.0) : mix(horizon, zenith, 0.5) * ambient;
#if WQ >= 1
	vec3 scatter = tint * (1.0 - tr);
	ALBEDO = mix(scatter * (1.0 - fres), foam_col, foam);
	EMISSION = ((bed * tr + scatter * amb) * (1.0 - fres) + sky * fres) * (1.0 - foam) + foam_col * amb * foam * 0.6;
	// (soft where it laps the bank)
	ALPHA = clamp(smoothstep(0.0, 0.05, thick) + foam, 0.0, 1.0);
#else
	// (laid over the bed: the deeper, the less of it shows through)
	ALBEDO = mix(tint * (1.0 - fres), foam_col, foam);
	EMISSION = (tint * amb * 0.5 * (1.0 - fres) + sky * fres) * (1.0 - foam) + foam_col * amb * foam * 0.6;
	ALPHA = clamp(mix(0.4, 0.95, smoothstep(0.0, 4.0, depth)) + fres * 0.3 + foam, 0.0, 1.0);
#endif
	ROUGHNESS = mix(0.05, 0.6, foam);
	NORMAL = normalize(mix((VIEW_MATRIX * vec4(n, 0.0)).xyz, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, foam * 0.7));
	glint = (1.0 - foam) * mix(0.3, 1.0, fres) * sun_k;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// (lit per vertex there, which would lose every glint: the sun's glitter
	// is worked out here instead, for each pixel)
	float sd = clamp(dot(rr, sun_dir), 0.0, 1.0);
	EMISSION += sun_col * (pow(sd, 1400.0) * 4.0 + pow(sd, 160.0) * 0.16 + pow(sd, 20.0) * 0.012) * glint;
#endif
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	// the sun on the water: a hard glitter off every ripple facing it, a broad sheen round it
	float nh = clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0);
	float sp = pow(nh, 1600.0) * 9.0 + pow(nh, 220.0) * 0.25 + pow(nh, 30.0) * 0.025;
	SPECULAR_LIGHT += sp * glint * ATTENUATION * LIGHT_COLOR;
#endif
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
uniform vec2 sea = vec2(0.85, 0.6);
uniform vec3 coast = vec3(0.0);

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
	wp.y = __LEVEL__ + gerst_h(wp.xz, water_time) * m.b * smoothstep(0.06, 0.55, m.r) * offshore(wp.xz) + 0.02;
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
uniform vec2 sea = vec2(0.85, 0.6);
uniform vec3 coast = vec3(0.0);
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
	wp.y = __LEVEL__ + gerst_h(wp.xz, water_time) * m.b * smoothstep(0.06, 0.55, m.r) * offshore(wp.xz) + 0.02;
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
