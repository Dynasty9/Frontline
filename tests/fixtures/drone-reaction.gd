extends "res://tests/fixtures/infantry-grenades.gd"


func reaction_world(native: bool) -> ShotScene:
	var w := ShotScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	register(w, ShotSoldier.new(), 1)
	for id in range(100, 120):
		register(w, ShotDrone.new(), id)
		w.drones.append(w.entity(id))
	return w


func _ready() -> void:
	assert(ClassDB.class_exists("DroneReactionCore"))
	var worlds := [reaction_world(false), reaction_world(true)]
	var dives := 0
	var warnings := 0
	for trial in 4096:
		for w in worlds:
			w.rng.seed = trial + 337
			w.stats.clear()
			w.effects.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3.ZERO
			s.team = trial % 2
			s.rotation = Vector3.ZERO
			s.act = Soldier.Act.IDLE
			s.posture = Soldier.Post.STAND
			s.dive_t = 0.0
			s.dive_dir = Vector3.ZERO
			s.say_cd = 1.0 if trial % 2 else 0.0
			s.at_cover = true
			s.peek_up = true
			s.path = PackedVector3Array([Vector3(20, 0, 20)])
			s.path_i = 0
			s.heard_drones.clear()
			if trial % 5 == 0:
				for id in range(200, 217):
					s.heard_drones[id] = true
			elif trial % 7 == 0:
				s.heard_drones[100] = true
			for id in range(100, 120):
				var d: Drone = w.entity(id)
				var radius: float = [0.0, 8.99, 9.0, 44.99, 45.0, 45.01][(trial + id) % 6]
				d.position = Vector3(radius, (trial + id) % 3, 0)
				d.target_pos = Vector3([0.0, 5.49, 5.5][(trial + id) % 3], 200, 0)
				d.team = (trial + id) % 2
				d.dead = (trial + id) % 11 == 0
				d.diving = (trial + id) % 3 != 0
		for attempt in 5:
			for w in worlds:
				var s: Soldier = w.entity(1)
				s._react_drones()
				for d: Drone in w.drones:
					d.position.x -= 0.3
			var a: Soldier = worlds[0].entity(1)
			var b: Soldier = worlds[1].entity(1)
			for key in ["act", "posture", "say_cd", "dive_t", "dive_dir", "rotation", "path", "at_cover", "peek_up"]:
				assert(a.get(key) == b.get(key), "Drone reaction %s trial=%d attempt=%d ref=%s rust=%s" % [key, trial, attempt, a.get(key), b.get(key)])
			assert(a.heard_drones.keys() == b.heard_drones.keys(), "Drone hearing order")
			assert(worlds[0].rng.state == worlds[1].rng.state, "Drone random draws")
			assert(worlds[0].effects == worlds[1].effects and worlds[0].stats == worlds[1].stats, "Drone warnings and dive counters")
			var saved: PackedByteArray = b._drone_reaction.checkpoint()
			assert(b._drone_reaction.restore(saved))
			assert(not b._drone_reaction.restore(saved.slice(0, saved.size() - 1)))
			assert(b._drone_reaction.checkpoint() == saved)
		dives += int(worlds[0].stats.get("dive", 0))
		warnings += worlds[0].effects.size()
	assert(dives > 100 and warnings > 1000, "Both warnings and dives must execute")
	for w in worlds:
		w.free()
	print("DRONE_REACTION passed steps=20480")
	get_tree().quit()
