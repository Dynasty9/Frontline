extends "res://tests/fixtures/infantry-grenades.gd"

class MedicalScene extends GrenadeScene:
	var step := 0
	func record(kind: String, s: Soldier, extra: Array = []) -> void:
		effects.append([kind, s.eid, s.task_phase, s.task_t, s.backwards, s.posture, rng.state, extra])

class Medic extends ShotSoldier:
	func go_to(p: Vector3, kind: String, mode: int) -> void:
		world.record("go", self, [p, kind, mode])
		world.rng.randi()
		goal = p
		goal_kind = kind
		move_mode = mode
		path = PackedVector3Array([p]) if world.trial % 2 else PackedVector3Array()
		path_i = 0
		_path_pending = world.trial % 3 == 0
	func stop_moving() -> void:
		world.record("stop", self)
		world.rng.randi()
		path = PackedVector3Array()
		path_i = 0
		_path_pending = false
		goal_kind = ""
	func _move_tick(dt: float, speed: float) -> bool:
		world.record("move", self, [dt, speed])
		world.rng.randi()
		if is_moving():
			var delta := goal - position
			position += delta.limit_length(speed * dt)
			_last_dir = delta.normalized()
		var moving: bool = world.step % 3 != 2 and world.trial % 5 != 0
		if not moving:
			path = PackedVector3Array()
			path_i = 0
			_path_pending = false
		return moving
	func _choose_act(moving: bool) -> void:
		world.record("act", self, [moving])
		world.rng.randi()
		act = Act.WALK if moving else Act.IDLE
	func _weapon_tick(dt: float, moving: bool, kind: String) -> void:
		world.record("weapon", self, [dt, moving, kind])
		world.rng.randi()
		if world.trial % 2 == 0:
			last_shot_t = world.time
	func revive(_tent := false) -> void:
		world.record("revive", world.entity(1), [eid])
		world.rng.randi()
		life = Life.ALIVE
		hp = max_hp

class MedicalRules extends Rules:
	func has_upgrade(_team: int, _key: String) -> bool:
		world.record("upgrade", world.entity(1))
		world.rng.randi()
		return world.trial % 2 == 0

class OriginalMedic extends Medic:
	func _rescue_tick(dt: float) -> void:
		var w := task_ent as Soldier
		if w == null or w.gone or w.life != Life.DOWNED or (w.dragged_by != null and w.dragged_by != self) or not w.carried_by.is_empty():
			_end_rescue()
			return
		match task_phase:
			0:
				posture = Post.STAND
				if Defs.flat(w.position - position).length() < 1.2:
					task_phase = 1
					w.dragged_by = self
					task_pos = _safe_spot(w)
					world.stat("drag")
					go_to(task_pos, "task", 0)
					if path.is_empty():
						task_phase = 2
						task_t = heal_time()
					say(_pick(["I've got you!", "Hang on, I've got you!", "Grab on!", "Moving him!"]), true)
					return
				if not is_moving() or w.position.distance_to(goal) > 1.5:
					go_to(w.position, "task", 2)
				_move_tick(dt, 4.8)
				act = Act.RUN
			1:
				backwards = true
				posture = Post.STAND
				var moved := _move_tick(dt, 1.15)
				var f := -_last_dir
				_face(f, dt, 12.0)
				w.position = position + Defs.dir_of(rotation.y) * 1.05
				w.position.y = 0.0
				w.rotation.y = rotation.y
				act = Act.DRAG
				if not moved:
					task_phase = 2
					task_t = heal_time()
					backwards = false
			2:
				act = Act.HEAL
				posture = Post.CROUCH
				w.dragged_by = null
				_face(Defs.flat(w.position - position), dt, 8.0)
				task_t -= dt
				if task_t <= 0.0:
					w.revive()
					world.stat("patched_up")
					_end_rescue()


	func _heal_tick(dt: float) -> void:
		var w := task_ent as Soldier
		if w == null or w.gone or w.life != Life.ALIVE or w.hp >= w.max_hp:
			task = ""
			return
		if task_phase == 0:
			if Defs.flat(w.position - position).length() < 1.4:
				task_phase = 1
				task_t = heal_time() * 0.6
				stop_moving()
			else:
				if not is_moving():
					go_to(w.position, "task", 0)
				_move_tick(dt, _speed())
				_choose_act(true)
			return
		act = Act.HEAL
		posture = Post.CROUCH
		_face(Defs.flat(w.position - position), dt, 8.0)
		task_t -= dt
		if task_t <= 0.0:
			w.hp = w.max_hp
			task = ""


	func _escort_tick(dt: float) -> void:
		var r := task_ent2 as Soldier
		var w := task_ent as Soldier
		if r == null or r.gone or r.life != Life.ALIVE or r.task != "rescue" or r.task_phase == 2 or w == null or w.gone:
			task = ""
			backwards = false
			at_cover = false
			next_cover_eval = 0.0
			return
		var thr := _threat_dir(_threats())
		var side := thr.cross(Vector3.UP).normalized()
		if side.dot(Defs.flat(position - r.position)) < 0.0:
			side = -side
		var want := r.position + side * 1.6 + thr * 0.9
		var to := Defs.flat(want - position)
		var spd := 4.4 if to.length() > 3.0 else 1.3
		var np := position + to.normalized() * minf(to.length(), spd * dt)
		if to.length() > 0.2 and world.nav.walkable(np):
			position = np
		backwards = to.length() > 0.2 and to.normalized().dot(thr) < 0.0
		_face(thr, dt, 8.0)
		_weapon_tick(dt, false, "escort")
		if world.time - last_shot_t < 0.35:
			act = Act.SHOOT
		else:
			act = Act.WALK if to.length() > 0.2 else Act.IDLE




func medical_world(native: bool) -> MedicalScene:
	var w := MedicalScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.rules = MedicalRules.new(w)
	w.terrain = TerrainMap.new(w)
	w.fires = Fires.new(w)
	w.nav = Nav.new()
	w.nav.finalize()
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	register(w, Medic.new() if native else OriginalMedic.new(), 1)
	register(w, Medic.new(), 3)
	register(w, Medic.new(), 4)
	register(w, ShotWall.new(), 10)
	for i in w.nav.ikind.size():
		w.nav.ikind[i] = Nav.SOLID if i % 17 == 0 else Nav.FREE
		w.nav.inf.set_point_solid(Vector2i(i % Nav.N, i / Nav.N), w.nav.ikind[i] == Nav.SOLID)
	assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
	return w


func same(a, b, label: String) -> void:
	if a is Vector3:
		assert(a.distance_to(b) < 0.00001, "%s: %s vs %s" % [label, a, b])
	elif a is float:
		assert(absf(a - float(b)) < 0.0000001, "%s: %s vs %s" % [label, a, b])
	elif a is Array or a is PackedVector3Array:
		assert(a.size() == b.size(), "Array size " + label)
		for i in a.size():
			same(a[i], b[i], label + ":" + str(i))
	else:
		assert(a == b, "%s: %s vs %s" % [label, a, b])


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
	var worlds := [medical_world(false), medical_world(true)]
	var checks := 0
	var outcomes := {}
	for trial in 1024:
		for kind in ["rescue", "heal", "escort"]:
			for w: MedicalScene in worlds:
				w.trial = trial
				w.rng.seed = trial + 2971
				w.effects.clear()
				w.spoken.clear()
				w.stats.clear()
				var s: Soldier = w.entity(1)
				var patient: Soldier = w.entity(3)
				var rescuer: Soldier = w.entity(4)
				s.position = Vector3([0.0, 0.8, 1.2, 1.4, 3.0, 5.0][(trial / 2) % 6], 0.3 if trial % 7 == 0 else 0.0, 0)
				s.rotation.y = trial * 0.37
				s.task = kind
				s.task_ent = patient
				s.task_ent2 = rescuer
				s.task_phase = trial % 3 if kind == "rescue" else trial % 2
				s.task_t = float(trial % 9) * 0.03
				s.task_pos = Vector3.ZERO
				s.posture = trial % 5
				s.act = Soldier.Act.IDLE
				s.backwards = false
				s.at_cover = true
				s.next_cover_eval = 9.0
				s.last_shot_t = 0.0
				s.goal = Vector3(0, 2.0 if trial % 4 == 0 else 0.0, 0)
				s.goal_kind = "task"
				s.move_mode = trial % 3
				s.path = PackedVector3Array([s.goal]) if trial % 2 else PackedVector3Array()
				s.path_i = 0
				s._path_pending = trial % 3 == 0
				s._last_dir = Vector3(0.3, 0, -0.7).normalized()
				s.udef = {"heal": 0.5 + float(trial % 11) * 0.3}
				s.hold_pos = Vector3.ZERO
				s.hold_face = Vector3.FORWARD
				s.squad = null
				if trial % 4 == 0:
					s.squad = Squad.new()
					s.squad.world = w
					s.squad.members = [s]
					s.squad.order_pos = Vector3(0, 0, [10.0, -10.0, 22.0][(trial / 4) % 3])
				var mount: Structure = w.entity(10)
				mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4]
				mount.position += s.position - mount.mount_pos()
				s.mounted = mount if trial % 7 == 0 else null
				patient.position = Vector3.ZERO
				patient.rotation.y = 0
				patient.life = Soldier.Life.DEAD if trial % 11 == 0 else (Soldier.Life.ALIVE if kind == "heal" else Soldier.Life.DOWNED)
				patient.gone = trial % 17 == 0
				patient.hp = 100.0 if trial % 13 == 0 else 30.0
				patient.max_hp = 100.0
				patient.dragged_by = rescuer if trial % 19 == 0 else (s if trial % 3 == 0 else null)
				patient.rescue_claimed = s
				patient.carried_by = [rescuer] if trial % 23 == 0 else []
				rescuer.position = Vector3(0.5, 0, 1.5)
				rescuer.life = Soldier.Life.DEAD if trial % 29 == 0 else Soldier.Life.ALIVE
				rescuer.gone = trial % 31 == 0
				rescuer.task = "rescue" if trial % 7 else ""
				rescuer.task_phase = trial % 3
			for tick in 6:
				var dt: float = [0.0, 1.0 / 30.0, 0.2][trial % 3]
				for w: MedicalScene in worlds:
					w.step = tick
					w.time = 10.0 + tick * dt
					var s: Soldier = w.entity(1)
					s.call("_" + kind + "_tick", dt)
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				var label := "%s trial=%d tick=%d" % [kind, trial, tick]
				for key in ["position", "rotation", "task", "task_phase", "task_t", "task_pos", "posture", "act", "backwards", "at_cover", "next_cover_eval", "goal", "goal_kind", "move_mode", "path", "path_i", "_path_pending", "last_shot_t"]:
					same(a.get(key), b.get(key), label + ":" + key)
				for key in ["position", "rotation", "life", "hp"]:
					same(worlds[0].entity(3).get(key), worlds[1].entity(3).get(key), label + ":patient:" + key)
				for key in ["dragged_by", "rescue_claimed"]:
					same(eid(worlds[0].entity(3).get(key)), eid(worlds[1].entity(3).get(key)), label + ":patient:" + key)
				same(worlds[0].effects, worlds[1].effects, label + ":effects")
				same(worlds[0].spoken, worlds[1].spoken, label + ":speech")
				same(worlds[0].stats, worlds[1].stats, label + ":stats")
				assert(worlds[0].rng.state == worlds[1].rng.state, "Medical randomness " + label)
				for event: Array in worlds[1].effects:
					outcomes[event[0]] = true
				if b._medicine:
					var saved: PackedByteArray = b._medicine.checkpoint()
					assert(b._medicine.restore(saved) and b._medicine.checkpoint() == saved)
				checks += 1
	for event in ["go", "move", "stop", "revive", "upgrade", "weapon"]:
		assert(outcomes.has(event), "Missing medical effect: " + event)
	var native: World = worlds[1]
	var subject: Soldier = native.entity(1)
	for kind in ["rescue", "heal", "escort"]:
		var removed := Medic.new()
		register(native, removed, 50)
		subject.task = kind
		subject.task_ent = removed
		native.entities.erase(50)
		removed.free()
		subject.call("_" + kind + "_tick", 1.0 / 30.0)
		assert(subject.task == "", "Removed patient " + kind)
	var removed_rescuer := Medic.new()
	register(native, removed_rescuer, 50)
	subject.task = "escort"
	subject.task_ent = native.entity(3)
	subject.task_ent2 = removed_rescuer
	native.entities.erase(50)
	removed_rescuer.free()
	subject._escort_tick(1.0 / 30.0)
	assert(subject.task == "", "Removed escort leader")
	print("INFANTRY_MEDICINE_FREED passed tasks=4")
	print("INFANTRY_MEDICINE passed steps=", checks)
	for w: World in worlds:
		w.free()
	get_tree().quit()
