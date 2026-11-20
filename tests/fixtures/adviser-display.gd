extends Node
## Inert display fixture: the World and structures never enter the scene tree.
## Native Adviser, objective panel and minimap objective drawing; no simulation.

class ObjectiveMap extends HudMinimap:
	func _draw_content(_phase := -1) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.INK)
		for i in range(1, 4):
			draw_line(Vector2(i * size.x / 4, 0), Vector2(i * size.x / 4, size.y), UiKit.FAINT, 1)
			draw_line(Vector2(0, i * size.y / 4), Vector2(size.x, i * size.y / 4), UiKit.FAINT, 1)
		for town in hud.world.structures:
			if town.skind != "town":
				continue
			var p := _pt(town.position)
			draw_circle(p, 3, UiKit.GOOD if town.team == 0 else UiKit.DIM)
			UiKit.text(self, p + Vector2(12, 4), town.sname, 12, UiKit.TEXT)
		_draw_objectives(hud.world)

var world: World
var hud: Hud
var panel: HudObjectives
var map: ObjectiveMap
var caption: Label
var detail: Label
var failures := 0
var capture := ""
var take := "AFTER"
var frame := 0
var records: Array = []

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		print("ADVISER CHECK FAILED: " + text)

func reset(held: int) -> void:
	if world:
		for entity in world.entities.values():
			entity.free()
		world.free()
	world = World.new()
	world.local_team = 0
	var fob := Structure.new()
	fob.eid = 1
	fob.skind = "fob"
	fob.position = Vector3(-400, 0, -400)
	fob.hp = 100
	world.entities[1] = fob
	world.team_info = [{"fobs": [[1, "Home"]]}, {}]
	for i in 6:
		var town := Structure.new()
		town.eid = i + 2
		town.skind = "town"
		town.sname = ["Elm", "Oak", "Pine", "Ash", "Birch", "Alder"][i]
		town.position = Vector3(-260 + (i % 3) * 250, 0, -180 + (i / 3) * 420)
		town.team = 0 if i >= 3 and i < 3 + held else -1
		world.entities[town.eid] = town
		world.structures.append(town)
	world.adviser = Adviser.new(world)
	if hud:
		hud.world = world

func update(at: float) -> void:
	world.time = at
	world.adviser._suggest(world.team_info[0])

func state_of(eid: int) -> int:
	var pos: Vector3 = world.entities[eid].position
	for o in HudObjectives.shown(world).get("objs", []):
		if o[4] == pos:
			return int(o[2])
	return -1

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--adviser-capture="):
			capture = arg.trim_prefix("--adviser-capture=")
		elif arg.begins_with("--adviser-take="):
			take = arg.trim_prefix("--adviser-take=")
	Settings.v["adviser"] = true
	Settings.v["perf"] = 0
	MapDims.configure(1024)
	if capture != "":
		_setup_view()
		DirAccess.make_dir_recursive_absolute(capture)
	reset(0)
	update(0)
	check(world.adviser.objs.size() == 2, "starts with two suggestions")
	await show_phase("Two suggestions", "No simulated activity; both towns are unowned.")
	world.entities[2].team = 0
	update(1)
	check(state_of(2) == MissionDirector.DONE, "owned suggestion acknowledges completion")
	await show_phase("Completion acknowledged", "Synthetic ownership: Elm becomes ours.")
	world.entities[2].team = -1
	update(2)
	check(state_of(2) == MissionDirector.ACTIVE, "reversed ownership restores active display")
	await show_phase("Ownership reverses", "Elm is unowned again. Panel and minimap must agree.")

	reset(3)
	update(0)
	await show_phase("Three towns held", "A fresh synthetic state starts just below the cutoff.")
	world.entities[2].team = 0
	update(1)
	check(state_of(2) == MissionDirector.DONE, "fourth town keeps valid completion feedback")
	check(world.adviser.objs.size() == 1, "cutoff removes active suggestions")
	await show_phase("Fourth town held", "Keep Elm's completion briefly; show no active markers.")
	update(5)
	check(state_of(2) == MissionDirector.DONE, "completion persists during its display interval")
	check(world.adviser.objs.size() == 1, "no new suggestions while completion is retained")
	await show_phase("Completion remains", "Four seconds later: acknowledgement only, no new suggestions.")
	update(10)
	check(world.adviser.objs.is_empty(), "expired completion clears without new suggestions")
	await show_phase("Feedback expires", "Nine seconds after completion: panel and markers clear.")

	# A completion already on screen must not open the cutoff to new markers.
	reset(2)
	update(0)
	world.entities[2].team = 0
	update(1)
	world.entities[3].team = 0
	update(2)
	check(world.adviser.objs.size() == 2 and state_of(2) == MissionDirector.DONE and state_of(3) == MissionDirector.DONE, "simultaneous valid acknowledgements survive cutoff")
	update(10)
	check(world.adviser.objs.size() == 1 and state_of(3) == MissionDirector.DONE, "older completion expires without filling its slot")
	world.entities[3].team = -1
	world.entities[4].team = 0
	update(11)
	check(world.adviser.objs.is_empty(), "reversal at cutoff clears invalid completion without a marker")

	reset(0)
	world.adviser._watch_fobs(world.team_info[0])
	world.entities[1].hp = 90
	world.adviser._watch_fobs(world.team_info[0])
	check("latest alert or ping" in world.adviser.current(), "hint describes global latest-notification shortcut")
	if capture != "":
		FileAccess.open(capture.path_join("states.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
		panel.free()
		map.free()
		hud.free()
	for entity in world.entities.values():
		entity.free()
	world.free()
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("ADVISER_DISPLAY failures=%d" % failures)
	# Before captures intentionally retain the original failures.
	get_tree().quit(0 if capture != "" else (1 if failures else 0))

func _setup_view() -> void:
	get_window().content_scale_size = Vector2i(1600, 900)
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.size = Vector2(1600, 900)
	add_child(bg)
	caption = Label.new()
	caption.position = Vector2(60, 55)
	caption.add_theme_font_size_override("font_size", 32)
	add_child(caption)
	detail = Label.new()
	detail.position = Vector2(60, 112)
	detail.add_theme_font_size_override("font_size", 22)
	add_child(detail)
	var footer := Label.new()
	footer.text = "INERT UI FIXTURE  /  UI AT 150%  /  SYNTHETIC OWNERSHIP  /  NO SIMULATION"
	footer.position = Vector2(60, 825)
	footer.add_theme_font_size_override("font_size", 19)
	add_child(footer)
	hud = Hud.new()
	panel = HudObjectives.new()
	panel.hud = hud
	panel.position = Vector2(520, 230)
	panel.scale = Vector2.ONE * 1.5
	panel.size = Vector2(640, 400)
	add_child(panel)
	map = ObjectiveMap.new()
	map.hud = hud
	map.position = Vector2(90, 265)
	map.scale = Vector2.ONE * 1.5
	map.size = Vector2(350, 350)
	add_child(map)

func show_phase(title: String, text: String) -> void:
	records.append({"phase": title, "time": world.time, "objs": world.adviser.objs.duplicate(true)})
	if capture == "":
		return
	caption.text = take + "  |  " + title
	detail.text = text
	map.queue_redraw()
	panel.queue_redraw()
	for i in 24:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture.path_join("frame-%04d.png" % frame))
		frame += 1
