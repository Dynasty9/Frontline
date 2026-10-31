extends "res://tests/fixtures/infantry-vitals.gd"

class CasualtySquad extends Squad:
	func on_member_down(_s: Soldier) -> void:
		pass

class CasualtyWorld extends Scene:
	var removed := 0
	func despawn(e: Entity) -> void:
		removed = e.eid

class Body extends Trooper:
	func _ground() -> float:
		return -0.3

func check_actor(s: Soldier, core: RefCounted, rng: SimulationRandom, label: String) -> void:
	var expected := InfantryState.capture(s)
	var actual: Array = core.values()
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s vs %s" % [label, group, expected[group], actual[group]])
	assert(s.world.rng.state == rng.state, label + " RNG")

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	var w := CasualtyWorld.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": false}
	w.nav = Nav.new()
	w.nav.finalize()
	add_child(w)
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var rng := SimulationRandom.new()
	var mount := Mount.new()
	mount.world = w
	mount.eid = 9
	mount.skind = "mg_nest"
	mount.position = Vector3(3, 0, -4)
	w.add_child(mount)
	var drone := Drone.new()
	drone.eid = 8
	drone.world = w
	var squad := CasualtySquad.new()
	squad.world = w
	squad.sid = 17
	var patient := Trooper.new()
	patient.eid = 2
	patient.world = w
	w.add_child(patient)
	var checks := 0
	for trial in 384:
		for op in 8:
			var s := Body.new()
			s.world = w
			s.srv = true
			s.eid = 1
			s.sid = 17
			s.squad = squad
			squad.breach_by = s
			s.utype = "rifleman"
			s.udef = Defs.UNITS.rifleman
			s.wdef = Defs.WEAPONS.rifle if trial % 3 else {}
			s.mag = trial % 31
			s.reserve = trial % 130
			s.life = trial % 6
			s.times_downed = trial % 5
			s.hp = 17.0
			s.base_hp = 100.0
			s.max_hp = 80.0
			s.position = Vector3(0.3, -0.4, -1.1)
			s.rotation.y = trial * 0.37
			s.posture = trial % 5
			s.act = Soldier.Act.COOK
			s.path = PackedVector3Array([Vector3(10, 0, 1)])
			s.goal_kind = "cover"
			s._path_pending = trial % 2 == 0
			s._path_revision = trial
			s.task = ["", "rescue", "stretcher", "breach", "man", "pilot"][trial % 6]
			s.task_ent = patient
			s.task_ent2 = patient
			s.drone_ctrl = drone
			drone.gone = trial % 11 == 0
			drone.phase = 0
			s.mounted = mount if trial % 2 else null
			s.gun_override = Defs.WEAPONS.hmg
			s.base_y = 4.0
			s.backwards = true
			s.peek_up = true
			s.blind = true
			s.at_cover = true
			s.next_cover_eval = 110.0
			s.act_kind = "cook"
			s.act_t = 0.3
			s._queued_throw = {"pos": Vector3(10, 0, 1), "kind": "frag", "fuse": 1.0}
			s.dragged_by = patient
			s.rescue_claimed = patient
			s.carried_by = [patient] if trial % 7 == 0 else []
			s.stretcher_claimed = trial % 5 == 0
			s._hit_kind = ["", "bullet", "explosion", "melee"][trial % 4]
			s._hit_dir = Vector3(0.3, 0.7, -0.8)
			s.dead_t = -400.0
			patient.dragged_by = s
			patient.rescue_claimed = s
			patient.carried_by = [s]
			patient.life = Soldier.Life.ALIVE if trial % 2 else Soldier.Life.DEAD
			w.rng.seed = trial + 137
			rng.seed = trial + 137
			w.time = 100.0
			w.removed = 0
			w.add_child(s)
			var expected_release := PackedInt64Array([2 if s.task == "rescue" else 0, 2 if s.task == "stretcher" else 0, 17 if s.task == "breach" else 0, 8])
			assert(core.load_state(InfantryState.capture(s)))
			match op:
				0:
					s._release_all()
					assert(core.release_all() == expected_release)
				1:
					s._go_down()
					assert(core.go_down(w.time) == expected_release)
				2:
					var was_dead := s.life == Soldier.Life.DEAD
					var ammo := PackedInt32Array([int(s.wdef.ammo)]) if not s.wdef.is_empty() else PackedInt32Array()
					s._die()
					var out: Array = core.die(w.time, ammo)
					assert(out == [not was_dead, PackedInt64Array([0, 0, 0, 0]) if was_dead else expected_release])
				3:
					s.revive(trial % 2 == 0)
					var speech: int = core.revive(trial % 2 == 0, ["rifle", int(Defs.WEAPONS.rifle.mag)], rng._backend)
					assert(w.spoken.back()[1] == ["Thanks, doc.", "I'm good, I'm good!", "Back in the fight.", "Ugh... let's go."][speech])
				4:
					var accepted := s.life != Soldier.Life.HIDDEN and s.carried_by.is_empty()
					var released := accepted and s.life == Soldier.Life.ALIVE
					s.fling_from(s.position if trial % 2 else Vector3.ZERO, 7.0)
					var out: Array = core.fling_from(Vector3(0.3, -0.4, -1.1) if trial % 2 else Vector3.ZERO, 7.0, rng._backend)
					assert(out == [accepted, expected_release if released else PackedInt64Array([0, 0, 0, 0])])
				5:
					var reason: int = trial % 7
					s.hide_in(InfantryState.HIDDEN[reason], 0.3, mount if trial % 2 else null)
					assert(core.hide_in(reason, 0.3, [9, mount.position] if trial % 2 else []))
				6:
					s.unhide(Vector3(4.2, -1.3, 2.7))
					assert(core.unhide(Vector3(4.2, -1.3, 2.7), w.nav._planner))
				7:
					s._dead(0.1)
					assert(core.corpse_tick(-0.3, w.time, patient.life == Soldier.Life.ALIVE) == int(w.removed == 1))
			check_actor(s, core, rng, "op %d trial %d" % [op, trial])
			if op == 2 or op == 4:
				w.effects.clear()
				s._death_fx()
				var effect: Array = core.death_pose()
				assert(w.effects.back()[3] == effect[0])
				assert((w.effects.back()[2] as Vector3).distance_to(effect[1]) < 0.00001)
			var saved: PackedByteArray = core.checkpoint()
			assert(core.restore(saved) and core.checkpoint() == saved)
			s.free()
			checks += 1
	drone.free()
	print("INFANTRY_CASUALTY passed cases=", checks)
	get_tree().quit()
