class_name BattlefieldCache
extends RefCounted
## Unticked deployments only: every generation input and the saved RNG belong together.

const ROOT := "user://battlefields"
const BUNDLED := "res://maps/precomputed"
const MAGIC := "FLMAP001"
const MAX_BYTES := 512 * 1024 * 1024
const MAX_CACHE_BYTES := 2 * 1024 * 1024 * 1024
const MAX_ENTRIES := 8
const HEADER_BYTES := 144
static var _identity := ""

static func _sources(path: String, records: Array[String]) -> void:
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd", "tres", "tscn"]:
			var source := FileAccess.get_file_as_string(path.path_join(file)).replace("\r\n", "\n")
			records.append(path.path_join(file).trim_prefix("res://") + "\n" + source.sha256_text() + "\n")
	for folder in DirAccess.get_directories_at(path):
		_sources(path.path_join(folder), records)

static func identity() -> String:
	if not _identity.is_empty():
		return _identity
	var code := ""
	if OS.has_feature("template"):
		if not FileAccess.file_exists("res://bin/map-cache-code.sha256"):
			return ""  # Unstamped exports generate normally rather than trust stale packages.
		code = FileAccess.get_file_as_string("res://bin/map-cache-code.sha256").strip_edges()
	else:
		var records: Array[String] = []
		_sources("res://scripts", records)
		_sources("res://assets", records)
		var project := FileAccess.get_file_as_string("res://project.godot").replace("\r\n", "\n")
		records.append("project.godot\n" + project.sha256_text() + "\n")
		records.sort()
		code = "".join(records).sha256_text()
	var library := "frontline_sim.dll" if OS.get_name() == "Windows" else ("libfrontline_sim.dylib" if OS.get_name() == "macOS" else "libfrontline_sim.so")
	var path := "res://bin/native/" + library
	if not FileAccess.file_exists(path):
		path = OS.get_executable_path().get_base_dir().path_join(library)
		if OS.get_name() == "macOS" and not FileAccess.file_exists(path):
			path = OS.get_executable_path().get_base_dir().get_base_dir().path_join("Frameworks/" + library)
	var server := LocalServer.executable()
	if server.is_empty():
		return ""
	if code.length() != 64 or not FileAccess.file_exists(path) or not FileAccess.file_exists("res://bin/content.json"):
		return ""
	_identity = (MAGIC + code + FileAccess.get_sha256(path) + FileAccess.get_sha256(server) + FileAccess.get_sha256("res://bin/content.json") + str(Engine.get_version_info())).sha256_text()
	return _identity

static func key(settings: Dictionary) -> String:
	var code := identity()
	if code.is_empty():
		return ""
	var inputs := settings.duplicate(true)
	for field in ["simulation_export", "map_cache", "map_cache_dir", "perf_at", "perf_duration", "perf_details", "benchmark_output", "fixed_seed"]:
		inputs.erase(field)
	# Top-level lookup order is irrelevant; nested player iteration order is not.
	var keys := inputs.keys()
	keys.sort()
	var ordered := {}
	for field in keys:
		ordered[field] = inputs[field]
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(code.to_utf8_buffer())
	hash.update(var_to_bytes(ordered))
	return hash.finish().hex_encode()

static func enabled(settings: Dictionary) -> bool:
	return not OS.has_feature("web") and bool(settings.get("map_cache", true))

static func root(settings: Dictionary) -> String:
	return String(settings.get("map_cache_dir", ROOT))

static func read(path: String, expected: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < HEADER_BYTES or file.get_length() > MAX_BYTES + HEADER_BYTES:
		return PackedByteArray()
	if file.get_buffer(8).get_string_from_ascii() != MAGIC or file.get_buffer(64).get_string_from_ascii() != expected:
		return PackedByteArray()
	var checksum := file.get_buffer(64).get_string_from_ascii()
	var length := file.get_64()
	if length < 8 or length > MAX_BYTES or length != file.get_length() - HEADER_BYTES:
		return PackedByteArray()
	var data := file.get_buffer(length)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data)
	if hash.finish().hex_encode() != checksum or data.slice(0, 4).get_string_from_ascii() != "FLIN":
		return PackedByteArray()
	return data

static func restore(settings: Dictionary, destination: String) -> bool:
	if not enabled(settings):
		return false
	var id := key(settings)
	if id.is_empty():
		return false
	for folder in [BUNDLED, root(settings)]:
		var data := read(folder.path_join(id + ".flmap"), id)
		if data.is_empty():
			continue
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			return false
		file.store_buffer(data)
		file.flush()
		if file.get_error() != OK:
			return false
		print("BATTLEFIELD_CACHE hit bytes=%d bundled=%s" % [data.size(), str(folder == BUNDLED)])
		return true
	print("BATTLEFIELD_CACHE miss")
	return false

static func remember(settings: Dictionary, data: PackedByteArray) -> void:
	if not enabled(settings) or data.size() < 8 or data.size() > MAX_BYTES:
		return
	var id := key(settings)
	if id.is_empty():
		return
	var folder := root(settings)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return  # A read-only or full cache must not stop the match.
	var path := folder.path_join(id + ".flmap")
	var temporary := path + ".%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data)
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_buffer(id.to_ascii_buffer())
	file.store_buffer(hash.finish().hex_encode().to_ascii_buffer())
	file.store_64(data.size())
	file.store_buffer(data)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return
	# Only the application's disposable cache is evicted; bake directories are explicit artifacts.
	if folder == ROOT:
		_prune(folder, id)
	print("BATTLEFIELD_CACHE stored bytes=%d" % data.size())

static func _prune(folder: String, keep: String) -> void:
	var entries := []
	var total := 0
	for name in DirAccess.get_files_at(folder):
		if name.length() != 70 or not name.ends_with(".flmap") or not name.get_basename().is_valid_hex_number(false):
			continue
		var path := folder.path_join(name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var length := file.get_length()
		total += length
		entries.append([path, length, FileAccess.get_modified_time(path), name == keep + ".flmap"])
	entries.sort_custom(func(a: Array, b: Array): return a[2] < b[2])
	var count := entries.size()
	for entry: Array in entries:
		if count <= MAX_ENTRIES and total <= MAX_CACHE_BYTES:
			break
		if not entry[3] and DirAccess.remove_absolute(entry[0]) == OK:
			total -= int(entry[1])
			count -= 1
