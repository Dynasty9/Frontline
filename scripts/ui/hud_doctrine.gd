class_name HudDoctrine
extends Control
## The doctrine tree (its key, or the Research Post's card): how a side grows
## from a few squads and light vehicles into a force on land, in the air and
## at sea. A lane for each branch - land, air, sea and the infantry's kit -
## and in it the steps, left to right in the order they must come, joined
## by rules to what they need. Each step says what it costs, how long it
## takes and what it unlocks; a step that's done is ticked, one under way
## shows how far along it is, one that can start now is lit, and one that
## can't yet is faint. Click a lit step to start it at the Research Post with
## the shortest queue. Laid out the Signal way (docs/UI.md): data on ink,
## corner ticks rather than boxes, one accent for what can be done now.

signal closed

const NODE_W := 268.0
const NODE_H := 60.0
const ROW_GAP := 10.0
const COL_GAP := 44.0
const LANE_W := 104.0  # the branch names down the left
const HEAD_H := 62.0
const FOOT_H := 64.0
const LANE_GAP := 14.0

var hud: Hud
var _rects := {}  # upgrade key -> Rect2 (this frame's layout)
var _hover := ""
var _close_r := Rect2()
var _layout_team := -2
var _place := {}  # key -> [branch index, col, row]
var _lane_rows: Array = []  # rows per branch
var _flash := ""  # a word to the commander in the footer (no Research Post...)
var _flash_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	visible = true
	_hover = ""
	UiMotion.arrive(self, Vector2(0, 1))
	Sfx.ui("ui_whoosh", -14.0)


func _process(dt: float) -> void:
	if not visible:
		return
	_flash_t -= dt
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := ""
		for k in _rects:
			if (_rects[k] as Rect2).has_point(ev.position):
				h = k
		if h != _hover:
			_hover = h
			if h != "":
				Sfx.ui("ui_tick", -22.0)
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_RIGHT or _close_r.has_point(mb.position):
			closed.emit()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for k in _rects:
			if (_rects[k] as Rect2).has_point(mb.position):
				_start(String(k))
				return
		if not _panel_rect().has_point(mb.position):
			closed.emit()


## Starts a step at the Research Post with the shortest queue.
func _start(key: String) -> void:
	var w := hud.world
	var lt := w.local_team
	if _state(key, lt) != "ready":
		Sfx.ui("click", -14.0, 0.7)
		return
	var best: Structure = null
	for st in w.structures:
		if st.skind == "research" and st.team == lt and st.built and not st.gone:
			if best == null or st.queue_items.size() < best.queue_items.size():
				best = st
	if best == null:
		_flash = "Build a Research Post first: engineers put one up from Base."
		_flash_t = 4.0
		Sfx.ui("click", -12.0, 0.7)
		return
	if best.queue_items.size() >= 4:
		_flash = "Every Research Post is busy: four steps queued at each."
		_flash_t = 4.0
		return
	w.send_cmd({"t": "research", "building": best.eid, "item": key})
	Sfx.ui("click")


## done, busy (under way or queued), ready (can start now) or locked.
func _state(key: String, lt: int) -> String:
	var w := hud.world
	if lt < 0 or lt >= w.team_info.size():
		return "locked"
	var have: Array = (w.team_info[lt] as Dictionary).get("up", [])
	if key in have:
		return "done"
	if _progress(key, lt) >= 0.0:
		return "busy"
	for rq in Defs.requires_of(key):
		if not rq in have:
			return "locked"
	return "ready"


## How far along a step is at a Research Post (0..1), -1 if it isn't queued;
## a queued step that hasn't begun is 0.
func _progress(key: String, lt: int) -> float:
	for st in hud.world.structures:
		if st.skind != "research" or st.team != lt or st.gone:
			continue
		var q: Array = st.queue_items
		var i := q.find(key)
		if i == 0:
			return clampf(st.queue_frac, 0.0, 1.0)
		if i > 0:
			return 0.0
	return -1.0


func _layout(lt: int) -> void:
	if _layout_team == lt:
		return
	_layout_team = lt
	_place.clear()
	_lane_rows.clear()
	for bi in Defs.BRANCHES.size():
		var br := String(Defs.BRANCHES[bi][0])
		var per_col := {}
		var rows := 0
		for k in Defs.UPGRADES:
			var u: Dictionary = Defs.UPGRADES[k]
			if not lt in u.teams or String(u.get("branch", "inf")) != br:
				continue
			var c := int(u.get("col", 0))
			var r := int(per_col.get(c, 0))
			per_col[c] = r + 1
			_place[k] = [bi, c, r]
			rows = maxi(rows, r + 1)
		_lane_rows.append(rows)


func _panel_rect() -> Rect2:
	var rows := 0
	var lanes := 0
	for r in _lane_rows:
		rows += int(r)
		if int(r) > 0:
			lanes += 1
	var w := LANE_W + 3.0 * NODE_W + 2.0 * COL_GAP + 40.0
	var h := HEAD_H + rows * (NODE_H + ROW_GAP) + lanes * LANE_GAP + FOOT_H
	var vs := size
	var k := minf(1.0, minf((vs.x - 32.0) / w, (vs.y - 32.0) / h))
	return Rect2((vs - Vector2(w, h)) * 0.5, Vector2(w, h)) if k >= 1.0 else Rect2(Vector2(16, 16), Vector2(w, h))


func _draw() -> void:
	var w := hud.world
	var lt := w.local_team
	if lt < 0:
		return
	_layout(lt)
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.fa(UiKit.INK, 0.72))
	var pr := _panel_rect()
	draw_rect(pr, UiKit.fa(UiKit.INK, 0.9))
	UiKit.ticks(self, pr, UiKit.RULE2, UiKit.TICK_ARM, 0.0)
	var x0 := pr.position.x + 20.0
	var y0 := pr.position.y + 26.0
	# the head: the word, the side, what there is to spend, the posts at work
	var hx := x0 + UiKit.caps_at(self, Vector2(x0, y0), "Doctrine", 17, UiKit.TEXT)
	hx += 12.0 + UiKit.caps_at(self, Vector2(hx + 12.0, y0), Defs.TEAM_NAMES[lt], 11, Defs.TEAM_COLORS[lt].lightened(0.35))
	var info: Dictionary = w.team_info[lt]
	var have: Array = info.get("up", [])
	var total := 0
	var done := 0
	for k in Defs.UPGRADES:
		if lt in Defs.UPGRADES[k].teams:
			total += 1
			if k in have:
				done += 1
	var posts := 0
	var queued := 0
	for st in w.structures:
		if st.skind == "research" and st.team == lt and st.built and not st.gone:
			posts += 1
			queued += st.queue_items.size()
	var right := "SUP %d   ·   %d/%d DONE   ·   " % [int(info.get("supply", 0)), done, total]
	right += ("POSTS %d   ·   QUEUED %d" % [posts, queued]) if posts > 0 else "NO RESEARCH POST: BUILD ONE FROM BASE"
	var rx := pr.end.x - 20.0
	var kl := Keys.label("doctrine").to_upper()
	_close_r = Rect2()
	if kl != "":
		var kw := UiKit.mono_w(kl, 10) + 8.0
		UiKit.key(self, Vector2(rx - kw, y0 - 11.0), kl, false, 10)
		_close_r = Rect2(rx - kw - 4.0, y0 - 15.0, kw + 8.0, 22.0)
		rx -= kw + 12.0
	UiKit.mono_at(self, Vector2(rx - UiKit.mono_w(right, 11), y0), right, 11, UiKit.DIM if posts > 0 else UiKit.WARN)
	UiKit.rule(self, Vector2(x0, y0 + 12.5), Vector2(pr.end.x - 20.0, y0 + 12.5))
	# the lanes
	_rects.clear()
	var y := pr.position.y + HEAD_H
	var lane_y := []
	for bi in Defs.BRANCHES.size():
		lane_y.append(y)
		var rows := int(_lane_rows[bi])
		if rows == 0:
			continue
		var lh := rows * (NODE_H + ROW_GAP) - ROW_GAP
		UiKit.caps_at(self, Vector2(x0, y + 16.0), String(Defs.BRANCHES[bi][1]), 13, UiKit.TEXT)
		var nb := 0
		var nd := 0
		for k in _place:
			if int(_place[k][0]) == bi:
				nb += 1
				if k in have:
					nd += 1
		UiKit.mono_at(self, Vector2(x0, y + 34.0), "%d/%d" % [nd, nb], 11, UiKit.GOOD if nd == nb else UiKit.FAINT)
		draw_line(Vector2(x0 + LANE_W - 14.0, y + 2.0), Vector2(x0 + LANE_W - 14.0, y + lh - 2.0), UiKit.RULE2, 1.0)
		y += lh + ROW_GAP + LANE_GAP
	for k in _place:
		var pl: Array = _place[k]
		var nx := x0 + LANE_W + int(pl[1]) * (NODE_W + COL_GAP)
		var ny: float = float(lane_y[int(pl[0])]) + int(pl[2]) * (NODE_H + ROW_GAP)
		_rects[k] = Rect2(nx, ny, NODE_W, NODE_H)
	# what each step needs, as rules from its right edge to the next one's left
	for k in _rects:
		for rq in Defs.requires_of(k):
			if not _rects.has(rq):
				continue
			var a: Rect2 = _rects[rq]
			var b: Rect2 = _rects[k]
			var p0 := Vector2(a.end.x + 2.0, a.position.y + NODE_H * 0.5)
			var p1 := Vector2(b.position.x - 2.0, b.position.y + NODE_H * 0.5)
			var mx := (p0.x + p1.x) * 0.5
			var lit: bool = rq in have
			var col := UiKit.fa(UiKit.ACCENT, 0.7) if lit else UiKit.RULE2
			draw_polyline(PackedVector2Array([p0, Vector2(mx, p0.y), Vector2(mx, p1.y), p1]), col, 1.0)
			draw_rect(Rect2(p1 - Vector2(3, 2), Vector2(3, 4)), col)
	for k in _rects:
		_node(String(k), _rects[k], lt, have)
	# the foot: the step under the hand, in full; else how to read the tree
	var fy := pr.end.y - FOOT_H + 18.0
	UiKit.rule(self, Vector2(x0, fy - 12.5), Vector2(pr.end.x - 20.0, fy - 12.5))
	if _flash_t > 0.0:
		UiKit.text(self, Vector2(x0, fy + 6.0), _flash, 13, UiKit.WARN, 500)
	elif _hover != "" and Defs.UPGRADES.has(_hover):
		var u: Dictionary = Defs.UPGRADES[_hover]
		var lines := MapSymbols.wrap(String(u.desc), 13, 400, pr.size.x - 40.0)
		UiKit.text(self, Vector2(x0, fy + 2.0), String(lines[0]) if not lines.is_empty() else "", 13, UiKit.TEXT, 400)
		var un: Array = []
		for it in u.get("unlocks", []):
			if Defs.VEHICLES.has(it):
				un.append(String(Defs.VEHICLES[it].name))
		if not un.is_empty():
			UiKit.mono_at(self, Vector2(x0, fy + 24.0), ("UNLOCKS  " + "  ·  ".join(un)).to_upper(), 10, UiKit.ACCENT)
		elif lines.size() > 1:
			UiKit.text(self, Vector2(x0, fy + 22.0), String(lines[1]), 13, UiKit.TEXT, 400)
	else:
		UiKit.mono_at(self, Vector2(x0, fy + 6.0), "CLICK A LIT STEP TO RESEARCH IT  ·  EACH STEP NEEDS THE ONE BEFORE IT  ·  RIGHT-CLICK OR %s TO CLOSE" % (kl if kl != "" else "ESC"), 10, UiKit.FAINT)


## A step: its name, what it costs and takes (or how far along it is), and
## what it unlocks.
func _node(key: String, r: Rect2, lt: int, have: Array) -> void:
	var u: Dictionary = Defs.UPGRADES[key]
	var st := _state(key, lt)
	var hov := key == _hover
	var name_col := UiKit.TEXT
	var tick_col := UiKit.RULE2
	var a := 1.0
	match st:
		"done":
			name_col = UiKit.DIM
			tick_col = UiKit.fa(UiKit.GOOD, 0.6)
		"busy":
			tick_col = UiKit.ACCENT
		"ready":
			tick_col = UiKit.ACCENT if hov else UiKit.fa(UiKit.ACCENT, 0.55)
		"locked":
			a = 0.5
	if hov or st == "ready":
		draw_rect(r, UiKit.fa(UiKit.ACCENT, 0.1 if hov else 0.04))
	UiKit.ticks(self, r, tick_col, 6.0, 0.0)
	var x := r.position.x + 10.0
	var y := r.position.y + 20.0
	UiKit.caps_at(self, Vector2(x, y), String(u.name), 13, UiKit.fa(name_col, a))
	var code := ""
	var cc := UiKit.FAINT
	match st:
		"done":
			code = "DONE"
			cc = UiKit.GOOD
			var cx := r.end.x - 12.0
			draw_polyline(PackedVector2Array([Vector2(cx - 10, y - 5), Vector2(cx - 6, y - 1), Vector2(cx, y - 9)]), UiKit.GOOD, 1.6, true)
		"busy":
			var f := _progress(key, lt)
			code = "RESEARCHING %d%%" % int(f * 100.0) if f > 0.0 else "QUEUED"
			cc = UiKit.ACCENT
			draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x * f, 2.0), UiKit.ACCENT)
		"ready":
			code = "%d SUP  ·  %dS" % [int(u.cost), int(u.time)]
			cc = UiKit.ACCENT
		"locked":
			var need := []
			for rq in Defs.requires_of(key):
				if not rq in have:
					need.append(String(Defs.UPGRADES[rq].name))
			code = "NEEDS " + ", ".join(need).to_upper()
	if st != "done":
		var cw := UiKit.mono_w(code, 10)
		while code.length() > 4 and cw > r.size.x - 20.0:
			code = code.substr(0, code.length() - 2)
			cw = UiKit.mono_w(code, 10)
	UiKit.mono_at(self, Vector2(x, y + 17.0), code, 10, UiKit.fa(cc, a))
	# what it unlocks, as many as fit
	var un: Array = u.get("unlocks", [])
	var line := ""
	if un.is_empty():
		line = String(u.desc)
	else:
		var shown := 0
		for it in un:
			var nm := String(Defs.VEHICLES[it].name) if Defs.VEHICLES.has(it) else String(it)
			var cand := nm if line == "" else line + "  ·  " + nm
			var more := "  +%d" % (un.size() - shown - 1) if shown < un.size() - 1 else ""
			if UiKit.mono_w((cand + more).to_upper(), 10) > r.size.x - 20.0 and shown > 0:
				line += "  +%d" % (un.size() - shown)
				break
			line = cand
			shown += 1
	line = line.to_upper()
	while line.length() > 4 and UiKit.mono_w(line, 10) > r.size.x - 20.0:
		line = line.substr(0, line.length() - 2)
	UiKit.mono_at(self, Vector2(x, y + 33.0), line, 10, UiKit.fa(UiKit.DIM if st != "locked" else UiKit.FAINT, a))
