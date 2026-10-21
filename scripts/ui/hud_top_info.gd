class_name HudTopInfo
extends Control
## Resources (player) or the balance of forces (observer), top-left.

## The observer's balance-of-forces box.
const OBS_W := 420.0  # (wide enough for the towns each side holds)
const OBS_H := 76.0

var hud: Hud
var content_h := 80.0  # how far down the FOB and town lines reach (the order of battle goes below)
var _towns_n := 0
var _towns_t := -1.0


## How many towns and villages the map has (counted now and then: they
## arrive with the rest of the map, and never go away).
func _town_count(w: World) -> int:
	if w.time > _towns_t:
		_towns_t = w.time + 5.0
		_towns_n = 0
		for st in w.sim_structures:
			if st.skind == "town":
				_towns_n += 1
	return _towns_n


## A little flag on its pole, for a town.
func _flag_mark(p: Vector2, c: Color) -> void:
	draw_line(p, p + Vector2(0, 11), UiKit.DIM, 1.0)
	draw_rect(Rect2(p + Vector2(1, 0), Vector2(6, 4)), c)


## A FOB's or a town's supply state, as a code.
func _code(s: String) -> String:
	match s:
		"Truck en route":
			return "TRUCK ON ROAD"
		"No FOB":
			return "NO FOB"
		"No road":
			return "NO ROAD"
		"Truck destroyed":
			return "TRUCK LOST"
		"Road blocked":
			return "ROAD BLOCKED"
	return s.to_upper()


# The status line (docs/UI.md, Status): the side, then a label and a mono
# figure per item between short rules, ending with the battle's clock. No
# box: it sits on the top scrim.
func _caps(x: float, y: float, t: String, size: int, col: Color) -> float:
	var f := UiKit.cond(600, 1)
	UiKit.text_f(self, f, Vector2(x, y), t.to_upper(), size, col)
	return UiFx.width(f, t.to_upper(), size)


func _mono(x: float, y: float, t: String, size: int, col: Color) -> float:
	var f := UiKit.mono()
	UiKit.text_f(self, f, Vector2(x, y), t, size, col)
	return UiFx.width(f, t, size)


func _sep(x: float) -> float:
	draw_rect(Rect2(x, 10, 1, 12), UiKit.RULE2)
	return 1.0


func _draw() -> void:
	var w := hud.world
	var lt := w.local_team
	var mins := int(w.time / 60.0)
	var secs := int(w.time) % 60
	var clock := "T+%02d:%02d" % [mins, secs]
	if lt >= 0:
		var ti: Dictionary = w.team_info[lt]
		var tl: Array = ti.get("towns", [])
		var x := 0.0
		var y0 := 22.0
		draw_rect(Rect2(0, 12, 7, 7), Defs.TEAM_COLORS[lt])
		x = 13.0 + _caps(13.0, y0, Defs.TEAM_NAMES[lt], 13, UiKit.TEXT) + 14.0
		var items := [["Sup", str(int(ti.get("supply", 0))), ("+%d/M" % int(ti.get("inc", 0))) if w.mission_info.is_empty() else ""],
			["Units", "%d/%d" % [int(ti.get("units", 0)), int(ti.get("cap", 0))], ""],
			["FOB", str((ti.get("fobs", []) as Array).size()), ""]]
		if _town_count(w) > 0:
			items.append(["Towns", "%d/%d" % [tl.size(), _town_count(w)], ""])
		for it in items:
			x += _sep(x) + 14.0
			x += _caps(x, y0, it[0], 11, UiKit.FAINT) + 6.0
			x += _mono(x, y0 + 1, it[1], 15, UiKit.TEXT)
			if it[2] != "":
				x += 6.0 + _mono(x + 6.0, y0 + 1, it[2], 12, UiKit.GOOD if int(ti.get("inc", 0)) > 0 else UiKit.FAINT)
			x += 14.0
		x += _sep(x) + 14.0
		var wtot := x + _mono(x, y0 + 1, clock, 15, UiKit.TEXT)
		# FOB lines: quiet unless something is wrong
		var y := 50.0
		var fw := 0.0  # the widest FOB line (the towns go in a column beside them)
		for f in ti.get("fobs", []):
			var stx: String = f[3]
			var ok := stx == "OK" or stx == "Truck en route"
			var c := UiKit.GOOD if stx == "OK" else (UiKit.WARN if ok else UiKit.BAD)
			draw_rect(Rect2(0, y - 8, 5, 5), c)
			var lw := 12.0 + _caps(12.0, y, String(f[1]), 12, UiKit.TEXT if ok else UiKit.BAD)
			lw += 8.0 + _mono(lw + 8.0, y, str(int(f[2])), 12, UiKit.DIM)
			if not ok or stx == "Truck en route":
				lw += 10.0 + _mono(lw + 10.0, y, _code(stx), 11, c)
			fw = maxf(fw, lw)
			y += 17.0
		var fob_y := y
		# the towns we hold: what each gives, what's waiting in its dump, and
		# whether its trucks are getting through, in a column beside the FOBs. One
		# the enemy is moving into, or whose trucks aren't getting through, gets a
		# line of its own; the quiet ones are summed up in one line once there are
		# more than a couple, so the order of battle below keeps its room.
		var tx := fw + 26.0 if fw > 0.0 else 0.0
		y = 50.0
		var rows := []
		var summed := []
		for tn in tl:
			var st0 = w.entity(int(tn[0]))
			var bad: bool = (st0 is Structure and st0.cap_team >= 0 and st0.cap_team != lt and st0.cap_prog > 0.0) or not String(tn[3]) in ["OK", "Truck en route"]
			if bad and rows.size() < 3:
				rows.append(tn)
			else:
				summed.append(tn)
		if rows.size() + summed.size() <= 2:
			rows.append_array(summed)
			summed.clear()
		for tn: Array in rows:
			var tst: String = tn[3]
			var tok := tst == "OK" or tst == "Truck en route"
			var st = w.entity(int(tn[0]))
			var taking: bool = st is Structure and st.cap_team >= 0 and st.cap_team != lt and st.cap_prog > 0.0
			_flag_mark(Vector2(tx, y - 10), Defs.TEAM_COLORS[lt])
			var lx := tx + 13.0 + _caps(tx + 13.0, y, String(tn[1]), 12, UiKit.TEXT if tok and not taking else UiKit.BAD)
			lx += 8.0 + _mono(lx + 8.0, y, "%d +%d/M" % [int(tn[2]), int(tn[4])], 12, UiKit.DIM)
			var note := ""
			var nc := UiKit.FAINT
			if taking:
				note = "BEING TAKEN %d%%" % int(st.cap_prog)
				nc = UiKit.BAD
			elif tst == "OK":
				note = ("TO " + String(tn[5]).to_upper()) if String(tn[5]) != "" else ""
			else:
				note = _code(tst)
				nc = UiKit.WARN if tok else UiKit.BAD
			_mono(lx + 10.0, y, note, 11, nc)
			y += 17.0
		if not summed.is_empty():
			var s_inc := 0
			var s_stock := 0
			for tn in summed:
				s_inc += int(tn[4])
				s_stock += int(tn[2])
			_flag_mark(Vector2(tx, y - 10), Defs.TEAM_COLORS[lt])
			var lx2 := tx + 13.0 + _caps(tx + 13.0, y, "%d %stowns" % [summed.size(), "more " if not rows.is_empty() else ""], 12, UiKit.TEXT)
			_mono(lx2 + 8.0, y, "%d +%d/M" % [s_stock, s_inc], 12, UiKit.DIM)
			y += 17.0
		content_h = maxf(y, fob_y) - 12.0
		var mt := hud.mode_text()
		if mt != "":
			# the mode the cursor is in (placing, a fire mission): the active
			# thing on screen, so it takes the accent's corner ticks
			var mw := UiKit.text_width(mt, 13) + 24.0
			var vs := get_viewport_rect().size
			var r := Rect2(vs.x * 0.5 - mw * 0.5 - position.x, 2, mw, 26)
			if r.position.x < wtot + 10.0:
				# a narrow screen: under the bar, or under the objectives if it would cover them
				r.position.y = 42.0
				if hud.objectives.visible and r.end.x > vs.x - HudObjectives.W - 24.0 - position.x:
					r.position.y = hud.objectives.need_h + 22.0 - position.y
			draw_rect(r, UiKit.fa(UiKit.INK, 0.8))
			UiKit.ticks(self, r, UiKit.ACCENT, 6.0, 3.0)
			UiKit.text(self, r.position + Vector2(12, 18), mt, 13, UiKit.ACCENT)
	else:
		# balance of forces
		var sold := [0, 0]
		var veh := [0, 0]
		for s in w.soldiers:
			if s.life == Soldier.Life.ALIVE and s.team >= 0 and s.team < 2:
				sold[s.team] += 1
		for v in w.vehicles:
			if v.team >= 0 and v.team < 2:
				veh[v.team] += 1
		var x0 := _caps(0, 22, "Battle", 11, UiKit.FAINT) + 8.0
		_mono(x0, 23, clock, 15, UiKit.TEXT)
		for t in 2:
			var y2 := 46.0 + t * 19.0
			var ti2: Dictionary = w.team_info[t]
			draw_rect(Rect2(0, y2 - 8, 7, 7), Defs.TEAM_COLORS[t])
			_caps(13, y2, Defs.TEAM_NAMES[t], 12, UiKit.TEXT)
			var nf := (ti2.get("fobs", []) as Array).size()
			var nt := (ti2.get("towns", []) as Array).size()
			_mono(110, y2, "%d TRP  %d VEH  %d FOB  %d TWN  %d SUP" % [sold[t], veh[t], nf, nt, int(ti2.get("supply", 0))], 12, UiKit.DIM)
		# the balance, counted: 40 steps split between the sides
		var s0 := float(sold[0] + veh[0] * 4) + 0.01
		var s1 := float(sold[1] + veh[1] * 4) + 0.01
		var n0 := roundi(40.0 * s0 / (s0 + s1))
		for i in 40:
			draw_rect(Rect2(110 + i * 7.0, 13, 5, 8), Defs.TEAM_COLORS[0] if i < n0 else Defs.TEAM_COLORS[1])
