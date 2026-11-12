class_name HelicopterFlight
extends RefCounted
## A helicopter flies by tilting its rotor. To go somewhere the pilot tips the
## disc that way and the airframe follows it: the nose dips before she gathers
## speed, comes up into a flare before she slows, and she banks to turn. The
## cyclic only moves so fast (a heavy lifter is slow to answer, a scout snaps
## round), so acceleration builds and dies away instead of switching on.
##
## In forward flight the tail fin keeps the nose on the flight path and turns
## are banked arcs; only near the hover can the pilot point her anywhere, pedal
## turn or side-step, and then only so fast sideways or backwards. Climbs are
## best with some forward speed, and at hover speeds the descent is kept slow
## (come straight down fast and the rotor sinks into its own downwash).
##
## The pilot flies a profile, not a straight line: lift into a low hover, then
## nose over and climb away as speed builds; cruise high enough to clear the
## ground ahead; and come down a glide path into a low hover over the spot,
## slowing all the way, before setting down. Guidance asks for a velocity, not
## a position: momentum survives a new order. The host runs all of this; the
## pitch and bank are sent to clients with the snapshots.

const G := 9.81
const CRUISE_AGL := 16.0  # over the highest ground ahead
const HOVER_AGL := 2.0  # the hover check after lift-off, and the last hover before touchdown
const GLIDE := 0.22  # the approach: about 12 degrees down to the spot
const LEAD := 1.2  # s: how far down the glide path the pilot is already reading
const KP := 0.65  # near the spot: speed wanted per metre still to go (1/s)
const KV := 1.6  # velocity error to acceleration (1/s)
const KV_CRUISE := 1.1  # the same for speed changes in forward flight, flown more gently
const KZ := 0.9  # height error to climb rate (1/s)
const KVZ := 2.4  # climb-rate error to vertical acceleration (1/s)
const V_JERK := 7.0  # how fast the collective changes the vertical acceleration (m/s³)

var pitch := 0.0  # negative: nose down (disc tilted forward)
var roll := 0.0  # negative: right side down
var pitch_rate := 0.0
var roll_rate := 0.0
var yaw_rate := 0.0
var lift := 0.0  # the vertical acceleration the collective is giving (m/s²)
var _spec := {}


func step(v: Vehicle, goal: Vector3, dt: float, face := INF) -> void:
	if dt <= 0.0:
		return
	if _spec.is_empty():
		_spec = spec(v)
	# Keep the same handling when a test or fast-forward uses a coarser tick.
	var left := dt
	while left > 0.00001:
		var h := minf(left, 1.0 / 30.0)
		_integrate(v, goal, h, face)
		left -= h


## The airframe's envelope, from its handling profile: how hard it may tilt
## to accelerate, brake and bank, how fast the cyclic moves, its climb.
static func spec(v: Vehicle) -> Dictionary:
	var motion := v.motion_profile()
	var handling: Array = motion.handling
	var accel := float(handling[0])
	var vmax := maxf(float(v.vdef.speed), 1.0)
	# a small rotor answers the stick quicker than a big one
	var length := float(v.vdef.get("size", Vector3(2, 2, 10)).z)
	var cyclic := float(motion.hull_turn) * clampf(1.6 - length / 25.0, 0.75, 1.35)
	return {
		"accel": accel, "brake": float(handling[1]), "vmax": vmax, "tail": length * 0.5,
		"bank": atan(accel * 1.6 / G),
		"cyclic": cyclic,
		"yaw": float(motion.hull_turn), "yaw_accel": float(motion.hull_accel),
		"climb": 1.5 + accel * 1.2, "vaccel": 1.6 + accel * 0.3,
		# parasite drag: cruising flat out takes the nose about 6.5 degrees down
		"drag": G * tan(deg_to_rad(6.5)) / (vmax * vmax),
	}


func _integrate(v: Vehicle, goal: Vector3, dt: float, face: float) -> void:
	var s := _spec
	var loaded := v.sling_cargo != null
	var accel_max := float(s.accel) * (0.55 if loaded else 1.0)
	var brake_max := float(s.brake) * (0.65 if loaded else 1.0)
	var vmax := float(s.vmax) * (0.65 if loaded else 1.0)
	var bank_max := float(s.bank) * (0.7 if loaded else 1.0)
	var cyclic := float(s.cyclic) * (0.7 if loaded else 1.0)
	# a load on the cable drags too, and keeps the nose further down
	var drag := float(s.drag) * (1.8 if loaded else 1.0)
	var ground := maxf(0.0, v.world.ground_y(v.position))
	var agl := v.position.y - ground
	var on_gear := agl < 0.2
	var hang := v.sling_hang()
	var vel := Defs.flat(v.velocity)
	var spd := vel.length()
	var to := Defs.flat(goal - v.position)
	var d := to.length()
	var along := to / d if d > 0.001 else Defs.dir_of(v.rotation.y)

	# --- pedals: in forward flight the fin keeps the nose on the flight path;
	# near the hover the pilot points it where she's going (or at the target)
	var heading := v.rotation.y
	var want_heading := heading
	# how far she is into forward flight (holding the nose on a target, the
	# pilot flies her like a hover however fast she's sliding)
	var fast := 0.0 if face != INF else smoothstep(0.25 * vmax, 0.5 * vmax, spd)
	if on_gear:
		pass  # (she doesn't turn on her wheels or skids)
	elif face != INF:
		want_heading = face
	else:
		var low := Defs.yaw_of(to) if d > 12.0 else heading
		var high := Defs.yaw_of(vel) if spd > 0.5 else heading
		want_heading = lerp_angle(low, high, fast)
	var turn := VehicleMotion.slew(heading, yaw_rate, want_heading, float(s.yaw) * (0.75 if loaded else 1.0), float(s.yaw_accel), dt)
	yaw_rate = turn.y
	v.rotation.y = turn.x
	var fwd := Defs.dir_of(v.rotation.y)
	var right := fwd.cross(Vector3.UP)

	# --- cyclic: the speed wanted for stopping on the spot, with a planned
	# deceleration well inside the airframe's (the pilot keeps some in hand)
	var plan := brake_max * 0.55
	var v0 := plan / KP
	var d0 := v0 / KP
	var want := d * KP if d <= d0 else sqrt(v0 * v0 + 2.0 * plan * (d - d0))
	# how much slower she should be for each metre closer: flown as a steady
	# deceleration, not left to build up as a lag and caught with a late flare
	var slope := KP if d <= d0 else plan / maxf(want, 0.1)
	if want >= vmax:
		want = vmax
		slope = 0.0
	# Leaving low over the ground, or with a load under her, she doesn't race
	# along: the pilot climbs out while gathering speed. (Coming in, the glide
	# path and the slowing approach already keep height and speed together.)
	if not on_gear and d > 30.0:
		var climb_out := maxf(1.5, (agl - hang - 0.6) * 2.0)
		if climb_out < want:
			want = climb_out
			slope = 0.0
	var slowing := -slope * maxf(0.0, vel.dot(along)) if d > 0.001 else 0.0
	var side := G * tan(bank_max)
	var target_pitch := 0.0
	var target_roll := 0.0
	if not on_gear:
		var a := Vector3.ZERO
		if fast < 1.0:
			# hover taxi: fly the velocity wanted, any way the nose points,
			# but sideways and backwards only at a walking pace or so
			var wanted := along * want if d > 0.001 else Vector3.ZERO
			var wf := maxf(wanted.dot(fwd), -vmax * 0.35)
			var wr := clampf(wanted.dot(right), -vmax * 0.45, vmax * 0.45)
			a = (fwd * wf + right * wr - vel) * KV + along * slowing
		if fast > 0.0:
			# forward flight: hold the speed, and bank to swing the flight path
			# round onto the goal; a sharp turn is taken slower, and a goal too
			# close to turn onto at this speed means slowing down for it
			var dir := vel / spd
			var perp := Vector3.UP.cross(dir)
			var off := atan2(perp.dot(along), dir.dot(along))
			var speed := want * lerpf(1.0, 0.45, clampf((absf(off) - 0.9) / 1.6, 0.0, 1.0))
			var reach := d / (2.0 * maxf(sin(minf(absf(off), PI * 0.5)), 0.05))
			speed = minf(speed, sqrt(reach * side))
			var cruise := dir * ((speed - spd) * KV_CRUISE + slowing) + perp * clampf(off * spd * 1.1, -side, side)
			a = a.lerp(cruise, fast)
		a += vel * (drag * spd)
		var af := clampf(a.dot(fwd), -brake_max, accel_max)
		var ar := clampf(a.dot(right), -side, side)
		target_pitch = -atan(af / G)
		target_roll = -atan(ar / G)
		# no big flare close to the ground: the tail would strike it
		var tail_room := clampf((agl - 0.6) / float(s.tail), 0.0, 1.0)
		target_pitch = minf(target_pitch, maxf(0.06, asin(tail_room)))
	var p := VehicleMotion.slew(pitch, pitch_rate, target_pitch, cyclic, cyclic * 3.5, dt, false)
	pitch = p.x
	pitch_rate = p.y
	var r := VehicleMotion.slew(roll, roll_rate, target_roll, cyclic * 1.5, cyclic * 5.0, dt, false)
	roll = r.x
	roll_rate = r.y
	# The tilt of the disc is what moves her (the collective holds her up).
	var acceleration := fwd * (-G * tan(pitch)) + right * (-G * tan(roll)) - vel * (drag * spd)
	vel = Vector3.ZERO if on_gear else vel + acceleration * dt

	# --- collective
	var alt := route_height(v, goal, d, along, spd, ground, hang)
	var etl := smoothstep(0.15 * vmax, 0.45 * vmax, spd)
	var climb_max := float(s.climb) * (0.6 + 0.4 * etl) * (0.6 if loaded else 1.0)
	var sink_max := lerpf(2.0, 5.5, etl)
	var vaccel := float(s.vaccel) * (0.7 if loaded else 1.0)
	var err := alt - v.position.y
	var zplan := vaccel * 0.6
	var z0 := zplan / KZ
	var zd := absf(err) * KZ if absf(err) <= z0 / KZ else sqrt(z0 * z0 + 2.0 * zplan * (absf(err) - z0 / KZ))
	var vz_want := clampf(signf(err) * zd, -sink_max, climb_max)
	var a_z := clampf((vz_want - v.velocity.y) * KVZ, -vaccel, vaccel)
	lift = move_toward(lift, a_z, V_JERK * dt)
	var vz := v.velocity.y + lift * dt
	v.velocity = Vector3(vel.x, vz, vel.z)
	v.position += v.velocity * dt
	ground = maxf(0.0, v.world.ground_y(v.position))
	if v.position.y < ground + 0.15:
		v.position.y = ground + 0.15
		v.velocity.y = maxf(0.0, v.velocity.y)
		lift = maxf(0.0, lift)
	# Station keeping: once she's sat over the spot, hold it exactly rather
	# than creep about it by millimetres.
	var rest := Defs.flat(goal - v.position)
	if rest.length() < 0.03 and Defs.flat(v.velocity).length() < 0.03 and absf(pitch) < 0.004 and absf(roll) < 0.004:
		v.position.x = goal.x
		v.position.z = goal.z
		v.velocity.x = 0.0
		v.velocity.z = 0.0
	v.speed = Defs.flat(v.velocity).length()


## The height to fly at on the way to goal: CRUISE_AGL over the highest
## ground on the track ahead, coming down the glide path near the goal. The
## pilot reads the path a little ahead of where she is, so the descent starts
## in time rather than lagging behind it.
func route_height(v: Vehicle, goal: Vector3, d: float, along: Vector3, spd: float, ground: float, hang: float) -> float:
	var top := ground
	var reach := minf(d, 15.0 + spd * 2.5)
	if reach > 1.0:
		for f: float in [0.34, 0.67, 1.0]:
			top = maxf(top, maxf(0.0, v.world.ground_y(v.position + along * (reach * f))))
	# (with a load on the cable, high enough that it hangs well clear too)
	var cruise := top + maxf(CRUISE_AGL, hang + 10.0)
	var ahead := maxf(0.0, d - spd * LEAD)
	var glide := goal.y + maxf(0.0, ahead - 3.0) * GLIDE
	var height := maxf(goal.y, minf(cruise, glide))
	# A ridge short of the spot is never cut across on the glide path.
	return maxf(height, top + hang + clampf((ahead - 3.0) * GLIDE, 0.0, 6.0))


func settled(v: Vehicle, goal: Vector3, horizontal := 0.7, vertical := 0.12) -> bool:
	return Defs.flat(v.position - goal).length() < horizontal and absf(v.position.y - goal.y) < vertical \
		and Defs.flat(v.velocity).length() < 0.65 and absf(v.velocity.y) < 0.35
