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
		for st in w.structures:
			if st.skind == "town":
				_towns_n += 1
	return _towns_n


## A little flag on its pole, for a town.
func _flag_mark(p: Vector2, c: Color) -> void:
	draw_line(p, p + Vector2(0, 12), Color(0.85, 0.85, 0.8), 1.2)
	draw_rect(Rect2(p + Vector2(0.6, 0), Vector2(7, 5)), c)


func _town_status(s: String) -> String:
	match s:
		"Truck en route":
			return "truck on the road"
		"No FOB":
			return "no FOB to supply"
		"No road":
			return "no road to a FOB"
		"Truck destroyed":
			return "truck destroyed"
		"Road blocked":
			return "road blocked"
	return s.to_lower()

func _draw() -> void:
	var w := hud.world
	var lt := w.local_team
	var mins := int(w.time / 60.0)
	var secs := int(w.time) % 60
	if lt >= 0:
		var ti: Dictionary = w.team_info[lt]
		var tl: Array = ti.get("towns", [])
		var sup := str(int(ti.get("supply", 0)))
		if w.mission_info.is_empty():
			sup += "  +%d/min" % int(ti.get("inc", 0))  # (a mission's supply is a fixed stock)
		var items := [["SUPPLY", sup], ["UNITS", "%d / %d" % [int(ti.get("units", 0)), int(ti.get("cap", 0))]],
			["FOBS", str((ti.get("fobs", []) as Array).size())]]
		if _town_count(w) > 0:
			items.append(["TOWNS", "%d / %d" % [tl.size(), _town_count(w)]])
		items.append(["", "%d:%02d" % [mins, secs]])
		var x := 0.0
		var tc: Color = Defs.TEAM_COLORS[lt]
		var wtot := 28.0 + UiKit.text_width(Defs.TEAM_NAMES[lt].to_upper(), 13, 600)
		for it in items:
			wtot += 22.0 + UiKit.text_width(it[0], 11, 600) + 6.0 + UiKit.text_width(it[1], 15, 600)
		UiKit.pill(self, Rect2(0, 0, wtot, 34))
		draw_circle(Vector2(16, 17), 5.0, tc)
		x = 28.0
		UiKit.text(self, Vector2(x, 22), Defs.TEAM_NAMES[lt].to_upper(), 13, UiKit.TEXT, 600)
		x += UiKit.text_width(Defs.TEAM_NAMES[lt].to_upper(), 13, 600) + 22.0
		for it in items:
			if it[0] != "":
				UiKit.text(self, Vector2(x, 22), it[0], 11, UiKit.DIM, 600)
				x += UiKit.text_width(it[0], 11, 600) + 6.0
			UiKit.text(self, Vector2(x, 23), it[1], 15, UiKit.TEXT, 600)
			x += UiKit.text_width(it[1], 15, 600) + 22.0
		# FOB lines: quiet unless something is wrong
		var y := 52.0
		for f in ti.get("fobs", []):
			var stx: String = f[3]
			var ok := stx == "OK" or stx == "Truck en route"
			var c := UiKit.GOOD if stx == "OK" else (UiKit.WARN if ok else UiKit.BAD)
			draw_circle(Vector2(8, y - 4), 3.5, c)
			UiKit.text(self, Vector2(18, y), "%s  %d" % [f[1], int(f[2])], 12, UiKit.TEXT if ok else UiKit.BAD)
			if not ok or stx == "Truck en route":
				UiKit.text(self, Vector2(26 + UiKit.text_width("%s  %d" % [f[1], int(f[2])], 12), y), stx, 12, c)
			y += 17.0
		# the towns we hold: what each gives, what's waiting in its dump, and
		# whether its trucks are getting through (or the enemy's moving in) -
		# the ones in trouble first, the quiet ones summed up past a few
		var rows := []
		for tn in tl:
			var st0 = w.entity(int(tn[0]))
			var bad: bool = (st0 is Structure and st0.cap_team >= 0 and st0.cap_team != lt and st0.cap_prog > 0.0) or not String(tn[3]) in ["OK", "Truck en route"]
			if bad:
				rows.insert(0, tn)
			else:
				rows.append(tn)
		var rest := 0
		var rest_inc := 0
		for i in rows.size():
			var tn: Array = rows[i]
			if i >= 4 and rows.size() > 5:
				rest += 1
				rest_inc += int(tn[4])
				continue
			var tst: String = tn[3]
			var tok := tst == "OK" or tst == "Truck en route"
			var st = w.entity(int(tn[0]))
			var taking: bool = st is Structure and st.cap_team >= 0 and st.cap_team != lt and st.cap_prog > 0.0
			_flag_mark(Vector2(5, y - 10), Defs.TEAM_COLORS[lt])
			var line := "%s  %d  +%d/min" % [tn[1], int(tn[2]), int(tn[4])]
			UiKit.text(self, Vector2(18, y), line, 12, UiKit.TEXT if tok and not taking else UiKit.BAD)
			var note := ""
			var nc := UiKit.DIM
			if taking:
				note = "Being taken! %d%%" % int(st.cap_prog)
				nc = UiKit.BAD
			elif tst == "OK":
				note = ("to FOB " + String(tn[5])) if String(tn[5]) != "" else ""
			else:
				note = _town_status(tst)
				nc = UiKit.WARN if tok else UiKit.BAD
			UiKit.text(self, Vector2(26 + UiKit.text_width(line, 12), y), note, 12, nc)
			y += 17.0
		if rest > 0:
			_flag_mark(Vector2(5, y - 10), Defs.TEAM_COLORS[lt])
			UiKit.text(self, Vector2(18, y), "%d more towns  +%d/min" % [rest, rest_inc], 12, UiKit.DIM)
			y += 17.0
		content_h = y - 12.0
		var mt := hud.mode_text()
		if mt != "":
			var mw := UiKit.text_width(mt, 13) + 28.0
			var vs := get_viewport_rect().size
			var r := Rect2(vs.x * 0.5 - mw * 0.5 - position.x, 0, mw, 32)
			if r.position.x < wtot + 10.0:
				# a narrow screen: under the bar, or under the objectives if it would cover them
				r.position.y = 42.0
				if hud.objectives.visible and r.end.x > vs.x - HudObjectives.W - 24.0 - position.x:
					r.position.y = hud.objectives.need_h + 22.0 - position.y
			UiKit.pill(self, r, Color(0.2, 0.17, 0.08, 0.9), Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.6))
			UiKit.text(self, r.position + Vector2(14, 21), mt, 13, UiKit.ACCENT)
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
		UiKit.pill(self, Rect2(0, 0, OBS_W, OBS_H))
		UiKit.text(self, Vector2(14, 22), "%d:%02d" % [mins, secs], 15, UiKit.TEXT, 600)
		UiKit.text(self, Vector2(66, 22), "BATTLE", 11, UiKit.DIM, 600)
		for t in 2:
			var y2 := 44.0 + t * 20.0
			var ti2: Dictionary = w.team_info[t]
			draw_circle(Vector2(16, y2 - 4), 4.5, Defs.TEAM_COLORS[t])
			UiKit.text(self, Vector2(28, y2), Defs.TEAM_NAMES[t], 13, UiKit.TEXT, 600)
			var nf := (ti2.get("fobs", []) as Array).size()
			var nt := (ti2.get("towns", []) as Array).size()
			UiKit.text(self, Vector2(118, y2), "%d troops   %d %s   %d %s   %d %s   %d supply" % [sold[t], veh[t], "vehicle" if veh[t] == 1 else "vehicles", nf, "FOB" if nf == 1 else "FOBs",
				nt, "town" if nt == 1 else "towns", int(ti2.get("supply", 0))], 12, UiKit.DIM)
		# strength bar
		var s0 := float(sold[0] + veh[0] * 4) + 0.01
		var s1 := float(sold[1] + veh[1] * 4) + 0.01
		var bw := 230.0
		var k := s0 / (s0 + s1)
		draw_rect(Rect2(118, 10, bw * k, 6), Defs.TEAM_COLORS[0])
		draw_rect(Rect2(118 + bw * k, 10, bw * (1.0 - k), 6), Defs.TEAM_COLORS[1])
