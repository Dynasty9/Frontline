class_name UiDeckEmptyState
extends Control
## Empty selection, empty search or onboarding text in the same visual language.
var eyebrow := ""
var title := ""
var body := ""
var code := ""
var help_title := ""
var help_lines: PackedStringArray = []


func _init() -> void:
	custom_minimum_size.y = 120
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(data: Dictionary) -> void:
	eyebrow = data.get("eyebrow", "")
	title = data.get("title", "")
	body = data.get("body", "")
	code = data.get("code", "")
	help_title = data.get("help_title", "")
	help_lines = PackedStringArray(data.get("help_lines", []))
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	UiDeckSurface.paint(self, r, true)
	UiKit.caps_at(self, r.position + Vector2(20, 25), eyebrow, 11, UiKit.ACCENT)
	UiKit.caps_at(self, r.position + Vector2(20, 52), title, 22, UiKit.TEXT)
	UiKit.text(self, r.position + Vector2(20, 76), body, 13, UiKit.DIM)
	UiKit.mono_at(self, r.position + Vector2(20, 101), code, 10, UiKit.FAINT)
	if r.size.x > 580 and help_lines.size() >= 3:
		var x := r.position.x + r.size.x * 0.47
		draw_line(Vector2(x - 20, r.position.y + 20), Vector2(x - 20, r.end.y - 20), UiKit.LINE)
		UiKit.caps_at(self, Vector2(x, r.position.y + 28), help_title, 11, UiKit.DIM)
		UiKit.text(self, Vector2(x, r.position.y + 52), help_lines[0], 12, UiKit.TEXT)
		UiKit.text(self, Vector2(x, r.position.y + 74), help_lines[1], 12, UiKit.TEXT)
		UiKit.text(self, Vector2(x, r.position.y + 96), help_lines[2], 12, UiKit.DIM)
