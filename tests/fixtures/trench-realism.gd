extends Node

class ClearCombat extends Combat:
	func ray(_from: Vector3, _to: Vector3, _ex: Array = []) -> Dictionary:
		return {}

class CoverProbe extends Soldier:
	var sought := false
	func _seek_cover(_anchor: Vector3, _radius: float, _threats: Array) -> void:
		sought = true

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func make_trench(w: World, id: int, p: Vector3, finished := false) -> Structure:
	var st := Structure.new()
	st.world = w
	st.srv = true
	st.eid = id
	st.team = 0
	st.skind = "trench"
	st.position = p
	st.built = finished
	st.progress = 1.0 if finished else 0.0
	w.add_child(st)
	w._register(st)
	st.on_spawned()
	w._shash_add(st)
	w.terrain.structure_changed(st)
	return st

func _ready() -> void:
	var w := World.new()
	w.has_view = false
	w.srv = true
	w.nav = Nav.new()
	w.terrain = TerrainMap.new(w)
	w.nav.terrain = w.terrain
	w.combat = ClearCombat.new(w)
	w.rules = Rules.new(w)
	w.battle = BattleStats.new(w)
	var st := make_trench(w, 6, Vector3.ZERO)
	check(w.ground_y(Vector3.ZERO) == 0.0, "Marked ground is not excavated")
	st.add_work(20.0)
	w.terrain.tick(1 << 30)
	var shallow := st.trench_depth()
	check(shallow > 0.0 and shallow < 0.6, "Work produces shallow excavation before completion")
	check(w.ground_y(Vector3.ZERO) < 0.0 and not w.in_trench(Vector3.ZERO), "A shallow scrape does not give full trench protection")
	check(w.terrain.cover_at(Vector3.ZERO) == TerrainMap.LIGHT, "Partial excavation gives light cover")
	var held := st.progress
	w.terrain.tick(1 << 30)
	check(st.progress == held, "Interrupted work persists without progressing")
	st.add_work(40.0)
	w.terrain.tick(1 << 30)
	check(st.built and is_equal_approx(st.trench_depth(), 1.2), "Resumed work completes the excavation")
	check(w.terrain.cover_at(Vector3.ZERO) == TerrainMap.HEAVY, "Completed excavation gives heavy cover")
	check(w.trench_depth(Vector3(3.3, 0, 0)) < 0.3, "An open end ramps to the surface")
	var adjacent := make_trench(w, 2, Vector3(6, 0, 0), true)
	check(is_equal_approx(w.trench_depth(Vector3(3, 0, 0)), 1.2), "Joined ends have no ramp or hump")
	adjacent.built = false
	adjacent.progress = 0.5
	var join_depth := w.trench_depth(Vector3(3, 0, 0))
	check(join_depth > 0.6 and join_depth < 1.2, "Different excavation stages blend across a joined end")
	adjacent.built = true
	var recess := TrenchNet.recess_of(st)
	check(recess.size() == 2 and w.trench_depth(recess[1]) > 1.0, "The rear recess is usable excavated ground")
	for i in st.anc_p.size():
		check(not TrenchNet.inside(st, st.anc_p[i] + st.anc_n[i] * 0.5), "Rear-bay entrances are not offered as parapet cover")
	st.take_damage(1.0)
	check(is_equal_approx(st.trench_depth(), 1.2), "Minor hits do not collapse a finished section")
	var occupant := CoverProbe.new()
	occupant.world = w
	occupant.wdef = Soldier.PISTOL
	occupant.at_cover = true
	occupant.cover_st = st
	occupant.cover_ai = 0
	occupant.cover_pos = st.anc_p[0]
	occupant.cover_h = st.anc_h[0]
	st.take_damage(100000.0)
	occupant._fight_think_work()
	check(occupant.sought, "An occupant reassesses cover after its parapet height changes")
	occupant.free()
	w.terrain.tick(1 << 30)
	check(not st.gone and st.hp == 1.0, "Bombardment cannot erase an excavation")
	check(st.trench_depth() > 0.0 and st.trench_depth() < 0.6, "Collapsed earth locally reduces depth")
	check(is_equal_approx(adjacent.trench_depth(), 1.2), "Damage leaves adjacent sections intact")
	st.add_work(60.0)
	check(st.hp == st.max_hp and is_equal_approx(st.trench_depth(), 1.2), "Clearing restores the damaged section")
	var peer := make_trench(w, 3, Vector3(20, 0, 0))
	for finished in [false, true]:
		for fraction in [0.0, 0.124, 0.125, 0.2498, 0.25, 0.2501, 0.5, 0.75, 0.99, 1.0]:
			st.built = finished
			st.progress = fraction
			st.hp = st.max_hp * fraction if finished else st.max_hp
			var buffer := StreamPeerBuffer.new()
			st.write_state(buffer)
			buffer.seek(0)
			peer.read_state(buffer)
			check(is_equal_approx(st.trench_depth(), peer.trench_depth()), "Snapshots preserve exact excavation and collapse stages")
	peer.built = false
	peer.progress = 0.5
	peer.hp = peer.max_hp
	peer._define_parts()
	var old_height: float = peer.parts[0].s.y
	peer.apply_props({"built": true, "progress": 1.0})
	check(peer.parts[0].s.y > old_height, "Reliable completion properties update collision before the next snapshot")
	st.built = true
	st.hp = st.max_hp
	var workers: Array[Soldier] = []
	for i in 10:
		var man := Soldier.new()
		man.world = w
		man.eid = 10 + i
		man.position = Vector3(-4 + i, 0, 30)
		man.task = "build"
		man.task_ent = st
		man.task_pos = man._work_spot(st)
		for previous in workers:
			check(man.task_pos == Vector3.INF or man.task_pos.distance_to(previous.task_pos) > 0.9, "Workers reserve distinct digging positions")
		workers.append(man)
		w.soldiers.append(man)
		w._hadd(man)
	check(workers[8].task_pos == Vector3.INF, "Surplus workers wait rather than stack on a work station")
	for man in workers:
		man.free()
	w.soldiers.clear()
	w._uhash.clear()
	var left := Soldier.new()
	var right := Soldier.new()
	left.world = w
	right.world = w
	left.eid = 100
	right.eid = 101
	left.position = Vector3(-0.3, 0, 0)
	right.position = Vector3(0.3, 0, 0)
	left.path = PackedVector3Array([Vector3(2, 0, 0)])
	right.path = PackedVector3Array([Vector3(-2, 0, 0)])
	w._hadd(left)
	w._hadd(right)
	w.time = 1.0
	right._move_tick(0.1, 2.0)
	check(right.position.z < 0.0 and right.position.x > 0.2, "The yielding soldier steps aside and slows for approaching traffic")
	var held_position := right.position
	right._sep = Vector3(0, 0, -10)
	right._apply_sep(1.0)
	check(right.position == held_position, "Separation cannot push a resting soldier through the trench wall")
	left.free()
	right.free()
	w._uhash.clear()
	var geology := w.terrain.landform
	geology.heights.resize(geology.n * geology.n)
	for z in geology.n:
		for x in geology.n:
			geology.heights[z * geology.n + x] = 40.0 + (x * Landform.STEP - geology.half) * 0.02
	check(w.ground_y(Vector3.ZERO) > 38.0 and w.in_trench(Vector3.ZERO), "Elevated trenches retain their excavated floor and protection")
	var defender := Soldier.new()
	defender.world = w
	defender.position = Vector3.ZERO
	defender._gy = w.ground_y(defender.position)
	var protected := defender.hit_factor()
	defender.position = Vector3(0, 0, 10)
	check(is_equal_approx(protected, defender.hit_factor() * 0.55), "Protection depends on excavation rather than absolute altitude")
	defender.free()
	var gun := Structure.new()
	gun.world = w
	gun.skind = "hmg_nest"
	gun.variant = 1
	var crew := gun.mount_pos()
	check(is_equal_approx(crew.y, w.ground_y(crew)), "A trench gun crew stands on the actual floor")
	gun.free()
	var network := TrenchNet.new(w)
	add_child(network)
	network.rebuild()
	var arrays := network.floor_mi.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(vertices.size() > 0, "The trench network has a real floor mesh")
	for point in vertices:
		check(absf(point.y - (geology.height(point) - w.trench_depth(point, -0.3))) < 0.0001, "Floor vertices follow the sloped geology and local excavation depth")
	for i in range(0, vertices.size(), 3):
		check((vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).y < 0.0, "Floor triangles face the player rather than exposing the sky")
	st.hp = st.max_hp * 0.3
	network.rebuild()
	var samples := RandomNumberGenerator.new()
	samples.seed = 19
	for i in 600:
		var point := Vector3(samples.randf_range(-4, 10), 0, samples.randf_range(-3, 3))
		for margin in [-0.3, -0.1]:
			check(is_equal_approx(network._draw_depth(point, margin), w.trench_depth(point, margin)), "Cached mesh depths agree with gameplay after local damage")
	network.free()
	var actor := SkinnedRifleman.new()
	add_child(actor)
	actor.shovel = Node3D.new()
	actor.add_child(actor.shovel)
	actor.shovel.position.y = 0.7
	actor._dig_soil(0.1)
	check(actor._dig_loaded and actor.dig_soil.visible, "A low shovel picks up soil")
	actor.shovel.position.y = 1.4
	actor._dig_soil(0.1)
	check(actor._dig_flying, "Lifting the shovel releases the soil")
	for i in 30:
		actor._dig_soil(0.1)
	check(not actor._dig_flying and not actor.dig_soil.visible, "Soil lands and its single mesh is reused")
	actor.free()
	w.free()
	print("TRENCH_REALISM failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
