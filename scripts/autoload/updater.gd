extends Node
## Keeping the game up to date. A release build (its version is stamped into
## project.godot by .github/workflows/release.yml) asks the matchmaker for the
## latest release when it starts: every release bakes its version, download
## links and checksums into the matchmaker (GET /release) and the website, so
## all three agree. GitHub's API is the fallback if the matchmaker can't be
## reached. If that's newer, it downloads the release's zip for
## this platform in the background, checks it against the SHA-256 GitHub
## publishes for it, and swaps the executable: the running one is renamed aside
## (Windows lets you rename a running program, though not overwrite it) and the
## new one takes its name. On a Mac the game is an app, which is a folder
## (Frontline.app: the program, the game it runs, and a signature over both),
## so the whole folder is swapped the same way. The menu then offers a
## restart; quitting does as well, since the next launch is the new version.
## The old file (or app) is deleted on that next launch.
##
## Where the game can't update itself (a build from source, a folder it can't
## write to, no build for this platform, a Mac app run straight from the
## Downloads folder, which macOS runs from a read-only copy), the menu links to
## the downloads.
## Keeping up matters online: the matchmaker only pairs players on the same
## network version (Net.NET_VERSION).
##
## Test switches: --game-version=X.Y.Z pretends to be that release,
## --update-api=URL reads the release from elsewhere (either form), and
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
var _api := ""  # --update-api, else the matchmaker's /release, then GitHub's
var _target := ""  # the executable an update replaces ("" when it can't)
var _asset := {}  # this platform's zip in the latest release: url, digest, size
var _req: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--managed-server="):
			return  # the launcher owns updates and the shared download file


	if OS.has_feature("web"):
		return  # the browser build is whatever the website serves: always the latest
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


## Find the latest release; if it's newer, say so, and install it when we can.
func check() -> void:
	var sources := [_api] if _api != "" else [Online.base_url + "/release", LATEST_RELEASE_API]
	var rel := {}
	for url in sources:
		rel = parse_release(await _get_json(String(url)))
		if not rel.is_empty():
			break
	var missing_native := OS.has_feature("template") and not ClassDB.class_exists("PerceptionSearch")
	if rel.is_empty() or (not newer(String(rel.version), version) and not (missing_native and String(rel.version) == version)):
		return
	latest = String(rel.version)
	_asset = rel.asset
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
	# a Mac app is swapped whole, beside itself: it's the folder it sits in
	# (Applications, usually) that has to take the new one
	var bundle := bundle_of(_target)
	var probe := (bundle if bundle != "" else _target).get_base_dir().path_join(".frontline-write-test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _get_json(url: String) -> Variant:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	if req.request(url, PackedStringArray(["Accept: application/json"])) != OK:
		req.queue_free()
		return null
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return null
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())


## {version, asset: {url, digest, size}} from either the matchmaker's
## release.json or GitHub's release API ({} if it's neither). The asset is
## the zip for this platform, or for `plat` ({} if the release has none).
static func parse_release(d: Variant, plat := "") -> Dictionary:
	if not d is Dictionary:
		return {}
	var r: Dictionary = d
	if plat == "":
		plat = platform()
	var asset := {}
	if r.has("version") and r.get("assets") is Dictionary:
		# ours: assets by platform, with the bare checksum
		var a: Variant = (r.assets as Dictionary).get(plat)
		if a is Dictionary:
			asset = {"url": String(a.get("url", "")), "digest": "sha256:" + String(a.get("sha256", "")), "size": int(a.get("size", 0))}
		return {"version": String(r.version), "asset": asset}
	if r.has("tag_name") and r.get("assets") is Array:
		# GitHub's: a list of files, and the checksum as "sha256:..."
		for a in r.assets:
			if a is Dictionary and String(a.get("name", "")) == "Frontline-%s.zip" % plat:
				asset = {"url": String(a.get("browser_download_url", "")), "digest": String(a.get("digest", "")), "size": int(a.get("size", 0))}
		return {"version": String(r.tag_name).trim_prefix("v"), "asset": asset}
	return {}


## This system, as a release names its zip: Frontline-<platform>.zip.
static func platform() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
		"Linux", "FreeBSD":
			return "linux"
	return ""


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
	var bundle := bundle_of(target)
	var problem := _install_app(z, bundle, target.get_file()) if bundle != "" else _install_file(z, target)
	z.close()
	return problem


## Windows and Linux: the game is one file, the executable with the game packed inside.
static func _install_file(z: ZIPReader, target: String) -> String:
	var entry := ""
	var libraries := {}
	for f in z.get_files():
		if f.get_file() == "Frontline.exe" or f.get_file() == "Frontline.x86_64":
			entry = f
		if f.get_file() in ["frontline_sim.dll", "libfrontline_sim.so"]:
			libraries[target.get_base_dir().path_join(f.get_file())] = z.read_file(f)
	var data := z.read_file(entry) if entry != "" else PackedByteArray()
	if data.size() < 1024:
		return "The download has no game in it."
	# Stage every sidecar before replacing the executable. Existing clients
	# updated only the executable; a missing extension triggers same-version
	# repair on their next launch, followed by the usual restart notice.
	var swapped: Array = []
	for path: String in libraries:
		var library: PackedByteArray = libraries[path]
		var file := FileAccess.open(path + ".new", FileAccess.WRITE)
		if library.is_empty() or file == null:
			_restore_libraries(swapped)
			return "The simulation library couldn't be staged."
		file.store_buffer(library)
		file.close()
		var existed := FileAccess.file_exists(path)
		if FileAccess.file_exists(path + ".old"):
			DirAccess.remove_absolute(path + ".old")
		if existed and DirAccess.rename_absolute(path, path + ".old") != OK:
			_restore_libraries(swapped)
			return "The simulation library is in use; close other copies and retry."
		swapped.append([path, existed])
		if DirAccess.rename_absolute(path + ".new", path) != OK:
			_restore_libraries(swapped)
			return "The new simulation library couldn't be put in place."
	var fresh := target + ".new"
	var w := FileAccess.open(fresh, FileAccess.WRITE)
	if w == null:
		_restore_libraries(swapped)
		return "The game's folder can't be written to."
	w.store_buffer(data)
	w.close()
	if not target.ends_with(".exe"):
		_make_executable(fresh)  # like the build it replaces
	var old := target + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(target, old) != OK:
		DirAccess.remove_absolute(fresh)
		_restore_libraries(swapped)
		return "The running game couldn't be moved aside."
	if DirAccess.rename_absolute(fresh, target) != OK:
		DirAccess.rename_absolute(old, target)  # put it back as it was
		_restore_libraries(swapped)
		return "The new version couldn't be put in place."
	return ""


static func _restore_libraries(swapped: Array) -> void:
	for i in range(swapped.size() - 1, -1, -1):
		var path: String = swapped[i][0]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if swapped[i][1]:
			DirAccess.rename_absolute(path + ".old", path)


## A Mac: the zip holds Frontline.app, which is unpacked beside the running app
## and then swapped for it, folder for folder. The program and the game it runs
## come as a pair, and the app's signature covers both, so they're never
## replaced one file at a time.
static func _install_app(z: ZIPReader, bundle: String, exe_name: String) -> String:
	var prefix := ""  # "Frontline.app/"
	for f in z.get_files():
		var i := f.find(".app/Contents/MacOS/")
		if i > 0 and not f.substr(0, i).contains("/"):
			prefix = f.substr(0, i + 5)
			break
	var exe := "Contents/MacOS/" + exe_name
	if prefix == "" or not z.file_exists(prefix + exe):
		return "The download has no game in it."
	var fresh := bundle + ".new"
	_remove_tree(fresh)
	for f in z.get_files():
		if not f.begins_with(prefix) or f.ends_with("/"):
			continue
		var rel := f.substr(prefix.length())
		if ".." in rel.split("/"):
			_remove_tree(fresh)
			return "The download isn't a zip the game can read."
		var path := fresh.path_join(rel)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var w := FileAccess.open(path, FileAccess.WRITE)
		if w == null:
			_remove_tree(fresh)
			return "The game's folder can't be written to."
		w.store_buffer(z.read_file(f))
		w.close()
		# a zip reader leaves the executable bit behind: the programs need it back
		if rel.begins_with("Contents/MacOS/") or rel.begins_with("Contents/Frameworks/"):
			_make_executable(path)
	var check := FileAccess.open(fresh.path_join(exe), FileAccess.READ)
	if check == null or check.get_length() < 1024:
		_remove_tree(fresh)
		return "The download has no game in it."
	check.close()
	var old := bundle + ".old"
	_remove_tree(old)
	if DirAccess.rename_absolute(bundle, old) != OK:
		_remove_tree(fresh)
		return "The running game couldn't be moved aside."
	if DirAccess.rename_absolute(fresh, bundle) != OK:
		DirAccess.rename_absolute(old, bundle)  # put it back as it was
		return "The new version couldn't be put in place."
	return ""


## The Mac app an executable lives in (".../Frontline.app"), or "" when the
## game is a single file.
static func bundle_of(exe: String) -> String:
	var i := exe.rfind(".app/Contents/MacOS/")
	return exe.substr(0, i + 4) if i > 0 else ""


## rwxr-xr-x
static func _make_executable(path: String) -> void:
	FileAccess.set_unix_permissions(path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
		| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER)


## Deletes a file, or a folder and everything in it. A link inside is removed,
## never followed.
static func _remove_tree(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		var d := DirAccess.open(path)
		if d != null:
			d.include_hidden = true
			for f in d.get_files():
				DirAccess.remove_absolute(path.path_join(f))
			for sub in d.get_directories():
				if d.is_link(sub):
					DirAccess.remove_absolute(path.path_join(sub))
				else:
					_remove_tree(path.path_join(sub))
		DirAccess.remove_absolute(path)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Start the new version and quit this one.
func restart() -> void:
	var bundle := bundle_of(_target)
	if bundle != "" and DirAccess.dir_exists_absolute(bundle):
		# the way the Finder opens an app (-n: a new copy, though this one
		# hasn't quite gone yet)
		OS.create_process("/usr/bin/open", PackedStringArray(["-n", bundle]))
	elif _target != "" and FileAccess.file_exists(_target):
		OS.create_process(_target, PackedStringArray())
	get_tree().quit()


func _fail(msg: String) -> void:
	error = msg
	state = State.FAILED
	_debug("update failed: " + msg)
	changed.emit()


## What the last update left behind: the previous executable or app (in use
## until we restarted) and a download that never finished.
func _clean_up() -> void:
	var bundle := bundle_of(_target)
	if bundle != "":
		_remove_tree(bundle + ".old")
	elif _target != "" and FileAccess.file_exists(_target + ".old"):
		DirAccess.remove_absolute(_target + ".old")
	if _target != "":
		for library in ["frontline_sim.dll", "libfrontline_sim.so"]:
			var old := _target.get_base_dir().path_join(library + ".old")
			if FileAccess.file_exists(old):
				DirAccess.remove_absolute(old)
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
