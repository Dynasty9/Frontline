extends Node

func _ready() -> void:
	var overlay := HudOverlay.new()
	overlay._groups[7] = {}
	overlay._label_epoch = 1
	var key := Vector2i(7, 0)
	var font := UiKit.cond(600, 1)
	var color := Color(0.8, 0.9, 0.7, 0.6)
	overlay._map_text(key, Vector2(100, 80), "ALPHA", font, 10, color)
	var label: HudOverlay.MapLabel = overlay._map_labels[key]
	var width := font.get_string_size("ALPHA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	assert(label.position == Vector2(100 - width * 0.5, 80))
	assert(label.modulate == color and label.visible and label.show_behind_parent)
	overlay._label_epoch += 1
	overlay._map_text(key, Vector2(120, 90), "ALPHA", font, 10, Color.WHITE)
	assert(overlay._map_labels[key] == label and label.width == width)
	assert(label.position == Vector2(120 - width * 0.5, 90) and label.modulate == Color.WHITE)
	overlay._map_text(key, Vector2.ZERO, "LONGER CALLSIGN", UiKit.mono(400), 15, color)
	assert(label.text == "LONGER CALLSIGN" and label.font_size == 15 and label.face == UiKit.mono(400))
	assert(label.width == label.face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	overlay._finish_map_labels()
	assert(label.visible)
	overlay._label_epoch += 1
	overlay._finish_map_labels()
	assert(not label.visible)
	overlay._groups.clear()
	overlay._finish_map_labels()
	assert(overlay._map_labels.is_empty() and label.is_queued_for_deletion())
	await get_tree().process_frame
	overlay.free()
	print("MAP_LABELS passed")
	get_tree().quit()
