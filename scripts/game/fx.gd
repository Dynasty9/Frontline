class_name Fx
extends Node3D
## Client-side effects driven by server events: gunfire (GunFx), explosions,
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

## What a round struck, as a SHOT event carries it: it decides what flies off.
const HIT_DIRT := 1
const HIT_FLESH := 2
const HIT_METAL := 3
const HIT_WOOD := 4
const HIT_STONE := 5
const HIT_SAND := 6  # sandbags, earthworks
const HIT_LEAVES := 7  # a hedge, a tree's crown

var world: World
var gunfx: GunFx
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
	gunfx = GunFx.new()
	gunfx.name = "GunFx"
	gunfx.world = world
	gunfx.vfx = vfx
	add_child(gunfx)
	_prewarm.call_deferred()
	# (none in the browser build: the first time a light falls on something, the
	# browser compiles that thing's shaders again for it, a hitch mid-battle)
	for i in (0 if Vfx.gl else 8):
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
	gunfx.prewarm(at)


func _puff(kind: String, pos: Vector3, dir := Vector3.UP) -> void:
	vfx.puff(kind, pos, dir)


func stats_text() -> String:
	return "%s  talk %d  movers %d  decals %d" % [gunfx.stats_text() if gunfx else "", talk.size(), _movers.size(), vfx._decals.size() if vfx else 0]


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
	var wl: Wildlife = world.atmo.wildlife if world.atmo else null
	if wl and wl.level > 0:
		# the birds go up at gunfire, and everything runs from a shell; what a
		# round or a blast catches dies (for the eye only: the round flies on)
		match int(ev[0]):
			SHOT:
				wl.shot(ev[1], ev[2])
				wl.startle(ev[1], 40.0)
			EXPLODE:
				wl.blast(ev[1], float(ev[2]))
				wl.startle(ev[1], 55.0 + 30.0 * float(ev[2]))
			CANNON, MORTAR:
				wl.startle(ev[1], 75.0)
			LAUNCH:
				wl.startle(ev[1], 45.0)
			FIRE:
				wl.fire(ev[1], float(ev[2]), float(ev[3]))
			TREE_FALL:
				wl.startle(ev[1], 25.0)
	match int(ev[0]):
		SHOT:
			_shot(_muzzle_of(ev, 5, ev[1], false), ev[2], int(ev[3]), String(ev[4]), world.entity(int(ev[5])) if ev.size() > 5 else null)
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
			_cannon(_muzzle_of(ev, 3, ev[1], true), ev[2], world.entity(int(ev[3])) if ev.size() > 3 else null)
		RICOCHET:
			_ricochet(ev[1], ev[2])
		SOUND:
			Sfx.play(String(ev[1]), ev[2], -6.0)
		LAUNCH:
			_launch(ev[1], ev[2], world.entity(int(ev[3])) if ev.size() > 3 else null)
		MELEE:
			Sfx.play("thud", ev[1])
			_puff("dust", ev[1])
		TREE_FALL:
			_tree_fall(ev[1], float(ev[2]), int(ev[3]) if ev.size() > 3 else 0, int(ev[4]) if ev.size() > 4 else 0)
		MORTAR:
			Sfx.play("mortar", ev[1], -2.0)
			gunfx.mortar_blast(ev[1], _cam_d(ev[1]))
		SUPPORT:
			if world.director:
				world.director.cue(ev[1], float(ev[2]))
			Sfx.ui("click")
		DELIVER:
			_float_text(ev[1], "+%d SUP" % int(ev[2]), UiKit.GOOD if int(ev[3]) == world.local_team or world.local_team < 0 else Color(1, 1, 1, 0))
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
	if mp == Vector3.INF:
		return fallback
	return mp


## How heavy a round each gun fires, for what it does where it lands.
const CAL := {"pistol": 0.6, "smg": 0.75, "rifle": 1.0, "minigun": 0.9, "mg": 1.1, "hmg": 1.8, "gmg": 1.3, "ac": 2.4}


## What a round that stopped in `st` at hp looks like going in.
static func surface_of(st: Structure, hp: Vector3) -> int:
	match String(st.skind):
		"crates", "watchtower", "fence", "dock":
			return HIT_WOOD
		"tree":
			return HIT_LEAVES if hp.y > 2.3 else HIT_WOOD
		"low_wall":
			return HIT_LEAVES if st.variant % 3 == 1 else HIT_STONE  # (a hedge)
		"sandbags", "mg_nest", "hmg_nest", "mortar_pit", "at_post", "trench", "fob", "tunnel", "medic_tent":
			return HIT_SAND
		"car", "wreck", "tank_trap", "wire":
			return HIT_METAL
	return HIT_STONE


func _cam_d(p: Vector3) -> float:
	return world.cam.cam.global_position.distance_to(p) if world.cam else 0.0


## A round fired from `from` (the muzzle on this screen) to `to`, where it
## struck `impact` (HIT_*): its recoil on whoever fired it, the flash and
## smoke at the gun, the round in flight, and what it does when it gets there.
func _shot(from: Vector3, to: Vector3, impact: int, snd: String, src) -> void:
	_kick(src, snd)
	var cd_from := _cam_d(from)
	var cd_to := _cam_d(to)
	if cd_from > 230.0 and cd_to > 230.0:
		return
	Sfx.play(snd, from, -4.0 if snd != "mg" else -2.0)
	var span := to - from
	if span.length() < 0.05:
		return
	var dir := span.normalized()
	if cd_from <= 230.0:
		gunfx.muzzle(from, dir, snd, cd_from)
	var team: int = src.team if src is Entity else -1
	var t := gunfx.round_flight(from, to, snd, team, minf(cd_from, cd_to))
	if impact <= 0 or cd_to > 230.0:
		return
	if impact == HIT_DIRT and to.y < 0.3 and world.water and not world.water.is_empty() and world.water.wet_at(to):
		# into the water: a spout, not dust
		var at := Vector3(to.x, WaterMap.LEVEL, to.z)
		_puff("water_spurt", at)
		if randf() < 0.3 and vfx.water_view():
			vfx.water_view().foam(at, randf_range(0.6, 0.9), 2.0, WaterView.BOIL)
		return
	gunfx.impact(impact, to, -dir, float(CAL.get(snd, 1.0)), cd_to, t)
	# now and then a round skips off: off steel or stone, or off the ground
	# when it came in low
	var rk := 0.14 if impact == HIT_METAL or impact == HIT_STONE else (0.1 if impact == HIT_DIRT and dir.y > -0.3 else 0.0)
	if rk > 0.0 and randf() < rk:
		var n := Vector3.UP if impact == HIT_DIRT else Defs.flat(-dir).normalized()
		var r := (dir.bounce(n) + GunFx._jit(0.35) + Vector3(0, 0.25, 0)).normalized()
		gunfx.ricochet(to, r, gunfx.last_tracer, t)


## The weapon that fired kicks: the rifle back into his shoulder and its
## muzzle up, the mounted gun on its pintle, the turret on its ring.
func _kick(src, snd: String) -> void:
	if src is Soldier:
		var s: Soldier = src
		if s.model == null:
			return
		var m: Array = GunFx.MUZZLE.get(snd, GunFx.MUZZLE.rifle)
		var cm := s.crew_mount()
		if cm:
			cm.crew_kick(float(m[7]))
			s.model.fire_kick(0.3)
		else:
			s.model.fire_kick(float(m[7]))
	elif src is Vehicle and snd == "ac":
		(src as Vehicle).gun_kick(0.035)


## Other code's tracers and flashes (aircraft guns).
func _tracer(from: Vector3, to: Vector3, length: float, width: float) -> void:
	gunfx.tracer(from, to, GunFx.TRACER_HOT, length * 1.8, 0.035 * width, 700.0)


func _flash(p: Vector3, life: float, size: float) -> void:
	gunfx.flash(p, size * 0.45 * randf_range(0.8, 1.2), life, GunFx.HOT)


func _light(p: Vector3, energy: float, rng_m: float) -> void:
	if _lights.is_empty():
		return
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


## A tank or gun firing its main armament: the hull rocks back and the
## turret jolts, the muzzle blast, and the round's tracer.
func _cannon(from: Vector3, to: Vector3, src) -> void:
	var dir := (to - from).normalized()
	var v: Vehicle = src if src is Vehicle else null
	if v == null:
		for x in world.vehicles:
			if x.model and x.position.distance_to(from) < 7.0:
				v = x
				break
	if v and v.model:
		v.recoil(dir)
		v.gun_kick(0.26)
	Sfx.play("cannon", from, 3.0)
	var cd := _cam_d(from)
	if cd < 260.0:
		gunfx.cannon_blast(from, dir, cd)
	gunfx.tracer(from, to, Color(1.0, 0.5, 0.18, 7.0), 14.0, 0.12, 950.0)
	if world.cam and Settings.get_v("shake"):
		var d := world.cam.focus_pos.distance_to(from)
		if d < 40.0:
			world.cam.shake(0.3 * (1.0 - d / 40.0))


## A rocket or missile fired: its launcher's back-blast, and the man who
## fired it rocked by it.
func _launch(from: Vector3, dir: Vector3, src) -> void:
	if src is Soldier and (src as Soldier).model:
		(src as Soldier).model.fire_kick(1.6)
	var cd := _cam_d(from)
	if cd < 230.0:
		gunfx.launch_blast(from, dir, cd)


func _ricochet(p: Vector3, dir: Vector3) -> void:
	Sfx.play("ricochet", p, -6.0)
	if _cam_d(p) < 230.0:
		gunfx.ricochet(p, dir, false)


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
	l.font = UiKit.mono(500)  # a figure, so mono (docs/UI.md, Two voices)
	l.font_size = 20
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
