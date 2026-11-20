class_name SnowRoof
extends RefCounted
## The snow on a house's roof as a body of its own, in the snow weather: what
## the surface shader can't draw on the roof's own faces (Mats: the coat on
## the slopes, scoured on the side facing the wind, thin where it's steep,
## thawed on a warm house). Built for each roof when snow first lies on it
## (Structure._snow_roof), in the roof's own frame, and drawn by CAP_SHADER,
## which grows it as the snow settles, and melts it with the roof (its snow_k,
## and the thaws round a fire). Looks only.
##
## - Along a pitched roof's eaves, the snow that slid down the slope curls
##   over the edge in a rounded lip, showing the coat's thickness, thicker on
##   steep sheet that sheds most of it and broken where it fell; a thinner lip
##   up a gable's verges.
## - Under the eaves of a warm house, icicles in runs where the meltwater drips.
## - On a flat roof, the wind drifts it against the parapets: a deep bank in
##   the lee of the one facing the wind, a shallow one against the far one.

const WIND := Vector3(0.924, 0, 0.382)  # (Fires.WIND, flat and normalised)
## How many roofs may be dressed in one frame (a town's worth at once would hitch).
const PER_FRAME := 3

static var _mat: ShaderMaterial
static var _frame := -1
static var _count := 0


## The mesh as it's built: an indexed list, filled directly (a SurfaceTool's
## per-vertex calls cost a few milliseconds a roof).
class Build:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func quad(a: int, b: int, cc: int, d: int) -> void:
		idx.append_array(PackedInt32Array([a, b, cc, a, cc, d]))


## Whether another roof may be dressed this frame (PER_FRAME).
static func turn() -> bool:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_count = 0
	_count += 1
	return _count <= PER_FRAME


## The cap for a roof whose form its model recorded (Structure._roof_form), in
## that roof's frame (the kit's turn included), or null if there's nothing to
## draw. `heat` 0 (cold) to 1, `carry` how much this roof holds, `yaw` the
## structure's (to find the wind in the roof's frame).
static func cap(form: Dictionary, heat: float, carry: float, yaw: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var b := Build.new()
	var ang: float = form.get("ang", 0.0)
	# (the wind in the kit's frame)
	var wind := (Basis(Vector3.UP, yaw) * Basis(Vector3.UP, ang)).inverse() * WIND
	if form.get("flat", false):
		_parapets(b, form, wind, rng)
	else:
		_eaves(b, form, heat, carry, rng)
	if b.idx.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b.v
	arrays[Mesh.ARRAY_NORMAL] = b.n
	arrays[Mesh.ARRAY_COLOR] = b.c
	arrays[Mesh.ARRAY_INDEX] = b.idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A pitched roof's lips and icicles (BuildingRoofs.gable and hip's geometry).
static func _eaves(b: Build, form: Dictionary, heat: float, carry: float, rng: RandomNumberGenerator) -> void:
	var t := deg_to_rad(float(form.pitch))
	var tn := tan(t)
	var ov := 0.35
	var fz: float = form.fz
	var fx: float = maxf(float(form.fx), fz)
	var th: float = form.get("th", 0.09)
	var edge := float(form.h) - ov * tn + th / cos(t)  # the covering's top at the eave's edge
	# (a barn's cold sheet drops most of what slides off it at the eaves; a warm
	# house's has partly melted and run off as icicles)
	var r := (0.28 if form.get("barn", false) else 0.21) * clampf(carry, 0.6, 1.2) * (1.0 - heat * 0.3)
	var sides: Array = []  # [from, to, outward (horizontal)]
	if form.get("hipped", false):
		var ex := fx + ov
		var ez := fz + ov
		for q in 4:
			var o := Basis(Vector3.UP, q * PI * 0.5) * Vector3(0, 0, 1)
			var along := o.cross(Vector3.UP)
			var half := ex if q % 2 == 0 else ez
			var reach := ez if q % 2 == 0 else ex
			sides.append([o * reach - along * half + Vector3.UP * edge, o * reach + along * half + Vector3.UP * edge, o])
	else:
		var run := float(form.L) * 0.5 + ov
		var reach := fz + ov
		var ridge := float(form.h) + fz * tn + th / cos(t)
		for s: float in [-1.0, 1.0]:
			var o := Vector3(0, 0, s)
			sides.append([Vector3(-run, edge, s * reach), Vector3(run, edge, s * reach), o])
			# up the verges, a thinner lip
			for e: float in [-1.0, 1.0]:
				var n := Vector3(0, cos(t), s * sin(t))
				_roll(b, Vector3(e * run, edge, s * reach), Vector3(e * run, ridge, 0.0), Vector3(e, 0, 0), n, r * 0.45, 0.25, rng, 0.0)
	for side: Array in sides:
		var o: Vector3 = side[2]
		var n := (o * sin(t) + Vector3.UP * cos(t)).normalized()
		var d := (o * cos(t) - Vector3.UP * sin(t)).normalized()
		_roll(b, side[0], side[1], d, n, r, 0.45, rng, 1.0)
		if heat > 0.0:
			_icicles(b, side[0], side[1], o, edge - th / cos(t) - 0.12, heat, rng)


## A rounded lip of snow along a roof's edge from `a` to `e`: `d` points out
## over the edge in the slope's plane, `n` out of the slope. It lies on the
## covering `tail` metres up the slope and curls over and down past the edge.
## `breaks` how often it's broken (where some of it fell). (vertex colour red:
## 0 snow, 1 ice; green: how far round the curl, for its shading)
static func _roll(b: Build, a: Vector3, e: Vector3, d: Vector3, n: Vector3, r: float, tail: float, rng: RandomNumberGenerator, breaks: float) -> void:
	var length := a.distance_to(e)
	var along := (e - a) / maxf(length, 0.001)
	var segs := maxi(1, int(ceil(length / 0.5)))
	# the cross-section, in (d, n): from the covering up the slope, over the
	# top, round the edge and down
	var down_a := atan2(-n.y, d.y)  # (the angle pointing straight down)
	# (its tail starts a little under the covering, so the roof's own coat
	# draws where the two meet, and how far up it reaches varies)
	var section: Array[Vector2] = [Vector2(-tail, -0.03)]
	for i in 7:
		var phi := lerpf(PI * 0.5, down_a - 0.25, i / 6.0)
		section.append(Vector2(r * 0.25, 0.0) + Vector2(cos(phi), sin(phi)) * r)
	var cols := section.size()
	var normals: Array[Vector3] = []
	for i in cols:
		normals.append(_curl_normal(section, i, d, n))
	var base := b.v.size()
	for j in segs + 1:
		# how thick it is at each joint along its length (gusts, and gaps where it fell)
		var k := rng.randf_range(0.65, 1.15)
		# (where some fell it's thinner, never gone: a gap would show the dark
		# fascia through it)
		if breaks > 0.0 and rng.randf() < 0.12 * breaks and j > 0 and j < segs:
			k = rng.randf_range(0.35, 0.5)
		var at := a + along * (length * j / segs)
		var reach := rng.randf_range(0.55, 1.5)
		for i in cols:
			var q: Vector2 = section[i]
			# (scaled toward the edge: a gap closes the lip down onto it)
			b.v.append(at + (d * q.x * reach + n * q.y if i == 0 else d * q.x * k + n * (q.y * k)))
			b.n.append(normals[i])
			b.c.append(Color(0.0, float(i) / (cols - 1), 0.0))
	for j in segs:
		for i in cols - 1:
			var p := base + j * cols + i
			b.quad(p, p + cols, p + cols + 1, p + 1)


## The lip's normal at a point of its section: out from the middle of the
## curl, so it shades as a rounded roll (on the covering, straight out of it).
static func _curl_normal(section: Array[Vector2], k: int, d: Vector3, n: Vector3) -> Vector3:
	if k == 0:
		return n
	var dir := (section[k] - Vector2(section[1].x, 0.0)).normalized()
	return (d * dir.x + n * dir.y).normalized()


## Icicles under an eave from `a` to `e` (outward `o`), hanging from `y`: in
## runs where the meltwater drips off the warm roof, the longest mid-run.
static func _icicles(b: Build, a: Vector3, e: Vector3, o: Vector3, y: float, heat: float, rng: RandomNumberGenerator) -> void:
	var length := Vector2(a.x - e.x, a.z - e.z).length()
	var along := Vector3(e.x - a.x, 0, e.z - a.z) / maxf(length, 0.001)
	var x := rng.randf_range(0.1, 0.8)
	while x < length - 0.1:
		var run := rng.randf_range(0.6, 2.4) * heat
		var end := minf(length - 0.1, x + run)
		var mid := (x + end) * 0.5
		while x < end:
			var long := rng.randf_range(0.06, 0.38) * (1.0 - absf(x - mid) / maxf(run * 0.5, 0.1) * 0.6) * (0.6 + 0.4 * heat)
			var rad := rng.randf_range(0.008, 0.016)
			var top := Vector3(a.x, y, a.z) + along * x + o * (0.14 + rng.randf_range(-0.02, 0.02))
			_cone(b, top, rad, long)
			x += rng.randf_range(0.06, 0.35)
		x = end + rng.randf_range(0.8, 3.0)


static func _cone(b: Build, top: Vector3, rad: float, long: float) -> void:
	var base := b.v.size()
	for i in 4:
		var a := i * PI * 0.5 + 0.4
		var out := Vector3(cos(a), 0, sin(a))
		b.v.append(top + out * rad)
		b.n.append((out + Vector3(0, -rad / maxf(long, 0.01), 0)).normalized())
		b.c.append(Color(1.0, 0.0, 0.0))
	b.v.append(top - Vector3(0, long, 0))
	b.n.append(Vector3.DOWN)
	b.c.append(Color(1.0, 0.0, 0.0))
	for i in 4:
		b.idx.append_array(PackedInt32Array([base + i, base + (i + 1) % 4, base + 4]))


## A flat roof's drifts against its parapets (BuildingRoofs.flat: the deck's
## top 0.2 above the walls, parapets 0.18 thick inside its edge).
static func _parapets(b: Build, form: Dictionary, wind: Vector3, rng: RandomNumberGenerator) -> void:
	var L: float = form.L
	var W: float = form.W
	var deck := float(form.h) + 0.2
	var ix := L * 0.5 - 0.13
	var iz := W * 0.5 - 0.13
	var prof: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.25, 0.92), Vector2(0.55, 0.62), Vector2(0.8, 0.25), Vector2(1.0, 0.0)]
	for q in 4:
		var o := Basis(Vector3.UP, q * PI * 0.5) * Vector3(0, 0, 1)  # out through this parapet
		var into := o.dot(wind)  # (+: the wind blows out over it, so it's the far one)
		# (deep in the lee of the parapet the wind comes over, shallow against the far one)
		var deep := clampf(-into, 0.0, 1.0) * 0.38 + clampf(into, 0.0, 1.0) * 0.16
		var wide := clampf(-into, 0.0, 1.0) * 1.6 + clampf(into, 0.0, 1.0) * 0.6
		if deep < 0.06:
			continue
		var along := o.cross(Vector3.UP)
		var half := (ix if q % 2 == 0 else iz) - 0.02
		var reach := iz if q % 2 == 0 else ix
		var face := o * reach + Vector3.UP * deck
		var segs := maxi(1, int(ceil(half * 2.0)))
		var base := b.v.size()
		for j in segs + 1:
			var k := rng.randf_range(0.7, 1.15) * (smoothstep(0.0, 0.8, half - absf(-half + 2.0 * half * j / segs)) * 0.6 + 0.4)
			for i in prof.size():
				var pr: Vector2 = prof[i]
				b.v.append(face + along * (-half + 2.0 * half * j / segs) - o * (pr.x * wide * k) + Vector3.UP * (pr.y * deep * k + 0.01))
				# (the bank's slope: down and away from the parapet)
				var slope := 1.3 * deep / maxf(wide, 0.05) * (1.0 if i > 0 and i < prof.size() - 1 else 0.4)
				b.n.append((Vector3.UP - o * slope).normalized())
				b.c.append(Color(0.0, 0.0, 0.0))
		var cols := prof.size()
		for j in segs:
			for i in cols - 1:
				var p := base + j * cols + i
				b.quad(p, p + cols, p + cols + 1, p + 1)


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = CloudShadow.make(Mats.code(CAP_SHADER))
	return _mat


const CAP_SHADER := """
shader_type spatial;
render_mode cull_disabled;
global uniform float snow_cover;  // how deep the snow weather lies (Atmosphere._snow_tick)
""" + Mats.THAW_GLSL + SnowLie.GLSL + """
// (the roof's own: how much it holds, warm or not; Structure._snow_roof, melt_snow)
instance uniform vec4 snow_k = vec4(1.0, -1.0, 10000.0, 10000.0);
// CLOUD_SHADOW
varying vec3 wpos;
varying float ice;
varying float curl;

void vertex() {
	ice = COLOR.r;
	curl = COLOR.g;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// (it's there once the snow lies thick enough on the roof to slide and
	// curl; icicles once it has lain a while)
	if (snow_cover * snow_k.x < (ice > 0.5 ? 0.6 : 0.3)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// (drawn both ways, but lit by its own normals, which face
	// out: the engine flips them on the faces it sees from behind)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// (its top as soft as the roof's own coat, Mats: so the two meet without a seam)
	if (ice < 0.5) {
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.4 * (1.0 - smoothstep(0.3, 0.6, curl))));
	}
	// (melted off round a fire, as the roof's own: SnowMelt)
	if (snow_thaw_0.z > 0.0 && surface_thaw(wpos.xz, 0.0) > 0.35) {
		discard;
	}
	// (what's left of it as the roof's fire melts it: Structure.melt_snow)
	if (snow_k.x < 0.75 && snow_noise(wpos.xz * 1.7 + wpos.y) > snow_k.x * 1.2) {
		discard;
	}
	// (ice clear and bright, the light through it)
	vec3 col = ice > 0.5 ? vec3(0.78, 0.84, 0.9) : vec3(0.8, 0.83, 0.88) * (0.94 + 0.06 * snow_noise(wpos.xz * 3.0 + wpos.y * 2.0));
	// (the underside of the curl in its own shade)
	col *= ice > 0.5 ? 1.0 : mix(1.0, 0.8, smoothstep(0.6, 1.0, curl));
	if (OUTPUT_IS_SRGB) { col = pow(col, vec3(1.0 / 2.2)); }
	ALBEDO = col;
	ROUGHNESS = ice > 0.5 ? 0.25 : 0.85;
	BACKLIGHT = vec3(ice * 0.4);
	SPECULAR = ice > 0.5 ? 0.7 : 0.3;
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""
