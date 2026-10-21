extends Node
## Error reports from players' copies of the game. When something goes wrong
## in a release build, the engine's account of it (what failed, in which of
## our functions, and the GDScript calls that led there) goes to the
## matchmaker, which keeps a tally for the developers (matchmaker/src/errors.js).
## A crash can't report itself, so the next launch finds it in the log the
## engine left behind and sends that.
##
## What a release build can tell us: engine errors (a method called with bad
## arguments, a node that isn't there, a mesh or shader the driver rejected)
## and push_error(). GDScript's own runtime errors (a null used, an index out
## of range) are silent in release builds - the call just returns null and play
## carries on - so those only ever show in development runs and CI. The call
## stacks need the project setting debug/settings/gdscript/always_track_call_stacks,
## which costs a few nanoseconds a call.
##
## A report says what went wrong, where in our code, and on what: the game's
## version, the operating system, the graphics card and its driver, and
## whether it was in the menus or a battle. Paths on the player's machine,
## addresses and emails are taken out before it goes, and it carries no
## account or callsign. Players can switch it off (Settings > Interface > Send
## error reports).
##
## Only exported release builds report. Command line: --report-errors makes
## any build report (test it against a local matchmaker with --matchmaker=URL);
## --test-error=SECONDS causes an engine error and a push_error that long
## after start, and --test-crash=SECONDS crashes the game.

## A newly caught error waits up to this long for any that follow it.
const POLL_S := 5.0
const SEND_EVERY_S := 30.0
const RETRY_S := 120.0
const MAX_SENDS := 20  # requests in one launch
const MARK_PATH := "user://error_reports.cfg"
## How much of the end of a crashed run's log is read.
const CRASH_TAIL := 256 * 1024

var active := false
var _catcher: Catcher
var _session := ""
var _next_send := 0.0  # uptime (s) before which nothing is sent
var _sending := false
var _sends := 0
var _crash_checked := false
var _ctx_t := 0.0
var _test_error_at := -1.0
var _test_crash_at := -1.0
# what's taken out of a report: this machine's own paths, then patterns
var _plain: Array = []  # [text, replacement]
var _patterns: Array = []  # [RegEx, replacement]


## Catches every error the engine reports, from any thread. It only notes them
## down (each distinct error once, with a count); Errors sends them.
class Catcher extends Logger:
	const MAX_KINDS := 32
	const MAX_FRAMES := 24
	const KINDS := {ERROR_TYPE_ERROR: "error", ERROR_TYPE_SCRIPT: "script", ERROR_TYPE_SHADER: "shader"}

	var mutex := Mutex.new()
	## {kind, message, condition, where, context, backtrace, count, sent}
	var entries: Array = []
	var _by_sig := {}
	var _context := "menu"

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		# (nothing in here may print or push an error: it would come straight back)
		if not KINDS.has(error_type):
			return  # warnings
		var frames := PackedStringArray()
		for bt in script_backtraces:
			for f in bt.get_frame_count():
				if frames.size() < MAX_FRAMES:
					frames.append("%s (%s:%d)" % [bt.get_frame_function(f), bt.get_frame_file(f), bt.get_frame_line(f)])
		var where := "%s (%s:%d)" % [function, file, line]
		var sig := "%d %s %s" % [error_type, where, frames[0] if not frames.is_empty() else ""]
		mutex.lock()
		var i: int = _by_sig.get(sig, -1)
		if i >= 0:
			entries[i].count += 1
		elif entries.size() < MAX_KINDS:
			_by_sig[sig] = entries.size()
			entries.append({
				"kind": KINDS[error_type],
				"message": rationale if rationale != "" else code,
				"condition": code if rationale != "" else "",
				"where": where,
				"context": _context,
				"backtrace": frames,
				"count": 1,
				"sent": 0,
			})
		mutex.unlock()

	## Where the game is ("menu", "battle"), for the errors from now on.
	func set_context(c: String) -> void:
		mutex.lock()
		_context = c
		mutex.unlock()

	## What hasn't been sent yet: [index, how many, a copy to send] each,
	## counted as sent (give_back() if it doesn't get there).
	func take() -> Array:
		var out := []
		mutex.lock()
		for i in entries.size():
			var e: Dictionary = entries[i]
			var n: int = e.count - e.sent
			if n > 0:
				e.sent = e.count
				var r := e.duplicate()
				r.erase("sent")
				r.count = n
				out.append([i, n, r])
		mutex.unlock()
		return out

	func give_back(items: Array) -> void:
		mutex.lock()
		for it in items:
			entries[it[0]].sent -= it[1]
		mutex.unlock()


func _init() -> void:
	# as early as can be (Errors is the first autoload), so that errors while
	# the rest of the game starts are caught too
	var flags := OS.get_cmdline_user_args()
	var release := OS.has_feature("template") and not String(ProjectSettings.get_setting("application/config/version", "")).ends_with("-dev")
	active = release or "--report-errors" in flags
	for a in flags:
		var s := String(a)
		if s.begins_with("--test-error="):
			_test_error_at = s.substr(13).to_float()
		elif s.begins_with("--test-crash="):
			_test_crash_at = s.substr(13).to_float()
	if active:
		_catcher = Catcher.new()
		OS.add_logger(_catcher)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(active or _test_error_at >= 0.0 or _test_crash_at >= 0.0)
	if not active:
		return
	_session = Crypto.new().generate_random_bytes(6).hex_encode()  # one launch, nobody in particular
	_next_send = POLL_S
	var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	for p in [[OS.get_user_data_dir(), "<user data>"], [OS.get_executable_path().get_base_dir(), "<game>"], [home, "<home>"]]:
		var path := String(p[0])
		if path.length() > 3:
			_plain.append([path, p[1]])
			_plain.append([path.replace("\\", "/"), p[1]])
			_plain.append([path.replace("/", "\\"), p[1]])
	for p in [
		["(?i)([a-z]:[\\\\/]users[\\\\/])[^\\\\/\\s\"']+", "$1<name>"],
		["/home/[^/\\s\"']+", "/home/<name>"],
		["/Users/[^/\\s\"']+", "/Users/<name>"],  # a Mac's home folders
		["[\\w.+-]+@[\\w-]+\\.[\\w.-]+", "<email>"],
		["\\b\\d{1,3}(\\.\\d{1,3}){3}\\b", "<address>"],
		["(?i)\\b([0-9a-f]{1,4}:){3,7}[0-9a-f]{1,4}\\b", "<address>"],
	]:
		var re := RegEx.new()
		re.compile(p[0])
		_patterns.append([re, p[1]])


func _exit_tree() -> void:
	if _catcher:
		OS.remove_logger(_catcher)


func _process(dt: float) -> void:
	var up := Time.get_ticks_msec() / 1000.0
	if active:
		_ctx_t -= dt
		if _ctx_t <= 0.0:
			_ctx_t = 1.0
			var scene := get_tree().current_scene
			_catcher.set_context("battle" if scene and scene.has_node("World") else "menu")
	if _test_error_at >= 0.0 and up >= _test_error_at:
		_test_error_at = -1.0
		# (carrying what a report must never: a path on this machine, an email, an address)
		push_error("Deliberate test error (--test-error) in %s/logs, from player@example.com at 203.0.113.7" % OS.get_user_data_dir())
		get_node("Deliberate test error (--test-error)")  # an engine error: no such node
	if _test_crash_at >= 0.0 and up >= _test_crash_at:
		OS.crash("Deliberate test crash (--test-crash)")
	if not active:
		return
	if _sending or up < _next_send or _sends >= MAX_SENDS:
		return
	_next_send = up + POLL_S
	var on: bool = Settings.get_v("error_reports")
	if not _crash_checked:
		_crash_checked = true
		var crash := _last_crash()
		if not crash.is_empty():
			if on:
				_send([[-1, 1, crash]])
				return
			_mark_crash(crash)  # (switched off: never sent, then or later)
	var items := _catcher.take()
	if items.is_empty() or not on:
		return  # (switched off: what was caught is forgotten)
	_send(items)


func _send(items: Array) -> void:
	_sending = true
	_sends += 1
	var reports := []
	for it in items:
		var rep := _clean(it[2])
		rep.erase("log_file")
		reports.append(rep)
	var body := {
		"game_version": Updater.version,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"gpu": RenderingServer.get_video_adapter_name(),
		"driver": " ".join(PackedStringArray([RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_api_version(), RenderingServer.get_current_rendering_method()])).strip_edges().replace("  ", " "),
		"session": _session,
		"reports": reports,
	}
	var r: Dictionary = await Online.api(HTTPClient.METHOD_POST, "/errors", body, PackedStringArray(), 15.0)
	_sending = false
	var up := Time.get_ticks_msec() / 1000.0
	var code := int(r.code)
	if r.ok or (code >= 400 and code < 500 and code != 429):
		# (refused as it stands: sending it again won't help either)
		_next_send = up + SEND_EVERY_S
		for it in items:
			if int(it[0]) < 0:
				_mark_crash(it[2])
	else:
		# unreachable, or too many at once: try again later
		var live: Array = items.filter(func(it): return int(it[0]) >= 0)
		_catcher.give_back(live)
		if live.size() < items.size():
			_crash_checked = false  # (and the crash with them)
		_next_send = up + RETRY_S


## A report with this machine's particulars taken out.
func _clean(r: Dictionary) -> Dictionary:
	var out := r.duplicate()
	for k in out:
		if out[k] is String:
			out[k] = _scrub(out[k])
		elif out[k] is PackedStringArray or out[k] is Array:
			var a := PackedStringArray()
			for s in out[k]:
				a.append(_scrub(String(s)))
			out[k] = a
	return out


func _scrub(s: String) -> String:
	for p in _plain:
		s = s.replace(p[0], p[1])
	for p in _patterns:
		s = (p[0] as RegEx).sub(s, p[1], true)
	return s


## The last run's crash, from the log the engine wrote ({} if it didn't
## crash, or that log has been looked at already).
##
## A crash in the log: the errors just before it, then a banner, "...: Program
## crashed with signal 11", the engine's own (unnamed) frames, and the
## GDScript calls it was in the middle of, each block ending in a line
## "-- END OF ... BACKTRACE --".
func _last_crash() -> Dictionary:
	if not ProjectSettings.get_setting_with_override("debug/file_logging/enable_file_logging"):
		return {}
	var log_path := String(ProjectSettings.get_setting_with_override("debug/file_logging/log_path"))
	var dir := log_path.get_base_dir()
	var base := log_path.get_file().get_basename()
	var ext := "." + log_path.get_extension()
	# each launch renames the one before's log to base + its date, so the
	# latest of those is the last run's
	var last := ""
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(base) and f.ends_with(ext) and f != base + ext and f > last:
			last = f
	if last == "":
		return {}
	var mark := ConfigFile.new()
	mark.load(MARK_PATH)
	if String(mark.get_value("crash", "reported", "")) == last:
		return {}
	var fa := FileAccess.open(dir.path_join(last), FileAccess.READ)
	if fa == null:
		return {}
	fa.seek(maxi(0, fa.get_length() - CRASH_TAIL))
	var lines := fa.get_buffer(CRASH_TAIL).get_string_from_utf8().split("\n")
	var at := -1
	for i in range(lines.size() - 1, -1, -1):
		if lines[i].contains("Program crashed"):
			at = i
			break
	if at < 0:
		return {}
	var message := lines[at].substr(lines[at].find("Program crashed")).strip_edges()
	var frames := PackedStringArray()
	var native := PackedStringArray()
	var block := ""
	for i in range(at + 1, lines.size()):
		var l := lines[i].strip_edges()
		if l.begins_with("-- END OF"):
			block = ""
		elif l.begins_with("Dumping the backtrace"):
			block = "c++"
		elif l.begins_with("GDScript backtrace"):
			block = "gd"
		elif l.begins_with("[") and l.contains("] "):
			var frame := l.substr(l.find("] ") + 2)
			if block == "gd" and frames.size() < Catcher.MAX_FRAMES:
				frames.append(frame)
			elif block == "c++" and native.size() < 12:
				# "7ff6072b4d03 (main+40d4d03) - no debug info": the offset is what's worth keeping
				var o := frame.find("(")
				native.append(frame.substr(o + 1, frame.find(")") - o - 1) if o >= 0 else frame)
	# what the log said just before (the errors that led up to it)
	var before := PackedStringArray()
	var i0 := at - 1
	while i0 >= 0 and (lines[i0].strip_edges() == "" or lines[i0].begins_with("=")):
		i0 -= 1
	for i in range(maxi(0, i0 - 23), i0 + 1):
		before.append(lines[i].rstrip("\r"))
	if not native.is_empty():
		before.append("Engine frames: " + ", ".join(native))
	return {
		"kind": "crash",
		"message": message,
		"where": frames[0] if not frames.is_empty() else "",
		"backtrace": frames,
		"log": before,
		"count": 1,
		"log_file": last,
	}


## That crash's log has been dealt with: never send it again.
func _mark_crash(crash: Dictionary) -> void:
	var mark := ConfigFile.new()
	mark.load(MARK_PATH)
	mark.set_value("crash", "reported", String(crash.get("log_file", "")))
	mark.save(MARK_PATH)
