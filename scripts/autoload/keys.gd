extends Node
## Key bindings: every action the keyboard (or an extra mouse button) does,
## grouped the way the Controls page shows them, each with up to two
## bindings. Saved to user://keybinds.cfg (only what differs from the
## defaults, so a new default reaches players who never changed that key).
##
## A binding is one int: a key's keycode with its modifier masks
## (KEY_MASK_CTRL and the like), or minus a mouse button with its masks.
## The game asks `action_for(event, ids)` which of a list of actions a key
## press means (the closest match: exact modifiers first, then the binding
## with the most of the held modifiers, so holding Shift while pressing R
## still retreats), and `held(id)` whether an action's key is down (camera
## movement).

signal changed

const PATH := "user://keybinds.cfg"
const NONE := 0

## Contexts: where an action is listened for. Two bindings clash when their
## contexts can be live at once: anything against "cam" or "ui" (always on in
## a battle), or two of the same. Placing a building takes its keys before the
## commands do, and an observer's keys only matter to an observer, so those
## don't clash with the commands.
const GLOBAL_CTX := ["cam", "ui"]

## The categories in the order they're listed.
const CATEGORIES := ["Camera", "Saved views", "Orders", "Abilities & fire support", "Building", "Control groups",
	"Co-commanders", "Interface", "Observer"]

## [id, label, category, context, default, default (second), what it does]
const ACTIONS := [
	["cam_up", "Pan forward", "Camera", "cam", KEY_W, KEY_UP, "Hold to move the camera the way it faces."],
	["cam_down", "Pan back", "Camera", "cam", KEY_S, KEY_DOWN, ""],
	["cam_left", "Pan left", "Camera", "cam", KEY_A, KEY_LEFT, ""],
	["cam_right", "Pan right", "Camera", "cam", KEY_D, KEY_RIGHT, ""],
	["cam_fast", "Pan faster (hold)", "Camera", "cam", KEY_SHIFT, NONE, "Held with a pan key, the camera moves two and a half times as fast."],
	["cam_turn_left", "Turn left", "Camera", "cam", KEY_Q, NONE, ""],
	["cam_turn_right", "Turn right", "Camera", "cam", KEY_E, NONE, ""],
	["cam_tilt_up", "Tilt up", "Camera", "cam", KEY_PAGEUP, NONE, "Toward the horizon."],
	["cam_tilt_down", "Tilt down", "Camera", "cam", KEY_PAGEDOWN, NONE, "Toward a plan view."],
	["cam_zoom_in", "Zoom in", "Camera", "cam", KEY_EQUAL, KEY_KP_ADD, ""],
	["cam_zoom_out", "Zoom out", "Camera", "cam", KEY_MINUS, KEY_KP_SUBTRACT, ""],
	["cam_reset", "Square the view up", "Camera", "cam", KEY_BACKSPACE, NONE, "Turn back to the heading the battle started on, and the zoom's own tilt."],
	["cam_follow", "Follow the selection", "Camera", "cam", KEY_F | KEY_MASK_CTRL, NONE, "The camera keeps the selected units in view until you pan away."],
	["jump_alert", "Jump to the latest alert or ping", "Camera", "cam", KEY_SPACE, NONE, ""],
	["cycle_fob", "Cycle your bases", "Camera", "cam", KEY_HOME, NONE, ""],
	["view_go_1", "Go to saved view 1", "Saved views", "cam", KEY_F5, NONE, ""],
	["view_go_2", "Go to saved view 2", "Saved views", "cam", KEY_F6, NONE, ""],
	["view_go_3", "Go to saved view 3", "Saved views", "cam", KEY_F7, NONE, ""],
	["view_go_4", "Go to saved view 4", "Saved views", "cam", KEY_F8, NONE, ""],
	["view_save_1", "Save view 1", "Saved views", "cam", KEY_F5 | KEY_MASK_CTRL, NONE, ""],
	["view_save_2", "Save view 2", "Saved views", "cam", KEY_F6 | KEY_MASK_CTRL, NONE, ""],
	["view_save_3", "Save view 3", "Saved views", "cam", KEY_F7 | KEY_MASK_CTRL, NONE, ""],
	["view_save_4", "Save view 4", "Saved views", "cam", KEY_F8 | KEY_MASK_CTRL, NONE, ""],
	["attack_move", "Attack-move", "Orders", "cmd", KEY_X, NONE, "Then click where to push: they bound forward cover to cover and fight what they meet."],
	["defend", "Defend an area", "Orders", "cmd", KEY_B, NONE, "Then click (and drag to face): they spread into the best cover there and hold."],
	["retreat", "Retreat", "Orders", "cmd", KEY_R, NONE, "Back to the nearest FOB, keeping clear of known enemy fire."],
	["hold", "Hold position", "Orders", "cmd", KEY_H, NONE, ""],
	["grenade", "Throw a grenade", "Abilities & fire support", "cmd", KEY_G, NONE, ""],
	["smoke", "Throw smoke", "Abilities & fire support", "cmd", KEY_T, NONE, ""],
	["fire_mission", "Fire mission", "Abilities & fire support", "cmd", KEY_F, NONE, "Mortar teams and artillery: then click the target."],
	["support", "Call fire support", "Abilities & fire support", "cmd", KEY_Z, NONE, "Arms the first air or artillery support that's ready."],
	["rotate_build", "Turn the building 90°", "Building", "place", KEY_R, NONE, "While placing. (Shift + wheel turns it 45°.)"],
	["group_1", "Select group 1", "Control groups", "cmd", KEY_1, NONE, "Press twice quickly to jump there."],
	["group_2", "Select group 2", "Control groups", "cmd", KEY_2, NONE, ""],
	["group_3", "Select group 3", "Control groups", "cmd", KEY_3, NONE, ""],
	["group_4", "Select group 4", "Control groups", "cmd", KEY_4, NONE, ""],
	["group_5", "Select group 5", "Control groups", "cmd", KEY_5, NONE, ""],
	["group_6", "Select group 6", "Control groups", "cmd", KEY_6, NONE, ""],
	["group_7", "Select group 7", "Control groups", "cmd", KEY_7, NONE, ""],
	["group_8", "Select group 8", "Control groups", "cmd", KEY_8, NONE, ""],
	["group_9", "Select group 9", "Control groups", "cmd", KEY_9, NONE, ""],
	["group_0", "Select group 0", "Control groups", "cmd", KEY_0, NONE, ""],
	["group_set_1", "Set group 1", "Control groups", "cmd", KEY_1 | KEY_MASK_CTRL, NONE, "Makes the selection group 1."],
	["group_set_2", "Set group 2", "Control groups", "cmd", KEY_2 | KEY_MASK_CTRL, NONE, ""],
	["group_set_3", "Set group 3", "Control groups", "cmd", KEY_3 | KEY_MASK_CTRL, NONE, ""],
	["group_set_4", "Set group 4", "Control groups", "cmd", KEY_4 | KEY_MASK_CTRL, NONE, ""],
	["group_set_5", "Set group 5", "Control groups", "cmd", KEY_5 | KEY_MASK_CTRL, NONE, ""],
	["group_set_6", "Set group 6", "Control groups", "cmd", KEY_6 | KEY_MASK_CTRL, NONE, ""],
	["group_set_7", "Set group 7", "Control groups", "cmd", KEY_7 | KEY_MASK_CTRL, NONE, ""],
	["group_set_8", "Set group 8", "Control groups", "cmd", KEY_8 | KEY_MASK_CTRL, NONE, ""],
	["group_set_9", "Set group 9", "Control groups", "cmd", KEY_9 | KEY_MASK_CTRL, NONE, ""],
	["group_set_0", "Set group 0", "Control groups", "cmd", KEY_0 | KEY_MASK_CTRL, NONE, ""],
	["ping", "Ping at the cursor (hold: wheel)", "Co-commanders", "cmd", NONE, NONE, "Tap: ping what's under the cursor. Hold: the ping wheel. (Alt + click does the same.)"],
	["coop_next", "Look at the next co-commander's view", "Co-commanders", "cmd", NONE, NONE, "Each press glides to the next commander on your side."],
	["tactical", "Tactical map", "Interface", "ui", KEY_TAB, NONE, ""],
	["orbat", "Order of battle", "Interface", "ui", KEY_O, NONE, ""],
	["log", "Message history", "Interface", "ui", KEY_L, NONE, ""],
	["chat", "Chat to everyone", "Interface", "ui", KEY_ENTER, KEY_KP_ENTER, ""],
	["chat_team", "Chat to your side", "Interface", "ui", KEY_ENTER | KEY_MASK_SHIFT, NONE, ""],
	["help", "Controls (help)", "Interface", "ui", KEY_F1, NONE, ""],
	["hide_hud", "Hide the interface", "Interface", "ui", KEY_F2, NONE, ""],
	["perf", "Performance overlay", "Interface", "ui", KEY_F3, NONE, "Off, FPS, compact, full breakdown."],
	["manual", "Field Manual", "Interface", "ui", KEY_F4, NONE, ""],
	["console", "Console", "Interface", "ui", KEY_QUOTELEFT, NONE, "Type commands: why the game is slow (why), what each setting costs (bench), frame graphs. help lists them."],
	["director", "Director camera", "Observer", "obs", KEY_C, NONE, "The camera follows the fighting by itself."],
	["pause", "Pause", "Observer", "obs", KEY_P, NONE, ""],
	["slower", "Slower", "Observer", "obs", KEY_BRACKETLEFT, NONE, ""],
	["faster", "Faster", "Observer", "obs", KEY_BRACKETRIGHT, NONE, ""],
	["view_side", "Whose eyes to watch through", "Observer", "obs", KEY_V, NONE, "Both sides, or one side's fog of war."],
]

## The mouse, for reference on the Controls page (not rebindable here).
const MOUSE := [
	["Select a squad / drag a box", "Left click / drag"],
	["Add to the selection", "Shift + click"],
	["Every unit of that type on screen", "Double-click"],
	["Command one soldier on his own", "Alt + click him"],
	["Move, attack, build, enter, board", "Right click"],
	["Run there / set their facing", "Shift + right click / right-drag"],
	["Attack-move there", "Ctrl + right click"],
	["Ping / ping wheel", "Alt + click / hold Alt + left button"],
	["Draw on the map for your side", "Alt + right-drag"],
	["Turn and tilt the camera", "Middle-drag"],
	["Grab the map", "Alt + middle-drag"],
	["Zoom toward the cursor", "Mouse wheel"],
	["Turn a building 45°", "Shift + mouse wheel"],
	["A straight trench line", "Hold Alt while dragging it"],
	["Menu / cancel", "Esc"],
]

const MODS := KEY_MASK_SHIFT | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_META

var binds := {}  # id -> [code, code]
var capturing := false  # the Controls page is waiting for a key: the game leaves the keys alone
var console_open := false  # the keys are going into the console: the game leaves them alone too
var _info := {}  # id -> its row in ACTIONS


func _ready() -> void:
	for a in ACTIONS:
		_info[a[0]] = a
	reset_all(false)
	_load()
	# --bind=id:Key[,id:Key...] (tests): rebind for this run only
	for arg in OS.get_cmdline_user_args():
		var s := String(arg)
		if s.begins_with("--bind="):
			for kv in s.substr(7).split(","):
				var p := kv.split(":", true, 1)
				if p.size() == 2 and _info.has(p[0]):
					binds[p[0]] = [parse(p[1]), NONE]


# --- what's bound ----------------------------------------------------------------------------

func has(id: String) -> bool:
	return _info.has(id)


func defaults(id: String) -> Array:
	var a: Array = _info.get(id, [])
	return [int(a[4]), int(a[5])] if not a.is_empty() else [NONE, NONE]


func get_bind(id: String, slot: int) -> int:
	var b: Array = binds.get(id, [NONE, NONE])
	return int(b[slot]) if slot < b.size() else NONE


func is_default(id: String) -> bool:
	var b: Array = binds.get(id, [NONE, NONE])
	var d := defaults(id)
	return int(b[0]) == d[0] and int(b[1]) == d[1]


func set_bind(id: String, slot: int, code: int) -> void:
	if not _info.has(id):
		return
	var b: Array = (binds.get(id, [NONE, NONE]) as Array).duplicate()
	b[slot] = code
	# a single binding always sits in the first slot
	if int(b[0]) == NONE and int(b[1]) != NONE:
		b = [b[1], NONE]
	binds[id] = b
	save()
	changed.emit()


func reset(id: String) -> void:
	binds[id] = defaults(id)
	save()
	changed.emit()


func reset_all(persist := true) -> void:
	for a in ACTIONS:
		binds[a[0]] = [int(a[4]), int(a[5])]
	if persist:
		save()
		changed.emit()


## The other actions a binding would clash with if `id` had it: [[id, slot], ...].
func clashes(id: String, code: int) -> Array:
	var out := []
	if code == NONE or not _info.has(id):
		return out
	var ctx := String(_info[id][3])
	for a in ACTIONS:
		var other: String = a[0]
		if other == id or not _clash_ctx(ctx, String(a[3])):
			continue
		for slot in 2:
			if get_bind(other, slot) == code:
				out.append([other, slot])
	return out


static func _clash_ctx(a: String, b: String) -> bool:
	return a == b or a in GLOBAL_CTX or b in GLOBAL_CTX


# --- matching --------------------------------------------------------------------------------

## How well a key press or mouse click matches a binding: 2 the very key and
## modifiers, 1 the key with extra modifiers held, 0 not at all.
static func quality(ev: InputEvent, code: int) -> int:
	if code == NONE:
		return 0
	var want_mods := 0
	var held_mods := 0
	if code > 0:
		if not ev is InputEventKey:
			return 0
		var k := ev as InputEventKey
		var key := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if key != (code & KEY_CODE_MASK):
			return 0
		want_mods = code & MODS
		held_mods = int(k.get_modifiers_mask()) & ~_own_mask(key)
	else:
		if not ev is InputEventMouseButton:
			return 0
		var mb := ev as InputEventMouseButton
		var c := -code
		if mb.button_index != (c & KEY_CODE_MASK):
			return 0
		want_mods = c & MODS
		held_mods = int(mb.get_modifiers_mask())
	if held_mods == want_mods:
		return 2
	return 1 if (held_mods & want_mods) == want_mods else 0


## A modifier key's own mask (pressing Shift reports Shift held).
static func _own_mask(key: int) -> int:
	match key:
		KEY_SHIFT:
			return KEY_MASK_SHIFT
		KEY_CTRL:
			return KEY_MASK_CTRL
		KEY_ALT:
			return KEY_MASK_ALT
		KEY_META:
			return KEY_MASK_META
	return 0


## Which of these actions a key press (or mouse click) means: the closest
## match, the earlier in the list on a tie. "" for none.
func action_for(ev: InputEvent, ids: Array) -> String:
	var best := ""
	var bq := 0
	for id in ids:
		var b: Array = binds.get(id, [])
		for code in b:
			var q := quality(ev, int(code))
			if q > bq:
				bq = q
				best = id
	return best


## Whether this press is this action (its best reading, among just itself).
func is_event(ev: InputEvent, id: String) -> bool:
	return action_for(ev, [id]) == id


## Whether an action's key (or button) is held down now, with its modifiers.
func held(id: String) -> bool:
	for code in binds.get(id, []):
		var c := int(code)
		if c == NONE:
			continue
		var mods := (c if c > 0 else -c) & MODS
		if mods & KEY_MASK_SHIFT and not Input.is_key_pressed(KEY_SHIFT):
			continue
		if mods & KEY_MASK_CTRL and not Input.is_key_pressed(KEY_CTRL):
			continue
		if mods & KEY_MASK_ALT and not Input.is_key_pressed(KEY_ALT):
			continue
		if mods & KEY_MASK_META and not Input.is_key_pressed(KEY_META):
			continue
		if c > 0 and Input.is_key_pressed(c & KEY_CODE_MASK):
			return true
		if c < 0 and Input.is_mouse_button_pressed((-c) & KEY_CODE_MASK):
			return true
	return false


## The binding a key press or mouse click would make ("" pieces left out).
static func code_of(ev: InputEvent) -> int:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var key := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		return key | (int(k.get_modifiers_mask()) & ~_own_mask(key))
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return -(mb.button_index | int(mb.get_modifiers_mask()))
	return NONE


# --- names -----------------------------------------------------------------------------------

const KEY_NAMES := {KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_EQUAL: "=", KEY_MINUS: "-", KEY_KP_ADD: "Num +",
	KEY_KP_SUBTRACT: "Num -", KEY_KP_MULTIPLY: "Num *", KEY_KP_DIVIDE: "Num /", KEY_KP_ENTER: "Num Enter",
	KEY_KP_PERIOD: "Num .", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down", KEY_QUOTELEFT: "`", KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'", KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SLASH: "/", KEY_BACKSLASH: "\\", KEY_ESCAPE: "Esc",
	KEY_BACKSPACE: "Backspace", KEY_CTRL: "Ctrl", KEY_CAPSLOCK: "Caps Lock", KEY_INSERT: "Insert", KEY_DELETE: "Delete",
	KEY_SPACE: "Space", KEY_TAB: "Tab", KEY_ENTER: "Enter", KEY_HOME: "Home", KEY_END: "End"}


## A binding as players read it: "Ctrl + F", "Num +", "Mouse 4".
static func name_of(code: int) -> String:
	if code == NONE:
		return ""
	var c := code if code > 0 else -code
	var parts := []
	if c & KEY_MASK_CTRL:
		parts.append("Ctrl")
	if c & KEY_MASK_SHIFT:
		parts.append("Shift")
	if c & KEY_MASK_ALT:
		parts.append("Alt")
	if c & KEY_MASK_META:
		parts.append(meta_name())
	var base := c & KEY_CODE_MASK
	if code < 0:
		parts.append({MOUSE_BUTTON_MIDDLE: "Middle mouse", MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
			MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_RIGHT: "Right mouse"}.get(base, "Mouse %d" % base))
	elif KEY_NAMES.has(base):
		parts.append(KEY_NAMES[base])
	elif base == KEY_META:
		parts.append(meta_name())
	elif base >= KEY_KP_0 and base <= KEY_KP_9:
		parts.append("Num %d" % (base - KEY_KP_0))
	else:
		parts.append(OS.get_keycode_string(base))
	return " + ".join(parts)


## What the key beside Alt is called here: the Windows key, a Mac's Command key.
static func meta_name() -> String:
	return {"Windows": "Win", "macOS": "Cmd"}.get(OS.get_name(), "Meta")


## An action's keys for a hint ("X", "Ctrl + F", "W / Up"); "" if unbound.
func label(id: String, both := false) -> String:
	var a := name_of(get_bind(id, 0))
	var b := name_of(get_bind(id, 1))
	if both and a != "" and b != "":
		return "%s / %s" % [a, b]
	return a if a != "" else b


func title(id: String) -> String:
	return String(_info.get(id, ["", id])[1])


## A key name typed in a test switch ("Ctrl+F", "K", "Mouse4") back to a binding.
static func parse(s: String) -> int:
	var t := s.strip_edges()
	var low := t.to_lower().replace(" ", "")
	for m in ["mouse4", "mouse5", "middlemouse"]:
		if low.ends_with(m):
			var btn: int = {"mouse4": MOUSE_BUTTON_XBUTTON1, "mouse5": MOUSE_BUTTON_XBUTTON2, "middlemouse": MOUSE_BUTTON_MIDDLE}[m]
			var mods := (KEY_MASK_CTRL if "ctrl" in low else 0) | (KEY_MASK_SHIFT if "shift" in low else 0) | (KEY_MASK_ALT if "alt" in low else 0)
			return -(btn | mods)
	return int(OS.find_keycode_from_string(t.replace(" ", "")))


# --- saving ----------------------------------------------------------------------------------

func save() -> void:
	if Settings.no_save:
		return
	var cf := ConfigFile.new()
	for a in ACTIONS:
		if not is_default(a[0]):
			cf.set_value("keys", a[0], binds[a[0]])
	cf.save(PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for id in (cf.get_section_keys("keys") if cf.has_section("keys") else PackedStringArray()):
		var v = cf.get_value("keys", id)
		if _info.has(id) and v is Array and (v as Array).size() == 2:
			binds[id] = [int(v[0]), int(v[1])]
