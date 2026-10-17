class_name GameScripts
extends RefCounted
## The game's own classes - World and the eighty-odd scripts it reaches that the
## menu doesn't need: soldiers, vehicles, structures, the AI, the HUD - compile
## on a worker thread while the title plays, instead of before the first frame.
## GDScript compiles every class a script names when that script loads (a type,
## a static call, a constant: all of them), so the autoloads, main.gd and the
## menu never name one: they load these by path, through here.

const WORLD := "res://scripts/game/world.gd"
const FIELD_MANUAL := "res://scripts/ui/field_manual.gd"
const STATS_PANEL := "res://scripts/ui/stats_panel.gd"


## Starts compiling them (World reaches all the rest). A browser has no
## threads to spare, so there it's done at once, before the first frame, as it
## always was.
static func compile_in_background() -> void:
	if ResourceLoader.has_cached(WORLD):
		# compiled already, so something the title or the menu loads names one
		# of them, and the launch waits for them all again: say so (in a
		# development run, which fails a test run)
		if OS.is_debug_build():
			push_error("The game's classes compiled before the menu: a script on the way to it names one (load it through GameScripts)")
		return
	if OS.has_feature("web"):
		load(WORLD)
	elif ResourceLoader.load_threaded_get_status(WORLD) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(WORLD)


## One of them, compiled: if the compile behind the title is still going (a
## battle started, or the Field Manual opened, within seconds of the launch),
## this waits for it to finish.
static func load_script(path: String) -> Script:
	if ResourceLoader.load_threaded_get_status(WORLD) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(WORLD)
	return load(path)
