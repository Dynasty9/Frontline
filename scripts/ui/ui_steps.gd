class_name UiSteps
extends Range
## A range as a counted bar (docs/UI.md, Meter): `count` square steps, filled
## with the accent to the value. Click or drag along it, or use the arrow keys
## when it has focus. Replaces sliders: settings are counted, not smooth.

signal drag_started
signal drag_ended(value_changed: bool)

var count := 20
var step_w := 7.0
var step_h := 12.0
var _dragging := false
var _drag_from := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	value_changed.connect(func(_v): queue_redraw())
	changed.connect(queue_redraw)


func _get_minimum_size() -> Vector2:
	return Vector2(count * (step_w + 2.0) - 2.0, step_h + 4.0)


func _draw() -> void:
	var span := max_value - min_value
	var frac := 0.0 if span <= 0.0 else (value - min_value) / span
	var filled := frac * count
	var y := (size.y - step_h) * 0.5
	var hot := has_focus() or _dragging
	for i in count:
		var x := i * (step_w + 2.0)
		var on := float(i) < filled - 0.001 or (i == 0 and frac > 0.0)
		var c := UiKit.ACCENT if on else UiKit.RULE2
		if on and hot and i == int(ceil(filled)) - 1:
			c = c.lightened(0.25)
		draw_rect(Rect2(x, y, step_w, step_h), c)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_dragging = true
			_drag_from = value
			drag_started.emit()
			_set_from_x(mb.position.x)
			grab_focus()
		elif _dragging:
			_dragging = false
			drag_ended.emit(not is_equal_approx(value, _drag_from))
			queue_redraw()
		accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		_set_from_x((ev as InputEventMouseMotion).position.x)
		accept_event()
	elif ev.is_action_pressed("ui_left"):
		value -= _key_step()
		accept_event()
	elif ev.is_action_pressed("ui_right"):
		value += _key_step()
		accept_event()


func _key_step() -> float:
	return step if step > 0.0 else (max_value - min_value) / count


func _set_from_x(x: float) -> void:
	var w := count * (step_w + 2.0) - 2.0
	var frac := clampf(x / maxf(w, 1.0), 0.0, 1.0)
	value = min_value + frac * (max_value - min_value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
