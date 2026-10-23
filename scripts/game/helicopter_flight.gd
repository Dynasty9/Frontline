class_name HelicopterFlight
extends RefCounted
## A rotorcraft can accelerate sideways without pointing its nose that way.
## Guidance asks for a velocity, not a new position: momentum survives a new
## order, and the pilot brakes into a hover before descending onto the pad.

var pitch := 0.0
var roll := 0.0
var yaw_rate := 0.0


func step(v: Vehicle, goal: Vector3, dt: float, face := INF) -> void:
	if dt <= 0.0:
		return
	# Keep the same handling when a test or fast-forward uses a coarser tick.
	var left := dt
	while left > 0.00001:
		var h := minf(left, 1.0 / 30.0)
		_integrate(v, goal, h, face)
		left -= h


func _integrate(v: Vehicle, goal: Vector3, dt: float, face: float) -> void:
	var loaded := v.sling_cargo != null
	var accel := 3.5 if loaded else 7.0
	var brake := 5.0 if loaded else 8.0
	var vmax := float(v.vdef.speed) * (0.65 if loaded else 1.0)
	var to := Defs.flat(goal - v.position)
	var distance := to.length()
	# The final proportional approach avoids snapping to the destination;
	# stopping distance starts the flare well before the old arrival radius.
	var approach := minf(vmax, minf(sqrt(2.0 * brake * distance), distance * 1.5))
	var desired := to.normalized() * approach
	var before := Defs.flat(v.velocity)
	var slowing := desired.dot(before) < before.length_squared()
	var horizontal := before.move_toward(desired, (brake if slowing else accel) * dt)
	var acceleration := (horizontal - before) / dt
	var ground := maxf(0.0, v.world.ground_y(v.position))
	var ahead := v.position + horizontal * 0.8
	var ground_ahead := maxf(0.0, v.world.ground_y(ahead))
	# Craters must not pull the aircraft below sea level; raised lips are
	# anticipated in cruise. Touchdown is relative to the actual landing spot.
	var altitude := maxf(goal.y, ground_ahead + 0.15)
	var height_error := altitude - v.position.y
	# Reserve braking authority for the discrete step: using the full 4 m/s²
	# envelope here reaches the floor with residual speed before the last tick.
	var vertical_want := signf(height_error) * minf(6.0, minf(sqrt(6.0 * absf(height_error)), absf(height_error) * 1.5))
	var vertical := move_toward(v.velocity.y, vertical_want, 4.0 * dt)
	v.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	v.position += v.velocity * dt
	ground = maxf(0.0, v.world.ground_y(v.position))
	if v.position.y < ground + 0.15:
		v.position.y = ground + 0.15
		v.velocity.y = maxf(0.0, v.velocity.y)
	v.speed = horizontal.length()
	var heading := face
	if heading == INF:
		# Face the intended travel, but keep the last heading once hovering.
		if distance > 1.0:
			heading = Defs.yaw_of(to)
		else:
			heading = v.rotation.y
	var error := wrapf(heading - v.rotation.y, -PI, PI)
	var max_turn := minf(float(v.vdef.turn), 1.8) * (0.75 if loaded else 1.0)
	var wanted_rate := clampf(error * 3.0, -max_turn, max_turn)
	yaw_rate = move_toward(yaw_rate, wanted_rate, 4.0 * dt)
	v.rotation.y = wrapf(v.rotation.y + yaw_rate * dt, -PI, PI)
	var forward := Defs.dir_of(v.rotation.y)
	var right := forward.cross(Vector3.UP)
	# Cyclic follows actual acceleration, including the nose-up braking flare.
	# A little forward trim counters drag in cruise; a stationary yaw does not
	# manufacture a bank. These angles are sent by the host, not re-simulated.
	var thrust := acceleration + horizontal * 0.055
	var airborne := clampf((v.position.y - ground - 0.15) / 2.0, 0.0, 1.0)
	var target_pitch := clampf(-atan2(thrust.dot(forward), 9.81), -0.42, 0.42) * airborne
	var target_roll := clampf(-atan2(thrust.dot(right), 9.81), -0.48, 0.48) * airborne
	pitch = lerpf(pitch, target_pitch, 1.0 - exp(-dt * 5.0))
	roll = lerpf(roll, target_roll, 1.0 - exp(-dt * 5.0))


func settled(v: Vehicle, goal: Vector3, horizontal := 0.7, vertical := 0.12) -> bool:
	return Defs.flat(v.position - goal).length() < horizontal and absf(v.position.y - goal.y) < vertical \
		and Defs.flat(v.velocity).length() < 0.65 and absf(v.velocity.y) < 0.35
