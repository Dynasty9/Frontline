class_name Hud
extends CanvasLayer
## In-game interface. Deliberately quiet: resources top-left, fading toasts
## top-right, a floating minimap, and selection / command panels that only
## appear when something is selected. Zooming in reveals what each soldier is
## doing; hovering one shows a small card. Spectators get an observer bar
## (pause, speed, director camera, whose eyes to watch through).

const MSG_COLORS := {"chat": Color(0.95, 0.95, 0.92), "info": Color(0.62, 0.92, 0.6), "alert": Color(1.0, 0.55, 0.43),
	"warn": Color(1.0, 0.84, 0.45), "intel": Color(0.5, 0.88, 1.0), "system": Color(0.75, 0.76, 0.7), "radio": Color(0.72, 0.84, 0.95),
	"ping": Color(0.7, 0.96, 0.86)}
const BASE_KINDS := ["fob", "barracks", "factory", "medic_tent", "research", "helipad", "tunnel"]
const CAT_COLORS := {"fight": Color(1.0, 0.82, 0.52), "stress": Color(1.0, 0.58, 0.42), "medic": Color(1.0, 0.62, 0.66),
	"hurt": Color(1.0, 0.42, 0.4), "work": Color(0.62, 0.84, 1.0), "move": Color(0.86, 0.9, 0.84), "idle": Color(0.8, 0.8, 0.75)}


## The minimap's backdrop needs baking again (the water has arrived, say).
func refresh_minimap() -> void:
	if minimap:
		minimap.rebake(true)


## The minimap's side in pixels for each size setting, and the panel's margin round it.
const MINIMAP_PX := [200.0, 250.0, 320.0]
const MINIMAP_PAD := 5.0


func minimap_side() -> float:
	var s: float = MINIMAP_PX[clampi(int(Settings.get_v("minimap_size")), 0, MINIMAP_PX.size() - 1)]
	if workspace == "map":
		s = maxf(s, 380.0)
	# a short screen (a big interface scale) keeps room above it for the support buttons
	return minf(s, maxf(160.0, root.size.y * 0.48)) if root and root.size.y > 0.0 else s


## The persistent map sits above its compact tool dock. Expanding the map
## exposes the layer controls; chat remains clear of the complete module.
func layout_minimap() -> void:
	var s := minimap_side()
	var outer := s + MINIMAP_PAD * 2.0
	minimap.custom_minimum_size = Vector2(s, s)
	minimap_panel.offset_left = 14
	minimap_panel.offset_right = 14 + outer
	minimap_panel.offset_bottom = -72
	minimap_panel.offset_top = -72 - outer
	minimap_panel.size = Vector2(outer, outer)
	var lh := HudLayers.S * HudLayers.ITEMS.size() + 4.0 * (HudLayers.ITEMS.size() - 1)
	layers_ui.offset_left = 14 + outer + 6
	layers_ui.offset_right = layers_ui.offset_left + HudLayers.S
	layers_ui.offset_bottom = -72
	layers_ui.offset_top = -72 - lh
	var above := -72 - outer - 38
	if task_bar:
		task_bar.position = Vector2(14, root.size.y - 62)
	if map_caption:
		map_caption.position = Vector2(18, root.size.y - 72 - outer - 23)
	chat_edit.offset_bottom = above
	chat_edit.offset_top = above - 34



## The narrowest the selection panel gets, and an order in the orders grid.
const SEL_MIN_W := 300.0
const CARD_BTN := Vector2(136, 26)


## Where the bottom-left cluster (minimap and layer column) ends on the right.
func minimap_right() -> float:
	return 14 + minimap_side() + MINIMAP_PAD * 2.0 + 6 + HudLayers.S


## How the map is drawn (each toggled from the layer column by the minimap).
const LAYER_KEYS := {"units": "lyr_units", "orders": "lyr_orders", "intel": "lyr_intel", "vision": "lyr_vision", "ranges": "lyr_ranges", "labels": "labels"}
const PHASE_NAMES := {"plan": "Planning", "move": "Moving into position", "fix": "Fixing the enemy", "assault": "Assault", "fallback": "Falling back"}

var world: World
var typing := false
var workspace := "battle"
var task_bar: HBoxContainer
var squad_search: LineEdit
var _task_buttons := {}
var workspace_title: Label
var workspace_hint: Label
var map_caption: Label
var support_scroll: ScrollContainer
var tactical := false
## sid -> [order, where, facing, order number, team, msec the order came in (-1: already standing), attack plan or null]
var orders := {}
var orbat: HudOrbat
var _slow_t := 0.0
var layers_ui: HudLayers
var tint: ColorRect
var root: Control
var top: HudTopInfo
var obs_bar: PanelContainer
var obs_speed: Label
var obs_pause: Button
var obs_dir: Button
var obs_view: Button
var obs_slower: Button
var obs_faster: Button
var _log_head: Label  # the log's header text
var _log_key: Label  # and, after it, the key that closes it
var toasts: HudToasts
var objectives: HudObjectives
var log_panel: PanelContainer
var log_box: RichTextLabel
var chat_edit: LineEdit
var chat_team := false
var card_panel: PanelContainer
var card: GridContainer
var card_title: Label
var _card_key := ""
var _card_page := "main"
var _page_base := ""  # the card a production page was opened on
## Production categories: [label, tooltip].
const PROD_CATS := {
	"inf": ["Infantry", "Squads and teams."],
	"light": ["Light", "MRAPs, scout cars, light strike vehicles, technicals."],
	"armour": ["Armour", "Tanks, infantry fighting vehicles and APCs."],
	"support": ["Fire support", "Self-propelled artillery, rocket launchers, anti-aircraft vehicles."],
	"logistics": ["Logistics", "Trucks: transport, ammunition, repair, medical; engineering vehicles; the UGV."],
	"air": ["Air", "Helicopters and drones."],
}
var sel_panel: PanelContainer
var sel_info: HudSelInfo
var minimap: HudMinimap
var minimap_panel: PanelContainer
var overlay: HudOverlay
var pointer_overlay: HudPointerOverlay
var coop: HudCoop  # the other commanders on our side, over the battlefield
var coop_roster: HudCoopRoster  # ...and listed top right
var alert_label: Label
var _alert_t := 0.0
var over_panel: PanelContainer
var _xp_box: VBoxContainer  # in the report's header: what the battle was worth to the rank
var help_panel: PanelContainer
var veil: TopoBackdrop  # the living map, see-through, behind the menus and the end of the battle
var _veil_wave := -1.0  # seconds since the battle ended (its wave wakes the map from the middle)
var _theme_rev := 0
var menu_panel: PanelContainer
var settings_panel: SettingsPanel
var manual: FieldManual
var stats_panel: StatsPanel  # the battle statistics (hold Tab, or Esc > Battle Statistics)
var aar_panel: StatsPanel  # the after-action report on the end-of-battle screen
var _stats_pinned := false  # opened from the menu (stays until closed), not just peeked at
var account_panel: AccountPanel  # signing in at the end of a battle, to keep it on the record
var _rec_note: Label  # the end screen: whether this battle went on the service record
var _rec_btn: Button
var _over_row: HBoxContainer  # the report's footer: its note and buttons come in last
var _stats_t := 0.0
var support_box: VBoxContainer
var _support_btns := {}  # kind -> Button
var _support_key := "unbuilt"
var _inspect: Entity = null
var _inspect_t := 0.0
var _msgs: Array = []
var _scrims := {}  # edge -> UiScrim: the HUD sits on the scene with no boxes (docs/UI.md, Scrim)
var _fires_open := false  # the fire support list showing every mission, not just the ready ones
var _fires_more: Button  # its last row: how many more are cooling down (click to show them)
var _menu_clock: Label  # the pause dialog's battle clock
var _menu_ctx: Label  # ...and what battle this is


func _input(event: InputEvent) -> void:
	if overlay:
		overlay._input(event)


func _ready() -> void:
	layer = 5
	Online.battle_reported.connect(_on_battle_reported)
	MapSymbols.build_atlas(self, MapSymbols.atlas_k_for(Settings.ui_factor()))
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)

	# the tactical map: the battlefield dims under the symbols
	tint = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.035, 0.04, 0.62)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.visible = false
	root.add_child(tint)

	overlay = HudOverlay.new()
	overlay.hud = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reuse the tactical drawing between updates instead of replaying every stroke.
	var overlay_view := SubViewport.new()
	overlay_view.disable_3d = true
	overlay_view.transparent_bg = true
	overlay_view.gui_disable_input = true
	overlay_view.size = Vector2i(get_viewport().get_visible_rect().size)
	overlay_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(overlay_view)
	overlay.raster = overlay_view
	overlay.theme = root.theme
	overlay_view.add_child(overlay)
	var overlay_image := TextureRect.new()
	overlay_image.texture = overlay_view.get_texture()
	overlay_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay_image)
	pointer_overlay = HudPointerOverlay.new()
	pointer_overlay.hud = self
	pointer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pointer_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pointer_overlay)

	# co-commanders: their views, cursors, selections, plans and pings
	coop = HudCoop.new()
	coop.hud = self
	coop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coop)

	# the edge scrims: the ink fading in from the screen's edges, so the HUD
	# reads over the battlefield without a box round anything
	for e in [["top", 96.0, 0.0], ["left", 400.0, 640.0], ["right", 560.0, 320.0], ["bottom", 250.0, 0.0]]:
		var sc := UiScrim.make(e[0], e[1], e[2])
		_scrims[e[0]] = sc
		root.add_child(sc)

	top = HudTopInfo.new()
	top.hud = self
	top.position = Vector2(14, 12)
	top.size = Vector2(520, 160)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	_build_observer_bar()

	toasts = HudToasts.new()
	toasts.hud = self
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -440
	toasts.offset_right = -14
	toasts.offset_top = 36
	toasts.offset_bottom = 290
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	# a mission's objectives, top right (the notifications move down under them)
	objectives = HudObjectives.new()
	objectives.hud = self
	objectives.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objectives.visible = false
	root.add_child(objectives)

	# the command net: the other commanders on our side, under the objectives
	coop_roster = HudCoopRoster.new()
	coop_roster.hud = self
	coop_roster.size = Vector2(HudCoopRoster.W, 40)
	root.add_child(coop_roster)

	alert_label = Label.new()
	alert_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	alert_label.offset_top = 92
	alert_label.offset_left = -360
	alert_label.offset_right = 360
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_override("font", UiKit.cond(600, 2))
	alert_label.add_theme_font_size_override("font_size", 15)
	alert_label.add_theme_color_override("font_color", UiKit.TEXT)
	alert_label.add_theme_constant_override("outline_size", 5)
	alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	alert_label.uppercase = true
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_label)

	# minimap, bottom-left (sized by the settings: see layout_minimap)
	minimap_panel = PanelContainer.new()
	minimap_panel.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), MINIMAP_PAD))
	minimap_panel.anchor_top = 1.0
	minimap_panel.anchor_bottom = 1.0
	root.add_child(minimap_panel)
	minimap = HudMinimap.new()
	minimap.hud = self
	minimap.prepare_layers()
	minimap_panel.add_child(minimap)

	# map layers: a column of toggles beside the minimap
	layers_ui = HudLayers.new()
	layers_ui.hud = self
	layers_ui.anchor_top = 1.0
	layers_ui.anchor_bottom = 1.0
	root.add_child(layers_ui)

	# order of battle, down the left
	orbat = HudOrbat.new()
	orbat.hud = self
	orbat.position = Vector2(14, 100)
	orbat.size = Vector2(HudOrbat.W, 300)
	root.add_child(orbat)

	# off-map support: one button per power, stacked above the minimap
	support_box = VBoxContainer.new()
	support_box.anchor_top = 1.0
	support_box.anchor_bottom = 1.0
	support_box.offset_left = 14
	support_box.offset_right = 224
	support_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	support_box.add_theme_constant_override("separation", 0)
	root.add_child(support_box)

	chat_edit = LineEdit.new()
	chat_edit.anchor_top = 1.0
	chat_edit.anchor_bottom = 1.0
	chat_edit.offset_left = 14
	chat_edit.offset_right = 430
	chat_edit.visible = false
	var cn := UiKit.underline(UiKit.ACCENT, 8.0, 6.0)
	cn.bg_color = UiKit.PANEL
	chat_edit.add_theme_stylebox_override("normal", cn)
	chat_edit.add_theme_stylebox_override("focus", cn)
	chat_edit.text_submitted.connect(_on_chat)
	chat_edit.focus_exited.connect(func(): _close_chat())
	root.add_child(chat_edit)
	_build_workspaces()
	layout_minimap()
	Settings.changed.connect(layout_minimap)
	_theme_rev = UiKit.theme_rev
	Settings.changed.connect(func():
		if _theme_rev != UiKit.theme_rev:
			_theme_rev = UiKit.theme_rev
			_build_help())  # its headings are in the theme's accent
	root.resized.connect(layout_minimap)  # the window, or the interface scale, changed
	root.resized.connect(func():
		var k := MapSymbols.atlas_k_for(Settings.ui_factor())
		if k != MapSymbols.atlas_k:
			MapSymbols.build_atlas(self, k))

	# selection details, bottom-centre (hidden when nothing is selected)
	sel_panel = PanelContainer.new()
	sel_panel.anchor_left = 0.5
	sel_panel.anchor_right = 0.5
	sel_panel.anchor_top = 1.0
	sel_panel.anchor_bottom = 1.0
	sel_panel.offset_left = -330
	sel_panel.offset_right = 230
	sel_panel.offset_top = -196
	sel_panel.offset_bottom = -14
	sel_panel.add_theme_stylebox_override("panel", UiKit.bare(4.0))
	sel_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sel_panel)
	sel_info = HudSelInfo.new()
	sel_info.hud = self
	sel_info.custom_minimum_size = Vector2(540, 120)
	sel_info.mouse_filter = Control.MOUSE_FILTER_STOP
	sel_panel.add_child(sel_info)

	# command card, bottom-right
	card_panel = PanelContainer.new()
	card_panel.anchor_left = 1.0
	card_panel.anchor_right = 1.0
	card_panel.anchor_top = 1.0
	card_panel.anchor_bottom = 1.0
	card_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card_panel.offset_right = -14
	card_panel.offset_bottom = -14
	card_panel.offset_left = -14
	card_panel.offset_top = -14
	card_panel.add_theme_stylebox_override("panel", UiKit.bare(0.0))
	root.add_child(card_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card_panel.add_child(cv)
	var ch := UiKit.header("Orders")
	card_title = ch.get_node("Text") as Label
	card_title.clip_text = true  # the keys set the card's width, not the title
	card_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(ch)
	card = GridContainer.new()
	card.columns = 3
	card.add_theme_constant_override("h_separation", 12)
	card.add_theme_constant_override("v_separation", 0)
	cv.add_child(card)

	# message history (L): it opens in place of the latest lines, top right,
	# on a lighter ink rather than in a box
	log_panel = PanelContainer.new()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = -440
	log_panel.offset_right = -14
	log_panel.offset_top = 36
	log_panel.offset_bottom = 420
	log_panel.visible = false
	log_panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_SOFT, 0, Color(0, 0, 0, 0), 0, 10.0))
	root.add_child(log_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	log_panel.add_child(lv)
	var lh := UiKit.header("Messages", "-")
	_log_head = lh.get_node("Text") as Label
	_log_key = lh.get_node("Count") as Label
	lv.add_child(lh)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_override("normal_font", UiKit.font(400))
	log_box.add_theme_font_override("mono_font", UiKit.mono(400))
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.add_theme_font_size_override("mono_font_size", 12)
	log_box.add_theme_constant_override("line_separation", 3)
	lv.add_child(log_box)

	veil = TopoBackdrop.new()
	veil.see_through = 0.5
	veil.visible = false
	root.add_child(veil)
	over_panel = _center_panel(Vector2(440, 220))
	help_panel = _center_panel(Vector2(1000, 640))
	menu_panel = _center_panel(Vector2(340, 316))
	_build_help()
	Keys.changed.connect(_keys_changed)
	_build_menu()
	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	root.add_child(settings_panel)
	UiKit.fit_center(settings_panel, Vector2(700, 600))
	stats_panel = StatsPanel.new()
	stats_panel.me_id = world.local_peer
	stats_panel.me_team = world.local_team
	stats_panel.visible = false
	stats_panel.closed.connect(close_stats)
	root.add_child(stats_panel)
	UiKit.fit_center(stats_panel, Vector2(1140, 780), 40.0)
	world.report_updated.connect(_on_report)
	# the field manual sits above everything (F2's hidden HUD included)
	manual = FieldManual.new()
	manual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	manual.offset_left = 40
	manual.offset_right = -40
	manual.offset_top = 36
	manual.offset_bottom = -36
	manual.visible = false
	manual.closed.connect(func(): manual.visible = false)
	add_child(manual)
	var hk := Keys.label("help")
	var how := ("%s for controls, " % hk) if hk != "" else ""
	if String(world.settings.get("mission", "")) != "":
		add_message("system", "Mission started. %sEsc for the menu." % how)
	else:
		add_message("system", "Battle started. You command the %s. %sEsc for the menu." % [Defs.TEAM_NAMES[world.local_team] if world.local_team >= 0 else "camera (observer)", how])
	_keys_changed()


## The map stays in view. Compact tools open one task above it at a time.
func _build_workspaces() -> void:
	task_bar = HBoxContainer.new()
	task_bar.add_theme_constant_override("separation", 2)
	root.add_child(task_bar)
	for item in [["battle", "View"], ["squads", "Squads"], ["map", "Expand"], ["fires", "Support"]]:
		var key: String = item[0]
		var b := preload("res://scripts/ui/hud_task_button.gd").new()
		b.kind = key
		b.caption = item[1]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.tooltip_text = {"battle": "Battlefield view · Close the open tool. The minimap stays visible.", "squads": "Find a squad or vehicle. Click to select and locate; Shift-click adds to selection.", "map": "Expand or collapse the minimap. Click the map to move the camera. Layer controls appear when expanded.", "fires": "Support · Off-map artillery and air strikes. Commanders spend supply; spectators can try a free demo."}[key]
		b.pressed.connect(func(): set_workspace("battle" if workspace == key else key))
		task_bar.add_child(b)
		_task_buttons[key] = b
	workspace_title = UiKit.caps("", 15, UiKit.TEXT)
	workspace_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(workspace_title)
	workspace_hint = UiKit.label("", 12, UiKit.DIM)
	workspace_hint.size = Vector2(320, 40)
	workspace_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(workspace_hint)
	map_caption = UiKit.caps("", 10, UiKit.DIM)
	map_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_caption)
	support_scroll = ScrollContainer.new()
	support_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	support_scroll.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 0, UiKit.LINE, 0, 8.0))
	root.add_child(support_scroll)
	if support_box.get_parent():
		support_box.reparent(support_scroll)
	else:
		support_scroll.add_child(support_box)
	support_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	support_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_search = LineEdit.new()
	squad_search.size = Vector2(HudOrbat.W, 32)
	squad_search.placeholder_text = "Find callsign, role or vehicle…"
	squad_search.clear_button_enabled = true
	var search_ink := UiKit.underline(UiKit.RULE2, 8.0, 6.0)
	search_ink.bg_color = UiKit.PANEL
	squad_search.add_theme_stylebox_override("normal", search_ink)
	squad_search.text_changed.connect(func(value: String): orbat.query = value; orbat.queue_redraw())
	squad_search.focus_entered.connect(func(): typing = true)
	squad_search.focus_exited.connect(func(): typing = false)
	squad_search.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			squad_search.release_focus()
			set_workspace("battle")
			squad_search.accept_event())
	root.add_child(squad_search)
	set_workspace("battle")


func set_workspace(value: String) -> void:
	workspace = value
	orbat.visible = value == "squads"
	orbat.open = true
	squad_search.visible = value == "squads"
	if not squad_search.visible and squad_search.has_focus():
		squad_search.release_focus()
	minimap_panel.visible = true
	layers_ui.visible = value == "map"
	support_box.visible = value == "fires"
	support_scroll.visible = value == "fires"
	layout_minimap()
	for key in _task_buttons:
		(_task_buttons[key] as Button).set_pressed_no_signal(key == value)
		(_task_buttons[key] as Button).queue_redraw()
	# Tactical symbols belong to map observation; returning to another task
	# restores the scene immediately.
	if value != "map" and tactical:
		tactical = false
		tint.visible = false


func _build_observer_bar() -> void:
	obs_bar = PanelContainer.new()
	obs_bar.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 6.0, 0.6, 8.0))
	obs_bar.anchor_left = 0.5
	obs_bar.anchor_right = 0.5
	obs_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	obs_bar.offset_top = 12
	obs_bar.visible = false
	root.add_child(obs_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	obs_bar.add_child(hb)
	var tag := UiKit.caps("Observer", 12, UiKit.ACCENT)
	tag.custom_minimum_size = Vector2(76, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(tag)
	obs_pause = _small_button("Pause", "Pause / resume (P)", func(): world.director.toggle_pause())
	hb.add_child(obs_pause)
	obs_slower = _small_button("-", "Slower", func(): world.director.set_speed_index(world.director.speed_i - 1))
	hb.add_child(obs_slower)
	obs_speed = UiKit.mono_label("1X", 14, UiKit.TEXT)
	obs_speed.custom_minimum_size = Vector2(44, 0)
	obs_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obs_speed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(obs_speed)
	obs_faster = _small_button("+", "Faster", func(): world.director.set_speed_index(world.director.speed_i + 1))
	hb.add_child(obs_faster)
	var s1 := VSeparator.new()
	hb.add_child(s1)
	obs_dir = _small_button("Director", "Cinematic camera that follows the fighting (C)", func(): world.director.active = not world.director.active)
	obs_dir.toggle_mode = true
	hb.add_child(obs_dir)
	obs_view = _small_button("View: Both", "Whose eyes to watch through: both sides, or one side's fog of war (V)", func(): world.director.cycle_view())
	obs_view.custom_minimum_size = Vector2(130, 30)
	hb.add_child(obs_view)


var _obs_place := Vector2(-1, -1)  # (bottom?, slide right) as last laid out
var _obs_low := false


## The observer bar: top centre, slid right if it would cover the balance of
## forces top left. A narrow screen (a big interface scale) has no room for it
## between that and a mission's objectives, so there it goes bottom right
## (nothing else is there for an observer), the fire support list above it.
func _place_obs_bar() -> void:
	var bw := obs_bar.size.x
	var vw := root.size.x
	var x0 := maxf((vw - bw) * 0.5, top.position.x + HudTopInfo.OBS_W + 12.0)
	var right := vw - 14.0 - (HudObjectives.W + 12.0 if objectives.visible else 0.0)
	_obs_low = x0 + bw > right
	var dx := 0.0 if _obs_low else x0 - (vw - bw) * 0.5
	var key := Vector2(1.0 if _obs_low else 0.0, dx)
	if key == _obs_place:
		return
	_obs_place = key
	for p in [obs_bar]:
		var c: Control = p
		c.anchor_left = 1.0 if _obs_low else 0.5
		c.anchor_right = c.anchor_left
		c.anchor_top = 1.0 if _obs_low else 0.0
		c.anchor_bottom = c.anchor_top
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if _obs_low else Control.GROW_DIRECTION_BOTH
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN if _obs_low else Control.GROW_DIRECTION_END
		c.offset_left = -14.0 if _obs_low else dx
		c.offset_right = c.offset_left
	if _obs_low:
		obs_bar.offset_top = -14.0
		obs_bar.offset_bottom = -14.0
	else:
		obs_bar.offset_top = 12.0
		obs_bar.offset_bottom = 12.0


func _small_button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(34 if text.length() <= 1 else 74, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func _center_panel(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.frame_hot(18.0, 0.95))
	p.visible = false
	root.add_child(p)
	UiKit.fit_center(p, sz)
	return p


## A key for the help text, as it's bound now ("unbound" if it isn't).
func _k(id: String, both := false) -> String:
	var s := Keys.label(id, both)
	return "[b]%s[/b]" % (s.replace("[", "[lb]") if s != "" else "unbound")


func _k_pan() -> String:
	return "%s / %s / %s / %s" % [_k("cam_up"), _k("cam_left"), _k("cam_down"), _k("cam_right")]


## The controls (F1), with the keys as they're bound now: rebuilt when they
## change. A key reference (docs/UI.md): [KEY] and what it does, in groups;
## the how-it-works lives in the Field Manual, with a few lines of it here.
func _build_help() -> void:
	for c in help_panel.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	UiKit.scroll_content(help_panel, vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := UiKit.caps("Controls", 12, UiKit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.mono_label("CHANGE ANY KEY: SETTINGS › CONTROLS", 11, UiKit.FAINT))
	var cols := HFlowContainer.new()
	cols.add_theme_constant_override("h_separation", 28)
	cols.add_theme_constant_override("v_separation", 14)
	vb.add_child(cols)
	var groups := [
		[["Camera", [[_kk(["cam_up", "cam_left", "cam_down", "cam_right"]), "Pan (or the screen's edge)"], [_kk(["cam_fast"]), "Pan faster"],
			[_kk(["cam_zoom_in", "cam_zoom_out"]), "Zoom (or the wheel)"], [_kk(["cam_turn_left", "cam_turn_right"]), "Turn"], [_kk(["cam_tilt_up", "cam_tilt_down"]), "Tilt"],
			[["MMB"], "Turn and tilt (Alt: grab)"], [_kk(["cam_reset"]), "Square the view up"], [_kk(["cam_follow"]), "Follow the selection"],
			[_kr("view_save_1", "view_save_4"), "Save a view"], [_kr("view_go_1", "view_go_4"), "Go to a view"], [_kk(["cycle_fob"]), "Cycle your FOBs"], [_kk(["jump_alert"]), "Last alert or ping"]]],
		 ["Command", [[["LMB"], "Select · drag a box"], [["2× LMB"], "Every squad of that type"], [["RMB"], "Move · attack · build · enter"], [["SHIFT+RMB"], "Run there"],
			[["ALT+LMB"], "Command one man"], [_kr("group_set_1", "group_set_9"), "Set a group"], [_kr("group_1", "group_9"), "Recall a group (twice: go there)"],
			[_kk(["tactical"]), "Tactical map (hold: statistics)"], [_kk(["orbat"]), "Order of battle"]]]],
		[["Orders", [[_kk(["attack_move"]), "Attack-move (Ctrl+RMB)"], [_kk(["defend"]), "Defend an area"], [_kk(["hold"]), "Hold"], [_kk(["retreat"]), "Retreat"],
			[_kk(["grenade"]), "Grenade"], [_kk(["smoke"]), "Smoke"], [_kk(["fire_mission"]), "Mortar fire mission"], [_kk(["support"]), "First ready fire support"],
			[_kk(["rotate_build"]), "Rotate a building (Shift+wheel: 45°)"]]],
		 ["Co-commanders", [[["ALT+LMB"] if Keys.label("ping") == "" else _kk(["ping"]), "Ping (hold: the wheel)"], [["ALT+RMB"], "Draw on the map"],
			[_kk(["coop_next"]), "Next commander's view"]]]],
		[["Other", [[_kk(["chat"]), "Chat"], [_kk(["chat_team"]), "Team chat"], [_kk(["log"]), "Message history"], [_kk(["hide_hud"]), "Hide the interface"],
			[_kk(["perf"]), "Performance overlay"], [_kk(["manual"]), "Field Manual"], [_kk(["console"]), "Console (type why)"], [["ESC"], "Menu and settings"]]],
		 ["Observer", [[_kk(["director"]), "Director camera"], [_kk(["view_side"]), "Whose eyes to watch through"], [_kk(["pause"]), "Pause"],
			[_kk(["slower", "faster"]), "Slower · faster"]]]],
	]
	for col in groups:
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.custom_minimum_size.x = 280
		cols.add_child(cv)
		for g in col:
			cv.add_child(UiKit.header(String(g[0])))
			for row in g[1]:
				var keys: Array = row[0]
				if keys.is_empty():
					continue
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 4)
				for k in keys:
					hb.add_child(_key_box(String(k)))
				var l := UiKit.label(String(row[1]), 13, UiKit.DIM)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(6, 0)
				hb.add_child(sp)
				hb.add_child(l)
				cv.add_child(hb)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			cv.add_child(gap)
	vb.add_child(UiKit.header("How it works"))
	for line in ["Cover pips under the cursor: green hard, lime medium, yellow soft, red open. The tick shows where he'll fire from.",
			"Supply runs by truck down each FOB's road. Cut the road and the FOBs beyond it starve.",
			"Towns: men in the ring with none of theirs take it. It fills its dump and trucks it to your nearest FOB.",
			"Minimap: click to look, right-click to send the selection. The wedge is your view; orange rings are firefights.",
			"Win: take or destroy every enemy FOB. The Field Manual (%s) has the rest." % (Keys.label("manual") if Keys.label("manual") != "" else "Esc › Field manual")]:
		var l2 := UiKit.label(line, 13, UiKit.DIM)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l2)


## The keys bound to these actions ("" ones left out).
func _kk(ids: Array) -> Array:
	var out := []
	for id in ids:
		var k := Keys.label(String(id))
		if k != "":
			out.append(k.to_upper())
	return out


## A run of numbered keys as one, "F5–F8".
func _kr(first: String, last: String) -> Array:
	var a := Keys.label(first)
	var b := Keys.label(last)
	if a == "" or b == "":
		return _kk([first, last])
	return ["%s–%s" % [a.to_upper(), b.to_upper()]]


## A key in its box, for the key reference.
static func _key_box(k: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.RULE2, 1, 0.0)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UiKit.mono_label(k, 11, UiKit.TEXT))
	return p


## Everything on screen that names a key, again after a key has been changed.
func _keys_changed() -> void:
	_build_help()
	_card_key = ""
	_support_key = ""
	if obs_pause:
		obs_pause.tooltip_text = "Pause / resume%s" % _kt("pause")
		obs_slower.tooltip_text = "Slower%s" % _kt("slower")
		obs_faster.tooltip_text = "Faster%s" % _kt("faster")
		obs_dir.tooltip_text = "Cinematic camera that follows the fighting%s" % _kt("director")
		obs_view.tooltip_text = "Whose eyes to watch through: both sides, or one side's fog of war%s" % _kt("view_side")
	_log_head.text = "Messages"
	_log_key.text = ("%s CLOSES" % Keys.label("log").to_upper()) if Keys.label("log") != "" else ""


## " (key)" for a tooltip, or "" when nothing is bound.
func _kt(id: String) -> String:
	var s := Keys.label(id)
	return ("  (%s)" % s) if s != "" else ""


func _build_menu() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	UiKit.scroll_content(menu_panel, vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := UiKit.caps("Paused" if world.director and world.director.can_control_time() else "Menu", 12, UiKit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_menu_clock = UiKit.mono_label("", 12, UiKit.DIM)
	head.add_child(_menu_clock)
	_menu_ctx = UiKit.mono_label("", 12, UiKit.FAINT)
	_menu_ctx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_menu_ctx)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	vb.add_child(gap)
	var top_rule := ColorRect.new()
	top_rule.color = UiKit.LINE
	top_rule.custom_minimum_size = Vector2(0, 1)
	vb.add_child(top_rule)
	for it in [["Resume", "Esc", func(): menu_panel.visible = false, false],
			["Battle statistics", Keys.label("tactical"), func(): menu_panel.visible = false; open_stats(), false],
			["Settings", "", func(): menu_panel.visible = false; settings_panel.visible = true, false],
			["Field manual", Keys.label("manual"), func(): menu_panel.visible = false; manual.visible = true, false],
			["Controls", Keys.label("help"), func(): menu_panel.visible = false; toggle_help(), false],
			["Leave battle", "", _leave, true]]:
		vb.add_child(list_item(String(it[0]), String(it[1]), it[2], bool(it[3])))


## The pause dialog's context: the battle's clock and what battle it is.
func _menu_context() -> void:
	if _menu_clock == null:
		return
	_menu_clock.text = "T+%02d:%02d" % [int(world.time / 60.0), int(world.time) % 60]
	var what: String = String(world.mission_info.get("op", world.mission_info.get("title", ""))) if not world.mission_info.is_empty() else "Battle"
	var side: String = Defs.TEAM_NAMES[world.local_team] if world.local_team >= 0 else "Observer"
	_menu_ctx.text = ("%s · %s" % [what, side]).to_upper()


## A line of a dialog's list (docs/UI.md, Dialog): capitals on a rule; under
## the cursor it fills with the accent. `key` shows at its end; `danger` is in red.
static func list_item(text: String, key: String, cb: Callable, danger := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_ALL
	var n := UiKit.box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0.0)
	n.border_color = UiKit.LINE
	n.border_width_bottom = 1
	n.content_margin_left = 10
	var h := UiKit.box(UiKit.ACCENT, 0, UiKit.ACCENT, 0, 0.0)
	h.content_margin_left = 10
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, n)
	for st in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, h)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var l := UiKit.caps(text, 14, UiKit.BAD if danger else UiKit.TEXT, 600, 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var k: Label = null
	if key != "":
		k = UiKit.mono_label(key.to_upper(), 11, UiKit.FAINT)
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(k)
	var lit := func(on: bool) -> void:
		l.add_theme_color_override("font_color", UiKit.ON_ACCENT if on else (UiKit.BAD if danger else UiKit.TEXT))
		if k:
			k.add_theme_color_override("font_color", UiKit.ON_ACCENT if on else UiKit.FAINT)
	b.mouse_entered.connect(lit.bind(true))
	b.mouse_exited.connect(lit.bind(false))
	b.focus_entered.connect(lit.bind(true))
	b.focus_exited.connect(lit.bind(false))
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func _leave() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("return_to_menu"):
		main.return_to_menu("")


func toggle_manual() -> void:
	manual.visible = not manual.visible


func toggle_menu() -> void:
	if workspace != "battle":
		set_workspace("battle")
		return
	if stats_panel.visible:
		close_stats()
		return
	if manual.visible:
		manual.visible = false
		return
	if settings_panel.visible:
		settings_panel.visible = false
		return
	if help_panel.visible:
		help_panel.visible = false
		return
	if log_panel.visible:
		toggle_log()
		return
	menu_panel.visible = not menu_panel.visible
	if menu_panel.visible:
		_menu_context()
		UiMotion.arrive(menu_panel, Vector2(0, 1))


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


# --- map layers & the tactical map -------------------------------------------------------

func map_layer(key: String) -> bool:
	if tactical and key in ["units", "orders", "intel"]:
		return true
	return bool(Settings.get_v(LAYER_KEYS[key]))


func set_map_layer(key: String, on: bool) -> void:
	Settings.v[LAYER_KEYS[key]] = on
	layers_ui.queue_redraw()
	Sfx.ui("click")
	flash("%s %s" % [{"units": "Unit symbols", "orders": "Orders", "intel": "Intelligence", "vision": "Fog of war", "ranges": "Weapon ranges", "labels": "Soldier labels"}[key], "on" if on else "off"])


func toggle_tactical() -> void:
	tactical = not tactical
	tint.visible = tactical
	if tactical:
		set_workspace("map")
	layers_ui.queue_redraw()
	Sfx.ui("click")


func toggle_orbat() -> void:
	set_workspace("battle" if workspace == "squads" else "squads")


## Tracks every squad's orders from the team summary; a new order number means
## the commander (you or the AI) has just sent that squad something.
func _track_orders() -> void:
	var now := Time.get_ticks_msec()
	var seen := {}
	for t in mini(2, world.team_info.size()):
		var sq: Dictionary = (world.team_info[t] as Dictionary).get("sq", {})
		for sid in sq:
			var o: Array = sq[sid]
			var id := int(sid)
			seen[id] = true
			var prev: Array = orders.get(id, [])
			var came := -1
			if not prev.is_empty():
				came = int(prev[5])
				if int(prev[3]) != int(o[3]):
					came = now
			orders[id] = [String(o[0]), o[1], o[2], int(o[3]), t, came, o[4] if o.size() > 4 else null, int(o[5]) if o.size() > 5 else -1, String(o[6]) if o.size() > 6 else ""]
	for id in orders.keys():
		if not seen.has(id):
			orders.erase(id)


## What a squad is doing, in a few words, for the order of battle and the
## squad card: {text, code, col, glyph, contact, pinned, wounded, low_ammo}.
## `code` is the same said the Signal way (docs/UI.md, Voice): MOV D8,
## PINNED · DEF E4.
func squad_state(sid: int, mem: Array) -> Dictionary:
	var out := {"text": "Holding", "code": "HOLD", "col": UiKit.DIM, "glyph": "", "contact": false, "pinned": false, "wounded": 0, "low_ammo": false, "morale": -1, "mstate": 0}
	var alive := 0
	var pinned := 0
	var low := 0
	var riding := false
	for s in mem:
		if s.life == Soldier.Life.DOWNED:
			out.wounded += 1
		if s.life != Soldier.Life.ALIVE and s.life != Soldier.Life.HIDDEN:
			continue
		alive += 1
		if s.riding != null:
			riding = true
		if (s.flags & Soldier.F_SHOOTING) != 0:
			out.contact = true
		if (s.flags & Soldier.F_PINNED) != 0:
			pinned += 1
		if (s.flags & (Soldier.F_LOWAMMO | Soldier.F_NOAMMO)) != 0:
			low += 1
	out.pinned = alive > 0 and pinned * 2 >= alive
	out.low_ammo = alive > 0 and low * 2 >= alive
	var o: Array = orders.get(sid, [])
	if not o.is_empty():
		var g := Defs.grid_ref(o[1])
		out.code = {"move": "MOV ", "bound": "BOUND ", "ambush": "AMBUSH ", "assault": "ATK ", "defend": "DEF ", "build": "BUILD "}.get(String(o[0]), "") + g
		out.code = {"retreat": "FALL BACK", "attack": "ENGAGE", "tunnel": "TUNNELS", "contact": "CONTACT", "displace": "DISPLACE", "rout": "ROUTING"}.get(String(o[0]), out.code)
		match String(o[0]):
			"move":
				out.text = "Moving to " + g
				out.glyph = "move"
				out.col = UiKit.TEXT
			"bound":
				out.text = "Bounding to " + g
				out.glyph = "move"
				out.col = UiKit.TEXT
			"ambush":
				out.text = "Ambush at " + g
				out.glyph = "defend"
				out.col = MapSymbols.ORDER_COLORS["defend"]
			"assault":
				out.text = "Attacking " + g
				out.glyph = "assault"
				out.col = MapSymbols.ORDER_COLORS["assault"]
			"defend":
				out.text = "Defending " + g
				out.glyph = "defend"
				out.col = MapSymbols.ORDER_COLORS["defend"]
			"retreat":
				out.text = "Falling back"
				out.glyph = "retreat"
				out.col = MapSymbols.ORDER_COLORS["retreat"]
			"attack":
				out.text = "Engaging target"
				out.glyph = "fire"
				out.col = MapSymbols.ORDER_COLORS["attack"]
			"build":
				out.text = "Building at " + g
				out.glyph = "build"
				out.col = MapSymbols.ORDER_COLORS["build"]
			"tunnel":
				out.text = "In the tunnels"
				out.glyph = "tunnel"
			"contact":
				out.text = "Contact! Returning fire"
				out.glyph = "fire"
				out.col = Color(1.0, 0.72, 0.42)
			"displace":
				out.text = "Moving out of the shellfire"
				out.glyph = "move"
				out.col = Color(1.0, 0.72, 0.42)
			"rout":
				out.text = "ROUTING"
				out.glyph = "retreat"
				out.col = UiKit.BAD
		if String(o[8]) == "withdraw":
			out.text = "Breaking contact"
			out.code = "BREAK CONTACT"
		var pl = o[6]
		if pl != null:
			out.text = plan_text(pl)
			out.code = plan_code(pl)
		out.morale = int(o[7])
		out.mstate = SquadBrain.state(float(o[7]), String(o[8]) == "rout") if int(o[7]) >= 0 else 0
	if riding:
		out.text = "Mounted  ·  " + out.text
		out.code = "MOUNTED · " + out.code
	if out.pinned:
		out.text = "PINNED  ·  " + out.text
		out.code = "PINNED · " + out.code
		out.col = UiKit.WARN
	elif out.contact and not String(out.text).begins_with("Attacking"):
		out.text = "In contact  ·  " + out.text
		if not String(out.code).begins_with("CONTACT"):
			out.code = "CONTACT · " + out.code
		out.col = Color(1.0, 0.72, 0.42)
	return out


## A squad's part in an attack plan, as a code.
func plan_code(pl: Array) -> String:
	var role := String(pl[5]) if pl.size() > 5 else "assault"
	var obj := Defs.grid_ref(pl[1])
	match String(pl[0]):
		"plan":
			return "PLAN " + obj
		"move":
			return ("TO SPT " if role == "support" else "TO ASLT ") + obj
		"fix":
			return "FIX %s · NEED SPT" % obj
		"assault":
			return ("FIRE ON " + obj) if role == "support" else ("ASSAULT " + obj)
		"fallback":
			return "REGROUP " + obj
	return "ATK " + obj


## One line for a squad's part in an attack plan.
func plan_text(pl: Array) -> String:
	var phase := String(pl[0])
	var role := String(pl[5]) if pl.size() > 5 else "assault"
	var obj := Defs.grid_ref(pl[1])
	match phase:
		"plan":
			return "Planning the attack on " + obj
		"move":
			return ("Moving to support position" if role == "support" else "Moving to assault position") + " · " + obj
		"fix":
			return "Fixing the enemy at %s, needs support" % obj
		"assault":
			return ("Base of fire on " + obj) if role == "support" else ("Assaulting " + obj)
		"fallback":
			return "Falling back to regroup · " + obj
	return "Attacking " + obj


func toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	toasts.visible = not log_panel.visible
	if log_panel.visible:
		_fit_log()
		UiMotion.arrive(log_panel, Vector2(0, -1))


## The history takes the latest lines' place while it's open, as tall as what
## it holds (a box round one line says nothing), up to the space above the orders.
func _fit_log() -> void:
	toasts.visible = false
	var h := clampf(log_box.get_content_height(), 18.0, 330.0)
	log_panel.offset_bottom = log_panel.offset_top + h + 52.0


func flash(text: String) -> void:
	alert_label.text = text
	_alert_t = 3.0


func inspect(e: Entity) -> void:
	_inspect = e
	_inspect_t = 4.0


## A line in the message log (L), and (`toast`) a notification top right.
func add_message(kind: String, text: String, toast := true) -> void:
	var col: Color = MSG_COLORS.get(kind, Color.WHITE)
	var mins := int(world.time / 60.0)
	var secs := int(world.time) % 60
	var clean := text.replace("[", "(").replace("]", ")") if kind == "chat" else text
	var line := "[color=#%s][code]%02d:%02d[/code][/color]  [color=#%s]%s[/color]" % [UiKit.FAINT.to_html(false), mins, secs, col.to_html(false), clean]
	_msgs.append(line)
	if _msgs.size() > 120:
		_msgs.pop_front()
	log_box.append_text(line + "\n")
	if toast:
		toasts.push(kind, text)
	if kind == "alert":
		Sfx.ui("click")


func open_chat(team_only: bool) -> void:
	chat_team = team_only
	chat_edit.visible = true
	chat_edit.placeholder_text = "Team chat..." if team_only else "Chat to everyone..."
	chat_edit.grab_focus()
	typing = true


func _close_chat() -> void:
	chat_edit.visible = false
	chat_edit.text = ""
	typing = false


func _on_chat(text: String) -> void:
	if text.strip_edges() != "":
		world.send_cmd({"t": "chat", "text": text, "team_only": chat_team})
	_close_chat()


## The living map fades in, see-through, under the Esc menu, the help and the
## settings, and under the end of the battle, where a wave from the middle of
## the screen wakes it.
func _update_veil(rdt: float) -> void:
	var on := menu_panel.visible or help_panel.visible or settings_panel.visible or over_panel.visible
	veil.modulate.a = move_toward(veil.modulate.a, 1.0 if on else 0.0, rdt * 4.0)
	veil.visible = veil.modulate.a > 0.0
	if _veil_wave >= 0.0 and over_panel.visible:
		_veil_wave += rdt
		veil.wake_t = _veil_wave - 0.15
	else:
		_veil_wave = -1.0
		veil.wake_t = 1000.0


## The end of the battle: who won, and the after-action report - the whole
## battle's figures, both sides', in the stats tabs.
func show_game_over(w: int) -> void:
	close_stats()
	_veil_wave = 0.0
	veil.wake_at = Vector2(0.5, 0.5)
	for c in over_panel.get_children():
		c.queue_free()
	UiKit.fit_center(over_panel, Vector2(1180, 840), 30.0)
	# the report sits on the same glass as the statistics
	var glass := StyleBoxEmpty.new()
	glass.set_content_margin_all(26.0)
	glass.content_margin_top = 22.0
	over_panel.add_theme_stylebox_override("panel", glass)
	if not over_panel.draw.is_connected(_draw_over):
		over_panel.draw.connect(_draw_over)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	over_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var facts := ""
	if not world.mission_info.is_empty():
		facts = _mission_head(hv)
	else:
		hv.add_child(UiKit.caps("After-action report", 11, UiKit.FAINT, 600, 2))
		var t := UiKit.caps("", 34, UiKit.TEXT, 600, 4)
		if world.local_team < 0:
			t.text = "%s WIN" % Defs.TEAM_NAMES[w].to_upper()
			t.add_theme_color_override("font_color", Defs.TEAM_COLORS[w].lightened(0.3))
		elif w == world.local_team:
			t.text = "VICTORY"
			t.add_theme_color_override("font_color", UiKit.GOOD)
		else:
			t.text = "DEFEAT"
			t.add_theme_color_override("font_color", UiKit.BAD)
		hv.add_child(t)
		hv.add_child(UiKit.label("%s have taken the battlefield." % Defs.TEAM_NAMES[w], 14, UiKit.DIM))
		facts = "T+%s" % UiKit.fmt_time(world.time)
		Music.sting("defeat" if world.local_team >= 0 and w != world.local_team else "victory")
	if world.local_team >= 0 and Online.signed_in():
		_xp_row(head)
	var fl := UiKit.mono_label(facts, 12, UiKit.DIM)
	fl.size_flags_vertical = Control.SIZE_SHRINK_END
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(fl)
	aar_panel = StatsPanel.new()
	aar_panel.embedded = true
	aar_panel.me_id = world.local_peer
	aar_panel.me_team = world.local_team
	aar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(aar_panel)
	aar_panel.set_report(world.report)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	# the service record: saved, or sign in to keep it
	_rec_note = UiKit.label("", 13, UiKit.FAINT)
	_rec_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rec_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# a width to wrap at from the start: laid out while the report is still
	# hidden, a wrapping label with none breaks at every letter and stretches it
	_rec_note.custom_minimum_size = Vector2(380, 0)
	row.add_child(_rec_note)
	_rec_btn = _cta("Sign in", false, _sign_in_for_record)
	_rec_btn.custom_minimum_size = Vector2(130, 42)
	row.add_child(_rec_btn)
	if not Online.record_changed.is_connected(_update_record_note):
		Online.record_changed.connect(_update_record_note)
	_update_record_note()
	if not world.mission_info.is_empty() and multiplayer.is_server():
		row.add_child(_cta("Play Again" if int(world.mission_info.get("over", 0)) == 1 else "Try Again", false, func(): over_panel.visible = false; Net.start_game()))
	row.add_child(_cta("Return to Menu", true, _leave))
	_over_row = row
	_end_sequence(w)


## The report's buttons: the one to press next is the primary (docs/UI.md).
func _cta(text: String, primary: bool, cb: Callable) -> Button:
	var b := UiKit.button(text, "primary" if primary else "secondary", 190, 40)
	b.mouse_entered.connect(func(): Sfx.ui("ui_tick", -26.0, 1.4))
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func _spaced_label(text: String, fs: int, col: Color, spacing: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiFx.spaced(700, spacing))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _draw_over() -> void:
	UiFx.panel(over_panel, Rect2(Vector2.ZERO, over_panel.size), 1.0)


## The end of the battle as a moment: the battlefield greys out behind a
## banner with the result (and the player's rating filling its bar), then the
## after-action report rises into its place (EndBanner).
func _end_sequence(w: int) -> void:
	var won := world.local_team < 0 or w == world.local_team
	var ban := EndBanner.new()
	ban.world = world
	if not world.mission_info.is_empty():
		var ok := int(world.mission_info.get("over", 0)) == 1
		won = ok
		ban.headline = "MISSION ACCOMPLISHED" if ok else "MISSION FAILED"
		ban.sub = String(world.mission_info.get("op", ""))
	elif world.local_team < 0:
		ban.headline = "%s WIN" % String(Defs.TEAM_NAMES[w]).to_upper()
		ban.sub = "Battle lasted %s" % UiKit.fmt_time(world.time)
	else:
		ban.headline = "VICTORY" if won else "DEFEAT"
		ban.sub = "%s have taken the battlefield" % Defs.TEAM_NAMES[w]
	ban.won = won
	ban.accent = (Defs.TEAM_COLORS[w] as Color).lightened(0.25) if world.local_team < 0 and world.mission_info.is_empty() else (UiKit.GOOD if won else UiKit.BAD)
	# the player's own rating, if they fought
	var r: Dictionary = world.report
	if world.local_team >= 0 and not r.is_empty():
		for c in r.get("players", []):
			if int(c.id) == world.local_peer:
				var rv := BattleStats.rating(c, (r.sides as Array)[world.local_team])
				ban.rating = rv
				ban.rating_word = UiKit.rating_word(rv)
	var old := root.get_node_or_null("OverGrade")
	if old:
		old.queue_free()
	var grade := EndBanner.make_grade(won)
	root.add_child(grade)
	root.move_child(grade, over_panel.get_index())
	ban.grade = grade
	root.add_child(ban)
	over_panel.visible = false
	ban.finished.connect(_reveal_report)


## The report rises into place under where the banner was.
func _reveal_report() -> void:
	over_panel.visible = true
	UiKit.fit_center(over_panel, Vector2(1180, 840), 30.0)
	over_panel.modulate.a = 0.0
	var y := over_panel.position.y
	over_panel.position.y = y + 56.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	tw.tween_property(over_panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(over_panel, "position:y", y, 0.55)
	Sfx.ui("ui_whoosh", -12.0, 0.85)
	if _over_row and is_instance_valid(_over_row):
		UiFx.slide_in(_over_row, 0.0, 0.4, 1.1)


## Under the after-action report: whether this battle went on the player's
## service record, and if they're signed out, a way to sign in and keep it.
func _update_record_note() -> void:
	if _rec_note == null or not is_instance_valid(_rec_note):
		return
	var st := String(Online.last_record.get("state", ""))
	_rec_btn.visible = false
	_rec_note.add_theme_color_override("font_color", UiKit.DIM)
	match st:
		"saving":
			_rec_note.text = "Saving this battle to your service record..."
		"saved":
			_rec_note.text = "This battle is on your service record (main menu > Service Record)."
			_rec_note.add_theme_color_override("font_color", UiKit.GOOD)
		"waiting":
			if Online.signed_in():
				_rec_note.text = "Couldn't reach the matchmaker: this battle goes on your service record next time it can."
				_rec_note.add_theme_color_override("font_color", UiKit.WARN)
			else:
				_rec_note.text = "Sign in to keep this battle, and every one after it, on a service record, and to earn ranks and insignia."
				_rec_btn.visible = true
		_:
			_rec_note.text = ""


func _sign_in_for_record() -> void:
	if account_panel == null:
		account_panel = AccountPanel.new()
		root.add_child(account_panel)
		UiKit.fit_center(account_panel, AccountPanel.SIZE)
	account_panel.open(false, Net.my_name)


## The rank's corner of the report's header. It waits for the matchmaker to
## say what the battle was worth (Online.battle_reported): the XP, how far
## through the rank, and a promotion with the patch that comes with it.
func _xp_row(parent: Control) -> void:
	_xp_box = VBoxContainer.new()
	_xp_box.add_theme_constant_override("separation", 4)
	_xp_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_box.custom_minimum_size = Vector2(320, 0)
	parent.add_child(_xp_box)
	_xp_box.add_child(UiKit.label("Counting your XP...", 13, UiKit.DIM))


func _on_battle_reported(rep: Dictionary) -> void:
	if not is_instance_valid(_xp_box):
		return
	for c in _xp_box.get_children():
		c.queue_free()
	if rep.has("error"):
		var e := UiKit.label("Couldn't count this battle towards your rank: %s" % String(rep.error), 13, UiKit.BAD)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(320, 0)
		_xp_box.add_child(e)
		return
	var gained: int = int(rep.get("gained", 0))
	var before: int = int(rep.get("rank_before", Online.rank))
	var promoted: bool = Online.rank > before
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_xp_box.add_child(row)
	# promoted: the new rank's patch is theirs to wear
	var id: String = ("r%02d" % Online.rank) if promoted else Online.icon
	var pic := TextureRect.new()
	pic.texture = Insignia.texture(id, 128)
	pic.custom_minimum_size = Vector2(52, 52)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var rname := Insignia.rank_name(Online.rank).to_upper()
	v.add_child(_spaced_label(("PROMOTED: " + rname) if promoted else rname, 12, UiKit.GOOD if promoted else UiKit.ACCENT, 2))
	var nxt := ("%s / %s XP" % [Insignia.thousands(Online.xp - Online.rank_xp), Insignia.thousands(Online.next_xp - Online.rank_xp)]) if Online.next_xp > 0 else "Top rank"
	v.add_child(UiKit.label(("+%d XP  \u00b7  %s" % [gained, nxt]) if gained > 0 else "No XP: battles under two minutes don't count", 14, UiKit.TEXT, 600))
	if promoted:
		var more: int = Online.rank - before - 1
		v.add_child(UiKit.label("New insignia: %s%s" % [String(Insignia.find(id).get("n", "")), (" and %d more" % more) if more > 0 else ""], 12, UiKit.DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 4)
	bar.max_value = maxf(1.0, Online.next_xp - Online.rank_xp) if Online.next_xp > 0 else 1.0
	bar.value = (Online.xp - Online.rank_xp) if Online.next_xp > 0 else 1.0
	bar.add_theme_stylebox_override("background", UiKit.box(Color(1, 1, 1, 0.08), 2, Color(0, 0, 0, 0), 0, 0.0))
	bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.ACCENT, 2, Color(0, 0, 0, 0), 0, 0.0))
	_xp_box.add_child(bar)


## The end of a mission: accomplished or failed and why, the headline of the
## after-action report. Returns what it cost, in a line.
func _mission_head(vb: VBoxContainer) -> String:
	var info: Dictionary = world.mission_info
	var ok := int(info.get("over", 0)) == 1
	Music.sting("victory" if ok else "defeat")
	vb.add_child(UiKit.caps(String(info.get("op", "")), 11, UiKit.FAINT, 600, 2))
	vb.add_child(UiKit.caps("Mission accomplished" if ok else "Mission failed", 30, UiKit.GOOD if ok else UiKit.BAD, 600, 4))
	var s := UiKit.label(String(info.get("end", "")), 14, UiKit.TEXT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(420, 0)
	vb.add_child(s)
	var done := 0
	var all := 0
	for o in info.get("objs", []):
		if bool(o[7]):
			continue
		all += 1
		if int(o[2]) == MissionDirector.DONE:
			done += 1
	var el := float(info.get("el", 0.0))
	var lost: Array = info.get("lost", [0, 0])
	return "T+%s · OBJECTIVES %d/%d · LOST %d/%d · KILLED %d" % [UiKit.fmt_time(el), done, all, int(lost[0]), int(lost[1]), int(info.get("kills", 0))]


# --- battle statistics -------------------------------------------------------------------

## Opens the battle statistics and keeps them open (Esc > Battle Statistics).
func open_stats(tab := "") -> void:
	if world.winner >= 0:
		return
	_stats_pinned = true
	_show_stats(tab)


## Holding Tab: shows them until it's let go (unless they were opened from the menu).
func peek_stats(on: bool) -> void:
	if world.winner >= 0 or _stats_pinned:
		return
	if on:
		_show_stats("")
	else:
		stats_panel.pop_out()


func close_stats() -> void:
	_stats_pinned = false
	stats_panel.pop_out()


func _show_stats(tab: String) -> void:
	stats_panel.peek = not _stats_pinned
	if tab != "":
		stats_panel.show_tab(tab)
	stats_panel.set_report(world.report)
	stats_panel.pop_in()
	if _stats_pinned:
		Sfx.ui("ui_whoosh", -16.0)
	_stats_t = 0.0
	world.request_report()


func _on_report() -> void:
	if stats_panel.visible:
		stats_panel.set_report(world.report)
	if aar_panel != null and is_instance_valid(aar_panel):
		aar_panel.set_report(world.report)


# --- per frame -------------------------------------------------------------------------

func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("hud", _t0)


func _view_process(dt: float) -> void:
	var rdt := dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.001 else 0.016
	_alert_t -= rdt
	alert_label.modulate.a = clampf(_alert_t * 1.5, 0.0, 1.0)
	_inspect_t -= rdt
	if log_panel.visible:
		_fit_log()
	var spectator := world.local_team < 0
	obs_bar.visible = spectator and world.director != null and not world.settings.get("replay", false)
	if obs_bar.visible:
		var d := world.director
		var spd: float = d.speed()
		obs_speed.text = "PAUSED" if spd <= 0.0 else ("%sX" % (str(spd) if spd < 1.0 else str(int(spd))))
		obs_pause.text = "PLAY" if spd <= 0.0 else "PAUSE"
		obs_pause.disabled = not d.can_control_time()
		obs_dir.set_pressed_no_signal(d.active)
		obs_view.text = "VIEW: " + (["Both sides", Defs.TEAM_NAMES[0], Defs.TEAM_NAMES[1]][world.view_team + 1]).to_upper()
		_place_obs_bar()
	_track_orders()
	_update_support()
	_update_card()
	_update_veil(rdt)
	# the battle statistics stay current while they're up
	if stats_panel.visible:
		_stats_t += rdt
		if _stats_t >= 2.0:
			_stats_t = 0.0
			world.request_report()
	var task_y := maxf(96.0, top.position.y + top.content_h + 8.0)
	workspace_title.position = Vector2(18, task_y)
	workspace_hint.position = Vector2(18, task_y + 26)
	var context := "OBSERVER" if spectator else "COMMAND"
	var title: String = {"battle": "BATTLEFIELD", "squads": "FIND A UNIT", "map": "TACTICAL OVERVIEW", "fires": "SUPPORT DEMO" if spectator else "SUPPORT"}[workspace]
	workspace_title.text = context + " / " + title
	var hint := "Click the map to look around. Select a unit to inspect it." if spectator else "Click a squad to select. Right-click terrain to move."
	if workspace == "squads":
		hint = "Search, then click to locate. Double-click to zoom in." if spectator else "Search, then click to select and locate. Shift-click adds units."
	elif workspace == "map":
		hint = "Click the map to move the camera. Use the icons beside it to filter layers."
	elif workspace == "fires":
		hint = "Free spectator demo: choose artillery or air support, then click a target." if spectator else "Off-map artillery and air strikes. Choose support, then click a target."
	workspace_hint.text = hint
	map_caption.text = context + " / " + ("TACTICAL MAP" if workspace == "map" else "SECTOR MAP")
	squad_search.position = Vector2(14, task_y + 72.0)
	orbat.position = Vector2(14, task_y + 114.0)
	var limit := minimap_panel.position.y - 42.0
	orbat.size = Vector2(HudOrbat.W, maxf(50.0, limit - orbat.position.y))
	support_scroll.position = Vector2(14, task_y + 76.0)
	support_scroll.size = Vector2(HudOrbat.W, maxf(50.0, limit - support_scroll.position.y))
	var left_scrim: UiScrim = _scrims["left"]
	left_scrim.visible = true
	# on a narrow screen (a big interface scale) the command card gives up
	# columns before the selection panel beside it is squeezed
	var room := root.size.x - minimap_right() - 10.0 - SEL_MIN_W - 12.0 - 14.0
	var cols := clampi(int((room - 15.0) / (CARD_BTN.x + 12.0)), 2, 3)
	if card.columns != cols:
		card.columns = cols
	var has_sel := world.input != null and (world.input.has_units() or world.input.sel_structure != 0 or (_inspect_t > 0.0 and _inspect != null and not _inspect.gone))
	sel_panel.visible = has_sel
	_slow_t -= rdt
	var slow := _slow_t <= 0.0
	if slow:
		_slow_t = 0.1
	if has_sel and slow:
		sel_info.queue_redraw()
		sel_info.custom_minimum_size.y = sel_info.need_h
		# (above the observer bar when that's down here)
		var sb := 14.0 + (obs_bar.size.y + 8.0 if obs_bar.visible and _obs_low else 0.0)
		sel_panel.offset_bottom = -sb
		sel_panel.offset_top = -sb - sel_info.need_h - 22.0
		# fit between the minimap and the command card, centred in the free space
		var vw := root.size.x
		var left := minimap_right() + 10.0
		var right := vw - 14.0 - (card_panel.size.x + 12.0 if card_panel.visible else 0.0)
		var w := clampf(right - left, SEL_MIN_W, 580.0)
		var x0 := left + maxf(0.0, (right - left - w) * 0.5)
		sel_panel.anchor_left = 0.0
		sel_panel.anchor_right = 0.0
		sel_panel.offset_left = x0
		sel_panel.offset_right = x0 + w
		sel_info.custom_minimum_size.x = w - 22.0
	card_panel.visible = card.get_child_count() > 0
	_card_active()
	if menu_panel.visible:
		_menu_context()
	var bs: UiScrim = _scrims["bottom"]
	var want_b := 1.0 if (sel_panel.visible or card_panel.visible) else 0.55
	if absf(bs.strength - want_b) > 0.01:
		bs.strength = move_toward(bs.strength, want_b, rdt * 4.0)
		bs.queue_redraw()
	if slow:
		top.queue_redraw()
		orbat.queue_redraw()
		layers_ui.queue_redraw()
		coop_roster.queue_redraw()
	# keep notifications clear of the performance overlay
	var perf_big := int(Settings.get_v("perf")) >= 2
	if perf_big != (toasts.anchor_left == 0.0):
		if perf_big:
			toasts.anchor_left = 0.0
			toasts.anchor_right = 0.0
			toasts.offset_left = 14
			toasts.offset_right = 440
			toasts.offset_top = 190
			toasts.offset_bottom = 430
		else:
			toasts.anchor_left = 1.0
			toasts.anchor_right = 1.0
			toasts.offset_left = -440
			toasts.offset_right = -14
			toasts.offset_top = 36
			toasts.offset_bottom = 290
	# the command net goes under the objectives (or the frame-rate readout),
	# and the notifications under that
	var perf_lvl := int(Settings.get_v("perf"))
	var ry := 12.0 if perf_lvl < 1 else 34.0
	if objectives.need_h > 0.0:
		ry = 12.0 + objectives.need_h + 10.0
	elif perf_big:
		ry = 22.0 + (184.0 if perf_lvl == 2 else 590.0) + 8.0  # (perf_overlay.gd's PANEL_H)
	coop_roster.position = Vector2(root.size.x - 14.0 - HudCoopRoster.W, ry)
	coop_roster.size = Vector2(HudCoopRoster.W, coop_roster.need_h)
	if not perf_big:
		# under the objectives, and above the command card on a short screen
		var ty := 36.0 if objectives.need_h <= 0.0 else 12.0 + objectives.need_h + 10.0
		if coop_roster.need_h > 0.0:
			ty = ry + coop_roster.need_h + 10.0
		var tb := ty + 254.0
		if card_panel.visible:
			tb = clampf(card_panel.position.y - 10.0, ty + 40.0, tb)
		if toasts.offset_top != ty or toasts.offset_bottom != tb:
			toasts.offset_top = ty
			toasts.offset_bottom = tb
	toasts.tick(rdt)
	minimap.refresh_layers()
	if world.cam:
		overlay.refresh_for_view(rdt, world.cam.cam)
	pointer_overlay.queue_redraw()
	coop.queue_redraw()


## A fire mission's name, short: its designation and what it does
## ("A-10C Thunderbolt II Gun Run" is A-10C GUN RUN); the full name is its tooltip.
const _FIRE_WORDS := ["Strike", "Gun", "Run", "Gunship", "Strafe", "Drone", "Recon", "Pass", "Precision", "Overwatch", "Artillery", "Barrage",
	"Mortars", "Smoke", "Airstrike", "Bombing", "Rockets", "Missile", "Salvo", "Cluster", "Napalm", "Strike.", "Rocket", "Helicopter"]


static func fire_short(name: String) -> String:
	var tok := name.split(" ")
	var out := [tok[0]]
	for i in range(1, tok.size()):
		var w := String(tok[i])
		if w in _FIRE_WORDS or w == w.to_lower() or w.contains("-"):
			out.append(w)
	return " ".join(out).to_upper()


## FIRES (docs/UI.md, Layout): the fire missions on call, a row each above the
## minimap. The ready ones are listed; the ones cooling down fold into a last
## row (+9 ON COOLDOWN · NEXT 81S) that opens them.
func _update_support() -> void:
	var kinds: Array = Defs.supports_for(world.local_team) if world.local_team >= 0 else Defs.DEMO_SUPPORT.duplicate()
	if world.local_team >= 0 and not world.mission_info.is_empty():
		# a mission has what's on call for it, and nothing else
		var on_call: Array = world.mission_info.get("sup", [])
		kinds = kinds.filter(func(k): return k in on_call)
	var key := ",".join(kinds)
	if key != _support_key:
		_support_key = key
		for c in support_box.get_children():
			c.queue_free()
		_support_btns.clear()
		if kinds.is_empty():
			support_box.add_child(UiKit.caps("No support on call", 12, UiKit.DIM))
		if not kinds.is_empty():
			support_box.add_child(UiKit.header("Support", "%02d" % kinds.size()))
		for k in kinds:
			var kk: String = k
			var b := _fire_row(fire_short(String(Defs.SUPPORT[k].name)), "%s\n%s" % [Defs.SUPPORT[k].name, Defs.SUPPORT[k].desc], func():
				world.input.cancel_modes()
				world.input.ability = ("support:" if world.local_team >= 0 else "demo:") + kk)
			support_box.add_child(b)
			_support_btns[k] = b
		_fires_more = _fire_row("", "Show every fire mission", func(): _fires_open = not _fires_open)
		support_box.add_child(_fires_more)
		_fires_more.visible = not kinds.is_empty()
	if kinds.is_empty():
		return
	var sup: Dictionary = world.team_info[world.local_team].get("sup", {}) if world.local_team >= 0 else {}
	var first := true
	var cooling := []
	for k in kinds:
		var b: Button = _support_btns.get(k)
		if b == null:
			continue
		var sd: Dictionary = Defs.SUPPORT[k]
		var left := float(sup.get(k, Defs.support_from(k))) - world.time if world.local_team >= 0 else 0.0
		b.disabled = left > 0.0
		var state: Label = b.get_meta("state")
		var nm: Label = b.get_meta("name")
		if left <= 0.0:
			var zk := Keys.label("support")
			state.text = ("[%s] RDY · %d" % [zk.to_upper(), int(sd.cost)]) if first and zk != "" else ("RDY · %d" % int(sd.cost))
			if world.local_team < 0:
				state.text = "DEMO"
			state.add_theme_color_override("font_color", UiKit.GOOD)
			nm.add_theme_color_override("font_color", UiKit.TEXT)
			first = false
			b.visible = true
		else:
			state.text = "%dS" % int(ceil(left))
			state.add_theme_color_override("font_color", UiKit.FAINT)
			nm.add_theme_color_override("font_color", UiKit.DIM)
			cooling.append([left, b])
	# the ones cooling down: shown when opened, or a couple when few are ready
	cooling.sort_custom(func(a, c): return float(a[0]) < float(c[0]))
	var show_n := cooling.size() if _fires_open else maxi(0, 2 - (kinds.size() - cooling.size()))
	for i in cooling.size():
		(cooling[i][1] as Button).visible = i < show_n
	var hidden := cooling.size() - show_n
	_fires_more.visible = hidden > 0 or (_fires_open and cooling.size() > 0)
	(_fires_more.get_meta("name") as Label).text = ("+%d on cooldown" % hidden) if hidden > 0 else "Fold the list"
	(_fires_more.get_meta("state") as Label).text = ("NEXT %dS" % int(ceil(float(cooling[show_n][0])))) if hidden > 0 else ""


## A row of the fire support list: its name, and its state at the end.
func _fire_row(name: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 24)
	b.tooltip_text = tip
	var n := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.LINE, 0, 0.0)
	n.border_width_bottom = 1
	var h := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, UiKit.LINE, 0, 0.0)
	h.border_width_bottom = 1
	var pr := UiKit.box(UiKit.fa(UiKit.ACCENT, 0.22), 0, UiKit.LINE, 0, 0.0)
	pr.border_width_bottom = 1
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 2
	row.offset_right = -2
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var l := UiKit.caps(name, 12, UiKit.TEXT, 600, 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var st := UiKit.mono_label("", 12, UiKit.FAINT)
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(st)
	b.set_meta("name", l)
	b.set_meta("state", st)
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func mode_text() -> String:
	var inp := world.input
	if inp == null:
		return ""
	if inp.ability.begins_with("support:") or inp.ability.begins_with("demo:"):
		var k := inp.ability.get_slice(":", 1)
		var shp := String(Defs.SUPPORT.get(k, {}).get("shape", "circle"))
		return "%s: click the target%s  -  right-click cancels" % [String(Defs.SUPPORT.get(k, {}).get("name", k)), " and drag to set the direction it runs in" if shp in ["line", "strafe", "sweep"] else ""]
	if inp.place_kind != "":
		var rk := Keys.label("rotate_build")
		return "Placing %s  -  left-click to build, drag for a line, %sShift+wheel rotates, right-click cancels" % [Defs.BUILDINGS[inp.place_kind].name, (rk + " / ") if rk != "" else ""]
	if inp.order_mode == "assault":
		return "Attack-move: click where to push (drag to face)  -  they bound forward cover to cover and fight what they meet"
	if inp.order_mode == "defend":
		return "Defend: click the ground to hold, drag to set the facing  -  they spread out into the best cover there"
	if inp.ability != "":
		match inp.ability:
			"frag":
				return "Left-click to throw a grenade"
			"smoke":
				return "Left-click to throw smoke"
			"mortar_he", "pit_he":
				return "Left-click: mortar fire mission (HE)"
			"arty_he":
				return "Left-click: artillery fire mission"
			_:
				return "Left-click: mortar fire mission (smoke)"
	return ""


func _update_card() -> void:
	var inp := world.input
	var key := ""
	var st: Structure = null
	if inp.sel_unit != 0:
		key = "unit:%d" % inp.sel_unit
	elif inp.has_units():
		key = "units:%s" % ("inf" if not inp.sel_squads.is_empty() else "veh")
		if inp.selection_has_mortar():
			key += ":mortar"
	elif inp.sel_structure != 0:
		st = world.entity(inp.sel_structure) as Structure
		if st:
			key = "st:%d:%s:%s:%d" % [st.eid, st.skind, str(st.built), st.team]
			if st.skind == "research":
				key += str(world.team_info[world.local_team].get("up", []) if world.local_team >= 0 else [])
			if st.skind == "tunnel":
				for t in world.structures:
					if t.skind == "tunnel" and t.team == st.team and t.built:
						key += ":%d" % t.eid
	if st and Defs.BUILDINGS.get(st.skind, {}).has("produces") and world.local_team >= 0:
		key += str(world.team_info[world.local_team].get("up", []))  # research unlocks vehicle tiers
	if not key.begins_with("units:inf") and not (_card_page.begins_with("prod:") and key == _page_base):
		_card_page = "main"
	_page_base = key
	key += "|" + _card_page
	if key == _card_key:
		return
	_card_key = key
	for c in card.get_children():
		c.queue_free()
	card_title.text = ""
	var lt := world.local_team
	if lt < 0:
		return
	if key.begins_with("unit:"):
		var su: Soldier = world.entity(inp.sel_unit) as Soldier
		card_title.text = "Orders · %s" % (su.sname if su else "")
		_button("Grenade", Keys.label("grenade"), "Throw a frag grenade at a spot.", func(): inp.ability = "frag")
		_button("Smoke", Keys.label("smoke"), "Throw smoke to block line of sight.", func(): inp.ability = "smoke")
		_button("Hold", Keys.label("hold"), "Stop right here.", func(): inp.hold())
		_button("Fall back", Keys.label("retreat"), "Run back to the nearest FOB.", func(): inp.retreat())
		_button("Squad", "", "Select his whole squad again (any squad order brings him back in).", func():
			var s2: Soldier = world.entity(inp.sel_unit) as Soldier
			if s2 and s2.sid != 0:
				inp.clear_selection()
				inp.sel_squads.append(s2.sid))
	elif key.begins_with("units:inf"):
		if _card_page == "main":
			card_title.text = "Orders"
			_button("Attack-move", Keys.label("attack_move"), "Push to a spot in bounds, one fire team moving while the other covers. They stop to fight anything they meet, then dig in at the objective. (Ctrl+right-click)", func(): inp.cancel_modes(); inp.order_mode = "assault")
			_button("Defend", Keys.label("defend"), "Hold an area: the squad spreads into the best cover there facing the way you drag, and stays put.", func(): inp.cancel_modes(); inp.order_mode = "defend")
			_button("Base", "Build", "FOBs, barracks, factory, medic tent, research...", func(): _card_page = "base")
			_button("Defenses", "Build", "Trenches, sandbags, wire, mines, nests, mortar pits, bunkers...", func(): _card_page = "def")
			if key.contains(":mortar"):
				_button("Mortar HE", Keys.label("fire_mission"), "Fire mission: 4 high-explosive rounds (25-140 m).", func(): inp.ability = "mortar_he")
				_button("Mortar smoke", "", "Fire mission: 4 smoke rounds to screen an advance or a rescue.", func(): inp.ability = "mortar_smoke")
			_button("Grenade", Keys.label("grenade"), "Throw a frag grenade at a spot.", func(): inp.ability = "frag")
			_button("Smoke", Keys.label("smoke"), "Throw smoke to block line of sight.", func(): inp.ability = "smoke")
			_button("Retreat", Keys.label("retreat"), "Run back to the nearest FOB, keeping clear of known enemy fire. Retreating men shrug off half the suppression.", func(): inp.retreat())
			_button("Hold", Keys.label("hold"), "Stop and hold position here.", func(): inp.hold())
		else:
			card_title.text = "Build %s" % ("base" if _card_page == "base" else "defences")
			_button("Back", "‹", "Back to orders.", func(): _card_page = "main")
			for kind in Defs.BUILD_MENU[lt]:
				if (kind in BASE_KINDS) != (_card_page == "base"):
					continue
				var d: Dictionary = Defs.BUILDINGS[kind]
				_button(d.name, str(d.cost), "%s\nCost %d supply. Build time %ds (engineers are twice as fast)." % [d.desc, d.cost, int(d.time)], func(): inp.start_place(kind))
	elif key.begins_with("units:veh"):
		card_title.text = "Vehicle orders"
		_button("Attack-move", Keys.label("attack_move"), "Drive to a spot, halting for a steady shot at anything in range on the way. Troops inside dismount when the enemy is close.", func(): inp.cancel_modes(); inp.order_mode = "assault")
		_button("Dismount", "", "Drop the ramp: the troops inside get out and dig in.", func(): world.send_cmd({"t": "dismount", "vehicles": inp.sel_vehicles}))
		if inp.selection_has_arty():
			_button("Fire mission", Keys.label("fire_mission"), "Artillery: click a spot in range for a salvo there (they also fire on their own at anything your side has spotted).", func(): inp.ability = "arty_he")
		_button("Hold", Keys.label("hold"), "Stop moving.", func(): inp.hold())
		_button("Retreat", Keys.label("retreat"), "Drive back to the nearest FOB.", func(): inp.retreat())
	elif st and st.team == lt and st.built:
		var def: Dictionary = Defs.BUILDINGS.get(st.skind, {})
		if def.has("produces"):
			var items: Array = def.produces[lt]
			var tier := 1
			for k in world.team_info[lt].get("up", []):
				if Defs.UPGRADES.has(k):
					tier = maxi(tier, int(Defs.UPGRADES[k].get("tier", 1)))
			var cats := []
			for item in items:
				var c := _prod_cat(item)
				if not c in cats:
					cats.append(c)
			var page := _card_page.trim_prefix("prod:") if _card_page.begins_with("prod:") else ""
			if cats.size() > 1 and items.size() > 9 and page == "":
				# a long list: pick a category first
				card_title.text = "Train · RMB sets the rally point"
				for c in cats:
					var n := 0
					for item in items:
						if _prod_cat(item) == c:
							n += 1
					var cc: String = c
					_button(PROD_CATS[cc][0], "%d types" % n, PROD_CATS[cc][1], func(): _card_page = "prod:" + cc)
			else:
				card_title.text = ("Train %s · RMB sets the rally point" % String(PROD_CATS[page][0]).to_lower()) if page != "" else "Train · RMB sets the rally point"
				if page != "":
					_button("Back", "‹", "Back to the categories.", func(): _card_page = "main")
				for item in items:
					if page != "" and _prod_cat(item) != page:
						continue
					var d2: Dictionary = Defs.SQUADS[item] if Defs.SQUADS.has(item) else Defs.VEHICLES[item]
					var sid := st.eid
					var need_t := int(d2.get("tier", 1))
					if need_t > tier:
						var research := ""
						for uk in Defs.UPGRADES:
							if int(Defs.UPGRADES[uk].get("tier", 0)) == need_t and lt in Defs.UPGRADES[uk].teams:
								research = String(Defs.UPGRADES[uk].name)
						var lb := _button(d2.name, "tier %d" % need_t, "%s\nLocked: research %s at a Research Post." % [d2.desc, research], func(): pass)
						lb.disabled = true
					else:
						_button(d2.name, str(d2.cost), "%s\nCost %d, %ds." % [d2.desc, d2.cost, int(d2.time)], func(): world.send_cmd({"t": "train", "building": sid, "item": item}))
			_button("Cancel", "", "Cancel the last item in the queue (refunded).", func(): world.send_cmd({"t": "cancel", "building": st.eid}))
		elif st.skind == "research":
			card_title.text = "Research"
			var have: Array = world.team_info[lt].get("up", [])
			for k in Defs.UPGRADES:
				var u: Dictionary = Defs.UPGRADES[k]
				if not lt in u.teams or k in have:
					continue
				var sid2 := st.eid
				_button(u.name, str(u.cost), "%s\nCost %d, %ds." % [u.desc, u.cost, int(u.time)], func(): world.send_cmd({"t": "research", "building": sid2, "item": k}))
		elif st.skind == "mortar_pit":
			card_title.text = "Mortar pit · fires on spotted enemies"
			_button("Fire HE", "", "Fire mission: 6 high-explosive rounds on a spot.", func(): inp.ability = "pit_he")
			_button("Fire smoke", "", "Fire mission: 6 smoke rounds to screen an area.", func(): inp.ability = "pit_smoke")
		elif st.skind == "tunnel":
			card_title.text = "Tunnel network"
			_button("Exit here", "", "Bring everyone inside back out at this entrance.", func(): world.send_cmd({"t": "tunnel_exit", "building": st.eid, "exit": st.eid}))
			for t in world.structures:
				if t.skind == "tunnel" and t.team == lt and t.built and t != st:
					var ex: int = t.eid
					_button("Exit " + Defs.grid_ref(t.position), "", "Move everyone inside to the entrance at %s." % Defs.grid_ref(t.position), func(): world.send_cmd({"t": "tunnel_exit", "building": st.eid, "exit": ex}))


## Which production page an item is on.
func _prod_cat(item: String) -> String:
	if Defs.SQUADS.has(item):
		return "inf"
	var d: Dictionary = Defs.VEHICLES.get(item, {})
	if d.has("cat"):
		return String(d.cat)
	match String(d.get("base", "")):
		"tank", "afv":
			return "armour"
		"spaa", "arty":
			return "support"
		"supply", "util", "ugv":
			return "logistics"
		"attack_heli", "lift_heli", "uav":
			return "air"
	return "light"


## An order in the orders grid (docs/UI.md, Keys): its key in a box, its name
## in capitals, and (for a build, a train or a page) its cost or a mark at the
## end. A key fills with the accent while its order is the one in hand.
func _button(text: String, sub: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.custom_minimum_size = CARD_BTN
	b.focus_mode = Control.FOCUS_NONE
	var n := UiKit.box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0.0)
	var h := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, Color(0, 0, 0, 0), 0, 0.0)
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, h)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var is_key := sub != "" and not sub.is_valid_int() and sub != "Build" and sub != "‹" and not sub.begins_with("tier ") and not sub.ends_with(" types")
	var kb: PanelContainer = null
	if is_key:
		kb = _key_box(sub.to_upper())
		kb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(kb)
	var danger := text in ["Retreat", "Fall back", "Cancel"]
	var l := UiKit.caps(text, 12, UiKit.BAD if danger else UiKit.TEXT, 600, 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if sub != "" and not is_key:
		var tag := sub
		if sub == "Build":
			tag = "›"
		elif sub.begins_with("tier "):
			tag = "T" + sub.trim_prefix("tier ")
		elif sub.ends_with(" types"):
			tag = sub.trim_suffix(" types")
		var sl := UiKit.mono_label(tag, 11, UiKit.FAINT)
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sl)
	b.set_meta("name", l)
	if kb:
		b.set_meta("key", kb)
	b.set_meta("order", text)
	b.pressed.connect(func(): Sfx.ui("click"); cb.call(); _card_key = "")
	card.add_child(b)
	return b


## Which order is in hand (attack-move, defend, a grenade, a fire mission):
## its key in the orders grid fills with the accent.
func _card_active() -> void:
	var inp := world.input
	if inp == null:
		return
	var hand := {"Attack-move": inp.order_mode == "assault", "Defend": inp.order_mode == "defend", "Grenade": inp.ability == "frag",
		"Smoke": inp.ability == "smoke", "Mortar HE": inp.ability == "mortar_he", "Mortar smoke": inp.ability == "mortar_smoke",
		"Fire mission": inp.ability == "arty_he", "Fire HE": inp.ability == "pit_he", "Fire smoke": inp.ability == "pit_smoke"}
	for b in card.get_children():
		if not b.has_meta("key"):
			continue
		var on: bool = hand.get(String(b.get_meta("order")), false)
		if on == b.get_meta("on", false):
			continue
		b.set_meta("on", on)
		var kb: PanelContainer = b.get_meta("key")
		var sb := UiKit.box(UiKit.ACCENT if on else Color(0, 0, 0, 0), 0, UiKit.ACCENT if on else UiKit.RULE2, 1, 0.0)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		kb.add_theme_stylebox_override("panel", sb)
		(kb.get_child(0) as Label).add_theme_color_override("font_color", UiKit.ON_ACCENT if on else UiKit.TEXT)
		(b.get_meta("name") as Label).add_theme_color_override("font_color", UiKit.ACCENT if on else UiKit.TEXT)
