class_name HudToasts
extends Control
## The log, top right (docs/UI.md, Log): the newest messages on the right
## scrim, a line each: the time in mono, who it's from, what it says. Alerts
## step up in three levels: a notice is just a line; a caution is a line ruled
## off in yellow that flickers on once; a warning is ruled off in red and
## flickers on twice. Older lines wait in the message history (L).

const LIFE := 7.0  # seconds a line stays (alerts and intel longer)
const TIME_W := 46.0
const FROM_W := 92.0
const MERGE_S := 4.0  # how soon the same report from another unit joins the line already up

var hud: Hud
var items: Array = []  # [kind, text, age, life, time stamp(, who, what: a merged report)]


func push(kind: String, text: String) -> void:
	for it in items:
		if it[1] == text:
			it[2] = 0.0
			queue_redraw()
			return
	# several units reporting the same thing at once ("Bravo 1 is moving out of
	# the shellfire", then Charlie 1, then Delta 1) is one event: say it once,
	# naming them, rather than filling the log with the same line
	var said := _subject_split(text)
	if not said.is_empty():
		for it in items:
			if it[0] == kind and float(it[2]) < MERGE_S and it.size() > 5 and String(it[6]) == String(said[1]):
				var who: Array = it[5]
				if not String(said[0]) in who:
					who.append(String(said[0]))
				it[1] = _joined(who, String(said[1]))
				it[2] = 0.0
				queue_redraw()
				return
	var t := hud.world.time if hud and hud.world else 0.0
	var item := [kind, text, 0.0, 10.0 if kind in ["alert", "intel", "warn"] else LIFE, t]
	if not said.is_empty():
		item.append([String(said[0])])
		item.append(String(said[1]))
	items.push_front(item)
	if items.size() > 6:
		items.pop_back()
	queue_redraw()


func tick(dt: float) -> void:
	var changed := false
	for i in range(items.size() - 1, -1, -1):
		# Between arrival and departure the log's drawing stays unchanged.
		changed = changed or items[i][2] < 0.24 or items[i][2] + dt >= items[i][3] - 0.15
		items[i][2] += dt
		if items[i][2] > items[i][3]:
			items.remove_at(i)
	if changed:
		queue_redraw()


## "Bravo 1 is moving out of the shellfire." as [who, what it's doing], or []
## when the line isn't a unit saying what it is doing.
static func _subject_split(text: String) -> Array:
	var i := text.find(" is ")
	if i <= 0 or i > 28 or text.find(": ") >= 0:
		return []
	return [text.substr(0, i), text.substr(i + 4)]


## Several units doing the same thing, in a line: "Bravo 1 and Charlie 1 are
## …", "Bravo 1, Charlie 1 and Delta 1 are …", "Bravo 1, Charlie 1 +3 are …".
static func _joined(who: Array, what: String) -> String:
	if who.size() == 1:
		return "%s is %s" % [who[0], what]
	if who.size() == 2:
		return "%s and %s are %s" % [who[0], who[1], what]
	if who.size() == 3:
		return "%s, %s and %s are %s" % [who[0], who[1], who[2], what]
	return "%s, %s +%d are %s" % [who[0], who[1], who.size() - 2, what]


## Who a message is from, and what it says: "Bravo 1: Contact east" splits at
## the colon; the rest are signed by what they are.
static func _split(kind: String, text: String) -> Array:
	var c := text.find(": ")
	if c > 0 and c <= 22 and kind in ["chat", "radio", "info", "intel", "ping"]:
		return [text.substr(0, c), text.substr(c + 2)]
	var from: String = {"system": "HQ", "info": "HQ", "radio": "Radio", "intel": "Intel", "ping": "Ping", "chat": "Chat", "warn": "▲ Caution", "alert": "▲ Warning"}.get(kind, "HQ")
	return [from, text]


func _draw() -> void:
	var started := Time.get_ticks_usec()
	_draw_content()
	if hud and hud.world:
		hud.world.vp("notification drawing", started)


func _draw_content() -> void:
	var y := 0.0
	var w := size.x
	for it in items:
		var kind: String = it[0]
		var age: float = it[2]
		# arrive at once, leave quickly; an alert flickers as it lands
		var a := clampf((float(it[3]) - age) / 0.15, 0.0, 1.0)
		var flick := 2 if kind == "alert" else (1 if kind == "warn" else 0)
		if not UiMotion.reduced() and age < flick * 0.12 and fmod(age, 0.12) >= 0.06:
			a = 0.0
		var parts := _split(kind, String(it[1]))
		var level := kind in ["alert", "warn"]
		var lc: Color = UiKit.BAD if kind == "alert" else (UiKit.WARN if kind == "warn" else UiKit.ACCENT)
		var lines := MapSymbols.wrap(String(parts[1]), 13, 400, w - TIME_W - FROM_W - 8.0)
		var h := 6.0 + lines.size() * 17.0 + (6.0 if level else 0.0)
		if y > 0.0 and y + h > size.y:
			break  # out of room (the orders are below): the older ones wait in the log (L)
		if a > 0.0:
			var by := y + (3.0 if level else 0.0)
			if level:
				draw_line(Vector2(0, y + 0.5), Vector2(w, y + 0.5), UiKit.fa(lc, 0.45 * a), 1.0)
				draw_line(Vector2(0, y + h - 0.5), Vector2(w, y + h - 0.5), UiKit.fa(lc, 0.45 * a), 1.0)
			var t := int(it[4])
			UiKit.mono_at(self, Vector2(0, by + 15), "%02d:%02d" % [t / 60, t % 60], 12, UiKit.fa(lc if level else UiKit.DIM, a))
			var from := String(parts[0])
			var fc := lc if level or kind != "chat" else UiKit.TEXT
			if kind == "system":
				fc = UiKit.DIM
			var fw := UiKit.caps_w(from, 12)
			while from.length() > 3 and fw > FROM_W - 6.0:
				from = from.substr(0, from.length() - 2)
				fw = UiKit.caps_w(from, 12)
			UiKit.caps_at(self, Vector2(TIME_W, by + 15), from, 12, UiKit.fa(fc, a))
			var ly := by + 15.0
			var tc: Color = lc if level else (Hud.MSG_COLORS.get(kind, UiKit.TEXT) if kind in ["intel", "ping"] else UiKit.TEXT)
			for ln in lines:
				UiKit.text_f(self, UiKit.font(400 if not level else 500), Vector2(TIME_W + FROM_W, ly), String(ln), 13, UiKit.fa(tc, a))
				ly += 17.0
		y += h + 4.0
