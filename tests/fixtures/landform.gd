extends Node

class ClearCombat extends Combat:
	func ray(_from: Vector3, _to: Vector3, _ex: Array = []) -> Dictionary:
		return {}


func _ready() -> void:
	assert(MapGen.alpine_dressing(0.15, 0.1, 0.8) == "alpine_scrub")
	assert(MapGen.alpine_dressing(0.55, 0.1, 0.8) == "alpine_stones")
	assert(MapGen.alpine_dressing(0.2, 0.6, 0.8) == "alpine_stones")
	assert(MapGen.alpine_dressing(0.8, 0.1, 0.8) == "")
	assert(MapGen.alpine_dressing(0.2, 1.2, 0.8) == "")
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var world := World.new()
	world.settings = {"seed": 3}
	world.terrain = TerrainMap.new(world)
	world.water = WaterMap.new(world)
	var previous_half := MapDims.HALF
	MapDims.HALF = 32.0
	world.terrain.landform.heights.resize(world.terrain.landform.n * world.terrain.landform.n)
	world.terrain.landform.heights.fill(8.0)
	world.terrain.landform.peak = 30.0
	var scatter_a: Array = []
	var scatter_b: Array = []
	var gen := MapGen.new(world)
	gen._alpine_scatter(scatter_a, 1.0)
	gen._alpine_scatter(scatter_b, 1.0)
	assert(not scatter_a.is_empty() and scatter_a.size() <= 65, "Dressing is bounded and populated")
	assert(scatter_a == scatter_b, "Dressing placement is seeded independently of simulation RNG")
	for entry in scatter_a:
		assert(is_equal_approx(entry[1].y, 7.92), "Dressing follows the authoritative ground")
	MapDims.HALF = previous_half
	world.terrain.landform.heights = PackedFloat32Array()
	world.terrain.landform.peak = 0.0
	var atmosphere := Atmosphere.new()
	atmosphere.world = world
	atmosphere._surface_baked = true
	var reflections_before: bool = Settings.get_v("terrain_reflections")
	Settings.v.terrain_reflections = true
	atmosphere._update_terrain_probe()
	var capture := atmosphere._terrain_probe
	assert(capture != null and capture.cull_mask == 4 and capture.update_mode == ReflectionProbe.UPDATE_ONCE, "Reflections capture static terrain once")
	atmosphere._update_terrain_probe()
	assert(atmosphere._terrain_probe == capture, "Steady settings reuse the capture")
	atmosphere._update_terrain_probe(true)
	assert(atmosphere._terrain_probe != capture, "Lighting changes refresh the capture")
	Settings.v.terrain_reflections = false
	atmosphere._update_terrain_probe()
	assert(atmosphere._terrain_probe == null, "Disabling reflections releases the probe")
	Settings.v.terrain_reflections = reflections_before
	atmosphere.free()
	var geology := Landform.new(64)
	geology.generate(3, [[], [], []], world.water, [])
	var repeat := Landform.new(64)
	repeat.generate(3, [[], [], []], world.water, [])
	assert(geology.heights == repeat.heights, "Seeded terrain must reproduce exactly")
	repeat.generate(9, [[], [], []], world.water, [])
	assert(geology.heights != repeat.heights, "Seeds must produce different terrain")
	assert(Landform.valid(geology.heights, 64))
	var campaign := Landform.new(64)
	campaign.generate(3, [[], [], []], world.water, [], false)
	assert(campaign.heights != geology.heights and Landform.valid(campaign.heights, 64), "Campaigns retain their authored relief recipe")
	assert(not Landform.valid(PackedFloat32Array([NAN]), 64))
	var invalid := geology.heights.duplicate()
	invalid[0] = INF
	assert(not Landform.valid(invalid, 64))
	var forms_a := Landform.new(256)
	forms_a.heights.resize(forms_a.n * forms_a.n)
	forms_a.heights.fill(80.0)
	var forms_b := Landform.new(256)
	forms_b.heights = forms_a.heights.duplicate()
	forms_a._place_forms(3)
	forms_b._place_forms(3)
	assert(forms_a.heights == forms_b.heights, "Baked rock forms place deterministically")
	assert(Array(forms_a.heights).min() < 75.0 and Array(forms_a.heights).max() > 85.0, "Forms carve valleys and build rock masses, not just recolour ground")
	assert(Landform.valid(forms_a.heights, 256))
	for name in ["buttress", "cirque", "saddle"]:
		var form: PackedFloat32Array = Landform.FORMS.get_meta(name)
		assert(form.size() == 33 * 33 and Array(form).min() >= 0.0 and Array(form).max() <= 1.0)
	for name in ["rock_face_03", "aerial_rocks_02", "aerial_grass_rock"]:
		for suffix in ["color_height", "surface"]:
			var tex: Texture2D = load("res://assets/terrain/%s_%s.png" % [name, suffix])
			var img := tex.get_image()
			assert(img.get_size() == Vector2i(1024, 1024) and img.has_mipmaps(), "Packed relief textures keep distance filtering")
			assert(img.get_format() == Image.FORMAT_RGBA8, "Height and roughness alpha must survive import")
	var corridor := Landform.new(256)
	corridor.generate(3, [[PackedVector3Array([Vector3(-100, 0, 0), Vector3(100, 0, 0)])]], world.water, [[Vector3(0, 0, 60), 12.0]])
	assert(corridor.peak > 5.0, "Reserved maps still contain hills")
	for x in range(-100, 101, 4):
		assert(is_zero_approx(corridor.height(Vector3(x, 0, 0))), "Roads have a continuous graded corridor")
	assert(corridor.fits(Vector3(0, 0, 60), Vector2(10, 10), 0.0), "Settlements retain level building ground")
	# A known ridge separates two level firing positions, with a gentle west ramp.
	var heights := PackedFloat32Array()
	heights.resize(17 * 17)
	for z in 17:
		for x in 17:
			var wx := x * 4.0 - 32.0
			heights[z * 17 + x] = 12.0 * maxf(0.0, 1.0 - absf(wx) / 12.0)
	var flat := Landform.new(64).bake_surface()
	assert(flat.get_pixel(3, 3).r > 0.99 and absf(flat.get_pixel(3, 3).g - 0.5) < 0.01, "Flat terrain has open sky and no concavity")
	world.terrain.install_landform(heights)
	var baked := world.terrain.landform.bake_surface()
	assert(baked.get_data() == world.terrain.landform.bake_surface().get_data(), "Surface baking is deterministic")
	assert(world.terrain.landform.heights == heights, "Baking must not change gameplay geography")
	assert(baked.get_pixel(2, 4).r < 0.97, "A nearby ridge reduces valley sky light")
	var low_sun := world.terrain.landform.bake_surface(Vector3(1, 0.3, 0).normalized())
	assert(low_sun.get_pixel(2, 4).b < 0.1 and low_sun.get_pixel(6, 4).b > 0.9, "Baked sunlight casts a ridge shadow on its sheltered side")
	assert(is_equal_approx(world.ground_y(Vector3.ZERO), 11.75))
	var hit := world.terrain.ray_ground(Vector3(-20, 1.5, 0), Vector3(20, 1.5, 0))
	assert(not hit.is_empty() and hit.position.x < 0.0, "A ridge must block sight and bullets")
	assert(world.terrain.ray_ground(Vector3(-20, 15, 0), Vector3(20, 15, 0)).is_empty())
	world.rules = Rules.new(world)
	var enemy := Soldier.new()
	enemy.world = world
	enemy.team = 1
	enemy.position = Vector3(20, 0, 0)
	var observers := [{}, {}]
	world.rules._add_obs(observers[0], Vector3(-20, 1.5, 0), 60.0)
	world.rules._vis_ent(enemy, observers)
	assert((enemy.vis_mask & 1) == 0, "Fog of war must not reveal enemies through ridges")
	enemy.free()
	assert(not world.terrain.landform.fits(Vector3(-8, 0, 0), Vector2(3, 3), 0.0))
	assert(world.terrain.landform.fits(Vector3(-24, 0, 0), Vector2(2, 2), 0.0))
	world.nav = Nav.new()
	world.nav.terrain = world.terrain
	var steep := world.terrain.idx_of(Vector3(-8, 0, 0))
	world.nav.terrain_changed(steep)
	assert(not world.nav.walkable(Vector3(-8, 0, 0)))
	assert(world.nav.vkind_at(Vector3(-8, 0, 0)) == Nav.SOLID)
	var soldier := Soldier.new()
	soldier.world = world
	soldier.position = Vector3(0, 0, 0)
	for i in 90:
		soldier._settle_y(1.0 / 30.0)
	assert(absf(soldier.position.y - world.ground_y(soldier.position)) < 0.01, "Infantry settle onto a ridge")
	soldier.position.x = -5.0
	for i in 90:
		soldier._settle_y(1.0 / 30.0)
	assert(absf(soldier.position.y - world.ground_y(soldier.position)) < 0.01, "Infantry update height after moving downhill")
	soldier.dive_t = 0.5
	soldier.dive_dir = Vector3.ZERO
	soldier._alive(1.0 / 30.0)
	assert(soldier.position.y >= world.ground_y(soldier.position), "Diving infantry cannot sink into elevated ground")
	soldier.free()
	var truck := Vehicle.new()
	truck.world = world
	truck.vkind = "supply"
	truck.position = Vector3(-13, 0, 0)
	world.nav.terrain_changed(world.terrain.idx_of(Vector3(-11, 0, 0)))
	truck._move_by(Vector3(2, 0, 0), 1.0)
	assert(truck.position.x <= -12.0, "Supply trucks cannot bypass an impassable mountain slope")
	# Give the hull a real elevated plateau, rather than a knife-edge ridge.
	var plateau := World.new()
	plateau.settings = {"seed": 3}
	plateau.terrain = TerrainMap.new(plateau)
	plateau.water = WaterMap.new(plateau)
	var level := heights.duplicate()
	level.fill(12.0)
	plateau.terrain.install_landform(level)
	plateau.nav = Nav.new()
	plateau.nav.terrain = plateau.terrain
	truck.world = plateau
	truck.position = Vector3(0, 12, 0)
	plateau.nav.terrain_changed(plateau.terrain.idx_of(Vector3(0, 0, 2)))
	truck._move_by(Vector3(0, 0, 2), 1.0)
	assert(truck.position.z > 1.9 and is_equal_approx(truck.position.y, 12.0), "Vehicles traverse level elevated ground")
	truck.free()
	plateau.free()
	var heli := Vehicle.new()
	heli.world = world
	heli.vkind = "hummingbird"
	heli.vdef = {"speed": 22.0, "turn": 1.8}
	heli.flight = HelicopterFlight.new()
	heli.position = Vector3(-24, 16, 0)
	var crossed := false
	for i in 30 * 45:
		heli._fly_to(Vector3(24, 16, 0), 1.0 / 30.0)
		assert(heli.position.y >= world.ground_y(heli.position) + 0.14, "Rotorcraft must stay above a crossed ridge")
		crossed = crossed or heli.position.x > 20.0
	assert(crossed, "Terrain clearance must not strand a helicopter in its climb")
	heli.position = Vector3(0, 25, 0)
	heli.velocity = Vector3.ZERO
	for i in 30 * 12:
		heli._fly_to(Vector3(0, world.ground_y(Vector3.ZERO) + 0.15, 0), 1.0 / 30.0)
	assert(absf(heli.position.y - world.ground_y(heli.position) - 0.15) < 0.02, "Touchdown is relative to elevated terrain")
	heli.free()
	var trench := Structure.new()
	trench.eid = 101
	trench.skind = "trench"
	trench.built = true
	trench.position = Vector3(0, 12, 0)
	trench.size = Vector3(6, 3, 3.2)
	trench.foot = Vector2(3, 1.6)
	world._shash_add(trench)
	assert(is_equal_approx(world.ground_y(Vector3.ZERO), 12.0 + TrenchNet.FLOOR_Y + 0.15), "Trenches are dug below local ground")
	world.combat = ClearCombat.new(world)
	var frag := Projectile.new()
	frag.world = world
	frag.ptype = "frag"
	frag.fuse = 100.0
	frag.flying = true
	frag.position = Vector3(0, 13, 0)
	for i in 120:
		frag._ballistic(1.0 / 30.0)
	assert(absf(frag.position.y - world.ground_y(frag.position) - 0.06) < 0.01, "Grenades settle on the elevated trench floor")
	frag.free()
	world._shash_remove(trench)
	trench.free()
	var shell := Projectile.new()
	shell.world = world
	shell.srv = true
	shell.ptype = "mortar"
	shell.target = Vector3.ZERO
	shell.on_spawned()
	assert(is_equal_approx(shell.get_props().target.y, world.ground_y(Vector3.ZERO)), "Shell elevation is set before its trajectory is replicated")
	shell.free()
	var before := world.ground_y(Vector3.ZERO)
	world.terrain.add_crater(Vector3(0, before, 0), 2.0)
	var after := world.ground_y(Vector3.ZERO)
	assert(after < before and after > before - 1.5, "Shells dig relative to the ridge, not down to sea level")
	assert(is_equal_approx(world.terrain.landform.height(Vector3.ZERO), 12.0))
	# The network representation must preserve the exact geology, not regenerate a new seed.
	var restored: PackedFloat32Array = World._unpack(World._pack(heights))
	assert(restored == heights)
	world.free()
	print("LANDFORM passed: generation, determinism, validation, grounding, sight, slope navigation, craters, replication")
	get_tree().quit()
