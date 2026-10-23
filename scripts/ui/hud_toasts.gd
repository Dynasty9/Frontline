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

var hud: Hud
var items: Array = []  # [kind, text, age, life, time stamp]


func push(kind: String, text: String) -> void:
	for it in items:
		if it[1] == text:
			it[2] = 0.0
			queue_redraw()
			return
	var t := hud.world.time if hud and hud.world else 0.0
	items.push_front([kind, text, 0.0, 10.0 if kind in ["alert", "intel", "warn"] else LIFE, t])
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
			UiKit.mono_at(self, Vector2(0, by + 15), "%02d:%02d" % [t / 60, t % 60], 12, UiKit.fa(lc if level else UiKit.FAINT, a))
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
