extends "res://tests/fixtures/infantry-duties.gd"

class Controlman extends Dutyman:
	func _leave_tent() -> void:
		world.record("leave_tent", self)
		world.rng.randi()
		life = Life.ALIVE
	func unhide(p: Vector3) -> void:
		world.record("unhide", self, [p])
		world.rng.randi()
		life = Life.ALIVE
		hidden_reason = ""
		hidden_in = null
		position = p
		position.y = 0.0

class ControlRules extends DutyRules:
	func prisoner_done(s: Soldier) -> void:
		world.record("prisoner_done", s)
		world.rng.randi()
		s.hidden_t = 9999.0
	func nearest_fob(_team: int, _pos: Vector3) -> Structure:
		return null

class OriginalControlman extends Controlman:
	func _posture_sanity(dt: float) -> void:
		if life != Life.ALIVE or dt <= 0.0:
			_sim_prev = position
			return
		var sp := Defs.flat(position - _sim_prev).length() / dt
		_sim_prev = position
		if sp < 0.3 or act in [Act.CRAWL, Act.DIVE, Act.FLUNG, Act.SLIDE, Act.DRAGGED, Act.CARRIED, Act.VAULT, Act.SMOTHER]:
			return
		var fixed := ""
		if posture == Post.PRONE:
			posture = Post.CROUCH if sp < 3.2 else Post.STAND
			fixed = "prone"
		if act in [Act.IDLE, Act.IDLE_CHAT, Act.IDLE_LOOK, Act.IDLE_CHECK, Act.FLINCH]:
			act = Act.RUN if sp > 3.2 else Act.WALK
			fixed += "idle"
		if fixed != "" and OS.has_environment("FL_DEBUG_PRONE"):
			world.stat("posture_fix_%s_%s_%s" % [fixed, task, goal_kind])


	func _update_flags_work() -> void:
		var f := 0
		if suppression > 25.0:
			f |= F_SUPP
		if suppression >= 60.0:
			f |= F_PINNED
		var w := cur_weapon()
		if not w.is_empty() and int(w.ammo) < 9000:
			if total_ammo() <= 0:
				f |= F_NOAMMO
			elif total_ammo() < int(w.ammo * 0.3):
				f |= F_LOWAMMO
		if world.time - last_shot_t < 0.6:
			f |= F_SHOOTING
		if life == Life.DOWNED:
			f |= F_MEDIC
		if squad and squad.leader == self:
			f |= F_LEADER
		if at_cover and cover_type == Cov.LOW and peek_up and not blind and (cover_h > 0.0 or posture == Post.STAND):
			f |= F_OVERWALL
		flags = f


	## Out of breath: rushes, sprints and dragging a man wear him down; a breather
	## (lower down, sooner) brings it back.


	func _hidden(dt: float) -> void:
		if hidden_reason == "vehicle":
			if riding != null and is_instance_valid(riding) and not riding.gone:
				position = riding.position
				return
			# the vehicle's gone: bail out wherever it was
			riding = null
			unhide(position)
			return
		hidden_t -= dt
		if hidden_t > 0.0:
			return
		match hidden_reason:
			"tent":
				_leave_tent()
			"tunnel_travel":
				if hidden_in and is_instance_valid(hidden_in):
					hidden_in.inside.erase(self)
				unhide(task_pos)
			"interrogation", "held":
				world.rules.prisoner_done(self)
			_:
				hidden_t = 9999.0


	func _pilot_tick(dt: float) -> void:
		posture = Post.CROUCH
		act = Act.LAUNCH
		if drone_ctrl == null or drone_ctrl.gone or drone_ctrl.dead:
			drone_ctrl = null
			task = ""
			return
		_face(Defs.flat(drone_ctrl.position - position), dt, 4.0)


	# --- replication -------------------------------------------------------------------------

func control_world(native: bool) -> MedicalScene:
	var w := duty_world(native)
	w.rules = ControlRules.new(w)
	w.entity(1).free()
	register(w, Controlman.new() if native else OriginalControlman.new(), 1)
	register(w, ShotDrone.new(), 30)
	return w

func compare_control(worlds: Array, label: String) -> void:
	var a: Soldier = worlds[0].entity(1)
	var b: Soldier = worlds[1].entity(1)
	for key in ["position", "rotation", "_sim_prev", "life", "task", "posture", "act", "flags", "hidden_t", "hidden_reason"]:
		same(a.get(key), b.get(key), label + ":" + key)
	assert(eid(a.riding) == eid(b.riding) and eid(a.hidden_in) == eid(b.hidden_in) and eid(a.drone_ctrl) == eid(b.drone_ctrl), label + ":links")
	assert(worlds[0].rng.state == worlds[1].rng.state, label + ":rng")
	same(worlds[0].effects, worlds[1].effects, label + ":effects")
	assert(worlds[0].stats == worlds[1].stats, label + ":stats")

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
	assert(ClassDB.class_exists("InfantryControlCore"))
	var core: RefCounted = ClassDB.instantiate("InfantryControlCore")
	var initial: PackedByteArray = core.checkpoint()
	assert(core.hidden_step(99, 1.0, 0.1, PackedVector3Array()).is_empty())
	assert(core.hidden_step(0, NAN, 0.1, PackedVector3Array()).is_empty())
	assert(core.motion_posture(Vector3.ZERO, Vector3.ZERO, 0.1, 99, 0, 0).is_empty())
	assert(core.status([]) == -1)
	assert(core.pilot(Vector3.ZERO, 0.0, 0.1, PackedVector3Array(), PackedFloat64Array([1.0])).is_empty())
	assert(not core.restore(initial.slice(0, initial.size() - 1)))
	assert(core.checkpoint() == initial)
	print("INFANTRY_CONTROL_BOUNDARY passed")
	var worlds := [control_world(false), control_world(true)]
	var checks := 0
	for trial in 4096:
		var dt: float = [0.0, 1.0 / 30.0, 0.1, 1.0][trial % 4]
		for w: MedicalScene in worlds:
			w.trial = trial
			w.rng.seed = trial + 6379
			w.effects.clear()
			w.stats.clear()
			w.time = 10.0
			var s: Soldier = w.entity(1)
			s.position = Vector3(0.3, 0, -1.7)
			s._sim_prev = s.position - Vector3([0.0, 0.01, 0.3, 3.2, 3.21][trial % 5], 0, 0)
			s.rotation.y = trial * 0.017
			s.life = trial % 6
			s.posture = (trial / 3) % 5
			s.act = trial % 37
			s.task = "pilot"
			s.flags = 0
			s.suppression = [0.0, 25.0, 25.01, 59.99, 60.0, 100.0][trial % 6]
			s.wdef = {} if trial % 7 == 0 else {"ammo": [30, 100, 8999, 9000][trial % 4]}
			s.gun_override = {}
			s.mag = trial % 31
			s.reserve = 0
			s.last_shot_t = [0.0, 9.4, 9.40001, 10.1][(trial / 3) % 4]
			s.squad = Squad.new()
			s.squad.world = w
			s.squad.members = [s]
			s.squad.leader = s if trial % 2 else w.entity(3)
			s.at_cover = trial % 3 != 0
			s.cover_type = (trial / 5) % 4
			s.peek_up = trial % 2 == 0
			s.blind = trial % 7 == 0
			s.cover_h = [-0.1, 0.0, 0.1][(trial / 7) % 3]
			s.mounted = null
			if trial % 9 == 0:
				var mount: Structure = w.entity(10)
				mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4]
				mount.position += s.position - mount.mount_pos()
				s.mounted = mount
			var drone: Drone = w.entity(30)
			drone.position = Vector3(-3.7, 4.2, -9.1)
			drone.gone = trial % 13 == 0
			drone.dead = trial % 17 == 0
			s.drone_ctrl = null if trial % 7 == 0 else drone
		for method in ["_posture_sanity", "_update_flags_work", "_pilot_tick"]:
			for w: MedicalScene in worlds:
				if method == "_update_flags_work":
					w.entity(1).call(method)
				else:
					w.entity(1).call(method, dt)
			compare_control(worlds, "%s trial=%d" % [method, trial])
			checks += 1
		for w: MedicalScene in worlds:
			var s: Soldier = w.entity(1)
			s.life = Soldier.Life.HIDDEN
			s.hidden_reason = ["", "tunnel_wait", "vehicle", "tent", "tunnel_travel", "interrogation", "held"][trial % 7]
			s.hidden_t = [0.0, 0.01, 0.2, 9999.0][(trial / 7) % 4]
			s.hidden_in = w.entity(11)
			s.hidden_in.inside = [s]
			s.task_pos = Vector3(3, 0, 5)
			var car: Vehicle = w.entity(12)
			car.position = Vector3(7, 3, 2)
			car.gone = trial % 13 == 0
			s.riding = null if trial % 11 == 0 else car
		for tick in 4:
			for w: MedicalScene in worlds:
				w.entity(12).position.x += 0.01
				w.entity(1)._hidden(dt)
			compare_control(worlds, "hidden trial=%d tick=%d" % [trial, tick])
			assert(worlds[0].entity(11).inside.size() == worlds[1].entity(11).inside.size(), "Tunnel membership")
			var s: Soldier = worlds[1].entity(1)
			if s._control_core:
				var saved: PackedByteArray = s._control_core.checkpoint()
				assert(s._control_core.restore(saved) and s._control_core.checkpoint() == saved)
			checks += 1
	var w: World = worlds[1]
	var s: Soldier = w.entity(1)
	for kind in ["vehicle", "tunnel", "drone"]:
		var removed: Entity = WorkCar.new() if kind == "vehicle" else (ShotDrone.new() if kind == "drone" else Work.new())
		register(w, removed, 50)
		if kind == "vehicle":
			s.hidden_reason = "vehicle"
			s.riding = removed
		elif kind == "tunnel":
			s.hidden_reason = "tunnel_travel"
			s.hidden_t = 0.0
			s.hidden_in = removed
		else:
			s.task = "pilot"
			s.drone_ctrl = removed
		w.entities.erase(50)
		removed.free()
		if kind == "drone":
			s._pilot_tick(0.1)
			assert(s.task == "" and s.drone_ctrl == null)
		else:
			s._hidden(0.1)
			assert(s.life == Soldier.Life.ALIVE)
	var tent := Work.new()
	register(w, tent, 50)
	var patient := Dutyman.new()
	register(w, patient, 51)
	patient.hidden_in = tent
	patient.position = Vector3.ZERO
	w.entities.erase(50)
	tent.free()
	patient._leave_tent()
	assert(patient.life == Soldier.Life.ALIVE and patient.task == "limp")
	print("INFANTRY_CONTROL_FREED passed cases=4")
	print("INFANTRY_CONTROL passed steps=", checks)
	for world: World in worlds:
		world.free()
	get_tree().quit()
