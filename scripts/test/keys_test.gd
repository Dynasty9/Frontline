extends Node
## --keys-test: checks the key bindings end to end with made-up input. Reading
## and naming bindings, the closest match (exact modifiers before extra ones),
## clashes, presses reaching the game through PlayerInput (a rebound key works
## and the old one doesn't, placing takes R before retreat), a mouse side
## button on the tactical map (tapped and held), a held key driving the
## camera, and the Controls page rebinding a key (moving it off another
## action, Undo, a modifier on its own). Prints
## KEYTEST ok / FAIL lines and a total, then quits. Needs a window (the camera
## and the HUD), so run it off-screen:
##   godot --path . -- --host --team=0 --keys-test --offscreen
## Nothing is saved: test runs never write the player's bindings.

var world: World
var _fails := 0
var _n := 0


func _ready() -> void:
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	_n += 1
	if not ok:
		_fails += 1
		TestRun.fail()
	print("KEYTEST %s %s  %s" % ["ok  " if ok else "FAIL", what, detail])


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


static func _key(code: int, down := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code & KEY_CODE_MASK
	e.pressed = down
	e.ctrl_pressed = (code & KEY_MASK_CTRL) != 0
	e.shift_pressed = (code & KEY_MASK_SHIFT) != 0
	e.alt_pressed = (code & KEY_MASK_ALT) != 0
	return e


func _press(code: int) -> void:
	world.input._unhandled_input(_key(code))
	world.input._unhandled_input(_key(code, false))


## A side button pressed or let go, fed to the engine as a real mouse's would
## be (mid-screen, over the battlefield), so Input knows whether it's held.
func _side_button(down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_XBUTTON1
	mb.button_mask = MOUSE_BUTTON_MASK_MB_XBUTTON1 if down else 0
	mb.pressed = down
	mb.position = get_viewport().get_visible_rect().size * 0.5
	mb.global_position = mb.position
	Input.parse_input_event(mb)


## Waits until it's so, or a few seconds: an event fed to the engine reaches
## the game a frame later, and off-screen frames are slow.
func _until(cond: Callable, limit := 3.0) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await _wait(0.1)
		t += 0.1


func _run() -> void:
	while world.input == null or world.hud == null or world.time < 1.5:
		await _wait(0.2)
	var inp := world.input
	assert(Settings.no_save)
	# --- names and matching
	_check("Ctrl + F reads as Ctrl + F", Keys.name_of(KEY_F | KEY_MASK_CTRL) == "Ctrl + F", Keys.name_of(KEY_F | KEY_MASK_CTRL))
	_check("a typed name parses back", Keys.parse("Ctrl+F") == (KEY_F | KEY_MASK_CTRL) and Keys.parse("Mouse4") == -MOUSE_BUTTON_XBUTTON1)
	_check("brackets and keypad read plainly", Keys.name_of(KEY_BRACKETLEFT) == "[" and Keys.name_of(KEY_KP_ADD) == "Num +")
	_check("F means the fire mission", Keys.action_for(_key(KEY_F), PlayerInput.KEY_ACTIONS) == "fire_mission")
	_check("Ctrl + F means follow, not the fire mission", Keys.action_for(_key(KEY_F | KEY_MASK_CTRL), PlayerInput.KEY_ACTIONS) == "cam_follow")
	_check("Shift + R still retreats", Keys.action_for(_key(KEY_R | KEY_MASK_SHIFT), PlayerInput.KEY_ACTIONS) == "retreat")
	_check("Shift + Enter is team chat", Keys.action_for(_key(KEY_ENTER | KEY_MASK_SHIFT), PlayerInput.KEY_ACTIONS) == "chat_team")
	_check("Ctrl + 3 sets group 3", Keys.action_for(_key(KEY_3 | KEY_MASK_CTRL), PlayerInput.KEY_ACTIONS) == "group_set_3")
	# --- clashes
	var cl := Keys.clashes("defend", KEY_X)
	_check("X for defend clashes with attack-move", cl.size() == 1 and cl[0][0] == "attack_move", str(cl))
	_check("R for turning a building doesn't clash with retreat", Keys.clashes("rotate_build", KEY_R).is_empty())
	_check("a camera key clashes with an order", not Keys.clashes("cam_up", KEY_H).is_empty())
	_check("an observer key doesn't clash with an order", Keys.clashes("pause", KEY_H).is_empty())
	# --- presses reaching the game
	inp.clear_selection()
	for s in world.soldiers:
		if s.owner_peer == world.local_peer and s.sid != 0:
			inp.sel_squads.append(s.sid)
			break
	_check("a squad to give orders to", inp.has_units())
	_press(KEY_X)
	_check("X arms attack-move", inp.order_mode == "assault", inp.order_mode)
	inp.cancel_modes()
	Keys.set_bind("attack_move", 0, KEY_K)
	_press(KEY_X)
	_check("rebound to K, X no longer does it", inp.order_mode == "", inp.order_mode)
	_press(KEY_K)
	_check("and K does", inp.order_mode == "assault", inp.order_mode)
	inp.cancel_modes()
	Keys.reset("attack_move")
	_check("the hint on the command card follows", Keys.label("attack_move") == "X")
	inp.start_place("sandbags")
	var y0: float = inp.place_yaw
	_press(KEY_R)
	_check("placing, R turns the building", absf(inp.place_yaw - y0 - PI * 0.5) < 0.001 and inp.place_kind == "sandbags")
	inp.cancel_modes()
	# --- a mouse side button on the tactical map: a tap switches to the map when
	# it's let go, held it shows the statistics. The release of a side button is
	# noticed through Input's state, so the presses go through the engine
	Keys.set_bind("tactical", 1, -MOUSE_BUTTON_XBUTTON1)
	var tac: bool = world.hud.tactical
	_side_button(true)
	_side_button(false)
	await _until(func() -> bool: return world.hud.tactical != tac)
	_check("a mouse side button can be bound", world.hud.tactical != tac)
	if world.hud.tactical != tac:
		world.hud.toggle_tactical()
	_side_button(true)
	await _until(func() -> bool: return inp._tab_peek)
	_check("held, the side button shows the statistics", inp._tab_peek)
	_side_button(false)
	await _until(func() -> bool: return inp._tab_down < 0)
	_check("let go, they go away and the map stays as it was", inp._tab_down < 0 and world.hud.tactical == tac)
	Keys.reset("tactical")
	# --- a held key driving the camera
	var cam := world.cam
	cam.stop_follow()
	Keys.set_bind("cam_up", 0, KEY_I)
	var f0 := cam.focus_pos
	Input.parse_input_event(_key(KEY_I))
	await _wait(0.5)
	Input.parse_input_event(_key(KEY_I, false))
	await _wait(0.2)
	var fwd := Vector3(-sin(cam.yaw), 0, -cos(cam.yaw))
	_check("held, a rebound key pans the camera", (cam.focus_pos - f0).dot(fwd) > 1.0, "%.1f m forward" % (cam.focus_pos - f0).dot(fwd))
	Keys.reset("cam_up")
	# --- the Controls page
	var sp: SettingsPanel = world.hud.settings_panel
	sp.visible = true
	sp._show_tab("controls")
	await _wait(0.2)
	var cp: ControlsPage = sp._pages["controls"]
	cp._start_capture("hold", 0)
	_check("waiting for a key, the game leaves the keys alone", Keys.capturing)
	cp._input(_key(KEY_J))
	_check("the page binds the key pressed", Keys.get_bind("hold", 0) == KEY_J and not Keys.capturing)
	cp._start_capture("defend", 0)
	cp._input(_key(KEY_X))
	_check("taking X for defend moves it off attack-move", Keys.get_bind("defend", 0) == KEY_X and Keys.get_bind("attack_move", 0) == Keys.NONE)
	_check("and says so", cp._msg.text.contains("Attack-move") and cp._undo.visible, cp._msg.text)
	cp._on_undo()
	_check("Undo puts both back", Keys.get_bind("defend", 0) == KEY_B and Keys.get_bind("attack_move", 0) == KEY_X)
	cp._start_capture("cam_fast", 0)
	cp._input(_key(KEY_CTRL | KEY_MASK_CTRL))
	cp._input(_key(KEY_CTRL, false))
	_check("a modifier on its own can be the key", Keys.get_bind("cam_fast", 0) == KEY_CTRL, Keys.name_of(Keys.get_bind("cam_fast", 0)))
	cp._start_capture("grenade", 1)
	cp._input(_key(KEY_ESCAPE))
	_check("Esc calls it off", Keys.get_bind("grenade", 1) == Keys.NONE and not Keys.capturing)
	cp._search.text = "smoke"
	cp._filter()
	var shown := 0
	for id in cp._rows:
		if (cp._rows[id].row as Control).visible:
			shown += 1
	_check("search finds the action", shown >= 1 and (cp._rows["smoke"].row as Control).visible and not (cp._rows["hold"].row as Control).visible, "%d shown" % shown)
	cp._search.text = ""
	Keys.reset_all()
	_check("reset all puts every default back", Keys.is_default("hold") and Keys.is_default("cam_fast"))
	sp.visible = false
	print("KEYTEST %d/%d passed" % [_n - _fails, _n])
	TestRun.quit(get_tree())
