class_name Wildlife
extends Node3D
## (view) The life that carries on round a battle. Small birds feed in the
## fields and burst up and away from men, vehicles and gunfire; crows and
## buzzards turn in the sky, gulls along the coast; bats flit about at night.
## Rats run along the walls in town and hares sit out in the open. Fish swim in
## the rivers and ponds and now and then jump, ducks paddle on fresh water and
## dolphins roll through the swell out at sea.
##
## None of it is simulated on the server or sent to anyone: each player's game
## makes up its own, round its own camera, and it never touches the battle's
## random numbers. Only the camera's surroundings are alive; whatever falls
## behind is moved on ahead, out of sight, so it costs the same however big
## the map is. Every kind is one MultiMesh, written in one go each frame, and
## wings, tails and flukes are moved by the shaders. Animals take fright only
## at what the player can see, so a hidden enemy flushes no birds, on the
## host's screen or on a client's. They can be killed - a round through a
## flock, a shell among them - and fall and lie where they fell, but only
## for the eye: the round flies on as it would have. Settings > Graphics >
## Wildlife sets how much there is, or turns it off.

## The meshes, one MultiMesh each, and how many each can draw.
enum {SONG, BIG, DUCK, RAT, HARE, FISH, DOLPHIN}
const CAPS := [160, 16, 24, 32, 12, 64, 16]  # (the living and the dead)

## The bird shader's palette rows (and the small birds' kinds).
enum {SPARROW, STARLING, CROW, GULL, BUZZARD, BAT, DRAKE, HEN, PIGEON}
## The critter shader's palette rows.
enum {C_RAT, C_HARE, C_FISH, C_DOLPHIN, C_SEAFISH}
## Parts of a body (the palette's columns): a bird's back, belly, wing, wing
## tip and tail, head, bill and feet; a critter's back, belly, fins and tail,
## dark (eyes, ear tips), pink (nose, ears, a rat's tail), white.
enum {P_BACK, P_BELLY, P_WING, P_TIP, P_HEAD, P_BILL}

## How much life the camera's surroundings hold, at Some and at Plenty.
const FLOCKS := [3, 6]
const FLOCK_SIZE := [7, 11]
const SOARERS := [2, 5]
const BATS := [4, 9]
const RATS := [4, 9]
const HARES := [2, 4]
const SCHOOLS := [3, 6]
const PODS := [1, 2]
const DUCKS := [1, 2]

## How near (m) a man or a vehicle the player can see comes before each takes
## fright: small birds, ducks, rats, hares.
const SHY_BIRD := Vector2(13.0, 32.0)
const SHY_DUCK := Vector2(16.0, 34.0)
const SHY_RAT := Vector2(4.5, 12.0)
const SHY_HARE := Vector2(22.0, 45.0)

## How big each soaring bird (and bat) is against its mesh.
const SOAR_SIZE := [1.0, 1.0, 1.0, 1.15, 1.35, 1.25]

## How close a round has to pass to hit one (m, at its own size): a small
## bird, a crow, a duck, a rat, a hare, a fish, a dolphin - a mesh each.
const HIT_R := [0.1, 0.3, 0.22, 0.1, 0.18, 0.14, 0.4]
## How high above its origin each lies when it's down on its side (m, at its
## own size), and how it lies: on its side, or (fish, dolphins) belly up.
const REST_Y := [0.03, 0.07, 0.02, 0.05, 0.1, -0.02, -0.12]
const REST_ROLL := [PI * 0.5, PI * 0.5, PI * 0.5, PI * 0.5, PI * 0.5, PI, PI * 0.6]
## How many dead lie about at most (the oldest out of sight go first), and for how long.
const DEAD_MAX := 30
const DEAD_LIFE := 150.0
## Feathers knocked out of a bird hit, by its palette row.
const FEATHER := [Color(0.5, 0.38, 0.26), Color(0.12, 0.12, 0.12), Color(0.08, 0.08, 0.09), Color(0.92, 0.93, 0.94),
	Color(0.42, 0.3, 0.2), Color(0.0, 0.0, 0.0, 0.0), Color(0.55, 0.52, 0.46), Color(0.5, 0.4, 0.28), Color(0.6, 0.62, 0.66)]

## Beyond this far from the camera each is too small to make out, so isn't drawn.
const SEE_SMALL := 150.0  # small birds
const SEE_RAT := 90.0
const SEE_FISH := 110.0

var world: World
var level := -1
var rng := RandomNumberGenerator.new()
var t := 0.0
var _frame := 0
var focus := Vector3.ZERO  # what the camera looks at
var reach := 120.0  # how far round it there's life
var cam_pos := Vector3.ZERO
var _cam: Camera3D
var _planes: Array[Plane] = []  # the camera's view (this frame)
var _b: Array = []  # Batch per mesh
var _flocks: Array = []
var _ducks: Array = []
var _soarers: Array = []
var _bats: Array = []
var _runners: Array = []
var _schools: Array = []
var _pods: Array = []
var _threats := PackedVector3Array()  # men and vehicles round the camera the player can see (and fires)
var _big := PackedByteArray()  # 1: a vehicle or a fire (heard and seen from further off), 2: an aircraft
var _fires: Array = []  # [where, until]: grass fires burning
var _dead: Array = []  # Carcass
var _scan_t := 0.0
var _scanned := false  # (this frame)
var _plan_t := 0.0
var _spawns := 0  # this frame's: a few a frame, so a jump across the map doesn't hitch
var _first := true  # nothing placed yet: the first lot may appear in view
var _call_t := 2.0  # until the next call or song may be heard
var _dbg_us := 0
var _dbg_n := 0
var _dbg_t := 0.0
var _dbg_fright := {}  # (FL_DEBUG_WILDLIFE) what took fright at what, since the last report
var _dbg := OS.has_environment("FL_DEBUG_WILDLIFE")


func _ready() -> void:
	rng.seed = int(world.settings.get("seed", 1)) * 31 + 7
	var bird_mat := _material(BIRD_SHADER)
	var critter_mat := _material(CRITTER_SHADER)
	var meshes := [
		_bird_mesh(0.15, 0.03, 0.24, 0.06, 0.021, 0.014, Vector2(0.0, 0.012), 0.05, 0.0),
		_bird_mesh(0.46, 0.075, 1.0, 0.22, 0.055, 0.06, Vector2(0.0, 0.025), 0.13, 0.0),
		_bird_mesh(0.52, 0.1, 0.86, 0.16, 0.05, 0.055, Vector2(0.03, 0.12), 0.06, 0.085),
		_rat_mesh(), _hare_mesh(), _fish_mesh(), _dolphin_mesh()]
	for k in meshes.size():
		var b := Batch.new(meshes[k], bird_mat if k <= DUCK else critter_mat, CAPS[k])
		add_child(b.mi)
		_b.append(b)
	apply_settings()


func _material(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	m.shader = sh
	return m


func apply_settings() -> void:
	# soaring birds' shadows sweep over the ground (the rest are too small to bother)
	if not _b.is_empty():
		(_b[BIG] as Batch).mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(Settings.get_v("shadows")) > 0 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lv := clampi(int(Settings.get_v("wildlife")), 0, 2)
	if lv == level:
		return
	level = lv
	visible = level > 0
	_flocks.clear()
	_ducks.clear()
	_soarers.clear()
	_bats.clear()
	_runners.clear()
	_schools.clear()
	_pods.clear()
	_dead.clear()
	_fires.clear()
	for b in _b:
		(b as Batch).clear()
	_first = true
	if level == 0:
		return
	var li := level - 1
	for i in FLOCKS[li]:
		_flocks.append(Flock.new(false))
	for i in DUCKS[li]:
		_ducks.append(Flock.new(true))
	for i in SOARERS[li]:
		_soarers.append(Soarer.new())
	for i in BATS[li]:
		var s := Soarer.new()
		s.kind = BAT
		_bats.append(s)
	for i in int(RATS[li] * 1.5):  # (more come out at night)
		_runners.append(Runner.new(false))
	for i in HARES[li]:
		_runners.append(Runner.new(true))
	for i in SCHOOLS[li]:
		_schools.append(School.new())
	for i in PODS[li]:
		_pods.append(Pod.new())
	_plan_t = 0.0


func _process(dt: float) -> void:
	if level <= 0 or world.cam == null or world.building:
		return
	var t0 := Time.get_ticks_usec()
	_tick(dt)
	world.vp("wildlife", t0)
	if _dbg:
		_debug_report(t0, dt)
	# FL_WILDLIFE_FOLLOW=dolphins (birds, ducks, soarer, bat, rat, hare, fish, dead): the camera keeps on one (for a look at it)
	if OS.has_environment("FL_WILDLIFE_FOLLOW"):
		var q := _one_of(OS.get_environment("FL_WILDLIFE_FOLLOW"))
		if q.x != INF:
			world.cam.focus(world.cam.focus_pos.lerp(Vector3(q.x, 0.0, q.z), minf(1.0, dt * 3.0)))


## (FL_DEBUG_WILDLIFE) Every five seconds: what it costs, how many of each are
## drawn, what took fright at what, and where one of each is.
func _debug_report(t0: int, dt: float) -> void:
	_dbg_us += Time.get_ticks_usec() - t0
	_dbg_n += 1
	_dbg_t += dt
	if _dbg_t < 5.0:
		return
	var drawn: Array = []
	for b in _b:
		drawn.append((b as Batch).mm.visible_instance_count)
	print("WILDLIFE %.3f ms/frame  drawn %s (song big duck rat hare fish dolphin)  reach %d  fright %s" % [_dbg_us / 1000.0 / maxf(1.0, _dbg_n), str(drawn), int(reach), str(_dbg_fright)])
	_dbg_fright.clear()
	var at := ""
	for k in ["birds", "ducks", "soarer", "bat", "rat", "hare", "fish", "dolphins"]:
		var q := _one_of(k)
		if q.x != INF:
			at += "  %s %d,%d" % [k, int(q.x), int(q.z)]
	var down := 0
	var up := 0
	for f in _flocks:
		if f.on:
			if f.air:
				up += 1
			else:
				down += 1
	print("WILDLIFE at" + at + "  (flocks down %d, up %d)" % [down, up])
	if t < 6.0:  # (the first report: where the water is, to look at the fish and ducks)
		var wat := ""
		for r in world.water.rivers:
			var pts: PackedVector3Array = r.pts
			wat += "  river %d,%d" % [int(pts[pts.size() / 2].x), int(pts[pts.size() / 2].z)]
		for pd in world.water.ponds:
			wat += "  pond %d,%d" % [int(pd.c.x), int(pd.c.z)]
		print("WILDLIFE water" + wat)
	_dbg_us = 0
	_dbg_n = 0
	_dbg_t = 0.0


## (debugging) Where the first of a kind is (a flock down on the ground
## first); INF if there's none about.
func _one_of(kind: String) -> Vector3:
	if kind == "dead":
		return (_dead[0] as Carcass).p if not _dead.is_empty() else Vector3.INF
	var groups: Array = {"birds": _flocks, "ducks": _ducks, "soarer": _soarers, "bat": _bats, "rat": _runners, "hare": _runners,
		"fish": _schools, "dolphins": _pods}.get(kind, [])
	var flying := Vector3.INF
	for e in groups:
		if not e.on or (e is Runner and e.hare != (kind == "hare")):
			continue
		if e is Runner or e is Soarer:
			return e.p
		if e is Flock and e.air:
			if flying.x == INF:
				flying = e.c
			continue
		return e.c
	return flying


func _tick(dt: float) -> void:
	t += dt
	_frame += 1
	_cam = world.cam.cam
	cam_pos = _cam.global_position
	_planes = _cam.get_frustum()
	focus = world.cam.focus_pos
	reach = clampf(50.0 + world.cam.dist * 1.2, 80.0, 240.0)
	_spawns = 0
	_call_t -= dt
	_plan_t -= dt
	if _plan_t <= 0.0:
		_plan_t = 2.0
		_plan()
	_scan_t -= dt
	_scanned = _scan_t <= 0.0
	if _scanned:
		_scan_t = 0.3
		_scan()
	for f in _flocks:
		_flock(f, dt)
	for f in _ducks:
		_flock(f, dt)
	for s in _soarers:
		_soar(s, dt)
	for s in _bats:
		_soar(s, dt)
	for r in _runners:
		_run(r, dt)
	for s in _schools:
		_swim(s, dt)
	for p in _pods:
		_pod(p, dt)
	_carcasses(dt)
	if _first:
		# every kind drawn once, out of sight under the ground, so its shaders compile
		# while the battle is still being revealed: a browser compiles a shader the
		# first time it's drawn, which would otherwise be a hitch at the first rat
		for b in _b:
			(b as Batch).put(focus + Vector3(0.0, -30.0, 0.0), Basis(), 1.0, Color(0.5, 0.0, 0.0, 0.0))
	for b in _b:
		(b as Batch).flush()
	_first = false


## What's about at this time of day and in this weather: no small birds or
## soaring ones at night (bats instead, and more rats), fewer in the rain.
func _plan() -> void:
	var mood: String = world.atmo.mood if world.atmo else "day"
	var night := mood == "night"
	var rain := mood == "rain"
	var li := level - 1
	var all: int = FLOCKS[li]
	var nf: int = 0 if night else (ceili(all * 0.5) if rain else all)
	for i in _flocks.size():
		_flocks[i].want = i < nf
	for i in _ducks.size():
		_ducks[i].want = not night or i == 0
	for i in _soarers.size():
		_soarers[i].want = not night and not (rain and i > 0)
	for i in _bats.size():
		_bats[i].want = night
	var rats := 0
	for r in _runners:
		if r.hare:
			r.want = not rain
		else:
			r.want = rats < int(RATS[li] * (1.5 if night else 1.0))
			rats += 1
	for s in _schools:
		s.want = true
	for p in _pods:
		p.want = true


## The men and vehicles round the camera that the player can see.
func _scan() -> void:
	_threats.clear()
	_big.clear()
	var r := reach + 60.0
	var r2 := r * r
	for s in world.soldiers:
		if s.gone or s.life == Soldier.Life.DEAD or s.life == Soldier.Life.HIDDEN:
			continue
		if _d2(s.position, focus) < r2 and s.seen_by_local():
			_threats.append(s.position)
			_big.append(0)
	for v in world.vehicles:
		if v.gone:
			continue
		if _d2(v.position, focus) < r2 and v.seen_by_local():
			_threats.append(v.position)
			_big.append(2 if v.is_air() else 1)
	# a grass fire keeps everything off like a vehicle would
	for i in range(_fires.size() - 1, -1, -1):
		if t > float(_fires[i][1]):
			_fires.remove_at(i)
		elif _d2(_fires[i][0], focus) < r2:
			_threats.append(_fires[i][0])
			_big.append(1)


## The nearest man within `man` metres of p, or vehicle within `veh`; -1 if none.
func _threat(p: Vector3, man: float, veh: float) -> int:
	var best := -1
	var bd := INF
	for i in _threats.size():
		var r := veh if _big[i] >= 1 else man
		var d := _d2(p, _threats[i])
		if d < r * r and d < bd:
			bd = d
			best = i
	return best


## Gunfire, a shell, a rocket at p (Fx calls this): what's within r of it takes fright.
func startle(p: Vector3, r: float) -> void:
	if level <= 0 or _d2(p, focus) > (reach + r) * (reach + r):
		return
	var r2 := r * r
	for f in _flocks:
		if f.on and not f.air and _d2(f.c, p) < r2:
			_fright("birds", "fire")
			_take_off(f, p)
	for f in _ducks:
		if f.on and not f.air and _d2(f.c, p) < r2:
			_fright("ducks", "fire")
			_take_off(f, p)
	for s in _soarers:
		if s.on and s.scared <= 0.0 and _d2(s.p, p) < r2 * 0.6:
			_fright("soarer", "fire")
			_scare(s, p)
	for s in _bats:
		if s.on and s.scared <= 0.0 and _d2(s.p, p) < r2 * 0.6:
			_scare(s, p)
	for ru in _runners:
		if ru.on and ru.state != Runner.FLEE and _d2(ru.p, p) < r2 * (0.5 if ru.hare else 0.3):
			_fright("hare" if ru.hare else "rat", "fire")
			_flee(ru, p)
	for sc in _schools:
		if sc.on and _d2(sc.c, p) < r2 * 0.2:
			_dart(sc, p)
	for pd in _pods:
		if pd.on and _d2(pd.c, p) < r2 * 0.5:
			pd.aim = _yaw_away(pd.c, p)  # (turning away, not snapping round)
			pd.hurry = 8.0


# --- small birds and ducks ---------------------------------------------------------------------

## A flock of small birds (or a few ducks): down feeding (afloat), or in the
## air on the way somewhere. Each bird has its own place in the flock; taking
## off and coming down, each goes from where it was to where it's going, a
## moment apart from the next.
class Flock:
	var duck := false
	var kind := SPARROW  # SPARROW, STARLING, PIGEON (ducks: DRAKE)
	var on := false
	var want := false
	var wait := 0.0  # until it next looks for somewhere to appear
	var air := false
	var leaving := false  # flying off for good: gone once out of the camera's surroundings
	var n := 0
	var sz := 1.0
	var c := Vector3.ZERO  # where it feeds, or where it is in the air
	var gy := 0.0  # the ground (the water) where it feeds
	var hd := 0.0  # heading in the air
	var vy := 0.0
	var turn := 0.0  # how hard it's turning (banks the birds)
	var goal := Vector3.ZERO  # where it means to come down
	var cruise := 8.0
	var speed := 10.0
	var stay := 0.0  # on the ground: until it moves on of its own accord
	var alarm := 0.0  # another flock went up near it: going up too in this long
	var alarm_from := Vector3.ZERO
	var mix := 1.0  # 0 -> 1: from where each was to where it's going
	var song := 3.0
	var p := PackedVector3Array()  # each bird (on the ground: its spot; in the air: where it's drawn)
	var was := PackedVector3Array()  # where each was as the flock took off, or began to come down
	var slot := PackedVector3Array()  # each one's place in the flock in the air
	var yaw := PackedFloat32Array()  # each one's heading on the ground
	var act := PackedFloat32Array()  # until each next hops or pecks (dabbles)
	var hop := PackedFloat32Array()  # how far through its hop or peck, 1: done
	var peck := PackedByteArray()  # 1: the hop is a peck
	var ph := PackedFloat32Array()  # wing beat
	var lag := PackedFloat32Array()  # each one's moment's delay
	var sp := PackedFloat32Array()  # palette row (as the shader takes it)

	func _init(is_duck: bool) -> void:
		duck = is_duck

	## One of them gone (killed).
	func remove(i: int) -> void:
		p.remove_at(i)
		was.remove_at(i)
		slot.remove_at(i)
		yaw.remove_at(i)
		act.remove_at(i)
		hop.remove_at(i)
		ph.remove_at(i)
		lag.remove_at(i)
		peck.remove_at(i)
		sp.remove_at(i)
		n -= 1
		if n <= 0:
			on = false

	func resize(k: int) -> void:
		n = k
		p.resize(k)
		was.resize(k)
		slot.resize(k)
		yaw.resize(k)
		act.resize(k)
		hop.resize(k)
		ph.resize(k)
		lag.resize(k)
		peck.resize(k)
		sp.resize(k)


func _flock(f: Flock, dt: float) -> void:
	if not f.on:
		_appear(f, _spawn_flock, dt)
		return
	var far := _d2(f.c, focus) > reach * reach * 1.7
	if f.air:
		_fly(f, dt)
		if (f.leaving or not f.want) and far:
			f.on = false
		return
	if far and _unseen(f.c, SEE_SMALL):
		f.on = false  # out of the camera's surroundings: off somewhere else (unseen, it just goes)
		return
	if not f.want or far:
		f.leaving = not f.want
		_take_off(f, f.c + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), false)
		return
	_feed(f, dt)


## On the ground (or the water): hopping about and pecking (paddling, dabbling).
func _feed(f: Flock, dt: float) -> void:
	f.stay -= dt
	if f.mix >= 1.0 and f.stay <= 0.0:
		# moving on to another patch
		_take_off(f, f.c + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), false)
		return
	if f.alarm > 0.0:
		# the flock next to it went up: so does this one, a moment after
		f.alarm -= dt
		if f.alarm <= 0.0:
			_fright("ducks" if f.duck else "birds", "others")
			_take_off(f, f.alarm_from)
			return
	if _scanned:
		var shy: Vector2 = SHY_DUCK if f.duck else SHY_BIRD
		var ti := _threat(f.c, shy.x + 3.0, shy.y)
		if ti >= 0:
			_fright("ducks" if f.duck else "birds", "near")
			_take_off(f, _threats[ti])
			return
	var landed := f.mix >= 1.0
	f.mix = minf(1.0, f.mix + dt / 0.9)
	if f.duck:
		f.gy = _surf(f.c)
	var vis := _seen(f.c, 6.0, SEE_SMALL)
	var b: Batch = _b[DUCK if f.duck else SONG]
	for i in f.n:
		if not vis:
			continue  # (off the screen they keep still: nobody sees where each one is)
		if landed:
			if f.duck:
				_paddle(f, i, dt)
			else:
				_hop(f, i, dt)
		var q := f.p[i]
		q.y = f.gy if f.duck else _gy(q)
		var pitch := 0.0
		var h := f.hop[i]
		if h < 1.0:
			if f.peck[i] == 1:
				pitch = -sin(PI * h) * (1.4 if f.duck else 0.7)
			else:
				q.y += sin(PI * h) * 0.05
		if f.duck:
			q.y += 0.012 * sin(t * 2.1 + i)
		if landed:
			b.put(q, Basis.from_euler(Vector3(pitch, f.yaw[i], 0.0)), f.sz, Color(0.5, f.sp[i], 1.0, 0.0))
		else:
			# coming down: from where it was in the air to its spot, wings beating, then folded
			var k := smoothstep(0.0, 1.0, clampf((f.mix - f.lag[i]) / (1.0 - f.lag[i]), 0.0, 1.0))
			f.ph[i] += dt * TAU * 9.0
			b.put(f.was[i].lerp(q, k), Basis.from_euler(Vector3((1.0 - k) * 0.5, f.yaw[i], 0.0)), f.sz,
				Color(0.5 + 0.5 * sin(f.ph[i]) * (1.0 - k), f.sp[i], k, 0.0))
	# a song now and then, from a flock feeding near the camera
	f.song -= dt
	if f.song <= 0.0:
		f.song = rng.randf_range(4.0, 11.0)
		if not f.duck and landed and cam_pos.distance_to(f.c) < 75.0:
			var song := "coo" if f.kind == PIGEON else ("birdsong" if rng.randf() < 0.5 else "birdsong2")
			_call(song, f.p[rng.randi() % f.n], -9.0, rng.randf_range(0.92, 1.12))


## A small bird on the ground: now and then a hop (back towards the others if
## it's strayed) or a peck at something.
func _hop(f: Flock, i: int, dt: float) -> void:
	if f.hop[i] < 1.0:
		f.hop[i] = minf(1.0, f.hop[i] + dt / (0.18 if f.peck[i] == 0 else 0.35))
		if f.peck[i] == 0:
			var y := f.yaw[i]
			f.p[i] += Vector3(-sin(y), 0.0, -cos(y)) * (0.8 if f.kind == PIGEON else 1.1) * dt
		return
	f.act[i] -= dt
	if f.act[i] > 0.0:
		return
	f.act[i] = rng.randf_range(0.3, 1.8)
	f.hop[i] = 0.0
	if rng.randf() < 0.55:
		f.peck[i] = 0
		var to := f.c - f.p[i]
		if Vector2(to.x, to.z).length() > 2.8:
			f.yaw[i] = atan2(-to.x, -to.z) + rng.randf_range(-0.5, 0.5)
		else:
			f.yaw[i] += rng.randf_range(-1.3, 1.3)
	else:
		f.peck[i] = 1


## A duck afloat: paddling slowly about, keeping near the others and off the
## bank, and now and then upending to feed.
func _paddle(f: Flock, i: int, dt: float) -> void:
	var y := f.yaw[i]
	var fw := Vector3(-sin(y), 0.0, -cos(y))
	if f.hop[i] < 1.0:
		f.hop[i] = minf(1.0, f.hop[i] + dt / 2.6)  # (upended)
	else:
		f.p[i] += fw * 0.16 * dt
		f.yaw[i] += sin(t * 0.37 + i * 1.9) * 0.25 * dt
	f.act[i] -= dt
	if f.act[i] <= 0.0:
		f.act[i] = rng.randf_range(1.5, 5.0)
		var to := f.c - f.p[i]
		if not _fresh(f.p[i] + fw * 1.2) or Vector2(to.x, to.z).length() > 4.5:
			f.yaw[i] = atan2(-to.x, -to.z) + rng.randf_range(-0.4, 0.4)
		elif rng.randf() < 0.3:
			f.peck[i] = 1
			f.hop[i] = 0.0


func _fly(f: Flock, dt: float) -> void:
	var to := f.goal - f.c
	to.y = 0.0
	var dist := to.length()
	if not f.leaving and dist > reach * 1.6:
		f.leaving = true  # (the camera has gone elsewhere)
	if not f.leaving:
		var dh := wrapf(atan2(-to.x, -to.z) - f.hd, -PI, PI)
		f.turn = clampf(dh * 1.6, -1.8, 1.8)
	else:
		f.turn = lerpf(f.turn, 0.0, dt)
	f.hd += f.turn * dt
	var alt := f.cruise if f.leaving or dist > 40.0 else lerpf(0.0, f.cruise, dist / 40.0)
	f.vy = clampf((f.gy + alt - f.c.y) * 1.3, -3.0, 4.0)
	var fs := f.speed if f.leaving or dist > 14.0 else lerpf(2.2, f.speed, dist / 14.0)
	f.c += Vector3(-sin(f.hd) * fs, f.vy, -cos(f.hd) * fs) * dt
	f.c.y = maxf(f.c.y, _gy(f.c) + 0.5)
	var k0 := f.mix
	f.mix = minf(1.0, f.mix + dt / 1.1)
	if not f.leaving and dist < 1.2 and f.c.y - f.gy < 0.7:
		_land(f)
		return
	# wing beats: sparrows bound (a burst of beats, then wings shut), starlings
	# and pigeons beat and glide, ducks beat steadily
	var rate := 13.0
	match f.kind:
		STARLING:
			rate = 11.0
		PIGEON:
			rate = 7.5
		DRAKE:
			rate = 6.5
	rate *= TAU * dt * (1.25 if k0 < 1.0 else 1.0)
	var vis := _seen(f.c, 12.0, SEE_SMALL * 1.2)
	var hb := Basis(Vector3.UP, f.hd)
	var b: Batch = _b[DUCK if f.duck else SONG]
	var pitch := atan2(f.vy, fs) * 0.6
	var roll := f.turn * 0.35
	for i in f.n:
		if not vis:
			f.p[i] = f.c + hb * f.slot[i]  # (out of sight: just where it is)
			continue
		f.ph[i] += rate
		var k := 1.0
		if k0 < 1.0:
			k = smoothstep(0.0, 1.0, clampf((k0 - f.lag[i]) / (1.0 - f.lag[i]), 0.0, 1.0))
		var q := f.c + hb * (f.slot[i] + Vector3(sin(t * 1.3 + i * 1.7), sin(t * 1.9 + i * 2.3) * 0.5, cos(t * 1.1 + i * 0.9)) * 0.45)
		if k < 1.0:
			q = f.was[i].lerp(q, k) + Vector3(0.0, sin(PI * k) * 0.6, 0.0)
		f.p[i] = q
		var flap := sin(f.ph[i])
		var fold := 0.0
		if k >= 1.0 and not f.duck:
			var cyc := fmod(f.ph[i] / TAU + f.lag[i] * 7.0, 6.0)
			if f.kind == SPARROW and fmod(cyc, 4.0) > 3.0:
				flap = 0.2
				fold = 0.85
			elif f.kind != SPARROW and cyc > 4.5:
				flap = 0.1  # gliding
		b.put(q, Basis.from_euler(Vector3(pitch + (1.0 - k) * 0.7, f.hd + sin(t * 2.0 + i) * 0.08, roll)), f.sz,
			Color(0.5 + 0.5 * flap * (0.85 if f.duck else 1.0), f.sp[i], fold, 0.0))


## Up and away from what frightened them (from_p), towards somewhere quieter
## to come down; out of the camera's surroundings altogether if there isn't
## one. A fright spreads: the flocks feeding nearby go up after it.
func _take_off(f: Flock, from_p: Vector3, fright := true) -> void:
	if f.air:
		return
	f.air = true
	f.mix = 0.0
	f.alarm = 0.0
	for i in f.n:
		var q := f.p[i]
		q.y = f.gy if f.duck else _gy(q)
		f.was[i] = q
		f.lag[i] = rng.randf_range(0.0, 0.35)
	var away := f.c - from_p
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	f.hd = atan2(-away.x, -away.z) + rng.randf_range(-0.5, 0.5)
	f.turn = 0.0
	f.c.y = f.gy
	if not f.leaving:
		var fw := Vector3(-sin(f.hd), 0.0, -cos(f.hd))
		var to := _landing(f, f.c + fw * (rng.randf_range(45.0, 100.0) if fright else rng.randf_range(25.0, 70.0)))
		if to.x == INF:
			f.leaving = true
		else:
			f.goal = to
	if cam_pos.distance_to(f.c) < 90.0 and not f.duck:
		var pitch := rng.randf_range(0.75, 0.9) if f.kind == PIGEON else rng.randf_range(0.95, 1.1)
		_call("flutter", f.c, -4.0 + minf(4.0, f.n * 0.3), pitch, true)
	if fright:
		for g in _flocks:
			_alarm(g, f, from_p)
		for g in _ducks:
			_alarm(g, f, from_p)


func _alarm(g: Flock, f: Flock, from_p: Vector3) -> void:
	if g != f and g.on and not g.air and g.alarm <= 0.0 and _d2(g.c, f.c) < 35.0 * 35.0:
		g.alarm = rng.randf_range(0.25, 0.9)
		g.alarm_from = from_p


## Somewhere to come down near `near`: bare ground (fresh water for ducks)
## inside the camera's surroundings, with nobody about. INF if there's none.
func _landing(f: Flock, near: Vector3) -> Vector3:
	for k in 12:
		var q := near + Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-24, 24))
		if _d2(q, focus) > pow(reach * 0.95, 2.0):
			continue
		if (_fresh(q) if f.duck else _feeding(q)) and _threat(q, 30.0, 60.0) < 0:
			return q
	return Vector3.INF


func _land(f: Flock) -> void:
	f.air = false
	f.mix = 0.0
	f.stay = rng.randf_range(20.0, 60.0)
	f.gy = _surf(f.goal) if f.duck else _gy(f.goal)
	var spread := 3.5 if f.duck else 2.4
	for i in f.n:
		f.was[i] = f.p[i]
		var q := f.goal + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		if f.duck and not _fresh(q):
			q = f.goal
		f.p[i] = q
		f.yaw[i] = f.hd + rng.randf_range(-1.2, 1.2)
		f.act[i] = rng.randf_range(0.5, 2.0)
		f.hop[i] = 1.0
		f.peck[i] = 0
		if f.duck and cam_pos.distance_to(q) < 80.0 and _wv() != null:
			_wv().foam(q, 0.7, 1.4, WaterView.RING)
	f.c = f.goal


func _spawn_flock(f: Flock) -> void:
	var spot := Vector3.INF
	for k in 12:
		var q := _around(0.1, 0.9)
		if (_fresh(q) if f.duck else _feeding(q)) and _threat(q, 30.0, 60.0) < 0:
			spot = q
			break
	if spot.x == INF:
		return
	var li := level - 1
	var fs: int = FLOCK_SIZE[li]
	if f.duck:
		f.kind = DRAKE
		f.resize(rng.randi_range(3, 6))
	else:
		# pigeons about the town, sparrows anywhere, starlings out on the fields
		var town := world.town_rect.size.x > 0.0 and world.town_rect.grow(15.0).has_point(Vector2(spot.x, spot.z))
		var r := rng.randf()
		f.kind = (PIGEON if r < 0.55 else SPARROW) if town else (STARLING if r < 0.45 else SPARROW)
		f.resize(fs + rng.randi_range(-2, 3) - (3 if f.kind == PIGEON else 0))
	f.sz = 1.9 if f.kind == PIGEON else (1.25 if f.kind == STARLING else 1.0)
	f.cruise = rng.randf_range(5.0, 8.0) if f.duck else rng.randf_range(5.0, 12.0)
	f.speed = rng.randf_range(13.0, 16.0) if f.duck else rng.randf_range(9.0, 12.0)
	var spread := Vector3(2.4, 0.9, 2.4) if f.duck else Vector3(2.8, 1.2, 2.8) * sqrt(f.sz)
	for i in f.n:
		f.sp[i] = ((DRAKE if rng.randf() < 0.5 else HEN) if f.duck else f.kind) / 8.0
		f.slot[i] = Vector3(rng.randf_range(-1, 1) * spread.x, rng.randf_range(-1, 1) * spread.y, rng.randf_range(-1, 1) * spread.z)
		f.ph[i] = rng.randf() * TAU
		f.lag[i] = rng.randf_range(0.0, 0.35)
	f.on = true
	f.leaving = false
	f.goal = spot
	f.gy = _surf(spot) if f.duck else _gy(spot)
	if _first:
		# the battle opens with them already down
		f.c = spot
		f.p.fill(spot)
		f.hd = rng.randf() * TAU
		_land(f)
		f.mix = 1.0
		f.stay = rng.randf_range(5.0, 60.0)
		return
	# otherwise they fly in from beyond the camera's surroundings
	var a := rng.randf() * TAU
	for k in 6:
		if _unseen(focus + Vector3(cos(a), 0.0, sin(a)) * reach * 1.15 + Vector3(0, 10, 0), SEE_SMALL):
			break
		a += TAU / 6.0
	f.c = focus + Vector3(cos(a), 0.0, sin(a)) * reach * 1.15
	f.c.y = f.cruise
	f.air = true
	f.mix = 1.0
	var to := spot - f.c
	f.hd = atan2(-to.x, -to.z)
	f.turn = 0.0


# --- soaring birds and bats ----------------------------------------------------------------------

## A crow, gull or buzzard turning circles on the air, or a bat flitting
## about low down: a point going round a circle whose middle drifts, the
## bird pointed and banked along its own path.
class Soarer:
	var kind := CROW
	var on := false
	var want := false
	var wait := 0.0  # until it next looks for somewhere to appear
	var c := Vector3.ZERO  # the middle of its circle
	var r := 20.0
	var a := 0.0
	var w := 0.3  # how fast it goes round (rad/s; the sign is which way)
	var alt := 25.0
	var drift := Vector3.ZERO
	var p := Vector3.ZERO
	var hd := 0.0
	var ph := 0.0
	var flap := 0.0  # flapping for this much longer
	var rest := 2.0  # gliding for this much longer
	var climb := 0.0  # frightened: climbing away
	var scared := 0.0  # frightened: making off for this much longer
	var cry := 6.0
	var k := 0.0  # its own offset in time
	var shown := true  # drawn last frame (off the screen it's moved every other frame)
	var owed := 0.0  # time it hasn't been moved for


func _soar(s: Soarer, dt: float) -> void:
	if not s.on:
		_appear(s, _spawn_soarer, dt)
		return
	if not s.shown and not _scanned and (_frame + int(s.k)) % 2 == 0:
		s.owed += dt
		return
	dt += s.owed
	s.owed = 0.0
	var bat := s.kind == BAT
	if not s.want:
		s.drift = (s.c - focus).normalized() * 8.0  # off elsewhere
	if _d2(s.c, focus) > pow(reach * 1.3, 2.0) and (not s.want or _unseen(s.p, 400.0)):
		s.on = false
		return
	if s.scared > 0.0:
		s.scared -= dt
		if s.scared <= 0.0:
			s.drift = s.drift.normalized() * 1.2
	elif _scanned:
		# a helicopter coming close
		for i in _threats.size():
			if _big[i] == 2 and _threats[i].distance_squared_to(s.p) < 45.0 * 45.0:
				_fright("soarer", "aircraft")
				_scare(s, _threats[i])
				break
	s.c += s.drift * dt
	var spin := 1.0 + (0.7 * sin(t * 2.7 + s.k) if bat else 0.0)
	s.a += s.w * spin * dt
	var rr := s.r * ((0.55 + 0.45 * sin(t * 1.3 + s.k * 3.0)) if bat else 1.0)
	s.climb = maxf(0.0, s.climb - dt * 0.08)
	var h := s.alt + (1.6 * sin(t * 2.1 + s.k) if bat else 2.5 * sin(t * 0.13 + s.k)) + s.climb * 22.0
	var np := s.c + Vector3(cos(s.a) * rr, h, sin(s.a) * rr)
	var v := (np - s.p) / maxf(dt, 0.001)
	s.p = np
	var flat := Vector2(v.x, v.z).length()
	var hd := atan2(-v.x, -v.z) if flat > 0.1 else s.hd
	var turn := wrapf(hd - s.hd, -PI, PI) / maxf(dt, 0.001)
	s.hd = hd
	# flapping: crows mostly beat, gulls and buzzards mostly glide, bats never stop
	var flap := 0.0
	var rate := 4.5
	match s.kind:
		BAT:
			rate = 11.0
			s.flap = 1.0
		GULL:
			rate = 3.2
		BUZZARD:
			rate = 3.0
	if s.flap > 0.0:
		s.flap -= dt
		s.ph += dt * TAU * rate
		flap = sin(s.ph)
		if s.flap <= 0.0:
			s.rest = rng.randf_range(1.0, 2.5) if s.kind == CROW else rng.randf_range(5.0, 14.0)
	else:
		s.rest -= dt
		flap = 0.15 if s.kind == BUZZARD else 0.05  # (a buzzard holds its wings up in a shallow V)
		if s.rest <= 0.0 or s.climb > 0.3:
			s.flap = rng.randf_range(2.0, 4.0) if s.kind == CROW else rng.randf_range(0.8, 2.0)
	# a cry now and then
	s.cry -= dt
	if s.cry <= 0.0:
		s.cry = rng.randf_range(7.0, 18.0)
		if not bat and cam_pos.distance_to(s.p) < 110.0:
			match s.kind:
				CROW:
					_call("caw", s.p, -6.0, rng.randf_range(0.9, 1.1))
				GULL:
					_call("gull", s.p, -6.0, rng.randf_range(0.92, 1.1))
				BUZZARD:
					_call("gull", s.p, -9.0, rng.randf_range(0.66, 0.72))
	# (a big bird's shadow can fall in view from well outside it)
	s.shown = _seen(s.p, 2.0, SEE_SMALL) if bat else _seen(s.p, 45.0, 400.0)
	if bat and not s.shown:
		return
	var bas := Basis.from_euler(Vector3(clampf(atan2(v.y, maxf(flat, 0.1)), -0.6, 0.6), hd, clampf(turn * flat / 9.8, -0.8, 0.8)))
	var b: Batch = _b[SONG if bat else BIG]
	b.put(s.p, bas, SOAR_SIZE[s.kind], Color(0.5 + 0.5 * flap, s.kind / 8.0, 0.0, 0.0))


## Off and away from what frightened it (from_p), climbing and beating hard.
func _scare(s: Soarer, from_p: Vector3) -> void:
	var away := s.p - from_p
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	s.drift = away.normalized() * (5.0 if s.kind == BAT else 8.0)
	s.scared = rng.randf_range(5.0, 9.0)
	s.climb = 0.6 if s.kind == BAT else 1.0
	s.flap = rng.randf_range(1.5, 3.0)


func _spawn_soarer(s: Soarer) -> void:
	var bat := s.kind == BAT
	var sea := not world.water.coast.is_empty() and absf(world.water.coast_x(focus.z) - focus.x) < reach
	if not bat:
		s.kind = GULL if sea and rng.randf() < 0.75 else (BUZZARD if rng.randf() < 0.35 else CROW)
	match s.kind:
		BAT:
			s.r = rng.randf_range(4.0, 9.0)
			s.alt = rng.randf_range(3.0, 7.0)
		CROW:
			s.r = rng.randf_range(12.0, 30.0)
			s.alt = rng.randf_range(14.0, 30.0)
		GULL:
			s.r = rng.randf_range(15.0, 40.0)
			s.alt = rng.randf_range(12.0, 35.0)
		BUZZARD:
			s.r = rng.randf_range(25.0, 45.0)
			s.alt = rng.randf_range(35.0, 60.0)
	var speed := 6.0 if bat else (7.0 if s.kind == BUZZARD else 9.0)
	s.w = speed / s.r * (1.0 if rng.randf() < 0.5 else -1.0)
	s.k = rng.randf() * 100.0
	s.drift = Vector3.ZERO if bat else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 1.2
	s.climb = 0.0
	s.scared = 0.0
	s.flap = 0.0
	s.rest = rng.randf_range(0.5, 4.0)
	# somewhere it isn't seen arriving (a bat over open ground or the trees)
	for k in 8:
		var c := _around(0.0, 0.85)
		if s.kind == GULL:
			c.z = clampf(focus.z + rng.randf_range(-0.7, 0.7) * reach, -MapDims.HALF, MapDims.HALF)
			c.x = world.water.coast_x(c.z) + rng.randf_range(-25.0, 50.0)
		s.c = c
		s.a = rng.randf() * TAU
		s.p = s.c + Vector3(cos(s.a) * s.r, s.alt, sin(s.a) * s.r)
		if _unseen(s.p, 400.0) and (not bat or _field(c)):
			break
	s.hd = s.a
	s.on = true


# --- rats and hares -------------------------------------------------------------------------------

## A rat in town, scurrying along the walls from one bit of cover to the next,
## or a hare out in the fields; either bolts from anyone who comes near, a rat
## for the nearest hole in a wall.
class Runner:
	enum {SIT, GO, FLEE}
	var hare := false
	var on := false
	var want := false
	var wait := 0.0  # until it next looks for somewhere to appear
	var p := Vector3.ZERO
	var yaw := 0.0
	var state := SIT
	var timer := 0.0
	var speed := 0.0
	var ph := 0.0  # gait
	var tail := 0.0
	var away := Vector3.ZERO  # running from here
	var home := Vector3.ZERO  # a rat's own bit of wall it keeps to
	var hole := Vector3.INF  # a rat's way in
	var up := 0.0  # sitting up (a hare on the alert): 0..1
	var zig := 0.0
	var shown := true  # drawn last frame (off the screen, sitting, it's looked at every fourth)
	var owed := 0.0

	func _init(is_hare: bool) -> void:
		hare = is_hare


func _run(r: Runner, dt: float) -> void:
	if not r.on:
		_appear(r, _spawn_runner, dt)
		return
	if not r.shown and r.state == Runner.SIT and not _scanned and (_frame + int(r.zig * 10.0)) % 4 != 0:
		r.owed += dt
		return
	dt += r.owed
	r.owed = 0.0
	if (_d2(r.p, focus) > pow(reach * 1.15, 2.0) or not r.want) and _unseen(r.p, SEE_RAT):
		r.on = false
		return
	if _scanned and r.state != Runner.FLEE:
		var shy: Vector2 = SHY_HARE if r.hare else SHY_RAT
		var ti := _threat(r.p, shy.x, shy.y)
		if ti >= 0:
			_fright("hare" if r.hare else "rat", "near")
			_flee(r, _threats[ti])
	r.timer -= dt
	var bob := 0.0
	var pitch := 0.0
	match r.state:
		Runner.SIT:
			r.up = move_toward(r.up, 1.0 if fmod(t + r.zig, 7.0) < 2.5 else 0.0, dt * 2.0)
			r.tail += dt * 2.0
			if r.timer <= 0.0:
				r.state = Runner.GO
				r.speed = rng.randf_range(0.9, 1.6) if r.hare else rng.randf_range(2.2, 3.8)
				r.timer = rng.randf_range(1.0, 3.0) if r.hare else rng.randf_range(0.4, 1.4)
				r.yaw = _wall_yaw(r) if not r.hare else r.yaw + rng.randf_range(-1.2, 1.2)
				if not r.hare and _d2(r.p, r.home) > 36.0:
					var back := r.home - r.p
					r.yaw = atan2(-back.x, -back.z) + rng.randf_range(-0.5, 0.5)
		Runner.GO, Runner.FLEE:
			r.up = move_toward(r.up, 0.0, dt * 6.0)
			var fleeing := r.state == Runner.FLEE
			if fleeing:
				if r.hare:
					r.zig -= dt
					if r.zig <= 0.0:
						r.zig = rng.randf_range(0.4, 0.9)
						r.yaw = _yaw_away(r.p, r.away) + rng.randf_range(-0.7, 0.7)
				elif r.hole.x != INF:
					var to := r.hole - r.p
					r.yaw = atan2(-to.x, -to.z)
			var fw := Vector3(-sin(r.yaw), 0.0, -cos(r.yaw))
			var nx := r.p + fw * r.speed * dt
			if not r.hare and fleeing and _solid(nx):
				r.on = false  # in through the hole and gone
				return
			if not _passable(nx, r.hare):
				r.yaw += (PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5) + rng.randf_range(-0.4, 0.4)
				if not fleeing:
					r.state = Runner.SIT
					r.timer = rng.randf_range(0.2, 0.8)
			else:
				r.p = nx
			r.ph += dt * TAU * (r.speed * 0.45 + 1.6 if r.hare else 9.0)
			r.tail += dt * 12.0
			if r.hare:
				bob = absf(sin(r.ph * 0.5)) * (0.24 if fleeing else 0.1)
				pitch = cos(r.ph * 0.5) * 0.22
			else:
				bob = absf(sin(r.ph)) * 0.012
			if r.timer <= 0.0:
				r.state = Runner.SIT
				r.timer = rng.randf_range(2.0, 8.0) if r.hare else rng.randf_range(0.5, 3.0)
				r.zig = rng.randf() * 7.0
	r.shown = _seen(r.p, 1.0, SEE_RAT * (1.4 if r.hare else 1.0))
	if not r.shown:
		return
	var q := r.p
	q.y = _gy(q) + bob
	# sitting up: a rat sniffing the air, a hare up on its haunches; grazing, a hare's head goes down
	pitch += r.up * (0.5 if not r.hare else 0.35)
	if r.hare and r.state == Runner.SIT and r.up < 0.5:
		pitch -= 0.12
	var bas := Basis.from_euler(Vector3(pitch, r.yaw, 0.0))
	if r.hare:
		_b[HARE].put(q, bas, 1.0, Color(fmod(r.tail / TAU, 1.0), C_HARE / 8.0, 0.0, 0.0))
	else:
		_b[RAT].put(q, bas, 1.0, Color(fmod(r.tail / TAU, 1.0), C_RAT / 8.0, 0.03 if r.state != Runner.SIT else 0.015, 0.0))


func _flee(r: Runner, from_p: Vector3) -> void:
	r.state = Runner.FLEE
	r.away = from_p
	r.yaw = _yaw_away(r.p, from_p) + rng.randf_range(-0.4, 0.4)
	if r.hare:
		r.speed = rng.randf_range(9.0, 12.0)
		r.timer = rng.randf_range(3.0, 5.0)
		r.zig = 0.0
	else:
		r.speed = rng.randf_range(5.0, 6.5)
		r.timer = 2.5
		# the nearest way into a building, unless it's past whoever frightened it
		r.hole = Vector3.INF
		for k in 16:
			var a := TAU * k / 16.0
			for d in [1.5, 3.0, 5.0]:
				var q := r.p + Vector3(cos(a), 0, sin(a)) * float(d)
				if _solid(q) and _d2(q, from_p) > _d2(r.p, from_p) * 0.6:
					if r.hole.x == INF or _d2(q, r.p) < _d2(r.hole, r.p):
						r.hole = q
					break
		if cam_pos.distance_to(r.p) < 35.0:
			_call("squeak", r.p, -10.0, rng.randf_range(0.9, 1.2))


## A rat's way: along the nearest wall, if there's one beside it.
func _wall_yaw(r: Runner) -> float:
	for k in 8:
		var a := TAU * k / 8.0
		if _solid(r.p + Vector3(cos(a), 0, sin(a)) * 1.2):
			# run along it (one way or the other)
			var along := a + (PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5)
			return atan2(-cos(along), -sin(along))
	return r.yaw + rng.randf_range(-2.0, 2.0)


func _passable(p: Vector3, hare: bool) -> bool:
	if not _in_map(p) or _solid(p):
		return false
	var k := world.terrain.kind_at(p)
	return k != TerrainMap.WATER and k != TerrainMap.SHALLOW and k != TerrainMap.TRENCH and (not hare or k != TerrainMap.ROAD)


func _spawn_runner(r: Runner) -> void:
	for k in 14:
		var q := _around(0.05, 0.9)
		if not _unseen(q, SEE_RAT):
			continue
		if (_hare_spot(q) if r.hare else _rat_spot(q)) and _threat(q, 25.0 if r.hare else 8.0, 40.0) < 0:
			r.p = q
			r.home = q
			r.yaw = rng.randf() * TAU
			r.state = Runner.SIT
			r.timer = rng.randf_range(0.5, 4.0)
			r.up = 0.0
			r.zig = rng.randf() * 7.0
			r.on = true
			return


## Beside a wall, or among the rubble.
func _rat_spot(q: Vector3) -> bool:
	if not _feeding(q):
		return false
	if world.terrain.rubble[world.terrain.idx_of(q)] > 0:
		return true
	for k in 8:
		var a := TAU * k / 8.0
		if _solid(q + Vector3(cos(a), 0, sin(a)) * 1.3):
			return true
	return false


## Out in the grass, well clear of the town and of buildings.
func _hare_spot(q: Vector3) -> bool:
	if not _field(q) or world.terrain.kind_at(q) != TerrainMap.GROUND or world.atmo.grass_amount(q) < 0.45:
		return false
	if world.town_rect.size.x > 0.0 and world.town_rect.grow(25.0).has_point(Vector2(q.x, q.z)):
		return false
	for k in 4:
		var a := TAU * k / 4.0
		if _solid(q + Vector3(cos(a), 0, sin(a)) * 8.0):
			return false
	return true


# --- fish -----------------------------------------------------------------------------------------

## A few fish swimming together under the surface, keeping to water deep
## enough to hide in; now and then one jumps.
class School:
	var on := false
	var want := false
	var wait := 0.0  # until it next looks for somewhere to appear
	var sea := false
	var c := Vector3.ZERO
	var yaw := 0.0
	var aim := 0.0
	var speed := 0.6
	var dart := 0.0
	var turn_t := 0.0
	var look_t := 0.0
	var sy := INF  # the surface over it (worked out every other frame)
	var n := 0
	var off := PackedVector3Array()
	var ph := PackedFloat32Array()
	var depth := PackedFloat32Array()
	var jumper := -1  # the one in the air
	var jt := 0.0
	var j0 := Vector3.ZERO
	var jv := Vector3.ZERO
	var next_jump := 10.0

	## One of them gone (killed).
	func remove(i: int) -> void:
		off.remove_at(i)
		ph.remove_at(i)
		depth.remove_at(i)
		if jumper == i:
			jumper = -1
		elif jumper > i:
			jumper -= 1
		n -= 1
		if n <= 0:
			on = false


func _swim(s: School, dt: float) -> void:
	if not s.on:
		_appear(s, _spawn_school, dt)
		return
	if _d2(s.c, focus) > pow(reach * 1.15, 2.0) and s.jumper < 0:
		s.on = false  # (under the water: nobody sees it go)
		return
	if s.dart <= 0.0 and _scanned:
		# a boat coming through
		var ti := _threat(s.c, 0.0, 9.0)
		if ti >= 0:
			_dart(s, _threats[ti])
	s.dart -= dt
	s.turn_t -= dt
	if s.turn_t <= 0.0:
		s.turn_t = rng.randf_range(1.0, 3.5)
		s.aim = s.yaw + rng.randf_range(-0.9, 0.9)
	var sp := s.speed + (2.4 if s.dart > 0.0 else 0.0)
	# a look ahead a few times a second (it goes no more than a metre between)
	s.look_t -= dt
	if s.look_t <= 0.0:
		s.look_t = 0.25
		var look := 2.0 + sp
		if not _fish_water(s.c + Vector3(-sin(s.aim), 0, -cos(s.aim)) * look):
			for d in [0.8, -0.8, 1.6, -1.6, PI]:
				var y: float = s.aim + float(d)
				if _fish_water(s.c + Vector3(-sin(y), 0, -cos(y)) * look):
					s.aim = y
					break
	s.yaw = lerp_angle(s.yaw, s.aim, minf(1.0, dt * 2.0))
	var fw := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	var nc := s.c + fw * sp * dt
	if _in_map(nc) and world.terrain.base[world.terrain.idx_of(nc)] >= TerrainMap.WATER:
		s.c = nc
	else:
		s.aim += PI * 0.5
		s.look_t = 0.0
	var vis := _seen(s.c, 3.0, SEE_FISH)
	# a jump: up out of the water in an arc and back in with a splash
	s.next_jump -= dt
	if s.next_jump <= 0.0:
		s.next_jump = rng.randf_range(6.0, 25.0)
		if vis and s.jumper < 0 and cam_pos.distance_to(s.c) < 90.0:
			s.jumper = rng.randi() % s.n
			s.jt = 0.0
			s.j0 = s.c + Basis(Vector3.UP, s.yaw) * s.off[s.jumper]
			s.j0.y = _surf(s.j0)
			s.jv = fw * rng.randf_range(1.0, 2.0) + Vector3(0.0, rng.randf_range(2.6, 3.6), 0.0)
			if _wv():
				_wv().foam(s.j0, 0.35, 1.0, WaterView.RING)
	if not vis:
		return
	var hb := Basis(Vector3.UP, s.yaw)
	var b: Batch = _b[FISH]
	var pal := (C_SEAFISH if s.sea else C_FISH) / 8.0
	# (under the surface as it is just now: the swell drops it in the troughs; too
	# near it and the water shows them as a bright shoal, not a dark shape)
	if _frame % 2 == 0 or s.sy == INF:
		s.sy = _surf(s.c)  # (every other frame: the swell is dear to work out)
	var surf := s.sy
	var bed := world.terrain.deform_at(s.c) + 0.12
	for i in s.n:
		s.ph[i] += dt * TAU * (1.6 + sp * 2.2)
		if i == s.jumper:
			s.jt += dt
			var jp := s.j0 + s.jv * s.jt + Vector3(0.0, -4.9 * s.jt * s.jt, 0.0)
			var vy := s.jv.y - 9.8 * s.jt
			var hs := Vector2(s.jv.x, s.jv.z).length()
			b.put(jp, Basis.from_euler(Vector3(atan2(vy, hs), s.yaw, 0.0)), 1.0, Color(fmod(s.ph[i] * 2.0 / TAU, 1.0), pal, 0.06, 0.0))
			if s.jt > 0.2 and jp.y < _surf(jp):
				s.jumper = -1
				if _wv():
					_wv().foam(jp, 0.5, 1.4, WaterView.RING)
				_call("plop", jp, -8.0, rng.randf_range(0.85, 1.2), true)
			continue
		var q := s.c + hb * s.off[i] + Vector3(sin(t * 0.8 + i * 2.1), 0.0, cos(t * 0.7 + i * 1.3)) * 0.25
		q.y = clampf(surf - s.depth[i], bed, surf - 0.35)
		b.put(q, Basis(Vector3.UP, s.yaw + sin(t * 1.7 + i) * 0.18), 1.0, Color(fmod(s.ph[i] / TAU, 1.0), pal, 0.025 + 0.01 * minf(sp, 2.0), 0.0))


func _dart(s: School, from_p: Vector3) -> void:
	s.dart = 1.6
	s.aim = _yaw_away(s.c, from_p)


func _spawn_school(s: School) -> void:
	for k in 10:
		var q := _around(0.0, 1.0)
		if _fish_water(q):
			s.c = q
			s.sea = _sea(q)
			s.n = rng.randi_range(3, 6)
			s.off.resize(s.n)
			s.ph.resize(s.n)
			s.depth.resize(s.n)
			for i in s.n:
				s.off[i] = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-1.2, 1.2))
				s.ph[i] = rng.randf() * TAU
				s.depth[i] = rng.randf_range(0.45, 1.0)
			s.yaw = rng.randf() * TAU
			s.aim = s.yaw
			s.speed = rng.randf_range(0.4, 0.9)
			s.jumper = -1
			s.next_jump = rng.randf_range(3.0, 20.0)
			s.on = true
			return


# --- dolphins -------------------------------------------------------------------------------------

## A pod of dolphins cruising out at sea, each rolling up through the surface
## to breathe - the back and the fin showing, then gone - and now and then one
## leaping clear.
class Pod:
	var on := false
	var want := false
	var wait := 0.0  # until it next looks for somewhere to appear
	var c := Vector3.ZERO
	var yaw := 0.0
	var aim := 0.0
	var speed := 4.5
	var hurry := 0.0
	var turn_t := 0.0
	var look_t := 0.0
	var n := 0
	var off := PackedVector3Array()
	var cyc := PackedFloat32Array()  # how far through its breath each is (0..1)
	var dur := PackedFloat32Array()  # that breath's length (s)
	var leap := PackedByteArray()  # 1: this breath is a leap
	var beat := PackedFloat32Array()  # its flukes
	var was := PackedFloat32Array()  # how high it was last frame against the surface
	var size := PackedFloat32Array()

	## One of them gone (killed).
	func remove(i: int) -> void:
		off.remove_at(i)
		cyc.remove_at(i)
		dur.remove_at(i)
		leap.remove_at(i)
		beat.remove_at(i)
		was.remove_at(i)
		size.remove_at(i)
		n -= 1
		if n <= 0:
			on = false


const BREATH := 0.3  # of a breath, the part up through the surface
const LEAP := 0.45


func _pod(s: Pod, dt: float) -> void:
	if not s.on:
		_appear(s, _spawn_pod, dt)
		return
	if _d2(s.c, focus) > pow(reach * 1.25, 2.0):
		s.on = false
		return
	if _scanned:
		var ti := _threat(s.c, 0.0, 28.0)
		if ti >= 0:
			s.aim = _yaw_away(s.c, _threats[ti])
			s.hurry = 4.0
	s.hurry -= dt
	s.turn_t -= dt
	if s.turn_t <= 0.0:
		s.turn_t = rng.randf_range(3.0, 8.0)
		s.aim = s.yaw + rng.randf_range(-0.6, 0.6)
	s.look_t -= dt
	if s.look_t <= 0.0:
		s.look_t = 0.5
		if not _open_sea(s.c + Vector3(-sin(s.aim), 0, -cos(s.aim)) * 16.0):
			for d in [0.7, -0.7, 1.4, -1.4, 2.2, -2.2, PI]:
				var y: float = s.aim + float(d)
				if _open_sea(s.c + Vector3(-sin(y), 0, -cos(y)) * 16.0):
					s.aim = y
					break
	s.yaw = lerp_angle(s.yaw, s.aim, minf(1.0, dt * 0.6))
	var sp := s.speed * (1.6 if s.hurry > 0.0 else 1.0)
	var fw := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	s.c += fw * sp * dt
	var wv := _wv()
	var vis := _seen(s.c, 8.0, 220.0)
	var hb := Basis(Vector3.UP, s.yaw)
	var b: Batch = _b[DOLPHIN]
	var surf := (WaterMap.LEVEL + wv.height_at(s.c) if wv else WaterMap.LEVEL) if vis else 0.0  # (once a pod: dear to work out)
	for i in s.n:
		s.cyc[i] += dt / s.dur[i]
		if s.cyc[i] >= 1.0:
			s.cyc[i] -= 1.0
			s.dur[i] = rng.randf_range(2.8, 4.2)
			s.leap[i] = 1 if rng.randf() < 0.1 else 0
		s.beat[i] += dt * TAU * (1.2 + sp * 0.12)
		var q := s.c + hb * s.off[i]
		var y := _breath_y(s.cyc[i], s.leap[i] == 1)
		# a splash as it breaks the surface (a big one, leaping) and as it goes back in
		var top := y + 0.2 * s.size[i]
		if vis and (signf(top) != signf(s.was[i])):
			var big := s.leap[i] == 1
			if wv and (big or top > 0.0):
				wv.foam(q, 1.2 if big else 0.55, 1.8 if big else 1.0, WaterView.RING)
			if big and top < 0.0:
				_call("splash", q, -4.0, rng.randf_range(0.85, 1.1), true)
		s.was[i] = top
		if not vis:
			continue
		q.y = surf + y
		var pitch := atan2((_breath_y(s.cyc[i] + 0.01, s.leap[i] == 1) - y) / (0.01 * s.dur[i]), sp)
		var bas := Basis.from_euler(Vector3(pitch, s.yaw, sin(s.beat[i] * 0.3 + i) * 0.08))
		b.put(q, bas, s.size[i], Color(fmod(s.beat[i] / TAU, 1.0), C_DOLPHIN / 8.0, 0.09, 1.0))


## A dolphin's height against the surface (its middle) through a breath: up
## through the surface in an arc, the back and fin showing (clear of the water
## altogether in a leap), then down and along underneath.
static func _breath_y(s: float, leap: bool) -> float:
	s = fmod(s, 1.0)
	var up := LEAP if leap else BREATH
	if s < up:
		return -0.75 + (2.9 if leap else 0.72) * sin(PI * s / up)
	return -0.75 - 0.8 * sin(PI * (s - up) / (1.0 - up))


func _spawn_pod(s: Pod) -> void:
	if world.water.coast.is_empty():
		return
	for k in 10:
		var q := _around(0.15, 1.0)
		if not _open_sea(q):
			continue
		s.c = q
		s.n = rng.randi_range(2, 5)
		s.off.resize(s.n)
		s.cyc.resize(s.n)
		s.dur.resize(s.n)
		s.beat.resize(s.n)
		s.was.resize(s.n)
		s.size.resize(s.n)
		s.leap.resize(s.n)
		var base := rng.randf()
		for i in s.n:
			s.off[i] = Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-3.0, 5.0))
			s.cyc[i] = fmod(base + rng.randf_range(0.0, 0.2), 1.0)  # (they tend to come up together)
			s.dur[i] = rng.randf_range(2.8, 4.2)
			s.beat[i] = rng.randf() * TAU
			s.was[i] = -1.0
			s.leap[i] = 0
			s.size[i] = rng.randf_range(0.85, 1.1)
		if s.n >= 4:
			s.size[s.n - 1] = 0.6  # a calf
			s.off[s.n - 1] = s.off[0] + Vector3(1.2, 0.0, 0.6)
		s.yaw = rng.randf() * TAU
		s.aim = s.yaw
		s.speed = rng.randf_range(3.5, 5.5)
		s.on = true
		return


# --- shot, blown up, dead ---------------------------------------------------------------------

## A round's flight from a to b (Fx calls this for every shot): a bird or a
## beast it passes through dies - only for the eye: the round flies on as it
## would have - and everything it cracks past, or strikes the ground near,
## takes fright.
func shot(a: Vector3, b: Vector3) -> void:
	if level <= 0 or _cam == null:
		return
	var t0 := Time.get_ticks_usec()
	_shot(a, b)
	_cost(t0)


## What it costs goes in the performance overlay (and FL_DEBUG_WILDLIFE's report).
func _cost(t0: int) -> void:
	world.vp("wildlife", t0)
	if _dbg:
		_dbg_us += Time.get_ticks_usec() - t0


func _shot(a: Vector3, b: Vector3) -> void:
	var ab := b - a
	var ll := ab.length_squared()
	if ll < 0.01 or _seg_d2(Vector3(a.x, 0, a.z), Vector3(ab.x, 0, ab.z), maxf(ab.x * ab.x + ab.z * ab.z, 0.0001), Vector3(focus.x, 0, focus.z)) > pow(reach + 20.0, 2.0):
		return
	var dir := ab / sqrt(ll)
	for g in 2:
		for f: Flock in (_flocks if g == 0 else _ducks):
			if not f.on:
				continue
			var mid := f.c if f.air else Vector3(f.c.x, f.gy, f.c.z)
			var d2 := _seg_d2(a, ab, ll, mid)
			if d2 > 10.0 * 10.0 and _d2(b, mid) > 12.0 * 12.0:
				continue
			var mesh := DUCK if f.duck else SONG
			var hr: float = HIT_R[mesh] * f.sz
			for i in range(f.n - 1, -1, -1):
				var q := f.p[i] if f.air else Vector3(f.p[i].x, f.gy + REST_Y[mesh] * f.sz, f.p[i].z)
				if _seg_d2(a, ab, ll, q) < hr * hr:
					_kill_bird(f, i, dir)
			if f.on and not f.air:
				_fright("ducks" if f.duck else "birds", "round")
				_take_off(f, a + ab * _seg_t(a, ab, ll, mid))
	for g in 2:
		for s: Soarer in (_soarers if g == 0 else _bats):
			if not s.on:
				continue
			var d2 := _seg_d2(a, ab, ll, s.p)
			var mesh := SONG if s.kind == BAT else BIG
			var hr: float = HIT_R[mesh] * float(SOAR_SIZE[s.kind])
			if d2 < hr * hr:
				_kill(mesh, s.p, Vector3(-sin(s.hd), 0.0, -cos(s.hd)) * 6.0 + dir * 2.0, s.hd, SOAR_SIZE[s.kind], Color(0.62, s.kind / 8.0, 0.35, 0.0), FEATHER[s.kind])
				s.on = false
			elif d2 < 12.0 * 12.0 and s.scared <= 0.0:
				_scare(s, a + ab * _seg_t(a, ab, ll, s.p))
	for r: Runner in _runners:
		if not r.on:
			continue
		var mesh := HARE if r.hare else RAT
		var q := r.p + Vector3(0.0, REST_Y[mesh], 0.0)
		var d2 := _seg_d2(a, ab, ll, q)
		if d2 < HIT_R[mesh] * HIT_R[mesh]:
			_kill(mesh, q, dir * 1.5 + Vector3(0.0, 1.5, 0.0), r.yaw, 1.0, Color(0.0, (C_HARE if r.hare else C_RAT) / 8.0, 0.0, 0.0))
			r.on = false
		elif r.state != Runner.FLEE and (d2 < 6.0 * 6.0 or _d2(b, r.p) < 8.0 * 8.0):
			_fright("hare" if r.hare else "rat", "round")
			_flee(r, b)
	# into the water: a fish right under where it struck, and a dolphin at the surface
	var wet: bool = world.water.wet_at(b) and b.y < 0.3
	for sc: School in _schools:
		if not sc.on or not wet or _d2(sc.c, b) > 6.0 * 6.0:
			continue
		var hb := Basis(Vector3.UP, sc.yaw)
		for i in range(sc.n - 1, -1, -1):
			var q := sc.c + hb * sc.off[i]
			if _d2(q, b) < 0.45 * 0.45:
				q.y = _surf(q) - sc.depth[i]
				_kill(FISH, q, Vector3.ZERO, sc.yaw, 1.0, Color(0.0, (C_SEAFISH if sc.sea else C_FISH) / 8.0, 0.0, 0.0))
				sc.remove(i)
		if sc.on:
			_dart(sc, b)
	for pd: Pod in _pods:
		if not pd.on or _d2(pd.c, b) > 15.0 * 15.0 and _seg_d2(a, ab, ll, pd.c) > 15.0 * 15.0:
			continue
		var hb := Basis(Vector3.UP, pd.yaw)
		for i in range(pd.n - 1, -1, -1):
			var y := _breath_y(pd.cyc[i], pd.leap[i] == 1)
			if y < -0.5:
				continue  # (under the water: the round never gets to it)
			var q := pd.c + hb * pd.off[i]
			q.y = _surf(q) + y
			var hr: float = HIT_R[DOLPHIN] * pd.size[i]
			if _seg_d2(a, ab, ll, q) < hr * hr:
				_kill(DOLPHIN, q, Vector3.ZERO, pd.yaw, pd.size[i], Color(0.0, C_DOLPHIN / 8.0, 0.0, 1.0))
				pd.remove(i)
		if pd.on:
			pd.aim = _yaw_away(pd.c, b)
			pd.hurry = 6.0


## A shell, a bomb, a grenade at p (Fx calls this, `size` as it's drawn): what's
## close is killed and thrown; in the water, the fish near it are stunned and
## float up. (startle() then sends everything further off running.)
func blast(p: Vector3, size: float) -> void:
	if level <= 0 or _cam == null or _d2(p, focus) > pow(reach + 30.0, 2.0):
		return
	var t0 := Time.get_ticks_usec()
	_blast(p, size)
	_cost(t0)


func _blast(p: Vector3, size: float) -> void:
	var kr := 1.5 + 2.5 * size
	var kr2 := kr * kr
	for g in 2:
		for f: Flock in (_flocks if g == 0 else _ducks):
			if not f.on or _d2(f.c, p) > pow(kr + 6.0, 2.0):
				continue
			for i in range(f.n - 1, -1, -1):
				var q := f.p[i] if f.air else Vector3(f.p[i].x, f.gy, f.p[i].z)
				if q.distance_squared_to(p) < kr2:
					_kill_bird(f, i, (q - p).normalized(), (q - p).normalized() * (4.0 + 5.0 * size) + Vector3(0.0, 3.0 + 3.0 * size, 0.0))
	for g in 2:
		for s: Soarer in (_soarers if g == 0 else _bats):
			if s.on and s.p.distance_squared_to(p) < kr2 * 1.5:
				var mesh := SONG if s.kind == BAT else BIG
				_kill(mesh, s.p, (s.p - p).normalized() * 6.0, s.hd, SOAR_SIZE[s.kind], Color(0.62, s.kind / 8.0, 0.35, 0.0), FEATHER[s.kind])
				s.on = false
	for r: Runner in _runners:
		if r.on and _d2(r.p, p) < kr2:
			var mesh := HARE if r.hare else RAT
			var away := r.p - p
			away.y = 0.0
			_kill(mesh, r.p + Vector3(0.0, REST_Y[mesh], 0.0), away.normalized() * (3.0 + 4.0 * size) + Vector3(0.0, 3.0 + 2.0 * size, 0.0), r.yaw, 1.0,
				Color(0.0, (C_HARE if r.hare else C_RAT) / 8.0, 0.0, 0.0))
			r.on = false
	if world.water.wet_at(p) and p.y < 1.0:
		var fr := 3.0 + 6.0 * size
		for sc: School in _schools:
			if not sc.on or _d2(sc.c, p) > pow(fr + 3.0, 2.0):
				continue
			var hb := Basis(Vector3.UP, sc.yaw)
			for i in range(sc.n - 1, -1, -1):
				var q := sc.c + hb * sc.off[i]
				if _d2(q, p) < fr * fr:
					q.y = _surf(q) - sc.depth[i]
					_kill(FISH, q, Vector3.ZERO, sc.yaw + rng.randf_range(-1, 1), 1.0, Color(0.0, (C_SEAFISH if sc.sea else C_FISH) / 8.0, 0.0, 0.0))
					sc.remove(i)
		for pd: Pod in _pods:
			if not pd.on:
				continue
			var hb := Basis(Vector3.UP, pd.yaw)
			for i in range(pd.n - 1, -1, -1):
				var q := pd.c + hb * pd.off[i]
				if _d2(q, p) < pow(1.5 + 2.0 * size, 2.0):
					q.y = _surf(q) + _breath_y(pd.cyc[i], pd.leap[i] == 1)
					_kill(DOLPHIN, q, Vector3.ZERO, pd.yaw, pd.size[i], Color(0.0, C_DOLPHIN / 8.0, 0.0, 1.0))
					pd.remove(i)


## A grass fire at p (Fx calls this): everything keeps clear of it while it burns.
func fire(p: Vector3, r: float, secs: float) -> void:
	if level <= 0:
		return
	_fires.append([p, t + secs])
	startle(p, r + 20.0)


func _kill_bird(f: Flock, i: int, dir: Vector3, thrown := Vector3.INF) -> void:
	var mesh := DUCK if f.duck else SONG
	var q := f.p[i] if f.air else Vector3(f.p[i].x, f.gy + REST_Y[mesh] * f.sz, f.p[i].z)
	var v := thrown
	if v.x == INF:
		# shot: out of the air with the way it was flying; on the ground, knocked over
		v = Vector3(-sin(f.hd) * f.speed * 0.5, f.vy, -cos(f.hd) * f.speed * 0.5) if f.air else dir * 0.6 + Vector3(0.0, 0.8, 0.0)
	var sp: int = int(f.sp[i] * 8.0 + 0.5)
	_kill(mesh, q, v, f.yaw[i] if not f.air else f.hd, f.sz, Color(0.62, f.sp[i], 0.35, 0.0), FEATHER[sp])
	f.remove(i)


## Something killed at p, moving at v: a puff of blood (and feathers, from a
## bird), the rest nearby take fright, and the body falls and lies there.
func _kill(mesh: int, p: Vector3, v: Vector3, yaw: float, sz: float, c: Color, feather := Color(0, 0, 0, 0)) -> void:
	_fright(["bird", "crow", "duck", "rat", "hare", "fish", "dolphin"][mesh], "killed")
	var k := Carcass.new()
	k.b = mesh
	k.p = p
	k.v = v
	k.yaw = yaw
	k.sz = sz
	k.c = c
	k.side = 1.0 if rng.randf() < 0.5 else -1.0
	k.tumble = rng.randf_range(4.0, 9.0) if v.length() > 2.0 else 0.0
	k.water = mesh == FISH or mesh == DOLPHIN or (world.water.wet_at(p) and world.terrain.deform_at(p) < WaterMap.LEVEL - 0.1)
	if _dead.size() >= DEAD_MAX:
		# room for it: the oldest out of sight goes (the oldest of all if none is)
		var gone := 0
		for i in _dead.size():
			if _unseen((_dead[i] as Carcass).p, 60.0):
				gone = i
				break
		_dead.remove_at(gone)
	_dead.append(k)
	var g: GunFx = world.fx.gunfx if world.fx else null
	if g and cam_pos.distance_to(p) < 130.0 and mesh != FISH:
		var s := sqrt(sz) * (2.0 if mesh == DOLPHIN else (1.0 if mesh == BIG or mesh == DUCK or mesh == HARE else 0.6))
		g.puff(p, v * 0.2 + Vector3(0.0, 0.4, 0.0), 0.02 * s, 0.14 * s, 0.35, Color(0.3, 0.03, 0.02, 0.6), 8.0, 0.0, 1.0, 0.2)
		if feather.a > 0.0:
			for i in int(4 + 6 * s):
				var fv := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.2), rng.randf_range(-1, 1)) * rng.randf_range(0.8, 2.2) + v * 0.15
				var fl := rng.randf_range(0.025, 0.045) * s
				g.chunk(p, fv, Vector3(fl * 0.6, fl * 0.06, fl), rng.randf_range(6.0, 10.0), feather * rng.randf_range(0.85, 1.15), _gy(p), 5.0, 3.6)
	if mesh == RAT and cam_pos.distance_to(p) < 35.0:
		_call("squeak", p, -9.0, rng.randf_range(1.1, 1.3), true)
	startle(p, 14.0)


## A dead creature: falling (a bird out of the air, something thrown by a
## blast), or floating up (a fish), then lying where it came down (afloat, if
## that's the water) until it's been out of sight a good while.
class Carcass:
	var b := 0  # which mesh
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var yaw := 0.0
	var side := 1.0  # which side it lies on
	var tumble := 0.0  # how fast it turns over as it falls
	var spin := 0.0
	var sz := 1.0
	var c := Color()  # what its shader draws it by
	var water := false
	var sy := WaterMap.LEVEL  # the surface it floats on
	var down := false
	var lain := 0.0


func _carcasses(dt: float) -> void:
	for i in range(_dead.size() - 1, -1, -1):
		var k: Carcass = _dead[i]
		var rest: float = REST_Y[k.b] * k.sz
		if not k.down:
			var lo := _surf(k.p) + rest if k.water else _gy(k.p) + rest
			if k.water and k.p.y < lo:
				# (underwater: it floats up)
				k.p.y = minf(lo, k.p.y + dt * 0.5)
				k.p += Vector3(k.v.x, 0.0, k.v.z) * dt
				k.v *= 1.0 - minf(1.0, dt * 2.0)
				if k.p.y >= lo:
					k.down = true
					k.sy = lo - rest
			else:
				k.v.y -= 9.8 * dt
				k.v *= 1.0 - minf(1.0, dt * (0.9 if k.b == SONG else 0.3))  # (a small bird's wings and feathers drag)
				k.p += k.v * dt
				k.spin += k.tumble * dt
				if k.p.y <= lo:
					k.water = k.water or (world.water.wet_at(k.p) and world.terrain.deform_at(k.p) < WaterMap.LEVEL - 0.1)
					k.sy = _surf(k.p)
					k.p.y = k.sy + rest if k.water else lo
					k.down = true
					if k.water and _wv() and cam_pos.distance_to(k.p) < 90.0:
						_wv().foam(k.p, 0.3 + 0.3 * k.sz, 1.2, WaterView.RING)
		else:
			k.lain += dt
			if k.water:
				if (_frame + i) % 3 == 0 and _seen(k.p, 1.0, 160.0):
					k.sy = _surf(k.p)  # (the swell is dear to work out: now and then, and only when it shows)
				k.p.y = k.sy + rest + 0.01 * sin(t * 1.3 + i)
				k.yaw += sin(t * 0.2 + i) * 0.03 * dt
			if (k.lain > DEAD_LIFE or _d2(k.p, focus) > pow(reach * 1.5, 2.0)) and _unseen(k.p, 60.0):
				_dead.remove_at(i)
				continue
		if not _seen(k.p, 1.0, 160.0):
			continue
		var roll: float = REST_ROLL[k.b] * k.side
		var bas := Basis.from_euler(Vector3(k.spin, k.yaw, roll + k.spin * 0.7)) if not k.down else Basis.from_euler(Vector3(0.0, k.yaw, roll))
		(_b[k.b] as Batch).put(k.p, bas, k.sz, k.c)


static func _seg_t(a: Vector3, ab: Vector3, ll: float, p: Vector3) -> float:
	return clampf((p - a).dot(ab) / ll, 0.0, 1.0)


## How far (squared) p is from the segment from a along ab (ll: its length squared).
static func _seg_d2(a: Vector3, ab: Vector3, ll: float, p: Vector3) -> float:
	return (a + ab * _seg_t(a, ab, ll, p)).distance_squared_to(p)


# --- where things are ----------------------------------------------------------------------------

## (FL_DEBUG_WILDLIFE) Counts a fright (or a death): what, and at what.
func _fright(what: String, at: String) -> void:
	if not _dbg:
		return
	var k := what + "@" + at
	_dbg_fright[k] = int(_dbg_fright.get(k, 0)) + 1


## A group that isn't about yet looks for somewhere to appear, now and then
## (not every frame: where there's no water or no town, it would find none
## every frame).
func _appear(g: Object, spawn: Callable, dt: float) -> void:
	g.wait -= dt
	if not g.want or g.wait > 0.0 or not _can_spawn():
		return
	spawn.call(g)
	if not g.on:
		g.wait = rng.randf_range(1.5, 3.0)

func _can_spawn() -> bool:
	if _first:
		return true
	_spawns += 1
	return _spawns <= 3


static func _d2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


static func _yaw_away(p: Vector3, from_p: Vector3) -> float:
	var d := p - from_p
	if Vector2(d.x, d.z).length() < 0.01:
		return 0.0
	return atan2(-d.x, -d.z)


## A random spot round the camera's focus, from lo to hi of the way out.
func _around(lo: float, hi: float) -> Vector3:
	var a := rng.randf() * TAU
	var d := reach * sqrt(rng.randf_range(lo * lo, hi * hi))
	var lim := MapDims.HALF - 4.0
	return Vector3(clampf(focus.x + cos(a) * d, -lim, lim), 0.0, clampf(focus.z + sin(a) * d, -lim, lim))


## In the camera's view (give or take `pad` metres) and near enough to make
## out: worth drawing. A group is checked as one, so it's a few calls a group,
## not one a creature.
func _seen(p: Vector3, pad: float, far: float) -> bool:
	if cam_pos.distance_squared_to(p) > far * far:
		return false
	for pl in _planes:
		if pl.distance_to(p) > pad:
			return false
	return true


## Somewhere a creature can appear (or vanish) without the player seeing it:
## off the screen, or too far off to make out.
func _unseen(p: Vector3, far: float) -> bool:
	return _first or cam_pos.distance_squared_to(p) > far * far or not _cam.is_position_in_frustum(p)


func _in_map(p: Vector3) -> bool:
	var lim := MapDims.HALF - 2.0
	return absf(p.x) < lim and absf(p.z) < lim


func _solid(p: Vector3) -> bool:
	return _in_map(p) and world.terrain.solid[world.terrain.idx_of(p)] > 0


func _gy(p: Vector3) -> float:
	return world.terrain.deform_at(p)


func _wv() -> WaterView:
	return world.atmo.water_view if world.atmo else null


## The water's surface at p (the swell lifts it at sea).
func _surf(p: Vector3) -> float:
	var wv := _wv()
	return WaterMap.LEVEL + (wv.height_at(p) if wv else 0.0)


## Open ground small birds come down on to feed.
func _field(p: Vector3) -> bool:
	if not _in_map(p) or _solid(p):
		return false
	var k := world.terrain.kind_at(p)
	return k == TerrainMap.GROUND or k == TerrainMap.MUD or k == TerrainMap.CRATER


## Where small birds come down to feed, and rats run: ground the grass won't
## hide them in (roads, yards, pavements, mud, shell holes).
func _feeding(p: Vector3) -> bool:
	if not _in_map(p) or _solid(p) or world.water.on_deck(p):
		return false
	var k := world.terrain.kind_at(p)
	if k == TerrainMap.WATER or k == TerrainMap.SHALLOW or k == TerrainMap.TRENCH:
		return false
	if k == TerrainMap.ROAD or k == TerrainMap.MUD or k == TerrainMap.CRATER or k == TerrainMap.RUBBLE:
		return true
	var g: Grass = world.atmo.grass
	return g == null or g.bare(p) or world.atmo.grass_amount(p) < 0.15


## Water deep enough for a fish to keep under.
func _fish_water(p: Vector3) -> bool:
	if not _in_map(p):
		return false
	var b: int = world.terrain.base[world.terrain.idx_of(p)]
	return (b == TerrainMap.WATER or b == TerrainMap.SHALLOW) and world.terrain.deform_at(p) < WaterMap.LEVEL - 0.7


func _sea(p: Vector3) -> bool:
	return not world.water.coast.is_empty() and p.x > world.water.coast_x(p.z) - 6.0


## The open sea, well off the beach: dolphins' water.
func _open_sea(p: Vector3) -> bool:
	if not _in_map(p) or world.water.coast.is_empty() or p.x < world.water.coast_x(p.z) + 22.0:
		return false
	return world.terrain.base[world.terrain.idx_of(p)] == TerrainMap.WATER


## Ponds and rivers, off the bank: ducks.
func _fresh(p: Vector3) -> bool:
	if not _in_map(p) or _sea(p):
		return false
	var b: int = world.terrain.base[world.terrain.idx_of(p)]
	return (b == TerrainMap.WATER or b == TerrainMap.SHALLOW) and world.terrain.deform_at(p) < WaterMap.LEVEL - 0.2


## A bird's song, a cry, a splash: heard on the ambience, and only now and
## then (`always`: a flock going up, a splash, which happen when they happen).
func _call(sname: String, p: Vector3, vol_db: float, pitch: float, always := false) -> void:
	if not always:
		if _call_t > 0.0:
			return
		_call_t = rng.randf_range(1.0, 3.0)
	Sfx.play(sname, p, vol_db, pitch, &"Ambience")


# --- drawing -------------------------------------------------------------------------------------

## All of one kind of creature, written into its MultiMesh's buffer each frame
## and uploaded in one go, however many there are.
class Batch:
	var mm := MultiMesh.new()
	var mi := MultiMeshInstance3D.new()
	var buf := PackedFloat32Array()
	var n := 0
	var cap := 0

	func _init(mesh: Mesh, mat: Material, size: int) -> void:
		cap = size
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = size
		mm.visible_instance_count = 0
		# (they're all round the camera: never culled as a whole)
		mm.custom_aabb = AABB(Vector3(-MapDims.HALF - 400.0, -20.0, -MapDims.HALF - 400.0), Vector3(MapDims.N + 800.0, 200.0, MapDims.N + 800.0))
		buf.resize(size * 16)
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	## One creature: where, its turn, its size, and what the shader animates it by.
	func put(o: Vector3, b: Basis, s: float, c: Color) -> void:
		if n >= cap:
			return
		var i := n * 16
		buf[i] = b.x.x * s
		buf[i + 1] = b.y.x * s
		buf[i + 2] = b.z.x * s
		buf[i + 3] = o.x
		buf[i + 4] = b.x.y * s
		buf[i + 5] = b.y.y * s
		buf[i + 6] = b.z.y * s
		buf[i + 7] = o.y
		buf[i + 8] = b.x.z * s
		buf[i + 9] = b.y.z * s
		buf[i + 10] = b.z.z * s
		buf[i + 11] = o.z
		buf[i + 12] = c.r
		buf[i + 13] = c.g
		buf[i + 14] = c.b
		buf[i + 15] = c.a
		n += 1

	func flush() -> void:
		if n > 0:
			mm.buffer = buf
		if mm.visible_instance_count != n:
			mm.visible_instance_count = n
		n = 0

	func clear() -> void:
		n = 0
		mm.visible_instance_count = 0


# --- the models (forward is -z, up +y). UV2 carries x: how much that point
# moves (1 on a wing; how far down the tail), y: the part (/ 8); UV x how far
# out along a wing from the shoulder. (Not the vertex colour: the browser
# build's renderer multiplies that by an instance colour these MultiMeshes
# don't have, and it comes out black.) ---------------------------------------------------

## A body lofted along z through cross-sections [z, half width, half height,
## middle's height], each an ellipse `seg` points round (front to back, a
## section of size 0 closing each end). Above the middle is `top`, below it
## `under`; from z = bend.x back to bend.y the bend weight grows 0 -> 1.
static func _loft(st: SurfaceTool, secs: Array, seg: int, top: int, under: int, bend := Vector2(INF, INF), flag := 0.0) -> void:
	var rings: Array = []
	for si in secs.size():
		var s: Array = secs[si]
		var prv: Array = secs[maxi(si - 1, 0)]
		var nxt: Array = secs[mini(si + 1, secs.size() - 1)]
		var dz := float(nxt[0]) - float(prv[0])
		var slope := ((float(nxt[1]) + float(nxt[2])) - (float(prv[1]) + float(prv[2]))) * 0.5 / dz if absf(dz) > 1e-5 else 0.0
		var z := float(s[0])
		var w := 0.0
		if bend.x != INF:
			w = pow(clampf((z - bend.x) / (bend.y - bend.x), 0.0, 1.0), 1.6)
		var ring: Array = []
		for k in seg:
			var a := TAU * k / seg
			var ca := cos(a)
			var sa := sin(a)
			var v := Vector3(ca * float(s[1]), float(s[3]) + sa * float(s[2]), z)
			var nrm := Vector3(ca * maxf(float(s[2]), 1e-4), sa * maxf(float(s[1]), 1e-4), 0.0).normalized()
			nrm.z = -slope
			ring.append([v, nrm.normalized(), Vector2(w if flag == 0.0 else flag, float(top if sa >= -0.15 else under) / 8.0)])
		rings.append(ring)
	for si in rings.size() - 1:
		var r0: Array = rings[si]
		var r1: Array = rings[si + 1]
		for k in seg:
			var k2 := (k + 1) % seg
			for v in [r0[k], r1[k], r1[k2], r0[k], r1[k2], r0[k2]]:
				st.set_uv(Vector2.ZERO)
				st.set_uv2(v[2])
				st.set_normal(v[1])
				st.add_vertex(v[0])


## A flat triangle (both sides drawn), each corner [point, part, weight]. A
## wing's (shoulder >= 0) carries how far out from the shoulder each corner
## is, which folding it draws in by.
static func _flat(st: SurfaceTool, pts: Array, nrm: Vector3, shoulder := -1.0) -> void:
	for v in pts:
		st.set_uv(Vector2(maxf(absf((v[0] as Vector3).x) - shoulder, 0.0) if shoulder >= 0.0 else 0.0, 0.0))
		st.set_uv2(Vector2(float(v[2]), float(v[1]) / 8.0))
		st.set_normal(nrm)
		st.add_vertex(v[0])


## A tapered four-sided stick from a to b (legs, ears).
static func _stick(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, pa: int, pb: int, w := 0.0) -> void:
	var ax := (b - a).normalized()
	var side := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(ax).normalized()
	var dirs := [side, up, -side, -up]
	for k in 4:
		var d0: Vector3 = dirs[k]
		var d1: Vector3 = dirs[(k + 1) % 4]
		var n := (d0 + d1).normalized()
		var quad := [[a + d0 * r0, pa], [b + d0 * r1, pb], [b + d1 * r1, pb], [a + d0 * r0, pa], [b + d1 * r1, pb], [a + d1 * r0, pa]]
		for q in quad:
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2(w, float(q[1]) / 8.0))
			st.set_normal(n)
			st.add_vertex(q[0])
	# the ends
	for e in [[b, r1, pb, ax], [a, r0, pa, -ax]]:
		var c: Vector3 = e[0]
		var r: float = e[1]
		for k in [1, 2]:
			for d in [dirs[0], dirs[k], dirs[k + 1]]:
				st.set_uv(Vector2.ZERO)
				st.set_uv2(Vector2(w, float(e[2]) / 8.0))
				st.set_normal(e[3])
				st.add_vertex(c + (d as Vector3) * r)


## A bird: its length, body half-width, wingspan and the wing's chord, the
## head's radius, the bill's length, where the head sits (forward of the
## breast, above the middle), the tail's length, and how high the body rides
## (a duck sits in the water).
static func _bird_mesh(ln: float, bw: float, span: float, chord: float, head: float, bill: float, neck: Vector2, tail: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := ln * 0.5
	var y := lift
	_loft(st, [[-h * 0.62, 0.0, 0.0, y], [-h * 0.52, bw * 0.7, bw * 0.7, y], [-h * 0.22, bw, bw * 0.95, y - bw * 0.05],
		[h * 0.2, bw * 0.86, bw * 0.8, y], [h * 0.55, bw * 0.42, bw * 0.36, y + bw * 0.1], [h * 0.72, 0.0, 0.0, y + bw * 0.16]], 8, P_BACK, P_BELLY)
	var hz := -h * 0.6 - head * 0.4 - neck.x
	var hy := y + neck.y
	if neck.y > head:
		_stick(st, Vector3(0.0, y + bw * 0.4, -h * 0.4), Vector3(0.0, hy - head * 0.3, hz + head * 0.2), bw * 0.42, head * 0.6, P_HEAD, P_HEAD)
	_loft(st, [[hz - head, 0.0, 0.0, hy - head * 0.1], [hz - head * 0.7, head * 0.7, head * 0.68, hy], [hz, head, head, hy],
		[hz + head * 0.7, head * 0.72, head * 0.72, hy], [hz + head, 0.0, 0.0, hy]], 7, P_HEAD, P_HEAD)
	var bz := hz - head * 0.75
	_loft(st, [[bz - bill, 0.0, 0.0, hy - head * 0.22], [bz, head * 0.36, head * 0.22, hy - head * 0.15], [bz + head * 0.3, 0.0, 0.0, hy - head * 0.15]], 5, P_BILL, P_BILL)
	# the tail
	var ty := y + bw * 0.15
	for sx in [1.0, -1.0]:
		_flat(st, [[Vector3(0.0, ty, h * 0.45), P_TIP, 0.0], [Vector3(sx * bw * 0.85, ty, h * 0.5 + tail), P_TIP, 0.0], [Vector3(0.0, ty, h * 0.55 + tail), P_TIP, 0.0]], Vector3.UP)
	# the wings: inner half and outer, swept back to the tip
	var wy := y + bw * 0.45
	for sx in [1.0, -1.0]:
		var rf := Vector3(sx * bw * 0.6, wy, -chord * 0.5)
		var rb := Vector3(sx * bw * 0.6, wy, chord * 0.5)
		var ef := Vector3(sx * span * 0.27, wy, -chord * 0.45)
		var eb := Vector3(sx * span * 0.27, wy, chord * 0.62)
		var tip := Vector3(sx * span * 0.5, wy, chord * 0.2)
		var tb := Vector3(sx * span * 0.45, wy, chord * 0.7)
		for tri in [[[rf, P_WING], [ef, P_WING], [rb, P_WING]], [[ef, P_WING], [eb, P_WING], [rb, P_WING]],
				[[ef, P_WING], [tip, P_TIP], [eb, P_WING]], [[tip, P_TIP], [tb, P_TIP], [eb, P_WING]]]:
			_flat(st, [[tri[0][0], tri[0][1], 1.0], [tri[1][0], tri[1][1], 1.0], [tri[2][0], tri[2][1], 1.0]], Vector3.UP, bw * 0.6)
	return st.commit()


## A brown rat: a long low body, a pointed snout, round ears and a long bare
## tail that swings as it runs.
static func _rat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, [[-0.15, 0.0, 0.0, 0.035], [-0.135, 0.013, 0.012, 0.036], [-0.1, 0.03, 0.026, 0.043], [-0.07, 0.036, 0.033, 0.047],
		[-0.03, 0.048, 0.042, 0.05], [0.03, 0.058, 0.05, 0.052], [0.08, 0.05, 0.043, 0.048], [0.11, 0.026, 0.024, 0.038], [0.125, 0.0, 0.0, 0.033]], 8, P_BACK, P_BELLY)
	_loft(st, [[-0.155, 0.0, 0.0, 0.034], [-0.146, 0.006, 0.006, 0.035], [-0.14, 0.0, 0.0, 0.035]], 4, P_HEAD, P_HEAD)
	for sx in [1.0, -1.0]:
		_flat(st, [[Vector3(sx * 0.014, 0.06, -0.085), P_HEAD, 0.0], [Vector3(sx * 0.03, 0.085, -0.08), P_HEAD, 0.0], [Vector3(sx * 0.024, 0.062, -0.07), P_HEAD, 0.0]], Vector3(sx, 0.4, 0.0).normalized())
	# the tail, as a thin strip
	var n := 7
	for k in n:
		var z0 := 0.11 + 0.2 * k / n
		var z1 := 0.11 + 0.2 * (k + 1) / n
		var w0 := lerpf(0.007, 0.002, float(k) / n)
		var w1 := lerpf(0.007, 0.002, float(k + 1) / n)
		var y0 := lerpf(0.03, 0.012, float(k) / n)
		var y1 := lerpf(0.03, 0.012, float(k + 1) / n)
		var a := float(k) / n
		var b := float(k + 1) / n
		_flat(st, [[Vector3(-w0, y0, z0), P_HEAD, a], [Vector3(w0, y0, z0), P_HEAD, a], [Vector3(w1, y1, z1), P_HEAD, b]], Vector3.UP)
		_flat(st, [[Vector3(-w0, y0, z0), P_HEAD, a], [Vector3(w1, y1, z1), P_HEAD, b], [Vector3(-w1, y1, z1), P_HEAD, b]], Vector3.UP)
	return st.commit()


## A brown hare: a long back, big haunches, long black-tipped ears up and a
## white scut.
static func _hare_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, [[-0.12, 0.0, 0.0, 0.17], [-0.1, 0.05, 0.06, 0.17], [-0.05, 0.075, 0.085, 0.16], [0.05, 0.095, 0.105, 0.155],
		[0.14, 0.1, 0.11, 0.15], [0.2, 0.07, 0.08, 0.14], [0.23, 0.0, 0.0, 0.14]], 8, P_BACK, P_BELLY)
	_loft(st, [[-0.29, 0.0, 0.0, 0.2], [-0.27, 0.025, 0.025, 0.205], [-0.22, 0.05, 0.055, 0.22], [-0.16, 0.05, 0.055, 0.225], [-0.12, 0.0, 0.0, 0.215]], 7, P_BACK, P_BELLY)
	for sx in [1.0, -1.0]:
		_stick(st, Vector3(sx * 0.02, 0.255, -0.18), Vector3(sx * 0.035, 0.42, -0.125), 0.018, 0.012, P_BACK, P_TIP)
		_stick(st, Vector3(sx * 0.035, 0.12, -0.07), Vector3(sx * 0.03, 0.0, -0.09), 0.014, 0.01, P_BELLY, P_BELLY)
		# the long hind feet along the ground, under the haunch
		_stick(st, Vector3(sx * 0.06, 0.08, 0.14), Vector3(sx * 0.055, 0.01, 0.0), 0.022, 0.014, P_BACK, P_BELLY)
	_loft(st, [[0.2, 0.0, 0.0, 0.17], [0.225, 0.032, 0.03, 0.175], [0.26, 0.0, 0.0, 0.175]], 6, P_BILL, P_BILL)
	return st.commit()


## A fish a third of a metre long, deep-bodied, with a forked tail and a
## dorsal fin.
static func _fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bend := Vector2(-0.08, 0.22)
	_loft(st, [[-0.17, 0.0, 0.0, 0.0], [-0.14, 0.018, 0.028, 0.0], [-0.08, 0.028, 0.05, 0.004], [0.0, 0.026, 0.052, 0.006],
		[0.07, 0.016, 0.032, 0.004], [0.12, 0.006, 0.012, 0.0], [0.13, 0.0, 0.0, 0.0]], 8, P_BACK, P_BELLY, bend)
	var side := Vector3.RIGHT
	_flat(st, [[Vector3(0, 0.0, 0.12), P_WING, 0.85], [Vector3(0, 0.065, 0.225), P_WING, 1.0], [Vector3(0, 0.0, 0.19), P_WING, 1.0]], side)
	_flat(st, [[Vector3(0, 0.0, 0.12), P_WING, 0.85], [Vector3(0, 0.0, 0.19), P_WING, 1.0], [Vector3(0, -0.065, 0.225), P_WING, 1.0]], side)
	_flat(st, [[Vector3(0, 0.052, -0.04), P_WING, 0.1], [Vector3(0, 0.085, 0.0), P_WING, 0.2], [Vector3(0, 0.045, 0.05), P_WING, 0.4]], side)
	return st.commit()


## A bottlenose dolphin, 2.2 m: the short beak, the rounded melon, a tall
## curved dorsal fin, flippers, and flukes that beat up and down.
static func _dolphin_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bend := Vector2(-0.2, 1.15)
	# (slim from above: the beak, the melon rising behind it, the widest at the
	# flippers, then the tail stock narrowing and deepening to the flukes)
	_loft(st, [[-1.1, 0.0, 0.0, -0.03], [-1.06, 0.028, 0.024, -0.03], [-0.97, 0.042, 0.04, -0.025], [-0.92, 0.065, 0.075, 0.0],
		[-0.85, 0.11, 0.125, 0.03], [-0.7, 0.15, 0.165, 0.04], [-0.45, 0.185, 0.205, 0.03], [-0.15, 0.2, 0.215, 0.02], [0.15, 0.175, 0.2, 0.02],
		[0.45, 0.12, 0.15, 0.03], [0.7, 0.06, 0.1, 0.04], [0.88, 0.032, 0.06, 0.04], [0.98, 0.018, 0.03, 0.035], [1.02, 0.0, 0.0, 0.035]], 12, P_BACK, P_BELLY, bend)
	var side := Vector3.RIGHT
	# the dorsal fin, curving back
	_flat(st, [[Vector3(0, 0.2, -0.12), P_WING, 0.0], [Vector3(0, 0.4, 0.08), P_WING, 0.05], [Vector3(0, 0.21, 0.2), P_WING, 0.1]], side)
	_flat(st, [[Vector3(0, 0.4, 0.08), P_WING, 0.05], [Vector3(0, 0.47, 0.27), P_WING, 0.1], [Vector3(0, 0.21, 0.2), P_WING, 0.1]], side)
	for sx in [1.0, -1.0]:
		# the flukes
		_flat(st, [[Vector3(0, 0.035, 0.92), P_WING, 1.0], [Vector3(sx * 0.3, 0.035, 1.12), P_WING, 1.0], [Vector3(sx * 0.1, 0.035, 1.17), P_WING, 1.0]], Vector3.UP)
		_flat(st, [[Vector3(0, 0.035, 0.92), P_WING, 1.0], [Vector3(sx * 0.1, 0.035, 1.17), P_WING, 1.0], [Vector3(0, 0.035, 1.09), P_WING, 1.0]], Vector3.UP)
		# a flipper
		_flat(st, [[Vector3(sx * 0.15, -0.1, -0.5), P_WING, 0.0], [Vector3(sx * 0.36, -0.2, -0.3), P_WING, 0.0], [Vector3(sx * 0.15, -0.1, -0.36), P_WING, 0.0]], Vector3(0, 1, 0))
	return st.commit()


## Small birds, soaring birds, bats and ducks. INSTANCE_CUSTOM: r the wings'
## beat (0 down, 0.5 level, 1 up), g the species, b how far they're folded.
const BIRD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// each species' colours (as picked: sRGB): back, belly, wing, wing tip and tail, head, bill and feet.
// Sparrow, starling, crow, gull, buzzard, bat, mallard drake and duck, pigeon
const vec3 PAL[54] = {
	vec3(0.47, 0.34, 0.22), vec3(0.72, 0.66, 0.56), vec3(0.44, 0.31, 0.2), vec3(0.22, 0.17, 0.13), vec3(0.42, 0.38, 0.35), vec3(0.3, 0.26, 0.22),
	vec3(0.1, 0.11, 0.1), vec3(0.16, 0.15, 0.14), vec3(0.13, 0.13, 0.12), vec3(0.08, 0.08, 0.08), vec3(0.09, 0.12, 0.1), vec3(0.78, 0.64, 0.22),
	vec3(0.07, 0.07, 0.08), vec3(0.09, 0.09, 0.1), vec3(0.08, 0.08, 0.09), vec3(0.05, 0.05, 0.06), vec3(0.07, 0.07, 0.08), vec3(0.05, 0.05, 0.05),
	vec3(0.66, 0.69, 0.72), vec3(0.93, 0.94, 0.95), vec3(0.64, 0.67, 0.71), vec3(0.1, 0.1, 0.11), vec3(0.94, 0.95, 0.96), vec3(0.88, 0.72, 0.22),
	vec3(0.38, 0.26, 0.16), vec3(0.66, 0.56, 0.44), vec3(0.36, 0.25, 0.16), vec3(0.14, 0.11, 0.09), vec3(0.44, 0.33, 0.22), vec3(0.22, 0.2, 0.16),
	vec3(0.17, 0.13, 0.11), vec3(0.21, 0.17, 0.14), vec3(0.12, 0.1, 0.09), vec3(0.09, 0.07, 0.06), vec3(0.16, 0.13, 0.11), vec3(0.1, 0.08, 0.07),
	vec3(0.52, 0.48, 0.42), vec3(0.76, 0.75, 0.71), vec3(0.47, 0.44, 0.4), vec3(0.24, 0.22, 0.2), vec3(0.06, 0.32, 0.16), vec3(0.88, 0.76, 0.22),
	vec3(0.5, 0.38, 0.25), vec3(0.6, 0.48, 0.34), vec3(0.46, 0.35, 0.23), vec3(0.28, 0.22, 0.16), vec3(0.48, 0.37, 0.26), vec3(0.78, 0.5, 0.18),
	vec3(0.52, 0.54, 0.6), vec3(0.58, 0.59, 0.64), vec3(0.6, 0.62, 0.67), vec3(0.22, 0.23, 0.27), vec3(0.4, 0.46, 0.46), vec3(0.72, 0.42, 0.42)
};

varying vec3 col;

void vertex() {
	if (UV2.x > 0.5) {
		// folded, the wings lie back along the body (UV.x: how far out from the
		// shoulder); spread, they beat about its long axis
		float fold = INSTANCE_CUSTOM.b;
		float out_ = UV.x * fold;
		VERTEX.x -= sign(VERTEX.x) * out_ * 0.88;
		VERTEX.z += out_ * 0.55;
		float a = (INSTANCE_CUSTOM.r * 2.0 - 1.0) * 1.05 * (1.0 - fold);
		float th = a * sign(VERTEX.x);
		float c = cos(th);
		float s = sin(th);
		VERTEX.xy = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
		NORMAL.xy = vec2(NORMAL.x * c - NORMAL.y * s, NORMAL.x * s + NORMAL.y * c);
	}
	int sp = clamp(int(INSTANCE_CUSTOM.g * 8.0 + 0.5), 0, 8);
	int part = clamp(int(UV2.y * 8.0 + 0.5), 0, 5);
	col = PAL[sp * 6 + part];
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;  // the normal as modelled (the engine turns a back face's round)
	}
	// (clamped: with MSAA a pixel a sliver of a triangle only partly covers is
	// shaded at its middle, outside the triangle, where the colour runs past its
	// range - and a power of a negative number is NaN, a black blot spreading)
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
}
"""

## Rats, hares, fish and dolphins. INSTANCE_CUSTOM: r how far through a beat
## of the tail (or flukes), g the species, b how hard it beats (m), a 1 when
## it beats up and down (a dolphin) rather than side to side.
const CRITTER_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// rat, hare, river fish, dolphin, sea fish (sRGB): back, belly, fins and tail, dark, pink, white
const vec3 PAL[30] = {
	vec3(0.33, 0.28, 0.23), vec3(0.5, 0.45, 0.4), vec3(0.4, 0.33, 0.28), vec3(0.06, 0.05, 0.05), vec3(0.68, 0.5, 0.47), vec3(0.85, 0.83, 0.8),
	vec3(0.52, 0.41, 0.28), vec3(0.82, 0.77, 0.68), vec3(0.5, 0.4, 0.28), vec3(0.08, 0.07, 0.06), vec3(0.62, 0.46, 0.4), vec3(0.95, 0.95, 0.93),
	vec3(0.36, 0.39, 0.28), vec3(0.78, 0.76, 0.66), vec3(0.62, 0.4, 0.24), vec3(0.06, 0.06, 0.05), vec3(0.6, 0.45, 0.4), vec3(0.85, 0.85, 0.82),
	vec3(0.24, 0.27, 0.31), vec3(0.74, 0.76, 0.78), vec3(0.21, 0.23, 0.27), vec3(0.06, 0.06, 0.07), vec3(0.62, 0.62, 0.64), vec3(0.9, 0.9, 0.9),
	vec3(0.3, 0.42, 0.45), vec3(0.86, 0.88, 0.89), vec3(0.36, 0.43, 0.46), vec3(0.06, 0.06, 0.07), vec3(0.6, 0.6, 0.62), vec3(0.9, 0.9, 0.9)
};
// how many waves to the metre run down each one's body
const float WAVE[5] = {28.0, 8.0, 15.0, 2.6, 15.0};

varying vec3 col;
varying float wet;

void vertex() {
	int sp = clamp(int(INSTANCE_CUSTOM.g * 8.0 + 0.5), 0, 4);
	float bend = sin(INSTANCE_CUSTOM.r * TAU - VERTEX.z * WAVE[sp]) * INSTANCE_CUSTOM.b * UV2.x;
	if (INSTANCE_CUSTOM.a > 0.5) {
		VERTEX.y += bend;
	} else {
		VERTEX.x += bend;
	}
	int part = clamp(int(UV2.y * 8.0 + 0.5), 0, 5);
	col = PAL[sp * 6 + part];
	wet = sp >= 2 ? 1.0 : 0.0;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));  // (clamped: see the bird shader)
	// fur is matte; a fish or a dolphin is wet
	float w = clamp(wet, 0.0, 1.0);
	ROUGHNESS = mix(0.92, 0.32, w);
	SPECULAR = mix(0.15, 0.5, w);
}
"""
