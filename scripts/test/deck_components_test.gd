extends Node
## Contracts for reusable components, deliberately without a World or HUD.
var checks := 0


func _check(message: String, passed: bool) -> void:
	checks += 1
	print("DECK %s %s" % ["ok" if passed else "FAIL", message])
	if not passed:
		TestRun.fail()


func _settle() -> void:
	for i in 8:
		await get_tree().process_frame


func _ready() -> void:
	TestRun.watch()
	Settings.no_save = true
	var stage := Control.new()
	stage.theme = UiKit.theme()
	stage.size = Vector2(1000, 800)
	add_child(stage)
	var grid := UiDeckGrid.new()
	stage.add_child(grid)
	var called: Array = []
	var action := grid.add_action({"id": "translated_attack", "label": "Avancer", "icon": "attack", "key": "Ctrl+Shift+X"}, func(): called.append("attack"))
	var disabled := grid.add_action({"id": "locked", "label": "Locked", "disabled": true, "value": "200"})
	await _settle()
	_check("grid uses the shared surface without the menu frame", grid.get_theme_stylebox("panel") is StyleBoxEmpty)
	_check("translated label does not choose the icon", action.icon_id == "attack" and action.action_id == "translated_attack")
	_check("full rebound shortcut is available in tooltip", action.tooltip_text.contains("Ctrl+Shift+X"))
	action.set_active(true)
	_check("active state reaches the keycap", action.active and action.keycap.active)
	_check("disabled actions retain their value", disabled.disabled and disabled.value_label.text == "200")
	for width in [348.0, 288.0, 320.0]:
		grid.fit_width(width)
		await _settle()
		_check("key stays in its resized tile at %d" % width, action.get_global_rect().grow(1).encloses(action.keycap.get_global_rect()))
		_check("caption stays in its resized tile at %d" % width, action.get_global_rect().grow(1).encloses(action.caption.get_global_rect()))
	# Native keyboard dispatch must work outside the battle's shortcut handler.
	action.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await _settle()
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	Input.parse_input_event(key)
	await _settle()
	_check("focused action supports native keyboard activation", called == ["attack"])
	# Reconfiguration must clear old hints, value and targeting appearance.
	action.configure({"id": "cost", "label": "Build", "value": "150", "icon": "build"})
	_check("reconfiguration replaces shortcut and active state", not action.active and not action.keycap.visible and action.value_label.visible and action.value_label.text == "150")
	action.configure({"id": "translated_attack", "label": "Avancer", "icon": "attack", "key": "X", "active": true})
	var prior_theme := UiKit.theme_key
	for theme_key in UiKit.THEMES:
		UiKit.apply_theme(theme_key, get_tree())
		await _settle()
		_check("active caption follows theme %s" % theme_key, action.caption.get_theme_color("font_color") == UiKit.ACCENT)
		_check("active key follows theme %s" % theme_key, action.keycap.caption.get_theme_color("font_color") == UiKit.ON_ACCENT)
	UiKit.apply_theme(prior_theme, get_tree())
	var preview := UiModelPreview.new()
	stage.add_child(preview)
	var first := MeshInstance3D.new()
	first.mesh = BoxMesh.new()
	preview.set_model(first)
	_check("preview accepts a mesh as its root", preview._bounds(first).size == Vector3.ONE)
	var replacement := Node3D.new()
	preview.set_model(replacement)
	_check("replacing a preview releases the previous model", not is_instance_valid(first) and preview._model == replacement)
	grid.clear_actions()
	_check("clearing removes actions immediately", grid.grid.get_child_count() == 0 and grid.scroll.scroll_vertical == 0)
	var new_action := grid.add_action({"id": "replacement", "label": "New", "icon": "build"}, func(): called.append("new"))
	new_action.pressed.emit()
	_check("recomposing does not retain stale callbacks", called == ["attack", "new"])
	grid.clear_actions()
	grid.paged = true
	for i in 14:
		grid.add_action({"id": str(i), "label": "Build", "key": "Alt + 1", "value": "150"})
	await _settle()
	_check("pages expose only nine actions at a time", grid.page_count() == 2 and grid.grid.get_child(8).visible and not grid.grid.get_child(9).visible)
	grid.turn_page(1)
	_check("next page replaces the visible actions", not grid.grid.get_child(0).visible and grid.grid.get_child(13).visible and grid.next.disabled and not grid.previous.disabled)
	var priced := grid.grid.get_child(13) as UiDeckAction
	_check("cost and shortcut have separate readable space", priced.keycap.visible and priced.value_label.visible and not priced.caption.get_rect().intersects(priced.value_label.get_rect()))
	grid.turn_page(1)
	_check("paging stops at the last page", grid.page == 1)
	grid.clear_actions()
	_check("new selection resets paging", grid.page == 0 and not grid.pager.visible)
	stage.queue_free()
	await _settle()
	while Music._task >= 0:
		await get_tree().process_frame
	print("DECK %d checks complete" % checks)
	TestRun.quit(get_tree())
