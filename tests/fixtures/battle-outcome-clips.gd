extends Node3D
## Controlled end-of-battle capture using the real scenario, victory rules,
## result banner and report. Resolve starts near zero to keep the clip short.
## Record at 15 fps. UI wall clocks are advanced by the same fixed frame time,
## so software rendering cannot skip the result animation.
var field: World
var elapsed := 0.0
var started := false

func _ready() -> void:
	TestRun.watch()
	process_priority = -100
	Settings.apply_preset("low", false)
	Settings.v.perf = 0
	field = World.new()
	field.settings = {"scenario": "attack", "scenario_player": true, "seed": 3, "mood": "day", "map_size": 1024, "players": {1: {"team": 0, "name": "Commander"}}, "ai_teams": []}
	add_child(field)
	await field.build()
	if field.has_view:
		field.cam.focus(Vector3(0, 0, -5))
		field.cam.target_dist = 115.0
		field.cam.dist = 115.0
		field.input.set_process(false)
	# A held town supplies a real ground advantage; neither side loses its FOB.
	var town: Structure = field.spawn("structure", {"skind": "town", "variant": 1, "pos": Vector3(-80, 0, 70), "team": 0, "built": true, "sname": "Training town"})
	town.zone_c = town.position
	field.rules.town_list.append(town)
	field.rules.capture_town(town, 0)
	field.time = 10.0
	field.rules.victory.on = true
	field.rules.victory.bleed_from = 0.0
	field.rules.victory.points = [400.0, 2.0]
	started = true

func _process(dt: float) -> void:
	if not started:
		return
	elapsed += dt
	# EndBanner and StatsPanel intentionally ignore game speed. Pin their
	# wall-clock input only in this capture fixture, never in gameplay code.
	for node in field.hud.root.get_children() if field.has_view else []:
		if node is EndBanner:
			node._last_ms = Time.get_ticks_msec() - 67
	if field.has_view and field.hud.aar_panel:
		field.hud.aar_panel._last_ms = Time.get_ticks_msec() - 67
	if elapsed >= 14.0:
		if field.winner != 0 or field.report.is_empty():
			TestRun.fail()
		print("OUTCOME CAPTURE winner=%d report=%s" % [field.winner, field.report.get("outcome", "legacy generic result")])
		TestRun.quit(get_tree())
