extends "res://tests/fixtures/infantry-special.gd"

class DamageWorld extends ActorWorld:
	var journal := []
	var subject: Structure
	func fx_event(e: Array) -> void:
		match e[0]:
			Fx.SOUND:
				if e[1] == "door_kick": journal.append([0])
			Fx.DEBRIS: journal.append([7, e[3]])
			Fx.TREE_FALL: journal.append([8, e[2]])
			Fx.EXPLODE: journal.append([9])
	func send_msg(_team: int, _kind: String, text: String, _ping = null) -> void:
		if "under attack" in text: journal.append([1])
		elif "has been wrecked" in text: journal.append([3])
		elif "destroyed at" in text: journal.append([10])
	func stat(key: String) -> void:
		super.stat(key)
		if key == "cache_cook_off": journal.append([6, int(4 + 5 * clampf(subject.supply / 160.0, 0.2, 1.0))])

class DamageBattle extends BattleStats:
	func building_destroyed(st: Structure) -> void:
		world.journal.append([2])
		super.building_destroyed(st)

class DamageRules extends Rules:
	func on_fob_changed(_team: int) -> void: pass

class DamageFires extends Fires:
	func _stamp(_p: Vector3, _r: float, _d: int) -> void: pass
	func ignite(st: Structure, heat := 0.15) -> bool:
		var lit := super.ignite(st, heat)
		if lit: world.journal.append([11])
		return lit

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	MapDims.BIOME = 32
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	HNav.NCC = 4
	HNav._corner = HNav._corners()
	TerrainMap.N = 32
	TerrainMap.H = 16.0
	TerrainMap.DN = 64
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for kind in ["fob", "tunnel", "mg_nest", "watchtower", "hmg_nest", "ammo_cache", "tree", "house_wall", "barracks", "car", "concrete_wall", "crates"]:
		for trial in 32:
			var w := DamageWorld.new()
			w.has_view = false
			w.srv = true
			w.settings = {"rust_infantry": false}
			w.nav = RecordedRoutes.new()
			w.nav._planner = ClassDB.instantiate("PathPlannerCore")
			assert(w.nav._planner.configure(32))
			w.terrain = TerrainMap.new(w)
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.battle = DamageBattle.new(w)
			w.rules = DamageRules.new(w)
			w.fires = DamageFires.new(w) if trial % 7 else null
			w._deferred_effects = DeferredEffects.new(false)
			var queue := DeferredEffects.new()
			add_child(w)
			w.rng.seed = 57317 + trial
			random.seed = 57317 + trial
			var st := Mount.new()
			st.world = w
			st.srv = true
			st.eid = 20
			st.skind = kind
			st.team = trial % 3 - 1
			st.owner_peer = 7
			st.position = Vector3(0.3, 0, 0.7)
			st.yaw = 0.731
			st.hp = 60.0 if kind == "car" else 100.0
			st.max_hp = 100.0
			st.size = Vector3(2.9 if trial % 3 == 0 else 6.3, 3, 1.9 if trial % 2 else 4.7)
			st.indestructible = trial % 9 == 0
			st.built = trial % 11 != 0
			st.wrecked = kind == "fob" and trial % 5 == 0
			st.burnt = trial % 13 == 0
			st.variant = trial % 9 if kind == "car" else trial % 4
			st.door_shut = trial % 4 == 0
			st.supply = trial * 7.3
			st._alert_t = 10.0 if trial % 3 == 0 else 0.0
			st.hit_from = Vector3(-2, 1, -4) if trial % 3 == 0 else Vector3.INF
			w.add_child(st)
			w.entities[20] = st
			w.subject = st
			for id in range(1, 4):
				var s := make_soldier(w, id, 0 if id < 3 else 1)
				w.soldiers.append(s)
				if id < 3 and kind == "tunnel":
					s.life = Soldier.Life.HIDDEN
					s.hidden_reason = "tunnel_wait"
					s.hidden_in = st
					st.inside.append(s)
				if id == 1 and kind in ["mg_nest", "watchtower", "hmg_nest"]:
					s.mounted = st
					s.gun_override = Defs.WEAPONS.mmg
					s.task = "man"
					s.task_ent = st
					s.base_y = 4.0 if kind == "watchtower" else 0.0
					s.position.y = s.base_y
					s.at_cover = true
					s.cover_type = Soldier.Cov.LOW
					s._mount_target = w.entities.get(2)
					s._pit_aim = Vector3(1, 0, -12)
					st.gunner = s
			var blocks := []
			var kinds := PackedByteArray()
			for e: Entity in w.entities.values():
				if e is Soldier:
					kinds.append(0)
					blocks.append(soldier_bytes(e))
				else:
					kinds.append(1)
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			for step in 4:
				w.time = 10.0 + step * 13.0
				w.journal.clear()
				w.stats.clear()
				var result: Array
				if trial % 4 == 1 and step == 0:
					st._destroyed(trial % 8 == 1)
					result = actors.destroy_structure(20, trial % 8 == 1, w.time, st.is_player_building(), w.nav._planner, queue._native, random._backend)
				else:
					var source: Entity = w.entities[[3, 2, 1][trial % 3]] if trial % 5 else null
					var blame := [-2, 1, "v9", 0] if trial % 5 == 0 else []
					w.battle._blame = blame
					var amount: float = [17.1, 31.7, 70.0, 300.0][step]
					st.take_damage(amount, source)
					result = actors.damage_structure(20, PackedFloat64Array([amount, w.time, int(st.is_player_building()), 55.0 if w.fires else -1.0]),
						InfantryState.entity_id(source), blame, w.nav._planner, queue._native, random._backend)
				assert(result.size() == 3, "Rejected structure damage")
				var journal := []
				for event: Array in result[1]:
					seen[event[0]] = true
					if not event[0] in [4, 5]: journal.append(event)
				assert(w.journal == journal, "%s %d/%d events: %s / %s" % [kind, trial, step, w.journal, journal])
				assert(w.rng.state == random.state, "%s %d/%d RNG" % [kind, trial, step])
				if not st.gone:
					assert(structure.restore(actors.actor_state(20)))
					assert(structure.values() == StructureState.capture(st), "%s %d/%d structure" % [kind, trial, step])
				elif not result[2].is_empty():
					assert(actors.actor_state(20).is_empty() and structure.restore(result[2]))
					assert(structure.values() == StructureState.capture(st), "%s %d/%d removed structure" % [kind, trial, step])
				checks += 1
				for s: Soldier in w.soldiers:
					compare_actor(s, actors, "%s %d/%d/%d soldier" % [kind, trial, step, s.eid])
					checks += 1
				var pending: Array = queue._native.pending()
				assert(pending.size() == w._deferred_effects._pending.size())
				for i in pending.size():
					var e: Array = w._deferred_effects._pending[i]
					assert(e[0] == pending[i][0] and e[1] == pending[i][1] and e[2] == pending[i][2][0][1])
					var d: Dictionary = e[3]
					assert(pending[i][2][0][2] == PackedFloat64Array([d.dmg, d.radius, d.fling, d.get("at", 0.0), 0.3, d.size, 1.0]))
				assert(queue.take_rubble() == w._deferred_effects.take_rubble(), "%s %d/%d rubble" % [kind, trial, step])
				if step == 1:
					assert(actors.restore(actors.checkpoint()) and queue._native.restore(queue._native.checkpoint()))
			w.free()
	for code in 12: assert(seen.has(code), "Unexercised structure event %d" % code)
	print("STRUCTURE_DAMAGE passed states=%d events=%s" % [checks, seen])
	get_tree().quit()
