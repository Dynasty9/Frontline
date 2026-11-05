extends "res://tests/fixtures/actors.gd"

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var squad: RefCounted = ClassDB.instantiate("SquadStateCore")
	var random := SimulationRandom.new()
	var total := 0
	for trial in 48:
		var w := ActorWorld.new()
		w.srv = true
		w.has_view = false
		w.settings = {"rust_infantry": false}
		w.rules = Rules.new(w)
		w.rules.upgrades = [{}, {}]
		for team in 2:
			if trial % 2: w.rules.upgrades[team]["armor"] = true
			if trial % 4 >= 2: w.rules.upgrades[team]["grenades"] = true
		add_child(w)
		w.rng.seed = 8317 + trial
		random.seed = 8317 + trial
		assert(actors.load_state(1, PackedByteArray(), []))
		w.next_sid = trial * 47 + 1
		var q := w.new_squad(trial % 2, -1 - trial % 2, "crew" if trial % 2 == 0 else "r_crew")
		assert(squad.create(q.sid, q.team, q.owner, q.kind))
		assert(squad.values() == SquadState.capture(q))
		for kind: String in Defs.UNITS:
			var d: Dictionary = Defs.UNITS[kind]
			var weapon: Dictionary = Defs.WEAPONS.get(d.weapon, {})
			var team := int(d.team)
			var name: String = "Fixed name" if trial % 3 == 0 else w.rules.random_name(team)
			var native_name: String = "Fixed name" if trial % 3 == 0 else actors.soldier_name(PackedStringArray(Defs.NAMES[clampi(team, 0, 1)]), random._backend)
			assert(name == native_name and w.rng.state == random.state, "Name %s/%d: %s / %s, random %d / %d" % [kind, trial, name, native_name, w.rng.state, random.state])
			var props := {"utype": kind, "team": team, "owner": q.owner, "pos": Vector3(total % 7 * 1.7, (total % 3) * 0.15, trial * -0.73),
				"yaw": trial * 0.137 - 3.0, "name": name, "squad": q.sid, "life": trial % 6, "posture": trial % 5, "max_hp": 17.0}
			var s: Soldier = w.spawn("soldier", props)
			assert(is_instance_valid(s))
			var id: int = actors.spawn_infantry([team, q.owner, props.pos, props.yaw, native_name, q.sid, props.life, props.posture,
				w.rules.has_upgrade(team, "armor"), w.rules.has_upgrade(team, "grenades")],
				[kind, InfantryState.weapon_key(weapon), float(d.hp), int(weapon.get("mag", 0)), int(weapon.get("ammo", 0)),
				int(d.frags), int(d.smokes), int(d.get("rockets", 0)), int(d.get("mortar", 0)), int(d.get("drones", 0)), bool(d.get("bearer", false))], random._backend)
			assert(id == s.eid)
			compare_actor(s, actors, "birth %s/%d" % [kind, trial])
			assert(w.rng.state == random.state)
			q.add(s)
			assert(squad.add_member(id, actors))
			q.add(s)
			assert(not squad.add_member(id, actors))
			compare_actor(s, actors, "recruit %s/%d" % [kind, trial])
			assert(squad.values() == SquadState.capture(q))
			assert(actors.restore(actors.checkpoint()))
			assert(squad.restore(squad.checkpoint()))
			total += 2
		w.free()
	assert(total == Defs.UNITS.size() * 48 * 2)
	print("INFANTRY_SPAWN passed states=", total, " kinds=", Defs.UNITS.size())
