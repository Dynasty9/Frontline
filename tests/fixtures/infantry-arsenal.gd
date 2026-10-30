extends "res://tests/fixtures/infantry-grenades.gd"

class ArsenalScene extends GrenadeScene:
	func ground_y(_p: Vector3) -> float:
		return 0.7

class ArsenalRules extends Rules:
	var queries := []
	func fpv_target(team: int, pos: Vector3, radius: float) -> Entity:
		queries.append(["fpv", team, pos, radius, world.entity(1).drone_cd])
		return world.entity(10) if world.trial % 5 else null
	func mortar_target(team: int, pos: Vector3, rmin: float, rmax: float) -> Vector3:
		queries.append(["mortar", team, pos, rmin, rmax, world.entity(1).mortar_cd])
		return Vector3(70, 0, 10) if world.trial % 7 else Vector3.INF


func arsenal_world(native: bool) -> ArsenalScene:
	var w := ArsenalScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = Combat.new(w)
	w.rules = ArsenalRules.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for id in [1, 3, 4, 5]:
		register(w, ShotSoldier.new(), id)
	for id in [10, 11, 12]:
		register(w, ShotCar.new(), id)
		body(w.entity(id), Vector3(2, 3, 3))
	for id in [20, 21]:
		register(w, ShotWall.new(), id)
		body(w.entity(id), Vector3(1, 4, 4))
	register(w, ShotDrone.new(), 30)
	return w


func action_data(s: Soldier) -> Dictionary:
	var data := s.act_data.duplicate()
	if data.has("target"):
		data.target = eid(data.target)
	return data


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryArsenalCore"))
	var worlds := [arsenal_world(false), arsenal_world(true)]
	var outcomes := {}
	for trial in 2048:
		for w in worlds:
			w.trial = trial
			w.time = 10.0
			w.rng.seed = trial + 691
			w.stats.clear()
			w.spoken.clear()
			w.rules.queries.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3.ZERO
			s.rotation = Vector3.ZERO
			s.team = trial % 2
			s.act = Soldier.Act.IDLE
			s.act_kind = ""
			s.act_t = 0.0
			s.act_data.clear()
			s.say_cd = 0.0
			s.rockets = trial % 4
			s.drones_left = trial % 3
			s.mortar_rounds = trial % 5
			s.rocket_cd = 11.0 if trial % 7 == 0 else 0.0
			s.drone_cd = 11.0 if trial % 11 == 0 else 0.0
			s.mortar_cd = 11.0 if trial % 17 == 0 else 0.0
			s.melee_cd = 11.0 if trial % 19 == 0 else 0.0
			s.wdef = {} if trial % 11 == 0 else Defs.WEAPONS.rifle
			s.drone_ctrl = w.entity(30) if trial % 17 == 0 else null
			s._gy = 0.0
			s._gy_t = 0.0
			s.path = PackedVector3Array([Vector3(20, 0, 20)]) if trial % 13 == 0 else PackedVector3Array()
			s.path_i = 0
			s.squad = Squad.new() if trial % 13 else null
			if s.squad:
				s.squad.world = w
				s.squad.ambush = trial % 17 == 0
				if trial % 2 == 0:
					var distance: float = [24.99, 25.0, 140.0, 140.01][(trial >> 1) % 4]
					s.squad.fire_queue = [[Vector3(distance, 3, 0), "smoke"], [Vector3(100, 0, 20), "he"]]
			s.vis_targets = [w.entity(3)]
			for id in [3, 4, 5]:
				var other: Soldier = w.entity(id)
				other.team = (trial + id) % 3 - 1
				other.position = Vector3([1.89, 1.9, 1.91][(trial + id) % 3], 0, 0)
				other.life = Soldier.Life.DOWNED if (trial + id) % 4 == 0 else Soldier.Life.ALIVE
				other.flinging = (trial + id) % 5 == 0
			for id in [10, 11, 12]:
				var v: Vehicle = w.entity(id)
				v.position = Vector3([30.0, 59.99, 60.0, 69.99, 70.0, 74.99, 75.0][(trial + id) % 7], 0, (id - 10) * 5.0)
				v.gone = (trial + id) % 19 == 0
				w.combat.dirty_collision(id)
				if trial % 3 == 0:
					s.vis_targets.append(v)
				if s.squad:
					s.squad.known[id] = {"e": v, "t": w.time - float((trial + id) % 8)}
			var forced: Structure = w.entity(20)
			forced.position = Vector3([59.99, 60.0, 60.01][trial % 3], 0, 0)
			forced.gone = trial % 23 == 0
			s.forced_target = forced if trial % 5 == 0 else null
			w.combat.dirty_collision(20)
			w.entity(21).position = Vector3(10, 1.6, 0 if trial % 3 == 1 else 30)
			w.combat.dirty_collision(21)
			w.combat._visibility.set_projectile(1000, Vector3(15, 1.6, 5), 5.0 if trial % 5 == 0 else 0.0)
		for attempt in 4:
			for w in worlds:
				w.time += [0.0, 2.0, 4.0, 30.0][attempt]
			for method in ["_try_melee", "_try_mortar", "_try_rocket", "_try_drone"]:
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				var ar: bool = a.call(method)
				var br: bool = b.call(method)
				assert(ar == br, "%s result trial=%d attempt=%d" % [method, trial, attempt])
				outcomes[a.act_kind] = true
				for key in ["rockets", "rocket_cd", "drones_left", "drone_cd", "mortar_rounds", "mortar_cd", "melee_cd", "rotation", "path", "act", "act_kind", "act_t", "_gy", "_gy_t", "say_cd"]:
					assert(a.get(key) == b.get(key), "Arsenal %s %s trial=%d ref=%s rust=%s" % [method, key, trial, a.get(key), b.get(key)])
				assert(action_data(a) == action_data(b), "Arsenal action target")
				if a.squad:
					assert(a.squad.fire_queue == b.squad.fire_queue, "Mortar queue")
				assert(worlds[0].rng.state == worlds[1].rng.state, "Arsenal random cursor")
				assert(worlds[0].stats == worlds[1].stats and worlds[0].spoken == worlds[1].spoken, "Arsenal effects")
				assert(worlds[0].rules.queries == worlds[1].rules.queries, "Arsenal query order and state")
				if b._arsenal:
					var bytes: PackedByteArray = b._arsenal.checkpoint()
					assert(b._arsenal.restore(bytes))
	for key in ["melee", "mortar", "launch", "launch_drone", ""]:
		assert(outcomes.has(key), "Missing special attack " + key)
	for w in worlds:
		w.free()
	print("INFANTRY_ARSENAL passed decisions=32768")
	get_tree().quit()
