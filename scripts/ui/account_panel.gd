class_name AccountPanel
extends PanelContainer
## Signing in, or making an account (Online), from the main menu or at the end
## of a battle. None of it is needed to play; an account keeps your callsign
## yours and every battle you fight on your service record.

signal closed
signal signed_in

var email: LineEdit
var password: LineEdit
var callsign: LineEdit
var msg: Label
var _title: Label
var _go: Button
var _switch: Button
var _create := false
var _busy := false


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
	var blurb := UiKit.label("You don't need an account to play. One keeps your callsign yours (no one else can register it, and battles you host show a tick) and keeps a service record of every battle you fight: your rating, kills and losses, and each battle's after-action report.", 13, UiKit.DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(blurb)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_go = _button("Sign in", _submit)
	_go.custom_minimum_size = Vector2(150, 38)
	row.add_child(_go)
	_switch = _button("New here? Create an account", func(): _set_mode(not _create))
	_switch.flat = true
	_switch.add_theme_color_override("font_color", UiKit.ACCENT)
	_switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_switch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(_switch)
	row.add_child(_button("Close", func(): visible = false; closed.emit()))
	msg = UiKit.label("", 13, UiKit.DIM)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)


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
	visible = true
	UiFx.pop(self)
	Sfx.ui("ui_whoosh", -18.0, 1.15)
	msg.text = ""
	_busy = false
	if callsign.text == "" and suggest != "Commander":
		callsign.text = suggest
	_set_mode(create)
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
	_title.text = "CREATE AN ACCOUNT" if create else "SIGN IN"
	_go.text = "Create account" if create else "Sign in"
	_switch.text = "I already have an account" if create else "New here? Create an account"
	callsign.visible = create
	_go.disabled = false
	msg.text = ""


func _submit() -> void:
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
