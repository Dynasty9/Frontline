extends "res://tests/fixtures/infantry-duties.gd"

class ActionScene extends MedicalScene:
	func record(kind: String, s: Soldier, extra: Array = []) -> void:
		effects.append([kind, s.eid, s.act_kind, s.act_t, s.act, s.posture, rng.state, extra])

class Actionman extends Dutyman:
	pass

class ActionCombat extends Combat:
	func throw_grenade(s: Soldier, pos: Vector3, kind: String, fuse := 3.4) -> Projectile:
		world.record("throw", s, [pos, kind, fuse])
		world.rng.randi()
		return world.entity(20)
	func throw_grenade_low(s: Soldier, pos: Vector3, fuse := 3.4) -> Projectile:
		world.record("throw_in", s, [pos, fuse])
		world.rng.randi()
		return world.entity(20)
	func fire_rocket(s: Soldier, target: Entity) -> void:
		world.record("rocket", s, [target.eid])
		world.rng.randi()
	func fire_mortar(s: Soldier, from: Vector3, target: Vector3, kind: String) -> void:
		world.record("mortar", s, [from, target, kind])
		world.rng.randi()
	func melee_hit(s: Soldier, target) -> void:
		world.record("melee", s, [target.eid if is_instance_valid(target) else 0])
		world.rng.randi()
	func launch_drone(s: Soldier, target: Entity) -> Drone:
		world.record("drone", s, [target.eid])
		world.rng.randi()
		return world.entity(30) if world.trial % 2 else null

class ActionRound extends Round:
	func kick(s: Soldier, velocity: Vector3) -> void:
		world.record("kick", s, [eid, velocity])
		world.rng.randi()
		s.hit_dirt_t = 2.7 if world.trial % 2 else 0.1
	func release_throw(s: Soldier, pos: Vector3) -> void:
		world.record("rethrow", s, [eid, pos])
		world.rng.randi()
		held_by = null

class ActionDoor extends ShotWall:
	func open_door(s: Entity, kicked: bool) -> void:
		world.record("door", s, [eid, kicked])
		world.rng.randi()
		door_shut = false

class ActionSquad extends Squad:
	func last_known_near(p: Vector3, r: float, age: float) -> Dictionary:
		world.record("known", world.entity(1), [p, r, age])
		world.rng.randi()
		return {} if world.trial % 3 == 0 else {"pos": Vector3(3, 0, -20)}

class OriginalActionman extends Actionman:
	func _begin_action(kind: String, dur: float, data: Dictionary) -> void:
		act_kind = kind
		act_t = dur
		act_data = data
		stop_moving()
		match kind:
			"throw", "rethrow", "throw_in":
				act = Act.THROW
			"kick", "door_kick":
				act = Act.KICK
			"cook":
				act = Act.COOK
			"melee":
				act = Act.MELEE
			"pickup":
				act = Act.PICKUP
			"launch", "launch_drone", "mortar":
				act = Act.LAUNCH
		if data.has("pos"):
			_face_now(Defs.flat(data.pos - position))
		elif data.has("target") and data.target is Entity:
			_face_now(Defs.flat(data.target.position - position))


	func _action_tick(_dt: float) -> void:
		if act_kind == "mortar":
			posture = Post.CROUCH
			return
		if act_kind == "cook":
			return  # holding it in whatever stance he's in
		if act_kind == "kick" or act_kind == "door_kick":
			posture = Post.STAND
			return
		if act_kind == "launch" or act_kind == "throw" or act_kind == "rethrow" or act_kind == "throw_in":
			posture = Post.STAND if act_kind != "launch" else Post.CROUCH
			if act_data.has("target") and act_data.target is Entity and not act_data.target.gone:
				_face_now(Defs.flat(act_data.target.position - position))


	func _action_done() -> void:
		var k := act_kind
		act_kind = ""
		act = Act.IDLE
		if k == "cook" and not _queued_throw.is_empty():
			var qt := _queued_throw
			_queued_throw = {}
			_begin_action("throw", 0.6, qt)
			say(_pick(["Frag out!", "Grenade out!", "Fire in the hole!"]), true)
			return
		match k:
			"throw":
				world.combat.throw_grenade(self, act_data.pos, String(act_data.kind), float(act_data.get("fuse", 3.4)))
			"throw_in":
				bt_breach_g = world.combat.throw_grenade_low(self, act_data.pos, float(act_data.get("fuse", 3.4)))
			"kick":
				var kg: Projectile = act_data.get("g")
				if kg and not kg.gone and kg.held_by == null and Defs.flat(kg.position - position).length() < 1.4:
					kg.kick(self, act_data.v)
					world.stat("kicked")
				hit_dirt_t = maxf(hit_dirt_t, 1.6)  # and down
			"pickup":
				var g: Projectile = act_data.get("g")
				if g and not g.gone and g.held_by == self:
					var tp := _rethrow_target(g)
					_begin_action("rethrow", 0.3, {"g": g, "pos": tp})
			"rethrow":
				var g: Projectile = act_data.get("g")
				if g and not g.gone and g.held_by == self:
					g.release_throw(self, act_data.pos)
					world.stat("throwback")
					say("Throwing it back!", true)
			"door_kick":
				var dr: Structure = act_data.get("door")
				if dr and not dr.gone:
					dr.open_door(self, true)
			"melee":
				world.combat.melee_hit(self, act_data.get("target"))
			"launch":
				var t: Entity = act_data.get("target")
				if t and not t.gone:
					world.combat.fire_rocket(self, t)
			"mortar":
				world.combat.fire_mortar(self, position + Vector3(0, 1.0, 0), act_data.pos, String(act_data.kind))
			"launch_drone":
				var t2: Entity = act_data.get("target")
				if t2 and not t2.gone:
					drone_ctrl = world.combat.launch_drone(self, t2)
					if drone_ctrl:
						task = "pilot"


	func _rethrow_target(g: Projectile) -> Vector3:
		var src: Entity = world.entity(g.thrower_id)
		if src and not src.gone and src.team != team:
			return src.position
		if squad:
			var lk: Dictionary = squad.last_known_near(position, 30.0, 10.0)
			if not lk.is_empty():
				return lk.pos
		return position + Defs.dir_of(rotation.y) * 18.0

func action_world(native: bool) -> ActionScene:
	var w := ActionScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = ActionCombat.new(w)
	add_child(w)
	register(w, Actionman.new() if native else OriginalActionman.new(), 1)
	register(w, ShotSoldier.new(), 3)
	register(w, ShotSoldier.new(), 5)
	register(w, ActionDoor.new(), 10)
	register(w, ActionRound.new(), 20)
	register(w, ShotDrone.new(), 30)
	return w

func action_data(w: World, kind: String) -> Dictionary:
	match kind:
		"throw", "throw_in": return {"pos": Vector3(-7, 0, -10), "kind": "smoke" if w.trial % 2 else "frag", "fuse": 0.3}
		"rethrow": return {"g": w.entity(20), "pos": Vector3(-3, 0, -12)}
		"kick": return {"g": w.entity(20), "v": Vector3(7, 2, -1)}
		"pickup": return {"g": w.entity(20)}
		"door_kick": return {"door": w.entity(10), "pos": Vector3(1, 0, -3)}
		"melee", "launch", "launch_drone": return {"target": w.entity(5)}
		"mortar": return {"pos": Vector3(3, 0, -60), "kind": "smoke" if w.trial % 2 else "he"}
	return {}

func plain_data(data: Dictionary) -> Array:
	return [data.get("pos", Vector3.ZERO), data.get("kind", ""), data.get("fuse", 3.4), data.get("v", Vector3.ZERO),
		eid(data.get("target")), eid(data.get("g")), eid(data.get("door"))]

func _ready() -> void:
	assert(ClassDB.class_exists("InfantryActionCore"))
	var worlds := [action_world(false), action_world(true)]
	var checks := 0
	var outcomes := {}
	for trial in 256:
		for kind in ["", "throw", "rethrow", "throw_in", "kick", "door_kick", "cook", "melee", "pickup", "launch", "launch_drone", "mortar"]:
			for w: ActionScene in worlds:
				w.trial = trial
				w.rng.seed = trial + 3827
				w.effects.clear()
				w.spoken.clear()
				w.stats.clear()
				var s: Soldier = w.entity(1)
				s.position = Vector3(0, 0, 0)
				s.rotation.y = trial * 0.37
				s.posture = trial % 5
				s.act = Soldier.Act.IDLE
				s.act_kind = ""
				s.act_t = 0.0
				s.task = ""
				s.team = trial % 2
				s.say_cd = 0.0
				s.hit_dirt_t = 2.0 if trial % 2 else 0.0
				s.drone_ctrl = null
				s.bt_breach_g = null
				s.path = PackedVector3Array([Vector3(1, 0, 2)])
				s.path_i = 0
				s._path_pending = true
				s.goal_kind = "move"
				s._queued_throw = {"pos": Vector3(0, 0, -16), "kind": "frag", "fuse": 0.4} if trial % 2 else {}
				s.squad = ActionSquad.new()
				s.squad.world = w
				var target: Soldier = w.entity(5)
				target.position = Vector3([0.0, 0.001, 3.0][trial % 3], 1.0, -2.5)
				target.team = s.team if trial % 3 else 1 - s.team
				target.gone = trial % 13 == 0
				var g: Projectile = w.entity(20)
				g.position = Vector3([1.0, 1.39, 1.4, 1.41][trial % 4], 1.0, 0)
				g.gone = trial % 17 == 0
				g.held_by = [null, s, w.entity(3)][trial % 3]
				g.thrower_id = 5 if trial % 2 else 0
				w.entity(10).gone = trial % 19 == 0
				w.entity(10).door_shut = true
				s._begin_action(kind, [0.01, 0.2, 0.8][trial % 3], action_data(w, kind))
			for tick in 8:
				var dt: float = [0.0, 1.0 / 30.0, 0.2, 0.4][trial % 4]
				for w: ActionScene in worlds:
					w.step = tick
					w.time = 10.0 + tick * dt
					var s: Soldier = w.entity(1)
					w.entity(5).position.x += 0.01
					if s.act_t > 0.0:
						s.act_t -= dt
						s._action_tick(dt)
						if s.act_t <= 0.0:
							s._action_done()
				var label := "%s trial=%d tick=%d" % [kind, trial, tick]
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				for key in ["position", "rotation", "task", "act_kind", "act_t", "posture", "act", "hit_dirt_t", "say_cd", "path", "path_i", "_path_pending", "goal_kind", "_queued_throw"]:
					same(a.get(key), b.get(key), label + ":" + key)
				same(plain_data(a.act_data), plain_data(b.act_data), label + ":data")
				assert(eid(a.drone_ctrl) == eid(b.drone_ctrl) and eid(a.bt_breach_g) == eid(b.bt_breach_g), label + ":created")
				assert(eid(worlds[0].entity(20).held_by) == eid(worlds[1].entity(20).held_by), label + ":holder")
				assert(worlds[0].entity(10).door_shut == worlds[1].entity(10).door_shut, label + ":door")
				assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
				same(worlds[0].effects, worlds[1].effects, label + ":effects")
				assert(worlds[0].spoken == worlds[1].spoken and worlds[0].stats == worlds[1].stats, label + ":speech/stats")
				for event: Array in worlds[1].effects:
					outcomes[event[0]] = true
				if b._action_core:
					var saved: PackedByteArray = b._action_core.checkpoint()
					assert(b._action_core.restore(saved) and b._action_core.checkpoint() == saved)
				checks += 1
	for key in ["throw", "throw_in", "kick", "rethrow", "door", "melee", "rocket", "mortar", "drone", "known", "stop"]:
		assert(outcomes.has(key), "Uncovered action effect " + key)
	var w: World = worlds[1]
	var s: Soldier = w.entity(1)
	for kind in ["launch", "launch_drone", "melee", "door_kick", "pickup", "rethrow", "kick"]:
		var removed: Entity = ActionRound.new() if kind in ["pickup", "rethrow", "kick"] else (ActionDoor.new() if kind == "door_kick" else ShotSoldier.new())
		register(w, removed, 50)
		var data := action_data(w, kind)
		data["g" if kind in ["pickup", "rethrow", "kick"] else ("door" if kind == "door_kick" else "target")] = removed
		s._begin_action(kind, 0.2, data)
		w.entities.erase(50)
		removed.free()
		s._action_tick(0.2)
		s._action_done()
		assert(s.act_kind == "", "Removed action target " + kind)
	var core := s._actions()
	var saved: PackedByteArray = core.checkpoint()
	var malformed := s._action_values()
	malformed[0] = -1
	assert(core.start_pose(malformed, s.eid, s.position, []).is_empty())
	malformed[0] = 0
	malformed[1] = NAN
	assert(core.pose(malformed, s.eid, s.position, []).is_empty())
	assert(core.finish([], s.eid, s.position, []).is_empty())
	assert(not core.restore(saved.slice(0, saved.size() - 1)))
	assert(core.checkpoint() == saved, "Invalid action input changes no state")
	print("INFANTRY_ACTION_BOUNDARY passed")
	print("INFANTRY_ACTION_FREED passed cases=7")
	print("INFANTRY_ACTION passed steps=", checks)
	for world: World in worlds:
		world.free()
	get_tree().quit()
