class_name TimeOfDay
extends RefCounted
## Time passing in a battle (Settings > Lighting & Look > Time passes). The
## battle opens at its mood's hour and its clock runs on from there, faster
## than life: golden hour to full night in about forty minutes of battle.
##
## The light is worked out from two things only: the mood the battle began in
## and how long it has been going (World.time, which every player's game takes
## from the host). So every player sees the same sky at the same moment, and a
## replay or a seed brings the same light back. Nothing here keeps state.
##
## Between two moods on the clock the light blends from one to the next. The
## sun follows a path through each mood's own place in the sky, so the moment
## a mood is reached it looks as that mood always has. After sunset its light
## fades, and in the dark between the two the moon (the night mood's light)
## takes over; before dawn, the other way about. Rain, overcast and haze are
## weather, not a time of day: they hold.
##
## Night is light and nothing else: no rule in the simulation reads it
## (soldiers spot as far by night as by day). Should night ever change what
## soldiers see, the clock to use is already the host's.

## Seconds of the day that go by in a second of battle: golden hour to full
## night (16:30 to past 20:20, when the sun is 12 degrees down) in forty minutes.
const PACE := 6.0
## Battle seconds between one relighting and the next. The sun moves under a
## tenth of a degree in that time and the colours a few thousandths of the way from
## one mood to the next: too little to see a step, and the sky's lighting is
## worked out again only once a step (see Atmosphere._time_tick).
const STEP := 2.0

## The hour each mood on the clock stands for, where a battle in it begins.
## A night battle begins in the small hours, with a few hours of dark ahead.
const HOUR := {"dawn": 7.0, "day": 13.0, "golden": 16.5, "dusk": 18.5, "night": 1.0}
## The moods round the clock, [hour, mood], hours past 24 into the next day:
## the light blends from each to the next, and night holds from 21:30 until
## the sky starts to pale at 04:30.
const CLOCK := [[7.0, "dawn"], [13.0, "day"], [16.5, "golden"], [18.5, "dusk"], [21.5, "night"], [28.5, "night"]]
## The sun's way across the sky, [hour, elevation, azimuth] in degrees (an
## azimuth of 90 is east, +x; 0 south, +z), through each daylight mood's own
## sun and on round below the horizon. Azimuths run on past -180 so that the
## path never jumps; it repeats every day, 360 degrees further round.
const SUN_PATH := [[3.0, -30.0, 110.0], [5.0, -12.0, 90.0], [6.0, 0.0, 80.0], [7.0, 12.0, 70.0], [13.0, 52.0, -35.0],
	[16.5, 24.0, -60.0], [18.5, 9.0, -95.0], [19.25, 0.0, -103.0], [20.5, -14.0, -115.0], [22.0, -30.0, -130.0]]
## The sun's light comes up over these elevations (fully lit from the upper
## one, which every daylight mood's sun is above) ...
const SUN_UP := Vector2(-3.0, 8.0)
## ... and the moon's goes as the sun climbs through these: in the deep
## twilight between the two neither lights the ground, only the sky does.
const MOON_UP := Vector2(-10.0, -4.0)
## How much of the photographed midday sky shows, by how much of the light is
## midday's (it can't follow the sun far, so it gives way early).
const PHOTO := Vector2(0.7, 1.0)
## Twilight goes with the sun, not the clock: from a mood's own sun at dusk
## (or dawn) down to this elevation the sky turns to the night's; the sky
## is as dark as it gets once the sun is this far below the horizon (the end
## of nautical twilight).
const TWILIGHT_END := -12.0
## The blue hour: with the sun a few degrees down, the light left is the clear
## sky's, and sky, air and land go blue. Its colours (as the mood table's),
## laid over the blend of dusk (or dawn) and night as far as blue_hour() says.
const BLUE_HOUR := {"zenith": Color(0.07, 0.11, 0.27), "horizon": Color(0.36, 0.38, 0.55), "fog": Color(0.22, 0.27, 0.4)}
const BLUE_HOUR_MAX := 0.65
## Between sunset and moonlight there's a dark gap: the sky's light fails before
## the moon's is up. The eye opens up for it, so the exposure does too, by up
## to this much again (twilight_lift()): more under the physical sky, which
## goes darker after sunset than the painted one does.
const TWILIGHT_LIFT := {"physical": 1.1, "painted": 0.5}
## The last of the sun, and the first: so low it shines through so much air
## that little but the red gets through. Below dusk's (or dawn's) own sun the
## sunlight goes this far toward this colour by the time it sets.
const LOW_SUN := Color(1.0, 0.44, 0.24)
const LOW_SUN_MAX := 0.6


## Whether the clock runs for a battle that began in this mood.
static func runs(mood: String) -> bool:
	return HOUR.has(mood)


## The hour of the day, t seconds into a battle that began in this mood.
static func hour(start: String, t: float) -> float:
	return fposmod(float(HOUR.get(start, 12.0)) + t * PACE / 3600.0, 24.0)


## The sun's (elevation, azimuth) in degrees at an hour: a smooth curve
## (Catmull-Rom, by the hours) through SUN_PATH.
static func sun_at(h: float) -> Vector2:
	var n := SUN_PATH.size()
	var x := fposmod(h - float(SUN_PATH[0][0]), 24.0) + float(SUN_PATH[0][0])
	var i := n - 1
	for k in n - 1:
		if x < float(SUN_PATH[k + 1][0]):
			i = k
			break
	var a := _key(i - 1)
	var b := _key(i)
	var c := _key(i + 1)
	var d := _key(i + 2)
	var w := (x - b.x) / (c.x - b.x)
	if w <= 0.0:
		return Vector2(b.y, wrapf(b.z, -180.0, 180.0))
	var elev := cubic_interpolate_in_time(b.y, c.y, a.y, d.y, w, c.x - b.x, a.x - b.x, d.x - b.x)
	var azim := cubic_interpolate_in_time(b.z, c.z, a.z, d.z, w, c.x - b.x, a.x - b.x, d.x - b.x)
	return Vector2(elev, wrapf(azim, -180.0, 180.0))


## SUN_PATH's key k as (hour, elevation, azimuth), the path repeating each day.
static func _key(k: int) -> Vector3:
	var n := SUN_PATH.size()
	var day := floori(float(k) / float(n))
	var p: Array = SUN_PATH[posmod(k, n)]
	return Vector3(float(p[0]) + 24.0 * day, float(p[1]), float(p[2]) - 360.0 * day)


## Where an hour falls on the clock: [the mood before, the mood after, how far
## (0..1, eased) the light has gone from one to the other].
static func blend(h: float) -> Array:
	var first := float(CLOCK[0][0])
	var x := fposmod(h - first, 24.0) + first
	var n := CLOCK.size()
	for i in n:
		var to: Array = CLOCK[(i + 1) % n]
		var at := float(CLOCK[i][0])
		var next := float(to[0]) + (24.0 if i == n - 1 else 0.0)
		if x < next:
			return [String(CLOCK[i][1]), String(to[1]), smoothstep(0.0, 1.0, (x - at) / (next - at))]
	return [String(CLOCK[0][1]), String(CLOCK[0][1]), 0.0]


## Toward a body at this elevation and azimuth (degrees): the basis.z of a
## DirectionalLight3D turned to (-elevation, azimuth, 0).
static func toward(elev: float, azim: float) -> Vector3:
	var e := deg_to_rad(elev)
	var a := deg_to_rad(azim)
	return Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))


## The light t seconds into a battle that began in `start`:
##   hour      the hour of the day (-1 for weather, which holds)
##   mood      the mood the light is nearest
##   weights   mood -> share of the light (one at 1.0 on a mood's own hour)
##   d         the mood table's entry for this moment (Atmosphere.MOODS'
##             keys: the light's elevation, azimuth, colour, energy and
##             softness, the sky, the air, the exposure), plus `tint`, the
##             light's colour without the jump where the moon takes over
##   sun       the sun's own (elevation, azimuth), up or down
##   sun_moods [mood, mood, share]: the daylight moods the sun's own colour,
##             strength and (Physical sky's) air come from
##   up        how far up the light's body is (0..1: its light fading in or out)
##   lift      how far the eye opens up in the dark between sunset and moonlight
##             (0..1, times TWILIGHT_LIFT: the exposure goes up by that share)
##   sun_energy the sun's own strength, before the horizon takes it
##   photo     how much of the photographed midday sky shows
##   rim_azim  where the cool fill light comes from (opposite the light)
static func light(start: String, t: float) -> Dictionary:
	var moods: Dictionary = Atmosphere.MOODS
	if not runs(start):
		return still(start)
	var h := hour(start, t)
	var bl := blend(h)
	var a: String = bl[0]
	var b: String = bl[1]
	var k: float = bl[2]
	var sp := sun_at(h)
	if (a == "night") != (b == "night"):
		k = twilight(sp.x, float(moods[b if a == "night" else a].elev))
		if a == "night":
			k = 1.0 - k
	if a == b or k <= 0.0:
		b = a
		k = 0.0
	elif k >= 1.0:
		a = b
		k = 0.0
	var weights := {a: 1.0} if a == b else {a: 1.0 - k, b: k}
	var lift := 0.0
	var da: Dictionary = moods[a]
	var db: Dictionary = moods[b]
	var d := {}
	for key in ["zenith", "horizon", "fog"]:
		d[key] = _mix(da[key], db[key], k)
	for key in ["fog_d", "ambient", "clouds", "exposure"]:
		d[key] = _mixf(float(da[key]), float(db[key]), k)
	# the sun takes its colour and strength from the daylight moods alone:
	# nothing of the moonlight's blue in a sunset
	var sa := a if a != "night" else b
	var sb := b if b != "night" else a
	if sa == "night":
		sa = "dawn"
		sb = "dawn"
	var ks := k if sa != sb else 0.0
	var sun_col: Color = _mix(moods[sa].sun, moods[sb].sun, ks)
	if sa == sb and (a == "night") != (b == "night"):
		var low := 1.0 - smoothstep(-1.0, float(moods[sa].elev), sp.x)
		if low > 0.0:
			sun_col = sun_col.lerp(LOW_SUN, low * LOW_SUN_MAX)
	var sun_e := _mixf(float(moods[sa].energy), float(moods[sb].energy), ks)
	var sun_soft := _mixf(float(moods[sa].soft), float(moods[sb].soft), ks)
	var sun_up := smoothstep(SUN_UP.x, SUN_UP.y, sp.x)
	var moon_up := 1.0 - smoothstep(MOON_UP.x, MOON_UP.y, sp.x)
	var night: Dictionary = moods.night
	var by_moon := sun_up <= 0.0 and moon_up > 0.0
	if by_moon:
		d.elev = night.elev
		d.azim = night.azim
		d.sun = night.sun
		d.energy = float(night.energy) * moon_up if moon_up < 1.0 else night.energy
		d.soft = night.soft
	else:
		d.elev = sp.x
		d.azim = sp.y
		d.sun = sun_col
		d.energy = sun_e * sun_up if sun_up < 1.0 else sun_e
		d.soft = sun_soft
	if (a == "night") != (b == "night"):
		var blue := blue_hour(sp.x)
		if blue > 0.0:
			for key in BLUE_HOUR:
				d[key] = (d[key] as Color).lerp(BLUE_HOUR[key], blue * BLUE_HOUR_MAX)
		lift = twilight_lift(sp.x)
	var dark := float(weights.get("night", 0.0))
	d.tint = _mix(sun_col, night.sun, dark)
	# the fill light swings round with the light, not across in one go
	var rim := sp.y
	if dark >= 1.0:
		rim = float(night.azim)
	elif dark > 0.0:
		rim = rad_to_deg(lerp_angle(deg_to_rad(sp.y), deg_to_rad(float(night.azim)), dark))
	return {"hour": h, "mood": a if k < 0.5 else b, "weights": weights, "d": d, "sun": sp, "sun_moods": [sa, sb, ks], "up": moon_up if by_moon else sun_up, "lift": lift,
		"sun_energy": sun_e, "photo": smoothstep(PHOTO.x, PHOTO.y, float(weights.get("day", 0.0))), "rim_azim": rim + 180.0}


## How far the sky has gone from a day mood's (its sun at `key` degrees) to
## the night's, for a sun at `elev`: 0 at the mood's own sun, 1 from
## TWILIGHT_END down.
static func twilight(elev: float, key: float) -> float:
	return smoothstep(0.0, 1.0, clampf((key - elev) / (key - TWILIGHT_END), 0.0, 1.0))


## How deep in the blue hour a sun at `elev` puts the sky (0..1): from
## sunset, deepest with the sun 4 to 7 degrees down, gone into the night.
static func blue_hour(elev: float) -> float:
	return smoothstep(1.0, -4.0, elev) * (1.0 - smoothstep(-7.0, -12.0, elev))


## How far the eye opens up for the dark between sunset and moonlight (0..1):
## from a little before sunset, most with the sun 3 to 4 degrees down, gone as
## the moonlight comes in.
static func twilight_lift(elev: float) -> float:
	return smoothstep(4.0, -3.0, elev) * (1.0 - smoothstep(-4.0, -9.0, elev))


## A mood's light as it always is, the clock stopped (weather, or the setting off).
static func still(m: String) -> Dictionary:
	var d: Dictionary = Atmosphere.MOODS[m].duplicate()
	d.tint = d.sun
	return {"hour": -1.0, "mood": m, "weights": {m: 1.0}, "d": d, "sun": Vector2(float(d.elev), float(d.azim)),
		"sun_moods": [m, m, 0.0], "up": 1.0, "lift": 0.0, "sun_energy": float(d.energy), "photo": 1.0 if m == "day" else 0.0, "rim_azim": float(d.azim) + 180.0}


## a to b by k, exactly a at 0 and b at 1 (a mood's own hour gives its own values).
static func _mix(a: Color, b: Color, k: float) -> Color:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	return a.lerp(b, k)


static func _mixf(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	return lerpf(a, b, k)
