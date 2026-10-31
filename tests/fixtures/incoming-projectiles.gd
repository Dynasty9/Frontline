extends "res://tests/fixtures/grenade-attack.gd"


func busy_reference(s: Soldier) -> bool:
	for g: Projectile in s.world.projectiles:
		if g.ptype != "frag" or g.held_by != null:
			continue
		var d := Defs.flat(g.position - s.position).length()
		if d > 7.5 or s.seen_grenades.has(g.eid):
			continue
		if g.flying and g.fuse > 2.2 and d > 4.0:
			continue
		if s.seen_grenades.size() > 24:
			s.seen_grenades.clear()
		s.seen_grenades[g.eid] = true
		s.say(s._pick(["GRENADE!", "Grenade! Get down!", "Frag!"]), true)
		s._dive_from(g.position)
		return true
	return false


func _ready() -> void:
	assert(ClassDB.class_exists("GrenadeReactionCore"))
	var worlds := [attack_world(false), attack_world(true)]
	for w in worlds:
		for id in range(100, 110):
			register(w, Round.new(), id)
			w.projectiles.append(w.entity(id))
	var dives := 0
	for trial in 2048:
		for w in worlds:
			w.rng.seed = trial + 389
			w.time = 10.0
			w.stats.clear()
			w.spoken.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3.ZERO
			s.rotation = Vector3.ZERO
			s.act = Soldier.Act.IDLE
			s.posture = Soldier.Post.STAND
			s.suppression = float(trial % 90)
			s.hit_dirt_t = 0.0
			s.say_cd = 1.0 if trial % 2 else 0.0
			s.dive_t = 0.0
			s.dive_dir = Vector3.ZERO
			s.at_cover = true
			s.peek_up = true
			s.path = PackedVector3Array([Vector3(20, 0, 20)])
			s.path_i = 0
			s.bt_g = w.entity(100)
			s.seen_grenades.clear()
			if trial % 7 == 0:
				for id in range(200, 265):
					s.seen_grenades[id] = true
			for id in range(100, 110):
				var g: Projectile = w.entity(id)
				g.ptype = "frag" if id < 102 else "mortar"
				var d: float = [0.0, 4.49, 4.5, 7.99, 8.0, 14.0, 14.01, 20.0][(trial + id) % 8]
				g.position = Defs.dir_of(float(trial % 17)) * d
				g.target = g.position + Vector3(0, trial % 3, 0)
				g.shell_t = [1.6, 1.61, 2.2][(trial + id) % 3]
				g.life_t = 0.0
				g.fuse = [1.0, 2.2, 2.3][(trial + id) % 3]
				g.flying = trial % 3 == 0
				g.gone = (trial + id) % 11 == 0
				g.held_by = w.entity(3) if (trial + id) % 13 == 0 else null
		for attempt in 6:
			var results := []
			for wi in 2:
				var w: World = worlds[wi]
				var s: Soldier = w.entity(1)
				var reacted := false
				if trial % 3 == 2:
					reacted = busy_reference(s) if wi == 0 else s._react_grenade()
				if not reacted:
					reacted = s._react_shells(trial % 3 != 0)
				results.append(reacted)
				for g: Projectile in w.projectiles:
					g.life_t += 0.3
					g.fuse -= 0.3
			assert(results[0] == results[1], "Incoming reaction trial=%d step=%d" % [trial, attempt])
			var a: Soldier = worlds[0].entity(1)
			var b: Soldier = worlds[1].entity(1)
			for key in ["act", "posture", "suppression", "hit_dirt_t", "say_cd", "dive_t", "dive_dir", "rotation", "path", "at_cover", "peek_up"]:
				assert(a.get(key) == b.get(key), "Incoming %s trial=%d ref=%s rust=%s" % [key, trial, a.get(key), b.get(key)])
			assert(a.seen_grenades.keys() == b.seen_grenades.keys(), "Incoming memory order")
			assert(eid(a.bt_g) == eid(b.bt_g), "Busy reaction must retain the previous brain target")
			assert(worlds[0].rng.state == worlds[1].rng.state and worlds[0].spoken == worlds[1].spoken, "Incoming random draws and warnings")
			assert(worlds[0].stats == worlds[1].stats, "Incoming counters")
			dives += int(results[0])
			if b._grenade_core:
				var saved: PackedByteArray = b._grenade_core.checkpoint()
				assert(b._grenade_core.restore(saved))
	assert(dives > 100)
	for w in worlds:
		w.free()
	print("INCOMING_PROJECTILES passed steps=12288")
	get_tree().quit()
