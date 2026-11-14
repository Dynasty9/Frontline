class_name SmokePlumes
extends Node3D
## (view) The smoke a barrage or a fire leaves hanging over the field, close
## up: each a plume of its own, dense where it rose and drawn out downwind,
## spreading and climbing as it goes and breaking up into rags, its top lit by
## the sun and its underside in its own shade, until it thins away. The
## particle smoke of the blast or the fire is the heart of it; this is the pall
## it leaves behind. (Far off, the weather grid's coarse smoke stands in.)
##
## A few fog volumes (PLUMES) with a fog shader of their own, each laid along
## the wind: a new blast close to a young plume feeds that one rather than
## starting another, and once all are in use the oldest is taken. Burning
## things keep a plume going over them while they burn. Volumetric fog only;
## looks only.

const PLUMES := 16
## Seconds a blast's plume hangs before it has thinned away.
const LIFE := 55.0
## How close (m) a blast must fall to a young plume to feed it.
const MERGE := 14.0

var world
var _shader: Shader
var _wisps: Texture3D
var _wind := Vector2.ONE
var _yaw := 0.0
var _p: Array = []  # [volume, material, source, size, age, life, strength, fire]
var _fire_t := 0.0
var _debug_k := float(OS.get_environment("FL_DEBUG_PLUMES")) if OS.has_environment("FL_DEBUG_PLUMES") else 1.0  # thicken them, to see where they hang


func setup(w, wisps: Texture3D) -> void:
	world = w
	name = "SmokePlumes"
	_wisps = wisps
	_wind = Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	_yaw = atan2(-_wind.y, _wind.x)
	_shader = Shader.new()
	_shader.code = SHADER


## A blast of `size` (an effect event's) at p: a new plume, or more smoke in a
## young one close by.
func blast(p: Vector3, size: float) -> void:
	if size < 0.7:
		return
	for pl in _p:
		if not pl[7] and float(pl[4]) < 15.0 and Defs.flat(p - (pl[2] as Vector3)).length() < MERGE:
			pl[6] = minf(1.6, float(pl[6]) + 0.25 * size)
			pl[3] = maxf(float(pl[3]), size)
			return
	_start(p, size, LIFE * clampf(0.6 + 0.2 * size, 0.6, 1.2), clampf(0.35 + 0.3 * size, 0.4, 1.2), false)


func _start(p: Vector3, size: float, life: float, strength: float, fire: bool) -> Array:
	var pl: Array
	if _p.size() < PLUMES:
		var v := FogVolume.new()
		v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("wisps", _wisps)
		m.set_shader_parameter("wind", _wind)
		v.material = m
		v.rotation.y = _yaw
		add_child(v)
		pl = [v, m, p, size, 0.0, life, strength, fire]
		_p.append(pl)
	else:
		# (all in use: the one nearest its end goes)
		pl = _p[0]
		for q in _p:
			if float(q[5]) - float(q[4]) < float(pl[5]) - float(pl[4]):
				pl = q
		pl[2] = p
		pl[3] = size
		pl[4] = 0.0
		pl[5] = life
		pl[6] = strength
		pl[7] = fire
	(pl[0] as FogVolume).visible = true
	return pl


func tick(dt: float, on: bool) -> void:
	visible = on
	if not on:
		return
	_fire_t -= dt
	if _fire_t <= 0.0:
		_fire_t = 1.0
		_fires()
	for pl in _p:
		var v: FogVolume = pl[0]
		if not v.visible:
			continue
		pl[4] = float(pl[4]) + dt
		var age := float(pl[4])
		var life := float(pl[5])
		if age >= life:
			v.visible = false
			continue
		var size := float(pl[3])
		var src: Vector3 = pl[2]
		# a blast's cloud drifts off whole and spreads; a fire's stays rooted
		# over it, its plume reaching downwind
		var drift := 0.0 if pl[7] else WeatherGrid.DRIFT * age
		var length := 14.0 + 7.0 * size + (24.0 if pl[7] else WeatherGrid.DRIFT * age * 0.8)
		var width := 9.0 + 5.0 * size + age * 0.35
		var height := 8.0 + 6.0 * size + age * 0.5
		var w3 := Vector3(_wind.x, 0.0, _wind.y)
		var gy: float = world.ground_y(src)
		v.size = Vector3(length, height, width)
		v.position = Vector3(src.x, gy, src.z) + w3 * (drift + length * 0.5 - 3.0) + Vector3(0, height * 0.5 - 1.0, 0)
		var k := float(pl[6]) * smoothstep(0.0, 2.5, age) * pow(1.0 - age / life, 1.4)
		(pl[1] as ShaderMaterial).set_shader_parameter("density", 0.2 * k * _debug_k)
		(pl[1] as ShaderMaterial).set_shader_parameter("spread", clampf(age / 20.0, 0.0, 1.0))


## Whatever's alight keeps a plume over it while it burns.
func _fires() -> void:
	if world.fx == null or world.fx.vfx == null:
		return
	for f in world.fx.vfx.fire_sources():
		var at: Vector3 = f[0]
		var heat := float(f[1])
		var big := float(f[2])
		# (a small fire's smoke is its own particles' alone; a burning house or
		# a wreck lays a plume)
		if heat < 0.25 or big < 0.9:
			continue
		var k := (0.2 + 0.4 * heat) * minf(big, 2.0) * 0.5
		var found := false
		for pl in _p:
			if pl[7] and (pl[0] as FogVolume).visible and Defs.flat(at - (pl[2] as Vector3)).length() < 5.0:
				pl[5] = float(pl[4]) + 6.0  # (burning on: it lasts a while past the last look)
				pl[6] = k
				found = true
				break
		if not found:
			_start(at, big, 8.0, k, true)


## How many plumes are hanging (for --stats).
func count() -> int:
	var n := 0
	for pl in _p:
		if (pl[0] as FogVolume).visible:
			n += 1
	return n


## UVW runs 0..1 through the box: x down the wind from where it rose, y up, z
## across. The plume is a tube that widens and climbs as it goes, broken up by
## the drifting noise, lit on top and dark underneath (the fog doesn't shade
## itself, so its own shade is painted in).
const SHADER := """
shader_type fog;

uniform sampler3D wisps : filter_linear, repeat_enable;
uniform vec2 wind = vec2(0.92, 0.38);
uniform float density = 0.0;
uniform float spread = 0.0;  // how far it has opened out (0 new, 1 old)
// (sRGB) a neutral grey with a little of the sky in it; lit, near white
uniform vec3 shade_col : source_color = vec3(0.4, 0.42, 0.46);
uniform vec3 lit_col : source_color = vec3(0.93, 0.92, 0.9);

void fog() {
	vec3 u = UVW;
	float along = u.x;
	float r = mix(0.22, 0.5, sqrt(along)) * mix(0.8, 1.0, spread);
	float cy = mix(0.22, 0.55, along);
	vec2 d = vec2((u.z - 0.5) / r, (u.y - cy) / (r * 0.85));
	float body = exp(-dot(d, d) * 2.0);
	// thickest near where it rose, thinning out downwind, rooted on the ground
	body *= smoothstep(0.0, 0.06, along) * (1.0 - smoothstep(mix(0.45, 0.7, spread), 1.0, along)) * smoothstep(0.0, 0.05, u.y);
	vec3 p = WORLD_POSITION;
	float n1 = texture(wisps, p * 0.045 - vec3(wind.x, -0.25, wind.y) * TIME * 0.04).r;
	float n2 = texture(wisps, p * 0.13 + vec3(0.0, -TIME * 0.06, 0.0)).r;
	float rags = smoothstep(0.48, 0.82, n1 * 0.8 + n2 * 0.5 - spread * 0.1);
	DENSITY = density * body * rags * 2.0;
	ALBEDO = mix(shade_col, lit_col, smoothstep(cy - r * 0.9, cy + r * 0.6, u.y));
}
"""
