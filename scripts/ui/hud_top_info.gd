class_name HudTopInfo
extends Control
## Resources (player) or the balance of forces (observer), top-left.

var hud: Hud

func _draw() -> void:
	var w := hud.world
	var lt := w.local_team
	var mins := int(w.time / 60.0)
	var secs := int(w.time) % 60
	if lt >= 0:
		var ti: Dictionary = w.team_info[lt]
		var items := [["SUPPLY", str(int(ti.get("supply", 0)))], ["UNITS", "%d / %d" % [int(ti.get("units", 0)), int(ti.get("cap", 0))]],
			["FOBS", str((ti.get("fobs", []) as Array).size())], ["", "%d:%02d" % [mins, secs]]]
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
		var mt := hud.mode_text()
		if mt != "":
			var mw := UiKit.text_width(mt, 13) + 28.0
			var vs := get_viewport_rect().size
			var r := Rect2(vs.x * 0.5 - mw * 0.5 - position.x, 0, mw, 32)
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
		UiKit.pill(self, Rect2(0, 0, 360, 76))
		UiKit.text(self, Vector2(14, 22), "%d:%02d" % [mins, secs], 15, UiKit.TEXT, 600)
		UiKit.text(self, Vector2(66, 22), "BATTLE", 11, UiKit.DIM, 600)
		for t in 2:
			var y2 := 44.0 + t * 20.0
			var ti2: Dictionary = w.team_info[t]
			draw_circle(Vector2(16, y2 - 4), 4.5, Defs.TEAM_COLORS[t])
			UiKit.text(self, Vector2(28, y2), Defs.TEAM_NAMES[t], 13, UiKit.TEXT, 600)
			var nf := (ti2.get("fobs", []) as Array).size()
			UiKit.text(self, Vector2(118, y2), "%d troops   %d %s   %d %s   %d supply" % [sold[t], veh[t], "vehicle" if veh[t] == 1 else "vehicles", nf, "FOB" if nf == 1 else "FOBs", int(ti2.get("supply", 0))], 12, UiKit.DIM)
		# strength bar
		var s0 := float(sold[0] + veh[0] * 4) + 0.01
		var s1 := float(sold[1] + veh[1] * 4) + 0.01
		var bw := 230.0
		var k := s0 / (s0 + s1)
		draw_rect(Rect2(118, 10, bw * k, 6), Defs.TEAM_COLORS[0])
		draw_rect(Rect2(118 + bw * k, 10, bw * (1.0 - k), 6), Defs.TEAM_COLORS[1])
