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
	# a short screen (a big interface scale) keeps room above it for the support buttons
	return minf(s, maxf(160.0, root.size.y * 0.4)) if root and root.size.y > 0.0 else s


## Lays out the bottom-left corner round the minimap's size: the map, its
## layer column to the right, the support buttons and the chat line above.
func layout_minimap() -> void:
	var s := minimap_side()
	var outer := s + MINIMAP_PAD * 2.0
	minimap.custom_minimum_size = Vector2(s, s)
	minimap_panel.offset_left = 14
	minimap_panel.offset_right = 14 + outer
	minimap_panel.offset_bottom = -14
	minimap_panel.offset_top = -14 - outer
	minimap_panel.size = Vector2(outer, outer)
	var lh := HudLayers.S * HudLayers.ITEMS.size() + 4.0 * (HudLayers.ITEMS.size() - 1)
	layers_ui.offset_left = 14 + outer + 6
	layers_ui.offset_right = layers_ui.offset_left + HudLayers.S
	layers_ui.offset_bottom = -14
	layers_ui.offset_top = -14 - lh
	var above := -14 - outer - 6
	support_box.offset_bottom = above
	support_box.offset_top = above
	chat_edit.offset_bottom = above
	chat_edit.offset_top = above - 34


## The narrowest the selection panel gets, and a command card button.
const SEL_MIN_W := 300.0
const CARD_BTN := Vector2(92, 46)


## Where the bottom-left cluster (minimap and layer column) ends on the right.
func minimap_right() -> float:
	return 14 + minimap_side() + MINIMAP_PAD * 2.0 + 6 + HudLayers.S


## How the map is drawn (each toggled from the layer column by the minimap).
const LAYER_KEYS := {"units": "lyr_units", "orders": "lyr_orders", "intel": "lyr_intel", "vision": "lyr_vision", "ranges": "lyr_ranges", "labels": "labels"}
const PHASE_NAMES := {"plan": "Planning", "move": "Moving into position", "fix": "Fixing the enemy", "assault": "Assault", "fallback": "Falling back"}

var world: World
var typing := false
var tactical := false
## sid -> [order, where, facing, order number, team, msec the order came in (-1: already standing), attack plan or null]
var orders := {}
var orbat: HudOrbat
var _slow_t := 0.0
var _map_t := 0.0
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
var _log_head: Label
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
var coop: HudCoop  # the other commanders on our side, over the battlefield
var coop_roster: HudCoopRoster  # ...and listed top right
var alert_label: Label
var _alert_t := 0.0
var over_panel: PanelContainer
var help_panel: PanelContainer
var menu_panel: PanelContainer
var settings_panel: SettingsPanel
var manual: FieldManual
var support_box: VBoxContainer
var _support_btns := {}  # kind -> Button
var _support_key := ""
var demo_panel: PanelContainer
var _inspect: Entity = null
var _inspect_t := 0.0
var _msgs: Array = []


func _ready() -> void:
	layer = 5
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
	root.add_child(overlay)

	# co-commanders: their views, cursors, selections, plans and pings
	coop = HudCoop.new()
	coop.hud = self
	coop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coop)

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
	alert_label.add_theme_font_override("font", UiKit.font(600))
	alert_label.add_theme_font_size_override("font_size", 19)
	alert_label.add_theme_color_override("font_color", UiKit.WARN)
	alert_label.add_theme_constant_override("outline_size", 7)
	alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_label)

	# minimap, bottom-left (sized by the settings: see layout_minimap)
	minimap_panel = PanelContainer.new()
	minimap_panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 8, UiKit.LINE, 1, MINIMAP_PAD, 10))
	minimap_panel.anchor_top = 1.0
	minimap_panel.anchor_bottom = 1.0
	root.add_child(minimap_panel)
	minimap = HudMinimap.new()
	minimap.hud = self
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
	support_box.add_theme_constant_override("separation", 3)
	root.add_child(support_box)

	chat_edit = LineEdit.new()
	chat_edit.anchor_top = 1.0
	chat_edit.anchor_bottom = 1.0
	chat_edit.offset_left = 14
	chat_edit.offset_right = 430
	chat_edit.visible = false
	chat_edit.text_submitted.connect(_on_chat)
	chat_edit.focus_exited.connect(func(): _close_chat())
	root.add_child(chat_edit)
	layout_minimap()
	Settings.changed.connect(layout_minimap)
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
	root.add_child(card_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card_panel.add_child(cv)
	card_title = UiKit.label("", 12, UiKit.DIM)
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # the buttons set the card's width, not the title
	cv.add_child(card_title)
	card = GridContainer.new()
	card.columns = 5
	card.add_theme_constant_override("h_separation", 5)
	card.add_theme_constant_override("v_separation", 5)
	cv.add_child(card)

	# message history (L)
	log_panel = PanelContainer.new()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = -480
	log_panel.offset_right = -14
	log_panel.offset_top = 60
	log_panel.offset_bottom = 420
	log_panel.visible = false
	root.add_child(log_panel)
	var lv := VBoxContainer.new()
	log_panel.add_child(lv)
	_log_head = UiKit.header("Messages")
	lv.add_child(_log_head)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 13)
	lv.add_child(log_box)

	over_panel = _center_panel(Vector2(440, 220))
	help_panel = _center_panel(Vector2(720, 620))
	menu_panel = _center_panel(Vector2(320, 300))
	_build_help()
	Keys.changed.connect(_keys_changed)
	_build_menu()
	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	root.add_child(settings_panel)
	UiKit.fit_center(settings_panel, Vector2(700, 600))
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


func _build_observer_bar() -> void:
	obs_bar = PanelContainer.new()
	obs_bar.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 8, UiKit.LINE, 1, 6.0, 10))
	obs_bar.anchor_left = 0.5
	obs_bar.anchor_right = 0.5
	obs_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	obs_bar.offset_top = 12
	obs_bar.visible = false
	root.add_child(obs_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	obs_bar.add_child(hb)
	var tag := UiKit.label("OBSERVER", 12, UiKit.ACCENT, 600)
	tag.custom_minimum_size = Vector2(76, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(tag)
	obs_pause = _small_button("Pause", "Pause / resume (P)", func(): world.director.toggle_pause())
	hb.add_child(obs_pause)
	obs_slower = _small_button("-", "Slower", func(): world.director.set_speed_index(world.director.speed_i - 1))
	hb.add_child(obs_slower)
	obs_speed = UiKit.label("1x", 14, UiKit.TEXT, 600)
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
	var s2 := VSeparator.new()
	hb.add_child(s2)
	var fs := _small_button("Fire support", "Call in any air or artillery support to watch it (observer demo)", func(): demo_panel.visible = not demo_panel.visible)
	fs.toggle_mode = true
	fs.custom_minimum_size = Vector2(110, 30)
	hb.add_child(fs)
	_build_demo_panel()


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
	for p in [obs_bar, demo_panel]:
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
		demo_panel.offset_top = -14.0 - obs_bar.size.y - 8.0
		demo_panel.offset_bottom = demo_panel.offset_top
	else:
		obs_bar.offset_top = 12.0
		obs_bar.offset_bottom = 12.0
		demo_panel.offset_top = 62.0
		demo_panel.offset_bottom = 62.0


func _small_button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(34 if text.length() <= 1 else 74, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func _center_panel(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.06, 0.055, 0.94), 10, UiKit.LINE, 1, 18.0, 18))
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


## The controls (F1), with the keys as they're bound now: rebuilt when they change.
func _build_help() -> void:
	for c in help_panel.get_children():
		c.queue_free()
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.add_theme_font_size_override("normal_font_size", 14)
	l.add_theme_font_override("bold_font", UiKit.font(600))
	var t := "[font_size=20][b]Controls[/b][/font_size]   [color=#9ea292]Change any key in Settings > Controls[/color]\n\n"
	t += "[color=#f5c96e]Camera[/color]  %s or the screen edge to pan (%s: faster), wheel to zoom toward the cursor (or %s / %s), %s / %s to turn, %s / %s to tilt. Middle-drag turns and tilts; Alt+middle-drag grabs the map (swap them in Settings > Interface). %s squares the view up again. %s follows the selection. %s..%s save a view, %s..%s go back to it. %s cycles your FOBs, %s jumps to the last alert or ping. Zoom in close to see what every soldier is doing.\n" % [
		_k_pan(), _k("cam_fast"), _k("cam_zoom_in"), _k("cam_zoom_out"), _k("cam_turn_left"), _k("cam_turn_right"), _k("cam_tilt_up"), _k("cam_tilt_down"),
		_k("cam_reset"), _k("cam_follow"), _k("view_save_1"), _k("view_save_4"), _k("view_go_1"), _k("view_go_4"), _k("cycle_fob"), _k("jump_alert")]
	t += "[color=#f5c96e]Minimap[/color]  Click or drag to look there, right-click to send the selection, wheel to zoom. The white wedge is the camera's view, orange rings are firefights, the needle points north (click it to square up). Size and turning with the camera: Settings > Interface.\n"
	t += "[color=#f5c96e]Command view[/color]  %s switches to the tactical map. %s opens the order of battle (click a unit to select it and look at it). The buttons beside the minimap turn map layers on and off: unit symbols, orders and attack plans, intelligence (last known enemy positions), fog of war, weapon ranges, soldier labels.\n" % [_k("tactical"), _k("orbat")]
	t += "[color=#f5c96e]Select[/color]  Click a soldier to select his squad, drag a box, double-click for every squad of that type on screen. %s..%s set a group, %s..%s recall it (twice quickly jumps there). Alt+click a soldier (or click his name in the squad panel) to command just him.\n" % [_k("group_set_1"), _k("group_set_9"), _k("group_1"), _k("group_9")]
	t += "[color=#f5c96e]Orders[/color]  Right-click ground to move (Shift = run; drag to set the facing), an enemy to attack, an unfinished or damaged building to build or repair, a tunnel / nest / bunker to enter it, a boat to board it (they wade out to it). With a lift helicopter selected, right-click one of your vehicles to sling it underneath, then right-click where to set it down. The pips show where each man will fight from: green hard cover (sandbags, stone, earth), lime medium (cars, house walls - a machine gun goes through), yellow soft (a hedge hides you, bullets don't care), red caught in the open; the tick points the way he'll fire over it. Low cover is fought from prone, waist-high kneeling, chest-high standing; tall walls from their edges.\n"
	t += "[color=#f5c96e]Squad[/color]  %s attack-move (or Ctrl+right-click), %s defend an area, %s retreat, %s hold, %s grenade, %s smoke, %s mortar fire mission.\n" % [_k("attack_move"), _k("defend"), _k("retreat"), _k("hold"), _k("grenade"), _k("smoke"), _k("fire_mission")]
	t += "[color=#f5c96e]Build[/color]  Select infantry, open Base or Defenses on the command card and click to place (%s turns 90 degrees, Shift+wheel 45; everything snaps to the 1 m build grid). Drag to lay a whole line of trenches (fire bays and traverses; hold Alt for straight), sandbags, wire or walls.\n" % _k("rotate_build")
	t += "[color=#f5c96e]Support[/color]  The buttons above the minimap (%s arms the first one ready): click the target and drag to set the run-in direction. Observers can launch any of them from Fire support.\n" % _k("support")
	t += "[color=#f5c96e]Co-commanders[/color]  Every commander has a colour. On your side, theirs show as viewfinders on the ground and the minimap (where they're looking), cursors with their names and what they're doing, rings round what they've selected, and the building, fire mission or order they're lining up before they commit it. The Command Net (top right) lists them: click a name to look where they're looking, the screen button (or a double-click) to watch their view live%s. Alt+click to ping: an enemy (enemy spotted), one of ours (watch this) or the ground (look here), on the minimap too%s. Hold Alt and the left button for the ping wheel: attack, on my way, need support, danger, defend, look. Alt+right-drag draws on the map for your side.\n" % [
		(" (%s goes from one to the next)" % _k("coop_next")) if Keys.label("coop_next") != "" else "", (", or %s (hold it for the wheel)" % _k("ping")) if Keys.label("ping") != "" else ""]
	t += "[color=#f5c96e]Supply[/color]  Each FOB lays a road back to your lines. Trucks drive supply down it; lose the road and the FOBs beyond it starve. The top bar shows what's coming in a minute.\n"
	t += "[color=#f5c96e]Towns[/color]  The town and every village have a supply dump flying the flag of whoever holds it. Get men inside its ring with no enemy there to take it (right-click a town that isn't yours with squads selected). A town you hold fills its dump and trucks it to your nearest FOB, refills your men's ammunition round the dump, and lets you build a FOB near it. Click a dump to see what it gives.\n"
	t += "[color=#f5c96e]Win[/color]  Take or destroy every enemy FOB.\n\n"
	t += "[color=#f5c96e]Observer[/color]  %s director camera, %s switch whose eyes you watch through, %s pause, %s and %s change speed.\n" % [_k("director"), _k("view_side"), _k("pause"), _k("slower"), _k("faster")]
	t += "[color=#f5c96e]Other[/color]  %s chat (%s team), %s message history, %s hide the interface, %s performance overlay, %s Field Manual, Esc menu & settings." % [_k("chat"), _k("chat_team"), _k("log"), _k("hide_hud"), _k("perf"), _k("manual")]
	l.text = t
	help_panel.add_child(l)


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
	_log_head.text = ("MESSAGES  (%s TO CLOSE)" % Keys.label("log").to_upper()) if Keys.label("log") != "" else "MESSAGES"


## " (key)" for a tooltip, or "" when nothing is bound.
func _kt(id: String) -> String:
	var s := Keys.label(id)
	return ("  (%s)" % s) if s != "" else ""


func _build_menu() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	menu_panel.add_child(vb)
	var t := UiKit.label("Paused" if world.director and world.director.can_control_time() else "Menu", 22, UiKit.TEXT, 600)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for it in [["Resume", func(): menu_panel.visible = false],
			["Settings", func(): menu_panel.visible = false; settings_panel.visible = true],
			["Field Manual", func(): menu_panel.visible = false; manual.visible = true],
			["Controls", func(): menu_panel.visible = false; toggle_help()],
			["Leave Battle", _leave]]:
		var b := Button.new()
		b.text = it[0]
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(it[1])
		vb.add_child(b)


func _leave() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("return_to_menu"):
		main.return_to_menu("")


func toggle_manual() -> void:
	manual.visible = not manual.visible


func toggle_menu() -> void:
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
		log_panel.visible = false
		return
	menu_panel.visible = not menu_panel.visible


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
	layers_ui.queue_redraw()
	Sfx.ui("click")


func toggle_orbat() -> void:
	orbat.toggle()


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
## squad card: {text, col, glyph, contact, pinned, wounded, low_ammo}.
func squad_state(sid: int, mem: Array) -> Dictionary:
	var out := {"text": "Holding", "col": UiKit.DIM, "glyph": "", "contact": false, "pinned": false, "wounded": 0, "low_ammo": false, "morale": -1, "mstate": 0}
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
		var pl = o[6]
		if pl != null:
			out.text = plan_text(pl)
		out.morale = int(o[7])
		out.mstate = SquadBrain.state(float(o[7]), String(o[8]) == "rout") if int(o[7]) >= 0 else 0
	if riding:
		out.text = "Mounted  ·  " + out.text
	if out.pinned:
		out.text = "PINNED  ·  " + out.text
		out.col = UiKit.BAD
	elif out.contact and not String(out.text).begins_with("Attacking"):
		out.text = "In contact  ·  " + out.text
		out.col = Color(1.0, 0.72, 0.42)
	return out


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
	var line := "[color=#777]%d:%02d[/color]  [color=#%s]%s[/color]" % [mins, secs, col.to_html(false), clean]
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


func show_game_over(w: int) -> void:
	for c in over_panel.get_children():
		c.queue_free()
	if not world.mission_info.is_empty():
		_mission_over()
		return
	Music.sting("defeat" if world.local_team >= 0 and w != world.local_team else "victory")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	over_panel.add_child(vb)
	var t := UiKit.label("", 38, UiKit.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if world.local_team < 0:
		t.text = "%s WIN" % Defs.TEAM_NAMES[w].to_upper()
		t.add_theme_color_override("font_color", Defs.TEAM_COLORS[w].lightened(0.3))
	elif w == world.local_team:
		t.text = "VICTORY"
		t.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		t.text = "DEFEAT"
		t.add_theme_color_override("font_color", UiKit.BAD)
	vb.add_child(t)
	var s := UiKit.label("%s have taken the battlefield." % Defs.TEAM_NAMES[w], 15, UiKit.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var b := Button.new()
	b.text = "Return to Menu"
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(_leave)
	vb.add_child(b)
	over_panel.visible = true


## The end of a mission: accomplished or failed, why, and what it cost.
func _mission_over() -> void:
	var info: Dictionary = world.mission_info
	var ok := int(info.get("over", 0)) == 1
	Music.sting("victory" if ok else "defeat")
	UiKit.fit_center(over_panel, Vector2(560, 340))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	over_panel.add_child(vb)
	var op := UiKit.label(String(info.get("op", "")).to_upper(), 12, UiKit.ACCENT, 700)
	op.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(op)
	var t := UiKit.label("MISSION ACCOMPLISHED" if ok else "MISSION FAILED", 34, UiKit.GOOD if ok else UiKit.BAD, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := UiKit.label(String(info.get("end", "")), 15, UiKit.TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(480, 0)
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
	var st := UiKit.label("Time %d:%02d    Objectives %d of %d    Men lost %d of %d    Enemy killed %d" % [int(el) / 60, int(el) % 60, done, all, int(lost[0]), int(lost[1]), int(info.get("kills", 0))], 13, UiKit.DIM)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(st)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	if multiplayer.is_server():
		var again := Button.new()
		again.text = "Play Again" if ok else "Try Again"
		again.custom_minimum_size = Vector2(170, 40)
		again.pressed.connect(func(): over_panel.visible = false; Net.start_game())
		row.add_child(again)
	var b := Button.new()
	b.text = "Return to Menu"
	b.custom_minimum_size = Vector2(170, 40)
	b.pressed.connect(_leave)
	row.add_child(b)
	over_panel.visible = true


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
	var spectator := world.local_team < 0
	obs_bar.visible = spectator and world.director != null
	if obs_bar.visible:
		var d := world.director
		var spd: float = d.speed()
		obs_speed.text = "paused" if spd <= 0.0 else ("%sx" % (str(spd) if spd < 1.0 else str(int(spd))))
		obs_pause.text = "Play" if spd <= 0.0 else "Pause"
		obs_pause.disabled = not d.can_control_time()
		obs_dir.set_pressed_no_signal(d.active)
		obs_view.text = "View: " + (["Both sides", Defs.TEAM_NAMES[0], Defs.TEAM_NAMES[1]][world.view_team + 1])
		_place_obs_bar()
	_track_orders()
	_update_support()
	_update_card()
	# the order of battle fits its contents, down to the support buttons at
	# most, below however many FOB and town lines there are
	orbat.position.y = maxf(100.0, top.position.y + top.content_h + 8.0) if world.local_team >= 0 else 100.0
	var limit := minimap_panel.position.y - 10.0
	if support_box.get_child_count() > 0:
		limit = support_box.global_position.y - 10.0
	var want := HudOrbat.HEAD_H if not orbat.open else orbat.content_h()
	orbat.size = Vector2(HudOrbat.W, clampf(want, HudOrbat.HEAD_H, maxf(HudOrbat.HEAD_H, limit - orbat.position.y)))
	# on a narrow screen (a big interface scale) the command card gives up
	# columns before the selection panel beside it is squeezed
	var room := root.size.x - minimap_right() - 10.0 - SEL_MIN_W - 12.0 - 14.0
	var cols := clampi(int((room - 15.0) / (CARD_BTN.x + 5.0)), 3, 5)
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
		ry = 22.0 + (150.0 if perf_lvl == 2 else 590.0) + 8.0
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
	_map_t -= rdt
	if _map_t <= 0.0:
		_map_t = 1.0 / 15.0
		minimap.queue_redraw()
	overlay.queue_redraw()
	coop.queue_redraw()


func _update_support() -> void:
	var kinds: Array = Defs.supports_for(world.local_team) if world.local_team >= 0 else []
	if not world.mission_info.is_empty():
		# a mission has what's on call for it, and nothing else
		var on_call: Array = world.mission_info.get("sup", [])
		kinds = kinds.filter(func(k): return k in on_call)
	var key := ",".join(kinds)
	if key != _support_key:
		_support_key = key
		for c in support_box.get_children():
			c.queue_free()
		_support_btns.clear()
		var i := 0
		for k in kinds:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(210, 28)
			b.add_theme_font_size_override("font_size", 13)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = String(Defs.SUPPORT[k].desc)
			var kk: String = k
			b.pressed.connect(func():
				Sfx.ui("click")
				world.input.cancel_modes()
				world.input.ability = "support:" + kk)
			support_box.add_child(b)
			_support_btns[k] = b
			i += 1
	if kinds.is_empty():
		return
	var sup: Dictionary = world.team_info[world.local_team].get("sup", {}) if world.local_team >= 0 else {}
	var first := true
	for k in kinds:
		var b: Button = _support_btns.get(k)
		if b == null:
			continue
		var sd: Dictionary = Defs.SUPPORT[k]
		var left := float(sup.get(k, Defs.support_from(k))) - world.time
		b.disabled = left > 0.0
		var zk := Keys.label("support")
		var hot := ("  [%s]" % zk) if first and left <= 0.0 and zk != "" else ""
		if left <= 0.0:
			first = false
		b.text = ("  %s   %d%s" % [sd.name, int(sd.cost), hot]) if left <= 0.0 else ("  %s   %ds" % [sd.name, int(ceil(left))])


## Observer: every kind of support, free, anywhere - to see the effects.
func _build_demo_panel() -> void:
	demo_panel = PanelContainer.new()
	demo_panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 8, UiKit.LINE, 1, 6.0, 10))
	demo_panel.anchor_left = 0.5
	demo_panel.anchor_right = 0.5
	demo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	demo_panel.offset_top = 62
	demo_panel.visible = false
	root.add_child(demo_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	demo_panel.add_child(vb)
	vb.add_child(UiKit.label("FIRE SUPPORT DEMO  -  pick one, click the map (drag sets the run-in direction)", 12, UiKit.ACCENT, 600))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	vb.add_child(g)
	for k in Defs.DEMO_SUPPORT:
		var b := Button.new()
		b.text = String(Defs.SUPPORT[k].name)
		b.tooltip_text = String(Defs.SUPPORT[k].desc)
		b.custom_minimum_size = Vector2(150, 34)
		b.focus_mode = Control.FOCUS_NONE
		var kk: String = k
		b.pressed.connect(func():
			Sfx.ui("click")
			world.input.cancel_modes()
			world.input.ability = "demo:" + kk)
		g.add_child(b)


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
		card_title.text = "SOLDIER ORDERS  -  %s" % (su.sname.to_upper() if su else "")
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
			card_title.text = "ORDERS"
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
			card_title.text = "BUILD %s  -  soldiers walk over and build it by hand" % ("BASE" if _card_page == "base" else "DEFENSES")
			_button("Back", "", "Back to orders.", func(): _card_page = "main")
			for kind in Defs.BUILD_MENU[lt]:
				if (kind in BASE_KINDS) != (_card_page == "base"):
					continue
				var d: Dictionary = Defs.BUILDINGS[kind]
				_button(d.name, str(d.cost), "%s\nCost %d supply. Build time %ds (engineers are twice as fast)." % [d.desc, d.cost, int(d.time)], func(): inp.start_place(kind))
	elif key.begins_with("units:veh"):
		card_title.text = "VEHICLE ORDERS"
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
				card_title.text = "BUILD  -  pick a category (right-click the ground to set a rally point)"
				for c in cats:
					var n := 0
					for item in items:
						if _prod_cat(item) == c:
							n += 1
					var cc: String = c
					_button(PROD_CATS[cc][0], "%d types" % n, PROD_CATS[cc][1], func(): _card_page = "prod:" + cc)
			else:
				card_title.text = ("%s  -  right-click the ground to set a rally point" % String(PROD_CATS[page][0]).to_upper()) if page != "" else "TRAIN  -  right-click the ground to set a rally point"
				if page != "":
					_button("Back", "", "Back to the categories.", func(): _card_page = "main")
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
			card_title.text = "RESEARCH"
			var have: Array = world.team_info[lt].get("up", [])
			for k in Defs.UPGRADES:
				var u: Dictionary = Defs.UPGRADES[k]
				if not lt in u.teams or k in have:
					continue
				var sid2 := st.eid
				_button(u.name, str(u.cost), "%s\nCost %d, %ds." % [u.desc, u.cost, int(u.time)], func(): world.send_cmd({"t": "research", "building": sid2, "item": k}))
		elif st.skind == "mortar_pit":
			card_title.text = "MORTAR PIT  -  fires on spotted enemies, or on your call"
			_button("Fire HE", "", "Fire mission: 6 high-explosive rounds on a spot.", func(): inp.ability = "pit_he")
			_button("Fire smoke", "", "Fire mission: 6 smoke rounds to screen an area.", func(): inp.ability = "pit_smoke")
		elif st.skind == "tunnel":
			card_title.text = "TUNNEL NETWORK"
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


func _button(text: String, sub: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text if sub == "" else "%s\n%s" % [text, sub]
	b.tooltip_text = tip
	b.custom_minimum_size = CARD_BTN
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.ui("click"); cb.call(); _card_key = "")
	card.add_child(b)
	return b











