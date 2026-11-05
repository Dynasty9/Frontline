extends "res://tests/fixtures/infantry-motion.gd"

func check_state(s: Soldier, core: RefCounted, label: String) -> void:
	var expected := InfantryState.capture(s)
	var actual: Array = core.values()
	var motion: PackedFloat64Array = expected[1][1][0]
	var native: PackedFloat64Array = actual[1][1][0]
	for i in [0, 1, 2, 3, 5, 6, 7, 12, 13, 14]:
		assert(absf(motion[i] - native[i]) < 0.00001, "%s motion %d" % [label, i])
		motion[i] = native[i]
	expected[1][1][0] = motion
	assert((expected[1][6][2] as Vector3).distance_to(actual[1][6][2]) < 0.00001, label + " previous position")
	expected[1][6][2] = actual[1][6][2]
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s vs %s" % [label, group, expected[group], actual[group]])

func activities(w: World) -> void:
	var s := make_soldier(w, 0, Vector3.ZERO, PackedVector3Array())
	var other := Trooper.new()
	other.world = w
	other.eid = 101
	w.add_child(other)
	var mount := add_structure(w, 102, "mg_nest", Vector3.ZERO, 0)
	var squad := Squad.new()
	squad.world = w
	squad.members = [s, other]
	s.squad = squad
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	for trial in 8880:
		s.life = trial % 6
		s.task = task_name(trial / 6 % 20)
		s.act = trial / 120 % 37
		s.posture = trial % 5
		s.task_phase = trial / 4440 * 2
		s.task_ent = other
		other.gone = trial % 2 == 0
		s.mounted = mount if trial % 3 else null
		s.chat_with = other if trial % 7 else null
		s.dragged_by = other if trial % 7 else null
		s.carried_by = [other] if trial % 11 else []
		s.flags = trial % 16
		s.hit_dirt_t = 0.1 if trial % 13 == 0 else 0.0
		s.goal_kind = "cover"
		s._path_pending = trial % 3 == 0
		s._shifting = trial % 5 == 0
		s.cover_type = trial % 4
		s.at_cover = trial % 3 == 0
		s.cover_h = 0.8
		s.blind = trial % 7 == 0
		s.target = other
		squad.ambush = trial % 11 == 0
		assert(core.load_state(InfantryState.capture(s)))
		s._update_doing_work()
		assert(core.update_activity(not other.gone, s.mounted != null, s.chat_with != null, squad.ambush and s._target_valid(s.target)))
		check_state(s, core, "activity %d" % trial)
	for e in w.entities.values():
		w.combat.remove_collision(e.eid)
	w.entities.clear()
	s.free()
	other.free()
	mount.free()

func task_name(code: int) -> String:
	return ["", "rescue", "escort", "heal", "build", "stretcher", "limp", "captor", "man", "tunnel", "board", "resupply", "grenade_pickup", "smother", "gkick", "breach", "retreat", "throw", "pilot", "unknown"][code]

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var a := make_world()
	var b := make_world()
	activities(a)
	var samples := RandomNumberGenerator.new()
	samples.seed = 67185
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	for trial in 100:
		var yaw := samples.randf_range(-PI, PI)
		var direction := Defs.dir_of(yaw)
		var start := -direction * (0.6 if trial % 2 == 0 else 8.0)
		var route := PackedVector3Array([Vector3.ZERO, direction * 12.0])
		if trial % 5 == 0:
			route = PackedVector3Array([start, start, direction * 2.0])
		for w in [a, b]:
			w.rng.seed = trial + 177
			w.stats.clear()
			w.spoken.clear()
			w.effects.clear()
			w.time = 0.0
			var door := add_structure(w, 1, "house_wall", Vector3.ZERO, yaw)
			door.door_shut = true
			door.parts = [{"p": Vector3(0, 1, Structure.DOOR_Z), "s": Vector3(1.8, 2, 0.1), "r": 0.0, "col": true, "door": true}]
			door._make_body()
			w.add_door(door)
			var wall := add_structure(w, 2, "low_wall", direction * 3, yaw)
			wall.parts = [{"p": Vector3(0, 0.4, 0), "s": Vector3(20, 0.8, 0.4), "r": 0.0, "col": true}]
			wall._make_body()
			var mounted := add_structure(w, 3, ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4], start, yaw)
			var s := make_soldier(w, trial, start, route)
			if trial % 4 == 0:
				s.mounted = mounted
				mounted.position += start - mounted.mount_pos()
			if trial % 10 == 0:
				s._stuck_t = 3.1
			if trial % 9 == 0:
				s._path_pending = true
		assert(core.load_state(InfantryState.capture(b.entity(100))))
		for tick in 180:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			a.time += dt
			b.time += dt
			var s: Soldier = a.entity(100)
			var shadow: Soldier = b.entity(100)
			s._recover_tick(dt)
			s._fatigue_tick(dt)
			assert(core.recover(dt, b.time))
			assert(core.fatigue(dt))
			var state: Array = core.values()
			var motion: PackedFloat64Array = state[1][1][0]
			var position := Vector3(motion[0], motion[1], motion[2])
			var candidates := []
			for door in b.door_cells.get(Vector2i(floori(position.x / 1.5), floori(position.z / 1.5)), []):
				if not door.gone:
					candidates.append([door.eid, door.position, door.yaw])
			var waiting: Structure = b.entity(state[1][1][2]) as Structure
			b.combat._sync_collision()
			var output: Array = core.move_route([dt, b.time, 3.2, s._danger(), not b.door_cells.is_empty(), waiting != null and waiting.door_shut, shadow._mount_turn()],
				candidates, b.nav._planner, b.terrain._native, b.combat._collision, b.rng._backend, b.water.deck)
			assert(output.size() == 6)
			if not output[3].is_empty():
				shadow.position = output[3][2]
				(b.entity(output[3][0]) as Structure).open_door(shadow, output[3][1])
			if output[4] >= 0:
				b.say(shadow, ["Breaching!", "Door!", "Kicking it in!"][output[4]])
			if output[5]:
				b.stat("slide")
			var after: PackedFloat64Array = core.values()[1][1][0]
			shadow.position = Vector3(after[0], after[1], after[2])
			if not output[1].is_empty():
				b.stat("repath")
				var revision: int = output[1][0]
				b.nav.request_path(shadow, output[1][1], false, shadow.team, output[1][2], func(points: PackedVector3Array) -> void:
					assert(core.accept_path(revision, points, b.time, b.rng._backend) >= 0))
			assert(output[2] == 0)
			var expected := s._move_tick_reference(dt, 3.2)
			assert(expected == output[0], "moving %d/%d" % [trial, tick])
			if not expected:
				s._stationary_reference(dt)
				assert(core.stand([dt, b.time, false, shadow._mount_turn()], b.nav._planner, b.terrain._native, b.water.deck))
			s._posture_sanity(dt)
			s._update_flags_work()
			assert(core.finish_tick(dt, b.time, PackedInt32Array(), false) >= 0)
			check_state(s, core, "tick %d/%d" % [trial, tick])
			assert(a.rng.state == b.rng.state, "draws %d/%d" % [trial, tick])
			assert(a.stats == b.stats and a.spoken == b.spoken and a.effects == b.effects, "effects %d/%d" % [trial, tick])
			if tick % 23 == 0:
				assert(core.restore(core.checkpoint()))
		for w in [a, b]:
			w.door_cells.clear()
			for e in w.entities.values():
				w.combat.remove_collision(e.eid)
				e.free()
			w.entities.clear()
	a.free()
	b.free()
	print("INFANTRY_UPDATE passed labels=8880 steps=18000")
	get_tree().quit()
