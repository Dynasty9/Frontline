extends Node3D

class Scene extends World:
	var spoken := []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text])

class ShotCapture extends Combat:
	var shots := []
	func fire_bullet(shooter: Entity, muzzle: Vector3, aim: Vector3, target: Entity, weapon: Dictionary, accuracy := 1.0) -> void:
		shots.append([shooter.eid, muzzle, aim, target.eid if target else 0, weapon, accuracy, shooter.mag, shooter.last_shot_t])
		# A hit may consume draws and raise the shooter's suppression before recovery.
		for draw in 1 + shooter.eid % 5:
			world.rng.randi()
		shooter.suppression += 0.25
		if shooter.eid % 7 == 0:
			shooter.weapon = shooter.weapon.duplicate()
			shooter.weapon.reload = 0.25

class Trooper extends Soldier:
	var weapon := {}
	var shifts := 0
	var shift_height := -1.0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func cur_weapon() -> Dictionary:
		return weapon
	func _shift_along() -> bool:
		shifts += 1
		_shifting = true
		if shift_height >= 0.0:
			cover_h = shift_height
			at_cover = false
			peek_up = false
		return true

class Mount extends Structure:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

var checks := 0
var outcomes := {}


func make_world() -> Scene:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry_weapon": true, "debug": true}
	add_child(w)
	return w


func make_soldier(w: World, trial: int, id: int) -> Trooper:
	var s := Trooper.new()
	s.world = w
	s.eid = id
	s.team = trial % 2
	s.srv = true
	s.at_cover = true
	s.cover_type = [Soldier.Cov.LOW, Soldier.Cov.LEAN][(trial / 2) % 2]
	s.cover_h = [0.4, 0.62, 1.2][(trial / 4) % 3]
	s.cover_mat = (trial / 12) % 4
	s._gy = -1.0 if trial % 3 == 0 else 0.0
	s.mag = [0, 6, 15, 30][(trial / 3) % 4]
	s.reserve = 90 if trial % 7 != 0 else 0
	s.burst_left = trial % 5
	s.weapon = {} if trial % 11 == 0 else {"ammo": 9999 if trial % 13 == 0 else 120, "mag": 30, "reload": 2.4}
	s.peek_t = -0.1 if trial % 5 == 0 else 1.3
	s.peek_up = trial % 3 == 0
	s.last_shot_t = -99.0
	s._supp_t = -99.0
	s.position = Vector3(id * 2, 0, 0)
	w.add_child(s)
	return s


func observe(a: Trooper, b: Trooper, label: String) -> void:
	for key in ["peek_t", "_peek_from", "_up_supp", "reload_t", "say_cd", "fire_t", "last_shot_t"]:
		assert(absf(float(a.get(key)) - float(b.get(key))) < 0.00000001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["peek_up", "_stayed", "_watching", "blind", "burst_left", "mag", "reserve", "_shifting", "shifts", "low_ammo_said", "act"]:
		assert(a.get(key) == b.get(key), "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	assert(a.world.rng.state == b.world.rng.state, "Gameplay random cursor " + label)
	assert(a.world.spoken == b.world.spoken and a.world.stats == b.world.stats, "Firing events " + label)
	for key in ["peek_t", "say_cd"]:
		assert(a.squad.members[1].get(key) == b.squad.members[1].get(key), "Buddy covering " + label)
	for key in ["_stayed", "_watching", "blind", "_shifting"]:
		if a.get(key):
			outcomes[key] = true
	if a.reload_t > 0.0:
		outcomes.reload = true
	if a.squad.members[1].peek_t == 0.2:
		outcomes.buddy = true
	checks += 1


func shots(worlds: Array) -> void:
	for w in worlds:
		w.combat = ShotCapture.new(w)
	worlds[0].settings.rust_infantry_weapon = false
	var count := 0
	var low_ammo := false
	var weapons: Array = Defs.WEAPONS.values()
	for trial in 96:
		var pair: Array[Trooper] = []
		for w in worlds:
			w.rng.seed = 719 + trial
			w.time = 10.0
			w.stats.clear()
			w.spoken.clear()
			w.combat.shots.clear()
			var s := make_soldier(w, trial, 1)
			var buddy := make_soldier(w, trial, 2)
			s.squad = Squad.new()
			s.squad.world = w
			s.squad.members = [s, buddy]
			s.squad.morale = [10.0, 45.0, 90.0][trial % 3]
			s.squad.ambush_t = 25.0 if trial % 4 == 0 else 0.0
			s.eid = trial + 1
			s.weapon = weapons[trial % weapons.size()]
			s.mag = int(s.weapon.mag) if trial % 3 == 0 else 1
			s.reserve = [0, 8, 240][trial % 3]
			s.stamina = (trial % 7) * 0.15
			s.blind = trial % 5 == 0
			s.gun_override = s.weapon if trial % 4 == 0 else {}
			s.cover_n = Vector3.FORWARD
			pair.append(s)
		for tick in 400:
			for s in pair:
				s.world.time += 0.1
				s.say_cd -= 0.1
				s._advance_weapon_timers(0.1)
				if s.fire_t <= 0.0 and s.reload_t <= 0.0:
					s._shoot(Vector3(10, 1, 20), null, trial % 2 == 0, trial % 3 == 0)
			observe(pair[0], pair[1], "shot trial=%d tick=%d" % [trial, tick])
			assert(worlds[0].combat.shots == worlds[1].combat.shots, "Bullet origin, aim, accuracy and shot ordering trial=%d tick=%d" % [trial, tick])
			if tick % 19 == 0:
				var core: RefCounted = ClassDB.instantiate("InfantryWeaponCore")
				assert(core.restore(pair[1]._weapon_core.checkpoint()))
				pair[1]._weapon_core = core
		count += worlds[0].combat.shots.size()
		low_ammo = low_ammo or worlds[0].stats.has("low_ammo")
		for w in worlds:
			for child in w.get_children():
				child.free()
	assert(count > 5000 and low_ammo, "Shot fixture must exercise live rounds and low ammunition: %d rounds, low ammo=%s" % [count, low_ammo])
	print("INFANTRY_SHOTS rounds=", count)


func stances(worlds: Array) -> void:
	var poses := {}
	var allowed := {}
	for trial in 512:
		var pair: Array[Trooper] = []
		for w in worlds:
			w.time = 10.0
			w.rng.seed = 941 + trial
			w.spoken.clear()
			w.stats.clear()
			var s := make_soldier(w, trial, 1)
			var buddy := make_soldier(w, trial, 2)
			s.squad = Squad.new()
			s.squad.world = w
			s.squad.members = [s, buddy]
			s.squad.ambush = trial % 5 == 0
			s.forced_target = buddy if trial % 7 == 0 else null
			s.at_cover = trial % 5 != 0
			s.cover_type = trial % 4
			s.cover_h = [0.0, 0.4, 0.62, 0.79, 0.8, 1.119, 1.12, 1.55][(trial / 4) % 8]
			s.cover_threat = Defs.dir_of(trial * 0.27)
			s.lean_dir = s.cover_threat.cross(Vector3.UP) * (-1 if (trial / 4) % 2 else 1)
			s.rotation.y = trial * 0.13
			s.shift_height = 0.4 if trial % 9 == 0 else -1.0
			s.move_mode = (trial / 3) % 3
			s._sector = Vector3.FORWARD if trial % 2 == 0 else Vector3.ZERO
			s.utype = "pkm" if trial % 7 == 0 else "rifleman"
			s.goal_kind = "cover" if trial % 4 == 0 else "slot"
			s.goal = s.position + Vector3(1.0 if trial % 5 == 0 else 5.0, 0, 0)
			s.path = PackedVector3Array([s.goal])
			s.target = buddy if trial % 2 else null
			s.vis_targets = [buddy]
			s.fire_t = 1.0
			if trial % 6 == 0:
				var mount := Mount.new()
				mount.world = w
				mount.skind = "mg_nest"
				mount.variant = (trial / 6) % 2
				w.add_child(mount)
				s.mounted = mount
				s.position = mount.mount_pos()
			pair.append(s)
		var mode: String = ["normal", "escort", "crew"][(trial / 17) % 3]
		var moving := trial % 8 == 0
		for tick in 120:
			var have_target := (trial / 3) % 2 != 0 and tick % 31 < 20
			var cf := trial % 5 == 0
			for s in pair:
				s.world.time += 0.1
				s.say_cd -= 0.1
				s.suppression = [0.0, 20.0, 40.0, 70.0, 90.0][(tick / 24) % 5]
				s.hit_dirt_t = 1.0 if tick % 47 == 0 else 0.0
				s._advance_weapon_timers(0.1)
			var pinned := pair[0].suppression >= 60.0
			var danger := trial % 3 == 0 or pair[0].suppression > 5.0
			var reference := pair[0]._weapon_stance(0.1, moving, mode, pair[0].weapon, pinned, danger, have_target, cf)
			var actual := pair[1]._weapon_stance(0.1, moving, mode, pair[1].weapon, pinned, danger, have_target, cf)
			observe(pair[0], pair[1], "stance trial=%d tick=%d" % [trial, tick])
			assert(reference == actual and pair[0].posture == pair[1].posture, "Firing stance trial=%d tick=%d ref=%s/%d rust=%s/%d" % [trial, tick, reference, pair[0].posture, actual, pair[1].posture])
			assert(pair[0].rotation.distance_to(pair[1].rotation) < 0.00001, "Firing heading")
			poses[pair[0].posture] = true
			allowed[reference] = true
		for w in worlds:
			for child in w.get_children():
				child.free()
	assert(poses.size() == 5 and allowed.size() == 2, "All firing stances and permission outcomes: %s %s" % [poses, allowed])
	print("INFANTRY_STANCES steps=61440 poses=", poses)


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryWeaponCore"))
	var worlds := [make_world(), make_world()]
	for trial in 192:
		var pair: Array[Trooper] = []
		for w in worlds:
			w.time = 10.0
			w.rng.seed = trial * 61 + 137
			w.stats.clear()
			w.spoken.clear()
			var s := make_soldier(w, trial, 1)
			var buddy := make_soldier(w, trial, 2)
			var foe := make_soldier(w, trial, 3)
			foe.team = 1 - s.team
			s.squad = Squad.new()
			s.squad.world = w
			s.squad.members = [s, buddy]
			s.target = foe if trial % 5 != 0 else null
			if trial % 7 != 0:
				s.vis_targets = [foe]
			pair.append(s)
		var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.2][trial % 3]
		for tick in 360:
			var phase: int = (tick / 30) % 6
			var want_fire := phase != 0 and phase != 5
			for s in pair:
				s.world.time += dt
				s.say_cd -= dt
				s.squad.members[1].say_cd -= dt
				s.suppression = [0.0, 10.0, 48.0, 75.0, 90.0, 0.0][phase]
				if s.suppression > 0.0:
					s._supp_t = s.world.time
				s.hit_dirt_t = 0.6 if trial % 9 == 0 and phase == 5 else 0.0
				if s.reload_t > 0.0:
					s.reload_t -= dt
					if s.reload_t <= 0.0:
						s._finish_reload()
				if tick % 43 == 0:
					s.mag = mini(s.mag, 4)
				s.squad.members[1].peek_up = trial % 4 == 0 and phase == 2
				s.squad.members[1].reload_t = 1.0 if trial % 6 == 0 and phase == 3 else 0.0
				s.squad.members[1].peek_t = 3.0
				s.squad.members[1].task = "build" if trial % 8 == 0 else ""
			var pinned := pair[0].suppression >= 60.0
			pair[0]._cover_cycle_reference(dt, pair[0].cur_weapon(), want_fire, pinned)
			pair[1]._cover_cycle(dt, pair[1].cur_weapon(), want_fire, pinned)
			observe(pair[0], pair[1], "trial=%d tick=%d" % [trial, tick])
			if tick % 29 == 0:
				var core: RefCounted = ClassDB.instantiate("InfantryWeaponCore")
				assert(core.restore(pair[1]._weapon_core.checkpoint()))
				assert(core.checkpoint() == pair[1]._weapon_core.checkpoint())
				pair[1]._weapon_core = core
		for w in worlds:
			for child in w.get_children():
				child.free()
	for key in ["_stayed", "_watching", "blind", "_shifting", "reload", "buddy"]:
		assert(outcomes.has(key), "Missing firing outcome " + key)
	shots(worlds)
	stances(worlds)
	print("INFANTRY_WEAPON passed steps=", checks, " outcomes=", outcomes)
	get_tree().quit()
