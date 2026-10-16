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
	"vsync": true, "fps_cap": 0, "perf": 1, "shake": true, "volume": 0.8, "ui_scale": 1.0, "mood": "random", "labels": true, "lyr_units": true, "lyr_orders": false, "lyr_intel": true, "lyr_ranges": false, "orbat": true,
	"ao_q": 2, "upscaler": 1, "sharpen": 0.2, "ssr": true, "lod": 2, "aniso": 3,
	"window": 0, "resolution": 2, "brightness": 1.0, "contrast": 1.0, "look": 0, "tonemap": 0, "fov": 48.0,
	"bubbles": true, "cover_preview": true, "edge_pan": true, "cam_speed": 1.0,
	"zoom_cursor": true, "mmb_mode": 0, "minimap_size": 1, "minimap_rotate": false,
	"coop_show": true,
}


func _ready() -> void:
	_load()
	apply_global()


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
	if vp:
		vp.content_scale_factor = clampf(float(v.ui_scale), 0.6, 2.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(v.volume))))


var _win_applied := [-1, -1]


## Window mode and windowed resolution (only touched when they change, so
## dragging the window around isn't undone by every other setting).
func _apply_window() -> void:
	var wm := clampi(int(v.window), 0, 2)
	var ri := clampi(int(v.resolution), 0, RESOLUTIONS.size() - 1)
	if _win_applied[0] == wm and _win_applied[1] == ri:
		return
	var first: bool = _win_applied[0] < 0
	_win_applied = [wm, ri]
	if first and wm == 0 and no_save:
		return  # test runs keep the project's own window
	match wm:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if not first:
				var sz: Vector2i = RESOLUTIONS[ri]
				var scr := DisplayServer.screen_get_usable_rect()
				sz = Vector2i(mini(sz.x, scr.size.x), mini(sz.y, scr.size.y))
				DisplayServer.window_set_size(sz)
				DisplayServer.window_set_position(scr.position + (scr.size - sz) / 2)


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
