extends "res://scripts/main.gd"

var planes: Array = []
var maxima := [0.0, 0.0]
var closest := [INF, INF]
var start_time := 0.0


func _process(dt: float) -> void:
	super._process(dt)
	if not world or not world.rules or world.time < 0.05:
		return
	if planes.is_empty():
		for kind in ["jet", "a10"]:
			planes.append(world.spawn("projectile", {"ptype": kind, "pos": Vector3(-190, 60, 330), "target": Vector3(-190, 0, 0), "vel": Vector3.FORWARD * 75.0, "fuse": 0}))
		start_time = world.time
	for i in planes.size():
		var p = planes[i]
		if p.gone:
			continue
		var delta: Vector3 = p.position - p.target
		maxima[i] = maxf(maxima[i], absf(delta.x))
		if absf(delta.z) < 60.0:
			closest[i] = minf(closest[i], absf(delta.x))
	if world.time - start_time < 6.5:
		return
	set_process(false)
	assert(maxima[0] > 8.0 and maxima[1] > 8.0 and closest[0] < 0.05 and closest[1] < 0.05, "both aircraft bend onto the centre line")
	var slope_before: float = planes[1].a10_alt(0.0) - planes[1].a10_alt(-1.0)
	var slope_after: float = planes[1].a10_alt(1.0) - planes[1].a10_alt(0.0)
	assert(absf(slope_before - slope_after) < 0.01, "the pull-up has a continuous pitch")
	print("BANKED_FLYOVERS passed")
	get_tree().quit()
