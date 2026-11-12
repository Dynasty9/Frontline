class_name HeatHaze
extends RefCounted
## Heat haze (Settings > Lighting & Look > Camera and lens): the air shimmering
## over burning wrecks and grass and wood fires, over the engine decks and out
## of the exhausts of vehicles with their engines running, and for a moment
## round a blast or a gun's muzzle. Hot air is thinner than the air round it,
## so it bends light, and it rises in turbulent cells, so the bend wavers and
## whatever is seen through it swims.
##
## Each source is a blob of hot air stretched along its axis (straight up for a
## fire, out of the pipe and up for an exhaust): a centre, a width, the axis and
## how far it is drawn out along it, how hot it is, how fast the air rises and
## the size of its turbulence. They are gathered here on the main thread every
## frame (Vfx.heat_sources, Vehicle.heat_sources and the pulses), culled to the
## view, and the strongest HEAT_MAX of them handed to CinematicFx, whose heat
## pass bends the scene behind them. Looks only: nothing here reaches the
## simulation.

const MAX := CinematicFx.HEAT_MAX
const STRIDE := CinematicFx.HEAT_STRIDE
## Beyond this a shimmer is too fine to see from the camera.
const REACH := 280.0
## At most this many blasts and muzzles at once (the oldest go first).
const PULSES := 16

var on := false  # the setting (Atmosphere): while off, nothing is gathered or kept
var _eye := Vector3.ZERO
var _planes: Array[Plane] = []
var _cand := PackedFloat32Array()  # this frame's sources, STRIDE floats each
var _score := PackedFloat32Array()  # and how much each would show
var _n := 0
var _pulses: Array = []  # [centre, width, axis, stretch, strength, rise, cell, life, age]


## Starts this frame's sources, seen from `cam`.
func begin(cam: Camera3D) -> void:
	_eye = cam.global_position
	_planes = cam.get_frustum()
	_n = 0


## A blob of hot air centred on `c`, `width` across (one standard deviation, m),
## drawn out `stretch` times as far along `axis` (a unit vector); `strength` 1
## is a well-alight fire. Its air rises `rise` m/s and churns in cells `cell` m
## across, `churn` times a second. Left out if it's behind the camera, out of
## the view or too far off to see.
func add(c: Vector3, width: float, axis: Vector3, stretch: float, strength: float, rise: float, cell: float, churn := 1.0) -> void:
	if strength < 0.02 or width <= 0.0:
		return
	var extent := width * maxf(stretch, 1.0) * 2.5
	var d := _eye.distance_to(c)
	if d > REACH + extent:
		return
	for pl in _planes:
		if pl.distance_to(c) > extent:
			return
	var i := _n * STRIDE
	if _cand.size() < i + STRIDE:
		_cand.resize(i + STRIDE * 16)
		_score.resize(_n + 16)
	_cand[i] = c.x
	_cand[i + 1] = c.y
	_cand[i + 2] = c.z
	_cand[i + 3] = width
	_cand[i + 4] = axis.x
	_cand[i + 5] = axis.y
	_cand[i + 6] = axis.z
	_cand[i + 7] = maxf(stretch, 0.2)
	_cand[i + 8] = strength
	_cand[i + 9] = rise
	_cand[i + 10] = cell
	_cand[i + 11] = churn
	# what it would show: how hot, how big on screen, fading out with distance
	_score[_n] = strength * width * maxf(stretch, 1.0) / maxf(d, 8.0) * (1.0 - smoothstep(REACH * 0.6, REACH + extent, d))
	_n += 1


## This frame's sources for the heat pass: all of them, or the MAX that would
## show the most.
func finish() -> PackedFloat32Array:
	if _n <= MAX:
		return _cand.slice(0, _n * STRIDE)
	var sorted := _score.slice(0, _n)
	sorted.sort()
	var cut := sorted[_n - MAX]
	var out := PackedFloat32Array()
	out.resize(MAX * STRIDE)
	var j := 0
	for i in _n:
		if _score[i] < cut or j >= MAX:
			continue
		for k in STRIDE:
			out[j * STRIDE + k] = _cand[i * STRIDE + k]
		j += 1
	return out


## Everything giving off heat in view this frame, for the heat pass.
func gather(world: World, cam: Camera3D, dt: float) -> PackedFloat32Array:
	begin(cam)
	if world.fx and world.fx.vfx:
		world.fx.vfx.heat_sources(self)
	var far := (REACH + 20.0) * (REACH + 20.0)
	for v in world.vehicles:
		if v.model and v.visible and not v.gone and v.global_position.distance_squared_to(_eye) < far:
			v.heat_sources(self)
	_tick_pulses(dt)
	return finish()


## A fire filling the box `ext` (half extents) round `p`, burning at `fire`
## (0..1): a column of hot air over it, leaning a little downwind, taller and
## wider the bigger the fire.
func add_fire(p: Vector3, ext: Vector3, fire: float) -> void:
	var r := maxf(ext.x, ext.z)
	var width := 0.45 + 0.5 * r
	var tall := 2.2 + 2.0 * ext.y + 1.6 * sqrt(r) + 1.4 * fire
	var axis := (Vector3.UP + Fires.WIND * 0.12).normalized()
	add(p + axis * (tall * 0.42), width, axis, maxf(1.2, tall / (2.0 * width)), 0.4 + 0.9 * fire, 1.6 + 0.8 * fire, 0.3 + 0.12 * r, 0.8)


## A burst of heat: a blast, a gun's muzzle. It swells and fades over `life`
## seconds.
func pulse(c: Vector3, width: float, axis: Vector3, stretch: float, strength: float, life: float, rise := 3.0, cell := 0.5) -> void:
	if not on:
		return
	if _pulses.size() >= PULSES:
		_pulses.pop_front()
	_pulses.append([c, width, axis, stretch, strength, rise, cell, life, 0.0])


## An explosion of `size` (as Fx draws it) at `p`.
func blast(p: Vector3, size: float) -> void:
	var s := clampf(size, 0.3, 3.0)
	pulse(p + Vector3(0, 0.5 + 0.6 * s, 0), 1.0 + 1.3 * s, Vector3.UP, 1.3, 1.1 + 0.4 * s, 0.45 + 0.3 * s, 3.5, 0.45 + 0.2 * s)


## How strong a pulse is `age` seconds into its `life`: in at once, out slowly.
static func pulse_strength(age: float, life: float) -> float:
	if life <= 0.0 or age >= life:
		return 0.0
	var u := age / life
	return smoothstep(0.0, 0.06, u) * (1.0 - u) * (1.0 - u)


func _tick_pulses(dt: float) -> void:
	for i in range(_pulses.size() - 1, -1, -1):
		var pl: Array = _pulses[i]
		pl[8] = float(pl[8]) + dt
		var k := pulse_strength(float(pl[8]), float(pl[7]))
		if k <= 0.0 and float(pl[8]) >= float(pl[7]):
			_pulses.remove_at(i)
			continue
		var u := float(pl[8]) / float(pl[7])
		# the hot gas spreads as it cools
		add(pl[0], float(pl[1]) * (0.75 + 0.5 * u), pl[2], float(pl[3]), float(pl[4]) * k, float(pl[5]), float(pl[6]), 2.5)


## How many pulses are still going (for the tests).
func pulses() -> int:
	return _pulses.size()


## Drops everything kept from earlier frames (the setting turned off).
func clear() -> void:
	_pulses.clear()
	_n = 0
