class_name SnowMelt
extends RefCounted
## Snow melting off round the heat of the battle, in the snow weather: a fire
## thaws the ground round it to bare, wet earth with a rim of grey slush, and
## a vehicle standing with its engine running works the snow behind its
## exhaust to a small patch of slush (the engine's own warmth clears its deck:
## Vehicle._snow_view). The heat is the heat haze's (Vfx's fires and the
## vehicles' exhausts). Thawed ground stays thawed after the fire is out, and
## whitens again only slowly, while the snow keeps falling on it. Looks only:
## each view keeps its own, and nothing here reaches the simulation.
##
## Each patch is a spot: a centre, how far it reaches and how far it has
## melted (1 down to the earth). The ground and the roads are handed the
## SHOWN spots nearest the camera (melt_spots[], read by snow_melted()), and
## everything standing the nearest few (Mats.set_melt); the grass has them
## painted into its scar map (green), and a burning structure's spot melts the snow off the structure
## itself (melt_snow).

const SHOWN := 24  # (melt_spots[] in the ground and road shaders)
const MAX := 96
const STEP := 0.25  # s between updates
## Seconds of falling snow to whiten thawed ground again.
const REFREEZE := 900.0
## Seconds for a well-alight fire to clear the ground under it to the earth.
const FIRE_MELT := 14.0
## Seconds for an idling engine's exhaust to work the snow it blows on to
## slush, and as far as it gets (warm air, not a flame: it never reaches the
## earth), and how far the patch reaches (m).
const IDLE_MELT := 150.0
const IDLE_MAX := 0.55
const EXHAUST_REACH := 0.9
## How long a vehicle stands still before the snow under it starts to go.
const IDLE_AFTER := 10.0
## How fast a thaw spreads out to its full reach (m/s).
const SPREAD := 0.08

## The shaders' side (Mats.MELT_GLSL): snow_melted(p, rag), how far the snow
## at `p` has melted, 0 (lying) to 1 (bare).
const GLSL := Mats.MELT_GLSL

var atmo  # Atmosphere (null in a test)
## [x, z, reach, melt, reach it spreads to, key (0: left behind), owner, warmed
## this step, as drawn on its owner, as painted on the grass (melt, reach), core]
var spots: Array = []
var _keyed := {}  # key -> spot
var _idle := {}  # vehicle eid -> [where it stood, how long]
var _t := 0.0
var _shown := PackedVector4Array()
var _paint: Array = []  # spots to repaint on the grass
var _paved := PackedVector4Array()  # as everything standing has them (Mats.set_melt)


func _init(a = null) -> void:
	atmo = a


## Each view frame, while snow lies.
func tick(dt: float) -> void:
	_t += dt
	if _t < STEP:
		return
	_t -= STEP
	if _t > STEP:
		_t = 0.0  # (a long frame: don't race to catch up)
	var world: World = atmo.world
	if world.fx and world.fx.vfx:
		for h: Variant in world.fx.vfx.burning():
			if not is_instance_valid(h):
				continue
			var hn: Node3D = h
			var f := float(hn.get_meta("fire", 0.0))
			if f <= 0.02 or not hn.is_inside_tree() or not hn.is_visible_in_tree():
				continue
			var ext: Vector3 = hn.get_meta("ext", Vector3(0.5, 0.4, 0.5))
			var r := maxf(ext.x, ext.z)
			# (the wind carries the warm air off downwind)
			var at := hn.global_position + Fires.WIND.normalized() * (0.15 * r + 0.4)
			var who: Variant = hn.get_meta(&"melts") if hn.has_meta(&"melts") else null
			# (a big fire's heat reaches farther: bare from its own edge outward, then slush)
			warm(hn.get_instance_id(), at, r + 2.0 + 2.0 * f + 0.3 * r, r * 0.8 + 1.0, (0.4 + 0.6 * f) * STEP / FIRE_MELT, 1.0, who, r)
	for v in world.vehicles:
		_idling(v)
	settle(atmo.mood == "snow")
	_show(world)


## A vehicle's engine, running while it stands: once it's been still a while,
## the snow its exhaust blows on goes to slush, in a small patch just beyond
## the outlet. The engine's warmth goes up through its deck (Vehicle._snow_view),
## not down into the snow under the hull: a vehicle with no outlet of its own
## on its model leaves the ground as it was.
func _idling(v: Vehicle) -> void:
	if v.gone or v.model == null or v.is_air() or v.is_boat():
		_idle.erase(v.eid)
		return
	var p := v.global_position
	var rec: Array = _idle.get(v.eid, [])
	if rec.is_empty() or Defs.flat(p - (rec[0] as Vector3)).length() > 0.8:
		_idle[v.eid] = [p, 0.0]
		return
	rec[1] = float(rec[1]) + STEP
	if float(rec[1]) < IDLE_AFTER:
		return
	if v._vm == null or not v._vm.engine_vent.is_finite():
		return
	# (the warm gas blows out of the outlet away from the hull: the patch lies
	# a little beyond it, where it comes down on the snow)
	var vent: Vector3 = v._vm.engine_vent
	var out := Vector2(vent.x, vent.z)
	out = out / maxf(out.length(), 0.001)
	var at := v.model.global_transform * Vector3(vent.x + out.x * 0.6, 0.0, vent.z + out.y * 0.6)
	warm(-1 - v.eid, at, EXHAUST_REACH, EXHAUST_REACH * 0.4, STEP / IDLE_MELT, IDLE_MAX, null, 0.0)


## Heat on the snow at `at` this step, from the source `key`: its thaw spreads
## from `start` out to `reach` (m), bare across `core` (m) as it melts, and
## melts `rate` further, as far as `cap`.
## A source that has moved on leaves its old thaw behind and starts another.
func warm(key: int, at: Vector3, reach: float, start: float, rate: float, cap: float, who: Variant = null, core := 0.0) -> Array:
	var s: Array = _keyed.get(key, [])
	if not s.is_empty() and Vector2(at.x - float(s[0]), at.z - float(s[1])).length() > 1.5 + 0.3 * float(s[2]):
		s[5] = 0
		_keyed.erase(key)
		s = []
	if s.is_empty():
		if spots.size() >= MAX:
			_drop_one()
		s = [at.x, at.z, minf(start, reach), 0.0, reach, key, who, false, -1.0, -1.0, 0.0, 0.0]
		spots.append(s)
		_keyed[key] = s
	s[4] = maxf(float(s[4]), reach)
	s[11] = clampf(maxf(float(s[11]), core), 0.0, 30.0)
	s[2] = minf(float(s[4]), float(s[2]) + SPREAD * STEP)
	if float(s[3]) < cap:
		s[3] = minf(cap, float(s[3]) + rate)
	s[7] = true
	if who != null:
		s[6] = who
	return s


## The step's end: thaws nothing warmed whiten again while it snows, slowly,
## and go once they're white; their owners and the grass hear of the change.
func settle(snowing: bool) -> void:
	for i in range(spots.size() - 1, -1, -1):
		var s: Array = spots[i]
		if not bool(s[7]) and snowing:
			s[3] = float(s[3]) - STEP / REFREEZE
		s[7] = false
		if float(s[3]) <= 0.0:
			s[3] = 0.0
			_tell(s)
			_paint.append(s)
			spots.remove_at(i)
			if int(s[5]) != 0:
				_keyed.erase(int(s[5]))
			continue
		_tell(s)
		var q := snappedf(float(s[3]), 0.125)
		if q != float(s[9]) or float(s[2]) > float(s[10]) + 0.75:
			_paint.append(s)


## A burning structure's own snow follows the thaw it's in the middle of.
func _tell(s: Array) -> void:
	var who: Variant = s[6]
	if who == null:
		return
	if not is_instance_valid(who):
		s[6] = null
		return
	var q := snappedf(float(s[3]), 0.34 if Mats.per_material else 0.25)
	if q != float(s[8]):
		s[8] = q
		(who as Node).call(&"melt_snow", minf(q, 1.0))


## Out of room: the faintest thaw left behind goes first.
func _drop_one() -> void:
	var worst := -1
	var least := INF
	for i in spots.size():
		var s: Array = spots[i]
		var w := float(s[3]) * float(s[2]) * (4.0 if int(s[5]) != 0 else 1.0)
		if w < least:
			least = w
			worst = i
	if worst >= 0:
		var s: Array = spots[worst]
		s[3] = 0.0
		_paint.append(s)
		if int(s[5]) != 0:
			_keyed.erase(int(s[5]))
		spots.remove_at(worst)


## The ground and the roads take the thaws nearest the camera; the grass has
## the ones that changed painted in.
func _show(world: World) -> void:
	var c := Vector2.ZERO
	if world.cam:
		c = Vector2(world.cam.focus_pos.x, world.cam.focus_pos.z)
	var pick: Array = spots
	if spots.size() > SHOWN:
		pick = spots.duplicate()
		pick.sort_custom(func(a: Array, b: Array) -> bool:
			return c.distance_squared_to(Vector2(a[0], a[1])) - float(a[2]) * float(a[2]) < c.distance_squared_to(Vector2(b[0], b[1])) - float(b[2]) * float(b[2]))
		pick.resize(SHOWN)
	var out := PackedVector4Array()
	out.resize(SHOWN)
	for i in pick.size():
		var s: Array = pick[i]
		out[i] = Vector4(s[0], s[1], s[2], floorf(minf(float(s[11]), float(s[2]))) + float(s[3]) * 0.99)
	if out != _shown:
		_shown = out
		for m: ShaderMaterial in [atmo.ground_mat, atmo.road_mat]:
			if m:
				m.set_shader_parameter("melt_spots", out)
				m.set_shader_parameter("melt_n", pick.size())
	# (and everything standing, the THAWS nearest: Mats.set_melt)
	var near := pick.duplicate()
	near.sort_custom(func(a: Array, b: Array) -> bool:
		return c.distance_squared_to(Vector2(a[0], a[1])) - float(a[2]) * float(a[2]) < c.distance_squared_to(Vector2(b[0], b[1])) - float(b[2]) * float(b[2]))
	var few := PackedVector4Array()
	for i in mini(Mats.THAWS, near.size()):
		var s: Array = near[i]
		few.append(Vector4(s[0], s[1], s[2], floorf(minf(float(s[11]), float(s[2]))) + float(s[3]) * 0.99))
	if few != _paved:
		_paved = few
		Mats.set_melt(few)
	if not _paint.is_empty() and atmo.grass:
		for s in _paint:
			_paint_grass(atmo.grass, s)
		_paint.clear()


## Repaints the grass round the thaw `s` (the scar map's green: how far the
## snow on the grass there has melted), from every thaw that reaches there.
func _paint_grass(grass: Grass, s: Array) -> void:
	s[9] = snappedf(float(s[3]), 0.125)
	s[10] = float(s[2])
	var r := float(s[2]) + 1.0
	var lo := Vector2(float(s[0]) - r, float(s[1]) - r)
	var hi := Vector2(float(s[0]) + r, float(s[1]) + r)
	var near: Array = []
	for o in spots:
		var orr := float(o[2])
		if float(o[0]) + orr > lo.x and float(o[0]) - orr < hi.x and float(o[1]) + orr > lo.y and float(o[1]) - orr < hi.y:
			near.append(o)
	var img := grass.scar_img
	var half := MapDims.HALF
	var n := MapDims.N
	for z in range(maxi(0, floori(lo.y + half)), mini(n, ceili(hi.y + half))):
		for x in range(maxi(0, floori(lo.x + half)), mini(n, ceili(hi.x + half))):
			var px := x + 0.5 - half
			var pz := z + 0.5 - half
			var rag := (fposmod(sin(px * 12.9898 + pz * 78.233) * 43758.5453, 1.0) - 0.5) * 0.2
			var m := 0.0
			for o in near:
				var d := Vector2(px - float(o[0]), pz - float(o[1])).length()
				if d < float(o[2]):
					m = maxf(m, amount(d, float(o[2]), float(o[3]), rag, floorf(minf(float(o[11]), float(o[2])))))
			var cur := img.get_pixel(x, z)
			if absf(cur.g - m) > 0.01:
				img.set_pixel(x, z, Color(cur.r, m, 0.0))
	grass.scar_changed()


## How far a thaw reaching `reach`, bare across `core`, and melted `melt` has
## melted the snow `d` from its centre (as snow_melted() in the shaders).
static func amount(d: float, reach: float, melt: float, rag := 0.0, core := 0.0) -> float:
	return melt * (1.0 - smoothstep(0.45, 1.0, maxf(0.0, d - core) / maxf(reach - core, 0.5) + rag))
