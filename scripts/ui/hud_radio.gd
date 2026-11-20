class_name HudRadio
extends Control
## The command net: what comes over the radio (the XO's reports, the
## mission's traffic, another commander's orders), heard one transmission
## at a time as a subtitle low in the middle of the screen, the way a
## commander hears it in his headset, rather than piled up with the alerts
## in the corner. A burst of squelch opens each one; the line types on, holds
## while it's read, and is gone. Everything said stays in the message
## history (L).

const HOLD_MIN := 3.2  # seconds a transmission stays at the least
const READ_CPS := 22.0  # ...and longer ones as long as they take to read
const TYPE_CPS := 90.0  # how fast a line types on
const WIDTH := 720.0
const QUEUE_MAX := 4  # older traffic waits in the history instead

var hud: Hud
var _queue: Array = []  # [from, text, priority]
var _cur: Array = []
var _age := 0.0
var _hold := 0.0


## A message of kind "radio" (or anything else meant for the net): "Bravo 1:
## Contact east" is heard from Bravo 1.
func push(text: String) -> void:
	var parts := HudToasts._split("radio", text)
	# the same thing said again just keeps it on (a repeated report)
	if not _cur.is_empty() and String(_cur[1]) == String(parts[1]):
		_age = minf(_age, 0.5)
		return
	for q in _queue:
		if String(q[1]) == String(parts[1]):
			return
	_queue.append([String(parts[0]), String(parts[1])])
	if _queue.size() > QUEUE_MAX:
		_queue.pop_front()


func tick(dt: float) -> void:
	if _cur.is_empty():
		if _queue.is_empty():
			return
		_cur = _queue.pop_front()
		_age = 0.0
		_hold = maxf(HOLD_MIN, String(_cur[1]).length() / READ_CPS)
		# hurry along when there's more waiting
		if not _queue.is_empty():
			_hold = maxf(HOLD_MIN * 0.7, _hold * 0.75)
		Sfx.ui("squelch", -12.0)
		queue_redraw()
		return
	_age += dt
	if _age > _hold + 0.25:
		_cur = []
		queue_redraw()
	elif _age < String(_cur[1]).length() / TYPE_CPS + 0.05 or _age > _hold - 0.05:
		queue_redraw()


func busy() -> bool:
	return not _cur.is_empty()


func _draw() -> void:
	if _cur.is_empty():
		return
	var from := String(_cur[0]).to_upper()
	var text := String(_cur[1])
	var a := clampf((_hold + 0.25 - _age) / 0.25, 0.0, 1.0)
	var shown := mini(text.length(), int(_age * TYPE_CPS))
	if UiMotion.reduced():
		shown = text.length()
	var lines := MapSymbols.wrap(text, 14, 500, WIDTH - 24.0)
	var cx := size.x * 0.5
	var y := 16.0
	# who's on the net: a live dot, then the callsign, centred over the words
	var fw := UiKit.caps_w(from, 11) + 14.0
	var dot := 0.6 + 0.4 * sin(_age * 9.0)
	draw_circle(Vector2(cx - fw * 0.5 + 3.0, y - 4.0), 3.0, UiKit.fa(UiKit.GOOD, dot * a))
	UiKit.caps_at(self, Vector2(cx - fw * 0.5 + 12.0, y), from, 11, UiKit.fa(UiKit.ACCENT, a))
	y += 20.0
	var left := shown
	for ln in lines:
		var s := String(ln)
		var part := s.substr(0, clampi(left, 0, s.length()))
		left -= s.length() + 1
		var lw := UiKit.text_width(s, 14, 500)
		UiKit.text_f(self, UiKit.font(500), Vector2(cx - lw * 0.5, y), part, 14, UiKit.fa(UiKit.TEXT, a))
		y += 19.0
