extends Control
## The commander's instruments have a stable, opaque home; the scene stays open.
var hud: Hud
var idle_panel: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	idle_panel = Control.new()
	idle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(idle_panel)


func refresh() -> void:
	var left := hud.minimap_right() + 8.0
	idle_panel.position = Vector2(left, size.y - 134.0 - (hud.obs_bar.size.y + 8.0 if hud.obs_bar.visible and hud._obs_low else 0.0))
	idle_panel.size = Vector2(maxf(240, size.x - left - 14), 120)
	idle_panel.visible = not hud.sel_panel.visible and not hud.card_panel.visible
	queue_redraw()


func _frame(r: Rect2, accent := false) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var cut := 8.0
	var p := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, cut), r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])
	var high := UiKit.fa(UiKit.INK.lightened(0.08), 0.97)
	var low := UiKit.fa(UiKit.INK, 0.98)
	draw_polygon(p, PackedColorArray([high, high, low, low, low, high]))
	var outline := p.duplicate()
	outline.append(p[0])
	draw_polyline(outline, UiKit.RULE2, 1.0, true)
	draw_line(r.position + Vector2(cut, 2), Vector2(r.end.x - 2, r.position.y + 2), UiKit.fa(UiKit.TEXT, 0.09))
	draw_rect(Rect2(r.position + Vector2(12, 0), Vector2(42, 2)), UiKit.ACCENT if accent else UiKit.RULE2)


func _draw() -> void:
	if hud == null or hud.minimap_panel == null:
		return
	var map_rect := hud.minimap_panel.get_rect()
	_frame(Rect2(Vector2(map_rect.position.x - 8, hud.task_bar.position.y - 8), Vector2(map_rect.size.x + 16, map_rect.end.y - hud.task_bar.position.y + 16)), true)
	if hud.top:
		var tw := HudTopInfo.OBS_W if hud.world.local_team < 0 else hud.top.size.x
		_frame(Rect2(hud.top.position - Vector2(8, 8), Vector2(tw + 16, hud.top.content_h + 10)))
	if hud.obs_bar.visible:
		_frame(hud.obs_bar.get_rect().grow(4))
	if hud.drawer_frame.visible:
		_frame(hud.drawer_frame.get_rect().grow(4), true)
		var r := hud.drawer_frame.get_rect()
		draw_line(r.position + Vector2(12, 36 if r.size.y < 320 else 60), Vector2(r.end.x - 12, r.position.y + (36 if r.size.y < 320 else 60)), UiKit.LINE)
	if hud.layers_ui.visible:
		_frame(hud.layers_ui.get_rect().grow(4))
	if hud.events_toggle.visible:
		_frame(hud.events_toggle.get_rect().grow(4))
		if hud.log_panel.visible:
			_frame(hud.log_panel.get_rect())
		elif hud.toasts.visible and not hud.toasts.items.is_empty():
			_frame(hud.toasts.get_rect().grow(6))
	if hud.sel_panel.visible:
		_frame(hud.sel_panel.get_rect(), true)
	if hud.card_panel.visible:
		_frame(hud.card_panel.get_rect(), true)
	if idle_panel and idle_panel.visible:
		var r := idle_panel.get_rect()
		_frame(r, true)
		var observer := hud.world.local_team < 0
		UiKit.caps_at(self, r.position + Vector2(20, 25), "Battle overview" if observer else "Tactical command", 11, UiKit.ACCENT)
		UiKit.caps_at(self, r.position + Vector2(20, 52), "Observer" if observer else Defs.TEAM_NAMES[hud.world.local_team] + " command", 22, UiKit.TEXT)
		UiKit.text(self, r.position + Vector2(20, 76), "Select a unit to inspect." if observer else "Select a unit to issue orders.", 13, UiKit.DIM)
		UiKit.mono_at(self, r.position + Vector2(20, 101), "NO UNIT SELECTED", 10, UiKit.FAINT)
		if r.size.x > 580:
			var x := r.position.x + r.size.x * 0.47
			draw_line(Vector2(x - 20, r.position.y + 20), Vector2(x - 20, r.end.y - 20), UiKit.LINE)
			UiKit.caps_at(self, Vector2(x, r.position.y + 28), "Camera & selection", 11, UiKit.DIM)
			UiKit.text(self, Vector2(x, r.position.y + 52), "Click a map position to move your view.", 12, UiKit.TEXT)
			UiKit.text(self, Vector2(x, r.position.y + 74), "Units: search, then Enter to focus.", 12, UiKit.TEXT)
			UiKit.text(self, Vector2(x, r.position.y + 96), "Right-click terrain to move a selected unit." if not observer else "Use the observer controls to follow the action.", 12, UiKit.DIM)
