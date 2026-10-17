extends Node
## Procedurally synthesised sound effects, played through a pool of 3D players.
## Every player feeds one of the mixer's buses, so music, effects, ambience and
## the interface each have their own volume (Settings sets the levels).

const RATE := 22050
## The mixer: each of these feeds Master.
const BUSES := ["Music", "Effects", "Ambience", "Interface"]

var streams := {}
var pool: Array = []
var pool_i := 0
var ui_player: AudioStreamPlayer
var ui_pool: Array = []  # interface sounds overlap (a whoosh under an impact, ticks over both)
var ui_i := 0
var enabled := true
var _last := {}  # name -> msec, throttles very frequent sounds
var far_pool: Array = []  # non-positional players for things heard from far away (aircraft, gunship fire)
var far_i := 0
# the sounds being made: the worker threads' task, and what it's making
var _synth := -1
var _recipes_made: Array = []
var _made: Array = []


func _ready() -> void:
	_setup_buses()
	set_process(false)
	if DisplayServer.get_name() == "headless":
		enabled = false
		if dump_dir() == "":
			return
	# Every sound is made at start-up. None depends on another, so they're
	# made side by side on the worker threads, each with random numbers of its
	# own (seeded by its name, so it sounds the same every launch): the global
	# ones aren't safe to share between threads. Nothing waits for them while
	# the menu is being built; the first sound asked for before they're done
	# waits for the rest (_ensure).
	_recipes_made = _recipes()
	_made.resize(_recipes_made.size())  # each worker fills in only its own slot
	_synth = WorkerThreadPool.add_group_task(_make.bind(_recipes_made, _made), _recipes_made.size(), -1, true, "Sound synthesis")
	set_process(true)
	for i in 32:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 300.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		p.bus = &"Effects"
		add_child(p)
		pool.append(p)
	for i in 5:
		var up := AudioStreamPlayer.new()
		up.bus = &"Interface"
		add_child(up)
		ui_pool.append(up)
	ui_player = ui_pool[0]
	for i in 6:
		var fp := AudioStreamPlayer.new()
		fp.bus = &"Effects"
		add_child(fp)
		far_pool.append(fp)


func _process(_dt: float) -> void:
	if _synth >= 0 and WorkerThreadPool.is_group_task_completed(_synth):
		_ensure()


## The sounds, once they're all made (waiting for them if they aren't yet).
func _ensure() -> void:
	if _synth < 0:
		return
	WorkerThreadPool.wait_for_group_task_completion(_synth)
	_synth = -1
	for i in _recipes_made.size():
		streams[_recipes_made[i][0]] = _made[i]
	_recipes_made = []
	_made = []
	set_process(false)


## One sound, for a player of your own (null if there's no such sound).
func stream(sname: String) -> AudioStream:
	_ensure()
	return streams.get(sname)


## Every sound: its name, and the synthesis that makes it (called with the
## sound's own RandomNumberGenerator).
func _recipes() -> Array:
	return [
		["rifle", _gun.bind(0.16, 0.9, 1400.0, 0.55)],
		["smg", _gun.bind(0.12, 0.7, 1800.0, 0.4)],
		["mg", _gun.bind(0.14, 0.95, 1100.0, 0.6)],
		["pistol", _gun.bind(0.11, 0.6, 2200.0, 0.35)],
		["hmg", _gun.bind(0.26, 1.0, 650.0, 1.1)],
		["gmg", _gun.bind(0.22, 0.85, 420.0, 1.3)],  # a deep thump per grenade
		["ac", _gun.bind(0.3, 1.0, 520.0, 1.35)],  # autocannon bark
		["minigun", _gun.bind(0.07, 0.75, 1600.0, 0.35)],
		["mortar", _boom.bind(0.45, 0.55, 130.0)],
		["whistle", _whistle],
		["cannon", _boom.bind(1.4, 0.8, 70.0)],
		["explosion", _boom.bind(1.6, 1.0, 55.0)],
		["small_boom", _boom.bind(0.7, 0.7, 90.0)],
		["ricochet", _ricochet],
		["drone", _drone_loop],
		["launch", _whoosh],
		["thud", _thud],
		["click", _click],
		["objective", _chime.bind([660.0, 880.0])],
		["objective_done", _chime.bind([660.0, 880.0, 1320.0])],
		["objective_failed", _chime.bind([520.0, 390.0])],
		["ping", _pip.bind([1320.0, 1760.0], 0.065)],
		["ping_alert", _pip.bind([1560.0, 1170.0, 1560.0], 0.06)],
		["build", _knock],
		["door_kick", _door_kick],
		["door", _creak],
		["jet", _jet],
		["big_boom", _boom.bind(2.6, 1.0, 38.0)],
		["rotor", _rotor_loop],
		["wind", _wind_loop],
		["rumble", _rumble_loop],
		["rain", _rain_loop],
		["thunder", _thunder],
		["brrt", _burst.bind(2.1, 65.0, 0.16, 1.0, 1.55)],
		["ac25", _burst.bind(1.3, 30.0, 0.3, 0.55, 0.95)],
		["ac40", _boom.bind(0.9, 0.95, 92.0)],
		["ac105", _boom.bind(3.0, 1.0, 34.0)],
		["prop", _prop_loop],
		["arty_whistle", _incoming],
		["fire", _fire_loop],
		# wildlife (wildlife.gd), on the ambience
		["birdsong", _birdsong],
		["birdsong2", _birdsong],
		["flutter", _flutter],
		["coo", _coo],
		["caw", _caw],
		["gull", _gull],
		["plop", _plop],
		["splash", _splash],
		["squeak", _squeak],
		# the stats screens and the end of a battle
		["ui_whoosh", _ui_whoosh],
		["ui_tick", _ui_tick],
		["ui_slam", _ui_slam.bind(false)],
		["ui_slam_low", _ui_slam.bind(true)],
		["ui_medal", _ui_medal],
	]


## (On a worker thread.) Makes sound i of the recipes into made[i].
func _make(i: int, recipes: Array, made: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(recipes[i][0]))
	made[i] = (recipes[i][1] as Callable).call(rng)


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, &"Master")
	# a limiter last on the master: a dozen shells landing at once get as loud
	# as the speakers go, not clipped into crackle
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


## --sound-dump=DIR: write every synthesised sound to DIR as a WAV and quit
## (main.gd), so a sound can be listened to or measured on its own.
func dump_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--sound-dump="):
			return String(a).substr(13)
	return ""


func dump(dir: String) -> void:
	_ensure()
	DirAccess.make_dir_recursive_absolute(dir)
	for k in streams:
		(streams[k] as AudioStreamWAV).save_to_wav(dir.path_join(String(k) + ".wav"))


func play(sname: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, bus := &"Effects") -> void:
	if not enabled:
		return
	_ensure()
	if not streams.has(sname):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sname + str(int(pos.x / 8)) + str(int(pos.z / 8)), 0)) < 25:
		return
	_last[sname + str(int(pos.x / 8)) + str(int(pos.z / 8))] = now
	var p: AudioStreamPlayer3D = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = streams[sname]
	p.bus = bus
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	p.play()


## Heard rather than placed: aircraft overhead, a gunship's guns two hundred
## metres up. `pan` is ignored (mono), volume falls off with `dist`.
func play_far(sname: String, vol_db := 0.0, pitch := 1.0, dist := 0.0) -> void:
	if not enabled:
		return
	_ensure()
	if not streams.has(sname):
		return
	var p: AudioStreamPlayer = far_pool[far_i]
	far_i = (far_i + 1) % far_pool.size()
	p.stream = streams[sname]
	p.volume_db = vol_db - clampf(dist / 25.0, 0.0, 14.0)
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func ui(sname: String, vol_db := -8.0, pitch := 1.0) -> void:
	if not enabled:
		return
	_ensure()
	if not streams.has(sname):
		return
	var p: AudioStreamPlayer = ui_pool[ui_i % ui_pool.size()]
	ui_i += 1
	p.stream = streams[sname]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func make_drone_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"Effects"
	if enabled:
		_ensure()
		p.stream = streams["drone"]
		p.unit_size = 10.0
		p.max_distance = 120.0
		p.volume_db = -4.0
		p.autoplay = true
	return p


# --- synthesis helpers ------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _gun(rng: RandomNumberGenerator, dur: float, vol: float, crack_hz: float, body: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var a := clampf(crack_hz / RATE * 6.0, 0.05, 0.9)
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * a
		var crack := lp * exp(-t * 38.0)
		var thump := sin(TAU * 95.0 * t) * exp(-t * 28.0) * body
		s[i] = (crack * 1.4 + thump) * vol
	return _wav(s)


func _boom(rng: RandomNumberGenerator, dur: float, vol: float, base_hz: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.08
		lp2 += (lp - lp2) * 0.1
		var env := exp(-t * 3.2) * (1.0 - exp(-t * 400.0))
		var sub := sin(TAU * base_hz * t * (1.0 - t * 0.3)) * exp(-t * 4.0)
		var crack := noise * exp(-t * 30.0) * 0.5
		s[i] = (lp2 * 5.0 * env + sub * 0.8 + crack) * vol
	return _wav(s)


func _ricochet(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 3400.0 - t * 5000.0
		ph += TAU * f / RATE
		s[i] = (sin(ph) * 0.5 + (rng.randf() - 0.5) * 0.15) * exp(-t * 9.0)
	return _wav(s)


func _drone_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (196.0 + sin(TAU * 4.0 * t) * 6.0) / RATE
		ph2 += TAU * 392.0 / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var saw2 := fmod(ph2 / TAU, 1.0) * 2.0 - 1.0
		s[i] = (saw * 0.35 + saw2 * 0.15 + (rng.randf() - 0.5) * 0.08) * 0.8
	return _wav(s, true)


func _whoosh(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.7 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var a := 0.05 + t * 0.4
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * a
		s[i] = lp * exp(-t * 3.0) * (1.0 - exp(-t * 60.0)) * 1.6
	return _wav(s)


## Jet pass: rising roar, a doppler drop as it goes over, rumble trailing off.
func _jet(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(5.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var t_pass := 2.2
		var near := 1.0 / (1.0 + pow((t - t_pass) * 1.6, 2.0))
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * (0.08 + near * 0.25)
		lp2 += (lp - lp2) * 0.2
		var f := 900.0 if t < t_pass else 900.0 - minf(1.0, (t - t_pass) * 2.0) * 380.0
		ph += TAU * f / RATE
		var whine := sin(ph) * 0.12 * near
		var env := clampf(t / 1.2, 0.0, 1.0) * clampf((5.0 - t) / 1.5, 0.0, 1.0)
		s[i] = (lp2 * 2.6 * (0.35 + near) + whine) * env
	return _wav(s)


## Helicopter rotor: low thudding blade slap over turbine whine.
func _rotor_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.12
		var slap := pow(maxf(0.0, sin(TAU * 5.0 * t)), 8.0)
		ph += TAU * 1450.0 / RATE
		s[i] = (lp * (0.4 + 2.2 * slap) + sin(ph) * 0.05) * 0.8
	return _wav(s, true)


## Wind: air rushing past (noise from a few hundred hertz up) and a hollow
## howl whose pitch rises as it blows harder, in gusts that come and go
## irregularly. The gusts are slow swells whose periods divide the loop, so it
## repeats seamlessly and only every ten seconds. Nothing much below 200 Hz:
## low noise that swells and fades sounds like surf on a beach, not wind.
func _wind_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var secs := 10.0
	var n := int(secs * RATE)
	var fade := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n + fade)
	var parts := []
	for k in [1, 2, 3, 5, 8]:
		parts.append([float(k), rng.randf() * TAU, rng.randf_range(0.5, 1.0) / pow(float(k), 0.6)])
	var top := 0.0
	for p in parts:
		top += float(p[2])
	var g := 0.0
	var f := 0.0
	var low := 0.0
	var band := 0.0
	var lp := 0.0
	var hp := 0.0
	for i in n + fade:
		if i % 32 == 0:
			var t := float(i) / RATE
			var v := 0.0
			for p in parts:
				v += float(p[2]) * sin(TAU * float(p[0]) * t / secs + float(p[1]))
			g = 0.5 + 0.5 * v / top
			f = 2.0 * sin(PI * (230.0 + 420.0 * g) / RATE)
		var w := rng.randf() * 2.0 - 1.0
		# the howl: noise through a resonant band-pass (a state-variable filter)
		low += f * band
		band += f * (w - low - 0.45 * band)
		# the rush: noise between ~250 Hz and ~1.5 kHz
		lp += (w - lp) * 0.28
		hp += (lp - hp) * 0.07
		s[i] = band * 0.22 * (0.55 + 0.45 * g) + (lp - hp) * 0.35 * (0.35 + 0.65 * g * g)
	return _wav(_normalize(_seamless(s, fade), -20.0), true)


## The battle somewhere else: muffled artillery thumps with long tails, far-off
## machine-gun bursts, and a faint low murmur between them (8 s loop).
func _rumble_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var secs := 8.0
	var n := int(secs * RATE)
	var fade := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in n + fade:
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.03
		lp2 += (lp - lp2) * 0.03
		hp += (lp2 - hp) * 0.012
		s[i] = lp2 - hp
	s = _seamless(s, fade)
	# distant guns, one in each fifth of the loop so they never bunch up (a tail
	# running past the end carries on at the start: it's a loop)
	for j in 5:
		var k0 := int((j * secs / 5.0 + rng.randf_range(0.0, secs / 5.0 - 0.6)) * RATE)
		var amp := rng.randf_range(0.35, 1.0)
		var f0 := rng.randf_range(42.0, 62.0)
		var a := 0.0
		var b := 0.0
		for i in int(2.2 * RATE):
			var t := float(i) / RATE
			a += ((rng.randf() * 2.0 - 1.0) - a) * 0.08
			b += (a - b) * 0.08
			var env := (1.0 - exp(-t * 60.0)) * exp(-t * 2.6)
			s[(k0 + i) % n] += (b * 6.0 + sin(TAU * f0 * t) * 0.3 * exp(-t * 5.0)) * env * amp
	# a machine gun firing a long way off
	for j in 3:
		var t0 := rng.randf_range(0.0, secs)
		var rate := rng.randf_range(8.0, 12.0)
		var amp := rng.randf_range(0.04, 0.09)
		for q in rng.randi_range(4, 9):
			var k0 := int((t0 + q / rate + rng.randf_range(0.0, 0.01)) * RATE)
			var a := 0.0
			for i in int(0.08 * RATE):
				a += ((rng.randf() * 2.0 - 1.0) - a) * 0.25
				s[(k0 + i) % n] += a * exp(-float(i) / RATE * 55.0) * amp
	# take out what's below hearing: it only reads as pressure, like surf
	# (run round the loop twice so the filter starts where it ends)
	var h := 0.0
	for pass_i in 2:
		for i in n:
			h += (s[i] - h) * 0.01
			if pass_i == 1:
				s[i] -= h
	return _wav(_normalize(s, -22.0), true)


## Rain: dense hiss with patter (seamless 3 s loop).
func _rain_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(3.0 * RATE)
	var fade := int(0.3 * RATE)
	var s := PackedFloat32Array()
	s.resize(n + fade)
	var lp := 0.0
	var hp := 0.0
	for i in n + fade:
		var w := rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		hp += (lp - hp) * 0.05
		var v := (lp - hp) * 0.5
		if rng.randf() < 0.004:
			v += (rng.randf() - 0.5) * 0.6
		s[i] = v
	return _wav(_seamless(s, fade), true)


## Makes a loop without a seam: `s` runs `fade` samples past the loop's end,
## and that overrun is faded into the start (equal power, for noise), so the
## end flows straight on into the beginning.
func _seamless(s: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := s.size() - fade
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * sqrt(k) + s[n + i] * sqrt(1.0 - k)
	s.resize(n)
	return s


## Scales `s` to an RMS level (dBFS), so how loud a loop plays is set by its
## player's volume, not by how the synthesis happened to come out.
func _normalize(s: PackedFloat32Array, rms_db: float) -> PackedFloat32Array:
	var sum := 0.0
	for x in s:
		sum += x * x
	var k := db_to_linear(rms_db) / maxf(1e-6, sqrt(sum / maxf(1.0, s.size())))
	for i in s.size():
		s[i] *= k
	return s


## A fire close to: the breathing roar of the flames under a run of crackles
## and the odd sharp pop of sap or a round cooking off. The roar sits between
## ~150 and ~500 Hz: below that, noise that swells reads as surf, like the old
## wind did. Its breathing repeats twice and five times a loop, so it's seamless.
func _fire_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(4.0 * RATE)
	var fade := int(0.3 * RATE)
	var s := PackedFloat32Array()
	s.resize(n + fade)
	var a := 0.0
	var b := 0.0
	var hp := 0.0
	var ck := 0.0
	var ck_lp := 0.0
	for i in n + fade:
		var t := float(i) / RATE
		var w := rng.randf() * 2.0 - 1.0
		a += (w - a) * 0.12
		b += (a - b) * 0.12
		hp += (b - hp) * 0.04
		var roar := (b - hp) * (0.7 + 0.18 * sin(t * TAU * 0.5) + 0.12 * sin(t * TAU * 1.25 + 1.0))
		if rng.randf() < 0.0016:
			ck = rng.randf_range(0.25, 0.8)
		elif rng.randf() < 0.00006:
			ck = 1.0
		ck *= 0.988
		ck_lp += (rng.randf() * 2.0 - 1.0 - ck_lp) * 0.55
		s[i] = roar * 0.65 + ck_lp * ck * 0.5
	return _wav(_seamless(s, fade), true)


## Thunder: a crack followed by a long rolling rumble.
func _thunder(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(5.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.04
		lp2 += (lp - lp2) * 0.05
		var roll := (0.6 + 0.4 * sin(TAU * 1.3 * t) * sin(TAU * 0.7 * t + 2.0)) * exp(-t * 0.7)
		var crack := w * exp(-t * 14.0) * 0.6
		s[i] = (lp2 * 9.0 * roll + crack) * minf(1.0, t * 30.0)
	return _wav(s)


func make_loop_player(sname: String, unit := 14.0, vol := -2.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"Effects"
	_ensure()
	if enabled and streams.has(sname):
		p.stream = streams[sname]
		p.unit_size = unit
		p.max_distance = 220.0
		p.volume_db = vol
		p.autoplay = true
	return p


## A bed of sound for the whole scene (wind, the distant battle, rain): not
## placed anywhere, on the Ambience bus.
func make_ambience(sname: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	_ensure()
	if enabled and streams.has(sname):
		p.stream = streams[sname]
		p.volume_db = vol_db
		p.autoplay = true
	return p


func _whistle(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.4 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1500.0 - t * 600.0 + sin(TAU * 5.0 * t) * 20.0
		ph += TAU * f / RATE
		s[i] = sin(ph) * 0.35 * minf(1.0, t * 1.5) * (1.0 - exp(-(1.4 - t) * 30.0))
	return _wav(s)


func _thud(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.18 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 110.0 * t) * 0.8 + (rng.randf() - 0.5) * 0.3) * exp(-t * 30.0)
	return _wav(s)


func _click(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.04 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 1600.0 * t) * exp(-t * 120.0) * 0.5
	return _wav(s)


## A panel sliding in: a short breath of air, rising then gone.
func _ui_whoosh(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var dur := 0.34
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var cut := 0.04 + 0.32 * sin(k * PI)
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * cut
		lp2 += (lp - lp2) * 0.5
		s[i] = (lp - lp2 * 0.6) * pow(sin(k * PI), 1.6) * 1.5
	return _wav(s)


## One tick of a number counting up.
func _ui_tick(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.022 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 2700.0 * t) * 0.6 + sin(TAU * 5400.0 * t) * 0.15 + (rng.randf() - 0.5) * 0.12) * exp(-t * 260.0) * 0.55
	return _wav(s)


## The end-of-battle banner landing: a sub drop under a hard transient, a
## metal ring, and a long dark tail. low: the defeat's, heavier and duller.
func _ui_slam(rng: RandomNumberGenerator, low: bool) -> AudioStreamWAV:
	var dur := 1.8
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	var tail := 0.0
	var f0 := 70.0 if low else 95.0
	var f1 := 30.0 if low else 40.0
	for i in n:
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t * 6.0)
		ph += TAU * f / RATE
		var sub := sin(ph) * exp(-t * (2.6 if low else 3.4)) * 0.95
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * (0.35 if low else 0.55)
		var hit := lp * exp(-t * 22.0) * 0.9
		var ring := 0.0
		if not low:
			ring = (sin(TAU * 1830.0 * t) * 0.5 + sin(TAU * 2750.0 * t) * 0.35 + sin(TAU * 4120.0 * t) * 0.15) * exp(-t * 9.0) * 0.16
		tail += ((rng.randf() * 2.0 - 1.0) - tail) * 0.06
		var verb := tail * exp(-t * 2.2) * (1.0 - exp(-t * 30.0)) * 0.55
		s[i] = (sub + hit + ring + verb) * 0.64
	return _wav(s)


## An honour landing: a bright little chord and a sparkle over it.
func _ui_medal(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var dur := 1.1
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [1046.5, 1568.0, 2093.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in notes.size():
			var lt := t - j * 0.045
			if lt < 0.0:
				continue
			var f: float = notes[j] * (1.0 + 0.003 * sin(TAU * 5.5 * lt))
			v += (sin(TAU * f * lt) * 0.7 + sin(TAU * f * 2.0 * lt) * 0.12) * minf(1.0, lt * 300.0) * exp(-lt * 4.2) * 0.22
		var sp := (rng.randf() - 0.5) * exp(-t * 14.0) * 0.12 * sin(TAU * 7300.0 * t)
		s[i] = v + sp
	return _wav(s)


## A co-commander's ping: a few short, bright pips, clear of the radio chimes
## so it never reads as an objective.
func _pip(rng: RandomNumberGenerator, notes: Array, step: float) -> AudioStreamWAV:
	var n := int((step * notes.size() + 0.16) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var k := mini(int(t / step), notes.size() - 1)
		var lt := t - k * step
		var f: float = notes[k]
		var env := minf(1.0, lt * 500.0) * exp(-lt * (16.0 if k == notes.size() - 1 else 34.0))
		s[i] = (sin(TAU * f * t) * 0.85 + sin(TAU * f * 3.0 * t) * 0.07) * env * 0.3
	return _wav(s)


## A mission's radio chime: a burst of squelch, then a short run of tones
## (rising for good news, falling for bad).
func _chime(rng: RandomNumberGenerator, notes: Array) -> AudioStreamWAV:
	var step := 0.13
	var n := int((0.06 + step * notes.size() + 0.25) * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var seed_v := 12345
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		if t < 0.06:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			v += (float(seed_v) / 0x7fffffff - 0.5) * 0.18 * (1.0 - t / 0.06)
		var k := int((t - 0.06) / step)
		if t >= 0.06 and k < notes.size():
			var lt := t - 0.06 - k * step
			var env := minf(1.0, lt * 200.0) * exp(-lt * (9.0 if k == notes.size() - 1 else 16.0))
			var f: float = notes[k]
			v += (sin(TAU * f * t) * 0.8 + sin(TAU * f * 2.0 * t) * 0.15) * env * 0.32
		elif t >= 0.06:
			var lt2 := t - 0.06 - (notes.size() - 1) * step
			var f2: float = notes[notes.size() - 1]
			v += sin(TAU * f2 * t) * exp(-lt2 * 9.0) * 0.32 * 0.8
		s[i] = v
	return _wav(s)


## A boot through a door: the crack of the lock giving, a deep boom from
## the panel, and the slam of it hitting the wall inside.
func _door_kick(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := (rng.randf() - 0.5) * exp(-t * 90.0) * 1.1
		var boom := sin(TAU * 85.0 * t + sin(TAU * 31.0 * t)) * exp(-t * 16.0) * 0.9
		var t2 := t - 0.21
		var slam := 0.0
		if t2 > 0.0:
			lp += ((rng.randf() - 0.5) - lp) * 0.35
			slam = (sin(TAU * 140.0 * t2) * 0.6 + lp * 1.4) * exp(-t2 * 26.0) * 0.8
		s[i] = clampf(crack + boom + slam, -1.0, 1.0)
	return _wav(s)


## Old hinges: a door pushed open.
func _creak(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.7 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 420.0 + 160.0 * sin(TAU * 2.3 * t) + 60.0 * sin(TAU * 7.0 * t)
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var env := sin(PI * clampf(t / 0.7, 0.0, 1.0)) * (0.7 + 0.3 * sin(TAU * 31.0 * t))
		s[i] = saw * env * 0.22
	return _wav(s)


func _knock(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.1 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 520.0 * t) * 0.5 + (rng.randf() - 0.5) * 0.4) * exp(-t * 55.0)
	return _wav(s)



## Automatic cannon: a train of sharp reports `rate` per second (65 = the A-10's
## GAU-8, a tearing BRRRT; 30 = the gunship's 25 mm buzz).
func _burst(rng: RandomNumberGenerator, dur: float, rate: float, bright: float, bass: float, hold: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var echo := PackedFloat32Array()
	echo.resize(int(0.09 * RATE))
	var ei := 0
	for i in n:
		var t := float(i) / RATE
		var on := 1.0 if t < hold else exp(-(t - hold) * 9.0)
		var ph := fmod(t * rate, 1.0)
		var pulse := exp(-ph * 7.0)
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * bright
		lp2 += (lp - lp2) * 0.3
		var saw := (1.0 - ph * 2.0) * 0.4 * bass
		var v := (lp2 * 3.2 * (0.35 + pulse) + saw * pulse) * on * minf(1.0, t * 30.0)
		# a short slap-back off the ground
		v += echo[ei] * 0.35
		echo[ei] = v
		ei = (ei + 1) % echo.size()
		s[i] = clampf(v * 0.8, -1.0, 1.0)
	return _wav(s)


## Four turboprops droning in a slow orbit (loops).
func _prop_loop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.04
		var hum := sin(TAU * 72.0 * t) * 0.3 + sin(TAU * 74.5 * t) * 0.3 + sin(TAU * 144.0 * t) * 0.12 + sin(TAU * 216.0 * t) * 0.05
		var beat := 0.75 + 0.25 * sin(TAU * 2.5 * t)
		s[i] = (hum * beat + lp * 1.6) * 0.5
	return _wav(s, true)


## A heavy shell coming in: a falling tearing whistle.
func _incoming(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 900.0 - t * 380.0
		ph += TAU * f / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.2
		var env := minf(1.0, t * 1.2) * (1.0 - exp(-(2.0 - t) * 25.0))
		s[i] = (sin(ph) * 0.22 + lp * 0.5) * env
	return _wav(s)


# --- wildlife ----------------------------------------------------------------------------------

## A small bird's song: a phrase of quick whistled notes, each a fast sweep
## (some trilled), with short gaps between. Each name seeds a different phrase.
func _birdsong(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var at := rng.randf_range(0.02, 0.08)
	var ph := 0.0
	for k in rng.randi_range(5, 9):
		var dur := rng.randf_range(0.04, 0.13)
		var f0 := rng.randf_range(2600.0, 4600.0)
		var f1 := f0 + rng.randf_range(-1600.0, 1600.0)
		var trill := rng.randf() < 0.3
		var i0 := int(at * RATE)
		var i1 := mini(n, int((at + dur) * RATE))
		for i in range(i0, i1):
			var u := float(i - i0) / float(i1 - i0)
			var f := lerpf(f0, f1, u) + (sin(TAU * 38.0 * u * dur) * 500.0 if trill else 0.0)
			ph += TAU * f / RATE
			var env := sin(PI * u)
			s[i] += sin(ph) * env * env * 0.45
		at += dur + rng.randf_range(0.015, 0.09)
		if at > 1.4:
			break
	return _wav(s)


## A flock going up: a dozen birds each beating its wings fast, a soft thump
## of air at every beat, all at once and then thinning out as they go.
func _flutter(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for b in 12:
		var rate := rng.randf_range(14.0, 22.0)
		var start := rng.randf_range(0.0, 0.25)
		var last := start + rng.randf_range(0.35, 0.8)
		var tt := start
		while tt < last:
			var i0 := int(tt * RATE)
			var amp := 0.25 * (1.0 - (tt - start) / (last - start))
			var lp := 0.0
			for i in range(i0, mini(n, i0 + int(0.03 * RATE))):
				var u := float(i - i0) / RATE
				lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.35
				s[i] += lp * exp(-u * 120.0) * amp
			tt += rng.randf_range(0.9, 1.1) / rate
	return _wav(s)


## A pigeon's coo: a soft, throaty "hoo-roo-coo", the middle note rolled.
func _coo(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.3 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for c in [[0.03, 0.22, 400.0, 470.0], [0.32, 0.42, 470.0, 380.0], [0.82, 0.36, 430.0, 360.0]]:
		var at: float = c[0]
		var dur: float = c[1]
		var ph := 0.0
		for i in range(int(at * RATE), mini(n, int((at + dur) * RATE))):
			var u := (float(i) / RATE - at) / dur
			ph += TAU * lerpf(c[2], c[3], u) * (1.0 + 0.04 * sin(TAU * 24.0 * u * dur)) / RATE
			lp += ((rng.randf() * 2.0 - 1.0) - lp) * 0.05
			var tone := sin(ph) * 0.7 + sin(ph * 2.0) * 0.18 + lp * 0.2
			s[i] = tone * sin(PI * u) * (0.75 + 0.25 * sin(TAU * 24.0 * u * dur)) * 0.5
	return _wav(s)


## A crow's caw, twice: a harsh, nasal "kaah", falling a little.
func _caw(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.95 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for c in 2:
		var at := 0.05 + c * 0.42
		var dur := rng.randf_range(0.26, 0.32)
		var ph := 0.0
		for i in range(int(at * RATE), mini(n, int((at + dur) * RATE))):
			var u := (float(i) / RATE - at) / dur
			ph += lerpf(620.0, 520.0, u) * (1.0 + 0.03 * sin(TAU * 31.0 * u * dur)) / RATE
			var raw := (fmod(ph, 1.0) * 2.0 - 1.0) * (0.75 + 0.5 * (rng.randf() - 0.5))
			# the throat: a band round a kilohertz or so
			lp += (raw - lp) * 0.45
			lp2 += (lp - lp2) * 0.12
			s[i] = (lp - lp2) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.6, 1.0, u)) * 1.2
	return _wav(s)


## A gull's cry: a long "kee-ow", rising then falling, and two short laughing calls.
func _gull(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for c in [[0.02, 0.42, 1500.0, 2300.0, 1300.0], [0.55, 0.16, 1700.0, 2000.0, 1500.0], [0.78, 0.16, 1650.0, 1950.0, 1450.0]]:
		var at: float = c[0]
		var dur: float = c[1]
		var ph := 0.0
		for i in range(int(at * RATE), mini(n, int((at + dur) * RATE))):
			var u := (float(i) / RATE - at) / dur
			var f: float = lerpf(c[2], c[3], u / 0.35) if u < 0.35 else lerpf(c[3], c[4], (u - 0.35) / 0.65)
			ph += TAU * f / RATE
			var tone := sin(ph) * 0.6 + sin(ph * 2.0) * 0.28 + sin(ph * 3.0) * 0.12
			s[i] = tone * (1.0 + (rng.randf() - 0.5) * 0.5) * smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.7, 1.0, u)) * 0.5
	return _wav(s)


## A fish falling back in: a small plop (the bubble's note rising) and a few droplets.
func _plop(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (500.0 + 1400.0 * minf(1.0, t / 0.04)) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.6
		s[i] = sin(ph) * exp(-t * 35.0) * 0.5 + (noise - lp) * exp(-t * 14.0) * 0.25
	return _wav(s)


## A dolphin landing back in the sea: a heavy slap and the rush of the water it threw up.
func _splash(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(1.2 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.35
		lp2 += (lp - lp2) * 0.04
		var slap := (lp - lp2) * exp(-t * 20.0) * 0.9
		var rush := (noise - lp) * exp(-t * 3.5) * (1.0 - exp(-t * 30.0)) * 0.2
		s[i] = slap + rush + sin(TAU * 90.0 * t) * exp(-t * 25.0) * 0.5
	return _wav(s)


## A rat's squeak: two thin, high chirps.
func _squeak(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.24 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for c in 2:
		var at := 0.01 + c * rng.randf_range(0.09, 0.12)
		var dur := rng.randf_range(0.05, 0.07)
		var ph := 0.0
		for i in range(int(at * RATE), mini(n, int((at + dur) * RATE))):
			var u := (float(i) / RATE - at) / dur
			ph += TAU * (5200.0 + 1200.0 * sin(PI * u)) / RATE
			s[i] = sin(ph) * sin(PI * u) * 0.35
	return _wav(s)
