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
	hud.orbat.hud = hud
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
	hud.orbat.set_query("medic charlie")
	_check("search terms match in either order", hud.orbat.matches_unit("Charlie 1 rifle squad medic", "infantry", false))
	hud.orbat.set_query("")
	hud.orbat.set_filter("attention")
	_check("attention filters healthy units", hud.orbat.matches_unit("charlie", "infantry", true) and not hud.orbat.matches_unit("alpha", "infantry", false))
	hud.orbat.set_filter("all")
	_check("closing drawer preserves the map", hud.drawer_frame.visible and hud.roster_filters.visible)
	hud.drawer_close.pressed.emit()
	_check("drawer close returns to observation", not hud.drawer_frame.visible and hud.minimap_panel.visible)
	_check("normal battle shows only selected plans", hud.show_order_for(true) and not hud.show_order_for(false))
	for viewport_size in [Vector2(1422, 800), Vector2(960, 640), Vector2(960, 540)]:
		stage.size = viewport_size
		hud.set_workspace("squads")
		hud._layout_workspace()
		_check("command station fits %s" % viewport_size, _inside(hud.station_frame, stage.get_global_rect()))
		_check("unit drawer fits %s" % viewport_size, _inside(hud.drawer_frame, stage.get_global_rect()))
		_check("drawer clears map %s" % viewport_size, not hud.drawer_frame.get_rect().intersects(hud.station_frame.get_rect()))
		_check("roster stays in drawer %s" % viewport_size, hud.orbat.get_rect().end.y <= hud.drawer_frame.get_rect().end.y)
	# A briefing and command card must not squeeze the workspace into overlap.
	hud.objectives = HudObjectives.new()
	hud.objectives.need_h = 200.0
	hud.card_panel = PanelContainer.new()
	hud.card_panel.position = Vector2(700, 370)
	hud.card_panel.size = Vector2(240, 156)
	hud._layout_workspace()
	_check("short view keeps task above orders", hud.drawer_frame.get_rect().end.y <= hud.card_panel.position.y - 18.0)
	_check("crowded briefing yields to task", hud.objectives.modulate.a == 0.0)
	hud.set_workspace("battle")
	_check("closing task restores briefing", hud.objectives.modulate.a == 1.0)
	hud.objectives.free()
	hud.objectives = null
	hud.card_panel.free()
	hud.card_panel = null
	var compact_map := hud.minimap_side()
	var fixed_map := hud.minimap_panel.get_rect()
	hud.set_workspace("map")
	_check("layers never resize or move the map", hud.minimap_side() == compact_map and hud.minimap_panel.get_rect() == fixed_map)
	_check("map replaces roster with map controls", hud.minimap_panel.visible and hud.layers_ui.visible and not hud.orbat.visible and not hud.squad_search.visible)
	_check("map reserves space beside selection", hud.minimap_right() > 200.0)
	var previous_orders: bool = Settings.get_v("lyr_orders")
	Settings.v.lyr_orders = true
	_check("tactical workspace reveals army plans", hud.show_order_for(false))
	Settings.v.lyr_orders = false
	_check("orders layer hides unselected plans", not hud.show_order_for(false) and hud.show_order_for(true))
	Settings.v.lyr_orders = previous_orders
	hud.set_workspace("fires")
	_check("support keeps map fixed", hud.minimap_panel.get_rect() == fixed_map and hud.support_box.visible and hud.minimap_panel.visible and not hud.layers_ui.visible)
	hud.toggle_menu()
	_check("escape returns to battle", hud.workspace == "battle" and not hud.support_box.visible)
	_check("battle reserves persistent map space", hud.minimap_right() > 200.0)
	battle.local_team = -1
	hud._update_support()
	_check("spectators have demo support available", hud._support_btns.size() == Defs.DEMO_SUPPORT.size())
	_check("spectator support is labelled demo", hud._support_btns.values().all(func(button): return (button.get_meta("state") as Label).text == "DEMO"))
	# The actual roster selection/camera path, with lightweight live entities.
	battle.input = PlayerInput.new()
	battle.input.world = battle
	battle.hud = hud
	battle.cam = RtsCamera.new()
	battle.cam.world = battle
	var troop := Soldier.new()
	troop.sid = 77
	troop.team = 0
	troop.position = Vector3(60, 0, 80)
	battle.soldiers.append(troop)
	hud.set_workspace("squads")
	hud.orbat._pick("sq", 77, true, false, false)
	_check("single click selects without moving the camera", battle.input.sel_squads == [77] and not battle.cam._gliding and hud.workspace == "squads")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	battle.input._key(escape)
	_check("escape closes tools before clearing selection", hud.workspace == "battle" and battle.input.sel_squads == [77])
	hud.set_workspace("squads")
	hud.orbat._entries = [[Rect2(0, 24, HudOrbat.W, 40), "sq", 77, true], [Rect2(0, 800, HudOrbat.W, 40), "sq", 77, true]]
	hud.orbat.move_cursor(1)
	_check("arrow navigation reveals results outside the scroll window", hud.orbat._cursor == 1 and hud.orbat._scroll > 0)
	hud.orbat.activate_cursor()
	_check("enter focuses the unit and restores battlefield control", battle.cam._gliding and battle.cam._g_pos[1] == troop.position and hud.workspace == "battle" and not hud.typing and battle.input.sel_squads == [77])
	hud.set_workspace("fires")
	var demo_key: String = Defs.DEMO_SUPPORT[0]
	(hud._support_btns[demo_key] as Button).pressed.emit()
	_check("choosing support clears the workspace for targeting", battle.input.ability == "demo:" + demo_key and hud.workspace == "battle")
	battle.local_team = 0
	battle.mission_info = {}
	battle.time = 100000.0
	battle.team_info[0] = {"supply": 0, "sup": {}}
	hud._update_support()
	_check("unaffordable support explains why it is unavailable", hud._support_btns.values().all(func(button): return button.disabled and (button.get_meta("state") as Label).text.begins_with("NEED")))
	battle.team_info[0].supply = 999999
	hud._update_support()
	_check("support becomes available when supply arrives", hud._support_btns.values().all(func(button): return not button.disabled))
	battle.soldiers.clear()
	troop.free()
	battle.cam.free()
	battle.cam = null
	battle.input.free()
	battle.input = null
	var marker_overlay := HudOverlay.new()
	marker_overlay.hud = hud
	stage.add_child(marker_overlay)
	marker_overlay._cache_hud_regions()
	var scale_to_overlay := marker_overlay.get_viewport().get_visible_rect().size / stage.size
	_check("world markers yield to the map controls", marker_overlay._under_hud(hud.station_frame.get_rect().get_center() * scale_to_overlay))
	_check("world markers remain in the open battlefield", not marker_overlay._under_hud(Vector2(stage.size.x * 0.7, stage.size.y * 0.5) * scale_to_overlay))
	marker_overlay.free()
	hud.toasts = HudToasts.new()
	hud.toasts.hud = hud
	hud.log_panel = PanelContainer.new()
	hud.log_panel.hide()
	hud.log_box = RichTextLabel.new()
	stage.add_child(hud.log_panel)
	hud.log_panel.add_child(hud.log_box)
	hud._build_events_toggle()
	hud.events_toggle.pressed.emit()
	hud.add_message("info", "Alpha: Contact east")
	_check("minimized events stay hidden and count new arrivals", hud.events_collapsed and not hud.toasts.visible and hud.unread_events == 1)
	_check("minimizing preserves message history", hud.log_box.get_parsed_text().contains("Contact east"))
	hud.events_toggle.pressed.emit()
	_check("expanding events clears unread count", hud.toasts.visible and hud.unread_events == 0)
	hud.toggle_events()
	hud.toggle_log()
	_check("history shortcut reopens minimized event log", hud.log_panel.visible and not hud.events_collapsed and not hud.toasts.visible)
	hud.toggle_events()
	_check("minimize also closes history", not hud.log_panel.visible and hud.events_collapsed)
	hud.toasts.free()
	hud.log_panel.free()
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
