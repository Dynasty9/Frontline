extends "res://tests/fixtures/infantry-duties.gd"

class IdleScene extends MedicalScene:
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text, rng.state, e.idle_act, e.idle_next, e._banter.size(), e._laugh_until])
		rng.randi()

class OriginalIdleman extends Dutyman:
	func _idle_tick(dt: float, moving: bool) -> void:
		var calm := not moving and not _danger() and _sector == Vector3.ZERO and reload_t <= 0.0 and world.time - last_shot_t > 12.0 and mounted == null and not _target_valid(target)
		if not calm:
			calm_t = 0.0
			if idle_act != 0:
				_end_idle()
			return
		calm_t += dt
		if idle_act != 0:
			var partner_gone: bool = idle_act == Act.IDLE_CHAT and (chat_with == null or not is_instance_valid(chat_with) or chat_with.gone or chat_with.chat_with != self or chat_with.life != Life.ALIVE)
			if world.time > idle_until or partner_gone:
				_end_idle()
				return
			act = idle_act
			posture = Post.STAND
			if idle_act == Act.IDLE_CHAT and chat_with != null:
				var to: Vector3 = Defs.flat(chat_with.position - position)
				if to.length() > 0.3:
					_face(to.normalized(), dt, 4.0)
				_banter_tick()
			return
		if calm_t < 12.0 or world.time < idle_next:
			return
		_start_idle()


	func _start_idle() -> void:
		idle_next = world.time + world.rng.randf_range(6.0, 16.0)
		var ti := 1 if team == 1 else 0
		if world.rng.randf() < 0.35 and world.time - float(world.last_chat[ti]) > 8.0:
			var mate := _chat_mate()
			if mate:
				_start_chat(mate)
				return
		var picks := [Act.IDLE_SMOKE, Act.IDLE_SIT, Act.IDLE_STRETCH, Act.IDLE_CHECK, Act.IDLE_LOOK, Act.IDLE_LOOK]
		idle_act = picks[world.rng.randi() % picks.size()]
		var dur := {Act.IDLE_SMOKE: 16.0, Act.IDLE_SIT: 24.0, Act.IDLE_STRETCH: 3.2, Act.IDLE_CHECK: 5.0, Act.IDLE_LOOK: 6.0}
		idle_until = world.time + float(dur[idle_act]) * world.rng.randf_range(0.8, 1.3)
		if world.rng.randf() < 0.22:
			say(_pick(BORED[1 if team == 1 else 0]))


	func _chat_mate() -> Soldier:
		for o in world.soldiers_near(position, 6.0):
			if o == self or o.team != team or o.life != Life.ALIVE or o.chat_with != null or o.calm_t < 5.0 or o.task != "" or o.is_moving():
				continue
			return o
		return null


	func _start_chat(mate: Soldier) -> void:
		var lines: Array = BANTER[1 if team == 1 else 0]
		var ex: Array = lines[world.rng.randi() % lines.size()]
		var dur := 3.5 + ex.size() * 2.8
		for s in [self, mate]:
			s.chat_with = mate if s == self else self
			s.idle_act = Act.IDLE_CHAT
			s.idle_until = world.time + dur
			s.idle_next = world.time + dur + world.rng.randf_range(25.0, 60.0)
			s._banter.clear()
		for i in ex.size():
			var who: Soldier = self if i % 2 == 0 else mate
			var other: Soldier = mate if i % 2 == 0 else self
			var txt: String = ex[i]
			if txt.contains("%s"):
				txt = txt % other.sname
			who._banter.append([world.time + 0.3 + i * 2.8, txt])
		# the one who didn't get the last word laughs it off
		var listener: Soldier = mate if ex.size() % 2 == 1 else self
		listener._banter.append([world.time + ex.size() * 2.8 - 0.6, "!laugh"])
		world.stat("banter")
		world.last_chat[1 if team == 1 else 0] = world.time


	func _banter_tick() -> void:
		while not _banter.is_empty() and world.time >= float(_banter[0][0]):
			var e: Array = _banter.pop_front()
			if String(e[1]) == "!laugh":
				_laugh_until = world.time + 1.8
				if world.rng.randf() < 0.6:
					say(_pick(LAUGHS), true)
			else:
				say(String(e[1]), true)
		if world.time < _laugh_until:
			act = Act.IDLE_LAUGH


	func _end_idle() -> void:
		idle_act = 0
		_banter.clear()
		_laugh_until = 0.0
		if chat_with != null and is_instance_valid(chat_with) and chat_with.chat_with == self:
			chat_with.chat_with = null
		chat_with = null
		idle_next = world.time + world.rng.randf_range(5.0, 12.0)

func idle_world(native: bool) -> IdleScene:
	var w := IdleScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	add_child(w)
	for id in range(1, 7):
		register(w, Dutyman.new() if native else OriginalIdleman.new(), id)
	return w

func compare_idle(worlds: Array, label: String) -> void:
	for id in range(1, 7):
		var a: Soldier = worlds[0].entity(id)
		var b: Soldier = worlds[1].entity(id)
		for key in ["calm_t", "idle_act", "idle_until", "idle_next", "_banter", "_laugh_until", "act", "posture", "rotation", "say_cd"]:
			same(a.get(key), b.get(key), "%s soldier=%d:%s" % [label, id, key])
		assert(eid(a.chat_with) == eid(b.chat_with), label + ":partner")
		if b._idle_core:
			var saved: PackedByteArray = b._idle_core.checkpoint()
			assert(b._idle_core.restore(saved) and b._idle_core.checkpoint() == saved)
	assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
	same(worlds[0].spoken, worlds[1].spoken, label + ":speech")
	same(worlds[0].last_chat, worlds[1].last_chat, label + ":conversation cooldown")
	assert(worlds[0].stats == worlds[1].stats, label + ":stats")

func _ready() -> void:
	assert(ClassDB.class_exists("InfantryIdleCore"))
	var worlds := [idle_world(false), idle_world(true)]
	var checks := 0
	var kinds := {}
	for trial in 512:
		var dt: float = [1.0 / 30.0, 0.1, 1.0, 2.0][trial % 4]
		for w: IdleScene in worlds:
			w.trial = trial
			w.rng.seed = trial + 5921
			w.effects.clear()
			w.spoken.clear()
			w.stats.clear()
			w.time = 100.0
			w.last_chat = [96.0, 96.0] if trial % 11 == 0 else [-99.0, -99.0]
			for id in range(1, 7):
				var s: Soldier = w.entity(id)
				s.position = Vector3(float(id) * 0.7, 0, float(id % 2))
				s.rotation.y = trial * 0.071
				s.sname = "Alex" if id == 1 else ("Mikhail" if id == 3 else "Mate%d" % id)
				s.team = trial % 2
				s.life = Soldier.Life.ALIVE
				s.task = "" if id < 4 else "heal"
				s.calm_t = [0.0, 5.0, 11.99, 12.0, 30.0][(trial + id) % 5]
				s.idle_act = 0
				s.idle_until = 0.0
				s.idle_next = 0.0
				s._banter.clear()
				s._laugh_until = 0.0
				s.chat_with = null
				s.posture = trial % 5
				s.act = Soldier.Act.IDLE
				s.target = null
				s.suppression = 0.0
				s.reload_t = 0.0
				s.last_shot_t = 0.0
				s._sector = Vector3.ZERO
				s.mounted = null
				s.say_cd = 0.0 if trial % 3 else 1000.0
				s.path = PackedVector3Array()
				s.path_i = 0
				s._path_pending = false
			var s: Soldier = w.entity(1)
			if trial % 4 == 0:
				s._start_chat(w.entity(3))
			elif trial % 4 == 1:
				s._start_idle()
		compare_idle(worlds, "initial trial=%d" % trial)
		for tick in 32:
			for w: IdleScene in worlds:
				w.time += dt
				for id in [1, 3]:
					var s: Soldier = w.entity(id)
					s.suppression = 10.0 if trial % 7 == 0 and tick >= 8 else 0.0
					s.reload_t = 1.0 if trial % 13 == 0 and tick >= 9 else 0.0
					s._sector = Vector3.FORWARD if trial % 17 == 0 and tick >= 10 else Vector3.ZERO
					s._idle_tick(dt, trial % 19 == 0 and tick >= 11)
					kinds[s.idle_act] = true
			compare_idle(worlds, "trial=%d tick=%d" % [trial, tick])
			checks += 2
	for code in [0, Soldier.Act.IDLE_CHAT, Soldier.Act.IDLE_SMOKE, Soldier.Act.IDLE_SIT, Soldier.Act.IDLE_STRETCH, Soldier.Act.IDLE_CHECK, Soldier.Act.IDLE_LOOK]:
		assert(kinds.has(code), "Missing idle activity %d" % code)
	var w: IdleScene = worlds[1]
	var s: Soldier = w.entity(1)
	var removed := Dutyman.new()
	register(w, removed, 50)
	s.chat_with = removed
	s.idle_act = Soldier.Act.IDLE_CHAT
	s.idle_until = w.time + 5.0
	s.target = null
	s.suppression = 0.0
	s.reload_t = 0.0
	s._sector = Vector3.ZERO
	w.entities.erase(50)
	removed.free()
	s._idle_tick(0.1, false)
	assert(s.chat_with == null and s.idle_act == 0)
	var target_removed := ShotDrone.new()
	register(w, target_removed, 51)
	s.target = target_removed
	w.entities.erase(51)
	target_removed.free()
	s._idle_tick(0.1, false)
	assert(not s._target_valid(s.target))
	print("INFANTRY_IDLE_FREED passed cases=2")
	var core: RefCounted = ClassDB.instantiate("InfantryIdleCore")
	var saved: PackedByteArray = core.checkpoint()
	var rng_before: int = w.rng.state
	assert(core.begin([], 0.0, 0.0, w.rng._backend).is_empty())
	assert(core.solo(s._idle_values(), NAN, 0, w.rng._backend).is_empty())
	assert(core.chat(s._idle_values(), s._idle_values(), PackedInt64Array([1, 1]), w.time, 0, PackedStringArray(["a", "b"]), w.rng._backend).is_empty())
	assert(not core.restore(saved.slice(0, saved.size() - 1)))
	assert(saved == core.checkpoint() and w.rng.state == rng_before)
	print("INFANTRY_IDLE_BOUNDARY passed")
	print("INFANTRY_IDLE passed steps=", checks)
	for world: World in worlds:
		world.free()
	get_tree().quit()
