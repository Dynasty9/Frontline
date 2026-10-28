class_name HudPointerOverlay
extends HudOverlay
## Cursor feedback redraws independently of the army's cached status counters.

func _draw() -> void:
	var w := hud.world
	var inp := w.input
	if inp == null or w.cam == null:
		return
	var cam := w.cam.cam
	var lt := w.local_team
	if inp.lmb and inp.dragging:
		var r := Rect2(inp.drag_start, Vector2.ZERO).expand(hud.root.get_global_mouse_position())
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.1))
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.75), false, 1.0)
	var mp: Vector2 = inp._mouse()
	if not inp.preview.is_empty():
		_cover_preview(inp, cam, mp)
	if inp.place_kind != "" and inp.ghost_err != "":
		UiKit.caps_at(self, mp + Vector2(18, 26), inp.ghost_err, 12, UiKit.BAD)
	elif inp.ability.begins_with("support:") or inp.ability.begins_with("demo:"):
		_support_preview(inp, mp)
	elif inp.ability != "":
		var lbl := "Grenade"
		match inp.ability:
			"smoke":
				lbl = "Smoke"
			"mortar_he", "pit_he":
				lbl = "Mortar HE"
			"arty_he":
				lbl = "Artillery salvo"
			"mortar_smoke", "pit_smoke":
				lbl = "Mortar smoke"
		_hint(mp, lbl, _grid_at(inp, mp), UiKit.WARN)
	elif inp.place_drag and not inp.line_items.is_empty():
		var ok := 0
		for it in inp.line_items:
			if it[2]:
				ok += 1
		_hint(mp, "%d × %s" % [ok, Defs.BUILDINGS[inp.place_kind].name], "%d SUP" % (ok * int(Defs.BUILDINGS[inp.place_kind].cost)), UiKit.GOOD)
	elif inp.hover and inp.hover.visible and not inp.pinging:
		if inp.has_units() and inp.hover.is_hostile_to(lt):
			_hint(mp, "Attack", "", UiKit.BAD)
		elif inp.hover is Soldier:
			_hover_card(inp.hover as Soldier, mp)
		elif inp.hover is Vehicle:
			_vehicle_card(inp.hover as Vehicle, mp)


## Company of Heroes style cover pips where each man will end up, a facing
## arrow while dragging, and what the ground under the cursor is worth.
func _cover_preview(inp, cam: Camera3D, mp: Vector2) -> void:
	var cols := [Color(1.0, 0.36, 0.3), Color(0.82, 0.82, 0.8), Color(1.0, 0.8, 0.28), Color(0.42, 0.95, 0.45)]
	# fighting positions by what they're made of: soft (hides you), medium, hard, fortified
	var mat_cols := [Color(1.0, 0.8, 0.28), Color(0.74, 0.92, 0.36), Color(0.42, 0.95, 0.45), Color(0.42, 0.95, 0.45)]
	var w := hud.world
	var gp: Vector3 = w.cam.ground_point(inp.rmb_start if inp.rmb else mp)
	var near_info := {}
	var near_d := 3.0
	for sl in inp.preview:
		var p: Vector3 = sl[0] + Vector3(0, 0.12, 0)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		var lvl: int = int(sl[1])
		var info: Dictionary = sl[2] if sl.size() > 2 else {}
		var col: Color = cols[clampi(lvl + 1, 0, 3)]
		if not info.is_empty():
			col = mat_cols[int(info.mat)]
			# a tick towards the barrier: the way he'll face and fire over it
			var tip := cam.unproject_position(p + (info.n as Vector3) * 0.8)
			var tv := (tip - sp).limit_length(17.0)
			draw_line(sp, sp + tv, Color(0, 0, 0, 0.6), 4.5, true)
			draw_line(sp, sp + tv, col, 2.2, true)
			var d := Defs.flat((sl[0] as Vector3) - gp).length()
			if d < near_d:
				near_d = d
				near_info = info
		_shield(sp, col, lvl)
	var face: Vector3 = inp.drag_face()
	if face.length() > 0.1:
		var a := cam.unproject_position(gp + Vector3(0, 0.1, 0))
		var b := cam.unproject_position(gp + face * 7.0 + Vector3(0, 0.1, 0))
		draw_line(a, b, Color(1, 1, 1, 0.85), 2.5, true)
		var dv := (b - a).normalized()
		var nv := Vector2(-dv.y, dv.x)
		MapSymbols.poly(self, PackedVector2Array([b + dv * 8.0, b - dv * 4.0 + nv * 7.0, b - dv * 4.0 - nv * 7.0]), Color(1, 1, 1, 0.9))
	if inp.hover == null or not inp.hover.is_hostile_to(w.local_team):
		var lbl := ""
		match inp.order_mode:
			"assault":
				lbl = "Attack-move · "
			"defend":
				lbl = "Defend · "
		var cs: String = w.terrain.describe(gp, gp + inp.preview_face * 40.0) if w.terrain else ""
		if not near_info.is_empty():
			cs = Cover.describe(near_info)
		var pos: Vector2 = (inp.rmb_start if inp.rmb else mp) + Vector2(18, 44)
		var x := pos.x + UiKit.caps_at(self, pos, lbl, 11, UiKit.ACCENT)
		UiKit.caps_at(self, Vector2(x, pos.y), cs, 11, UiKit.TEXT)


func _shield(c: Vector2, col: Color, lvl: int) -> void:
	if lvl == 0:
		draw_circle(c, 4.0, Color(0, 0, 0, 0.55))
		draw_circle(c, 2.6, Color(col.r, col.g, col.b, 0.85))
		return
	var s := 1.0 if lvl != 1 else 0.85
	var pts := PackedVector2Array([c + Vector2(-7, -8) * s, c + Vector2(7, -8) * s, c + Vector2(7, 0) * s, c + Vector2(0, 8) * s, c + Vector2(-7, 0) * s])
	var outline := PackedVector2Array([c + Vector2(-8.5, -9.5) * s, c + Vector2(8.5, -9.5) * s, c + Vector2(8.5, 0.5) * s, c + Vector2(0, 10) * s, c + Vector2(-8.5, 0.5) * s])
	MapSymbols.poly(self, outline, Color(0, 0, 0, 0.6))
	MapSymbols.poly(self, pts, col)
	if lvl == 2:
		draw_line(c + Vector2(-3.5, -4), c + Vector2(-3.5, 2), Color(0, 0, 0, 0.55), 2.0)
		draw_line(c + Vector2(3.5, -4), c + Vector2(3.5, 2), Color(0, 0, 0, 0.55), 2.0)
	elif lvl == 1:
		draw_line(c + Vector2(0, -4), c + Vector2(0, 2), Color(0, 0, 0, 0.55), 2.0)
	else:
		draw_line(c + Vector2(0, -5), c + Vector2(0, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_circle(c + Vector2(0, 3), 1.2, Color(1, 1, 1, 0.9))


## Where the support will land: rings, the strafing strip or the bombing line,
## the gunship's orbit, and an arrow for the run-in direction; for a recon
## flight, the ground it will see.
func _support_preview(inp, mp: Vector2) -> void:
	var w := hud.world
	var k: String = inp.ability.get_slice(":", 1)
	var sd: Dictionary = Defs.SUPPORT.get(k, {})
	var gp: Vector3 = w.cam.ground_point(inp.ab_start if inp.ab_drag else mp)
	var dir: Vector3 = inp.support_dir()
	var red := Color(1.0, 0.42, 0.3, 0.95)
	var side := dir.cross(Vector3.UP)
	match String(sd.get("shape", "circle")):
		"strafe":
			var a := gp - dir * 20.0
			var b := gp + dir * 20.0
			_ground_poly([a + side * 3.0, b + side * 3.0, b - side * 3.0, a - side * 3.0], red)
			_ground_arrow(gp - dir * 34.0, gp - dir * 22.0, red)
		"line":
			for i in 4:
				_ground_ring(gp + dir * (-15.0 + i * 10.0), 4.0, Color(1.0, 0.7, 0.4, 0.85))
			_ground_arrow(gp - dir * 32.0, gp - dir * 20.0, red)
		"orbit":
			_ground_ring(gp, float(sd.get("r", 38.0)), red)
			_ground_ring(gp, Projectile.AC_R * 0.45, Color(1, 1, 1, 0.25))
		"sweep":
			# the strip a recon pass's camera sees, along its track and on past
			# the spot both ways (as much of it as is in front of the camera)
			var rr := float(sd.get("r", 80.0))
			var ln := 200.0
			while ln > 25.0 and (w.cam.cam.is_position_behind(gp - dir * ln) or w.cam.cam.is_position_behind(gp + dir * ln)):
				ln *= 0.6
			_ground_poly([gp - dir * ln + side * rr, gp + dir * ln + side * rr, gp + dir * ln - side * rr, gp - dir * ln - side * rr], RECON_COL)
			_ground_arrow(gp - dir * 30.0, gp + dir * 12.0, RECON_COL)
		"watch":
			_ground_ring(gp, float(sd.get("r", 80.0)), RECON_COL)
			_ground_ring(gp, Projectile.AC_R * 0.45, Color(1, 1, 1, 0.25))
		_:
			_ground_ring(gp, float(sd.get("r", 14.0)), red)
	var cost := int(sd.get("cost", 0))
	_hint(mp, String(sd.get("name", k)), ("%d SUP" % cost) if inp.ability.begins_with("support:") else "DEMO", UiKit.BAD)


## A cursor hint (docs/UI.md, Codes): what the click will do in capitals, and
## its figure in mono after it.
func _hint(mp: Vector2, what: String, code: String, col: Color) -> void:
	var x := mp.x + 18.0 + UiKit.caps_at(self, mp + Vector2(18, 26), what, 12, col)
	if code != "":
		UiKit.mono_at(self, Vector2(x + 8.0, mp.y + 26), code, 12, UiKit.TEXT)


## The grid square under the cursor, for a hint.
func _grid_at(inp, mp: Vector2) -> String:
	var cam := hud.world.cam.cam
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return ""
	var t := -o.y / d.y
	return Defs.grid_ref(o + d * t) if t > 0.0 else ""


func _hover_card(s: Soldier, mp: Vector2) -> void:
	var nm := s.display_name()
	var sub: String = Defs.TEAM_NAMES[s.team] if s.team >= 0 else ""
	var own := _co_owner(s)
	if own != 0:
		sub += " · Shared control" if s.team == hud.world.local_team else ""
	var act := s.doing_text()
	var ac: Color = Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM)
	match s.life:
		Soldier.Life.DOWNED:
			act = "Wounded · " + act
			ac = UiKit.BAD
		Soldier.Life.DEAD:
			act = "Killed in action"
			ac = UiKit.BAD
	var wd := maxf(UiKit.caps_w(nm, 14) + UiKit.caps_w(sub, 11) + 16.0, UiKit.caps_w(act, 11)) + 24.0
	wd = maxf(wd, 176.0)
	var r := Rect2(mp + Vector2(24, 24), Vector2(wd, 64.0 if act != "" else 48.0))
	_card(r)
	UiKit.caps_at(self, r.position + Vector2(12, 20), nm, 14, UiKit.TEXT)
	if s.team >= 0:
		UiKit.caps_at(self, r.position + Vector2(20 + UiKit.caps_w(nm, 14), 20), sub, 11, Net.player_color(own) if own != 0 else Defs.TEAM_COLORS[s.team].lightened(0.35))
	var hf := s.health_frac()
	var x := r.position.x + 12.0
	x += UiKit.mono_at(self, Vector2(x, r.position.y + 39), "HP", 10, UiKit.FAINT) + 5.0
	x += UiKit.steps(self, Vector2(x, r.position.y + 31), hf * 8.0, 8, UiKit.GOOD if hf > 0.5 else (UiKit.WARN if hf > 0.25 else UiKit.BAD), 4.0, 8.0) + 12.0
	x += UiKit.mono_at(self, Vector2(x, r.position.y + 39), "AM", 10, UiKit.FAINT) + 5.0
	UiKit.steps(self, Vector2(x, r.position.y + 31), s.ammo_fraction() * 8.0, 8, UiKit.INTEL, 4.0, 8.0)
	if act != "":
		UiKit.caps_at(self, r.position + Vector2(12, 56), act, 11, ac)


func _vehicle_card(v: Vehicle, mp: Vector2) -> void:
	var nm := v.display_name()
	var sub: String = Defs.TEAM_NAMES[v.team] if v.team >= 0 else ""
	var own := _co_owner(v)
	if own != 0:
		sub += " · Shared control" if v.team == hud.world.local_team else ""
	var hf := v.health_frac()
	var st := "Track broken" if (v.flags & Vehicle.F_TRACK) != 0 else ("Burning" if hf < 0.2 else ("Smoking" if hf < 0.4 else ""))
	var wd := maxf(UiKit.caps_w(nm, 14) + UiKit.caps_w(sub, 11) + 40.0, 184.0)
	var r := Rect2(mp + Vector2(24, 24), Vector2(wd, 62.0 if st != "" else 46.0))
	_card(r)
	UiKit.caps_at(self, r.position + Vector2(12, 20), nm, 14, UiKit.TEXT)
	if v.team >= 0:
		UiKit.caps_at(self, r.position + Vector2(20 + UiKit.caps_w(nm, 14), 20), sub, 11, Net.player_color(own) if own != 0 else Defs.TEAM_COLORS[v.team].lightened(0.35))
	var x := r.position.x + 12.0
	x += UiKit.mono_at(self, Vector2(x, r.position.y + 39), "HP", 10, UiKit.FAINT) + 5.0
	UiKit.steps(self, Vector2(x, r.position.y + 31), hf * 12.0, 12, UiKit.GOOD if hf > 0.5 else (UiKit.WARN if hf > 0.25 else UiKit.BAD), 6.0, 8.0)
	if st != "":
		UiKit.caps_at(self, r.position + Vector2(12, 54), st, 11, UiKit.BAD)


## A hover card's ground: ink with corner ticks (docs/UI.md, Panels).
func _card(r: Rect2) -> void:
	draw_rect(r, UiKit.fa(UiKit.INK, 0.9))
	UiKit.ticks(self, r, UiKit.RULE2, UiKit.TICK_ARM, 0.0)
