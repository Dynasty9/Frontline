extends "res://tests/fixtures/boat-navigation.gd"

func _ready() -> void:
	dimensions()
	var w := ground_world()
	var nav: RefCounted = ClassDB.instantiate("BoatNavigationCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var foe := make_soldier(w, 9, 1)
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].get("base", kind) == "boat": kinds.append(kind)
	checks = 0
	var observed := {}
	for trial in 72:
		var mode := trial % 12
		var water := setup_water(w, mode, nav)
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.vkind = kinds[(trial / 12 + mode) % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(0.3, WaterMap.LEVEL, 1.7)
		v.rotation.y = 0.0
		v.path = PackedVector3Array([Vector3(0.3, 0, -90.0)])
		if mode == 1: v.path = PackedVector3Array([Vector3(0.3, 0, 9.0)])
		if mode == 2: v.path.clear()
		if mode in [2, 3, 4, 5, 6]: v.speed = 8.3
		if mode in [5, 6]:
			v.position.z = 0.01
			v.path = PackedVector3Array([Vector3(0.3, 0, -5.0 if mode == 5 else -100.0)])
		if mode == 7: v._stuck_t = 4.1
		if mode in [8, 10]:
			v.rotation.y = PI
			v.path = PackedVector3Array([Vector3(-9, 0, -40), Vector3(25, 0, -80), Vector3(60, 0, -100)])
		if mode == 11: v.path = w.nav.find_boat_path(v.position, Vector3(-30, 0, 100))
		foe.position = Vector3(0.3, 0, 25.0 if mode == 3 else -50.0)
		v.target = foe if mode in [3, 4] else null
		v.assault = mode in [3, 4]
		w.add_child(v)
		w.vehicles.append(v)
		var others := []
		if mode == 4:
			for j in 3:
				var other := Carrier.new()
				other.world = w
				other.eid = 20 + j
				other.vkind = "rhib"
				other.vdef = Defs.VEHICLES.rhib
				other.position = Vector3((j - 1) * 3.0, WaterMap.LEVEL, -9.0 - j * 15.0)
				other.rotation.y = PI if j == 2 else 0.0
				other.speed = 0.0 if j == 0 else 1.7
				w.add_child(other)
				w.vehicles.append(other)
				others.append(other)
		assert(core.load_state(VehicleState.capture(v)))
		var p := [v._hull_size(), v.vdef.speed, PackedFloat64Array(v._hull_k()), v.vdef.cannon]
		for step in 600:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][(trial / 12) % 3]
			w.time = step * dt
			w.stats.clear()
			var target := PackedVector3Array([foe.position]) if v._target_ok() else PackedVector3Array()
			var result: PackedByteArray = core.boat_tick(dt, w.time, p, target, nav, water, traffic(w))
			assert(result.size() == 4)
			v._boat_drive(dt)
			for i in 4:
				var key: String = ["boat_unstick", "boat_aground", "boat_rejoin", "boat_about_seaward"][i]
				assert(result[i] == int(w.stats.get(key, 0)), "Boat event " + key)
				if result[i]: observed[key] = true
			compare_motion(v, core, "%s mode=%d step=%d" % [v.vkind, mode, step])
			if step % 37 == 0:
				var state: PackedByteArray = core.checkpoint()
				assert(core.restore(state) and core.checkpoint() == state)
			if v._rev: observed["reverse"] = true
			if v._grounded: observed["grounded"] = true
			if v._current.length() > 0.0: observed["current"] = true
			if v._avoid_cap == 3.0: observed["avoid"] = true
			if v.path_i >= v.path.size() and not v.path.is_empty(): observed["arrived"] = true
			for other in others: other.position += Defs.dir_of(other.rotation.y) * other.speed * dt
		for other in others:
			w.vehicles.erase(other)
			other.free()
		w.vehicles.erase(v)
		v.free()
	for key in ["boat_unstick", "boat_aground", "boat_rejoin", "boat_about_seaward", "reverse", "grounded", "current", "avoid", "arrived"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	foe.free()
	w.free()
	print("VEHICLE_BOAT passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
