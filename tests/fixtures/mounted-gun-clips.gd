extends Node3D
## Every vehicle's mounted guns in the actual showroom battlefield (terrain,
## grass, sky and lighting, High preset), on the game's own models, aimed,
## fired and animated by the game's own code. The same stage on two builds
## gives a matched before/after.
##   --clip=mounted-guns-stills  one vehicle at a time on the same spot: its
##                               main weapon from the front quarter and its
##                               machine gun (or the gun again) from behind
##                               (DIR/<kind>-a.png, DIR/<kind>-b.png)
##   --clip=mounted-guns         a firing line engaging trucks downrange, the
##                               camera close on one gun after another
##                               (DIR/0000.png ..., tools/showcase/capture.py's
##                               contract: 30 frames a game second)
##   --frames=DIR      where the images go
##   --label=TEXT      the caption's first line (e.g. BEFORE / AFTER)
##   --kinds=a,b,c     a different set of vehicles
##   --seconds=S       how long the firing clip runs (default 27)
const SPOT := Vector3(40, 0, 50)  # open ground east of the base
const STILLS: Array[String] = [
	"tank", "slammer", "slammer_up", "rhino", "rhino_up", "old_tank", "varsuk", "kuma", "angara", "angara_k", "futura",
	"ifv", "marshall", "gorgon", "mora", "kamysh", "nyx_ac", "btr", "panther", "bobcat", "cheetah", "tigris", "scorcher", "sochor", "marid",
	"humvee", "hunter_hmg", "hunter_gmg", "strider_hmg", "strider_gmg", "ifrit_hmg", "ifrit_gmg", "prowler_hmg", "prowler_at", "stomper", "nyx_at", "qilin_mg",
	"technical", "offroad_hmg", "mb4wd_lmg", "aa_tech",
	"ghosthawk", "pawnee", "hellcat", "orca_armed", "blackfoot", "kajman", "gunship",
	"speedboat_hmg", "speedboat_minigun", "motorboat", "patrol_ship", "gun_trawler",
]
## The firing line: [kind, seconds the camera holds on it, which gun, its
## mark: "truck" downrange, "air" a helicopter hovering beyond, "side" a truck
## off to the right].
const LINE: Array = [
	["tank", 4.0, "gun", "truck"], ["ifv", 3.0, "mg", "truck"], ["marshall", 3.0, "mg", "truck"], ["hunter_hmg", 3.0, "mg", "air"],
	["technical", 3.0, "mg", "truck"], ["aa_tech", 3.5, "mg", "air"], ["hunter_gmg", 3.0, "mg", "truck"], ["motorboat", 2.5, "mg", "truck"],
	["ghosthawk", 3.0, "mg", "side"],
]
## How long each kind of gun is, roughly, for framing (by its sound).
const GUN_LENGTH := {"mg": 1.2, "minigun": 1.0, "hmg": 1.7, "gmg": 1.2, "ac": 2.8}

var output := ""
var mode := "mounted-guns"
var label := "CURRENT BUILD"
var kinds: Array = []
var seconds := -1.0
var field: World
var camera: Camera3D
var caption: Label
var frame := 0


func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg.begins_with("--kinds="): kinds = Array(arg.get_slice("=", 1).split(","))
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=", 1))
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
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	# Clear the stage: the showroom's own vehicles would wander into frame.
	for v: Vehicle in field.vehicles.duplicate():
		field.despawn(v)
	if mode == "mounted-guns-stills":
		await _stills()
	else:
		await _firing_line()
	print("MOUNTED_GUNS complete")
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit(0)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, field.ground_y(p), p.z)


func _spawn(kind: String, at: Vector3, yaw: float, team := -2) -> Vehicle:
	var side := team
	if side == -2:
		side = maxi(0, int(Defs.VEHICLES[kind].get("team", 0)))
	var v: Vehicle = field.spawn("vehicle", {"vkind": kind, "team": side, "owner": -1, "pos": _ground(at), "yaw": yaw})
	v.order_stop()
	return v


# --- stills -----------------------------------------------------------------------

func _stills() -> void:
	var list: Array = kinds if not kinds.is_empty() else STILLS
	for kind: String in list:
		if not Defs.VEHICLES.has(kind):
			print("MOUNTED_GUNS skip %s (no such vehicle)" % kind)
			continue
		var v := _spawn(kind, SPOT, 0.55)
		v.roe = 2
		# Let the suspension settle and the turret come to rest.
		await _pass(1.2)
		var shots := _framings(v)
		for i in shots.size():
			var s: Array = shots[i]
			camera.global_position = s[0]
			camera.look_at(s[1])
			caption.text = "%s · %s · %s" % [label, v.display_name().to_upper(), String(s[2])]
			await _settle()
			_save("%s-%s" % [kind, "abc"[i]])
		_report(kind, v)
		field.despawn(v)
		await _settle()


## [camera, look-at, what] for the main weapon from its front quarter and the
## machine gun (or the main weapon again) from behind and above, each from
## the vehicle's outer side so the hull never stands between.
func _framings(v: Vehicle) -> Array:
	var out: Array = []
	var vm: VehicleModels = v._vm
	var mg := String(v.vdef.mg).to_upper()
	var mg_len := float(GUN_LENGTH.get(String(Defs.WEAPONS.get(String(v.vdef.mg), {}).get("snd", "mg")), 1.3))
	var centre := v.global_position + Vector3(0, 1.2, 0)
	if vm.gun_tip:
		out.append(_frame(vm.gun_tip.global_position, -vm.gun_tip.global_basis.z, 5.2, 1.0, centre, "MAIN GUN"))
		if vm.roof_gun != Vector3.INF and vm.turret:
			var rg := vm.turret.global_transform * vm.roof_gun
			out.append(_frame(rg - vm.turret.global_basis.z * 0.9, -vm.turret.global_basis.z, 1.7, -1.0, centre, "ROOF MG"))
		elif vm.mg_tip:
			out.append(_frame(vm.mg_tip.global_position, -vm.mg_tip.global_basis.z, mg_len * 1.6, 1.0, centre, mg))
	elif vm.mg_tip:
		out.append(_frame(vm.mg_tip.global_position, -vm.mg_tip.global_basis.z, mg_len, 1.0, centre, mg))
		out.append(_frame(vm.mg_tip.global_position, -vm.mg_tip.global_basis.z, mg_len, -1.0, centre, mg))
		# and the receiver and barrel close to, from the side
		var axis := (-vm.mg_tip.global_basis.z).normalized()
		var at := vm.mg_tip.global_position - axis * mg_len * 0.62
		var side := axis.cross(Vector3.UP).normalized()
		var out_side := -1.0 if side.dot(at - centre) < 0.0 else 1.0
		if absf(side.dot(at - centre)) < 0.3:
			out_side = -1.0
		out.append([at + (side * out_side * 0.85 + Vector3.UP * 0.32 + axis * 0.25).normalized() * (mg_len * 0.55 + 0.25), at, mg + " CLOSE"])
	else:
		out.append([centre + Vector3(8, 4, 8), centre, "NO GUN"])
	return out


## A camera on a gun whose muzzle is at `muzzle`, pointing `axis`: `front` 1
## looks back at it from its front quarter, -1 from behind its breech; from
## the side away from `centre` (the vehicle's middle).
func _frame(muzzle: Vector3, axis: Vector3, length: float, front: float, centre: Vector3, what: String) -> Array:
	axis = axis.normalized()
	var mid := muzzle - axis * length * 0.5
	var side := axis.cross(Vector3.UP).normalized()
	var out := signf(side.dot(mid - centre))
	if absf(side.dot(mid - centre)) < 0.3:
		out = -1.0  # (a gun on the centreline: from its left, the side its belt feeds)
	var dist := length * 1.25 + 0.7
	var at := mid + (axis * 0.55 + side * out * 0.75 + Vector3.UP * 0.42).normalized() * dist
	if front < 0.0:
		at = mid + (-axis * 0.7 + side * out * 0.6 + Vector3.UP * 0.55).normalized() * dist
	return [at, mid, what]


## What a vehicle's model offers to shoot from, for the survey.
func _report(kind: String, v: Vehicle) -> void:
	var vm: VehicleModels = v._vm
	var bits: Array[String] = []
	for name: String in ["mg_tip", "gun_tip", "gun_mount", "turret", "elev"]:
		var n: Node3D = vm.get(name)
		if n:
			bits.append("%s=%s" % [name, str(v.to_local(n.global_position)).replace(" ", "")])
	var mounts: Variant = vm.get("mg_mounts")
	if mounts is Array:
		bits.append("mounts=%d free=%s" % [(mounts as Array).size(), str(vm.get("mg_free"))])
	if vm.roof_gun != Vector3.INF:
		bits.append("roof_gun=%s" % str(vm.roof_gun).replace(" ", ""))
	print("MOUNTED_GUNS %s mg=%s %s" % [kind, String(v.vdef.mg), " ".join(bits)])


# --- the firing line ------------------------------------------------------------

func _firing_line() -> void:
	var line: Array = LINE
	if not kinds.is_empty():
		# (kind or kind:mark)
		line = kinds.map(func(k): return [String(k).get_slice(":", 0), 3.0, "mg", String(k).get_slice(":", 1) if String(k).contains(":") else "truck"])
	var total := 0.0
	for entry: Array in line:
		total += float(entry[1])
	if seconds < 0.0:
		seconds = total
	var guns: Array[Vehicle] = []
	var marks: Array[Vehicle] = []
	hover.clear()
	for i in line.size():
		var at := SPOT + Vector3(i * 16.0, 0, 0)
		var v := _spawn(String(line[i][0]), at, 0.0, 0)
		guns.append(v)
		# Its mark: a truck downrange, a little off its line of fire, or a
		# helicopter hovering beyond it, or a truck off to its right.
		var mark: Vehicle
		match String(line[i][3]):
			"air":
				mark = _spawn("hellcat", at + Vector3(4.0, 0, -50.0), 0.0, 1)
				mark.position.y = field.ground_y(mark.position) + 30.0
			"side":
				mark = _spawn("hemtt", at + Vector3(42.0, 0, -6.0), 0.0, 1)
			_:
				mark = _spawn("hemtt", at + Vector3(6.0 if i % 2 == 0 else -6.0, 0, -48.0), PI * 0.5, 1)
		mark.roe = 2
		marks.append(mark)
		hover.append(mark.position)
	# The guns find their marks and lay on them before the camera rolls.
	await _pass(4.0, marks)
	var t := 0.0
	var shot := -1
	var until := 0.0
	var holding: Vehicle = null
	while t < seconds:
		if t >= until and shot + 1 < line.size():
			if holding:
				_report_lay(holding)
			shot += 1
			holding = guns[shot]
			until += float(line[shot][1])
			caption.text = "%s · %s · %s" % [label, holding.display_name().to_upper(), String(Defs.WEAPONS.get(String(holding.vdef.mg), {}).get("name", "")).to_upper()]
			holding.mg_t = 0.0
			holding.mg_burst = 0
			if holding.vdef.cannon:
				holding.cannon_t = 0.8
		if holding and is_instance_valid(holding):
			_follow(holding, String(line[shot][2]))
			if holding.is_heli():
				holding.target = marks[shot]
				_door_gun(holding, marks[shot])
		await _step(marks)
		_save("%04d" % frame)
		frame += 1
		t += 1.0 / 30.0
	if holding:
		_report_lay(holding)


## How the gun it held on was laid, for the log.
func _report_lay(v: Vehicle) -> void:
	var mounts: Variant = v._vm.get("mg_mounts")
	var lay: Array[String] = []
	if mounts is Array:
		for m: Node3D in mounts:
			lay.append("(%.2f, %.2f)" % [m.rotation.x, m.rotation.y])
	print("MOUNTED_GUNS laid %s target=%s turret=%.2f mounts=%s" % [v.vkind, v.target.vkind if v.target is Vehicle else str(v.target), v.turret_yaw, " ".join(lay)])


## Holds the camera on a gun as the turret lays it.
func _follow(v: Vehicle, which: String) -> void:
	var vm: VehicleModels = v._vm
	var tip: Node3D = vm.gun_tip if which == "gun" and vm.gun_tip else vm.mg_tip
	if tip == null:
		return
	var length := 5.2 if tip == vm.gun_tip else float(GUN_LENGTH.get(String(Defs.WEAPONS.get(String(v.vdef.mg), {}).get("snd", "mg")), 1.3))
	var s := _frame(tip.global_position, -tip.global_basis.z, length, 1.0, v.global_position + Vector3(0, 1.2, 0), "")
	# A little wider than a still, so the muzzle blast has room.
	var look: Vector3 = s[1]
	camera.global_position = look + ((s[0] as Vector3) - look) * (1.1 if tip == vm.gun_tip else 1.35)
	camera.look_at(look + (-tip.global_basis.z) * length * 0.3)


## Helicopters on the ground don't fire on their own: their door gunner
## works through bursts as the AI would in the air.
var _door_t := 0.0
var _door_burst := 0


func _door_gun(v: Vehicle, mark: Vehicle) -> void:
	_door_t -= 1.0 / 30.0
	if _door_t > 0.0:
		return
	var w: Dictionary = Defs.WEAPONS[String(v.vdef.mg)]
	if _door_burst <= 0:
		_door_burst = field.rng.randi_range(w.burst.x, w.burst.y)
	_door_burst -= 1
	field.combat.fire_bullet(v, v.weapon_muzzle("mg"), mark.center_point(), mark, w, 1.0)
	_door_t = maxf(float(w.interval), 1.0 / 30.0) if _door_burst > 0 else 0.7


## Lets `seconds` of game time pass, keeping the marks standing.
func _pass(span: float, marks: Array = []) -> void:
	var until := field.time + span
	while field.time < until:
		await _step(marks)


var hover: Array[Vector3] = []  # where each mark is kept


func _step(marks: Array) -> void:
	for i in marks.size():
		var m: Vehicle = marks[i]
		if is_instance_valid(m) and not m.gone:
			m.hp = m.max_hp
			if m.is_heli():
				m.position = hover[i]
	await RenderingServer.frame_post_draw


func _settle() -> void:
	for i in 6:
		await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	if output.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))
