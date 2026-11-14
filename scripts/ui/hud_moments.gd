class_name HudMoments
extends Control
## The battle's turning points, top centre under the status line (docs/UI.md,
## Moments): an enemy vehicle burning, a squad wiped out, a town or a FOB
## changing hands. One line each, in mono capitals, the good news in green and
## the bad in red, between corner ticks: a display's notice, not a fanfare.
## Each stays a few seconds; the newest carries the jump key, and a click on a
## line takes the camera there. The same news, worded for the log, comes in on
## the radio as before.

const LIFE := 6.0  # seconds a moment stays
const MAX := 2  # lines at once (the oldest gives way)
const LINE_H := 24.0
const GAP := 4.0

var hud: Hud
var items: Array = []  # [tone, text, pos, age, count]
var _rects: Array = []  # [Rect2, pos]: each line as drawn, to click


func push(tone: String, text: String, pos) -> void:
	for it in items:
		if it[1] == text:
			# the same again while it's up (two trucks in one ambush): counted, not repeated
			it[3] = 0.0
			it[4] = int(it[4]) + 1
			it[2] = pos
			queue_redraw()
			return
	items.push_front([tone, text, pos, 0.0, 1])
	if items.size() > MAX:
		items.pop_back()
	visible = true
	queue_redraw()


func tick(dt: float) -> void:
	if items.is_empty():
		return
	for i in range(items.size() - 1, -1, -1):
		items[i][3] += dt
		if float(items[i][3]) > LIFE:
			items.remove_at(i)
	visible = not items.is_empty()
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for r in _rects:
			if (r[0] as Rect2).has_point(ev.position) and r[1] is Vector3 and hud.world.cam:
				hud.world.cam.glide_to(r[1])
				accept_event()
				return


## A point is on a line (the rest of the strip lets clicks through to the battlefield).
func _has_point(p: Vector2) -> bool:
	for r in _rects:
		if (r[0] as Rect2).has_point(p):
			return true
	return false


func _draw() -> void:
	_rects.clear()
	var y := 0.0
	var jump := Keys.label("jump_alert").to_upper()
	for i in items.size():
		var it: Array = items[i]
		var tone: String = it[0]
		var age: float = it[3]
		var a := clampf((LIFE - age) / 0.4, 0.0, 1.0)
		# it lands with one flicker, like a caution in the log
		if not UiMotion.reduced() and age < 0.12 and fmod(age, 0.12) >= 0.06:
			a = 0.0
		var col := UiKit.GOOD if tone == "gain" else UiKit.BAD
		var text := String(it[1]).to_upper()
		if int(it[4]) > 1:
			text += "  ×%d" % int(it[4])
		var grid := Defs.grid_ref(it[2]) if it[2] is Vector3 else ""
		var hint := ("[%s]" % jump) if i == 0 and jump != "" and grid != "" else ""
		var tw := UiKit.mono_w(text, 13)
		var gw := (14.0 + UiKit.mono_w(grid, 12)) if grid != "" else 0.0
		var hw := (14.0 + UiKit.mono_w(hint, 11)) if hint != "" else 0.0
		var w := 14.0 + tw + gw + hw + 14.0
		var r := Rect2((size.x - w) * 0.5, y, w, LINE_H)
		_rects.append([r, it[2]])
		if a > 0.0:
			draw_rect(r, UiKit.fa(UiKit.INK, 0.72 * a))
			UiKit.ticks(self, r, UiKit.fa(col, a), 6.0, 0.0)
			var x := r.position.x + 14.0
			x += UiKit.mono_at(self, Vector2(x, y + 17), text, 13, UiKit.fa(col, a))
			if grid != "":
				x += 14.0 + UiKit.mono_at(self, Vector2(x + 14.0, y + 17), grid, 12, UiKit.fa(UiKit.DIM, a))
			if hint != "":
				UiKit.mono_at(self, Vector2(x + 14.0, y + 17), hint, 11, UiKit.fa(UiKit.FAINT, a))
		y += LINE_H + GAP
