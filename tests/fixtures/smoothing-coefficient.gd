extends Node
func _ready() -> void:
	var main = load("res://scripts/main.gd").new()
	var empty: Array[float] = []
	var single: Array[float] = [16.0]
	var steady: Array[float] = [16.0, 16.0]
	assert(main._frame_change_report(empty) == {"count": 0})
	assert(main._frame_change_report(single) == {"count": 0})
	var samples: Array[float] = [10.0, 30.0, 10.0, 30.0]
	var changes: Dictionary = main._frame_change_report(samples)
	assert(changes.count == 3 and changes.p50_ms == 20.0 and changes.max_ms == 20.0)
	assert(samples == [10.0, 30.0, 10.0, 30.0], "Reporting must preserve frame order")
	assert(main._frame_change_report(steady).max_ms == 0.0)
	main.free()
	var normal := Entity.new()
	var shared := Entity.new()
	for entity in [normal, shared]:
		entity.net_init = true
		entity.rotation.y = PI - 0.1
	for dt in [0.0, 0.016, 0.033, 0.008, 0.1]:
		for target in [Vector3(1, 2, 3), Vector3(10, 0, 20), Vector3.ZERO]:
			for entity in [normal, shared]:
				entity.net_pos = target
				entity.net_yaw = -PI + 0.1
			normal.net_smooth(dt)
			shared.net_smooth(dt, 1.0 - exp(-dt * 14.0))
			assert(normal.transform.is_equal_approx(shared.transform), "Shared smoothing must preserve motion and angle wrapping")
	normal.free()
	shared.free()
	print("SMOOTHING_COEFFICIENT passed")
	get_tree().quit()
