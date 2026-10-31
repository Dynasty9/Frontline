extends "res://tests/fixtures/vehicle-sling.gd"

class CannonCombat extends Combat:
	var blasts := []
	func ray(from: Vector3, to: Vector3, _exclude: Array = []) -> Dictionary:
		var hit: PackedFloat64Array = _collision.ray(from, to, PackedInt64Array([1]))
		return {} if hit.is_empty() else {"position": Vector3(hit[2], hit[3], hit[4])}
	func explode(p: Vector3, d: Dictionary) -> void:
		assert(d.src.last_fire_t == world.time)
		assert(world.effects.back()[0] == Fx.CANNON and world.stats.cannon == 1)
		blasts.append([p, d])
		# Shared damage follows the timestamp and muzzle event, and can consume randomness.
		for _i in 4: world.rng.randi()

func muzzle_profile(v: Vehicle, weapon: String) -> Array:
	var item: Dictionary = VehicleSockets.layout(v.vkind).get(weapon, {})
	var points := PackedVector3Array()
	if not item.is_empty():
		points.append(Vector3(item.point[0], item.point[1], item.point[2]))
		if item.has("pivot"): points.append(Vector3(item.pivot[0], item.pivot[1], item.pivot[2]))
	return [PackedByteArray([int(v.is_heli()), int(v.base() == "attack_heli")]), v.vdef.get("gun_h", 0.8 if v.base() == "attack_heli" else 2.2), points]

func _ready() -> void:
	MapDims.N = 128
	MapDims.SIZE = 128.0
	MapDims.HALF = 64.0
	MapDims.BIOME = 128
	Nav.N = 128
	Nav.H = 64.0
	HNav.C = 16
	HNav.NC = 8
	TerrainMap.N = 128
	TerrainMap.H = 64.0
	TerrainMap.DN = 256
	var w := ground_world()
	w.combat = CannonCombat.new(w)
	w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var helper: Node = load("res://tests/fixtures/projectile-actor.gd").new()
	var kinds := Defs.VEHICLES.keys()
	checks = 0
	var observed := {}
	for trial in 264:
		w.rng.seed = trial + 137
		random.set_seed(trial + 137)
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(1.3, 14 if v.is_heli() else 0, -2.7)
		v.rotation.y = (trial % 7) * 0.37
		v.turret_yaw = (trial % 11) * -0.17
		v.flight_pitch = (trial % 9) * 0.037
		v.flight_roll = (trial % 13) * -0.017
		if trial % 11 == 0: v.vkind = "fixture_unmapped"
		w.add_child(v)
		var foe := make_soldier(w, 2, 1)
		foe.position = Vector3(0, -1 if trial % 2 == 0 else 0, -30)
		foe.posture = trial % 3
		v.target = foe
		w.entities = {1: v, 2: foe}
		var trench := Mount.new()
		trench.world = w
		trench.eid = 99
		trench.skind = "trench"
		trench.built = true
		trench.radius = 5.0
		trench.size = Vector3(8, 1, 1)
		trench.position = Vector3(0, 0, -30)
		trench.yaw = PI * 0.5
		trench.hash_cells = w._shash_cells(trench)
		w.add_child(trench)
		w.terrain.trench.fill(0)
		if trial % 2 == 0:
			for z in range(32, 37):
				for x in range(62, 67): w.terrain.trench[z * Nav.N + x] = 1
		assert(w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
		if trial % 6 == 0:
			w.terrain.sync_structure(trench, true)
		w.combat._collision.remove_body(99)
		if trial % 4 == 0:
			assert(w.combat._collision.replace_body(99, PackedFloat32Array([0, 1, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 10, 0.5, 0])))
		assert(actors.load_state(3, PackedByteArray([2, 0]), [vehicle_bytes(v, core), soldier_bytes(foe)]))
		for weapon in ["gun", "mg"]:
			var p := muzzle_profile(v, weapon)
			assert(core.restore(actors.actor_state(1)))
			var actual: PackedVector3Array = core.weapon_muzzle(p, weapon == "gun")
			assert(actual.size() == 1)
			assert(actual[0].distance_to(v.weapon_muzzle(weapon)) < 0.00002, "Weapon socket %s/%s" % [v.vkind, weapon])
			checks += 1
			observed["socket" if p[2].size() else "fallback"] = true
		var p := muzzle_profile(v, "gun")
		var gun: Dictionary = v.vdef.get("gun", {})
		var g := PackedFloat64Array([gun.get("dmg", 160.0), gun.get("radius", 5.5), gun.get("at", 320.0), gun.get("size", 1.4)])
		for shot in 3:
			w.time = 30.7 + shot
			w.stats.clear()
			w.effects.clear()
			w.combat.blasts.clear()
			v._fire_cannon()
			var result: Array = actors.fire_vehicle_cannon(1, 2, w.time, p, g, w.terrain._native, w.combat._collision, random)
			assert(result.size() == 2 and result[1].size() == 1)
			assert((result[0] as Vector3).distance_to(w.effects[0][1]) < 0.00002)
			var actual: Array = result[1][0]
			var expected: Array = helper.blast(w.combat.blasts[0][0], w.combat.blasts[0][1])
			assert(actual.size() == expected.size())
			for i in actual.size():
				if i == 1:
					assert((actual[i] as Vector3).distance_to(expected[i]) < 0.0002, "Cannon impact %d" % trial)
				elif i == 2:
					assert(Array(actual[i]) == expected[i])
				elif i == 3:
					assert((actual[i][0] as Vector3).distance_to(expected[i][0]) < 0.00002)
				else:
					assert(actual[i] == expected[i])
			for _i in 4: random.randi()
			assert(w.rng.state == random.get_state(), "Damage follows cannon scatter")
			compare_owned(v, actors, core, "cannon %d/%d" % [trial, shot])
			var saved: PackedByteArray = actors.checkpoint()
			assert(actors.restore(saved) and actors.checkpoint() == saved)
		if trial % 4 == 0: observed["wall"] = true
		if trial % 2 == 0:
			observed["enfilade" if w.trench_enfiladed(foe.position, v.barrel_tip()) else "lip"] = true
		if v.is_heli(): observed["aircraft"] = true
		trench.free()
		foe.free()
		v.free()
		w.entities.clear()
	for key in ["socket", "fallback", "wall", "enfilade", "lip", "aircraft"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	helper.free()
	w.free()
	print("VEHICLE_CANNON passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
