class_name HudCoop
extends Control
## The other commanders on your side, drawn over the battlefield in their own
## colours: where each one is looking (a viewfinder on the ground), his cursor
## with his name and what he's doing on it, the units he has selected (a ring
## round them), what he's lining up before he commits - a building's ghost, a
## fire mission's footprint, an order being dragged out - and everyone's pings.
## A commander looking somewhere off your screen waits at its edge, pointing
## the way: click the marker to look there. Your own ping wheel (hold Alt and
## the left button) is drawn here too.

const INK := Color(0.03, 0.04, 0.04)
## The cursor: an arrow pointer, tip at the origin.
const ARROW := [Vector2(0, 0), Vector2(0, 16.5), Vector2(4.3, 12.6), Vector2(7.2, 19.0), Vector2(9.9, 17.8), Vector2(7.1, 11.6), Vector2(12.6, 11.6)]
const WHEEL_LABELS := {"attack": "Attack here", "omw": "On my way", "help": "Need support", "danger": "Danger",
	"defend": "Defend here", "look": "Look here"}
const WHEEL_R := 96.0

var hud: Hud
var chips: Array = []  # [Rect2, peer]: the edge markers drawn last frame (a click on one looks there)
var _taken: Array = []  # screen rects already used by edge markers this frame
var _vpm := Projection.IDENTITY  # world -> clip space, this frame
var _near := 0.3
var _vs := Vector2.ONE


## A click on an edge marker looks at that commander's view. True if it hit one.
func click(at: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	for c in chips:
		if (c[0] as Rect2).has_point(at):
			var p = hud.world.coop.peers.get(int(c[1]))
			if p:
				hud.world.cam.glide_to(p.focus, p.dist, p.yaw, p.tilt)
				Sfx.ui("click")
			return true
	return false


func _draw() -> void:
	var w := hud.world
	var co := w.coop
	chips.clear()
	_taken.clear()
	if co == null or w.cam == null or w.input == null:
		return
	var t0 := Time.get_ticks_usec()
	var cam := w.cam.cam
	var vs := get_viewport_rect().size
	_begin_projection(cam, vs)
	var show := bool(Settings.get_v("coop_show"))
	var all := co.list()
	var dbg := OS.has_environment("FL_DEBUG_COOP")
	var tp := t0
	if show:
		for p in all:
			if p.peer != w.cam.shadow:
				_view_frame(cam, vs, p)
		if dbg:
			tp = _mk("coop views", tp)
		for p in all:
			_selection(cam, p)
		if dbg:
			tp = _mk("coop selection", tp)
		for p in all:
			_intent(cam, p)
		if dbg:
			tp = _mk("coop intents", tp)
	_sketches(cam, co)
	if dbg:
		tp = _mk("coop sketches", tp)
	_pings(cam, vs, co)
	if dbg:
		tp = _mk("coop pings", tp)
	if show:
		for p in all:
			_cursor(cam, vs, p)
		for p in all:
			_edge_chip(cam, vs, p)
		if dbg:
			tp = _mk("coop cursors", tp)
	_shadow_frame(vs)
	_wheel()
	w.vp("co-commanders", t0)


## FL_DEBUG_COOP: the cost of each part, in the performance overlay.
func _mk(key: String, since: int) -> int:
	hud.world.vp(key, since)
	return Time.get_ticks_usec()


# --- helpers ------------------------------------------------------------------------------

static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## Sets up _gp for this frame: the camera's view and projection as one matrix.
## (Camera3D.unproject_position builds both again on every call, and this
## layer projects hundreds of points a frame.)
func _begin_projection(cam: Camera3D, vs: Vector2) -> void:
	_vpm = cam.get_camera_projection() * Projection(cam.get_camera_transform().affine_inverse())
	_near = cam.near
	_vs = vs


## A point on the ground, on the screen (INF behind the camera).
func _gp(_cam: Camera3D, p: Vector3, h := 0.2) -> Vector2:
	var c := _vpm * Vector4(p.x, h, p.z, 1.0)
	if c.w < _near:
		return Vector2.INF
	return Vector2((c.x / c.w * 0.5 + 0.5) * _vs.x, (-c.y / c.w * 0.5 + 0.5) * _vs.y)


static func _on_screen(sp: Vector2, vs: Vector2, margin := 0.0) -> bool:
	return sp != Vector2.INF and sp.x >= -margin and sp.y >= -margin and sp.x <= vs.x + margin and sp.y <= vs.y + margin


## A circle on the ground (`shade`: with a dark edge under it, to stand out
## on bright ground). Returns its highest point on the screen (for a tag),
## INF when not drawn.
## (Dashes go out as one batch of lines: each draw call has a cost of its own.)
func _ring(cam: Camera3D, c: Vector3, r: float, col: Color, a: float, dashed: bool, seg := 32, width := 2.0, shade := true) -> Vector2:
	if a <= 0.02:
		return Vector2.INF
	var pts := PackedVector2Array()
	var top := Vector2(0.0, INF)
	var tab: Array = _unit_circle(seg)
	var cs: PackedFloat32Array = tab[0]
	var sn: PackedFloat32Array = tab[1]
	if r <= 12.0:
		# small: the projected circle is all but an ellipse through three projected points
		var sc := _gp(cam, c)
		var sx := _gp(cam, c + Vector3(r, 0, 0))
		var sz := _gp(cam, c + Vector3(0, 0, r))
		if sc == Vector2.INF or sx == Vector2.INF or sz == Vector2.INF:
			return Vector2.INF
		var ax := sx - sc
		var az := sz - sc
		for i in seg + 1:
			var sp := sc + ax * cs[i] + az * sn[i]
			pts.append(sp)
			if sp.y < top.y:
				top = sp
	else:
		for i in seg + 1:
			var sp := _gp(cam, c + Vector3(cs[i] * r, 0, sn[i] * r))
			if sp == Vector2.INF:
				return Vector2.INF
			pts.append(sp)
			if sp.y < top.y:
				top = sp
	var cc := _a(col, a)
	if dashed:
		var segs := PackedVector2Array()
		for i in range(0, pts.size() - 1, 2):
			segs.append(pts[i])
			segs.append(pts[i + 1])
		if shade:
			draw_multiline(segs, Color(0, 0, 0, 0.4 * a), width + 2.0, true)
		draw_multiline(segs, cc, width, true)
	else:
		if shade:
			draw_polyline(pts, Color(0, 0, 0, 0.35 * a), width + 2.0, true)
		draw_polyline(pts, cc, width, true)
	return top


static var _circles := {}  # segments -> [cos, sin] round a circle (seg + 1 of each, closing it)


static func _unit_circle(seg: int) -> Array:
	var t: Array = _circles.get(seg, [])
	if t.is_empty():
		var cs := PackedFloat32Array()
		var sn := PackedFloat32Array()
		for i in seg + 1:
			cs.append(cos(TAU * i / seg))
			sn.append(sin(TAU * i / seg))
		t = [cs, sn]
		_circles[seg] = t
	return t


## A filled circle on the ground (a fire mission's beaten zone).
func _ground_disc(cam: Camera3D, c: Vector3, r: float, col: Color, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var ang := TAU * i / 32.0
		var sp := _gp(cam, c + Vector3(cos(ang) * r, 0, sin(ang) * r))
		if sp == Vector2.INF:
			return
		pts.append(sp)
	MapSymbols.poly(self, pts, _a(col, alpha))


## A shape on the ground, filled faintly and outlined. False if it couldn't be drawn.
func _ground_poly(cam: Camera3D, pts3: Array, col: Color, a: float, fill := 0.16) -> bool:
	var pts := PackedVector2Array()
	for p in pts3:
		var sp := _gp(cam, p)
		if sp == Vector2.INF:
			return false
		pts.append(sp)
	MapSymbols.poly(self, pts, _a(col, fill * a))
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.4 * a), 4.0, true)
	draw_polyline(pts, _a(col, 0.95 * a), 2.0, true)
	return true


## A dashed line over the ground.
func _ground_dash(cam: Camera3D, a3: Vector3, b3: Vector3, col: Color, a: float, width := 2.0, step := 2.4) -> void:
	var d := Defs.flat(b3 - a3)
	var n := clampi(int(d.length() / step), 2, 120)
	var prev := _gp(cam, a3)
	var segs := PackedVector2Array()
	for i in range(1, n + 1):
		var cur := _gp(cam, a3 + d * (float(i) / n))
		if i % 2 == 1 and prev != Vector2.INF and cur != Vector2.INF:
			segs.append(prev)
			segs.append(cur)
		prev = cur
	if segs.is_empty():
		return
	draw_multiline(segs, Color(0, 0, 0, 0.4 * a), width + 2.0, true)
	draw_multiline(segs, _a(col, a), width, true)


func _arrow_head(tip: Vector2, from: Vector2, col: Color, a: float, hs := 9.0) -> void:
	if tip.distance_to(from) < 3.0:
		return
	var dv := (tip - from).normalized()
	var nv := Vector2(-dv.y, dv.x)
	MapSymbols.poly(self, PackedVector2Array([tip + dv * hs, tip - dv * hs * 0.5 + nv * hs * 0.8, tip - dv * hs * 0.5 - nv * hs * 0.8]), _a(col, a))


## A round badge in a commander's colour with his initials.
func _badge(c: Vector2, peer: int, r: float, a: float) -> void:
	var co := hud.world.coop
	var col := co.color(peer)
	draw_circle(c, r + 1.5, Color(0, 0, 0, 0.5 * a))
	draw_circle(c, r, _a(col, a))
	var ini := co.initials(peer)
	var fs := int(clampf(r * 0.95, 8.0, 14.0))
	var tw := UiKit.text_width(ini, fs, 700)
	draw_string(UiKit.font(700), c + Vector2(-tw * 0.5, fs * 0.36), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _a(INK, a))


## His name on a pill in his colour, and (if any) what he's doing on a dark
## tab hanging off it. Returns the rectangle it took.
func _name_pill(at: Vector2, peer: int, nm: String, sub: String, a: float) -> Rect2:
	var col := hud.world.coop.color(peer)
	var nw := UiKit.text_width(nm, 12, 700) + 14.0
	var sw := (UiKit.text_width(sub, 11, 600) + 14.0) if sub != "" else 0.0
	var r := Rect2(at, Vector2(nw + sw, 20.0))
	if sub != "":
		draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.035, 0.86 * a), 10, _a(col, 0.55 * a), 1, 0.0), r)
		draw_string(UiKit.font(600), r.position + Vector2(nw + 7.0, 14.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.96, 0.92, a))
	draw_style_box(UiKit.boxc(_a(col, 0.97 * a), 10, Color(0, 0, 0, 0.3 * a), 1, 0.0), Rect2(at, Vector2(nw, 20.0)))
	draw_string(UiKit.font(700), at + Vector2(7.0, 14.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _a(INK, a))
	return r


# --- where he's looking --------------------------------------------------------------------

## Where he's looking: a viewfinder on the ground at the middle of his screen,
## turned the way he faces and sized to how far out he is, with his name under
## it. On the tactical map, the edge of all the ground his screen takes in as
## well (an RTS view is a wide trapezoid running off toward the horizon: over
## the battlefield those lines would only clutter it, and alone they wouldn't
## say where his attention is).
func _view_frame(cam: Camera3D, vs: Vector2, p: CoCommand.Presence) -> void:
	var w := hud.world
	var col := w.coop.color(p.peer)
	var a := 0.95 if p.idle < 45 else 0.5
	# looking at much the same ground as you: a whisper of a frame
	if Defs.flat(p.s_focus - w.cam.focus_pos).length() < 8.0 and absf(p.dist - w.cam.dist) < 10.0:
		a *= 0.35
	if p.s_quad.size() == 4 and hud.tactical:
		for i in 4:
			_ground_line(cam, p.s_quad[i], p.s_quad[(i + 1) % 4], _a(col, 0.5 * a), 1.3)
	var f := p.s_focus
	var fwd := Defs.dir_of(p.yaw)
	var right := fwd.cross(Vector3.UP).normalized()
	var hs := clampf(p.dist * 0.2, 4.0, 34.0)
	var arm := hs * 0.42
	var cs := [f + (fwd - right) * hs, f + (fwd + right) * hs, f + (-fwd + right) * hs, f + (-fwd - right) * hs]
	var segs := PackedVector2Array()
	for i in 4:
		var c: Vector3 = cs[i]
		var nx: Vector3 = cs[(i + 1) % 4]
		var pv: Vector3 = cs[(i + 3) % 4]
		var s0 := _gp(cam, c)
		var s1 := _gp(cam, c + (nx - c).normalized() * arm)
		var s2 := _gp(cam, c + (pv - c).normalized() * arm)
		if s0 == Vector2.INF or s1 == Vector2.INF or s2 == Vector2.INF:
			continue
		segs.append_array([s1, s0, s0, s2])
	if not segs.is_empty():
		draw_multiline(segs, Color(0, 0, 0, 0.45 * a), 6.0, true)
		draw_multiline(segs, _a(col, a), 3.0, true)
	# the way he's facing: a tick off the far side
	var t0 := _gp(cam, f + fwd * (hs + 0.5))
	var t1 := _gp(cam, f + fwd * (hs + maxf(2.0, hs * 0.3)))
	if t0 != Vector2.INF and t1 != Vector2.INF:
		_arrow_head(t1, t0, col, a, 6.0)
	var c0 := _gp(cam, f)
	if c0 != Vector2.INF:
		draw_circle(c0, 2.5, _a(col, 0.8 * a))
	# his name under the near side
	var nb := _gp(cam, f - fwd * hs)
	if _on_screen(nb, vs, -20.0):
		var nm := "%s'S VIEW" % w.coop.pname(p.peer).to_upper()
		var tw := UiKit.text_width(nm, 11, 700) + 16.0
		var at := nb + Vector2(-tw * 0.5, 20)
		# clear of the base names and unit symbols already on the screen
		for k in 4:
			if not hud.overlay._overlaps(Rect2(at + Vector2(0, -12), Vector2(tw, 16))):
				break
			at.y += 18.0
		hud.overlay._place_rect(Rect2(at + Vector2(0, -12), Vector2(tw, 16)))
		MapSymbols.glyph(self, "eye", at + Vector2(6, -4), 6.5, col, a, false)
		UiKit.text(self, at + Vector2(16, 0), nm, 11, _a(col, a), 700)


## A solid line over the ground, sampled so the bits behind the camera drop out.
func _ground_line(cam: Camera3D, a3: Vector3, b3: Vector3, col: Color, width := 1.5) -> void:
	var d := Defs.flat(b3 - a3)
	var n := clampi(int(d.length() / 6.0), 2, 60)
	var pts := PackedVector2Array()
	for i in n + 1:
		var sp := _gp(cam, a3 + d * (float(i) / n))
		if sp == Vector2.INF:
			if pts.size() > 1:
				draw_polyline(pts, col, width, true)
			pts = PackedVector2Array()
			continue
		pts.append(sp)
	if pts.size() > 1:
		draw_polyline(pts, col, width, true)


## A commander off your screen: a marker at the edge pointing to where he's
## looking, with how far it is. Click it to look there.
func _edge_chip(cam: Camera3D, vs: Vector2, p: CoCommand.Presence) -> void:
	var w := hud.world
	if p.peer == w.cam.shadow:
		return
	var sp := _gp(cam, p.s_focus, 0.5)
	if _on_screen(sp, vs, -60.0):
		return
	var e := _edge(cam, vs, p.s_focus)
	var col := w.coop.color(p.peer)
	var a := 0.95 if p.idle < 45 else 0.55
	var dist := int(round(Defs.flat(p.s_focus - w.cam.focus_pos).length() / 5.0) * 5.0)
	var txt := "%s  %d m" % [w.coop.pname(p.peer), dist]
	var tw := UiKit.text_width(txt, 11, 600)
	var dn: Vector2 = e[1]
	var c: Vector2 = e[0]
	var r := Rect2(c - Vector2(14 + (tw + 10.0) * (0.5 + dn.x * 0.5), 14), Vector2(28 + tw + 10.0, 28))
	# markers for several commanders the same way: stack them along the edge
	for i in 6:
		var hit := false
		for q in _taken:
			if (q as Rect2).grow(3.0).intersects(r):
				hit = true
				break
		if not hit:
			break
		r.position += Vector2(0, 32) if absf(dn.x) > absf(dn.y) else Vector2(r.size.x + 6.0, 0)
	_taken.append(r)
	chips.append([r, p.peer])
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.035, 0.84 * a), 14, _a(col, 0.8 * a), 1, 0.0), r)
	var bc := r.position + Vector2(14, 14) if dn.x <= 0.0 else r.end - Vector2(14, 14)
	_badge(bc, p.peer, 10.0, a)
	var tx := r.position.x + 30.0 if dn.x <= 0.0 else r.position.x + 9.0
	UiKit.text(self, Vector2(tx, r.position.y + 18.5), txt, 11, Color(1, 1, 1, 0.92 * a), 600)
	# the arrow, out from the badge the way his view lies
	var tip := bc + dn * 19.0
	_arrow_head(tip, bc, col, a, 6.0)


## Where a marker for a point off the screen waits: on the edge of the screen
## (clear of the top bar and the bottom panels), the way the point lies.
## [position, direction].
func _edge(cam: Camera3D, vs: Vector2, p: Vector3) -> Array:
	var c := vs * 0.5
	var q := Vector3(p.x, 0.5, p.z)
	var sp := cam.unproject_position(q)
	var d := sp - c
	if cam.is_position_behind(q):
		d = -d
	if d.length() < 1.0:
		d = Vector2(0, -1)
	var dn := d.normalized()
	var r := Rect2(Vector2(60, 96), vs - Vector2(120, 96 + 250))
	var rc := r.get_center()
	var t := minf((r.size.x * 0.5) / maxf(absf(dn.x), 0.0001), (r.size.y * 0.5) / maxf(absf(dn.y), 0.0001))
	return [rc + dn * t, dn]


## Watching through a co-commander's eyes: his colour round the screen and a
## caption saying whose view it is.
func _shadow_frame(vs: Vector2) -> void:
	var w := hud.world
	if w.cam.shadow == 0:
		return
	var col := w.coop.color(w.cam.shadow)
	draw_rect(Rect2(Vector2(2, 2), vs - Vector2(4, 4)), _a(col, 0.75), false, 3.0)
	var nm := "%s'S VIEW" % w.coop.pname(w.cam.shadow).to_upper()
	var sub := "pan, turn or zoom to take your camera back"
	var tw := UiKit.text_width(nm, 13, 700) + UiKit.text_width(sub, 12) + 62.0
	var r := Rect2(vs.x * 0.5 - tw * 0.5, 54, tw, 30)
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.035, 0.88), 15, _a(col, 0.9), 1, 0.0), r)
	var t := Time.get_ticks_msec() / 1000.0
	draw_circle(r.position + Vector2(17, 15), 5.0, _a(col, 0.55 + 0.45 * sin(t * 4.0)))
	UiKit.text(self, r.position + Vector2(30, 20), nm, 13, col, 700)
	UiKit.text(self, r.position + Vector2(40 + UiKit.text_width(nm, 13, 700), 20), sub, 12, UiKit.DIM)


# --- his cursor and what he has in hand ------------------------------------------------------

func _cursor(cam: Camera3D, vs: Vector2, p: CoCommand.Presence) -> void:
	if not p.cur_on:
		return
	var w := hud.world
	var sp := _gp(cam, p.s_cur, 0.3)
	if not _on_screen(sp, vs, -4.0):
		return
	var col := w.coop.color(p.peer)
	var a := 1.0 if p.idle < 20 else 0.5
	var pts := PackedVector2Array()
	var sh := PackedVector2Array()
	for v in ARROW:
		pts.append(sp + v)
		sh.append(sp + v * 1.12 + Vector2(-0.6, 0.4))
	MapSymbols.poly(self, sh, Color(0, 0, 0, 0.55 * a))
	MapSymbols.poly(self, pts, _a(col, a))
	pts.append(pts[0])
	draw_polyline(pts, _a(INK, 0.8 * a), 1.2, true)
	var act := w.coop.activity(p)
	if act == "" and p.on_map:
		act = "on the minimap"
	if act == "" and p.idle >= 60:
		act = "idle %dm" % (p.idle / 60) if p.idle < 255 else "away"
	_name_pill(sp + Vector2(12, 17), p.peer, w.coop.pname(p.peer), act, a)


## The units he has selected: a dashed ring in his colour round each squad
## (a small one under each man, closer in) with his initials on it.
func _selection(cam: Camera3D, p: CoCommand.Presence) -> void:
	var w := hud.world
	var col := w.coop.color(p.peer)
	var groups: Dictionary = hud.overlay._groups
	var close := w.cam.dist < 40.0
	# (with unit symbols up, his ring round the symbol and its tab already say whose)
	var tags := w.cam.dist < HudOverlay.CLOSE_Z or not hud.map_layer("units")
	for sid in p.sq:
		var g: Dictionary = groups.get(sid, {})
		if g.is_empty() or int(g["n"]) == 0:
			continue
		var c: Vector3 = g["c"]
		var r := 3.0
		for s in g["mem"]:
			if s.life == Soldier.Life.ALIVE:
				r = maxf(r, Defs.flat(s.position - c).length() + 2.4)
				if close and s.visible:
					_ring(cam, s.position, 0.75, col, 0.9, false, 14, 1.6)
		var top := _ring(cam, c, minf(r, 18.0), col, 0.85, true, 28)
		if top != Vector2.INF and tags:
			_badge(top + Vector2(0, -2), p.peer, 9.0, 0.95)
	for id in p.veh:
		var v = w.entity(id)
		if v is Vehicle and v.visible and not v.gone:
			var top2 := _ring(cam, v.position, 5.5, col, 0.85, true, 32)
			if top2 != Vector2.INF and tags:
				_badge(top2 + Vector2(0, -2), p.peer, 9.0, 0.95)
	if p.unit != 0:
		var u = w.entity(p.unit)
		if u is Soldier and u.visible:
			var top3 := _ring(cam, u.position, 1.4, col, 0.95, false, 20)
			if top3 != Vector2.INF:
				_badge(top3 + Vector2(0, -12), p.peer, 8.0, 0.95)
	if p.st != 0:
		var st = w.entity(p.st)
		if st is Structure and st.visible:
			_ring(cam, st.position, maxf(3.0, st.radius + 1.0), col, 0.75, true, 36)


## What he's lining up, before he commits it: the building's ghost (or the
## line he's dragging out), the fire mission's footprint, the order he's
## dragging - so two commanders don't put a barrage on the same wood, or
## trenches across each other.
func _intent(cam: Camera3D, p: CoCommand.Presence) -> void:
	var w := hud.world
	var col := w.coop.color(p.peer)
	match p.mode:
		CoCommand.Mode.PLACE:
			var def: Dictionary = Defs.BUILDINGS.get(p.kind, {})
			if def.is_empty():
				return
			var sz: Vector2 = def.size
			if p.drag and Defs.flat(p.s_a - p.s_b).length() > 1.5:
				var dir := Defs.flat(p.s_a - p.s_b).normalized()
				var side := dir.cross(Vector3.UP).normalized()
				var hw := sz.y * 0.5 + (TrenchNet.HALF_W if p.kind == "trench" else 0.0)
				_ground_poly(cam, [p.s_b + side * hw, p.s_a + side * hw, p.s_a - side * hw, p.s_b - side * hw], col, 1.0, 0.2)
				# a tick at each length of it, as it will be built
				var L := Defs.flat(p.s_a - p.s_b).length()
				var seg := maxf(1.0, sz.x)
				var k := seg
				while k < L - 0.5:
					var q := p.s_b + dir * k
					var t0 := _gp(cam, q + side * hw)
					var t1 := _gp(cam, q - side * hw)
					if t0 != Vector2.INF and t1 != Vector2.INF:
						draw_line(t0, t1, _a(col, 0.6), 1.2, true)
					k += seg
			else:
				var half := sz * 0.5
				var bs := Basis(Vector3.UP, p.ryaw)
				var pts := []
				for o in [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y), Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y)]:
					pts.append(p.s_a + bs * o)
				_ground_poly(cam, pts, col if p.ok else UiKit.BAD, 1.0, 0.22)
				# the way it faces
				var f := p.s_a + bs * Vector3(0, 0, -half.y - 1.5)
				var fa := _gp(cam, p.s_a + bs * Vector3(0, 0, -half.y))
				var fb := _gp(cam, f)
				if fa != Vector2.INF and fb != Vector2.INF:
					draw_line(fa, fb, _a(col, 0.9), 2.0, true)
					_arrow_head(fb, fa, col, 0.9, 6.0)
		CoCommand.Mode.SUPPORT:
			var sd: Dictionary = Defs.SUPPORT.get(p.kind, {})
			if sd.is_empty():
				return
			var gp := p.s_a
			var dir := Defs.flat(p.s_b - p.s_a)
			dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
			var side := dir.cross(Vector3.UP)
			var danger := Color(1.0, 0.42, 0.3)
			var tag_at := Vector2.INF
			match String(sd.get("shape", "circle")):
				"strafe":
					var a2 := gp - dir * 20.0
					var b2 := gp + dir * 20.0
					_ground_poly(cam, [a2 + side * 3.0, b2 + side * 3.0, b2 - side * 3.0, a2 - side * 3.0], col, 1.0, 0.14)
					_run_in(cam, gp - dir * 34.0, gp - dir * 22.0, col)
					tag_at = _gp(cam, b2 + side * 3.0)
				"line":
					for i in 4:
						var t2 := _ring(cam, gp + dir * (-15.0 + i * 10.0), 4.0, col, 0.9, false, 24)
						if i == 3:
							tag_at = t2
					_run_in(cam, gp - dir * 32.0, gp - dir * 20.0, col)
				"orbit":
					_ground_disc(cam, gp, float(sd.get("r", 38.0)), danger, 0.06)
					tag_at = _ring(cam, gp, float(sd.get("r", 38.0)), col, 0.95, true, 36, 2.5)
					_ring(cam, gp, Projectile.AC_R * 0.45, danger, 0.4, false, 32, 1.2)
				_:
					var rr := float(sd.get("r", 14.0))
					_ground_disc(cam, gp, rr, danger, 0.08)
					tag_at = _ring(cam, gp, rr, col, 0.95, false, 36, 2.5)
					_ring(cam, gp, rr * 0.55, danger, 0.5, true, 36, 1.4)
			var c0 := _gp(cam, gp)
			if c0 != Vector2.INF:
				_crosshair(c0, danger, 1.0)
			if tag_at != Vector2.INF:
				# danger close: a hazard sign on the edge of where it will land
				draw_circle(tag_at, 11.0, Color(0, 0, 0, 0.5))
				draw_circle(tag_at, 9.5, Color(0.1, 0.03, 0.02, 0.92))
				draw_arc(tag_at, 9.5, 0.0, TAU, 24, col, 2.0, true)
				_danger(tag_at + Vector2(0, -0.5), 5.2, danger, 1.0)
		CoCommand.Mode.ABILITY:
			var c1 := _gp(cam, p.s_a)
			if c1 != Vector2.INF:
				_crosshair(c1, col, 0.95)
		CoCommand.Mode.ORDER:
			var ocol: Color = MapSymbols.ORDER_COLORS.get(p.kind, col)
			# from the units he's sending to where he's sending them
			var from := _sel_centre(p)
			if from != Vector3.INF and Defs.flat(from - p.s_a).length() > 4.0:
				_ground_dash(cam, from, p.s_a, col, 0.75, 2.0)
			_ring(cam, p.s_a, 2.2, ocol, 0.95, false, 24, 2.2)
			if p.drag and Defs.flat(p.s_b - p.s_a).length() > 1.0:
				var a3 := _gp(cam, p.s_a)
				var b3 := _gp(cam, p.s_a + Defs.flat(p.s_b - p.s_a).normalized() * 7.0)
				if a3 != Vector2.INF and b3 != Vector2.INF:
					draw_line(a3, b3, Color(0, 0, 0, 0.45), 5.0, true)
					draw_line(a3, b3, _a(ocol, 0.95), 2.5, true)
					_arrow_head(b3, a3, ocol, 0.95, 8.0)


## The middle of what a commander has selected (INF if nothing).
func _sel_centre(p: CoCommand.Presence) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	var groups: Dictionary = hud.overlay._groups
	for sid in p.sq:
		var g: Dictionary = groups.get(sid, {})
		if not g.is_empty() and int(g["n"]) > 0:
			c += g["c"]
			n += 1
	for id in p.veh:
		var v = hud.world.entity(id)
		if v is Vehicle and not v.gone:
			c += v.position
			n += 1
	return Defs.flat(c / n) if n > 0 else Vector3.INF


func _run_in(cam: Camera3D, a3: Vector3, b3: Vector3, col: Color) -> void:
	var sa := _gp(cam, a3)
	var sb := _gp(cam, b3)
	if sa == Vector2.INF or sb == Vector2.INF:
		return
	draw_line(sa, sb, Color(0, 0, 0, 0.45), 5.0, true)
	draw_line(sa, sb, col, 3.0, true)
	_arrow_head(sb, sa, col, 1.0, 9.0)


func _crosshair(c: Vector2, col: Color, a: float) -> void:
	draw_arc(c, 9.0, 0.0, TAU, 24, Color(0, 0, 0, 0.45 * a), 4.0, true)
	draw_arc(c, 9.0, 0.0, TAU, 24, _a(col, a), 2.0, true)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 4.0, c + d * 14.0, _a(col, a), 2.0, true)


## The danger sign: a filled triangle with a mark in it.
func _danger(c: Vector2, s: float, col: Color, a: float) -> void:
	var tri := PackedVector2Array([c + Vector2(0, -s * 1.05), c + Vector2(s * 1.05, s * 0.8), c + Vector2(-s * 1.05, s * 0.8)])
	MapSymbols.poly(self, tri, _a(col, a))
	draw_line(c + Vector2(0, -s * 0.45), c + Vector2(0, s * 0.2), _a(INK, a), maxf(1.4, s * 0.24), true)
	draw_circle(c + Vector2(0, s * 0.52), maxf(0.9, s * 0.13), _a(INK, a))


# --- pings ---------------------------------------------------------------------------------

## A ping's sign: a dark disc ringed in the sender's colour, the sign in the
## colour of what it means.
func _ping_badge(c: Vector2, kind: String, ring: Color, mark: Color, r: float, a: float) -> void:
	draw_circle(c, r + 2.0, Color(0, 0, 0, 0.45 * a))
	draw_circle(c, r, Color(0.04, 0.05, 0.05, 0.92 * a))
	draw_arc(c, r, 0.0, TAU, 28, _a(ring, a), 2.4, true)
	if kind == "danger":
		_danger(c + Vector2(0, -0.5), r * 0.55, mark, a)
	else:
		MapSymbols.glyph(self, String(CoCommand.PING_GLYPH.get(kind, "eye")), c, r * 0.62, mark, a, false)


## Everyone's pings: rings spreading over the ground and a pin with the sign,
## who sent it and what it says; one off the screen waits at its edge.
func _pings(cam: Camera3D, vs: Vector2, co: CoCommand) -> void:
	var w := hud.world
	var now := Time.get_ticks_msec()
	for pg in co.pings:
		var age := (now - int(pg.born)) / 1000.0
		var fade := clampf((float(pg.life) - age) / 1.5, 0.0, 1.0) * clampf(age * 8.0, 0.0, 1.0)
		if fade <= 0.01:
			continue
		var pos := co.ping_pos(pg)
		var col := co.color(pg.peer)
		var mark: Color = CoCommand.PING_COLORS.get(pg.kind, Color(0.96, 0.97, 0.94))
		var g := _gp(cam, pos)
		var mine: bool = pg.peer == w.local_peer
		var who: String = "You" if mine else co.pname(pg.peer)
		if pg.kind == "omw" and not mine and co.peers.has(pg.peer):
			# on his way: from the units he has selected to the spot
			var from := _sel_centre(co.peers[pg.peer])
			if from != Vector3.INF:
				_ground_dash(cam, from, pos, col, 0.7 * fade, 2.0, 3.0)
		# how far, to the nearest 5 m (steadier to read while the camera moves)
		var dm := int(round(Defs.flat(pos - w.cam.focus_pos).length() / 5.0) * 5.0)
		if _on_screen(g, vs, -10.0):
			for k in 2:
				var ph := fmod(age * 0.85 + k * 0.5, 1.0)
				_ring(cam, pos, 1.2 + ph * 7.5, col, (1.0 - ph) * 0.9 * fade, false, 20, 2.0, false)
			var pop := 1.0 + maxf(0.0, 0.25 - age) * 2.0
			var bc := g + Vector2(0, -40)
			draw_line(g, bc, _a(col, fade), 2.0, true)
			draw_circle(g, 3.2, _a(col, fade))
			_ping_badge(bc, pg.kind, col, mark, 12.0 * pop, fade)
			# who, what, how far (on a dark pill: no outline needed on the text)
			var dist := "%d m" % dm
			var nw := UiKit.text_width(who, 11, 700)
			var tw := UiKit.text_width(pg.text, 11, 600)
			var dw := UiKit.text_width(dist, 10, 600)
			var r := Rect2(bc + Vector2(17, -10), Vector2(nw + tw + dw + 32, 20))
			draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.035, 0.85 * fade), 10, _a(col, 0.6 * fade), 1, 0.0), r)
			draw_string(UiKit.font(700), r.position + Vector2(9, 14), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _a(col, fade))
			draw_string(UiKit.font(600), r.position + Vector2(16 + nw, 14), pg.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.96, 0.97, 0.94, fade))
			draw_string(UiKit.font(600), r.position + Vector2(24 + nw + tw, 14), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _a(UiKit.DIM, fade))
		else:
			var e := _edge(cam, vs, pos)
			var ec: Vector2 = e[0]
			var dn: Vector2 = e[1]
			var pulse := 1.0 + 0.12 * sin(age * 9.0) if age < 3.0 else 1.0
			_arrow_head(ec + dn * 20.0, ec, col, fade, 7.0)
			_ping_badge(ec, pg.kind, col, mark, 12.0 * pulse, fade)
			var lbl := "%s  %d m" % [who, dm]
			var lw := UiKit.text_width(lbl, 10, 600)
			UiKit.text(self, ec + Vector2(-lw * 0.5, 27), lbl, 10, _a(col, fade), 600)


## Lines drawn on the map (Alt+right-drag): each in its commander's colour,
## drawing itself in as it arrives, an arrowhead where it ends and his
## initials where it starts. They fade after a while, like a grease pencil
## line wiped off the map case.
func _sketches(cam: Camera3D, co: CoCommand) -> void:
	var w := hud.world
	var now := Time.get_ticks_msec()
	for sk in co.sketches:
		var age := (now - int(sk.born)) / 1000.0
		var fade := clampf((CoCommand.SKETCH_LIFE - age) / 2.5, 0.0, 1.0)
		var mine: bool = sk.peer == w.local_peer
		_stroke(cam, sk.pts, co.color(sk.peer), fade, 1.0 if mine else clampf(age / 0.6, 0.0, 1.0), 0 if mine else int(sk.peer))
	var inp := w.input
	if inp.sketching and inp.sketch_pts.size() >= 1:
		var live := inp.sketch_pts.duplicate()
		live.append(w.cam.ground_point(inp._mouse()))
		_stroke(cam, live, co.color(w.local_peer), 0.9, 1.0, 0)


func _stroke(cam: Camera3D, pts: PackedVector3Array, col: Color, a: float, grow: float, peer: int) -> void:
	if pts.size() < 2 or a <= 0.01:
		return
	var n := mini(pts.size(), maxi(2, ceili(pts.size() * grow)))
	var runs: Array = []
	var cur := PackedVector2Array()
	for i in n:
		var sp := _gp(cam, pts[i], 0.3)
		if sp == Vector2.INF:
			if cur.size() > 1:
				runs.append(cur)
			cur = PackedVector2Array()
			continue
		cur.append(sp)
	if cur.size() > 1:
		runs.append(cur)
	for r in runs:
		draw_polyline(r, _a(col, 0.16 * a), 11.0, true)
		draw_polyline(r, Color(0, 0, 0, 0.45 * a), 6.5, true)
		draw_polyline(r, _a(col, a), 3.5, true)
	if runs.is_empty():
		return
	var last: PackedVector2Array = runs.back()
	if grow >= 1.0 and last.size() >= 2:
		var tip := last[last.size() - 1]
		var back := last[maxi(0, last.size() - 3)]
		if tip.distance_to(back) > 4.0:
			var dv := (tip - back).normalized()
			var nv := Vector2(-dv.y, dv.x)
			MapSymbols.poly(self, PackedVector2Array([tip + dv * 14.0, tip - dv * 4.0 + nv * 10.0, tip - dv * 4.0 - nv * 10.0]), Color(0, 0, 0, 0.45 * a))
			MapSymbols.poly(self, PackedVector2Array([tip + dv * 11.0, tip - dv * 3.0 + nv * 8.0, tip - dv * 3.0 - nv * 8.0]), _a(col, a))
	var first: PackedVector2Array = runs[0]
	if peer != 0:
		_badge(first[0], peer, 9.0, a)
	else:
		draw_circle(first[0], 4.0, _a(col, a))


## Your own ping wheel while Alt and the left button are held: let go on a
## spoke to send that ping, in the middle to call it off.
func _wheel() -> void:
	var inp := hud.world.input
	if not inp.ping_wheel_open():
		return
	var co := hud.world.coop
	var c: Vector2 = inp.ping_at
	var pick: String = inp.ping_wheel_pick()
	var me := co.color(hud.world.local_peer)
	draw_circle(c, WHEEL_R + 3.0, Color(0, 0, 0, 0.35))
	draw_circle(c, WHEEL_R, Color(0.03, 0.035, 0.035, 0.72))
	draw_arc(c, WHEEL_R, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.0, true)
	var n := CoCommand.WHEEL.size()
	var step := TAU / n
	for i in n:
		var k: String = CoCommand.WHEEL[i]
		var ang := i * step
		var dir := Vector2(sin(ang), -cos(ang))
		var hot := k == pick
		if hot:
			var wedge := PackedVector2Array()
			for j in 9:
				var a2 := ang - step * 0.5 + step * j / 8.0
				wedge.append(c + Vector2(sin(a2), -cos(a2)) * WHEEL_R)
			for j in 9:
				var a3 := ang + step * 0.5 - step * j / 8.0
				wedge.append(c + Vector2(sin(a3), -cos(a3)) * (PlayerInput.PING_WHEEL_R + 2.0))
			MapSymbols.poly(self, wedge, _a(me, 0.28))
		# the spokes between the choices
		var sa := ang + step * 0.5
		var sd := Vector2(sin(sa), -cos(sa))
		draw_line(c + sd * (PlayerInput.PING_WHEEL_R + 4.0), c + sd * (WHEEL_R - 4.0), Color(1, 1, 1, 0.08), 1.0, true)
		var bc := c + dir * 62.0
		_ping_badge(bc, k, me if hot else Color(1, 1, 1, 0.35), CoCommand.PING_COLORS.get(k, Color(0.96, 0.97, 0.94)), 16.0 if hot else 13.0, 1.0)
		var lbl: String = WHEEL_LABELS.get(k, k)
		var lw := UiKit.text_width(lbl, 11, 700)
		var lp := c + dir * (WHEEL_R + 14.0)
		UiKit.text(self, lp + Vector2(-lw * 0.5 + dir.x * lw * 0.5, 4.0), lbl, 11, me if hot else Color(1, 1, 1, 0.75), 700)
	draw_circle(c, PlayerInput.PING_WHEEL_R - 8.0, Color(0, 0, 0, 0.35))
	var mid := "cancel" if pick == "" else ""
	if mid != "":
		var mw := UiKit.text_width(mid, 10, 600)
		UiKit.text(self, c + Vector2(-mw * 0.5, 4.0), mid, 10, UiKit.DIM, 600)
	draw_line(c, inp._mouse(), _a(me, 0.6), 1.5, true)
