extends Node
## Keeping the game up to date. A release build (its version is stamped into
## project.godot by .github/workflows/release.yml) asks GitHub for the latest
## release when it starts. If that's newer, it downloads the release's zip for
## this platform in the background, checks it against the SHA-256 GitHub
## publishes for it, and swaps the executable: the running one is renamed aside
## (Windows lets you rename a running program, though not overwrite it) and the
## new one takes its name. The menu then offers a restart; quitting does as
## well, since the next launch is the new version. The old file is deleted on
## that next launch.
##
## Where the game can't update itself (a build from source, a folder it can't
## write to, no build for this platform), the menu links to the downloads.
## Keeping up matters online: the matchmaker only pairs players on the same
## network version (Net.NET_VERSION).
##
## Test switches: --game-version=X.Y.Z pretends to be that release,
## --update-api=URL reads the release from another GitHub API URL, and
## --update-target=PATH swaps that file instead of the running executable (so
## a run from source can go through a whole update without touching Godot).

signal changed

enum State { NONE, AVAILABLE, DOWNLOADING, READY, FAILED }

const LATEST_RELEASE_API := "https://api.github.com/repos/Dynasty9/Frontline/releases/latest"
const WEBSITE_URL := "https://web-production-5a4c1.up.railway.app"
const DOWNLOAD := "user://update.zip"

## This build's version: "0.1.4" for a release, "0.0.0-dev" from source,
## "0.1.5-pr.12" for a pull request's test build.
var version := String(ProjectSettings.get_setting("application/config/version", "0.0.0-dev"))
var state := State.NONE
var latest := ""  # the newer release's version, once found
var error := ""
var _api := LATEST_RELEASE_API
var _target := ""  # the executable an update replaces ("" when it can't)
var _asset := {}  # this platform's zip in the latest release: url, digest, size
var _req: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game-version="):
			version = a.substr(15)
		elif a.begins_with("--update-api="):
			_api = a.substr(13)
		elif a.begins_with("--update-target="):
			_target = a.substr(16)
	if _target == "" and OS.has_feature("template"):
		_target = OS.get_executable_path()
	_clean_up()
	if is_release():
		check.call_deferred()


## Whether this is a numbered release (not a build from source or a test build).
func is_release() -> bool:
	return not version.contains("-")


## How far the download has got, 0 to 1.
func progress() -> float:
	if _req == null or _req.get_body_size() <= 0:
		return 0.0
	return clampf(float(_req.get_downloaded_bytes()) / float(_req.get_body_size()), 0.0, 1.0)


## Ask GitHub for the latest release; if it's newer, say so, and install it
## when we can.
func check() -> void:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	if req.request(_api, PackedStringArray(["Accept: application/vnd.github+json"])) != OK:
		req.queue_free()
		return
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not d is Dictionary:
		return
	var v := String((d as Dictionary).get("tag_name", "")).trim_prefix("v")
	if not newer(v, version):
		return
	latest = v
	_asset = _platform_asset((d as Dictionary).get("assets", []))
	state = State.AVAILABLE
	_debug("v%s is out (this is v%s); %s" % [latest, version, "installing" if can_install() else "can't install it here"])
	changed.emit()
	if can_install():
		download()


## Whether an update can replace the executable here, rather than sending the
## player to the website: a release build with a zip for this platform, in a
## folder we can write to.
func can_install() -> bool:
	if _target == "" or _asset.is_empty():
		return false
	var probe := _target.get_base_dir().path_join(".frontline-write-test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _platform_asset(assets: Array) -> Dictionary:
	var want := ""
	match OS.get_name():
		"Windows":
			want = "Frontline-windows.zip"
		"Linux", "FreeBSD":
			want = "Frontline-linux.zip"
	for a in assets:
		if a is Dictionary and String(a.get("name", "")) == want:
			return {"url": String(a.get("browser_download_url", "")), "digest": String(a.get("digest", "")), "size": int(a.get("size", 0))}
	return {}


func download() -> void:
	if state == State.DOWNLOADING or state == State.READY:
		return
	_req = HTTPRequest.new()
	_req.download_file = DOWNLOAD
	_req.use_threads = true
	_req.timeout = 900.0
	add_child(_req)
	state = State.DOWNLOADING
	changed.emit()
	var err := _req.request(String(_asset.url))
	var res: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0]
	if err == OK:
		res = await _req.request_completed
	_req.queue_free()
	_req = null
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		_fail("The download didn't finish. It'll try again next time the game starts.")
		return
	var zip := ProjectSettings.globalize_path(DOWNLOAD)
	var problem := install(zip, String(_asset.digest), _target)
	DirAccess.remove_absolute(zip)
	if problem != "":
		_fail(problem)
		return
	_debug("v%s installed over %s" % [latest, _target])
	state = State.READY
	changed.emit()


## Check the zip, unpack the game from it beside `target` and swap it in. ""
## when it worked, else what went wrong.
static func install(zip: String, digest: String, target: String) -> String:
	if digest.begins_with("sha256:") and FileAccess.get_sha256(zip) != digest.substr(7):
		return "The download was damaged (its checksum doesn't match), so it wasn't installed."
	var z := ZIPReader.new()
	if z.open(zip) != OK:
		return "The download isn't a zip the game can read."
	var entry := ""
	for f in z.get_files():
		if f.get_file() == "Frontline.exe" or f.get_file() == "Frontline.x86_64":
			entry = f
	var data := z.read_file(entry) if entry != "" else PackedByteArray()
	z.close()
	if data.size() < 1024:
		return "The download has no game in it."
	var fresh := target + ".new"
	var w := FileAccess.open(fresh, FileAccess.WRITE)
	if w == null:
		return "The game's folder can't be written to."
	w.store_buffer(data)
	w.close()
	if not target.ends_with(".exe"):
		# rwxr-xr-x, like the build it replaces
		FileAccess.set_unix_permissions(fresh, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
			| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER)
	var old := target + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(target, old) != OK:
		DirAccess.remove_absolute(fresh)
		return "The running game couldn't be moved aside."
	if DirAccess.rename_absolute(fresh, target) != OK:
		DirAccess.rename_absolute(old, target)  # put it back as it was
		return "The new version couldn't be put in place."
	return ""


## Start the new version and quit this one.
func restart() -> void:
	if _target != "" and FileAccess.file_exists(_target):
		OS.create_process(_target, PackedStringArray())
	get_tree().quit()


func _fail(msg: String) -> void:
	error = msg
	state = State.FAILED
	_debug("update failed: " + msg)
	changed.emit()


## What the last update left behind: the previous executable (in use until we
## restarted) and a download that never finished.
func _clean_up() -> void:
	if _target != "" and FileAccess.file_exists(_target + ".old"):
		DirAccess.remove_absolute(_target + ".old")
	if FileAccess.file_exists(DOWNLOAD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOWNLOAD))


## Whether version a (X.Y.Z) is newer than b.
static func newer(a: String, b: String) -> bool:
	var pa := a.get_slice("-", 0).split(".")
	var pb := b.get_slice("-", 0).split(".")
	if pa.size() != 3:
		return false
	for i in 3:
		var x := int(pa[i])
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


## Test hook (--menu-update): show the notice as if a release had been found.
func pretend(v: String, s: State) -> void:
	latest = v
	state = s
	error = "The download didn't finish. It'll try again next time the game starts." if s == State.FAILED else ""
	changed.emit()


func _debug(msg: String) -> void:
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("UPDATER ", msg)
