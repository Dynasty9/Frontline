extends "res://tests/fixtures/vehicle-driving.gd"

func dimensions() -> void:
	MapDims.N = 256
	MapDims.SIZE = 256.0
	MapDims.HALF = 128.0
	MapDims.BIOME = 256
	Nav.N = 256
	Nav.H = 128.0
	HNav.C = 16
	HNav.NC = 16
	TerrainMap.N = 256
	TerrainMap.H = 128.0
	TerrainMap.DN = 512

func setup_water(w: World, mode: int, native: RefCounted) -> RefCounted:
	w.nav = Nav.new()
	w.nav.terrain = w.terrain
	w.water = WaterMap.new(w)
	w.water.rivers = [{"pts": PackedVector3Array([Vector3(0, 0, -128), Vector3(9, 0, 0), Vector3(0, 0, 128)]), "w": 50.0}]
	w.water.deck.resize(Nav.N * Nav.N)
	w.water.deck.fill(0)
	for z in Nav.N:
		for x in Nav.N:
			var solid := x < 3 or z < 3 or x >= Nav.N - 3 or z >= Nav.N - 3
			if mode in [5, 6]: solid = solid or z < 128
			if mode == 8: solid = solid or (x in range(105, 118) and z in range(90, 160))
			if mode == 10: solid = solid or (x < 117 and z in range(110, 180))
			if mode == 11: solid = solid or (x in range(120, 126) and z < 180) or (z in range(160, 168) and x > 140)
			w.terrain.base[z * Nav.N + x] = TerrainMap.GROUND if solid else (TerrainMap.SHALLOW if x % 47 in range(0, 4) else TerrainMap.WATER)
			if mode == 9 and x > 190 and z in range(60, 64): w.water.deck[z * Nav.N + x] = 1
	assert(w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
	w.nav.build_boat_grid(w.water)
	assert(native.configure(w.terrain._native, w.water.deck))
	# The reference search uses Godot's own AStarGrid2D, not the shared Rust search.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, w.nav.boat_n, w.nav.boat_n)
	grid.cell_size = Vector2(2, 2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in w.nav.boat_n:
		for x in w.nav.boat_n:
			var p := Vector2i(x, z)
			grid.set_point_solid(p, w.nav.boat.is_point_solid(p))
			grid.set_point_weight_scale(p, w.nav.boat.get_point_weight_scale(p))
	w.nav.boat = grid
	return w.water._raster_core()

func _ready() -> void:
	dimensions()
	var w := ground_world()
	var native: RefCounted = ClassDB.instantiate("BoatNavigationCore")
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	checks = 0
	for mode in 12:
		setup_water(w, mode, native)
		for i in 256:
			var a := Vector3(rng.randf_range(-140, 140), 3.2, rng.randf_range(-140, 140))
			var b := Vector3(rng.randf_range(-140, 140), -0.7, rng.randf_range(-140, 140))
			assert(native.open(a) == w.nav.boat_ok(a))
			assert(native.body(a) == w.nav.water_body(a))
			var width: float = [0.0, 1.0, 3.7, 8.0][i % 4]
			assert(native.line(a, b, width) == w.nav.boat_line(a, b, width))
			var body: int = -1 if i % 2 == 0 else w.nav.water_body(b)
			var radius: float = [0.0, 10.0, 30.0, 60.0, 160.0][i % 5]
			var nearest: PackedVector3Array = native.nearest(a, radius, body)
			var expected := w.nav.nearest_boat(a, radius, body)
			assert(nearest == (PackedVector3Array() if expected == Vector3.INF else PackedVector3Array([expected])))
			assert(native.path(a, b) == w.nav.find_boat_path(a, b), "Water route %d/%d" % [mode, i])
			if i % 61 == 0:
				var state: PackedByteArray = native.checkpoint()
				assert(native.restore(state) and native.checkpoint() == state)
			checks += 1
	w.free()
	print("BOAT_NAVIGATION passed queries=%d" % checks)
	get_tree().quit()
