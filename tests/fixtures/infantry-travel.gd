extends "res://tests/fixtures/infantry-duties.gd"

class Travelman extends Dutyman:
	func can_take_orders() -> bool:
		return true
	func _move_tick(dt: float, speed: float) -> bool:
		var moved := super._move_tick(dt, speed)
		if task == "board" and world.trial % 7 == 0:
			task_ent.position.x += 0.1
		if task == "resupply" and world.step == 1:
			reserve += 5
		return moved
	func _begin_action(kind: String, duration: float, data: Dictionary) -> void:
		world.record("action", self, [kind, duration, data, frags, smokes])
		world.rng.randi()
		act_kind = kind
		act_t = duration
		act_data = data
	func hide_in(reason: String, duration: float, where: Structure) -> void:
		world.record("hide", self, [reason, duration, where.eid])
		world.rng.randi()
		life = Life.HIDDEN
		hidden_reason = reason
		hidden_t = duration
		hidden_in = where

class Transport extends WorkCar:
	var free_seats := 1
	var helicopter := false
	var boat := false
	func seats_free() -> int:
		world.record("seats", world.entity(1))
		world.rng.randi()
		return free_seats
	func is_heli() -> bool:
		world.record("helicopter", world.entity(1))
		world.rng.randi()
		return helicopter
	func is_boat() -> bool:
		world.record("boat", world.entity(1))
		world.rng.randi()
		return boat
	func board(s: Soldier) -> bool:
		world.record("board", s, [eid])
		world.rng.randi()
		free_seats -= 1
		s.riding = self
		s.life = Soldier.Life.HIDDEN
		return true

class Admission extends MedicalScene:
	var queries := 0
	func team_of_peer(_peer: int) -> int:
		return 0
	func _command_squads(_peer: int, _ids: Array) -> Array:
		queries += 1
		return []

class OriginalTravelman extends Travelman:
	func _board_tick(dt: float) -> void:
		var v := task_ent as Vehicle
		if v == null or v.gone or v.seats_free() <= 0 or (v.is_heli() and v.position.y > 1.0):
			task = ""
			return
		var d := Defs.flat(v.position - position).length()
		var boat := v.is_boat()
		if d < 3.6 or (boat and (d < 8.0 or (d < 18.0 and not is_moving()))):
			task = ""
			v.board(self)
			return
		var moving := _move_tick(dt, _speed())
		if boat and not moving and Defs.flat(v.position - position).length() < 18.0:
			# waded out as far as he can: hauled over the side
			task = ""
			v.board(self)
			return
		if not moving or Defs.flat(goal - v.position).length() > 3.0:
			go_to(v.position, "task", 1)
		_choose_act(true)

	func _tunnel_tick(dt: float) -> void:
		var st := task_ent as Structure
		if st == null or st.gone or not st.built:
			task = ""
			return
		if _move_tick(dt, _speed()):
			_choose_act(true)
			return
		if Defs.flat(st.position - position).length() > 2.5:
			go_to(st.position, "task", 1)
			return
		task = ""
		hide_in("tunnel_wait", 9999.0, st)
		world.stat("tunnel_in")
		st.inside.append(self)
		st.net_dirty = true

	func _resupply_tick(dt: float) -> void:
		var t := task_ent
		if t == null or t.gone:
			task = ""
			return
		if _move_tick(dt, _speed()):
			_choose_act(true)
			return
		act = Act.IDLE
		if t is Soldier:
			if t.loot > 0:
				var take := mini(int(wdef.ammo) - total_ammo(), t.loot)
				t.loot -= take
				reserve += take
				say("Got ammo.")
			_return_to_hold()
		elif total_ammo() >= int(wdef.ammo) - 5:
			_return_to_hold()

	func _throw_tick(dt: float) -> void:
		if Defs.flat(task_pos - position).length() <= 25.0:
			var kind := throw_kind
			if kind == "smoke" and smokes <= 0 or kind == "frag" and frags <= 0:
				task = ""
				return
			if kind == "smoke":
				smokes -= 1
				world.stat("smoke")
			else:
				frags -= 1
			task = ""
			_begin_action("throw", 0.6, {"pos": task_pos, "kind": kind})
			say("Smoke out!" if kind == "smoke" else "Frag out!", true)
			return
		if not _move_tick(dt, _speed()):
			task = ""
		_choose_act(true)



func travel_world(native: bool) -> MedicalScene:
	var w := duty_world(native)
	w.entity(1).free()
	register(w, Travelman.new() if native else OriginalTravelman.new(), 1)
	w.entity(12).free()
	register(w, Transport.new(), 12)
	return w


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
	var worlds := [travel_world(false), travel_world(true)]
	var checks := 0
	var outcomes := {}
	for trial in 1024:
		for kind in ["board", "tunnel", "resupply", "throw"]:
			for w: MedicalScene in worlds:
				w.trial = trial
				w.rng.seed = trial + 3761
				w.effects.clear()
				w.spoken.clear()
				w.stats.clear()
				var s: Soldier = w.entity(1)
				var v: Transport = w.entity(12)
				var entrance: Structure = w.entity(11)
				var body: Soldier = w.entity(3)
				s.position = Vector3([0.0, 2.5, 3.6, 8.0, 17.9, 18.0, 25.0, 25.01, 35.0][(trial / 2) % 9], 0, 0)
				s.rotation.y = trial * 0.17
				s.life = Soldier.Life.ALIVE
				s.riding = null
				s.task = kind
				s.task_ent = v if kind == "board" else (body if kind == "resupply" and trial % 2 else entrance)
				s.task_phase = 0
				s.task_t = 0.0
				s.task_pos = Vector3.ZERO
				s.posture = trial % 5
				s.act = Soldier.Act.IDLE
				s.act_t = 0.0
				s.act_kind = ""
				s.act_data = {}
				s.backwards = false
				s.goal = Vector3([0.0, 3.0, 3.01, 9.0][(trial / 3) % 4], 0, 0)
				s.goal_kind = "task"
				s.move_mode = trial % 3
				s.path = PackedVector3Array([s.goal]) if trial % 2 else PackedVector3Array()
				s.path_i = 0
				s._path_pending = trial % 3 == 0
				s._last_dir = Vector3.FORWARD
				s.wdef = {"ammo": 120}
				s.mag = 30
				s.reserve = trial % 120
				s.frags = trial % 3
				s.smokes = (trial / 3) % 3
				s.throw_kind = "frag" if trial % 2 else "smoke"
				s.say_cd = 0.0
				s.squad = null
				s.hidden_in = null
				s.hidden_t = 0.0
				s.hidden_reason = ""
				v.position = Vector3(0, [0.0, 1.0, 1.01, 3.0][(trial / 2) % 4], 0)
				v.gone = trial % 23 == 0
				v.free_seats = trial % 5 - 1
				v.helicopter = trial % 3 == 0
				v.boat = trial % 2 == 0
				entrance.position = Vector3.ZERO
				entrance.gone = trial % 17 == 0
				entrance.built = trial % 11 != 0
				entrance.inside.clear()
				entrance.net_dirty = false
				body.position = Vector3.ZERO
				body.life = Soldier.Life.DEAD
				body.gone = trial % 19 == 0
				body.loot = trial % 70
			for tick in 6:
				var dt: float = [0.0, 1.0 / 30.0, 0.2][trial % 3]
				for w: MedicalScene in worlds:
					w.step = tick
					w.time = 10.0 + tick * dt
					w.entity(1).call("_" + kind + "_tick", dt)
				var a: Soldier = worlds[0].entity(1)
				var b: Soldier = worlds[1].entity(1)
				var label := "%s trial=%d tick=%d" % [kind, trial, tick]
				for key in ["position", "rotation", "life", "task", "task_phase", "task_t", "posture", "act", "act_t", "act_kind", "act_data", "goal", "goal_kind", "move_mode", "path", "path_i", "_path_pending", "say_cd", "reserve", "mag", "frags", "smokes", "hidden_t", "hidden_reason"]:
					same(a.get(key), b.get(key), label + ":" + key)
				assert(eid(a.riding) == eid(b.riding) and eid(a.hidden_in) == eid(b.hidden_in), label + ":links")
				assert(worlds[0].entity(12).free_seats == worlds[1].entity(12).free_seats, label + ":seats")
				same(worlds[0].entity(12).position, worlds[1].entity(12).position, label + ":vehicle")
				assert(worlds[0].entity(11).inside.map(eid) == worlds[1].entity(11).inside.map(eid), label + ":tunnel")
				assert(worlds[0].entity(11).net_dirty == worlds[1].entity(11).net_dirty, label + ":dirty")
				assert(worlds[0].entity(3).loot == worlds[1].entity(3).loot, label + ":loot")
				assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
				same(worlds[0].effects, worlds[1].effects, label + ":effects")
				assert(worlds[0].spoken == worlds[1].spoken and worlds[0].stats == worlds[1].stats, label + ":speech/stats")
				for event: Array in worlds[1].effects:
					outcomes[event[0]] = true
				checks += 1
	for key in ["seats", "helicopter", "boat", "board", "hide", "action", "hold", "go", "move"]:
		assert(outcomes.has(key), "Uncovered travel effect " + key)
	var native: World = worlds[1]
	var s: Soldier = native.entity(1)
	for kind in ["board", "tunnel", "resupply"]:
		var removed: Entity = Transport.new() if kind == "board" else (Work.new() if kind == "tunnel" else Travelman.new())
		register(native, removed, 50)
		s.task = kind
		s.task_ent = removed
		native.entities.erase(50)
		removed.free()
		s.call("_" + kind + "_tick", 1.0 / 30.0)
		assert(s.task == "", "Removed travel destination " + kind)
	var admission := Admission.new()
	admission.srv = true
	for kind in ["", "rocket", "unknown"]:
		s.task = "build"
		s.task_ent = native.entity(11)
		s.detached = false
		var cursor := native.rng.state
		s.cmd_throw(Vector3.ZERO, kind)
		s.unit_order({"o": "throw", "kind": kind, "pos": Vector3.ZERO})
		assert(s.task == "build" and s.task_ent == native.entity(11) and not s.detached and cursor == native.rng.state)
		admission.execute_cmd(1, {"t": "throw", "kind": kind, "pos": Vector3.ZERO})
		admission.execute_cmd(1, {"t": "unit", "o": "throw", "kind": kind, "pos": Vector3.ZERO})
		assert(admission.queries == 0, "Invalid throw reached command ownership")
	admission.execute_cmd(1, {"t": "throw", "kind": "frag", "pos": Vector3.ZERO})
	assert(admission.queries == 1, "Valid throw was rejected")
	admission.free()
	print("INFANTRY_TRAVEL_BOUNDARY passed")
	print("INFANTRY_TRAVEL passed steps=", checks)
	for w: World in worlds:
		w.free()
	get_tree().quit()
