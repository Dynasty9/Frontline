extends "res://tests/fixtures/vehicle-driving.gd"

class Aviator extends Carrier:
	func _scan() -> void:
		pass

func flight_profile(v: Vehicle) -> PackedFloat64Array:
	var p := v.motion_profile()
	return PackedFloat64Array([v.vdef.speed, p.handling[0], p.handling[1], p.hull_turn, p.hull_accel])

func compare_flight(v: Vehicle, core: RefCounted, label: String) -> void:
	var expected := VehicleState.capture(v)
	var actual: Array = core.values()
	for group in expected.size():
		if group in [2, 11]:
			for i in expected[group].size():
				assert(absf(float(expected[group][i]) - float(actual[group][i])) < 0.0001, "%s group=%d scalar=%d: %s / %s" % [label, group, i, expected[group][i], actual[group][i]])
		elif group == 4:
			for i in expected[group].size():
				assert((expected[group][i] as Vector3).distance_to(actual[group][i]) < 0.0002, "%s point=%d: %s / %s" % [label, i, expected[group][i], actual[group][i]])
		else:
			assert(expected[group] == actual[group], "%s group=%d: %s / %s" % [label, group, expected[group], actual[group]])
	checks += 1

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var w := ground_world()
	w.water = WaterMap.new(w)
	w.water.deck.resize(Nav.N * Nav.N)
	for z in Nav.N:
		for x in Nav.N:
			w.water.deck[z * Nav.N + x] = int(x in range(27, 31))
	for z in TerrainMap.DN:
		for x in TerrainMap.DN:
			w.terrain.dh[z * TerrainMap.DN + x] = sin(x * 0.13) * cos(z * 0.07) * 0.7
	assert(w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].get("air", false):
			kinds.append(kind)
	var cargo := Carrier.new()
	cargo.eid = 99
	w.add_child(cargo)
	checks = 0
	var observed := {}
	for trial in 80:
		var v := Aviator.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.position = Vector3(-7.3, 0.15 + trial % 5, 11.7)
		v.rotation.y = (trial % 7) * 0.37
		v.velocity = Vector3(1.7, -0.1, -0.3) if trial % 2 else Vector3.ZERO
		v.flight = HelicopterFlight.new()
		v.sling_cargo = cargo if trial % 4 == 0 else null
		v.uav_dest = Vector3(12.3, 0, -13.7)
		w.add_child(v)
		assert(core.load_state(VehicleState.capture(v)))
		var p := flight_profile(v)
		var uav := v.base() == "uav"
		var goal := Vector3(21.3, 14, -19.7)
		for step in 300:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1, 0.2][trial % 4]
			if step == 160:
				goal = Vector3(-12.3, 0.15, 7.7)
				v.sling_cargo = null
				v.uav_dest = Vector3(-17.3, 0, 15.7)
				var state: Array = core.values()
				state[0][8] = 0
				state[5][5] = PackedVector3Array([v.uav_dest])
				assert(core.load_state(state))
			if uav:
				# The scan runs before guidance; its timer remains in the existing dispatcher.
				var state: Array = core.values()
				var scan: float = v.scan_t - dt
				state[2][11] = 0.5 if scan <= 0.0 else scan
				assert(core.load_state(state))
				assert(core.fly_uav(dt, float(v.vdef.get("alt", 20.0)), float(v.vdef.get("orbit", 16.0)), p))
				v._uav_tick(dt)
				observed["uav"] = true
			else:
				var face: float = 1.3 if trial % 3 == 0 else INF
				var expected := v._fly_to(goal, dt, face)
				var actual: int = core.fly_to(goal, dt, VehicleState.optional_scalar(face), p, w.terrain._native, w.water.deck)
				assert(actual == int(expected), "Settled %d/%d expected=%s actual=%s" % [trial, step, expected, actual])
				if expected:
					observed["settled"] = true
				if v.sling_cargo:
					observed["loaded"] = true
			compare_flight(v, core, "%s trial=%d step=%d" % [v.vkind, trial, step])
			if step % 31 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
		var saved: PackedByteArray = core.checkpoint()
		assert(core.fly_to(goal, NAN, PackedFloat64Array(), p, w.terrain._native, w.water.deck) == -1)
		assert(core.fly_uav(NAN, 20.0, 16.0, p) == false)
		assert(core.checkpoint() == saved)
		v.free()
	for key in ["uav", "settled", "loaded"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_FLIGHT passed steps=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
