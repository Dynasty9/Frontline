extends Node3D
## --soldier-sheet=PATH: every kind of soldier lined up in daylight on bare
## ground, rendered and saved as PATH, then quits. For checking the soldier
## models as they're built (vehicles have --model-sheet). Options:
##   --sheet-team=0|1     one side's units (default: both, a row each)
##   --sheet-view=front|back|rts   facing the camera, from behind, or from
##                        above at the game's own camera angle
##   --sheet-pose=idle|shoot|run|mix
##   --sheet-unit=TYPE [--sheet-seed=N]   one man turned four ways instead
##                        (front, three-quarter, side, back), close up
##   --sheet-seeds=N      with --sheet-unit: N different men of that type, front on
##   --sheet-stats        print each man's triangles, render instances and build time

var args := {}
var _frames := 0
var _saved := false


func _ready() -> void:
	var view := String(args.get("sheet-view", "front"))
	var pose := String(args.get("sheet-pose", "mix"))
	var team := String(args.get("sheet-team", "all"))
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_stage()
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	if args.has("sheet-unit"):
		# one man, close up: four views of him, or several of his kind
		var ut := String(args["sheet-unit"])
		var tm: int = int(Defs.UNITS[ut].team) if int(Defs.UNITS[ut].team) >= 0 else 0
		var sd := int(args.get("sheet-seed", 3))
		var n := int(args.get("sheet-seeds", 0))
		var count := n if n > 0 else 4
		for i in count:
			var sm := _man(ut, tm, (sd + i if n > 0 else sd) * 31 + 7, pose, i)
			sm.position = Vector3((i - (count - 1) * 0.5) * 1.0, 0, 0)
			if n == 0:
				sm.rotation.y = [0.0, -0.7, -PI * 0.5, PI][i]
		cam.fov = 30.0
		var d := count * 1.0 * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 0.62 + 0.9
		cam.position = Vector3(0, 1.3, -d)
		cam.look_at(Vector3(0, 0.98, 0))
		return
	var rows: Array = []
	if team != "1":
		rows.append([["rifleman", 0, 3], ["rifleman", 0, 11], ["medic", 0, 5], ["engineer", 0, 9], ["mg_gunner", 0, 4],
			["at_soldier", 0, 6], ["mortar_gunner", 0, 8], ["crewman", 0, 2]])
	if team != "0":
		rows.append([["fighter", 1, 3], ["fighter", 1, 12], ["fighter", 1, 21], ["fighter", 1, 30], ["r_medic", 1, 5], ["digger", 1, 9],
			["pkm", 1, 4], ["rpg", 1, 6], ["fpv_op", 1, 8], ["r_crewman", 1, 2], ["bearer", -1, 1]])
	var gap := 0.95
	var w := 0.0
	for ri in rows.size():
		var row: Array = rows[ri]
		w = maxf(w, row.size() * gap)
		for ci in row.size():
			var u: Array = row[ci]
			var sm := _man(String(u[0]), int(u[1]), int(u[2]) * 31 + 7, pose, ci)
			sm.position = Vector3((ci - (row.size() - 1) * 0.5) * gap, 0, ri * 2.4)
			sm.rotation.y = PI if view == "back" else 0.0
	match view:
		"rts":
			# the game's own view of them: from above and well back
			cam.fov = 40.0
			cam.position = Vector3(0, 9.5, -10.5 + rows.size() * 1.2)
			cam.look_at(Vector3(0, 0.6, rows.size() * 1.2))
		_:
			cam.fov = 30.0
			var d := w * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 0.6 + 1.0
			cam.position = Vector3(0, 1.6 + rows.size() * 0.6, -d)
			cam.look_at(Vector3(0, 0.9, (rows.size() - 1) * 1.2))


## A man of that type, posed.
func _man(ut: String, team: int, seed: int, pose: String, i: int) -> SoldierModel:
	var sm := SoldierModel.new()
	add_child(sm)
	var t0 := Time.get_ticks_usec()
	sm.build(ut, team, seed)
	if args.has("sheet-stats"):
		var c := _count(sm)
		print("SHEET %s: %d triangles, %d instances, built in %.2f ms" % [ut, c[0], c[1], (Time.get_ticks_usec() - t0) / 1000.0])
	var act := Soldier.Act.IDLE
	var spd := 0.0
	match pose:
		"shoot":
			act = Soldier.Act.SHOOT
		"run":
			act = Soldier.Act.RUN
			spd = 4.6
		"mix":
			act = [Soldier.Act.IDLE, Soldier.Act.SHOOT, Soldier.Act.IDLE, Soldier.Act.RUN][i % 4]
			spd = 4.6 if act == Soldier.Act.RUN else 0.0
			if int(Defs.UNITS[ut].get("rockets", 0)) > 0:
				act = Soldier.Act.LAUNCH
				spd = 0.0
	for f in 14:
		sm.pose(0.12, 0, Soldier.Post.STAND, act, spd, false, false)
	return sm


## [triangles, mesh instances] drawn for a model.
func _count(n: Node) -> Array:
	var tris := 0
	var inst := 0
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).is_visible_in_tree() and (c as MeshInstance3D).mesh:
			inst += 1
			var m: Mesh = (c as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var a := m.surface_get_arrays(si)
				var idx = a[Mesh.ARRAY_INDEX]
				tris += ((idx as PackedInt32Array).size() if idx != null and not (idx as PackedInt32Array).is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var sub := _count(c)
		tris += int(sub[0])
		inst += int(sub[1])
	return [tris, inst]


func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.38, 0.52, 0.72)
	sm.sky_horizon_color = Color(0.72, 0.74, 0.74)
	sm.ground_horizon_color = Color(0.5, 0.47, 0.42)
	sm.ground_bottom_color = Color(0.24, 0.23, 0.2)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX  # as in the game
	env.ssao_enabled = true
	env.ssao_radius = 0.5
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(150), 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	Mats.apply(g, "plain", Color(0.62, 0.55, 0.45))
	add_child(g)


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 24 and not _saved:
		_saved = true
		var path := String(args["soldier-sheet"])
		get_viewport().get_texture().get_image().save_png(path)
		print("soldier sheet saved ", path)
		TestRun.quit(get_tree())
