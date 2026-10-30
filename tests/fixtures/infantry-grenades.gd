extends "res://tests/fixtures/native-bullet.gd"

class GrenadeScene extends ShotScene:
	var spoken := []
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text, rng.state])

class Grenadier extends ShotSoldier:
	func _react_shells(_only: bool) -> bool: return false
	func _react_drones() -> void: pass
	func _try_melee() -> bool: return false
	func _scavenge() -> void: pass
	func _try_mortar() -> bool: return false
	func _try_rocket() -> bool: return false
	func _try_drone() -> bool: return false
	func _try_grenade() -> bool: return false
	func _fight_think() -> void: pass
	func _sector_dir() -> Vector3: return Vector3.ZERO

class Round extends Projectile:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


func grenade_world(native: bool) -> GrenadeScene:
	var w := GrenadeScene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": native, "debug": true}
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	register(w, Grenadier.new(), 1)
	for id in range(3, 8):
		register(w, ShotSoldier.new(), id)
	register(w, ShotWall.new(), 10)
	register(w, ShotCar.new(), 11)
	body(w.entity(10), Vector3(0.2, 3, 4))
	body(w.entity(11), Vector3(0.2, 3, 4))
	for id in range(20, 23):
		register(w, Round.new(), id)
		w.projectiles.append(w.entity(id))
	return w


func eid(e) -> int:
	return e.eid if is_instance_valid(e) else 0


func compare_grenades(a: Soldier, b: Soldier, trial: int) -> void:
	for key in ["task", "task_t", "posture", "act", "at_cover", "peek_up", "blind", "hit_dirt_t", "dive_t", "dive_dir", "rotation", "path", "say_cd", "bt_path", "seen_grenades"]:
		assert(a.get(key) == b.get(key), "Grenade trial=%d %s ref=%s rust=%s" % [trial, key, a.get(key), b.get(key)])
	assert(eid(a.task_ent) == eid(b.task_ent) and eid(a.bt_g) == eid(b.bt_g), "Grenade targets")
	assert(a.world.rng.state == b.world.rng.state, "Grenade random cursor")
	assert(a.world.spoken == b.world.spoken and a.world.stats == b.world.stats, "Grenade effects")
	for id in range(20, 23):
		assert(eid(a.world.entity(id).handler) == eid(b.world.entity(id).handler))
		assert(eid(a.world.entity(id).smothered_by) == eid(b.world.entity(id).smothered_by))


func _ready() -> void:
	assert(ClassDB.class_exists("GrenadeReactionCore"))
	var worlds := [grenade_world(false), grenade_world(true)]
	var outcomes := {}
	for trial in 4096:
		for w in worlds:
			w.rng.seed = 317 + trial
			w.time = 10.0
			w.stats.clear()
			w.spoken.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3.ZERO
			s.rotation.y = float(trial % 20) * 0.13
			s.life = Soldier.Life.ALIVE
			s.team = 0
			s.task = ""
			s.task_ent = null
			s.task_t = 0.0
			s.act = Soldier.Act.IDLE
			s.act_t = 0.0
			s.posture = trial % 5
			s.at_cover = true
			s.peek_up = true
			s.blind = true
			s.hit_dirt_t = 0.0
			s.dive_t = 0.0
			s.dive_dir = Vector3.ZERO
			s.bt_path = ""
			s.suppression = float(trial % 90)
			s.mounted = w.entity(10) if trial % 17 == 0 else null
			s.riding = w.entity(11) if trial % 23 == 0 else null
			s.wdef = {} if trial % 7 == 0 else Defs.WEAPONS.rifle
			s.path = PackedVector3Array([Vector3(20, 0, 20)])
			s.seen_grenades.clear()
			if trial % 19 == 0:
				for id in range(100, 125):
					s.seen_grenades[id] = true
			s.squad = null if trial % 11 == 0 else Squad.new()
			if s.squad:
				s.squad.world = w
				s.squad.members = [s]
			for id in range(3, 8):
				var mate: Soldier = w.entity(id)
				mate.position = Vector3(2 + (id - 3) * 0.2, 0, (id - 4) * 0.2)
				mate.team = 1 if id == 7 else 0
				mate.life = [Soldier.Life.ALIVE, Soldier.Life.DOWNED, Soldier.Life.CAPTIVE][(trial / 5 + id) % 3]
				mate.task = "heal" if trial % 3 == 0 else ""
				mate.at_cover = trial % 2 == 0
				mate.cover_mat = trial % 4
				if id == 7 and trial % 37 == 0:
					mate.task = "smother"
					mate.life = Soldier.Life.ALIVE
			var wall: Structure = w.entity(10)
			wall.skind = "low_wall"
			wall.position = Vector3(1, 0, 0 if trial % 3 == 0 else 10)
			w.combat.dirty_collision(10)
			w.entity(11).position = Vector3(1, 0, 0 if trial % 3 == 1 else 10)
			w.combat.dirty_collision(11)
			for id in range(20, 23):
				var g: Projectile = w.entity(id)
				g.ptype = "smoke" if id == 20 and trial % 13 == 0 else "frag"
				g.position = Vector3((trial % 9) * 0.7 + 0.4 if id == 20 else 5.5 + (id - 21) * 10.0, (trial % 3) * 0.2, 0)
				g.fuse = 0.4 + (trial % 12) * 0.25
				g.gone = trial % 29 == 0
				g.flying = trial % 3 == 0
				g.held_by = w.entity(7) if trial % 31 == 0 else null
				g.handler = w.entity(7) if trial % 37 == 0 else null
				g.smothered_by = w.entity(3) if trial % 41 == 0 else null
				g.thrown_back = int(trial % 11 == 0)
				g.thrower_id = 7 if trial % 2 == 0 else 0
			SoldierBrain.think(s)
			outcomes[s.bt_path] = true
		compare_grenades(worlds[0].entity(1), worlds[1].entity(1), trial)
		var velocities := []
		var cooking := []
		for w in worlds:
			velocities.append(SoldierBrain.kick_vel(w.entity(1), w.entity(20)))
			cooking.append(SoldierBrain.cook_time(w.entity(1), w.entity(3), float(trial % 31)))
		assert(velocities[0] == velocities[1], "Grenade kick velocity")
		assert(cooking[0] == cooking[1] and worlds[0].rng.state == worlds[1].rng.state, "Grenade cooking")
		var core: RefCounted = worlds[1].entity(1)._grenade_core
		var saved: PackedByteArray = core.checkpoint()
		assert(core.restore(saved))
	for outcome in ["throw himself on it", "pick it up", "kick it away", "get down behind it", "dive clear"]:
		assert(outcomes.has(outcome), "Missing grenade reflex " + outcome)
	for w in worlds:
		w.free()
	print("INFANTRY_GRENADES passed cases=4096")
