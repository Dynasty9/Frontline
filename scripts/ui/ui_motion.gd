class_name UiMotion
extends RefCounted
## The interface's motions (docs/UI.md, Motion). A display redraws: it doesn't
## swing, bounce or glide. State changes cut. New things arrive a few pixels
## from where they belong, in their first frame, fast and exactly; text types
## on; figures count; an alert flickers on. Every screen moves with these and
## nothing else, and Settings > Interface > Reduce motion makes all of them cut.

const QUICK := 0.12  # an arrival or a departure
const BASE := 0.16  # a dialog, a screen's content
const INSTANT := 0.06  # one frame of a flicker
const TYPE := 0.018  # per character typing on
const TYPE_MAX := 0.3  # the longest a line takes to type on
const TRAVEL_SM := 4.0  # rows and lines
const TRAVEL_MD := 8.0  # lists, panels, dialogs
const STAGGER := 0.016  # between rows arriving


static func reduced() -> bool:
	return Settings.get_v("reduce_motion") == true


## A control arriving from `from` (a direction: Vector2(-1, 0) is from the
## left): it's drawn in its first frame `travel` pixels off and slides into
## place. In a container it waits a frame for the container to place it.
static func arrive(c: Control, from := Vector2(-1, 0), delay := 0.0, travel := TRAVEL_MD, dur := QUICK) -> void:
	if not is_instance_valid(c):
		return
	if reduced():
		finish_arrive(c)
		return
	if delay > 0.0:
		c.modulate.a = 0.0
	if c.get_parent() is Container:
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	# A quick close and reopen starts from the resting place, not halfway
	# through the previous arrival. Otherwise fixed dialogs drift each time.
	finish_arrive(c)
	var base := c.position
	c.position = base + from * travel
	if delay > 0.0:
		c.modulate.a = 0.0
	var tw := c.create_tween()
	c.set_meta("ui_arrive", {"tween": tw, "base": base})
	tw.set_ignore_time_scale(true)
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): c.modulate.a = 1.0)
	tw.tween_property(c, "position", base, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): c.remove_meta("ui_arrive"))


## Finish an arrival before another animation or a window resize lays it out.
static func finish_arrive(c: Control) -> void:
	if not c.has_meta("ui_arrive"):
		return
	var old: Dictionary = c.get_meta("ui_arrive")
	(old.tween as Tween).kill()
	c.position = old.base
	c.modulate.a = 1.0
	c.remove_meta("ui_arrive")


## A list's rows arriving one after another (the first eight; the rest with the eighth).
static func stagger(rows: Array, from := Vector2(0, 1), delay := 0.0) -> void:
	for i in rows.size():
		if rows[i] is Control:
			arrive(rows[i], from, delay + mini(i, 7) * STAGGER, TRAVEL_SM)


## A control leaving toward `to`, then hidden (and `then` called).
static func leave(c: Control, to := Vector2(-1, 0), then := Callable()) -> void:
	if reduced() or not is_instance_valid(c) or not c.visible:
		if is_instance_valid(c):
			c.visible = false
		if then.is_valid():
			then.call()
		return
	var base := c.position
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "position", base + to * TRAVEL_MD * 0.5, QUICK).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		c.visible = false
		c.position = base
		if then.is_valid():
			then.call())


## New text typing on, left to right.
static func type_on(l: Label, text: String) -> void:
	l.text = text
	if reduced() or text.is_empty():
		l.visible_ratio = 1.0
		return
	l.visible_ratio = 0.0
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(l, "visible_ratio", 1.0, minf(text.length() * TYPE, TYPE_MAX))


## An alert landing: on, off, on (`times` over).
static func flicker(c: CanvasItem, times := 1) -> void:
	if reduced() or not is_instance_valid(c):
		return
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	for i in times:
		tw.tween_property(c, "modulate:a", 0.0, 0.0).set_delay(INSTANT)
		tw.tween_property(c, "modulate:a", 1.0, 0.0).set_delay(INSTANT)


## A figure counting to its value, written by `fmt` (a Callable taking the
## number and returning the text), with a tick as it goes.
static func count(l: Label, value: float, fmt: Callable, dur := 0.9, delay := 0.0) -> void:
	if reduced():
		l.text = String(fmt.call(value))
		return
	l.text = String(fmt.call(0.0))
	var last := [0]
	var step := func(v: float) -> void:
		l.text = String(fmt.call(v))
		var now := Time.get_ticks_msec()
		if now - int(last[0]) > 55 and v < value:
			last[0] = now
			Sfx.ui("ui_tick", -24.0, randf_range(0.95, 1.08))
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, value, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## How far into a motion `t` seconds is, 0 to 1 (for things that draw
## themselves each frame): exact and fast, or there at once when motion is reduced.
static func progress(t: float, dur := QUICK) -> float:
	if reduced():
		return 1.0
	t = clampf(t / maxf(dur, 0.001), 0.0, 1.0)
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)
