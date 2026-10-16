class_name HudCoopRoster
extends Control
## The command net, top right: every other commander on your side, in his
## colour, with what he's doing this moment ("Placing a trench · D4", "Aiming
## 155 mm Artillery · F3", "Ordered Bravo 2: ASSAULT E5", "Called in 155 mm
## Artillery · E5", "Commanding Bravo 2"),
## what he has under command, and two buttons - look at his view, or watch his
## screen live. A row lights up when its commander pings.
## Click a row to look where he's looking; double-click to watch it live.

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
func _status(p: CoCommand.Presence, owner_of: Dictionary) -> Array:
	var w := hud.world
	var act := w.coop.activity(p, true)
	if act != "":
		return [act, UiKit.ACCENT]
	# an order he has just sent
	var now := Time.get_ticks_msec()
	var best := ""
	var best_age := 6.0
	for sid in hud.orders:
		var o: Array = hud.orders[sid]
		if int(o[5]) < 0 or int(owner_of.get(int(sid), 0)) != p.peer:
			continue
		var age := (now - int(o[5])) / 1000.0
		if age < best_age:
			best_age = age
			best = "Ordered %s: %s" % [Squad.callsign_of(int(o[4]), int(sid)), HudOverlay._order_tag(o)]
	if best != "":
		return [best, UiKit.TEXT]
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
	# who commands what, once a redraw
	var owner_of := {}
	var units := {}
	for s in w.soldiers:
		if s.sid != 0 and s.owner_peer > 0 and s.life != Soldier.Life.DEAD:
			if not owner_of.has(s.sid):
				owner_of[s.sid] = s.owner_peer
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
	draw_style_box(UiKit.boxc(UiKit.PANEL, 8, UiKit.LINE, 1, 0.0), Rect2(0, 0, W, h))
	UiKit.text(self, Vector2(12, 18), "COMMAND NET", 11, UiKit.ACCENT, 700)
	# your own colour, so you can tell them which you are
	var me := co.color(w.local_peer)
	var hint := "Alt+click to ping"
	var hx := W - 12.0 - UiKit.text_width(hint, 10, 600)
	UiKit.text(self, Vector2(hx, 18), hint, 10, UiKit.DIM, 600)
	var yx := hx - 40.0
	draw_circle(Vector2(yx, 14), 4.5, me)
	UiKit.text(self, Vector2(yx + 8, 18), "You", 10, me, 700)
	draw_line(Vector2(10, HEAD_H), Vector2(W - 10, HEAD_H), UiKit.LINE, 1.0)
	var now := Time.get_ticks_msec()
	var y := HEAD_H + 2.0
	for p in all:
		var peer: int = p.peer
		var col := co.color(peer)
		var r := Rect2(5, y, W - 10, ROW_H - 3)
		var look := Rect2(r.end.x - 58, r.position.y + 9, 25, 25)
		var watch := Rect2(r.end.x - 29, r.position.y + 9, 25, 25)
		_rows.append([r, look, watch, peer])
		var watching: bool = w.cam != null and w.cam.shadow == peer
		var hot := r.has_point(_hover)
		# he just pinged: his row flashes in his colour
		var fl := 1.0 - clampf((now - int(co.flash.get(peer, -99999))) / 1400.0, 0.0, 1.0)
		var bg := Color(1, 1, 1, 0.05) if hot else Color(0, 0, 0, 0)
		if fl > 0.0:
			bg = bg.lerp(Color(col.r, col.g, col.b, 0.22), fl)
		if watching:
			bg = Color(col.r, col.g, col.b, 0.12)
		draw_style_box(UiKit.boxc(bg, 6, Color(col.r, col.g, col.b, 0.75) if watching else Color(0, 0, 0, 0), 1 if watching else 0, 0.0), r)
		draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(3, r.size.y - 14)), col)
		var idle: bool = p.idle >= 60
		var bc := r.position + Vector2(22, r.size.y * 0.5)
		draw_circle(bc, 14.5, Color(0, 0, 0, 0.45))
		draw_circle(bc, 13.0, col if not idle else col.darkened(0.45))
		var ini := co.initials(peer)
		var iw := UiKit.text_width(ini, 12, 700)
		draw_string(UiKit.font(700), bc + Vector2(-iw * 0.5, 4.5), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudCoop.INK)
		var x0 := r.position.x + 44.0
		var nm := co.pname(peer)
		var maxn := look.position.x - x0 - 8.0
		UiKit.text(self, Vector2(x0, r.position.y + 17), nm, 13, UiKit.TEXT, 700)
		var u: Array = units.get(peer, [0, 0])
		var ut := ""
		var pt := w.team_of_peer(peer)
		if w.local_team < 0 and pt >= 0:
			# watching: both sides' commanders are listed, so say whose each is
			ut = String(Defs.TEAM_NAMES[pt])
		if int(u[0]) > 0:
			ut += ("  ·  " if ut != "" else "") + "%d %s" % [int(u[0]), "squad" if int(u[0]) == 1 else "squads"]
		if int(u[1]) > 0:
			ut += ("  ·  " if ut != "" else "") + "%d %s" % [int(u[1]), "vehicle" if int(u[1]) == 1 else "vehicles"]
		var nw := UiKit.text_width(nm, 13, 700)
		if ut != "" and nw + 10.0 + UiKit.text_width(ut, 10, 600) < maxn:
			UiKit.text(self, Vector2(x0 + nw + 10.0, r.position.y + 17), ut, 10, UiKit.DIM, 600)
		var stt := _status(p, owner_of)
		var line: String = stt[0]
		while line.length() > 4 and UiKit.text_width(line, 11, 600) > maxn:
			line = line.substr(0, line.length() - 2)
		if line != String(stt[0]):
			line = line.strip_edges() + "…"
		UiKit.text(self, Vector2(x0, r.position.y + 34), line, 11, stt[1], 600)
		_button(look, "look", col, look.has_point(_hover), false)
		_button(watch, "watch", col, watch.has_point(_hover), watching)
		y += ROW_H


func _button(r: Rect2, kind: String, col: Color, hot: bool, on: bool) -> void:
	var bg := Color(0.12, 0.13, 0.12, 0.9)
	if on:
		bg = Color(col.r, col.g, col.b, 0.85)
	elif hot:
		bg = Color(0.2, 0.21, 0.19, 0.95)
	draw_style_box(UiKit.boxc(bg, 5, Color(col.r, col.g, col.b, 0.8) if (hot or on) else Color(1, 1, 1, 0.1), 1, 0.0), r)
	var c := r.get_center()
	var ink := HudCoop.INK if on else (Color(1, 1, 1) if hot else Color(0.85, 0.86, 0.82))
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
