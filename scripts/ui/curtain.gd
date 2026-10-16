class_name Curtain
extends Control
## The full-screen curtain over everything while the game gets ready:
##  - the intro, carrying on from the boot splash (the same artwork) until the
##    menu's 3D backdrop has actually rendered, then fading into the menu;
##  - the loading screen before a battle: the operation, its conditions, a tip
##    and the stages of the build, held while the first frames compile their
##    shaders behind it, then fading into the battlefield.

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

var mode := "intro"  # "intro" or "loading"
var _art: Texture2D
var _alpha := 1.0
var _fading := false
var _fade_rate := 1.8
var _t := 0.0
var _progress := 0.0
var _shown_progress := 0.0
var _stage := ""
var _title := ""
var _lines: Array = []  # [label, value]
var _tip := ""
var _story := ""  # a mission's briefing, under the lines


static func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it takes clicks until it's gone
	_art = _tex("res://assets/splash.png" if mode == "intro" else "res://assets/backdrop.png")


## The loading screen's briefing: who's fighting, where and when.
func brief(seed: int, what: String, lines: Array, op := "", story := "") -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	_title = "OPERATION %s %s" % [OP_A[r.randi() % OP_A.size()], OP_B[r.randi() % OP_B.size()]]
	if op != "":
		_title = op.to_upper()
	_lines = [["MISSION", what]] + lines
	_tip = _with_keys(TIPS[r.randi() % TIPS.size()])
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
			l[1] = value
			queue_redraw()
			return
	_lines.append([label, value])
	queue_redraw()


func set_stage(text: String, frac: float) -> void:
	_stage = text
	_progress = clampf(frac, _progress, 1.0)
	queue_redraw()


## Fade out, then free.
func finish(rate := 1.8) -> void:
	_fading = true
	_fade_rate = rate


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)  # a long build frame shouldn't skip the fade
	_t += dt
	_shown_progress = move_toward(_shown_progress, _progress, dt * 1.6)
	if _fading:
		_alpha -= dt * _fade_rate
		if _alpha <= 0.0:
			gone.emit()
			queue_free()
			return
	modulate.a = clampf(_alpha, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.031, 0.039, 0.043))
	if _art:
		# cover the screen, centred (the same framing as the boot splash)
		var ts := _art.get_size()
		var k := maxf(vs.x / ts.x, vs.y / ts.y)
		var ds := ts * k
		draw_texture_rect(_art, Rect2((vs - ds) * 0.5, ds), false)
	if mode == "intro":
		_draw_intro(vs)
	else:
		_draw_loading(vs)


func _draw_intro(vs: Vector2) -> void:
	# a thin line sweeping under the tagline while things get ready
	var w := minf(vs.x * 0.3, 520.0)
	var y := vs.y * 0.5 + vs.y * 0.235
	var x0 := (vs.x - w) * 0.5
	draw_rect(Rect2(x0, y, w, 1), Color(1, 1, 1, 0.06))
	var s := fmod(_t * 0.7, 1.4) - 0.2
	var a := clampf(s, 0.0, 1.0)
	var b := clampf(s + 0.2, 0.0, 1.0)
	draw_rect(Rect2(x0 + w * a, y, w * (b - a), 1), Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.8))


func _draw_loading(vs: Vector2) -> void:
	var acc := UiKit.ACCENT
	# the emblem as a faint watermark on the right
	var wc := Vector2(vs.x * 0.74, vs.y * 0.44)
	var ws := minf(vs.x, vs.y) * 0.2
	var wp := PackedVector2Array([wc + Vector2(-ws, ws * 0.78), wc + Vector2(0, -ws * 0.82), wc + Vector2(ws, ws * 0.78), wc + Vector2(-ws, ws * 0.78)])
	draw_polyline(wp, Color(0.87, 0.8, 0.63, 0.05), 6.0, true)
	draw_circle(wc + Vector2(0, ws * 0.2), ws * 0.2, Color(0.84, 0.32, 0.24, 0.05))
	var m := Vector2(maxf(64.0, vs.x * 0.06), maxf(56.0, vs.y * 0.09))
	# the emblem and the operation
	_emblem(m + Vector2(14, 14), 14.0)
	UiKit.text(self, m + Vector2(44, 22), "FRONTLINE", 15, Color(0.93, 0.9, 0.82), 700)
	UiKit.text(self, m + Vector2(0, 92), _title, 42, Color(0.95, 0.93, 0.86), 700)
	draw_rect(Rect2(m + Vector2(0, 110), Vector2(minf(560.0, vs.x * 0.42), 2)), Color(acc.r, acc.g, acc.b, 0.9))
	# the briefing lines
	var y := m.y + 150.0
	for l in _lines:
		UiKit.text(self, Vector2(m.x, y), String(l[0]), 12, Color(acc.r, acc.g, acc.b, 0.85), 700)
		UiKit.text(self, Vector2(m.x + 130, y), String(l[1]), 16, Color(0.9, 0.9, 0.86), 500)
		y += 30.0
	if _story != "":
		# the briefing, as the commander reads it out
		y += 10.0
		UiKit.text(self, Vector2(m.x, y), "BRIEFING", 12, Color(acc.r, acc.g, acc.b, 0.85), 700)
		_wrap(_story, Vector2(m.x + 130, y), minf(620.0, vs.x * 0.46), 15, Color(0.86, 0.86, 0.82))
	# the tip, in a panel at the bottom left (a mission's briefing takes its place)
	if _story == "":
		var tw := minf(640.0, vs.x * 0.45)
		var tr := Rect2(Vector2(m.x, vs.y - m.y - 170), Vector2(tw, 74))
		draw_rect(tr, Color(0, 0, 0, 0.42))
		draw_rect(Rect2(tr.position, Vector2(3, tr.size.y)), acc)
		UiKit.text(self, tr.position + Vector2(18, 24), "FIELD NOTE", 11, Color(acc.r, acc.g, acc.b, 0.9), 700)
		_wrap(_tip, tr.position + Vector2(18, 46), tw - 36, 15, Color(0.88, 0.88, 0.84))
	# progress: the stage and a bar along the bottom
	var by := vs.y - m.y - 40
	var bw := vs.x - m.x * 2.0
	UiKit.text(self, Vector2(m.x, by - 14), _stage.to_upper(), 12, Color(0.85, 0.85, 0.8), 700)
	UiKit.text(self, Vector2(m.x + bw - 60, by - 14), "%3d%%" % int(_shown_progress * 100.0), 12, Color(0.85, 0.85, 0.8), 700)
	draw_rect(Rect2(m.x, by, bw, 2), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(m.x, by, bw * _shown_progress, 2), acc)
	# a small working indicator: three ticks pulsing in turn
	for i in 3:
		var p := 0.35 + 0.65 * maxf(0.0, sin(_t * 5.0 - i * 0.9))
		draw_rect(Rect2(m.x + bw - 90 + i * 9, by - 21, 5, 5), Color(acc.r, acc.g, acc.b, p))


func _emblem(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s, s * 0.78), c + Vector2(0, -s * 0.82), c + Vector2(s, s * 0.78), c + Vector2(-s, s * 0.78)])
	draw_polyline(pts, Color(0.87, 0.8, 0.63), 2.5, true)
	draw_circle(c + Vector2(0, s * 0.2), s * 0.2, Color(0.84, 0.32, 0.24))


func _wrap(text: String, p: Vector2, w: float, fs: int, col: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := p.y
	for wd in words:
		var trial := wd if line == "" else line + " " + wd
		if UiKit.text_width(trial, fs, 400) > w and line != "":
			UiKit.text(self, Vector2(p.x, y), line, fs, col, 400)
			y += fs + 6
			line = wd
		else:
			line = trial
	if line != "":
		UiKit.text(self, Vector2(p.x, y), line, fs, col, 400)
