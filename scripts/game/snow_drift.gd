class_name SnowDrift
extends Node3D
## Snow drifted against walls, buildings and hedges, in the snow weather. The
## wind (Fires.WIND) scours the snow off the open and drops it where the air
## behind an obstacle goes slack: a drift banked against the lee face, rising
## to a rounded crest a little way out and tailing off over a few metres
## downwind (farther behind a tall wall than a low one, and farther still
## behind a hedge or a fence, which the wind half passes through), with a
## smaller bank against the windward face.
## Looks only: nothing here reaches the simulation.
##
## Every view works the drifts out for itself from the structures standing,
## which are replicated, so every peer gets the same ones (as with the water
## and the scar map): each obstacle stamps its drift into a map, CELL metres a
## texel, by looking upwind and downwind from each texel for its footprint.
## Nothing drifts inside a roofed house. A wall knocked down takes its drift
## with it (the area is stamped afresh), and a thaw (SnowMelt) or a shell's
## scorch on the ground (the grass's scar map) clears it where it lies.
##
## The drifts are drawn as raised snow laid over the ground in TILE-metre
## tiles wherever the map has any (DRIFT_SHADER, the terrain's own height read
## from its deformation map, so they ride shell holes and slopes), and the
## grass in a drift is buried (Grass.GRASS_SHADER reads the same map).

## Metres a texel: one on the usual map; two on the bigger battlefields,
## where a metre's map would be four or nine times the memory and stamping.
static var CELL := 1.0
const TILE := 32.0  # m: a drift mesh tile
const REGION := 256.0  # m: tiles are drawn in batches this size, each culled on its own
const CHECK := 1.0  # s between looks at what's standing
const BUDGET_US := 3000  # stamping per frame (the first look stamps the whole map over a few frames)
## How much of a drift each kind of obstacle catches (a hedge: see _kind).
const KINDS := {"house_wall": 1.0, "tall_wall": 1.0, "concrete_wall": 1.0, "low_wall": 0.8, "fence": 0.6,
	"sandbags": 0.65, "barricade": 0.7, "barracks": 1.0, "factory": 1.0, "research": 1.0, "fob": 0.9, "depot": 0.9,
	"wreck": 0.6, "car": 0.5, "crates": 0.45, "rubble": 0.4}
## Thin obstacles have their foot filled (the drift reaches the wall); a building's
## inside is the building.
const THIN := ["house_wall", "tall_wall", "concrete_wall", "low_wall", "fence", "sandbags", "barricade"]
const WIND := Vector2(0.924, 0.382)  # (Fires.WIND, flat and normalised)

var atmo  # Atmosphere
var n := 0  # texels across the map
var data := PackedByteArray()
var roofed := PackedInt32Array()  # roof count per texel: overlapping roofs stay covered
var img: Image
var tex: ImageTexture
var _obst := {}  # eid -> drift spec (see _spec)
var _sig := {}  # eid -> what it was last look (position, yaw, size), to skip the unchanged
var _roofs := {}  # eid -> roof spec
var _by_tile := {}  # Vector2i (TILE) -> {eid: spec}: the obstacles stamping there
var _stamp: Array = []  # specs to stamp
var _clear: Array = []  # Rect2i (texels) to clear and stamp afresh
var _dirty_tiles := {}  # Vector2i -> true
var _regions := {}  # Vector2i (REGION) -> MultiMeshInstance3D
var _tiles := {}  # Vector2i -> true: tiles with drift
var _t := 0.0
var _changed := false
var _mesh: PlaneMesh
var _mat: ShaderMaterial


func setup(a) -> void:
	atmo = a
	CELL = 1.0 if MapDims.SIZE <= 1100.0 else 2.0
	n = int(round(MapDims.SIZE / CELL))
	data.resize(n * n)
	roofed.resize(n * n)
	img = Image.create_from_data(n, n, false, Image.FORMAT_R8, data)
	tex = ImageTexture.create_from_image(img)
	_mesh = PlaneMesh.new()
	_mesh.size = Vector2(TILE, TILE)
	_mesh.subdivide_width = int(TILE) - 1
	_mesh.subdivide_depth = int(TILE) - 1
	_mat = ShaderMaterial.new()
	_mat.shader = CloudShadow.make(MapDims.shader(DRIFT_SHADER), CloudShadow.NO_SPECULAR)
	_mat.set_shader_parameter("drift_tex", tex)
	_mat.set_shader_parameter("deform_tex", atmo.deform_tex)
	_mat.set_shader_parameter("detail_tex", atmo.ground_mat.get_shader_parameter("detail_tex"))
	_mat.set_shader_parameter("material_colors", atmo.ground_mat.get_shader_parameter("material_colors"))
	if atmo.grass:
		_mat.set_shader_parameter("scar", atmo.grass.scar_tex)
		atmo.grass.set_drift(tex)


## Each view frame while snow lies.
func tick(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = CHECK
		_look()
	_work()


## What's standing now against what was: new obstacles stamp, gone or moved
## ones clear their ground and have it stamped afresh.
func _look() -> void:
	var seen := {}
	var roofs := {}
	for st in atmo.world.structures:
		if not is_instance_valid(st) or st.gone or not st.built:
			continue
		if st.skind == "roof":
			roofs[st.eid] = true
			var roof := _spec(st, 0.0)
			if not _roofs.has(st.eid):
				_roofs[st.eid] = roof
				_cover(roof)
			elif not _same(_roofs[st.eid], roof):
				var previous: Array = _roofs[st.eid]
				_uncover(previous)
				_clear.append(previous[9])
				_roofs[st.eid] = roof
				_cover(roof)
			continue
		var k := _kind(st)
		if k <= 0.0:
			continue
		seen[st.eid] = true
		var sig := Vector4(st.position.x, st.position.z, st.yaw, st.foot.x * 1000.0 + st.foot.y + k * 0.001)
		if _sig.get(st.eid, Vector4.INF) == sig:
			continue
		_sig[st.eid] = sig
		var sp := _spec(st, k)
		var was: Array = _obst.get(st.eid, [])
		if was.is_empty():
			_obst[st.eid] = sp
			_stamp.append(sp)
			_file(sp, true)
		elif not _same(was, sp):
			_obst[st.eid] = sp
			_file(was, false)
			_file(sp, true)
			_clear.append(was[9])
			_clear.append(sp[9])
	for eid in _obst.keys():
		if not seen.has(eid):
			var sp: Array = _obst[eid]
			_obst.erase(eid)
			_sig.erase(eid)
			_file(sp, false)
			_clear.append(sp[9])
	for eid in _roofs.keys():
		if not roofs.has(eid):
			var sp: Array = _roofs[eid]
			_roofs.erase(eid)
			_uncover(sp)
			_clear.append(sp[9])


## How much of a drift `st` catches (0: none).
func _kind(st) -> float:
	if st.skind == "low_wall" and int(st.variant) % 3 == 1:
		return 1.0  # a hedge: thick, and the snow sifts into it
	return float(KINDS.get(st.skind, 0.0))


## [x, z, cos yaw, sin yaw, half x, half z, catch, reach, thin, Rect2i of texels, reach upwind, eid]
func _spec(st, k: float) -> Array:
	var h := minf(4.0, float(st._vis_height()))
	var porous: bool = st.skind == "fence" or (st.skind == "low_wall" and int(st.variant) % 3 == 1)
	# (a garden wall or a hedge drifts out a long way for its height; behind a
	# house the eddy is short and steep for its size)
	var reach := clampf(2.0 + 2.2 * h, 3.0, 10.0) * (1.35 if porous else 1.0)
	if h > 2.0:
		reach = clampf(2.5 + 1.1 * h, 3.0, 6.5)
	var back := minf(2.0, reach * 0.3)
	var c := cos(float(st.yaw))
	var s := sin(float(st.yaw))
	var hx: float = maxf(0.15, st.foot.x)
	var hz: float = maxf(0.15, st.foot.y)
	var p: Vector3 = st.position
	# the texels it can reach: its footprint's corners, carried downwind and upwind
	var lo := Vector2(INF, INF)
	var hi := -lo
	for corner in [Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
		var w := Vector2(p.x + corner.x * c + corner.y * s, p.z - corner.x * s + corner.y * c)
		for q in [w + WIND * reach, w - WIND * back, w]:
			lo = lo.min(q)
			hi = hi.max(q)
	var half := MapDims.HALF
	var a := Vector2i(clampi(floori((lo.x + half) / CELL) - 1, 0, n - 1), clampi(floori((lo.y + half) / CELL) - 1, 0, n - 1))
	var b := Vector2i(clampi(ceili((hi.x + half) / CELL) + 1, 0, n - 1), clampi(ceili((hi.y + half) / CELL) + 1, 0, n - 1))
	return [p.x, p.z, c, s, hx, hz, k, reach, st.skind in THIN, Rect2i(a, b - a + Vector2i.ONE), back, int(st.eid)]


func _same(a: Array, b: Array) -> bool:
	for i in 9:
		if absf(float(a[i]) - float(b[i])) > 0.01:
			return false
	return true


## Lists (or unlists) an obstacle under the tiles it stamps.
func _file(sp: Array, on: bool) -> void:
	var r: Rect2i = sp[9]
	var t0 := _tile_of(r.position)
	var t1 := _tile_of(r.end - Vector2i.ONE)
	var key: int = sp[11]
	for tz in range(t0.y, t1.y + 1):
		for tx in range(t0.x, t1.x + 1):
			var t := Vector2i(tx, tz)
			if on:
				if not _by_tile.has(t):
					_by_tile[t] = {}
				_by_tile[t][key] = sp
			elif _by_tile.has(t):
				(_by_tile[t] as Dictionary).erase(key)


func _tile_of(texel: Vector2i) -> Vector2i:
	var per := int(TILE / CELL)
	return Vector2i(texel.x / per, texel.y / per)


## Marks a roof's footprint: nothing drifts under it.
func _cover(sp: Array) -> void:
	_mark_roof(sp, 1)
	_clear.append(sp[9])


func _uncover(sp: Array) -> void:
	_mark_roof(sp, -1)


func _mark_roof(sp: Array, v: int) -> void:
	var r: Rect2i = sp[9]
	var half := MapDims.HALF
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var dx := (x + 0.5) * CELL - half - float(sp[0])
			var dz := (z + 0.5) * CELL - half - float(sp[1])
			var lx := dx * float(sp[2]) - dz * float(sp[3])
			var lz := dx * float(sp[3]) + dz * float(sp[2])
			if absf(lx) <= float(sp[4]) and absf(lz) <= float(sp[5]):
				roofed[z * n + x] = maxi(0, roofed[z * n + x] + v)


## Stamps and clears within the frame's budget.
func _work() -> void:
	if _stamp.is_empty() and _clear.is_empty():
		if _changed:
			_changed = false
			img.set_data(n, n, false, Image.FORMAT_R8, data)
			tex.update(img)
			_retile()
		return
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < BUDGET_US:
		if not _clear.is_empty():
			var r: Rect2i = _clear.pop_back()
			for z in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					data[z * n + x] = 0
			var near := {}
			var a := _tile_of(r.position)
			var b := _tile_of(r.end - Vector2i.ONE)
			for tz in range(a.y, b.y + 1):
				for tx in range(a.x, b.x + 1):
					for sp in (_by_tile.get(Vector2i(tx, tz), {}) as Dictionary).values():
						near[sp[11]] = sp
			for sp in near.values():
				stamp(sp, r)
			_mark_tiles(r)
		elif not _stamp.is_empty():
			var sp: Array = _stamp.pop_back()
			# A removed or moved obstacle may still be waiting behind the clears.
			if not _obst.has(sp[11]) or _obst[sp[11]] != sp:
				continue
			stamp(sp, sp[9])
			_mark_tiles(sp[9])
		else:
			break
		_changed = true


## Stamps the drift of the obstacle `sp` into the texels of `r` (max-combined).
func stamp(sp: Array, r: Rect2i) -> void:
	var box: Rect2i = (sp[9] as Rect2i).intersection(r)
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var cx := float(sp[0])
	var cz := float(sp[1])
	var c := float(sp[2])
	var s := float(sp[3])
	var hx := float(sp[4]) + 0.3
	var hz := float(sp[5]) + 0.3
	var k := float(sp[6])
	var reach := float(sp[7])
	var thin: bool = sp[8]
	var back := float(sp[10])
	# the wind in the obstacle's own frame
	var wx := WIND.x * c - WIND.y * s
	var wz := WIND.x * s + WIND.y * c
	var half := MapDims.HALF
	for z in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var i := z * n + x
			if roofed[i] != 0:
				continue
			var dx := (x + 0.5) * CELL - half - cx
			var dz := (z + 0.5) * CELL - half - cz
			var v := drift_at(dx * c - dz * s, dx * s + dz * c, wx, wz, hx, hz, reach, back, thin) * k
			if v > 0.0:
				var b := int(v * 255.0)
				if b > data[i]:
					data[i] = b


## How deep the drift is at (lx, lz) in an obstacle's frame (half extents hx,
## hz, the wind (wx, wz) in that frame): looking upwind for the obstacle, the
## nearer it is the deeper the drift in its lee, out to `reach`; looking
## downwind, a smaller bank against its windward face, out to `back`. 1 at the
## foot of a thin wall, 0 inside a building.
static func drift_at(lx: float, lz: float, wx: float, wz: float, hx: float, hz: float, reach: float, back: float, thin: bool) -> float:
	if absf(lx) <= hx and absf(lz) <= hz:
		return 0.6 if thin else 0.0
	var lee := _hit(lx, lz, -wx, -wz, hx, hz, reach)
	var v := 0.0
	if lee >= 0.0:
		# (banked against the wall, a rounded crest a fifth of the way out where
		# the eddy behind it drops the most, then a long tail feathering out)
		var u := lee / reach
		v = (0.55 + 0.45 * smoothstep(0.0, 0.22, u)) * (1.0 - smoothstep(0.22, 1.0, u))
	var face := _hit(lx, lz, wx, wz, hx, hz, back)
	if face >= 0.0:
		v = maxf(v, 0.5 * (1.0 - smoothstep(0.0, 1.0, face / back)))
	return v


## Where a ray from (px, pz) along (dx, dz) first meets the box (half extents
## hx, hz), if within `far`; -1 if it doesn't.
static func _hit(px: float, pz: float, dx: float, dz: float, hx: float, hz: float, far: float) -> float:
	var t0 := 0.0
	var t1 := far
	for axis in 2:
		var p := px if axis == 0 else pz
		var d := dx if axis == 0 else dz
		var h := hx if axis == 0 else hz
		if absf(d) < 0.0001:
			if absf(p) > h:
				return -1.0
			continue
		var a := (-h - p) / d
		var b := (h - p) / d
		if a > b:
			var tmp := a
			a = b
			b = tmp
		t0 = maxf(t0, a)
		t1 = minf(t1, b)
		if t0 > t1:
			return -1.0
	return t0


func _mark_tiles(r: Rect2i) -> void:
	var a := _tile_of(r.position)
	var b := _tile_of(r.end - Vector2i.ONE)
	for tz in range(a.y, b.y + 1):
		for tx in range(a.x, b.x + 1):
			_dirty_tiles[Vector2i(tx, tz)] = true


## Lays drift meshes over the tiles that have drift now, and takes them off
## the ones that haven't.
func _retile() -> void:
	if _dirty_tiles.is_empty():
		return
	var per := int(TILE / CELL)
	var regions := {}
	for t: Vector2i in _dirty_tiles:
		var any := false
		for z in range(t.y * per, mini(n, (t.y + 1) * per)):
			for x in range(t.x * per, mini(n, (t.x + 1) * per)):
				if data[z * n + x] > 12:
					any = true
					break
			if any:
				break
		if any:
			_tiles[t] = true
		else:
			_tiles.erase(t)
		regions[_region_of(t)] = true
	_dirty_tiles.clear()
	for rg: Vector2i in regions:
		_build_region(rg)


func _region_of(t: Vector2i) -> Vector2i:
	var per := int(REGION / TILE)
	return Vector2i(floori(float(t.x) / per), floori(float(t.y) / per))


func _build_region(rg: Vector2i) -> void:
	var per := int(REGION / TILE)
	var xf: Array[Transform3D] = []
	var low := INF
	var high := -INF
	for tz in range(rg.y * per, (rg.y + 1) * per):
		for tx in range(rg.x * per, (rg.x + 1) * per):
			if not _tiles.has(Vector2i(tx, tz)):
				continue
			var centre := Vector3(tx * TILE - MapDims.HALF + TILE * 0.5, 0.0, tz * TILE - MapDims.HALF + TILE * 0.5)
			xf.append(Transform3D(Basis.IDENTITY, centre))
			for o in [Vector3.ZERO, Vector3(-16, 0, -16), Vector3(16, 0, -16), Vector3(-16, 0, 16), Vector3(16, 0, 16)]:
				var y: float = atmo.world.terrain.deform_at(centre + o)
				low = minf(low, y)
				high = maxf(high, y)
	var mi: MultiMeshInstance3D = _regions.get(rg)
	if xf.is_empty():
		if mi:
			mi.queue_free()
			_regions.erase(rg)
		return
	if mi == null:
		mi = MultiMeshInstance3D.new()
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_regions[rg] = mi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	# (the tiles ride the terrain in the shader: bounds from its heights here)
	var bounds := mm.get_aabb()
	bounds.position.y = low - 10.0
	bounds.size.y = high - low + 20.0
	mm.custom_aabb = bounds
	mi.multimesh = mm


const DRIFT_SHADER := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D drift_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D scar : hint_default_black, filter_linear, repeat_disable;
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray material_colors : source_color, filter_linear_mipmap_anisotropic, repeat_enable;  // (the ground's: its snow powder is layer 3)
global uniform float snow_cover;  // how deep the snow weather lies (Atmosphere._snow_tick)
// TERRAIN_TEXTURE_HELPER
// CLOUD_SHADOW
""" + SnowLie.GLSL + """
varying vec3 wpos;
varying float deep;
varying float hollow;  // (the foot of the drift, where it meets the wall, in the shade of the crest)

// How deep the drift is at p: the drift map, deeper along some stretches of
// it than others as the gusts laid it, and gone where a thaw (SnowMelt) or a
// scorch has cleared the ground (the grass's scar map), as the snow lies now.
float drift_deep(vec2 p) {
	vec2 uv = (p + __MAP_HALF__) / __MAP_SIZE__;
	vec2 marks = textureLod(scar, uv, 0.0).rg;
	float gusts = mix(0.6, 1.15, textureLod(detail_tex, p / 11.0 + 0.47, 0.0).r);
	// (gone by the slush at a thaw's rim, as the ground's snow is)
	return min(1.0, textureLod(drift_tex, uv, 0.0).r * gusts) * snow_cover * (1.0 - smoothstep(0.1, 0.45, marks.g)) * (1.0 - marks.r);
}

float drift_top(vec2 p) {
	float d = drift_deep(p);
	// The thin skirt sinks into the terrain instead of floating above it.
	// Keep the full lee crest; only the outer few centimetres are recessed.
	float rise = d * d * (3.0 - 2.0 * d) * 0.55;
	float skirt = 0.045 * (1.0 - smoothstep(0.0, 0.3, d));
	return terrain_height(deform_tex, (p + __MAP_HALF__) / __MAP_SIZE__) + rise - skirt;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	deep = drift_deep(wpos.xz);
	float y = drift_top(wpos.xz);
	float xp = drift_top(wpos.xz + vec2(1.0, 0.0));
	float xn = drift_top(wpos.xz - vec2(1.0, 0.0));
	float zp = drift_top(wpos.xz + vec2(0.0, 1.0));
	float zn = drift_top(wpos.xz - vec2(0.0, 1.0));
	VERTEX.y = y - MODEL_MATRIX[3].y;
	wpos.y = y;
	// (its slopes a little steeper to the light than they are, so the crest
	// and the hollow behind it read under a flat winter sky)
	NORMAL = normalize(vec3(-(xp - xn) * 1.4, 2.0, -(zp - zn) * 1.4));
	hollow = clamp((xp + xn + zp + zn - 4.0 * y) * 4.0, 0.0, 1.0);
}

void fragment() {
	// Clip only empty tiles. The buried skirt makes the visible boundary,
	// so an alpha threshold cannot cut an elevated sheet across the ground.
	ALPHA = smoothstep(0.0, 0.01, deep);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// the ground's own snow (Atmosphere's ground shader: its powder scan read
	// twice and its grain softened, linear), so the two meet without a seam
	vec3 powder = texture(material_colors, vec3(wpos.xz / 2.0, 3.0)).rgb;
	vec3 other = texture(material_colors, vec3(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wpos.xz / 3.1 + 0.37, 3.0)).rgb;
	powder = mix(powder, other, smoothstep(0.35, 0.65, texture(detail_tex, wpos.xz / 13.0 + 0.61).r));
	if (OUTPUT_IS_SRGB) {
		powder = mix(powder / 12.92, pow((powder + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), powder));
	}
	float grain = min(dot(powder, vec3(0.2126, 0.7152, 0.0722)) * 2.0, 1.0);
	float macro = texture(detail_tex, wpos.xz / 190.0 + 0.19).r;
	vec3 col = vec3(0.9) * mix(1.0, grain, 0.45) * mix(vec3(0.82, 0.90, 1.0), vec3(1.0), smoothstep(-0.3, 0.6, macro));
	// (its relief shaded as the sun would light it, more than the flat winter
	// light does: the face toward the sun brighter, the slope behind the crest
	// a cool shade darker; a shade greyer in the hollow at its foot)
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_sun = normalize(snow_sun());
	// (and as dim as the ground's snow round it, which its own bakes of the
	// sky it can see and of the hills' shade take down: measured, about 0.86)
	// (none of it at the thin edge, so the drift runs out into the ground's
	// own snow with no rim)
	float body = smoothstep(0.05, 0.35, deep);
	col *= 0.86 * clamp(1.0 + (dot(wn, to_sun) - to_sun.y) * 0.9 * body, 0.75, 1.15) * (1.0 - hollow * 0.12);
	col *= mix(vec3(1.0), vec3(0.9, 0.95, 1.04), smoothstep(0.0, -0.25, dot(wn, to_sun) - to_sun.y) * body);
	if (OUTPUT_IS_SRGB) {
		col = mix(col * 12.92, 1.055 * pow(max(col, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), col));
	}
	ALBEDO = col;
	ROUGHNESS = 0.88;
	AO = 1.0 - hollow * 0.35;
	AO_LIGHT_AFFECT = 0.3;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""
