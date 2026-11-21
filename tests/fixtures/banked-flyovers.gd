extends "res://scripts/main.gd"

var planes: Array = []
var maxima := [0.0, 0.0]
var closest := [INF, INF]
var start_time := 0.0
var last_climb := [INF, INF]
var climb_jump := [0.0, 0.0]


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
		# the flight path's climb angle never jumps from one frame to the next
		var climb: float = asin(clampf(p.vel.normalized().y, -1.0, 1.0))
		if last_climb[i] != INF:
			climb_jump[i] = maxf(climb_jump[i], absf(climb - last_climb[i]))
		last_climb[i] = climb
	if world.time - start_time < 6.5:
		return
	set_process(false)
	print("BANKED_FLYOVERS swing-in %.1f / %.1f m, closest to the line %.2f / %.2f m, biggest climb change %.3f / %.3f rad a frame" % [maxima[0], maxima[1], closest[0], closest[1], climb_jump[0], climb_jump[1]])
	assert(maxima[0] > 8.0 and maxima[1] > 8.0 and closest[0] < 2.0 and closest[1] < 2.0, "both aircraft bend onto the centre line")
	assert(climb_jump[0] < 0.05 and climb_jump[1] < 0.05, "the pull-up has a continuous pitch")
	print("BANKED_FLYOVERS passed")
	get_tree().quit()
