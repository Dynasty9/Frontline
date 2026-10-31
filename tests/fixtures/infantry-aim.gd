extends Node3D

class Scene extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Trooper extends Soldier:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Car extends Vehicle:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Wall extends Structure:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Aircraft extends Drone:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


func register(w: World, e: Entity, id: int) -> void:
	e.world = w
	e.eid = id
	e.srv = true
	w.entities[id] = e
	w.add_child(e)


func body(e: Entity, size: Vector3) -> void:
	e.body = StaticBody3D.new()
	e.body.collision_layer = Combat.MASK
	e.body.set_meta("eid", e.eid)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	e.body.add_child(shape)
	e.add_child(e.body)
	e.world.combat.dirty_collision(e.eid)


func make_world(native: bool) -> Scene:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = Combat.new(w)
	w.fires = Fires.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	assert(w.combat._collision != null and w.combat._visibility != null)
	register(w, Trooper.new(), 1)
	register(w, Trooper.new(), 2)
	register(w, Car.new(), 3)
	register(w, Aircraft.new(), 4)
	register(w, Wall.new(), 5)
	register(w, Wall.new(), 6)
	body(w.entity(3), Vector3(3, 3, 4))
	body(w.entity(5), Vector3(2, 5, 4))
	body(w.entity(6), Vector3(1, 5, 6))
	var s: Soldier = w.entity(1)
	s.squad = Squad.new()
	s.squad.world = w
	s.squad.members = [s]
	return w


func id(e: Entity) -> int:
	return e.eid if e else 0


func _ready() -> void:
	var worlds := [make_world(false), make_world(true)]
	var outcomes := {}
	var checks := 0
	for trial in 256:
		for w in worlds:
			w.rng.seed = trial + 1729
			w.stats.clear()
			var s: Soldier = w.entity(1)
			s.los_ent = null
			s.los_t = 0.0
			s.los_ok = false
			s.utype = "mg_gunner" if trial % 3 == 0 else "rifleman"
			s.gun_override = {"range": 50.0} if trial % 7 == 0 else {}
			s._path_pending = trial % 2 == 0
			s.path = PackedVector3Array([Vector3.ZERO]) if trial % 3 == 0 else PackedVector3Array()
			s.path_i = 0
			for entity_id in [3, 5]:
				w.entity(entity_id).position = Vector3(20, 0, -20 if entity_id == 3 else 20)
				w.combat.dirty_collision(entity_id)
		for tick in 80:
			var results := []
			for w in worlds:
				w.time = tick * 0.1
				var s: Soldier = w.entity(1)
				var target_soldier: Soldier = w.entity(2)
				s.position = Vector3(-5, 0, 0)
				s.posture = (trial / 2) % 5
				s.at_cover = trial % 2 == 0
				s.cover_type = trial % 4
				s.cover_h = 0.4 + (trial % 6) * 0.25
				s.peek_up = tick % 3 == 0
				s.blind = trial % 5 == 0
				s.cover_n = Vector3.RIGHT
				s.lean_dir = Vector3.BACK
				target_soldier.position = Vector3(20, 0, (tick % 3 - 1) * 2)
				target_soldier.posture = (trial / 8) % 5
				target_soldier.at_cover = trial % 2 == 0
				target_soldier.cover_type = (trial / 3) % 4
				target_soldier.cover_h = (trial % 8) * 0.25
				target_soldier.peek_up = tick % 2 == 0
				target_soldier.blind = tick % 5 == 0
				target_soldier.cover_n = Vector3.LEFT
				target_soldier.lean_dir = Vector3.BACK
				target_soldier.life = Soldier.Life.DOWNED if trial % 11 == 0 else Soldier.Life.ALIVE
				target_soldier.gone = trial % 17 == 0
				var drone: Drone = w.entity(4)
				drone.position = Vector3(20, 3, 0)
				drone.dead = trial % 19 == 0
				s.target = w.entity(2 + ((trial + (tick / 20)) % 5)) if trial % 13 else null
				w.entity(6).position = Vector3(5, 0, 0 if tick % 16 < 8 else 40)
				w.combat.dirty_collision(6)
				w.fires.smokes = [[Vector3(5, 2, 0), 8.0]] if tick % 7 == 0 else []
				w.combat.update_fire_smoke(w.fires.smokes)
				s.squad.known = {2: {"e": target_soldier, "pos": target_soldier.position, "t": w.time - (trial % 7)}}
				var cf := (trial + tick) % 4 == 0
				var cfp := Vector3(20 if trial % 7 else 150, 0, -5)
				var aim := s._weapon_aim(s._target_valid(s.target), cf, cfp, 50.0)
				results.append([aim, id(s._aim_ent), id(s.los_ent), s.los_t, s.los_ok, w.rng.state, w.stats.duplicate()])
				if w.stats.get("perception_blocked_reused", 0) > 0:
					outcomes.reused = true
				if aim == Vector3.INF:
					outcomes.no_aim = true
				elif s._aim_ent:
					outcomes[id(s._aim_ent)] = true
				else:
					outcomes.area_fire = true
			assert(results[0] == results[1], "Aim trial=%d tick=%d ref=%s rust=%s" % [trial, tick, results[0], results[1]])
			assert(worlds[1].entity(1)._aim_core != null, "Fixture must run the Rust aim controller")
			if tick % 19 == 0:
				var s: Soldier = worlds[1].entity(1)
				var core: RefCounted = ClassDB.instantiate("InfantryAimCore")
				assert(core.restore(s._aim_core.checkpoint()))
				s._aim_core = core
			checks += 1
	for outcome in ["no_aim", "area_fire", 2, 3, 4, 5, 6]:
		assert(outcomes.has(outcome), "Aim fixture did not exercise %s" % outcome)
	assert(outcomes.has("reused"), "Exercise obstruction reuse")
	for w in worlds:
		w.free()
	print("INFANTRY_AIM passed steps=", checks)
	get_tree().quit()
