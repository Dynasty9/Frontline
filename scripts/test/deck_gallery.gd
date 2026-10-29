extends Control
## --deck-gallery[=PATH] opens the production component workbench; a path captures and exits.
var args := {}
var _frames := 0
var _grid: UiDeckGrid
var _status: Label
var _long := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if args.has("gallery-theme"):
		UiKit.apply_theme(String(args["gallery-theme"]), get_tree())
	theme = UiKit.theme()
	var background := ColorRect.new()
	background.color = UiKit.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(UiKit.caps("Frontline / design tools", 11, UiKit.ACCENT))
	column.add_child(UiKit.caps("Command deck components", 28, UiKit.TEXT))
	column.add_child(UiKit.label("The same controls used in battle. Change the theme, resize the command grid and try an action.", 14, UiKit.DIM))
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 16)
	column.add_child(toolbar)
	toolbar.add_child(UiKit.caps("Theme", 11, UiKit.DIM))
	var themes := OptionButton.new()
	var keys: Array = UiKit.THEMES.keys()
	for key in keys:
		themes.add_item(UiKit.THEMES[key].name)
	themes.select(keys.find(UiKit.theme_key))
	themes.item_selected.connect(func(index: int): UiKit.apply_theme(keys[index], get_tree()))
	toolbar.add_child(themes)
	toolbar.add_child(UiKit.caps("Grid width", 11, UiKit.DIM))
	var width := HSlider.new()
	width.custom_minimum_size = Vector2(180, 30)
	width.min_value = 288
	width.max_value = 348
	width.step = 1
	width.value = 348
	width.value_changed.connect(func(value: float): _grid.fit_width(value); _grid.reset_size())
	toolbar.add_child(width)
	var long_list := CheckBox.new()
	long_list.text = "Long command list"
	long_list.toggled.connect(func(value: bool): _long = value; _populate())
	toolbar.add_child(long_list)
	_status = UiKit.mono_label("READY · choose an action", 12, UiKit.ACCENT)
	column.add_child(_status)
	var panels := HFlowContainer.new()
	panels.add_theme_constant_override("h_separation", 20)
	panels.add_theme_constant_override("v_separation", 20)
	column.add_child(panels)
	var commands := _section(panels, "01 / Command grid", 370)
	commands.add_child(UiKit.label("Selected · disabled · danger · cost · rebound key", 12, UiKit.DIM))
	_grid = UiDeckGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.title.text = "Unit orders"
	commands.add_child(_grid)
	_populate()
	var instruments := _section(panels, "02 / Navigation & shortcuts", 390)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	instruments.add_child(tools)
	for item in [["units", "Units"], ["support", "Support"], ["layers", "Layers"]]:
		var button := UiDeckNav.new()
		button.icon_id = item[0]
		button.caption = item[1]
		button.custom_minimum_size.x = 106
		button.pressed.connect(func(): _status.text = "TOOL · " + button.caption.to_upper())
		tools.add_child(button)
		button.custom_minimum_size.x = 106
	instruments.add_child(UiKit.label("Key hints retain their full binding in a tooltip.", 12, UiKit.DIM))
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 12)
	instruments.add_child(hints)
	for binding in ["X", "Ctrl+Shift+T", "Space"]:
		var hint := UiDeckKeycap.new()
		hint.set_binding(binding)
		hints.add_child(hint)
		if binding == "X":
			hint.set_active(true)
	instruments.add_child(UiKit.header("Semantic icons"))
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 6)
	icons.add_theme_constant_override("v_separation", 6)
	instruments.add_child(icons)
	for icon_id in UiDeckIcons.IDS:
		var action := UiDeckAction.new()
		action.configure({"id": icon_id, "icon": icon_id, "label": icon_id})
		action.custom_minimum_size.x = 80
		action.pressed.connect(func(): _status.text = "ICON · " + action.icon_id.to_upper())
		icons.add_child(action)
	var previews := _section(panels, "03 / Model stage", 370)
	previews.add_child(UiKit.label("An isolated model preview with no battle attached.", 12, UiKit.DIM))
	var preview := UiModelPreview.new()
	preview.custom_minimum_size = Vector2(330, 210)
	previews.add_child(preview)
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.scale = Vector3(1.8, 0.6, 2.5)
	model.add_child(mesh)
	var turret := MeshInstance3D.new()
	turret.mesh = CylinderMesh.new()
	turret.scale = Vector3(0.8, 0.3, 0.8)
	turret.position.y = 0.5
	model.add_child(turret)
	preview.set_model(model)
	previews.add_child(UiKit.mono_label("STATIC RENDER · RESIZE / THEME UPDATES", 10, UiKit.DIM))
	var empty := UiDeckEmptyState.new()
	empty.configure({"eyebrow": "04 / Empty state", "title": "Awaiting selection", "body": "Give the player a clear next action.", "code": "CONTEXTUAL GUIDANCE",
		"help_title": "Composition", "help_lines": ["Reusable surface, type and spacing.", "Data supplied by the host screen.", "Shared by commander and observer views."]})
	column.add_child(empty)


func _section(parent: Control, heading: String, width: float) -> VBoxContainer:
	var surface := UiDeckSurface.new()
	surface.custom_minimum_size.x = width
	parent.add_child(surface)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	surface.add_child(content)
	content.add_child(UiKit.caps(heading, 13, UiKit.TEXT))
	return content


func _populate() -> void:
	_grid.clear_actions()
	var specs := [
		{"id": "attack", "label": "Attack-move", "icon": "attack", "key": "X", "active": true},
		{"id": "defend", "label": "Defend", "icon": "defend", "key": "B"},
		{"id": "base", "label": "Base", "icon": "build", "value": "150"},
		{"id": "grenade", "label": "Grenade", "icon": "grenade", "key": "G", "disabled": true, "tooltip": "Unavailable: no grenades remaining."},
		{"id": "smoke", "label": "Smoke", "icon": "smoke", "key": "Ctrl+Shift+T"},
		{"id": "hold", "label": "Hold", "icon": "hold", "key": "H"},
		{"id": "retreat", "label": "Retreat", "icon": "back", "key": "R", "dangerous": true}]
	if _long:
		for i in 9:
			specs.append({"id": "build_%d" % i, "label": "Building %d" % (i + 1), "icon": "build", "value": str(100 + i * 25)})
	for spec in specs:
		var button := _grid.add_action(spec)
		button.pressed.connect(func():
			for action: UiDeckAction in _grid.grid.get_children():
				action.set_active(action == button)
			_status.text = "ACTION · " + button.action_id.to_upper())


func _process(_dt: float) -> void:
	_frames += 1
	var path := String(args.get("deck-gallery", ""))
	if _frames == 30 and not path.is_empty() and path != "true":
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		# The audio autoload may still be generating its first samples.
		while Music._task >= 0:
			await get_tree().process_frame
		TestRun.quit(get_tree())
