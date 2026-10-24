class_name HumanoidGait
extends RefCounted
## Shared contact / passing / lift poses for the procedural rig. Animation
## resources are shared by all men; sampling them needs no per-man scene tree.
## The keys deliberately linger on the planted leg rather than swing like a pendulum.

static var library: AnimationLibrary


static func _ensure_library() -> void:
	if library != null:
		return
	library = AnimationLibrary.new()
	for gait in ["walk", "run"]:
		var clip := Animation.new()
		clip.length = 1.0
		clip.loop_mode = Animation.LOOP_LINEAR
		var thigh := [0.95, 0.55, 0.05, -0.5, -0.9, -0.75, -0.15, 0.7, 0.95]
		var knee := [0.12, 0.08, 0.04, 0.08, 0.24, 0.85, 1.0, 0.5, 0.12]
		if gait == "run":
			thigh = [1.0, 0.65, 0.0, -0.7, -1.0, -0.6, 0.25, 0.85, 1.0]
			knee = [0.3, 0.15, 0.08, 0.2, 0.65, 1.0, 0.85, 0.5, 0.3]
		for values in [thigh, knee]:
			var track := clip.add_track(Animation.TYPE_VALUE)
			clip.track_set_path(track, NodePath("thigh" if track == 0 else "knee"))
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
			for i in values.size():
				clip.track_insert_key(track, float(i) / 8.0, float(values[i]))
		library.add_animation(gait, clip)


static func leg(phase: float, running: float) -> Vector2:
	_ensure_library()
	var at := fposmod(phase / TAU, 1.0)
	var walk := library.get_animation("walk")
	var run := library.get_animation("run")
	return Vector2(lerpf(float(walk.value_track_interpolate(0, at)), float(run.value_track_interpolate(0, at)), running),
		clampf(lerpf(float(walk.value_track_interpolate(1, at)), float(run.value_track_interpolate(1, at)), running), 0.0, 1.0))
