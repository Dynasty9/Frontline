extends Node
## The weather grid without a battle: sized from MapDims, mist pooling in the
## hollows and along the water, rain in bands, a blast's smoke and dust (and
## none of the dust off wet ground), everything drifting downwind as a whole
## and thinning away, close-up smoke plumes merging and clearing, vehicles'
## dust by the ground they drive on and the trails it leaves, headlights after
## dark, the far rain's curtains, and the air layers' shaders carrying what
## they need.


## A stand-in for the World the grid reads: a valley running north-south
## west of the middle, a pond in it, nothing burning or driving.
class FakeWorld:
	extends RefCounted
	var water = null
	var fx = null
	var smoke_projectiles: Array = []
	var vehicles: Array = []
	var terrain = null
	var atmo = null
	var cam = null
	var town_rect := Rect2(200, -100, 100, 200)

	func ground_y(p: Vector3) -> float:
		return -20.0 if absf(p.x + 200.0) < 60.0 else 0.0


## Ground for the dust: a dirt road down x = 0 (paved through the town at
## x 200..300), mud west of x = -100, thick grass everywhere else.
class FakeTerrain:
	extends RefCounted

	func kind_at(p: Vector3) -> int:
		if absf(p.x) < 4.0 or (p.x > 200.0 and p.x < 300.0):
			return TerrainMap.ROAD
		return TerrainMap.MUD if p.x < -100.0 else TerrainMap.GROUND


class FakeAtmo:
	extends RefCounted
	var biome_img := Image.create(1, 1, false, Image.FORMAT_R8)
	var _d := {"fog": Color(0.6, 0.62, 0.66)}

	func grass_amount(_p: Vector3) -> float:
		return 1.0


class FakeVehicle:
	extends Node3D
	var eid := 0
	var vdef := {}

	func is_air() -> bool:
		return false

	func is_boat() -> bool:
		return false

	func weight() -> int:
		return 1

	func health_frac() -> float:
		return 1.0


class FakeCam:
	extends RefCounted
	var cam: Camera3D


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	_check_size()
	_check_hollows()
	_check_rain()
	_check_blast()
	_check_drift()
	_check_plumes()
	_check_vehicle_dust()
	_check_trails()
	_check_headlights()
	_check_curtains()
	_check_shaders()
	MapDims.configure(1024)
	print("AIR LAYERS passed: size, hollows, rain bands, blasts, drift, plumes, vehicle dust, trails, headlights, rain curtains, shaders")
	get_tree().quit()


func _grid(mood: String) -> WeatherGrid:
	var g := WeatherGrid.new(FakeWorld.new())
	g.mood = mood
	g.survey()
	return g


func _check_size() -> void:
	for m in [[1024, 32], [2048, 64], [3072, 64]]:
		MapDims.configure(m[0])
		var g := WeatherGrid.new(FakeWorld.new())
		assert(g.n == m[1], "a %d m map gets %d cells across, not %d" % [m[0], m[1], g.n])
		assert(is_equal_approx(g.n * g.cell, MapDims.SIZE), "the grid covers the map")
		assert(g.tex.get_width() == g.n, "its texture is a pixel a cell")
	MapDims.configure(1024)


## At dawn the mist lies thick in the valley and thin on the open ground.
func _check_hollows() -> void:
	var g := _grid("dawn")
	var valley := g.sample(Vector3(-200, 0, 0)).x
	var open := g.sample(Vector3(300, 0, 0)).x
	assert(valley > 0.4 and open < 0.3 and valley > open * 2.0, "dawn mist: valley %.2f, open ground %.2f" % [valley, open])
	var day := _grid("day")
	assert(day.sample(Vector3(-200, 0, 0)).x < valley * 0.3, "a clear day has far less mist")


## Rain comes over in heavier and lighter bands; none on a dry day.
func _check_rain() -> void:
	var g := _grid("rain")
	var lo := 9.0
	var hi := 0.0
	for i in 40:
		var r := g.sample(Vector3(-480 + i * 24, 0, -100 + i * 5)).y
		lo = minf(lo, r)
		hi = maxf(hi, r)
	assert(lo > 0.2 and hi - lo > 0.2, "rain bands from %.2f to %.2f" % [lo, hi])
	assert(_grid("golden").totals().y == 0.0, "no rain without the rain")


## A shell on dry ground leaves smoke and dust; in the water, smoke and spray.
func _check_blast() -> void:
	var g := _grid("day")
	var p := Vector3(100, 0, 100)
	var before := g.sample(p)
	g.blast(p, 2.0, false, 0.0)
	var after := g.sample(p)
	assert(after.w > before.w + 0.1 and after.z > before.z + 0.05, "a blast's smoke %.2f and dust %.2f" % [after.w, after.z])
	var g2 := _grid("day")
	g2.blast(p, 2.0, true, 0.0)
	var wet := g2.sample(p)
	assert(wet.z <= before.z + 0.001 and wet.x > before.x, "in the water it throws up spray, not dust")
	# soaked ground hardly dusts at all
	var g3 := _grid("day")
	g3.wet = 1.0
	g3.blast(p, 2.0, false, 0.0)
	assert(g3.sample(p).z - before.z < (after.z - before.z) * 0.4, "wet ground throws up little dust")


## The pall drifts off downwind as a whole and thins away.
func _check_drift() -> void:
	var g := _grid("day")
	var p := Vector3(0, 0, 0)
	g.blast(p, 2.5, false, 0.0)
	var start := g.sample(p).w
	var wind := Vector3(Fires.WIND.x, 0, Fires.WIND.z).normalized()
	var t := 60.0
	for i in int(t * 10.0):
		g.tick(0.1)
	var downwind := p + wind * WeatherGrid.DRIFT * t
	var there := g.sample(downwind).w
	var left := g.sample(p).w
	assert(there > left * 2.0, "after a minute the smoke is downwind (%.3f) not where it was (%.3f)" % [there, left])
	assert(there < start * 0.8, "and thinner (%.3f, from %.3f)" % [there, start])
	assert(g.drift.x >= 0.0 and g.drift.x < g.cell and g.drift.y >= 0.0 and g.drift.y < g.cell, "the drift stays under a cell")


## Shells falling close together feed one plume; one far off starts another;
## a grenade starts none; they clear once they've thinned away.
func _check_plumes() -> void:
	var pl := SmokePlumes.new()
	add_child(pl)
	pl.setup(FakeWorld.new(), NoiseTexture3D.new())
	pl.blast(Vector3(100, 0, 100), 2.0)
	pl.blast(Vector3(108, 0, 104), 2.0)
	assert(pl.count() == 1, "two shells close together make one plume, not %d" % pl.count())
	pl.blast(Vector3(-200, 0, 50), 2.0)
	pl.blast(Vector3(0, 0, 0), 0.5)
	assert(pl.count() == 2, "one far off starts another, a grenade none (%d)" % pl.count())
	for i in SmokePlumes.PLUMES + 4:
		pl.blast(Vector3(-480 + i * 40, 0, -300), 2.0)
	assert(pl.count() == SmokePlumes.PLUMES, "never more than %d" % SmokePlumes.PLUMES)
	for i in 80:
		pl.tick(1.0, true)
	assert(pl.count() == 0, "they clear once they've thinned away (%d left)" % pl.count())
	# a fire's plume stands as long as it burns (each look pushes its life on),
	# and a burst close by flashes it
	var fire: Array = pl._start(Vector3(50, 0, 50), 1.5, 8.0, 0.4, true)
	fire[8] = 0.8
	for i in 40:
		fire[5] = float(fire[4]) + 6.0
		pl.tick(1.0, true)
	var m: ShaderMaterial = fire[1]
	assert(float(m.get_shader_parameter("density")) > 0.1, "a fire's plume hasn't faded while it burns (%s)" % m.get_shader_parameter("density"))
	pl.blast(Vector3(60, 0, 52), 1.0)
	pl.tick(1.0 / 30.0, true)
	assert(float(m.get_shader_parameter("flash")) > 0.1, "a burst close by flashes the pall")
	for i in 10:
		pl.tick(1.0 / 30.0, true)
	assert(float(m.get_shader_parameter("flash")) == 0.0, "for a moment only")
	pl.queue_free()


## A vehicle driving down a dry dirt road raises dust (and the trails are told
## of it); a paved street far less; none off the mud or thick grass, none in
## the rain, none parked.
func _check_vehicle_dust() -> void:
	var dirt := 0.0
	for case in [[Vector3(0, 0, 0), "day", 1.0], [Vector3(250, 0, 0), "day", 0.5], [Vector3(-200, 0, 0), "day", 0.0], [Vector3(60, 0, 0), "day", 0.0], [Vector3(0, 0, 0), "rain", 0.0]]:
		var w := FakeWorld.new()
		w.terrain = FakeTerrain.new()
		w.atmo = FakeAtmo.new()
		var g := WeatherGrid.new(w)
		g.mood = case[1]
		g.survey()
		var v := FakeVehicle.new()
		v.eid = 7
		v.position = case[0]
		w.vehicles = [v]
		var before := g.totals().z
		for i in 10:
			v.position += Vector3(0, 0, -6)  # (12 m/s)
			g._sources(0.5)
		var raised := g.totals().z - before
		var want := float(case[2])
		if want >= 1.0:
			assert(raised > 0.0003 and not g.vehicle_dust.is_empty(), "a vehicle on a dirt road raises dust (%.4f)" % raised)
			dirt = raised
		elif want > 0.0:
			assert(raised > 0.0 and raised < dirt * 0.4, "a paved street far less (%.4f, dirt %.4f)" % [raised, dirt])
		else:
			assert(raised < 0.0001 and g.vehicle_dust.is_empty(), "none at %s in %s (%.4f)" % [case[0], case[1], raised])
		v.free()
	var w2 := FakeWorld.new()
	w2.terrain = FakeTerrain.new()
	var g2 := WeatherGrid.new(w2)
	g2.mood = "day"
	var v2 := FakeVehicle.new()
	w2.vehicles = [v2]
	for i in 4:
		g2._sources(0.5)
	assert(g2.vehicle_dust.is_empty(), "a parked vehicle raises none")
	v2.free()


## A vehicle lays a trail along its route in stretches; one behind it on the
## same road thickens that trail rather than starting more; it settles away.
func _check_trails() -> void:
	var tr := DustTrails.new()
	add_child(tr)
	tr.setup(FakeWorld.new(), NoiseTexture3D.new())
	var lead := Vector3(0, 0, 100)
	for i in 20:
		tr.feed([[lead + Vector3(0, 0, -6), lead, 1.0]])
		lead += Vector3(0, 0, -6)
		tr.tick(0.5, true)
	var laid := tr.count()
	assert(laid >= 3 and laid <= 5, "120 m of road in a few stretches (%d)" % laid)
	var back := Vector3(0, 0, 100)
	for i in 20:
		tr.feed([[back + Vector3(0, 0, -6), back, 1.0]])
		back += Vector3(0, 0, -6)
		tr.tick(0.5, true)
	assert(tr.count() == laid, "the next along the same road thickens the trail (%d, was %d)" % [tr.count(), laid])
	for i in 50:
		tr.tick(1.0, true)
	assert(tr.count() == 0, "it settles away (%d left)" % tr.count())
	tr.queue_free()


## After dark the vehicles on the move near the camera get headlights; a
## parked one, or any by day, none.
func _check_headlights() -> void:
	var w := FakeWorld.new()
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 20, 40)
	w.cam = FakeCam.new()
	w.cam.cam = cam
	var moving := FakeVehicle.new()
	moving.eid = 1
	var parked := FakeVehicle.new()
	parked.eid = 2
	parked.position = Vector3(10, 0, 0)
	add_child(moving)
	add_child(parked)
	w.vehicles = [moving, parked]
	var hl := Headlights.new()
	add_child(hl)
	hl.setup(w)
	hl.level = 1.0
	for i in 8:
		moving.position += Vector3(0, 0, -2)
		hl._process(0.25)
	assert(hl._on.count(moving) == 1 and hl._on.count(parked) == 0, "the one driving has its lights on, the parked one not")
	var lit := hl._lights[hl._on.find(moving)]
	assert(lit.visible and lit.light_energy > 0.0 and lit.light_volumetric_fog_energy > 0.0, "a beam that shows in the air")
	assert(lit.global_position.z < moving.position.z, "on its front")
	hl.level = 0.0
	hl._process(0.3)
	assert(hl._on.count(null) == Headlights.SLOTS, "none by day")
	for n in [hl, moving, parked, cam]:
		n.queue_free()


## Under rain the far showers hang as curtains: several round about, none close
## to the camera; none when it isn't raining.
func _check_curtains() -> void:
	var w := FakeWorld.new()
	w.atmo = FakeAtmo.new()
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 80, 0)
	w.cam = FakeCam.new()
	w.cam.cam = cam
	var rc := RainCurtains.new()
	add_child(rc)
	rc.setup(w, w.atmo)
	rc.level = 1.0
	rc.tick(0.1)
	var shown := 0
	for q in rc._q:
		if q.visible:
			shown += 1
			var d := Vector2(q.global_position.x, q.global_position.z).length()
			assert(d >= RainCurtains.NEAR and d <= RainCurtains.FAR, "a curtain only far off (%.0f m)" % d)
	assert(shown >= 4, "several hang round about (%d)" % shown)
	rc.level = 0.0
	rc.tick(0.1)
	for q in rc._q:
		assert(not q.visible, "none without the rain")
	rc.queue_free()
	cam.queue_free()


func _check_shaders() -> void:
	var air := MapDims.shader(AirLayers.AIR_SHADER.replace("// CLOUD_SHADOW", CloudShadow.PATTERN))
	assert(air.begins_with("\nshader_type fog;") and air.contains("float terrain_height(") and air.contains("float cloud_sun("), "the air's fog shader has its helpers")
	assert(not air.contains("__MAP_"), "the map's size is filled in")
	assert(SmokePlumes.SHADER.contains("shader_type fog;") and SmokePlumes.SHADER.contains("UVW") and SmokePlumes.SHADER.contains("EMISSION"), "the plumes' fog shader, glowing")
	assert(air.contains("low_d") and air.contains("terrain_height(deform_tex, (p.xz + dir * d"), "the low haze and the ridges' shafts")
	assert(DustTrails.SHADER.contains("shader_type fog;") and DustTrails.SHADER.contains("UVW"), "the dust trails' fog shader")
	assert(RainCurtains.SHADER.contains("shader_type spatial;") and not RainCurtains.SHADER.contains("hint_depth_texture"), "the curtains draw the same under both renderers")
	var c := MapDims.shader(Caustics.SHADER)
	assert(c.contains("hint_depth_texture") and c.contains("NDC_Z") and not c.contains("__MAP_"), "the thrown-back caustics read depth both renderers' way")
	for wq in 4:
		var w := WaterView.WATER_SHADER.replace("__WQ__", str(wq))
		assert(w.contains("vec3 caustics(vec2 p, float soft)"), "the water's bed caustics")
