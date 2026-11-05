extends "res://tests/fixtures/vehicle-flight.gd"

class Pilot extends Aviator:
	var events := []
	# Shared cargo mutations have their own paired-actor check. Here compare when pilots request them.
	func _hook(v: Vehicle) -> void:
		events.append([1, v.eid])
	func _release_sling() -> void:
		events.append([2, 0])
	func dismount() -> void:
		events.append([3, 0])
	func _sling_tick(_dt: float) -> void:
		pass

class Pad extends Structure:
	func _ready() -> void:
		set_process(false)

func pad(w: World, id: int, p: Vector3, supply: float) -> Structure:
	var s := Pad.new()
	s.world = w
	s.eid = id
	s.team = 0
	s.skind = "fob"
	s.built = true
	s.position = p
	s.supply = supply
	w.add_child(s)
	return s

func fob_row(s: Structure) -> Array:
	return [s.eid, s.position, s.supply] if s and not s.gone and s.team == 0 else []

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
	w.rules = Rules.new(w)
	var home := pad(w, 50, Vector3(-31.3, 0, 7.1), 300)
	var fob_a := pad(w, 51, Vector3(12.7, 0, -19.3), 20)
	var fob_b := pad(w, 52, Vector3(-12.7, 0, -19.3), 20)
	w.rules.depots[0] = home
	w.fob_structures = [fob_a, fob_b]
	var cargo := Carrier.new()
	cargo.eid = 99
	cargo.team = 0
	cargo.vkind = "technical"
	cargo.vdef = Defs.VEHICLES[cargo.vkind]
	cargo.position = Vector3(17.3, 0, -13.7)
	w.add_child(cargo)
	var passenger := make_soldier(w, 98, 0)
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].get("base", "") == "lift_heli":
			kinds.append(kind)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	checks = 0
	var observed := {}
	for trial in 64:
		var supply := trial % 2 == 0
		var v := Pilot.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.max_hp = v.vdef.hp
		v.hp = v.max_hp
		v.flight = HelicopterFlight.new()
		v.heli_home = home if trial % 3 else null
		v.position = Vector3(-7.3, 0.15, 11.7)
		v.rotation.y = (trial % 7) * 0.37
		v.heli_phase = (trial / 2) % 8
		v.heli_dest = fob_a
		v.heli_t = 0.3
		v._flight_hold = Vector3(9.1, 0.15, -3.7)
		v.lift_phase = (trial / 2) % 8
		v.lift_dest = Vector3(13.7, 0, -11.3)
		v.lift_t = 0.3
		v.sling_target = cargo if v.lift_phase in [5, 6] else null
		v.sling_cargo = cargo if trial % 7 == 3 else null
		v.passengers = [passenger] if trial % 3 == 2 else []
		w.add_child(v)
		fob_a.team = 0
		fob_a.gone = false
		fob_a.supply = 20
		fob_b.supply = 20
		cargo.gone = false
		assert(core.load_state(VehicleState.capture(v)))
		for step in 1200:
			var dt: float = [1.0 / 30.0, 0.1, 0.2][trial % 3]
			if step == 310:
				fob_a.team = 1 if trial % 4 == 0 else 0
				cargo.gone = trial % 5 == 1
			w.effects.clear()
			w.stats.clear()
			v.events.clear()
			if supply:
				var rows := []
				for f in w.rules.fobs(0):
					rows.append(fob_row(f))
				var return_to: Vector3 = home.position if v.heli_home else home.position + Vector3(0, 0, -12)
				var delivered: int = core.supply_guidance(dt, flight_profile(v), w.terrain._native, PackedByteArray(), rows, fob_row(v.heli_dest), return_to)
				assert(delivered >= 0)
				v._heli_tick(dt)
				assert(int(w.stats.get("heli_delivered", 0)) == int(delivered != 0))
				if delivered:
					assert(w.effects == [[Fx.DELIVER, v.heli_dest.position + Vector3(0, 4, 0), int(v.vdef.get("load", 80)), v.team]])
					observed["supply"] = true
			else:
				# Scan/combat run before guidance; preserve only that independent clock here.
				var state: Array = core.values()
				state[2][11] = 0.5 if v.scan_t - dt <= 0.0 else v.scan_t - dt
				assert(core.load_state(state))
				var target := [cargo.eid, cargo.position, cargo._hull_size().y] if v.sling_target and v.can_sling(cargo) else []
				var home_input := PackedVector3Array([home.position, v._landing_spot(home.position)]) if v.heli_home else PackedVector3Array()
				var event: PackedInt64Array = core.lift_guidance(dt, flight_profile(v), w.terrain._native, PackedByteArray(), v._cargo_h(), target, home_input)
				assert(event.size() == 2)
				v._lift_tick(dt)
				assert(v.events == ([] if event[0] == 0 else [[event[0], event[1]]]), "Pilot event %d/%d %s / %s" % [trial, step, v.events, event])
				if event[0] > 0:
					observed[["", "hook", "release", "dismount"][event[0]]] = true
			compare_flight(v, core, "air trial=%d step=%d" % [trial, step])
			if step % 67 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
		var saved: PackedByteArray = core.checkpoint()
		assert(core.lift_guidance(NAN, flight_profile(v), w.terrain._native, PackedByteArray(), 0.0, [], PackedVector3Array()).is_empty())
		assert(core.checkpoint() == saved)
		v.free()
	for key in ["supply", "hook", "release", "dismount"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_AIR passed steps=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
