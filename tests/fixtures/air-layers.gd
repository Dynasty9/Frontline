extends Node
## The weather grid without a battle: sized from MapDims, mist pooling in the
## hollows and along the water, rain in bands, a blast's smoke and dust (and
## none of the dust off wet ground), everything drifting downwind as a whole
## and thinning away, close-up smoke plumes merging and clearing, and the air
## layers' shaders carrying what they need.


## A stand-in for the World the grid reads: a valley running north-south
## west of the middle, a pond in it, nothing burning or driving.
class FakeWorld:
	extends RefCounted
	var water = null
	var fx = null
	var smoke_projectiles: Array = []
	var vehicles: Array = []

	func ground_y(p: Vector3) -> float:
		return -20.0 if absf(p.x + 200.0) < 60.0 else 0.0


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	_check_size()
	_check_hollows()
	_check_rain()
	_check_blast()
	_check_drift()
	_check_plumes()
	_check_shaders()
	MapDims.configure(1024)
	print("AIR LAYERS passed: size, hollows, rain bands, blasts, drift, plumes, shaders")
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
	pl.queue_free()


func _check_shaders() -> void:
	var air := MapDims.shader(AirLayers.AIR_SHADER.replace("// CLOUD_SHADOW", CloudShadow.PATTERN))
	assert(air.begins_with("\nshader_type fog;") and air.contains("float terrain_height(") and air.contains("float cloud_sun("), "the air's fog shader has its helpers")
	assert(not air.contains("__MAP_"), "the map's size is filled in")
	assert(SmokePlumes.SHADER.contains("shader_type fog;") and SmokePlumes.SHADER.contains("UVW"), "the plumes' fog shader")
	var c := MapDims.shader(Caustics.SHADER)
	assert(c.contains("hint_depth_texture") and c.contains("NDC_Z") and not c.contains("__MAP_"), "the thrown-back caustics read depth both renderers' way")
	for wq in 4:
		var w := WaterView.WATER_SHADER.replace("__WQ__", str(wq))
		assert(w.contains("vec3 caustics(vec2 p, float soft)"), "the water's bed caustics")
