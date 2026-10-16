class_name Fx
extends Node3D
## Client-side effects driven by server events: tracers, impacts, explosions,
## speech bubbles, dropped rifles, debris and falling trees.

const SHOT := 0
const EXPLODE := 1
const SAY := 2
const RIFLE_DROP := 3
const DEBRIS := 4
const CANNON := 5
const RICOCHET := 6
const SOUND := 7
const LAUNCH := 8
const MELEE := 9
const TREE_FALL := 10
const DELIVER := 11
const MORTAR := 12
const SUPPORT := 13
const FAR_SOUND := 14
const DIE := 15
const FIRE := 16  # a grass fire: [FIRE, pos, radius, seconds]
const BURNT_OUT := 17  # something burnt through falls in: [BURNT_OUT, pos, half extents, yaw]
const SINK := 18  # a boat founders: [SINK, eid, pos]

const TRACER_SPEED := 380.0

var world: World
var _tracer_pool: Array = []
var _tracers: Array = []  # [mi, from, to, t, len, width]
var _flash_pool: Array = []
var _flashes: Array = []  # [mi, t]
var _puffs := {}  # type -> [pool array, index]
var talk: Array = []  # what's being said right now: [eid, text, born msec, seconds]; the HUD draws it
var _movers: Array = []  # [node, vel, spin, t, life, rest]
var _craters: Array = []
var _lights: Array = []
var _light_i := 0
var vfx: Vfx


func _ready() -> void:
	if not world.has_view:
		return
	vfx = Vfx.new()
	vfx.name = "Vfx"
	vfx.world = world
	add_child(vfx)
	_prewarm.call_deferred()
	var tm := vfx.tracer_mat
	for i in 120:
		var mi := MeshInstance3D.new()
		mi.mesh = Res.box(Vector3(0.035, 0.035, 1.0))
		mi.material_override = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_tracer_pool.append(mi)
	var fm := vfx.flash_mat
	for i in 40:
		var f := MeshInstance3D.new()
		f.mesh = vfx.quad
		f.material_override = fm
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		add_child(f)
		_flash_pool.append(f)
	_make_puffs("blood", 16, Color(0.55, 0.05, 0.04, 0.9), 0.08, 8, 0.45, 2.0, Vector3(0, -6, 0))
	_make_puffs("wood", 12, Color(0.5, 0.36, 0.2, 1.0), 0.08, 8, 0.6, 3.0, Vector3(0, -9, 0))
	for i in 8:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.omni_range = 14.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)


func _prewarm() -> void:
	await get_tree().process_frame
	vfx.apply_lighting()
	var at := world.cam.focus_pos if world.cam else Vector3.ZERO
	vfx.prewarm(at)


func _make_puffs(kind: String, n: int, col: Color, size: float, amount: int, life: float, vel: float, grav: Vector3, glow := false) -> void:
	var arr := []
	for i in n:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = amount
		p.lifetime = life
		p.explosiveness = 0.95
		if kind in ["smoke", "dust", "fire"]:
			p.mesh = Res.quad(Vector2(size * 2.0, size * 2.0))
			p.material_override = Res.puff_mat(glow)
		else:
			p.mesh = Res.sphere(size, 5)
			p.material_override = Res.vcol_mat(true, glow)
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = vel * 0.4
		p.initial_velocity_max = vel
		p.gravity = grav
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		var g := Gradient.new()
		g.set_color(0, col)
		g.set_color(1, Color(col.r, col.g, col.b, 0.0))
		p.color_ramp = g
		p.local_coords = false
		add_child(p)
		arr.append(p)
	_puffs[kind] = [arr, 0]


func _puff(kind: String, pos: Vector3, dir := Vector3.UP) -> void:
	if kind in Vfx.SMALL_KINDS:
		vfx.puff(kind, pos, dir)
		return
	var entry: Array = _puffs.get(kind, [])
	if entry.is_empty():
		return
	var arr: Array = entry[0]
	var p: CPUParticles3D = arr[entry[1]]
	entry[1] = (entry[1] + 1) % arr.size()
	p.global_position = pos
	p.direction = dir
	p.restart()
	p.emitting = true


func stats_text() -> String:
	return "tracers %d  talk %d  movers %d  decals %d" % [_tracers.size(), talk.size(), _movers.size(), vfx._decals.size() if vfx else 0]


func _visible_at(p: Vector3) -> bool:
	return world.cam == null or world.cam.cam.global_position.distance_to(p) < 230.0


func play(ev: Array) -> void:
	if not world.has_view:
		return
	if world.director:
		match int(ev[0]):
			SHOT:
				world.director.note(ev[2], 0.15)
			EXPLODE:
				world.director.note(ev[1], 2.5 * float(ev[2]))
			CANNON, MORTAR:
				world.director.note(ev[1], 1.5)
			LAUNCH:
				world.director.note(ev[1], 1.0)
	match int(ev[0]):
		SHOT:
			_shot(_muzzle_of(ev, 5, ev[1], false), ev[2], int(ev[3]), String(ev[4]))
		EXPLODE:
			_explode(ev[1], float(ev[2]))
		SAY:
			_say(int(ev[1]), String(ev[2]))
		DIE:
			var ds = world.entity(int(ev[1]))
			if ds is Soldier and world.phys:
				world.phys.ragdoll(ds, ev[2], int(ev[3]))
		RIFLE_DROP:
			_rifle_drop(ev[1], ev[2])
		DEBRIS:
			_debris(ev[1], ev[2], int(ev[3]))
		CANNON:
			_cannon(_muzzle_of(ev, 3, ev[1], true), ev[2])
		RICOCHET:
			_ricochet(ev[1], ev[2])
		SOUND:
			Sfx.play(String(ev[1]), ev[2], -6.0)
		LAUNCH:
			_puff("smoke", ev[1], -ev[2])
			_flash(ev[1], 0.08, 1.5)
		MELEE:
			Sfx.play("thud", ev[1])
			_puff("dust", ev[1])
		TREE_FALL:
			_tree_fall(ev[1], float(ev[2]), int(ev[3]) if ev.size() > 3 else 0, int(ev[4]) if ev.size() > 4 else 0)
		MORTAR:
			Sfx.play("mortar", ev[1], -2.0)
			_flash(ev[1], 0.08, 1.8)
			_puff("smoke", ev[1] + Vector3(0, 0.5, 0))
		SUPPORT:
			if world.director:
				world.director.cue(ev[1], float(ev[2]))
			Sfx.ui("click")
		DELIVER:
			_float_text(ev[1], "+%d supply" % int(ev[2]), Color(0.5, 1.0, 0.5) if int(ev[3]) == world.local_team or world.local_team < 0 else Color(1, 1, 1, 0))
		FAR_SOUND:
			var dist := world.cam.focus_pos.distance_to(ev[3]) if world.cam and ev.size() > 3 else 0.0
			Sfx.play_far(String(ev[1]), float(ev[2]), 1.0, dist)
		FIRE:
			vfx.ground_fire(ev[1], float(ev[2]), float(ev[3]))
		BURNT_OUT:
			Sfx.play("thud", ev[1], -2.0, 0.7)
			if _visible_at(ev[1]):
				vfx.collapse(ev[1], ev[2])
		SINK:
			# (on a client the boat's already been cleared away by now)
			var sv = world.entity(int(ev[1]))
			if sv == null:
				sv = world.gone_entity(int(ev[1]))
			if sv is Vehicle and _visible_at(ev[2]):
				sv.sink_view()


## The muzzle as the shooter's model has it on this screen (the barrel tip of
## the rifle in his hands, the mounted gun he's on, the vehicle's gun), falling
## back to where the server fired from.
func _muzzle_of(ev: Array, idx: int, fallback: Vector3, main_gun: bool) -> Vector3:
	if ev.size() <= idx:
		return fallback
	var src = world.entity(int(ev[idx]))
	if src == null:
		return fallback
	var mp := Vector3.INF
	if src is Vehicle:
		mp = src.muzzle_world(main_gun)
	elif src is Soldier:
		mp = src.muzzle_world()
	if mp == Vector3.INF or mp.distance_to(fallback) > 4.0:
		return fallback
	return mp


func _shot(from: Vector3, to: Vector3, impact: int, snd: String) -> void:
	if not _visible_at(from) and not _visible_at(to):
		return
	if world.rng.randf() < (0.4 if snd in ["mg", "hmg"] else 0.18):
		_tracer(from, to, 1.5, 0.55)
	_flash(from, 0.05, 1.0)
	Sfx.play(snd, from, -4.0 if snd != "mg" else -2.0)
	if snd in ["mg", "hmg"] and world.cam and world.cam.dist < 30.0 and world.rng.randf() < 0.5:
		var side := (to - from).cross(Vector3.UP).normalized()
		_puff("brass", from, (side + Vector3.UP * 1.2).normalized())
	var dir := (from - to).normalized()
	if impact == 1 and to.y < 0.3 and world.water and not world.water.is_empty() and world.water.wet_at(to):
		# into the water: a spout, not dust
		var at := Vector3(to.x, WaterMap.LEVEL, to.z)
		_puff("water_spurt", at)
		if randf() < 0.3 and vfx.water_view():
			vfx.water_view().foam(at, randf_range(0.6, 0.9), 2.0, WaterView.BOIL)
		return
	match impact:
		1:
			_puff("dust", to, dir)
			if world.rng.randf() < 0.35:
				_puff("dirt_spurt", to, dir)
		2:
			_puff("blood", to, dir)
		3:
			_puff("spark", to, dir)
		4:
			_puff("wood", to, dir)


func _tracer(from: Vector3, to: Vector3, length: float, width: float) -> void:
	if _tracer_pool.is_empty():
		return
	var mi: MeshInstance3D = _tracer_pool.pop_back()
	mi.visible = true
	mi.scale = Vector3(width, width, length)
	_tracers.append([mi, from, to, 0.0, length])


func _flash(p: Vector3, life: float, size: float) -> void:
	if _flash_pool.is_empty():
		return
	var f: MeshInstance3D = _flash_pool.pop_back()
	f.global_position = p
	f.scale = Vector3.ONE * size * 0.6 * world.rng.randf_range(0.7, 1.3)
	f.set_instance_shader_parameter("rot", world.rng.randf() * TAU)
	f.visible = true
	_flashes.append([f, life])


func _light(p: Vector3, energy: float, rng_m: float) -> void:
	var l: OmniLight3D = _lights[_light_i]
	_light_i = (_light_i + 1) % _lights.size()
	l.global_position = p + Vector3(0, 1.5, 0)
	l.light_energy = energy
	l.omni_range = rng_m


func _explode(p: Vector3, size: float) -> void:
	if not world.srv and world.terrain:
		world.terrain.add_crater(p, size)
	var wet: bool = world.water and not world.water.is_empty() and p.y < 3.0 and world.water.wet_at(p)
	if wet and p.y < 1.2 and not _on_boat(p):
		# in the water: a column of spray, a ring of foam, no crater
		Sfx.play("explosion" if size >= 0.8 else "small_boom", p, 0.0)
		_light(p, 3.0 * size, 10.0 + 6.0 * size)
		if _visible_at(p):
			vfx.splash(Vector3(p.x, WaterMap.LEVEL, p.z), size)
		return
	Sfx.play("big_boom" if size >= 2.2 else ("explosion" if size >= 0.8 else "small_boom"), p, 4.0 if size >= 2.2 else (2.0 if size >= 1.3 else 0.0))
	_light(p, 4.5 * size, 12.0 + 9.0 * size)
	if _visible_at(p):
		vfx.explode(p, size)
		if wet:
			vfx.splash(Vector3(p.x, WaterMap.LEVEL, p.z), size * 0.45)  # (against a hull: spray round her)
		elif world.phys and p.y < 1.6 and size >= 1.2:
			world.phys.blast_chunks(p, size)
	if world._decor_node and p.y < 3.0 and size >= 0.8:
		world._decor_node.blast(p, size)
	# the blast rocks vehicles on their suspension
	for v in world.vehicles:
		if v.model and Defs.flat(v.position - p).length() < 5.0 + size * 5.0:
			v.blast_jolt(p, size)
	if wet:
		pass  # (no hole in the water)
	elif p.y < 1.6 and size >= 0.9:
		vfx.crater(p, size)  # permanent, wherever it lands: the ground remembers
	elif p.y < 1.6 and size >= 0.35 and world.atmo and world.atmo.grass:
		world.atmo.grass.scar(p, 0.8 + size * 1.5, 0.5)
	if world.cam:
		var d := world.cam.focus_pos.distance_to(p)
		if d < 50.0 and Settings.get_v("shake"):
			world.cam.shake(size * 0.5 * (1.0 - d / 50.0))


## A blast against a boat's hull (it burns, it doesn't splash).
func _on_boat(p: Vector3) -> bool:
	for v in world.vehicles:
		if v.is_boat() and not v.gone and Defs.flat(v.position - p).length() < v._hull_size().z * 0.5 + 1.0:
			return true
	return false


func _cannon(from: Vector3, to: Vector3) -> void:
	for v in world.vehicles:
		if v.model and v.position.distance_to(from) < 7.0:
			v.recoil((to - from).normalized())
			break
	Sfx.play("cannon", from, 3.0)
	_flash(from, 0.1, 5.0)
	_light(from, 6.0, 16.0)
	_puff("smoke", from)
	_puff("dust", Vector3(from.x, 0.2, from.z))
	_tracer(from, to, 4.0, 3.0)


func _ricochet(p: Vector3, dir: Vector3) -> void:
	_puff("spark", p, dir)
	Sfx.play("ricochet", p, -6.0)
	_tracer(p, p + dir.normalized() * 15.0 + Vector3(0, world.rng.randf_range(1, 5), 0), 1.5, 0.8)


var _said := {}  # text -> [pos, msec]: one bubble per shout per area


func _say(id: int, text: String) -> void:
	if not Settings.get_v("bubbles"):
		return
	var e: Entity = world.entity(id)
	if e == null or not e.seen_by_local():
		return
	var now := Time.get_ticks_msec()
	var prev: Array = _said.get(text, [])
	if not prev.is_empty() and now - int(prev[1]) < 2500 and (prev[0] as Vector3).distance_to(e.position) < 18.0:
		return
	_said[text] = [e.position, now]
	if world.cam and world.cam.cam.global_position.distance_to(e.position) > 160.0:
		return
	# long lines stay up long enough to read
	var dur := clampf(1.4 + text.length() * 0.055, 2.0, 5.0)
	for b in talk:
		if b[0] == id:
			b[1] = text
			b[2] = now
			b[3] = dur
			return
	talk.append([id, text, now, dur])


func _float_text(p: Vector3, text: String, col: Color) -> void:
	if col.a <= 0.0:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0013
	l.font_size = 28
	l.outline_size = 8
	l.no_depth_test = true
	l.render_priority = 127  # over roads and other see-through ground layers
	l.modulate = col
	add_child(l)
	l.global_position = p
	_movers.append([l, Vector3(0, 1.5, 0), Vector3.ZERO, 0.0, 2.5, false])


func _rifle_drop(p: Vector3, dir: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	Res.mi(n, Res.box(Vector3(0.06, 0.09, 0.85)), Res.mat(Color(0.12, 0.12, 0.12)), Vector3.ZERO, Vector3.ZERO, false)
	n.global_position = p
	_movers.append([n, dir * 3.5 + Vector3(0, 3.0, 0), Vector3(6, 3, 2), 0.0, 40.0, true])


func _debris(p: Vector3, col: Color, n: int) -> void:
	if not _visible_at(p):
		return
	if world.phys:
		world.phys.debris(p, col, n)
		_puff("dust", p)
		return
	for i in n:
		var b := MeshInstance3D.new()
		var s := world.rng.randf_range(0.12, 0.4)
		b.mesh = Res.box(Vector3(s, s * 0.6, s * 0.8))
		b.material_override = Res.mat(col.darkened(world.rng.randf_range(0.0, 0.3)))
		add_child(b)
		b.global_position = p + Vector3(world.rng.randf_range(-0.5, 0.5), world.rng.randf_range(0, 0.8), world.rng.randf_range(-0.5, 0.5))
		var v := Vector3(world.rng.randf_range(-5, 5), world.rng.randf_range(3, 9), world.rng.randf_range(-5, 5))
		_movers.append([b, v, Vector3(world.rng.randf_range(-8, 8), world.rng.randf_range(-8, 8), 0), 0.0, world.rng.randf_range(4.0, 9.0), true])
	_puff("dust", p)


## A felled tree: the same tree, toppling away from what hit it and staying
## where it falls (under physics when there is any).
func _tree_fall(p: Vector3, yaw: float, id: int, v: int) -> void:
	var n := Node3D.new()
	add_child(n)
	Structure.tree_model(n, id, v)
	var dir := Defs.dir_of(yaw)
	if world.phys:
		var k := 0.62 if (v & 15) == 1 else 1.0
		world.phys.prop(n, Transform3D(Basis.IDENTITY, p), dir * 1.0, Vector3.UP.cross(dir) * 0.9, Vector3(1.6, 7.0, 1.6) * k, 900.0 * k)
		return
	n.global_position = p
	n.rotation.y = yaw
	_movers.append([n, Vector3.ZERO, Vector3(-1.2, 0, 0), 0.0, 12.0, false, "tree"])


func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("fx", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view:
		return
	for i in range(_tracers.size() - 1, -1, -1):
		var t: Array = _tracers[i]
		t[3] += dt
		var from: Vector3 = t[1]
		var to: Vector3 = t[2]
		var total := from.distance_to(to)
		var head_d := minf(total, TRACER_SPEED * t[3])
		var tail_d := maxf(0.0, TRACER_SPEED * t[3] - float(t[4]))
		var mi: MeshInstance3D = t[0]
		if tail_d >= total - 0.01 or total < 0.1:
			mi.visible = false
			_tracer_pool.append(mi)
			_tracers.remove_at(i)
			continue
		var dir := (to - from) / total
		var a := from + dir * tail_d
		var b := from + dir * head_d
		var mid := (a + b) * 0.5
		var len := maxf(0.05, a.distance_to(b))
		mi.global_position = mid
		if absf(dir.dot(Vector3.UP)) < 0.99:
			mi.look_at(mid + dir, Vector3.UP)
		mi.scale.z = len
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i][1] -= dt
		if _flashes[i][1] <= 0.0:
			_flashes[i][0].visible = false
			_flash_pool.append(_flashes[i][0])
			_flashes.remove_at(i)
	for l in _lights:
		if l.light_energy > 0.0:
			l.light_energy = maxf(0.0, l.light_energy * exp(-dt * 7.0) - dt * 2.0)
	var now_ms := Time.get_ticks_msec()
	for i in range(talk.size() - 1, -1, -1):
		var b: Array = talk[i]
		if world.entity(int(b[0])) == null or now_ms - int(b[2]) > float(b[3]) * 1000.0:
			talk.remove_at(i)
	for i in range(_movers.size() - 1, -1, -1):
		var m: Array = _movers[i]
		var n: Node3D = m[0]
		m[3] += dt
		if m.size() > 6 and m[6] == "tree":
			n.rotation.x = maxf(-PI * 0.5, n.rotation.x - dt * (0.5 + m[3] * 2.0))
		else:
			var v: Vector3 = m[1]
			if m[5]:
				v.y -= 18.0 * dt
			n.global_position += v * dt
			n.rotation += m[2] * dt
			if m[5] and n.global_position.y < 0.05:
				n.global_position.y = 0.05
				v = Vector3.ZERO
				m[2] = Vector3.ZERO
			m[1] = v
		if n is Label3D:
			n.modulate.a = clampf(float(m[4]) - m[3], 0.0, 1.0)
		if m[3] > m[4]:
			n.queue_free()
			_movers.remove_at(i)
