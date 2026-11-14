extends Node
## Knocked-out vehicles leave the wrecks every peer builds alike, without map
## generation or rendering: a tank whose ammunition goes up loses its turret,
## which lies beside the hull where the burn reaches it, and every wreck (not
## just a tank's) is sent to the clients with what they need to build it
## burnt out in its own paint.

class WreckNav extends Nav:
	func vkind_at(_p: Vector3, _tracks := false) -> int:
		return Nav.FREE

	func nearest_walkable(p: Vector3, _vehicle := false, _tracks := false) -> Vector3:
		return p


class Field extends World:
	func _ready() -> void:
		has_view = false
		set_process(false)
		set_physics_process(false)

	func ground_y(_p: Vector3) -> float:
		return 0.0

	func fx_event(_ev: Array) -> void:
		pass

	func send_msg(_team: int, _kind: String, _text: String, _ping = null) -> void:
		pass


var field: Field
var checks := 0
var failures := 0


func _ready() -> void:
	TestRun.watch()
	field = Field.new()
	add_child(field)
	field.terrain = TerrainMap.new(field)
	field.rules = Rules.new(field)
	field.nav = WreckNav.new()
	_brew_up()
	_every_wreck_replicates()
	print("VEHICLE WRECKS ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)


func _vehicle(kind: String, at: Vector3) -> Vehicle:
	var v := Vehicle.new()
	v.world = field
	v.srv = true
	v.team = 0
	v.vkind = kind
	v.position = at
	field.add_child(v)
	v.on_spawned()
	v.set_process(false)
	v.scan_t = 10000.0
	return v


## Knocks `kind` out at `at`, its ammunition going up or not (`brew_up`: 1 or
## -1), and returns the wreck it leaves.
func _knock_out(kind: String, at: Vector3, brew_up := 0) -> Structure:
	var v := _vehicle(kind, at)
	v.eid = 5000 + int(at.x)  # (clear of the wrecks' own ids)
	v.brew_up_next = brew_up
	v.take_damage(v.max_hp * 3.0, null)
	for st in field.get_children():
		if st is Structure and st.skind == "wreck" and st.vk == kind and Defs.flat(st.position - at).length() < 1.0:
			return st
	return null


func _brew_up() -> void:
	var before := int(field.stats.get("turret_blown_off", 0))
	var wreck := _knock_out("slammer", Vector3(0, 0, 0), 1)
	_check("a knocked-out tank leaves a wreck", wreck != null)
	if wreck == null:
		return
	_check("its ammunition went up: the turret is off", wreck.turret_off)
	_check("and the clients are told so", wreck.get_props().get("turret_off", false) == true)
	_check("the counter shows it", int(field.stats.get("turret_blown_off", 0)) == before + 1)
	var kept := _knock_out("slammer", Vector3(40, 0, 0), -1)
	_check("a tank whose ammunition didn't go up keeps its turret", kept != null and not kept.turret_off and not kept.get_props().has("turret_off"))
	var truck := _knock_out("technical", Vector3(80, 0, 0), 1)
	_check("a technical has no turret to lose", truck != null and not truck.turret_off)
	# The view: the turret lies beside the hull, on the ground, burnt; a hole where it sat.
	var model := Node3D.new()
	wreck.add_child(model)
	wreck.model = model
	var wk := VehicleModels.build("slammer", 0, int(wreck.wreck_finish.get("seed", 1)), false, true)
	wreck._dress_vehicle(wk)
	var debris := model.get_node_or_null("Debris") as Node3D
	_check("the turret lies among the debris, off the hull", wk.turret != null and debris != null and wk.turret.get_parent() == debris)
	if wk.turret == null or debris == null:
		return
	var box := Structure._bounds_in(wk.turret)
	var lowest := INF
	var highest := -INF
	for i in 8:
		var corner := box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var y := (wk.turret.global_transform * corner).y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	var off := Defs.flat(wk.turret.global_position - wreck.global_position).length()
	_check("thrown clear of the hull (%.1f m out)" % off, off > wreck.size.x * 0.5 + 0.8)
	_check("resting on the ground, bedded in a little (lowest %.2f m)" % lowest, lowest < 0.0 and lowest > -0.5 and highest > 0.4)
	var hole := false
	for c in wk.root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			hole = true
	_check("a black hole in the hull roof where it sat", hole)
	var from := wreck._burn_source
	var lie := (debris.transform * wk.turret.transform).origin
	_check("the burn reaches it where it fell", from.is_finite() and ((lie - from) * Vector3(1.0, 0.74, 1.0)).length() < wreck._wreck_reach * 2.56)
	var soot := false
	for mi: MeshInstance3D in wk.turret.find_children("*", "MeshInstance3D", true, false):
		soot = soot or mi.material_overlay == wreck._wreck_soot
	_check("and it is burnt like the hull", soot)
	wk.root.free()


func _every_wreck_replicates() -> void:
	var x := 120.0
	for kind in ["slammer", "technical", "hemtt", "hunter"]:
		var wreck := _knock_out(kind, Vector3(x, 0, 0), -1)
		x += 40.0
		_check("%s: leaves a wreck" % kind, wreck != null)
		if wreck:
			var props := wreck.get_props()
			_check("%s: the clients are sent its paint, to build it burnt out" % kind, not wreck.wreck_finish.is_empty() and props.get("wreck_finish", {}) == wreck.wreck_finish)
