extends "res://tests/fixtures/vehicle-driving.gd"

class DamageWorld extends ActorWorld:
	var trace := []
	var messages := []
	func fx_event(event: Array) -> void:
		trace.append(["fx", event])
		super.fx_event(event)
	func send_msg(team: int, kind: String, text: String, ping = null) -> void:
		messages.append([team, kind, text, ping])

class Victim extends Carrier:
	func take_damage(amount: float, source) -> void:
		(world as DamageWorld).trace.append(["damage", amount, source == null])
		# Destruction can draw before a ricochet. Make incorrect sequencing observable.
		for _i in 4:
			world.rng.randf()

class Casualty extends Carrier:
	var destructions := 0
	func _destroyed() -> void:
		destructions += 1

func armor(v: Vehicle) -> Array:
	return [PackedInt32Array([v.vdef.armor, int(v.is_heli()), int(v.is_boat()), int(v.base() == "supply")]), float(v._toss_class()[0])]

func blast_input(p: Vector3, d: Dictionary) -> Array:
	return [p, float(d.get("size", 1.0)), float(d.get("at", 0.0)), PackedVector3Array([d.dir]) if d.has("dir") else PackedVector3Array(),
		bool(d.get("top", false)), float(d.get("track", 0.3)), float(d.get("radius", 5.0)), float(d.get("dmg", 100.0)), float(d.get("veh_mult", 1.0))]

func damage(trace: Array, amount: float, no_source: bool, random: RefCounted) -> void:
	trace.append(["damage", amount, no_source])
	for _i in 4:
		random.randf()

func compare_trace(actual: Array, expected: Array, label: String) -> void:
	assert(actual.size() == expected.size(), label + " event count")
	for i in actual.size():
		if actual[i][0] == "fx" and actual[i][1][0] == Fx.RICOCHET:
			assert(expected[i][0] == "fx" and expected[i][1][0] == Fx.RICOCHET, label)
			assert(actual[i][1][1].distance_to(expected[i][1][1]) < 0.0001, label)
			assert(actual[i][1][2].distance_to(expected[i][1][2]) < 0.0001, label)
		else:
			assert(actual[i] == expected[i], "%s event=%d %s / %s" % [label, i, actual[i], expected[i]])

func _ready() -> void:
	var w := DamageWorld.new()
	w.srv = true
	w.has_view = false
	w.time = 31.7
	add_child(w)
	var source := make_soldier(w, 9, 1)
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	var kinds := Defs.VEHICLES.keys()
	checks = 0
	var observed := {}
	for trial in 1056:
		for op in 2:
			w.trace.clear()
			w.effects.clear()
			w.stats.clear()
			w.rng.seed = trial + 137
			random.set_seed(trial + 137)
			var v := Victim.new()
			v.world = w
			v.srv = true
			v.eid = 7
			v.team = 0
			v.vkind = kinds[trial % kinds.size()]
			v.vdef = Defs.VEHICLES[v.vkind]
			v.hp = v.vdef.hp
			v.max_hp = v.vdef.hp
			v.position = Vector3(0.3, 5.0 if trial % 3 == 0 else 0.0, 1.7)
			v.rotation.y = trial * 0.37
			v.track_broken = trial % 5 == 0
			w.add_child(v)
			assert(core.load_state(VehicleState.capture(v)))
			var p := armor(v)
			var trace := []
			var stats := {}
			if op == 0:
				var weapon := {"dmg": 37.3, "ap": trial % 2 == 0, "aa": trial % 3 == 1}
				var impact := v.position + Vector3(0.7, 0.8, -0.3) if trial % 7 else v.position
				var dir := Vector3(0.3, 0.1, -0.7).normalized()
				var amount: PackedFloat64Array = core.bullet_damage(p, weapon.dmg, weapon.ap, weapon.aa)
				assert(amount.size() == 1)
				if int(v.vdef.armor) < 2 or weapon.ap:
					damage(trace, amount[0], int(v.vdef.armor) >= 2, random)
				var bounce: Array = core.bullet_ricochet(p, impact, dir, random)
				assert(bounce.size() == 1)
				if not bounce[0].is_empty():
					trace.append(["fx", [Fx.RICOCHET, impact, bounce[0][0]]])
					stats["ricochet"] = 1
					observed["ricochet"] = true
				assert(v.bullet_hit(impact, dir, weapon, source) == 3)
			else:
				var d := {"at": 0.0 if trial % 3 == 0 else 320.0, "size": [0.7, 1.2, 2.1, 4.3][trial % 4], "top": trial % 5 == 1, "track": 0.7,
					"radius": 5.5, "dmg": 137.3, "veh_mult": 0.8, "src": source}
				if trial % 2:
					d["dir"] = Defs.dir_of(trial * 0.53)
				var hit_pos: Vector3 = v.position + Defs.dir_of(trial * 0.73) * [0.0, 2.2, 4.5, 8.3][trial % 4]
				var hit: PackedFloat64Array = core.explosion_hit(w.time, p, blast_input(hit_pos, d), random)
				assert(hit.size() == 4)
				if hit[1]:
					stats["at_hit"] = 1
				if hit[2]:
					stats["at_bounce"] = 1
					trace.append(["fx", [Fx.RICOCHET, hit_pos, Vector3.UP]])
					observed["at_bounce"] = true
				if hit[3]:
					stats["track_broken"] = 1
					trace.append(["fx", [Fx.DEBRIS, v.position + Vector3(0, 0.5, 0), Color(0.1, 0.1, 0.1), 8]])
					observed["track"] = true
				if hit[0] > 0.0:
					damage(trace, hit[0], false, random)
				v.explosion_hit(hit_pos, d)
			compare_motion(v, core, "%d/%d" % [trial, op])
			assert(random.get_state() == w.rng.state, "Damage random cursor %d/%d" % [trial, op])
			compare_trace(trace, w.trace, "%d/%d" % [trial, op])
			assert(w.stats == stats, "Damage stats %d/%d: %s / %s" % [trial, op, w.stats, stats])
			v.free()
		var v := Casualty.new()
		v.world = w
		v.srv = true
		v.eid = 7
		v.team = 0
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = 100.0
		v.max_hp = 100.0
		v.position = Vector3(3, 0, 7)
		w.add_child(v)
		assert(core.load_state(VehicleState.capture(v)))
		for i in 5:
			w.messages.clear()
			var before := v.destructions
			var applied := v.hp > 0.0
			var amount: float = [0.0, 37.0, 60.0, 51.0, 99.0][i]
			var result: PackedByteArray = core.take_damage(amount, w.time, v.is_auto())
			v.take_damage(amount, null)
			assert(result == PackedByteArray([int(applied), int(not w.messages.is_empty()), int(v.destructions > before)]))
			compare_motion(v, core, "hp %d/%d" % [trial, i])
		v.free()
	for key in ["ricochet", "at_bounce", "track"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_DAMAGE passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
