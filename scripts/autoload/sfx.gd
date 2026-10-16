extends Node
## Procedurally synthesised sound effects, played through a pool of 3D players.

const RATE := 22050

var streams := {}
var pool: Array = []
var pool_i := 0
var ui_player: AudioStreamPlayer
var enabled := true
var _last := {}  # name -> msec, throttles very frequent sounds
var far_pool: Array = []  # non-positional players for things heard from far away (aircraft, gunship fire)
var far_i := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	streams["rifle"] = _gun(0.16, 0.9, 1400.0, 0.55)
	streams["smg"] = _gun(0.12, 0.7, 1800.0, 0.4)
	streams["mg"] = _gun(0.14, 0.95, 1100.0, 0.6)
	streams["pistol"] = _gun(0.11, 0.6, 2200.0, 0.35)
	streams["hmg"] = _gun(0.26, 1.0, 650.0, 1.1)
	streams["gmg"] = _gun(0.22, 0.85, 420.0, 1.3)  # a deep thump per grenade
	streams["ac"] = _gun(0.3, 1.0, 520.0, 1.35)  # autocannon bark
	streams["minigun"] = _gun(0.07, 0.75, 1600.0, 0.35)
	streams["mortar"] = _boom(0.45, 0.55, 130.0)
	streams["whistle"] = _whistle()
	streams["cannon"] = _boom(1.4, 0.8, 70.0)
	streams["explosion"] = _boom(1.6, 1.0, 55.0)
	streams["small_boom"] = _boom(0.7, 0.7, 90.0)
	streams["ricochet"] = _ricochet()
	streams["drone"] = _drone_loop()
	streams["launch"] = _whoosh()
	streams["thud"] = _thud()
	streams["click"] = _click()
	streams["objective"] = _chime([660.0, 880.0])
	streams["objective_done"] = _chime([660.0, 880.0, 1320.0])
	streams["objective_failed"] = _chime([520.0, 390.0])
	streams["build"] = _knock()
	streams["door_kick"] = _door_kick()
	streams["door"] = _creak()
	streams["jet"] = _jet()
	streams["big_boom"] = _boom(2.6, 1.0, 38.0)
	streams["rotor"] = _rotor_loop()
	streams["wind"] = _wind_loop()
	streams["rumble"] = _rumble_loop()
	streams["rain"] = _rain_loop()
	streams["thunder"] = _thunder()
	streams["brrt"] = _burst(2.1, 65.0, 0.16, 1.0, 1.55)
	streams["ac25"] = _burst(1.3, 30.0, 0.3, 0.55, 0.95)
	streams["ac40"] = _boom(0.9, 0.95, 92.0)
	streams["ac105"] = _boom(3.0, 1.0, 34.0)
	streams["prop"] = _prop_loop()
	streams["arty_whistle"] = _incoming()
	for i in 32:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 300.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		add_child(p)
		pool.append(p)
	ui_player = AudioStreamPlayer.new()
	add_child(ui_player)
	for i in 6:
		var fp := AudioStreamPlayer.new()
		add_child(fp)
		far_pool.append(fp)


func play(sname: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled or not streams.has(sname):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sname + str(int(pos.x / 8)) + str(int(pos.z / 8)), 0)) < 25:
		return
	_last[sname + str(int(pos.x / 8)) + str(int(pos.z / 8))] = now
	var p: AudioStreamPlayer3D = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = streams[sname]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	p.play()


## Heard rather than placed: aircraft overhead, a gunship's guns two hundred
## metres up. `pan` is ignored (mono), volume falls off with `dist`.
func play_far(sname: String, vol_db := 0.0, pitch := 1.0, dist := 0.0) -> void:
	if not enabled or not streams.has(sname):
		return
	var p: AudioStreamPlayer = far_pool[far_i]
	far_i = (far_i + 1) % far_pool.size()
	p.stream = streams[sname]
	p.volume_db = vol_db - clampf(dist / 25.0, 0.0, 14.0)
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func ui(sname: String) -> void:
	if not enabled or not streams.has(sname):
		return
	ui_player.stream = streams[sname]
	ui_player.volume_db = -8.0
	ui_player.play()


func make_drone_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if enabled:
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


func _gun(dur: float, vol: float, crack_hz: float, body: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var a := clampf(crack_hz / RATE * 6.0, 0.05, 0.9)
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * a
		var crack := lp * exp(-t * 38.0)
		var thump := sin(TAU * 95.0 * t) * exp(-t * 28.0) * body
		s[i] = (crack * 1.4 + thump) * vol
	return _wav(s)


func _boom(dur: float, vol: float, base_hz: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.08
		lp2 += (lp - lp2) * 0.1
		var env := exp(-t * 3.2) * (1.0 - exp(-t * 400.0))
		var sub := sin(TAU * base_hz * t * (1.0 - t * 0.3)) * exp(-t * 4.0)
		var crack := noise * exp(-t * 30.0) * 0.5
		s[i] = (lp2 * 5.0 * env + sub * 0.8 + crack) * vol
	return _wav(s)


func _ricochet() -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 3400.0 - t * 5000.0
		ph += TAU * f / RATE
		s[i] = (sin(ph) * 0.5 + (randf() - 0.5) * 0.15) * exp(-t * 9.0)
	return _wav(s)


func _drone_loop() -> AudioStreamWAV:
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
		s[i] = (saw * 0.35 + saw2 * 0.15 + (randf() - 0.5) * 0.08) * 0.8
	return _wav(s, true)


func _whoosh() -> AudioStreamWAV:
	var n := int(0.7 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var a := 0.05 + t * 0.4
		lp += ((randf() * 2.0 - 1.0) - lp) * a
		s[i] = lp * exp(-t * 3.0) * (1.0 - exp(-t * 60.0)) * 1.6
	return _wav(s)


## Jet pass: rising roar, a doppler drop as it goes over, rumble trailing off.
func _jet() -> AudioStreamWAV:
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
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * (0.08 + near * 0.25)
		lp2 += (lp - lp2) * 0.2
		var f := 900.0 if t < t_pass else 900.0 - minf(1.0, (t - t_pass) * 2.0) * 380.0
		ph += TAU * f / RATE
		var whine := sin(ph) * 0.12 * near
		var env := clampf(t / 1.2, 0.0, 1.0) * clampf((5.0 - t) / 1.5, 0.0, 1.0)
		s[i] = (lp2 * 2.6 * (0.35 + near) + whine) * env
	return _wav(s)


## Helicopter rotor: low thudding blade slap over turbine whine.
func _rotor_loop() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.12
		var slap := pow(maxf(0.0, sin(TAU * 5.0 * t)), 8.0)
		ph += TAU * 1450.0 / RATE
		s[i] = (lp * (0.4 + 2.2 * slap) + sin(ph) * 0.05) * 0.8
	return _wav(s, true)


## Wind: brown noise with slow gusts (seamless 4 s loop).
func _wind_loop() -> AudioStreamWAV:
	var n := int(4.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var b := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		b = b * 0.996 + (randf() * 2.0 - 1.0) * 0.06
		hp += (b - hp) * 0.02
		var gust := 0.55 + 0.45 * sin(TAU * 0.25 * t) * sin(TAU * 0.5 * t + 1.0)
		s[i] = (b - hp) * 2.2 * gust
	# crossfade the ends so the loop is seamless
	var fade := int(0.3 * RATE)
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * k + s[n - fade + i] * (1.0 - k)
	return _wav(s, true)


## Distant battle: low rumble with far-off thumps and crackle (6 s loop).
func _rumble_loop() -> AudioStreamWAV:
	var n := int(6.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var booms := []
	for j in 5:
		booms.append([randf() * 5.6, randf_range(35.0, 60.0), randf_range(0.4, 1.0)])
	for i in n:
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.01
		var v := lp * 1.8
		for bm in booms:
			var dt := t - float(bm[0])
			if dt > 0.0 and dt < 2.0:
				v += sin(TAU * float(bm[1]) * dt) * exp(-dt * 3.0) * float(bm[2]) * 0.5
		if randf() < 0.0006:
			v += (randf() - 0.5) * 0.3
		s[i] = v
	var fade := int(0.4 * RATE)
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * k + s[n - fade + i] * (1.0 - k)
	return _wav(s, true)


## Rain: dense hiss with patter (seamless 3 s loop).
func _rain_loop() -> AudioStreamWAV:
	var n := int(3.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		hp += (lp - hp) * 0.05
		var v := (lp - hp) * 0.5
		if randf() < 0.004:
			v += (randf() - 0.5) * 0.6
		s[i] = v
	var fade := int(0.3 * RATE)
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * k + s[n - fade + i] * (1.0 - k)
	return _wav(s, true)


## Thunder: a crack followed by a long rolling rumble.
func _thunder() -> AudioStreamWAV:
	var n := int(5.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.04
		lp2 += (lp - lp2) * 0.05
		var roll := (0.6 + 0.4 * sin(TAU * 1.3 * t) * sin(TAU * 0.7 * t + 2.0)) * exp(-t * 0.7)
		var crack := w * exp(-t * 14.0) * 0.6
		s[i] = (lp2 * 9.0 * roll + crack) * minf(1.0, t * 30.0)
	return _wav(s)


func make_loop_player(sname: String, unit := 14.0, vol := -2.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if enabled and streams.has(sname):
		p.stream = streams[sname]
		p.unit_size = unit
		p.max_distance = 220.0
		p.volume_db = vol
		p.autoplay = true
	return p


func _whistle() -> AudioStreamWAV:
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


func _thud() -> AudioStreamWAV:
	var n := int(0.18 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 110.0 * t) * 0.8 + (randf() - 0.5) * 0.3) * exp(-t * 30.0)
	return _wav(s)


func _click() -> AudioStreamWAV:
	var n := int(0.04 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 1600.0 * t) * exp(-t * 120.0) * 0.5
	return _wav(s)


## A mission's radio chime: a burst of squelch, then a short run of tones
## (rising for good news, falling for bad).
func _chime(notes: Array) -> AudioStreamWAV:
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
func _door_kick() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := (randf() - 0.5) * exp(-t * 90.0) * 1.1
		var boom := sin(TAU * 85.0 * t + sin(TAU * 31.0 * t)) * exp(-t * 16.0) * 0.9
		var t2 := t - 0.21
		var slam := 0.0
		if t2 > 0.0:
			lp += ((randf() - 0.5) - lp) * 0.35
			slam = (sin(TAU * 140.0 * t2) * 0.6 + lp * 1.4) * exp(-t2 * 26.0) * 0.8
		s[i] = clampf(crack + boom + slam, -1.0, 1.0)
	return _wav(s)


## Old hinges: a door pushed open.
func _creak() -> AudioStreamWAV:
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


func _knock() -> AudioStreamWAV:
	var n := int(0.1 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 520.0 * t) * 0.5 + (randf() - 0.5) * 0.4) * exp(-t * 55.0)
	return _wav(s)



## Automatic cannon: a train of sharp reports `rate` per second (65 = the A-10's
## GAU-8, a tearing BRRRT; 30 = the gunship's 25 mm buzz).
func _burst(dur: float, rate: float, bright: float, bass: float, hold: float) -> AudioStreamWAV:
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
		var noise := randf() * 2.0 - 1.0
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
func _prop_loop() -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.04
		var hum := sin(TAU * 72.0 * t) * 0.3 + sin(TAU * 74.5 * t) * 0.3 + sin(TAU * 144.0 * t) * 0.12 + sin(TAU * 216.0 * t) * 0.05
		var beat := 0.75 + 0.25 * sin(TAU * 2.5 * t)
		s[i] = (hum * beat + lp * 1.6) * 0.5
	return _wav(s, true)


## A heavy shell coming in: a falling tearing whistle.
func _incoming() -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 900.0 - t * 380.0
		ph += TAU * f / RATE
		var noise := randf() * 2.0 - 1.0
		lp += (noise - lp) * 0.2
		var env := minf(1.0, t * 1.2) * (1.0 - exp(-(2.0 - t) * 25.0))
		s[i] = (sin(ph) * 0.22 + lp * 0.5) * env
	return _wav(s)
