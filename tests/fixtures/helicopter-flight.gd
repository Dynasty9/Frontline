extends Node
## Exercise real flight and vehicle phases without map generation or rendering.

class FlightNav extends Nav:
	func vkind_at(_p: Vector3) -> int:
		return Nav.FREE

	func nearest_walkable(p: Vector3, _vehicle := false) -> Vector3:
		return p


class FlightRules extends Rules:
	var destinations: Array = []
	var delivered := 0

	func fobs(_team: int, _include_wrecked := true) -> Array:
		return destinations

	func note_income(_team: int, amount: int) -> void:
		delivered += amount


class Field extends World:
	var floor_height := 0.0

	func _ready() -> void:
		has_view = false
		set_process(false)
		set_physics_process(false)

	func ground_y(_p: Vector3) -> float:
		return floor_height

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
	field.rules = FlightRules.new(field)
	field.nav = FlightNav.new()
	for hz in [30, 60]:
		_dynamics(hz)
		_phases(hz)
		_retask(hz)
	_replication()
	var a := _trajectory(30)
	var b := _trajectory(60)
	var repeat := _trajectory(30)
	_check("identical inputs repeat exactly", a == repeat)
	_check("30/60 Hz position agrees within half a metre", a.distance_to(b) < 0.5)
	print("HELICOPTER FLIGHT ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)


func _vehicle(kind := "hummingbird", altitude := 16.0) -> Vehicle:
	var v := Vehicle.new()
	v.world = field
	v.team = 0
	v.vkind = kind
	v.position = Vector3(0, altitude, 0)
	field.add_child(v)
	v.on_spawned()
	v.set_process(false)
	v.scan_t = 10000.0
	return v


func _dynamics(hz: int) -> void:
	var dt := 1.0 / hz
	var v := _vehicle()
	_check("spawn creates helicopter controller", v.flight != null)
	var bounds := true
	for i in hz * 3:
		var old := v.velocity
		var yaw := v.rotation.y
		v._fly_to(Vector3(0, 16, -500), dt)
		bounds = bounds and Defs.flat(v.velocity - old).length() <= 8.0 * dt + 0.0001
		bounds = bounds and absf(wrapf(v.rotation.y - yaw, -PI, PI)) <= 1.8 * dt + 0.0001
	_check("acceleration and yaw bounds", bounds)
	_check("forward acceleration pitches nose down", v.flight_pitch < -0.05)
	var before := v.velocity
	v._fly_to(Vector3(0, 16, 500), dt)
	_check("reversal preserves forward momentum", v.velocity.dot(before) > 0.0)
	_check("reversal acceleration bounded", (v.velocity - before).length() <= 8.0 * dt + 0.0001)
	for i in hz / 2:
		v._fly_to(v.position, dt, 0.0)
	_check("braking flares nose up", v.flight_pitch > 0.05)
	v.free()
	v = _vehicle()
	v.velocity = Vector3(0, 0, -15)
	before = v.velocity
	v._fly_to(Vector3(100, 16, 0), dt)
	_check("side turn preserves momentum", v.velocity.z < -14.0)
	for i in hz:
		v._fly_to(Vector3(100, 16, 0), dt, 0.0)
	_check("sideways acceleration banks", absf(v.flight_roll) > 0.05)
	v.free()
	v = _vehicle()
	var goal := v.position
	bounds = true
	var last_rate := 0.0
	for i in hz * 10:
		var yaw := v.rotation.y
		v._fly_to(goal, dt, PI)
		bounds = bounds and absf(wrapf(v.rotation.y - yaw, -PI, PI)) <= 1.8 * dt + 0.0001
		bounds = bounds and absf(v.flight.yaw_rate - last_rate) <= 4.0 * dt + 0.0001
		last_rate = v.flight.yaw_rate
	_check("180 degree hover yaw has bounded rate and acceleration", bounds)
	_check("stationary hover has no orbit or drift", v.position == goal and v.velocity == Vector3.ZERO)
	_check("stationary yaw does not bank", is_zero_approx(v.flight_roll) and is_zero_approx(v.flight_pitch))
	var previous_yaw := v.rotation.y
	v._fly_to(Vector3(999, 99, 999), 0.0)
	_check("zero time does not move helicopter", v.position == goal and v.rotation.y == previous_yaw)
	_check("stationary yaw reaches requested heading", absf(wrapf(v.rotation.y - PI, -PI, PI)) < 0.01)
	v.free()
	v = _vehicle("hummingbird", 0.15)
	bounds = true
	for i in hz * 12:
		var old := v.velocity.y
		v._fly_to(Vector3(0, 16, 0), dt)
		bounds = bounds and absf(v.velocity.y - old) <= 4.0 * dt + 0.0001 and absf(v.velocity.y) <= 6.0001
	_check("climb acceleration and speed bounded", bounds)
	_check("climb settles without teleport", v.flight.settled(v, Vector3(0, 16, 0)))
	bounds = true
	for i in hz * 12:
		var old := v.velocity.y
		v._fly_to(Vector3(0, 0.15, 0), dt)
		bounds = bounds and absf(v.velocity.y - old) <= 4.0 * dt + 0.0001 and v.position.y >= 0.14999
	_check("descent acceleration bounded and no ground penetration", bounds)
	_check("touchdown settles", v.flight.settled(v, Vector3(0, 0.15, 0)))
	field.floor_height = -5.0
	for i in hz:
		v._fly_to(Vector3(0, -5, 0), dt)
	_check("crater cannot pull helicopter below sea level", v.position.y >= 0.15)
	field.floor_height = 2.0
	v.position.y = 2.15
	v.velocity = Vector3.ZERO
	for i in hz:
		v._fly_to(Vector3(0, 0, 0), dt)
	_check("raised landing ground respected", v.position.y >= 2.15)
	field.floor_height = 0.0
	v.free()
	var light := _vehicle()
	var loaded := _vehicle()
	var cargo := _vehicle("tank", 0.0)
	loaded.sling_cargo = cargo
	for i in hz:
		light._fly_to(Vector3(0, 16, -500), dt)
		loaded._fly_to(Vector3(0, 16, -500), dt)
	_check("sling load reduces acceleration", loaded.speed < light.speed * 0.6)
	for i in hz * 15:
		light._fly_to(Vector3(0, 16, -1000), dt)
		loaded._fly_to(Vector3(0, 16, -1000), dt)
	_check("sling load reduces cruise speed", loaded.speed <= float(loaded.vdef.speed) * 0.65 + 0.001)
	light.free()
	loaded.free()
	cargo.free()


func _phases(hz: int) -> void:
	var dt := 1.0 / hz
	var lift := _vehicle("hummingbird", 0.15)
	lift.lift_dest = Vector3(45, 0, -30)
	var visited := {}
	for i in hz * 60:
		visited[lift.lift_phase] = true
		lift._lift_tick(dt)
	_check("lift completes climb cruise and landing", visited.has_all([0, 1, 2, 3]) and lift.lift_phase == 0)
	_check("lift lands at destination", lift.position.distance_to(Vector3(45, 0.15, -30)) < 0.2)
	lift.position.y = 16.0
	lift.velocity = Vector3(10, 0, 0)
	lift.order_stop()
	var hold := lift._flight_hold
	for i in hz * 20:
		lift._lift_tick(dt)
	_check("stop order settles in hover", lift.lift_phase == 7 and lift.position.distance_to(hold) < 0.1 and lift.velocity.length() < 0.01)
	lift.free()
	var attack := _vehicle("pawnee", 22.0)
	attack.gs_dest = Vector3(50, 0, 30)
	for i in hz * 30:
		attack._gunship_tick(dt)
	_check("attack helicopter reaches and holds destination", Defs.flat(attack.position - attack.gs_dest).length() < 0.1 and attack.speed < 0.01)
	attack.free()
	var supply := _vehicle("huron", 0.15)
	var home := Structure.new()
	var fob := Structure.new()
	field.add_child(home)
	field.add_child(fob)
	home.team = 0
	fob.team = 0
	fob.position = Vector3(45, 0, 30)
	supply.heli_home = home
	var rules := field.rules as FlightRules
	rules.destinations = [fob]
	var initial_supply := fob.supply
	visited = {}
	for i in hz * 100:
		visited[supply.heli_phase] = true
		supply._heli_tick(dt)
		if visited.has(6) and supply.heli_phase == 0:
			break
	_check("supply flies all eight mission phases", visited.has_all([0, 1, 2, 3, 4, 5, 6, 7]))
	_check("supply delivers once and returns home", fob.supply == initial_supply + int(supply.vdef.get("load", 80)) and supply.heli_phase == 0 and supply.position.distance_to(Vector3(0, 0.15, 0)) < 0.7)
	# A blast can raise the lip under a pad after the descent was planned.
	supply.position = Vector3(9, 5, 0)
	supply.velocity = Vector3.ZERO
	supply.heli_phase = 3
	supply._flight_hold = Vector3(9, 0.15, 0)
	field.floor_height = 0.8
	for i in hz * 20:
		supply._heli_tick(dt)
		if supply.heli_phase == 7:
			break
	_check("supply landing adapts to newly raised ground", supply.heli_phase == 7 and supply.position.y >= 0.94999)
	field.floor_height = 0.0
	rules.destinations.clear()
	supply.free()
	home.free()
	fob.free()
	var tank := _vehicle("tank", 0.0)
	_check("ground vehicle never gets flight controller", tank.flight == null)
	tank.free()


func _replication() -> void:
	var v := _vehicle()
	var copy := _vehicle()
	v.flight_pitch = -0.32
	v.flight_roll = 0.43
	v.sling_eid = 12345
	v.flags = Vehicle.F_GROUND
	var b := StreamPeerBuffer.new()
	v.write_state(b)
	b.put_u32(0x12345678)
	b.seek(0)
	copy.read_state(b)
	_check("state roundtrip consumes complete packet", b.get_available_bytes() == 4 and b.get_u32() == 0x12345678)
	_check("signed pitch and roll survive replication", absf(copy.flight_pitch - v.flight_pitch) < 0.001 and absf(copy.flight_roll - v.flight_roll) < 0.001)
	_check("existing state fields survive replication", copy.sling_eid == v.sling_eid and copy.flags == v.flags and copy.team == v.team)
	v.free()
	copy.free()


func _trajectory(hz: int) -> Vector3:
	var v := _vehicle()
	for i in hz * 8:
		v._fly_to(Vector3(70, 25, -80), 1.0 / hz)
	var result := v.position
	v.free()
	return result


func _retask(hz: int) -> void:
	var dt := 1.0 / hz
	var lift := _vehicle("ghosthawk", 6.0)
	lift.lift_phase = 3
	lift.lift_dest = Vector3.ZERO
	lift.velocity = Vector3(0, -3, 0)
	var old := lift.velocity
	lift.order_move(Vector3(50, 0, 50))
	_check("new order cancels landing without changing momentum", lift.lift_phase == 2 and lift.velocity == old)
	lift._lift_tick(dt)
	_check("landing retask climbs smoothly", absf(lift.velocity.y - old.y) <= 4.0 * dt + 0.0001)
	lift.free()
	lift = _vehicle("ghosthawk", 16.0)
	var cargo := _vehicle("technical", 0.0)
	cargo.eid = 77
	cargo.position = Vector3(15, 0, 15)
	lift.order_sling(cargo)
	var visited := {}
	for i in hz * 40:
		visited[lift.lift_phase] = true
		lift._lift_tick(dt)
		if lift.sling_cargo == cargo and lift.position.y > 15.9:
			break
	_check("sling pickup approaches and hooks from hover", visited.has_all([5, 6]) and lift.sling_cargo == cargo and cargo.slung_by == lift)
	lift.velocity = Vector3(5, 0, 0)
	lift.order_stop()
	var hold := lift._flight_hold
	for i in hz * 20:
		lift._lift_tick(dt)
	_check("stop retains live sling cargo in stable hover", lift.sling_cargo == cargo and cargo.slung_by == lift and lift.position.distance_to(hold) < 0.1 and lift.velocity.length() < 0.01)
	lift.order_move(Vector3(50, 0, 50))
	for i in hz * 60:
		lift._lift_tick(dt)
		if lift.sling_cargo == null:
			break
	_check("resume after pickup delivers sling cargo", lift.sling_cargo == null and cargo.slung_by == null and Defs.flat(cargo.position - Vector3(50, 0, 50)).length() < 0.8)
	lift.free()
	cargo.free()
