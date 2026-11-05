extends "res://tests/fixtures/vehicle-sling.gd"

class LaunchWorld extends ActorWorld:
	var shots := []
	var warnings := []
	var spawn_id := 3
	func spawn(kind: String, data: Dictionary) -> Entity:
		assert(kind == "projectile")
		var p := Projectile.new()
		p.world = self
		p.srv = true
		p.eid = spawn_id
		spawn_id += 1
		p.apply_props(data)
		entities[p.eid] = p
		add_child(p)
		shots.append(p)
		if p.ptype in ["atgm", "rocket", "recoilless"]:
			p._warn_target()
		return p

class Warned extends Carrier:
	func threatened(from: Vector3) -> void:
		world.warnings.append([eid, from])
		super.threatened(from)

func compare_projectile(p: Projectile, actors: RefCounted, helper: Node) -> void:
	var expected: RefCounted = ClassDB.instantiate("ProjectileActorCore")
	helper.start(p, expected)
	var actual: RefCounted = ClassDB.instantiate("ProjectileActorCore")
	assert(actual.restore(actors.actor_state(p.eid)))
	var a: Array = actual.values()
	var b: Array = expected.values()
	assert(a[0] == b[0] and a[1] == b[1], "Projectile identity and motion kind")
	a = actual.view_state()
	b = expected.view_state()
	assert(a.size() == b.size())
	for i in a.size():
		if a[i] is Vector3:
			assert((a[i] as Vector3).distance_to(b[i]) < 0.0002, "Projectile %d point %d: %s / %s" % [p.eid, i, a[i], b[i]])
		else:
			assert(a[i] == b[i], "Projectile %d field %d" % [p.eid, i])
	checks += 1

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var helper: Node = load("res://tests/fixtures/projectile-actor.gd").new()
	checks = 0
	var observed := {}
	for trial in 128:
		var w := LaunchWorld.new()
		w.has_view = false
		w.srv = true
		w.combat = Combat.new(w)
		w.rng.seed = 137 + trial
		random.set_seed(137 + trial)
		add_child(w)
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = 0
		v.vkind = ["tank", "ifv", "blackfoot", "technical"][trial % 4]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(1.3, trial % 5, -2.7)
		v.rotation.y = trial * 0.37
		v.turret_yaw = trial * -0.17
		w.add_child(v)
		var foe := Warned.new()
		foe.world = w
		foe.srv = true
		foe.eid = 2
		foe.team = 1
		foe.vkind = ["tank", "ifv", "blackfoot", "technical"][trial % 4]
		foe.vdef = Defs.VEHICLES[foe.vkind]
		foe.hp = foe.vdef.hp
		foe.max_hp = foe.vdef.hp
		foe.position = Vector3(37.1, trial % 7, -21.7)
		foe.smoke_left = 2
		foe.smoke_cd = 100.0 if trial % 11 == 0 else 0.0
		# Crew evasion has its own comparison; this fixture isolates projectile creation.
		foe.brain_state = "withdraw"
		w.add_child(foe)
		w.entities = {1: v, 2: foe}
		w.vehicles = [v, foe]
		assert(actors.load_state(3, PackedByteArray([2, 2]), [vehicle_bytes(v, core), vehicle_bytes(foe, core)]))
		for step in 3:
			var kind: String = ["atgm", "sam", "atgm"][step]
			w.time = 10.3 + step * 30.0
			w.shots.clear()
			w.warnings.clear()
			var previous_fire := v.last_fire_t
			v._launch(kind, foe)
			assert(v.last_fire_t == w.time)
			var launch: Array = actors.launch_vehicle_missile(1, 2, kind == "atgm", v.base() == "attack_heli", v.vdef.get("gun_h", 0.8 if v.base() == "attack_heli" else 2.2))
			assert(launch.size() == 3 and launch[0] == w.shots[0].eid)
			var warned: int = actors.projectile_warning_target(launch[0])
			assert(w.warnings.size() == int(warned != 0))
			if warned != 0:
				assert(w.warnings[0][0] == warned)
				assert((w.warnings[0][1] as Vector3).distance_to(launch[1]) < 0.0002)
				var smoke: Array = actors.launch_vehicle_smoke(warned, w.time, launch[1], int(foe.vdef.get("armor", 0)), foe.is_heli(), foe.vdef.get("gun_h", 2.0), random)
				assert(smoke.size() == 1 and smoke[0].size() == w.shots.size() - 1)
				observed["smoke" if smoke[0].size() else "blocked"] = true
			else:
				observed["sam"] = true
			assert(w.rng.state == random.get_state(), "Random continuation after smoke")
			for p: Projectile in w.shots:
				compare_projectile(p, actors, helper)
			assert(actors.next_id() == w.spawn_id)
			# Weapon completion updates the timestamp after the launch and warnings.
			v.last_fire_t = previous_fire
			compare_owned(v, actors, core, "launcher %d/%d" % [trial, step])
			compare_owned(foe, actors, core, "warned %d/%d" % [trial, step])
			var saved: PackedByteArray = actors.checkpoint()
			assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.free()
	# Unguided warnings use vehicle registration order, with named targets taking priority.
	for trial in 64:
		var w := LaunchWorld.new()
		w.has_view = false
		w.srv = true
		add_child(w)
		var blocks := []
		for i in 3:
			var v := Warned.new()
			v.world = w
			v.srv = true
			v.eid = i + 1
			v.team = 0 if i == 0 else 1
			v.vkind = "tank"
			v.vdef = Defs.VEHICLES.tank
			v.smoke_left = 0
			v.position = Vector3(0, 0, -[0.0, 50.0, 43.0][i])
			if trial % 4 == 1 and i == 1: v.gone = true
			if trial % 4 == 2 and i == 1: v.position.x = 80.0
			if trial % 4 == 3 and i > 0: v.position.y = 100.0
			w.add_child(v)
			w.vehicles.append(v)
			if not v.gone:
				w.entities[v.eid] = v
				blocks.append(vehicle_bytes(v, core))
		var kinds := PackedByteArray()
		kinds.resize(blocks.size())
		kinds.fill(2)
		assert(actors.load_state(4, kinds, blocks))
		w.spawn_id = 4
		var p: Projectile = w.spawn("projectile", {"ptype": "rocket" if trial % 2 else "recoilless", "team": 0, "pos": Vector3.ZERO, "vel": Vector3(0, 0, -75), "thrower": 1, "tgt": 2 if trial % 5 == 0 else 0})
		var projectile: RefCounted = ClassDB.instantiate("ProjectileActorCore")
		helper.start(p, projectile)
		assert(actors.spawn(3, projectile.checkpoint()) == 4)
		var warned: int = actors.projectile_warning_target(4)
		assert(w.warnings.size() == int(warned != 0))
		if warned != 0: assert(w.warnings[0][0] == warned, "Warning order %d" % trial)
		observed["warning_%d" % warned] = true
		checks += 1
		w.free()
	for key in ["smoke", "blocked", "sam", "warning_0", "warning_2", "warning_3"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	helper.free()
	print("VEHICLE_LAUNCH passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
