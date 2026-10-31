extends "res://tests/fixtures/infantry-motion.gd"

class Executing extends Trooper:
	func _think() -> void:
		pass

func check_actor(s: Soldier, core: RefCounted, rng: SimulationRandom, label: String) -> void:
	var expected := InfantryState.capture(s)
	var actual: Array = core.values()
	var motion: PackedFloat64Array = expected[1][1][0]
	var native: PackedFloat64Array = actual[1][1][0]
	for i in [0, 1, 2, 3]:
		assert(absf(motion[i] - native[i]) < 0.00001, "%s motion %d" % [label, i])
		motion[i] = native[i]
	expected[1][1][0] = motion
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s vs %s" % [label, group, expected[group], actual[group]])
	assert(rng.state == s.world.rng.state, label + " RNG")

func stage(s: Soldier, dt: float) -> int:
	if s.dazed_t > 0.0: return 1
	if s.dive_t > 0.0: return 2
	if s.act_t > 0.0: return 3
	if s.flinch_t > dt: return 4
	return 5 if s.think_t <= dt else 0

func step(s: Soldier, core: RefCounted, rng: SimulationRandom, dt: float) -> void:
	var related := s._action_related()
	var expected_stage := stage(s, dt)
	s._fatigue_tick(dt)
	s._alive_timers_reference(dt)
	assert(core.alive_stage(dt, rng._backend) == expected_stage)
	match expected_stage:
		1: assert(core.dazed_tick(dt, PackedFloat64Array(), s.world.nav._planner, rng._backend))
		2: assert(core.dive_tick(dt, s.world.time, s.world.nav._planner))
		3:
			var effect: Array = core.action_tick(related, rng._backend)
			assert(effect.size() == 3)
			assert(effect[0][0] == 0, "Actions remain pending, or complete cooking into a retained throw")
			if effect[2] >= 0:
				assert(effect[1] and effect[2] < 3)
				assert(s.world.spoken.back()[1] == ["Frag out!", "Grenade out!", "Fire in the hole!"][effect[2]])

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	MapDims.BIOME = 32
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	TerrainMap.N = 32
	TerrainMap.H = 16.0
	TerrainMap.DN = 64
	var w := make_world()
	w.settings.rust_infantry = false
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var rng := SimulationRandom.new()
	var target := Trooper.new()
	target.world = w
	target.eid = 2
	target.position = Vector3(3, 0.5, -4)
	w.add_child(target)
	var grenade := Projectile.new()
	grenade.eid = 3
	grenade.world = w
	grenade.position = Vector3(0.8, 1, 0)
	var door := add_structure(w, 4, "house_wall", Vector3.RIGHT, 0.0)
	var checks := 0
	for trial in 128:
		for kind in Soldier.ACTION_KINDS:
			var s := Executing.new()
			s.world = w
			s.eid = 1
			s.position = Vector3(0.3, 0.4, -0.1)
			s.rotation.y = trial * 0.37
			s.posture = trial % 5
			s.path = PackedVector3Array([Vector3(3, 0, 8)])
			s._path_pending = trial % 2 == 0
			s.goal_kind = "cover"
			s.stamina = 0.37
			s.suppression = trial % 100
			s.move_mode = trial % 3
			s.think_t = 0.1
			s.flinch_t = 0.12
			s.dazed_t = 0.15 if trial % 5 == 0 else 0.0
			s.dive_t = 0.1 if trial % 3 == 0 else 0.0
			s.dive_dir = Vector3(0.3, 0, -0.7)
			s._queued_throw = {"pos": Vector3(4, 0, -12), "kind": "frag", "fuse": 1.1} if trial % 2 else {}
			w.rng.seed = trial + 137
			rng.seed = trial + 137
			w.add_child(s)
			var data := {}
			match kind:
				"throw", "throw_in", "mortar": data = {"pos": Vector3(7, 0, -15), "kind": "smoke", "fuse": 1.2}
				"rethrow": data = {"g": grenade, "pos": Vector3(6, 0, -14)}
				"kick": data = {"g": grenade, "v": Vector3(5, 2, -1)}
				"pickup": data = {"g": grenade}
				"door_kick": data = {"door": door, "pos": door.position}
				"melee", "launch", "launch_drone": data = {"target": target}
			assert(core.load_state(InfantryState.capture(s)))
			s._begin_action(kind, 0.05 if kind == "cook" else 2.0, data)
			assert(core.begin_action(InfantryState.action(s), s._action_related()))
			check_actor(s, core, rng, "begin %s %d" % [kind, trial])
			for tick in 6:
				w.time = 100.0 + tick * 0.1
				step(s, core, rng, 0.1)
				check_actor(s, core, rng, "%s %d tick %d" % [kind, trial, tick])
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
				checks += 1
			s.free()
	for trial in 64:
		var s := Executing.new()
		s.world = w
		s.eid = 1
		s.position = Vector3(0.3, 2.0, -0.1)
		s.rotation.y = trial * 0.37
		s.posture = trial % 5
		s.life = trial % 6
		s.flinging = true
		s.fling_v = Vector3(3.0, -2.0, -0.7)
		s.task_t = 0.3
		w.rng.seed = trial + 891
		rng.seed = trial + 891
		w.add_child(s)
		assert(core.load_state(InfantryState.capture(s)))
		for tick in 120:
			w.time = 200.0 + tick / 30.0
			if s.flinging:
				s._fling_tick(1.0 / 30.0)
				var result: Array = core.fling_tick(1.0 / 30.0, w.nav._planner, rng._backend)
				assert(result.size() == 2)
			elif s.life == Soldier.Life.ALIVE:
				step(s, core, rng, 1.0 / 30.0)
			if tick % 13 == 0:
				s.flinch_from(Vector3.ZERO, 0.3, 3.0)
				assert(core.flinch_from(0.3, 3.0))
			check_actor(s, core, rng, "blast %d tick %d" % [trial, tick])
			checks += 1
		s.free()
	var saved: PackedByteArray = core.checkpoint()
	assert(core.alive_stage(NAN, rng._backend) == -1)
	assert(not core.flinch_from(-1.0, 3.0))
	assert(core.checkpoint() == saved)
	grenade.free()
	print("INFANTRY_EXECUTION passed steps=", checks)
	get_tree().quit()
