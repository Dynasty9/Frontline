class_name UiDeckEmptyState
extends Control
## Empty selection, empty search or onboarding text in the same visual language.
var surface := true
var eyebrow := ""
var title := ""
var body := ""
var code := ""
var help_title := ""
var help_lines: PackedStringArray = []


func _init() -> void:
	custom_minimum_size.y = 76
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(data: Dictionary) -> void:
	surface = data.get("surface", true)
	eyebrow = data.get("eyebrow", "")
	title = data.get("title", "")
	body = data.get("body", "")
	code = data.get("code", "")
	help_title = data.get("help_title", "")
	help_lines = PackedStringArray(data.get("help_lines", []))
	custom_minimum_size.y = 120 if not code.is_empty() or not help_lines.is_empty() else 76
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if surface:
		UiDeckSurface.paint(self, r)
	UiKit.caps_at(self, r.position + Vector2(16, 18), eyebrow, 11, UiKit.ACCENT)
	UiKit.caps_at(self, r.position + Vector2(16, 40), title, 17, UiKit.TEXT)
	UiKit.text(self, r.position + Vector2(16, 62), body, 12, UiKit.DIM)
	if size.y >= 100:
		UiKit.mono_at(self, r.position + Vector2(16, 86), code, 10, UiKit.FAINT)
	if r.size.x > 580 and help_lines.size() >= 3:
		var x := r.position.x + r.size.x * 0.47
		draw_line(Vector2(x - 20, r.position.y + 20), Vector2(x - 20, r.end.y - 20), UiKit.LINE)
		UiKit.caps_at(self, Vector2(x, r.position.y + 28), help_title, 11, UiKit.DIM)
		UiKit.text(self, Vector2(x, r.position.y + 52), help_lines[0], 12, UiKit.TEXT)
		UiKit.text(self, Vector2(x, r.position.y + 74), help_lines[1], 12, UiKit.TEXT)
		UiKit.text(self, Vector2(x, r.position.y + 96), help_lines[2], 12, UiKit.DIM)
