extends Node
## frontline:// links: how the website's Join and Find Match buttons open the
## game. A link is `frontline://join/<lobby id>` or `frontline://find-match`;
## the menu acts on it (menu.gd open_link).
##
## The browser starts the game with the link as its argument. If a copy is
## already running, the new one hands the link to it over a local socket and
## quits, so a click joins from the game you have open instead of starting a
## second one. An exported build registers the scheme itself the first time it
## runs from a given place (per user: no admin rights needed), which is why the
## website says to start the game once.
##
## For testing, pass the link after `--`: godot --path . -- frontline://join/ID.
## Test runs (any --switch) only listen for links handed on with --links.

signal link_opened(url: String)

const SCHEME := "frontline"
const PORT := 47781  # localhost only: where a running game listens for links

## The link this copy was started with, until the menu takes it.
var pending := ""
var _server: TCPServer
var _peers: Array = []  # [StreamPeerTCP, received text, give-up time]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		# a browser tab has no command line to be handed a link on, no local
		# socket and no scheme to claim (and can't join a battle anyway)
		set_process(false)
		return
	var user_args := OS.get_cmdline_user_args()
	pending = _link_in(OS.get_cmdline_args() + user_args)
	if pending != "" and _hand_on(pending):
		_debug("handed %s to the running game" % pending)
		get_tree().quit()
		return
	# a player's game listens for links; automated test runs (started with
	# --switches) leave the port alone unless asked, so a headless host can't
	# catch a link meant for the game being tested
	var testing := false
	for a in user_args:
		testing = testing or (a.begins_with("--") and a != "--links")
	if not testing or "--links" in user_args:
		_server = TCPServer.new()
		if _server.listen(PORT, "127.0.0.1") != OK:
			# another copy already listens: it gets the links
			_server = null
	# and only a player's game claims the scheme: a test run of an exported
	# build (from a scratch folder, say) must not point the links at itself
	if not testing:
		_register()


func _link_in(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with(SCHEME + "://"):
			return a
	return ""


## Give the link to a copy that's already running. False if there isn't one.
func _hand_on(url: String) -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", PORT) != OK:
		return false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 500:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			peer.put_data((url + "\n").to_utf8_buffer())
			peer.disconnect_from_host()
			return true
		if st != StreamPeerTCP.STATUS_CONNECTING:
			return false
		OS.delay_msec(10)
	return false


func _process(_dt: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		_peers.append([_server.take_connection(), "", Time.get_ticks_msec() + 2000])
	for i in range(_peers.size() - 1, -1, -1):
		var p: Array = _peers[i]
		var peer: StreamPeerTCP = p[0]
		peer.poll()
		var n := peer.get_available_bytes()
		if n > 0:
			p[1] = String(p[1]) + peer.get_utf8_string(n)
		var line := String(p[1])
		if line.contains("\n") or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() > int(p[2]):
			_peers.remove_at(i)
			peer.disconnect_from_host()
			line = line.get_slice("\n", 0).strip_edges()
			if line.begins_with(SCHEME + "://"):
				_debug("got %s from a second copy" % line)
				# bring the game to the front: the player just clicked in a browser
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_move_to_foreground()
				link_opened.emit(line)


## What a link asks for: ["join", lobby id], ["find-match", ""], or ["", ""].
static func parse(url: String) -> Array:
	var path := url.substr(url.find("://") + 3).trim_suffix("/")
	if path == "find-match":
		return ["find-match", ""]
	if path.begins_with("join/") and path.length() > 5:
		return ["join", path.substr(5).uri_decode()]
	return ["", ""]


# --- registering the scheme -------------------------------------------------------------

## Tell the OS that frontline:// links open this copy of the game, once per
## install location (remembered in user://links.cfg). Exported builds only:
## from the editor, the executable is Godot itself.
func _register() -> void:
	if not OS.has_feature("template"):
		return
	var exe := OS.get_executable_path()
	var cf := ConfigFile.new()
	cf.load("user://links.cfg")
	if String(cf.get_value("links", "registered", "")) == exe:
		return
	var ok := false
	match OS.get_name():
		"Windows":
			ok = _register_windows(exe)
		"Linux", "FreeBSD":
			ok = _register_linux(exe)
	_debug("registered %s:// for %s: %s" % [SCHEME, exe, str(ok)])
	if ok:
		cf.set_value("links", "registered", exe)
		cf.save("user://links.cfg")


## HKEY_CURRENT_USER\Software\Classes\frontline, through a .reg file: `reg add`
## can't be given the empty "URL Protocol" value through OS.execute, and a
## UTF-16 .reg file keeps install paths with any characters intact.
func _register_windows(exe: String) -> bool:
	var path := exe.replace("/", "\\")
	var q := func(s: String) -> String: return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
	var key := "HKEY_CURRENT_USER\\Software\\Classes\\" + SCHEME
	var reg := "\n".join([
		"Windows Registry Editor Version 5.00",
		"",
		"[%s]" % key,
		"@=" + q.call("URL:Frontline"),
		"\"URL Protocol\"=\"\"",
		"",
		"[%s\\DefaultIcon]" % key,
		"@=" + q.call("\"%s\",0" % path),
		"",
		"[%s\\shell\\open\\command]" % key,
		"@=" + q.call("\"%s\" \"%%1\"" % path),
		"",
	])
	var file := OS.get_user_data_dir().path_join("frontline-links.reg")
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(("\ufeff" + reg.replace("\n", "\r\n")).to_utf16_buffer())
	f.close()
	var code := OS.execute("reg", ["import", file.replace("/", "\\")])
	DirAccess.remove_absolute(file)
	return code == 0


## A hidden .desktop entry that handles x-scheme-handler/frontline.
func _register_linux(exe: String) -> bool:
	var data := OS.get_environment("XDG_DATA_HOME")
	if data == "":
		data = OS.get_environment("HOME").path_join(".local/share")
	var apps := data.path_join("applications")
	DirAccess.make_dir_recursive_absolute(apps)
	var desktop := "\n".join([
		"[Desktop Entry]",
		"Type=Application",
		"Name=Frontline",
		"Comment=Opens frontline:// links from the Frontline website",
		"Exec=\"%s\" %%u" % exe.replace("\\", "\\\\").replace("\"", "\\\""),
		"Terminal=false",
		"NoDisplay=true",
		"MimeType=x-scheme-handler/%s;" % SCHEME,
		"",
	])
	var f := FileAccess.open(apps.path_join("frontline-links.desktop"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(desktop)
	f.close()
	var code := OS.execute("xdg-mime", ["default", "frontline-links.desktop", "x-scheme-handler/" + SCHEME])
	OS.execute("update-desktop-database", [apps])
	return code == 0


func _debug(msg: String) -> void:
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("LINKS ", msg)
