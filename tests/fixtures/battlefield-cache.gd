extends Node

func _ready() -> void:
	BattlefieldCache._identity = "fixture"
	var folder := "user://cache-test-%d" % OS.get_process_id()
	var settings := {"seed": 3, "players": {1: {"name": "One", "team": 0}}, "map_size": 1024, "map_cache_dir": folder}
	var id := BattlefieldCache.key(settings)
	var changed := settings.duplicate(true)
	changed["simulation_export"] = "different-output"
	changed["perf_at"] = 30.0
	assert(BattlefieldCache.key(changed) == id, "Output and measurement paths must not invalidate identical maps")
	for field in ["seed", "map_size", "new_gameplay_option", "players"]:
		changed = settings.duplicate(true)
		changed[field] = 9
		assert(BattlefieldCache.key(changed) != id, "Every gameplay input must invalidate the package")
	BattlefieldCache._identity = "different-code"
	assert(BattlefieldCache.key(settings) != id, "Code/content identity must invalidate packages")
	BattlefieldCache._identity = "fixture"
	changed = settings.duplicate(true)
	changed.players = {2: {"team": 0}, 1: {"team": 0}}
	var reordered := changed.duplicate(true)
	reordered.players = {1: {"team": 0}, 2: {"team": 0}}
	assert(BattlefieldCache.key(changed) != BattlefieldCache.key(reordered), "Player iteration order affects deployment and must be preserved")
	var payload := "FLINtest-payload".to_utf8_buffer()
	BattlefieldCache.remember(settings, payload)
	var path := folder.path_join(id + ".flmap")
	assert(BattlefieldCache.read(path, id) == payload, "Package must round trip exact bytes")
	assert(BattlefieldCache.read(path, "wrong").is_empty(), "Wrong identity must be rejected")
	var destination := folder.path_join("restored.initial")
	assert(BattlefieldCache.restore(settings, destination))
	assert(FileAccess.get_file_as_bytes(destination) == payload)
	changed = settings.duplicate(true)
	changed.map_cache = false
	assert(not BattlefieldCache.restore(changed, destination), "Disabled caches must generate normally")
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end(-1)
	file.store_8(0)
	file.close()
	assert(BattlefieldCache.read(path, id).is_empty(), "Corrupt data must regenerate, not enter the simulation")
	BattlefieldCache.remember(settings, payload)
	assert(BattlefieldCache.read(path, id) == payload, "Regeneration must repair a corrupt entry atomically")
	file = FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek(BattlefieldCache.HEADER_BYTES - 8)
	file.store_64(BattlefieldCache.MAX_BYTES + 1)
	file.close()
	assert(BattlefieldCache.read(path, id).is_empty(), "Oversized declared lengths must not allocate")
	for i in 10:
		changed = settings.duplicate(true)
		changed.seed = i
		BattlefieldCache.remember(changed, payload)
	BattlefieldCache._prune(folder, BattlefieldCache.key(changed))
	var entries := 0
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".flmap"):
			entries += 1
	assert(entries <= BattlefieldCache.MAX_ENTRIES, "Disposable cache must remain bounded")
	assert(not BattlefieldCache.read(folder.path_join(BattlefieldCache.key(changed) + ".flmap"), BattlefieldCache.key(changed)).is_empty(), "Eviction must retain the newly generated entry")
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	BattlefieldCache._identity = ""
	print("BATTLEFIELD_CACHE_TEST passed")
	get_tree().quit()
