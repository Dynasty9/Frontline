class_name TestRun
extends RefCounted
## How a test run ends. Every switch that runs the game as a test (scenarios,
## missions, battles, sheets and shots, the camera and key tests, the test
## port) quits through here, so a failure leaves a non-zero exit code for CI and
## scripts to act on, not just a line in the output to grep for:
##   1  a script error happened (or the game's own push_error), or a check failed
##   0  everything ran clean
## Engine warnings and errors that aren't the scripts' fault (a renderer
## complaining about a transform, resources still in use at exit) don't count.

static var script_errors := 0
static var failures := 0
## The last few script errors, "file:line: message" (the test port hands them on).
static var recent: Array[String] = []
static var _lock := Mutex.new()


## Counts script errors as the engine reports them. Loggers are called from
## whichever thread hit the error, hence the lock.
class ErrorCounter extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT and function != "push_error":
			return
		var at := "%s:%d" % [file, line]
		if not script_backtrace.is_empty() and script_backtrace[0].get_frame_count() > 0:
			at = "%s:%d" % [script_backtrace[0].get_frame_file(0), script_backtrace[0].get_frame_line(0)]
		TestRun._count("%s: %s" % [at, rationale if rationale != "" else code])

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Starts counting (main.gd calls this for any run given switches).
static func watch() -> void:
	OS.add_logger(ErrorCounter.new())


static func _count(what: String) -> void:
	_lock.lock()
	script_errors += 1
	recent.append(what)
	if recent.size() > 20:
		recent.pop_front()
	_lock.unlock()


## A check of the run's own failed (the camera and key tests, the test port).
static func fail() -> void:
	_lock.lock()
	failures += 1
	_lock.unlock()


static func exit_code() -> int:
	return 1 if script_errors > 0 or failures > 0 else 0


## Ends the run with its exit code (saying why, when it isn't 0).
static func quit(tree: SceneTree) -> void:
	if script_errors > 0 or failures > 0:
		print("TESTRUN failed: %d script error(s), %d failed check(s)" % [script_errors, failures])
	tree.quit(exit_code())
