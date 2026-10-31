extends "res://tests/fixtures/actors.gd"

class RecordedRoutes extends Nav:
	var jobs := []
	func request_path(unit: Entity, destination: Vector3, vehicle: bool, team: int, care: float, done: Callable) -> void:
		jobs.append([unit.eid, destination, vehicle, team, care, done])
	func cancel_path(_id: int) -> void:
		pass
	func find_boat_path(from: Vector3, to: Vector3) -> PackedVector3Array:
		return PackedVector3Array([from, to])

class Carrier extends Vehicle:
	func _ready() -> void:
		set_process(false)
	func _landing_spot(p: Vector3) -> Vector3:
		return Vector3(p.x + 0.3, 0.0, p.z - 0.7)

func compare_vehicle(v: Vehicle, core: RefCounted, label: String) -> void:
	var expected := VehicleState.capture(v)
	var actual: Array = core.values()
	assert(actual.size() == expected.size(), label)
	for group in expected.size():
		if group == 2:
			for i in expected[group].size():
				assert(absf(float(expected[group][i]) - float(actual[group][i])) < 0.000001, "%s scalar %d: %s / %s" % [label, i, expected[group][i], actual[group][i]])
		else:
			assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])
	var saved: PackedByteArray = core.checkpoint()
	assert(core.restore(saved) and core.checkpoint() == saved, label + " checkpoint")
	checks += 1

func apply_route(v: Vehicle, core: RefCounted, route: Array) -> void:
	assert(route.size() == 4)
	if int(route[0]) == 1:
		var job: Array = v.world.nav.jobs.back()
		assert(route[1] == job[1] and route[2] == job[4] and int(route[3]) == v._path_revision)
	elif int(route[0]) == 2:
		assert(route[1] == v.path[-1])
		assert(core.complete_boat_path(v.path))

func _ready() -> void:
	var w := ActorWorld.new()
	w.has_view = false
	w.srv = true
	w.nav = RecordedRoutes.new()
	add_child(w)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var foe := make_soldier(w, 9, 1)
	foe.position = Vector3(110, 3, -90)
	var kinds := Defs.VEHICLES.keys()
	checks = 0
	for trial in 264:
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.owner_peer = [-1, 1, -2][trial % 3]
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.max_hp = v.vdef.hp
		v.hp = v.max_hp * 0.3
		v.position = Vector3(4.3, float(trial % 7), -3.7)
		v.rotation.y = 0.37 * (trial % 7)
		v.path = PackedVector3Array([Vector3.ONE, Vector3(13, 0, -22)])
		v.path_i = trial % 3
		v.path_pending = trial % 2 == 0
		v._path_revision = trial + 1
		v.brain_state = ["", "withdraw", "evade", "wait"][trial % 4]
		v.brain_resume = {"dest": Vector3(13, 0, -22), "assault": true, "assault_dest": Vector3(40, 0, -31)}
		v.bt_cd = {"push_on": 123.1 + trial}
		v._tries_t = 0.3 if trial % 2 else -INF
		v._avoid_cap = 3.0 if trial % 2 else INF
		v._last_blast = [Vector3(3, 0, -1), 2.1, 31.7]
		v.track_broken = true
		v.track_fix = trial % 6
		v.lift_phase = trial % 8
		v.forced_target = foe
		v.target = foe
		v.flight = HelicopterFlight.new() if v.base() in ["attack_heli", "lift_heli"] else null
		w.add_child(v)
		w.nav.jobs.clear()
		assert(core.load_state(VehicleState.capture(v)), "capture %s" % v.vkind)
		compare_vehicle(v, core, "import %d" % trial)
		var bad: Array = core.values()
		bad[0][0] = -1
		var saved: PackedByteArray = core.checkpoint()
		assert(not core.load_state(bad) and core.checkpoint() == saved)
		var avoid_cap := v._avoid_cap
		v._avoid_cap = NAN
		assert(not core.load_state(VehicleState.capture(v)) and core.checkpoint() == saved)
		v._avoid_cap = avoid_cap
		var before := v.track_broken
		v.repair(1.3)
		assert(core.repair(1.3) == int(before and not v.track_broken))
		v.rearm()
		assert(core.rearm(v.atgm_left, v.sam_left))
		compare_vehicle(v, core, "repair %d" % trial)
		var destination := Vector3(37.3, 1.0, -19.7)
		if trial % 2:
			v.order_assault(destination)
		else:
			v.order_move(destination)
		apply_route(v, core, core.order_move(destination, v.base(), v._landing_spot(destination), bool(trial % 2)))
		compare_vehicle(v, core, "move %d" % trial)
		v.order_attack(foe)
		apply_route(v, core, core.order_attack(foe.eid, foe.position, v.base()))
		compare_vehicle(v, core, "attack %d" % trial)
		var revision := v._path_revision
		v.order_stop()
		assert(core.order_stop(v.base(), v.is_auto()))
		compare_vehicle(v, core, "stop %d" % trial)
		if not w.nav.jobs.is_empty():
			(w.nav.jobs.back()[5] as Callable).call(PackedVector3Array([destination]))
			assert(core.complete_path(revision, PackedVector3Array([destination])) == 0)
			compare_vehicle(v, core, "stale route %d" % trial)
		var motion := v.motion_profile()
		for step in 90:
			if step == 30:
				v.target = null
			elif step == 60:
				v.target = foe
			if step in [30, 60]:
				var state: Array = core.values()
				state[0][2] = InfantryState.entity_id(v.target)
				assert(core.load_state(state))
			v._turret_tick(1.0 / 30.0)
			assert(core.turret_tick(foe.eid if v.target else 0, foe.position, 1.0 / 30.0, v.base() == "attack_heli", float(motion.traverse), float(motion.traverse_accel)))
			compare_vehicle(v, core, "turret %d/%d" % [trial, step])
		v.free()
	# Shared boarding updates both owned actors, and retired IDs do not occupy seats.
	var v := Carrier.new()
	v.world = w
	v.srv = true
	v.eid = 7
	v.vdef = Defs.VEHICLES.tank.duplicate()
	v.vdef["seats"] = 1
	v.position = Vector3.ZERO
	w.add_child(v)
	var man := make_soldier(w, 5, 0)
	assert(core.load_state(VehicleState.capture(v)))
	assert(actors.load_state(20, PackedByteArray([0, 2]), [soldier_bytes(man), core.checkpoint()]))
	assert(v.board(man) and actors.board(7, 5, 1, false) == 1)
	compare_actor(man, actors, "boarded")
	assert(core.restore(actors.actor_state(7)))
	compare_vehicle(v, core, "boarded vehicle")
	assert(actors.board(7, 5, 1, false) == 0)
	w.free()
	print("VEHICLE_STATE passed cases=%d" % checks)
	get_tree().quit()
