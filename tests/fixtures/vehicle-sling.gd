extends "res://tests/fixtures/vehicle-driving.gd"

class Load extends Carrier:
	var damage := []
	func take_damage(amount: float, _source) -> void:
		# Transport requests damage; the vehicle combat dispatcher applies it separately.
		damage.append(amount)

func sling_spec(h: Vehicle, v: Vehicle) -> PackedInt32Array:
	return PackedInt32Array([int(h.base() == "lift_heli"), int(h.vdef.get("sling", -1)), v.weight(), int(v.is_heli()), int(v.is_boat()), int(v.is_auto())])

func vehicle_bytes(v: Vehicle, core: RefCounted) -> PackedByteArray:
	assert(core.load_state(VehicleState.capture(v)))
	return core.checkpoint()

func compare_owned(v: Vehicle, actors: RefCounted, core: RefCounted, label: String) -> void:
	assert(core.restore(actors.actor_state(v.eid)))
	compare_motion(v, core, label)

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
	for z in Nav.N:
		for x in Nav.N:
			var solid := x < 3 or z < 3 or x >= Nav.N - 3 or z >= Nav.N - 3 or (x in range(31, 33) and z in range(29, 35))
			w.nav.vkind[z * Nav.N + x] = Nav.SOLID if solid else Nav.FREE
			w.nav.veh.set_point_solid(Vector2i(x, z), solid)
	assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var kinds := []
	for kind in Defs.VEHICLES:
		if Defs.VEHICLES[kind].get("base", "") == "lift_heli" and int(Defs.VEHICLES[kind].get("sling", -1)) >= 0:
			kinds.append(kind)
	checks = 0
	var observed := {}
	for trial in 96:
		w.stats.clear()
		w.effects.clear()
		var h := Carrier.new()
		h.world = w
		h.srv = true
		h.eid = 1
		h.team = 0
		h.vkind = kinds[trial % kinds.size()]
		h.vdef = Defs.VEHICLES[h.vkind]
		h.hp = h.vdef.hp
		h.max_hp = h.vdef.hp
		h.position = Vector3(trial % 9 - 4, 10 if trial % 5 == 3 else 16, trial % 6 - 3)
		h.velocity = Vector3(2.1, 0, -3.7)
		h.rotation.y = trial * 0.37
		w.add_child(h)
		var v := Load.new()
		v.world = w
		v.srv = true
		v.eid = 2
		v.team = 1 if trial % 17 == 0 else 0
		v.vkind = ["tank", "technical", "ifv", "truck"][trial % 4]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.rotation.y = trial * 0.31
		v.path = PackedVector3Array([Vector3(20, 0, 3)])
		v.path_pending = trial % 3 == 0
		v._path_revision = 17 + trial
		v.speed = 3.0
		v.velocity = Vector3(3, 0, 0)
		v.assault = true
		w.add_child(v)
		assert(actors.load_state(3, PackedByteArray([2, 2]), [vehicle_bytes(h, core), vehicle_bytes(v, core)]))
		var p := sling_spec(h, v)
		var allowed := h.can_sling(v)
		assert(actors.can_sling(1, 2, p) == int(allowed))
		h.order_sling(v)
		assert(actors.order_sling(1, 2, p) == int(allowed))
		compare_owned(h, actors, core, "order %d" % trial)
		compare_owned(v, actors, core, "waiting cargo %d" % trial)
		if allowed:
			h._hook(v)
			assert(actors.hook_sling(1, 2, p) == 1)
			for step in 120:
				var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
				h._sling_tick(dt)
				assert(actors.step_sling(1, dt, v._hull_size().y) == 1)
				compare_owned(h, actors, core, "carrier %d/%d" % [trial, step])
				compare_owned(v, actors, core, "cargo %d/%d" % [trial, step])
				if step % 23 == 0:
					var saved: PackedByteArray = actors.checkpoint()
					assert(actors.restore(saved) and actors.checkpoint() == saved)
			var saved: PackedByteArray = actors.checkpoint()
			assert(actors.step_sling(1, NAN, v._hull_size().y) == -1)
			assert(actors.checkpoint() == saved)
			if trial % 3 == 0:
				h._release_sling()
				assert(actors.release_sling(1, w.nav._planner) == 2)
				compare_owned(h, actors, core, "released helicopter %d" % trial)
				compare_owned(v, actors, core, "released cargo %d" % trial)
				observed["delivered"] = true
			elif trial % 3 == 1:
				v.gone = true
				assert(actors.remove(2))
				h._sling_tick(0.1)
				assert(actors.step_sling(1, 0.1, v._hull_size().y) == 0)
				compare_owned(h, actors, core, "removed cargo %d" % trial)
				observed["removed"] = true
			else:
				h.gone = true
				assert(actors.remove(1))
				var dropped: Array = actors.drop_sling(2, w.nav._planner)
				assert(dropped.size() == 3)
				v._drop_from_sling()
				compare_owned(v, actors, core, "dropped cargo %d" % trial)
				assert(dropped[0] == v.position)
				assert(v.damage == [float(dropped[1])] if dropped[2] else v.damage.is_empty())
				assert(w.effects.size() == (2 if dropped[2] else 0))
				if dropped[2]:
					assert(w.effects[0][0] == Fx.DEBRIS and w.effects[1] == [Fx.SOUND, "thud", v.position])
				observed["dropped"] = true
				observed["impact" if dropped[2] else "gentle"] = true
		else:
			observed["rejected"] = true
		h.free()
		v.free()
	for key in ["delivered", "removed", "dropped", "rejected", "impact", "gentle"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_SLING passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
