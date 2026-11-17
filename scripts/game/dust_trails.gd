class_name DustTrails
extends Node3D
## (view) The dust a vehicle raises off a dry road, close up: a low, pale
## cloud laid along the way it went, billowing up behind it and spreading,
## drifting off downwind and settling over half a minute or so, so a column's
## route stays marked on the ground for a while after it has gone by. (Far
## off, and under the browser's renderer, the weather grid's coarse dust
## stands in; WeatherGrid.dust_of is how much each kind of ground gives.)
##
## A few fog volumes (SEGS), each a stretch of the route up to SEG_LEN long:
## a vehicle carries on the stretch it's laying, a vehicle behind it on the
## same road thickens that stretch rather than starting another, and once all
## are in use the one nearest its end is taken. Volumetric fog only; looks only.

const SEGS := 20
## The longest stretch (m) one volume covers.
const SEG_LEN := 36.0
## Seconds a stretch hangs after the last vehicle went along it.
const LIFE := 34.0

var world
var _shader: Shader
var _wisps: Texture3D
var _wind := Vector2.ONE
var _s: Array = []  # [volume, material, from, to, age, amount]
var _debug_k := float(OS.get_environment("FL_DEBUG_DUST")) if OS.has_environment("FL_DEBUG_DUST") else 1.0  # thicken them, to see where they lie


func setup(w, wisps: Texture3D) -> void:
	world = w
	name = "DustTrails"
	_wisps = wisps
	_wind = Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	_shader = Shader.new()
	_shader.code = SHADER


## The vehicles raising dust at the grid's last look ([where, where it was,
## how much]): each carries on its stretch, thickens one it's driving along, or
## starts one.
func feed(movers: Array) -> void:
	for m in movers:
		var p: Vector3 = m[0]
		var was: Vector3 = m[1]
		var k := float(m[2])
		var dir := Defs.flat(p - was)
		if dir.length() < 0.5:
			continue
		dir = dir.normalized()
		var best: Array = []
		for sg in _s:
			if not (sg[0] as FogVolume).visible:
				continue
			var a: Vector3 = sg[2]
			var b: Vector3 = sg[3]
			var along := Defs.flat(b - a)
			var ln := along.length()
			# (the stretch it's laying: it ends where this one was, heading its way)
			if ln < SEG_LEN and Defs.flat(b - was).length() < 4.0 and (ln < 1.0 or along.normalized().dot(dir) > 0.8):
				best = sg
				break
			# (one it's driving along: thicken that)
			if ln > 1.0 and _off_line(p, a, b) < 5.0:
				best = sg
		if best.is_empty():
			best = _start(was)
		var a2: Vector3 = best[2]
		var b2: Vector3 = best[3]
		if Defs.flat(b2 - a2).length() < SEG_LEN and Defs.flat(b2 - was).length() < 4.0:
			best[3] = p
		best[4] = minf(float(best[4]), 4.0)  # (fresh dust on it: it hangs on)
		best[5] = minf(1.6, float(best[5]) + 0.35 * k)


## How far p is from the stretch a..b (flat), or a long way past its ends.
func _off_line(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Defs.flat(b - a)
	var t := Defs.flat(p - a).dot(ab) / maxf(ab.length_squared(), 0.01)
	if t < -0.1 or t > 1.1:
		return 99.0
	return Defs.flat(p - (a + ab * clampf(t, 0.0, 1.0))).length()


func _start(at: Vector3) -> Array:
	var sg: Array
	if _s.size() < SEGS:
		var v := FogVolume.new()
		v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var mt := ShaderMaterial.new()
		mt.shader = _shader
		mt.set_shader_parameter("wisps", _wisps)
		mt.set_shader_parameter("wind", _wind)
		v.material = mt
		add_child(v)
		sg = [v, mt, at, at, 0.0, 0.0]
		_s.append(sg)
	else:
		# (all in use: the oldest goes)
		sg = _s[0]
		for q in _s:
			if float(q[4]) > float(sg[4]):
				sg = q
		sg[2] = at
		sg[3] = at
		sg[4] = 0.0
		sg[5] = 0.0
	(sg[0] as FogVolume).visible = true
	return sg


func tick(dt: float, on: bool) -> void:
	visible = on
	if not on:
		return
	var w3 := Vector3(_wind.x, 0.0, _wind.y)
	for sg in _s:
		var v: FogVolume = sg[0]
		if not v.visible:
			continue
		sg[4] = float(sg[4]) + dt
		var age := float(sg[4])
		if age >= LIFE:
			v.visible = false
			continue
		var a: Vector3 = sg[2]
		var b: Vector3 = sg[3]
		var ab := Defs.flat(b - a)
		var ln := ab.length()
		var yaw := atan2(-ab.z, ab.x) if ln > 0.5 else 0.0
		# it billows up and out behind the vehicle, then spreads, drifts off
		# downwind and sinks back as it settles
		var rise := smoothstep(0.0, 4.0, age)
		var width := 7.0 + 0.45 * age
		var height := 3.0 + 4.0 * rise + 0.08 * age
		var mid := (a + b) * 0.5
		var gy: float = world.ground_y(mid)
		v.rotation.y = yaw
		v.size = Vector3(ln + 10.0, height, width + 4.0)
		v.position = Vector3(mid.x, gy + height * 0.5 - 0.6, mid.z) + w3 * (WeatherGrid.DRIFT * 0.6 * age)
		var fade := pow(1.0 - age / LIFE, 1.6)
		var m: ShaderMaterial = sg[1]
		m.set_shader_parameter("density", 0.22 * float(sg[5]) * rise * fade * _debug_k)
		m.set_shader_parameter("settle", age / LIFE)


## How many stretches hang (for --stats).
func count() -> int:
	var n := 0
	for sg in _s:
		if (sg[0] as FogVolume).visible:
			n += 1
	return n


## UVW runs 0..1 through the box: x along the route, y up, z across. A low
## bank thickest along the middle of the route and near the ground, its edges
## and top ragged with the drifting noise, the ends soft so stretches run into
## one another; lit on top by the sun, its underside in its own shade.
const SHADER := """
shader_type fog;

uniform sampler3D wisps : filter_linear, repeat_enable;
uniform vec2 wind = vec2(0.92, 0.38);
uniform float density = 0.0;
uniform float settle = 0.0;  // how far through its life (0 new, 1 settled)
// (sRGB) dry earth, the shade a little cooler; lit, a pale sandy dun
uniform vec3 shade_col : source_color = vec3(0.74, 0.68, 0.58);
uniform vec3 lit_col : source_color = vec3(0.95, 0.9, 0.8);

void fog() {
	vec3 u = UVW;
	vec3 p = WORLD_POSITION;
	float n1 = texture(wisps, p * 0.05 - vec3(wind.x, -0.12, wind.y) * TIME * 0.05).r;
	float n2 = texture(wisps, p * 0.16 + vec3(0.0, -TIME * 0.04, 0.0)).r;
	// across: thick down the middle of the route, ragged at the sides
	float c = (u.z - 0.5) * 2.0 * (0.8 + 0.5 * n1);
	float body = exp(-c * c * 2.6);
	// up: thickest low down, thinning to a ragged top that sinks as it settles
	float top = mix(0.85, 0.45, settle) * (0.75 + 0.5 * n2);
	body *= smoothstep(top, top * 0.3, u.y) * smoothstep(0.0, 0.08, u.y);
	// the ends soft (a volume's bounds must never show), the sides too
	body *= smoothstep(0.0, 0.14, u.x) * smoothstep(1.0, 0.86, u.x);
	body *= smoothstep(0.0, 0.12, u.z) * smoothstep(1.0, 0.88, u.z);
	float rags = smoothstep(0.4, 0.8, n1 * 0.75 + n2 * 0.55);
	DENSITY = density * body * (0.08 + rags * 1.6);
	ALBEDO = mix(shade_col, lit_col, smoothstep(0.1, 0.7, u.y));
}
"""
