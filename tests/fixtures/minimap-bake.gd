extends Node

func _ready() -> void:
	Sfx._ensure()
	var world := World.new()
	var hud := Hud.new()
	hud.world = world
	var map := HudMinimap.new()
	map.hud = hud
	# Keep drawing disabled; exercise the real incremental bake directly.
	map.hide()
	add_child(map)
	map._ground = Image.create(HudMinimap.N, HudMinimap.N, false, Image.FORMAT_RGB8)
	map._ground.fill(Color.BLACK)
	map._static = ImageTexture.create_from_image(map._ground)
	var old := map._static
	for i in 12000:
		var wall := Structure.new()
		wall.skind = "house_wall"
		world.structures.append(wall)
	var floor := Structure.new()
	floor.skind = "floor"
	floor.foot = Vector2(16, 16)
	world.structures.append(floor)
	var roof := Structure.new()
	roof.skind = "roof"
	world.structures.append(roof)
	world.srv = false
	world.loaded = false
	map._check_bake()
	assert(not map._baking and map._static == old, "Loading must not repeatedly bake incomplete map data")
	world.loaded = true
	map._bake_static()
	assert(map._baking and map._static == old, "Large bakes must yield while retaining the complete map")
	var removed: Structure = world.structures.pop_front()
	removed.free()
	map.rebake(true)
	map._ground = Image.create(HudMinimap.N, HudMinimap.N, false, Image.FORMAT_RGB8)
	map._ground.fill(Color.BLUE)
	world.structures.erase(roof)
	roof.free()
	while map._baking:
		await get_tree().process_frame
	assert(map._static_dirty, "Changes during a bake must request another pass")
	map._bake_static()
	while map._baking:
		await get_tree().process_frame
	assert(not map._static_dirty)
	var image := map._static.get_image()
	assert(image.get_pixel(0, 0).is_equal_approx(Color.BLUE), "The replacement must use the newly baked ground")
	var ruin := image.get_pixel(256, 256)
	assert(absf(ruin.r - HudMinimap.C_RUIN.r) < 0.01 and absf(ruin.g - HudMinimap.C_RUIN.g) < 0.01 and absf(ruin.b - HudMinimap.C_RUIN.b) < 0.01, "Destroyed roofs must reveal the ruined footprint")
	for structure in world.structures:
		structure.free()
	map.free()
	hud.free()
	world.free()
	print("MINIMAP_BAKE passed")
	get_tree().quit()
