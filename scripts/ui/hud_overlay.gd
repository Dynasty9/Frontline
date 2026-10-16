class_name HudOverlay
extends Control

var hud: Hud
var _placed: Array = []
var _groups := {}  # sid -> {"mem": [...], "c": centroid of the living, "n": living, "team": t, "lead": squad leader}
var _sel_sids := {}
var _pt := 0
var _team_structs: Array = []
var _ts_t := 0
const CLOSE_Z := 22.0
const FAR_Z := 42.0

func _draw() -> void:
	var w := hud.world
	var inp := w.input
	if inp == null or w.cam == null:
		return
	var cam := w.cam.cam
	var vs := get_viewport().get_visible_rect().size
	if inp.lmb and inp.dragging:
		var r := Rect2(inp.drag_start, Vector2.ZERO).expand(get_viewport().get_mouse_position())
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.1))
		draw_rect(r, Color(0.6, 1.0, 0.6, 0.75), false, 1.0)
	var lt := w.local_team
	var cpos := cam.global_position
	var zoom: float = w.cam.dist
	# Three levels of detail. Close up: each man's name, what he's doing, what
	# he says and who he's dealing with. Further out: an icon per man. Zoomed
	# out: one symbol per squad with its orders, and new orders as they come
	# down from the commander.
	var a_close := clampf((CLOSE_Z - zoom) / 5.0, 0.0, 1.0)
	var a_mid := clampf((zoom - CLOSE_Z + 5.0) / 5.0, 0.0, 1.0) * clampf((FAR_Z + 8.0 - zoom) / 8.0, 0.0, 1.0)
	var a_far := clampf((zoom - FAR_Z) / 10.0, 0.0, 1.0)
	var labels_on: bool = hud.map_layer("labels")
	var a_units := a_far
	if hud.map_layer("units") and zoom > CLOSE_Z:
		a_units = maxf(a_far, 0.85)
	if hud.tactical:
		# the map view: symbols, orders and contacts on a dimmed battlefield
		a_units = 1.0
		a_close = 0.0
		a_mid = 0.0
		labels_on = false
		_map_grid(cam, vs)
	elif not hud.map_layer("units"):
		a_units = 0.0
	_pt = Time.get_ticks_usec()
	# the few structures that carry a name or a progress bar (HQs, FOBs, anything
	# being built): picked out of the hundreds of walls and trees twice a second
	_ts_t -= 1
	if _ts_t <= 0:
		_ts_t = 30
		_team_structs.clear()
		for st2 in w.structures:
			if st2.team >= 0 or st2.label_h > 0.0:
				_team_structs.append(st2)
	_clear_placed()
	_build_groups(inp)
	_mark("groups")
	_town_marks()
	_structure_labels(cam, vs, zoom)
	_mark("structure labels")
	if hud.map_layer("intel"):
		_intel(cam, vs, lt)
	if hud.map_layer("ranges"):
		_ranges(cam)
	_sight_rings()
	_order_graphics(lt, maxf(a_far, a_units * 0.9))
	_mark("orders")
	if not w.mission_info.is_empty() and int(w.mission_info.get("over", 0)) == 0:
		_mission_marks(cam, vs)
	var men := _men_on_screen(cam, vs)
	_mark("men on screen")
	if a_close > 0.0:
		_interactions(cam, men, a_close)
	if a_close + a_mid > 0.0:
		_leader_marks(men, maxf(a_close, a_mid))
		_sectors(cam, maxf(a_close, a_mid))
	_mark("interactions")
	if Settings.get_v("bubbles"):
		_speech(cam, vs, a_close, a_mid)
	_mark("speech")
	if labels_on and a_close > 0.0:
		_name_tags(men, a_close, zoom, lt)
	if labels_on and a_mid > 0.0:
		_status_icons(men, a_mid)
	_mark("labels")
	_nato_markers(cam, lt, a_units)
	_command_links(cam, a_units)
	_mark("symbols")
	# health bars: selected, wounded or downed friendlies
	for s in w.soldiers:
		if not s.visible or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DEAD:
			continue
		var own: bool = s.team == lt
		var want: bool = s.selected or (own and s.life == Soldier.Life.DOWNED) or (own and s.health_frac() < 0.98 and s.life == Soldier.Life.ALIVE)
		if not want or (a_far > 0.6 and s.life != Soldier.Life.DOWNED):
			continue
		var p: Vector3 = s.position + Vector3(0, 2.1, 0)
		if cam.is_position_behind(p) or cpos.distance_to(p) > 160.0:
			continue
		var sp := cam.unproject_position(p)
		if s.life == Soldier.Life.DOWNED:
			var a2 := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
			draw_rect(Rect2(sp + Vector2(-2, -7), Vector2(4, 14)), Color(1, 0.15, 0.1, a2))
			draw_rect(Rect2(sp + Vector2(-7, -2), Vector2(14, 4)), Color(1, 0.15, 0.1, a2))
			_bar(sp + Vector2(-12, 9), Vector2(24, 3), s.health_frac(), Color(1, 0.3, 0.3))
			continue
		var hf: float = s.health_frac()
		_bar(sp + Vector2(-11, 2), Vector2(22, 3), hf, Color(1.0, 0.25, 0.2).lerp(Color(0.4, 0.95, 0.4), hf))
		if s.selected:
			_bar(sp + Vector2(-11, 6), Vector2(22, 2), s.ammo_fraction(), Color(0.45, 0.7, 1.0))
	for v in w.vehicles:
		if not v.visible or not (v.selected or (v.team == lt and v.health_frac() < 0.99)):
			continue
		var p2: Vector3 = v.position + Vector3(0, 3.6, 0)
		if cam.is_position_behind(p2):
			continue
		var sp2 := cam.unproject_position(p2)
		_bar(sp2 + Vector2(-24, 0), Vector2(48, 4), v.health_frac(), UiKit.GOOD)
		if (v.flags & Vehicle.F_TRACK) != 0:
			UiKit.text(self, sp2 + Vector2(-26, -5), "TRACK HIT", 11, UiKit.BAD, 600)
	for st in _team_structs:
		if st.gone or (st.team < 0 and st.skind != "town") or not st.visible:
			continue
		var capturable: bool = st.skind == "fob" or st.skind == "town"
		var need: bool = (not st.built) or (capturable and st.cap_prog > 0.0) or (st.team == lt and st.hp < st.max_hp * 0.98 and st.is_player_building())
		if not need:
			continue
		var p3: Vector3 = st.position + Vector3(0, 4.5 if st.skind != "town" else st.label_h - 2.4, 0)
		if cam.is_position_behind(p3) or cpos.distance_to(p3) > (170.0 if st.skind != "town" else 320.0):
			continue
		var sp3 := cam.unproject_position(p3)
		if not st.built:
			_bar(sp3 + Vector2(-30, 0), Vector2(60, 4), st.progress, UiKit.WARN)
		elif capturable and st.cap_prog > 0.0 and st.cap_team >= 0:
			_bar(sp3 + Vector2(-40, 0), Vector2(80, 6), st.cap_prog / 100.0, Defs.TEAM_COLORS[st.cap_team])
			UiKit.text(self, sp3 + Vector2(-34, -5), "CAPTURING", 11, Color(1, 1, 1), 600)
		else:
			_bar(sp3 + Vector2(-30, 0), Vector2(60, 3), st.hp / maxf(1.0, st.max_hp), UiKit.GOOD)
	var now := w.time
	for i in range(w.pings.size() - 1, -1, -1):
		var pg: Array = w.pings[i]
		if pg[1] < now:
			w.pings.remove_at(i)
			continue
		var pp: Vector3 = pg[0] + Vector3(0, 2, 0)
		if cam.is_position_behind(pp):
			continue
		var spp := cam.unproject_position(pp)
		spp = spp.clamp(Vector2(24, 60), vs - Vector2(24, 240))
		var col2 := Color(0.5, 0.9, 1.0) if pg[2] == "intel" else Color(1, 0.55, 0.3)
		var rr := 8.0 + fmod(now * 1.5, 1.0) * 10.0
		draw_arc(spp, rr, 0, TAU, 24, Color(col2.r, col2.g, col2.b, 1.0 - fmod(now * 1.5, 1.0) * 0.7), 2.0)
		draw_circle(spp, 3.0, col2)
	# follow caption (observer director)
	var d := w.director
	if d and d.active and d._subject and not d._subject.gone and d._subject is Soldier:
		var sj: Soldier = d._subject
		var cap: String = "%s  -  %s" % [sj.display_name(), Defs.TEAM_NAMES[sj.team] if sj.team >= 0 else ""]
		var act := sj.doing_text()
		var cw := maxf(UiKit.text_width(cap, 15, 600), UiKit.text_width(act, 13)) + 40.0
		var cr := Rect2(vs.x * 0.5 - cw * 0.5, vs.y - 92, cw, 52.0 if act != "" else 32.0)
		UiKit.pill(self, cr, Color(0.03, 0.035, 0.03, 0.6))
		UiKit.text(self, Vector2(cr.position.x + 20, cr.position.y + 21), cap, 15, UiKit.TEXT, 600)
		if act != "":
			UiKit.text(self, Vector2(cr.position.x + 20, cr.position.y + 41), act, 13, Hud.CAT_COLORS.get(sj.doing_cat(), UiKit.DIM))
	var mp: Vector2 = inp._mouse()
	if not inp.preview.is_empty():
		_cover_preview(inp, cam, mp)
	if inp.place_kind != "" and inp.ghost_err != "":
		UiKit.text(self, mp + Vector2(18, 26), inp.ghost_err, 13, UiKit.BAD)
	elif inp.ability.begins_with("support:") or inp.ability.begins_with("demo:"):
		_support_preview(inp, mp)
	elif inp.ability != "":
		var lbl := "Throw grenade here"
		match inp.ability:
			"smoke":
				lbl = "Throw smoke here"
			"mortar_he", "pit_he":
				lbl = "Mortar HE on this spot"
			"arty_he":
				lbl = "Artillery salvo on this spot"
			"mortar_smoke", "pit_smoke":
				lbl = "Mortar smoke on this spot"
		UiKit.text(self, mp + Vector2(18, 26), lbl, 13, UiKit.WARN)
	elif inp.place_drag and not inp.line_items.is_empty():
		var ok := 0
		for it in inp.line_items:
			if it[2]:
				ok += 1
		UiKit.text(self, mp + Vector2(18, 26), "%d x %s  (%d supply)" % [ok, Defs.BUILDINGS[inp.place_kind].name, ok * int(Defs.BUILDINGS[inp.place_kind].cost)], 13, UiKit.GOOD)
	elif inp.hover and inp.hover.visible and not inp.pinging:
		if inp.has_units() and inp.hover.is_hostile_to(lt):
			UiKit.text(self, mp + Vector2(18, 26), "Attack", 13, UiKit.BAD, 600)
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
				lbl = "Attack-move  ·  "
			"defend":
				lbl = "Defend  ·  "
		var cs: String = w.terrain.describe(gp, gp + inp.preview_face * 40.0) if w.terrain else ""
		if not near_info.is_empty():
			cs = Cover.describe(near_info)
		var pos: Vector2 = (inp.rmb_start if inp.rmb else mp) + Vector2(18, 44)
		var tw := UiKit.text_width(lbl + cs, 12) + 14.0
		draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.7), 4, Color(0, 0, 0, 0), 0, 0.0), Rect2(pos + Vector2(-7, -14), Vector2(tw, 19)))
		UiKit.text(self, pos, lbl + cs, 12, UiKit.TEXT)

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

const RECON_COL := Color(0.5, 0.88, 1.0, 0.9)  # what recon will see (sight rings, recon calls)


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
	var lbl := "%s%s" % [String(sd.get("name", k)), ("  -  %d supply" % cost) if inp.ability.begins_with("support:") else "  (demo)"]
	UiKit.text(self, mp + Vector2(18, 26), lbl, 13, UiKit.BAD, 600)

func _ground_poly(pts: Array, col: Color) -> void:
	var cam := hud.world.cam.cam
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector3 = p + Vector3(0, 0.1, 0)
		if cam.is_position_behind(q):
			return
		out.append(cam.unproject_position(q))
	out.append(out[0])
	draw_polyline(out, col, 2.0, true)
	MapSymbols.poly(self, out, Color(col.r, col.g, col.b, 0.12))

func _ground_arrow(a: Vector3, b: Vector3, col: Color) -> void:
	var cam := hud.world.cam.cam
	if cam.is_position_behind(a) or cam.is_position_behind(b):
		return
	var sa := cam.unproject_position(a + Vector3(0, 0.1, 0))
	var sb := cam.unproject_position(b + Vector3(0, 0.1, 0))
	draw_line(sa, sb, col, 3.0, true)
	var dv := (sb - sa).normalized()
	var nv := Vector2(-dv.y, dv.x)
	MapSymbols.poly(self, PackedVector2Array([sb + dv * 10.0, sb - dv * 4.0 + nv * 8.0, sb - dv * 4.0 - nv * 8.0]), col)

# --- levels of detail -------------------------------------------------------

func _build_groups(inp) -> void:
	_groups.clear()
	_sel_sids.clear()
	for sid in inp.sel_squads:
		_sel_sids[sid] = true
	for s in hud.world.soldiers:
		if s.sid == 0 or not s.visible or s.life == Soldier.Life.HIDDEN:
			continue
		var g: Dictionary = _groups.get(s.sid, {})
		if g.is_empty():
			g = {"mem": [], "c": Vector3.ZERO, "n": 0, "team": s.team, "lead": null}
			_groups[s.sid] = g
		(g["mem"] as Array).append(s)
		if s.life == Soldier.Life.ALIVE:
			g["c"] = (g["c"] as Vector3) + s.position
			g["n"] = int(g["n"]) + 1
			if (s.flags & Soldier.F_LEADER) != 0:
				g["lead"] = s
	for sid in _groups:
		var g: Dictionary = _groups[sid]
		if int(g["n"]) > 0:
			g["c"] = (g["c"] as Vector3) / float(g["n"])

func _men_on_screen(cam: Camera3D, vs: Vector2) -> Array:
	var out := []
	var center := vs * 0.5
	for s in hud.world.soldiers:
		if not s.visible or s.life == Soldier.Life.DEAD or s.life == Soldier.Life.HIDDEN:
			continue
		var p0: Vector3 = s.position + Vector3(0, _head_h(s), 0)
		if cam.is_position_behind(p0):
			continue
		var sp0 := cam.unproject_position(p0)
		if sp0.x < -40 or sp0.y < -20 or sp0.x > vs.x + 40 or sp0.y > vs.y + 20:
			continue
		out.append([sp0.distance_squared_to(center), s, sp0])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

static func _head_h(e: Entity) -> float:
	if not e is Soldier:
		return 3.2
	var s: Soldier = e
	if s.life == Soldier.Life.DOWNED or s.posture == Soldier.Post.PRONE:
		return 0.8
	if s.posture == Soldier.Post.CROUCH:
		return 1.55
	return 2.0

static func _glyph_of(s: Soldier) -> String:
	if (s.flags & Soldier.F_PINNED) != 0 and s.life == Soldier.Life.ALIVE:
		return "pinned"
	var g: String = MapSymbols.DOING_GLYPH[s.doing] if s.doing >= 0 and s.doing < MapSymbols.DOING_GLYPH.size() else ""
	if g == "" and (s.flags & Soldier.F_NOAMMO) != 0:
		return "noammo"
	return g

## FOB and HQ names: drawn here rather than in the 3D scene so roads and
## smoke can never cover them.
func _structure_labels(cam: Camera3D, vs: Vector2, zoom: float) -> void:
	var fs := 13 if zoom < 30.0 else (12 if zoom < 70.0 else 11)
	for st in _team_structs:
		if st.gone or st.label_h <= 0.0 or not st.visible:
			continue
		var p: Vector3 = st.position + Vector3(0, st.label_h, 0)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if sp.x < -120 or sp.x > vs.x + 120 or sp.y < -30 or sp.y > vs.y + 30:
			continue
		var txt: String = st.display_name() + ("  (WRECKED)" if st.wrecked else "")
		if st.skind == "town":
			txt += "  ·  " + ("town" if st.variant == 1 else "village")
		var tw := UiKit.text_width(txt, fs, 600)
		var r := Rect2(sp.x - tw * 0.5 - 10, sp.y - fs - 5, tw + 20, fs + 10)
		draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.66), 4, Color(1, 1, 1, 0.08), 1, 0.0), r)
		if st.team >= 0:
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(3, r.size.y - 2)), Defs.TEAM_COLORS[st.team])
		elif st.skind == "town":
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(3, r.size.y - 2)), Structure.C_TOWN_FLAG)
		UiKit.text(self, Vector2(r.position.x + 11, r.position.y + fs + 2), txt, fs, Color(1, 1, 1, 0.94), 600)
		_place_rect(r)

## Each squad's orders drawn on the ground: dashed arrows for moves, a bold
## axis of advance and an objective ring for assaults, a defended arc for
## positions to hold. Zoomed out: every squad; closer in, the ones you've
## selected. The whole route shows for selected squads and fresh orders
## (drawing itself in as the order goes out); otherwise a short arrow
## points the way, so a zoomed-out map stays readable.
func _order_graphics(lt: int, a_far: float) -> void:
	var now := Time.get_ticks_msec()
	for sid in hud.orders:
		var o: Array = hud.orders[sid]
		var g: Dictionary = _groups.get(sid, {})
		if g.is_empty() or int(g["n"]) == 0:
			continue
		var sel := _sel_sids.has(sid)
		var a := maxf(a_far, 0.7) if sel else a_far
		if not sel and hud.map_layer("orders") and (int(o[4]) == lt or lt < 0):
			a = maxf(a, 0.6)
		if a <= 0.02:
			continue
		if o.size() > 6 and o[6] != null:
			_plan_graphics(o[6], int(o[4]), a, sel)
			continue
		var age := 1e9 if int(o[5]) < 0 else (now - int(o[5])) / 1000.0
		var grow := clampf(age / 0.7, 0.0, 1.0)
		var tc: Color = Defs.TEAM_COLORS[int(o[4])]
		var from: Vector3 = g["c"]
		var to: Vector3 = o[1]
		var face: Vector3 = o[2]
		var dd := Defs.flat(to - from)
		var full_k := 1.0 if sel else clampf(7.0 - age, 0.0, 1.0)
		var stub := minf(dd.length(), 20.0)
		var reach := lerpf(stub, dd.length(), full_k)
		var whole := full_k > 0.99
		if not whole:
			a *= lerpf(0.6, 1.0, full_k)
		if dd.length() > 0.1:
			to = from + dd.normalized() * reach
		var far := reach > 9.0
		match String(o[0]):
			"move", "bound":
				if far:
					_ground_path(from, to, tc.lightened(0.35), a * 0.8, grow, true, 2.0)
			"retreat":
				if far:
					_ground_path(from, to, Color(1.0, 0.76, 0.36), a * 0.85, grow, true, 2.0)
			"assault":
				if far:
					_ground_path(from, to, tc.lightened(0.15), a, grow, false, 3.5 if whole else 2.5)
				if whole:
					_dashed_ring(to, 5.0, tc.lightened(0.3), a * 0.8 * grow)
			"attack":
				if far:
					_ground_path(from, to, Color(1.0, 0.45, 0.35), a, grow, false, 2.5)
			"defend", "ambush":
				if far:
					_ground_path(from, to, tc.lightened(0.35), a * 0.55, grow, true, 1.5)
				if whole or dd.length() < 25.0:
					_defend_arc(o[1], face, tc.lightened(0.35), a * grow)
			"build":
				if far:
					_ground_path(from, to, UiKit.WARN, a * 0.55, grow, true, 1.5)

func _ground_path(a: Vector3, b: Vector3, col: Color, alpha: float, grow: float, dashed: bool, width: float, arrow := true) -> void:
	var cam := hud.world.cam.cam
	var d := Defs.flat(b - a)
	var l := d.length() * grow
	if l < 1.5:
		return
	var dir := d.normalized()
	var n := maxi(2, int(l / 2.5))
	var pts := PackedVector2Array()
	for i in n + 1:
		var p := a + dir * (l * i / n)
		p.y = 0.3
		if cam.is_position_behind(p):
			return
		pts.append(cam.unproject_position(p))
	var c := Color(col.r, col.g, col.b, alpha)
	var sh := Color(0, 0, 0, alpha * 0.45)
	if dashed:
		for i in range(0, pts.size() - 1, 2):
			draw_line(pts[i], pts[i + 1], sh, width + 2.0, true)
			draw_line(pts[i], pts[i + 1], c, width, true)
	else:
		draw_polyline(pts, sh, width + 2.0, true)
		draw_polyline(pts, c, width, true)
	if not arrow:
		return
	var tip := pts[pts.size() - 1]
	var back := pts[0]
	if (tip - back).length() < 4.0:
		return
	var dv := (tip - back).normalized()
	var nv := Vector2(-dv.y, dv.x)
	var hs := 5.0 + width * 1.8
	var head := PackedVector2Array([tip + dv * hs, tip - dv * hs * 0.5 + nv * hs * 0.8, tip - dv * hs * 0.5 - nv * hs * 0.8])
	MapSymbols.poly(self, head, c)

func _dashed_ring(c3: Vector3, r: float, col: Color, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var cam := hud.world.cam.cam
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		var p := c3 + Vector3(cos(ang) * r, 0, sin(ang) * r)
		p.y = 0.3
		if cam.is_position_behind(p):
			return
		pts.append(cam.unproject_position(p))
	var c := Color(col.r, col.g, col.b, alpha)
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], Color(0, 0, 0, alpha * 0.4), 4.0, true)
		draw_line(pts[i], pts[i + 1], c, 2.0, true)

## Each town's ground as a ring in its holder's colours (the town's own while
## nobody holds it) when the camera is over it, and whenever someone is
## taking it - then pulsing in the taker's colour.
func _town_marks() -> void:
	var w := hud.world
	var f: Vector3 = w.cam.focus_pos
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	for st in _team_structs:
		if st.gone or st.skind != "town" or st.zone_r <= 0.0:
			continue
		var taking: bool = st.cap_team >= 0 and st.cap_prog > 0.0
		var a := clampf((st.zone_r + 90.0 - Defs.flat(st.zone_c - f).length()) / 60.0, 0.0, 1.0) * 0.4
		var col: Color = Defs.TEAM_COLORS[st.team] if st.team >= 0 else Structure.C_TOWN_FLAG
		if taking:
			a = maxf(a, 0.75)
			col = (Defs.TEAM_COLORS[st.cap_team] as Color).lerp(col, pulse * 0.6)
		_dashed_ring(st.zone_c, st.zone_r, col, a)


## A mission's objectives where they are: the area as a ring on the ground, and
## over it a diamond with its letter and how far it is from the camera's
## centre. One off the screen waits at the edge, pointing the way.
func _mission_marks(cam: Camera3D, vs: Vector2) -> void:
	var w := hud.world
	var t := Time.get_ticks_msec() / 1000.0
	for o in w.mission_info.get("objs", []):
		if int(o[2]) != MissionDirector.ACTIVE or o[4] == null:
			continue
		var p: Vector3 = o[4]
		var col: Color = UiKit.ACCENT if not bool(o[7]) else Color(0.75, 0.8, 0.85)
		var r := float(o[5])
		if String(o[3]) in ["reach", "clear", "hold", "extract", "deliver"] and r > 0.0:
			_dashed_ring(p, r, col, 0.55)
		var top := p + Vector3(0, 7.0, 0)
		var sp := cam.unproject_position(top)
		var behind := cam.is_position_behind(top)
		var margin := 46.0
		var inside := not behind and sp.x > margin and sp.x < vs.x - margin and sp.y > margin and sp.y < vs.y - margin
		var dist := Defs.flat(p - w.cam.focus_pos).length()
		if inside:
			var bob := sin(t * 2.4) * 2.0
			var c := sp + Vector2(0, bob)
			draw_line(c + Vector2(0, 13), cam.unproject_position(p + Vector3(0, 0.3, 0)), Color(col.r, col.g, col.b, 0.35), 1.0, true)
			HudObjectives.diamond(self, c, 15.0, String(o[0]), col, 1.0)
			if dist > 25.0:
				HudObjectives._at(self, c - Vector2(0, 22), "%d m" % int(dist), 12, Color(col.r, col.g, col.b, 0.95), 700, 0.5)
		else:
			# to the edge of the screen, along the line from its centre
			var mid := vs * 0.5
			var d := sp - mid
			if behind:
				d = -d
			if d.length() < 1.0:
				d = Vector2(0, 1)
			var k := minf((mid.x - margin) / maxf(absf(d.x), 0.001), (mid.y - margin) / maxf(absf(d.y), 0.001))
			var e := mid + d * k
			var dn := d.normalized()
			HudObjectives.diamond(self, e, 13.0, String(o[0]), col, 0.95)
			var tip := e + dn * 23.0
			draw_colored_polygon(PackedVector2Array([tip, e + dn * 15.0 + dn.orthogonal() * 6.0, e + dn * 15.0 - dn.orthogonal() * 6.0]), Color(col.r, col.g, col.b, 0.95))
			HudObjectives._at(self, e - dn * 30.0 + Vector2(0, 4), "%d m" % int(dist), 11, Color(col.r, col.g, col.b, 0.9), 700, 0.5)


## The "defend" tactical sign: an arc across the front with ticks facing out.
func _defend_arc(c3: Vector3, face: Vector3, col: Color, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var cam := hud.world.cam.cam
	var base := atan2(face.z, face.x) if face.length() > 0.1 else -PI * 0.5
	var r := 7.0
	var pts := PackedVector2Array()
	var ticks := []
	for i in 15:
		var ang := base + deg_to_rad(-70.0 + i * 10.0)
		var dv := Vector3(cos(ang), 0, sin(ang))
		var p := c3 + dv * r
		p.y = 0.3
		if cam.is_position_behind(p):
			return
		pts.append(cam.unproject_position(p))
		if i % 2 == 1:
			ticks.append([p, p + dv * 1.4])
	var c := Color(col.r, col.g, col.b, alpha)
	draw_polyline(pts, Color(0, 0, 0, alpha * 0.45), 5.0, true)
	draw_polyline(pts, c, 3.0, true)
	for t in ticks:
		draw_line(cam.unproject_position(t[0]), cam.unproject_position(t[1]), c, 2.0, true)

## Who's dealing with whom, close up: chat partners, a medic and his patient,
## a guard and his prisoner.
func _interactions(cam: Camera3D, men: Array, a: float) -> void:
	var w := hud.world
	for m in men:
		var s: Soldier = m[1]
		if s.doing_ent == 0:
			continue
		var o: Entity = w.entity(s.doing_ent)
		if o == null or not o.visible or not o is Soldier:
			continue
		var os: Soldier = o
		match s.doing:
			35:
				if os.doing_ent != s.eid or s.eid < os.eid:
					_link(cam, s, os, Hud.CAT_COLORS["idle"], a * 0.6, true, "chat")
			9, 10:
				_link(cam, s, os, Hud.CAT_COLORS["medic"], a * 0.85, false, "medic")
			16:
				_link(cam, s, os, UiKit.DIM, a * 0.5, true, "eye")

func _link(cam: Camera3D, s: Soldier, o: Soldier, col: Color, alpha: float, dashed: bool, gk: String) -> void:
	var pa: Vector3 = s.position + Vector3(0, _head_h(s) - 0.35, 0)
	var pb: Vector3 = o.position + Vector3(0, _head_h(o) - 0.35, 0)
	if cam.is_position_behind(pa) or cam.is_position_behind(pb):
		return
	var a2 := cam.unproject_position(pa)
	var b2 := cam.unproject_position(pb)
	var c := Color(col.r, col.g, col.b, alpha)
	var mid := (a2 + b2) * 0.5 + Vector2(0, -minf(18.0, a2.distance_to(b2) * 0.3))
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a2.lerp(mid, t).lerp(mid.lerp(b2, t), t))
	if dashed:
		for i in range(0, pts.size() - 1, 2):
			draw_line(pts[i], pts[i + 1], c, 1.6, true)
	else:
		draw_polyline(pts, Color(0, 0, 0, alpha * 0.4), 3.4, true)
		draw_polyline(pts, c, 1.8, true)
	if gk != "":
		MapSymbols.glyph(self, gk, pts[6], 6.0, col, alpha)

## Squad leaders wear sergeant's chevrons; when an order comes in over the
## radio, the set lights up next to them.
func _leader_marks(men: Array, a: float) -> void:
	var now := Time.get_ticks_msec()
	for m in men:
		var s: Soldier = m[1]
		if (s.flags & Soldier.F_LEADER) == 0 or s.life != Soldier.Life.ALIVE:
			continue
		var sp: Vector2 = m[2] + Vector2(0, -6)
		var tc: Color = (Defs.TEAM_COLORS[s.team] if s.team >= 0 else Color.WHITE).lightened(0.3)
		for i in 2:
			var y := sp.y - i * 4.0
			var pts := PackedVector2Array([Vector2(sp.x - 5, y + 2.5), Vector2(sp.x, y - 1.0), Vector2(sp.x + 5, y + 2.5)])
			draw_polyline(pts, Color(0, 0, 0, 0.6 * a), 3.4, true)
			draw_polyline(pts, Color(tc.r, tc.g, tc.b, a), 1.8, true)
		var o: Array = hud.orders.get(s.sid, [])
		if not o.is_empty() and int(o[5]) >= 0 and now - int(o[5]) < 3500:
			var blink := 0.6 + 0.4 * sin(now / 90.0)
			MapSymbols.glyph(self, "radio", sp + Vector2(13, -2), 6.5, Color(0.6, 1.0, 0.7), a * blink)

static func _talk_kind(e: Entity, t: String) -> String:
	var lo := t.to_lower()
	if lo.contains("medic") or lo.contains("man down") or lo.contains(" is hit") or lo.contains("wounded"):
		return "medic"
	if e is Soldier:
		var s: Soldier = e
		if (s.doing >= 35 and s.doing <= 41) or (s.doing in [0, 8] and not t.ends_with("!")):
			return "chat"
		if (s.flags & Soldier.F_LEADER) != 0 and (t.begins_with("Copy") or t.begins_with("Roger") or t.begins_with("Moving to") or t.begins_with("Wilco")):
			return "radio"
	return "shout"

static func _order_words(o: Array) -> String:
	var g := Defs.grid_ref(o[1])
	match String(o[0]):
		"move":
			return "move to %s." % g
		"assault":
			return "assault %s." % g
		"defend":
			return "dig in at %s." % g
		"bound":
			return "bound forward to %s." % g
		"ambush":
			return "lay an ambush at %s." % g
		"retreat":
			return "fall back."
		"attack":
			return "engage at %s." % g
		"build":
			return "build at %s." % g
		"hold":
			return "hold your position."
		"tunnel":
			return "into the tunnels."
	return String(o[0]) + "."

static func _order_tag(o: Array) -> String:
	var k := String(o[0])
	var words := {"move": "MOVE", "assault": "ASSAULT", "defend": "DEFEND", "retreat": "FALL BACK", "attack": "ENGAGE", "build": "BUILD", "hold": "HOLD", "tunnel": "TUNNELS", "bound": "BOUND", "ambush": "AMBUSH"}
	return String(words.get(k, k.to_upper())) + ("" if k in ["retreat", "hold", "tunnel"] else "  " + Defs.grid_ref(o[1]))

## Speech: comic bubbles close up (light for banter, dark for shouts, red for
## casualties, green for the radio); further out only the shouts, cut short.
## New orders are heard over each squad leader's radio first.
func _speech(cam: Camera3D, vs: Vector2, a_close: float, a_mid: float) -> void:
	if a_close + a_mid <= 0.0:
		return
	var w := hud.world
	var now := Time.get_ticks_msec()
	var items := []
	if w.fx:
		for b in w.fx.talk:
			var e: Entity = w.entity(int(b[0]))
			if e == null or not e.visible:
				continue
			var age := (now - int(b[2])) / 1000.0
			var f := clampf((float(b[3]) - age) * 3.0, 0.0, 1.0) * clampf(age * 10.0, 0.0, 1.0)
			items.append([e, String(b[1]), f, _talk_kind(e, String(b[1])), age])
	for sid in hud.orders:
		var o: Array = hud.orders[sid]
		if int(o[5]) < 0:
			continue
		var age2 := (now - int(o[5])) / 1000.0
		if age2 > 3.5:
			continue
		var g: Dictionary = _groups.get(sid, {})
		if g.is_empty() or g["lead"] == null:
			continue
		var hq := "Six" if int(o[4]) == 0 else "Command"
		items.append([g["lead"], "%s: %s" % [hq, _order_words(o)], clampf((3.5 - age2) * 3.0, 0.0, 1.0) * clampf(age2 * 10.0, 0.0, 1.0), "radio", 9.0])
	for it in items:
		var e: Entity = it[0]
		var kind: String = it[3]
		# a squad leader shouting orders: you see the word go out to his men
		if a_close > 0.0 and e is Soldier and ((e as Soldier).flags & Soldier.F_LEADER) != 0 and kind == "shout" and float(it[4]) < 1.5:
			_command_fan(cam, e, (1.5 - float(it[4])) / 1.5 * a_close)
		var p: Vector3 = e.position + Vector3(0, _head_h(e), 0)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p) + Vector2(0, -16)
		if sp.x < -150 or sp.x > vs.x + 150 or sp.y < -60 or sp.y > vs.y + 40:
			continue
		if a_close > 0.0:
			_bubble(sp, it[1], kind, float(it[2]) * a_close, 12, 220.0)
		elif kind != "chat":
			var t: String = it[1]
			if t.length() > 24:
				t = t.substr(0, 22).strip_edges() + "..."
			_bubble(sp, t, kind, float(it[2]) * a_mid, 11, 170.0)

func _command_fan(cam: Camera3D, lead: Soldier, a: float) -> void:
	var g: Dictionary = _groups.get(lead.sid, {})
	if g.is_empty():
		return
	var p0: Vector3 = lead.position + Vector3(0, _head_h(lead) - 0.3, 0)
	if cam.is_position_behind(p0):
		return
	var s0 := cam.unproject_position(p0)
	var k := clampf(1.0 - a, 0.0, 1.0)
	for s in g["mem"]:
		if s == lead or s.life != Soldier.Life.ALIVE:
			continue
		var p1: Vector3 = s.position + Vector3(0, _head_h(s) - 0.3, 0)
		if cam.is_position_behind(p1) or Defs.flat(p1 - p0).length() > 35.0:
			continue
		var s1 := cam.unproject_position(p1)
		draw_line(s0, s1, Color(1.0, 0.86, 0.55, 0.3 * a), 1.2, true)
		draw_circle(s0.lerp(s1, k), 2.4, Color(1.0, 0.86, 0.55, 0.9 * a))

func _bubble(anchor: Vector2, text: String, kind: String, a: float, fs: int, wmax: float) -> void:
	if a <= 0.01:
		return
	var weight := 600 if kind != "chat" else 400
	var lines := MapSymbols.wrap(text, fs, weight, wmax)
	var lw := 0.0
	for l in lines:
		lw = maxf(lw, UiKit.text_width(l, fs, weight))
	var icon := 15.0 if kind == "radio" else 0.0
	var lh := fs + 3.0
	var sz := Vector2(lw + 16.0 + icon, lines.size() * lh + 8.0)
	var r := Rect2(anchor + Vector2(-sz.x * 0.5, -sz.y - 8.0), sz)
	var tries := 0
	while tries < 4 and _overlaps(r):
		r.position.y -= sz.y * 0.5 + 4.0
		tries += 1
	_place_rect(r)
	var bg := Color(0.04, 0.045, 0.04, 0.88)
	var fg := Color(1.0, 0.95, 0.82)
	var edge := Color(1.0, 0.75, 0.4, 0.5)
	match kind:
		"chat":
			bg = Color(0.95, 0.94, 0.89, 0.94)
			fg = Color(0.1, 0.11, 0.1)
			edge = Color(0, 0, 0, 0.25)
		"radio":
			bg = Color(0.03, 0.1, 0.06, 0.92)
			fg = Color(0.62, 1.0, 0.72)
			edge = Color(0.4, 0.85, 0.55, 0.7)
		"medic":
			bg = Color(0.13, 0.04, 0.04, 0.92)
			fg = Color(1.0, 0.74, 0.7)
			edge = Color(1.0, 0.4, 0.35, 0.8)
	bg.a *= a
	fg.a *= a
	edge.a *= a
	# the tail points at whoever's talking
	var tx := clampf(anchor.x, r.position.x + 9.0, r.end.x - 9.0)
	if anchor.y > r.end.y + 1.0:
		MapSymbols.poly(self, PackedVector2Array([Vector2(tx - 5, r.end.y - 1), Vector2(tx + 5, r.end.y - 1), anchor]), bg)
	draw_style_box(UiKit.boxc(bg, 7, edge, 1, 0.0), r)
	var x0 := r.position.x + 8.0
	if kind == "radio":
		MapSymbols.glyph(self, "radio", Vector2(x0 + 5, r.position.y + r.size.y * 0.5), 6.0, fg, a, false)
		x0 += icon
	var y := r.position.y + 3.0 + fs
	for l in lines:
		if kind == "chat":
			draw_string(UiKit.font(weight), Vector2(x0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
		else:
			UiKit.text(self, Vector2(x0, y), l, fs, fg, weight)
		y += lh

## Close up: name, an icon and what he's doing, over each man near the
## middle of the screen.
func _name_tags(men: Array, a: float, zoom: float, lt: int) -> void:
	for i in mini(men.size(), 40):
		var s: Soldier = men[i][1]
		var txt := s.doing_text()
		var cat := s.doing_cat()
		# routine states only right up close; the interesting ones a little further out
		if (txt == "" or cat in ["idle", "move"]) and zoom > 17.0:
			txt = ""
		var gk := _glyph_of(s)
		var col: Color = Hud.CAT_COLORS.get(cat, UiKit.DIM)
		if gk == "pinned":
			col = UiKit.BAD
		var fs := 11
		var nw := UiKit.text_width(s.sname, fs, 600)
		var tw := nw + (UiKit.text_width("  " + txt, fs) if txt != "" else 0.0) + (15.0 if gk != "" else 0.0)
		var sp: Vector2 = men[i][2]
		var rect := Rect2(sp.x - tw * 0.5 - 6, sp.y - 32, tw + 12, 16)
		var tries := 0
		while tries < 3 and _overlaps(rect):
			rect.position.y -= 17
			tries += 1
		if _overlaps(rect):
			continue
		_place_rect(rect)
		var al := a * (1.0 if s.team == lt or lt < 0 else 0.85)
		draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.58 * al), 4, Color(0, 0, 0, 0), 0, 0.0), rect)
		if s.team >= 0:
			var tc: Color = Defs.TEAM_COLORS[s.team]
			draw_rect(Rect2(rect.position + Vector2(0, 3), Vector2(2, 10)), Color(tc.r, tc.g, tc.b, al))
		var x := rect.position.x + 6.0
		if gk != "":
			MapSymbols.glyph(self, gk, Vector2(x + 5, rect.position.y + 8), 6.0, col, al, false)
			x += 15.0
		UiKit.text(self, Vector2(x, rect.position.y + 12), s.sname, fs, Color(1, 1, 1, 0.92 * al), 600)
		if txt != "":
			UiKit.text(self, Vector2(x + nw, rect.position.y + 12), "  " + txt, fs, Color(col.r, col.g, col.b, al))

## Mid zoom: no names, just an icon over each man doing something worth
## knowing about.
func _status_icons(men: Array, a: float) -> void:
	for i in mini(men.size(), 90):
		var s: Soldier = men[i][1]
		if s.life == Soldier.Life.DOWNED:
			continue  # the red cross over him says it
		var gk := _glyph_of(s)
		if gk in ["", "cover", "smoke", "eye"]:
			continue
		var col: Color = Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM)
		if gk == "pinned":
			col = UiKit.BAD
		var sp: Vector2 = men[i][2] + Vector2(0, -22)
		var r := Rect2(sp - Vector2(8, 8), Vector2(16, 16))
		if _overlaps(r):
			continue
		_place_rect(r)
		MapSymbols.glyph(self, gk, sp, 7.5, col, a * (0.7 if gk == "chat" else 1.0))

## Zoomed out: one unit symbol per squad, with what it's been told to do, a
## pip per man, a burst when it's in contact and its callsign; a new order
## pulses the symbol and shows under it for a few seconds.
func _nato_markers(cam: Camera3D, lt: int, a: float) -> void:
	if a <= 0.0:
		return
	var w := hud.world
	var now := Time.get_ticks_msec()
	for sid in _groups:
		var g: Dictionary = _groups[sid]
		if int(g["n"]) == 0:
			continue
		var p: Vector3 = (g["c"] as Vector3) + Vector3(0, 4.2, 0)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		var vsz := get_viewport().get_visible_rect().size
		if sp.x < -80 or sp.y < -80 or sp.x > vsz.x + 80 or sp.y > vsz.y + 80:
			continue
		# squads bunched together: nudge the symbols apart, with a leader line
		# down to where the squad really is
		var foot := Rect2(sp + Vector2(-24, -14), Vector2(62, 46))
		var nudged := Vector2.ZERO
		for off in [Vector2.ZERO, Vector2(0, -38), Vector2(46, -22), Vector2(-46, -22), Vector2(0, -76), Vector2(92, -22), Vector2(-92, -22), Vector2(46, -60), Vector2(-46, -60)]:
			if not _overlaps(Rect2(foot.position + off, foot.size)):
				nudged = off
				break
		_place_rect(Rect2(foot.position + nudged, foot.size))
		if nudged != Vector2.ZERO:
			var ground := cam.unproject_position(g["c"] as Vector3)
			draw_line(ground, sp + nudged + Vector2(0, 10), Color(1, 1, 1, 0.45 * a), 1.0, true)
			draw_circle(ground, 2.5, Color(1, 1, 1, 0.7 * a))
			sp += nudged
		var tm: int = g["team"]
		var mine := tm == lt or lt < 0
		var mem: Array = g["mem"]
		var sym := MapSymbols.squad_symbol(mem)
		var sel := _sel_sids.has(sid)
		var sz := 30.0 if sel else 26.0
		var hw := sz * 0.5
		var o: Array = hud.orders.get(sid, [])
		var age := 1e9 if o.is_empty() or int(o[5]) < 0 else (now - int(o[5])) / 1000.0
		if age < 1.6:
			var k := age / 1.6
			draw_arc(sp, 16.0 + k * 28.0, 0.0, TAU, 32, Color(1, 1, 1, (1.0 - k) * 0.85 * a), 2.0, true)
		var firing := 0
		var supp := 0
		var alive := 0
		for s in mem:
			if s.life == Soldier.Life.ALIVE:
				alive += 1
				if (s.flags & Soldier.F_SHOOTING) != 0:
					firing += 1
				if (s.flags & (Soldier.F_SUPP | Soldier.F_PINNED)) != 0:
					supp += 1
		MapSymbols.nato(self, sp, sz, mine, tm, sym[0], sym[1], a)
		if sel:
			draw_arc(sp, hw + 7.0, 0.0, TAU, 28, Color(1, 1, 1, 0.55 * a), 1.5, true)
		# another commander's squad: his initials on it, and his colour round it while he has it selected
		var own := _co_owner(mem[0])
		if own != 0:
			_owner_tab(sp + Vector2(hw + 1.0, -sz * 0.34 - 12.0), own, a)
		var by := int(w.coop.sel_sq.get(sid, 0)) if w.coop else 0
		if by != 0:
			draw_arc(sp, hw + 7.0, 0.0, TAU, 28, HudCoop._a(Net.player_color(by), 0.95 * a), 2.0, true)
		if firing > 0:
			_contact_burst(sp + Vector2(-hw - 3.0, -hw * 0.62), a)
		if supp * 2 >= maxi(1, alive) and alive > 0:
			MapSymbols.glyph(self, "supp", sp + Vector2(-hw - 5.0, hw * 0.5), 6.5, UiKit.WARN, a)
		if not o.is_empty():
			var og: String = MapSymbols.ORDER_GLYPH.get(String(o[0]), "")
			if og != "":
				MapSymbols.glyph(self, og, sp + Vector2(hw + 10.0, -1.0), 7.5, MapSymbols.ORDER_COLORS.get(String(o[0]), UiKit.TEXT), a)
		# strength: a pip per man (white standing, red down, grey lost)
		var py := sp.y + hw * 0.68 + 4.0
		var px := sp.x - mem.size() * 2.5
		for s in mem:
			var pc := Color(0.92, 0.95, 0.9)
			if s.life == Soldier.Life.DOWNED:
				pc = Color(1, 0.32, 0.26)
			elif s.life != Soldier.Life.ALIVE:
				pc = Color(0.32, 0.32, 0.3)
			draw_rect(Rect2(px - 0.5, py - 0.5, 5, 4), Color(0, 0, 0, 0.6 * a))
			draw_rect(Rect2(px, py, 4, 3), Color(pc.r, pc.g, pc.b, a))
			px += 5.0
		var ty := py + 15.0
		if mine:
			var cs := Squad.callsign_of(tm, int(sid))
			UiKit.text(self, Vector2(sp.x - UiKit.text_width(cs, 10, 600) * 0.5, ty), cs, 10, Color(1, 1, 1, 0.8 * a), 600)
			ty += 12.0
		if age < 6.0:
			var tag := _order_tag(o)
			var ta := clampf((6.0 - age) * 1.5, 0.0, 1.0) * a
			var tcol := UiKit.ACCENT
			if own != 0:
				# who sent it, in his colour
				tag = "%s  %s" % [w.coop.initials(own), tag]
				tcol = Net.player_color(own)
			UiKit.text(self, Vector2(sp.x - UiKit.text_width(tag, 10, 600) * 0.5, ty), tag, 10, Color(tcol.r, tcol.g, tcol.b, ta), 600)
	for v in w.vehicles:
		if not v.visible or v.team < 0 or v.vkind == "truck":
			continue
		var p2: Vector3 = v.position + Vector3(0, 6.0, 0)
		if cam.is_position_behind(p2):
			continue
		var vs3: Array = MapSymbols.vehicle_symbol(v.vkind)
		var vp := cam.unproject_position(p2)
		var vsz2 := get_viewport().get_visible_rect().size
		if vp.x < -80 or vp.y < -80 or vp.x > vsz2.x + 80 or vp.y > vsz2.y + 80:
			continue
		var vr := Rect2(vp - Vector2(18, 14), Vector2(36, 28))
		for off in [Vector2.ZERO, Vector2(0, -32), Vector2(40, -16), Vector2(-40, -16)]:
			if not _overlaps(Rect2(vr.position + off, vr.size)):
				if off != Vector2.ZERO:
					draw_line(cam.unproject_position(v.position), vp + off + Vector2(0, 10), Color(1, 1, 1, 0.45 * a), 1.0, true)
				vp += off
				vr.position += off
				break
		_place_rect(vr)
		MapSymbols.nato(self, vp, 28.0, v.team == lt or lt < 0, v.team, vs3[0], vs3[1], a)
		if v.selected:
			draw_arc(vp, 21.0, 0.0, TAU, 28, Color(1, 1, 1, 0.55 * a), 1.5, true)
		var vo := _co_owner(v)
		if vo != 0:
			_owner_tab(vp + Vector2(6.0, -22.5), vo, a)
		var vby := int(w.coop.sel_veh.get(v.eid, 0)) if w.coop else 0
		if vby != 0:
			draw_arc(vp, 21.0, 0.0, TAU, 28, HudCoop._a(Net.player_color(vby), 0.95 * a), 2.0, true)

## The other human commander a unit belongs to (0: yours, the AI's or nobody's).
func _co_owner(e: Entity) -> int:
	var own: int = e.owner_peer
	return own if own > 0 and own != hud.world.local_peer and Net.players.has(own) else 0


## Another commander's unit: his initials on a small tab in his colour.
func _owner_tab(at: Vector2, peer: int, a: float) -> void:
	var ini := hud.world.coop.initials(peer) if hud.world.coop else "?"
	var tw := UiKit.text_width(ini, 8, 700)
	var r := Rect2(at, Vector2(tw + 7.0, 11.0))
	draw_style_box(UiKit.boxc(HudCoop._a(Net.player_color(peer), 0.95 * a), 3, Color(0, 0, 0, 0.5 * a), 1, 0.0), r)
	draw_string(UiKit.font(700), r.position + Vector2(3.5, 8.8), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.03, 0.04, 0.04, a))


## Zoomed out: each order is seen leaving HQ - a link from the commander's
## headquarters to the squad, with the message running down it (in the
## colour of whoever sent it, when that's another commander on your side).
func _command_links(cam: Camera3D, a: float) -> void:
	if a <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var hq := {}
	for st in hud.world.structures:
		if st.skind == "depot" and st.team >= 0:
			hq[st.team] = st.position
	for sid in hud.orders:
		var o: Array = hud.orders[sid]
		if int(o[5]) < 0 or not hq.has(int(o[4])):
			continue
		var age := (now - int(o[5])) / 1000.0
		if age > 2.2:
			continue
		var g: Dictionary = _groups.get(sid, {})
		if g.is_empty() or int(g["n"]) == 0:
			continue
		var p0: Vector3 = hq[int(o[4])] + Vector3(0, 6.0, 0)
		var p1: Vector3 = (g["c"] as Vector3) + Vector3(0, 4.2, 0)
		if cam.is_position_behind(p0) or cam.is_position_behind(p1):
			continue
		var s0 := cam.unproject_position(p0)
		var s1 := cam.unproject_position(p1)
		var tc: Color = Defs.TEAM_COLORS[int(o[4])].lightened(0.4)
		var own := _co_owner((g["mem"] as Array)[0])
		if own != 0:
			tc = Net.player_color(own)
		var fade := clampf((2.2 - age) * 2.0, 0.0, 1.0) * a
		var mid := (s0 + s1) * 0.5 + Vector2(0, -minf(90.0, s0.distance_to(s1) * 0.18))
		var pts := PackedVector2Array()
		for i in 25:
			var t := i / 24.0
			pts.append(s0.lerp(mid, t).lerp(mid.lerp(s1, t), t))
		for i in range(0, pts.size() - 1, 2):
			draw_line(pts[i], pts[i + 1], Color(tc.r, tc.g, tc.b, 0.55 * fade), 1.5, true)
		var k := clampf(age / 0.9, 0.0, 1.0)
		var idx := int(k * 23.99)
		var dot := pts[idx].lerp(pts[idx + 1], k * 24.0 - idx)
		draw_circle(dot, 3.5, Color(1, 1, 1, 0.95 * fade))
		draw_circle(dot, 7.0, Color(tc.r, tc.g, tc.b, 0.3 * fade))

func _contact_burst(c: Vector2, a: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var r := 6.5 + sin(t * 11.0) * 1.3
	var pts := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0 + t
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	MapSymbols.poly(self, pts, Color(1.0, 0.55, 0.2, 0.95 * a))

func _hover_card(s: Soldier, mp: Vector2) -> void:
	var nm := s.display_name()
	var sub: String = Defs.TEAM_NAMES[s.team] if s.team >= 0 else ""
	var own := _co_owner(s)
	if own != 0:
		sub = "%s's" % Net.player_name(own)
	var act := s.doing_text()
	match s.life:
		Soldier.Life.DOWNED:
			act = "Wounded  -  " + act
		Soldier.Life.DEAD:
			act = "Killed in action"
	var wd := maxf(UiKit.text_width(nm, 14, 600) + UiKit.text_width(sub, 12) + 16.0, UiKit.text_width(act, 12)) + 24.0
	wd = maxf(wd, 170.0)
	var r := Rect2(mp + Vector2(20, 20), Vector2(wd, 62.0 if act != "" else 46.0))
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.88), 6, Color(1, 1, 1, 0.1), 1, 0.0, 6), r)
	UiKit.text(self, r.position + Vector2(12, 19), nm, 14, UiKit.TEXT, 600)
	if s.team >= 0:
		UiKit.text(self, r.position + Vector2(20 + UiKit.text_width(nm, 14, 600), 19), sub, 12, Net.player_color(own) if own != 0 else Defs.TEAM_COLORS[s.team].lightened(0.35))
	_bar(r.position + Vector2(12, 28), Vector2(wd * 0.5 - 18, 4), s.health_frac(), Color(1.0, 0.3, 0.25).lerp(UiKit.GOOD, s.health_frac()))
	_bar(r.position + Vector2(wd * 0.5, 28), Vector2(wd * 0.5 - 12, 4), s.ammo_fraction(), Color(0.45, 0.7, 1.0))
	if act != "":
		UiKit.text(self, r.position + Vector2(12, 52), act, 12, Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM))

func _ground_ring(c: Vector3, r: float, col: Color) -> void:
	var cam := hud.world.cam.cam
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		var p := c + Vector3(cos(a) * r, 0.1, sin(a) * r)
		if cam.is_position_behind(p):
			return
		pts.append(cam.unproject_position(p))
	draw_polyline(pts, col, 2.0, true)

func _vehicle_card(v: Vehicle, mp: Vector2) -> void:
	var nm := v.display_name()
	var sub: String = Defs.TEAM_NAMES[v.team] if v.team >= 0 else ""
	var own := _co_owner(v)
	if own != 0:
		sub = "%s's" % Net.player_name(own)
	var hf := v.health_frac()
	var st := "Track broken" if (v.flags & Vehicle.F_TRACK) != 0 else ("Burning" if hf < 0.2 else ("Smoking" if hf < 0.4 else ""))
	var wd := maxf(UiKit.text_width(nm, 14, 600) + UiKit.text_width(sub, 12) + 40.0, 180.0)
	var r := Rect2(mp + Vector2(20, 20), Vector2(wd, 58.0 if st != "" else 42.0))
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.88), 6, Color(1, 1, 1, 0.1), 1, 0.0, 6), r)
	UiKit.text(self, r.position + Vector2(12, 19), nm, 14, UiKit.TEXT, 600)
	if v.team >= 0:
		UiKit.text(self, r.position + Vector2(20 + UiKit.text_width(nm, 14, 600), 19), sub, 12, Net.player_color(own) if own != 0 else Defs.TEAM_COLORS[v.team].lightened(0.35))
	_bar(r.position + Vector2(12, 28), Vector2(wd - 24, 4), hf, Color(1.0, 0.3, 0.25).lerp(UiKit.GOOD, hf))
	if st != "":
		UiKit.text(self, r.position + Vector2(12, 50), st, 12, UiKit.BAD)

const PGRID := 64.0
var _pgrid := {}  # Vector2i cell -> [Rect2]


func _clear_placed() -> void:
	_placed.clear()
	_pgrid.clear()


func _place_rect(r: Rect2) -> void:
	_placed.append(r)
	for cx in range(floori(r.position.x / PGRID), floori(r.end.x / PGRID) + 1):
		for cy in range(floori(r.position.y / PGRID), floori(r.end.y / PGRID) + 1):
			var k := Vector2i(cx, cy)
			var a = _pgrid.get(k)
			if a == null:
				_pgrid[k] = [r]
			else:
				a.append(r)


func _overlaps(r: Rect2) -> bool:
	for cx in range(floori(r.position.x / PGRID), floori(r.end.x / PGRID) + 1):
		for cy in range(floori(r.position.y / PGRID), floori(r.end.y / PGRID) + 1):
			var a = _pgrid.get(Vector2i(cx, cy))
			if a == null:
				continue
			for o in a:
				if (o as Rect2).intersects(r):
					return true
	return false

func _bar(p: Vector2, sz: Vector2, f: float, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(1, 1), sz + Vector2(2, 2)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p, Vector2(sz.x * clampf(f, 0.0, 1.0), sz.y)), col)


# --- attack plans, intelligence, ranges, the map grid ---------------------------------

var _plans_drawn := {}


## An attack plan on the ground: the objective (OBJ, with the phase under it),
## the support-by-fire position with its fire converging on the objective,
## and the assault element's route out to the flank and in.
func _plan_graphics(pl: Array, team: int, a: float, sel: bool) -> void:
	var cam := hud.world.cam.cam
	var obj: Vector3 = pl[1]
	var sbf: Vector3 = pl[2]
	var ap: Vector3 = pl[3]
	var key := "%d|%d|%d" % [int(obj.x), int(obj.z), Engine.get_frames_drawn()]
	if _plans_drawn.has(key):
		return
	_plans_drawn[key] = true
	var tc: Color = Defs.TEAM_COLORS[team].lightened(0.3)
	var fire := Color(1.0, 0.5, 0.3)
	var phase := String(pl[0])
	# support by fire: a bracket facing the objective, fire lines converging on it
	var to := Defs.flat(obj - sbf)
	if to.length() > 4.0:
		var d := to.normalized()
		var lat := d.cross(Vector3.UP)
		var firing := phase in ["assault", "fallback", "fix"] or (phase == "move")
		var fa := a * (1.0 if firing else 0.55)
		for k in [-1.0, 1.0]:
			_ground_path(sbf + lat * k * 3.0 + d * 2.5, obj - d * 4.0 + lat * k * 1.5, fire, fa * 0.75, 1.0, true, 1.6)
		var p0 := sbf + Vector3(0, 0.3, 0)
		if not cam.is_position_behind(p0):
			var sp := cam.unproject_position(p0)
			var bl := PackedVector2Array()
			for i in 9:
				var ang := -PI * 0.5 + (i - 4) * 0.2
				var pp := sbf + (d.rotated(Vector3.UP, ang + PI * 0.5) * 3.2)
				bl.append(cam.unproject_position(pp + Vector3(0, 0.3, 0)))
			draw_polyline(bl, Color(0, 0, 0, 0.5 * a), 5.0, true)
			draw_polyline(bl, Color(fire.r, fire.g, fire.b, a), 3.0, true)
			_tag(sp + Vector2(0, 16), "SBF", fire, a)
	# assault route: out to the flank, then in
	var g := Vector3.INF
	var cpts := []
	for sid in hud.orders:
		var o2: Array = hud.orders[sid]
		if o2.size() > 6 and o2[6] != null and (o2[6][1] as Vector3).distance_to(obj) < 0.5:
			var gr: Dictionary = _groups.get(sid, {})
			if not gr.is_empty() and int(gr["n"]) > 0:
				cpts.append(gr["c"])
	if phase in ["plan", "move", "fix"]:
		var start: Vector3 = sbf
		var bd := -1.0
		for c in cpts:
			var dd: float = Defs.flat(c - sbf).length()
			if dd > bd:
				bd = dd
				start = c
		if phase != "fix":
			_ground_path(start, ap, tc, a * 0.85, 1.0, true, 2.5, false)
		_ground_path(ap, obj, tc, a, 1.0, false, 3.5)
		var pa := ap + Vector3(0, 0.3, 0)
		if not cam.is_position_behind(pa):
			_tag(cam.unproject_position(pa) + Vector2(0, 16), "AP", tc, a)
	elif phase == "assault":
		_ground_path(ap, obj, tc, a, 1.0, false, 4.0)
	# the objective
	_dashed_ring(obj, 7.0, tc, a)
	var po := obj + Vector3(0, 0.3, 0)
	if not cam.is_position_behind(po):
		var so := cam.unproject_position(po)
		_tag(so + Vector2(0, -2), "OBJ " + Defs.grid_ref(obj), tc, a)
		var pn: String = String(Hud.PHASE_NAMES.get(phase, phase)).to_upper()
		UiKit.text(self, so + Vector2(-UiKit.text_width(pn, 10, 700) * 0.5, 16), pn, 10, Color(1, 1, 1, 0.85 * a), 700)


func _tag(at: Vector2, text: String, col: Color, a: float) -> void:
	var tw := UiKit.text_width(text, 10, 700)
	var r := Rect2(at.x - tw * 0.5 - 6, at.y - 12, tw + 12, 16)
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.78 * a), 4, Color(col.r, col.g, col.b, 0.8 * a), 1, 0.0), r)
	UiKit.text(self, Vector2(r.position.x + 6, r.position.y + 12), text, 10, Color(col.r, col.g, col.b, a), 700)


## Where the enemy was last seen: hollow diamonds that fade with age, with
## how long ago. (Enemies in sight right now have their own symbols.)
func _intel(cam: Camera3D, vs: Vector2, lt: int) -> void:
	var w := hud.world
	var teams: Array = [lt] if lt >= 0 else []
	if lt < 0 and w.view_team >= 0:
		teams = [w.view_team]
	for t in teams:
		if t >= w.team_info.size():
			continue
		var il: Array = (w.team_info[t] as Dictionary).get("intel", [])
		for it in il:
			var age := float(it[2])
			if age < 3.0:
				continue  # in sight: drawn as a unit
			var p: Vector3 = it[0] + Vector3(0, 0.5, 0)
			if cam.is_position_behind(p):
				continue
			var sp := cam.unproject_position(p)
			if sp.x < -20 or sp.y < -20 or sp.x > vs.x + 20 or sp.y > vs.y + 20:
				continue
			var a := clampf(1.0 - age / 90.0, 0.25, 0.9)
			var red := Color(1.0, 0.42, 0.36, a)
			var hs := 8.0 if String(it[1]) == "inf" else 10.0
			var d := PackedVector2Array([sp + Vector2(0, -hs), sp + Vector2(hs, 0), sp + Vector2(0, hs), sp + Vector2(-hs, 0), sp + Vector2(0, -hs)])
			draw_polyline(d, Color(0, 0, 0, 0.5 * a), 4.0, true)
			draw_polyline(d, red, 2.0, true)
			UiKit.text(self, sp + Vector2(-3, 4), "?", 10, red, 700)
			if age > 10.0:
				var at := "%ds" % int(age)
				UiKit.text(self, sp + Vector2(hs + 3, 4), at, 9, Color(1, 1, 1, 0.6 * a), 600)


## What each man of a selected squad is watching while it holds: a faint
## wedge on the ground from where he kneels, so you can see the squad's
## all-round cover (and the gap if a man goes down).
func _sectors(cam: Camera3D, a: float) -> void:
	for sid in _sel_sids:
		var g: Dictionary = _groups.get(sid, {})
		if g.is_empty():
			continue
		for s in g["mem"]:
			if s.life != Soldier.Life.ALIVE or not s.visible or s._view_speed > 0.4:
				continue
			var p: Vector3 = s.position + Vector3(0, 0.08, 0)
			if cam.is_position_behind(p):
				continue
			var yaw: float = s.rotation.y
			var pts := PackedVector2Array([cam.unproject_position(p)])
			var ok := true
			for i in 7:
				var q := p + Defs.dir_of(yaw + deg_to_rad(-24.0 + i * 8.0)) * 10.0
				if cam.is_position_behind(q):
					ok = false
					break
				pts.append(cam.unproject_position(q))
			if not ok:
				continue
			var col: Color = Defs.TEAM_COLORS[s.team].lightened(0.35) if s.team >= 0 else UiKit.ACCENT
			MapSymbols.poly(self, pts, Color(col.r, col.g, col.b, 0.07 * a))
			pts.append(pts[0])
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.28 * a), 1.0, true)


## How far the selected units can reach.
func _ranges(cam: Camera3D) -> void:
	var w := hud.world
	for sid in _sel_sids:
		var g: Dictionary = _groups.get(sid, {})
		if g.is_empty() or int(g["n"]) == 0:
			continue
		var r := 0.0
		for s in g["mem"]:
			if s.life == Soldier.Life.ALIVE:
				var wpn: Dictionary = s.cur_weapon()
				if not wpn.is_empty():
					r = maxf(r, float(wpn.get("range", 0.0)))
		if r > 0.0:
			_dashed_ring(g["c"], r, Color(1.0, 0.85, 0.5), 0.55)
	for id in w.input.sel_vehicles:
		var v = w.entity(id)
		if v and not v.gone:
			var vr := 95.0 if v.vdef.get("cannon", false) else 80.0
			_dashed_ring(v.position, vr, Color(1.0, 0.85, 0.5), 0.55)


## How far your eyes see, in pale blue: a watchtower being placed (and with a
## lookout up it) or picked out, a drone or a recon vehicle selected - the
## weapon ranges layer adds every selected vehicle's.
func _sight_rings() -> void:
	var w := hud.world
	var inp = w.input
	if inp.place_kind == "watchtower" and inp.ghost:
		var gp: Vector3 = inp.ghost.position
		gp.y = 0.0
		_dashed_ring(gp, Vision.TOWER, RECON_COL, 0.6)
		_dashed_ring(gp, Vision.TOWER_MANNED, RECON_COL, 0.3)
	if inp.sel_structure != 0:
		var st = w.entity(inp.sel_structure)
		if st is Structure and not st.gone and st.built and st.team >= 0 and (st.skind == "watchtower" or hud.map_layer("ranges")):
			var r := Vision.structure_sight(st)
			if r > 0.0:
				_dashed_ring(st.position, r, RECON_COL, 0.6)
	for id in inp.sel_vehicles:
		var v = w.entity(id)
		if v is Vehicle and not v.gone and (v.base() == "uav" or (v.vdef.has("sight") and (hud.map_layer("ranges") or float(v.vdef.sight) >= 75.0))):
			_dashed_ring(v.position, float(v.vdef.get("sight", Vision.VEHICLE)), RECON_COL, 0.55)


## The map grid the radio uses (A-H across, 1-8 down), drawn on the ground.
func _map_grid(cam: Camera3D, vs: Vector2) -> void:
	var col := Color(0.75, 0.9, 1.0, 0.16)
	var cell := MapDims.CELL
	for i in MapDims.GRID + 1:
		var x := -MapDims.HALF + i * cell
		var pts := PackedVector2Array()
		var pts2 := PackedVector2Array()
		for k in MapDims.GRID * 4 + 1:
			var z := -MapDims.HALF + k * cell * 0.25
			var p1 := Vector3(x, 0.2, z)
			var p2 := Vector3(z, 0.2, x)
			if cam.is_position_behind(p1) or cam.is_position_behind(p2):
				pts = PackedVector2Array()
				pts2 = PackedVector2Array()
				break
			pts.append(cam.unproject_position(p1))
			pts2.append(cam.unproject_position(p2))
		if pts.size() > 1:
			draw_polyline(pts, col, 1.0, true)
			draw_polyline(pts2, col, 1.0, true)
	for cx in MapDims.GRID:
		for cz in MapDims.GRID:
			var c := Vector3(-MapDims.HALF + cx * cell + 3.0, 0.2, -MapDims.HALF + cz * cell + 5.0)
			if cam.is_position_behind(c):
				continue
			var sp := cam.unproject_position(c)
			if sp.x < 0 or sp.y < 0 or sp.x > vs.x or sp.y > vs.y:
				continue
			UiKit.text(self, sp, "%s%d" % ["ABCDEFGHIJKLMNOP"[cx], cz + 1], 10, Color(0.75, 0.9, 1.0, 0.4), 700)


func _mark(name: String) -> void:
	hud.world.vp("ovl " + name, _pt)
	_pt = Time.get_ticks_usec()
