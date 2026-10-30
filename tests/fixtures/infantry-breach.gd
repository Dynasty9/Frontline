extends "res://tests/fixtures/infantry-grenades.gd"

class EntryScene extends GrenadeScene:
	func structures_near(p: Vector3, r: float, _floors := false) -> Array:
		var result := []
		for e: Entity in entities.values():
			if e is Structure and Defs.flat(e.position - p).length() <= r:
				result.append(e)
		return result

class Breacher extends Grenadier:
	func _danger() -> bool: return false
	func go_to(p: Vector3, kind: String, mode: int) -> void:
		goal = p
		goal_kind = kind
		move_mode = mode
		path = PackedVector3Array([p])
		path_i = 0
		world.effects.append(["go", eid, p, kind, mode, world.rng.state])
	func _move_tick(dt: float, speed: float) -> bool:
		world.effects.append(["move", eid, dt, speed, world.rng.state])
		world.rng.randi()
		if not is_moving() or world.trial % 11 == 0:
			return false
		var delta := goal - position
		position += delta.limit_length(3.0 * dt)
		if delta.length() < 3.0 * dt:
			stop_moving()
		return is_moving()
	func _weapon_tick(dt: float, moving: bool, kind := "normal") -> void:
		world.effects.append(["weapon", eid, dt, moving, kind, world.rng.state])
		world.rng.randi()
		if world.trial % 7 == 0 and world.time > 2.0:
			world.entity(7).life = Life.DEAD

class EntryWall extends ShotWall:
	func open_door(by: Entity, kicked: bool) -> void:
		world.effects.append(["door", by.eid, kicked, world.rng.state])
		world.rng.randi()
		door_shut = false

class EntryCombat extends Combat:
	func throw_grenade_low(s: Soldier, p: Vector3, fuse := 3.4) -> Projectile:
		world.effects.append(["throw", s.eid, p, fuse, world.rng.state])
		world.rng.randi()
		var g: Projectile = world.entity(20)
		g.gone = false
		g.fuse = fuse
		return g


func entry_world(native: bool) -> EntryScene:
	var w := EntryScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = EntryCombat.new(w)
	w.nav = Nav.new()
	w.nav.finalize()
	add_child(w)
	w.combat.enable_native_collision()
	for id in [1, 3, 7]:
		register(w, Breacher.new(), id)
	for id in [10, 11]:
		register(w, EntryWall.new(), id)
	register(w, Round.new(), 20)
	return w


func compare_entry(a: Soldier, b: Soldier, label: String) -> void:
	for id in [1, 3]:
		var x: Soldier = a.world.entity(id)
		var y: Soldier = b.world.entity(id)
		for key in ["position", "rotation", "task", "task_phase", "task_t", "task_pos", "task_pos2", "bt_wait", "bt_cook_t0", "bt_nofrag", "hold_pos", "hold_face", "leash", "at_cover", "posture", "act", "act_kind", "act_t", "frags", "path", "goal_kind", "move_mode", "next_cover_eval"]:
			assert(x.get(key) == y.get(key), "%s id=%d %s ref=%s rust=%s" % [label, id, key, x.get(key), y.get(key)])
		for key in ["pos", "fuse", "kind"]:
			assert(x.act_data.get(key) == y.act_data.get(key), label + " action " + key)
		assert(eid(x.task_ent) == eid(y.task_ent) and eid(x.task_ent2) == eid(y.task_ent2))
	assert(a.world.rng.state == b.world.rng.state, label + " random draws")
	assert(a.world.effects == b.world.effects, label + " callback order")
	assert(a.world.stats == b.world.stats and a.world.spoken == b.world.spoken, label + " effects")
	assert(eid(a.squad.breach_by) == eid(b.squad.breach_by), label + " claim")
	assert(a.squad.clear_call.size() == b.squad.clear_call.size(), label + " clear signal")
	if not a.squad.clear_call.is_empty():
		assert(eid(a.squad.clear_call[0]) == eid(b.squad.clear_call[0]) and a.squad.clear_call[1] == b.squad.clear_call[1])


func _ready() -> void:
	assert(ClassDB.class_exists("BreachCore"))
	Nav.N = 64
	Nav.H = 32.0
	var worlds := [entry_world(false), entry_world(true)]
	var outcomes := {}
	var checks := 0
	for trial in 256:
		for w in worlds:
			w.trial = trial
			w.time = 0.0
			w.rng.seed = trial + 209
			w.stats.clear()
			w.spoken.clear()
			w.effects.clear()
			var h: Structure = w.entity(10)
			h.skind = "floor"
			h.position = Vector3(0, 0, -3)
			h.size = Vector3(8, 0.2, 6)
			h.yaw = 0.0
			h.gone = false
			var wall: Structure = w.entity(11)
			wall.position = Vector3.ZERO
			wall.skind = "house_wall"
			wall.door_shut = trial % 3 == 0
			wall.gone = false
			var q := Squad.new()
			q.world = w
			for id in [1, 3, 7]:
				var s: Soldier = w.entity(id)
				s.squad = q if id != 7 else null
				s.team = 0 if id != 7 else 1
				s.life = Soldier.Life.ALIVE
				s.position = Vector3(-3 + trial % 5, 0, 4.0 + id) if id != 7 else Vector3(1, 0, -3)
				s.rotation.y = 0.0
				s.task = ""
				s.task_ent = null
				s.task_ent2 = null
				s.task_pos2 = Vector3.ZERO
				s.bt_wait = 0.0
				s.act_kind = ""
				s.act_t = 0.0
				s.act_data.clear()
				s.act = Soldier.Act.IDLE
				s.posture = Soldier.Post.STAND
				s.frags = 0 if trial % 5 == 0 else 2
				s.at_cover = id == 7
				s.cover_mat = trial % 4
				s.hold_pos = Vector3(20, 0, 20)
				s.hold_face = Vector3.ZERO
				s.leash = 9.0
				s.next_cover_eval = 0.0
				s.say_cd = 0.0
				s.path = PackedVector3Array()
				s.goal_kind = ""
				s.move_mode = 1
				if id != 7:
					q.members.append(s)
			q.known[7] = {"e": w.entity(7), "t": 0.0}
			var s: Soldier = w.entity(1)
			var opening := [wall, Vector3.ZERO, Vector3.FORWARD * -1, trial % 4 != 0]
			s.bt_breach = [h, opening, w.entity(7)]
			if trial % 2 == 0:
				SoldierBrain.start_clearing(s, h, opening, w.entity(3))
			else:
				SoldierBrain.breach(s)
			s.bt_reordered = trial % 13 == 0
			w.entity(20).gone = true
		for tick in 180:
			for w in worlds:
				var s: Soldier = w.entity(1)
				var dt: float = [0.1, 0.3, 0.5][trial % 3]
				w.time += dt
				var g: Projectile = w.entity(20)
				g.fuse -= dt
				if g.fuse <= 0.0:
					g.gone = true
				if trial % 17 == 0 and tick == 10:
					w.entity(11).gone = true
				if s.act_t > 0.0:
					s.act_t -= dt
					s._action_tick(dt)
					if s.act_t <= 0.0:
						s._action_done()
				elif s.task == "breach":
					SoldierBrain.breach_tick(s, dt)
				outcomes[s.act_kind] = true
				for key in w.stats:
					outcomes[key] = true
			compare_entry(worlds[0].entity(1), worlds[1].entity(1), "trial=%d tick=%d" % [trial, tick])
			var core: RefCounted = worlds[1].entity(1)._breach_core
			if core:
				var bytes: PackedByteArray = core.checkpoint()
				assert(core.restore(bytes))
			checks += 1
	for key in ["cook", "door_kick", "throw_in", "breach_frag_in", "room_entry"]:
		assert(outcomes.has(key), "Missing breach outcome " + key)
	for w in worlds:
		w.free()
	print("INFANTRY_BREACH passed steps=%d" % checks)
	get_tree().quit()
