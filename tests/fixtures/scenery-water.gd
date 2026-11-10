extends Node

func _ready() -> void:
	for metres in [1024, 2048, 3072]:
		MapDims.configure(metres)
		var inner := ceili((MapDims.HALF + 132.0) * 2.0 / WaterView.TILE) * WaterView.TILE * 0.5
		var outer := MapDims.HALF + 2400.0
		var shore := MapDims.HALF - 100.0
		var rects := WaterView.sea_surround_rects(inner, outer, shore)
		assert(rects.size() == 3)
		var detailed := Rect2(-inner, -inner, inner * 2.0, inner * 2.0)
		for i in rects.size():
			assert(not rects[i].intersects(detailed), "Distant sea must not double-draw detailed waves")
			for j in range(i + 1, rects.size()):
				assert(not rects[i].intersects(rects[j]), "Distant patches meet without overlapping")
		for z in range(-int(outer) + 1, int(outer), 47):
			for x in range(int(shore) + 1, int(outer), 47):
				var p := Vector2(x, z)
				var covered := detailed.has_point(p)
				for r in rects:
					covered = covered or r.has_point(p)
				assert(covered, "The sea must cover the backdrop without gaps")
		assert(WaterView.sea_surround_rects(inner, outer, 1e9).is_empty(), "Inland maps have no distant ocean")
	MapDims.configure(1024)
	print("SCENERY_WATER passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
