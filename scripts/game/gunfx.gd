class_name GunFx
extends Node3D
## Gunfire, drawn on the GPU: tracers, muzzle flashes, the smoke and brass a
## gun throws out, and what a round does to whatever it hits - earth spurting
## up, stone chips and grit, sandbag dust, splinters, leaves, sparks off
## steel, a splash. Each kind of thing is one MultiMesh drawn in one call: a
## shot writes a few instances into a ring and the vertex shader flies them
## from there (drag, gravity, wind, coming down on the ground), so nothing is
## moved from script once it has been spawned, however heavy the fire.

## Muzzle look per weapon sound, roughly to life: a rifle's flash is a hand's
## breadth of flame, a .50's a forearm's, an autocannon's a man's height.
## [flash radius, flame length, flame width, flash life, light, smoke, brass
## size (0: none), recoil kick, tracer share, tracer speed, tracer width]
const MUZZLE := {
	"pistol": [0.07, 0.15, 0.07, 0.03, 0.4, 0.12, 0.75, 0.55, 0.0, 380.0, 0.025],
	"rifle": [0.1, 0.3, 0.11, 0.035, 0.8, 0.22, 1.0, 1.0, 0.2, 800.0, 0.03],
	"smg": [0.09, 0.22, 0.09, 0.03, 0.6, 0.18, 0.85, 0.65, 0.12, 420.0, 0.028],
	"mg": [0.14, 0.42, 0.15, 0.04, 1.0, 0.35, 1.0, 0.85, 0.25, 780.0, 0.035],
	"minigun": [0.13, 0.36, 0.13, 0.03, 1.0, 0.3, 0.9, 0.3, 0.25, 820.0, 0.03],
	"hmg": [0.26, 0.8, 0.28, 0.045, 1.8, 0.7, 1.6, 1.3, 0.25, 850.0, 0.05],
	"gmg": [0.22, 0.38, 0.24, 0.05, 1.3, 0.8, 0.0, 1.0, 0.0, 240.0, 0.04],
	"ac": [0.5, 1.4, 0.5, 0.06, 2.6, 1.3, 2.1, 1.0, 0.5, 950.0, 0.07],
}
## Tracer colours: red for the Coalition's rounds, green for the Rebels'
## (the Soviet-pattern ammunition), a hot orange for anyone else's.
const TRACER_COLS := [Color(1.0, 0.2, 0.07, 9.0), Color(0.28, 1.0, 0.2, 8.0)]
const TRACER_HOT := Color(1.0, 0.45, 0.14, 8.5)
const HOT := Color(1.0, 0.58, 0.24, 1.0)
const BRASS := Color(0.74, 0.52, 0.2, 1.0)

var world: World
var vfx: Vfx
var now := 0.0  # the effects clock: game time, as the shaders see it
var shots := 0
var last_tracer := false  # whether the last round flown was a tracer
var _dt := 1.0 / 60.0
var _mats: Array[ShaderMaterial] = []
var _sorted: Array[MultiMeshInstance3D] = []  # see-through layers, sorted as if at the camera's focus
var _tr: Ring  # tracers, and the faint streak of the odd round without one
var _fl: Ring  # muzzle flashes and flames, glints where rounds strike steel
var _pf: Ring  # smoke, dust, spray, mist
var _sp: Ring  # sparks
var _gr: Ring  # grit: earth, stone, sand and splinters flung out fast, smeared by their speed
var _ch: Ring  # clods, chips, splinters, leaves
var _br: Ring  # brass, which lies where it falls a good while
var _lights: Array = []  # [light, energy]
var _light_i := 0


## A fixed number of instances, written round and round: the oldest one goes
## when a new one is wanted.
class Ring:
	var mm: MultiMesh
	var mi: MultiMeshInstance3D
	var i := 0

	func put(xf: Transform3D, col: Color, cd: Color) -> void:
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, col)
		mm.set_instance_custom_data(i, cd)
		i += 1
		if i >= mm.instance_count:
			i = 0


func _ready() -> void:
	# (before anything else this frame, so what's spawned now starts now)
	process_priority = -100
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var fx := Settings.fx_mult()
	_tr = _ring(quad, TRACER_SHADER, int(320 * maxf(fx, 0.6)), true, 0.6)
	_fl = _ring(quad, FLASH_SHADER, 200, true, 0.8)
	_pf = _ring(quad, PUFF_SHADER, int(1200 * maxf(fx, 0.5)), true, 0.0)
	_sp = _ring(quad, SPARK_SHADER, int(700 * maxf(fx, 0.5)), true, 0.7)
	_gr = _ring(quad, SPARK_SHADER.replace("blend_add", "blend_mix"), int(1400 * maxf(fx, 0.5)), true, 0.1)
	(_gr.mi.material_override as ShaderMaterial).set_shader_parameter("grit", true)
	_ch = _ring(box, CHUNK_SHADER, int(1100 * maxf(fx, 0.5)), false, 0.0)
	_br = _ring(box, "", 700, false, 0.0, _ch.mm.mesh, (_ch.mi.material_override as ShaderMaterial))
	for m in [_fl, _pf]:
		(m.mi.material_override as ShaderMaterial).set_shader_parameter("noise_tex", vfx.noise_tex)
	copy_lighting()
	for i in (0 if Vfx.gl else 10):  # (no lights in the browser build: see Fx)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.66, 0.34)
		l.light_energy = 0.0
		l.light_specular = 0.25
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append([l, 0.0])


func _ring(mesh: Mesh, code: String, cap: int, see_through: bool, sort_bias: float, share_mesh: Mesh = null, share_mat: ShaderMaterial = null) -> Ring:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = share_mesh if share_mesh else mesh
	mm.instance_count = cap
	# (the instances carry flight data, not transforms: the box is the map)
	var big := AABB(Vector3(-MapDims.HALF - 300.0, -100.0, -MapDims.HALF - 300.0), Vector3((MapDims.HALF + 300.0) * 2.0, 400.0, (MapDims.HALF + 300.0) * 2.0))
	mm.custom_aabb = big
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = big
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := share_mat
	if mat == null:
		var sh := Shader.new()
		sh.code = code
		mat = ShaderMaterial.new()
		mat.shader = sh
		_mats.append(mat)
	mi.material_override = mat
	if see_through:
		mi.sorting_use_aabb_center = false
		mi.set_meta("bias", sort_bias)
		_sorted.append(mi)
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var r := Ring.new()
	r.mm = mm
	r.mi = mi
	return r


## Copies the sun and sky light the smoke is lit by (Vfx.apply_lighting).
func copy_lighting() -> void:
	if vfx == null or vfx.smoke_mat == null:
		return
	var pm := _pf.mi.material_override as ShaderMaterial
	for k in ["sun_dir", "sun_col", "sun_energy", "amb_col", "amb_energy"]:
		var v = vfx.smoke_mat.get_shader_parameter(k)
		if v != null:
			pm.set_shader_parameter(k, v)
	pm.set_shader_parameter("wind", Fires.WIND)
	var gl = vfx.ejecta_mat.get_shader_parameter("light")
	if gl != null:
		(_gr.mi.material_override as ShaderMaterial).set_shader_parameter("light", gl)


func stats_text() -> String:
	return "shots %d" % shots


## When a thing spawned now starts on the effects clock: the server fires
## during the physics step, before this frame's clock has moved on.
func _t0() -> float:
	return now + (_dt if Engine.is_in_physics_frame() else 0.0)


func _process(dt: float) -> void:
	var _t0u := Time.get_ticks_usec()
	_dt = dt
	now += dt
	for m in _mats:
		m.set_shader_parameter("now", now)
	# the see-through layers sort against the other smoke and flames as if
	# they stood where the camera is looking
	if world.cam:
		var cp := world.cam.cam.global_position
		var d0 := cp.length()
		var df := cp.distance_to(world.cam.focus_pos)
		for mi in _sorted:
			mi.sorting_offset = d0 - df + float(mi.get_meta("bias"))
	for e in _lights:
		if float(e[1]) > 0.0:
			e[1] = float(e[1]) * exp(-dt * 38.0) - dt * 0.5
			var l: OmniLight3D = e[0]
			if float(e[1]) <= 0.02:
				e[1] = 0.0
				l.visible = false
			else:
				l.light_energy = e[1]
	world.vp("gunfx", _t0u)


func ground_y(p: Vector3) -> float:
	return world.terrain.deform_at(p) if world.terrain else 0.0


static func _jit(r: float) -> Vector3:
	return Vector3(randf_range(-r, r), randf_range(-r, r), randf_range(-r, r))


# --- the primitives -------------------------------------------------------------

## A glowing streak flying from `from` to `to`: `length` of it lit at once,
## `speed` metres a second. col.a is its brightness.
func tracer(from: Vector3, to: Vector3, col: Color, length := 6.0, width := 0.04, speed := 520.0, delay := 0.0) -> void:
	_tr.put(Transform3D(Basis(to - from, Vector3(length, width, speed), Vector3.ZERO), from), col, Color(_t0() + delay, 9.0, randf(), 0.0))


## A burst of light facing the camera (a muzzle seen end-on, a glint).
func flash(p: Vector3, radius: float, life: float, col: Color, delay := 0.0) -> void:
	_fl.put(Transform3D(Basis(Vector3.ZERO, Vector3(radius, 0.0, 0.0), Vector3.ZERO), p), col, Color(_t0() + delay, maxf(life, _dt * 1.6), randf(), 0.0))


## A tongue of flame thrown out along `axis` (its length), `width` across.
func flame(p: Vector3, axis: Vector3, width: float, life: float, col: Color, delay := 0.0) -> void:
	_fl.put(Transform3D(Basis(axis, Vector3(width, 0.0, 1.0), Vector3.ZERO), p), col, Color(_t0() + delay, maxf(life, _dt * 1.6), randf(), 0.0))


## A puff of smoke, dust, spray or mist. v: its speed at birth, which drag
## eats away; r0/r1: its radius at birth and at the end; rise: how fast it
## climbs on its own (smoke) and grav how fast it falls back (thrown earth,
## water); wind_k: how much the wind carries it; heat: for how many seconds
## it's still burning gas, glowing before it cools into smoke.
func puff(p: Vector3, v: Vector3, r0: float, r1: float, life: float, col: Color, drag := 2.0, rise := 0.0, grav := 0.0, wind_k := 1.0, delay := 0.0, heat := 0.0) -> void:
	_pf.put(Transform3D(Basis(v, Vector3(r0, r1, drag), Vector3(rise, wind_k, heat)), p), col, Color(_t0() + delay, life, randf(), grav))


## A hot spark flying off on `v`, smeared along its path, gone when it
## comes down to floor_y.
func spark(p: Vector3, v: Vector3, life: float, col: Color, width := 0.012, streak := 0.02, drag := 1.2, grav := 9.8, floor_y := -100.0, delay := 0.0) -> void:
	_sp.put(Transform3D(Basis(v, Vector3(streak, width, drag), Vector3(grav, floor_y, 0.0)), p), col, Color(_t0() + delay, life, randf(), 0.0))


## A grain of earth, grit or a splinter flung off fast, smeared along its
## path (as spark(), but solid and dark).
func grit(p: Vector3, v: Vector3, life: float, col: Color, width := 0.02, streak := 0.03, drag := 1.2, floor_y := -100.0, delay := 0.0) -> void:
	_gr.put(Transform3D(Basis(v, Vector3(streak, width, drag), Vector3(9.8, floor_y, 0.0)), p), col, Color(_t0() + delay, life, randf(), 0.0))


## A bit of something knocked off and thrown (a box `ext` big, tumbling at
## `spin`), lying where it lands on floor_y until `life` is up. Brass is
## metal and lies about longer (its own ring); the rest is earth, stone, wood.
func chunk(p: Vector3, v: Vector3, ext: Vector3, life: float, col: Color, floor_y: float, spin := 12.0, drag := 0.3, delay := 0.0, brass := false) -> void:
	(_br if brass else _ch).put(Transform3D(Basis(v, Vector3(1.0, spin, drag), ext), p), Color(col.r, col.g, col.b, 1.0 if brass else 0.0), Color(_t0() + delay, life, randf(), floor_y))


## A flash lighting up what's round it for a moment (the same gun firing
## again keeps its light).
func light(p: Vector3, energy: float, rng_m: float) -> void:
	if Settings.fx_mult() < 0.5 or _lights.is_empty():
		return  # (low effects, or the browser build: no lights)
	var e: Array = []
	for x in _lights:
		if float(x[1]) > 0.0 and (x[0] as OmniLight3D).global_position.distance_squared_to(p) < 4.0:
			e = x
			break
	if e.is_empty():
		e = _lights[_light_i]
		_light_i = (_light_i + 1) % _lights.size()
	var l: OmniLight3D = e[0]
	var k := vfx.fire_light if vfx else 1.0
	e[1] = maxf(float(e[1]), energy * k)
	l.global_position = p
	l.omni_range = rng_m
	l.light_energy = e[1]
	l.visible = true


# --- guns --------------------------------------------------------------------------

const SMOKE := Color(0.62, 0.61, 0.58)  # propellant smoke
const SOIL := Color(0.58, 0.52, 0.42)  # dry earth thrown up as dust (fine dust shows far paler than the ground)
const SOIL_GRIT := Color(0.3, 0.25, 0.18)


## A round leaving a muzzle at p, fired along dir. What you really see is a
## flash a hand's breadth across that's gone in a frame - a hot core and a
## short jet of flame, split into petals by the flash hider (or thrown out
## sideways by a heavy gun's muzzle brake) - the burning gas that follows the
## round out, glowing for an instant and cooling to a breath of smoke, a
## moment's light on what's round it, the case spinning out of the ejection
## port, and dust blown up off the ground under a gun fired low.
func muzzle(p: Vector3, dir: Vector3, kind: String, cam_d: float) -> void:
	shots += 1
	var m: Array = MUZZLE.get(kind, MUZZLE.rifle)
	var fx := Settings.fx_mult()
	var fr: float = m[0]
	var fl: float = m[1]
	var fw: float = m[2]
	var life: float = m[3]
	var s: float = m[5]
	var k := randf_range(0.8, 1.2)
	flame(p, dir * fl * randf_range(0.75, 1.25), fw * k, life, HOT)
	flash(p + dir * fr * 0.5, fr * k, life * 0.8, HOT)
	if cam_d > 140.0:
		return
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.01 else Vector3.RIGHT
	if fl > 0.7:
		# a heavy gun's muzzle brake throws the gas out to the sides
		var sl := fl * randf_range(0.3, 0.45)
		flame(p + dir * 0.03, (side + dir * 0.35).normalized() * sl, fw * 0.6, life * 0.8, HOT)
		flame(p + dir * 0.03, (-side + dir * 0.35).normalized() * sl, fw * 0.6, life * 0.8, HOT)
	elif randf() < 0.5:
		# the flash hider's prongs split it into a little star of petals
		var r0 := randf() * TAU
		for i in 3:
			var pd := (dir + side.rotated(dir, r0 + i * TAU / 3.0) * 0.7).normalized()
			flame(p, pd * fl * randf_range(0.35, 0.5), fw * 0.45, life * 0.7, HOT)
	if cam_d < 90.0:
		light(p + dir * 0.3, float(m[4]), 2.5 + float(m[4]) * 2.4)
	if cam_d < 110.0 and randf() < fx:
		# the gas behind the round: burning for an instant, then smoke
		puff(p + dir * 0.05, dir * randf_range(2.0, 4.0) * sqrt(s) + _jit(0.2), 0.02 + 0.03 * s, 0.08 + 0.22 * s, randf_range(0.35, 0.6), Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.3 + 0.15 * minf(s, 1.5)), 8.0, 0.15, 0.0, 0.5, 0.0, 0.03 + 0.03 * s)
		if randf() < 0.5:
			puff(p + dir * 0.25 * sqrt(s), dir * randf_range(0.6, 1.4) * sqrt(s) + _jit(0.15), 0.03 + 0.06 * s, (0.25 + 0.45 * s) * randf_range(0.8, 1.2), randf_range(1.2, 2.2), Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.08 + 0.06 * minf(s, 1.5)), 2.5, 0.2)
	var gy := ground_y(p)
	var fd := Defs.flat(dir)
	if cam_d < 100.0 and p.y - gy < (0.5 if fl < 0.7 else 1.6) and fd.length() > 0.3 and randf() < 0.6 * fx:
		# fired low, the blast lifts the dust off the ground in front
		fd = fd.normalized()
		puff(Vector3(p.x, gy + 0.08, p.z) + fd * 0.4 * sqrt(s), fd * randf_range(1.5, 3.0) * sqrt(s) + Vector3(0, 0.2, 0), 0.06 + 0.06 * s, (0.35 + 0.5 * s) * randf_range(0.8, 1.2), randf_range(1.4, 2.2), Color(SOIL.r, SOIL.g, SOIL.b, 0.22), 2.6, 0.1)
	var bs: float = m[6]
	if bs > 0.0 and cam_d < 48.0 and randf() < fx:
		var right := side
		var bv := right * randf_range(1.8, 3.0) + Vector3(0, randf_range(1.6, 2.6), 0) - dir * randf_range(0.2, 0.9)
		chunk(p - dir * (0.35 + 0.1 * bs) + right * 0.05, bv, Vector3(0.011, 0.011, 0.04) * bs, randf_range(16.0, 26.0), BRASS, gy, 26.0, 0.4, 0.0, true)


## 0 by day, 1 at night (from how much a fire lights up its surroundings).
func darkness() -> float:
	return clampf(((vfx.fire_light if vfx else 0.8) - 0.8) / 1.8, 0.0, 1.0)


## The round in flight: one in so many is a tracer, in its side's colour - a
## bright streak at night, a dimmer, shorter one by day (the others can't be
## seen at all). Returns how long the round takes to get there.
func round_flight(from: Vector3, to: Vector3, kind: String, team: int, _cam_d: float) -> float:
	var m: Array = MUZZLE.get(kind, MUZZLE.rifle)
	var speed: float = m[9]
	var dist := from.distance_to(to)
	last_tracer = randf() < float(m[8])
	if last_tracer:
		var col: Color = TRACER_COLS[team] if team >= 0 and team < TRACER_COLS.size() else TRACER_HOT
		var dark := darkness()
		col.a *= lerpf(0.4, 1.0, dark)
		# (lit for the length it covers while the eye holds it, a sixtieth or so)
		tracer(from, to, col, speed * 0.011 * lerpf(0.65, 1.0, dark) * randf_range(0.85, 1.15), float(m[10]), speed)
	return minf(dist / speed, 0.45)


## What a round does to what it hit (Fx.HIT_*), at p, `back` pointing back
## along its path, `cal` its weight (1: a rifle round), shown after `delay`
## (when it gets there). Real ones are small and quick: a fast cone of fine
## stuff blown out of the hole, dense for an instant, grains and a few bigger
## bits arcing clear, and a thin haze left drifting.
func impact(kind: int, p: Vector3, back: Vector3, cal: float, cam_d: float, delay := 0.0) -> void:
	var q := clampf(1.3 - cam_d / 140.0, 0.3, 1.0) * Settings.fx_mult()
	cal *= 1.1  # (a touch over life size, to read from where the camera is)
	var gy := ground_y(p)
	var sc := sqrt(cal)
	var up := Vector3.UP
	var ng := maxi(2, int(9.0 * q * sc))  # grains
	match kind:
		Fx.HIT_DIRT:
			# (into the water it's a spout: Fx._shot)
			# the crown of soil and dust thrown up out of the hole, a little back
			# the way the round came, falling back as it spreads
			var d := (up + back * 0.4).normalized()
			for i in maxi(3, int(6.0 * q * sc + 0.5)):
				puff(p + Vector3(0, 0.03, 0), (d + _jit(0.22)).normalized() * randf_range(3.5, 8.5) * sc, 0.04 * cal, randf_range(0.18, 0.3) * cal, randf_range(0.6, 1.1), Color(SOIL.r, SOIL.g, SOIL.b, 0.7), 7.0, 0.05, 1.2, 0.4, delay)
			puff(p + Vector3(0, 0.1, 0), d * 0.6 + _jit(0.2), 0.1 * cal, randf_range(0.42, 0.65) * cal, randf_range(1.6, 2.4), Color(SOIL.r, SOIL.g, SOIL.b, 0.18), 2.0, 0.15, 0.0, 1.0, delay + 0.03)
			for i in ng:
				grit(p + Vector3(0, 0.02, 0), (d + _jit(0.45)).normalized() * randf_range(2.5, 6.5) * sc, randf_range(0.5, 0.8), Color(SOIL_GRIT.r, SOIL_GRIT.g, SOIL_GRIT.b, 0.85), 0.013 * sc, 0.02, 1.6, gy, delay)
			for i in int(2.0 * q * cal + 0.8):
				var ce := randf_range(0.025, 0.045) * sc
				chunk(p + Vector3(0, 0.03, 0), (d + _jit(0.5)) * randf_range(2.0, 4.5) * sc, Vector3(ce, ce * 0.8, ce), randf_range(5.0, 9.0), Color(0.2, 0.16, 0.11) * randf_range(0.8, 1.15), gy, 14.0, 0.4, delay)
		Fx.HIT_STONE:
			# grit and stone dust blown hard back off the face, chips flying, now
			# and then a spark struck off it
			var d := (back + up * 0.2).normalized()
			for i in maxi(2, int(3.0 * q * sc + 0.5)):
				puff(p + back * 0.05, (d + _jit(0.3)).normalized() * randf_range(3.0, 6.5) * sc, 0.03 * cal, randf_range(0.14, 0.24) * cal, randf_range(0.5, 0.9), Color(0.58, 0.57, 0.54, 0.58), 8.0, 0.05, 0.6, 0.4, delay)
			puff(p + back * 0.15, back * 0.5 + _jit(0.2), 0.08 * cal, randf_range(0.38, 0.55) * cal, randf_range(1.4, 2.0), Color(0.57, 0.56, 0.54, 0.14), 2.0, 0.14, 0.0, 1.0, delay + 0.03)
			for i in ng:
				grit(p + back * 0.03, (d + _jit(0.55)).normalized() * randf_range(3.5, 8.0) * sc, randf_range(0.35, 0.65), Color(0.42, 0.41, 0.39, 0.85), 0.012 * sc, 0.02, 1.8, gy, delay)
			for i in int(2.0 * q * cal + 0.8):
				var ce := randf_range(0.02, 0.04) * sc
				chunk(p + back * 0.05, (d + _jit(0.7)) * randf_range(2.5, 5.5) * sc, Vector3(ce, ce * 0.6, ce * 0.9), randf_range(5.0, 8.0), Color(0.5, 0.49, 0.46) * randf_range(0.8, 1.2), gy, 18.0, 0.35, delay)
			if randf() < 0.2 + 0.15 * cal:
				flash(p + back * 0.04, 0.07 * sc, 0.03, Color(1.0, 0.82, 0.55, 0.8), delay)
				for i in randi_range(2, 3):
					spark(p + back * 0.03, (d + _jit(0.9)).normalized() * randf_range(4.0, 9.0), randf_range(0.1, 0.25), HOT, 0.008, 0.016, 2.0, 9.8, gy, delay)
		Fx.HIT_SAND:
			# sandbags and packed earth: a dry burst of sand and dust, no chips
			var d := (back * 0.8 + up * 0.6).normalized()
			for i in maxi(2, int(3.0 * q * sc + 0.5)):
				puff(p + back * 0.05, (d + _jit(0.32)).normalized() * randf_range(2.5, 5.5) * sc, 0.04 * cal, randf_range(0.18, 0.3) * cal, randf_range(0.6, 1.0), Color(0.56, 0.49, 0.37, 0.6), 7.0, 0.05, 1.0, 0.4, delay)
			puff(p + back * 0.15, back * 0.4 + _jit(0.2), 0.1 * cal, randf_range(0.42, 0.6) * cal, randf_range(1.5, 2.2), Color(0.55, 0.5, 0.4, 0.15), 2.0, 0.12, 0.0, 1.0, delay + 0.03)
			for i in ng:
				grit(p + back * 0.03, (d + _jit(0.5)).normalized() * randf_range(2.5, 6.0) * sc, randf_range(0.45, 0.75), Color(0.45, 0.38, 0.27, 0.85), 0.011 * sc, 0.02, 2.0, gy, delay)
		Fx.HIT_WOOD:
			# splinters torn out and a puff of pale sawdust
			var d := (back + up * 0.3).normalized()
			for i in maxi(2, ng / 2):
				grit(p + back * 0.03, (d + _jit(0.6)).normalized() * randf_range(3.0, 7.0) * sc, randf_range(0.45, 0.8), Color(0.62, 0.5, 0.33, 0.9), 0.011 * sc, 0.025, 1.5, gy, delay)
			puff(p + back * 0.06, (d + _jit(0.3)).normalized() * randf_range(1.5, 3.5) * sc, 0.03 * cal, randf_range(0.18, 0.28) * cal, randf_range(0.8, 1.2), Color(0.6, 0.5, 0.36, 0.42), 6.0, 0.08, 0.4, 0.6, delay)
			for i in int(3.0 * q * cal + 1.0):
				var ln := randf_range(0.06, 0.14) * sc
				chunk(p + back * 0.05, (d + _jit(0.7)) * randf_range(2.5, 5.5) * sc, Vector3(ln * 0.18, ln * 0.18, ln), randf_range(6.0, 10.0), Color(0.62, 0.47, 0.29) * randf_range(0.75, 1.15), gy, 16.0, 0.5, delay)
		Fx.HIT_LEAVES:
			# leaves and twigs shot off, fluttering down; a puff of green dust
			for i in maxi(2, ng / 2):
				grit(p, (back + _jit(0.8)).normalized() * randf_range(2.0, 4.5), randf_range(0.3, 0.55), Color(0.2, 0.27, 0.1, 0.85), 0.011, 0.025, 2.5, gy, delay)
			puff(p + back * 0.1, back * 0.9 + _jit(0.4), 0.05 * cal, randf_range(0.3, 0.45) * cal, randf_range(1.0, 1.6), Color(0.32, 0.34, 0.2, 0.28), 3.0, 0.08, 0.0, 0.8, delay)
			for i in int(5.0 * q * cal + 2.0):
				var lf := randf_range(0.05, 0.09)
				var g := randf_range(0.7, 1.2)
				chunk(p + _jit(0.2), (back * randf_range(1.0, 2.5) + _jit(1.3) + up * 1.0), Vector3(lf, lf * 0.08, lf * 0.75), randf_range(6.0, 10.0), Color(0.18 * g, 0.26 * g, 0.08 * g), gy, 5.0, 3.6, delay)
		Fx.HIT_METAL:
			# sparks sprayed off the plate, a white-hot glint, a wisp of smoke
			var rd := (back + _jit(0.5)).normalized()
			flash(p + back * 0.04, 0.1 * sc, 0.03, Color(1.0, 0.82, 0.55, 1.0), delay)
			for i in maxi(3, int(8.0 * q * sc + 0.5)):
				spark(p + back * 0.03, (rd + _jit(0.85)).normalized() * randf_range(4.0, 12.0) * sc, randf_range(0.12, 0.4), HOT, 0.009, 0.02, 1.6, 9.8, gy, delay)
			puff(p + back * 0.08, back * 0.5 + _jit(0.25), 0.03, randf_range(0.18, 0.28) * cal, randf_range(0.8, 1.2), Color(0.42, 0.41, 0.4, 0.22), 3.5, 0.25, 0.0, 0.8, delay)
		Fx.HIT_FLESH:
			# a quick dark mist, most of it out the far side
			puff(p, (-back * randf_range(1.5, 3.0) + _jit(0.3)) * sc, 0.03, randf_range(0.16, 0.24) * sc, randf_range(0.25, 0.35), Color(0.3, 0.03, 0.02, 0.65), 8.0, 0.0, 2.0, 0.2, delay)
			puff(p, back * randf_range(0.5, 1.0) + _jit(0.2), 0.02, randf_range(0.1, 0.14) * sc, randf_range(0.2, 0.3), Color(0.34, 0.04, 0.03, 0.5), 8.0, 0.0, 1.0, 0.2, delay)
			for i in int(3.0 * q + 1.0):
				grit(p, (-back + _jit(0.6)).normalized() * randf_range(2.0, 4.0), randf_range(0.25, 0.5), Color(0.26, 0.02, 0.015, 0.85), 0.01, 0.02, 1.0, gy, delay)


## A ricochet: the round skips off in a new direction, glowing if it was a
## tracer, and throws sparks where it struck.
func ricochet(p: Vector3, dir: Vector3, bright: bool, delay := 0.0) -> void:
	var d := dir.normalized()
	var to := p + d * randf_range(10.0, 22.0) + Vector3(0, randf_range(1.0, 6.0), 0)
	if bright:
		var col := TRACER_HOT
		col.a *= lerpf(0.4, 1.0, darkness())
		tracer(p, to, col, 3.0, 0.03, 450.0, delay)
	for i in randi_range(3, 5):
		spark(p, (d + _jit(0.7)).normalized() * randf_range(4.0, 10.0), randf_range(0.1, 0.3), HOT, 0.009, 0.018, 1.6, 9.8, ground_y(p), delay)
	flash(p, 0.08, 0.03, Color(1.0, 0.82, 0.55, 1.0), delay)


## A tank's main gun: a flash of fire the size of a car, gone in a blink, the
## burning gas rolling out ahead in a fireball that turns to smoke, flecks of
## burning propellant, a great cloud left hanging in front of the gun and,
## close to the ground, the blast driving a ring of dust out from under it
## that hides the tank for a moment.
func cannon_blast(p: Vector3, dir: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	flash(p + dir * 1.4, 2.0, 0.06, HOT)
	flame(p, dir * randf_range(3.5, 4.5), 1.6, 0.07, HOT)
	light(p + dir * 1.5, 7.0, 18.0)
	if cam_d > 200.0:
		return
	# the fireball: it's out at full size within a frame or two, burning,
	# and the smoke it turns into takes over from it
	for i in int(6 * fx) + 3:
		puff(p + dir * randf_range(0.6, 2.6) + _jit(0.35), (dir + _jit(0.35)) * randf_range(4.0, 10.0), 0.8, randf_range(1.4, 2.0), randf_range(0.4, 0.6), Color(0.5, 0.48, 0.45, 0.85), 6.0, 0.4, 0.0, 0.6, randf_range(0.0, 0.02), randf_range(0.14, 0.22))
	# the smoke left hanging in front of the gun
	for i in int(9 * fx) + 3:
		puff(p + dir * randf_range(0.8, 3.0), dir * randf_range(3.0, 9.0) + _jit(2.0), 0.9, randf_range(1.9, 3.0), randf_range(3.5, 5.5), Color(0.6, 0.58, 0.55, 0.34), 2.2, 0.3, 0.0, 1.0, randf_range(0.04, 0.12))
	for i in int(10 * fx) + 3:
		spark(p + dir * 0.4, (dir + _jit(0.3)).normalized() * randf_range(14.0, 32.0), randf_range(0.2, 0.5), HOT, 0.025, 0.012, 2.4, 3.0)
	var gy := ground_y(p)
	var f := Defs.flat(dir)
	if p.y - gy < 4.5 and f.length() > 0.2:
		f = f.normalized()
		for i in int(14 * fx) + 5:
			var a := randf_range(-2.0, 2.0)
			var d := f.rotated(Vector3.UP, a)
			var gp := Vector3(p.x, gy + 0.35, p.z) + f * 1.2 + d * randf_range(0.3, 1.5)
			puff(gp, d * randf_range(5.0, 12.0) * (1.25 - absf(a) / 3.0) + Vector3(0, randf_range(0.3, 1.2), 0), 0.6, randf_range(1.8, 3.2), randf_range(3.0, 5.0), Color(SOIL.r, SOIL.g, SOIL.b, 0.5), 2.6, 0.18, 0.0, 1.0, randf_range(0.0, 0.06))
	if vfx and fx >= 0.6:
		vfx._shockwave(p + dir * 0.8, 0.45)


## A rocket or missile leaving its launcher: flame out of both ends of the
## tube, the back-blast's burning gas turning to a cloud of smoke and kicking
## up the ground behind it.
func launch_blast(p: Vector3, dir: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	var d := dir.normalized()
	flame(p, d * 0.7, 0.3, 0.05, HOT)
	flash(p + d * 0.15, 0.3, 0.04, HOT)
	var bp := p - d * 1.0
	flame(bp, -d * randf_range(1.6, 2.4), 0.8, 0.07, HOT)
	flash(bp - d * 0.3, 0.6, 0.05, HOT)
	light(bp, 3.5, 9.0)
	if cam_d > 160.0:
		return
	for i in int(3 * fx) + 2:
		puff(bp - d * randf_range(0.0, 0.5), (-d + _jit(0.25)) * randf_range(6.0, 12.0), 0.2, randf_range(0.6, 1.0), randf_range(0.8, 1.2), Color(0.55, 0.53, 0.5, 0.7), 5.0, 0.3, 0.0, 0.6, 0.0, randf_range(0.06, 0.1))
	for i in int(6 * fx) + 3:
		puff(bp - d * randf_range(0.0, 0.6), (-d + _jit(0.3)) * randf_range(5.0, 13.0), 0.25, randf_range(1.0, 1.8), randf_range(2.4, 3.6), Color(0.64, 0.62, 0.58, 0.32), 3.0, 0.25)
	for i in int(2 * fx) + 1:
		puff(p + d * 0.3, (d + _jit(0.4)) * randf_range(2.0, 4.0), 0.12, randf_range(0.4, 0.7), randf_range(1.4, 2.2), Color(0.66, 0.64, 0.6, 0.25), 3.0, 0.25)
	var gy := ground_y(bp)
	if bp.y - gy < 2.5:
		var f := Defs.flat(-d)
		f = f.normalized() if f.length() > 0.2 else Vector3.BACK
		for i in int(6 * fx) + 2:
			var g := f.rotated(Vector3.UP, randf_range(-1.1, 1.1))
			puff(Vector3(bp.x, gy + 0.2, bp.z) + g * randf_range(0.3, 1.2), g * randf_range(3.0, 8.0) + Vector3(0, 0.4, 0), 0.3, randf_range(1.1, 1.8), randf_range(2.2, 3.2), Color(SOIL.r, SOIL.g, SOIL.b, 0.32), 2.6, 0.15)


## A mortar round leaving the tube: a bark of flame straight up, the gas
## cooling into a puff of smoke, dust blown out round the base plate.
func mortar_blast(p: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	var up := Vector3.UP
	flame(p, up * randf_range(1.0, 1.4), 0.4, 0.05, HOT)
	flash(p + up * 0.25, 0.4, 0.04, HOT)
	light(p + up * 0.5, 3.0, 8.0)
	if cam_d > 160.0:
		return
	for i in 2:
		puff(p + up * 0.25, (up + _jit(0.2)) * randf_range(4.0, 8.0), 0.12, randf_range(0.4, 0.6), randf_range(0.7, 1.0), Color(0.55, 0.53, 0.5, 0.65), 5.0, 0.3, 0.0, 0.6, 0.0, 0.06)
	for i in int(3 * fx) + 2:
		puff(p + up * 0.3, (up + _jit(0.25)) * randf_range(3.0, 7.0), 0.2, randf_range(0.8, 1.4), randf_range(2.4, 3.4), Color(0.64, 0.62, 0.58, 0.32), 2.8, 0.3)
	var gy := ground_y(p)
	for i in int(6 * fx) + 2:
		var g := Vector3.FORWARD.rotated(up, randf() * TAU)
		puff(Vector3(p.x, gy + 0.15, p.z) + g * 0.4, g * randf_range(2.5, 5.0) + Vector3(0, 0.3, 0), 0.25, randf_range(0.7, 1.2), randf_range(1.8, 2.6), Color(SOIL.r, SOIL.g, SOIL.b, 0.28), 2.8, 0.12)


## Draws each layer once out of sight, so their shaders are compiled during
## loading rather than at the first shot.
func prewarm(at: Vector3) -> void:
	var p := at + Vector3(0, -40.0, 0)
	tracer(p, p + Vector3(5, 0, 0), TRACER_HOT)
	flash(p, 0.3, 0.05, HOT)
	flame(p, Vector3(1, 0, 0), 0.3, 0.05, HOT)
	puff(p, Vector3.ZERO, 0.2, 0.5, 0.2, Color(0.5, 0.5, 0.5, 0.5), 2.0, 0.0, 0.0, 1.0, 0.0, 0.1)
	spark(p, Vector3.UP, 0.2, HOT)
	grit(p, Vector3.UP, 0.2, Color(0.2, 0.2, 0.2, 1.0))
	chunk(p, Vector3.UP, Vector3(0.05, 0.05, 0.05), 0.2, Color(0.2, 0.2, 0.2), p.y - 1.0)
	chunk(p, Vector3.UP, Vector3(0.01, 0.01, 0.04), 0.2, BRASS, p.y - 1.0, 10.0, 0.4, 0.0, true)


# --- shaders ------------------------------------------------------------------------
# Every instance carries its own flight in place of a transform (basis
# columns and origin, see the primitives above), its colour, and in its
# custom data [birth time, life, seed, extra]. Dead ones are folded up behind
# the camera, where nothing is drawn.

const TRACER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform float now = 0.0;
varying vec4 v_col;
varying float v_k;

void vertex() {
	vec3 from = MODEL_MATRIX[3].xyz;
	vec3 span = MODEL_MATRIX[0].xyz;
	vec3 prm = MODEL_MATRIX[1].xyz;  // length lit, width, speed
	float total = length(span);
	float age = now - INSTANCE_CUSTOM.x;
	float run = prm.z * age;
	float head = min(total, run);
	float tail = clamp(run - prm.x, 0.0, total);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	v_col = COLOR;
	v_k = 0.0;
	if (age >= 0.0 && tail < total - 0.01 && total > 0.05) {
		vec3 dir = span / total;
		vec3 p = from + dir * mix(head, tail, UV.y);
		vec3 to_p = p - cam;
		vec3 side = cross(dir, to_p);
		float sl = length(side);
		side = sl > 1e-5 ? side / sl : INV_VIEW_MATRIX[0].xyz;
		// never thinner than a pixel or two, however far off: it dims instead
		float px = length(to_p) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
		float w = max(prm.y, px * 1.6);
		v_k = clamp(prm.y / w, 0.45, 1.0);
		wp = p + side * (UV.x - 0.5) * w * 2.4;
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float a = UV.y;  // 0 at the head, 1 at the tail
	float core = exp(-x * x * 20.0);
	float halo = exp(-x * x * 4.0);
	float along = (1.0 - a) * (1.0 - a);
	vec3 c = v_col.rgb * (halo * 0.16 + core) + vec3(1.0, 0.9, 0.8) * core * core * (1.0 - a) * 0.5;
	ALBEDO = c * v_col.a * v_k * mix(0.04, 1.0, along) * smoothstep(0.0, 0.03, 1.0 - a + 0.01);
	ALPHA = 1.0;
}
"""

const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform float now = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// a depth read back to clip space: OpenGL's (the browser build's) runs -1..1, Vulkan's 0..1
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif
uniform float intensity = 5.0;
varying vec4 v_col;
varying float v_k;
varying float v_seed;
varying float v_kind;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[0].xyz;
	vec3 prm = MODEL_MATRIX[1].xyz;  // radius (a flame: its width), -, 0 a burst / 1 a flame
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	v_col = COLOR;
	v_seed = INSTANCE_CUSTOM.z;
	v_kind = prm.z;
	v_k = 0.0;
	if (age >= 0.0 && age <= life) {
		float u = age / max(life, 1e-4);
		v_k = pow(1.0 - u, 1.3);
		if (prm.z < 0.5) {
			float a = v_seed * 6.2831;
			// a flash is so bright it still twinkles a few pixels wide from far
			// off, however small it really is
			float px = length(o - cam) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
			float rad = max(prm.x, px * 3.0);
			v_k *= mix(1.0, clamp(prm.x / rad, 0.0, 1.0), 0.5);
			vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * rad * (0.85 + 0.35 * u);
			q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
			// drawn a little towards the camera, so the gun doesn't cut through it
			vec3 tc = normalize(cam - o);
			wp = o + tc * min(rad * 0.5, 0.3) + INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y;
		} else {
			float len = length(axis);
			vec3 dir = axis / max(len, 1e-4);
			float grow = 0.65 + 0.35 * min(u * 3.0, 1.0);
			vec3 p = o + dir * UV.y * len * grow;
			vec3 side = cross(dir, p - cam);
			float sl = length(side);
			side = sl > 1e-5 ? side / sl : INV_VIEW_MATRIX[0].xyz;
			wp = p + side * (UV.x - 0.5) * prm.x;
		}
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float g;
	vec3 c;
	if (v_kind < 0.5) {
		// the burst: a white-hot point in a ragged ball of orange gas
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float n = texture(noise_tex, vec2(ang * 0.159 + v_seed * 3.0, r * 0.25 + v_seed * 7.0)).r;
		float rr = r * (0.75 + 0.6 * n);
		g = exp(-r * r * 36.0) * 2.0 + exp(-rr * rr * 5.0) * 0.55;
		g *= 1.0 - smoothstep(0.7, 1.0, r);
		c = mix(v_col.rgb, vec3(1.0, 0.92, 0.74), exp(-r * r * 28.0));
	} else {
		// the flame: a narrow jet at the muzzle blooming into a ragged lick of
		// fire a little way out, torn away at the tip
		float x = UV.x * 2.0 - 1.0;
		float v = UV.y;
		float n = texture(noise_tex, vec2(UV.x * 0.35 + v_seed * 5.1, v * 0.5 + v_seed * 2.3)).r;
		float n2 = texture(noise_tex, vec2(UV.x * 0.9 + v_seed * 1.7, v * 1.6 - v_seed * 4.0)).g;
		float prof = mix(0.3, 1.0, smoothstep(0.0, 0.4, v)) * sqrt(1.0 - smoothstep(0.45, 1.0, v));
		float edge = prof * (0.5 + 0.8 * n);
		float d = abs(x) + (n2 - 0.5) * 0.45 * v;
		float body = 1.0 - smoothstep(edge * 0.25, edge, d);
		float core = (1.0 - smoothstep(0.0, edge * 0.4, d)) * (1.0 - smoothstep(0.05, 0.5, v));
		g = body * (0.4 + 0.6 * (1.0 - v)) * (0.6 + 0.7 * n) + core * 1.3;
		c = mix(v_col.rgb * vec3(1.0, 0.85, 0.75), vec3(1.0, 0.92, 0.75), clamp(core, 0.0, 1.0));
	}
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(dz), 1.0);
	float soft = clamp((-vp.z / vp.w + VERTEX.z) / 0.2, 0.0, 1.0);
	ALBEDO = c * g * v_k * intensity * v_col.a * soft;
	ALPHA = 1.0;
}
"""

## Smoke and dust as a little volume on a sprite: a density field from
## warped noise (dense at the heart, wispy and torn at the edges), shaded by
## how much of itself lies between each point and the sun, so it's lit on
## one side and in its own shadow on the other the way real smoke is - and,
## for a moment, hot gas glowing through it before it cools.
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float now = 0.0;
uniform vec3 wind = vec3(0.6, 0.0, 0.25);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// a depth read back to clip space: OpenGL's (the browser build's) runs -1..1, Vulkan's 0..1
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.0;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.8;
varying vec4 v_col;
varying float v_u;
varying float v_seed;
varying float v_heat;
varying vec3 v_ls;  // towards the sun in the sprite's own frame: across it, and (z) towards the camera

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 sz = MODEL_MATRIX[1].xyz;  // radius at birth, radius at the end, drag
	vec3 mo = MODEL_MATRIX[2].xyz;  // rise, wind share, seconds it's still burning gas
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	v_col = COLOR;
	v_seed = INSTANCE_CUSTOM.z;
	v_u = 1.0;
	v_heat = 0.0;
	v_ls = vec3(0.0, 0.0, 1.0);
	if (age >= 0.0 && age < life) {
		float u = age / life;
		float k = max(sz.z, 0.05);
		vec3 p = o + v0 * ((1.0 - exp(-k * age)) / k) + wind * (mo.y * age);
		p.y += mo.x * age - 0.5 * INSTANCE_CUSTOM.w * age * age;
		// it opens out fast, then slows as the air takes it
		float s = mix(sz.x, sz.y, 1.0 - pow(1.0 - u, 3.0));
		p.y = max(p.y, o.y - 0.3 + s * 0.3);
		float a = v_seed * 6.2831 + (v_seed - 0.5) * 1.4 * age;
		vec2 rc = vec2(cos(a), sin(a));
		vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * s;
		q = vec2(q.x * rc.x - q.y * rc.y, q.x * rc.y + q.y * rc.x);
		wp = p + INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y;
		v_u = u;
		v_heat = mo.z > 0.0 ? pow(clamp(1.0 - age / mo.z, 0.0, 1.0), 1.5) : 0.0;
		vec3 lv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
		v_ls = vec3(lv.x * rc.x + lv.y * rc.y, -lv.x * rc.y + lv.y * rc.x, lv.z);
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

// how thick the smoke is at p (-1..1 across the sprite)
float density(vec2 p, float u, float seed) {
	vec2 b = vec2(seed * 5.31, seed * 9.17);
	vec2 flow = vec2(u * 0.09, u * 0.06);
	vec3 w = texture(noise_tex, p * 0.18 + b + flow).rgb;
	// the outline itself is warped, so no two come out round
	vec2 pw = p + (w.rb - 0.5) * (0.55 + 0.35 * u);
	float n1 = texture(noise_tex, pw * 0.3 + b * 1.3 - flow).r;
	float n2 = texture(noise_tex, pw * 0.75 + b * 2.1 + flow * 1.5).g;
	float n = clamp((n1 * 0.65 + n2 * 0.35 - 0.5) * 1.8 + 0.5, 0.0, 1.0);
	float fall = 1.0 - smoothstep(0.1, 0.95, length(pw));
	// a dense heart going wispy as it spreads, eaten away from the edges in;
	// (and nothing may reach the quad's edges)
	return clamp(fall * (0.15 + 1.5 * n) - u * 0.45 * (1.0 - n), 0.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, length(p)));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float d = density(p, v_u, v_seed);
	// the smoke between here and the sun: sampled towards it across the
	// sprite, or (the sun behind or before it) its own thickness here. Seen
	// from the sun's side it's lit all over; from the far side the thick of
	// it is in its own shadow and only the thin edges glow.
	float ds = density(p + v_ls.xy * 0.45, v_u, v_seed);
	float thick = mix(ds, d, abs(v_ls.z) * 0.6);
	float lit = exp(-thick * mix(2.4, 0.35, v_ls.z * 0.5 + 0.5));
	float rim = pow(max(-v_ls.z, 0.0), 2.0) * (1.0 - smoothstep(0.0, 0.45, d)) * 0.6;
	// (the thick of it a little darker: it shades itself from the sky too)
	vec3 col = v_col.rgb * (sun_col * sun_energy * (lit * 0.9 + rim) + amb_col * amb_energy) * (1.0 - 0.22 * d * d);
	float fade = smoothstep(0.0, 0.03, v_u) * (1.0 - smoothstep(0.25, 1.0, v_u));
	float a = smoothstep(0.0, 0.85, d) * v_col.a * fade;
	if (v_heat > 0.0) {
		// burning gas: hottest in the thick of it, going sooty as it cools
		float h = v_heat * smoothstep(0.04, 0.5, d);
		vec3 fire = mix(vec3(0.55, 0.1, 0.02), vec3(1.0, 0.42, 0.08), smoothstep(0.1, 0.45, h));
		fire = mix(fire, vec3(1.0, 0.85, 0.55), smoothstep(0.5, 0.85, h));
		col *= mix(1.0, 0.5, v_heat * (1.0 - h));
		col = mix(col, fire * (0.8 + 7.0 * h * h), smoothstep(0.02, 0.25, h));
		a = clamp(a + h * 0.5 * v_col.a, 0.0, 1.0);
	}
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(dz), 1.0);
	a *= clamp((-vp.z / vp.w + VERTEX.z) / 0.35, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

const SPARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform float now = 0.0;
uniform float intensity = 7.0;
uniform bool grit = false;  // solid grains, not glowing sparks (drawn blend_mix)
uniform vec3 light = vec3(1.0);
varying vec4 v_col;
varying float v_k;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 prm = MODEL_MATRIX[1].xyz;  // streak (seconds of its path it smears over), width, drag
	vec3 gf = MODEL_MATRIX[2].xyz;   // gravity, the ground it dies on
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	v_col = COLOR;
	v_k = 0.0;
	if (age >= 0.0 && age < life) {
		float k = max(prm.z, 0.05);
		vec3 vt = vec3(0.0, -gf.x / k, 0.0);
		float e = exp(-k * age);
		vec3 p = o + vt * age + (v0 - vt) * ((1.0 - e) / k);
		vec3 v = vt + (v0 - vt) * e;
		if (p.y > gf.y) {
			float sp = length(v);
			vec3 dir = sp > 1e-3 ? v / sp : vec3(0.0, 1.0, 0.0);
			float len = max(sp * prm.x, prm.y * 2.0);
			vec3 a = p - dir * len * UV.y;
			vec3 side = cross(dir, a - cam);
			float sl = length(side);
			side = sl > 1e-5 ? side / sl : INV_VIEW_MATRIX[0].xyz;
			float px = length(a - cam) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
			float w = max(prm.y, px * 1.2);
			float u = age / life;
			v_k = clamp(prm.y / w, 0.3, 1.0) * (grit ? 1.0 - smoothstep(0.7, 1.0, u) : 1.0 - u * u);
			wp = a + side * (UV.x - 0.5) * w * 2.0;
		}
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	if (grit) {
		ALBEDO = v_col.rgb * light;
		ALPHA = clamp((1.0 - smoothstep(0.3, 1.0, abs(x))) * v_col.a * min(v_k * 1.6, 1.0) * (1.0 - UV.y * 0.6), 0.0, 1.0);
	} else {
		float core = exp(-x * x * 5.0);
		vec3 c = mix(v_col.rgb, vec3(1.0, 0.92, 0.75), (1.0 - UV.y) * 0.6 * v_k);
		ALBEDO = c * core * (1.0 - UV.y * 0.7) * v_k * intensity * v_col.a;
		ALPHA = 1.0;
	}
}
"""

const CHUNK_SHADER := """
shader_type spatial;
render_mode cull_back, skip_vertex_transform;
uniform float now = 0.0;
varying float v_metal;

vec3 at_time(vec3 o, vec3 v0, float k, float t, float flutter, float seed) {
	vec3 vt = vec3(0.0, -9.8 / k, 0.0);
	vec3 p = o + vt * t + (v0 - vt) * ((1.0 - exp(-k * t)) / k);
	// a leaf side-slips and see-saws as it falls
	p.xz += vec2(sin(t * 5.3 + seed * 40.0), cos(t * 4.1 + seed * 23.0)) * flutter * min(t * 2.0, 1.0);
	return p;
}

mat3 axis_angle(vec3 ax, float a) {
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(vec3(t * ax.x * ax.x + c, t * ax.x * ax.y + s * ax.z, t * ax.x * ax.z - s * ax.y),
		vec3(t * ax.x * ax.y - s * ax.z, t * ax.y * ax.y + c, t * ax.y * ax.z + s * ax.x),
		vec3(t * ax.x * ax.z + s * ax.y, t * ax.y * ax.z - s * ax.x, t * ax.z * ax.z + c));
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 prm = MODEL_MATRIX[1].xyz;  // -, spin, drag
	vec3 ext = MODEL_MATRIX[2].xyz;  // its size
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	float seed = INSTANCE_CUSTOM.z;
	float fy = INSTANCE_CUSTOM.w;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	vec3 nrm = vec3(0.0, 1.0, 0.0);
	v_metal = COLOR.a;
	if (age >= 0.0 && age < life) {
		float k = max(prm.z, 0.05);
		float flutter = prm.z > 2.0 ? 0.05 * prm.z : 0.0;
		float rest = min(min(ext.x, ext.y), ext.z) * 0.5;
		float tl = age;
		vec3 p = at_time(o, v0, k, age, flutter, seed);
		if (p.y < fy + rest) {
			// down: find when it landed, and leave it lying there
			float lo = 0.0;
			float hi = age;
			for (int i = 0; i < 9; i++) {
				float m = 0.5 * (lo + hi);
				if (at_time(o, v0, k, m, flutter, seed).y < fy + rest) {
					hi = m;
				} else {
					lo = m;
				}
			}
			tl = hi;
			p = at_time(o, v0, k, tl, flutter, seed);
			p.y = fy + rest;
		}
		vec3 ax = normalize(fract(sin(vec3(seed * 127.1, seed * 311.7, seed * 74.7)) * 43758.5453) - 0.5 + 1e-3);
		mat3 R = axis_angle(ax, seed * 6.2831 + prm.y * tl);
		float shrink = 1.0 - smoothstep(0.85, 1.0, age / life);
		wp = p + R * (VERTEX * ext * shrink);
		nrm = R * normalize(NORMAL / max(ext, vec3(1e-4)));
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * nrm);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.95, 0.3, v_metal);
	METALLIC = v_metal * 0.9;
}
"""
