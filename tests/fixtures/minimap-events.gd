extends Node

func structure(world: World, kind: String, position := Vector3.ZERO) -> Structure:
	var st := Structure.new()
	st.world = world
	st.eid = world.next_eid
	world.next_eid += 1
	st.skind = kind
	st.position = position
	st.foot = Vector2(16, 16)
	world._register(st)
	world.add_child(st)
	return st

func bake(map: HudMinimap) -> void:
	map._next_sig_ms = 0
	map._check_bake()
	while map._baking:
		await get_tree().process_frame
	assert(not map._static_dirty)

func pixel(map: HudMinimap, position: Vector3, expected: Color) -> void:
	var point := map._to_map(position)
	var color := map._static.get_image().get_pixel(int(point.x), int(point.y))
	assert(absf(color.r - expected.r) < 0.01 and absf(color.g - expected.g) < 0.01 and absf(color.b - expected.b) < 0.01)

func _ready() -> void:
	var world := World.new()
	world.loaded = true
	var hud := Hud.new()
	hud.world = world
	var map := HudMinimap.new()
	map.hud = hud
	map.size = Vector2(HudMinimap.N, HudMinimap.N)
	map.hide()
	add_child(map)
	map._base = Image.create(HudMinimap.N, HudMinimap.N, false, Image.FORMAT_RGB8)
	map._base.fill(Color.BLACK)
	map._ground = map._base.duplicate()
	map._static = ImageTexture.create_from_image(map._ground)
	map._road_sig = 0
	map._static_dirty = false
	var original := map._static
	for i in 300:
		structure(world, "house_wall")
	await bake(map)
	assert(map._static == original, "Unchanged scenery must not repaint the map")
	structure(world, "floor")
	var roof := structure(world, "roof")
	var second := structure(world, "floor", Vector3(100, 0, 0))
	assert(map._static_dirty, "Registry births invalidate the baked layer")
	await bake(map)
	pixel(map, Vector3.ZERO, HudMinimap.C_ROOF)
	pixel(map, second.position, HudMinimap.C_RUIN)
	original = map._static
	world.despawn(roof)
	structure(world, "roof", second.position)
	map._check_bake()
	assert(map._static == original and map._static_dirty, "Destruction is coalesced until the next refresh")
	await bake(map)
	pixel(map, Vector3.ZERO, HudMinimap.C_RUIN)
	pixel(map, second.position, HudMinimap.C_ROOF)
	assert(map._static != original, "Equal roof counts must not hide a different destroyed building")
	second.team = 0
	assert(map._static_dirty, "Ownership changes update neutral footprints")
	await bake(map)
	pixel(map, second.position, Color.BLACK)
	second.team = -1
	await bake(map)
	pixel(map, second.position, HudMinimap.C_ROOF)
	second.team = -1
	assert(not map._static_dirty, "Repeated observations of the same owner do not repaint scenery")
	var tree := structure(world, "tree", Vector3(200, 0, 200))
	world.despawn(tree)
	assert(not map._static_dirty, "Trees retain the existing deferred update policy")
	world.roads[2].append(PackedVector3Array([Vector3(-100, 0, -100), Vector3(100, 0, -100)]))
	await bake(map)
	pixel(map, Vector3(0, 0, -100), HudMinimap.C_ROAD)
	await get_tree().process_frame
	roof.free()
	tree.free()
	map.free()
	hud.free()
	world.free()
	print("MINIMAP_EVENTS passed")
	get_tree().quit()
