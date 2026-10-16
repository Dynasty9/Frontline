extends Node
## Player settings (graphics, audio, interface). Saved to user://settings.cfg
## and applied live; the World listens to `changed` for scene-level options.

signal changed

const PATH := "user://settings.cfg"

const PRESETS := {
	"low": {"shadows": 1, "ssao": false, "ao_q": 0, "ssil": false, "gi": false, "vol_fog": false, "glow": true, "aa": 1, "scale": 0.77,
		"upscaler": 1, "grass": 0, "effects": 0, "decals": false, "ragdolls": false, "post": false, "dof": false, "ssr": false, "lod": 0, "aniso": 1},
	"medium": {"shadows": 2, "ssao": true, "ao_q": 1, "ssil": false, "gi": false, "vol_fog": false, "glow": true, "aa": 2, "scale": 1.0,
		"upscaler": 1, "grass": 1, "effects": 1, "decals": true, "ragdolls": true, "post": true, "dof": false, "ssr": false, "lod": 1, "aniso": 2},
	"high": {"shadows": 2, "ssao": true, "ao_q": 2, "ssil": true, "gi": false, "vol_fog": true, "glow": true, "aa": 6, "scale": 1.0,
		"upscaler": 1, "grass": 2, "effects": 2, "decals": true, "ragdolls": true, "post": true, "dof": false, "ssr": true, "lod": 2, "aniso": 3},
	"ultra": {"shadows": 3, "ssao": true, "ao_q": 3, "ssil": true, "gi": true, "vol_fog": true, "glow": true, "aa": 7, "scale": 1.0,
		"upscaler": 1, "grass": 2, "effects": 2, "decals": true, "ragdolls": true, "post": true, "dof": true, "ssr": true, "lod": 2, "aniso": 4},
}

const LABELS := {
	"shadows": ["Off", "Low", "High", "Ultra"],
	"aa": ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA", "SMAA", "MSAA 2x + SMAA", "MSAA 4x + SMAA"],
	"grass": ["Off", "Sparse", "Dense"],
	"effects": ["Low", "Medium", "High"],
	"fps_cap": ["Unlimited", "60", "120", "144", "240"],
	"perf": ["Off", "FPS", "Compact", "Full breakdown"],
	"ao_q": ["Low", "Medium", "High", "Ultra"],
	"upscaler": ["Bilinear", "AMD FSR 1", "AMD FSR 2"],
	"lod": ["Near", "Medium", "Far"],
	"aniso": ["Off", "2x", "4x", "8x", "16x"],
	"window": ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"],
	"look": ["Natural", "Cinematic", "Vivid", "Warm film", "Cold steel", "Bleached war film", "Black & white"],
	"tonemap": ["AgX (filmic, default)", "ACES", "Filmic", "Reinhard"],
	"mmb_mode": ["Turn and tilt", "Pan (grab the map)"],
	"minimap_size": ["Small", "Medium", "Large"],
}
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
## Colour grading looks: [brightness, contrast, saturation, tint]
const LOOKS := [
	[1.0, 1.08, 1.08, Color(1, 1, 1)],
	[0.98, 1.16, 0.92, Color(1.0, 0.97, 0.92)],
	[1.02, 1.12, 1.3, Color(1, 1, 1)],
	[1.0, 1.1, 1.0, Color(1.06, 0.98, 0.88)],
	[0.98, 1.12, 0.85, Color(0.9, 0.97, 1.06)],
	[1.02, 1.22, 0.55, Color(1.0, 0.98, 0.94)],
	[1.0, 1.2, 0.0, Color(1, 1, 1)],
]
const FPS_CAPS := [0, 60, 120, 144, 240]

var preset := "high"
var v := {
	"shadows": 2, "ssao": true, "ssil": true, "gi": false, "vol_fog": true, "glow": true, "aa": 6, "scale": 1.0,
	"grass": 2, "effects": 2, "decals": true, "ragdolls": true, "post": true, "dof": false,
	"vsync": true, "fps_cap": 0, "perf": 1, "shake": true, "ui_scale": 1.0, "mood": "random", "labels": true, "lyr_units": true, "lyr_orders": false, "lyr_intel": true, "lyr_vision": true, "lyr_ranges": false, "orbat": true,
	"ao_q": 2, "upscaler": 1, "sharpen": 0.2, "ssr": true, "lod": 2, "aniso": 3,
	"window": 0, "resolution": 2, "brightness": 1.0, "contrast": 1.0, "look": 0, "tonemap": 0, "fov": 48.0,
	"bubbles": true, "cover_preview": true, "edge_pan": true, "cam_speed": 1.0,
	"zoom_cursor": true, "mmb_mode": 0, "minimap_size": 1, "minimap_rotate": false,
	"coop_show": true,
	"volume": 0.8, "vol_music": 0.6, "vol_effects": 1.0, "vol_ambience": 0.8, "vol_ui": 0.8, "battle_music": true, "mute_bg": false,
}
## Volume sliders -> the mixer bus each one sets.
const VOLUME_BUS := {"volume": "Master", "vol_music": "Music", "vol_effects": "Effects", "vol_ambience": "Ambience", "vol_ui": "Interface"}


func _ready() -> void:
	_load()
	apply_global()
	# the interface follows the window: resizing it or going fullscreen rescales it
	get_tree().root.size_changed.connect(apply_ui_scale)


func get_v(key: String):
	return v.get(key)


func set_v(key: String, value) -> void:
	v[key] = value
	if PRESETS.has(preset) and PRESETS[preset].has(key) and PRESETS[preset][key] != value:
		preset = "custom"
	apply_global()
	save()
	changed.emit()


func apply_preset(p: String, persist := true) -> void:
	if not PRESETS.has(p):
		return
	preset = p
	for k in PRESETS[p]:
		v[k] = PRESETS[p][k]
	apply_global()
	if persist:
		save()
	changed.emit()


## Effect density multiplier for particle systems.
func fx_mult() -> float:
	return [0.35, 0.65, 1.0][int(v.effects)]


func apply_global() -> void:
	var vp := get_tree().root if get_tree() else null
	if vp:
		var aa := int(v.aa)
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED,
			Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(aa, 0, 7)]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else (Viewport.SCREEN_SPACE_AA_SMAA if aa >= 5 else Viewport.SCREEN_SPACE_AA_DISABLED)
		vp.use_taa = aa == 4
		var sc: float = clampf(float(v.scale), 0.5, 1.0)
		vp.scaling_3d_scale = sc
		var up := int(v.upscaler)
		if up == 2:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2  # FSR 2 brings its own temporal AA
		elif up == 1 and sc < 0.99:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		else:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.fsr_sharpness = clampf(2.0 - float(v.sharpen) * 2.0, 0.0, 2.0)
		vp.mesh_lod_threshold = [4.0, 2.0, 1.0][clampi(int(v.lod), 0, 2)]
		if "anisotropic_filtering_level" in vp:
			vp.anisotropic_filtering_level = clampi(int(v.aniso), 0, 4)
		var aq := int(v.ao_q)
		RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
			RenderingServer.ENV_SSAO_QUALITY_HIGH, RenderingServer.ENV_SSAO_QUALITY_ULTRA][clampi(aq, 0, 3)], aq < 2, 0.5, 2, 50.0, 300.0)
		vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][int(v.shadows)]
	var ds: int = [1024, 2048, 4096, 8192][int(v.shadows)]
	RenderingServer.directional_shadow_atlas_set_size(ds, true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v.vsync else DisplayServer.VSYNC_DISABLED)
		_apply_window()
	Engine.max_fps = FPS_CAPS[clampi(int(v.fps_cap), 0, FPS_CAPS.size() - 1)]
	apply_ui_scale()
	_apply_audio()


var _focused := true


## Each volume slider sets its bus. The slider is squared on the way to
## decibels, so its travel feels even: halfway sounds about half as loud
## (a straight line would stay loud until the very end).
func _apply_audio() -> void:
	for k in VOLUME_BUS:
		var bi := AudioServer.get_bus_index(VOLUME_BUS[k])
		if bi < 0:
			continue
		var lv := clampf(float(v[k]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(0.00001, lv * lv)))
		AudioServer.set_bus_mute(bi, lv <= 0.001 or (k == "volume" and v.mute_bg and not _focused))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		_apply_audio()


## The interface's size. At 100% it grows with the window, taking the same
## share of it at any resolution (a 1600 x 900 window draws it at 1.125x,
## 1080p at 1.35x, 1440p at 1.8x, 4K at 2.7x), and the player's scale goes on
## top. It stops growing once it would no longer fit: the battle interface
## still works on a 960 x 540 screen's worth of room, but the menus need a
## full 1280 x 900, so they only grow until they fill the window.
const UI_REF_H := 800.0
const UI_MIN_BATTLE := Vector2(960, 540)
const UI_MIN_MENU := Vector2(1280, 900)
const UI_SCALE_MIN := 0.6

var ui_menu := true  # main.gd: false while a battle is on


func set_ui_menu(on: bool) -> void:
	ui_menu = on
	apply_ui_scale()


## What 100% comes to for this window.
func ui_base() -> float:
	return _win_px().y / UI_REF_H


## The largest scale the player can pick that still fits a battle in this window.
func ui_scale_max() -> float:
	var px := _win_px()
	var fit := minf(px.x / UI_MIN_BATTLE.x, px.y / UI_MIN_BATTLE.y)
	return maxf(1.0, snappedf(fit / ui_base() - 0.025, 0.05))


## The factor the window's 2D content is drawn at.
func ui_factor() -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0  # no window to fit (and the tests lay out as they always have)
	var px := _win_px()
	var lim: Vector2 = UI_MIN_MENU if ui_menu else UI_MIN_BATTLE
	var fit := minf(px.x / lim.x, px.y / lim.y)
	return minf(maxf(ui_base() * clampf(float(v.ui_scale), UI_SCALE_MIN, 4.0), 0.5), fit)


func apply_ui_scale() -> void:
	var vp := get_tree().root if get_tree() else null
	if vp:
		var f := ui_factor()
		if absf(vp.content_scale_factor - f) > 0.001:
			vp.content_scale_factor = f


func _win_px() -> Vector2:
	var vp := get_tree().root if get_tree() else null
	var s := Vector2(vp.size) if vp else Vector2(1600, 900)
	return Vector2(maxf(s.x, 320.0), maxf(s.y, 180.0))


var _win_applied := [-1, -1]


## Room left over the window for its title bar, when deciding whether a size fits.
const TITLE_BAR := 40


## Window mode and windowed size: the player's choice from the moment the game
## opens, then only touched again when one of them changes, so resizing or
## dragging the window isn't undone by every other setting.
func _apply_window() -> void:
	var wm := clampi(int(v.window), 0, 2)
	var ri := clampi(int(v.resolution), 0, RESOLUTIONS.size() - 1)
	if _win_applied[0] == wm and _win_applied[1] == ri:
		return
	var first: bool = _win_applied[0] < 0
	_win_applied = [wm, ri]
	if first and _test_launch():
		return  # test runs keep the project's own window (or the size --resolution asks for)
	if OS.has_feature("web"):
		# the page sizes the game, and the browser only goes fullscreen for a
		# click (so not as the game opens): either kind of fullscreen is its own
		if not first:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if wm > 0 else DisplayServer.WINDOW_MODE_WINDOWED)
		return
	match wm:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			var sz: Vector2i = RESOLUTIONS[ri]
			var scr := DisplayServer.screen_get_usable_rect()
			if sz.x >= scr.size.x or sz.y + TITLE_BAR >= scr.size.y:
				# too big for the screen with its title bar (1920 x 1080 on a 1080p
				# screen): fill the screen instead, title bar and all
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			else:
				if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(sz)
				DisplayServer.window_set_position(scr.position + (scr.size - sz) / 2)


## Started for a test (main.gd reads any `--` switch after `--` as one; a
## frontline:// link from the website isn't). Checked here because this runs
## before main.gd has looked at the command line.
func _test_launch() -> bool:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--"):
			return true
	return false


var no_save := false  # set by automated test runs so they never overwrite the player's settings


func save() -> void:
	if no_save:
		return
	var cf := ConfigFile.new()
	cf.set_value("main", "preset", preset)
	cf.set_value("main", "cfg_version", 2)
	for k in v:
		cf.set_value("main", k, v[k])
	cf.save(PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	preset = String(cf.get_value("main", "preset", preset))
	for k in v:
		v[k] = cf.get_value("main", k, v[k])
	# v2: temporal AA (and FSR 2 at native scale) smeared the procedural
	# surfaces whenever the camera moved; move saved setups to MSAA + SMAA
	if int(cf.get_value("main", "cfg_version", 1)) < 2:
		if int(v.aa) == 4:
			v.aa = 6 if preset != "ultra" else 7
		if int(v.upscaler) == 2 and float(v.scale) >= 0.99:
			v.upscaler = 1
		save()
