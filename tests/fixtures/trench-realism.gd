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
	var terrain_layers := Atmosphere.terrain_materials()
	for material in [network.wall_mat, network.berm_mat, network.floor_mat, TrenchNet.bank_material()]:
		check(material.get_shader_parameter("earth_colors") == terrain_layers[0], "Earthworks reuse the battlefield's photographic colour layers")
		check(material.get_shader_parameter("earth_surfaces") == terrain_layers[1], "Earthworks retain packed normal, occlusion and roughness data")
	for i in 100:
		var sample := Vector3(i * 0.73, 0.0, i * -0.41)
		check(absf(TrenchNet.edge_erosion(sample)) <= 0.111, "Cosmetic edge erosion stays outside the clear walking route")
		var rim := TrenchNet.rim_height(sample, 1.2)
		check(rim >= 0.02 and rim <= 0.1, "Loose rim clods stay below ten centimetres and above the intact ground")
		check(is_equal_approx(TrenchNet.rim_height(sample, 0.0), 0.02), "An unexcavated mark has no raised soil clods")
	for i in 100:
		var sample := Vector3(i * 0.37, 30.0, i * -0.29)
		check(is_zero_approx(TrenchNet.cut_relief(sample, 0.0)) and is_zero_approx(TrenchNet.cut_relief(sample, 1.0)), "Cut relief meets the rim and authoritative floor without seams")
		for depth in [0.2, 0.4, 0.6, 0.8]:
			var relief := TrenchNet.cut_relief(sample, depth)
			check(relief >= 0.0 and relief <= 0.081, "Earth clods stay within eight centimetres of the cut and clear of the walking route")
	for heading in [0.0, 0.7, 2.2]:
		var shoring := Node3D.new()
		var shoring_rng := RandomNumberGenerator.new()
		shoring_rng.seed = 37
		var original_yaw: float = st.yaw
		st.yaw = heading
		WorksModels.trench_shoring(st, shoring, shoring_rng)
		check(shoring.get_child_count() > 0 and shoring.get_child_count() <= 60, "Shoring uses a bounded number of pieces before the static mesh merge")
		for piece: MeshInstance3D in shoring.get_children():
			var bounds := piece.transform * piece.mesh.get_aabb()
			check(absf(piece.position.z) > 0.40, "Retaining timber leaves the central walking route clear")
			check(bounds.position.x >= -st.size.x * 0.5 and bounds.end.x <= st.size.x * 0.5, "Retaining panels stay between the end traverses")
		st.yaw = original_yaw
		shoring.free()
	for rear_bank in [false, true]:
		var bank := WorksModels._bank_mesh(2.8, 1.0, 2.0, rear_bank)
		var bank_arrays := bank.surface_get_arrays(0)
		var bank_points: PackedVector3Array = bank_arrays[Mesh.ARRAY_VERTEX]
		var bank_normals: PackedVector3Array = bank_arrays[Mesh.ARRAY_NORMAL]
		check(bank_points.size() > 1500 and bank_points.size() <= 3072, "Continuous bunker banks have a bounded triangle budget")
		for i in bank_points.size():
			check(bank_points[i].is_finite() and bank_normals[i].y > 0.0, "Bank corners keep finite upward-facing normals")
		for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
			check(WorksModels._bank_point(0.0, t, 2.8, 1.0, 2.0, rear_bank).y < 0.0, "The bunker approach stays clear of its bank")
	check(TrenchNet.bank_material(true).get_shader_parameter("trench_mask") == network.tex, "Ground banks share the current world trench mask")
	check(TrenchNet.bank_material(true).get_shader_parameter("cut_trench") and not TrenchNet.bank_material().get_shader_parameter("cut_trench"), "Excavation cuts bank toes but leaves roof soil intact")
	var bank_center := Vector3(30, 0, 30)
	bank_center.y = geology.height(bank_center)
	for heading in [0.0, 0.7, 2.2]:
		var foundation := Transform3D(Basis(Vector3.UP, heading), bank_center)
		for i in 64:
			var angle := i * TAU / 64.0
			var toe := WorksModels._bank_ground_point(angle, 1.0, 2.8, 1.0, 2.0, true, w, foundation)
			var contact := foundation * toe
			check(absf(contact.y - geology.height(contact) + 0.025) < 0.0001, "Bunker bank toes meet elevated sloping ground at every heading")
			var lip := WorksModels._bank_ground_point(angle, 0.0, 2.8, 1.0, 2.0, true, w, foundation)
			check(lip == WorksModels._bank_point(angle, 0.0, 2.8, 1.0, 2.0, true), "Grounding leaves the bank against the level bunker foundation")
	for variant in 4:
		var roof := WorksModels.roof_soil(variant)
		check(roof == WorksModels.roof_soil(variant), "Bunker caps reuse their mesh instead of allocating per building")
		var roof_arrays := roof.surface_get_arrays(0)
		var roof_vertices: PackedVector3Array = roof_arrays[Mesh.ARRAY_VERTEX]
		var roof_normals: PackedVector3Array = roof_arrays[Mesh.ARRAY_NORMAL]
		check(roof_vertices.size() > 1200 and roof_vertices.size() <= 2400, "The roof cap has a bounded triangle budget")
		for i in roof_vertices.size():
			var point := roof_vertices[i]
			check(is_equal_approx(point.y, WorksModels.roof_soil_height(Vector2(point.x, point.z), variant)), "Roof bags and the earth cap share a support surface")
			check(point.y >= -0.141 and point.y < 0.7 and roof_normals[i].y > 0.0, "Earth cap stays over its roof and faces upward")
	var arrays := network.floor_mi.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(vertices.size() > 0, "The trench network has a real floor mesh")
	for point in vertices:
		check(absf(point.y - (geology.height(point) - w.trench_depth(point, -0.3))) < 0.0001, "Floor vertices follow the sloped geology and local excavation depth")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(indices.size() > vertices.size(), "Floor triangles share their coincident corners")
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		check((b - a).cross(c - a).y < 0.0, "Floor triangles face the player rather than exposing the sky")
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
	var mound_ring: Array = [Vector3(0,0,0), Vector3(1,0.1,0), Vector3(1,0.2,1), Vector3(0,0.1,1), Vector3(0,0,0)]
	var seam_normal := TrenchNet._berm_normal(mound_ring, 0, Vector3(-1,0.2,-1), true)
	check(seam_normal.is_equal_approx(TrenchNet._berm_normal(mound_ring, 4, Vector3(-1,0.2,-1), true)), "Closed spoil strips share their lighting across the seam")
	check(seam_normal.y > 0.0 and is_equal_approx(seam_normal.length(), 1.0), "Spoil lighting follows an upward unit surface normal")
	check(TrenchNet._berm_normal([Vector3.ZERO,Vector3.ZERO], 0, Vector3.ZERO, false) == Vector3.UP, "Collapsed mound spans keep a finite normal")
	var joined_world := World.new()
	joined_world.has_view = false
	joined_world.srv = true
	joined_world.nav = Nav.new()
	joined_world.terrain = TerrainMap.new(joined_world)
	joined_world.nav.terrain = joined_world.terrain
	var first_cut := make_trench(joined_world, 91, Vector3.ZERO, true)
	first_cut._build_model()
	var original_furnishings := first_cut.model.get_node("Done")
	first_cut.refresh_trench_furnishings()
	check(first_cut.model.get_node("Done") == original_furnishings, "Unchanged neighbors reuse the existing furnishings")
	var backing := Vector3(2, 0, 1.05)
	check(WorksModels.trench_backed(first_cut, backing, 0.4), "An isolated parapet retains its bags and timber")
	var parallel_cut := make_trench(joined_world, 92, Vector3(0, 0, 1.2), true)
	first_cut.refresh_trench_furnishings()
	check(first_cut.model.get_node("Done") != original_furnishings and original_furnishings.is_queued_for_deletion(), "A newly joined cut rebuilds and retires the old furnishings")
	check(not WorksModels.trench_backed(first_cut, backing, 0.4), "A joined parallel excavation removes unsupported parapet furnishings")
	check(WorksModels.trench_backed(first_cut, Vector3(2, 0, -1.05), 0.4), "Joining one side preserves the opposite retaining wall")
	parallel_cut.hp = 1.0
	check(not WorksModels.trench_backed(first_cut, backing, 0.4), "A collapsed but still excavated neighbor cannot support floating bags")
	parallel_cut.gone = true
	check(WorksModels.trench_backed(first_cut, backing, 0.4), "Removing the neighboring cut restores the backing")
	var partial_join := make_trench(joined_world, 94, Vector3(-1.2, 0, -1.2))
	partial_join.progress = 0.25
	var ramp_backing := Vector3(2, 0, -1.05)
	check(joined_world.trench_depth(ramp_backing) < 0.15, "The joining-ramp regression begins with a shallow excavation")
	check(not WorksModels.trench_backed(first_cut, ramp_backing, 0.1), "Digging a joining footprint clears kit over its future ramp")
	first_cut.refresh_trench_furnishings()
	var partial_furnishings := first_cut.model.get_node("Done")
	partial_join.built = true
	partial_join.progress = 1.0
	first_cut.refresh_trench_furnishings()
	check(first_cut.model.get_node("Done") == partial_furnishings, "Finishing the joining cut does not reshuffle already-cleared furnishings")
	joined_world.free()
	w.free()
	print("TRENCH_REALISM failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
