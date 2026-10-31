extends "res://tests/fixtures/vehicle-launch.gd"

class Targets extends Rules:
	var chosen := Vector3.INF
	var queries := 0
	func mortar_target(_team: int, _from: Vector3, _min: float, _max: float) -> Vector3:
		queries += 1
		world.rng.randi()
		return chosen

func artillery_profile(v: Vehicle) -> Array:
	var a: Dictionary = v.vdef.art
	var p := v.motion_profile()
	return [a.get("shell", "arty"), PackedFloat64Array([v.vdef.get("gun_h", 2.2), a.get("muzzle", 4.0), a.get("scatter", 3.0),
		a.get("lay", 2.0), a.get("gap", 0.8), a.get("cd", 18.0), p.traverse, p.traverse_accel]), a.get("salvo", 3)]

var maximum_lay_error := 0.0

func compare_motion(v: Vehicle, core: RefCounted, label: String) -> void:
	var expected := VehicleState.capture(v)
	var actual: Array = core.values()
	for group in expected.size():
		if group == 2:
			for i in expected[group].size():
				assert(absf(float(expected[group][i]) - float(actual[group][i])) < 0.0001, "%s scalar %d" % [label, i])
		elif group == 4:
			for i in expected[group].size():
				assert((expected[group][i] as Vector3).distance_to(actual[group][i]) < 0.0002, "%s point %d" % [label, i])
		elif group == 6:
			for i in expected[group].size():
				assert(expected[group][i].size() == actual[group][i].size())
				if i == 0 and expected[group][i].size():
					# Godot's atan2 and portable libm may differ in the last double-precision bit.
					var error := absf(float(expected[group][i][0]) - float(actual[group][i][0]))
					maximum_lay_error = maxf(maximum_lay_error, error)
					assert(error < 0.000000000001, "%s laying angle difference %.17f" % [label, error])
				else:
					assert(expected[group][i] == actual[group][i], "%s optional %d" % [label, i])
		else:
			assert(expected[group] == actual[group], "%s group %d" % [label, group])
	checks += 1

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var helper: Node = load("res://tests/fixtures/projectile-actor.gd").new()
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].has("art"): kinds.append(kind)
	checks = 0
	var observed := {}
	for trial in 64:
		var w := LaunchWorld.new()
		w.has_view = false
		w.srv = true
		w.spawn_id = 2
		w.rng.seed = trial + 137
		w.rules = Targets.new(w)
		w.rules.chosen = Vector3.INF if trial % 5 == 0 else Vector3(71.3, 0, -113.7)
		random.set_seed(trial + 137)
		add_child(w)
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(1.3, 0, -2.7)
		v.rotation.y = trial * 0.37
		v.path_pending = trial % 7 == 0
		v.fire_queue = [Vector3(41.3, 0, -79.7)] if trial % 3 == 0 else []
		w.add_child(v)
		w.entities = {1: v}
		assert(actors.load_state(2, PackedByteArray([2]), [vehicle_bytes(v, core)]))
		var p := artillery_profile(v)
		var expected_stats := {}
		var queries := 0
		for step in 600:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			w.time += dt
			w.shots.clear()
			var target := PackedVector3Array()
			if actors.artillery_needs_target(1, w.time) == 1:
				queries += 1
				random.randi()
				if w.rules.chosen != Vector3.INF: target.append(w.rules.chosen)
			v._arty_tick(dt)
			var event: int = actors.artillery_tick(1, w.time, dt, p, target)
			assert(event >= 0)
			if event == 1:
				expected_stats["arty_mission"] = int(expected_stats.get("arty_mission", 0)) + 1
			if event == 2:
				assert(w.shots.size() == 1)
				var shot: Projectile = w.shots[0]
				var launch: Array = actors.launch_vehicle_shell(1, w.time, p, random)
				assert(launch.size() == 5 and launch[0] == shot.eid)
				assert((launch[1] as Vector3).distance_to(shot.position) < 0.0002)
				assert((launch[1] as Vector3).distance_to(shot.origin) < 0.0002)
				assert((launch[2] as Vector3).distance_to(shot.target) < 0.0002)
				assert(absf(float(launch[4]) - shot.shell_t) < 0.0001)
				assert(actors.finish_artillery_round(1, p))
				compare_projectile(shot, actors, helper)
				expected_stats["arty_round"] = int(expected_stats.get("arty_round", 0)) + 1
				observed[shot.ptype] = true
			else:
				assert(w.shots.is_empty())
			assert(w.rules.queries == queries, "Automatic target query order")
			assert(w.stats == expected_stats, "Artillery events")
			assert(w.rng.state == random.get_state(), "Artillery random continuation")
			assert(actors.next_id() == w.spawn_id)
			compare_owned(v, actors, core, "artillery %d/%d" % [trial, step])
			if step % 43 == 0:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.free()
	for trial in 96:
		var w := LaunchWorld.new()
		w.has_view = false
		w.srv = true
		w.combat = Combat.new(w)
		w.time = 30.7
		w.rng.seed = trial + 137
		random.set_seed(trial + 137)
		add_child(w)
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = 0
		v.vkind = ["blackfoot", "pawnee", "hellcat", "kajman"][trial % 4]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(1.3, 15, -2.7)
		v.rotation.y = trial * 0.37
		w.add_child(v)
		var foe := Warned.new()
		foe.world = w
		foe.srv = true
		foe.eid = 2
		foe.team = 1
		foe.vkind = "tank"
		foe.vdef = Defs.VEHICLES.tank
		foe.hp = foe.vdef.hp
		foe.max_hp = foe.vdef.hp
		foe.position = Vector3(1.3 + trial % 3, 0, -52.7)
		foe.smoke_left = 0 if trial % 3 == 0 else 2
		foe.brain_state = "withdraw"
		w.add_child(foe)
		w.entities = {1: v, 2: foe}
		w.vehicles = [v, foe]
		v.target = foe
		assert(actors.load_state(3, PackedByteArray([2, 2]), [vehicle_bytes(v, core), vehicle_bytes(foe, core)]))
		var previous_fire := v.last_fire_t
		v._rocket_salvo()
		assert(v.last_fire_t == w.time)
		var warning_index := 0
		for i in int(v.vdef.get("rockets", 4)):
			var launch: Array = actors.launch_vehicle_rocket(1, 2, i, random)
			assert(launch.size() == 3)
			var warned: int = actors.projectile_warning_target(launch[0])
			if warned != 0:
				assert(w.warnings[warning_index][0] == warned)
				assert((w.warnings[warning_index][1] as Vector3).distance_to(launch[1]) < 0.0002)
				warning_index += 1
				var smoke: Array = actors.launch_vehicle_smoke(warned, w.time, launch[1], 2, false, foe.vdef.get("gun_h", 2.0), random)
				assert(smoke.size() == 1)
				if smoke[0].size(): observed["interleaved_smoke"] = true
		assert(warning_index == w.warnings.size())
		assert(actors.next_id() == w.spawn_id)
		assert(w.rng.state == random.get_state(), "Each rocket warns before the next scatter draw")
		for shot: Projectile in w.shots: compare_projectile(shot, actors, helper)
		v.last_fire_t = previous_fire
		compare_owned(v, actors, core, "rocket carrier %d" % trial)
		compare_owned(foe, actors, core, "rocket target %d" % trial)
		w.free()
	for key in ["arty", "grad", "interleaved_smoke"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	helper.free()
	print("VEHICLE_ARTILLERY passed states=%d lay_error=%.17f outcomes=%s" % [checks, maximum_lay_error, observed])
	get_tree().quit()
