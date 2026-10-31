extends "res://tests/fixtures/infantry-duties.gd"

class Clockman extends Dutyman:
	func note(kind: String) -> void:
		world.effects.append([kind, think_t, scan_n, _doing_t, dive_t, dazed_t, flinch_t, act_t, life, act, posture, task, world.rng.state])
		world.rng.randi()
	func _update_doing() -> void: note("doing")
	func _recover_tick(_dt: float) -> void: note("recover")
	func _fatigue_tick(_dt: float) -> void: note("fatigue")
	func _fling_tick(_dt: float) -> void:
		note("fling")
		flinging = false
	func _dazed_tick(dt: float) -> void:
		note("dazed")
		dazed_t -= dt
		act = Act.DAZED
	func _action_tick(_dt: float) -> void:
		note("action")
		if world.trial % 19 == 0:
			act_t = 0.4
	func _action_done() -> void:
		note("action_done")
		act = Act.IDLE
	func _think() -> void:
		note("think")
		match world.trial % 7:
			0: act_t = 0.3
			1: dive_t = 0.1
			2: life = Life.DOWNED
			3: task = "build"
	func _scan() -> void: note("scan")
	func _compute_sep() -> void: note("separate")
	func _fight_tick(_dt: float) -> void: note("fight")
	func _rescue_tick(_dt: float) -> void: note("rescue")
	func _escort_tick(_dt: float) -> void: note("escort")
	func _heal_tick(_dt: float) -> void: note("heal")
	func _build_tick(_dt: float) -> void: note("build")
	func _stretcher_tick(_dt: float) -> void: note("stretcher")
	func _limp_tick(_dt: float) -> void: note("limp")
	func _captor_tick(_dt: float) -> void: note("captor")
	func _man_tick(_dt: float) -> void: note("man")
	func _tunnel_tick(_dt: float) -> void: note("tunnel")
	func _board_tick(_dt: float) -> void: note("board")
	func _resupply_tick(_dt: float) -> void: note("resupply")
	func _gpick_tick(_dt: float) -> void: note("gpick")
	func _retreat_tick(_dt: float) -> void: note("retreat")
	func _throw_tick(_dt: float) -> void: note("throw")
	func _pilot_tick(_dt: float) -> void: note("pilot")
	func _downed(_dt: float) -> void: note("downed")
	func _dead(_dt: float) -> void: note("dead")
	func _captive(_dt: float) -> void: note("captive")
	func _hidden(_dt: float) -> void: note("hidden")
	func _posture_sanity(_dt: float) -> void:
		note("posture")
		_sim_prev = position
	func _update_flags() -> void:
		note("flags")
		flags += 1

class OriginalClockman extends Clockman:
	func sim(dt: float) -> void:
		if not debug_pose.is_empty():
			posture = int(debug_pose[0])
			act = int(debug_pose[1])
			life = int(debug_pose[2])
			flags = int(debug_pose[4]) if debug_pose.size() > 4 else 0
			return
		_doing_t -= dt
		if _doing_t <= 0.0:
			_doing_t = 0.25
			_update_doing()
		_recover_tick(dt)
		if flinging:
			_fling_tick(dt)
		else:
			match life:
				Life.ALIVE:
					_alive(dt)
				Life.DOWNED:
					_downed(dt)
				Life.DEAD:
					_dead(dt)
				Life.SURRENDER, Life.CAPTIVE:
					_captive(dt)
				Life.HIDDEN:
					_hidden(dt)
		_posture_sanity(dt)
		_update_flags()


	func _alive(dt: float) -> void:
		_fatigue_tick(dt)
		if dazed_t > 0.0:
			_dazed_tick(dt)
			return
		if dive_t > 0.0:
			dive_t -= dt
			act = Act.DIVE
			var np := position + dive_dir * 5.5 * dt
			if world.nav.walkable(np):
				position = np
			position.y = maxf(base_y, position.y - dt * 3.0)
			if dive_t <= 0.0:
				posture = Post.PRONE
				act = Act.IDLE
				at_cover = false
				next_cover_eval = world.time + 0.8
			return
		if act_t > 0.0:
			act_t -= dt
			_action_tick(dt)
			if act_t <= 0.0:
				_action_done()
			return
		if flinch_t > 0.0:
			flinch_t -= dt
			act = Act.FLINCH
			if flinch_t > 0.0:
				return
			act = Act.IDLE
		think_t -= dt
		if think_t <= 0.0:
			think_t = 0.24 + world.rng.randf() * 0.1
			_think()
			if act_t > 0.0 or dive_t > 0.0 or life != Life.ALIVE:
				return
		match task:
			"":
				_fight_tick(dt)
			"rescue":
				_rescue_tick(dt)
			"escort":
				_escort_tick(dt)
			"heal":
				_heal_tick(dt)
			"build":
				_build_tick(dt)
			"stretcher":
				_stretcher_tick(dt)
			"limp":
				_limp_tick(dt)
			"captor":
				_captor_tick(dt)
			"man":
				_man_tick(dt)
			"tunnel":
				_tunnel_tick(dt)
			"board":
				_board_tick(dt)
			"resupply":
				_resupply_tick(dt)
			"grenade_pickup":
				_gpick_tick(dt)
			"smother":
				SoldierBrain.smother_tick(self, dt)
			"gkick":
				SoldierBrain.gkick_tick(self, dt)
			"breach":
				SoldierBrain.breach_tick(self, dt)
			"retreat":
				_retreat_tick(dt)
			"throw":
				_throw_tick(dt)
			"pilot":
				_pilot_tick(dt)
			_:
				task = ""


	## What he sees, then what he does about it: the reflexes and the fight are
	## a behaviour tree (SoldierBrain).


	func _think_work() -> void:
		scan_n += 1
		if scan_n % 2 == 0 or target == null:
			_scan()
		_compute_sep()
		SoldierBrain.think(self)


	## Where a man at a halt keeps watch: towards the threat, spread across the
	## squad's frontage by where he stands in it (the flanks look out to the
	## flanks); in a big squad the last man covers the rear.


	func can_take_orders() -> bool:
		if life != Life.ALIVE:
			return false
		if task in ["stretcher", "captor", "limp", "tunnel"]:
			return false
		if task == "rescue" and task_phase >= 1:
			return false
		return true

func clock_world(native: bool) -> MedicalScene:
	var w := duty_world(native)
	w.entity(1).free()
	register(w, Clockman.new() if native else OriginalClockman.new(), 1)
	return w

func compare_clock(worlds: Array, label: String) -> void:
	var a: Soldier = worlds[0].entity(1)
	var b: Soldier = worlds[1].entity(1)
	for key in ["think_t", "scan_n", "_doing_t", "dive_t", "dive_dir", "dazed_t", "flinch_t", "act_t", "life", "act", "posture", "task", "flags", "at_cover", "next_cover_eval", "position", "_sim_prev", "flinging"]:
		same(a.get(key), b.get(key), label + ":" + key)
	assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
	same(worlds[0].effects, worlds[1].effects, label + ":effects")
	if b._controller:
		var saved: PackedByteArray = b._controller.checkpoint()
		assert(b._controller.restore(saved) and b._controller.checkpoint() == saved)

func _ready() -> void:
	MapDims.N = 64
	MapDims.HALF = 32.0
	MapDims.SIZE = 64.0
	MapDims.BIOME = 64
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	assert(ClassDB.class_exists("InfantryControllerCore"))
	var worlds := [clock_world(false), clock_world(true)]
	var duties := ["", "rescue", "escort", "heal", "build", "stretcher", "limp", "captor", "man", "tunnel", "board", "resupply", "grenade_pickup", "retreat", "throw", "pilot", "unknown"]
	var checks := 0
	var outcomes := {}
	for trial in 256:
		var dt: float = [0.0, 1.0 / 30.0, 0.1, 0.5][trial % 4]
		for w: MedicalScene in worlds:
			w.trial = trial
			w.time = 100.0
			w.rng.seed = trial + 9127
			w.effects.clear()
			var s: Soldier = w.entity(1)
			s.position = Vector3(1.3, 0.7, -0.1)
			s.base_y = 0.2 if trial % 3 == 0 else 0.0
			s.life = trial % 6
			s.act = Soldier.Act.SHOOT
			s.posture = trial % 5
			s.flags = 0
			s.debug_pose = [1, 7, 0, 0] if trial % 31 == 0 else []
			s.task = duties[trial % duties.size()]
			s.task_phase = trial % 4
			s.at_cover = true
			s.next_cover_eval = 15.0
			s._sim_prev = Vector3.ZERO
			s.flinging = trial % 7 == 0
			s.think_t = (trial % 5) * 0.02
			s.scan_n = trial
			s._doing_t = (trial % 3) * 0.1
			s.dive_t = 0.1 if trial % 5 == 0 else 0.0
			s.dive_dir = Vector3(0.3, 0.1, -0.7)
			s.dazed_t = 0.1 if trial % 11 == 0 else 0.0
			s.flinch_t = (trial % 4) * 0.02
			s.act_t = 0.1 if trial % 13 == 0 else 0.0
			s.udef = {"bearer": trial % 11 == 0}
		for tick in 16:
			for w: MedicalScene in worlds:
				w.time += dt
				w.entity(1).sim(dt)
			compare_clock(worlds, "trial=%d tick=%d" % [trial, tick])
			checks += 1
		for target_present in [false, true]:
			for w: MedicalScene in worlds:
				var s: Soldier = w.entity(1)
				s.life = Soldier.Life.ALIVE
				s.task = "smother"
				s.target = w.entity(3) if target_present else null
				s._think_work()
			compare_clock(worlds, "scan trial=%d" % trial)
			checks += 1
		for kind in Soldier.CONTROLLER_TASKS + ["unknown"]:
			for life in 6:
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				for s in [a, b]:
					s.task = kind
					s.life = life
				assert(a.can_take_orders() == b.can_take_orders(), "Order gate " + kind)
				assert(a._can_retreat() == b._can_retreat(), "Retreat gate " + kind)
				assert(SoldierBrain.busy(a) == SoldierBrain.busy(b), "Duty gate " + kind)
				checks += 1
		for event in worlds[1].effects:
			outcomes[event[0]] = true
	for kind in ["doing", "recover", "fatigue", "fling", "dazed", "action", "action_done", "think", "scan", "separate", "downed", "dead", "captive", "hidden", "posture", "flags"]:
		assert(outcomes.has(kind), "Missing controller effect " + kind)
	var core: RefCounted = ClassDB.instantiate("InfantryControllerCore")
	var saved: PackedByteArray = core.checkpoint()
	var w: World = worlds[1]
	var rng_before: int = w.rng.state
	assert(core.advance([], 0.1, PackedFloat64Array([0, 0, 0]), w.rng._backend).is_empty())
	assert(core.activity(w.entity(1)._controller_values(), NAN).is_empty())
	assert(core.orders(0, 99, 0, false) == -1)
	assert(core.busy(0, -1, false) == -1)
	assert(not core.restore(saved.slice(0, saved.size() - 1)))
	assert(core.checkpoint() == saved and w.rng.state == rng_before)
	print("INFANTRY_CONTROLLER_BOUNDARY passed")
	print("INFANTRY_CONTROLLER passed steps=", checks)
	for world: World in worlds:
		world.free()
	get_tree().quit()
