extends Node

func _ready() -> void:
	assert(ClassDB.class_exists("InfantryStateCore"))
	var core: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var restored: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var s := Soldier.new()
	var mate := Soldier.new()
	var wall := Structure.new()
	var car := Vehicle.new()
	var grenade := Projectile.new()
	var drone := Drone.new()
	var refs := [s, mate, wall, car, grenade, drone]
	for i in refs.size():
		refs[i].eid = i + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1773
	for trial in 256:
		for field in ["hp", "max_hp", "base_hp", "suppression", "_supp_t", "reveal_t", "bleed", "bleed_max", "say_cd",
			"hit_dirt_t", "downed_t", "dead_t", "scream_t", "pistol_t", "crawl_t", "_stuck_t", "slide_t", "slide_cd",
			"_bar_t", "_gy_t", "_gy", "door_wait", "_door_t", "peek_t", "_peek_from", "_up_supp", "reload_t", "fire_t",
			"last_shot_t", "rocket_cd", "drone_cd", "mortar_cd", "melee_cd", "grenade_cd", "scav_t", "resupply_t",
			"hidden_t", "calm_t", "idle_until", "idle_next", "_laugh_until", "think_t", "_doing_t", "dive_t",
			"dazed_t", "flinch_t", "los_t", "act_t", "base_y", "leash", "next_cover_eval", "cover_h", "task_t",
			"intel_t", "bt_next_breach", "bt_cook_t0", "bt_wait", "_mount_scan_t", "_pit_delay", "cf_until", "_fire_flee_t", "build_snd_t"]:
			s.set(field, rng.randf_range(0.1, 200.0))
		for field in ["gone", "vaulting", "_bar", "door_kick", "peek_up", "_stayed", "_watching", "blind", "low_ammo_said",
			"flinging", "los_ok", "_path_pending", "backwards", "detached", "at_cover", "_shifting", "is_front",
			"stretcher_claimed", "tent_dead", "bt_clear", "bt_nofrag", "bt_reordered", "out_said", "_shuffle"]:
			s.set(field, rng.randi() % 2 == 0)
		for field in ["_stuck_p", "_last_dir", "_sim_prev", "dive_dir", "fling_v", "goal", "hold_pos", "hold_face",
			"cover_pos", "lean_dir", "cover_threat", "cover_n", "task_pos", "task_pos2", "cf_pos", "_sector", "_sep", "_hit_dir"]:
			s.set(field, Vector3(rng.randf_range(-30, 30), rng.randf_range(-2, 2), rng.randf_range(-30, 30)))
		s.position = Vector3(trial * 0.37, -0.2, -trial * 0.19)
		s.rotation.y = rng.randf_range(-PI, PI)
		s.team = trial % 3 - 1
		s.owner_peer = trial - 2
		s.vis_mask = trial % 4
		s.seen_mask = (trial + 1) % 4
		s.sname = "André %d" % trial
		s.sid = trial
		s.wdef = Defs.WEAPONS.mmg if trial % 2 else {}
		s.gun_override = Defs.WEAPONS.m2 if trial % 3 else {}
		s.hit_by = [7, 1, "tank", 37] if trial % 2 else []
		s.life = trial % 6
		s.times_downed = trial
		s.stamina = rng.randf()
		s.path = PackedVector3Array([Vector3.ZERO, Vector3(1.2, 3.4, -5.6), Vector3(9, -0.4, 17)])
		s.path_i = trial % 4
		s.door_st = wall
		s.mag = trial % 30
		s.reserve = trial
		s.burst_left = trial % 4
		s.rockets = trial % 5
		s.drones_left = trial % 6
		s.mortar_rounds = trial % 7
		s.frags = trial % 4
		s.smokes = trial % 3
		s.hidden_reason = InfantryState.HIDDEN[trial % 7]
		s.idle_act = [0, 26, 28, 29, 30, 31, 32][trial % 7]
		s.chat_with = mate
		s._banter = [[3.7, "Ready, André?"], [9.2, "Yes."]] if trial % 2 else []
		s.scan_n = trial
		s.los_ent = mate
		s.seen_grenades = {3: true, 17: true, 5: true}
		s.heard_drones = {32: true, 6: true}
		s.act_kind = Soldier.ACTION_KINDS[trial % 12]
		s.act_data = {"g": grenade, "target": mate, "door": wall, "pos": Vector3(3, 1, 2), "kind": "smoke", "fuse": 2.1, "v": Vector3(1, 2, 3)}
		s._queued_throw = {"pos": Vector3(4, 2, -3), "kind": "frag", "fuse": 1.7} if trial % 2 else {}
		s._path_revision = trial * 37
		s.goal_kind = InfantryState.GOALS[trial % 6]
		s.move_mode = trial % 3
		s.cover_type = trial % 4
		s.cover_mat = trial % 5 - 1
		s.cover_st = wall
		s.cover_ai = trial - 1
		s.task = Soldier.CONTROLLER_TASKS[trial % Soldier.CONTROLLER_TASKS.size()]
		s.task_ent = mate
		s.task_ent2 = grenade
		s.task_phase = trial % 12
		s.throw_kind = "smoke" if trial % 2 else "frag"
		s.riding = car
		s.dragged_by = mate
		s.rescue_claimed = mate
		s.carried_by = [mate, s]
		s.captor = mate
		s.hidden_in = wall
		s.home = wall
		s.prison_dest = wall
		s.intel_left = trial
		s.bt_breach = [wall, [wall, Vector3.RIGHT, Vector3.FORWARD, true], mate] if trial % 2 else []
		s.bt_house = wall
		s.bt_door = [wall, Vector3(1.2, 0, 3.4), Vector3.LEFT, false] if trial % 3 else []
		s.bt_breach_g = grenade
		s.mounted = wall
		s._mount_target = car
		s._pit_aim = Vector3(7.2, 0, -4.6) if trial % 2 else Vector3.INF
		s._pit_kind = "smoke" if trial % 3 else "he"
		s.target = mate
		s.forced_target = car
		s.vis_targets = [mate, wall, car]
		s.fteam = trial % 2
		s.drone_ctrl = drone
		s.bt_g = grenade
		s.loot = trial
		s.posture = trial % 5
		s.act = trial % 37
		s.flags = trial
		s.doing = trial % 53
		s.doing_ent = trial
		s._hit_kind = "blast" if trial % 2 else "bullet"
		var values := InfantryState.capture(s)
		assert(core.load_state(values), "Actor import trial %d" % trial)
		assert(core.values() == values, "Actor fields trial %d" % trial)
		var saved: PackedByteArray = core.checkpoint()
		assert(not saved.is_empty())
		assert(restored.restore(saved))
		assert(restored.values() == values, "Restored actor fields trial %d" % trial)
		assert(restored.checkpoint() == saved)
		var broken := values.duplicate(true)
		broken[0][0] = 4294967296
		assert(not core.load_state(broken))
		assert(core.checkpoint() == saved)
		broken = values.duplicate(true)
		broken[2][5] = NAN
		assert(not core.load_state(broken))
		assert(core.checkpoint() == saved)
		saved.resize(saved.size() - 1)
		assert(not core.restore(saved))
		assert(core.values() == values)
	for e in [mate, wall, car, grenade, drone]:
		e.free()
	var stale := InfantryState.capture(s)
	assert(core.load_state(stale), "Removed entities must leave nullable IDs")
	assert(core.values() == stale)
	s.free()
	print("INFANTRY_STATE passed actors=256 removed=5")
	get_tree().quit()
