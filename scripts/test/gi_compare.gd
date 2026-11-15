extends Node
## FL_DEBUG_GI_CYCLE=DIR: the ways the game can bounce light, side by side on
## one frozen frame. Once the battle has run FL_DEBUG_GI_AT seconds (6 unless
## set), the world stops and each mode in FL_DEBUG_GI_MODES (all unless set)
## takes the view in turn: it is held long enough for its history to settle,
## its GPU time per frame is averaged over the last half of the hold, and a
## picture of it is saved to DIR/<mode>.png. Then the run quits. The player's
## saved settings are never touched.
##
## Modes: none (no indirect light at all), ssil (the engine's screen-space
## indirect light), sdfgi (its signed-distance-field GI), ssgi1 / ssgi2
## (bounce light at Medium / High), ssil_ssgi2 (both), and
## view_light, view_albedo, view_added (bounce light's debug views).
##
## FL_DEBUG_GI_POSES="name:where:zoom:pitch:yaw;..." runs every mode from each
## of those camera poses in turn (pictures named <pose>_<mode>.png). Where is
## x,z on the map, or found on it: "town" (the town's centre), "ruin" (the
## roofless house nearest it, open to the sky) or "alley" (the narrowest gap
## between two houses near it, looked along; yaw then turns from there).
## Pitch "auto" leaves the camera's own pitch for that zoom.
##
## FL_DEBUG_GI_AB=mode,mode,...: instead of pictures, what each mode costs the
## graphics card over "none". Each is switched on and off every AB_HOLD frames,
## AB_ROUNDS times, so whatever else loads the machine falls on both halves
## alike; the first frames after each switch are left out.
##
## FL_DEBUG_GI_PAN="vx,vz,frames": instead, from the first pose and in the
## first mode, the camera pans at (vx, vz) m/s while the battle runs on, and
## every frame is saved (DIR/pan_000.png...): run it with --fixed-fps 30 for
## frames 1/30 s apart, to see the light hold (or smear) while the view moves.

const MODES := {
	"none": {"ssil": false, "gi": false, "ssgi": 0},
	"ssil": {"ssil": true, "gi": false, "ssgi": 0},
	"sdfgi": {"ssil": false, "gi": true, "ssgi": 0},
	"ssgi1": {"ssil": false, "gi": false, "ssgi": 1},
	"ssgi2": {"ssil": false, "gi": false, "ssgi": 2},
	"ssil_ssgi2": {"ssil": true, "gi": false, "ssgi": 2},
	# bounce light's debug views (FL_DEBUG_SSGI_VIEW): the light alone, the
	# colour estimated for each surface, and what is added (four times over)
	"view_light": {"ssil": false, "gi": false, "ssgi": 2, "view": 1},
	"view_albedo": {"ssil": false, "gi": false, "ssgi": 2, "view": 2},
	"view_added": {"ssil": false, "gi": false, "ssgi": 2, "view": 3},
	"view_rad": {"ssil": false, "gi": false, "ssgi": 2, "view": 4},
	"view_normal": {"ssil": false, "gi": false, "ssgi": 2, "view": 5},
	"view_raw": {"ssil": false, "gi": false, "ssgi": 2, "view": 6},
	"view_hist": {"ssil": false, "gi": false, "ssgi": 2, "view": 7},
}
const HOLD := 90  # frames each mode is held (SDFGI takes a while to converge)

var world: Node
var _dir := OS.get_environment("FL_DEBUG_GI_CYCLE")
var _at := float(OS.get_environment("FL_DEBUG_GI_AT")) if OS.has_environment("FL_DEBUG_GI_AT") else 6.0
var _modes: PackedStringArray = OS.get_environment("FL_DEBUG_GI_MODES").split(",") if OS.has_environment("FL_DEBUG_GI_MODES") \
	else PackedStringArray(MODES.keys())
var _poses: PackedStringArray = OS.get_environment("FL_DEBUG_GI_POSES").split(";", false) if OS.has_environment("FL_DEBUG_GI_POSES") 	else PackedStringArray([""])
var _pose := 0
var _i := -1
var _frames := 0
var _sum := 0.0
var _n := 0
var _ab: PackedStringArray = OS.get_environment("FL_DEBUG_GI_AB").split(",", false)
const AB_HOLD := 30
const AB_SKIP := 8
const AB_ROUNDS := 12
var _ab_i := 0
var _ab_on := false
var _ab_round := 0
var _ab_sum := [0.0, 0.0]
var _ab_n := [0, 0]
var _pan: PackedStringArray = OS.get_environment("FL_DEBUG_GI_PAN").split(",", false)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.no_save = true


func _process(_dt: float) -> void:
	if _i < 0:
		if world == null or float(world.get("time")) < _at:
			return
		DirAccess.make_dir_recursive_absolute(_dir)
		if _pan.size() == 3:
			_i = 0
			_set_pose(_poses[0])
			_apply(_modes[0])
			return
		Engine.time_scale = 0.0
		if not _ab.is_empty():
			_i = 0
			_set_pose(_poses[0])
			_ab_switch()
			return
		_next()
		return
	if not _ab.is_empty():
		_ab_tick()
		return
	if _pan.size() == 3:
		_pan_tick()
		return
	var vp := get_viewport().get_viewport_rid()
	_frames += 1
	if _frames > HOLD >> 1:
		_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_n += 1
	if _frames < HOLD:
		return
	var m := _modes[_i]
	var pose_name := _poses[_pose].get_slice(":", 0)
	if pose_name != "":
		m = pose_name + "_" + m
	get_viewport().get_texture().get_image().save_png(_dir.path_join(m + ".png"))
	print("GICMP %s gpu %.3f ms (%d frames)" % [m, _sum / maxf(_n, 1.0), _n])
	_next()


func _next() -> void:
	_i += 1
	_frames = 0
	_sum = 0.0
	_n = 0
	if _i >= _modes.size():
		_pose += 1
		_i = 0
		if _pose >= _poses.size():
			get_tree().quit()
			return
	if _i == 0:
		_set_pose(_poses[_pose])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_apply(_modes[_i])


func _set_pose(pose: String) -> void:
	var f := pose.split(":")
	var cam: Node = world.get("cam")
	if f.size() < 5 or cam == null:
		return
	var at := Vector3.ZERO
	var yaw := float(f[4])
	var where := f[1]
	if where.contains(","):
		at = Vector3(float(where.get_slice(",", 0)), 0.0, float(where.get_slice(",", 1)))
	else:
		var found: Array = _find(where)
		at = found[0]
		yaw += float(found[1])
	cam.call("focus", at)
	cam.set("target_dist", float(f[2]))
	cam.set("dist", float(f[2]))
	# "auto": the pitch the game itself gives that zoom, as a player sees it
	cam.set("pitch_deg", NAN if f[3] == "auto" else float(f[3]))
	cam.set("yaw", yaw)
	print("GICMP pose %s at %.1f,%.1f yaw %.2f" % [f[0], at.x, at.z, yaw])


## A place on the map worth looking at, and the heading to look at it from.
func _find(what: String) -> Array:
	var town := Vector3.ZERO
	var roofs: Array[Vector3] = []
	var floors: Array[Vector3] = []
	var walls: Array[Vector3] = []
	for st: Node3D in world.get("structures"):
		match String(st.get("skind")):
			"town":
				town = st.position
			"roof":
				roofs.append(st.position)
			"floor":
				floors.append(st.position)
			"house_wall":
				walls.append(st.position)
	var best := town
	var best_yaw := 0.0
	var best_d := INF
	if what == "ruin":
		for fl in floors:
			var roofed := false
			for r in roofs:
				if Vector2(r.x - fl.x, r.z - fl.z).length() < 6.0:
					roofed = true
			var n := 0
			for w in walls:
				if Vector2(w.x - fl.x, w.z - fl.z).length() < 8.0:
					n += 1
			var d := fl.distance_to(town)
			if not roofed and n >= 6 and d < best_d:
				best_d = d
				best = fl
	elif what == "alley":
		# two houses side by side, a narrow way between them (by their roofs)
		for i in roofs.size():
			for j in range(i + 1, roofs.size()):
				var a := roofs[i]
				var b := roofs[j]
				var gap := Vector2(b.x - a.x, b.z - a.z)
				if gap.length() < 9.0 or gap.length() > 15.0:
					continue
				var d := ((a + b) * 0.5).distance_to(town) + gap.length() * 4.0
				if d < best_d:
					best_d = d
					best = (a + b) * 0.5
					var dir := gap.normalized()
					best_yaw = atan2(dir.y, -dir.x)
	return [Vector3(best.x, 0.0, best.z), best_yaw]


func _apply(mode: String) -> void:
	var want: Dictionary = MODES.get(mode, {})
	OS.set_environment("FL_DEBUG_SSGI_VIEW", str(want.get("view", 0)))
	for k in want:
		if k != "view":
			Settings.v[k] = want[k]
	Settings.changed.emit()


func _ab_switch() -> void:
	_frames = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_apply(_ab[_ab_i] if _ab_on else "none")


func _ab_tick() -> void:
	_frames += 1
	var k := 1 if _ab_on else 0
	if _frames > AB_SKIP:
		_ab_sum[k] += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		_ab_n[k] += 1
	if _frames < AB_HOLD:
		return
	_ab_on = not _ab_on
	if not _ab_on:
		_ab_round += 1
	if _ab_round >= AB_ROUNDS:
		var off: float = _ab_sum[0] / maxf(_ab_n[0], 1.0)
		var on: float = _ab_sum[1] / maxf(_ab_n[1], 1.0)
		print("GIAB %s gpu: none %.3f ms, on %.3f ms, costs %.3f ms (%d + %d frames)" % [_ab[_ab_i], off, on, on - off, _ab_n[0], _ab_n[1]])
		_ab_i += 1
		_ab_round = 0
		_ab_sum = [0.0, 0.0]
		_ab_n = [0, 0]
		if _ab_i >= _ab.size():
			get_tree().quit()
			return
	_ab_switch()


func _pan_tick() -> void:
	var cam: Node = world.get("cam")
	var fp: Vector3 = cam.get("focus_pos")
	cam.call("focus", fp + Vector3(float(_pan[0]), 0.0, float(_pan[1])) / 30.0)
	# (the first frames settle the history from scratch: they're kept too)
	get_viewport().get_texture().get_image().save_png(_dir.path_join("pan_%03d.png" % _frames))
	_frames += 1
	if _frames >= int(_pan[2]):
		get_tree().quit()
