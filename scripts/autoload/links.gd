extends Node
## frontline:// links: how the website's Join and Find Match buttons open the
## game, and how it hands back a sign-in. A link is `frontline://join/<lobby id>`
## or `frontline://find-match`, which the menu acts on (menu.gd open_link), or
## `frontline://sign-in/<state>/<refresh token>`, which Online takes.
##
## The browser starts the game with the link as its argument. If a copy is
## already running, the new one hands the link to it over a local socket and
## quits, so a click joins from the game you have open instead of starting a
## second one. An exported build registers the scheme itself when it starts
## (per user: no admin rights needed) unless the system already sends links to
## it, which is why the website says to start the game once. On a Mac the app
## claims the scheme in its Info.plist (export_presets.cfg) and macOS takes note
## when it's first opened; a link reaches the game as `--uri="frontline://..."`,
## and when the game is already running, Godot starts a second copy with it,
## which hands it on like any other.
##
## For testing, pass the link after `--`: godot --path . -- frontline://join/ID.
## Test runs (any --switch) only listen for links handed on with --links.

signal link_opened(url: String)

const SCHEME := "frontline"
const PORT := 47781  # localhost only: where a running game listens for links
const DESKTOP := "frontline-links.desktop"  # on Linux, the entry that handles the links

## The link this copy was started with, until the menu takes it.
var pending := ""
## PORT, or FL_LINKS_PORT: a test's copies pass links among themselves, not
## to the game you're playing.
var port := PORT
var _server: TCPServer
var _takes_links := false  # a player's game, or a test run given --links
var _listen_at := 0  # when to ask for the port again, while another copy has it
var _peers: Array = []  # [StreamPeerTCP, received text, give-up time]
var _claim_task := -1  # registering the scheme, on a worker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		# a browser tab has no command line to be handed a link on, no local
		# socket and no scheme to claim (and can't join a battle anyway)
		set_process(false)
		return
	if OS.has_environment("FL_LINKS_PORT"):
		port = int(OS.get_environment("FL_LINKS_PORT"))
	var user_args := OS.get_cmdline_user_args()
	pending = link_in(OS.get_cmdline_args() + user_args)
	if pending != "" and _hand_on(pending):
		_debug("handed %s to the running game" % pending.get_slice("/", 2))
		# it's theirs now: nothing in this copy may act on it before it quits
		pending = ""
		get_tree().quit()
		return
	# a player's game listens for links; automated test runs (started with
	# --switches) leave the port alone unless asked, so a headless host can't
	# catch a link meant for the game being tested
	var testing := false
	for a in user_args:
		testing = testing or (a.begins_with("--") and a != "--links" and link_in(PackedStringArray([a])) == "")
	_takes_links = not testing or "--links" in user_args
	if _takes_links:
		_listen()
	# and only a player's game claims the scheme: a test run of an exported
	# build (from a scratch folder, say) must not point the links at itself
	if not testing:
		_register()


## The link among a copy's arguments: as a browser on Windows or Linux passes
## it, or as macOS does (`--uri="frontline://..."`). "" if there's none.
static func link_in(args: PackedStringArray) -> String:
	for a in args:
		var s := a.trim_prefix("--uri=")
		if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
			s = s.substr(1, s.length() - 2)
		if s.begins_with(SCHEME + "://"):
			return s
	return ""


## Take the port, unless another copy has it: that one gets the links, and
## this one asks again in a second. It may only be on its way out (an update
## starts the new version, then quits the old), and a game that gave up on the
## port would leave nothing listening once it had gone: every link from then
## on would start a second game instead of reaching this one.
func _listen() -> void:
	var server := TCPServer.new()
	if server.listen(port, "127.0.0.1") == OK:
		_server = server
		_debug("listening for links")
	else:
		_listen_at = Time.get_ticks_msec() + 1000


## Give the link to a copy that's already running. False if there isn't one.
func _hand_on(url: String) -> bool:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host("127.0.0.1", port) != OK:
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
		if _takes_links and Time.get_ticks_msec() >= _listen_at:
			_listen()
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
				_debug("got %s from a second copy" % line.get_slice("/", 2))
				# bring the game to the front: the player just clicked in a browser
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_move_to_foreground()
				link_opened.emit(line)


## What a link asks for: ["join", lobby id], ["find-match", ""],
## ["sign-in", state, refresh token], or ["", ""].
static func parse(url: String) -> Array:
	var path := url.substr(url.find("://") + 3).trim_suffix("/")
	if path == "find-match":
		return ["find-match", ""]
	if path.begins_with("join/") and path.length() > 5:
		return ["join", path.substr(5).uri_decode()]
	if path.begins_with("sign-in/"):
		var p := path.substr(8).split("/")
		if p.size() == 2 and p[0] != "" and p[1] != "":
			return ["sign-in", p[0].uri_decode(), p[1].uri_decode()]
	return ["", ""]


# --- registering the scheme -------------------------------------------------------------

## Tell the OS that frontline:// links open this copy of the game. Exported
## builds only: from the editor, the executable is Godot itself. Asking the OS
## first means running another program (reg, xdg-mime: a few hundredths of a
## second, longer on some Linux desktops), so it's done on a worker and the
## title doesn't wait for it.
func _register() -> void:
	if not OS.has_feature("template") or OS.get_name() not in ["Windows", "Linux", "FreeBSD"]:
		return  # on a Mac the app's Info.plist claims it: nothing to do here
	_claim_task = WorkerThreadPool.add_task(_claim.bind(OS.get_executable_path()), false, "Claiming frontline:// links")


func _exit_tree() -> void:
	if _claim_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_claim_task)  # nothing may be left running on a worker at exit
		_claim_task = -1


## Where the links were last claimed for is noted in user://links.cfg, but the
## note is only believed while the system still sends them there. Uninstalling
## another copy (the installer's uninstaller takes the links with it), a
## registry cleaner or another copy claiming them can take them away, and a
## game that went by its note alone never claimed them back: Join, Find Match
## and signing in on the website then opened nothing at all.
func _claim(exe: String) -> void:
	var cf := ConfigFile.new()
	cf.load("user://links.cfg")
	if String(cf.get_value("links", "registered", "")) == exe and _claimed(exe):
		_debug("%s:// still opens %s" % [SCHEME, exe])
		return
	var ok: bool = _register_windows(exe) if OS.get_name() == "Windows" else _register_linux(exe)
	_debug("registered %s:// for %s: %s" % [SCHEME, exe, str(ok)])
	if ok:
		cf.set_value("links", "registered", exe)
		cf.save("user://links.cfg")


## Whether the system still sends frontline:// links to `exe`.
func _claimed(exe: String) -> bool:
	if OS.get_name() == "Windows":
		# `reg query` would print the command in the console's code page, which
		# garbles any letter outside it (C:\Users\José comes back as "Jos‚"), so
		# the game would never recognise its own path; `reg export` writes the
		# key out in UTF-16, just as the game's own .reg file is written
		var file := OS.get_user_data_dir().path_join("frontline-links-%d.reg" % OS.get_process_id())
		var key := "HKCU\\Software\\Classes\\%s\\shell\\open\\command" % SCHEME
		if OS.execute("reg", ["export", key, file.replace("/", "\\"), "/y"]) != 0:
			return false  # no key at all
		var bytes := FileAccess.get_file_as_bytes(file)
		DirAccess.remove_absolute(file)
		return windows_claimed(bytes, exe)
	var handler := []
	OS.execute("xdg-mime", ["query", "default", "x-scheme-handler/" + SCHEME], handler)
	var path := _applications().path_join(DESKTOP)
	var desktop := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return linux_claimed("".join(handler), desktop, exe)


## Whether the command key, as `reg export` writes it out (the file's bytes),
## starts `exe` with the link: the very line the game writes itself. Windows
## paths ignore case, and the installer writes the folder as the player typed it.
static func windows_claimed(exported: PackedByteArray, exe: String) -> bool:
	if exported.size() >= 2 and exported[0] == 0xFF and exported[1] == 0xFE:
		exported = exported.slice(2)
	var want := _windows_command(exe).to_lower()
	for line in exported.get_string_from_utf16().split("\n"):
		if line.strip_edges().to_lower() == want:
			return true
	return false


## Whether xdg-mime's handler for the scheme (what `xdg-mime query default`
## printed) is the game's .desktop entry, and that entry (its text) starts `exe`.
static func linux_claimed(handler: String, desktop: String, exe: String) -> bool:
	if handler.strip_edges() != DESKTOP:
		return false
	for line in desktop.split("\n"):
		if line.strip_edges() == _desktop_exec(exe):
			return true
	return false


## HKEY_CURRENT_USER\Software\Classes\frontline, through a .reg file: `reg add`
## can't be given the empty "URL Protocol" value through OS.execute, and a
## UTF-16 .reg file keeps install paths with any characters intact.
func _register_windows(exe: String) -> bool:
	var path := exe.replace("/", "\\")
	var key := "HKEY_CURRENT_USER\\Software\\Classes\\" + SCHEME
	var reg := "\n".join([
		"Windows Registry Editor Version 5.00",
		"",
		"[%s]" % key,
		"@=" + _reg_string("URL:Frontline"),
		"\"URL Protocol\"=\"\"",
		"",
		"[%s\\DefaultIcon]" % key,
		"@=" + _reg_string("\"%s\",0" % path),
		"",
		"[%s\\shell\\open\\command]" % key,
		_windows_command(exe),
		"",
	])
	var file := OS.get_user_data_dir().path_join("frontline-links.reg")
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return false
	# reg only reads UTF-16 with its byte-order mark (FF FE) in front. It's
	# written as bytes: a "\ufeff" in a string comes out of an exported build
	# (its scripts stored as tokens) as nothing at all, reg turned the file
	# down, and no player's game on Windows ever claimed the scheme.
	var bytes := PackedByteArray([0xFF, 0xFE])
	bytes.append_array(reg.replace("\n", "\r\n").to_utf16_buffer())
	f.store_buffer(bytes)
	f.close()
	var code := OS.execute("reg", ["import", file.replace("/", "\\")])
	DirAccess.remove_absolute(file)
	return code == 0


## The .reg line that has a link start `exe`, the link as its argument.
static func _windows_command(exe: String) -> String:
	return "@=" + _reg_string("\"%s\" \"%%1\"" % exe.replace("/", "\\"))


## A string as a .reg file has it: in quotes, with \ and " escaped.
static func _reg_string(s: String) -> String:
	return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""


## A hidden .desktop entry that handles x-scheme-handler/frontline.
func _register_linux(exe: String) -> bool:
	var apps := _applications()
	DirAccess.make_dir_recursive_absolute(apps)
	var desktop := "\n".join([
		"[Desktop Entry]",
		"Type=Application",
		"Name=Frontline",
		"Comment=Opens frontline:// links from the Frontline website",
		_desktop_exec(exe),
		"Terminal=false",
		"NoDisplay=true",
		"MimeType=x-scheme-handler/%s;" % SCHEME,
		"",
	])
	var f := FileAccess.open(apps.path_join(DESKTOP), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(desktop)
	f.close()
	var code := OS.execute("xdg-mime", ["default", DESKTOP, "x-scheme-handler/" + SCHEME])
	OS.execute("update-desktop-database", [apps])
	return code == 0


## The .desktop line that has a link start `exe`, the link as its argument.
static func _desktop_exec(exe: String) -> String:
	return "Exec=\"%s\" %%u" % exe.replace("\\", "\\\\").replace("\"", "\\\"")


## Where the player's own .desktop entries go.
static func _applications() -> String:
	var data := OS.get_environment("XDG_DATA_HOME")
	if data == "":
		data = OS.get_environment("HOME").path_join(".local/share")
	return data.path_join("applications")


func _debug(msg: String) -> void:
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("LINKS ", msg)
