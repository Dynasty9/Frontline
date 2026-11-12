extends Node
## Photo mode gives back everything it borrowed: the camera, the battle's speed
## (held as the pause key holds it alone, and as the replay's own speed holds a
## replay; never in multiplayer), the interface, every value of the look, and
## it never writes a setting. A small world stands in for the battle: the real
## commander's camera, director, input, replay player, and the real
## Atmosphere's environment, lens and film look, with no map under them.

class Field extends World:
	func _ready() -> void:
		has_view = true
		set_process(false)
		set_physics_process(false)

	func ground_y(_p: Vector3) -> float:
		return 0.0


## The battle's look with no ground to light: a new time of day only relights the sky and the grade.
class Look extends Atmosphere:
	var moods_applied: Array = []

	func apply_mood(m: String) -> void:
		moods_applied.append(m)
		mood = m
		_d = MOODS[m]
		env.tonemap_exposure = base_exposure()
		_apply_look()


class QuietHud extends Hud:
	func _ready() -> void:
		pass

	func _process(_dt: float) -> void:
		pass


class FakeMain extends Node:
	var world: Node = null

	func return_to_menu(_msg: String) -> void:
		pass


var failures := 0
var checks := 0
var settings_changed := 0
var field: Field
var photo: PhotoMode


func _check(what: String, ok: bool, detail := "") -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PHOTO_MODE FAIL: %s %s" % [what, detail])


func _ready() -> void:
	Settings.no_save = true
	Settings.changed.connect(func(): settings_changed += 1)
	field = Field.new()
	field.srv = true
	field.settings = {"seed": 1}
	add_child(field)
	var atmo := Look.new()
	atmo.world = field
	atmo.mood = "golden"
	atmo._d = Atmosphere.MOODS.golden
	atmo._build_env()
	atmo._build_post()
	atmo.set_process(false)
	field.add_child(atmo)
	field.atmo = atmo
	atmo._apply_look()
	# as the battle has them after its first bake, with the film look and tilt-shift on
	var post := atmo.post_rect.material as ShaderMaterial
	post.set_shader_parameter("vignette", 0.15)
	post.set_shader_parameter("grain", 0.006)
	atmo.post_layer.visible = true
	atmo.cam_attr.dof_blur_far_enabled = true
	atmo.cam_attr.dof_blur_far_distance = 74.0
	atmo.cam_attr.dof_blur_far_transition = 49.5
	atmo.cam_attr.dof_blur_near_enabled = true
	atmo.cam_attr.dof_blur_near_distance = 30.0
	atmo.cam_attr.dof_blur_near_transition = 16.5
	atmo.cam_attr.dof_blur_amount = 0.06
	field.cam = RtsCamera.new()
	field.cam.world = field
	field.add_child(field.cam)
	field.cam.edge_pan = false  # (no mouse here to push the view about)
	field.cam.focus(Vector3(40, 0, -25))
	field.director = Director.new()
	field.director.world = field
	field.add_child(field.director)
	field.director.set_process(false)  # (its shots would move the camera: whether it's on is what matters)
	field.input = PlayerInput.new()
	field.input.world = field
	field.add_child(field.input)
	field.input.set_process(false)  # (its drawing wants a whole HUD; the keys and clicks are what matter here)
	field.hud = QuietHud.new()
	field.hud.world = field
	field.add_child(field.hud)
	photo = PhotoMode.new()
	photo.world = field
	field.add_child(photo)
	field.photo = photo
	await _frames(3)
	await _alone()
	await _shared()
	await _replay()
	_keys()
	_check("no setting was changed", settings_changed == 0, str(settings_changed))
	if failures == 0:
		print("PHOTO_MODE passed (%d checks)" % checks)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Everything photo mode may touch, as it stands.
func _state() -> Dictionary:
	var a := field.atmo
	var ca := a.cam_attr
	var post := a.post_rect.material as ShaderMaterial
	var cam := field.cam.cam
	return {
		"cam": cam.global_transform, "fov": cam.fov, "near": cam.near,
		"rts": [field.cam.is_processing(), field.cam.is_processing_unhandled_input(), field.cam.focus_pos, field.cam.dist, field.cam.yaw],
		"input": [field.input.is_processing(), field.input.is_processing_unhandled_input()],
		"director": [field.director.active, field.director.speed_i],
		"time_scale": Engine.time_scale,
		"hud": field.hud.visible,
		"mood": a.mood,
		"env": [a.env.tonemap_exposure, a.env.adjustment_enabled, a.env.adjustment_brightness, a.env.adjustment_contrast, a.env.adjustment_saturation],
		"post": [a.post_layer.visible, post.get_shader_parameter("vignette"), post.get_shader_parameter("grain"), post.get_shader_parameter("tint")],
		"dof": [ca.dof_blur_far_enabled, ca.dof_blur_far_distance, ca.dof_blur_far_transition, ca.dof_blur_near_enabled,
			ca.dof_blur_near_distance, ca.dof_blur_near_transition, ca.dof_blur_amount],
		"lens": [a.look_override.duplicate(), a.look_v("lens"), a.look_v("film"), a.look_v("shafts")],
		"settings": Settings.v.duplicate(true), "preset": Settings.preset,
		"mouse": Input.mouse_mode,
		"scale": [get_viewport().scaling_3d_scale, get_viewport().scaling_3d_mode],
	}


func _same(what: String, before: Dictionary, after: Dictionary) -> void:
	for k in before:
		_check("%s: %s back as it was" % [what, k], str(before[k]) == str(after[k]), "%s -> %s" % [str(before[k]), str(after[k])])


## Every value of the picture moved off where it started, and the lens flown somewhere else.
func _dress() -> void:
	for kv in [["fov", 24.0], ["focus", 12.0], ["blur", 0.8], ["exposure", 1.5], ["mood", "night"], ["look", 3],
			["contrast", 1.2], ["saturation", 0.4], ["vignette", 0.6], ["grain", 0.15], ["show_fog", true], ["roll", 12.0],
			["lens", not bool(Settings.get_v("lens"))], ["film", not bool(Settings.get_v("film"))], ["shafts", "on"]]:
		photo.set_value(kv[0], kv[1])
	photo.pos += Vector3(30, 8, -60)
	photo.yaw += 1.2
	photo.pitch = -0.3


## Alone (offline, or a solo battle's private host): photo mode holds the battle as the pause key does.
func _alone() -> void:
	field.director.active = true  # (watching through the director, as a spectator would)
	field.director.set_speed_index(4)  # (and at double speed)
	var before := _state()
	_check("alone, photo mode would pause", photo.can_pause())
	_check("photo mode opens", photo.enter())
	await _frames(2)
	_check("the battle holds still", Engine.time_scale == 0.0 and field.director.speed_i == 0, "%s %d" % [Engine.time_scale, field.director.speed_i])
	_check("held the way the pause key holds it", photo.held == "director", photo.held)
	_check("the interface goes", not field.hud.visible)
	_check("the commander's camera and hands are off", not field.cam.is_processing() and not field.cam.is_processing_unhandled_input()
		and not field.input.is_processing_unhandled_input())
	_check("the director lets go of the camera", not field.director.active)
	_check("the panel is up", photo.panel != null and is_instance_valid(photo.panel) and photo.panel.is_inside_tree())
	_dress()
	await _frames(2)
	var a := field.atmo
	var cam := field.cam.cam
	_check("the lens is where it was flown", cam.global_position.distance_to(photo.pos) < 0.01, str(cam.global_position))
	_check("its field of view", is_equal_approx(cam.fov, 24.0), str(cam.fov))
	_check("its roll", absf(cam.global_rotation.z - deg_to_rad(12.0)) < 0.01, str(cam.global_rotation))
	_check("its focus is real depth of field", a.cam_attr.dof_blur_far_enabled and a.cam_attr.dof_blur_near_enabled
		and a.cam_attr.dof_blur_near_distance < 12.0 and a.cam_attr.dof_blur_far_distance > 12.0, "%s %s" % [a.cam_attr.dof_blur_near_distance, a.cam_attr.dof_blur_far_distance])
	_check("the time of day changes", a.mood == "night")
	_check("exposure in stops over the night's own", is_equal_approx(a.env.tonemap_exposure, a.base_exposure() * pow(2.0, 1.5)), str(a.env.tonemap_exposure))
	_check("the grade, its contrast and saturation", is_equal_approx(a.env.adjustment_contrast, float(Settings.LOOKS[3][1]) * 1.2)
		and is_equal_approx(a.env.adjustment_saturation, float(Settings.LOOKS[3][2]) * 0.4), "%s %s" % [a.env.adjustment_contrast, a.env.adjustment_saturation])
	var post := a.post_rect.material as ShaderMaterial
	_check("the camera-and-lens passes are photo mode's own while it's open", a.look_v("lens") == (not bool(Settings.get_v("lens")))
		and a.look_v("film") == (not bool(Settings.get_v("film"))) and a.look_v("shafts") == true, str(a.look_override))
	_check("vignette and grain", is_equal_approx(float(post.get_shader_parameter("vignette")), 0.6) and is_equal_approx(float(post.get_shader_parameter("grain")), 0.15))
	_check("values stay inside what a lens can do", photo.fov >= PhotoMode.FOV_MIN and photo.fov <= PhotoMode.FOV_MAX)
	photo.set_value("fov", 500.0)
	_check("a field of view too wide is held to the widest", photo.fov == PhotoMode.FOV_MAX, str(photo.fov))
	photo.pos.y = -40.0
	await _frames(2)
	_check("the lens never goes into the ground", photo.pos.y >= PhotoMode.MIN_CLEAR - 0.001, str(photo.pos.y))
	photo.exit()
	await _frames(2)
	_same("alone", before, _state())
	_check("the old time of day came back", a.moods_applied.back() == "golden", str(a.moods_applied))
	_check("photo mode closed", not photo.active and photo.panel == null)
	field.director.set_speed_index(3)
	field.director.active = false


## Multiplayer (other players connected to this host): the camera comes off, the battle never stops.
func _shared() -> void:
	field.ready_peers = [2]
	var before := _state()
	_check("with company, photo mode wouldn't pause", not photo.can_pause())
	_check("photo mode opens in multiplayer", photo.enter())
	await _frames(2)
	_check("the battle goes on", Engine.time_scale == 1.0 and field.director.speed_i == 3, "%s %d" % [Engine.time_scale, field.director.speed_i])
	_check("nothing holds it", photo.held == "", photo.held)
	_check("the camera still comes off its orbit", not field.cam.is_processing())
	_dress()
	await _frames(2)
	photo.toggle()
	await _frames(2)
	_same("multiplayer", before, _state())
	field.ready_peers = []


## A replay: its own speed holds it, its controls go, and both come back.
func _replay() -> void:
	field.settings["replay"] = true
	var main := FakeMain.new()
	add_child(main)
	var rp: Node = load("res://scripts/game/replay_player.gd").new()
	rp.main = main
	add_child(rp)
	await _frames(2)
	photo.replay = rp
	var before := _state()
	_check("a replay can be held", photo.can_pause())
	_check("photo mode opens in a replay", photo.enter())
	await _frames(2)
	_check("the replay holds still", float(rp.speed) == 0.0 and Engine.time_scale == 0.0, "%s %s" % [rp.speed, Engine.time_scale])
	_check("held by the replay's own speed", photo.held == "replay", photo.held)
	_check("the replay's controls go", not rp.visible)
	_dress()
	photo.exit()
	await _frames(2)
	_check("the replay plays on at its speed", float(rp.speed) == 1.0 and Engine.time_scale == 1.0, "%s %s" % [rp.speed, Engine.time_scale])
	_check("its controls come back", rp.visible)
	_same("replay", before, _state())
	field.settings.erase("replay")
	photo.replay = null
	rp.queue_free()
	main.queue_free()
	await _frames(1)


## The keys: bound by default, not clashing with each other or the interface's.
func _keys() -> void:
	for id in ["photo_mode", "photo_capture", "photo_rise", "photo_sink", "photo_roll_left", "photo_roll_right", "photo_level", "photo_slow"]:
		_check("%s is bound" % id, Keys.has(id) and Keys.label(id) != "", id)
		_check("%s clashes with nothing" % id, Keys.clashes(id, Keys.get_bind(id, 0)).is_empty(), str(Keys.clashes(id, Keys.get_bind(id, 0))))
	_check("the photo mode key reaches it from the battle", "photo_mode" in PlayerInput.KEY_ACTIONS)
	_check("a photo key may share a key with an order", Keys.clashes("photo_rise", KEY_E).is_empty() and Keys.clashes("photo_capture", KEY_SPACE).is_empty())
	_check("but not with the interface's keys", not Keys.clashes("photo_capture", KEY_F1).is_empty())
	_check("a picture's name says when it was taken", PhotoMode.shot_name({"year": 2026, "month": 11, "day": 3, "hour": 9, "minute": 5, "second": 7}) == "frontline-2026-11-03-090507")
