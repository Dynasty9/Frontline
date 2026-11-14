extends Node
## --gpu-bench[=out.json]: what each graphics setting costs the graphics card.
##
## The battle is held still (the simulation off, the camera where --focus /
## --zoom put it, the interface hidden), so the processor isn't what limits
## the frame and the picture doesn't change while it's measured. Then each
## setting that is on is turned off and on again several times in turn (off,
## on, off, on...), in short blocks, and the GPU time of each frame is read
## from the renderer. Whatever else uses the graphics card meanwhile (another
## game, a video) falls on both halves alike, and it only ever adds time, so
## each block counts by its quicker frames (one a fifth of the way up from the quickest),
## not its middle one. Each on block sits between two off blocks (off, on,
## off, on, ... off), and is set against their average, so load that grows or
## fades steadily through the three cancels out. The setting's cost is the
## median of those differences, and the middle half of them is the measure's
## own noise. The frames just after a
## switch are left out: the renderer reports a frame's GPU time a frame or two
## late, and global illumination, water, grass and shadows rebuild.
##
## This is a stationary cost, not the cost of an advancing battle. Time passes
## is reported separately as unmeasured: its relighting work needs a moving clock.
## Start it on the settings to be priced (--preset=cinematic enables them).
## Render scale is in the list as a control: halving the pixels must save far
## more than the noise, or the numbers aren't to be trusted (the run says so).
## Nothing here is saved, and the settings are put back before the run ends.
##   --gpu-bench-at=S      seconds into the battle to start (8)
##   --gpu-bench-frames=N  frames measured in each block (20; the settle is 2/5 of it, at least 6)
##   --gpu-bench-cycles=N  off/on pairs per setting (10)
##   --gpu-bench-only=a,b  just these settings

## [setting, the value it's tried at, what that is]: the console's bench list,
## and the scenery and lighting settings it leaves out.
const EXTRA := [
	["shadow_fit", false, "Adaptive shadows off"],
	["cloud_shadows", false, "Cloud shadows on units off"],
	["terrain_reflections", false, "Mountain reflections off"],
	["mountain_clouds", 0, "Mountain clouds off"],
	["alpine_haze", false, "Alpine distance haze off"],
	["decals", false, "Scorch marks off"],
]
const CONTROL := "scale"
## Do not toggle these in a frozen scene and mistake the settled frames for
## their running cost. Keep the reason in both the console and JSON report.
const DYNAMIC := {
	"time_passes": "The battle clock is held still; sky relighting, terrain-shadow rebakes and reflection recaptures need advancing battle time.",
}
## Settings that take longer to settle once switched: global illumination
## rebuilds its cascades over many frames, water and grass their meshes.
const SLOW := {"gi": 6, "water": 2, "grass": 2, "lod": 2, "terrain_reflections": 3, "shadows": 2}
## Which frame of a block counts: the quicker ones, as other work only adds time.
const QUICK := 0.2

var world: Node
var out := ""
var frames := 20
var cycles := 10
var only: PackedStringArray = []

var _settle := 24
var _orig := {}
var _no_save := true
var _plan := []  # [key, off value, label]
var _i := -1  # the setting being priced (-1: the baseline)
var _block := 0  # off, on, off, on, ... off
var _wait := 0
var _carry := 1
var _take: PackedFloat32Array = []
var _blocks: Array[float] = []  # each block's quick frame time, in order
var _base: PackedFloat32Array = []
var _results := []
var _unmeasured := []
var _battle_time := 0.0
var _rid: RID


func _ready() -> void:
	_settle = maxi(6, frames * 2 / 5)
	_orig = Settings.v.duplicate()
	_no_save = Settings.no_save
	Settings.no_save = true
	_battle_time = float(world.get("time"))
	for key in DYNAMIC:
		if bool(_orig.get(key, false)) and (only.is_empty() or key in only):
			_unmeasured.append({"key": key, "reason": DYNAMIC[key], "requires": "advancing_battle_clock"})
	var bench: Array = (load("res://scripts/ui/console_cmds.gd") as Script).get_script_constant_map()["BENCH"]
	for b in bench + EXTRA:
		var key: String = b[0]
		if DYNAMIC.has(key) or key.begins_with("(") or not Settings.v.has(key) or (not only.is_empty() and not key in only and key != CONTROL):
			continue
		var cur: Variant = Settings.v[key]
		if key == CONTROL:
			if float(cur) > 0.55:
				_plan.append(b)
		elif cur != b[1]:
			_plan.append(b)
	# hold the battle: no simulation, no moving camera, no interface
	var director: Node = world.get("director")
	if director and director.can_control_time():
		director.set_speed_index(0)
	else:
		Engine.time_scale = 0.0
	var hud: Node = world.get("hud")
	if hud and hud.get("root"):
		hud.root.visible = false
	# uncapped, so a frame's GPU time is its own and not a share of a vsync wait
	Settings.v.vsync = false
	Settings.v.fps_cap = 0
	Settings.apply_global()
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	print("GPUBENCH %d settings, %d off/on pairs of %d frames each, on %s" % [_plan.size(), cycles, frames, _gpu_name()])
	_wait = _settle


func _process(_dt: float) -> void:
	if _wait > 0:
		_wait -= 1
		return
	_take.append(RenderingServer.viewport_get_measured_render_time_gpu(_rid))
	if _take.size() < frames:
		return
	if _i < 0:
		_base = _take.duplicate()
		print("GPUBENCH baseline %.2f ms a frame (quick %.2f, middle half %.2f)" % [_median(_base), _quick(_base), _spread(_base)])
		_next_setting()
		return
	_blocks.append(_quick(_take))
	_block += 1
	if _block <= cycles * 2:
		_switch(_block % 2 == 1)
		return
	_finish_setting()
	_next_setting()


func _next_setting() -> void:
	_i += 1
	_blocks.clear()
	_block = 0
	if _i >= _plan.size():
		_done()
		return
	_switch(false)


## off (the bench value) or on (as it was).
func _switch(on: bool) -> void:
	var step: Array = _plan[_i]
	Settings.v[step[0]] = _orig[step[0]] if on else step[1]
	Settings.apply_global()
	Settings.changed.emit()
	_take.clear()
	# (as long as the slower of this setting and the one just put back needs)
	_wait = _settle * maxi(int(SLOW.get(step[0], 1)), _carry)
	_carry = 1


func _finish_setting() -> void:
	var step: Array = _plan[_i]
	var diffs: Array[float] = []
	var offs: Array[float] = []
	var ons: Array[float] = []
	for k in range(1, _blocks.size() - 1, 2):
		ons.append(_blocks[k])
		offs.append(_blocks[k - 1])
		diffs.append(_blocks[k] - (_blocks[k - 1] + _blocks[k + 1]) * 0.5)
	offs.append(_blocks[_blocks.size() - 1])
	# (the run ended on an off block: the setting goes back as it was)
	Settings.v[step[0]] = _orig[step[0]]
	Settings.apply_global()
	Settings.changed.emit()
	_carry = int(SLOW.get(step[0], 1))
	diffs.sort()
	var n := diffs.size()
	var cost := diffs[n >> 1]
	var spread := diffs[(n * 3) >> 2] - diffs[n >> 2] if n >= 4 else diffs[n - 1] - diffs[0]
	var r := {"key": step[0], "label": step[2], "on": _orig[step[0]], "off": step[1], "cost_ms": cost, "spread_ms": spread,
		"on_ms": _median_of(ons), "off_ms": _median_of(offs), "pairs": diffs}
	_results.append(r)
	print("GPUBENCH %s %+7.2f ms  (%.2f on, %.2f off, spread %.2f)%s" % [String(step[2]).rpad(34), cost, r.on_ms, r.off_ms, spread,
		"" if absf(cost) > maxf(spread, 0.05) else "  within noise"])


func _done() -> void:
	Settings.v = _orig.duplicate()
	Settings.apply_global()
	Settings.changed.emit()
	var restored := true
	for k in _orig:
		if Settings.v[k] != _orig[k]:
			restored = false
	Settings.no_save = _no_save
	# the control: halving the pixels must stand well clear of the noise
	var noise := 0.0
	var control := {}
	for r in _results:
		noise = maxf(noise, float(r.spread_ms))
		if r.key == CONTROL:
			control = r
	var sound: bool = not control.is_empty() and float(control.cost_ms) > maxf(1.0, 3.0 * float(control.spread_ms))
	_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cost_ms) > float(b.cost_ms))
	print("GPUBENCH what each setting costs, the most first (baseline %.2f ms, %s):" % [_median(_base), _gpu_name()])
	for r in _results:
		print("GPUBENCH   %s %+7.2f ms  spread %.2f" % [String(r.label).trim_suffix(" off").trim_suffix(" on Low").rpad(34), r.cost_ms, r.spread_ms])
	for r in _unmeasured:
		print("GPUBENCH %s NOT MEASURED: %s" % [r.key, r.reason])
	if DisplayServer.get_name() == "headless":
		print("GPUBENCH headless: no GPU time to read, so this run only checked itself")
	elif control.is_empty():
		print("GPUBENCH control: render scale was already at 50% or below, so nothing checks the measure")
	else:
		print("GPUBENCH control %s: render scale 100%% costs %.2f ms over 50%% (spread %.2f)" % ["ok" if sound else "FAILED, the numbers are noise",
			control.cost_ms, control.spread_ms])
	var size := Vector2i(get_viewport().get_visible_rect().size)
	var report := {"gpu": _gpu_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"api": RenderingServer.get_video_adapter_api_version(), "size": [size.x, size.y], "scale": float(_orig.get(CONTROL, 1.0)),
		"frames": frames, "settle": _settle, "cycles": cycles, "quick_fraction": QUICK, "baseline_ms": _median(_base),
		"baseline_quick_ms": _quick(_base), "baseline_spread_ms": _spread(_base),
		"control_ok": sound, "restored": restored, "no_save": Settings.no_save, "cinematic_keys": Settings.CINEMATIC_KEYS, "mood": String(world.get("atmo").mood) if world.get("atmo") else "",
		"scope": "stationary", "battle_time_start": _battle_time, "battle_time_end": float(world.get("time")),
		"settings": _results, "unmeasured_settings": _unmeasured}
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, "  "))
			print("GPUBENCH report written to %s" % out)
	if not restored:
		push_error("GPUBENCH didn't put the settings back")
	print("GPUBENCH done")
	TestRun.quit(get_tree())


func _gpu_name() -> String:
	return "%s %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()]


static func _median(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() >> 1]


static func _median_of(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() >> 1]


## The frame QUICK of the way up from the quickest.
static func _quick(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[int(float(s.size() - 1) * QUICK)]


## The middle half of the frames (from the first quarter to the last): a frame's own wobble.
static func _spread(a: PackedFloat32Array) -> float:
	if a.size() < 4:
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[(s.size() * 3) >> 2] - s[s.size() >> 2]
