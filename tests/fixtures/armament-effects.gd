extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	TestRun.watch()
	Settings.v.effects = 2
	Vfx.gl = "--cpu-effects" in OS.get_cmdline_user_args()
	var field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var v: Vfx = field.fx.vfx
	# Check the imported data, not just the presence of source PNG files. A
	# texture importer that discards transparent RGB silently breaks relighting.
	for maps: Array in v.blasts._textures.values():
		var bounds: Texture2D = maps[3]
		check(bounds.get_width() == 128 and bounds.get_height() == 1, "Bounds cover 64 frames and two camera elevations")
		for texture: Texture2D in maps:
			check(texture != null, "Every animation map imports")
			if texture == null: continue
			if texture != bounds:
				check(texture.get_width() == 4096 and texture.get_height() == 2048, "Shipping atlases retain 256-pixel frames")
			var image := texture.get_image()
			check(image != null and not image.is_empty(), "Animation data survives texture import")
			if image == null or image.is_empty(): continue
			if image.is_compressed():
				check(image.decompress() == OK, "Compressed animation data can be inspected")
			var signal_sum := 0.0
			for y in range(0, image.get_height(), 32):
				for x in range(0, image.get_width(), 32):
					var pixel := image.get_pixel(x, y)
					signal_sum += pixel.r + pixel.g + pixel.b
			check(signal_sum > 1.0, "Lighting and motion channels retain their data")
			if texture == maps[0]:
				var view_difference := 0.0
				var half_width := image.get_width() >> 1
				for y in range(0, image.get_height(), 32):
					for x in range(0, half_width, 32):
						var low_pixel := image.get_pixel(x, y)
						var high_pixel := image.get_pixel(x + half_width, y)
						view_difference += absf(low_pixel.a - high_pixel.a) + absf(low_pixel.r - high_pixel.r)
				check(view_difference > 1.0, "Shipping atlases contain distinct elevation views, not duplicated previews")
	field.floor_height = 40.0
	var p := Vector3(0, 40.1, 0)
	v.crater(p, 1.4)
	check(is_equal_approx((v._craters[-1] as Decal).global_position.y, 40.0), "Fallback crater decals follow elevated ground")
	check((v._craters[-1] as Decal).cull_mask == Res.GROUND_DECAL_LAYER, "Crater marks project only onto terrain receivers")
	v.scorch(p, 3.0)
	check((v._decals[-1][0] as Decal).cull_mask == Res.GROUND_DECAL_LAYER, "Scorch marks cannot project onto default-layer walls or effects")
	v.explode(p, 1.0, "frag")
	var frag: Node3D = v._rigs.s[0]
	var fl: Dictionary = frag.get_meta("layers")
	var dust: BlastFlipbooks.Blast = v.blasts._pools.dust[0]
	check(is_equal_approx(dust.mesh.global_position.y, 40.04), "Grenade dust anchors to elevated ground")
	check(dust.mesh.visible, "Grenades use the baked dust animation")
	check(not fl.has("flaming"), "Grenades must not use burning fragment layers")
	v.explode(p, 1.4, "fuel")
	var shell: Node3D = v._rigs.m[0]
	var layers: Dictionary = shell.get_meta("layers")
	check(layers.flaming.visible and layers.afterburn.visible, "Fuel burns after the blast")
	shell.set_meta("t", -1000.0)
	v.explode(p, 1.4, "he")
	check(v._rigs.m.size() == 1, "An idle rig is reused")
	check(v.blasts._pools.dust.size() == 2, "Shells use a separate baked ground burst")
	check(not layers.flaming.visible and not layers.afterburn.visible, "HE must clear recycled fuel flames")
	shell.set_meta("t", -1000.0)
	var flash_index: int = field.fx.gunfx._fl.i
	v.explode(p + Vector3.UP * 8.0, 1.4, "he")
	check(not layers.afterburn.visible and not layers.flaming.visible, "Airbursts clear recycled ground flames")
	check(field.fx.gunfx._fl.i == (flash_index + 1) % field.fx.gunfx._fl.mm.instance_count, "Airbursts immediately queue their brief flash in the shared batch")
	check(not layers.flash.visible, "A batched flash does not double up with a delayed particle flash")
	var air: BlastFlipbooks.Blast = v.blasts._pools.fuel[-1]
	check(is_equal_approx(float(air.material.get_shader_parameter("fuel")), 0.0), "HE airbursts never inherit fuel emission")
	check(is_equal_approx(air.mesh.global_position.y, p.y + 8.0), "Airbursts stay at their altitude")
	v._fire_layer(layers.sparks, 0.0, 0.0)
	check(not layers.sparks.visible and not Vfx.is_emitting(layers.sparks), "Zero-budget layers stop")
	var child_count: int = field.fx.gunfx.get_child_count()
	for i in 30:
		field.fx.gunfx.blast_fragments(p, 1.4, "he", true, 1.0)
	check(field.fx.gunfx.get_child_count() == child_count, "Fragments and landing dust create no scene nodes")
	check(is_equal_approx(field.fx.gunfx.ground_y(p), 40.0), "Batched fragments use the world's elevated ground contact")
	# The dummy renderer doesn't retain MultiMesh instance data.
	if DisplayServer.get_name() != "headless":
		var ring: GunFx.Ring = field.fx.gunfx._ch
		var last := (ring.i + ring.mm.instance_count - 1) % ring.mm.instance_count
		check(is_equal_approx(ring.mm.get_instance_custom_data(last).a, 40.0), "Batched clods store their elevated landing height")
	for i in int(Vfx.MAX_RIGS.m) + 8:
		v.explode(p, 1.4, "he")
	check(v._rigs.m.size() <= int(Vfx.MAX_RIGS.m), "A barrage has a bounded rig pool")
	for i in 80:
		v.blasts.burst(p, 1.4, "he", 1.0)
	check(v.blasts._pools.dust.size() <= int(BlastFlipbooks.CAPACITY.dust * Settings.fx_mult()), "A barrage has a bounded animation pool")
	var pool_nodes := v.blasts.get_child_count()
	for i in 30:
		v.blasts.burst(p, 1.4, "he", 1.0)
	check(v.blasts.get_child_count() == pool_nodes, "Saturated animation pools reuse their surfaces")
	v.blasts._process(0.5)
	var newest: BlastFlipbooks.Blast = v.blasts._pools.dust[0]
	check(is_equal_approx(float(newest.material.get_shader_parameter("age")), 0.5), "Animation follows the simulation delta")
	v.blasts._process(20.0)
	for pool: Array in v.blasts._pools.values():
		for b: BlastFlipbooks.Blast in pool:
			check(not b.mesh.visible, "Expired animation surfaces stop drawing")
	# A barrage can recycle a warmup surface before its cleanup timer fires.
	# The timer must not hide a newer explosion at that same location.
	v.prewarm(p)
	var warming: BlastFlipbooks.Blast = v.blasts._pools.dust[0]
	var live_rig := v._get_rig("m")
	v.explode(p, 1.4, "fuel")
	for i in v.blasts._pools.dust.size() + 2:
		v.blasts.burst(p, 1.4, "he", 1.0)
	await get_tree().create_timer(0.7).timeout
	check(warming.mesh.visible, "Warmup cleanup preserves a recycled live explosion")
	var live_layers: Dictionary = live_rig.get_meta("layers")
	check(live_layers.flaming.visible, "Warmup cleanup preserves live fuel fragments")
	v._view_process(Vfx.RIG_LIFE + 1.1)
	check(not live_layers.flaming.visible, "Flash and flame rigs expire with simulation time")
	Settings.v.effects = 0
	v.blasts.burst(p, 1.4, "he", 1.0)
	var active_dust := 0
	for b: BlastFlipbooks.Blast in v.blasts._pools.dust:
		if b.mesh.visible: active_dust += 1
	check(active_dust <= maxi(4, int(BlastFlipbooks.CAPACITY.dust * Settings.fx_mult())), "Lowering quality limits an already allocated high-quality pool")
	var low := BlastFlipbooks.new()
	low.vfx = v
	v.add_child(low)
	check(low._textures.dust[2] == null and low._textures.fuel[2] == null, "Low effects leave optical-flow maps unloaded")
	var low_blast := low.burst(p, 1.4, "he", 1.0)
	check(not bool(low_blast.material.get_shader_parameter("motion_enabled")), "Low effects use the inexpensive animation path")
	for i in 80:
		low.burst(p, 1.4, "he", 1.0)
	check(low._pools.dust.size() <= maxi(4, int(BlastFlipbooks.CAPACITY.dust * Settings.fx_mult())), "Low effects reduce the active surface budget")
	Settings.v.effects = 2
	low_blast = low.burst(p, 1.4, "he", 1.0)
	check(low._textures.dust[2] != null and bool(low_blast.material.get_shader_parameter("motion_enabled")), "Raising quality loads optical flow for the next blast")
	check(low._textures.fuel[2] == null, "Unused fuel optical flow stays unloaded")
	low.queue_free()
	var trail := v.make_flare_trail()
	add_child(trail)
	check(trail.get_child_count() == 2, "Flares have separate smoke and spark emitters")
	for emitter: GeometryInstance3D in trail.get_children():
		check((emitter is CPUParticles3D) == Vfx.gl, "Flare emitters follow the renderer")
		check(not bool(emitter.get("local_coords")), "Flare smoke stays behind in world space")
	var atmo := Atmosphere.new()
	atmo.world = field
	field.atmo = atmo
	add_child(atmo)
	atmo.set_process(false)
	atmo._spawn_flare(p)
	atmo._flare_t = 999.0
	var f: Array = atmo._flares[0]
	f[3] = 26.0
	var start: Vector3 = (f[0] as Node3D).position
	atmo._flares_tick(1.0)
	check((f[0] as Node3D).position.y < start.y, "Illumination flares descend")
	check((f[0] as Node3D).position.x != start.x, "Illumination flares drift with the wind")
	atmo._flares_tick(float(f[3]))
	check((f[0] as Node3D).position.y < field.floor_height + 2.0, "Long-burning flares keep descending near the ground")
	for emitter: GeometryInstance3D in (f[5] as Node3D).get_children():
		check(not Vfx.is_emitting(emitter), "Flare emitters stop when the charge burns out")
	atmo._flares_tick(5.0)
	check(atmo._flares.is_empty(), "Spent flares drain their smoke and are removed")
	# A light HE scorch must stay light while fading and after a pool reuse.
	while v._decals.size() < 70:
		v.scorch(p, 1.0)
	var recycled: Decal = v._decals[0][0]
	v.scorch(p, 1.0, 0.25)
	check(v._decals[-1][0] == recycled, "Ground marks reuse the bounded pool")
	v._view_process(0.1)
	check(is_equal_approx(recycled.modulate.a, 0.25), "Weak scorch strength survives its first update")
	v._decals[-1][1] = 135.0
	v._view_process(0.1)
	check(recycled.modulate.a > 0.0 and recycled.modulate.a < 0.125, "Scorch fade retains its original strength")
	field.free()
	trail.queue_free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("ARMAMENT_EFFECTS %s failures=%d" % ["CPU" if Vfx.gl else "GPU", failures])
	get_tree().quit(1 if failures else 0)
