extends Node
## Time passes: the light is a pure function of the battle's time and the
## mood it began in, and with the setting off nothing changes from before.
##
## The clock on its own (TimeOfDay): each mood's own hour gives that mood
## exactly; the light runs on smoothly round the whole day, the sun and the
## moon handing over only in the dark; weather holds; golden hour reaches full
## night in about forty minutes. Then the real Atmosphere's environment, sun,
## fill light and skies, as a battle has them with no map under them: lit at a
## moment straight away and lit there by way of any other moments give the
## same light to the last bit, and with the setting off the light never moves.
##
## FL_TOD_DUMP=mood prints the light every few battle minutes instead.

class Field extends World:
	func _ready() -> void:
		has_view = true
		set_process(false)
		set_physics_process(false)


var failures := 0
var checks := 0


func _quiet(ok: bool, what: String, hour: float, values: Array) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("TIME_OF_DAY FAIL: %s at %.2fh %s" % [what, hour, str(values)])


func _check(what: String, ok: bool, detail := "") -> void:
	checks += 1
	if not ok:
		failures += 1
		print("TIME_OF_DAY FAIL: %s %s" % [what, detail])


func _ready() -> void:
	Settings.no_save = true
	if OS.has_environment("FL_TOD_DUMP"):
		_dump(OS.get_environment("FL_TOD_DUMP"))
		get_tree().quit()
		return
	var took := []
	for c in [_check_moods_hold_their_hour, _check_weather_holds, _check_smooth_round_the_day, _check_pace, _check_no_hidden_state,
			_check_live_light, _check_setting_off, _check_sky_code]:
		var t0 := Time.get_ticks_msec()
		c.call()
		took.append("%s %d ms" % [c.get_method().trim_prefix("_check_"), Time.get_ticks_msec() - t0])
	print("TIME_OF_DAY took: " + ", ".join(took))
	if failures == 0:
		print("TIME_OF_DAY passed (%d checks)" % checks)
	get_tree().quit(1 if failures > 0 else 0)


## On its own hour a mood's light is that mood's, to the bit.
func _check_moods_hold_their_hour() -> void:
	for m in TimeOfDay.HOUR:
		var st := TimeOfDay.light(m, 0.0)
		_check("%s starts as %s" % [m, m], st.mood == m and st.weights == {m: 1.0}, str(st.weights))
		var d: Dictionary = st.d
		for k in Atmosphere.MOODS[m]:
			_check("%s at its hour keeps %s" % [m, k], d[k] == Atmosphere.MOODS[m][k], "%s != %s" % [d[k], Atmosphere.MOODS[m][k]])


func _check_weather_holds() -> void:
	for m in ["overcast", "rain", "hazy"]:
		_check("%s isn't on the clock" % m, not TimeOfDay.runs(m))
		for t in [0.0, 600.0, 2400.0, 9000.0]:
			_check("%s holds at %d s" % [m, t], str(TimeOfDay.light(m, t)) == str(TimeOfDay.still(m)))


## Round the whole day in steps of a relighting: nothing jumps, except the
## light's direction where the sun hands over to the moon (or back), and
## that only while neither lights anything.
func _check_smooth_round_the_day() -> void:
	var day_s := 24.0 * 3600.0 / TimeOfDay.PACE
	var prev := TimeOfDay.light("dawn", 0.0)
	var handovers := 0
	var t := TimeOfDay.STEP
	while t <= day_s + 0.5:
		var st := TimeOfDay.light("dawn", t)
		var a: Dictionary = prev.d
		var b: Dictionary = st.d
		# (checked quietly, the message made only for a failure: thousands of steps)
		var where := float(st.hour)
		# (never more than about 25 degrees an hour: 0.08 a step)
		var sun_a := TimeOfDay.toward((prev.sun as Vector2).x, (prev.sun as Vector2).y)
		var sun_b := TimeOfDay.toward((st.sun as Vector2).x, (st.sun as Vector2).y)
		_quiet(sun_a.angle_to(sun_b) < deg_to_rad(0.12), "the sun moves on smoothly", where, [prev.sun, st.sun])
		for k in ["zenith", "horizon", "fog", "tint"]:
			var ca: Color = a[k]
			var cb: Color = b[k]
			# (a hundredth of the way from black to white, summed over the channels, a step at most)
			_quiet(absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) < 0.012, k + " blends smoothly", where, [ca, cb])
		for k in ["fog_d", "ambient", "clouds", "exposure", "energy"]:
			_quiet(absf(float(a[k]) - float(b[k])) < 0.02 * maxf(1.0, absf(float(a[k]))), k + " blends smoothly", where, [a[k], b[k]])
		_quiet(float(b.energy) >= 0.0, "the light is never negative", where, [b.energy])
		var moved := TimeOfDay.toward(float(a.elev), float(a.azim)).angle_to(TimeOfDay.toward(float(b.elev), float(b.azim)))
		if moved > deg_to_rad(0.1):
			handovers += 1
			_quiet(float(a.energy) < 0.002 and float(b.energy) < 0.002, "sun and moon hand over in the dark", where, [a.energy, b.energy])
		prev = st
		t += TimeOfDay.STEP
	_check("the sun hands over to the moon and back once a day", handovers == 2, str(handovers))


## Golden hour to full night in about forty minutes.
func _check_pace() -> void:
	var t := 0.0
	while float(TimeOfDay.light("golden", t).weights.get("night", 0.0)) < 1.0 and t < 7200.0:
		t += TimeOfDay.STEP
	_check("golden hour to night in about forty minutes", t > 25.0 * 60.0 and t < 45.0 * 60.0, "%.1f min" % (t / 60.0))


## The clock keeps nothing: moments asked for in any order give what they
## give asked for in order.
func _check_no_hidden_state() -> void:
	var times: Array[float] = []
	for i in 200:
		times.append(float(i) * 37.3)
	var first := {}
	for t in times:
		first[t] = str(TimeOfDay.light("dusk", t))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 400:
		var t: float = times[r.randi() % times.size()]
		_check("the light at %.1f s is the same asked again" % t, str(TimeOfDay.light("dusk", t)) == first[t])


## A battle's Atmosphere with its environment, sun, fill light and skies, and
## no ground (the photo-mode fixture's way). One world stands under them all.
var _field: Field


func _atmosphere(settings: Dictionary) -> Atmosphere:
	if _field == null:
		_field = Field.new()
		_field.srv = true
		add_child(_field)
	_field.settings = settings
	var atmo := Atmosphere.new()
	atmo.world = _field
	atmo.mood = Atmosphere.pick_mood(settings)
	atmo._d = Atmosphere.MOODS[atmo.mood]
	atmo.weights = {atmo.mood: 1.0}
	atmo._clock_start = atmo.mood
	atmo._build_env()
	atmo._build_post()
	atmo.set_process(false)
	_field.add_child(atmo)
	_field.atmo = atmo
	return atmo


func _done(a: Atmosphere) -> void:
	a.queue_free()


## What a player sees of the light: the sun, the fill light, the
## environment and the sky's material and its parameters.
func _seen(a: Atmosphere) -> String:
	var out := [a.mood, a.sun.rotation, a.sun.light_color, a.sun.light_energy, a.sun.light_angular_distance, a.rim.rotation,
		a.env.ambient_light_energy, a.env.tonemap_exposure, a.env.fog_light_color, a.env.volumetric_fog_albedo,
		a.env.adjustment_saturation, a.env.sky.radiance_size]
	var m := a.env.sky.sky_material as ShaderMaterial
	out.append(m == a.sky_mat)
	out.append(m == a._phys_sky)
	for p in ["zenith", "horizon", "sun_col", "cloud_cover", "stars", "photo_mix", "rotation", "turbidity", "sky_energy",
			"cloudiness", "sun_direction", "sun_energy", "night", "night_light", "warm_grey"]:
		out.append(m.get_shader_parameter(p))
	return str(out)


func _tick_at(a: Atmosphere, t: float) -> void:
	a.world.time = t
	a._time_tick()


## Lit at a moment straight away, or by way of others (in steps, backwards,
## jumping about as a replay sought to and fro would), the light is the same.
## And a battle on the same seed, with its mood picked from the seed, starts
## its clock in the same mood.
func _check_live_light() -> void:
	Settings.v.time_passes = true
	for phys in [false, true]:
		Settings.v.phys_sky = phys
		for start in ["golden", "dawn", "night"]:
			for t in [0.0, 1440.0, 1610.0, 1700.0, 5000.0]:
				var straight := _atmosphere({"seed": 3, "mood": start})
				_tick_at(straight, t)
				var roundabout := _atmosphere({"seed": 3, "mood": start})
				for u in [t + 900.0, 60.0, 3.0, t * 0.5, 7000.0, t]:
					_tick_at(roundabout, u)
				var a := _seen(straight)
				var b := _seen(roundabout)
				_check("%s at %d s (Physical sky %s) is the same however it got there" % [start, t, phys], a == b, "" if a == b else "%s  ||  %s" % [a, b])
				_done(straight)
				_done(roundabout)
	var x := _atmosphere({"seed": 11})
	var y := _atmosphere({"seed": 11})
	_check("the same seed, the same mood", x.mood == y.mood)
	_tick_at(x, 1234.0)
	_tick_at(y, 1234.0)
	_check("the same seed, the same light", _seen(x) == _seen(y))
	_done(x)
	_done(y)


## With the setting off, a battle's light is its mood's, whatever the time,
## exactly as it was before there was a clock: the sun, the air and the sky
## each mood always had.
func _check_setting_off() -> void:
	Settings.v.time_passes = false
	for phys in [false, true]:
		Settings.v.phys_sky = phys
		for m in Atmosphere.MOODS:
			var before := _atmosphere({"seed": 1, "mood": m})
			var d: Dictionary = Atmosphere.MOODS[m]
			var what := "%s (Physical sky %s)" % [m, phys]
			_check(what + ": the sun where the mood has it", before.sun.rotation_degrees.is_equal_approx(Vector3(-float(d.elev), float(d.azim), 0.0)))
			# (the engine keeps them in single precision)
			_check(what + ": its colour and strength", before.sun.light_color.is_equal_approx(d.sun) and is_equal_approx(before.sun.light_energy, float(d.energy)))
			_check(what + ": the air, the sky's light and the exposure", before.env.fog_light_color.is_equal_approx(d.fog)
				and is_equal_approx(before.env.ambient_light_energy, float(d.ambient)) and is_equal_approx(before.env.tonemap_exposure, float(d.exposure)))
			_check(what + ": the grade", is_equal_approx(before.env.adjustment_saturation, 1.05 if m in ["golden", "dusk", "dawn"] else 1.1))
			var sky := before.env.sky.sky_material as ShaderMaterial
			var physical: bool = phys and PhysicalSky.MOODS.has(m)
			_check(what + ": its own sky", (sky == before._phys_sky) == physical and (sky == before._photo_sky) == (m == "day" and not physical)
				and before.env.sky.radiance_size == (Sky.RADIANCE_SIZE_256 if physical else Sky.RADIANCE_SIZE_128))
			_check(what + ": the painted sky as it was", before.sky_mat.get_shader_parameter("zenith") == d.zenith
				and before.sky_mat.get_shader_parameter("horizon") == d.horizon and before.sky_mat.get_shader_parameter("sun_col") == d.sun
				and float(before.sky_mat.get_shader_parameter("cloud_cover")) == (1.0 if m in ["overcast", "rain"] else (0.3 if m == "day" else 0.55))
				and float(before.sky_mat.get_shader_parameter("stars")) == (1.0 if m == "night" else 0.0))
			var seen := _seen(before)
			for t in [2.0, 600.0, 2400.0]:
				_tick_at(before, t)
				var now := _seen(before)
				_check("%s with time standing still at %d s" % [what, t], now == seen, "" if now == seen else "%s  ||  %s" % [seen, now])
			_done(before)
	Settings.v.time_passes = false
	Settings.v.phys_sky = false


## The physical sky takes in the painted sky's uniforms (its night) and the
## photograph's: a local of the same name in the physical sky's code would be
## read as the uniform (the compiler resolves it so) and fail the whole sky on
## the graphics card, which a headless run never compiles. And with nothing to
## blend, every sky draws as it did.
func _check_sky_code() -> void:
	var taken := {}
	var re := RegEx.new()
	re.compile("uniform\\s+\\w+\\s+(\\w+)")
	for code in [Atmosphere.PAINTED_SKY, Atmosphere.PHOTO_SKY_FN, PhysicalSky.NIGHT_UNIFORMS, "uniform float photo_mix"]:
		for m in re.search_all(code):
			taken[m.get_string(1)] = true
	var local := RegEx.new()
	local.compile("(?:float|int|bool|vec2|vec3|vec4|mat3)\\s+(\\w+)\\s*[=;,)]")
	for m in local.search_all(PhysicalSky.SHADER):
		_check("the physical sky has no local named like an injected uniform (%s)" % m.get_string(1), not taken.has(m.get_string(1)))
	var phys := Atmosphere.with_photo(PhysicalSky.with_night(PhysicalSky.SHADER))
	_check("the physical sky takes in the night and the photograph", phys.contains("painted_sky(d, night_light") and phys.contains("photo_sky(EYEDIR)"))
	_check("only behind their switches", phys.contains("if (night > 0.0)") and phys.contains("if (photo_mix > 0.0)"))
	var painted := Atmosphere.with_photo(Atmosphere.SKY_SHADER)
	_check("the painted sky draws through painted_sky()", painted.contains("painted_sky(EYEDIR, LIGHT0_DIRECTION, TIME)"))
	_check("midday's photograph keeps its sky still (no TIME: no re-render each frame)", not Atmosphere.PHOTO_SKY_SHADER.contains("TIME"))


## FL_TOD_DUMP=golden: the light every few battle minutes from that mood.
func _dump(start: String) -> void:
	var every := float(OS.get_environment("FL_TOD_EVERY")) if OS.has_environment("FL_TOD_EVERY") else 150.0
	var t := 0.0
	while t <= 24.0 * 3600.0 / TimeOfDay.PACE:
		var st := TimeOfDay.light(start, t)
		var d: Dictionary = st.d
		var sp: Vector2 = st.sun
		print("%6.1fmin %05.2fh %-7s sun %6.1f %7.1f light %5.1f %6.1f e %.3f up %.2f exp %.3f amb %.3f zen %s hor %s fog %s photo %.2f %s" % [
			t / 60.0, float(st.hour), st.mood, sp.x, sp.y, float(d.elev), float(d.azim), float(d.energy), float(st.up),
			float(d.exposure), float(d.ambient), (d.zenith as Color).to_html(false), (d.horizon as Color).to_html(false),
			(d.fog as Color).to_html(false), float(st.photo), str(st.weights)])
		t += every
