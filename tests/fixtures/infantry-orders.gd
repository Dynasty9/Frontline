extends Node

class RecordedRoutes extends Nav:
	var jobs: Array = []
	var cancelled := 0
	func request_path(unit: Entity, destination: Vector3, vehicle: bool, team: int, care: float, done: Callable) -> void:
		jobs.append([unit.eid, destination, vehicle, team, care, done])
	func cancel_path(_id: int) -> void:
		cancelled += 1

class ArrivalRules extends Rules:
	var arrivals := 0
	func prisoner_arrived(_s: Soldier) -> void:
		arrivals += 1
		world.rng.randi()

func compare(s: Soldier, core: RefCounted, rng: SimulationRandom, label: String) -> void:
	assert(core.values() == InfantryState.capture(s), label)
	assert(rng.state == s.world.rng.state, label + " random cursor")

func _ready() -> void:
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	var w := World.new()
	w.time = 100.0
	w.nav = RecordedRoutes.new()
	w.rules = ArrivalRules.new(w)
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var rng := SimulationRandom.new()
	var cases := 0
	for trial in 1024:
		var s := Soldier.new()
		s.world = w
		s.eid = 17
		s.team = trial % 2
		s.life = trial % 6
		s.position = Vector3(1.2, -0.5, 3.4)
		s.rotation.y = 0.71
		s._path_revision = trial * 2
		s.path = PackedVector3Array([Vector3.ONE, Vector3(2.4, -0.3, 7.1)])
		s.path_i = trial % 3
		s._path_pending = trial % 2 == 0
		s._stuck_t = 0.7
		s._stuck_p = Vector3.ZERO
		s.slide_t = 0.3
		s.cover_type = trial % 4
		s.cover_n = [Vector3.ZERO, Vector3(0.3, 0, -0.7), Vector3(0.001, 0, 0.001)][trial % 3]
		s.cover_h = 1.2
		s.cover_mat = 2
		s.cover_ai = 3
		s.at_cover = true
		s._shifting = true
		s.blind = true
		s.peek_t = 0.4
		s.last_shot_t = [99.5, 99.4, 99.9][trial % 3]
		s.task = ["", "retreat", "limp"][trial % 3]
		w.nav.jobs.clear()
		w.nav.cancelled = 0
		w.rules.arrivals = 0
		w.rng.seed = 137 + trial
		rng.seed = 137 + trial
		assert(core.load_state(InfantryState.capture(s)))
		var purpose: int = trial % 6
		var mode: int = trial % 3
		var destination := s.position + Vector3([0.0, 1.69, 1.7, 1.71, 12.0][trial % 5], 0, 0)
		s.go_to(destination, InfantryState.GOALS[purpose], mode)
		var order: Array = core.go_to(destination, purpose, mode)
		assert(order == [s._path_revision, w.nav.jobs[0][4]])
		compare(s, core, rng, "request %d" % trial)
		var revision: int = s._path_revision
		if trial % 7 == 0:
			s.go_to(Vector3(9.1, 0, -3.7), "slot", 1)
			assert(core.go_to(Vector3(9.1, 0, -3.7), 1, 1) == [s._path_revision, w.nav.jobs[1][4]])
		elif trial % 7 == 1:
			s.stop_moving()
			assert(core.stop_moving())
		compare(s, core, rng, "superseded %d" % trial)
		var saved: PackedByteArray = core.checkpoint()
		assert(core.restore(saved))
		var points := PackedVector3Array([Vector3(5.6, -0.2, 1.8), destination]) if trial % 4 == 0 else PackedVector3Array()
		var expected := 0
		if revision == s._path_revision and s.life not in [Soldier.Life.DEAD, Soldier.Life.HIDDEN]:
			if not points.is_empty():
				expected = 1
			elif Defs.flat(s.position - s.goal).length_squared() < 1.7 * 1.7:
				expected = 3 if s.goal_kind == "prison" else 2
			else:
				expected = 4
		(w.nav.jobs[0][5] as Callable).call(points)
		var result: int = core.accept_path(revision, points, w.time, rng._backend)
		assert(result == expected, "Completion kind %d" % trial)
		if result == 3:
			rng.randi()
		compare(s, core, rng, "completed %d" % trial)
		var prison := s.goal_kind == "prison"
		s._arrived()
		assert(core.arrived(w.time, rng._backend) == int(prison))
		if prison:
			rng.randi()
		compare(s, core, rng, "arrived %d" % trial)
		var unchanged: PackedByteArray = core.checkpoint()
		assert(core.go_to(Vector3.ZERO, 1, -1).is_empty())
		assert(core.accept_path(s._path_revision, PackedVector3Array([Vector3(NAN, 0, 0)]), w.time, rng._backend) == -1)
		assert(core.checkpoint() == unchanged)
		assert(w.rng.state == rng.state)
		w.nav.jobs.clear()
		s.free()
		cases += 4
	w.free()
	print("INFANTRY_ORDERS passed cases=%d" % cases)
	get_tree().quit()
