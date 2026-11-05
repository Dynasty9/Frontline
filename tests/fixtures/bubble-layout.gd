extends Node

func _ready() -> void:
	var overlay := HudOverlay.new()
	for text in ["", "Move up!", "Six: assault that building. Keep moving toward D8."]:
		for size in [11, 12, 18]:
			for weight in [400, 600]:
				for width in [80.0, 170.0, 220.0]:
					var expected := MapSymbols.wrap(text, size, weight, width)
					var actual := overlay._bubble_layout(text, size, weight, width)
					assert(actual[0] == expected, "Cached wrapping must distinguish text, size, weight and width")
					var longest := 0.0
					for line: String in expected:
						longest = maxf(longest, UiKit.text_width(line, size, weight))
					assert(actual[1] == longest)
					assert(overlay._bubble_layout(text, size, weight, width) == actual)
	for i in 300:
		overlay._bubble_layout("Order %d" % i, 12, 600, 170.0)
		assert(overlay._bubble_layouts.size() <= 256, "Long matches must not retain every unique radio order")
	var restored := overlay._bubble_layout("Move up!", 12, 600, 170.0)
	assert(restored[0] == ["Move up!"] and restored[1] == UiKit.text_width("Move up!", 12, 600))
	overlay.free()
	print("BUBBLE_LAYOUT passed")
	get_tree().quit()
