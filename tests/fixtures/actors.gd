extends "res://tests/fixtures/infantry-vitals.gd"

class ActorWorld extends Scene:
	func despawn(e: Entity) -> void:
		e.gone = true
	func send_msg(_team: int, _kind: String, _text: String, _ping = null) -> void:
		pass

class ActorCombat extends Combat:
	var explosions := []
	func explode(pos: Vector3, data: Dictionary) -> void:
		explosions.append([pos, data])

func soldier_bytes(s: Soldier) -> PackedByteArray:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	assert(state.load_state(InfantryState.capture(s)))
	return state.checkpoint()

func drone_bytes(d: Drone, actors: RefCounted) -> PackedByteArray:
	var flight: RefCounted = ClassDB.instantiate("DroneFlightCore")
	assert(flight.reset(d.position, d.rotation.y))
	var bytes: PackedByteArray = flight.checkpoint()
	bytes[8] = d.phase
	bytes[9] = int(d.diving)
	bytes[10] = int(d.dead)
	return actors.drone_checkpoint(PackedInt64Array([d.eid, d.team, d.operator.eid if d.operator else 0, d.target.eid if d.target else 0, d.operator_id, d.target_id]), d.warhead, bytes)

func compare_actor(s: Soldier, actors: RefCounted, label: String) -> void:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	assert(state.restore(actors.actor_state(s.eid)))
	var expected := InfantryState.capture(s)
	var actual: Array = state.values()
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])

func compare_drone(d: Drone, actors: RefCounted, label: String) -> void:
	var a: Array = actors.drone_state(d.eid)
	assert(a.size() == 13)
	assert(d.position.distance_to(a[0]) < 0.002, label + " position")
	assert(d.vel.distance_to(a[1]) < 0.002, label + " velocity")
	assert(d.target_pos.distance_to(a[2]) < 0.002, label + " target")
	assert(absf(angle_difference(d.rotation.y, float(a[7]))) < 0.0001, label + " yaw")
	assert([d.life_t, d.phase, d.diving, d.dead] == [a[3], a[4], a[5], a[6]], label + " flight")
	assert([d.operator.eid if d.operator else 0, d.target.eid if d.target else 0, d.operator_id, d.target_id, d.warhead] == [a[8], a[9], a[10], a[11], a[12]], label + " links")

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	var w := ActorWorld.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": false}
	w.nav = Nav.new()
	w.nav.finalize()
	w.combat = ActorCombat.new(w)
	w.combat.enable_native_collision()
	add_child(w)
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var rng := SimulationRandom.new()
	for trial in 96:
		for op in 4:
			var s := make_soldier(w, 1, trial % 2)
			var patient := make_soldier(w, 2, trial % 2)
			var d := Drone.new()
			d.eid = 3
			d.world = w
			d.team = s.team
			d.operator = s
			d.operator_id = 1
			d.target = patient
			d.target_id = 2
			d.position = Vector3(0, 7, 0)
			d.target_pos = d.position
			d.phase = trial % 4
			s.drone_ctrl = d
			s.task = ["rescue", "stretcher", ""][trial % 3]
			s.task_ent = patient
			s.path = PackedVector3Array([Vector3(10, 0, 3)])
			patient.dragged_by = s if trial % 5 else patient
			patient.rescue_claimed = s if trial % 7 else patient
			patient.carried_by = [patient, s]
			w.time = 31.7
			w.rng.seed = trial + 137
			rng.seed = trial + 137
			assert(actors.load_state(9, PackedByteArray([0, 0, 4]), [soldier_bytes(s), soldier_bytes(patient), drone_bytes(d, actors)]))
			match op:
				0:
					s._release_all()
					assert(actors.release_all(1).size() == 4)
				1:
					s._go_down()
					assert(actors.go_down(1, w.time).size() == 4)
				2:
					s._die()
					assert(actors.die(1, w.time, int(s.wdef.ammo))[0])
				3:
					s.fling_from(Vector3(-2, 0, -1), 7.3)
					assert(actors.fling_from(1, Vector3(-2, 0, -1), 7.3, rng._backend)[0])
			compare_actor(s, actors, "carrier %d/%d" % [trial, op])
			compare_actor(patient, actors, "patient %d/%d" % [trial, op])
			compare_drone(d, actors, "drone release %d/%d" % [trial, op])
			assert(w.rng.state == rng.state)
			var saved: PackedByteArray = actors.checkpoint()
			assert(actors.restore(saved))
			assert(actors.checkpoint() == saved)
			var bad := saved.duplicate()
			bad[4] = 2
			assert(not actors.restore(bad))
			assert(actors.checkpoint() == saved)
			checks += 1
			s.free()
			patient.free()
			d.free()
	MapDims.SIZE = 1024.0
	MapDims.HALF = 512.0
	var steps := 0
	for trial in 72:
		var operator := make_soldier(w, 1, trial % 2)
		var target := make_soldier(w, 2, 1 - trial % 2)
		target.position = Vector3(30.0 + trial * 0.7, 0, -17.0 - trial * 0.3)
		target.posture = trial % 5
		var d := Drone.new()
		d.eid = 3
		d.world = w
		d.team = operator.team
		d.position = Vector3(-4.3, 7.2, -2.8)
		d.rotation.y = 0.37
		d.target_pos = d.position
		d.operator = operator
		d.operator_id = 1
		d.target = target
		d.target_id = 2
		d.warhead = 1.5 if trial % 2 else 1.0
		(w.combat as ActorCombat).explosions.clear()
		assert(actors.load_state(4, PackedByteArray([0, 0, 4]), [soldier_bytes(operator), soldier_bytes(target), drone_bytes(d, actors)]))
		var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
		for tick in 3100:
			if tick == 20 and trial % 6 == 0:
				operator.life = Soldier.Life.DEAD
				assert(actors.die(1, w.time, 120)[0])
			if tick == 30 and trial % 6 == 1:
				operator.gone = true
				assert(actors.remove(1))
			if tick == 35 and trial % 6 == 2:
				target.life = Soldier.Life.DEAD
				assert(actors.die(2, w.time, 120)[0])
			if tick == 40 and trial % 6 == 3:
				target.gone = true
				assert(actors.remove(2))
			if tick == 12 and trial % 6 == 4:
				d.shot_down()
				assert(actors.shoot_drone(3) == 1)
			if tick % 17 == 0:
				assert(actors.restore(actors.checkpoint()))
			d.sim(dt)
			var result: Array = actors.step_drone(3, dt, w.combat._collision, MapDims.HALF)
			assert(result.size() == 1)
			compare_drone(d, actors, "flight %d/%d" % [trial, tick])
			if not result[0].is_empty():
				assert(result[0].size() == 1 and result[0][0][0] == 0)
				var event: Array = result[0][0]
				var explosions: Array = (w.combat as ActorCombat).explosions
				assert(explosions.size() == 1)
				assert((explosions[0][0] as Vector3).distance_to(event[1]) < 0.002)
				var damage: Dictionary = explosions[0][1]
				assert(event[2] == PackedFloat64Array([damage.dmg, damage.radius, damage.fling, damage.at, damage.track, damage.size, damage.struct_mult]))
				assert(event[3].is_empty() and event[4] and event[5] == (damage.src.eid if damage.src else 0) and event[6] == damage.team and event[7] == 0)
			steps += 1
			if d.gone:
				break
		assert(d.gone)
		operator.free()
		target.free()
		d.free()
	print("ACTOR_STATE passed shared=%d flights=72 steps=%d" % [checks, steps])
	get_tree().quit()
