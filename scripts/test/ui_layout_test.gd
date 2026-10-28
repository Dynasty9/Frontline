extends Node
## Real UI layout without a battle or the matchmaker. The Node test wrapper
## runs this in CI; --ui-layout-shots=DIR also renders the populated screens.

var stage: Control
var hud: Hud
var battle: World
var _n := 0
var _fails := 0


func _ready() -> void:
	TestRun.watch()
	Settings.no_save = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-layout-shots="):
			await _screenshots(arg.trim_prefix("--ui-layout-shots="))
			Sfx._ensure()
			while Music._task >= 0:
				await get_tree().process_frame
			TestRun.quit(get_tree())
			return
	await _run()
	print("UILAYOUT %d/%d passed" % [_n - _fails, _n])
	TestRun.quit(get_tree())


func _check(what: String, ok: bool) -> void:
	_n += 1
	if not ok:
		_fails += 1
		TestRun.fail()
	print("UILAYOUT %s %s" % ["ok" if ok else "FAIL", what])


func _settle() -> void:
	for i in 8:
		await get_tree().process_frame


func _inside(c: Control, bounds: Rect2) -> bool:
	return bounds.grow(1.0).encloses(c.get_global_rect())


func _on_screen(c: Control) -> bool:
	if not c.is_visible_in_tree() or not _inside(c, stage.get_global_rect()):
		return false
	var p := c.get_parent_control()
	while p:
		if p.clip_contents and not _inside(c, p.get_global_rect()):
			return false
		p = p.get_parent_control()
	return true


func _reveal(c: Control) -> void:
	# Work from the innermost scroll to the outer one, like a focused field.
	var p := c.get_parent_control()
	while p:
		if p is ScrollContainer:
			p.ensure_control_visible(c)
			await _settle()
		p = p.get_parent_control()


func _button_named(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found := _button_named(child, text)
		if found:
			return found
	return null


func _players(mode: String) -> void:
	Net.players.clear()
	for id in range(1, 9):
		Net.players[id] = {"name": "Commander %d" % id, "team": 0 if mode == "coop" else id % 2, "ready": true}
	Net.settings = {"name": "Eight commanders", "mode": mode, "coop_side": 0, "max_players": 8}


func _populate_browser(browser: ServerBrowser) -> void:
	browser._entries = [{"key": "layout", "name": "Evening operation", "host": "Commander 1", "mode": "coop", "side": 0,
		"players": 3, "max_players": 8, "teams": [3, 0], "nat": "open", "in_game": false}]
	browser._sel = "layout"
	browser._render()


func _run() -> void:
	stage = Control.new()
	stage.theme = UiKit.theme()
	stage.size = Vector2(1600, 900)
	add_child(stage)
	# Only the real dialog builders need a World; no simulation is started.
	battle = World.new()
	battle.mission_info = {"op": "A long operation name that must wrap rather than push a pause dialog off the screen"}
	hud = Hud.new()
	hud.world = battle
	hud.root = stage
	hud.menu_panel = hud._center_panel(Vector2(340, 316))
	hud.help_panel = hud._center_panel(Vector2(1000, 640))
	hud._build_menu()
	hud._build_help()
	hud._menu_context()
	# Use the menu's own screen positioning without constructing its backdrop.
	var menu := preload("res://scripts/ui/menu.gd").new()
	menu.size = stage.size
	var browser := ServerBrowser.new()
	browser.visible = false
	stage.add_child(browser)
	menu._screen(browser)
	# Do not start online refresh when showing this offline fixture.
	browser.set_block_signals(true)
	browser.visible = true
	browser.set_block_signals(false)
	_populate_browser(browser)
	var direct_join := _button_named(browser, "JOIN")
	_check("direct-connect Join control exists", direct_join != null)
	var joined: Array = []
	browser.join_requested.connect(func(entry: Dictionary): joined.append(entry.key))
	browser._join_btn.pressed.emit()
	_check("browser Join requests the selected battle", joined == ["layout"])
	var direct: Array = []
	browser.direct_requested.connect(func(address: String, port: int, password: String): direct.append([address, port, password]))
	browser._addr.text = "127.0.0.1"
	if direct_join:
		direct_join.pressed.emit()
	_check("direct Join requests the entered address", direct == [["127.0.0.1", Net.DEFAULT_PORT, ""]])
	var lobby := LobbyScreen.new()
	lobby.visible = false
	stage.add_child(lobby)
	menu._screen(lobby)
	lobby.visible = true
	Settings.v.ui_scale = 4.0
	Settings.ui_menu = true
	for pixels in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(800, 600), Vector2(640, 360)]:
		var factor := Settings.ui_factor_for(pixels)
		var logical: Vector2 = pixels / factor
		_check("4x menu scale respects window %s" % pixels, logical.x >= Settings.UI_MIN_MENU.x - 1.0 and logical.y >= Settings.UI_MIN_MENU.y - 1.0)
		stage.size = logical
		menu.size = logical
		menu.resized.emit()  # a detached Control has no viewport to send this
		for mode in ["coop", "versus"]:
			_players(mode)
			lobby.refresh()
			await _settle()
			_check("%s eight-player lobby fits %s" % [mode, pixels], _inside(lobby, stage.get_global_rect()))
			_check("%s Start stays visible %s" % [mode, pixels], _on_screen(lobby._start_btn))
			_check("%s Leave stays visible %s" % [mode, pixels], _on_screen(lobby._leave_btn))
			# A spectator can join either eligible side without the roster
			# pushing its side action below the chat or footer.
			Net.players[1].team = -1
			lobby.refresh()
			await _settle()
			for col: Dictionary in lobby._cols:
				var join: Button = col.join
				if join.visible:
					await _reveal(join)
					_check("%s side Join reachable %s" % [mode, pixels], _on_screen(join))
			# The client footer uses the same container, but Ready instead
			# of Start. Network authority is covered by the multiplayer tests.
			lobby._start_btn.hide()
			lobby._ready_btn.show()
			await _settle()
			_check("%s client Ready stays visible %s" % [mode, pixels], _on_screen(lobby._ready_btn))
		await _reveal(browser._join_btn)
		_check("browser Join reachable %s" % pixels, _on_screen(browser._join_btn) and not browser._join_btn.disabled)
		_check("direct address reachable %s" % pixels, _on_screen(browser._addr))
		_check("direct port reachable %s" % pixels, _on_screen(browser._port))
		_check("direct password reachable %s" % pixels, _on_screen(browser._pw))
		_check("direct Join reachable %s" % pixels, direct_join != null and _on_screen(direct_join))
	# Even a logical viewport below the menu scale floor can scroll to Join.
	stage.size = Vector2(960, 540)
	menu.size = stage.size
	menu.resized.emit()
	await _settle()
	await _reveal(browser._join_btn)
	_check("narrow browser Join scrolls into view", _on_screen(browser._join_btn))
	_check("narrow browser direct address stays in view", _on_screen(browser._addr))
	_check("narrow browser direct Join stays in view", direct_join != null and _on_screen(direct_join))
	_check("narrow browser panel stays in view", _inside(browser, stage.get_global_rect()))
	browser.hide()
	lobby.hide()
	Settings.ui_menu = false
	hud.menu_panel.show()
	hud.help_panel.show()
	for pixels in [Vector2(1920, 1080), Vector2(800, 600), Vector2(640, 360)]:
		stage.size = pixels / Settings.ui_factor_for(pixels)
		await _settle()
		_check("4x pause fits %s" % pixels, _inside(hud.menu_panel, stage.get_global_rect()))
		_check("4x controls fit %s" % pixels, _inside(hud.help_panel, stage.get_global_rect()))
		var content := hud.menu_panel.get_child(0).get_child(0)
		var leave: Button = content.get_child(content.get_child_count() - 1)
		leave.grab_focus()
		await _settle()
		_check("pause last action scrolls into view %s" % pixels, _on_screen(leave))
		var help_content := hud.help_panel.get_child(0).get_child(0)
		var last_help: Control = help_content.get_child(help_content.get_child_count() - 1)
		await _reveal(last_help)
		_check("last controls reference scrolls into view %s" % pixels, _on_screen(last_help))
	hud.help_panel.hide()
	hud.stats_panel = StatsPanel.new()
	hud.manual = FieldManual.new()
	hud.settings_panel = SettingsPanel.new()
	hud.log_panel = PanelContainer.new()
	for panel: Control in [hud.stats_panel, hud.manual, hud.settings_panel, hud.log_panel]:
		panel.hide()
	var before := hud.menu_panel.position
	for i in 12:
		hud.toggle_menu()
		hud.toggle_menu()
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_check("repeated pause reopening does not drift", hud.menu_panel.position.distance_to(before) < 0.1)
	UiMotion.arrive(hud.menu_panel, Vector2(0, 1))
	stage.size += Vector2(100, 50)
	await get_tree().create_timer(0.3).timeout
	_check("resize cancels the old pause animation", hud.menu_panel.get_rect().get_center().distance_to(stage.size * 0.5) < 0.1)
	var pause_content := hud.menu_panel.get_child(0).get_child(0)
	(pause_content.get_child(4) as Button).pressed.emit()
	_check("Resume closes the pause dialog", not hud.menu_panel.visible)
	hud.toggle_menu()
	_check("menu shortcut reopens the pause dialog", hud.menu_panel.visible)
	for panel: Control in [hud.stats_panel, hud.manual, hud.settings_panel, hud.log_panel]:
		panel.free()
	var stagger_box := VBoxContainer.new()
	stage.add_child(stagger_box)
	var stagger_row := Label.new()
	stagger_row.text = "Staggered arrival"
	stagger_box.add_child(stagger_row)
	await _settle()
	UiMotion.arrive(stagger_row, Vector2(0, 1), 0.1)
	_check("delayed container arrival hides its first frame", stagger_row.modulate.a == 0.0)
	await _settle()
	await get_tree().create_timer(0.3).timeout
	_check("delayed arrival becomes visible after its delay", stagger_row.modulate.a == 1.0)
	menu.free()
	# Task switching must release battlefield space and preserve the selection.
	hud.orbat = HudOrbat.new()
	hud.minimap = HudMinimap.new()
	hud.minimap_panel = PanelContainer.new()
	hud.layers_ui = HudLayers.new()
	hud.support_box = VBoxContainer.new()
	hud.chat_edit = LineEdit.new()
	hud.tint = ColorRect.new()
	hud._build_workspaces()
	_check("battle keeps map visible with tools closed", not hud.orbat.visible and hud.minimap_panel.visible and not hud.support_box.visible)
	hud.toggle_orbat()
	_check("roster shortcut opens squad search", hud.orbat.visible and hud.squad_search.visible)
	hud.squad_search.text = "Charlie"
	hud.squad_search.text_changed.emit("Charlie")
	_check("typing filters the roster", hud.orbat.query == "charlie")
	hud.orbat.set_query("  medic  ")
	hud.orbat.set_filter("infantry")
	_check("search and category combine", hud.orbat.matches_unit("charlie medic", "infantry", false) and not hud.orbat.matches_unit("medic carrier", "vehicles", false))
	hud.orbat.set_query("")
	hud.orbat.set_filter("attention")
	_check("attention filters healthy units", hud.orbat.matches_unit("charlie", "infantry", true) and not hud.orbat.matches_unit("alpha", "infantry", false))
	hud.orbat.set_filter("all")
	_check("closing drawer preserves the map", hud.drawer_frame.visible and hud.roster_filters.visible)
	hud.drawer_close.pressed.emit()
	_check("drawer close returns to observation", not hud.drawer_frame.visible and hud.minimap_panel.visible)
	_check("normal battle shows only selected plans", hud.show_order_for(true) and not hud.show_order_for(false))
	for viewport_size in [Vector2(1422, 800), Vector2(960, 640)]:
		stage.size = viewport_size
		hud.set_workspace("squads")
		hud._layout_workspace()
		_check("command station fits %s" % viewport_size, _inside(hud.station_frame, stage.get_global_rect()))
		_check("unit drawer fits %s" % viewport_size, _inside(hud.drawer_frame, stage.get_global_rect()))
		_check("drawer clears map %s" % viewport_size, hud.drawer_frame.get_rect().end.y < hud.station_frame.position.y)
		_check("roster stays in drawer %s" % viewport_size, hud.orbat.get_rect().end.y <= hud.drawer_frame.get_rect().end.y)
	hud.set_workspace("battle")
	var compact_map := hud.minimap_side()
	hud.set_workspace("map")
	_check("expanded map is larger", hud.minimap_side() >= compact_map)
	_check("map replaces roster with map controls", hud.minimap_panel.visible and hud.layers_ui.visible and not hud.orbat.visible and not hud.squad_search.visible)
	_check("map reserves space beside selection", hud.minimap_right() > 200.0)
	var previous_orders: bool = Settings.get_v("lyr_orders")
	Settings.v.lyr_orders = true
	_check("tactical workspace reveals army plans", hud.show_order_for(false))
	Settings.v.lyr_orders = false
	_check("orders layer hides unselected plans", not hud.show_order_for(false) and hud.show_order_for(true))
	Settings.v.lyr_orders = previous_orders
	hud.set_workspace("fires")
	_check("support keeps map visible", hud.support_box.visible and hud.minimap_panel.visible and not hud.layers_ui.visible)
	hud.toggle_menu()
	_check("escape returns to battle", hud.workspace == "battle" and not hud.support_box.visible)
	_check("battle reserves persistent map space", hud.minimap_right() > 200.0)
	battle.local_team = -1
	hud._update_support()
	_check("spectators have demo support available", hud._support_btns.size() == Defs.DEMO_SUPPORT.size())
	_check("spectator support is labelled demo", hud._support_btns.values().all(func(button): return (button.get_meta("state") as Label).text == "DEMO"))
	for control: Control in [hud.orbat, hud.minimap, hud.minimap_panel, hud.layers_ui, hud.support_box, hud.chat_edit, hud.tint]:
		control.free()
	hud.free()
	battle.free()


func _screenshots(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	Settings.v.ui_scale = 4.0
	Settings.v.reduce_motion = true
	Settings.set_ui_menu(true)
	var menu := preload("res://scripts/ui/menu.gd").new()
	add_child(menu)
	_players("coop")
	menu._show_lobby()
	await _settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("lobby.png"))
	menu.lobby.hide()
	menu.browser.set_block_signals(true)
	menu.browser.show()
	_populate_browser(menu.browser)
	await _settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join("browser.png"))
