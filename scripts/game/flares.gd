class_name Flares
extends RefCounted
## Illumination flares: a mortar's star shell, or an off-map battery's. The
## round's time fuze bursts it high over the target and throws out a canister
## of magnesium on a little parachute. It lights at once, burns for well over
## half a minute with a hard white light, and drifts down on the wind, the
## charge swinging under its chute like a pendulum, so every shadow on the
## ground below swings and lengthens with it.
##
## At night it is how a side sees: men spot only a fraction as far in the dark
## (Defs.NIGHT_SIGHT, through Vision and the soldiers' and vehicles' scans), but
## anyone standing in a flare's light is seen as far as by day - whichever side
## he's on. A flare over your own men shows them up as well as the enemy.
##
## The host decides: it bursts each flare (from world.rng) and sends it to
## every player once as an effect event (Fx.FLARE: id, burst point, burst time,
## burn, swing). Where a flare is at any moment is worked out from those alone
## (at), so every player's game, a replay and the host's rules all have it in
## the same place without anything more being sent.

var world: World
## Every flare still in the air: {id, p (burst point), t0, life, ph (swing phase), team}.
var list: Array[Dictionary] = []
var _next_id := 1
var _debug_at := Vector3(INF, INF, INF)


func _init(w: World) -> void:
	world = w
	var at := OS.get_environment("FL_DEBUG_FLARE_AT").split(",")
	if at.size() == 3:
		_debug_at = Vector3(at[0].to_float(), at[1].to_float(), at[2].to_float())


## (host) Where a star shell fired at `target` (on the ground) is fuzed to
## burst: high over it, a little higher or lower round by round.
func burst_point(target: Vector3) -> Vector3:
	return Vector3(target.x, world.ground_y(target) + float(Defs.FLARE.burst) + world.rng.randf_range(-6.0, 6.0), target.z)


## (host) Bursts a flare at `p` (in the air) for `team` (-1: nobody's).
func burst(p: Vector3, team: int) -> void:
	var fd: Dictionary = Defs.FLARE
	p.y = maxf(p.y, world.ground_y(p) + 12.0)  # (a round struck short still lights)
	var life := world.rng.randf_range(float(fd.life[0]), float(fd.life[1]))
	var ph := world.rng.randf() * TAU
	var id := _next_id
	_next_id += 1
	world.stat("flare_burst")
	if OS.has_environment("FL_DEBUG_FLARES"):
		print("FLARE %d t=%.1f at (%.0f, %.0f, %.0f) burns %.0f s, team %d" % [id, world.time, p.x, p.y, p.z, life, team])
	world.fx_event([Fx.FLARE, id, p, world.time, life, ph, team])
	add(id, p, world.time, life, ph, team)


## A flare as the effect event has it (on the host too, once only).
func add(id: int, p: Vector3, t0: float, life: float, ph: float, team: int) -> void:
	for f in list:
		if int(f.id) == id:
			return
	list.append({"id": id, "p": p, "t0": t0, "life": life, "ph": ph, "team": team})


## Drops the flares that have burnt out and fallen (see tick).
func tick() -> void:
	# FL_DEBUG_FLARE_AT=X,Z,T: (host) a flare bursts over (X, Z) at battle time T,
	# for renders that need one in a known place at a known moment
	if world.srv and _debug_at.x < INF and world.time >= _debug_at.z:
		burst(burst_point(Vector3(_debug_at.x, 0.0, _debug_at.y)), -1)
		_debug_at = Vector3(INF, INF, INF)
	if OS.has_environment("FL_DEBUG_FLARES") and fmod(world.time, 5.0) < 0.034:
		for f in list:
			var age := world.time - float(f.t0)
			var c := chute_at(f.p, age, float(f.ph))
			print("FLARE %d t=%.0f chute (%.0f, %.0f, %.0f) brightness %.2f" % [int(f.id), world.time, c.x, c.y - world.ground_y(c), c.z, brightness(age, float(f.life))])
	for i in range(list.size() - 1, -1, -1):
		var f := list[i]
		if world.time - float(f.t0) > float(f.life) + 6.0 or world.time < float(f.t0) - 1.0:
			list.remove_at(i)


## Where a flare's chute is `age` seconds after the burst: falling at its rate
## of descent, carried downwind (Fires.WIND) and wandering a little on the
## gusts. The canister opens the chute in the first second, so it drops faster
## until then.
static func chute_at(p: Vector3, age: float, ph: float) -> Vector3:
	var fd: Dictionary = Defs.FLARE
	var fall := float(fd.fall) * age + 3.0 * (1.0 - exp(-age * 2.5))
	var drift := Fires.WIND * float(fd.drift) * age
	var gust := Vector3(sin(age * 0.23 + ph) * 3.5, 0.0, cos(age * 0.17 + ph * 1.7) * 3.0)
	return Vector3(p.x, p.y - fall, p.z) + drift + gust


## The burning charge, hung below the chute on its shroud lines: it swings as a
## pendulum (a ~4 m line swings in about four seconds), the gusts feeding the
## swing in one direction and then another, so it never settles.
static func charge_at(p: Vector3, age: float, ph: float) -> Vector3:
	return chute_at(p, age, ph) + swing(age, ph)


## The charge's place below the chute (a vector down the shroud lines).
static func swing(age: float, ph: float) -> Vector3:
	var fd: Dictionary = Defs.FLARE
	var l := float(fd.line)
	var w := sqrt(9.8 / l)
	var amp := float(fd.swing) * (0.75 + 0.25 * sin(age * 0.31 + ph * 2.3))
	var ax := amp * sin(age * w + ph)
	var az := amp * 0.6 * sin(age * w * 1.07 + ph * 0.5 + 1.3)
	return Vector3(sin(ax) * l, -cos(ax) * cos(az) * l, sin(az) * l)


## How bright a flare is (0..1) at an age: it catches in the first moment
## after the burst, and gutters out over its last few seconds.
static func brightness(age: float, life: float) -> float:
	if age < 0.0 or age > life:
		return 0.0
	return clampf(age / 0.6, 0.0, 1.0) * clampf((life - age) / 3.0, 0.0, 1.0)


## How well a spot on the ground is lit by flares (0..1): full under a burning
## flare, falling off toward the edge of its light (Defs.FLARE lit_r).
func light_at(q: Vector3) -> float:
	var best := 0.0
	var r := float(Defs.FLARE.lit_r)
	for f in list:
		var age := world.time - float(f.t0)
		var b := brightness(age, float(f.life))
		if b <= 0.0:
			continue
		var c := chute_at(f.p, age, float(f.ph))
		var dx := c.x - q.x
		var dz := c.z - q.z
		var d2 := dx * dx + dz * dz
		if d2 >= r * r:
			continue
		best = maxf(best, b * (1.0 - 0.4 * sqrt(d2) / r))
	return best


## Lit enough to be seen as far as by day.
func lit(q: Vector3) -> bool:
	return not list.is_empty() and light_at(q) > 0.3


## Burning flares within `r` of a spot (for the AI: is it already lit, or soon).
func burning_near(q: Vector3, r: float) -> int:
	var n := 0
	for f in list:
		var age := world.time - float(f.t0)
		if age > float(f.life) - 8.0:
			continue  # (nearly out: worth another)
		var c := chute_at(f.p, maxf(age, 0.0), float(f.ph))
		if Vector2(c.x - q.x, c.z - q.z).length() < r:
			n += 1
	return n
