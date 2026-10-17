extends RefCounted
## --platform-test: what the game does with the system it runs on, checked
## offline and on any system: finding its download in a release, installing an
## update (one executable on Windows and Linux; on a Mac, the app, which is a
## folder) and reading a frontline:// link however the system hands it over.
## Prints PLATFORMTEST ok / FAIL lines and a total, then quits:
##   godot --headless --path . -- --platform-test

static var _n := 0
static var _fails := 0


static func _check(what: String, ok: bool, detail := "") -> void:
	_n += 1
	if not ok:
		_fails += 1
		TestRun.fail()
	print("PLATFORMTEST %s %s  %s" % ["ok  " if ok else "FAIL", what, detail])


static func run() -> void:
	var root := OS.get_user_data_dir().path_join("platform-test")
	Updater._remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)
	_releases()
	_links()
	_single_file(root.path_join("single"))
	_mac_app(root.path_join("mac"))
	Updater._remove_tree(root)
	_check("the scratch folder is cleared away", not DirAccess.dir_exists_absolute(root))
	print("PLATFORMTEST %d/%d passed" % [_n - _fails, _n])


# --- releases --------------------------------------------------------------------------------

static func _releases() -> void:
	var ours := {"version": "9.9.9", "assets": {}}
	var github := {"tag_name": "v9.9.9", "assets": []}
	for p in ["windows", "macos", "linux"]:
		ours.assets[p] = {"url": "https://x/%s.zip" % p, "sha256": p, "size": 1}
		github.assets.append({"name": "Frontline-%s.zip" % p, "browser_download_url": "https://x/%s.zip" % p, "digest": "sha256:" + p, "size": 1})
	for p in ["windows", "macos", "linux"]:
		var a: Dictionary = Updater.parse_release(ours, p).asset
		var b: Dictionary = Updater.parse_release(github, p).asset
		_check("a release names the %s download" % p, String(a.get("url")) == "https://x/%s.zip" % p and String(b.get("url")) == "https://x/%s.zip" % p
			and String(a.get("digest")) == "sha256:" + p and String(b.get("digest")) == "sha256:" + p)
	_check("this system has a download of its own", Updater.platform() != "", OS.get_name())
	# a release from before Mac builds: no download, so a Mac sends you to the website
	var old := {"version": "1.0.1", "assets": {"windows": ours.assets.windows, "linux": ours.assets.linux}}
	_check("a release without a Mac build offers a Mac nothing", (Updater.parse_release(old, "macos").asset as Dictionary).is_empty())


# --- links -------------------------------------------------------------------------------------

static func _links() -> void:
	var cases := [
		[["frontline://join/abc"], "frontline://join/abc", "a link as a browser on Windows or Linux passes it"],
		[["--uri=\"frontline://join/abc\""], "frontline://join/abc", "a link as macOS hands it over (quoted)"],
		[["--uri=frontline://find-match"], "frontline://find-match", "a link as macOS hands it over (bare)"],
		[["--headless", "--path", ".", "--uri=\"frontline://sign-in/s/t\""], "frontline://sign-in/s/t", "a link among other arguments"],
		[["--uri=\"https://example.com/\"", "--path"], "", "another kind of link is left alone"],
		[["--headless", "--path", "."], "", "no link at all"],
	]
	for c in cases:
		var got := Links.link_in(PackedStringArray(c[0]))
		_check(String(c[2]), got == String(c[1]), "%s -> %s" % [str(c[0]), got])
	_check("a Mac's link is read for what it asks", Links.parse(Links.link_in(PackedStringArray(["--uri=\"frontline://join/abc\""]))) == ["join", "abc"])
	_check("the key beside Alt has this system's name", Keys.name_of(KEY_META) == Keys.meta_name() and Keys.name_of(KEY_F | KEY_MASK_META) == Keys.meta_name() + " + F", Keys.name_of(KEY_F | KEY_MASK_META))


# --- installing --------------------------------------------------------------------------------

static func _bytes(what: String) -> PackedByteArray:
	return (what + " ").repeat(400).to_utf8_buffer()  # bigger than the smallest game the updater takes


static func _write(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


static func _read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## A zip of {name: bytes}; a name ending in / is a folder.
static func _zip(path: String, files: Dictionary) -> void:
	var z := ZIPPacker.new()
	z.open(path)
	for name in files:
		z.start_file(String(name))
		if not String(name).ends_with("/"):
			z.write_file(files[name])
		z.close_file()
	z.close()


## Windows and Linux: the executable is swapped for the one in the zip.
static func _single_file(dir: String) -> void:
	var exe := dir.path_join("Frontline.exe")
	_write(exe, _bytes("old"))
	var zip := dir.path_join("update.zip")
	_zip(zip, {"Frontline.exe": _bytes("new"), "LICENSE": "licence".to_utf8_buffer()})
	_check("a damaged download isn't installed", Updater.install(zip, "sha256:" + "0".repeat(64), exe).contains("damaged") and _read(exe) == _bytes("old"))
	var problem := Updater.install(zip, "sha256:" + FileAccess.get_sha256(zip), exe)
	_check("one executable: the new one takes its place", problem == "" and _read(exe) == _bytes("new") and _read(exe + ".old") == _bytes("old"), problem)


## A Mac: Frontline.app is swapped whole for the one in the zip.
static func _mac_app(dir: String) -> void:
	var app := dir.path_join("Applications/Frontline.app")
	var exe := app.path_join("Contents/MacOS/Frontline")
	_check("the app is found from its program", Updater.bundle_of(exe) == app and Updater.bundle_of(dir.path_join("Frontline.exe")) == "", Updater.bundle_of(exe))
	_write(exe, _bytes("old program"))
	_write(app.path_join("Contents/Resources/Frontline.pck"), _bytes("old game"))
	_write(app.path_join("Contents/Resources/gone.txt"), _bytes("only in the old app"))
	var release := {
		"Frontline.app/": PackedByteArray(),
		"Frontline.app/Contents/": PackedByteArray(),
		"Frontline.app/Contents/Info.plist": "<plist/>".to_utf8_buffer(),
		"Frontline.app/Contents/MacOS/Frontline": _bytes("new program"),
		"Frontline.app/Contents/Resources/Frontline.pck": _bytes("new game"),
		"Frontline.app/Contents/_CodeSignature/CodeResources": "<plist/>".to_utf8_buffer(),
		"LICENSE": "licence".to_utf8_buffer(),
	}
	var zip := dir.path_join("update.zip")
	_zip(zip, release)
	var problem := Updater.install(zip, "sha256:" + FileAccess.get_sha256(zip), exe)
	_check("a Mac app: installed", problem == "", problem)
	_check("the new app has the new program and the new game", _read(exe) == _bytes("new program") and _read(app.path_join("Contents/Resources/Frontline.pck")) == _bytes("new game")
		and FileAccess.file_exists(app.path_join("Contents/_CodeSignature/CodeResources")))
	_check("the whole app is swapped, not file by file", not FileAccess.file_exists(app.path_join("Contents/Resources/gone.txt")))
	_check("the old app waits beside it until the next launch", _read(app + ".old/Contents/MacOS/Frontline") == _bytes("old program") and not DirAccess.dir_exists_absolute(app + ".new"))
	_check("the licence beside the app in the zip isn't put in it", not FileAccess.file_exists(app.path_join("LICENSE")))
	if OS.get_name() != "Windows":
		var mode := FileAccess.get_unix_permissions(exe)
		_check("the program can be run", mode & FileAccess.UNIX_EXECUTE_OWNER != 0, "mode %o" % mode)
	# the next launch clears the old app away
	var target: String = Updater._target
	Updater._target = exe
	Updater._clean_up()
	Updater._target = target
	_check("the next launch clears the old app away", not DirAccess.dir_exists_absolute(app + ".old") and FileAccess.file_exists(exe))
	# and the update after that goes over it just the same
	release["Frontline.app/Contents/MacOS/Frontline"] = _bytes("newer program")
	_zip(zip, release)
	problem = Updater.install(zip, "", exe)
	_check("a second update goes over the first", problem == "" and _read(exe) == _bytes("newer program") and _read(app + ".old/Contents/MacOS/Frontline") == _bytes("new program"), problem)
	# a zip without the program in it changes nothing
	_zip(zip, {"Frontline.app/Contents/Info.plist": "<plist/>".to_utf8_buffer(), "LICENSE": "licence".to_utf8_buffer()})
	problem = Updater.install(zip, "", exe)
	_check("a download without the game leaves the app alone", problem.contains("no game") and _read(exe) == _bytes("newer program"), problem)
	# nor does one that tries to write outside the app
	_zip(zip, {"Frontline.app/Contents/MacOS/Frontline": _bytes("bad"), "Frontline.app/Contents/../../escaped.txt": _bytes("bad")})
	problem = Updater.install(zip, "", exe)
	_check("a download that reaches outside the app is refused", problem != "" and _read(exe) == _bytes("newer program") and not FileAccess.file_exists(dir.path_join("Applications/escaped.txt"))
		and not DirAccess.dir_exists_absolute(app + ".new"), problem)
