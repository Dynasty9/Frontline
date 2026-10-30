extends "res://tests/fixtures/infantry-grenades.gd"


func attack_world(native: bool) -> GrenadeScene:
	var w := GrenadeScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for id in [1, 3, 4, 5, 6, 7]:
		register(w, ShotSoldier.new(), id)
	return w


func _ready() -> void:
	assert(ClassDB.class_exists("GrenadeAttackCore"))
	var worlds := [attack_world(false), attack_world(true)]
	var outcomes := {}
	var checks := 0
	for trial in 4096:
		for w in worlds:
			w.time = 10.0
			w.rng.seed = trial + 2291
			w.stats.clear()
			w.spoken.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3.ZERO
			s.rotation.y = 0.0
			s.frags = trial % 5
			s.grenade_cd = 11.0 if trial % 7 == 0 else 0.0
			s.suppression = float(trial % 90)
			s.team = trial % 2
			s.act_kind = ""
			s.act_t = 0.0
			s.act_data.clear()
			s._queued_throw.clear()
			s.say_cd = 0.0
			s.act = Soldier.Act.IDLE
			s.task = ""
			s.path = PackedVector3Array([Vector3(20, 0, 20)]) if trial % 11 == 0 else PackedVector3Array()
			s.path_i = 0
			s.goal_kind = ""
			s.squad = Squad.new() if trial % 13 else null
			s.vis_targets.clear()
			if s.squad:
				s.squad.world = w
				s.squad.ambush = trial % 17 == 0
			for id in range(3, 8):
				var e: Soldier = w.entity(id)
				e.position = Vector3(7.0 + trial % 24 + (id - 3) * 0.6, 0, (id - 5) * 0.5)
				e.life = Soldier.Life.DOWNED if (trial + id) % 5 == 0 else Soldier.Life.ALIVE
				e.team = s.team if (trial + id) % 11 == 0 else 1 - s.team
				e.gone = (trial + id) % 19 == 0
				e.posture = (trial + id) % 5
				e.at_cover = (trial + id) % 3 == 0
				e.cover_mat = (trial + id) % 4
				if (trial + id) % 3 == 0:
					s.vis_targets.append(e)
				if s.squad:
					s.squad.known[id] = {"e": e, "t": w.time - float((trial + id) % 8)}
		for attempt in 3:
			var results := []
			for w in worlds:
				w.time += [0.0, 3.0, 30.0][attempt]
				var s: Soldier = w.entity(1)
				results.append(s._try_grenade())
				outcomes[s.act_kind] = true
			var a: Soldier = worlds[0].entity(1)
			var b: Soldier = worlds[1].entity(1)
			assert(results[0] == results[1], "Grenade result trial=%d attempt=%d" % [trial, attempt])
			for key in ["frags", "grenade_cd", "rotation", "path", "act", "act_kind", "act_t", "act_data", "_queued_throw"]:
				assert(a.get(key) == b.get(key), "Grenade %s trial=%d ref=%s rust=%s" % [key, trial, a.get(key), b.get(key)])
			assert(worlds[0].rng.state == worlds[1].rng.state, "Grenade attack random cursor")
			assert(worlds[0].stats == worlds[1].stats and worlds[0].spoken == worlds[1].spoken, "Grenade attack effects")
			if b._grenade_attack:
				var bytes: PackedByteArray = b._grenade_attack.checkpoint()
				assert(b._grenade_attack.restore(bytes))
			checks += 1
	for key in ["cook", "throw", ""]:
		assert(outcomes.has(key), "Missing grenade attack outcome " + key)
	for w in worlds:
		var s: Soldier = w.entity(1)
		s.seen_grenades.clear()
		s.say_cd = 0.0
		w.spoken.clear()
		for id in range(100, 165):
			var g := Round.new()
			register(w, g, id)
			g.ptype = "mortar"
			g.target = Vector3(10, 0, 0)
			g.shell_t = 0.5
			g.life_t = 0.0
			w.projectiles.append(g)
		assert(not s._react_shells(true))
		assert(s.seen_grenades.size() == 65)
		assert(not SoldierBrain.grenade_close(s))
		assert(s.seen_grenades.size() == 65, "Mortar history must survive until a new grenade is noticed")
		if s._grenade_core:
			var bytes: PackedByteArray = s._grenade_core.checkpoint()
			assert(s._grenade_core.restore(bytes))
		var frag := Round.new()
		register(w, frag, 20)
		frag.ptype = "frag"
		frag.position = Vector3(2, 0, 0)
		frag.flying = false
		w.projectiles.append(frag)
		assert(SoldierBrain.grenade_close(s))
		assert(s.seen_grenades.keys() == [20])
	assert(worlds[0].rng.state == worlds[1].rng.state and worlds[0].spoken == worlds[1].spoken, "Warnings after a long bombardment")
	for w in worlds:
		w.free()
	print("GRENADE_ATTACK passed decisions=%d mortar_memory=65" % checks)
	get_tree().quit()
