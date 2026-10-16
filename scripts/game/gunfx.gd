class_name GunFx
extends Node3D
## Gunfire, drawn on the GPU: tracers, muzzle flashes, the smoke and brass a
## gun throws out, and what a round does to whatever it hits - earth spurting
## up, stone chips and grit, sandbag dust, splinters, leaves, sparks off
## steel, a splash. Each kind of thing is one MultiMesh drawn in one call: a
## shot writes a few instances into a ring and the vertex shader flies them
## from there (drag, gravity, wind, coming down on the ground), so nothing is
## moved from script once it has been spawned, however heavy the fire.

## Muzzle look per weapon sound: [flash radius, flame length, flame width,
## flash life, light, smoke, brass size (0: none), recoil kick, tracer share,
## tracer speed, tracer width]
const MUZZLE := {
	"pistol": [0.2, 0.3, 0.16, 0.04, 0.5, 0.3, 0.75, 0.55, 0.0, 480.0, 0.03],
	"rifle": [0.3, 0.62, 0.24, 0.045, 0.9, 0.45, 1.0, 1.0, 0.2, 520.0, 0.04],
	"smg": [0.26, 0.45, 0.2, 0.04, 0.75, 0.38, 0.85, 0.65, 0.12, 480.0, 0.035],
	"mg": [0.4, 0.9, 0.3, 0.05, 1.2, 0.6, 1.0, 0.85, 0.4, 540.0, 0.045],
	"minigun": [0.36, 0.7, 0.26, 0.035, 1.1, 0.5, 0.9, 0.3, 0.35, 600.0, 0.04],
	"hmg": [0.7, 1.4, 0.5, 0.06, 2.0, 1.1, 1.6, 1.3, 0.45, 560.0, 0.07],
	"gmg": [0.5, 0.65, 0.42, 0.06, 1.4, 1.2, 0.0, 1.0, 0.0, 300.0, 0.05],
	"ac": [1.05, 2.0, 0.75, 0.07, 2.8, 1.7, 2.1, 1.0, 0.6, 620.0, 0.1],
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
	_pf = _ring(quad, PUFF_SHADER, int(900 * maxf(fx, 0.5)), true, 0.0)
	_sp = _ring(quad, SPARK_SHADER, int(700 * maxf(fx, 0.5)), true, 0.7)
	_gr = _ring(quad, SPARK_SHADER.replace("blend_add", "blend_mix"), int(1400 * maxf(fx, 0.5)), true, 0.1)
	(_gr.mi.material_override as ShaderMaterial).set_shader_parameter("grit", true)
	_ch = _ring(box, CHUNK_SHADER, int(1100 * maxf(fx, 0.5)), false, 0.0)
	_br = _ring(box, "", 700, false, 0.0, _ch.mm.mesh, (_ch.mi.material_override as ShaderMaterial))
	for m in [_fl, _pf]:
		(m.mi.material_override as ShaderMaterial).set_shader_parameter("noise_tex", vfx.noise_tex)
	copy_lighting()
	for i in 10:
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
## water); wind_k: how much the wind carries it.
func puff(p: Vector3, v: Vector3, r0: float, r1: float, life: float, col: Color, drag := 2.0, rise := 0.0, grav := 0.0, wind_k := 1.0, delay := 0.0) -> void:
	_pf.put(Transform3D(Basis(v, Vector3(r0, r1, drag), Vector3(rise, wind_k, randf_range(-0.6, 0.6))), p), col, Color(_t0() + delay, life, randf(), grav))


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
	if Settings.fx_mult() < 0.5:
		return  # (low effects: no lights)
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

## A round leaving a muzzle at p, fired along dir: the flash, the flame
## thrown out ahead of it (and split out sideways by the flash hider or
## brake), a moment's light, a breath of smoke, the case spinning out of the
## ejection port, dust blown up off the ground under a gun fired low.
func muzzle(p: Vector3, dir: Vector3, kind: String, cam_d: float) -> void:
	shots += 1
	var m: Array = MUZZLE.get(kind, MUZZLE.rifle)
	var fx := Settings.fx_mult()
	var fr: float = m[0]
	var fl: float = m[1]
	var fw: float = m[2]
	var life: float = m[3]
	var k := randf_range(0.8, 1.2)
	flame(p - dir * 0.02, dir * fl * randf_range(0.7, 1.3), fw * k, life * 0.9, HOT)
	flash(p + dir * fr * 0.3, fr * k, life, HOT)
	if cam_d > 140.0:
		return
	if fl > 1.0 or randf() < 0.4:
		var side := dir.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 0.01 else Vector3.RIGHT
		side = side.rotated(dir, randf() * TAU if fl < 1.0 else randf_range(-0.3, 0.3))
		var sl := fl * randf_range(0.22, 0.38)
		flame(p + dir * 0.04, side * sl, fw * 0.55, life * 0.7, HOT)
		flame(p + dir * 0.04, -side * sl, fw * 0.55, life * 0.7, HOT)
	if cam_d < 90.0:
		light(p + dir * 0.4, float(m[4]), 3.0 + float(m[4]) * 2.6)
	var s: float = m[5]
	if cam_d < 110.0 and randf() < 0.8 * fx:
		puff(p + dir * 0.2 * s, dir * randf_range(1.2, 2.6) * sqrt(s) + _jit(0.3), 0.06 * s, randf_range(0.45, 0.8) * s, randf_range(1.3, 2.3), Color(0.62, 0.61, 0.58, 0.26 + 0.1 * minf(s, 1.5)), 2.8, 0.22)
	var gy := ground_y(p)
	var fd := Defs.flat(dir)
	if cam_d < 100.0 and p.y - gy < (0.75 if fl < 1.0 else 1.8) and fd.length() > 0.3 and randf() < 0.65 * fx:
		# fired low, the blast lifts the dust off the ground in front
		fd = fd.normalized()
		puff(Vector3(p.x, gy + 0.1, p.z) + fd * 0.5 * s, fd * randf_range(1.6, 3.2) * sqrt(s) + Vector3(0, 0.25, 0), 0.1 * s, randf_range(0.7, 1.1) * s, randf_range(1.6, 2.4), Color(0.5, 0.45, 0.37, 0.32), 2.4, 0.12)
	var bs: float = m[6]
	if bs > 0.0 and cam_d < 48.0 and randf() < fx:
		var right := dir.cross(Vector3.UP)
		right = right.normalized() if right.length_squared() > 0.01 else Vector3.RIGHT
		var bv := right * randf_range(1.8, 3.0) + Vector3(0, randf_range(1.6, 2.6), 0) - dir * randf_range(0.2, 0.9)
		chunk(p - dir * (0.35 + 0.1 * bs) + right * 0.05, bv, Vector3(0.011, 0.011, 0.04) * bs, randf_range(16.0, 26.0), BRASS, gy, 26.0, 0.4, 0.0, true)


## The round in flight: a tracer (in its side's colour) for one round in so
## many, and the barest streak for some of the others. Returns how long it
## takes to get there.
func round_flight(from: Vector3, to: Vector3, kind: String, team: int, cam_d: float) -> float:
	var m: Array = MUZZLE.get(kind, MUZZLE.rifle)
	var speed: float = m[9]
	var dist := from.distance_to(to)
	last_tracer = randf() < float(m[8])
	if last_tracer:
		var col: Color = TRACER_COLS[team] if team >= 0 and team < TRACER_COLS.size() else TRACER_HOT
		tracer(from, to, col, randf_range(6.5, 9.5) * (1.3 if float(m[10]) > 0.06 else 1.0), float(m[10]) * 1.4, speed)
	elif cam_d < 110.0 and randf() < 0.45 * Settings.fx_mult():
		tracer(from, to, Color(1.0, 0.9, 0.78, 0.55), 2.2, 0.012, speed)
	return minf(dist / speed, 0.45)


## What a round does to what it hit (Fx.HIT_*), at p, `back` pointing back
## along its path, `cal` its weight (1: a rifle round), shown after `delay`
## (when it gets there). Each is a fast, hard spray of grit with a small dense
## burst of dust at its heart, a few bigger bits thrown clear, and a haze
## that hangs on after.
func impact(kind: int, p: Vector3, back: Vector3, cal: float, cam_d: float, delay := 0.0) -> void:
	var q := clampf(1.3 - cam_d / 140.0, 0.3, 1.0) * Settings.fx_mult()
	cal *= 1.45  # (a little larger than life, to read from up where the camera is)
	var gy := ground_y(p)
	var sc := sqrt(cal)
	var up := Vector3.UP
	var ng := maxi(3, int(14.0 * q * sc))  # grains
	match kind:
		Fx.HIT_DIRT:
			# (into the water it's a spout: Fx._shot)
			# earth spurts up, mostly straight, a little back the way the round came
			var d := (up + back * 0.35).normalized()
			for i in ng:
				grit(p + Vector3(0, 0.03, 0), (d + _jit(0.38)).normalized() * randf_range(3.0, 8.5) * sc, randf_range(0.6, 1.0), Color(0.24, 0.18, 0.12, 0.95), 0.022 * sc, 0.035, 1.4, gy, delay)
			for i in maxi(2, int(3.0 * q * sc + 0.5)):
				puff(p + Vector3(0, 0.05, 0), (d + _jit(0.2)) * randf_range(5.0, 10.0) * sc, 0.03 * cal, randf_range(0.18, 0.3) * cal, randf_range(0.5, 0.8), Color(0.27, 0.21, 0.15, 0.9), 8.0, 0.0, 2.5, 0.3, delay)
			puff(p + Vector3(0, 0.12, 0), d * 0.8 + _jit(0.25), 0.1 * cal, randf_range(0.55, 0.8) * cal, randf_range(1.8, 2.6), Color(0.45, 0.4, 0.32, 0.22), 2.2, 0.2, 0.0, 1.0, delay + 0.02)
			for i in int(3.0 * q * cal + 1.0):
				var ce := randf_range(0.04, 0.07) * sc
				chunk(p + Vector3(0, 0.04, 0), (d + _jit(0.5)) * randf_range(2.0, 5.0) * sc, Vector3(ce, ce * 0.8, ce), randf_range(5.0, 9.0), Color(0.17, 0.13, 0.09) * randf_range(0.8, 1.15), gy, 14.0, 0.4, delay)
		Fx.HIT_STONE:
			# grit and dust blown hard back off the face, chips flying, now
			# and then a spark struck off it
			var d := (back + up * 0.25).normalized()
			for i in ng:
				grit(p + back * 0.03, (d + _jit(0.6)).normalized() * randf_range(4.0, 10.0) * sc, randf_range(0.4, 0.8), Color(0.36, 0.35, 0.33, 0.9), 0.018 * sc, 0.03, 1.6, gy, delay)
			for i in maxi(1, int(2.0 * q * sc + 0.5)):
				puff(p + back * 0.06, (d + _jit(0.35)) * randf_range(3.0, 6.0) * sc, 0.04 * cal, randf_range(0.22, 0.34) * cal, randf_range(0.7, 1.1), Color(0.5, 0.49, 0.46, 0.62), 6.5, 0.1, 0.5, 0.4, delay)
			puff(p + back * 0.2, back * 0.7 + _jit(0.25), 0.1 * cal, randf_range(0.55, 0.8) * cal, randf_range(1.8, 2.6), Color(0.52, 0.51, 0.49, 0.14), 2.0, 0.16, 0.0, 1.0, delay + 0.02)
			for i in int(3.0 * q * cal + 1.0):
				var ce := randf_range(0.03, 0.055) * sc
				chunk(p + back * 0.05, (d + _jit(0.7)) * randf_range(2.5, 6.0) * sc, Vector3(ce, ce * 0.6, ce * 0.9), randf_range(5.0, 8.0), Color(0.5, 0.49, 0.46) * randf_range(0.8, 1.2), gy, 18.0, 0.35, delay)
			if randf() < 0.25 + 0.2 * cal:
				flash(p + back * 0.05, 0.14 * sc, 0.035, Color(1.0, 0.8, 0.55, 0.7), delay)
				for i in randi_range(2, 4):
					spark(p + back * 0.03, (d + _jit(0.9)).normalized() * randf_range(4.0, 9.0), randf_range(0.12, 0.3), HOT, 0.01, 0.018, 2.0, 9.8, gy, delay)
		Fx.HIT_SAND:
			# sandbags and packed earth: a dry burst of sand and dust, no chips
			var d := (back * 0.8 + up * 0.6).normalized()
			for i in ng:
				grit(p + back * 0.03, (d + _jit(0.55)).normalized() * randf_range(3.0, 7.0) * sc, randf_range(0.5, 0.9), Color(0.47, 0.4, 0.28, 0.9), 0.016 * sc, 0.03, 1.8, gy, delay)
			for i in maxi(2, int(2.5 * q * sc + 0.5)):
				puff(p + back * 0.06, (d + _jit(0.4)) * randf_range(2.5, 5.0) * sc, 0.05 * cal, randf_range(0.26, 0.4) * cal, randf_range(0.7, 1.2), Color(0.5, 0.44, 0.32, 0.66), 6.0, 0.05, 1.5, 0.5, delay)
			puff(p + back * 0.2, back * 0.5 + _jit(0.25), 0.12 * cal, randf_range(0.6, 0.85) * cal, randf_range(1.8, 2.6), Color(0.52, 0.47, 0.38, 0.17), 2.0, 0.14, 0.0, 1.0, delay + 0.02)
		Fx.HIT_WOOD:
			# splinters torn out and a puff of light sawdust
			var d := (back + up * 0.3).normalized()
			for i in maxi(2, ng / 2):
				grit(p + back * 0.03, (d + _jit(0.6)).normalized() * randf_range(3.0, 8.0) * sc, randf_range(0.5, 0.9), Color(0.6, 0.47, 0.3, 0.95), 0.014 * sc, 0.035, 1.4, gy, delay)
			puff(p + back * 0.08, (d + _jit(0.3)) * randf_range(2.0, 4.0) * sc, 0.04 * cal, randf_range(0.26, 0.4) * cal, randf_range(0.9, 1.4), Color(0.58, 0.48, 0.34, 0.5), 4.5, 0.1, 0.4, 0.6, delay)
			for i in int(4.0 * q * cal + 1.5):
				var ln := randf_range(0.08, 0.18) * sc
				chunk(p + back * 0.05, (d + _jit(0.7)) * randf_range(2.5, 6.0) * sc, Vector3(ln * 0.2, ln * 0.2, ln), randf_range(6.0, 10.0), Color(0.62, 0.47, 0.29) * randf_range(0.75, 1.15), gy, 16.0, 0.5, delay)
		Fx.HIT_LEAVES:
			# leaves and twigs shot off, fluttering down; a puff of green dust
			for i in maxi(2, ng / 2):
				grit(p, (back + _jit(0.8)).normalized() * randf_range(2.0, 5.0), randf_range(0.3, 0.6), Color(0.2, 0.27, 0.1, 0.9), 0.014, 0.03, 2.5, gy, delay)
			puff(p + back * 0.1, back * 1.2 + _jit(0.5), 0.06 * cal, randf_range(0.4, 0.6) * cal, randf_range(1.2, 1.8), Color(0.3, 0.33, 0.18, 0.36), 3.0, 0.1, 0.0, 0.8, delay)
			for i in int(6.0 * q * cal + 2.5):
				var lf := randf_range(0.06, 0.1)
				var g := randf_range(0.7, 1.2)
				chunk(p + _jit(0.2), (back * randf_range(1.0, 3.0) + _jit(1.5) + up * 1.2), Vector3(lf, lf * 0.08, lf * 0.75), randf_range(6.0, 10.0), Color(0.18 * g, 0.26 * g, 0.08 * g), gy, 5.0, 3.6, delay)
		Fx.HIT_METAL:
			# sparks sprayed off the plate, a white-hot glint, a wisp of smoke
			var rd := (back + _jit(0.5)).normalized()
			flash(p + back * 0.05, 0.24 * sc, 0.045, Color(1.0, 0.8, 0.52, 1.0), delay)
			for i in maxi(4, int(11.0 * q * sc + 0.5)):
				spark(p + back * 0.04, (rd + _jit(0.85)).normalized() * randf_range(4.0, 14.0) * sc, randf_range(0.15, 0.5), HOT, 0.012, 0.022, 1.6, 9.8, gy, delay)
			puff(p + back * 0.1, back * 0.6 + _jit(0.3), 0.04, randf_range(0.26, 0.4) * cal, randf_range(0.9, 1.4), Color(0.42, 0.41, 0.4, 0.3), 3.0, 0.3, 0.0, 0.8, delay)
		Fx.HIT_FLESH:
			# a quick dark mist, most of it out the far side
			puff(p, (-back * randf_range(1.5, 3.0) + _jit(0.4)) * sc, 0.04, randf_range(0.26, 0.36) * sc, randf_range(0.3, 0.42), Color(0.3, 0.03, 0.02, 0.8), 7.0, 0.0, 2.0, 0.2, delay)
			puff(p, back * randf_range(0.6, 1.2) + _jit(0.3), 0.03, randf_range(0.14, 0.2) * sc, randf_range(0.25, 0.35), Color(0.34, 0.04, 0.03, 0.6), 7.0, 0.0, 1.0, 0.2, delay)
			for i in int(5.0 * q + 1.0):
				grit(p, (-back + _jit(0.6)).normalized() * randf_range(2.0, 4.5), randf_range(0.3, 0.6), Color(0.26, 0.02, 0.015, 0.9), 0.012, 0.025, 1.0, gy, delay)


## A ricochet: the round skips off in a new direction, glowing if it was a
## tracer, and throws sparks where it struck.
func ricochet(p: Vector3, dir: Vector3, bright: bool, delay := 0.0) -> void:
	var d := dir.normalized()
	var to := p + d * randf_range(10.0, 22.0) + Vector3(0, randf_range(1.0, 6.0), 0)
	tracer(p, to, TRACER_HOT if bright else Color(1.0, 0.78, 0.55, 1.6), 3.0 if bright else 1.6, 0.03 if bright else 0.015, 300.0, delay)
	for i in randi_range(3, 6):
		spark(p, (d + _jit(0.7)).normalized() * randf_range(4.0, 10.0), randf_range(0.12, 0.35), HOT, 0.012, 0.02, 1.6, 9.8, ground_y(p), delay)
	flash(p, 0.22, 0.035, Color(1.0, 0.8, 0.55, 1.0), delay)


## A tank's main gun: a blinding flash, a fireball thrown out ahead and a
## long tongue of flame, burning propellant flecks, a great cloud of smoke
## rolling out round the muzzle and, if it's low enough, the blast slapping
## the ground and driving a ring of dust out from under the gun.
func cannon_blast(p: Vector3, dir: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	flash(p + dir * 0.6, 2.6, 0.1, HOT)
	flash(p + dir * 2.4, 1.9, 0.13, Color(1.0, 0.5, 0.18, 1.0))
	flame(p, dir * randf_range(4.0, 5.5), 1.6, 0.09, HOT)
	light(p + dir * 1.5, 7.0, 18.0)
	if cam_d > 200.0:
		return
	for i in int(8 * fx) + 3:
		puff(p + dir * randf_range(0.5, 2.5), dir * randf_range(5.0, 15.0) + _jit(3.0), 0.4, randf_range(1.6, 2.6), randf_range(2.4, 3.8), Color(0.6, 0.58, 0.55, 0.4), 2.4, 0.3)
	for i in int(4 * fx) + 2:
		var sd := dir.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
		puff(p + dir * 0.3, sd * randf_range(3.0, 7.0) + dir * randf_range(1.0, 3.0) + _jit(1.0), 0.3, randf_range(1.1, 1.8), randf_range(2.0, 3.0), Color(0.58, 0.56, 0.53, 0.38), 2.6, 0.3)
	for i in int(12 * fx) + 4:
		spark(p + dir * 0.4, (dir + _jit(0.35)).normalized() * randf_range(14.0, 34.0), randf_range(0.2, 0.55), HOT, 0.03, 0.012, 2.4, 3.0)
	var gy := ground_y(p)
	var f := Defs.flat(dir)
	if p.y - gy < 4.5 and f.length() > 0.2:
		f = f.normalized()
		for i in int(12 * fx) + 4:
			var a := randf_range(-1.9, 1.9)
			var d := f.rotated(Vector3.UP, a)
			var gp := Vector3(p.x, gy + 0.35, p.z) + f * 1.2 + d * randf_range(0.3, 1.5)
			puff(gp, d * randf_range(5.0, 11.0) * (1.25 - absf(a) / 3.0) + Vector3(0, randf_range(0.3, 1.2), 0), 0.5, randf_range(1.6, 2.8), randf_range(2.2, 3.6), Color(0.5, 0.45, 0.36, 0.4), 2.6, 0.18, 0.0, 1.0, randf_range(0.0, 0.05))
	if vfx and fx >= 0.6:
		vfx._shockwave(p + dir * 0.8, 0.45)


## A rocket or missile leaving its launcher: flame and smoke out of both ends
## of the tube, and the back-blast kicking up the ground behind it.
func launch_blast(p: Vector3, dir: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	var d := dir.normalized()
	flash(p + d * 0.2, 0.7, 0.06, HOT)
	flame(p, d * 1.1, 0.45, 0.06, HOT)
	var bp := p - d * 1.0
	flame(bp, -d * randf_range(1.8, 2.6), 0.9, 0.08, HOT)
	flash(bp - d * 0.4, 1.0, 0.08, HOT)
	light(bp, 3.5, 9.0)
	if cam_d > 160.0:
		return
	for i in int(7 * fx) + 3:
		puff(bp - d * randf_range(0.0, 0.6), (-d + _jit(0.3)) * randf_range(7.0, 16.0), 0.25, randf_range(1.1, 2.0), randf_range(2.2, 3.4), Color(0.64, 0.62, 0.58, 0.48), 3.2, 0.25)
	for i in int(3 * fx) + 1:
		puff(p + d * 0.3, (d + _jit(0.4)) * randf_range(2.0, 4.0), 0.15, randf_range(0.6, 1.0), randf_range(1.6, 2.4), Color(0.66, 0.64, 0.6, 0.4), 3.0, 0.25)
	var gy := ground_y(bp)
	if bp.y - gy < 2.5:
		var f := Defs.flat(-d)
		f = f.normalized() if f.length() > 0.2 else Vector3.BACK
		for i in int(6 * fx) + 2:
			var g := f.rotated(Vector3.UP, randf_range(-1.1, 1.1))
			puff(Vector3(bp.x, gy + 0.2, bp.z) + g * randf_range(0.3, 1.2), g * randf_range(3.0, 8.0) + Vector3(0, 0.4, 0), 0.3, randf_range(1.2, 2.0), randf_range(2.2, 3.2), Color(0.5, 0.45, 0.36, 0.42), 2.6, 0.15)


## A mortar round leaving the tube: a bark of flame straight up, smoke and
## dust blown out round the base plate.
func mortar_blast(p: Vector3, cam_d: float) -> void:
	var fx := Settings.fx_mult()
	var up := Vector3.UP
	flame(p, up * randf_range(1.3, 1.8), 0.55, 0.06, HOT)
	flash(p + up * 0.3, 0.9, 0.06, HOT)
	light(p + up * 0.5, 3.0, 8.0)
	if cam_d > 160.0:
		return
	for i in int(4 * fx) + 2:
		puff(p + up * 0.3, (up + _jit(0.25)) * randf_range(3.0, 8.0), 0.2, randf_range(0.9, 1.6), randf_range(2.4, 3.4), Color(0.64, 0.62, 0.58, 0.45), 2.8, 0.3)
	var gy := ground_y(p)
	for i in int(6 * fx) + 2:
		var g := Vector3.FORWARD.rotated(up, randf() * TAU)
		puff(Vector3(p.x, gy + 0.15, p.z) + g * 0.4, g * randf_range(2.5, 5.0) + Vector3(0, 0.3, 0), 0.25, randf_range(0.8, 1.3), randf_range(1.8, 2.6), Color(0.5, 0.45, 0.36, 0.36), 2.8, 0.12)


## Draws each layer once out of sight, so their shaders are compiled during
## loading rather than at the first shot.
func prewarm(at: Vector3) -> void:
	var p := at + Vector3(0, -40.0, 0)
	tracer(p, p + Vector3(5, 0, 0), TRACER_HOT)
	flash(p, 0.3, 0.05, HOT)
	flame(p, Vector3(1, 0, 0), 0.3, 0.05, HOT)
	puff(p, Vector3.ZERO, 0.2, 0.5, 0.2, Color(0.5, 0.5, 0.5, 0.5))
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
		float w = max(prm.y, px * 2.2);
		v_k = clamp(prm.y / w, 0.45, 1.0);
		wp = p + side * (UV.x - 0.5) * w * 3.0;
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float a = UV.y;  // 0 at the head, 1 at the tail
	float core = exp(-x * x * 14.0);
	float halo = exp(-x * x * 3.0);
	float along = (1.0 - a) * (1.0 - a);
	vec3 c = v_col.rgb * (halo * 0.35 + core * 0.9) + vec3(1.0, 0.9, 0.8) * core * core * (1.0 - a) * 0.6;
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
uniform float intensity = 7.0;
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
			vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * prm.x * (0.85 + 0.35 * u);
			q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
			// drawn a little towards the camera, so the gun doesn't cut through it
			vec3 tc = normalize(cam - o);
			wp = o + tc * min(prm.x * 0.5, 0.3) + INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y;
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
		// the burst: a white-hot core, ragged spikes, a soft orange bloom
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float n = texture(noise_tex, vec2(ang * 0.3183 + v_seed * 3.0, v_seed * 7.0)).r;
		float spikes = pow(abs(cos(ang * 2.0 + v_seed * 11.0)), 14.0) + pow(abs(cos(ang * 3.0 + v_seed * 5.0)), 24.0) * 0.6;
		g = exp(-r * r * 16.0) * 1.8 + spikes * (0.4 + 0.9 * n) * exp(-r * 3.4) * 0.9 + exp(-r * 4.5) * 0.3;
		g *= 1.0 - smoothstep(0.75, 1.0, r);
		c = mix(v_col.rgb, vec3(1.0, 0.95, 0.86), exp(-r * r * 22.0));
	} else {
		// the flame: widest a little way out from the muzzle, torn to a point
		float x = UV.x * 2.0 - 1.0;
		float v = UV.y;
		float n = texture(noise_tex, vec2(UV.x * 0.3 + v_seed * 5.1, v * 0.45 + v_seed * 2.3)).r;
		float n2 = texture(noise_tex, vec2(UV.x * 0.8 + v_seed * 1.7, v * 1.3 - v_seed * 4.0)).g;
		float prof = sqrt(sin(3.14159 * clamp(v * 0.94 + 0.03, 0.0, 1.0))) * mix(1.0, 0.45, v);
		float edge = prof * (0.55 + 0.75 * n);
		float d = abs(x) + (n2 - 0.5) * 0.35 * v;
		float body = 1.0 - smoothstep(edge * 0.3, edge, d);
		float core = (1.0 - smoothstep(0.0, edge * 0.42, d)) * (1.0 - smoothstep(0.04, 0.55, v));
		g = body * (0.45 + 0.65 * (1.0 - v)) * (0.7 + 0.6 * n) + core * 1.5;
		c = mix(v_col.rgb, vec3(1.0, 0.93, 0.78), clamp(core, 0.0, 1.0));
	}
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	float soft = clamp((-vp.z / vp.w + VERTEX.z) / 0.2, 0.0, 1.0);
	ALBEDO = c * g * v_k * intensity * v_col.a * soft;
	ALPHA = 1.0;
}
"""

const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float now = 0.0;
uniform vec3 wind = vec3(0.6, 0.0, 0.25);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.0;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.8;
varying vec4 v_col;
varying float v_u;
varying float v_seed;
varying vec2 v_rot;
varying vec3 v_lv;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 sz = MODEL_MATRIX[1].xyz;  // radius at birth, radius at the end, drag
	vec3 mo = MODEL_MATRIX[2].xyz;  // rise, wind share, spin
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = cam + INV_VIEW_MATRIX[2].xyz;
	v_col = COLOR;
	v_seed = INSTANCE_CUSTOM.z;
	v_u = 1.0;
	v_rot = vec2(1.0, 0.0);
	v_lv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	if (age >= 0.0 && age < life) {
		float u = age / life;
		float k = max(sz.z, 0.05);
		vec3 p = o + v0 * ((1.0 - exp(-k * age)) / k) + wind * (mo.y * age);
		p.y += mo.x * age - 0.5 * INSTANCE_CUSTOM.w * age * age;
		float s = mix(sz.x, sz.y, 1.0 - pow(1.0 - u, 3.0));
		p.y = max(p.y, o.y - 0.3 + s * 0.3);
		float a = v_seed * 6.2831 + mo.z * age;
		v_rot = vec2(cos(a), sin(a));
		vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * s;
		q = vec2(q.x * v_rot.x - q.y * v_rot.y, q.x * v_rot.y + q.y * v_rot.x);
		wp = p + INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y;
		v_u = u;
	}
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	vec2 nuv = UV * 0.42 + vec2(v_seed * 5.31, v_seed * 9.17);
	vec3 t1 = texture(noise_tex, nuv + vec2(v_u * 0.07, v_u * 0.05)).rgb;
	vec3 t2 = texture(noise_tex, nuv * 2.03 + 0.37 - vec2(v_u * 0.1, 0.0)).rgb;
	float n = t1.r * 0.45 + t1.g * 0.3 + t2.g * 0.25;
	float edge = r + (0.5 - n) * (1.05 + v_u * 0.9);
	// (however the noise eats at it, nothing may reach the quad's edges)
	float shape = (1.0 - smoothstep(0.25, 0.95, edge)) * (1.0 - smoothstep(0.62, 0.98, r));
	// it tears into wisps as it spreads and thins
	shape *= mix(1.0, smoothstep(0.18, 0.62, t2.g * 0.6 + t1.b * 0.4), 0.3 + 0.4 * v_u);
	float fade = smoothstep(0.0, 0.04, v_u) * (1.0 - smoothstep(0.2, 1.0, v_u));
	float a = shape * v_col.a * fade;
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	a *= clamp((-vp.z / vp.w + VERTEX.z) / 0.35, 0.0, 1.0);
	// lit like a little volume: brighter on the sun's side, darker in the middle
	float nz = sqrt(max(0.0, 1.0 - min(r * r, 1.0)));
	vec3 ns = normalize(vec3(p * 0.8 + (vec2(t1.r, t2.r) - 0.5) * 0.8, nz + 0.35));
	vec3 nv = vec3(v_rot.x * ns.x - v_rot.y * ns.y, v_rot.y * ns.x + v_rot.x * ns.y, ns.z);
	float diff = clamp(dot(nv, v_lv) * 0.7 + 0.3, 0.0, 1.0);
	vec3 col = v_col.rgb * (sun_col * sun_energy * diff * mix(0.55, 1.0, n) + amb_col * amb_energy * (0.6 + 0.4 * n));
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
