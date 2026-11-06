extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	TestRun.watch()
	Vfx.gl = "--cpu-effects" in OS.get_cmdline_user_args()
	var field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var v: Vfx = field.fx.vfx
	field.floor_height = 40.0
	var p := Vector3(0, 40.1, 0)
	v.explode(p, 1.0, "frag")
	var frag: Node3D = v._rigs.s[0]
	var fl: Dictionary = frag.get_meta("layers")
	check(fl.dirt.visible, "Grenades throw dirt on elevated ground")
	check(not fl.has("flaming"), "Grenades must not use burning fragment layers")
	v.explode(p, 1.4, "fuel")
	var shell: Node3D = v._rigs.m[0]
	var layers: Dictionary = shell.get_meta("layers")
	check(layers.flaming.visible and layers.afterburn.visible, "Fuel burns after the blast")
	shell.set_meta("t", -1000.0)
	v.explode(p, 1.4, "he")
	check(v._rigs.m.size() == 1, "An idle rig is reused")
	check(layers.column.visible and layers.dirt.visible, "Shell impacts lift earth above elevated terrain")
	check(not layers.flaming.visible and not layers.afterburn.visible, "HE must clear recycled fuel flames")
	shell.set_meta("t", -1000.0)
	v.explode(p + Vector3.UP * 8.0, 1.4, "he")
	for key in ["dirt", "debris", "column", "ring", "afterburn", "ejecta"]:
		if layers.has(key):
			check(not layers[key].visible, "Airbursts clear the recycled " + key + " layer")
	check(layers.smoke.visible and layers.flash.visible, "Airbursts retain flash and smoke")
	v._fire_layer(layers.smoke, 0.0, 0.0)
	check(not layers.smoke.visible and not Vfx.is_emitting(layers.smoke), "Zero-budget layers stop")
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
	var start: Vector3 = (f[0] as Node3D).position
	atmo._flares_tick(1.0)
	check((f[0] as Node3D).position.y < start.y, "Illumination flares descend")
	check((f[0] as Node3D).position.x != start.x, "Illumination flares drift with the wind")
	atmo._flares_tick(float(f[3]))
	for emitter: GeometryInstance3D in (f[5] as Node3D).get_children():
		check(not Vfx.is_emitting(emitter), "Flare emitters stop when the charge burns out")
	atmo._flares_tick(5.0)
	check(atmo._flares.is_empty(), "Spent flares drain their smoke and are removed")
	field.free()
	trail.queue_free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("ARMAMENT_EFFECTS %s failures=%d" % ["CPU" if Vfx.gl else "GPU", failures])
	get_tree().quit(1 if failures else 0)
