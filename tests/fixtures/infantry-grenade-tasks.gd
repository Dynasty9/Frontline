extends "res://tests/fixtures/infantry-grenades.gd"


func compare_task(a: Soldier, b: Soldier, label: String) -> void:
	for key in ["position", "rotation"]:
		assert((a.get(key) as Vector3).distance_to(b.get(key)) < 0.00001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["task", "posture", "act", "at_cover", "peek_up", "hit_dirt_t", "dive_t", "dive_dir", "path", "act_kind", "act_t", "stamina"]:
		assert(a.get(key) == b.get(key), "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	assert(eid(a.task_ent) == eid(b.task_ent), "Task target " + label)
	assert(a.world.rng.state == b.world.rng.state and a.world.stats == b.world.stats, "Task random draws " + label)
	for key in ["pos", "v", "kind", "fuse"]:
		assert(a.act_data.get(key) == b.act_data.get(key), "Action data " + label)
	assert(eid(a.act_data.get("g")) == eid(b.act_data.get("g")), "Action grenade " + label)
	var ga: Projectile = a.world.entity(20)
	var gb: Projectile = b.world.entity(20)
	for key in ["position", "vel", "flying", "thrown_back", "team", "thrower_id"]:
		assert(ga.get(key) == gb.get(key), "%s projectile %s" % [label, key])
	assert(eid(ga.held_by) == eid(gb.held_by), "Grenade holder " + label)


func _ready() -> void:
	assert(ClassDB.class_exists("GrenadeReactionCore"))
	Nav.N = 64
	Nav.H = 32.0
	var worlds := [grenade_world(false), grenade_world(true)]
	for w in worlds:
		w.nav = Nav.new()
		for z in Nav.N:
			for x in Nav.N:
				w.nav.ikind[z * Nav.N + x] = Nav.SOLID if x % 7 == 0 else Nav.FREE
		w.nav.finalize()
	var outcomes := {}
	var checks := 0
	for trial in 384:
		for w in worlds:
			w.time = 0.0
			w.rng.seed = 913 + trial
			w.stats.clear()
			w.spoken.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3(trial % 7 - 3, 0.0, (trial / 7) % 7 - 3)
			s.rotation.y = float(trial % 20) * 0.13
			s.life = Soldier.Life.ALIVE
			s.team = 0
			s.task = ["smother", "gkick", "grenade_pickup"][trial % 3]
			s.task_t = 0.0
			s.task_ent = w.entity(20) if trial % 13 != 0 else null
			s.act = Soldier.Act.IDLE
			s.act_t = 0.0
			s.act_kind = ""
			s.act_data = {}
			s.posture = trial % 5
			s.dive_t = 0.0
			s.dive_dir = Vector3.ZERO
			s.hit_dirt_t = 0.0
			s.at_cover = true
			s.peek_up = true
			s.stamina = 1.0
			s.squad = null
			s.path = PackedVector3Array()
			s.mounted = null
			if trial % 11 == 0:
				var mount: Structure = w.entity(10)
				mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][(trial / 11) % 4]
				mount.position += s.position - mount.mount_pos()
				s.mounted = mount
			var g: Projectile = w.entity(20)
			g.ptype = "frag"
			g.position = s.position + Vector3(0.4 + (trial % 8) * 0.7, 0.1, 0.2)
			g.fuse = [0.3, 0.5, 0.8, 2.0, 4.0][(trial / 3) % 5]
			g.gone = false
			g.flying = false
			g.vel = Vector3.ZERO
			g.held_by = s if trial % 17 == 0 else (w.entity(7) if trial % 19 == 0 else null)
			g.smothered_by = s if trial % 3 == 0 else null
			g.thrown_back = 0
			g.team = 1
			g.thrower_id = 7
		for tick in 120:
			for w in worlds:
				var s: Soldier = w.entity(1)
				var g: Projectile = w.entity(20)
				var dt: float = [1.0 / 30.0, 0.02, 0.08][(trial / 3) % 3]
				w.time += dt
				g.fuse -= dt
				g.gone = g.fuse <= 0.0
				match s.task:
					"smother": SoldierBrain.smother_tick(s, dt)
					"gkick": SoldierBrain.gkick_tick(s, dt)
					"grenade_pickup": s._gpick_tick(dt)
					_:
						if s.act_t > 0.0:
							s.act_t -= dt
							s._action_tick(dt)
							if s.act_t <= 0.0:
								s._action_done()
						elif s.dive_t > 0.0:
							s._alive(dt)
				outcomes[s.act] = true
			compare_task(worlds[0].entity(1), worlds[1].entity(1), "trial=%d tick=%d" % [trial, tick])
			var s: Soldier = worlds[1].entity(1)
			var g: Projectile = worlds[1].entity(20)
			var covered := Defs.flat(s.position + Defs.dir_of(s.rotation.y) * 0.75 - g.position).length() <= 0.9
			assert(SoldierBrain._core(s).covers_grenade(s.position, s.rotation.y, g.position) == covered, "Covering pose")
			checks += 1
		for w in worlds:
			var s: Soldier = w.entity(1)
			s._dive_from(s.position)
		compare_task(worlds[0].entity(1), worlds[1].entity(1), "Dive at origin")
	for action in [Soldier.Act.SMOTHER, Soldier.Act.DIVE, Soldier.Act.KICK, Soldier.Act.PICKUP, Soldier.Act.RUN]:
		assert(outcomes.has(action), "Missing grenade task action %d" % action)
	for w in worlds:
		w.free()
	print("INFANTRY_GRENADE_TASKS passed steps=%d" % checks)
