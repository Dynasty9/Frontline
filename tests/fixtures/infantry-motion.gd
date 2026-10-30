extends Node3D

class Scene extends World:
	var spoken := []
	var effects := []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func say(e: Entity, text: String) -> void:
		spoken.append([e.eid, text])
	func fx_event(event: Array) -> void:
		effects.append(event)

class Trooper extends Soldier:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

var checks := 0
var outcomes := {}


func make_world() -> Scene:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.settings = {"seed": 137, "rust_infantry_motion": true}
	w.nav = Nav.new()
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	w.water.deck.resize(Nav.N * Nav.N)
	w.combat = Combat.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	for z in Nav.N:
		for x in Nav.N:
			var i := z * Nav.N + x
			w.nav.ikind[i] = [Nav.FREE, Nav.SLOW, Nav.LOW][(x / 4) % 3]
			w.terrain.base[i] = [TerrainMap.GROUND, TerrainMap.MUD, TerrainMap.ROAD, TerrainMap.SHALLOW][(z / 4) % 4]
			w.water.deck[i] = int(x % 7 == 0)
	w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods,
		w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh)
	w.nav.finalize()
	assert(w.nav._planner != null and w.terrain._native != null and w.combat._collision != null)
	return w


func add_structure(w: World, id: int, kind: String, p: Vector3, yaw: float) -> Structure:
	var st := Structure.new()
	st.world = w
	st.srv = true
	st.eid = id
	st.skind = kind
	st.position = p
	st.yaw = yaw
	st.rotation.y = yaw
	w.entities[id] = st
	w.add_child(st)
	return st


func make_soldier(w: World, trial: int, start: Vector3, route: PackedVector3Array) -> Soldier:
	var s := Trooper.new()
	s.world = w
	s.eid = 100
	s.srv = true
	s.position = start
	s.rotation.y = trial * 0.37 - 8.0
	s.path = route
	s._stuck_p = start
	s.goal_kind = "cover" if trial % 3 == 0 else "slot"
	s.cover_n = Vector3.RIGHT
	s.move_mode = (trial / 3) % 3
	s.suppression = 40.0 if trial % 2 == 0 else 0.0
	s.backwards = trial % 7 == 0
	s.base_y = 1.7 if trial % 13 == 0 else 0.0
	s.life = Soldier.Life.DOWNED if trial % 11 == 0 else Soldier.Life.ALIVE
	w.entities[s.eid] = s
	w.add_child(s)
	return s


func compare(a: Soldier, b: Soldier, label: String) -> void:
	for key in ["position", "rotation", "_last_dir", "_stuck_p"]:
		assert((a.get(key) as Vector3).distance_to(b.get(key)) < 0.00001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["_stuck_t", "slide_t", "slide_cd", "_bar_t", "_gy_t", "_gy", "door_wait", "_door_t", "peek_t", "next_cover_eval"]:
		assert(absf(float(a.get(key)) - float(b.get(key))) < 0.0000001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["path", "path_i", "_path_pending", "_path_revision", "vaulting", "_bar", "door_kick", "goal_kind", "at_cover", "_shifting"]:
		assert(a.get(key) == b.get(key), "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	assert((a.door_st.eid if a.door_st else 0) == (b.door_st.eid if b.door_st else 0), "Waiting door " + label)
	assert(a.world.rng.state == b.world.rng.state, "Gameplay random cursor " + label)
	assert(a.world.stats == b.world.stats and a.world.spoken == b.world.spoken and a.world.effects == b.world.effects, "Movement events " + label)
	checks += 1


func benchmark(a: Soldier, b: Soldier) -> void:
	var samples := [[], []]
	for round in 8:
		for mode in ([0, 1] if round % 2 == 0 else [1, 0]):
			var s: Soldier = [a, b][mode]
			s.path = PackedVector3Array([Vector3(20, 0, 20)])
			s.path_i = 0
			s._path_pending = false
			var start := Time.get_ticks_usec()
			for i in 1000:
				s.position = Vector3(-20, 0, -20)
				s._stuck_t = 0.0
				s.world.time = i / 30.0
				if mode == 0:
					s._move_tick_reference(1.0 / 30.0, 3.2)
				else:
					s._move_tick_work(1.0 / 30.0, 3.2)
			if round > 1:
				samples[mode].append((Time.get_ticks_usec() - start) / 1000.0)
	print("INFANTRY_MOTION_BENCH steps=1000 gdscript_ms=", samples[0], " rust_ms=", samples[1])


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryMotionCore"))
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var a := make_world()
	var b := make_world()
	var rng := RandomNumberGenerator.new()
	rng.seed = 67185
	for trial in 100:
		var yaw := rng.randf_range(-PI, PI)
		var direction := Defs.dir_of(yaw)
		var start := -direction * (0.6 if trial % 2 == 0 else 8.0)
		var route := PackedVector3Array([Vector3.ZERO, direction * 12.0])
		if trial % 5 == 0:
			route = PackedVector3Array([start, start, direction * 2.0])
		var soldiers: Array[Soldier] = []
		for w in [a, b]:
			w.rng.seed = trial + 177
			w.stats.clear()
			w.spoken.clear()
			w.effects.clear()
			w.time = 0.0
			var door := add_structure(w, 1, "house_wall", Vector3.ZERO, yaw)
			door.door_shut = true
			door.parts = [{"p": Vector3(0, 1, Structure.DOOR_Z), "s": Vector3(1.8, 2, 0.1), "r": 0.0, "col": true, "door": true}]
			door._make_body()
			w.add_door(door)
			var wall := add_structure(w, 2, "low_wall", direction * 3, yaw)
			wall.parts = [{"p": Vector3(0, 0.4, 0), "s": Vector3(20, 0.8, 0.4), "r": 0.0, "col": true}]
			wall._make_body()
			var mount := add_structure(w, 3, ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4], start, yaw)
			var s := make_soldier(w, trial, start, route)
			if trial % 4 == 0:
				s.mounted = mount
				mount.position += start - mount.mount_pos()
			soldiers.append(s)
		for tick in 180:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			for w in [a, b]:
				w.time += dt
				var s: Soldier = w.entity(100)
				s._path_pending = trial % 9 == 0 and tick < 3
				if trial % 10 == 0 and tick == 5:
					s._stuck_t = 3.1
					s._stuck_p = s.position
				if trial % 8 == 0 and tick == 7:
					(w.entity(1) as Structure).open_door(s, false)
			var expected := soldiers[0]._move_tick_reference(dt, 3.2)
			var actual := soldiers[1]._move_tick_work(dt, 3.2)
			assert(expected == actual, "Movement completion trial=%d tick=%d" % [trial, tick])
			compare(soldiers[0], soldiers[1], "trial=%d tick=%d" % [trial, tick])
			if soldiers[1]._motion_core and tick % 23 == 0:
				var saved: PackedByteArray = soldiers[1]._motion_core.checkpoint()
				assert(soldiers[1]._motion_core.restore(saved) and saved == soldiers[1]._motion_core.checkpoint())
			for s in soldiers:
				if s.vaulting:
					outcomes["vault"] = true
				if s.at_cover:
					outcomes["arrive_cover"] = true
		for key in a.stats:
			outcomes[key] = true
		if trial == 99 and "--motion-bench" in OS.get_cmdline_user_args():
			benchmark(soldiers[0], soldiers[1])
		for w in [a, b]:
			w.door_cells.clear()
			for e in w.entities.values():
				w.combat.remove_collision(e.eid)
				e.free()
			w.entities.clear()
	for key in ["door_opened", "door_kicked", "slide", "repath", "arrive_cover", "vault"]:
		assert(outcomes.has(key), "Fixture must exercise " + key)
	a.free()
	b.free()
	print("INFANTRY_MOTION passed steps=", checks, " outcomes=", outcomes)
	get_tree().quit()
