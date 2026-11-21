extends Node3D
## Matched controlled encounter: destroy two Humvees with a Technical between
## them. Real vehicle damage, battle events, HUD notices and wreck effects.
var field: World
var elapsed := 0.0
var started := false
var vehicles: Array[Vehicle] = []
var next := 0

func _ready() -> void:
	TestRun.watch()
	Online.record_battles = false
	Settings.apply_preset("low", false)
	Settings.v.perf = 0
	Settings.v.reduce_motion = OS.get_environment("FL_REDUCED") == "1"
	field = World.new()
	field.settings = {"scenario": "attack", "scenario_player": true, "seed": 3, "mood": "day", "map_size": 1024, "players": {1: {"team": 0, "name": "Commander"}}, "ai_teams": []}
	add_child(field)
	await field.build()
	if field.has_view:
		field.cam.focus(Vector3(0, 0, -5))
		field.cam.target_dist = 90.0
		field.cam.dist = 90.0
		field.input.set_process(false)
	for i in 3:
		var v: Vehicle = field.spawn("vehicle", {"vkind": "technical" if i == 1 else "humvee", "team": 1, "owner": -2, "pos": Vector3(-22 + 22 * i, 0, -5), "yaw": 0.4})
		# Keep incidental crossfire from changing the scripted event order.
		v.hp = 1000000.0
		vehicles.append(v)
	print("FEEDBACK READY drawn=%d reduced=%s" % [Engine.get_frames_drawn(), str(UiMotion.reduced())])
	started = true

func _process(dt: float) -> void:
	if not started:
		return
	elapsed += dt
	if next < 3 and elapsed >= 2.0 + next * 1.4:
		vehicles[next].take_damage(2000000.0, null)
		next += 1
		print("FEEDBACK EVENT n=%d elapsed=%.3f drawn=%d rows=%s" % [next, elapsed, Engine.get_frames_drawn(), str(field.hud.moments.items) if field.has_view else "headless"])
	if elapsed >= 9.0:
		print("FEEDBACK CAPTURE destroyed=%d" % next)
		if field.has_view:
			print("FEEDBACK ROWS %s" % str(field.hud.moments.items))
		TestRun.quit(get_tree())
