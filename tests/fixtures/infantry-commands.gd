extends "res://tests/fixtures/infantry-orders.gd"

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	HNav.NCC = 4
	HNav._corner = HNav._corners()
	var w := World.new()
	w.nav = RecordedRoutes.new()
	w.nav.finalize()
	w.time = 100.0
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var rng := SimulationRandom.new()
	for trial in 3840:
		var s := Soldier.new()
		s.world = w
		s.eid = 1
		s.life = trial / 640 % 6
		var task_code: int = trial / 8 % 20
		s.task = Soldier.CONTROLLER_TASKS[task_code] if task_code < Soldier.CONTROLLER_TASKS.size() else "unknown"
		s.task_phase = trial / 160 % 4
		s.position = Vector3(1.3, -0.4, -2.7)
		s.path = PackedVector3Array([Vector3(8.0, 0.0, 2.1)])
		s.goal = s.path[0]
		s.goal_kind = "cover"
		s._path_pending = trial % 2 == 0
		s._path_revision = trial
		s._stuck_t = 0.5
		s._stuck_p = Vector3(0.4, 0, 1.3)
		s.hold_pos = Vector3(-10.0, 0.0, -10.0)
		s.hold_face = Vector3.FORWARD
		s.leash = [3.0, 9.0, 20.0][trial % 3]
		s.backwards = true
		s.at_cover = true
		s.cover_type = 2
		s.cover_n = Vector3.RIGHT
		s.cover_h = 1.2
		s.cover_mat = 2
		s.cover_ai = 3
		s._shifting = true
		s.peek_up = true
		s.blind = true
		s.next_cover_eval = 103.0
		s.act_kind = "cook"
		s.act_t = 0.7
		s._queued_throw = {"kind": "frag", "pos": Vector3.ONE, "fuse": 1.1}
		var patient := Soldier.new()
		patient.eid = 2
		patient.world = w
		patient.position = Vector3(3.4, 0, 13.1)
		patient.dragged_by = s if trial % 3 else null
		patient.rescue_claimed = s if trial % 5 else null
		var st := Structure.new()
		st.eid = 3
		st.world = w
		st.position = Vector3(2.1, 0, 3.7)
		var vehicle := Vehicle.new()
		vehicle.world = w
		vehicle.eid = 4
		s.mounted = st if s.task == "man" and trial % 3 else null
		s.base_y = 4.25 if trial % 2 else 0.0
		s.gun_override = Defs.WEAPONS.hmg if s.mounted else {}
		s._pit_aim = Vector3(8, 0, 12)
		s._mount_target = vehicle
		s._mount_scan_t = 0.8
		s.task_ent = st if s.task == "man" else patient
		s.task_ent2 = patient
		s.forced_target = patient
		var squad := Squad.new()
		squad.world = w
		squad.sid = 77
		squad.members = [s, patient]
		squad.breach_by = s if trial % 3 else patient
		s.squad = squad if trial % 5 else null
		s.sid = 77 if s.squad else 0
		w.nav.jobs.clear()
		w.nav.cancelled = 0
		w.rng.seed = trial + 117
		rng.seed = trial + 117
		assert(core.load_state(InfantryState.capture(s)))
		var kind: int = trial % 8
		var p := s.position + Vector3([12.0, 24.0, 24.01, 30.0, 60.0][trial % 5], 0, 0)
		var face: Vector3 = [Vector3.ZERO, Vector3(0.05, 0, 0), Vector3(0.3, 0, -0.8)][trial % 3]
		var mode: int = trial % 3
		var input: Array = [
			[0, p, mode, face], [1, face], [2, s.goal + Vector3([2.99, 3.0, 3.01][trial % 3], 0, 0), mode, face],
			[3, patient.eid, patient.position, p], [4, p], [5, p, trial / 8 % 2], [6], [7],
		][kind]
		var mount_position := PackedVector3Array([st.position]) if s.mounted else PackedVector3Array()
		var before := [patient.dragged_by, patient.rescue_claimed, squad.breach_by]
		var allowed := kind == 7 or (s._can_retreat() if kind == 4 else (s.can_take_orders() and (s.task == "" if kind in [1, 2] else true)))
		match kind:
			0: s.cmd_move(p, mode, face)
			1: s.cmd_halt(face)
			2: s.follow_to(input[1], mode, face)
			3: s.cmd_attack(patient, p)
			4: s.cmd_retreat(p)
			5: s.cmd_throw(p, "smoke" if trial / 8 % 2 else "frag")
			6: s.cmd_stop()
			7: s._return_to_hold()
		var expected_links := [patient.dragged_by, patient.rescue_claimed, squad.breach_by]
		patient.dragged_by = before[0]
		patient.rescue_claimed = before[1]
		squad.breach_by = before[2]
		var out: Array = core.command(input, w.nav._planner, mount_position)
		assert(out.size() == 4 and out[0] == allowed, "admission %d" % trial)
		if not out[1].is_empty():
			if out[1][0] == 1:
				assert(out[1][1] == patient.eid)
				if patient.dragged_by == s:
					patient.dragged_by = null
				if patient.rescue_claimed == s:
					patient.rescue_claimed = null
			else:
				assert(out[1] == [2, squad.sid])
				if squad.breach_by == s:
					squad.breach_by = null
		assert(expected_links == [patient.dragged_by, patient.rescue_claimed, squad.breach_by], "shared claims %d" % trial)
		compare(s, core, rng, "command %d" % trial)
		assert(int(out[2]) == w.nav.cancelled)
		assert(out[3].is_empty() == w.nav.jobs.is_empty(), "path request %d" % trial)
		if not out[3].is_empty():
			assert(out[3] == [s._path_revision, w.nav.jobs[0][1], w.nav.jobs[0][4]])
		assert(core.restore(core.checkpoint()))
		compare(s, core, rng, "restored command %d" % trial)
		var saved: PackedByteArray = core.checkpoint()
		assert(core.command([5, Vector3.ZERO, 2], w.nav._planner, PackedVector3Array()).is_empty())
		assert(core.command([0, Vector3(NAN, 0, 0), 1, Vector3.ZERO], w.nav._planner, PackedVector3Array()).is_empty())
		assert(core.command([3, -1, Vector3.ZERO, Vector3.ZERO], w.nav._planner, PackedVector3Array()).is_empty())
		assert(core.checkpoint() == saved)
		w.nav.jobs.clear()
		s.free()
		patient.free()
		st.free()
		vehicle.free()
	w.free()
	print("INFANTRY_COMMANDS passed cases=3840")
	get_tree().quit()
