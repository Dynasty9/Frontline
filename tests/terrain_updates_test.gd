extends Node
## Craters crossing a texture or collision boundary must update both sides.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var atmosphere := Atmosphere.new()
	for spacing in [0.5, 2.0]:
		var mesh := atmosphere._grid_mesh(63.02, spacing)
		check(is_equal_approx(mesh.get_aabb().size.x, 63.02) and is_equal_approx(mesh.get_aabb().size.z, 63.02), "Every ground detail level must cover its entire tile")
	atmosphere.free()
	var source := Image.create(1024, 1024, false, Image.FORMAT_RH)
	source.set_pixel(511, 300, Color(-0.5, 0, 0))
	source.set_pixel(512, 300, Color(-0.75, 0, 0))
	var tiles := TerrainTexture.new(source)
	var left := tiles.patch(Vector2i.ZERO)
	var right := tiles.patch(Vector2i(1, 0))
	check(left.get_pixel(513, 301).r == right.get_pixel(1, 301).r, "Right border must match its neighbouring interior")
	check(left.get_pixel(512, 301).r == right.get_pixel(0, 301).r, "Left border must match its neighbouring interior")
	tiles.mark_dirty(Rect2i(511, 300, 2, 1))
	check(tiles.pending.size() == 2, "A seam crater must queue both layers")
	tiles.flush(1)
	check(tiles.pending.size() == 1, "Uploads must obey the layer budget")
	tiles.flush(1)
	check(tiles.pending.is_empty(), "Queued layers must eventually finish")
	var world := World.new()
	world.has_view = false
	world.terrain = TerrainMap.new(world)
	var fx := PhysicsFx.new(world)
	# Build only the two tiles under test, without starting the game or camera.
	var crater := Vector3(-MapDims.HALF + 32, 0, -MapDims.HALF + 16)
	world.terrain.add_crater(crater, 2.0)
	fx._rebuild_ground_tile(Vector2i.ZERO)
	fx._rebuild_ground_tile(Vector2i(1, 0))
	var a: PackedFloat32Array = fx._ground_tiles[Vector2i.ZERO].shape.map_data
	var b: PackedFloat32Array = fx._ground_tiles[Vector2i(1, 0)].shape.map_data
	check(a.size() == 1089 and b.size() == 1089, "Collision updates must stay inside 33 by 33 samples")
	check(a[16 * 33 + 32] < 0 and a[16 * 33 + 32] == b[16 * 33], "Collision tiles must share identical crater edges")
	fx.update_ground(PackedByteArray(), Rect2(Vector2(crater.x, crater.z), Vector2.ONE))
	check(fx._ground_dirty.size() == 2, "Both collision edges must refresh")
	fx.free()
	world.free()
	print("TERRAIN_UPDATES_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
