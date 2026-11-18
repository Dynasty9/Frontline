extends Node3D
## A support sortie from the Field Manual's range, flown by the real
## simulation over a plain floor, framed by the demo's own camera or (with
## --side) from far off to one side so the whole flight profile reads.
## godot --path . --fixed-fps 30 --write-movie out.avi res://tools/showcase/support-flight.tscn -- --kind=a10 [--side]

var demo: Node
var side_cam: Camera3D
var side := false


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	side = args.has("side")
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(3000, 3000)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.36, 0.40, 0.27)
	floor_mesh.material = floor_mat
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	add_child(ground)
	demo = load("res://scripts/ui/support_demo.gd").new()
	demo.set("settings", {"map_size": 1024, "seed": 7, "scenario": "support_preview", "mood": "day"})
	demo.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(demo)
	demo.connect("finished", func(): get_tree().quit())
	await demo.prepare(String(args.get("kind", "a10")))
	if side:
		side_cam = Camera3D.new()
		side_cam.fov = 40.0
		side_cam.far = 3000.0
		add_child(side_cam)
		side_cam.make_current()


func _process(_dt: float) -> void:
	if side_cam and is_instance_valid(demo._aircraft) and not demo._aircraft.gone:
		# off the flank of the run-in line, near enough that the attitude reads,
		# panning with the aircraft; the targets stay low in the frame
		var p: Vector3 = demo._aircraft.global_position
		side_cam.global_position = Vector3(clampf(p.x, -260.0, 260.0) * 0.8, 6.0 + p.y * 0.25, 150.0)
		side_cam.look_at(p.lerp(Vector3.ZERO, 0.25))
