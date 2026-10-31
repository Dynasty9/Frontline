extends "res://tests/fixtures/infantry-medicine.gd"

class Dutyman extends Medic:
	func _speed() -> float:
		world.record("speed", self)
		world.rng.randi()
		return 2.6
	func _return_to_hold() -> void:
		world.record("hold", self)
		world.rng.randi()
		task = ""
	func enter_tent(tent: Structure) -> void:
		world.record("tent", world.entity(1), [eid, tent.eid])
		world.rng.randi()
		life = Life.HIDDEN

class Work extends ShotWall:
	var needed := true
	func needs_work() -> bool:
		world.record("needs_work", world.entity(1), [eid])
		world.rng.randi()
		return needed
	func add_work(amount: float) -> bool:
		world.record("work", world.entity(1), [eid, amount])
		world.rng.randi()
		progress += amount
		needed = progress < 1.0
		return not needed
	func exit_pos() -> Vector3:
		world.record("exit", world.entity(1), [eid])
		world.rng.randi()
		return position + Vector3(0, 0, 3)

class WorkCar extends ShotCar:
	var needed := true
	func needs_repair() -> bool:
		world.record("needs_repair", world.entity(1), [eid])
		world.rng.randi()
		return needed
	func repair(amount: float) -> void:
		world.record("repair", world.entity(1), [eid, amount])
		world.rng.randi()
		hp += amount
		needed = hp < max_hp

class WorkSquad extends Squad:
	func on_build_done(st: Entity) -> void:
		world.record("built", world.entity(1), [st.eid if is_instance_valid(st) else 0])
		world.rng.randi()

class DutyRules extends MedicalRules:
	func take_prisoner(p: Soldier, c: Soldier) -> void:
		world.record("prisoner", c, [p.eid])
		world.rng.randi()
		p.life = Soldier.Life.CAPTIVE

class OriginalDutyman extends Dutyman:
	func _build_tick(dt: float) -> void:
		var st := task_ent
		var done := st == null or st.gone
		if not done:
			if st is Structure:
				done = not st.needs_work()
			elif st is Vehicle:
				done = not st.needs_repair()
		if done:
			task = ""
			if squad:
				squad.on_build_done(st)
			return
		if suppression > 55.0:
			posture = Post.CROUCH
			act = Act.IDLE
			_weapon_tick(dt, false, "normal")
			return
		if is_moving():
			_move_tick(dt, _speed())
			_choose_act(true)
			return
		if Defs.flat(position - task_pos).length() > 1.6:
			go_to(task_pos, "task", 1)
			return
		if _target_valid(target) and Defs.flat(target.position - position).length() < 18.0:
			_weapon_tick(dt, false, "normal")
			_choose_act(false)
			return
		_face(Defs.flat(st.position - position), dt, 8.0)
		act = Act.BUILD
		posture = Post.CROUCH
		var rate := float(udef.get("build", 1.0))
		if st is Structure:
			st.add_work(rate * dt)
		elif st is Vehicle:
			st.repair(rate * dt)
		build_snd_t -= dt
		if build_snd_t <= 0.0:
			build_snd_t = world.rng.randf_range(0.5, 0.9)
			world.fx_event([Fx.SOUND, "build", position])

	func _stretcher_tick(dt: float) -> void:
		var cas := task_ent as Soldier
		var partner := task_ent2 as Soldier
		var partner_ok := partner != null and not partner.gone and partner.life == Life.ALIVE and partner.task == "stretcher" and partner.task_ent == cas
		if home == null or home.gone or not _stretcher_valid(cas):
			_end_stretcher(false)
			return
		posture = Post.STAND
		match task_phase:
			0:
				if is_moving():
					_move_tick(dt, 4.4)
					act = Act.RUN
					return
				if Defs.flat(cas.position - position).length() > 1.8:
					go_to(cas.position, "task", 1)
					return
				task_phase = 1
				task_t = 1.4
			1:
				act = Act.PICKUP
				task_t -= dt
				if partner_ok and partner.task_phase == 0 and task_t > -8.0:
					return
				if task_t > 0.0:
					return
				if is_front or not partner_ok:
					task_phase = 2
					cas.carried_by = [self]
					if partner_ok:
						cas.carried_by.append(partner)
						partner.task_phase = 3
					go_to(home.exit_pos(), "task", 0)
					say("Lift on three!" if partner_ok else "I've got him!", true)
			2:
				var solo := not partner_ok
				var moved := _move_tick(dt, 0.95 if solo else 1.9)
				if solo:
					backwards = true
					act = Act.DRAG
					_face(-_last_dir, dt, 10.0)
					cas.position = position + Defs.dir_of(rotation.y) * 1.5 + Vector3(0, -0.55, 0)
					cas.rotation.y = rotation.y
					if cas.carried_by.size() > 1:
						cas.carried_by = [self]
						say("Bearer down! I'll drag him!", true)
				else:
					backwards = false
					act = Act.CARRY
					cas.position = position - _last_dir * 1.15
					cas.position.y = 0.0
					cas.rotation.y = Defs.yaw_of(-_last_dir)
				if not moved:
					var c := cas
					_end_stretcher(true)
					if partner_ok:
						partner._end_stretcher(true)
					c.enter_tent(home)
			3:
				if not partner_ok or partner.task_phase != 2:
					task_phase = 2
					cas.carried_by = [self]
					go_to(home.exit_pos(), "task", 0)
					return
				var md := Defs.dir_of(partner.rotation.y)
				var want := partner.position - md * 2.3
				position = position.lerp(want, 1.0 - exp(-dt * 10.0))
				position.y = 0.0
				rotation.y = partner.rotation.y
				act = Act.CARRY

	func _captor_tick(dt: float) -> void:
		var p := task_ent as Soldier
		if p == null or p.gone or (p.life != Life.SURRENDER and p.life != Life.CAPTIVE) or p.captor != self:
			_return_to_hold()
			return
		posture = Post.STAND
		match task_phase:
			0:
				if Defs.flat(p.position - position).length() < 2.6:
					task_phase = 1
					world.rules.take_prisoner(p, self)
					say(_pick(["Move! Hands where I can see them!", "On your feet! Walk!", "Easy... keep those hands up."]), true)
					return
				if not is_moving():
					go_to(p.position, "task", 1)
				_move_tick(dt, 4.0)
				act = Act.RUN
			1:
				var d := Defs.flat(p.position - position)
				if d.length() > 2.3:
					var np := position + d.normalized() * minf(d.length() - 2.0, 1.9 * dt)
					if world.nav.walkable(np):
						position = np
					else:
						position = position.lerp(p.position, 0.02)
					act = Act.WALK
				else:
					act = Act.SHOOT if world.rng.randf() < 0.0 else Act.IDLE
				_face(d, dt, 8.0)



func duty_world(native: bool) -> MedicalScene:
	var w := medical_world(native)
	w.rules = DutyRules.new(w)
	for id in [1, 3, 4]:
		w.entity(id).free()
		register(w, Dutyman.new() if native else OriginalDutyman.new(), id)
	register(w, ShotSoldier.new(), 5)
	register(w, Work.new(), 11)
	register(w, WorkCar.new(), 12)
	register(w, Work.new(), 13)
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
	assert(ClassDB.class_exists("InfantryDutiesCore"))
	var worlds := [duty_world(false), duty_world(true)]
	var checks := 0
	var outcomes := {}
	for trial in 1024:
		for kind in ["build", "stretcher", "captor"]:
			for w: MedicalScene in worlds:
				w.trial = trial
				w.rng.seed = trial + 7931
				w.effects.clear()
				w.spoken.clear()
				w.stats.clear()
				var s: Soldier = w.entity(1)
				var cas: Soldier = w.entity(3)
				var partner: Soldier = w.entity(4)
				var enemy: Soldier = w.entity(5)
				s.position = Vector3([0.0, 1.6, 1.8, 2.3, 2.6, 5.0][(trial / 2) % 6], 0.3 if trial % 7 == 0 else 0.0, 0)
				s.rotation.y = trial * 0.37
				s.task = kind
				s.task_ent = w.entity(11 + trial % 2) if kind == "build" else cas
				s.task_ent2 = partner
				s.task_phase = 0 if kind == "build" else trial % 4
				s.task_t = [0.01, 0.8, -7.8, -8.0][(trial / 3) % 4]
				s.task_pos = Vector3.ZERO
				s.build_snd_t = 0.01 if trial % 3 else 0.8
				s.home = w.entity(13)
				s.is_front = trial % 3 != 0
				s.posture = trial % 5
				s.act = Soldier.Act.IDLE
				s.backwards = false
				s.at_cover = true
				s.next_cover_eval = 9.0
				s.last_shot_t = 0.0
				s.goal = Vector3(0, 0, 1.0)
				s.goal_kind = "task"
				s.move_mode = trial % 3
				s.path = PackedVector3Array([s.goal]) if trial % 2 else PackedVector3Array()
				s.path_i = 0
				s._path_pending = trial % 3 == 0
				s._last_dir = Vector3(0.3, 0, -0.7).normalized()
				s.udef = {"build": 0.5 + float(trial % 11) * 0.3}
				s.suppression = [0.0, 55.0, 55.01, 100.0][(trial / 4) % 4]
				s.say_cd = 0.0
				s.squad = WorkSquad.new()
				s.squad.world = w
				s.squad.members = [s]
				var mount: Structure = w.entity(10)
				mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4]
				mount.position += s.position - mount.mount_pos()
				s.mounted = mount if trial % 7 == 0 else null
				cas.position = Vector3.ZERO
				cas.rotation.y = 0
				cas.life = Soldier.Life.SURRENDER if kind == "captor" else Soldier.Life.DOWNED
				if trial % 29 == 0:
					cas.life = Soldier.Life.HIDDEN
				elif trial % 5 == 0 and kind == "stretcher":
					cas.life = Soldier.Life.DEAD
				cas.gone = trial % 17 == 0
				cas.dragged_by = partner if trial % 19 == 0 else null
				cas.carried_by = [s, partner] if trial % 2 else []
				cas.stretcher_claimed = true
				cas.captor = partner if trial % 23 == 0 else s
				partner.position = Vector3(0.5, 0.2, 1.5)
				partner.rotation.y = trial * -0.23
				partner.life = Soldier.Life.DEAD if trial % 13 == 0 else Soldier.Life.ALIVE
				partner.gone = trial % 31 == 0
				partner.task = "stretcher" if trial % 7 else ""
				partner.task_ent = cas
				partner.task_ent2 = s
				partner.task_phase = (trial / 4) % 4
				partner.task_t = 0.0
				partner.posture = Soldier.Post.STAND
				partner.backwards = false
				partner.home = s.home
				partner.goal = Vector3.ZERO
				partner.goal_kind = ""
				partner.path = PackedVector3Array()
				partner.path_i = 0
				partner._path_pending = false
				enemy.position = s.position + Vector3([1.0, 17.9, 18.0, 20.0][(trial / 5) % 4], 0, 0)
				enemy.life = Soldier.Life.ALIVE
				enemy.gone = false
				s.target = enemy if trial % 3 else null
				for id in [11, 12]:
					var st: Entity = w.entity(id)
					st.needed = trial % 11 != 0
					st.gone = trial % 37 == 0
					st.position = Vector3(-1, 0, -2)
					st.hp = 99.9
					st.max_hp = 100.0
					if st is Structure:
						st.progress = 0.8
				s.home.gone = trial % 41 == 0
			for tick in 10:
				var dt: float = [0.0, 1.0 / 30.0, 0.2][trial % 3]
				for w: MedicalScene in worlds:
					w.step = tick
					w.time = 10.0 + tick * dt
					w.entity(1).call("_" + kind + "_tick", dt)
				var label := "%s trial=%d tick=%d" % [kind, trial, tick]
				for id in [1, 3, 4]:
					var a: Soldier = worlds[0].entity(id)
					var b: Soldier = worlds[1].entity(id)
					for key in ["position", "rotation", "life", "task", "task_phase", "task_t", "task_pos", "posture", "act", "backwards", "at_cover", "next_cover_eval", "goal", "goal_kind", "move_mode", "path", "path_i", "_path_pending", "last_shot_t", "build_snd_t", "stretcher_claimed", "say_cd"]:
						same(a.get(key), b.get(key), label + ":" + str(id) + ":" + key)
					assert(eid(a.task_ent) == eid(b.task_ent) and eid(a.task_ent2) == eid(b.task_ent2), label + ":links")
					assert(a.carried_by.map(eid) == b.carried_by.map(eid), label + ":carriers")
				for id in [11, 12]:
					same(worlds[0].entity(id).hp, worlds[1].entity(id).hp, label + ":work hp")
					assert(worlds[0].entity(id).needed == worlds[1].entity(id).needed, label + ":work completion")
				same(worlds[0].entity(11).progress, worlds[1].entity(11).progress, label + ":construction")
				assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
				same(worlds[0].effects, worlds[1].effects, label + ":effects")
				assert(worlds[0].spoken == worlds[1].spoken and worlds[0].stats == worlds[1].stats, label + ":speech/stats")
				for event: Array in worlds[1].effects:
					outcomes[event[0]] = true
				var native: Soldier = worlds[1].entity(1)
				if native._duties:
					var saved: PackedByteArray = native._duties.checkpoint()
					assert(native._duties.restore(saved) and native._duties.checkpoint() == saved)
				checks += 1
	for key in ["work", "repair", "built", "prisoner", "tent", "go", "move", "hold", "weapon"]:
		assert(outcomes.has(key), "Uncovered duty effect " + key)
	var native: World = worlds[1]
	var s: Soldier = native.entity(1)
	for kind in ["build", "captor", "stretcher", "home", "partner", "target"]:
		var removed: Entity = Work.new() if kind in ["build", "home"] else Dutyman.new()
		register(native, removed, 50)
		s.task = kind if kind in ["build", "captor", "stretcher"] else ("build" if kind == "target" else "stretcher")
		s.task_phase = 3 if kind == "partner" else 0
		s.task_ent = native.entity(3)
		s.task_ent2 = native.entity(4)
		s.home = native.entity(13)
		s.home.gone = false
		s.target = null
		var cas: Soldier = native.entity(3)
		cas.life = Soldier.Life.DOWNED
		cas.gone = false
		cas.dragged_by = null
		cas.carried_by = []
		if kind in ["build", "captor", "stretcher"]:
			s.task_ent = removed
		elif kind == "home":
			s.home = removed
		elif kind == "partner":
			s.task_ent2 = removed
		else:
			s.task_ent = native.entity(11)
			s.task_ent.gone = false
			s.task_ent.needed = true
			s.task_ent.progress = 0.0
			s.task_pos = s.position
			s.suppression = 0.0
			s.path = PackedVector3Array()
			s.path_i = 0
			s._path_pending = false
			s.target = removed
		native.entities.erase(50)
		removed.free()
		var task_name: String = s.task
		s.call("_" + task_name + "_tick", 1.0 / 30.0)
		if kind == "partner":
			assert(s.task == "stretcher" and s.task_phase == 2 and cas.carried_by == [s], "Removed bearer takeover")
		elif kind == "target":
			assert(s.task == "build" and s.act == Soldier.Act.BUILD, "Removed construction threat")
		else:
			assert(s.task == "", "Removed duty object " + kind)
	print("INFANTRY_DUTIES_FREED passed cases=6")
	print("INFANTRY_DUTIES passed steps=", checks)
	for w: World in worlds:
		w.free()
	get_tree().quit()
