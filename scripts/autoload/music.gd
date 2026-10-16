extends Node
## The soundtrack. Like every other sound in the game it is synthesised: a
## small orchestra (strings, low strings, horns, a wordless choir, piano,
## timpani, a war drum, a snare) is rendered into samples on a worker thread at
## startup, and a sequencer plays them from the scores below through a hall
## reverb on the Music bus.
##
## The menu plays the theme. A battle plays a score in layers that come and go
## with the fighting (Atmosphere reports how hot it is): a quiet bed of strings
## and a few piano notes while it's calm, then a driving low pulse, drums and
## horns as it heats up. In a long lull the music rests and leaves the
## battlefield to the wind. Victory and defeat each get a short sting.

const RATE := 22050
const TABLE := 2048  # samples in one cycle of a waveform
const LOOP_S := 3.0  # a held note's sample loops over this many seconds
const VOICES := 40

## inst -> [kind, the pitches it's rendered at, level in the mix]. A "held"
## instrument sustains for as long as a note lasts; a "hit" plays out. A note
## plays the nearest rendering, retuned, so none is stretched far.
const INSTRUMENTS := {
	"strings": ["held", ["A2", "A3", "A4"], 0.8],
	"low": ["held", ["A1", "A2"], 0.9],
	"horn": ["held", ["A2", "A3", "A4"], 0.75],
	"choir": ["held", ["A3", "A4"], 0.5],
	"spicc": ["hit", ["D2", "D3"], 0.7],
	"piano": ["hit", ["C3", "C4", "C5"], 0.75],
	"timp": ["hit", ["D2"], 0.8],
	"drum": ["hit", ["D1"], 0.9],
	"snare": ["hit", ["C4"], 0.45],
	"swell": ["hit", ["C4"], 0.35],
}

## Chords as [bass, voicing]. The voicings move by step from one chord to the
## next, the way an arranger would write them for strings.
const CHORDS := {
	"Dm": ["D2", "A3 D4 F4"], "Bb": ["Bb1", "Bb3 D4 F4"], "F": ["F2", "A3 C4 F4"], "C": ["C2", "G3 C4 E4"],
	"Gm": ["G1", "G3 Bb3 D4"], "A": ["A1", "A3 C#4 E4"], "Eb": ["Eb2", "G3 Bb3 Eb4"], "D": ["D2", "A3 D4 F#4"],
}
const PITCH := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const SWELL_S := 2.4  # the cymbal swell's length: it ends on the beat it leads into

var enabled := false
var heat := 0.0  # how hot the fighting is, 0..1 (Atmosphere sets it)

var _task := -1
var _rendered := {}  # filled by the worker thread
var _samples := {}  # inst -> [[hz, AudioStreamWAV], ...]
var _ready_ok := false
var _synth_rng := RandomNumberGenerator.new()  # the worker thread's own
var _rng := RandomNumberGenerator.new()
var _voices: Array[Voice] = []
var _clock := 0.0  # music time: real time, but it waits while the game hitches
var _last_us := 0
var _cue := ""
var _want := ""  # the cue asked for before the samples were ready
var _loops := false
var _events: Array = []  # [time, inst, midi, length, vel, layer, fade, rel], times in seconds into the pass
var _ev_i := 0
var _pass_t0 := 0.0
var _pass_len := 0.0
var _bpm := 66.0
var _level := 1.0  # the cue's overall level: in battle the score sits under the guns
var _heat := 0.0
var _spent := 0.0  # seconds the drums have been going (less while they rest)
var _tired := false
var _layer := PackedFloat32Array([1, 1, 1, 1, 1])
var _layer_want := PackedFloat32Array([1, 1, 1, 1, 1])
var _battle_on := true


class Voice:
	var p: AudioStreamPlayer
	var on := false
	var layer := 0
	var vel := 1.0
	var t0 := 0.0
	var fade := 0.0  # seconds to swell in
	var off := INF  # music time its release begins
	var rel := 0.3  # seconds to die away


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = Sfx.enabled
	if not enabled and Sfx.dump_dir() == "":
		set_process(false)
		return
	var bi := AudioServer.get_bus_index("Music")
	if bi >= 0 and AudioServer.get_bus_effect_count(bi) == 0:
		# a hall, so the instruments sound like players in a room
		var rv := AudioEffectReverb.new()
		rv.predelay_msec = 35.0
		rv.room_size = 0.78
		rv.damping = 0.45
		rv.spread = 1.0
		rv.hipass = 0.15
		rv.dry = 0.85
		rv.wet = 0.3
		AudioServer.add_bus_effect(bi, rv)
	for i in VOICES:
		var v := Voice.new()
		v.p = AudioStreamPlayer.new()
		v.p.bus = &"Music"
		add_child(v.p)
		_voices.append(v)
	_battle_on = bool(Settings.get_v("battle_music"))
	Settings.changed.connect(_on_settings)
	_rng.randomize()
	_synth_rng.seed = 1944
	_last_us = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_render_all, false, "Music synthesis")


## Starts a cue: "menu" or "battle", or "" for silence. Whatever was playing
## dies away first.
func play_cue(cue_name: String) -> void:
	_want = cue_name
	if not _ready_ok or cue_name == _cue:
		return
	_begin(cue_name, 2.5)


## A short piece for the end of a battle: "victory" or "defeat". Plays once.
func sting(sting_name: String) -> void:
	_want = ""
	if _ready_ok:
		_begin(sting_name, 1.2)


func _begin(cue_name: String, fade_out: float) -> void:
	var busy := false
	for v in _voices:
		if v.on and v.off > _clock:
			v.off = _clock
			v.rel = fade_out
			busy = true
	_cue = cue_name
	if _cue == "battle":
		heat = 0.0
		_heat = 0.0
		_spent = 0.0
		_tired = false
	_events.clear()
	_ev_i = 0
	_pass_len = 0.0
	_pass_t0 = _clock + (fade_out * 0.6 if busy else 0.3)
	if _cue != "":
		_new_pass()


func _on_settings() -> void:
	var on := bool(Settings.get_v("battle_music"))
	if on == _battle_on:
		return
	_battle_on = on
	if not on and _cue == "battle":
		for v in _voices:
			if v.on and v.off > _clock:
				v.off = _clock
				v.rel = 1.5


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var wall := (now - _last_us) / 1000000.0
	_last_us = now
	if not _ready_ok:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_samples = _rendered
			_ready_ok = true
			if enabled and _want != "":
				_begin(_want, 0.0)
		return
	# music keeps real time whatever speed the battle runs at (the movie writer's
	# fixed frames included), but waits out a hitch rather than rushing to catch up
	var dt := delta / Engine.time_scale if Engine.time_scale > 0.0001 else wall
	dt = minf(dt, 0.1)
	_clock += dt
	_heat = lerpf(_heat, heat, 1.0 - exp(-dt / (1.5 if heat > _heat else 10.0)))
	if _cue == "battle":
		# a long fight doesn't get the full score all the way through: after a
		# minute and a half of drums and horns it eases back to the strings'
		# pulse for a while, as a film score would
		_spent = clampf(_spent + (dt if _layer[2] > 0.5 else -dt), 0.0, 120.0)
		if _spent > 90.0:
			_tired = true
		elif _spent < 20.0:
			_tired = false
		var h := minf(_heat, 0.4) if _tired else _heat
		_layer_want[0] = 0.6 + 0.4 * smoothstep(0.0, 0.5, h)
		_layer_want[1] = smoothstep(0.12, 0.4, h)
		_layer_want[2] = smoothstep(0.35, 0.65, h)
		_layer_want[3] = smoothstep(0.6, 0.9, h)
		_layer_want[4] = 1.0 - smoothstep(0.1, 0.35, h)
	else:
		_layer_want.fill(1.0)
	for i in _layer.size():
		_layer[i] = move_toward(_layer[i], _layer_want[i], dt * 0.5)
	_sequence()
	if OS.has_environment("FL_DEBUG_MUSIC") and int(_clock / 5.0) != int((_clock - dt) / 5.0):
		var on := 0
		for v in _voices:
			on += int(v.on)
		print("MUSIC t=%.0f cue=%s heat=%.2f%s layers=%s voices=%d pass_t=%.1f/%.1f" % [_clock, _cue, _heat, " (easing off)" if _tired else "", str(_layer), on, _clock - _pass_t0, _pass_len])
	for v in _voices:
		if not v.on:
			continue
		if not v.p.playing:
			v.on = false
			continue
		var env := 1.0
		if v.fade > 0.0:
			env = clampf((_clock - v.t0) / v.fade, 0.0, 1.0)
		if _clock > v.off:
			var r := 1.0 - (_clock - v.off) / maxf(0.01, v.rel)
			if r <= 0.0:
				v.p.stop()
				v.on = false
				continue
			env *= r * r
		v.p.volume_db = linear_to_db(maxf(0.00001, v.vel * _layer[v.layer] * env))


func _sequence() -> void:
	if _cue == "":
		return
	var t := _clock - _pass_t0
	if t < 0.0 and _cue == "battle" and _heat > 0.3:
		# resting, and the fighting has flared up: come back in
		_pass_t0 = minf(_pass_t0, _clock + 0.5)
	while _ev_i < _events.size() and float(_events[_ev_i][0]) <= t:
		var e: Array = _events[_ev_i]
		_ev_i += 1
		_start(e, t - float(e[0]))
	if _pass_len > 0.0 and t >= _pass_len:
		if not _loops:
			_cue = ""
			return
		_pass_t0 += _pass_len
		if _cue == "battle" and _heat < 0.15:
			_pass_t0 += _rng.randf_range(25.0, 50.0)  # a lull: rest, and leave it to the wind
		_new_pass()


func _new_pass() -> void:
	_events.clear()
	_ev_i = 0
	_level = 0.7 if _cue == "battle" else 1.0
	match _cue:
		"menu":
			_score_menu()
		"battle":
			_score_battle()
		"victory":
			_sting_victory()
		"defeat":
			_sting_defeat()
	_events.sort_custom(func(a, b): return float(a[0]) < float(b[0]))


func _start(e: Array, late: float) -> void:
	var layer: int = e[5]
	if _layer[layer] < 0.01 and _layer_want[layer] < 0.01:
		return
	if _cue == "battle" and not _battle_on:
		return
	var inst: String = e[1]
	var list: Array = _samples.get(inst, [])
	if list.is_empty():
		return
	var hz := 440.0 * pow(2.0, (int(e[2]) - 69) / 12.0)
	var best: Array = list[0]
	for s in list:
		if absf(log(hz / float(s[0]))) < absf(log(hz / float(best[0]))):
			best = s
	var v := _free_voice()
	v.on = true
	v.layer = layer
	v.vel = float(e[4]) * float(INSTRUMENTS[inst][2]) * _level
	v.t0 = _clock - late
	v.fade = float(e[6])
	v.off = v.t0 + float(e[3])
	v.rel = float(e[7])
	v.p.stream = best[1]
	v.p.pitch_scale = hz / float(best[0])
	var env := clampf(late / v.fade, 0.0, 1.0) if v.fade > 0.0 else 1.0
	v.p.volume_db = linear_to_db(maxf(0.00001, v.vel * _layer[layer] * env))
	# a frame's lateness is made up by starting that far into the note
	v.p.play(minf(late, 0.03) * v.p.pitch_scale)


func _free_voice() -> Voice:
	var best: Voice = _voices[0]
	for v in _voices:
		if not v.on:
			return v
		if v.off < best.off or (v.off == best.off and v.t0 < best.t0):
			best = v
	best.p.stop()
	return best


## --sound-dump: every instrument's samples as WAVs (once they're rendered).
func dump(dir: String) -> void:
	while _task >= 0 or not _ready_ok:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	for inst in _samples:
		var list: Array = _samples[inst]
		for k in list.size():
			(list[k][1] as AudioStreamWAV).save_to_wav(dir.path_join("music_%s_%s.wav" % [inst, INSTRUMENTS[inst][1][k]]))


# --- the scores -----------------------------------------------------------------

## The theme (D minor, 66 bpm): strings settle in, the piano rolls through the
## chords, the horn takes the tune over a quiet parade snare, then the strings
## sing the other half of it over piano and choir, and it dies away.
func _score_menu() -> void:
	_bpm = 66.0
	_loops = true
	var at := 0.0
	# two bars of D minor swelling in
	_pads(at, "Dm:8", 0.36, 3.0, 1.0)
	_n(at, "timp", "D2", 6.0, 0.3, 0, 0.0, 1.5)
	_n(at + 4.0, "piano", "A4", 2.0, 0.3, 0, 0.0, 0.6)
	_n(at + 6.0, "piano", "D5", 2.0, 0.28, 0, 0.0, 0.6)
	at += 8.0
	# A: the piano alone over the strings
	var a := "Dm Bb F C Dm Bb Gm A"
	_pads(at, a, 0.32, 0.6, 1.0)
	_arp(at, a, 0.42)
	at += 32.0
	# B: the horn's tune, snare and timpani under it
	var b := "Bb F Gm Dm Bb F Gm:2 A:2 Dm"
	_pads(at, b, 0.38, 0.5, 1.0)
	_line(at, "horn", "F4:2 D4 F4 | A4:3 G4 | Bb4:2 A4 G4 | A4:4 | F4:2 D4 F4 | C5:3 Bb4 | Bb4:2 A4 C#5 | D5:4", 0.55, 0, 0.98, 0.08, 0.7)
	_march(at, 8, 0.24)
	_n(at, "timp", "Bb1", 4.0, 0.45, 0, 0.0, 1.0)
	_n(at + 16.0, "timp", "Bb1", 4.0, 0.45, 0, 0.0, 1.0)
	_n(at + 28.0, "timp", "D2", 4.0, 0.5, 0, 0.0, 1.0)
	at += 32.0
	# A again: the strings carry the tune, the choir above, the piano under
	_pads(at, a, 0.3, 0.6, 1.0)
	_arp(at, a, 0.32)
	_line(at, "strings", "A4:3 G4 | F4:2 D4:2 | C4:3 D4 | E4:4 | A4:3 Bb4 | D5:2 C5 Bb4 | Bb4:2 A4 G4 | A4:4", 0.5, 0, 1.0, 0.25, 0.8)
	_choir(at, a, 0.3)
	at += 32.0
	# D minor dying away, the piano's last notes
	_pads(at, "Dm:8", 0.28, 0.6, 4.0)
	_n(at, "piano", "D5", 3.0, 0.32, 0, 0.0, 0.8)
	_n(at + 3.0, "piano", "A4", 2.0, 0.26, 0, 0.0, 0.8)
	_n(at + 5.0, "piano", "D4", 4.0, 0.24, 0, 0.0, 1.5)
	at += 8.0
	_pass_len = _b(at + 12.0)  # three bars' silence before it comes round again


## The battle (D minor, 96 bpm), in layers the fighting turns up and down:
## 0 the strings' bed, 1 low strings driving eighths, 2 drums, 3 horns, 4 a few
## high piano notes that only sound while it's quiet.
func _score_battle() -> void:
	_bpm = 96.0
	_loops = true
	var prog := "Dm:8 Bb:8 Gm:8 A:8 Dm:8 Eb:8 Bb:8 A:8"
	_pads(0.0, prog, 0.34, 1.2, 1.4)
	var at := 0.0
	for tok in prog.split(" "):
		var c := _chord_at(tok)
		var ch: Array = CHORDS[c[0]]
		var bass := _midi(ch[0])
		var voicing := _notes(ch[1])
		var beats: float = c[1]
		for k in int(beats * 2.0):
			var acc: bool = k % 8 in [0, 3, 6]  # 3 + 3 + 2
			_n(at + k * 0.5, "spicc", bass + 12, 0.45, 0.8 if acc else 0.5, 1, 0.0, 0.1)
			if acc:
				_n(at + k * 0.5, "spicc", bass, 0.45, 0.6, 1, 0.0, 0.1)
		for bar in int(beats / 4.0):
			var b0 := at + bar * 4.0
			for h in [[0.0, 0.95], [0.75, 0.45], [2.0, 0.75], [3.5, 0.55]]:
				_n(b0 + float(h[0]), "drum", "D1", 4.0, float(h[1]), 2, 0.0, 0.5)
			_n(b0 + 1.0, "snare", "C4", 1.0, 0.25, 2)
			_n(b0 + 3.0, "snare", "C4", 1.0, 0.3, 2)
		_n(at, "timp", bass if bass >= 36 else bass + 12, 4.0, 0.6, 2, 0.0, 1.0)
		_n(at, "horn", bass + 12, beats, 0.5, 3, 1.6, 1.2)
		_n(at, "horn", bass + 19, beats, 0.42, 3, 1.6, 1.2)
		_n(at + _rng.randi_range(0, 1) * 2.0, "piano", voicing[_rng.randi() % voicing.size()] + 12, 3.0, 0.3, 4, 0.0, 0.6)
		if _rng.randf() < 0.6:
			_n(at + 4.0 + _rng.randi_range(0, 2), "piano", voicing[_rng.randi() % voicing.size()] + 12, 3.0, 0.26, 4, 0.0, 0.6)
		at += beats
	# a cymbal swelling into the second half, and into the next time round
	for end in [32.0, 64.0]:
		_n(end - SWELL_S * _bpm / 60.0, "swell", "C4", 8.0, 0.5, 3)
	_pass_len = _b(at)


## Victory: a timpani roll into D major, horns and strings in full.
func _sting_victory() -> void:
	_bpm = 60.0
	_loops = false
	for k in 14:
		_n(k * 0.11, "timp", "A1", 1.0, lerpf(0.15, 0.7, k / 13.0), 0, 0.0, 0.4)
	var hit := 1.7
	_n(hit, "drum", "D1", 4.0, 1.0)
	_n(hit, "timp", "D2", 4.0, 0.9, 0, 0.0, 1.5)
	_chord_notes(hit, "strings", "A3 D4 F#4 A4", 4.5, 0.45, 0.3, 3.0)
	_chord_notes(hit, "low", "D2 D3", 4.5, 0.5, 0.3, 3.0)
	_chord_notes(hit, "horn", "D3 A3 D4 F#4", 4.5, 0.5, 0.4, 3.0)
	_chord_notes(hit, "choir", "A4 D5", 4.5, 0.35, 0.8, 3.0)
	_n(hit + 0.5, "piano", "D5", 3.0, 0.3, 0, 0.0, 1.0)
	_pass_len = hit + 8.0


## Defeat: low strings in D minor, and the horn falling away to the tonic.
func _sting_defeat() -> void:
	_bpm = 60.0
	_loops = false
	_n(0.0, "drum", "D1", 4.0, 0.5)
	_chord_notes(0.0, "strings", "D3 F3 A3", 7.5, 0.4, 1.5, 3.0)
	_chord_notes(0.0, "low", "D2", 7.5, 0.5, 1.0, 3.0)
	_line(0.5, "horn", "A3:1.4 G3:1.4 F3:1.4 E3:1.4 D3:4", 0.45, 0, 1.0, 0.15, 2.0)
	_n(6.1, "timp", "D2", 4.0, 0.45, 0, 0.0, 1.5)
	_n(6.6, "piano", "D4", 3.0, 0.25, 0, 0.0, 1.5)
	_pass_len = 11.0


# --- writing scores ---------------------------------------------------------------

func _b(beats: float) -> float:
	return beats * 60.0 / _bpm


## One note: `at` and `dur` in beats, `note` a name ("F#4") or a MIDI number;
## `fade` (swelling in) and `rel` (dying away) in seconds.
func _n(at: float, inst: String, note, dur: float, vel: float, layer := 0, fade := 0.0, rel := 0.3) -> void:
	var m: int = note if note is int else _midi(String(note))
	_events.append([_b(at), inst, m, _b(dur), vel, layer, fade, rel])


func _chord_notes(at: float, inst: String, notes: String, dur: float, vel: float, fade: float, rel: float, layer := 0) -> void:
	for m in _notes(notes):
		_n(at, inst, m, dur, vel, layer, fade, rel)


## A tune: "F4:2 D4 F4 | A4:3 G4" (beats after the colon, one if none; "r" is
## a rest, "|" only marks the bars).
func _line(at: float, inst: String, notes: String, vel: float, layer := 0, legato := 0.95, fade := 0.0, rel := 0.3) -> void:
	var t := at
	for tok in notes.split(" ", false):
		if tok == "|":
			continue
		var parts := tok.split(":")
		var d := float(parts[1]) if parts.size() > 1 else 1.0
		if parts[0] != "r":
			_n(t, inst, parts[0], d * legato, vel, layer, fade, rel)
		t += d


## The strings' chords and the low strings' bass under them, one chord per
## token ("Gm:2" holds it two beats; four if no count).
func _pads(at: float, prog: String, vel: float, fade: float, rel: float, layer := 0) -> void:
	var t := at
	for tok in prog.split(" ", false):
		var c := _chord_at(tok)
		var ch: Array = CHORDS[c[0]]
		var dur: float = float(c[1]) + 0.15  # a touch of overlap: legato
		_chord_notes(t, "strings", ch[1], dur, vel, fade, rel, layer)
		var bass := _midi(ch[0])
		_n(t, "low", bass, dur, vel * 1.1, layer, fade, rel)
		_n(t, "low", bass + 12, dur, vel * 0.7, layer, fade, rel)
		t += float(c[1])


## The piano rolling through each chord in eighths, the bass note under it.
func _arp(at: float, prog: String, vel: float) -> void:
	var t := at
	for tok in prog.split(" ", false):
		var c := _chord_at(tok)
		var ch: Array = CHORDS[c[0]]
		var v := _notes(ch[1])
		var tones := [v[0], v[1], v[2], v[0] + 12, v[1] + 12]
		var pat := [1, 2, 3, 2, 4, 2, 3, 2]
		var acc := [1.0, 0.7, 0.8, 0.7, 0.9, 0.7, 0.8, 0.7]
		_n(t, "piano", _midi(ch[0]) + 12, float(c[1]), vel * 0.8, 0, 0.0, 0.5)
		for k in int(float(c[1]) * 2.0):
			_n(t + k * 0.5, "piano", tones[pat[k % 8]], 1.5, vel * float(acc[k % 8]), 0, 0.0, 0.5)
		t += float(c[1])


## The choir holding the top of each chord, an octave up.
func _choir(at: float, prog: String, vel: float) -> void:
	var t := at
	for tok in prog.split(" ", false):
		var c := _chord_at(tok)
		var v := _notes(CHORDS[c[0]][1])
		for m in [v[0] + 12, v[1] + 12]:
			_n(t, "choir", m, float(c[1]) + 0.2, vel, 0, 0.6, 1.2)
		t += float(c[1])


## A parade snare: an accent, a tap, a quick ruff into the third beat; every
## fourth bar a fill leading on.
func _march(at: float, bars: int, vel: float) -> void:
	for bar in bars:
		var b0 := at + bar * 4.0
		var hits := [[0.0, 1.0], [1.0, 0.45], [2.0, 0.7], [2.5, 0.5], [2.75, 0.5], [3.0, 0.85]]
		if bar % 4 == 3:
			hits = [[0.0, 1.0], [1.0, 0.45], [2.0, 0.7], [3.0, 0.5], [3.25, 0.6], [3.5, 0.75], [3.75, 0.9]]
		for h in hits:
			_n(b0 + float(h[0]), "snare", "C4", 1.0, vel * float(h[1]))


## "Gm:2" -> ["Gm", 2.0]
func _chord_at(tok: String) -> Array:
	var p := tok.split(":")
	return [p[0], float(p[1]) if p.size() > 1 else 4.0]


func _notes(s: String) -> Array:
	var out := []
	for nn in s.split(" ", false):
		out.append(_midi(nn))
	return out


## "C#4" -> 61 (MIDI; middle C is C4).
static func _midi(nn: String) -> int:
	var pc: int = PITCH[nn[0]]
	var i := 1
	if nn[i] == "#":
		pc += 1
		i += 1
	elif nn[i] == "b":
		pc -= 1
		i += 1
	return pc + 12 * (int(nn.substr(i)) + 1)


# --- the instruments (rendered on a worker thread) ---------------------------

func _render_all() -> void:
	var out := {}
	for inst in INSTRUMENTS:
		var list := []
		for nn in INSTRUMENTS[inst][1]:
			list.append(_render(String(inst), _midi(String(nn))))
		out[inst] = list
	_rendered = out


## [the pitch it actually sounds at (Hz), the sample]
func _render(inst: String, midi: int) -> Array:
	var f0 := 440.0 * pow(2.0, (midi - 69) / 12.0)
	match inst:
		"strings":
			return _held(f0, _saw(f0, 2400.0), [-7.0, 0.0, 6.0], 6.0, 0.25, 0.0)
		"low":
			return _held(f0, _saw(f0, 1000.0), [-5.0, 4.0], 4.0, 0.2, 0.0)
		"horn":
			return _held(f0, _brass(f0), [-3.0, 3.0], 5.0, 0.12, 0.0)
		"choir":
			return _held(f0, _vowel(f0), [-9.0, -2.0, 4.0, 10.0], 12.0, 0.3, 0.05)
		"spicc":
			return [f0, _spicc(f0)]
		"piano":
			return [f0, _piano(f0)]
		"timp":
			return [f0, _timp(f0)]
		"drum":
			return [f0, _drum()]
		"snare":
			return [f0, _snare()]
	return [f0, _swell()]


## Harmonic amplitudes of a bowed string: a sawtooth's 1/n, rolled off above
## `bright` Hz (a darker tone for the low strings).
func _saw(f0: float, bright: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for h in range(1, mini(80, int(9500.0 / f0)) + 1):
		a.append(1.0 / h / (1.0 + pow(h * f0 / bright, 2.0)))
	return a


## A mellow horn: strong low harmonics, falling away steeply above ~900 Hz.
func _brass(f0: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for h in range(1, mini(60, int(9500.0 / f0)) + 1):
		a.append(1.0 / pow(h, 0.6) / (1.0 + pow(h * f0 / 900.0, 2.5)))
	return a


## Voices singing "ah": the harmonics shaped by the vowel's formants.
func _vowel(f0: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for h in range(1, mini(60, int(9500.0 / f0)) + 1):
		var f := h * f0
		var g := 0.03 / h
		for fm in [[730.0, 90.0, 1.0], [1090.0, 110.0, 0.5], [2440.0, 160.0, 0.22]]:
			g += float(fm[2]) / (1.0 + pow((f - float(fm[0])) / float(fm[1]), 2.0))
		a.append(g / pow(h, 0.3))
	return a


## One cycle of a waveform from its harmonics, peak 1 (one sample longer than
## the cycle, so a lookup can always read the next one).
func _table(amps: PackedFloat32Array) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TABLE + 1)
	var top := 0.0
	for i in TABLE:
		var x := TAU * i / TABLE
		var v := 0.0
		for h in amps.size():
			v += amps[h] * sin(x * (h + 1))
		t[i] = v
		top = maxf(top, absf(v))
	for i in TABLE:
		t[i] /= top
	t[TABLE] = t[0]
	return t


## A sustained note: copies of the waveform detuned around the pitch (an
## ensemble), with vibrato, swelling in over `att` seconds; then the sample
## loops. Each copy is tuned to a whole number of cycles in the loop and the
## vibrato to a whole number of wobbles, so the loop has no seam. Returns the
## pitch it actually sounds at (it's rounded to fit the loop), so notes retuned
## from it are true.
func _held(f0: float, amps: PackedFloat32Array, detune: Array, vib_cents: float, att: float, breath: float) -> Array:
	var tab := _table(amps)
	var loop_n := int(LOOP_S * RATE)
	var att_n := int(att * RATE)
	var n := att_n + loop_n
	var k0 := roundi(f0 * LOOP_S)
	var hz := k0 / LOOP_S
	var vib_hz := 5.0  # 15 wobbles in the loop
	var lfo_n := int(RATE / vib_hz)
	var lfo := PackedFloat32Array()
	lfo.resize(lfo_n)
	for i in lfo_n:
		lfo[i] = sin(TAU * i / lfo_n)
	var freqs := PackedFloat32Array()
	var depth := PackedFloat32Array()
	var phase := PackedFloat32Array()
	var lfo_off := PackedInt32Array()
	for d in detune:
		var k := roundi(f0 * (pow(2.0, float(d) / 1200.0) - 1.0) * LOOP_S)
		if k == 0 and float(d) != 0.0:
			k = 1 if float(d) > 0.0 else -1
		var f := (k0 + k) / LOOP_S
		freqs.append(f)
		depth.append(f * (pow(2.0, vib_cents / 1200.0) - 1.0) / vib_hz / TAU)
		phase.append(_synth_rng.randf())
		lfo_off.append(_synth_rng.randi() % lfo_n)
	# breath: noise that itself repeats with the loop
	var noise := PackedFloat32Array()
	if breath > 0.0:
		noise.resize(loop_n)
		var lp := 0.0
		var hp := 0.0
		for rep in 2:
			for i in loop_n:
				lp += ((_synth_rng.randf() * 2.0 - 1.0) - lp) * 0.3
				hp += (lp - hp) * 0.08
				noise[i] = lp - hp
	var s := PackedFloat32Array()
	s.resize(n)
	var nv := freqs.size()
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in nv:
			var x := fmod(phase[j] + freqs[j] * t + depth[j] * lfo[(i + lfo_off[j]) % lfo_n], 1.0) * TABLE
			if x < 0.0:
				x += TABLE
			var xi := int(x)
			v += tab[xi] + (tab[xi + 1] - tab[xi]) * (x - xi)
		v /= nv
		if breath > 0.0:
			v += noise[(i - att_n + loop_n) % loop_n] * breath
		if i < att_n:
			v *= 0.5 - 0.5 * cos(PI * i / att_n)
		s[i] = v
	# level: the loop at -14 dBFS RMS
	var sum := 0.0
	for i in range(att_n, n):
		sum += s[i] * s[i]
	var g := db_to_linear(-14.0) / maxf(1e-6, sqrt(sum / loop_n))
	for i in n:
		s[i] = clampf(s[i] * g, -1.0, 1.0)
	var w := _wav(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = att_n
	w.loop_end = n
	return [hz, w]


## Low strings played short and hard (spiccato): a bite of bow noise and a
## quick decay.
func _spicc(f0: float) -> AudioStreamWAV:
	var tab := _table(_saw(f0, 1600.0))
	var n := int(0.7 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var fr := [f0 * pow(2.0, -8.0 / 1200.0), f0, f0 * pow(2.0, 7.0 / 1200.0)]
	var ph := [_synth_rng.randf(), _synth_rng.randf(), _synth_rng.randf()]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in 3:
			var x := fmod(float(ph[j]) + float(fr[j]) * t, 1.0) * TABLE
			var xi := int(x)
			v += tab[xi] + (tab[xi + 1] - tab[xi]) * (x - xi)
		lp += ((_synth_rng.randf() * 2.0 - 1.0) - lp) * 0.4
		s[i] = (v / 3.0 * minf(1.0, t / 0.006) + lp * 0.25 * exp(-t * 60.0)) * exp(-t * 7.0)
	return _wav(_peak(s, -1.0))


## A soft (felt) piano note: slightly stretched partials, each dying away
## faster the higher it is, in two stages like a real string; a hammer thump.
func _piano(f0: float) -> AudioStreamWAV:
	var dur := clampf(6.0 - f0 / 110.0, 2.2, 5.0)
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var k := sqrt(f0 / 261.6)
	var h := 1
	while h <= 10 and h * f0 < 7000.0:
		var fh := h * f0 * sqrt(1.0 + 0.0004 * h * h)
		var amp := 1.0 / pow(h, 1.1) / (1.0 + pow(h * f0 / 1800.0, 2.0))
		var w := TAU * fh / RATE
		var cw := cos(w)
		var sw := sin(w)
		var c := 1.0
		var sn := 0.0
		var r := (1.2 + 0.8 * h) * k
		var d1 := exp(-r / RATE)
		var d2 := exp(-r * 0.2 / RATE)
		var e1 := amp * 0.65
		var e2 := amp * 0.35
		for i in n:
			var c2 := c * cw - sn * sw
			sn = sn * cw + c * sw
			c = c2
			s[i] += sn * (e1 + e2)
			e1 *= d1
			e2 *= d2
		h += 1
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		if i < int(0.04 * RATE):
			lp += ((_synth_rng.randf() * 2.0 - 1.0) - lp) * 0.15
			s[i] += lp * 0.25 * exp(-t * 120.0)
		s[i] *= minf(1.0, t / 0.002) * minf(1.0, (dur - t) / 0.08)
	return _wav(_peak(s, -1.0))


## Timpani: the drum's inharmonic modes, the pitch settling a moment after the
## stroke, a soft mallet.
func _timp(f0: float) -> AudioStreamWAV:
	var n := int(3.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for md in [[1.0, 1.0, 1.6], [1.504, 0.55, 2.6], [1.742, 0.35, 3.4], [2.0, 0.28, 4.0], [2.245, 0.18, 5.0], [2.494, 0.12, 6.0]]:
		var ph := 0.0
		for i in n:
			var t := float(i) / RATE
			ph += TAU * f0 * float(md[0]) * (1.0 + 0.025 * exp(-t * 30.0)) / RATE
			s[i] += sin(ph) * float(md[1]) * exp(-t * float(md[2]))
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((_synth_rng.randf() * 2.0 - 1.0) - lp) * 0.2
		s[i] = (s[i] + lp * 0.6 * exp(-t * 90.0)) * minf(1.0, t / 0.002)
	return _wav(_peak(s, -1.0))


## A big war drum: a deep skin whose pitch drops as it settles.
func _drum() -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * 52.0 * (1.0 + 0.7 * exp(-t * 22.0)) / RATE
		ph2 += TAU * 83.0 * (1.0 + 0.5 * exp(-t * 30.0)) / RATE
		var w := _synth_rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.12
		s[i] = (sin(ph) * exp(-t * 3.2) + sin(ph2) * 0.3 * exp(-t * 7.0) + lp * 0.6 * exp(-t * 20.0) + w * 0.3 * exp(-t * 300.0)) * minf(1.0, t / 0.0015)
	return _wav(_peak(s, -1.0))


## A snare: the shell's ring and the rattle of the wires.
func _snare() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _synth_rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.25
		s[i] = (sin(TAU * 185.0 * t) * 0.7 * exp(-t * 30.0) + sin(TAU * 330.0 * t) * 0.3 * exp(-t * 40.0) + (w - lp) * 0.8 * exp(-t * 14.0)) * minf(1.0, t / 0.001)
	return _wav(_peak(s, -1.0))


## A suspended cymbal rolled from nothing up to the next downbeat.
func _swell() -> AudioStreamWAV:
	var n := int(SWELL_S * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _synth_rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		s[i] = (w - lp) * pow(t / SWELL_S, 2.5) * minf(1.0, (SWELL_S - t) / 0.02)
	return _wav(_peak(s, -1.0))


## Scales a one-shot to a peak level (dBFS) and fades out its last 20 ms, so
## it ends in silence wherever its tail had got to.
func _peak(s: PackedFloat32Array, db: float) -> PackedFloat32Array:
	var top := 0.0
	for x in s:
		top = maxf(top, absf(x))
	var g := db_to_linear(db) / maxf(1e-6, top)
	var tail := int(0.02 * RATE)
	for i in s.size():
		s[i] *= g * minf(1.0, float(s.size() - 1 - i) / tail)
	return s


func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
