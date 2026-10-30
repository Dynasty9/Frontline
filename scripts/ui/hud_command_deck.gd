extends Control
## Shared ink surfaces group controls without framing the whole battlefield.
var hud: Hud
var idle_panel: UiDeckEmptyState
var _idle_team := -99


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	idle_panel = UiDeckEmptyState.new()
	idle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(idle_panel)


func refresh() -> void:
	var left := hud.minimap_right() + 8.0
	var available := maxf(240, size.x - left - 14)
	idle_panel.position = Vector2(left, size.y - 90.0 - (hud.obs_bar.size.y + 8.0 if hud.obs_bar.visible and hud._obs_low else 0.0))
	idle_panel.size = Vector2(minf(440, available), 76)
	idle_panel.visible = not hud.sel_panel.visible and not hud.card_panel.visible
	if _idle_team != hud.world.local_team:
		_idle_team = hud.world.local_team
		var observer := _idle_team < 0
		idle_panel.configure({
			"surface": false,
			"eyebrow": "Observer" if observer else "Command",
			"title": "Select a unit to inspect" if observer else "Select a unit to command",
			"body": "Units to search · Enter to focus" if observer else "Units to search · Right-click to move"})
	queue_redraw()


func _draw() -> void:
	if hud == null or hud.minimap_panel == null:
		return
	var map_rect := hud.minimap_panel.get_rect()
	UiDeckSurface.paint(self, Rect2(Vector2(map_rect.position.x - 8, hud.task_bar.position.y - 8), Vector2(map_rect.size.x + 16, map_rect.end.y - hud.task_bar.position.y + 16)), true)
	UiMapGridFrame.paint(self, Rect2(hud.minimap_panel.position + hud.minimap.position, hud.minimap.size), MapDims.GRID, bool(Settings.get_v("minimap_rotate")))
	if hud.drawer_frame.visible:
		UiDeckSurface.paint(self, hud.drawer_frame.get_rect().grow(4), true)
		var r := hud.drawer_frame.get_rect()
		draw_line(r.position + Vector2(12, 36 if r.size.y < 320 else 60), Vector2(r.end.x - 12, r.position.y + (36 if r.size.y < 320 else 60)), UiKit.LINE)
	if hud.layers_ui.visible:
		UiDeckSurface.paint(self, hud.layers_ui.get_rect().grow(4))
	if hud.events_toggle.visible:
		if hud.log_panel.visible:
			UiDeckSurface.paint(self, hud.log_panel.get_rect())
	if hud.sel_panel.visible:
		UiDeckSurface.paint(self, hud.sel_panel.get_rect(), true)
