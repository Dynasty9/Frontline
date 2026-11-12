class_name PhotoMode
extends Node
## Photo mode (F9 to begin with): what a war photographer has that a
## commander hasn't. A solo battle or a replay holds still, the way the pause
## key holds it; in multiplayer the fighting goes on, since the host never waits
## for one player's picture. The interface goes, and the lens leaves its orbit
## to fly wherever a photographer could stand, down in the grass or up on a
## crane, the horizon tipped a little if he likes. Then the lens, the light and
## the film: field of view, where it focuses and how soft the rest falls,
## exposure, the time of day, a grade, vignette and grain. The picture is a PNG
## in the screenshots folder, drawn at up to twice the resolution and scaled
## down if asked (a cleaner edge on every wire and barrel).
##
## Everything here belongs to the view and goes when photo mode does: the
## camera, the battle's speed, the interface and every value are put back as
## they were found, and the player's settings are never written (nothing here
## calls Settings.set_v). The simulation is only ever held the way the pause key
## holds it (the director's speed, or the replay's), never by anything else.

signal changed  # a value changed (the panel follows)
signal captured(path: String, where: String)  # a picture taken: the file, and where a player finds it

const FOV_MIN := 15.0
const FOV_MAX := 90.0
const FOCUS_MIN := 0.5  # metres
const FOCUS_MAX := 600.0
const EXPOSURE_EV := 3.0  # stops either way
const MIN_CLEAR := 0.6  # the lens stays this far over the ground...
const MAX_RISE := 260.0  # ...and no further up than this
const MAP_MARGIN := 120.0  # how far past the map's edge it may wander
const PITCH_LIMIT := 85.0  # degrees up or down
const ROLL_LIMIT := 45.0  # degrees either way
const ROLL_RATE := 35.0  # degrees a second
const LOOK_RATE := 0.0032  # radians a pixel of mouse, at a 50 degree lens (finer zoomed in)
const NEAR := 0.1  # the lens goes close: grass and a rifle a pace off stay drawn
const SUPERSAMPLE := 2.0  # the render scale of a supersampled picture
const SUPERSAMPLE_MAX_PX := 7680.0  # ...as long as its long side stays within this
const SHOTS_DIR := "user://screenshots"
## The times of day, in the order the panel lists them.
const MOODS := ["day", "golden", "dawn", "dusk", "overcast", "hazy", "night", "rain"]
## The camera-and-lens passes (Settings > Lighting & Look): flare and glare,
## sun shafts, local exposure, eye adaptation, the film look, heat haze. The
## desktop renderer's only; photo mode turns them on and off for its picture.
const LENS_KEYS := ["lens", "shafts", "local_exp", "eye_adapt", "film", "heat_haze"]

var world: World
var active := false
## The replay player (main.gd's replay_viewer) when this world is a replay: its
## speed is what holds a replay still.
var replay: Node = null
var panel: PhotoPanel = null

# the free camera: where the lens is, which way it looks (radians), its tilt
var pos := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var _vel := Vector3.ZERO
var _looking := false
var _look_from := Vector2.ZERO
var _last_ms := 0

# the picture, as the panel sets it
var fov := 48.0
var focus := 40.0  # where the lens focuses (m)
var blur := 0.0  # how soft what's out of focus goes, 0 (all sharp) to 1 (wide open)
var exposure := 0.0  # stops over the time of day's own
var mood := ""
var look := 0  # Settings.LOOKS
var contrast := 1.0
var saturation := 1.0
var vignette := 0.0
var grain := 0.0
var show_fog := false  # the fog of war's shading on the ground (only the drawing)
var lens_fx := {}  # LENS_KEYS -> on, photo mode's own (Atmosphere.look_override while it's open)
var supersample := true
## How the battle is held: "director" (the pause key's speed), "replay", or ""
## (multiplayer: it goes on).
var held := ""

var _saved := {}
var _entered_frame := -1
var _capturing := false
var _capture_undo := []  # while a picture is being taken: [render scale, scaling mode, [layers hidden]]
var last_size := Vector2i.ZERO  # the last picture's size in pixels
## The depth of field's blur is so many pixels of the render: drawn at twice
## the size, it's widened to match, or the picture would come out sharper
## than the view it was framed on.
var _dof_scale := 1.0
var _winner0 := -1


func _ready() -> void:
	# after the atmosphere and the camera each frame, so the picture's values are the last word
	process_priority = 10
	set_process(false)


## Whether entering would hold the battle still: alone (a solo battle, offline)
## or in a replay, as the pause key can.
func can_pause() -> bool:
	if _replay() != null:
		return true
	if world.director == null or not world.director.can_control_time():
		return false
	# a host with anyone else in the battle, even a player still loading it,
	# never stops for a picture (a solo battle's private host is LocalServer's)
	return LocalServer.connected or not world.srv or world.multiplayer.get_peers().is_empty()


func _replay() -> Node:
	if replay != null and is_instance_valid(replay):
		return replay
	if world.settings.get("replay", false):
		var m := get_tree().root.get_node_or_null("Main") if is_inside_tree() else null
		var rv: Variant = m.get("replay_viewer") if m != null else null
		if rv is Node and is_instance_valid(rv):
			replay = rv
			return replay
	return null


## Opens photo mode. False if it can't (no camera, the battle not drawn yet, or over).
func enter() -> bool:
	if active or world.cam == null or world.cam.cam == null or world.atmo == null or world.client_loading():
		return false
	if world.winner >= 0 and _replay() == null:
		return false  # (the end of the battle has its own screen)
	var a := world.atmo
	var cam := world.cam.cam
	var post := a.post_rect.material as ShaderMaterial
	var ca := a.cam_attr
	_saved = {
		"cam": cam.transform, "fov": cam.fov, "near": cam.near, "h": cam.h_offset, "v": cam.v_offset,
		"mood": a.mood, "exposure": a.env.tonemap_exposure,
		"adjust": [a.env.adjustment_enabled, a.env.adjustment_brightness, a.env.adjustment_contrast, a.env.adjustment_saturation],
		"post": a.post_layer.visible,
		"shader": [post.get_shader_parameter("vignette"), post.get_shader_parameter("grain"), post.get_shader_parameter("tint")],
		"dof": [ca.dof_blur_far_enabled, ca.dof_blur_far_distance, ca.dof_blur_far_transition, ca.dof_blur_near_enabled,
			ca.dof_blur_near_distance, ca.dof_blur_near_transition, ca.dof_blur_amount],
		"fog": world.fog.hidden if world.fog else false,
		"hud": world.hud.visible if world.hud else false,
		"director": world.director.active if world.director else false,
		"user_moved": world.cam.user_moved,
		"speed_i": world.director.speed_i if world.director else 3,
		"mouse": Input.mouse_mode,
		"layers": [],
		"look_override": a.look_override.duplicate(),
	}
	# the battle holds still, the way the pause key holds it
	held = ""
	var rp := _replay()
	if rp != null and rp.has_method("photo_hold"):
		rp.photo_hold(true)
		held = "replay"
	elif can_pause():
		world.director.set_speed_index(0)
		held = "director"
	if world.director:
		world.director.active = false
	# the interface goes: the HUD, and the overlays the game keeps outside the battle
	if world.hud:
		world.hud.visible = false
	var perf := get_tree().root.get_node_or_null("Main/PerfOverlay") if is_inside_tree() else null
	if perf is CanvasLayer:
		_saved.layers.append([perf, perf.visible])
		perf.visible = false
	if world.input:
		world.input.suspend(true)
	world.cam.suspend(true)
	# the lens starts where the commander's camera was, looking the same way
	pos = cam.global_position
	var f := -cam.global_basis.z
	yaw = atan2(-f.x, -f.z)
	pitch = clampf(asin(clampf(f.y, -1.0, 1.0)), -deg_to_rad(PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))
	roll = 0.0
	_vel = Vector3.ZERO
	_last_ms = 0
	fov = cam.fov
	focus = clampf(world.cam.dist, FOCUS_MIN, FOCUS_MAX)
	blur = 0.0
	exposure = 0.0
	mood = a.mood
	look = clampi(int(Settings.get_v("look")), 0, Settings.LOOKS.size() - 1)
	contrast = float(Settings.get_v("contrast"))
	saturation = 1.0
	vignette = float(_param(post, "vignette")) if a.post_layer.visible else 0.0
	grain = float(_param(post, "grain")) if a.post_layer.visible else 0.0
	show_fog = false
	lens_fx = {}
	for k in LENS_KEYS:
		lens_fx[k] = bool(a.look_v(k))
	supersample = can_supersample()
	cam.near = NEAR
	if not _compatibility():
		# a round, smooth bokeh for the picture (the battle's default is cheaper)
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
		RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)
	active = true
	_winner0 = world.winner
	_entered_frame = Engine.get_process_frames()
	set_process(true)
	panel = PhotoPanel.new()
	panel.name = "PhotoPanel"
	panel.photo = self
	add_child(panel)
	_apply_view()
	_apply_lens()
	changed.emit()
	return true


## Closes photo mode and puts everything back as it was found.
func exit() -> void:
	if not active:
		return
	active = false
	set_process(false)
	_end_look()
	_undo_capture()
	var a := world.atmo
	if is_instance_valid(a):
		if a.mood != String(_saved.mood):
			a.apply_mood(String(_saved.mood))
		a.env.tonemap_exposure = float(_saved.exposure)
		a.env.adjustment_enabled = bool(_saved.adjust[0])
		a.env.adjustment_brightness = float(_saved.adjust[1])
		a.env.adjustment_contrast = float(_saved.adjust[2])
		a.env.adjustment_saturation = float(_saved.adjust[3])
		a.post_layer.visible = bool(_saved.post)
		var post := a.post_rect.material as ShaderMaterial
		post.set_shader_parameter("vignette", _saved.shader[0])
		post.set_shader_parameter("grain", _saved.shader[1])
		post.set_shader_parameter("tint", _saved.shader[2])
		var ca := a.cam_attr
		var d: Array = _saved.dof
		ca.dof_blur_far_enabled = bool(d[0])
		ca.dof_blur_far_distance = float(d[1])
		ca.dof_blur_far_transition = float(d[2])
		ca.dof_blur_near_enabled = bool(d[3])
		ca.dof_blur_near_distance = float(d[4])
		ca.dof_blur_near_transition = float(d[5])
		ca.dof_blur_amount = float(d[6])
		a.look_override = _saved.look_override
		a._apply_cinematic()
	if not _compatibility():
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(int(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_shape", 1)))
		RenderingServer.camera_attributes_set_dof_blur_quality(int(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_quality", 1)),
			bool(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_use_jitter", false)))
	if world.fog and is_instance_valid(world.fog):
		world.fog.set_hidden(bool(_saved.fog))
	if world.cam and is_instance_valid(world.cam):
		var cam := world.cam.cam
		cam.transform = _saved.cam
		cam.fov = float(_saved.fov)
		cam.near = float(_saved.near)
		cam.h_offset = float(_saved.h)
		cam.v_offset = float(_saved.v)
		world.cam.suspend(false)
		world.cam.user_moved = bool(_saved.user_moved)
	if world.input and is_instance_valid(world.input):
		world.input.suspend(false)
	if world.hud and is_instance_valid(world.hud):
		world.hud.visible = bool(_saved.hud)
	for lv in _saved.layers:
		if is_instance_valid(lv[0]):
			lv[0].visible = bool(lv[1])
	var d := world.director
	if d and is_instance_valid(d):
		d.active = bool(_saved.director)
	match held:
		"replay":
			var rp := _replay()
			if rp != null:
				rp.photo_hold(false)
		"director":
			var i := int(_saved.speed_i)
			if d and is_instance_valid(d):
				d.set_speed_index(i)
				if d.speed_i != i:
					# (it can no longer say: never leave a battle stopped that we stopped)
					d.speed_i = i
					Engine.time_scale = maxf(0.0001, Director.SPEEDS[i]) if i > 0 else 0.0
	held = ""
	Input.mouse_mode = _saved.mouse
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	changed.emit()


func toggle() -> void:
	if active:
		exit()
	else:
		enter()


func _exit_tree() -> void:
	# the battle closing under photo mode: what lives outside it goes back too
	exit()


## The panel sets a value: clamped to what a lens or a grade can do, and shown at once.
func set_value(key: String, v: Variant) -> void:
	match key:
		"fov":
			fov = clampf(float(v), FOV_MIN, FOV_MAX)
		"focus":
			focus = clampf(float(v), FOCUS_MIN, FOCUS_MAX)
		"blur":
			blur = clampf(float(v), 0.0, 1.0)
		"exposure":
			exposure = clampf(float(v), -EXPOSURE_EV, EXPOSURE_EV)
		"mood":
			var m := String(v)
			if Atmosphere.MOODS.has(m):
				mood = m
		"look":
			look = clampi(int(v), 0, Settings.LOOKS.size() - 1)
		"contrast":
			contrast = clampf(float(v), 0.5, 1.5)
		"saturation":
			saturation = clampf(float(v), 0.0, 2.0)
		"vignette":
			vignette = clampf(float(v), 0.0, 1.0)
		"grain":
			grain = clampf(float(v), 0.0, 0.2)
		"show_fog":
			show_fog = _on(v)
		"supersample":
			supersample = _on(v) and can_supersample()
		"roll":
			roll = clampf(deg_to_rad(float(v)), -deg_to_rad(ROLL_LIMIT), deg_to_rad(ROLL_LIMIT))
		_:
			if not key in LENS_KEYS:
				return
			lens_fx[key] = _on(v)
			if active:
				_apply_lens()
	if active:
		_apply_view()
	changed.emit()


static func _on(v: Variant) -> bool:
	return v if v is bool else String(v).to_lower() in ["1", "true", "on"]


## The lens passes as photo mode has them, over the player's settings (the
## atmosphere refuses them itself where the renderer can't draw them).
func _apply_lens() -> void:
	world.atmo.look_override = lens_fx.duplicate()
	world.atmo._apply_cinematic()


func has_lens() -> bool:
	return CinematicFx.supported()


## Depth of field and a round bokeh are the desktop renderer's: the browser's
## (Compatibility) has neither.
func has_dof() -> bool:
	return not _compatibility()


func can_supersample() -> bool:
	return DisplayServer.get_name() != "headless"


static func _compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## A shader uniform's value: the one set, or the shader's own default.
static func _param(m: ShaderMaterial, uname: String) -> Variant:
	var v: Variant = m.get_shader_parameter(uname)
	if v == null and m.shader:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), uname)
	return v if v != null else 0.0


func _process(_dt: float) -> void:
	if not active:
		return
	if world.winner >= 0 and _winner0 < 0 and _replay() == null:
		exit()  # the battle's over: its end screen comes up instead
		return
	# real time: the battle is usually stopped, the lens isn't
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else 0.016
	_last_ms = now
	_fly(dt)
	_apply_view()


func _typing() -> bool:
	return Keys.capturing or Keys.console_open or get_viewport().gui_get_focus_owner() is LineEdit


## WASD (the camera's pan keys) fly the way the lens looks, the rise and sink
## keys straight up and down; it eases in and out like a camera on a slider,
## faster the higher it is, and never into the ground or off past the map.
func _fly(dt: float) -> void:
	var want := Vector3.ZERO  # in the lens's own frame: x right, y up (the world's), z back
	var spin := 0.0
	var fast := false
	var slow := false
	if not _typing() and not _capturing:
		if Keys.held("cam_up"):
			want.z -= 1.0
		if Keys.held("cam_down"):
			want.z += 1.0
		if Keys.held("cam_left"):
			want.x -= 1.0
		if Keys.held("cam_right"):
			want.x += 1.0
		if Keys.held("photo_rise"):
			want.y += 1.0
		if Keys.held("photo_sink"):
			want.y -= 1.0
		if Keys.held("photo_roll_left"):
			spin += 1.0
		if Keys.held("photo_roll_right"):
			spin -= 1.0
		fast = Keys.held("cam_fast")
		slow = Keys.held("photo_slow")
	if spin != 0.0:
		var lim := deg_to_rad(ROLL_LIMIT)
		roll = clampf(roll + spin * deg_to_rad(ROLL_RATE) * dt * (0.3 if slow else 1.0), -lim, lim)
	var ground := world.ground_y(pos)
	var spd := clampf(4.0 + (pos.y - ground) * 0.6, 4.0, 90.0) * float(Settings.get_v("cam_speed"))
	spd *= (3.0 if fast else 1.0) * (0.2 if slow else 1.0)
	var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var target := (look.x * want.x + look.z * want.z).limit_length(1.0) * spd + Vector3.UP * want.y * spd
	_vel = _vel.lerp(target, 1.0 - exp(-dt * 9.0))
	if want == Vector3.ZERO and _vel.length_squared() < 0.0004:
		_vel = Vector3.ZERO
	pos += _vel * dt
	var lim_xz := MapDims.HALF + MAP_MARGIN
	pos.x = clampf(pos.x, -lim_xz, lim_xz)
	pos.z = clampf(pos.z, -lim_xz, lim_xz)
	ground = world.ground_y(pos)
	pos.y = clampf(pos.y, ground + MIN_CLEAR, ground + MAX_RISE)


## The camera, the lens, the light and the film as they're set now. Each frame
## while photo mode is on, so nothing else that frame (the tilt-shift the
## settings give, a bake of the ground's light after a new time of day) has
## the last word on the picture.
func _apply_view() -> void:
	var a := world.atmo
	var cam := world.cam.cam
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	cam.fov = fov
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	if mood != a.mood:
		a.apply_mood(mood)
	a.env.tonemap_exposure = a.base_exposure() * pow(2.0, exposure)
	a.apply_grade(look, contrast, saturation)
	var post := a.post_rect.material as ShaderMaterial
	post.set_shader_parameter("vignette", vignette)
	post.set_shader_parameter("grain", grain)
	a.post_layer.visible = bool(_saved.post) or vignette > 0.001 or grain > 0.0005
	if world.fog:
		world.fog.set_hidden(not show_fog)
	var ca := a.cam_attr
	var on := blur > 0.001 and has_dof()
	ca.dof_blur_far_enabled = on
	ca.dof_blur_near_enabled = on
	if on:
		# a lens focused at `focus`: sharp a little either side, the sharp
		# band thinner and the fall-off quicker the wider it's open, and
		# shallower in front of the focus than behind, as through a real lens
		var depth := focus * lerpf(0.3, 0.03, blur)
		ca.dof_blur_far_distance = focus + depth
		ca.dof_blur_far_transition = maxf(0.3, focus * lerpf(1.5, 0.3, blur))
		ca.dof_blur_near_distance = maxf(0.05, focus - depth)
		ca.dof_blur_near_transition = maxf(0.05, (focus - depth) * lerpf(0.8, 0.4, blur))
		ca.dof_blur_amount = minf(1.0, lerpf(0.03, 0.25, blur) * _dof_scale)


func _unhandled_input(ev: InputEvent) -> void:
	if not active or _capturing:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed and not _looking:
					# hold a button and drag to look round (the cursor stays where it was)
					_looking = true
					_look_from = get_viewport().get_mouse_position()
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				elif not mb.pressed and _looking and not _any_look_button():
					_end_look()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					set_value("fov", fov / 1.06)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					set_value("fov", fov * 1.06)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and _looking:
		var mm := ev as InputEventMouseMotion
		var k := LOOK_RATE * fov / 50.0
		yaw -= mm.screen_relative.x * k
		pitch = clampf(pitch - mm.screen_relative.y * k, -deg_to_rad(PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey or ev is InputEventMouseButton:
		if not ev.is_pressed() or ev.is_echo() or _typing():
			return
		if ev.is_action_pressed("ui_cancel"):
			exit()
			get_viewport().set_input_as_handled()
			return
		match Keys.action_for(ev, ["photo_mode", "photo_capture", "photo_level", "hide_hud"]):
			"photo_mode":
				if Engine.get_process_frames() != _entered_frame:
					exit()
			"photo_capture":
				capture()
			"photo_level":
				set_value("roll", 0.0)
			"hide_hud":
				if panel:
					panel.toggle_sheet()
			_:
				return
		get_viewport().set_input_as_handled()


func _any_look_button() -> bool:
	for b in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(b):
			return true
	return false


func _end_look() -> void:
	if not _looking:
		return
	_looking = false
	Input.mouse_mode = _saved.get("mouse", Input.MOUSE_MODE_VISIBLE)
	if DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(_look_from)


# --- the picture -----------------------------------------------------------------------------

## Takes the picture: the panel and every overlay off for a frame (the film
## look stays: it's part of the picture), drawn at twice the resolution if
## asked, and saved. In a browser it's handed to the player as a download too,
## since a page's own storage is out of their reach.
func capture() -> void:
	if not active or _capturing:
		return
	_capturing = true
	var vp := get_viewport()
	var hidden: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible and cl != world.atmo.post_layer and cl.get_viewport() == vp:
			hidden.append(cl)
			cl.visible = false
	_capture_undo = [vp.scaling_3d_scale, vp.scaling_3d_mode, hidden]
	var ss := supersample and can_supersample()
	if ss:
		var px := Vector2(vp.size)
		var k := minf(SUPERSAMPLE, SUPERSAMPLE_MAX_PX / maxf(1.0, maxf(px.x, px.y)))
		ss = k > 1.05
		if ss:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = k
			_dof_scale = k / maxf(0.01, float(_capture_undo[0]))
			_apply_view()
	# one frame for the overlays to go (and a bigger buffer to be made), one drawn clean
	for i in 2:
		await RenderingServer.frame_post_draw
	if not _capturing:
		return  # (photo mode closed meanwhile, and put it all back)
	var img := vp.get_texture().get_image()
	_undo_capture()
	if img == null or img.is_empty():
		captured.emit("", "Nothing was drawn to save.")
		return
	var file := shot_name(Time.get_datetime_dict_from_system())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS_DIR))
	var path := SHOTS_DIR.path_join(file + ".png")
	var n := 2
	while FileAccess.file_exists(path):
		path = SHOTS_DIR.path_join("%s-%d.png" % [file, n])
		n += 1
	var err := img.save_png(path)
	if err != OK:
		captured.emit("", "Couldn't save the picture (error %d)." % err)
		return
	var where := ProjectSettings.globalize_path(path)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), path.get_file(), "image/png")
		where = "your downloads"
	if OS.has_environment("FL_DEBUG_PHOTO"):
		print("PHOTO saved %s %dx%d" % [path, img.get_width(), img.get_height()])
	last_size = img.get_size()
	captured.emit(path, where)


## Puts back what taking a picture changed: the render scale, and the overlays hidden for it.
func _undo_capture() -> void:
	if not _capturing:
		return
	_capturing = false
	_dof_scale = 1.0
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(_capture_undo[0])
		vp.scaling_3d_mode = _capture_undo[1]
	for cl in _capture_undo[2]:
		if is_instance_valid(cl):
			cl.visible = true
	_capture_undo = []


## A picture's file name from the local date and time: frontline-2026-11-11-153012.
static func shot_name(t: Dictionary) -> String:
	return "frontline-%04d-%02d-%02d-%02d%02d%02d" % [int(t.get("year", 0)), int(t.get("month", 0)), int(t.get("day", 0)),
		int(t.get("hour", 0)), int(t.get("minute", 0)), int(t.get("second", 0))]


# --- what the panel reads out ----------------------------------------------------------------

## Height over the ground, compass heading and roll, as the panel shows them.
func readout() -> String:
	var alt := pos.y - world.ground_y(pos)
	var hdg := fposmod(-rad_to_deg(yaw), 360.0)
	return "ALT %s M  HDG %03d°  ROLL %+d°" % [("%.1f" % alt) if alt < 100.0 else str(roundi(alt)), roundi(hdg) % 360, roundi(rad_to_deg(roll))]
