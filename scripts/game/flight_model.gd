class_name FlightModel
extends RefCounted
## A fixed-wing aircraft flown by stick and throttle, as a pilot flies one.
##
## It is a point mass with an attitude. The stick's roll axis rolls it about its
## nose; its pitch axis asks the wing for g (neutral holds 1 g, full back the
## airframe's limit, full forward its negative limit), and the wing's lift, along
## the aircraft's own up, bends the flight path. So a turn is a bank and a pull,
## a loop is a pull held, and inverted flight works. The wing can't give more g
## than the airflow allows, (V / v_stall)^2, so a slow aeroplane can't hold its
## height. Thrust against drag, and gravity along the flight path, set the
## speed: a dive gains it, a climb or a hard turn bleeds it; speed brakes are the
## throttle's negative half.
##
## The AI flies it through `autopilot` (a heading, a climb angle, a speed); a
## player would set `roll`, `pitch` and `throttle` directly and call `step`.
## Everything is plain arithmetic on its own state, so a seed repeats a flight.

const G := 9.81

# --- the airframe ---
var v_cruise := 95.0  # m/s it flies at, about 60% throttle level
var v_stall := 38.0  # below this the wing can't hold 1 g
var v_max := 150.0
var n_max := 7.0  # the most g the pilot may pull
var n_min := -2.5  # and push
var roll_rate := 3.0  # rad/s at full stick
var onset := 10.0  # g/s: how fast the wing's load follows the stick
var accel := 9.0  # m/s^2 of thrust at full throttle
var brake := 6.0  # m/s^2 of drag from the speed brakes, fully out

# --- the controls (-1..1) ---
var roll := 0.0  # + rolls right
var pitch := 0.0  # + pulls (back stick)
var throttle := 0.6  # 0..1 thrust; below 0, speed brakes

# --- its state ---
var pos := Vector3.ZERO
var basis := Basis.IDENTITY  # its attitude: -Z the nose, +Y the canopy
var speed := 95.0
var n := 1.0  # the load the wing is carrying now (g)


## Sets the airframe for an aircraft that cruises at `cruise` m/s.
## `thrust` is its full-throttle push per m/s of cruise: about 0.13 for a
## fighter in afterburner, less for an A-10 or a light plane.
func setup(cruise: float, g_limit := 7.0, roll_limit := 3.0, thrust := 0.095) -> FlightModel:
	v_cruise = cruise
	v_stall = cruise * 0.4
	v_max = cruise * 1.6
	n_max = g_limit
	roll_rate = roll_limit
	accel = cruise * thrust
	brake = cruise * 0.065
	speed = cruise
	return self


## Puts it at `p` flying along `dir` (wings level) at `v` m/s.
func place(p: Vector3, dir: Vector3, v: float) -> void:
	pos = p
	speed = v
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
	basis = Basis.looking_at(dir, up)
	n = cos(asin(clampf(dir.normalized().y, -1.0, 1.0)))


func forward() -> Vector3:
	return -basis.z


func velocity() -> Vector3:
	return forward() * speed


## Its bank: + left wing down.
func bank() -> float:
	return atan2(basis.x.y, basis.y.y)


## Its flight path angle: + climbing.
func climb() -> float:
	return asin(clampf(forward().y, -1.0, 1.0))


## The most g the wing can give at this speed.
func n_aero() -> float:
	var r := speed / v_stall
	return r * r


## Drag at speed `v` carrying `load` g, as an acceleration: parasite drag rising
## with the square of the speed, and the drag of lift rising with the load.
func drag(v: float, load: float) -> float:
	var k := accel * 0.6 / (v_cruise * v_cruise)
	var induced := accel * 0.04 * load * load * (v_cruise * v_cruise) / maxf(v * v, 1.0)
	return k * v * v + induced


## The stick position that asks for `want` g.
func stick_for(want: float) -> float:
	return clampf((want - 1.0) / (n_max - 1.0), 0.0, 1.0) if want >= 1.0 else -clampf((1.0 - want) / (1.0 - n_min), 0.0, 1.0)


## Flies `dt` seconds on the controls as they are.
func step(dt: float) -> void:
	# roll about the nose
	basis = basis * Basis(Vector3.BACK, -clampf(roll, -1.0, 1.0) * roll_rate * dt)
	# the g the stick asks for, as much of it as the airflow allows, coming on at the onset rate
	var p := clampf(pitch, -1.0, 1.0)
	var want := 1.0 + p * (n_max - 1.0) if p >= 0.0 else 1.0 + p * (1.0 - n_min)
	var lim := n_aero()
	want = clampf(want, maxf(n_min, -lim * 0.6), minf(n_max, lim))
	n = move_toward(n, want, onset * dt)
	# lift along the canopy and gravity across the flight path bend it
	var fw := forward()
	var down_across := Vector3.DOWN - fw * fw.dot(Vector3.DOWN)
	var across := basis.y * (G * n) + down_across * G
	var nf := (fw + across / maxf(speed, 1.0) * dt).normalized()
	var axis := fw.cross(nf)
	var s := axis.length()
	if s > 1e-7:
		basis = Basis(axis / s, asin(minf(s, 1.0))) * basis
	basis = basis.orthonormalized()
	# thrust, drag, brakes and gravity along the path
	var t := clampf(throttle, -1.0, 1.0)
	var a := accel * maxf(t, 0.0) - drag(speed, n) - brake * maxf(-t, 0.0) - G * nf.y
	speed = clampf(speed + a * dt, v_stall * 0.5, v_max)
	pos += nf * (speed * dt)


## The controls that fly toward ground heading `want_dir` (flat), climbing at
## `gamma_want` rad, at `speed_want` m/s, banking no more than `max_bank` and
## pulling `n_lo`..`n_hi` g at most: what a pilot does without thinking.
func autopilot(want_dir: Vector3, gamma_want: float, speed_want: float, max_bank: float, n_lo := 0.2, n_hi := 4.0, roll_limit := 1.0) -> void:
	var fw := Vector3(forward().x, 0.0, forward().z)
	var wf := Vector3(want_dir.x, 0.0, want_dir.z)
	var err := 0.0
	if fw.length() > 0.01 and wf.length() > 0.01:
		err = fw.normalized().signed_angle_to(wf.normalized(), Vector3.UP)
	var g := climb()
	# no steeper a bank than the wing can hold its climb in at this speed
	var n_av := minf(n_hi, n_aero() * 0.9)
	if n_av > cos(g):
		max_bank = minf(max_bank, acos(cos(g) / n_av))
	else:
		max_bank = 0.0
	# nor a steeper climb than the engine keeps up, less if he's slow, more
	# while he has speed in hand to trade for height
	var sustained := asin(clampf((accel - drag(speed, 1.0 / maxf(cos(max_bank), 0.25))) / G, -1.0, 1.0))
	gamma_want = minf(gamma_want, sustained + 2.0 * (speed - speed_want * 0.85) / speed_want)
	# bank toward the turn (+ left), roll there briskly but without overshoot
	var b := bank()
	var bank_want := clampf(err * 5.0, -max_bank, max_bank)
	roll = clampf(-(bank_want - b) * 4.0, -roll_limit, roll_limit)
	# the g that holds the climb it wants in this bank, plus a pull toward it
	var cb := maxf(cos(b), 0.25)
	var n_want := (cos(g) + speed * 1.6 * (gamma_want - g) / G) / cb
	pitch = stick_for(clampf(n_want, n_lo, n_hi))
	# throttle for the drag and the climb, and a little more for the error
	var need := drag(speed, n) + G * sin(g) + (speed_want - speed) * 0.8
	throttle = clampf(need / accel, 0.0, 1.0) if need >= 0.0 else clampf(need / brake, -1.0, 0.0)
