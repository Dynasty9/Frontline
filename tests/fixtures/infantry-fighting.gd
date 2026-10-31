extends "res://tests/fixtures/infantry-fire.gd"

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var squad: RefCounted = ClassDB.instantiate("SquadStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var random := SimulationRandom.new()
	var layout := RandomNumberGenerator.new()
	layout.seed = 17391
	var seen := {}
	checks = 0
	for trial in 192:
		var w: World = ground_world()
		w.settings = {"rust_infantry": false, "debug": true}
		w.combat = FiringCombat.new(w)
		w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
		w.combat._visibility = ClassDB.instantiate("VisibilityCore")
		var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
		w.rng.seed = trial + 7139
		random.seed = trial + 7139
		var q := Squad.new()
		q.sid = 9
		q.world = w
		q.morale = [-1.0, 11.9, 12.0, 32.9, 33.0, 54.9, 55.0, 100.0][trial % 8]
		q.drill = "rout" if trial % 13 == 0 else ""
		q.ambush = trial % 17 == 0
		q.ambush_t = 22.0
		q.cover_fire_until = 21.7 if trial % 5 == 0 else 0.0
		q.cover_fire_pos = Vector3(-20, 0, -25)
		for id in range(1, 5):
			var s := make_soldier(w, id, trial % 2 if id < 4 else 1 - trial % 2)
			s.position = Vector3((id - 1) * 4, 0, -25 if id == 4 else 0)
			s.at_cover = true
			s.cover_type = Soldier.Cov.LOW if trial % 6 != 0 else Soldier.Cov.LEAN
			s.cover_h = [0.0, 0.4, 0.8, 1.3][trial % 4]
			s.cover_mat = trial % 4
			s.cover_n = Vector3.FORWARD
			s.cover_threat = Vector3(0.3, 0, -1)
			s.lean_dir = Vector3.LEFT
			s.peek_up = trial % 2 == 0
			s.peek_t = 0.2 + trial % 4
			s._peek_from = 18.0
			s._up_supp = 0.0
			s.posture = (id + trial) % 5
			s.say_cd = 5.0 if trial % 3 == 0 else 0.0
			s.suppression = trial % 94
			s.stamina = layout.randf()
			s.last_shot_t = 19.7 if trial % 4 == 0 else -10.0
			if id < 4:
				s.squad = q
				s.sid = q.sid
			w.soldiers.append(s)
		q.members = [w.entities[1], w.entities[3], w.entities[2]]
		q.known[4] = {"e": w.entities[4], "pos": w.entities[4].position, "t": 19.0}
		var st := Mount.new()
		st.world = w
		st.eid = 8
		st.team = trial % 2
		st.skind = ("mg_nest" if trial % 4 < 2 else "hmg_nest") if trial % 3 == 2 else "low_wall"
		st.variant = trial % 2
		st.built = true
		for i in 3:
			st.anc_p.append(Vector3([0.0, 2.0, -2.0][i], 0, 0))
			st.anc_n.append(Vector3.FORWARD)
			st.anc_h.append(1.3 if i == 0 else (0.4 if i == 1 else 0.8))
			st.anc_k.append((Cover.EDGE_R if i == 1 else Cover.EDGE_L) if trial % 6 == 0 else Cover.OVER)
		w.add_child(st)
		w.entities[8] = st
		var s: Soldier = w.entities[1]
		s.utype = "mg_gunner" if trial % 5 == 0 else "rifleman"
		s.udef = Defs.UNITS[s.utype]
		s.wdef = Defs.WEAPONS[s.udef.weapon]
		s.target = w.entities[4] if trial % 7 else null
		s.vis_targets = [w.entities[4]] if trial % 7 else []
		s.mag = trial % 25
		s.reserve = 90
		s.rotation.y = layout.randf_range(-PI, PI)
		s.blind = trial % 4 == 0
		s.cf_until = 21.2 if trial % 7 == 0 else 0.0
		s.cf_pos = Vector3(20, 0, -25)
		s.cover_st = st
		s.cover_ai = 0
		s._sector = Vector3.FORWARD if trial % 2 == 0 else Vector3.ZERO
		s.hit_dirt_t = 1.0 if trial % 11 == 0 else 0.0
		if trial % 3 == 2:
			s.mounted = st
			s.gun_override = st.mount_weapon()
			s.position = st.mount_pos() + (Vector3.RIGHT if trial % 5 == 0 else Vector3.ZERO)
		if trial % 7 == 0:
			s.path = PackedVector3Array([Vector3(2, 0, 0)])
			s.goal = Vector3(2, 0, 0)
			s.goal_kind = "cover"
			s.move_mode = trial % 3
		if trial % 8 == 0:
			w.entities[3].cover_pos = Vector3(2, 0, 0)
		var blocks := []
		var types := PackedByteArray()
		for e: Entity in w.entities.values():
			if e is Soldier:
				blocks.append(soldier_bytes(e))
				types.append(0)
			else:
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
				types.append(1)
		assert(actors.load_state(100, types, blocks))
		assert(squad.load_state(SquadState.capture(q)))
		assert(units.load_state(12.0, []) and units.rebuild_units(actors))
		w._rebuild_uhash()
		var weapon: Dictionary = s.cur_weapon()
		var burst: Vector2i = weapon.burst
		var fire_profile := PackedFloat64Array([weapon.ammo, weapon.get("mag", 30), weapon.get("reload", 2.0), burst.x, burst.y])
		var recovery := PackedFloat64Array([weapon.ammo, weapon.get("mag", 30), weapon.get("reload", 2.0), weapon.interval])
		var clocks := PackedFloat64Array([weapon.ammo, weapon.get("mag", 30), weapon.get("reload", 2.0)])
		for step in 64:
			w.time = 20.0 + step / 30.0
			w.stats.clear()
			w.spoken.clear()
			w.nav.jobs.clear()
			w.combat.shots.clear()
			if step % 16 == 0:
				collider(w.combat._collision, 99, Vector3(step - 12, 2, -10), Vector3(8, 4, 0.5))
			var smoke := PackedFloat64Array([0, 2, -8, 8 if step % 13 == 0 else 0])
			assert(w.combat._visibility.set_fires(smoke) and visibility.set_fires(smoke))
			var mode: int = trial % 3
			var moving := trial % 7 == 0
			s._weapon_tick_work(1.0 / 30.0, moving, ["normal", "escort", "crew"][mode])
			var ready: Array = actors.ready_infantry_weapon(1, PackedFloat64Array([1.0 / 30.0, w.time, int(moving), mode, weapon.range]), clocks, gun_profile(st), squad, w.nav._planner, units, w.combat._collision, visibility, random._backend)
			assert(ready.size() == 8)
			var spoken := []
			var cycle: PackedInt32Array = ready[4]
			if cycle[3] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][cycle[3]]])
			if ready[6] >= 0: spoken.append([ready[5], ["Covering!", "Got you covered!", "I'm up!"][ready[6]]])
			var stats := {}
			if cycle[0]: stats["t%d_drew" % s.team] = 1
			if cycle[1]: stats["t%d_peek" % s.team] = 1
			if cycle[2]: stats.blind_fire = 1
			if ready[2]: stats.perception_blocked_reused = 1
			var route: Array = ready[7]
			if not route.is_empty():
				stats.shift_along = 1
				assert(w.nav.jobs.size() == 1 and route.slice(1) == w.nav.jobs[0].slice(0, 5))
				assert(route[0] == s._path_revision)
				seen["shift"] = true
			else: assert(w.nav.jobs.is_empty())
			if ready[0] != Vector3.INF:
				var shot: Array = actors.prepare_infantry_shot(1, w.time, moving, fire_profile, gun_profile(st), squad, random._backend)
				assert(shot.size() == 6)
				if shot[3] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][shot[3]]])
				if shot[2]:
					spoken.append([1, "Low on ammo!"])
					stats.low_ammo = 1
				assert(int(shot[0]) == w.combat.shots.size())
				if shot[0]:
					var capture: Array = w.combat.shots[0]
					assert((shot[5] as Vector3).distance_to(capture[0]) < 0.00001, "Muzzle %d/%d" % [trial, step])
					assert([ready[0], ready[1], shot[4]] == [capture[1], capture[2], capture[3]], "Shot %d/%d" % [trial, step])
					assert(state.restore(actors.actor_state(1)))
					assert(state.values() == capture[4], "Before effects %d/%d" % [trial, step])
					for draw in 2: random.randi()
					var finish: Array = actors.finish_infantry_shot(1, recovery, shot[1], ready[3], random._backend)
					assert(finish.size() == 1)
					if finish[0] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][finish[0]]])
					seen["fired"] = true
			else: assert(w.combat.shots.is_empty(), "Unexpected shot %d/%d" % [trial, step])
			assert(w.spoken == spoken, "Speech %d/%d: %s / %s" % [trial, step, w.spoken, spoken])
			assert(w.stats == stats, "Stats %d/%d: %s / %s" % [trial, step, w.stats, stats])
			assert(random.state == w.rng.state, "Random cursor %d/%d" % [trial, step])
			assert(squad.values() == SquadState.capture(q), "Squad state %d/%d" % [trial, step])
			for member in w.soldiers:
				compare_actor(member, actors, "weapon %d/%d/%d" % [trial, step, member.eid])
				checks += 1
			if step == 31:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.nav.jobs.clear()
		w.free()
	assert(seen.has("shift") and seen.has("fired"), "Fixture must exercise shifts and shots: %s" % seen)
	print("INFANTRY_FIGHTING passed states=%d" % checks)
	get_tree().quit()
