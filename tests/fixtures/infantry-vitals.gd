extends Node3D

class Scene extends World:
	var spoken := []
	var effects := []
	var props := []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text])
	func fx_event(event: Array) -> void:
		effects.append(event)
	func push_props(e: Entity, d: Dictionary) -> void:
		props.append([e.eid, d])

class Trooper extends Soldier:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Mount extends Structure:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

var checks := 0
var outcomes := {}
var events := {}


func make_world(native: bool) -> Scene:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	add_child(w)
	return w


func make_soldier(w: Scene, id: int, team_id: int) -> Trooper:
	var s := Trooper.new()
	s.world = w
	s.srv = true
	s.eid = id
	s.team = team_id
	s.owner_peer = -1 - team_id
	s.sname = "Test soldier %d" % id
	s.wdef = Defs.WEAPONS.rifle
	s.udef = Defs.UNITS.rifleman
	s.mag = 7
	s.reserve = 23
	s.position = Vector3(id * 2, 0, 0)
	w.entities[id] = s
	w.add_child(s)
	return s


func observe(a: Soldier, b: Soldier, label: String) -> void:
	for key in ["hp", "max_hp", "base_hp", "suppression", "_supp_t", "reveal_t", "bleed", "bleed_max", "stamina", "say_cd", "hit_dirt_t", "downed_t", "dead_t", "scream_t", "pistol_t", "crawl_t"]:
		assert(absf(float(a.get(key)) - float(b.get(key))) < 0.000000001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["life", "times_downed", "act", "posture", "task", "at_cover", "peek_up", "blind", "mag", "reserve", "loot", "_hit_kind", "_hit_dir", "hit_by", "path", "path_i"]:
		assert(a.get(key) == b.get(key), "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	assert(a.world.rng.state == b.world.rng.state, "Gameplay random cursor " + label)
	assert(a.world.stats == b.world.stats and a.world.spoken == b.world.spoken and a.world.effects == b.world.effects and a.world.props == b.world.props, "Damage events " + label)
	assert(a.world.battle.sides == b.world.battle.sides and a.world.battle.players == b.world.battle.players, "Damage attribution " + label)
	assert(a.squad.morale == b.squad.morale and a.squad.heard == b.squad.heard, "Squad response " + label)
	assert(a.world.entities[3].squad.morale == b.world.entities[3].squad.morale, "Attacker morale " + label)
	outcomes[a.life] = true
	checks += 1


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryVitalsCore"))
	var worlds := [make_world(false), make_world(true)]
	for trial in 384:
		var pair: Array[Soldier] = []
		for w in worlds:
			w.time = 10.0
			w.rng.seed = 371 + trial
			w.spoken.clear()
			w.stats.clear()
			w.effects.clear()
			w.props.clear()
			w.battle = BattleStats.new(w)
			var s := make_soldier(w, 1, trial % 2)
			var buddy := make_soldier(w, 2, trial % 2)
			var foe := make_soldier(w, 3, 1 - trial % 2)
			for man in [s, foe]:
				man.squad = Squad.new()
				man.squad.world = w
				man.squad.kind = "rifle_squad"
				man.squad.morale = 65.0
				man.squad.team = man.team
				man.squad.members = [man]
			s.squad.members.append(buddy)
			s.life = trial % 6
			s.times_downed = (trial / 6) % 5
			s.bleed = 45.0
			s.task = ["", "retreat", "stretcher", "rescue", "smother"][(trial / 7) % 5]
			s.cover_type = trial % 4
			s.cover_mat = (trial / 4) % 5 - 1
			s.at_cover = trial % 3 != 0
			s.peek_up = trial % 5 == 0
			s._gy = -0.8 if trial % 2 else 0.0
			s.utype = "bearer" if trial % 17 == 0 else "rifleman"
			s.udef = s.udef.duplicate()
			s.udef.bearer = trial % 17 == 0
			s.base_hp = 120.0 if trial % 7 == 0 else 100.0
			s.move_mode = (trial / 11) % 3
			s.posture = trial % 3
			s.act = Soldier.Act.CRAWL if trial % 9 == 0 else Soldier.Act.IDLE
			s.path = PackedVector3Array([Vector3(10, 0, 20)]) if trial % 2 == 0 else PackedVector3Array()
			s.hit_dirt_t = 0.4
			if trial % 5 == 0:
				var mount := Mount.new()
				mount.world = w
				mount.skind = "watchtower" if trial % 10 == 0 else "mg_nest"
				w.add_child(mount)
				s.mounted = mount
			pair.append(s)
		for tick in 240:
			for s in pair:
				s.world.time += 0.1
				s._recover_tick(0.1)
				s._fatigue_tick(0.1)
				if tick % 11 == 0:
					s.add_suppression([5.0, 35.0, 100.0][trial % 3], Vector3(20, 0, 20))
				if tick % 23 == 0:
					var before := s.life
					s.take_damage([0.0, 7.0, 25.0, 46.0, 101.0][(trial + tick) % 5], s.world.entities[3] if trial % 4 != 0 else null,
						Vector3.FORWARD, ["bullet", "explosion", "melee", "fire"][trial % 4])
					if before != Soldier.Life.DEAD and s.life == Soldier.Life.DEAD:
						s._death_fx()
				if tick % 61 == 60 and s.life == Soldier.Life.DOWNED:
					s.revive(trial % 2 == 0)
			observe(pair[0], pair[1], "trial=%d tick=%d" % [trial, tick])
			if tick % 19 == 0:
				var core: RefCounted = ClassDB.instantiate("InfantryVitalsCore")
				assert(core.restore(pair[1]._vitals_core.checkpoint()))
				assert(core.checkpoint() == pair[1]._vitals_core.checkpoint())
				pair[1]._vitals_core = core
		for w in worlds:
			for key in w.stats:
				events[key] = true
			w.entities.clear()
			for child in w.get_children():
				child.free()
	assert(outcomes.size() == 6, "All soldier life states must be compared")
	for key in ["downed", "killed", "revived"]:
		assert(events.has(key), "Missing life transition " + key)
	print("INFANTRY_VITALS passed steps=", checks, " lives=", outcomes)
	get_tree().quit()
