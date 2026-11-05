extends "res://tests/fixtures/native-bullet.gd"

var max_damage_difference := 0.0

class BlastScene extends ShotScene:
	func vehicles_near(p: Vector3, r: float) -> Array:
		var result := []
		for e: Entity in entities.values():
			if e is Vehicle and Defs.flat(e.position - p).length_squared() <= r * r:
				result.append(e)
		return result
	func structures_near(p: Vector3, r: float, _floors_only := false) -> Array:
		var result := []
		for e: Entity in entities.values():
			if e is Structure and Defs.flat(e.position - p).length_squared() <= r * r:
				result.append(e)
		return result
	func note_heavy_impact(p: Vector3) -> void:
		effects.append(["heavy", p])

class BlastTerrain extends ShotTerrain:
	func in_trench(p: Vector3) -> bool:
		return world.trial % 3 == 0 and p.z > 0.0
	func blast_mul(_p: Vector3) -> float:
		return [0.65, 1.0, 1.2][world.trial % 3]
	func add_crater(p: Vector3, size: float) -> void:
		world.effects.append(["crater", p, size, world.rng.state])
		world.rng.randi()

class BlastFires extends Fires:
	func blast(p: Vector3, size: float, r: float) -> void:
		world.effects.append(["fire", p, size, r, world.rng.state])
		world.rng.randi()

class BlastSoldier extends ShotSoldier:
	func fling_from(c: Vector3, power: float) -> void:
		world.effects.append(["fling", eid, c, power, life, world.rng.state])
		world.rng.randi()
	func flinch_from(c: Vector3, dist: float, max_r: float) -> void:
		world.effects.append(["flinch", eid, c, dist, max_r, life, world.rng.state])
		world.rng.randi()

class BlastCar extends ShotCar:
	func explosion_hit(pos: Vector3, d: Dictionary) -> void:
		world.effects.append(["vehicle", eid, pos, d.dmg, world.rng.state])
		world.rng.randi()

class BlastWall extends ShotWall:
	func toss_from(bp: Vector3, bsize: float) -> void:
		world.effects.append(["toss", eid, bp, bsize, world.rng.state])
		world.rng.randi()


func blast_world(native: bool) -> BlastScene:
	var w := BlastScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.rules = ShotRules.new(w)
	w.terrain = BlastTerrain.new(w)
	w.battle = BattleStats.new(w)
	w.combat = Combat.new(w)
	w.fires = BlastFires.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for entity_id in [1, 2, 3, 4]:
		register(w, BlastSoldier.new(), entity_id)
	register(w, BlastCar.new(), 5)
	register(w, BlastWall.new(), 6)
	register(w, BlastWall.new(), 7)
	register(w, ShotDrone.new(), 8)
	w.drones.append(w.entity(8))
	body(w.entity(5), Vector3(3, 3, 4))
	body(w.entity(6), Vector3(1, 3, 6))
	body(w.entity(7), Vector3(1, 3, 6))
	return w


func same_effects(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for event in a.size():
		if a[event].size() != b[event].size():
			return false
		for field in a[event].size():
			if typeof(a[event][field]) != typeof(b[event][field]):
				return false
			if typeof(a[event][0]) == TYPE_STRING and a[event][0] == "damage" and field == 2:
				# The pinned power function can differ from Godot's platform libm by an ulp.
				var difference := absf(float(a[event][field]) - float(b[event][field]))
				max_damage_difference = maxf(max_damage_difference, difference)
				if difference > 0.0000000001:
					return false
			elif a[event][field] != b[event][field]:
				return false
	return true


func _ready() -> void:
	var worlds := [blast_world(false), blast_world(true)]
	var outcomes := {}
	for trial in 2048:
		for w in worlds:
			w.trial = trial
			w.rng.seed = 31991 + trial
			w.effects.clear()
			for e: Entity in w.entities.values():
				e.hp = 100.0
				e.team = e.eid % 2
				e.position = Vector3((trial % 9) * 0.6 + e.eid * 0.3, 0, (trial % 7) * 0.4 - 2.0)
				if e is Soldier:
					e.life = (trial + e.eid) % 6
					e.posture = (trial / 6 + e.eid) % 5
				elif e is Drone:
					e.dead = false
				elif e is Structure:
					e.radius = 0.5 + (trial % 4) * 0.5
					e.skind = ["low_wall", "car", "tall_wall", "hesco", "wire", "mines", "crates"][trial % 7]
					e.variant = 1
				if e is Structure or e is Vehicle:
					if trial % 2:
						e.position.z += 12.0
					w.combat.dirty_collision(e.eid)
			var pos := Vector3(-0.4, 0.1, -0.2 if trial % 2 else 0.2)
			var data := {"dmg": 20.0 + trial % 150, "radius": 0.25 + (trial % 12) * 0.8, "fling": 0.0 if trial % 4 == 0 else 7.0,
				"src": w.entity(1), "team": 1, "size": 0.8 if trial % 3 else 2.0, "struct_mult": 1.0 + (trial % 3) * 0.25, "top": trial % 2 == 0}
			w.combat.explode(pos, data)
		assert(same_effects(worlds[0].effects, worlds[1].effects), "Blast trial=%d ref=%s rust=%s" % [trial, worlds[0].effects, worlds[1].effects])
		assert(worlds[0].rng.state == worlds[1].rng.state, "Blast random cursor")
		for event: Array in worlds[0].effects:
			outcomes[event[0]] = true
	for outcome in ["damage", "fling", "flinch", "wall", "vehicle", "drone", "toss", "crater", "fire", "heavy", Fx.EXPLODE]:
		assert(outcomes.has(outcome), "Blast fixture did not exercise %s" % outcome)
	for w in worlds:
		w.free()
	print("NATIVE_BLAST passed cases=2048 max_damage_difference=%.20f" % max_damage_difference)
	get_tree().quit()
