class_name HudWatch
extends Control
## The watch officer at the commander's elbow (docs/UI.md, Layout): which of
## your squads are standing about with nothing to do, and which have come under
## fire while you were looking somewhere else. Everything here is read from
## what every peer already has (the men, their states, the team's orders), so
## it needs nothing replicated.
##
## Idle squads show as one line above the fire missions, IDLE 02 [.], hidden
## when there are none; the key (or a click) selects the next and takes the
## camera there. A squad under fire off screen gets a caution in the log and a
## ping on the map, so the jump key goes to it; once a squad has been reported
## it isn't again for a while, however long the fight goes on.

const CHECK_EVERY := 0.5  # seconds between looks at the squads
const IDLE_AFTER := 8.0  # how long a squad has to stand about before it counts
const ARRIVED := 14.0  # metres from its move order's end that count as there
const FIRE_QUIET := 45.0  # a squad reported under fire isn't again for this long
const FIRE_GAP := 6.0  # nor any squad this soon after another
const SUPP_FIRE := 45.0  # mean suppression that is being shot at, not just near it

var hud: Hud
var idle: Array = []  # sids of your idle squads, longest idle first
var _t := 0.0
var _idle_since := {}  # sid -> world time it was first seen idle
var _cycle := -1  # the last idle squad picked by the key
var _seen := {}  # sid -> [men standing, men down or dead] at the last look
var _fire_t := {}  # sid -> world time of its last under-fire report
var _last_fire := -INF


func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = CHECK_EVERY
	_look()


## One look over your squads: who's idle, who's under fire.
func _look() -> void:
	var w := hud.world
	if w.local_team < 0 or w.winner >= 0:
		idle.clear()
		visible = false
		return
	var by_sid := {}
	for s in w.soldiers:
		if s.team != w.local_team or s.sid == 0 or s.owner_peer != w.local_peer:
			continue
		if not by_sid.has(s.sid):
			by_sid[s.sid] = []
		by_sid[s.sid].append(s)
	var now := w.time
	var was := idle.duplicate()
	idle.clear()
	for sid in by_sid:
		var mem: Array = by_sid[sid]
		if _is_idle(int(sid), mem):
			if not _idle_since.has(sid):
				_idle_since[sid] = now
			if now - float(_idle_since[sid]) >= IDLE_AFTER:
				idle.append(int(sid))
		else:
			_idle_since.erase(sid)
		_under_fire(int(sid), mem)
	for sid in _idle_since.keys():
		if not by_sid.has(sid):
			_idle_since.erase(sid)
	for sid in _seen.keys():
		if not by_sid.has(sid):
			_seen.erase(sid)
	idle.sort_custom(func(a, b): return float(_idle_since[a]) < float(_idle_since[b]))
	visible = not idle.is_empty()
	if idle != was:
		queue_redraw()


## Standing about: alive, on foot, not shooting or being shot at, with no task
## (no defence, ambush, building or assault of its own, and no XO handling it),
## and at the end of its last move.
func _is_idle(sid: int, mem: Array) -> bool:
	var o: Array = hud.orders.get(sid, [])
	if o.is_empty() or not String(o[0]) in ["hold", "move", "bound"] or o[6] != null:
		return false
	if not hud.intent_of(sid).is_empty():
		return false
	var c := Vector3.ZERO
	var n := 0
	for s in mem:
		if s.life != Soldier.Life.ALIVE:
			continue
		if s.riding != null or (s.flags & (Soldier.F_SHOOTING | Soldier.F_PINNED)) != 0:
			return false
		var cat: String = s.doing_cat()
		if cat == "move" or cat == "fight" or cat == "work" or cat == "medic":
			return false
		c += s.position
		n += 1
	if n == 0:
		return false
	c /= n
	if String(o[0]) != "hold" and o[1] is Vector3 and Defs.flat(c - (o[1] as Vector3)).length() > ARRIVED:
		return false
	return true


## A squad you can't see taking fire: a man of it hit since the last look, or
## the squad pinned down. Said once, then quiet for a while.
func _under_fire(sid: int, mem: Array) -> void:
	var w := hud.world
	var up := 0
	var hurt := 0
	var supp := 0.0
	var pinned := 0
	var c := Vector3.ZERO
	for s in mem:
		if s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.HIDDEN:
			up += 1
			supp += s.supp_value()
			c += s.position
			if (s.flags & Soldier.F_PINNED) != 0:
				pinned += 1
		elif s.life == Soldier.Life.DOWNED or s.life == Soldier.Life.DEAD:
			hurt += 1
	var prev: Array = _seen.get(sid, [up, hurt])
	_seen[sid] = [up, hurt]
	if up == 0:
		return
	c /= up
	var hit := hurt > int(prev[1])
	var shot_at := pinned * 2 >= up or supp / up >= SUPP_FIRE
	if not hit and not shot_at:
		return
	var now := w.time
	if now - float(_fire_t.get(sid, -INF)) < FIRE_QUIET or now - _last_fire < FIRE_GAP:
		return
	if _on_screen(c):
		_fire_t[sid] = now  # (you saw it: nothing to tell you)
		return
	_fire_t[sid] = now
	_last_fire = now
	w.stat("under_fire_alert")
	var cs := Squad.callsign_of(w.local_team, sid)
	var what := "taking casualties" if hit else ("pinned down" if pinned * 2 >= up else "under fire")
	hud.add_message("warn", "%s %s at %s." % [cs, what, Defs.grid_ref(c)])
	w.pings.append([c, now + 30.0, "warn"])


## Whether a point is in the camera's view (with a margin for the HUD's edges).
func _on_screen(p: Vector3) -> bool:
	var w := hud.world
	if w.cam == null or w.cam.cam == null:
		return false
	var cam: Camera3D = w.cam.cam
	if cam.is_position_behind(p):
		return false
	var sp := cam.unproject_position(p)
	var vs := get_viewport_rect().size
	return Rect2(vs * 0.08, vs * 0.84).has_point(sp)


## Select the next idle squad and take the camera there.
func next_idle() -> void:
	var w := hud.world
	if idle.is_empty() or not w.input.can_command():
		return
	_cycle = (_cycle + 1) % idle.size()
	var sid: int = idle[_cycle]
	w.input.clear_selection()
	w.input.sel_squads = [sid]
	Sfx.ui("click")
	var c := w.input.selection_centre()
	if c != Vector3.INF and w.cam:
		w.cam.glide_to(c)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		next_idle()
		accept_event()


## IDLE 02 [.]: a label, the count in mono, and the key.
func _draw() -> void:
	if idle.is_empty():
		return
	var x := 0.0
	x += UiKit.caps_at(self, Vector2(x, 16), "Idle", 11, UiKit.DIM)
	x += 8.0 + UiKit.mono_at(self, Vector2(x + 8.0, 16), "%02d" % idle.size(), 12, UiKit.WARN)
	var k := Keys.label("next_idle").to_upper()
	if k != "":
		x += 10.0 + UiKit.mono_at(self, Vector2(x + 10.0, 16), "[%s]" % k, 11, UiKit.FAINT)
	var sid: int = idle[0]
	x += 12.0 + UiKit.caps_at(self, Vector2(x + 12.0, 16), Squad.callsign_of(hud.world.local_team, sid), 11, UiKit.FAINT)
	if idle.size() > 1:
		x += 4.0 + UiKit.caps_at(self, Vector2(x + 4.0, 16), "+%d" % (idle.size() - 1), 11, UiKit.FAINT)
	size.x = x + 4.0
	tooltip_text = "Squads standing about with nothing to do. Click (or %s) to select the next one." % (k if k != "" else "the key")
