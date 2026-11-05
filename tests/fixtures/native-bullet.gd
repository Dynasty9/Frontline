extends "res://tests/fixtures/infantry-aim.gd"

class ShotScene extends World:
	var trial := 0
	var effects := []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func fx_event(event: Array) -> void:
		effects.append(event)
	func soldiers_near(p: Vector3, r: float) -> Array:
		var result := []
		for e: Entity in entities.values():
			if e is Soldier and Defs.flat(e.position - p).length_squared() <= r * r:
				result.append(e)
		return result
	func trench_enfiladed(_p: Vector3, _from: Vector3) -> bool:
		return trial % 4 == 0

class ShotTerrain extends TerrainMap:
	func hit_mul(_target: Vector3, _shooter: Vector3) -> float:
		return [0.45, 0.7, 1.0, 1.2][world.trial % 4]
	func in_trench(_p: Vector3) -> bool:
		return world.trial % 3 == 0

class ShotRules extends Rules:
	func has_upgrade(_team: int, _key: String) -> bool:
		return world.trial % 2 == 0

class ShotCombat extends Combat:
	func explode(pos: Vector3, d: Dictionary) -> void:
		world.effects.append(["explosion", pos, d.dmg, d.radius, d.src.eid, world.rng.state])
		for _i in 3:
			world.rng.randi()

class ShotSoldier extends Soldier:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func take_damage(amount: float, src = null, hitdir := Vector3.ZERO, kind := "bullet") -> void:
		world.effects.append(["damage", eid, amount, src.eid, hitdir, kind, world.rng.state])
		world.rng.randi()
		hp -= amount
		life = Life.DOWNED if hp > 0.0 else Life.DEAD
		posture = Post.PRONE
	func add_suppression(amount: float, from := Vector3.INF) -> void:
		world.effects.append(["suppression", eid, amount, from, world.rng.state])
		world.rng.randi()
		suppression += amount

class ShotCar extends Vehicle:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func is_air() -> bool:
		return world.trial % 2 == 0
	func bullet_hit(p: Vector3, dir: Vector3, _w: Dictionary, shooter) -> int:
		world.effects.append(["vehicle", eid, p, dir, shooter.eid, world.rng.state])
		world.rng.randi()
		return Fx.HIT_METAL

class ShotWall extends Structure:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func take_damage(amount: float, src = null) -> void:
		world.effects.append(["wall", eid, amount, src.eid, world.rng.state])
		world.rng.randi()
		hp -= amount

class ShotDrone extends Drone:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func shot_down() -> void:
		world.effects.append(["drone", eid, world.rng.state])
		world.rng.randi()
		dead = true


func shot_world(native: bool) -> ShotScene:
	var w := ShotScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.rules = ShotRules.new(w)
	w.terrain = ShotTerrain.new(w)
	w.battle = BattleStats.new(w)
	w.combat = ShotCombat.new(w)
	w.fires = Fires.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	register(w, ShotSoldier.new(), 1)
	register(w, ShotSoldier.new(), 2)
	register(w, ShotCar.new(), 3)
	register(w, ShotDrone.new(), 4)
	register(w, ShotWall.new(), 5)
	register(w, ShotWall.new(), 6)
	register(w, ShotCar.new(), 7)
	register(w, ShotSoldier.new(), 8)
	body(w.entity(3), Vector3(3, 3, 4))
	body(w.entity(5), Vector3(2, 4, 4))
	body(w.entity(6), Vector3(1, 5, 8))
	body(w.entity(7), Vector3(3, 3, 4))
	return w


func _ready() -> void:
	var worlds := [shot_world(false), shot_world(true)]
	var weapons: Array = Defs.WEAPONS.values()
	var outcomes := {}
	for trial in 4096:
		for w in worlds:
			w.trial = trial
			w.rng.seed = trial + 10007
			w.time = 10.0
			w.stats.clear()
			w.effects.clear()
			w.combat._reveal.clear()
			for e: Entity in w.entities.values():
				e.team = 0 if e.eid in [1, 7] else 1
				e.owner_peer = -1 - e.team
				e.hp = 100.0
				e.position = Vector3(20, 0, (e.eid - 2) * 10)
				if e is Soldier:
					e.life = Soldier.Life.ALIVE
					e.posture = trial % 5
					e.suppression = trial % 100
					e._gy = -1.0 if trial % 3 == 0 else 0.0
				elif e is Drone:
					e.dead = false
				elif e is Vehicle or e is Structure:
					w.combat.dirty_collision(e.eid)
			w.entity(1).position = Vector3(-5, 0, 0)
			w.entity(7).position = Vector3(-5, 0, 0)
			w.entity(8).position = Vector3(9.5, 0, 0)
			w.entity(8).team = trial % 7 == 0
			var blocker: Structure = w.entity(6)
			blocker.position = Vector3(8, 0, 0 if trial % 3 else 30)
			blocker.skind = ["low_wall", "car", "tall_wall", "hesco"][trial % 4]
			blocker.variant = 1
			w.combat.dirty_collision(6)
			w.fires.smokes = [[Vector3(6, 1, 0), 5.0]] if trial % 11 == 0 else []
			w.combat.update_fire_smoke(w.fires.smokes)
		for round in 3:
			for w in worlds:
				var shooter: Entity = w.entity(7 if trial % 6 == 0 else 1)
				var target: Entity = w.entity(2 + (trial / 7) % 4) if trial % 5 else null
				var aim: Vector3 = target.center_point() if target else Vector3(24, -0.5 if trial % 2 else 1.0, 0)
				var weapon: Dictionary = weapons[trial % weapons.size()]
				w.combat.fire_bullet(shooter, shooter.position + Vector3(0, 1.4, 0), aim, target, weapon, 0.5 + (trial % 4) * 0.5)
			assert(worlds[0].effects == worlds[1].effects, "Bullet effects trial=%d round=%d ref=%s rust=%s" % [trial, round, worlds[0].effects, worlds[1].effects])
			assert(worlds[0].rng.state == worlds[1].rng.state, "Bullet random cursor")
			assert(worlds[0].stats == worlds[1].stats and worlds[0].battle.sides == worlds[1].battle.sides and worlds[0].battle.players == worlds[1].battle.players, "Bullet counters and credit")
		for event: Array in worlds[0].effects:
			outcomes[event[0]] = true
		if worlds[0].stats.get("through_hit", 0) > 0:
			outcomes.through_hit = true
	for outcome in ["damage", "suppression", "wall", "vehicle", "drone", "explosion", "through_hit", Fx.SHOT]:
		assert(outcomes.has(outcome), "Bullet fixture did not exercise %s" % outcome)
	for w in worlds:
		w.free()
	print("NATIVE_BULLET passed shots=12288")
	get_tree().quit()
