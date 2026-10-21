extends Node
## Cosmetic haze and transparent world symbols must stay readable at command zoom.

var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		push_error(what)
		TestRun.fail()


func _ready() -> void:
	TestRun.watch()
	Settings.no_save = true
	var atmo := Atmosphere.new()
	atmo.env = Environment.new()
	for mood in Atmosphere.MOODS:
		atmo.mood = mood
		atmo._d = Atmosphere.MOODS[mood]
		var previous := INF
		for distance in [10.0, 22.0, 32.0, 45.0, 120.0, 260.0, 600.0, 1200.0]:
			atmo._apply_haze(distance)
			var density := atmo.env.fog_density + atmo.env.volumetric_fog_density
			check(density > 0.0, "%s retains its atmosphere at %s m" % [mood, distance])
			check(density <= previous, "%s haze cannot grow as the camera pulls back" % mood)
			check(density * distance <= 0.0481, "%s haze obscures too much at %s m" % [mood, distance])
			previous = density
	# Switching from haze to another mood must also reset the volume density.
	atmo.mood = "day"
	atmo._d = Atmosphere.MOODS.day
	atmo._apply_haze(45.0)
	check(is_equal_approx(atmo.env.volumetric_fog_density, 0.0011 * Atmosphere.VOLUME_STRENGTH * Atmosphere.haze_distance_factor(45.0)), "day volume density resets after another mood")
	atmo.free()
	MapSymbols.build_atlas(self)
	for friendly in [true, false]:
		for team in [0, 1, -1]:
			for glyph in MapSymbols.NATO_GLYPHS:
				var solid := MapSymbols._nato_key(friendly, team, glyph)
				var subtle := MapSymbols._nato_key(friendly, team, glyph, true)
				check(MapSymbols._cells.has(solid) and MapSymbols._cells.has(subtle), "both map and world variants exist for %s" % glyph)
				check(MapSymbols._cells[solid] != MapSymbols._cells[subtle], "world and map symbols never share an opaque atlas cell")
	for i in 3:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := MapSymbols.atlas.get_image()
		var solid: Rect2 = MapSymbols._cells[MapSymbols._nato_key(true, 0, "inf")]
		var subtle: Rect2 = MapSymbols._cells[MapSymbols._nato_key(true, 0, "inf", true)]
		# Above the diagonal crossing, but inside the rectangle's fill.
		var sample := Vector2i(MapSymbols.CELL * 0.5, MapSymbols.CELL * 0.5 - 6.0)
		var solid_alpha := img.get_pixelv(Vector2i(solid.position) + sample).a
		var subtle_alpha := img.get_pixelv(Vector2i(subtle.position) + sample).a
		check(solid_alpha > 0.7, "map counters remain solid")
		check(subtle_alpha < 0.2, "world counter interiors let the troops show through")
	if DisplayServer.get_name() != "headless":
		Sfx._ensure()
		while Music._task >= 0:
			await get_tree().process_frame
	print("VISIBILITYTEST %d checks, %d failures" % [checks, TestRun.failures])
	TestRun.quit(get_tree())
