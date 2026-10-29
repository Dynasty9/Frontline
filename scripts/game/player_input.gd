class_name PlayerInput
extends Node
## Selection, orders, building placement and ability targeting for the local
## player. Everything is sent to the host as commands.

var world: World
var sel_squads: Array = []
var _marked_soldiers: Array[Soldier] = []
var sel_vehicles: Array = []
var sel_structure := 0
var drag_start := Vector2.ZERO
var dragging := false
var lmb := false
var place_kind := ""
var place_yaw := 0.0
var _place_turn := 0.0  # Shift + two fingers on a trackpad, gathered into whole steps
var ghost: MeshInstance3D
var build_grid: MeshInstance3D  # the 1 m build grid shown round the cursor while placing
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 g = wp.xz;
	vec2 f = abs(fract(g - 0.5) - 0.5) / fwidth(g);
	float minor = 1.0 - clamp(min(f.x, f.y) - 0.1, 0.0, 1.0);
	vec2 g4 = g * 0.25;
	vec2 f4 = abs(fract(g4 - 0.5) - 0.5) / fwidth(g4);
	float major = 1.0 - clamp(min(f4.x, f4.y) - 0.6, 0.0, 1.0);
	float d = length(wp.xz - NODE_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(5.0, 15.0, d);
	ALBEDO = vec3(0.92, 0.96, 0.9);
	ALPHA = clamp(minor * 0.09 + major * 0.2, 0.0, 1.0) * fade;
}
"""
var ghost_err := ""
var ability := ""
var groups := {}
const LINE_KINDS := ["sandbags", "hesco", "barricade", "trench", "wire", "concrete_wall", "tank_trap"]
var place_drag := false
var place_a := Vector3.ZERO
var line_items: Array = []  # [pos, yaw, ok]
var _line_ghosts: Array = []
var hover: Entity = null
var _hover_t := 0.0
var _markers: Array = []
var _last_group := -1
var _last_group_t := 0.0
var sel_unit := 0  # one soldier picked out of his squad (Alt+click, or his row in the squad panel)
var order_mode := ""  # "assault" / "defend": the next left-click gives that order
var rmb := false  # an order is being dragged out (drag sets the facing)
var rmb_left := false
var rmb_start := Vector2.ZERO
var rmb_gp := Vector3.ZERO
var rmb_shift := false
var rmb_ctrl := false
var ab_drag := false  # support call being dragged out for its direction
var ab_start := Vector2.ZERO
var ab_gp := Vector3.ZERO
var preview: Array = []  # [[pos, cover level], ...] where the selection would end up
var preview_face := Vector3.FORWARD
var _prev_t := 0.0
## The tactical map's key (Tab unless rebound): a tap switches to the map,
## holding it shows the battle statistics until it's let go.
const TAB_HOLD_MS := 220
var _tab_down := -1  # msec Tab went down (-1: it's up)
var _tab_peek := false
## Alt and the left button held: a ping (a tap) or the ping wheel (held, or dragged).
var pinging := false
var ping_at := Vector2.ZERO
var _ping_ms := 0
const PING_WHEEL_R := 34.0  # let go inside this and the wheel is called off
## Alt and the right button held: drawing on the map for your side.
var sketching := false
var sketch_pts := PackedVector3Array()
var _sk_last := Vector2.ZERO


func _ready() -> void:
	place_yaw = 0.0 if world.local_team != 1 else PI


func can_command() -> bool:
	return world.local_team >= 0 and world.winner < 0


## Recruitment ownership is attribution, not an allied selection lock.
func is_mine(e: Entity) -> bool:
	if e == null:
		return false
	# Supply convoys run themselves; they are inspected, not ordered.
	if world.local_team >= 0 and e is Vehicle and e.is_auto():
		return false
	# observers may select anything to inspect it (they can't give orders)
	return e.team >= 0 and (e.team == world.local_team or world.local_team < 0)


func has_units() -> bool:
	return not sel_squads.is_empty() or not sel_vehicles.is_empty() or sel_unit != 0


func has_infantry() -> bool:
	return not sel_squads.is_empty() or sel_unit != 0


func clear_selection() -> void:
	sel_squads.clear()
	sel_vehicles.clear()
	sel_structure = 0
	sel_unit = 0
	order_mode = ""


## Picks one soldier out of his squad for direct orders.
func select_unit(s: Soldier) -> void:
	if not is_mine(s):
		return
	clear_selection()
	sel_unit = s.eid
	Sfx.ui("click")


func selected_soldiers() -> Array:
	var out := []
	for s in world.soldiers:
		if (s.sid in sel_squads or s.eid == sel_unit) and s.team == world.local_team and world.local_team >= 0 and not s.gone:
			out.append(s)
	return out


var debug_mouse := Vector2(-1, -1)  # test harness: pretend the cursor is here


func _mouse() -> Vector2:
	if debug_mouse.x >= 0.0:
		return debug_mouse
	return get_viewport().get_mouse_position()


# --- input -------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if world.cam == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_XBUTTON1 or mb.button_index == MOUSE_BUTTON_XBUTTON2:
			# the side buttons do whatever they've been bound to
			if mb.pressed:
				_key(mb)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# a co-commander's marker at the screen's edge: look where he's looking
				if world.hud and world.hud.coop.click(mb.position):
					return
				if place_kind != "":
					if place_kind in LINE_KINDS:
						place_drag = true
						var gp := world.cam.ground_point(mb.position)
						place_a = TrenchNet.snap_pos(gp)
						return
					_confirm_place(mb.shift_pressed)
					return
				if ability.begins_with("support:") or ability.begins_with("demo:"):
					ab_drag = true
					ab_start = mb.position
					ab_gp = world.cam.ground_point(mb.position)
					return
				if ability != "":
					_use_ability()
					return
				if order_mode != "":
					_begin_order(mb, true)
					return
				# Alt+click pings (Alt+click on one of your allied men still picks him out)
				if mb.alt_pressed and not _alt_picks(mb.position):
					pinging = true
					ping_at = mb.position
					_ping_by_key = false
					_ping_ms = Time.get_ticks_msec()
					return
				lmb = true
				drag_start = mb.position
				dragging = false
			elif pinging:
				_end_ping()
			elif ab_drag:
				ab_drag = false
				_call_support()
			elif rmb and rmb_left:
				_end_order(mb.position)
			elif place_drag:
				place_drag = false
				if line_items.size() >= 2:
					_confirm_line(mb.shift_pressed)
				else:
					_confirm_place(mb.shift_pressed)
				_clear_line()
			elif lmb:
				lmb = false
				if dragging:
					_box_select(drag_start, mb.position, mb.shift_pressed)
				else:
					_click_select(mb.position, mb.shift_pressed, mb.double_click)
				dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if pinging:
				pinging = false
				return
			if mb.alt_pressed and place_kind == "" and ability == "" and order_mode == "":
				sketching = true
				sketch_pts = PackedVector3Array([world.cam.ground_point(mb.position)])
				_sk_last = mb.position
				return
			if place_kind != "" or ability != "" or order_mode != "":
				cancel_modes()
				return
			_begin_order(mb, false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and sketching:
			_end_sketch()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and rmb and not rmb_left:
			_end_order(mb.position)
		elif place_kind != "" and mb.pressed and mb.shift_pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			# (a Mac turns Shift + the wheel into a sideways scroll: up comes as left)
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT
			place_yaw = TrenchNet.snap_yaw(place_yaw + (TrenchNet.BUILD_ANGLE if up else -TrenchNet.BUILD_ANGLE))
	elif ev is InputEventPanGesture and place_kind != "" and (ev as InputEventPanGesture).shift_pressed:
		# Shift + two fingers on a trackpad, like Shift + the wheel: a step for
		# every couple of units scrolled, whichever way the scroll comes
		var pd := (ev as InputEventPanGesture).delta
		_place_turn -= pd.y if absf(pd.y) >= absf(pd.x) else pd.x
		while absf(_place_turn) >= 2.0:
			place_yaw = TrenchNet.snap_yaw(place_yaw + signf(_place_turn) * TrenchNet.BUILD_ANGLE)
			_place_turn -= signf(_place_turn) * 2.0
	elif ev is InputEventMouseMotion:
		var mpos := (ev as InputEventMouseMotion).position
		if lmb and mpos.distance_to(drag_start) > 8.0:
			dragging = true
		if sketching and mpos.distance_to(_sk_last) > 7.0 and sketch_pts.size() < 256:
			sketch_pts.append(world.cam.ground_point(mpos))
			_sk_last = mpos
	elif ev is InputEventKey:
		var k := ev as InputEventKey
		if k.pressed and not k.echo:
			_key(k)
		elif not k.pressed and _tab_down >= 0 and not Keys.held("tactical"):
			_tab_up()


## The actions a key press can mean in a battle, most particular first (a tie
## goes to the earlier). Placing a building puts its own keys in front.
const KEY_ACTIONS := ["chat_team", "chat", "support", "grenade", "smoke", "attack_move", "defend", "cam_follow",
	"fire_mission", "cam_reset", "view_save_1", "view_save_2", "view_save_3", "view_save_4", "view_go_1", "view_go_2",
	"view_go_3", "view_go_4", "retreat", "hold", "tactical", "cycle_fob", "orbat", "jump_alert", "log", "hide_hud",
	"help", "manual", "director", "pause", "slower", "faster", "view_side", "ping", "coop_next",
	"group_set_1", "group_set_2", "group_set_3", "group_set_4", "group_set_5", "group_set_6", "group_set_7",
	"group_set_8", "group_set_9", "group_set_0", "group_1", "group_2", "group_3", "group_4", "group_5", "group_6",
	"group_7", "group_8", "group_9", "group_0"]
const PLACE_ACTIONS := ["rotate_build"]

var _ping_by_key := false  # the ping (or its wheel) was started by the ping key, not Alt+click
var _coop_i := -1


## A key press (or an extra mouse button) in a battle: Esc always backs out;
## everything else is whatever it's bound to (Settings > Controls).
func _key(ev: InputEvent) -> void:
	if (world.hud and world.hud.typing) or Keys.capturing or Keys.console_open:
		return
	if ev is InputEventKey and (ev as InputEventKey).keycode == KEY_ESCAPE:
		if pinging or sketching:
			pinging = false
			sketching = false
			sketch_pts = PackedVector3Array()
		elif place_kind != "" or ability != "" or order_mode != "":
			cancel_modes()
		elif world.hud and world.hud.workspace != "battle":
			world.hud.set_workspace("battle")
		elif has_units() or sel_structure != 0:
			clear_selection()
		elif world.hud:
			world.hud.toggle_menu()
		return
	var act := Keys.action_for(ev, (PLACE_ACTIONS + KEY_ACTIONS) if place_kind != "" else KEY_ACTIONS)
	if act == "":
		return
	if act.begins_with("group_set_"):
		var n := int(act.right(1))
		groups[n] = {"s": sel_squads.duplicate(), "v": sel_vehicles.duplicate()}
		if world.hud:
			world.hud.flash("Group %d set." % n)
		return
	if act.begins_with("group_"):
		var g := int(act.right(1))
		if groups.has(g):
			sel_squads = groups[g].s.duplicate()
			sel_vehicles = groups[g].v.duplicate()
			sel_structure = 0
			var now := Time.get_ticks_msec() / 1000.0
			if _last_group == g and now - _last_group_t < 0.4:
				_focus_selection()
			_last_group = g
			_last_group_t = now
		return
	if act.begins_with("view_save_") or act.begins_with("view_go_"):
		# saved views 1-4 are the camera's slots 5-8 (they were F5-F8 to begin with)
		world.cam.bookmark(int(act.right(1)) + 4, act.begins_with("view_save_"))
		return
	match act:
		"chat", "chat_team":
			if world.hud:
				world.hud.open_chat(act == "chat_team")
		"support":
			if world.local_team >= 0:
				var sup: Dictionary = world.team_info[world.local_team].get("sup", {})
				for sk in Defs.supports_for(world.local_team):
					if not world.mission_info.is_empty() and not sk in world.mission_info.get("sup", []):
						continue
					if float(sup.get(sk, Defs.support_from(sk))) <= world.time and float(world.team_info[world.local_team].get("supply", 0)) >= float(Defs.SUPPORT[sk].cost):
						cancel_modes()
						ability = "support:" + String(sk)
						if world.hud:
							world.hud.set_workspace("battle")
						break
		"grenade":
			if has_infantry():
				ability = "frag"
		"smoke":
			if has_infantry():
				ability = "smoke"
		"attack_move":
			if has_units():
				cancel_modes()
				order_mode = "assault"
		"defend":
			if has_units():
				cancel_modes()
				order_mode = "defend"
		"cam_follow":
			world.cam.toggle_follow()
		"fire_mission":
			if selection_has_mortar():
				ability = "mortar_he"
			elif selection_has_arty():
				ability = "arty_he"
		"cam_reset":
			world.cam.reset_view()
		"rotate_build":
			place_yaw += PI * 0.5
		"retreat":
			if has_units():
				retreat()
		"hold":
			if has_units():
				hold()
		"tactical":
			_tab_down = Time.get_ticks_msec()
			_tab_peek = false
		"cycle_fob":
			_cycle_fob()
		"orbat":
			if world.hud:
				world.hud.toggle_orbat()
		"jump_alert":
			# the newest of the alerts and the co-commanders' pings
			var at := Vector3.INF
			var came := -INF
			if not world.pings.is_empty():
				at = world.pings.back()[0]
				came = float(world.pings.back()[1]) - 30.0
			if world.coop and world.coop.last_ping_pos != Vector3.INF and world.coop.last_ping_t > came:
				at = world.coop.last_ping_pos
			if at != Vector3.INF:
				world.cam.glide_to(at)
		"log":
			if world.hud:
				world.hud.toggle_log()
		"hide_hud":
			if world.hud:
				world.hud.root.visible = not world.hud.root.visible
		"help":
			if world.hud:
				world.hud.toggle_help()
		"manual":
			if world.hud:
				world.hud.toggle_manual()
		"director":
			if world.director:
				world.director.active = not world.director.active
				if world.hud:
					world.hud.flash("Director camera ON" if world.director.active else "Director camera OFF")
		"pause":
			if world.director:
				world.director.toggle_pause()
		"slower":
			if world.director:
				world.director.set_speed_index(world.director.speed_i - 1)
		"faster":
			if world.director:
				world.director.set_speed_index(world.director.speed_i + 1)
		"view_side":
			if world.director:
				world.director.cycle_view()
				if world.hud:
					world.hud.flash("Viewing: %s" % ("everything" if world.view_team < 0 else Defs.TEAM_NAMES[world.view_team] + " fog of war"))
		"ping":
			# a tap pings what's under the cursor; held, it opens the wheel there
			if not pinging and place_kind == "" and ability == "":
				pinging = true
				_ping_by_key = true
				ping_at = _mouse()
				_ping_ms = Time.get_ticks_msec()
		"coop_next":
			var all: Array = world.coop.list() if world.coop else []
			if all.is_empty():
				if world.hud:
					world.hud.flash("No other commanders on your side")
			else:
				_coop_i = (_coop_i + 1) % all.size()
				var p = all[_coop_i]
				world.cam.glide_to(p.focus, p.dist, p.yaw, p.tilt)
				if world.hud:
					world.hud.flash("%s's view" % Net.player_name(p.peer))


## Alt+click on one of your allied men picks him out of his squad (rather than pinging).
func _alt_picks(at: Vector2) -> bool:
	var e := pick(at)
	return e is Soldier and is_mine(e) and e.life == Soldier.Life.ALIVE


## The ping wheel shows once the button has been held a moment, or dragged.
func ping_wheel_open() -> bool:
	return pinging and (Time.get_ticks_msec() - _ping_ms > 220 or _mouse().distance_to(ping_at) > 14.0)


## The wheel's spoke under the cursor ("" in the middle: called off).
func ping_wheel_pick() -> String:
	var d := _mouse() - ping_at
	if d.length() < PING_WHEEL_R:
		return ""
	var n := CoCommand.WHEEL.size()
	return CoCommand.WHEEL[posmod(int(round(atan2(d.x, -d.y) / (TAU / n))), n)]


## Let go: a tap pings whatever is under the cursor (an enemy, one of ours, the
## ground); off the wheel it's the spoke picked, at the spot first pressed.
func _end_ping() -> void:
	var wheel := ping_wheel_open()
	pinging = false
	_ping_by_key = false
	if world.coop == null or world.cam == null:
		return
	var tgt := pick(ping_at)
	var kind: String = ping_wheel_pick() if wheel else world.coop.context_ping(tgt)
	if kind == "":
		return
	var gp := world.cam.ground_point(ping_at)
	var eid := 0
	if (tgt is Soldier or tgt is Vehicle) and tgt.visible and tgt.seen_by_local():
		eid = tgt.eid
		gp = Defs.flat(tgt.position)
	world.coop.ping(kind, gp, eid)


## Let go of a sketch: it goes to your side, thinned out to as many points as a sketch may have.
func _end_sketch() -> void:
	sketching = false
	var pts := sketch_pts
	sketch_pts = PackedVector3Array()
	if world.coop == null:
		return
	var L := 0.0
	for i in range(1, pts.size()):
		L += Defs.flat(pts[i] - pts[i - 1]).length()
	if pts.size() < 2 or L < 3.0:
		if world.hud:
			world.hud.flash("Hold Alt and drag with the right button to draw for your side")
		return
	world.coop.sketch(thin_line(pts, CoCommand.SKETCH_PTS))


## The same line in at most n points, evenly along it.
static func thin_line(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	if pts.size() <= n:
		return pts
	var out := PackedVector3Array()
	for i in n:
		out.append(pts[int(round(float(i) * (pts.size() - 1) / (n - 1)))])
	return out


func retreat() -> void:
	if sel_unit != 0:
		world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "retreat"})
	else:
		world.send_cmd({"t": "retreat", "squads": sel_squads, "vehicles": sel_vehicles})
	Sfx.ui("click")


func hold() -> void:
	if sel_unit != 0:
		world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "stop"})
	else:
		world.send_cmd({"t": "stop", "squads": sel_squads, "vehicles": sel_vehicles})
	Sfx.ui("click")


## The run-in direction for a support call: dragged out, else across the
## screen (observer) or from our own lines.
func support_dir() -> Vector3:
	if ab_drag:
		var g2 := world.cam.ground_point(_mouse())
		if _mouse().distance_to(ab_start) > 18.0 and Defs.flat(g2 - ab_gp).length() > 2.0:
			return Defs.flat(g2 - ab_gp).normalized()
	if ability.begins_with("demo:") or world.local_team < 0:
		var r := world.cam.cam.global_transform.basis.x
		return Defs.flat(r).normalized() if Defs.flat(r).length() > 0.1 else Vector3.RIGHT
	return Vector3(0, 0, -1) if world.local_team == 0 else Vector3(0, 0, 1)


func _call_support() -> void:
	var k := ability.get_slice(":", 1)
	var dir := support_dir()
	if ability.begins_with("demo:"):
		world.send_cmd({"t": "demo_support", "kind": k, "pos": ab_gp, "dir": dir})
		# frame the show: aircraft need room to be seen coming in
		var want: float = float({"a10": 80.0, "wipeout": 80.0, "airstrike": 80.0, "ac130": 105.0, "blackfish": 100.0}.get(k, 0.0))
		if world.cam and float(want) > world.cam.target_dist:
			world.cam.target_dist = float(want)
			world.cam.focus(ab_gp)
		if world.director:
			world.director.active = false
	else:
		world.send_cmd({"t": "support", "kind": k, "pos": ab_gp, "dir": dir})
	_marker(ab_gp, Color(1.0, 0.45, 0.3))
	Sfx.ui("click")
	if not Input.is_key_pressed(KEY_SHIFT):
		ability = ""


func cancel_modes() -> void:
	place_kind = ""
	ab_drag = false
	ability = ""
	order_mode = ""
	rmb = false
	place_drag = false
	_clear_line()
	if ghost:
		ghost.queue_free()
		ghost = null
	if build_grid:
		build_grid.queue_free()
		build_grid = null


func _cycle_fob() -> void:
	var fobs := []
	for st in world.fob_structures:
		if st.skind == "fob" and (st.team == world.local_team or world.local_team < 0):
			fobs.append(st)
	if fobs.is_empty():
		return
	var cur := 0
	for i in fobs.size():
		if fobs[i].eid == sel_structure:
			cur = i + 1
	var f: Structure = fobs[cur % fobs.size()]
	clear_selection()
	sel_structure = f.eid
	world.cam.glide_to(f.position)


func _focus_selection() -> void:
	var c := selection_centre()
	if c != Vector3.INF:
		world.cam.glide_to(c)


## The middle of everything selected (INF when nothing is).
func selection_centre() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for s in selected_soldiers():
		if s.life == Soldier.Life.DEAD:
			continue
		c += s.position
		n += 1
	for id in sel_vehicles:
		var v = world.entity(id)
		if v and not v.gone:
			c += v.position
			n += 1
	return Defs.flat(c / n) if n > 0 else Vector3.INF


# --- picking & selection ---------------------------------------------------------------

func pick(screen: Vector2) -> Entity:
	var cam := world.cam.cam
	var best: Entity = null
	var bd := 20.0
	for arr in [world.soldiers, world.vehicles]:
		for e in arr:
			if e.gone or not e.visible:
				continue
			if e is Soldier and e.life == Soldier.Life.HIDDEN:
				continue
			var p: Vector3 = e.position + Vector3(0, 0.9 if e is Soldier else 1.2, 0)
			if cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen)
			if e is Vehicle:
				d *= 0.5
			if d < bd:
				bd = d
				best = e
	if best:
		return best
	var gp := world.cam.ground_point(screen)
	for st in world.structures_near(gp, 12.0):
		if not st.visible or (st.team < 0 and st.skind != "town") or st.gone:
			continue
		if Defs.point_in_obb(Vector2(gp.x, gp.z), Vector2(st.position.x, st.position.z), st.foot + Vector2(0.6, 0.6), st.yaw):
			return st
	return null


func _click_select(screen: Vector2, add: bool, dbl: bool) -> void:
	var e := pick(screen)
	if e is Soldier and is_mine(e) and Input.is_key_pressed(KEY_ALT) and e.life == Soldier.Life.ALIVE:
		select_unit(e)
		return
	if not add:
		clear_selection()
	if e == null:
		return
	sel_unit = 0
	if e is Soldier and is_mine(e) and e.sid != 0:
		if dbl:
			var kind_sids := _same_kind_on_screen(e)
			for sid in kind_sids:
				if not sid in sel_squads:
					sel_squads.append(sid)
		elif e.sid in sel_squads and add:
			sel_squads.erase(e.sid)
		elif not e.sid in sel_squads:
			sel_squads.append(e.sid)
		sel_structure = 0
		Sfx.ui("click")
	elif e is Vehicle and is_mine(e):
		if not e.eid in sel_vehicles:
			sel_vehicles.append(e.eid)
		sel_structure = 0
		Sfx.ui("click")
	elif e is Structure and (e.team == world.local_team or world.local_team < 0 or e.skind == "town"):
		sel_squads.clear()
		sel_vehicles.clear()
		sel_structure = e.eid
		Sfx.ui("click")
	elif world.hud:
		world.hud.inspect(e)


func _same_kind_on_screen(ref: Soldier) -> Array:
	var out := []
	var vs := get_viewport().get_visible_rect().size
	var kind := _squad_kind_of(ref.sid)
	for s in world.soldiers:
		if not is_mine(s) or s.sid == 0 or s.sid in out:
			continue
		if _squad_kind_of(s.sid) != kind:
			continue
		var sp := world.cam.cam.unproject_position(s.position)
		if sp.x >= 0 and sp.y >= 0 and sp.x <= vs.x and sp.y <= vs.y:
			out.append(s.sid)
	return out


func _squad_kind_of(sid: int) -> String:
	var types := []
	for s in world.soldiers:
		if s.sid == sid:
			types.append(s.utype)
	types.sort()
	return ",".join(types)


func _box_select(a: Vector2, b: Vector2, add: bool) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	if not add:
		clear_selection()
	var cam := world.cam.cam
	for s in world.soldiers:
		if not is_mine(s) or s.sid == 0 or s.gone or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DEAD:
			continue
		if cam.is_position_behind(s.position):
			continue
		if r.has_point(cam.unproject_position(s.position + Vector3(0, 0.8, 0))) and not s.sid in sel_squads:
			sel_squads.append(s.sid)
	for v in world.vehicles:
		if not is_mine(v) or v.is_auto():
			continue
		if not cam.is_position_behind(v.position) and r.has_point(cam.unproject_position(v.position + Vector3(0, 1, 0))) and not v.eid in sel_vehicles:
			sel_vehicles.append(v.eid)
	if has_units():
		sel_structure = 0
		Sfx.ui("click")


# --- orders ------------------------------------------------------------------------------

func _begin_order(mb: InputEventMouseButton, left: bool) -> void:
	rmb = true
	rmb_left = left
	rmb_start = mb.position
	rmb_gp = world.cam.ground_point(mb.position)
	rmb_shift = mb.shift_pressed
	rmb_ctrl = mb.ctrl_pressed
	_prev_t = 0.0


## Released: the drag (if any) sets which way the men face.
func _end_order(pos: Vector2) -> void:
	rmb = false
	var face := Vector3.ZERO
	var g2 := world.cam.ground_point(pos)
	if pos.distance_to(rmb_start) > 18.0 and Defs.flat(g2 - rmb_gp).length() > 1.5:
		face = Defs.flat(g2 - rmb_gp).normalized()
	var kind := order_mode
	if kind == "" and rmb_ctrl:
		kind = "assault"
	_order(rmb_start, rmb_shift, face, kind)
	if not rmb_shift:
		order_mode = ""


func drag_face() -> Vector3:
	if not rmb:
		return Vector3.ZERO
	var g2 := world.cam.ground_point(_mouse())
	if _mouse().distance_to(rmb_start) > 18.0 and Defs.flat(g2 - rmb_gp).length() > 1.5:
		return Defs.flat(g2 - rmb_gp).normalized()
	return Vector3.ZERO


func _order(screen: Vector2, shift: bool, face_in := Vector3.ZERO, kind := "") -> void:
	if not can_command():
		return
	var gp := world.cam.ground_point(screen)
	if sel_unit != 0:
		_unit_order(screen, gp, shift, face_in)
		return
	if not has_units():
		var st = world.entity(sel_structure)
		if st is Structure and st.team == world.local_team and Defs.BUILDINGS.get(st.skind, {}).has("produces"):
			world.send_cmd({"t": "rally", "building": sel_structure, "pos": gp})
			_marker(gp, Color(0.4, 1.0, 0.4))
		return
	var tgt := pick(screen)
	var lt := world.local_team
	if tgt is Structure and tgt.skind == "town" and tgt.team != lt:
		# a town that isn't ours: go and take it - fight in if the enemy holds
		# it, then hold its ground until the flag is ours
		world.send_cmd({"t": "assault" if tgt.team >= 0 else "defend", "squads": sel_squads, "vehicles": sel_vehicles, "pos": tgt.zone_c})
		_marker(tgt.zone_c, Color(1.0, 0.85, 0.3))
		Sfx.ui("click")
		return
	if tgt and tgt.is_hostile_to(lt) and tgt.seen_by_local():
		var ok := true
		if tgt is Soldier and tgt.life != Soldier.Life.ALIVE and tgt.life != Soldier.Life.DOWNED:
			ok = false
		if tgt is Structure and tgt.skind in ["mines"]:
			ok = false
		if ok:
			world.send_cmd({"t": "attack", "squads": sel_squads, "vehicles": sel_vehicles, "target": tgt.eid})
			_marker(tgt.position, Color(1.0, 0.3, 0.25))
			Sfx.ui("click")
			return
	if tgt is Structure and tgt.team == lt and not sel_squads.is_empty():
		if tgt.needs_work():
			world.send_cmd({"t": "work", "squads": sel_squads, "target": tgt.eid})
			_marker(tgt.position, Color(1.0, 0.85, 0.3))
			Sfx.ui("click")
			return
		if tgt.skind in ["tunnel", "mg_nest", "watchtower"]:
			world.send_cmd({"t": "enter", "squads": sel_squads, "target": tgt.eid})
			_marker(tgt.position, Color(0.6, 0.9, 1.0))
			Sfx.ui("click")
			return
	if tgt is Vehicle and tgt.team == lt and not sel_vehicles.is_empty() and sel_squads.is_empty():
		# a lift helicopter picks up one of our vehicles on its sling
		for id in sel_vehicles:
			var hv = world.entity(id)
			if hv is Vehicle and hv.base() == "lift_heli" and int(hv.vdef.get("sling", -1)) >= tgt.weight() and not tgt.is_heli() and not tgt.is_boat() and tgt != hv:
				world.send_cmd({"t": "sling", "vehicles": [hv.eid], "target": tgt.eid})
				_marker(tgt.position, Color(0.6, 0.9, 1.0))
				Sfx.ui("click")
				return
	if tgt is Vehicle and tgt.team == lt and not sel_squads.is_empty() and tgt.seats() > 0 and tgt.health_frac() > 0.3 \
			and not (tgt.is_heli() and tgt.position.y > 1.0) and not _has_engineers():
		world.send_cmd({"t": "board", "squads": sel_squads, "target": tgt.eid})
		_marker(tgt.position, Color(0.6, 0.9, 1.0))
		Sfx.ui("click")
		return
	if tgt is Vehicle and tgt.team == lt and not sel_squads.is_empty() and (tgt.health_frac() < 0.99 or (tgt.flags & Vehicle.F_TRACK) != 0):
		world.send_cmd({"t": "work", "squads": sel_squads, "target": tgt.eid})
		_marker(tgt.position, Color(1.0, 0.85, 0.3))
		return
	var c := Vector3.ZERO
	var n := 0
	for s in selected_soldiers():
		c += s.position
		n += 1
	for id in sel_vehicles:
		var v = world.entity(id)
		if v:
			c += v.position
			n += 1
	var face := face_in
	if n > 0:
		c /= n
		if face.length() < 0.1:
			face = Defs.flat(gp - c).normalized()
	var t := kind if kind != "" else "move"
	world.send_cmd({"t": t, "squads": sel_squads, "vehicles": sel_vehicles, "pos": gp, "face": face, "mode": 1 if shift else 0})
	_marker(gp, {"assault": Color(1.0, 0.55, 0.3), "defend": Color(0.45, 0.75, 1.0)}.get(t, Color(0.5, 1.0, 0.5)))
	Sfx.ui("click")


## Orders for one hand-picked soldier: move (into the best cover there), attack,
## man a weapon, or (with abilities) throw.
func _unit_order(screen: Vector2, gp: Vector3, shift: bool, face: Vector3) -> void:
	var tgt := pick(screen)
	var lt := world.local_team
	if tgt and tgt.is_hostile_to(lt) and tgt.seen_by_local():
		world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "attack", "target": tgt.eid})
		_marker(tgt.position, Color(1.0, 0.3, 0.25))
	elif tgt is Structure and tgt.team == lt and tgt.is_mount():
		world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "man", "target": tgt.eid})
		_marker(tgt.position, Color(0.6, 0.9, 1.0))
	else:
		world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "move", "pos": gp, "face": face, "mode": 1 if shift else 0})
		_marker(gp, Color(0.5, 1.0, 0.5))
	Sfx.ui("click")


func order_at(gp: Vector3) -> void:
	if not can_command() or not has_units():
		return
	world.send_cmd({"t": "move", "squads": sel_squads, "vehicles": sel_vehicles, "pos": gp, "face": Vector3.ZERO, "mode": 0})
	_marker(gp, Color(0.5, 1.0, 0.5))


## Engineers in the selection (they'd rather repair a damaged vehicle than ride in it).
func _has_engineers() -> bool:
	for s in selected_soldiers():
		if s.udef.get("engineer", false):
			return true
	return false


func selection_has_arty() -> bool:
	for id in sel_vehicles:
		var v = world.entity(id)
		if v is Vehicle and v.vdef.has("art"):
			return true
	return false


func _use_ability() -> void:
	var gp := world.cam.ground_point(_mouse())
	var smoke := ability.ends_with("smoke")
	match ability:
		"mortar_he", "mortar_smoke":
			world.send_cmd({"t": "fire_mission", "squads": sel_squads, "pos": gp, "kind": "smoke" if smoke else "he"})
		"pit_he", "pit_smoke":
			world.send_cmd({"t": "fire_mission", "building": sel_structure, "pos": gp, "kind": "smoke" if smoke else "he"})
		"arty_he":
			world.send_cmd({"t": "fire_mission", "vehicles": sel_vehicles, "pos": gp, "kind": "he"})
		"support":
			pass
		_:
			if sel_unit != 0:
				world.send_cmd({"t": "unit", "soldier": sel_unit, "o": "throw", "pos": gp, "kind": ability})
			else:
				world.send_cmd({"t": "throw", "squads": sel_squads, "pos": gp, "kind": ability})
	_marker(gp, Color(0.85, 0.85, 0.85) if smoke else Color(1.0, 0.6, 0.2))
	Sfx.ui("click")
	ability = ""


func selection_has_mortar() -> bool:
	for s in selected_soldiers():
		if int(s.udef.get("mortar", 0)) > 0 and s.life == Soldier.Life.ALIVE:
			return true
	return false


func _clear_line() -> void:
	line_items.clear()
	for g in _line_ghosts:
		g.visible = false


## Click-and-drag a line of walls / trenches / wire / tank traps.
func _update_line(gp: Vector3) -> void:
	var def: Dictionary = Defs.BUILDINGS[place_kind]
	var seg: float = def.size.x + (1.2 if place_kind == "tank_trap" else 0.0)
	var to := Defs.flat(gp - place_a)
	line_items.clear()
	if to.length() < seg * 0.6:
		for g in _line_ghosts:
			g.visible = false
		ghost.visible = true
		return
	ghost.visible = false
	# lines run along the build grid: 45 degree headings from a whole-metre start
	var dir := TrenchNet.snap_dir(to)
	var yaw := atan2(-dir.z, dir.x)
	var zig := place_kind == "trench" and not Input.is_key_pressed(KEY_ALT)
	var lay: Array = []
	var n := clampi(int(round(to.dot(dir) / seg)), 1, 24)
	if place_kind == "trench":
		lay = TrenchNet.layout(place_a, gp, zig, def.size.x, 24)
		n = lay.size()
	var cost := int(def.cost)
	var info: Dictionary = world.team_info[world.local_team] if world.local_team >= 0 else {}
	var budget := int(info.get("supply", 0))
	var h: float = {"concrete_wall": 2.6, "hesco": 1.37, "barricade": 1.2}.get(place_kind, 1.0)
	while _line_ghosts.size() < n:
		var g := MeshInstance3D.new()
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(g)
		_line_ghosts.append(g)
	for i in _line_ghosts.size():
		var g: MeshInstance3D = _line_ghosts[i]
		if i >= n:
			g.visible = false
			continue
		var p := place_a + dir * seg * (i + 0.5)
		var y := yaw
		var ln: float = def.size.x
		if not lay.is_empty():
			p = lay[i][0]
			y = lay[i][1]
			ln = lay[i][2]
		var ok := world.placement_error(world.local_team, place_kind, p, y) == "" and budget >= cost
		if ok:
			budget -= cost
		line_items.append([p, y, ok, ln])
		g.visible = true
		g.mesh = Res.box(Vector3(ln + (1.2 if place_kind == "trench" else 0.0), h, def.size.y if place_kind != "trench" else 1.44))
		g.position = p + Vector3(0, h * 0.5, 0)
		g.rotation.y = y
		g.material_override = Res.mat(Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.3, 0.25, 0.35), 0.5, 0.0, true)
	var good := 0
	for it in line_items:
		if it[2]:
			good += 1
	ghost_err = "" if good > 0 else "Can't build any of these here."


func _confirm_line(keep: bool) -> void:
	var items := []
	for it in line_items:
		if it[2]:
			items.append([it[0], it[1], it[3]] if place_kind == "trench" else [it[0], it[1]])
	if items.is_empty():
		if world.hud:
			world.hud.flash(ghost_err if ghost_err != "" else "Can't build there.")
		return
	world.send_cmd({"t": "build_many", "kind": place_kind, "items": items, "squads": sel_squads})
	Sfx.ui("click")
	if not keep:
		cancel_modes()


func start_place(kind: String) -> void:
	if not can_command():
		return
	cancel_modes()
	place_kind = kind
	var def: Dictionary = Defs.BUILDINGS[kind]
	var s: Vector2 = def.size
	var h := 3.0
	if kind in ["sandbags", "trench", "wire", "mines", "tank_trap", "tunnel"]:
		h = 1.0
	elif kind in ["hesco", "barricade", "ammo_cache"]:
		h = 1.3
	ghost = MeshInstance3D.new()
	ghost.mesh = Res.box(Vector3(s.x, h, s.y))
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ghost)
	var arrow := MeshInstance3D.new()
	arrow.mesh = Res.box(Vector3(0.3, 0.1, 1.5))
	arrow.material_override = Res.mat(Color(1, 1, 1, 0.7), 0.5, 0.0, true)
	arrow.position = Vector3(0, -h * 0.5 + 0.1, -s.y * 0.5 - 1.0)
	ghost.add_child(arrow)
	build_grid = MeshInstance3D.new()
	build_grid.mesh = Res.plane(34.0)
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRID_SHADER
	build_grid.material_override = gm
	build_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(build_grid)


func _confirm_place(keep: bool) -> void:
	if ghost_err != "":
		if world.hud:
			world.hud.flash(ghost_err)
		return
	var gp: Vector3 = ghost.position
	gp.y = 0.0
	world.send_cmd({"t": "build", "kind": place_kind, "pos": gp, "yaw": place_yaw, "squads": sel_squads})
	Sfx.ui("click")
	if not (keep or place_kind in LINE_KINDS and Input.is_key_pressed(KEY_SHIFT)):
		cancel_modes()


func _marker(p: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = Res.torus(0.6, 0.8)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = c
	m.material_override = mm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.position = Vector3(p.x, 0.1, p.z)
	_markers.append([m, 0.0])


# --- per frame ----------------------------------------------------------------------------

func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("input", _t0)


func _tab_up() -> void:
	if _tab_down < 0:
		return
	_tab_down = -1
	if not world.hud:
		return
	if _tab_peek:
		world.hud.peek_stats(false)
	else:
		world.hud.toggle_tactical()


func _view_process(dt: float) -> void:
	if _tab_down >= 0:
		if not Keys.held("tactical"):
			_tab_up()  # let go while we weren't looking (the window lost focus)
		elif not _tab_peek and Time.get_ticks_msec() - _tab_down >= TAB_HOLD_MS and world.hud:
			_tab_peek = true
			world.hud.peek_stats(true)
	# a ping or a sketch let go of over a panel: the release never reached us
	if debug_mouse.x < 0.0:
		if pinging and _ping_by_key:
			# started by the ping key: let go of it to send
			if not Keys.held("ping"):
				_end_ping()
		elif pinging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_ping()
		if sketching and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_end_sketch()
	_update_selection()
	_prev_t -= dt
	if _prev_t <= 0.0:
		_prev_t = 0.05
		_update_preview()
	for v in world.vehicles:
		v.selected = v.eid in sel_vehicles
	if place_kind != "" and ghost:
		var gp := world.cam.ground_point(_mouse())
		gp = TrenchNet.snap_pos(gp) if place_drag else TrenchNet.snap_foot(gp, place_kind, place_yaw)
		if build_grid:
			build_grid.position = Vector3(round(gp.x), 0.04, round(gp.z))
		var h: float = Res.box_size(ghost.mesh).y
		ghost.position = gp + Vector3(0, h * 0.5, 0)
		ghost.rotation.y = place_yaw
		ghost_err = world.placement_error(world.local_team, place_kind, gp, place_yaw)
		var cost := int(Defs.BUILDINGS[place_kind].cost)
		var info: Dictionary = world.team_info[world.local_team] if world.local_team >= 0 else {}
		if ghost_err == "" and int(info.get("supply", 0)) < cost:
			ghost_err = "Not enough supply (%d needed)." % cost
		ghost.material_override = Res.mat(Color(0.3, 1.0, 0.4, 0.35) if ghost_err == "" else Color(1.0, 0.3, 0.25, 0.35), 0.5, 0.0, true)
		if place_drag:
			_update_line(gp)
	_hover_t -= dt
	if _hover_t <= 0.0:
		_hover_t = 0.1
		hover = pick(_mouse())
	for i in range(_markers.size() - 1, -1, -1):
		var m: Array = _markers[i]
		m[1] += dt
		var mi: MeshInstance3D = m[0]
		mi.scale = Vector3.ONE * (1.0 + m[1] * 1.5)
		(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - m[1] / 0.7, 0.0, 1.0)
		if m[1] > 0.7:
			mi.queue_free()
			_markers.remove_at(i)



## Where the selection would end up if ordered at the cursor, each man snapped
## to cover the way the server will do it. The HUD draws these as cover pips.
func _update_preview() -> void:
	preview.clear()
	if not can_command() or place_kind != "" or ability != "" or pinging or sketching or world.terrain == null or world.cam == null:
		return
	if not Settings.get_v("cover_preview") and not rmb:
		return
	if sel_squads.is_empty() and sel_unit == 0:
		return
	var screen := rmb_start if rmb else _mouse()
	var gp := world.cam.ground_point(screen)
	var h := pick(screen)
	if h and (h.is_hostile_to(world.local_team) or h is Vehicle):
		return
	if h is Structure and (h.needs_work() or h.skind in ["tunnel", "mg_nest", "hmg_nest", "watchtower", "bunker", "mortar_pit", "at_post"]):
		return
	var mems := selected_soldiers()
	var c := Vector3.ZERO
	var counts := {}
	for s in mems:
		if s.life != Soldier.Life.ALIVE:
			continue
		c += s.position
		counts[s.sid] = int(counts.get(s.sid, 0)) + 1
	var total := 0
	for k in counts:
		total += int(counts[k])
	if total == 0:
		return
	c /= total
	var face := drag_face()
	if face.length() < 0.1:
		face = Defs.flat(gp - c).normalized() if Defs.flat(gp - c).length() > 1.0 else Vector3.FORWARD
	preview_face = face
	if sel_unit != 0:
		var thr := gp + face * 40.0
		preview.append(world.terrain.best_spot_near(gp, 2.0, thr, []))
		return
	var side := face.cross(Vector3.UP).normalized()
	var n := sel_squads.size()
	for i in n:
		var cnt := int(counts.get(sel_squads[i], 0))
		if cnt == 0:
			continue
		var p: Vector3 = gp + side * (i - (n - 1) / 2.0) * 13.0
		for sl in world.terrain.slots(p, face, cnt, order_mode == "defend"):
			preview.append(sl)


func _update_selection() -> void:
	var live := {}
	if not sel_squads.is_empty():
		for s in world.soldiers:
			if s.sid != 0 and s.sid in sel_squads and is_mine(s) and s.life != Soldier.Life.DEAD:
				live[s.sid] = true
	for i in range(sel_squads.size() - 1, -1, -1):
		if not live.has(sel_squads[i]):
			sel_squads.remove_at(i)
	for i in range(sel_vehicles.size() - 1, -1, -1):
		if not is_mine(world.entity(sel_vehicles[i])):
			sel_vehicles.remove_at(i)
	if sel_structure != 0 and world.entity(sel_structure) == null:
		sel_structure = 0
	if sel_unit != 0:
		var su = world.entity(sel_unit)
		if not (su is Soldier) or su.life != Soldier.Life.ALIVE or not is_mine(su):
			sel_unit = 0
	# Clearing an empty selection need only visit the men marked last frame.
	for s in _marked_soldiers:
		if is_instance_valid(s):
			s.selected = false
	_marked_soldiers.clear()
	if not sel_squads.is_empty():
		for s in world.soldiers:
			if (s.sid != 0 and s.sid in sel_squads and is_mine(s)) or (sel_unit != 0 and s.eid == sel_unit):
				s.selected = true
				_marked_soldiers.append(s)
	elif sel_unit != 0:
		var s: Soldier = world.entity(sel_unit)
		s.selected = true
		_marked_soldiers.append(s)
