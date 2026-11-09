extends "res://scripts/main.gd"
## Capture the production HUD through its normal workspace/action callbacks.
## Fixed 24 Hz and a seeded battle; no synthetic UI or edited playback.
const FPS := 24
var output := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(output)
	super._ready()
	while not is_instance_valid(world) or not world.loaded or not is_instance_valid(world.hud) or world.time < 1.0:
		await get_tree().process_frame
	var hud: Node = world.hud
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	var caption := Label.new()
	caption.position = Vector2(390, 70)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	caption.text = "COMMAND DECK / The tactical map stays fixed"
	hud.set_workspace("battle")
	for frame in 15 * FPS:
		if frame == 24:
			hud.set_workspace("squads")
			caption.text = "UNITS / Open the roster without moving the map"
		if frame in [60, 66, 72, 78, 84, 90, 96]:
			var query := "charlie".left(1 + (frame - 60) / 6)
			hud.squad_search.text = query
			hud.squad_search.text_changed.emit(query)
			caption.text = "SEARCH / Filter by callsign, then focus the result"
		if frame == 120:
			hud.orbat.activate_cursor()
			caption.text = "FOCUS / Return to the battle with orders ready"
		if frame == 168:
			hud._update_card()
			hud.activate_card_action("build_base")
			caption.text = "BASE / Construction costs and bound-key shortcuts"
		if frame == 216:
			hud.set_workspace("map")
			caption.text = "LAYERS / Map controls stay beside navigation"
		if frame == 264:
			hud.set_workspace("fires")
			caption.text = "SUPPORT / Availability and costs in one workspace"
		if frame == 324:
			hud.set_workspace("battle")
			caption.text = "BACK TO BATTLE / Fixed map, focused command tools"
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
	print("HUD_CLIP frames=360")
	TestRun.quit(get_tree())
