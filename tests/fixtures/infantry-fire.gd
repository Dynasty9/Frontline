extends "res://tests/fixtures/vehicle-scan.gd"

class FiringCombat extends ScanCombat:
	var shots := []
	func fire_bullet(shooter: Entity, muzzle: Vector3, aim: Vector3, target: Entity, weapon: Dictionary, accuracy := 1.0) -> void:
		shots.append([muzzle, aim, InfantryState.entity_id(target), accuracy, InfantryState.capture(shooter)])
		for draw in 1 + shooter.eid % 5:
			world.rng.randi()

func gun_profile(st: Structure) -> PackedFloat64Array:
	var g: Dictionary = WeaponModels.GUNS[st.mg_kind()]
	return PackedFloat64Array([g.bore, g.muzzle, (g.grip_r as Vector3).z, g.nest_h, g.trench_h])

func _ready() -> void:
	var layout := RandomNumberGenerator.new()
	layout.seed = 17391
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var squad: RefCounted = ClassDB.instantiate("SquadStateCore")
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for trial in 192:
		var w := ScanWorld.new()
		w.has_view = false
		w.srv = true
		w.settings = {"rust_infantry": false}
		w.combat = FiringCombat.new(w)
		w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
		w.combat._visibility = ClassDB.instantiate("VisibilityCore")
		var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
		add_child(w)
		w.rng.seed = trial + 7139
		random.seed = trial + 7139
		var q := Squad.new()
		q.sid = 9
		q.world = w
		q.morale = [-1.0, 11.9, 12.0, 32.9, 33.0, 54.9, 55.0, 100.0][trial % 8]
		q.drill = "rout" if trial % 13 == 0 else ""
		q.ambush_t = 21.0
		q.cover_fire_until = 20.7 if trial % 5 == 0 else 0.0
		q.cover_fire_pos = Vector3(-20, 0, -30)
		for id in range(1, 5):
			var s := make_soldier(w, id, 0 if id < 4 else 1)
			s.position = Vector3((id - 1) * 2, 0, -25 if id == 4 else 0)
			s.at_cover = true
			s.cover_type = Soldier.Cov.LOW
			s.cover_h = [0.0, 0.5, 0.8, 1.3][(id + trial) % 4]
			s.cover_n = Vector3.FORWARD
			s.lean_dir = Vector3.LEFT
			s.peek_up = id == 4 or trial % 5 == 0
			s.peek_t = 3.0
			s.posture = (id + trial) % 5
			s.say_cd = 5.0 if trial % 3 == 0 else 0.0
			s.suppression = trial % 90
			s.stamina = layout.randf()
			s.last_shot_t = 19.7 if trial % 4 == 0 else -10.0
			if id < 4:
				s.squad = q
				s.sid = q.sid
			w.soldiers.append(s)
		q.members = [w.entities[1], w.entities[3], w.entities[2]]
		q.known[4] = {"e": w.entities[4], "pos": w.entities[4].position, "t": 16.0}
		var v := Carrier.new()
		v.world = w
		v.eid = 5
		v.team = 1
		v.vkind = "tank"
		v.vdef = Defs.VEHICLES.tank
		v.position = Vector3(8, 0, -25)
		v.body = StaticBody3D.new()
		v.add_child(v.body)
		w.combat._rid_entities[v.body.get_rid()] = v.eid
		w.add_child(v)
		w.entities[5] = v
		w.vehicles.append(v)
		for id in [6, 8]:
			var st := Mount.new()
			st.world = w
			st.eid = id
			st.team = trial % 2
			st.skind = "depot" if id == 6 else ("mg_nest" if trial % 4 < 2 else "hmg_nest")
			st.position = Vector3(-8, 0, -25) if id == 6 else Vector3.ZERO
			st.yaw = trial * 0.371
			st.variant = trial % 2
			st.built = true
			w.add_child(st)
			w.entities[id] = st
		var drone := Drone.new()
		drone.eid = 7
		drone.team = 1
		drone.position = Vector3(4, 7, -22)
		w.entities[7] = drone
		var s: Soldier = w.entities[1]
		var st: Structure = w.entities[8]
		s.utype = "mg_gunner" if trial % 3 == 0 else "rifleman"
		s.udef = Defs.UNITS[s.utype]
		s.wdef = Defs.WEAPONS[s.udef.weapon]
		s.target = w.entities.get(4 + trial % 5)
		s.vis_targets = [w.entities[4]]
		s.mag = trial % 20
		s.reserve = trial % 100
		s.rotation.y = layout.randf_range(-PI, PI)
		s.blind = trial % 4 == 0
		s.cf_until = 21.2 if trial % 7 == 0 else 0.0
		s.cf_pos = Vector3(20, 0, -30)
		if trial % 2 == 0:
			s.mounted = st
			s.gun_override = st.mount_weapon()
			s.position = st.mount_pos() + (Vector3.RIGHT if trial % 6 == 0 else Vector3.ZERO)
		if trial % 3 == 0: s.path = PackedVector3Array([Vector3(20, 0, 20)])
		s._path_pending = trial % 5 == 0
		var blocks := []
		var types := PackedByteArray()
		for e: Entity in w.entities.values():
			if e is Soldier:
				blocks.append(soldier_bytes(e))
				types.append(0)
			elif e is Vehicle:
				blocks.append(vehicle_bytes(e, vehicle))
				types.append(2)
			elif e is Drone:
				blocks.append(drone_bytes(e, actors))
				types.append(4)
			else:
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
				types.append(1)
		assert(actors.load_state(100, types, blocks))
		assert(squad.load_state(SquadState.capture(q)))
		var weapon: Dictionary = s.cur_weapon()
		var burst: Vector2i = weapon.burst
		var fire_profile := PackedFloat64Array([weapon.ammo, weapon.get("mag", 30), weapon.get("reload", 2.0), burst.x, burst.y])
		var recovery := PackedFloat64Array([weapon.ammo, weapon.get("mag", 30), weapon.get("reload", 2.0), weapon.interval])
		for step in 16:
			w.time = 20.0 + step * 0.1
			w.stats.clear()
			w.spoken.clear()
			if step % 4 == 0:
				collider(w.combat._collision, 99, Vector3(step * 2 - 12, 2, -10), Vector3(8, 4, 0.5))
			var smoke := PackedFloat64Array([0, 2, -8, 8 if step % 3 == 0 else 0])
			assert(w.combat._visibility.set_fires(smoke) and visibility.set_fires(smoke))
			var own_cf: bool = s.cf_until > w.time
			var cf: bool = own_cf or q.cover_fire_until > w.time
			var cfp: Vector3 = s.cf_pos if own_cf else q.cover_fire_pos
			var aim: Vector3 = s._weapon_aim_reference(s._target_valid(s.target), cf, cfp, weapon.range)
			var result: Array = actors.aim_infantry(1, w.time, weapon.range, squad, w.combat._collision, visibility, random._backend)
			assert(result.size() == 3 and result[0] == aim and result[1] == InfantryState.entity_id(s._aim_ent), "Aim %d/%d: %s / %s" % [trial, step, result, aim])
			assert(int(result[2]) == w.stats.get("perception_blocked_reused", 0))
			assert(random.state == w.rng.state, "Aim random cursor")
			var buddy: bool = s._buddy_up()
			s._call_cover()
			var reply: Array = actors.infantry_cover_reply(1, w.time, squad, random._backend)
			assert(reply.size() == 3 and reply[0] == buddy)
			var spoken := []
			if reply[2] >= 0: spoken.append([reply[1], ["Covering!", "Got you covered!", "I'm up!"][reply[2]]])
			assert(w.spoken == spoken, "Cover reply %s / %s" % [w.spoken, spoken])
			assert(random.state == w.rng.state, "Cover random cursor")
			w.spoken.clear()
			w.combat.shots.clear()
			if aim != Vector3.INF:
				var moving := step % 2 == 0
				s._shoot_reference(aim, s._aim_ent, moving, cf)
				var shot: Array = actors.prepare_infantry_shot(1, w.time, moving, fire_profile, gun_profile(st), squad, random._backend)
				assert(shot.size() == 6)
				spoken.clear()
				if shot[3] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][shot[3]]])
				if shot[2]: spoken.append([1, "Low on ammo!"])
				assert(int(shot[0]) == w.combat.shots.size())
				if shot[0]:
					var capture: Array = w.combat.shots[0]
					assert((shot[5] as Vector3).distance_to(capture[0]) < 0.00001, "Muzzle %d/%d: %s / %s" % [trial, step, shot[5], capture[0]])
					assert(shot[4] == capture[3], "Shot accuracy")
					assert(state.restore(actors.actor_state(1)))
					assert(state.values() == capture[4], "State before bullet effects %d/%d" % [trial, step])
					for draw in 2: random.randi()
					var finish: Array = actors.finish_infantry_shot(1, recovery, shot[1], cf, random._backend)
					assert(finish.size() == 1)
					if finish[0] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][finish[0]]])
					seen["fired"] = true
					if s.crew_mount() != null: seen["mounted"] = true
					if s.blind: seen["blind"] = true
					if shot[1]: seen["low"] = true
				else: seen["reload"] = true
				assert(w.spoken == spoken, "Firing speech %s / %s" % [w.spoken, spoken])
				assert(random.state == w.rng.state, "Shot random cursor %d/%d" % [trial, step])
			for member in w.soldiers:
				compare_actor(member, actors, "fire %d/%d/%d" % [trial, step, member.eid])
				checks += 1
			if step == 7:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.free()
		drone.free()
	for key in ["fired", "mounted", "blind", "low", "reload"]: assert(seen.has(key), "Fixture must exercise " + key)
	print("INFANTRY_FIRE passed states=%d outcomes=%s" % [checks, seen])
	get_tree().quit()
