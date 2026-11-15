extends Node
## Falling rain and lightning, without a battle: every surface that stands in
## the rain takes the drops, the Effects setting decides how much of them is
## drawn, a strike grows a forked channel down to the ground and flickers out,
## and its thunder arrives as late as the channel is far.


func _ready() -> void:
	TestRun.watch()
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_shaders()
	_check_settings()
	_check_strike()
	_check_in_cloud()
	print("RAIN EFFECTS passed: shaders, settings, strike, thunder, flash in the cloud")
	get_tree().quit()


## The ground, the roads and every shared surface carry the drops.
func _check_shaders() -> void:
	for src: String in [Atmosphere.GROUND_SHADER, Atmosphere.ROAD_SHADER, Mats.SURFACE_SHADER]:
		assert(src.contains("// RAIN_DROPS"), "a shader that stands in the rain takes no drops")
	assert(Atmosphere.GROUND_SHADER.contains("rain_rings(") and Atmosphere.ROAD_SHADER.contains("rain_rings("), "puddles take no rings")
	assert(Mats.SURFACE_SHADER.contains("rain_crowns(") and Mats.SURFACE_SHADER.contains("rain_rivulets("), "surfaces take no drops or rivulets")
	var code: String = Mats.shader().code
	assert(code.contains("global uniform vec4 rain_fx") and not code.contains("// RAIN_DROPS"), "the surfaces' shader is built without the drops")
	assert(ProjectSettings.has_setting("shader_globals/rain_fx"), "the rain_fx global isn't declared")


## Low draws none of it; Medium the rings and crowns; High the rest too. The
## browser's per-vertex ground can't show a ring's slope, so it has crowns only.
func _check_settings() -> void:
	assert(Atmosphere.rain_fx_for(1.0, 0, false, 3.0) == Vector4(0, 0, 0, 3), "Effects Low draws falling rain")
	assert(Atmosphere.rain_fx_for(1.0, 1, false, 3.0) == Vector4(1, 1, 0, 3), "Effects Medium: rings and crowns")
	assert(Atmosphere.rain_fx_for(1.0, 2, false, 3.0) == Vector4(1, 1, 1, 3), "Effects High: everything")
	assert(Atmosphere.rain_fx_for(1.0, 2, true, 3.0) == Vector4(0, 1, 1, 3), "per-vertex ground: no rings")
	assert(Atmosphere.rain_fx_for(0.5, 2, false, 3.0).x == 0.5, "the drops ease in and out with the rain")


func _check_strike() -> void:
	seed(7)
	var l := Lightning.new(null)
	add_child(l)
	var eye := Vector3(0, 30, 0)
	var at := Vector3(300, 0, -600)
	l.strike_seen_from(eye, at)
	var mesh := l._bolt.mesh as ArrayMesh
	assert(mesh != null and l._bolt.visible, "a strike draws no bolt")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(verts.size() > 200, "the channel is too plain: %d vertices" % verts.size())
	var low := INF
	var high := -INF
	for v in verts:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	assert(low <= 0.5 and high >= 400.0, "the channel doesn't run from the cloud base (%.0f m) to the ground (%.0f m)" % [high, low])
	# the leader takes a frame to come down, then the strokes flicker it out
	l.tick(0.02)
	assert(l.flash == 0.0, "the bolt flashes before the leader is down")
	var peak := 0.0
	var dips := 0
	var last := 0.0
	var t := 0.02
	var heard := false
	while t < 8.0:
		l.tick(1.0 / 60.0)
		t += 1.0 / 60.0
		peak = maxf(peak, l.flash)
		if l.flash < last - 0.05:
			dips += 1
		last = l.flash
		if l.last_thunder.x >= 0.0 and not heard:
			heard = true
			# thunder comes as late as the nearest of the channel is far
			assert(absf(l.last_thunder.x - l.last_thunder.y / Lightning.SOUND_SPEED) < 0.02,
				"thunder from %.0f m came after %.2f s" % [l.last_thunder.y, l.last_thunder.x])
			assert(l.last_thunder.y > 450.0 and l.last_thunder.y < at.distance_to(eye) + 5.0,
				"the nearest of a strike %.0f m off was %.0f m away" % [at.distance_to(eye), l.last_thunder.y])
	assert(peak > 0.8, "the strike barely flashed (%.2f)" % peak)
	assert(dips >= 1, "the bolt flashes once and never flickers")
	assert(heard, "no thunder")
	assert(l.flash == 0.0 and not l._bolt.visible and l._bolt.mesh == null, "the bolt lingers")
	assert(l.flash_near > 0.6 and l.flash_near <= 1.0, "a strike 670 m off doesn't light the field (%.2f)" % l.flash_near)
	l.free()


## A flash in the cloud: a dimmer crawler along the cloud base, never down to the ground.
func _check_in_cloud() -> void:
	seed(11)
	var l := Lightning.new(null)
	add_child(l)
	l.strike_seen_from(Vector3.ZERO, Vector3(0, 0, -1800), true)
	var verts: PackedVector3Array = (l._bolt.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := INF
	for v in verts:
		low = minf(low, v.y)
	assert(low > 150.0, "a flash in the cloud reached down to %.0f m" % low)
	var peak := 0.0
	for i in 40:
		l.tick(1.0 / 60.0)
		peak = maxf(peak, l.flash)
	assert(peak > 0.1 and peak < 0.5, "a flash in the cloud is as bright as a strike (%.2f)" % peak)
	l.free()
