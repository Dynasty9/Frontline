extends "res://tests/fixtures/vehicle-driving.gd"

class GunWorld extends ActorWorld:
	var shots := []
	func shot(kind: int, target: Entity) -> void:
		shots.append([kind, target.eid])
		# Shot damage can consume randomness before burst recovery or the next weapon choice.
		for _i in 4:
			rng.randf()

class GunCombat extends Combat:
	func fire_bullet(_shooter: Entity, _muzzle: Vector3, _aim: Vector3, target: Entity, _weapon: Dictionary, _accm := 1.0) -> void:
		(world as GunWorld).shot(4, target)

class Gunner extends Carrier:
	func _launch(kind: String, t: Entity) -> void:
		(world as GunWorld).shot(1 if kind == "sam" else 2, t)
		last_fire_t = world.time
	func _fire_cannon() -> void:
		(world as GunWorld).shot(3, target)
		last_fire_t = world.time

class Building extends Structure:
	func _ready() -> void:
		set_process(false)

func fire_profile(v: Vehicle) -> Array:
	var w: Dictionary = Defs.WEAPONS.get(String(v.vdef.mg), {})
	var burst: Vector2i = w.get("burst", Vector2i(1, 1))
	return [v.base(), bool(v.vdef.cannon), int(v.vdef.armor), String(v.vdef.mg), PackedInt32Array([burst.x, burst.y]),
		PackedFloat64Array([float(w.get("interval", 0.1)), float(v.vdef.get("gun", {}).get("cd", 5.5)), float(v.vdef.get("sam", [0, 0])[1]),
		float(v.vdef.get("sam_range", 160.0)), float(v.vdef.get("atgm", [0, 0])[1]), float(v.vdef.get("atgm_range", 125.0))])]

func fire_target(v: Vehicle) -> Array:
	if not v._target_ok():
		return []
	var t := v.target
	if t is Soldier:
		var count := 0
		for o in v.world.soldiers_near(t.position, 5.0):
			if o.team == t.team and o.life == Soldier.Life.ALIVE:
				count += 1
		return [t.position, 0, PackedInt32Array([count, int(t.rockets > 0), int(t.mounted != null)])]
	if t is Vehicle:
		return [t.position, 1, PackedInt32Array([int(t.is_air()), int(t.vdef.armor)])]
	if t is Structure:
		return [t.position, 2, PackedInt32Array([int(t.skind in ["bunker", "mg_nest", "hmg_nest", "at_post", "watchtower"])])]
	return [t.position, 3, PackedInt32Array()]

func _ready() -> void:
	var w := GunWorld.new()
	w.has_view = false
	w.srv = true
	w.combat = GunCombat.new(w)
	add_child(w)
	var troop := make_soldier(w, 20, 1)
	var buddy := make_soldier(w, 21, 1)
	w.soldiers = [troop, buddy]
	var tank := Carrier.new()
	tank.world = w
	tank.eid = 22
	tank.team = 1
	tank.vkind = "tank"
	tank.vdef = Defs.VEHICLES.tank
	w.add_child(tank)
	var heli := Carrier.new()
	heli.world = w
	heli.eid = 23
	heli.team = 1
	for key in Defs.VEHICLES:
		if Defs.VEHICLES[key].get("air", false):
			heli.vkind = key
			heli.vdef = Defs.VEHICLES[key]
			break
	w.add_child(heli)
	var building := Building.new()
	building.world = w
	building.eid = 24
	building.team = 1
	w.add_child(building)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var kinds := Defs.VEHICLES.keys()
	checks = 0
	var observed := {}
	for trial in 264:
		var v := Gunner.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp
		v.max_hp = v.vdef.hp
		v.rearm()
		v.cannon_t = 0.0
		w.add_child(v)
		w.rng.seed = trial + 137
		random.set_seed(trial + 137)
		assert(core.load_state(VehicleState.capture(v)))
		var p := fire_profile(v)
		for step in 80:
			w.time = 31.7 + step * 0.5
			w.shots.clear()
			var dist: float = [21.9, 40.3, 69.9, 90.0, 124.9, 159.9][(trial + step) % 6]
			var pos := Vector3(5.0 if trial % 11 == 0 else 0.0, 0, -dist)
			troop.position = pos
			troop.rockets = int(step % 5 == 0)
			troop.mounted = building if step % 5 == 1 else null
			troop.life = Soldier.Life.DOWNED if step % 13 == 0 else Soldier.Life.ALIVE
			buddy.position = pos + Vector3(1 if step % 3 == 0 else 10, 0, 0)
			tank.position = pos
			heli.position = pos + Vector3(0, 5, 0)
			building.position = pos
			building.skind = "bunker" if step % 2 == 0 else "house"
			v.target = [troop, tank, heli, building, troop, null][step % 6]
			v.cannon_t -= 0.5
			v.mg_t -= 0.5
			v._aim_time = 0.29 if step % 7 == 0 else 0.3
			w._rebuild_uhash()
			var state: Array = core.values()
			state[0][2] = v.target.eid if v.target else 0
			state[2][9] -= 0.5
			state[2][10] -= 0.5
			state[2][6] = v._aim_time
			assert(core.load_state(state))
			var shot: int = core.choose_weapon(w.time, p, fire_target(v), random)
			assert(shot >= 0)
			if shot:
				for _i in 4:
					random.randf()
			assert(core.finish_weapon(shot, w.time, p, random))
			v._fire_tick()
			assert(w.shots == ([] if shot == 0 else [[shot, v.target.eid]]), "Weapon %s %d/%d %s / %s" % [v.vkind, trial, step, shot, w.shots])
			observed[shot] = true
			assert(random.get_state() == w.rng.state, "Weapon random cursor %d/%d" % [trial, step])
			compare_motion(v, core, "weapon %d/%d" % [trial, step])
			if step % 13 == 0:
				var saved: PackedByteArray = core.checkpoint()
				assert(core.restore(saved) and core.checkpoint() == saved)
		v.free()
	for code in 5:
		assert(observed.has(code), "Fixture must exercise weapon " + str(code))
	w.free()
	print("VEHICLE_WEAPON passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
