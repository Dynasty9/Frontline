extends Node3D
## Wrecked vehicles in the actual showroom battlefield (terrain, grass, sky
## and lighting, High preset): one of each kind of hull in a row - a main
## battle tank, a tracked IFV, an 8x8 APC, an MRAP, a technical, a truck and a
## helicopter - all knocked out at once, the game's own death and fire code
## doing the rest. Stills while they burn and again once they've burnt out,
## the whole row and each wreck close up, so the same stage on two builds
## gives a matched before/after.
##   --frames=DIR   where the stills go (burning-wide.png, burning-<kind>.png,
##                  out-wide.png, out-<kind>.png)
##   --label=TEXT   the caption (e.g. BEFORE / AFTER)
##   --kinds=a,b,c  a different row
const ORIGIN := Vector3(40, 0, 50)  # the row starts on open ground east of the base
const SPACING := 15.0
var output := ""
var label := "CURRENT BUILD"
var kinds: Array = ["slammer", "panther", "marshall", "hunter", "technical", "hemtt", "ghosthawk"]
var field: World
var wrecks: Array = []  # [kind, ground point]
var camera: Camera3D
var caption: Label


func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg.begins_with("--kinds="): kinds = Array(arg.get_slice("=", 1).split(","))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	seed(712)
	Settings.apply_preset("high", false)
	Settings.v.dof = false
	field = World.new()
	field.settings = {"scenario": "showroom", "seed": 712, "mood": "day", "map_size": 1024, "players": {}, "ai_teams": []}
	add_child(field)
	await field.build()
	while field.cam == null or field.building:
		await get_tree().process_frame
	field.cam.set_process(false)
	field.input.set_process(false)
	field.hud.visible = false
	if field.director:
		field.director.active = false
	camera = field.cam.cam
	camera.fov = 40.0
	var vehicles: Array = []
	for i in kinds.size():
		var p := ORIGIN + Vector3(i * SPACING, 0, 0)
		p.y = field.ground_y(p)
		var v: Vehicle = field.spawn("vehicle", {"vkind": String(kinds[i]), "team": 0 if i % 2 == 0 else 1, "owner": -1, "pos": p, "yaw": 0.5})
		v.order_stop()
		vehicles.append(v)
		wrecks.append([String(kinds[i]), p])
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	_wide()
	print("VEHICLE_WRECKS_WARMUP")
	for i in 48:
		await RenderingServer.frame_post_draw
	for v: Vehicle in vehicles:
		if is_instance_valid(v) and not v.gone:
			v.take_damage(v.max_hp * 3.0, null)
	# Let the fires take hold (quickly: these frames aren't kept).
	await _pass(12.0, 4.0)
	await _shots("burning", "BURNING")
	# ...and burn themselves out, the smoke thinning away.
	await _pass(100.0, 10.0)
	await _shots("out", "BURNT OUT")
	print("VEHICLE_WRECKS complete")
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit(0)


## Lets `seconds` of game time pass, `speed` times faster than it plays.
func _pass(seconds: float, speed: float) -> void:
	Engine.time_scale = speed
	var until := field.time + seconds
	while field.time < until:
		await RenderingServer.frame_post_draw
	Engine.time_scale = 1.0


func _shots(prefix: String, state: String) -> void:
	_wide()
	caption.text = "%s · %s · %.0f s AFTER" % [label, state, field.time - 0.0]
	await _settle()
	_save(prefix + "-wide")
	for w in wrecks:
		var at: Vector3 = w[1]
		var off := Vector3(6.5, 3.6, 8.5)
		# from three-quarters on, off the wreck's own flank (a helicopter's
		# fallen where its crash took it, and its tail can fill the frame)
		var wreck: Structure = null
		for s: Structure in field.structures_near(at, 12.0):
			if s.skind == "wreck" and (wreck == null or s.global_position.distance_to(at) < wreck.global_position.distance_to(at)):
				wreck = s
		if wreck and OS.has_environment("FL_DEBUG_WRECK"):
			for d in wreck.find_children("*", "Decal", true, false):
				print("DECAL ", w[0], " at ", (d as Decal).global_position, " size ", (d as Decal).size, " vis ", (d as Decal).is_visible_in_tree(), " ground ", field.ground_y(wreck.global_position), " tex ", (d as Decal).texture_albedo != null)
		if wreck:
			at = wreck.global_position
			var reach := maxf(wreck.size.x, wreck.size.z) * 0.62 + 5.0
			off = (wreck.global_basis.x * 0.8 - wreck.global_basis.z * 0.6).normalized() * reach + Vector3(0, reach * 0.45, 0)
		camera.global_position = at + off
		camera.look_at(at + Vector3(0, 1.0, 0))
		caption.text = "%s · %s · %s" % [label, state, String(w[0]).to_upper()]
		await _settle()
		_save(prefix + "-" + String(w[0]))


func _wide() -> void:
	var mid: Vector3 = ORIGIN + Vector3((kinds.size() - 1) * SPACING * 0.5, 0, 0)
	mid.y = field.ground_y(mid)
	camera.global_position = mid + Vector3(8, 26, 52)
	camera.look_at(mid + Vector3(0, 1, 0))


func _settle() -> void:
	for i in 6:
		await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	if output.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))
