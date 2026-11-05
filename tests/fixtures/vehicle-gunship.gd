extends "res://tests/fixtures/vehicle-flight.gd"

class GunWorld extends ActorWorld:
	func soldiers_near(p: Vector3, r: float) -> Array:
		return soldiers.filter(func(s): return Defs.flat(s.position - p).length() <= r)

class Gunship extends Aviator:
	var scans := 0
	var fire_calls := 0
	var salvos := 0
	func _scan() -> void:
		scans += 1
	func _fire_tick() -> void:
		fire_calls += 1
	func _rocket_salvo() -> void:
		# Projectile creation and warning effects have a separate shared-actor comparison.
		salvos += 1

func _ready() -> void:
	MapDims.N = 256
	MapDims.SIZE = 256.0
	MapDims.HALF = 128.0
	MapDims.BIOME = 256
	Nav.N = 256
	Nav.H = 128.0
	HNav.C = 16
	HNav.NC = 16
	TerrainMap.N = 256
	TerrainMap.H = 128.0
	TerrainMap.DN = 512
	var w := GunWorld.new()
	w.has_view = false
	w.srv = true
	w.settings = {"seed": 137}
	w.terrain = TerrainMap.new(w)
	add_child(w)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].get("base", "") == "attack_heli": kinds.append(kind)
	var observed := {}
	checks = 0
	for trial in 64:
		var v := Gunship.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp * (0.2 if trial % 5 == 0 else 1.0)
		v.max_hp = v.vdef.hp
		v.position = Vector3(1.3, 14.0, -2.7)
		v.rotation.y = (trial % 7) * 0.37
		v.flight = HelicopterFlight.new()
		v.gs_dest = Vector3(51.7, 0, 75.3) if trial % 3 == 0 else Vector3.INF
		w.add_child(v)
		var foe: Entity
		w.soldiers.clear()
		if trial % 2 == 0:
			for i in 3:
				var s := make_soldier(w, 9 + i, 1)
				s.position = Vector3(13.7 + i, 0, -50.9)
				if i == 2 and trial % 4 == 0: s.life = Soldier.Life.DEAD
				w.soldiers.append(s)
			foe = w.soldiers[0]
		else:
			foe = Carrier.new()
			foe.world = w
			foe.eid = 9
			foe.team = 1
			foe.position = Vector3(13.7, 0, -50.9)
			w.add_child(foe)
		v.target = foe
		assert(core.load_state(VehicleState.capture(v)))
		var p := flight_profile(v)
		var motion := v.motion_profile()
		var scans := 0
		var salvos := 0
		for step in 300:
			foe.gone = step % 90 >= 60
			var target := PackedVector3Array() if foe.gone else PackedVector3Array([foe.position])
			var worth := foe is Vehicle
			if foe is Soldier:
				var n := 0
				for s in w.soldiers:
					if s.team == foe.team and s.life == Soldier.Life.ALIVE: n += 1
				worth = n >= 3
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			w.time += dt
			v._gunship_tick(dt)
			var scan: int = core.gunship_begin(dt)
			assert(scan >= 0)
			scans += scan
			assert(core.gunship_guidance(dt, target, p, w.terrain._native, PackedByteArray()))
			assert(core.turret_tick(0 if foe.gone else foe.eid, foe.position, dt, true, motion.traverse, motion.traverse_accel))
			var due: int = core.gunship_rockets_due(target, worth, int(v.vdef.get("rockets", 4)))
			assert(due >= 0)
			salvos += due
			assert(v.scans == scans and v.salvos == salvos and v.fire_calls == step + 1)
			compare_flight(v, core, "gunship %d/%d" % [trial, step])
			if due: observed["rocket"] = true
			if foe.gone: observed["lost_target"] = true
			if not worth: observed["sparse_infantry"] = true
			if step % 43 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
		var infantry := foe is Soldier
		for s in w.soldiers: s.free()
		if not infantry: foe.free()
		w.soldiers.clear()
		w.entities.clear()
		v.free()
	for key in ["rocket", "lost_target", "sparse_infantry"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_GUNSHIP passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
