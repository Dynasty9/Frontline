extends "res://tests/fixtures/infantry-vitals.gd"

class CasualtyScene extends Scene:
	func despawn(e: Entity) -> void:
		effects.append(["despawn", e.eid, rng.state])
		e.gone = true
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text, rng.state])

class CasualtyCombat extends Combat:
	func prot_at(p: Vector3, _threats: Array, h: float) -> float:
		world.effects.append(["protection", p, h, world.rng.state])
		return 0.0
	func find_cover(_s: Soldier, anchor: Vector3, radius: float, _threats: Array, prone: bool) -> Dictionary:
		world.effects.append(["cover", anchor, radius, prone, world.rng.state])
		return {"pos": anchor + Vector3.RIGHT * 2.0}

class Casualty extends Soldier:
	var sampled_ground := -0.65
	var pistol_changes_state := false
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _ground() -> float:
		return sampled_ground
	func _pistol_fire() -> void:
		world.effects.append(["pistol", world.rng.state, carried_by.size(), dragged_by != null])
		last_shot_t = world.time
		world.rng.randf()
		if pistol_changes_state:
			bleed = 3.0
	func _threats() -> Array:
		return [Vector3(10, 0, 10)]
	func go_to(p: Vector3, kind: String, mode: int) -> void:
		world.effects.append(["go", p, kind, mode, world.rng.state])
		path = PackedVector3Array([p])
		path_i = 0
		goal_kind = kind
	func _move_tick(dt: float, speed: float) -> bool:
		world.effects.append(["move", dt, speed, world.rng.state])
		position.x += dt * speed
		return true


func make_casualty(w: Scene, trial: int) -> Casualty:
	var s := Casualty.new()
	s.world = w
	s.srv = true
	s.eid = 1
	s.team = trial % 2
	s.life = Soldier.Life.DOWNED
	s.wdef = Defs.WEAPONS.rifle
	s.udef = Defs.UNITS.rifleman
	s.mag = 7
	s.reserve = 23
	s.position = Vector3(1, 2, 3)
	s.bleed = [0.01, 2.0, 24.0, 50.0][trial % 4]
	s.bleed_max = 50.0
	s.scream_t = float(trial % 3) * 0.1
	s.pistol_t = float((trial / 3) % 3) * 0.1
	s.crawl_t = 0.15
	s.pistol_changes_state = trial % 7 == 0
	s.stretcher_claimed = trial % 13 == 0
	s.dead_t = -300.0
	w.add_child(s)
	w.entities[1] = s
	return s


func compare_wounded(a: Soldier, b: Soldier, label: String) -> void:
	for key in ["life", "act", "gone", "hp", "bleed", "scream_t", "pistol_t", "crawl_t", "dead_t", "say_cd", "mag", "reserve", "loot", "path", "path_i", "goal_kind", "last_shot_t"]:
		assert(a.get(key) == b.get(key), "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	assert(a.position == b.position, "Position " + label)
	assert(a.carried_by.size() == b.carried_by.size() and (a.dragged_by == null) == (b.dragged_by == null), "Rescuers " + label)
	assert(a.world.effects == b.world.effects and a.world.spoken == b.world.spoken and a.world.stats == b.world.stats, "Wounded events " + label)
	assert(a.world.rng.state == b.world.rng.state, "Random cursor " + label)
	outcomes[a.act] = true
	checks += 1


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryVitalsCore"))
	var worlds: Array[Scene] = []
	for native in [false, true]:
		var w := CasualtyScene.new()
		w.srv = true
		w.has_view = false
		w.settings = {"rust_infantry": native, "debug": true}
		w.rules = Rules.new(w)
		w.combat = CasualtyCombat.new(w)
		add_child(w)
		worlds.append(w)
	for trial in 384:
		var pair: Array[Soldier] = []
		var rescuers: Array[Soldier] = []
		for w in worlds:
			w.rng.seed = 831 + trial
			w.time = 10.0
			w.stats.clear()
			w.spoken.clear()
			w.effects.clear()
			w.rules.upgrades = [{}, {}]
			if trial % 2 == 0:
				w.rules.upgrades[trial % 2].medicine = true
			var s := make_casualty(w, trial)
			var rescuer := Trooper.new()
			rescuer.world = w
			rescuer.eid = 2
			rescuer.task = "rescue"
			w.add_child(rescuer)
			if trial % 3 == 0:
				s.dragged_by = rescuer
			elif trial % 3 == 1:
				s.carried_by.append(rescuer)
			pair.append(s)
			rescuers.append(rescuer)
		for tick in 160:
			for i in 2:
				var s := pair[i]
				s.world.time = 10.0 + tick * 0.1
				if tick == 5:
					rescuers[i].life = Soldier.Life.DEAD
				if tick == 10 and s.life == Soldier.Life.DOWNED:
					s.carried_by.append(rescuers[i])
				if tick == 15 and s.life == Soldier.Life.DEAD:
					rescuers[i].life = Soldier.Life.ALIVE
					s.carried_by.append(rescuers[i])
				if tick == 20:
					rescuers[i].gone = true
				if not s.gone:
					if s.life == Soldier.Life.DOWNED:
						s._downed(0.1)
					else:
						s._dead(0.1)
			compare_wounded(pair[0], pair[1], "trial=%d tick=%d" % [trial, tick])
			if tick == 35 and pair[1]._vitals_core:
				var saved: PackedByteArray = pair[1]._vitals_core.checkpoint()
				assert(pair[1]._vitals_core.restore(saved))
		for i in 2:
			worlds[i].entities.clear()
			pair[i].free()
			rescuers[i].free()
	for action in [Soldier.Act.CARRIED, Soldier.Act.DRAGGED, Soldier.Act.CRAWL, Soldier.Act.PISTOL, Soldier.Act.IDLE]:
		assert(outcomes.has(action), "Missing casualty action %d" % action)
	var freed_pair: Array[Soldier] = []
	for w in worlds:
		w.effects.clear()
		w.spoken.clear()
		w.stats.clear()
		w.rng.seed = 19
		var s := make_casualty(w, 3)
		var rescuer := Trooper.new()
		s.dragged_by = rescuer
		rescuer.free()
		s._downed(0.1)
		assert(s.dragged_by == null)
		freed_pair.append(s)
	compare_wounded(freed_pair[0], freed_pair[1], "Freed rescuer")
	for s in freed_pair:
		s.world.entities.clear()
		s.free()
	for w in worlds:
		w.free()
	print("INFANTRY_WOUNDED passed steps=%d" % checks)
