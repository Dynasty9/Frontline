extends Control
## The commander's instruments have a stable, opaque home; the scene stays open.
var hud: Hud
var idle_panel: UiDeckEmptyState
var _idle_team := -99


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	idle_panel = UiDeckEmptyState.new()
	idle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(idle_panel)


func refresh() -> void:
	var left := hud.minimap_right() + 8.0
	idle_panel.position = Vector2(left, size.y - 134.0 - (hud.obs_bar.size.y + 8.0 if hud.obs_bar.visible and hud._obs_low else 0.0))
	idle_panel.size = Vector2(maxf(240, size.x - left - 14), 120)
	idle_panel.visible = not hud.sel_panel.visible and not hud.card_panel.visible
	if _idle_team != hud.world.local_team:
		_idle_team = hud.world.local_team
		var observer := _idle_team < 0
		idle_panel.configure({
			"eyebrow": "Battle overview" if observer else "Tactical command",
			"title": "Observer" if observer else Defs.TEAM_NAMES[_idle_team] + " command",
			"body": "Select a unit to inspect." if observer else "Select a unit to issue orders.",
			"code": "NO UNIT SELECTED", "help_title": "Camera & selection",
			"help_lines": ["Click a map position to move your view.", "Units: search, then Enter to focus.",
				"Use the observer controls to follow the action." if observer else "Right-click terrain to move a selected unit."]})
	queue_redraw()


func _draw() -> void:
	if hud == null or hud.minimap_panel == null:
		return
	var map_rect := hud.minimap_panel.get_rect()
	UiDeckSurface.paint(self, Rect2(Vector2(map_rect.position.x - 8, hud.task_bar.position.y - 8), Vector2(map_rect.size.x + 16, map_rect.end.y - hud.task_bar.position.y + 16)), true)
	if hud.top:
		var tw := HudTopInfo.OBS_W if hud.world.local_team < 0 else hud.top.size.x
		UiDeckSurface.paint(self, Rect2(hud.top.position - Vector2(8, 8), Vector2(tw + 16, hud.top.content_h + 10)))
	if hud.obs_bar.visible:
		UiDeckSurface.paint(self, hud.obs_bar.get_rect().grow(4))
	if hud.drawer_frame.visible:
		UiDeckSurface.paint(self, hud.drawer_frame.get_rect().grow(4), true)
		var r := hud.drawer_frame.get_rect()
		draw_line(r.position + Vector2(12, 36 if r.size.y < 320 else 60), Vector2(r.end.x - 12, r.position.y + (36 if r.size.y < 320 else 60)), UiKit.LINE)
	if hud.layers_ui.visible:
		UiDeckSurface.paint(self, hud.layers_ui.get_rect().grow(4))
	if hud.events_toggle.visible:
		UiDeckSurface.paint(self, hud.events_toggle.get_rect().grow(4))
		if hud.log_panel.visible:
			UiDeckSurface.paint(self, hud.log_panel.get_rect())
		elif hud.toasts.visible and not hud.toasts.items.is_empty():
			UiDeckSurface.paint(self, hud.toasts.get_rect().grow(6))
	if hud.sel_panel.visible:
		UiDeckSurface.paint(self, hud.sel_panel.get_rect(), true)
