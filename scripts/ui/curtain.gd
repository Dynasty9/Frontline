class_name Curtain
extends Control
## The full-screen curtain over everything while the game gets ready, drawn on
## the same living map (TopoBackdrop) that lies behind the menu:
##  - the title: it picks up exactly where the boot splash leaves off (the map
##    asleep under the emblem and the name), sends a wave out of the emblem's
##    dot that wakes the map and lights its contours, then lifts away and
##    leaves the menu on the same map;
##  - the loading screen before a battle: the operation, its conditions, a tip
##    and the stages of the build over the map being surveyed, held while the
##    first frames compile their shaders behind it, then fading into the
##    battlefield. It's a Signal readout (docs/UI.md): labels in faint
##    capitals, values in mono, rules under the lines, the field note as prose
##    under a rule and the build as a row of counted steps.

signal gone

const TIPS := [
	"Pin them first. A suppressed man barely shoots back - put the machine gun on them, then move.",
	"Place a machine gun on a trench and it becomes a gun bay: tripod on the lip, gunner on the fire step.",
	"Attack-move ({attack_move}) makes a squad bound by fire teams from cover to cover instead of walking in the open.",
	"A deliberate attack fixes the enemy with one element and flanks with the other. Give it time to set up.",
	"Smoke ({smoke}) across open ground before an assault. Nobody can hit what they can't see.",
	"Trenches stop almost everything but a shell that lands in them or fire straight down the bay.",
	"Medics and stretcher bearers bring the wounded back. Keep your medic tent close to the fighting.",
	"Supply runs down the road. Cut the enemy's road and their FOBs starve.",
	"Every village is supply. Hold its ground with no enemy on it and its trucks start running to your nearest FOB.",
	"A town shelled to ruins gives a third of what it did. Take it, don't flatten it.",
	"Tanks shrug off rifles. Rockets from the side or the rear, mines and AT posts are what stop them.",
	"An outnumbered attack goes firm and calls for help. Answer it with fires or another squad.",
	"{tactical} opens the tactical map: every order, plan and contact on a dimmed battlefield.",
	"{manual} opens the Field Manual: every unit, weapon and vehicle with its numbers.",
	"Men at a halt take a knee and watch their sectors. Select a squad to see its arcs of fire.",
	"Rebels can dig tunnels between entrances and move whole cells under the enemy's guns.",
	"Night battles are lit by street lamps and flares. Muzzle flashes give positions away.",
	"Mortar pits shell anything your side can see, even behind cover. Keep your own men 8 m clear.",
]

const OP_A := ["IRON", "SILENT", "BROKEN", "AMBER", "COLD", "GRANITE", "HOLLOW", "NORTHERN", "PALE", "SCARLET", "STEEL", "WINTER", "DUSTY", "BLACK", "LONG"]
const OP_B := ["VEIL", "ANVIL", "HARVEST", "LANTERN", "SPEAR", "CROSSING", "RIDGE", "TIDE", "FALCON", "ORCHARD", "WATCH", "HAMMER", "CANAL", "GATE", "MERIDIAN"]
const MOOD_TEXT := {"day": "Midday, clear", "golden": "Golden hour, long shadows", "dawn": "Dawn, low sun", "dusk": "Dusk, failing light",
	"overcast": "Overcast, flat light", "hazy": "Hazy, poor visibility", "night": "Night, street lights and flares", "rain": "Rain and thunder", "random": "Unknown"}

const WAKE_AT := 0.35  # the title: when the wave goes out (seconds in)
const TITLE_HOLD := 1.9  # and when the menu may take over
const SAND := Color(0.87, 0.8, 0.63)
const WORD := Color(0.93, 0.91, 0.84)
const TAGLINE := "SQUAD TACTICS  \u00b7  COMBINED ARMS  \u00b7  COMMAND"

var mode := "intro"  # "intro" or "loading"
var hold_at := -1.0  # the title held at this moment (screenshots)
var _map: TopoBackdrop
var _skip := false  # the title was clicked through
var _alpha := 1.0
var _fading := false
var _fade_rate := 1.8
var _t := 0.0
var _progress := 0.0
var _shown_progress := 0.0
var _stage := ""
var _stage_t := -1.0  # when the stage's name started to type on (-1: drawn whole)
var _title := ""
var _lines: Array = []  # [label, value, when the value started to type on]
var _tip := ""
var _story := ""  # a mission's briefing, under the lines
var _last_us := 0
var _steady := false  # the last frame came on time (see _born)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it takes clicks until it's gone
	_map = TopoBackdrop.new()
	_map.show_behind_parent = true
	_sync_map()
	add_child(_map)


## The title has played (or been clicked through): the menu can take over.
func title_done() -> bool:
	return hold_at < 0.0 and (_skip or _t >= TITLE_HOLD)


func _gui_input(ev: InputEvent) -> void:
	if mode == "intro" and ev is InputEventMouseButton and ev.pressed:
		_skip = true


func _input(ev: InputEvent) -> void:
	if mode == "intro" and ev is InputEventKey and ev.pressed:
		_skip = true


## The loading screen's briefing: who's fighting, where and when.
func brief(seed: int, what: String, lines: Array, op := "", story := "") -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	_title = "OPERATION %s %s" % [OP_A[r.randi() % OP_A.size()], OP_B[r.randi() % OP_B.size()]]
	if op != "":
		_title = op.to_upper()
	_lines = [["MISSION", what, _born()]]
	for l in lines:
		_lines.append([String(l[0]), String(l[1]), _born()])
	_tip = _with_keys(TIPS[r.randi() % TIPS.size()])
	if OS.has_feature("web"):
		# the page answers only between the stages of laying out the battlefield
		# (World._breathe), and not at all while its graphics are first prepared
		# (main.gd _reveal_next_frame): say so before the browser does
		_tip = "In a browser the battlefield is laid out a stage at a time and its graphics prepared, which takes longest the first time. If the browser says the page isn't responding, choose Wait."
	_story = story
	queue_redraw()


## A tip with {action} put back as the key it's bound to now.
static func _with_keys(t: String) -> String:
	for id in ["attack_move", "smoke", "tactical", "manual"]:
		var k := Keys.label(id)
		t = t.replace("{%s}" % id, k if k != "" else "Its key")
	return t


func add_line(label: String, value: String) -> void:
	for l in _lines:
		if l[0] == label:
			if l[1] != value:
				l[1] = value
				l[2] = _born()  # a value coming in (the conditions, once known) types on
			queue_redraw()
			return
	_lines.append([label, value, _born()])
	queue_redraw()


func set_stage(text: String, frac: float) -> void:
	if text != _stage:
		_stage = text
		_stage_t = _born()
	_progress = clampf(frac, _progress, 1.0)
	queue_redraw()


## When text arriving now starts to type on: now, while the screen's frames are
## coming steadily, or never (drawn whole) while it's being held up. On the
## desktop the battlefield is built in one long frame right after the screen
## first draws, and in a browser each stage of it is a long frame: a line
## caught half typed would hang there for the whole wait.
func _born() -> float:
	return _t if _steady else -1.0


## How much of `s` has typed on since `at` (all of it with Reduce motion, or
## when it was drawn whole).
func _typed(s: String, at: float) -> String:
	if at < 0.0 or UiMotion.reduced():
		return s
	var dur := minf(s.length() * UiMotion.TYPE, UiMotion.TYPE_MAX)
	return s.left(ceili(clampf((_t - at) / maxf(dur, 0.001), 0.0, 1.0) * s.length()))


## Fade out, then free.
func finish(rate := 1.8) -> void:
	_fading = true
	_fade_rate = rate


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)  # a long build frame shouldn't skip the fade
	_t = hold_at if hold_at >= 0.0 else _t + dt
	# whether the frames are coming steadily, by the wall clock (dt is the
	# game's, and capped)
	var now := Time.get_ticks_usec()
	_steady = _last_us > 0 and now - _last_us < 100000
	_last_us = now
	_shown_progress = move_toward(_shown_progress, _progress, dt * 1.6)
	if _fading:
		_alpha -= dt * _fade_rate
		if _alpha <= 0.0:
			gone.emit()
			queue_free()
			return
	modulate.a = clampf(_alpha, 0.0, 1.0)
	_sync_map()
	queue_redraw()


func _sync_map() -> void:
	if mode == "intro":
		_map.wake_at = _dot(size) / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
		_map.wake_t = _t - WAKE_AT
		_map.shade = 0.0
		_map.scan = 0.0
		_map.quiet = Vector3(0.5, 0.49, 0.62)  # so the name stands clear of the brightest lines
	else:
		_map.wake_t = 1000.0
		_map.shade = 1.0  # as under the menu, so the one gives way to the other without a seam
		_map.scan = clampf(_t * 1.5, 0.0, 1.0)
		_map.quiet = Vector3(0.3, 0.38, 0.5)  # a calm patch under the briefing
		# closing in on the ground while it's built, then diving into it as the
		# battlefield fades up
		var dive := 1.0 - clampf(_alpha, 0.0, 1.0)
		_map.zoom = 1.0 + 0.4 * (1.0 - exp(-_t * 0.35)) + 1.6 * dive * dive


## The emblem's centre on the title, laid out as on the boot splash (1080
## pixels high, centred), and its red dot, where the wave starts.
func _emblem_at(vs: Vector2) -> Vector2:
	return vs * 0.5 + Vector2(0, -159) * (vs.y / 1080.0)


func _dot(vs: Vector2) -> Vector2:
	return _emblem_at(vs) + Vector2(0, 12.4) * (vs.y / 1080.0)


func _draw() -> void:
	if mode == "intro":
		_draw_title(size)
	else:
		_draw_loading(size)


## The title, as on the boot splash: the emblem, the name, a rule and the
## tagline. When the wave goes out of the dot a ring rides its front, the rule
## glints where it crosses and each letter flares as it passes; as the menu
## takes over, the title rises away.
func _draw_title(vs: Vector2) -> void:
	var u := vs.y / 1080.0
	var wt := _t - WAKE_AT
	var dot := _dot(vs)
	var front := TopoBackdrop.wave_front(wt) * vs.y if wt >= 0.0 else -1000.0  # where the map's wave has got to
	var ring := exp(-wt * 1.7) if wt >= 0.0 else 0.0
	var rise := Vector2(0, -22.0 * u * (1.0 - clampf(_alpha, 0.0, 1.0)))
	var ec := _emblem_at(vs) + rise
	var s := 62.0 * u
	var pts := PackedVector2Array([ec + Vector2(-s, s * 0.78), ec + Vector2(0, -s * 0.82), ec + Vector2(s, s * 0.78), ec + Vector2(-s, s * 0.78)])
	draw_polyline(pts, SAND.lerp(Color.WHITE, ring * 0.35), 5.0 * u, true)
	var pulse := exp(-wt * 4.0) if wt >= 0.0 else 0.0
	draw_circle(dot + rise, s * 0.2 * (1.0 + 0.3 * pulse), Color(0.84, 0.32, 0.24).lerp(Color(1.0, 0.72, 0.6), pulse))
	if ring > 0.02:
		draw_arc(dot + rise, maxf(front, 1.0), 0.0, TAU, 128, Color(1.0, 0.86, 0.7, 0.28 * ring), 1.5 * u, true)
	_spaced("FRONTLINE", vs.x * 0.5, vs.y * 0.5 + 24.0 * u, 806.0 * u, int(121.0 * u), WORD, dot, front, ring, rise)
	var ry := vs.y * 0.5 + 88.0 * u
	var rw := 822.0 * u
	var rx := vs.x * 0.5 - rw * 0.5
	draw_rect(Rect2(Vector2(rx, ry) + rise, Vector2(rw, 2.0 * u)), SAND)
	var dy := ry - dot.y
	if ring > 0.02 and front > absf(dy):
		var gx := sqrt(front * front - dy * dy)
		for side in [-1.0, 1.0]:
			var x: float = vs.x * 0.5 + side * gx
			if x > rx and x < rx + rw:
				for i in 6:
					var hw := (6 - i) * 14.0 * u
					var x0 := clampf(x - hw, rx, rx + rw)
					draw_rect(Rect2(Vector2(x0, ry - 0.5 * u) + rise, Vector2(minf(x + hw, rx + rw) - x0, 3.0 * u)), Color(1, 0.95, 0.85, 0.12 * ring))
	_spaced(TAGLINE, vs.x * 0.5, vs.y * 0.5 + 125.0 * u, 817.0 * u, int(23.0 * u), SAND, dot, front, ring, rise)


## Capitals spread evenly to fill a width, centred on cx, each flaring as the
## wave front passes it.
func _spaced(text: String, cx: float, base: float, w: float, fs: int, col: Color, dot: Vector2, front: float, ring: float, rise: Vector2) -> void:
	var f := UiKit.font(700)
	var adv := PackedFloat32Array()
	var total := 0.0
	for i in text.length():
		var a := f.get_char_size(text.unicode_at(i), fs).x
		adv.append(a)
		total += a
	var gap := (w - total) / maxf(float(text.length() - 1), 1.0)
	var x := cx - w * 0.5
	var ci := get_canvas_item()
	for i in text.length():
		var ch := text.unicode_at(i)
		var p := Vector2(x, base) + rise
		var d := (p + Vector2(adv[i] * 0.5, -fs * 0.35) - dot).length()
		var fl := ring * exp(-absf(d - front) / (fs * 0.9))
		f.draw_char(ci, p, ch, fs, col.lerp(Color(1.0, 0.98, 0.93), fl))
		x += adv[i] + gap


## The loading screen, down the left over the map: the name, the operation
## ruled off, the briefing as lines of a label and its value, and at the foot
## the field note and the build's progress, all in one column.
func _draw_loading(vs: Vector2) -> void:
	var m := Vector2(maxf(64.0, vs.x * 0.06), maxf(56.0, vs.y * 0.09))
	var cw := minf(720.0, vs.x - m.x * 2.0)  # the column's width
	var vx := m.x + 130.0  # where the values start
	_emblem(m + Vector2(14, 14), 14.0)
	UiKit.caps_at(self, m + Vector2(44, 19), "Frontline", 13, UiKit.DIM)
	UiKit.text_f(self, UiKit.cond(700, 2), m + Vector2(0, 92), _title, 44, UiKit.TEXT)
	UiKit.rule(self, Vector2(m.x, m.y + 110.5), Vector2(m.x + cw, m.y + 110.5), UiKit.RULE2)
	var y := m.y + 150.0
	for l in _lines:
		UiKit.caps_at(self, Vector2(m.x, y), String(l[0]), 11, UiKit.FAINT)
		UiKit.mono_at(self, Vector2(vx, y), _typed(String(l[1]).to_upper(), float(l[2])), 13, UiKit.TEXT)
		UiKit.rule(self, Vector2(m.x, y + 12.5), Vector2(m.x + cw, y + 12.5))
		y += 34.0
	if _story != "":
		# a mission's briefing, as the commander reads it out
		y += 8.0
		UiKit.caps_at(self, Vector2(m.x, y), "Briefing", 11, UiKit.FAINT)
		_prose(_wrap_lines(_story, cw - 130.0, 15), Vector2(vx, y), 15, UiKit.TEXT)
	else:
		# the field note: prose under a rule, its label at the head of the rule
		var tl := _wrap_lines(_tip, cw, 15)
		var fy := vs.y - m.y - 74.0 - tl.size() * 21.0
		var lw := UiKit.caps_at(self, Vector2(m.x, fy), "Field note", 11, UiKit.FAINT)
		UiKit.rule(self, Vector2(m.x + lw + 8.0, fy - 3.5), Vector2(m.x + cw, fy - 3.5))
		_prose(tl, Vector2(m.x, fy + 25.0), 15, UiKit.TEXT)
	# the build: its stage in capitals and how far it's got in mono over a row
	# of counted steps, the next one blinking while it's worked on
	var py := vs.y - m.y - 10.0
	UiKit.caps_at(self, Vector2(m.x, py - 10.0), _typed(_stage, _stage_t), 11, UiKit.DIM)
	var pct := "%d%%" % int(_shown_progress * 100.0)
	UiKit.mono_at(self, Vector2(m.x + cw - UiKit.mono_w(pct, 12), py - 10.0), pct, 12, UiKit.TEXT)
	var n := int((cw + 2.0) / 9.0)
	var sw := (cw - 2.0 * (n - 1)) / n
	var filled := _shown_progress * n
	UiKit.steps(self, Vector2(m.x, py), filled, n, UiKit.ACCENT, sw, 8.0)
	var head := ceili(filled - 0.001)  # (as steps() counts them)
	if head < n and not UiMotion.reduced() and int(_t * 4.0) % 2 == 0:
		draw_rect(Rect2(m.x + head * (sw + 2.0), py, sw, 8.0), UiKit.fa(UiKit.ACCENT, 0.55))


func _emblem(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s, s * 0.78), c + Vector2(0, -s * 0.82), c + Vector2(s, s * 0.78), c + Vector2(-s, s * 0.78)])
	draw_polyline(pts, SAND, 2.5, true)
	draw_circle(c + Vector2(0, s * 0.2), s * 0.2, Color(0.84, 0.32, 0.24))


## Prose broken into lines that fit `w`.
static func _wrap_lines(text: String, w: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for wd in text.split(" "):
		var trial: String = wd if line == "" else line + " " + wd
		if UiKit.text_width(trial, fs, 400) > w and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


func _prose(lines: PackedStringArray, p: Vector2, fs: int, col: Color) -> void:
	for i in lines.size():
		UiKit.text(self, Vector2(p.x, p.y + i * (fs + 6)), lines[i], fs, col, 400)
