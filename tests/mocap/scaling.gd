extends "res://scripts/main.gd"
## Rendered crowd check through the real World and SoldierModel paths.
var populated := false
var frames: Array[float] = []
var measured_at := 0
var reported := false
var overlay: CanvasLayer
var view_ms := {}
var render_cpu_ms := 0.0
var render_gpu_ms := 0.0
var pose_updates: Array[int] = []
var pose_times := {}
var pose_modes := {"locomotion":0.0, "prone":0.0, "fallback":0.0}
var fallback_states := {}

var soldier_script: Script

func _ready() -> void:
	super._ready()
	soldier_script = GameScripts.load_script("res://scripts/game/soldier.gd")
	for child in get_children():
		if child.get_script() == preload("res://scripts/ui/perf_overlay.gd"): overlay = child
	assert(overlay != null)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or world.time < 0.2: return
	if not populated:
		populated = true
		var started := Time.get_ticks_msec()
		for i in 12:
			var at := Vector3(-18 + (i % 4) * 12, 0, 12 + (i / 4) * 10)
			world.rules.spawn_squad("rifle_squad", 0, -1, at, at + Vector3(0,0,-12))
		var native := 0
		for man in world.soldiers:
			if man.model != null and man.model.skinned != null: native += 1
		if "--skinned-units" in OS.get_cmdline_user_args(): assert(native >= 48)
		print("SCALING soldiers=", world.soldiers.size(), " skinned=", native, " spawn_ms=", Time.get_ticks_msec()-started)
	if world.time < 5.0 or Engine.time_scale != 1.0: return
	if measured_at == 0:
		measured_at = Time.get_ticks_msec()
		return
	frames.append(dt * 1000.0)
	var updated := 0
	for man in world.soldiers:
		if man.model == null or man.model.rifle_driver == null: continue
		if man.life == soldier_script.Life.ALIVE:
			var mode := "locomotion" if man.model._native_locomotion else ("prone" if man.model._native_prone else "fallback")
			pose_modes[mode] += 1.0
			if mode == "fallback":
				var state: int = int(man.posture) * 100 + int(man.act)
				fallback_states[state] = float(fallback_states.get(state, 0.0)) + 1.0
		var elapsed: float = man.model.rifle_driver.elapsed
		if pose_times.has(man.eid) and elapsed > float(pose_times[man.eid]): updated += 1
		pose_times[man.eid] = elapsed
	pose_updates.append(updated)
	for key in overlay._view_avg:
		view_ms[key] = float(view_ms.get(key, 0.0)) + float(overlay._view_avg[key])
	var viewport := get_viewport().get_viewport_rid()
	render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	render_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	if not reported and Time.get_ticks_msec() - measured_at > 9000:
		reported = true
		frames.sort()
		print("SCALING frame_ms p50=", frames[frames.size()/2], " p95=", frames[int(frames.size()*0.95)], " max=", frames[-1], " samples=", frames.size())
		pose_updates.sort()
		print("SCALING native_standing_crouch_updates min=", pose_updates[0], " median=", pose_updates[pose_updates.size()/2], " p95=", pose_updates[int(pose_updates.size()*0.95)], " max=", pose_updates[-1])
		for mode in pose_modes: pose_modes[mode] /= frames.size()
		print("SCALING mean_live_pose_modes=", pose_modes)
		for state in fallback_states:
			print("SCALING fallback ", soldier_script.Post.keys()[int(state) / 100], "/", soldier_script.Act.keys()[int(state) % 100], " mean=", float(fallback_states[state]) / frames.size())
		for key in view_ms: view_ms[key] /= frames.size()
		print("SCALING mean_view_ms=", view_ms, " render_cpu_ms=", render_cpu_ms / frames.size(), " render_gpu_ms=", render_gpu_ms / frames.size())
