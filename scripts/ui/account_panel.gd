class_name AccountPanel
extends PanelContainer
## Signing in, or making an account (Online), from the main menu or at the end
## of a battle. None of it is needed to play; an account keeps your callsign
## yours and every battle you fight on your service record.
##
## A player's game sends them to the website to sign in with GitHub
## (Online.web_sign_in), which makes the account the first time, and waits
## here until the website hands the sign-in back in a frontline:// link. It
## says what's going on as it goes: the steps, which one they're on, and that
## it's still waiting, since the browser is where the work is and nothing in
## the game moves meanwhile. The email and password form is for testing:
## running from source, or against a matchmaker of your own.

signal closed
signal signed_in

## Its size on the screen (UiKit.fit_center): the form's. Sending the player to
## the website, it's only as tall as its words and buttons.
const SIZE := Vector2(500, 440)
## Signing in on the website, step by step.
const WEB_STEPS := [
	"Sign in with GitHub on the Frontline website, in your browser. The first time makes your account.",
	"When your browser asks to open Frontline, let it.",
	"The game signs in, and this closes.",
]

var email: LineEdit
var password: LineEdit
var callsign: LineEdit
var msg: Label
var _title: Label
var _go: Button
var _switch: Button
var _row: HBoxContainer
var _create := false
var _busy := false
var _web := false  # signing in on the website, not in the form
var _suggest := ""
var _close: Button
var _blurb: Label
# signing in on the website: where it's got to, the steps, and what to do if it stalls
var _stage := 0  # 0 waiting for the website, 1 its sign-in is back, -1 that failed
var _status: Label
var _steps: VBoxContainer
var _step_labels: Array = []  # [number, text] for each step
var _hint: Label


func _ready() -> void:
	UiFx.glass(self, 16.0, 24.0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := Label.new()
	head.text = "ACCOUNT"
	head.add_theme_font_override("font", UiFx.spaced(700, 4))
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UiKit.ACCENT)
	v.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", UiFx.spaced(700, 3))
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", UiKit.TEXT)
	v.add_child(_title)
	_blurb = UiKit.label("You don't need an account to play. One keeps your callsign yours (no one else can register it, and battles you host show a tick) and keeps a service record of every battle you fight: your rating, kills and losses, and each battle's after-action report.", 13, UiKit.DIM)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_blurb)
	_status = UiKit.label("", 15, UiKit.ACCENT, 600)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_steps = VBoxContainer.new()
	_steps.add_theme_constant_override("separation", 6)
	v.add_child(_steps)
	for i in WEB_STEPS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := UiKit.label(str(i + 1), 15, UiKit.DIM, 700)
		n.custom_minimum_size = Vector2(16, 0)
		var t := UiKit.label(WEB_STEPS[i], 13, UiKit.DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(t)
		_steps.add_child(row)
		_step_labels.append([n, t])
	_hint = UiKit.label("No page in your browser? Press Open it again. Signed in there, but nothing happened here? Press Open Frontline on the page: the game has to be running to take it.", 12, UiKit.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	email = LineEdit.new()
	email.placeholder_text = "Email"
	password = LineEdit.new()
	password.placeholder_text = "Password (8 characters or more)"
	password.secret = true
	password.text_submitted.connect(func(_t): _submit())
	callsign = LineEdit.new()
	callsign.placeholder_text = "Callsign (what other players see)"
	callsign.max_length = 20
	callsign.text_submitted.connect(func(_t): _submit())
	for e: LineEdit in [email, password, callsign]:
		e.custom_minimum_size = Vector2(0, 36)
		v.add_child(e)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	v.add_child(_row)
	_go = _button("Sign in", _submit)
	_go.custom_minimum_size = Vector2(150, 38)
	_row.add_child(_go)
	_switch = _button("New here? Create an account", func(): _set_mode(not _create))
	_switch.flat = true
	_switch.add_theme_color_override("font_color", UiKit.ACCENT)
	_switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_switch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_row.add_child(_switch)
	_close = _button("Close", func(): visible = false; closed.emit())
	_row.add_child(_close)
	msg = UiKit.label("", 13, UiKit.DIM)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	Online.account_changed.connect(_on_account_changed)
	Online.web_sign_in_received.connect(_on_web_received)
	Online.web_sign_in_failed.connect(_on_web_failed)
	set_process(false)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


## Opens on the sign-in form, or the new-account one (with a callsign to
## suggest). Says up front if this matchmaker has no accounts, or can't be reached.
func open(create := false, suggest := "") -> void:
	_web = Online.web_sign_in
	# under the buttons, but for the website what to do comes before them
	msg.get_parent().move_child(msg, -1)
	if _web:
		msg.get_parent().move_child(msg, _row.get_index())
	UiKit.fit_center(self, Vector2(SIZE.x, 0.0) if _web else SIZE)
	visible = true
	UiFx.pop(self)
	Sfx.ui("ui_whoosh", -18.0, 1.15)
	msg.text = ""
	_busy = false
	_suggest = suggest if suggest != "Commander" else ""
	if callsign.text == "":
		callsign.text = _suggest
	_set_mode(create)
	if _web:
		_open_website()
	else:
		email.grab_focus.call_deferred()
	var r: Dictionary = await Online.check()
	if not visible:
		return
	if not r.ok:
		msg.text = String(r.error)
	elif String(r.data.get("accounts", "off")) == "off":
		msg.text = "This matchmaker doesn't have accounts switched on. You can still play online under any callsign."
		_go.disabled = true


func _set_mode(create: bool) -> void:
	_create = create
	_title.text = "CREATE AN ACCOUNT" if create and not _web else "SIGN IN"
	_go.text = "Open the website" if _web else "Create account" if create else "Sign in"
	_switch.text = "I already have an account" if create else "New here? Create an account"
	email.visible = not _web
	password.visible = not _web
	callsign.visible = create and not _web
	_switch.visible = not _web
	# the website's way in tells its steps instead of what an account is for:
	# the player chose to sign in already
	_blurb.visible = not _web
	for c: Control in [_status, _steps, _hint]:
		c.visible = _web
	_close.text = "Cancel" if _web else "Close"
	_go.disabled = false
	msg.text = ""


## Off to the website, in the browser: the game waits here for it.
func _open_website() -> void:
	Online.open_web_sign_in(_create, _suggest if _create else "")
	_go.text = "Open it again"
	_show_stage(0, "")


## Where signing in on the website has got to: each step done (green), under
## way, or still to come (dim), and a line saying so. While it waits the line's
## dots keep moving (_process), so it's plain the game hasn't stalled.
func _show_stage(stage: int, text: String) -> void:
	_stage = stage
	var at := 2 if stage == 1 else 0
	for i in _step_labels.size():
		var col: Color = UiKit.GOOD if i < at else UiKit.TEXT if i == at else UiKit.DIM
		for l: Label in _step_labels[i]:
			l.add_theme_color_override("font_color", col)
	var status_col: Color = UiKit.GOOD if stage == 1 else UiKit.BAD if stage == -1 else UiKit.ACCENT
	_status.add_theme_color_override("font_color", status_col)
	_status.text = text
	set_process(stage == 0)
	_process(0.0)


func _process(_dt: float) -> void:
	if not visible or not _web or _stage != 0:
		set_process(false)
		return
	_status.text = "Waiting for the website" + ".".repeat(int(Time.get_ticks_msec() / 400.0) % 4)


func _on_web_received() -> void:
	if visible and _web:
		_show_stage(1, "Back from the website. Signing in...")


func _on_account_changed() -> void:
	if visible and _web and Online.signed_in():
		visible = false
		signed_in.emit()


func _on_web_failed(error: String) -> void:
	if not visible or not _web:
		return
	_go.text = "Try again"
	_show_stage(-1, error)


func _submit() -> void:
	if _web:
		_open_website()
		return
	if _busy:
		return
	_busy = true
	_go.disabled = true
	msg.add_theme_color_override("font_color", UiKit.DIM)
	msg.text = "Creating the account..." if _create else "Signing in..."
	var r: Dictionary
	if _create:
		r = await Online.sign_up(email.text, password.text, callsign.text)
	else:
		r = await Online.sign_in(email.text, password.text)
	_busy = false
	_go.disabled = false
	if not r.ok:
		msg.add_theme_color_override("font_color", UiKit.BAD)
		msg.text = String(r.error)
	elif r.get("confirm", false):
		_set_mode(false)
		msg.text = "Check your email for the confirmation link, then sign in here."
	else:
		password.text = ""
		visible = false
		signed_in.emit()
