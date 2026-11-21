class_name HudToasts
extends Control
## The log, top right (docs/UI.md, Log): the newest messages on the right
## scrim, a line each: the time in mono, who it's from, what it says. Alerts
## step up in three levels: a notice is just a line; a caution is a line ruled
## off in yellow that flickers on once; a warning is ruled off in red and
## flickers on twice. Only a few lines at once, and briefly: the same news
## again (another truck lost, another strongpoint knocked down) updates its
## line and counts rather than stacking up, routine news (a squad trained, a
## building finished) passes quickest, and the radio is heard on the command
## net instead (HudRadio). Older lines wait in the message history (L).

const LIFE := 5.0  # seconds a line stays (alerts and intel longer, routine news shorter)
const LIFE_LOUD := 8.0
const LIFE_ROUTINE := 3.5
const MAX_LINES := 3
const TIME_W := 46.0
const FROM_W := 92.0
const MERGE_S := 4.0  # how long after a unit's report another unit's same report joins its line
const MERGE_KINDS := ["info", "alert", "warn"]  # units' reports (not players' comings and goings, nor chat)

var hud: Hud
var items: Array = []  # [kind, text, age, life, time stamp, template, count, who, what, grouping age]


## The same news again, whatever the numbers and places in it: "The supply
## truck from Ruvel was destroyed at E6 with 120 supply aboard!" and the next
## one are one line.
static func template_of(text: String) -> String:
	var out := ""
	var digit := false
	for c in text:
		if c >= "0" and c <= "9":
			if not digit:
				out += "#"
			digit = true
		else:
			out += c
			digit = false
	return out


## News the commander needn't stop for: something he ordered is ready.
static func routine(kind: String, text: String) -> bool:
	return kind in ["info", "system"] and (text.ends_with(" ready.") or text.ends_with(" completed.") or text.begins_with("Research complete") or text.ends_with("are standing by."))


func push(kind: String, text: String) -> void:
	var tpl := template_of(text)
	# several units reporting the same thing at once ("Bravo 1 is moving out of
	# the shellfire", then Charlie 1, then Delta 1) is one event: say it once,
	# naming them, rather than one line each or a bare count
	var said := _subject_split(text) if kind in MERGE_KINDS else []
	if not said.is_empty():
		for it in items:
			if it[0] != kind or float(it[9]) >= MERGE_S or (it[7] as Array).is_empty() or String(it[8]) != String(said[1]):
				continue
			var who: Array = it[7]
			if not String(said[0]) in who:
				who.append(String(said[0]))
				it[1] = _joined(who, String(said[1]))
				it[5] = template_of(String(it[1]))
			it[2] = 0.0
			queue_redraw()
			return
	for it in items:
		# (a message in the chat stands on its own, however often it's said)
		if it[0] == kind and kind != "chat" and (it[1] == text or it[5] == tpl):
			it[6] = int(it[6]) + 1
			it[1] = text
			it[2] = 0.0
			queue_redraw()
			return
	var t := hud.world.time if hud and hud.world else 0.0
	var life := LIFE_LOUD if kind in ["alert", "intel", "warn", "ping"] else (LIFE_ROUTINE if routine(kind, text) else LIFE)
	items.push_front([kind, text, 0.0, life, t, tpl, 1, [String(said[0])] if not said.is_empty() else [], String(said[1]) if not said.is_empty() else "", 0.0])
	if items.size() > MAX_LINES:
		# the oldest goes, unless it's louder than everything newer
		var drop := items.size() - 1
		if items[drop][0] in ["alert", "warn"]:
			for i in range(items.size() - 1, 0, -1):
				if not items[i][0] in ["alert", "warn"]:
					drop = i
					break
		items.remove_at(drop)
	queue_redraw()


func tick(dt: float) -> void:
	var changed := false
	for i in range(items.size() - 1, -1, -1):
		# Between arrival and departure the log's drawing stays unchanged.
		changed = changed or items[i][2] < 0.24 or items[i][2] + dt >= items[i][3] - 0.15
		items[i][2] += dt
		items[i][9] += dt
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
		if int(it[6]) > 1:
			parts[1] = String(parts[1]) + "  ×%d" % int(it[6])
		if routine(kind, String(it[1])):
			a *= 0.7
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
