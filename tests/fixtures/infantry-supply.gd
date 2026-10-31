extends "res://tests/fixtures/infantry-grenades.gd"

class SupplyScene extends GrenadeScene:
	func structures_near(p: Vector3, radius: float, _floors := false) -> Array:
		var result := []
		for e: Entity in entities.values():
			if e is Structure and not e.gone and Defs.flat(e.position - p).length() <= radius + 3.0:
				result.append(e)
		return result

class SuppliedSoldier extends ShotSoldier:
	func go_to(p: Vector3, kind: String, mode: int) -> void:
		world.effects.append(["move", p, kind, mode, world.rng.state])
		world.rng.randi()
		goal = p
		goal_kind = kind
		move_mode = mode

class SupplyRules extends Rules:
	func nearest_fob(_team: int, _pos: Vector3) -> Structure:
		world.effects.append(["fob_query", world.entity(1).resupply_t, world.rng.state])
		return world.entity(20) if world.trial % 5 else null


func supply_world(native: bool) -> SupplyScene:
	var w := SupplyScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.rules = SupplyRules.new(w)
	add_child(w)
	register(w, SuppliedSoldier.new(), 1)
	for id in [3, 4, 5]:
		register(w, ShotSoldier.new(), id)
	for id in [20, 21, 22]:
		register(w, ShotWall.new(), id)
	return w


func _ready() -> void:
	assert(ClassDB.class_exists("InfantrySupplyCore"))
	var worlds := [supply_world(false), supply_world(true)]
	var destinations := {}
	var scavenged := 0
	for trial in 4096:
		for w in worlds:
			w.trial = trial
			w.time = 10.0
			w.rng.seed = trial + 991
			w.stats.clear()
			w.spoken.clear()
			w.effects.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3(float(trial % 7) * 0.7, 0, float(trial % 9) * 0.3)
			s.team = trial % 2
			s.wdef = {"ammo": 9000 if trial % 19 == 0 else 31 + trial % 150, "mag": 10, "reload": 1.7}
			if trial % 23 == 0:
				s.wdef = {}
			s.udef = {"frags": 2, "smokes": 1, "rockets": 3, "drones": 2, "mortar": 5}
			s.gun_override = {"ammo": 150, "mag": 90, "reload": 3.1} if trial % 13 == 0 else {}
			s.mag = 0 if trial % 3 == 0 else trial % 15
			s.reserve = trial % 100
			s.frags = trial % 4
			s.smokes = trial % 3
			s.rockets = trial % 5
			s.drones_left = trial % 4
			s.mortar_rounds = trial % 7
			s.scav_t = 11.0 if trial % 7 == 0 else 0.0
			s.resupply_t = 11.0 if trial % 11 == 0 else 0.0
			s.reload_t = 2.0 if trial % 17 == 0 else 0.0
			s.burst_left = 3
			s.low_ammo_said = true
			s.out_said = true
			s.say_cd = 1.0 if trial % 2 else 0.0
			s.task = ""
			s.task_ent = null
			s.goal = Vector3.ZERO
			s.goal_kind = ""
			s.move_mode = 0
			w.rules.upgrades = [{}, {}]
			if trial % 2:
				w.rules.upgrades[s.team]["grenades"] = true
			for id in [3, 4, 5]:
				var b: Soldier = w.entity(id)
				b.position = s.position + Vector3([1.0, 3.2, 24.99, 25.0, 30.0][(trial + id) % 5], 0, 0)
				b.life = Soldier.Life.DEAD if (trial + id) % 3 == 0 else Soldier.Life.DOWNED
				b.loot = (trial + id) % 40
			for id in [20, 21, 22]:
				var st: Structure = w.entity(id)
				st.position = Vector3([20.0, 50.0, 70.0, 72.0, 89.99, 90.0][(trial + id) % 6], 0, float((trial + id) % 5))
				st.skind = "fob" if id == 20 else ("ammo_cache" if (trial + id) % 3 else "house")
				st.team = (trial + id) % 2
				st.built = (trial + id) % 7 != 0
				st.gone = (trial + id) % 11 == 0
		for attempt in 4:
			for w in worlds:
				w.time += [0.0, 1.5, 6.0, 10.0][attempt]
				var s: Soldier = w.entity(1)
				s._scavenge()
				var result := s._seek_resupply()
				w.effects.append(["found", result])
				s.resupply([0.0, 1.0 / 30.0, 0.5, 1.0, 10.0][trial % 5])
			var a: Soldier = worlds[0].entity(1)
			var b: Soldier = worlds[1].entity(1)
			for key in ["mag", "reserve", "frags", "smokes", "rockets", "drones_left", "mortar_rounds", "scav_t", "resupply_t", "reload_t", "burst_left", "out_said", "low_ammo_said", "say_cd", "task", "goal", "goal_kind", "move_mode"]:
				assert(a.get(key) == b.get(key), "Supply %s trial=%d attempt=%d ref=%s rust=%s" % [key, trial, attempt, a.get(key), b.get(key)])
			assert(eid(a.task_ent) == eid(b.task_ent), "Supply destination")
			destinations[eid(a.task_ent)] = true
			for id in [3, 4, 5]:
				assert(worlds[0].entity(id).loot == worlds[1].entity(id).loot, "Shared corpse ammunition")
			assert(worlds[0].rng.state == worlds[1].rng.state, "Supply random cursor")
			assert(worlds[0].spoken == worlds[1].spoken and worlds[0].effects == worlds[1].effects and worlds[0].stats == worlds[1].stats, "Supply callback order")
			if b._supply:
				var bytes: PackedByteArray = b._supply.checkpoint()
				assert(b._supply.restore(bytes))
		scavenged += int(worlds[0].stats.get("scavenge", 0))
	assert(scavenged > 100 and destinations.size() >= 5, "Scavenge, body, cache and FOB paths must execute")
	for w in worlds:
		w.free()
	print("INFANTRY_SUPPLY passed steps=16384")
	get_tree().quit()
