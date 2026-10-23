extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var folder := ProjectSettings.globalize_path("user://sidecar-test-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var exe := folder.path_join("Frontline.exe")
	var dll := folder.path_join("frontline_sim.dll")
	var archive := folder.path_join("release.zip")
	var old := PackedByteArray()
	old.resize(2048)
	old.fill(1)
	var fresh := old.duplicate()
	fresh.fill(2)
	for path in [exe, dll]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(old)
		file.close()
	var zip := ZIPPacker.new()
	zip.open(archive)
	for name in ["Frontline.exe", "frontline_sim.dll"]:
		zip.start_file(name)
		zip.write_file(fresh)
		zip.close_file()
	zip.close()
	check(Updater.install(archive, "sha256:wrong", exe) != "", "A damaged archive must be rejected")
	check(FileAccess.get_file_as_bytes(exe) == old and FileAccess.get_file_as_bytes(dll) == old, "Rejection must leave executable and library unchanged")
	check(Updater.install(archive, "sha256:" + FileAccess.get_sha256(archive), exe) == "", "Executable and sidecar installation must succeed")
	check(FileAccess.get_file_as_bytes(exe) == fresh and FileAccess.get_file_as_bytes(dll) == fresh, "An update must install both files")
	check(FileAccess.get_file_as_bytes(exe + ".old") == old and FileAccess.get_file_as_bytes(dll + ".old") == old, "The running version's files must be retained until restart")
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print("UPDATE_SIDECARS_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
