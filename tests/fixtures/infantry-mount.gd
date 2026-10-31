extends "res://tests/fixtures/infantry-duties.gd"

class Gunman extends Dutyman:
	func _threats() -> Array: return [position + Vector3(10, 0, -20)]
	func _clear_cover() -> void:
		world.record("clear_cover", self)
		world.rng.randi()

class MountRules extends DutyRules:
	func mortar_target(_team: int, _p: Vector3, _near: float, _far: float) -> Vector3:
		world.record("mortar_target", world.entity(1))
		world.rng.randi()
		return Vector3.INF if world.trial % 5 == 0 else Vector3(0, 0, -60)

class MountCombat extends Combat:
	func fire_mortar(src: Soldier, from: Vector3, target: Vector3, kind: String) -> void:
		world.record("mortar", src, [from, target, kind, src.mortar_cd, src.last_shot_t])
		world.rng.randi()
	func fire_at(src: Soldier, from: Vector3, target: Entity, guided: bool) -> void:
		world.record("at", src, [from, target.eid, guided, src.rocket_cd, src.last_shot_t])
		world.rng.randi()

class MountCar extends ShotCar:
	func visible_to_team(_team: int) -> bool:
		return (world.trial + eid) % 11 != 0
	func exposed_points() -> Array:
		return [position + Vector3(0, 1.3, 0)]

class OriginalGunman extends Gunman:
	func _man_tick(dt: float) -> void:
		var st := task_ent as Structure
		if st == null or st.gone or not st.built:
			release_mount()
			return
		match task_phase:
			0:
				if is_moving():
					_move_tick(dt, _speed())
					_choose_act(true)
					return
				if st.skind == "watchtower":
					task_phase = 1
					task_t = 1.6
					position = Vector3(st.position.x, 0, st.position.z)
				else:
					task_phase = 2
					position = st.mount_pos()
					gun_override = st.mount_weapon()
					match st.skind:
						"mortar_pit":
							say("On the mortar!", true)
						"at_post":
							say("AT post manned!", true)
						_:
							say("Manning the gun!", true)
			1:
				task_t -= dt
				act = Act.CLIMB
				position.y = lerpf(0.0, 4.25, clampf(1.0 - task_t / 1.6, 0.0, 1.0))
				if task_t <= 0.0:
					task_phase = 2
					base_y = 4.25
					position = st.mount_pos()
		if task_phase != 2:
			return
		position = st.mount_pos()
		match st.skind:
			"mortar_pit":
				_mortar_pit_tick(dt, st)
				return
			"at_post":
				_at_post_tick(dt, st)
				return
			"mg_nest", "hmg_nest":
				at_cover = true
				cover_type = Cov.LOW
				cover_threat = _threat_dir(_threats())
				_weapon_tick(dt, false, "crew")
				_choose_act(false)
				return
		at_cover = true
		cover_type = Cov.LOW
		cover_threat = _threat_dir(_threats())
		_weapon_tick(dt, false, "normal")
		_choose_act(false)


	func _mortar_pit_tick(dt: float, st: Structure) -> void:
		posture = Post.CROUCH
		act = Act.LAUNCH if world.time - last_shot_t < 0.7 else Act.IDLE
		if world.time < mortar_cd:
			return
		if _pit_aim == Vector3.INF:
			_pit_kind = "he"
			_pit_delay = 2.2 if not st.fire_queue.is_empty() else 5.0
			if not st.fire_queue.is_empty():
				var fm: Array = st.fire_queue.pop_front()
				_pit_aim = fm[0]
				_pit_kind = fm[1]
			else:
				_pit_aim = world.rules.mortar_target(team, st.position, 30.0, 160.0)
			if _pit_aim == Vector3.INF:
				mortar_cd = world.time + 2.0
				_face(st.front_dir(), dt, 3.0)
				return
		var dir := Defs.flat(_pit_aim - position)
		_face(dir, dt)
		if absf(wrapf(Defs.yaw_of(dir) - rotation.y, -PI, PI)) > 0.035:
			return
		mortar_cd = world.time + _pit_delay
		last_shot_t = world.time
		world.combat.fire_mortar(self, st.position + Vector3(0, 1.0, 0), _pit_aim, _pit_kind)
		_pit_aim = Vector3.INF


	func _at_post_tick(dt: float, st: Structure) -> void:
		posture = Post.CROUCH
		act = Act.LAUNCH if world.time - last_shot_t < 1.0 else Act.IDLE
		var eye := st.position + Vector3(0, 1.3, 0)
		_mount_scan_t -= dt
		if _mount_scan_t <= 0.0:
			_mount_scan_t = 0.7
			_mount_target = null
			var bd := 130.0
			for v in world.vehicles:
				if v.team == team or v.team < 0 or not v.visible_to_team(team):
					continue
				var d: float = Defs.flat(v.position - st.position).length()
				if d > bd or not world.combat.can_see_from(eye, v, []):
					continue
				bd = d
				_mount_target = v
		if not is_instance_valid(_mount_target) or _mount_target.gone:
			return
		var dir := Defs.flat(_mount_target.position - st.position).normalized()
		_face(dir, dt)
		if world.time < rocket_cd or absf(wrapf(Defs.yaw_of(dir) - rotation.y, -PI, PI)) > 0.035:
			return
		if not world.combat.can_see_from(eye, _mount_target, []):
			return
		rocket_cd = world.time + 7.0
		last_shot_t = world.time
		world.combat.fire_at(self, eye + dir * 0.9, _mount_target, team == Defs.ARMY)
		say("Missile away!" if team == Defs.ARMY else "Recoilless, fire!")


	## Mobile mortar teams: fire missions first, otherwise shell spotted enemies.

func mount_world(native: bool) -> MedicalScene:
	var w := duty_world(native)
	w.rules = MountRules.new(w)
	w.combat = MountCombat.new(w)
	w.combat.enable_native_collision()
	w.entity(1).free()
	register(w, Gunman.new() if native else OriginalGunman.new(), 1)
	for id in range(20, 28):
		register(w, MountCar.new(), id)
		w.vehicles.append(w.entity(id))
	register(w, ShotWall.new(), 99)
	body(w.entity(99), Vector3(4, 5, 4))
	return w

func _ready() -> void:
	MapDims.N = 64
	MapDims.HALF = 32.0
	MapDims.SIZE = 64.0
	MapDims.BIOME = 64
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	assert(ClassDB.class_exists("InfantryMountCore"))
	var worlds := [mount_world(false), mount_world(true)]
	var checks := 0
	var outcomes := {}
	for trial in 256:
		for kind in ["watchtower", "mg_nest", "hmg_nest", "mortar_pit", "at_post"]:
			for w: MedicalScene in worlds:
				w.trial = trial
				w.rng.seed = trial + 1481
				w.effects.clear()
				w.spoken.clear()
				w.stats.clear()
				var s: Soldier = w.entity(1)
				var st: Structure = w.entity(11)
				st.skind = kind
				st.team = trial % 2
				st.gone = trial % 43 == 0
				st.built = trial % 47 != 0
				st.position = Vector3.ZERO
				st.yaw = trial * 0.17
				st.fire_queue = [[Vector3(0, 0, -50), "smoke"], [Vector3(20, 0, -60), "he"]] if trial % 2 else []
				s.team = trial % 2
				s.position = st.mount_pos()
				s.rotation.y = trial * 0.031
				s.base_y = 4.25 if kind == "watchtower" and trial % 3 == 2 else 0.0
				s.task = "man"
				s.task_ent = st
				s.mounted = st
				s.task_phase = trial % 3
				s.task_t = [0.0, 0.01, 0.8, 1.6][(trial / 3) % 4]
				s.goal = Vector3(0, 0, 2)
				s.path = PackedVector3Array([s.goal]) if trial % 2 else PackedVector3Array()
				s.path_i = 0
				s._path_pending = trial % 7 == 0
				s.posture = Soldier.Post.STAND
				s.act = Soldier.Act.IDLE
				s.at_cover = false
				s.cover_type = Soldier.Cov.NONE
				s.cover_threat = Vector3.ZERO
				s.gun_override = {}
				s.next_cover_eval = 9.0
				s.last_shot_t = 9.5 if trial % 2 else 0.0
				s.mortar_cd = 11.0 if trial % 5 == 0 else 0.0
				s.rocket_cd = 11.0 if trial % 7 == 0 else 0.0
				s.say_cd = 0.0
				s._pit_aim = Vector3.INF if trial % 3 else Vector3(0, 0, -70)
				s._pit_kind = "smoke" if trial % 2 else "he"
				s._pit_delay = 2.2 if trial % 2 else 5.0
				s._mount_scan_t = 0.01 if trial % 3 else 0.8
				s._mount_target = w.entity(20) if trial % 2 else null
				for v: Vehicle in w.vehicles:
					v.team = 1 - s.team if v.eid % 3 else s.team
					v.gone = false
					v.position = Vector3(0, 0, -[20.0, 40.0, 40.0, 130.0, 130.01, 70.0, 10.0, 45.0][v.eid - 20])
					if trial % 2:
						v.position.x = float((v.eid - 20) % 3) * 7.5
				w.entity(99).position = Vector3(0, 0, -5) if trial % 4 == 0 else Vector3(20, 0, 20)
				w.combat.dirty_collision(99)
				w.combat._visibility.set_fires(PackedFloat64Array([0, 1, -15, 3]) if trial % 13 == 0 else PackedFloat64Array())
			for tick in 12:
				var dt: float = [0.0, 1.0 / 30.0, 0.2, 1.7][trial % 4]
				for w: MedicalScene in worlds:
					w.step = tick
					w.time = 10.0 + tick * dt
					w.entity(1)._man_tick(dt)
				var label := "%s trial=%d tick=%d" % [kind, trial, tick]
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				for key in ["position", "rotation", "base_y", "task", "task_phase", "task_t", "posture", "act", "at_cover", "cover_type", "cover_threat", "gun_override", "next_cover_eval", "goal", "path", "path_i", "_path_pending", "last_shot_t", "mortar_cd", "rocket_cd", "say_cd", "_pit_kind", "_pit_delay", "_mount_scan_t"]:
					same(a.get(key), b.get(key), label + ":" + key)
				if a._pit_aim == Vector3.INF:
					assert(b._pit_aim == Vector3.INF, label + ":aim")
				else:
					same(a._pit_aim, b._pit_aim, label + ":aim")
				assert(eid(a.mounted) == eid(b.mounted) and eid(a.task_ent) == eid(b.task_ent), label + ":mount")
				assert(eid(a._mount_target) == eid(b._mount_target), label + ":target")
				same(worlds[0].entity(11).fire_queue, worlds[1].entity(11).fire_queue, label + ":queue")
				assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
				same(worlds[0].effects, worlds[1].effects, label + ":effects")
				assert(worlds[0].spoken == worlds[1].spoken and worlds[0].stats == worlds[1].stats, label + ":speech/stats")
				for event: Array in worlds[1].effects:
					outcomes[event[0]] = true
				if b._mount_core:
					var saved: PackedByteArray = b._mount_core.checkpoint()
					assert(b._mount_core.restore(saved) and b._mount_core.checkpoint() == saved)
				checks += 1
	for key in ["mortar", "at", "mortar_target", "move", "weapon", "clear_cover"]:
		assert(outcomes.has(key), "Uncovered mount effect " + key)
	var w: World = worlds[1]
	var s: Soldier = w.entity(1)
	var removed := ShotWall.new()
	register(w, removed, 50)
	s.task = "man"
	s.task_ent = removed
	s.mounted = removed
	s.base_y = 4.25
	w.entities.erase(50)
	removed.free()
	s._man_tick(1.0 / 30.0)
	assert(s.task == "" and s.mounted == null and s.base_y == 0.0, "Removed mount is released")
	print("INFANTRY_MOUNT_FREED passed")
	print("INFANTRY_MOUNT passed steps=", checks)
	for world: World in worlds:
		world.free()
	get_tree().quit()
