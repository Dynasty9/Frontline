extends "res://tests/fixtures/support-flight.gd"

const BALLISTIC := ["frag", "smoke", "rocket", "recoilless", "mortar", "mortar_smoke", "grad", "arty", "ac105", "ac40", "ac25", "bomb"]

class ActorWorld extends SupportWorld:
	func send_msg(_team: int, _kind: String, _text: String, _ping = null) -> void:
		events.append(["smother_notice", 3])

class ActorCombat extends SupportCombat:
	var smoke := false
	func ray(_a: Vector3, _b: Vector3, _exclude: Array = []) -> Dictionary:
		return {}
	func smoke_blocks(_a: Vector3, _b: Vector3) -> bool:
		return smoke

class Smotherer extends Soldier:
	func take_damage(amount: float, source, direction: Vector3, kind := "bullet") -> void:
		assert(amount == 900.0 and direction == Vector3.UP and kind == "explosion")
		world.events.append(["smother_damage", eid, source.eid if is_instance_valid(source) else 0])
		life = Life.DEAD

func metadata(p: Projectile) -> PackedInt64Array:
	return PackedInt64Array([p.eid, p.team, p.thrower_id, p.by, InfantryState.entity_id(p.held_by), InfantryState.entity_id(p.smothered_by), InfantryState.entity_id(p.handler), p.thrown_back, p.tgt_id])

func start(p: Projectile, core: RefCounted) -> int:
	var kind := 0
	var bytes: PackedByteArray
	if p.ptype in BALLISTIC:
		p._flight = ClassDB.instantiate("ProjectileFlightCore")
		p._reset_flight()
		bytes = p._flight.checkpoint()
		p._flight = null
		p._shell_flight = false
	elif p.ptype in ["atgm", "sam"]:
		kind = 1
		var flight: RefCounted = ClassDB.instantiate("GuidedFlightCore")
		assert(flight.reset(p.ptype == "atgm", p.position, p.vel, p.target, p.life_t, p.tgt_id != 0))
		bytes = flight.checkpoint()
	else:
		kind = 2
		p._support = ClassDB.instantiate("SupportFlightCore")
		p._reset_support()
		bytes = p._support.checkpoint()
		p._support = null
	assert(core.load_state(metadata(p), kind, bytes))
	return kind

func blast(pos: Vector3, data: Dictionary) -> Array:
	return [0, pos, Array(PackedFloat64Array([data.get("dmg", 120.0), data.get("radius", 5.0), data.get("fling", 8.0), data.get("at", 0.0), data.get("track", 0.3), data.get("size", 1.0), data.get("struct_mult", 1.0)])),
		[data.dir] if data.has("dir") else [], data.get("top", false), InfantryState.entity_id(data.get("src")), data.get("team", -1), data.get("by", 0)]

func spawn_data(kind: String, position: Vector3, velocity: Vector3, origin: Vector3, target: Vector3, fuse: float, duration: float, team: int, thrower: int, by: int) -> Array:
	return [1, BALLISTIC.find(kind), position, velocity, origin, target, fuse, duration, team, thrower, by]

func reference_events(w: ActorWorld) -> Array:
	var result := []
	for event: Array in w.events:
		match event[0]:
			"explode": result.append(blast(event[1], event[2]))
			"spawn":
				var p: Dictionary = event[2]
				result.append(spawn_data(p.ptype, p.get("pos", Vector3.ZERO), p.get("vel", Vector3.ZERO), p.get("origin", Vector3.ZERO), p.get("target", Vector3.ZERO), p.get("fuse", 3.4), p.get("T", 3.0), p.get("team", -1), p.get("thrower", 0), p.get("by", 0)))
			"fx": result.append([5, event[1][1], event[1][2], event[1][3]])
			"mark": result.append([4, event[1], event[2], event[3], event[4]])
			"despawn": result.append([7])
			"smother_damage": result.append([2, event[1], event[2]])
			"smother_notice": result.append([3, event[1]])
	return result

func native_events(events: Array, rng: SimulationRandom, stats: Dictionary) -> Array:
	var result := []
	for event: Array in events:
		match int(event[0]):
			0:
				result.append([0, event[1], Array(event[2]), Array(event[3]), event[4], event[5], event[6], event[7]])
				rng.randi()
			1:
				var v: PackedFloat64Array = event[2]
				result.append(spawn_data(BALLISTIC[event[1]], Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]), Vector3(v[9], v[10], v[11]), v[12], v[17], event[3], event[4], event[5]))
			6: stats[event[1]] = int(stats.get(event[1], 0)) + 1
			_: result.append(event)
	return result

func _ready() -> void:
	var cases := 0
	var steps := 0
	var setups := []
	for kind in BALLISTIC + ["atgm", "sam"]:
		setups.append([kind, ""])
	setups.append_array([["jet", ""], ["a10", ""], ["ac130", ""], ["ac130", "blackfish"], ["ac130", "xian"], ["ac130", "greyhawk"], ["ac130", "none"]])
	for setup: Array in setups:
		for trial in 8:
			var w := ActorWorld.new()
			w.has_view = false
			w.rng.seed = 8732 + trial
			w.combat = ActorCombat.new(w)
			w.combat.enable_native_collision()
			w.rules = SupportRules.new(w)
			var rng := SimulationRandom.new()
			rng.seed = 8732 + trial
			var stats := {}
			var p := Projectile.new()
			p.world = w
			p.eid = 17
			var target := Soldier.new()
			target.eid = 2
			target.world = w
			target.team = 1
			target.position = Vector3(37, 20 if setup[0] == "sam" else 0, -12)
			var holder := Soldier.new()
			holder.eid = 1
			holder.world = w
			holder.position = Vector3(1, 0, 2)
			holder.team = 1
			var smotherer := Smotherer.new()
			smotherer.eid = 3
			smotherer.world = w
			smotherer.position = Vector3(0, 0, 0.75)
			smotherer.task = "smother"
			w.entities = {1: holder, 2: target, 3: smotherer}
			w.nearby_soldiers = [target]
			p.apply_props({"ptype": setup[0], "guns": setup[1], "team": 0, "thrower": 1, "by": 77, "pos": Vector3(0, 2, 0), "vel": Vector3(12, 1, -3), "origin": Vector3(0, 2, 0), "target": Vector3(37, 0, -12), "tgt": 2 if setup[0] in ["atgm", "sam"] else 0, "T": 2.7, "sight": 65.0, "stay": 8.0})
			if p.ptype in ["jet", "a10", "ac130"]:
				p.position = Vector3(-420, 62, 0)
				p.vel = Vector3(58, 0, 0)
				p.mk = setup[1] if trial % 2 else ""
			if p.ptype == "frag" and trial >= 4:
				p.position = Vector3(0, 0.06, 0)
				p.vel = Vector3.ZERO
				p.fuse = 0.1
				p.smothered_by = smotherer
				smotherer.life = Soldier.Life.DEAD if trial == 5 else Soldier.Life.ALIVE
				smotherer.task = "" if trial == 6 else "smother"
				smotherer.position.x = 2.0 if trial == 7 else 0.0
			var core: RefCounted = ClassDB.instantiate("ProjectileActorCore")
			var motion := start(p, core)
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			for tick in 2200:
				if p.ptype in ["frag", "smoke"] and trial < 4:
					if tick == 2:
						p.pick_up(holder)
						assert(core.pick_up(holder.eid))
					if tick == 5:
						if trial % 2:
							p.release_throw(holder, Vector3(15, 0, 7))
							assert(core.release_throw(holder.eid, holder.team, holder.position, Vector3(15, 0, 7)))
						else: holder.life = Soldier.Life.DEAD
					if tick == 7:
						p.kick(holder, Vector3(4, 2, 1))
						assert(core.kick(Vector3(4, 2, 1)))
				if p.ptype in ["atgm", "sam"]:
					target.position.z += 2.0 * dt
					if tick == 8 and trial % 3 == 0: target.gone = true
					w.combat.smoke = tick >= 9 and trial % 3 == 1
				var held := 0
				var held_position := Vector3.ZERO
				if p.held_by:
					held = 1 if p.held_by.life == Soldier.Life.ALIVE else 2
					held_position = p.held_by.position + Vector3(0, 1.3, 0) + Defs.dir_of(p.held_by.rotation.y) * 0.3
				var target_position := PackedVector3Array()
				if not target.gone and p.tgt_id != 0: target_position.append(target.center_point())
				var covering := []
				if p.smothered_by: covering = [3, smotherer.position, smotherer.rotation.y, smotherer.life == Soldier.Life.ALIVE, smotherer.task == "smother"]
				var candidates := p._ac_candidates() if motion == 2 else PackedVector3Array()
				w.time += dt
				w.events.clear()
				p.sim(dt)
				var out: Array = core.advance([dt, w.time, MapDims.HALF, held, held_position, target_position, w.combat.smoke, covering], candidates, PackedInt64Array(), w.combat._collision, rng._backend)
				assert(out.size() == 1)
				var actual := native_events(out[0], rng, stats)
				var expected := reference_events(w)
				var label := "%s %d tick %d" % [setup, trial, tick]
				assert(same(expected, actual), "%s effects %s vs %s" % [label, expected, actual])
				assert(stats == w.stats, label + " stats")
				assert(rng.state == w.rng.state, label + " RNG")
				assert(core.values()[0] == metadata(p), label + " links")
				var state: Array = core.view_state()
				assert(p.position.distance_to(state[0]) < 0.005 and p.vel.distance_to(state[1]) < 0.01, label + " trajectory")
				assert(p.life_t == state[2], label + " lifetime")
				if motion == 0: assert([p.fuse, p.flying, p.smoke_t, p.smoke_r] == state.slice(3), label + " flight")
				elif motion == 1: assert(p.target == state[3], label + " guidance")
				else: assert([p.fuse, p._fire_el, p._bombs0, p._mark_t] == state.slice(3), label + " schedule")
				if tick % 17 == 0:
					var saved: PackedByteArray = core.checkpoint()
					assert(core.restore(saved) and core.checkpoint() == saved)
				steps += 1
				if p.gone: break
			assert(p.gone, "Projectile did not finish: %s" % [setup])
			p.free()
			w.free()
			holder.free()
			target.free()
			smotherer.free()
			cases += 1
	print("PROJECTILE_ACTOR passed cases=", cases, " steps=", steps)
	get_tree().quit()
