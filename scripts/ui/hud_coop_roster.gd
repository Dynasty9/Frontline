class_name HudCoopRoster
extends Control
## The command net, top right: every other commander on your side, in his
## colour, with what he's doing this moment ("Placing a trench · D4", "Aiming
## 155 mm Artillery · F3", "Ordered Bravo 2: ASSAULT E5", "Called in 155 mm
## Artillery · E5", "Commanding Bravo 2"),
## what he has under command, and two buttons - look at his view, or watch his
## screen live. A row lights up when its commander pings.
## Click a row to look where he's looking; double-click to watch it live.
## Signal (docs/UI.md): no box, on the right scrim; a header and its rule,
## then a ruled row per commander with his colour as its edge.

const W := 300.0
const HEAD_H := 28.0
const ROW_H := 46.0

var hud: Hud
var need_h := 0.0  # how tall it is (the notifications go under it)
var _rows: Array = []  # [row, look button, watch button, peer]
var _hover := Vector2(-1, -1)
var _clicked := {}  # peer -> msec of the last click on his row (a second soon after watches him)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(ev: InputEvent) -> void:
	var w := hud.world
	if ev is InputEventMouseMotion:
		_hover = (ev as InputEventMouseMotion).position
		queue_redraw()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at := (ev as InputEventMouseButton).position
		for r in _rows:
			var peer := int(r[3])
			if (r[2] as Rect2).has_point(at):
				w.cam.toggle_shadow(peer)
				Sfx.ui("click")
				accept_event()
				return
			if (r[1] as Rect2).has_point(at) or (r[0] as Rect2).has_point(at):
				var now := Time.get_ticks_msec()
				if now - int(_clicked.get(peer, -9999)) < 400 and not (r[1] as Rect2).has_point(at):
					w.cam.toggle_shadow(peer)
				else:
					_look(peer)
				_clicked[peer] = now
				Sfx.ui("click")
				accept_event()
				return


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)
		queue_redraw()


func _get_tooltip(at: Vector2) -> String:
	for r in _rows:
		var nm := Net.player_name(int(r[3]))
		if (r[1] as Rect2).has_point(at):
			return "Look at %s's view" % nm
		if (r[2] as Rect2).has_point(at):
			return "Watch %s's screen live\n(pan, turn or zoom to take your camera back)" % nm
		if (r[0] as Rect2).has_point(at):
			return "Click: look where %s is looking.  Double-click: watch it live." % nm
	return ""


func _look(peer: int) -> void:
	var w := hud.world
	var p = w.coop.peers.get(peer)
	if p and w.cam:
		w.cam.glide_to(p.focus, p.dist, p.yaw, p.tilt)
		if w.director:
			w.director.active = false


## What he's doing, for his row: [text, colour].
func _status(p: CoCommand.Presence) -> Array:
	var w := hud.world
	var act := w.coop.activity(p, true)
	if act != "":
		return [act, UiKit.ACCENT]
	# Unit ownership is recruitment attribution, not the last order's sender.
	# something he has just built, called in or set training
	var dd: Array = w.coop.last_deed(p.peer, 15.0)
	if not dd.is_empty():
		return ["%s  ·  %s" % [dd[0], Defs.grid_ref(dd[1])], UiKit.TEXT]
	var names := []
	for sid in p.sq:
		names.append(Squad.callsign_of(maxi(0, w.local_team), int(sid)))
	for id in p.veh:
		var v = w.entity(id)
		if v is Vehicle:
			names.append(v.display_name())
	if p.unit != 0:
		var u = w.entity(p.unit)
		if u is Soldier:
			names.append(u.sname)
	if not names.is_empty():
		var s := "Commanding " + ", ".join(names.slice(0, 2))
		if names.size() > 2:
			s += " +%d" % (names.size() - 2)
		return [s, Color(0.86, 0.9, 0.84)]
	if p.st != 0:
		var st = w.entity(p.st)
		if st is Structure:
			return ["At %s" % st.display_name(), Color(0.86, 0.9, 0.84)]
	if p.idle >= 60:
		return ["Idle for %d min" % (p.idle / 60) if p.idle < 255 else "Away", UiKit.DIM]
	var where := Defs.grid_ref(p.focus)
	if p.tactical:
		return ["On the tactical map  ·  " + where, UiKit.DIM]
	return ["Watching " + where, UiKit.DIM]


func _draw() -> void:
	var w := hud.world
	_rows.clear()
	var co := w.coop
	var all: Array = co.list() if co else []
	if all.is_empty():
		need_h = 0.0
		return
	# recruitment attribution, once a redraw
	var seen_squads := {}
	var units := {}
	for s in w.soldiers:
		if s.sid != 0 and s.owner_peer > 0 and s.life != Soldier.Life.DEAD:
			if not seen_squads.has(s.sid):
				seen_squads[s.sid] = true
				var u: Array = units.get(s.owner_peer, [0, 0])
				u[0] += 1
				units[s.owner_peer] = u
	for v in w.vehicles:
		if v.owner_peer > 0 and v.vkind != "truck" and not v.gone:
			var u2: Array = units.get(v.owner_peer, [0, 0])
			u2[1] += 1
			units[v.owner_peer] = u2
	var h := HEAD_H + all.size() * ROW_H + 4.0
	need_h = h
	var hx := 2.0 + UiKit.caps_at(self, Vector2(2, 17), "Command net", 11, UiKit.FAINT)
	UiKit.mono_at(self, Vector2(hx + 8, 17), "%02d" % all.size(), 11, UiKit.DIM)
	# your own colour, so you can tell them which you are
	var me := co.color(w.local_peer)
	var hint := "ALT+CLICK PING"
	var hw := UiKit.mono_w(hint, 10)
	UiKit.mono_at(self, Vector2(W - 2.0 - hw, 17), hint, 10, UiKit.FAINT)
	var yx := W - 2.0 - hw - 46.0
	draw_rect(Rect2(yx, 9, 7, 7), me)
	UiKit.caps_at(self, Vector2(yx + 12, 17), "You", 10, me)
	UiKit.rule(self, Vector2(0, HEAD_H - 0.5), Vector2(W, HEAD_H - 0.5), UiKit.RULE2)
	var now := Time.get_ticks_msec()
	var y := HEAD_H + 2.0
	for p in all:
		var peer: int = p.peer
		var col := co.color(peer)
		var r := Rect2(0, y, W, ROW_H - 3)
		var look := Rect2(r.end.x - 54, r.position.y + 10, 24, 24)
		var watch := Rect2(r.end.x - 26, r.position.y + 10, 24, 24)
		_rows.append([r, look, watch, peer])
		var watching: bool = w.cam != null and w.cam.shadow == peer
		var hot := r.has_point(_hover)
		# he just pinged: his row flashes in his colour
		var fl := 1.0 - clampf((now - int(co.flash.get(peer, -99999))) / 1400.0, 0.0, 1.0)
		var bg := UiKit.fa(UiKit.TEXT, 0.05) if hot else Color(0, 0, 0, 0)
		if fl > 0.0:
			bg = bg.lerp(Color(col.r, col.g, col.b, 0.22), fl)
		if watching:
			bg = Color(col.r, col.g, col.b, 0.12)
		if bg.a > 0.0:
			draw_rect(r, bg)
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)), col)
		UiKit.rule(self, Vector2(0, r.end.y + 0.5), Vector2(W, r.end.y + 0.5))
		var idle: bool = p.idle >= 60
		# his initials on a square of his colour
		var bc := r.position + Vector2(24, r.size.y * 0.5)
		draw_rect(Rect2(bc - Vector2(12, 12), Vector2(24, 24)), col if not idle else col.darkened(0.45))
		var ini := co.initials(peer)
		var iw := UiKit.mono_w(ini, 12)
		draw_string(UiKit.mono(500), bc + Vector2(-iw * 0.5, 4.5), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudCoop.INK)
		var x0 := r.position.x + 46.0
		var nm := co.pname(peer)
		var maxn := look.position.x - x0 - 8.0
		UiKit.caps_at(self, Vector2(x0, r.position.y + 18), nm, 13, UiKit.TEXT)
		var u: Array = units.get(peer, [0, 0])
		var ut := ""
		var pt := w.team_of_peer(peer)
		if w.local_team < 0 and pt >= 0:
			# watching: both sides' commanders are listed, so say whose each is
			ut = String(Defs.TEAM_NAMES[pt])
		if int(u[0]) > 0:
			ut += (" · " if ut != "" else "") + "%d SQ" % int(u[0])
		if int(u[1]) > 0:
			ut += (" · " if ut != "" else "") + "%d VEH" % int(u[1])
		var nw := UiKit.caps_w(nm, 13)
		if ut != "" and nw + 10.0 + UiKit.mono_w(ut.to_upper(), 10) < maxn:
			UiKit.mono_at(self, Vector2(x0 + nw + 10.0, r.position.y + 18), ut.to_upper(), 10, UiKit.DIM)
		var stt := _status(p)
		var line: String = stt[0]
		while line.length() > 4 and UiKit.caps_w(line, 11) > maxn:
			line = line.substr(0, line.length() - 2)
		if line != String(stt[0]):
			line = line.strip_edges() + "…"
		UiKit.caps_at(self, Vector2(x0, r.position.y + 35), line, 11, stt[1])
		_button(look, "look", col, look.has_point(_hover), false)
		_button(watch, "watch", col, watch.has_point(_hover), watching)
		y += ROW_H


func _button(r: Rect2, kind: String, col: Color, hot: bool, on: bool) -> void:
	# square, a hairline round it; filled in his colour while it's on
	if on:
		draw_rect(r, Color(col.r, col.g, col.b, 0.85))
	elif hot:
		draw_rect(r, UiKit.fa(UiKit.TEXT, 0.08))
	draw_rect(r.grow(-0.5), Color(col.r, col.g, col.b, 0.8) if (hot or on) else UiKit.RULE2, false, 1.0)
	var c := r.get_center()
	var ink := HudCoop.INK if on else (UiKit.TEXT if hot else UiKit.DIM)
	if kind == "look":
		# a viewfinder: corner brackets round a dot
		var s := 6.5
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var k: Vector2 = c + q * s
			draw_line(k, k - Vector2(q.x * 3.5, 0), ink, 1.6, true)
			draw_line(k, k - Vector2(0, q.y * 3.5), ink, 1.6, true)
		draw_circle(c, 2.0, ink)
	else:
		# a screen with a live dot
		draw_rect(Rect2(c + Vector2(-7, -5.5), Vector2(14, 10)), ink, false, 1.5)
		draw_line(c + Vector2(-3, 6.5), c + Vector2(3, 6.5), ink, 1.5, true)
		var t := Time.get_ticks_msec() / 1000.0
		draw_circle(c + Vector2(0, -0.5), 2.3, Color(1.0, 0.35, 0.3, 0.6 + 0.4 * sin(t * 5.0)) if on else ink)
