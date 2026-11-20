class_name AirLights
extends Node
## (view) The battle's own lights in the smoke and the air: a shell bursting
## among the smoke of the last ones lights it from inside, a burning wreck or
## house lights the smoke drifting past it, a muzzle flash catches the gun's
## own smoke, a street lamp or a flare the smoke under it, and a tracer lights
## the smoke it flies through and leaves a faint streak in the night's damp
## air, brightest where the mist lies.
##
## The smoke is drawn unshaded (Vfx's and GunFx's puffs light themselves from
## the sun and the sky), so the engine's lights never reach it. Every frame
## the lights that matter most to the camera are picked (MAX, by how bright
## and how big they are and how near) and written into a small texture every
## smoke shader reads (the global `air_lights`, GLSL below): the puffs are lit
## by them per vertex, from the side the light is on, in both renderers (the
## browser's stand-in for the glow, since it has no volumetric fog). The air
## itself already takes the flashes', fires', lamps' and flares' lights in the
## engine's volumetric fog (their light_volumetric_fog_energy), but a line of
## light it can't draw: the fog volumes (AirLayers, SmokePlumes) add the
## tracers' streaks, the first FOG of the list, to the air they hold.
##
## Its own list of the flashes (fed by Fx and GunFx as they light up, so the
## browser, which has no flash lights, gets them too, dying away as those do),
## the tracers in flight (GunFx.tracer, on its clock), and the steady lights
## (the fires' glows and anything else in Atmosphere.LIGHT_GROUP: flares,
## lamps), the nearest STEADY looked up a few times a second. Looks only:
## nothing here touches the simulation or world.rng.

## How many lights the smoke is lit by at once, and how many of them (the
## tracers) glow in the fog volumes.
const MAX := 16
const FOG := 8
## How strongly the fog volumes and the particle smoke take the lights.
## (The fog weighs a volume's emission by its density, a few thousandths a
## metre in the night's haze, so its scale is far larger than the smoke's,
## which is lit like a surface.)
const FOG_K := 60.0
const SMOKE_K := 0.35
## Tracers kept in flight for the glow (the oldest is dropped).
const TRACERS := 48
## How far (m) a light may be from the camera and still count, and how many
## of the steady ones (the nearest) are looked at each frame.
const REACH := 320.0
const STEADY := 24

var world
## (FL_DEBUG_AIR_FLIP_LIGHTS turns it off and on for comparisons;
## FL_DEBUG_AIR_LIGHTS_OFF leaves it off, for "before" recordings)
var on := not OS.has_environment("FL_DEBUG_AIR_LIGHTS_OFF")
var count := 0  # how many lit the air last frame (for --stats)
var fog_count := 0
var _flashes: Array = []  # [pos, colour (linear, times energy), energy, range, decay a second, linger]
var _tracers: Array = []  # [from, dir, total, lit length, speed, t0, ignition, colour]
var _steady: Array[Light3D] = []
var _steady_t := 0.0
var _img: Image
var _tex: ImageTexture
var _buf := PackedFloat32Array()
var _was := false
## FL_DEBUG_AIR_LIGHTS=K: the fog's share times K (to see where it lies), and
## a line a second of what's lit.
var _debug_k := float(OS.get_environment("FL_DEBUG_AIR_LIGHTS")) if OS.has_environment("FL_DEBUG_AIR_LIGHTS") else 0.0
var _debug_t := 0.0
## Scratch for the pick (kept, so a frame allocates nothing): up to CANDS
## candidates, each a score, a fog flag and twelve values (three texels).
const CANDS := MAX * 2
var _nc := 0
var _weakest := -1  # (when full: the weakest's index, -1 to look again)
var _score := PackedFloat32Array()
var _fog_flag := PackedByteArray()
var _cand := PackedFloat32Array()
var _taken := PackedByteArray()


func setup(w) -> void:
	world = w
	name = "AirLights"
	_buf.resize(MAX * 3 * 4)
	_score.resize(CANDS)
	_fog_flag.resize(CANDS)
	_taken.resize(CANDS)
	_cand.resize(CANDS * 12)
	_img = Image.create_from_data(MAX, 3, false, Image.FORMAT_RGBAF, _buf.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set(&"air_lights", _tex)
	RenderingServer.global_shader_parameter_set(&"air_light_info", Vector4.ZERO)


func _exit_tree() -> void:
	# (the next battle, the Field Manual's models: nothing lit by this one's)
	RenderingServer.global_shader_parameter_set(&"air_light_info", Vector4.ZERO)


## A flash at p: `energy` and `rng_m` as the light it comes with (Fx's and
## GunFx's), dying away by `decay` a second as that light does.
func flash(p: Vector3, col: Color, energy: float, rng_m: float, decay: float) -> void:
	# (a gun firing again keeps its flash going, as GunFx keeps its light)
	for i in range(_flashes.size() - 1, maxi(_flashes.size() - 8, 0) - 1, -1):
		var f: Array = _flashes[i]
		if (f[0] as Vector3).distance_squared_to(p) < 4.0:
			f[2] = maxf(float(f[2]), energy)
			return
	if _flashes.size() >= 48:
		_flashes.pop_front()
	_flashes.append([p, col.srgb_to_linear(), energy, rng_m, decay])


## A tracer leaving `from` for `to` at `t0` on GunFx's clock (see GunFx.tracer):
## the lit `lit` metres of it run along at `speed`.
func tracer(from: Vector3, to: Vector3, col: Color, lit: float, speed: float, t0: float, ignition: float) -> void:
	var span := to - from
	var total := span.length()
	if total < 1.0:
		return
	if _tracers.size() >= TRACERS:
		_tracers.pop_front()
	_tracers.append([from, span / total, total, lit, speed, t0, ignition, Color(col.r, col.g, col.b).srgb_to_linear() * col.a])


var _debug_us := 0
var _debug_ticks := 0


func tick(dt: float, gun_now: float) -> void:
	if _debug_k <= 0.0:
		_tick(dt, gun_now)
		return
	var t0 := Time.get_ticks_usec()
	_tick(dt, gun_now)
	_debug_us += Time.get_ticks_usec() - t0
	_debug_ticks += 1


func _tick(dt: float, gun_now: float) -> void:
	# the flashes die away whether they're drawn or not
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Array = _flashes[i]
		f[2] = float(f[2]) * exp(-dt * float(f[4])) - dt * 0.5
		if float(f[2]) <= 0.02:
			_flashes.remove_at(i)
	for i in range(_tracers.size() - 1, -1, -1):
		var t: Array = _tracers[i]
		if float(t[4]) * (gun_now - float(t[5])) - float(t[3]) >= float(t[2]):
			_tracers.remove_at(i)
	var cam: Camera3D = world.cam.cam if world.cam else null
	if not on or cam == null or Settings.fx_mult() < 0.5:
		_upload(0, 0)
		return
	_steady_t -= dt
	if _steady_t <= 0.0:
		_steady_t = 0.25
		_find_steady(cam.global_position)
	_pick(cam.global_position, -cam.global_basis.z, gun_now)


## The steady lights: every fire's glow, and the other lights of the battle
## (flares, street lamps), but not the flashes' own pool (fed as flashes).
func _find_steady(cam: Vector3) -> void:
	_steady.clear()
	var near: Array = []
	for n in get_tree().get_nodes_in_group(&"fx_light"):
		var l := n as OmniLight3D
		if l == null or l.has_meta(&"air_flash") or l.light_energy < 0.05 or not l.is_visible_in_tree():
			continue
		var d := l.global_position.distance_to(cam)
		if d < REACH + l.omni_range:
			near.append([d - l.omni_range, l])
	# (a town's street lamps are many: only the nearest are looked at each frame)
	if near.size() > STEADY:
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		near.resize(STEADY)
	for e in near:
		_steady.append(e[1])


## The MAX candidates scoring highest, fog-lit ones first.
func _pick(cam: Vector3, fwd: Vector3, gun_now: float) -> void:
	_nc = 0
	_weakest = -1
	for f in _flashes:
		var p: Vector3 = f[0]
		var e := float(f[2])
		_offer(p, p, float(f[3]), (f[1] as Color) * e, e, false, false, cam, fwd)
	for l in _steady:
		if not is_instance_valid(l) or l.light_energy < 0.05 or not l.is_inside_tree():
			continue
		var p := l.global_position
		var e := l.light_energy
		_offer(p, p, (l as OmniLight3D).omni_range, l.light_color.srgb_to_linear() * e, e, false, false, cam, fwd)
	for t in _tracers:
		var age := gun_now - float(t[5])
		var run := float(t[4]) * age
		var total := float(t[2])
		var lit := float(t[3])
		var ign := minf(float(t[6]), total)
		if age < 0.0 or run < ign:
			continue
		# the air round the burning streak itself, a little longer (the eye
		# holds it a moment), dimming as it goes into what it hit
		var head := minf(total, run)
		var tail := clampf(run - lit * 1.3, ign, total)
		var fade := clampf((total - clampf(run - lit, ign, total)) / maxf(lit, 1.0), 0.0, 1.0)
		if head - tail < 0.5 or fade <= 0.0:
			continue
		var from: Vector3 = t[0]
		var dir: Vector3 = t[1]
		var c: Color = t[7]
		_offer(from + dir * head, from + dir * tail, 2.5, c * (0.04 * fade), 0.6 * fade, true, true, cam, fwd)
	# fog-lit first (the best FOG of them), then the best of the rest
	_taken.fill(0)
	var n := 0
	var nf := 0
	for pass_fog in [1, 0]:
		var cap: int = FOG if pass_fog == 1 else MAX
		while n < MAX and (nf < cap if pass_fog == 1 else true):
			var best := -1
			for i in _nc:
				if _taken[i] == 0 and _fog_flag[i] == pass_fog and (best < 0 or _score[i] > _score[best]):
					best = i
			if best < 0:
				break
			_taken[best] = 1
			for k in 12:
				_buf[_slot(n, k)] = _cand[best * 12 + k]
			n += 1
			if pass_fog == 1:
				nf += 1
	_upload(n, nf)


## Where value k (0..11: three texels of four) of light n goes in the image.
func _slot(n: int, k: int) -> int:
	return ((k >> 2) * MAX + n) * 4 + (k & 3)


## One candidate: a point (a == b) or a line from a to b, `rng_m` across,
## of `col` (linear, energy in it). Kept only if it's among the MAX best.
func _offer(a: Vector3, b: Vector3, rng_m: float, col: Color, e: float, fog: bool, line: bool, cam: Vector3, fwd: Vector3) -> void:
	var to := a - cam
	var d2 := to.length_squared()
	if d2 > REACH * REACH or to.dot(fwd) < -rng_m:
		return
	var s := e * rng_m * rng_m / (rng_m * rng_m + d2 * 0.25)
	var at := _nc
	if _nc >= CANDS:
		# (full: this takes the weakest one's place, if it beats it)
		if _weakest < 0:
			_weakest = 0
			for i in CANDS:
				if _score[i] < _score[_weakest]:
					_weakest = i
		if _score[_weakest] >= s:
			return
		at = _weakest
		_weakest = -1
	else:
		_nc += 1
	_score[at] = s
	_fog_flag[at] = 1 if fog else 0
	var o := at * 12
	_cand[o] = a.x
	_cand[o + 1] = a.y
	_cand[o + 2] = a.z
	_cand[o + 3] = rng_m
	_cand[o + 4] = col.r
	_cand[o + 5] = col.g
	_cand[o + 6] = col.b
	_cand[o + 7] = 1.0 if line else 0.0
	_cand[o + 8] = b.x
	_cand[o + 9] = b.y
	_cand[o + 10] = b.z
	_cand[o + 11] = 0.0


func _upload(n: int, nf: int) -> void:
	count = n
	fog_count = nf
	if n == 0 and not _was:
		return
	_was = n > 0
	if n > 0:
		_img.set_data(MAX, 3, false, Image.FORMAT_RGBAF, _buf.to_byte_array())
		_tex.update(_img)
	var vol: bool = Settings.get_v("vol_fog") and not Vfx.gl
	RenderingServer.global_shader_parameter_set(&"air_light_info", Vector4(n, nf if vol else 0, FOG_K * (_debug_k if _debug_k > 0.0 else 1.0), SMOKE_K))
	if _debug_k > 0.0 and Time.get_ticks_msec() > _debug_t:
		_debug_t = Time.get_ticks_msec() + 1000.0
		print("AIRL n=%d fog=%d vol=%s flashes=%d tracers=%d steady=%d cpu=%.3f ms" % [n, nf, vol, _flashes.size(), _tracers.size(), _steady.size(), _debug_us / 1000.0 / maxf(_debug_ticks, 1)])
		_debug_us = 0
		_debug_ticks = 0


## What each shader that takes the lights includes (air_lights.gdshaderinc):
## air_light(p, n, dir), the light the first n of them throw on the air at p,
## and (dir, weighted by it) where it mostly comes from; air_light_glow(), the
## fog volumes' share of it.
const INCLUDE := "res://scripts/game/air_lights.gdshaderinc"
