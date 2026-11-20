extends Node
## The cinematic lighting's rules, without a battle: the presets and how saved
## settings take them up, the adaptive shadow fit, which lights get shadows,
## the physical sky's moods, which heat sources the heat haze keeps, how the
## rain soaks things and dries off, how the snow comes and covers everything,
## and what the motion blur asks of the engine. Run windowed, it also checks that the lens, eye, heat and motion
## blur passes compile and run on this graphics card.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_shadow_fit()
	_check_light_picking()
	_check_sky()
	_check_heat_sources()
	_check_heat_pulses()
	_check_detached_fires()
	_check_exhaust_markers()
	_check_rain_wet()
	_check_snow()
	_check_motion_blur()
	if DisplayServer.get_name() != "headless":
		await _check_passes()
	else:
		assert(not CinematicFx.supported())
		assert(not SsgiFx.supported())
	print("CINEMATIC LIGHTING passed: presets, saved settings, shadow fit, light shadows, sky, heat haze, rain, snow, motion blur")
	get_tree().quit()


## A battle that opens in the rain starts soaked; rain setting in wets things
## over WET_IN seconds, and they dry over DRY_OUT once it stops.
func _check_rain_wet() -> void:
	var atmo := Atmosphere.new()
	atmo.mood = "rain"
	atmo._wet_tick(0.1)
	assert(is_equal_approx(atmo.rain_wet, 1.0), "a battle opening in the rain starts soaked")
	atmo.mood = "golden"
	atmo._wet_tick(Atmosphere.DRY_OUT * 0.5)
	assert(is_equal_approx(atmo.rain_wet, 0.5), "half dry after half the drying time")
	atmo._wet_tick(Atmosphere.DRY_OUT)
	assert(atmo.rain_wet == 0.0)
	atmo.mood = "rain"
	atmo._wet_tick(Atmosphere.WET_IN * 0.25)
	assert(is_equal_approx(atmo.rain_wet, 0.25), "rain setting in wets things gradually")
	var fresh := Atmosphere.new()
	fresh.mood = "day"
	fresh._wet_tick(0.1)
	assert(fresh.rain_wet == 0.0, "a dry battle starts dry")
	atmo.free()
	fresh.free()
	RenderingServer.global_shader_parameter_set(&"rain_wet", 0.0)


## Snow is a mood like the others: offered in the settings and photo mode,
## drawn now and then from the seed (a second draw, so no other seed's weather
## changes, and never over rain, which damps fires). A battle that opens in
## snow starts covered; snow setting in settles over SNOW_IN, and it thaws
## over THAW once it stops. Everything standing out in it reads the cover.
func _check_snow() -> void:
	assert(Atmosphere.MOODS.has("snow"))
	assert(SettingsPanel.MOODS.has("snow") and SettingsPanel.MOODS.size() == SettingsPanel.MOOD_NAMES.size())
	assert(PhotoMode.MOODS.has("snow"))
	assert(Curtain.MOOD_TEXT.has("snow"))
	var d: Dictionary = Atmosphere.MOODS.snow
	for k in Atmosphere.MOODS.overcast:
		assert(d.has(k), "the snow mood leaves out %s" % k)
	# flat, cold light: a weak sun and soft shadows under a pale sky
	assert(float(d.energy) < float(Atmosphere.MOODS.overcast.energy) and float(d.soft) >= float(Atmosphere.MOODS.overcast.soft))
	assert((d.zenith as Color).b > (d.zenith as Color).r, "a cold, blue-grey sky")
	assert(Atmosphere.pick_mood({"mood": "snow", "seed": 5}) == "snow")
	var old_bag := ["golden", "golden", "day", "day", "dawn", "dusk", "overcast", "hazy", "night", "rain"]
	var snowy := 0
	for seed in range(1, 801):
		var picked := Atmosphere.pick_mood({"mood": "random", "seed": seed})
		assert(picked == Atmosphere.pick_mood({"mood": "random", "seed": seed}), "the weather comes from the seed")
		var r := RandomNumberGenerator.new()
		r.seed = seed * 7 + 3
		var before: String = old_bag[r.randi() % old_bag.size()]
		if picked == "snow":
			snowy += 1
			assert(before != "rain", "seed %d rained, and snow mustn't take the rain's place" % seed)
		else:
			assert(picked == before, "seed %d's weather changed from %s to %s" % [seed, before, picked])
	assert(snowy > 800 * Atmosphere.SNOW_CHANCE * 0.5 and snowy < 800 * Atmosphere.SNOW_CHANCE * 1.6, "snow came %d times in 800" % snowy)
	# the cover ramps
	var atmo := Atmosphere.new()
	atmo.mood = "snow"
	atmo._snow_tick(0.1)
	assert(is_equal_approx(atmo.snow_cover, 1.0), "a battle opening in snow starts covered")
	atmo.mood = "overcast"
	atmo._snow_tick(Atmosphere.THAW * 0.5)
	assert(is_equal_approx(atmo.snow_cover, 0.5), "half thawed after half the thaw")
	atmo._snow_tick(Atmosphere.THAW)
	assert(atmo.snow_cover == 0.0)
	atmo.mood = "snow"
	atmo._snow_tick(Atmosphere.SNOW_IN * 0.25)
	assert(is_equal_approx(atmo.snow_cover, 0.25), "snow setting in settles gradually")
	assert(Atmosphere.SNOW_IN < Atmosphere.THAW, "snow settles faster than it thaws")
	var fresh := Atmosphere.new()
	fresh.mood = "rain"
	fresh._snow_tick(0.1)
	assert(fresh.snow_cover == 0.0, "no snow lying in the rain")
	atmo.free()
	fresh.free()
	RenderingServer.global_shader_parameter_set(&"snow_cover", 0.0)
	# what stands out in it reads the cover
	for code in [Atmosphere.GROUND_SHADER, Atmosphere.ROAD_SHADER, Mats.SURFACE_SHADER, Mats.FOLIAGE_SHADER, Mats.NETTING_SHADER,
			Grass.GRASS_SHADER, Grass.BUSH_SHADER, DistantForest.SHADER, TrenchNet.BERM_SHADER, Woodland.SHADER]:
		assert(String(code).contains("global uniform float snow_cover;"))
	assert(ProjectSettings.has_setting("shader_globals/snow_cover"), "snow_cover is a project shader global")
	# a floor indoors and a windscreen hold none; a man only a dusting
	assert(float(Mats._preset("floor_tiles").get("snow_hold", 1.0)) == 0.0)
	assert(float(Mats._preset("glass").get("snow_hold", 1.0)) == 0.0)
	assert(float(Mats._preset("suit").get("snow_hold", 1.0)) < 0.5)
	assert(float(Mats._preset("camo_tank").get("snow_hold", 1.0)) == 1.0)
	# a vehicle carries its own snow (snow_k): it gathers on one standing still
	# and is shaken off one on the move or swinging its turret, never all of it
	assert(Mats.SURFACE_SHADER.contains("instance uniform vec4 snow_k"))
	assert(Vehicle.snow_carry(0.3, 1.0, 0.0, 0.0, Atmosphere.SNOW_IN) == 1.0, "a parked hull gathers a full load")
	assert(Vehicle.snow_carry(0.3, 0.0, 0.0, 0.0, 60.0) == 0.3, "no more gathers once it stops snowing")
	var driven := Vehicle.snow_carry(1.0, 1.0, 5.0, 0.0, Vehicle.SNOW_SHED * 0.5)
	assert(driven < 0.6 and driven > Vehicle.SNOW_KEPT, "driving shakes it off as it goes (%s)" % driven)
	assert(is_equal_approx(Vehicle.snow_carry(1.0, 1.0, 5.0, 0.0, Vehicle.SNOW_SHED * 3.0), Vehicle.SNOW_KEPT), "some stays in the corners")
	assert(Vehicle.snow_carry(0.1, 1.0, 5.0, 0.0, 10.0) == 0.1, "none gathers on the move")
	assert(Vehicle.snow_carry(1.0, 1.0, 0.0, 0.5, 10.0) < 1.0, "a swinging turret throws some off")
	assert(Vehicle.snow_carry(1.0, 1.0, 9.0, 0.0, 1.0) < Vehicle.snow_carry(1.0, 1.0, 3.0, 0.0, 1.0), "faster sheds faster")
	# the warm patch on an engine deck spreads the longer the engine runs
	assert(Vehicle.engine_spread(0.0) == 0.0 and Vehicle.engine_spread(Vehicle.ENGINE_WARM * 0.5) == 2.0)
	assert(Vehicle.engine_spread(Vehicle.ENGINE_WARM * 9.0) == 4.0, "as far as it goes")
	_check_snow_melt()
	_check_snow_drift()
	_check_snow_lie()
	_check_snow_roof()


## How deep the snow lies on the land (SnowLie): one rule the ground and the
## grass both follow (the grass's blades stand out where the ground shows),
## without a texture of its own (the ground keeps to its sampler budget).
## Under trees each trunk stands in a well (Woodland, kind 7).
func _check_snow_lie() -> void:
	assert(not SnowLie.GLSL.contains("sampler"))
	assert(Atmosphere.GROUND_SHADER.contains("snow_lie(") and Grass.GRASS_SHADER.contains("snow_lie("), "the ground and the grass share the rule")
	assert(Atmosphere.GROUND_SHADER.contains("wood_floor"), "thinner under the trees")
	assert(Woodland.SHADER.contains("kind == 7"), "a well round each trunk")
	# the streets are ploughed to the kerbs
	assert(Atmosphere.ROAD_SHADER.contains("bank_relief("))


## The snow on a roof (SnowRoof, Structure._snow_roof): a lip along a pitched
## roof's eaves (and icicles under a warm house's), drifts against a flat
## roof's parapets on the lee of the one the wind comes over; the surface
## shader reads a roof's warmth and chimney from its snow_k.
func _check_snow_roof() -> void:
	var rng := RandomNumberGenerator.new()
	var gable := {"L": 8.0, "W": 6.0, "h": 3.0, "pitch": 30.0, "fx": 4.2, "fz": 3.2, "hipped": false, "barn": false, "ang": 0.0, "th": 0.09}
	rng.seed = 7
	var cold := SnowRoof.cap(gable, 0.0, 1.0, 0.0, rng)
	rng.seed = 7
	var warm := SnowRoof.cap(gable, 1.0, 1.0, 0.0, rng)
	assert(cold != null and warm != null)
	var verts := func(m: ArrayMesh) -> int: return (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert(verts.call(warm) > verts.call(cold), "icicles under a warm house's eaves")
	# the lip lies along the eaves (±z beyond the walls), over the edge and below its top
	var aabb := cold.get_aabb()
	assert(aabb.position.z < -3.4 and aabb.end.z > 3.4, "a lip along both eaves")
	rng.seed = 7
	var hip := gable.duplicate()
	hip.hipped = true
	assert(SnowRoof.cap(hip, 0.0, 1.0, 0.0, rng) != null)
	# a flat roof: the deep bank is inside the parapet the wind comes over (upwind)
	rng.seed = 7
	var flat := {"flat": true, "L": 8.0, "W": 8.0, "h": 3.0, "ang": 0.0}
	var m := SnowRoof.cap(flat, 0.0, 1.0, 0.0, rng)
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var up := 0.0
	var down := 0.0
	for p in v:
		var w := Vector2(p.x, p.z).dot(Vector2(SnowRoof.WIND.x, SnowRoof.WIND.z))
		if w < -2.5:
			up = maxf(up, p.y)
		elif w > 2.5:
			down = maxf(down, p.y)
	assert(up > down, "deepest in the lee of the parapet the wind comes over (%s, %s)" % [up, down])
	assert(Mats.SURFACE_SHADER.contains("snow_k.y < 0.0"), "a roof's warmth and chimney ride in its snow_k")
	assert(SnowRoof.CAP_SHADER.contains("surface_thaw("), "a roof's lip melts round a fire")


## The wind heaps the snow against walls, buildings and hedges (SnowDrift):
## banked in the lee against the wall, rising to a crest a little way out and
## thinning out to its reach, a smaller bank on the windward face, none off
## its ends; a thin wall's foot is filled, a building's inside isn't, and
## nothing drifts under a roof. The grass in a drift is buried, and a thaw or
## a scorch clears the drift.
func _check_snow_drift() -> void:
	# a wall 4 m long across the wind (its length along local x, the wind along local z)
	var near := SnowDrift.drift_at(0.0, 1.0, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true)
	var far := SnowDrift.drift_at(0.0, 4.0, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true)
	assert(near > far and far > 0.0, "deep near the wall, thinning downwind")
	var crest := SnowDrift.drift_at(0.0, 1.3, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true)
	var foot := SnowDrift.drift_at(0.0, 0.35, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true)
	assert(crest > foot and crest > far, "a rounded crest a little way out from the wall")
	assert(SnowDrift.drift_at(0.0, 5.5, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true) == 0.0, "none beyond its reach")
	var face := SnowDrift.drift_at(0.0, -0.8, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true)
	assert(face > 0.0 and face < near, "a smaller bank on the windward face")
	assert(SnowDrift.drift_at(0.0, -2.5, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true) == 0.0)
	assert(SnowDrift.drift_at(3.0, 1.0, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true) == 0.0, "nothing off its ends")
	assert(SnowDrift.drift_at(0.0, 0.0, 0.0, 1.0, 2.0, 0.3, 5.0, 1.5, true) > 0.0, "a wall's foot is filled")
	assert(SnowDrift.drift_at(0.0, 0.0, 0.0, 1.0, 4.0, 4.0, 5.0, 1.5, false) == 0.0, "a building's inside isn't")
	# stamped into the map, nothing under a roof
	var d := SnowDrift.new()
	d.n = int(round(MapDims.SIZE / SnowDrift.CELL))
	d.data.resize(d.n * d.n)
	d.roofed.resize(d.n * d.n)
	var mid := d.n / 2
	var rect := Rect2i(mid - 6, mid - 6, 12, 12)
	# (its length along its own x; at this yaw that lies across Fires.WIND)
	var yaw := PI * 0.5 - atan2(SnowDrift.WIND.y, SnowDrift.WIND.x)
	var sp := [0.0, 0.0, cos(yaw), sin(yaw), 2.0, 0.3, 1.0, 5.0, true, rect, 1.5, 1]
	d.stamp(sp, rect)
	var lee := Vector2(SnowDrift.WIND) * 2.0
	var at := func(p: Vector2) -> int:
		return d.data[int(floor((p.y + MapDims.HALF) / SnowDrift.CELL)) * d.n + int(floor((p.x + MapDims.HALF) / SnowDrift.CELL))]
	assert(at.call(lee) > 0, "a drift in the wall's lee")
	assert(at.call(-SnowDrift.WIND * 4.0) == 0, "none far upwind")
	d.data.fill(0)
	for i in d.roofed.size():
		d.roofed[i] = 1
	d.stamp(sp, rect)
	assert(at.call(lee) == 0, "nothing drifts under a roof")
	# A demolished wall can disappear while its first stamp is still queued.
	d.roofed.fill(0)
	d.data.fill(0)
	d._stamp.append(sp)
	d._clear.append(rect)
	while not d._stamp.is_empty() or not d._clear.is_empty():
		d._work()
	assert(at.call(lee) == 0, "queued stamps cannot restore a demolished wall")
	# Reusing the same entity with a new footprint invalidates its old stamp.
	var moved: Array = sp.duplicate()
	moved[0] = 100.0
	d._obst[sp[11]] = moved
	d._stamp.append(sp)
	while not d._stamp.is_empty() or not d._clear.is_empty():
		d._work()
	assert(at.call(lee) == 0, "queued stamps cannot restore a moved wall")
	# A current stamp still runs after invalid entries have been discarded.
	d._obst[sp[11]] = sp
	d._stamp.append(sp)
	while not d._stamp.is_empty() or not d._clear.is_empty():
		d._work()
	assert(at.call(lee) > 0, "current stamps survive removal and requeue")
	# Removing either of two overlapping roofs must leave the other shelter intact.
	var roof: Array = sp.duplicate()
	roof[4] = 5.0
	roof[5] = 5.0
	d._cover(roof)
	d._cover(roof)
	d._uncover(roof)
	d.data.fill(0)
	d.stamp(sp, rect)
	assert(at.call(lee) == 0, "remaining overlapping roof still shelters the ground")
	d._uncover(roof)
	d.stamp(sp, rect)
	assert(at.call(lee) > 0, "snow can drift once the last roof is removed")
	d.free()
	assert(Grass.GRASS_SHADER.contains("drift_tex"), "the grass in a drift is buried")
	assert(SnowDrift.DRIFT_SHADER.contains("global uniform float snow_cover;") and SnowDrift.DRIFT_SHADER.contains("marks.g"), "a drift reads the cover and the thaws")


## Heat melts the snow (SnowMelt): a fire thaws the ground round it down to
## the earth, with slush at the rim; an idling engine only gets it to slush;
## and thawed ground stays thawed once the fire is out, whitening again only
## slowly, and only while it snows. The shaders read it without a texture of
## their own (the ground keeps to its sampler budget).
func _check_snow_melt() -> void:
	var warmup := Vfx.new()
	add_child(warmup)
	warmup.prewarm(Vector3.ZERO)
	assert(warmup.burning().is_empty(), "shader warm-up fires must never reach snow melting")
	for code in [Atmosphere.GROUND_SHADER, Atmosphere.ROAD_SHADER]:
		assert(String(code).contains("uniform vec4 melt_spots[") and String(code).contains("snow_melted("))
	assert(not SnowMelt.GLSL.contains("sampler"))
	assert(Grass.GRASS_SHADER.contains("thawed"), "the grass stands up where it's thawed")
	assert(Grass.BUSH_SHADER.contains("uniform sampler2D scar") and Grass.BUSH_SHADER.contains("(1.0 - lies)"), "and the snow melts off the bushes")
	var melt := SnowMelt.new()
	var fire: Array = []
	for i in int(SnowMelt.FIRE_MELT * 2.0 / SnowMelt.STEP):
		fire = melt.warm(1, Vector3(5, 0, 5), 8.0, 3.0, SnowMelt.STEP / SnowMelt.FIRE_MELT, 1.0)
		melt.settle(true)
	assert(is_equal_approx(float(fire[3]), 1.0), "a fire melts it down to the earth")
	assert(float(fire[2]) > 3.0 and float(fire[2]) <= 8.0, "and the thaw spreads out from it")
	assert(SnowMelt.amount(0.0, 8.0, 1.0) == 1.0 and SnowMelt.amount(8.0, 8.0, 1.0) == 0.0)
	var rim := SnowMelt.amount(6.5, 8.0, 1.0)
	# a big fire is bare from its own edge outward (its core), not just at its middle
	assert(SnowMelt.amount(5.0, 10.0, 1.0, 0.0, 4.0) == 1.0 and SnowMelt.amount(5.0, 10.0, 1.0) < 1.0)
	# everything standing round a fire (the paving, the yards, the roofs) takes
	# the nearest thaws, as globals every material and copy reads
	assert(Mats.SURFACE_SHADER.contains("surface_thaw("))
	for i in Mats.THAWS:
		assert(Mats.SURFACE_SHADER.contains("global uniform vec4 snow_thaw_%d;" % i))
		assert(ProjectSettings.has_setting("shader_globals/snow_thaw_%d" % i), "snow_thaw_%d is a project global" % i)
	assert(rim > 0.05 and rim < 0.55, "bare in the middle, slush at the rim (%s)" % rim)
	# out: it stays thawed, and whitens only while it snows
	for i in int(60.0 / SnowMelt.STEP):
		melt.settle(true)
	assert(float(fire[3]) > 0.9 and float(fire[3]) < 1.0, "a minute after the fire's out the ground is still bare")
	var held := float(fire[3])
	for i in int(60.0 / SnowMelt.STEP):
		melt.settle(false)
	assert(float(fire[3]) == held, "with no snow falling it stays as it is")
	for i in int(SnowMelt.REFREEZE / SnowMelt.STEP):
		melt.settle(true)
	assert(melt.spots.is_empty(), "white again after REFREEZE of falling snow")
	# an engine idling works it to slush, no further
	var idle: Array = []
	for i in int(SnowMelt.IDLE_MELT * 2.0 / SnowMelt.STEP):
		idle = melt.warm(-2, Vector3(40, 0, 5), 3.0, 1.0, SnowMelt.STEP / SnowMelt.IDLE_MELT, SnowMelt.IDLE_MAX)
		melt.settle(true)
	assert(is_equal_approx(float(idle[3]), SnowMelt.IDLE_MAX), "an idling engine gets it only to slush")
	# it drives off and stops again: the old thaw is left behind, a new one starts
	var moved := melt.warm(-2, Vector3(60, 0, 5), 3.0, 1.0, SnowMelt.STEP / SnowMelt.IDLE_MELT, SnowMelt.IDLE_MAX)
	assert(moved != idle and melt.spots.size() == 2 and int(idle[5]) == 0, "a thaw left behind where it stood")
	# the snowfall follows the effects setting, and the browser gets fewer flakes
	var saved := int(Settings.v.effects)
	var counts := []
	for fx in [0, 2]:
		Settings.v.effects = fx
		var fall := Snowfall.new()
		add_child(fall)
		var p: GeometryInstance3D = fall.get_child(0)
		counts.append(int(p.get(&"amount")))
		fall.free()
	Settings.v.effects = saved
	assert(counts[0] < counts[1] and counts[1] >= Snowfall.FLAKES * (0.25 if Vfx.gl else 1.0) * 0.99, "flakes %s" % [counts])


## The velocity buffer is drawn only while the blur wants it, and the camera's
## own movement blurs only on "Objects + camera", never with Reduce motion.
func _check_motion_blur() -> void:
	assert(Settings.LABELS.motion_blur.size() == 3)
	assert(int(Settings.PRESETS.cinematic.motion_blur) == 1, "Cinematic blurs moving things, not the commander's pans")
	for p in ["low", "medium", "high", "ultra"]:
		assert(int(Settings.PRESETS[p].motion_blur) == 0)
	var fx := CinematicFx.new()
	assert(not fx.motion_blur and not fx.needs_motion_vectors)
	fx = null


func _check_presets() -> void:
	assert(Settings.PRESET_KEYS.size() == Settings.PRESETS.size())
	for p in Settings.PRESET_KEYS:
		assert(Settings.PRESETS.has(p))
		for k in Settings.PRESETS[p]:
			assert(Settings.v.has(k), "preset %s sets %s, which isn't a setting" % [p, k])
		for k in Settings.CINEMATIC_KEYS:
			assert(Settings.PRESETS[p].has(k), "preset %s leaves out %s" % [p, k])
	# Cinematic is Ultra with all of the cinematic lighting on top
	var ultra: Dictionary = Settings.PRESETS.ultra
	var cine: Dictionary = Settings.PRESETS.cinematic
	for k in ultra:
		if not k in Settings.CINEMATIC_KEYS and k != "terrain_reflections":
			assert(cine[k] == ultra[k], "Cinematic differs from Ultra in %s" % k)
	for k in Settings.CINEMATIC_KEYS:
		assert(bool(cine[k]), "Cinematic leaves %s off" % k)
		if k != "shadow_fit":
			assert(not bool(ultra[k]), "Ultra already has %s" % k)
	# the browser build hides what its renderer can't draw
	for k in ["light_shadows", "phys_sky", "lens", "shafts", "local_exp", "eye_adapt", "film", "heat_haze", "motion_blur", "ssgi"]:
		assert(k in SettingsPanel.NOT_ON_WEB)
	# bounce light: off up to Medium, then more of it the higher the preset
	var last := -1
	for p in Settings.PRESET_KEYS:
		var q := int(Settings.PRESETS[p].ssgi)
		assert(q >= last and q <= 2, "bounce light goes up with the presets (%s: %d)" % [p, q])
		last = q
	assert(int(Settings.PRESETS.medium.ssgi) == 0 and int(Settings.PRESETS.high.ssgi) == 1 and int(Settings.PRESETS.ultra.ssgi) == 2)


## A settings file from before the cinematic lighting takes its preset's.
func _check_saved_settings() -> void:
	var saved := Settings.v.duplicate()
	var saved_preset := Settings.preset
	for preset in ["low", "cinematic"]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", preset)
		cf.set_value("main", "cfg_version", 2)
		cf.set_value("main", "shadows", 2)
		var path := "user://cinematic_lighting_test.cfg"
		cf.save(path)
		for k in Settings.CINEMATIC_KEYS:
			Settings.v[k] = Settings.PRESETS.high[k]
		Settings._load(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		for k in Settings.CINEMATIC_KEYS:
			assert(Settings.v[k] == Settings.PRESETS[preset][k], "a saved %s setup gets %s = %s" % [preset, k, Settings.v[k]])
	# a setup saved before bounce light takes its preset's; a custom one stays without
	for preset in ["high", "ultra", "custom"]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", preset)
		cf.set_value("main", "cfg_version", 2)
		var path := "user://bounce_light_test.cfg"
		cf.save(path)
		Settings.v.ssgi = 2
		Settings._load(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var want: int = int(Settings.PRESETS[preset].ssgi) if Settings.PRESETS.has(preset) else 0
		assert(int(Settings.v.ssgi) == want, "a saved %s setup gets bounce light %d" % [preset, int(Settings.v.ssgi)])
	Settings.v = saved
	Settings.preset = saved_preset


func _check_shadow_fit() -> void:
	var cam := Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	# close in and looking down: the shadows reach no further than the view
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45.0), 0.3, 0.0)), Vector3(0, 12, 12))
	var near := Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)
	assert(near.size() == 4)
	assert(near[0] < 200.0, "close in the shadows still reach %.0f m" % near[0])
	assert(near[1] > 0.0 and near[1] < near[2] and near[2] < near[3] and near[3] < 1.0)
	# zoomed out, further; looking at the horizon, the whole reach
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-60.0), 0.3, 0.0)), Vector3(0, 180, 100))
	var far := Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)
	assert(far[0] > near[0] and far[0] <= 800.0)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), 0.3, 0.0)), Vector3(0, 8, 0))
	assert(is_equal_approx(Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)[0], 800.0))
	# Low shadows keep two cascades
	assert(Atmosphere.fit_cascades(cam, 0.0, 0.0, 140.0, 2).size() == 2)
	# mountains look further down into the valleys
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45.0), 0.3, 0.0)), Vector3(0, 12, 12))
	assert(Atmosphere.fit_cascades(cam, 0.0, 400.0, 800.0, 4)[0] > near[0])
	cam.free()


func _check_light_picking() -> void:
	var lights: Array[OmniLight3D] = []
	for spec in [[8.0, 14.0, Vector3(5, 1, 0)], [2.0, 14.0, Vector3(10, 1, 0)], [9.0, 14.0, Vector3(400, 1, 0)],
			[0.1, 14.0, Vector3(1, 1, 0)], [6.0, 5.0, Vector3(2, 1, 0)], [7.0, 14.0, Vector3(3, 1, 0)]]:
		var l := OmniLight3D.new()
		l.light_energy = spec[0]
		l.omni_range = spec[1]
		add_child(l)
		l.global_position = spec[2]
		lights.append(l)
	lights[5].visible = false
	var picked := Atmosphere.pick_shadowed(lights, Vector3.ZERO, 2)
	# the bright near ones; not the far one, the spent one or the hidden one
	assert(picked.size() == 2 and picked[0] == lights[0] and picked[1] == lights[1], "picked %s" % [picked])
	assert(Atmosphere.pick_shadowed(lights, Vector3.ZERO, 6).size() == 3)
	for l in lights:
		l.free()


func _check_sky() -> void:
	for m in PhysicalSky.MOODS:
		assert(Atmosphere.MOODS.has(m))
		var mat := PhysicalSky.make(m)
		assert(float(mat.get_shader_parameter("sky_energy")) > 1.0)
	# midday keeps its photographed sky; cloud, rain and night their painted ones
	for m in ["day", "overcast", "rain", "night"]:
		assert(not PhysicalSky.MOODS.has(m))


## Windowed: the passes compile and run (a shader the driver refuses
## push_errors, which fails the run).
func _check_passes() -> void:
	if not CinematicFx.supported():
		return
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var fx := CinematicFx.new()
	for k in ["shafts", "lens", "local_exposure", "eye", "film", "heat_haze"]:
		fx.set(k, true)
	# a column of hot air in front of the box
	var hh := HeatHaze.new()
	hh.on = true
	var hc := Camera3D.new()
	add_child(hc)
	hh.begin(hc)
	hh.add(Vector3(0, 0.4, -3.0), 0.5, Vector3.UP, 2.0, 1.0, 2.0, 0.3)
	fx.heat = hh.finish()
	fx.heat_time = 1.5
	hc.free()
	var p := PackedFloat32Array()
	p.resize(CinematicFx.PARAMS)
	p[6] = 1.0
	p[7] = 16.0 / 9.0
	p[11] = 1.0
	p[12] = 1.0
	p[13] = 0.3
	p[14] = 1.0
	p[15] = 2.0
	p[16] = 1.0
	p[17] = 1.0
	p[18] = 1.0
	p[19] = 1.0 / 30.0
	p[20] = 1.0
	p[22] = 0.4
	p[24] = 2.6
	p[25] = 0.7
	p[26] = 0.12
	fx.params = p
	var comp := Compositor.new()
	var effects: Array[CompositorEffect] = [fx]
	comp.compositor_effects = effects
	env.compositor = comp
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -4)
	add_child(box)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(fx._ready_rd, "the cinematic passes didn't compile")
	env.queue_free()
	cam.queue_free()
	box.queue_free()


## The heat haze keeps what the camera can see, near enough to show, and when
## there's more than the heat pass takes, the ones that would show the most.
func _check_heat_sources() -> void:
	var cam := Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	cam.global_transform = Transform3D.IDENTITY  # at the origin, looking down -Z
	var hh := HeatHaze.new()
	hh.begin(cam)
	hh.add(Vector3(0, 0, -30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # in view: kept
	hh.add(Vector3(0, 0, 30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # behind the camera
	hh.add(Vector3(200, 0, -30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # far off to the side
	hh.add(Vector3(0, 0, -900), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # too far to see
	hh.add(Vector3(2, 0, -30), 0.6, Vector3.UP, 2.0, 0.0, 2.0, 0.3)  # cold
	var out := hh.finish()
	assert(out.size() == HeatHaze.STRIDE, "kept %d floats" % out.size())
	assert(is_equal_approx(out[2], -30.0) and is_equal_approx(out[8], 1.0))
	# a big battle: only the strongest HeatHaze.MAX go to the heat pass
	hh.begin(cam)
	var n := HeatHaze.MAX + 20
	for i in n:
		hh.add(Vector3(float(i % 9) - 4.0, 0, -40), 0.6, Vector3.UP, 2.0, 0.05 + 0.01 * i, 2.0, 0.3)
	out = hh.finish()
	assert(out.size() == HeatHaze.MAX * HeatHaze.STRIDE, "kept %d" % (out.size() / HeatHaze.STRIDE))
	var weakest := INF
	for i in HeatHaze.MAX:
		weakest = minf(weakest, out[i * HeatHaze.STRIDE + 8])
	assert(weakest >= 0.05 + 0.01 * 20 - 0.001, "kept a source of strength %.2f over stronger ones" % weakest)
	# a fire's hot air stands over it, leaning downwind; a bigger fire's is wider
	hh.begin(cam)
	hh.add_fire(Vector3(0, 0, -30), Vector3(0.55, 0.45, 0.55), 1.0)
	hh.add_fire(Vector3(0, 0, -30), Vector3(3.0, 0.25, 3.0), 1.0)
	out = hh.finish()
	assert(out.size() == 2 * HeatHaze.STRIDE)
	assert(out[1] > 1.0 and out[4] * Fires.WIND.x > 0.0 and out[5] > 0.9, "a fire's column %s" % [out.slice(0, 8)])
	assert(out[HeatHaze.STRIDE + 3] > out[3])
	cam.free()


## Blasts and muzzles: a pulse only while the haze is on, in at once and gone
## once its time is up.
func _check_heat_pulses() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var hh := HeatHaze.new()
	hh.blast(Vector3(0, 0, -30), 1.4)
	assert(hh.pulses() == 0, "a pulse kept with the haze off")
	hh.on = true
	hh.blast(Vector3(0, 0, -30), 1.4)
	assert(hh.pulses() == 1)
	assert(HeatHaze.pulse_strength(0.0, 1.0) == 0.0 and HeatHaze.pulse_strength(1.0, 1.0) == 0.0)
	assert(HeatHaze.pulse_strength(0.06, 1.0) > HeatHaze.pulse_strength(0.5, 1.0))
	assert(HeatHaze.pulse_strength(0.5, 1.0) > HeatHaze.pulse_strength(0.9, 1.0))
	hh.begin(cam)
	hh._tick_pulses(0.05)
	assert(hh.finish().size() == HeatHaze.STRIDE, "a fresh blast's heat isn't in view")
	for i in 30:
		hh.begin(cam)
		hh._tick_pulses(0.05)
	assert(hh.pulses() == 0, "a blast's heat outlived it")
	for i in HeatHaze.PULSES + 5:
		hh.blast(Vector3(0, 0, -30), 1.0)
	assert(hh.pulses() == HeatHaze.PULSES)
	hh.clear()
	assert(hh.pulses() == 0)
	cam.free()


## The models note the mouths of their exhausts, pointing the way the gas
## leaves: an Apache's turbines blow out and back.
func _check_exhaust_markers() -> void:
	var k := VehicleModels.build("gunship", 0, 1)
	assert(k.exhausts.size() >= 2, "the Apache notes %d exhausts" % k.exhausts.size())
	for e in k.exhausts:
		var out := e.basis.y.normalized()
		assert(out.z > 0.3, "an exhaust blows %s, not back" % out)
		assert(absf(e.origin.x) > 0.3 and e.origin.y > 1.0, "an exhaust's mouth at %s" % e.origin)
	k.root.free()


## A fire on something taken out of the tree (a destroyed vehicle, kept a
## while after it's cleared away) adds no heat, and reading where it is mustn't
## raise an engine error every frame.
func _check_detached_fires() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var vfx := Vfx.new()
	var holder := Node3D.new()
	for i in 2:
		var h := Node3D.new()
		h.position = Vector3(0, 0, -30)
		h.set_meta("fire", 1.0)
		h.set_meta("ext", Vector3(0.55, 0.45, 0.55))
		holder.add_child(h)
		vfx._burners.append(h)
	var hh := HeatHaze.new()
	hh.begin(cam)
	vfx.heat_sources(hh)
	assert(hh.finish().is_empty(), "fires outside the tree gave off heat")
	add_child(holder)
	hh.begin(cam)
	vfx.heat_sources(hh)
	assert(hh.finish().size() == 2 * HeatHaze.STRIDE, "fires back in the tree gave off no heat")
	holder.free()
	vfx.free()
	cam.free()
